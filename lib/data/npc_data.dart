/// NPC 种子数据：依据设定文档「第四部分 · NPC完整名录与外貌描述」
/// 及四大时代配置。字段用于初始化 NPC 注册表。
class NpcSeed {
  final String id;
  final String name;
  final List<String> aliases; // 常用简称/别名
  final String house; // Gryffindor / Slytherin / Ravenclaw / Hufflepuff / '' = 教职或成人
  final int grade; // 0 = 成人/教职
  final String bloodStatus;
  final List<String> personality;
  final String appearance; // 电影形象描述
  final String era; // dumbledore / marauders / harry_same / post_war / all
  final String gender; // '男' / '女' / '' = 未知（恋爱取向匹配必需）
  final String? sexOrientation; // default 由生成器决定
  final Map<String, int> giftPrefs; // 挚爱礼物 → 分值
  final String? personalGoal;

  const NpcSeed({
    required this.id,
    required this.name,
    this.aliases = const [],
    this.house = '',
    this.grade = 0,
    this.bloodStatus = 'unknown',
    this.personality = const [],
    this.appearance = '',
    this.era = 'all',
    this.gender = '',
    this.sexOrientation,
    this.giftPrefs = const {},
    this.personalGoal,
  });
}

/// 教职员工（所有时代通用）
const List<NpcSeed> staffSeeds = [
  NpcSeed(
    id: 'dumbledore',
    name: '阿不思·邓布利多',
    gender: '男',
    aliases: ['老蜜蜂', '老邓', '邓布利多校长'],
    house: 'Gryffindor',
    grade: 0,
    bloodStatus: 'halfblood',
    personality: ['智慧', '神秘', '仁慈', '深谋远虑'],
    appearance:
        '一位身材高挑、银发银须的老人。戴着半月形眼镜，镜片后是一双明亮而闪烁着睿智光芒的蓝眼睛。长袍通常是深紫色或墨绿色的丝绒质地，饰以银色刺绣。声音温和而深沉，带着仿佛看穿一切的从容。',
    era: 'all',
    personalGoal: '保护霍格沃茨并引导命运',
  ),
  NpcSeed(
    id: 'mcgonagall',
    name: '米勒娃·麦格',
    gender: '女',
    aliases: ['麦格教授', '格兰芬多院长'],
    house: 'Gryffindor',
    grade: 0,
    bloodStatus: 'halfblood',
    personality: ['公正', '严格', '关怀', '强大'],
    appearance:
        '身材高瘦、神态严厉的女巫。黑发紧紧盘成一个发髻，戴尖顶帽，穿翠绿色长袍。嘴唇常抿成一条细线，眼镜后的目光锐利如鹰。从不高声说话，但每一句话都像一把精准的刀。',
    era: 'all',
    personalGoal: '守护格兰芬多的荣誉',
  ),
  NpcSeed(
    id: 'snape',
    name: '西弗勒斯·斯内普',
    gender: '男',
    aliases: ['斯内普教授', '斯莱特林院长', '混血王子'],
    house: 'Slytherin',
    grade: 0,
    bloodStatus: 'halfblood',
    personality: ['复杂', '严厉', '深情', '傲慢'],
    appearance:
        '身形瘦削、面色蜡黄。一头油腻的黑色长发像帘幕一样垂在脸颊两侧。眼睛漆黑，目光冰冷而锐利。鼻子鹰钩般突出，说话时声音低缓，带着令人不安的停顿。长袍永远漆黑。',
    era: 'all',
    personalGoal: '在双重身份中守护莉莉的孩子',
  ),
  NpcSeed(
    id: 'hagrid',
    name: '鲁伯·海格',
    gender: '男',
    aliases: ['猎场看守', '钥匙管理员'],
    house: 'Gryffindor',
    grade: 0,
    bloodStatus: 'halfblood',
    personality: ['善良', '热情', '天真', '忠诚'],
    appearance:
        '身形是常人两倍高的巨人。蓬乱的黑色胡子和头发几乎遮住大半张脸。眼睛像黑色的甲虫一样明亮，双手大如垃圾桶盖。穿着巨大的鼹鼠皮大衣，声音洪亮如雷。',
    era: 'all',
    personalGoal: '照看危险的魔法生物',
  ),
  NpcSeed(
    id: 'flitwick',
    name: '菲利乌斯·弗立维',
    gender: '男',
    aliases: ['弗立维教授', '拉文克劳院长', '魔咒课教授'],
    house: 'Ravenclaw',
    grade: 0,
    bloodStatus: 'unknown',
    personality: ['热情', '博学', '机敏', '温和'],
    appearance:
        '身材极其矮小的男巫，站在讲台后面常常只能露出一个脑袋。花白短发，尖尖的鼻子，明亮而机敏的眼睛。声音尖细而充满热情，挥舞魔杖的姿态精准得如同指挥家。',
    era: 'all',
  ),
  NpcSeed(
    id: 'sprout',
    name: '波莫娜·斯普劳特',
    gender: '女',
    aliases: ['斯普劳特教授', '赫奇帕奇院长', '草药课教授'],
    house: 'Hufflepuff',
    grade: 0,
    bloodStatus: 'unknown',
    personality: ['朴实', '温暖', '勤劳', '可靠'],
    appearance:
        '身材敦实、面容和蔼的女巫。蓬松的灰色卷发总是沾着泥土和草叶。穿着打满补丁的旧长袍，围着厚厚的围裙。笑容温暖而朴实，像刚从温室里走出来。',
    era: 'all',
  ),
  NpcSeed(
    id: 'hooch',
    name: '罗兰达·霍琦',
    gender: '女',
    aliases: ['霍琦夫人', '飞行课教授', '魁地奇裁判'],
    house: '',
    grade: 0,
    bloodStatus: 'unknown',
    personality: ['精干', '严厉', '利落'],
    appearance:
        '身材瘦削、面容精干的女巫。灰色短发剪得极短，黄色的鹰隼般的眼睛锐利有神。总是穿着利落的飞行服，嗓音短促而有力。',
    era: 'all',
  ),
  NpcSeed(
    id: 'trelawney',
    name: '西比尔·特里劳妮',
    gender: '女',
    aliases: ['特里劳妮教授', '占卜课教授'],
    house: 'Ravenclaw',
    grade: 0,
    bloodStatus: 'unknown',
    personality: ['神秘', '飘忽', '神经质'],
    appearance:
        '身材消瘦、眼神飘忽的女巫。戴着被放大了无数倍的眼镜，眼睛看起来像昆虫一样。披着缀满亮片和流苏的披肩，脖子上挂满珠串和护身符。声音如梦呓般飘忽不定。',
    era: 'all',
  ),
  NpcSeed(
    id: 'filch',
    name: '阿格斯·费尔奇',
    gender: '男',
    aliases: ['管理员', '看门人'],
    house: '',
    grade: 0,
    bloodStatus: 'squib',
    personality: ['阴郁', '严厉', '记仇'],
    appearance:
        '弯腰驼背、面容阴郁的男人。瘦削布满皱纹的脸，灰白头发稀疏地贴在头皮上。永远穿着一件破旧的棕色外套。走路时几乎不发出声音，像一只老猫在走廊里无声地滑行。',
    era: 'all',
  ),
  NpcSeed(
    id: 'pince',
    name: '伊尔玛·平斯',
    gender: '女',
    aliases: ['平斯夫人', '图书管理员'],
    house: '',
    grade: 0,
    bloodStatus: 'unknown',
    personality: ['严肃', '刻板', '护书'],
    appearance:
        '瘦得像铅笔一样的女人。灰发紧贴在头皮上，戴着钢丝边眼镜。嘴唇永远抿成一条不满的线。是霍格沃茨图书馆的守护者。',
    era: 'all',
  ),
  NpcSeed(
    id: 'pomfrey',
    name: '波比·庞弗雷',
    gender: '女',
    aliases: ['庞弗雷夫人', '校医', '护士长'],
    house: '',
    grade: 0,
    bloodStatus: 'unknown',
    personality: ['慈祥', '坚定', '负责'],
    appearance:
        '身材丰满、面容慈祥的女巫。银灰色卷发，总是穿着雪白的护士袍。语气温和而坚定，不允许任何人质疑她的医嘱。',
    era: 'all',
  ),
  NpcSeed(
    id: 'binns',
    name: '宾斯教授',
    gender: '男',
    aliases: ['宾斯', '宾斯先生', '魔法史教授', '幽灵教授'],
    house: '',
    grade: 0,
    bloodStatus: 'ghost',
    personality: ['单调', '健忘', '古板'],
    appearance:
        '魔法史教授，霍格沃茨唯一一位留在岗位上的幽灵。在教员休息室睡着后忘了带走身体。声音单调如旧唱片。',
    era: 'all',
  ),
];

