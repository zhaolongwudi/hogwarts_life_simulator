/// 伏笔的闭环与回响
///
/// ## 为什么会有这个文件
///
/// 伏笔（`OpenLoopRecord`）在这套系统里是**只增不减**的：
/// AI 每回合从叙事摘要里提取【伏笔】写进 `openLoops`，状态一律是 `open`，
/// 而全项目**没有任何一处**会把 AI 提取的伏笔置为 `done`
/// ——唯一的 `status: 'done'` 在委托交付里（`loopType: 'quest'`）。
///
/// 后果是三重的，而且每一重都比"缺个奖励"严重：
///
///   1. **伏笔永远收不回来。** 玩家从头到尾看不到任何一件悬着的事被了结。
///   2. **容量是假的。** 100 条满了之后按 `(open?1000:0) + importance` 排序挤掉
///      最早的——因为全是 open + importance 6，等于按插入顺序丢。
///      于是「别忘了这些重要伏笔」那条提醒，会一直念着早就没了的事。
///   3. **AI 被自己写过的话淹没。** T1 里堆着 40 条永远关不掉的事项，
///      真正的待办反而挤不进去。
///
/// 所以这里做的是两件事：**让伏笔能关**，以及**关掉的时候有回响**。
///
/// ## 匹配为什么用重合度而不是哈希
///
/// 伏笔是 AI 用自然语言写的，了结它的那段话也是 AI 写的，
/// 两者措辞几乎不可能一字不差（"答应保密" → "最终替他保守了秘密"），
/// 所以创建时那个 `auto_loop_<hash>` 的 id 在这里完全用不上。
///
/// 这里改用**中文二字组（bigram）的重合度**：把两段文本都切成相邻两字的集合，
/// 用交集除以**较小**那一边的大小。
///
/// 不用 Jaccard（交/并）是因为了结文本通常比伏笔描述长，
/// 并集会把它稀释掉——"斯内普最终还是替主角保守了那个秘密"
/// 明明命中了"斯内普答应给主角保密"，分母一膨胀分数就被压没了。
/// 除以较小的一边，测的才是"短的那段有多少被覆盖"。
///
/// 中文里二字组比单字有区分度："斯内普的信" 和 "斯内普的坩埚"
/// 单字重合很高，二字组只剩一个「斯内」，会被正确判为不相关。
///
/// ## Batch 8 Issue #15：实体一致性放行通道
///
/// 纯 bigram 重合度有两个盲区：
///
///   1. **漏关**——两段措辞差异大但确实是同一件事（"小天狼星把活点地图
///      留给主角" → "主角靠着那张地图找到了密道"），bigram 覆盖太少被误杀；
///   2. **误关的孪生问题**——实体名不一致时（AI 换了叫法），比例被稀释。
///
/// 所以这里加一条**放行通道**：两段文本**同时命中 ≥ 2 个实体 token**
/// （NPC 全名/别名 + 物品名），就算 bigram 分数不够，也认为是同一件事。
/// 双命中门槛保证只靠撞一个人名（"斯内普的信" vs "斯内普的坩埚"）不会放行。
import '../models/long_term_memory.dart';
import 'npc_data.dart';
import 'item_data.dart';

/// 去掉标点、空白与数字，只留汉字与字母——标点是噪声，
/// 留着它会让两条毫不相关的文本因为都用了几个逗号而"变熟"。
final RegExp _noiseRe = RegExp(r'[\s，。、；：！？…—\-「」『』（）()《》〈〉\d]+');

/// 切成二字组。不足两字时退化为整串（否则短描述永远匹配不上）。
Set<String> bigramsOf(String text) {
  final t = text.replaceAll(_noiseRe, '');
  if (t.isEmpty) return const <String>{};
  if (t.length < 2) return <String>{t};
  final out = <String>{};
  for (var i = 0; i < t.length - 1; i++) {
    out.add(t.substring(i, i + 2));
  }
  return out;
}

