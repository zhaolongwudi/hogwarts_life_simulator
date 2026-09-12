// Q9：空响应率监控 — 连续空响应降级并提示换稳定模型。
//
// 修复前：空响应与超时/网络错误混在同一口锅里——每个 Key 连续 3 次失败就
// 进 60 秒冷却，而空响应是模型输出质量问题，冷却毫无意义；玩家也得不到
// 「换稳定模型」的指引，只会反复触发重试。
//
// 修复后：
//  1. EmptyResponseMonitor 按「提供商+模型」跟踪连续空响应，一次成功即清零；
//  2. 偶发空响应（未达阈值）→ AiEmptyRetryableException，**不记 Key 熔断**；
//  3. 连续 3 次空响应 → AiEmptyResponseException，路由层跳过该提供商全部
//     Key 降级到备用提供商，并留下「换稳定模型」提示——成功路径经
//     callDeepSeek 进通知栏，失败路径由异常文案兜底。
library;
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/providers/app_provider.dart';
import 'package:hogwarts_life_simulator/services/ai_router.dart';
import 'package:hogwarts_life_simulator/services/deepseek_service.dart';
import 'package:hogwarts_life_simulator/services/empty_response_monitor.dart';
import 'package:hogwarts_life_simulator/services/rate_limiter.dart';

import 'helpers/test_fixtures.dart';

GameChoice cmd(String action) => GameChoice(text: action, action: action);

/// 假的 AI 端点：记录被打了几次、每次都返回什么（从 q5 测试复用）。
class _FakeAiServer {
  _FakeAiServer._(this._server);

  final HttpServer _server;
  int hits = 0;

  int get port => _server.port;

  static Future<_FakeAiServer> start({
    required int status,
    required String body,
    String contentType = 'application/json',
    Duration delay = Duration.zero,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = _FakeAiServer._(server);
    server.listen((request) async {
      fake.hits++;
      try {
        await request.drain<void>();
        if (delay > Duration.zero) {
          await Future<void>.delayed(delay);
        }
        request.response.statusCode = status;
        request.response.headers.contentType =
            ContentType.parse('$contentType; charset=utf-8');
        request.response.write(body);
        await request.response.close();
      } catch (_) {
        // 连接被客户端掐断（取消 / 超时），属预期。
      }
    });
    return fake;
  }

  Future<void> close() => _server.close(force: true);
}

DeepSeekService _serviceOn(
  _FakeAiServer server, {
  required AiProvider provider,
  String key = 'test-key',
  String model = 'test-model',
}) {
  final cfg = AiConfig(
    provider: provider,
    apiKey: key,
    baseUrl: 'http://127.0.0.1:${server.port}',
    model: model,
  );
  return DeepSeekService(
    config: cfg,
    dio: Dio(BaseOptions(
      baseUrl: 'http://127.0.0.1:${server.port}',
      receiveTimeout: const Duration(seconds: 5),
    )),
  );
}

String _chatBody(String content) => jsonEncode({
      'choices': [
        {
          'message': {'content': content}
        }
      ],
      'usage': {'prompt_tokens': 1, 'completion_tokens': 1, 'total_tokens': 2},
    });

/// 总是抛「连续空响应」的假服务：模拟 monitor 已判定该模型不稳定。
/// 用于 TestWidgetsFlutterBinding 环境（真实 HttpClient 会被拦截成 400）。
class _EmptyDegradeService extends DeepSeekService {
  _EmptyDegradeService({required super.config})
      : super(
          dio: Dio(
            BaseOptions(baseUrl: 'http://127.0.0.1:1'),
          ),
        );

  @override
  Future<ChatResult> chatComplete({
    required String prompt,
    String systemPrompt = '',
    double temperature = 0.8,
    int maxTokens = 4096,
    CancelToken? cancelToken,
  }) async {
    throw AiEmptyResponseException(
        config.provider.name, config.model, '连续空响应');
  }
}

/// 总是正常返回的假服务（备用提供商侧）。
class _OkService extends DeepSeekService {
  _OkService({required super.config})
      : super(
          dio: Dio(
            BaseOptions(baseUrl: 'http://127.0.0.1:1'),
          ),
        );

