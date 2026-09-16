/// R9 + R10 + R11 + R12：零散小配置的数据化
///
/// R9：EventAnchor 特判白名单（原 common_jul_summer_start 靠 id 硬编码 removeWhere）
/// R10：魔杖来源描述（原 mixin_init.dart 3 处硬编码「奥利凡德魔杖店选中」）
/// R11：地图区域定义（原 mixin_commands.dart _formatMap 硬编码列表）
/// R12：课堂意外事件池（原 mixin_relations.dart 斯内普教授硬编码）
///
/// 依赖方向：本文件 → locations.dart（单向），因为 `regionForLocation` 需要
/// 地点别名表把「蜂蜜公爵糖果店」这类子地点归到「霍格莫德村」区域。
/// locations.dart **不得**反向 import 本文件，否则形成循环依赖。
library;

import 'locations.dart';

// ====== R9：需要额外进度门的事件锚点 id 白名单 ======
// 这些锚点如果要触发，除了 event_anchors.dart 自带的 month/grade/era 条件外，
// 还需要满足一个"时间/进度"门槛。（例如暑假开始锚点不能在入学前的7月触发）
class AnchorGatedRule {
  final String anchorId;
  final String description; // debug 打印的原因

  /// 判定函数（返回 true 时允许触发，false 时跳过）
  final bool Function(
    int currentYear,
    int currentMonth,
    int? academicYearStartInt,
  ) predicate;

  const AnchorGatedRule({
    required this.anchorId,
    required this.description,
    required this.predicate,
  });
}

final List<AnchorGatedRule> anchorGatedRules = [
  AnchorGatedRule(
    anchorId: 'common_jul_summer_start',
    description: '7 月属于入学前/学年开始前，非学年结束后的暑假',
    predicate: (year, month, acYearStart) {
      if (month != 7) return true;
      final start = acYearStart;
      if (start == null) return true;
      // 例：1991-1992 学年 → 1992 年 7 月放暑假 ✓；1991 年 7 月 = 入学前 ✗
      return year >= (start + 1);
    },
  ),
];

// ====== R10：魔杖来源定义 ======
class WandSourceDef {
  final String id;
  final String narrativeLine; // 注入给 AI 的魔杖来源设定
  final bool isCanonical;
  const WandSourceDef({
    required this.id,
    required this.narrativeLine,
    this.isCanonical = true,
  });
}

const Map<String, WandSourceDef> wandSources = {
  'olivander_shop': WandSourceDef(
    id: 'olivander_shop',
    narrativeLine: '玩家的魔杖是奥利凡德先生在对角巷亲手选中的（魔杖选择巫师），绝不是捡来的木棍、祖传物品、或自己制作。',
  ),
  'family_heirloom': WandSourceDef(
    id: 'family_heirloom',
    narrativeLine: '玩家的魔杖是家族传家宝，由上一代亲人赠予，木材和杖芯承载着家族的古老记忆。',
    isCanonical: false,
  ),
  'self_made': WandSourceDef(
    id: 'self_made',
    narrativeLine: '玩家的魔杖由自己亲手制作：木材采自童年的山丘，杖芯来自一次奇遇中的神奇生物馈赠。',
    isCanonical: false,
  ),
};

const String kDefaultWandSourceId = 'olivander_shop';

// ====== R11：地图区域定义 ======
class MapRegionDef {
  final String icon;
  final String name;

  /// 解锁条件的**展示文案**。
  ///
  /// 以前它是唯一的解锁信息——一段给人看的中文，代码里没有任何一处读它
  /// 做判定，于是写着「高年级或特定课程开放」的禁林，一年级新生照样能
  /// 一个人走进去。现在判定看 [minGrade] / [weekendOnly]，
  /// 这个字段只负责把条件说给人（和 AI）听。
  final String? unlockCondition; // null 表示默认解锁

  /// 低于这个年级不开放（0 表示无年级限制）。
  final int minGrade;

  /// 只在周末开放（霍格莫德村）。
  final bool weekendOnly;

  const MapRegionDef({
    required this.icon,
    required this.name,
    this.unlockCondition,
    this.minGrade = 0,
    this.weekendOnly = false,
  });

  /// [grade] 为 null（还没入学 / 未设定年级）时按一年级算。
  bool isUnlocked({required int? grade, required bool isWeekend}) {
    final g = grade ?? 1;
    if (g < minGrade) return false;
    if (weekendOnly && !isWeekend) return false;
    return true;
  }
}

