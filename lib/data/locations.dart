/// 已知地点表（主名 × 别名）。
///
/// 原先是 mixin_narrative 里的私有常量，但它其实是纯数据：
///  - _syncLocationFromNarrative 拿它把 AI 写的【地点】标签归一化成主名
///  - 事件锚点的 requiredLocation 也依赖这套别名做位置约束
/// 挪到数据层之后，测试可以直接校验「锚点要求的位置是不是真存在」，
/// 不用再去翻 mixin 的私有成员。
const List<(String, List<String>)> kKnownLocations = [
  ('家中·卧室', ['家中', '卧室', '自己的房间']),
  ('国王十字车站', ['国王十字', '国王十字车站', '九又四分之三站台', '9¾站台', '站台']),
  ('霍格沃茨特快列车', ['霍格沃茨特快', '特快列车', '火车包厢', '车厢']),
  ('霍格沃茨大礼堂', ['大礼堂', '分院仪式', '分院帽']),
  ('霍格沃茨·公共休息室', ['公共休息室', '休息室']),
  ('霍格沃茨·教室', ['教室', '课堂', '阶梯教室']),
  ('霍格沃茨·图书馆', ['图书馆', '禁书区']),
  ('霍格沃茨·医疗翼', ['医疗翼', '医院翼']),
  ('霍格沃茨·走廊', ['走廊', '楼梯', '移动楼梯']),
  ('霍格沃茨·场地', ['草坪', '魁地奇球场', '魁地奇看台', '黑湖']),
  ('禁林', ['禁林', '黑暗森林']),
  ('对角巷', ['对角巷', '奥利凡德', '摩金夫人']),
  ('古灵阁', ['古灵阁', '妖精银行']),
  ('霍格莫德村', ['霍格莫德', '三把扫帚', '蜂蜜公爵']),
];

/// 所有地点主名。
List<String> get kLocationNames =>
    kKnownLocations.map((e) => e.$1).toList(growable: false);

/// 所有别名（含主名本身）。
Iterable<String> get allLocationAliases sync* {
  for (final (name, aliases) in kKnownLocations) {
    yield name;
    yield* aliases;
  }
}

/// 在 [text] 里找第一个命中的地点别名，返回对应主名；没命中返回 null。
///
/// 匹配顺序按 kKnownLocations 的声明顺序——「家中」排在「走廊」前面，
/// 所以"家里的走廊"会归到家中而不是霍格沃茨走廊。
String? resolveLocationName(String text) {
  if (text.isEmpty) return null;
  for (final (name, aliases) in kKnownLocations) {
    // 先试主名：AI 偶尔直接写规范名（「霍格沃茨·场地」），
    // 而这条目的别名是「草坪/魁地奇球场/黑湖」，没有一个匹配得上规范名本身。
    if (text.contains(name)) return name;
    for (final alias in aliases) {
      if (text.contains(alias)) return name;
    }
  }
  return null;
}

/// 当前地点 [currentLocation] 是否满足事件锚点的位置约束 [required]。
///
/// 先把两边都归一化成地点主名再比，比不出来才退回双向子串。
/// 只比子串是不够的：当前地点是归一化后的主名（「霍格沃茨·场地」），而锚点
/// 写的是「黑湖」——「黑湖」是场地这条目的别名，两边互为子串都成立不了，
/// 于是写明「在黑湖畔触发」的锚点一个都不会触发，而且不报错、不写日志，
/// 只能靠"这个剧情怎么一直不出"来发现。
bool locationMatches(String currentLocation, String required) {
  if (required.isEmpty || currentLocation.isEmpty) return true;
  final here = resolveLocationName(currentLocation);
  final want = resolveLocationName(required);
  if (here != null && want != null) return here == want;
  return currentLocation.contains(required) || required.contains(currentLocation);
}

/// [keyword] 是否是某个已知地点的主名或别名的一部分。
///
/// 这是给测试用的数据校验：抓 requiredLocation 写错别字（「特快列车」写成
/// 「特快车」）这种改一个字就静默失效的笔误。运行时是否匹配看
/// [locationMatches]，不是这里。
bool locationKeywordResolvable(String keyword) {
  if (keyword.isEmpty) return true;
  for (final alias in allLocationAliases) {
    if (alias.contains(keyword) || keyword.contains(alias)) return true;
  }
  return false;
}
