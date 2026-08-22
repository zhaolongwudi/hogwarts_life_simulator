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

  Future<void> waitForSlot() async {
    int attempts = 0;
    while (!canRequest && attempts < 60) {
      await Future.delayed(const Duration(seconds: 3));
      attempts++;
    }
    if (canRequest) {
      recordRequest();
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

  Future<void> waitForQuota() async {
    int attempts = 0;
    while (!canMakeCall && attempts < 30) {
      final now = DateTime.now();
      final oldestCall = _callTimes.first;
      final waitTime = _windowDuration.inSeconds - now.difference(oldestCall).inSeconds;
      if (waitTime > 0 && waitTime < 300) {
        await Future.delayed(Duration(seconds: waitTime));
      } else {
        await Future.delayed(const Duration(minutes: 1));
      }
      attempts++;
    }
    if (canMakeCall) {
      recordCall();
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
