#!/usr/bin/env python3
"""
P2 最终修复：
1) 在 GameProviderBase 中声明所有"本体方法"(autoSave/updateClient/...) 的 abstract 签名，让Mixin能看见
2) 扫描 6 个 Mixin：凡 "引用发生在文件外" 的 "_xxx" 私有方法 → public化（去掉前缀 _）
3) game_provider.dart / game_provider_base.dart 补必要 import
"""
import re
from pathlib import Path
from collections import defaultdict

MIXIN_DIR = Path("/workspace/hogwarts_life_simulator/lib/mixins")
PROV_DIR = Path("/workspace/hogwarts_life_simulator/lib/providers")
FILES = {
    "mixin_init": MIXIN_DIR / "mixin_init.dart",
    "mixin_narrative": MIXIN_DIR / "mixin_narrative.dart",
    "mixin_commands": MIXIN_DIR / "mixin_commands.dart",
    "mixin_response": MIXIN_DIR / "mixin_response.dart",
    "mixin_relations": MIXIN_DIR / "mixin_relations.dart",
    "mixin_systems": MIXIN_DIR / "mixin_systems.dart",
    "game_provider": PROV_DIR / "game_provider.dart",
    "game_provider_base": PROV_DIR / "game_provider_base.dart",
}
ALL_FILES = list(FILES.values())

# ========================================================================
# STEP 1: 收集所有 "_xxx" 私有方法，以及每个方法定义所在的文件
# ========================================================================
def extract_definitions(path: Path, only_underscore=False):
    """返回 {method_name: line_no}"""
    content = path.read_text(encoding="utf-8")
    lines = content.split("\n")
    result = {}
    multi_line_buf = ""
    for i, line in enumerate(lines, 1):
        multi_line_buf += "\n" + line
        if len(multi_line_buf) > 400:
            multi_line_buf = multi_line_buf[-400:]
        # 方法定义: 类型 名字(
        # 允许多行 (前面可能有 类型行 + 名字(在下一行)
        for m in re.finditer(
            r"(?:^|\n)\s*(?:void|bool|int|String|double|Future(?:<[^>]*>)?|List<[^>]*>|Map<[^>]*>|Set<[^>]*>|Player|NpcData|NPC|WorldState|AiRouter|SaveService|Random|NpcChatService|DateTime|GameChoice|LongTermMemory|[A-Z][A-Za-z0-9_<>\[\],\s\?]*?)\s+"
            r"([a-zA-Z_][a-zA-Z0-9_]*)\s*\(",
            multi_line_buf,
        ):
            name = m.group(1)
            if only_underscore and not name.startswith("_"):
                continue
            if name not in result:
                result[name] = i
    return result

all_defs = {}  # file_key -> {method: line}
all_priv_defs = {}
for k, p in FILES.items():
    d = extract_definitions(p)
    all_defs[k] = d
    all_priv_defs[k] = {m: ln for m, ln in d.items() if m.startswith("_")}
    print(f"[{k}] 方法定义: {len(d)} 个 (私有 {len(all_priv_defs[k])})")

# ========================================================================
# STEP 2: 找出"被外部引用"的私有方法 → 需要 public 化
# ========================================================================
# 首先把下划线方法归类：定义在哪个文件
def_to_file = {}
for k, d in all_priv_defs.items():
    for m in d:
        def_to_file[m] = k

cross_reffed_privates = set()
for m, defined_in in def_to_file.items():
    referenced_in = set()
    name_pattern = re.compile(r"(?<![a-zA-Z0-9_])" + re.escape(m) + r"(?![a-zA-Z0-9_])")
    for fk, fp in FILES.items():
        if fk == defined_in:
            continue
        content = fp.read_text(encoding="utf-8")
        # 跳过注释行/import
        clean_lines = []
        for line in content.split("\n"):
            s = line.strip()
            if s.startswith("//") or s.startswith("import"):
                continue
            clean_lines.append(line)
        clean = "\n".join(clean_lines)
        if name_pattern.search(clean):
            referenced_in.add(fk)
    if referenced_in:
        cross_reffed_privates.add(m)
        print(f"  → {m} (定义在 {defined_in}) → 被 {sorted(referenced_in)} 引用 → public化")

print(f"\n合计需要 public 化的私有方法: {len(cross_reffed_privates)}")

# ========================================================================
# STEP 3: 跨全库进行 "下划线 → 去下划线"的精确整词替换
# ========================================================================
rename_map = {old: old[1:] for old in cross_reffed_privates}

# 同时，处理另一个case：GameProvider 本体中定义但被Mixin引用的 public 方法（autoSave/updateNpcAffection等）
# 不需要改名字，只需在 GameProviderBase 中加 abstract 声明即可
# 但如果 game_provider 中的方法在 GameProviderBase 中没声明，Mixin 引用时仍然找不到

# 先看 game_provider.dart 中定义的所有 public 方法
gp_methods = set(all_defs.get("game_provider", {}).keys())
gp_methods.discard("GameProvider")  # 构造函数不算
print(f"\nGameProvider 本体 public 方法: {sorted(gp_methods)}")

# 找出哪些被Mixin引用
body_referenced_from_mixin = set()
for m in gp_methods:
    pat = re.compile(r"(?<![a-zA-Z0-9_])" + re.escape(m) + r"(?![a-zA-Z0-9_])")
    for fk in ["mixin_init", "mixin_narrative", "mixin_commands", "mixin_response", "mixin_relations", "mixin_systems"]:
        if fk == "game_provider":
            continue
        if pat.search(FILES[fk].read_text(encoding="utf-8")):
            body_referenced_from_mixin.add(m)
            break
