/// 霍格沃茨城堡设定数据：依据设定文档「第三部分 · 霍格沃茨魔法学校」。
///
/// 为什么单独建这个文件：
/// 城堡的世界观细节——七条秘密通道、常驻幽灵与特殊居民、四大学院公共
/// 休息室的入口与陈设——此前**只存在于系统提示词里那几行简述**，代码里
/// 查不到任何一份权威数据。后果有两处：
///
/// 1. AI 在叙事里写「你钻进打人柳的树洞，出来是蜂蜜公爵的地窖」时，
///    没有任何数据能校验这条通道到底通到哪里——打人柳通向尖叫棚屋，
///    通向蜂蜜公爵地窖的是独眼女巫雕像。这类错写在长线叙事里会累积成
///    世界观的硬伤，而玩家一旦认出来，沉浸感当场归零。
/// 2. 玩家想回顾「我学院的公共休息室长什么样」无处可查，只能靠 AI 临时
///    编——每次编出来的陈设还不一样。
///
/// 这里把它们落成数据（不 import material），mixin、UI、测试都能用：
///  - [secretPassages] / [passageById] / [passagesTo]：通道的权威事实表
///  - [castleResidents]：常驻幽灵与特殊居民，供叙事取用
///  - [houseProfiles] / [houseProfileOf]：四大学院完整档案
///  - [castleBriefForPrompt]：给系统提示词的精简版（控制 token，只列名字）
///
/// 所有描述严格参照设定文档原文，不另行发挥。

import 'house_data.dart';

// ============================================================================
// 城堡本体
// ============================================================================

/// 城堡基本档案。
class CastleProfile {
  /// 建校年份（约）。
  final String founded;

  /// 校训拉丁原文。
  final String mottoLatin;

  /// 校训中译。
  final String motto;

  /// 四位创始人。
  final List<String> founders;

  /// 城堡特征（不可标绘、台阶会动、麻瓜电子设备失灵……）。
  final List<String> traits;

  const CastleProfile({
    required this.founded,
    required this.mottoLatin,
    required this.motto,
    required this.founders,
    required this.traits,
  });
}

const CastleProfile kCastleProfile = CastleProfile(
  founded: '约公元990年',
  mottoLatin: 'Draco Dormiens Nunquam Titillandus',
  motto: '眠龙勿扰',
  founders: [
    '戈德里克·格兰芬多',
    '赫尔加·赫奇帕奇',
    '罗伊纳·拉文克劳',
    '萨拉查·斯莱特林',
  ],
  traits: [
    '七层建筑',
    '142处台阶，有的逢星期五会通往不同的地方',
    '整座城堡被古老的魔法笼罩，不可幻影显形',
    '任何麻瓜的电子设备在此都会失灵',
    '麻瓜路过时只会看见一座破败的废墟和一块写着「危险勿入」的牌子',
  ],
);

// ============================================================================
// 四大学院完整档案
// ============================================================================

/// 学院完整档案。
///
/// 与 [kHouseDisplayNames]（只有 key ↔ 中文名）的分工：那份是**归一化**
/// 用的，供逻辑判定；这份是**描述**用的，供叙事与玩家查看。两者靠 [key]
/// 对齐，key 一律用 [kHouseKeys] 里的权威写法。
class HouseProfile {
  /// 学院 key，与 [kHouseKeys] 一致（'Gryffindor' 等）。
  final String key;

  /// 中文名。
  final String name;

  /// 学院特质。
  final List<String> virtues;

  /// 公共休息室位置。
  final String commonRoom;

  /// 入口在哪、怎么开。
  final String entrance;

  /// 内部陈设（叙事取用，保证每次描写一致）。
  final String interior;

  /// 学院幽灵名。
  final String ghost;

  /// 学院幽灵来历。
  final String ghostDesc;

  /// 象征物。
  final String symbol;

  /// 代表色。
  final String colors;

  /// 著名校友。
  final List<String> alumni;

  const HouseProfile({
    required this.key,
    required this.name,
    required this.virtues,
    required this.commonRoom,
    required this.entrance,
    required this.interior,
    required this.ghost,
    required this.ghostDesc,
    required this.symbol,
    required this.colors,
    required this.alumni,
  });
}

