/// 咒语数据：玩家的「已学魔咒」（Player.learnedSpells）唯一的可学来源。
///
/// 这张表之所以存在，是因为学会咒语此前**在游戏里根本没有入口**：
/// 全项目对 learnedSpells 的写入只有一处——用《标准咒语书》且一个咒语都没
/// 学时，塞进一条「漂浮咒 / 等级1」。之后玩家再没有任何办法学第二个咒、也
/// 没有任何办法把等级从 1 提上去。连带后果：
///  - 成就「书虫」（学会 10 个以上魔咒）永远拿不到，上限是 1；
///  - 成就「优等生」（任一技能熟练度达到 90）查的是咒语等级，上限同样是 1；
///  - /状态 里的「已学魔咒」永远是「1个咒语」；
///  - 一致性检查器（mixin_narrative_continuity 的 R5_spell_power_creep）拿
///    learnedSpells 当白名单，白名单恒空，于是玩家哪怕学会了守护神咒，叙
///    事里一提就仍然被判「一年级放守护神」。
///
/// 表里的咒语按年级梯度排布，一年级禁咒（守护神咒、钻心咒、杀戮咒、夺魂
/// 咒）刻意保留但门槛拉到高年级——它们同时是上面那份白名单的解锁项：真的
/// 学会了，叙事才允许你放。
library;

/// 咒语分类，用于 /咒语 一览的分组展示。
enum SpellCategory {
  general('通用'),
  life('生活'),
  defense('防御'),
  offense('攻击'),
  transfiguration('变形'),
  dark('黑魔法');

  final String label;
  const SpellCategory(this.label);
}

class SpellDef {
  /// 中文名，同时是 learnedSpells 的键。
  final String name;

  /// 拉丁咒文。
  final String incantation;

  final SpellCategory category;

  /// 最低可学年级。
  final int minGrade;

  /// 难度 1~5：决定学习门槛与练习时的成长速度（越难长得越慢）。
  final int difficulty;

  /// 关联的熟练度属性键（lib/data/attribute_data.dart）。
  /// 咒语等级被这个属性「压着」——熟练度不到，等级就上不去。
  final String attribute;

  final String effect;

  const SpellDef({
    required this.name,
    required this.incantation,
    required this.category,
    required this.minGrade,
    required this.difficulty,
    required this.attribute,
    required this.effect,
  });

  /// 学习所需的关联属性下限。
  int get requiredAttribute => 20 + difficulty * 10;

  /// 咒语等级能到的上限：跟着熟练度走，熟练度满 100 时上限 100。
  ///
  /// 之所以不直接封 100：不然玩家一年级把漂浮咒连练三十次就能顶到满级，
  /// 而「咒语等级」在 /状态 和 AI 上下文里都会被当成实力看。
  int levelCapFor(int attributeValue) =>
      (attributeValue + 10).clamp(0, 100).toInt();
}

