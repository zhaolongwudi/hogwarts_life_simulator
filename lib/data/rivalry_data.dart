/// 宿敌系统规则（数据层）
///
/// 地基是 NPC 上那个早就存在、却只有一种触发方式的 `grudges`：
/// 原先只有「单次好感暴跌 > 15」会记一笔 'betrayal'，记完也仅用于
/// 压低好感上限——NPC 不会主动做任何事，玩家感受到的只有"好感涨不上去了"，
/// 而不是"有个人在跟我作对"。
///
/// 这里补上三样东西：
///  1. 多种成因（抢风头、当众下不来台、情场竞争、立场冲突……）各有权重；
///  2. 宿敌分与等级：一条记仇和十条记仇不该表现得一样，一年前的旧账也不该
///     和昨天的新仇一样烫；
///  3. 每档一份行为指令，喂给叙事 AI——宿敌得**做点什么**，玩家才感觉得到。
library;

/// 宿敌成因。key 即写入 grudges 的 type 字段，
/// 'betrayal' 与既有存档兼容（老存档里只有这一种）。
enum RivalryCause {
  betrayal,
  publicHumiliation,
  outshone,
  romance,
  harmed,
  principle,
  house,
}

/// 成因定义：权重决定它在宿敌分里占多大分量。
class RivalryCauseDef {
  final RivalryCause cause;
  final String key;
  final String label;

  /// 单条记仇的基础宿敌分
  final int weight;

  /// 给玩家看的一句话解释
  final String note;

  const RivalryCauseDef({
    required this.cause,
    required this.key,
    required this.label,
    required this.weight,
    required this.note,
  });
}

const List<RivalryCauseDef> kRivalryCauses = [
  RivalryCauseDef(
    cause: RivalryCause.betrayal,
    key: 'betrayal',
    label: '背叛',
    weight: 40,
    note: '你骗了他，或者在他需要你的时候站到了对面',
  ),
  RivalryCauseDef(
    cause: RivalryCause.publicHumiliation,
    key: 'public_humiliation',
    label: '当众难堪',
    weight: 35,
    note: '你让他在众人面前下不来台，这比打一架还难原谅',
  ),
  RivalryCauseDef(
    cause: RivalryCause.harmed,
    key: 'harmed',
    label: '伤害',
    weight: 35,
    note: '你伤了他，或者伤了他所在乎的人',
  ),
  RivalryCauseDef(
    cause: RivalryCause.romance,
    key: 'romance',
    label: '情场竞争',
    weight: 25,
    note: '你们看上了同一个人，而他没抢到',
  ),
  RivalryCauseDef(
    cause: RivalryCause.outshone,
    key: 'outshone',
    label: '被抢风头',
    weight: 20,
    note: '同一门课、同一场比赛、同一次竞选——风头被你抢走了',
  ),
  RivalryCauseDef(
    cause: RivalryCause.principle,
    key: 'principle',
    label: '立场冲突',
    weight: 15,
    note: '你们在血统、立场这类根本问题上站在两边',
  ),
  RivalryCauseDef(
    cause: RivalryCause.house,
    key: 'house',
    label: '学院对立',
    weight: 8,
    note: '没什么私仇，纯粹是学院之间那点老规矩',
  ),
];

final Map<String, RivalryCauseDef> _causeByKey = {
  for (final c in kRivalryCauses) c.key: c,
};

/// 认不出的 type 按「背叛」算，不至于让旧数据或手写数据悄悄失效。
const int kUnknownCauseWeight = 30;

int grudgeWeightFor(String? type) =>
    _causeByKey[type]?.weight ?? kUnknownCauseWeight;

String causeLabelFor(String? type) => _causeByKey[type]?.label ?? '过节';

// ============================================================ 宿敌等级

enum RivalryTier {
  none,
  grudge,
  hostile,
  nemesis,
  archenemy,
}

class RivalryTierDef {
  final RivalryTier tier;

  /// 进入这一档所需的最低宿敌分
  final int threshold;
  final String label;

  /// 给玩家看的描述
  final String desc;

  const RivalryTierDef({
    required this.tier,
    required this.threshold,
    required this.label,
    required this.desc,
  });
}

