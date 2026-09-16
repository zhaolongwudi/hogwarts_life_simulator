#!/usr/bin/env python3
"""验证各文件中关键类型是否有对应的import，防止过度删除。"""
import re
from pathlib import Path

PROJECT = Path('/workspace/hogwarts_life_simulator')

# 类型名 -> import路径映射 (需要的import如果使用了该类型)
TYPE_TO_IMPORT = [
    # dart SDK
    ('Random', 'dart:math'),
    ('Timer', 'dart:async'),
    ('Completer', 'dart:async'),
    ('unawaited', 'dart:async'),
    # flutter
    ('ChangeNotifier', 'package:flutter/widgets.dart'),
    ('debugPrint', 'package:flutter/widgets.dart'),
    ('WidgetsBinding', 'package:flutter/widgets.dart'),
    # 数据模型
    ('Player', '../models/player.dart'),
    ('NPC', '../models/npc.dart'),
    ('WorldState', '../models/world_state.dart'),
    ('GameChoice', '../models/game_systems.dart'),
    ('LongTermMemory', '../models/long_term_memory.dart'),
    ('MemoryFact', '../models/long_term_memory.dart'),
    ('CgDef', '../data/cg_data.dart'),
    ('PetDef', '../data/pet_data.dart'),
    ('NpcDef', '../data/npc_data.dart'),
    ('TraitDef', '../data/trait_data.dart'),
    ('CourseDef', '../data/course_data.dart'),
    ('GoalDef', '../data/goal_data.dart'),
    ('WandDef', '../data/wand_data.dart'),
    ('Balance', '../data/balance_constants.dart'),
    ('EventAnchor', '../data/event_anchors.dart'),
    ('Era', '../models/world_state.dart'),
    # 服务
    ('SaveService', '../services/save_service.dart'),
    ('ChatResult', '../services/deepseek_service.dart'),
    ('TokenUsage', '../services/deepseek_service.dart'),
    ('AiRouter', '../services/ai_router.dart'),
    ('AiScene', '../services/ai_router.dart'),
    ('AiProvider', '../services/ai_router.dart'),
    ('AiRouterConfig', '../services/ai_router.dart'),
    ('NpcChatService', '../services/npc_chat_service.dart'),
    ('PromptSanitizer', '../utils/prompt_sanitizer.dart'),
    ('StoryTextRenderer', '../utils/story_text_renderer.dart'),
    ('RateLimiter', '../services/rate_limiter.dart'),
    ('ResponseCache', '../services/deepseek_service.dart'),
    ('CrashLogger', '../utils/crash_logger.dart'),
    # Provider
    ('AppProvider', '../providers/app_provider.dart'),
    ('GameProvider', '../providers/game_provider.dart'),
]

FILES = [
    'lib/mixins/mixin_commands.dart',
    'lib/mixins/mixin_init.dart',
    'lib/mixins/mixin_narrative.dart',
    'lib/mixins/mixin_relations.dart',
    'lib/mixins/mixin_response.dart',
    'lib/mixins/mixin_systems.dart',
    'lib/providers/game_provider.dart',
    'lib/providers/game_provider_base.dart',
    'lib/screens/other/diary_screen.dart',
    'lib/screens/other/forum_screen.dart',
    'lib/screens/other/matchmaker_screen.dart',
    'lib/screens/other/parallel_world_screen.dart',
    'lib/screens/shop/shop_tab.dart',
]

def remove_comments(src: str) -> str:
    """移除Dart代码中的//单行注释和/* */块注释，避免误判注释中引用的类型。"""
    # 去掉块注释
    src = re.sub(r'/\*.*?\*/', '', src, flags=re.DOTALL)
    # 去掉行注释（不在字符串内的，简单处理）
    out_lines = []
    for line in src.splitlines():
        # 简单处理：去掉 // 之后的内容（不处理字符串内的情况，这只是个启发式）
        idx = line.find('//')
        if idx >= 0:
            line = line[:idx]
        out_lines.append(line)
    return '\n'.join(out_lines)

def check_file(rel_path: str):
    path = PROJECT / rel_path
    src = path.read_text(encoding='utf-8')
    code = remove_comments(src)
    lines = src.splitlines()
    
    # 收集现有imports
    existing_imports = set()
    import_pat = re.compile(r"^\s*import\s+['\"]([^'\"]+)['\"]")
    for line in lines:
        m = import_pat.match(line)
        if m:
            imp = m.group(1)
            existing_imports.add(imp)
    
    def has_import(required: str) -> bool:
        for e in existing_imports:
            # 路径尾匹配或完全相等
            norm_req = required.lstrip('./')
            norm_e = e.rstrip("';")
            if norm_e == required or norm_e.endswith('/' + norm_req):
                return True
            # package: / dart: 精确匹配
            if required.startswith('package:') or required.startswith('dart:'):
                if e == required:
                    return True
        return False
    
    missing = []
    for type_name, required_import in TYPE_TO_IMPORT:
        # 搜索词边界上的类型引用
        pat = re.compile(r'\b' + re.escape(type_name) + r'(?=[\s?.(<\[:,])')
        if pat.search(code):
            if not has_import(required_import):
                # 但：有些类型是通过 on GameProviderBase 继承的，不需要再次import
                # 例如：worldState, player 等字段在 Mixin 里引用，但类型可能不需要import
                # 所以仅做WARN，不视为硬错误
                missing.append((type_name, required_import))
    
    if missing:
        print(f'[WARN] {rel_path}: 可能缺少import (需人工确认):')
        for t, i in missing:
            print(f'       类型 {t} -> import {i}')
        return False
    else:
        print(f'[ OK ] {rel_path}: 类型-import 看起来完整')
        return True

def main():
    fails = 0
    for f in FILES:
        if not check_file(f):
            fails += 1
    print(f'\n共 {len(FILES)} 个文件，{fails} 个需要人工复查')

if __name__ == '__main__':
    main()