const List<SpellDef> spellCatalog = [
  // ====== 一年级 ======
  SpellDef(
    name: '漂浮咒',
    incantation: 'Wingardium Leviosa',
    category: SpellCategory.general,
    minGrade: 1,
    difficulty: 1,
    attribute: 'spell_understanding',
    effect: '让物体悬浮并随魔杖移动。',
  ),
  SpellDef(
    name: '照明咒',
    incantation: 'Lumos',
    category: SpellCategory.life,
    minGrade: 1,
    difficulty: 1,
    attribute: 'spell_understanding',
    effect: '杖尖亮起一束光。',
  ),
  SpellDef(
    name: '熄灭咒',
    incantation: 'Nox',
    category: SpellCategory.life,
    minGrade: 1,
    difficulty: 1,
    attribute: 'spell_understanding',
    effect: '熄掉照明咒的光。',
  ),
  SpellDef(
    name: '清理咒',
    incantation: 'Scourgify',
    category: SpellCategory.life,
    minGrade: 1,
    difficulty: 1,
    attribute: 'spell_understanding',
    effect: '擦洗掉污渍与污垢。',
  ),
  SpellDef(
    name: '开锁咒',
    incantation: 'Alohomora',
    category: SpellCategory.life,
    minGrade: 1,
    difficulty: 2,
    attribute: 'spell_understanding',
    effect: '撬开没有施加魔法的锁。',
  ),
  SpellDef(
    name: '软腿咒',
    incantation: 'Locomotor Mortis',
    category: SpellCategory.defense,
    minGrade: 1,
    difficulty: 2,
    attribute: 'dda',
    effect: '把对手的双腿锁在一起。',
  ),

  // ====== 二年级 ======
  SpellDef(
    name: '缴械咒',
    incantation: 'Expelliarmus',
    category: SpellCategory.defense,
    minGrade: 2,
    difficulty: 3,
    attribute: 'dda',
    effect: '击飞对手手中的魔杖。',
  ),
  SpellDef(
    name: '飞来咒',
    incantation: 'Accio',
    category: SpellCategory.general,
    minGrade: 2,
    difficulty: 2,
    attribute: 'spell_understanding',
    effect: '把远处的东西召唤到手边。',
  ),
  SpellDef(
    name: '束缚咒',
    incantation: 'Incarcerous',
    category: SpellCategory.defense,
    minGrade: 2,
    difficulty: 2,
    attribute: 'dda',
    effect: '甩出绳索捆住目标。',
  ),
  SpellDef(
    name: '全身束缚咒',
    incantation: 'Petrificus Totalus',
    category: SpellCategory.defense,
    minGrade: 2,
    difficulty: 3,
    attribute: 'dda',
    effect: '把人从头到脚定住。',
  ),
  SpellDef(
    name: '火柴变针',
    incantation: 'Sargophagi Transfiguras',
    category: SpellCategory.transfiguration,
    minGrade: 2,
    difficulty: 2,
    attribute: 'transfiguration',
    effect: '一年级变形课的入门变形。',
  ),

  // ====== 三年级 ======
  SpellDef(
    name: '铁甲咒',
    incantation: 'Protego',
    category: SpellCategory.defense,
    minGrade: 3,
    difficulty: 3,
    attribute: 'dda',
    effect: '在身前立起一面看不见的屏障。',
  ),
  SpellDef(
    name: '昏迷咒',
    incantation: 'Stupefy',
    category: SpellCategory.offense,
    minGrade: 3,
    difficulty: 3,
    attribute: 'dda',
    effect: '击晕对手，命中要害则直接放倒。',
  ),
  SpellDef(
    name: '愈合咒',
    incantation: 'Episkey',
    category: SpellCategory.life,
    minGrade: 3,
    difficulty: 3,
    attribute: 'herbology',
    effect: '接好断骨、止住小伤。',
  ),
  SpellDef(
    name: '复苏咒',
    incantation: 'Enervate',
    category: SpellCategory.life,
    minGrade: 3,
    difficulty: 3,
    attribute: 'herbology',
    effect: '唤醒被昏迷咒放倒的人。',
  ),
  SpellDef(
    name: '呼神护卫的引子·快乐咒',
    incantation: 'Expecto Patronum（练习）',
    category: SpellCategory.defense,
    minGrade: 3,
    difficulty: 4,
    attribute: 'dda',
    effect: '还唤不出成形守护神，只能让杖尖凝出银雾。',
  ),
  SpellDef(
    name: '蜷缩咒',
    incantation: 'Locomotor Wibbly',
    category: SpellCategory.offense,
    minGrade: 3,
    difficulty: 3,
    attribute: 'dda',
    effect: '让对手的腿软成面条。',
  ),

  // ====== 四年级 ======
  SpellDef(
    name: '变形咒·动物变高脚杯',
    incantation: 'Draconifors',
    category: SpellCategory.transfiguration,
    minGrade: 4,
    difficulty: 4,
    attribute: 'transfiguration',
    effect: '把小型生物变成一件器皿。',
  ),
  SpellDef(
    name: '消失咒',
    incantation: 'Evanesco',
    category: SpellCategory.transfiguration,
    minGrade: 4,
    difficulty: 4,
    attribute: 'transfiguration',
    effect: '让一件东西彻底消失。',
  ),
  SpellDef(
    name: '复制咒',
    incantation: 'Geminio',
    category: SpellCategory.transfiguration,
    minGrade: 4,
    difficulty: 4,
    attribute: 'transfiguration',
    effect: '复制一件物品，复制品脆弱易坏。',
  ),
  SpellDef(
    name: '夺魂咒',
    incantation: 'Imperio',
    category: SpellCategory.dark,
    minGrade: 4,
    difficulty: 5,
    attribute: 'dda',
    effect: '不可饶恕咒之一：完全控制对方的意志。',
  ),

  // ====== 五年级及以上 ======
  SpellDef(
    name: '守护神咒',
    incantation: 'Expecto Patronum',
    category: SpellCategory.defense,
    minGrade: 5,
    difficulty: 5,
    attribute: 'dda',
    effect: '唤出成形的守护神，驱散摄魂怪。',
  ),
  SpellDef(
    name: '无声咒',
    incantation: '（无咒文·无声施法）',
    category: SpellCategory.general,
    minGrade: 5,
    difficulty: 5,
    attribute: 'magic_control',
    effect: '不出声也能施法，O.W.L.s 的加分项。',
  ),
  SpellDef(
    name: '变形咒·人形变形',
    incantation: 'Hominem Revelio',
    category: SpellCategory.transfiguration,
    minGrade: 6,
    difficulty: 5,
    attribute: 'transfiguration',
    effect: '最难的变形：把一样东西变成人。',
  ),
  SpellDef(
    name: '钻心咒',
    incantation: 'Crucio',
    category: SpellCategory.dark,
    minGrade: 6,
    difficulty: 5,
    attribute: 'dda',
    effect: '不可饶恕咒之一：制造无法忍受的痛苦。',
  ),
  SpellDef(
    name: '杀戮咒',
    incantation: 'Avada Kedavra',
    category: SpellCategory.dark,
    minGrade: 7,
    difficulty: 5,
    attribute: 'dda',
    effect: '不可饶恕咒之一：一道绿光，不可抵挡、不可饶恕。',
  ),
];

/// 按名字查咒语（中英文与拉丁咒文都认）。
///
/// 认拉丁咒文是因为 AI 生成的叙事里常写「Expelliarmus」，一致性检查器
/// 那边拿到的是咒文而不是中文名。
SpellDef? spellByName(String name) {
  if (name.isEmpty) return null;
  final lower = name.toLowerCase();
  for (final s in spellCatalog) {
    if (s.name == name) return s;
  }
  for (final s in spellCatalog) {
    if (s.name.contains(name) || name.contains(s.name)) return s;
  }
  for (final s in spellCatalog) {
    if (s.incantation.toLowerCase() == lower) return s;
  }
  for (final s in spellCatalog) {
    if (s.incantation.toLowerCase().contains(lower) && lower.length >= 4) {
      return s;
    }
  }
  return null;
}

/// 当前年级已经可以学的咒语。
List<SpellDef> spellsLearnableAt(int grade) =>
    spellCatalog.where((s) => s.minGrade <= grade).toList();
