import 'dart:async';
import 'dart:convert';

import '../utils/debug_log.dart';
import 'prefs_store.dart';

/// 限流 / 配额闸门的等待超时上限。
///
/// 必须**小于** AiRouter 的单次调用超时（最短 35 秒）：这段等待发生在
/// DeepSeekService.chatComplete 内部，而外层用 perCallTimeout 把整个调用包住了。
/// 以前默认 40 秒 > 35 秒，于是排队还没排到就被外层掐断，抛出的却是
/// 「单次 AI 请求超时」——实际卡在本地限流排队，排查方向被彻底带偏
/// （第八次审查 P2-1）。
const Duration kGateWaitTimeout = Duration(seconds: 30);

/// 本地限流/配额闸门的等待超时异常。
///
/// 与 AI 响应解析失败完全不同：这是「排队没排到」，不是「响应坏了」。
/// 单独成类型，让 DeepSeekService 的兜底 catch 能放行它——修复前闸门抛裸
/// `Exception`，被 chatComplete 的兜底重包成「AI 响应解析失败: ...」，
/// 玩家以为模型坏了，实际是本地排队超时（Q7）。
class AiGateTimeoutException implements Exception {
  final String message;
  AiGateTimeoutException(this.message);
  @override
  String toString() => message;
}

// 本文件的两个闸门此前完全没接进请求路径，等于裸奔：Agnes 免费版 20 RPM、
// SenseNova 每 5 小时有配额上限，超了服务方直接返 429。现在由
// DeepSeekService.chatComplete 在发请求前调用 waitForSlot / waitForQuota。
//
// 这里只保留「等待并占位」的入口。canRequest / currentRPM / recordRequest
// 这类「先查后记」的成对接口一并删除——waitForSlot 内部已经完成判断与记账，
// 留两套接口只会给调用方制造忘记记账的机会。

/// Agnes速率限制器（免费版限20 RPM）
/// 支持多 API Key：每个 Key 独立统计 RPM，互不影响。
///
/// 刻意**不做**持久化（对比 SenseNovaQuotaManager 的 Q1）：RPM 是 60 秒
/// 滑动窗口，App 重启最多丢 60 秒内的计数，服务商窗口几乎同步滑过；
/// 且 _keyHash 明确不落盘（见 DeepSeekService），持久化反而违背该约定。
class AgnesRateLimiter {
  /// 公开给测试与诊断：Agnes 免费版上限 20 RPM，这里留 2 个余量。
  static const int maxRPM = 18;

  /// keyHash → 请求时间记录列表
  final Map<String, List<DateTime>> _requestTimesByKey = {};

  AgnesRateLimiter._privateConstructor();
  static final AgnesRateLimiter instance = AgnesRateLimiter._privateConstructor();

  /// 获取指定 Key 的 RPM 记录列表
  List<DateTime> _timesForKey(String keyHash) {
    return _requestTimesByKey.putIfAbsent(keyHash, () => []);
  }

  /// 精确等待可用名额（替代固定 3 秒轮询）：
  /// 直接计算最早一条请求滑出 60 秒窗口的时刻并睡到那一刻。
  /// 超时抛异常，让上层 AiRouter 捕获并切换到备用提供商。
  /// 每个 API Key 独立统计，互不影响。
  Future<void> waitForSlot(String keyHash, {Duration timeout = kGateWaitTimeout}) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final now = DateTime.now();
      final times = _timesForKey(keyHash);
      times.removeWhere((t) => now.difference(t) > const Duration(minutes: 1));
      if (times.length < maxRPM) {
        times.add(DateTime.now());
        return;
      }
      if (now.isAfter(deadline)) {
        // 文案里写明是「本地限流」而不是「AI 请求超时」：抛出时还没切到任何
        // 备用 Key，写「已切换备用提供商」会让排查的人往网络方向找。
        // 用专用异常类型而不是裸 Exception：否则 DeepSeekService 的兜底
        // catch 会把它重包成「AI 响应解析失败」（Q7）。
        throw AiGateTimeoutException(
            'Agnes($keyHash) 本地限流等待超时（${timeout.inSeconds}秒），跳过该 Key');
      }
      // 最早一条请求在 oldest+60s 滑出窗口，精确睡到该时刻（+50ms 缓冲）
      // 但不能睡过 deadline——否则 timeout 形同虚设：窗口是 60 秒，
      // 一次 sleep 就要睡满 60 秒，上层永远等不到「超时切换提供商」。
      final waitMs = const Duration(minutes: 1).inMilliseconds -
          now.difference(times.first).inMilliseconds +
          50;
      final untilDeadline = deadline.difference(now).inMilliseconds;
      final sleepMs = waitMs.clamp(50, untilDeadline < 50 ? 50 : untilDeadline);
      await Future.delayed(Duration(milliseconds: sleepMs.toInt()));
    }
  }

  void reset() {
    _requestTimesByKey.clear();
  }
}

