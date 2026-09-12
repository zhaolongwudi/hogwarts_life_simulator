/// 原著剧情节点库（离线模式事件源）。
///
/// 【与 event_anchors.dart 的分工——别把两者混为一谈】
///
/// | 维度 | `EventAnchor` | `CanonEvent`（本文件） |
/// | --- | --- | --- |
/// | 性质 | **学年日历骨架**：每年按月份复现 | **原著时间线**：七部小说的一次性大事 |
/// | 例子 | 开学宴、万圣节、期末考、圣诞 | 密室开启、三强争霸、天文塔之夜 |
/// | 触发键 | `月份 + 年级 + 时代` | `年份 + 月份 + 时代` |
/// | 复现 | 每个学年可再触发一次（`@年级` 后缀） | **全域仅一次**（`canon_` 前缀） |
/// | 消费者 | `_checkEventAnchors`（AI 与离线共用） | `_runOfflineQuickTurn`（离线叙事拼装） |
///
/// 为什么要单独建一张表而不是往 `EventAnchor` 里塞：`EventAnchor` 的
/// `fixedOnlyOnce` 语义是「每学年一次」，而原著大事是「整个存档一次」。
/// 混在一起会让 1991 年发生过的密室事件在 1992 年又冒出来。
///
/// 【平行世界原则——本文件最容易犯的错】
/// 玩家是**原创角色**，不是哈利。原著事件必须写成「发生在你周围」，
/// 不能让玩家成为哈利。这条约束由 `test/canon_events_test.dart` 里的
/// 禁用措辞扫描守住（见该文件 `_forbiddenProtagonistPhrases`）。
/// 写法对照：
///   ❌ 「你在密室里举剑刺向蛇怪」      —— 玩家成了哈利
///   ✅ 「学校里流传着石化事件的消息，走廊巡逻加倍」 —— 事件在周围发生
///
/// 【版权说明】本文件只描述**剧情节点与氛围**，不抄录原著原文句子。
library;

/// 一条原著剧情节点。
class CanonEvent {
  final String id;

  /// 原著故事内年份（1991 = 哈利入学那年）。
  final int year;

  /// 触发月份（1-12）。
  final int month;

  /// 玩家需在的年级；null = 不限年级。
  ///
  /// 用途：有些事件对所有在校生都构成背景（如三强争霸全校围观），
  /// 有些只对特定年级有直接关联。
  final int? grade;

  /// 适用时代（`EraDef.eraKey`）。目前原著主线只有子世代。
  final List<String> eras;

  /// 标题（通知栏与存档记录用）。
  final String title;

  /// 注入给叙事的指令。
  ///
  /// 写作要求：
  ///   1. 旁观者视角（"你听说/你注意到/学校因此…"），禁止让玩家成为事件主角；
  ///   2. 2~3 句，具体到可被叙事 AI 或离线拼装直接使用；
  ///   3. 提供**玩家可行动的接口**（如"你可以打听消息/避开某处"），
  ///      否则离线模式下玩家只能读不能动。
  final String directive;

  /// 出处标注（如「魔法石」），便于溯源与维护。
  final String bookRef;

  const CanonEvent({
    required this.id,
    required this.year,
    required this.month,
    this.grade,
    this.eras = const ['harry_same'],
    required this.title,
    required this.directive,
    required this.bookRef,
  });
}

/// 原著主线是否适用于该时代。
///
/// 1892（少年邓布利多）/ 1971（亲世代）/ 1976（第一次战争）各有自己的
/// 时代锚点（见 `event_anchors.dart` 尾部），**不能**套子世代的剧情线——
/// 那时候密室还没开、伏地魔还没出生。
bool eraHasCanonTimeline(String era) => era == 'harry_same';