/// 两段文本的重合度（0~1）。见文件头：除以较小的那一边，不是并集。
///
/// 注意这只是**比例**，单看它是不够的：两条都很短的文本很容易刷出高分
/// （"斯内普的信" 与 "斯内普的坩埚" 的比例高达 0.75，纯属撞了个人名）。
/// 真正的判定在 [isSameLoop]，它还要额外过一道绝对数量的门槛。
double loopMatchScore(String a, String b) {
  final m = _overlap(a, b);
  return m.ratio;
}

/// 一次比对的结果
typedef LoopOverlap = ({int shared, double ratio});

LoopOverlap _overlap(String a, String b) {
  final sa = bigramsOf(a);
  final sb = bigramsOf(b);
  if (sa.isEmpty || sb.isEmpty) return (shared: 0, ratio: 0.0);
  // 遍历小的那个集合，省一半
  final (small, large) = sa.length <= sb.length ? (sa, sb) : (sb, sa);
  var inter = 0;
  for (final g in small) {
    if (large.contains(g)) inter++;
  }
  return (shared: inter, ratio: inter / small.length);
}

/// 低于这个比例就不认为是同一件事。
///
/// 定在 0.30 是这样来的：措辞完全不同的同一件事（"答应保密" → "保守了秘密"）
/// 实测在 0.35 上下；而只是撞了个人名的两件事会掉到 0.3 以下。
/// 宁可漏关，不可错关——错关会让玩家眼看着一件还没办的事被系统宣布了结。
const double kLoopMatchThreshold = 0.30;

/// 重合的二字组至少要有这么多。
///
/// 光有比例会被短文本骗到（见 [loopMatchScore] 的注释），
/// 所以再卡一道绝对数量：4 个共同二字组意味着至少有 5 个连续的字
/// 或几段分散的两字是重合的，偶然撞上的概率就低了。
///
/// 这条门槛同时解释了为什么宁可漏关：「小天狼星留了一把钥匙」
/// 和「那把钥匙打开了尖叫棚屋的门」只有 2 个共同二字组，
/// 会被判为不相干——很可惜，但比误关一条还没做的事安全得多。
const int kLoopMatchMinShared = 4;

/// ## Batch 8 Issue #15：实体一致性放行通道
///
/// 纯 bigram 重合度的盲区是**措辞差异大的同一件事**会被漏关：
/// "小天狼星把活点地图留给主角" → "主角靠着那张地图找到了密道"，
/// 两者几乎不共享二字组，但显然是同一件事。
///
/// 这里用**实体 token 双命中**补一条放行通道：NPC 全名/别名 + 物品名
/// 同时出现在伏笔描述与了结文本里，就算 bigram 分数不够也放行。
/// 门槛是 **≥ 2 个不同实体**——只撞一个人名（"斯内普的信" vs "斯内普的坩埚"）
/// 不会放行，避免把两件不同的事误关成一件。

/// 构建实体 token 集：NPC 全名 + 别名 + 物品名。
///
/// 过滤规则：
///   - 长度 < 2 的 token 直接丢弃（单字无区分度）；
///   - 排除通用称谓（"教授""院长""管理员"等，见 [kLoopGenericEntityTokens]）；
///   - NPC 别名里混着"妹妹""叛徒"这类普通名词，不能当实体。
///     [story_text_renderer] 维护了一份 `_aliasesTooGeneric`，这里复用它。
///
/// 静态构建一次，运行时只读。
final Set<String> _entityTokens = _buildEntityTokens();
Set<String> _buildEntityTokens() {
  final out = <String>{};
  for (final npc in kAllNpcSeeds) {
    if (npc.name.length >= 2) out.add(npc.name);
    for (final a in npc.aliases) {
      if (a.length >= 2 && !kLoopGenericEntityTokens.contains(a)) out.add(a);
    }
  }
  for (final item in kItemCatalog) {
    if (item.name.length >= 2) out.add(item.name);
  }
  return out;
}

