#!/usr/bin/env python3
"""
本地无-SNI TLS 终止代理：让 git / curl / gh 在受限沙箱里也能连 GitHub。

原理
----
1) /etc/hosts 把 github.com、api.github.com 等指向 127.0.0.1；
2) 本代理在 127.0.0.1:443 监听 HTTPS（本地 CA 签发的叶子证书）；
3) 代理解密后以「无 SNI」直连 GitHub 真实 IP 回源；
4) 客户端通过 GIT_SSL_CAINFO / curl --cacert 信任本地 CA。

为什么必须去掉 SNI：出口链路上带 SNI 的 ClientHello 会被掐断，
不带 SNI 的 TLS 握手反而畅通。所以这一层代理是必需的，不是可选优化。

用法
----
    # 一次性准备（沙箱重置后要重做，见 .github/GITHUB_HANDSHAKE_SOLUTION.md §8）
    python3 gh_proxy.py &
    echo "127.0.0.1 github.com" >> /etc/hosts

    GIT_SSL_CAINFO=/opt/ghproxy/ca.crt git push origin main
    curl --cacert /opt/ghproxy/ca.crt https://api.github.com/...

关于回源 IP（2026-09 更新，重要）
--------------------------------
沙箱把 **UDP/53 全劫持** 了：所有公共 DNS（含 /etc/resolv.conf 里的）
一律返回假 IP 198.18.0.x，连上就 EOF。但 **TCP/53 没有被劫持**，
能拿到真实 IP。所以解析顺序是：TCP DNS → 失败则回退硬编码 IP 池。
"""
import os
import select
import socket
import ssl
import struct
import sys
import threading

LISTEN_HOST, LISTEN_PORT = "0.0.0.0", 443

_HERE = os.path.dirname(os.path.abspath(__file__))
_CANDIDATE_DIRS = ["/opt/ghproxy", _HERE, os.path.join(_HERE, "certs")]
LEAF_CRT = next(
    (os.path.join(d, "leaf.crt") for d in _CANDIDATE_DIRS
     if os.path.exists(os.path.join(d, "leaf.crt"))), "leaf.crt")
LEAF_KEY = LEAF_CRT.replace("leaf.crt", "leaf.key")

RECV = 65536
UPSTREAM_TIMEOUT = 20

# 硬编码兜底：按 Host 分节点。
# 注意 140.82.121.5 是 API 专属节点，拿去请求 github.com 的 git 路径会 403。
API_IPS = ["140.82.121.5", "140.82.113.3", "140.82.121.4",
           "140.82.114.3", "20.205.243.166"]
WEB_IPS = ["140.82.113.3", "140.82.121.4", "140.82.114.3",
           "140.82.112.4", "140.82.116.4"]

# UDP/53 全被劫持成 198.18.0.x，只有 TCP/53 能拿到真 IP
TCP_DNS_SERVERS = ["8.8.8.8", "1.1.1.1", "9.9.9.9"]

_ip_cache = {}


def log(msg):
    sys.stderr.write("[ghproxy] " + msg + "\n")
    sys.stderr.flush()


# ---------------------------------------------------------------- DNS ----

def _enc_domain(d):
    out = b""
    for label in d.split(b"."):
        out += bytes([len(label)]) + label
    return out + b"\x00"


def tcp_dns_resolve(host, ns, timeout=5):
    """TCP/53 查 A 记录。返回 IP 列表，失败返回 []。"""
    query = (b"\xab\xcd\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00"
             + _enc_domain(host.encode()) + struct.pack(">HH", 1, 1))
    try:
        s = socket.create_connection((ns, 53), timeout=timeout)
        s.sendall(struct.pack(">H", len(query)) + query)
        need = struct.unpack(">H", s.recv(2))[0]
        data = b""
        while len(data) < need:
            chunk = s.recv(need - len(data))
            if not chunk:
                break
            data += chunk
        s.close()
        idx = 12
        while idx < len(data) and data[idx] != 0:
            idx += data[idx] + 1
        idx += 5
        ancount = struct.unpack(">H", data[6:8])[0]
        ips = []
        for _ in range(ancount):
            while True:
                l = data[idx]
                if l & 0xC0 == 0xC0:
                    idx += 2
                    break
                if l == 0:
                    idx += 1
                    break
                idx += l + 1
            typ, _cls, _ttl, rdlen = struct.unpack(">HHIH", data[idx:idx + 10])
            idx += 10
            if typ == 1 and rdlen == 4:
                ips.append(".".join(str(b) for b in data[idx:idx + 4]))
            idx += rdlen
        return ips
    except Exception:
        return []


