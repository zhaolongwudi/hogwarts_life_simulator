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

  /// 进行中的调用（callId → 当前缓冲内容），用于把 START+RESPONSE/ERROR 拼成一条
  /// 避免并行调用（如narrative和choice）时START和RESPONSE交叉写入
  final Map<String, StringBuffer> _pendingCalls = {};

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

  /// 生成一个调用ID（timestamp + 场景 + 短随机），唯一标识一次 START→RESPONSE/ERROR 配对
  String _newCallId(String scene, String provider) {
    final ts = DateTime.now().microsecondsSinceEpoch;
    return '$ts-$scene-$provider';
  }

  /// 记录 START 阶段 → 返回 callId，后续 RESPONSE/ERROR/TIMEOUT 用这个 callId 追加并完成
  Future<String?> logStart({
    required String timestamp,
    required String scene,
    required String provider,
    required String promptPreview,
    String? systemPrompt,
  }) async {
    if (!_enabled) return null;
    try {
      await _ensureLogDir();
      final callId = _newCallId(scene, provider);
      final buf = StringBuffer();
      buf.writeln('═══════════════════════════════════');
      buf.writeln('时间: $timestamp');
      buf.writeln('场景: $scene');
      buf.writeln('模型: $provider');
      buf.writeln('动作: START');
      buf.writeln('CallID: $callId');
      buf.writeln('═══════════════════════════════════');
      buf.writeln('【发送给模型的 Prompt】');
      buf.writeln('---');
      buf.writeln(promptPreview);
      buf.writeln('---');
      if (systemPrompt != null && systemPrompt.isNotEmpty) {
        buf.writeln('【System Prompt】');
        buf.writeln('---');
        buf.writeln(systemPrompt);
        buf.writeln('---');
      }
      _pendingCalls[callId] = buf;
      return callId;
    } catch (e) {
      debugPrint('AiDebugLogger logStart 失败: $e');
      return null;
    }
  }

  /// 记录 RESPONSE / ERROR / TIMEOUT 阶段：用 callId 找到 START 缓冲，合并成一条再落盘
  Future<void> logComplete({
    required String? callId,
    required String timestamp,
    required String scene,
    required String provider,
    required String action, // 'RESPONSE' / 'ERROR' / 'TIMEOUT'
    String? responsePreview,
    int? promptTokens,
    int? completionTokens,
    int? totalTokens,
    String? error,
  }) async {
    if (!_enabled) return;
    try {
      await _ensureLogDir();
      StringBuffer buf;
      if (callId != null && _pendingCalls.containsKey(callId)) {
        buf = _pendingCalls.remove(callId)!;
        // 追加一个分隔区块区分 START 和完成阶段
        buf.writeln('');
        buf.writeln('───────────────────────────────────');
        buf.writeln('完成时间: $timestamp');
        buf.writeln('动作: $action');
        buf.writeln('───────────────────────────────────');
      } else {
        // 找不到对应的START（极端情况），单独写一条带说明
        buf = StringBuffer();
        buf.writeln('═══════════════════════════════════');
        buf.writeln('时间: $timestamp');
        buf.writeln('场景: $scene');
        buf.writeln('模型: $provider');
        buf.writeln('动作: $action（对应START缺失，可能是日志开关中途切换）');
        buf.writeln('═══════════════════════════════════');
      }

      if (responsePreview != null) {
        buf.writeln('【模型返回内容】');
        buf.writeln('---');
        buf.writeln(responsePreview);
        buf.writeln('---');
      }
      if (error != null) {
        buf.writeln('【错误信息】');
        buf.writeln('---');
        buf.writeln(error);
        buf.writeln('---');
      }
      if (promptTokens != null || completionTokens != null || totalTokens != null) {
        buf.writeln('【Token 统计】');
        buf.writeln('---');
        buf.writeln('输入: ${promptTokens ?? '-'} tokens');
        buf.writeln('输出: ${completionTokens ?? '-'} tokens');
        buf.writeln('总计: ${totalTokens ?? '-'} tokens');
        buf.writeln('---');
      }

      buf.writeln('');
      final logLine = buf.toString();
      _controller.add(logLine);
      await _writeToFile(logLine);
    } catch (e) {
      debugPrint('AiDebugLogger logComplete 失败: $e');
    }
  }

  /// 兼容旧版 API：一次性写入 START/RESPONSE/ERROR（无配对）
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
    if (_logDir == null) {
      await _ensureLogDir();
      if (_logDir == null) return [];
    }
    final dir = Directory(_logDir!);
    if (!await dir.exists()) return [];
    final files = await dir.list().toList();
    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files.whereType<File>().map((f) => f.path).toList();
  }

  Future<Map<String, dynamic>> getUsageStats() async {
    final files = await getLogFiles();
    int totalCalls = 0;
    int totalSize = 0;
    for (final p in files) {
      final f = File(p);
      totalSize += await f.length();
      final content = await f.readAsString();
      totalCalls += '═══════════════════════════════════'.allMatches(content).length;
    }
    return {
      'files': files.length,
      'calls': totalCalls,
      'sizeBytes': totalSize,
    };
  }

  /// 读取指定路径的日志文件文本（用于设置页 LogViewerDialog）
  Future<String?> readLogFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (e) {
      debugPrint('读取日志失败 $path: $e');
      return '读取失败: $e';
    }
  }

  Future<void> clearAllLogs() async {
    final files = await getLogFiles();
    for (final p in files) {
      try {
        await File(p).delete();
      } catch (e) {
        debugPrint('删除日志失败: $p $e');
      }
    }
    _pendingCalls.clear();
  }
}