/// 四大学院完整档案（顺序同 [kHouseKeys]）。
const List<HouseProfile> houseProfiles = [
  HouseProfile(
    key: 'Gryffindor',
    name: '格兰芬多',
    virtues: ['勇气', '胆识', '骑士精神'],
    commonRoom: '格兰芬多塔楼第八层',
    entrance: '入口藏在一幅胖夫人的肖像画后面，每日口令不同',
    interior: '温暖的圆形房间，摆满了深红色软垫扶手椅，壁炉里永远跳跃着火焰，窗外可以俯瞰魁地奇球场',
    ghost: '差点没头的尼克',
    ghostDesc: '尼古拉斯·德·敏西-波平顿爵士，因一次失败的斩首而永远顶着几乎断掉的脖子',
    symbol: '狮子',
    colors: '红与金',
    alumni: [
      '阿不思·邓布利多',
      '哈利·波特',
      '米勒娃·麦格',
      '詹姆·波特',
      '莉莉·波特',
      '小天狼星·布莱克',
    ],
  ),
  HouseProfile(
    key: 'Hufflepuff',
    name: '赫奇帕奇',
    virtues: ['忠诚', '正直', '勤劳', '公平竞争'],
    commonRoom: '地下室走廊尽头',
    entrance: '入口藏在一幅静物画后面——画中一碗水果需要轻轻敲击才能打开',
    interior: '低矮的圆形房间，黄黑相间的装饰，铺满柔软的地毯，窗外可以看到摇曳的绿草和蒲公英',
    ghost: '胖修士',
    ghostDesc: '一位和蔼的幽灵，喜欢用他那圆滚滚的身躯挡住学生的去路，只为给他们讲一个笑话',
    symbol: '獾',
    colors: '黄与黑',
    alumni: ['塞德里克·迪戈里', '纽特·斯卡曼德', '尼法朵拉·唐克斯'],
  ),
  HouseProfile(
    key: 'Ravenclaw',
    name: '拉文克劳',
    virtues: ['智慧', '学识', '创造力', '聪颖'],
    commonRoom: '拉文克劳塔楼的最高层',
    entrance: '入口是一扇带有青铜鹰状门环的木门——想要进入，必须回答鹰状门环提出的谜题',
    interior: '圆形敞亮的房间，蓝铜色调，穹顶绘有星夜图案，四周摆满了书架和雕像',
    ghost: '格雷女士',
    ghostDesc: '海莲娜·拉文克劳，罗伊纳·拉文克劳的女儿，因偷走母亲的冠冕而永远背负着愧疚',
    symbol: '鹰',
    colors: '蓝与铜',
    alumni: ['卢娜·洛夫古德', '秋·张', '菲利乌斯·弗立维'],
  ),
  HouseProfile(
    key: 'Slytherin',
    name: '斯莱特林',
    virtues: ['野心', '精明', '血统纯正', '狡猾', '机智'],
    commonRoom: '地下湖附近的地牢',
    entrance: '入口隐藏在一道石墙的伪装门后',
    interior: '昏暗而幽静，绿色与银色的装饰，窗户可以俯瞰黑湖的湖底——巨乌贼偶尔会缓缓游过',
    ghost: '血人巴罗',
    ghostDesc: '一个永远戴着锁链的幽灵，因杀死海莲娜·拉文克劳而永远背负着诅咒',
    symbol: '蛇',
    colors: '绿与银',
    alumni: ['萨拉查·斯莱特林', '汤姆·里德尔', '西弗勒斯·斯内普', '德拉科·马尔福'],
  ),
];

/// 按学院 key 取档案；认不出来返回 null。
///
/// 兼容 'gryffindor' 这类大小写不一致的老存档写法，与 [normalizeHouseKey]
/// 保持同一口径。
HouseProfile? houseProfileOf(String? key) {
  if (key == null) return null;
  final t = key.trim();
  if (t.isEmpty) return null;
  for (final p in houseProfiles) {
    if (p.key == t) return p;
  }
  final lower = t.toLowerCase();
  for (final p in houseProfiles) {
    if (p.key.toLowerCase() == lower) return p;
  }
  // 也认中文名（AI 和玩家都习惯写「格兰芬多」而不是 Gryffindor）
  for (final p in houseProfiles) {
    if (p.name == t) return p;
  }
  return null;
}

