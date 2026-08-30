/// 魔法生物图鉴数据：禁林探险/遭遇事件的统一数据源。
class CreatureDef {
  final String id;
  final String name;
  final int danger; // 1-5 危险度
  final String habitat;
  final String desc;
  final List<String> loot; // 掉落材料名
  final int bond; // 遭遇后收获的图鉴/羁绊印象

  const CreatureDef({
    required this.id,
    required this.name,
    required this.danger,
    required this.habitat,
    this.desc = '',
    this.loot = const [],
    this.bond = 1,
  });
}

const List<CreatureDef> kCreatureCatalog = [
  CreatureDef(
    id: 'niffler',
    name: '嗅嗅',
    danger: 1,
    habitat: '禁林边缘 / 霍格莫德',
    desc: '对一切闪闪发光的东西毫无抵抗力，口袋里藏满了金加隆。',
    bond: 2,
  ),
  CreatureDef(
    id: 'bowtruckle',
    name: '护树罗锅',
    danger: 1,
    habitat: '禁林树木',
    desc: '巴掌大的小精灵，是制作魔杖的树木守护者，喂食土鳖可获好感。',
    bond: 2,
  ),
  CreatureDef(
    id: 'gnome',
    name: '地精',
    danger: 1,
    habitat: '花园 / 菜地',
    desc: '喜欢挖洞捣蛋的小家伙，被扔过花园围栏时会发出刺耳的尖叫。',
    bond: 1,
  ),
  CreatureDef(
    id: 'mooncalf',
    name: '月痴兽',
    danger: 2,
    habitat: '禁林 · 月光下的空地',
    desc: '蓝白色的害羞生物，只在月圆时出来跳舞，粪便是最上等的肥料。',
    // 月痴兽是温顺草食生物，不该掉「独角兽毛」（那是独角兽的专属掉落）。
    // 不给掉落（与嗅嗅/护树罗锅/地精一致），保持语义正确。
    bond: 2,
  ),
  CreatureDef(
    id: 'unicorn',
    name: '独角兽',
    danger: 2,
    habitat: '禁林深处',
    desc: '圣洁的银白色独角兽，幼崽通体金黄。它们只亲近纯净的灵魂。',
    loot: ['独角兽毛'],
    bond: 3,
  ),
  CreatureDef(
    id: 'hippogriff',
    name: '鹰头马身有翼兽',
    danger: 3,
    habitat: '禁林 / 海格的小屋附近',
    desc: '鹰首马身，必须向它鞠躬以示尊重，否则会被利爪招呼。',
    loot: ['凤羽'],
    bond: 3,
  ),
  CreatureDef(
    id: 'troll',
    name: '巨怪',
    danger: 3,
    habitat: '禁林深处 / 地下教室',
    desc: '十二英尺高，头脑简单力气大，最爱把棍子砸向所有会动的东西。',
    // 巨怪掉「巨怪指甲」而非「龙血」：以前掉龙血让 3 年级玩家（龙 danger=5
    // 需 5 年级）靠杀巨怪就能完成「龙血的诱惑」委托，语义与等级都错位。
    loot: ['巨怪指甲'],
    bond: 2,
  ),
  CreatureDef(
    id: 'acromantula',
    name: '八眼巨蛛',
    danger: 4,
    habitat: '禁林深处',
    desc: '能说话的巨大蜘蛛，集体行动，会毫不犹豫地捕食猎物。',
    // 蜘蛛掉「八眼巨蛛毒液」而非「蛇的毒牙」：蛇的毒牙是蛇怪专属材料
    // （能贯穿魂器），八眼巨蛛的剧毒才是它自己的掉落，委托也据此改名。
    loot: ['八眼巨蛛毒液'],
    bond: 2,
  ),
  CreatureDef(
    id: 'thunderbird',
    name: '雷鸟',
    danger: 4,
    habitat: '云端 / 禁林上空',
    desc: '翼展遮天蔽日，振翅便能召来雷暴，尾羽可作魔杖杖芯。',
    loot: ['凤羽'],
    bond: 3,
  ),
  CreatureDef(
    id: 'dragon_norwegian',
    name: '挪威脊背龙',
    danger: 5,
    habitat: '禁林深处',
    desc: '幼年火龙已是凶悍至极，喷出的火焰能瞬间熔化铁器。',
    loot: ['龙血'],
    bond: 3,
  ),
  CreatureDef(
    id: 'dragon_hungarian',
    name: '匈牙利树蜂',
    danger: 5,
    habitat: '禁林深处',
    desc: '最凶残的火龙品种，尾部长着尖刺，连火焰都偏爱喷向活物。',
    loot: ['龙血'],
    bond: 3,
  ),
  CreatureDef(
    id: 'dementor',
    name: '摄魂怪',
    danger: 5,
    habitat: '阿兹卡班 / 阴冷处',
    desc: '披着破斗篷的可怕存在，吸走快乐与希望，被守护神咒克制。',
    bond: 2,
  ),
];

// 注：creatureById 已删——图鉴只按 id 记录发现进度
// （player.bestiary 存 id，展示时直接遍历 kCreatureCatalog），
// 玩家养的宠物走 pet_data.petById，这条反查零调用。
// creatureByName 保留：测试用它校验委托目标生物确实存在于图鉴。

/// 按名字查图鉴条目。生产代码不调用，但委托数据一致性测试依赖它。
CreatureDef? creatureByName(String name) {
  for (final c in kCreatureCatalog) {
    if (c.name == name) return c;
  }
  return null;
}

String dangerLabel(int danger) => switch (danger) {
      1 => '人畜无害',
      2 => '谨慎接触',
      3 => '危险生物',
      4 => '高危生物',
      _ => '致命',
    };