const List<MapRegionDef> mapRegions = [
  MapRegionDef(icon: '🏰', name: '城堡主楼（大礼堂、各学院公共休息室、图书馆、教室）'),
  MapRegionDef(icon: '🧙', name: '各学院公共休息室'),
  MapRegionDef(
    icon: '🌳',
    name: '禁林',
    unlockCondition: '二年级以上，或由教授带队',
    minGrade: 2,
  ),
  MapRegionDef(icon: '🧪', name: '地下教室（魔药学、斯莱特林公共休息室）'),
  MapRegionDef(icon: '🏟️', name: '魁地奇球场'),
  MapRegionDef(
    icon: '🏘️',
    name: '霍格莫德村',
    unlockCondition: '三年级以上，且仅周末开放',
    minGrade: 3,
    weekendOnly: true,
  ),
  MapRegionDef(icon: '🧹', name: '天文塔'),
  MapRegionDef(icon: '📚', name: '图书馆（含禁书区）'),
];

/// 当前条件下已开放的区域（/地点 命令与 prompt 共用一份判定）。
List<MapRegionDef> unlockedRegionsFor({
  required int? grade,
  required bool isWeekend,
}) =>
    mapRegions
        .where((r) => r.isUnlocked(grade: grade, isWeekend: isWeekend))
        .toList();

/// 当前条件下尚未开放的区域。AI 需要知道玩家**去不了**哪些地方，
/// 否则会一本正经地写"一年级新生独自深入禁林"。
List<MapRegionDef> lockedRegionsFor({
  required int? grade,
  required bool isWeekend,
}) =>
    mapRegions
        .where((r) => !r.isUnlocked(grade: grade, isWeekend: isWeekend))
        .toList();

// ====== 区域门禁判定（统一入口） ======
//
// 【为什么要有这一层】R11 把区域条件数据化后，`minGrade` / `weekendOnly`
// 只被 `isUnlocked` 消费，而 `isUnlocked` 的消费者只有两个「展示/提示」场景：
//   · `unlockedRegionsFor` / `lockedRegionsFor` → 喂 prompt 文案与 /地点 面板
//   · mixin_commands 的 🔒 标记
// 真正决定「玩家能不能进」的**状态写入硬门**却在别处写死了 `'霍格莫德'` 三个字，
// 于是：禁林 `minGrade: 2` 白定义、霍格莫德 `weekendOnly: true` 从未拦过。
// 这就是典型的「配置字段与判定函数断链」——字段写得很规范，判定函数也有，
// 但两者之间没有连线。本层的作用就是**把线连上**：所有门禁判定都从这里出，
// 数据改一处、行为跟着改一处。

/// 区域门禁的拦截原因。null 表示放行。
///
/// 用它替代原先的 `bool` 返回值，是为了让调用方能写出**准确**的提示文案——
/// 以前三处调用点的文案都硬编码成"需三年级/霍格莫德需三年级"，
/// 即使拦的是禁林也会这么说（因为函数只认霍格莫德，文案也就跟着只提三级）。
/// 现在原因由数据推导，文案自然准确，也不会再出现"拦了 A 却说 B"。
enum RegionGateReason {
  /// 年级不够（[MapRegionDef.minGrade]）。
  grade,

  /// 非周末（[MapRegionDef.weekendOnly]）。
  weekend,
}

/// 区域门禁判定的结果。
class RegionGateResult {
  /// 被拦下的区域定义；null 表示放行。
  final MapRegionDef? blocked;

  /// 拦截原因；[blocked] 为 null 时为 null。
  final RegionGateReason? reason;

  const RegionGateResult._(this.blocked, this.reason);

  static const RegionGateResult allowed = RegionGateResult._(null, null);

  bool get isBlocked => blocked != null;

  /// 给玩家/日志看的解锁条件文案（来自数据表，不再各处硬编码）。
  String get conditionText => blocked?.unlockCondition ?? '';
}

/// [detected] 文本命中的受限区域 → 它在地点表里的主名。没有则返回 null。
///
/// 匹配分两步，缺一不可：
///   1. **区域主名直配**：`region.name` 出现在 detected 里，或去掉括号说明后的
///      主干词出现（如「城堡主楼（大礼堂…）」→ 看「城堡主楼」）。
///   2. **别名表回查**：AI 常写子地点而非区域名（「蜂蜜公爵糖果店」而不是
///      「霍格莫德村」）。子地点关系定义在 `locations.dart` 的 `kKnownLocations`
///      别名表里，这里用 `resolveLocationName` 反查主名，再看该主名是否
///      以某个区域名开头（`霍格莫德村·三把扫帚`.startsWith(`霍格莫德村`)）。
///
/// 【为什么必须走别名表】这两张表（区域门禁 vs 地点别名）本来是**两套独立的
/// 字符串**，靠"名字看起来一样"维持默契——这正是"配置与判定断链"的温床。
/// 走 `resolveLocationName` 之后，地点归属只有 `kKnownLocations` 一个真源，
/// 新增子地点时门禁自动跟随，不需要同时改两处。
MapRegionDef? regionForLocation(String detected) {
  if (detected.isEmpty) return null;

  final restricted = mapRegions
      .where((r) => r.minGrade > 0 || r.weekendOnly)
      .toList(growable: false);
  if (restricted.isEmpty) return null;

  for (final region in restricted) {
    if (_nameMatches(region.name, detected)) return region;
  }

  // 别名表回查：先归一到地点主名，再看它挂在哪条区域下
  final canonical = resolveLocationName(detected);
  if (canonical != null) {
    final t = _stripParen(canonical);
    for (final region in restricted) {
      if (t == region.name || t.startsWith(region.name)) return region;
    }
  }
  return null;
}

