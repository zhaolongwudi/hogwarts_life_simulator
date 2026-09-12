import '../models/npc.dart';

// ==================== NPC 日程推导 ====================
//
// NPC.currentLocation 的默认值是 '霍格沃茨'，而全项目没有任何一处给它赋过值。
// 后果有两个，都不报错、只看得见症状：
//  1. npcsInCurrentLocation() 用 `npc.currentLocation.contains(玩家地点)` 判定，
//     '霍格沃茨' 包含不了 '霍格沃茨·教室'，所以【在场】这一行从来不出现在
//     prompt 里——上回合还站在你面前的人，下回合凭空消失。
//  2. isNearby() 用 `npc.currentLocation == 玩家地点`，恒为 false。
//
// 给几十个 NPC 逐个手写日程表不现实（npc_data.dart 里 schedule 字段至今全空），
// 所以这里改成按「身份 + 时段」推导：饭点去大礼堂、深夜回宿舍、教授守着
// 自己的教室。粒度粗，但活得起来，而且符合 README 里承诺的
// 「教授按课表出现在教室，魁地奇队长在球场训练」。

/// 教职工的常驻地点。没列出的教职工回落到 [kDefaultStaffLocation]。
const Map<String, String> kStaffHomeLocations = {
  'dumbledore': '霍格沃茨·校长室',
  'mcgonagall': '霍格沃茨·教室', // 变形术
  'snape': '霍格沃茨·地窖', // 魔药学
  'flitwick': '霍格沃茨·教室', // 魔咒学
  'sprout': '霍格沃茨·温室', // 草药学
  'hooch': '霍格沃茨·场地', // 飞行课 / 魁地奇
  'trelawney': '霍格沃茨·天文塔', // 占卜学
  'binns': '霍格沃茨·教室', // 魔法史
  'pince': '霍格沃茨·图书馆', // 图书管理员
  'pomfrey': '霍格沃茨·医疗翼', // 护士长
  'hagrid': '霍格沃茨·场地', // 猎场看守
  'filch': '霍格沃茨·走廊', // 管理员，永远在巡逻
};

/// 没在 [kStaffHomeLocations] 里的教职工（含动态生成的）默认待的地方。
const String kDefaultStaffLocation = '霍格沃茨·教室';

/// 每位教授/教职工**上课时段**（也是白天常待）的具体教室——「教授按课表在
/// 教室等」的硬耦合本体。没列出的教职工回落到自己的常驻点。
///
/// 之前所有教授共享一个泛化「霍格沃茨·教室」，玩家进教室看到的是"一屋子
/// 教授"，哪个都不像在上课。细分之后：麦格只在变形术教室、弗利维只在魔咒
/// 教室、斯内普守地窖……玩家走进对应教室才见得到那位教授，世界才像在运转。
const Map<String, String> kStaffClassLocations = {
  'mcgonagall': '霍格沃茨·变形术教室', // 变形术
  'snape': '霍格沃茨·地窖', // 魔药学（原著：魔药课在地下教室）
  'flitwick': '霍格沃茨·魔咒教室', // 魔咒学
  'sprout': '霍格沃茨·温室', // 草药学
  'trelawney': '霍格沃茨·占卜教室', // 占卜学
  'binns': '霍格沃茨·魔法史教室', // 魔法史
  'hooch': '霍格沃茨·场地', // 飞行课
  'hagrid': '霍格沃茨·场地', // 保护神奇生物
};

/// 上课时段学生可能待的教室池。按 npc 身份哈希分配，避免一整个年级的人
/// 同时挤进同一个教室——不同教室该有不同的面孔。
const List<String> kStudentClassRooms = [
  '霍格沃茨·教室',
  '霍格沃茨·变形术教室',
  '霍格沃茨·魔咒教室',
  '霍格沃茨·魔法史教室',
  '霍格沃茨·占卜教室',
];