/// 七部小说的剧情节点时间线。
///
/// 年份对应原著故事内年份：1991-92 是哈利与玩家共同的一年级，
/// 依此类推到 1997-98 的七年级（《死亡圣器》）。
const List<CanonEvent> canonEvents = [
  // ================================================================
  // 《魔法石》 1991-1992（一年级）
  // ================================================================
  CanonEvent(
    id: 'canon_ps_sorting',
    year: 1991,
    month: 9,
    grade: 1,
    title: '入学与分院',
    bookRef: '魔法石',
    eras: ['harry_same'],
    directive:
        '霍格沃茨特快在九月一日午后抵达霍格莫德车站，一年级新生由海格领着'
        '乘船渡过黑湖，第一次望见山丘上的城堡。大礼堂里四张长桌旁挤满老生，'
        '天花板上是一片星空，新生们一个接一个被叫上前戴上分院帽。'
        '你会在这一夜被分入某个学院，成为这所学校的一部分。',
  ),
  CanonEvent(
    id: 'canon_ps_gringotts',
    year: 1991,
    month: 7,
    title: '古灵阁被闯入',
    bookRef: '魔法石',
    eras: ['harry_same'],
    directive:
        '《预言家日报》头版报道古灵阁最深处的一间金库在七月底被人试图闯入，'
        '凶手至今在逃，妖精们拒绝对外解释金库里到底存了什么。'
        '对角巷的店铺都在议论这件事——有人说那间金库是空的，也有人说里面「有过东西」。'
        '你可以在开学采购时听到这些传闻，也可以选择不以为意。',
  ),
  CanonEvent(
    id: 'canon_ps_troll',
    year: 1991,
    month: 10,
    grade: 1,
    title: '万圣节巨怪闯入',
    bookRef: '魔法石',
    eras: ['harry_same'],
    directive:
        '万圣节晚宴进行到一半，奇洛教授冲进大礼堂喊了一声「巨怪——在地下教室」后昏倒。'
        '邓布利多让各学院级长立刻带队回公共休息室。走廊里到处是乱跑的学生，'
        '你听见低年级生哭喊着说看见「比人还高」的东西。'
        '当晚的消息是：教工把巨怪处理了，没有人受重伤。你可以跟随队伍撤离，也可以趁乱多看一眼。',
  ),
  CanonEvent(
    id: 'canon_ps_quidditch_first',
    year: 1991,
    month: 11,
    title: '第一场魁地奇比赛',
    bookRef: '魔法石',
    eras: ['harry_same'],
    directive:
        '格兰芬多对斯莱特林的第一场魁地奇赛季赛在今天举行。'
        '看台上挤满了人，斯莱特林那边的横幅写着嘲讽的话。'
        '比赛中途出了一点怪事——看台上有议论说格兰芬多的找球手差点从扫帚上摔下来，'
        '有人咬定「那把扫帚被人施了咒」。你可以去球场观赛，也可以在赛后打听传闻。',
  ),
  CanonEvent(
    id: 'canon_ps_christmas_mirror',
    year: 1991,
    month: 12,
    title: '厄里斯魔镜的传闻',
    bookRef: '魔法石',
    eras: ['harry_same'],
    directive:
        '圣诞假期留校生很少。城堡里有传闻说，八楼一间废弃教室里放着一面很古怪的镜子，'
        '「照见的东西会让你不想离开」。管理员费尔奇最近格外频繁地在夜里巡查那一层。'
        '你可以试着找到那间教室，也可以选择遵守熄灯后不得离寝的规定。',
  ),
  CanonEvent(
    id: 'canon_ps_forbidden_forest',
    year: 1992,
    month: 3,
    title: '禁林里的独角兽',
    bookRef: '魔法石',
    eras: ['harry_same'],
    directive:
        '有学生在禁林边缘发现了受伤的独角兽，还有人说林子里「有什么东西在喝它的血」。'
        '海格最近几次半夜带着猎犬进林子，回来时脸色不太好看。'
        '教工要求学生近期一律不得独自靠近禁林。你可以向海格打听，也可以远远观望。',
  ),
  CanonEvent(
    id: 'canon_ps_year_end',
    year: 1992,
    month: 6,
    grade: 1,
    title: '一年级期末与学院杯',
    bookRef: '魔法石',
    eras: ['harry_same'],
    directive:
        '学年临近结束，学院杯的分数在最后几场比赛后才真正拉开差距。'
        '大礼堂的年终宴会上，四位学院的旗帜悬挂在长桌上方，'
        '邓布利多会在宴会上宣布最终名次并给今年「做出特别贡献」的学生加分。'
        '回顾你自己这一年的成长，教授或同学可能会对你做出具体评价。',
  ),

  // ================================================================
  // 《密室》 1992-1993（二年级）
  // ================================================================
  CanonEvent(
    id: 'canon_cos_chamber_open',
    year: 1992,
    month: 9,
    grade: 2,
    title: '密室被打开了',
    bookRef: '密室',
    eras: ['harry_same'],
    directive:
        '开学不久，城堡里就传开了一个让人不安的消息：有人宣称「密室已经被打开了」。'
        '走廊的墙上、公告板上出现了用血写的字迹，费尔奇不得不连夜清理。'
        '年纪大的学生开始给新生讲五十年前那桩旧事——据说那次也死过人。'
        '你可以向高年级生打听那段历史，也可以留意走廊里异常的动静。',
  ),
  CanonEvent(
    id: 'canon_cos_petrification',
    year: 1992,
    month: 11,
    title: '石化事件',
    bookRef: '密室',
    eras: ['harry_same'],
    directive:
        '学校里出现了第一起被「石化」的学生——有人被发现在走廊里僵直不动，'
        '像是被冻在了一瞬间。庞弗雷夫人说她「没有死，只是被石化了」，'
        '但没人知道怎么解除。随后又有猫与更多学生遇袭，学生们开始结伴行动，'
        '不敢单独走走廊。你可以选择结伴、避开某些楼层，或者去医疗翼打听情况。',
  ),
  CanonEvent(
    id: 'canon_cos_dueling_club',
    year: 1992,
    month: 12,
    title: '决斗俱乐部',
    bookRef: '密室',
    eras: ['harry_same'],
    directive:
        '洛哈特教授宣布成立「决斗俱乐部」，在大礼堂亲自示范缴械咒，'
        '并邀请斯内普教授做对手——结果被一击缴械。'
        '学生们随后两两配对练习，现场一片混乱，有人放出蛇、有人受了伤。'
        '你对这场闹剧的看法，以及是否认真练到东西，由你自己决定。',
  ),
  CanonEvent(
    id: 'canon_cos_diary',
    year: 1993,
    month: 2,
    title: '日记本的传闻',
    bookRef: '密室',
    eras: ['harry_same'],
    directive:
        '学校里流传着一个说法：那本「出事前被人捡到的旧日记」可能和密室有关。'
        '有学生说见过一本能自己写字的本子，也有人认定这只是有人在传谣。'
        '你可以试着追查这条线索，也可以只管做好自己的期末准备。',
  ),

  // ================================================================
  // 《阿兹卡班的囚徒》 1993-1994（三年级）
  // ================================================================
  CanonEvent(
    id: 'canon_poa_escape',
    year: 1993,
    month: 8,
    title: '阿兹卡班越狱事件',
    bookRef: '阿兹卡班的囚徒',
    eras: ['harry_same'],
    directive:
        '《预言家日报》报道了一个爆炸性消息：阿兹卡班有囚犯越狱，'
        '据说他是神秘人的追随者，当年被判终身监禁。'
        '麻瓜的晚间新闻也在播报「有逃犯在逃，请居民锁好门窗」。'
        '你可以在开学前就从家里听到这消息，也可以到校后再听同学们议论。',
  ),
  CanonEvent(
    id: 'canon_poa_dementors',
    year: 1993,
    month: 9,
    title: '摄魂怪进驻',
    bookRef: '阿兹卡班的囚徒',
    eras: ['harry_same'],
    directive:
        '摄魂怪被派驻在霍格沃茨各入口与霍格莫德村一带，负责搜捕越狱的逃犯。'
        '它们经过时空气会骤然变冷，人会被吸走快乐、想起最糟糕的回忆。'
        '校医提醒学生随身带巧克力以备不适，校长则明确要求所有人不得靠近湖畔的摄魂怪。'
        '你可以开始认真考虑学一个守护神咒，也可以尽量绕开它们的巡逻路线。',
  ),
  CanonEvent(
    id: 'canon_poa_hogsmeade',
    year: 1993,
    month: 11,
    grade: 3,
    title: '第一次去霍格莫德',
    bookRef: '阿兹卡班的囚徒',
    eras: ['harry_same'],
    directive:
        '三年级学生这学期被允许在周末前往霍格莫德村。'
        '村里到处是巫师店铺：糖果店、酒吧、笑话店、邮局，'
        '还有传闻中「闹鬼」的尖叫棚屋就在村外山坡上。'
        '你可以趁这个周末去村里逛一逛，也可以听同学讲那栋房子当年的故事。',
  ),
  CanonEvent(
    id: 'canon_poa_buckbeak',
    year: 1994,
    month: 4,
    title: '鹰头马身有翼兽事件',
    bookRef: '阿兹卡班的囚徒',
    eras: ['harry_same'],
    directive:
        '保护神奇生物课上出了一件事：一头鹰头马身有翼兽伤了学生，'
        '随后被判定有危险，即将面临处置听证。海格为此几乎崩溃。'
        '学生之间开始联名请愿，也有人认为「课堂纪律本来就没抓好」。'
        '你可以选择签字、去陪海格，或者认为这件事与自己无关。',
  ),

  // ================================================================
  // 《火焰杯》 1994-1995（四年级）
  // ================================================================
  CanonEvent(
    id: 'canon_gof_announce',
    year: 1994,
    month: 9,
    title: '三强争霸赛重启',
    bookRef: '火焰杯',
    eras: ['harry_same'],
    directive:
        '邓布利多在开学宴上宣布：中断了两百多年的三强争霸赛将在今年恢复，'
        '霍格沃茨将与布斯巴顿、德姆斯特朗两校同场竞技。'
        '一条年龄线将被画在火焰杯前——未满十七岁的学生不得报名。'
        '整个城堡的气氛一下子被点燃，人人都在谈论谁会被选中当勇士。',
  ),
  CanonEvent(
    id: 'canon_gof_champions',
    year: 1994,
    month: 10,
    title: '勇士名单公布',
    bookRef: '火焰杯',
    eras: ['harry_same'],
    directive:
        '万圣节夜，火焰杯选出了三位勇士。但在众人以为仪式结束时，'
        '火焰杯竟又吐出一张名单，诞生了**第四位**勇士，全场哗然。'
        '两所学校的学生认为霍格沃茨作弊，本校学生也觉得其中有问题。'
        '你可以选择相信官方说法、加入质疑者，或者单纯当一个看客。',
  ),
  CanonEvent(
    id: 'canon_gof_yule_ball',
    year: 1994,
    month: 12,
    title: '圣诞舞会',
    bookRef: '火焰杯',
    eras: ['harry_same'],
    directive:
        '作为三强争霸赛的传统一环，圣诞舞会将在圣诞节当晚举行，'
        '四年级以上学生可以参加，也可以邀请低年级学生作为舞伴。'
        '城堡被装饰得格外隆重，学生们提前几周就在紧张地考虑邀约对象。'
        '你可以试着邀请某人，也可以选择和朋友们一起去看看热闹。',
  ),
  CanonEvent(
    id: 'canon_gof_maze',
    year: 1995,
    month: 6,
    title: '第三个项目：迷宫',
    bookRef: '火焰杯',
    eras: ['harry_same'],
    directive:
        '三强争霸赛的第三个项目在魁地奇球场举行，赛场被改造成一片高墙迷宫。'
        '三位勇士（以及那位意外入选的第四位）在观众注视下进入迷宫。'
        '比赛结束后，学校里弥漫着一种说不清的紧张——有传言说'
        '决赛当晚出了大事，但校方对外只说「有一位参赛者受了伤」。'
        '你可以去关注官方公告，也可以向消息灵通的同学打听。',
  ),

  // ================================================================
  // 《凤凰社》 1995-1996（五年级）
  // ================================================================
  CanonEvent(
    id: 'canon_ootp_return',
    year: 1995,
    month: 9,
    title: '五年级开学·战时气氛',
    bookRef: '凤凰社',
    eras: ['harry_same'],
    directive:
        '新学期在紧张气氛中开始：返校的列车上加强了守卫，'
        '《预言家日报》连续多日把哈利·波特与校长描绘成「制造恐慌的人」，'
        '而学生们私下里更愿意相信另一种说法。'
        '这一年有学生要参加普通巫师等级考试（O.W.L.），课业压力本就沉重，'
        '加上校内外的不确定，整个城堡的气氛与往年很不一样。',
  ),
  CanonEvent(
    id: 'canon_ootp_umbridge',
    year: 1995,
    month: 8,
    title: '魔法部接管霍格沃茨',
    bookRef: '凤凰社',
    eras: ['harry_same'],
    directive:
        '魔法部通过了一项教育令，派出一名高级副部长进驻霍格沃茨担任「高级调查官」。'
        '她一上任就连发数道教育令，禁止学生集会、禁止教师谈论「未经批准」的话题，'
        '并开始逐个听课考核教授。教师们明显不满，但表面上仍要配合。'
        '你可以选择低调行事，也可以暗中继续和同学交流真正有用的东西。',
  ),
  CanonEvent(
    id: 'canon_ootp_da',
    year: 1995,
    month: 10,
    title: '秘密学习小组',
    bookRef: '凤凰社',
    eras: ['harry_same'],
    directive:
        '由于黑魔法防御术课变成了纯理论背诵，学生们开始私下组织练习小组，'
        '在有求必应屋一类的地方偷偷练实用的防御咒。'
        '组织者要求参与者签署保密协议，一旦被发现，后果可能很严重。'
        '你可以选择加入、自己找人练，或者干脆不掺和。',
  ),
  CanonEvent(
    id: 'canon_ootp_ministry_battle',
    year: 1996,
    month: 6,
    title: '神秘事务司之战',
    bookRef: '凤凰社',
    eras: ['harry_same'],
    directive:
        '学期末，霍格沃茨发生了一场震动全校的事件：一伙学生深夜离开城堡，'
        '魔法部地下发生了一场激烈的战斗，有凤凰社成员与食死徒参与，'
        '甚至有人目击了「神秘人」本人露面——尽管部里起初拒不承认。'
        '随后部里终于公开承认他回来了。你可以去听校长在学期末的说明，'
        '也可以和同学们讨论这一切意味着什么。',
  ),

  // ================================================================
  // 《混血王子》 1996-1997（六年级）
  // ================================================================
  CanonEvent(
    id: 'canon_hbp_return',
    year: 1996,
    month: 9,
    title: '六年级返校',
    bookRef: '混血王子',
    eras: ['harry_same'],
    directive:
        '新学期开始，学生们在国王十字车站登上特快。'
        '车站月台上多了不少巡逻的傲罗，家长们的告别比往年更长。'
        '有同学低声说，今年可能有人不会回来了——因为家里不放心。'
        '城堡里多了几道新的防护咒，入学通知上也第一次附了安全须知。',
  ),
  CanonEvent(
    id: 'canon_hbp_malfoy_task',
    year: 1996,
    month: 10,
    title: '城堡里弥漫的不安',
    bookRef: '混血王子',
    eras: ['harry_same'],
    directive:
        '新学期开始后，城堡外的袭击事件时有传闻，霍格莫德也加强了守卫。'
        '校内气氛明显紧绷：有学生家长打算把孩子接走，'
        '也有人注意到几位高年级学生的行为变得反常、频繁出入某些楼层。'
        '你可以留意这些异常，也可以把注意力放回自己的学业与关系上。',
  ),
  CanonEvent(
    id: 'canon_hbp_potions_book',
    year: 1996,
    month: 11,
    title: '一本旧课本',
    bookRef: '混血王子',
    eras: ['harry_same'],
    directive:
        '魔药学课上，有学生拿到了一本写满边注的旧课本，'
        '书上署名「混血王子」，其中的窍门让持有者成绩突飞猛进。'
        '有人怀疑这是作弊，也有人认为这只是前人留下的笔记。'
        '你可以去打听这本书的来历，也可以专注自己的实验。',
  ),
  CanonEvent(
    id: 'canon_hbp_astronomy_tower',
    year: 1997,
    month: 6,
    title: '天文塔之夜',
    bookRef: '混血王子',
    eras: ['harry_same'],
    directive:
        '学年末的夜里，天文塔方向发生了大事：食死徒闯入了城堡，'
        '校长在天文塔上遭遇袭击并殒命，许多学生亲眼目睹了塔顶的绿光，'
        '也有人在混乱中看见马尔福被带离。全校陷入震动与哀悼，'
        '学年提前结束，期末考试被取消。你可以参加随后的悼念，'
        '也可以和同学讨论这场灾难会把霍格沃茨带向何方。',
  ),

  // ================================================================
  // 《死亡圣器》 1997-1998（七年级）
  // ================================================================
  CanonEvent(
    id: 'canon_dh_last_year',
    year: 1997,
    month: 9,
    title: '最后一个学期·风声鹤唳',
    bookRef: '死亡圣器',
    eras: ['harry_same'],
    directive:
        '这一年开学与往年截然不同：站台上少了送行的家长，多了穿黑袍的检查者。'
        '返校的学生被逐个核对身份，有几位同学始终没有出现在名单上——'
        '有人说他们「不方便再来」，也有人说他们已经被带走了。'
        '开学宴上换了一张新面孔主持秩序，他宣布了几条此前从未有过的新规矩。'
        '你可以选择尽量不引人注意，也可以暗中留意这些规矩的边界在哪里。',
  ),
  CanonEvent(
    id: 'canon_dh_fall',
    year: 1997,
    month: 8,
    title: '霍格沃茨被控制',
    bookRef: '死亡圣器',
    eras: ['harry_same'],
    directive:
        '开学前，魔法部已被彻底渗透，霍格沃茨换了新的管理班子：'
        '两位曾经的教授接管校务，学校开始强制推行血统审查，'
        '麻瓜出身的巫师被要求「证明」自己的家世。'
        '校内成立了告密性质的巡查队，学生们彼此警惕。'
        '这是一个需要你谨慎选择立场与言行的年份。',
  ),
  CanonEvent(
    id: 'canon_dh_underground',
    year: 1997,
    month: 11,
    title: '地下的反抗',
    bookRef: '死亡圣器',
    eras: ['harry_same'],
    directive:
        '尽管处境艰难，仍有学生在有求必应屋一类的地方维持着一个地下组织，'
        '收留被追查的同学、传递外界消息、帮忙藏匿。'
        '参与者都知道一旦被发现代价极大。你可以提供帮助、保持沉默，'
        '或者干脆只求保全自己——每条路都会影响你在这个学年里的处境。',
  ),
  CanonEvent(
    id: 'canon_dh_final_battle',
    year: 1998,
    month: 5,
    title: '大决战',
    bookRef: '死亡圣器',
    eras: ['harry_same'],
    directive:
        '五月初，城堡被围，保卫方与进攻方在城堡内外展开了一场大战：'
        '石像被唤醒参战、走廊里到处是咒语的光、禁林方向传来巨人的脚步，'
        '许多过往的同学与老师从各地赶回。战斗持续了一夜，'
        '破晓时分，伏地魔本人出现在大礼堂前——随后被彻底击败。'
        '魔法世界在那一刻终结了一场持续多年的战争。'
        '你可以选择参与防守、疏散低年级，或在安全处见证这一切，'
        '但无论如何，这一夜都会成为你霍格沃茨生涯的终点。',
  ),
];

