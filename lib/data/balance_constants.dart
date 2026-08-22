/// 游戏数值平衡常量
///
/// 集中管理原先散落在 game_provider.dart / npc.dart 中的魔法数字，
/// 便于调参与回归测试。所有好感度、表白、好感锁等关键阈值统一在此维护。
library;

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
}