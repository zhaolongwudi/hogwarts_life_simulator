/// 魔法世界图鉴（百科收集系统）：玩家在叙事里"亲眼见过/亲耳听到"即收录。
///
/// 与既有两套收集系统的分工：
///  · `bestiary_data.dart`（禁林遭遇图鉴）：只覆盖禁林探险遇到的魔法生物，
///    走"探险结算写入 player.bestiary"的显式路径；
///  · `collectible_data.dart`（收藏品）：巧克力蛙画片等物品抽取，走
///    `/抽奖` 等显式获得路径；
///  · 本文件是**百科式图鉴**：不需要玩家做任何特定操作，只要某一回合的
///    叙事文本里出现了条目的关键词，就算"收录"——扫地式覆盖主线剧情
///    （PS/CoS 的叙事会自然提到分院帽、曼德拉草、密室…）与沙盒日常
///    （事件锚点会提到魁地奇、霍格莫德、三把扫帚…）。
///
/// 【零侵入原则】本系统不要求现有剧情/事件文本做任何改动——关键词是从
/// 文本里"长"出来的：先定条目，再回头用脚本核对关键词确实出现在既有文本
/// 里（测试 `collection_data_test.dart` 里有守卫用例，防止将来改动让关键词
/// 与文本脱节）。新增剧情章节时，顺藤摸瓜补关键词即可。
///
/// 【存档通道】已收录 id 走 `extra_data['collection']`，老存档没有这个键
/// 读进来就是空集合，零迁移。
library;

/// 图鉴五大分类（顺序即 `/图鉴` 面板的展示顺序）。
const List<String> kCollectionCategories = <String>[
  '生物',
  '魔咒',
  '地点',
  '人物',
  '奇物',
];

class CollectionDef {
  final String id;

  /// 所属分类，取值必须是 [kCollectionCategories] 之一。
  final String category;
  final String name;

  /// 百科式一句话说明，收录后在 `/图鉴 详情` 里展示。
  final String desc;

  /// 命中词：叙事文本 `contains` 任一关键词即收录该条目。
  /// 关键词必须足够具体（避免"魔杖"这类每回合都出现的泛词），
  /// 且按原著常用译名书写——见测试守卫用例。
  final List<String> keywords;

  const CollectionDef({
    required this.id,
    required this.category,
    required this.name,
    required this.desc,
    required this.keywords,
  });
}

