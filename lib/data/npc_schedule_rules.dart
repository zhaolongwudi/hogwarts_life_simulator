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

/// 推导 [npc] 在 [hour] 点应该在的位置。
///
/// [weekday] 沿用 GameTime 的约定：**0=星期日 … 6=星期六**。
/// 周末学生不上课，在场地和休息室之间晃——这也是「霍格莫德村周末开放」
/// 这条规则能生效的前提。
String npcExpectedLocation(NPC npc, int hour, {int weekday = 1}) {
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
    // 教授白天守着自己的教室；霍琦和海格常年在户外
    if (npc.id == 'hooch' || npc.id == 'hagrid') return kGroundsLocation;
    // 不上课的时间，教授回办公室而不是教室
    return isClassHour(hour) ? home! : kStaffHomeLocations[npc.id] ?? home!;
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

  return '霍格沃茨·教室';
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
