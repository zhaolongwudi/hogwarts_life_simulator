// Q7：限流/配额等待超时文案不再误标「解析失败」。
//
// 修复前：闸门（Agnes 20 RPM / SenseNova 5h 配额）等待超时抛的是裸
// `Exception`，被 DeepSeekService.chatComplete 的兜底 catch 重包成
// 「AI 响应解析失败: Exception: ...」——玩家以为模型坏了，实际是本地排队没排到。
// 修复后：专用类型 AiGateTimeoutException 一路透传到上层，文案保持原意。
library;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/providers/app_provider.dart';
import 'package:hogwarts_life_simulator/services/ai_router.dart';
import 'package:hogwarts_life_simulator/services/deepseek_service.dart';
import 'package:hogwarts_life_simulator/services/rate_limiter.dart';

/// 故意抛 AiGateTimeoutException 的假服务：验证路由层原样透传、不重包。
class _GateTimeoutService extends DeepSeekService {
  _GateTimeoutService({required super.config})
      : super(dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1')));

  @override
  Future<ChatResult> chatComplete({
    required String prompt,
    String systemPrompt = '',
    double temperature = 0.8,
    int maxTokens = 4096,
    CancelToken? cancelToken,
  }) async {
    throw AiGateTimeoutException('Agnes(xxx) 本地限流等待超时（30秒），跳过该 Key');
  }
}

void main() {
  group('Q7 闸门超时异常类型', () {
    test('Agnes 配额耗尽后抛 AiGateTimeoutException 而不是裸 Exception', () async {
      AgnesRateLimiter.instance.reset();
      // 填满 18 个名额，下一次必须走超时分支
      for (var i = 0; i < AgnesRateLimiter.maxRPM; i++) {
        await AgnesRateLimiter.instance.waitForSlot('q7-key');
      }
      await expectLater(
        AgnesRateLimiter.instance.waitForSlot(
          'q7-key',
          timeout: const Duration(milliseconds: 80),
        ),
        throwsA(
          isA<AiGateTimeoutException>().having(
            (e) => e.message,
            'message',
            contains('本地限流'),
          ),
        ),
      );
      AgnesRateLimiter.instance.reset();
    });

    test('SenseNova 配额耗尽后抛 AiGateTimeoutException 而不是裸 Exception', () async {
      SenseNovaQuotaManager.instance.reset();
      // 托管模型配额 500/5h：先填满，下一次必须走超时分支
      for (var i = 0; i < 500; i++) {
        await SenseNovaQuotaManager.instance.waitForQuota('deepseek-v4-flash');
      }
      await expectLater(
        SenseNovaQuotaManager.instance.waitForQuota(
          'deepseek-v4-flash',
          timeout: const Duration(milliseconds: 80),
        ),
        throwsA(
          isA<AiGateTimeoutException>().having(
            (e) => e.message,
            'message',
            contains('本地配额'),
          ),
        ),
      );
      SenseNovaQuotaManager.instance.reset();
    });

    test('路由层原样透传 AiGateTimeoutException，不重包成「解析失败」', () async {
      final router = AiRouter(
        const AiRouterConfig(
          narrativeProvider: AiProvider.deepseek,
          summaryProvider: AiProvider.deepseek,
          npcChatProvider: AiProvider.deepseek,
          choiceProvider: AiProvider.deepseek,
          fallbackOrder: [AiProvider.deepseek],
        ),
        services: {
          AiProvider.deepseek: [
            _GateTimeoutService(
              config: AiConfig(
                provider: AiProvider.deepseek,
                apiKey: 'k',
                baseUrl: 'http://127.0.0.1:1',
                model: 'm',
              ),
            ),
          ],
        },
      );
      await expectLater(
        router.chatComplete(scene: AiScene.narrative, prompt: 'x'),
        throwsA(isA<AiGateTimeoutException>()),
      );
    });

    test('DeepSeekService 兜底 catch 放行 AiGateTimeoutException', () {
      // 行为测试无法在不改 30 秒默认超时的前提下触发真实闸门路径，
      // 这里守的是「兜底 catch 里存在放行分支」这一结构不变式（与
      // review_fixes_test 既有风格一致）。
      final src = File('lib/services/deepseek_service.dart').readAsStringSync();
      expect(src.contains('on AiGateTimeoutException'), isTrue,
          reason: '缺少放行分支，限流超时仍会被重包成「AI 响应解析失败」');
    });
  });
}
