// ==================== 学院杯 · 日常行为的加减分 ====================
//
// 学院杯本身是完好的（见 mixin_play.dart）：`addHouseCupPoints` 统一入口、
// `/学院杯` 能看得分构成、学年末 `settleHouseCup()` 结算排名发奖励、
// 还有一个 `house_cup_winner` 成就。
//
// 但它的 5 个加分点全是**大事件**：魁地奇取胜 +30、决斗获胜 +1~10、
// 禁林战胜危险生物 +5、完成委托 +3~10。
//
// 于是有个缺口：
//
//   一个不打魁地奇、不决斗、不进禁林、不接委托的玩家，
//   `houseCupPoints` 七年恒为 0。而 `settleHouseCup()` 开头就是
//   `if (p.houseCupPoints <= 0) return;`——
//   **他七年里一次学院杯结算都看不到。**
//
// 学院杯在原著里从来不只是那几场比赛。它是课堂上答对的那个问题、
// 是你替同学解的围、也是你夜游被抓时扣掉的那些分。
// 那才是"每一个小选择都有分量"的意思。
//
// 所以这里补的是日常。三条原则：
//
// 1. **每回合最多加减一次。** 不是怕刷分——是怕 AI 在一大段叙事里
//    连写三句"教授赞许地点了点头"，一篇课文加 30 分。
// 2. **扣分优先于加分。** 一段叙事里先闯祸后补救的时候，记的是闯祸那次。
//    人被扣分往往比被加分更记得住。
// 3. **判不出来就不加减。** 宁可漏，不可乱加——
//    学院分是玩家挣的，不是系统发的。

/// 一次学院分变动。
class HousePointDelta {
  /// 分值，正为加、负为扣
  final int value;

  /// 为什么。这句会进 `/学院杯` 的来源明细，所以写得像人话。
  final String reason;

  const HousePointDelta(this.value, this.reason);
}

// ---------------------------------------------------------------- 加分

/// 加分信号：分值 → 关键词。
///
/// 分两档而不是一档，是因为"教授点了点头"和"全班只有你做成了"
/// 显然不是一回事。
const Map<int, List<String>> kHousePointGainRules = {
  10: [
    '唯一一个', '第一个成功', '全班只有', '连教授都', '教授站起来',
    '完美地', '教科书级', '救了', '挡在', '抓住了那个',
  ],
  5: [
    '赞许', '表扬', '称赞', '夸奖', '做得好', '很出色', '不错',
    '答对了', '答出问题', '回答正确', '一次成功', '一次就成了',
    '帮了', '扶起', '替他解围', '替她解围', '站出来', '主动承认',
  ],
};

// ---------------------------------------------------------------- 扣分

const Map<int, List<String>> kHousePointLossRules = {
  -20: [
    '关禁闭', '被开除', '记过', '送到校长室',
  ],
  // 注意这里写的是「坩埚炸」「魔药炸」而不是裸的「炸了」——
  // AI 很爱写「礼堂笑炸了」，那是夸你，不是扣你分。
  -10: [
    '被抓到', '被逮住', '当场抓住', '夜游', '违反校规',
    '打了起来', '动了手', '坩埚炸', '魔药炸', '失控',
  ],
  -5: [
    '留堂', '抄写', '罚站', '迟到了', '走神', '走错了',
  ],
};

/// 这些词出现时，上面的信号不作数。
///
/// 「差点被抓到」「幸好没炸」「以为会被关禁闭」——都不是真出事。
const List<String> kHousePointHedgeWords = [
  '差点', '险些', '几乎', '以为', '幸好', '幸亏', '还好',
  '没有', '没被', '虚惊', '逃过', '躲过',
];

/// 从一段叙事里认出一次学院分变动。
///
/// 返回 null 表示这一回合没有值得记的事——**绝大多数回合应该返回 null**。
HousePointDelta? housePointFromNarrative(String text) {
  if (text.isEmpty) return null;

  // 扣分先看：一段叙事里先闯祸后补救的时候，记的是闯祸那次。
  for (final entry in kHousePointLossRules.entries) {
    for (final w in entry.value) {
      final i = text.indexOf(w);
      if (i < 0) continue;
      if (_hedged(text, i)) continue;
      return HousePointDelta(entry.key, _reasonFor(text, i, w));
    }
  }
  for (final entry in kHousePointGainRules.entries) {
    for (final w in entry.value) {
      final i = text.indexOf(w);
      if (i < 0) continue;
      if (_hedged(text, i)) continue;
      return HousePointDelta(entry.key, _reasonFor(text, i, w));
    }
  }
  return null;
}

/// [i] 附近是不是有"差点 / 幸好"这类把事件否掉的词。
///
/// 窗口取前面 8 个字、后面 4 个字：中文里"差点"几乎总是前置
/// （"差点被抓到"），而"幸好"可以在后面（"被抓到了，幸好…"）。
bool _hedged(String text, int i) {
  final from = i - 8 < 0 ? 0 : i - 8;
  final to = i + 4 > text.length ? text.length : i + 4;
  final near = text.substring(from, to);
  for (final h in kHousePointHedgeWords) {
    if (near.contains(h)) return true;
  }
  return false;
}

/// 从命中处抠一句"发生了什么"，给来源明细用。
///
/// 取命中词前后一段，切到最近的标点，避免把半个句子拖进来。
String _reasonFor(String text, int i, String word) {
  final from = i - 12 < 0 ? 0 : i - 12;
  final to = i + 18 > text.length ? text.length : i + 18;
  var seg = text.substring(from, to).replaceAll(RegExp(r'\s+'), '');
  const breaks = {'，', '。', '、', '；', '：', '！', '？', '…'};
  final rel = i - from;
  // 往左找最近的分句起点
  for (var k = rel; k >= 0; k--) {
    if (breaks.contains(seg[k])) {
      seg = seg.substring(k + 1);
      break;
    }
  }
  // 往右切到标点为止
  for (var k = 0; k < seg.length; k++) {
    if (breaks.contains(seg[k])) return seg.substring(0, k);
  }
  return seg.isEmpty ? word : seg;
}

/// 给 `/学院杯` 来源明细用的分类名。
///
/// 日常的分数单独归一类，跟"魁地奇取胜""决斗获胜"这些大事件区分开——
/// 玩家看见"日常表现 +45"会比看见一堆零碎更清楚自己是怎么挣的。
String houseCupSourceLabelFor(HousePointDelta d) =>
    d.value > 0 ? '日常表现' : '日常扣分';
