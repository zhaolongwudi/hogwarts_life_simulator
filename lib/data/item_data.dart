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
    id: 'copper_amulet',
    name: '铜制护符',
    type: '装备',
    price: 25,
    desc: '霍格莫德小摊上最常见的护符，聊胜于无',
    equipSlot: 'amulet',
    statBonus: {'magic_control': 2},
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
    id: 'ward_chain',
    name: '守护符链',
    type: '装备',
    price: 75,
    desc: '刻满如尼文的银链，佩戴时能挡下多数恶咒',
    equipSlot: 'amulet',
    statBonus: {'courage': 6, 'magic_control': 4},
    combatBonus: 6,
    castBonus: 25,
  ),
  ItemDef(
    id: 'time_amulet',
    name: '时间护符',
    type: '装备',
    price: 130,
    desc: '沙漏造型的挂坠，转动时周围的声音会慢半拍',
    equipSlot: 'amulet',
    statBonus: {'magic_control': 9, 'reaction_time': 5},
    combatBonus: 4,
    castBonus: 45,
  ),
  ItemDef(
    id: 'wool_hat',
    name: '保暖毛线帽',
    type: '装备',
    price: 20,
    desc: '韦斯莱夫人手织，耳朵一点都不冷',
    equipSlot: 'hat',
    statBonus: {'emotional_stability': 3},
  ),
  ItemDef(
    id: 'disguise_hat',
    name: '伪装帽',
    type: '装备',
    price: 48,
    desc: '帽檐压低时，熟人也认不出你',
    equipSlot: 'hat',
    statBonus: {'observation': 5, 'intuition': 3},
    combatBonus: 1,
    castBonus: 8,
  ),
  ItemDef(
    id: 'star_hat',
    name: '星级巫师帽',
    type: '装备',
    price: 95,
    desc: '帽尖缀着会缓缓转动的星图，天文学教授看了都要点头',
    equipSlot: 'hat',
    statBonus: {'logic': 6, 'theory': 4},
    castBonus: 30,
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
  // ===== 礼物 =====
  // 这一整类的存在理由：archetype_data 的原型礼物偏好表里写着这些名字，
  // 但它们此前根本不在目录里——玩家送不出任何一件 NPC 真心喜欢的东西，
  // 送礼退化成「只有巧克力蛙能送中」。这里把它们补成可购买的真实物品。
  ItemDef(
    id: 'quidditch_badge',
    name: '魁地奇徽章',
    type: '礼物',
    price: 25,
    desc: '珐琅烤漆的院队徽章，别在校袍上很神气',
  ),
  ItemDef(
    id: 'courage_medal',
    name: '勇气勋章',
    type: '礼物',
    price: 45,
    desc: '梅林爵士团同款仿制品，沉甸甸的',
  ),
  ItemDef(
    id: 'old_book',
    name: '旧书',
    type: '礼物',
    price: 18,
    desc: '书页发黄，边角有人密密麻麻写过批注',
  ),
  ItemDef(
    id: 'flower_bouquet',
    name: '花束',
    type: '礼物',
    price: 15,
    desc: '禁林边缘采的野花，还带着露水',
  ),
  ItemDef(
    id: 'greeting_card',
    name: '手写贺卡',
    type: '礼物',
    price: 8,
    desc: '你一笔一划写下的祝福，字迹比内容更打动人',
  ),
  ItemDef(
    id: 'plan_book',
    name: '计划书',
    type: '礼物',
    price: 20,
    desc: '装订整齐的五年规划，翻开来全是表格',
  ),
  ItemDef(
    id: 'silver_pen',
    name: '银色钢笔',
    type: '礼物',
    price: 35,
    desc: '笔尖镀银，写出来的字会微微发亮',
  ),
  ItemDef(
    id: 'knitted_scarf',
    name: '编织围巾',
    type: '礼物',
    price: 22,
    desc: '粗针脚，但足够长，能绕两圈',
  ),
  ItemDef(
    id: 'homemade_snack',
    name: '自制点心',
    type: '礼物',
    price: 10,
    desc: '厨房里偷烤的，形状不太规整',
  ),
  ItemDef(
    id: 'mystic_symbol',
    name: '神秘符号',
    type: '礼物',
    price: 30,
    desc: '一枚看不懂用途的黄铜符文，摸上去微热',
  ),
  ItemDef(
    id: 'magic_prop',
    name: '魔法道具',
    type: '礼物',
    price: 40,
    desc: '佐科笑话店的正品，效果保证出人意料',
  ),
  ItemDef(
    id: 'prank_toy',
    name: '恶作剧玩具',
    type: '礼物',
    price: 20,
    desc: '会咬人的橡皮鸡，弗立维教授见过一次就够了',
  ),
  ItemDef(
    id: 'joke_book',
    name: '笑话集',
    type: '礼物',
    price: 16,
    desc: '皮皮鬼据说也有一本',
  ),
  ItemDef(
    id: 'punk_accessory',
    name: '朋克饰品',
    type: '礼物',
    price: 28,
    desc: '铆钉与皮革，麻瓜世界带来的叛逆',
  ),
  ItemDef(
    id: 'rock_album',
    name: '摇滚专辑',
    type: '礼物',
    price: 24,
    desc: '麻瓜乐队的唱片，封面上的人头发比你还乱',
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
    id: 'acromantula_venom',
    name: '八眼巨蛛毒液',
    type: '材料',
    price: 30,
    desc: '八眼巨蛛的剧毒，稀有魔药的关键材料',
  ),
  ItemDef(
    id: 'phoenix_feather',
    name: '凤羽',
    type: '材料',
    price: 25,
    desc: '金色的凤凰尾羽，无比珍稀',
  ),
  // 稀有材料：只在禁林深处、委托奖励里出现，不在普通采集池里
  ItemDef(
    id: 'mandrake_leaf',
    name: '曼德拉草叶',
    type: '材料',
    price: 35,
    desc: '成熟曼德拉草的叶片，采摘时最好塞住耳朵',
  ),
  ItemDef(
    id: 'moonstone_powder',
    name: '月长石粉',
    type: '材料',
    price: 30,
    desc: '研磨到极细的月长石，魔药的稳定剂',
  ),
  ItemDef(
    id: 'troll_nail',
    name: '巨怪指甲',
    type: '材料',
    price: 28,
    desc: '厚硬发黄，气味不太好闻，但很值钱',
  ),
  ItemDef(
    id: 'grindylow_hair',
    name: '水妖毛发',
    type: '材料',
    price: 40,
    desc: '从黑湖边的水妖巢附近捡到的，泡过水的那种滑腻触感',
  ),
  ItemDef(
    id: 'ashwinder_egg',
    name: '火灰蛇蛋',
    type: '材料',
    price: 45,
    desc: '从壁炉余烬里刨出来的，握在手里烫得惊人',
  ),
  ItemDef(
    id: 'thestral_tail',
    name: '夜骐尾羽',
    type: '材料',
    price: 55,
    desc: '只有见过死亡的人才能看见它原来的主人',
  ),
];

