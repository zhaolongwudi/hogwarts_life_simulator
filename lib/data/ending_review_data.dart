/// 结局回望：毕业时把七年编成一篇能读的文章
///
/// ## 现在是什么样
///
/// 毕业结算（`_graduationSettlement`）给的是这样一屏：
///
/// ```
/// 【七年统计】
/// · 声望：学术42｜社交38｜战斗51｜道德60｜领导29
/// · 资产：1840 加隆
/// · 深厚羁绊：3 人
/// · 世界线变动率：12.4%
/// · 成就：17 / 93
/// ```
///
/// 数字全对，但读完之后你不知道这七年发生了什么。
/// 玩家花几十个小时走完的七年，最后一屏是一张成绩单——
/// 而这一屏是整个游戏**最该被好好做**的地方。
///
/// ## 要编成什么
///
/// 一篇分节的回顾。关键不在"写全"，而在**取舍**：
///
///   · **空的小节比没有小节更难受**。七年没交到朋友，
///     就不该出现「那些人」这一节——它会明晃晃地告诉你那里本来该有什么。
///     所以每一节都是**有内容才生成**。
///   · **不重复统计数字**。声望、资产、成就那些在结算上半屏已经有了，
///     这里要写的是**发生过的事**，不是数。
///   · **按时间讲，不按重要性讲**。重要性用来筛选哪些事够格进来，
///     排的时候按发生顺序——回忆不是按分量排序的。
///
/// ## 为什么分成"事实"和"编排"两步
///
/// `EndingFacts` 只是一堆数字的容器，不含任何判断。
/// 所有"够不够格进这一节""该用哪个说法"都在纯函数里，
/// 于是每一条取舍都能单独测——加进来的东西凭什么进来，
/// 被丢掉的东西为什么丢，都得有地方说得清。

import '../models/long_term_memory.dart';

/// 进「那些事」这一节的最低分量。
///
/// 8 分的门槛是这样定的：T0 开局事实是 9 分（但会被 category 排除），
/// 伏笔了结给 7 分，AI 从叙事里提取的普通事实在 5~7 分。
/// 卡在 8 意味着只有"这件事定义了我这七年"级别的东西能进来。
const int kReviewMinImportance = 8;

/// 一节里最多讲几件事。
/// 再多就不是"回望"了，是流水账。
const int kReviewMaxMoments = 6;

/// 最深的那几个人
const int kReviewMaxPeople = 3;

/// 还没了结的事，最多列几条
const int kReviewMaxOpenLoops = 3;

/// 什么样的羁绊算"深"
const int kDeepBondAffection = 50;

/// 七年里攒下的全部事实。
/// 这个类不含任何判断，只负责把散在各处的数据收拢到一起。
class EndingFacts {
  final String playerName;
  final String house;
  final String bloodLabel;

  final List<KeyFactRecord> keyFacts;
  final List<OpenLoopRecord> openLoops;
  final List<WorldEventRecord> worldEvents;

  /// 名字 → 好感
  final Map<String, int> affections;

  /// 名字 → 宿敌档位标签（已按严重程度排好）
  final List<(String, String)> rivals;

  /// 世界线变动率（0~1）
  final double worldLineDeviation;

  /// 被你改写过的事（来自 worldline_data 的 rewrittenEchoesOf）
  final List<String> rewrittenEchoes;

  /// 没改过的、你选择袖手旁观的关键节点
  final List<String> witnessedUnchanged;

  final int deepBonds;
  final bool wasFaculty;
  final int moral;
  final int combat;
  final int academic;
  final int dark;
  final int leadership;

  /// 伤疤清单（scar_data 的 Scar）。终章里会有一节「身上的痕迹」。
  final List<String> scars;

  const EndingFacts({
    required this.playerName,
    required this.house,
    required this.bloodLabel,
    required this.keyFacts,
    required this.openLoops,
    required this.worldEvents,
    required this.affections,
    required this.rivals,
    required this.worldLineDeviation,
    required this.rewrittenEchoes,
    required this.witnessedUnchanged,
    required this.deepBonds,
    required this.wasFaculty,
    required this.moral,
    required this.combat,
    required this.academic,
    required this.dark,
    required this.leadership,
    this.scars = const [],
  });
}

