/// P14 校园社团库：给「你属于什么」一条持续成长的线。
///
/// 前几层（节庆/奇遇/羁绊/宠物/来信）讲的是「发生在你身上的事」——它们来了又散，
/// 留不下一个持续的身份。本层补上「你属于什么」：加入一个社团，你的每次离线行动
/// 只要对得上社团的干系事，就为社团积累积分、逐级晋升（候补→活跃→骨干→王牌→
/// 传奇）。积分与晋升是**有因果、可积累**的成长引擎，把「长期做同一件事」变成实在
/// 的回报（属性/学院分/声望/同好的眼缘），也让玩家在城堡里多一个可归属的角落。
///
/// 四个社团，特色各有侧重：
///  - duel（决斗俱乐部）：以杖会友，打磨勇气与临场反应；加「反应速度/勇气」
///  - potion（魔药部）：坩埚里蒸腾耐心与精确；加「魔药学」
///  - broom（魁地奇队）：把心和扫帚交给同一种飞翔；加「飞行」与魁地奇技巧
///  - quip（快讯社）：把城堡里的新鲜事写进每一份快讯；加「社交/创造力」
///
/// 数据全收口在这里；mixin 只做「匹配行动 → 记分 → 跨阶发奖」三层事。
library;

/// 一个晋升阶的加成清单（可空）。
class ClubRankBonus {
  /// 属性 key（kAttributeLabels 里定义了中文名）；null 则表示本阶没有属性加成。
  final String? attrKey;
  final int attrValue;
  /// 声望维度（academic/social/combat/moral/leadership/dark）与数值；0 则不结算。
  final String? reputationDim;
  final int reputationValue;
  /// 晋升本阶随即获得的学院杯分（>0 才结算）。
  final int housePoints;
  /// 每晋升到本阶时追加一句值得回味的旁白（可带 `$club`、`$rank` 占位）。
  final String note;
  const ClubRankBonus({
    this.attrKey,
    this.attrValue = 0,
    this.reputationDim,
    this.reputationValue = 0,
    this.housePoints = 0,
    required this.note,
  });
}

/// 社团里的一个晋升阶。
class ClubRank {
  final String name; // 阶名：候补/活跃/骨干/王牌/传奇
  /// 晋升到本阶所需的**累计**社团积分（升到 bounds[0]=0 即初入）。
  final int points;
  final List<ClubRankBonus> bonuses;
  const ClubRank({
    required this.name,
    required this.points,
    this.bonuses = const [],
  });
}

/// 一个社团的定义。
class ClubDef {
  final String id;
  final String name;
  final String icon;
  final String tagline; // 一句话气质
  final String description; // 加入引导用的一段介绍
  /// 离线行动里出现这些词即视为「为社团出力」。
  final List<String> activityKeywords;
  /// 同好（成员 NPC 全名），用于氛围与入社旁白。
  final List<String> attendees;
  final List<ClubRank> ranks;

  const ClubDef({
    required this.id,
    required this.name,
    required this.icon,
    required this.tagline,
    required this.description,
    required this.activityKeywords,
    required this.attendees,
    required this.ranks,
  });

  /// 某积分落在第几阶（0 = 候补，等同在初入）。积分为负时钳到 0。
  int rankIndexFor(int points) {
    final p = points < 0 ? 0 : points;
    var idx = 0;
    for (var i = 0; i < ranks.length; i++) {
      if (p >= ranks[i].points) idx = i;
    }
    return idx;
  }
}

/// 查询某个社团；未知 id 返回 null。
ClubDef? clubById(String id) {
  for (final c in kClubs) {
    if (c.id == id) return c;
  }
  return null;
}

/// 社团文案占位符替换：`$club` → 社团名，`$rank` → 阶名。
String fillClubText(String text,
    {required String club, required String rank}) {
  return text.replaceAll(r'$club', club).replaceAll(r'$rank', rank);
}

