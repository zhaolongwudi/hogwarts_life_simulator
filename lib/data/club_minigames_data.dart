/// 社团专属小玩法数据（框架2 新增 · 批次B 命令层）。
///
/// 为四社玩法提供静态数据：
///  - 魔药部限时配方表 [kPotionRecipes]（9 种，含材料/产出/窗口映射）
///  - 魁地奇队训练文案 [kQuidditchTrainMoments]（4 位置 × 2 套）
///
/// 设计文档：docs/魔药部限时配方设计.md、docs/魁地奇队训练设计.md。
/// 纯玩法层数据，不触碰现有 4 种效果药商店链路与 P8 比赛叙事。
library;

// ==================== 魔药部限时配方 ====================
/// 限时窗口：每学期 3 个（开学季/圣诞季/冲刺季）。
/// [PotionWindow] 用月份判定（复用节庆模式，无新增时间字段）。
class PotionWindow {
  final String id;
  final String name;
  /// 触发月份（1-12）。
  final int month;
  const PotionWindow({required this.id, required this.name, required this.month});
}

const List<PotionWindow> kPotionWindows = [
  PotionWindow(id: 'opening', name: '开学季', month: 9),
  PotionWindow(id: 'christmas', name: '圣诞季', month: 12),
  PotionWindow(id: 'sprint', name: '冲刺季', month: 5),
];

/// 单个配方定义。
class PotionRecipeDef {
  final String id;
  final String name; // 配方名
  final String productName; // 产出药水名（进背包）
  final Map<String, int> materials; // 材料名 → 数量
  final String effectKey; // 生效属性 key（复用 /使用 生效链路）
  final int effectValue; // 生效数值
  final int windowIndex; // 所属窗口（0=开学季 1=圣诞季 2=冲刺季）
  const PotionRecipeDef({
    required this.id,
    required this.name,
    required this.productName,
    required this.materials,
    required this.effectKey,
    required this.effectValue,
    required this.windowIndex,
  });
}

/// 9 种配方：产出均为一次性效果药，进背包 /使用 生效，商店买不到。
/// 窗口映射：开学季 3 基础 + 圣诞季 3 进阶 + 冲刺季 3 高阶。
const List<PotionRecipeDef> kPotionRecipes = [
  // ---- 开学季（windowIndex 0）----
  PotionRecipeDef(
    id: 'cheer',
    name: '欢欣剂',
    productName: '欢欣药剂',
    materials: {'独角兽毛': 2},
    effectKey: 'spirit',
    effectValue: 40,
    windowIndex: 0,
  ),
  PotionRecipeDef(
    id: 'clarity',
    name: '清醒剂',
    productName: '清醒药剂',
    materials: {'银色鳞片': 2},
    effectKey: 'energy',
    effectValue: 40,
    windowIndex: 0,
  ),
  PotionRecipeDef(
    id: 'heartguard',
    name: '护心剂',
    productName: '护心药剂',
    materials: {'龙血': 2},
    effectKey: 'health',
    effectValue: 40,
    windowIndex: 0,
  ),
  // ---- 圣诞季（windowIndex 1）----
  PotionRecipeDef(
    id: 'witboost',
    name: '增智剂',
    productName: '增智药剂',
    materials: {'凤羽': 2},
    effectKey: 'magic',
    effectValue: 40,
    windowIndex: 1,
  ),
  PotionRecipeDef(
    id: 'antivenom',
    name: '抗毒剂',
    productName: '抗毒药剂',
    materials: {'蛇的毒牙': 2},
    effectKey: 'spirit',
    effectValue: 30,
    windowIndex: 1,
  ),
  PotionRecipeDef(
    id: 'spiderbrew',
    name: '蛛毒合剂',
    productName: '蛛毒药剂',
    materials: {'八眼巨蛛毒液': 2},
    effectKey: 'magic',
    effectValue: 30,
    windowIndex: 1,
  ),
  // ---- 冲刺季（windowIndex 2）----
  PotionRecipeDef(
    id: 'moonlight',
    name: '月华剂',
    productName: '月华药剂',
    materials: {'月长石粉': 2},
    effectKey: 'courage',
    effectValue: 50,
    windowIndex: 2,
  ),
  PotionRecipeDef(
    id: 'mandrake_soup',
    name: '曼德拉汤',
    productName: '曼德拉汤',
    materials: {'曼德拉草叶': 2},
    effectKey: 'health',
    effectValue: 60,
    windowIndex: 2,
  ),
  PotionRecipeDef(
    id: 'omnielixir',
    name: '全能剂',
    productName: '全能药剂',
    materials: {'曼德拉草叶': 1, '月长石粉': 1},
    effectKey: 'magic',
    effectValue: 60,
    windowIndex: 2,
  ),
];