// ============================================================================
// 秘密通道
// ============================================================================

/// 秘密通道。
///
/// [knownToStudents] 的用途：区分「学生间口耳相传的路」（打人柳、独眼女巫）
/// 和「几乎无人知晓的路」（三楼活板门）。叙事里 NPC 随口提起一条通道时，
/// 得先过这道闸——没人会让同学说出「三楼活板门后面有什么」。
class SecretPassage {
  final String id;

  /// 通道名。
  final String name;

  /// 起点。
  final String from;

  /// 终点。
  final String to;

  /// 备注（怎么走、有什么风险、谁在用）。
  final String note;

  /// 学生间是否普遍知道。
  final bool knownToStudents;

  const SecretPassage({
    required this.id,
    required this.name,
    required this.from,
    required this.to,
    required this.note,
    required this.knownToStudents,
  });
}

/// 霍格沃茨七条秘密通道（依据设定文档第三部分）。
const List<SecretPassage> secretPassages = [
  SecretPassage(
    id: 'whomping_willow',
    name: '打人柳通道',
    from: '打人柳树根下的树洞',
    to: '尖叫棚屋',
    note: '莱姆斯·卢平每月圆夜经此前往尖叫棚屋变身；必须先按住树上的结疤，让打人柳静止',
    knownToStudents: true,
  ),
  SecretPassage(
    id: 'one_eyed_witch',
    name: '独眼女巫通道',
    from: '四楼驼背独眼女巫雕像背后',
    to: '霍格莫德·蜂蜜公爵地窖',
    note: '敲一下雕像的驼背便会开启，出口落在蜂蜜公爵糖果店的地窖里',
    knownToStudents: true,
  ),
  SecretPassage(
    id: 'third_floor_trapdoor',
    name: '三楼活板门',
    from: '三楼走廊尽头的活板门',
    to: '未知深处',
    note: '门后是层层守卫的禁区，具体通向何处从未有人走通过',
    knownToStudents: false,
  ),
  SecretPassage(
    id: 'fourth_floor_portrait',
    name: '四楼画像通道',
    from: '四楼的一幅画像背后',
    to: '霍格莫德',
    note: '穿过画像后的暗道可直达村中，是学生们溜出城堡的老路',
    knownToStudents: true,
  ),
  SecretPassage(
    id: 'room_of_requirement',
    name: '有求必应屋墙后通道',
    from: '有求必应屋的墙后',
    to: '霍格莫德',
    note: '通道藏在有求必应屋堆积如山的旧物之后，出口在村中的某处地窖',
    knownToStudents: false,
  ),
  SecretPassage(
    id: 'astronomy_tower',
    name: '天文塔密道',
    from: '天文塔',
    to: '城堡外部',
    note: '自塔身盘旋而下，可绕过城堡正门的宵禁巡查出到校外',
    knownToStudents: false,
  ),
  SecretPassage(
    id: 'quidditch_pitch',
    name: '魁地奇球场通道',
    from: '魁地奇球场',
    to: '城堡地窖',
    note: '自看台下方折回地牢，球员与球具常走这条近路',
    knownToStudents: true,
  ),
];

/// 按 id 取通道。
SecretPassage? passageById(String id) {
  for (final p in secretPassages) {
    if (p.id == id) return p;
  }
  return null;
}

/// 名字模糊匹配通道：认「打人柳」「独眼女巫」这类简称，也认全名。
///
/// 玩家和 AI 都不会老老实实写「打人柳通道」四个字，写「打人柳」的概率高得多，
/// 所以这里做的是包含匹配而不是全等。
SecretPassage? passageByName(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  for (final p in secretPassages) {
    if (p.name == t || p.id == t) return p;
  }
  for (final p in secretPassages) {
    if (p.name.contains(t) || t.contains(p.name)) return p;
  }
  for (final p in secretPassages) {
    if (p.from.contains(t) || p.to.contains(t)) return p;
  }
  return null;
}

