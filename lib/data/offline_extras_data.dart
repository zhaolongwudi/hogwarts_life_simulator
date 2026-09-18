/// P8 离线扩充内容库：魁地奇赛果变体与赛后事件、禁林特殊遭遇、NPC 回忆。
///
/// 【为什么单独成文件】魁地奇 / 禁林 / NPC 聊天三处本地玩法此前叙事模板
/// 各只有一套（固定句式 + 少量随机数字），离线模式跑久了会明显重复。
/// 这三个系统各自挂接的模板统一收口到本文件，mixin 只做「选模板 +
/// 结算」，不再内嵌句子；新增剧情内容只改这里，不动玩法逻辑。
library;

// ==================== 1. 魁地奇：赛果变体 ====================

/// 胜利/惜败的叙事变体。`$myHouse`/`$opp`/`$score`/`$oppScore`/`$broom`
/// 由调用方替换。位置专属时刻（[kQuidditchPositionMoments]）另表。
class QuidditchResultVariant {
  final String winBody;
  final String lossBody;
  const QuidditchResultVariant({required this.winBody, required this.lossBody});
}

/// 赛后事件（胜负通用）。模板里可带 `$myHouse`/`$opp`/`$score`/`$oppScore`。
class QuidditchAfterEvent {
  final String text;
  final int energyCost;
  const QuidditchAfterEvent({required this.text, this.energyCost = 0});
}

/// 位置专属时刻：找球手抓飞贼 / 追球手连进三球 / 守门员扑出绝杀 / 击球手开球
class QuidditchPositionMoment {
  final String text;
  const QuidditchPositionMoment({required this.text});
}

const List<QuidditchResultVariant> kQuidditchResultVariants = [
  QuidditchResultVariant(
    winBody:
        r'终场哨响的刹那，看台像被点燃了一样。$myHouse 的旗帜在你头顶翻飞，'
        r'队友们把你抛向空中——你做到了，$myHouse $score : $oppScore $opp 拿下这一场。',
    lossBody:
        r'终场哨响，比分定格在 $myHouse $score : $oppScore $opp。'
        r'$opp 的欢呼声刺得耳朵发疼，你垂下扫帚，队友们沉默地拍了拍你的肩：'
        r'「别灰心，下一场赢回来。」',
  ),
  QuidditchResultVariant(
    winBody:
        r'比赛结束，你握着$broom 的手还在微微发颤。看台上传来整齐的呐喊，'
        r'队长第一个冲过来把你搂进怀里：「好样的！$myHouse 需要的就是这样的斗士！」'
        r'记分牌上留着 $myHouse $score : $oppScore $opp 的比分。',
    lossBody:
        r'最后几分钟里 $opp 咬住了比分，$myHouse $score : $oppScore $opp。'
        r'你回到更衣室，把脸埋进毛巾里。队长没有责怪任何人：'
        r'「输一场不是输掉赛季。回去练，下周见真章。」',
  ),
  QuidditchResultVariant(
    winBody:
        r'当哨声响起，$myHouse 的看台爆发出一阵声浪。你骑着$broom 绕场一周，'
        r'向每一个呐喊的人挥手。比分牌上 $myHouse $score : $oppScore $opp——'
        r'这一晚，$myHouse 的公共休息室注定要热闹到深夜。',
    lossBody:
        r'$myHouse $score : $oppScore $opp。输球后的城堡走廊安静得反常，'
        r'只有你们几个人抱着扫帚慢慢往回走。你暗暗发誓：下周的今天，'
        r'要让记分牌上的数字倒过来。',
  ),
];