/// 够格进「那些事」的事实：分量够、不是开局就有的身份标签。
///
/// 排除 `identity` 是因为：T0 那批"你叫 XX、出生于 XX 年、血统是 XX"
/// 的重要性一律是 9，按分数排它们会霸占整节——
/// 但那是**开局就写在那里**的东西，不是这七年里发生的事。
List<KeyFactRecord> reviewableFacts(
  List<KeyFactRecord> facts, {
  int minImportance = kReviewMinImportance,
}) {
  final out = facts
      .where((f) => f.importance >= minImportance && f.category != 'identity')
      .toList();
  // 按时间讲，不按分量讲——回忆不是按重要性排序的
  out.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return out;
}

/// 去重：AI 会把同一件事换几种说法反复提取，
/// 这里按内容前 12 字认作同一件事（够长，不至于把"A 帮了 B"和"A 帮了 C"并掉）。
List<KeyFactRecord> dedupeFacts(List<KeyFactRecord> facts) {
  final seen = <String>{};
  final out = <KeyFactRecord>[];
  for (final f in facts) {
    final key = f.fact.length <= 12 ? f.fact : f.fact.substring(0, 12);
    if (!seen.add(key)) continue;
    out.add(f);
  }
  return out;
}

/// 还没了结的事，按分量排
List<OpenLoopRecord> lingeringLoops(
  List<OpenLoopRecord> loops, {
  int maxCount = kReviewMaxOpenLoops,
}) {
  final out = loops
      .where((l) => l.status == 'open' && l.importance >= 6)
      .toList()
    ..sort((a, b) => b.importance.compareTo(a.importance));
  return out.take(maxCount).toList(growable: false);
}

/// 最深的那几个人，按好感排
List<(String, int)> closestAllies(
  Map<String, int> affections, {
  int maxCount = kReviewMaxPeople,
  int minAffection = kDeepBondAffection,
}) {
  final out = affections.entries
      .where((e) => e.value >= minAffection)
      .map((e) => (e.key, e.value))
      .toList()
    ..sort((a, b) => b.$2.compareTo(a.$2));
  return out.take(maxCount).toList(growable: false);
}

/// 好感的几种说法。
/// 用分档而不是直接印数字——数字在结算上半屏已经看过了，
/// 这里要说清楚的是**那是一种什么样的关系**。
String bondLabel(int affection) {
  if (affection >= 90) return '生死之交';
  if (affection >= 70) return '至交';
  if (affection >= 50) return '真正的朋友';
  if (affection >= 30) return '说得上的朋友';
  return '点头之交';
}

/// 一句话定性。
///
/// 这是整篇回顾里唯一一处**评价**，也是最该慎重写的地方。
/// 它得是从数据里推出来的，不能是随机挑的好听话——
/// 一个道德 20、宿敌一堆的人，不该被说成"让人信赖"。
class EndingEpithet {
  final String text;

  /// 命中条件
  final bool Function(EndingFacts) test;

  const EndingEpithet(this.text, this.test);
}

/// 按顺序匹配，命中第一条就用它。
/// 顺序即优先级——越靠前的越特指。
final List<EndingEpithet> kEndingEpithets = [
  // 被黑暗吞没的人——框架2 §118 坏结局三：成为自己曾经害怕的人
  // 黑魔法声望压过道德底线的人，说什么别的都轻了
  EndingEpithet('一个最后被黑暗吞没的人',
      (f) => f.dark >= 70 && f.moral < 35),
  // 改写过世界的人，说什么别的都轻了
  EndingEpithet('一个动过世界的人', (f) => f.worldLineDeviation >= 0.40),
  EndingEpithet('一个在关键时刻站出来过的人',
      (f) => f.moral >= 70 && (f.combat >= 60 || f.leadership >= 60)),
  EndingEpithet('一个让人愿意把背后交给你的人',
      (f) => f.moral >= 65 && f.deepBonds >= 3),
  EndingEpithet('一个走过弯路、又自己走了回来的人',
      (f) => f.dark >= 45 && f.moral >= 50),
  EndingEpithet('一个不太服软的人', (f) => f.combat >= 65),
  EndingEpithet('一个在书里待得比在人群里久的人', (f) => f.academic >= 70),
  EndingEpithet('一个让别人愿意跟着走的人', (f) => f.leadership >= 65),
  EndingEpithet('一个别人记得住、但说不清为什么的人', (f) => f.deepBonds >= 2),
];

