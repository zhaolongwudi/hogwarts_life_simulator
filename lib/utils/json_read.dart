/// 外来 JSON（旧存档 / 导入存档 / 外部接口返回）的宽容读取工具。
///
/// 背景（审查 F3）：`Player.fromJson` 等反序列化入口过去大量直接
/// `json['field']` 透传 dynamic，或者 `xxx as String` 硬转。老存档里
/// 字段一旦类型漂移（数值存成字符串、字段被手改、缺省等），fromJson 就抛
/// 类型异常，整份存档读不出来、玩家只能清零重来。
///
/// 设计原则：
/// - **宽容但不纵容**：取得到合法值就取，取不到回退到 fallback，绝不抛
///   类型 error —— 把「整份读档失败」降级成「该字段用默认值」。
/// - 数值区分度保留：int 字段用 `readInt`、double 字段用 `readDouble`，
///   不把小数静默读成整数 —— float 读成 int 属于数据损坏，不该被"宽容"
///   消化掉。
/// - 可选字段（`*OrNull`）只认合法形态，非法与其返回坏值不如返回 null，
///   由上层按"缺省"处理。
library;

/// 读 String。数字 / 布尔会转成字符串形态（保持"内容还在"），
/// 取不到或非法 → [fallback]。
String readString(Object? v, {String fallback = ''}) {
  if (v == null) return fallback;
  if (v is String) return v;
  if (v is num || v is bool) return v.toString();
  return fallback;
}

/// 读 String（可选）。null 或非 String 形态一律返回 null。
///
/// 与 [readString] 的区别：这里**不**把数字/布尔转成字符串——
/// 可选字段的语义是"缺省"，给错类型按缺省处理比硬转更安全。
String? readStringOrNull(Object? v) {
  if (v is String) return v;
  return null;
}

/// 读 int。接受 int、double 整数、数字字符串、bool(1/0)。
/// 取不到或非法 → [fallback]。
int readInt(Object? v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is bool) return v ? 1 : 0;
  if (v is String) {
    final t = v.trim();
    if (t.isEmpty) return fallback;
    final n = num.tryParse(t);
    if (n != null) return n.toInt();
  }
  return fallback;
}

/// 读 int（可选）。null 或非法形态返回 null。
int? readIntOrNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  if (v is String) {
    final t = v.trim();
    if (t.isEmpty) return null;
    final n = num.tryParse(t);
    if (n != null) return n.toInt();
  }
  return null;
}

/// 读 double。接受 double、int、数字字符串。
/// 取不到或非法 → [fallback]。
double readDouble(Object? v, {double fallback = 0.0}) {
  if (v == null) return fallback;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) {
    final t = v.trim();
    if (t.isEmpty) return fallback;
    final n = num.tryParse(t);
    if (n != null) return n.toDouble();
  }
  return fallback;
}

/// 读 bool。接受 true/false、1/0、"true"/"false"（大小写不敏感）、
/// "1"/"0"。取不到或非法 → [fallback]。
bool readBool(Object? v, {bool fallback = false}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final t = v.trim().toLowerCase();
    if (t == 'true' || t == '1') return true;
    if (t == 'false' || t == '0') return false;
  }
  return fallback;
}

/// 读 String 列表（可选）。把每个标量元素转成 String，非标量（嵌套
/// Map/List）元素丢弃；取不到或非法 → [fallback]（默认空列表）。
///
/// 注意：`List<String>.from` 遇非 String 元素会抛异常，这里改为"过滤掉
/// 坏元素"——既不崩整份读档，也不把坏数据留进列表。
List<String> readStringList(Object? v, {List<String>? fallback}) {
  if (v is List) {
    return v
        .where((e) => e is String || e is num || e is bool)
        .map((e) => e.toString())
        .toList();
  }
  return fallback ?? const <String>[];
}