#!/usr/bin/env python3
"""
终极修复：Mixin间互不可见（Dart静态分析限制）。
- 扫描所有 6 个 Mixin + GameProvider 本体的 public 方法定义
- 扫描所有引用：凡 "定义位置!=引用位置" 的public方法，统一在 GameProviderBase 做 abstract 声明
"""
import re
from pathlib import Path
from collections import defaultdict

MIXIN_DIR = Path("/workspace/hogwarts_life_simulator/lib/mixins")
PROV_DIR = Path("/workspace/hogwarts_life_simulator/lib/providers")
KEY_FILES = {
    "init": MIXIN_DIR / "mixin_init.dart",
    "narrative": MIXIN_DIR / "mixin_narrative.dart",
    "commands": MIXIN_DIR / "mixin_commands.dart",
    "response": MIXIN_DIR / "mixin_response.dart",
    "relations": MIXIN_DIR / "mixin_relations.dart",
    "systems": MIXIN_DIR / "mixin_systems.dart",
    "gp": PROV_DIR / "game_provider.dart",
}
BASE_FILE = PROV_DIR / "game_provider_base.dart"

def extract_method_sigs(path: Path):
    """返回 [(method_name, signature_line, return_type)]"""
    content = path.read_text(encoding="utf-8")
    # 匹配: 返回类型 方法名(参数列表)  { 或 async {
    # 允许跨行：(参数部分可以包含 {, }, <, >, [, ])
    results = []
    i = 0
    lines = content.split("\n")
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        # 跳过行首注释
        if stripped.startswith("//") or stripped.startswith("import") or stripped.startswith("export"):
            i += 1
            continue
        # 匹配 "返回类型 方法名("
        m = re.match(
            r"\s*(Future<[^>]*>|Future|void|bool|int|String|double|num|Object|dynamic|"
            r"List<[^>]*>|Map<[^>]*>|Set<[^>]*>|Iterable<[^>]*>|"
            r"[A-Z][A-Za-z0-9_<>\[\],\s\?]*?)\s+"
            r"([a-zA-Z_][a-zA-Z0-9_]*)\s*\(",
            line,
        )
        if not m:
            i += 1
            continue
        ret, name = m.group(1), m.group(2)
        if ret in {"if", "switch", "for", "while", "return", "catch", "throw"}:
            i += 1
            continue
        if name in {"if", "mixin", "class", "for"}:
            i += 1
            continue
        # 拼接完整括号平衡后的 "(" + ")"
        open_paren = 1
        start_col = line.find("(", m.start())
        param_buf = line[start_col + 1:]
        full_line = line
        j = i
        while open_paren > 0 and j < len(lines) - 1:
            for ch in param_buf:
                if ch == "(" and not (j > i or ch != "("):  # rough
                    pass
            # use a simpler counter for the whole concatenated body
            cnt_start = j
            buf_tail = "\n".join(lines[i:j + 2]) if j + 1 < len(lines) else "\n".join(lines[i:])
            break_outer = False
            # simpler approach: just concatenate lines until paren balance
            all_params = ""
            idx = start_col + 1
            lines_copy = lines[i:]
            lc = 0
            while open_paren > 0 and lc < len(lines_copy):
                cl = lines_copy[lc]
                start_idx = idx if lc == 0 else 0
                for ci in range(start_idx, len(cl)):
                    c = cl[ci]
                    if c == "(":
                        open_paren += 1
                    elif c == ")":
                        open_paren -= 1
                        if open_paren == 0:
                            break
                    all_params += c
                lc += 1
            j = i + lc - 1
            full_line = " ".join(lines[i:j + 1])
            break
        sig = f"{ret} {name}({all_params.strip()});"
        results.append((name, sig, ret))
        i = j + 1
    return results

# 1. 收集每个文件的方法
defs_per_file = {}
for k, p in KEY_FILES.items():
    defs_per_file[k] = extract_method_sigs(p)
    print(f"[{k}] {len(defs_per_file[k])} 方法")

# 2. 方法 -> { 定义在哪些文件 }
method_locations = defaultdict(set)
method_sigs = {}  # method -> first seen full sig
for k, sigs in defs_per_file.items():
    for name, sig, ret in sigs:
        method_locations[name].add(k)
        if name not in method_sigs:
            method_sigs[name] = sig
            if ";" not in sig:
                method_sigs[name] = sig.rstrip()

# 3. 扫描所有文件的引用，找出 "引用文件 != 所有定义文件" 的那些
# 注意：也包括 game_provider_base.dart 和 screens 中的引用
ALL_DART = list(Path("/workspace/hogwarts_life_simulator/lib").rglob("*.dart"))

needed_abs = defaultdict(set)  # method -> set of files that reference it from outside its home
for f in ALL_DART:
    content = f.read_text(encoding="utf-8")
    # 简化引用查找: \bmethodName\s*\(
    fkey = None
    for k, p in KEY_FILES.items():
        if f.resolve() == p.resolve():
            fkey = k
            break
    # 排除定义行：检查 method 是否是在此文件中定义
    methods_defined_here = set()
    if fkey:
        for name, s, r in defs_per_file[fkey]:
            methods_defined_here.add(name)
    for method in list(method_sigs.keys()):
        if len(method) < 3:
            continue
        if method in methods_defined_here:
            continue
        # 找引用: 后面跟 ( 或 .method(
        pat = re.compile(r"(?<!\w)" + re.escape(method) + r"\s*\(")
        if pat.search(content):
            # 确实被引用了，而且定义不在本文件
            # 把方法加入 to-abstract 集合
            needed_abs[method].add(str(f.relative_to(PROV_DIR.parent.parent / "lib")))

