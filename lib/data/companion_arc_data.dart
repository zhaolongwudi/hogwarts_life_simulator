/// P11 霍格沃茨羁绊小剧场库：一场与你所亲近之人之间的、跨多回合的小戏。
///
/// 【和奇遇的区别】奇遇是「你」个人随机碰到的一件小事；羁绊小剧场是
/// **你与某个 NPC 之间**的一件有始有终的小事——靠「好感」解锁，好感没到
/// 那份交情，这段戏就不会开演。它跨好几回合演完（前幕自动推进、最终幕留
/// 一次抉择），像身边人慢慢向你敞开心门。演完即归宿（每场只一次），留着
/// 让玩家愿意去把每一段羁绊都培养出来。
///
/// 触发：好感 ≥ `startAffection` + 年级/季节过滤；编排：多节拍按顺序推进，
/// 最终幕两段式抉择；数据全收口在这里，mixin 只做「选人开演 + 推进 + 抉择
/// 结算」三层事。新增小剧场只改这一份文件。
library;

// ==================== 节拍效果 ====================

/// 一幕戏带来的结算效果（全部可选，0 = 不结算该项）。口径对齐奇遇/节庆。
class CompanionArcEffectDef {
  final String? reputationDim; // academic/social/combat/moral/leadership/dark
  final int reputationValue;
  final int housePoints;
  final int galleons;
  final int energy;
  final int npcAffection; // 对本弧 NPC 的好感加成
  final String? itemName; // 奖励物品（需在 item_data 有定义）
  const CompanionArcEffectDef({
    this.reputationDim,
    this.reputationValue = 0,
    this.housePoints = 0,
    this.galleons = 0,
    this.energy = 0,
    this.npcAffection = 0,
    this.itemName,
  });
}

/// 一幕戏。`isClimax == true` 的节拍是最终幕：本回合播场景并给出抉择选项，
/// 下一回合按玩家选择结算对应结局；其余节拍自动推进（`effect` 即时结算）。
class CompanionArcBeatDef {
  final String id;
  final String scene; // 场景叙事（可带 `$house` 占位符）
  final bool isClimax; // 最终幕（唯一可给出结局分歧的一幕）
  final List<String> outcomeTitles; // 最终幕：抉择按钮文案（2 个）
  final List<String> outcomeTexts; // 最终幕：结局叙事（与 outcomeTitles 对齐）
  final List<CompanionArcEffectDef> outcomeEffects; // 最终幕：各结局奖励
  final CompanionArcEffectDef? effect; // 非最终幕：推进时即时结算的效果
  const CompanionArcBeatDef({
    required this.id,
    required this.scene,
    this.isClimax = false,
    this.outcomeTitles = const [],
    this.outcomeTexts = const [],
    this.outcomeEffects = const [],
    this.effect,
  });
}

/// 一场羁绊小剧场。
class CompanionArcDef {
  final String id;
  final String npcId; // 归属 NPC（npc_data 的 id）
  final String title; // 小剧场标题，如「深夜图书馆的约定」
  final int startAffection; // 好感门槛（>= 才触发）
  final int minGrade; // 年级门控（1~7）；默认 1
  final List<String> seasonTags; // 空=四季通用
  final int weight; // 抽取权重（多个可开演时的优先级）
  final List<CompanionArcBeatDef> beats; // 有序节拍：最后一幕应为 isClimax
  final List<String> traitTags; // 你需具备的性格特质（空=不限）；回填给玩家留口味
  const CompanionArcDef({
    required this.id,
    required this.npcId,
    required this.title,
    this.startAffection = 20,
    this.minGrade = 1,
    this.seasonTags = const [],
    this.weight = 1,
    required this.beats,
    this.traitTags = const [],
  });
}

/// 季节标签集合（spring/summer/autumn/winter）——用于数据校验。
const Set<String> kCompanionArcSeasonTags = {
  'spring', 'summer', 'autumn', 'winter',
};

/// 按 id 查小剧场。
CompanionArcDef? companionArcById(String id) {
  for (final a in kCompanionArcs) {
    if (a.id == id) return a;
  }
  return null;
}

