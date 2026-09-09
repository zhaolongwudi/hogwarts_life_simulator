// Q5：叙事等待体验 — 支持取消。
//
// 与仓库里大量「读源码查子串」的断言不同，这里每一条都真的把代码跑一遍，
// 沿用第八轮审查测试的三条纪律（注入参数与生产同侧 / 断言目标性质 / 不锁死实现细节）。
//
// 覆盖五条行为：
//  1. router.cancelCurrentCall() 掐断进行中的慢请求 → 快速抛出 AiCanceledException
//  2. 取消后不再切换到下一个 Key 发起新请求
//  3. DeepSeekService：token 已取消 → AiCanceledException（不再被兜底重包成「解析失败」）
//  4. DeepSeekService：请求进行中取消 → AiCanceledException（不再归类成「网络错误」）
//  5. processChoice 全链路：取消后恢复可输入、不覆盖正文、不降级兜底
library;
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/providers/app_provider.dart';
import 'package:hogwarts_life_simulator/services/ai_router.dart';
import 'package:hogwarts_life_simulator/services/deepseek_service.dart';

import 'helpers/test_fixtures.dart';

GameChoice cmd(String action) => GameChoice(text: action, action: action);

/// 一个假的 AI 端点：记录被打了几次、每次都返回什么（从 audit_round8 复用）。
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
  String key = 'test-key',
  String model = 'test-model',
}) {
  final cfg = AiConfig(
    provider: AiProvider.deepseek,
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

/// 永不自行完成的假服务：挂住请求直到 CancelToken 被掐断。
///
/// 用于 TestWidgetsFlutterBinding 环境（真实 HttpClient 会被绑定拦截成 400），
/// 也用于验证「取消」而不依赖任何真实网络往返。
class _BlockingService extends DeepSeekService {
  _BlockingService({required super.config})
      : super(
          dio: Dio(
            BaseOptions(baseUrl: 'http://127.0.0.1:1'),
          ),
        );

  final List<Completer<ChatResult>> _pendings = [];

  int get pendingCount => _pendings.length;

  @override
  Future<ChatResult> chatComplete({
    required String prompt,
    String systemPrompt = '',
    double temperature = 0.8,
    int maxTokens = 4096,
    CancelToken? cancelToken,
  }) {
    final completer = Completer<ChatResult>();
    _pendings.add(completer);
    cancelToken?.whenCancel.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(AiCanceledException('请求已取消'));
      }
    });
    return completer.future;
  }
}

AiRouter _routerWith(List<DeepSeekService> services) => AiRouter(
      AiRouterConfig(
        narrativeProvider: AiProvider.deepseek,
        summaryProvider: AiProvider.deepseek,
        npcChatProvider: AiProvider.deepseek,
        choiceProvider: AiProvider.deepseek,
        fallbackOrder: const [AiProvider.deepseek],
      ),
      services: {AiProvider.deepseek: services},
    );