print(f"\n需要在 GameProviderBase 做 abstract 声明的跨文件方法: {len(needed_abs)}")

# 4. 同时，之前的 abstract 抽取可能把 tryAutoLoad / updateApiKey 等参数截断了。重抽。
# 先用 KEY_FILES["gp"] 重新用一个更简单的策略提取签名
def extract_sigs_simple(path):
    content = path.read_text(encoding="utf-8")
    results = []
    for m in re.finditer(
        r"(?<=\n)\s*(Future<[^>]*?>|Future|void|bool|int|String|double)\s+(\w+)\s*\(([^)]*)\)",
        "\n" + content,
    ):
        ret, name, params = m.group(1), m.group(2), m.group(3)
        if name in {"GameProvider", "import"}:
            continue
        sig = f"{ret} {name}({params});".replace("  ", " ")
        results.append((name, sig))
    return results

gp_sigs = extract_sigs_simple(KEY_FILES["gp"])

# 5. 合并 needed_abs + gp_sigs
all_sigs_by_name = {}
# 先加入 gp_sigs
for n, s in gp_sigs:
    all_sigs_by_name[n] = s
# 然后加入 method_sigs (优先 gp_sigs 的精确版本，如果 gp_sigs 没有的话)
for n, s in method_sigs.items():
    if n in needed_abs and n not in all_sigs_by_name:
        all_sigs_by_name[n] = s
# 再把 needed_abs 中遗漏的 gp 方法加进去
for n, s in gp_sigs:
    all_sigs_by_name[n] = s

# 过滤: 只保留出现在 needed_abs 中 或 gp 的 9 个本体方法
wanted = set(needed_abs.keys()) | {n for n, _ in gp_sigs}

# 6. 清理 GameProviderBase 中原有的 abstract 段，重新写入
base_content = BASE_FILE.read_text(encoding="utf-8")

# 删除旧的 abstract 段 (从 "  // 以下方法由 GameProvider 本体" 开始直到 类结束 })
old_marker_start = base_content.find("  // 以下方法由 GameProvider 本体")
old_marker_end = base_content.rfind("}")
if old_marker_start >= 0:
    base_content = base_content[:old_marker_start].rstrip() + "\n" + base_content[old_marker_end:]

# 找到类最后一个 }
last_close = base_content.rfind("}")
if last_close < 0:
    print("❌ 找不到 GameProviderBase 类的闭合 }")
    exit(1)

# 按字母排序生成 abstract 块
lines_block = [
    "",
    "  // ============================================================",
    "  // 跨 Mixin 调用 与 GameProvider 本体方法的 abstract 声明。",
    "  // Dart 3 的 Mixin 静态分析只认识 `on X` 中的 X 类成员，不认识",
    "  // 同一最终类中 `with A, B, C` 的其他 Mixin 的方法，所以这里统一声明。",
    "  // 实现由：GameProvider 本体 / 6 个 Mixin 分别提供 @override。",
    "  // ============================================================",
]
for name in sorted(wanted):
    sig = all_sigs_by_name.get(name)
    if not sig:
        # 用最通用的兜底：dynamic XXX(...) 不行，必须严格匹配。
        # 尝试从任意 KEY_FILE 中直接 grep
        for fk, fp in KEY_FILES.items():
            c = fp.read_text(encoding="utf-8")
            m = re.search(
                r"(Future<[^>]*?>|Future|void|bool|int|String|double|Object|dynamic)\s+"
                + re.escape(name) + r"\s*\(([^)]*)\)",
                c,
            )
            if m:
                sig = f"{m.group(1)} {name}({m.group(2)});"
                break
        if not sig:
            sig = f"void {name}();  // TODO(fallback): 未能抽取精确签名"
            print(f"  ⚠️  {name} 签名抽取失败 → 兜底 void {name}();")
    lines_block.append("  abstract " + sig if not sig.startswith("abstract ") else sig)

lines_block.append("")
new_block = "\n".join(lines_block)

new_base = base_content[:last_close] + new_block + base_content[last_close:]
BASE_FILE.write_text(new_base, encoding="utf-8")

print(f"\n✅ 已写入 GameProviderBase: {len(lines_block)-3} 条 abstract 方法声明")

# 7. 最后：game_provider.dart 中那些加了 abstract 的方法要显式写 @override
# （Dart 3 中 abstract 方法实现不加 @override 通常不报错，但如果 Dart analyze 开启 strict-raw-types 可能提示）
# 检查一个典型方法：
gp = KEY_FILES["gp"].read_text(encoding="utf-8")
added = 0
for n, s in gp_sigs:
    # s e.g. "Future<void> autoSave();"
    # 在 gp 内容里找："Future<void> autoSave() async {" → 前面加 @override
    ret = s.split(" ")[0]
    params_match = s[s.find("(") : s.find(";")]
    pattern_sig = re.escape(f"{ret} {n}{params_match}")
    def_pat = re.compile(pattern_sig + r"\s*(?:async\s*)?\{")
    m = def_pat.search(gp)
    if m:
        target = m.group(0)
        if "@override" not in gp[: m.start()][-30:]:
            new_target = "@override\n  " + target
            gp = gp.replace(target, new_target, 1)
            added += 1
KEY_FILES["gp"].write_text(gp, encoding="utf-8")
print(f"✅ GameProvider 补 @override 注解: {added} 处")
