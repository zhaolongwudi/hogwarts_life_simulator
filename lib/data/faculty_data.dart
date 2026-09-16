import 'course_data.dart';

/// 毕业后留校任教
///
/// ## 为什么要做这个
///
/// 七年读完，`_onPlayerGraduated` 把 `graduated` 置真，然后——什么也没有了。
/// 在校时的每一天都有锚点、有课程、有学院杯、有宿敌、有恋爱线，
/// 毕业那一瞬间这些东西全部停摆，剩下的只有打工和 AI 自由发挥。
///
/// 而玩家用七年养起来的那张关系网（教授好感、学术声望、某几门课的熟练度）
/// 在毕业结算里被打印成一行统计，然后就再没人看过。
///
/// 留校任教是唯一能把这三者接上的出路：
/// **你教的那门课，是你七年里学得最好的那门；
/// 愿意推荐你的教授，是你七年里真正相处过的那几个人；
/// 而昔日同学变成同事之后，关系会往哪个方向走，是另一段故事。**
///
/// ## 门槛
///
/// 不是人人都能留校。学术声望、拿得出手的一门课、至少两位教授的点头、
/// 以及不能声名狼藉——四条同时满足才有邀请。
/// 达不到就老老实实去魔法部找工作，这也是一种结局。

/// 教职等级
enum FacultyRank {
  /// 未任教
  none,

  /// 助教：批改作业、带实习、给教授打下手
  assistant,

  /// 讲师：独立授课
  lecturer,

  /// 教授：正式教席
  professor,

  /// 院长：兼管一个学院
  headOfHouse,
}

class FacultyRankDef {
  final FacultyRank rank;
  final String id;

  /// 职称
  final String title;

  /// 晋升所需的服务年限
  final int minServiceYears;

  /// 晋升所需的学术声望
  final int minAcademic;

  /// 晋升所需的领导声望（只有院长要）
  final int minLeadership;

  /// 年薪（加隆）。毕业后的主要收入来源。
  final int annualPay;

  /// 职责描述：注入给叙事 AI，也是 /教职 里给玩家看的那句
  final String duty;

  const FacultyRankDef({
    required this.rank,
    required this.id,
    required this.title,
    required this.minServiceYears,
    required this.minAcademic,
    this.minLeadership = 0,
    required this.annualPay,
    required this.duty,
  });
}

const List<FacultyRankDef> kFacultyRanks = [
  FacultyRankDef(
    rank: FacultyRank.assistant,
    id: 'assistant',
    title: '助教',
    minServiceYears: 0,
    minAcademic: 0,
    annualPay: 400,
    duty: '批改作业、准备教具、在课上给主讲教授打下手。'
        '学生不一定记得你的名字，但会记得你批改的羊皮纸边上那行字。',
  ),
  FacultyRankDef(
    rank: FacultyRank.lecturer,
    id: 'lecturer',
    title: '讲师',
    minServiceYears: 2,
    minAcademic: 60,
    annualPay: 700,
    duty: '独立带课、出卷、坐镇考场。'
        '第一次独自站上讲台那天，你会在台下看见当年坐在那里的自己。',
  ),
  FacultyRankDef(
    rank: FacultyRank.professor,
    id: 'professor',
    title: '教授',
    minServiceYears: 5,
    minAcademic: 75,
    annualPay: 1200,
    duty: '正式教席，有自己的办公室与研究室。'
        '新生会在走廊里小声念你的名字，像你当年念别人那样。',
  ),
  FacultyRankDef(
    rank: FacultyRank.headOfHouse,
    id: 'head',
    title: '院长',
    minServiceYears: 8,
    minAcademic: 82,
    minLeadership: 65,
    annualPay: 1800,
    duty: '除教席之外，还管着一个学院的学生：'
        '他们的处分、他们的家长信、他们在深夜里闯的祸。'
        '你终于成了那个在开学宴会上念名单的人。',
  ),
];

FacultyRankDef rankDefFor(FacultyRank rank) =>
    kFacultyRanks.firstWhere((r) => r.rank == rank);

FacultyRankDef? rankDefById(String id) {
  for (final r in kFacultyRanks) {
    if (r.id == id) return r;
  }
  return null;
}

/// 学业属性 → 教席科目。
///
/// 从课程表反查，不手抄一份映射：手抄一份的话，课程表改了科目名
/// 这里不会跟着改，玩家会看到自己教一门学校里根本不存在的课。
/// 同一属性挂了多门课时（memory 同时是魔法史和古代如尼文研究）
/// 取排在前面的那门——课程表本来就是按学科主次排的。
/// 课程表里的年级后缀（「飞行课（一年级）」），当教席名时要去掉。
final RegExp _gradeSuffixRe = RegExp(r'（[^）]*）');

