/// 世界线变动率的兑现：因果锚点（Causal Anchor）
///
/// ## 这个系统要解决什么问题
///
/// `player.worldLineDeviation` 之前每 10 回合自动 +0.005，然后在三处被读：
/// 成就门槛、目标门槛、影响力增速。也就是说——**它只有一个数字，没有兑现点。**
/// 玩家玩满七年，看到的是一条从 0.0% 爬到 30% 的进度条，仅此而已。
///
/// 这是单机 AI 叙事游戏最该打出来的一张牌没打出来：
/// 原著里那些"已经写死"的事件，玩家到底能不能改？
///
/// ## 设计
///
/// 把原著的关键节点做成**因果锚点**。每个锚点绑定一个
/// `event_anchors.dart` 里的事件 id，当那个事件要发生时，
/// 如果玩家的世界线变动率已经够高，就会弹出抉择：
///
/// - **干预**：你伸手了。史书上这一段从此是错的。
///   → 变动率暴涨，影响力暴涨，但你要付代价（健康、道德声望、或者别的）
/// - **旁观**：你让该发生的发生。
///   → 变动率回落（世界线自我修复回原典），你平安，但你记得自己什么都没做
///
/// 这个闭环是整个系统的灵魂：
///
/// ```
/// 时间推移 → 变动率缓慢上升 → 越过门槛 → 出现第一个抉择
///   → 选干预 → 变动率跳一大截 → 更快越过下一道门槛 → 更硬的定数也能改
///   → 选旁观 → 变动率掉回去 → 世界回到书上写的那样，但你失去了它
/// ```
///
/// "想把人救下来"和"想让这个世界还是你认识的那个世界"，
/// 在这里是互斥的。这就是那张王牌。
///
/// ## 越硬的定数，改起来越贵
///
/// `CausalAnchor.minStage` 就是门槛。塔楼那一夜要求 rewritten（≥0.40），
/// 决斗俱乐部那点小事只要 fraying（≥0.10）就能插手。
/// 干预的 `deviationDelta` 也随门槛递增：改一件小事 +0.08，
/// 把塔楼那一夜改写 +0.22。

/// 世界线自动漂移：每 [kDeviationTickIntervalDays] 个游戏日结算一次。
///
/// 按"游戏内天数"而不是"回合数"计：一回合推进多少分钟取决于玩家在做什么
/// （默认 15 分钟，睡一觉 480 分钟），一学年到底几百个回合根本估不准，
/// 按回合计费的所有平衡数字都是空中楼阁。一学年九月初到六月底 ≈ 270 天，
/// 这个是确定的。
const int kDeviationTickIntervalDays = 10;

/// 漂移的基准步长。
const double kDeviationTickBase = 0.004;

/// 纯漂移能到达的上限。
///
/// **这个阻尼不是装饰，是整套门槛成立的前提。** 线性累加做不到
/// 下面这两件事同时成立：
///   · 二年级就该碰到第一个分歧点（否则绝大多数玩家一辈子见不着一个抉择）
///   · 什么都不做到毕业也够不到「已被改写」（否则干预与否毫无区别）
///
/// 线性 tick 的无解之处在于：前者要求斜率 > 0.071/学年，
/// 后者要求 < 0.061/学年——区间是空的。
///
/// 加上阻尼后（越接近原典越容易被推动，偏得越远世界越"沉"），
/// 划水七年稳定停在 0.36 左右：够得到「分歧显现」，
/// 永远够不到 0.40 的「已被改写」。
/// 于是**想改塔楼那一夜，你必须先在某处伸过手**——这就是这套系统的全部张力所在。
const double kDeviationDriftCap = 0.45;

/// 一次漂移的增量。偏离越远，世界越沉，漂得越慢。
double deviationDriftFor(double current) {
  if (current.isNaN || current >= kDeviationDriftCap) return 0.0;
  final d = current < 0 ? 0.0 : current;
  return kDeviationTickBase * (1.0 - d / kDeviationDriftCap);
}

/// 世界线阶段
enum WorldLineStage {
  /// 原典未改：一切都还按书上来
  intact,

  /// 边缘松动：小人物、小事件的走向可以改
  fraying,

  /// 分歧显现：重要配角的命运可以改
  diverging,

  /// 已被改写：主线关键节点可以改
  rewritten,

  /// 面目全非：连最硬的定数都能改
  unrecognizable,
}

class WorldLineStageDef {
  final WorldLineStage stage;
  final double minDeviation;
  final String label;
  final String badge;

