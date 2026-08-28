/// 血统（bloodType）的唯一权威：标签、开局问卷可选项、问卷说明。
///
/// 之前这三样散在两个地方各写一份：
///  - mixin_systems.bloodStatusLabel：13 个 key 的 Map，游戏内文案用
///  - intro_screen._bloodLabels / _bloodOptions / _bloodDescriptions：
///    问卷 UI 自己又写了一遍 11 个标签（其中「默然者」还多带了「（高风险）」）
/// 两边一旦不同步，玩家在问卷里看到的名字和实际写进存档、显示的状态栏
/// 就对不上。放数据层之后两边共用一份。
library;

/// 血统 key → 中文名（游戏内统一文案）。
const Map<String, String> kBloodStatusLabels = {
  'muggleborn': '麻瓜出身',
  'halfblood': '混血巫师',
  'pureblood': '纯血',
  'pureblood_side': '纯血旁支',
  'pureblood_sacred': '神圣二十八族',
  'special': '特殊家庭',
  'squib': '哑炮',
  'obscurial': '默然者',
  'veela': '混血媚娃',
  'werewolf': '狼人',
  'half_giant': '半巨人',
  'muggle_family': '麻瓜家庭',
  'custom': '自定义',
  // 'ghost' 是 NPC 侧用的（宾斯教授），玩家选不了，所以只在标签表里、
  // 不进 kBloodStatusOptions。之前没这条，NPC 列表会直接打出 "ghost"。
  'ghost': '幽灵',
};

/// 开局问卷里可选的血统。
///
/// 不是所有血统都适合让玩家开局就选（'pureblood' 和 'special' 是
/// 剧情/NPC 侧用的），所以这张表比 [kBloodStatusLabels] 短。
const List<String> kBloodStatusOptions = [
  'muggleborn',
  'halfblood',
  'pureblood_side',
  'pureblood_sacred',
  'squib',
  'obscurial',
  'veela',
  'werewolf',
  'half_giant',
  'muggle_family',
  'custom',
];

/// NPC 侧的历史别称 → 规范 key。
///
/// npc_data 里现存的取值其实已经是规范 key 了（pureblood/halfblood/
/// muggleborn/unknown/squib/ghost），这几个短写是老存档和早期数据留下的，
/// 单独收一张别名表，免得每个读 NPC 血统的地方都自己 switch 一遍。
const Map<String, String> kBloodStatusAliases = {
  'pure': 'pureblood',
  'half': 'halfblood',
  'muggle': 'muggleborn',
};

/// 开局问卷里对高风险血统的额外标注。
///
/// 只影响问卷 UI 的显示，不进存档、不进游戏内文案——否则状态栏上会
/// 莫名其妙跟着一个"（高风险）"。
const Set<String> kBloodStatusRisky = {'obscurial'};

/// 开局问卷里每个血统的说明文字。
const Map<String, String> kBloodStatusDescriptions = {
  'muggleborn': '父母均为麻瓜，十一岁前对魔法世界一无所知',
  'halfblood': '父母一方巫师一方麻瓜，魔法能力未必弱于纯血',
  'pureblood_side': '纯血家族非核心成员，有姓氏便利也背负期望',
  'pureblood_sacred': '古老纯血家族核心成员，拥有财富与人脉',
  'squib': '出生于巫师家庭但无法使用魔法，地位尴尬',
  'obscurial': '幼年压抑魔法诞生的危险黑暗力量，极高不稳定',
  'veela': '拥有媚娃血统，外貌魅惑但面临偏见',
  'werewolf': '被狼人咬伤，满月变形，面临严重就业歧视',
  'half_giant': '巨人血统，体型庞大力量惊人，被主流社会排斥',
  'muggle_family': '完全的麻瓜家庭，若非巫师则与魔法无关',
  'custom': '由玩家自定义血统与出身',
};

/// 血统 key → 中文名。未知 key 原样返回（比显示 '未知' 更好排查）。
String bloodStatusLabelOf(String status) =>
    kBloodStatusLabels[status] ?? status;

/// 开局问卷里显示的血统名（高风险血统会带上风险标注）。
String bloodStatusOptionLabel(String status) {
  final base = bloodStatusLabelOf(status);
  return kBloodStatusRisky.contains(status) ? '$base（高风险）' : base;
}

/// NPC 侧的血统标签。
///
/// 和玩家侧两点不同：认历史别称；'unknown' 显示「血统不明」而不是把
/// 'unknown' 这个 key 直接糊到 NPC 列表上。
String npcBloodStatusLabel(String status) {
  if (status.isEmpty || status == 'unknown') return '血统不明';
  return bloodStatusLabelOf(kBloodStatusAliases[status] ?? status);
}