/// 位置专属时刻：只在对应位置生效，随机触发（不与赛后事件叠加时）。
const Map<String, QuidditchPositionMoment> kQuidditchPositionMoments = {
  '找球手': QuidditchPositionMoment(
    text:
        '比赛最胶着的时刻，你的目光锁定了那抹金色的残影——金色飞贼！'
        '你压低扫帚一个俯冲，指尖擦过它冰凉的翅膀，在最后一刻把它攥进掌心。'
        '全场沸腾了。这一瞬间，你觉得自己就是为天空而生的。',
  ),
  '追球手': QuidditchPositionMoment(
    text:
        r'你在空中一个急转，鬼飞球穿过对方守门员的腋下，稳稳入环。'
        r'连进三球之后，对方球员看你的眼神都变了——你已经成了 $opp 的重点盯防对象。',
  ),
  '守门员': QuidditchPositionMoment(
    text:
        r'比赛末段 $opp 的一次快攻如闪电般袭来，你在千钧一发之际飞身扑出，'
        r'指尖堪堪把鬼飞球挡在环外。全场响起一片倒吸凉气的声音。',
  ),
  '击球手': QuidditchPositionMoment(
    text:
        r'你抡圆球棒，一记大力抽射把游走球狠狠击向 $opp 的找球手。'
        r'他不得不放弃追飞贼的路线闪避——这一球，为你的队友撕开了整个右翼的空当。',
  ),
};

/// 赛后事件池（胜负通用，单场随机触发一条；触发概率在 mixin 内控制）。
const List<QuidditchAfterEvent> kQuidditchAfterEvents = [
  QuidditchAfterEvent(
    text:
        r'赛后，$opp 的队长在球员通道口等你，郑重地握了握手：'
        r'「打得好。$myHouse 出了个了不起的新人。」你们约好下次交手再见分晓。',
  ),
  QuidditchAfterEvent(
    text:
        '霍琦夫人吹着哨子把你叫住：「姿势不错，但最后那个转弯太急，'
        '差点摔下去。下周训练来早一点，我教你个压弯的诀窍。」'
        '飞行课的内容 +1。',
  ),
  QuidditchAfterEvent(
    text:
        '更衣室门口，格兰芬多的同学们举着自制的横幅等你。'
        '有人塞给你一块滋滋蜜蜂糖，有人往你头上戴了一顶歪歪扭扭的胜利帽。'
        '被簇拥着走回城堡的路上，你第一次觉得「学院」这个词有了温度。',
    energyCost: 3,
  ),
  QuidditchAfterEvent(
    text:
        '你刚把扫帚放回棚子，就看见斯内普教授从走廊另一头路过，'
        '他瞥了你一眼，什么都没说——但那一眼里，居然有一丝几乎看不见的认可。',
  ),
  QuidditchAfterEvent(
    text:
        '一只谷仓猫头鹰在你回城堡的路上丢下一封信，是母亲寄来的。'
        '「看到《预言家日报》的赛果了，为你骄傲。别太累，记得吃饭。」'
        '你小心地把信折好收进口袋。',
  ),
];

/// 通用字符串插值：把模板里的占位符换成实际值。
String fillQuidditchTemplate(
  String template, {
  required String myHouse,
  required String opp,
  required int score,
  required int oppScore,
  required String broom,
}) {
  return template
      .replaceAll(r'$myHouse', myHouse)
      .replaceAll(r'$opp', opp)
      .replaceAll(r'$score', '$score')
      .replaceAll(r'$oppScore', '$oppScore')
      .replaceAll(r'$broom', broom);
}

// ==================== 2. 禁林：特殊遭遇表 ====================

/// 禁林特殊遭遇：与普通「遭遇生物/采材料/捡钱/空手/摔伤」平行的剧情事件。
/// [minGrade] 做年级门控：低年级玩家先解锁安全的奇遇，高年级才遇得上
/// 危险的巢穴与守卫，避免「一年级就撞上八眼巨蛛巢」的崩坏。
class ForestSpecialEncounter {
  final String id;
  final String title;
  final String text;
  final int minGrade;
  const ForestSpecialEncounter({
    required this.id,
    required this.title,
    required this.text,
    this.minGrade = 1,
  });
}

