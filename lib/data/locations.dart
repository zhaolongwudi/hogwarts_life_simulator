/// 已知地点表（主名 × 别名）。
///
/// 原先是 mixin_narrative 里的私有常量，但它其实是纯数据：
///  - _syncLocationFromNarrative 拿它把 AI 写的【地点】标签归一化成主名
///  - 事件锚点的 requiredLocation 也依赖这套别名做位置约束
/// 挪到数据层之后，测试可以直接校验「锚点要求的位置是不是真存在」，
/// 不用再去翻 mixin 的私有成员。
/// 「家」这条目的主名。
const String kHomeLocation = '家中·卧室';

/// 「霍格沃茨宿舍」的主名。
const String kDormLocation = '霍格沃茨·宿舍';

/// 「霍格沃茨厨房」的主名。
const String kKitchenLocation = '霍格沃茨·厨房';

/// 家里和城堡里都有的房间名。
///
/// 用途：AI 写「卧室」「厨房」时，光看这两个词分不清是老家还是城堡。
/// 分错后果很糟——在宿舍跟室友聊完天，下回合开场变成
/// "你推开家门，养母在厨房喊你"。
///
/// 这两个词刻意**不**写进「家中」条目的别名表——地点表要求一个别名只映射
/// 到一个主名（「卧室」「厨房」既作宿舍/厨房的别名又作家里的别名，
/// 解析结果就取决于声明顺序，测试也没法判定对错），
/// 而是由 [resolveLocationName] 在出现学校线索时前置拦截。
const List<String> kAmbiguousRoomWords = ['卧室', '厨房'];

/// [kAmbiguousRoomWords] 在学校语境里各自该落到哪个主名。
const Map<String, String> kAmbiguousAtHogwarts = {
  '卧室': kDormLocation,
  '厨房': kKitchenLocation,
};

/// 出现其中任意一个词，就认为玩家人已经回家了。
///
/// 与 [kHogwartsContextHints] 配合使用：AI 写「你推开家门，养母在厨房喊你」
/// 时，[kAmbiguousRoomWords] 靠它把「厨房」判回家里而不是城堡厨房。
const List<String> kHomeContextHints = [
  '家中',
  '家里',
  '家门',
  '回家',
  '老家',
  '养母',
  '养父',
  '父母',
  '母亲',
  '父亲',
  '监护人',
  '自己的房间',
  '麻瓜',
];

const List<String> kHogwartsContextHints = [
  '霍格沃茨',
  '格兰芬多',
  '斯莱特林',
  '赫奇帕奇',
  '拉文克劳',
  '宿舍',
  '寝室',
  '舍友',
  '室友',
  '级长',
  '城堡',
  '公共休息室',
  '分院帽',
  '教授',
];

