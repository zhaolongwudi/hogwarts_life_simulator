/// P11 羁绊小剧场：一场跨多回合的 NPC 专属个人支线。
///
/// 与奇遇的区别：奇遇是**「你」个人**随机碰到的一件小事（两段式、即时）；
/// 羁绊小剧场是**你与某个 NPC 之间**一场有起承转合的小戏——因为它由
/// 「好感」推动，所以只在你的好感跨过该 NPC 的门槛后才被解锁，并用好几
/// 个回合一点点演完：前段推进（自动演）、中段升温、最终幕留一次抉择。
///
/// 进度存在 [`WorldState.companionArcs`]，按 npcId 记一份 [`CompanionArcProgress`]，
/// 序列化持久化，中途退出仍能接着演。一场弧只能走到一次，演完 `completed` 后
/// 不会再触发（守稳每场一次的体验，也让玩家有"集齐"的理由）。
library;

/// 一场羁绊小剧场的进行状态（按 npcId 各存一份）。
class CompanionArcProgress {
  /// 当前/已完成的小剧场 id；null = 该 NPC 从未有在演或演完的弧。
  final String? arcId;

  /// 下一幕要播的节拍下标（0-based）。
  final int beatIndex;

  /// 是否处于「最终幕已播、正等你做抉择」的状态。为 true 时本弧暂时停住，
  /// 下回合由玩家选结局；选完即 `completed`。
  final bool pendingClimax;

  /// 是否已演完（不会再触发）。
  final bool completed;

  const CompanionArcProgress({
    this.arcId,
    this.beatIndex = 0,
    this.pendingClimax = false,
    this.completed = false,
  });

  CompanionArcProgress copyWith({
    String? arcId,
    int? beatIndex,
    bool? pendingClimax,
    bool? completed,
  }) {
    return CompanionArcProgress(
      arcId: arcId ?? this.arcId,
      beatIndex: beatIndex ?? this.beatIndex,
      pendingClimax: pendingClimax ?? this.pendingClimax,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toJson() => {
    'a': arcId,
    'bi': beatIndex,
    'pc': pendingClimax,
    'd': completed,
  };

  factory CompanionArcProgress.fromJson(dynamic src) {
    if (src == null) return const CompanionArcProgress();
    if (src is Map) {
      return CompanionArcProgress(
        arcId: (src['a'] as String?) ?? (src['arcId'] as String?),
        beatIndex: (src['bi'] as int?) ?? 0,
        pendingClimax: (src['pc'] as bool?) ?? false,
        completed: (src['d'] as bool?) ?? false,
      );
    }
    return const CompanionArcProgress();
  }
}