/// 当前月份对应窗口（无则 null）。
PotionWindow? potionWindowForMonth(int month) {
  for (final w in kPotionWindows) {
    if (w.month == month) return w;
  }
  return null;
}

/// 指定窗口内的配方列表。
List<PotionRecipeDef> potionRecipesInWindow(int windowIndex) =>
    kPotionRecipes.where((r) => r.windowIndex == windowIndex).toList();

/// 按产出药水名查配方（`/使用` 兜底生效用，酿造药水不进 kItemCatalog）。
PotionRecipeDef? potionRecipeByProduct(String productName) {
  for (final r in kPotionRecipes) {
    if (r.productName == productName) return r;
  }
  return null;
}

// ==================== 魁地奇队训练 ====================
/// 位置专项训练文案（4 位置 × 2 套）。
class QuidditchTrainMoment {
  final String text;
  const QuidditchTrainMoment({required this.text});
}

const Map<String, List<QuidditchTrainMoment>> kQuidditchTrainMoments = {
  '找球手': [
    QuidditchTrainMoment(
      text:
          '你松开扫帚柄，让身体几乎贴平帚杆，向那颗悬停的金色飞贼俯冲。'
          '指尖掠过它冰凉的翅膀，差一点就够到了。'
          '教练在场边喊：「手腕再松一点！你不是在抓它，是在等它自己落进你手里！」',
    ),
    QuidditchTrainMoment(
      text:
          '金色飞贼绕着球场打转，你在它身后紧追不舍。'
          '它突然一个急坠，你险些撞上地面，却在最后一刻拉起帚杆。'
          '虽然没抓到，但这一趟冲刺让你的眼力又准了几分。',
    ),
  ],
  '追球手': [
    QuidditchTrainMoment(
      text:
          '你夹着鬼飞球绕场疾飞，两名队友在两侧接应。'
          '你一个假动作晃过防守，把球稳稳传给队友——配合越来越默契了。',
    ),
    QuidditchTrainMoment(
      text:
          '你在三个球门前反复练习投射，球一次次精准入环。'
          '守门员没好气地抱怨：「你到底练了多少次？这球都快被你投出印子了！」',
    ),
  ],
  '守门员': [
    QuidditchTrainMoment(
      text:
          '你在三个圆环前来回飞扑，队友轮流向你投球。'
          '连续扑出三个刁钻角度后，连对手都忍不住为你叫好。',
    ),
    QuidditchTrainMoment(
      text:
          '训练赛里你死死守住球门，视线在鬼飞球与游走球之间来回切换。'
          '一个飞身救球后，霍琦夫人难得地点了点头：「反应不错，保持住。」',
    ),
  ],
  '击球手': [
    QuidditchTrainMoment(
      text:
          '你抡圆球棒，把游走球狠狠抽向预定方向。'
          '球在空中划出一道弧线，正好把对面阵型撕开一个口子。'
          '「就这个力度！」队长在场边喊道。',
    ),
    QuidditchTrainMoment(
      text:
          '你追着游走球满场跑，练习预判它的弹道。'
          '一记精准的截击把球打向对手找球手的方向，迫使他放弃追飞贼的路线。',
    ),
  ],
};

/// 位置对应的训练属性成长 key。
String quidditchTrainAttrOf(String position) =>
    switch (position) {
      '找球手' => 'reaction_time',
      '追球手' => 'flying',
      '守门员' => 'reaction_time',
      '击球手' => 'flying',
      _ => 'flying',
    };
