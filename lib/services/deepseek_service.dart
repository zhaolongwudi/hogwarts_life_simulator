import 'dart:convert';
import 'package:dio/dio.dart';

class DeepSeekService {
  final String apiKey;
  final Dio _dio;

  DeepSeekService({required this.apiKey})
      : _dio = Dio(BaseOptions(
          baseUrl: 'https://api.deepseek.com',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ));

  Future<String> chat({
    required String prompt,
    String systemPrompt = '',
    double temperature = 0.8,
    int maxTokens = 2000,
  }) async {
    try {
      final response = await _dio.post(
        '/v1/chat/completions',
        data: jsonEncode({
          'model': 'deepseek-chat',
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

      if (response.data['choices']?.isNotEmpty == true) {
        return response.data['choices'][0]['message']['content'] as String;
      }
      throw Exception('Empty response from DeepSeek');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('API Key 无效，请检查设置');
      } else if (e.response?.statusCode == 429) {
        throw Exception('请求过于频繁，请稍后重试');
      }
      throw Exception('API 错误: ${e.message}');
    }
  }

  Future<bool> checkConnection() async {
    try {
      await _dio.get('/v1/models');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<double?> getBalance() async {
    try {
      final response = await _dio.get('/v1/balance');
      return (response.data['total_balance'] as num?)?.toDouble();
    } catch (_) {
      return null;
    }
  }
}
