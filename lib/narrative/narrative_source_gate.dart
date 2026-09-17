import 'package:flutter/foundation.dart';

/// 叙事来源枚举（P1 叙事来源抽象）。
enum NarrativeSource { ai, local }

/// 叙事来源自动降级开关（P1）。
///
/// 【要解决的问题】此前「本地兜底叙事」是散落在各混合件里的 `if 失败 →
/// generateFallbackNarrative()`，没有一个统一的"当前叙事来源"概念，也不存在
/// 自动切换：AI 连续掉线时每次都在空转重试后才落到本地，玩家只感到慢。
///
/// 【本对象做什么】把"当前该用 AI 还是本地"收敛成一次判定，并提供自动降级：
///   - 连续 [maxFailuresBeforeDegrade] 次 AI 叙事失败 → 自动切本地；
///   - 切本地后给 [localGraceTurns] 个回合的宽限期（期间不再打扰 AI），
///     宽限用完自动恢复尝试 AI（自动恢复），或下一次 AI 成功立即恢复。
///
/// 纯粹、可脱离 UI 单测；不持有任何游戏状态，上层负责喂数据。
class NarrativeSourceGate {
  NarrativeSourceGate({
    this.maxFailuresBeforeDegrade = 2,
    this.localGraceTurns = 3,
  });

  /// 连续 AI 失败多少次后自动降级到本地叙事。
  final int maxFailuresBeforeDegrade;

  /// 降级后本地兜底叙事保留几个回合（宽限期），到期自动恢复尝试 AI。
  final int localGraceTurns;

  int _failures = 0;
  int _graceLeft = 0;
  bool _autoDegraded = false;

  /// 是否处于自动降级状态（因连续失败切入，而非用户主动离线）。
  bool get isAutoDegraded => _autoDegraded;

  /// 距自动恢复还需几个本地回合；0 表示未降级或已到期。
  int get localTurnsRemaining => _graceLeft;

  /// 记录一次 AI 叙事成功：清零失败计数、撤销自动降级。
  void recordSuccess() {
    _failures = 0;
    _autoDegraded = false;
    _graceLeft = 0;
  }

  /// 记录一次 AI 叙事失败：连续达阈值即切入自动降级，并给足本地宽限期。
  void recordFailure() {
    _failures++;
    if (_failures >= maxFailuresBeforeDegrade) {
      _autoDegraded = true;
      _graceLeft = localGraceTurns;
    }
  }

  /// 实际走了一段本地叙事：消费一个宽限回合，用尽则自动恢复（.ai）。
  void onLocalTurn() {
    if (_graceLeft > 0) {
      _graceLeft--;
      if (_graceLeft <= 0) _autoDegraded = false;
    }
  }

  /// 当前生效的叙事来源：
  ///   - 用户主动离线 / 无可用 AI → 恒 local（尊重硬约束，也确保兜底走得通）；
  ///   - 否则看是否处于自动降级。
  NarrativeSource effective({
    required bool offlineQuickMode,
    required bool aiAvailable,
  }) {
    if (offlineQuickMode || !aiAvailable) return NarrativeSource.local;
    return _autoDegraded ? NarrativeSource.local : NarrativeSource.ai;
  }

  @visibleForTesting
  void resetForTest() {
    _failures = 0;
    _graceLeft = 0;
    _autoDegraded = false;
  }
}