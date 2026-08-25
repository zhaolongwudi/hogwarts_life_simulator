/// 物品数据：霍格沃茨商店/背包/物品系统统一数据源。
/// 数据层保持纯净，不依赖 Flutter material（图标由 UI 层按 type 映射）。
class ItemDef {
  final String id;
  final String name;
  final String type; // 食品/药水/装备/材料/书籍/文具/道具
  final int price;
  final String desc;
  final bool usable; // 能否通过 /使用 消耗
  final String? equipSlot; // 装备槽位：robe/hat/broom/amulet
  final Map<String, int> effect; // 使用效果：health/magic/spirit/satiety/energy/属性键；special:'random' 随机
  final Map<String, int> statBonus; // 装备属性加成（attributes 键）
  final int combatBonus; // 装备决斗战力加成
  final int castBonus; // 装备施法成功率加成（千分比，如 20 表示 +2%）

  const ItemDef({
    required this.id,
    required this.name,
    required this.type,
    required this.price,
    this.desc = '',
    this.usable = false,
    this.equipSlot,
    this.effect = const {},
    this.statBonus = const {},
    this.combatBonus = 0,
    this.castBonus = 0,
  });

  bool get isEquippable => equipSlot != null;
}

/// 商店/背包可用物品目录（唯一数据源）
const List<ItemDef> kItemCatalog = [
  // ===== 食品 =====
  ItemDef(
    id: 'chocolate_frog',
    name: '巧克力蛙',
    type: '食品',
    price: 10,
    desc: '会跳的巧克力，附赠著名巫师卡片',
    usable: true,
    effect: {'satiety': 12},
  ),
  ItemDef(
    id: 'acid_pops',
    name: '酸味爆弹',
    type: '食品',
    price: 8,
    desc: '真的很酸，慎入',
    usable: true,
    effect: {'satiety': 8},
  ),
  ItemDef(
    id: 'cauldron_cake',
    name: '坩埚蛋糕',
    type: '食品',
    price: 12,
    desc: '迷你坩埚造型，味道不错',
    usable: true,
    effect: {'satiety': 15},
  ),
  ItemDef(
    id: 'pumpkin_pie',
    name: '南瓜馅饼',
    type: '食品',
    price: 8,
    desc: '霍格沃茨餐桌上最常见的味道',
    usable: true,
    effect: {'satiety': 15},
  ),
  ItemDef(
    id: 'butterbeer',
    name: '黄油啤酒',
    type: '食品',
    price: 12,
    desc: '香甜温热，略带奶油泡沫',
    usable: true,
    effect: {'satiety': 10, 'spirit': 5},
  ),
  ItemDef(
    id: 'berties_every_flavor',
    name: '比比多味豆',
    type: '食品',
    price: 6,
    desc: '一口下去，可能是草莓也可能是耳屎',
    usable: true,
    effect: {'special': 1},
  ),
  // ===== 药水 =====
  ItemDef(
    id: 'essence_dittany',
    name: '白鲜香精',
    type: '药水',
    price: 25,
    desc: '强力愈合剂，能快速止血疗伤',
    usable: true,
    effect: {'health': 25},
  ),
  ItemDef(
    id: 'pepperup',
    name: '提神剂',
    type: '药水',
    price: 20,
    desc: '蒸汽从耳朵里冒出来，但人立刻清醒',
    usable: true,
    effect: {'energy': 30},
  ),
  ItemDef(
    id: 'vitality_potion',
    name: '活力滋补剂',
    type: '药水',
    price: 30,
    desc: '滋补魔力，恢复施法储备',
    usable: true,
    effect: {'magic': 30},
  ),
  ItemDef(
    id: 'murtlap',
    name: '莫特拉鼠汁',
    type: '药水',
    price: 18,
    desc: '舒缓精神，清空疲惫的头脑',
    usable: true,
    effect: {'spirit': 20},
  ),
  // ===== 文具 / 书籍 / 道具 =====
  ItemDef(
    id: 'quill',
    name: '新羽毛笔',
    type: '文具',
    price: 20,
    desc: '猫头鹰羽毛，书写流畅',
  ),
  ItemDef(
    id: 'parchment',
    name: '羊皮纸一包',
    type: '文具',
    price: 25,
    desc: '优质防泼溅羊皮纸 20 张',
  ),
  ItemDef(
    id: 'standard_book',
    name: '标准咒语书',
    type: '书籍',
    price: 60,
    desc: '一年级课程教材，研读可提升魔咒理解',
    usable: true,
    effect: {'spell_understanding': 2, 'learn_spell': 1},
  ),
  ItemDef(
    id: 'magic_tape',
    name: '魔法胶带',
    type: '道具',
    price: 15,
    desc: '能粘住任何东西的胶带',
  ),
  ItemDef(
    id: 'telescope',
    name: '全效望远镜',
    type: '道具',
    price: 22,
    desc: '天文课必备，也能看见远处的人影',
  ),
  ItemDef(
    id: 'brass_scales',
    name: '黄铜天平',
    type: '道具',
    price: 18,
    desc: '魔药称量用，做工精致',
  ),
  // ===== 装备 =====
  ItemDef(
    id: 'school_robe',
    name: '校袍',
    type: '装备',
    price: 30,
    desc: '崭新的霍格沃茨校袍，院徽闪闪发亮',
    equipSlot: 'robe',
    statBonus: {'dda': 2},
    combatBonus: 2,
  ),
  ItemDef(
    id: 'winter_cloak',
    name: '冬季斗篷',
    type: '装备',
    price: 35,
    desc: '厚实的斗篷，能抵御禁林寒风',
    equipSlot: 'robe',
    statBonus: {'observation': 3},
    combatBonus: 1,
  ),
  ItemDef(
    id: 'witch_hat',
    name: '巫师帽',
    type: '装备',
    price: 25,
    desc: '经典尖顶巫师帽，气场十足',
    equipSlot: 'hat',
    statBonus: {'logic': 3},
    castBonus: 10,
  ),
  ItemDef(
    id: 'lucky_amulet',
    name: '护身符',
    type: '装备',
    price: 40,
    desc: '据说能带来好运，戴久了觉得魔力更稳',
    equipSlot: 'amulet',
    statBonus: {'magic_control': 5},
    combatBonus: 3,
    castBonus: 20,
  ),
  ItemDef(
    id: 'broom_cleansweep',
    name: '飞天扫帚·横扫',
    type: '装备',
    price: 50,
    desc: '横扫牌入门扫帚，稳但不算快',
    equipSlot: 'broom',
    statBonus: {'flying': 5},
    combatBonus: 1,
  ),
  ItemDef(
    id: 'broom_comet',
    name: '飞天扫帚·彗星',
    type: '装备',
    price: 80,
    desc: '彗星牌，速度与操控的均衡之选',
    equipSlot: 'broom',
    statBonus: {'flying': 10},
    combatBonus: 3,
  ),
  // ===== 材料 =====
  ItemDef(
    id: 'unicorn_hair',
    name: '独角兽毛',
    type: '材料',
    price: 15,
    desc: '银白色的独角兽尾毛，杖芯与魔药的上等原料',
  ),
  ItemDef(
    id: 'dragon_blood',
    name: '龙血',
    type: '材料',
    price: 20,
    desc: '火龙之血，强力魔药与炼金材料',
  ),
  ItemDef(
    id: 'basilisk_fang',
    name: '蛇的毒牙',
    type: '材料',
    price: 12,
    desc: '尖锐的毒牙，能贯穿魂器与绝大多数咒语防护',
  ),
  ItemDef(
    id: 'phoenix_feather',
    name: '凤羽',
    type: '材料',
    price: 25,
    desc: '金色的凤凰尾羽，无比珍稀',
  ),
];

ItemDef? itemDefByName(String name) {
  for (final d in kItemCatalog) {
    if (d.name == name) return d;
  }
  return null;
}

ItemDef? itemDefById(String id) {
  for (final d in kItemCatalog) {
    if (d.id == id) return d;
  }
  return null;
}

List<ItemDef> equippableItems() =>
    kItemCatalog.where((d) => d.isEquippable).toList();

List<ItemDef> usableItems() => kItemCatalog.where((d) => d.usable).toList();

/// 禁林/委托产出材料（统一来源，避免各处硬编码）
const List<String> kCommonLootMaterials = ['独角兽毛', '蛇的毒牙', '龙血', '凤羽'];