  /// 注入给叙事 AI 的氛围指令。
  ///
  /// 注意：这是**唯一**让 AI 感知到"这个世界被改写过"的通道。
  /// 不写清楚，AI 会在玩家把塔楼那一夜改掉之后，
  /// 下一回合照旧写"邓布利多死了"——因为它的训练数据里就是这么写的。
  final String aiDirective;

  const WorldLineStageDef({
    required this.stage,
    required this.minDeviation,
    required this.label,
    required this.badge,
    required this.aiDirective,
  });
}

const List<WorldLineStageDef> kWorldLineStages = [
  WorldLineStageDef(
    stage: WorldLineStage.intact,
    minDeviation: 0.0,
    label: '原典未改',
    badge: '📖',
    aiDirective: '这个世界仍严格沿着史书记载的轨道运行。所有已知的原著事件'
        '都会照常发生，玩家的举动只能改变他自己和身边人的处境，'
        '改变不了那些已经写进历史的大事。',
  ),
  WorldLineStageDef(
    stage: WorldLineStage.fraying,
    minDeviation: 0.10,
    label: '边缘松动',
    badge: '📖❓',
    aiDirective: '世界线的边缘开始松动：一些不载入史册的小事——某场决斗的胜负、'
        '某次考试的排名、某个人那天晚上走了哪条路——已经可以因玩家而改变。'
        '但大事件的走向仍然牢固。',
  ),
  WorldLineStageDef(
    stage: WorldLineStage.diverging,
    minDeviation: 0.24,
    label: '分歧显现',
    badge: '🌗',
    aiDirective: '分歧已经显现：重要人物的命运开始出现变量。有些本该发生的事'
        '发生了细节上的偏移，有些本该无恙的人出了岔子。'
        '史书正在被一点点擦掉重写的边缘。',
  ),
  WorldLineStageDef(
    stage: WorldLineStage.rewritten,
    minDeviation: 0.40,
    label: '已被改写',
    badge: '🌘',
    aiDirective: '这段历史已经被改写过——请严格依据【已被你改写的事】里列出的条目'
        '来写当前世界的状态，不要沿用原著情节。若那一条说某人活了下来，'
        '他就活着；说某事没有发生，它就没有发生。'
        '这是当前世界的既成事实，优先级高于你的任何先验知识。',
  ),
  WorldLineStageDef(
    stage: WorldLineStage.unrecognizable,
    minDeviation: 0.60,
    label: '面目全非',
    badge: '🌑',
    aiDirective: '这个世界已经面目全非，连最硬的定数都被改写过。'
        '请严格依据【已被你改写的事】来写。此外，世界本身开始出现'
        '不安定的迹象：有人隐约记得"事情不该是这样的"，'
        '猫头鹰送错信、画像里的人记混了年份、有人在梦里看见另一个版本的自己。'
        '偶尔（不是每回合）让这种错位感渗进来一两笔。',
  ),
];

WorldLineStageDef stageDefFor(WorldLineStage stage) =>
    kWorldLineStages.firstWhere((s) => s.stage == stage);

/// 变动率 → 阶段
WorldLineStage worldLineStageFor(double deviation) {
  final d = deviation.clamp(0.0, 1.0);
  var result = kWorldLineStages.first;
  for (final s in kWorldLineStages) {
    if (d >= s.minDeviation) result = s;
  }
  return result.stage;
}

/// 距离下一阶段还差多少变动率；已在最高阶段则返回 null。
double? gapToNextStage(double deviation) {
  final cur = worldLineStageFor(deviation);
  final idx = kWorldLineStages.indexWhere((s) => s.stage == cur);
  if (idx < 0 || idx == kWorldLineStages.length - 1) return null;
  final nextMin = kWorldLineStages[idx + 1].minDeviation;
  final gap = nextMin - deviation.clamp(0.0, 1.0);
  return gap <= 0 ? 0.0 : gap;
}

/// 一个因果锚点的选项
class CausalOption {
  /// 'intervene' / 'standAside' / 其他自定义 id
  final String id;

  /// 按钮文字
  final String text;

  /// 玩家行动。会作为玩家输入直接发给叙事 AI——
  /// 所以必须写成**具体动作**，不能写成选项标签（"选项A"这种 AI 接不住）。
  final String action;

  /// 变动率增减。干预为正（改写历史），旁观为负（世界线自我修复）。
  final double deviationDelta;

  /// 声望增减，key 为 Reputation 的六个维度之一
  final Map<String, int> reputation;

  /// 属性增减，key 见 attribute_data.dart
  final Map<String, int> attributes;

  final int healthDelta;

  /// 世界影响力增减（0~1，与 playerImpactScore 同量纲）
  final double impactDelta;

