/// 月度事件池（R6：数据化，替代 _generateMonthlyEvent 硬编码 Map + 手写拼接）
///
/// 支持：
///   - weight：事件抽取权重（越大越容易抽到）
///   - seasonTags：季节标签（spring/summer/autumn/winter）；空表示四季通用
///   - mutuallyExclusiveIds：互斥事件 id 列表。抽中 A 之后，
///     [kMutuallyExclusiveMonths] 个月内不再抽 B/C（双向生效）。
///   - baseChance：基础参与概率（0.0~1.0），类似旧代码里 dark=0.3 / creature=0.4
class MonthlyEventDef {
  final String id;
  final String category; // ministry / hogwarts / economy / dark / creature / season
  final String text;
  final int weight;
  final List<String> seasonTags; // spring(3-5) summer(6-8) autumn(9-11) winter(12-2)

  /// 互斥事件 id。抽中本条之后 [kMutuallyExclusiveMonths] 个月内，
  /// 列表里的事件不再参与抽取（反向同理：本条也会因为它们的发生被跳过）。
  final List<String> mutuallyExclusiveIds;

  /// 同一条事件在多少个月内不重复出现。
  static const int repeatCooldownMonths = 12;

  final double baseChance;

  const MonthlyEventDef({
    required this.id,
    required this.category,
    required this.text,
    this.weight = 1,
    this.seasonTags = const [],
    this.mutuallyExclusiveIds = const [],
    this.baseChance = 1.0,
  });
}

/// 互斥关系生效的窗口（月）。
const int kMutuallyExclusiveMonths = 6;