print(f"GameProvider本体方法 被Mixin引用: {sorted(body_referenced_from_mixin)}")

# ========================================================================
# 执行 private→public 替换
# ========================================================================
replace_counts = defaultdict(int)
for fk, fp in FILES.items():
    if fk == "game_provider_base":
        continue  # base里不应该有_前缀私有方法引用
    content = fp.read_text(encoding="utf-8")
    for old, new in rename_map.items():
        pat = re.compile(r"(?<![a-zA-Z0-9_])" + re.escape(old) + r"(?![a-zA-Z0-9_])")
        content, n = pat.subn(new, content)
        if n:
            replace_counts[fk] += n
    fp.write_text(content, encoding="utf-8")

print("\nprivate→public 替换统计:")
for fk, n in replace_counts.items():
    print(f"  {fk}: {n} 处")

# ========================================================================
# STEP 4: 修复 GameProviderBase 中 abstract 方法/字段声明
# ========================================================================
# 我们需要从 GameProvider 中抽取方法签名，写成 abstract 形式加进 Base
gp_content = FILES["game_provider"].read_text(encoding="utf-8")
# 提取带完整签名的方法（包含返回类型 + 方法名 + 参数）
method_signatures = []
for m in re.finditer(
    r"(?<=\n)\s*(Future<[^>]*>|Future|void|bool|int|String|double)\s+"
    r"(\w+)\s*\(([^)]*)\)\s*(?:async\s*)?\{",
    "\n" + gp_content,
):
    ret, name, params = m.group(1), m.group(2), m.group(3)
    if name in ("GameProvider",):
        continue
    if "{" in params:
        continue
    sig = f"  {ret} {name}({params});"
    method_signatures.append((name, sig))

print(f"\nGameProvider 可抽取 abstract 方法 {len(method_signatures)} 个:")
for n, s in method_signatures:
    if n in body_referenced_from_mixin:
        print(f"  ★ {s}")
    else:
        print(f"    {s}")

# 抽取 import 列表：game_provider_base 已 import 什么, game_provider还需要什么
base_imports = set(re.findall(r"""import\s+['"]([^'"]+)['"]""", FILES["game_provider_base"].read_text(encoding="utf-8")))
needed_extra = {
    'package:flutter/foundation.dart': 1,  # 用于 Random/dart:math → 实际是 dart:math
    '../models/game_systems.dart': 1,
}
# 把这些 append 到 game_provider_base.dart
base_content = FILES["game_provider_base"].read_text(encoding="utf-8")
# 先确保有 dart:math
if "import 'dart:math';" not in base_content and 'import "dart:math";' not in base_content:
    base_content = base_content.replace("import 'dart:math';", "")
    base_lines = base_content.split("\n")
    base_lines.insert(1, "import 'dart:math';")
    base_content = "\n".join(base_lines)
# 添加 game_systems.dart import
if "game_systems.dart" not in base_content:
    idx = base_content.find("import '../models/world_state.dart';")
    if idx >= 0:
        base_content = base_content[:idx] + "import '../models/game_systems.dart';\n" + base_content[idx:]
FILES["game_provider_base"].write_text(base_content, encoding="utf-8")

# 给 game_provider_base.dart 末尾 append abstract 方法签名 (在 最后一个 '}' 之前插入)
base_content = FILES["game_provider_base"].read_text(encoding="utf-8")
# 找最后一个 } 位置 (GameProviderBase 类的闭合)
close_pos = base_content.rfind("}")
if close_pos >= 0:
    sig_block_lines = ["\n  // 以下方法由 GameProvider 本体 (extends GameProviderBase) @override 实现",
                       "  // 此处声明为 abstract，从而让 6 个 Mixin (`on GameProviderBase`) 能看见并调用"]
    for n, s in method_signatures:
        sig_block_lines.append(s)
    sig_block = "\n".join(sig_block_lines) + "\n"
    base_content = base_content[:close_pos] + sig_block + base_content[close_pos:]
FILES["game_provider_base"].write_text(base_content, encoding="utf-8")

# ========================================================================
# STEP 5: game_provider.dart 本身也要补 import
# 它里面使用了 Player / WorldState / NPC / GameChoice / LongTermMemory / Random
# 这些类可能通过 Base 间接 import 了，但为了保险起见也在 game_provider.dart 显式加上
# ========================================================================
gp = FILES["game_provider"].read_text(encoding="utf-8")
needed_model_imports = [
    "import '../models/player.dart';",
    "import '../models/world_state.dart';",
    "import '../models/npc.dart';",
    "import '../models/game_systems.dart';",
    "import '../models/long_term_memory.dart';",
]
for imp in needed_model_imports:
    quoted = imp.split("'")[1] if "'" in imp else imp.split('"')[1]
    if quoted not in gp:
        # 找到最后一个 import 的行位置并插入
        lines = gp.split("\n")
        last_import_idx = max(
            [i for i, l in enumerate(lines) if l.strip().startswith("import")]
        )
        lines.insert(last_import_idx + 1, imp)
        gp = "\n".join(lines)
FILES["game_provider"].write_text(gp, encoding="utf-8")

print("\n✅ 脚本完成: \n"
      f"  - {len(rename_map)} 个私有方法 public 化\n"
      f"  - {len(method_signatures)} 个 GameProvider 本体方法在 Base 声明 abstract\n"
      f"  - game_provider_base.dart 补 2 个 import (dart:math, game_systems)\n"
      f"  - game_provider.dart 补 5 个 model import")