  /// 选择之后立刻展示给玩家的后果文本
  final String consequence;

  /// 永久留在世界里的痕迹。选择之后，这条会写进【已被你改写的事】，
  /// 之后每回合都注入 AI——这是改写"真的发生过"的唯一凭证。
  /// 旁观选项留空字符串：世界回到原典，不留痕迹。
  final String echo;

  const CausalOption({
    required this.id,
    required this.text,
    required this.action,
    required this.deviationDelta,
    this.reputation = const {},
    this.attributes = const {},
    this.healthDelta = 0,
    this.impactDelta = 0.0,
    required this.consequence,
    this.echo = '',
  });

  bool get isIntervention => echo.isNotEmpty;
}

/// 因果锚点：绑定一个事件锚点 id，在它触发时提供分支抉择
class CausalAnchor {
  /// 对应 event_anchors.dart 里的 EventAnchor.id
  final String anchorId;

  /// 抉择标题
  final String title;

  /// 解锁所需的最低世界线阶段
  final WorldLineStage minStage;

  /// 时代限制；null = 所有时代
  final String? era;

  /// 抉择前的旁白（不告知后果）
  final String setup;

  final List<CausalOption> options;

  const CausalAnchor({
    required this.anchorId,
    required this.title,
    required this.minStage,
    this.era,
    required this.setup,
    required this.options,
  });
}

