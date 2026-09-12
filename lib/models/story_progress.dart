/// 主线剧情模式的数据模型与**纯函数**。
///
/// 【这个文件解决什么问题】
///
/// 离线模式此前是「一套去掉了所有剧情推进器官的回合循环」：它复用了 AI 路径的
/// 回合收尾（时间/精力/NPC/影响力/原著节点注入），却完全绕开了剧情上下文构建、
/// 伏笔回收、任务推进、记忆写入四大块。`canon_events.dart` 只做「每月往叙事尾巴
/// 贴一段旁白」，没有前因后果、没有分支、没有推进状态。
///
/// 本文件提供**剧情引擎的两半里可以直接单测的那一半**：
///   - 上半：`StoryEffect`/`StoryChoiceDef`/`StoryStepDef`/… 全是 `const` 数据表
///     （内容写在 `lib/data/story_data.dart`），后六部填充只是"再加一张表"；
///   - 下半：`StoryProgress` 是运行态进度，走存档 `extra_data` 通道，
///     `fromJson(null)` 直接返回 [StoryProgress.inactive]，老存档天然兼容。
///
/// 运行时（`mixin_narrative.dart` 的 `_runStoryTurn`）只调用本文件的纯函数，
/// 逻辑与内容彻底分离——这是"跑通第一部之后，后面六部不用改逻辑代码"的前提。
///
/// 【为什么进度不进 Player / WorldState】
/// 那两个类的 `fromJson` 一旦加字段，所有历史存档都要考虑迁移；而
/// `_saveExtraData()` / 读档处的 `extra_data` 通道本就是"扩展字段收纳口"，
/// 新增 key 读不到就走默认值，**零迁移风险**。
///
/// 【平行世界原则】玩家是**原创角色**，不扮演哈利。剧情步的 `setup` 可以写
/// 「你也在禁林里」「你看见有人俯身饮下独角兽的血」，但不能写「你杀死了蛇怪」
/// 「你是救世主」。这条约束由 `test/canon_story_parallel_test.dart` 扫描守住。
library;

// ================================================================
// 一、数据层（const 表）
// ================================================================

/// 一步剧情里「一个选择」造成的数值与状态变化。
///
/// 【为什么用声明式效果而不是给每步写个函数】
/// 后六部的内容填充如果每步都要写代码，就不可能"只填数据"。
/// 把效果收敛成一张字段表之后，`_applyStoryEffect` 只需写一次。
class StoryEffect {
  /// NPC 好感增量（作用对象见 [targetNpcId]）。
  final int affection;

  /// 玩家个人声望增量。
  final int reputation;

  /// 学院分增量（可为负：扣分也是剧情的一部分）。
  final int housePoints;

  /// 精神增量。
  final int spirit;

  /// 加隆增量。
  final int galleons;

  /// 获得物品 id（写入 `Player.inventory`）。
  final List<String> addItems;

  /// 获得情报——与 [setFlags] 的区别是语义：
  /// 情报是"你知道了某件事"（会写进长期记忆，影响后续叙事措辞），
  /// flag 是"某个开关被打开"（影响后续选项是否可见）。
  final List<String> addKnowledge;

  /// 置位的剧情 flag。
  final List<String> setFlags;

  /// 清除的剧情 flag。
  final List<String> clearFlags;

  /// 好感作用对象；null = 不加好感（只做数值/物品/flag 变化）。
  final String? targetNpcId;

  const StoryEffect({
    this.affection = 0,
    this.reputation = 0,
    this.housePoints = 0,
    this.spirit = 0,
    this.galleons = 0,
    this.addItems = const [],
    this.addKnowledge = const [],
    this.setFlags = const [],
    this.clearFlags = const [],
    this.targetNpcId,
  });

  /// 无任何变化（用于"自由行动"降级路径与过场步）。
  static const StoryEffect none = StoryEffect();

  /// 是否不产生任何变化（测试与调试用）。
  bool get isEmpty =>
      affection == 0 &&
      reputation == 0 &&
      housePoints == 0 &&
      spirit == 0 &&
      galleons == 0 &&
      addItems.isEmpty &&
      addKnowledge.isEmpty &&
      setFlags.isEmpty &&
      clearFlags.isEmpty;
}

/// 一个剧情分支（= 一个分支点的一条出路）。
class StoryChoiceDef {
  /// 步内唯一的分支 id（如 `'a1'`）。会被编码进 `GameChoice.action`。
  final String id;

  /// 玩家看到的按钮文案。
  final String text;

  /// 选完之后叙事里写出来的"你做了什么"。
  ///
  /// 这段文本是剧情推进的**可见证据**：没有它，玩家点完选项只会看到数值变化，
  /// 却读不到自己的行动如何改变了处境。
  final String consequence;

