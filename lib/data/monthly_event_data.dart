/// 月度事件池（R6：数据化，替代 _generateMonthlyEvent 硬编码 Map + 手写拼接）
///
/// 支持：
///   - weight：事件抽取权重（越大越容易抽到）
///   - seasonTags：季节标签（spring/summer/autumn/winter）；空表示四季通用
///   - mutuallyExclusiveIds：互斥事件 id 列表。抽中 A 之后，
///     [kMutuallyExclusiveMonths] 个月内不再抽 B/C（双向生效）。
///   - baseChance：基础参与概率（0.0~1.0），类似旧代码里 dark=0.3 / creature=0.4
class MonthlyEventDef {
  final String id;
  final String category; // ministry / hogwarts / economy / dark / creature / season
  final String text;
  final int weight;
  final List<String> seasonTags; // spring(3-5) summer(6-8) autumn(9-11) winter(12-2)

  /// 互斥事件 id。抽中本条之后 [kMutuallyExclusiveMonths] 个月内，
  /// 列表里的事件不再参与抽取（反向同理：本条也会因为它们的发生被跳过）。
  final List<String> mutuallyExclusiveIds;

  /// 同一条事件在多少个月内不重复出现。
  static const int repeatCooldownMonths = 12;

  final double baseChance;

  const MonthlyEventDef({
    required this.id,
    required this.category,
    required this.text,
    this.weight = 1,
    this.seasonTags = const [],
    this.mutuallyExclusiveIds = const [],
    this.baseChance = 1.0,
  });
}

/// 互斥关系生效的窗口（月）。
const int kMutuallyExclusiveMonths = 6;

