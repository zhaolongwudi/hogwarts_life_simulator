#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""审计 prompt 常量体积（字符数 / 粗略 token 估算）。

只做静态读取，不改任何代码。用于回答「每回合到底往模型塞了多少字」。
token 估算口径：中文按 1 字 ≈ 0.6 token（BPE 经验值），仅用于相对比较。
"""
import re
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read(rel):
    with open(os.path.join(ROOT, rel), encoding='utf-8') as f:
        return f.read()


def extract(src, name):
    pat = re.compile(r"\b" + re.escape(name) + r"\s*=\s*'''(.*?)'''", re.S)
    m = pat.search(src)
    return m.group(1) if m else None


def main():
    narrative = read('lib/prompts/narrative_prompts.dart')
    choice = read('lib/prompts/choice_prompts.dart')

    items = []
    for name in ('kNarrativeRulesCore', 'kNarrativeRulesQuality'):
        t = extract(narrative, name)
        if t is not None:
            items.append((name, len(t)))
    for name in ('kChoicePromptPreamble', 'kChoicePromptSuffix',
                 'kChoiceQualityChecklist'):
        t = extract(choice, name)
        if t is not None:
            items.append((name, len(t)))

    print('%-32s %8s %8s' % ('常量', '字符数', '约token'))
    print('-' * 52)
    for name, n in items:
        print('%-32s %8d %8d' % (name, n, round(n * 0.6)))

    core = extract(narrative, 'kNarrativeRulesCore') or ''
    qual = extract(narrative, 'kNarrativeRulesQuality') or ''
    print()
    print('每回合叙事规则注入量：')
    print('  turn%%3 != 0（T0）     : %d 字符 约 %d token'
          % (len(core), round(len(core) * 0.6)))
    print('  turn%%3 == 0（T0+T1）  : %d 字符 约 %d token'
          % (len(core) + len(qual), round((len(core) + len(qual)) * 0.6)))

    pre = extract(choice, 'kChoicePromptPreamble') or ''
    suf = extract(choice, 'kChoicePromptSuffix') or ''
    chk = extract(choice, 'kChoiceQualityChecklist') or ''
    fixed = len(pre) + len(suf) + len(chk)
    print('选项 prompt 固定骨架（不含动态上下文）: %d 字符 约 %d token'
          % (fixed, round(fixed * 0.6)))
    return 0


if __name__ == '__main__':
    sys.exit(main())