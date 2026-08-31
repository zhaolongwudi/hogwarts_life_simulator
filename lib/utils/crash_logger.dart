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
}

class CrashLogger {
  static CrashLogger? _instance;
  static CrashLogger get instance => _instance ??= CrashLogger._();
  CrashLogger._();

  List<CrashEntry> _entries = [];
  List<CrashEntry> get entries => List.unmodifiable(_entries);

  /// 启动时缓存的应用文档目录（path_provider 只能异步取，崩溃 handler 里来不及）。
  String? _cachedDir;

  /// 最近一次心跳标记 + 时间（崩溃/ANR 后用于定位"卡死前在做什么"）。
  Map<String, String> get heartbeatSnapshot => _heartbeat;
  Map<String, String> _heartbeat = {};

  File? _logFile;
  Future<File> _ensureFile() async {
    if (_logFile != null) return _logFile!;
    final dir = await getApplicationDocumentsDirectory();
    _cachedDir = dir.path;
    _logFile = File('${dir.path}/crash_logs.json');
    if (!await _logFile!.exists()) {
      await _logFile!.writeAsString(jsonEncode([]));
    }
    return _logFile!;
  }

  /// 同步崩溃记录（崩溃 handler 专用）。
  ///
  /// 崩溃瞬间进程随时可能被系统杀掉——此前 record() 用异步写文件，
  /// 写完前进程一死，崩溃就"没有记录"了。这里用同步写 + flush:true，
  /// 崩溃 handler 里的同步写入一定落盘。
  void recordSync(
    dynamic error,
    StackTrace? stack, {
    String screen = '',
    String extra = '',
  }) {
    final entry = CrashEntry(
      time: DateTime.now(),
      error: error?.toString() ?? 'unknown error',
      stackTrace: stack?.toString() ?? '',
      screen: screen,
      extra: extra,
    );
    _entries.insert(0, entry);
    if (_entries.length > 50) _entries = _entries.sublist(0, 50);
    final dir = _cachedDir;
    if (dir == null) return;
    try {
      final f = File('$dir/crash_logs.json');
      f.writeAsStringSync(
        jsonEncode(_entries.map((e) => e.toJson()).toList()),
        flush: true,
      );
    } catch (e) {
      debugPrint('[CrashLogger] 同步落盘失败: $e');
    }
  }

  /// 心跳：记录"最近一次正在做什么"。
  ///
  /// ANR（主线程卡死，UI 冻结后系统杀进程）不会触发任何 onError，
  /// 异常记录永远接不到。靠心跳文件在下次启动时定位卡死前的最后一步。
  /// 只在回合边界调用（每回合 2~4 次），每次同步写一个小文件，开销可忽略。
  void logHeartbeat(String marker) {
    _heartbeat = {'time': DateTime.now().toIso8601String(), 'marker': marker};
    final dir = _cachedDir;
    if (dir == null) return;
    try {
      File('$dir/heartbeat.json')
          .writeAsStringSync(jsonEncode(_heartbeat), flush: true);
    } catch (_) {}
  }

  /// 启动时读取上次崩溃/卡死前的心跳（供设置页诊断展示）。
  void loadHeartbeat() {
    final dir = _cachedDir;
    if (dir == null) return;
    try {
      final f = File('$dir/heartbeat.json');
      if (f.existsSync()) {
        _heartbeat =
            Map<String, String>.from(jsonDecode(f.readAsStringSync()) as Map);
      }
    } catch (_) {}
  }

  Future<void> load() async {
    try {
      final f = await _ensureFile();
      final content = await f.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      _entries = list
          .map((e) => CrashEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      loadHeartbeat();
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
