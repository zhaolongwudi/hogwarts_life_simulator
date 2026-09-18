/// P10 霍格沃茨奇遇库：随机发生在「你」身上的小故事。
///
/// 【和月度/学年事件、节庆的区别】月度/学年事件是"世界发生了什么"（新闻），
/// 节庆是"今天是个特别的日子"（日历）；奇遇是**「你」个人碰到的突发事件**
/// ——走廊里滚来一只快掉的皮皮鬼气球、图书馆里有人求你帮忙找书、黑湖边上
/// 有只迷路的青蛙。它不讲大事，只讲"这种事居然落在我头上"。
///
/// 触发：无固定日期，按「季节 + 地点 + 年级」过滤，加权抽取 + 冷却；
/// 交互：触发当回合给出 2~4 个「你打算怎么做」，下一回合选定后结算不同结局
/// （奖励 / 声望 / 好感 / 物品），记档去重后不再重复。数据全收口在这里，
/// mixin 只做「过滤 + 抽取 + 选择结算」三层事，新增奇遇只改这一份文件。
library;

// ==================== 奇遇效果 ====================

/// 一场奇遇带来的结算效果（全部可选，0 表示不结算该项）。
/// 字段与点法对齐节庆（FestivalEffectDef），保证两条个人事件线的收获口径一致。
class HappenstanceEffectDef {
  final String? reputationDim; // academic/social/combat/moral/leadership/dark
  final int reputationValue;
  final int housePoints;
  final int galleons;
  final int energy;
  final String? npcId; // 好感加成对象
  final int npcAffection;
  final String? itemName; // 奖励物品（需在 item_data 有定义）
  const HappenstanceEffectDef({
    this.reputationDim,
    this.reputationValue = 0,
    this.housePoints = 0,
    this.galleons = 0,
    this.energy = 0,
    this.npcId,
    this.npcAffection = 0,
    this.itemName,
  });
}

/// 一个奇遇选项：玩家选它之后会发生的事。
class HappenstanceOutcomeDef {
  final String title; // 按钮文案，简短，如「帮它找主人」
  final String text; // 选定后的叙事（可带 `$house` 占位符）
  final HappenstanceEffectDef effect;
  const HappenstanceOutcomeDef({
    required this.title,
    required this.text,
    required this.effect,
  });
}

/// 一场奇遇。触发条件见 mixin（季节/地点/年级过滤 + 加权抽取 + 冷却）。
class HappenstanceDef {
  final String id;
  final String title; // 奇遇标题，如「走廊里跑出来的皮皮鬼气球」
  final String scene; // 触发时的场景叙事（可带 `$house` 占位符）
  final List<String> seasonTags; // spring/summer/autumn/winter；空=四季通用
  final List<String> locationKeys; // 地点关键词；空=不限地点
  final int minGrade; // 年级门控（1~7）；默认 1
  final int weight; // 抽取权重
  final double baseChance; // 命中后触发概率 0.0~1.0
  final List<HappenstanceOutcomeDef> outcomes; // 2~4 个选项
  const HappenstanceDef({
    required this.id,
    required this.title,
    required this.scene,
    this.seasonTags = const [],
    this.locationKeys = const [],
    this.minGrade = 1,
    this.weight = 1,
    this.baseChance = 1.0,
    required this.outcomes,
  });
}

/// 通用占位符替换：`$house` → 学院名（与节庆同一套口径，避免 `$` 泄漏）。
String fillHappenstanceText(String text, {required String house}) =>
    text.replaceAll(r'$house', house);

/// 按 id 查奇遇。
HappenstanceDef? happenstanceById(String id) {
  for (final h in kHappenstances) {
    if (h.id == id) return h;
  }
  return null;
}

/// 季节标签集合（spring/summer/autumn/winter）——用于数据校验。
const Set<String> kHappenstanceSeasonTags = {
  'spring', 'summer', 'autumn', 'winter',
};