const List<(String, List<String>)> kKnownLocations = [
  // 宿舍刻意排在「家中」之前：在城堡里待的时间远多于在家，
  // 且宿舍的别名（宿舍/寝室/四柱床）与家中不冲突，只有「卧室」需要上下文判定。
  (kDormLocation, ['宿舍', '寝室', '四柱床', '床铺']),
  (kHomeLocation, ['家中', '卧室', '自己的房间', '老家']),
  ('国王十字车站', ['国王十字', '国王十字车站', '九又四分之三站台', '9¾站台', '站台']),
  ('霍格沃茨特快列车', ['霍格沃茨特快', '特快列车', '火车包厢', '车厢']),
  ('霍格沃茨大礼堂', ['大礼堂', '分院仪式', '分院帽']),
  ('霍格沃茨·公共休息室', ['公共休息室', '休息室']),
  // ↓↓↓ 以下 8 条是补齐的：AI 常写，但原先表里没有，
  //     resolveLocationName 返回 null → currentLocation 永远停在旧值，
  //     于是「我明明去了宿舍」在下一回合的 prompt 里依然是「霍格沃茨·教室」。
  ('霍格沃茨·盥洗室', ['盥洗室', '洗手间', '浴室', '厕所', '卫生间']),
  ('霍格沃茨·温室', ['温室', '草药棚']),
  ('霍格沃茨·地窖', ['地窖', '地下教室', '魔药教室']),
  ('霍格沃茨·天文塔', ['天文塔', '塔楼', '观星台']),
  ('霍格沃茨·猫头鹰屋', ['猫头鹰屋', '猫头鹰棚']),
  ('霍格沃茨·厨房', ['厨房', '家养小精灵']),
  ('有求必应屋', ['有求必应屋', '来去屋']),
  ('霍格沃茨·校长室', ['校长室', '邓布利多办公室']),
  ('霍格沃茨·教室', ['教室', '课堂', '阶梯教室']),
  ('霍格沃茨·图书馆', ['图书馆', '禁书区']),
  ('霍格沃茨·医疗翼', ['医疗翼', '医院翼']),
  ('霍格沃茨·走廊', ['走廊', '楼梯', '移动楼梯']),
  ('霍格沃茨·场地', ['草坪', '魁地奇球场', '魁地奇看台', '黑湖']),
  ('禁林', ['禁林', '黑暗森林']),
  ('霍格莫德村', ['霍格莫德', '三把扫帚', '蜂蜜公爵']),
  ('对角巷', ['对角巷', '奥利凡德', '摩金夫人']),
  ('古灵阁', ['古灵阁', '妖精银行', '金库', '古灵阁金库']),
  // ↓↓↓ 校外三大去处，README 里写了但地点表漏了
  ('翻倒巷', ['翻倒巷', '博金博克', '博金-博克']),
  ('魔法部', ['魔法部', '神秘事务司', '正厅']),
  ('圣芒戈魔法伤病医院', ['圣芒戈', '魔法伤病医院']),
  ('伦敦', ['伦敦', '破釜酒吧', '麻瓜伦敦']),
  // ↓↓↓ 补全：以下原著主要地点原先词表缺失，AI 写了会 resolveLocationName 返回 null
  //     → currentLocation 卡在旧值（"去了陋居，下回合 prompt 仍以为在霍格沃茨·教室"）。
  //     补全后这些地点能正常解析、地点向前推进，不再"切不动"。
  ('陋居', ['陋居', '韦斯莱家', '韦斯莱']),
  ('格里莫广场12号', ['格里莫', '格里莫广场', '凤凰社总部']),
  ('猪头酒吧', ['猪头', '猪头酒吧']),
  ('尖叫棚屋', ['尖叫棚屋', '尖叫屋']),
  ('骑士巴士', ['骑士巴士', '紫色巴士']),
  ('夜骐马车', ['夜骐', '夜骐马车', '马车']),
  ('女贞路4号', ['女贞路', '德思礼', '德思礼家']),
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

  // 「卧室」「厨房」这类房间名家里和城堡里都有。先断人在不在学校：
  // 命中学院名 / 城堡 / 舍友等线索时跳过「家中」条目，让它们落进宿舍或
  // 霍格沃茨厨房；没有这些线索则跳过宿舍，按家里算。
  // 「卧室」「厨房」在城堡和家里都有，光看这两个词定不下来。
  // 先看上下文：出现学院名、城堡、舍友这类线索就按学校里的那一份算
  // （在宿舍跟室友聊完天，下回合不该变成"你推开家门，养母在厨房喊你"）；
  // 出现家门、养母这类线索就按家里算。
  // 两条线索都给不出时（比如就孤零零一个「卧室」），落到下面的别名表兜底。
  for (final w in kAmbiguousRoomWords) {
    if (!text.contains(w)) continue;
    if (kHomeContextHints.any(text.contains)) return kHomeLocation;
    if (kHogwartsContextHints.any(text.contains)) {
      return kAmbiguousAtHogwarts[w]!;
    }
    break;
  }

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
