/// P13 猫头鹰来信库：给「世界在动」补上身边人会留下的只言片语。
///
/// 现状：信只能由**玩家主动** `/信 寄` 发出，NPC 只在被联络时才回一封模板信。
/// 平时那些认识你的人——赫敏、罗恩、纳威、还有你那个总爱找茬的对手——像是
/// 从来不会主动想起你。本层让 NPC 在离线日常里偶尔给你寄来一只猫头鹰：
/// 不是发任务，也不是抢戏，而是像身边真的有人惦记着你——午后的一封闲聊，
/// 大病初愈后的挂念，乃至对手不请自来的挑衅。
///
/// 三类来信：
///   ① 友情来信（friendship）：门槛低、会重复，随寄信人对你的好感出现，暖场不做主角；
///   ② 敌对来信（rivalry）：由对你有怨气的对手寄来（会漏、会挖苦），也是「世界在动」的一角；
///   ③ 羁绊里程碑来信（milestone）：好感/关系跨过关键门槛时各演一次（演过不重播），
///      给一笔更实的分量，让「我在这个世界里不是孤身一人」这件事值得回想。
///
/// 部分来信带着问题与牵挂，会进入「待回信」：下一回合玩家可以真的回一封信，
/// 寄信人读罢再给你一段回应。数据全收口在这里；mixin 只做「选信 + 落款 + 结算」。
library;

// ==================== 信末效果 ====================

/// 一封信带来的结算（全部可选，0 = 不结算该项）。口径对齐奇遇/羁绊。
class LetterEffect {
  final int senderAffection; // 寄信人对你的好感变化（可为负，如挑衅）
  final int galleons;
  final int housePoints;
  final String? reputationDim; // academic/social/combat/moral/leadership/dark
  final int reputationValue;
  const LetterEffect({
    this.senderAffection = 0,
    this.galleons = 0,
    this.housePoints = 0,
    this.reputationDim,
    this.reputationValue = 0,
  });
}

/// 回信的一种选择：标题 + 寄信人读到后的回应 + 结算。
class LetterReply {
  final String title; // 选项标签（「回信道：…」）
  final String text; // 寄信人的回应（可带 `$sender` 占位）
  final LetterEffect effect;
  const LetterReply({
    required this.title,
    required this.text,
    this.effect = const LetterEffect(),
  });
}

enum LetterKind {
  friendship,
  rivalry,
  milestone,
  ministry,
  mystery,
  reunion,
}

/// 一封信。
class LetterDef {
  final String id;
  final LetterKind kind;
  final String? senderId; // 指定寄信人；null = 按品格从已结识 NPC 里挑一位

  /// 无 NPC 寄信人时的署名标签（魔法部/匿名等）；null = 用 NPC 名。
  ///
  /// `senderId == null && senderLabel != null` → 机构/匿名信（不查 NPC pool，
  /// 直接按冷却投递）；`senderId != null && senderLabel == null` → 走现有
  /// NPC 通道（含 reunion 放开 graduated）。
  final String? senderLabel;

  /// 仅在该月份可投递（1-12）；null = 任意月份。
  ///
  /// 用于魔法部公函等「学期节点」信（如 O.W.L.s 报名只在 5 月、禁林警告只在
  /// 9 月开学季），让机构信低频、不抢日常来信的戏。
  final int? month;
  /// 关联的社团 id（社长邀请信用；null = 与社团无关）。
  ///
  /// 非空时：① `maybeTriggerLetter` 只在玩家**未入该社**且对应社长好感达标时
  /// 投递；② 回信「好，我加入」选项会触发 `joinClub(clubId)` 直接入社。
  final String? clubId;

  /// 寄信人对你的好感下限（友情/里程碑用）。
  final int minAffection;

  /// 寄信人对你的好感上限（敌对来信用：好感不能太高）。
  final int? maxAffection;

  /// 是否一次性里程碑（演过不重播）。
  final bool onceOnly;

  /// 信件正文（可带 `$player`/`$sender`/`$house` 占位符）。
  final String scene;

  /// 收信即结算（默认为友情问候的小额好感）。
  final LetterEffect effect;

  /// 回信选项；空 = 无需回信（读罢即止）。
  final List<LetterReply> replies;
  const LetterDef({
    required this.id,
    required this.kind,
    this.senderId,
    this.senderLabel,
    this.month,
    this.clubId,
    this.minAffection = 0,
    this.maxAffection,
    this.onceOnly = false,
    required this.scene,
    this.effect = const LetterEffect(),
    this.replies = const [],
  });
}

/// 来信默认冷却（回合）：猫头鹰不会天天扑腾，隔一阵才来一封。
const int kLetterCooldownTurns = 9;

/// 回信动作前缀：action 形如 `信:<letterId>:<idx>`。
const String kLetterActionPrefix = '信:';

/// 按 id 查信。
LetterDef? letterById(String id) {
  for (final l in kLetters) {
    if (l.id == id) return l;
  }
  return null;
}

/// 占位符替换：`$player` → 玩家名，`$sender` → 寄信人，`$house` → 学院名。
String fillLetterText(String text,
    {required String player, required String sender, required String house}) {
  return text
      .replaceAll(r'$player', player)
      .replaceAll(r'$sender', sender)
      .replaceAll(r'$house', house);
}

// ==================== 来信集合 ====================

