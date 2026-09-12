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
    description: '''聪明独立的送信伙伴，能远距离传递信息。
雪白的羽毛在月光下泛着微光，它站在窗台上歪着头看你的样子，
像一位矜持的邮差在核对收件人。爪子有力，认路的本事在魔法界数一数二——
哪怕你把信寄到麻瓜的伦敦街头，它也能找到那扇该落脚的窗。''',
    species: '猫头鹰',
    abilities: ['送信', '侦察', '护主'],
  ),
  PetDef(
    id: 'cat',
    name: '巫师猫',
    description: '''神秘的小巫师，能感知危险，偶尔预知未来。
它总在你最需要的时候出现，又在你回过神之前消失。琥珀色的瞳孔
像两枚硬币，盯着虚空时，仿佛在阅读某种只有猫能看见的预兆。
传闻霍格沃茨的猫都通晓一些连教授都不知道的秘密。''',
    species: '猫',
    abilities: ['预知', '感知魔力', '夜视'],
  ),
  PetDef(
    id: 'toad',
    name: '蟾蜍',
    description: '''传统而忠诚的伙伴，对魔药原料有天然敏感度。
它安静得像一枚石头，却能在一英里外嗅到曼德拉草的动静。
魔药课上，它趴在你肩头，鼓鼓的眼睛盯着坩埚——据说蟾蜍
能分辨出火候与药材的微妙关系，是魔药大师的老搭档。''',
    species: '蟾蜍',
    abilities: ['识药', '安神', '藏匿'],
  ),
  PetDef(
    id: 'rat',
    name: '老鼠',
    description: '''小巧机灵，好奇心旺盛，能钻进狭小空间寻宝。
它把霍格沃茨的地板缝当自己的王国，今天叼来一枚发卡，
明天在墙洞里囤满面包屑。别看它个子小，认路、听声、找东西
样样在行——有时候它比活点地图更清楚城堡的暗路。''',
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