Map<String, String> subjectsByAttribute() {
  final out = <String, String>{};
  for (final c in allCourses()) {
    final name = c.name.replaceAll(_gradeSuffixRe, '').trim();
    out.putIfAbsent(c.attribute, () => name);
  }
  return out;
}

/// 从玩家的学业属性里挑出他最强的一门，返回（属性键, 学科名, 分数）。
///
/// 只认课程表里出现过的那些——情绪稳定、意志这类通用素质没有对应的教席，
/// 不能拿来当主科。
({String key, String subject, int score}) bestSubjectOf(
    Map<String, int> attributes) {
  final subjects = subjectsByAttribute();
  var key = 'spell_understanding';
  var score = -1;
  for (final e in subjects.entries) {
    final v = attributes[e.key] ?? 50;
    if (v > score) {
      score = v;
      key = e.key;
    }
  }
  return (key: key, subject: subjects[key]!, score: score);
}

/// 留校资格的判定门槛
const int kFacultyMinAcademic = 55;
const int kFacultyMinSubjectScore = 68;
const int kFacultyMinMoral = 35;
const int kFacultyMaxDark = 45;
const int kFacultyMinAllies = 2;
const int kFacultyAllyAffection = 45;

/// 走后门：学术够高、且有一位教授真正看重你时，起步直接给讲师
const int kFacultyFastTrackAcademic = 75;
const int kFacultyFastTrackAffection = 65;

/// 留校资格评估
class FacultyEligibility {
  final bool eligible;

  /// 逐条门槛（描述, 是否达标）。不达标时这就是"差在哪"的说明书。
  final List<(String, bool)> checks;

  /// 若被邀请，从哪个职级起步
  final FacultyRank startingRank;

  /// 任教科目（最强那门）
  final String subject;

  /// 愿意推荐你的教授名字
  final List<String> allies;

  const FacultyEligibility({
    required this.eligible,
    required this.checks,
    required this.startingRank,
    required this.subject,
    required this.allies,
  });

  /// 学术声望离门槛还差多少（已达标为 0）
  int get academicGap => _gapOf(0);
  int get subjectGap => _gapOf(1);
  int get moralGap => _gapOf(2);
  int get alliesGap => _gapOf(3);

  int _gapOf(int idx) {
    if (idx >= checks.length) return 0;
    final (label, ok) = checks[idx];
    if (ok) return 0;
    // 数量后面可能带单位（「当前 1 位，需 2 位」），不能直接期待逗号
    final m = RegExp(r'（当前 (-?\d+)[^，]*，需 (-?\d+)').firstMatch(label);
    if (m == null) return 0;
    final cur = int.tryParse(m.group(1)!) ?? 0;
    final need = int.tryParse(m.group(2)!) ?? 0;
    return need - cur;
  }
}

/// 评估留校资格。纯函数，输入全是玩家状态和 NPC 好感。
///
/// [teacherAffections] 是在职教授（grade == 0）的名字 → 好感 映射。
FacultyEligibility evaluateFacultyEligibility({
  required int academic,
  required int moral,
  required int dark,
  required Map<String, int> attributes,
  required Map<String, int> teacherAffections,
}) {
  final best = bestSubjectOf(attributes);
  final allies = teacherAffections.entries
      .where((e) => e.value >= kFacultyAllyAffection)
      .map((e) => e.key)
      .toList()
    ..sort((a, b) =>
        (teacherAffections[b] ?? 0).compareTo(teacherAffections[a] ?? 0));

  final checks = <(String, bool)>[
    ('学术声望（当前 $academic，需 $kFacultyMinAcademic）',
        academic >= kFacultyMinAcademic),
    ('「${best.subject}」熟练度（当前 ${best.score}，需 $kFacultyMinSubjectScore）',
        best.score >= kFacultyMinSubjectScore),
    ('道德声望（当前 $moral，需 $kFacultyMinMoral）', moral >= kFacultyMinMoral),
    ('愿意推荐你的教授（当前 ${allies.length} 位，需 $kFacultyMinAllies 位）',
        allies.length >= kFacultyMinAllies),
    ('黑魔法声望不高于 $kFacultyMaxDark（当前 $dark）', dark <= kFacultyMaxDark),
  ];

  final eligible = checks.every((c) => c.$2);

  // 走后门：学术够硬 + 有一位教授是真看重你，不用从助教熬起
  final fastTrack = academic >= kFacultyFastTrackAcademic &&
      teacherAffections.values.any((v) => v >= kFacultyFastTrackAffection);

  return FacultyEligibility(
    eligible: eligible,
    checks: checks,
    startingRank: eligible
        ? (fastTrack ? FacultyRank.lecturer : FacultyRank.assistant)
        : FacultyRank.none,
    subject: best.subject,
    allies: allies,
  );
}

