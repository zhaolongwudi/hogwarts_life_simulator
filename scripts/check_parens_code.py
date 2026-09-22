#!/usr/bin/env python3
# 字符串+注释感知的括号校验：剥离 Dart 字符串字面量与注释后再统计。
# 用于区分「中文文案里的半角英文括号」与「真实代码结构不平衡」。
# 全部使用 % 格式化，避免 f-string 内嵌引号。
import sys


def strip_strings_and_comments(src):
    """把字符串字面量、// 行注释、/* */ 块注释替换为等长空格。
    返回 (cleaned, kept_any) 便于后续纯计数。"""
    out = []
    i = 0
    n = len(src)
    while i < n:
        c = src[i]
        # 行注释
        if c == '/' and i + 1 < n and src[i + 1] == '/':
            j = src.find('\n', i)
            if j == -1:
                out.append(' ' * (n - i))
                break
            out.append(' ' * (j - i))
            i = j
            continue
        # 块注释
        if c == '/' and i + 1 < n and src[i + 1] == '*':
            j = src.find('*/', i + 2)
            if j == -1:
                out.append(' ' * (n - i))
                break
            out.append(' ' * (j + 2 - i))
            i = j + 2
            continue
        # 字符串（单/双引号，含转义；三引号）
        if c in ("'", '"'):
            triple = src[i:i + 3]
            if triple in ("'''", '"""'):
                j = src.find(triple, i + 3)
                if j == -1:
                    out.append(' ' * (n - i))
                    break
                out.append(' ' * (j + 3 - i))
                i = j + 3
                continue
            q = c
            j = i + 1
            while j < n:
                if src[j] == '\\':
                    j += 2
                    continue
                if src[j] == q:
                    break
                j += 1
            end = j + 1 if j < n else n
            out.append(' ' * (end - i))
            i = end
            continue
        out.append(c)
        i += 1
    return ''.join(out)


def check(path):
    raw = open(path, encoding='utf-8').read()
    code = strip_strings_and_comments(raw)
    pairs = {'{': '}', '(': ')', '[': ']'}
    o = {k: 0 for k in pairs}
    c = {v: 0 for v in pairs.values()}
    st = []
    line = 1
    col = 0
    bad = False
    for ch in code:
        if ch == '\n':
            line += 1
            col = 0
            continue
        col += 1
        if ch in o:
            o[ch] += 1
            st.append((ch, line, col))
        elif ch in c:
            c[ch] += 1
            if not st:
                print('%s:%d:%d unmatched close %s' % (path, line, col, ch))
                bad = True
            else:
                top, tl, tc = st.pop()
                if pairs[top] != ch:
                    print('%s:%d:%d mismatch %s vs %s (open %d:%d)' % (path, line, col, top, ch, tl, tc))
                    bad = True
    if st:
        for item in st[:5]:
            print('%s unclosed %s at %d:%d' % (path, item[0], item[1], item[2]))
        bad = True
    ok = (not bad) and all(o[k] == c[pairs[k]] for k in o)
    print(('OK  ' if ok else 'BAD ') + path +
          '  code { %d/%d ( %d/%d [ %d/%d' % (o['{'], c['}'], o['('], c[')'], o['['], c[']']))
    return ok


def main():
    files = [
        'lib/mixins/mixin_play.dart',
        'lib/mixins/mixin_commands.dart',
        'lib/data/club_minigames_data.dart',
        'lib/models/player.dart',
        'lib/models/game_systems.dart',
        'lib/mixins/mixin_club.dart',
    ]
    allok = True
    for f in files:
        if not check(f):
            allok = False
    sys.exit(0 if allok else 1)


if __name__ == '__main__':
    main()