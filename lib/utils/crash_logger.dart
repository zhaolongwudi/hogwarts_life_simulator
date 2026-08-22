import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CrashEntry {
  final DateTime time;
  final String error;
  final String stackTrace;
  final String screen;
  final String extra;

  CrashEntry({
    required this.time,
    required this.error,
    required this.stackTrace,
    this.screen = '',
    this.extra = '',
  });

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'error': error,
        'stackTrace': stackTrace,
        'screen': screen,
        'extra': extra,
      };

  factory CrashEntry.fromJson(Map<String, dynamic> j) => CrashEntry(
        time: DateTime.tryParse(j['time'] ?? '') ?? DateTime.now(),
        error: (j['error'] ?? '').toString(),
        stackTrace: (j['stackTrace'] ?? '').toString(),
        screen: (j['screen'] ?? '').toString(),
        extra: (j['extra'] ?? '').toString(),
      );

  String formatShort() {
    final ts =
        '${time.year.toString().padLeft(4, '0')}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return '⏱ $ts\n❌ $error\n${screen.isNotEmpty ? '📍 场景：$screen\n' : ''}${extra.isNotEmpty ? '💡 补充：$extra\n' : ''}────────';
  }
}

class CrashLogger {
  static CrashLogger? _instance;
  static CrashLogger get instance => _instance ??= CrashLogger._();
  CrashLogger._();

  List<CrashEntry> _entries = [];
  List<CrashEntry> get entries => List.unmodifiable(_entries);

  File? _logFile;
  Future<File> _ensureFile() async {
    if (_logFile != null) return _logFile!;
    final dir = await getApplicationDocumentsDirectory();
    _logFile = File('${dir.path}/crash_logs.json');
    if (!await _logFile!.exists()) {
      await _logFile!.writeAsString(jsonEncode([]));
    }
    return _logFile!;
  }

  Future<void> load() async {
    try {
      final f = await _ensureFile();
      final content = await f.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      _entries = list
          .map((e) => CrashEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[CrashLogger] 读取日志失败: $e');
      _entries = [];
    }
  }

  Future<void> record(
    dynamic error,
    StackTrace? stack, {
    String screen = '',
    String extra = '',
  }) async {
    final entry = CrashEntry(
      time: DateTime.now(),
      error: error?.toString() ?? 'unknown error',
      stackTrace: stack?.toString() ?? '',
      screen: screen,
      extra: extra,
    );
    _entries.insert(0, entry);
    if (_entries.length > 50) _entries = _entries.sublist(0, 50);

    try {
      final f = await _ensureFile();
      final out = _entries.map((e) => e.toJson()).toList();
      await f.writeAsString(jsonEncode(out), flush: true);
    } catch (e) {
      debugPrint('[CrashLogger] 落盘失败: $e');
    }
  }

  Future<void> clear() async {
    _entries = [];
    try {
      final f = await _ensureFile();
      await f.writeAsString(jsonEncode([]), flush: true);
    } catch (_) {}
  }
}
