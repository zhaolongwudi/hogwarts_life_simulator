import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../providers/app_provider.dart';
import 'ai_timeouts.dart' as timeouts;
import 'empty_response_monitor.dart';
import 'rate_limiter.dart';

class TokenUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  const TokenUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  factory TokenUsage.fromJson(Map<String, dynamic> json) {
    return TokenUsage(
      promptTokens: json['prompt_tokens'] as int? ?? 0,
      completionTokens: json['completion_tokens'] as int? ?? 0,
      totalTokens: json['total_tokens'] as int? ?? 0,
    );
  }
}

class ChatResult {
  final String content;
  final TokenUsage usage;

  const ChatResult({
    required this.content,
    required this.usage,
  });
}

/// 可重试的 AI 调用异常（超时、限流、服务端错误等）
///
/// [isTimeout] 区分「这一路慢/挂住了」与「这一次被拒了」：
/// 限流、5xx 这类错误退避两秒再试同一把 Key 是有意义的，而超时说明对端
/// 这会儿就是慢，再试一次只会再吃满一个超时窗口——那点时间该留给别的 Key。
/// 路由层据此决定是重试同 Key 还是直接切下一个。
class AiRetryableException implements Exception {
  final String message;
  final bool isTimeout;
  AiRetryableException(this.message, {this.isTimeout = false});
  @override
  String toString() => message;
}

/// 不可重试的 AI 调用异常（认证失败、参数错误、端点不存在等）
class AiNonRetryableException implements Exception {
  final String message;
  AiNonRetryableException(this.message);
  @override
  String toString() => message;
}

/// 用户主动取消（router.cancelCurrentCall）时抛出的异常。
///
/// 与超时/网络错误不同：调用方应静默收尾——不重试、不切 Key、不生成兜底
/// 剧情。此前取消只表现为 DioException(cancel) → 被 `_handleError` 归类成
/// 「网络错误」→ 上层误以为 AI 挂了而走本地兜底，把玩家正在看的剧情
/// 替换成过渡文本（Q5）。
class AiCanceledException implements Exception {
  final String message;
  AiCanceledException(this.message);
  @override
  String toString() => 'AiCanceledException: $message';
}

/// 连续空响应达到阈值（EmptyResponseMonitor.degradeThreshold）后抛出的异常。
///
/// 与偶发空响应（AiRetryableException）不同：它携带「该模型不稳定」信号，
/// 路由层据此跳过该提供商**全部** Key 降级到备用提供商，并提示玩家更换
/// 稳定模型（Q9）。文案自带换模型建议——即使全链失败把异常上抛给玩家，
/// 提示也不会丢。
class AiEmptyResponseException implements Exception {
  final String provider;
  final String model;
  final String message;
  AiEmptyResponseException(this.provider, this.model, this.message);
  @override
  String toString() => message;
}

/// 偶发空响应（未达到连续降级阈值）抛出的异常。
///
/// 语义上「可重试」（mixin 的强化指令重试逻辑照常接管），但归因是模型
/// 输出质量而非 Key/网络——路由层据此**不记 Key 熔断**：模型不稳定 ≠
/// Key 失效，把空响应计入熔断只会让 60 秒冷却白等（Q9）。
class AiEmptyRetryableException extends AiRetryableException {
  AiEmptyRetryableException(super.message);
}

/// 流式增量回调。
///
/// [reset] 为 true 表示「此前累积的预览作废」：路由层换 Key、上层重试、或
/// 新一轮生成开始时调用，UI 据此清空已显示的半截文本，避免两次尝试的内容
/// 被拼在一起。为 false 时 [delta] 是本次新增的正文片段。
typedef AiStreamCallback = void Function(String delta, {bool reset});

class DeepSeekService {
  final AiConfig config;
  final Dio _dio;

  /// Dio 的接收超时 = 路由层单次调用预算 + 10s 缓冲。
  ///
  /// **单一来源（F48 收口）**：策略数字收口在 `ai_timeouts.dart`，这里与
  /// `ai_router.dart` 一样只做转发。以前两处各维护一对超时常量，靠注释约定
  /// 「必须成对改」——改漏一边，路由层先掐断、Dio 的 receiveTimeout 日志就
  /// 一次都不会出现，「网关慢」和「请求挂死」在日志上长得一模一样
  /// （第八次审查 P1-B）。现在结构性保证 Dio 永远晚于路由层掐断。
  static Duration receiveTimeoutFor(AiProvider provider) =>
      timeouts.receiveTimeoutFor(provider);