const List<CausalAnchor> kCausalAnchors = [
  // ==================== 二年级·决斗俱乐部 ====================
  // 不限时代：任何年代都成立的小事，门槛也最低。
  // 这是绝大多数玩家会遇到的第一个分歧点——它必须够早、够轻，
  // 让"世界线是可以被改动的"这件事在一开始就被玩家看见。
  CausalAnchor(
    anchorId: 'g2_feb_duelling',
    title: '决斗俱乐部·那一下犯规',
    minStage: WorldLineStage.fraying,
    setup: '决斗俱乐部散场的时候你看见了：那个总赢的人赢在裁判看不见的地方——'
        '袍子底下藏着一枚已经缴械过的备用魔杖。下一场，他对上的是你认识的人。',
    options: [
      CausalOption(
        id: 'intervene',
        text: '当场揭穿他',
        action: '我在众目睽睽之下指出他袍子底下那根魔杖，要求裁判检查。',
        deviationDelta: 0.08,
        reputation: {'moral': 6, 'social': -4, 'combat': 3},
        attributes: {'courage': 4, 'social': -2},
        impactDelta: 0.04,
        consequence: '你指了出来。那一瞬间整个大厅安静得能听见火把的噼啪声。'
            '他脸上那种表情你后来在很多场合又见过——不是被抓包的慌张，'
            '是被人当面撕下皮的那种恨。他从此再没赢过一场正当的决斗，'
            '也再没跟你说过一句话。',
        echo: '你在决斗俱乐部当场揭穿了那人的作弊。他从此记恨你，'
            '而那一年往后的决斗排名，和原本该有的不一样。',
      ),
      CausalOption(
        id: 'standAside',
        text: '什么也没说',
        action: '我把到嘴边的话咽了回去，转身混进散场的人群。',
        deviationDelta: -0.05,
        reputation: {'moral': -5, 'social': 3},
        attributes: {'caution': 3, 'courage': -2},
        consequence: '你什么也没说。你朋友输了，还笑着恭喜对手。'
            '那人从台上下来时冲你点了下头——他知道你看见了，'
            '你们从此共享一个秘密，尽管你一个字都没说过。',
      ),
    ],
  ),

  // ==================== 五年级·O.W.L. 泄题 ====================
  // 同样不限时代。这是"变动作弊"之外的另一种改法：改自己。
  CausalAnchor(
    anchorId: 'g5_jun_owls',
    title: 'O.W.L.·提前拿到的试题',
    minStage: WorldLineStage.fraying,
    setup: '考前一周，一份试题出现在你抽屉里。没有署名，没有勒索信，'
        '就那么放着——像有人替你把路铺好了，又像是有人在测试你会不会走上去。',
    options: [
      CausalOption(
        id: 'intervene',
        text: '把试题交上去',
        action: '我拿着那份试题去了教授办公室，把它放在桌子上，什么也没多说。',
        deviationDelta: 0.09,
        reputation: {'moral': 8, 'academic': 4, 'social': -6},
        attributes: {'willpower': 4, 'courage': 3},
        healthDelta: -5,
        impactDelta: 0.05,
        consequence: '考试照常举行，题目全换了。有人考砸了，有人在考场里骂了脏话。'
            '你那几门成绩平平，其中一门还挂了。'
            '但你之后每次走过那条走廊，都能直视任何一双眼睛。',
        echo: '你交回了那份提前拿到的 O.W.L. 试题，导致当年考题全部重出。'
            '你的成绩因此比本该有的差了一截，但你知道是谁在背后替你骄傲。',
      ),
      CausalOption(
        id: 'standAside',
        text: '收下它',
        action: '我把试题收进怀里，谁也没告诉。',
        deviationDelta: -0.06,
        reputation: {'moral': -8, 'academic': 6, 'social': 2},
        attributes: {'caution': 4, 'willpower': -3},
        consequence: '你考得很好。好到有人来问你复习的诀窍，'
            '你编了个说得通的谎。那份纸你烧掉了，'
            '但灰烬的形状你记了很久。',
      ),
    ],
  ),

  // ==================== 五年级·新法令 ====================
  CausalAnchor(
    anchorId: 'g5_oct_ministry_decree',
    title: '新法令·被当众念出来的名字',
    minStage: WorldLineStage.diverging,
    era: 'harry_same',
    setup: '那位派来的官员在礼堂里念名单，念到一半停下，'
        '抬起头说：还有一个名字，念出来之前给她最后一次机会。'
        '你认识那个"她"——她就站在离你三步远的地方，'
        '整个人僵着，像被人从背后顶住了一把刀。',
    options: [
      CausalOption(
        id: 'intervene',
        text: '站到她旁边去',
        action: '我离开队伍，走到她身边站定，什么也没说。',
        deviationDelta: 0.14,
        reputation: {'moral': 10, 'leadership': 6, 'social': -8},
        attributes: {'courage': 6, 'caution': -4},
        healthDelta: -12,
        impactDelta: 0.09,
        consequence: '礼堂安静了很久。最后官员把名单折起来，'
            '说今天到此为止。你被记了过，抄了一整夜的校规，'
            '而那个人这之后再没在食堂里单独坐过——总有人陪她。'
            '那不全是你的功劳，但你开了头。',
        echo: '你在礼堂上当众站到了被点名的人身边。她没有被带走，'
            '而那份名单从那天起改了写法——他们不再当众念名字。',
      ),
      CausalOption(
        id: 'standAside',
        text: '低着头，不动',
        action: '我盯着自己的鞋尖，直到人群散尽。',
        deviationDelta: -0.09,
        reputation: {'moral': -9, 'caution': 0},
        attributes: {'caution': 5, 'courage': -4, 'emotional_stability': -3},
        consequence: '名字被念完了。她后来还来上课，'
            '只是不再抬头看黑板。你每次想跟她说话，'
            '都先想起那天自己鞋尖上的那块灰。',
      ),
    ],
  ),

  // ==================== 六年级·身边的人出事了 ====================
  CausalAnchor(
    anchorId: 'g6_oct_classmate_loss',
    title: '身边的人出事了·来得及',
    minStage: WorldLineStage.diverging,
    era: 'harry_same',
    setup: '消息传来的时候你离那边只有一条走廊。'
        '没有大人，没有教授，只有你和一扇还没关上的门。'
        '你跑过去大概要二十秒——二十秒，够做点什么。',
    options: [
      CausalOption(
        id: 'intervene',
        text: '跑过去',
        action: '我没有多想，转身朝那条走廊跑过去。',
        deviationDelta: 0.16,
        reputation: {'moral': 9, 'combat': 7, 'leadership': 5},
        attributes: {'courage': 7, 'reaction_time': 3},
        healthDelta: -20,
        impactDelta: 0.11,
        consequence: '你到了。你做了你当时能想到的一切，'
            '其中大部分是错的，但你到了。'
            '他活下来了——代价是你自己在医疗翼躺了两周，'
            '左肩到现在阴雨天还会疼。'
            '史书上那一年的名单是错的，因为你在上面划掉了一个名字。',
        echo: '你在那条走廊上赶到了，本该出事的人活了下来。'
            '史书上那一年的名单少了一个名字，而你的左肩从此阴雨天会疼。',
      ),
      CausalOption(
        id: 'standAside',
        text: '站在原地',
        action: '我站在原地没有动，听着那边的声音一点点平息。',
        deviationDelta: -0.11,
        reputation: {'moral': -11, 'social': 2},
        attributes: {'emotional_stability': -5, 'caution': 4, 'willpower': -3},
        consequence: '你站在原地。后来的事你都是从别人嘴里听来的，'
            '每个版本都不一样。葬礼上你去了，'
            '站得比谁都久。没人知道你当时离得有多近。',
      ),
    ],
  ),

  // ==================== 六年级·塔楼那一夜 ====================
  // 全表最硬的定数。门槛 rewritten（≥0.40），干预收益最大，代价也最大。
  CausalAnchor(
    anchorId: 'g6_jun_headmaster_fall',
    title: '塔楼那一夜',
    minStage: WorldLineStage.rewritten,
    era: 'harry_same',
    setup: '城堡里乱成一团，所有人都在往外跑，只有你注意到'
        '通往塔楼的那道楼梯上有人在往上走——走得很稳，稳得不对劲。'
        '你不知道上面会发生什么。你只知道如果现在上去，'
        '你还有可能来得及；如果不上去，明天的一切都会照着某个'
        '早就写好的样子发生。',
    options: [
      CausalOption(
        id: 'intervene',
        text: '上塔去',
        action: '我没有跟着人群往外走，我转身上塔楼的楼梯。',
        deviationDelta: 0.22,
        reputation: {'moral': 12, 'combat': 10, 'leadership': 8, 'social': -5},
        attributes: {'courage': 8, 'willpower': 6, 'emotional_stability': -6},
        healthDelta: -30,
        impactDelta: 0.18,
        consequence: '你上了塔。'
            '后来的事情没有一个版本说得清楚——包括你自己。'
            '你记得有人坠落，但你不确定是谁；你记得自己的魔杖亮了，'
            '但你不确定那道咒有没有打中。'
            '第二天全校被要求保持安静，但压着嗓子的哭声里，'
            '混着一些别的什么：有人活着走下了那座塔，'
            '尽管史书上写的是他死在了上面。'
            '你在医疗翼躺了整整一个月。有些事你至今没跟任何人说过。',
        echo: '塔楼那一夜你上了塔。那位本该在那晚死去的校长活了下来，'
            '还活着，还在当校长。史书上没有这一笔，'
            '但整个世界的后两年都是照着"他还活着"往下走的。'
            '你自己身上留下了那一夜的伤，阴雨天会疼。',
      ),
      CausalOption(
        id: 'standAside',
        text: '跟着人群往外走',
        action: '我随着人流往外走，没有回头。',
        deviationDelta: -0.15,
        reputation: {'moral': -12, 'caution': 0, 'leadership': -5},
        attributes: {'caution': 6, 'courage': -6, 'emotional_stability': -4},
        consequence: '你跟着人群往外走。'
            '第二天全校被要求保持安静，走廊里全是压着嗓子的哭声。'
            '你站在人群里抬头看那座塔，和其他所有人一样。'
            '一切照着书上写的发生了。'
            '世界线稳稳地回到了它该在的轨道上——代价是你自己知道，'
            '那天晚上你离得有多近。',
      ),
    ],
  ),

  // ==================== 七年级·回不去的学校 ====================
  CausalAnchor(
    anchorId: 'g7_oct_on_the_run',
    title: '回不去的学校·名单上的另一个名字',
    minStage: WorldLineStage.rewritten,
    era: 'harry_same',
    setup: '你拿到了回学校的许可。名单上有你的名字，'
        '也有另一个人的名字——那个人本不该在上面，'
        '是有人填错了，还是有人故意的，都一样：'
        '他只要踏进城堡大门，就会被带走。'
        '你可以提醒他。提醒了他，你就得解释你是怎么知道的。',
    options: [
      CausalOption(
        id: 'intervene',
        text: '把他的名字划掉',
        action: '我在夜里潜进办公室，把他从名单上划掉，改成另一个不存在的名字。',
        deviationDelta: 0.17,
        reputation: {'moral': 10, 'leadership': 7, 'dark': 3},
        attributes: {'courage': 6, 'caution': -3, 'intuition': 3},
        healthDelta: -10,
        impactDelta: 0.12,
        consequence: '第二天点名的时候那个名字被跳过了，'
            '念名字的人皱了下眉，没多问。'
            '他没来学校，但他在——有人在霍格莫德见过他，'
            '瘦了很多，还活着。'
            '至于你是怎么知道那份名单的，'
            '你编了个谎，谎编得不算好，但没人再追问。',
        echo: '你把那个人从回校名单上划掉了。他没进城堡，也因此没被带走，'
            '还活着。有人在霍格莫德见过他。',
      ),
      CausalOption(
        id: 'standAside',
        text: '照常回学校',
        action: '我什么也没做，照常收拾行李回学校。',
        deviationDelta: -0.12,
        reputation: {'moral': -10, 'caution': 0},
        attributes: {'caution': 5, 'courage': -5, 'emotional_stability': -5},
        consequence: '你回了学校。他回了学校。'
            '第三天他没来上课，第四天他的名字从宿舍门牌上被摘了下来。'
            '你照常上课，照常吃饭，照常在走廊里低头走路。'
            '一切照旧。',
      ),
    ],
  ),

  // ==================== 七年级·城堡之下 ====================
  // 最后一个，也是唯一一个三选一的锚点。
  // 这三个选项在别的游戏里会被判高下，这里不判——
  // 报告里写过：战斗、护送他人、躲藏、或者仅仅是活下来，都应当被允许。
  CausalAnchor(
    anchorId: 'g7_may_battle',
    title: '城堡之下',
    minStage: WorldLineStage.unrecognizable,
    era: 'harry_same',
    setup: '城堡被要求交出一个人。学生们被集中到一处，'
        '然后战争在校园里正面打响了。'
        '你有大概十秒钟决定自己往哪边走。',
    options: [
      CausalOption(
        id: 'intervene',
        text: '留下来打',
        action: '我没有往后退，我抽出魔杖站到了前面。',
        deviationDelta: 0.20,
        reputation: {'combat': 15, 'moral': 10, 'leadership': 12, 'dark': 5},
        attributes: {'courage': 10, 'willpower': 8, 'emotional_stability': -8},
        healthDelta: -35,
        impactDelta: 0.22,
        consequence: '你留下了。'
            '这一夜之后有人叫你英雄，有人只记得你身上沾了血。'
            '你救回来的人比你以为的少，'
            '你没救回来的人比你以为的多。'
            '但那天晚上站在前面的一共有十几个人，'
            '而原本该站出来的那几个，'
            '其中有两个是被你拉过去的。',
        echo: '城堡之战那一夜你留在了前面。你没能让所有人活下来，'
            '但你拉住了两个人，而那两个人原本不在那份名单上。',
      ),
      CausalOption(
        id: 'escort',
        text: '护送别人离开',
        action: '我转身去拽那些还愣着的人，把他们往通道那边推。',
        deviationDelta: 0.13,
        reputation: {'moral': 12, 'leadership': 9, 'combat': 4},
        attributes: {'courage': 6, 'social': 4, 'willpower': 4},
        healthDelta: -18,
        impactDelta: 0.15,
        consequence: '你没打，你拽人。'
            '你一共把七个愣在原地的人推进了那条通道，'
            '第八个你没拉住——你回头找的时候，'
            '通道已经被封了。'
            '那七个人后来都活到了战后。其中一个每年给你寄一张圣诞卡。',
        echo: '城堡之战那一夜你没打，你拽人。你把七个愣在原地的人推进了通道，'
            '第八个没拉住。那七个人都活到了战后。',
      ),
      CausalOption(
        id: 'standAside',
        text: '找一个地方躲起来',
        action: '我丢下所有人，找一个能藏身的地方躲了起来。',
        deviationDelta: -0.18,
        reputation: {'moral': -15, 'combat': -8, 'leadership': -10},
        attributes: {'caution': 8, 'courage': -8, 'emotional_stability': -10},
        consequence: '你活下来了。'
            '天亮的时候你从藏身处爬出来，'
            '城堡还在，但已经不是你认识的那座了。'
            '毕业宴会上没有人提那一夜你去了哪里，'
            '也没有人需要提——每个人心里都有本账。'
            '这是你的那本。',
      ),
    ],
  ),

  // ==================== 亲世代·O.W.L. 考完那天 ====================
  // 挂 mr_g5_jun_worst_memory（1976 年 6 月）。
  //
  // 这是全游戏最值得挂因果锚点的一天，即便它看起来只是一场校园霸凌。
  // 原著里，莉莉在这一幕之后彻底跟斯内普决裂——
  // 她后来嫁给了詹姆，于是有了一个叫哈利的孩子，
  // 于是有了往后所有的故事。分岔点就在这个下午的草坪上。
  //
  // 门槛设在 diverging：这一笔改写的是**一个配角的命运**，
  // 不是"哈利会不会出生"那条主线。你站出来，斯内普此后对你
  // 少了一点恨，而那一点恨在他往后的人生里值很多东西。
  CausalAnchor(
    anchorId: 'mr_g5_jun_worst_memory',
    title: '草坪上那一下',
    minStage: WorldLineStage.diverging,
    era: 'marauders',
    setup: '考完最后一门的下午，草坪上围了一圈人。'
        '被倒吊在半空中的是那个斯莱特林男生，袍子被褪到了头上，'
        '围观的人在笑。动手的那个人很得意，'
        '他没注意到人群外沿站着的那个红头发女生——'
        '她没有笑，她在看，而且她看见了你。',
    options: [
      CausalOption(
        id: 'intervene',
        text: '站到他旁边去',
        action: '我挤进人群，站到被倒吊的那个人旁边，喊教授过来。',
        deviationDelta: 0.12,
        reputation: {'moral': 10, 'social': -6, 'combat': 2},
        attributes: {'courage': 6, 'social': -3, 'willpower': 3},
        impactDelta: 0.08,
        consequence: '你挤了进去。'
            '笑声是慢慢停的，先是旁边的人，再是更外圈的人，'
            '等教授走过来的时候，已经没有人笑了。'
            '被放下来的那个人没有看你，'
            '也没有说谢谢——他这辈子都没跟你说过这两个字。'
            '但从此以后，他在你面前说话的时候，'
            '少了一点那股要刺你一下的劲儿。'
            '那一点，在他往后的人生里值很多东西。'
            '至于那个红头发的女生：她走过来，'
            '说了句"刚才那一下，谢谢"。就这一句，'
            '然后她去追那个被放下来的人了。'
            '她没有留下来跟你说话，'
            '而你知道她把这件事记住了。',
        echo: 'O.W.L. 考完那天你挤进了人群，喊来了教授。'
            '那个被倒吊的人一辈子没对你说过谢谢，'
            '但他此后在你面前，少了一点要刺你的劲儿。',
      ),
      CausalOption(
        id: 'standAside',
        text: '转身走开',
        action: '我看了一眼，转身从人群外沿走开了。',
        deviationDelta: -0.08,
        reputation: {'moral': -8, 'social': 4},
        attributes: {'courage': -5, 'caution': 4},
        consequence: '你走开了。'
            '身后的笑声没有停，一直到很晚才停。'
            '第二天再见到那个斯莱特林男生的时候，'
            '他看你的眼神跟看别人没有区别——'
            '他分不清你是走开的那个，还是笑的那个，'
            '对他来说都一样。'
            '那个红头发的女生也没有再提起这件事。'
            '她只是从此以后，对你客气了一些，'
            '而客气是一种距离。',
      ),
    ],
  ),

  // ==================== 一战·他倒了那一夜 ====================
  // 挂 fw_g6_nov_he_is_gone（1981 年 11 月）。
  //
  // "他倒了"本身是定数，玩家改不了。这一夜能改的是另一件事：
  // 消息是慢慢渗进来的，而你知道有一个人已经等了很久了——
  // 你去不去告诉他，以及你去的时候他在哪儿。
  CausalAnchor(
    anchorId: 'fw_g6_nov_he_is_gone',
    title: '告诉那个等了很久的人',
    minStage: WorldLineStage.diverging,
    era: 'first_war',
    setup: '消息还没有被宣布，但你手里已经有了确切的东西：'
        '一封拆开的信，或者一个刚从外面回来的人说的话。'
        '没有官方说法，可你知道这是真的。'
        '你也知道有一个人已经等了很久了——'
        '他等了整整十年，他家里的人死在那一年，'
        '他现在就在城堡里的某个地方。'
        '你要不要现在就去告诉他。',
    options: [
      CausalOption(
        id: 'intervene',
        text: '现在就去告诉他',
        action: '我拿着那封信，去找那个等了十年的人，当面告诉他。',
        deviationDelta: 0.10,
        // 做对了，但不是没有代价：这封信是私拆的，这个消息是抢在官方之前
        // 散出去的。事后有人说你造谣，也有人说你在抢风头——
        // 而"是他先说的"这句话，在往后的清算里会一直跟着你。
        reputation: {'moral': 8, 'social': -3, 'leadership': 4},
        attributes: {'courage': 5, 'caution': -3},
        impactDelta: 0.06,
        consequence: '你去了。'
            '他一个人在天文塔上——他最近总在那儿待着，'
            '说那里能看见猫头鹰来的方向。'
            '你把信递给他，他没有接，让你念。'
            '你念完了。'
            '他站在那里很久，久到你开始后悔来这一趟。'
            '然后他说了一句"好"。'
            '只说了这一个字，然后他转身下塔，'
            '走得很快，你跟都跟不上。'
            '后来你才知道，他那天夜里去了哪里、'
            '把这件事第一个告诉了谁。'
            '那封信是你拆的，那句话是你念的，'
            '于是这个消息传到她耳朵里的时候，'
            '中间隔的是你的名字，不是别人的。'
            '代价是另一回事：这封信是私拆的，'
            '这个消息是抢在官方之前散出去的。'
            '第二天全校都知道了，'
            '有人说你造谣，也有人说你在抢风头。'
            '往后的清算里，"就是他先说的"这句话'
            '一直跟在你名字后面。',
        echo: '「他倒了」的消息是你送到那个等了十年的人手里的。'
            '你在天文塔上把那封信念给他听，'
            '他只说了一个字：好。',
      ),
      CausalOption(
        id: 'standAside',
        text: '把信收起来',
        action: '我把信折好收进口袋，没有去找任何人。',
        deviationDelta: -0.06,
        reputation: {'moral': -6, 'social': 2},
        attributes: {'courage': -4, 'caution': 5},
        consequence: '你把信收起来了。'
            '第二天早上，全校都知道了。'
            '你后来在人群里看见他——'
            '他是笑着被人拍着肩膀的，'
            '只是那个笑一直没有到眼睛里。'
            '这件事你本来可以是第一个告诉他的。'
            '你没有，这也算是他等到的那个结局的一部分。',
      ),
    ],
  ),
];

