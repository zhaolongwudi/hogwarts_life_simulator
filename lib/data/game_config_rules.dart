/// R9 + R10 + R11 + R12：零散小配置的数据化
///
/// R9：EventAnchor 特判白名单（原 common_jul_summer_start 靠 id 硬编码 removeWhere）
/// R10：魔杖来源描述（原 mixin_init.dart 3 处硬编码「奥利凡德魔杖店选中」）
/// R11：地图区域定义（原 mixin_commands.dart _formatMap 硬编码列表）
/// R12：课堂意外事件池（原 mixin_relations.dart 斯内普教授硬编码）

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
  final String? unlockCondition; // null 表示默认解锁
  const MapRegionDef({
    required this.icon,
    required this.name,
    this.unlockCondition,
  });
}

const List<MapRegionDef> mapRegions = [
  MapRegionDef(icon: '🏰', name: '城堡主楼（大礼堂、各学院公共休息室、图书馆、教室）'),
  MapRegionDef(icon: '🧙', name: '各学院公共休息室'),
  MapRegionDef(
    icon: '🌳',
    name: '禁林',
    unlockCondition: '高年级或特定课程开放',
  ),
  MapRegionDef(icon: '🧪', name: '地下教室（魔药学、斯莱特林公共休息室）'),
  MapRegionDef(icon: '🏟️', name: '魁地奇球场'),
  MapRegionDef(
    icon: '🏘️',
    name: '霍格莫德村',
    unlockCondition: '周末开放',
  ),
  MapRegionDef(icon: '🧹', name: '天文塔'),
  MapRegionDef(icon: '📚', name: '图书馆（含禁书区）'),
];

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
