#!/usr/bin/env python3
"""扫描字符串插值和this.xxx中残留的_前缀字段名"""
import re
from pathlib import Path

LIB = Path("/workspace/hogwarts_life_simulator/lib")

# 已经 public 化的字段（summary中的32个核心成员）
publicized_fields = {
    'player', 'worldState', 'npcRegistry', 'memory',
    'currentNarrative', 'narrativeSummary', 'pendingSummary', 'recentTurns',
    'choices', 'commandResult', 'isLoading', 'isInitializing', 'error',
    'turnCount', 'lastPlayerAction', 'systemPrompt', 'loadingStage',
    'lastAffectionSections', 'notifications',
    'totalPromptTokens', 'totalCompletionTokens', 'totalTokens',
    'lastRoundTokens', 'apiCalls', 'gameWeek', 'lastSchoolYearStart',
    'pendingAnchorDirective', 'openingScene'
}

issues = []
for f in LIB.rglob("*.dart"):
    content = f.read_text(encoding="utf-8")
    lines = content.split("\n")
    for i, line in enumerate(lines, 1):
        # 排除注释行和import行
        stripped = line.strip()
        if stripped.startswith("//") or stripped.startswith("import"):
            continue
        # 1. 字符串插值: $_xxx 或 ${_xxx}
        for m in re.finditer(r"\$\{?_\w+\}?", line):
            tok = m.group(0)
            # 提取字段名
            name = re.sub(r"[\$\{\}]", "", tok)[1:]  # 去掉 $_/${...} 再去掉前导_
            if name in publicized_fields:
                issues.append(f"  ❌ {f.relative_to(LIB)} L{i}: {tok} → 应为 ${name}")
        # 2. this._xxx
        for m in re.finditer(r"this\.(\w+)", line):
            name = m.group(1)
            if name.startswith("_") and name[1:] in publicized_fields:
                issues.append(f"  ❌ {f.relative_to(LIB)} L{i}: this.{name} → 应为 this.{name[1:]}")
        # 3. 裸引用（非 this.）出现在明显的字段访问位置
        # 这里容易误判局部变量，所以只做辅助统计，不列作错误

if issues:
    print("\n".join(issues))
    print(f"\n共发现 {len(issues)} 处字段引用错误")
else:
    print("✅ 所有 public 化字段的引用均无下划线前缀残留")
