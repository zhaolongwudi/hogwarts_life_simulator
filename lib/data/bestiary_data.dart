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
    loot: ['独角兽毛'],
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
    loot: ['龙血'],
    bond: 2,
  ),
  CreatureDef(
    id: 'acromantula',
    name: '八眼巨蛛',
    danger: 4,
    habitat: '禁林深处',
    desc: '能说话的巨大蜘蛛，集体行动，会毫不犹豫地捕食猎物。',
    loot: ['蛇的毒牙'],
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

CreatureDef? creatureById(String id) {
  for (final c in kCreatureCatalog) {
    if (c.id == id) return c;
  }
  return null;
}

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
