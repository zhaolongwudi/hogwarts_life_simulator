/// 支线委托板数据：委托模板 + 进行中的委托记录。
/// type:
///   gather — 收集指定材料（禁林探险/图鉴掉落自动推进）
///   defeat — 击败指定生物（禁林战斗自动推进）
///   pet — 宠物羁绊达到目标值（宠物互动自动推进）
class QuestTemplate {
  final String id;
  final String title;
  final String desc;
  final String type;
  final String target; // 目标名称（材料名/生物名/「宠物羁绊」）
  final int targetCount;
  final int rewardGalleons;
  final int rewardHousePoints;
  final int minGrade;

  const QuestTemplate({
    required this.id,
    required this.title,
    required this.desc,
    required this.type,
    required this.target,
    required this.targetCount,
    this.rewardGalleons = 15,
    this.rewardHousePoints = 3,
    this.minGrade = 1,
  });
}

const List<QuestTemplate> kQuestTemplates = [
  QuestTemplate(
    id: 'q_unicorn_hair',
    title: '独角兽的尾毛',
    desc: '魔药课教授需要几缕独角兽尾毛做实验。去禁林碰碰运气吧。',
    type: 'gather',
    target: '独角兽毛',
    targetCount: 1,
    rewardGalleons: 25,
    rewardHousePoints: 5,
  ),
  QuestTemplate(
    id: 'q_spider_fang',
    title: '巨蛛的毒牙',
    desc: '校医院需要八眼巨蛛毒牙标本。危险，但报酬可观。',
    type: 'gather',
    target: '蛇的毒牙',
    targetCount: 1,
    rewardGalleons: 40,
    rewardHousePoints: 8,
    // 修复：八眼巨蛛危险度 4，需 3 年级才能在禁林遭遇（maxDanger 表）。
    // 旧值 2 会让二年级玩家接了委托却永远遇不到目标生物，形成死锁。
    minGrade: 3,
  ),
  QuestTemplate(
    id: 'q_dragon_blood',
    title: '龙血的诱惑',
    desc: '一位炼金师重金收购火龙血。想要这笔横财，先得活着回来。',
    type: 'gather',
    target: '龙血',
    targetCount: 1,
    rewardGalleons: 45,
    rewardHousePoints: 10,
    minGrade: 3,
  ),
  QuestTemplate(
    id: 'q_gnomes',
    title: '驱除菜园地精',
    desc: '菜园被地精挖得千疮百孔，霍格莫德的老巫师请你清理一下。',
    type: 'defeat',
    target: '地精',
    targetCount: 2,
    rewardGalleons: 20,
    rewardHousePoints: 4,
  ),
  QuestTemplate(
    id: 'q_troll',
    title: '巨怪警报',
    desc: '禁林边缘出现了巨怪的踪迹。霍格沃茨悬赏一名勇士去处理。',
    type: 'defeat',
    target: '巨怪',
    targetCount: 1,
    rewardGalleons: 50,
    rewardHousePoints: 10,
    minGrade: 2,
  ),
  QuestTemplate(
    id: 'q_pet_bond',
    title: '驯养伙伴',
    desc: '把你的宠物训练成默契的伙伴（羁绊达到 60）。',
    type: 'pet',
    target: '宠物羁绊',
    targetCount: 60,
    rewardGalleons: 15,
    rewardHousePoints: 5,
  ),
];

QuestTemplate? questTemplateById(String id) {
  for (final q in kQuestTemplates) {
    if (q.id == id) return q;
  }
  return null;
}

/// 进行中的委托记录（存档序列化）
class QuestRecord {
  final String templateId;
  String title;
  String desc;
  String type;
  String target;
  int targetCount;
  int progress;
  int rewardGalleons;
  int rewardHousePoints;
  String status; // active / completed
  int issuedWeek;

  QuestRecord({
    required this.templateId,
    required this.title,
    required this.desc,
    required this.type,
    required this.target,
    required this.targetCount,
    this.progress = 0,
    this.rewardGalleons = 15,
    this.rewardHousePoints = 3,
    this.status = 'active',
    this.issuedWeek = 1,
  });

  bool get isDone => progress >= targetCount;

  factory QuestRecord.fromTemplate(QuestTemplate t, {int week = 1}) => QuestRecord(
        templateId: t.id,
        title: t.title,
        desc: t.desc,
        type: t.type,
        target: t.target,
        targetCount: t.targetCount,
        rewardGalleons: t.rewardGalleons,
        rewardHousePoints: t.rewardHousePoints,
        issuedWeek: week,
      );

  Map<String, dynamic> toJson() => {
        'template_id': templateId,
        'title': title,
        'desc': desc,
        'type': type,
        'target': target,
        'target_count': targetCount,
        'progress': progress,
        'reward_galleons': rewardGalleons,
        'reward_house_points': rewardHousePoints,
        'status': status,
        'issued_week': issuedWeek,
      };

  factory QuestRecord.fromJson(Map<String, dynamic> json) => QuestRecord(
        templateId: json['template_id'] ?? '',
        title: json['title'] ?? '',
        desc: json['desc'] ?? '',
        type: json['type'] ?? 'gather',
        target: json['target'] ?? '',
        targetCount: json['target_count'] ?? 1,
        progress: json['progress'] ?? 0,
        rewardGalleons: json['reward_galleons'] ?? 15,
        rewardHousePoints: json['reward_house_points'] ?? 3,
        status: json['status'] ?? 'active',
        issuedWeek: json['issued_week'] ?? 1,
      );
}

/// 委托类型 → 中文名。
///
/// 之前 mixin_play 和 game_play_screens 各写了一份一模一样的
/// `_questTypeLabel` switch，改一个译名要改两个地方。
const Map<String, String> kQuestTypeLabels = {
  'gather': '收集',
  'defeat': '讨伐',
  'pet': '培养',
};

/// 委托类型 → 中文名，未知类型回落到「委托」。
String questTypeLabel(String type) => kQuestTypeLabels[type] ?? '委托';