  /// 跳转到哪一步；空串 = 顺延到当前章的下一个未完成步（或下一章首步）。
  ///
  /// 用空串而不是 null，是因为 `const` 表里写 `''` 比写 `null` 更能表达
  /// "此处故意不指定"，且能避免忘记判空的调用方踩到 NPE。
  final String nextStepId;

  final StoryEffect effect;

  /// 非空时，需要持有该 flag 才显示此选项。
  ///
  /// 用途：前面章节获得的情报会解锁后面章节的专属出路。
  /// **注意**：过滤后如果一条都不剩，[availableStoryChoices] 会退回全部选项，
  /// 绝不让玩家面对一个空的选择界面。
  final String? requireFlag;

  const StoryChoiceDef({
    required this.id,
    required this.text,
    required this.consequence,
    this.nextStepId = '',
    this.effect = StoryEffect.none,
    this.requireFlag,
  });
}

/// 一步剧情（= 一章里的一个节拍）。
class StoryStepDef {
  /// 全局唯一步 id（如 `'ps_ch1_letter'`）。
  final String id;

  /// 所属章 id。
  final String chapterId;

  /// [层1 情境层] 本步开场情境描写。
  final String setup;

  /// [层3 世界层] 可选的环境氛围句池（按 [StoryProgress.stepTurnSeed] 轮转）。
  final List<String> ambient;

  /// 本步的分支点（2-4 个）。
  final List<StoryChoiceDef> choices;

  /// 对应的原著节点 id（`canon_events.dart` 里的 `CanonEvent.id`）。
  ///
  /// 非空时，剧情模式下这条原著节点由**剧情文本讲述**，不再额外贴 `📖` 块——
  /// 但 `firedAnchorIds` 仍会写入，防止玩家退出剧情模式后二次触发。
  final String? canonRefId;

  /// 本章节拍式时间推进（天）。
  ///
  /// 【为什么不用 `advanceTimeForAction` 的关键词推断】
  /// 剧情推动 8 章可能只跨几个月，而关键词推断会让"去图书馆查资料"直接推进
  /// 好几天，导致原著节点月份对不上。剧情模式用显式步长，时间才可控。
  /// `_finalizeTurn` 仍照常调用（NPC/影响力/断言结算不丢）。
  final int timeCostDays;

  /// 进入该步时的过场文本（可空）。
  final String? onEnterText;

  const StoryStepDef({
    required this.id,
    required this.chapterId,
    required this.setup,
    this.ambient = const [],
    required this.choices,
    this.canonRefId,
    this.timeCostDays = 1,
    this.onEnterText,
  });
}

/// 一章（= 一部里的一个大段落）。
class StoryChapterDef {
  final String id;

  /// 所属书 id（如 `'ps'`）。
  final String bookId;

  /// 章序（1 起）。
  final int ordinal;

  final String title;

  final List<StoryStepDef> steps;

  const StoryChapterDef({
    required this.id,
    required this.bookId,
    required this.ordinal,
    required this.title,
    required this.steps,
  });
}

/// 结局判定规则。
///
/// 【顺序即优先级】[resolveStoryEnding] 取**第一个**满足条件的规则，
/// 所以"特殊结局"必须排在"兜底结局"之前，否则永远轮不到。
class StoryEndingRule {
  final String id;
  final String title;
  final String body;

  /// 须**全部**持有的 flag。
  final List<String> requireFlags;

  /// 须**至少持有一个**的 flag（空 = 不限制）。
  final List<String> requireAnyFlags;

  /// 好感累计下限（null = 不限制）。
  final int? minAffectionTotal;

  /// 声望下限（null = 不限制）。
  final int? minReputation;

  const StoryEndingRule({
    required this.id,
    required this.title,
    required this.body,
    this.requireFlags = const [],
    this.requireAnyFlags = const [],
    this.minAffectionTotal,
    this.minReputation,
  });

  /// 本规则是否被 [progress] 满足。
  bool matches(StoryProgress progress) {
    for (final f in requireFlags) {
      if (!progress.flags.contains(f)) return false;
    }
    if (requireAnyFlags.isNotEmpty &&
        !requireAnyFlags.any(progress.flags.contains)) {
      return false;
    }
    if (minAffectionTotal != null &&
        progress.totalAffection < minAffectionTotal!) {
      return false;
    }
    if (minReputation != null && progress.totalReputation < minReputation!) {
      return false;
    }
    return true;
  }
}

