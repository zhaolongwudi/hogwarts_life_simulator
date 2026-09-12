/// 主线剧情内容库。
///
/// 【本文件是"纯内容"】所有逻辑都在 `lib/models/story_progress.dart` 与
/// `lib/mixins/mixin_narrative.dart`。这里只写 `const` 数据表——
/// 跑通第一部之后，第二到第七部**不需要动任何一行逻辑代码**，
/// 只是往这里继续加 `StoryChapterDef`。这是"一部一部按时间线添加"能成立的前提。
///
/// 【与 canon_events.dart 的关系】`canon_events.dart` 那 31 条原著节点是
/// **沙盒模式**的事件源（往叙事尾巴贴旁白）。剧情模式下，某些步用
/// `canonRefId` 声明"这条原著节点由本步的剧情文本讲述"，此时不再贴旁白块，
/// 但 `firedAnchorIds` 照写，避免玩家退出剧情模式后同一件事再弹一次。
///
/// 【平行世界原则——本文件最容易犯的错】
/// 玩家是**原创角色**，不是哈利。原著场景要写成「你也在场」，而不是「你是主角」：
///   ❌ 「你举剑刺向蛇怪」「你额上的闪电形伤疤作痛」
///   ✅ 「你也在禁林里，看见有人俯身饮下独角兽的血，那影子仓皇逃开了」
/// 这条约束由 `test/canon_story_parallel_test.dart` 的禁用措辞扫描守住。
///
/// 【原著大局不变】无论玩家怎么选，巨怪还是被制服、活板门下还是邓布利多收场。
/// 玩家改的是**自己的**命运（声望/学院/关系/物品/情报/结局），不改写原著大事。
///
/// 【canon 覆盖】《魔法石》在 `canon_events.dart` 里有 7 个节点
/// （gringotts/sorting/troll/quidditch_first/christmas_mirror/
/// forbidden_forest/year_end）。本表按原著月份把它们排进对应章节，
/// **全部**由某一步声明讲述——由 `test/canon_story_parallel_test.dart`
/// 的「canon 节点全覆盖」守住。（收信不在 canon 节点表里，第一章不声明。）
///
/// 【开局场景对齐】开局时刻由 `opening_scene_data.dart` 决定（7/31 在家、
/// 8/20 对角巷、9/1 站台或礼堂）。`storyStartStepFor` 按开局场景把起始步
/// 跳到玩家真正所在的时间点，避免"9 月开局重新收到 7 月的信"的时间倒流。
///
/// 【版权说明】本文件只写剧情结构与氛围描述，不抄录原著原文句子。
library;

import '../models/story_progress.dart';

// ================================================================
// 《魔法石》 1991-1992 · 一年级
// ================================================================

