/// S1 流式输出专项测试。
///
/// 覆盖三件在别处无法验证的事：
///  1. **非流式路径零回归** —— 不传 onDelta 时，请求体里 `stream` 仍是 false，
///     走的还是 `choices[0].message` 那条老路（全仓 7 个测试文件依赖它）；
///  2. **流式路径真的逐帧回调** —— 起一个真发 SSE 的本地服务，断言增量拼接
///     结果等于完整正文、且回调次数 > 1（否则「流式」名不副实）；
///  3. **降级与边界** —— 端点不支持 SSE（返普通 JSON / 空体 / 400）时必须
///     自动退回非流式，而不是把功能变成坏的；多字节中文跨 chunk 不能乱码；
///     usage 从最后一个 chunk 正确回读；畸形 chunk 不影响整段。
///
/// 这些都是行为测试：起真 HTTP 服务、真发请求、真读流，改坏了会红。
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/providers/app_provider.dart';
import 'package:hogwarts_life_simulator/services/deepseek_service.dart';

/// 一个可编程的假 AI 端点：按请求体里有没有 `"stream": true` 决定回什么。
class _FakeEndpoint {
  _FakeEndpoint._(this._server);

  final HttpServer _server;
  int hits = 0;
  final List<Map<String, dynamic>> bodies = [];

  int get port => _server.port;

  /// [sseChunks] 非空时按 SSE 逐帧下发；[rawChunks] 则按**原始字节**下发
  /// （用于把多字节字符切断）；[jsonBody] 是普通 JSON 响应体。
  /// [status] 用于模拟「不认 stream_options 而返 400」。
  static Future<_FakeEndpoint> start({
    required int status,
    String? jsonBody,
    List<String>? sseChunks,
    List<List<int>>? rawChunks,
    Duration chunkDelay = Duration.zero,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = _FakeEndpoint._(server);
    server.listen((request) async {
      fake.hits++;
      try {
        final raw = await utf8.decoder.bind(request).join();
        if (raw.isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map) fake.bodies.add(decoded.cast<String, dynamic>());
        }
        request.response.statusCode = status;
        if (rawChunks != null) {
          request.response.headers.contentType =
              ContentType.parse('text/event-stream; charset=utf-8');
          for (final bytes in rawChunks) {
            request.response.add(bytes);
            await request.response.flush();
          }
        } else if (sseChunks != null) {
          // SSE 必须带这个 content-type，Dio 才会当流处理。
          request.response.headers.contentType =
              ContentType.parse('text/event-stream; charset=utf-8');
          for (final chunk in sseChunks) {
            request.response.write(chunk);
            await request.response.flush();
            if (chunkDelay > Duration.zero) {
              await Future<void>.delayed(chunkDelay);
            }
          }
        } else {
          request.response.headers.contentType =
              ContentType.parse('application/json; charset=utf-8');
          request.response.write(jsonBody ?? '{}');
        }
        await request.response.close();
      } catch (_) {
        // 客户端提前断开属预期（降级/超时用例）。
      }
    });
    return fake;
  }

  Future<void> close() => _server.close(force: true);
}

DeepSeekService _serviceOn(_FakeEndpoint server) {
  final cfg = AiConfig(
    provider: AiProvider.deepseek,
    apiKey: 'test-key',
    baseUrl: 'http://127.0.0.1:${server.port}',
    model: 'test-model',
  );
  return DeepSeekService(
    config: cfg,
    dio: Dio(BaseOptions(
      baseUrl: 'http://127.0.0.1:${server.port}',
      receiveTimeout: const Duration(seconds: 5),
    )),
  );
}

/// 拼一个 OpenAI 风格的流式 chunk。
String _sseDelta(String content) => 'data: ${jsonEncode({
      'choices': [
        {
          'delta': {'content': content},
        }
      ],
    })}\n\n';

String _sseUsage() => 'data: ${jsonEncode({
      'choices': const [],
      'usage': {
        'prompt_tokens': 120,
        'completion_tokens': 34,
        'total_tokens': 154,
      },
    })}\n\n';

String _chatBody(String content) => jsonEncode({
      'choices': [
        {'message': {'content': content}}
      ],
      'usage': {'prompt_tokens': 1, 'completion_tokens': 1, 'total_tokens': 2},
    });