/// 子世代（1991级）格兰芬多
const List<NpcSeed> harrySameGryffindor = [
  NpcSeed(
    id: 'harry',
    name: '哈利·波特',
    gender: '男',
    aliases: ['哈利波特', '大难不死的男孩', '救世之星', '波特先生'],
    house: 'Gryffindor',
    grade: 1,
    bloodStatus: 'halfblood',
    personality: ['勇敢', '忠诚', '冲动', '富有同情心'],
    appearance:
        '乱蓬蓬的黑发，翠绿色的眼睛（电影中为蓝色），额头上有一道闪电形的伤疤。戴着圆框眼镜，身材瘦小。看起来总是像刚刚经历过一场风暴。',
    era: 'harry_same',
    personalGoal: '在命运与平凡之间寻找自己',
  ),
  NpcSeed(
    id: 'hermione',
    name: '赫敏·格兰杰',
    gender: '女',
    aliases: ['妙丽', '万事通', '赫敏格兰杰'],
    house: 'Gryffindor',
    grade: 1,
    bloodStatus: 'muggleborn',
    personality: ['聪明', '勤奋', '正义', '有时固执'],
    appearance:
        '浓密的棕色卷发，大板牙（电影中为正常牙齿）。总是抱着一本厚厚的书，目光笃定而专注。声音带着一种不容置疑的自信。',
    era: 'harry_same',
    personalGoal: '证明麻瓜出身也能成为最优秀的巫师',
  ),
  NpcSeed(
    id: 'ron',
    name: '罗恩·韦斯莱',
    gender: '男',
    aliases: ['罗纳德', '罗罗', '罗恩韦斯莱'],
    house: 'Gryffindor',
    grade: 1,
    bloodStatus: 'pureblood',
    personality: ['幽默', '忠诚', '嫉妒', '勇敢'],
    appearance:
        '火红色的头发，满脸雀斑。个子高而瘦削，手脚都显得有点太大。鼻子上总是沾着一点什么——也许是巧克力，也许是魔药材料。',
    era: 'harry_same',
    personalGoal: '走出哥哥们的阴影',
  ),
  NpcSeed(
    id: 'neville',
    name: '纳威·隆巴顿',
    gender: '男',
    aliases: ['纳威隆巴顿', '纳胖'],
    house: 'Gryffindor',
    grade: 1,
    bloodStatus: 'pureblood',
    personality: ['善良', '勇敢', '笨拙', '成长'],
    appearance:
        '圆脸，一头淡棕色的短发。耳朵有点大，表情总是带着一丝紧张。抱着一只蟾蜍，叫莱福。',
    era: 'harry_same',
    personalGoal: '证明自己配得上父母留下的名字',
  ),
  NpcSeed(
    id: 'lavender',
    name: '拉文德·布朗',
    gender: '女',
    aliases: ['拉文德布朗', '小文'],
    house: 'Gryffindor',
    grade: 1,
    bloodStatus: 'unknown',
    personality: ['开朗', '热情', '八卦'],
    appearance: '浅棕色的长发，总是编着辫子。眼睛大而明亮，笑声清脆而频繁。',
    era: 'harry_same',
  ),
  NpcSeed(
    id: 'seamus',
    name: '西莫·斐尼甘',
    gender: '男',
    aliases: ['西莫斐尼甘', '爆炸王'],
    house: 'Gryffindor',
    grade: 1,
    bloodStatus: 'halfblood',
    personality: ['幽默', '冒失', '热情'],
    appearance:
        '深色短发，爱尔兰人的面容。说话时带着浓重的口音，魔咒课上经常出点小事故。',
    era: 'harry_same',
  ),
  NpcSeed(
    id: 'parvati',
    name: '帕瓦蒂·帕蒂尔',
    gender: '女',
    aliases: ['帕瓦蒂帕蒂尔', '小帕'],
    house: 'Gryffindor',
    grade: 1,
    bloodStatus: 'pureblood',
    personality: ['精致', '友善', '传统'],
    appearance:
        '黑色长发，深色眼睛。总是穿得比其他人更精致一些，耳环在烛光下闪闪发亮。',
    era: 'harry_same',
  ),
  NpcSeed(
    id: 'dean',
    name: '迪安·托马斯',
    gender: '男',
    aliases: ['迪安托马斯', '小迪'],
    house: 'Gryffindor',
    grade: 1,
    bloodStatus: 'halfblood',
    personality: ['温和', '艺术', '开朗'],
    appearance:
        '深色皮肤，黑色短发。喜欢画素描，魁地奇海报贴满了他的床铺四周。',
    era: 'harry_same',
  ),
  NpcSeed(
    id: 'ginny',
    name: '金妮·韦斯莱',
    gender: '女',
    aliases: ['金妮韦斯莱', '小金子', '金尼'],
    house: 'Gryffindor',
    grade: 1,
    bloodStatus: 'pureblood',
    personality: ['独立', '勇敢', '热情', '强势'],
    appearance:
        '火红色的长发，明亮的棕色眼睛。安静时像一只猫，愤怒时像一团火。',
    era: 'harry_same',
    personalGoal: '从"韦斯莱家的小妹妹"成为她自己',
  ),
  NpcSeed(
    id: 'colin',
    name: '科林·克里维',
    gender: '男',
    aliases: ['科林克里维', '小摄影师'],
    house: 'Gryffindor',
    grade: 1,
    bloodStatus: 'muggleborn',
    personality: ['崇拜', '热情', '执着'],
    appearance:
        '浅色头发，圆脸。永远举着一架相机，对哈利·波特的崇拜毫不掩饰。',
    era: 'harry_same',
  ),
];

