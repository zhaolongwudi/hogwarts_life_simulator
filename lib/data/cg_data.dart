import 'cg_unlock_conditions.dart';

/// CG 数据：依据设定文档「第十五部分 · 特殊CG系统」
class CgDef {
  final String id;
  final String name;
  final int stars; // 1-5
  final String chapter; // 相遇/暧昧/深情/珍贵/表白心碎/拉郎配/骨科

  /// 构造器里写的条件文案。只对「解锁条件写在代码里的」CG（拉郎配、硬编码
  /// 剧情点）有效；凡是在 cgUnlockConditions 里声明了条件的 CG，一律以
  /// [conditionText] 为准，这里的原文只作为兜底。
  final String condition;

  const CgDef({
    required this.id,
    required this.name,
    required this.stars,
    required this.chapter,
    required this.condition,
  });

  String get starText => '★' * stars;

  /// 给玩家看的解锁条件，也是唯一应该被显示的那份。
  ///
  /// 条件表和条件文案曾经是两份手抄，早就漂了（CG-001 文案写「初遇」，实际
  /// 判定是好感≥20；CG-011 文案写「好感≥80」，实际还要求对方是暗恋对象）。
  /// 现在表内的 CG 直接由条件表生成文案，表外的沿用声明原文。
  String get conditionText {
    final generated = cgConditionTextOf(id);
    return generated.isNotEmpty ? generated : condition;
  }
}

/// 相遇与暗恋之章
const List<CgDef> cgMeet = [
  CgDef(id: 'CG-001', name: '雾气中的第一眼', stars: 2, chapter: '相遇与暗恋', condition: '初遇'),
  CgDef(id: 'CG-002', name: '分院帽下的对视', stars: 2, chapter: '相遇与暗恋', condition: '分院仪式'),
  CgDef(id: 'CG-003', name: '对角巷的偶然回眸', stars: 2, chapter: '相遇与暗恋', condition: '初次相遇'),
  CgDef(id: 'CG-004', name: '走廊里的第一百次对视', stars: 2, chapter: '相遇与暗恋', condition: '好感≥35'),
  CgDef(id: 'CG-005', name: '图书馆的偷看笔记', stars: 2, chapter: '相遇与暗恋', condition: '好感≥40'),
  CgDef(id: 'CG-006', name: '魁地奇练习场的独行身影', stars: 2, chapter: '相遇与暗恋', condition: '好感≥40'),
];

/// 暧昧与恋爱之章
const List<CgDef> cgLove = [
  CgDef(id: 'CG-007', name: '雪地里的指尖相触', stars: 3, chapter: '暧昧与恋爱', condition: '好感≥60'),
  CgDef(id: 'CG-008', name: '共享围巾的雪夜', stars: 3, chapter: '暧昧与恋爱', condition: '好感≥65'),
  CgDef(id: 'CG-009', name: '有求必应屋的烛火', stars: 3, chapter: '暧昧与恋爱', condition: '好感≥70'),
  CgDef(id: 'CG-010', name: '天文塔的告白', stars: 3, chapter: '暧昧与恋爱', condition: 'NPC表白'),
  CgDef(id: 'CG-011', name: '圣诞舞会的旋转瞬间', stars: 3, chapter: '暧昧与恋爱', condition: '好感≥80'),
  CgDef(id: 'CG-012', name: '湖畔的初吻', stars: 3, chapter: '暧昧与恋爱', condition: '恋爱后'),
];

/// 深情与宿命之章
const List<CgDef> cgDeep = [
  CgDef(id: 'CG-013', name: '雨中拥吻的告别', stars: 4, chapter: '深情与宿命', condition: '好感≥90'),
  CgDef(id: 'CG-014', name: '日出的誓言', stars: 4, chapter: '深情与宿命', condition: '好感≥92'),
  CgDef(id: 'CG-015', name: '圣诞夜的长吻', stars: 4, chapter: '深情与宿命', condition: '好感≥95'),
  CgDef(id: 'CG-016', name: '生死之间的抉择', stars: 4, chapter: '深情与宿命', condition: '好感≥90'),
  CgDef(id: 'CG-017', name: '时间转换器的逆光', stars: 4, chapter: '深情与宿命', condition: '好感≥95'),
  CgDef(id: 'CG-018', name: '挽留的那一刻', stars: 4, chapter: '深情与宿命', condition: '好感≥93'),
];

/// 珍贵之章
const List<CgDef> cgPrecious = [
  CgDef(id: 'CG-019', name: '私奔的月光', stars: 5, chapter: '珍贵之章', condition: '好感≥96'),
  CgDef(id: 'CG-020', name: '霍格沃茨的婚礼', stars: 5, chapter: '珍贵之章', condition: '好感≥98'),
  CgDef(id: 'CG-021', name: '第一个孩子的啼哭', stars: 5, chapter: '珍贵之章', condition: '婚后生育'),
];

/// 表白与心碎之章
const List<CgDef> cgConfess = [
  CgDef(id: 'CG-CF-001', name: '月光下的告白', stars: 4, chapter: '表白与心碎', condition: 'NPC主动表白'),
  CgDef(id: 'CG-CF-002', name: '心碎的转身', stars: 3, chapter: '表白与心碎', condition: '拒绝表白'),
  CgDef(id: 'CG-CF-003', name: '沉默的等待', stars: 4, chapter: '表白与心碎', condition: '需要时间思考'),
];

/// 拉郎配特殊CG
const List<CgDef> cgPair = [
  CgDef(id: 'CG-LP-001', name: '第一次对视', stars: 3, chapter: '拉郎配', condition: '配对好感≥60'),
  CgDef(id: 'CG-LP-002', name: '梦中的名字', stars: 3, chapter: '拉郎配', condition: '配对好感≥65'),
  CgDef(id: 'CG-LP-003', name: '不自觉的维护', stars: 3, chapter: '拉郎配', condition: '配对好感≥70'),
  CgDef(id: 'CG-LP-004', name: '月下的坦白', stars: 4, chapter: '拉郎配', condition: '配对好感≥75'),
  CgDef(id: 'CG-LP-005', name: '不曾说出口的承认', stars: 4, chapter: '拉郎配', condition: '配对关系恋爱'),
  CgDef(id: 'CG-LP-006', name: '世界的偏袒', stars: 5, chapter: '拉郎配', condition: '配对关系深爱'),
];

/// 骨科特殊CG
const List<CgDef> cgBone = [
  CgDef(id: 'CG-BONE-001', name: '血脉的悖论', stars: 4, chapter: '骨科', condition: '骨科模式开启，表白'),
  CgDef(id: 'CG-BONE-002', name: '家族的沉默', stars: 4, chapter: '骨科', condition: '骨科模式开启，公开关系'),
  CgDef(id: 'CG-BONE-003', name: '不被原谅的选择', stars: 5, chapter: '骨科', condition: '骨科模式开启，关系深化'),
];

List<CgDef> allCgs() => [...cgMeet, ...cgLove, ...cgDeep, ...cgPrecious, ...cgConfess, ...cgPair, ...cgBone];

CgDef? cgById(String id) {
  for (final cg in allCgs()) {
    if (cg.id == id) return cg;
  }
  return null;
}
