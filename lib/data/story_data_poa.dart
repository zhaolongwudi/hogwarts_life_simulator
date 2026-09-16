/// 《阿兹卡班的囚徒》1993-1994 · 三年级 · 剧情内容表
///
/// 【这一部的气质】前两部是"城堡里有秘密"，这一部是"恐惧住进了城堡"。
/// 摄魂怪是原著三年级真正的压迫源：它不杀你，它让你把最坏的那段记忆
/// 重新过一遍。玩家作为原创三年级生，第一次获得去霍格莫德的资格，
/// 也第一次意识到——城堡的墙挡不住所有东西。
///
/// 【与哈利线的边界】越狱的是小天狼星·布莱克，被追的是他，逃亡与对峙
/// 都是哈利线的戏剧位。玩家能接触到的只有：报纸上的通缉令、走廊里
/// 突然增多的巡逻、摄魂怪经过时全车厢一齐暗下去的那几秒钟、
/// 以及听证会外头围观的队伍。真相（谁背叛了谁、谁是无辜的）只在
/// 学年末以"传闻的碎片"形式飘到玩家耳边——你知道有件事被解决了，
/// 但你不是解决它的人。
///
/// 【原著节点覆盖】13 个 canon_poa_* 节点已全覆盖，一一挂载在
/// 对应的 `canonRefId` 上，由 `story_graph_integrity_test` 与
/// `verify_canon.py` 双向校验月份对齐。
///
/// 【内容密度】46 步 × 平均 7.4 天 ≈ 341 天。三年级原著里那些
/// "恐惧如何渗进日常"的场景（到校第一夜、博格特之后不敢回宿舍、
/// 空掉的球场、听证会之后不敢敲门、考试月夜里的警报）在早期版本里
/// 被合并进了几个大步，玩家一部书只有 36 次选择——比《魔法石》少一半。
/// 现在这些场景各自成步，选择密度与前两部看齐。
library;

import 'package:hogwarts_life_simulator/models/story_progress.dart';

// ================================================================
// 《阿兹卡班的囚徒》 1993-1994 · 三年级
//
// 【时间线】1993-07-25 开启锚点（第三年的信）→ 1994-07-01 学年结束。
// 46 步 × 平均 7.4 天 ≈ 341 天，与 13 个 canon_poa_* 节点的月份逐一对齐。
// 注意：有两对锚点落在同一个月（10 月的 hogsmeade_form 与 boggart、
// 11 月的 quidditch_storm 与 hogsmeade），改天数时不能把它们压到 0 天。
// ================================================================

