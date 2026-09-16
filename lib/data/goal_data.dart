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

// ==================== 短期目标系统（学年→学期→月度）====================

/// 短期目标层级
enum GoalTier { year, semester, month }

/// 短期目标定义
class SubGoal {
  final String id;
  final GoalTier tier;
  final String label;       // 目标标题
  final String description; // 目标描述

  /// 关联的人生目标 id（空字符串表示通用）
  final String relatedGoalId;

  /// 建议的 AI 注入提示
  final String steeringHint;

  const SubGoal({
    required this.id,
    required this.tier,
    required this.label,
    required this.description,
    this.relatedGoalId = '',
    this.steeringHint = '',
  });
}

/// 学年目标池（每学年抽取 1~2 个作为该学年的"记忆锚点"）
const List<SubGoal> yearGoalPool = [
  SubGoal(
    id: 'yr_first_friend',
    tier: GoalTier.year,
    label: '结交第一位挚友',
    description: '在这个学年里，找到一位真正信任的朋友。',
    steeringHint: '本学年主线：社交与友谊，安排一次与同学深入交流的机会。',
  ),
  SubGoal(
    id: 'yr_professor_favor',
    tier: GoalTier.year,
    label: '赢得一位教授的赏识',
    description: '让某位教授注意到你的特别之处。',
    steeringHint: '本学年主线：学术表现，安排一次课堂出彩或课后交流的机会。',
  ),
  SubGoal(
    id: 'yr_house_cup',
    tier: GoalTier.year,
    label: '为学院杯贡献力量',
    description: '为学院赢得加分，在学年末的学院杯上留下你的名字。',
    steeringHint: '本学年主线：学院荣誉，安排一次为学院争光的机会。',
  ),
  SubGoal(
    id: 'yr_skill_mastery',
    tier: GoalTier.year,
    label: '精通一门魔法技艺',
    description: '在某一门魔法课程上达到出类拔萃的水平。',
    steeringHint: '本学年主线：技艺精进，安排一次技艺突破或展示的机会。',
  ),
  SubGoal(
    id: 'yr_secret_discovery',
    tier: GoalTier.year,
    label: '发现一座城堡的秘密',
    description: '霍格沃茨藏着无数秘密——找到其中一个。',
    steeringHint: '本学年主线：探索与发现，安排一次探索城堡隐藏区域的机会。',
  ),
  SubGoal(
    id: 'yr_stand_up',
    tier: GoalTier.year,
    label: '在关键时刻挺身而出',
    description: '当有人需要帮助时，你没有退缩。',
    steeringHint: '本学年主线：勇气与担当，安排一次需要玩家做出道德抉择的场景。',
  ),
];

/// 学期目标池（每学期抽取 1 个）
const List<SubGoal> semesterGoalPool = [
  SubGoal(
    id: 'sem_exam_top',
    tier: GoalTier.semester,
    label: '期末考试冲进前十',
    description: '在期末考试中取得年级前十名的好成绩。',
    steeringHint: '本学期目标：考试冲刺，安排一次考前复习或辅导的机会。',
  ),
  SubGoal(
    id: 'sem_new_friend',
    tier: GoalTier.semester,
    label: '认识一位新朋友',
    description: '主动接触一位之前没说过话的同学。',
    steeringHint: '本学期目标：社交拓展，安排一次偶然相遇或合作的机会。',
  ),
  SubGoal(
    id: 'sem_quidditch_try',
    tier: GoalTier.semester,
    label: '尝试一次魁地奇',
    description: '不管打得好不好，先飞一次再说。',
    steeringHint: '本学期目标：运动体验，安排一次魁地奇训练或试训的机会。',
  ),
  SubGoal(
    id: 'sem_extra_credit',
    tier: GoalTier.semester,
    label: '完成一次额外学分任务',
    description: '接受一位教授布置的额外任务，证明你的能力。',
    steeringHint: '本学期目标：额外课业，安排一次教授委托任务的机会。',
  ),
  SubGoal(
    id: 'sem_explore_village',
    tier: GoalTier.semester,
    label: '探索霍格莫德村',
    description: '好好逛逛霍格莫德，发现一些有趣的小店或秘密。',
    steeringHint: '本学期目标：探索霍格莫德，安排一次周末去霍格莫德的机会。',
  ),
  SubGoal(
    id: 'sem_forbidden_forest',
    tier: GoalTier.semester,
    label: '禁林边缘走一遭',
    description: '壮着胆子，去禁林边上看一眼。',
    steeringHint: '本学期目标：禁林探险，安排一次靠近禁林的冒险机会。',
  ),
];

