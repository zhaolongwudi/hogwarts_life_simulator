#!/usr/bin/env python3
"""
核心修复：GameProviderBase 中所有 "_xxx(...);" 形式的 private abstract 声明必须删除。
Dart library 级隐私模型：private标识符仅在声明它的library内可见。
GameProviderBase 在 providers/ 下，Mixins 在 mixins/ 下 → 属于不同library，
所以 abstract 方法如果带下划线前缀，子类/Mixin 完全看不到该声明，
GameProvider/Mixin 内的同名 private 方法也不算 @override，
最终导致的不是编译错就是抽象类继承接口不匹配。

同理检查：所有 Base 中参数里用到的类型是否真的 import 了（NPC/Era/CgDef/ChatResult/AiScene）
"""
import re
from pathlib import Path

PROV_DIR = Path("/workspace/hogwarts_life_simulator/lib/providers")
BASE_FILE = PROV_DIR / "game_provider_base.dart"

content = BASE_FILE.read_text(encoding="utf-8")
lines = content.split("\n")
new_lines = []
dropped = []
for line in lines:
    # 匹配: 行内包含抽象方法签名 且 方法名以 _ 开头
    m = re.match(r"(\s*)([a-zA-Z_][\w<>?, \[\]]*?)\s+(_[a-zA-Z0-9_]+)\s*\((.*)\);\s*$", line)
    if m and m.group(3).startswith("_"):
        dropped.append(f"{m.group(2)} {m.group(3)}({m.group(4)})")
        continue  # 丢掉
    new_lines.append(line)

BASE_FILE.write_text("\n".join(new_lines), encoding="utf-8")
print(f"✅ 已移除 {len(dropped)} 条 _前缀 private abstract 声明（跨library不可见，Dart禁止）：")
for d in dropped:
    print(f"   - {d}")

# 二次核查：Base 文件里的类型引用是否都有对应 import
# 从 abstract 方法签名里抽类型名
types_used = set()
for line in new_lines:
    for token in re.findall(r"\b([A-Z][a-zA-Z0-9]*)\b", line):
        if token in {"String", "int", "double", "bool", "List", "Map", "Set",
                     "Future", "Iterable", "Object", "dynamic", "void",
                     "DateTime", "RegExp", "Random"}:
            continue
        types_used.add(token)

# 统计每个 import 引入的类（按文件名映射常见类）
known = {
    "player.dart": ["Player"],
    "npc.dart": ["NPC"],
    "world_state.dart": ["WorldState", "Era"],
    "game_systems.dart": ["GameChoice", "SaveSlot", "GameTime", "MonthlyEvent"],
    "long_term_memory.dart": ["LongTermMemory"],
    "cg_data.dart": ["CgDef", "CG_TAG"],
    "npc_chat_service.dart": ["ChatResult", "NpcChatService"],
    "ai_router.dart": ["AiScene", "AiRouter", "AiProvider", "AiRouterConfig"],
    "app_provider.dart": ["AppProvider"],
    "save_service.dart": ["SaveService"],
}
# 看看哪些类型在当前 base 里没对应 import 可能
imports = re.findall(r"""import\s+['"]([^'"]+)['"];""", "\n".join(new_lines))
print("\nGameProviderBase 当前 imports:")
for i in imports:
    print(f"   {i}")

# 检查 _formatTime 引用问题是否解了
mixin_cmds = Path("/workspace/hogwarts_life_simulator/lib/mixins/mixin_commands.dart").read_text(encoding="utf-8")
if "_formatTime" in mixin_cmds and re.search(r"String\s+_formatTime\s*\(", mixin_cmds):
    print("\n✅ mixin_commands 中 _formatTime() 的定义与引用在同文件内，不再触发跨library可见性错误")