const List<RivalryTierDef> kRivalryTiers = [
  RivalryTierDef(
    tier: RivalryTier.none,
    threshold: 0,
    label: '无',
    desc: '你们之间没什么过不去的。',
  ),
  RivalryTierDef(
    tier: RivalryTier.grudge,
    threshold: 20,
    label: '芥蒂',
    desc: '心里有根刺，说话带点刺，但还不至于撕破脸。',
  ),
  RivalryTierDef(
    tier: RivalryTier.hostile,
    threshold: 45,
    label: '敌意',
    desc: '不打算装了。当面顶撞、公开较劲，也在拉人站队。',
  ),
  RivalryTierDef(
    tier: RivalryTier.nemesis,
    threshold: 70,
    label: '宿敌',
    desc: '主动找机会让你难堪。他不是为了赢，是为了让你输。',
  ),
  RivalryTierDef(
    tier: RivalryTier.archenemy,
    threshold: 100,
    label: '死敌',
    desc: '恨你，且不在乎代价。造谣、下绊子，不惜自己吃亏也要拉你下水。',
  ),
];

RivalryTier tierForScore(int score) {
  var tier = RivalryTier.none;
  for (final t in kRivalryTiers) {
    if (score >= t.threshold) tier = t.tier;
  }
  return tier;
}

RivalryTierDef tierDefFor(RivalryTier tier) =>
    kRivalryTiers.firstWhere((t) => t.tier == tier);

// ============================================================ 时间衰减

/// 每过这么多天，宿敌分乘一次 [kDecayPerPeriod]。
const int kDecayPeriodDays = 30;

/// 一个衰减周期内保留的比例。
const double kDecayPerPeriod = 0.85;

/// 最低保留比例：再久的旧账也不该彻底归零，
/// 否则玩家什么都不做、挂机几个月就能自动洗白所有宿敌。
const double kDecayFloor = 0.25;

double decayFactorFor(int daysAgo) {
  if (daysAgo <= 0) return 1.0;
  final periods = daysAgo / kDecayPeriodDays;
  final f = powDouble(kDecayPerPeriod, periods);
  return f < kDecayFloor ? kDecayFloor : f;
}

/// 手写 pow：dart:math 的 pow 返回 num，这里要的是 double，
/// 且指数不会很大，循环展开比引 math 更省事。
double powDouble(double base, double exponent) {
  var result = 1.0;
  var e = exponent;
  while (e > 0) {
    result *= base;
    e -= 1;
  }
  return result;
}

// ============================================================ 好感修正

/// 宿敌分的好感折扣。
///
/// 好感已经很高说明关系在回暖，这时还把旧账按全额算就会很怪：
/// "他明明已经跟你称兄道弟了，转头还给你使绊子"。
const int kAffectionSofteningAt = 30;
const int kAffectionForgivingAt = 60;

double affectionFactorFor(int affection) {
  if (affection >= kAffectionForgivingAt) return 0.4;
  if (affection >= kAffectionSofteningAt) return 0.7;
  return 1.0;
}

// ============================================================ 宿敌分

/// 计算宿敌分。
///
/// [grudges] 为 NPC 的记仇记录，每条需含 'type' 与 'day'；
/// [currentDay] 为当前游戏日（与 grudges 的 day 同一基准）；
/// [relief] 是玩家主动补救累计下来的减免；
/// [affection] 用于关系回暖时打折。
int rivalryScoreFor(
  List<Map<String, dynamic>> grudges, {
  required int currentDay,
  int relief = 0,
  int affection = 0,
}) {
  if (grudges.isEmpty) return 0;

  var raw = 0.0;
  for (final g in grudges) {
    final type = g['type'] as String?;
    final day = g['day'] is int ? g['day'] as int : int.tryParse('${g['day']}');
    final daysAgo = day == null ? 0 : currentDay - day;
    raw += grudgeWeightFor(type) * decayFactorFor(daysAgo);
  }

  final softened = raw * affectionFactorFor(affection);
  final after = softened - relief;
  return after <= 0 ? 0 : after.round();
}

// ============================================================ 行为指令

