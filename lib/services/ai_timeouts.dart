import '../providers/app_provider.dart';

/// AI 服务层超时策略的**单一来源**（F48 收口）。
///
/// 路由层（[AiRouter] 的单次调用预算）与 Dio 层（[DeepSeekService] 的接收
/// 超时）以前各维护一对常量，靠注释约定「必须成对改」；改漏一边，路由层先
/// 掐断、Dio 的 receiveTimeout 日志就一次都不会出现，「网关慢」和「请求挂死」
/// 在日志上长得一模一样（第八次审查 P1-B）。
///
/// 现在两侧都从这里取值：
/// - 路由层先掐断：[perCallTimeoutFor]（默认 35s，sensenova 50s）
/// - Dio 只做兜底：[receiveTimeoutFor] = [perCallTimeoutFor] + [kDioTimeoutBuffer]
///
/// 结构性保证 Dio 永远晚于路由层超时，不再存在两处数字漂移的可能。

/// Dio 接收超时相对路由层单次调用预算的固定缓冲。
const Duration kDioTimeoutBuffer = Duration(seconds: 10);

/// 测试注入点：覆盖单次调用超时。生产路径恒为 null。
///
/// 注入时**必须保持与生产一致的相对关系**：服务端 delay > perCallTimeout、
/// 且 Dio 的 receiveTimeout > perCallTimeout。只想让测试跑得快而把超时调小，
/// 会把被测路径从「Dart timeout」悄悄换成「Dio timeout」——这两条路径在生产
/// 配置下行为完全相反（第七轮那 24 条行为测试正是这样集体放过了 P0）。
Duration? perCallTimeoutOverride;

/// 单次 Key 调用的超时上限，**按提供商区分**。
///
/// 必须比该提供商的 Dio receiveTimeout 短——否则 Dio 永远等不到自己超时，
/// 坏 Key 的判定全落在这一层，「网关慢」和「请求挂死」在日志上长得一样。
Duration perCallTimeoutFor(AiProvider provider) {
  final override = perCallTimeoutOverride;
  if (override != null) return override;
  return provider == AiProvider.sensenova
      ? const Duration(seconds: 50)
      : const Duration(seconds: 35);
}

/// 所有 provider 里最长的单次调用超时。全局超时按它取上界，
/// 保证算出来的预算对任何 provider 都成立。
Duration get maxPerCallTimeout {
  final override = perCallTimeoutOverride;
  if (override != null) return override;
  return const Duration(seconds: 50);
}

/// Dio 接收超时 = 路由层单次调用预算 + 固定缓冲。
///
/// 以前这里是独立的 45s/60s 常量；现在结构上就保证
/// `receiveTimeout > perCallTimeout` 恒成立。
Duration receiveTimeoutFor(AiProvider provider) =>
    perCallTimeoutFor(provider) + kDioTimeoutBuffer;
