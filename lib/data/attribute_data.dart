/// 玩家属性（Player.attributes）的唯一权威：key 集合、中文名、学业相关子集。
///
/// 之前同一个属性在两处有两套翻译，而且**互相矛盾**：
///  - mixin_systems.attrLabel:'potions' → '魔药'、'magic_control' → '魔法控制'、
///    'observation' → '观察力'
///  - mixin_play._attrLabelZh:'potions' → '魔药学'、'magic_control' → '魔力控制'、
///    'observation' → '洞察力'
/// 玩家在物品属性加成、宠物训练反馈里看到「魔药学」「魔力控制」「洞察力」，
/// 到了任务需求、AI 上下文里就变成「魔药」「魔法控制」「观察力」。
///
/// 统一后的取值依据：
///  - 'potions' → '魔药学'，跟课程名（course_data 里 '魔药学'）对齐
///  - 'magic_control' → '魔力控制'，跟 MP 在 UI 上叫「魔力」对齐
///  - 'observation' → '观察力'，直译，且它是「保护神奇生物」课的属性
library;

/// 属性 key → 中文名。
const Map<String, String> kAttributeLabels = {
  'spell_understanding': '魔咒理解',
  'transfiguration': '变形术',
  'potions': '魔药学',
  'herbology': '草药学',
  'dda': '黑魔法防御',
  'flying': '飞行',
  'theory': '理论知识',
  'memory': '记忆力',
  'observation': '观察力',
  'magic_control': '魔力控制',
  'reaction_time': '反应速度',
  'emotional_stability': '情绪稳定',
  'creativity': '创造力',
  'social': '社交',
  'courage': '勇气',
  'caution': '谨慎',
  'willpower': '意志',
  'logic': '逻辑',
  'intuition': '直觉',
};

/// 学业相关属性：课程表（lib/data/course_data.dart）里会提升的那些。
///
/// 用来给「上课/考试/复习」这类行动筛选要注入 AI 上下文的属性。原先那里
/// 写的是 const {'智慧', '魔力', '勤奋'}——属性表里压根没有这三个名字，
/// 过滤结果恒为空，【学业】上下文从来没真正注入过。
///
/// 内容和 allCourses() 的 attribute 字段保持一致，由
/// test/progression_fix_test.dart 的测试双向钉住。
const Set<String> kStudyAttributeKeys = {
  'spell_understanding',
  'transfiguration',
  'potions',
  'herbology',
  'dda',
  'flying',
  'theory',
  'memory',
  'observation',
  'creativity',
  'logic',
  'intuition',
};

/// 属性 key → 中文名。未知 key 原样返回（比显示「未知」更好排查）。
String attributeLabel(String key) => kAttributeLabels[key] ?? key;