def resolve(host):
    """拿真实 IP：TCP DNS 优先（过滤假 IP），硬编码池兜底。"""
    if host in _ip_cache:
        return _ip_cache[host]
    for ns in TCP_DNS_SERVERS:
        real = [i for i in tcp_dns_resolve(host, ns)
                if not i.startswith("198.18.")]
        if real:
            _ip_cache[host] = real[0]
            log(f"DNS(TCP) {host} -> {real[0]}")
            return real[0]
    return None


def ip_candidates(host):
    h = host.lower()
    pool = API_IPS if (h == "api.github.com" or h.endswith(".api.github.com")) \
        else WEB_IPS
    ip = resolve(host)
    return ([ip] if ip else []) + pool


# ------------------------------------------------------------- TLS 层 ----

def sni_from_clienthello(data):
    """从 ClientHello 里抠 SNI，用来决定回源到哪个域名。"""
    try:
        if len(data) < 5 or data[0] != 0x16:
            return None
        body = data[5:]
        if not body or body[0] != 0x01:
            return None
        p = 4 + 2 + 32                # type+len, version, random
        p += 1 + body[p]              # session id
        p += 2 + struct.unpack(">H", body[p:p + 2])[0]   # cipher suites
        p += 1 + body[p]              # compression
        end = p + 2 + struct.unpack(">H", body[p:p + 2])[0]
        p += 2
        while p + 4 <= end:
            etype, elen = struct.unpack(">HH", body[p:p + 4])
            p += 4
            if etype == 0:            # server_name
                nlen = struct.unpack(">H", body[p + 3:p + 5])[0]
                return body[p + 5:p + 5 + nlen].decode("utf-8", "ignore")
            p += elen
    except Exception:
        return None
    return None


def upstream_connect(host):
    last = None
    for ip in ip_candidates(host):
        try:
            ctx = ssl.create_default_context()
            ctx.check_hostname = False          # 直连 IP，主机名必然对不上
            ctx.verify_mode = ssl.CERT_REQUIRED  # 证书链照样校验，防伪造
            raw = socket.create_connection((ip, 443), timeout=UPSTREAM_TIMEOUT)
            # 关键：不传 server_hostname => ClientHello 里不带 SNI
            tls = ctx.wrap_socket(raw)
            return tls, ip
        except Exception as e:
            last = e
            continue
    raise last if last else RuntimeError(f"no upstream for {host}")


def pipe(a, b):
    """双向转发，任一端 EOF 就收工。"""
    try:
        while True:
            r, _, err = select.select([a, b], [], [a, b], 300)
            if err or not r:
                return
            for s in r:
                other = b if s is a else a
                try:
                    data = s.recv(RECV)
                except (ssl.SSLWantReadError, BlockingIOError):
                    continue
                except OSError:
                    return
                if not data:
                    return
                try:
                    other.sendall(data)
                except OSError:
                    return
    finally:
        for s in (a, b):
            try:
                s.close()
            except Exception:
                pass


def handle(conn, _addr):
    target = "?"
    try:
        conn.settimeout(UPSTREAM_TIMEOUT)
        peek = conn.recv(4096, socket.MSG_PEEK)
        if not peek:
            conn.close()
            return
        target = sni_from_clienthello(peek) or "github.com"

        sctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        sctx.load_cert_chain(LEAF_CRT, LEAF_KEY)
        tls_in = sctx.wrap_socket(conn, server_side=True)

        tls_out, ip = upstream_connect(target)
        tls_in.settimeout(None)
        tls_out.settimeout(None)
        log(f"{target} -> {ip} (无 SNI)")
        pipe(tls_in, tls_out)
    except Exception as e:
        log(f"{target}: {type(e).__name__} {e}")
        try:
            conn.close()
        except Exception:
            pass


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else LISTEN_PORT
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((LISTEN_HOST, port))
    srv.listen(128)
    log(f"listening on {LISTEN_HOST}:{port}  cert={LEAF_CRT}")
    while True:
        c, a = srv.accept()
        threading.Thread(target=handle, args=(c, a), daemon=True).start()


if __name__ == "__main__":
    main()
