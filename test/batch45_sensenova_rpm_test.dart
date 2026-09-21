// Batch 45 · SenseNova 每分钟限流（治 429）。
//
// 背景：SenseNovaQuotaManager 只做 5 小时总量闸门，对「每分钟请求数（RPM）」
// 零拦截。deepseek-v4-flash ≈ 1.67 次/分钟，一回合「叙事 + 选项」两发就撞
// 服务端 429；5h 总量闸门要到 500 次才动，没机会拦。429 → 重试 → 再 429 的
// 正反馈就是这么来的。
//
// 本测试锁三件事：
// 1. rpmForModel：托管模型（deepseek/glm）1 次/分钟，自研（sensenova-*）4 次/分钟。
// 2. 按 Key 分桶：多个 Key 各自独立 RPM 桶，一个 Key 满额不影响另一个。
// 3. 满额后超时抛 AiGateTimeoutException（不被上层重包成「解析失败」）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/services/rate_limiter.dart';

void main() {
  group('SenseNovaRateLimiter 每分钟限流', () {
    tearDown(() {
      SenseNovaRateLimiter.instance.reset();
    });

    test('托管模型 deepseek-v4-flash 每分钟 1 次', () {
      expect(SenseNovaRateLimiter.rpmForModel('deepseek-v4-flash'), 1);
      expect(SenseNovaRateLimiter.rpmForModel('glm-5.2'), 1);
      expect(SenseNovaRateLimiter.rpmForModel('deepseek-v4-pro'), 1);
    });

    test('自研模型 sensenova-* 每分钟 4 次', () {
      expect(
        SenseNovaRateLimiter.rpmForModel('sensenova-6.8-flash-lite'),
        4,
      );
      expect(SenseNovaRateLimiter.rpmForModel('sensenova-u1-fast'), 4);
    });

    test('同一个 Key 满额后第 2 次（托管模型）超时抛闸门异常', () async {
      final r = SenseNovaRateLimiter.instance;
      await r.waitForSlot('key-a', 'deepseek-v4-flash');
      await expectLater(
        r.waitForSlot(
          'key-a',
          'deepseek-v4-flash',
          timeout: const Duration(milliseconds: 80),
        ),
        throwsA(isA<AiGateTimeoutException>()),
      );
    });

    test('不同 Key 各自独立 RPM 桶，互不影响', () async {
      final r = SenseNovaRateLimiter.instance;
      // key-a 用满 1 次/分钟额度
      await r.waitForSlot('key-a', 'deepseek-v4-flash');
      // key-b 不受 key-a 满额影响，仍可放行
      await r.waitForSlot('key-b', 'deepseek-v4-flash');
      // key-a 再发则超时
      await expectLater(
        r.waitForSlot(
          'key-a',
          'deepseek-v4-flash',
          timeout: const Duration(milliseconds: 80),
        ),
        throwsA(isA<AiGateTimeoutException>()),
      );
    });
  });
}
