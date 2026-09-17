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
/// forbidden_forest/year_end），《密室》另有 8 个
/// （lockhart/chamber_open/petrification/dueling_club/christmas/
/// diary/hermione_petrified/resolved）。本表按原著月份把它们排进对应章节，
/// **全部**由某一步声明讲述——由 `test/canon_story_parallel_test.dart`
/// 的「canon 节点全覆盖」守住。（收信不在 canon 节点表里，第一章不声明。）
///
/// 【批次 6 起的多书结构】本文件现在装两部**完整可玩**的书：
///   · `_philosophersStone`（9 章 26 步）+ `_chamberOfSecrets`
///     （12 章 32 步 67 选择 5 结局），都注册进 `kStoryBooks`；
///   · 《阿兹卡班的逃犯》~《死亡圣器》是骨架：`kBookOrder`/`kBookTitles`
///     （story_progress.dart）里有书序与书名，但**不注册**——玩家走到
///     部末衔接点会得到"还没装载"的明确提示，之后逐部精做时只需
///     往这里加书表 + 注册，衔接引擎不用再动。
///
/// 【开局场景对齐】开局时刻由 `opening_scene_data.dart` 决定（7/31 在家、
/// 8/20 对角巷、9/1 站台或礼堂）。`storyStartStepFor` 按开局场景把起始步
/// 跳到玩家真正所在的时间点，避免"9 月开局重新收到 7 月的信"的时间倒流。
///
/// 【版权说明】本文件只写剧情结构与氛围描述，不抄录原著原文句子。
library;

