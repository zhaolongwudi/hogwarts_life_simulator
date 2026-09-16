#!/usr/bin/env python3
"""根据flutter analyze日志清理所有文件中未使用的import和警告。"""
import re
import sys
from pathlib import Path

PROJECT = Path('/workspace/hogwarts_life_simulator')

# 从CI日志提取: {rel_path: [set of unused import line numbers]}
# 格式: warning • ... • path/to/file.dart:LINE:8 • unused_import
UNUSED_IMPORTS = {
    'lib/mixins/mixin_commands.dart': {2,3,4,5,7,10,11,13,14,15,16,17,18,19,20,21,22,23,24,27,28,29},
    'lib/mixins/mixin_init.dart':     {2,4,10,11,12,13,14,16,18,21,22,23,24,25,27},
    'lib/mixins/mixin_narrative.dart':{4,5,6,7,10,12,13,14,15,16,19,20,21,23,24,25,26,28},
    'lib/mixins/mixin_relations.dart':{2,4,5,6,7,10,11,13,14,16,18,19,20,21,22,25,26,28,29},
    'lib/mixins/mixin_response.dart': {2,4,5,6,10,11,12,14,15,16,17,18,19,20,21,22,23,24,25,26,28,29},
    'lib/mixins/mixin_systems.dart':  {4,5,6,7,10,12,13,14,15,18,19,20,21,23,26,29},
    'lib/providers/game_provider.dart': {4,8,9,10,11,12,13,14,16,17,18,24,25,26},
    'lib/providers/game_provider_base.dart': {3},
    'lib/screens/other/diary_screen.dart': {3,5,6,7},
    'lib/screens/other/forum_screen.dart': {2,3,4,5,6,7},
    'lib/screens/other/matchmaker_screen.dart': {5,7},
    'lib/screens/other/parallel_world_screen.dart': {2,3,4,5,6,7},
}

def clean_imports(rel_path: str, bad_lines: set[int]) -> bool:
    path = PROJECT / rel_path
    if not path.exists():
        print(f'[SKIP] 不存在: {rel_path}')
        return False
    lines = path.read_text(encoding='utf-8').splitlines()
    new_lines = []
    removed = 0
    for i, line in enumerate(lines, 1):
        if i in bad_lines:
            removed += 1
            continue
        new_lines.append(line)
    path.write_text('\n'.join(new_lines) + '\n', encoding='utf-8')
    print(f'[OK] {rel_path}: 移除 {removed} 行未使用import')
    return True

def main():
    total = 0
    for rel_path, bad in UNUSED_IMPORTS.items():
        if clean_imports(rel_path, bad):
            total += 1
    print(f'\n完成: 处理了 {total} 个文件')

if __name__ == '__main__':
    main()