/// 兜底的那句。七年什么都没攒下也是一种结局，
/// 而且是最多人真正会走到的那一种——写得比别的更认真。
const String kEndingEpithetFallback =
    '一个平平常常念完七年的人。没有谁会为你立碑，'
    '但你认识的每一个人，都还记得你的名字。';

String epithetFor(EndingFacts facts) {
  for (final e in kEndingEpithets) {
    if (e.test(facts)) return e.text;
  }
  return kEndingEpithetFallback;
}

/// 一篇结局回望：若干个小节，有内容才会生成。
class EndingReview {
  final List<(String title, List<String> lines)> sections;

  const EndingReview(this.sections);

  bool get isEmpty => sections.isEmpty;
}

/// 编出这篇回顾。
///
/// 每一节都是**有内容才生成**——见文件头，空的小节比没有小节更难受。
EndingReview buildEndingReview(EndingFacts f) {
  final sections = <(String, List<String>)>[];

  // ——— 一、你是谁 ———
  // 这一节永远有：哪怕后面什么都空着，你总得知道自己念完了七年。
  sections.add((
    '你是谁',
    [
      '${f.playerName}。${f.house}。${f.bloodLabel}。',
      epithetFor(f),
    ],
  ));

  // ——— 一·五、身上的痕迹 ———
  // 伤疤是七年的印记：有伤疤说明你经历过什么，而且活了下来。
  if (f.scars.isNotEmpty) {
    sections.add((
      '身上的痕迹',
      [
        '那些没有愈合、也不该被忘记的印记：',
        ...f.scars.map((s) => '· $s'),
      ],
    ));
  }

  // ——— 二、那些人 ———
  final allies = closestAllies(f.affections);
  if (allies.isNotEmpty) {
    sections.add((
      '那些人',
      allies
          .map((a) => '· ${a.$1}　${bondLabel(a.$2)}')
          .toList(growable: false),
    ));
  }

  // 宿敌单独成一节，不跟朋友混在一起——
  // 这两种关系放在同一个列表里，两边都显得轻了。
  if (f.rivals.isNotEmpty) {
    sections.add((
      '那些没解开的事',
      f.rivals
          .take(kReviewMaxPeople)
          .map((r) => '· ${r.$1}　${r.$2}')
          .toList(growable: false),
    ));
  }

  // ——— 三、那些事 ———
  final moments = dedupeFacts(reviewableFacts(f.keyFacts))
      .take(kReviewMaxMoments)
      .toList(growable: false);
  if (moments.isNotEmpty) {
    sections.add((
      '那些事',
      moments.map((m) => '· ${m.fact}').toList(growable: false),
    ));
  }

  // ——— 四、你动过的世界 ———
  if (f.rewrittenEchoes.isNotEmpty) {
    // 这一节的标题要跟上面"那些事"区分开：
    // 那是发生在你身上的事，这是**因为你才变成这样**的世界。
    sections.add((
      '被你改写过的事',
      f.rewrittenEchoes.map((e) => '· $e').toList(growable: false),
    ));
  } else if (f.witnessedUnchanged.isNotEmpty) {
    sections.add((
      '你看着它发生的',
      f.witnessedUnchanged.map((e) => '· $e').toList(growable: false),
    ));
  }

  // ——— 五、放不下的事 ———
  final loops = lingeringLoops(f.openLoops);
  if (loops.isNotEmpty) {
    sections.add((
      '还没了结的',
      loops.map((l) => '· ${l.description}').toList(growable: false),
    ));
  }

  return EndingReview(sections);
}

/// 把一篇回望渲染成一段文本。
String formatEndingReview(EndingReview review) {
  if (review.isEmpty) return '';
  final buf = StringBuffer()
    ..writeln('── 回望这七年 ──')
    ..writeln();
  for (final (title, lines) in review.sections) {
    buf.writeln('【$title】');
    for (final l in lines) {
      buf.writeln(l);
    }
    buf.writeln();
  }
  return buf.toString().trimRight();
}
