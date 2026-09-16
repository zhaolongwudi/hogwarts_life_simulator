/// 违和词（禁止词）检测表。
///
/// 原先整张表写死在 mixin_narrative_continuity 的 mixin 方法里，两个后果：
///  1. 没法单测——方法是 mixin 成员，要测就得先搭一个 GameProvider；
///  2. 拿不到时代信息，于是 2020 战后时代的玩家写「掏出手机」也会被判
///     critical 重生成最多 3 次。
/// 挪到数据层之后是纯函数，测试可以直接验「哪个时代放行哪些词」。

/// 一条违和词命中。
class ForbiddenHit {
  /// 'critical' → 触发整段重写；'warn' → 只记一致性日志。
  final String severity;

  /// 'modern'（现代物品）/ 'cross_ip'（跨 IP）/ 'slang'（网络梗）。
  final String category;

  /// 命中的词，用于日志与给 AI 的修正提示。
  final String word;

  const ForbiddenHit({
    required this.severity,
    required this.category,
    required this.word,
  });

  Map<String, dynamic> toMap() =>
      {'severity': severity, 'category': category, 'word': word};

  @override
  String toString() => '$severity/$category: $word';
}

/// 按子串匹配的现代物品（中文为主，子串匹配足够准）。
const List<String> kModernItems = [
  '手机', '智能手机', '电话', '互联网', '因特网', '微信', '电子邮件', '推特',
  '高铁', '动车', '飞机', '民航', '地铁', '打车', '网约车', '计算机', '电脑',
  '笔记本电脑', '平板', '应用程序', '游戏主机', '电视', '冰箱', '空调',
  '加隆兑换人民币', '汇率', '电子支付', '扫码', '二维码',
];

/// 需要按"整词"匹配的现代物品（正则, 报告里显示的原词）。
///
/// 这些词是别的英文单词的子串，用 contains 会误伤：
/// app ⊂ apple / happen / approach，switch 是英文常用词。
/// 正则预编译成顶层 final —— 每回合要在好几段叙事上跑，
/// 放在循环体里现编译会被 test/regex_hotpath_test.dart 拦下。
final List<(RegExp, String)> kModernItemPatterns = [
  (RegExp(r'\bapp\b'), 'app'),
  (RegExp(r'\bapps\b'), 'apps'),
  (RegExp(r'\bemail\b'), 'email'),
  (RegExp(r'\be-?mail\b'), 'e-mail'),
  (RegExp(r'\bqq\b'), 'QQ'),
  (RegExp(r'\bswitch\b'), 'Switch'),
  (RegExp(r'\bps5\b'), 'PS5'),
  (RegExp(r'\bipad\b'), 'iPad'),
  (RegExp(r'\btwitter\b'), 'Twitter'),
];

/// 跨 IP 角色。任何时代都不该出现。
const List<String> kCrossIpItems = [
  '柯南', '工藤新一', '海贼王', '路飞', '火影忍者', '鸣人', '佐助', '原神',
  '旅行者', '刻晴', '钟离', '斗罗大陆', '唐三', '斗破苍穹', '萧炎',
  '三体', '三体人', '智子', '罗辑', '叶文洁',
  // ⚠️ 这张表里曾经写的是「逻辑」而不是「罗辑」。
  // 「逻辑」是中文常用词，放在 critical 级会让几乎每回合的叙事都被判违和、
  // 触发最多 3 次重生成（烧 token 且拖慢出文）。角色名是「罗辑」。
];

/// 网络梗（中文，子串匹配）。只 warn，不触发重写。
const List<String> kInternetSlang = [
  '绝绝子', '社死', '打call', '破防了', '内卷', '躺平', '栓q',
  '笑死我了哈哈哈哈', '大冤种', '我不李姐', '咱就是说', '一整个爱住',
];

/// 字母梗：\b 只对 ASCII 词有效，中英混合的（如「栓q」）走上面那张表。
final List<(RegExp, String)> kSlangWordPatterns = [
  (RegExp(r'\byyds\b'), 'yyds'),
  (RegExp(r'\bemo\b'), 'emo'),
  (RegExp(r'\bawsl\b'), 'awsl'),
  (RegExp(r'\bxswl\b'), 'xswl'),
];

/// 数字梗：只在它是独立数词时才算梗——「233 加隆」里的 233 不是梗。
final List<(RegExp, String)> kSlangNumberPatterns = [
  (RegExp(r'(?<![0-9])666(?![0-9])'), '666'),
  (RegExp(r'(?<![0-9])233(?![0-9])'), '233'),
];

/// 这些时代里，[kModernItems] 是**正常的**，不该判违和。
///
/// post_war（2020+）：战后重建的魔法世界，手机、电视、飞机都是日常。
/// 一条不带时代门的违禁词表，会让 2020 时代的玩家每写一句现代生活就被判
/// critical 重生成——烧 token、拖慢出文，最后逼得 AI 把所有现代生活都
/// 写成复古风，时代特色整个消失。
const List<String> kErasAllowingModernItems = ['post_war'];

/// [eraKey] 这个时代是否放行现代物品。
bool modernItemsAllowedForEra(String eraKey) =>
    kErasAllowingModernItems.contains(eraKey);

/// 检查 [text] 里的违和词：现代物品、跨 IP、网络梗。
///
/// [eraKey] 为 null 时按"不放行现代物品"处理（保守）。
List<ForbiddenHit> detectForbiddenWords(
  String text, {
  String? eraKey,
}) {
  // ❗原文是 `final lower = text;` —— 变量名叫 lower 却没转小写，
  // 于是 'QQ' / 'APP' / 'Switch' 这些大写条目一个都匹配不上，
  // 而 'switch' 这种小写条目又会误伤英文正常用词。
  final lower = text.toLowerCase();
  final hits = <ForbiddenHit>[];

  if (eraKey == null || !modernItemsAllowedForEra(eraKey)) {
    for (final w in kModernItems) {
      if (lower.contains(w)) {
        hits.add(ForbiddenHit(severity: 'critical', category: 'modern', word: w));
      }
    }
    for (final (re, label) in kModernItemPatterns) {
      if (re.hasMatch(lower)) {
        hits.add(
            ForbiddenHit(severity: 'critical', category: 'modern', word: label));
      }
    }
  }

  for (final w in kCrossIpItems) {
    if (lower.contains(w)) {
      hits.add(ForbiddenHit(severity: 'critical', category: 'cross_ip', word: w));
    }
  }
  for (final w in kInternetSlang) {
    if (lower.contains(w)) {
      hits.add(ForbiddenHit(severity: 'warn', category: 'slang', word: w));
    }
  }
  for (final (re, label) in kSlangWordPatterns) {
    if (re.hasMatch(lower)) {
      hits.add(ForbiddenHit(severity: 'warn', category: 'slang', word: label));
    }
  }
  for (final (re, label) in kSlangNumberPatterns) {
    if (re.hasMatch(lower)) {
      hits.add(ForbiddenHit(severity: 'warn', category: 'slang', word: label));
    }
  }
  return hits;
}
