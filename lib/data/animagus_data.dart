/// 阿尼马格斯系统数据（框架2 第67条 · 困难且长期的魔法道路）
///
/// 设计要点：
///  · 学习是「知识 → 药剂 → 训练 → 月圆夜尝试」四段式长线，不可一蹴而就；
///  · 动物形态与角色长期形成的人格/情感关联（不是菜单里挑最帅的）；
///  · 有失败后果与法律问题（魔法部登记），未登记的阿尼马格斯是重罪；
///  · 与月相（每月十五）联动。
library;

/// 阿尼马格斯阶段
class AnimagusStage {
  final String id; // none/studying/potionReady/transformed/failed
  final String label;
  final String description;
  const AnimagusStage(this.id, this.label, this.description);
}

const List<AnimagusStage> kAnimagusStages = [
  AnimagusStage('none', '未涉足', '你从未考虑过这门危险而漫长的变形艺术。'),
  AnimagusStage('studying', '研习中', '你在图书馆与古籍间研究阿尼马格斯的理论，曼德拉草药剂尚未备齐。'),
  AnimagusStage('potionReady', '药剂就绪', '曼德拉草药剂已备好，只等满月之夜，以及足够扎实的训练。'),
  AnimagusStage('transformed', '已成', '你已经掌握了变形的奥秘，动物形态是你灵魂的另一面。'),
  AnimagusStage('failed', '失败', '某次尝试出了差错，暂时无法继续——但并非没有挽回的余地。'),
];

AnimagusStage animagusStageOf(String id) =>
    kAnimagusStages.firstWhere((s) => s.id == id, orElse: () => kAnimagusStages.first);

/// 阿尼马格斯动物形态（与人格/学院/魔法特质关联）
class AnimagusForm {
  final String animal;
  final String description;
  final List<String> traitKeywords; // 命中任一即加分
  final String houseAffinity; // 学院偏好（Gryffindor/Slytherin/Ravenclaw/Hufflepuff/空=不限）
  const AnimagusForm({
    required this.animal,
    required this.description,
    required this.traitKeywords,
    this.houseAffinity = '',
  });
}

const List<AnimagusForm> kAnimagusForms = [
  AnimagusForm(
    animal: '雄狮',
    description: '金色的鬃毛在月光下泛着微光，步履沉缓而自信，像随时准备为守护之物挺身而出。',
    traitKeywords: ['勇敢', '直率', '热情', '正义', '正义感', '胆识'],
    houseAffinity: 'Gryffindor',
  ),
  AnimagusForm(
    animal: '猎隼',
    description: '身形纤长，目光锐利，掠过夜空时几乎无声，永远在更高的地方俯视全局。',
    traitKeywords: ['理性', '聪明', '独立', '好奇', '敏锐', '观察'],
    houseAffinity: 'Ravenclaw',
  ),
  AnimagusForm(
    animal: '银獾',
    description: '敦实而沉稳，皮毛带着银灰色的光泽，遇到威胁时半步不退，护住身后的同伴。',
    traitKeywords: ['忠诚', '正直', '勤勉', '耐心', '善良', '温柔'],
    houseAffinity: 'Hufflepuff',
  ),
  AnimagusForm(
    animal: '黑蟒',
    description: '鳞片在月光下泛着幽绿，行动无声，冷静地缠绕、等待，然后一击必中。',
    traitKeywords: ['野心', '精明', '果断', '深沉', '敏锐', '谋略'],
    houseAffinity: 'Slytherin',
  ),
  AnimagusForm(
    animal: '雪鸮',
    description: '纯白的羽翼在夜色中格外醒目，安静地凝视，仿佛能看穿人心底最深的秘密。',
    traitKeywords: ['神秘', '内敛', '敏感', '睿智', '包容'],
  ),
  AnimagusForm(
    animal: '赤狐',
    description: '火红的皮毛，眼中有狡黠的光。它不与你正面相争，却总能在最意想不到的地方赢下局面。',
    traitKeywords: ['幽默', '乐观', '机智', '灵活', '善于交际'],
  ),
  AnimagusForm(
    animal: '灰狼',
    description: '灰白的毛皮，绿莹莹的眼睛。它独行，也忠诚于自己的狼群——一旦认定，绝不背弃。',
    traitKeywords: ['叛逆', '独立', '直率', '挑战权威', '热情'],
  ),
  AnimagusForm(
    animal: '白鹿',
    description: '身形优雅，额间一点月光般的印记。它温柔而坚定，是那种愿意为重要之人安静地付出一切的生灵。',
    traitKeywords: ['温柔', '体贴', '细腻', '善良', '忠诚'],
  ),
];

/// 根据人格特质 + 学院 + 随机性，选出阿尼马格斯形态。
String resolveAnimagusForm({
  required List<String> personality,
  required String house,
  required double dice,
}) {
  var best = kAnimagusForms.first;
  double bestScore = -1;
  for (final f in kAnimagusForms) {
    var score = 0;
    for (final t in f.traitKeywords) {
      if (personality.any((p) => p.contains(t))) score += 2;
    }
    if (f.houseAffinity.isNotEmpty && f.houseAffinity == house) score += 1;
    // 平票时用骰子扰动，避免同人格永远同形态
    final finalScore = score + (dice * 1.5 - 0.75);
    if (finalScore > bestScore) {
      bestScore = finalScore;
      best = f;
    }
  }
  return best.animal;
}

AnimagusForm? animagusFormByName(String animal) {
  for (final f in kAnimagusForms) {
    if (f.animal == animal) return f;
  }
  return null;
}

/// 满月之夜尝试变身的成功概率（0~1）。
///
/// 基础 25% + 训练进度贡献（最高 +35%）+ 魔药/变形熟练度加成（最高 +25%）。
/// 一个认真训练（progress≈80）且魔药/变形都在 70+ 的学生，成功率约 70%；
/// 裸奔尝试（progress≈0）成功率只有约 30%——失败是常态，这才叫困难路线。
double animagusSuccessChance({
  required int progress,
  required int potions,
  required int transfiguration,
}) {
  final base = 0.25;
  final progressBonus = (progress.clamp(0, 100) / 100) * 0.35;
  final skillBonus =
      ((potions + transfiguration) / 2 - 40).clamp(0, 50) / 200.0;
  return (base + progressBonus + skillBonus).clamp(0.0, 0.9);
}

/// 训练一次的进度增量（5~15，随熟练度微调）。
int animagusTrainingGain(int potions, int transfiguration) {
  final skill = (potions + transfiguration) / 2;
  final base = 5 + ((skill - 40) / 10).round();
  return base.clamp(5, 15);
}