/// 子世代 高年级
const List<NpcSeed> harrySameSenior = [
  NpcSeed(
    id: 'percy',
    name: '珀西·韦斯莱',
    gender: '男',
    aliases: ['珀西韦斯莱', '级长', '学生会主席'],
    house: 'Gryffindor',
    grade: 5,
    bloodStatus: 'pureblood',
    personality: ['刻板', '上进', '官僚'],
    appearance: '红发，戴着角质框眼镜。永远板着一张脸，怀里抱着厚厚一叠文件。',
    era: 'harry_same',
  ),
  NpcSeed(
    id: 'wood',
    name: '奥利弗·伍德',
    gender: '男',
    aliases: ['奥利弗伍德', '队长大人', '魁地奇队长'],
    house: 'Gryffindor',
    grade: 7,
    bloodStatus: 'unknown',
    personality: ['执着', '热血', '严格'],
    appearance: '深色短发，面容坚毅。眼睛里只有一件事：魁地奇杯。',
    era: 'harry_same',
  ),
  NpcSeed(
    id: 'fred',
    name: '弗雷德·韦斯莱',
    gender: '男',
    aliases: ['弗雷德韦斯莱', '双胞胎', '捣蛋王'],
    house: 'Gryffindor',
    grade: 6,
    bloodStatus: 'pureblood',
    personality: ['调皮', '创意', '幽默', '冒险'],
    appearance: '红发双胞胎之一，笑容狡黠。眼睛总是在寻找下一个恶作剧的目标。',
    era: 'harry_same',
  ),
  NpcSeed(
    id: 'george',
    name: '乔治·韦斯莱',
    gender: '男',
    aliases: ['乔治韦斯莱', '双胞胎', '捣蛋王'],
    house: 'Gryffindor',
    grade: 6,
    bloodStatus: 'pureblood',
    personality: ['调皮', '商业头脑', '幽默', '忠诚'],
    appearance: '红发双胞胎之一，与弗雷德如出一辙的狡黠笑容。',
    era: 'harry_same',
  ),
  NpcSeed(
    id: 'lee',
    name: '李·乔丹',
    gender: '男',
    aliases: ['李乔丹', '解说员', '小李'],
    house: 'Gryffindor',
    grade: 6,
    bloodStatus: 'unknown',
    personality: ['健谈', '幽默', '活力'],
    appearance:
        '深色皮肤，黑色短发。魁地奇比赛解说员，声音洪亮而富有感染力。',
    era: 'harry_same',
  ),
  NpcSeed(
    id: 'angelina',
    name: '安吉丽娜·约翰逊',
    gender: '女',
    aliases: ['安吉丽娜约翰逊', '追球手', '小安'],
    house: 'Gryffindor',
    grade: 6,
    bloodStatus: 'unknown',
    personality: ['自信', '果敢', '开朗'],
    appearance:
        '高挑而健美，深色皮肤。格兰芬多魁地奇队追球手，笑容自信而灿烂。',
    era: 'harry_same',
  ),
];

/// 斯莱特林（子世代）
const List<NpcSeed> harrySameSlytherin = [
  NpcSeed(
    id: 'draco',
    name: '德拉科·马尔福',
    gender: '男',
    aliases: ['德拉克', '小龙', '马尔福少爷'],
    house: 'Slytherin',
    grade: 1,
    bloodStatus: 'pureblood',
    personality: ['野心', '骄傲', '忠诚', '偏见'],
    appearance:
        '淡金色的头发，灰色的眼睛，脸色苍白而精致。下巴总是微微抬起，带着一种与生俱来的傲慢。',
    era: 'harry_same',
    personalGoal: '在父亲的阴影下找到自己的道路',
  ),
  NpcSeed(
    id: 'crabbe',
    name: '文森特·克拉布',
    gender: '男',
    aliases: ['文森特克拉布', '小克拉布'],
    house: 'Slytherin',
    grade: 1,
    bloodStatus: 'pureblood',
    personality: ['迟钝', '盲从', '粗壮'],
    appearance: '身材粗壮，深色短发。表情永远是茫然和迟钝的。',
    era: 'harry_same',
  ),
  NpcSeed(
    id: 'goyle',
    name: '格雷戈里·高尔',
    gender: '男',
    aliases: ['格雷戈里高尔', '小高尔'],
    house: 'Slytherin',
    grade: 1,
    bloodStatus: 'pureblood',
    personality: ['沉默', '盲从', '粗壮'],
    appearance: '身材更加粗壮，浅色短发。沉默比克拉布更深。',
    era: 'harry_same',
  ),
  NpcSeed(
    id: 'pansy',
    name: '潘西·帕金森',
    gender: '女',
    aliases: ['潘西帕金森', '潘女王'],
    house: 'Slytherin',
    grade: 1,
    bloodStatus: 'pureblood',
    personality: ['傲慢', '刻薄', '势利'],
    appearance:
        '黑色短发，尖下巴。嘴角永远向下撇着，像一只傲慢的哈巴狗。',
    era: 'harry_same',
  ),
  NpcSeed(
    id: 'blaise',
    name: '布莱斯·沙比尼',
    gender: '男',
    aliases: ['布莱斯沙比尼', '布莱兹'],
    house: 'Slytherin',
    grade: 1,
    bloodStatus: 'pureblood',
    personality: ['冷漠', '观察', '优雅'],
    appearance:
        '深色皮肤，面容英俊而冷漠。总是站在人群边缘，目光疏离地观察着一切。',
    era: 'harry_same',
  ),
];

/// 拉文克劳（子世代）
const List<NpcSeed> harrySameRavenclaw = [
  NpcSeed(
    id: 'cho',
    name: '秋·张',
    gender: '女',
    aliases: ['秋张', '张秋', '初恋姐姐'],
    house: 'Ravenclaw',
    grade: 5,
    bloodStatus: 'unknown',
    personality: ['温婉', '优秀', '感性'],
    appearance: '黑色长发，深色眼睛，面容温婉而秀美。笑容含蓄而礼貌。',
    era: 'harry_same',
  ),
  NpcSeed(
    id: 'luna',
    name: '卢娜·洛夫古德',
    gender: '女',
    aliases: ['疯姑娘', '露娜', '卢娜洛夫古德'],
    house: 'Ravenclaw',
    grade: 2,
    bloodStatus: 'unknown',
    personality: ['独特', '善良', '超脱', '直觉'],
    appearance:
        '浅金色长发，像月光一样垂到腰间。银灰色的眼睛目光微微失焦，仿佛在看着另一个世界的东西。戴着一串用软木塞串成的项链。',
    era: 'harry_same',
    personalGoal: '让世界相信那些"看不见的东西"',
  ),
  NpcSeed(
    id: 'penelope',
    name: '佩内洛·克里瓦特',
    gender: '女',
    aliases: ['佩内洛克里瓦特', '级长姐姐'],
    house: 'Ravenclaw',
    grade: 5,
    bloodStatus: 'unknown',
    personality: ['聪慧', '尽责', '独立'],
    appearance: '棕色长发，面容聪慧。拉文克劳的级长。',
    era: 'harry_same',
  ),
  NpcSeed(
    id: 'roger',
    name: '罗杰·戴维斯',
    gender: '男',
    aliases: ['罗杰戴维斯', '拉文克劳队长'],
    house: 'Ravenclaw',
    grade: 6,
    bloodStatus: 'unknown',
    personality: ['自信', '英俊', '洒脱'],
    appearance: '深色短发，面容英俊。拉文克劳魁地奇队队长。',
    era: 'harry_same',
  ),
];