/// 命中的原著节点（先按年份，再按月份的先后顺序）。
///
/// [year] 传 `GameTime.year`；[firedIds] 与事件锚点**共用同一集合**
/// （`WorldState.firedAnchorIds`，类型是 `List<String>`，这里只做 `contains`
/// 故收 `Iterable` 更宽松），因此这里用 `canon_` 前缀避免撞车。
List<CanonEvent> dueCanonEvents({
  required int year,
  required int month,
  required int grade,
  required String era,
  required Iterable<String> firedIds,
  int limit = 1,
}) {
  if (!eraHasCanonTimeline(era)) return const [];
  final fired = firedIds is Set<String> ? firedIds : firedIds.toSet();
  final out = <CanonEvent>[];
  for (final e in canonEvents) {
    if (e.year != year) continue;
    if (e.month != month) continue;
    if (e.grade != null && e.grade != grade) continue;
    if (!e.eras.contains(era)) continue;
    if (fired.contains(e.id)) continue;
    out.add(e);
    if (out.length >= limit) break;
  }
  return out;
}

/// 该 `id` 是否是原著节点（供存档兼容与调试面板区分来源）。
bool isCanonEventId(String id) => id.startsWith('canon_');

/// 原著节点总数（结构性测试用：防止某天有人误删整段）。
int get canonEventCount => canonEvents.length;

/// 原著时间线覆盖的年份范围（含端点）。
(int, int) get canonYearRange {
  var minY = canonEvents.first.year;
  var maxY = canonEvents.first.year;
  for (final e in canonEvents) {
    if (e.year < minY) minY = e.year;
    if (e.year > maxY) maxY = e.year;
  }
  return (minY, maxY);
}