/// 通用占位符替换：`$house` → 学院名（与奇遇/节庆同口径）。
String fillCompanionArcText(String text, {required String house}) =>
    text.replaceAll(r'$house', house);

const List<CompanionArcDef> kCompanionArcs = [
  // ====== 赫敏 · 深夜图书馆的约定 ======
  CompanionArcDef(
    id: 'hermione_study_pledge',
    npcId: 'hermione',
    title: '深夜图书馆的约定',
    startAffection: 25,
    seasonTags: ['autumn', 'winter'],
    traitTags: ['勤奋', '聪慧', '善良'],
    beats: [
      CompanionArcBeatDef(
        id: 'hs1',
        scene:
            '入秋后的图书馆越来越冷清，可赫敏总在最里头那排的角落待到熄灯前。'
            '这天她忽然叫住你，把一个叠得整整齐齐的书签按到你手心里：'
            '"我在替所有人都做一份……你要是也想偷懒，至少挑一个舒服一点的位置。"',
      ),
      CompanionArcBeatDef(
        id: 'hs2',
        scene:
            '之后连续几晚，那张书签一直躺在你桌上。某天你路过那排书架，'
            '看见赫敏趴在桌上睡着了，手边摊着一本写满了批注的《魔法史》，'
            '页码停在你们下星期要考的那章。你没有说话，把自己的围巾轻轻搭在她肩上。',
        effect: CompanionArcEffectDef(
            reputationDim: 'academic', reputationValue: 2, npcAffection: 3),
      ),
      CompanionArcBeatDef(
        id: 'hs3',
        isClimax: true,
        scene:
            '考试前两天的深夜，赫敏在后半夜才抬起头，眼眶发红却冲你笑了笑：'
            '"如果我一直是这样的人，以后是不是就没人愿意陪我了？"'
            '窗外是霍格沃茨沉睡的塔楼，她的话轻得像快要散在灯影里。',
        outcomeTitles: ['告诉她不会的', '陪她坐一会儿'],
        outcomeTexts: [
          '你认真看着她——"赫敏，没有人生来就要扛起所有书。你愿意被人讨厌地'
              '催促读书，只是因为你想帮每个人。这样的你，怎么会没人愿意陪。"'
              '她愣了很久，忽然笑了，眼里的红晕淡了下去。',
          '你没急着回答，只是在她对面坐下来，翻开你的书，陪她把那一段读完。'
              '安静里，你听她轻轻说了一声"谢谢"。那一晚的灯，亮得比任何时候都暖。',
        ],
        outcomeEffects: [
          CompanionArcEffectDef(
              reputationDim: 'social', reputationValue: 3, npcAffection: 8, galleons: 8),
          CompanionArcEffectDef(
              reputationDim: 'moral', reputationValue: 2, npcAffection: 8,
              energy: 4, itemName: '手叠旧书签'),
        ],
      ),
    ],
  ),

  // ====== 罗恩 · 藏在抽屉里的勇气 ======
  CompanionArcDef(
    id: 'ron_hidden_brooch',
    npcId: 'ron',
    title: '藏在口袋里的勇气',
    startAffection: 25,
    seasonTags: ['spring', 'summer'],
    traitTags: ['勇敢', '仗义', '忠诚'],
    beats: [
      CompanionArcBeatDef(
        id: 'rb1',
        scene:
            '午后的魁地奇练习场边，罗恩盯着球门发呆，表情比输了球还要难看。'
            '你在他身边坐下，半天他才挤出一句："我哥说，韦斯莱家的孩子生下来'
            '就得会这个。可我总觉得自己是那个拖后腿的。"',
      ),
      CompanionArcBeatDef(
        id: 'rb2',
        scene:
            '第二天，你在他的课本里发现一张皱巴巴的纸，上面涂满了"我能行"的字样，'
            '墨迹深浅不一，看得出写了很多遍。你把纸偷偷夹回去，没提一个字。'
            '当天傍晚，罗恩难得主动拉你去练习场试了一球。',
        effect: CompanionArcEffectDef(
            reputationDim: 'combat', reputationValue: 2, npcAffection: 3),
      ),
      CompanionArcBeatDef(
        id: 'rb3',
        isClimax: true,
        scene:
            '一场三对三的临时训练后，罗恩满头大汗地坐到你旁边，捏着掌心里的'
            '一枚旧校徽撞球——那上面有罗恩·韦斯莱自己的浮名。他低声问：'
            '"会有一天……我也能站上人人都看得见的那个位置吗？"',
        outcomeTitles: ['肯定他做得到', '带他去真的站上去'],
        outcomeTexts: [
          '你看着他："罗恩，勇气不是生下来就满格的东西，是你一次次站起来练出来的。"'
              '他握紧那枚撞球，眼睛一点点亮起来，重重地"嗯"了一声。',
          '你把他拉起来，一路带他去了训练场正中央——那天只有你们两个人，'
              '他却一直挺着胸膛，把手里的撞球举过了头顶。',
        ],
        outcomeEffects: [
          CompanionArcEffectDef(
              reputationDim: 'leadership', reputationValue: 3, npcAffection: 8, galleons: 6),
          CompanionArcEffectDef(
              reputationDim: 'combat', reputationValue: 2, npcAffection: 8,
              energy: 5, itemName: '勇气撞球'),
        ],
      ),
    ],
  ),

  // ====== 哈利 · 疤下的火与光 ======
  CompanionArcDef(
    id: 'harry_scar_promise',
    npcId: 'harry',
    title: '疤下的火与光',
    startAffection: 30,
    minGrade: 2,
    seasonTags: ['autumn', 'winter', 'spring'],
    traitTags: ['勇敢', '善良', '正直'],
    beats: [
      CompanionArcBeatDef(
        id: 'hd1',
        scene:
            '某天夜里，哈利独自坐在空无一人的走廊尽头，呆呆看着自己前额那道伤疤。'
            '他听见你的脚步声，没有躲，只是低声说："有时候它烧起来……我会想，'
            '那是不是还有一条路，是我不想看见的。"',
      ),
      CompanionArcBeatDef(
        id: 'hd2',
        scene:
            '第二天，你在你的空桌上发现一颗糖，糖纸上歪歪扭扭写着"昨天谢谢"。'
            '后来你从纳威那儿听说，那天夜里之后，哈利开始试着在图书馆待得久一点，'
            '不再总是一个人躲到角落里。',
        effect: CompanionArcEffectDef(
            reputationDim: 'moral', reputationValue: 2, npcAffection: 3),
      ),
      CompanionArcBeatDef(
        id: 'hd3',
        isClimax: true,
        scene:
            '一场突如其来的骚动之后，哈利靠在墙边喘着气，伤疤一阵阵地疼。'
            '他忽然抬头问你，声音哑得厉害："如果有一天要由你选——是哪束光更重要，'
            '你会怎么选？"',
        outcomeTitles: ['选照进身边人的光', '选他自己心里的光'],
        outcomeTexts: [
          '你看着他的眼睛："哈利，我选让人身边的人都亮起来的光。你疼的时候，'
              '从来不是一个人疼——这句话你记住就行。"他怔了很久，把拳头的指甲'
              '攥得发白，却终于松开了眉头。',
          '你一字一句说："你心里的那点光，本就不需要任何人批准它亮。"'
              '那天晚上，哈利破天荒地没有做噩梦，或者说——他学会在梦里握住那点火了。',
        ],
        outcomeEffects: [
          CompanionArcEffectDef(
              reputationDim: 'leadership', reputationValue: 3, npcAffection: 10, galleons: 9),
          CompanionArcEffectDef(
              reputationDim: 'moral', reputationValue: 3, npcAffection: 10,
              energy: 4, itemName: '灰色护身石'),
        ],
      ),
    ],
  ),
];

/// 索引反感：按 npcId 聚合，方便 mixin 按「这位 NPC」是否已有弧在做/演完。
Map<String, List<CompanionArcDef>> companionArcsByNpc() {
  final map = <String, List<CompanionArcDef>>{};
  for (final a in kCompanionArcs) {
    map.putIfAbsent(a.npcId, () => []).add(a);
  }
  return map;
}