const List<MonthlyEventDef> monthlyEventPool = [
  // ====== ministry（魔法部新闻）======
  MonthlyEventDef(
    id: 'mini_reform',
    category: 'ministry',
    text: '魔法部宣布了新一轮的魔法教育改革方案，涉及到所有魔法学校的课程调整。',
    // 和「黑魔法防御术专项检查」是同一件事的两种说法，连着两个月播会很假
    mutuallyExclusiveIds: ['mini_dada_check'],
  ),
  MonthlyEventDef(
    id: 'mini_dada_check',
    category: 'ministry',
    text: '魔法部对黑魔法防御术进行了专项检查，霍格沃茨的师资队伍通过了严格审核。',
    mutuallyExclusiveIds: ['mini_reform'],
  ),
  MonthlyEventDef(
    id: 'mini_forbidden',
    category: 'ministry',
    text: '魔法部发布了新的禁咒名单，三种黑魔法被列入最高级别管制。',
  ),
  MonthlyEventDef(
    id: 'mini_goblin',
    category: 'ministry',
    text: '魔法部与妖精家族达成了新的古灵阁运营协议，加强了对魔法经济的监管。',
  ),

  // ====== hogwarts（校内琐事）======
  MonthlyEventDef(
    id: 'hw_quidditch',
    category: 'hogwarts',
    text: '霍格沃茨宣布了本学期的魁地奇比赛安排，各院队长已经开始紧张训练。',
    seasonTags: ['autumn', 'spring'],
  ),
  MonthlyEventDef(
    id: 'hw_donation',
    category: 'hogwarts',
    text: '霍格沃茨图书馆收到了一批珍贵的古籍捐赠，其中包括几本失传已久的魔法著作。',
    mutuallyExclusiveIds: ['hw_decor'],
  ),
  MonthlyEventDef(
    id: 'hw_ghosts',
    category: 'hogwarts',
    text: '霍格沃茨的幽灵们最近异常活跃，据说地下室里传来了奇怪的声响。',
  ),
  MonthlyEventDef(
    id: 'hw_decor',
    category: 'hogwarts',
    text: '霍格沃茨大礼堂进行了季节性装饰，墙壁上挂满了与当前月份相关的魔法旗帜。',
    mutuallyExclusiveIds: ['hw_donation'],
  ),

  // ====== economy（经济 / 市场）======
  MonthlyEventDef(
    id: 'eco_galleon',
    category: 'economy',
    text: '古灵阁的金币汇率本月波动较大，加隆对英镑的比值创下了近年来的新高。',
    // 和「药水涨价」都是"数字又变了"，连着听两次会觉得世界在复读
    mutuallyExclusiveIds: ['eco_potion_shortage'],
  ),
  MonthlyEventDef(
    id: 'eco_potion_shortage',
    category: 'economy',
    text: '魔法药品市场供应紧张，几种常用药水的价格上涨了约15%。',
    mutuallyExclusiveIds: ['eco_galleon'],
  ),
  MonthlyEventDef(
    id: 'eco_fair',
    category: 'economy',
    text: '魔法物品交易会在对角巷举行，吸引了来自全国各地的巫师商人。',
  ),
  MonthlyEventDef(
    id: 'eco_owl_delay',
    category: 'economy',
    text: '由于天气原因，猫头鹰邮递的效率有所下降，信件送达时间延迟了1-2天。',
  ),

  // ====== dark（黑魔法动向，低概率）======
  MonthlyEventDef(
    id: 'dark_auror_border',
    category: 'dark',
    text: '黑巫师的活动在欧洲大陆有所增加，魔法部派遣了更多的傲罗前往边境地区。',
    weight: 2,
    baseChance: 0.3,
    mutuallyExclusiveIds: ['dark_castle'],
  ),
  MonthlyEventDef(
    id: 'dark_castle',
    category: 'dark',
    text: '一座废弃的城堡被黑巫师占据，魔法界对此高度关注。',
    baseChance: 0.3,
    mutuallyExclusiveIds: ['dark_patrol', 'dark_auror_border'],
  ),
  MonthlyEventDef(
    id: 'dark_patrol',
    category: 'dark',
    text: '有关黑魔法社团的传闻在学生中流传，霍格沃茨加强了夜间巡逻。',
    baseChance: 0.3,
    mutuallyExclusiveIds: ['dark_castle'],
  ),
  MonthlyEventDef(
    id: 'dark_seized',
    category: 'dark',
    text: '魔法部截获了一批非法交易的魔法生物，其中包括几只受保护的独角兽幼崽。',
    baseChance: 0.3,
  ),

  // ====== creature（神奇生物新闻，中低概率）======
  MonthlyEventDef(
    id: 'cr_unicorn',
    category: 'creature',
    text: '禁林中的独角兽族群迁徙了新的领地，生物学家对此进行了密切观察。',
    seasonTags: ['spring', 'autumn'],
    baseChance: 0.4,
    // 「又有稀有生物出现了」连着来两次就不稀有了
    mutuallyExclusiveIds: ['cr_phoenix', 'cr_dragon'],
  ),
  MonthlyEventDef(
    id: 'cr_phoenix',
    category: 'creature',
    text: '一只罕见的凤凰在霍格沃茨上空出现了数天，引发了学生们的热烈讨论。',
    baseChance: 0.4,
    mutuallyExclusiveIds: ['cr_unicorn', 'cr_dragon'],
  ),
  MonthlyEventDef(
    id: 'cr_spew',
    category: 'creature',
    text: '家养小精灵权益促进会（S.P.E.W.）发起了新一轮的签名请愿活动。',
    baseChance: 0.4,
  ),
  MonthlyEventDef(
    id: 'cr_dragon',
    category: 'creature',
    text: '挪威脊背龙的幼崽在冰岛被发现，生物学家正在研究它的生活习性。',
    baseChance: 0.4,
    mutuallyExclusiveIds: ['cr_unicorn', 'cr_phoenix'],
  ),

  // ====== 季节专属 ======
  MonthlyEventDef(
    id: 'se_summer_hogsmeade',
    category: 'season',
    text: '六月的午后热浪升腾，霍格莫德村的黄油啤酒冰杯销量创下历史新高。',
    seasonTags: ['summer'],
    weight: 3,
  ),
  MonthlyEventDef(
    id: 'se_autumn_pumpkin',
    category: 'season',
    text: '海格的巨型南瓜丰收了，据说今年最大的一颗需要三个三年级生才能搬动。',
    seasonTags: ['autumn'],
    weight: 3,
  ),
  MonthlyEventDef(
    id: 'se_winter_snow',
    category: 'season',
    text: '苏格兰高地降下了今年第一场雪，城堡的塔楼披上了一层厚厚的银装。',
    seasonTags: ['winter'],
    weight: 3,
  ),
  MonthlyEventDef(
    id: 'se_spring_flower',
    category: 'season',
    text: '禁林边缘的银柳抽出了新芽，草药课上教授提到这是制作舒缓药水的珍贵原料。',
    seasonTags: ['spring'],
    weight: 3,
  ),
];

/// 月份转季节标签（spring/summer/autumn/winter）
List<String> seasonTagsForMonth(int month) {
  if (month >= 3 && month <= 5) return const ['spring'];
  if (month >= 6 && month <= 8) return const ['summer'];
  if (month >= 9 && month <= 11) return const ['autumn'];
  return const ['winter'];
}