/// 通用称谓黑名单：这些词出现在别名里但不是实体（"教授""院长""管理员"…）。
/// 与 [story_text_renderer] 的 `_aliasesTooGeneric` 思路一致，独立维护以免循环依赖。
const Set<String> kLoopGenericEntityTokens = {
  '教授', '院长', '管理员', '看门人', '校医', '护士长', '级长',
  '追球手', '解说员', '妹妹', '叛徒', '教父', '双胞胎', '蝎子',
  '校长', '副校长', '院长助理',
};

/// 两段文本各自命中的实体 token 的交集（去重后）。
Set<String> sharedEntityTokens(String a, String b) {
  final inA = _entityTokens.where(a.contains).toSet();
  final inB = _entityTokens.where(b.contains).toSet();
  return inA.intersection(inB);
}

/// 这两段话说的是不是同一件事。
bool isSameLoop(
  String a,
  String b, {
  double threshold = kLoopMatchThreshold,
  int minShared = kLoopMatchMinShared,
  int minEntityShared = kLoopEntityMinShared,
}) {
  final ta = a.replaceAll(_noiseRe, '');
  final tb = b.replaceAll(_noiseRe, '');
  if (ta.isEmpty || tb.isEmpty) return false;
  // 捷径：AI 有时候会把伏笔原样复述一遍，那就没必要算相似度了。
  // 卡 6 个字是为了避免"钥匙"这种两字词被当成包含关系。
  if (ta.length >= 6 && tb.contains(ta)) return true;
  if (tb.length >= 6 && ta.contains(tb)) return true;

  // 实体双命中放行通道（Batch 8 Issue #15）。
  final sharedEntities = sharedEntityTokens(a, b);
  if (sharedEntities.length >= minEntityShared) return true;

  final m = _overlap(a, b);
  return m.shared >= minShared && m.ratio >= threshold;
}

/// 实体双命中放行的门槛：两段文本至少共享这么多个不同实体 token。
/// 2 个是为了「同一件事」的可信度——同一个 NPC 出现在两条伏笔里太常见了，
/// 但 NPC+物品/两个 NPC 同时对上，基本就是同一件事。
const int kLoopEntityMinShared = 2;

/// 一次匹配的结果
class LoopClosureMatch {
  final OpenLoopRecord loop;

  /// 匹配分数，越高越可信
  final double score;

  const LoopClosureMatch({required this.loop, required this.score});
}

/// 从候选伏笔里挑出最该被这段了结文本关掉的那条。
///
/// 只认 `status == 'open'` 的，且不会关掉刚刚才开的伏笔（< 2 回合）——
/// 那通常只是 AI 把同一件事换了个说法又写了一遍，不是了结。
///
/// 返回 null 表示没匹配上，**调用方应当安静地什么都不做**。
LoopClosureMatch? pickLoopToClose(
  String closedText,
  Iterable<OpenLoopRecord> candidates, {
  int currentTurn = 0,
  double threshold = kLoopMatchThreshold,
  int minAgeTurns = 2,
  int minEntityShared = kLoopEntityMinShared,
}) {
  final probe = bigramsOf(closedText);
  if (probe.isEmpty) return null;

  LoopClosureMatch? best;
  for (final l in candidates) {
    if (l.status != 'open') continue;
    if (l.openedTurn > 0 && currentTurn - l.openedTurn < minAgeTurns) continue;
    if (!isSameLoop(closedText, l.description,
        threshold: threshold, minEntityShared: minEntityShared)) {
      continue;
    }
    final score = loopMatchScore(closedText, l.description);
    if (best == null || score > best.score) {
      best = LoopClosureMatch(loop: l, score: score);
    }
  }
  return best;
}

/// 六种 loopType 对应的人类说法。
/// 不能让玩家在通知里看到 `promise` 这种内部键名。
const Map<String, String> kLoopTypeLabels = {
  'promise': '一个承诺',
  'debt': '一笔债务',
  'quest': '一项委托',
  'appointment': '一次约定',
  'question': '一个悬着的疑问',
  'grudge': '一笔旧账',
  'foreshadow': '一件悬着的事',
};