const List<MonthlyEventDef> monthlyEventPool = [
  // ====== ministry（魔法部新闻）======
  MonthlyEventDef(
    id: 'mini_reform',
    category: 'ministry',
    text: '魔法部宣布了新一轮的魔法教育改革方案，涉及到所有魔法学校的课程调整。',
    // 和「黑魔法防御术专项检查」是同一件事的两种说法，连着两个月播会很假
    mutuallyExclusiveIds: ['mini_dada_check'],
  ),
  MonthlyEventDef(
    id: 'mini_dada_check',
    category: 'ministry',
    text: '魔法部对黑魔法防御术进行了专项检查，霍格沃茨的师资队伍通过了严格审核。',
    mutuallyExclusiveIds: ['mini_reform'],
  ),
  MonthlyEventDef(
    id: 'mini_forbidden',
    category: 'ministry',
    text: '魔法部发布了新的禁咒名单，三种黑魔法被列入最高级别管制。',
  ),
  MonthlyEventDef(
    id: 'mini_goblin',
    category: 'ministry',
    text: '魔法部与妖精家族达成了新的古灵阁运营协议，加强了对魔法经济的监管。',
  ),

  // ====== hogwarts（校内琐事）======
  MonthlyEventDef(
    id: 'hw_quidditch',
    category: 'hogwarts',
    text: '霍格沃茨宣布了本学期的魁地奇比赛安排，各院队长已经开始紧张训练。',
    seasonTags: ['autumn', 'spring'],
  ),
  MonthlyEventDef(
    id: 'hw_donation',
    category: 'hogwarts',
    text: '霍格沃茨图书馆收到了一批珍贵的古籍捐赠，其中包括几本失传已久的魔法著作。',
    mutuallyExclusiveIds: ['hw_decor'],
  ),
  MonthlyEventDef(
    id: 'hw_ghosts',
    category: 'hogwarts',
    text: '霍格沃茨的幽灵们最近异常活跃，据说地下室里传来了奇怪的声响。',
  ),
  MonthlyEventDef(
    id: 'hw_decor',
    category: 'hogwarts',
    text: '霍格沃茨大礼堂进行了季节性装饰，墙壁上挂满了与当前月份相关的魔法旗帜。',
    mutuallyExclusiveIds: ['hw_donation'],
  ),

  // ====== economy（经济 / 市场）======
  MonthlyEventDef(
    id: 'eco_galleon',
    category: 'economy',
    text: '古灵阁的金币汇率本月波动较大，加隆对英镑的比值创下了近年来的新高。',
    // 和「药水涨价」都是"数字又变了"，连着听两次会觉得世界在复读
    mutuallyExclusiveIds: ['eco_potion_shortage'],
  ),
  MonthlyEventDef(
    id: 'eco_potion_shortage',
    category: 'economy',
    text: '魔法药品市场供应紧张，几种常用药水的价格上涨了约15%。',
    mutuallyExclusiveIds: ['eco_galleon'],
  ),
  MonthlyEventDef(
    id: 'eco_fair',
    category: 'economy',
    text: '魔法物品交易会在对角巷举行，吸引了来自全国各地的巫师商人。',
  ),
  MonthlyEventDef(
    id: 'eco_owl_delay',
    category: 'economy',
    text: '由于天气原因，猫头鹰邮递的效率有所下降，信件送达时间延迟了1-2天。',
  ),

  // ====== dark（黑魔法动向，低概率）======
  MonthlyEventDef(
    id: 'dark_auror_border',
    category: 'dark',
    text: '黑巫师的活动在欧洲大陆有所增加，魔法部派遣了更多的傲罗前往边境地区。',
    weight: 2,
    baseChance: 0.3,
    mutuallyExclusiveIds: ['dark_castle'],
  ),
  MonthlyEventDef(
    id: 'dark_castle',
    category: 'dark',
    text: '一座废弃的城堡被黑巫师占据，魔法界对此高度关注。',
    baseChance: 0.3,
    mutuallyExclusiveIds: ['dark_patrol', 'dark_auror_border'],
  ),
  MonthlyEventDef(
    id: 'dark_patrol',
    category: 'dark',
    text: '有关黑魔法社团的传闻在学生中流传，霍格沃茨加强了夜间巡逻。',
    baseChance: 0.3,
    mutuallyExclusiveIds: ['dark_castle'],
  ),
  MonthlyEventDef(
    id: 'dark_seized',
    category: 'dark',
    text: '魔法部截获了一批非法交易的魔法生物，其中包括几只受保护的独角兽幼崽。',
    baseChance: 0.3,
  ),

  // ====== creature（神奇生物新闻，中低概率）======
  MonthlyEventDef(
    id: 'cr_unicorn',
    category: 'creature',
    text: '禁林中的独角兽族群迁徙了新的领地，生物学家对此进行了密切观察。',
    seasonTags: ['spring', 'autumn'],
    baseChance: 0.4,
    // 「又有稀有生物出现了」连着来两次就不稀有了
    mutuallyExclusiveIds: ['cr_phoenix', 'cr_dragon'],
  ),
  MonthlyEventDef(
    id: 'cr_phoenix',
    category: 'creature',
    text: '一只罕见的凤凰在霍格沃茨上空出现了数天，引发了学生们的热烈讨论。',
    baseChance: 0.4,
    mutuallyExclusiveIds: ['cr_unicorn', 'cr_dragon'],
  ),
  MonthlyEventDef(
    id: 'cr_spew',
    category: 'creature',
    text: '家养小精灵权益促进会（S.P.E.W.）发起了新一轮的签名请愿活动。',
    baseChance: 0.4,
  ),
  MonthlyEventDef(
    id: 'cr_dragon',
    category: 'creature',
    text: '挪威脊背龙的幼崽在冰岛被发现，生物学家正在研究它的生活习性。',
    baseChance: 0.4,
    mutuallyExclusiveIds: ['cr_unicorn', 'cr_phoenix'],
  ),

  // ====== 季节专属 ======
  MonthlyEventDef(
    id: 'se_summer_hogsmeade',
    category: 'season',
    text: '六月的午后热浪升腾，霍格莫德村的黄油啤酒冰杯销量创下历史新高。',
    seasonTags: ['summer'],
    weight: 3,
  ),
  MonthlyEventDef(
    id: 'se_autumn_pumpkin',
    category: 'season',
    text: '海格的巨型南瓜丰收了，据说今年最大的一颗需要三个三年级生才能搬动。',
    seasonTags: ['autumn'],
    weight: 3,
  ),
  MonthlyEventDef(
    id: 'se_winter_snow',
    category: 'season',
    text: '苏格兰高地降下了今年第一场雪，城堡的塔楼披上了一层厚厚的银装。',
    seasonTags: ['winter'],
    weight: 3,
  ),
  MonthlyEventDef(
    id: 'se_spring_flower',
    category: 'season',
    text: '禁林边缘的银柳抽出了新芽，草药课上教授提到这是制作舒缓药水的珍贵原料。',
    seasonTags: ['spring'],
    weight: 3,
  ),

  // ====== 学年特异性事件（带学年标记）======
  MonthlyEventDef(
    id: 'yr1_first_letter',
    category: 'year',
    text: '一年级的走廊里，一个新生的猫头鹰撞翻了皮皮鬼的恶作剧——'
        '你收到了一封来自家里的信，墨水有些晕开了，像被什么打湿过。',
    seasonTags: ['autumn'],
    weight: 1,
  ),
  MonthlyEventDef(
    id: 'yr1_sorting_anniversary',
    category: 'year',
    text: '入学整整一个月了。你发现自己的学院公共休息室里，'
        '高年级生们正在用一种"你还太嫩"的眼神打量你——'
        '而你也开始用"你还没习惯呢"的眼神回敬一年级新生。',
    seasonTags: ['autumn'],
    weight: 1,
  ),
  MonthlyEventDef(
    id: 'yr2_trouble',
    category: 'year',
    text: '城堡里流传着一种奇怪的传闻：有人被石化了。'
        '走廊里巡逻的费尔奇比平时多了一倍，'
        '而画像们在窃窃私语，你一靠近就不说了。',
    seasonTags: ['autumn', 'winter'],
    weight: 1,
  ),
  MonthlyEventDef(
    id: 'yr3_sirius_escape',
    category: 'year',
    text: '《预言家日报》的头版上印着一张通缉令：'
        '小天狼星·布莱克越狱了。吃早饭的时候，礼堂里的议论声盖过了猫头鹰的翅膀声。',
    seasonTags: ['autumn'],
    weight: 1,
  ),
  MonthlyEventDef(
    id: 'yr4_triwizard',
    category: 'year',
    text: '布斯巴顿和德姆斯特朗的代表团就要到了。'
        '城堡里弥漫着一种混合了兴奋和紧张的气氛，'
        '就连平时最严肃的教授眉间也多了一丝期待。',
    seasonTags: ['autumn'],
    weight: 1,
  ),
  MonthlyEventDef(
    id: 'yr5_owls',
    category: 'year',
    text: 'O.W.Ls 考试的压力笼罩着整个五年级。'
        '图书馆里，五年级学生的桌上堆满了参考书，'
        '而低年级生路过时走路都放轻了脚步——不想被瞪。',
    seasonTags: ['spring'],
    weight: 1,
  ),
  MonthlyEventDef(
    id: 'yr6_quidditch_captain',
    category: 'year',
    text: '新学期的魁地奇队长选拔开始了。'
        '六年级的球员们比往年更卖力地训练，'
        '因为大家都知道——这可能是最后一次以学生身份上场的机会了。',
    seasonTags: ['autumn'],
    weight: 1,
  ),
  MonthlyEventDef(
    id: 'yr7_last_year',
    category: 'year',
    text: '七年级的第一天，你发现城堡看起来和往年没什么不同——'
        '但你知道，这是最后一次用"回学校"来形容这个秋天了。'
        'N.E.W.Ts 的课表比想象中更满，而走廊尽头的画像里，'
        '一位老校长似乎对你笑了笑。',
    seasonTags: ['autumn'],
    weight: 1,
  ),
];

