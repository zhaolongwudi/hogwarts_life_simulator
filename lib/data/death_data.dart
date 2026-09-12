/// NPC 的死亡：一件回不去的事
///
/// ## 现在的状况
///
/// `NPC.isAlive` 有字段、会存盘、到处都在过滤它——
/// 但**全项目没有任何一处会把它置为 false**。
///
/// 也就是说：NPC 永远不会死。
///
/// 连带失效的是一整套围绕"死亡"写好的东西：
///
///   · `mixin_narrative_continuity` 里有一道「死人复活」的检查
///     （isAlive=false 但叙事里写他活着说话），这道检查永远不触发；
///   · 关系列表、宿敌名册、场景上下文都在过滤 isAlive，
///     但那个过滤条件恒为真；
///   · 最后一年原著里那些人一个个倒下，而这个世界里没有人会死。
///
/// ## 判定的难处
///
/// 中文里"死"这个字到处都是，而且大多数时候不是说死：
///
///   · 「差点没命」「以为他要死了」——没死
///   · 「死一般的寂静」「死气沉沉」「笑死了」——跟死无关
///   · 「死亡圣器」「死神」「摄魂怪的吻」——专有名词
///
/// 所以这里分三层：先找死亡信号，再剔除这些说法，
/// 最后要求**指名道姓**——"有人死了"不知道是谁，不记。
///
/// ## 连锁反应
///
/// 一个人死了，最重的一笔不是他自己，是**他留下的那些没做完的事**。
///
/// 你答应过他的事，现在永远做不到了。那些 openLoops 会被标记为
/// dropped，并写一条记忆——玩家会在很久以后读到它。
///
/// 活着的人那边，反应按关系分档：至交会跟你更近
/// （共同失去一个人会把人拉近），而宿敌的账，人死了也就了了。

import '../models/long_term_memory.dart';

// ============================================================ 认出死亡

/// 死亡信号。
/// 收得刻意宽一些，宽了有下面两层兜底；窄了会漏掉真正的死亡。
final RegExp kDeathSignalRe = RegExp(
  r'(死了|死去|死亡|身亡|遇难|遇害|被杀|丧生|牺牲|咽气|断气|'
  r'再也没能|再也没有醒来|没能救回来|倒下后再没|停止了呼吸|'
  r'没了气息|没了心跳|尸体|遗体|双腿一蹬|永远地闭上)',
);

/// 这些说法里的"死"不是死。
final RegExp kDeathNotRe = RegExp(
  r'(死一般|死寂|死气沉沉|笑死|累死|吓死|急死|气死|疼死|忙死|'
  r'死亡圣器|死神|死尸|死囚|垂死挣扎|死不瞑目|死鸭子|装死|'
  r'半死|要死要活|死心|死路|死角|死守|死记硬背)',
);

/// 这些词出现就说明**没死成**——差一点、以为、像是。
final RegExp kDeathHedgeRe = RegExp(
  r'(差点|险些|几乎|差点儿|以为|要是|如果|仿佛|好像|像是|'
  r'再差一点|差点没|快要|险些就|好在|幸好|幸亏|幸而|救回|救了回来|'
  r'活了下来|活下来|撑了过来|挺了过来|捡回一条命)',
);

/// 从一段叙事里认出**谁**死了。
///
/// 必须在 [names] 里——只认这个世界里真有这么一号人，
/// 且要求是还活着的（已经死了的人不会再死一次）。
///
/// 返回 null 表示这一段里没有值得记录的死亡。
String? deathInNarrative(String text, Iterable<String> names) {
  if (text.isEmpty) return null;

  for (final m in kDeathSignalRe.allMatches(text)) {
    // 取死亡信号前后各 24 字作为上下文窗口——
    // 中文里主语常常离谓语很远（"倒在血泊里的那个总是笑的人，
    // 再也没有醒来"），窗口太小会认不出是谁。
    final start = m.start - 24 < 0 ? 0 : m.start - 24;
    final end = m.end + 24 > text.length ? text.length : m.end + 24;
    final window = text.substring(start, end);

    if (kDeathNotRe.hasMatch(window)) continue;
    if (kDeathHedgeRe.hasMatch(window)) continue;

    // 指名道姓：窗口里出现的最长的那个名字优先
    // （"德拉科"和"德拉科·马尔福"同时出现时取后者）
    String? hit;
    for (final n in names) {
      if (n.isEmpty) continue;
      if (!window.contains(n)) continue;
      if (hit == null || n.length > hit.length) hit = n;
    }
    if (hit != null) return hit;
  }
  return null;
}

