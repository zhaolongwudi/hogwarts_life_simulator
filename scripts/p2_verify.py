#!/usr/bin/env python3
"""P2 阶段深度静态核查：import/引用/括号/重复方法"""
import os
import re
import sys
from pathlib import Path

LIB = Path("/workspace/hogwarts_life_simulator/lib")

# ============== 1. 收集所有 .dart 文件 ==============
dart_files = list(LIB.rglob("*.dart"))
print(f"[1/6] 扫描到 {len(dart_files)} 个 .dart 文件\n")

# ============== 2. 检查 import 路径存在性 ==============
print("[2/6] 检查 import 路径...")
import_errors = []
for f in dart_files:
    content = f.read_text(encoding="utf-8")
    for m in re.finditer(r"""import\s+['"]([^'"]+)['"]""", content):
        imp = m.group(1)
        if imp.startswith("dart:") or imp.startswith("package:"):
            continue  # SDK/依赖跳过
        if imp.startswith("../") or imp.startswith("./") or not imp.startswith("/"):
            # 相对路径
            target = (f.parent / imp).resolve()
        else:
            target = Path(imp)
        if not target.exists():
            import_errors.append(f"  ❌ {f.relative_to(LIB)} -> {imp}")

if import_errors:
    print("\n".join(import_errors))
else:
    print("  ✅ 所有相对路径 import 均存在")

# ============== 3. 括号平衡检查 ==============
print("\n[3/6] 括号平衡检查...")
brace_errors = []
for f in dart_files:
    content = f.read_text(encoding="utf-8")
    # 移除字符串字面量中的括号
    stripped = re.sub(r"r?'''[\s\S]*?'''", "", content)
    stripped = re.sub(r'r?"""[\s\S]*?"""', "", stripped)
    stripped = re.sub(r"'(?:\\.|[^'\\])*'", "''", stripped)
    stripped = re.sub(r'"(?:\\.|[^"\\])*"', '""', stripped)
    # 移除注释
    stripped = re.sub(r"//[^\n]*", "", stripped)
    stripped = re.sub(r"/\*[\s\S]*?\*/", "", stripped)

    stack = []
    pairs = {"{": "}", "(": ")", "[": "]"}
    line_map = {}
    line_no = 1
    for i, ch in enumerate(stripped):
        if ch == "\n":
            line_no += 1
        if ch in "{([":
            stack.append((ch, line_no))
        elif ch in "})]":
            if not stack:
                brace_errors.append(f"  ❌ {f.relative_to(LIB)} L{line_no}: 多余的 {ch}")
                break
            open_ch, open_line = stack.pop()
            if pairs[open_ch] != ch:
                brace_errors.append(f"  ❌ {f.relative_to(LIB)} L{line_no}: {open_ch} 与 {ch} 不匹配 (open L{open_line})")
                break
    if stack:
        for open_ch, open_line in stack[-5:]:
            brace_errors.append(f"  ❌ {f.relative_to(LIB)} L{open_line}: {open_ch} 未闭合")

if brace_errors:
    print("\n".join(brace_errors))
else:
    print("  ✅ 所有文件括号平衡")

# ============== 4. 提取 GameProvider 类及 6 Mixin 中的所有方法/字段定义 ==============
print("\n[4/6] 提取 GameProvider + 6 Mixin 成员定义...")

def extract_members(file_path, class_ctx_regex):
    """提取类/mixin 中方法名和字段名"""
    content = Path(file_path).read_text(encoding="utf-8")
    # 提取 class 或 mixin 块
    m = re.search(class_ctx_regex, content, re.MULTILINE)
    if not m:
        return set(), set(), content
    body = m.group(1)
    # 方法名: 返回类型 方法名(
    methods = set()
    for mm in re.finditer(r"(?:^|\n)\s*(?:void|bool|int|String|double|Future(?:<[^>]*>)?|List<[^>]*>|Map<[^>]*>|Set<[^>]*>|Player|NpcData|WorldState|AiRouter|SaveService|Random|NpcChatService|DateTime|GameChoice|[A-Z][A-Za-z0-9_<>\[\],\s]*?)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(", body):
        methods.add(mm.group(1))
    # getters
    for mm in re.finditer(r"(?:^|\n)\s*(?:[A-Za-z0-9_<>\[\],\s]*?)\s+get\s+([a-zA-Z_][a-zA-Z0-9_]*)\s+", body):
        methods.add(mm.group(1))
    # 字段名 (非 final 且带类型/不带类型)
    fields = set()
    for fm in re.finditer(r"(?:^|\n)\s*(?:late\s+)?(?:final\s+)?(?:[A-Z][A-Za-z0-9_<>\[\],\s\?]*?)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*[=;]", body):
        fields.add(fm.group(1))
    return methods, fields, body

gp_methods, gp_fields, gp_body = extract_members(
    LIB / "providers/game_provider.dart",
    r"class GameProvider extends ChangeNotifier.*?\{([\s\S]*)\Z"
)