/// 稳定字符串哈希：Dart 的 hashCode 对同一字符串在同一平台稳定，但跨版本/
/// 跨平台不保证；这里用固定算法保证存档迁移与测试可复现。
int _stableHash(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

/// 学生默认待的地方。
const String kStudentCommonRoom = '霍格沃茨·公共休息室';
const String kStudentDorm = '霍格沃茨·宿舍';
const String kGreatHall = '霍格沃茨大礼堂';
const String kLibraryLocation = '霍格沃茨·图书馆';
const String kGroundsLocation = '霍格沃茨·场地';

/// 三餐时段（起始小时，含）：学生在这些钟点会去大礼堂。
const List<int> kMealHours = <int>[7, 8, 12, 13, 18, 19];

/// 上课时段（含）：这段时间内学生和教授都在教学区。
bool isClassHour(int hour) => hour >= 9 && hour < 17;

/// 深夜时段：学生回宿舍，教职工回自己的地盘。
bool isLateHour(int hour) => hour >= 22 || hour < 6;

// ==================== 作息例外 ====================
//
// 上面那套推导是**按身份归模板**：饭点大礼堂、深夜回宿舍、教授守自己的教室。
// 推得没错，但也因此每个人都是可预测的——你知道斯内普永远在地窖，
// 于是"去地窖找斯内普"变成一条固定路线，而不是一次遭遇。
//
// 真正的学校不是这样。你半夜路过教室撞见有人在熬药，
// 周日清晨看见有人在小屋外劈柴，凌晨三点的走廊上有人光脚在走。
// **这些"不在常规位置"的人，才是世界活着的证据。**
//
// 所以这里给一小撮人开例外。三条规矩：
//
//  1. **窗口要窄。** 覆盖大半个星期的例外就不叫例外了，
//     它会退化成"这个人的新常态"，而推导表里那套逻辑就白写了。
//  2. **每条都给个理由。** 理由不是给玩家看的，是喂给 AI 的——
//     否则 AI 只看见"斯内普在教室"，写不出"他在熬一种
//     不能在地窖里熬的东西"。
//  3. **只挑那些"他会在那儿"说得通的人。** 卢平每月消失几天
//     这种需要月相的例外暂时不做：那不是作息，那是另一个系统。

/// 某个人在某个特定时刻出现在不该在的地方。
class ScheduleException {
  final String npcId;

  /// 0=星期日 … 6=星期六；null = 每天都成立
  final int? weekday;

  /// 起止小时（闭区间）。都留空 = 该日全天。
  /// `fromHour > toHour` 表示跨午夜（如 23 点到次日 1 点）。
  final int? fromHour;
  final int? toHour;

  /// 他这会儿在哪儿
  final String location;

  /// 他在这儿干什么。这句会喂给 AI，写得越具体越好。
  final String reason;

  const ScheduleException({
    required this.npcId,
    this.weekday,
    this.fromHour,
    this.toHour,
    required this.location,
    required this.reason,
  });
}

const List<ScheduleException> kScheduleExceptions = [
  // ---- 深夜的教职工 ----
  ScheduleException(
    npcId: 'snape',
    weekday: 2, // 周二
    fromHour: 23,
    toHour: 1,
    location: '霍格沃茨·教室',
    reason: '他在熬一种不能在地窖里熬的东西——地窖总有人进进出出，'
        '而这间教室的门他能从里面锁上。他不会解释自己在熬什么，'
        '被撞见时他先做的动作是用身体挡住坩埚。',
  ),
  ScheduleException(
    npcId: 'mcgonagall',
    weekday: 3, // 周三
    fromHour: 23,
    toHour: 1,
    location: '霍格沃茨·走廊',
    reason: '她每周三值夜巡楼。这是她自己定的规矩，'
        '没人要求一个副院长每周三半夜在城堡里走一圈。'
        '她提着灯，走得很慢，在每一幅画像前都会停一下。',
  ),
  ScheduleException(
    npcId: 'dumbledore',
    fromHour: 0,
    toHour: 4,
    location: '霍格沃茨·天文塔',
    reason: '他睡得很少。塔上那台仪器转得很慢，'
        '而他坐在旁边，看起来不像在等什么结果，'
        '更像是在等天亮。'
        '被撞见时他不会赶人走，会先问一句"你也睡不着？"。',
  ),
  ScheduleException(
    npcId: 'trelawney',
    weekday: 4, // 周四
    fromHour: 23,
    toHour: 2,
    location: '霍格沃茨·教室',
    reason: '她说她在等一个预兆，说不上来是什么，'
        '也说不上来会是什么时候——"只是今晚必须有人在这儿"。'
        '桌上摆着三杯凉透的茶。',
  ),
  ScheduleException(
    npcId: 'filch',
    fromHour: 2,
    toHour: 5,
    location: '霍格沃茨·地窖',
    reason: '他很少下地窖——洛丽丝夫人受不了那里的味道。'
        '所以他挑在这个钟点下来，一个人慢慢地走一遍，'
        '手里的灯举得很低。没人知道他在找什么。',
  ),

  // ---- 海格：他的一周从周日清晨开始，周五夜里结束 ----
  ScheduleException(
    npcId: 'hagrid',
    weekday: 0, // 周日
    fromHour: 6,
    toHour: 9,
    location: '霍格沃茨·场地',
    reason: '他一整周的柴都在周日早上劈完，'
        '所以周日早饭他是不去吃的。'
        '斧头落下的声音很有节奏，隔着半个场地都听得见。',
  ),
  ScheduleException(
    npcId: 'hagrid',
    weekday: 5, // 周五
    fromHour: 23,
    toHour: 2,
    location: '禁林',
    reason: '周五夜里他去喂夜骐。他不带灯——'
        '他说它们不喜欢光，其实是怕吓着它们。'
        '他会跟它们说话，用的是跟人说话时完全不一样的语气。',
  ),

  // ---- 学生：他们从来不睡在该睡的地方 ----
  ScheduleException(
    npcId: 'wood',
    fromHour: 6,
    toHour: 7,
    location: '霍格沃茨·场地',
    reason: '晨跑。雷打不动，下雪也跑，'
        '而他也从不邀请任何人一起。'
        '跑完他会绕着球场走一圈，看看草皮。',
  ),
  ScheduleException(
    npcId: 'neville',
    fromHour: 21,
    toHour: 23,
    location: '霍格沃茨·温室',
    reason: '他忘了时间。这不是第一次了——'
        '温室里的灯还亮着，他蹲在一盆植物前面，'
        '手上全是泥，脸上有一道。',
  ),
  ScheduleException(
    npcId: 'hermione',
    weekday: 0, // 周日
    fromHour: 6,
    toHour: 8,
    location: '霍格沃茨·图书馆',
    reason: '她发现周日早上没有人跟她抢图书馆，'
        '于是这变成了她一周里最喜欢的两小时。'
        '桌上摊着六本书，还有一支咬得很难看的羽毛笔。',
  ),
  ScheduleException(
    npcId: 'luna',
    fromHour: 3,
    toHour: 5,
    location: '霍格沃茨·走廊',
    reason: '她在找她的鞋。它们总是不见，'
        '而她说这不是有人藏的，是城堡自己拿走的，'
        '"它只是想让我多走走"。她光着脚走得很平静。',
  ),
  ScheduleException(
    npcId: 'fred',
    weekday: 5, // 周五
    fromHour: 23,
    toHour: 2,
    location: '霍格沃茨·厨房',
    reason: '周五夜里的厨房归他们。他们在偷夜宵，'
        '但更像是把这当成了自己的据点——'
        '桌上摊着各种东西，其中不少跟吃的一点关系都没有。',
  ),
  ScheduleException(
    npcId: 'george',
    weekday: 5,
    fromHour: 23,
    toHour: 2,
    location: '霍格沃茨·厨房',
    reason: '同上：周五夜里的厨房。他负责望风，'
        '而望风这件事他做得极其不认真——'
        '被撞见时他会先笑，然后再决定要不要跑。',
  ),
];

/// [hour] 是否落在 [from] → [to] 这段闭区间里。
///
/// `from > to` 按跨午夜处理（23 点到次日 1 点）。
/// 两端都为空表示不限制钟点。
bool _hourInExceptionWindow(int hour, int? from, int? to) {
  if (from == null && to == null) return true;
  if (from == null) return hour <= to!;
  if (to == null) return hour >= from;
  if (from <= to) return hour >= from && hour <= to;
  return hour >= from || hour <= to; // 跨午夜
}

/// 查 [npcId] 在 [hour] 点有没有正在生效的作息例外。
///
/// [weekday] 沿用 GameTime 的约定：**0=星期日 … 6=星期六**。
/// 多条命中时取表里第一条——所以窄窗口的要排在前面。
ScheduleException? scheduleExceptionFor(
  String npcId,
  int hour, {
  int weekday = 1,
}) {
  for (final e in kScheduleExceptions) {
    if (e.npcId != npcId) continue;
    if (e.weekday != null && e.weekday != weekday) continue;
    if (!_hourInExceptionWindow(hour, e.fromHour, e.toHour)) continue;
    return e;
  }
  return null;
}

/// 推导 [npc] 在 [hour] 点应该在的位置。
///
/// [weekday] 沿用 GameTime 的约定：**0=星期日 … 6=星期六**。
/// 周末学生不上课，在场地和休息室之间晃——这也是「霍格莫德村周末开放」
/// 这条规则能生效的前提。
///
/// 例外优先：命中 [kScheduleExceptions] 时直接返回例外地点，
/// 不再走下面那套按身份推导。
String npcExpectedLocation(NPC npc, int hour, {int weekday = 1}) {
  final ex = scheduleExceptionFor(npc.id, hour, weekday: weekday);
  if (ex != null) return ex.location;

  final isStaff = npc.grade == 0;
  final home = isStaff
      ? (kStaffHomeLocations[npc.id] ?? kDefaultStaffLocation)
      : null;

  // 深夜：各回各家
  if (isLateHour(hour)) {
    return isStaff ? home! : kStudentDorm;
  }

  // 饭点：除了图书管理员和护士长，都去大礼堂
  if (kMealHours.contains(hour)) {
    if (isStaff && (npc.id == 'pince' || npc.id == 'pomfrey')) return home!;
    return kGreatHall;
  }

  if (isStaff) {
    // 霍琦和海格常年在户外
    if (npc.id == 'hooch' || npc.id == 'hagrid') return kGroundsLocation;
    // 上课时段：教授按课表守自己的专属教室——麦格在变形术教室、斯内普在
    // 地窖、弗利维在魔咒教室……这是「教授按课表在教室等」的硬耦合：
    // 玩家在上课时间去对应教室才见得到他。没配专属教室的回落常驻点。
    if (isClassHour(hour)) {
      return kStaffClassLocations[npc.id] ?? home!;
    }
    // 非上课时段（清晨 6-9 点、傍晚 17-22 点）：教授回自己的办公室或常驻点。
    // （22 点后的深夜在更上面的 isLateHour 分支就回 home 了，走不到这里。）
    // 这段判断曾经在做教室细分时被整段删掉，导致配了专属教室的教授在清晨和
    // 傍晚也钉在教室里——傍晚六点去变形术教室还能撞见麦格，kStaffHomeLocations
    // 对他们事实上失效。「世界在运转」要求位置随时间流动，而不是钉死在教室。
    return kStaffHomeLocations[npc.id] ?? home!;
  }

  // ---- 学生 ----
  // GameTime.weekday：0=星期日 … 6=星期六
  final isWeekend = weekday == 0 || weekday == 6;

  if (!isClassHour(hour)) {
    // 傍晚：周末在场地，平时泡图书馆或休息室
    if (isWeekend) return kGroundsLocation;
    return hour >= 19 ? kStudentCommonRoom : kLibraryLocation;
  }

  if (isWeekend) {
    // 周末白天：球场 / 霍格莫德
    return hour % 2 == 0 ? kGroundsLocation : kStudentCommonRoom;
  }

  // 工作日白天：上课。魁地奇队长和击球手下午在球场训练
  final isAthlete = const ['wood', 'angelina', 'cedric', 'roger'].contains(npc.id);
  if (isAthlete && hour >= 15) return kGroundsLocation;

  // 学生按身份稳定哈希分散到不同教室，不再全员挤进同一个「教室」——
  // 每个教室该有不同的面孔，玩家才感受得到「这一屋是变形术课、那屋是魔咒课」。
  return kStudentClassRooms[_stableHash(npc.id) % kStudentClassRooms.length];
}

/// 按当前世界时间刷新所有存活 NPC 的位置。
///
/// 只动「在校」的人：已毕业的学生和死亡的人不参与，避免毕业多年的学长
/// 还天天出现在教室。返回实际被改动位置的 NPC 数。
int refreshNpcLocations(Iterable<NPC> npcs, int hour, int weekday) {
  var changed = 0;
  for (final npc in npcs) {
    if (!npc.isAlive) continue;
    if (npc.graduated) continue;
    final next = npcExpectedLocation(npc, hour, weekday: weekday);
    if (npc.currentLocation != next) {
      npc.currentLocation = next;
      changed++;
    }
  }
  return changed;
}
