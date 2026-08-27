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
  NpcSeed(
    id: 'young_mcgonagall',
    name: '米勒娃·麦格',
    gender: '女',
    aliases: ['少女麦格'],
    house: 'Gryffindor',
    grade: 1,
    bloodStatus: 'halfblood',
    personality: ['优秀', '严肃', '坚定'],
    appearance: '少女时代的米勒娃·麦格，黑发，面容聪慧而严肃。',
    era: 'dumbledore',
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