import '../models/story_progress.dart';
import 'story_data_poa.dart';
import 'story_data_gof.dart';
import 'story_data_ootp.dart';
import 'story_data_hbp.dart';
import 'story_data_dh.dart';

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
        timeCostDays: 1,
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
            nextStepId: 'ps_ch1_window',
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
            nextStepId: 'ps_ch1_window',
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
        id: 'ps_ch1_window',
        chapterId: 'ps_ch1',
        timeCostDays: 1,
        setup:
            '读完信之后，你做的第一件事是重新坐到窗边，把这件事想清楚。街上的夏天照旧：送奶的、遛狗的、隔壁小孩在墙根下踢一块石头。只有你知道，从今天起，这个世界在你眼里裂成了两半。',
        ambient: [
          '猫头鹰早已飞走了，窗台上只留下一小撮细绒毛。',
          '养母在楼下喊你去买面包，声音和平常没什么两样。',
          '你把信又抽出来看了一眼，确认那枚盾徽不是错觉。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'sit_watch',
            text: '就这么坐着看完一整条街，把这一天记牢',
            consequence:
                '你坐了很久，直到面包店的卷帘门拉下来。你想，以后大概很难再有这样一天——世界还是你熟悉的样子，而你已经知道它底下藏着别的什么。',
            nextStepId: 'ps_ch1_tell',
            effect: StoryEffect(setFlags: ['ps_watched_street'], spirit: 4),
          ),
          StoryChoiceDef(
            id: 'ask_neighbor',
            text: '揣着信去敲隔壁那户人家的门',
            consequence:
                '开门的老太太听完只是笑，说「小孩子做梦想进城堡」。你谢过她，转身往回走——原来在不知道的人眼里，这件事看起来就像个笑话。你没再提。',
            nextStepId: 'ps_ch1_tell',
            effect: StoryEffect(setFlags: ['ps_dismissed_by_neighbor'], spirit: -2),
          ),
          StoryChoiceDef(
            id: 'tell_neighbor_truth',
            text: '跑回家，把信从头到尾念给养父母听',
            consequence:
                '你冲进厨房，把信展开在餐桌上，一字不落地念完。'
                '养父听完只说了句「先吃饭」，但他把报纸折起来放在了一边。'
                '那天晚上，你听见他们在隔壁压低声音商量了很久。',
            requireFlag: 'ps_read_letter_first',
            effect: StoryEffect(
              setFlags: ['ps_told_family_early'],
              addKnowledge: ['family_knows_early'],
              reputation: 2,
              spirit: 3,
            ),
          ),

        ],
      ),
      StoryStepDef(
        id: 'ps_ch1_tell',
        chapterId: 'ps_ch1',
        timeCostDays: 1,
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
            nextStepId: 'ps_ch1_list',
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
            nextStepId: 'ps_ch1_list',
            effect: StoryEffect(
              setFlags: ['ps_family_in_the_dark'],
              spirit: -5,
            ),
          ),
          StoryChoiceDef(
            id: 'show_letter_as_proof',
            text: '先把信推过去给他们看，再开口解释',
            consequence:
                '你没急着说话，只是把信连着信封一起推过去。'
                '养母捏着那枚蜡封看了很久，忽然问：「这个图案，'
                '是不是会动的？」——她其实早就见过一次，只是不敢告诉你。',
            requireFlag: 'ps_read_letter_first',
            effect: StoryEffect(
              setFlags: ['ps_letter_as_proof'],
              addKnowledge: ['family_had_hint'],
              reputation: 2,
              spirit: 3,
            ),
          ),

        ],
      ),
      StoryStepDef(
        id: 'ps_ch1_list',
        chapterId: 'ps_ch1',
        timeCostDays: 1,
        setup:
            '清单被你摊在饭桌上，一样一样念过去：三套黑色工作长袍、一顶素面尖顶帽、一门课的课本、一口锡镴坩埚。念到「学生可携带猫头鹰、猫或蟾蜍」这一行时，你停顿了一下——原来连这个都有规定。',
        ambient: [
          '养父拿铅笔在纸边算总数，眉头越皱越紧。',
          '纸角被汤碗压出了一个圆印子。',
          '窗外有辆卡车经过，桌上的杯子轻轻震了一下。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'save_list',
            text: '把清单折好收进书桌抽屉最里层',
            consequence:
                '你把它压在旧成绩单下面。那抽屉里装着各种你舍不得扔的东西——现在多了这张纸。你知道再过一个月它就会变成真的。',
            nextStepId: 'ps_ch1_study',
            effect: StoryEffect(setFlags: ['ps_saved_list'], spirit: 3),
          ),
          StoryChoiceDef(
            id: 'read_aloud',
            text: '拉着养母把每一样都念给她听',
            consequence:
                '你念得很慢，她就跟着一道一道问「这个贵不贵」「这个危险吗」。念完以后她说：「去吧，别丢东西。」这大概是她能给出的最接近祝福的话。',
            nextStepId: 'ps_ch1_study',
            effect: StoryEffect(setFlags: ['ps_family_heard_list'], spirit: 5),
          ),
          StoryChoiceDef(
            id: 'ask_budget',
            text: '指着清单上的价钱，问家里这笔钱够不够',
            consequence:
                '你把清单往养父那边推了推。他拿铅笔算了很久，'
                '最后说：「够，但你得自己去，学着自己算钱。」'
                '那张写满数字的纸被他折好收进了口袋。',
            requireFlag: 'ps_told_family_early',
            effect: StoryEffect(
              setFlags: ['ps_asked_budget'],
              addKnowledge: ['knows_school_cost'],
              reputation: 2,
              spirit: 2,
            ),
          ),

        ],
      ),
      StoryStepDef(
        id: 'ps_ch1_study',
        chapterId: 'ps_ch1',
        timeCostDays: 1,
        setup:
            '离九月一日还有一个月。你在抽屉深处翻出几本旧课本，'
            '想先把能看懂的看一遍——可书上的字像是活的，'
            '你盯着一页看了十分钟，只觉得那些字母在纸上彼此推搡。'
            '窗外的夏天正在一天天变短。',
        ambient: [
          '邻居家的孩子骑车经过，车铃响了两声，又骑远了。',
          '台灯的光晕里，你的影子落在翻开的书页上，一动不动。',
          '楼下传来电视的声音，播报员在念今天的天气。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'try_letters',
            text: '硬着头皮，把字母一个一个抄下来',
            consequence:
                '你抄满了整整两页纸。抄到第三页时，某个词突然自己'
                '「亮」了一下——不是发光，是你忽然读懂了它。'
                '你把这一页折了个角，决定以后每天都抄一点。',
            nextStepId: 'ps_ch1_visit',
            effect: StoryEffect(
              setFlags: ['ps_studied_ahead'],
              addKnowledge: ['knows_letters_shift'],
              spirit: 3,
            ),
          ),
          StoryChoiceDef(
            id: 'give_up',
            text: '合上书，觉得到时候老师自然会教',
            consequence:
                '你把书塞回抽屉，用力推了一下抽屉让它关严。'
                '反正买书的日子在后头，现在着急也没用——'
                '你决定把剩下的暑假用来做点看得懂的事。',
            nextStepId: 'ps_ch1_visit',
            effect: StoryEffect(
              setFlags: ['ps_no_prep'],
              spirit: 2,
            ),
          ),
          StoryChoiceDef(
            id: 'show_letters_to_family',
            text: '把抄满字母的那两页纸拿给家里人看',
            consequence:
                '养母看不懂，但她把那两页纸抚平，贴在了冰箱门上。'
                '接下来一个月，你每次经过厨房都会看到自己的字——'
                '它们提醒你，这件事已经不只是你一个人的秘密了。',
            requireFlag: 'ps_told_family_early',
            effect: StoryEffect(
              setFlags: ['ps_family_seen_effort'],
              addKnowledge: ['knows_letters_shift'],
              spirit: 5,
              reputation: 2,
            ),
          ),

        ],
      ),
      StoryStepDef(
        id: 'ps_ch1_visit',
        chapterId: 'ps_ch1',
        timeCostDays: 1,
        setup:
            '八月初的一个下午，一位穿着深绿色斗篷的巫师来家里拜访。'
            '他自称是霍格沃茨的「联络人」，负责给麻瓜出身的家庭做说明。'
            '他从袖子里抽出一根细杖，把养母手里那只总也不热的茶杯变成了'
            '一只吱吱叫的仓鼠——然后又变了回去。',
        ambient: [
          '养父全程没说话，只是盯着那只杯子，手指在桌沿上敲个不停。',
          '仓鼠在茶杯里打了个转，把奶油色的茶渍蹭得到处都是。',
          '那位巫师说话很慢，每句话都像早就被说过一百遍。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'ask_questions',
            text: '把攒了一个月的问题全问出来',
            consequence:
                '你问了学校在哪、有多少门课、会不会有危险、'
                '还有「为什么是我」。他一条条答，答到最后一条时停了停：'
                '「没有为什么。你会魔法，这就够了。」'
                '这句话你记了很多年。',
            nextStepId: 'ps_ch1_reply',
            effect: StoryEffect(
              addKnowledge: ['knows_school_basics'],
              setFlags: ['ps_asked_why_me'],
              reputation: 2,
              spirit: 6,
            ),
          ),
          StoryChoiceDef(
            id: 'watch_quietly',
            text: '坐在一边，看他们怎么跟养父母解释',
            consequence:
                '你什么也没问，只是听。听他说学费有专款、'
                '听他说假期可以回家、听他说「孩子会写信」。'
                '你忽然发现养母的肩膀松下来了一点——'
                '原来她担心的从来不是「魔法」，是「你回不回来」。',
            nextStepId: 'ps_ch1_reply',
            effect: StoryEffect(
              setFlags: ['ps_watched_explanation'],
              spirit: 4,
            ),
          ),
          StoryChoiceDef(
            id: 'ask_about_war',
            text: '问那位巫师：信上这枚盾徽，是不是出过什么事',
            consequence:
                '他愣了一下，没有立刻回答。过了一会儿他才说：'
                '「那上面最后一场仗，打完还不到十年。你以后会听到很多说法，'
                '先别急着信哪一个。」——你没听懂，但把这句话记住了。',
            requireFlag: 'ps_confronted_family',
            effect: StoryEffect(
              setFlags: ['ps_asked_about_past'],
              addKnowledge: ['knows_recent_war_hint'],
              spirit: -2,
              reputation: 1,
            ),
          ),

        ],
      ),
      StoryStepDef(
        id: 'ps_ch1_reply',
        chapterId: 'ps_ch1',
        timeCostDays: 1,
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
            nextStepId: 'ps_ch1_postbox',
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
            nextStepId: 'ps_ch1_postbox',
            effect: StoryEffect(
              setFlags: ['ps_accepted', 'ps_hesitated_first'],
              addKnowledge: ['will_go_to_hogwarts'],
              spirit: -3,
              reputation: 1,
            ),
          ),
          StoryChoiceDef(
            id: 'write_alone',
            text: '把门关好，自己一个人写完这张回执',
            consequence:
                '你没跟任何人商量，笔尖落下去的时候手很稳。'
                '写完之后你把回执从头看了一遍，确认每个字母都对——'
                '这是你第一次替自己的人生签了字。',
            requireFlag: 'ps_saved_list',
            effect: StoryEffect(
              setFlags: ['ps_accepted', 'ps_wrote_it_alone'],
              addKnowledge: ['will_go_to_hogwarts'],
              reputation: 2,
              spirit: 6,
            ),
          ),

        ],
      ),
      StoryStepDef(
        id: 'ps_ch1_postbox',
        chapterId: 'ps_ch1',
        timeCostDays: 1,
        setup:
            '回信写完之后，你捏着那只不肯离开的猫头鹰发愁：麻瓜的邮筒显然不合适，而厨房的烟囱又太窄。最后你把回执系在它腿上，走到院子里，把它举过头顶。',
        ambient: [
          '夜里的风比白天凉，草叶上已经有了露水。',
          '远处有人家在放电视，声音闷闷的，听不清在说什么。',
          '猫头鹰的爪子在你手腕上紧了紧，像是催你快点。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'release_now',
            text: '松手，看着它飞进夜色里',
            consequence:
                '它飞得很低，掠过一排屋顶，然后突然拔高，几秒钟就融进了黑。你仰着头站了很久，脖子都酸了。',
            nextStepId: 'ps_ch1_last_night',
            effect: StoryEffect(setFlags: ['ps_owl_released'], spirit: 4),
          ),
          StoryChoiceDef(
            id: 'hold_back',
            text: '先把它带回房间，喂点面包再送',
            consequence:
                '你翻出半块面包，它却看都不看，只是盯着你。你忽然明白它在等什么——于是你把窗户推开，它就走了。',
            nextStepId: 'ps_ch1_last_night',
            effect: StoryEffect(setFlags: ['ps_fed_owl'], spirit: 6),
          ),
          StoryChoiceDef(
            id: 'tell_family_before',
            text: '回屋叫上家里人到院子里，一起看它飞走',
            consequence:
                '你把养父母都叫了出来。三个人仰着头站在草地上，'
                '看那只猫头鹰越飞越小。养母小声说了句「它真快」，'
                '养父没说话，但他一直站到你转身回屋才动。',
            requireFlag: 'ps_told_family_early',
            effect: StoryEffect(
              setFlags: ['ps_family_saw_owl'],
              reputation: 2,
              spirit: 6,
            ),
          ),

        ],
      ),
      StoryStepDef(
        id: 'ps_ch1_last_night',
        chapterId: 'ps_ch1',
        timeCostDays: 1,
        setup:
            '开学前的最后一夜，你躺在床上睡不着。行李箱立在墙角，'
            '里面装着新买的长袍、几本还读不太懂的课本，'
            '还有养母偷偷塞进来的一小包饼干。'
            '你把手伸到枕头底下——那封信还在那儿。',
        ambient: [
          '窗帘没拉严，路灯的光在墙上拉出一条细长的亮线。',
          '楼下偶尔传来一声碗碟轻响，说明还没人睡。',
          '你把饼干包摸出来，拆了一小块，味道和平常一样。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'memorize_room',
            text: '站起来，把房间的每个角落都看一遍',
            consequence:
                '书桌、窗户、那道被铅笔划过无数次的墙、'
                '还有门后那道你小时候量身高的刻痕。'
                '你把这些都看了一遍，像是要给它们拍一张照片存在脑子里。'
                '明天起，这间屋子就只是「家」了。',
            nextStepId: '',
            effect: StoryEffect(
              setFlags: ['ps_said_goodbye_room'],
              spirit: 5,
            ),
          ),
          StoryChoiceDef(
            id: 'sleep_early',
            text: '闭上眼，逼自己早点睡',
            consequence:
                '你翻了个身，把脸埋进枕头。心跳还是快，但你已经'
                '决定了——明天要走。想到这儿，睡意反而自己来了。',
            nextStepId: '',
            effect: StoryEffect(
              setFlags: ['ps_slept_before_departure'],
              spirit: 4,
            ),
          ),
          StoryChoiceDef(
            id: 'reread_letter_once',
            text: '把枕头下的信再抽出来，就着路灯光读最后一遍',
            consequence:
                '你已经能背下大半封了，可还是想再看一遍。读到书单那一段时，'
                '你注意到自己上个月抄下的那些字母已经认得出来了——'
                '原来这一个月并没有白过。你把信放回去，很快睡着了。',
            requireFlag: 'ps_studied_ahead',
            effect: StoryEffect(
              setFlags: ['ps_reread_before_departure'],
              spirit: 5,
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
        timeCostDays: 1,
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
          StoryChoiceDef(
            id: 'a_owl_office',
            text: '先去邮局，把信里那张回执寄了',
            consequence:
                '你逆着人流走进邮局，把回执递给柜台后那个妖精。'
                '他扫了一眼蜡封，什么都没多问，只是把回执塞进一只'
                '标着「霍格沃茨」的木格子里。这件事办完，你才觉得自己'
                '真的要去上学了。',
            requireFlag: 'ps_fed_owl',
            effect: StoryEffect(
              setFlags: ['ps_posted_reply_first'],
              addKnowledge: ['knows_school_basics'],
              reputation: 1,
              spirit: 4,
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
            nextStepId: 'ps_ch2_crowd',
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
            nextStepId: 'ps_ch2_crowd',
            effect: StoryEffect(
              setFlags: ['ps_kept_head_down'],
              galleons: 5,
              spirit: 3,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch2_crowd',
        chapterId: 'ps_ch2',
        timeCostDays: 1,
        setup:
            '巷子里的人比你预想的要多得多。穿长袍的人、抱坩埚的人、肩上蹲着猫头鹰的人，挤在同一条鹅卵石街上。你被推着往前走，忽然意识到自己完全不知道该先去哪家。',
        ambient: [
          '有人扛着一摞教材从书店出来，最上面那本在往下滑。',
          '街角蹲着一只瘦猫，正盯着药店门口挂着的一串死老鼠看。',
          '空气里混着羊皮纸、蜡油和一点点硫磺的味道。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'follow_group',
            text: '跟上一群背着新书包的同龄人',
            consequence:
                '你跟着他们走进长袍店，又跟着他们拐去书店。全程没人跟你说话，但你已经把这条街的顺序记熟了——这是最省事的认路方式。',
            nextStepId: 'ps_ch2_vault',
            effect: StoryEffect(setFlags: ['ps_learned_diagon'], spirit: 3),
          ),
          StoryChoiceDef(
            id: 'ask_direction',
            text: '停下脚步，找个店员问路',
            consequence:
                '一个高个子的店员用魔杖指了指街尾，然后说「第一次来吧」。你点头。他笑了笑：「那就慢慢逛，反正你以后每年都来。」',
            nextStepId: 'ps_ch2_vault',
            effect: StoryEffect(addKnowledge: ['knows_diagon_layout'], setFlags: ['ps_asked_for_directions'], spirit: 2),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch2_vault',
        chapterId: 'ps_ch2',
        timeCostDays: 1,
        setup:
            '妖精领着你走过一段向下的石阶，空气越来越冷。轨道小车在黑暗里穿行，风声在耳边刮过去。最后停在一扇小门前——那扇门比走廊里所有门都小一圈。',
        ambient: [
          '车厢的木板上刻满了各种名字和日期，最早的已经看不清了。',
          '隧道深处有水滴声，一下一下，很规律。',
          '妖精把钥匙插进锁孔的时候，手背上的青筋鼓了起来。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'count_coins',
            text: '把属于你的金币一枚一枚数清楚',
            consequence:
                '你数了三遍，确认了数目。这些钱够买齐清单上的每一样，还能剩下一点。你把它们重新装好，扎紧了袋口。',
            nextStepId: 'ps_ch2_shopping',
            effect: StoryEffect(setFlags: ['ps_counted_galleons'], spirit: 3, galleons: 12),
          ),
          StoryChoiceDef(
            id: 'think_rumor',
            text: '站在金库门口，又想起刚才听到的那句传闻',
            consequence:
                '你回头看了看走廊深处——那里还有几百扇同样的小门。闯进来的人到底在找哪一扇？这个问题你没问出口，因为问了也不会有人答。',
            nextStepId: 'ps_ch2_shopping',
            effect: StoryEffect(addKnowledge: ['knows_gringotts_depth'], setFlags: ['ps_pondered_gringotts'], spirit: -1),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch2_shopping',
        canonRefId: 'canon_ps_diagon_alley',
        chapterId: 'ps_ch2',
        timeCostDays: 17,
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
            nextStepId: 'ps_ch2_books',
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
            nextStepId: 'ps_ch2_books',
            effect: StoryEffect(
              addItems: ['标准咒语书'],
              setFlags: ['ps_wand_old'],
              reputation: 1,
              spirit: 5,
            ),
          ),
          StoryChoiceDef(
            id: 'a_ask_about_old_wars',
            text: '试着问店主一句：这些魔杖打过仗吗',
            consequence:
                '店主从鼻子上方看了你一眼，说：「每一根都打过。」'
                '他把一只盒子推过来，补充道：「魔杖不会挑平安的年头，'
                '它只挑拿得动的人。」你握着那根杖，觉得比刚才沉了一点。',
            requireKnowledge: ['knows_recent_war_hint'],
            effect: StoryEffect(
              addItems: ['标准咒语书'],
              setFlags: ['ps_wand_grave_talk'],
              spirit: -1,
              reputation: 1,
            ),
          ),

        ],
      ),
      StoryStepDef(
        id: 'ps_ch2_books',
        chapterId: 'ps_ch2',
        timeCostDays: 1,
        setup:
            '丽痕书店的门口堆着一摞一摞的教材，店员正用魔杖把它们一本本送到不同的顾客手里。你挤进去，在书架的阴影里找到了自己清单上的那几本。',
        ambient: [
          '有个一年级生把《标准咒语》拿反了，正皱着眉头看。',
          '书架顶上蹲着一只店猫，尾巴垂下来一晃一晃。',
          '收银台前排着队，有人在抱怨今年的书又涨价了。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'browse_extra',
            text: '多花点时间，把别的书也翻一翻',
            consequence:
                '你在角落翻到一本讲城堡传说的旧书，里面提到霍格沃茨的楼梯会自己换方向。你记下了这一条，付钱的时候还在想那会是什么样子。',
            nextStepId: 'ps_ch2_icecream',
            effect: StoryEffect(addItems: ['标准咒语书'], setFlags: ['ps_browsed_extra'], spirit: 4),
          ),
          StoryChoiceDef(
            id: 'buy_and_go',
            text: '按清单买齐就走，别耽误时间',
            consequence:
                '你把书抱在怀里出门，纸页的味道一路跟着你。清单上的东西差不多齐了，只剩下最后一个也是最要紧的一项。',
            nextStepId: 'ps_ch2_icecream',
            effect: StoryEffect(addItems: ['标准咒语书'], setFlags: ['ps_quick_shopper'], spirit: 2),
          ),
          StoryChoiceDef(
            id: 'pick_letters_reader',
            text: '专门挑一本字母排得最清楚的书',
            consequence:
                '你把几本都摊开比了比，挑了那本行距最宽、字体最端正的。'
                '店员说这本旧一点，但你没有换——上个月抄字母的滋味你还记得，'
                '凡是能让眼睛省点力的地方，你都愿意多花一分钟。',
            requireKnowledge: ['knows_letters_shift'],
            effect: StoryEffect(
              addItems: ['标准咒语书'],
              setFlags: ['ps_picked_easy_read'],
              spirit: 4,
            ),
          ),

        ],
      ),
      StoryStepDef(
        id: 'ps_ch2_icecream',
        chapterId: 'ps_ch2',
        timeCostDays: 1,
        setup:
            '采购到一半，你在街边的小店买了一份冰淇淋——那种会冒冷烟、颜色不太对劲的那种。你靠在店门口的柱子上，看整条街的人来人往。',
        ambient: [
          '有对老夫妻在挑猫头鹰，把每只都叫起来听声音。',
          '一个比你高半头的男孩抱着一大包东西匆匆走过，撞了你一下。',
          '冰淇淋化得比想象中快，汁水顺着手指往下淌。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'watch_people',
            text: '慢慢吃完，把这条街的人和事都看一遍',
            consequence:
                '你看到了至少三种不同的长袍款式、两个因为扫帚型号吵架的少年、和一位把帽子戴反了的老巫师。这些细节你后来一直记得。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['ps_people_watcher'], spirit: 5),
          ),
          StoryChoiceDef(
            id: 'offer_seat',
            text: '把旁边的凳子让给一个抱着小孩的女士',
            consequence:
                '她谢了你，坐下喂孩子吃点心。你站在一边把冰淇淋吃完，觉得今天的太阳格外好。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['ps_offered_kindness'], reputation: 2, spirit: 3),
          ),
          StoryChoiceDef(
            id: 'piece_together_date',
            text: '把报纸上的日期和自己收到信的日子对一下',
            consequence:
                '你在心里数了一遍：金库被闯是七月底，你收到信也是七月底，'
                '前后差不了几天。这条巧合你说不出意味着什么，'
                '但它让你第一次觉得，魔法世界的事也讲究个来龙去脉。',
            requireKnowledge: ['knows_gringotts_rumor'],
            effect: StoryEffect(
              setFlags: ['ps_noted_date_coincidence'],
              reputation: 2,
              spirit: 3,
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
        timeCostDays: 7,
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
            nextStepId: 'ps_ch3_wall',
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
            nextStepId: 'ps_ch3_wall',
            effect: StoryEffect(
              setFlags: ['ps_window_seat'],
              spirit: 2,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch3_wall',
        chapterId: 'ps_ch3',
        timeCostDays: 1,
        setup:
            '正对着那堵砖墙的时候，你犹豫了半秒。看起来它就是一堵结结实实的墙，后面是站台的承重柱。但前面那个穿校服的男孩毫不犹豫地撞了进去，消失了。',
        ambient: [
          '墙面上有一小块砖颜色比别处浅，像是被人反复摸过。',
          '你身后有人推着行李车排队，不耐烦地清了清嗓子。',
          '你的手心出汗了，把行李车的把手弄湿了一小片。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'walk_straight',
            text: '闭一口气，直直走进去',
            consequence:
                '预想中的撞击没有发生。你穿过去的瞬间只觉得脸上一凉，然后就看见了那辆猩红色的火车，和挤满整个站台的、和你一样的学生。',
            nextStepId: 'ps_ch3_train',
            effect: StoryEffect(setFlags: ['ps_braved_wall'], spirit: 6),
          ),
          StoryChoiceDef(
            id: 'watch_first',
            text: '退到一边，再看来两个人过去才敢走',
            consequence:
                '你数到第五个人才挪步。走过去的时候你其实已经不怕了，但你还是走得很快——好像慢一点墙就会变硬。',
            nextStepId: 'ps_ch3_train',
            effect: StoryEffect(setFlags: ['ps_watched_first'], spirit: 2),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch3_train',
        canonRefId: 'canon_ps_platform',
        chapterId: 'ps_ch3',
        timeCostDays: 5,
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
            nextStepId: 'ps_ch3_candy',
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
            nextStepId: 'ps_ch3_candy',
            effect: StoryEffect(
              setFlags: ['ps_quiet_rider'],
              spirit: 3,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch3_candy',
        canonRefId: 'canon_ps_first_classes',
        chapterId: 'ps_ch3',
        timeCostDays: 1,
        setup:
            '零食车推到你们包厢门口，老太太问要不要来点什么。你掏出口袋里的零钱，发现能买的东西比想象中多——巧克力蛙、比比多味豆、南瓜馅饼、还有几种你叫不上名字的。',
        ambient: [
          '隔壁包厢传来一声惊呼，大概是有人抽到了重复的卡片。',
          '车厢晃了一下，零食车上的罐子互相碰了碰。',
          '窗外开始出现田野，牛群在坡上慢吞吞地移动。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'share_candy',
            text: '各样买两包，分给包厢里的人',
            consequence:
                '你把糖倒在座位上，几个人很快就吃开了。有人抽到一张著名巫师的卡片，举起来给大家看。这是你第一次觉得，学校可能不只是个地方，还是一群人。',
            nextStepId: '',
            effect: StoryEffect(addItems: ['比比多味豆'], setFlags: ['ps_shared_sweets'], spirit: 5, targetNpcId: 'ron', affection: 2),
          ),
          StoryChoiceDef(
            id: 'eat_alone',
            text: '只买自己那份，靠着窗户慢慢吃',
            consequence:
                '你把巧克力蛙拆开，它一下跳到窗玻璃上，你手忙脚乱地把它按住。旁边的人笑了，你也跟着笑了——这一天开始变得轻松起来。',
            nextStepId: '',
            effect: StoryEffect(addItems: ['巧克力蛙'], setFlags: ['ps_ate_alone'], spirit: 4),
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
        timeCostDays: 5,
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
            nextStepId: 'ps_ch4_lake',
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
            nextStepId: 'ps_ch4_lake',
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
        id: 'ps_ch4_lake',
        chapterId: 'ps_ch4',
        timeCostDays: 1,
        setup:
            '船在黑湖上滑行，水面平得像一块黑玻璃。抬头的时候，城堡就在山丘上——窗口一扇一扇地亮着，比你见过的任何一栋建筑都大。',
        ambient: [
          '船头破开的水纹里，偶尔有个什么影子一闪而过。',
          '有人在船上小声说「那里面会不会有东西」。',
          '桨划水的声音很轻，整支船队都安安静静的。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'look_castle',
            text: '一直抬头看着城堡，直到脖子发酸',
            consequence:
                '你数不清有多少扇窗。船靠岸的时候你还仰着头，差点绊了一跤。有人扶了你一把，你说了谢谢，眼睛还留在那上面。',
            nextStepId: 'ps_ch4_wait',
            effect: StoryEffect(setFlags: ['ps_first_sight_castle'], spirit: 7),
          ),
          StoryChoiceDef(
            id: 'watch_water',
            text: '低头看湖水，想知道底下有什么',
            consequence:
                '水很黑，什么也看不见。但你隐约觉得，刚才那个影子比鱼要大得多。你决定不去想它——至少今天晚上不去想。',
            nextStepId: 'ps_ch4_wait',
            effect: StoryEffect(addKnowledge: ['knows_lake_is_deep'], setFlags: ['ps_watched_lake'], spirit: 3),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch4_wait',
        chapterId: 'ps_ch4',
        timeCostDays: 1,
        setup:
            '名字一个接一个被念出来，被念到的人走上前，坐上那张凳子，帽子落到头上。你站在队伍里，手心里的汗把长袍的袖口浸湿了一小块。',
        ambient: [
          '前排有个女孩被分到某个学院时，那边的长桌爆出一阵欢呼。',
          '天花板上的星星一动不动，像真的夜空被搬进了屋子里。',
          '你听见自己的心跳，比周围所有的声音都响。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'listen_hat',
            text: '竖起耳朵，仔细听帽子都在说什么',
            consequence:
                '你听出来了：帽子不是随便喊一个学院，它像是在跟每个人商量。有的商量得很久，有的刚一戴上就喊了出来。这个发现让你心里踏实了些。',
            nextStepId: 'ps_ch4_sorting',
            effect: StoryEffect(addKnowledge: ['knows_hat_chooses'], setFlags: ['ps_listened_to_hat'], spirit: 4),
          ),
          StoryChoiceDef(
            id: 'count_ahead',
            text: '默默数前面还有几个人',
            consequence:
                '还有七个、六个、五个……数字越数越小，你反而越来越平静。轮到你的前一个，你甚至开始好奇自己会去哪里。',
            nextStepId: 'ps_ch4_sorting',
            effect: StoryEffect(setFlags: ['ps_counted_queue'], spirit: 3),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch4_sorting',
        chapterId: 'ps_ch4',
        // 原著节点：入学与分院（1991 年 9 月）
        canonRefId: 'canon_ps_sorting',
        timeCostDays: 6,
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
        timeCostDays: 7,
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
            nextStepId: 'ps_ch5_doorway',
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
            nextStepId: 'ps_ch5_doorway',
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
        id: 'ps_ch5_doorway',
        chapterId: 'ps_ch5',
        timeCostDays: 1,
        setup:
            '第一堂课上完，你在走廊里迷了路。楼梯在你回头的时候换了个方向，本来是往上的，现在变成了往左。你抱着课本，站在一个完全陌生的岔口。',
        ambient: [
          '墙上的画里，一位骑士正在跟旁边那幅画吵架。',
          '有只猫从你脚边走过，然后在拐角处停下，回头看了你一眼。',
          '远处传来上课铃，但你不确定那是哪个方向。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'ask_painting',
            text: '向墙上的画问路',
            consequence:
                '画里的骑士停止了争吵，很认真地给你指了一条路，然后补充说「不过它会动」。你谢过他，走了十分钟才明白这句话的意思。',
            nextStepId: 'ps_ch5_potions',
            effect: StoryEffect(setFlags: ['ps_asked_painting'], spirit: 3),
          ),
          StoryChoiceDef(
            id: 'follow_cat',
            text: '跟着那只猫走',
            consequence:
                '猫在走廊里七拐八拐，最后停在一扇门前，舔了舔爪子就走了。你推门进去——居然就是你要找的教室。你后来一直怀疑那不是普通的猫。',
            nextStepId: 'ps_ch5_potions',
            effect: StoryEffect(addKnowledge: ['knows_castle_cats'], setFlags: ['ps_followed_cat'], spirit: 5),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch5_potions',
        chapterId: 'ps_ch5',
        timeCostDays: 7,
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
            nextStepId: 'ps_ch5_cauldron',
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
            nextStepId: 'ps_ch5_cauldron',
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
        id: 'ps_ch5_cauldron',
        canonRefId: 'canon_ps_quidditch_tryout',
        chapterId: 'ps_ch5',
        timeCostDays: 2,
        setup:
            '魔药课下课后，你的坩埚里还剩半锅没倒掉的药剂。它在你收拾书包的时候慢慢变成了浅紫色，然后开始冒一种很小的泡。',
        ambient: [
          '地窖比城堡别的地方都冷，你的手指有点僵。',
          '架子上排着一罐罐泡着东西的玻璃瓶，标签字迹很小。',
          '隔壁桌的人早就跑光了，只剩下你和这锅东西。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'clean_thoroughly',
            text: '按课本写的步骤，一点一点刷干净',
            consequence:
                '你花了二十分钟。刷到最后，坩埚亮得能照出人影。教授路过的时候看了你一眼，什么也没说，但第二天上课他叫了你的名字。',
            nextStepId: 'ps_ch5_library',
            effect: StoryEffect(setFlags: ['ps_cleaned_cauldron'], housePoints: 5, spirit: 3),
          ),
          StoryChoiceDef(
            id: 'leave_quickly',
            text: '盖上盖子就走，反正下次还要用',
            consequence:
                '你把坩埚塞进书包，快步出了地窖。走到一半你闻到了一股怪味——那锅东西在你的书包里，把一本课本的封面染成了紫色。',
            nextStepId: 'ps_ch5_library',
            effect: StoryEffect(setFlags: ['ps_left_cauldron'], spirit: -2),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch5_library',
        canonRefId: 'canon_ps_halloween_prep',
        chapterId: 'ps_ch5',
        timeCostDays: 7,
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
            nextStepId: 'ps_ch5_note',
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
            nextStepId: 'ps_ch5_note',
            effect: StoryEffect(
              addKnowledge: ['knows_secret_corridors'],
              setFlags: ['ps_explored_castle'],
              spirit: 5,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch5_note',
        chapterId: 'ps_ch5',
        timeCostDays: 1,
        setup:
            '图书馆的闭馆铃响了，你才发现自己坐了两个多小时。桌上的羊皮纸写满了字，但翻到下一页，你发现有几行写得完全看不懂——像是自己写的，又不像。',
        ambient: [
          '平斯夫人正在把散落的书归位，脚步声很轻。',
          '窗外已经完全黑了，玻璃上倒映着你的脸。',
          '油灯的火苗晃了一下，然后又稳住了。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'copy_neat',
            text: '把看不懂的那几行重新誊抄一遍',
            consequence:
                '你抄完之后，那几行字还是不懂，但形状记住了。你把纸夹进课本，想着也许以后哪一天会突然明白。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['knows_strange_handwriting'], setFlags: ['ps_copied_notes'], spirit: 2),
          ),
          StoryChoiceDef(
            id: 'pack_up',
            text: '收好东西赶紧回去，明天还要早起',
            consequence:
                '你把纸卷起来塞进书包，几乎是小跑着出了图书馆。走廊里的画像都已经睡了，有几幅还在轻轻打鼾。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['ps_left_library_early'], spirit: 3),
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
        timeCostDays: 4,
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
            nextStepId: 'ps_ch6_pumpkins',
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
            nextStepId: 'ps_ch6_pumpkins',
            effect: StoryEffect(
              setFlags: ['ps_rest_before'],
              spirit: 2,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch6_pumpkins',
        chapterId: 'ps_ch6',
        timeCostDays: 1,
        setup:
            '万圣节前，大礼堂被装饰得闪闪发亮：上千只南瓜雕成的灯笼漂浮在天花板下面，烤南瓜的味道从厨房一路飘到门厅。',
        ambient: [
          '有只蝙蝠从蜡烛上方掠过，把火苗吹得歪了一下。',
          '长桌上摆着还没点完的蜡烛，排列得很整齐。',
          '几个低年级生正踮脚去够漂浮的南瓜。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'help_decorate',
            text: '留下来帮忙把剩余的南瓜灯挂好',
            consequence:
                '你踩在凳子上挂了六只，最后一只位置太高，是路过的高年级生帮你按住的。全部挂完的时候，整个礼堂像被点着了一样亮。',
            nextStepId: 'ps_ch6_troll',
            effect: StoryEffect(setFlags: ['ps_helped_decorate'], housePoints: 5, spirit: 5),
          ),
          StoryChoiceDef(
            id: 'go_early',
            text: '早点回公共休息室，避开晚宴的拥挤',
            consequence:
                '你顺着人流往回走，路上只碰到两三个人。休息室的炉火烧得很旺，你找了个靠火的位置坐下。',
            nextStepId: 'ps_ch6_troll',
            effect: StoryEffect(setFlags: ['ps_left_early'], spirit: 2),
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
        timeCostDays: 2,
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
            nextStepId: 'ps_ch6_corridor',
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
            nextStepId: 'ps_ch6_corridor',
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
            nextStepId: 'ps_ch6_corridor',
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
        id: 'ps_ch6_corridor',
        chapterId: 'ps_ch6',
        timeCostDays: 1,
        setup:
            '巨怪的消息传开之后，走廊里全是乱跑的人。你被裹在人流里往前推，脚下的石板上有一摊没干的水渍。',
        ambient: [
          '有人摔了一跤，书包里的课本散了一地。',
          '远处传来一声闷响，接着是好几个人的尖叫。',
          '级长站在楼梯口，扯着嗓子喊「回休息室，不要停」。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'help_fallen',
            text: '停下来把摔倒的人扶起来',
            consequence:
                '你蹲下去捡书，那人一边道谢一边发抖。你们一起挤出人群的时候，',
            nextStepId: 'ps_ch6_after',
            effect: StoryEffect(setFlags: ['ps_helped_firstyear'], reputation: 2, spirit: 3, targetNpcId: 'neville', affection: 2),
          ),
          StoryChoiceDef(
            id: 'stay_line',
            text: '跟着队伍，不要掉队',
            consequence:
                '你紧紧跟着前面的人，一步也不敢停。回到休息室的时候，你的手还在抖，但至少你把自己完整地带回来了。',
            nextStepId: 'ps_ch6_after',
            effect: StoryEffect(setFlags: ['ps_stayed_with_group'], spirit: 1),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch6_after',
        canonRefId: 'canon_ps_first_snow',
        chapterId: 'ps_ch6',
        timeCostDays: 16,
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
            nextStepId: 'ps_ch6_rumor',
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
            nextStepId: 'ps_ch6_rumor',
            effect: StoryEffect(
              setFlags: ['ps_back_on_track'],
              housePoints: 2,
              reputation: 2,
              spirit: 1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch6_rumor',
        canonRefId: 'canon_ps_library_rules',
        chapterId: 'ps_ch6',
        timeCostDays: 1,
        setup:
            '巨怪事件过去几天，走廊里的议论还没停。有人说巨怪是被几个一年级生撞见的，有人说地窖里其实还有别的东西。',
        ambient: [
          '公共休息室的告示板上多了一张新的通知。',
          '壁炉边围着几个人，声音压得很低。',
          '窗外的第一场霜落在草坪上，白了一片。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'listen_in',
            text: '凑过去，把他们的说法都听一遍',
            consequence:
                '你听到至少三个版本，细节互相打架。唯一一致的是：那天晚上有人做对了事。你没插话，但记住了这件事可以被这样讲。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['ps_heard_troll_versions'], spirit: 2),
          ),
          StoryChoiceDef(
            id: 'ignore_rumor',
            text: '不去听，专心把落下的作业补上',
            consequence:
                '你把课本摊在膝头，炉火烤得人昏昏欲睡。作业补完了，传闻也自己慢慢淡了。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['ps_focused_on_work'], housePoints: 5, spirit: 2),
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
        timeCostDays: 12,
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
        timeCostDays: 29,
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
            nextStepId: 'ps_ch7_gifts',
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
            nextStepId: 'ps_ch7_gifts',
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
            nextStepId: 'ps_ch7_gifts',
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
        id: 'ps_ch7_gifts',
        chapterId: 'ps_ch7',
        timeCostDays: 2,
        setup:
            '圣诞那天早上，公共休息室的壁炉前堆着一小摞用牛皮纸包着的盒子，'
            '上面写着你的名字。多数是家里寄来的：手织的围巾、一罐太甜的糖、'
            '一张字迹潦草的便条。也有一个盒子没有署名。'
            '窗外雪还在下，整座城堡安静得像被整个抬离了地面。',
        ambient: [
          '壁炉里的柴火偶尔爆一下，火星贴着地砖滚出去一小段。',
          '楼下传来几个人打雪仗的笑声，隔着一层楼听着很远。',
          '你把围巾围上试了试，长度比预想的多了半尺。',
        ],
        canonRefId: 'canon_ps_christmas_gifts',
        onEnterText: '留校的假期不长，但这几天几乎没有人管你。',
        choices: [
          StoryChoiceDef(
            id: 'open_all',
            text: '把所有盒子一次拆完，再慢慢看那张便条',
            consequence:
                '你拆得很快，快到拆完才发现自己没记住哪样是从哪个盒子里出来的。'
                '那张便条你读了三遍：家里说今年冬天很冷，'
                '让你记得多穿一件。你把它折好放进了口袋。',
            effect: StoryEffect(
              addItems: ['手织围巾'],
              setFlags: ['ps_christmas_stayed'],
              spirit: 6,
            ),
            nextStepId: 'ps_ch7_term_end',
          ),
          StoryChoiceDef(
            id: 'write_back',
            text: '先坐下来写一封回信，再拆礼物',
            consequence:
                '你写了两页，写到一半发现自己不知道该说什么，'
                '于是把最要紧的几句留在最后。信寄出去要等好几天才有回音，'
                '但你把信封投进礼堂外的邮筒时，觉得这几天没白过。',
            effect: StoryEffect(
              addKnowledge: ['ps_family_correspondence'],
              setFlags: ['ps_wrote_home'],
              spirit: 4,
            ),
            nextStepId: 'ps_ch7_term_end',
          ),
          StoryChoiceDef(
            id: 'explore_castle',
            text: '把礼物堆在床边，趁假期去城堡里转转',
            consequence:
                '假期的城堡和平时完全不是同一个地方：楼梯不挤，'
                '画像都在打盹，你走到了几处平时没机会停下来的角落。'
                '在一段没人的走廊尽头，你听见某个房间里传来很轻的说话声——'
                '你站了一会儿，没有推门。',
            effect: StoryEffect(
              addKnowledge: ['ps_castle_quiet_corners'],
              setFlags: ['ps_explored_holiday_castle'],
              spirit: 3,
            ),
            nextStepId: 'ps_ch7_term_end',
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch7_term_end',
        canonRefId: 'canon_ps_winter_study',
        chapterId: 'ps_ch7',
        timeCostDays: 29,
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
            nextStepId: 'ps_ch7_stands',
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
            nextStepId: 'ps_ch7_stands',
            effect: StoryEffect(
              setFlags: ['ps_solo_grind'],
              housePoints: 2,
              reputation: 1,
              spirit: 1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch7_stands',
        chapterId: 'ps_ch7',
        timeCostDays: 1,
        setup:
            '第一场魁地奇比赛，你挤在看台的人群里。风很大，围巾被吹得贴在脸上，但没有人愿意先去避风的地方。',
        ambient: [
          '解说员的声音被风吹得断断续续。',
          '看台另一头传来整齐的鼓点和口号。',
          '你旁边的人一直在踮脚，挡住了你半边视线。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'cheer_loud',
            text: '跟着大家一起喊，把嗓子喊哑',
            consequence:
                '你不记得自己喊了多久，只知道散场的时候说话都变了调。但这大概是入学以来最痛快的一场下午。',
            nextStepId: 'ps_ch7_snow',
            effect: StoryEffect(setFlags: ['ps_cheered_quidditch'], spirit: 6),
          ),
          StoryChoiceDef(
            id: 'watch_players',
            text: '只顾盯着场上的人看，不出声',
            consequence:
                '你看清了每一个人的位置、每一次传球。散场以后你还在想那些动作——有些东西你大概永远做不到，但看得懂也很好。',
            nextStepId: 'ps_ch7_snow',
            effect: StoryEffect(addKnowledge: ['knows_quidditch_play'], setFlags: ['ps_studied_quidditch'], spirit: 4),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch7_snow',
        chapterId: 'ps_ch7',
        timeCostDays: 1,
        setup:
            '圣诞假期留校的人不多。第一场大雪落下来的时候，你和几个同样没回家的同学在院子里堆了个雪人，用两颗煤球当眼睛。',
        ambient: [
          '雪还在下，落在雪人的肩膀上又加了一层。',
          '远处厨房的窗户透出暖黄色的光。',
          '有人从门厅出来喊「开饭了」，声音在雪地里传得很远。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'stay_outside',
            text: '在雪里多待一会儿，直到手指冻僵',
            consequence:
                '你把雪人补得很结实，还给它围了根树枝当手臂。回屋的时候你的手套全湿了，但你觉得这个假期不算白过。',
            nextStepId: 'ps_ch7_gift',
            effect: StoryEffect(setFlags: ['ps_built_snowman'], spirit: 5),
          ),
          StoryChoiceDef(
            id: 'go_warm',
            text: '先进屋，在炉火边看书',
            consequence:
                '你挑了本厚书坐到壁炉前，偶尔抬头看看窗外那个越堆越高的雪人。安静得能听见木柴噼啪的响声。',
            nextStepId: 'ps_ch7_gift',
            effect: StoryEffect(setFlags: ['ps_read_by_fire'], spirit: 4),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch7_gift',
        chapterId: 'ps_ch7',
        timeCostDays: 1,
        setup:
            '圣诞节的早晨，公共休息室的树下堆着包裹。你找到了写着自己名字的那几件——其中一件包得歪歪扭扭，一看就是家里人包的。',
        ambient: [
          '有人拆到一件手织的毛衣，举起来给大家看。',
          '炉火把包装纸烤得卷了边。',
          '窗外雪停了，光秃秃的树枝上挂着冰。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'open_all',
            text: '把每一件都拆开，慢慢看',
            consequence:
                '有一件是养母寄来的，还有一张短短的字条。你把字条读了两遍，然后夹进那本最常用的课本里——后来你再翻到那一页时，总会停一下。',
            nextStepId: 'ps_ch7_exams',
            effect: StoryEffect(setFlags: ['ps_opened_gifts'], spirit: 8),
          ),
          StoryChoiceDef(
            id: 'thank_first',
            text: '先写信道谢，再拆包裹',
            consequence:
                '你铺开羊皮纸，写了两页。写到一半的时候你发现，自己居然有很多事可以说。信寄出去以后你才去拆包裹，拆得比往年都慢。',
            nextStepId: 'ps_ch7_exams',
            effect: StoryEffect(setFlags: ['ps_wrote_thanks'], reputation: 2, spirit: 6),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch7_exams',
        chapterId: 'ps_ch7',
        timeCostDays: 1,
        setup:
            '期末考前的图书馆坐满了人。你找到的位子旁边坐着一个正在小声背咒语的女生，她的笔记记得比课本还密。',
        ambient: [
          '闭馆铃响的时候，整层楼发出一片叹气声。',
          '有人把羽毛笔咬得都是牙印。',
          '窗外天早就黑了，玻璃上结了薄薄一层霜。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'study_with',
            text: '跟她交换笔记，互相抽查',
            consequence:
                '你们互相问了半个小时，她记住了你抄的那几条，你也记住了她的。第二天考试的时候，有几道题你一看就笑了。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['ps_studied_together'], spirit: 4, targetNpcId: 'hermione', affection: 3),
          ),
          StoryChoiceDef(
            id: 'study_alone',
            text: '自己按自己的节奏复习，不打扰别人',
            consequence:
                '你把课本从头过了一遍，把不确定的地方折了角。考试那天，折角的那几页果然都用上了。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['ps_studied_alone'], housePoints: 5, spirit: 3),
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
        canonRefId: 'canon_ps_valentine',
        chapterId: 'ps_ch8',
        timeCostDays: 25,
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
            nextStepId: 'ps_ch8_notice',
            requireAnyFlags: ['ps_festive_helper', 'ps_helped_decorate', 'ps_study_group', 'ps_studied_together'],
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
            nextStepId: 'ps_ch8_notice',
            effect: StoryEffect(
              setFlags: ['ps_obeyed_forest_ban'],
              housePoints: 1,
              spirit: 1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch8_notice',
        chapterId: 'ps_ch8',
        timeCostDays: 1,
        setup:
            '公告栏上贴出了新的通知：近期任何人不得独自靠近禁林，违者按校规处理。落款是校长办公室。',
        ambient: [
          '有几个高年级生围着通知小声讨论。',
          '走廊里的画像们也在交头接耳，有一位老校长甚至在画框里走来走去。',
          '窗外的森林边沿，树影比平时显得更密。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'read_carefully',
            text: '把通知逐字读完，包括最下面那行小字',
            consequence:
                '最下面写着「如有发现，请立即报告教工」。你把这句话记住了——它和平时那些「注意安全」的通知不太一样，这次是真的在提醒什么。',
            nextStepId: 'ps_ch8_link',
            requireAnyFlags: ['ps_curious_mind', 'ps_library_regular', 'ps_copied_notes', 'ps_studied_ahead'],
            effect: StoryEffect(addKnowledge: ['knows_forest_warning'], setFlags: ['ps_read_notice'], spirit: 1),
          ),
          StoryChoiceDef(
            id: 'ask_prefect',
            text: '去问级长到底发生了什么',
            consequence:
                '级长看了你一眼，说「不该问的别问」。但他走开之前又补了一句：「晚上别乱跑。」你能听出他也在紧张。',
            nextStepId: 'ps_ch8_link',
            effect: StoryEffect(addKnowledge: ['knows_prefects_worried'], setFlags: ['ps_asked_prefect'], spirit: -1),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch8_link',
        chapterId: 'ps_ch8',
        timeCostDays: 15,
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
            nextStepId: 'ps_ch8_watch',
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
            nextStepId: 'ps_ch8_watch',
            requireAnyFlags: ['ps_study_group', 'ps_studied_together', 'ps_library_regular', 'ps_curious_mind'],
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
            nextStepId: 'ps_ch8_watch',
            effect: StoryEffect(
              setFlags: ['ps_stayed_focused'],
              housePoints: 2,
              spirit: 1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch8_watch',
        chapterId: 'ps_ch8',
        timeCostDays: 1,
        setup:
            '有个下午你路过城堡的侧门，看见海格正牵着那条大猎犬往林子方向走。他背着一只鼓鼓的布袋，脚步比平时快。',
        ambient: [
          '猎犬的耳朵一直竖着，鼻子贴在地上嗅。',
          '侧门的台阶上还留着几个很大的泥脚印。',
          '风从林子的方向吹过来，带着一股说不清的味道。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'offer_help',
            text: '上前问要不要帮忙',
            consequence:
                '海格摆摆手说「不用，你回去」。但他顿了一下，又说「谢谢你想着」——这句话他说得比想象中轻。',
            nextStepId: 'ps_ch8_night',
            requireAnyFlags: ['ps_asked_why_me', 'ps_offered_kindness', 'ps_study_group', 'ps_helped_classmate'],
            effect: StoryEffect(setFlags: ['ps_offered_hagrid_help'], spirit: 2, targetNpcId: 'hagrid', affection: 3),
          ),
          StoryChoiceDef(
            id: 'stay_back',
            text: '站在门口看着他们走远',
            consequence:
                '你一直看到那一人一狗的背影被树影吞掉。你忽然很想知道林子里到底有什么，但你也知道，今天不是问的时候。',
            nextStepId: 'ps_ch8_night',
            effect: StoryEffect(setFlags: ['ps_watched_hagrid_go'], spirit: 1),
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
        timeCostDays: 16,
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
            nextStepId: 'ps_ch8_return',
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
            nextStepId: 'ps_ch8_return',
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
            nextStepId: 'ps_ch8_return',
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
        id: 'ps_ch8_return',
        canonRefId: 'canon_ps_quidditch_final',
        chapterId: 'ps_ch8',
        timeCostDays: 1,
        setup:
            '很晚的时候，侧门那边有动静。你和另外两个同样没睡着的同学趴在窗边，看见海格回来了，步子比去的时候慢了很多。',
        ambient: [
          '猎犬走在他旁边，尾巴垂着。',
          '有人小声说「他的脸色不太对」。',
          '门厅的灯亮了又灭，走廊重新安静下来。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'wait_news',
            text: '在窗边等到走廊彻底没声',
            consequence:
                '你们三个人一直等到打更的时间。什么也没等到，但你们都知道今天晚上发生了点什么。',
            nextStepId: 'ps_ch8_after',
            effect: StoryEffect(setFlags: ['ps_waited_for_news'], spirit: -1),
          ),
          StoryChoiceDef(
            id: 'go_sleep',
            text: '不看了，回去睡觉',
            consequence:
                '你爬上床，把被子拉到下巴。窗外偶尔有树枝摩擦的响声，你听着听着就睡着了。',
            nextStepId: 'ps_ch8_after',
            effect: StoryEffect(setFlags: ['ps_slept_through'], spirit: 2),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch8_after',
        chapterId: 'ps_ch8',
        timeCostDays: 45,
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
            nextStepId: 'ps_ch8_morning',
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
            nextStepId: 'ps_ch8_morning',
            effect: StoryEffect(
              setFlags: ['ps_vow_stronger'],
              reputation: 1,
              spirit: 4,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch8_morning',
        canonRefId: 'canon_ps_exams',
        chapterId: 'ps_ch8',
        timeCostDays: 1,
        setup:
            '第二天早上，林子边多了一道用魔杖划出来的警戒线。有几个教工站在那里，不让任何人靠近。',
        ambient: [
          '雪化了以后，地上的脚印看得更清楚。',
          '有个低年级生想凑近看，被教工拦了回去。',
          '上课铃响了，大家才慢慢散开。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'keep_watch',
            text: '连着几天都绕路过来看一眼',
            consequence:
                '你说不清自己在看什么。警戒线一直没有撤，教工换了几批。这件事慢慢变成了你这一年的一个记号。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['knows_forest_guarded'], setFlags: ['ps_kept_forest_watch'], spirit: 2),
          ),
          StoryChoiceDef(
            id: 'move_on',
            text: '看过一次就够了，回去上课',
            consequence:
                '你在警戒线外站了一分钟，然后就走了。课照常上，作业照常交，但你偶尔还会想起那天晚上的灯。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['ps_moved_on'], housePoints: 5, spirit: 2),
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
        timeCostDays: 29,
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
            nextStepId: 'ps_ch9_whispering',
            requireAnyFlags: ['ps_helped_firstyear', 'ps_troll_stood_together', 'ps_helped_classmate', 'ps_curious_mind'],
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
            nextStepId: 'ps_ch9_whispering',
            effect: StoryEffect(
              setFlags: ['ps_packed_early'],
              housePoints: 1,
              spirit: 3,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch9_whispering',
        chapterId: 'ps_ch9',
        timeCostDays: 1,
        setup:
            '学年末的走廊里，到处都是压低了声音的交谈。有人说城堡里藏了东西，有人说几位教授最近都不见人影。',
        ambient: [
          '图书馆的书架这几天空了一半，借出去的书没还。',
          '有几个高年级生凑在角落里画着什么图。',
          '连画像们都比平时安静。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'piece_together',
            text: '把听到的碎片一条条记下来',
            consequence:
                '你记了满满一页：谁在哪天说过什么、哪扇门平时锁着现在开着。写完之后你发现，这些碎片拼不出完整的图——但至少你不再是什么都不知道的人。',
            nextStepId: 'ps_ch9_feast',
            requireAnyFlags: ['ps_detective_mind', 'ps_shared_doubt', 'ps_kept_forest_watch', 'ps_understood_price'],
            effect: StoryEffect(addKnowledge: ['knows_term_secrets'], setFlags: ['ps_collected_clues'], spirit: 2),
          ),
          StoryChoiceDef(
            id: 'stay_out',
            text: '不听不问，把最后几周用在考试上',
            consequence:
                '你把心思全放在课本上。等考试结束你才发现，那几周城堡里发生的事，你几乎一无所知。',
            nextStepId: 'ps_ch9_feast',
            effect: StoryEffect(setFlags: ['ps_stayed_out_of_it'], housePoints: 5, spirit: 1),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch9_feast',
        chapterId: 'ps_ch9',
        // 原著节点：一年级期末与学院杯（1992 年 6 月）
        canonRefId: 'canon_ps_year_end',
        timeCostDays: 15,
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
            nextStepId: 'ps_ch9_table',
            requireAnyFlags: ['ps_cheered_quidditch', 'ps_studied_quidditch', 'ps_study_group', 'ps_studied_together'],
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
            nextStepId: 'ps_ch9_table',
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
        id: 'ps_ch9_table',
        chapterId: 'ps_ch9',
        timeCostDays: 1,
        setup:
            '年终宴会那天，四个学院的长桌上方挂着各自颜色的旗帜。你坐在同院的人中间，桌上的金色盘子闪着光。',
        ambient: [
          '有人在讨论等会儿会不会有额外的加分。',
          '天花板上的星星比平时更亮一些。',
          '隔壁桌传来压抑的笑声，很快又被掌声盖过去。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'cheer_house',
            text: '为本院的每一分都用力鼓掌',
            consequence:
                '你把手都拍红了。不管最后名次怎样，这一年的每一次加分都有人在下面记得——包括你自己在魔药课上挣来的那五分。',
            nextStepId: 'ps_ch9_farewell',
            requireAnyFlags: ['ps_cheered_quidditch', 'ps_built_snowman', 'ps_wrote_home', 'ps_wrote_thanks', 'ps_festive_helper'],
            effect: StoryEffect(setFlags: ['ps_cheered_house'], spirit: 6),
          ),
          StoryChoiceDef(
            id: 'reflect_year',
            text: '安静坐着，把这一年一件一件想一遍',
            consequence:
                '从那只落在窗台上的猫头鹰开始，你把它一路想到今天的宴会。有些事你做得不错，有些事如果再给你一次，你会做得不一样。',
            nextStepId: 'ps_ch9_farewell',
            effect: StoryEffect(setFlags: ['ps_reflected_year'], spirit: 5),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ps_ch9_farewell',
        chapterId: 'ps_ch9',
        timeCostDays: 14,
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
  startYear: 1991,
  startMonth: 7,
  // 【为什么是 7 月 18 日】第一章「女贞路的信」共 5 天（收信 1 + 告知 1 +
  // 预习 3 + 家访 2 + 回信 1 + 前夜 1 = 9 天，其中收信当天不计），
  // 把它整段落在七月需要开局日 ≤ 7-25；留一天缓冲取 7-18，于是
  // `ps_ch2_arrival` 恰好停在 7 月 31 日——与沙盒「letter 开局」
  // （`opening_scene_data.dart` 的 1991-07-31）同日。
  //
  // 【为什么这条必须守住】`canon_ps_gringotts` 声明在 `ps_ch2_bank` 上，
  // 按时间步长重放后必须落回 1991-07（`canon_story_parallel_test.dart`
  // 的「原著节点落在它真正发生的那个月」）。开局日往后挪一天，
  // 整条时间线（含排序、魁地奇、禁林、年终宴）全部错位。
  startDay: 18,
);

// ================================================================
// 《密室》 1992-1993 · 二年级
//
// 【时间线】1992-07-25 开启锚点（第二学年的信）→ 1993-06 学年结束宴。
// 36 步 × 平均 9 天 ≈ 330 天，与 canon_cos_* 节点的月份逐一对齐。
//
// 【与哈利线的边界】多比的警告、会飞的汽车、日记里的男孩都是哈利线，
// 玩家只能从报纸、传闻与走廊里的骚动里听到它们。密室决战之夜玩家的
// 位置是「被院长的魔杖灯叫醒、在公共休息室里等消息」——在场的是恐惧，
// 不是主角光环。
// ================================================================

const List<StoryChapterDef> _cosChapters = [
  // --------------------------------------------------------------
  // 第一章 · 第二年的信（1992 年 7 月下旬）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'cos_ch1',
    bookId: 'cos',
    ordinal: 1,
    title: '第二年的信',
    steps: [
      StoryStepDef(
        id: 'cos_ch1_letter',
        chapterId: 'cos_ch1',
        timeCostDays: 10,
        onEnterText:
            '—— 第 2 部 · 密室 ——\n'
            '一年过去了。你如今是一名二年级学生，'
            '而这封第二年的信，落款日期比去年早了整整一周。',
        setup:
            '七月的蝉声里，第二封霍格沃茨的信到了。信封比去年厚——里面多了一张'
            '二年级书单，书单正中印着一整套烫金封皮的新书：《与女鬼决裂》《与吸血鬼同船》。'
            '楼下店里去年路过时你见过这堆书，码得像一座小山。',
        ambient: [
          '蝉声一阵接一阵，信纸上的烫金书名在日光里反着光。',
          '你把去年的旧课本翻出来对比，发现书单上一本都对不上。',
          '猫头鹰站在窗台上喝水，一副送完就走的冷淡样子。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'study_list',
            text: '把书单读三遍，提前给二年级的课做规划',
            consequence:
                '你把书单摊在桌上逐行读完，又在自家日历上圈出采买日。'
                '施魔法课、变形课的教材没换，多出来的全是黑魔法防御术的新书——'
                '同一个作者写了整整七本。你把这些书名抄在扉页上，打了个问号。',
            effect: StoryEffect(
              addKnowledge: ['cos_second_year_plan'],
              setFlags: ['cos_read_list_carefully'],
              spirit: 2,
            ),
            nextStepId: 'cos_ch1_owl',),
          StoryChoiceDef(
            id: 'enjoy_summer',
            text: '先把信压在枕头下，夏天的最后两周要紧',
            consequence:
                '你把信塞进抽屉，跑去和夏天的伙伴把最后两周玩了个够。'
                '采买的事，开学前再去对角巷一趟也不迟——去年就是这么干的。',
            effect: StoryEffect(
              spirit: 5,
              setFlags: ['cos_squeezed_summer'],
            ),
            nextStepId: 'cos_ch1_owl',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch1_owl',
        chapterId: 'cos_ch1',
        timeCostDays: 1,
        setup:
            '第二年的信又是在早饭时到的。这次你已经认得那只猫头鹰——它落在窗台上，很熟练地把爪子伸向你的盘子。',
        ambient: [
          '养母已经不看报纸了，只是把牛奶往你这边推了推。',
          '窗外的树比去年又高了一截。',
          '猫头鹰等你取信的时候，尾巴轻轻拍着窗台。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'read_now',
            text: '当场把信拆开，把书单念出来',
            consequence:
                '书单比去年厚，多了几本你没见过的。念到一半养母插了句「又是一堆书」。她的语气比去年平静多了。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_read_letter_early'], spirit: 5),
          ),
          StoryChoiceDef(
            id: 'read_after',
            text: '把信收进口袋，等吃完再看',
            consequence:
                '你一直忍到收拾完碗筷。拆信的时候手还是有点抖——这件事大概永远也不会变得完全平常。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_saved_letter'], spirit: 3),
          ),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch1_diagon',
        chapterId: 'cos_ch1',
        timeCostDays: 16,
        setup:
            '对角巷和去年一样热闹，又比去年拥挤：丽痕书店门口排起长龙，'
            '横幅上写着「吉德罗·洛哈特，今日亲临签售」。队伍绕了三个街角，'
            '队伍里全是抱着一整摞同一位作者新书的家长和学生。'
            '你的书单上那七本，恰好都在其中。',
        ambient: [
          '书店橱窗里贴满了同一个人的微笑照片，照片里的他冲每个人眨眼。',
          '队伍里有人在争论他的哪本书最好看，声音一浪高过一浪。',
          '一家店门口的天鹅绒帽子会自己调整角度，惹得几个小孩笑个不停。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'join_queue',
            text: '乖乖排队，把七本书一次买齐',
            consequence:
                '你排了将近一个小时的队，买到七本崭新烫金的书。'
                '签售桌后的作者本人比照片更高、牙更白，他抓着你的手连签了七个名，'
                '快得你几乎看不清。书很沉，队很长，你把「签名照」这张纸塞进了书页里。',
            effect: StoryEffect(
              addItems: ['旧书'],
              addKnowledge: ['cos_has_lockhart_books'],
              setFlags: ['cos_diagon_lockhart_queue'],
              galleons: -6,
              spirit: 1,
            ),
            nextStepId: 'cos_ch1_purchase',),
          StoryChoiceDef(
            id: 'buy_used',
            text: '转身去二手书摊，把七本都凑成便宜的旧版',
            consequence:
                '你在巷子深处的旧书摊上把七本书凑齐，价钱不到原价三成。'
                '摊主说你赚了：「这些书看完就是垫坩埚的厚度。」'
                '你注意到每一本的内页都干干净净——看过的人确实不多。',
            effect: StoryEffect(
              addItems: ['旧书'],
              addKnowledge: ['cos_has_lockhart_books', 'cos_books_look_thin'],
              setFlags: ['cos_bought_used_books'],
              galleons: -2,
              spirit: 2,
            ),
            nextStepId: 'cos_ch1_purchase',),
          StoryChoiceDef(
            id: 'watch_from_far',
            text: '不凑热闹，去别家把别的用品买齐',
            consequence:
                '你绕开签售的长队，把羊皮纸、羽毛笔和一瓶提神剂买齐。'
                '路过书店时瞥见那位作者正被簇拥着摆姿势，笑容没有变过。'
                '你觉得这学期黑魔法防御术课大概会很热闹。',
            effect: StoryEffect(
              addItems: ['新羽毛笔'],
              addKnowledge: ['cos_skipped_queue'],
              setFlags: ['cos_doubted_lockhart'],
              galleons: -3,
              spirit: 3,
            ),
            nextStepId: 'cos_ch1_purchase',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch1_purchase',
        chapterId: 'cos_ch1',
        timeCostDays: 1,
        setup:
            '第二年的采购清单短了些，但你还是在对角巷花了一整个上午。经过古灵阁的时候，你忍不住看了一眼那些大理石台阶。',
        ambient: [
          '台阶上的警卫比去年多了两个。',
          '有人在药店门口排队，队伍一直排到街上。',
          '阳光很好，把鹅卵石晒得发亮。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'visit_bank',
            text: '进去换些零钱，顺便看看大厅',
            consequence:
                '大厅还是那么高，妖精们还是坐在那么高的柜台后面。你换完钱往外走的时候，忽然想起去年在报纸上读到的那些字。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_visited_bank'], spirit: 2, galleons: 10),
          ),
          StoryChoiceDef(
            id: 'skip_bank',
            text: '直接去书店，钱的事以后再说',
            consequence:
                '你在书店待了很久，最后抱着书出来。没有多花一分钱，但也没多知道任何事。',
            nextStepId: '',
            effect: StoryEffect(addItems: ['标准咒语书'], setFlags: ['cos_skipped_bank'], spirit: 2),
          ),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch1_summer_night',
        chapterId: 'cos_ch1',
        timeCostDays: 6,
        setup:
            '返校前的最后一晚，你把两个世界的行李分开装：'
            '麻瓜世界的夏天装进一个箱子，魔法世界的一年装进另一个。'
            '窗外的知了还在叫，你的猫头鹰却已经站在门边等了——'
            '它比你自己还清楚，你属于哪边。',
        ambient: [
          '两个箱子一高一矮，像你人生的两半。',
          '那只猫头鹰在门边整理羽毛，一副「准备好了」的职业表情。',
          '你把去年的学院杯纪念徽章别在行李箱内侧，算是给新学年打个样。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'early_sleep',
            text: '早睡——明天要赶最早的列车',
            consequence:
                '你熄了灯，把闹钟拨到五点半。黑暗里你复盘了一遍上一年：'
                '交到的朋友、踩过的坑、还有那些没敢做的事。'
                '你想好了一件事，作为二年级的起点：'
                '这一年，要主动一点。',
            effect: StoryEffect(
              setFlags: ['cos_resolve_proactive'],
              spirit: 3,
            ),
            nextStepId: 'cos_ch1_lastweek',),
          StoryChoiceDef(
            id: 'write_friends',
            text: '熬夜给同窗写信，约好站台上见',
            consequence:
                '你写了四张短笺，塞给四只猫头鹰分头送出。'
                '回信在半夜接连到达，七扭八歪地挤在窗台：'
                '「站台第三个车门」「提前占座」「带上你说的那种糖」。'
                '你笑着睡去——有人等你回去，这感觉比什么都强。',
            effect: StoryEffect(
              addItems: ['手写贺卡'],
              setFlags: ['cos_station_promise'],
              affection: 2,
              spirit: 4,
            ),
            nextStepId: 'cos_ch1_lastweek',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch1_lastweek',
        chapterId: 'cos_ch1',
        timeCostDays: 1,
        setup:
            '开学前的最后一周，你把去年的课本都翻了出来。有几页的笔记你还认得，有几页已经完全陌生。',
        ambient: [
          '书页间掉出一张去年夹进去的纸条。',
          '窗外的蝉声比去年短了，已经开始有秋天的意思。',
          '你把长袍从柜子里拿出来，发现袖口短了一截。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'review_all',
            text: '把去年的课本全部过一遍',
            consequence:
                '你花了三天时间。有些咒语的发音还记得，有些已经忘了。你在忘掉的地方做了记号，打算开学以后重新问一遍。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['cos_knows_gaps'], setFlags: ['cos_reviewed_books'], spirit: 4),
          ),
          StoryChoiceDef(
            id: 'pack_light',
            text: '不复习了，收拾行李要紧',
            consequence:
                '你把东西一件件塞进箱子，最后发现装不下，只好又拿出来几件。这种事你去年也遇到过。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_packed_light'], spirit: 3),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第二章 · 开学宴（1992 年 9 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'cos_ch2',
    bookId: 'cos',
    ordinal: 2,
    title: '开学宴',
    steps: [
      StoryStepDef(
        id: 'cos_ch2_feast',
        chapterId: 'cos_ch2',
        timeCostDays: 12,
        canonRefId: 'canon_cos_lockhart',
        setup:
            '九一之夜，四张长桌重新坐满。今年的一年级比去年更瘦小、更紧张。'
            '麦格教授刚放下分院凳，黑魔法防御术课的座位方向就站起一个金发男人——'
            '他的袍子是青绿色的，胸前别着一枚会转的徽章。他清了清嗓子，'
            '整个礼堂安静了下来。',
        ambient: [
          '长桌上的南瓜汁冒着热气，气氛却比去年开学宴喧闹得多。',
          '你旁边的二年级同学小声说：「就是写那七本书的人。」',
          '天花板上的烛台飘得比往年高一点，光影在四张长桌间晃。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'listen_closely',
            text: '认真听这位新教授的自我介绍',
            consequence:
                '他介绍自己「三度荣获《巫师周刊》最迷人微笑奖」，'
                '然后话锋一转，宣布要在课上演示他书里的历险。'
                '你数了数，五分钟的发言里他提到了自己的名字十一次。'
                '你记下这个数字，决定课堂上再验证一次。',
            effect: StoryEffect(
              addKnowledge: ['cos_knows_lockhart_style'],
              setFlags: ['cos_counted_his_names'],
              spirit: 1,
            ),
            nextStepId: 'cos_ch2_seat',),
          StoryChoiceDef(
            id: 'compare_notes',
            text: '和同学小声比对新教授的传闻',
            consequence:
                '同桌告诉你，他哥哥说洛哈特的书「细节多到不真实」。'
                '另一个同学说管他呢，学分就行。你们交换完情报，'
                '礼堂上空的烛光正好暗了一档——新教授的演讲还在继续。',
            effect: StoryEffect(
              addKnowledge: ['cos_rumor_lockhart_exaggerates'],
              setFlags: ['cos_openfeast_lockhart_fan', 'cos_doubted_lockhart'],
              spirit: 2,
            ),
            nextStepId: 'cos_ch2_seat',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch2_seat',
        chapterId: 'cos_ch2',
        timeCostDays: 1,
        setup:
            '开学宴上，你找了个靠边的位置坐下。大礼堂的布置和去年一样，但坐在你周围的人好像都长高了一点。',
        ambient: [
          '新生队伍比去年短，有几个特别矮的走在最后。',
          '长桌上的南瓜还在飘，只是没有万圣节那么多。',
          '有人在小声认今年新来的老师是谁。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'greet_new',
            text: '主动跟旁边的新生搭话',
            consequence:
                '你问他叫什么、从哪里来。他答得很小声，手一直攥着桌布。你想起来自己去年也是这样，于是又跟他说了几句，直到他笑了一下。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_greeted_new'], reputation: 1, spirit: 4, targetNpcId: 'ginny', affection: 2),
          ),
          StoryChoiceDef(
            id: 'sit_quiet',
            text: '安静吃饭，观察这一年的变化',
            consequence:
                '你注意到教师的位子上多了一个人，还注意到有几个老同学没有回来。这些变化你默默记下了。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_observed_changes'], spirit: 2),
          ),
          StoryChoiceDef(
            id: 'greet_by_name',
            text: '叫出那个新生的名字，问他哥哥是不是也在学校',
            consequence:
                '你报出名字之后，他整个人明显松了一下——原来被人认出来'
                '是这么管用的事。他小声说了哥哥的名字，说他收到了信，'
                '但家里还有点不放心。你说了两句宽心的话，他就笑了。',
            requireFlag: 'cos_counted_his_names',
            effect: StoryEffect(
              setFlags: ['cos_greeted_new', 'cos_called_by_name'],
              addKnowledge: ['knows_weasley_family'],
              reputation: 2,
              spirit: 4,
              targetNpcId: 'ginny',
              affection: 3,
            ),
          ),

        ],
      ),
      StoryStepDef(
        id: 'cos_ch2_first_week',
        chapterId: 'cos_ch2',
        timeCostDays: 3,
        setup:
            '开学第一周，走廊里贴满了新教授的移动海报。黑魔法防御术课的教室门口'
            '排起了合影的队——上课的人反而排不进去。隔壁的草药课倒是完全照旧：'
            '温室里新到的一批盆栽被布盖着，据说「二年级下半学期才能揭开」。',
        ambient: [
          '海报里那位教授的签名照一遍遍重放微笑，贴得连楼梯口都有。',
          '温室里盖着布的盆栽偶尔动一动，像什么东西在里面拱。',
          '开学第一周的作业量意外地轻，轻得让人心里没底。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'ask_sprout',
            text: '向斯普劳特教授打听温室里盖着布的盆栽',
            consequence:
                '斯普劳特教授神秘地压低声音：「曼德拉草，二年级的宝贝，'
                '也是这学年的希望——等它们成年，医疗翼要用。」'
                '她没有多解释，但你把「曼德拉草」和「希望」这两个词记在了一起。',
            effect: StoryEffect(
              addKnowledge: ['cos_mandrake_hope'],
              setFlags: ['cos_asked_sprout'],
              spirit: 2,
            ),
            nextStepId: 'cos_ch2_schedule',),
          StoryChoiceDef(
            id: 'avoid_crowd',
            text: '躲开合影的队，把第一周的课表理顺',
            consequence:
                '你把一整周的课表抄成两份，一份贴在床头，一份折进口袋。'
                '第一周结束时，你比一半同学更早知道哪节课要带什么、'
                '哪段楼梯逢周三会换方向。这种确定感让你踏实。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包'],
              setFlags: ['cos_organized_week'],
              spirit: 3,
            ),
            nextStepId: 'cos_ch2_schedule',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch2_schedule',
        chapterId: 'cos_ch2',
        timeCostDays: 1,
        setup:
            '新学期的课表发下来了，一张羊皮纸钉在公告栏上。你对着那张纸研究了半天，发现有几节课的时间竟然是重叠的，而课本上并没写遇到这种情况该怎么办。',
        ambient: [
          '公告栏前挤满了人，都在核对时间。',
          '有人抱怨说今年的课排得太满。',
          '走廊的钟敲了一下，人群开始往教室方向移动。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'ask_teacher',
            text: '拿着课表去问教授怎么安排',
            consequence:
                '教授看了一眼说「你自己选」。这大概就是二年级的意思——没人再手把手告诉你要做什么了。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['cos_knows_self_choice'], setFlags: ['cos_asked_teacher'], spirit: 2),
          ),
          StoryChoiceDef(
            id: 'ask_senior',
            text: '去问高年级的学长哪个更值得上',
            consequence:
                '学长说了半小时，最后总结成一句「选你喜欢的」。你谢过他，回到宿舍又把课表看了一遍。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_asked_senior'], spirit: 3),
          ),
          StoryChoiceDef(
            id: 'mark_overlap',
            text: '照着课表把时间重叠的那几节圈出来，自己排一份',
            consequence:
                '你把羊皮纸折成两栏，把重叠的课标成三角，又在背面写'
                '哪些课要带坩埚、哪些课要带护目镜。这张纸后来被同桌'
                '借去抄了三遍——有人照着它，一整个学期都没迟到过。',
            requireFlag: 'cos_counted_his_names',
            effect: StoryEffect(
              setFlags: ['cos_made_own_plan'],
              addItems: ['羊皮纸一包'],
              reputation: 2,
              housePoints: 2,
              spirit: 3,
            ),
          ),

          StoryChoiceDef(
            id: 'check_signature',
            text: '把海报上的签名和书里的字迹对着比一比',
            consequence:
                '你从书包里翻出那本课本，就着走廊的光一个字一个字对。'
                '有几处笔锋确实像，有几处又差得很远。你合上书——'
                '这大概说明不了什么，但你记住了「他写自己的名字最认真」'
                '这件事。',
            requireFlag: 'cos_doubted_lockhart',
            effect: StoryEffect(
              setFlags: ['cos_checked_signature'],
              addKnowledge: ['cos_lockhart_suspect'],
              spirit: 2,
              reputation: 1,
            ),
          ),

        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第三章 · 墙上的传闻（1992 年 9-10 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'cos_ch3',
    bookId: 'cos',
    ordinal: 3,
    title: '墙上的传闻',
    steps: [
      StoryStepDef(
        id: 'cos_ch3_rumor',
        chapterId: 'cos_ch3',
        timeCostDays: 5,
        canonRefId: 'canon_cos_chamber_open',
        setup:
            '开学不到一个月，一个词开始在走廊里流传：密室。'
            '有人在二楼盥洗室附近的墙上看到了字——费尔奇在擦，字却总在换地方。'
            '更让人不安的是高年级学生的反应：他们讲起五十年前一桩旧事，'
            '语气比讲任何鬼故事都认真。这件事由剧情文本讲述，不再另贴旁白。',
        ambient: [
          '二楼走廊总是比别处空一点，连画像都往两边挪。',
          '有高年级学生在楼梯拐角压低声音讲古，围着的人越站越近。',
          '公告板上的失物启事贴了一层又一层，像在掩盖什么。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'ask_senior',
            text: '拉住一个靠谱的高年级生，把五十年前的旧事问清楚',
            consequence:
                '一位七年级的老学长把你拉到窗边：五十年前密室也开过一次，'
                '有个女生死在了城堡里，凶手没被找到，学校差点关门。'
                '「从那以后，每年都有人说它会被再次打开。」他说完看了眼走廊尽头，走了。',
            effect: StoryEffect(
              addKnowledge: ['cos_legacy_fifty_years', 'cos_girl_died_before'],
              setFlags: ['cos_heard_chamber', 'cos_knew_legacy'],
              spirit: -3,
            ),
            nextStepId: 'cos_ch3_whisper',),
          StoryChoiceDef(
            id: 'check_wall',
            text: '亲自去二楼走廊看那面墙',
            consequence:
                '你趁课后绕到二楼。墙上的水渍痕迹说明费尔奇确实擦过很多遍，'
                '擦不掉的深色渗进了石缝，排成歪歪扭扭的一行。你离得不够近，'
                '守在旁边的费尔奇一瞪眼，你就顺着人流退了出来。',
            effect: StoryEffect(
              addKnowledge: ['cos_saw_wall_marks'],
              setFlags: ['cos_checked_wall'],
              spirit: -2,
            ),
            nextStepId: 'cos_ch3_whisper',),
          StoryChoiceDef(
            id: 'ignore_it',
            text: '把传闻当鬼故事，专心自己的课业',
            consequence:
                '你决定不理会走廊里的窃窃私语，把夜晚投进作业和魔咒练习里。'
                '但那句「五十年前死过人」还是从别人嘴边飘进了耳朵——'
                '有些事，不理会也需要勇气。',
            effect: StoryEffect(
              setFlags: ['cos_ignored_rumor'],
              spirit: 2,
              housePoints: 2,
            ),
            nextStepId: 'cos_ch3_whisper',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch3_whisper',
        chapterId: 'cos_ch3',
        timeCostDays: 1,
        setup:
            '关于城堡里那间密室的说法越传越邪乎。有人说五十年前死过人，有人说走廊里的水渍就是证据。',
        ambient: [
          '公共休息室里有人在画地图，标出所有水管经过的地方。',
          '壁炉边的谈话声比平时小。',
          '窗外开始下雨，敲在玻璃上嗒嗒响。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'join_map',
            text: '凑过去一起看那张地图',
            consequence:
                '你们把城堡的管道系统拼了半张纸。虽然谁也不知道密室在哪，但你把这座城堡的结构记了个大概。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['cos_knows_castle_pipes'], setFlags: ['cos_joined_mapping'], spirit: 3),
          ),
          StoryChoiceDef(
            id: 'keep_out',
            text: '这种事少掺和，做自己的事',
            consequence:
                '你往炉火边挪了挪，翻开课本。别人的地图越画越大，你一个字都没看进去。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_kept_out'], spirit: 1),
          ),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch3_ghosts',
        canonRefId: 'canon_cos_quidditch_incident',
        chapterId: 'cos_ch3',
        timeCostDays: 14,
        setup:
            '你想到一条别人没想到的线索：活了几百年的幽灵，才是真正的目击者。'
            '问题是，幽灵们最近也有点反常——几乎没有谁肯好好回答问题，'
            '倒是差一点没头的尼克最近逢人就强调自己的「头」几乎是被砍掉的。',
        ambient: [
          '拉环把走廊里的奖杯擦得雪亮，不肯回答任何问题。',
          '一位灰衣修女模样的幽灵从你身边飘过，嘴里念着旧年的课表。',
          '尼克绅士地欠了欠身，但你能看出他在担心什么。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'talk_nearly_headless',
            text: '去赴尼克的「死亡日」晚宴邀请，混进幽灵堆里听风声',
            consequence:
                '死亡日晚宴定在万圣节前夜。你答应尼克会到场——'
                '他高兴得把脖子歪出一个危险的弧度。你猜到那天城堡里'
                '会同时发生很多事：活人和死人的两个宴会，总有一个先出乱子。',
            effect: StoryEffect(
              addKnowledge: ['cos_deathday_plan'],
              setFlags: ['cos_asked_ghosts', 'cos_deathday_invited'],
              spirit: 1,
            ),
            nextStepId: 'cos_ch3_nearly_headless',),
          StoryChoiceDef(
            id: 'ask_myrtille_target',
            text: '打听五十年前「死掉的那个女生」的名字',
            consequence:
                '一位常在盥洗室附近徘徊的幽灵的名字被几个学生提到：'
                '「哭鼻子的桃金娘。」有人说她五十年前就住在那间盥洗室，'
                '再也没出来过。你把这个名字和二楼走廊对上了号。',
            effect: StoryEffect(
              addKnowledge: ['cos_myrtille_clue'],
              setFlags: ['cos_knew_myrtille'],
              spirit: -1,
            ),
            nextStepId: 'cos_ch3_nearly_headless',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch3_nearly_headless',
        canonRefId: 'canon_cos_nearly_headless',
        chapterId: 'cos_ch3',
        timeCostDays: 1,
        setup:
            '走廊里碰见差点没头的尼克的时候，他正跟另一位幽灵争论什么。看见你过来，他停下来行了个礼。',
        ambient: [
          '幽灵飘过的地方，蜡烛会暗一下。',
          '走廊尽头有扇门半开着，风从里面吹出来。',
          '地板上的水渍还没有完全干。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'ask_ghost',
            text: '问问他关于密室知道些什么',
            consequence:
                '尼克说「那件事我不在场」。但他补了一句：「活人要小心走廊里的水。」这句话你记了很久。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['cos_ghost_hint'], setFlags: ['cos_asked_ghost'], spirit: 2),
          ),
          StoryChoiceDef(
            id: 'bow_back',
            text: '还了礼就走，不打听',
            consequence:
                '你点头致意，绕开了那片暗。身后两位幽灵继续争论，声音一直传到你拐弯的地方。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_polite_to_ghost'], reputation: 1, spirit: 2),
          ),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch3_old_news',
        chapterId: 'cos_ch3',
        timeCostDays: 8,
        setup:
            '高年级的讲述都是二手货。你想找一手记录——'
            '五十年前的旧《预言家日报》合订本就锁在图书馆的限阅区，'
            '需要教授签字。麦格教授听完你的来意，签字时多看了你一眼：'
            '「看完放回原处。别把听到的一切都当真。」',
        ambient: [
          '合订本的纸页脆得像饼干，翻页要用指尖托着。',
          '五十年前的报纸版式老派得多，字是手工排的。',
          '限阅区很安静，静得能听见纸页自己呼吸。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'read_archive',
            text: '逐版翻完事发那一个月的旧报纸',
            consequence:
                '那一个月的头版只有一条主线：校内一名女生死亡，'
                '校方「坚决否认与任何古老传闻有关」。'
                '配图里，围墙的影子拉得很长。你记下死亡日期——'
                '它离学年结束只有两个月，和今年一样。',
            effect: StoryEffect(
              addKnowledge: ['cos_archive_details'],
              setFlags: ['cos_read_archive', 'cos_kept_chasing'],
              spirit: -2,
            ),
            nextStepId: 'cos_ch3_clipping',),
          StoryChoiceDef(
            id: 'respect_limit',
            text: '只读校方通报的那一版，不碰学生死难的细节',
            consequence:
                '你只翻了头版就合上了合订本——五十年前的悲痛不该被你'
                '当故事翻。你把这次查证的目标换成校方的处置：'
                '「时任校长坚持不关校。」一行字。城堡挺过了那次，'
                '这一次它也需要有人相信它能。',
            effect: StoryEffect(
              addKnowledge: ['cos_school_survived'],
              setFlags: ['cos_read_archive'],
              spirit: 2,
            ),
            nextStepId: 'cos_ch3_clipping',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch3_clipping',
        chapterId: 'cos_ch3',
        timeCostDays: 1,
        setup:
            '图书馆最里面的架子上，你找到了五十年前的旧报纸合订本。翻到冬天那几期的时候，你发现有几页被人整整齐齐地剪掉了，只剩下窄窄的一条白边。',
        ambient: [
          '合订本的皮革封面已经开裂，摸上去掉渣。',
          '平斯夫人在远处整理书架，脚步声很轻。',
          '窗外的雨停了，云里漏下一道光。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'note_missing',
            text: '把被剪掉的日期和版面记下来',
            consequence:
                '你一共找出了七处缺口，集中在同一年的十一月。这个规律让你后背有点发凉。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['cos_knows_archive_gaps'], setFlags: ['cos_noted_gaps'], spirit: -1),
          ),
          StoryChoiceDef(
            id: 'ask_librarian',
            text: '拿着报纸去问平斯夫人',
            consequence:
                '她看了一眼就说「借阅规定不许议论」。但她把合订本收回去的时候，手比平时慢了一点。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_asked_librarian']),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第四章 · 万圣节（1992 年 10 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'cos_ch4',
    bookId: 'cos',
    ordinal: 4,
    title: '万圣节的字',
    steps: [
      StoryStepDef(
        id: 'cos_ch4_halloween_eve',
        canonRefId: 'canon_cos_banned_word',
        chapterId: 'cos_ch4',
        timeCostDays: 18,
        setup:
            '十月最后一天，城堡挂满了南瓜灯。今晚有两场宴会：礼堂里的万圣节宴，'
            '和地窖里尼克的死亡日五百年纪念。你按下午的安排收拾好自己——'
            '顺便留意到走廊上的人比平时急躁，费尔奇在二楼来回踱步。',
        ambient: [
          '南瓜灯的烛光把每个人的影子拉得长长的。',
          '宴会长桌上的蝙蝠形状点心一动不动，画上去的翅膀却偶尔扑棱。',
          '远处地窖的方向传来幽灵乐队的调音声，闷闷的。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'go_deathday',
            text: '照计划去地窖赴尼克的死亡日晚宴',
            consequence:
                '死亡日晚宴阴冷而盛大：腐烂的蛋糕、拉锯般的乐队、'
                '把头摘下来抛接的客串演出。你作为极少数的活人嘉宾备受关注，'
                '尼克感动得又把脖子歪了。直到散场，你们才听说——'
                '楼上的活人宴会出事了。',
            effect: StoryEffect(
              setFlags: ['cos_attended_deathday'],
              spirit: -1,
              reputation: 2,
            ),
            nextStepId: 'cos_ch4_pumpkin',),
          StoryChoiceDef(
            id: 'stay_hall',
            text: '留在礼堂的万圣节宴，和同学一起过节',
            consequence:
                '你留在暖和的礼堂里。宴会上半段其乐融融，'
                '直到一个低年级学生连滚带爬地冲进来喊：二楼墙上有字，'
                '还有猫被吊在火把架旁——整个礼堂的笑声像被掐断了。',
            effect: StoryEffect(
              setFlags: ['cos_halloween_witness', 'cos_hall_halloween'],
              spirit: -2,
            ),
            nextStepId: 'cos_ch4_pumpkin',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch4_pumpkin',
        canonRefId: 'canon_cos_slytherin_rumor',
        chapterId: 'cos_ch4',
        timeCostDays: 1,
        setup:
            '今年的万圣节装饰撤得特别早。前一天大礼堂里还挂着一排南瓜灯，第二天早上再经过的时候，那些位置全空了，只剩下挂过东西的细小绳痕。',
        ambient: [
          '门厅的蜡烛换成了普通的那种。',
          '有个低年级生站在原来挂南瓜的位置抬头看。',
          '走廊比往年安静，脚步声听得很清楚。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'ask_why',
            text: '去问为什么今年撤得这么早',
            consequence:
                '得到的回答是「上面的安排」。你追问了一句，对方就摆手走了。你站在空荡荡的门厅里，忽然觉得这座城堡有点陌生。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_asked_why'], spirit: -1),
          ),
          StoryChoiceDef(
            id: 'decorate_own',
            text: '回休息室，自己摆了些东西',
            consequence:
                '你把去年留下的一只小南瓜摆在窗台上。整个休息室只有你这一处有节日的样子。有人经过时笑了一下。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_decorated_own'], spirit: 3),
          ),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch4_first_petrified',
        chapterId: 'cos_ch4',
        timeCostDays: 12,
        canonRefId: 'canon_cos_petrification',
        setup:
            '消息传开：费尔奇的猫被「石化」了——不是死，是僵在半空，'
            '眼睛圆睁。旁边的墙上是一行擦不掉的血字：'
            '「密室已被打开，与继承人为敌者，当心。」'
            '麦格教授宣布学生即刻回宿舍。这件事由剧情文本讲述。',
        ambient: [
          '回宿舍的长队里没人说话，只有脚步声。',
          '走廊的火把都比平时亮，像是要把影子全部烧掉。',
          '你身边的低年级学生攥着你的袖口，指节发白。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'shield_firstyear',
            text: '把身边发抖的低年级学生护在人群里侧',
            consequence:
                '你让那个一年级的孩子走内侧，自己靠墙的那一侧走完全程。'
                '回到公共休息室后，孩子小声向你道谢。你说没什么。'
                '但第二天，几个高年级生开始学你在队伍里护人的样子。',
            effect: StoryEffect(
              setFlags: ['cos_shielded_firstyear'],
              reputation: 3,
              affection: 3,
              targetNpcId: 'colin',
              spirit: 1,
            ),
            nextStepId: 'cos_ch4_crowd',),
          StoryChoiceDef(
            id: 'observe_calmly',
            text: '控制住恐惧，把现场看到的东西默记下来',
            consequence:
                '你强迫自己把现场细节记下来：字迹的高度、火把的位置、'
                '猫僵直的姿势——像是被打断的瞬间。听完麦格教授的指令，'
                '你把这些写进笔记本，锁进了箱底。',
            effect: StoryEffect(
              addKnowledge: ['cos_first_scene_notes'],
              setFlags: ['cos_observed_calmly'],
              spirit: -2,
              reputation: 1,
            ),
            nextStepId: 'cos_ch4_crowd',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch4_crowd',
        chapterId: 'cos_ch4',
        timeCostDays: 1,
        setup:
            '第一个被石化的人被发现以后，走廊里围了一圈又一圈的人。你挤在外面，只看见担架的一角。',
        ambient: [
          '有人在哭，有人举着魔杖想往前挤。',
          '教工把人群往两边拨，喊着「让开」。',
          '墙上的水渍在灯光下显得特别明显。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'observe_seriously',
            text: '认真看清现场，记住每一个细节',
            consequence:
                '你注意到担架旁边那滩水比别处大，还注意到被抬走的方向不是医疗翼。这两件事你都没跟人说。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['cos_scene_details'], setFlags: ['cos_observed_scene'], spirit: -2),
          ),
          StoryChoiceDef(
            id: 'join_lockhart_fans',
            text: '跟围观的学生一起去看洛哈特教授怎么处理现场',
            consequence:
                '人群里的确有人等了很久，可教授到场之后并没有做什么，'
                '只是让人散开。你听见几个高年级生低声说了句什么，'
                '语气不太好。你没有跟着喊，但心里那点将信将疑又多了一分。',
            requireFlag: 'cos_doubted_lockhart',
            effect: StoryEffect(
              setFlags: ['cos_watched_lockhart_fail'],
              addKnowledge: ['cos_lockhart_suspect'],
              spirit: -2,
              reputation: 1,
            ),
          ),

          StoryChoiceDef(
            id: 'help_crowd',
            text: '帮着把围观的人往后带',
            consequence:
                '你张开手臂把人群往后挡，喊了几嗓子。教工看了你一眼，点了点头。等担架抬过去，你的手心全是汗。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_helped_crowd'], reputation: 2, spirit: 1),
          ),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch4_next_morning',
        chapterId: 'cos_ch4',
        timeCostDays: 1,
        setup:
            '血字的第二天早晨，二楼走廊被拉起了绳。'
            '学生们像参观某种可怕的展览一样远远探头，'
            '被赶来的教授一次次驱散。校园里第一次出现了「转学」这个词——'
            '从几个高年级生的嘴里。',
        ambient: [
          '绳子外的人越聚越多，教授的声音一遍遍从人群里响起。',
          '二楼盥洗室的门第一次被挂上「维修」的木牌。',
          '有人的行李箱轮子声从上午响到中午。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'steady_classmates',
            text: '在早饭桌上替慌张的桌友把事情捋一遍',
            consequence:
                '「石化不是死亡——庞弗雷夫人亲口说的；'
                '校方没封校——说明他们有办法；我们结伴走——这是我们能做的。」'
                '你一条条说完，同桌们的脸色肉眼可见地缓了过来。'
                '有人小声重复你的最后一句，像在背一条咒语。',
            effect: StoryEffect(
              setFlags: ['cos_steadied_table'],
              reputation: 3,
              housePoints: 2,
              spirit: 2,
            ),
            nextStepId: 'cos_ch4_morning_after',),
          StoryChoiceDef(
            id: 'avoid_second_floor',
            text: '从今天起，把二楼从自己的生活动线里删掉',
            consequence:
                '你研究了三张楼梯换向表，拼出一条全年不经过二楼的路线。'
                '多走的路让你每天少睡十分钟，但「可控」二字值这十分钟。'
                '你把这条路线画成图，同桌们人手抄了一份。',
            effect: StoryEffect(
              setFlags: ['cos_route_map'],
              spirit: 1,
            ),
            nextStepId: 'cos_ch4_morning_after',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch4_morning_after',
        chapterId: 'cos_ch4',
        timeCostDays: 1,
        setup:
            '第二天早上，出事的那条走廊被封了。地上拉起了两道绳子，隔着几米站着两个高年级生，路过的人都绕着走。',
        ambient: [
          '有学生在远处指指点点，不敢靠近。',
          '被封的那段走廊里，灯一直亮着。',
          '早餐时大家都在低声说话，没人开玩笑。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'detour_route',
            text: '找一条新的路，绕开那段走廊',
            consequence:
                '你花了一天时间把城堡摸了个遍。从此你手里有了一张别人没有的路线图——虽然你希望自己用不上它。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['cos_knows_routes'], setFlags: ['cos_found_detour'], spirit: 2),
          ),
          StoryChoiceDef(
            id: 'write_down_facts',
            text: '把昨天到今天听到的每一句话都记到本子上',
            consequence:
                '你分了左右两栏：左边写「有人说的」，右边写「有人亲口证的」。'
                '写着写着你就发现，左边那一栏几乎占满了整页，'
                '右边只有三行——都是庞弗雷夫人和教授说过的话。'
                '你把本子合上，心里第一次有了点底。',
            requireFlag: 'cos_observed_scene',
            effect: StoryEffect(
              setFlags: ['cos_started_notes'],
              addKnowledge: ['cos_knows_fact_vs_rumor'],
              spirit: 3,
              reputation: 2,
            ),
          ),

          StoryChoiceDef(
            id: 'stand_watch',
            text: '在绳子外面站一会儿',
            consequence:
                '你没站多久就走了。回头的时候你看见那两个高年级生也在往里看。他们大概也不知道里面是什么。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_stood_watch']),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第五章 · 结伴的冬天（1992 年 11 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'cos_ch5',
    bookId: 'cos',
    ordinal: 5,
    title: '结伴的冬天',
    steps: [
      StoryStepDef(
        id: 'cos_ch5_pairs',
        chapterId: 'cos_ch5',
        timeCostDays: 6,
        setup:
            '校方的新规一条接一条：下午四点半后不许单独在走廊逗留、'
            '部分楼梯口封闭、每个学生登记「结伴名单」。'
            '连霍格沃茨的墙上都加了新岗——画像是会打小报告的。'
            '恐慌像冬天的雾，从走廊渗进教室。',
        ambient: [
          '结伴名单贴在公共休息室门口，写得歪歪扭扭的名字排了三栏。',
          '封闭的楼梯口用丝绒绳拦着，画像里的老院长整天盯着。',
          '人人走路都成群结队，连去盥洗室都要报备。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'organize_pairs',
            text: '主动整理结伴名单，把落单的人排进去',
            consequence:
                '你把名单重新誊了一遍，按课表分时段排好，'
                '特意把三个没朋友的落单同学插进了各组。'
                '级长看了你的版本，直接用它替换了原来那张。'
                '这件事让几个原本不认识你的人记住了你的名字。',
            effect: StoryEffect(
              setFlags: ['cos_organized_pairs', 'cos_helped_juniors'],
              reputation: 4,
              housePoints: 3,
              spirit: 2,
            ),
            nextStepId: 'cos_ch5_buddy',),
          StoryChoiceDef(
            id: 'visit_hospital',
            text: '想办法去医疗翼，看看被石化的猫到底什么样',
            consequence:
                '庞弗雷夫人拦住了你，但隔着门帘你看了一眼：'
                '那只猫保持着一个撕裂般的姿势僵着，皮毛像石头。'
                '「在等曼德拉草复壮剂，」她在帘子后说，「都等着它。」'
                '你想起斯普劳特教授温室里那些盖着布的盆栽。',
            effect: StoryEffect(
              addKnowledge: ['cos_mandrake_is_cure', 'cos_hospital_visit'],
              setFlags: ['cos_visited_hospital'],
              spirit: -2,
            ),
            nextStepId: 'cos_ch5_buddy',),
          StoryChoiceDef(
            id: 'study_hard',
            text: '恐惧越是蔓延，越要按时去每一堂课',
            consequence:
                '你坚持全勤。变形课上麦格教授难得地表扬了你一次——'
                '「在大家都在传谣的时候，还有人记得自己是来上学的。」'
                '这句话被你记了很久，它比任何加分都提气。',
            effect: StoryEffect(
              setFlags: ['cos_kept_attending'],
              housePoints: 4,
              reputation: 2,
              spirit: 3,
            ),
            nextStepId: 'cos_ch5_buddy',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch5_buddy',
        chapterId: 'cos_ch5',
        timeCostDays: 1,
        setup:
            '学校开始要求低年级生出行必须结伴。你的同伴是个跟你不太熟的男生，头两节课你们几乎没说过话。',
        ambient: [
          '走廊里到处是两人一组的学生。',
          '有人抱怨这样做什么都不方便。',
          '窗外的天阴沉着，像要下雪。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'make_friends',
            text: '主动找话题，把这段同行变得不那么难熬',
            consequence:
                '你问了他在哪个学院、喜欢哪门课。聊到第三节课的时候，你们已经能在走廊里对着笑话笑了。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_made_buddy'], spirit: 5, targetNpcId: 'seamus', affection: 3),
          ),
          StoryChoiceDef(
            id: 'walk_silent',
            text: '各走各的，只要挨着就行',
            consequence:
                '你们保持着两米的距离走了一整天。虽然尴尬，但至少谁都没出事。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_silent_buddy']),
          ),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch5_quidditch',
        canonRefId: 'canon_cos_polyjuice',
        chapterId: 'cos_ch5',
        timeCostDays: 6,
        setup:
            '魁地奇赛季照常开赛——这几乎是唯一没被恐慌取消的活动。'
            '看台上人人攥着围巾，喊声比往年更用力，像是要用声音把恐惧压回去。'
            '比赛本身却出了状况：一颗游走球像是长了眼睛，追着场上一个飞得最快的身影不放，'
            '最后把一只手臂直接砸断了。',
        ambient: [
          '看台的木板上积着薄霜，跺脚取暖的声音此起彼伏。',
          '游走球划过看台前的风声让人下意识缩脖子。',
          '医疗翼的担架从场地边一路小跑，人群鸦雀无声。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'cheer_loudly',
            text: '把嗓子喊哑，带头给场上的人壮声势',
            consequence:
                '你的嗓子在第三节就哑了，但你身边的整排人都站了起来。'
                '那天学院队赢得艰难，看台的声浪却是一年里最响的一次。'
                '散场时有人说：「今天这才像个学校。」',
            effect: StoryEffect(
              setFlags: ['cos_cheered_match'],
              housePoints: 3,
              spirit: 4,
            ),
            nextStepId: 'cos_ch5_match',),
          StoryChoiceDef(
            id: 'watch_ball',
            text: '盯住那颗不对劲的游走球，记下它的轨迹',
            consequence:
                '你没有看球赛的精彩处，全程盯着那颗游走球——'
                '它的转向太尖锐、太持续，不像普通的击球能解释。'
                '赛后你把轨迹画在纸角上，旁边标了个问号。'
                '有人施了魔法，而且就在看台上。你把这个想法锁回脑子里。',
            effect: StoryEffect(
              addKnowledge: ['cos_bludger_suspicion'],
              setFlags: ['cos_watched_ball'],
              spirit: -1,
              reputation: 1,
            ),
            nextStepId: 'cos_ch5_match',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch5_match',
        chapterId: 'cos_ch5',
        timeCostDays: 1,
        setup:
            '这个赛季的第一场魁地奇比赛取消了。看台上空了大半，只有零星几个人坐着，球场上的三个球门在风里轻轻晃。',
        ambient: [
          '球场上的球门在风里轻轻晃。',
          '有人拖着扫帚从场边走过，没有抬头。',
          '解说席的喇叭一直没响。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'stay_and_watch',
            text: '留下来坐一会儿，看看空球场',
            consequence:
                '你坐到散场才走。风把看台下面的纸片吹得满地跑。你想，有些东西一旦停下来，要重新开始就难了。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_watched_empty'], spirit: -1),
          ),
          StoryChoiceDef(
            id: 'leave_quietly',
            text: '看一眼就走，回宿舍看书',
            consequence:
                '你转身往回走，路上一个人也没碰到。回到宿舍，炉火已经快灭了。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_left_quietly'], spirit: 2),
          ),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch5_weekend_mood',
        chapterId: 'cos_ch5',
        timeCostDays: 1,
        setup:
            '十一月的第一个周末，城堡里的空气闷得像结了冰的湖面。'
            '连画中人都在抱怨：「孩子们不笑了，画像都挂得没滋味。」'
            '你意识到一件被忽略的事：恐慌也是一种会传染的病，'
            '而它需要一个解药。',
        ambient: [
          '画里的女士隔着画框看你，眼神像在等好消息。',
          '温室里的泥土味是城堡里少数没变的东西。',
          '有人在下棋，棋子走两步就被一句「听说——」打断一次。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'start_gossip_free',
            text: '在自己桌上立一条规矩：晚饭时间不许讲石化',
            consequence:
                '规矩贴出去的第一天就有人犯规，你只是敲了敲桌子指了指规矩。'
                '第二天犯规的人变成了零。第三天，桌上开始有人讲笑话了。'
                '这条规矩后来被别的桌抄走——恐慌封锁不了城堡，'
                '但「晚饭的一小时平静」可以由人守住。',
            effect: StoryEffect(
              setFlags: ['cos_gossip_free_rule'],
              reputation: 3,
              housePoints: 2,
              spirit: 3,
            ),
            nextStepId: 'cos_ch5_letter_home',),
          StoryChoiceDef(
            id: 'brew_tea',
            text: '去温室找斯普劳特教授讨点安神的花草',
            consequence:
                '教授给了你一小袋洋甘菊，教你泡「给神经松绑」的茶。'
                '她在温室里是个例外——恐惧对她好像没用：「植物不撒谎。'
                '曼德拉草每天都在长，这就是眼下最好的消息。」'
                '你把这句话带回了公共休息室，配上了一壶茶。',
            effect: StoryEffect(
              addItems: ['白鲜香精'],
              setFlags: ['cos_chamomile_tea'],
              affection: 2,
              spirit: 3,
            ),
            nextStepId: 'cos_ch5_letter_home',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch5_letter_home',
        chapterId: 'cos_ch5',
        timeCostDays: 1,
        setup:
            '这个周末你摊开羊皮纸，想给家里写封信。写到一半你停住了笔——你不知道该不该把学校里这几天发生的事如实告诉他们。',
        ambient: [
          '羊皮纸上已经写了大半页，都是些无关紧要的。',
          '窗外有几个低年级生在雪地里跑。',
          '墨水瓶快见底了，你把瓶底刮了刮。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'write_truth',
            text: '把真实的情况写进去，哪怕他们担心',
            consequence:
                '你写了城堡里发生的事，也写了自己很安全。寄出去以后你想，他们大概还是会担心——但至少知道的是真的。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_wrote_truth'], reputation: 1, spirit: 3),
          ),
          StoryChoiceDef(
            id: 'write_safe',
            text: '只写好的，别让他们胡思乱想',
            consequence:
                '你把信写得轻松愉快，连考试都写成了很有趣的事。封口的时候你叹了口气。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_wrote_safe'], spirit: 1),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第六章 · 决斗俱乐部（1992 年 12 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'cos_ch6',
    bookId: 'cos',
    ordinal: 6,
    title: '决斗俱乐部',
    steps: [
      StoryStepDef(
        id: 'cos_ch6_club',
        chapterId: 'cos_ch6',
        timeCostDays: 6,
        canonRefId: 'canon_cos_dueling_club',
        setup:
            '为了让学生「在危险面前有所准备」，洛哈特开办了决斗俱乐部。'
            '大礼堂里搭起高台，他和斯内普教授的示范对决只坚持了一个回合——'
            '缴械咒把他本人轰下了台。随后全场两人一组自由练习，混乱瞬间失控。'
            '这件事由剧情文本讲述。',
        ambient: [
          '高台上的横幅写着「决斗俱乐部：安全第一」，边角已经卷了。',
          '有人配对的咒语打歪，点燃了旁边一摞垫子，几个男生踩火忙作一团。',
          '斯内普教授抱臂站在台侧，眼神像是在验尸。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'practice_seriously',
            text: '不理会闹剧，抓住机会把缴械咒练熟',
            consequence:
                '你拉住一个同样认真的同学，把「除你武器」拆成三步练：'
                '挥臂、咬字、盯住对方的手。练到第三轮你成功了一次完整的缴械——'
                '对手的魔杖划着弧线飞过来，稳稳落在你掌心。'
                '这份踏实，比看一百次签名照有用。',
            effect: StoryEffect(
              setFlags: ['cos_learned_disarming', 'cos_practice_serious'],
              housePoints: 3,
              spirit: 3,
            ),
            nextStepId: 'cos_ch6_watch_club',),
          StoryChoiceDef(
            id: 'watch_snake',
            text: '留意场上那场「蛇」的意外——以及人群里骤起的窃语',
            consequence:
                '练习区的角落出事了：一条被变出来的蛇冲向人群，'
                '然后——它像是听懂了谁的话，僵在半空，又缓缓垂下。'
                '全场安静了一瞬，随即窃语声炸开：「有人会跟蛇说话。」'
                '你看得真切：那不是闹剧，是某种你从未见过的天赋。',
            effect: StoryEffect(
              addKnowledge: ['cos_snake_talk_witness'],
              setFlags: ['cos_saw_snake_talk'],
              spirit: -2,
            ),
            nextStepId: 'cos_ch6_watch_club',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch6_watch_club',
        chapterId: 'cos_ch6',
        timeCostDays: 1,
        setup:
            '决斗俱乐部第一次活动那天，大礼堂里挤得满满当当。你站在后排，看几位高年级生怎么把中间的台子搭起来，又怎么把地板清空。',
        ambient: [
          '有人在前面演示，魔杖挥得很快。',
          '观众里不断发出吸气声和笑声。',
          '地板被清空了一大块，中间画了条线。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'watch_learn',
            text: '认真看每一个动作，记下能记的',
            consequence:
                '你记住了两个咒语的起手式，虽然回家练了很多遍都没成功。但你知道自己记住了。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['cos_knows_duel_basics'], setFlags: ['cos_learned_moves'], spirit: 3),
          ),
          StoryChoiceDef(
            id: 'stay_back_row',
            text: '站在后面，只想看看会发生什么',
            consequence:
                '后排的视野不好，你踮了几次脚。后来台子上出了状况，人群一阵骚动，你被推着往后退了两步。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_back_row'], spirit: 1),
          ),
          StoryChoiceDef(
            id: 'copy_stance',
            text: '照着台上两个人的起手式，把手型摆了一遍',
            consequence:
                '你没有挥出去，只是把姿势比了比。旁边的同学看了一眼'
                '说「你手肘太高了」，顺手帮你压平。就这一下，'
                '后来你在宿舍里照着练，居然真的把那一式练成了形。',
            requireFlag: 'cos_practice_serious',
            effect: StoryEffect(
              setFlags: ['cos_practiced_stance'],
              addKnowledge: ['cos_knows_duel_basics'],
              housePoints: 2,
              spirit: 3,
            ),
          ),

        ],
      ),
      StoryStepDef(
        id: 'cos_ch6_aftermath',
        chapterId: 'cos_ch6',
        timeCostDays: 3,
        setup:
            '决斗俱乐部的次日，「蛇佬腔」三个字传遍走廊。'
            '有人说会跟蛇说话的是五十年来第一个，有人说这是萨拉查·斯莱特林的天赋——'
            '而能打开密室的，只有斯莱特林的继承人。'
            '传闻像雪一样，落满了每一面墙。',
        ambient: [
          '公共休息室里的讨论声压得很低，人人都在重复「继承人」三个字。',
          '有人开始在走廊里排队躲着某个方向走——流言也有自己的风口。',
          '图书馆里《霍格沃茨：一段校史》被借空了。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'refuse_rumor',
            text: '当面怼一个把传闻说得太起劲的人',
            consequence:
                '「你们亲眼看见那人做了什么坏事吗？」你当众问。'
                '对方语塞。你补了一句：「会说话蛇的人现在就躺在这所学校的病床上'
                '——石化的那种。」人群散了。流言没有停，但至少那天没人再添油加醋。',
            effect: StoryEffect(
              setFlags: ['cos_refused_rumor'],
              reputation: 3,
              spirit: 2,
            ),
            nextStepId: 'cos_ch6_after_club',),
          StoryChoiceDef(
            id: 'dig_history',
            text: '去图书馆借《霍格沃茨：一段校史》，查萨拉查·斯莱特林',
            consequence:
                '书里的记载干巴巴的：四位创始人，一位因纯血理念不合而离开，'
                '留下了一座传说中的密室。平斯夫人说你已是这个月第二十个借这本书的。'
                '你在借书卡上看到一串熟悉的名字——整个二年级都在查同一件事。',
            effect: StoryEffect(
              addItems: ['旧书'],
              addKnowledge: ['cos_slytherin_legacy'],
              setFlags: ['cos_dug_history'],
              spirit: -1,
            ),
            nextStepId: 'cos_ch6_after_club',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch6_after_club',
        chapterId: 'cos_ch6',
        timeCostDays: 1,
        setup:
            '俱乐部那晚之后，关于那条蛇的传言一夜之间传遍了整座城堡。你走在走廊里，听见每个人都在说同一件事。',
        ambient: [
          '有几个学生聚在一起，比划着蛇的动作。',
          '走廊里的画像今天都不说话了。',
          '窗外黑得早，玻璃上映着烛光。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'think_snake',
            text: '回宿舍，把听到的所有说法整理一遍',
            consequence:
                '你写满了一页纸。写完之后你发现，所有人的说法都指向同一件事——但没人知道那条蛇在哪。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['cos_knows_snake_talk'], setFlags: ['cos_organized_rumors'], spirit: 1),
          ),
          StoryChoiceDef(
            id: 'avoid_topic',
            text: '不去想，做点别的分散注意力',
            consequence:
                '你找了本闲书看到很晚。书里的故事很好看，但合上的时候，走廊里那些话又回来了。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_avoided_topic'], spirit: 2),
          ),
          StoryChoiceDef(
            id: 'recheck_corridors',
            text: '沿着那天听说的几条走廊再走一遍，把水渍和墙缝看仔细',
            consequence:
                '你走近每一条墙缝，蹲下来看那些还没擦干净的地方。'
                '有一处的水痕比别处低，像是从更靠下的地方渗上来的。'
                '你说不出这代表什么，但把位置记在了课表背面。',
            requireFlag: 'cos_back_row',
            effect: StoryEffect(
              setFlags: ['cos_marked_wall'],
              addKnowledge: ['cos_location_clue'],
              spirit: -1,
              reputation: 2,
            ),
          ),

        ],
      ),
      StoryStepDef(
        id: 'cos_ch6_whisper_winds',
        chapterId: 'cos_ch6',
        timeCostDays: 1,
        setup:
            '「继承人」的传闻开始长牙齿：有斯莱特林的同学在走廊被拦住质问，'
            '有混血背景的学生被人贴纸条。恐慌找到了可以欺负的具体对象——'
            '这比恐慌本身更难看。你亲眼看见一个一年级男生被围在楼梯口。',
        ambient: [
          '楼梯口的嘲笑声不大，但足够让被围的人耳朵发红。',
          '「血统」这个词从没像这个月这样频繁地出现在走廊。',
          '有教授路过时勒令散开，但人群散了又聚。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'step_in',
            text: '从人群里走出去，站到被围的同学身边',
            consequence:
                '你什么都没说，只是挤进去站在他旁边。'
                '围观的人骂得没那么起劲了——一个人的沉默可以无视，'
                '两个人的沉默就有了重量。一个教授随后赶到，人群作鸟兽散。'
                '那个男生后来在桌上给你留了一块蛋糕。',
            effect: StoryEffect(
              setFlags: ['cos_stood_with_bullied'],
              reputation: 4,
              housePoints: 3,
              affection: 3,
              targetNpcId: 'blaise',
              spirit: 2,
            ),
            nextStepId: 'cos_ch6_wind',),
          StoryChoiceDef(
            id: 'report_pattern',
            text: '把「谁在带头欺负人」的规律整理给级长',
            consequence:
                '你把一周里三次围堵的时间、地点、牵头人写成一张纸，'
                '折好塞给了级长。级长照着这张纸蹲了两晚，'
                '第三晚当场逮到人。纸条的事没人知道是你写的——'
                '这正好，你要的不是名声。',
            effect: StoryEffect(
              setFlags: ['cos_reported_pattern'],
              reputation: 2,
              housePoints: 3,
              spirit: 1,
            ),
            nextStepId: 'cos_ch6_wind',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch6_wind',
        chapterId: 'cos_ch6',
        timeCostDays: 1,
        setup:
            '这天夜里风特别大，把城堡高处的窗户吹得哐哐作响。你被吵醒了，翻了好几次身也睡不着，索性坐起来听了一会儿。',
        ambient: [
          '塔楼的钟在风里响得不太准。',
          '走道里有人起来走动，脚步声很轻。',
          '窗帘被风吹起来又落回去。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'get_up',
            text: '披上外套，到公共休息室坐一会儿',
            consequence:
                '休息室的炉火还没灭。你坐在火边，听见风声一层一层叠上来。后来你在沙发上睡着了。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_night_up'], spirit: 1),
          ),
          StoryChoiceDef(
            id: 'stay_bed',
            text: '把被子蒙过头，逼自己再睡',
            consequence:
                '你数了很久的羊。风声慢慢变成了一种背景，最后你真的又睡着了。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_slept_through_wind'], spirit: 2),
          ),
          StoryChoiceDef(
            id: 'listen_to_wind',
            text: '不点灯，就躺着听风里有没有别的声音',
            consequence:
                '风声之外，你听见楼梯在响、画像在翻身、远处有人关门。'
                '这些声音平时听不见，因为白天太吵。你躺着听了很久，'
                '忽然觉得这座城堡其实一直醒着，只是没人肯听。',
            requireFlag: 'cos_learned_moves',
            effect: StoryEffect(
              setFlags: ['cos_heard_castle'],
              spirit: 4,
            ),
          ),

        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第七章 · 圣诞（1992 年 12 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'cos_ch7',
    bookId: 'cos',
    ordinal: 7,
    title: '石化阴影下的圣诞',
    steps: [
      StoryStepDef(
        id: 'cos_ch7_stay_or_go',
        chapterId: 'cos_ch7',
        timeCostDays: 4,
        canonRefId: 'canon_cos_christmas',
        setup:
            '圣诞假期登记表贴了出来。今年签「回家」的人比去年多了一倍——'
            '家长们的理由出奇一致：「出了事连人都不齐。」'
            '留下来的名单短得反常，礼堂里那十二棵圣诞树看上去都比往年空旷。'
            '这件事由剧情文本讲述。',
        ambient: [
          '登记表上的签名一格一格排下来，越往后间隔越大。',
          '圣诞树的冰凌在烛光里闪闪发亮，像没化开的冬天。',
          '行李箱的轮子声在走廊里响了整整一下午。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'stay_school',
            text: '留下来——越是这样的时候，越有人需要留下',
            consequence:
                '你在「留校」一栏签了名。留下的十几个学生来自四个学院，'
                '以前谁也不理谁，现在却在同一张长桌上吃饭。'
                '假期第一晚，你们在休息室里把桌子拼在一起打牌——'
                '这大概是恐慌季里最像「正常生活」的一晚。',
            effect: StoryEffect(
              setFlags: ['cos_stayed_christmas', 'cos_stayed_at_school'],
              spirit: 3,
              reputation: 2,
            ),
            nextStepId: 'cos_ch7_decision',),
          StoryChoiceDef(
            id: 'go_home',
            text: '回家——让家里人也放心一点',
            consequence:
                '你回了家。家里的炉火、妈妈的唠叨、不用设防的走廊——'
                '你把霍格沃茨的消息挑着讲，报喜不报忧。'
                '假期过得很快，但每次想起城堡，心里都空一块：'
                '你的同学还留在那片恐惧里。',
            effect: StoryEffect(
              setFlags: ['cos_went_home_christmas'],
              spirit: 4,
              reputation: -1,
            ),
            nextStepId: 'cos_ch7_decision',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch7_decision',
        chapterId: 'cos_ch7',
        timeCostDays: 1,
        setup:
            '圣诞假期要不要留校，是这几天每个低年级生都在讨论的问题。你收拾行李的时候，箱子装了一半又停下了。',
        ambient: [
          '宿舍里的人越来越少，空床越来越多。',
          '有人在门口问「你走不走」。',
          '窗外开始飘雪，落在地上就化了。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'decide_stay',
            text: '决定留下，把箱子重新打开',
            consequence:
                '你把行李一件件放回去。整个宿舍最后只剩三个人。那天晚上城堡安静得不像真的。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_stayed_christmas'], spirit: 2),
          ),
          StoryChoiceDef(
            id: 'decide_go',
            text: '决定回家，把剩下的也装进去',
            consequence:
                '你很快就把箱子收拾好了。走的时候你在门口回头看了一眼，走廊尽头那盏灯还亮着。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_went_home'], spirit: 3),
          ),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch7_snow',
        chapterId: 'cos_ch7',
        timeCostDays: 5,
        setup:
            '留校的假期出奇地安静。大雪封了场地，湖面冻得结结实实，'
            '连城堡的吵闹都像被雪吸走了。有天下午，几个留校的学生'
            '在场地里打了一场没有裁判、没有学院分的雪仗——'
            '四院的人混编成队，打得浑身是雪。',
        ambient: [
          '雪球在空中炸开，笑声在雪地上传得很远。',
          '礼堂里端的黄油啤酒永远是热的，杯壁上的水珠往下淌。',
          '窗外的雪把禁林描成一幅静物画，安静得不像有恐惧的地方。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'snow_battle',
            text: '组织那场四院混编的雪仗',
            consequence:
                '你画了简陋的场地线，用两顶帽子当界桩。'
                '赫奇帕奇的一个高个子女生成了两队争抢的王牌，'
                '拉文克劳的几个人搞出了雪球抛物线。'
                '那天晚上，有人提议明年还这么打——'
                '「不分学院的那种。」',
            effect: StoryEffect(
              setFlags: ['cos_snow_friendship'],
              addItems: ['编织围巾'],
              spirit: 5,
              reputation: 2,
            ),
            nextStepId: 'cos_ch7_quiet_halls',),
          StoryChoiceDef(
            id: 'quiet_library',
            text: '趁图书馆没人，把这学年的线索重新捋一遍',
            consequence:
                '空无一人的图书馆里，你把这一学期的记录摊开：血字、石化的猫、'
                '游走球、蛇佬腔、五十年前的旧事。平斯夫人破例没赶你，'
                '只是在离开时说了句「早点回去」。你的笔记比上学期厚了一倍。',
            effect: StoryEffect(
              addKnowledge: ['cos_timeline_notes'],
              setFlags: ['cos_reviewed_clues'],
              spirit: 1,
              housePoints: 2,
            ),
            nextStepId: 'cos_ch7_quiet_halls',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch7_quiet_halls',
        chapterId: 'cos_ch7',
        timeCostDays: 1,
        setup:
            '假期里的城堡安静得能听见自己的脚步声。你走在平时最挤的那条走廊上，现在一个人也没有。',
        ambient: [
          '画像们有的在睡觉，有的在小声聊天。',
          '有些教室的门锁上了，有些还虚掩着。',
          '雪把窗外的草坪盖得平平的，没有脚印。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'explore',
            text: '趁人少，把平时没去过的地方走一遍',
            consequence:
                '你找到了一条从图书馆直通四楼的近路，还发现了一间堆满旧课桌椅的储藏室。这些发现让你对这座城堡多了几分把握。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['cos_knows_shortcuts'], setFlags: ['cos_explored_halls'], spirit: 4),
          ),
          StoryChoiceDef(
            id: 'study_quiet',
            text: '找间空教室，安静地复习',
            consequence:
                '你在空教室里待了一整天。没有人打扰，效率高得惊人。天黑的时候你才想起来吃饭。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_studied_quiet'], housePoints: 5, spirit: 3),
          ),
          StoryChoiceDef(
            id: 'recheck_marked_spot',
            text: '带着课表背面那张图，去那面墙再看一眼',
            consequence:
                '走廊空了，那处水痕还在，而且比上个月往下爬了一指。'
                '你蹲着看了很久。城堡里结冰的天气它都不干，'
                '那就说明水的来处还开着——你把这一指宽的变化也记了上去。',
            requireKnowledge: ['cos_location_clue'],
            effect: StoryEffect(
              setFlags: ['cos_tracked_wall'],
              addKnowledge: ['cos_wall_still_weeping'],
              reputation: 2,
              spirit: -1,
            ),
          ),

          StoryChoiceDef(
            id: 'check_on_firstyears',
            text: '绕到低年级的住处附近，看看那几个新生有没有事',
            consequence:
                '你没进去，只在走廊尽头站了一会儿。宿舍里亮着灯，'
                '有笑声传出来，听起来比上学期安稳。你转身往回走，'
                '觉得这个圣诞留校也没那么空。',
            requireKnowledge: ['knows_weasley_family'],
            effect: StoryEffect(
              setFlags: ['cos_checked_juniors_winter'],
              reputation: 2,
              spirit: 5,
            ),
          ),

        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第八章 · 一月的风声（1993 年 1 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'cos_ch8',
    bookId: 'cos',
    ordinal: 8,
    title: '一月的风声',
    steps: [
      StoryStepDef(
        id: 'cos_ch8_second_wave',
        canonRefId: 'canon_cos_winter_rules',
        chapterId: 'cos_ch8',
        timeCostDays: 12,
        setup:
            '假期的平静在新学期第二周被打破：又有人被石化了——'
            '这一次是一个一年级男孩和一位几百岁的幽灵，'
            '被发现时就在结伴名单标注「安全」的那段走廊上。'
            '「结伴」神话破灭了：连成群结队都拦不住它。',
        ambient: [
          '那段走廊被拉起了丝绒绳，画像里的人都在摇头。',
          '医疗翼的门帘放下又掀开，来探望的人排成了队。',
          '公共休息室里有人提议给家里写信，笔尖在羊皮纸上悬了很久。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'join_guard',
            text: '加入高年级自发组织的「结伴巡逻」',
            consequence:
                '几个五年级生把落单巡逻的志愿名单贴了出来，'
                '你第一个签名。巡逻没有权限抓任何东西——'
                '它的意义是让走廊里始终有人影、有灯光、有回应。'
                '你值的第一晚平安无事，第二天有人学着你也报了名。',
            effect: StoryEffect(
              setFlags: ['cos_joined_guard', 'cos_guarded_corridors'],
              reputation: 4,
              housePoints: 3,
              spirit: -1,
            ),
            nextStepId: 'cos_ch8_fear',),
          StoryChoiceDef(
            id: 'watch_silence',
            text: '留意谁在慌乱中反常地安静——安静的人往往知道点什么',
            consequence:
                '你注意到几个细节：某几个学院的桌上聊得最凶却什么新消息都拿不出；'
                '而有一个方向的人几乎不谈论石化。这不是证据，'
                '但恐慌里，「不谈论」本身就是一种声音。你把这条也记进了笔记。',
            effect: StoryEffect(
              addKnowledge: ['cos_quiet_group_note'],
              setFlags: ['cos_watched_silence'],
              spirit: -1,
              reputation: 1,
            ),
            nextStepId: 'cos_ch8_fear',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch8_fear',
        chapterId: 'cos_ch8',
        timeCostDays: 1,
        setup:
            '第二起石化事件之后，学校的气氛明显变了。课间不再有人打闹，走廊里大家都贴着墙走。',
        ambient: [
          '有学生家长来接孩子，站在门厅不肯进来。',
          '公告栏上的通知换得比平时勤。',
          '食堂里空了好几排座位。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'keep_routine',
            text: '照常上课、照常写作业',
            consequence:
                '你把每一天都排得满满的。规律的生活本身成了一种安定。在这种时候，能照常做事就是胜利。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_kept_routine'], housePoints: 5, spirit: 3),
          ),
          StoryChoiceDef(
            id: 'reach_out',
            text: '主动去关心几个看起来最害怕的人',
            consequence:
                '你找了几个一年级生聊天。有个小姑娘一开始不敢说话，聊到最后她问你「会不会有事」。你说不会——虽然你也不确定。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_reached_out'], reputation: 2, spirit: 2, targetNpcId: 'ginny', affection: 3),
          ),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch8_parent_letters',
        chapterId: 'cos_ch8',
        timeCostDays: 10,
        setup:
            '家信一封接一封地到。有家长在信里直接质问校方「为什么还不关门」，'
            '猫头鹰们成群落在猫头鹰棚屋，雪片一样的信让传达室的教授应接不暇。'
            '校长在早课上只说了一句话：「城堡里最安全的地方，是彼此身边。」',
        ambient: [
          '猫头鹰棚屋的雪地上落满了来送信的影子。',
          '早课上校长的声音不高，却让整个礼堂安静了整整一顿饭。',
          '有同学把家信折成纸飞机，从天文塔上放下去，谁也没笑。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'write_home_honest',
            text: '给家里写一封实话实说的报平安信',
            consequence:
                '你没有报喜不报忧：把石化的真相、校方的措施、你自己的安排'
                '一五一十写了三页纸，最后附上一句「我结伴巡逻，很安全」。'
                '回信只有一行：「照顾好自己，我们相信你。」'
                '你把信夹进了课本最里面的一页。',
            effect: StoryEffect(
              setFlags: ['cos_honest_letter'],
              addItems: ['手写贺卡'],
              spirit: 3,
            ),
            nextStepId: 'cos_ch8_advice',),
          StoryChoiceDef(
            id: 'comfort_friend',
            text: '拉住一个被家信吓哭的同学，陪他吃完这顿饭',
            consequence:
                '你没说什么大道理，只是把自己的南瓜汁推过去，'
                '听他把担心全倒出来，然后陪他把饭吃完。'
                '分别时他说：「谢谢你没有说别怕。」'
                '——「说别怕的人自己也在怕。」你答。',
            effect: StoryEffect(
              setFlags: ['cos_comforted_friend'],
              affection: 3,
              reputation: 2,
              spirit: 2,
            ),
            nextStepId: 'cos_ch8_advice',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch8_advice',
        chapterId: 'cos_ch8',
        timeCostDays: 1,
        setup:
            '家长的信像雪片一样飞进城堡，门厅的信架上堆得老高。有的家长要立刻接孩子回去，有的写信来要求学校给个说法，还有的干脆亲自来了，站在门厅不肯进。',
        ambient: [
          '公告栏边围着看信的家长和老师。',
          '有学生看完信就回宿舍收拾东西了。',
          '门厅的壁炉这几天一直烧得很旺。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'write_back',
            text: '也给家里写信，说明自己的想法',
            consequence:
                '你写了自己不想回去的理由。写的时候你才发现，你其实已经把这里当成了家的一部分。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_wrote_own_choice'], spirit: 4),
          ),
          StoryChoiceDef(
            id: 'say_nothing',
            text: '不给家里添乱，什么都不说',
            consequence:
                '你把这件事压在心里，谁也没说。从那以后每次收到家里的信，你都只回一句「一切都好」。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_said_nothing']),
          ),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch8_mandrake_progress',
        chapterId: 'cos_ch8',
        timeCostDays: 4,
        setup:
            '学生们的忍耐快到头了，但温室里的事在按另一种节奏走。'
            '你几次路过温室，听见斯普劳特教授在里面隔着布催苗——'
            '「快了，宝贝们，再撑十天半个月。」'
            '复壮剂的原料进度，成了全校最不该外泄又人人想打听的事。',
        ambient: [
          '温室的窗户结着厚厚的白霜，里面的灯光却亮到很晚。',
          '有同学在布帘缝里偷看，被教授拿喷壶浇了一头。',
          '医疗翼的方向偶尔飘来熬制剂的苦味，一天比一天浓。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'help_greenhouse',
            text: '报名温室的杂工，贴着「希望」干活',
            consequence:
                '你负责松土和搬盆，学会了在曼德拉草的哭声里塞耳塞。'
                '斯普劳特教授话不多，但每次都把最粗的活抢过去自己干。'
                '收工时她说：「知道苗在长的人，晚上睡得着。」'
                '你发现她说得对——参与希望，比等待希望好熬得多。',
            effect: StoryEffect(
              addItems: ['曼德拉草叶'],
              setFlags: ['cos_greenhouse_helped'],
              housePoints: 3,
              spirit: 3,
            ),
            nextStepId: 'cos_ch8_greenhouse',),
          StoryChoiceDef(
            id: 'protect_secret',
            text: '把听到的「十天半个月」烂在肚子里，拦住打听的人',
            consequence:
                '有高年级生想套你的话，被你一句「教授让我保密的」顶了回去。'
                '泄露进度只会让绝望再 Deadline 一次——你懂这个道理，'
                '并第一次体会到「守住秘密」也是一种守护。'
                '教授后来听说有人打听，看了你一眼，什么都没说。',
            effect: StoryEffect(
              setFlags: ['cos_kept_greenhouse_secret'],
              reputation: 2,
              spirit: 1,
            ),
            nextStepId: 'cos_ch8_greenhouse',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch8_greenhouse',
        chapterId: 'cos_ch8',
        timeCostDays: 1,
        setup:
            '草药课的温室里，那几盆曼德拉草长得比谁都快。教授说照这个速度，再过几个月就能拿来用了，但没说用来做什么。',
        ambient: [
          '温室的玻璃上全是水汽，看不清外面。',
          '有几盆草在土里扭动，像不想待在原地。',
          '戴耳罩的同学说话都得喊。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'ask_professor',
            text: '问教授这草药到底治什么',
            consequence:
                '教授说「治那种被冻住的人」。你没再问，但你把这句话和走廊里的事连了起来。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['cos_mandrake_cure'], setFlags: ['cos_knows_mandrake_use'], spirit: 2),
          ),
          StoryChoiceDef(
            id: 'tend_plants',
            text: '留下来帮忙给草换盆',
            consequence:
                '你戴着手套忙了一下午。教授走的时候说了句「谢谢」。你手上沾着泥，心里却踏实。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_tended_plants'], housePoints: 5, spirit: 4, targetNpcId: 'hagrid', affection: 2),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第九章 · 情人节与日记（1993 年 2 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'cos_ch9',
    bookId: 'cos',
    ordinal: 9,
    title: '情人节与日记',
    steps: [
      StoryStepDef(
        id: 'cos_ch9_valentine',
        canonRefId: 'canon_cos_quidditch_cancelled',
        chapterId: 'cos_ch9',
        timeCostDays: 6,
        setup:
            '二月十四日，洛克哈特包下整个礼堂搞了一场「情人节庆典」：'
            '粉红色的纸花从天花板飘落，几十个长翅膀的胖矮人抱着竖琴'
            '在桌子间穿行，往任何人面前凑，唱走调的情歌。'
            '恐慌里强行营业的喜庆，荒诞得让人不知道先笑还是先叹。',
        ambient: [
          '一个矮人扯住你的领带（或围巾），唱了一整段跑调的副歌。',
          '粉红色的纸花落在南瓜汁里，捞都来不及。',
          '有同学把矮人雇去给同桌唱歌，全场哄笑——这是几周来第一次有人大笑。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'laugh_along',
            text: '干脆跟着闹——大家已经太久没有笑过了',
            consequence:
                '你花两个纳特雇了个矮人，把情歌唱给了整桌同学。'
                '那顿午饭笑声不断，连隔壁桌绷了一学期的脸都松了。'
                '散场时你发现，恐慌没有消失，但人的力气回来了一点——'
                '笑原来也是一种补给。',
            effect: StoryEffect(
              setFlags: ['cos_valentine_laugh'],
              addItems: ['巧克力蛙'],
              spirit: 4,
              housePoints: 2,
            ),
            nextStepId: 'cos_ch9_lockhart_day',),
          StoryChoiceDef(
            id: 'slip_out',
            text: '趁礼堂都在过节，把无人注意的走廊再查一遍',
            consequence:
                '你溜出礼堂，把平时有人盯着不敢细看的几段走廊走了一遍。'
                '墙上的水渍还在——费尔奇已经不擦了。'
                '二楼盥洗室的门虚掩着，里面传出隐隐的哭声。'
                '你在门口站了几秒，没敢进去，退了出来。',
            requireAnyFlags: ['cos_shielded_firstyear', 'cos_stood_with_bullied', 'cos_observed_scene', 'cos_route_map'],
            effect: StoryEffect(
              addKnowledge: ['cos_myrtle_crying'],
              setFlags: ['cos_checked_corridors'],
              spirit: -2,
            ),
            nextStepId: 'cos_ch9_lockhart_day',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch9_lockhart_day',
        chapterId: 'cos_ch9',
        timeCostDays: 1,
        setup:
            '情人节那天，整个城堡被装饰成了一种让人说不出话的粉色。走廊里飘着一群挎着竖琴的小矮人。',
        ambient: [
          '有人被小矮人拦下当众念情诗，脸涨得通红。',
          '粉色的纸花贴满了柱子和门框。',
          '不少高年级生干脆躲进了图书馆。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'escape_library',
            text: '躲进图书馆，把这一天当成普通日子',
            consequence:
                '图书馆里挤满了和你同样想法的人。你们谁也没说话，但气氛比外面好得多。',
            nextStepId: 'cos_ch9_after_diary',
            effect: StoryEffect(setFlags: ['cos_escaped_valentine'], spirit: 3),
          ),
          StoryChoiceDef(
            id: 'watch_fun',
            text: '站在走廊边上看热闹',
            consequence:
                '你看了三场当众念诗，笑得差点扶不住墙。这一天大概是这个学期最轻松的一天。',
            nextStepId: 'cos_ch9_after_diary',
            effect: StoryEffect(setFlags: ['cos_watched_valentine'], spirit: 5),
          ),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch9_after_diary',
        chapterId: 'cos_ch9',
        timeCostDays: 1,
        setup:
            '那本日记的事传出来之后，整个城堡都在议论那本不起眼的小册子。有人说它是五十年前的东西，也有人说那上面记着当年的事。',
        ambient: [
          '有人在图书馆翻旧年鉴，找五十年前的照片。',
          '走廊里的画像也在讨论这件事。',
          '窗外的天开始放晴，雪化了一半。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'find_yearbook',
            text: '去图书馆翻那一年的年鉴',
            consequence:
                '你找到了那一届的合影。照片里的人都笑着，但有一个人的位置是空的。你把那页记在了心里。',
            nextStepId: '',
            requireAnyFlags: ['cos_read_archive', 'cos_noted_gaps', 'cos_dug_history', 'cos_checked_wall'],
            effect: StoryEffect(addKnowledge: ['cos_knows_old_year'], setFlags: ['cos_found_yearbook'], spirit: 2),
          ),
          StoryChoiceDef(
            id: 'dont_pry',
            text: '不去翻，这种事不该打听',
            consequence:
                '你绕开了图书馆那片区域。但走廊里的议论声还是一路跟着你回了宿舍。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_didnt_pry'], spirit: 1),
          ),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch9_diary',
        chapterId: 'cos_ch9',
        timeCostDays: 11,
        canonRefId: 'canon_cos_diary',
        setup:
            '日记的传闻在这个月成了走廊头条：有人说见过一本「会自己写字」的旧日记，'
            '有人赌咒说它的主人在石化事件前把它丢进了盥洗室。'
            '更多的人在传：「那是继承人的日记。」传闻的真假没人验证得了——'
            '但恐慌需要一个实体，日记恰好出现了。这件事由剧情文本讲述。',
        ambient: [
          '有人在走廊里复述「日记写回了字」的场景，手舞足蹈。',
          '「盥洗室」三个字出现的频率陡然升高，随之而来的是绕路的人流。',
          '图书馆的书页声都比平时轻，像人人都在压着嗓子活着。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'chase_diary',
            text: '把「日记传闻」的每个源头都追一遍',
            consequence:
                '你顺着传闻往回追，追到第三层就断了线：'
                '每个人都说「听别人说的」。唯一确定的是——'
                '传闻里的时间线对得上：那本日记据说出现在第一起石化之前。'
                '你把「盥洗室」「日记」「五十年前」三个词写在一行，看了很久。',
            requireAnyFlags: ['cos_visited_hospital', 'cos_organized_rumors', 'cos_dug_history', 'cos_reported_pattern'],
            effect: StoryEffect(
              addKnowledge: ['cos_diary_timeline'],
              setFlags: ['cos_chased_diary', 'cos_kept_chasing'],
              spirit: -2,
              reputation: 1,
            ),
          ),
          StoryChoiceDef(
            id: 'stay_sane',
            text: '不追传闻——越接近考试，越不能被恐慌牵着走',
            consequence:
                '你把传闻关在门外，按考试周期排好了复习表。'
                '斯普劳特教授在温室里宣布「曼德拉草长出了第一批成叶」——'
                '这是几周来第一个真正的好消息。你看向那排盖布的盆栽，'
                '第一次觉得「希望」原来有叶子。',
            effect: StoryEffect(
              addItems: ['曼德拉草叶'],
              setFlags: ['cos_stayed_sane'],
              housePoints: 3,
              spirit: 3,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第十章 · 三月：最冷的春天（1993 年 3 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'cos_ch10',
    bookId: 'cos',
    ordinal: 10,
    title: '最冷的春天',
    steps: [
      StoryStepDef(
        id: 'cos_ch10_library',
        chapterId: 'cos_ch10',
        timeCostDays: 30,
        canonRefId: 'canon_cos_hermione_petrified',
        setup:
            '三月的第一次警报来自图书馆：两名学生被石化，'
            '其中一个是人人认识的「图书馆常驻」。抬走她时，'
            '手里那张从书页里撕下来的纸条被教授收走了——'
            '但「纸条上写着一个与蛇有关的词」这句话，当天就传遍了全校。'
            '这件事由剧情文本讲述。',
        ambient: [
          '图书馆部分区域被丝绒绳拦起，平斯夫人守在绳边不让人靠近。',
          '走廊里第一次有人公开说「我要退学」。',
          '猫头鹰棚屋的信件比一月时更多、更急。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'piece_clue',
            text: '把「蛇」和「水管」两个词放到一起想',
            consequence:
                '蛇——密室的怪物；水管——城堡的底下。'
                '你在笔记上画了半张城堡的管线草图，越画越冷：'
                '如果它能在全城堡的管道里穿行，那任何水槽、任何盥洗室都是口子。'
                '你没有把这张图给任何人看，只是把它锁进了箱底。',
            requireAnyFlags: ['cos_knows_mandrake_use', 'cos_dug_history', 'cos_organized_rumors', 'cos_reported_pattern'],
            effect: StoryEffect(
              addKnowledge: ['cos_pipe_theory'],
              setFlags: ['cos_piece_clue', 'cos_kept_chasing'],
              spirit: -3,
              reputation: 1,
            ),
            nextStepId: 'cos_ch10_study_hard',),
          StoryChoiceDef(
            id: 'grieve_hermione',
            text: '去医疗翼外放下一朵花，为被石化的人守一刻钟',
            consequence:
                '医疗翼的走廊里陆续出现了别人放的小东西：糖纸、折纸、字条。'
                '你放了一朵从温室要来的小花，站了一刻钟。'
                '庞弗雷夫人出来给花换了水，看见你，点了点头。'
                '恐惧里，这种安静的仪式让人的心没有散。',
            effect: StoryEffect(
              setFlags: ['cos_grieved_hospital'],
              affection: 2,
              spirit: 1,
              reputation: 2,
            ),
            nextStepId: 'cos_ch10_study_hard',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch10_study_hard',
        canonRefId: 'canon_cos_mandrake',
        chapterId: 'cos_ch10',
        timeCostDays: 1,
        setup:
            '三月的图书馆比平时任何时候都挤。期末考临近，而整个学期有大半时间都没能正常上课。',
        ambient: [
          '有人在借参考书，书架前围了一圈。',
          '有几个毕业班的学生占着最里面的位子不放。',
          '窗外开始回暖，玻璃上的霜没了。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'study_group',
            text: '和几个人组个小组，互相补进度',
            consequence:
                '你们四个人把落下的内容分了工。每个人讲一章，讲到不懂的地方就一起翻书。这种学法比一个人啃快多了。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_group_study'], housePoints: 5, spirit: 4, targetNpcId: 'hermione', affection: 3),
          ),
          StoryChoiceDef(
            id: 'solo_grind',
            text: '自己一个人啃，按自己的进度来',
            consequence:
                '你每天泡在图书馆到闭馆。进度慢，但每一步都扎实。你把所有没弄懂的地方都列了出来。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_solo_study'], housePoints: 5, spirit: 3),
          ),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch10_leave_or_stay',
        chapterId: 'cos_ch10',
        timeCostDays: 13,
        setup:
            '家长的联名信把校董会惊动了。「停学」的传闻一天一个版本。'
            '有几个同学被接走了，行李箱轮子的声音再一次响遍走廊。'
            '留守的人越来越少，班级合照上的空位越来越多。'
            '轮到你的家信摆在你面前——信里问了你的意思。',
        ambient: [
          '公共休息室的炉火烧得很旺，人却越来越少。',
          '有人的座位空了一周，课本还摊在原处。',
          '走廊的灯亮得比往年久——校方在用灯光对抗恐惧。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'reply_stay',
            text: '回信：我留下。城堡需要每一个留下的人',
            consequence:
                '你的回信只有半页：这里没有外面传得那么可怕，'
                '巡逻有安排，教授们都在，我留下能帮上忙。'
                '落款之后你想了很久，又添了一句：'
                '「如果人人都走，城堡才真的会输。」',
            effect: StoryEffect(
              setFlags: ['cos_stay_decision', 'cos_stayed_at_school'],
              spirit: 2,
              reputation: 3,
              housePoints: 3,
            ),
            nextStepId: 'cos_ch10_stay_question',),
          StoryChoiceDef(
            id: 'reply_home',
            text: '回信：我先回家，等一切平息再回来',
            consequence:
                '你把行李打包，在同窗们的注视里下了马车。'
                '家里的日子安稳得近乎失真：没有封锁的走廊，没有结伴名单。'
                '你每天翻报纸找霍格沃茨的消息，剪下来贴成了一叠。'
                '你比任何时候都清楚：你在躲，但你的心还留在那里。',
            effect: StoryEffect(
              setFlags: ['cos_leave_decision', 'cos_left_school'],
              spirit: 1,
              reputation: -2,
            ),
            nextStepId: 'cos_ch10_stay_question',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch10_stay_question',
        chapterId: 'cos_ch10',
        timeCostDays: 1,
        setup:
            '「要不要离开学校」这个问题在宿舍里被讨论了整整一晚。有人说家里已经买好了回程票。',
        ambient: [
          '宿舍的地板上摊着几个打开的箱子。',
          '有人在窗边坐着不说话。',
          '炉火没人添，慢慢暗下去了。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'argue_stay',
            text: '跟他们说，现在走反而更乱',
            consequence:
                '你说了你的想法：这里至少有老师在，路上的几周反而没人护着。有人被说服了，有人没有。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_argued_stay'], reputation: 2, spirit: 2),
          ),
          StoryChoiceDef(
            id: 'respect_choice',
            text: '不劝，每个人的家里情况不一样',
            consequence:
                '你帮要走的同学收拾了行李，一直送到门厅。回来的时候宿舍空了一半。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_respected_choice'], spirit: -1),
          ),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch10_exam_cloud',
        canonRefId: 'canon_cos_staff_meetings',
        chapterId: 'cos_ch10',
        timeCostDays: 9,
        setup:
            '「期末考可能取消」的传闻和「学校可能提前关」的传闻一起飞。'
            '二年级的魔咒课改成了自习，代课的教授照本宣科，'
            '教室后排的空位越来越多。你面前有两个选择都沉甸甸的：'
            '把课业放下，或者把课业抓得更紧。',
        ambient: [
          '自习课的教室安静得能听见雪落。',
          '黑板上的课程表被改了又改，改到没人再看。',
          '有个同学把书包原封不动背回家又背回来，一周三次。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'keep_exam_rhythm',
            text: '不管取消不取消，按考试日程复习',
            consequence:
                '你给自己排的复习表一天没断。魔咒课的自习上，'
                '开始只有你一个人在练发音，第二周变成了四个人，'
                '第三周后排都坐满了——恐慌偷走的东西，节奏能一点点还回来。'
                '期末考最后真的取消了，但你没觉得白练。',
            effect: StoryEffect(
              setFlags: ['cos_kept_exam_rhythm'],
              housePoints: 4,
              spirit: 3,
            ),
            nextStepId: 'cos_ch10_prep',),
          StoryChoiceDef(
            id: 'teach_firstyear',
            text: '把自习课变成「二年级辅导一年级」的课堂',
            consequence:
                '你征得代课教授同意，把一年级的娃们分了组：'
                '漂浮咒组、火苗组、变形入门组，二年级生一人带一组。'
                '教室里第一次有了声音。散课时一个一年级的小姑娘说：'
                '「上你们的课，就忘了害怕了。」',
            requireAnyFlags: ['cos_greenhouse_helped', 'cos_knows_mandrake_use', 'cos_helped_juniors', 'cos_tended_plants'],
            effect: StoryEffect(
              setFlags: ['cos_taught_firstyear', 'cos_helped_juniors'],
              reputation: 4,
              housePoints: 4,
              spirit: 2,
            ),
            nextStepId: 'cos_ch10_prep',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch10_prep',
        chapterId: 'cos_ch10',
        timeCostDays: 1,
        setup:
            '考试到底会不会照常举行，没有人给得出准确答复。课表改了一次又一次，公告栏上的通知换了一版又一版，你还是决定按「会考」来准备。',
        ambient: [
          '课表上的课被取消了几节，又补了几节。',
          '教授们的脸色一天比一天严肃。',
          '公告栏上多了一张又一张通知。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'prepare_anyway',
            text: '不管考不考，都按计划复习',
            consequence:
                '你把三本课本从头到尾过了一遍。就算最后不考，这些知识以后也用得上。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['cos_solid_basics'], setFlags: ['cos_prepared_anyway'], spirit: 3),
          ),
          StoryChoiceDef(
            id: 'follow_updates',
            text: '每天去公告栏看有没有新消息',
            consequence:
                '你养成了每天看通知的习惯。虽然大部分通知都跟你没关系，但至少你不会错过重要的那些。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['cos_knows_notices'], setFlags: ['cos_followed_updates'], spirit: 2),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第十一章 · 封校（1993 年 4-5 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'cos_ch11',
    bookId: 'cos',
    ordinal: 11,
    title: '封校的日子',
    steps: [
      StoryStepDef(
        id: 'cos_ch11_recall',
        chapterId: 'cos_ch11',
        timeCostDays: 16,
        setup:
            '五月中旬，一封校方的正式信件寄到每个离校学生手里：'
            '学年结束宴照常举行，石化事件「已获重大进展」，'
            '请全体学生于五月末前返校。你在家里坐不住了——'
            '收拾行李的速度连你自己都吃惊。',
        ambient: [
          '返校的马车上坐满了同一批当初离开的人，谁都不太敢对视。',
          '城堡的大门敞开着，门柱上的石兽像是松了一口气。',
          '礼堂的长桌重新坐满那天，盘子的碰撞声都显得如释重负。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'return_eager',
            text: '提前两天返校，把落下的每一堂课补齐',
            consequence:
                '你提前回了学校，把离校期间的笔记借了个遍，'
                '一个星期补完了半学期的功课。'
                '同桌看你的眼神从惊讶变成了佩服。'
                '逃开过一次的人才明白：能回来按时上课，本身就是一种奢侈。',
            requireAnyFlags: ['cos_honest_letter', 'cos_wrote_own_choice', 'cos_helped_juniors', 'cos_taught_firstyear'],
            effect: StoryEffect(
              setFlags: ['cos_returned_early'],
              housePoints: 3,
              spirit: 3,
            ),
            nextStepId: 'cos_ch11_rumor_final',),
          StoryChoiceDef(
            id: 'return_quiet',
            text: '按信上的日子返校，先把校方说的「重大进展」打听清楚',
            consequence:
                '返校第一晚你就拉住了巡逻的级长：「重大进展是什么？」'
                '级长左右看了看，压低声音：「曼德拉草快成了，医疗翼在赶制复壮剂。'
                '还有——听说那个开密室的人，快藏不住了。」'
                '你把这两句话拆开揉碎想了一整晚。',
            effect: StoryEffect(
              addKnowledge: ['cos_mandrake_ready', 'cos_progress_rumor'],
              setFlags: ['cos_asked_progress'],
              spirit: 2,
            ),
            nextStepId: 'cos_ch11_rumor_final',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch11_rumor_final',
        chapterId: 'cos_ch11',
        timeCostDays: 1,
        setup:
            '学期被一再延长，走廊里的消息一天比一天紧。有人说已经找到了那间密室的入口，也有人说还差得远。真真假假，没人分得清。',
        ambient: [
          '有几个教工整天不见人影。',
          '走廊里的水渍又出现了，位置和上次一样。',
          '晚上点名比以前早了一个小时。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'track_water',
            text: '留意那些水渍，记下出现的位置',
            consequence:
                '你在三处地方做了记号。三天之后你去检查，有两处已经干了，一处的痕迹还在扩大。这个发现你只告诉了最信得过的一个人。',
            nextStepId: '',
            requireAnyFlags: ['cos_route_map', 'cos_checked_wall', 'cos_found_detour', 'cos_noted_gaps'],
            effect: StoryEffect(addKnowledge: ['cos_water_pattern'], setFlags: ['cos_tracked_water'], spirit: 2),
          ),
          StoryChoiceDef(
            id: 'wait_orders',
            text: '不自己去查，等学校的安排',
            consequence:
                '你每天照常上课、照常回宿舍。你觉得这种事应该交给大人处理——虽然你也不确定他们处理得怎么样。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_waited_orders'], spirit: 1),
          ),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch11_final_night',
        canonRefId: 'canon_cos_special_lessons',
        chapterId: 'cos_ch11',
        timeCostDays: 15,
        setup:
            '六月前的一个深夜，你被一阵急促的敲门声和魔杖的灯光弄醒——'
            '所有学生被要求立刻到各自的公共休息室集合，不许外出，不许回寝室。'
            '没有人解释发生了什么。走廊深处传来很多人奔跑的脚步声，'
            '然后，是一段长得可怕的寂静。',
        ambient: [
          '公共休息室的炉火被拨旺了，几十张脸在火光里面面相觑。',
          '有人小声数着走廊里的脚步声，数到一半就不数了。',
          '窗外的天一点一点亮起来，谁都没有睡。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'calm_juniors',
            text: '把休息室里的低年级组织起来，讲不太吓人的故事等天亮',
            consequence:
                '你让一二年级的孩子们围坐在炉火边，'
                '把假期里雪仗的段子翻出来讲，讲到连高年级都在偷听。'
                '天亮时，最小的那个孩子靠着你睡着了。'
                '多年以后他们会忘掉恐惧，但会记得那一晚有人让他们笑过。',
            effect: StoryEffect(
              setFlags: ['cos_calm_night', 'cos_helped_juniors'],
              reputation: 5,
              housePoints: 4,
              spirit: -1,
            ),
            nextStepId: 'cos_ch11_longest_night',),
          StoryChoiceDef(
            id: 'listen_facts',
            text: '竖起耳朵，把这一夜听到的只言片语全部记下来',
            consequence:
                '「蛇」「水管」「好深」「活不了了」「教授下去了」——'
                '你把传进休息室的每个词都记在纸上。'
                '天亮后对照你三月的管线草图，手开始抖：'
                '他们下去的方向，和你猜的一样。',
            effect: StoryEffect(
              addKnowledge: ['cos_final_night_notes'],
              setFlags: ['cos_listened_night', 'cos_kept_chasing'],
              spirit: -3,
              reputation: 2,
            ),
            nextStepId: 'cos_ch11_longest_night',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch11_longest_night',
        chapterId: 'cos_ch11',
        timeCostDays: 1,
        setup:
            '那个晚上，整座城堡的灯都亮着。低年级生被集中在公共休息室里，有人说「今晚谁都别乱走」。',
        ambient: [
          '休息室的门被从里面闩上了。',
          '有人带来了毯子和饼干，分给大家。',
          '有低年级生一直在哭，被人搂着。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'reassure',
            text: '把饼干分给最小的那几个，陪他们说话',
            consequence:
                '你讲了几个自己编的故事，讲得磕磕巴巴，但他们都听着。有个小姑娘后来靠在你肩上睡着了。',
            nextStepId: '',
            requireAnyFlags: ['cos_visited_hospital', 'cos_helped_juniors', 'cos_made_buddy', 'cos_organized_pairs'],
            effect: StoryEffect(setFlags: ['cos_reassured_young'], reputation: 2, spirit: 3),
          ),
          StoryChoiceDef(
            id: 'keep_vigil',
            text: '坐在门边，一晚上没合眼',
            consequence:
                '你听着走廊里来来回回的脚步声。有几次你以为门要被推开了。天亮的时候，你的眼睛又酸又干。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_kept_vigil'], spirit: -1),
          ),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch11_exam_cancel',
        chapterId: 'cos_ch11',
        timeCostDays: 10,
        setup:
            '校方正式通知：期末考试取消。公告贴出来时，'
            '所有人先是安静，然后爆发出的不是欢呼，而是一片叹息——'
            '连「考试」这样普通的麻烦都被没收了，说明事态比传的更重。'
            '城堡第一次让人觉得，正常生活本身是一种需要去争的东西。',
        ambient: [
          '公告板前站了满满一圈人，没一个人笑。',
          '有教授在走廊里说「至少把魔咒课的实操考了」，语气像在恳求。',
          '晚饭的礼堂比平时亮，像校方想用光把士气撑住。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'petition_exam',
            text: '和同学联名向校方请愿：考可以简化，但不能没有',
            consequence:
                '请愿书收集了四十七个签名。一周后校方回了话：'
                '「实操考核照常，笔试减免。」消息传开那天，'
                '城堡里的气氛是四月以来最好的一天——'
                '不是因为这个决定多重要，而是它证明请愿有用。'
                '你的名字在请愿书第一行。',
            effect: StoryEffect(
              setFlags: ['cos_petitioned_exam'],
              reputation: 5,
              housePoints: 4,
              spirit: 3,
            ),
            nextStepId: 'cos_ch11_aftermath_day',),
          StoryChoiceDef(
            id: 'accept_and_rest',
            text: '接受取消，把攒了一年的疲惫还给自己',
            consequence:
                '你睡了几个学期以来最沉的觉，白天去湖边看巨乌贼冒泡，'
                '把这一年紧绷的东西一件件放下来。'
                '恢复不是逃避——城堡要站到六月，靠的不是绷断的弦。'
                '假期般的半个月后，你比谁都稳。',
            effect: StoryEffect(
              setFlags: ['cos_rest_and_recover'],
              spirit: 5,
              reputation: -1,
            ),
            nextStepId: 'cos_ch11_aftermath_day',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch11_aftermath_day',
        chapterId: 'cos_ch11',
        timeCostDays: 1,
        setup:
            '第二天早上，消息传过来：事情解决了，被抓走的人也被送回来了。考试的安排改了，又改回去。',
        ambient: [
          '食堂里重新有了笑声，但声音还小。',
          '有人抱着一摞书在走廊里跑，被级长叫住了。',
          '窗外是四月的太阳，很亮。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'visit_medical',
            text: '去医疗翼外面看看那些人',
            consequence:
                '你没能进去，但你在门口站了一会儿。出来的人脸色还白，但能走路。你远远地朝其中一个人点了点头。',
            nextStepId: '',
            requireAnyFlags: ['cos_visited_hospital', 'cos_grieved_hospital', 'cos_made_buddy', 'cos_dug_history'],
            effect: StoryEffect(setFlags: ['cos_visited_medical'], reputation: 1, spirit: 3),
          ),
          StoryChoiceDef(
            id: 'back_to_class',
            text: '回教室，把落下的课一节节补回来',
            consequence:
                '你重新坐回教室里，把课本一页页翻开。窗外的阳光照在纸面上，比前几个月任何时候都要暖。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_back_to_class'], housePoints: 5, spirit: 3),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第十二章 · 学年结束宴（1993 年 6 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'cos_ch12',
    bookId: 'cos',
    ordinal: 12,
    title: '学年结束宴',
    steps: [
      StoryStepDef(
        id: 'cos_ch12_wake',
        chapterId: 'cos_ch12',
        timeCostDays: 10,
        setup:
            '消息像解冻的春水一样涌开：被石化的人全部醒了，'
            '第一个醒来的那个「图书馆常驻」，醒来第一句话是问书还了没有。'
            '密室的怪物死了——被一把银色的剑刺穿；'
            '打开密室的「继承人」查明了，传闻里的日记是元凶之一。'
            '你听了整整一天，把这些和自己的笔记一一对照——几乎全对上了。',
        ambient: [
          '医疗翼的走廊里，苏醒的学生被围了一层又一层。',
          '有人在楼梯上大喊「结束了」，被教授瞪了一眼，喊声变成笑声。',
          '你的笔记摊在桌上，画满勾和叉，最后一页写着两个字：对上了。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'share_notes',
            text: '把自己这一年的记录整理出来，交给信任的教授',
            consequence:
                '你把笔记誊清了十一页，从血字的位置到管线的猜测，'
                '连同三个词的推理一并交了上去。'
                '麦格教授翻完沉默了很久，最后只说了一句：'
                '「二年级……有心了。」'
                '她把笔记收进了自己的公文包，而不是丢进抽屉。',
            requireAnyFlags: ['cos_learned_disarming', 'cos_piece_clue', 'cos_organized_rumors', 'cos_group_study'],
            effect: StoryEffect(
              setFlags: ['cos_shared_notes', 'cos_kept_chasing'],
              reputation: 5,
              housePoints: 5,
              spirit: 3,
            ),
            nextStepId: 'cos_ch12_sunlight',),
          StoryChoiceDef(
            id: 'visit_hermione',
            text: '去医疗翼，把这一年没说出口的话对苏醒的人说',
            consequence:
                '病床边你组织了半天语言，最后只说出一句：'
                '「欢迎回来。」对方虚弱地笑：「听说你把走廊管得很好。」'
                '你们聊了一下午。有些并肩，不需要在同一间教室里。',
            effect: StoryEffect(
              setFlags: ['cos_welcomed_back'],
              affection: 4,
              reputation: 2,
              spirit: 3,
            ),
            nextStepId: 'cos_ch12_sunlight',),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch12_sunlight',
        chapterId: 'cos_ch12',
        timeCostDays: 1,
        setup:
            '学年结束前的最后几周，天气好得反常。所有人都往户外跑，草坪上、湖边、门前的石阶上都是人，像要把关在屋子里的大半年一口气补回来。',
        ambient: [
          '草坪上到处是摊开的课本和毯子。',
          '有人在湖边钓鱼，一条也没钓上来。',
          '城堡的影子在草地上慢慢移动。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'outdoor_study',
            text: '把复习搬到草坪上，边晒太阳边看书',
            consequence:
                '你看了半页就睡着了。醒过来的时候书还摊在胸口，旁边的人正拿草叶逗你。',
            nextStepId: 'cos_ch12_lastlook',
            effect: StoryEffect(setFlags: ['cos_outdoor_nap'], spirit: 6),
          ),
          StoryChoiceDef(
            id: 'play_quidditch',
            text: '和几个人踢一场随意的小球赛',
            consequence:
                '你们用一只旧手套当球，在草地上追着跑了一下午。最后谁也没记住比分，只记住了谁笑得最响。',
            nextStepId: 'cos_ch12_lastlook',
            effect: StoryEffect(setFlags: ['cos_played_outside'], spirit: 6, targetNpcId: 'ron', affection: 2),
          ),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch12_lastlook',
        chapterId: 'cos_ch12',
        timeCostDays: 1,
        setup:
            '离开城堡前的最后一个早上，你起得比平时早，绕着熟悉的那几条走廊多走了一圈，把每一处都看了一遍。',
        ambient: [
          '画像们有的在道别，有的装作没看见。',
          '行李箱已经堆在门厅了。',
          '窗外的火车冒着白烟等在站台上。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'say_goodbye',
            text: '跟几个这一年帮过你的人道个别',
            consequence:
                '你一个个找到他们，说了谢谢。有的人愣了一下，有的人笑着说「明年见」。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_said_goodbye'], reputation: 2, spirit: 6),
          ),
          StoryChoiceDef(
            id: 'walk_alone',
            text: '一个人把走廊走完，什么都不说',
            consequence:
                '你从一楼走到七楼，又走回来。每层楼你都停了一会儿。这一年在你的记忆里，比去年长得多。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['cos_walked_alone'], spirit: 5),
          ),
        ],
      ),
      StoryStepDef(
        id: 'cos_ch12_feast',
        chapterId: 'cos_ch12',
        timeCostDays: 10,
        canonRefId: 'canon_cos_resolved',
        setup:
            '学年结束宴如期而至。大礼堂的横幅换了新的，'
            '被恐惧压了一整年的学生把这一顿饭吃出了节日的味道。'
            '校长的年度致辞很短，最后他说：'
            '「这一年，让霍格沃茨站住的，不只是教授——是每一个没有散开的你们。」'
            '学院杯的分数在掌声里揭晓。这件事由剧情文本讲述。',
        ambient: [
          '礼堂的金盘子里堆满了食物，没有人急着动叉子，都在听。',
          '你身边的每张脸都被烛光照得暖暖的，一年里的第一次。',
          '行李已经收拾好放在寝室，明天的马车会把所有人送回夏天。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'raise_goblet',
            text: '举起杯子，敬这所学校和没有走散的人',
            consequence:
                '你站起来举杯，同桌们一个接一个跟着站起来。'
                '校长隔着长桌朝你们这一桌微微颔首。'
                '杯里的南瓜汁晃出细小的光。这一年你失去过安稳，'
                '换来了说不出口的东西——比如在恐惧里不散掉的勇气。',
            effect: StoryEffect(
              setFlags: ['cos_raised_goblet'],
              spirit: 5,
              reputation: 3,
              housePoints: 3,
            ),
          ),
          StoryChoiceDef(
            id: 'quiet_thanks',
            text: '安静地吃完这顿饭，把纪念收好',
            consequence:
                '你没有举杯，只是安安静静把整顿饭吃完，'
                '把蛇怪死后校方发的纪念徽章收进了内袋。'
                '散场时你回头看了一眼大礼堂——'
                '有些告别不需要声音，心里有回音就够了。',
            effect: StoryEffect(
              setFlags: ['cos_quiet_feast'],
              addItems: ['蛇的毒牙'],
              spirit: 3,
              housePoints: 2,
            ),
          ),
        ],
      ),
    ],
  ),
];

/// 《密室》结局规则（顺序即优先级）。
///
/// 数值口径：36 步里 positive reputation 合计约 +33、housePoints 约 +30、
/// affection 约 +22——门槛都设在这些上限的一半以下，保证可达。
const List<StoryEndingRule> _cosEndings = [
  StoryEndingRule(
    id: 'cos_ending_lighthouse',
    title: '城堡的灯',
    body:
        '这一年最冷的三月，你没有走；封校的那一夜，你让最小的孩子笑着等到天亮。'
        '学年结束宴后，好几个高年级生在与你道别时用了同一个说法：'
        '「走廊里有你，就不那么黑。」'
        '恐惧没有放过霍格沃茨，但也没能吃掉它——因为有人把自己当成了灯。',
    requireFlags: ['cos_stayed_at_school', 'cos_helped_juniors'],
    minAffectionTotal: 12,
    minReputation: 12,
  ),
  StoryEndingRule(
    id: 'cos_ending_detective',
    title: '把真相拼出来的人',
    body:
        '你的笔记没有抓到凶手，但它的每一页都写满了「不肯转身逃走」。'
        '教授收下那十一页纸的时候说的那句话，你记了很多年——'
        '「二年级……有心了。」'
        '真相由更强的人终结，但你证明了：普通人盯着它看，它就会露馅。',
    requireFlags: ['cos_kept_chasing', 'cos_shared_notes'],
    minReputation: 10,
  ),
  StoryEndingRule(
    id: 'cos_ending_heart',
    title: '有人身边的那个人',
    body:
        '这一年你做的每一件事都不惊天动地：护住发抖的新生、陪吓哭的同学吃完饭、'
        '在医疗翼外放一朵花。可正是这些小事让恐慌没能把人心打散。'
        '散伙的马车上，好几个人和你约好：三年级，还坐同一节车厢。',
    requireAnyFlags: [
      'cos_shielded_firstyear',
      'cos_comforted_friend',
      'cos_welcomed_back',
    ],
    minAffectionTotal: 8,
  ),
  StoryEndingRule(
    id: 'cos_ending_survivor',
    title: '平安的二年级',
    body:
        '你按时上课、按时巡逻、按时考试，在传闻和恐惧的缝隙里把日子过得踏实。'
        '学年结束宴上你举起杯，敬这所学校——'
        '它又熬过了一年，你也一样。',
    minReputation: 1,
  ),
  StoryEndingRule(
    id: 'cos_ending_distant',
    title: '提前退场的人',
    body:
        '三月你上了回家的马车，五月的返校信才把你带回城堡。'
        '真相、苏醒与宴会你都赶上了尾巴，却总觉得隔着一层玻璃。'
        '你在心里记下一句话：下一次城堡再出事，你不走了。',
  ),
];

const StoryBookDef _chamberOfSecrets = StoryBookDef(
  id: 'cos',
  title: '密室',
  chapters: _cosChapters,
  endings: _cosEndings,
  startYear: 1992,
  startMonth: 7,
  startDay: 25,
);

/// 注册全部剧情书。
///
/// 【为什么用函数而不是顶层 const 列表】`kStoryBooks` 定义在
/// `models/story_progress.dart`（纯函数层），而书表定义在这里（内容层）。
/// 顶层注册会在 import 时就生效，但那样"注册"这件事就不可测了——
/// 用 `void registerAllStoryBooks()` 让测试可以显式调用、也可断言幂等。
void registerAllStoryBooks() {
  registerStoryBook(_philosophersStone);
  registerStoryBook(_chamberOfSecrets);
  registerStoryBook(prisonerOfAzkaban);
  registerStoryBook(gobletOfFire);
  registerStoryBook(orderOfThePhoenix);
  registerStoryBook(halfBloodPrince);
  registerStoryBook(deathlyHallows);
}