// ==================== 月度气氛 ====================
//
// 上面那个池子是「这个月发生了一件什么事」——新闻。
// 新闻是有成本的：会冷却、会互斥、抽完一轮就没了，
// 于是大部分月份其实是空的，只有那一条随机事件撑着。
//
// 下面是另一回事：**这个月城堡里是什么味儿。**
// 不抽取、不冷却、不互斥，每个月都有一句，每回合都注入。
//
// 新闻是"世界发生了什么"，气氛是"你站在里面是什么感觉"。
// 前者可以偶尔缺席，后者不能——没有底色的月份，
// AI 写出来的就只是一段没有季节的场景。

// ==================== 学年专属事件池 ====================
///
/// 每学年都有 5+ 条专属事件，学年结束后移入"历史事件池"（不再复用）。
/// 加上通用事件池（30+ 条），确保"第三学年的 9 月 ≠ 第一学年的 9 月"。

class SchoolYearEventDef {
  final String id;
  final int schoolYear; // 适用学年（1~7）
  final String text;
  final double baseChance;

  const SchoolYearEventDef({
    required this.id,
    required this.schoolYear,
    required this.text,
    this.baseChance = 1.0,
  });
}

const List<SchoolYearEventDef> schoolYearEventPool = [
  // ====== 第一学年 ======
  SchoolYearEventDef(
    id: 'sy1_sorting',
    schoolYear: 1,
    text: '分院帽在高年级的歌声中完成了今年的分院仪式——新生的面孔在烛光下一张张亮起来，礼堂里响起各院的掌声。',
  ),
  SchoolYearEventDef(
    id: 'sy1_first_lesson',
    schoolYear: 1,
    text: '第一堂变形课，麦格教授变成一只猫跳上讲台的时候，有个新生差点从椅子上摔下去。',
  ),
  SchoolYearEventDef(
    id: 'sy1_letter_home',
    schoolYear: 1,
    text: '开学第一周，猫头鹰们带着家信从大礼堂的窗户涌进来——不少人第一次在公开场合没忍住眼泪。',
  ),
  SchoolYearEventDef(
    id: 'sy1_halloween',
    schoolYear: 1,
    text: '万圣节的礼堂被真正的蝙蝠和南瓜灯塞得满满当当，漂浮的蜡烛在雾气里飘成了淡黄色的星带。',
  ),
  SchoolYearEventDef(
    id: 'sy1_exam_scare',
    schoolYear: 1,
    text: '期末临近，一年级的学生第一次体会到"被考试追着跑"的滋味——图书馆里有人在凌晨三点抱着魔药课本睡着了。',
  ),

  // ====== 第二学年 ======
  SchoolYearEventDef(
    id: 'sy2_back',
    schoolYear: 2,
    text: '第二年返校时，走廊里少了几张熟悉的面孔，多了一群举着魔杖到处乱指的新生——你忽然意识到自己已经不是最小的了。',
  ),
  SchoolYearEventDef(
    id: 'sy2_club_fair',
    schoolYear: 2,
    text: '今年的社团招新出乎意料地热闹，决斗俱乐部和魔药兴趣小组在走廊上互相抢人，差点打起来。',
  ),
  SchoolYearEventDef(
    id: 'sy2_detention',
    schoolYear: 2,
    text: '费尔奇先生和他的猫似乎比去年更记仇了——禁闭名单上多了几个熟悉的名字。',
  ),
  SchoolYearEventDef(
    id: 'sy2_midnight',
    schoolYear: 2,
    text: '深夜的城堡走廊永远不缺故事——有人穿着隐身斗篷溜出去，有人在楼梯间撞见皮皮鬼，还有人在天文塔上看到了不该看到的东西。',
  ),

  // ====== 第三学年 ======
  SchoolYearEventDef(
    id: 'sy3_elective',
    schoolYear: 3,
    text: '三年级选修课清单公布的那天，走廊上挤满了讨论"选什么课才不会后悔"的学生——所有人的答案都不一样。',
  ),
  SchoolYearEventDef(
    id: 'sy3_hogsmeade',
    schoolYear: 3,
    text: '三年级的霍格莫德日——第一杯黄油啤酒下肚的时候，你终于觉得"长大了"这件事不只是说说而已。',
  ),
  SchoolYearEventDef(
    id: 'sy3_detective',
    schoolYear: 3,
    text: '城堡里最近流传着一个关于密室的传闻，大多数学生把它当玩笑，但赫敏的眉头已经皱了一整个星期了。',
  ),

  // ====== 第四学年 ======
  SchoolYearEventDef(
    id: 'sy4_triwizard',
    schoolYear: 4,
    text: '火焰杯的蓝色火焰在礼堂中央燃烧的那个晚上，整个学校都屏住了呼吸——谁也不知道它会吐出谁的名字。',
  ),
  SchoolYearEventDef(
    id: 'sy4_ball',
    schoolYear: 4,
    text: '圣诞舞会的消息让整个学校沸腾了两个星期——礼服、舞伴、和那些"你愿意和我一起去吗"的紧张时刻。',
  ),
  SchoolYearEventDef(
    id: 'sy4_task',
    schoolYear: 4,
    text: '三强争霸赛的第一项任务结束了，城堡里所有人都在谈论那条龙。',
  ),

  // ====== 第五学年 ======
  SchoolYearEventDef(
    id: 'sy5_owl',
    schoolYear: 5,
    text: 'O.W.L.s 的倒计时牌挂在公共休息室的那天起，气氛就变了——有人开始疯狂刷题，有人开始放弃治疗，麦格教授的视线比任何时候都更锋利。',
  ),
  SchoolYearEventDef(
    id: 'sy5_umbridge',
    schoolYear: 5,
    text: '魔法部的新任调查官开始在走廊上出没，她的粉色开衫和甜腻的声音让所有人都觉得后背发凉。',
  ),
  SchoolYearEventDef(
    id: 'sy5_dumbledore_army',
    schoolYear: 5,
    text: '一件关于"秘密集会"的传闻在暗处流传——愿意参加的人，在午夜带着魔杖到有求必应屋门口等着。',
  ),

  // ====== 第六学年 ======
  SchoolYearEventDef(
    id: 'sy6_newt',
    schoolYear: 6,
    text: 'N.E.W.T. 级别的课程让所有人重新认识了"作业"这个词的定义——图书馆的闭馆时间从九点延到了十一点。',
  ),
  SchoolYearEventDef(
    id: 'sy6_slughorn',
    schoolYear: 6,
    text: '斯拉格霍恩教授的晚宴请柬从各个方向飞向那些"有前途"的学生——被邀请的人不一定想去，但没被邀请的人更难受。',
  ),
  SchoolYearEventDef(
    id: 'sy6_apparition',
    schoolYear: 6,
    text: '幻影显形课程的通知贴出来的时候，一半人兴奋得睡不着，另一半人已经写好了遗嘱。',
  ),

  // ====== 第七学年 ======
  SchoolYearEventDef(
    id: 'sy7_last_first',
    schoolYear: 7,
    text: '最后一学年的开学晚宴上，你看着天花板上的蜡烛，忽然意识到——这是最后一次了。',
  ),
  SchoolYearEventDef(
    id: 'sy7_career_advice',
    schoolYear: 7,
    text: '就业指导谈话的安排表贴在了公共休息室门口——每个人都有不同的未来，但走廊上的脚步声变得比往年更沉了。',
  ),
  SchoolYearEventDef(
    id: 'sy7_farewell',
    schoolYear: 7,
    text: '离校前的最后一天，有人在黑湖边的树下埋了一样东西，有人在塔楼的墙上刻了一个名字，还有人什么都没做——只是站着，把每个角落都看了一遍。',
  ),
];

