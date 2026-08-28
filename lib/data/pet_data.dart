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
    abilities: ['送信', '侦察', '护主'],
  ),
  PetDef(
    id: 'cat',
    name: '巫师猫',
    description: '神秘的小巫师，能感知危险，偶尔预知未来',
    species: '猫',
    abilities: ['预知', '感知魔力', '夜视'],
  ),
  PetDef(
    id: 'toad',
    name: '蟾蜍',
    description: '传统而忠诚的伙伴，对魔药原料有天然敏感度',
    species: '蟾蜍',
    abilities: ['识药', '安神', '藏匿'],
  ),
  PetDef(
    id: 'rat',
    name: '老鼠',
    description: '小巧机灵，好奇心旺盛，能钻进狭小空间寻宝',
    species: '老鼠',
    abilities: ['侦察', '寻物', '钻缝'],
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
    abilities: ['幻术', '魅惑', '化形', '治愈'],
  ),
];

PetDef? petById(String id) {
  for (final p in allPets) {
    if (p.id == id) return p;
  }
  return null;
}

/// 对角巷「咿啦猫头鹰商店」的在售宠物与售价（加隆）。
///
/// 之前 /宠物 在没有宠物时会告诉玩家「可以去对角巷挑选一只猫头鹰、猫或
/// 蟾蜍」——但商店里根本没有宠物卖，这句提示把人指到了一条死路上：
/// 开局问卷跳过宠物的玩家再也拿不到宠物，而 /宠物 喂食 /玩耍 /训练
/// 三个子指令和「宠物助战」「羁绊化形」这些机制也全都废了。
///
/// 九尾灵狐是契约灵兽，只在开局问卷里结缘，不卖。
const Map<String, int> kPetPrices = {
  'owl': 30,
  'cat': 25,
  'toad': 12,
  'rat': 8,
};

/// 能在对角巷买到的宠物。
Iterable<PetDef> get purchasablePets =>
    allPets.where((p) => kPetPrices.containsKey(p.id));

/// 宠物的默认名字（玩家没起名时用）。
///
/// 开局问卷和"买了还没起名"两种情况共用一份，免得两处各写一份 switch。
const Map<String, String> kPetDefaultNames = {
  'owl': '雪鸮',
  'cat': '猫',
  'toad': '蟾蜍',
  'rat': '老鼠',
  'kyuubi': '绯月',
};

/// 按 id / 名字 / 物种 / 别名找宠物。
///
/// 玩家会输入「猫头鹰」（物种）而不是「雪鸮」（名字），也可能直接敲
/// 「owl」，所以三个字段都得试。
PetDef? findPet(String keyword) {
  final kw = keyword.trim().toLowerCase();
  if (kw.isEmpty) return null;
  for (final p in allPets) {
    if (p.id.toLowerCase() == kw ||
        p.name.toLowerCase() == kw ||
        p.species.toLowerCase() == kw) {
      return p;
    }
  }
  // 退一步：包含匹配（"猫" 命中"巫师猫"、"狐狸" 命中"九尾灵狐"）
  for (final p in allPets) {
    if (p.name.toLowerCase().contains(kw) ||
        p.species.toLowerCase().contains(kw) ||
        kw.contains(p.species.toLowerCase())) {
      return p;
    }
  }
  return null;
}
