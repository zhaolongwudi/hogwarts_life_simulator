import 'package:flutter/material.dart';

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
    keywords: ['大礼堂', '礼堂'],
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
    keywords: ['魔药课教室', '魔药教室', '地牢', '斯莱特林地牢'],
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
    keywords: ['魁地奇球场', '球场', '训练场'],
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
    keywords: ['天文塔', '天文'],
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
    keywords: ['对角巷', '古灵阁', '奥利凡德', '丽痕书店', '破釜酒吧', '韦斯莱魔法把戏坊'],
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
    keywords: ['魔法部'],
    title: '魔法部',
    icon: Icons.account_balance,
    emoji: '🏛️',
    gradient: [Color(0xFF4A4E69), Color(0xFF363A52), Color(0xFF22243A)],
  ),
  SceneIllustration(
    keywords: ['国王十字', '九又四分之三', '站台', '霍格沃茨特快', '火车'],
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
    keywords: ['有求必应屋'],
    title: '有求必应屋',
    icon: Icons.auto_awesome,
    emoji: '✨',
    gradient: [Color(0xFF7B5EA7), Color(0xFF5B4380), Color(0xFF3A2A55)],
  ),
  SceneIllustration(
    keywords: ['校长办公室', '邓布利多办公室'],
    title: '校长办公室',
    icon: Icons.door_front_door,
    emoji: '🦉',
    gradient: [Color(0xFF8A6D3B), Color(0xFF63502C), Color(0xFF3E311B)],
  ),
  SceneIllustration(
    keywords: ['公共休息室', '休息室', '格兰芬多塔', '拉文克劳塔', '赫奇帕奇地下室', '宿舍', '塔楼'],
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
    keywords: ['陋居', '女贞路', '家', '庄园'],
    title: '家',
    icon: Icons.home,
    emoji: '🏠',
    gradient: [Color(0xFF8A7B5E), Color(0xFF665A44), Color(0xFF403828)],
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
SceneIllustration resolveSceneIllustration(String? location) {
  if (location == null || location.trim().isEmpty) {
    return kDefaultSceneIllustration;
  }
  // 收集所有 (关键词, 场景) 并按关键词长度降序，保证长词优先
  final candidates = <({String keyword, SceneIllustration scene})>[];
  for (final scene in kSceneIllustrations) {
    for (final kw in scene.keywords) {
      candidates.add((keyword: kw, scene: scene));
    }
  }
  candidates.sort((a, b) => b.keyword.length.compareTo(a.keyword.length));
  for (final c in candidates) {
    if (location.contains(c.keyword)) return c.scene;
  }
  return kDefaultSceneIllustration;
}
