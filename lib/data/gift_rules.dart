import '../models/game_systems.dart';

/// 送礼判定。
///
/// 这套数据此前是完整的死链：npc_data 里 56 位 NPC 的 giftPrefs 全空，
/// mixin_init / mixin_relations 按人格原型补了一份并存进存档，
/// 但没有任何代码读过它——「送礼」只是被动好感推断里的一个关键词
/// （+1~+2），和送的是什么完全无关。affectionChangeRules 里那三条
/// 「赠送礼物（一般/喜欢/挚爱）」也一次都没被引用过。
///
/// 判定阈值按原型表的实际分值分布定：
/// 挚爱档 8 分（魁地奇徽章、旧书、编织围巾、神秘符号、朋克饰品），
/// 喜欢档 4~7 分，一般档 1~3 分（巧克力蛙）。
enum GiftReaction { beloved, liked, neutral, unknown }

class GiftVerdict {
  final GiftReaction reaction;
  final int score;

  /// 好感变化区间，与 affectionChangeRules 中「赠送礼物(...)」三条保持一致
  final int minGain;
  final int maxGain;

  const GiftVerdict({
    required this.reaction,
    required this.score,
    required this.minGain,
    required this.maxGain,
  });

  /// 对应设定 11.2 里的规则名，用于日志与存档的 reason 字段。
  String get ruleName {
    switch (reaction) {
      case GiftReaction.beloved:
        return '赠送礼物（挚爱）';
      case GiftReaction.liked:
        return '赠送礼物（喜欢）';
      case GiftReaction.neutral:
        return '赠送礼物（一般）';
      case GiftReaction.unknown:
        return '赠送礼物（无感）';
    }
  }
}

/// 按偏好表给一件礼物定档。
///
/// [prefs] 为空（NPC 没生成过偏好）时一律 unknown——宁可给最低档，
/// 也不要用「平均喜好」糊弄过去，那会让送礼重新退化成随机数。
GiftVerdict evaluateGift(Map<String, int> prefs, String itemName) {
  final score = prefs[itemName] ?? 0;
  if (score >= 8) {
    return GiftVerdict(reaction: GiftReaction.beloved, score: score, minGain: 10, maxGain: 15);
  }
  if (score >= 4) {
    return GiftVerdict(reaction: GiftReaction.liked, score: score, minGain: 5, maxGain: 8);
  }
  if (score > 0) {
    return GiftVerdict(reaction: GiftReaction.neutral, score: score, minGain: 1, maxGain: 3);
  }
  // 送偏了不掉好感：玩家花钱花物品去试探偏好，为探索本身扣分太苛刻
  return GiftVerdict(reaction: GiftReaction.unknown, score: 0, minGain: 0, maxGain: 1);
}

/// 这位 NPC 最想要的三件礼物，按分值降序。用于 /送礼 不带名字时的提示。
List<String> topWishes(Map<String, int> prefs, {int limit = 3}) {
  final entries = prefs.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries.take(limit).map((e) => e.key).toList(growable: false);
}

/// 送礼判定用的数值必须与设定 11.2 的表一致。
///
/// affectionChangeRules 会被写进给 AI 的提示词，如果这里改了幅度却忘了
/// 同步设定表，AI 叙事里的好感表现就会和实际数值对不上。
List<String> giftRuleMismatches() {
  final problems = <String>[];
  final byName = {for (final r in affectionChangeRules) r.type: r};

  void check(String ruleName, int min, int max) {
    final r = byName[ruleName];
    if (r == null) {
      problems.add('设定表里没有「$ruleName」');
      return;
    }
    if (r.min != min || r.max != max) {
      problems.add('$ruleName：判定用 $min~$max，设定表写的是 ${r.min}~${r.max}');
    }
  }

  check('赠送礼物（挚爱）', 10, 15);
  check('赠送礼物（喜欢）', 5, 8);
  check('赠送礼物（一般）', 1, 3);
  return problems;
}
