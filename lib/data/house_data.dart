/// 学院 key ↔ 中文名 的唯一权威。
///
/// 之前这个映射在项目里有 5 份手写副本：mixin_init / mixin_play（三处）
/// 各写一遍 switch，UI 层的 UiHelpers.getHouseLabel 再写一遍，
/// 而且各自的默认值还不一样（'对手' / '（未分院）' / '格兰芬多' / '未分院'）。
/// 加一个新学院或者改一个译名要改 5 个地方，漏一处就是"同一件事两种说法"。
///
/// 放在数据层（不 import material），mixin 和 UI 都能用。
const Map<String, String> kHouseDisplayNames = {
  'Gryffindor': '格兰芬多',
  'Slytherin': '斯莱特林',
  'Ravenclaw': '拉文克劳',
  'Hufflepuff': '赫奇帕奇',
};

/// 四个学院 key（顺序固定：用于随机对手池这类需要稳定顺序的场景）。
const List<String> kHouseKeys = [
  'Gryffindor',
  'Slytherin',
  'Ravenclaw',
  'Hufflepuff',
];

/// 四个学院中文名（顺序同 [kHouseKeys]）。
List<String> get kHouseNames =>
    kHouseKeys.map((k) => kHouseDisplayNames[k]!).toList(growable: false);

/// 学院 key → 中文名。未知 key 返回 [fallback]。
///
/// [fallback] 留了口子是因为调用方的语境不同：叙事里未分院要写"（未分院）"，
/// 魁地奇对手池里要写"对手"，UI 标签里要写"未分院"。
String houseDisplayName(String? key, {String fallback = '未分院'}) {
  if (key == null) return fallback;
  final exact = kHouseDisplayNames[key];
  if (exact != null) return exact;
  // 兼容 'gryffindor' 这类大小写不一致的写法（老存档和 NPC 数据里都见过）
  final lower = key.toLowerCase();
  for (final entry in kHouseDisplayNames.entries) {
    if (entry.key.toLowerCase() == lower) return entry.value;
  }
  return fallback;
}

/// 中文名 / 英文 key → 学院 key（Gryffindor 等）；认不出来返回 null。
String? houseKeyByDisplayName(String text) {
  if (text.contains('格兰芬多') || text.contains('Gryffindor')) {
    return 'Gryffindor';
  }
  if (text.contains('斯莱特林') || text.contains('Slytherin')) {
    return 'Slytherin';
  }
  if (text.contains('拉文克劳') || text.contains('Ravenclaw')) {
    return 'Ravenclaw';
  }
  if (text.contains('赫奇帕奇') || text.contains('Hufflepuff')) {
    return 'Hufflepuff';
  }
  return null;
}