/// 轮询等待 [server] 被请求命中，超时视为失败。
Future<void> _waitHit(_FakeAiServer server) async {
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  while (server.hits == 0 && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(server.hits, greaterThanOrEqualTo(1), reason: '请求应已打到假服务端');
}

void main() {
  // ==================== 1. 路由器：取消进行中的慢请求 ====================
  group('Q5 路由器取消', () {
    test('cancelCurrentCall 掐断慢请求，快速抛 AiCanceledException', () async {
      final server = await _FakeAiServer.start(
        status: 200,
        body: _chatBody('慢响应'),
        delay: const Duration(seconds: 5),
      );
      addTearDown(server.close);
      final router = _routerWith([_serviceOn(server, key: 'slow-key')]);

      final sw = Stopwatch()..start();
      final fut = router.chatComplete(
        scene: AiScene.narrative,
        prompt: 'cancel-me-${DateTime.now().microsecondsSinceEpoch}',
      );
      await _waitHit(server);

      router.cancelCurrentCall();
      await expectLater(fut, throwsA(isA<AiCanceledException>()));
      sw.stop();

      expect(sw.elapsed, lessThan(const Duration(seconds: 3)),
          reason: '取消应立即生效，而不是等慢请求自己完成（5s）');
    });

    test('取消后不切换到下一个 Key 发起新请求', () async {
      // 两个 Key 都故意挂起：无论轮询从谁起步，先被打到的那个挂住，
      // 取消后不得再向另一个 Key 发起请求（不锁定轮询起点这个实现细节）。
      final a = await _FakeAiServer.start(
        status: 200,
        body: _chatBody('A'),
        delay: const Duration(seconds: 5),
      );
      final b = await _FakeAiServer.start(
        status: 200,
        body: _chatBody('B'),
        delay: const Duration(seconds: 5),
      );
      addTearDown(a.close);
      addTearDown(b.close);
      final router = _routerWith([
        _serviceOn(a, key: 'a-key'),
        _serviceOn(b, key: 'b-key'),
      ]);

      final fut = router.chatComplete(
        scene: AiScene.narrative,
        prompt: 'gap-${DateTime.now().microsecondsSinceEpoch}',
      );
      final deadline = DateTime.now().add(const Duration(seconds: 8));
      while (a.hits == 0 && b.hits == 0 && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(a.hits + b.hits, greaterThanOrEqualTo(1),
          reason: '请求应已打到某个 Key');

      router.cancelCurrentCall();
      await expectLater(fut, throwsA(isA<AiCanceledException>()));
      // 给「不该发生的下一次尝试」留出观察窗口
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(a.hits + b.hits, 1,
          reason: '取消后不得再向任何 Key 发起新请求');
    });
  });

  // ==================== 2/3. 服务层：取消的归类 ====================
  group('Q5 DeepSeekService 取消归类', () {
    test('token 已取消：抛 AiCanceledException，且不再发请求', () async {
      final server = await _FakeAiServer.start(
        status: 200,
        body: _chatBody('不该返回'),
      );
      addTearDown(server.close);
      final svc = _serviceOn(server, key: 'only');

      final token = CancelToken();
      token.cancel('用户取消');
      await expectLater(
        svc.chatComplete(prompt: 'pre-cancelled', cancelToken: token),
        throwsA(isA<AiCanceledException>()),
      );
      expect(server.hits, 0,
          reason: '取消后不得发出请求（修复前会在兜底里被重包成「解析失败」）');
    });

    test('请求进行中取消：抛 AiCanceledException，而非「网络错误」', () async {
      final server = await _FakeAiServer.start(
        status: 200,
        body: _chatBody('慢'),
        delay: const Duration(seconds: 5),
      );
      addTearDown(server.close);
      final svc = _serviceOn(server, key: 'only');

      final token = CancelToken();
      final fut = svc.chatComplete(prompt: 'mid-cancel', cancelToken: token);
      await _waitHit(server);

      token.cancel('用户取消');
      // 修复前：DioExceptionType.cancel 被 _handleError 归类成
      // AiRetryableException('网络错误: ...')，上层会误以为 AI 挂了。
      await expectLater(fut, throwsA(isA<AiCanceledException>()));
    });
  });

  // ==================== 4. processChoice 全链路 ====================
  group('Q5 processChoice 全链路取消', () {
    test('取消后恢复可输入、不覆盖正文、不降级兜底', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final gp = await makeGame();
      final before = gp.currentNarrative;
      // 真实 HttpClient 会被 TestWidgetsFlutterBinding 拦截成 400，
      // 用「挂住直到取消」的假服务模拟进行中的慢请求。
      final blocker = _BlockingService(
        config: AiConfig(
          provider: AiProvider.deepseek,
          apiKey: 'k',
          baseUrl: 'http://127.0.0.1:1',
          model: 'm',
        ),
      );
      gp.router = _routerWith([blocker]);

      final fut = gp.processChoice(cmd('走向城堡'));
      final deadline = DateTime.now().add(const Duration(seconds: 8));
      while (blocker.pendingCount == 0 && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(blocker.pendingCount, greaterThanOrEqualTo(1),
          reason: '叙事请求应已发出并挂起');
      expect(gp.isLoading, isTrue, reason: '请求在飞时应处于加载态');

      gp.cancelCurrentNarrative();
      await fut;

      expect(gp.isLoading, isFalse, reason: '取消后应退出加载态');
      expect(gp.currentNarrative, before,
          reason: '取消不得覆盖当前正文（不走本地兜底剧情）');
      expect(gp.notifications.any((n) => n.contains('已取消')), isTrue,
          reason: '应给出「已取消」的轻量提示');
    });
  });
}
