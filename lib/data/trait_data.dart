/// 开局特质系统（出身特质抽取）
///
/// 参考《人生重开模拟器》的天赋抽取设计：
/// - 稀有度分级（普通/稀有/传说），软保底机制
/// - 特质影响属性加成与事件触发倾向
/// - 开局随机抽取 3 个，提升多周目动力

class TraitDef {
  final String id;
  final String name;
  final String description;

  /// 稀有度：common / rare / legendary
  final String rarity;

  /// 属性加成：属性 key -> 加成值（可为负）
  final Map<String, int> attributeBonus;

  /// 注入给叙事 AI 的特质提示（简短）
  final String narrativeHint;

  const TraitDef({
    required this.id,
    required this.name,
    required this.description,
    this.rarity = 'common',
    this.attributeBonus = const {},
    this.narrativeHint = '',
  });
}

const List<TraitDef> traitCatalog = [
  // ==================== 普通特质 ====================
  TraitDef(
    id: 'early_riser',
    name: '早起鸟',
    description: '你习惯早起，清晨的霍格沃茨属于你。',
    attributeBonus: {'energy': 5},
    narrativeHint: '精力略好，清晨时段行动更从容。',
  ),
  TraitDef(
    id: 'bookish',
    name: '书卷气',
    description: '你从小就爱泡在书堆里。',
    attributeBonus: {'theory': 8, 'memory': 5},
    narrativeHint: '理论学习上手更快，图书馆剧情更多。',
  ),
  TraitDef(
    id: 'green_thumb',
    name: '绿手指',
    description: '植物在你手里总能长得很好。',
    attributeBonus: {'herbology': 10},
    narrativeHint: '草药学有天赋，温室剧情更多。',
  ),
  TraitDef(
    id: 'steady_hand',
    name: '稳手',
    description: '你的手很稳，切药材从不失手。',
    attributeBonus: {'potions': 8},
    narrativeHint: '魔药学有天赋，地窖课堂更受教授注意。',
  ),
  TraitDef(
    id: 'quick_feet',
    name: '快脚',
    description: '你跑得快，反应也灵敏。',
    attributeBonus: {'flying': 8, 'reaction_time': 5},
    narrativeHint: '飞行与运动有优势，魁地奇选拔更易入选。',
  ),
  TraitDef(
    id: 'charming_smile',
    name: '讨喜的笑容',
    description: '人们天然对你有好感。',
    attributeBonus: {'social': 8},
    narrativeHint: '初次见面印象更好，社交剧情更顺。',
  ),
  TraitDef(
    id: 'thrifty',
    name: '节俭',
    description: '你懂得精打细算。',
    attributeBonus: {},
    narrativeHint: '初始加隆略多，购物时偶尔有折扣剧情。',
  ),
  TraitDef(
    id: 'night_owl',
    name: '夜猫子',
    description: '深夜的你格外清醒。',
    attributeBonus: {'observation': 5},
    narrativeHint: '深夜行动更有优势，但也更容易违反宵禁。',
  ),
  TraitDef(
    id: 'brave_heart',
    name: '胆大',
    description: '别人害怕的事，你敢试试。',
    attributeBonus: {'courage': 8, 'caution': -5},
    narrativeHint: '勇气更高但更莽撞，冒险剧情更多。',
  ),
  TraitDef(
    id: 'careful_mind',
    name: '谨慎',
    description: '你三思而后行。',
    attributeBonus: {'caution': 8, 'courage': -3},
    narrativeHint: '更少陷入危险，但可能错过机会。',
  ),
  TraitDef(
    id: 'animal_friend',
    name: '动物亲和',
    description: '神奇生物对你不那么戒备。',
    attributeBonus: {'observation': 5},
    narrativeHint: '神奇生物相关剧情更多，海格对你印象好。',
  ),
  TraitDef(
    id: 'good_appetite',
    name: '好胃口',
    description: '你从不浪费霍格沃茨的食物。',
    attributeBonus: {'health': 5},
    narrativeHint: '饱食度下降更慢，宴会剧情更享受。',
  ),

  // ==================== 稀有特质 ====================
  TraitDef(
    id: 'prodigy_spells',
    name: '咒语奇才',
    description: '你学咒语的速度令人惊讶。',
    rarity: 'rare',
    attributeBonus: {'spell_understanding': 12, 'magic_control': 8},
    narrativeHint: '施法成功率更高，更早学会进阶魔咒。',
  ),
  TraitDef(
    id: 'natural_flyer',
    name: '天生找球手',
    description: '扫帚像是你身体的延伸。',
    rarity: 'rare',
    attributeBonus: {'flying': 15, 'reaction_time': 8},
    narrativeHint: '魁地奇试训极易入选，球场是你的主场。',
  ),
  TraitDef(
    id: 'potion_intuition',
    name: '魔药直觉',
    description: '你能凭直觉判断坩埚里的变化。',
    rarity: 'rare',
    attributeBonus: {'potions': 15, 'intuition': 8},
    narrativeHint: '魔药课表现突出，斯内普类教授会注意到你。',
  ),
  TraitDef(
    id: 'silver_tongue',
    name: '巧舌',
    description: '你总能说出别人想听的话。',
    rarity: 'rare',
    attributeBonus: {'social': 12, 'logic': 5},
    narrativeHint: '说服与谈判更容易成功，但也更容易被识破。',
  ),
  TraitDef(
    id: 'iron_will',
    name: '钢铁意志',
    description: '压力与恐惧很难动摇你。',
    rarity: 'rare',
    attributeBonus: {'willpower': 12, 'emotional_stability': 8},
    narrativeHint: '面对黑魔法与恐惧时更镇定，心理状态更稳。',
  ),
  TraitDef(
    id: 'keen_eye',
    name: '锐眼',
    description: '你能注意到别人忽略的细节。',
    rarity: 'rare',
    attributeBonus: {'observation': 12, 'logic': 8},
    narrativeHint: '更容易发现隐藏线索与秘密。',
  ),
  TraitDef(
    id: 'old_family',
    name: '古老家族',
    description: '你的姓氏在魔法界有些分量。',
    rarity: 'rare',
    attributeBonus: {'social': 5},
    narrativeHint: '部分纯血家族对你另眼相看，但也背负家族期待。',
  ),
  TraitDef(
    id: 'lucky_coin',
    name: '幸运硬币',
    description: '你有一枚总带来好运的硬币。',
    rarity: 'rare',
    attributeBonus: {'intuition': 8},
    narrativeHint: '关键时刻偶尔有好运眷顾。',
  ),

  // ==================== 传说特质 ====================
  TraitDef(
    id: 'metamorph',
    name: '易容天赋',
    description: '你能轻微改变自己的外貌——极其罕见的天赋。',
    rarity: 'legendary',
    attributeBonus: {'transfiguration': 15, 'creativity': 10},
    narrativeHint: '变形术天赋异禀，易容能力可在剧情中使用，但需隐藏以免被研究。',
  ),
  TraitDef(
    id: 'parsel_hint',
    name: '蛇语低喃',
    description: '你偶尔能听懂蛇的嘶鸣——这天赋既是礼物也是诅咒。',
    rarity: 'legendary',
    attributeBonus: {'intuition': 10, 'social': -10},
    narrativeHint: '蛇佬腔天赋：可解锁独特剧情，但一旦暴露将引发巨大舆论与恐惧。',
  ),
  TraitDef(
    id: 'seer_dreams',
    name: '先知的梦',
    description: '你的梦偶尔会成真——模糊、滞后，但真实。',
    rarity: 'legendary',
    attributeBonus: {'intuition': 15, 'logic': -5},
    narrativeHint: '偶尔获得模糊的预知梦，可提前感知危险，但预言不可靠且难以取信于人。',
  ),
  TraitDef(
    id: 'phoenix_bond',
    name: '凤凰之缘',
    description: '某只凤凰似乎对你格外亲近——原因不明。',
    rarity: 'legendary',
    attributeBonus: {'moral': 10, 'spirit': 10},
    narrativeHint: '与凤凰有特殊羁绊，关键时刻可能获得帮助，但凤凰不会无条件服从。',
  ),
];

/// 稀有度权重（软保底：连续未出稀有/传说时概率递增）
class TraitRarityWeights {
  static const double commonBase = 0.70;
  static const double rareBase = 0.25;
  static const double legendaryBase = 0.05;

  /// 软保底：每连续 N 次未出该稀有度，概率提升
  static const int pityThreshold = 3;
  static const double pityBonus = 0.10;
}

/// 按稀有度分组
Map<String, List<TraitDef>> traitsByRarity() {
  final map = <String, List<TraitDef>>{
    'common': [],
    'rare': [],
    'legendary': [],
  };
  for (final t in traitCatalog) {
    map[t.rarity]?.add(t);
  }
  return map;
}

TraitDef? traitById(String id) {
  for (final t in traitCatalog) {
    if (t.id == id) return t;
  }
  return null;
}
