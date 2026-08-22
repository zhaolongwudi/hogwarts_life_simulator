/// 人生目标目录（融合版「目标系统」）
/// 玩家可通过 /目标 指令设定一条人生主线目标，AI 将据此牵引剧情走向，
/// 但玩家仍可自由行动——目标只是方向，不是强制任务。

/// 目标毕业条件（数值化）
/// 满足全部条件视为"目标达成"，影响毕业结局评价。
class GoalRequirement {
  /// 所需声望维度（academic/social/combat/moral/leadership/dark）
  final String? reputationDim;
  final int reputationMin;

  /// 所需属性（attributes key）
  final String? attributeKey;
  final int attributeMin;

  /// 所需最低加隆（含银行）
  final int wealthMin;

  /// 所需最低好感 NPC 数量（好感≥50）
  final int deepRelationsMin;

  /// 所需最低世界线变动率（0.0-1.0）
  final double worldLineMin;

  const GoalRequirement({
    this.reputationDim,
    this.reputationMin = 0,
    this.attributeKey,
    this.attributeMin = 0,
    this.wealthMin = 0,
    this.deepRelationsMin = 0,
    this.worldLineMin = 0.0,
  });
}

class LifeGoal {
  final String id;
  final String name;
  final String category; // 目标大类
  final String description;

  /// 注入给叙事 AI 的牵引提示（简短，节省 token）
  final String steeringHint;

  /// 毕业时的达成条件（数值化）
  final GoalRequirement requirement;

  const LifeGoal({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.steeringHint,
    this.requirement = const GoalRequirement(),
  });
}

