/// R7：分院条件数据化（替换 computeHouseLocal 中 4 套硬编码关键词 List）
///
/// 原 if 链散落着：
///   - 性格关键词加分（每命中1个 +2）
///   - houseDimensions 四维直接加对应分值
///   - 政治倾向微调
///   - 血统背景微调
/// 现在全部做成 HouseSortingWeight 的数据，新学院或新关键词直接加数据。
class HouseSortingWeight {
  final String houseKey; // Gryffindor / Slytherin / Ravenclaw / Hufflepuff
  final String displayName;
  final List<String> traitKeywords; // 性格关键词，命中 +2
  final String dimKey; // courage / ambition / wisdom / loyalty
  final List<String> politicalTendencyBoost; // 政治倾向包含这些关键词则 +1
  final List<String> bloodBoost; // 血统包含这些关键词则 +1

  const HouseSortingWeight({
    required this.houseKey,
    required this.displayName,
    required this.traitKeywords,
    required this.dimKey,
    this.politicalTendencyBoost = const [],
    this.bloodBoost = const [],
  });
}

const List<HouseSortingWeight> houseSortingWeights = [
  HouseSortingWeight(
    houseKey: 'Gryffindor',
    displayName: '格兰芬多',
    traitKeywords: ['勇敢', '勇气', '无畏', '热情', '骑士', '正义'],
    dimKey: 'courage',
    politicalTendencyBoost: ['平等', '凤凰社'],
    bloodBoost: ['muggleborn'],
  ),
  HouseSortingWeight(
    houseKey: 'Slytherin',
    displayName: '斯莱特林',
    traitKeywords: ['野心', '精明', '狡猾', '意志', '血统', '领导'],
    dimKey: 'ambition',
    politicalTendencyBoost: ['纯血'],
    bloodBoost: ['pureblood'],
  ),
  HouseSortingWeight(
    houseKey: 'Ravenclaw',
    displayName: '拉文克劳',
    traitKeywords: ['智慧', '聪明', '好奇', '知识', '创造', '学习'],
    dimKey: 'wisdom',
  ),
  HouseSortingWeight(
    houseKey: 'Hufflepuff',
    displayName: '赫奇帕奇',
    traitKeywords: ['忠诚', '勤勉', '公平', '坚韧', '正直', '耐心'],
    dimKey: 'loyalty',
  ),
];

// houseKeyByDisplayName 已挪到 lib/data/house_data.dart —— 学院名与学院 key
// 的双向映射放一起，改译名时不用跨文件找。