mixin_infos = {
    "GameInitMixin": LIB / "mixins/mixin_init.dart",
    "GameNarrativeMixin": LIB / "mixins/mixin_narrative.dart",
    "GameCommandsMixin": LIB / "mixins/mixin_commands.dart",
    "GameResponseMixin": LIB / "mixins/mixin_response.dart",
    "GameRelationsMixin": LIB / "mixins/mixin_relations.dart",
    "GameSystemsMixin": LIB / "mixins/mixin_systems.dart",
}

all_methods = {}
all_fields = {}
bodies = {}
duplicates = []
total_mixin_methods = 0
for name, path in mixin_infos.items():
    regex = rf"mixin {name} on GameProvider\s*\{{([\s\S]*)\Z"
    ms, fs, body = extract_members(path, regex)
    all_methods[name] = ms
    all_fields[name] = fs
    bodies[name] = body
    total_mixin_methods += len(ms)
    # 检查内部重复
    seen_m = {}
    for line_idx, line in enumerate(body.split("\n"), 1):
        for mm in re.finditer(r"(?:void|bool|int|String|double|Future[^(]*?|[A-Z][A-Za-z0-9_<>\[\],\s]*?)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(", line):
            mname = mm.group(1)
            if mname in seen_m:
                duplicates.append(f"  ⚠️  {name} 内部方法重复: {mname} (L{seen_m[mname]} & L{line_idx})")
            seen_m[mname] = line_idx

# 跨 Mixin 重复检查
for i, (n1, ms1) in enumerate(all_methods.items()):
    for n2, ms2 in list(all_methods.items())[i+1:]:
        overlap = ms1 & ms2
        for m in overlap:
            if m in ("toString", "noSuchMethod", "runtimeType", "hashCode"):
                continue
            duplicates.append(f"  ⚠️  跨 Mixin 方法重复: {n1} ∩ {n2} -> {m}")

print(f"  GameProvider 本体: {len(gp_methods)} 方法, {len(gp_fields)} 字段")
for n in mixin_infos:
    print(f"  {n}: {len(all_methods[n])} 方法, {len(all_fields[n])} 字段")
print(f"  Mixin 合计: {total_mixin_methods} 方法")
if duplicates:
    print("\n" + "\n".join(duplicates))
else:
    print("  ✅ 无重复方法定义")

# ============== 5. GameProvider + Mixin 成员引用交叉检查 ==============
print("\n[5/6] 成员引用交叉检查 (Mixin内引用的方法/字段必须在聚合中存在)...")
all_available_methods = set(gp_methods)
all_available_fields = set(gp_fields)
for ms in all_methods.values():
    all_available_methods |= ms
for fs in all_fields.values():
    all_available_fields |= fs

# 静态成员 (regex)
static_members = set()
gp_content = (LIB / "providers/game_provider.dart").read_text(encoding="utf-8")
for sm in re.finditer(r"static\s+(?:const\s+|final\s+)?(?:RegExp|String|int|List<[^>]*>|Map<[^>]*>)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*[=;]", gp_content):
    static_members.add(sm.group(1))
print(f"  GameProvider 静态成员: {sorted(static_members)}")

missing_refs = []
# 已知安全忽略 (来自dart SDK/ChangeNotifier等)
ignore_calls = {
    "notifyListeners", "toString", "noSuchMethod", "hashCode", "runtimeType",
    "addListener", "removeListener", "dispose",
    "saveToJson", "loadFromJson", "toMap", "fromMap",  # 可能在model中
    "addPostFrameCallback",  # WidgetsBinding
    "read", "watch",  # Provider
    "of", "pop", "push", "showDialog", "showModalBottomSheet",  # Flutter导航
    "print", "debugPrint", "sleep", "exit", "stderr", "stdout",
    "nextInt", "nextBool", "nextDouble",  # Random
    "jsonEncode", "jsonDecode",  # dart:convert
    "substring", "split", "replaceAll", "replaceFirst", "trim", "toLowerCase", "toUpperCase",
    "contains", "startsWith", "endsWith", "indexOf", "lastIndexOf",
    "length", "isEmpty", "isNotEmpty", "first", "last", "single",
    "add", "addAll", "remove", "removeAt", "clear", "insert", "forEach", "map", "where", "reduce", "fold",
    "toList", "toSet", "join", "take", "skip", "cast",
    "keys", "values", "entries", "putIfAbsent",
    "copyWith", "toIso8601String", "difference", "add", "subtract",  # DateTime
    "year", "month", "day", "hour", "minute", "second", "weekday",
    "isNaN", "isInfinite", "abs", "round", "floor", "ceil", "toInt", "toDouble",
    "clamp", "remainder",
    "call", "then", "catchError", "whenComplete", "timeout",  # Future
    "microseconds", "milliseconds", "seconds", "minutes", "hours", "days",  # Duration
}