const List<StoryChapterDef> _psChapters = [
  // --------------------------------------------------------------
  // 第一章 · 女贞路的信（1991 年 7 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'ps_ch1',
    bookId: 'ps',
    ordinal: 1,
    title: '女贞路的信',
    steps: [
      StoryStepDef(
        id: 'ps_ch1_letter',
        chapterId: 'ps_ch1',
        // 【修正】收信不是 canon_events 表里的节点，不能声明幽灵引用——
        // 批次 5 的 canonRefId 白名单抑制按「节点 id 精确匹配」工作。
        timeCostDays: 3,
        setup:
            '七月末的清晨，一只仓鸮落在你家窗台上，爪子上系着一封厚重的羊皮纸信。'
            '信封用翠绿墨水写着你的名字，背面压着一枚蜡封：盾徽上有狮子、鹰、獾和蛇。'
            '你的养父母正坐在楼下吃早饭，报纸翻得哗哗响。',
        ambient: [
          '窗外的街上，送奶车叮当作响，没有人注意到这只猫头鹰。',
          '你摸了摸信封边缘，羊皮纸粗粝的纹理让拇指微微发痒。',
          '楼下的收音机在播报天气，说今年夏天会比往年更热。',
        ],
        onEnterText: '故事从这封信开始。',
        choices: [
          StoryChoiceDef(
            id: 'read_in_room',
            text: '先回房间，把信拆开悄悄读完',
            consequence:
                '你把门反锁，坐在床沿把信读完。信里写着入学通知、书单，'
                '以及九月一日从国王十字车站出发的安排。你把信折好，塞进枕头底下。',
            nextStepId: 'ps_ch1_tell',
            effect: StoryEffect(
              addItems: ['霍格沃茨的来信'],
              addKnowledge: ['knows_hogwarts_acceptance'],
              setFlags: ['ps_read_letter_first'],
              spirit: 5,
            ),
          ),
          StoryChoiceDef(
            id: 'ask_family',
            text: '拿着信下楼，直接问养父母这是怎么回事',
            consequence:
                '你把信拍在餐桌上。养母的茶杯停在半空，养父放下报纸，'
                '沉默了很久才说：「我们本来想等你再大一点再说。」'
                '他们承认，你小时候确实发生过一些「说不清」的事。',
            nextStepId: 'ps_ch1_tell',
            effect: StoryEffect(
              addItems: ['霍格沃茨的来信'],
              addKnowledge: [
                'knows_hogwarts_acceptance',
                'family_hid_the_truth',
              ],
              setFlags: ['ps_confronted_family'],
              spirit: -3,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch1_tell',
        chapterId: 'ps_ch1',
        timeCostDays: 5,
        setup:
            '信读完了，接下来最难的部分是：怎么跟家里人说你要去一所魔法学校。'
            '信封里还附了一张清单——长袍、课本、坩埚，还有一根你自己的魔杖。'
            '清单最下面写着回信的方式：交给那只不肯走的猫头鹰。',
        ambient: [
          '那只仓鸮还在窗台上，歪着头看你，像是在等一个答复。',
          '你把清单又看了一遍，每看一遍都觉得更不真实一点。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'tell_truth',
            text: '把信和清单全部摊开，认真跟他们解释',
            consequence:
                '你把清单摊在桌上，一条一条念。养母问了很多问题，'
                '最后叹了口气说：「那……总得给你买齐东西。」'
                '当晚，养父破天荒地在餐桌上讲了三个笑话。',
            nextStepId: 'ps_ch1_reply',
            effect: StoryEffect(
              setFlags: ['ps_family_supportive'],
              reputation: 2,
              spirit: 8,
            ),
          ),
          StoryChoiceDef(
            id: 'hide_truth',
            text: '含糊过去，只说要转学去一所寄宿学校',
            consequence:
                '你说了个含糊的借口，他们信了一半。收拾行李那几天，'
                '养母几次欲言又止，最后只是往你箱子里多塞了一件毛衣。',
            nextStepId: 'ps_ch1_reply',
            effect: StoryEffect(
              setFlags: ['ps_family_in_the_dark'],
              spirit: -5,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch1_reply',
        chapterId: 'ps_ch1',
        timeCostDays: 2,
        setup:
            '该给霍格沃茨回信了。你捏着羽毛笔，面前是那张空白的回执。'
            '窗外的天已经暗下来，路灯一盏盏亮起。',
        ambient: [
          '羽毛笔的笔尖滴了一滴墨在纸角，你还没来得及擦。',
          '仓鸮在窗台上换了个姿势，把翅膀收得更紧。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'write_yes',
            text: '写下「我愿意入学」，把回执系回猫头鹰腿上',
            consequence:
                '你把回执系好，推开窗。仓鸮展开翅膀，几乎是无声地滑进了夜色，'
                '很快变成一个黑点。你站在窗边很久，心跳得厉害。',
            nextStepId: '',
            effect: StoryEffect(
              setFlags: ['ps_accepted'],
              addKnowledge: ['will_go_to_hogwarts'],
              reputation: 3,
              spirit: 10,
            ),
          ),
          StoryChoiceDef(
            id: 'write_delay',
            text: '先问问能不能晚一年入学，把回执写得犹豫一点',
            consequence:
                '你在回执上多写了两句犹豫的话。第二天清晨，猫头鹰回来了，'
                '带回一张字迹工整的便条：「霍格沃茨随时欢迎你，但门只为你开一次。」'
                '你把它读了三遍，最后还是把「我愿意」补了上去。',
            nextStepId: '',
            effect: StoryEffect(
              setFlags: ['ps_accepted', 'ps_hesitated_first'],
              addKnowledge: ['will_go_to_hogwarts'],
              spirit: -3,
              reputation: 1,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第二章 · 对角巷与古灵阁（1991 年 8 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'ps_ch2',
    bookId: 'ps',
    ordinal: 2,
    title: '对角巷与古灵阁',
    steps: [
      StoryStepDef(
        id: 'ps_ch2_arrival',
        chapterId: 'ps_ch2',
        timeCostDays: 2,
        setup:
            '八月下旬的上午，破釜酒吧的后院里，带你来的那个人用魔杖在砖墙上'
            '敲了五下。蓝色的砖块像门一样一块块挪开，对角巷在你面前展开——'
            '曲曲折折的鹅卵石街两侧挤满了店铺：药店门口挂着成束的风干草药，'
            '扫帚店的橱窗里立着最新的横扫系列，孩子们把鼻尖贴在恶作剧商店的玻璃上。',
        ambient: [
          '一个矮个子妖精从古灵阁的大理石台阶上走下来，皮包骨的手里攥着一把钥匙。',
          '邮局的窗口里，几十只猫头鹰按颜色分了排，最花哨的那只在打瞌睡。',
          '有人在摩金夫人长袍店门口喊：「下一个！」',
        ],
        onEnterText: '你第一次踏上对角巷。',
        choices: [
          StoryChoiceDef(
            id: 'a_eyes_open',
            text: '把每一扇橱窗都看个遍',
            consequence:
                '你放慢脚步，从药店看到魔杖店。摩金夫人的橱窗里一件校袍'
                '自己叠好了自己，福林的橱窗里羽毛笔在空中排队。'
                '你把这些都记在心里——这就是你要去生活的地方。',
            nextStepId: 'ps_ch2_bank',
            effect: StoryEffect(
              setFlags: ['ps_marveled_diagon'],
              spirit: 5,
            ),
          ),
          StoryChoiceDef(
            id: 'a_straight',
            text: '直奔主题：先去古灵阁把事情办了',
            consequence:
                '你捏着口袋里的钱袋直往街尾走。橱窗里的东西再好看，'
                '也该先把正事办完——钱在古灵阁，清单的第一项在别处。',
            nextStepId: 'ps_ch2_bank',
            effect: StoryEffect(
              setFlags: ['ps_practical_shopper'],
              reputation: 1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch2_bank',
        chapterId: 'ps_ch2',
        // 原著节点：古灵阁被闯入（1991 年 7 月，《预言家日报》头版）
        canonRefId: 'canon_ps_gringotts',
        timeCostDays: 1,
        setup:
            '古灵阁的大门有两人高，青铜门面上雕着妖精与持矛的警卫。'
            '大理石大厅比想象中还要高，妖精们坐在高高的柜台后面称量宝石。'
            '排队的时候，你前面一位老巫师把一份《预言家日报》翻得哗哗响——'
            '头版写着：古灵阁最深处的一间金库在七月底遭人试图闯入，至今没有抓到凶手。',
        ambient: [
          '柜台深处，取货的小车沿轨道呼啸而过，车轮声在穹顶下荡出回音。',
          '你身边一个矮胖的妖精敲了敲柜台示意下一位，语气不耐烦。',
          '穿猩红制服的警卫比平时多了一倍，大家都在小声议论为什么。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'a_listen',
            text: '凑近听那几位巫师在议论什么',
            consequence:
                '「那间金库本来就是空的。」一个声音压得很低。'
                '「空的金库用得着人去闯？」另一个声音嗤笑，'
                '「依我看，里面『有过』什么东西，而现在不在了。」'
                '你把这两句话都记下了。',
            nextStepId: 'ps_ch2_shopping',
            effect: StoryEffect(
              addKnowledge: ['knows_gringotts_rumor'],
              setFlags: ['ps_heard_gringotts'],
              spirit: -2,
            ),
          ),
          StoryChoiceDef(
            id: 'a_ignore',
            text: '换完钱就走，不掺和别人的事',
            consequence:
                '你数清了钱袋里的加隆，把收据折好揣进口袋。'
                '外面的阳光正好，你决定不去想金库里到底丢了什么——'
                '那是妖精和傲罗的事。',
            nextStepId: 'ps_ch2_shopping',
            effect: StoryEffect(
              setFlags: ['ps_kept_head_down'],
              galleons: 5,
              spirit: 3,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch2_shopping',
        chapterId: 'ps_ch2',
        timeCostDays: 3,
        setup:
            '清单还剩最后几项：课本、坩埚，以及最重要的一根魔杖。'
            '奥利凡德的店铺又窄又旧，门口的招牌金字剥落了大半。'
            '你推门进去，风铃轻轻响了一声——店里安静得能听见灰尘落地的声音，'
            '几千个窄长的纸盒从地板一直摞到天花板。',
        ambient: [
          '「每一根魔杖都不一样，」有人在货架后面轻声说，'
          '「重要的是魔杖选巫师，不是反过来。」',
          '一把自动卷尺从柜台下钻出来，绕着你量了一圈又缩了回去。',
          '橱窗外，两个同龄的孩子正为一根飞天扫帚的型号争得面红耳赤。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'a_patient',
            text: '耐着性子一根一根试',
            consequence:
                '你试到第七根的时候，杖尖终于冒出一簇金色的火星，'
                '暖得像把整个夏天握在手里。店主满意地点头：'
                '「看到了吧？我说过，总有一根在等你。」',
            nextStepId: '',
            effect: StoryEffect(
              addItems: ['标准咒语书'],
              setFlags: ['ps_wand_found'],
              spirit: 8,
            ),
          ),
          StoryChoiceDef(
            id: 'a_curious',
            text: '被货架深处一根积灰的旧杖吸引',
            consequence:
                '你踮脚取下那根没有盒子的魔杖，杖身有细小的刻痕。'
                '店主盯着你看了很久，最后说：「这根等它的主人等了些年头了。」'
                '它在你手里轻轻颤了一下，像是叹气。',
            nextStepId: '',
            effect: StoryEffect(
              addItems: ['标准咒语书'],
              setFlags: ['ps_wand_old'],
              reputation: 1,
              spirit: 5,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第三章 · 九又四分之三站台（1991 年 9 月 1 日）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'ps_ch3',
    bookId: 'ps',
    ordinal: 3,
    title: '九又四分之三站台',
    steps: [
      StoryStepDef(
        id: 'ps_ch3_platform',
        chapterId: 'ps_ch3',
        timeCostDays: 1,
        setup:
            '九月一日，国王十字车站挤满了返校的学生。'
            '你推着行李车穿过第九和第十站台之间的砖墙——'
            '砖面在身后合拢的触感还没散去，眼前就是那辆猩红色的蒸汽机车，'
            '车头的白烟把半个站台都罩住了。',
        ambient: [
          '一窝猫头鹰在笼子里扑腾，信封和羽毛掉了一地。',
          '穿绿长袍的母亲踮脚给自己的孩子理围巾，'
          '嘴里念叨着「圣诞前记得写信」。',
          '汽笛响了第一遍，月台上的人流明显快了起来。',
        ],
        onEnterText: '开学日。',
        choices: [
          StoryChoiceDef(
            id: 'a_help_push',
            text: '帮一个行李散了架的圆脸男孩捡东西',
            consequence:
                '蟾蜍、书盒、还有一只拼命想逃跑的卷心菜滚了一地。'
                '你们俩手忙脚乱地收拾，最后是那位男孩的奶奶帮你们把'
                '书盒重新捆好。「我叫纳威，」他红着脸说，'
                '「谢谢……我总是把东西弄丢。」',
            nextStepId: 'ps_ch3_train',
            effect: StoryEffect(
              targetNpcId: 'neville',
              affection: 2,
              setFlags: ['ps_met_neville'],
              spirit: 3,
            ),
          ),
          StoryChoiceDef(
            id: 'a_find_seat',
            text: '趁人还不多，先上车找个靠窗的位子',
            consequence:
                '你把箱子塞进行李架，靠窗坐下。窗外的月台上，'
                '家长们朝车厢里张望，有人抹了把眼睛。'
                '汽笛响第二遍的时候，车身轻轻一震，动了。',
            nextStepId: 'ps_ch3_train',
            effect: StoryEffect(
              setFlags: ['ps_window_seat'],
              spirit: 2,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch3_train',
        chapterId: 'ps_ch3',
        timeCostDays: 1,
        setup:
            '车厢里渐渐坐满了人。走廊里有人兜售巧克力蛙和南瓜馅饼，'
            '车窗外的伦敦变成郊外，又变成起伏的山丘。'
            '零食车哐当哐当碾过车厢接缝，你听见自己的肚子咕噜了一声。',
        ambient: [
          '隔壁包厢在打牌，笑声隔着门板都能听见。',
          '一只灰色的谷仓猫头鹰从窗外掠过，翅膀几乎擦到玻璃。',
          '有人抱着一摞崭新的课本从过道走过，边走边小声背咒语。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'a_share_snacks',
            text: '和同车厢的人分享零食，聊起了各自的家',
            consequence:
                '你把南瓜馅饼掰了一半递过去。红头发的那位说他家三代都是'
                '霍格沃茨的，双胞胎哥哥昨天还往他的坩埚里塞了只蜘蛛。'
                '「你呢？」你说了自己的事——说到一半他自己接上了：'
                '「那你得赶紧补课，不然魔药课第一个礼拜就会被叫起来回答问题。」',
            nextStepId: '',
            effect: StoryEffect(
              targetNpcId: 'ron',
              affection: 2,
              addKnowledge: ['knows_classmates'],
              setFlags: ['ps_met_ron'],
              spirit: 4,
            ),
          ),
          StoryChoiceDef(
            id: 'a_watch',
            text: '安静看风景，把心事留给窗外',
            consequence:
                '你看着山丘上的羊群一点点往后退。邻座打起了瞌睡，'
                '你从口袋里摸出入学信又读了一遍。窗玻璃映出你的脸——'
                '和收到信那天比，好像没什么变化，又好像完全不同了。',
            nextStepId: '',
            effect: StoryEffect(
              setFlags: ['ps_quiet_rider'],
              spirit: 3,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第四章 · 分院帽（1991 年 9 月 1 日夜）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'ps_ch4',
    bookId: 'ps',
    ordinal: 4,
    title: '分院帽',
    steps: [
      StoryStepDef(
        id: 'ps_ch4_boats',
        chapterId: 'ps_ch4',
        timeCostDays: 1,
        setup:
            '霍格莫德车站的天已经黑透。一个嗓门大得吓人的巨人提着灯笼，'
            '喊「一年级新生——这边！」。你们沿着一条陡峭的小路走到黑湖边，'
            '二十来条小船泊在如镜的湖面上。城堡就立在湖对岸的山崖上，'
            '一层层窗户亮着灯，像悬在半空的星图。',
        ambient: [
          '湖面偶尔冒出一个水泡，谁也不确定底下是什么。',
          '有人小声说看见人鱼了，立刻被同伴笑话是紧张的幻觉。',
          '城堡越来越近，你能看清最高的那座塔上有一扇亮着的窗。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'a_look',
            text: '抬头把城堡的轮廓看进心里',
            consequence:
                '你数了数塔楼的数目，找到了最高的那座和它背后的天文塔。'
                '有人说第一年谁都会迷路，你打算做个例外。',
            nextStepId: 'ps_ch4_sorting',
            effect: StoryEffect(
              addKnowledge: ['knows_hogwarts_layout'],
              setFlags: ['ps_mapped_castle'],
              spirit: 3,
            ),
          ),
          StoryChoiceDef(
            id: 'a_talk',
            text: '跟同一条船的人互相壮胆',
            consequence:
                '「要是被分进自己完全没想过的学院怎么办？」船头那位'
                '白天行李散架的圆脸男孩又紧张起来。「那就说明帽子看见了'
                '你没看见的东西。」你说。船尾有人小声接了一句：'
                '「反正帽子不是非要听我们的。」',
            nextStepId: 'ps_ch4_sorting',
            effect: StoryEffect(
              targetNpcId: 'neville',
              affection: 2,
              setFlags: ['ps_met_neville'],
              spirit: 2,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch4_sorting',
        chapterId: 'ps_ch4',
        // 原著节点：入学与分院（1991 年 9 月）
        canonRefId: 'canon_ps_sorting',
        timeCostDays: 1,
        setup:
            '大礼堂的四张长桌旁坐满了老生，烛光下面是一片被施了法的夜空。'
            '分院仪式开始了：一排新生站成三列，一顶打着补丁的尖顶旧帽子'
            '搁在四脚凳上。帽子开口唱了歌，随后新生一个接一个被叫上前——'
            '轮到你的时候，帽子被举过头顶，整个世界安静下来，'
            '它的声音在你耳边响起，细得像是从很远的地方传来。',
        ambient: [
          '「格兰芬多！」帽子朝礼堂喊了一声，左边的长桌爆发出欢呼。',
          '有位教授正在给一个吓哭了的低年级生整理袍子，动作轻得像在哄猫。',
          '天花板上的星星比外面的真星星密得多，偶尔有一小片云飘过去。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'a_listen',
            text: '安静听完帽子的每一句低语',
            consequence:
                '帽子在你耳边絮絮叨叨，问你喜欢早晨还是深夜、喜欢书还是人。'
                '它听得比你想象的认真——甚至会停下来想。最后，'
                '它在你头顶大声说出了决定，你的学院的长桌立刻响起掌声。'
                '你摘下帽子时，帽檐朝你点了一下，像是道别。',
            nextStepId: '',
            effect: StoryEffect(
              addKnowledge: ['knows_own_house'],
              setFlags: ['ps_sorted'],
              housePoints: 2,
              spirit: 6,
            ),
          ),
          StoryChoiceDef(
            id: 'a_debate',
            text: '在心里跟帽子争辩了两句',
            consequence:
                '帽子话没说完，你就在心里回了它一句——它愣了一下，'
                '随即发出一阵细小的笑声：「多年没人跟我顶嘴了。」'
                '它重新掂量了一会儿，才喊出它的最终答案。'
                '你坐下的时候手心全是汗，但那是你自己争来的答案。',
            nextStepId: '',
            effect: StoryEffect(
              addKnowledge: ['knows_own_house'],
              setFlags: ['ps_sorted', 'ps_debated_hat'],
              housePoints: 1,
              reputation: 2,
              spirit: 8,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第五章 · 城堡的第一课（1991 年 9 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'ps_ch5',
    bookId: 'ps',
    ordinal: 5,
    title: '城堡的第一课',
    steps: [
      StoryStepDef(
        id: 'ps_ch5_first_class',
        chapterId: 'ps_ch5',
        timeCostDays: 3,
        setup:
            '开学第一周的魔咒课。弗立维教授站在一摞书上才够到讲台，'
            '他在黑板上写下今天的目标，然后环视全班：「规矩很简单——'
            '安全第一，大声念对咒文。」你面前的白羽毛悬在半空，'
            '就等一个正确的咒语让它起飞。',
        ambient: [
          '前排有人把咒语念成了绕口令，羽毛纹丝不动。',
          '教室角落，一根羽毛突然窜起来撞上了吊灯，全班哄笑。',
          '弗立维踮着脚在过道里巡视，时不时用魔杖尖轻轻点一下谁的书页。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'a_drill',
            text: '按教授说的，一遍一遍把咒文念准',
            consequence:
                '第十遍的时候，白羽毛颤了一下，离桌三寸，又落回去。'
                '但全班都看见它动了。弗立维给你记了一分：'
                '「节奏对了，剩下的交给练习。」',
            nextStepId: 'ps_ch5_potions',
            effect: StoryEffect(
              setFlags: ['ps_spell_drill'],
              housePoints: 3,
              spirit: 3,
            ),
          ),
          StoryChoiceDef(
            id: 'a_help',
            text: '转头帮同桌纠正手势',
            consequence:
                '你注意到同桌的手腕一直绷得太死。「放松，像抖水彩笔那样。」'
                '他照做了——羽毛晃晃悠悠升到了两人头顶。'
                '弗立维从讲台后面探出头：「互相帮助，各记一分！」',
            nextStepId: 'ps_ch5_potions',
            effect: StoryEffect(
              targetNpcId: 'seamus',
              affection: 2,
              setFlags: ['ps_helped_classmate'],
              housePoints: 2,
              spirit: 4,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch5_potions',
        chapterId: 'ps_ch5',
        timeCostDays: 3,
        setup:
            '地下教室比外面冷得多，一排排泡在玻璃罐里的东西在昏暗里泛着光。'
            '斯内普教授进门时没有打招呼，教室里立刻安静得只剩下火苗的'
            '噼啪声。他的目光从第一排扫到最后一排——被扫到的人'
            '不自觉地坐直了。',
        ambient: [
          '天花板上挂着的风干标本轻轻晃动，你不确定那是不是真的蛇。',
          '有人小声问邻居两个配方之间的区别，被一声咳嗽吓得闭了嘴。',
          '坩埚下的火苗忽明忽暗，教室里的气味混着菖蒲和冷水的味道。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'a_precise',
            text: '把每一步用量都记在羊皮纸上',
            consequence:
                '你按书上的顺序一样一样加，最后得到的药膏颜色和黑板上的'
                '示范图分毫不差。斯内普路过时瞥了一眼你的坩埚，什么也没说'
                '——但你注意到他在这页记录上多停了半秒。',
            nextStepId: 'ps_ch5_library',
            effect: StoryEffect(
              setFlags: ['ps_potions_precise'],
              housePoints: 2,
              reputation: 2,
            ),
          ),
          StoryChoiceDef(
            id: 'a_question',
            text: '举手问了一个「为什么」',
            consequence:
                '「为什么是顺时针搅七圈半？」教室里有人倒抽冷气。'
                '斯内普盯着你看了很久才开口：「因为八圈会破坏蜥蜴的成分，'
                '七圈不到你连药渣都配不出来。」他转身走开前补了一句：'
                '「会问问题的学生很少见。别浪费。」',
            nextStepId: 'ps_ch5_library',
            effect: StoryEffect(
              addKnowledge: ['knows_potions_why'],
              setFlags: ['ps_asked_why'],
              reputation: 1,
              spirit: 4,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch5_library',
        chapterId: 'ps_ch5',
        timeCostDays: 4,
        setup:
            '九月的最后一个周末，城堡里的新鲜劲淡下去了，功课开始压上来。'
            '图书馆的高窗外天色正好，平斯夫人在书架间无声地巡行，'
            '谁的书页翻得太响都会被她的目光钉在原地。',
        ambient: [
          '禁书区的铁链在走廊尽头闪着微光，据说要教授的签字条才能进。',
          '有个七年级生抱着一摞比人还高的书挪向门口，动作像在演杂技。',
          '翻书声、羽毛笔的沙沙声，和偶尔一声压低的「借一下羊皮纸」。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'a_stack',
            text: '在图书馆占个靠窗的位子，把功课清空',
            consequence:
                '你把变形课的论文、魔药课的记录、还有抄了一半的星象表'
                '排成一列，一项一项划掉。合上最后一本书的时候，'
                '窗外的天已经黑了，但你心里前所未有地踏实。',
            nextStepId: '',
            effect: StoryEffect(
              setFlags: ['ps_library_regular'],
              reputation: 2,
              spirit: 3,
            ),
          ),
          StoryChoiceDef(
            id: 'a_roam',
            text: '跟着同院的人去「勘察」城堡',
            consequence:
                '你们从三楼走廊摸到四楼，发现了一幅会指路的画像、'
                '一条走到一半消失的楼梯，和一扇怎么推也推不开的门。'
                '回去的路上谁也没说话——但每个人脸上都写着「下周再来」。',
            nextStepId: '',
            effect: StoryEffect(
              addKnowledge: ['knows_secret_corridors'],
              setFlags: ['ps_explored_castle'],
              spirit: 5,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第六章 · 万圣节的巨怪（1991 年 10 月 31 日）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'ps_ch6',
    bookId: 'ps',
    ordinal: 6,
    title: '万圣节的巨怪',
    steps: [
      StoryStepDef(
        id: 'ps_ch6_banquet',
        chapterId: 'ps_ch6',
        timeCostDays: 2,
        setup:
            '十月三十一日，城堡从早上就开始过节。礼堂天花板上悬着几百只'
            '活蝙蝠，南瓜灯一个比一个大，连走廊盔甲的头盔里都被塞了糖。'
            '晚饭前的最后一节课刚下，同学们三三两两往礼堂去。',
        ambient: [
          '有人用魔杖让纸糊的骷髅追着自己跑，笑倒在一堆南瓜里。',
          '级长们已经换好了正式长袍，站在礼堂门口清点各自的队列。',
          '厨房的方向飘来烤南瓜和蜂蜜蛋糕的味道。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'a_decorate',
            text: '留下来帮忙把最后一串南瓜灯挂上房梁',
            consequence:
                '你踩着凳子把最后一串挂上去的时候，它突然自己转了个圈，'
                '把灯影投得满墙都是。海格路过时哈哈大笑，'
                '说这是他今年见过最有万圣节样子的灯。',
            nextStepId: 'ps_ch6_troll',
            effect: StoryEffect(
              targetNpcId: 'hagrid',
              affection: 1,
              setFlags: ['ps_festive_helper'],
              spirit: 5,
            ),
          ),
          StoryChoiceDef(
            id: 'a_rest',
            text: '先回休息室歇一会儿，养精蓄锐',
            consequence:
                '你在休息室的沙发上眯了半个钟头。醒来时走廊里已经开始热闹，'
                '你理了理袍子往礼堂走——刚好赶上开饭。',
            nextStepId: 'ps_ch6_troll',
            effect: StoryEffect(
              setFlags: ['ps_rest_before'],
              spirit: 2,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch6_troll',
        chapterId: 'ps_ch6',
        // 原著节点：万圣节巨怪闯入（1991 年 10 月）
        // 原著大局：巨怪被教工制服，无人重伤——玩家的选择改变不了这一点，
        // 改变的是那一晚自己站在哪里、做了什么。
        canonRefId: 'canon_ps_troll',
        timeCostDays: 1,
        setup:
            '万圣节晚宴吃到一半，礼堂的大门砰地被撞开——奇洛教授连滚带爬'
            '冲了进来，喊了一声「巨怪——在地下教室」，就直挺挺昏了过去。'
            '礼堂瞬间炸了锅。邓布利多的声音压过所有尖叫：'
            '「级长，立刻带队回各自的公共休息室！」',
        ambient: [
          '长桌上的南瓜汁还在晃，有人连椅子带盘子撞翻在地板上。',
          '走廊里到处是乱跑的学生，低年级生哭喊着说看见「比人还高」的东西。',
          '教师席已经空了——教授们走得比任何人都快。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'a_count',
            text: '留在楼梯口帮级长清点人数，确认没人掉队',
            consequence:
                '你站在楼梯口，一个一个数着从你面前跑过去的人。'
                '数到第三遍确认没有漏，级长才关上休息室的门——'
                '你听见他长长地出了一口气。后半夜，消息传回来：'
                '教工把巨怪制服了，没有人受重伤。',
            nextStepId: 'ps_ch6_after',
            effect: StoryEffect(
              setFlags: ['ps_troll_stood_together'],
              housePoints: 5,
              reputation: 3,
              spirit: -2,
            ),
          ),
          StoryChoiceDef(
            id: 'a_help_up',
            text: '扶了一把吓瘫在走廊上的同学，一起走',
            consequence:
                '那孩子的腿抖得站不住，你几乎是把他半拖半架到了休息室。'
                '他缩在沙发角落里抓着你的袖子不肯放，直到级长把热可可'
                '分到每个人手里。后来他红着眼圈说：「多亏有你。」',
            nextStepId: 'ps_ch6_after',
            effect: StoryEffect(
              targetNpcId: 'neville',
              affection: 3,
              setFlags: ['ps_helped_firstyear'],
              housePoints: 2,
              spirit: -1,
            ),
          ),
          StoryChoiceDef(
            id: 'a_peek',
            text: '趁乱多看了一眼地下教室的方向',
            consequence:
                '你只来得及看见走廊尽头的黑暗和一道挪动的阴影，'
                '紧接着就被赶来的级长拽回了队伍。回到休息室你才后知后觉'
                '地开始后怕——手心里全是冷汗。',
            nextStepId: 'ps_ch6_after',
            effect: StoryEffect(
              addKnowledge: ['knows_troll_aftermath'],
              setFlags: ['ps_peaked_troll'],
              reputation: 1,
              spirit: -3,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch6_after',
        chapterId: 'ps_ch6',
        timeCostDays: 3,
        setup:
            '巨怪事件之后的那几天，走廊里的话题只有一个。有人说巨怪是'
            '自己走进来的，有人说看见「有人从楼上跑下来」，还有人说'
            '费尔奇在检查每一块松动的地板。开学以来，城堡第一次有了'
            '「有事发生」的气味。',
        ambient: [
          '教室里总有人把话题岔到那一晚，被教授用粉笔头打断。',
          '费尔奇拎着油灯在楼梯间转悠的次数明显比平时多。',
          '信使猫头鹰带来了家里的信，好几封都在问「报纸上说的事你没事吧」。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'a_listen_more',
            text: '把各处听来的说法拼在一起',
            consequence:
                '你把听到的版本排成一列：巨怪出现的地点、教授们消失的方向、'
                '还有那位昏倒的奇洛教授后来「请了两天假」。拼完你发现'
                '整件事最奇怪的不是巨怪——是那晚教授们的反应快得不正常。',
            nextStepId: '',
            effect: StoryEffect(
              addKnowledge: ['knows_staff_reaction'],
              setFlags: ['ps_curious_mind'],
              reputation: 1,
              spirit: -2,
            ),
          ),
          StoryChoiceDef(
            id: 'a_focus',
            text: '不理传闻，把落下的功课补回来',
            consequence:
                '那一晚落下的两节自习课你用三个晚上补了回来。'
                '教授们似乎都注意到了你的用功——变形课上，'
                '你的甲虫针脚第一次全部对齐了。',
            nextStepId: '',
            effect: StoryEffect(
              setFlags: ['ps_back_on_track'],
              housePoints: 2,
              reputation: 2,
              spirit: 1,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第七章 · 冬天的城堡（1991 年 11 月 - 12 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'ps_ch7',
    bookId: 'ps',
    ordinal: 7,
    title: '冬天的城堡',
    steps: [
      StoryStepDef(
        id: 'ps_ch7_quidditch',
        chapterId: 'ps_ch7',
        // 原著节点：第一场魁地奇比赛（1991 年 11 月）
        canonRefId: 'canon_ps_quidditch_first',
        timeCostDays: 2,
        setup:
            '十一月的第一个周六，格兰芬多对斯莱特林的魁地奇赛季首战。'
            '看台上挤得水泄不通，格兰芬多那边的横幅是高年级连夜画的，'
            '斯莱特林那边则齐声哼着难听的小调。你裹着围巾找了个'
            '能看清全场的位置——十一月的寒风刮在脸上像小刀子。',
        ambient: [
          '解说员李·乔丹的声音在魔法扩音器里又急又响，偶尔被麦格教授喝止。',
          '看台下有人冻得直跺脚，热黄油啤酒的香气从保温壶里飘出来。',
          '比赛用球被放飞的那一瞬，十四个身影像箭一样蹿上了天。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'a_cheer',
            text: '从开场喊到终场',
            consequence:
                '你的嗓子在最后一节彻底哑了——尤其是那阵惊呼：'
                '格兰芬多的找球手在扫帚上晃得厉害，差点一头栽下来，'
                '全场屏住呼吸，随后他又稳稳爬了回去。终场哨响，'
                '格兰芬多赢了，你身边的人抱成一团。',
            nextStepId: 'ps_ch7_christmas',
            effect: StoryEffect(
              setFlags: ['ps_saw_broom_spell'],
              housePoints: 3,
              spirit: 6,
            ),
          ),
          StoryChoiceDef(
            id: 'a_hear_story',
            text: '只看了半场，赛后去打听那阵骚动',
            consequence:
                '赛后休息室里吵成一团。「那把扫帚绝对被人施了咒！」'
                '有人说得斩钉截铁，「好好的扫帚怎么会自己发疯？」'
                '没人给出答案——但「有人不想让格兰芬多赢」这个说法，'
                '从此在走廊里生了根。',
            nextStepId: 'ps_ch7_christmas',
            effect: StoryEffect(
              addKnowledge: ['knows_broom_cursed'],
              setFlags: ['ps_heard_broom_rumor'],
              reputation: 1,
              spirit: 1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch7_christmas',
        chapterId: 'ps_ch7',
        // 原著节点：厄里斯魔镜的传闻（1991 年 12 月）
        canonRefId: 'canon_ps_christmas_mirror',
        timeCostDays: 4,
        setup:
            '圣诞假期开始，城堡一夜之间空了一大半。十二月中旬，'
            '一个传闻悄悄在留校生中间传开：八楼一间废弃教室里有一面'
            '很古怪的镜子，「照见的东西会让你不想离开」——'
            '而费尔奇最近总在夜里巡查那一层。',
        ambient: [
          '城堡的冷杉树上挂满长明蜡烛，融化的蜡滴在地板上冻成了小珠。',
          '圣诞夜的大礼堂摆上了十来棵巨型的圣诞树，彩灯自己会变花样。',
          '窗外落雪无声，八楼走廊的甲胄下传来猫爪落地的轻响。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'a_seek_mirror',
            text: '夜里循着传闻找到那间教室',
            consequence:
                '镜子比传闻里更高、顶到天花板，边框刻着你认不出的字。'
                '你在镜前站了很久——镜中的画面让你挪不开眼，'
                '直到远处传来脚步声，你才一步三回头地退出去。'
                '回宿舍的路上你想了一路：那面镜子，为什么偏偏放在'
                '没有人的教室里？',
            nextStepId: 'ps_ch7_term_end',
            effect: StoryEffect(
              addKnowledge: ['knows_mirror_room'],
              setFlags: ['ps_seen_mirror'],
              reputation: 1,
              spirit: -3,
            ),
          ),
          StoryChoiceDef(
            id: 'a_play_snow',
            text: '白天在院子里打雪仗，晚上睡个好觉',
            consequence:
                '你和留校的同学们把院子里的雪堆成了三座碉堡，'
                '混战中连送信的猫头鹰都来参了一脚。晚上你裹着'
                '新毛线帽睡得又沉又香——传闻什么的，留给他们去神秘。',
            nextStepId: 'ps_ch7_term_end',
            effect: StoryEffect(
              addItems: ['保暖毛线帽'],
              setFlags: ['ps_snow_king'],
              spirit: 6,
            ),
          ),
          StoryChoiceDef(
            id: 'a_go_home',
            text: '回家过节',
            consequence:
                '家人到车站接你。这个圣诞节比往年都特别——餐桌上多了'
                '会自己动的圣诞贺卡，养父偷偷问你「那个飞天扫帚贵不贵」，'
                '养母把院子里也点了一盏像模像样的浮灯。',
            nextStepId: 'ps_ch7_term_end',
            requireFlag: 'ps_family_supportive',
            effect: StoryEffect(
              addItems: ['手写贺卡'],
              setFlags: ['ps_went_home'],
              spirit: 8,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch7_term_end',
        chapterId: 'ps_ch7',
        timeCostDays: 4,
        setup:
            '假期结束，期末考试像冬天最后一股寒流一样压了上来。'
            '图书馆的位子一夜之间重新紧张起来，走廊里人人嘴里都在'
            '念叨变形咒的口诀和魔药配比。',
        ambient: [
          '有人在公共休息室的黑板上贴出了「互助复习表」，'
          '签名的位置挤满了字。',
          '钟楼每晚九点准时响，然后总有人从图书馆一路狂奔回塔。',
          '雪化了又冻上，石板路滑得像抹了油。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'a_group',
            text: '组一个复习小组，把笔记摊开来对',
            consequence:
                '六个人、五套笔记，互相挑错挑得面红耳赤。散伙的时候'
                '你的笔记被借走了一遍，你也在别人的笔记里发现了'
                '三个你从来没记过的要点。',
            nextStepId: '',
            effect: StoryEffect(
              targetNpcId: 'hermione',
              affection: 2,
              setFlags: ['ps_study_group'],
              reputation: 2,
              spirit: 2,
            ),
          ),
          StoryChoiceDef(
            id: 'a_solo',
            text: '一个人按计划过完所有科目',
            consequence:
                '你把每科的要点抄成了小卡片，睡前抽一张。'
                '考试那几天的睡眠出奇地好——这大概就是准备充分的副产品。',
            nextStepId: '',
            effect: StoryEffect(
              setFlags: ['ps_solo_grind'],
              housePoints: 2,
              reputation: 1,
              spirit: 1,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第八章 · 禁林与独角兽（1992 年 3 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'ps_ch8',
    bookId: 'ps',
    ordinal: 8,
    title: '禁林与独角兽',
    steps: [
      StoryStepDef(
        id: 'ps_ch8_rumor',
        chapterId: 'ps_ch8',
        timeCostDays: 3,
        setup:
            '三月初，一条消息像融雪水一样渗进城堡：有学生在禁林边缘'
            '发现了一头受伤的独角兽。更瘆人的是另一个说法——'
            '「林子里有什么东西在喝它的血」。海格最近几次半夜带着猎犬'
            '进林子，回来时脸色一次比一次差。教工发了正式通知：'
            '任何学生不得独自靠近禁林。',
        ambient: [
          '草药课的路上，你能看见禁林的黑线横在场地尽头，比冬天更沉默。',
          '有人赌咒发誓说夜里听见林子方向有马蹄声，碎得不像正常的走法。',
          '海格的木屋烟囱这几天起得很早，烟却很淡。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'a_ask_hagrid',
            text: '课间绕去海格的小屋，当面问问',
            consequence:
                '海格给你倒了杯滚烫的茶，话在嘴边转了几圈才出来：'
                '「独角兽的事……你听谁说的？」他没否认，也没多说，'
                '只反复叮嘱「林子里现在不干净，谁叫你都别去」。'
                '临走他往你兜里塞了两块岩皮饼。',
            nextStepId: 'ps_ch8_link',
            effect: StoryEffect(
              targetNpcId: 'hagrid',
              affection: 2,
              addKnowledge: ['knows_unicorn_injured'],
              setFlags: ['ps_trusts_hagrid'],
              spirit: -1,
            ),
          ),
          StoryChoiceDef(
            id: 'a_stay_back',
            text: '尊重禁令，远远观望',
            consequence:
                '你把好奇收进心里，转身去抄草药课的笔记。'
                '窗外的禁林安安静静——但你知道，安静本身就不太对劲。',
            nextStepId: 'ps_ch8_link',
            effect: StoryEffect(
              setFlags: ['ps_obeyed_forest_ban'],
              housePoints: 1,
              spirit: 1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch8_link',
        chapterId: 'ps_ch8',
        timeCostDays: 2,
        setup:
            '晚上在公共休息室，壁炉的火烤得人脸发烫。你把最近这些事'
            '在心里过了一遍：七月底被闯入的金库、圣诞夜那面'
            '「让人不想离开」的镜子、还有现在禁林里受伤的独角兽。'
            '这些事彼此隔着一个学年——但总觉得有什么把它们'
            '串在一条线上。',
        ambient: [
          '火钳在炭堆里拨出细响，有人在上铺翻身。',
          '窗外的雪已经化了大半，石板路上蒸起薄薄的白汽。',
          '墙上的画像们压低了声音聊天，偶尔朝你这边瞟一眼。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'a_connect',
            text: '把金库、镜子和禁林串成一条线',
            consequence:
                '空了的东西、被藏起来的东西、被追猎的东西——三件事拼在'
                '一起，你后背发凉：有同一个人在找同一样东西。'
                '你没跟任何人说这个推论，但从此每次看到教授们低声交谈，'
                '你都会竖起耳朵。',
            nextStepId: 'ps_ch8_night',
            // 【口径】requireFlag 过滤的是 **flags**（不是 knowledge）——
            // 所以这里引用 ch2_bank a_listen 置位的 flag，而不是它
            // addKnowledge 的知识 id。flag 才是"开关"，知识是"你知道了"。
            requireFlag: 'ps_heard_gringotts',
            effect: StoryEffect(
              addKnowledge: ['knows_ps_big_picture'],
              setFlags: ['ps_detective_mind'],
              reputation: 3,
              spirit: -2,
            ),
          ),
          StoryChoiceDef(
            id: 'a_share',
            text: '把心里的不安说给好友听',
            consequence:
                '对方听完沉默了一会儿，说：「我猜邓布利多早就知道了。'
                '校长办公室的灯这几周就没在半夜前熄过。」'
                '有同伴一起琢磨，那份不安就变成了能摊开的谜题。',
            nextStepId: 'ps_ch8_night',
            effect: StoryEffect(
              targetNpcId: 'ron',
              affection: 2,
              addKnowledge: ['knows_headmaster_watchful'],
              setFlags: ['ps_shared_doubt'],
              spirit: 2,
            ),
          ),
          StoryChoiceDef(
            id: 'a_drop',
            text: '不去多想，先对付下一周的草药课测验',
            consequence:
                '你把羊皮纸铺开，强迫自己背完曼德拉草的三个休眠期。'
                '疑云什么的，留给大人去头疼——一年级的你已经'
                '卷进够多的事了。',
            nextStepId: 'ps_ch8_night',
            effect: StoryEffect(
              setFlags: ['ps_stayed_focused'],
              housePoints: 2,
              spirit: 1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch8_night',
        chapterId: 'ps_ch8',
        // 原著节点：禁林里的独角兽（1992 年 3 月）
        // 玩家只在外围帮忙/观望——林子里的事是别人的命运，
        // 玩家看见的只是「有什么东西在动」。
        canonRefId: 'canon_ps_forbidden_forest',
        timeCostDays: 2,
        setup:
            '三月末的一个傍晚，你替海格把两袋饲料搬到林子外围的围栏边'
            '——这是他亲口答应的「忙里帮闲」。天快黑时，他牵着猎犬'
            '站在林缘，脸朝着黑压压的树影。「那头受伤的独角兽还在里头，'
            '我得盯着点。」他头也不回地说，「今晚别等我，'
            '回去的路你自己认得。」',
        ambient: [
          '林子里的鸟叫在日落后的第一分钟全部熄灭，黑得像被剪掉了一块。',
          '围栏边的夜风带着湿土和苔藓的味道，猎犬的耳朵一直贴着。',
          '远处传来一声鸟啼，又戛然而止——你数了数，'
          '那不是本地任何一种鸟的叫法。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'a_carry',
            text: '把饲料码好，等海格回来一起走',
            consequence:
                '你在围栏边等了大半夜，最后是踩着月光回来的海格打破了沉默。'
                '他没说林子里有什么，只是拍了拍你的肩：「好孩子。'
                '有些事，大人来。」回去的路上你们谁也没提林子，'
                '聊的是他的猎犬最爱吃的骨头饼干。',
            nextStepId: 'ps_ch8_after',
            effect: StoryEffect(
              targetNpcId: 'hagrid',
              affection: 3,
              setFlags: ['ps_forest_helped_hagrid'],
              reputation: 2,
              spirit: -2,
            ),
          ),
          StoryChoiceDef(
            id: 'a_return',
            text: '码完饲料就折返，一步也不多留',
            consequence:
                '你按禁令原路返回，一路上把每个路口的画像都记了一遍。'
                '回塔的路上你听到钟楼报时——你忽然明白，'
                '为什么校规里「禁林」两个字写得那么大。',
            nextStepId: 'ps_ch8_after',
            effect: StoryEffect(
              setFlags: ['ps_obeyed_forest_ban'],
              housePoints: 2,
              spirit: 1,
            ),
          ),
          StoryChoiceDef(
            id: 'a_telescope',
            text: '上钟楼用望远镜远远看了几眼',
            consequence:
                '望远镜的镜片里，林子是一片缓慢起伏的黑。凌晨两点，'
                '你看见了——林子深处有一点银白的东西倒了下去，'
                '随即有一道更黑的影子俯向它。你放下望远镜，'
                '手心冰凉，一夜没再合眼。',
            nextStepId: 'ps_ch8_after',
            effect: StoryEffect(
              addKnowledge: ['knows_forest_shadow'],
              setFlags: ['ps_saw_the_shadow'],
              reputation: 1,
              spirit: -4,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch8_after',
        chapterId: 'ps_ch8',
        timeCostDays: 3,
        setup:
            '几天后，消息还是传开了：那头独角兽没能救回来。'
            '海格在场地边的板房前站了很久，哑着嗓子让大家别去林子边。'
            '城堡里的空气比三月的雨还沉——有些东西死了，'
            '连一年级的你也感觉得到。',
        ambient: [
          '那天晚饭的礼堂格外安静，连最爱闹的一年级都乖乖坐着。',
          '板房外的栅栏上多了一小束不知谁放的野花。',
          '教授们的脸色都很差，连宾斯教授的课都提前放了十分钟。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'a_mourn',
            text: '放学后绕去板房，陪海格坐了一会儿',
            consequence:
                '你们谁都没怎么说话。海格递给你一杯茶，说：'
                '「独角兽的血是最强的东西，可喝它的人要被诅咒一辈子。」'
                '你不完全懂，但你记住了——有些捷径的代价，是一辈子。',
            nextStepId: '',
            effect: StoryEffect(
              targetNpcId: 'hagrid',
              affection: 2,
              addKnowledge: ['knows_unicorn_blood_price'],
              setFlags: ['ps_understood_price'],
              spirit: -3,
            ),
          ),
          StoryChoiceDef(
            id: 'a_vow',
            text: '在回塔的路上给自己立了个誓',
            consequence:
                '你把拳头攥紧又松开。你说不清自己为什么愤怒——'
                '你甚至没见过那头独角兽。但有些愤怒不需要理由。'
                '那晚你的卡片上多了一行字：变强，'
                '然后在下一次，站在能拦住它的地方。',
            nextStepId: '',
            effect: StoryEffect(
              setFlags: ['ps_vow_stronger'],
              reputation: 1,
              spirit: 4,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第九章 · 活板门之下（1992 年 6 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'ps_ch9',
    bookId: 'ps',
    ordinal: 9,
    title: '活板门之下',
    steps: [
      StoryStepDef(
        id: 'ps_ch9_whisper',
        chapterId: 'ps_ch9',
        timeCostDays: 2,
        setup:
            '六月的前两个星期，期末考结束，城堡里却涌动着一股压不住的'
            '窃窃私语：三楼那条禁走廊、那只三头狗、还有「有人看见'
            '几个一年级生半夜下了活板门」。传说越传越玄——唯一确定的'
            '是，几天后校长办公室的窗亮了一整夜，然后一切归于平静。',
        ambient: [
          '三楼走廊现在有三道锁、两道咒和一只打呼噜的三头狗——按传闻的说法。',
          '有高年级生拍了拍你的肩：「听说你们年级出了几个了不起的人物。」',
          '大礼堂里挂出了年终宴会的横幅，四个学院的颜色并排垂着。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'a_details',
            text: '把传闻的来龙去脉打听清楚',
            consequence:
                '你从三个不同的渠道把事情拼了个大概：金库里空了的东西'
                '被藏进了城堡，有人想偷，而几个一年级生抢在所有人前面'
                '把它保住了——「最后一个关头是校长赶到的。」'
                '你想起这一年里听到的所有传闻，忽然全都对上了。',
            nextStepId: 'ps_ch9_feast',
            effect: StoryEffect(
              addKnowledge: ['knows_trapdoor_ending'],
              setFlags: ['ps_knows_truth'],
              reputation: 1,
              spirit: 2,
            ),
          ),
          StoryChoiceDef(
            id: 'a_self',
            text: '觉得那是别人的人生，把自己的行李先收了',
            consequence:
                '你把书按科目捆好，袍子送去洗了，床头的墙上没留一颗钉子。'
                '传闻里的事再大，也大不过你要回的家和你自己的暑假。'
                '你把最后一本笔记本合上，心里出奇地平静。',
            nextStepId: 'ps_ch9_feast',
            effect: StoryEffect(
              setFlags: ['ps_packed_early'],
              housePoints: 1,
              spirit: 3,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch9_feast',
        chapterId: 'ps_ch9',
        // 原著节点：一年级期末与学院杯（1992 年 6 月）
        canonRefId: 'canon_ps_year_end',
        timeCostDays: 1,
        setup:
            '年终宴会那天，大礼堂的四张长桌按学院挂了色，天花板的星空'
            '亮得不像六月。邓布利多站起来致词，讲了讲这一年——然后，'
            '像所有传说的结尾那样，他宣布了最后几笔「特别贡献」加分，'
            '学院杯的名次在最后一刻翻了个个儿，半个礼堂都跳了起来。',
        ambient: [
          '长桌上堆着比平时多一倍的甜点，谁也顾不上吃相。',
          '有位教授在给毕业的七年级生一个一个签名留念。',
          '分院帽被搬回校长席旁的四脚凳上，帽檐耷拉着，像在打盹。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'a_toast',
            text: '站起来为你的朋友们举杯',
            consequence:
                '你端着南瓜汁站起来的时候手都有点抖——一年了，'
                '从站台上的陌生人到能互相挑错笔记的同桌，'
                '这个杯子敬他们，也敬你自己。你的学院那一桌响起了'
                '零零散散又汇成一片的掌声。',
            nextStepId: 'ps_ch9_farewell',
            effect: StoryEffect(
              targetNpcId: 'hermione',
              affection: 2,
              setFlags: ['ps_raised_cup'],
              housePoints: 2,
              spirit: 8,
            ),
          ),
          StoryChoiceDef(
            id: 'a_watch',
            text: '安静看完这最后一场喧闹',
            consequence:
                '你把宴会从头看到尾：名次、欢呼、蜡烛、彩带，'
                '还有讲台上校长那双弯起来的眼睛。你把这一切都收进记忆里'
                '——第一年，你活着，你学到了东西，'
                '你也终于知道这座城堡里什么最重要。',
            nextStepId: 'ps_ch9_farewell',
            effect: StoryEffect(
              addKnowledge: ['knows_house_cup_result'],
              setFlags: ['ps_watched_feast'],
              reputation: 2,
              spirit: 4,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch9_farewell',
        chapterId: 'ps_ch9',
        timeCostDays: 2,
        setup:
            '离别日的清晨，特快停靠在霍格莫德车站。行李箱堆上车的声音、'
            '猫头鹰的叫声、还有最后一批合影的闪光，把站台搅成一片'
            '温热的混乱。你站在车厢门口，身后是一整年，眼前是整个夏天。',
        ambient: [
          '海格抱着一大包岩皮饼，挨个发给这一年他记得住名字的学生。',
          '有只灰林鸮停在行李架上，脚环上系着一张写着「明年见」的小纸条。',
          '汽笛响了，月台上的人都往后退了半步，又都舍不得真的走开。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'a_promise',
            text: '和朋友们约好：九月一日，同一个站台',
            consequence:
                '你们把这句话说得很郑重，像签一份契约。车开动的时候，'
                '有人追着车厢跑了十几米，笑得直不起腰。你靠在车窗边想：'
                '明年，这座城堡里会有你的第二张床、你的老位子、'
                '和属于你自己的传说。',
            nextStepId: '',
            effect: StoryEffect(
              targetNpcId: 'ron',
              affection: 2,
              setFlags: ['ps_promised_next_year'],
              spirit: 6,
            ),
          ),
          StoryChoiceDef(
            id: 'a_quiet',
            text: '一个人先坐进包厢，把这一年写进本子里',
            consequence:
                '你翻开新本子的第一页：分院帽的低语、巨怪之夜的楼梯口、'
                '禁林边的月光、还有年终宴会的掌声。写到一半你停了笔——'
                '有些事不用写也会记一辈子。窗外，'
                '城堡的尖顶在视线里越来越小。',
            nextStepId: '',
            effect: StoryEffect(
              setFlags: ['ps_wrote_memoir'],
              spirit: 4,
            ),
          ),
        ],
      ),
    ],
  ),
];

// ================================================================
// 书表注册
// ================================================================

/// 《魔法石》的结局规则。
///
/// 【顺序即优先级】[resolveStoryEnding] 取第一个满足的规则，所以：
///   1. 特殊结局（需 flag + 数值）排最前；
///   2. **兜底结局排最后，且必须是无条件规则**——否则会出现"没有任何规则
///      匹配"的情况（`resolveStoryEnding` 会返回末位规则，但那份报告读起来
///      像是没判定成功）。结构上由 `test/story_data_test.dart` 的
///      「末位规则必须是兜底规则」守住。
///
/// 【数值预算】全好感路线的 `affection` 累计上限约 22（neville/hermione/
/// ron/seamus/hagrid 各章的总和），`reputation` 上限约 18——所以
/// `ps_ending_trusted` 的 20/10 是"几乎全走关心别人路线"才够得着的高门槛，
/// `ps_ending_companion` 的 8 是"做对几次关键选择"就能到的中等门槛。
const List<StoryEndingRule> _psEndings = [
  StoryEndingRule(
    id: 'ps_ending_trusted',
    title: '被记住的新生',
    body:
        '学年结束，你拖着箱子走下礼堂台阶。这一年你没有改变任何一件大事，'
        '但有人记住了你——在你需要的时候，他们愿意为你作证。',
    requireFlags: ['ps_family_supportive'],
    minAffectionTotal: 20,
    minReputation: 10,
  ),
  StoryEndingRule(
    id: 'ps_ending_companion',
    title: '并肩的人',
    body:
        '火车驶出站台的时候，有人在人群中朝你挥手。这一年你没能改变任何'
        '大事，但你做了几次正确的事——在楼梯口数人、在走廊里扶人、'
        '在禁林边守夜。你的名字被一些人记住了，用的是朋友的记法。',
    requireAnyFlags: [
      'ps_troll_stood_together',
      'ps_helped_firstyear',
      'ps_forest_helped_hagrid',
    ],
    minAffectionTotal: 8,
  ),
  StoryEndingRule(
    id: 'ps_ending_steady',
    title: '安安稳稳的一年级',
    body:
        '城堡的楼梯又换了一次方向，你已经能记住哪些会动、哪些不会。'
        '这一年没什么惊天动地的故事，但你活着，而且活着挺好。',
    minReputation: 1,
  ),
  StoryEndingRule(
    id: 'ps_ending_detached',
    title: '站在人群之外',
    body:
        '你选择了把自己摘干净。回头看，你确实没被卷进任何麻烦——'
        '代价是，也没人真的走近过你。',
  ),
];

const StoryBookDef _philosophersStone = StoryBookDef(
  id: 'ps',
  title: '魔法石',
  chapters: _psChapters,
  endings: _psEndings,
);

/// 注册全部剧情书。
///
/// 【为什么用函数而不是顶层 const 列表】`kStoryBooks` 定义在
/// `models/story_progress.dart`（纯函数层），而书表定义在这里（内容层）。
/// 顶层注册会在 import 时就生效，但那样"注册"这件事就不可测了——
/// 用 `void registerAllStoryBooks()` 让测试可以显式调用、也可断言幂等。
void registerAllStoryBooks() {
  registerStoryBook(_philosophersStone);
}
