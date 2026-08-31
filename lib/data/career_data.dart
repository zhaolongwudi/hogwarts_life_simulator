/// 毕业后正式职业系统（框架2 §95 毕业不是结局 + §96 职业有门槛）
///
/// 仿照 faculty_data（教职）的成熟模式：职业线 = 职级表（职称/年薪/晋升门槛）+
/// 每年九月年结（发薪 + 晋升判定）。区别是：
///  · 教职只服务「留校任教」一条路，职业系统覆盖 goal 目录里的主流人生目标；
///  · 入职有硬门槛：O.W.L/N.E.W.T 成绩、核心属性、对应声望维度；
///  · 玩家七年攒下的成绩与声望在这里兑现成职业起点。
library;

import 'attribute_data.dart';
import 'exam_data.dart';

/// O.W.L/N.E.W.T 单科成绩要求（subject: 科目 id，minGrade: 最低等级）。
/// 用对象而不是 Map 是为了避免被「手写属性表」契约测试误判——
/// 这里存的是科目→成绩等级，不是属性→中文名。
class OwlRequirement {
  final String subject;
  final String minGrade;
  const OwlRequirement(this.subject, this.minGrade);
}

/// 职业线定义
class CareerDef {
  final String id;
  final String name;

  /// 一句话描述（/职业 列表 展示）
  final String description;

  /// 入职要求的核心属性键（attribute_data 的 key）
  final String minAttr;
  final int minAttrValue;

  /// 入职要求的声望维度（academic/social/combat/moral/leadership/dark）
  final String repDim;
  final int minReputation;

  /// O.W.L 中至少需要达到的成绩等级（'O'/'E'/'A'，A=及格）
  /// 空 = 不要求特定科目
  final List<OwlRequirement> owlRequirements;

  /// 是否要求 N.E.W.T 高阶成绩（六年级以上职业）
  final bool requiresNewt;

  /// 职级（从低到高）
  final List<String> ranks;

  /// 起始年薪（加隆）
  final int startPay;

  /// 顶级年薪
  final int topPay;

  /// 每级晋升所需服务年限
  final int yearsPerRank;

  /// 职责描述（注入叙事 AI + /职业 展示）
  final String duty;

  const CareerDef({
    required this.id,
    required this.name,
    required this.description,
    required this.minAttr,
    required this.minAttrValue,
    required this.repDim,
    required this.minReputation,
    this.owlRequirements = const [],
    this.requiresNewt = false,
    required this.ranks,
    required this.startPay,
    required this.topPay,
    this.yearsPerRank = 2,
    required this.duty,
  });

  int payAt(int rankIndex) {
    final t = ranks.isEmpty ? 0 : (rankIndex.clamp(0, ranks.length - 1) / (ranks.length - 1)).clamp(0.0, 1.0);
    return (startPay + (topPay - startPay) * t).round();
  }

  /// 是否满足入职门槛
  bool eligible({
    required Map<String, int> attributes,
    required Map<String, String> owlGrades,
    required Map<String, String> newtGrades,
    required int repValue,
  }) {
    final attr = attributes[minAttr] ?? 0;
    if (attr < minAttrValue) return false;
    if (repValue < minReputation) return false;
    for (final e in owlRequirements) {
      final grade = owlGrades[e.subject] ?? newtGrades[e.subject];
      if (grade == null) return false;
      if (_gradeRank(grade) < _gradeRank(e.minGrade)) return false;
    }
    if (requiresNewt && newtGrades.isEmpty) return false;
    return true;
  }

  static int _gradeRank(String g) {
    const order = {'T': 0, 'D': 1, 'P': 2, 'A': 3, 'E': 4, 'O': 5};
    return order[g] ?? 0;
  }
}