/// 去掉名称里的括号说明部分（`霍格莫德村（仅周末）` → `霍格莫德村`）。
String _stripParen(String s) {
  final idx = s.indexOf('（');
  return idx > 0 ? s.substring(0, idx) : s;
}

/// [name] 是否在 [text] 中出现：先按全名，再按去括号后的主干词。
bool _nameMatches(String name, String text) {
  if (text.contains(name)) return true;
  final stem = _stripParen(name);
  return stem != name && text.contains(stem);
}

/// 区域门禁统一判定。
///
/// 【为什么取代 `blockedByGradeGate`】旧函数签名 `(detected, grade)` 有两个问题：
///   1. 只认霍格莫德（写死字符串），禁林/周末限制形同虚设；
///   2. 只收 `grade`，没有 `isWeekend`，天生无法表达周末限制。
/// 新函数收齐判定所需的全部输入，并从数据表推导原因，避免再次断链。
///
/// [escortExempt] 用于「教授带队」豁免（禁林解锁条件明确写了"或由教授带队"）。
/// 是否豁免由调用方决定——因为只有调用方拿得到叙事正文/事件上下文。
RegionGateResult evaluateRegionGate({
  required String detected,
  required int? grade,
  required bool isWeekend,
  bool escortExempt = false,
}) {
  final region = regionForLocation(detected);
  if (region == null) return RegionGateResult.allowed;

  // 教授带队豁免：仅对「有年级限制但非周末限制」的区域生效。
  // 霍格莫德是村民通行许可制度，带队也去不了，所以不给豁免。
  if (escortExempt && !region.weekendOnly) {
    return RegionGateResult.allowed;
  }

  final g = grade ?? 1;
  if (g < region.minGrade) {
    return RegionGateResult._(region, RegionGateReason.grade);
  }
  if (region.weekendOnly && !isWeekend) {
    return RegionGateResult._(region, RegionGateReason.weekend);
  }
  return RegionGateResult.allowed;
}

/// 判断 [weekday] 是否为周末。
///
/// 单点定义，消除散落各处的 `weekday == 0 || weekday == 6`。
/// `GameTime.weekday` 约定：0 = 星期日 … 6 = 星期六。
bool isWeekendWeekday(int weekday) => weekday == 0 || weekday == 6;

// ====== R12：课堂意外事件池 ======
// 每一条包含：科目筛选（subjectFilter 为空表示全科目通用）、意外文本模板
class ClassAccidentDef {
  final List<String> subjectFilter; // 命中任一即会出现；空 = 通用
  final String text;
  const ClassAccidentDef({this.subjectFilter = const [], required this.text});
}

const List<ClassAccidentDef> classAccidentPool = [
  ClassAccidentDef(
    subjectFilter: ['魔药学', '魔药课', 'potions'],
    text: '魔药课上，你的坩埚突然冒出诡异的绿烟，被魔药课教授冷冷地盯了三秒。',
  ),
  const ClassAccidentDef(
    subjectFilter: ['草药学', '草药课', 'herbology'],
    text: '温室里，你险些被曼德拉草的尖叫声震晕，幸好及时堵住了耳朵。',
  ),
  const ClassAccidentDef(
    subjectFilter: ['黑魔法防御术', 'dada', '黑魔法防御课'],
    text: '黑魔法防御课上，你被选中上台示范，紧张中竟意外地漂亮完成了动作。',
  ),
  const ClassAccidentDef(
    subjectFilter: ['天文学', '天文课', 'astronomy'],
    text: '天文课上，你透过望远镜瞥见了一颗罕见的流星，全班都循声凑了过来。',
  ),
  // ====== 通用（不指定科目的随机小插曲）======
  const ClassAccidentDef(
    text: '你的笔记本被邻桌同学失手撞掉，散落的纸片飞了一地，两人手忙脚乱地捡起来时相视一笑。',
  ),
  const ClassAccidentDef(
    text: '窗外突然掠过一群猫头鹰，学生们都不自觉地转头望去，教授敲了敲讲桌才拉回大家的注意力。',
  ),
  const ClassAccidentDef(
    text: '你答不出问题时，身后传来一张递来的小纸条——上面用歪歪扭扭的字写着答案的前半句。',
  ),
];