const List<ForestSpecialEncounter> kForestSpecialEncounters = [
  ForestSpecialEncounter(
    id: 'forest_centaur',
    title: '人马的低语',
    text:
        '林间雾气忽然浓郁，一位人马从树影中缓步走出。他没有敌意，只是静静看着你：'
        '「星星说，你会在这片林子里走得很远，也会遇到很多抉择。'
        '记住，森林记得每一个以善意踏入的人。」说完，他转身消失在雾中，'
        '只在风里留下一点月长石粉般的微光。',
  ),
  ForestSpecialEncounter(
    id: 'forest_unicorn',
    title: '月光下的独角兽',
    text:
        '踏进一片洒满月光的空地，月光下的独角兽正低头饮着溪水。'
        '它抬起头看了你一眼——那目光清澈得不像尘世之物。'
        '你没有靠近，只是远远地看了一会儿。它点了点头，像是默许了你这份敬意，'
        '然后缓步走进林深之处。',
    minGrade: 2,
  ),
  ForestSpecialEncounter(
    id: 'forest_acromantula',
    title: '巨蛛的巢穴',
    text:
        '蛛网越来越密，你忽然意识到自己闯进了什么地盘。'
        '八眼巨蛛的嘶鸣从四面八方响起，八只眼睛在黑暗中闪着光。'
        '你屏住呼吸，一寸一寸地后退——直到那声音被远远抛在身后。'
        '你的后背已经被冷汗浸透了。',
    minGrade: 3,
  ),
  ForestSpecialEncounter(
    id: 'forest_treasure',
    title: '猎场看守的旧物',
    text:
        '一棵老橡树的树洞里，躺着一只锈迹斑斑的铁盒。打开一看——'
        '几枚加隆、一张泛黄的便条（「藏在这里，别让费尔奇看见。——R.H.」），'
        '还有一根漆黑的夜骐尾羽。',
    minGrade: 2,
  ),
  ForestSpecialEncounter(
    id: 'forest_thestral',
    title: '直视生死的夜骐',
    text:
        '直视生死的夜骐，就在你面前。月光下，几匹漆黑的夜骐正低头啃食着青草，'
        '它们有着蝙蝠般的翅膀和银白色的眼睛。你能看见它们——'
        '这意味着，你的生命中已经见过了死亡。你没有害怕，只是静静站在那里，'
        '直到它们展翅飞离。',
    minGrade: 4,
  ),
  ForestSpecialEncounter(
    id: 'forest_centaur_war',
    title: '人马的警告',
    text:
        '这次你遇到的是费伦泽。他压低声音：「暴风雨就要来了，不是天上那种。'
        '这段时间，夜里不要独自进这片林子。若是非进不可——带上你的魔杖，'
        '和你的朋友。」他的语气里带着不容置疑的认真。',
    minGrade: 3,
  ),
  ForestSpecialEncounter(
    id: 'forest_golden_flower',
    title: '金色花海',
    text:
        '转过一片山坳，你的眼前忽然铺开一片金色花海——是只在月圆之夜开放的'
        '月长石花。整片花海在月光下泛着柔和的光晕，美得让人屏息。'
        '你小心翼翼地采下几朵，收进怀里。',
  ),
  ForestSpecialEncounter(
    id: 'forest_phoenix_feather',
    title: '凤凰的足迹',
    text:
        '林地上散落着几根赤金色的羽毛，在暗处竟微微发着光。'
        '凤凰不会轻易留下痕迹——你小心地把羽毛收好，没有声张。'
        '（获得：凤羽）',
    minGrade: 2,
  ),
];

// ==================== 3. NPC 回忆库 ====================

/// 一段 NPC 回忆支线：好感达标 + 未收集时，在聊天结束后解锁。
/// [affectionThreshold] 门槛与好感度档位对齐（10=相识、35=好友、60=挚友）。
/// [rewardAffection]/[rewardGalleons] 是解锁时附带的奖励。
class NpcMemory {
  final String id;
  final String npcId;
  final String title;
  final String text;
  final int affectionThreshold;
  final int rewardAffection;
  final int rewardGalleons;
  const NpcMemory({
    required this.id,
    required this.npcId,
    required this.title,
    required this.text,
    required this.affectionThreshold,
    this.rewardAffection = 2,
    this.rewardGalleons = 0,
  });
}