  /// 测试注入点。
  ///
  /// 以前 `_dio` 是构造函数里硬编码的私有 final，测试根本没法替换，
  /// 于是「AI 返回 HTML 错误页」「连接超时」这两条最要命的异常路径
  /// 全仓零覆盖——回归永远全绿。生产路径不传，走默认的真实 Dio。
  DeepSeekService({required this.config, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: normalizeBaseUrl(config.baseUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${config.apiKey}',
              },
              connectTimeout: const Duration(seconds: 15),
              // SenseNova 6.8 Flash Lite 响应较慢（评测反馈），需要更长超时
              receiveTimeout: receiveTimeoutFor(config.provider),
            ));

  /// 释放底层 HttpClient 连接池（Dio 泄漏修复）。
  ///
  /// 以前更换 API Key / 切提供商时直接丢弃旧 AiRouter，旧的
  /// DeepSeekService/Dio（含 socket 连接池）从不 close，反复切换会泄漏。
  /// AiRouter.dispose() 会遍历调用本方法；测试注入的 MockDio 不受影响。
  void close() {
    try {
      _dio.close(force: true);
    } catch (_) {
      // 测试注入的 Dio 可能不支持 close，忽略即可
    }
  }

  /// 规范化 baseUrl：去除末尾 /v1 前缀（因为 chatPath/balancePath 通常已经以 /v1/ 开头）
  /// 避免 Agnes 等官方文档风格 "https://api.agnes-ai.cn/v1" + chatPath="/v1/..."
  /// 导致变成 /v1/v1/chat/completions 404
  static String normalizeBaseUrl(String url) {
    var u = url.trim();
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    // 只去除末尾 /v1 版本号，保留 /v2, /v3, /v4 等（这些可能是实际API路径）
    final v1Suffix = RegExp(r'/v1$');
    if (v1Suffix.hasMatch(u)) {
      u = u.replaceFirst(v1Suffix, '');
    }
    return u;
  }

  /// 规范化 path：保证以 / 开头
  static String normalizePath(String path) {
    if (path.startsWith('/')) return path;
    return '/$path';
  }

  /// 把 Dio 的响应体归一化成 Map；不是 JSON 对象就抛可重试异常。
  ///
  /// 服务商在免费/不稳定额度下可能返回 HTTP 200 但响应体是 HTML 错误页、
  /// WAF 拦截页或网关占位页 —— 此时 response.data 不是 Map 而是 String。
  /// 这类响应不是 DioException，一旦对它做下标访问就抛 NoSuchMethodError，
  /// 绕过 on DioException 的归类，在 ai_router 里被当成不可重试的普通异常，
  /// 直接把整个 Key 弃用。
  ///
  /// **chatComplete 与 checkConnection 必须共用这一个函数**：同一个文件、
  /// 同一套 _dio、同一个端点，两条路径对畸形响应的处理不该有分歧。第七轮
  /// 只给 chatComplete 加了防护，checkConnection 照旧崩——而玩家点「测试连接」
  /// 的恰恰就是 AI 连不上、服务商返回错误页的那一刻（第八次审查 P1-A）。
  static Map<String, dynamic> _decodePayload(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.cast<String, dynamic>();
    throw AiRetryableException('AI 返回了非 JSON 响应体（可能被网关拦截），请重试');
  }

  /// 本地区分不同 API Key 的限流桶标识。
  ///
  /// 只用 hashCode，不落盘也不进日志——它只需要在内存里把同一个 Key 的请求
  /// 归到同一个桶，不需要也不应该能反推出 Key 本身。
  String get _keyHash => config.apiKey.hashCode.abs().toRadixString(36);

