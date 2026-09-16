/// 开场场景定义（R2：数据化，替代 mixin_init.dart 中 3 处 switch）
///
/// 同一个 openingScene（letter/station/diagon/hall/eve...）的：
///   - 初始时间（月/日/时/分）
///   - 初始地点（支持模板变量：${birthLocation}）
///   - 开场叙事文案
/// 统一定义在一张表。新增开局场景 = 新增 1 条 OpeningSceneDef。
class OpeningSceneDef {
  final String id;

  /// 起始时间
  final int month;
  final int day;
  final int hour;
  final int minute;

  /// 初始地点模板（支持 ${birthLocation} 替换）
  final String locationTemplate;

  /// 注入给 AI 的开场剧情起点描述
  final String startNarrative;

  const OpeningSceneDef({
    required this.id,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    required this.locationTemplate,
    required this.startNarrative,
  });

  /// 用玩家出生地替换模板变量后返回真实地点名
  String resolveLocation(String birthLocation) {
    return locationTemplate.replaceAll(r'${birthLocation}', birthLocation);
  }
}

const List<OpeningSceneDef> allOpeningScenes = [
  OpeningSceneDef(
    id: 'letter',
    month: 7,
    day: 31,
    hour: 18,
    minute: 45,
    locationTemplate: r'${birthLocation}·家中',
    startNarrative:
        '故事从你收到霍格沃茨录取通知书的那一刻开始——那只迟来的猫头鹰终于叩响了你的窗。',
  ),
  OpeningSceneDef(
    id: 'diagon',
    month: 8,
    day: 20,
    hour: 10,
    minute: 30,
    locationTemplate: '伦敦·对角巷',
    startNarrative:
        '故事从你踏入对角巷的那一刻开始——破釜酒吧的后门之外，整条鹅卵石街都在为开学季而热闹。',
  ),
  OpeningSceneDef(
    id: 'station',
    month: 9,
    day: 1,
    hour: 10,
    minute: 45,
    locationTemplate: '伦敦国王十字车站',
    startNarrative:
        '故事从你站在九又四分之三站台前开始——蒸汽火车冒着白烟等待着你。',
  ),
  OpeningSceneDef(
    id: 'hall',
    month: 9,
    day: 1,
    hour: 18,
    minute: 0,
    locationTemplate: '霍格沃茨大礼堂',
    startNarrative:
        '故事从你第一次踏入霍格沃茨大礼堂开始——金色的烛光在长桌上方摇曳。',
  ),
  OpeningSceneDef(
    id: 'eve',
    month: 9,
    day: 1,
    hour: 18,
    minute: 0,
    locationTemplate: '霍格沃茨新生宿舍',
    startNarrative:
        '故事从分院仪式前夜开始——你躺在床上翻来覆去，想着明天会被分到哪个学院。',
  ),
];

/// 默认回退（未知 id 时使用，保持与旧 switch default 分支一致）
const OpeningSceneDef _fallbackScene = OpeningSceneDef(
  id: 'station',
  month: 9,
  day: 1,
  hour: 9,
  minute: 0,
  locationTemplate: '伦敦国王十字车站',
  startNarrative:
      '故事从你站在九又四分之三站台前开始——蒸汽火车冒着白烟等待着你。',
);

OpeningSceneDef openingSceneById(String id) {
  for (final s in allOpeningScenes) {
    if (s.id == id) return s;
  }
  return _fallbackScene;
}
