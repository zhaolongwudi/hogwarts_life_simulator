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

  DeepSeekService({required this.config})
      : _dio = Dio(BaseOptions(
          baseUrl: config.baseUrl,
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
        config.chatPath,
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

  Future<String> chat({
    required String prompt,
    String systemPrompt = '',
    double temperature = 0.8,
    int maxTokens = 4096,
  }) async {
    final result = await chatComplete(
      prompt: prompt,
      systemPrompt: systemPrompt,
      temperature: temperature,
      maxTokens: maxTokens,
    );
    return result.content;
  }

  Future<String> chatWithMessages({
    required List<Map<String, dynamic>> messages,
    double temperature = 0.8,
    int maxTokens = 4096,
  }) async {
    try {
      final response = await _dio.post(
        config.chatPath,
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

  Future<bool> checkConnection() async {
    try {
      final response = await _dio.post(
        config.chatPath,
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
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return false;
      }
      if (e.response?.statusCode != null && e.response!.statusCode! < 500) {
        return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<double?> getBalance() async {
    final path = config.balancePath;
    if (path == null) return null;
    try {
      final response = await _dio.get(path);
      final data = response.data;

      if (config.provider == AiProvider.deepseek) {
        return (data['total_balance'] as num?)?.toDouble();
      } else if (config.provider == AiProvider.zhipu) {
        final balance = data['data']?['balance'] ?? data['balance'];
        if (balance is num) return balance.toDouble();
        if (balance is String) return double.tryParse(balance);
        final remaining = data['data']?['remaining'];
        if (remaining is num) return remaining.toDouble();
        return null;
      } else if (config.provider == AiProvider.agnes) {
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
      final response = await _dio.get(path);
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