ItemDef? itemDefByName(String name) {
  for (final d in kItemCatalog) {
    if (d.name == name) return d;
  }
  return null;
}

// 注：itemDefById 已删——背包里存的是物品**名字**（InventoryItem.name），
// 全项目没有任何地方按 id 反查物品，这个函数只是个常年零调用的陷阱。

List<ItemDef> equippableItems() =>
    kItemCatalog.where((d) => d.isEquippable).toList();

List<ItemDef> usableItems() => kItemCatalog.where((d) => d.usable).toList();

/// 禁林/委托产出材料（统一来源，避免各处硬编码）
///
/// 分两档而不是一个大池子：此前禁林采集是在 4 种里均匀取一，跑十趟禁林
/// 拿到的东西大同小异，「翻树根」这件事很快就没什么可期待的了。
const List<String> kCommonLootMaterials = ['独角兽毛', '蛇的毒牙', '龙血', '凤羽'];

/// 稀有材料：出得少、卖得贵，也是送礼时的高价值选择。
const List<String> kRareLootMaterials = [
  '曼德拉草叶',
  '月长石粉',
  '巨怪指甲',
  '水妖毛发',
  '火灰蛇蛋',
  '夜骐尾羽',
];

/// 稀有材料在采集时的占比（千分比）。
const int kRareLootRatePerThousand = 150;

/// 按稀有度摇一种采集产物。传入 0~999 的随机数便于测试固定结果。
String rollLootMaterial(int rollPerThousand) {
  final pool = rollPerThousand < kRareLootRatePerThousand
      ? kRareLootMaterials
      : kCommonLootMaterials;
  return pool[rollPerThousand % pool.length];
}

/// 已穿戴装备的决斗战力加成总和。
///
/// 之前 mixin_play._equipmentCombatBonus 和 game_play_screens._combatBonus
/// 各写一遍同样的循环。装备页显示的加成和实际打决斗用的加成一旦算法分叉，
/// 玩家会看到「+5」打出来却只有「+3」。
int equippedCombatBonus(Map<String, String> equipped) {
  var sum = 0;
  equipped.forEach((slot, name) {
    final def = itemDefByName(name);
    if (def != null) sum += def.combatBonus;
  });
  return sum;
}

/// 已穿戴装备的施法成功率加成总和（千分比，20 表示 +2%）。
int equippedCastBonus(Map<String, String> equipped) {
  var sum = 0;
  equipped.forEach((slot, name) {
    final def = itemDefByName(name);
    if (def != null) sum += def.castBonus;
  });
  return sum;
}