void main() {
  group('S1 · 非流式路径零回归', () {
    test('不传 onDelta 时请求体 stream=false，且走 choices[0].message', () async {
      final server = await _FakeEndpoint.start(
        status: 200,
        jsonBody: _chatBody('你推开教室的门。'),
      );
      addTearDown(server.close);

      final result = await _serviceOn(server).chatComplete(prompt: 'hi');

      expect(result.content, '你推开教室的门。');
      expect(server.bodies.single['stream'], isFalse,
          reason: '不传 onDelta 就必须保持非流式——7 个测试文件依赖这条路径');
      expect(server.bodies.single.containsKey('stream_options'), isFalse,
          reason: '非流式请求不该带 stream_options');
    });
  });

  group('S1 · 流式路径', () {
    test('逐帧回调，增量拼接等于完整正文', () async {
      final server = await _FakeEndpoint.start(
        status: 200,
        sseChunks: [
          _sseDelta('你推开门。'),
          _sseDelta('走廊里'),
          _sseDelta('很安静。'),
          _sseUsage(),
          'data: [DONE]\n\n',
        ],
      );
      addTearDown(server.close);

      final deltas = <String>[];
      final result = await _serviceOn(server).chatComplete(
        prompt: 'hi',
        onDelta: (d, {bool reset = false}) {
          if (!reset && d.isNotEmpty) deltas.add(d);
        },
      );

      expect(result.content, '你推开门。走廊里很安静。');
      expect(deltas.length, 3, reason: '每个 delta 帧都应回调一次');
      expect(deltas.join(), result.content, reason: '增量拼接必须等于返回值');
      expect(server.bodies.single['stream'], isTrue);
    });

    test('请求体带 stream_options.include_usage，usage 从末帧回读', () async {
      final server = await _FakeEndpoint.start(
        status: 200,
        sseChunks: [
          _sseDelta('正文'),
          _sseUsage(),
          'data: [DONE]\n\n',
        ],
      );
      addTearDown(server.close);

      final result = await _serviceOn(server).chatComplete(
        prompt: 'hi',
        onDelta: (_, {bool reset = false}) {},
      );

      expect(server.bodies.single['stream_options'],
          {'include_usage': true});
      expect(result.usage.promptTokens, 120);
      expect(result.usage.completionTokens, 34);
      expect(result.usage.totalTokens, 154);
    });

    test('多字节中文跨 chunk 不产生乱码', () async {
      // 真·字节级切分：把整段 SSE 的 UTF-8 字节流在**一个中文字符的中间**
      // 断开分两次下发。这是真实网络分块必然会发生的事（TCP 只保证字节序，
      // 不保证按字符边界切），也是 utf8.decoder 缓冲跨块字节的价值所在。
      final full = 'data: {"choices":[{"delta":{"content":"你好"}}]}\n\n'
          'data: [DONE]\n\n';
      final bytes = utf8.encode(full);
      // 找一个三字节中文字符的内部位置切一刀。
      final cut = bytes.indexOf(0xE4) + 1;
      expect(cut, greaterThan(0), reason: '测试自身前提：正文里应有中文');
      final server = await _FakeEndpoint.start(
        status: 200,
        rawChunks: [
          bytes.sublist(0, cut),
          bytes.sublist(cut),
        ],
      );
      addTearDown(server.close);

      final result = await _serviceOn(server).chatComplete(
        prompt: 'hi',
        onDelta: (_, {bool reset = false}) {},
      );

      expect(result.content, '你好');
      expect(result.content.contains('\uFFFD'), isFalse, reason: '不得出现替换字符');
    });

    test('畸形 chunk 被跳过，不影响后续正常帧', () async {
      final server = await _FakeEndpoint.start(
        status: 200,
        sseChunks: [
          'data: {这不是合法JSON\n\n',
          _sseDelta('仍然能读到'),
          'data: [DONE]\n\n',
        ],
      );
      addTearDown(server.close);

      final result = await _serviceOn(server).chatComplete(
        prompt: 'hi',
        onDelta: (_, {bool reset = false}) {},
      );

      expect(result.content, '仍然能读到');
    });
  });

  group('S1 · 降级与边界', () {
    test('端点返普通 JSON（不支持 SSE）→ 自动降级非流式，结果仍正确', () async {
      final server = await _FakeEndpoint.start(
        status: 200,
        jsonBody: _chatBody('降级后的正文'),
      );
      addTearDown(server.close);

      final deltas = <String>[];
      final result = await _serviceOn(server).chatComplete(
        prompt: 'hi',
        onDelta: (d, {bool reset = false}) {
          if (!reset && d.isNotEmpty) deltas.add(d);
        },
      );

      expect(result.content, '降级后的正文');
      expect(deltas, isEmpty, reason: '降级路径没有增量可吐');
      expect(server.hits, 2, reason: '流式一次 + 降级非流式一次');
    });

    test('端点返 400（不认 stream_options）→ 会降级重试一次，仍失败则如实上抛',
        () async {
      // 本端点恒定返 400：流式那次拿不到任何帧 → 自动降级为非流式再试一次；
      // 非流式这次同样 400 → 归类为「不可重试的参数错误」（400 属 4xx）。
      // 关键断言是 hits==2：证明降级确实发生了，而不是把 400 直接当终局。
      final server = await _FakeEndpoint.start(
        status: 400,
        jsonBody: jsonEncode({'error': {'message': 'unknown field stream_options'}}),
      );
      addTearDown(server.close);

      await expectLater(
        _serviceOn(server).chatComplete(
          prompt: 'hi',
          onDelta: (_, {bool reset = false}) {},
        ),
        throwsA(isA<AiNonRetryableException>()),
      );
      expect(server.hits, 2, reason: '应尝试流式 + 降级非流式各一次');
    });

    test('通道通但模型没吐正文 → 走空响应归类，不重复发请求', () async {
      final server = await _FakeEndpoint.start(
        status: 200,
        sseChunks: ['data: [DONE]\n\n'],
      );
      addTearDown(server.close);

      await expectLater(
        _serviceOn(server).chatComplete(
          prompt: 'hi',
          onDelta: (_, {bool reset = false}) {},
        ),
        throwsA(isA<AiRetryableException>()),
      );
      expect(server.hits, 1, reason: '收到过帧就不是「通道不通」，不该降级重发');
    });
  });
}