/// 按事件锚点 id 找因果锚点；没有则返回 null。
CausalAnchor? causalAnchorFor(String anchorId) {
  for (final a in kCausalAnchors) {
    if (a.anchorId == anchorId) return a;
  }
  return null;
}

/// 该因果锚点在当前状态下是否解锁。
///
/// 三个条件同时满足：时代对得上、之前没做过、变动率够高。
bool isCausalAnchorUnlocked(
  CausalAnchor anchor, {
  required String era,
  required double deviation,
  required Set<String> decidedAnchorIds,
}) {
  if (anchor.era != null && anchor.era != era) return false;
  if (decidedAnchorIds.contains(anchor.anchorId)) return false;
  final cur = worldLineStageFor(deviation);
  return cur.index >= anchor.minStage.index;
}

/// 玩家真正改写过历史的那些痕迹（echo 列表）。
///
/// 从存档的 causalChoices 反查，按 kCausalAnchors 的定义顺序返回——
/// 也就是按原著时间线排，不依赖 Map 的迭代顺序。
///
/// 这个列表必须**每回合**都注入叙事 AI。少一次，AI 下一句就会
/// 照着原著把活人写死、把没发生的事写出来。
List<String> rewrittenEchoesOf(Map<String, String> causalChoices) {
  final out = <String>[];
  for (final a in kCausalAnchors) {
    final picked = causalChoices[a.anchorId];
    if (picked == null) continue;
    for (final o in a.options) {
      if (o.id == picked && o.echo.isNotEmpty) out.add(o.echo);
    }
  }
  return out;
}