const List<StoryChapterDef> _poaChapters = [
  // --------------------------------------------------------------
  // 第一章 · 越狱的夏天（1993 年 7-8 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'poa_ch1',
    bookId: 'poa',
    ordinal: 1,
    title: '越狱的夏天',
    steps: [
      StoryStepDef(
        id: 'poa_ch1_wanted',
        chapterId: 'poa_ch1',
        timeCostDays: 1,
        setup:
            '七月底的对角巷，几乎每家店的橱窗上都多了一张会动的通缉令：'
            '照片里的男人瘦得脱形，头发又长又乱，正缓慢地把脸转向镜头，'
            '然后又移开。报纸的头版连着登了三天，'
            '用词一次比一次严重，却始终没人解释他是怎么从那里出来的。',
        ambient: [
          '丽痕书店的橱窗玻璃上，通缉令被贴在打折海报旁边。',
          '有人在店门口停下来看了很久，然后摇摇头走开。',
          '风把一张报纸从街角卷过来，头版朝着天躺在地上。',
        ],
        canonRefId: 'canon_poa_daily_prophet',
        onEnterText: '整个夏天，你走到哪里都能看见这张脸。',
        choices: [
          StoryChoiceDef(
            id: 'read_everything',
            text: '把能找到的报道都读一遍，记住细节',
            consequence:
                '你把几份报纸摊在桌上对比，发现不同来源对同一件事的'
                '描述并不一致：有的说他"极度危险"，有的只说他"在逃"。'
                '你把两处矛盾记在心里——这个夏天你学会了不轻信单一说法。',
            effect: StoryEffect(
              addItems: ['剪下来的报纸'],
              addKnowledge: ['poa_escape_details'],
              setFlags: ['poa_studied_reports'],
              spirit: -2,
            ),
            nextStepId: 'poa_ch1_news',
          ),
          StoryChoiceDef(
            id: 'ask_shopkeeper',
            text: '向店主打听几句，看他怎么说',
            consequence:
                '店主压低了声音，说得比报纸多得多：他提到那个人的名字、'
                '提到他当年"干过什么"，也提到那件事之后这条街上的风向。'
                '说完他自己也觉得不妥，转身去招呼别的客人了。',
            effect: StoryEffect(
              addKnowledge: ['poa_black_backstory'],
              setFlags: ['poa_asked_shopkeeper'],
              spirit: -1,
            ),
            nextStepId: 'poa_ch1_news',
          ),
          StoryChoiceDef(
            id: 'ignore',
            text: '不理会这些传闻，先顾好自己的采购',
            consequence:
                '你按着书单把该买的东西都买齐了，只在最后一家店门口'
                '被那张通缉令绊住了一秒。你对自己说：那是个成年人的事，'
                '离得很远。这个判断在两个月后会被证明只对了一半。',
            effect: StoryEffect(
              addKnowledge: ['poa_knew_of_escape'],
              setFlags: ['poa_ignored_reports'],
              spirit: 1,
            ),
            nextStepId: 'poa_ch1_news',
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch1_news',
        chapterId: 'poa_ch1',
        timeCostDays: 20,
        onEnterText:
            '—— 第 3 部 · 阿兹卡班的囚徒 ——\n'
            '三年级的暑假来得很安静，直到一张报纸把整个夏天撕开。',
        setup:
            '第三年的信和《预言家日报》一起落在门垫上。你先捡起了报纸——'
            '头版那张照片会动，上面的人瘦得脱了形，眼睛却亮得不正常，'
            '标题写着他从阿兹卡班逃走了。楼下有人说，监狱的守卫已经'
            '换成了那种会飘的东西。',
        ambient: [
          '照片里的人每隔几秒就挣扎一次，像被困在纸里。',
          '信安静地压在报纸下面，火漆完好，还没被拆开。',
          '窗外蝉声照旧，和头版上那行大字形成某种荒谬的对比。',
        ],
        canonRefId: 'canon_poa_escape',
        choices: [
          StoryChoiceDef(
            id: 'read_all',
            text: '把头版和内页的追踪报道逐字读完',
            consequence:
                '你读完了全部三版。越狱者叫小天狼星·布莱克，十二年前'
                '被判终身监禁，从未要求重审。报道里反复出现一个名字——'
                '一个和你同校的男孩。你把这两件事在心里系了个结，'
                '没跟任何人说。',
            effect: StoryEffect(
              addKnowledge: ['poa_escape_dossier'],
              setFlags: ['poa_read_news'],
              spirit: 2,
            ),
            nextStepId: 'poa_ch1_telly',),
          StoryChoiceDef(
            id: 'ask_around',
            text: '拿着报纸去问大人这到底意味着什么',
            consequence:
                '你得到的答案比报纸更含糊：有人说"别操心，学校会护着你们"，'
                '有人说"那种守卫上了街，事情就不小"。你从他们的表情里'
                '读到的比从话里读到的多——大人也在怕。',
            effect: StoryEffect(
              addKnowledge: ['poa_adults_afraid'],
              setFlags: ['poa_knows_escape'],
              reputation: 1,
            ),
            nextStepId: 'poa_ch1_telly',),
          StoryChoiceDef(
            id: 'fold_away',
            text: '把报纸折起来压在信下面，先拆信',
            consequence:
                '你把报纸折了两折压在信下面，先去拆那封属于你的信。'
                '三年级的书单比去年厚，多出两门新课。'
                '那个逃跑的人暂时被你关在了纸里——直到开学那天他还会再出来。',
            effect: StoryEffect(
              addKnowledge: ['poa_third_year_list'],
              spirit: 1,
            ),
            nextStepId: 'poa_ch1_telly',),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch1_telly',
        chapterId: 'poa_ch1',
        timeCostDays: 1,
        setup:
            '麻瓜的电视里在放一条很短的新闻，说某处监狱发生了"越狱"，画面只给了三秒钟。你家里的人一边换台一边说这种事跟他们没关系——但你记得那个名字，和它后面跟着的一长串头衔。',
        ambient: [
          '电视屏幕闪了一下，信号被什么干扰了。',
          '窗外有猫头鹰扑棱着飞过，白天不该有猫头鹰。',
          '你母亲把音量调小了，说是给小孩听的新闻。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'ask_about_it',
            text: '追问那个名字是谁',
            consequence:
                '大人交换了一个眼神，最后还是说了个大概：那是个很危险的巫师，逃出来已经有一阵了。他们说完就转开了话题，但你记住了"阿兹卡班"三个字。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['poa_knows_azkaban'], setFlags: ['poa_asked_about_sirius'], spirit: -2),
          ),
          StoryChoiceDef(
            id: 'stay_quiet',
            text: '不作声，把这件事悄悄记在心里',
            consequence:
                '你没有再问。晚饭的时候大家都在说别的事，只有你知道自己一直在想那条三秒钟的新闻。有些事大人们不说，是因为说了也没用。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['poa_kept_silent'], spirit: -1),
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch1_dementor_rumor',
        chapterId: 'poa_ch1',
        timeCostDays: 10,
        setup:
            '八月的街上开始出现那种守卫。它们不走路，它们在飘；'
            '经过的时候，路灯会暗一下，空气里像被人抽走了所有暖和的东西。'
            '街坊们压低了声音说话，管它们叫摄魂怪。',
        ambient: [
          '有人说它们靠人的快乐为生，被碰过的人会想起最糟的一天。',
          '巷口的猫这几天一直躲在垃圾桶后面不肯出来。',
          '你想起三年级的教室在城堡高处，风应该很大。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'observe',
            text: '躲在窗帘后面，把它们经过的样子记住',
            consequence:
                '你数了三只。它们移动的时候周围的草都会枯一下，'
                '而你的手指在窗台上凉得发麻。你把这种凉意记了下来——'
                '它不像冷，更像"被抽走"。',
            effect: StoryEffect(
              addKnowledge: ['poa_dementor_sensation'],
              setFlags: ['poa_knows_dementor'],
              spirit: -2,
            ),
          ),
          StoryChoiceDef(
            id: 'comfort_sibling',
            text: '家里有人在发抖，你留下来陪着',
            consequence:
                '你没有去看窗外，而是坐下来陪着那个人说话，'
                '直到街上重新亮起来。后来你想，那天你做的这件事，'
                '比看清它们的样子更值。',
            effect: StoryEffect(
              addKnowledge: ['poa_stayed_with_family'],
              setFlags: ['poa_helped_peer'],
              reputation: 2,
              affection: 2,
              targetNpcId: 'ginny',
            ),
          ),
          StoryChoiceDef(
            id: 'read_defense',
            text: '翻出二年级的黑魔法防御术课本找对策',
            consequence:
                '你把课本从头翻到尾，关于它们的内容只有半页，'
                '还写着"课本不推荐深入学习"。'
                '但你在页边找到了一行小字：驱散它们的咒语属于高级课程。',
            effect: StoryEffect(
              addKnowledge: ['poa_patronus_hint'],
              setFlags: ['poa_knows_dementor'],
              spirit: 1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch1_booklist',
        chapterId: 'poa_ch1',
        timeCostDays: 6,
        setup:
            '三年级的书单上多了两门选修：占卜学和神奇动物保护。'
            '前者的教材封面画着一只眼睛，后者要求你准备一副厚手套。'
            '你只能选一门先深入——时间只有那么多。',
        ambient: [
          '《拨开迷雾看未来》翻开第一页就掉出一把茶渣。',
          '《怪兽及其产地》的边角被前一位主人翻得起了毛。',
          '对角巷的书店里，这两摞书正在互相瞪着对方。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'pick_divination',
            text: '选占卜学，跟着茶渣和星象走',
            consequence:
                '你选了占卜学。第一课你就被告知，你手上那条线'
                '短得不太吉利——老师说完还同情地拍了拍你的肩。'
                '你决定把这当成一种风格，而不是预言。',
            effect: StoryEffect(
              addItems: ['旧书'],
              addKnowledge: ['poa_divination_basics'],
              setFlags: ['poa_divination'],
              spirit: -1,
            ),
            nextStepId: 'poa_ch1_shopping',),
          StoryChoiceDef(
            id: 'pick_creatures',
            text: '选神奇动物保护，去上那个大胡子的课',
            consequence:
                '你选了神奇动物保护。海格在第一节课上就说：'
                '"书本是死的，它们是活的。"他身后栅栏里的东西'
                '发出一声马一样的嘶鸣，把前排的同学吓退了半步。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包'],
              addKnowledge: ['poa_creature_basics'],
              setFlags: ['poa_care_creatures'],
              reputation: 1,
              affection: 3,
              targetNpcId: 'hagrid',
            ),
            nextStepId: 'poa_ch1_shopping',),
          StoryChoiceDef(
            id: 'ask_upperclassman',
            text: '先去问高年级哪一门更值得',
            consequence:
                '你问了三个人，得到三种答案。其中一个三年级的学长'
                '压低声音说："选哪门都行，但别在它们面前说那个人的名字。"'
                '你没敢追问是哪个人。',
            effect: StoryEffect(
              addKnowledge: ['poa_upperclass_advice'],
              setFlags: ['poa_knows_escape'],
              reputation: 1,
              affection: 2,
              targetNpcId: 'cedric',
            ),
            nextStepId: 'poa_ch1_shopping',),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch1_leaky',
        chapterId: 'poa_ch1',
        timeCostDays: 12,
        setup:
            '开学前最后一次去对角巷，你在破釜酒吧等一壶热茶。'
            '邻桌坐着两个穿旧袍子的巫师，声音压得很低，'
            '但酒吧里太安静了——他们说的每一句你都听得见。'
            '他们说的不是报纸上那套，是"当年跟他一起的人"。',
        ambient: [
          '老板擦杯子的手停了两次，又继续擦。',
          '有人推门进来时带进一阵风，全屋的人都抬了一下头。',
          '那两人走的时候，桌上的茶一口没动。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'listen_in',
            text: '继续听，把他们说的记下来',
            consequence:
                '你听了二十分钟，记住三个名字和一句"他逃出来是为了什么"。'
                '这句话报纸上从来没出现过。'
                '后来你才明白，成年人知道的和说出来的从来不是同一件事。',
            effect: StoryEffect(
              addKnowledge: ['poa_adult_version'],
              setFlags: ['poa_overheard_adults'],
              housePoints: 2,
              spirit: -1,
            ),
            nextStepId: 'poa_ch1_shopping',
          ),
          StoryChoiceDef(
            id: 'ask_keeper',
            text: '去问那位老店主，他知道的比谁都多',
            consequence:
                '店主看了你一眼，把茶推过来，说："小孩子别打听这种事。"'
                '然后他压低声音补了一句："不过今年学校里会不太平，你自己小心。"'
                '这是他第一次跟你说这么长的话。',
            effect: StoryEffect(
              addKnowledge: ['poa_barman_warning'],
              setFlags: ['poa_warned_early'],
              housePoints: 1,
              affection: 1,
              targetNpcId: 'rosmerta',
            ),
            nextStepId: 'poa_ch1_shopping',
          ),
          StoryChoiceDef(
            id: 'ignore_it',
            text: '不听了，把茶喝完就走',
            consequence:
                '你把茶喝完，付了钱，出门去丽痕书店。'
                '这个夏天你决定不把这件事当成自己的事——'
                '这个决定在两个月后被你自己推翻了。',
            effect: StoryEffect(
              setFlags: ['poa_avoided_news'],
              spirit: 1,
            ),
            nextStepId: 'poa_ch1_shopping',
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch1_shopping',
        chapterId: 'poa_ch1',
        timeCostDays: 1,
        setup:
            '对角巷的书店比往年挤。新学期的书单上多了一本很厚的东西，封面上印着一个会动的、正在消散的人影。店员说这是今年卖得最好的一本。',
        ambient: [
          '《预言家日报》在门口堆成一摞，头版标题都差不多。',
          '有个小孩指着书封问妈妈那是什么，妈妈把他拉走了。',
          '柜台上摆着一种护身符，写着"驱赶黑暗生物"。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'buy_the_book',
            text: '把新书买下来，先自己读一遍',
            consequence:
                '你花了一整个下午读那本书，里面讲的东西比你想象得要冷静——它把危险一样一样列出来，然后告诉你为什么不必害怕。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['poa_read_defense_book'], setFlags: ['poa_bought_book'], spirit: 3),
          ),
          StoryChoiceDef(
            id: 'buy_charm',
            text: '买了那个护身符，尽管知道多半没用',
            consequence:
                '你知道这东西大概率是骗人的，但还是把它塞进了行李。长大一点以后你会发现，人有时候就是需要这种没用的东西。',
            nextStepId: '',
            effect: StoryEffect(addItems: ['护身符'], setFlags: ['poa_kept_charm'], spirit: 2),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第二章 · 摄魂怪列车（1993 年 9 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'poa_ch2',
    bookId: 'poa',
    ordinal: 2,
    title: '摄魂怪列车',
    steps: [
      StoryStepDef(
        id: 'poa_ch2_platform',
        chapterId: 'poa_ch2',
        timeCostDays: 1,
        setup:
            '九月的站台上人声比去年低。墙根下立着几个穿长袍的守卫，'
            '帽檐压得很低，正一列一列地检查车厢。'
            '你推着行李走过去时，听见有人小声说：它们在找一个人。',
        ambient: [
          '蒸汽里混着一股说不上来的味道，像放久了的衣服。',
          '有人的猫头鹰在笼子里一动不动，连叫都懒得叫。',
          '你母亲的手在你肩上停了一下，然后松开。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'steady_up',
            text: '站直了走过去，不低头也不加快脚步',
            consequence:
                '你按自己的步子走过去，眼睛看着车厢号。'
                '一个守卫转过头来看了你两秒，又转回去。'
                '你上车时手心是干的——这件事后来你记了很久。',
            effect: StoryEffect(
              setFlags: ['poa_brave_train'],
              reputation: 2,
              spirit: 2,
            ),
          ),
          StoryChoiceDef(
            id: 'help_underclass',
            text: '帮一个一年级生把箱子搬上台阶',
            consequence:
                '你腾出手帮那个小家伙把箱子抬上车。他太紧张了，'
                '一直在看那些守卫。你顺手把他推进最近的车厢，'
                '说"里面暖和"——其实你也不知道里面暖不暖。',
            effect: StoryEffect(
              setFlags: ['poa_helped_peer'],
              reputation: 2,
              affection: 2,
              targetNpcId: 'colin',
            ),
          ),
          StoryChoiceDef(
            id: 'watch_guards',
            text: '停下来观察它们怎么检查车厢',
            consequence:
                '你放慢脚步数了数：它们每个车厢停大约十秒，'
                '进去之后里面会彻底安静。出来时，总有人脸色发白。'
                '你把"十秒"这个数字记住了。',
            effect: StoryEffect(
              addKnowledge: ['poa_search_pattern'],
              setFlags: ['poa_knows_dementor'],
              spirit: -1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch2_train',
        chapterId: 'poa_ch2',
        timeCostDays: 1,
        canonRefId: 'canon_poa_dementors',
        setup:
            '火车开出半小时后，走廊尽头的光线开始变暗。不是云——'
            '是有什么东西从那头过来了。它经过每一节车厢，'
            '每一次，车厢里的声音都像被剪刀剪断。',
        ambient: [
          '窗玻璃上结了一层霜，从边缘往中间爬。',
          '有人在你旁边小声说："别看，别听。"',
          '你握着自己的手腕，发现脉搏比平时快。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'hold_peer',
            text: '把手伸过去，握住旁边人的手腕',
            consequence:
                '你抓住了旁边那只手。对方也回握住你，力气大得发疼。'
                '门外的东西停了一会儿，然后飘走了。'
                '你们谁都没提刚才听见了什么——那成了你们之间的默契。',
            effect: StoryEffect(
              setFlags: ['poa_brave_train'],
              affection: 3,
              reputation: 1,
              targetNpcId: 'neville',
            ),
            nextStepId: 'poa_ch2_cold',),
          StoryChoiceDef(
            id: 'focus_memory',
            text: '闭上眼，死死想住一件特别好的事',
            consequence:
                '你想起去年春天一件事，笑得很大声的那次。'
                '你把那段记忆翻来覆去地放着，像拿它当盾牌。'
                '车厢里冷，但你心里那块地方是热的——至少没被拿走。',
            effect: StoryEffect(
              addKnowledge: ['poa_memory_shield'],
              setFlags: ['poa_patronus_attempt'],
              spirit: 3,
            ),
            nextStepId: 'poa_ch2_cold',),
          StoryChoiceDef(
            id: 'chocolate_plan',
            text: '在包里翻找能让人缓过来的甜东西',
            consequence:
                '你摸出两块巧克力，掰开分给前后座。'
                '甜的东西下肚之后，那股凉意才慢慢退开。'
                '后来这成了你包里常备的东西——不是嘴馋，是准备。',
            effect: StoryEffect(
              addItems: ['巧克力蛙', '巧克力蛙'],
              addKnowledge: ['poa_chocolate_cure'],
              reputation: 1,
              spirit: 1,
            ),
            nextStepId: 'poa_ch2_cold',),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch2_compartment',
        chapterId: 'poa_ch2',
        timeCostDays: 1,
        setup:
            '列车开出去两个小时，走道上的推车来过了两次。'
            '你的包厢里坐着四个人，其中一个是二年级的，'
            '一路上都在讲他从哥哥那里听来的阿兹卡班细节。'
            '讲到一半，车慢了下来——不是因为到站。',
        ambient: [
          '有人在讲"那地方根本没有墙"的时候，灯闪了一下。',
          '过道里有人跑过去，脚步声很急。',
          '窗外的雨斜着打在玻璃上，越来越密。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'keep_talking',
            text: '接着把话题讲完，装作没注意到车速',
            consequence:
                '你们把话讲完了，讲得很响，像是要把什么盖过去。'
                '列车重新加速的时候，屋里没人提刚才那几分钟。'
                '但你注意到那个二年级生的手一直攥着袖口。',
            effect: StoryEffect(
              addKnowledge: ['poa_train_stories'],
              setFlags: ['poa_talked_over_it'],
              spirit: 1,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'go_look',
            text: '去走道尽头看看发生了什么',
            consequence:
                '你走到车厢连接处，看见两个级长站在那儿，脸色很难看。'
                '其中一个回头看见你，只说了一句："回座位去。"'
                '你回了座位——但那扇窗外的黑，你一直记着。',
            effect: StoryEffect(
              addKnowledge: ['poa_saw_corridor'],
              setFlags: ['poa_curious_on_train'],
              energy: -8,
              spirit: -2,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'change_seat',
            text: '换个座位，坐到靠窗但离门近的地方',
            consequence:
                '你换了个位置。没人问你为什么。'
                '你后来想，这大概是你第一次凭本能给自己找退路——'
                '这种直觉在接下来的两年里救过你几次。',
            effect: StoryEffect(
              setFlags: ['poa_instinct_tested'],
              housePoints: 1,
              satiety: -2,
            ),
            nextStepId: '',
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch2_cold',
        chapterId: 'poa_ch2',
        timeCostDays: 1,
        setup:
            '火车忽然慢了下来，然后彻底停了。窗玻璃上的水汽一下子结成了白霜，车厢里的暖气像是被谁关掉了——灯也一盏一盏暗下去。',
        ambient: [
          '过道里有人小声问为什么停车，没人回答。',
          '你呼出的气在眼前变成白雾。',
          '隔壁包厢传来一声很轻的、压抑住的抽气声。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'grab_hand',
            text: '伸手拉住身边那个在发抖的人',
            consequence:
                '你没有问怎么了，只是把手伸过去。那只手很凉，攥得很紧，直到车厢重新亮起来才松开。后来你们谁都没提这件事，但从那天起就成了朋友。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['poa_held_hand'], spirit: -2, targetNpcId: 'ginny', affection: 3),
          ),
          StoryChoiceDef(
            id: 'keep_calm',
            text: '不出声，慢慢数着自己的呼吸',
            consequence:
                '你数到第二十几下的时候，灯亮了。车轮重新碾过铁轨，霜在玻璃上化开。你发现自己其实没怎么害怕——这让你有点意外。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['poa_stayed_calm'], spirit: 2),
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch2_dementor_night',
        chapterId: 'poa_ch2',
        timeCostDays: 1,
        setup:
            '到校第一夜，不少人没睡。'
            '有人反复说自己"什么都想不起来"——'
            '只记得冷，而且冷得没有尽头。'
            '宿舍里没人开玩笑，连平时最爱闹的那个都早早拉上了床帘。',
        ambient: [
          '有人半夜坐起来，说听见了很远的哭声。',
          '窗外的湖面一动不动，像结了冰。',
          '第二天早上，有人把摄魂怪的事写进家信，写了三页。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'talk_it_out',
            text: '把在车厢里听见的东西说给室友听',
            consequence:
                '你说了。说到一半发现屋里有三个人在听，谁都没插话。'
                '你说完，有人跟着说了他的。'
                '那一夜之后，这件事不再是你一个人的东西。',
            effect: StoryEffect(
              addKnowledge: ['poa_train_shared'],
              setFlags: ['poa_shared_fear'],
              affection: 3,
              spirit: 2,
              targetNpcId: 'dean',
            ),
            nextStepId: 'poa_ch2_castle',
          ),
          StoryChoiceDef(
            id: 'keep_quiet',
            text: '不说，翻个身假装睡了',
            consequence:
                '你没说。你觉得说出来会让它变得更实在。'
                '那一夜之后，每次列车开进隧道你都会先闭上眼睛——'
                '这个习惯你保持了很久。',
            effect: StoryEffect(
              addKnowledge: ['poa_kept_it_in'],
              setFlags: ['poa_private_fear'],
              spirit: -2,
            ),
            nextStepId: 'poa_ch2_castle',
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch2_castle',
        chapterId: 'poa_ch2',
        timeCostDays: 2,
        setup:
            '夜里的城堡比去年安静。门口多了两道岗，'
            '开学宴上校长宣布摄魂怪将驻守学校四周，'
            '然后他补了一句：不要在它们面前落单。',
        ambient: [
          '礼堂顶上的蜡烛照旧飘着，但没往年那么暖。',
          '你注意到有几张高年级的脸绷得很紧。',
          '分院帽的歌声今年讲的是"警惕"。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'note_exits',
            text: '记下走廊里所有能拐弯的岔口',
            consequence:
                '你花了一周把常走的几条路摸熟，包括那些能拐进死角的岔口。'
                '你不是要躲谁，只是不喜欢被堵在一条直路上的感觉。',
            effect: StoryEffect(
              addKnowledge: ['poa_castle_routes'],
              setFlags: ['poa_knows_escape'],
              spirit: 1,
            ),
          ),
          StoryChoiceDef(
            id: 'check_on_friend',
            text: '去问问那个在火车上的人睡不睡得着',
            consequence:
                '你敲了公共休息室的门，那人果然还醒着。'
                '你们没聊摄魂怪，聊的是明天的课表。'
                '但临走时那人说："明天一起走。"——这句话比什么都管用。',
            effect: StoryEffect(
              setFlags: ['poa_helped_peer'],
              affection: 2,
              reputation: 1,
              targetNpcId: 'neville',
            ),
          ),
          StoryChoiceDef(
            id: 'ask_professor',
            text: '课后去问教授，那种东西到底怎么防',
            consequence:
                '你留下来问了。教授看了你一会儿，说那是很高级的魔法，'
                '三年级不该碰；然后他从抽屉里拿出一块巧克力推给你，'
                '什么也没解释。',
            effect: StoryEffect(
              addItems: ['巧克力蛙'],
              addKnowledge: ['poa_patronus_hint'],
              affection: 1,
              targetNpcId: 'mcgonagall',
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第三章 · 三年级的新课（1993 年 10 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'poa_ch3',
    bookId: 'poa',
    ordinal: 3,
    title: '三年级的新课',
    steps: [
      StoryStepDef(
        id: 'poa_ch3_divination',
        canonRefId: 'canon_poa_hogsmeade_form',
        chapterId: 'poa_ch3',
        timeCostDays: 14,
        setup:
            '占卜学的教室在塔楼顶上，得爬一架摇摇晃晃的梯子。'
            '屋子里全是薰香和矮桌，老师坐在阴影里，'
            '一开口就说她在你身上看见了一个不祥的东西。',
        ambient: [
          '茶杯底的渣子每次都摆出不同的形状，每次都不太好。',
          '窗帘拉着，屋里分不清上午还是下午。',
          '有同学已经开始把她的每句话记在羊皮纸上了。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'play_along',
            text: '认真记下每一次预言，回头对照',
            consequence:
                '你开始记。两周过去，十七条"预言"里有十六条没发生，'
                '剩下那一条——你宁可它也没发生。'
                '你合上本子，决定从此只把这门课当成一门课。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包'],
              addKnowledge: ['poa_divination_log'],
              setFlags: ['poa_divination'],
              spirit: -1,
            ),
            nextStepId: 'poa_ch3_tea',),
          StoryChoiceDef(
            id: 'push_back',
            text: '当众问她：能不能说点能验证的',
            consequence:
                '你举了手。教室里安静了三秒。'
                '老师的眼睛在烛光里显得很大，她说"质疑的人往往最先应验"。'
                '课后有同学拍你肩膀说：你胆子真大。',
            effect: StoryEffect(
              setFlags: ['poa_divination'],
              reputation: 2,
              spirit: 1,
            ),
            nextStepId: 'poa_ch3_tea',),
          StoryChoiceDef(
            id: 'skip_dream',
            text: '把注意力放在窗外能看见的湖面上',
            consequence:
                '你看着窗外的湖，一整节课什么都没听进去。'
                '但那天下午你发现，湖对岸的禁林边上多了一条小路，'
                '之前没有。你把这个记在了心里。',
            effect: StoryEffect(
              addKnowledge: ['poa_forest_path'],
              spirit: 1,
            ),
            nextStepId: 'poa_ch3_tea',),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch3_tea',
        canonRefId: 'canon_poa_boggart',
        chapterId: 'poa_ch3',
        timeCostDays: 20,
        setup:
            '占卜课上，茶杯在手里转了三圈，最后剩在杯底的形状谁也不肯明说。老师看了一眼你的杯子，又看了一眼你，把话头引开了。',
        ambient: [
          '隔壁桌的人凑过来看，然后也沉默了。',
          '教室里的香薰烧得太旺，让人有点头晕。',
          '窗外的天色阴沉，像是要下雪。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'ask_teacher',
            text: '下课后追上去问老师到底看到了什么',
            consequence:
                '她说得含含糊糊，只说"茶叶每天都不一样，别太当真"。但她说话的时候没有看你，这比任何具体的预言都更让你记住。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['poa_tea_reading'], setFlags: ['poa_asked_divination'], spirit: -2),
          ),
          StoryChoiceDef(
            id: 'don_believe',
            text: '把这件事当成一节课的玩笑翻过去',
            consequence:
                '你把杯子还回去，跟同学笑着说刚才那个形状像只狗。大家笑了，气氛轻松了起来。走出教室的时候，你其实没在笑。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['poa_dismissed_tea'], spirit: 1),
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch3_after_boggart',
        chapterId: 'poa_ch3',
        timeCostDays: 1,
        setup:
            '博格特那堂课之后，走廊上的气氛变了几天。'
            '有人互相打听"你看到的是什么"，'
            '被问到的人都笑着说没什么——'
            '然后当天晚上把床帘拉得比平时更严。',
        ambient: [
          '有人在盥洗室里待了很久，出来时眼睛是红的。',
          '黑魔法防御术教室的柜子被搬到了角落，蒙上了布。',
          '有人开始绕远路，就为了不经过那间教室。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'find_answer',
            text: '去图书馆查博格特到底是怎么运作的',
            consequence:
                '你查了三天，最后在一本旧书上找到一句话：'
                '"它没有自己的形状，只有你的。"'
                '知道这一点并没有让恐惧变小——'
                '但你不再觉得那是自己一个人的问题了。',
            effect: StoryEffect(
              addKnowledge: ['poa_boggart_theory'],
              setFlags: ['poa_studied_fear'],
              reputation: 2,
              housePoints: 2,
            ),
            nextStepId: 'poa_ch3_creatures',
          ),
          StoryChoiceDef(
            id: 'help_classmate',
            text: '去问那天反应最大的同学怎么样了',
            consequence:
                '你找到他的时候他正在擦一支笔，擦了很久。'
                '你什么也没问，就坐在旁边陪着。'
                '后来他忽然说："它变成了我爸。"'
                '然后就没再说了。',
            effect: StoryEffect(
              addKnowledge: ['poa_saw_others_fear'],
              setFlags: ['poa_supported_peer'],
              affection: 3,
              spirit: 1,
              targetNpcId: 'neville',
            ),
            nextStepId: 'poa_ch3_creatures',
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch3_creatures',
        chapterId: 'poa_ch3',
        timeCostDays: 3,
        setup:
            '神奇动物保护的课在禁林边上。海格掀开栅栏上的帆布，'
            '里面站着一只半鹰半马的东西，正用一只琥珀色的眼睛看你。'
            '他说：先鞠躬，等它回礼，然后才能靠近。',
        ambient: [
          '它每踏一步，地上的落叶就往两边分开。',
          '海格的手很大，拍你肩膀时你差点往前踉跄。',
          '有人在小声赌谁会第一个被踢。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'bow_patiently',
            text: '按规矩鞠躬，然后一动不动地等',
            consequence:
                '你鞠了躬，然后屏住呼吸等着。它看了你很久，'
                '久到你膝盖开始发酸——然后它弯下前腿，回了一礼。'
                '海格在旁边乐得直拍大腿。',
            effect: StoryEffect(
              setFlags: ['poa_buckbeak_friend'],
              addKnowledge: ['poa_hippogriff_bow'],
              affection: 3,
              reputation: 2,
              targetNpcId: 'hagrid',
            ),
          ),
          StoryChoiceDef(
            id: 'watch_first',
            text: '先站在圈外，看清楚它的脾气再说',
            consequence:
                '你在圈外看了半节课：它对耐心的人友好，'
                '对咋呼的人会竖起羽毛。轮到你时你照着做，'
                '一次就过了——有时候看比冲更管用。',
            effect: StoryEffect(
              addKnowledge: ['poa_hippogriff_temper'],
              setFlags: ['poa_care_creatures'],
              affection: 2,
              targetNpcId: 'hagrid',
            ),
          ),
          StoryChoiceDef(
            id: 'offer_food',
            text: '从口袋里掏出一点能喂的东西',
            consequence:
                '你摸出半块馅饼举在手心。它低头闻了闻，没吃，'
                '但也没有走开。海格说："它记人了。"'
                '从那天起它每次见你都会先看你的手。',
            effect: StoryEffect(
              addItems: ['南瓜馅饼'],
              setFlags: ['poa_buckbeak_friend'],
              addKnowledge: ['poa_hippogriff_bond'],
              affection: 2,
              targetNpcId: 'hagrid',
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch3_creatures_class',
        chapterId: 'poa_ch3',
        timeCostDays: 1,
        setup:
            '海格的第一堂课把所有人都带到了城堡外面。'
            '他站在一片空地上，笑得很用力，'
            '身后是几个盖着布的大笼子。'
            '他说这门课"没有课本"，因为他觉得课本没用。',
        ambient: [
          '笼子里传出很重的呼吸声，节奏不像任何一种你知道的动物。',
          '有人已经开始悄悄往后退了。',
          '海格不停地搓手，好像比你们还紧张。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'step_up',
            text: '第一个站出来，说愿意试试',
            consequence:
                '你走到笼子前面。海格的眼睛一下子亮了，'
                '他把布揭开一条缝，让你看里面。'
                '你只看到了一只眼睛——很大，很安静，正在看你。'
                '他说："好样的，好样的。"',
            effect: StoryEffect(
              setFlags: ['poa_first_to_step_up'],
              affection: 4,
              spirit: 2,
              reputation: 2,
              targetNpcId: 'hagrid',
            ),
            nextStepId: 'poa_ch3_defense',
          ),
          StoryChoiceDef(
            id: 'take_notes',
            text: '先站到后面，把海格说的每句话记下来',
            consequence:
                '你记了整整两页：喂食时间、不能做的动作、'
                '以及一句"它们其实很记仇，但也记好"。'
                '这堂课你没摸着任何动物，'
                '但期末实操的时候，你是班里唯一没做错手势的人。',
            effect: StoryEffect(
              addKnowledge: ['poa_creature_notes'],
              setFlags: ['poa_took_notes'],
              housePoints: 3,
            ),
            nextStepId: 'poa_ch3_defense',
          ),
          StoryChoiceDef(
            id: 'skeptic',
            text: '小声跟旁边的人说这课迟早要出大事',
            consequence:
                '你说对了。你当时很得意。'
                '但后来出事的时候，你也在场——'
                '而且你什么都没做。这句话你后悔了很久。',
            effect: StoryEffect(
              setFlags: ['poa_called_it'],
              spirit: -1,
              housePoints: 1,
            ),
            nextStepId: 'poa_ch3_defense',
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch3_defense',
        chapterId: 'poa_ch3',
        timeCostDays: 3,
        setup:
            '黑魔法防御术今年换了新老师。他看起来总是很累，'
            '讲课却比谁都认真。第一节课他没讲防御，'
            '而是问了全班一个问题：你最害怕的东西是什么？',
        ambient: [
          '教室后排那个一直缺课的位子，今年第一次坐了人。',
          '讲台上放着一个带锁的箱子，上面贴着新封条。',
          '窗外有只鸟撞了一下玻璃，全班都转了头。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'answer_honest',
            text: '老老实实说出自己怕的东西',
            consequence:
                '你说了。声音不大，但全班都听见了。'
                '老师点点头，说"说出来就好办了"，'
                '然后教你把那个东西想象成一件滑稽的衣服。'
                '荒唐，但你后来真的用上了。',
            effect: StoryEffect(
              addKnowledge: ['poa_boggart_trick'],
              setFlags: ['poa_patronus_attempt'],
              spirit: 3,
              reputation: 1,
            ),
            nextStepId: 'poa_ch3_practice',),
          StoryChoiceDef(
            id: 'help_classmate',
            text: '旁边的人答不上来，你替他圆了一句',
            consequence:
                '旁边那人站在那儿张着嘴，你小声提醒了他一个词。'
                '他顺着说下去，坐下的時候冲你比了个手势。'
                '一节课而已，但你多了一个会替你留座的人。',
            effect: StoryEffect(
              setFlags: ['poa_helped_peer'],
              affection: 2,
              reputation: 1,
              targetNpcId: 'seamus',
            ),
            nextStepId: 'poa_ch3_practice',),
          StoryChoiceDef(
            id: 'note_teacher',
            text: '留意他为什么每个月总有几天不来',
            consequence:
                '你注意到他缺课的日子和月亮的圆缺对得上。'
                '你把这件事写在本子最后一页，又划掉了——'
                '有些问题，问出来就是冒犯。',
            effect: StoryEffect(
              addKnowledge: ['poa_lupin_pattern'],
              spirit: -1,
            ),
            nextStepId: 'poa_ch3_practice',),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch3_practice',
        chapterId: 'poa_ch3',
        timeCostDays: 1,
        setup:
            '黑魔法防御术的课桌被推到了教室两边，中间空出一块地方。这学期的课终于不再是念课文了——要动手。',
        ambient: [
          '有人被叫上去示范，紧张得连咒语都念反了。',
          '柜子里锁着的东西在轻轻撞门。',
          '窗外飘起了今年第一场雪。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'volunteer',
            text: '举手上去第一个试',
            consequence:
                '你走到教室中间，手心全是汗。第一次什么都没发生，第二次有一小团银色的雾。老师点了点头，说"比大多数人都强"。那一天你走路都轻快了些。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['poa_basic_defense'], setFlags: ['poa_practiced_defense'], spirit: 5),
          ),
          StoryChoiceDef(
            id: 'watch_others',
            text: '先看别人怎么做，把要点记下来',
            consequence:
                '你站在旁边，把每个人失败的原因都看了一遍：咒语念太快、魔杖角度偏、心里在害怕。轮到你的时候，这些错误一个都没犯。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['poa_basic_defense'], setFlags: ['poa_learned_by_watching'], spirit: 3),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第四章 · 霍格莫德的周末（1993 年 11 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'poa_ch4',
    bookId: 'poa',
    ordinal: 4,
    title: '霍格莫德的周末',
    steps: [
      StoryStepDef(
        id: 'poa_ch4_permit',
        canonRefId: 'canon_poa_quidditch_storm',
        chapterId: 'poa_ch4',
        timeCostDays: 3,
        setup:
            '三年级最大的特权来了：一张需要家长签字的同意表。'
            '签了，你就能在周末去霍格莫德村；不签，'
            '你就只能在城堡里看着别人回来时鞋上的雪。',
        ambient: [
          '表格最后一行很小：未满十三岁不予批准。',
          '有人已经在讨论第一家该进哪家店了。',
          '你看着签名栏，笔尖悬在那儿。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'send_home',
            text: '老老实实寄回家签字',
            consequence:
                '你把表格寄了回去，等了四天。回信里除了签名，'
                '还多了一句："别一个人走夜路。"'
                '你把那张纸夹在书里，一直留到学年结束。',
            effect: StoryEffect(
              setFlags: ['poa_first_village'],
              addItems: ['手写贺卡'],
              spirit: 2,
            ),
          ),
          StoryChoiceDef(
            id: 'borrow_ink',
            text: '找人借笔，把字练端正了再交',
            consequence:
                '你借了支好笔，把手写体练了三遍才正式签。'
                '级长收表时看了你一眼，说"字不错"。'
                '你后来才发现，那张表是要存档的。',
            effect: StoryEffect(
              setFlags: ['poa_first_village'],
              addItems: ['银色钢笔'],
              reputation: 1,
              affection: 1,
              targetNpcId: 'percy',
            ),
          ),
          StoryChoiceDef(
            id: 'stay_behind',
            text: '先不交，把周末留给图书馆',
            consequence:
                '你把表压在抽屉底，第一个周末去了图书馆。'
                '安静是安静，但走廊里偶尔传回来的笑声让你有点后悔——'
                '也不是真后悔，只是记下了。',
            effect: StoryEffect(
              addKnowledge: ['poa_library_weekend'],
              spirit: 1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch4_village',
        chapterId: 'poa_ch4',
        timeCostDays: 19,
        canonRefId: 'canon_poa_hogsmeade',
        setup:
            '第一次进村。雪把路面压出一条条车辙，'
            '蜂蜜公爵的橱窗里糖在跳，风一吹，'
            '整条街都是甜的和烤面包的味道。',
        ambient: [
          '三把扫帚的门一开，暖气和笑声一起扑出来。',
          '有人从你身边跑过，怀里抱着一整袋会叫的糖。',
          '村口那栋挂着"闹鬼"牌子的屋子，窗帘动了一下。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'butterbeer',
            text: '进三把扫帚，点一杯黄油啤酒',
            consequence:
                '你捧着那杯东西坐在窗边，甜得发腻，暖得踏实。'
                '老板娘擦着杯子跟你搭话，说今年村里的客人'
                '比往年安静多了。她说的是"安静"，不是"少"。',
            effect: StoryEffect(
              addItems: ['黄油啤酒'],
              setFlags: ['poa_rosmerta_talk'],
              addKnowledge: ['poa_village_mood'],
              affection: 2,
              spirit: 2,
              targetNpcId: 'rosmerta',
            ),
            nextStepId: 'poa_ch4_sweetshop',),
          StoryChoiceDef(
            id: 'sweet_shop',
            text: '直奔蜂蜜公爵，把零花钱花光',
            consequence:
                '你把所有铜纳特换成了会跳的糖和会咬人的糖。'
                '回程路上你分了一半给同路的人，'
                '结果整个学期都有人在走廊里问你还有没有。',
            effect: StoryEffect(
              addItems: ['酸味爆弹', '巧克力蛙'],
              setFlags: ['poa_first_village'],
              reputation: 2,
              spirit: 2,
            ),
            nextStepId: 'poa_ch4_sweetshop',),
          StoryChoiceDef(
            id: 'shrieking_shack',
            text: '跟队伍走到村尾，看那栋闹鬼的屋子',
            consequence:
                '你们在栅栏外站了一会儿。那屋子没有一扇窗是完整的，'
                '据说夜里会传出声音。带队的高年级生催你们走，'
                '说那地方"不是给你们看的"。你们谁也没反驳。',
            effect: StoryEffect(
              setFlags: ['poa_shrieking_rumor'],
              addKnowledge: ['poa_shack_legend'],
              spirit: -1,
            ),
            nextStepId: 'poa_ch4_sweetshop',),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch4_sweetshop',
        chapterId: 'poa_ch4',
        timeCostDays: 3,
        setup:
            '糖果店里的货架高得顶到天花板，每一格都塞满了名字古怪的东西。店里很暖，玻璃上蒙着一层水雾。',
        ambient: [
          '有学生在柜台前争最后一块酸味糖。',
          '店员用一把长夹子去够最上层的罐子。',
          '窗外的雪积在窗台上，被人画了个笑脸。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'share_bag',
            text: '买一大袋，回去分给没能来的室友',
            consequence:
                '你把糖倒在宿舍的桌上，没去成村子的那个人先是愣了一下，然后笑着抓了一把。有些遗憾是能被一颗糖补回来的。',
            nextStepId: '',
            effect: StoryEffect(addItems: ['酸味爆弹'], setFlags: ['poa_shared_sweets'], spirit: 4, targetNpcId: 'ron', affection: 2),
          ),
          StoryChoiceDef(
            id: 'buy_alone',
            text: '只挑自己想吃的，慢慢逛',
            consequence:
                '你在店里待了很久，把每一罐都看了一遍。最后只买了一小袋。出门的时候风很冷，但心里挺满。',
            nextStepId: '',
            effect: StoryEffect(addItems: ['酸味爆弹'], setFlags: ['poa_shopped_alone'], spirit: 2),
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch4_shrieking',
        canonRefId: 'canon_poa_dementor_patrol',
        chapterId: 'poa_ch4',
        timeCostDays: 17,
        setup:
            '那栋屋子成了三年级的集体话题。有人说那是全英国'
            '最闹鬼的房子，有人说那只是风。'
            '还有人说——它和城堡之间有一条地道。',
        ambient: [
          '图书馆里关于它的三本书都被借空了。',
          '有人画了张草图在传，画得歪歪扭扭。',
          '你翻地图时发现，那栋屋子离打人柳不远。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'map_it',
            text: '借张地图，把地道可能的走向标出来',
            consequence:
                '你在地图上标了三个可能的入口，其中一个'
                '正好在城堡地下一层。你把地图还给书架，'
                '但那三个点记住了。',
            effect: StoryEffect(
              addItems: ['全效望远镜'],
              addKnowledge: ['poa_passage_map'],
              setFlags: ['poa_shrieking_rumor'],
              spirit: 1,
            ),
          ),
          StoryChoiceDef(
            id: 'ask_creature_class',
            text: '拿这事去问神奇动物保护的老师',
            consequence:
                '海格听完之后表情有点僵，说那房子"没什么好看的"，'
                '然后就转身去搬饲料了。他搬得比平时快。'
                '你意识到自己可能问错了人。',
            effect: StoryEffect(
              addKnowledge: ['poa_shack_taboo'],
              setFlags: ['poa_care_creatures'],
              affection: 1,
              targetNpcId: 'hagrid',
            ),
          ),
          StoryChoiceDef(
            id: 'drop_it',
            text: '不再打听，把好奇心收回来',
            consequence:
                '你把草图还给了人家，说自己不感兴趣了。'
                '其实还是好奇——但你学会了，'
                '有些门就算开着，也不该由你去推。',
            effect: StoryEffect(
              setFlags: ['poa_helped_peer'],
              spirit: 1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch4_spring',
        chapterId: 'poa_ch4',
        timeCostDays: 12,
        setup:
            '复活节假期留校的人很少。'
            '球场又一次没有开——这已经是这个学年第三次。'
            '摄魂怪的巡逻范围向外扩了一圈，'
            '连禁林边缘都不让靠近了。',
        ambient: [
          '草长得比往年高，没人来割。',
          '有人在空球门下面坐着，坐了一下午。',
          '天气开始回暖，但城堡里的人比冬天还安静。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'use_fields',
            text: '和几个同学偷偷把球门柱修了修',
            consequence:
                '你们弄来了工具，修了三个下午。'
                '没人在意这件事算不算违反校规——'
                '反正球场已经空了大半年，修好它不会伤到谁。'
                '完工那天有人带了球来，你们投了十几分钟。',
            effect: StoryEffect(
              setFlags: ['poa_repaired_pitch', 'poa_care_taken'],
              reputation: 3,
              spirit: 4,
              energy: -10,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'study_instead',
            text: '把时间都花在功课上',
            consequence:
                '你把这个春天过成了一段很长的自习。'
                '成绩单上多了几个不错的数字，'
                '代价是你现在想起来，那半年几乎没剩下什么画面。',
            effect: StoryEffect(
              addKnowledge: ['poa_quiet_spring'],
              setFlags: ['poa_buried_in_books'],
              housePoints: 3,
              spirit: -1,
            ),
            nextStepId: '',
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第五章 · 圣诞与寒雾（1993 年 12 月 - 1994 年 1 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'poa_ch5',
    bookId: 'poa',
    ordinal: 5,
    title: '圣诞与寒雾',
    steps: [
      StoryStepDef(
        id: 'poa_ch5_christmas',
        canonRefId: 'canon_poa_patronus_lesson',
        chapterId: 'poa_ch5',
        timeCostDays: 19,
        setup:
            '留校过圣诞的人比想象中多。今年城堡里挂着霜，'
            '礼堂的火炉烧得比往年旺，但坐在炉边的人'
            '还是会把毯子裹紧一点。',
        ambient: [
          '有人从家里寄来的包裹堆在长桌上，没人急着拆。',
          '窗外湖面全冻住了，白得看不到边。',
          '唱诗班的画像今年唱得格外小声。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'stay_organize',
            text: '留校，把假期过成一场小型聚会',
            consequence:
                '你留了下来，和一屋子同样没走的人过了两周。'
                '有人带了糖，有人带了牌，有人弹跑了调的琴。'
                '那两周你几乎忘了城堡外面还有东西在飘。',
            effect: StoryEffect(
              setFlags: ['poa_christmas_stay'],
              addItems: ['巧克力蛙', '手写贺卡'],
              reputation: 2,
              affection: 2,
              spirit: 3,
              targetNpcId: 'fred',
            ),
            nextStepId: 'poa_ch5_feast',),
          StoryChoiceDef(
            id: 'go_home',
            text: '回家，把城堡的冬天留在身后',
            consequence:
                '你回了家。家里的窗不结霜，饭是热的，'
                '但你总在半夜醒一次，以为听见了什么。'
                '返校那天你提早到了站台——不知道为什么。',
            effect: StoryEffect(
              addKnowledge: ['poa_home_winter'],
              spirit: 1,
            ),
            nextStepId: 'poa_ch5_feast',),
          StoryChoiceDef(
            id: 'write_letters',
            text: '给留校的人每人写一张卡片',
            consequence:
                '你写了十几张卡片，托猫头鹰一张张送出去。'
                '回信只有三封，但其中一封写着：'
                '"谢谢你，我今天过得好多了。"',
            effect: StoryEffect(
              setFlags: ['poa_helped_peer'],
              addItems: ['手写贺卡', '新羽毛笔'],
              reputation: 2,
              affection: 2,
              targetNpcId: 'hannah',
            ),
            nextStepId: 'poa_ch5_feast',),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch5_feast',
        chapterId: 'poa_ch5',
        timeCostDays: 14,
        setup:
            '圣诞晚餐的桌子上多摆了几副空碗筷，留给那些没有回家的人。大礼堂的蜡烛比平时矮了一截，光显得很温。',
        ambient: [
          '有人用巫师棋换了一盘糖果，输得很惨。',
          '壁炉边的猫蜷成一团，谁也不理。',
          '窗外的雪把整个操场的轮廓都抹平了。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'join_table',
            text: '坐到那群留校的人中间去',
            consequence:
                '你原本打算自己安静吃完就走，但有人给你挪了个位置。整顿饭下来你说了比整个学期加起来还多的话。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['poa_joined_feast'], spirit: 6, targetNpcId: 'ginny', affection: 2),
          ),
          StoryChoiceDef(
            id: 'eat_quietly',
            text: '挑个角落的位置，自己慢慢吃',
            consequence:
                '你听着别人的笑声，不觉得孤单，也不觉得想加入。这样也挺好——安静本身也是一种过节的方式。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['poa_ate_alone'], spirit: 3),
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch5_lake',
        canonRefId: 'canon_poa_marauders_map',
        chapterId: 'poa_ch5',
        timeCostDays: 17,
        setup:
            '一月的湖冻得能走人，然后就出事了：'
            '有人在冰上遇见了它们，回来说自己的腿'
            '在之后的三天里都站不直。从此冰面被划了禁区。',
        ambient: [
          '湖边插了木牌，字写得很急。',
          '医务室的灯那几天一直亮到后半夜。',
          '你站在走廊窗前往下看，湖面白得发蓝。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'visit_infirmary',
            text: '去医务室看看那个人',
            consequence:
                '你去了。那人半坐在床上，说自己不记得摔倒的过程，'
                '只记得"冷得不像话"。你把带来的糖放在床头，'
                '出门时手一直在抖。',
            effect: StoryEffect(
              addItems: ['白鲜香精'],
              setFlags: ['poa_helped_peer'],
              addKnowledge: ['poa_dementor_aftermath'],
              reputation: 2,
              spirit: -2,
            ),
            nextStepId: 'poa_ch5_ice',),
          StoryChoiceDef(
            id: 'mark_danger',
            text: '把湖边每条能下到冰上的路都记下来',
            consequence:
                '你花了三个傍晚把湖岸走了一遍，'
                '记下七处能下到冰面的缺口，抄了一份交给级长。'
                '级长说你多事，但还是收下了。',
            effect: StoryEffect(
              addKnowledge: ['poa_lake_blacklist'],
              setFlags: ['poa_brave_train'],
              reputation: 2,
              affection: 1,
              targetNpcId: 'percy',
            ),
            nextStepId: 'poa_ch5_ice',),
          StoryChoiceDef(
            id: 'avoid_windows',
            text: '绕开所有能看见湖的走廊',
            consequence:
                '你开始绕远路。多走五分钟，'
                '换来一整天不用想起那片白色。'
                '你承认这是逃避，但冬天这么长，'
                '总得给自己留条好走的路。',
            effect: StoryEffect(
              addKnowledge: ['poa_avoidance_route'],
              spirit: 1,
            ),
            nextStepId: 'poa_ch5_ice',),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch5_library',
        chapterId: 'poa_ch5',
        timeCostDays: 8,
        setup:
            '一月开始，图书馆靠里的三排书架被划走了。'
            '平斯夫人说那是"校方安排"，不肯多说。'
            '被划走的那三排，恰好是最常被借的那三排。'
            '有个斯莱特林的学生因为伸手去够最上面一层，被记了名字。',
        ambient: [
          '黄铜链子拉在书架之间，比平时紧绷得多。',
          '有人隔着链子往里面看，看了很久。',
          '平斯夫人在桌子之间巡视的次数，比往常多了一倍。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'find_elsewhere',
            text: '去公共休息室翻学生留下的旧笔记',
            consequence:
                '你在旧物柜里翻到一本高年级留下的笔记本，'
                '里面抄了不少被划走的书的内容——抄得很潦草，但够用。'
                '你把它借了三天，抄完还了回去。',
            effect: StoryEffect(
              addKnowledge: ['poa_borrowed_notes'],
              setFlags: ['poa_made_do'],
              housePoints: 2,
              galleons: 2,
            ),
            nextStepId: 'poa_ch5_ice',
          ),
          StoryChoiceDef(
            id: 'ask_why',
            text: '去问平斯夫人为什么',
            consequence:
                '她说："因为有人在书里夹了不该夹的东西。"'
                '你追问是什么东西，她把借书章重重盖了一下，'
                '说："这不是你该操心的。"',
            effect: StoryEffect(
              addKnowledge: ['poa_library_reason'],
              setFlags: ['poa_asked_librarian'],
              housePoints: 2,
            ),
            nextStepId: 'poa_ch5_ice',
          ),
          StoryChoiceDef(
            id: 'stay_clear',
            text: '不去碰，把复习范围缩到还开着的那几排',
            consequence:
                '你把复习计划改了一遍，只用能拿到的书。'
                '这么做很安全，也确实没耽误考试。'
                '只是那年冬天你想查的很多东西，最后都没查到。',
            effect: StoryEffect(
              setFlags: ['poa_played_safe'],
              housePoints: 1,
              spirit: -1,
            ),
            nextStepId: 'poa_ch5_ice',
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch5_ice',
        chapterId: 'poa_ch5',
        timeCostDays: 9,
        setup:
            '湖面结了冰，黑校袍的学生在冰上滑来滑去。有人在冰上摔了个四脚朝天，周围笑成一片。',
        ambient: [
          '冰面偶尔传来一声闷响，那是下面的水在动。',
          '有人用魔杖在冰上刻字，刻完就化掉了。',
          '远处城堡的窗户一盏盏亮起来。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'join_skating',
            text: '脱了大衣下去滑',
            consequence:
                '你摔了三次，最后一次是被别人拉起来的。回到岸上的时候手指冻得没知觉，但你笑得比谁都大声。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['poa_skated'], spirit: 6),
          ),
          StoryChoiceDef(
            id: 'stay_bank',
            text: '站在岸上帮人看东西',
            consequence:
                '你守着堆成一堆的围巾和手套，看着他们在冰上翻来覆去。后来每个人都回来跟你说谢谢，这感觉比滑冰还好。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['poa_watched_skating'], reputation: 2, spirit: 3),
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch5_patronus',
        chapterId: 'poa_ch5',
        timeCostDays: 16,
        setup:
            '传闻开始流行：有人看见一道银色的东西从湖边冲过去，'
            '把那一整片都逼退了。没人说得出那是什么，'
            '但从此之后，课后走廊里多了很多举着魔杖练习的人。',
        ambient: [
          '有人在空教室里练得满头汗，什么也没练出来。',
          '那道银色的东西被传成了三种不同的动物。',
          '你的魔杖尖今天只冒出过一点白雾。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'practice_daily',
            text: '每天抽半小时，对着同一个记忆练',
            consequence:
                '你练了整整一个月。最好的一次，'
                '杖尖凝出一团看不出形状的雾，撑了两秒就散了。'
                '但你把那段记忆越擦越亮——它现在真的能挡点什么了。',
            effect: StoryEffect(
              setFlags: ['poa_patronus_attempt'],
              addKnowledge: ['poa_patronus_practice'],
              spirit: 3,
              reputation: 1,
            ),
          ),
          StoryChoiceDef(
            id: 'ask_defense_teacher',
            text: '课后去问那位老师，能不能教一点',
            consequence:
                '他听完你的请求，沉默了一会儿，'
                '然后说三年级学这个太早，但他可以教你怎么'
                '在它们靠近时保持清醒。他说："清醒已经是本事。"',
            effect: StoryEffect(
              setFlags: ['poa_patronus_attempt'],
              addKnowledge: ['poa_stay_awake'],
              spirit: 2,
              reputation: 1,
            ),
          ),
          StoryChoiceDef(
            id: 'spread_word',
            text: '把"想想最好的那件事"教给一年级生',
            consequence:
                '你在楼梯口拦住几个一年级生，'
                '教他们挑一段最亮的记忆攥在手里。'
                '两周后有个小孩跑来跟你说：真的有用。',
            effect: StoryEffect(
              setFlags: ['poa_helped_peer'],
              reputation: 3,
              affection: 2,
              targetNpcId: 'colin',
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第六章 · 鹰头马身有翼兽（1994 年 4 月）→ canon_poa_buckbeak
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'poa_ch6',
    bookId: 'poa',
    ordinal: 6,
    title: '鹰头马身有翼兽',
    steps: [
      StoryStepDef(
        id: 'poa_ch6_incident',
        chapterId: 'poa_ch6',
        timeCostDays: 12,
        setup:
            '消息是从医务室传出来的：那堂课上有学生被伤了，'
            '而承担责任的是那头动物。通告贴在公告栏上，'
            '措辞客气，结论却写得很死。',
        ambient: [
          '公告栏前的人散得很快，像怕被看见站在这儿。',
          '海格三天没在餐厅露面。',
          '栅栏那边现在空着，帆布被风吹得翻过来。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'read_notice',
            text: '把通告逐句读完，记住它的措辞',
            consequence:
                '你注意到通告里没有一句话提到"谁先动了手"。'
                '它只说动物是危险的。你把这句抄了下来，'
                '虽然还不知道能拿它做什么。',
            effect: StoryEffect(
              addKnowledge: ['poa_notice_wording'],
              setFlags: ['poa_care_creatures'],
              spirit: -1,
            ),
          ),
          StoryChoiceDef(
            id: 'visit_hagrid',
            text: '去小屋那边看看那位老师',
            consequence:
                '你去了。他正在给一筐萝卜削皮，动作很慢。'
                '他说没事，又说"它只是没被礼貌对待过"。'
                '你要走时他往你兜里塞了几个烤饼。',
            effect: StoryEffect(
              setFlags: ['poa_buckbeak_friend'],
              addItems: ['坩埚蛋糕'],
              affection: 3,
              reputation: 1,
              targetNpcId: 'hagrid',
            ),
          ),
          StoryChoiceDef(
            id: 'ask_victim_side',
            text: '去问问当时在场的人到底发生了什么',
            consequence:
                '你问了三个在场的人，拼出另一版本：'
                '有人先挑衅，也忘了鞠躬。你把三份说法写在纸上，'
                '纸很轻，分量却重。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包'],
              addKnowledge: ['poa_incident_testimony'],
              setFlags: ['poa_hearing_witness'],
              reputation: 2,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch6_hearing',
        chapterId: 'poa_ch6',
        timeCostDays: 14,
        canonRefId: 'canon_poa_buckbeak',
        setup:
            '听证会那天，城堡里一半的人想去看，'
            '能进场的只有几个。你挤在门外的人群里，'
            '隔着两道墙听见了锤子落下的声音。',
        ambient: [
          '走廊上站满了人，没人说话。',
          '有个高年级生把手里的纸捏成了一团。',
          '锤声响了三下，人群像被抽了一下。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'stand_outside',
            text: '站在门外，等结果出来',
            consequence:
                '你站着等了近两个小时。门开的时候，'
                '最先出来的人眼睛是红的。你没问结果——'
                '你从那张脸上已经读到了。',
            effect: StoryEffect(
              setFlags: ['poa_hearing_witness'],
              addKnowledge: ['poa_verdict'],
              spirit: -2,
              reputation: 1,
            ),
            nextStepId: 'poa_ch6_after_hearing',),
          StoryChoiceDef(
            id: 'pass_evidence',
            text: '把手上那份说法递给能进场的人',
            consequence:
                '你把那张纸塞进一个正要进去的学长手里，'
                '说了句"这个也许有用"。他没答应什么，'
                '但进门前回头看了你一眼。',
            effect: StoryEffect(
              setFlags: ['poa_hearing_witness'],
              addKnowledge: ['poa_evidence_handed'],
              reputation: 3,
              affection: 2,
              targetNpcId: 'cedric',
            ),
            nextStepId: 'poa_ch6_after_hearing',),
          StoryChoiceDef(
            id: 'walk_away',
            text: '转身回图书馆，不去等那个结果',
            consequence:
                '你走回了图书馆，一页书也没看进去。'
                '傍晚有人带回消息时，你正盯着同一行字。'
                '后来你想，那两个小时你其实哪儿也没去。',
            effect: StoryEffect(
              addKnowledge: ['poa_verdict_secondhand'],
              spirit: -1,
            ),
            nextStepId: 'poa_ch6_after_hearing',),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch6_after_hearing',
        chapterId: 'poa_ch6',
        timeCostDays: 5,
        setup:
            '判决下来的那天，消息传得比风还快。有人愤愤不平，有人不说话，更多的人只是低着头继续走路。',
        ambient: [
          '走廊里的画像在窃窃私语，看见学生就闭嘴。',
          '公告栏前围了一圈人，看完就走。',
          '窗外的天比平时更灰，像是要下雨又下不出来。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'sign_petition',
            text: '在一份请大家联名的纸上签了名',
            consequence:
                '你不知道这份东西有没有用，但签名的时候你的手很稳。有些人签完就走了，有些人站在旁边看了很久。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['poa_signed_petition'], reputation: 3, spirit: 2),
          ),
          StoryChoiceDef(
            id: 'walk_away',
            text: '什么也没做，只是走开',
            consequence:
                '你从公告栏前走过去了。回到宿舍以后你想了很久——有些事你确实做不了什么，但"做不了"和"不做"是两回事。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['poa_walked_away'], spirit: -3),
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch6_after_verdict',
        chapterId: 'poa_ch6',
        timeCostDays: 7,
        setup:
            '裁决下来那天，消息传得很快。'
            '海格从早上就没在城堡里出现，'
            '小屋的灯亮着，但门被敲了两次都没开。'
            '没有人知道该说什么——这件事本来就不该由学生来安慰。',
        ambient: [
          '小屋门口被人放了两块糖，第二天还在，第三天不见了。',
          '有人说听见屋里有劈柴的声音，很晚才停。',
          '草药课暂停了一次，代课的是另一位老师。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'leave_gift',
            text: '去小屋门口放点东西，不留名字',
            consequence:
                '你把一包从霍格莫德带回来的糖果放在台阶上，'
                '敲了一下门就走了。'
                '后来你一直不知道他有没有看到那句话——'
                '你在包装纸上写了"不是你的错"。',
            effect: StoryEffect(
              setFlags: ['poa_kind_to_hagrid'],
              affection: 4,
              spirit: 2,
              targetNpcId: 'hagrid',
            ),
            nextStepId: 'poa_ch6_waiting',
          ),
          StoryChoiceDef(
            id: 'ask_professor',
            text: '去找教授问清到底发生了什么',
            consequence:
                '教授听完你的问题，沉默了一会儿，'
                '然后只说了两句：'
                '"程序走完了"和"这不是你们能改变的事"。'
                '你从他脸上看出来，他自己也不认同这个结果。',
            effect: StoryEffect(
              addKnowledge: ['poa_verdict_unjust'],
              setFlags: ['poa_saw_faculty_doubt'],
              housePoints: 2,
            ),
            nextStepId: 'poa_ch6_waiting',
          ),
          StoryChoiceDef(
            id: 'stay_away',
            text: '不去打扰，让他自己待着',
            consequence:
                '你什么都没做。'
                '这件事你后来想起过很多次——'
                '每次都觉得自己当时至少该走过去敲一次门。',
            effect: StoryEffect(
              setFlags: ['poa_stayed_away'],
              spirit: -2,
            ),
            nextStepId: 'poa_ch6_waiting',
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch6_waiting',
        chapterId: 'poa_ch6',
        timeCostDays: 7,
        setup:
            '判决之后是一段等待。执行日期被写在另一张通告上，'
            '没有写明地点。整个四月，城堡里的人走路都很轻，'
            '像怕惊动什么。',
        ambient: [
          '空着的栅栏一直没被拆。',
          '有人在学生中间传一张签名的纸。',
          '你发现自己开始数日子。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'sign_paper',
            text: '在那张联名的纸上签下名字',
            consequence:
                '你签了。名字排在中间，很不起眼。'
                '但你写完抬头时，看见后面还排着三个人——'
                '你不是最后一个，也不是第一个。',
            effect: StoryEffect(
              setFlags: ['poa_buckbeak_friend'],
              addItems: ['计划书'],
              reputation: 2,
              spirit: 2,
            ),
          ),
          StoryChoiceDef(
            id: 'keep_notes',
            text: '把所有时间线记成一份笔记',
            consequence:
                '你把事故、听证、判决的日子排成一条线，'
                '发现中间只隔了十一天。'
                '十一天，就定了一头活物的命。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包'],
              addKnowledge: ['poa_timeline_notes'],
              setFlags: ['poa_care_creatures'],
              reputation: 1,
            ),
          ),
          StoryChoiceDef(
            id: 'check_fence',
            text: '傍晚绕到空栅栏那边站一会儿',
            consequence:
                '你去了。地上还留着蹄印，'
                '被这几天的雨泡得发软。'
                '你站到天黑才回去，什么也没改变，但你去过了。',
            effect: StoryEffect(
              setFlags: ['poa_buckbeak_friend'],
              spirit: -1,
              affection: 1,
              targetNpcId: 'hagrid',
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第七章 · 期末的暗流（1994 年 5-6 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'poa_ch7',
    bookId: 'poa',
    ordinal: 7,
    title: '期末的暗流',
    steps: [
      StoryStepDef(
        id: 'poa_ch7_exams',
        canonRefId: 'canon_poa_exam_month',
        chapterId: 'poa_ch7',
        timeCostDays: 11,
        setup:
            '考试周来了。今年的考场比往年冷，'
            '监考的老师们站在后面，'
            '目光总往窗外飘。'
            '有传闻说，摄魂怪已经撤走了，但谁也不敢先说出来。',
        ambient: [
          '有人在考场上把墨水打翻了，整张卷子报废。',
          '走廊里贴着"考完请不要在走廊逗留"。',
          '你的复习笔记翻到了最后一页。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'study_group',
            text: '拉几个人组复习小组，互相抽背',
            consequence:
                '你们在角落里互相抽背了六个晚上。'
                '考完那天有人说"比自己一个人念强多了"——'
                '你这次是真的同意。',
            effect: StoryEffect(
              setFlags: ['poa_exam_ready'],
              addItems: ['标准咒语书'],
              reputation: 2,
              affection: 2,
              spirit: 2,
              targetNpcId: 'susan',
            ),
            nextStepId: 'poa_ch7_study',),
          StoryChoiceDef(
            id: 'solo_cram',
            text: '一个人躲进图书馆，按自己的节奏来',
            consequence:
                '你按自己的节奏过了一遍所有科目，'
                '安静、有效，也有点孤独。'
                '成绩出来那天，你发现自己确实考得不错。',
            effect: StoryEffect(
              setFlags: ['poa_exam_ready'],
              addKnowledge: ['poa_solo_study'],
              spirit: 2,
              reputation: 1,
            ),
            nextStepId: 'poa_ch7_study',),
          StoryChoiceDef(
            id: 'help_struggling',
            text: '把笔记借给那个快挂科的人',
            consequence:
                '你把整本笔记借了出去，自己只复习了半本。'
                '他过了，你踩着线也过了。'
                '你事后算了算，觉得这笔买卖不亏。',
            effect: StoryEffect(
              setFlags: ['poa_helped_peer', 'poa_exam_ready'],
              reputation: 3,
              affection: 3,
              targetNpcId: 'neville',
            ),
            nextStepId: 'poa_ch7_study',),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch7_study',
        chapterId: 'poa_ch7',
        timeCostDays: 7,
        setup:
            '考试周的图书馆连过道都坐满了人。你把书摊在膝盖上，周围只有翻页的声音和喷嚏声。你翻到一半，才发现自己已经盯着同一行看了很久。',
        ambient: [
          '有人在桌上堆了七本书，书上又摞了一摞笔记。',
          '窗外的天到十点还没全黑。',
          '管理员推车经过，轮子在地板上发出很轻的吱声。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'study_with_group',
            text: '和几个人拼桌，互相提问',
            consequence:
                '你们把最难的那门课拆成一个个问题轮着问。有人答不上来就翻书，翻到哪页大家一起看。比一个人啃快多了。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['poa_exam_prep'], setFlags: ['poa_studied_group'], spirit: 4),
          ),
          StoryChoiceDef(
            id: 'study_alone',
            text: '找个没人的角落自己看',
            consequence:
                '你在书架最里面找到一张空桌。一口气看到闭馆铃响，中间没有抬过头。效率高得让你自己都吃惊。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['poa_exam_prep'], setFlags: ['poa_studied_alone'], spirit: 2),
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch7_rumors',
        chapterId: 'poa_ch7',
        timeCostDays: 7,
        setup:
            '六月的某个早上，城堡里的气氛忽然不一样了。'
            '没人说得清发生了什么，只知道夜里有人被带走了，'
            '也有人说——真正该走的人，跑了。',
        ambient: [
          '餐厅里第一次出现了压着嗓子的争论。',
          '有位教授当天下午的课临时取消。',
          '你听见两个高年级生说了句"原来如此"，然后闭嘴。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'collect_fragments',
            text: '把听到的碎片一条条写下来，自己拼',
            consequence:
                '你写了七条，拼出了一个大概：'
                '十二年前有人替别人背了罪，今年夏天被翻了出来。'
                '你不能证明，但这个版本比"疯子杀人"讲得通。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包'],
              addKnowledge: ['poa_truth_fragments'],
              setFlags: ['poa_truth_heard'],
              reputation: 1,
              spirit: 1,
            ),
          ),
          StoryChoiceDef(
            id: 'ask_friend_direct',
            text: '直接问那个消息灵通的人到底怎么回事',
            consequence:
                '你问了。那人看了你很久，'
                '最后只说了一句："有些事，知道的人越少越安全。"'
                '你没再问——但你知道他其实是在保护你。',
            effect: StoryEffect(
              setFlags: ['poa_truth_heard'],
              addKnowledge: ['poa_protected_silence'],
              affection: 3,
              reputation: 1,
              targetNpcId: 'hermione',
            ),
          ),
          StoryChoiceDef(
            id: 'stay_out',
            text: '不去打听，把注意力放回自己的行李',
            consequence:
                '你开始收拾行李。城堡里发生的大事'
                '从来不需要你参与，也从来不告诉你全貌。'
                '你把这点想明白了，反而轻松了一点。',
            effect: StoryEffect(
              addKnowledge: ['poa_stayed_out'],
              spirit: 1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch7_patrol_night',
        chapterId: 'poa_ch7',
        timeCostDays: 8,
        setup:
            '考试月的某个夜里，城堡里响了一次警报。'
            '所有人都被要求留在公共休息室，'
            '级长在门口站到天亮。'
            '第二天早上什么都没查出来，但那张通缉令又被贴了一张新的。',
        ambient: [
          '级长的椅子在门口摆了一夜，椅背上搭着他的校袍。',
          '有人趴在桌上睡着了，手里还攥着复习提纲。',
          '黎明时窗外有影子掠过——后来知道那只是一只猫头鹰。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'keep_studying',
            text: '既然不能出去，就把这一夜用来复习',
            consequence:
                '你在公共休息室的地毯上坐了六个小时，'
                '把魔咒课的重难点过了一遍。'
                '第二个礼拜的实操考试，你答得比平时还稳。',
            effect: StoryEffect(
              addKnowledge: ['poa_exam_night_study'],
              setFlags: ['poa_steady_nerves'],
              housePoints: 3,
              spirit: 1,
            ),
            nextStepId: 'poa_ch7_night',
          ),
          StoryChoiceDef(
            id: 'watch_window',
            text: '守着窗户，想看看到底是什么',
            consequence:
                '你守到了天亮，只看到一次很远的影子。'
                '你不知道那是不是你想的那个人。'
                '但你记住了那一夜城堡外面的黑——'
                '那种黑里什么都可能发生。',
            effect: StoryEffect(
              addKnowledge: ['poa_watch_kept'],
              setFlags: ['poa_saw_the_dark'],
              spirit: -1,
              energy: -5,
            ),
            nextStepId: 'poa_ch7_night',
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch7_night',
        canonRefId: 'canon_poa_time_turner',
        chapterId: 'poa_ch7',
        timeCostDays: 9,
        setup:
            '那天的夜里城堡没有熄灯。有人被叫醒，'
            '走廊里有急促的脚步声。你从床上坐起来，'
            '听见窗外的风里有一声很长很长的嘶鸣。',
        ambient: [
          '公共休息室的火只剩最后一点。',
          '有人在楼梯口压着声音喊另一个人的名字。',
          '你把手放在窗玻璃上，指尖是凉的。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'go_to_window',
            text: '走到窗边，看那声音来自哪里',
            consequence:
                '你看见远处的禁林边上有个影子掠过，'
                '很快，很轻，像是往北去了。'
                '你不确定自己看见什么，但你记住了方向。',
            effect: StoryEffect(
              setFlags: ['poa_truth_heard'],
              addKnowledge: ['poa_night_shape'],
              spirit: -1,
            ),
          ),
          StoryChoiceDef(
            id: 'gather_roommates',
            text: '把同屋的人叫到一起，谁也别乱跑',
            consequence:
                '你把大家叫到壁炉边，数了一遍人数：都在。'
                '你们坐着等到天亮，谁也没睡着，'
                '但第二天早上，没有人觉得害怕得撑不住。',
            effect: StoryEffect(
              setFlags: ['poa_helped_peer'],
              reputation: 3,
              affection: 2,
              spirit: 2,
              targetNpcId: 'parvati',
            ),
          ),
          StoryChoiceDef(
            id: 'write_it_down',
            text: '点灯，把今晚写下来',
            consequence:
                '你在纸上写："今晚城堡没有睡。"'
                '写完你发现这句话能概括整个三年级。'
                '你把纸折好，夹进了这一年的最后一本书里。',
            effect: StoryEffect(
              addItems: ['手写贺卡'],
              addKnowledge: ['poa_night_note'],
              spirit: 2,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第八章 · 学年结束（1994 年 6 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'poa_ch8',
    bookId: 'poa',
    ordinal: 8,
    title: '学年结束',
    steps: [
      StoryStepDef(
        id: 'poa_ch8_lastlesson',
        chapterId: 'poa_ch8',
        timeCostDays: 6,
        setup:
            '最后一节课。神奇动物保护的老师站在空了一半的栅栏前，'
            '说这门课下学期照旧。'
            '黑魔法防御术的那位老师没有来告别。',
        ambient: [
          '教室后排那个位子又空了。',
          '有人把自己的课本塞进了那道栅栏缝里。',
          '你收拾书包时动作比平时慢。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'say_thanks',
            text: '留下来，对那位老师说声谢谢',
            consequence:
                '你留到最后，说了句"谢谢您的课"。'
                '他愣了一下，然后笑得很轻：'
                '"是我该谢你们，这学年不好过。"',
            effect: StoryEffect(
              setFlags: ['poa_stayed_till_end'],
              affection: 3,
              reputation: 2,
              spirit: 2,
              targetNpcId: 'hagrid',
            ),
          ),
          StoryChoiceDef(
            id: 'leave_note',
            text: '在那位空着的课桌上留一张纸条',
            consequence:
                '你写了张纸条压在讲台边上，'
                '上面只有一行："希望您一切都好。"'
                '你没署名——有些关心不需要被记住是谁给的。',
            effect: StoryEffect(
              setFlags: ['poa_stayed_till_end'],
              addItems: ['手写贺卡'],
              reputation: 1,
              spirit: 2,
            ),
          ),
          StoryChoiceDef(
            id: 'clean_desk',
            text: '把自己的课桌擦干净，什么都带走',
            consequence:
                '你把桌子擦得一点墨迹都不留，'
                '带走了所有东西，包括那半截用秃的羽毛笔。'
                '你想让三年级结束得干净一点。',
            effect: StoryEffect(
              setFlags: ['poa_stayed_till_end'],
              spirit: 1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch8_goodbye',
        chapterId: 'poa_ch8',
        timeCostDays: 4,
        setup:
            '最后两天大家在交换地址。有人说四年级再选同一门课，'
            '有人说暑假要去很远的地方。'
            '你发现自己这一年认识了比去年多一倍的人。',
        ambient: [
          '有人把校袍的第二颗纽扣送给了别人当纪念。',
          '走廊尽头那扇窗今年第一次开着。',
          '你的通讯录最后一页快写满了。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'exchange_all',
            text: '挨个交换地址，一个都不落下',
            consequence:
                '你跟二十多个人换了地址，写到手酸。'
                '暑假里你真的收到了信，一共十一封。'
                '你把回信封口时想：这学年没白过。',
            effect: StoryEffect(
              setFlags: ['poa_stayed_till_end'],
              addItems: ['手写贺卡', '新羽毛笔'],
              reputation: 3,
              affection: 2,
              spirit: 3,
              targetNpcId: 'ernie',
            ),
          ),
          StoryChoiceDef(
            id: 'find_quiet_one',
            text: '找到那个总是一个人的人，跟他说话',
            consequence:
                '你在一个不太起眼的角落找到了那个人，'
                '聊了大概十分钟。分开时他说：'
                '"你是这学年第一个主动跟我说话的人。"',
            effect: StoryEffect(
              setFlags: ['poa_helped_peer'],
              reputation: 2,
              affection: 3,
              spirit: 2,
              targetNpcId: 'luna',
            ),
          ),
          StoryChoiceDef(
            id: 'walk_courtyard',
            text: '一个人在院子里走一圈，跟城堡告别',
            consequence:
                '你沿着回廊走了一大圈，把这一年去过的地方'
                '都在心里过了一遍：塔楼、栅栏、湖岸、'
                '还有那条你后来学会绕开的走廊。',
            effect: StoryEffect(
              setFlags: ['poa_stayed_till_end'],
              addKnowledge: ['poa_farewell_walk'],
              spirit: 3,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch8_end',
        chapterId: 'poa_ch8',
        timeCostDays: 3,
        setup:
            '结束宴之后是列车。今年的车厢里没有那种飘着的东西，'
            '阳光照进来，热得人想脱外套。'
            '你靠着窗，看城堡在远处一点点变小。',
        ambient: [
          '有人已经把明年的书单翻出来了。',
          '窗外掠过的田野绿得晃眼。',
          '你口袋里还留着一张没寄出去的卡片。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'write_summary',
            text: '在颠簸的车厢里给这一年写个总结',
            consequence:
                '你写了满满一页。写到最后一句时'
                '你自己都愣了一下："我怕过，但我没被抽空。"'
                '你把这页纸夹进了明年的书里。',
            effect: StoryEffect(
              setFlags: ['poa_stayed_till_end'],
              addItems: ['计划书'],
              addKnowledge: ['poa_year_summary'],
              spirit: 3,
              reputation: 2,
            ),
            nextStepId: 'poa_ch8_train_home',),
          StoryChoiceDef(
            id: 'sit_with_friends',
            text: '挤进那节最吵的车厢，跟大家一起',
            consequence:
                '你挤进最吵的那节车厢，被塞了一把糖。'
                '大家聊明年的课、聊暑假、聊谁长高了。'
                '没有人提摄魂怪——这件事本身就是胜利。',
            effect: StoryEffect(
              setFlags: ['poa_stayed_till_end'],
              addItems: ['比比多味豆'],
              reputation: 2,
              affection: 3,
              spirit: 3,
              targetNpcId: 'ron',
            ),
            nextStepId: 'poa_ch8_train_home',),
          StoryChoiceDef(
            id: 'watch_castle',
            text: '一直看着窗外，直到城堡看不见',
            consequence:
                '你一直看到城堡彻底消失在地平线后面。'
                '三年级结束了。你想，'
                '明年应该会有不一样的事等着——好或坏，总之不一样。',
            effect: StoryEffect(
              setFlags: ['poa_stayed_till_end'],
              addKnowledge: ['poa_last_look'],
              spirit: 2,
            ),
            nextStepId: 'poa_ch8_train_home',),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch8_lastweek',
        chapterId: 'poa_ch8',
        timeCostDays: 2,
        setup:
            '学年最后一周，城堡里的传言终于对上了。'
            '有人说那个人根本没进城堡，有人说他进去了又走了。'
            '有人说有一只鹰头马身有翼兽飞走了，'
            '还有人说城堡的钟在某个夜里停过两次。'
            '这些说法互相矛盾，但没有一个是完整的。',
        ambient: [
          '打包行李的人比往年安静，走廊里堆着箱子。',
          '有人把这一年剪下的报纸夹进了课本里。',
          '海格的小屋门口，那两块糖的位置空着。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'piece_together',
            text: '把自己听到的所有版本拼一遍',
            consequence:
                '你在行李上坐下来，把这些说法一条条写下来。'
                '对不上的地方比能对上的多。'
                '最后你得到的结论只有一句："至少有一件事被解决了，而我不是解决它的人。"'
                '这大概是你这一年学到的最重要的一句话。',
            effect: StoryEffect(
              addKnowledge: ['poa_truth_fragments'],
              setFlags: ['poa_pieced_together'],
              housePoints: 3,
              galleons: 2,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'let_it_go',
            text: '不整理了，把行李收好，去赶火车',
            consequence:
                '你把东西一件件放进箱子，最后看了一眼宿舍。'
                '你决定不把这一年带走太多。'
                '火车开动的时候，城堡缩成了一个很小的点。',
            effect: StoryEffect(
              setFlags: ['poa_left_it'],
              spirit: 2,
            ),
            nextStepId: '',
          ),
        ],
      ),
      StoryStepDef(
        id: 'poa_ch8_train_home',
        chapterId: 'poa_ch8',
        timeCostDays: 1,
        setup:
            '回程的火车上，没有人像往年那样大声唱歌。大家靠在座位上看着窗外，田野一格一格往后退。',
        ambient: [
          '有人把剩下的糖分给了整节车厢。',
          '窗外远处有鹰在盘旋，很快就看不见了。',
          '行李架上的箱子随着车身轻轻晃。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'write_letter',
            text: '掏出纸笔，给这一年里帮过你的人写封信',
            consequence:
                '你写了三页，写到最后一页的时候火车已经出了山区。信没有寄出去，你把它折好收进了箱子——有些话写下来本身就是意义。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['poa_wrote_letter'], spirit: 5),
          ),
          StoryChoiceDef(
            id: 'sleep',
            text: '把围巾往脸上一盖，睡到终点',
            consequence:
                '你睡了一路。醒来的时候已经快到站了。这一年的最后一段路，你是在没有梦的睡眠里走完的。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['poa_slept_home'], spirit: 3),
          ),
        ],
      ),
    ],
  ),
];

// ================================================================
// 结局（顺序即优先级，兜底规则放最后）
// ================================================================

const List<StoryEndingRule> _poaEndings = [
  StoryEndingRule(
    id: 'poa_ending_witness',
    title: '站在听证会外的人',
    body:
        '你不是那个能翻案的人，也不是那个握着锤子的人。'
        '但你在场：你听完了全过程，递出去过一份说法，'
        '也在名单上签了自己的名字。'
        '多年以后有人提起那年四月，你会说——我在。',
    requireFlags: ['poa_hearing_witness', 'poa_buckbeak_friend'],
  ),
  StoryEndingRule(
    id: 'poa_ending_courage',
    title: '没被抽空的那个冬天',
    body:
        '这一年城堡里住进了会带走快乐的东西。'
        '你怕过，也确实冷过——但你把一段记忆擦得越来越亮，'
        '在黑暗的车厢里握住过谁的手，也在走廊上教过更小的孩子'
        '怎么攥紧自己最好的那一天。'
        '三年级结束时你清点自己：一样都没少。',
    requireAnyFlags: ['poa_brave_train', 'poa_patronus_attempt'],
    minReputation: 6,
  ),
  StoryEndingRule(
    id: 'poa_ending_warm',
    title: '雪与黄油啤酒',
    body:
        '你记住的这一年，是村口雪地上的车辙，'
        '是三把扫帚窗边那杯甜得发腻的东西，'
        '是有人隔着两道墙听完锤声后红着眼睛走出来的下午。'
        '恐惧是真的，暖也是真的。你选择把后者留下来了。',
    requireAnyFlags: ['poa_first_village', 'poa_rosmerta_talk'],
  ),
  StoryEndingRule(
    id: 'poa_ending_distant',
    title: '隔着一层霜',
    body:
        '你安全地度过了这一年：按时上课，按时考试，'
        '绕开了每一条能看见湖面的走廊。'
        '只是年末回想时，这一年像蒙着一层薄霜——'
        '什么都发生了，什么都没真的碰到你。'
        '你在心里记下一句话：下一次，我想站在近一点的地方。',
  ),
];

const StoryBookDef prisonerOfAzkaban = StoryBookDef(
  id: 'poa',
  title: '阿兹卡班的囚徒',
  chapters: _poaChapters,
  endings: _poaEndings,
  startYear: 1993,
  startMonth: 7,
  startDay: 25,
);
