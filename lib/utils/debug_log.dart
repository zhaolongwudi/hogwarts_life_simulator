import 'package:flutter/foundation.dart';

/// 全库唯一的调试日志出口（审查 F26 / S3）。
///
/// 背景：此前 17 个文件、84 处直接调用 `debugPrint`。`debugPrint` 只做**节流**、
/// 不做**环境判断**，所以 release 构建里照样往 stdout 写；而 AI 链路的日志里
/// 带着完整 prompt、response 与 Key 片段，等于把用户对话内容输出到系统日志。
///
/// 这里一次性解决两件事：
/// 1. release 静默 —— `kDebugMode` 为 false 时直接返回；
/// 2. 保留 `debugPrint` 的签名，替换零成本（[debugLog] 与 [debugPrint] 参数一致）。
///
/// 注意：调用点的字符串插值在 release 里照样会被求值（Dart 没有宏），
/// 所以**真正的热路径**（如文本渲染）不要加日志；本项目 84 处全在异常分支与
/// 回合边界，代价可忽略。
void debugLog(String? message, {int? wrapWidth}) {
  if (!kDebugMode) return;
  debugPrint(message, wrapWidth: wrapWidth);
}

/// 敏感信息脱敏（审查 S2 / S3）。
///
/// 崩溃日志会持久化 `error`、`stackTrace` 与 `extra` 三个字段：
/// AI 链路抛出的异常 message 里经常带着请求体、Authorization 头或 Key 片段，
/// 直接落盘等于把密钥写进设备文件。落盘前统一过一遍这个函数。
///
/// 匹配三类：
/// - `sk-xxx` / `Bearer xxx` 这类一眼可辨的凭证；
/// - `apiKey: xxx`、`token=xxx`、`password: xxx` 这类键值；
/// - URL query 里的 `?key=`/`&token=` 参数。
///
/// 设计取舍：**只脱「认得出来的凭证」，不做形态猜测**。
/// 早先的版本还加了一条「长度 ≥ 32 的 hex/base64 长串一律打码」，实测会把
/// 堆栈里的文件路径、package 名、UUID 一起吃掉 —— 日志失去定位能力，
/// 而这三种可辨认的形式已经覆盖了 Key 出现在异常 message 里的绝大多数情况。
/// 漏网形态的兜底是别把原始异常对象整个写进日志。
String redactSecrets(String input) {
  if (input.isEmpty) return input;
  var out = input;
  for (final rule in _rules) {
    out = out.replaceAllMapped(rule.pattern, (m) => rule.replacement(m));
  }
  return out;
}

/// 脱敏规则表。写成数据而不是一串 if，是为了新增规则时只动这一处。
///
/// **大小写一律用 `caseSensitive: false`，不要写 `(?i)` 内联标志**：
/// Dart 的 [RegExp] 走 ECMAScript 语义，不认 `(?i)`，构造时直接抛
/// `FormatException: Invalid group`。而且这张表是顶层懒初始化，
/// 错误要等到第一次调用 [redactSecrets] 才暴露 —— 曾经就因此让 7 个
/// 用例在 CI 上集体变红，本地却毫无察觉（本机跑不了 flutter test）。
/// 现在 [test/debug_log_test.dart] 里有专门的用例钉住"规则表能构造出来"。
final List<_RedactRule> _rules = [
  // Bearer / Basic 认证头
  // 注意：replaceAllMapped 的返回值是普通字符串、不做 $1 展开，
  // 所以必须自己从 Match 里取分组，写 r'$1 ***' 会原样输出美元符号。
  _RedactRule(
    RegExp(r'\b(bearer|basic)\s+[A-Za-z0-9._\-+/=]{8,}',
        caseSensitive: false),
    (m) => '${m.group(1)} ***',
  ),
  // sk- 开头的 OpenAI 风格 Key
  _RedactRule(
    RegExp(r'\bsk-[A-Za-z0-9._\-]{8,}'),
    (_) => 'sk-***',
  ),
  // apiKey / api_key / token / secret / password / authorization 的键值写法。
  // 保留键名与分隔符，方便日志里看出"这是哪种凭证被吃掉了"。
  _RedactRule(
    RegExp(
      r'\b(api[_-]?key|apikey|access[_-]?token|refresh[_-]?token|token|secret|password|passwd|authorization)\b'
      r'(\s*[:=]\s*|\s+)["'']?([A-Za-z0-9._\-+/=]{8,})["'']?',
      caseSensitive: false,
    ),
    (m) => '${m.group(1)}${m.group(2)}***',
  ),
  // URL query 里的 ?key=xxx / &token=xxx
  _RedactRule(
    RegExp(r'([?&](?:key|token|api_key|apikey|access_token)=)[^&\s"''>]{4,}',
        caseSensitive: false),
    (m) => '${m.group(1)}***',
  ),
];

class _RedactRule {
  final RegExp pattern;
  final String Function(Match) replacement;
  const _RedactRule(this.pattern, this.replacement);
}