/// SenseNova配额管理器（按模型区分，每5小时重置）
///
/// 商汤平台不同模型配额不同（参考 https://platform.sensenova.cn/docs，2026-08）：
///   - sensenova-6.8-flash-lite / sensenova-u1-fast：本地软限 1500次/5h
///   - deepseek-v4-flash / glm-5.2：500次/5h（RPM 极低，约1.67次/分钟）
/// 配额按模型独立计量，一个模型用完不影响其他模型。
///
/// 2026-08-28 起商汤公测额度已从「按次」改为「积分制」（通用积分池 60,000 积分/滚动 5h）。
/// 本类仍沿用「次/5h」作为本地保守软阈值（积分随 token 数变化，无法用固定次数精确折算），
/// 真正的超限 429 仍以服务商积分窗口为准。
///
/// Q1：本地计数**持久化**。服务商的 5 小时配额窗口从玩家第一次调用起算，
/// 而本类此前把调用时间只存在内存里——App 重启后本地计数归零，玩家以为
/// 还有 1500 次额度，实际服务商窗口还在计，超了直接返 429。现在调用时间
/// 落盘 SharedPreferences，重启后恢复计数，本地窗口与服务商窗口不脱节。
class SenseNovaQuotaManager {
  static const Duration _windowDuration = Duration(hours: 5);

  /// SharedPreferences key 前缀：`ai_quota_sensenova_{model}` → JSON 时间戳数组。
  static const String _prefsPrefix = 'ai_quota_sensenova_';

  /// 模型 → 每5小时配额上限
  static int quotaForModel(String model) {
    if (model.startsWith('sensenova-')) return 1500;
    // deepseek-v4-flash / glm-5.2 等第三方托管模型
    return 500;
  }

  /// 模型 → 调用时间记录
  final Map<String, List<DateTime>> _callTimesByModel = {};

  /// 懒加载 Future：只加载一次，防并发请求重复走 platform channel。
  Future<void>? _loadFuture;

  SenseNovaQuotaManager._privateConstructor();
  static final SenseNovaQuotaManager instance = SenseNovaQuotaManager._privateConstructor();

  /// 从本地持久化恢复调用时间（Q1）。
  ///
  /// 每个模型的 key 独立存储，遍历 prefs 过滤前缀即可全部恢复；
  /// 超过 5 小时窗口的旧记录直接丢弃（服务商窗口同样已滑过）。
  /// prefs 不可用（测试环境 / 平台异常）时静默回退到空计数，不阻塞请求。
  Future<void> _ensureLoaded() {
    return _loadFuture ??= _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await PrefsStore.instance.init();
      final now = DateTime.now();
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(_prefsPrefix)) continue;
        final model = key.substring(_prefsPrefix.length);
        final raw = prefs.getString(key);
        if (raw == null) continue;
        final times = (jsonDecode(raw) as List)
            .map((e) => DateTime.tryParse(e as String))
            .whereType<DateTime>()
            .toList();
        // 窗口外旧记录：服务商那边也已滑出窗口，本地不该再占着计数
        times.removeWhere((t) => now.difference(t) > _windowDuration);
        if (times.isNotEmpty) {
          _callTimesByModel[model] = times;
        }
      }
    } catch (e) {
      // 恢复失败只影响「本地提前感知配额」，不影响请求本身
      debugLog('[SenseNovaQuotaManager] 配额持久化恢复失败: $e');
    }
  }

  /// 把该模型的调用时间写入持久化（Q1）。fire-and-forget：
  /// 写失败不阻塞限流热路径，PrefsStore.writeAsync 内部已 catch + 留痕。
  void _persist(String model, List<DateTime> times) {
    PrefsStore.instance.writeAsync('sensenova_quota_$model', (p) {
      final key = _prefsPrefix + model;
      if (times.isEmpty) {
        p.remove(key);
      } else {
        p.setString(
          key,
          jsonEncode(times.map((t) => t.toIso8601String()).toList()),
        );
      }
    });
  }

  /// 精确等待配额窗口：计算最早一条调用滑出 5 小时窗口的时刻并睡到那一刻。
  /// 超时抛异常，让上层 AiRouter 捕获并切换到备用提供商。
  Future<void> waitForQuota(String model, {Duration timeout = kGateWaitTimeout}) async {
    // Q1：先恢复持久化计数，再判断窗口——否则重启后第一次调用就清零重计
    await _ensureLoaded();
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final now = DateTime.now();
      final times = _callTimesByModel[model] ??= [];
      times.removeWhere((t) => now.difference(t) > _windowDuration);
      if (times.length < quotaForModel(model)) {
        times.add(DateTime.now());
        _persist(model, times);
        return;
      }
      if (now.isAfter(deadline)) {
        throw AiGateTimeoutException(
            'SenseNova($model) 本地配额等待超时（${timeout.inSeconds}秒），跳过该 Key');
      }
      final waitMs = _windowDuration.inMilliseconds -
          now.difference(times.first).inMilliseconds +
          50;
      // 同上：不能睡过 deadline，否则 5 小时的窗口会让 timeout 完全失效
      final untilDeadline = deadline.difference(now).inMilliseconds;
      final sleepMs = waitMs.clamp(50, untilDeadline < 50 ? 50 : untilDeadline);
      await Future.delayed(Duration(milliseconds: sleepMs.toInt()));
    }
  }

  /// 当前 5 小时窗口内该模型已用的调用次数（Q2 只读视角）。
  ///
  /// 只计算落在窗口内的记录，超窗口的旧记录不计入「已用」——
  /// 与服务商 5h 窗口语义一致（窗口滑出即重置）。先恢复持久化计数
  /// 再统计，避免重启后误报「剩余满配额」。
  Future<int> usedInWindow(String model) async {
    await _ensureLoaded();
    final times = _callTimesByModel[model] ?? const <DateTime>[];
    final now = DateTime.now();
    return times.where((t) => now.difference(t) <= _windowDuration).length;
  }

  /// 当前 5 小时窗口内该模型剩余可用次数（Q2 玩家沟通视角）。
  ///
  /// 下限 0：配额耗尽时不显示负数。UI 展示「剩余 X / 上限 Y」用。
  Future<int> remainingInWindow(String model) async {
    final used = await usedInWindow(model);
    final limit = quotaForModel(model);
    return (limit - used).clamp(0, limit);
  }

  /// 清空内存计数并重置加载缓存（测试/诊断用）。
  ///
  /// 不清理已落盘的持久化数据：测试隔离由 `SharedPreferences.setMockInitialValues`
  /// 负责（每次测试从干净存储开始）；生产代码不调用本方法。
  void reset() {
    _callTimesByModel.clear();
    _loadFuture = null;
  }
}