/// 赫奇帕奇（子世代）
const List<NpcSeed> harrySameHufflepuff = [
  NpcSeed(
    id: 'cedric',
    name: '塞德里克·迪戈里',
    gender: '男',
    aliases: ['塞德里克迪戈里', '塞德', '赫奇帕奇英雄'],
    house: 'Hufflepuff',
    grade: 5,
    bloodStatus: 'pureblood',
    personality: ['正直', '优秀', '稳重', '公平'],
    appearance:
        '黑发，深色眼睛，英俊而温暖。笑容像阳光一样坦荡。赫奇帕奇的骄傲。',
    era: 'harry_same',
    personalGoal: '成为配得上赫奇帕奇名声的勇士',
  ),
  NpcSeed(
    id: 'hannah',
    name: '汉娜·艾博',
    gender: '女',
    aliases: ['汉娜艾博', '小汉娜'],
    house: 'Hufflepuff',
    grade: 1,
    bloodStatus: 'unknown',
    personality: ['温柔', '安静', '善良'],
    appearance: '金发碧眼，圆脸。说话时声音柔和，像一只安静的兔子。',
    era: 'harry_same',
  ),
  NpcSeed(
    id: 'susan',
    name: '苏珊·波恩',
    gender: '女',
    aliases: ['苏珊波恩', '小苏'],
    house: 'Hufflepuff',
    grade: 1,
    bloodStatus: 'unknown',
    personality: ['可靠', '稳重', '善良'],
    appearance: '棕色长发，圆脸。赫奇帕奇里最可靠的人之一。',
    era: 'harry_same',
  ),
  NpcSeed(
    id: 'ernie',
    name: '厄尼·麦克米兰',
    gender: '男',
    aliases: ['厄尼麦克米兰', '小厄'],
    house: 'Hufflepuff',
    grade: 1,
    bloodStatus: 'pureblood',
    personality: ['自视甚高', '庄重', '好学'],
    appearance: '浅色短发，圆脸。说话时总是带着一种自以为是的庄重。',
    era: 'harry_same',
  ),
  NpcSeed(
    id: 'zacharias',
    name: '扎卡赖斯·史密斯',
    gender: '男',
    aliases: ['扎卡赖斯史密斯', '扎卡里亚斯', '挑剔鬼'],
    house: 'Hufflepuff',
    grade: 1,
    bloodStatus: 'pureblood',
    personality: ['挑剔', '精明', '谨慎'],
    appearance: '金发，面容精致。眼神里总有一种挑剔的审视。',
    era: 'harry_same',
  ),
];

/// 亲世代（1971级）掠夺者时代
const List<NpcSeed> maraudersSeeds = [
  NpcSeed(
    id: 'james',
    name: '詹姆·波特',
    gender: '男',
    aliases: ['詹姆波特', '尖头叉子', '哈利父亲'],
    house: 'Gryffindor',
    grade: 1,
    bloodStatus: 'pureblood',
    personality: ['自信', '顽皮', '勇敢', '护短'],
    appearance:
        '黑发凌乱，一双榛色的眼睛。身材颀长，脸上总挂着玩世不恭的笑容。格兰芬多的魁地奇追球手。',
    era: 'marauders',
    personalGoal: '成为最耀眼的巫师与最忠诚的朋友',
  ),
  NpcSeed(
    id: 'sirius',
    name: '小天狼星·布莱克',
    gender: '男',
    aliases: ['西里斯', '大脚板', '教父'],
    house: 'Gryffindor',
    grade: 1,
    bloodStatus: 'pureblood',
    personality: ['叛逆', '勇敢', '不羁', '忠诚'],
    appearance:
        '黑色长发，英俊而带一丝不驯。与布莱克家族决裂后，举止透着贵族出身的底子与叛逆的锋芒。',
    era: 'marauders',
    personalGoal: '挣脱布莱克家族的枷锁',
  ),
  NpcSeed(
    id: 'remus',
    name: '莱姆斯·卢平',
    gender: '男',
    aliases: ['莱姆斯卢平', '月亮脸', '卢平教授'],
    house: 'Gryffindor',
    grade: 1,
    bloodStatus: 'halfblood',
    personality: ['温和', '隐忍', '聪慧', '善良'],
    appearance:
        '浅棕色头发，面容温和而带着一丝病态的苍白。眼神疲惫却温柔，总穿着打了补丁的旧袍子。',
    era: 'marauders',
    personalGoal: '藏好那个满月的秘密',
  ),
  NpcSeed(
    id: 'pettigrew',
    name: '小矮星彼得',
    gender: '男',
    aliases: ['彼得', '小矮星', '虫尾巴', '彼德', '叛徒'],
    house: 'Gryffindor',
    grade: 1,
    bloodStatus: 'halfblood',
    personality: ['怯懦', '谄媚', '自私'],
    appearance:
        '矮小肥胖，浅色头发。总是缩在人群边缘，眼神闪烁而讨好。',
    era: 'marauders',
  ),
  NpcSeed(
    id: 'lily',
    name: '莉莉·伊万斯',
    gender: '女',
    aliases: ['莉莉伊万斯', '莉莉波特', '哈利母亲'],
    house: 'Gryffindor',
    grade: 1,
    bloodStatus: 'muggleborn',
    personality: ['善良', '坚定', '聪慧', '宽容'],
    appearance:
        '一头火红色的长发，翠绿色的眼睛明亮而温柔。笑起来像春日阳光。',
    era: 'marauders',
    personalGoal: '用善良治愈那道裂痕',
  ),
  NpcSeed(
    id: 'snape_young',
    name: '西弗勒斯·斯内普',
    gender: '男',
    aliases: ['混血王子', '少年斯内普'],
    house: 'Slytherin',
    grade: 1,
    bloodStatus: 'halfblood',
    personality: ['孤僻', '聪慧', '敏感', '执着'],
    appearance:
        '瘦削的少年，一头油腻的黑发垂在颊侧。黑色的眼睛里藏着不易察觉的脆弱与执拗。',
    era: 'marauders',
    personalGoal: '守护与莉莉之间仅有的光明',
  ),
  NpcSeed(
    id: 'regulus',
    name: '雷古勒斯·布莱克',
    gender: '男',
    aliases: ['雷古勒斯布莱克', 'R.A.B.', '雷古'],
    house: 'Slytherin',
    grade: 2,
    bloodStatus: 'pureblood',
    personality: ['顺从', '内心挣扎', '勇敢'],
    appearance:
        '与小天狼星相似的英俊面容，但更内敛、更阴郁。黑色短发，气质沉静。',
    era: 'marauders',
    personalGoal: '在家族的黑暗里找回良知',
  ),
];