/// 通用来信集合。
const List<ClubDef> kClubs = [
  // ==================== 决斗俱乐部 ====================
  ClubDef(
    id: 'duel',
    name: '决斗俱乐部',
    icon: '⚔️',
    tagline: '以杖会友，在交锋中打磨勇气',
    description:
        '塌陷而热烈的会堂里，魔杖相击声此起彼伏。这里不分出身，只看你敢不敢把'
        '自己推到对面那根魔杖面前。赢了见长，输了认栽——下次赢回来。',
    activityKeywords: ['切磋', '对战', '对练', '比试', '挑战对手', '决斗', '互练魔咒', '挥杖', '过招',
      // —— 2026-09-21 扩容（Bug 21）——原表只有精准子串，玩家写「和罗恩练练」「跟同学较量」
      // 「比划几下」「较量」「交手」「较劲」「单挑」「一对一」「对决」「演武」「比武」全部漏网。
      // 下面这些是同义或半字面变体，覆盖常见口语/剧本表述。注意刻意不放「训练」「练习」等
      // 太泛的词——那些会撞魁地奇/魔药的任务描述。
      '较量', '单挑', '对决', '交手', '较劲', '一对一对战', '一比一', '斗法', '炫技', '比杆'],
    attendees: ['西莫', '弗雷德', '乔治'],
    ranks: [
      ClubRank(
        name: '候补',
        points: 0,
        bonuses: [
          ClubRankBonus(
            attrKey: 'reaction_time',
            attrValue: 3,
            note: '你初入决斗俱乐部，第一次与人握杖行礼。有些笨拙，但你记住了那股紧绷的对峙感。\$club · \$rank：反应快了几分。',
          ),
        ],
      ),
      ClubRank(
        name: '活跃',
        points: 60,
        bonuses: [
          ClubRankBonus(
            attrKey: 'reaction_time',
            attrValue: 5,
            note: '你在 \$club 的交锋里渐渐站稳了脚跟——既能进招，也学会了收势。\$rank之姿，初见锋芒。',
          ),
        ],
      ),
      ClubRank(
        name: '骨干',
        points: 140,
        bonuses: [
          ClubRankBonus(
            attrKey: 'courage',
            attrValue: 8,
            note: '例行集会时，会长开始点头让你带新人对练。你这才发现，\$club 信任你了。\$rank，名副其实。',
          ),
        ],
      ),
      ClubRank(
        name: '王牌',
        points: 250,
        bonuses: [
          ClubRankBonus(
            attrKey: 'dda',
            attrValue: 10,
            housePoints: 5,
            note: '一场漂亮的胜仗后，\$club 的半边会堂都在喊你的名字。\$rank——你的魔杖，如今是别人会先掂量三分的。',
          ),
        ],
      ),
      ClubRank(
        name: '传奇',
        points: 260,
        bonuses: [
          ClubRankBonus(
            attrKey: 'reaction_time',
            attrValue: 15,
            reputationDim: 'combat',
            reputationValue: 2,
            housePoints: 10,
            note: '从未有人能像你这样，在 \$club 的铁证中从无名一路站到今天。\$rank。将来学弟学妹学起决斗，会先听到你的名字。',
          ),
        ],
      ),
    ],
  ),

  // ==================== 魔药部 ====================
  ClubDef(
    id: 'potion',
    name: '魔药部',
    icon: '🧪',
    tagline: '坩埚里蒸腾的是耐心与精确',
    description:
        '蒸汽缭绕的地下教室，福灵剂淡淡的香气盖不住坩埚的铁腥味。这里不讲究花哨'
        '的天赋，只认一根根搅棒划出的稳定弧线——大火会毁掉一锅药，沉稳则能救回它。',
    activityKeywords: ['熬制', '魔药', '药剂', '药材', '调制药水', '坩埚', '研磨', '试炼药',
      // —— 2026-09-21 扩容（Bug 21）——玩家写「练配」「调汤」「煮东西」「炼药」「调配」等
      // 都会漏网；补上动词变体 + 常见场景词。刻意不加「实验」这类太泛的词。
      '调配', '炼制', '炼药', '试药', '调汤', '熬药水', '煎药', '捣碎', '配料', '称量'],
    attendees: ['赫敏', '纳威', '西弗勒斯'],
    ranks: [
      ClubRank(
        name: '候补',
        points: 0,
        bonuses: [
          ClubRankBonus(
            attrKey: 'potions',
            attrValue: 3,
            note: '你端稳了第一只坩埚，学会了让火候在小火与中火之间停得恰到好处。\$club · \$rank：煮药是慢功夫，你学得进去。',
          ),
        ],
      ),
      ClubRank(
        name: '活跃',
        points: 60,
        bonuses: [
          ClubRankBonus(
            attrKey: 'potions',
            attrValue: 5,
            note: '你熬出的药剂开始有稳定的成色，\$club 的老成员愿意在熄火后跟你多聊两句配方。\$rank，够格。',
          ),
        ],
      ),
      ClubRank(
        name: '骨干',
        points: 140,
        bonuses: [
          ClubRankBonus(
            attrKey: 'observation',
            attrValue: 8,
            note: '部长把给新人的第一堂「看锅色」示范交给你来做。\$club 的锅边，从此多了一双替你盯着火的眼睛。\$rank 了。',
          ),
        ],
      ),
      ClubRank(
        name: '王牌',
        points: 250,
        bonuses: [
          ClubRankBonus(
            attrKey: 'potions',
            attrValue: 10,
            housePoints: 5,
            note: '你独立改良了一味配方，\$club 的锅边为此沸腾了一整晚。\$rank——在魔药的世界里，你的名字开始有人认真记下。',
          ),
        ],
      ),
      ClubRank(
        name: '传奇',
        points: 260,
        bonuses: [
          ClubRankBonus(
            attrKey: 'potions',
            attrValue: 15,
            reputationDim: 'academic',
            reputationValue: 2,
            housePoints: 10,
            note: '\$club 的传奇只有一行注脚：此人能把最不稳的药，熬出最稳的成色。\$rank。你在这里留下的，是锅边无数个深夜。',
          ),
        ],
      ),
    ],
  ),

  // ==================== 魁地奇队 ====================
  ClubDef(
    id: 'broom',
    name: '魁地奇队',
    icon: '🧹',
    tagline: '把心和扫帚交给同一种飞翔',
    description:
        '风在耳边呼啸，球场像一片倒悬的天空。这里没有第二名——要么把金色飞贼抓进'
        '手套，要么在整场欢呼里独自吞下懊悔。但训练里，你们始终是一队人。',
    activityKeywords: ['魁地奇', '练球', '追球', '扫帚', '球场', '飞行训练', '扑球', '金探子',
      // —— 2026-09-21 扩容（Bug 21）——玩家写「上了节飞行课」「合练半天」「找飞贼」
      // 「打比赛」都会漏网。补上同义/半字面变体 + 常见口语。刻意不加单独「飞行」（会撞日常），
      // 也不用「击剑」（不属本社团意象）。
      '合练', '队内', '上飞行课', '打比赛', '对抗赛', '热身', '起飞', '拉风箱', '空翻', '找飞贼'],
    attendees: ['奥利弗', '金妮', '罗恩'],
    ranks: [
      ClubRank(
        name: '候补',
        points: 0,
        bonuses: [
          ClubRankBonus(
            attrKey: 'flying',
            attrValue: 3,
            note: '你第一次跟 \$club 整队合练，风把刘海吹得东倒西歪，可你听清了队长喊你的名字。\$rank · 你开始属于这片天空。',
          ),
        ],
      ),
      ClubRank(
        name: '活跃',
        points: 60,
        bonuses: [
          ClubRankBonus(
            attrKey: 'reaction_time',
            attrValue: 5,
            note: '一场对抗训练里你稳稳接住了那个直奔你后脑勺的鬼飞球。\$club 的队友拍了拍你的肩：\$rank，有你的一席。',
          ),
        ],
      ),
      ClubRank(
        name: '骨干',
        points: 140,
        bonuses: [
          ClubRankBonus(
            attrKey: 'flying',
            attrValue: 8,
            note: '队长开始拿你的飞行当样板示范给新人。\$club 的战术版上，你的位置被画了一个圈。\$rank。',
          ),
        ],
      ),
      ClubRank(
        name: '王牌',
        points: 250,
        bonuses: [
          ClubRankBonus(
            attrKey: 'reaction_time',
            attrValue: 10,
            housePoints: 5,
            note: '一场拿下比赛的漂亮配合后，整座看台都在喊你的代号。\$club 的 \$rank——那种从空中俯冲而下的欢呼，你大概会记很久。',
          ),
        ],
      ),
      ClubRank(
        name: '传奇',
        points: 260,
        bonuses: [
          ClubRankBonus(
            attrKey: 'flying',
            attrValue: 15,
            reputationDim: 'leadership',
            reputationValue: 2,
            housePoints: 10,
            note: '你是 \$club 队史上少数能被称作 \$rank 的人。多年后的新生会在更衣室的墙影里，读到你这号的辉煌。天空，从此记住你的名字。',
          ),
        ],
      ),
    ],
  ),

  // ==================== 快讯社 ====================
  ClubDef(
    id: 'quip',
    name: '快讯社',
    icon: '🪶',
    tagline: '把城堡里的新鲜事写进每一份快讯',
    description:
        '想把「今晚幽灵又要开会」写成第一版头条的那类人，都挤在这间塞满墨水瓶的'
        '房间。真相要快、要准，还要写得让人想往下读。在这里，笔杆子就是魔杖。',
    activityKeywords: ['采访', '写稿', '新闻', '快讯', '投稿', '写作', '记录', '笔录',
      // —— 2026-09-21 扩容（Bug 21）——玩家写「搞一篇」「出个专题」「蹲现场」「做报道」
      // 「当记者」「采点料」都会漏网。补上动词变体 + 常见口语。刻意不加「打听」「传八卦」等
      // 负面/泛义词，避免撞普通社交行为。
      '报道', '专题', '选题', '稿件', '头版', '署名', '见报', '编辑', '跑新闻', '蹲守'],
    attendees: ['卢娜', '丽塔', '科林'],
    ranks: [
      ClubRank(
        name: '候补',
        points: 0,
        bonuses: [
          ClubRankBonus(
            attrKey: 'creativity',
            attrValue: 3,
            note: '你交出了在 \$club 的第一篇稿子，主编划掉一半又补了一句批注：「有点意思」。\$rank · 算是进门了。',
          ),
        ],
      ),
      ClubRank(
        name: '活跃',
        points: 60,
        bonuses: [
          ClubRankBonus(
            attrKey: 'social',
            attrValue: 5,
            note: '你学会在礼堂人群里三分钟问出别人一周都套不出来的话。\$club 的 \$rank——消息自己会往你耳朵里跑。',
          ),
        ],
      ),
      ClubRank(
        name: '骨干',
        points: 140,
        bonuses: [
          ClubRankBonus(
            attrKey: 'logic',
            attrValue: 8,
            note: '你的一篇稿子纠正了全校都在传的谣言。\$club 的主编把「事实重于热闹」这行字用红笔描了一遍。\$rank 了。',
          ),
        ],
      ),
      ClubRank(
        name: '王牌',
        points: 250,
        bonuses: [
          ClubRankBonus(
            attrKey: 'social',
            attrValue: 10,
            housePoints: 5,
            note: '你的署名开始被人主动打听。\$club 的 \$rank——你写下的每个字，在城堡里都有了分量。',
          ),
        ],
      ),
      ClubRank(
        name: '传奇',
        points: 260,
        bonuses: [
          ClubRankBonus(
            attrKey: 'social',
            attrValue: 15,
            reputationDim: 'social',
            reputationValue: 2,
            housePoints: 10,
            note: '你是 \$club 的活招牌，是只有 \$rank 才能被冠上的名号。多年后的人们翻开旧快讯，第一眼仍会找你的署名。',
          ),
        ],
      ),
    ],
  ),
];

