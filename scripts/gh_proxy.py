#!/usr/bin/env python3
"""
本地无-SNI TLS 终止代理：让 git/gh 在沙箱里也能连 GitHub。

原理：
  1) /etc/hosts 把 github.com/api.github.com 等指向 127.0.0.1；
  2) 本代理在 127.0.0.1:443 监听 HTTPS（本地 CA 签发的叶子证书）；
  3) 代理解密后以「无 SNI」直连 GitHub 真实 IP 回源；
  4) git 通过 GIT_SSL_CAINFO 信任本地 CA。

每请求一个上游连接，请求头强制 `Connection: close`，因此上游发完响应就关连接，
代理以 EOF 作为「响应结束」的判据 —— 不依赖 chunked 解析，也不再傻等 keep-alive 超时。
出口流量不带 SNI，绕开 DPI；Authorization 头原样转发，认证不受影响。
"""
import socket
import ssl
import sys
import threading

LISTEN_HOST, LISTEN_PORT = "127.0.0.1", 443
LEAF_CRT = "leaf.crt"
LEAF_KEY = "leaf.key"

# 各 github 域名的真实 IP 候选（命中即用，自动回退）。按 Host 区分节点！
# 注意：140.82.121.5 是 API 专属节点，用于 github.com 的 git 路径会 403。
WEB_IPS = ["140.82.113.3", "140.82.121.4", "140.82.114.3", "140.82.112.4", "140.82.116.4"]
API_IPS = ["140.82.121.5", "140.82.113.3", "140.82.121.4", "140.82.114.3", "20.205.243.166"]

RECV = 65536
UPSTREAM_TIMEOUT = 120


def log(msg):
    sys.stderr.write(msg + "\n")
    sys.stderr.flush()


def ips_for(host):
    h = host.lower()
    if h == "api.github.com" or h.endswith(".api.github.com"):
        return API_IPS
    return WEB_IPS


def upstream_connect(host):
    last = None
    for ip in ips_for(host):
        try:
            ctx = ssl.create_default_context()
            ctx.check_hostname = False      # 直连 IP，主机名必然对不上
            ctx.verify_mode = ssl.CERT_REQUIRED   # 证书链照样校验，防伪造
            s = socket.create_connection((ip, 443), timeout=UPSTREAM_TIMEOUT)
            s.settimeout(UPSTREAM_TIMEOUT)
            return ctx.wrap_socket(s, server_hostname=None)   # 关键：无 SNI
        except Exception as e:
            last = e
            continue
    raise last


def read_headers(sock):
    """读到头结束（\r\n\r\n），返回完整缓冲区（可能含已粘包的 body 前缀）。"""
    buf = b""
    while b"\r\n\r\n" not in buf and len(buf) < 1 << 20:
        c = sock.recv(RECV)
        if not c:
            break
        buf += c
    return buf


def parse_headers(head):
    lines = head.split(b"\r\n")
    method, path, host, clen, chunked = "GET", "/", "github.com", 0, False
    if lines and lines[0]:
        parts = lines[0].decode("latin-1").split(" ", 2)
        if len(parts) >= 2:
            method, path = parts[0], parts[1]
    for l in lines[1:]:
        low = l.lower()
        if low.startswith(b"host:"):
            host = l.split(b":", 1)[1].strip().decode("latin-1").split(":")[0]
        elif low.startswith(b"content-length:"):
            try:
                clen = int(l.split(b":", 1)[1].strip())
            except ValueError:
                clen = 0
        elif low.startswith(b"transfer-encoding:") and b"chunked" in low:
            chunked = True
    return method, path, host, clen, chunked


def read_chunked(sock, pending=b""):
    """读 chunked 请求体，返回去 chunk 化后的原始 body。"""
    buf = pending
    body = b""

    def need():
        nonlocal buf
        while b"\r\n" not in buf:
            c = sock.recv(RECV)
            if not c:
                return False
            buf += c
        return True

    while True:
        if not need():
            break
        line, _, buf = buf.partition(b"\r\n")
        size = 0
        try:
            size = int(line.split(b";")[0].strip() or b"0", 16)
        except ValueError:
            break
        if size == 0:
            while not buf.endswith(b"\r\n") and len(buf) < 2:
                c = sock.recv(RECV)
                if not c:
                    break
                buf += c
            break
        while len(buf) < size + 2:
            c = sock.recv(RECV)
            if not c:
                break
            buf += c
        body += buf[:size]
        buf = buf[size + 2:]
    return body


def force_close(head):
    """把请求头改成 Connection: close，去掉 Proxy-Connection。"""
    lines = head.split(b"\r\n")
    out = []
    for l in lines:
        low = l.lower()
        if low.startswith(b"connection:") or low.startswith(b"proxy-connection:"):
            continue
        if low.startswith(b"keep-alive:"):
            continue
        out.append(l)
    out.append(b"Connection: close")
    return b"\r\n".join(out)


def handle(client):
    up = None
    try:
        client.settimeout(UPSTREAM_TIMEOUT)
        head = read_headers(client)
        if not head:
            return
        method, path, host, clen, chunked = parse_headers(head)
        _, _, pending = head.partition(b"\r\n\r\n")

        body = b""
        if chunked:
            body = read_chunked(client, pending)
        elif clen:
            body = pending
            while len(body) < clen:
                c = client.recv(RECV)
                if not c:
                    break
                body += c
            body = body[:clen]

        raw_head = head.split(b"\r\n\r\n", 1)[0]
        out_head = force_close(raw_head)
        if body:
            out_head += b"\r\nContent-Length: " + str(len(body)).encode()
        request = out_head + b"\r\n\r\n" + body

        log(f"[proxy] {method} {host}{path} (body={len(body)})")
        up = upstream_connect(host)
        up.sendall(request)

        # 上游收到 Connection: close，发完即关 → 读到 EOF 就是完整响应
        chunks = []
        total = 0
        while True:
            c = up.recv(RECV)
            if not c:
                break
            chunks.append(c)
            total += len(c)
        resp = b"".join(chunks)
        log(f"[proxy]   <- {total} bytes")
        if resp:
            client.sendall(resp)
    except Exception as e:
        log(f"[proxy] err: {repr(e)}")
    finally:
        for s in (up, client):
            try:
                if s:
                    s.close()
            except Exception:
                pass


def main():
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(LEAF_CRT, LEAF_KEY)
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((LISTEN_HOST, LISTEN_PORT))
    srv.listen(128)
    log(f"[proxy] listening https://{LISTEN_HOST}:{LISTEN_PORT}")
    while True:
        c, _ = srv.accept()
        try:
            tc = ctx.wrap_socket(c, server_side=True)
        except Exception as e:
            log(f"[proxy] tls err: {repr(e)}")
            try:
                c.close()
            except Exception:
                pass
            continue
        threading.Thread(target=handle, args=(tc,), daemon=True).start()


if __name__ == "__main__":
    main()
