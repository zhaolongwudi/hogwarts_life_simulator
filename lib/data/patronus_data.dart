/// 守护神形态数据（框架2 第66条 · 守护神与人格情感长期关联）
///
/// 设计：
///  · 守护神不是菜单里挑最帅的动物——形态由角色长期形成的人格、信念、
///    最深的记忆共同决定（这里用性格特质 + 学院 + 信念关键词近似）；
///  · 形态可能随巨大人生变化而改变（预留：世界线变动率高时可重塑）；
///  · 一年级不可能有守护神：需要守护神咒（五年级咒语）+ 情绪控制达标。
library;

/// 守护神候选：动物 + 关联特质/信念
class PatronusForm {
  final String animal;
  final String description;
  final List<String> traitKeywords;
  final String houseAffinity; // 空 = 不限
  const PatronusForm({
    required this.animal,
    required this.description,
    required this.traitKeywords,
    this.houseAffinity = '',
  });
}

const List<PatronusForm> kPatronusForms = [
  PatronusForm(
    animal: '雄鹿',
    description: '圣洁的白光凝成一头雄鹿的轮廓，鹿角如枝桠般舒展——它象征着守护与奉献，只为你真正在意的人奔跑。',
    traitKeywords: ['守护', '忠诚', '温柔', '奉献', '家人', '保护'],
  ),
  PatronusForm(
    animal: '银狮',
    description: '一头银白色的狮子昂首而立，鬃毛如月光织成——它由勇气与正义感凝成，面对黑暗时绝不后退。',
    traitKeywords: ['勇敢', '正义', '胆识', '骑士', '直率'],
    houseAffinity: 'Gryffindor',
  ),
  PatronusForm(
    animal: '渡鸦',
    description: '漆黑的渡鸦在光中展开翅膀，目光如墨玉——它属于那些永远在追问、永远在求索的灵魂。',
    traitKeywords: ['智慧', '好奇', '理性', '求知', '思考'],
    houseAffinity: 'Ravenclaw',
  ),
  PatronusForm(
    animal: '獾',
    description: '一只敦厚的獾踏光而来，脚步沉稳——它由忠诚与勤勉凝成，平时温和，遇险时寸步不让。',
    traitKeywords: ['忠诚', '正直', '勤勉', '耐心', '公平'],
    houseAffinity: 'Hufflepuff',
  ),
  PatronusForm(
    animal: '蛇',
    description: '一条银色的蛇缓缓游弋，鳞片折射着月光——它聪明而冷静，不轻易出手，出手则必中要害。',
    traitKeywords: ['野心', '精明', '果断', '冷静', '谋略'],
    houseAffinity: 'Slytherin',
  ),
  PatronusForm(
    animal: '赤狐',
    description: '一道灵巧的红影穿梭在光雾中，尾巴蓬松如火焰——它属于那些用机智与幽默化解一切的人。',
    traitKeywords: ['幽默', '乐观', '机智', '灵活'],
  ),
  PatronusForm(
    animal: '灰狼',
    description: '灰狼在月光下昂首长啸，孤独而骄傲——它属于那些独立、叛逆，却对认定的羁绊绝对忠诚的人。',
    traitKeywords: ['叛逆', '独立', '自由', '不羁'],
  ),
  PatronusForm(
    animal: '天鹅',
    description: '天鹅优雅地滑过光河，羽尖带起细碎的光点——它由细腻的情感凝成，温柔却有力量。',
    traitKeywords: ['细腻', '温柔', '艺术', '创造', '感性'],
  ),
  PatronusForm(
    animal: '雪鸮',
    description: '雪鸮静立枝头，目光清明——它属于那些在喧嚣中仍保有内心宁静与洞察的人。',
    traitKeywords: ['平静', '洞察', '内敛', '神秘'],
  ),
  PatronusForm(
    animal: '牡鹿',
    description: '牡鹿昂首，鹿角如冠——它由坚定的信念凝成，代表无论多少次跌倒都会重新站起的意志。',
    traitKeywords: ['意志', '信念', '坚韧', '不屈'],
  ),
];

/// 根据人格 + 学院 + 信念 + 骰子解析守护神形态。
String resolvePatronusForm({
  required List<String> personality,
  required String house,
  required String beliefs,
  required double dice,
}) {
  final joined = [...personality, beliefs].join('、');
  var best = kPatronusForms.first;
  double bestScore = -1;
  for (final f in kPatronusForms) {
    var score = 0;
    for (final t in f.traitKeywords) {
      if (joined.contains(t)) score += 2;
    }
    if (f.houseAffinity.isNotEmpty && f.houseAffinity == house) score += 1;
    final finalScore = score + (dice * 1.5 - 0.75);
    if (finalScore > bestScore) {
      bestScore = finalScore;
      best = f;
    }
  }
  return best.animal;
}

PatronusForm? patronusFormByName(String animal) {
  for (final f in kPatronusForms) {
    if (f.animal == animal) return f;
  }
  return null;
}