/// 社团活动默认冷却（回合）：不会每个回合都因同一件事被反复点亮。
const int kClubCooldownTurns = 6;

/// 入社引导用的默认社团 id（/社团 无参数且未入社时第一个展示）。
const String kDefaultClubId = 'duel';
/// ==================== P15 跨回合社团任务 ====================
///
/// 让社团从「被动攒分」升级为「有目标地出力」：接取一条任务后，之后的离线
/// 回合只要做了与社团干系事相符的行动，任务进度就随之为社团出力而积累；
/// 攒够所需回合数后可回社团领奖（大额积分 + 属性奖励，不占用日常记分冷却）。
/// 每社 3 条任务，覆盖各自干系词的日常高频动作，接取后可随时放弃重选。

/// 社团任务模板。
class ClubTaskDef {
  final String id;
  final String clubId; // 所属社团 id
  final String title;
  final String desc; // 接取引导文案
  /// 完成后追加的一句旁白（可带 `$club` 占位）。
  final String rewardNote;
  /// 需要「为社团出力」的回合数（每次匹配干系事的行动推进 1 回合进度）。
  final int requiredRounds;
  /// 任务完成奖励：一次性大额社团积分（不触发跨阶发奖，直接入账）。
  final int clubPointsReward;
  /// 属性奖励（key + 值），null 表示无属性奖励。
  final String? attrKey;
  final int attrValue;
  const ClubTaskDef({
    required this.id,
    required this.clubId,
    required this.title,
    required this.desc,
    required this.rewardNote,
    required this.requiredRounds,
    required this.clubPointsReward,
    this.attrKey,
    this.attrValue = 0,
  });
}