  /// 发请求前过一遍提供商侧的配额闸门。
  ///
  /// Agnes 免费版限 20 RPM，SenseNova 按模型每 5 小时有配额上限，超了服务方
  /// 直接返 429，玩家看到的就是「AI 卡住了」。这两个闸门此前一次都没被调用过，
  /// 现在在这里接上。等待超时会抛异常，由上层重试/切换提供商兜住。
  Future<void> _acquireSlot() async {
    switch (config.provider) {
      case AiProvider.agnes:
        await AgnesRateLimiter.instance.waitForSlot(_keyHash);
        break;
      case AiProvider.sensenova:
        await SenseNovaQuotaManager.instance.waitForQuota(config.model);
        break;
      case AiProvider.deepseek:
        // Atria 按量计费，不接本地限流闸门（服务端账号级 60 RPM 自会返回 429）
        break;
    }
  }

  Future<ChatResult> chatComplete({
    required String prompt,
    String systemPrompt = '',
    double temperature = 0.8,
    int maxTokens = 4096,
    CancelToken? cancelToken,
    AiStreamCallback? onDelta,
  }) async {
    try {
      await _acquireSlot();
      // 限流排队期间用户可能已取消：token 已掐断时不再发请求，
      // 直接以取消异常收尾，避免「取消后又立刻发起新请求」。
      if (cancelToken?.isCancelled == true) {
        throw AiCanceledException('请求已取消');
      }
      // 只有调用方显式传了 onDelta 才走流式（原因见 _chatCompleteStream 的
      // 注释：全仓 7 个测试文件用非流式 JSON 覆盖异常路径，stream 不能无
      // 条件打开）。不传时走 _chatCompleteOnce —— 就是改动前的请求体，
      // 字节级不变。
      if (onDelta != null) {
        return await _chatCompleteStream(
          prompt: prompt,
          systemPrompt: systemPrompt,
          temperature: temperature,
          maxTokens: maxTokens,
          cancelToken: cancelToken,
          onDelta: onDelta,
        );
      }
      return await _chatCompleteOnce(
        prompt: prompt,
        systemPrompt: systemPrompt,
        temperature: temperature,
        maxTokens: maxTokens,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    } on AiRetryableException {
      rethrow; // 上面结构断言抛出的可重试异常，直接放行
    } on AiCanceledException {
      rethrow; // Q5：用户取消，不得被下面的兜底重包成「解析失败」
    } on AiGateTimeoutException {
      rethrow; // Q7：本地限流/配额排队超时，不是「响应坏了」，不得重包
    } on AiEmptyResponseException {
      rethrow; // Q9：连续空响应=模型不稳定信号，不得被兜底重包
    } catch (e) {
      // 兜底：任何非预期解析异常都归一为可重试，避免被当成 Key 失效
      throw AiRetryableException('AI 响应解析失败: $e');
    }
  }

  /// 非流式单次请求 —— 改动前的 `chatComplete` 主体，逐字保留。
  ///
  /// 抽成独立方法只是为了让流式与非流式共用同一套错误语义（_handleError、
  /// 空响应归类、可重试归一），而不是把 `'stream'` 一开了之。
  Future<ChatResult> _chatCompleteOnce({
    required String prompt,
    required String systemPrompt,
    required double temperature,
    required int maxTokens,
    required CancelToken? cancelToken,
  }) async {
    final response = await _dio.post(
      normalizePath(config.chatPath),
      data: jsonEncode({
        'model': config.model,
        'messages': [
          if (systemPrompt.isNotEmpty)
            {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': prompt},
        ],
        'temperature': temperature,
        'max_tokens': maxTokens,
        'stream': false,
      }),
      cancelToken: cancelToken,
    );

    // 任何畸形响应都归一为 AiRetryableException，让路由层能正常重试/切 Key
    // （详见 _decodePayload 的注释）。
    final payload = _decodePayload(response.data);
    final choices = payload['choices'];
    final first = (choices is List && choices.isNotEmpty) ? choices[0] : null;
    final message = (first is Map) ? first['message'] : null;
    final content = (message is Map) ? (message['content'] as String? ?? '') : '';
    Map<String, dynamic>? usageData;
    final rawUsage = payload['usage'];
    if (rawUsage is Map) {
      usageData = rawUsage.cast<String, dynamic>();
    }
    final usage = TokenUsage.fromJson(usageData ?? const {});

    // 空响应同样要可重试：模型偶发空输出是高频事件，不该被放大成「Key 失效」。
    if (content.isEmpty) {
      _throwEmptyResponse();
    }
    // 成功响应清零连续空响应计数（Q9：该模型恢复稳定）
    EmptyResponseMonitor.instance.recordSuccess(
        config.provider.name, config.model);
    return ChatResult(content: content, usage: usage);
  }

  /// 空响应归类（Q9）—— 非流式与流式共用同一套判定。
  ///
  /// 连续空响应达到阈值 → [AiEmptyResponseException]，路由层据此跳过该提供商
  /// **全部** Key 并提示换稳定模型；偶发空响应 → [AiEmptyRetryableException]，
  /// 可重试且**不记 Key 熔断**（空响应是模型质量问题，不是 Key 问题）。
  Never _throwEmptyResponse() {
    final providerName = config.provider.name;
    final degraded = EmptyResponseMonitor.instance
        .recordEmpty(providerName, config.model);
    if (degraded) {
      throw AiEmptyResponseException(
        providerName,
        config.model,
        '模型 ${config.model} 连续${EmptyResponseMonitor.degradeThreshold}次返回空响应，'
        '已判定不稳定；建议在设置页更换稳定模型',
      );
    }
    throw AiEmptyRetryableException('AI 返回了空响应，请重试');
  }

  /// 流式生成（SSE）。仅在调用方传入 [onDelta] 时启用。
  ///
  /// 【为什么是「按调用方选择开启」而不是直接把 stream 打开】
  /// 全仓有 7 个测试文件用本地 HTTP 服务喂**非流式** JSON 来覆盖异常路径
  /// （HTML 错误页、连接超时、空响应、取消……）。一旦无条件 `'stream': true`，
  /// 这些用例读到的就是 SSE 文本，`choices[0].message` 恒为空 → 全红。
  /// 所以流式是一条**新增**通道：不传 onDelta 时一个字节都不变。
  ///
  /// 【降级策略】流式失败分两类，处理方式不同：
  ///  - **一个 SSE 帧都没收到**（网关不转发、提供商不认 stream_options 而返
  ///    400、响应体不是流）→ 自动退回一次非流式请求。结果是「没提速」，
  ///    而不是「功能坏了」。
  ///  - **已经吐过字**才失败 → 如实上抛，由路由层换 Key / 上层重试，并把
  ///    预览重置（onDelta 的 reset 语义），避免两次尝试的半截文本拼一起。
  Future<ChatResult> _chatCompleteStream({
    required String prompt,
    required String systemPrompt,
    required double temperature,
    required int maxTokens,
    required CancelToken? cancelToken,
    required AiStreamCallback onDelta,
  }) async {
    // 区分「通道不通」与「模型空答」：前者降级重发，后者直接走空响应归类。
    var sawFrame = false; // 收到过任意 data: 帧
    final buffer = StringBuffer();
    var usage = const TokenUsage(
      promptTokens: 0,
      completionTokens: 0,
      totalTokens: 0,
    );

    Future<ChatResult> degradeToNonStream() => _chatCompleteOnce(
          prompt: prompt,
          systemPrompt: systemPrompt,
          temperature: temperature,
          maxTokens: maxTokens,
          cancelToken: cancelToken,
        );

    try {
      final response = await _dio.post(
        normalizePath(config.chatPath),
        data: jsonEncode({
          'model': config.model,
          'messages': [
            if (systemPrompt.isNotEmpty)
              {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': temperature,
          'max_tokens': maxTokens,
          'stream': true,
          // OpenAI 兼容实现只在显式要求时，才在最后一个 chunk 里回 usage。
          // 不认这个字段的服务商返 400 —— 由「无帧即降级」兜住。
          'stream_options': {'include_usage': true},
        }),
        options: Options(responseType: ResponseType.stream),
        cancelToken: cancelToken,
      );
      final raw = response.data;
      if (raw is! ResponseBody) {
        throw AiRetryableException('流式响应体类型异常（${raw.runtimeType}）');
      }
      // utf8.decoder 会缓冲跨块的多字节字符、LineSplitter 会缓冲不完整的行，
      // 所以中文正文不会因为分块位置而乱码或截断。
      final lines = raw.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || !trimmed.startsWith('data:')) continue;
        final dataPart = trimmed.substring(5).trim();
        if (dataPart.isEmpty) continue;
        sawFrame = true;
        if (dataPart == '[DONE]') break;
        Map<String, dynamic> chunk;
        try {
          final decoded = jsonDecode(dataPart);
          if (decoded is! Map) continue;
          chunk = decoded.cast<String, dynamic>();
        } catch (_) {
          // 单个畸形 chunk 不该毁掉整段生成：跳过继续读。
          continue;
        }
        final rawUsage = chunk['usage'];
        if (rawUsage is Map) {
          usage = TokenUsage.fromJson(rawUsage.cast<String, dynamic>());
        }
        final choices = chunk['choices'];
        if (choices is! List || choices.isEmpty) continue;
        final first = choices[0];
        if (first is! Map) continue;
        final delta = first['delta'];
        if (delta is! Map) continue;
        final piece = delta['content'];
        if (piece is! String || piece.isEmpty) continue;
        buffer.write(piece);
        onDelta(piece, reset: false);
      }
    } on DioException catch (e) {
      if (!sawFrame) return await degradeToNonStream();
      _handleError(e);
      rethrow;
    } on AiRetryableException {
      if (!sawFrame) return await degradeToNonStream();
      rethrow;
    }

    // 一个帧都没收到（端点直接返回普通 JSON 或空体）：同「通道不通」处理。
    if (!sawFrame) return await degradeToNonStream();

    final content = buffer.toString();
    if (content.isEmpty) {
      // 通道是通的（收到过帧），只是模型没吐正文 → 走同一套空响应归类，
      // 不再降级重发，避免把「模型空答」放大成两次请求。
      _throwEmptyResponse();
    }
    EmptyResponseMonitor.instance.recordSuccess(
        config.provider.name, config.model);
    return ChatResult(content: content, usage: usage);
  }


  /// 区分服务商 429 的两种常见语义（Q16），给出可行动的文案：
  /// - 配额耗尽（quota / insufficient / 额度 / 次数用尽）→ 需要等 5 小时窗口重置
  /// - 速率限制（rate limit / too many requests / 限流）→ 稍等再试通常能恢复
  /// 判定只做关键词软匹配，拿不准就给通用文案，绝不臆造具体数字。
  @visibleForTesting
  static String classify429(String msg) {
    final m = msg.toLowerCase();
    final isQuota = m.contains('quota') ||
        m.contains('insufficient') ||
        m.contains('exceeded the quota') ||
        m.contains('额度') ||
        m.contains('次数用尽');
    final isRateLimit = m.contains('rate limit') ||
        m.contains('too many requests') ||
        m.contains('限流') ||
        m.contains('频繁');
    if (isQuota) {
      return '服务商配额已用尽（HTTP 429），需等待配额窗口（如 SenseNova 每 5 小时）重置后再试';
    }
    if (isRateLimit) {
      return '服务商限流（HTTP 429）：请求过于频繁，请稍等片刻再试';
    }
    return '请求过于频繁（HTTP 429），请稍后重试 - $msg';
  }

  void _handleError(DioException e) {
    final statusCode = e.response?.statusCode;
    final body = e.response?.data;
    String msg = e.message ?? 'Unknown error';

    if (body is Map<String, dynamic>) {
      final err = body['error'];
      if (err is Map<String, dynamic>) {
        msg = err['message'] as String? ?? msg;
      } else if (err is String) {
        msg = err;
      }
    }

    if (statusCode == 401) {
      throw AiNonRetryableException('API Key 无效，请检查设置');
    } else if (statusCode == 404) {
      throw AiNonRetryableException('API 端点不存在，请检查 Base URL 设置');
    } else if (statusCode == 429) {
      // Q16：HTTP 429 直接来自服务商，是「服务商侧」的限流/配额——
      // 与本地限流闸门（_acquireSlot 超时抛 RateLimitWaitTimeout，
      // "Q7：本地限流/配额排队超时"已经分流，不会走到这里）不同。
      // 文案要能把玩家引到正确的方向：该等窗口重置，而不是去改 Key。
      throw AiRetryableException(classify429(msg));
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      // 标记为超时：路由层看到 isTimeout 会直接换 Key，而不是再花 35 秒
      // 重试同一把——那点预算该留给下一个 Key。
      throw AiRetryableException('请求超时（${e.type.name}），请重试',
          isTimeout: true);
    } else if (e.type == DioExceptionType.cancel) {
      // 用户主动取消（Q5）：不归类成网络错误，让上层走「静默收尾」路径。
      throw AiCanceledException('请求已取消');
    } else if (statusCode != null && statusCode >= 400 && statusCode < 500) {
      throw AiNonRetryableException('API 错误 ($statusCode): $msg');
    } else {
      throw AiRetryableException('网络错误: $msg');
    }
  }

  /// 测试连接。成功返回 true，失败抛出带具体原因的 Exception（404/401/429/500/超时）
  Future<bool> checkConnection() async {
    try {
      final response = await _dio.post(
        normalizePath(config.chatPath),
        data: jsonEncode({
          'model': config.model,
          'messages': [
            {'role': 'user', 'content': 'Hi, reply with OK.'},
          ],
          'max_tokens': 10,
          'stream': false,
        }),
      );
      final payload = _decodePayload(response.data);
      final choices = payload['choices'];
      return choices is List && choices.isNotEmpty;
    } on AiRetryableException catch (e) {
      // 非 JSON 响应体：这是「连上了，但对端返回的不是 AI 响应」，
      // 与网络不通是两回事，文案要能把人指向正确的方向。
      throw Exception('${config.baseUrl} 返回的不是 JSON 响应（可能被网关拦截）：${e.message}');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final body = e.response?.data;
      // 先尝试提取服务商返回的错误 message
      String detail = '';
      if (body is Map<String, dynamic>) {
        final err = body['error'];
        if (err is Map<String, dynamic>) {
          detail = err['message'] as String? ?? '';
        } else if (err is String) {
          detail = err;
        }
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw Exception('连接超时（${config.baseUrl}），请检查网络或 Base URL');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw Exception('无法连接到 ${config.baseUrl}，请检查 Base URL 或网络');
      }
      if (statusCode == 401 || statusCode == 403) {
        throw Exception('认证失败：API Key 无效（HTTP $statusCode）${detail.isNotEmpty ? ' - $detail' : ''}');
      }
      if (statusCode == 404) {
        final full = '${normalizeBaseUrl(config.baseUrl)}${normalizePath(config.chatPath)}';
        throw Exception('端点不存在 (404)：最终请求路径 $full，请检查 Base URL 与服务商是否匹配');
      }
      if (statusCode == 429) {
        throw Exception(classify429(detail));
      }
      if (statusCode == 400) {
        throw Exception('请求参数错误（HTTP 400）${detail.isNotEmpty ? '：$detail' : '，可能模型名与服务商不匹配'}');
      }
      if (statusCode != null && statusCode >= 500) {
        throw Exception('服务商服务器错误（HTTP $statusCode）${detail.isNotEmpty ? ' - $detail' : ''}');
      }
      rethrow;
    }
  }

  Future<double?> getBalance() async {
    final path = config.balancePath;
    if (path == null) return null;
    try {
      final response = await _dio.get(normalizePath(path));
      // 与 chatComplete / checkConnection 共用同一套结构断言：余额接口同样
      // 可能返回 HTML 错误页。失败会被下面的 catch 降级成 null。
      final data = _decodePayload(response.data);

      if (config.provider == AiProvider.deepseek) {
        final infos = data['balance_infos'] as List?;
        if (infos != null && infos.isNotEmpty) {
          final first = infos.first as Map<String, dynamic>;
          final bal = first['total_balance'];
          if (bal is num) return bal.toDouble();
          if (bal is String) return double.tryParse(bal);
        }
        return null;
      } else if (config.provider == AiProvider.agnes) {
        return null;
      } else if (config.provider == AiProvider.sensenova) {
        // SenseNova（platform.sensenova.cn）公测期间无公开余额查询API，
        // 额度仅在控制台页面展示。如需查询请登录 https://platform.sensenova.cn/
        return null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

}