/// 回忆库：核心角色每人 2~3 段，按好感逐层解锁。
/// 文案锚定原著人设的「过去」，不剧透主线、不改变玩家选择空间。
const List<NpcMemory> kNpcMemories = [
  // ---- 哈利·波特 ----
  NpcMemory(
    id: 'harry_1',
    npcId: 'harry',
    title: '哈利的伤疤',
    text:
        '哈利卷起额前的刘海，露出那道闪电形的伤疤：「听他们说，这是那天夜里留下的。」'
        '他顿了顿，「有时候它还会隐隐作痛——但我已经习惯了。」'
        '他没有说下去，你也没有问。有些事，朋友之间不必多言。',
    affectionThreshold: 10,
  ),
  NpcMemory(
    id: 'harry_2',
    npcId: 'harry',
    title: '碗橱里的男孩',
    text:
        '夜深了，哈利忽然提起以前的事：「我小时候住在一间碗橱里，'
        '在德思礼家。他们给我表哥买一大堆玩具，我只能隔着楼梯栏杆看。」'
        '他笑了笑，「现在想想，能来霍格沃茨，大概是全世界最幸运的事。」',
    affectionThreshold: 35,
    rewardGalleons: 10,
  ),
  NpcMemory(
    id: 'harry_3',
    npcId: 'harry',
    title: '与父母有关的梦',
    text:
        '训练结束后的傍晚，哈利坐在球场边，声音很轻：「我几乎不记得他们的样子了。'
        '只有梦——梦里妈妈会对我笑，爸爸的眼镜总是滑下来。」'
        '他望着远处的城堡，「有时候我希望，能再多记住一点。」',
    affectionThreshold: 60,
    rewardGalleons: 15,
  ),

  // ---- 赫敏·格兰杰 ----
  NpcMemory(
    id: 'hermione_1',
    npcId: 'hermione',
    title: '牙医的女儿',
    text:
        '赫敏难得没有在看书：「我爸妈是牙医——麻瓜的那种。'
        '他们以为我在这里上的是一所特别厉害的寄宿学校。」'
        '她认真地补充，「总有一天我会让他们明白，这里的魔法是真的。」',
    affectionThreshold: 10,
  ),
  NpcMemory(
    id: 'hermione_2',
    npcId: 'hermione',
    title: '图书馆的晚自习',
    text:
        '闭馆前的图书馆只剩你们两个人。赫敏合上书，忽然叹了口气：'
        '「有时候我会害怕——如果我拼命努力，最后发现自己还是不够好，怎么办？」'
        '这是你第一次在她眼里看到不安，也是第一次觉得，她并不是无所不能的。',
    affectionThreshold: 35,
    rewardGalleons: 10,
  ),
  NpcMemory(
    id: 'hermione_3',
    npcId: 'hermione',
    title: '巫师的世界太吵了',
    text:
        '赫敏望着窗外，声音比平时轻：「我花了很久才习惯，这里的一切都讲魔法，'
        '不讲道理。」她顿了顿，「但你是讲道理的人——这对我来说，很重要。」',
    affectionThreshold: 60,
    rewardGalleons: 15,
  ),

  // ---- 罗恩·韦斯莱 ----
  NpcMemory(
    id: 'ron_1',
    npcId: 'ron',
    title: '旧袍子与手帕',
    text:
        '罗恩拽了拽自己那件明显大一号的旧袍子，假装不在意：'
        '「我上面还有五个哥哥，什么都是他们传下来的。」'
        '他掏出一条旧手帕，「连这个都是查理的。但没关系——总比什么都没有强。」',
    affectionThreshold: 10,
  ),
  NpcMemory(
    id: 'ron_2',
    npcId: 'ron',
    title: '哥哥们的影子',
    text:
        '罗恩一边往嘴里塞着鸡腿一边嘟囔：「珀西是级长，双胞胎是明星，'
        '查理玩魁地奇，比尔是学生会主席……家里人都在等我变成下一个谁。」'
        '他停了停，「我只想当我自己。」',
    affectionThreshold: 35,
    rewardGalleons: 10,
  ),
  NpcMemory(
    id: 'ron_3',
    npcId: 'ron',
    title: '巫师棋教我的事',
    text:
        '深夜的公共休息室，罗恩对着棋盘发呆：「我爸总说，下棋和人生一样——'
        '重要的不是每一步都走对，而是输了之后还能不能接着下。」'
        '他挪了一步棋，「我把这句话，记到了现在。」',
    affectionThreshold: 60,
    rewardGalleons: 15,
  ),

  // ---- 纳威·隆巴顿 ----
  NpcMemory(
    id: 'neville_1',
    npcId: 'neville',
    title: '奶奶的怀表',
    text:
        '纳威从口袋里摸出一只旧怀表：「这是我爸爸的。奶奶说，等我长大一点就还给我。」'
        '他握紧怀表，「我经常把东西弄丢，但这一件——绝对不会。」',
    affectionThreshold: 10,
  ),
  NpcMemory(
    id: 'neville_2',
    npcId: 'neville',
    title: '记忆球',
    text:
        '纳威红着脸把那颗灰扑扑的记忆球给你看：「它变红的时候，'
        '说明我忘了什么事。但我总是想不起来忘了什么……」'
        '他挠挠头，「我奶奶说，她记得我小时候第一次抓到它时，'
        '高兴得蹦了起来。」',
    affectionThreshold: 35,
  ),

  // ---- 德拉科·马尔福 ----
  NpcMemory(
    id: 'draco_1',
    npcId: 'draco',
    title: '父亲的期望',
    text:
        '德拉科难得没有用那种腔调说话：「我父亲对我只有一个要求——'
        '成为马尔福家该有的样子。」他垂着眼，「有时候我真想知道，'
        '如果没有这个姓氏，他还愿不愿意认我这个儿子。」',
    affectionThreshold: 20,
  ),

  // ---- 邓布利多 ----
  NpcMemory(
    id: 'dumbledore_1',
    npcId: 'dumbledore',
    title: '柠檬雪宝',
    text:
        '邓布利多从抽屉里取出一颗柠檬雪宝糖递给你：「我年轻的时候，'
        '也喜欢在深夜的办公室想一些没答案的问题。」'
        '他眨眨眼，「后来我发现，甜的东西能让人想得快一点——你要不要试试？」',
    affectionThreshold: 10,
  ),
  NpcMemory(
    id: 'dumbledore_2',
    npcId: 'dumbledore',
    title: '镜中的秘密',
    text:
        '邓布利多望着窗外，声音平静：「厄里斯魔镜很有趣——它照出的是渴望，'
        '不是真相。」他转过身，「我年轻时也曾在它面前站了很久。'
        '但总有一天你会明白：最强大的魔法，从来不是得到想要的一切。」',
    affectionThreshold: 50,
    rewardGalleons: 10,
  ),

  // ---- 斯内普 ----
  NpcMemory(
    id: 'snape_1',
    npcId: 'snape',
    title: '坩埚边的话',
    text:
        '魔药课结束后，斯内普教授叫住你——却没有训斥：「你刚才往坩埚里加'
        '瞌睡豆的时机，提前了两秒。」他顿了一下，「两秒钟，够一个人记住另一个人一生。」'
        '说完他转身走了，只留你在空荡荡的教室里发愣。',
    affectionThreshold: 20,
  ),

  // ---- 海格 ----
  NpcMemory(
    id: 'hagrid_1',
    npcId: 'hagrid',
    title: '林间小屋的茶',
    text:
        '海格往你的杯子里续了第三杯茶：「我总爱跟你们讲龙的故事，'
        '是因为我自己一直想要一条——」他有点不好意思地挠挠头，'
        '「想得够久了，久到我都分不清，那到底是回忆还是愿望了。」',
    affectionThreshold: 10,
  ),
  NpcMemory(
    id: 'hagrid_2',
    npcId: 'hagrid',
    title: '被误解的人',
    text:
        '海格难得安静下来：「我这辈子被人误解过很多回。但霍格沃茨从来没有把我赶出去——'
        '这里永远是我的家。」他看着你，「你也一样。不管你以后走到哪儿，'
        '这儿都留着你的位置。」',
    affectionThreshold: 40,
    rewardGalleons: 10,
  ),
];

NpcMemory? npcMemoryById(String id) {
  for (final m in kNpcMemories) {
    if (m.id == id) return m;
  }
  return null;
}

/// 某个 NPC 未收集的回忆（按好感门槛从小到大排）。
List<NpcMemory> pendingMemoriesFor(
  String npcId,
  int affection,
  Set<String> collected,
) {
  final out = <NpcMemory>[];
  for (final m in kNpcMemories) {
    if (m.npcId != npcId) continue;
    if (collected.contains(m.id)) continue;
    if (affection < m.affectionThreshold) continue;
    out.add(m);
  }
  out.sort((a, b) => a.affectionThreshold.compareTo(b.affectionThreshold));
  return out;
}