/// 月度目标池（每月抽取 1 个，作为"这个月我该做什么"的指引）
const List<SubGoal> monthGoalPool = [
  SubGoal(
    id: 'mon_read_book',
    tier: GoalTier.month,
    label: '读一本魔法书',
    description: '在图书馆找一本没读过的书，安静地读一个下午。',
    steeringHint: '本月提示：阅读与学习，安排一次图书馆场景。',
  ),
  SubGoal(
    id: 'mon_letter_home',
    tier: GoalTier.month,
    label: '给家里写一封信',
    description: '给家人寄一封猫头鹰信，说说在学校的生活。',
    steeringHint: '本月提示：家庭联系，安排一次写信或收家信的场景。',
  ),
  SubGoal(
    id: 'mon_practice_spell',
    tier: GoalTier.month,
    label: '练习一个新咒语',
    description: '找一个安静的角落，反复练习一个还没完全掌握的咒语。',
    steeringHint: '本月提示：咒语练习，安排一次独自练习咒语的机会。',
  ),
  SubGoal(
    id: 'mon_watch_quidditch',
    tier: GoalTier.month,
    label: '看一场魁地奇训练',
    description: '去球场看看，哪怕只是坐在看台上吹吹风。',
    steeringHint: '本月提示：魁地奇氛围，安排一次观看训练或比赛的机会。',
  ),
  SubGoal(
    id: 'mon_walk_lake',
    tier: GoalTier.month,
    label: '在黑湖边散步',
    description: '一个人绕着黑湖走一圈，想想最近发生的事。',
    steeringHint: '本月提示：独处与反思，安排一次安静散步的场景。',
  ),
  SubGoal(
    id: 'mon_tower_sunset',
    tier: GoalTier.month,
    label: '看一次日落',
    description: '爬到塔楼顶上，看一场城堡的日落。',
    steeringHint: '本月提示：风景与心境，安排一次登高望远的场景。',
  ),
  SubGoal(
    id: 'mon_help_classmate',
    tier: GoalTier.month,
    label: '帮助一位同学',
    description: '有人需要帮助——你不会视而不见。',
    steeringHint: '本月提示：善意与互助，安排一次主动帮助同学的机会。',
  ),
  SubGoal(
    id: 'mon_diary',
    tier: GoalTier.month,
    label: '写一篇日记',
    description: '把最近的心情写下来，有些话只能对自己说。',
    steeringHint: '本月提示：内心记录，安排一次独处写日记的场景。',
  ),
];

/// 根据学年号抽取学年目标
SubGoal selectYearGoal(int schoolYear, {int seed = 0}) {
  final index = (schoolYear - 1 + seed) % yearGoalPool.length;
  return yearGoalPool[index];
}

/// 根据学期号抽取学期目标
SubGoal selectSemesterGoal(int semesterIndex, {int seed = 0}) {
  final index = (semesterIndex + seed) % semesterGoalPool.length;
  return semesterGoalPool[index];
}

/// 根据月份抽取月度目标
SubGoal selectMonthGoal(int month, {int seed = 0}) {
  final index = (month - 1 + seed) % monthGoalPool.length;
  return monthGoalPool[index];
}