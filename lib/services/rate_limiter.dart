import 'dart:async';

/// 限流 / 配额闸门的等待超时上限。
///
/// 必须**小于** AiRouter 的单次调用超时（最短 35 秒）：这段等待发生在
/// DeepSeekService.chatComplete 内部，而外层用 perCallTimeout 把整个调用包住了。
/// 以前默认 40 秒 > 35 秒，于是排队还没排到就被外层掐断，抛出的却是
/// 「单次 AI 请求超时」——实际卡在本地限流排队，排查方向被彻底带偏
/// （第八次审查 P2-1）。
const Duration kGateWaitTimeout = Duration(seconds: 30);

// 本文件的两个闸门此前完全没接进请求路径，等于裸奔：Agnes 免费版 20 RPM、
// SenseNova 每 5 小时有配额上限，超了服务方直接返 429。现在由
// DeepSeekService.chatComplete 在发请求前调用 waitForSlot / waitForQuota。
//
// 这里只保留「等待并占位」的入口。canRequest / currentRPM / recordRequest
// 这类「先查后记」的成对接口一并删除——waitForSlot 内部已经完成判断与记账，
// 留两套接口只会给调用方制造忘记记账的机会。

/// Agnes速率限制器（免费版限20 RPM）
/// 支持多 API Key：每个 Key 独立统计 RPM，互不影响。
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
        throw Exception(
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
///   - sensenova-6.8-flash-lite / sensenova-6.7-flash-lite / sensenova-u1-fast：1500次/5h
///   - deepseek-v4-flash / glm-5.2：500次/5h（RPM 极低，约1.67次/分钟）
/// 配额按模型独立计量，一个模型用完不影响其他模型。
class SenseNovaQuotaManager {
  static const Duration _windowDuration = Duration(hours: 5);

  /// 模型 → 每5小时配额上限
  static int quotaForModel(String model) {
    if (model.startsWith('sensenova-')) return 1500;
    // deepseek-v4-flash / glm-5.2 等第三方托管模型
    return 500;
  }

  /// 模型 → 调用时间记录
  final Map<String, List<DateTime>> _callTimesByModel = {};

  SenseNovaQuotaManager._privateConstructor();
  static final SenseNovaQuotaManager instance = SenseNovaQuotaManager._privateConstructor();

  /// 精确等待配额窗口：计算最早一条调用滑出 5 小时窗口的时刻并睡到那一刻。
  /// 超时抛异常，让上层 AiRouter 捕获并切换到备用提供商。
  Future<void> waitForQuota(String model, {Duration timeout = kGateWaitTimeout}) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final now = DateTime.now();
      final times = _callTimesByModel[model] ??= [];
      times.removeWhere((t) => now.difference(t) > _windowDuration);
      if (times.length < quotaForModel(model)) {
        times.add(DateTime.now());
        return;
      }
      if (now.isAfter(deadline)) {
        throw Exception(
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

  void reset() {
    _callTimesByModel.clear();
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