/// 响应缓存（减少重复调用）
class ResponseCache {
  final Map<String, _CachedResponse> _cache = {};
  static const Duration _maxAge = Duration(minutes: 5);
  static const int _maxEntries = 50;

  ResponseCache._privateConstructor();
  static final ResponseCache instance = ResponseCache._privateConstructor();

  /// 缓存键必须覆盖「生成者身份」，光有生成参数不够。
  ///
  /// 玩家在设置页把模型从 A 换成 B 之后，若键里没有 provider/model，
  /// 5 分钟 TTL 内同一 prompt 会直接命中 A 的输出——「换了模型，内容一个字
  /// 都没变」（第八次审查 P1-F）。
  String _makeKey(
    String prompt, {
    String? systemPrompt,
    double? temperature,
    int? maxTokens,
    String? provider,
    String? model,
  }) {
    // 用原文作为缓存键，避免 hashCode 碰撞导致不同请求错误命中
    final keyBuffer = StringBuffer();
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      keyBuffer.write(systemPrompt);
      keyBuffer.write('|||');
    }
    keyBuffer.write(prompt);
    // 将温度与最大 token 纳入缓存键，避免不同生成参数之间互相污染
    keyBuffer.write('|||t$temperature');
    keyBuffer.write('|||m$maxTokens');
    // 生成者身份：同一个 prompt 换 provider / model 不该命中旧输出
    keyBuffer.write('|||p$provider');
    keyBuffer.write('|||d$model');
    return keyBuffer.toString();
  }

  String? get(
    String prompt, {
    String? systemPrompt,
    double? temperature,
    int? maxTokens,
    String? provider,
    String? model,
  }) {
    final key = _makeKey(
      prompt,
      systemPrompt: systemPrompt,
      temperature: temperature,
      maxTokens: maxTokens,
      provider: provider,
      model: model,
    );
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.timestamp) < _maxAge) {
      // LRU：命中后移到末尾，让最近使用的条目不被优先淘汰
      _cache.remove(key);
      _cache[key] = cached;
      return cached.content;
    }
    if (cached != null) {
      _cache.remove(key);
    }
    return null;
  }

  void set(
    String prompt,
    String content, {
    String? systemPrompt,
    double? temperature,
    int? maxTokens,
    String? provider,
    String? model,
  }) {
    final key = _makeKey(
      prompt,
      systemPrompt: systemPrompt,
      temperature: temperature,
      maxTokens: maxTokens,
      provider: provider,
      model: model,
    );
    // 更新已有条目时先移除，保证新条目位于末尾（LRU 语义）
    _cache.remove(key);
    if (_cache.length >= _maxEntries) {
      _evictOldest();
    }
    _cache[key] = _CachedResponse(content, DateTime.now());
  }

  void _evictOldest() {
    // Dart Map 保持插入顺序，keys.first 即最久未使用的条目（LRU）
    final oldestKey = _cache.keys.first;
    _cache.remove(oldestKey);
  }

  void clear() {
    _cache.clear();
  }
}

class _CachedResponse {
  final String content;
  final DateTime timestamp;

  _CachedResponse(this.content, this.timestamp);
}
