#!/usr/bin/env python3
"""
终极修复V4：
1) 移除 game_provider_base.dart 中所有方法签名前的 "abstract " 关键字（Dart 不允许）
2) GameProviderBase 声明本身必须为 `abstract class`（Dart 规定：有抽象方法的类必须abstract）
3) 补 game_provider_base.dart 缺失的 import (CgDef / ChatResult / AiScene / Era / NPC)
4) _standaloneNameMentioned: 只在 mixin_response.dart 被调用，无定义 → 直接内嵌实现
5) _formatTime: 同上，检查是否有定义
"""
import re
from pathlib import Path

MIXIN_DIR = Path("/workspace/hogwarts_life_simulator/lib/mixins")
PROV_DIR = Path("/workspace/hogwarts_life_simulator/lib/providers")
BASE_FILE = PROV_DIR / "game_provider_base.dart"
GP_FILE = PROV_DIR / "game_provider.dart"
RESP_FILE = MIXIN_DIR / "mixin_response.dart"

# 1) + 2) 修复 Base 类
base = BASE_FILE.read_text(encoding="utf-8")
# 确保是 abstract class
if "abstract class GameProviderBase" not in base:
    base = base.replace("class GameProviderBase", "abstract class GameProviderBase", 1)
# 去掉方法前的 "abstract " 前缀 — 注意不要误伤其他地方的 abstract 单词
# 匹配: 行首  "  abstract XxxxType methodName("
base_lines = base.split("\n")
new_lines = []
for line in base_lines:
    if re.match(r"\s*abstract\s+(Future|void|bool|int|String|double|Object|dynamic)", line):
        line = re.sub(r"^(\s*)abstract\s+", r"\1", line)
    new_lines.append(line)
base = "\n".join(new_lines)

# 3) 补 import: ChatResult (npc_chat_service), CgDef (cg_data), Era (world_state), AiScene (ai_router), NPC (npc)
needed_imports = {
    "../data/cg_data.dart": "CgDef",
    "../services/npc_chat_service.dart": "ChatResult",
    "../models/world_state.dart": "Era",  # 已有 world_state import? 如果有重名就跳过
    "../services/ai_router.dart": "AiScene",
    "../models/npc.dart": "NPC",
}
existing_imports = set(re.findall(r"""import\s+['"]([^'"]+)['"]""", base))
for imp_pkg, _ in needed_imports.items():
    if imp_pkg not in existing_imports:
        # 插到最后一个 import 之后
        last_import_pos = -1
        for m in re.finditer(r"""import\s+['"]([^'"]+)['"];\n""", base):
            last_import_pos = m.end() - 1
        if last_import_pos >= 0:
            base = base[:last_import_pos+1] + f"import '{imp_pkg}';\n" + base[last_import_pos+1:]
            existing_imports.add(imp_pkg)
BASE_FILE.write_text(base, encoding="utf-8")

# 4) _standaloneNameMentioned: 在 mixin_response.dart 内搜索有没有定义，没有就加一个
resp = RESP_FILE.read_text(encoding="utf-8")
if "_standaloneNameMentioned(" not in resp.split("if (_standaloneNameMentioned")[0]:
    # 没定义 → 直接加在引用它的方法末尾（markIntroducedFromNarrative 之前？或者放在mixin尾部）
    # 先搜索其他地方有没有定义（sibling mixins / gp）
    found = False
    for f in [MIXIN_DIR / "mixin_init.dart", MIXIN_DIR / "mixin_narrative.dart",
              MIXIN_DIR / "mixin_relations.dart", MIXIN_DIR / "mixin_systems.dart", GP_FILE]:
        if "_standaloneNameMentioned" in f.read_text(encoding="utf-8"):
            found = True
            break
    if not found:
        # 把内嵌 helper 实现加到 mixin_response.dart 末尾 (mixin 闭合 } 之前)
        helper = '''
  /// 判断叙事文本中是否独立提到了某个别名（前后为非字母数字非中文字符边界）
  bool _standaloneNameMentioned(String text, String name) {
    if (name.isEmpty) return false;
    // 按标点/空白切分，整词匹配
    final escaped = RegExp.escape(name);
    final pattern = RegExp(r'(?<![\\p{L}\\p{N}_])' + escaped + r'(?![\\p{L}\\p{N}_])', unicode: true);
    return pattern.hasMatch(text);
  }
'''
        close = resp.rfind("}")
        if close >= 0:
            resp = resp[:close] + helper + "\n" + resp[close:]
            RESP_FILE.write_text(resp, encoding="utf-8")
            print("✅ _standaloneNameMentioned 嵌入 mixin_response.dart 尾部")
        else:
            print("❌ 找不到 mixin_response.dart 的闭合 }")

