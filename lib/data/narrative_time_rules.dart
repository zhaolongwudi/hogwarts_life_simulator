/// 叙事时间校验规则（R4：双时间源收敛）
///
/// 问题背景：AI 在【时间戳】里写「📅 三天后」，但世界钟只按 TimeCostRules
/// 走了 30 分钟。AI 写的时间戳只被解析出来展示，从不回写 worldState，
/// 于是玩家看到"三天后"，日历还停在当天，下一回合 prompt 里的时间又跳回去。
///
/// 收敛办法取「明令 AI 不得自行跨天」这一路：日历由系统独占推进，
/// AI 只准照抄当前时间。本文件把"怎么判定 AI 越界"做成纯函数，
/// 便于单测，也让 mixin 那边只剩一行委托。
library;

/// 从叙事文本里解析出的 AI 自报日期。
class AiTimestamp {
  final int? year;
  final int? month;
  final int? day;

  const AiTimestamp({this.year, this.month, this.day});

  /// 年月日齐全才能做差比较；只有月日时按"缺年"处理（见 [checkNarrativeTime]）。
  bool get isComplete => year != null && month != null && day != null;

  @override
  String toString() => '${year ?? '?'}年${month ?? '?'}月${day ?? '?'}日';
}

/// 匹配【时间戳】行后面的日期。
/// 两种写法都接：完整版「📅 1991年9月1日，星期日，上午 9:00」
/// 与精简版「📅9月3日 傍晚」。
final RegExp _reTimestampLine = RegExp(r'📅\s*([^\n]+)');
final RegExp _reYear = RegExp(r'(\d{4})\s*年');
final RegExp _reMonth = RegExp(r'(\d{1,2})\s*月');
final RegExp _reDay = RegExp(r'(\d{1,2})\s*日');

/// 从叙事文本里抓 AI 自报的日期。抓不到返回空壳（各项为 null）。
AiTimestamp parseAiTimestamp(String narrative) {
  final line = _reTimestampLine.firstMatch(narrative)?.group(1);
  if (line == null) return const AiTimestamp();

  final y = _reYear.firstMatch(line)?.group(1);
  final m = _reMonth.firstMatch(line)?.group(1);
  final d = _reDay.firstMatch(line)?.group(1);

  return AiTimestamp(
    year: y == null ? null : int.tryParse(y),
    month: m == null ? null : int.tryParse(m),
    day: d == null ? null : int.tryParse(d),
  );
}

/// 时间跳跃词：AI 在正文里自行快进时间。
/// 命中即代表剧情时间与系统日历会分叉。
const List<String> kTimeJumpPhrases = [
  '三天后',
  '四天后',
  '五天后',
  '六天后',
  '一周后',
  '一周过去',
  '半个月后',
  '一个月后',
  '一个月过去',
  '几个月后',
  '半年后',
  '一年后',
  '数日后',
  '数周后',
  '数月后',
  '数年后',
  '三年后',
  '十年后',
  '许多年后',
  '时光飞逝',
  '转瞬即逝',
  '春去秋来',
  '寒来暑往',
  '日子一天天过去',
  '日子一天天',
  '日复一日',
];

/// 找出正文里命中的时间跳跃词。
List<String> findTimeJumpPhrases(String narrative) {
  final hits = <String>[];
  for (final phrase in kTimeJumpPhrases) {
    if (narrative.contains(phrase)) hits.add(phrase);
  }
  return hits;
}

/// 判定结论。
enum NarrativeTimeIssue {
  /// 没问题（没写日期，或日期与系统一致）
  none,

  /// 时间倒流：AI 写的日期早于系统日历
  regression,

  /// 时间跳跃：AI 写的日期比系统日历晚了不止一天
  jump,

  /// 日期只差一天：可能是深夜剧情自然延续，放行但记录
  overnight,

  /// 正文里用了「三天后」这类时间跳跃词
  jumpPhrase,
}

/// 时间校验报告。
class NarrativeTimeReport {
  final NarrativeTimeIssue issue;

  /// AI 日期 - 系统日期（天）。未解析出日期时为 null。
  final int? deltaDays;

  /// 命中的时间跳跃词。
  final List<String> phrases;

  /// AI 自报日期原文（用于违规提示里点名）。
  final String? evidence;

  const NarrativeTimeReport({
    required this.issue,
    this.deltaDays,
    this.phrases = const [],
    this.evidence,
  });

