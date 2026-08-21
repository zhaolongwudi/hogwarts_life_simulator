/// 宠物数据定义
/// 依据玩家需求添加九尾狐（东方神话背景）
class PetDef {
  final String id;
  final String name;
  final String description;
  final String species;
  final bool canTransform;
  final List<String> abilities;

  const PetDef({
    required this.id,
    required this.name,
    required this.description,
    required this.species,
    this.canTransform = false,
    this.abilities = const [],
  });
}

const List<PetDef> allPets = [
  PetDef(
    id: 'owl',
    name: '雪鸮',
    description: '聪明独立的送信伙伴，能远距离传递信息',
    species: '猫头鹰',
    abilities: ['送信', '侦察'],
  ),
  PetDef(
    id: 'cat',
    name: '巫师猫',
    description: '神秘的小巫师，能感知危险，偶尔预知未来',
    species: '猫',
    abilities: ['预知', '感知魔力'],
  ),
  PetDef(
    id: 'toad',
    name: '蟾蜍',
    description: '传统而忠诚的伙伴，对魔药原料有天然敏感度',
    species: '蟾蜍',
    abilities: ['识药'],
  ),
  PetDef(
    id: 'rat',
    name: '老鼠',
    description: '小巧机灵，好奇心旺盛，能钻进狭小空间寻宝',
    species: '老鼠',
    abilities: ['侦察', '寻物'],
  ),
  PetDef(
    id: 'kyuubi',
    name: '九尾灵狐·绯月',
    description: '''来自东方古国青丘的九尾灵狐。
传说中九尾狐乃上古祥瑞，法力高深者可化为人形。
绯月与玩家缔结契约后完全听命，化形时为倾国倾城的女子。
性格温柔聪慧，对主人绝对忠诚。''',
    species: '九尾灵狐',
    canTransform: true,
    abilities: ['幻术', '魅惑', '预知', '灵视', '化形', '治愈'],
  ),
];

PetDef? petById(String id) {
  for (final p in allPets) {
    if (p.id == id) return p;
  }
  return null;
}