/// 邓布利多时代（1892-1899）
const List<NpcSeed> dumbledoreEraSeeds = [
  NpcSeed(
    id: 'young_dumbledore',
    name: '阿不思·邓布利多',
    gender: '男',
    aliases: ['少年邓布利多'],
    house: 'Gryffindor',
    grade: 1,
    bloodStatus: 'halfblood',
    personality: ['才华横溢', '善良', '理想主义', '热情'],
    appearance:
        '少年阿不思·邓布利多，深棕色长发，蓝眼睛明亮而充满热情。刚从戈德里克山谷走来，指尖还带着泥土的气息。',
    era: 'dumbledore',
    personalGoal: '在才华与家庭的重负间找到平衡',
  ),
  NpcSeed(
    id: 'grindelwald',
    name: '盖勒特·格林德沃',
    gender: '男',
    aliases: ['黑魔王', '第一代黑魔王'],
    house: '',
    grade: 0,
    bloodStatus: 'pureblood',
    personality: ['天才', '迷人', '狂热', '野心'],
    appearance:
        '金发少年，面容英俊而带着一丝危险的魅力。笑容迷人，眼神里藏着野火般的狂热。',
    era: 'dumbledore',
    personalGoal: '为"更伟大的利益"寻找伙伴',
  ),
  NpcSeed(
    id: 'arianna',
    name: '阿利安娜·邓布利多',
    gender: '女',
    aliases: ['阿利安娜邓布利多', '妹妹', '默然者'],
    house: '',
    grade: 0,
    bloodStatus: 'unknown',
    personality: ['脆弱', '沉默', '痛苦'],
    appearance:
        '阿不思的妹妹，因幼年创伤而成为默然者。美丽的金发少女，眼神时而澄澈时而空洞。',
    era: 'dumbledore',
  ),
  // ⚠️ 这里原先放的是「少女麦格」。米勒娃·麦格生于 1935 年，
  // 1892 年她还没出生——这条是时代穿帮，已换成同龄的原创同学。
  NpcSeed(
    id: 'eleanor_vance',
    name: '埃莉诺·万斯',
    gender: '女',
    aliases: ['万斯', '埃莉诺'],
    house: 'Gryffindor',
    grade: 1,
    bloodStatus: 'halfblood',
    personality: ['敏锐', '好胜', '直言'],
    appearance:
        '红棕色头发束成一条粗辫子，绿眼睛，手指上总有洗不掉的墨水。说话快，笑起来却很慢。',
    era: 'dumbledore',
    personalGoal: '在变形术上赢过邓布利多一次',
  ),
  NpcSeed(
    id: 'abercrombie_dippet',
    name: '阿芒多·迪佩特',
    gender: '男',
    aliases: ['迪佩特教授', '迪佩特'],
    house: '',
    grade: 0,
    bloodStatus: 'pureblood',
    personality: ['温和', '守旧', '怕麻烦'],
    appearance:
        '一位头发稀疏、胡须修剪整齐的老先生，说话慢条斯理。此时还未接任校长，在城堡里教变形术。',
    era: 'dumbledore',
    personalGoal: '平安无事地教到退休',
  ),
  NpcSeed(
    id: 'galvenus_wigan',
    name: '加尔维纳斯·维甘',
    gender: '男',
    aliases: ['维甘教授'],
    house: '',
    grade: 0,
    bloodStatus: 'pureblood',
    personality: ['严厉', '务实', '不近人情'],
    appearance:
        '黑魔法防御术教授。身材瘦削，深色长袍，右手少了一根小指——据说是年轻时留下的纪念。',
    era: 'dumbledore',
    personalGoal: '让学生记住恐惧是什么形状',
  ),
  NpcSeed(
    id: 'perpetua_fancourt',
    name: '佩尔佩图亚·范考特',
    gender: '女',
    aliases: ['范考特夫人'],
    house: '',
    grade: 0,
    bloodStatus: 'pureblood',
    personality: ['刻薄', '讲究', '护短'],
    appearance:
        '草药学教授。永远戴着一顶插着干花的帽子，说话时鼻翼微张，像在闻什么不对劲的味道。',
    era: 'dumbledore',
    personalGoal: '让温室里的每一株植物都守规矩',
  ),
  NpcSeed(
    id: 'abercrombie_abbot',
    name: '阿不思的弟弟·阿不福思',
    gender: '男',
    aliases: ['阿不福思', '邓布利多的弟弟'],
    house: '',
    grade: 0,
    bloodStatus: 'halfblood',
    personality: ['粗鲁', '护短', '沉默'],
    appearance:
        '比阿不思矮小一些，棕发乱糟糟，蓝眼睛里总带着一股没处使的火气。手上常有喂羊留下的草屑。',
    era: 'dumbledore',
    personalGoal: '把妹妹看好，别让任何人再伤到她',
  ),
  NpcSeed(
    id: 'corvin_gaunt',
    name: '科尔文·冈特',
    gender: '男',
    aliases: ['冈特'],
    house: 'Slytherin',
    grade: 1,
    bloodStatus: 'pureblood',
    personality: ['傲慢', '阴郁', '记仇'],
    appearance:
        '冈特家的次子。脸色苍白，黑发油腻，说话时总把「纯血」两个字咬得很重。',
    era: 'dumbledore',
    personalGoal: '让所有人都记得冈特这个名字',
  ),
  NpcSeed(
    id: 'millicent_bagshot',
    name: '米利森特·巴沙特',
    gender: '女',
    aliases: ['巴沙特'],
    house: 'Ravenclaw',
    grade: 1,
    bloodStatus: 'halfblood',
    personality: ['好奇', '书卷气', '爱打听'],
    appearance:
        '瘦高的女生，鼻梁上架着一副总是滑下来的眼镜，怀里永远抱着比自己脑袋还大的书。',
    era: 'dumbledore',
    personalGoal: '把城堡里每一条秘密通道都走一遍',
  ),
  NpcSeed(
    id: 'Hector_flint',
    name: '赫克托·弗林特',
    gender: '男',
    aliases: ['弗林特'],
    house: 'Slytherin',
    grade: 3,
    bloodStatus: 'pureblood',
    personality: ['霸道', '好斗', '讲规矩'],
    appearance:
        '三年级的斯莱特林，肩膀已经比同齡人宽出一圈。笑起来露出一颗补过的牙。',
    era: 'dumbledore',
    personalGoal: '进魁地奇校队，然后当上队长',
  ),
  NpcSeed(
    id: 'winifred_oliver',
    name: '温妮弗雷德·奥利弗',
    gender: '女',
    aliases: ['奥利弗', '温妮'],
    house: 'Hufflepuff',
    grade: 2,
    bloodStatus: 'muggleborn',
    personality: ['热心', '实在', '不服输'],
    appearance:
        '赫奇帕奇的二年级生，圆脸，头发用一块花布扎着。袖口总是卷到手肘，指甲缝里有泥土。',
    era: 'dumbledore',
    personalGoal: '让所有人知道麻瓜出身不比谁差',
  ),
  NpcSeed(
    id: 'silas_throckmorton',
    name: '赛拉斯·斯洛克莫顿',
    gender: '男',
    aliases: ['斯洛克莫顿'],
    house: 'Ravenclaw',
    grade: 4,
    bloodStatus: 'pureblood',
    personality: ['孤僻', '痴迷', '不修边幅'],
    appearance:
        '四年级的拉文克劳，长袍上总有洗不掉的化学污渍。说话时眼睛不看人，只盯着自己手里的东西。',
    era: 'dumbledore',
    personalGoal: '做出一种从没有人做出来的魔药',
  ),
  NpcSeed(
    id: 'honoria_peverell',
    name: '霍诺莉亚·佩弗利尔',
    gender: '女',
    aliases: ['佩弗利尔'],
    house: 'Slytherin',
    grade: 5,
    bloodStatus: 'pureblood',
    personality: ['优雅', '冷淡', '城府深'],
    appearance:
        '五年级的斯莱特林女生，黑发挽成一个一丝不苟的髻。据说是佩弗利尔家的远支，她从不否认。',
    era: 'dumbledore',
    personalGoal: '让家族的名字重新回到魔法史里',
  ),
  NpcSeed(
    id: 'barnaby_crook',
    name: '巴纳比·克鲁克',
    gender: '男',
    aliases: ['克鲁克'],
    house: 'Gryffindor',
    grade: 6,
    bloodStatus: 'halfblood',
    personality: ['莽撞', '义气', '爱吹牛'],
    appearance:
        '六年级的格兰芬多，个子高得进门前要低头。左眉骨上有一道愈合得不太好的疤。',
    era: 'dumbledore',
    personalGoal: '在毕业前干一件让全校记住的事',
  ),
  NpcSeed(
    id: 'wilhelmina_filch_ancestor',
    name: '韦瑟比·费尔奇',
    gender: '男',
    aliases: ['费尔奇', '管理员费尔奇'],
    house: '',
    grade: 0,
    bloodStatus: 'squib',
    personality: ['刻薄', '多疑', '孤独'],
    appearance:
        '城堡管理员。灰白头发，眼睛突出，走路时脚步声轻得不像话。身上总带着一股擦拭剂的味道。',
    era: 'dumbledore',
    personalGoal: '抓住每一个违反校规的人',
  ),
];

