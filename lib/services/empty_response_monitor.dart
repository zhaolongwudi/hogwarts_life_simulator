/// 空响应监控器（Q9）。
///
/// 空响应与超时/网络错误性质不同：后者多半是 Key 或网络问题，前者是模型
/// 偶发输出质量问题——修 Key 修网络都没用，换模型才有意义。
///
/// 本监控按「提供商 + 模型」跟踪**连续**空响应：一次成功响应即清零连续计数。
/// 连续达到 [degradeThreshold] 判定该模型「不稳定」，DeepSeekService 改抛
/// [AiEmptyResponseException]（见 deepseek_service.dart），路由层据此跳过该
/// 提供商全部 Key、降级到备用提供商，并提示玩家更换稳定模型。
///
/// 与限流闸门（AgnesRateLimiter / SenseNovaQuotaManager）一样以单例形式
/// 挂在请求路径上，测试可直接 reset 后注入行为。
class EmptyResponseMonitor {
  /// 连续空响应达到该次数即判定模型不稳定。公开给测试与诊断：
  /// 用例不该自己抄一份「3」，否则调参时测试假红。
  static const int degradeThreshold = 3;

  /// 提供商/模型 → 连续空响应次数
  final Map<String, int> _consecutiveEmpty = {};

  /// 提供商/模型 → 累计空响应次数（诊断用）
  final Map<String, int> _totalEmpty = {};

  EmptyResponseMonitor._privateConstructor();
  static final EmptyResponseMonitor instance =
      EmptyResponseMonitor._privateConstructor();

  String _key(String provider, String model) => '$provider/$model';

  /// 记录一次空响应。返回「本次记录后是否达到降级阈值」——
  /// 即本次空响应恰好把该模型推入不稳定状态。
  bool recordEmpty(String provider, String model) {
    final k = _key(provider, model);
    final n = (_consecutiveEmpty[k] ?? 0) + 1;
    _consecutiveEmpty[k] = n;
    _totalEmpty[k] = (_totalEmpty[k] ?? 0) + 1;
    return n >= degradeThreshold;
  }

  /// 记录一次成功响应：连续计数清零，模型恢复稳定。
  void recordSuccess(String provider, String model) {
    _consecutiveEmpty[_key(provider, model)] = 0;
  }

  /// 该模型当前是否处于「不稳定（应降级）」状态。
  bool isDegraded(String provider, String model) =>
      (_consecutiveEmpty[_key(provider, model)] ?? 0) >= degradeThreshold;

  /// 连续空响应次数（诊断/UI 用）。
  int consecutiveEmptyCount(String provider, String model) =>
      _consecutiveEmpty[_key(provider, model)] ?? 0;

  /// 累计空响应次数（诊断/UI 用）。
  int totalEmptyCount(String provider, String model) =>
      _totalEmpty[_key(provider, model)] ?? 0;

  void reset() {
    _consecutiveEmpty.clear();
    _totalEmpty.clear();
  }
}
