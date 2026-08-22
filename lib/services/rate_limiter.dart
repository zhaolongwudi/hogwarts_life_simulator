import 'dart:async';

/// 智谱AI并发队列（免费版限1个并发）
class ZhipuConcurrencyQueue {
  final List<Completer<void>> _queue = [];
  bool _isProcessing = false;

  Future<T> execute<T>(Future<T> Function() task) async {
    final completer = Completer<void>();
    _queue.add(completer);

    if (_queue.length > 1) {
      await completer.future;
    }

    try {
      _isProcessing = true;
      return await task();
    } finally {
      _isProcessing = false;
      _queue.remove(completer);
      if (_queue.isNotEmpty) {
        _queue.first.complete();
      }
    }
  }

  int get queueLength => _queue.length;
  bool get isProcessing => _isProcessing;
}

/// Agnes速率限制器（免费版限20 RPM）
class AgnesRateLimiter {
  static const int _maxRPM = 18; // 留2个余量
  final List<DateTime> _requestTimes = [];

  AgnesRateLimiter._privateConstructor();
  static final AgnesRateLimiter instance = AgnesRateLimiter._privateConstructor();

  bool get canRequest {
    final now = DateTime.now();
    _requestTimes.removeWhere((t) => now.difference(t) > Duration(minutes: 1));
    return _requestTimes.length < _maxRPM;
  }

  int get currentRPM {
    final now = DateTime.now();
    _requestTimes.removeWhere((t) => now.difference(t) > Duration(minutes: 1));
    return _requestTimes.length;
  }

  void recordRequest() {
    _requestTimes.add(DateTime.now());
  }

  /// 精确等待可用名额（替代固定 3 秒轮询）：
  /// 直接计算最早一条请求滑出 60 秒窗口的时刻并睡到那一刻。
  /// 超时抛异常，让上层 AiRouter 捕获并切换到备用提供商。
  Future<void> waitForSlot({Duration timeout = const Duration(seconds: 40)}) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final now = DateTime.now();
      _requestTimes.removeWhere((t) => now.difference(t) > const Duration(minutes: 1));
      if (_requestTimes.length < _maxRPM) {
        _requestTimes.add(DateTime.now());
        return;
      }
      if (now.isAfter(deadline)) {
        throw Exception('Agnes 限流等待超时（${timeout.inSeconds}秒），已切换备用提供商');
      }
      // 最早一条请求在 oldest+60s 滑出窗口，精确睡到该时刻（+50ms 缓冲）
      final waitMs = const Duration(minutes: 1).inMilliseconds -
          now.difference(_requestTimes.first).inMilliseconds +
          50;
      await Future.delayed(Duration(milliseconds: waitMs.clamp(50, 61000).toInt()));
    }
  }

  void reset() {
    _requestTimes.clear();
  }
}

/// SenseNova配额管理器（每5小时1500次）
class SenseNovaQuotaManager {
  static const int _maxCallsPerWindow = 1500;
  static const Duration _windowDuration = Duration(hours: 5);

  final List<DateTime> _callTimes = [];

  SenseNovaQuotaManager._privateConstructor();
  static final SenseNovaQuotaManager instance = SenseNovaQuotaManager._privateConstructor();

  bool get canMakeCall {
    final now = DateTime.now();
    _callTimes.removeWhere((t) => now.difference(t) > _windowDuration);
    return _callTimes.length < _maxCallsPerWindow;
  }

  int get remainingQuota {
    final now = DateTime.now();
    _callTimes.removeWhere((t) => now.difference(t) > _windowDuration);
    return _maxCallsPerWindow - _callTimes.length;
  }

  void recordCall() {
    _callTimes.add(DateTime.now());
  }

  /// 精确等待配额窗口：计算最早一条调用滑出 5 小时窗口的时刻并睡到那一刻。
  /// 超时抛异常，让上层 AiRouter 捕获并切换到备用提供商。
  Future<void> waitForQuota({Duration timeout = const Duration(seconds: 40)}) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final now = DateTime.now();
      _callTimes.removeWhere((t) => now.difference(t) > _windowDuration);
      if (_callTimes.length < _maxCallsPerWindow) {
        _callTimes.add(DateTime.now());
        return;
      }
      if (now.isAfter(deadline)) {
        throw Exception('SenseNova 配额等待超时（${timeout.inSeconds}秒），已切换备用提供商');
      }
      final waitMs = _windowDuration.inMilliseconds -
          now.difference(_callTimes.first).inMilliseconds +
          50;
      await Future.delayed(Duration(milliseconds: waitMs.clamp(50, 61000).toInt()));
    }
  }

  void reset() {
    _callTimes.clear();
  }
}

/// 响应缓存（减少重复调用）
class ResponseCache {
  final Map<String, _CachedResponse> _cache = {};
  static const Duration _maxAge = Duration(minutes: 5);
  static const int _maxEntries = 50;

  ResponseCache._privateConstructor();
  static final ResponseCache instance = ResponseCache._privateConstructor();

  String _makeKey(String prompt, {String? systemPrompt, double? temperature, int? maxTokens}) {
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
    return keyBuffer.toString();
  }

  String? get(String prompt, {String? systemPrompt, double? temperature, int? maxTokens}) {
    final key = _makeKey(prompt, systemPrompt: systemPrompt, temperature: temperature, maxTokens: maxTokens);
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.timestamp) < _maxAge) {
      return cached.content;
    }
    if (cached != null) {
      _cache.remove(key);
    }
    return null;
  }

  void set(String prompt, String content, {String? systemPrompt, double? temperature, int? maxTokens}) {
    final key = _makeKey(prompt, systemPrompt: systemPrompt, temperature: temperature, maxTokens: maxTokens);
    if (_cache.length >= _maxEntries) {
      _evictOldest();
    }
    _cache[key] = _CachedResponse(content, DateTime.now());
  }

  void _evictOldest() {
    final oldestKey = _cache.keys.first;
    _cache.remove(oldestKey);
  }

  int get cacheSize => _cache.length;

  void clear() {
    _cache.clear();
  }
}

class _CachedResponse {
  final String content;
  final DateTime timestamp;

  _CachedResponse(this.content, this.timestamp);
}