/// 现代（2020+）
const List<NpcSeed> postWarSeeds = [
  NpcSeed(
    id: 'albus_porter',
    name: '阿不思·西弗勒斯·波特',
    gender: '男',
    aliases: ['阿不思波特', '小波特', '阿尔'],
    house: 'Slytherin',
    grade: 1,
    bloodStatus: 'halfblood',
    personality: ['敏感', '自卑', '渴望认可', '勇敢'],
    appearance:
        '黑发，戴眼镜，面容与父亲哈利十分相似，但神情更安静、更犹豫。',
    era: 'post_war',
    personalGoal: '走出父母名声的阴影',
  ),
  NpcSeed(
    id: 'scorpius',
    name: '斯科皮·马尔福',
    gender: '男',
    aliases: ['斯科皮马尔福', '小马尔福', '蝎子'],
    house: 'Slytherin',
    grade: 1,
    bloodStatus: 'pureblood',
    personality: ['善良', '开朗', '忠诚', '坦率'],
    appearance:
        '淡金色头发，灰色眼睛，面容英俊。与父亲德拉科相似，却少了几分傲慢，多了几分温暖。',
    era: 'post_war',
    personalGoal: '打破关于自己身世的谣言',
  ),
  NpcSeed(
    id: 'delphi',
    name: '德尔菲·里德尔',
    gender: '女',
    aliases: ['德尔菲里德尔', '伏地魔之女', '神秘少女'],
    house: 'Slytherin',
    grade: 0,
    bloodStatus: 'pureblood',
    personality: ['阴郁', '执着', '狂热'],
    appearance:
        '伏地魔的女儿，深色头发，面容冷峻而美丽。潜伏在暗处，等待着属于她的时机。',
    era: 'post_war',
    personalGoal: '让父亲的传奇复生',
  ),
  NpcSeed(
    id: 'james_sirius',
    name: '詹姆·小天狼星·波特',
    gender: '男',
    aliases: ['詹姆', '小詹姆'],
    house: 'Gryffindor',
    grade: 6,
    bloodStatus: 'halfblood',
    personality: ['张扬', '爱闹', '护短'],
    appearance:
        '黑发乱得很有型，下颌线已经能看出父亲当年的影子。笑起来露出一口白牙，走路带风。',
    era: 'post_war',
    personalGoal: '让弟弟知道他不是家里唯一值得操心的人',
  ),
  NpcSeed(
    id: 'rose_weasley',
    name: '罗丝·韦斯莱',
    gender: '女',
    aliases: ['罗丝', '罗丝格兰杰韦斯莱'],
    house: 'Gryffindor',
    grade: 5,
    bloodStatus: 'halfblood',
    personality: ['要强', '聪明', '嘴上不饶人'],
    appearance:
        '继承了母亲的浓密棕发和父亲的身高。说话时习惯性抬下巴，像随时准备反驳。',
    era: 'post_war',
    personalGoal: '在所有事情上都做到最好，哪怕没人看着',
  ),
  NpcSeed(
    id: 'hugo_weasley',
    name: '雨果·韦斯莱',
    gender: '男',
    aliases: ['雨果'],
    house: 'Hufflepuff',
    grade: 2,
    bloodStatus: 'halfblood',
    personality: ['温和', '慢热', '可靠'],
    appearance:
        '罗丝的弟弟。红发，圆脸，比姐姐矮半个头，笑起来眼睛会眯成一条缝。',
    era: 'post_war',
    personalGoal: '不被拿来和姐姐比较',
  ),
  NpcSeed(
    id: 'teddy_lupin',
    name: '泰迪·卢平',
    gender: '男',
    aliases: ['泰迪'],
    house: '',
    grade: 0,
    bloodStatus: 'halfblood',
    personality: ['温和', '体贴', '有点没正形'],
    appearance:
        '头发是会随心情变色的易容马人的天赋——此刻是柔软的青绿色。笑起来像个还没长大的孩子，虽然已经是正经傲罗了。',
    era: 'post_war',
    personalGoal: '做一个配得上自己姓氏的人',
  ),
  NpcSeed(
    id: 'victorie_weasley',
    name: '维克托娃·韦斯莱',
    gender: '女',
    aliases: ['维克托娃'],
    house: '',
    grade: 0,
    bloodStatus: 'pureblood',
    personality: ['爽利', '能干', '爱操心'],
    appearance:
        '比尔的大女儿，金红色长发，笑起来有酒窝。已经在魔法部实习，制服穿得一丝不苟。',
    era: 'post_war',
    personalGoal: '在家族这棵大树旁边长出自己的形状',
  ),
  NpcSeed(
    id: 'lorna_scamander',
    name: '洛娜·斯卡曼德',
    gender: '女',
    aliases: ['斯卡曼德教授'],
    house: '',
    grade: 0,
    bloodStatus: 'pureblood',
    personality: ['沉静', '专注', '不擅闲聊'],
    appearance:
        '纽特的孙媳，神奇生物学教授。头发随意挽着，长袍口袋里总有什么东西在动。',
    era: 'post_war',
    personalGoal: '让更多人学会敬畏而不是捕捉',
  ),
  NpcSeed(
    id: 'augustus_longbottom',
    name: '奥古斯塔斯·隆巴顿',
    gender: '男',
    aliases: ['小隆巴顿', '奥古'],
    house: 'Hufflepuff',
    grade: 1,
    bloodStatus: 'pureblood',
    personality: ['害羞', '较真', '善良'],
    appearance:
        '纳威的侄子。圆脸，头发软趴趴的，说话前总要深吸一口气。手指上总有泥。',
    era: 'post_war',
    personalGoal: '在草药课上不被姑姑的名字压得喘不过气',
  ),
  NpcSeed(
    id: 'lysandra_yaxley',
    name: '莱桑德拉·亚克斯利',
    gender: '女',
    aliases: ['亚克斯利'],
    house: 'Slytherin',
    grade: 1,
    bloodStatus: 'pureblood',
    personality: ['冷淡', '自尊心强', '观察力惊人'],
    appearance:
        '斯莱特林的一年级生，黑发齐肩，站姿笔直。姓氏在战争期间上过《预言家日报》，她从不主动提。',
    era: 'post_war',
    personalGoal: '让大家记住的是她，不是她的姓',
  ),
  NpcSeed(
    id: 'callum_fawley',
    name: '卡勒姆·福利',
    gender: '男',
    aliases: ['福利'],
    house: 'Ravenclaw',
    grade: 1,
    bloodStatus: 'muggleborn',
    personality: ['好奇', '话多', '不怯场'],
    appearance:
        '拉文克劳的新生，戴一副圆框眼镜，书包里塞着一台拆了一半的麻瓜收音机——他说要研究它为什么不响。',
    era: 'post_war',
    personalGoal: '搞清楚魔法和电到底为什么互相妨碍',
  ),
  NpcSeed(
    id: 'priya_shafiq',
    name: '普里娅·沙菲克',
    gender: '女',
    aliases: ['普里娅'],
    house: 'Gryffindor',
    grade: 3,
    bloodStatus: 'halfblood',
    personality: ['开朗', '讲义气', '爱管闲事'],
    appearance:
        '三年级的格兰芬多，深色长发编成一条长辫甩在背后。笑起来声音很大，隔两条走廊都听得见。',
    era: 'post_war',
    personalGoal: '让学院杯这次别再输',
  ),
  NpcSeed(
    id: 'neville_professor',
    name: '纳威·隆巴顿',
    gender: '男',
    aliases: ['隆巴顿教授'],
    house: '',
    grade: 0,
    bloodStatus: 'pureblood',
    personality: ['耐心', '沉稳', '意外地严厉'],
    appearance:
        '草药学教授。当年那个总把东西摔碎的男孩，如今站在讲台上，长袍口袋里塞满了种子和绷带。',
    era: 'post_war',
    personalGoal: '让每个学生都找到一件自己擅长的事',
  ),
];