/// 根据学年号获取该学年专属事件文本
String? schoolYearEventText(int schoolYear, {int seed = 0}) {
  final pool = schoolYearEventPool
      .where((e) => e.schoolYear == schoolYear)
      .toList();
  if (pool.isEmpty) return null;
  final index = seed % pool.length;
  return pool[index].text;
}

/// 12 个月的气氛。key 为月份（1-12）。
///
/// 写法上的规矩：只写**跟年份无关**的东西。
/// 不写"1991 年的秋天"、不写任何具体事件、不提任何人——
/// 这样五个时代都能用，也不会跟事件锚点打架。
const Map<int, String> kMonthlyAtmosphere = {
  1: '一月是这座城堡最冷的时候。石阶上结着一层薄冰，走廊里的火把烧得比平时旺，'
      '而大多数学生把被子裹成了茧，只在吃饭的时候才从里面爬出来。',
  2: '二月的穿堂风是认真的——它从城堡的每一条缝里钻进来，'
      '专门吹那些刚从火炉边离开、还以为自己暖和的人。',
  3: '三月开始融雪。黑湖边的冰一层一层退下去，'
      '禁林边缘的泥地踩下去会陷半个鞋跟，靴子拔出来的时候有声音。',
  4: '四月下雨。不是那种痛快的雨，是连着下三四天、'
      '把所有人的袍子都弄得潮乎乎、怎么烘都烘不干的那种。',
  5: '五月是考试的味道。图书馆从早到晚满着，'
      '有人开始把笔记抄在手背上，也有人已经放弃了，'
      '只是还坐在那儿——因为不坐在那儿会更难受。',
  6: '六月的天黑得很晚。草地上有人在熬夜，有人在等成绩，'
      '也有人只是不想回宿舍，说不上来在等什么。',
  7: '七月城堡空了。走廊长到能听见自己的脚步声，'
      '连画像里的人也懒得说话，你走过的时候他们只是看着。',
  8: '八月是最热的那几天，也是最长的一段无聊：'
      '离开学还有两周，而对角巷早就逛腻了，猫头鹰也不来。',
  9: '九月潮湿。站台上的蒸汽、新生的靴子、'
      '还有那种"又要开始了吗"的复杂心情——'
      '说不清是想来，还是不想。',
  10: '十月开始有雾。早上推开窗，城堡的下半截是看不见的，'
      '只有几个塔尖浮在白色的上面，像浮在水里。',
  11: '十一月风大。湖边的树基本秃了，'
      '魁地奇球场上飞着的不只有球，还有落叶和没关好的斗篷。',
  12: '十二月飘雪。窗玻璃内侧结着一层水汽，'
      '用手指划一道就能看见外面——很多人小时候都这么干过，'
      '现在假装不记得了。',
};

/// 取 [month] 月的气氛文案；月份越界时给空串（宁可不说，不要乱说）。
String atmosphereForMonth(int month) => kMonthlyAtmosphere[month] ?? '';

/// 月份转季节标签（spring/summer/autumn/winter）
List<String> seasonTagsForMonth(int month) {
  if (month >= 3 && month <= 5) return const ['spring'];
  if (month >= 6 && month <= 8) return const ['summer'];
  if (month >= 9 && month <= 11) return const ['autumn'];
  return const ['winter'];
}
