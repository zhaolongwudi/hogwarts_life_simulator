// Q1：配额本地计数持久化 — 重启不与服务商窗口脱节。
//
// 修复前：SenseNovaQuotaManager 把调用时间只存在内存里，App 重启后本地
// 计数归零——玩家以为还有 1500 次额度，实际服务商 5 小时窗口还在计，
// 超了直接返 429（「AI 卡住了」的又一来源）。
// 修复后：每次占用配额把该模型的时间戳列表落盘 SharedPreferences
// （ai_quota_sensenova_{model} → ISO8601 JSON 数组），重启后 waitForQuota
// 先恢复持久化计数再判断窗口；超过 5 小时窗口的旧记录恢复时直接丢弃。
library;
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hogwarts_life_simulator/services/rate_limiter.dart';
import 'package:hogwarts_life_simulator/services/prefs_store.dart';

void main() {
  const quotaModel = 'deepseek-v4-flash'; // 500 次/5h，便于用小样本测满
  final prefix = 'ai_quota_sensenova_';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PrefsStore.instance.resetForTest();
    SenseNovaQuotaManager.instance.reset();
    await PrefsStore.instance.init(); // 预热：让后续 writeAsync 同步生效
  });

  List<String> _stamps(int count, {Duration age = const Duration(hours: 1)}) {
    final now = DateTime.now();
    return List.generate(
      count,
      (i) => now.subtract(age).add(Duration(seconds: i)).toIso8601String(),
    );
  }

  Future<void> _flush() => pumpEventQueue(times: 20);

  // ==================== 1. 占用即落盘 ====================
  group('Q1 配额落盘', () {
    test('waitForQuota 占用后，prefs 记录该模型的时间戳列表', () async {
      final m = SenseNovaQuotaManager.instance;
      await m.waitForQuota(quotaModel);
      await m.waitForQuota(quotaModel);
      await _flush();

      final prefs = await PrefsStore.instance.init();
      final raw = prefs.getString('$prefix$quotaModel');
      expect(raw, isNotNull, reason: '占用配额后应立即落盘');
      final times = (jsonDecode(raw!) as List)
          .map((e) => DateTime.tryParse(e as String))
          .whereType<DateTime>()
          .toList();
      expect(times.length, 2, reason: '两次占用应记录两条时间戳');
      // 时间戳都在窗口内（刚写入）
      final now = DateTime.now();
      expect(times.every((t) => now.difference(t) < const Duration(hours: 5)),
          isTrue);
    });
  });

  // ==================== 2. 重启恢复计数 ====================
  group('Q1 重启恢复', () {
    test('恢复满配额计数：重启后 waitForQuota 立即感知配额耗尽', () async {
      // 模拟「重启前已用满 500 次」：写入 500 条 1 小时前的记录
      SharedPreferences.setMockInitialValues({
        '$prefix$quotaModel': jsonEncode(_stamps(500)),
      });
      PrefsStore.instance.resetForTest();
      SenseNovaQuotaManager.instance.reset();
      await PrefsStore.instance.init();

      // 若计数未恢复（修复前），waitForQuota 会直接放行第 501 次；
      // 恢复后 500 次满额 → 等待超时抛闸门异常
      await expectLater(
        SenseNovaQuotaManager.instance
            .waitForQuota(quotaModel, timeout: const Duration(milliseconds: 120)),
        throwsA(isA<AiGateTimeoutException>()),
      );
    });

    test('恢复部分计数：满额后再占用一次即耗尽', () async {
      SharedPreferences.setMockInitialValues({
        '$prefix$quotaModel': jsonEncode(_stamps(499)),
      });
      PrefsStore.instance.resetForTest();
      SenseNovaQuotaManager.instance.reset();
      await PrefsStore.instance.init();

      // 第 500 次正常放行
      await SenseNovaQuotaManager.instance
          .waitForQuota(quotaModel, timeout: const Duration(seconds: 5));
      // 第 501 次：配额已满 → 超时
      await expectLater(
        SenseNovaQuotaManager.instance
            .waitForQuota(quotaModel, timeout: const Duration(milliseconds: 120)),
        throwsA(isA<AiGateTimeoutException>()),
      );
    });

    test('窗口外旧记录恢复时丢弃，不占计数', () async {
      // 499 条 1 小时前（窗口内）+ 100 条 6 小时前（已滑出 5h 窗口）
      SharedPreferences.setMockInitialValues({
        '$prefix$quotaModel': jsonEncode([
          ..._stamps(499, age: const Duration(hours: 1)),
          ..._stamps(100, age: const Duration(hours: 6)),
        ]),
      });
      PrefsStore.instance.resetForTest();
      SenseNovaQuotaManager.instance.reset();
      await PrefsStore.instance.init();

      // 6 小时前的记录被丢弃 → 实际恢复 499 条 → 第 500 次可放行
      await SenseNovaQuotaManager.instance
          .waitForQuota(quotaModel, timeout: const Duration(seconds: 5));
      // 随后耗尽 → 超时
      await expectLater(
        SenseNovaQuotaManager.instance
            .waitForQuota(quotaModel, timeout: const Duration(milliseconds: 120)),
        throwsA(isA<AiGateTimeoutException>()),
      );
    });

    test('模型独立恢复：一个模型满额不影响另一个', () async {
      SharedPreferences.setMockInitialValues({
        '$prefix$quotaModel': jsonEncode(_stamps(500)),
      });
      PrefsStore.instance.resetForTest();
      SenseNovaQuotaManager.instance.reset();
      await PrefsStore.instance.init();

      // deepseek-v4-flash 满额 → 超时；sensenova-6.8-flash-lite（1500/5h）不受影响
      await expectLater(
        SenseNovaQuotaManager.instance
            .waitForQuota(quotaModel, timeout: const Duration(milliseconds: 120)),
        throwsA(isA<AiGateTimeoutException>()),
      );
      await SenseNovaQuotaManager.instance.waitForQuota(
          'sensenova-6.8-flash-lite',
          timeout: const Duration(seconds: 5));
    });
  });
}
