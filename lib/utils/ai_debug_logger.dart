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
    required String action, // 'RESPONSE' / 'ERROR' / 'TIMEOUT' / 'FALLBACK'
    String? responsePreview,
    int? promptTokens,
    int? completionTokens,
    int? totalTokens,
    String? error,
    bool keepPending = false, // true 表示 fallback 中间失败，不终结本次调用，等最终结果再合并
  }) async {
    if (!_enabled) return;
    try {
      await _ensureLogDir();
      if (keepPending && callId != null && _pendingCalls.containsKey(callId)) {
        // 备用模型失败：不终结调用，仅落一条简短的失败说明，等待后续成功/超时合并
        final line = '  └─ 备用模型 $provider 失败: $error\n';
        _controller.add(line);
        await _writeToFile(line);
        return;
      }
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
  static const int _maxFileBytes = 4 * 1024 * 1024; // 单日日志文件上限 4MB，防止无限膨胀

  Future<void> _writeToFile(String content) async {
    if (_logDir == null) return;
    final now = DateTime.now();
    final fileName = 'ai_log_${now.year}${_pad(now.month)}${_pad(now.day)}.txt';
    final file = File('${_logDir!}/$fileName');

    try {
      if (await file.exists() && await file.length() > _maxFileBytes) {
        // 当日日志超过上限：轮转，仅保留最新条目，避免磁盘被日志撑满
        await file.writeAsString(content, flush: true);
      } else {
        await file.writeAsString(content, mode: FileMode.append, flush: true);
      }
    } catch (e) {
      debugPrint('AiDebugLogger 写入失败: $e');
    }

    await _pruneOldLogs();
  }

  /// 只保留最近 7 天的日志文件，清理更早的，防止 ai_log 目录无限增长
  Future<void> _pruneOldLogs() async {
    if (_logDir == null) return;
    try {
      final dir = Directory(_logDir!);
      if (!await dir.exists()) return;
      final files = (await dir.list().toList()).whereType<File>().toList();
      if (files.length <= 7) return;
      final pairs = <(File, DateTime)>[];
      for (final f in files) {
        DateTime modified;
        try {
          modified = (await f.stat()).modified;
        } catch (_) {
          modified = DateTime.fromMillisecondsSinceEpoch(0);
        }
        pairs.add((f, modified));
      }
      pairs.sort((a, b) => b.$2.compareTo(a.$2));
      for (final p in pairs.skip(7)) {
        try {
          await p.$1.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  Future<List<String>> getLogFiles() async {
    if (_logDir == null) {
      await _ensureLogDir();
      if (_logDir == null) return [];
    }
    final dir = Directory(_logDir!);
    if (!await dir.exists()) return [];
    final files = (await dir.list().toList()).whereType<File>().toList();
    // 用异步 stat() 替代同步 statSync()，避免在 UI 线程做阻塞式文件 I/O
    final pairs = <MapEntry<File, DateTime>>[];
    for (final f in files) {
      DateTime modified;
      try {
        modified = (await f.stat()).modified;
      } catch (_) {
        modified = DateTime.fromMillisecondsSinceEpoch(0);
      }
      pairs.add(MapEntry(f, modified));
    }
    pairs.sort((a, b) => b.value.compareTo(a.value));
    return pairs.map((e) => e.key.path).toList();
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
