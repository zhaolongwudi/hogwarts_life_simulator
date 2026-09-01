/// 游戏数值平衡常量
///
/// 集中管理原先散落在 game_provider.dart / npc.dart 中的魔法数字，
/// 便于调参与回归测试。所有好感度、表白、好感锁等关键阈值统一在此维护。
import '../models/game_systems.dart';

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

  /// 写进 prompt 的「事件类好感落地区间」——AI 原始输出经
  /// [compressAffectionDelta] 平衡校准后的实际落地值。
  ///
  /// P0-2 根治：prompt 原来教 AI「救命 +10~+20、背叛 -15~-30」，落地却只有
  /// +7~+9 / -8~-10，割裂导致「AI 写 25 只涨 10」的体验落差。
  /// prompt 侧直接引用本函数生成的落地区间，改压缩函数时提示词自动跟随。
  static String affectionLandingFor(String ruleType) {
    final rule = affectionChangeRules.firstWhere((e) => e.type == ruleType);
    final min = compressAffectionDelta(rule.min);
    final max = compressAffectionDelta(rule.max);
    return '$min~$max';
  }

  // ===== 社交成本：连续互动递减 =====

  /// 对同一 NPC 连续互动超过此回合数后，好感收益开始递减
  static const int consecutiveInteractionThreshold = 3;

  /// 连续互动超过阈值后的每回合衰减比例（0.0~1.0）
  /// 第 4 回合好感收益 ×[1 - 0.3]，第 5 回合 ×[1 - 0.5]，第 6 回合 ×[1 - 0.7]
  static double consecutiveInteractionDecay(int consecutiveTurns) {
    if (consecutiveTurns <= consecutiveInteractionThreshold) return 1.0;
    final excess = consecutiveTurns - consecutiveInteractionThreshold;
    return (1.0 - excess * 0.2).clamp(0.3, 1.0);
  }

  /// 重大事件后免疫衰减的天数
  static const int majorEventImmunityDays = 7;

  // ===== 属性成长曲线参数 =====

  /// 属性成长期望值速查（7 学年结束时，正常玩家各属性的期望值区间）
  /// 用于校准毕业条件、技能解锁门槛、事件触发条件。
  /// 取值假设：每周上课 2 次 + 每月 1 次主动练习 + 年均 1 次事件增长。
  static const Map<String, Map<String, int>> growthExpectation = {
    // key: 属性名, value: {min: 最小值, max: 最大值, graduate: 毕业门槛建议}
    'dda': {'min': 50, 'max': 80, 'graduate': 65},
    'potions': {'min': 45, 'max': 75, 'graduate': 60},
    'herbology': {'min': 40, 'max': 70, 'graduate': 55},
    'transfiguration': {'min': 40, 'max': 70, 'graduate': 55},
    'charms': {'min': 45, 'max': 75, 'graduate': 60},
    'flying': {'min': 35, 'max': 65, 'graduate': 50},
    'theory': {'min': 40, 'max': 70, 'graduate': 55},
    'spell_understanding': {'min': 40, 'max': 70, 'graduate': 55},
    'observation': {'min': 35, 'max': 65, 'graduate': 50},
    'social': {'min': 40, 'max': 70, 'graduate': 55},
  };

  /// 每学年属性自然增长量（上课 + 事件 + 练习的综合期望）
  static const int attrGrowthPerYear = 8;

  /// 单次上课/练习/事件对属性的增益区间
  static const int attrGainMin = 0;
  static const int attrGainMax = 2;
  static const int attrGainEventMin = 1;
  static const int attrGainEventMax = 3;

  // ===== 学院分来源平衡 =====

  /// 各活动的学院分贡献系数
  static const Map<String, int> houseCupActivityPoints = {
    'quidditch_win': 30,      // 魁地奇胜场
    'duel_win': 5,            // 决斗胜场
    'classroom': 3,           // 课堂表现优异
    'forbidden_forest': 8,    // 禁林探险成功
    'quest_complete': 5,      // 委托完成
    'exam_top': 15,           // 年级前十
  };
}