# 收集所有模型类的字段/方法名作为安全忽略
model_methods = set()
for f in list((LIB / "models").glob("*.dart")):
    c = f.read_text(encoding="utf-8")
    for cm in re.finditer(r"(?:^|\n)\s*(?:void|bool|int|String|double|Future[^(]*?|[A-Z][A-Za-z0-9_<>\[\],\s]*?)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(", c):
        model_methods.add(cm.group(1))
    for cm in re.finditer(r"(?:^|\n)\s*(?:late\s+)?(?:final\s+)?(?:[A-Z][A-Za-z0-9_<>\[\],\s\?]*?)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*[=;]", c):
        model_methods.add(cm.group(1))
ignore_calls |= model_methods

# 收集 pet_data / world_rules / game_systems 等顶层函数
for f in list((LIB / "data").glob("*.dart")) + list((LIB / "models").glob("*.dart")) + list((LIB / "services").glob("*.dart")):
    if not f.exists():
        continue
    c = f.read_text(encoding="utf-8")
    for fm in re.finditer(r"(?:^|\n)(?:void|bool|int|String|double|Future[^(]*?|[A-Z][A-Za-z0-9_<>\[\],\s]*?)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(", c):
        ignore_calls.add(fm.group(1))

def check_body_refs(body, src_name):
    # 匹配 this.xxx 或 xxx( 或 xxx.xxx
    # 提取方法调用: xxx(
    calls = set()
    for cm in re.finditer(r"(?:this\.)?([a-zA-Z_][a-zA-Z0-9_]*)\s*\(", body):
        calls.add(cm.group(1))
    # 提取字段访问: xxx.xxx (this.xxx 或 无 this.)
    field_access = set()
    for fm in re.finditer(r"this\.([a-zA-Z_][a-zA-Z0-9_]*)", body):
        field_access.add(fm.group(1))
    # 静态引用: GameProvider.xxx
    static_refs = set()
    for sm in re.finditer(r"GameProvider\.([a-zA-Z_][a-zA-Z0-9_]*)", body):
        static_refs.add(sm.group(1))

    issues = []
    for c_name in calls:
        if c_name in ignore_calls:
            continue
        if c_name in all_available_methods or c_name in static_members:
            continue
        # 检查是不是构造函数名 (大写开头)
        if c_name and c_name[0].isupper():
            continue
        # 可能是局部函数 / lambda 参数调用 - 模糊放过，只报警告级
        issues.append(f"    ? 调用方法未在聚合中定义: {c_name}")

    for f_name in field_access:
        if f_name in ignore_calls or f_name in all_available_fields or f_name in all_available_methods:
            continue
        issues.append(f"    ❌ this.{f_name} 字段不存在")

    for s_name in static_refs:
        if s_name in static_members or s_name in all_available_methods or s_name in all_available_fields:
            continue
        issues.append(f"    ❌ GameProvider.{s_name} 静态成员不存在")

    if issues:
        missing_refs.append(f"  ⚠️  {src_name} 可疑引用:\n" + "\n".join(issues))

# 只查 GameProvider 本体 + 6 个 Mixin
check_body_refs(gp_body, "GameProvider")
for name in mixin_infos:
    check_body_refs(bodies[name], name)

if missing_refs:
    print("\n".join(missing_refs))
else:
    print("  ✅ 所有 this.xxx 字段和 GameProvider.xxx 静态成员引用均存在 (方法调用模糊匹配通过)")

# ============== 6. Screen层 import GameProvider 路径核查 ==============
print("\n[6/6] Screen层 GameProvider 引用路径检查...")
screen_issues = []
for f in dart_files:
    if "screens" not in str(f.relative_to(LIB)) and "widgets" not in str(f.relative_to(LIB)):
        continue
    content = f.read_text(encoding="utf-8")
    if "GameProvider" not in content and "game_provider" not in content:
        continue
    # 找 import
    imports = re.findall(r"""import\s+['"]([^'"]*game_provider[^'"]*)['"]""", content)
    if not imports:
        # 可能通过 barrel 导入
        if "Provider.of<GameProvider>" in content or "context.watch<GameProvider>" in content:
            screen_issues.append(f"  ⚠️  {f.relative_to(LIB)} 使用了 GameProvider 但未见对应 import (可能通过barrel)")

if screen_issues:
    print("\n".join(screen_issues))
else:
    print("  ✅ Screen层引用路径合理")

# ============== Summary ==============
print("\n" + "=" * 60)
print(f"核查汇总: import错误={len(import_errors)}, 括号错误={len(brace_errors)}, 方法重复={len(duplicates)}, 引用问题={len(missing_refs)}, Screen引用={len(screen_issues)}")
total_issues = len(import_errors) + len(brace_errors) + len(duplicates) + len(missing_refs) + len(screen_issues)
if total_issues == 0:
    print("🎉 6项静态核查全部通过")
    sys.exit(0)
else:
    print(f"⚠️  发现 {total_issues} 个警告/错误，请人工复核")
    sys.exit(1 if len(import_errors) + len(brace_errors) > 0 else 0)
