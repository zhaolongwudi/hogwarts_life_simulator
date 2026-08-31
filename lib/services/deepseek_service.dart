import 'dart:convert';
import 'package:dio/dio.dart';
import '../providers/app_provider.dart';
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

class DeepSeekService {
  final AiConfig config;
  final Dio _dio;

  /// Dio 的接收超时（按提供商区分：SenseNova 慢一些）。
  ///
  /// 必须**大于**路由层的单次调用预算 [AiRouter.perCallTimeoutFor]，让路由层
  /// 先掐断、Dio 这条只做兜底。以前两边各写各的数字（路由 35 秒、
  /// SenseNova 60 秒），关系反了也没人发现：SenseNova 一挂住，永远是路由层
  /// 先超时，Dio 那条 receiveTimeout 日志一次都不会出现，「网关慢」和
  /// 「请求挂死」在日志上长得一模一样（第八次审查 P1-B）。
  static const Duration receiveTimeoutDefault = Duration(seconds: 45);
  static const Duration receiveTimeoutSensenova = Duration(seconds: 60);

  /// [provider] 对应的 Dio 接收超时。路由层的全局预算也按 provider 取值，
  /// 两边必须成对改，所以收口成一个函数而不是在构造函数里散着写三元。
  static Duration receiveTimeoutFor(AiProvider provider) =>
      provider == AiProvider.sensenova
          ? receiveTimeoutSensenova
          : receiveTimeoutDefault;

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
        // DeepSeek 按量计费，无限流闸门
        break;
    }
  }

  Future<ChatResult> chatComplete({
    required String prompt,
    String systemPrompt = '',
    double temperature = 0.8,
    int maxTokens = 4096,
    CancelToken? cancelToken,
  }) async {
    try {
      await _acquireSlot();
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
        throw AiRetryableException('AI 返回了空响应，请重试');
      }
      return ChatResult(content: content, usage: usage);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    } on AiRetryableException {
      rethrow; // 上面结构断言抛出的可重试异常，直接放行
    } catch (e) {
      // 兜底：任何非预期解析异常都归一为可重试，避免被当成 Key 失效
      throw AiRetryableException('AI 响应解析失败: $e');
    }
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
      throw AiRetryableException('请求过于频繁，请稍后重试');
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      // 标记为超时：路由层看到 isTimeout 会直接换 Key，而不是再花 35 秒
      // 重试同一把——那点预算该留给下一个 Key。
      throw AiRetryableException('请求超时（${e.type.name}），请重试',
          isTimeout: true);
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
        throw Exception('请求过于频繁（HTTP 429），请稍后重试${detail.isNotEmpty ? ' - $detail' : ''}');
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
