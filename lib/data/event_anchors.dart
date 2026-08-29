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

import 'locations.dart';

class EventAnchor {
  final String id;

  /// 触发月份（1-12）
  final int month;

  /// 适用年级；null = 所有年级通用
  final int? grade;

  /// 适用时代；null = 所有时代通用
  final String? era;

  /// 排除的时代。用于「几乎所有时代都该发生，但某几个不该」的情况——
  /// 比如开学宴会上「邓布利多式校长致辞」：1892 年他还只是一年级新生，
  /// 2020 年他已逝世多年，这两个时代不能有。
  final List<String> excludedEras;

  /// 触发当日允许的时段（小时，闭区间）；均为null则不限制
  final int? minHour;
  final int? maxHour;

  /// 仅当当前位置包含该关键词时才允许触发；null则不限制
  final String? requiredLocation;

  /// 事件标题（用于通知与存档记录）
  final String title;

  /// 注入给叙事 AI 的锚点指令
  final String directive;

  const EventAnchor({
    required this.id,
    required this.month,
    this.grade,
    this.era,
    this.excludedEras = const [],
    this.minHour,
    this.maxHour,
    this.requiredLocation,
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
    minHour: 12, // 特快11点发车，抵达不会早于12点
    maxHour: 15, // 再晚就该写分院仪式了，不是"抵达"
    requiredLocation: '特快',
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
    // 尖叫棚屋是 1971 年为卢平建的（满月时关他用的），1892 年它还不存在。
    // 1971 年入学的那一届正好赶上它刚落成，传闻正是从那时候开始的。
    excludedEras: const ['dumbledore'],
    title: '第一次霍格莫德之行',
    directive:
        '安排三年级生的第一次霍格莫德周末：黄油啤酒、佐科笑话店、或关于尖叫棚屋的传闻。玩家与同伴的互动应体现当前关系状态。',
  ),

  // ==================== 四年级 ====================
  EventAnchor(
    id: 'g4_oct_tournament_rumor',
    month: 10,
    grade: 4,
    // 三强争霸赛 1792 年因死亡事故停办，直到 1994-95 学年才恢复。
    // harry_same 时代开局 1991 年，四年级正好是 1994 年——只有这个时代
    // 的玩家赶得上。其余时代（1892 / 1971 / 1976 / 2020）听到三强争霸赛
    // 传闻都是穿帮。
    era: 'harry_same',
    title: '校际赛事传闻',
    directive:
        '近期校园流传三强争霸赛即将恢复举办的传闻。描写学生们的猜测、跃跃欲试与畏惧。玩家可作为候选被讨论，但不应自动入选。',
  ),
  EventAnchor(
    id: 'g4_dec_yule',
    month: 12,
    grade: 4,
    // 圣诞舞会是三强争霸赛的配套活动，原著里只有 1994-95 那一届。
    // 和三强争霸赛传闻绑在同一个时代。
    era: 'harry_same',
    title: '圣诞舞会',
    directive:
        '圣诞舞会临近：邀请舞伴成为校园头等大事。描写玩家的舞伴抉择（可与其恋爱/暧昧状态联动）、礼服准备与舞会当晚的氛围。',
  ),

  EventAnchor(
    id: 'g4_jun_dark_lord_return',
    month: 6,
    grade: 4,
    // 1994-95 学年末：三强争霸赛的最后一个项目出了人命。
    // 只有 harry_same（1991 入学）的四年级赶得上。
    era: 'harry_same',
    title: '学期末的阴影',
    directive:
        '学年末的校园气氛骤然改变：有学生没能从校际赛事的最后一个项目回来，'
        '官方说法是"意外"，但走廊里流传着别的版本。教师们收紧了夜间巡逻，'
        '有几位教授的谈话在被人靠近时戛然而止。'
        '玩家应是**听闻者**而不是亲历者——他知道自己所在的这一年出了事，'
        '却未必知道究竟出了什么。让他从旁人的只言片语里拼出一角，'
        '拼不全才是这一年真正的滋味。',
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
    id: 'g5_oct_ministry_decree',
    month: 10,
    grade: 5,
    // 1995-96 学年：魔法部派高级调查员进驻霍格沃茨，连发教育令。
    era: 'harry_same',
    title: '新法令',
    directive:
        '魔法部派来的官员开始常驻学校，接连发布新法令：学生集会需要批准、'
        '课堂内容要接受审查、教授只能教"安全"的那一部分。'
        '描写那种"有人在盯着"的窒息感——告密被默许，'
        '私下议论要在走廊尽头压低声音，连眼神交换都要挑时机。'
        '玩家不必去对抗它：他只是要在这套规矩底下想办法过完这一年，'
        '而"想办法"本身就该是这一回合的戏。',
  ),
  EventAnchor(
    id: 'g5_dec_dementor_attack',
    month: 12,
    grade: 5,
    // 1995 年冬：摄魂怪出现在麻瓜聚居地，魔法部对外一口咬定"无事发生"。
    era: 'harry_same',
    title: '冬日里的恐惧',
    directive:
        '寒冷的季节里，恐惧有了具体的形状：有学生谈起一种让人发冷、'
        '把快乐抽走的东西，而官方口径对此矢口否认——报纸上写的是"无事发生"。'
        '描写校园里两派人互相说服不成的疲惫：一边拿报纸当证据，'
        '一边说"你没见过你不懂"。若玩家会守护神咒，可安排他勉强挡住一次；'
        '若不会，就让他真正害怕一次——害怕本身比战斗更值得写。',
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
    id: 'g6_oct_classmate_loss',
    month: 10,
    grade: 6,
    // 1996-97 学年：战争从报纸上的名词变成同学脸上的表情。
    era: 'harry_same',
    title: '身边的人出事了',
    directive:
        '战争从报纸上的名词变成了同学脸上的表情：某个平日里话很多的人'
        '突然安静了，某人的名字被从宿舍门牌上摘下，有人家里出事却说不出所以然。'
        '应具体落到玩家认识的人身上（优先取好感最高的几位之一），'
        '让他真切感到"这事离我不远了"。'
        '但不要让玩家去拯救谁——他能做的只有陪着、听着，或者什么也做不了。'
        '写不出办法的时候，就老老实实写那种无能为力。',
  ),
  EventAnchor(
    id: 'g6_feb_apparition',
    month: 2,
    grade: 6,
    title: '幻影显形课程',
    directive:
        '魔法部开设的幻影显形选修课开课：十二周课程、分体风险的笑话与恐惧。玩家可报名（需年满17岁，可视情况调整），描写练习过程。',
  ),

  EventAnchor(
    id: 'g6_jun_headmaster_fall',
    month: 6,
    grade: 6,
    // 1997 年 6 月：天文塔那一夜，邓布利多身亡，学年提前结束。
    era: 'harry_same',
    title: '塔楼那一夜',
    directive:
        '学年末的一个夜晚，城堡里发生了无法挽回的事：有人从塔楼坠落，'
        '那位在任校长不在了。第二天全校被要求保持安静，'
        '但走廊里全是压着嗓子的哭声和低语。'
        '描写玩家得知消息那一刻的反应（不在乎也是合理的反应，'
        '他未必喜欢过那个人），以及接下来的停课、提前放假、'
        '离校时那片反常的寂静。'
        '他不是事件的中心，只是站在人群里抬头看那座塔的人。',
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
    id: 'g7_oct_on_the_run',
    month: 10,
    grade: 7,
    // 1997-98 学年：食死徒掌控霍格沃茨，点名、通缉、逃亡。
    era: 'harry_same',
    title: '回不去的学校',
    directive:
        '新学年开始了，但不是所有人都能回到学校：有人退学、有人失踪、'
        '有人被通缉。城堡里进驻了陌生的成年人，点名制度变得严苛，'
        '学生之间开始互相打量——谁的名字会不会出现在明天的名单上。'
        '描写玩家在这一年里的处境（在校、躲藏或逃亡皆可，'
        '视其此前的选择与声望而定），以及"同学"这个词在这一年里'
        '变得多么不可靠：昨天还一起上课的人，今天可能不敢看你。',
  ),
  EventAnchor(
    id: 'g7_may_battle',
    month: 5,
    grade: 7,
    // 1998 年 5 月：霍格沃茨保卫战。与 g7_may_newts 同月，
    // 若本回合已经在写考试，就让战事先当背景音铺着，下一回合再正面写。
    era: 'harry_same',
    title: '城堡之下',
    directive:
        '终局来临：城堡被要求交出一个人，学生们被集中到一处，'
        '然后战争在校园里正面打响。'
        '描写混乱中的具体小事——谁把谁拉进了安全的地方、'
        '谁在这一夜之后再也找不到、以及玩家自己做了什么'
        '（战斗、护送他人、躲藏、或者仅仅是活下来，'
        '都应当被允许，且不作道德评判）。'
        '若本回合已经在处理 N.E.W.T. 考试，'
        '把战事压成背景音先行铺垫即可，正面冲突留到下一回合。',
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
    // 1892（dumbledore）时代邓布利多自己还是一年级新生，
    // 2020（post_war）时代他已逝世二十多年。这两个时代不能让「校长」致辞。
    excludedEras: const ['dumbledore', 'post_war'],
    directive:
        '开学宴会氛围：分院帽之歌、校长致辞、级长巡视。可安排校长致辞中的微妙暗示（致辞者须是当代在任校长）。',
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
  // ===== 3月：此前整月没有任何锚点，一整个月的游戏内时间都是空白 =====
  EventAnchor(
    id: 'common_mar_spring_thaw',
    month: 3,
    title: '三月·解冻',
    directive:
        '三月：积雪消融，禁林边缘开始出现活动迹象，温室里的魔法植物进入疯长期。'
        '可安排草药课相关的剧情，或学生在泥泞的场地上追打闹的轻松桥段。',
  ),
  EventAnchor(
    id: 'common_mar_midterm',
    month: 3,
    title: '学年中期考核',
    directive:
        '学年过半，教授们开始集中布置论文与随堂测验：图书馆一座难求，'
        '熬夜赶论文的学生、借笔记的人情往来。可安排与学业属性直接挂钩的剧情。',
  ),
  EventAnchor(
    id: 'common_mar_hogsmeade',
    month: 3,
    title: '霍格莫德周末',
    directive:
        '三月的霍格莫德周末：风大、路泥泞，但三把扫帚的热蜂蜜酒和蜂蜜公爵的糖果依然吸引人。'
        '可安排与好友结伴出行、送礼、或撞见不该撞见的事。',
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
///
/// [hourFrom] → [hour] 是这次时钟推进**经过**的时段，不是一个点。
/// 这一点很关键：睡觉一次推进 480 分钟、霍格莫德一日游 300 分钟，
/// 如果只看落地那一刻的小时数，窗口被整个跨过去的锚点就永远触发不了
/// （「11点发车→12-15点抵达」这种窗口，睡一觉直接从 11 点跨到 19 点）。
/// 跨天（[dayDelta] ≥ 1 或 hourFrom > hour）时视为经过了整天，不再卡时段。
List<EventAnchor> anchorsFor({
  required int month,
  required int grade,
  required String era,
  required Set<String> firedIds,
  int? hour,
  int? hourFrom,
  int dayDelta = 0,
  String? currentLocation,
}) {
  // 跨越整天 → 时段不再设限；否则取 [hourFrom, hour] 这段区间
  final bool spansWholeDay =
      dayDelta >= 1 || (hourFrom != null && hour != null && hourFrom > hour);
  final int? winFrom = spansWholeDay ? null : hourFrom;
  final int? winTo = spansWholeDay ? null : hour;

  final result = <EventAnchor>[];
  for (final a in eventAnchors) {
    if (a.month != month) continue;
    if (firedIds.contains(a.id)) continue;
    if (a.grade != null && a.grade != grade) continue;
    if (a.era != null && a.era != era) continue;
    if (a.excludedEras.contains(era)) continue;
    // 时段门槛：防止特快刚发车(10:45)就被要求描写"抵达霍格莫德"（正常应12-15点抵达）
    if (!_hourWindowHit(a, winFrom, winTo)) continue;
    // 位置门槛：锚点要求在特定场景才触发。
    // 走 locationMatches 而不是自己比子串：当前地点是归一化后的主名，约束
    // 词可能是这条目的别名（主名「霍格沃茨·场地」↔ 别名「黑湖」），裸子串
    // 两头都匹配不上，锚点会静默地一次都不触发。
    if (a.requiredLocation != null &&
        currentLocation != null &&
        !locationMatches(currentLocation, a.requiredLocation!)) continue;
    result.add(a);
  }
  return result;
}

/// 锚点的时段窗口 [minHour, maxHour] 是否与本次经过的 [from, to] 有交集。
///
/// [from]/[to] 为 null（跨天或调用方没给）时不做时段限制。
/// 只有一端给了就退化成原来的"单点判断"。
bool _hourWindowHit(EventAnchor a, int? from, int? to) {
  final int lo = a.minHour ?? 0;
  final int hi = a.maxHour ?? 23;
  if (from == null && to == null) return true;
  final int f = from ?? to!;
  final int t = to ?? from!;
  // 区间相交：窗口起点不晚于经过区间的终点，且窗口终点不早于区间起点
  return lo <= t && hi >= f;
}
