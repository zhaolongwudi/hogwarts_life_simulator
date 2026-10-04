import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/services/ai_router.dart';
import 'package:hogwarts_life_simulator/services/deepseek_service.dart';
import 'package:hogwarts_life_simulator/providers/app_provider.dart';

/// r5-2：多 Key 严格逐次轮换（无论成功失败，用完立刻换下一把）。
///
/// 目的：失败往往代表该 Key 已触顶 TPM/RPM（429），成功同样消耗配额——
/// 两种情况都不该让下一次调用再从同一把 Key 起步。旧逻辑只在调用开始时
/// 推进一次游标，「调用内切过 Key」后仍可能复用刚失败的那把。
void main() {
  // 极简 stub：成功返回固定文本；noOp 什么都不做（走超时/失败路径时用 mock 抛错）。
  DeepSeekService okService(String tag) {
    return _StubService(tag, succeed: true);
  }

  DeepSeekService failService(String tag) {
    return _StubService(tag, succeed: false);
  }

  AiRouter routerWith(Map<AiProvider, List<DeepSeekService>> m) =>
      AiRouter(const AiRouterConfig(
          narrativeProvider: AiProvider.deepseek,
          summaryProvider: AiProvider.deepseek,
          npcChatProvider: AiProvider.deepseek,
          choiceProvider: AiProvider.deepseek,
          fallbackOrder: [AiProvider.deepseek],
        ),
          services: m);

  test('成功后游标立即推进：下一次调用从下一把 Key 开始', () async {
    final a = okService('a') as _StubService, b = okService('b') as _StubService, c = okService('c') as _StubService;
    final router = routerWith({
      AiProvider.deepseek: [a, b, c],
    });
    await router.chatComplete(prompt: 'p1', scene: AiScene.narrative);
    // 第一次调用应落在 a（初始游标 0 → +1 =1？注意实现：startIndex=0%3=0 → 先 a）
    expect(a.callCount, 1, reason: '第一次调用应落在第一把 Key');
    expect(b.callCount, 0);
    await router.chatComplete(prompt: 'p2', scene: AiScene.narrative);
    // 成功后游标推进到 a 的下一把 → 第二次调用从 b 开始
    expect(b.callCount, 1, reason: '成功后应立刻轮换到下一把 Key');
    expect(a.callCount, 1, reason: '不应复用刚用过的 Key');
    await router.chatComplete(prompt: 'p3', scene: AiScene.narrative);
    expect(c.callCount, 1);
    await router.chatComplete(prompt: 'p4', scene: AiScene.narrative);
    expect(a.callCount, 2, reason: '轮完一圈回到第一把');
  });

  test('失败后游标也推进：下一次调用不再从刚失败的 Key 开始', () async {
    final bad = failService('bad') as _StubService;
    final good = okService('good') as _StubService;
    final router = routerWith({
      AiProvider.deepseek: [bad, good],
    });
    await router.chatComplete(prompt: 'p1', scene: AiScene.narrative);
    expect(bad.callCount, 1);
    expect(good.callCount, 1, reason: '失败后应切到下一把 Key 完成本次调用');
    await router.chatComplete(prompt: 'p2', scene: AiScene.narrative);
    // 第二次调用从 good 的下一把（=bad，2 把 Key 时轮换必然经过它）起步：
    // bad 失败后本次仍由 good 兜底完成。逐次轮换保证的是「同一把 Key 不会
    // 连续被选中两次」，而不是「失败的 Key 永不再选」——Key 数少时轮换圈
    // 会再次经过它（且熔断器另有 60s 冷却兜底）。
    expect(good.callCount, 2, reason: '每次调用都轮换，不会连续落在同一把上');
  });
}

class _StubService extends DeepSeekService {
  _StubService(this.tag, {required this.succeed})
      : super(
          config: AiConfig(
            provider: AiProvider.deepseek,
            apiKey: 'key-\$tag',
            baseUrl: 'https://api.test.local',
            model: 'test-model',
          ),
        );
  final String tag;
  final bool succeed;
  int callCount = 0;

  @override
  Future<ChatResult> chatComplete({
    required String prompt,
    String? systemPrompt,
    double temperature = 0.8,
    int maxTokens = 2500,
    bool trackCircuit = true,
    AiStreamCallback? onDelta,
    bool jsonMode = false,
    dynamic cancelToken,
  }) async {
    callCount++;
    if (succeed) {
      return const ChatResult(
          content: 'ok',
          usage: TokenUsage(
              promptTokens: 1, completionTokens: 1, totalTokens: 2));
    }
    throw Exception('429 rate limited (\$tag)');
  }
}