/// 全部职业线（对齐 goal_data 的职业类目标）
const List<CareerDef> kCareers = [
  CareerDef(
    id: 'auror',
    name: '傲罗',
    description: '捍卫魔法界，追捕黑巫师。需要过硬的战斗能力与胆识。',
    minAttr: 'dda',
    minAttrValue: 70,
    repDim: 'combat',
    minReputation: 60,
    owlRequirements: [OwlRequirement('dda', 'E'), OwlRequirement('potions', 'A')],
    requiresNewt: true,
    ranks: ['初级傲罗', '傲罗', '高级傲罗', '首席傲罗'],
    startPay: 400,
    topPay: 1500,
    yearsPerRank: 2,
    duty: '追捕黑巫师、调查危险案件、保护魔法界的安全。你的世界总是伴随着危险，但每一次凯旋都让这个世界更安全一点。',
  ),
  CareerDef(
    id: 'healer',
    name: '圣芒戈治疗师',
    description: '在圣芒戈魔法伤病医院救死扶伤。需要扎实的魔药与草药功底。',
    minAttr: 'potions',
    minAttrValue: 70,
    repDim: 'moral',
    minReputation: 55,
    owlRequirements: [OwlRequirement('potions', 'E'), OwlRequirement('herbology', 'E')],
    requiresNewt: true,
    ranks: ['实习治疗师', '治疗师', '资深治疗师', '首席治疗师'],
    startPay: 380,
    topPay: 1200,
    yearsPerRank: 2,
    duty: '在圣芒戈医院的病房与药房之间奔走。你见过最深的伤痛，也见过最顽强的生命。',
  ),
  CareerDef(
    id: 'ministry',
    name: '魔法部职员',
    description: '从普通职员做起，一路走向魔法部的权力中枢。',
    minAttr: 'social',
    minAttrValue: 60,
    repDim: 'leadership',
    minReputation: 50,
    owlRequirements: [OwlRequirement('history', 'A'), OwlRequirement('theory', 'A')],
    ranks: ['初级职员', '科长', '司长', '副部长'],
    startPay: 320,
    topPay: 1000,
    yearsPerRank: 3,
    duty: '在魔法部巨大的办公室迷宫里处理公文、协调部门、周旋于人事之间。权力游戏需要耐心。',
  ),
  CareerDef(
    id: 'reporter',
    name: '《预言家日报》记者',
    description: '用羽毛笔撬开魔法界的真相。需要敏锐的观察与社交手腕。',
    minAttr: 'observation',
    minAttrValue: 65,
    repDim: 'social',
    minReputation: 55,
    owlRequirements: [OwlRequirement('theory', 'A')],
    ranks: ['实习记者', '记者', '资深记者', '主编'],
    startPay: 300,
    topPay: 900,
    yearsPerRank: 2,
    duty: '追逐新闻、挖掘真相、在风口浪尖上保持清醒。你写的每一个字都会被人读到。',
  ),
  CareerDef(
    id: 'quidditch_pro',
    name: '职业魁地奇球员',
    description: '把七年球场上的汗水兑现为职业联赛的席位。',
    minAttr: 'flying',
    minAttrValue: 80,
    repDim: 'combat',
    minReputation: 45,
    ranks: ['替补球员', '正式球员', '明星球员', '队长'],
    startPay: 500,
    topPay: 2000,
    yearsPerRank: 2,
    duty: '在职业联赛的扫帚上驰骋。聚光灯下的每一秒，都来自训练场上没人看见的千百次练习。',
  ),
  CareerDef(
    id: 'curse_breaker',
    name: '古灵阁诅咒破解师',
    description: '深入古老遗迹与地下金库，破解千年诅咒。',
    minAttr: 'transfiguration',
    minAttrValue: 65,
    repDim: 'academic',
    minReputation: 55,
    owlRequirements: [OwlRequirement('transfiguration', 'E'), OwlRequirement('dda', 'A')],
    requiresNewt: true,
    ranks: ['学徒破解师', '破解师', '资深破解师', '首席破解师'],
    startPay: 420,
    topPay: 1400,
    yearsPerRank: 2,
    duty: '跟随古灵阁的探险队深入被时间遗忘的角落。每一次破咒，都是在与千年前的巫师对话。',
  ),
  CareerDef(
    id: 'potion_master',
    name: '魔药大师',
    description: '在坩埚与火焰之间追寻魔药学的极致。',
    minAttr: 'potions',
    minAttrValue: 75,
    repDim: 'academic',
    minReputation: 50,
    owlRequirements: [OwlRequirement('potions', 'O')],
    ranks: ['学徒', '魔药师', '魔药大师'],
    startPay: 350,
    topPay: 1100,
    yearsPerRank: 2,
    duty: '在私人实验室里调配药水、改良配方、为稀有药剂寻找新的解法。',
  ),
  CareerDef(
    id: 'ordinary',
    name: '普通巫师',
    description: '不追求传奇，找一份安稳的工作，过普通而体面的人生。',
    minAttr: 'social',
    minAttrValue: 40,
    repDim: 'moral',
    minReputation: 30,
    ranks: ['职员'],
    startPay: 250,
    topPay: 500,
    yearsPerRank: 3,
    duty: '在魔法世界的某个角落认真生活：开店、种地、养猫头鹰、攒钱旅行。平淡本身也是一种幸福。',
  ),
];

CareerDef? careerById(String id) {
  for (final c in kCareers) {
    if (c.id == id) return c;
  }
  return null;
}

CareerDef? careerByName(String name) {
  for (final c in kCareers) {
    if (c.name == name || c.description.contains(name) || name.contains(c.name)) {
      return c;
    }
  }
  return null;
}

/// 职业申请门槛文案（未达标时展示差了什么）
String careerGapText(CareerDef c, {
  required Map<String, int> attributes,
  required Map<String, String> owlGrades,
  required Map<String, String> newtGrades,
  required int repValue,
}) {
  final gaps = <String>[];
  final attr = attributes[c.minAttr] ?? 0;
  if (attr < c.minAttrValue) {
    gaps.add('${_attrName(c.minAttr)} ${attr}/${c.minAttrValue}');
  }
  if (repValue < c.minReputation) {
    gaps.add('${c.repDim}声望 $repValue/${c.minReputation}');
  }
  for (final e in c.owlRequirements) {
    final g = owlGrades[e.subject] ?? newtGrades[e.subject] ?? '无';
    if (CareerDef._gradeRank(g) < CareerDef._gradeRank(e.minGrade)) {
      gaps.add('${_subjectName(e.subject)}成绩 $g（需${e.minGrade}）');
    }
  }
  if (c.requiresNewt && newtGrades.isEmpty) {
    gaps.add('需参加 N.E.W.T. 考试');
  }
  return gaps.isEmpty ? '' : '未达标：${gaps.join('，')}';
}

String _attrName(String key) => attributeLabel(key);

String _subjectName(String key) {
  for (final s in examSubjects) {
    if (s.id == key) return s.name;
  }
  return key;
}
