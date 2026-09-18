/// P9 霍格沃茨年度节庆库：万圣节 / 圣诞夜 / 元旦 / 情人节 / 春季寻宝 / 学年舞会。
///
/// 【为什么单独成文件】离线版的「世界在动」此前只靠月度事件 + 原著时间线支撑，
/// 它们各自有固定触发窗口，玩家感受不到「今天是个特别的日子」。节庆是一套
/// 按**日期**触发、**每学年只庆祝一次**的固定日历事件：10月31 就该有万圣节，
/// 12月24 就该有圣诞夜。数据全收口在这里，mixin 只做「匹配日期 + 选庆祝方式」
/// 两层事，新增节日只改这一份文件，不碰玩法逻辑。
library;

// ==================== 节庆效果 ====================

/// 一场节庆庆祝带来的结算效果（全部可选，0 表示不结算该项）。
class FestivalEffectDef {
  final String? reputationDim; // academic/social/combat/moral/leadership/dark
  final int reputationValue;
  final int housePoints;
  final int galleons;
  final int energy;
  final String? npcId; // 好感加成对象
  final int npcAffection;
  final String? itemName; // 奖励物品（需在 item_data 有定义）
  const FestivalEffectDef({
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

/// 一种庆祝方式的结果：标题 + 叙事 + 结算。
class FestivalOutcomeDef {
  final String title;
  final String text; // 可带 `$house` 占位符
  final FestivalEffectDef effect;
  const FestivalOutcomeDef({
    required this.title,
    required this.text,
    required this.effect,
  });
}

/// 一个年度节日。触发条件：日期命中 [month]/[day]（合并为一个 int，见 [dateKey]）
/// 且本学年尚未庆祝过。
class FestivalDef {
  final String id;
  final String name;
  final String dateLabel; // 展示用，如「10月31日」
  final int month;
  final int day;
  final String intro; // 触发时的总起叙事
  final List<FestivalOutcomeDef> outcomes;
  const FestivalDef({
    required this.id,
    required this.name,
    required this.dateLabel,
    required this.month,
    required this.day,
    required this.intro,
    required this.outcomes,
  });

  /// 统一日期键，便于匹配与测试：`month * 100 + day`（如 10月31 → 1031）。
  int get dateKey => month * 100 + day;
}

const List<FestivalDef> kFestivals = [
  FestivalDef(
    id: 'halloween',
    name: '万圣节之夜',
    dateLabel: '10月31日',
    month: 10,
    day: 31,
    intro:
        '城堡上下飘满了自行雕刻的南瓜灯，礼堂里悬着无数只扑扇着翅膀的蝙蝠，'
        '幽灵们难得从云雾里探出来笑。费尔奇照旧一整晚板着脸，'
        r'可连他兜里都别着一颗发光的小南瓜。今晚的 $house，到处都弥漫着甜滋滋的焦糖香。',
    outcomes: [
      FestivalOutcomeDef(
        title: '南瓜雕刻比赛',
        text:
            '你报名参加了南瓜雕刻比赛。刀在橘红色的南瓜皮上游走，'
            '你雕出一只歪嘴笑着的灯——虽算不上最美，却让路过的人都忍不住盯着看。'
            '评委赏给你几枚加隆，你的社交声望也悄悄涨了一点。',
        effect: FestivalEffectDef(
            reputationDim: 'social', reputationValue: 4, galleons: 8, energy: 6),
      ),
      FestivalOutcomeDef(
        title: '听幽灵们讲故事',
        text:
            '你跟着皮皮鬼绕到一间废弃教室，听几个幽灵讲起百年前霍格沃茨的往事。'
            '它们难得安静下来。临走时，胖修士朝你点点头：「年轻人，今晚适合做点勇敢的事。」'
            '你的道德声望因这份深夜的倾听而微涨。',
        effect: FestivalEffectDef(
            reputationDim: 'moral', reputationValue: 4, energy: 4),
      ),
      FestivalOutcomeDef(
        title: '分享给孤独的人',
        text:
            '你端着一盘南瓜馅饼找到那个总是一个人坐在角落的一年级新生，'
            '分了一半给他。他怔了一下，眼睛亮起来。'
            r'这个万圣节，$house 少了一个孤单的人。',
        effect: FestivalEffectDef(
            reputationDim: 'moral',
            reputationValue: 3,
            housePoints: 6,
            npcAffection: 3),
      ),
    ],
  ),
  FestivalDef(
    id: 'christmas',
    name: '圣诞之夜',
    dateLabel: '12月24日',
    month: 12,
    day: 24,
    intro:
        '大雪在窗外交织成一片白幕。大礼堂被数百支蜡烛与十二棵圣诞树映得金碧辉煌，'
        '树上挂满摇摇晃晃的银色雪橇与金色星星。邓布利多朝你举了举高脚杯，'
        r'杯中的黄油啤酒泛起暖融融的光。这是 $house 一年里最温柔的夜晚。',
    outcomes: [
      FestivalOutcomeDef(
        title: '交换礼物',
        text:
            '你参与了圣诞夜的心意交换。拆开包装的一瞬，蓝盈盈的彩光溢了出来——'
            '是一枚保温油纸包着的坩埚蛋糕。你把写着祝福的卡片悄悄塞进那只更简陋的礼物盒，'
            '递给角落里的那个同学。圣诞的意义，本就在送出的一刻完成。',
        effect: FestivalEffectDef(
            reputationDim: 'social', reputationValue: 5, galleons: 10, energy: 5),
      ),
      FestivalOutcomeDef(
        title: '留在礼堂听唱诗合唱',
        text:
            '你搬了张长凳坐到壁炉边，听校合唱队唱起那首百年的圣诞颂歌。'
            '火光照在每个人脸上，连平时最吵闹的皮皮鬼都安静了下来。'
            '曲终，费伦泽的声音从门外飘进来：「夜晚自有它的星象，小子。」'
            '你的领导声望因这份定力而小涨。',
        effect: FestivalEffectDef(reputationDim: 'leadership', reputationValue: 4),
      ),
      FestivalOutcomeDef(
        title: '给海格帮忙布置圣诞树',
        text:
            '你跑去海格的小屋，帮他一起往那棵巨大的云杉上挂铃铛和镀金胡桃。'
            '海格咧着嘴笑，硬往你怀里塞了一大块滋滋蜜蜂糖。'
            '他说这棵树的星星挂饰，是他年轻时的第一条龙送的。',
        effect: FestivalEffectDef(
            reputationDim: 'social',
            reputationValue: 3,
            housePoints: 8,
            npcId: 'hagrid',
            npcAffection: 4,
            energy: 5),
      ),
    ],
  ),
  FestivalDef(
    id: 'newyear',
    name: '元旦钟声',
    dateLabel: '1月1日',
    month: 1,
    day: 1,
    intro:
        '零点的钟声在寒夜里层层荡开。公共休息室的壁炉烧得正旺，'
        '同学们挤在一起倒数，窗外的烟花在雪地上绽开成大大的一方金色华盖。'
        '你搓了搓手，在指尖呼出一小团白雾——新的一年，到来了。',
    outcomes: [
      FestivalOutcomeDef(
        title: '写下新年愿望',
        text:
            '你在羊皮纸上郑重写下明年的愿望，折好，锁进床头那只旧木匣。'
            '有些愿望适合大声说，有些适合一个人悄悄守着。'
            '写下的一刻，你觉得自己对这一年又多了一分笃定。',
        effect: FestivalEffectDef(
            reputationDim: 'academic',
            reputationValue: 3,
            galleons: 5,
            energy: 8),
      ),
      FestivalOutcomeDef(
        title: '和大家一起守夜',
        text:
            '你陪着一屋子人守到天边泛白。有人弹起六弦琴，有人跟着哼，'
            '连打瞌睡的你都被拉进圈里跳了两步笨拙的舞。'
            r'这一晚没有课业，只有 $house 聚在一起的心跳声。',
        effect: FestivalEffectDef(
            reputationDim: 'social', reputationValue: 5, housePoints: 4, energy: 10),
      ),
    ],
  ),
  FestivalDef(
    id: 'valentine',
    name: '情人节黄油啤酒',
    dateLabel: '2月14日',
    month: 2,
    day: 14,
    intro:
        '今天的三把扫帚酒吧比往常暖融融。猫头鹰衔着一封封粉色的信在餐厅上空盘旋，'
        '有人脸红，有人捂嘴偷笑。就连费尔奇也收到了一盒神秘的巧克力——'
        '虽然他知道是谁送的以后，把那盒糖锁进了抽屉最深处。',
    outcomes: [
      FestivalOutcomeDef(
        title: '匿名地表达一点心意',
        text:
            '你在那封没有署名的信上，用左手写下一行工整的字，塞进喜欢的那个人的收信格里。'
            '你没打算得到回应，只是想让今天有个温柔的开始。'
            '做这件事需要一点勇气——而勇气，总不会白费。',
        effect: FestivalEffectDef(
            reputationDim: 'moral',
            reputationValue: 4,
            npcAffection: 3,
            energy: 3),
      ),
      FestivalOutcomeDef(
        title: '陪单身的朋友逛街',
        text:
            '你拉着那个嘴上逞强、眼里却有点落寞的朋友去逛蜂蜜公爵，'
            '把最贵的那盒「吹宝超级泡泡糖」塞给他。他不会说谢谢，'
            '但后来他把袋子里的糖分给了你一半。',
        effect: FestivalEffectDef(
            reputationDim: 'social', reputationValue: 5, housePoints: 5),
      ),
    ],
  ),
  FestivalDef(
    id: 'spring_hunt',
    name: '春季彩蛋大寻宝',
    dateLabel: '4月6日',
    month: 4,
    day: 6,
    intro:
        '海格藏了整整一筐彩蛋在城堡与场地的各个角落——钥匙孔里、书架夹层、'
        '温室的龙粪堆（他说那是最保险的地方）。奖励不是糖：'
        '是一张通往禁林边缘的路线图，和一份能让魔药课教授点头的特权。',
    outcomes: [
      FestivalOutcomeDef(
        title: '带路找到藏得最深的彩蛋',
        text:
            '你凭着对城堡楼梯的熟悉，在第几级会动的楼梯上找到了那颗夹在雕花里的银蛋。'
            '海格拍着你的背哈哈大笑，说这份眼力能当半个猎场看守了。'
            '你从蛋里取出一袋加隆和一张泛黄的禁林路线图。',
        effect: FestivalEffectDef(
            reputationDim: 'social',
            reputationValue: 4,
            galleons: 12,
            itemName: '夜骐尾羽',
            energy: 8),
      ),
      FestivalOutcomeDef(
        title: '把找到的彩蛋分给一年级的孩子们',
        text:
            '你把那颗鼓鼓囊囊的彩蛋打开，把里面的糖分给一群眼睛亮晶晶的一年级小巫师。'
            '他们围着你欢呼，有个小姑娘塞给你一张自己画的、歪歪扭扭的感谢卡。'
            '海格在远处看见了，朝你竖了竖大拇指。',
        effect: FestivalEffectDef(
            reputationDim: 'moral', reputationValue: 5, housePoints: 10, energy: 6),
      ),
    ],
  ),
  FestivalDef(
    id: 'year_end_gala',
    name: '学年结束舞会',
    dateLabel: '6月15日',
    month: 6,
    day: 15,
    intro:
        '学年最后一晚，礼堂的地板被擦得能照见人影，串串灯笼垂成一片流动的星光。'
        '乐队奏起舒缓的圆舞曲，连平时最矜持的教授都在角落里轻轻晃着身子。'
        '明天就是暑假，今晚则是终结这一切的一声温柔的句点。',
    outcomes: [
      FestivalOutcomeDef(
        title: '跳一支舞',
        text:
            '你牵着一位朋友的手滑进舞池，笨拙但认真地迈着步子。'
            '灯光昏黄，音乐悠扬，你突然意识到这可能是值得记住的一夜。'
            '曲终，那位朋友看着你，像有很多话想说，最后只轻轻说了声「明年见」。',
        effect: FestivalEffectDef(
            reputationDim: 'social', reputationValue: 6, npcAffection: 4, energy: 6),
      ),
      FestivalOutcomeDef(
        title: '安静地站在露台上看烟火',
        text:
            '你溜到塔楼露台，看着最后一束烟火在夜空中炸开成金色。'
            '身后传来邓布利多温和的声音：「这一年的你，比你想的更勇敢。」'
            '你忽然有些舍不得这所学校了。',
        effect: FestivalEffectDef(
            reputationDim: 'leadership',
            reputationValue: 5,
            housePoints: 8,
            energy: 4),
      ),
    ],
  ),
];

/// 某月某日命中哪个节日（无则 null）。日期键对齐 [FestivalDef.dateKey]。
FestivalDef? festivalForDate(int month, int day) {
  final key = month * 100 + day;
  for (final f in kFestivals) {
    if (f.dateKey == key) return f;
  }
  return null;
}

/// 按 id 查节日。
FestivalDef? festivalById(String id) {
  for (final f in kFestivals) {
    if (f.id == id) return f;
  }
  return null;
}

/// 把节庆文本里的 `$house` 占位符替换成玩家学院名。只处理这一个占位符，
/// 其余内容均为纯文本，避免字符串插值泄漏 `$`。
String fillFestivalText(String text, {required String house}) =>
    text.replaceAll(r'$house', house);