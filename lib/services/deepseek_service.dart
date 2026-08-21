import 'dart:convert';
import 'package:dio/dio.dart';
import '../providers/app_provider.dart';

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

class DeepSeekService {
  final AiConfig config;
  final Dio _dio;

  /// 规范化 baseUrl：去除末尾 /v1 前缀（因为 chatPath/balancePath 通常已经以 /v1/ 开头）
  /// 避免 Agnes 等官方文档风格 "https://api.agnes-ai.cn/v1" + chatPath="/v1/..."
  /// 导致变成 /v1/v1/chat/completions 404
  static String normalizeBaseUrl(String url) {
    var u = url.trim();
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    // 如果 baseUrl 末尾带 /v1 或 /v2 或 /v3 版本号，去掉它
    final versionSuffix = RegExp(r'/v\d+$');
    if (versionSuffix.hasMatch(u)) {
      u = u.replaceFirst(versionSuffix, '');
    }
    return u;
  }

  /// 规范化 path：保证以 / 开头
  static String normalizePath(String path) {
    if (path.startsWith('/')) return path;
    return '/$path';
  }

  DeepSeekService({required this.config})
      : _dio = Dio(BaseOptions(
          baseUrl: normalizeBaseUrl(config.baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${config.apiKey}',
          },
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ));

  Future<ChatResult> chatComplete({
    required String prompt,
    String systemPrompt = '',
    double temperature = 0.8,
    int maxTokens = 4096,
  }) async {
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
          'stream': false,
        }),
      );

      final data = response.data;
      final content = data['choices']?[0]['message']['content'] as String? ?? '';
      final usageData = data['usage'] as Map<String, dynamic>? ?? {};
      final usage = TokenUsage.fromJson(usageData);

      if (content.isEmpty) {
        throw Exception('Empty response from AI');
      }
      return ChatResult(content: content, usage: usage);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<String> chatWithMessages({
    required List<Map<String, dynamic>> messages,
    double temperature = 0.8,
    int maxTokens = 4096,
  }) async {
    try {
      final response = await _dio.post(
        normalizePath(config.chatPath),
        data: jsonEncode({
          'model': config.model,
          'messages': messages,
          'temperature': temperature,
          'max_tokens': maxTokens,
          'stream': false,
        }),
      );

      final data = response.data;
      final content = data['choices']?[0]['message']['content'] as String? ?? '';
      if (content.isEmpty) {
        throw Exception('Empty response from AI');
      }
      return content;
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
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
      throw Exception('API Key 无效，请检查设置');
    } else if (statusCode == 429) {
      throw Exception('请求过于频繁，请稍后重试');
    } else if (statusCode == 404) {
      throw Exception('API 端点不存在，请检查 Base URL 设置');
    } else if (statusCode != null && statusCode >= 400) {
      throw Exception('API 错误 ($statusCode): $msg');
    } else {
      throw Exception('网络错误: $msg');
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
      return response.data['choices']?.isNotEmpty == true;
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
      final data = response.data;

      if (config.provider == AiProvider.deepseek) {
        final infos = data['balance_infos'] as List?;
        if (infos != null && infos.isNotEmpty) {
          final first = infos.first as Map<String, dynamic>;
          final bal = first['total_balance'];
          if (bal is num) return bal.toDouble();
          if (bal is String) return double.tryParse(bal);
        }
        return null;
      } else if (config.provider == AiProvider.zhipu) {
        final balance = data['data']?['balance'] ?? data['balance'];
        if (balance is num) return balance.toDouble();
        if (balance is String) return double.tryParse(balance);
        final remaining = data['data']?['remaining'];
        if (remaining is num) return remaining.toDouble();
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

  Future<Map<String, dynamic>?> getQuotaInfo() async {
    final path = config.balancePath;
    if (path == null) return null;
    try {
      final response = await _dio.get(normalizePath(path));
      if (config.provider == AiProvider.zhipu) {
        final data = response.data['data'] as Map<String, dynamic>?;
        return data;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