const List<CollectionDef> kCollectionCatalog = <CollectionDef>[
  // ================= 生物 =================
  CollectionDef(
    id: 'lore_dobby',
    category: '生物',
    name: '多比',
    desc: '一只穿着旧枕套的家养小精灵，说话会顺便揍自己，把主人的事务当成天大的秘密。',
    keywords: ['多比'],
  ),
  CollectionDef(
    id: 'lore_house_elf',
    category: '生物',
    name: '家养小精灵',
    desc: '被古老契约绑在贵族宅邸与城堡里的小生物，魔力强大却卑微得近乎自罚成瘾。',
    keywords: ['家养小精灵', '小精灵'],
  ),
  CollectionDef(
    id: 'lore_basilisk',
    category: '生物',
    name: '蛇怪',
    desc: '由蟾蜍孵出的蛇蛋诞生，与人对视即死，千年一遇的恐怖存在于传说中被称为"密室之王"。',
    keywords: ['蛇怪'],
  ),
  CollectionDef(
    id: 'lore_owl',
    category: '生物',
    name: '信使猫头鹰',
    desc: '巫师界最可靠的邮差，风雪与黑夜都挡不住它找到收件人的执着。',
    keywords: ['猫头鹰'],
  ),
  CollectionDef(
    id: 'lore_nearly_headless',
    category: '生物',
    name: '差点没头的尼克',
    desc: '格兰芬多塔楼的驻馆幽灵，脖子上的斧口让他在"无头骑士狩猎会"上永远只能当观众。',
    keywords: ['差点没头', '尼克'],
  ),
  CollectionDef(
    id: 'lore_mandrake',
    category: '生物',
    name: '曼德拉草',
    desc: '草根是一颗赤裸的婴儿，成熟时哭声致命，幼株的哭声只会让你昏迷数小时——记得戴耳罩。',
    keywords: ['曼德拉草'],
  ),
  CollectionDef(
    id: 'lore_dementor',
    category: '生物',
    name: '摄魂怪',
    desc: '以快乐为食的守卫，靠近它的人会重新活一遍最糟糕的记忆。巧克力是官方推荐的解药。',
    keywords: ['摄魂怪'],
  ),
  CollectionDef(
    id: 'lore_aragog',
    category: '生物',
    name: '阿拉戈克',
    desc: '海格年轻时养在柜子里的八眼巨蛛，如今在禁林深处称王，对"冲进禁林送外卖"的人类毫无胃口。',
    keywords: ['阿拉戈克', '八眼巨蛛'],
  ),
  CollectionDef(
    id: 'lore_fawkes',
    category: '生物',
    name: '福克斯',
    desc: '邓布利多的凤凰，定期烧成灰烬再从灰烬里重生，眼泪能疗愈一切伤口。',
    keywords: ['福克斯', '凤凰'],
  ),
  CollectionDef(
    id: 'lore_peeves',
    category: '生物',
    name: '皮皮鬼',
    desc: '城堡里唯一的捣蛋鬼幽灵，尊重两点：费尔万的虐待狂，以及血腥男爵的凶名。',
    keywords: ['皮皮鬼'],
  ),
  CollectionDef(
    id: 'lore_centaur',
    category: '生物',
    name: '马人',
    desc: '禁林深处的观星者，骄傲而疏离，对人类的占星报告向来只有一句"火星很亮"。',
    keywords: ['马人', '费伦泽'],
  ),
  CollectionDef(
    id: 'lore_acromantula',
    category: '生物',
    name: '八眼巨蛛',
    desc: '能说人语的巨蛛，体型如小马，禁林深处的蛛网传说就是它们的杰作。',
    keywords: ['八眼巨蛛', '大蜘蛛'],
  ),
  // ================= 魔咒 =================
  CollectionDef(
    id: 'lore_expelliarmus',
    category: '魔咒',
    name: '除你武器',
    desc: '缴械咒。决斗场上最不起眼也最致命的一招——夺走对方的魔杖，就夺走了一切。',
    keywords: ['除你武器'],
  ),
  CollectionDef(
    id: 'lore_lumos',
    category: '魔咒',
    name: '荧光闪烁',
    desc: '杖尖亮起一豆白光。黑暗走廊里最温柔的小咒语，熄灭只需一句"诺克斯"。',
    keywords: ['荧光闪烁', '荧光'],
  ),
  CollectionDef(
    id: 'lore_wingardium',
    category: '魔咒',
    name: '漂浮咒',
    desc: '"羽加迪姆 勒维奥萨"——挥杖要利落，别把魔杖甩得像根棍子。',
    keywords: ['漂浮咒', '羽加迪姆'],
  ),
  CollectionDef(
    id: 'lore_serpensortia',
    category: '魔咒',
    name: '乌龙出洞',
    desc: '召出一条活蛇的决斗咒。对蛇佬腔来说，这不算攻击，算"叫来了一个朋友"。',
    keywords: ['乌龙出洞'],
  ),
  CollectionDef(
    id: 'lore_obliviate',
    category: '魔咒',
    name: '一忘皆空',
    desc: '遗忘咒，遗忘事务官的看家本领。被施咒的人只会觉得脑子里缺了一块形状。',
    keywords: ['一忘皆空'],
  ),
  CollectionDef(
    id: 'lore_reparo',
    category: '魔咒',
    name: '修复如初',
    desc: '碎片腾空倒转，恢复原状。日常魔法里使用频率冠军——前提是碎片别太碎。',
    keywords: ['修复如初'],
  ),
  CollectionDef(
    id: 'lore_riddikulus',
    category: '魔咒',
    name: '滑稽滑稽',
    desc: '对付博格特的咒语：心里想着最滑稽的画面念出口，吓人的东西就会穿上滑稽的裤子。',
    keywords: ['滑稽滑稽', '博格特'],
  ),
  CollectionDef(
    id: 'lore_expecto',
    category: '魔咒',
    name: '呼神护卫',
    desc: '召唤守护神的高级咒语，需要集中一个真正快乐的回忆。银白色的守护神能驱散摄魂怪。',
    keywords: ['呼神护卫', '守护神'],
  ),
  CollectionDef(
    id: 'lore_accio',
    category: '魔咒',
    name: '飞来咒',
    desc: '召唤咒。念对名字，远在天边的物件会破空而来——前提是你得配得上它。',
    keywords: ['飞来咒'],
  ),
  // ================= 地点 =================
  CollectionDef(
    id: 'lore_diagon_alley',
    category: '地点',
    name: '对角巷',
    desc: '破釜酒吧后墙一敲即开的魔法商业街，古灵阁、奥利凡德与摩金夫人的长袍店都在这里。',
    keywords: ['对角巷'],
  ),
  CollectionDef(
    id: 'lore_platform',
    category: '地点',
    name: '九又四分之三站台',
    desc: '国王十字车站第九、十站台之间那堵墙。别迟疑，也别推着行李车慢慢挪——冲刺过去。',
    keywords: ['九又四分之三'],
  ),
  CollectionDef(
    id: 'lore_great_hall',
    category: '地点',
    name: '大礼堂',
    desc: '四张长桌与满天蜡烛，天花板的魔法模拟着外面的天空，开学宴与考试都在这里举行。',
    keywords: ['大礼堂'],
  ),
  CollectionDef(
    id: 'lore_restricted_section',
    category: '地点',
    name: '禁书区',
    desc: '图书馆里挂着绳子的角落，书会尖叫、咬人、闭起来打你。进去需要教授签名的条子。',
    keywords: ['禁书区'],
  ),
  CollectionDef(
    id: 'lore_dungeons',
    category: '地点',
    name: '魔药教室',
    desc: '地下教室，常年阴冷，泡在玻璃罐里的东西最好不要盯着看。黑袍教授在这里扣分最快。',
    keywords: ['魔药教室', '地下教室'],
  ),
  CollectionDef(
    id: 'lore_forbidden_forest',
    category: '地点',
    name: '禁林',
    desc: '城堡外的黑色森林，人马、巨蛛与更古老的东西住在里面。关禁闭的学生才需要进去。',
    keywords: ['禁林'],
  ),
  CollectionDef(
    id: 'lore_hogsmeade',
    category: '地点',
    name: '霍格莫德',
    desc: '英国唯一的全魔法村落，三年级以上凭监护人签字才能周末造访的"自由天堂"。',
    keywords: ['霍格莫德'],
  ),
  CollectionDef(
    id: 'lore_three_broomsticks',
    category: '地点',
    name: '三把扫帚',
    desc: '罗斯默塔夫人的酒馆，黄油啤酒与樱桃糖浆汽水是学生们的最爱，小道消息也一样。',
    keywords: ['三把扫帚'],
  ),
  CollectionDef(
    id: 'lore_shrieking_shack',
    category: '地点',
    name: '尖叫棚屋',
    desc: '霍格莫德村外最破的房子，村民说它是英国闹鬼最凶的地方——其实那些尖叫另有真相。',
    keywords: ['尖叫棚屋'],
  ),
  CollectionDef(
    id: 'lore_knockturn_alley',
    category: '地点',
    name: '翻倒巷',
    desc: '对角巷的暗面，博金-博克商店就开在这里，橱窗里的东西最好只看不碰。',
    keywords: ['翻倒巷'],
  ),
  CollectionDef(
    id: 'lore_room_of_requirement',
    category: '地点',
    name: '有求必应屋',
    desc: '八楼挂毯对面的那面墙：只在极度需要时出现，门后永远是你恰好最需要的那个房间。',
    keywords: ['有求必应屋'],
  ),
  CollectionDef(
    id: 'lore_chamber',
    category: '地点',
    name: '密室',
    desc: '斯莱特林亲手封存的地下密室，千年后由他的传人重新开启。入口在一间盥洗室里。',
    keywords: ['密室'],
  ),
  CollectionDef(
    id: 'lore_owlery',
    category: '地点',
    name: '猫头鹰棚屋',
    desc: '西塔顶层的猫头鹰驿站，几百只猫头鹰栖在横杆上，地板上的景象请自行想象。',
    keywords: ['猫头鹰棚屋'],
  ),
  // ================= 人物 =================
  CollectionDef(
    id: 'lore_dumbledore',
    category: '人物',
    name: '阿不思·邓布利多',
    desc: '霍格沃茨校长，梅林爵士团一级魔法师，糖果爱好者。温和背后是整个魔法界最深的算无遗策。',
    keywords: ['邓布利多'],
  ),
  CollectionDef(
    id: 'lore_mcgonagall',
    category: '人物',
    name: '米勒娃·麦格',
    desc: '变形课教授兼格兰芬多院长，方格纹长袍与薄嘴唇，公平得近乎严苛，护短时也最凶。',
    keywords: ['麦格'],
  ),
  CollectionDef(
    id: 'lore_snape',
    category: '人物',
    name: '西弗勒斯·斯内普',
    desc: '魔药课教授，黑发黑袍，嗓音像涂了毒。偏爱斯莱特林，扣起格兰芬多的分来毫不手软。',
    keywords: ['斯内普'],
  ),
  CollectionDef(
    id: 'lore_hagrid',
    category: '人物',
    name: '鲁伯·海格',
    desc: '钥匙管理员兼猎场看守，半巨人血统，口袋里永远揣着岩皮饼，对危险生物有着灾难性的爱。',
    keywords: ['海格'],
  ),
  CollectionDef(
    id: 'lore_flitwick',
    category: '人物',
    name: '菲利乌斯·弗立维',
    desc: '魔咒课教授，小个子站在一摞书上讲课，曾是决斗冠军——别被他的身高骗了。',
    keywords: ['弗立维'],
  ),
  CollectionDef(
    id: 'lore_sprout',
    category: '人物',
    name: '波莫娜·斯普劳特',
    desc: '草药课教授兼赫奇帕奇院长，头上常年顶着补丁帽，温室里的每一株植物她都叫得出小名。',
    keywords: ['斯普劳特'],
  ),
  CollectionDef(
    id: 'lore_quirrell',
    category: '人物',
    name: '奇洛教授',
    desc: '黑魔法防御课教授，头上裹着古怪的头巾，说话结巴，一年比一年瘦。',
    keywords: ['奇洛'],
  ),
  CollectionDef(
    id: 'lore_lockhart',
    category: '人物',
    name: '吉德罗·洛哈特',
    desc: '五次获奖的魔法界名人、畅销书作家、梅林爵士团三级魔法师——至少他自己的书里是这么写的。',
    keywords: ['洛哈特'],
  ),
  CollectionDef(
    id: 'lore_riddle',
    category: '人物',
    name: '汤姆·里德尔',
    desc: '五十年前级长与"模范学生"，日记里的少年优雅、健谈——以及太过了解你。',
    keywords: ['里德尔'],
  ),
  CollectionDef(
    id: 'lore_voldemort',
    category: '人物',
    name: '伏地魔',
    desc: '连名字都不敢提的黑魔王。十年前那一道绿光之后，魔法界只在耳语里称他为"神秘人"。',
    keywords: ['伏地魔', '神秘人'],
  ),
  CollectionDef(
    id: 'lore_lucius',
    category: '人物',
    name: '卢修斯·马尔福',
    desc: '马尔福家族家主，银发手杖，董事会里最舍得花钱的声音。家养小精灵在他手里活得很"精彩"。',
    keywords: ['卢修斯'],
  ),
  CollectionDef(
    id: 'lore_ginny',
    category: '人物',
    name: '金妮·韦斯莱',
    desc: '韦斯莱家最小的孩子，红发，一年级就敢在火车上大声维护陌生人。',
    keywords: ['金妮'],
  ),
  CollectionDef(
    id: 'lore_sirius',
    category: '人物',
    name: '小天狼星布莱克',
    desc: '阿兹卡班的名字换来十二条人命，报纸照片上的脸瘦得像骷髅，笑起来却还有疯劲。',
    keywords: ['小天狼星'],
  ),
  CollectionDef(
    id: 'lore_lupin',
    category: '人物',
    name: '莱姆斯·卢平',
    desc: '补丁袍子与温和笑容的黑魔法防御课教授，月圆之夜总会"家里有事"。',
    keywords: ['卢平'],
  ),
  CollectionDef(
    id: 'lore_malfoy',
    category: '人物',
    name: '德拉科·马尔福',
    desc: '斯莱特林的白金发级长候选人，"我爸爸"是他的万能咒语，鼻孔朝天的角度随心情浮动。',
    keywords: ['马尔福'],
  ),
  // ================= 奇物 =================
  CollectionDef(
    id: 'lore_sorting_hat',
    category: '奇物',
    name: '分院帽',
    desc: '盖在头顶唱一首即兴歌，再替你选学院。它说它读过每一颗装在它下面的脑袋。',
    keywords: ['分院帽', '分院'],
  ),
  CollectionDef(
    id: 'lore_philosophers_stone',
    category: '奇物',
    name: '魔法石',
    desc: '能把金属变成黄金、调出长生不老药的赤色宝石。炼金术士勒梅靠它活过了六百岁。',
    keywords: ['魔法石'],
  ),
  CollectionDef(
    id: 'lore_erised_mirror',
    category: '奇物',
    name: '厄里斯魔镜',
    desc: '镜中最深最渴望的欲望。邓布利多说：沉湎于虚幻的梦想而忘记现实的生活，这是毫无益处的。',
    keywords: ['厄里斯'],
  ),
  CollectionDef(
    id: 'lore_invisibility_cloak',
    category: '奇物',
    name: '隐形衣',
    desc: '水滴状的银光流过全身就能隐形的斗篷。真正的死亡圣器之一，普通的隐形咒做不到这样。',
    keywords: ['隐形衣', '隐身衣'],
  ),
  CollectionDef(
    id: 'lore_marauders_map',
    category: '奇物',
    name: '活点地图',
    desc: '整座城堡的每一条密道与每一个人都画在羊皮纸上。咒语是"我庄严宣誓我没干好事"。',
    keywords: ['活点地图'],
  ),
  CollectionDef(
    id: 'lore_riddle_diary',
    category: '奇物',
    name: '里德尔的日记',
    desc: '一本普通的空白日记——直到你往上面写字，而它开始回信。',
    keywords: ['日记'],
  ),
  CollectionDef(
    id: 'lore_chocolate_frog',
    category: '奇物',
    name: '巧克力蛙',
    desc: '会跳的巧克力，附赠一张著名巫师画片。画片收集者对空卡片咬牙切齿的历史由来已久。',
    keywords: ['巧克力蛙'],
  ),
  CollectionDef(
    id: 'lore_every_flavour_beans',
    category: '奇物',
    name: '比比多味豆',
    desc: '一颗豆子任何味道都有：椰子、肝脏、鼻屎……邓布利多年轻时踩过一颗耳屎味的。',
    keywords: ['比比多味豆', '多味豆'],
  ),
  CollectionDef(
    id: 'lore_golden_snitch',
    category: '奇物',
    name: '金色飞贼',
    desc: '魁地奇场上最小的球，银翅膀抖个不停，抓到它比赛才结束，捕捉者因此值一大笔加隆。',
    keywords: ['金色飞贼', '飞贼'],
  ),
  CollectionDef(
    id: 'lore_parseltongue',
    category: '奇物',
    name: '蛇佬腔',
    desc: '与蛇对话的天赋，巫师界谈之色变的能力——历史上最著名的两位蛇佬腔，都进了霍格沃茨。',
    keywords: ['蛇佬腔'],
  ),
  CollectionDef(
    id: 'lore_gryffindor_sword',
    category: '奇物',
    name: '格兰芬多的宝剑',
    desc: '妖精工艺的银剑，剑柄上嵌着红宝石。"只有真正的人才能把它从帽子里抽出来"。',
    keywords: ['宝剑'],
  ),
  CollectionDef(
    id: 'lore_pensieve',
    category: '奇物',
    name: '冥想盆',
    desc: '石盆里的银白物质不是液体也不是气体。把记忆倒进去，就能以旁观者身份重走一遍。',
    keywords: ['冥想盆'],
  ),
  CollectionDef(
    id: 'lore_portkey',
    category: '奇物',
    name: '门钥匙',
    desc: '一只旧靴子、一张报纸——被施了咒的普通物件，到点一碰就能把人拽过半个国家。',
    keywords: ['门钥匙'],
  ),
];

/// 已收录 id 集合 → 图鉴功能的状态层，见 `GameProviderBase.collectionUnlocked`。

final Map<String, CollectionDef> _collectionById = <String, CollectionDef>{
  for (final e in kCollectionCatalog) e.id: e,
};

CollectionDef? collectionById(String id) => _collectionById[id];

/// 扫描一段叙事文本，返回其中命中的图鉴条目 id（可能为空）。
///
/// 纯函数、零状态：调用方（`_finalizeTurn` 钩子）负责与已收录集合做差集。
/// 性能：~60 条 × 1~2 个关键词的 `contains`，每回合一次，开销可忽略。
Set<String> matchCollection(String text) {
  if (text.isEmpty) return const <String>{};
  final hit = <String>{};
  for (final e in kCollectionCatalog) {
    for (final kw in e.keywords) {
      if (text.contains(kw)) {
        hit.add(e.id);
        break;
      }
    }
  }
  return hit;
}