/// 查询某社团的任务模板列表（按 id 稳定顺序）。
List<ClubTaskDef> clubTasksFor(String clubId) =>
    kClubTasks.where((t) => t.clubId == clubId).toList();

/// 按 id 查任务模板；未知返回 null。
ClubTaskDef? clubTaskById(String id) {
  for (final t in kClubTasks) {
    if (t.id == id) return t;
  }
  return null;
}

/// 全部社团任务模板。
const List<ClubTaskDef> kClubTasks = [
  // ============ 决斗俱乐部 ============
  ClubTaskDef(
    id: 'duel_ten_spars',
    clubId: 'duel',
    title: '十场切磋，站稳脚跟',
    desc: '会长要看看新人是不是三分钟热度。连续多日用切磋/对练在会堂里露面，攒够出力回合，证明你属于这里。',
    rewardNote: '会长当众点你的名：「这小子（姑娘）是块料。」\n你为 \$club 拿下一笔可观的积分，魔杖握得也更稳了。',
    requiredRounds: 4,
    clubPointsReward: 40,
    attrKey: 'reaction_time',
    attrValue: 5,
  ),
  ClubTaskDef(
    id: 'duel_newcomer_mentor',
    clubId: 'duel',
    title: '带新人对练',
    desc: '前辈把你叫到一边：给刚入社的几个新手喂招，让他们见识见识什么叫真正的对决。',
    rewardNote: '你带的新人在例行集会上赢下了人生第一场。\n他们喊你「师傅」时，你忽然懂了 \$club 为什么愿意把接力棒交到你手上。',
    requiredRounds: 5,
    clubPointsReward: 55,
    attrKey: 'courage',
    attrValue: 6,
  ),
  ClubTaskDef(
    id: 'duel_rep',
    clubId: 'duel',
    title: '为社团正名',
    desc: '外院的嘴碎到你头上：说决斗俱乐部只会花架子。去，用一场场硬仗让质疑闭嘴。',
    rewardNote: '你赢得漂亮。从此再没人敢说 \$club 是花架子——\n你的名字，成了会堂里的一根标杆。',
    requiredRounds: 6,
    clubPointsReward: 70,
    attrKey: 'dda',
    attrValue: 8,
  ),
  // ============ 魔药部 ============
  ClubTaskDef(
    id: 'potion_stable_pot',
    clubId: 'potion',
    title: '一锅稳定的药剂',
    desc: '部长说：魔药不在乎天赋，在乎「每一锅都一个样」。连续多日用熬制/研磨沉下心，把稳定性熬出来。',
    rewardNote: '你端出的药剂成色稳定得像从同一只坩埚倒出来的。\n部长难得点了点头：「\$club 要的就是这种手。」',
    requiredRounds: 4,
    clubPointsReward: 40,
    attrKey: 'potions',
    attrValue: 5,
  ),
  ClubTaskDef(
    id: 'potion_rare_brew',
    clubId: 'potion',
    title: '试炼一味稀有配方',
    desc: '部里的一味稀有配方没人敢碰——火候差一点就废。你来，用耐心把它熬出来。',
    rewardNote: '配方成了。\n那晚 \$club 的坩埚边围满了人，你亲手熬出的那锅药，成了部里的传说。',
    requiredRounds: 5,
    clubPointsReward: 55,
    attrKey: 'observation',
    attrValue: 6,
  ),
  ClubTaskDef(
    id: 'potion_herb_run',
    clubId: 'potion',
    title: '药材大采购',
    desc: '温室和药材商那里的货参差不齐。接下这门跑腿的活，把部里缺的药材备齐。',
    rewardNote: '药材齐了，部里接下来一个月的熬制都有了底气。\n你为 \$club 攒下的不只是分，还有一屋子人的人情。',
    requiredRounds: 6,
    clubPointsReward: 70,
    attrKey: 'herbology',
    attrValue: 8,
  ),
  // ============ 魁地奇队 ============
  ClubTaskDef(
    id: 'broom_daily_drill',
    clubId: 'broom',
    title: '风雨无阻的训练',
    desc: '队长说：状态是练出来的，不是等出来的。连续多日用练球/飞行训练打卡。',
    rewardNote: '队长在训练表上给你画了一排勾。\n「\$club 要的就是这种自觉。」他说。天空不会辜负准时起飞的人。',
    requiredRounds: 4,
    clubPointsReward: 40,
    attrKey: 'flying',
    attrValue: 5,
  ),
  ClubTaskDef(
    id: 'broom_catch_drill',
    clubId: 'broom',
    title: '追球手特训',
    desc: '找球手/追球手该有的眼力和手感，靠一次次扑球、追球磨出来。',
    rewardNote: '你在一次对抗里抓到了那颗「根本不可能抓到」的金探子。\n更衣室里，全队都朝你看过来。这一刻，你属于 \$club 的天空。',
    requiredRounds: 5,
    clubPointsReward: 55,
    attrKey: 'reaction_time',
    attrValue: 6,
  ),
  ClubTaskDef(
    id: 'broom_team_combo',
    clubId: 'broom',
    title: '与队友的默契',
    desc: '单人再强也赢不了比赛。连续多日跟队合练，把默契磨到不用喊也知道往哪飞。',
    rewardNote: '一场配合行云流水的训练赛后，队长拍了拍你的背：\n「\$club 的战术版上，永远有你的位置。」',
    requiredRounds: 6,
    clubPointsReward: 70,
    // 领导力不入属性表：本任务以「战术后勤」为主题，奖励走大额积分 + 逻辑层补声望
    attrKey: null,
    attrValue: 0,
  ),
  // ============ 快讯社 ============
  ClubTaskDef(
    id: 'quip_first_report',
    clubId: 'quip',
    title: '第一篇署名热稿',
    desc: '主编丢给你一张任务卡：连续多日采访/写稿，攒出一篇真正的热稿。',
    rewardNote: '你的稿件贴在快讯栏最显眼的位置，署名加粗。\n整个城堡都在传你写的那件事。\$club 的主编冲你扬了扬下巴。',
    requiredRounds: 4,
    clubPointsReward: 40,
    attrKey: 'social',
    attrValue: 5,
  ),
  ClubTaskDef(
    id: 'quip_fact_check',
    clubId: 'quip',
    title: '戳穿谣言',
    desc: '城堡里谣传满天飞。接下这个选题：连续多日做记录/调查，把真相挖出来。',
    rewardNote: '你的稿子让全校都在传的谣言一夜熄火。\n「事实重于热闹」这行字，主编第一次把它讲给别人听时，讲的是你。',
    requiredRounds: 5,
    clubPointsReward: 55,
    attrKey: 'logic',
    attrValue: 6,
  ),
  ClubTaskDef(
    id: 'quip_exclusive',
    clubId: 'quip',
    title: '独家头条',
    desc: '城堡里就要出大事了——你闻到了独家头条的味道。连续多日蹲守采访，把它拿下。',
    rewardNote: '独家头条，你的署名，全校都在读。\n主编说：\$club 的传奇只有一种写法——把别人都写不出来的事，写好。',
    requiredRounds: 6,
    clubPointsReward: 70,
    attrKey: 'creativity',
    attrValue: 8,
  ),
];