String loopTypeLabel(String? type) =>
    kLoopTypeLabels[type] ?? kLoopTypeLabels['foreshadow']!;

/// 了结一条伏笔的回报。
///
/// 数值刻意压得很低：这是**回响**，不是奖励。
/// 委托交付给的是 +2/+3 加隆与学院分（稀少、玩家主动去领），
/// 伏笔了结是 AI 自己写出来的，一局里可能有几十次，
/// 给多了七年下来声望就通货膨胀了。
class LoopReward {
  final Map<String, int> reputation;

  /// 涉及的 NPC 各加多少好感（0 表示不加）
  final int npcAffection;

  const LoopReward({this.reputation = const {}, this.npcAffection = 0});

  const LoopReward.none() : reputation = const {}, npcAffection = 0;
}

const Map<String, LoopReward> kLoopRewards = {
  // 说到做到，主要记在别人眼里
  'promise': LoopReward(reputation: {'moral': 2, 'social': 1}, npcAffection: 2),
  // 还清了，债主会替你说话
  'debt': LoopReward(reputation: {'social': 2}, npcAffection: 3),
  // 委托有自己的一套奖励（加隆/学院分/声望），这里不重复发
  'quest': LoopReward.none(),
  'appointment': LoopReward(reputation: {'social': 2}, npcAffection: 2),
  // 一个悬着的疑问有了答案，算在自己头上
  'question': LoopReward(reputation: {'academic': 2}),
  'grudge': LoopReward(reputation: {'moral': 1, 'social': 1}),
  // AI 提取的伏笔默认落在这类，给一个"有始有终"的泛化回报
  'foreshadow': LoopReward(reputation: {'moral': 1}),
};

LoopReward rewardForLoop(String? type) =>
    kLoopRewards[type] ?? kLoopRewards['foreshadow']!;

/// 写进长期记忆的那句话。
///
/// 用「终于」而不是「完成了」——前者带着这段时间的重量，
/// 后者听起来像清掉了一条待办。
String loopClosedFact(String description, String? type) =>
    '你了结了${loopTypeLabel(type)}：${_trimTo(description, 60)}。';

/// 弹给玩家看的那句通知。
///
/// 带上"悬了多少回合"是因为**只有把它说出来，等待才有意义**——
/// 一条悬了 40 回合才了结的事和下一回合就了结的，不是同一件事。
String loopClosedNotice(String description, String? type, int turnsHeld) {
  final held = turnsHeld > 0 ? '（悬了 $turnsHeld 回合）' : '';
  return '🔗 了结${loopTypeLabel(type)}：${_trimTo(description, 40)}$held';
}

String _trimTo(String s, int max) =>
    s.length <= max ? s : '${s.substring(0, max)}…';

/// 悬太久又没什么分量的伏笔，该放下了。
///
/// 玩家显然已经放弃了这些事，AI 也再没提起过；继续把它们挂在 T1 里，
/// 只会挤掉真正重要的待办。这里是**静默**处理——
/// 弹一句「你放弃了 XXX」纯属给人添堵，那是玩家用脚投的票。
const int kLoopDropAfterTurns = 90;

/// 超过这么多回合、且重要性不高于这个值的，会被标记为 dropped
const int kLoopDropMaxImportance = 6;

/// 从一批伏笔里挑出该放下的那些。
List<OpenLoopRecord> staleLoopsToDrop(
  Iterable<OpenLoopRecord> loops,
  int currentTurn, {
  int afterTurns = kLoopDropAfterTurns,
  int maxImportance = kLoopDropMaxImportance,
}) {
  final out = <OpenLoopRecord>[];
  for (final l in loops) {
    if (l.status != 'open') continue;
    if (l.importance > maxImportance) continue;
    // openedTurn 为 0 是旧存档，按"很久以前"处理——
    // 但那样会一上手就把老存档的伏笔全丢了，所以这里按"刚开"处理，放过它
    if (l.openedTurn <= 0) continue;
    if (currentTurn - l.openedTurn < afterTurns) continue;
    out.add(l);
  }
  return out;
}
