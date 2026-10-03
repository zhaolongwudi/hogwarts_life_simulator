// r3-3 摘要场景 JSON mode 试点 —— 行为测试。
//
// 覆盖三件事：
//  1. 请求侧：summary 场景的请求体带 response_format= json_object（试点目标），
//     narrative 场景不带（非试点场景零影响）。
//  2. prompt 侧：jsonMode=true 时给出 JSON 输出契约，false 时与旧 prompt 一致。
//  3. 归一侧：JSON 输出被还原成【】块文本（记忆管线零改动）；解析失败时
//     原样回退自由文本（试点不能以「回退即丢记忆」为代价）。
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hogwarts_life_simulator/prompts/summary_prompts.dart';
import 'package:hogwarts_life_simulator/providers/app_provider.dart';
import 'package:hogwarts_life_simulator/services/ai_router.dart';
import 'package:hogwarts_life_simulator/services/deepseek_service.dart';

/// 假 AI 端点：记录每个请求体，统一回一个合法 chat completion。
class _RecordingServer {
  _RecordingServer._(this._server);

  final HttpServer _server;
  final List<Map<String, dynamic>> bodies = [];
  int hits = 0;

  int get port => _server.port;

  static Future<_RecordingServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = _RecordingServer._(server);
    server.listen((request) async {
      fake.hits++;
      try {
        final raw = await utf8.decoder.bind(request).join();
        fake.bodies.add(jsonDecode(raw) as Map<String, dynamic>);
        request.response.statusCode = 200;
        request.response.headers.contentType =
            ContentType.parse('application/json; charset=utf-8');
        request.response.write(jsonEncode({
          'choices': [
            {
              'message': {'content': '测试响应'}
            }
          ],
          'usage': {
            'prompt_tokens': 1,
            'completion_tokens': 1,
            'total_tokens': 2
          },
        }));
        await request.response.close();
      } catch (_) {
        // 用例结束时 socket 已关，属预期。
      }
    });
    return fake;
  }

  Future<void> close() => _server.close(force: true);
}

void main() {
  test('summary 场景请求体带 response_format=json_object（JSON mode 试点）',
      () async {
    final server = await _RecordingServer.start();
    addTearDown(server.close);
    final router = _routerOn(server.port);
    await router.chatComplete(
        scene: AiScene.summary, prompt: '压缩这段剧情');
    expect(server.bodies, hasLength(1));
    final rf = server.bodies.single['response_format'];
    expect(rf, isA<Map>());
    expect((rf as Map)['type'], 'json_object');
  });

  test('narrative 场景请求体不带 response_format（非试点场景零影响）', () async {
    final server = await _RecordingServer.start();
    addTearDown(server.close);
    final router = _routerOn(server.port);
    await router.chatComplete(scene: AiScene.narrative, prompt: '继续剧情');
    // 叙事路径可能因假端点不吐 SSE 而「无帧降级」重发一次，故只断言
    // 「每一次请求都不带 response_format」——那才是非试点场景的契约。
    expect(server.bodies, isNotEmpty);
    for (final b in server.bodies) {
      expect(b.containsKey('response_format'), isFalse,
          reason: 'narrative 不得开 JSON mode：$b');
    }
  });

  test('buildSummaryPrompt jsonMode=true 输出 JSON 契约；默认(false)保持旧格式',
      () {
    final base = <String, dynamic>{
      'limit': 800,
      'previousSummary': '',
      'newChunk': '某段新剧情。',
      'relSnapshot': '',
      'coreFacts': '',
    };
    final withJson = buildSummaryPrompt(
      limit: base['limit'] as int,
      previousSummary: base['previousSummary'] as String,
      newChunk: base['newChunk'] as String,
      relSnapshot: base['relSnapshot'] as String,
      coreFacts: base['coreFacts'] as String,
      jsonMode: true,
    );
    expect(withJson, contains('"摘要"'));
    expect(withJson, contains('只输出一个 JSON 对象'));

    final legacy = buildSummaryPrompt(
      limit: base['limit'] as int,
      previousSummary: base['previousSummary'] as String,
      newChunk: base['newChunk'] as String,
      relSnapshot: base['relSnapshot'] as String,
      coreFacts: base['coreFacts'] as String,
    );
    // 旧契约仍在（自由文本回退路径要能吃），但不含 JSON 契约
    expect(legacy, contains('【了结】'));
    expect(legacy.contains('"摘要"'), isFalse);
  });

  group('normalizeSummaryPayload（JSON → 【】块归一化）', () {
    String norm(String content) => normalizeSummaryPayload(content);

    test('JSON 输出被还原成等价的【】块文本', () {
      final payload = jsonEncode({
        '摘要': '主角与赫敏在图书馆建立信任。',
        '关系': ['赫敏:友好/60'],
        '伏笔': ['斯内普答应保密'],
        '核心事实': ['主角魔杖：山楂木'],
        '世界事件': ['密室传闻|学校流传密室传闻'],
        '了结': ['斯内普答应保密'],
      });
      final out = norm(payload);
      expect(out, contains('主角与赫敏在图书馆建立信任。'));
      expect(out, contains('【关系】'));
      expect(out, contains('赫敏:友好/60'));
      expect(out, contains('【伏笔】'));
      expect(out, contains('【核心事实】'));
      expect(out, contains('密室传闻|学校流传密室传闻'));
      expect(out, contains('【了结】'));
      // 记忆管线现有的块提取逻辑应能直接吃这个归一化产物
      expect(_extractBlock(out, '了结'), contains('斯内普答应保密'));
    });

    test('空数组块不产出空【】块（老解析器不会误命中）', () {
      final payload = jsonEncode({'摘要': '平静的一周。', '关系': []});
      final out = norm(payload);
      expect(out.contains('【'), isFalse);
    });

    test('自由文本（老模型/不支持 response_format 的 Key）原样放行', () {
      const legacy = '主角修炼有成。\n【关系】\n赫敏:友好/50';
      expect(norm(legacy), legacy);
    });

    test('坏 JSON（模型不守契约）原样放行，不抛异常不丢内容', () {
      const broken = '{"摘要": "截断的';
      expect(norm(broken), broken);
    });
  });
}

/// 与 mixin_summary_memory._extractBlock 同口径（复刻其正则语义）。
String _extractBlock(String text, String blockName) {
  final pattern = RegExp('【$blockName】\\s*\\n?([\\s\\S]*?)(?=【|\$)');
  final m = pattern.firstMatch(text);
  return m?.group(1)?.trim() ?? '';
}

AiRouter _routerOn(int port) => AiRouter(
      AiRouterConfig(
        narrativeProvider: AiProvider.deepseek,
        summaryProvider: AiProvider.deepseek,
        npcChatProvider: AiProvider.deepseek,
        choiceProvider: AiProvider.deepseek,
        fallbackOrder: const [AiProvider.deepseek],
      ),
      services: {
        AiProvider.deepseek: [
          DeepSeekService(
            config: AiConfig(
              provider: AiProvider.deepseek,
              apiKey: 'test-key',
              baseUrl: 'http://127.0.0.1:$port',
              model: 'test-model',
            ),
            dio: Dio(BaseOptions(
              baseUrl: 'http://127.0.0.1:$port',
              receiveTimeout: const Duration(seconds: 10),
            )),
          ),
        ],
      },
    );