/// 第一次巫师战争时代（1976级）：掠夺者一代进入六年级。
/// 亲世代种子 grade+5（1971 一年级 → 1976 六年级）。
final List<NpcSeed> firstWarSeeds = [
  for (final s in maraudersSeeds)
    NpcSeed(
      id: s.id,
      name: s.name,
      aliases: List.of(s.aliases),
      house: s.house,
      grade: s.grade + 5,
      bloodStatus: s.bloodStatus,
      personality: List.of(s.personality),
      appearance: s.appearance,
      era: 'first_war',
      gender: s.gender,
      sexOrientation: s.sexOrientation,
      giftPrefs: Map.of(s.giftPrefs),
      personalGoal: s.personalGoal,
    ),
];

/// 第一次巫师战争（1976-1977）时代原创名录。
///
/// 为什么需要这份：first_war 时代此前一个专属 NPC 都没有——
/// firstWarSeeds 只是把掠夺者四人组 grade+5 复刻了一遍，
/// 于是「伏地魔崛起、社会撕裂」这个设定里，玩家身边全是熟面孔，
/// 没有真正属于这个时代的阵容：既没有未来的食死徒同学，
/// 也没有未来的凤凰社成员，时代氛围完全立不起来。
///
/// 1976-77 学年在校的学生，正是几年后各自选边、彼此为敌的那一代。
const List<NpcSeed> firstWarOriginals = [
  // ===== 未来的食死徒（在校生）=====
  NpcSeed(
    id: 'evan_rosier',
    name: '埃文·罗齐尔',
    gender: '男',
    aliases: ['罗齐尔', '埃文罗齐尔'],
    house: 'Slytherin',
    grade: 6,
    bloodStatus: 'pureblood',
    personality: ['冷酷', '精明', '傲慢', '内敛'],
    appearance:
        '瘦高的少年，深色头发梳理得一丝不苟，斯莱特林长袍永远熨得笔挺。'
        '笑意很浅，话不多，眼神里却有种让人不舒服的笃定。',
    era: 'first_war',
    personalGoal: '让纯血统重新站到魔法界之上',
  ),
  NpcSeed(
    id: 'mulciber',
    name: '穆尔塞伯',
    gender: '男',
    aliases: ['穆尔塞伯同学'],
    house: 'Slytherin',
    grade: 6,
    bloodStatus: 'pureblood',
    personality: ['残忍', '野心', '阴郁', '果断'],
    appearance:
        '肩膀厚实，动作缓慢而用力。很少大声说话，但走廊里有学生会在他经过时绕开走。',
    era: 'first_war',
    personalGoal: '掌握让人屈服的手段',
  ),
  NpcSeed(
    id: 'travers',
    name: '特拉弗斯',
    gender: '男',
    aliases: ['特拉弗斯同学'],
    house: 'Slytherin',
    grade: 7,
    bloodStatus: 'pureblood',
    personality: ['沉默', '忠诚', '深沉', '固执'],
    appearance:
        '七年级，身形结实。脸上几乎没有表情，习惯站在人群后面听，然后一言不发地走开。',
    era: 'first_war',
    personalGoal: '服侍那个他认为会赢的人',
  ),

  // ===== 未来的凤凰社成员（在校生）=====
  NpcSeed(
    id: 'marlene',
    name: '马琳·麦金农',
    gender: '女',
    aliases: ['马琳麦金农', '麦金农'],
    house: 'Gryffindor',
    grade: 6,
    bloodStatus: 'pureblood',
    personality: ['开朗', '勇敢', '直率', '幽默'],
    appearance:
        '金色长发束成高马尾，笑起来声音很大。格兰芬多公共休息室里最能带动气氛的人之一。',
    era: 'first_war',
    personalGoal: '不让任何人替她决定该站在哪一边',
  ),
  NpcSeed(
    id: 'dorcas',
    name: '多卡斯·梅多斯',
    gender: '女',
    aliases: ['多卡斯梅多斯', '梅多斯'],
    house: 'Gryffindor',
    grade: 7,
    bloodStatus: 'halfblood',
    personality: ['机智', '勇敢', '善于交际', '敏锐'],
    appearance:
        '深色卷发，眼尾有一点笑纹。说话快而俏皮，但课堂上记的笔记是全年级最整齐的。',
    era: 'first_war',
    personalGoal: '在越来越紧的风声里守住朋友',
  ),
  NpcSeed(
    id: 'gideon',
    name: '吉迪翁·普威特',
    gender: '男',
    aliases: ['吉迪翁普威特', '普威特兄弟'],
    house: 'Gryffindor',
    grade: 7,
    bloodStatus: 'pureblood',
    personality: ['幽默', '勇敢', '乐观', '护短'],
    appearance:
        '红发，和孪生弟弟几乎一模一样，只是笑起来更张扬些。兄弟俩总是一起出现。',
    era: 'first_war',
    personalGoal: '和弟弟一起笑着熬过这个时代',
  ),
  NpcSeed(
    id: 'fabian',
    name: '费比安·普威特',
    gender: '男',
    aliases: ['费比安普威特', '普威特兄弟'],
    house: 'Gryffindor',
    grade: 7,
    bloodStatus: 'pureblood',
    personality: ['幽默', '勇敢', '随和', '固执'],
    appearance:
        '红发，比哥哥安静一点点，但被惹到时第一个站出来的往往是他。',
    era: 'first_war',
    personalGoal: '不让恐惧决定自己怎么活',
  ),
  NpcSeed(
    id: 'edgar',
    name: '埃德加·博恩斯',
    gender: '男',
    aliases: ['埃德加博恩斯', '博恩斯'],
    house: 'Hufflepuff',
    grade: 7,
    bloodStatus: 'halfblood',
    personality: ['正直', '可靠', '勤勉', '温和'],
    appearance:
        '方脸，肩膀宽，握手很有力。级长徽章擦得锃亮，做事一板一眼。',
    era: 'first_war',
    personalGoal: '证明出身不决定立场',
  ),
  NpcSeed(
    id: 'benjy',
    name: '本吉·芬威克',
    gender: '男',
    aliases: ['本吉芬威克', '芬威克'],
    house: 'Hufflepuff',
    grade: 6,
    bloodStatus: 'halfblood',
    personality: ['忠诚', '好奇', '乐观', '耐心'],
    appearance:
        '圆脸，头发总是乱的。喜欢蹲在温室后面观察神奇生物，口袋里常塞着零食。',
    era: 'first_war',
    personalGoal: '弄明白黑魔法到底是怎么蛊惑人的',
  ),
  NpcSeed(
    id: 'caradoc',
    name: '卡拉多克·迪尔伯恩',
    gender: '男',
    aliases: ['卡拉多克迪尔伯恩', '迪尔伯恩'],
    house: 'Ravenclaw',
    grade: 6,
    bloodStatus: 'halfblood',
    personality: ['神秘', '独立', '聪明', '内敛'],
    appearance:
        '总是独自坐在图书馆靠窗的位置。有人说他同时在做三件互不相干的事，没人证实过。',
    era: 'first_war',
    personalGoal: '在所有人选边之前先看清棋盘',
  ),
  NpcSeed(
    id: 'emmeline',
    name: '埃米琳·万斯',
    gender: '女',
    aliases: ['埃米琳万斯', '万斯'],
    house: 'Hufflepuff',
    grade: 5,
    bloodStatus: 'halfblood',
    personality: ['善良', '坚韧', '体贴', '正义'],
    appearance:
        '深色头发编成辫子垂在肩侧，说话轻声细语，但在走廊上看到不公平的事会立刻走过去。',
    era: 'first_war',
    personalGoal: '在分裂的校园里维持一点体面',
  ),

  // ===== 成人：傲罗 / 食死徒 / 灰色地带 =====
  NpcSeed(
    id: 'moody_young',
    name: '阿拉斯托·穆迪',
    gender: '男',
    aliases: ['疯眼汉穆迪', '穆迪', '阿拉斯托穆迪'],
    house: '',
    grade: 0,
    bloodStatus: 'halfblood',
    personality: ['警惕', '强硬', '正直', '多疑'],
    appearance:
        '三十来岁的傲罗，身材精悍。左眼还是好的，但脸上一道新鲜的伤疤。'
        '说话时总在扫视出口，握手前会先看对方的手。',
    era: 'first_war',
    personalGoal: '在黑魔王得手前多抓几个人',
  ),
  NpcSeed(
    id: 'lucius',
    name: '卢修斯·马尔福',
    gender: '男',
    aliases: ['卢修斯马尔福', '马尔福先生'],
    house: '',
    grade: 0,
    bloodStatus: 'pureblood',
    personality: ['傲慢', '精明', '野心', '圆滑'],
    appearance:
        '一头铂金色长发垂到肩头，手杖顶端是银质蛇首。'
        '语调永远温和有礼，礼貌底下是毫不掩饰的优越感。',
    era: 'first_war',
    personalGoal: '让马尔福家族站到胜利者那一边',
  ),
  NpcSeed(
    id: 'bellatrix',
    name: '贝拉特里克斯·布莱克',
    gender: '女',
    aliases: ['贝拉', '贝拉特里克斯布莱克', '贝拉特里克斯'],
    house: '',
    grade: 0,
    bloodStatus: 'pureblood',
    personality: ['狂热', '傲慢', '残忍', '美貌'],
    appearance:
        '浓密的黑色长卷发，眼窝深陷，五官张扬而凌厉。'
        '笑的时候像在享受什么只有自己知道的事。',
    era: 'first_war',
    personalGoal: '把自己献给那个她认为值得献祭的人',
  ),
  NpcSeed(
    id: 'aberforth',
    name: '阿不福思·邓布利多',
    gender: '男',
    aliases: ['阿不福思邓布利多', '阿不福思', '猪头老板'],
    house: '',
    grade: 0,
    bloodStatus: 'halfblood',
    personality: ['古怪', '直率', '内敛', '固执'],
    appearance:
        '和哥哥一样留着长须，但胡须凌乱、衣着随意。'
        '在猪头酒吧擦杯子的时候，不太愿意被人认出自己姓什么。',
    era: 'first_war',
    personalGoal: '守着这家酒吧，不掺和任何大事',
  ),
];