  @override
  Future<ChatResult> chatComplete({
    required String prompt,
    String systemPrompt = '',
    double temperature = 0.8,
    int maxTokens = 4096,
    CancelToken? cancelToken,
  }) async {
    return ChatResult(
      content: '备用叙事内容',
      usage: const TokenUsage(promptTokens: 0, completionTokens: 0, totalTokens: 0),
    );
  }
}

void main() {
  setUp(() {
    EmptyResponseMonitor.instance.reset();
    AgnesRateLimiter.instance.reset();
    SenseNovaQuotaManager.instance.reset();
  });

  // ==================== 1. 监控器单元测试 ====================
  group('Q9 EmptyResponseMonitor', () {
    test('连续 3 次空响应判定不稳定；成功响应清零连续计数', () {
      final m = EmptyResponseMonitor.instance;
      expect(m.recordEmpty('sensenova', 'm1'), isFalse);
      expect(m.recordEmpty('sensenova', 'm1'), isFalse);
      expect(m.consecutiveEmptyCount('sensenova', 'm1'), 2);
      expect(m.recordEmpty('sensenova', 'm1'), isTrue,
          reason: '第 3 次连续空响应恰好达到降级阈值');
      expect(m.isDegraded('sensenova', 'm1'), isTrue);

      m.recordSuccess('sensenova', 'm1');
      expect(m.isDegraded('sensenova', 'm1'), isFalse,
          reason: '一次成功响应即恢复稳定');
      expect(m.consecutiveEmptyCount('sensenova', 'm1'), 0);
      expect(m.totalEmptyCount('sensenova', 'm1'), 3,
          reason: '累计计数保留，供诊断/UI 使用');
    });

    test('不同模型独立计量，互不牵连', () {
      final m = EmptyResponseMonitor.instance;
      for (var i = 0; i < 3; i++) {
        m.recordEmpty('sensenova', 'm1');
      }
      expect(m.recordEmpty('sensenova', 'm2'), isFalse,
          reason: 'm2 首次空响应不应受 m1 已降级影响');
      expect(m.consecutiveEmptyCount('sensenova', 'm1'), 3);
      expect(m.consecutiveEmptyCount('sensenova', 'm2'), 1);
    });
  });

  // ==================== 2. 服务层：空响应的归类 ====================
  group('Q9 DeepSeekService 空响应归类', () {
    test('偶发空响应抛 AiEmptyRetryableException（可重试、不熔断）', () async {
      final server = await _FakeAiServer.start(
        status: 200,
        body: _chatBody(''),
      );
      addTearDown(server.close);
      final svc =
          _serviceOn(server, provider: AiProvider.sensenova, model: 'sn-6.8');

      await expectLater(
        svc.chatComplete(prompt: 'p1'),
        throwsA(isA<AiEmptyRetryableException>()),
      );
    });

    test('连续第 3 次空响应抛 AiEmptyResponseException（文案带换模型建议）', () async {
      final server = await _FakeAiServer.start(
        status: 200,
        body: _chatBody(''),
      );
      addTearDown(server.close);
      final svc =
          _serviceOn(server, provider: AiProvider.sensenova, model: 'sn-6.8');

      await expectLater(
          svc.chatComplete(prompt: 'p1'), throwsA(isA<AiEmptyRetryableException>()));
      await expectLater(
          svc.chatComplete(prompt: 'p2'), throwsA(isA<AiEmptyRetryableException>()));
      await expectLater(
        svc.chatComplete(prompt: 'p3'),
        throwsA(
          isA<AiEmptyResponseException>()
              .having((e) => e.provider, 'provider', 'sensenova')
              .having((e) => e.model, 'model', 'sn-6.8')
              .having((e) => e.message, 'message', contains('更换稳定模型')),
        ),
      );
    });

    test('空响应后成功响应清零连续计数，重新累计', () async {
      final emptyServer = await _FakeAiServer.start(
        status: 200,
        body: _chatBody(''),
      );
      final okServer = await _FakeAiServer.start(
        status: 200,
        body: _chatBody('正常回复'),
      );
      addTearDown(emptyServer.close);
      addTearDown(okServer.close);
      final emptySvc =
          _serviceOn(emptyServer, provider: AiProvider.sensenova, model: 'm');
      final okSvc =
          _serviceOn(okServer, provider: AiProvider.sensenova, model: 'm');

      await expectLater(
          emptySvc.chatComplete(prompt: 'e1'), throwsA(isA<AiEmptyRetryableException>()));
      await expectLater(
          emptySvc.chatComplete(prompt: 'e2'), throwsA(isA<AiEmptyRetryableException>()));

      final ok = await okSvc.chatComplete(prompt: 'ok');
      expect(ok.content, '正常回复');

      // 清零后重新累计：再来 3 次连续空响应才触发降级
      await expectLater(
          emptySvc.chatComplete(prompt: 'e3'), throwsA(isA<AiEmptyRetryableException>()));
      await expectLater(
          emptySvc.chatComplete(prompt: 'e4'), throwsA(isA<AiEmptyRetryableException>()));
      await expectLater(
        emptySvc.chatComplete(prompt: 'e5'),
        throwsA(isA<AiEmptyResponseException>()),
      );
    });
  });

  // ==================== 3. 路由层：连续空响应降级 ====================
  group('Q9 路由层降级', () {
    AiRouter _routerWith({
      required _FakeAiServer sensenova,
      required _FakeAiServer agnes,
    }) {
      return AiRouter(
        AiRouterConfig(
          narrativeProvider: AiProvider.sensenova,
          summaryProvider: AiProvider.sensenova,
          npcChatProvider: AiProvider.sensenova,
          choiceProvider: AiProvider.sensenova,
          fallbackOrder: const [AiProvider.agnes],
        ),
        services: {
          AiProvider.sensenova: [
            _serviceOn(sensenova,
                provider: AiProvider.sensenova,
                key: 'sn-key',
                model: 'sensenova-6.8-flash-lite'),
          ],
          AiProvider.agnes: [
            _serviceOn(agnes,
                provider: AiProvider.agnes, key: 'ag-key', model: 'agnes-2.5-flash'),
          ],
        },
      );
    }

    test('连续空响应跳过整个提供商降级到备用，成功并留下换模型提示', () async {
      final sensenova = await _FakeAiServer.start(
        status: 200,
        body: _chatBody(''),
      );
      final agnes = await _FakeAiServer.start(
        status: 200,
        body: _chatBody('备用内容'),
      );
      addTearDown(sensenova.close);
      addTearDown(agnes.close);
      final router = _routerWith(sensenova: sensenova, agnes: agnes);

      for (var i = 0; i < 3; i++) {
        final result = await router.chatComplete(
          scene: AiScene.narrative,
          prompt: 'try-$i',
        );
        expect(result.content, '备用内容');
      }

      expect(router.lastDegradeNotice, isNotNull,
          reason: '降级发生后应留下「换稳定模型」提示');
      expect(router.lastDegradeNotice!, contains('更换稳定模型'));
      expect(router.lastDegradeNotice!, contains('sensenova'));

      // 第 4 次调用：sensenova 仍被尝试（空响应不记熔断，模型不稳定≠Key 失效）
      await router.chatComplete(scene: AiScene.narrative, prompt: 'try-3');
      expect(sensenova.hits, 4,
          reason: '空响应不得让 Key 进熔断冷却——否则第 4 次调用会直接跳过 sensenova');
      expect(agnes.hits, 4, reason: 'agnes 每次都兜住降级');
    });

    test('无备用提供商时上抛 AiEmptyResponseException，文案自带建议', () async {
      final server = await _FakeAiServer.start(
        status: 200,
        body: _chatBody(''),
      );
      addTearDown(server.close);
      final router = AiRouter(
        AiRouterConfig(
          narrativeProvider: AiProvider.sensenova,
          summaryProvider: AiProvider.sensenova,
          npcChatProvider: AiProvider.sensenova,
          choiceProvider: AiProvider.sensenova,
          fallbackOrder: const [],
        ),
        services: {
          AiProvider.sensenova: [
            _serviceOn(server,
                provider: AiProvider.sensenova,
                key: 'sn-key',
                model: 'sensenova-6.8-flash-lite'),
          ],
        },
      );

      await expectLater(
        router.chatComplete(scene: AiScene.narrative, prompt: 'p1'),
        throwsA(isA<AiEmptyRetryableException>()),
      );
      await expectLater(
        router.chatComplete(scene: AiScene.narrative, prompt: 'p2'),
        throwsA(isA<AiEmptyRetryableException>()),
      );
      // 第 3 次：全链失败，异常上抛给调用方；文案自带换模型建议
      await expectLater(
        router.chatComplete(scene: AiScene.narrative, prompt: 'p3'),
        throwsA(
          isA<AiEmptyResponseException>()
              .having((e) => e.message, 'message', contains('更换稳定模型')),
        ),
      );
      // 失败路径同样留了提示（下次成功调用会展示），且可手动清除
      expect(router.lastDegradeNotice, isNotNull);
      router.clearDegradeNotice();
      expect(router.lastDegradeNotice, isNull);
    });
  });

  // ==================== 4. 全链路：降级提示进通知栏 ====================
  group('Q9 全链路降级提示', () {
    test('processChoice 触发降级后，通知栏出现换稳定模型提示', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final gp = await makeGame();
      final degradeSvc = _EmptyDegradeService(
        config: AiConfig(
          provider: AiProvider.sensenova,
          apiKey: 'k',
          baseUrl: 'http://127.0.0.1:1',
          model: 'sensenova-6.8-flash-lite',
        ),
      );
      final okSvc = _OkService(
        config: AiConfig(
          provider: AiProvider.agnes,
          apiKey: 'k2',
          baseUrl: 'http://127.0.0.1:1',
          model: 'agnes-2.5-flash',
        ),
      );
      gp.router = AiRouter(
        AiRouterConfig(
          narrativeProvider: AiProvider.sensenova,
          summaryProvider: AiProvider.sensenova,
          npcChatProvider: AiProvider.sensenova,
          choiceProvider: AiProvider.sensenova,
          fallbackOrder: const [AiProvider.agnes],
        ),
        services: {
          AiProvider.sensenova: [degradeSvc],
          AiProvider.agnes: [okSvc],
        },
      );

      await gp.processChoice(cmd('走向城堡'));

      expect(
        gp.notifications.any((n) => n.contains('更换稳定模型')),
        isTrue,
        reason: '降级后应明确提示玩家更换稳定模型',
      );
      final noticeCount = gp.notifications
          .where((n) => n.contains('更换稳定模型'))
          .length;
      // 模型持续不稳定期间，每次叙事都降级，但提示只出现一次，不刷屏。
      await gp.processChoice(cmd('继续前进'));
      expect(
        gp.notifications.where((n) => n.contains('更换稳定模型')).length,
        noticeCount,
        reason: '持续不稳定期间降级提示只出现一次（去重），不弹窗轰炸',
      );
    });
  });
}