/// 一场死亡的死因。够不上具体死因就返回 null，别硬编。
///
/// 这几个词会写进长期记忆和结局回望，所以要写得像人话。
final RegExp kDeathCauseRe = RegExp(
  r'(决斗|诅咒|魔咒|坠落|摔落|溺水|中毒|烧伤|咬伤|踩踏|'
  r'摄魂怪|巨怪|狼人|蛇怪|八眼巨蛛|炸药|爆炸|倒塌|车祸|'
  r'疾病|旧伤|过劳|自杀|他杀|谋杀|处决|战斗|战争)',
);

String? deathCauseIn(String text) {
  final m = kDeathCauseRe.firstMatch(text);
  return m?.group(1);
}

// ============================================================ 连锁反应

/// 活着的人对这场死亡的反应，按跟死者的关系分档。
///
/// 至交是**加分**而不是减分：共同失去一个人会把人拉近，
/// 这是最真实的那种反应。写成减分的话，"朋友死了"
/// 就变成了一个负面事件，那不是悲伤，那是惩罚。
class DeathRipple {
  final int minAffection;

  /// 对你的好感变化
  final int affectionDelta;

  /// 这一档的说法
  final String note;

  const DeathRipple({
    required this.minAffection,
    required this.affectionDelta,
    required this.note,
  });
}

/// 从高到低排列，取第一条命中。
const List<DeathRipple> kDeathRipples = [
  DeathRipple(minAffection: 70, affectionDelta: 8, note: '他失去了至交'),
  DeathRipple(minAffection: 50, affectionDelta: 5, note: '他失去了真正的朋友'),
  DeathRipple(minAffection: 30, affectionDelta: 2, note: '他失去了一个说得上的朋友'),
  DeathRipple(minAffection: -100, affectionDelta: 0, note: '他知道这个人'),
];

DeathRipple rippleFor(int affection) {
  for (final r in kDeathRipples) {
    if (affection >= r.minAffection) return r;
  }
  return kDeathRipples.last;
}

/// 一个人死后，他参与的、还没了结的事会变成什么样。
///
/// 这是整场死亡里最重的一笔：**你答应过他的事，永远做不到了。**
/// 那些 openLoops 会被标记为 dropped，并写一条记忆——
/// 玩家会在很久之后（结局回望里）读到它。
List<OpenLoopRecord> loopsBrokenByDeath(
  Iterable<OpenLoopRecord> loops,
  String npcId,
) {
  return loops
      .where((l) => l.status == 'open' && l.npcIds.contains(npcId))
      .toList(growable: false);
}

/// 写进长期记忆的那句。
///
/// 用第三人称、纯陈述——它要能跟几十条别的事实挤在一起，
/// 而且七年之后读起来还得是同一件事。
String deathFactFor(String name, String? cause) =>
    cause == null ? '$name 死了。' : '$name 死于$cause。';

/// 弹给玩家看的那句
String deathNoticeFor(String name, String? cause) => cause == null
    ? '💀 $name 死了。'
    : '💀 $name 死了——$cause。';

/// 没做完的事变成的那一句。
///
/// 这是整场死亡里最该被看见的东西，所以它单独成句，
/// 而且用的是"再也没机会"——不是"放弃了"。
String brokenPromiseFactFor(String promise) =>
    '你答应过$promise，但那个人已经死了，这件事永远做不到了。';

/// 宿敌的账，人死了也就了了。
///
/// 这句话带着一点空——你恨了七年的人没了，
/// 那七年突然没有地方放。
String rivalEndedFactFor(String name) =>
    '你和$name 之间那笔账，随着他的死一起没了。'
    '你恨过的那些年，现在没有地方放了。';