/// 列出通往某地的通道（终点包含关键词即可）。
List<SecretPassage> passagesTo(String destination) {
  final t = destination.trim();
  if (t.isEmpty) return const [];
  return secretPassages.where((p) => p.to.contains(t)).toList(growable: false);
}

// ============================================================================
// 常驻幽灵与特殊居民
// ============================================================================

/// 常驻幽灵与特殊居民。
///
/// 他们不是可攻略 NPC，不进 [npc_data] 的关系网，但会在走廊、盥洗室、
/// 教室和厨房里出现。叙事 AI 需要一份名册，才知道「这条走廊上飘着谁」。
class CastleResident {
  final String id;

  /// 名字。
  final String name;

  /// 类别：幽灵 / 恶作剧精灵 / 家养小精灵 / 幽灵教授。
  final String kind;

  /// 常驻地点。
  final String haunt;

  /// 性格与行事风格（叙事直接取用，保证口吻一致）。
  final String persona;

  const CastleResident({
    required this.id,
    required this.name,
    required this.kind,
    required this.haunt,
    required this.persona,
  });
}

/// 常驻幽灵与特殊居民（依据设定文档第三部分）。
const List<CastleResident> castleResidents = [
  CastleResident(
    id: 'nick',
    name: '差点没头的尼克',
    kind: '幽灵',
    haunt: '格兰芬多塔楼',
    persona: '本名尼古拉斯·德·敏西-波平顿爵士。彬彬有礼，极其在意自己「差点」没被斩首这件事，对任何暗示他头还在的说法都很敏感',
  ),
  CastleResident(
    id: 'fat_friar',
    name: '胖修士',
    kind: '幽灵',
    haunt: '赫奇帕奇公共休息室附近',
    persona: '和蔼可亲，喜欢用圆滚滚的身躯挡住学生的去路，只为给他们讲一个笑话；是少数会替犯错学生说好话的幽灵',
  ),
  CastleResident(
    id: 'grey_lady',
    name: '格雷女士',
    kind: '幽灵',
    haunt: '拉文克劳塔楼',
    persona: '本名海莲娜·拉文克劳。寡言、疏离，因偷走母亲的冠冕而永远背负着愧疚，很少主动与人交谈',
  ),
  CastleResident(
    id: 'bloody_baron',
    name: '血人巴罗',
    kind: '幽灵',
    haunt: '斯莱特林地牢',
    persona: '永远戴着锁链，浑身银白色的血迹。沉默而可怖，连皮皮鬼都不敢招惹他；因杀死海莲娜·拉文克劳而背负诅咒',
  ),
  CastleResident(
    id: 'moaning_myrtle',
    name: '哭泣的桃金娘',
    kind: '幽灵',
    haunt: '二楼女生盥洗室',
    persona: '嗓音尖利而悲伤，动不动就抽泣着躲进隔间；对别人的倒霉事有种不合时宜的兴致',
  ),
  CastleResident(
    id: 'binns',
    name: '宾斯教授',
    kind: '幽灵教授',
    haunt: '魔法史教室',
    persona: '霍格沃茨唯一一位留在岗位上的幽灵。某夜在教员休息室睡着后忘了带走身体，从此继续授课，声音单调如旧唱片，从不察觉自己已经死了',
  ),
  CastleResident(
    id: 'peeves',
    name: '皮皮鬼',
    kind: '恶作剧精灵',
    haunt: '城堡走廊（四处游荡）',
    persona: '不属于任何学院的恶作剧精灵，唯一一个可以不听费尔奇指挥的存在。漂浮在走廊里向路人投掷粉笔和水球，只对血人巴罗和少数教授有所忌惮',
  ),
  CastleResident(
    id: 'house_elves',
    name: '家养小精灵',
    kind: '家养小精灵',
    haunt: '城堡厨房',
    persona: '数百名在厨房工作的家养小精灵。终日忙碌于灶台之间，对客人过分热情，被当面道谢会窘迫得不知所措',
  ),
];

/// 按 id 取居民。
CastleResident? residentById(String id) {
  for (final r in castleResidents) {
    if (r.id == id) return r;
  }
  return null;
}