# 5) _formatTime 查定义
def find_global(search, root=Path("/workspace/hogwarts_life_simulator/lib")):
    results = []
    for f in root.rglob("*.dart"):
        c = f.read_text(encoding="utf-8")
        for i, line in enumerate(c.split("\n"), 1):
            if search in line:
                results.append(f"{f.relative_to(root)} L{i}: {line.strip()}")
                if len(results) > 12:
                    return results
    return results

print("\n_formatTime 定义/引用点:")
for l in find_global(r"_formatTime\s*\("):
    print("  " + l)

# 6) game_provider.dart 补 dart:math import
gp = GP_FILE.read_text(encoding="utf-8")
if "import 'dart:math'" not in gp and 'import "dart:math"' not in gp:
    lines = gp.split("\n")
    lines.insert(1, "import 'dart:math';")
    GP_FILE.write_text("\n".join(lines), encoding="utf-8")
    print("\n✅ game_provider.dart 补 dart:math import")

# 7) buildPrompt 方法：在 game_provider_base 有声明，实际定义应该在 mixin_narrative。确认一下
gp_text = Path("/workspace/hogwarts_life_simulator/lib/mixins/mixin_narrative.dart").read_text(encoding="utf-8")
m = re.search(r"(String|Future<[^>]*>|Future)\s+buildPrompt\s*\(", gp_text)
print(f"\nbuildPrompt 定义在 mixin_narrative: {bool(m)} → {m.group(0) if m else '⚠️ 未定义!'}")

# 8) _formatTime 如果没定义，给一个默认实现在 mixin_systems (时间相关)
systems_text = Path("/workspace/hogwarts_life_simulator/lib/mixins/mixin_systems.dart").read_text(encoding="utf-8")
if "String _formatTime(" not in systems_text and "String  formatTime(" not in systems_text:
    # GameProviderBase 里居然声明了 _formatTime 为抽象方法，这说明它之前在原 game_provider.dart 存在。
    # 查一下全库有没有
    found_any = False
    for f in Path("/workspace/hogwarts_life_simulator/lib").rglob("*.dart"):
        if re.search(r"String\s+_?formatTime\s*\(", f.read_text(encoding="utf-8")):
            found_any = True
            break
    if not found_any:
        # 没找到定义，我们就移除这条 abstract 声明
        base = BASE_FILE.read_text(encoding="utf-8")
        base = re.sub(r"\n\s*String\s+_formatTime\(\);\n", "\n", base)
        BASE_FILE.write_text(base, encoding="utf-8")
        print("✅ 移除了未定义的 _formatTime() abstract 声明")
    else:
        print("ℹ️  _formatTime 在某个文件中已有定义")

# 9) dispose() — GameProviderBase 里不应声明 dispose() 抽象方法，因为 ChangeNotifier 已经有了
base = BASE_FILE.read_text(encoding="utf-8")
if re.search(r"\n\s*void\s+dispose\(\);\n", base):
    base = re.sub(r"\n\s*void\s+dispose\(\);\n", "\n", base)
    BASE_FILE.write_text(base, encoding="utf-8")
    print("✅ 移除了多余的 dispose() abstract 声明 (ChangeNotifier 自带)")

print("\n=== V4 修复完成 ===")