  bool get hasProblem => issue != NarrativeTimeIssue.none;

  /// 是否严重到需要整段重写。
  /// overnight 不重写——深夜剧情跨过零点一天是合理的，系统日历稍后会推进。
  bool get needsRewrite =>
      issue == NarrativeTimeIssue.regression ||
      issue == NarrativeTimeIssue.jump ||
      issue == NarrativeTimeIssue.jumpPhrase;
}

/// 校验一段叙事的时间是否与系统日历一致。
///
/// [year]/[month]/[day] 为当前世界日期（推进前）。
/// 检查顺序：先查正文时间跳跃词，再比日期——词命中比日期错更常见，
/// 先报词能让 AI 拿到更具体的整改提示。
NarrativeTimeReport checkNarrativeTime(
  String narrative, {
  required int year,
  required int month,
  required int day,
}) {
  final phrases = findTimeJumpPhrases(narrative);
  if (phrases.isNotEmpty) {
    return NarrativeTimeReport(
      issue: NarrativeTimeIssue.jumpPhrase,
      phrases: phrases,
      evidence: phrases.join('、'),
    );
  }

  final ai = parseAiTimestamp(narrative);
  if (!ai.isComplete) {
    return const NarrativeTimeReport(issue: NarrativeTimeIssue.none);
  }

  final current = DateTime(year, month, day);
  final written = DateTime(ai.year!, ai.month!, ai.day!);
  final delta = written.difference(current).inDays;
  final evidence = ai.toString();

  if (delta < 0) {
    return NarrativeTimeReport(
      issue: NarrativeTimeIssue.regression,
      deltaDays: delta,
      evidence: evidence,
    );
  }
  if (delta == 0) {
    return const NarrativeTimeReport(issue: NarrativeTimeIssue.none);
  }
  if (delta == 1) {
    return NarrativeTimeReport(
      issue: NarrativeTimeIssue.overnight,
      deltaDays: delta,
      evidence: evidence,
    );
  }
  return NarrativeTimeReport(
    issue: NarrativeTimeIssue.jump,
    deltaDays: delta,
    evidence: evidence,
  );
}

/// 匹配「【时间戳】📅 ……」整行（完整版 prompt 的规范格式）。
final RegExp _reTimestampLabelLine = RegExp(r'^【时间戳】[^\n]*$', multiLine: true);

/// 匹配精简版 prompt 下 AI 只写的一行裸「📅 ……」。
final RegExp _reBareTimestampLine = RegExp(r'^📅[^\n]*$', multiLine: true);

/// 把 AI 自报的时间戳行替换成系统时间戳。
///
/// 这是展示侧的兜底：连续性检查已经把「三天后」这类跨天叙事打回重写了，
/// 但重试耗尽、或 AI 只是把时刻写偏几分钟时，玩家不该看到与日历对不上的时间。
/// 没有时间戳行时原样返回——不凭空造一行，避免改变"这回合有没有头部卡片"的既有行为。
String backfillTimestamp(String narrative, String systemTimestamp) {
  if (systemTimestamp.trim().isEmpty) return narrative;

  if (_reTimestampLabelLine.hasMatch(narrative)) {
    return narrative.replaceAllMapped(
      _reTimestampLabelLine,
      (_) => '【时间戳】$systemTimestamp',
    );
  }
  if (_reBareTimestampLine.hasMatch(narrative)) {
    final bare = systemTimestamp.trim();
    return narrative.replaceAllMapped(
      _reBareTimestampLine,
      (_) => bare.startsWith('📅') ? bare : '📅 $bare',
    );
  }
  return narrative;
}

/// 给叙事 prompt 用的时间预算说明行。
///
/// 光说"不要跨天"没用，AI 不知道一个回合该覆盖多久。
/// 把系统算出来的耗时直接告诉它，它才知道"这回合是一节课还是一整个假期"。
String timeBudgetPromptLine(int minutes) {
  final span = minutes >= 60 ? '${minutes ~/ 60} 小时' : '$minutes 分钟';
  return '【时间预算】本回合剧情覆盖约 $span（$minutes 分钟）的剧情时间。'
      '日期由系统日历独占推进——严禁写「三天后」「一周过去」「一个月过去了」，'
      '也不要把【时间戳】里的日期改成别的一天。'
      '日历不会因为你写了就跟着走，只会让剧情和日历对不上。';
}
