import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'debug_log.dart';
import 'log_paths.dart';

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
    _logDir = '${dir.path}/$kAiDebugLogDirName';
    final logDir = Directory(_logDir!);
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
  }

  /// 测试注入点：把日志根目录指向临时目录，避免污染真实文档目录。
  /// 生产路径不要调用——正常 flow 由 [_ensureLogDir] 用真实目录初始化。
  @visibleForTesting
  Future<void> forceLogDirForTest(String absPath) async {
    _logDir = absPath;
    final dir = Directory(_logDir!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _enabled = true;
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
        // Q15：完整 systemPrompt 含玩家档案/关系/魔法能力等隐私，绝不整段落盘。
        // 不写任何 systemPrompt 内容——即使只取"首行"，真机上常是单行 JSON，
        // 整份档案仍会裸奔（实测发现单行 systemPrompt 首行=全部）。只记长度，
        // 保留"本次用了多少约束上下文"的排查线索，隐私彻底脱敏。
        buf.writeln('【System Prompt】(隐私脱敏：不落内容，仅记录规模)');
        buf.writeln('---');
        buf.writeln('共 ${systemPrompt.length} 字符，完整内容已脱敏');
        buf.writeln('---');
      }
      _pendingCalls[callId] = buf;
      return callId;
    } catch (e) {
      debugLog('AiDebugLogger logStart 失败: $e');
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
      if (promptTokens != null ||
          completionTokens != null ||
          totalTokens != null) {
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
      debugLog('AiDebugLogger logComplete 失败: $e');
    }
  }

  static const int _maxFileBytes = 4 * 1024 * 1024; // 单份日志文件上限 4MB，防止无限膨胀

  Future<void> _writeToFile(String content) async {
    if (_logDir == null) return;
    final now = DateTime.now();
    final base = '${now.year}${_pad(now.month)}${_pad(now.day)}';

    await _appendToShard(base, content);
    await _pruneOldLogs();
  }

  /// 把一条日志追加到「当日日志族」里第一份未超上限的分片。
  ///
  /// 旧实现（run 前的 Q15）：当日文件超 4MB 时直接 `writeAsString(content)`
  /// 整体覆写，上一条并发写盘（同一文件多分片写）或当日更早的全部历史都会被
  /// 清空，只剩最后一小段——丢日志不可接受。改为分片追加：主片满了就开下一个
  /// `ai_log_YYYYMMDD_N.txt`（N 从 1 递增），历史永远保留，只是按容量分隔。
  Future<void> _appendToShard(String base, String content) async {
    try {
      for (var shard = 0; shard < 32; shard++) {
        final fileName = shard == 0
            ? 'ai_log_$base.txt'
            : 'ai_log_${base}_$shard.txt';
        final file = File('${_logDir!}/$fileName');
        if (await file.exists() && await file.length() > _maxFileBytes) {
          continue; // 该分片已满，找下一个
        }
        await file.writeAsString(content, mode: FileMode.append, flush: true);
        return;
      }
      // 32 片（合计约 128MB）都满：极不可能，兜底丢弃本条并仅登记计数，
      // 避免日志写入拖垮正常游戏流程（日志本来就该失败静默）。
      debugLog('AiDebugLogger 当日日志已达 ${32 * _maxFileBytes ~/ (1024 * 1024)}MB 上限，丢弃本条');
    } catch (e) {
      debugLog('AiDebugLogger 写入失败: $e');
    }
  }

  /// 只保留最近 7 个「日志日期族」的调试日志（清理更早的），防止目录无限增长。
  ///
  /// 按文件名的 `YYYYMMDD` 前缀聚类：同一天的主片与分片（`ai_log_20260910.txt`/
  /// `ai_log_20260910_1.txt`）算一个日期族，一起保留或一起删。
  /// 不是按文件数保留——否则一天分片越多，能保留的天数就越少。
  Future<void> _pruneOldLogs() async {
    if (_logDir == null) return;
    try {
      final dir = Directory(_logDir!);
      if (!await dir.exists()) return;
      final files = (await dir.list().toList()).whereType<File>().toList();
      if (files.isEmpty) return;
      final RegExp dayRe = RegExp(r'^ai_log_(\d{8})');
      final Map<String, List<File>> byDay = {};
      for (final f in files) {
        final m = dayRe.firstMatch(f.path.split('/').last);
        final day = m?.group(1) ?? 'other';
        (byDay[day] ??= []).add(f);
      }
      if (byDay.length <= 7) return;
      final days = byDay.keys.toList();
      // 纯数字日期可字典序比较（YYYYMMDD → 较新的排后面），非日期键垫底
      days.sort((a, b) {
        if (a == 'other' || b == 'other') return a == 'other' ? -1 : 1;
        return a.compareTo(b);
      });
      final toDelete = days
          .take(days.length - 7)
          .map((d) => byDay[d] ?? const <File>[])
          .expand((files) => files);
      for (final p in toDelete) {
        try {
          await p.delete();
        } catch (e) {
          debugLog('❌ 清理旧调试日志失败: ${p.path} $e');
        }
      }
    } catch (e) {
      debugLog('❌ 调试日志目录清理失败: $e');
    }
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
      debugLog('读取日志失败 $path: $e');
      return '读取失败: $e';
    }
  }

  Future<void> clearAllLogs() async {
    final files = await getLogFiles();
    for (final p in files) {
      try {
        await File(p).delete();
      } catch (e) {
        debugLog('删除日志失败: $p $e');
      }
    }
    _pendingCalls.clear();
  }

  /// 测试复位：清空挂起调用并丢弃已设置的日志目录引用。
  /// 不删文件（文件清理由测试自行 delete 临时目录），只解除测试间共享
  /// 的 `_logDir`/`_enabled` 状态，避免上一用例的目录串到下一用例。
  @visibleForTesting
  void resetForTest() {
    _pendingCalls.clear();
    _logDir = null;
    _enabled = false;
  }
}