/// 一部书。
class StoryBookDef {
  /// `'ps'` / `'cos'` / `'poa'` / `'gof'` / `'ootp'` / `'hbp'` / `'dh'`。
  final String id;

  final String title;

  final List<StoryChapterDef> chapters;

  /// 结局规则（**顺序即优先级**，兜底规则放最后）。
  final List<StoryEndingRule> endings;

  const StoryBookDef({
    required this.id,
    required this.title,
    required this.chapters,
    this.endings = const [],
  });
}

// ================================================================
// 二、运行态进度（进存档 extra_data）
// ================================================================

/// 剧情进度游标。
///
/// 【老存档兼容的关键】[fromJson] 收到 `null`（老存档 `extra_data` 里没有
/// 这个 key）时返回 [inactive]，于是所有既有存档读进来都是"非剧情模式"，
/// 行为与加这个功能之前逐字节一致。
class StoryProgress {
  /// 是否处于主线剧情模式。
  final bool active;

  final String bookId;
  final String chapterId;
  final String stepId;

  /// 已完成的步 id（用于"顺延到下一个未完成步"）。
  final List<String> doneSteps;

  /// 剧情 flag。
  final List<String> flags;

  /// 分支选择记录 `stepId → choiceId`（用于回顾与调试）。
  final Map<String, String> chosen;

  /// 累计数值效果 `key → value`。**必须持久化**：结局判定要读它，
  /// 而结算是跨存档累计的（不像 `Player` 上的实时数值会被剧情外行为改写）。
  final Map<String, int> effects;

  /// 非空 = 本局已到达结局（到达后不再推进剧情）。
  final String? endingId;

  /// 已获得的情报（写进长期记忆 + 用于 `_composeCausalText` 的因果过渡句）。
  final List<String> knowledge;

  /// 本步内的回合计数种子，用于 [ambient] 池轮转。
  final int stepTurnSeed;

  const StoryProgress({
    required this.active,
    this.bookId = 'ps',
    this.chapterId = '',
    this.stepId = '',
    this.doneSteps = const [],
    this.flags = const [],
    this.chosen = const {},
    this.effects = const {},
    this.endingId,
    this.knowledge = const [],
    this.stepTurnSeed = 0,
  });

  /// 非剧情模式（默认值 / 老存档读出来的值）。
  static const StoryProgress inactive = StoryProgress(active: false);

  /// 累计好感（结局判定用）。
  int get totalAffection => effects['affection'] ?? 0;

  /// 累计声望。
  int get totalReputation => effects['reputation'] ?? 0;

  /// 累计学院分。
  int get totalHousePoints => effects['housePoints'] ?? 0;

  bool get isFinished => endingId != null;

  Map<String, dynamic> toJson() => {
    'active': active,
    'book_id': bookId,
    'chapter_id': chapterId,
    'step_id': stepId,
    'done_steps': doneSteps,
    'flags': flags,
    'chosen': chosen,
    'effects': effects,
    if (endingId != null) 'ending_id': endingId,
    'knowledge': knowledge,
    'step_turn_seed': stepTurnSeed,
  };

