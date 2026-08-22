import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// AI 调用调试日志记录器
/// 用于记录每回合的输入输出，排查上下文污染、路由错误等问题
class AiDebugLogger {
  static AiDebugLogger? _instance;
  static AiDebugLogger get instance => _instance ??= AiDebugLogger._();
  AiDebugLogger._();

  String? _logDir;
  bool _enabled = false;
  final _controller = StreamController<String>.broadcast();

  bool get enabled => _enabled;
  Stream<String> get logs => _controller.stream;

  Future<void> initialize({bool enabled = false}) async {
    _enabled = enabled;
    if (enabled) {
      await _ensureLogDir();
    }
  }

  Future<void> _ensureLogDir() async {
    if (_logDir != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _logDir = '${dir.path}/ai_debug_logs';
    final logDir = Directory(_logDir!);
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
  }

  void setEnabled(bool value) {
    _enabled = value;
    if (value) {
      _ensureLogDir();
    }
  }

  /// 记录 AI 调用
  Future<void> logCall({
    required String timestamp,
    required String scene,
    required String provider,
    required String action,
    String? promptPreview,
    String? systemPrompt,
    String? responsePreview,
    int? promptTokens,
    int? completionTokens,
    int? totalTokens,
    String? error,
  }) async {
    if (!_enabled) return;

    try {
      await _ensureLogDir();
      final logEntry = StringBuffer();
      logEntry.writeln('═══════════════════════════════════');
      logEntry.writeln('时间: $timestamp');
      logEntry.writeln('场景: $scene');
      logEntry.writeln('模型: $provider');
      logEntry.writeln('动作: $action');
      logEntry.writeln('═══════════════════════════════════');

      if (promptPreview != null) {
        logEntry.writeln('【发送给模型的 Prompt】');
        logEntry.writeln('---');
        logEntry.writeln(promptPreview);
        logEntry.writeln('---');
      }

      if (systemPrompt != null && systemPrompt.isNotEmpty) {
        logEntry.writeln('【System Prompt】');
        logEntry.writeln('---');
        logEntry.writeln(systemPrompt);
        logEntry.writeln('---');
      }

      if (responsePreview != null) {
        logEntry.writeln('【模型返回内容】');
        logEntry.writeln('---');
        logEntry.writeln(responsePreview);
        logEntry.writeln('---');
      }

      if (error != null) {
        logEntry.writeln('【错误信息】');
        logEntry.writeln('---');
        logEntry.writeln(error);
        logEntry.writeln('---');
      }

      if (promptTokens != null || completionTokens != null || totalTokens != null) {
        logEntry.writeln('【Token 统计】');
        logEntry.writeln('---');
        logEntry.writeln('输入: ${promptTokens ?? '-'} tokens');
        logEntry.writeln('输出: ${completionTokens ?? '-'} tokens');
        logEntry.writeln('总计: ${totalTokens ?? '-'} tokens');
        logEntry.writeln('---');
      }

      logEntry.writeln('');

      final logLine = logEntry.toString();
      _controller.add(logLine);

      await _writeToFile(logLine);
    } catch (e) {
      debugPrint('AiDebugLogger 写入失败: $e');
    }
  }

  Future<void> _writeToFile(String content) async {
    if (_logDir == null) return;
    final now = DateTime.now();
    final fileName = 'ai_log_${now.year}${_pad(now.month)}${_pad(now.day)}.txt';
    final file = File('${_logDir!}/$fileName');

    await file.writeAsString(content, mode: FileMode.append);
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  Future<List<String>> getLogFiles() async {
    if (_logDir == null) return [];
    final dir = Directory(_logDir!);
    if (!await dir.exists()) return [];
    final files = await dir.list().where((f) => f.path.endsWith('.txt')).toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files.map((f) => f.path).toList();
  }

  Future<String?> readLogFile(String path) async {
    try {
      return await File(path).readAsString();
    } catch (e) {
      return null;
    }
  }

  Future<void> clearAllLogs() async {
    if (_logDir == null) return;
    final dir = Directory(_logDir!);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      _logDir = null;
      await _ensureLogDir();
    }
  }

  String getLogDirPath() => _logDir ?? '';

  /// 获取日志摘要，用于快速查看
  Future<List<Map<String, String>>> getLogSummary() async {
    final files = await getLogFiles();
    final summaries = <Map<String, String>>[];
    for (final path in files.take(30)) {
      final content = await readLogFile(path);
      if (content != null) {
        final timestampMatch = RegExp(r'时间: (.+)').firstMatch(content);
        final sceneMatch = RegExp(r'场景: (.+)').firstMatch(content);
        final providerMatch = RegExp(r'模型: (.+)').firstMatch(content);
        final tokenMatch = RegExp(r'总计: (\d+)').firstMatch(content);

        summaries.add({
          'file': path.split('/').last,
          'timestamp': timestampMatch?.group(1) ?? '未知',
          'scene': sceneMatch?.group(1) ?? '未知',
          'provider': providerMatch?.group(1) ?? '未知',
          'tokens': tokenMatch?.group(1) ?? '-',
        });
      }
    }
    return summaries;
  }
}