/// 任教满一年后，是否够格升一级。
///
/// 返回 null 表示还没到时候（年限或声望不够）。
FacultyRankDef? promotionFor({
  required FacultyRank current,
  required int serviceYears,
  required int academic,
  required int leadership,
}) {
  final idx = kFacultyRanks.indexWhere((r) => r.rank == current);
  if (idx < 0 || idx >= kFacultyRanks.length - 1) return null;
  final next = kFacultyRanks[idx + 1];
  if (serviceYears < next.minServiceYears) return null;
  if (academic < next.minAcademic) return null;
  if (leadership < next.minLeadership) return null;
  return next;
}

/// 距离下一次晋升还差什么（供 /教职 显示）。
String promotionHintFor({
  required FacultyRank current,
  required int serviceYears,
  required int academic,
  required int leadership,
}) {
  final idx = kFacultyRanks.indexWhere((r) => r.rank == current);
  if (idx < 0) return '尚未任教。';
  if (idx >= kFacultyRanks.length - 1) return '已是院长，没有更高的教职了。';
  final next = kFacultyRanks[idx + 1];
  final gaps = <String>[];
  if (serviceYears < next.minServiceYears) {
    gaps.add('任教年限 ${next.minServiceYears - serviceYears} 年');
  }
  if (academic < next.minAcademic) {
    gaps.add('学术声望 ${next.minAcademic - academic}');
  }
  if (leadership < next.minLeadership) {
    gaps.add('领导声望 ${next.minLeadership - leadership}');
  }
  return gaps.isEmpty
      ? '已满足晋升「${next.title}」的全部条件。'
      : '距「${next.title}」还差：${gaps.join('、')}';
}

/// 解析 `/教职 接受` / `/教职 婉拒`，返回 true / false；
/// 不是这条指令则返回 null。
///
/// 带参数的走 processChoice 的结算分支（先记账再发给 AI），
/// 不带参数的走 /教职 查看面板。
bool? parseFacultyCommand(String command) {
  final m = RegExp(r'^/教职\s*(接受|答应|留下|婉拒|拒绝|离校)\s*$')
      .firstMatch(command.trim());
  if (m == null) return null;
  return const ['接受', '答应', '留下'].contains(m.group(1));
}

/// 接受 / 婉拒之后，交给叙事 AI 的那句玩家行动。
///
/// 必须是一句具体动作——只结算不续写的话，玩家点完「留下来教书」
/// 看到一段后果文本就断了，毕业后的第一天永远没人写。
String facultyActionLineFor(bool accept, String subject) => accept
    ? '我把行李搬回了城堡，留下来教$subject。'
    : '我婉拒了那封信，收拾行李离开了霍格沃茨。';

/// 留校邀请的措辞。
///
/// [headmasterName] 为当代在任校长；为空时用「校方」这个不指名道姓的说法，
/// 免得 1892 年（邓布利多自己还是新生）或 2020 年（他已逝世）出洋相。
String facultyOfferLineFor({
  required FacultyEligibility e,
  required String? headmasterName,
  required String playerName,
}) {
  final who = (headmasterName == null || headmasterName.isEmpty)
      ? '校方'
      : headmasterName;
  final rank = rankDefFor(e.startingRank);
  final allyText = e.allies.length <= 2
      ? e.allies.join('和')
      : '${e.allies.take(2).join('、')}等 ${e.allies.length} 位教授';
  return '$who在你离校前一天叫住了你。\n'
      '「$playerName，」他说，「「${e.subject}」这门课，'
      '${allyText}都跟我提过你。\n'
      '下学年如果还没想好去哪儿，可以留下来当${rank.title}。\n'
      '${rank.duty}\n'
      '年薪 ${rank.annualPay} 加隆。不用现在答复，'
      '但离校的船明天上午开。」';
}

/// 婉拒留校时的措辞
const String kFacultyDeclineLine = '你道了谢，把那封信收进箱子最底下。'
    '有些门一旦关上就不会再开第二次——但那是你自己的选择，'
    '你知道自己在选什么。';
