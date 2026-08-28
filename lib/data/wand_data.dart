/// 魔杖数据：依据设定文档「第六部分 · 魔杖系统」
class WandData {
  final String id;
  final String name;
  final String wood;
  final String core;
  final String length;
  final String description;
  final String suitType;

  const WandData({
    required this.id,
    required this.name,
    required this.wood,
    required this.core,
    required this.length,
    required this.description,
    required this.suitType,
  });
}

/// 三大标准杖芯
const Map<String, String> wandCoreTraits = {
  '独角兽毛': '最稳定、最忠诚，最难倒向黑魔法',
  '龙心脏腱索': '最强大，容易转向黑魔法',
  '凤凰羽毛': '最稀有，有自主意识',
};

const List<WandData> wands = [
  WandData(
    id: 'holly_phoenix',
    name: '冬青木·凤凰羽毛',
    wood: '冬青木',
    core: '凤凰羽毛',
    length: '11英寸',
    description: '与哈利·波特同款魔杖，冬青木代表防护与掌控，凤凰羽毛杖芯拥有自主意识。',
    suitType: '非凡使命与崇高追求',
  ),
  WandData(
    id: 'yew_phoenix',
    name: '紫杉木·凤凰羽毛',
    wood: '紫杉木',
    core: '凤凰羽毛',
    length: '13.5英寸',
    description: '与伏地魔的魔杖为孪生杖芯，紫杉木象征死亡与重生。',
    suitType: '意志坚定、隐藏极深',
  ),
  WandData(
    id: 'vine_dragon',
    name: '葡萄藤木·龙心脏腱索',
    wood: '葡萄藤木',
    core: '龙心脏腱索',
    length: '10.75英寸',
    description: '与赫敏·格兰杰同款魔杖，葡萄藤木适合有追求、有远大目标的巫师。',
    suitType: '雄心勃勃、意志坚定',
  ),
  WandData(
    id: 'hawthorn_unicorn',
    name: '山楂木·独角兽毛',
    wood: '山楂木',
    core: '独角兽毛',
    length: '10英寸',
    description: '与德拉科·马尔福同款魔杖，山楂木适合内心复杂、命运多舛的巫师。',
    suitType: '内心复杂、充满矛盾',
  ),
  WandData(
    id: 'cherry_unicorn',
    name: '樱桃木·独角兽毛',
    wood: '樱桃木',
    core: '独角兽毛',
    length: '9英寸',
    description: '与纳威·隆巴顿同款魔杖，樱桃木适合正直、纯真、内心勇敢的巫师。',
    suitType: '正直、纯真、不轻易动摇',
  ),
  WandData(
    id: 'oak_unicorn',
    name: '橡木·独角兽毛',
    wood: '橡木',
    core: '独角兽毛',
    length: '12英寸',
    description: '橡木象征力量与守护，独角兽毛杖芯稳定忠诚，适合守护者的魔杖。',
    suitType: '忠诚可靠、守护者',
  ),
  WandData(
    id: 'willow_unicorn',
    name: '柳木·独角兽毛',
    wood: '柳木',
    core: '独角兽毛',
    length: '11.5英寸',
    description: '柳木适合有远大抱负却常被低估的巫师，柔和外表下藏着坚韧。',
    suitType: '深藏不露、韧性',
  ),
  WandData(
    id: 'elm_dragon',
    name: '榆木·龙心脏腱索',
    wood: '榆木',
    core: '龙心脏腱索',
    length: '13英寸',
    description: '榆木只选择纯粹之人，龙心脏腱索赋予强大的力量，适合天生的领袖。',
    suitType: '纯粹、天生的领袖',
  ),
  WandData(
    id: 'cedar_unicorn',
    name: '雪松木·独角兽毛',
    wood: '雪松木',
    core: '独角兽毛',
    length: '10.5英寸',
    description: '雪松木忠于内心信念，独角兽毛让魔杖稳定而忠诚，适合内心刚正之人。',
    suitType: '内心刚正、信念坚定',
  ),
  WandData(
    id: 'maple_phoenix',
    name: '枫木·凤凰羽毛',
    wood: '枫木',
    core: '凤凰羽毛',
    length: '12.5英寸',
    description: '枫木青睐有天赋且内心强大的巫师，凤凰羽毛杖芯罕见而神秘。',
    suitType: '天赋与内心强大',
  ),
];
/// 从设定的著名魔杖搭配中查找
String? canonWandFor(String npcName) {
  const map = {
    '哈利·波特': '冬青木，凤凰羽毛，11英寸',
    '伏地魔': '紫杉木，凤凰羽毛',
    '赫敏·格兰杰': '葡萄藤木，龙心脏腱索',
    '德拉科·马尔福': '山楂木，独角兽毛',
    '纳威·隆巴顿': '樱桃木，独角兽毛',
    '阿不思·邓布利多': '接骨木（老魔杖）',
  };
  return map[npcName];
}

/// 按 id 查找魔杖
WandData? wandById(String id) {
  for (final w in wands) {
    if (w.id == id) return w;
  }
  return null;
}
