import 'package:flutter/material.dart';

import 'locations.dart';

/// 场景插图配置：把剧情地点映射为「氛围渐变横幅」。
/// 不依赖外部图片资源，用渐变+图标+装饰营造场景氛围，
/// 保证任何地点都有视觉呈现（未命中时走默认城堡主题）。
class SceneIllustration {
  /// 地点关键词（包含匹配，长词在前优先命中）
  final List<String> keywords;
  final String title;
  final IconData icon;
  final List<Color> gradient;
  final String? emoji;

  const SceneIllustration({
    required this.keywords,
    required this.title,
    required this.icon,
    required this.gradient,
    this.emoji,
  });
}

/// 场景库：按典型地点组织，覆盖游戏内高频场景。
/// 匹配规则：地点字符串包含任一 keyword 即命中（长关键词优先）。
const List<SceneIllustration> kSceneIllustrations = [
  SceneIllustration(
    keywords: ['大礼堂', '礼堂', '分院仪式', '分院帽'],
    title: '大礼堂',
    icon: Icons.restaurant,
    emoji: '🕯️',
    gradient: [Color(0xFFB8860B), Color(0xFF6B4E16), Color(0xFF2D1F0A)],
  ),
  SceneIllustration(
    keywords: ['图书馆', '禁书区'],
    title: '图书馆',
    icon: Icons.menu_book,
    emoji: '📚',
    gradient: [Color(0xFF4A3B28), Color(0xFF2E2418), Color(0xFF1A140D)],
  ),
  SceneIllustration(
    // 「地窖」是 locations.dart 用的主名，场景库原写「地牢」，
    // 两个词对不齐导致「霍格沃茨·地窖」落空走默认城堡。
    keywords: ['魔药课教室', '魔药教室', '地牢', '斯莱特林地牢', '地窖', '地下教室'],
    title: '魔药课教室',
    icon: Icons.science,
    emoji: '⚗️',
    gradient: [Color(0xFF1B4332), Color(0xFF14332A), Color(0xFF0B1F1A)],
  ),
  SceneIllustration(
    keywords: ['温室', '草药'],
    title: '温室',
    icon: Icons.local_florist,
    emoji: '🌿',
    gradient: [Color(0xFF2D6A4F), Color(0xFF1E4D38), Color(0xFF12301F)],
  ),
  SceneIllustration(
    keywords: ['魁地奇球场', '球场', '训练场', '魁地奇看台'],
    title: '魁地奇球场',
    icon: Icons.sports_baseball,
    emoji: '🧹',
    gradient: [Color(0xFF1D5C8A), Color(0xFF164566), Color(0xFF0D2B40)],
  ),
  SceneIllustration(
    keywords: ['禁林', '森林'],
    title: '禁林',
    icon: Icons.park,
    emoji: '🌲',
    gradient: [Color(0xFF1B3A26), Color(0xFF102818), Color(0xFF071510)],
  ),
  SceneIllustration(
    keywords: ['黑湖', '湖边', '湖畔'],
    title: '黑湖',
    icon: Icons.water,
    emoji: '🌊',
    gradient: [Color(0xFF16324F), Color(0xFF0F2438), Color(0xFF081624)],
  ),
  SceneIllustration(
    keywords: ['天文塔', '天文', '观星台'],
    title: '天文塔',
    icon: Icons.nightlight_round,
    emoji: '🌌',
    gradient: [Color(0xFF2B2D5E), Color(0xFF1C1E42), Color(0xFF0F1029)],
  ),
  SceneIllustration(
    keywords: ['海格的小屋', '海格小屋'],
    title: '海格的小屋',
    icon: Icons.cottage,
    emoji: '🏡',
    gradient: [Color(0xFF7A5C3E), Color(0xFF5A4229), Color(0xFF3A2A18)],
  ),
  SceneIllustration(
    keywords: ['霍格莫德', '三把扫帚', '蜂蜜公爵', '帕笛芙', '佐科', '猪头酒吧'],
    title: '霍格莫德村',
    icon: Icons.store,
    emoji: '🏘️',
    gradient: [Color(0xFF8A6D3B), Color(0xFF66502A), Color(0xFF40311A)],
  ),
  SceneIllustration(
    keywords: [
      '对角巷',
      '古灵阁',
      '奥利凡德',
      '丽痕书店',
      '破釜酒吧',
      '韦斯莱魔法把戏坊',
      '摩金夫人',
      '妖精银行'
    ],
    title: '对角巷',
    icon: Icons.shopping_bag,
    emoji: '🪄',
    gradient: [Color(0xFF9A7B4F), Color(0xFF735A35), Color(0xFF4A3A20)],
  ),
  SceneIllustration(
    keywords: ['翻倒巷', '博金'],
    title: '翻倒巷',
    icon: Icons.dark_mode,
    emoji: '🕸️',
    gradient: [Color(0xFF3D3D4E), Color(0xFF2A2A38), Color(0xFF17171F)],
  ),
  SceneIllustration(
    keywords: ['魔法部', '神秘事务司', '正厅'],
    title: '魔法部',
    icon: Icons.account_balance,
    emoji: '🏛️',
    gradient: [Color(0xFF4A4E69), Color(0xFF363A52), Color(0xFF22243A)],
  ),
  SceneIllustration(
    keywords: [
      '国王十字',
      '九又四分之三',
      '站台',
      '霍格沃茨特快',
      '火车',
      '特快列车',
      '车厢'
    ],
    title: '九又四分之三站台',
    icon: Icons.train,
    emoji: '🚂',
    gradient: [Color(0xFF8B3A3A), Color(0xFF66292B), Color(0xFF40181B)],
  ),
  SceneIllustration(
    keywords: ['医疗翼', '医院', '圣芒戈'],
    title: '医疗翼',
    icon: Icons.local_hospital,
    emoji: '🩹',
    gradient: [Color(0xFF5E7CE2), Color(0xFF465FB0), Color(0xFF2C3D78)],
  ),
  SceneIllustration(
    keywords: ['有求必应屋', '来去屋'],
    title: '有求必应屋',
    icon: Icons.auto_awesome,
    emoji: '✨',
    gradient: [Color(0xFF7B5EA7), Color(0xFF5B4380), Color(0xFF3A2A55)],
  ),
  SceneIllustration(
    keywords: ['校长办公室', '邓布利多办公室', '校长室'],
    title: '校长办公室',
    icon: Icons.door_front_door,
    emoji: '🦉',
    gradient: [Color(0xFF8A6D3B), Color(0xFF63502C), Color(0xFF3E311B)],
  ),
  SceneIllustration(
    keywords: [
      '公共休息室',
      '休息室',
      '格兰芬多塔',
      '拉文克劳塔',
      '赫奇帕奇地下室',
      '宿舍',
      '塔楼',
      '寝室',
      '四柱床',
      '床铺'
    ],
    title: '学院公共休息室',
    icon: Icons.chair,
    emoji: '🔥',
    gradient: [Color(0xFF7A4A3A), Color(0xFF5A352A), Color(0xFF3A211A)],
  ),
  SceneIllustration(
    keywords: ['教室', '魔咒教室', '变形课教室', '黑魔法防御术教室', '课堂'],
    title: '教室',
    icon: Icons.school,
    emoji: '📖',
    gradient: [Color(0xFF5A6B8A), Color(0xFF435169), Color(0xFF2B3445)],
  ),
  SceneIllustration(
    keywords: ['盥洗室', '洗手间', '浴室', '厕所', '卫生间', '哭泣的桃金娘'],
    title: '盥洗室',
    icon: Icons.bathtub,
    emoji: '🚿',
    gradient: [Color(0xFF3E6B7A), Color(0xFF2C4E5A), Color(0xFF182B33)],
  ),
  SceneIllustration(
    keywords: ['猫头鹰屋', '猫头鹰棚', '猫头鹰'],
    title: '猫头鹰屋',
    icon: Icons.flight_takeoff,
    emoji: '🦉',
    gradient: [Color(0xFF5C4A38), Color(0xFF42352A), Color(0xFF2A211A)],
  ),
  SceneIllustration(
    keywords: ['厨房', '家养小精灵'],
    title: '厨房',
    icon: Icons.kitchen,
    emoji: '🍲',
    gradient: [Color(0xFF8A6A2F), Color(0xFF6A5023), Color(0xFF403014)],
  ),
  SceneIllustration(
    keywords: ['走廊', '移动楼梯', '门厅', '楼梯'],
    title: '城堡走廊',
    icon: Icons.stairs,
    emoji: '🚪',
    gradient: [Color(0xFF4A4A55), Color(0xFF35353F), Color(0xFF1F1F26)],
  ),
  SceneIllustration(
    keywords: ['场地', '草坪', '操场'],
    title: '城堡外的场地',
    icon: Icons.nature,
    emoji: '🌾',
    gradient: [Color(0xFF3F6B4A), Color(0xFF2E5038), Color(0xFF1A3023)],
  ),
  SceneIllustration(
    keywords: ['伦敦', '麻瓜伦敦', '泰晤士'],
    title: '伦敦',
    icon: Icons.location_city,
    emoji: '🌫️',
    gradient: [Color(0xFF55606E), Color(0xFF3F4753), Color(0xFF262C34)],
  ),
  SceneIllustration(
    keywords: ['陋居', '女贞路', '家', '庄园', '卧室', '自己的房间'],
    title: '家',
    icon: Icons.home,
    emoji: '🏠',
    gradient: [Color(0xFF8A7B5E), Color(0xFF665A44), Color(0xFF403828)],
  ),
  SceneIllustration(
    keywords: ['格里莫广场12号', '格里莫广场', '格里莫', '凤凰社总部'],
    title: '格里莫广场12号',
    icon: Icons.apartment,
    emoji: '🏛️',
    gradient: [Color(0xFF3D3A4A), Color(0xFF2A2738), Color(0xFF17151F)],
  ),
  SceneIllustration(
    keywords: ['尖叫棚屋', '尖叫屋'],
    title: '尖叫棚屋',
    icon: Icons.cottage,
    emoji: '🏚️',
    gradient: [Color(0xFF2E3B2E), Color(0xFF1E2A1E), Color(0xFF0F150F)],
  ),
  SceneIllustration(
    keywords: ['骑士巴士', '紫色巴士'],
    title: '骑士巴士',
    icon: Icons.directions_bus,
    emoji: '🚌',
    gradient: [Color(0xFF5B3A8A), Color(0xFF43296A), Color(0xFF2A1842)],
  ),
  SceneIllustration(
    keywords: ['夜骐马车', '马车'],
    title: '夜骐马车',
    icon: Icons.nightlight_round,
    emoji: '🐎',
    gradient: [Color(0xFF1B2A4A), Color(0xFF12203A), Color(0xFF0A1424)],
  ),
];

