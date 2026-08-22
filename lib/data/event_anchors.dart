/// 手写事件锚点库（学年日历骨架）
///
/// 设计目的：对抗纯 AI 即兴生成的内容重复与漂移。
/// 这些锚点是"确定性骨架"——在正确的学年节点注入给叙事 AI，
/// AI 负责演绎细节，代码保证关键事件在正确时间发生。
///
/// 触发规则：
/// - common 锚点：每个学年对应月份触发一次（所有年级）
/// - grade 锚点：仅对应年级触发一次
/// - era 过滤：为空表示所有时代通用
/// - 已触发的锚点 id 记录在存档中，不会重复触发

class EventAnchor {
  final String id;

  /// 触发月份（1-12）
  final int month;

  /// 适用年级；null = 所有年级通用
  final int? grade;

  /// 适用时代；null = 所有时代通用
  final String? era;

  /// 事件标题（用于通知与存档记录）
  final String title;

  /// 注入给叙事 AI 的锚点指令
  final String directive;

  const EventAnchor({
    required this.id,
    required this.month,
    this.grade,
    this.era,
    required this.title,
    required this.directive,
  });
}

const List<EventAnchor> eventAnchors = [
  // ==================== 一年级 ====================
  EventAnchor(
    id: 'g1_sep_arrival',
    month: 9,
    grade: 1,
    title: '入学·霍格沃茨特快',
    directive:
        '本回合应自然带出：新生乘霍格沃茨特快抵达霍格莫德车站，乘船/马车初见城堡，大礼堂分院仪式临近。描写新生们的紧张与期待，以及老生重逢的热闹。若玩家尚未分院，可安排分院相关剧情推进。',
  ),
  EventAnchor(
    id: 'g1_oct_first_flight',
    month: 10,
    grade: 1,
    title: '第一节飞行课',
    directive:
        '近期应安排一年级生的第一节飞行课：扫帚的脾气、霍琦夫人的口令、有人逞强摔下扫帚的经典桥段。玩家可表现出天赋或笨拙，结果应与其 flying 属性相关。',
  ),
  EventAnchor(
    id: 'g1_dec_christmas',
    month: 12,
    grade: 1,
    title: '第一个圣诞节',
    directive:
        '圣诞节临近：大礼堂装饰巨型圣诞树，留校学生收到家里的礼物。描写玩家收到的第一份霍格沃茨圣诞礼物（可与其家庭背景相关），以及节日晚宴的温暖氛围。',
  ),
  EventAnchor(
    id: 'g1_apr_exams_prep',
    month: 4,
    grade: 1,
    title: '期末复习氛围',
    directive:
        '期末考试临近，图书馆和公共休息室挤满复习的一年级生。可安排玩家与朋友的复习互助、或与竞争对手的暗自较劲。',
  ),
  EventAnchor(
    id: 'g1_jun_first_year_end',
    month: 6,
    grade: 1,
    title: '一年级结业',
    directive:
        '一年级学年末：学院杯分数即将定格，年终宴会前各院紧张又期待。回顾玩家这一年的成长，让教授或同学对其变化做出具体评价。',
  ),

  // ==================== 二年级 ====================
  EventAnchor(
    id: 'g2_sep_return',
    month: 9,
    grade: 2,
    title: '二年级返校',
    directive:
        '二年级开学：玩家已是老生，可安排其向新生指路、或与老友重逢的桥段。选修课选择（占卜/算术占卜/保护神奇生物等）可作为剧情点。',
  ),
  EventAnchor(
    id: 'g2_feb_duelling',
    month: 2,
    grade: 2,
    title: '决斗俱乐部',
    directive:
        '近期可安排一场学生间的决斗俱乐部或私下决斗：规则、观众、胜负的代价。玩家可参与或旁观，结果应反映其战斗属性与已学魔咒。',
  ),
  EventAnchor(
    id: 'g2_may_quidditch_final',
    month: 5,
    grade: 2,
    title: '魁地奇赛季收官',
    directive:
        '魁地奇赛季进入最后阶段，学院杯争夺白热化。若玩家是球员，安排关键比赛；若不是，安排观赛与学院荣誉相关的剧情。',
  ),

  // ==================== 三年级 ====================
  EventAnchor(
    id: 'g3_sep_hogsmeade',
    month: 9,
    grade: 3,
    title: '霍格莫德许可',
    directive:
        '三年级生首次获得霍格莫德村周末访问权。描写第一次拿到许可表的兴奋、三把扫帚与蜂蜜公爵的诱惑，以及没拿到许可的同学的失落。',
  ),
  EventAnchor(
    id: 'g3_nov_first_hogsmeade_trip',
    month: 11,
    grade: 3,
    title: '第一次霍格莫德之行',
    directive:
        '安排三年级生的第一次霍格莫德周末：黄油啤酒、佐科笑话店、或关于尖叫棚屋的传闻。玩家与同伴的互动应体现当前关系状态。',
  ),

  // ==================== 四年级 ====================
  EventAnchor(
    id: 'g4_oct_tournament_rumor',
    month: 10,
    grade: 4,
    title: '校际赛事传闻',
    directive:
        '近期校园流传校际魔法赛事/三强争霸赛类大型活动的传闻（可视时代调整形式）。描写学生们的猜测、跃跃欲试与畏惧。玩家可作为候选被讨论，但不应自动入选。',
  ),
  EventAnchor(
    id: 'g4_dec_yule',
    month: 12,
    grade: 4,
    title: '圣诞舞会',
    directive:
        '圣诞舞会临近：邀请舞伴成为校园头等大事。描写玩家的舞伴抉择（可与其恋爱/暧昧状态联动）、礼服准备与舞会当晚的氛围。',
  ),

  // ==================== 五年级 ====================
  EventAnchor(
    id: 'g5_sep_owls_pressure',
    month: 9,
    grade: 5,
    title: 'O.W.L. 压力',
    directive:
        '五年级开学即笼罩在普通巫师等级考试（O.W.L.）压力下：教授反复强调考试重要性，职业咨询提上日程。描写玩家对未来的初步打算。',
  ),
  EventAnchor(
    id: 'g5_jan_career_counsel',
    month: 1,
    grade: 5,
    title: '职业咨询',
    directive:
        '安排五年级生的职业咨询：院长/教授与学生一对一讨论未来方向（傲罗、治疗师、解咒师等）。咨询内容应与玩家的人生目标和声望状态呼应。',
  ),
  EventAnchor(
    id: 'g5_jun_owls',
    month: 6,
    grade: 5,
    title: 'O.W.L. 考试',
    directive:
        'O.W.L. 考试周：笔试与实操的紧张氛围、考后的集体对答案。玩家的考试结果应与其属性、平时表现合理对应，不要全科优秀。',
  ),

  // ==================== 六年级 ====================
  EventAnchor(
    id: 'g6_sep_newt_start',
    month: 9,
    grade: 6,
    title: 'N.E.W.T. 阶段开始',
    directive:
        '六年级开始 N.E.W.T. 高阶课程：课程难度陡增，部分学生因 O.W.L. 成绩被拒于高阶班门外。描写玩家进入高阶课程的状态与新的竞争格局。',
  ),
  EventAnchor(
    id: 'g6_feb_apparition',
    month: 2,
    grade: 6,
    title: '幻影显形课程',
    directive:
        '魔法部开设的幻影显形选修课开课：十二周课程、分体风险的笑话与恐惧。玩家可报名（需年满17岁，可视情况调整），描写练习过程。',
  ),

  // ==================== 七年级 ====================
  EventAnchor(
    id: 'g7_sep_final_year',
    month: 9,
    grade: 7,
    title: '最后一年',
    directive:
        '七年级开学，"最后一年"的氛围弥漫：学生们讨论毕业去向，教授态度微妙变化。描写玩家对毕业后的打算（应与人生目标呼应）。',
  ),
  EventAnchor(
    id: 'g7_may_newts',
    month: 5,
    grade: 7,
    title: 'N.E.W.T. 考试',
    directive:
        'N.E.W.T. 终极考试周：七年学业的最终检验。描写考前状态、关键科目的发挥，以及考后"一切结束了"的复杂情绪。结果应与玩家属性合理对应。',
  ),
  EventAnchor(
    id: 'g7_jun_farewell',
    month: 6,
    grade: 7,
    title: '毕业季',
    directive:
        '毕业季：告别宴会、留言册、最后的霍格沃茨夜晚。安排玩家与最重要的人告别或约定未来。这是在校生活的收官节点，叙事应有分量。',
  ),

  // ==================== 全校通用（按月份） ====================
  EventAnchor(
    id: 'common_sep_feast',
    month: 9,
    title: '开学宴会',
    directive:
        '开学宴会氛围：分院帽之歌、校长致辞、级长巡视。可安排邓布利多式校长致辞中的微妙暗示。',
  ),
  EventAnchor(
    id: 'common_oct_halloween',
    month: 10,
    title: '万圣节宴会',
    directive:
        '万圣节宴会：活蝙蝠、南瓜灯、盛宴。霍格沃茨的万圣节历来不平静，可安排小骚动或传闻（不必每年都是大事件）。',
  ),
  EventAnchor(
    id: 'common_nov_quidditch_open',
    month: 11,
    title: '魁地奇赛季开幕',
    directive:
        '魁地奇赛季揭幕战临近：各院队伍训练、解说员准备、赌谁赢的校园小赌局。可安排玩家观赛或参赛相关剧情。',
  ),
  EventAnchor(
    id: 'common_feb_valentine',
    month: 2,
    title: '情人节',
    directive:
        '情人节氛围：匿名情书、小精灵送花（可视时代调整）、走廊里的八卦。可与玩家的好感/暧昧状态自然联动，但不强制恋爱剧情。',
  ),
  EventAnchor(
    id: 'common_apr_easter',
    month: 4,
    title: '复活节假期',
    directive:
        '复活节假期：留校学生的轻松时光，或回家学生的猫头鹰来信。学业压力与假期放松的平衡。',
  ),
  EventAnchor(
    id: 'common_jul_summer_start',
    month: 7,
    title: '暑假开始',
    directive:
        '学年结束，暑假开始：学生离校回家。描写玩家的暑假安排（回家/留校/旅行/打工），并自然引出暑假剧情线（家庭、对角巷、暑期奇遇）。',
  ),
  EventAnchor(
    id: 'common_aug_summer_letter',
    month: 8,
    title: '暑假尾声',
    directive:
        '暑假接近尾声：同学间的猫头鹰来信、新学期购物清单、对返校的期待或焦虑。可安排玩家与好友的暑期重聚或书信往来。',
  ),
];

/// 查找指定月份、年级、时代下应触发的锚点（排除已触发的）
List<EventAnchor> anchorsFor({
  required int month,
  required int grade,
  required String era,
  required Set<String> firedIds,
}) {
  final result = <EventAnchor>[];
  for (final a in eventAnchors) {
    if (a.month != month) continue;
    if (firedIds.contains(a.id)) continue;
    if (a.grade != null && a.grade != grade) continue;
    if (a.era != null && a.era != era) continue;
    result.add(a);
  }
  return result;
}