  /// 从存档读取。`null` / 类型不对 / 缺字段一律安全降级为 [inactive]。
  ///
  /// 【为什么容错写得这么宽】存档可能来自任何历史版本，甚至被手改过。
  /// 一个字段解析失败就让整局游戏打不开，代价远大于"这一局回到非剧情模式"。
  factory StoryProgress.fromJson(Map<String, dynamic>? json) {
    if (json == null) return inactive;
    if (json['active'] != true) return inactive;
    return StoryProgress(
      active: true,
      bookId: json['book_id'] as String? ?? 'ps',
      chapterId: json['chapter_id'] as String? ?? '',
      stepId: json['step_id'] as String? ?? '',
      doneSteps: (json['done_steps'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      flags:
          (json['flags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      chosen: (json['chosen'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          const {},
      effects: (json['effects'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v is int ? v : int.tryParse('$v') ?? 0),
          ) ??
          const {},
      endingId: json['ending_id'] as String?,
      knowledge:
          (json['knowledge'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      stepTurnSeed: json['step_turn_seed'] as int? ?? 0,
    );
  }

  StoryProgress copyWith({
    bool? active,
    String? bookId,
    String? chapterId,
    String? stepId,
    List<String>? doneSteps,
    List<String>? flags,
    Map<String, String>? chosen,
    Map<String, int>? effects,
    String? endingId,
    List<String>? knowledge,
    int? stepTurnSeed,
  }) => StoryProgress(
    active: active ?? this.active,
    bookId: bookId ?? this.bookId,
    chapterId: chapterId ?? this.chapterId,
    stepId: stepId ?? this.stepId,
    doneSteps: doneSteps ?? this.doneSteps,
    flags: flags ?? this.flags,
    chosen: chosen ?? this.chosen,
    effects: effects ?? this.effects,
    endingId: endingId ?? this.endingId,
    knowledge: knowledge ?? this.knowledge,
    stepTurnSeed: stepTurnSeed ?? this.stepTurnSeed,
  );
}

// ================================================================
// 三、action 编码 / 解析
// ================================================================

/// 剧情指令前缀。
///
/// 【为什么把分支 id 编码进 `action` 字符串】
/// `GameChoice` 只有 `text` + `action` 两个字段（`game_systems.dart:727`），
/// 存档也只序列化这两个（`mixin_systems.dart:2839`）。多出的字段会在读档时
/// **静默丢失**，于是玩家读档后点同一个按钮，走的分支变成"自由行动"。
/// 编码进 `action` 是唯一能穿过存档的通道。
const String kStoryActionPrefix = '@@story:';

/// 把分支选择编码成可穿过存档的 `action`。
String encodeStoryAction(String stepId, String choiceId) =>
    '$kStoryActionPrefix$stepId:$choiceId@@';

/// 解析出的剧情指令。
class StoryCommand {
  final String stepId;
  final String choiceId;

  const StoryCommand({required this.stepId, required this.choiceId});

  @override
  bool operator ==(Object other) =>
      other is StoryCommand &&
      other.stepId == stepId &&
      other.choiceId == choiceId;

  @override
  int get hashCode => Object.hash(stepId, choiceId);

  @override
  String toString() => 'StoryCommand($stepId/$choiceId)';
}

/// 解析剧情指令；不是剧情指令时返回 `null`。
///
/// 容错要点：
///   - 前后空白与大小写不影响识别；
///   - 缺少收尾 `@@` 也接受（有些输入路径会剥掉 `@` 结尾）；
///   - `choiceId` 里含 `:` 不影响（只按**第一个** `:` 切分）。
StoryCommand? parseStoryCommand(String action) {
  var a = action.trim();
  if (a.length < kStoryActionPrefix.length) return null;
  if (a.toLowerCase().indexOf(kStoryActionPrefix) != 0) return null;
  a = a.substring(kStoryActionPrefix.length);
  if (a.endsWith('@@')) a = a.substring(0, a.length - 2);
  final sep = a.indexOf(':');
  if (sep <= 0 || sep >= a.length - 1) return null;
  final stepId = a.substring(0, sep).trim();
  final choiceId = a.substring(sep + 1).trim();
  if (stepId.isEmpty || choiceId.isEmpty) return null;
  return StoryCommand(stepId: stepId, choiceId: choiceId);
}

/// 该 `action` 是否是一条剧情指令（UI 侧用它决定是否显示"剧情"标记）。
bool isStoryAction(String action) => parseStoryCommand(action) != null;

// ================================================================
// 四、纯函数（可单测、无副作用）
// ================================================================

/// 全部已注册的书（由 `story_data.dart` 在加载时填充，避免循环 import）。
///
/// 【为什么不直接把书表定义在这里】内容有 1000+ 行且会持续增长，
/// 放独立的 `lib/data/story_data.dart` 更清爽；而纯函数必须能遍历书表，
/// 又不能反向 import 数据文件（会造成 `models → data → models` 的循环）。
/// 用一个可注入的注册表解开这个环。
final Map<String, StoryBookDef> kStoryBooks = <String, StoryBookDef>{};

/// 注册一本书（`story_data.dart` 在文件末尾调用）。
void registerStoryBook(StoryBookDef book) {
  kStoryBooks[book.id] = book;
}

/// 第一部（每局的起点）。
const String kFirstStoryBookId = 'ps';

/// 按 bookId 取书；查不到返回 `null`。
StoryBookDef? findStoryBook(String bookId) => kStoryBooks[bookId];

/// 按 bookId + chapterId 取章；查不到返回 `null`。
StoryChapterDef? findStoryChapter(String bookId, String chapterId) {
  final book = kStoryBooks[bookId];
  if (book == null) return null;
  for (final c in book.chapters) {
    if (c.id == chapterId) return c;
  }
  return null;
}

/// 按 bookId + chapterId + stepId 三元组查步；查不到返回 `null`。
StoryStepDef? findStoryStep(
  String bookId,
  String chapterId,
  String stepId,
) {
  final chapter = findStoryChapter(bookId, chapterId);
  if (chapter == null) return null;
  for (final s in chapter.steps) {
    if (s.id == stepId) return s;
  }
  return null;
}

/// 全书唯一步 id 查步（跨章兜底；正常流程用三元组更快）。
StoryStepDef? findStoryStepAnywhere(String bookId, String stepId) {
  final book = kStoryBooks[bookId];
  if (book == null) return null;
  for (final c in book.chapters) {
    for (final s in c.steps) {
      if (s.id == stepId) return s;
    }
  }
  return null;
}

/// 当前步可选的分支（按 [StoryChoiceDef.requireFlag] 过滤）。
///
/// 【兜底规则很重要】过滤后一条都不剩时**退回全部选项**——
/// 玩家的 flag 状态可能与内容作者预期不一致（改过档、走过特殊分支），
/// 这时候让他面对一个空的选择列表等于卡死。
List<StoryChoiceDef> availableStoryChoices(
  StoryStepDef step,
  Set<String> flags,
) {
  final ok = step.choices
      .where((c) => c.requireFlag == null || flags.contains(c.requireFlag))
      .toList();
  return ok.isEmpty ? List<StoryChoiceDef>.from(step.choices) : ok;
}

/// 判定结局：按顺序返回第一个满足的规则。
///
/// 都不满足时返回末位规则（约定为兜底规则）；完全没有规则时返回 `null`。
StoryEndingRule? resolveStoryEnding(
  StoryBookDef book,
  StoryProgress progress,
) {
  if (book.endings.isEmpty) return null;
  for (final r in book.endings) {
    if (r.matches(progress)) return r;
  }
  return book.endings.last;
}

/// 按序取书里的下一章；没有下一章返回 `null`（= 本部结束）。
StoryChapterDef? nextStoryChapter(StoryBookDef book, String chapterId) {
  for (var i = 0; i < book.chapters.length; i++) {
    if (book.chapters[i].id == chapterId) {
      return i + 1 < book.chapters.length ? book.chapters[i + 1] : null;
    }
  }
  return null;
}

/// 取一部书的第一步（剧情模式入口）。
StoryStepDef? firstStepOfBook(String bookId) {
  final book = kStoryBooks[bookId];
  if (book == null || book.chapters.isEmpty) return null;
  final first = book.chapters.first;
  return first.steps.isEmpty ? null : first.steps.first;
}

/// 按开局场景定位剧情模式的**起始步**。
///
/// 【为什么需要这张映射】开局场景（`opening_scene_data.dart`）决定世界时钟
/// 的起点：`letter` 是 7 月 31 日在家、`diagon` 是 8 月 20 日对角巷、
/// `station`/`hall`/`eve` 已是 9 月 1 日。而剧情第一章从 7 月收信讲起——
/// 若 9 月开局还从第一章开始，玩家会「在站台上重新收到七月的信」，时间线
/// 直接倒流。这里把起始步对齐到玩家**真正所在的时间点**：
///   - letter → 第一章（信刚到手）
///   - diagon → 第二章（人已在对角巷）
///   - station → 第三章（刚穿过站台墙）
///   - hall / eve → 第四章分院之夜（渡湖已完成，分院在即）
///
/// 跳章的代价是跳过的章的物品/flag 拿不到（比如 diagon 开局没有
/// `knows_gringotts_rumor`）——可接受：那些本来就不是必经线。
/// 查不到步（书表未注册/内容被删）时回退 [firstStepOfBook]。
StoryStepDef? storyStartStepFor(String openingSceneId) {
  const byScene = <String, String>{
    'diagon': 'ps_ch2_arrival',
    'station': 'ps_ch3_platform',
    'hall': 'ps_ch4_sorting',
    'eve': 'ps_ch4_sorting',
  };
  final fallback = firstStepOfBook(kFirstStoryBookId);
  final stepId = byScene[openingSceneId];
  if (stepId == null) return fallback;
  return findStoryStepAnywhere(kFirstStoryBookId, stepId) ?? fallback;
}

/// 结构统计（测试用：防止某天有人误删整段内容）。
class StoryStats {
  final int bookCount;
  final int chapterCount;
  final int stepCount;
  final int choiceCount;

  const StoryStats({
    required this.bookCount,
    required this.chapterCount,
    required this.stepCount,
    required this.choiceCount,
  });
}

/// 汇总当前已注册的剧情规模。
StoryStats get storyStats {
  var chapters = 0;
  var steps = 0;
  var choices = 0;
  for (final b in kStoryBooks.values) {
    chapters += b.chapters.length;
    for (final c in b.chapters) {
      steps += c.steps.length;
      for (final s in c.steps) {
        choices += s.choices.length;
      }
    }
  }
  return StoryStats(
    bookCount: kStoryBooks.length,
    chapterCount: chapters,
    stepCount: steps,
    choiceCount: choices,
  );
}
