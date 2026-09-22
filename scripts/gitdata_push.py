#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# 用 GitHub Git Data API 绕过 git push（github.com 直连超时，api.github.com 连通）。
# 核心思路：
#   1) 对目标 commit 的整棵 tree，找出【远端不存在的 blob】并逐个上传内容；
#   2) 从叶子目录向上重建 tree（POST /git/trees，引用已存在 blob sha）；
#   3) POST /git/commits 创建 commit（同一 sha 内容创建后 sha 一致）；
#   4) PATCH /git/refs/heads/main 更新引用。
# 用法: python3 scripts/gitdata_push.py <commit_sha> [heads/main]
#
# v3 修复：
#   - 中文文件名：git ls-tree 默认 core.quotepath=true 会输出八进制转义+引号，
#     改为 `git -c core.quotepath=false ls-tree -z`（NUL 分隔，路径原样 UTF-8）。
#   - PATCH /git/refs/{ref} 的 ref 不带 refs/ 前缀（如 heads/main）。
#   - 探测按对象类型分流（blob→GET /blobs，tree→GET /trees），减少无效请求。

import base64
import datetime
import json
import re
import subprocess
import sys
import urllib.request

REPO = 'zhaolongwudi/hogwarts_life_simulator'
BASE = f'https://api.github.com/repos/{REPO}/git'


def pat():
    url = subprocess.check_output(
        ['git', 'remote', 'get-url', 'origin'], text=True
    ).strip()
    return url.split('https://')[1].split('@')[0]


def api(method, path, payload=None, timeout=30):
    req = urllib.request.Request(BASE + path, method=method)
    req.add_header('Authorization', 'token ' + pat())
    if payload is not None:
        req.add_header('Content-Type', 'application/json')
        data = json.dumps(payload).encode()
    else:
        data = None
    try:
        with urllib.request.urlopen(req, data=data, timeout=timeout) as r:
            if method == 'HEAD':
                return {}
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:600]
        raise SystemExit(f'API {method} {path} -> HTTP {e.code}: {body}')


def git(args):
    return subprocess.check_output(['git'] + args, text=True).strip()


def remote_has_object(sha, obj_type):
    """探测远端是否已有该对象（blob 或 tree）。用 HEAD 避免下载整个对象体。"""
    try:
        if obj_type == 'tree':
            api('HEAD', f'/trees/{sha}?recursive=0')
        else:
            api('HEAD', f'/blobs/{sha}')
        return True
    except SystemExit:
        return False


def upload_blob(sha):
    raw = subprocess.check_output(['git', 'cat-file', 'blob', sha])
    b64 = base64.b64encode(raw).decode()
    b = api('POST', '/blobs', {'content': b64, 'encoding': 'base64'})
    if b.get('sha') != sha:
        raise SystemExit(f'blob sha mismatch: {sha}')


def build_tree_recursive(tree_sha):
    """自底向上在远端重建 tree（含子 tree），返回远端 tree sha。"""
    # -z: NUL 分隔记录，路径不做 quotepath 转义，中文/特殊字符原样输出
    raw = subprocess.check_output(
        ['git', '-c', 'core.quotepath=false', 'ls-tree', '-z', tree_sha])
    out_entries = []
    for rec in raw.split(b'\0'):
        if not rec:
            continue
        meta, path_b = rec.split(b'\t', 1)
        mode_b, obj_type_b, sha_b = meta.split(b' ')
        mode, obj_type = mode_b.decode(), obj_type_b.decode()
        sha = sha_b.decode()
        path = path_b.decode('utf-8', 'surrogateescape')
        if obj_type == 'tree':
            child = build_tree_recursive(sha)
            out_entries.append({'path': path, 'mode': mode,
                                'type': 'tree', 'sha': child})
        elif obj_type == 'blob':
            if not remote_has_object(sha, 'blob'):
                upload_blob(sha)
            out_entries.append({'path': path, 'mode': mode,
                                'type': 'blob', 'sha': sha})
        elif obj_type == 'commit':  # submodule，原样引用
            out_entries.append({'path': path, 'mode': mode,
                                'type': 'commit', 'sha': sha})
    created = api('POST', '/trees', {'tree': out_entries})
    return created['sha']


def parse_sig(sig):
    m = re.match(r'^(.*) <(.*)> (\d+) ([+-]\d{4})$', sig)
    if not m:
        return {'name': 'Operit', 'email': 'operit@local',
                'date': '2026-09-22T00:00:00Z'}
    name, email, ts, off = m.groups()
    dt = datetime.datetime.fromtimestamp(int(ts), tz=datetime.timezone.utc)
    return {'name': name, 'email': email, 'date': dt.strftime('%Y-%m-%dT%H:%M:%SZ')}


def push(commit_sha, ref):
    commits = git(['rev-list', '--reverse', 'origin/main..' + commit_sha]).splitlines()
    if not commits:
        print('nothing to push')
        return
    print('commits to push:', commits)

    for c in commits:
        raw = git(['cat-file', 'commit', c])
        lines = raw.split('\n')
        headers = {}
        msg_start = None
        for i, ln in enumerate(lines):
            if ln == '':
                msg_start = i + 1
                break
            if ln.startswith(('tree ', 'parent ', 'author ', 'committer ')):
                key = ln.split(' ')[0]
                headers.setdefault(key, []).append(ln)
        tree_sha = headers['tree'][0].split(' ')[1]
        parents = [p.split(' ')[1] for p in headers.get('parent', [])]
        author = headers['author'][0][len('author '):]
        committer = headers['committer'][0][len('committer '):]
        message = '\n'.join(lines[msg_start:])

        # 1) 重建 tree（自底向上；已存在对象跳过上传）
        print(f'  building tree for {c} ...', flush=True)
        new_tree = build_tree_recursive(tree_sha)
        assert new_tree == tree_sha, f'tree {tree_sha} != created {new_tree}'

        # 2) 创建 commit（父链：远端必须已有父；458c99a 已在远端）
        payload = {
            'message': message,
            'tree': tree_sha,
            'parents': parents,
            'author': parse_sig(author),
            'committer': parse_sig(committer),
        }
        created = api('POST', '/commits', payload)
        print(f'  commit {c} -> {created["sha"]}', flush=True)

    target = commits[-1]
    try:
        ref_resp = api('PATCH', f'/refs/{ref}',
                       {'sha': target, 'force': True})
        print(f'ref {ref} -> {ref_resp["object"]["sha"]}', flush=True)
    except SystemExit as e:
        # PATCH 404（ref 不存在）或 422（非 fast-forward 且 force 未生效）→ 用 create
        pos = str(e).find('HTTP ')
        code = int(str(e)[pos + 4:pos + 7]) if pos >= 0 else 0
        if code in (404, 422):
            full_ref = ref if ref.startswith('refs/') else f'refs/{ref}'
            create_resp = api('POST', '/refs', {
                'ref': full_ref,
                'sha': target,
            })
            print(f'ref created {create_resp["object"]["sha"]}', flush=True)
        else:
            raise


if __name__ == '__main__':
    sha = sys.argv[1]
    ref = sys.argv[2] if len(sys.argv) > 2 else 'heads/main'
    push(sha, ref)
    print('DONE')