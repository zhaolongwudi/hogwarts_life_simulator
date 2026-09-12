#!/usr/bin/env python3
"""
P2 关键修复：跨 Mixin 私有方法调用的 public 化（去掉 _ 前缀）。
Dart 的 library 级隐私模型：即使在同一个 package，不同文件的 _ 前缀成员互不可见。
"""
import re
from pathlib import Path

MIXIN_DIR = Path("/workspace/hogwarts_life_simulator/lib/mixins")
FILES = {
    "init": MIXIN_DIR / "mixin_init.dart",
    "narrative": MIXIN_DIR / "mixin_narrative.dart",
    "commands": MIXIN_DIR / "mixin_commands.dart",
    "response": MIXIN_DIR / "mixin_response.dart",
    "relations": MIXIN_DIR / "mixin_relations.dart",
    "systems": MIXIN_DIR / "mixin_systems.dart",
}
GP_FILE = Path("/workspace/hogwarts_life_simulator/lib/providers/game_provider.dart")

def extract_methods(path: Path, is_private_only=False):
    content = path.read_text(encoding="utf-8")
    # 只取 mixin 体内部
    m = re.search(r"mixin\s+\w+\s+on\s+\w+\s*\{([\s\S]*)\Z", content)
    body = m.group(1) if m else content
    # 方法定义: 类型 _name( 或 get _name
    methods = set()
    for mm in re.finditer(r"(?:^|\n)\s*(?:void|bool|int|String|double|Future[^(]*?|[A-Z][A-Za-z0-9_<>\[\],\s\?]*?)\s+(_[a-zA-Z_][a-zA-Z0-9_]*)\s*\(", body):
        methods.add(mm.group(1))
    for mm in re.finditer(r"(?:^|\n)\s*(?:[A-Za-z0-9_<>\[\],\s\?]*?)\s+get\s+(_[a-zA-Z_][a-zA-Z0-9_]*)\s+", body):
        methods.add(mm.group(1))
    return methods

# 1. 收集每个 Mixin 定义的私有方法名
per_file_privates = {}
for name, p in FILES.items():
    per_file_privates[name] = extract_methods(p)
    print(f"[{name}] {len(per_file_privates[name])} 个私有方法定义")

all_privates = set()
for s in per_file_privates.values():
    all_privates |= s
print(f"\n合计私有方法: {len(all_privates)}")

# 2. 对于每个私有方法，检查是否有跨文件引用
cross_ref_map = {}  # method_name -> set of files that reference it
GP_CONTENT = GP_FILE.read_text(encoding="utf-8")

for priv in sorted(all_privates):
    referencing_files = set()
    # 检查每个 Mixin 文件（排除自己）
    for file_name, path in FILES.items():
        content = path.read_text(encoding="utf-8")
        # 正则匹配: 引用为 XXX( 或 this.XXX. 或 .XXX( 或 XXX)
        pattern = re.compile(r"(?:this\.)?" + re.escape(priv) + r"(?=[\s(.\),;])")
        # 排除定义行
        for i, line in enumerate(content.split("\n"), 1):
            if re.search(r"(?:void|bool|int|String|double|Future|get)\s+" + re.escape(priv) + r"\s*[\(=]", line):
                continue  # 定义行跳过
            if pattern.search(line):
                referencing_files.add(file_name)
                break
    # 检查 game_provider.dart
    pattern = re.compile(r"(?:this\.)?" + re.escape(priv) + r"(?=[\s(.\),;])")
    for i, line in enumerate(GP_CONTENT.split("\n"), 1):
        if re.search(r"(?:void|bool|int|String|double|Future|get)\s+" + re.escape(priv) + r"\s*[\(=]", line):
            continue
        if pattern.search(line):
            referencing_files.add("game_provider")
            break
    if len(referencing_files) >= 2 or (referencing_files and not any(priv in per_file_privates.get(f, set()) for f in referencing_files)):
        cross_ref_map[priv] = referencing_files

print(f"\n需要 public 化（有跨文件引用）的私有方法: {len(cross_ref_map)}")
for m, refs in sorted(cross_ref_map.items()):
    def_in = [n for n, s in per_file_privates.items() if m in s]
    print(f"  {m}  定义:[{','.join(def_in)}]  引用:[{','.join(sorted(refs))}]")

# 3. 执行替换: 定义处 + 所有引用处 全部去掉前缀下划线 (方法名 -> 同名无_)
changes_per_file = {f: 0 for f in list(FILES.values()) + [GP_FILE]}

def apply_renames(file_path: Path):
    content = file_path.read_text(encoding="utf-8")
    original = content
    for priv in cross_ref_map:
        new_name = priv[1:]  # 去掉首 _
        # 精确替换: 整词匹配，避免前缀重叠 (如 _roll -> roll 不应影响 _rolling)
        pattern = re.compile(r"(?<![a-zA-Z0-9_])" + re.escape(priv) + r"(?![a-zA-Z0-9_])")
        content, n = pattern.subn(new_name, content)
        if n > 0:
            changes_per_file[file_path] += n
    if content != original:
        file_path.write_text(content, encoding="utf-8")

for p in list(FILES.values()) + [GP_FILE]:
    apply_renames(p)

print("\n替换统计:")
for p, n in changes_per_file.items():
    print(f"  {p.relative_to(Path('/workspace/hogwarts_life_simulator'))}: {n} 处")
print("✅ Done")
