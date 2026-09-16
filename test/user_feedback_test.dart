import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/utils/user_feedback.dart';

/// F6 / F9 的纯逻辑护栏。
///
/// F6：用户可见错误信息不足 —— 以前的 catch 块要么 `debugPrint` 了事、
/// 要么把原始 `$e`（`Bad state: ...`）直接拼进 SnackBar。现在统一走
/// `userFriendlyError`：只把认识的失败类型映射成玩家能看懂的中文，
/// 其余回退到调用方兜底文案，绝不泄露内部实现细节。
///
/// F9：恢复策略统一 —— 这套映射 + `miuixErrorSnack` 是所有屏幕共用的
/// 错误提示原语，这里钉住映射行为，UI 层反复改也不至于松动文案口径。
void main() {
  group('userFriendlyError 认识已知失败类型', () {
    test('SocketException → 网络连接异常', () {
      expect(userFriendlyError(SocketException('conn refused'), fallback: 'X'),
          '网络连接异常，请检查网络后重试');
    });

    test('HandshakeException → 安全连接失败', () {
      expect(userFriendlyError(HandshakeException('tls'), fallback: 'X'),
          '安全连接失败，请检查网络后重试');
    });

    test('HttpException → 网络请求失败', () {
      expect(userFriendlyError(HttpException('404'), fallback: 'X'),
          '网络请求失败，请稍后重试');
    });

    test('TimeoutException → 请求超时', () {
      expect(userFriendlyError(TimeoutException('slow'), fallback: 'X'),
          '请求超时，请稍后重试');
    });

    test('FormatException → 数据无法解析', () {
      expect(userFriendlyError(FormatException('bad'), fallback: 'X'),
          '返回的数据无法解析，请稍后重试');
    });
  });

  group('未知/空错误回退到兜底文案，绝不泄露', () {
    test('任意未知异常 → fallback', () {
      expect(userFriendlyError(StateError('内部状态错误'), fallback: '保存失败'),
          '保存失败');
      expect(userFriendlyError(ArgumentError('非法参数'), fallback: '导入失败'),
          '导入失败');
    });

    test('null 错误 → fallback', () {
      expect(userFriendlyError(null, fallback: '加载失败'), '加载失败');
    });

    test('fallback 文案里不会混入异常文本', () {
      final msg = userFriendlyError(
        StateError('secret-internal-detail-xyz'),
        fallback: '导出失败',
      );
      expect(msg, contains('导出失败'));
      expect(msg.contains('secret-internal-detail-xyz'), isFalse);
    });
  });

  group('errorMessage 便捷别名', () {
    test('等价于 userFriendlyError(error, fallback:)', () {
      expect(errorMessage(SocketException('x'), 'F'), '网络连接异常，请检查网络后重试');
      expect(errorMessage(StateError('x'), 'F'), 'F');
    });
  });
}