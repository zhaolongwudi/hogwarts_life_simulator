/// 游戏数值平衡常量
///
/// 集中管理原先散落在 game_provider.dart / npc.dart 中的魔法数字，
/// 便于调参与回归测试。所有好感度、表白、好感锁等关键阈值统一在此维护。

/// 好感度与关系平衡
abstract final class Balance {
  // ===== 好感度范围 =====
  static const int affectionMin = -100;
  static const int affectionMax = 100;

  // ===== 好感沉淀（防速通） =====
  /// 第一周（第1周）单周好感增益上限
  static const int weekOneAffectionCap = 30;

  /// 第一个月好感增益上限（保留，后续月度结算可复用）
  static const int monthOneAffectionCap = 50;

  // ===== 好感锁阈值 =====
  /// 好感达到该值解锁「信任锁」（共享秘密）
  static const int trustLockThreshold = 50;

  /// 好感达到该值解锁「情感锁」（浪漫事件）
  static const int romanceLockThreshold = 70;

  // ===== NPC 主动表白（融合版） =====
  /// 触发表白所需最低好感
  static const int confessionMinAffection = 85;

  /// 表白所需最低浪漫事件次数
  static const int confessionMinRomanticEvents = 2;

  /// 表白所需暧昧持续最短天数（≥2周）
  static const int confessionCrushMatureDays = 14;

  /// 表白触发基础概率
  static const double confessionBaseProbability = 0.2;

  /// 每存在一位好感≥90的候选者，概率加成
  static const double confessionHighAffectionBonus = 0.1;

  /// 表白触发概率上限
  static const double confessionMaxProbability = 0.6;

  /// 触发概率加成时视为「高好感」的阈值
  static const int confessionHighAffectionThreshold = 90;

  // ===== 好感维系（防集邮式社交） =====
  /// 连续多少天没有任何好感互动后，关系开始自然转淡
  static const int affectionDriftIdleDays = 30;

  /// 转淡速率：每个游戏周衰减的下限/上限（在两者之间取随机）
  static const int affectionDriftPerWeekMin = 1;
  static const int affectionDriftPerWeekMax = 2;

  /// 转淡地板：淡到「好感」段下沿为止——不联系会变生分，
  /// 但不会淡回素不相识（affectionStages 中「好感」段 min = 10）
  static const int affectionDriftFloor = 10;

  /// AI 原始好感幅度 → 落地值的分段压缩。
  ///
  /// 旧实现一刀切压到 ±5：AI 写「救命之恩 +20」和「顺手帮忙 +8」，
  /// 落地都是 +5——大事件与日常好意在数值上完全无法区分，玩家对
  /// 重大事件的反馈感知被抹平（数值钝化）。
  ///
  /// 分段映射保留"这件事有多大"的层次，同时上限 10 依然防暴涨：
  ///   |raw| ≤ 5   → 原样（日常互动不被放大也不被缩小）
  ///   |raw| 6–10  → 5–7（中等事件：帮助、共同冒险）
  ///   |raw| 11–20 → 7–9（重大事件：救命、当众决裂）
  ///   |raw| > 20  → 10（人生级事件：牺牲、背叛至极）
  ///
  /// 传入负值返回负值（符号对称）。正值落地后仍会过周/月沉淀上限，
  /// 负值不过沉淀上限——伤害从来都是即时且全额的。
  static int compressAffectionDelta(int raw) {
    final d = raw.abs();
    final int mapped;
    if (d <= 5) {
      mapped = d;
    } else if (d <= 10) {
      mapped = 5 + ((d - 5) * 2 / 5).round();
    } else if (d <= 20) {
      mapped = 7 + ((d - 10) * 2 / 10).round();
    } else {
      mapped = 10;
    }
    return raw < 0 ? -mapped : mapped;
  }
}