/// 给叙事 AI 的宿敌行为指令。
///
/// 有等级才有区别：一档只会背后嘀咕，四档会真的下黑手。
/// 写清楚"做什么"而不是"态度不好"——后者 AI 演不出来。
String rivalryDirectiveFor(RivalryTier tier, String npcName, String? reason) {
  final why = (reason == null || reason.isEmpty) ? '那笔旧账' : '「$reason」这笔账';
  return switch (tier) {
    RivalryTier.none => '',
    RivalryTier.grudge =>
      '$npcName 对$why一直没释怀：说话带刺、跟旁人嘀咕你、'
          '聚会时故意不看你。不至于动手，但绝不会给你台阶下。'
          '不要写成明面上的冲突——这一档是阴的。',
    RivalryTier.hostile =>
      '$npcName 不打算装了：$why他记着。当面顶撞、公开跟你较劲、'
          '你说什么他都先驳一句，也在悄悄拉人站到他那边。'
          '他会在有旁观者的场合找你麻烦，因为那才有意思。',
    RivalryTier.nemesis =>
      '你和$npcName 已经是你死我活那种关系：他会主动找机会让你难堪——'
          '在教授面前给你上眼药、把你的东西藏起来、'
          '在魁地奇场上专门盯着你撞。'
          '他不是为了赢，是为了让你输。写他真的动手，不要只写嘴上逞强。'
          '他恨你的根由是$why——写的时候记住这一点，别让他显得无理取闹。',
    RivalryTier.archenemy =>
      '$npcName 恨你，而且已经不在乎代价：造谣、下绊子、'
          '哪怕自己也吃亏也要拉你下水。'
          '这一档可以让他做出不体面甚至危险的事，'
          '但别写成卡通反派——他恨得有理由，那个理由是$why。',
  };
}

/// 给「在场 NPC」列表用的短标签。
String rivalryBadgeFor(RivalryTier tier) => switch (tier) {
      RivalryTier.none => '',
      RivalryTier.grudge => '🙄 芥蒂',
      RivalryTier.hostile => '😠 敌意',
      RivalryTier.nemesis => '⚔️ 宿敌',
      RivalryTier.archenemy => '💀 死敌',
    };

// ============================================================ 和解

/// 一次善意行动能减免多少宿敌分。
///
/// 低于这个数玩家感觉不到自己在赎罪，高于这个数宿敌又太容易洗白。
const int kReliefPerAmends = 12;

/// 一天内最多减免多少，防止"同一个下午连送十份礼物刷白"。
const int kMaxReliefPerDay = 24;

/// 化敌为友所需的门槛：宿敌分归零，且好感回到正值。
const int kForgivenessAffection = 20;

/// 峰值至少到过这一档，之后的化敌为友才算一段佳话。
/// 只结过一点小芥蒂就和好了，不值得专门记一笔。
const int kFormerRivalMinPeak = 45; // = hostile 档阈值

/// 是否达成「化敌为友」：曾经真恨过，如今宿敌分归零且关系回暖。
bool canBecomeFormerRival(int score, int affection, int peakScore) =>
    peakScore >= kFormerRivalMinPeak &&
    score <= 0 &&
    affection >= kForgivenessAffection;

/// 化敌为友后的叙事提示（喂给 AI，也显示在通知里）。
String formerRivalLine(String npcName) =>
    '$npcName 曾经是你最难缠的对头，如今却成了能坐下来喝一杯的人。'
    '这件事在学院里传了一阵子——有人不信，有人说早就看出来了。';

// ============================================================ 成因识别

/// 从好感变化的原因文本里识别宿敌成因。
///
/// 好感路径是唯一稳定会写 grudges 的地方，而从 reason 里认成因
/// 比另起一套触发检测便宜得多：AI 写的理由通常已经说清了是什么性质的事。
/// 认不出来就退回 [RivalryCause.betrayal]（与既有存档一致）。
RivalryCause causeFromReason(String? reason) {
  final r = reason ?? '';
  if (r.isEmpty) return RivalryCause.betrayal;

  if (_containsAny(r, const ['当众', '众目睽睽', '公开', '所有人面前', '当着'])) {
    return RivalryCause.publicHumiliation;
  }
  if (_containsAny(r, const ['抢', '超过', '胜过', '赢', '压过', '风头'])) {
    return RivalryCause.outshone;
  }
  if (_containsAny(r, const ['喜欢', '表白', '舞伴', '吃醋', '情', '恋'])) {
    return RivalryCause.romance;
  }
  if (_containsAny(r, const ['打伤', '伤害', '咒伤', '害', '见死不救'])) {
    return RivalryCause.harmed;
  }
  if (_containsAny(r, const ['血统', '麻瓜', '纯血', '立场', '信念'])) {
    return RivalryCause.principle;
  }
  if (_containsAny(r, const ['学院', '院际', '学院杯'])) {
    return RivalryCause.house;
  }
  return RivalryCause.betrayal;
}

bool _containsAny(String text, List<String> words) {
  for (final w in words) {
    if (text.contains(w)) return true;
  }
  return false;
}

String causeKeyFor(RivalryCause cause) =>
    kRivalryCauses.firstWhere((c) => c.cause == cause).key;