/// 名字模糊匹配居民。
CastleResident? residentByName(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  for (final r in castleResidents) {
    if (r.id == t || r.name == t) return r;
  }
  for (final r in castleResidents) {
    if (r.name.contains(t) || t.contains(r.name)) return r;
  }
  return null;
}

/// 在某地出没的居民（地点包含关键词即可）。
List<CastleResident> residentsAt(String place) {
  final t = place.trim();
  if (t.isEmpty) return const [];
  return castleResidents
      .where((r) => r.haunt.contains(t))
      .toList(growable: false);
}

// ============================================================================
// 展示与提示词
// ============================================================================

/// 给系统提示词的精简版城堡设定。
///
/// 只列名字和走向，不列陈设与性格——那部分留给 [formatCastlePassages]
/// 和 [formatCastleResidents] 展示给玩家。提示词每多一个字都要在所有回合
/// 里重复付一遍 token，而 AI 真正需要的只是「有这些通道、通向哪里」这条
/// 事实约束，免得它把打人柳写成通蜂蜜公爵。
String castleBriefForPrompt() {
  final buf = StringBuffer();
  buf.writeln('【秘密通道】以下七条是城堡里真实存在的路，走向不可张冠李戴：');
  for (final p in secretPassages) {
    buf.writeln('- ${p.name}：${p.from} → ${p.to}');
  }
  buf.writeln('【常驻幽灵与居民】他们会真的出现在这些地方：');
  for (final r in castleResidents) {
    buf.writeln('- ${r.name}（${r.kind}）·常驻${r.haunt}');
  }
  return buf.toString().trimRight();
}

/// 玩家视角：城堡概览（本体 + 学院 + 通道 + 居民）。
String formatCastleOverview({String? houseKey}) {
  final buf = StringBuffer();
  buf.writeln('【霍格沃茨魔法学校】');
  buf.writeln('建校：${kCastleProfile.founded}　校训：${kCastleProfile.motto}'
      '（${kCastleProfile.mottoLatin}）');
  for (final t in kCastleProfile.traits) {
    buf.writeln('· $t');
  }
  if (houseKey != null) {
    final p = houseProfileOf(houseKey);
    if (p != null) {
      buf.writeln();
      buf.writeln(houseProfileBlock(p));
    }
  }
  return buf.toString().trimRight();
}

/// 玩家视角：某学院的完整档案。
String houseProfileBlock(HouseProfile p) {
  final buf = StringBuffer();
  buf.writeln('【${p.name}】${p.symbol}｜${p.colors}');
  buf.writeln('特质：${p.virtues.join('、')}');
  buf.writeln('公共休息室：${p.commonRoom}');
  buf.writeln('入口：${p.entrance}');
  buf.writeln('陈设：${p.interior}');
  buf.writeln('学院幽灵：${p.ghost}——${p.ghostDesc}');
  buf.writeln('著名校友：${p.alumni.join('、')}');
  return buf.toString().trimRight();
}

/// 玩家视角：七条秘密通道。
///
/// 只列 [knownToStudents] 为 true 的那些吗？不列全。
/// 这里的设计取舍：面板是**给玩家看的**，玩家是个活了七年的学生，
/// 学生间口耳相传的路他迟早会知道；而真正没人走过的（三楼活板门），
/// 面板上如实标注「几乎无人知晓」，反而更有探索的诱惑。
String formatCastlePassages() {
  final buf = StringBuffer();
  buf.writeln('【霍格沃茨秘密通道】');
  for (var i = 0; i < secretPassages.length; i++) {
    final p = secretPassages[i];
    final known = p.knownToStudents ? '学生间口耳相传' : '几乎无人知晓';
    buf.writeln('${i + 1}. ${p.name}　$known');
    buf.writeln('   ${p.from} → ${p.to}');
    buf.writeln('   ${p.note}');
  }
  return buf.toString().trimRight();
}

/// 玩家视角：常驻幽灵与特殊居民。
String formatCastleResidents() {
  final buf = StringBuffer();
  buf.writeln('【常驻幽灵与特殊居民】');
  for (final r in castleResidents) {
    buf.writeln('· ${r.name}（${r.kind}）');
    buf.writeln('   常驻：${r.haunt}');
    buf.writeln('   ${r.persona}');
  }
  return buf.toString().trimRight();
}