const List<LifeGoal> lifeGoalCatalog = [
  LifeGoal(
    id: 'auror',
    name: '成为傲罗',
    category: '职业',
    description: '捍卫魔法界的正义，追捕黑巫师，成为传奇傲罗。',
    steeringHint: '主线倾向：追逐正义与战斗，偏向傲罗方向成长（黑魔法防御、战斗声望）。',
    requirement: GoalRequirement(
      reputationDim: 'combat',
      reputationMin: 60,
      attributeKey: 'dda',
      attributeMin: 75,
    ),
  ),
  LifeGoal(
    id: 'potion_master',
    name: '成为魔药大师',
    category: '职业',
    description: '精通魔药炼制，名震对角巷，成为一代魔药宗师。',
    steeringHint: '主线倾向：钻研魔药学，偏向魔药与学术声望方向。',
    requirement: GoalRequirement(
      reputationDim: 'academic',
      reputationMin: 60,
      attributeKey: 'potions',
      attributeMin: 80,
    ),
  ),
  LifeGoal(
    id: 'quidditch',
    name: '成为魁地奇职业球员',
    category: '职业',
    description: '横扫球场，为学院争光，最终登上职业魁地奇联赛。',
    steeringHint: '主线倾向：魁地奇、飞行与竞技，偏向运动与团队声望。',
    requirement: GoalRequirement(
      reputationDim: 'social',
      reputationMin: 50,
      attributeKey: 'flying',
      attributeMin: 80,
    ),
  ),
  LifeGoal(
    id: 'professor',
    name: '成为霍格沃茨教授',
    category: '职业',
    description: '回到母校，站上讲台，成为受学生敬仰的教授。',
    steeringHint: '主线倾向：钻研学术、教书育人，偏向学术与声望。',
    requirement: GoalRequirement(
      reputationDim: 'academic',
      reputationMin: 70,
      attributeKey: 'theory',
      attributeMin: 80,
    ),
  ),
  LifeGoal(
    id: 'minister',
    name: '成为魔法部部长',
    category: '权位',
    description: '从校园起步，步步高升，最终执掌整个魔法界。',
    steeringHint: '主线倾向：政治与权谋，偏向领导声望与社交声望。',
    requirement: GoalRequirement(
      reputationDim: 'leadership',
      reputationMin: 70,
      attributeKey: 'social',
      attributeMin: 75,
    ),
  ),
  LifeGoal(
    id: 'healer',
    name: '成为圣芒戈治疗师',
    category: '职业',
    description: '悬壶济世，在圣芒戈魔法伤病医院救死扶伤。',
    steeringHint: '主线倾向：草药、魔药与治疗魔法，偏向道德声望。',
    requirement: GoalRequirement(
      reputationDim: 'moral',
      reputationMin: 60,
      attributeKey: 'herbology',
      attributeMin: 70,
    ),
  ),
  LifeGoal(
    id: 'curse_breaker',
    name: '成为古灵阁解咒师',
    category: '职业',
    description: '破解古老咒语，探寻失落遗迹，成为顶尖解咒师。',
    steeringHint: '主线倾向：咒语、古迹探索与冒险，偏向战斗与学术声望。',
    requirement: GoalRequirement(
      reputationDim: 'combat',
      reputationMin: 50,
      attributeKey: 'spell_understanding',
      attributeMin: 75,
    ),
  ),
  LifeGoal(
    id: 'magizoologist',
    name: '成为神奇生物学家',
    category: '职业',
    description: '研究与保护神奇生物，成为纽特·斯卡曼德那样的传奇。',
    steeringHint: '主线倾向：与神奇生物结缘，偏向探索与道德声望。',
    requirement: GoalRequirement(
      reputationDim: 'moral',
      reputationMin: 50,
      attributeKey: 'observation',
      attributeMin: 70,
    ),
  ),
  LifeGoal(
    id: 'journalist',
    name: '成为《预言家日报》记者',
    category: '职业',
    description: '用羽毛笔记录时代，揭露真相，掌控舆论。',
    steeringHint: '主线倾向：观察、社交与信息搜集，偏向社交声望。',
    requirement: GoalRequirement(
      reputationDim: 'social',
      reputationMin: 60,
      attributeKey: 'observation',
      attributeMin: 70,
    ),
  ),
  LifeGoal(
    id: 'shop_owner',
    name: '成为对角巷店主',
    category: '事业',
    description: '经营一家自己的魔法商店，富甲一方。',
    steeringHint: '主线倾向：经商与积累财富，偏向社交声望与经济。',
    requirement: GoalRequirement(
      reputationDim: 'social',
      reputationMin: 50,
      wealthMin: 3000,
    ),
  ),
  LifeGoal(
    id: 'love',
    name: '与心爱之人相守',
    category: '情感',
    description: '在这段魔法人生里，找到并守护属于自己的爱。',
    steeringHint: '主线倾向：情感与羁绊，偏向恋爱与亲密关系发展。',
    requirement: GoalRequirement(
      reputationDim: 'moral',
      reputationMin: 40,
      deepRelationsMin: 1,
    ),
  ),
  LifeGoal(
    id: 'change_fate',
    name: '改写历史·改变命运',
    category: '使命',
    description: '利用你的选择影响世界线，改变某些注定的悲剧。',
    steeringHint: '主线倾向：干预关键事件、触动蝴蝶效应，偏向改变世界线。',
    requirement: GoalRequirement(
      worldLineMin: 0.3,
    ),
  ),
  LifeGoal(
    id: 'dark_power',
    name: '追求黑魔法的力量',
    category: '野心',
    description: '不择手段地追求力量，哪怕付出沉重代价。',
    steeringHint: '主线倾向：黑魔法、野心与代价，需体现黑魔法的长期后果。',
    requirement: GoalRequirement(
      reputationDim: 'dark',
      reputationMin: 60,
      attributeKey: 'dda',
      attributeMin: 70,
    ),
  ),
  LifeGoal(
    id: 'simple_life',
    name: '过平凡而幸福的生活',
    category: '人生',
    description: '不追逐宏大叙事，只求安然度过属于自己的魔法人生。',
    steeringHint: '主线倾向：日常、友情与内心的安宁，偏向平静细腻的叙事。',
    requirement: GoalRequirement(
      reputationDim: 'moral',
      reputationMin: 40,
      deepRelationsMin: 3,
    ),
  ),
];

LifeGoal? goalById(String id) {
  for (final g in lifeGoalCatalog) {
    if (g.id == id) return g;
  }
  return null;
}

LifeGoal? goalByName(String name) {
  for (final g in lifeGoalCatalog) {
    if (g.name == name) return g;
  }
  return null;
}