/// 通用来信集合。友情/敌对可重播；即 milestone==true 只演一次。
const List<LetterDef> kLetters = [
  // ====== 友情来信（会重播，寄信人 = 一位对你够好的朋友）======
  LetterDef(
    id: 'letter_dawdle',
    kind: LetterKind.friendship,
    minAffection: 25,
    scene:
        '午后的猫头鹰带来一封信，是 \$sender 的笔迹：\n'
        '「\$player！刚在图书馆打了个盹，梦见我们去年春天在禁林边聊到半夜。'
        '你最近都在忙什么呀？别总闷头念书，礼堂的南瓜汁今天特别甜，改天一起去坐坐。」',
    effect: LetterEffect(senderAffection: 1),
    replies: [
      LetterReply(
        title: '回一页长信，问问她近况',
        text: '\$sender 很快又寄来回信，字里行间满是欢喜：'
            '「你问我过得怎么样，我居然被问住了——原来这么久没人这么在意我了。'
            '谢谢你，\$player。我挺好，就是想你了。」',
        effect: LetterEffect(senderAffection: 2),
      ),
      LetterReply(
        title: '简短回一句「好，改天见」',
        text: '\$sender 的回信简短却轻快：'
            '「那就说定了。礼堂，周五，不见不散。你要是忘了，我就叫猫头鹰去你床头啄你。」',
        effect: LetterEffect(senderAffection: 1),
      ),
    ],
  ),
  LetterDef(
    id: 'letter_pick_gift',
    kind: LetterKind.friendship,
    minAffection: 35,
    scene:
        '一只猫头鹰在你窗台放下信，是 \$sender 写来的求助：\n'
        '「\$player，求帮忙拿个主意！快过节了，我想给家里寄点东西，'
        '可是蜂蜜公爵和风雅牌巫师服都快看好几天了还没定。你说，是甜甜的糖好，'
        '还是一件仔细挑过的衣服好？你眼光一向比我准。」',
    replies: [
      LetterReply(
        title: '回信劝她选甜美的心意',
        text: '\$sender 读罢你的回信，第二天便高兴地写信来：'
            '「就按你说的，挑了一盒最甜的糖夹进去。老觉得有你的主意，办事都踏实些。谢谢！」',
        effect: LetterEffect(senderAffection: 2),
      ),
      LetterReply(
        title: '回信劝她选用了心的衣服',
        text: '\$sender 的回信带着点不好意思：'
            '「你说得对，心意比花样重要。我已经把衣服包好寄出去了——'
            '下次拆礼物的人要是问是谁挑的，我可就说是你参谋的了。」',
        effect: LetterEffect(senderAffection: 2),
      ),
    ],
  ),
  LetterDef(
    id: 'letter_want_talk',
    kind: LetterKind.friendship,
    minAffection: 45,
    scene:
        '夜深了，一只猫头鹰轻轻落在你床头，送来 \$sender 的信：\n'
        '「\$player，其实没什么正事。就是今天突然很想找个人说说话，'
        '想来想去，第一个想到的竟是你。要是你也有这样的时候——客厅壁炉边上，'
        '我给你留了位置，还有热腾腾的黄油啤酒。」',
    replies: [
      LetterReply(
        title: '回信说「我这就来」',
        text: '收到回信后，\$sender 在壁炉边等你等到蜡烛烧短了半截，'
            '见你信里那句「我这就来」，她悄悄把给你那杯黄油啤酒又温了一遍：'
            '「你这个人啊，就是让人没法不惦记。」',
        effect: LetterEffect(senderAffection: 3),
      ),
      LetterReply(
        title: '回信说夜深了，改天见',
        text: '\$sender 的回信没有怨你：'
            '「好，那改天。位置我给你留着——不急，我一直都在。」',
        effect: LetterEffect(senderAffection: 1),
      ),
    ],
  ),

  // ====== 羁绊里程碑来信（演过不重播）======
  LetterDef(
    id: 'letter_first_owl',
    kind: LetterKind.milestone,
    minAffection: 30,
    onceOnly: true,
    scene:
        '这是你在这个世界收到的**第一封**朋友的信。猫头鹰的翅膀在你窗前'
        '扑棱得有些笨拙，\$sender 的笔迹落在羊皮纸上，生涩而郑重：\n'
        '「\$player：字写得不好，你别笑话我。我就是想让你知道——'
        '从今天起，会有人记得给你写信的。无论晴天雨天，你在霍格沃茨都不是一个人。」',
    effect: LetterEffect(
        senderAffection: 4, reputationDim: 'social', reputationValue: 1),
    replies: [
      LetterReply(
        title: '好好收藏这第一封信',
        text: '你把信纸抚平，夹进了最贴身的课本里。\$sender 得知后，'
            '害羞得连课都不好意思看你：但这道友谊的钩子，算是结结实实地系住了。',
        effect: LetterEffect(senderAffection: 2),
      ),
      LetterReply(
        title: '立刻回一封同样认真的信',
        text: '你当晚也认认真真回了一封。几只猫头鹰在你俩的窗口间扑腾了一整夜，'
            '\$sender 读着读着便笑了：「原来你写字也不比我好到哪儿去。」'
            '——但那天夜里，你们谁也没舍得先睡。',
        effect: LetterEffect(senderAffection: 3),
      ),
    ],
  ),
  LetterDef(
    id: 'letter_gratitude_saved',
    kind: LetterKind.milestone,
    minAffection: 50,
    onceOnly: true,
    effect: LetterEffect(
        senderAffection: 4, reputationDim: 'social', reputationValue: 1),
    scene:
        '一只腿上缠着细绳的猫头鹰送来 \$sender 的一封长信，墨迹深浅不一，像是写写停停'
        '纠结了很久：\n'
        '「\$player：有件事我一直没认真说过——那天要不是你在，我都不知道该怎么办。'
        '你知道的，我嘴笨，当面说不出口，只能写在纸上。你要是哪天需要我，'
        '我赴汤蹈火也来。这句话我认。」',
    replies: [
      LetterReply(
        title: '回信说「我记得，也谢谢你」',
        text: '\$sender 读着你的回信，久久没说话，最后把信叠好贴身收着：'
            '「这世上的谢，我们就算清啦。往后你就是我这边的人。」',
        effect: LetterEffect(senderAffection: 3),
      ),
      LetterReply(
        title: '回信说「朋友之间不用说谢」',
        text: '\$sender 的笑声仿佛隔着纸也能传来：'
            '「行啊你，还挺会说话。那就照你说的——不言谢，互相罩。」',
        effect: LetterEffect(senderAffection: 2),
      ),
    ],
  ),
  LetterDef(
    id: 'letter_after_big_day',
    kind: LetterKind.milestone,
    minAffection: 65,
    onceOnly: true,
    effect: LetterEffect(
        senderAffection: 3, reputationDim: 'social', reputationValue: 1),
    scene:
        '那件让你日思夜想的大事落定后的第一个黄昏，猫头鹰衔来 \$sender 的信，'
        '纸角还残留着一股淡淡的草药香（她的衣袖不小心蹭上去的）：\n'
        '「\$player：我知道你现在多半心绪翻涌。别急着一个人扛——'
        '我在图书馆后排的老位子上等你。你有话，我听着；你没话，我就陪你坐着。」'
        '信末添了一行小字：「带了你最爱的奶糖。」',
    replies: [
      LetterReply(
        title: '回信「那就见一面」',
        text: '暮色里，你们坐在图书馆老位子上，谁也没多说话。'
            '\$sender 把那包奶糖推到你手边，全程安静。等你想开口时，她已经先替你拨了一颗：'
            '「先吃东西，再说。」',
        effect: LetterEffect(
            senderAffection: 3, reputationDim: 'social', reputationValue: 1),
      ),
      LetterReply(
        title: '回信说想一个人静静，但谢她惦记',
        text: '你谢了她的好意，\$sender 没有追问，只轻声托猫头鹰带回一句：'
            '「好。位置我给你留着，你什么时候想来了，奶糖我随时补。」',
        effect: LetterEffect(senderAffection: 1),
      ),
    ],
  ),
  LetterDef(
    id: 'letter_dream',
    kind: LetterKind.milestone,
    minAffection: 80,
    onceOnly: true,
    effect: LetterEffect(
        senderAffection: 4, reputationDim: 'social', reputationValue: 1),
    scene:
        '一个失眠的夜里，\$sender 的信不期而至，字迹竟有些轻促：\n'
        '「\$player：我做了个梦，梦见我们在漫长的走廊里走散了，我喊你的名字，'
        '却怎么也追不上。惊醒后我盯着天花板看了很久——还好那只是梦。'
        '我不常把这些写给任何人，但一想到你，还是想让你知道。晚安。」',
    replies: [
      LetterReply(
        title: '回信说「醒醒，我一直都在」',
        text: '第二天清晨，\$sender 的猫头鹰比太阳还早地落在你窗前，'
            '信只有一行：「收到。那我不是一个人了。」字里行间，比昨夜安稳许多。',
        effect: LetterEffect(senderAffection: 4),
      ),
      LetterReply(
        title: '回信说「梦是反的，我会找到你」',
        text: '\$sender 读罢你的回信，在信的背面画了个小小的方向标，指向你们常去的地方：'
            '「那下次换我去找你也行。」一缕浅浅的笑意，隔着纸都藏不住。',
        effect: LetterEffect(
            senderAffection: 4, reputationDim: 'moral', reputationValue: 1),
      ),
    ],
  ),

  // ====== 敌对来信（会重播，寄信人 = 一位对你有怨气的对手）======
  LetterDef(
    id: 'letter_taunt',
    kind: LetterKind.rivalry,
    maxAffection: 0,
    scene:
        '一只羽毛油亮的猫头鹰趾高气昂地丢下一封信，落款是 \$sender。'
        '纸上的字迹张扬得快要飞出格子：\n'
        '「\$player，听说你最近挺得意？提醒你一句——这城堡里多得是没正眼看你这种'
        '出身的人。别太把自己当回事，省得到时候难看。」',
    effect: LetterEffect(senderAffection: -1),
    replies: [
      LetterReply(
        title: '回一句不卑不亢的话',
        text: '你的回信短而稳，\$sender 读过半响，在底下重重画了一道杠，'
            '再没多写一个字——但那只猫头鹰第二回送信时，羽毛似乎没那么油亮了。',
        effect: LetterEffect(
            senderAffection: 0, reputationDim: 'leadership', reputationValue: 1),
      ),
      LetterReply(
        title: '不理会，把信折成纸飞机',
        text: '你把信叠成纸飞机，让它顺着风飞出窗外。\$sender 迟迟没等来你的回音，'
            '那副气哼哼等着吵架的样子，反而先蔫了。',
        effect: LetterEffect(senderAffection: 0),
      ),
    ],
  ),
  LetterDef(
    id: 'letter_dare',
    kind: LetterKind.rivalry,
    maxAffection: 0,
    scene:
        '一封封口处涂了封蜡的信被猫头鹰丢在你桌上，落款 \$sender：\n'
        '「\$player，敢不敢下个周末在钟楼底下比一场？你要是个有种的家伙就应战，'
        '要是个只会缩在朋友身后的软蛋，就当没收到这封信。」',
    replies: [
      LetterReply(
        title: '回信应战，坦然赴约',
        text: '钟楼底下，\$sender 没想到你当真来了，愣了一瞬，随即扬起下巴：'
            '「哼，倒是有点胆子。」那场比试不论输赢，你俩互怼的劲儿，倒莫名齐了三分。',
        effect: LetterEffect(
            senderAffection: 2, reputationDim: 'combat', reputationValue: 2),
      ),
      LetterReply(
        title: '回信说「激将法对我没用」',
        text: '你的冷静让 \$sender 一时语塞。他在回信里憋了半天，只挤出一句：'
            '「……行吧，你还有点意思。」虽然是挑事的开头，倒也算认识了个不打不相识。',
        effect: LetterEffect(senderAffection: 1),
      ),
    ],
  ),

  // ====== 魔法部公函（机构来信，无 NPC 落款，按学期节点各一次） ======
  LetterDef(
    id: 'letter_ministry_owls',
    kind: LetterKind.ministry,
    senderLabel: '魔法部·考试管理局',
    month: 5,
    onceOnly: true,
    scene:
        '一只系着靛蓝封印的猫头鹰穿过蒙蒙晨雾，把一封印着魔法部纹章的公函丢在你面前：\n'
        '「\$player：经霍格沃茨魔法学校教务处转呈，兹通知你——'
        '本学年 O.W.L.s 普通巫师等级考试报名将于近期截止。'
        '请你尽快与你的院长确认报名科目，逾期不候。'
        '（考试成绩将载入个人魔法档案。）\n'
        '——魔法部·考试管理局」',
    effect: LetterEffect(housePoints: 5),
    replies: [
      LetterReply(
        title: '回函确认报名',
        text: '你当天就把回函交给了院长。几天后，一封盖章的公函又落到你桌上：'
            '「已收到你的报名确认。预祝你取得好成绩。」——信封里还夹着一张考试须知，'
            '墨水未干，透着公事公办的温度。',
        effect: LetterEffect(housePoints: 3),
      ),
      LetterReply(
        title: '先收起来，回头再看',
        text: '你把公函夹进课本里。魔法部的猫头鹰没再追着问——'
            '但那份须知上的截止日期，像只不紧不慢的猫头鹰，总会在最恰当的时候想起来。',
        effect: LetterEffect(reputationDim: 'academic', reputationValue: 1),
      ),
    ],
  ),
  LetterDef(
    id: 'letter_ministry_forbidden',
    kind: LetterKind.ministry,
    senderLabel: '魔法部·神奇动物管理控制司',
    month: 9,
    onceOnly: true,
    scene:
        '一支深绿色的猫头鹰信使在你窗台上站定，落下一封印着「禁林」字样的公函：\n'
        '「\$player：近期禁林边缘多次出现未经申报的夜游活动。'
        '为保障师生安全，禁林夜间通行需提前申报。情节严重者，本司将致函学校处理。'
        '\n——魔法部·神奇动物管理控制司」',
    replies: [
      LetterReply(
        title: '回信说「我会注意的」',
        text: '你给魔法部回了一封简短而礼貌的信。对方没有再多说——'
            '但打那以后，禁林边巡逻的脚步声，似乎听得更清楚了。',
        effect: LetterEffect(reputationDim: 'moral', reputationValue: 1),
      ),
      LetterReply(
        title: '把信叠好收进抽屉',
        text: '你没有回信，只把公函收进抽屉。那张警告沉甸甸地压在纸堆底下，'
            '像一扇未上锁的门，等你某天自己决定要不要推开。',
        effect: LetterEffect(reputationDim: 'dark', reputationValue: 1),
      ),
    ],
  ),

  // ====== 神秘信件（匿名，低概率彩蛋，onceOnly） ======
  LetterDef(
    id: 'letter_mystery_riddle',
    kind: LetterKind.mystery,
    senderLabel: '匿名的寄信人',
    onceOnly: true,
    scene:
        '深夜，一只羽毛漆黑的猫头鹰无声无息地落在窗台，留下一封没有署名的信，'
        '纸角微微发黄，墨迹却像是刚写下：\n'
        '「\$player：\n'
        '  当你读到这行字时，我在某个你看不见的地方。\n'
        '  城堡没有秘密，只有还没被发现的走廊。\n'
        '  别告诉任何人你收到过这封信。\n'
        '  ——一个知道你在找什么的人」',
    replies: [
      LetterReply(
        title: '回信问「你是谁」',
        text: '你的回信寄出后，石沉大海。只是在三天后的夜里，窗台上又多了张字条，'
            '只有一句话：「名字不重要。重要的是——你还在找吗？」',
        effect: LetterEffect(reputationDim: 'dark', reputationValue: 2),
      ),
      LetterReply(
        title: '把信烧掉，当作没看见',
        text: '火苗舔过纸角，那行字在灰烬里蜷成一只模糊的猫头鹰形状。'
            '你在烟雾里愣了两秒，随即把它抛到脑后——可那句话，总在你不经意时浮起来。',
        effect: LetterEffect(reputationDim: 'observant', reputationValue: 1),
      ),
    ],
  ),

  // ====== 毕业旧友重联（reunion，可重播，需有已毕业 NPC） ======
  LetterDef(
    id: 'letter_reunion_old_friend',
    kind: LetterKind.reunion,
    minAffection: 10,
    scene:
        '一只腿上绑着旧式信筒的猫头鹰落在你窗边，落款是那个早已毕业、'
        '去了远方的人：\n'
        '「\$player：\n'
        '  我在遥远的城市安顿下来了，窗台上养了一盆家乡的草药，'
        '  每次给它浇水，都会想起霍格沃茨温室里那股潮湿的泥土味。'
        '  听说你还在城堡里。真好。\n'
        '  要是哪天你路过，记得写信告诉我，你过得怎么样。\n'
        '  ——\$sender」',
    replies: [
      LetterReply(
        title: '回一封信，说说近况',
        text: '你的回信寄出没多久，\$sender 的信又追了过来，字里行间藏不住的欢喜：'
            '「你还记得我家的邮编？太好了——这封信够我高兴半个月。」'
            '隔着山川，友谊的线重新接上了。',
        effect: LetterEffect(senderAffection: 3),
      ),
      LetterReply(
        title: '简短回一句「我挺好的」',
        text: '\$sender 的回信同样简短，却透着踏实：'
            '「那就好。你那边风吹雨打的，记得照顾好自己——'
            '我的门，永远给你留着。」',
        effect: LetterEffect(senderAffection: 1),
      ),
    ],
  ),
  // ====== 社长邀请信（来信→社团，friendship + clubId；未入社且好感达标才投） ======
  LetterDef(
    id: 'letter_club_duel_invite',
    kind: LetterKind.friendship,
    senderId: 'seamus',
    clubId: 'duel',
    minAffection: 20,
    scene:
        '一只猫头鹰衔着皱巴巴的羊皮纸落在你肩头，展开一看是 \$sender 的笔迹，'
        '字迹里带着决斗场上的那股爽利：\n'
        '「\$player！听弗雷德说你也爱把自己推到对面那根魔杖面前——'
        '这话我爱听。决斗俱乐部从来不分出身，只看你敢不敢站上来。'
        '下周四晚，会堂见。赢了咱们喝黄油啤酒，输了咱再练。'
        '——你要是没想好，先来观战也成。」',
    effect: LetterEffect(senderAffection: 2),
    replies: [
      LetterReply(
        title: '好，我加入决斗俱乐部',
        text: '\$sender 收到你的回信，高兴得当场和人比了一场：'
            '「我就知道你没看走眼！会堂的门永远给你开着——'
            '来，先跟我过两招，让你试试手感。」',
        effect: LetterEffect(senderAffection: 5),
      ),
      LetterReply(
        title: '我再想想',
        text: '\$sender 的回信没有半分催促：'
            '「成，不着急。会堂的门一直开着，你什么时候想来，我都备着好魔杖。」',
        effect: LetterEffect(senderAffection: 2),
      ),
    ],
  ),
  LetterDef(
    id: 'letter_club_potion_invite',
    kind: LetterKind.friendship,
    senderId: 'hermione',
    clubId: 'potion',
    minAffection: 20,
    scene:
        '一封写得整整齐齐的信躺在你窗台，信封角压着一点干燥的月长石粉，'
        '是 \$sender 的笔迹：\n'
        '「\$player：魔药部这周要熬一锅缓和剂，正好缺个稳得住火候的搭档。'
        '你上次在课堂上坩埚搅得又稳又准，我记着呢。'
        '地下教室，周四下午。来之前把《高级魔药制作》第三章翻一遍，'
        '我保证不会让你帮倒忙——这话也只对你说。」',
    effect: LetterEffect(senderAffection: 2),
    replies: [
      LetterReply(
        title: '好，我加入魔药部',
        text: '\$sender 的回信带着一丝藏不住的雀跃：'
            '「太好了！我这就把本周的配方抄一份给你——'
            '放心，跟着我熬，不会让你炸坩埚的。」',
        effect: LetterEffect(senderAffection: 5),
      ),
      LetterReply(
        title: '我再想想',
        text: '\$sender 的回信依旧不急不缓：'
            '「也好，不勉强。坩埚的盖子我给你留着——哪天想来，提前说一声就行。」',
        effect: LetterEffect(senderAffection: 2),
      ),
    ],
  ),
  LetterDef(
    id: 'letter_club_broom_invite',
    kind: LetterKind.friendship,
    senderId: 'wood',
    clubId: 'broom',
    minAffection: 20,
    scene:
        '一只气势十足的猫头鹰把信用力丢在你桌上，展开是 \$sender 那龙飞凤舞的字：\n'
        '「\$player！我看过你在飞行课上的表现——追上那记游走球的样子，'
        '像个天生的找球手。魁地奇队最近在招新人，风里雨里，我只要敢飞的。'
        '周六清晨，球场，别迟到。要是怕早，我带你认认扫帚。」',
    effect: LetterEffect(senderAffection: 2),
    replies: [
      LetterReply(
        title: '好，我加入魁地奇队',
        text: '\$sender 的回信短而有力：'
            '「说定了！周六六点，球场。队里多了个敢抓飞贼的，'
            '我这个队长脸上也有光。」',
        effect: LetterEffect(senderAffection: 5),
      ),
      LetterReply(
        title: '我再想想',
        text: '\$sender 的回信依旧干脆：'
            '「不急。球场一直在那儿，你什么时候想飞，我都在。」',
        effect: LetterEffect(senderAffection: 2),
      ),
    ],
  ),
  LetterDef(
    id: 'letter_club_quip_invite',
    kind: LetterKind.friendship,
    senderId: 'luna',
    clubId: 'quip',
    minAffection: 20,
    scene:
        '一封画着歪歪扭扭猫头鹰的信，叠成纸飞机的形状落在你手心，'
        '是 \$sender 的笔迹：\n'
        '「\$player，你知道吗，快讯社缺一个能把城堡里那些小秘密写成头条的人。'
        '我总觉得你能看见别人看不见的东西——那种感觉，比新闻更重要。'
        '要是你愿意，墨水瓶和羽毛笔我都给你备好了。信写得好不好不重要，'
        '重要的是你愿意看见。」',
    effect: LetterEffect(senderAffection: 2),
    replies: [
      LetterReply(
        title: '好，我加入快讯社',
        text: '\$sender 的回信轻快得像风：'
            '「我就知道你会来。从今天起，城堡里那些被忽略的小事，'
            '都有人把它们写下来了。」',
        effect: LetterEffect(senderAffection: 5),
      ),
      LetterReply(
        title: '我再想想',
        text: '\$sender 的回信依旧轻盈：'
            '「没关系，世界不会因此少一个看见它的人——'
            '你什么时候想写，笔都在。」',
        effect: LetterEffect(senderAffection: 2),
      ),
    ],
  ),
  // ====== 羁绊预热信（来信→羁绊，milestone；好感接近 P11 门槛时触发） ======
  LetterDef(
    id: 'letter_warmup_hermione',
    kind: LetterKind.milestone,
    senderId: 'hermione',
    minAffection: 15,
    onceOnly: true,
    scene:
        '深夜，一只猫头鹰轻轻落在你床头，留下一封字迹工整的信：\n'
        '「\$player：说来奇怪，今天整理旧书的时候，翻到我们去年在图书馆那次'
        '为了一道变形术争到闭馆的笔记。那页纸角还留着你的涂鸦。'
        '有时候我会想，一个人能记得另一个人多久呢？'
        '——大概像我记得你这么久。\n'
        '                          \$sender」',
    effect: LetterEffect(senderAffection: 2),
    replies: [
      LetterReply(
        title: '回信说「我也记得」',
        text: '\$sender 读罢你的回信，隔天在走廊遇见你时，'
            '破天荒没有谈功课，只轻轻说了句：「那页笔记，我夹在最喜欢的书里了。」',
        effect: LetterEffect(senderAffection: 3),
      ),
      LetterReply(
        title: '回信说「别说这么肉麻的话」',
        text: '\$sender 的回信带着一点恼：'
            '「我那是陈述事实，不是肉麻。……不过，收到你的信，我还是高兴的。」',
        effect: LetterEffect(senderAffection: 2),
      ),
    ],
  ),
  LetterDef(
    id: 'letter_warmup_harry',
    kind: LetterKind.milestone,
    senderId: 'harry',
    minAffection: 20,
    onceOnly: true,
    scene:
        '黄昏时，一只灰色猫头鹰把信塞进你窗缝。字迹有点潦草，'
        '像赶着写下的：\n'
        '「\$player：今天训练完在球场边坐了一会儿，突然想起你上次'
        '和我们一起躲在走廊转角，躲过费尔奇那次——你笑得比我们还大声。'
        '说实话，在霍格沃茨，能让你真正笑出来的人不多。'
        '我想，你是其中一个。\n'
        '                          \$sender」',
    effect: LetterEffect(senderAffection: 2),
    replies: [
      LetterReply(
        title: '回信说「那次确实好笑」',
        text: '\$sender 的回信简短，却透着熟悉的热乎劲儿：'
            '「对吧！下次费尔奇巡楼，还带你一个。」',
        effect: LetterEffect(senderAffection: 3),
      ),
      LetterReply(
        title: '回信说「有空一起去球场坐坐」',
        text: '\$sender 的回信干脆利落：'
            '「说定了。周六下午，球场看台。我带黄油啤酒。」',
        effect: LetterEffect(senderAffection: 2),
      ),
    ],
  ),
  // ====== 内容扩容（r10）：新来信条目 ======
  // 神秘信件 +2（低概率彩蛋，onceOnly）
  LetterDef(
    id: 'letter_mystery_mirror',
    kind: LetterKind.mystery,
    senderLabel: '匿名的寄信人',
    onceOnly: true,
    scene:
        '一只没有标记的深灰色猫头鹰在深夜落在窗台，信纸的边缘'
        '微微发着珍珠般的光：\n'
        '「镜子里的那个你，今天有没有做过一件让 TA 骄傲的事？'
        '如果一时想不起来——明天还来得及。』',
    effect: LetterEffect(reputationDim: 'moral', reputationValue: 1),
    replies: [
      LetterReply(
        title: '在回信里写下一件小事',
        text:
            '你鬼使神差地回了信，写了一件白天的小事。信送出去的瞬间'
            '化成了点点银光。当晚镜子里的你，看起来精神了很多。',
        effect: LetterEffect(reputationDim: 'moral', reputationValue: 2),
      ),
      LetterReply(
        title: '把信锁进抽屉',
        text:
            '你把信收进抽屉最深处。之后每次拉开抽屉，那行字都还在——'
            '不催促，也不消失。直到某天你终于想起来了，信才安静地淡去。',
        effect: LetterEffect(),
      ),
    ],
  ),
  LetterDef(
    id: 'letter_mystery_map_corner',
    kind: LetterKind.mystery,
    senderLabel: '匿名的寄信人',
    onceOnly: true,
    scene:
        '一封信从《霍格沃茨一段校史》的书页间滑落。信纸上只画了'
        '一幅手绘小地图：从你的学院公共休息室出发，七个转弯，'
        '一扇挂着一个坏掉的门环的门。地图背面写着：'
        '「门后没有宝物，只有一段安静的时光。」',
    effect: LetterEffect(),
    replies: [
      LetterReply(
        title: '按图索骥走一趟',
        text:
            '七个转弯之后，那扇门真的在。门后是一间堆满旧坐垫的小阳台，'
            '正对着黑湖。你在那里坐了一个下午，什么都没做，'
            '却觉得比整个学期都放松。',
        effect: LetterEffect(),
      ),
      LetterReply(
        title: '把地图夹回书里',
        text:
            '有些秘密就该留在原地。你把地图夹回原来的书页。'
            '很多年后重读这本书时，地图还在——像一句等了很久的问候。',
        effect: LetterEffect(reputationDim: 'dark', reputationValue: 1),
      ),
    ],
  ),
  // 魔法部公函 +1（学期节点）
  LetterDef(
    id: 'letter_ministry_apparition',
    kind: LetterKind.ministry,
    senderLabel: '魔法部·交通管理局',
    month: 10,
    onceOnly: true,
    scene:
        '一封印着金色门钥纹章的公函扑棱棱落在早餐桌上：\n'
        '「\$player：年满十七岁的巫师可报名幻影显形训练课程。'
        '虽然你现在可能还够年纪——但提前了解 split（分裂）的风险，'
        '总比在关键时刻依赖门钥要好。课程简章见附件。'
        '——魔法部·交通管理局」',
    effect: LetterEffect(housePoints: 2),
    replies: [
      LetterReply(
        title: '认真读完简章并收好',
        text:
            '你逐行读完了幻影显形的三大注意事项，把简章夹进笔记本。'
            '「目的地，决心，从容」——这三个词你记了很久。',
        effect: LetterEffect(reputationDim: 'academic', reputationValue: 2),
      ),
      LetterReply(
        title: '叠成纸飞机扔给同学',
        text:
            '公函在空中划出一道弧线，精准命中邻座的后脑勺。'
            '全班哄笑，教授没收了纸飞机——但考试周前，'
            '它被原样还给了你，附一句「学好再扔」。',
        effect: LetterEffect(reputationDim: 'social', reputationValue: 1),
      ),
    ],
  ),
  // 友情来信 +1
  LetterDef(
    id: 'letter_friend_rain_day',
    kind: LetterKind.friendship,
    minAffection: 25,
    scene:
        '下雨的傍晚，一只湿漉漉的小猫头鹰顶着一层雨水冲进窗，'
        '信纸用防水墨水写的：\n'
        '「\$player：这种天气最适合缩在休息室烤火。'
        '你要是在打瞌睡，那这封信就当替你赶走梦里的克鲁克山。'
        '——\$sender」',
    effect: LetterEffect(senderAffection: 1),
    replies: [
      LetterReply(
        title: '回信邀请TA来烤火',
        text:
            '半小时后，\$sender 真的出现在休息室门口，抖了抖'
            '斗篷上的雨珠。两人就着炉火聊到晚钟响，'
            '雨天忽然变得很短。',
        effect: LetterEffect(senderAffection: 2),
      ),
      LetterReply(
        title: '回信抄一句打油诗',
        text:
            '你的打油诗把 \$sender 逗得不行，回信只有一行：'
            '「建议投稿《唱唱反调》，署名我认识的那位诗人。」',
        effect: LetterEffect(senderAffection: 2),
      ),
    ],
  ),
  // 敌对来信 +1（挖苦向，可缓和）
  LetterDef(
    id: 'letter_rival_quidditch_loss',
    kind: LetterKind.rivalry,
    minAffection: 0,
    maxAffection: 0,
    scene:
        '一只傲慢的 鹰头马身有翼兽 羽信使把信丢在你脚边就飞走了。'
        '字迹尖刻：\n'
        '「\$player：听说你们学院上周的训练赛输得很彻底。'
        '我不意外，只是想确认一下——你还会出现在下一场吗？'
        '——一个你熟悉的对手」',
    effect: LetterEffect(),
    replies: [
      LetterReply(
        title: '回信：「会，而且会赢」',
        text:
            '对方没再回信。但下一次训练赛你在场上看到了那张熟悉的脸——'
            '它只是来看你比赛的。这大概是对手能给出的最高尊重。',
        effect: LetterEffect(senderAffection: 2),
      ),
      LetterReply(
        title: '回信：「你这么关心我？」',
        text:
            '回信只有三个字：「少自恋。」——但字迹比平时潦草，'
            '像是写得太快。怨气的坚冰上，裂开了一条小小的缝。',
        effect: LetterEffect(senderAffection: 3),
      ),
    ],
  ),
  // ====== 内容扩容第三批（+6）======
  LetterDef(
    id: 'letter_mystery_sweets_note',
    kind: LetterKind.mystery,
    senderLabel: '匿名的祝福者',
    onceOnly: true,
    scene:
        '清晨醒来，枕边多了一小袋巧克力蛙和一张没有署名的字条，'
        '字迹清秀得刻意：「收藏巧克力蛙画片的人，运气不会太差。'
        '下次画片重复的时候，试试看把它送给需要它的人。」',
    effect: LetterEffect(),
    replies: [
      LetterReply(
        title: '把字条收进抽屉最里层',
        text:
            '你把字条折好收进抽屉。奇怪的是，那之后的画片，'
            '张张都是你没见过的新款——像是有什么人在暗处悄悄替你排好了一切。',
        effect: LetterEffect(senderAffection: 1),
      ),
      LetterReply(
        title: '在公共休息室大声念出字条',
        text:
            '没人承认是自己写的。但当晚你听见有人在小声笑，'
            '而第二天，你的糖罐满了——有人说「神秘人」的品味一向不差。',
        effect: LetterEffect(senderAffection: 2),
      ),
    ],
  ),
  LetterDef(
    id: 'letter_mystery_library_book',
    kind: LetterKind.mystery,
    senderLabel: '五十年前的借书人',
    onceOnly: true,
    scene:
        '你借的那本《高阶魔药解析》里，夹着一张泛黄的借书卡，'
        '最早一栏的日期是五十年前，借阅人签名被墨水晕开，隐约是个名字的开头。'
        '卡片背面用铅笔写着一行小字：「第七章的配方是错的，别照着做。」',
    effect: LetterEffect(),
    replies: [
      LetterReply(
        title: '翻到第七章仔细核对',
        text:
            '果然——第七章的月相表少印了一行。你用铅笔补上，'
            '又在卡片背面添了一句「已修正，谢谢五十年前的你」，把书放回书架。',
        effect: LetterEffect(senderAffection: 1),
      ),
      LetterReply(
        title: '把借书卡交给平斯夫人',
        text:
            '平斯夫人眯着眼看了很久，忽然说：「这孩子的重孙现在就在楼上学业办公室。'
            '要替你传个话吗？」一周后，一张崭新的手抄正确配方出现在你的床头上。',
        effect: LetterEffect(senderAffection: 2),
      ),
    ],
  ),
  LetterDef(
    id: 'letter_friend_shared_scarf',
    kind: LetterKind.friendship,
    minAffection: 40,
    scene:
        '\$sender 来信，信纸上有淡淡的花香：「降温了，听说你总是忘带围巾。'
        '我多织了一条——别嫌弃针脚歪，第一次织。黑色和你的校袍最配。'
        '系上的时候想想：有人在惦记你暖不暖。」',
    effect: LetterEffect(senderAffection: 2),
    replies: [
      LetterReply(
        title: '立刻围上新围巾回信道谢',
        text:
            '你把围巾裹得严严实实去上课。回信写：「针脚一点都不歪，'
            '歪的是我——看完信差点把眼泪掉在羊皮纸上。谢谢。」',
        effect: LetterEffect(senderAffection: 3),
      ),
      LetterReply(
        title: '回赠一罐蜂蜜公爵的太妃糖',
        text:
            '随包裹寄去的字条只有一句：「织围巾的手，值得吃点甜的。」'
            '后来你发现她把糖纸都细心抚平了，夹在课本里当书签。',
        effect: LetterEffect(senderAffection: 2),
      ),
    ],
  ),
  LetterDef(
    id: 'letter_reunion_old_professor',
    kind: LetterKind.reunion,
    scene:
        '一封用蜡封口的信送到你手上，落款是你一年级时的某位任课教授：'
        '「整理旧物时翻到你的课堂笔记——写得潦草，却全是好问题。'
        '教书这些年，好问题比好答案稀有得多。若你在城堡里遇到难解之事，'
        '我的办公室的门仍未上锁。」',
    effect: LetterEffect(),
    replies: [
      LetterReply(
        title: '登门拜访，带上那本旧笔记',
        text:
            '教授翻着笔记笑出了声：「这一页你把我的板书抄错了，我居然现在才看出来。」'
            '那天下午你听了很多课堂之外的事，离开时办公室的门在你身后虚掩着——确实没锁。',
        effect: LetterEffect(senderAffection: 2),
      ),
      LetterReply(
        title: '回信致谢，暂不多扰',
        text:
            '回信只有短短几行：「等我遇到配得上那扇门的问题，一定来。」'
            '回信来得很快，只有四个字：「一言为定。」',
        effect: LetterEffect(senderAffection: 1),
      ),
    ],
  ),
  LetterDef(
    id: 'letter_rival_lost_badge',
    kind: LetterKind.rivalry,
    maxAffection: 0,
    scene:
        '字条是从你的书上滑落的，字迹凌厉：「你的学院徽章掉在魔药课教室了。'
        '在我手里。别指望我白还——下个月的对决练习，敢不敢来？'
        '赢了，徽章还你；输了，就承认我是第一。」',
    effect: LetterEffect(),
    replies: [
      LetterReply(
        title: '回信应战：「到时候见」',
        text:
            '对决练习那天，徽章被打磨得锃亮，摆在场地中央。'
            '你赢了。对方把徽章抛给你时说：「下个月再来。别让我等太久。」',
        effect: LetterEffect(senderAffection: 3),
      ),
      LetterReply(
        title: '回信：「徽章送你了，胸口的位子有限」',
        text:
            '对方的回信只有一行字，却写了又划、划了又写：「……那这个我收着。'
            '等哪天你想要回去，就凭本事来拿。」',
        effect: LetterEffect(senderAffection: 2),
      ),
    ],
  ),
  LetterDef(
    id: 'letter_ministry_license',
    kind: LetterKind.ministry,
    senderLabel: '魔法部魔法执行司',
    month: 3,
    onceOnly: true,
    scene:
        '魔法部的牛皮信封里是一份表格：《未成年人魔杖使用许可·年度复核》。'
        '末尾附了一页手写的补充说明：「复核通过。另：你的年度魔杖保养记录'
        '填写得比大多数成年巫师都认真。保持下去，孩子。」',
    effect: LetterEffect(),
    replies: [
      LetterReply(
        title: '把补充说明小心收好',
        text:
            '官方文件被你贴身收着。那行字你读了好几遍——在魔法部，'
            '被记住名字的感觉，比盖章本身更难得。',
        effect: LetterEffect(senderAffection: 1),
      ),
      LetterReply(
        title: '回函申请一份保养手册副本',
        text:
            '你在回函里附了一句「想把手册也借给同寝室的人看」。'
            '批复下来时寄了两份，附言：「好东西就该多传几双手。」',
        effect: LetterEffect(senderAffection: 2),
      ),
    ],
  ),
];