import 'dart:async';
import 'dart:io';

/// 把底层异常/错误转成玩家看得懂的中文提示。
///
/// F6/F9 的核心原语之一：**宽容但不泄露**。只枚举我们认识的失败类型给友好文案，
/// 其余一律回退到调用方给的 [fallback]——绝不让 `Bad state: ...`、堆栈片段这类
/// 内部实现细节直接怼到玩家脸上（这正是 F6「用户可见错误信息不足」的病灶：
/// 以前的 catch 块要么 `debugPrint` 了事、要么把原始 `$e` 拼进 SnackBar）。
///
/// 用法：在 catch 里 `final msg = userFriendlyError(e, fallback: '保存失败')`，
/// 再用统一的 [miuixErrorSnack]（见 `widgets/miuix_overlays.dart`）弹给玩家。
///
/// 纯函数、无 Flutter 依赖：容易单测、也方便在 service / provider 层复用。
String userFriendlyError(Object? error, {required String fallback}) {
  if (error == null) return fallback;
  if (error is SocketException) return '网络连接异常，请检查网络后重试';
  if (error is HandshakeException) return '安全连接失败，请检查网络后重试';
  if (error is HttpException) return '网络请求失败，请稍后重试';
  if (error is TimeoutException) return '请求超时，请稍后重试';
  if (error is FormatException) return '返回的数据无法解析，请稍后重试';
  // 其余未知异常 / 业务异常：不猜、不泄露，就给调用方备好的兜底描述。
  return fallback;
}

/// 便捷转义：多数调用点只想「失败就弹兜底文案」，这里把 Object? + 兜底文案
/// 包成一次调用，签名与 SnackBar 拼串的意图对齐。
String errorMessage(Object? error, String fallback) =>
    userFriendlyError(error, fallback: fallback);