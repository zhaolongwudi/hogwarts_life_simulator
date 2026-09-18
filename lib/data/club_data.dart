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
    activityKeywords: ['切磋', '对战', '对练', '比试', '挑战对手', '决斗', '互练魔咒', '挥杖', '过招'],
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
        points: 400,
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
    activityKeywords: ['熬制', '魔药', '药剂', '药材', '调制药水', '坩埚', '研磨', '试炼药'],
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
        points: 400,
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
    activityKeywords: ['魁地奇', '练球', '追球', '扫帚', '球场', '飞行训练', '扑球', '金探子'],
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
        points: 400,
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
    activityKeywords: ['采访', '写稿', '新闻', '快讯', '投稿', '写作', '记录', '笔录'],
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
        points: 400,
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