const List<HappenstanceDef> kHappenstances = [
  // ====== 城堡·通用（不限季节）======
  HappenstanceDef(
    id: 'wandering_note',
    title: '一张来历不明的纸条',
    scene:
        '你在走廊拐角的地上看到一张折得方方正正的纸条，没有署名，'
        '只写了半句话——"如果第一间空教室的窗台下面……"。摇摇晃晃的笔迹，'
        '像是有人赶在关灯前飞快写下的。',
    locationKeys: ['走廊', '城堡', '公共休息室'],
    weight: 4,
    outcomes: [
      HappenstanceOutcomeDef(
        title: '捡起来看看',
        text:
            '你顺着纸条去了那间空教室。窗台下面压着一个裹着旧报纸的小包，'
            '里面是几块巧克蛙和一张"谢谢"的便签。第二天，你在桌上发现一枚'
            '崭新的加隆，压在一角。',
        effect: const HappenstanceEffectDef(
            reputationDim: 'moral', reputationValue: 2, galleons: 6),
      ),
      HappenstanceOutcomeDef(
        title: '把它留在原地',
        text:
            '你想了想，把纸条按原样放回地上——别人的秘密不该由你来拆。'
            '第二天它不见了。你莫名觉得，这样做是对的。',
        effect: const HappenstanceEffectDef(
            reputationDim: 'moral', reputationValue: 3, energy: 4),
      ),
    ],
  ),
  HappenstanceDef(
    id: 'lost_quill',
    title: '一支会自己修自己的羽毛笔',
    scene:
        '图书馆靠窗的位子上落着一支银色羽毛笔。你伸手去碰的瞬间，'
        '笔尖自己蘸了蘸墨，在你指节上画了一圈细细的花纹，像在抗议被人打扰。',
    locationKeys: ['图书馆', '城堡'],
    weight: 3,
    outcomes: [
      HappenstanceOutcomeDef(
        title: '据为己有',
        text:
            '你把它收进笔袋。这支笔划字极稳，写东西再没歪过角度，'
            '连魔药课笔记都工整了一截——虽然它偶尔会在你走神时，'
            '悄悄在页角画一朵花。',
        effect: const HappenstanceEffectDef(
            reputationDim: 'academic', reputationValue: 3, energy: 4),
      ),
      HappenstanceOutcomeDef(
        title: '问是不是有主',
        text:
            '你抬手问了一圈，邻座的拉文克劳学姐认领走了它，连声道谢。'
            r'晚上，$house 的公共休息室里多了一碟对方送来的糖霜饼干。',
        effect: const HappenstanceEffectDef(
            reputationDim: 'social',
            reputationValue: 3,
            npcAffection: 2),
      ),
    ],
  ),
  HappenstanceDef(
    id: 'pet_gewgaw',
    title: '一次意外的魔法坠饰',
    scene:
        '公共休息室的壁炉边，一枚系着褪色红绳的小坠饰被风吹到地上，'
        '铛的一声。坠面刻着一行细小的字，火光里看不太清。',
    locationKeys: ['公共休息室', '城堡'],
    weight: 2,
    outcomes: [
      HappenstanceOutcomeDef(
        title: '捡起来去失物招领',
        text:
            '你把坠饰交到失物招领处。傍晚，一只沾着煤灰的猫头鹰落到你肩头，'
            '腿上的小袋里装着三颗亮晶晶的石头，算是答谢。',
        effect: const HappenstanceEffectDef(
            galleons: 5, reputationDim: 'moral', reputationValue: 2),
      ),
      HappenstanceOutcomeDef(
        title: '戴在自己身上',
        text:
            '红绳绕上手腕的一瞬，你感到一丝凉意顺着腕骨爬上来。'
            '之后几天运气似乎不错——连魔药课那种容易炸的坩埚都平安无事。',
        effect: const HappenstanceEffectDef(
            reputationDim: 'dark', reputationValue: 2, housePoints: 4, energy: 5),
      ),
    ],
  ),

  // ====== 禁林·探索（秋冬偏多）======
  HappenstanceDef(
    id: 'forest_lost_frog',
    title: '迷路的紫色青蛙',
    scene:
        '禁林边缘的草地上蹲着一只通体淡紫色的青蛙，圆眼睛盯着你，'
        '一鼓一鼓的，肚皮上还有一小片银色的鳞——一看就是哪位教授的药池里'
        '偷跑出来的实验品。',
    locationKeys: ['禁林', '黑湖'],
    seasonTags: ['spring', 'summer', 'autumn'],
    minGrade: 2,
    weight: 3,
    outcomes: [
      HappenstanceOutcomeDef(
        title: '把它送回去',
        text:
            '你捧着青蛙送回温室，斯拉格霍恩教授（或当值药剂师）朝你点点头，'
            '把一罐松脂香的精油塞进你手里。这只青蛙后来成了你课上的常客，'
            '见到你就眨眼睛。',
        effect: const HappenstanceEffectDef(
            reputationDim: 'moral', reputationValue: 3, galleons: 4, npcAffection: 2),
      ),
      HappenstanceOutcomeDef(
        title: '悄悄放生',
        text:
            '你把它放回林子深处。它一跳老远，回头看了你一眼，钻进蕨丛不见了。'
            '走出禁林时，你衣袋里多了一片不知怎么进去的银色鳞片，'
            '凉凉的，带着一点苦艾的味道。',
        effect: const HappenstanceEffectDef(
            reputationDim: 'dark', reputationValue: 2, energy: 3, itemName: '银色鳞片'),
      ),
      HappenstanceOutcomeDef(
        title: '跟它玩一会儿',
        text:
            '你蹲下来，用草叶逗它。它不认生，绕着你的靴子蹦了几圈，'
            '又在你鞋带上蹲了半天。等它跳走，你才想起自己只是出来采风，'
            '却一点也不觉得累。',
        effect: const HappenstanceEffectDef(
            reputationDim: 'social', reputationValue: 2, energy: 3),
      ),
    ],
  ),
  HappenstanceDef(
    id: 'forest_lucky_rock',
    title: '会发光的圆石',
    scene:
        '禁林的地上有一枚拳头大小、表面温润的圆石，在阴影里泛着极淡的'
        '柔光。你蹲下想看个仔细，光却在你靠近时更亮了一些，像认得你。',
    locationKeys: ['禁林'],
    seasonTags: ['autumn', 'winter'],
    minGrade: 2,
    weight: 2,
    outcomes: [
      HappenstanceOutcomeDef(
        title: '收进口袋',
        text:
            '圆石在口袋里一直微温。夜里你把它放在枕边，睡得出奇安稳，'
            '第二天精神格外好——连那段绕了八遍的咒语都一遍过了。',
        effect: const HappenstanceEffectDef(
            reputationDim: 'academic', reputationValue: 2, energy: 6, itemName: '会发光的圆石'),
      ),
      HappenstanceOutcomeDef(
        title: '留在原地',
        text:
            '你轻轻把圆石放回原处，它又暗下去，像从未亮过。走出禁林时'
            '风正好吹过树梢，你莫名觉得，有些东西遇到了就够了，不必带走。',
        effect: const HappenstanceEffectDef(
            reputationDim: 'moral', reputationValue: 3, galleons: 3),
      ),
    ],
  ),

  // ====== 黑湖·夏夜 =======
  HappenstanceDef(
    id: 'lake_summer_glint',
    title: '黑湖里的星光',
    scene:
        '夏末的傍晚，你靠着黑湖边的老树发呆。水面忽然泛起一圈圈涟漪，'
        '一根沾着水草的光滑细小树枝被推到岸边，一端别着一枚发暗的银质徽章。',
    locationKeys: ['黑湖'],
    seasonTags: ['summer'],
    minGrade: 2,
    weight: 2,
    outcomes: [
      HappenstanceOutcomeDef(
        title: '捞起来看看',
        text:
            '你擦掉水草，认出那是三年前某届学生会主席的纪念徽章。'
            '你把它送去失物招领，结果负责人一头雾水——那届早毕业了。'
            '他让你留着：现在它该有个新主人了。',
        effect: const HappenstanceEffectDef(
            reputationDim: 'social', reputationValue: 3, housePoints: 5),
      ),
      HappenstanceOutcomeDef(
        title: '不碰，只看',
        text:
            '你没有碰那枚徽章，只是看着暮色沉进湖里。风把涟漪一层层'
            '推远，好像今晚的黑湖什么都不想让你带走，只想让你站到天黑。',
        effect: const HappenstanceEffectDef(
            reputationDim: 'moral', reputationValue: 2, energy: 4),
      ),
    ],
  ),

  // ====== 冬季·城堡 =======
  HappenstanceDef(
    id: 'winter_cold_kitty',
    title: '躲在角落的冷猫',
    scene:
        '走廊尽头的暖气片边缩着一只灰扑扑的猫，尾巴把自己裹成毛球。'
        '它看见你，警惕地压低了耳朵，却没有逃——实在太冷了。',
    locationKeys: ['走廊', '城堡'],
    seasonTags: ['winter'],
    weight: 4,
    outcomes: [
      HappenstanceOutcomeDef(
        title: '分它一点吃的',
        text:
            '你从口袋里翻出半块肉馅饼。它先是僵着不动，随后小口小口'
            '吃完了，用头顶了顶你的手，才迈着步子跟了你半截走廊。'
            '那天晚上，你总觉得哪只猫都会记得你的气味。',
        effect: const HappenstanceEffectDef(
            reputationDim: 'moral', reputationValue: 3, housePoints: 4),
      ),
      HappenstanceOutcomeDef(
        title: '把它抱到暖处',
        text:
            '你把它抱到公共休息室的炉火边。它窝在你腿上睡了一觉，'
            '醒来已经不怕人了。那天夜里你还口齿不清地摸出一瓶温牛奶，'
            '精灵们在你书架底下多放了两颗太妃糖。',
        effect: const HappenstanceEffectDef(
            reputationDim: 'social', reputationValue: 3, npcAffection: 2, energy: 3),
      ),
    ],
  ),
  HappenstanceDef(
    id: 'winter_frost_window',
    title: '窗玻璃上的名字',
    scene:
        '寒潮过后，天文台的窗玻璃结起厚厚的霜。你擦开一小块，'
        '指尖竟在霜面上划出了几道字迹，像是某个很久以前的夜晚，'
        '有人也在这里这样写过。',
    locationKeys: ['天文台', '城堡'],
    seasonTags: ['winter'],
    minGrade: 3,
    weight: 2,
    outcomes: [
      HappenstanceOutcomeDef(
        title: '在它下面补一行字',
        text:
            '你在那行模糊的字迹下面，用自己的字补了一句。'
            '后来每年的第一场雪，你都会来看它一次——玻璃上的颜色每次'
            '都淡一点，像心事被慢慢化开，你却觉得它更清楚了。',
        effect: const HappenstanceEffectDef(
            reputationDim: 'academic', reputationValue: 2, energy: 5),
      ),
      HappenstanceOutcomeDef(
        title: '读了一遍就离开',
        text:
            '你辨不清那行字，只觉写出它的人大概很冷、也很平静。'
            '你没有添字，只是替它把窗关严了些，就下了塔。'
            '楼道里回响的脚步声，比你上来时轻很多。',
        effect: const HappenstanceEffectDef(
            reputationDim: 'moral', reputationValue: 3, galleons: 4),
      ),
    ],
  ),

  // ====== 高年级·有求必应屋附近 ======
  HappenstanceDef(
    id: 'elder_mystery_box',
    title: '墙里探出的小箱子',
    scene:
        '你路过第八层走廊，墙面忽然起了杨柳般的波纹，一只蒙着灰、'
        '拴铜扣的小木箱从墙里"吐"了出来，落在地上发出沉闷的一声。'
        '箱盖上刻着一行已经看不太清的小字。',
    locationKeys: ['有求必应屋', '城堡'],
    minGrade: 5,
    weight: 2,
    outcomes: [
      HappenstanceOutcomeDef(
        title: '打开它',
        text:
            '你撬开铜扣——里面只有一截旧蜡烛、三颗干豆子和一张字条：'
            '"还给活下去的人。"你合上盖子，把它放回墙边。走出很远，'
            '仍觉得那句话是写给某个还没出现的人。',
        effect: const HappenstanceEffectDef(
            reputationDim: 'dark', reputationValue: 2, galleons: 5, energy: 4),
      ),
      HappenstanceOutcomeDef(
        title: '不碰，继续走',
        text:
            '你看了看那行字，终究没有弯腰。箱子在你身后静静躺着，'
            '这一次墙没有把它收回去。你走出走廊那一刻才明白：'
            '有些门，打开了就再难关上——而你没有开门的准备。',
        effect: const HappenstanceEffectDef(
            reputationDim: 'moral', reputationValue: 3, housePoints: 4),
      ),
    ],
  ),
];