/// 默认场景（未命中任何关键词时）：霍格沃茨城堡
const SceneIllustration kDefaultSceneIllustration = SceneIllustration(
  keywords: [],
  title: '霍格沃茨',
  icon: Icons.castle,
  emoji: '🏰',
  gradient: [Color(0xFF4A5568), Color(0xFF353E4E), Color(0xFF202634)],
);

/// 根据地点字符串解析场景插图配置。
/// 长关键词优先匹配（如「斯莱特林地牢」优先于「地牢」），未命中返回默认城堡。
/// 预展开并按关键词长度降序排好的候选表（长词优先）。
///
/// top-level final 是惰性求值且只算一次的——历史回放一页会渲染 10 条横幅，
/// 没必要每次 build 都重新展开全部关键词再排一遍序。
final List<({String keyword, SceneIllustration scene})> _kSceneCandidates =
    () {
  final list = <({String keyword, SceneIllustration scene})>[];
  for (final scene in kSceneIllustrations) {
    for (final kw in scene.keywords) {
      list.add((keyword: kw, scene: scene));
    }
  }
  list.sort((a, b) => b.keyword.length.compareTo(a.keyword.length));
  return list;
}();

SceneIllustration resolveSceneIllustration(String? location) {
  if (location == null || location.trim().isEmpty) {
    return kDefaultSceneIllustration;
  }

  // 第一优先：拿 AI 原文直接匹配。AI 写的地点是自由文本（「黑湖边的一块礁石」
  // 「斯内普的办公室」），往往比地点主名更具体，命中了就该保留这份具体。
  for (final c in _kSceneCandidates) {
    if (location.contains(c.keyword)) return c.scene;
  }

  // 第二优先：原文落空时，交给地点表归一化再试一次。
  // 这一步是给 UI 兜底的——叙事页的 location 是【地点】标签后的裸文本，
  // 不走归一化，命中率全看 AI 用词。归一化成主名后，
  // 上面那条「主名 100% 有场景」的契约就能接住它。
  // 注意顺序不能反：地点表粒度比场景库粗（黑湖和球场都并进「霍格沃茨·场地」），
  // 先归一化会把精细场景糊掉。
  final normalized = resolveLocationName(location);
  if (normalized != null) {
    for (final c in _kSceneCandidates) {
      if (normalized.contains(c.keyword)) return c.scene;
    }
  }

  return kDefaultSceneIllustration;
}