/// 你在场、但选择了袖手旁观的关键节点。
///
/// 回望的时候这是单独一栏：被你改写过的事会跟着你，
/// 而你**看着它发生**的那些，同样是你用选择留下的形状。
/// 只记**你在场**的节点——没碰过的分歧点不写进来，
/// 否则「你什么都没做」会变成一长串流水账。
List<String> witnessedEchoesOf(Map<String, String> causalChoices) {
  final out = <String>[];
  for (final a in kCausalAnchors) {
    final picked = causalChoices[a.anchorId];
    if (picked == null) continue;
    for (final o in a.options) {
      if (o.id == picked && o.echo.isEmpty) out.add(a.title);
    }
  }
  return out;
}

/// 解析 `/抉择 <anchorId> <optionId>`，返回锚点与选项；非法则返回 null。
///
/// 抉择按钮的 action 就是这条指令——不能直接拿选项文本当玩家行动，
/// 因为那会绕过数值结算。
({CausalAnchor anchor, CausalOption option})? parseCausalCommand(
    String command) {
  final m =
      RegExp(r'^/抉择\s+(\S+)\s+(\S+)\s*$').firstMatch(command.trim());
  if (m == null) return null;
  final anchor = causalAnchorFor(m.group(1)!);
  if (anchor == null) return null;
  for (final o in anchor.options) {
    if (o.id == m.group(2)!) return (anchor: anchor, option: o);
  }
  return null;
}

/// 该锚点下所有带痕迹的选项（即玩家真正改写过历史的那些）。
List<CausalOption> interventionsOf(String anchorId) {
  final a = causalAnchorFor(anchorId);
  if (a == null) return const [];
  return a.options.where((o) => o.isIntervention).toList();
}

/// 还差多少变动率才能解锁；已解锁返回 0。
double deviationGapToUnlock(CausalAnchor anchor, double deviation) {
  final need = stageDefFor(anchor.minStage).minDeviation;
  final gap = need - deviation.clamp(0.0, 1.0);
  return gap <= 0 ? 0.0 : gap;
}
