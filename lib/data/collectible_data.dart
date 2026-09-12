/// 收藏品数据：Player.collection 里存的 id 全部来自这张表。
///
/// 之所以要有这张表：/收藏 以前永远只有一句「暂无收藏品。在冒险中收集独特
/// 物品，如巧克力蛙画片、日记本等」——而全项目对 collection 的写入一处都没
/// 有。那句提示承诺了两件根本拿不到的东西：
///  · 巧克力蛙（item_data 里的描述就写着「附赠著名巫师卡片」）吃下去什么
///    卡片也不会掉；
///  · 「日记本」这类纪念品在任何地方都不存在。
/// 玩家照着提示玩，玩到通关收藏栏还是空的。
///
/// 收藏品按 series 分组，/收藏 按系列显示「已收集 / 总数」。
library;

class CollectibleDef {
  final String id;
  final String name;
  final String series;

  /// 稀有度 1~5，只在展示时用（★）与抽取权重相关：越稀有越难抽到。
  final int rarity;
  final String desc;

  const CollectibleDef({
    required this.id,
    required this.name,
    required this.series,
    required this.rarity,
    required this.desc,
  });

  String get starText => '★' * rarity;
}

const List<CollectibleDef> kCollectibleCatalog = [
  // ===== 巧克力蛙画片：著名巫师 =====
  CollectibleDef(
    id: 'card_dumbledore',
    name: '阿不思·邓布利多',
    series: '巧克力蛙画片',
    rarity: 5,
    desc: '「1907 年于格林德沃一战中展露锋芒」——卡片背面这么写，正面的人却只在打瞌睡。',
  ),
  CollectibleDef(
    id: 'card_grindelwald',
    name: '盖勒特·格林德沃',
    series: '巧克力蛙画片',
    rarity: 5,
    desc: '金发青年在照片里笑得温和，很难相信他后来做了什么。',
  ),
  CollectibleDef(
    id: 'card_nicholas',
    name: '尼古拉斯·勒梅',
    series: '巧克力蛙画片',
    rarity: 4,
    desc: '唯一已知的魔法石制造者，六百多岁了还活得挺精神。',
  ),
  CollectibleDef(
    id: 'card_merlin',
    name: '梅林',
    series: '巧克力蛙画片',
    rarity: 5,
    desc: '史上最伟大的巫师。卡片上他戴着那顶过分夸张的尖帽。',
  ),
  CollectibleDef(
    id: 'card_morgana',
    name: '摩根娜',
    series: '巧克力蛙画片',
    rarity: 4,
    desc: '梅林传说里的对手，卡片评价写着「才华不输，名声不佳」。',
  ),
  CollectibleDef(
    id: 'card_hengist',
    name: '亨吉斯特·伍德克罗夫特',
    series: '巧克力蛙画片',
    rarity: 2,
    desc: '霍格莫德的创建者。据说他躲起来是为了避开麻瓜，不是巫师。',
  ),
  CollectibleDef(
    id: 'card_bowman',
    name: '鲍曼·赖特',
    series: '巧克力蛙画片',
    rarity: 2,
    desc: '金色飞贼的发明者。一个铁匠，却在魔法史上留了名。',
  ),
  CollectibleDef(
    id: 'card_gunhilda',
    name: '冈希尔达·德·戈里亚',
    series: '巧克力蛙画片',
    rarity: 3,
    desc: '圣芒戈魔法医院的创始人，也是个厉害的治愈师。',
  ),
  CollectibleDef(
    id: 'card_wilfred',
    name: '威尔弗雷德·埃利奥特',
    series: '巧克力蛙画片',
    rarity: 3,
    desc: '《魔法药剂与药水》的作者，书里的插图比配方还吓人。',
  ),
  CollectibleDef(
    id: 'card_alberic',
    name: '阿尔贝里克·格鲁尼恩',
    series: '巧克力蛙画片',
    rarity: 2,
    desc: '从巨怪手里救下女孩的巫师，卡片上的巨怪画得像个大萝卜。',
  ),
  CollectibleDef(
    id: 'card_circe',
    name: '喀耳刻',
    series: '巧克力蛙画片',
    rarity: 3,
    desc: '古希腊的变形术大师，把船员变成猪的那位。',
  ),
  CollectibleDef(
    id: 'card_godelot',
    name: '戈德洛特',
    series: '巧克力蛙画片',
    rarity: 3,
    desc: '《魔法世界》的作者，据说写完就被自己书里封的东西逼疯了。',
  ),
  CollectibleDef(
    id: 'card_montague',
    name: '蒙塔古·奈特利',
    series: '巧克力蛙画片',
    rarity: 2,
    desc: '热衷麻瓜研究的巫师，最爱的一项运动是……骑自行车。',
  ),
  CollectibleDef(
    id: 'card_berthilda',
    name: '贝尔蒂尔达·巴格肖特',
    series: '巧克力蛙画片',
    rarity: 2,
    desc: '《魔法史》作者的姑婆，一生写了二十七本关于魔法饮食的书。',
  ),
  CollectibleDef(
    id: 'card_dorcas',
    name: '多卡斯·韦尔伯恩',
    series: '巧克力蛙画片',
    rarity: 3,
    desc: '唯一一位两次担任魔法部部长的女巫，任期加起来不到三年。',
  ),
  CollectibleDef(
    id: 'card_grogan',
    name: '格罗根·斯图姆普',
    series: '巧克力蛙画片',
    rarity: 3,
    desc: '把巨怪赶出英国的巫师。卡片背面说他「脾气和巨怪差不多」。',
  ),
  CollectibleDef(
    id: 'card_bridget',
    name: '布丽奇特·温洛克',
    series: '巧克力蛙画片',
    rarity: 2,
    desc: '研究数字命理学，坚信 7 是最有魔力的数字。',
  ),
  CollectibleDef(
    id: 'card_zacharias',
    name: '扎卡赖亚斯·姆普',
    series: '巧克力蛙画片',
    rarity: 1,
    desc: '卡片上写着「发明了一种会自己洗的锅」，然后就没有然后了。',
  ),
  CollectibleDef(
    id: 'card_edwinna',
    name: '埃德温娜·阿博特',
    series: '巧克力蛙画片',
    rarity: 1,
    desc: '据称曾把一整个村庄的猫变成茶壶，事后坚称是误会。',
  ),

  // ===== 徽章 =====
  CollectibleDef(
    id: 'badge_quidditch',
    name: '魁地奇院队徽章',
    series: '徽章',
    rarity: 2,
    desc: '珐琅烤漆的院队徽章，别在校袍上很神气。',
  ),

  // ===== 纪念品 =====
  CollectibleDef(
    id: 'souvenir_platform',
    name: '九又四分之三站台的旧车票',
    series: '纪念品',
    rarity: 1,
    desc: '票根磨得发白，日期那一栏早就看不清了。',
  ),
  CollectibleDef(
    id: 'souvenir_sorting',
    name: '分院仪式上的一片帽子碎布',
    series: '纪念品',
    rarity: 5,
    desc: '谁也不知道它是怎么掉下来的，总之你捡到了。',
  ),
  CollectibleDef(
    id: 'souvenir_forest',
    name: '禁林里捡到的独角兽尾毛',
    series: '纪念品',
    rarity: 4,
    desc: '泛着淡淡银光。海格说这说明它主人曾在附近走过。',
  ),
];

/// 按 id 查收藏品。
CollectibleDef? collectibleById(String id) {
  for (final c in kCollectibleCatalog) {
    if (c.id == id) return c;
  }
  return null;
}

/// 某个系列的全部收藏品。
List<CollectibleDef> collectiblesInSeries(String series) =>
    kCollectibleCatalog.where((c) => c.series == series).toList();

/// 目录里出现过的所有系列（按目录中的首次出现顺序）。
List<String> get collectibleSeries {
  final out = <String>[];
  for (final c in kCollectibleCatalog) {
    out.add(c.series);
  }
  return out.toSet().toList();
}

/// 买下某件商品时顺带入册的收藏品 id。
///
/// 这一栏存在的理由和上面的表一样：不加的话，目录里就会出现「看得见、拿不
/// 到」的条目——那正是 /收藏 当年的毛病。测试会盯着这张表，确保每一条都有
/// 至少一个真实的获取途径。
const Map<String, String> collectibleForPurchase = {
  '魁地奇徽章': 'badge_quidditch',
};

/// 使用某件物品时会掉落的收藏品系列（从中随机抽一张未拥有的）。
const Map<String, String> collectibleSeriesForUse = {
  '巧克力蛙': '巧克力蛙画片',
};