/// 全部 NPC 种子（按 id 去重）。
///
/// 剧情渲染器（lib/utils/story_text_renderer.dart）靠这份表决定「哪些词该当
/// 角色名处理」。以前它在自己文件里手抄了一份名单，抄的是哈利时代那批熟
/// 面孔，于是第一次巫师战争时代的 12 个原创 NPC 一个都不在里面：
///  - 剧情里没有一个角色名被染色；
///  - 「马琳：+3」这种好感行识别不出来，因为渲染器那句好感正则是拿名单拼的；
///  - 说话人判定也认不出他们，台词不上色。
/// 现在从数据层派生，以后往任何一个时代加 NPC，渲染自动跟上。
///
/// firstWarSeeds 是 maraudersSeeds 改年级后的副本（id 相同），不必重复收。
final List<NpcSeed> kAllNpcSeeds = _dedupById([
  ...staffSeeds,
  ...harrySameGryffindor,
  ...harrySameSenior,
  ...harrySameSlytherin,
  ...harrySameRavenclaw,
  ...harrySameHufflepuff,
  ...maraudersSeeds,
  ...dumbledoreEraSeeds,
  ...postWarSeeds,
  ...firstWarOriginals,
]);

List<NpcSeed> _dedupById(List<NpcSeed> src) {
  final seen = <String>{};
  final out = <NpcSeed>[];
  for (final s in src) {
    if (seen.add(s.id)) out.add(s);
  }
  return out;
}

/// 从 staffSeeds 中按 ID 挑选职员（各时代教职阵容不同，避免跨时代错乱）
List<NpcSeed> _pickStaff(Set<String> ids) =>
    [for (final s in staffSeeds) if (ids.contains(s.id)) s];

/// 1892 邓布利多时代职员：只有幽灵宾斯教授
/// （邓布利多/麦格由 dumbledoreEraSeeds 提供学生版，其余教职角色此时尚未出生）
final List<NpcSeed> dumbledoreStaff = _pickStaff({'binns'});

/// 1971 掠夺者时代职员：不含 1971 年还是学生的弗立维/特里劳妮，
/// 少年斯内普由 maraudersSeeds 提供（snape_young）。
final List<NpcSeed> maraudersStaff = _pickStaff({
  'dumbledore', 'mcgonagall', 'hagrid', 'sprout', 'hooch',
  'pince', 'pomfrey', 'binns', 'filch',
});

/// 2020 后战争时代职员：邓布利多（1997 逝）、斯内普（1998 逝）不再登场，
/// 由麦格接任校长。
final List<NpcSeed> postWarStaff = _pickStaff({
  'mcgonagall', 'hagrid', 'flitwick', 'sprout', 'hooch', 'trelawney',
  'pince', 'pomfrey', 'binns', 'filch',
});

/// 各时代 NPC 种子（按 Era 过滤）
final Map<String, List<NpcSeed>> eraNpcSeeds = {
  'dumbledore': [
    ...dumbledoreStaff,
    ...dumbledoreEraSeeds,
  ],
  'marauders': [
    ...maraudersStaff,
    ...maraudersSeeds,
  ],
  'first_war': [
    ...maraudersStaff,
    ...firstWarSeeds,
    ...firstWarOriginals,
  ],
  'harry_same': [
    ...staffSeeds,
    ...harrySameGryffindor,
    ...harrySameSenior,
    ...harrySameSlytherin,
    ...harrySameRavenclaw,
    ...harrySameHufflepuff,
  ],
  'post_war': [
    ...postWarStaff,
    ...postWarSeeds,
  ],
  'random': [
    ...staffSeeds,
    ...harrySameGryffindor,
    ...harrySameSlytherin,
    ...harrySameRavenclaw,
    ...harrySameHufflepuff,
  ],
};
