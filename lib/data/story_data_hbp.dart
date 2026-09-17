/// 《混血王子》1996-1997 · 六年级 · 剧情内容表
///
/// 【这一部的气质】六年级是七年里最像"普通校园生活"的一年——
/// 有成绩单、有派对、有魁地奇、有人在走廊里递纸条。
/// 但也正因为如此，它结束得格外突然：
/// 上半学年所有人都在过日子，下半学年某个夜里塔顶升起一道绿光，
/// 第二天早上学校就不再是原来那所学校了。
/// 这一部的叙事张力全部来自**落差**：先给你一段难得的平静，再收走它。
///
/// 【与哈利线的边界】拿到那本旧课本的是他，跟校长上记忆课的也是他，
/// 在塔上做出那个决定的同样是他。玩家的位置是：
/// 借过那本书的抄本、在门口等过那节课、在走廊里挡过那几十秒。
/// "捷径"这道题对玩家同样成立——因为每个人都会遇到一本
/// 写满别人答案的旧书。
///
/// 【原著节点覆盖】canon_hbp_return / canon_hbp_malfoy_task /
/// canon_hbp_potions_book / canon_hbp_astronomy_tower 四个节点各由一步剧情讲述。
library;

import 'package:hogwarts_life_simulator/models/story_progress.dart';

// ================================================================
// 《混血王子》 1996-1997 · 六年级
//
// 【时间线】1996-07-25 开启锚点 → 1997-07 学年提前结束。
// 37 步 × 平均 9.9 天 ≈ 365 天，与 canon_hbp_* 节点的月份逐一对齐：
//   09 返校 / 10 不安 / 11 旧课本 / 12-02 冬 / 03-05 记忆与传闻 / 06 天文塔
//
// 【密度补强】原为 28 步，是七部里最薄的一部。补入 9 个"旁观者视角"的
// 场景步（对角巷的货架、走廊上的擦肩、新教授的第一堂课、斯拉格霍恩的
// 晚宴、圣诞前的霍格莫德、图书馆被撕掉的那几页、那一夜锁上的门、
// 之后的早晨、最后的早餐），把"一个人的堕落"从 3 个大步摊成可感知的
// 若干次擦肩——玩家看不见阴谋，只看得出行为的变化。
// ================================================================

const List<StoryChapterDef> _hbpChapters = [
  // --------------------------------------------------------------
  // 第一章 · 六年级开学（1996 年 9 月）→ canon_hbp_return
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'hbp_ch1',
    bookId: 'hbp',
    ordinal: 1,
    title: '六年级开学',
    steps: [
      StoryStepDef(
        id: 'hbp_ch1_return',
        chapterId: 'hbp_ch1',
        timeCostDays: 52,
        onEnterText:
            '—— 第 6 部 · 混血王子 ——\n'
            '六年级。N.E.W.T. 年。'
            '站台上的人比往年多，只是多出来的那部分不是来送行的。',
        setup:
            '国王十字车站的九又四分之三站台今年多了一排穿斗篷的傲罗，'
            '他们不拦人，只是站在柱子旁边看着。'
            '有家长抱着孩子说了很久才松手，也有几个行李箱孤零零靠在墙根，'
            '主人始终没有出现。',
        ambient: [
          '蒸汽把月台的灯熏成一圈一圈的黄。',
          '你听见有人低声说"今年可能有人不会回来了"。',
          '一只猫头鹰在笼子里撞了两下，又安静下来。',
        ],
        canonRefId: 'canon_hbp_return',
        choices: [
          StoryChoiceDef(
            id: 'count_aurors',
            text: '数一数站台上有几个傲罗、站在哪几个位置',
            consequence:
                '你数了七个，两两一组，把住了三个出口。'
                '你把这个数字记在了心里——'
                '上一次有人这么认真地守着这站台，你还没出生。',
            effect: StoryEffect(
              addKnowledge: ['hbp_platform_watch'],
              setFlags: ['hbp_train_alert'],
              spirit: -1,
            ),
            nextStepId: 'hbp_ch1_results',),
          StoryChoiceDef(
            id: 'help_luggage',
            text: '帮旁边那个够不着行李架的一年级生把箱子塞上去',
            consequence:
                '你帮他把箱子塞了上去，他连说了三遍谢谢。'
                '隔着车窗，他母亲朝你点了点头——'
                '这个点头让你在整个暑假后的第一天，心情好了很多。',
            effect: StoryEffect(
              setFlags: ['hbp_train_kind'],
              addKnowledge: ['hbp_first_year_name'],
              reputation: 2,
              spirit: 2,
              targetNpcId: 'colin',
            ),
            nextStepId: 'hbp_ch1_results',),
          StoryChoiceDef(
            id: 'read_notice',
            text: '翻一翻随通知书寄来的那张安全须知',
            consequence:
                '须知一共四条，措辞客气，'
                '但每一条都在说同一件事：今年请待在人多的地方。'
                '你把纸折好夹进书里，没有跟同车厢的人提起。',
            effect: StoryEffect(
              addItems: ['计划书'],
              addKnowledge: ['hbp_safety_notice'],
              setFlags: ['hbp_train_notice'],
              spirit: -1,
            ),
            nextStepId: 'hbp_ch1_results',),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch1_results',
        canonRefId: 'canon_hbp_newts',
        chapterId: 'hbp_ch1',
        timeCostDays: 1,
        setup:
            '成绩单寄到的那天，你拆信封的手有点抖。结果比预想的好一些，也没好到能吹的程度。你把信封翻过来又看了一遍，才收进抽屉。',
        ambient: [
          '有人的成绩单掉在地上，捡起来看了一遍又一遍。',
          '窗外有猫头鹰在等回信。',
          '走廊里到处在比分数。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'celebrate_small',
            text: '不管别人怎么样，先给自己庆祝一下',
            consequence:
                '你去厨房要了块蛋糕，一个人吃完了。没有告诉任何人为什么。有些小小的胜利，本来就只该自己知道。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['hbp_celebrated_self'], spirit: 5),
          ),
          StoryChoiceDef(
            id: 'check_others',
            text: '先去看看几个朋友考得怎么样',
            consequence:
                '你挨个问了一圈。有人考砸了，你陪他在外面走了一小时。回宿舍的时候你才想起自己的成绩单还在口袋里。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['hbp_checked_friends'], reputation: 2, spirit: 2, targetNpcId: 'ron', affection: 2),
          ),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch1_diagon',
        chapterId: 'hbp_ch1',
        timeCostDays: 5,
        setup:
            '开学前最后一次去对角巷，你最先注意到的是货架。'
            '几家店的东西摆得比往年稀，有的位置干脆空着，'
            '也没人补。店主人站在柜台后面，看起来不太想说话。'
            '街上的大人走得比平时快。',
        ambient: [
          '摩金夫人长袍店门口排了很短的队，往年这里要排到街角。',
          '有人在看报纸，看完把报纸折起来塞进了口袋，没有丢进回收桶。',
          '古灵阁的白台阶上人流不断，每个人进去的时候都拎着东西。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'ask_shopkeeper',
            text: '问问店主人今年怎么了',
            consequence:
                '他犹豫了一下，说"货不好进"——就这三个字，'
                '然后把一摞旧袍子往你面前推，问你要不要改。'
                '你买了，他多送了你一副手套。'
                '整条街上，只有他一个人愿意多说了半句话。',
            effect: StoryEffect(
              addKnowledge: ['hbp_supply_shortage'],
              setFlags: ['hbp_asked_adults'],
              housePoints: 2,
              affection: 2,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'read_the_paper',
            text: '把报纸上那几条读一遍',
            consequence:
                '你读了。前面的几版还是老样子，'
                '翻到里面才发现有几条很短的消息，'
                '讲的是某处出事、某人失踪，每条都只有三行。'
                '你把这一天记住了——后来你才知道那是开始。',
            effect: StoryEffect(
              addKnowledge: ['hbp_early_news'],
              setFlags: ['hbp_read_early_news'],
              housePoints: 3,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'just_shopping',
            text: '不打听，把该买的买齐',
            consequence:
                '你把书单上的东西一件件买齐，比往年快了很多。'
                '有个位置没货，你换了一家店。'
                '回家路上你只记得那些空着的位置，记不得别的。',
            effect: StoryEffect(
              setFlags: ['hbp_stayed_focused'],
              spirit: 2,
            ),
            nextStepId: '',
          ),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch1_new_staff',
        chapterId: 'hbp_ch1',
        timeCostDays: 12,
        setup:
            '教工席上换了两把椅子。'
            '魔药学的位子坐了一位从没见过的人——'
            '他胖、和气，第一堂课就开始点名问每个人的家庭。'
            '而黑魔法防御术的教室门口，站了十一年的那个人终于坐在了讲台后面。',
        ambient: [
          '新教授记住名字的本事吓人，一节课记住了半个班。',
          '走廊里有人在争论这算不算"终于熬出头了"。',
          '你闻到位子底下往年留下的一股焦糊味。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'answer_polite',
            text: '被点到名字时，礼貌地答一句就坐下',
            consequence:
                '你答得简短得体。他笑了笑，在名单上你的名字后面画了个圈。'
                '你不知道那个圈是什么意思——'
                '但你注意到，被画圈的还有另外几个人。',
            effect: StoryEffect(
              setFlags: ['hbp_noticed_circle'],
              addKnowledge: ['hbp_slug_list'],
              reputation: 1,
              targetNpcId: 'snape',
            ),
          ),
          StoryChoiceDef(
            id: 'defense_practice',
            text: '在黑魔法防御术课上把缴械咒练到能连发',
            consequence:
                '你对着草人练了整整一节，胳膊酸得抬不起来。'
                '讲台后那个人走过来看了一眼，什么也没说，'
                '只在你的羊皮纸上写了个"尚可"。'
                '你后来才知道，"尚可"从他笔下出来算很高的评价。',
            effect: StoryEffect(
              setFlags: ['hbp_defense_drill'],
              addKnowledge: ['hbp_expelliarmus'],
              reputation: 2,
              spirit: 1,
              targetNpcId: 'snape',
            ),
          ),
          StoryChoiceDef(
            id: 'compare_syllabus',
            text: '把两门课的新旧教学大纲摊开对比',
            consequence:
                '你把两份大纲并排一放：'
                '黑魔法防御术今年真的开始练实战了，'
                '而魔药学的难度往上跳了一级。'
                '你把差别抄在纸的背面，贴到了宿舍墙上。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包', '新羽毛笔'],
              addKnowledge: ['hbp_syllabus_diff'],
              setFlags: ['hbp_newt_plan'],
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch1_owl_results',
        canonRefId: 'canon_hbp_quidditch_trials',
        chapterId: 'hbp_ch1',
        timeCostDays: 11,
        setup:
            'O.W.L.s 的成绩单在早餐时送到了。'
            '有人尖叫，有人当场把纸翻过去扣在桌上。'
            '成绩决定了你接下来两年能上哪些 N.E.W.T. 课程——'
            '六年级的第一道门，其实在十一岁那年就悄悄关了一半。',
        ambient: [
          '有人在餐厅里抱着朋友哭，是高兴的那种。',
          '你把信封捏在手里，先去上了两节课才敢拆。',
          '走廊的布告栏前挤着一群人在对分数。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'plan_newt',
            text: '按成绩挑两门最硬的 N.E.W.T. 课，把计划写到月',
            consequence:
                '你挑了两门明知道会很累的课，'
                '把每周的复习时段在计划书上排满。'
                '排完之后你盯着那张表看了很久——'
                '这可能是七年来最后一份可以只为自己排的计划。',
            effect: StoryEffect(
              addItems: ['计划书'],
              addKnowledge: ['hbp_newt_plan'],
              setFlags: ['hbp_newt_plan'],
              spirit: 1,
            ),
          ),
          StoryChoiceDef(
            id: 'congratulate',
            text: '先去给考砸了的那位同学倒杯南瓜汁',
            consequence:
                '你把南瓜汁推过去的时候，对方愣了一下才接。'
                '他说他父亲会怎么看这张纸。'
                '你说：那就明年再看一次。',
            effect: StoryEffect(
              addItems: ['南瓜馅饼'],
              setFlags: ['hbp_owl_kind'],
              reputation: 2,
              affection: 3,
              spirit: 1,
              targetNpcId: 'neville',
            ),
          ),
          StoryChoiceDef(
            id: 'fold_away',
            text: '把成绩单折进课本，谁也不给看',
            consequence:
                '你把纸折了三折夹进书里，'
                '然后整整一天没提过这两个字。'
                '晚上你把它又拿出来看了一遍——'
                '这一次，是你自己想看。',
            effect: StoryEffect(
              setFlags: ['hbp_owl_private'],
              spirit: -1,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第二章 · 风声（1996 年 10 月）→ canon_hbp_malfoy_task
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'hbp_ch2',
    bookId: 'hbp',
    ordinal: 2,
    title: '风声',
    steps: [
      StoryStepDef(
        id: 'hbp_ch2_unease',
        chapterId: 'hbp_ch2',
        timeCostDays: 7,
        setup:
            '开学一个月，坏消息开始以"传闻"的形式进来——'
            '没有官方说法，只有别人家信里的只言片语。'
            '霍格莫德周末加了守卫，进村要登记；'
            '有家长写信来问能不能把孩子接回家待一阵。',
        ambient: [
          '蜂蜜公爵门口排队的人少了一半。',
          '布告栏上贴了一张新写的"结伴同行"通知。',
          '有同学在信里被家里要求每周多写一封。',
        ],
        canonRefId: 'canon_hbp_malfoy_task',
        choices: [
          StoryChoiceDef(
            id: 'collect_rumors',
            text: '把听到的传闻按日期一条条抄下来',
            consequence:
                '你抄了十四条，其中六条互相矛盾。'
                '但把它们按日期排好之后，'
                '你发现"出事的地方"在地图上正一点点往城堡方向靠近。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包'],
              addKnowledge: ['hbp_rumor_timeline'],
              setFlags: ['hbp_watch_rumors'],
              spirit: -1,
            ),
            nextStepId: 'hbp_ch2_watch',),
          StoryChoiceDef(
            id: 'volunteer_guard',
            text: '报名周末在村口帮忙维持秩序',
            consequence:
                '你在村口站了两个下午，'
                '大部分时间只是在给迷路的一年级生指路。'
                '但第三天收工的时候，有位教授对你点了下头——'
                '你知道，你被记住了。',
            effect: StoryEffect(
              setFlags: ['hbp_hogsmeade_guard'],
              addKnowledge: ['hbp_village_guard'],
              reputation: 2,
              spirit: -1,
              targetNpcId: 'mcgonagall',
            ),
            nextStepId: 'hbp_ch2_watch',),
          StoryChoiceDef(
            id: 'head_down',
            text: '不去看布告栏，把心思放回课业',
            consequence:
                '你绕开了布告栏，绕开了所有人在走廊里的低声交谈。'
                '你读完了一整本教科书，'
                '然后在夜里听见远处一声闷响，'
                '你告诉自己那只是打雷。',
            effect: StoryEffect(
              addKnowledge: ['hbp_study_bubble'],
              setFlags: ['hbp_focus_study'],
              spirit: -2,
            ),
            nextStepId: 'hbp_ch2_watch',),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch2_watch',
        canonRefId: 'canon_hbp_hogsmeade_visits',
        chapterId: 'hbp_ch2',
        timeCostDays: 1,
        setup:
            '这一年城堡里多了些说不清的规矩。晚上回宿舍的时间被提前了，走廊里巡逻的人也多了。',
        ambient: [
          '有人被拦下来问了三遍才放行。',
          '公告栏上的纸一天一换。',
          '夜里的风比往年冷。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'follow_rules',
            text: '老老实实按时间回来',
            consequence:
                '你每天准时回宿舍，路上的时间算得刚刚好。有人笑你太乖，你没反驳——这一年，能不出事就是本事。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['hbp_followed_rules'], reputation: 1, spirit: 2),
          ),
          StoryChoiceDef(
            id: 'say_it_out_loud',
            text: '把心里那点不对劲说出来，不压着',
            consequence:
                '你把去年在站台上跟人约好的那句话搬了出来：「觉得不对就说。」'
                '你说完，周围安静了两秒，然后有三个人点头。'
                '慌没有消失，但从这一刻起，慌变成了有人一起担着的事。',
            requireFlag: 'gof_spoke_the_instinct',
            effect: StoryEffect(
              setFlags: ['hbp_spoke_up_early'],
              reputation: 3,
              spirit: 3,
            ),
          ),

          StoryChoiceDef(
            id: 'walk_longer',
            text: '故意绕远路，把校园走一遍',
            consequence:
                '你每天换一条路线。一个月下来，把城堡的每个角落都走熟了。有一次你看见有人从校长塔那边下来，走得很急。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['hbp_castle_secret'], setFlags: ['hbp_explored_castle'], spirit: 3),
          ),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch2_missing',
        chapterId: 'hbp_ch2',
        timeCostDays: 10,
        setup:
            '点名册上开始出现空行。'
            '有人说那几个同学是"家里不放心"，'
            '有人说得更含糊，说完就换话题。'
            '空行不会有人解释，只会慢慢变长。',
        ambient: [
          '有个座位空了三个星期，谁也没去坐。',
          '你把名字写下来又划掉，最后只是把纸收进口袋。',
          '餐厅里有人多盛了一份，端到一半又放回去了。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'count_names',
            text: '把缺席者的名字和最后一次见到他们的日子记下来',
            consequence:
                '你记了五个名字，四个日期。'
                '这不是什么英勇的事，'
                '只是为了让"他们曾经在这里"这件事有一份证据。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包', '新羽毛笔'],
              addKnowledge: ['hbp_missing_list'],
              setFlags: ['hbp_counted_names'],
              spirit: -2,
            ),
          ),
          StoryChoiceDef(
            id: 'write_letter',
            text: '给其中一个缺席的同学写封信',
            consequence:
                '你写了三遍才寄出去。'
                '信里没问发生了什么，只说：'
                '"你的位子我给你留着，作业我帮你抄了一份。"'
                '猫头鹰飞走以后，你在窗前站了很久。',
            effect: StoryEffect(
              addItems: ['手写贺卡'],
              setFlags: ['hbp_wrote_letter'],
              reputation: 2,
              affection: 3,
              targetNpcId: 'susan',
            ),
          ),
          StoryChoiceDef(
            id: 'say_nothing',
            text: '什么也不做，专心准备下周的随堂测',
            consequence:
                '你什么也没做。'
                '那一周的随堂测你考得很好。'
                '考完收拾东西时，你看见前面那个空位子上落了一层灰。',
            effect: StoryEffect(
              setFlags: ['hbp_said_nothing'],
              addKnowledge: ['hbp_guilt_of_silence'],
              spirit: -2,
            ),
          ),
          StoryChoiceDef(
            id: 'cross_check_names',
            text: '把这份名单和去年自己记的那些并排抄一遍',
            consequence:
                '你翻出旧本子，把两份名单抄在同一页上。'
                '抄到第三行时你停住了——有两个名字，去年就出现在'
                '「今天谁没来上课」那一栏里。你把这一页折了个角。',
            requireKnowledge: ['gof_knows_own_timeline'],
            effect: StoryEffect(
              setFlags: ['hbp_cross_checked'],
              addKnowledge: ['hbp_knows_repeat_names'],
              reputation: 3,
              housePoints: 2,
              spirit: -1,
            ),
          ),

        ],
      ),
      StoryStepDef(
        id: 'hbp_ch2_corridor',
        chapterId: 'hbp_ch2',
        timeCostDays: 3,
        setup:
            '十月起，你开始注意到一些很小的变化。'
            '某个人不再在固定时间出现在固定走廊，'
            '有人在课上被叫到名字时会先愣一下，'
            '还有人开始绕开某几条楼梯。'
            '这些事单独看都不值得说。',
        ambient: [
          '两条通常会一起走路的同学，最近一前一后。',
          '有人把课本抱在胸前，走路的姿势像是怕被撞。',
          '午餐时段，某张长桌的某个位置连着空了两天。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'notice_quietly',
            text: '把看到的变化记在心里，不跟人说',
            consequence:
                '你什么都没说。你只是记住了。'
                '后来你想，如果当时说出来，会不会不一样。'
                '但当时说出来，也只是让更多人开始害怕。',
            effect: StoryEffect(
              addKnowledge: ['hbp_watched_changes'],
              setFlags: ['hbp_silent_observer'],
              housePoints: 2,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'ask_a_friend',
            text: '问一个跟他同院的朋友：他怎么了',
            consequence:
                '对方看了你一眼，说"没什么"。'
                '停了两秒，又补了一句："他最近不太对。"'
                '然后就转开了话题。'
                '你明白了一件事：有些事谁都知道，但没人说。',
            effect: StoryEffect(
              addKnowledge: ['hbp_someone_noticed'],
              setFlags: ['hbp_asked_around'],
              affection: 2,
              housePoints: 1,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'keep_busy',
            text: '不看了，专注自己的事',
            consequence:
                '你把注意力收回到课业上。'
                '这个学期的成绩是你七年里最好的。'
                '只是每次走过那条走廊，你都会下意识加快一点脚步。',
            effect: StoryEffect(
              setFlags: ['hbp_stayed_busy'],
              housePoints: 3,
              spirit: 1,
            ),
            nextStepId: '',
          ),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch2_tail',
        chapterId: 'hbp_ch2',
        timeCostDays: 9,
        setup:
            '有些人反常得很难不注意到。'
            '一位你认识多年的高年级同学开始频繁消失，'
            '问去哪儿了，只说"有事"；'
            '他瘦了很多，袖口总是往下拉。'
            '城堡的某些楼层，你最近总在同一个时间看见他。',
        ambient: [
          '你数了一下，这一周你撞见他四次，全在同一个拐角。',
          '他看见你的时候，第一反应是把口袋里的东西按住。',
          '有同学说"别管他的事，他家的事你惹不起"。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'follow_once',
            text: '跟一次，只看他去哪一层就回来',
            consequence:
                '你跟到六楼，看见他在一扇从不存在的门前站了很久，'
                '门没有开。你退了回去，'
                '心跳快得像是自己做错了什么。',
            effect: StoryEffect(
              addKnowledge: ['hbp_room_on_sixth'],
              setFlags: ['hbp_followed'],
              spirit: -1,
              targetNpcId: 'draco',
            ),
          ),
          StoryChoiceDef(
            id: 'report_to_professor',
            text: '把这份反常告诉一位你信得过的教授',
            consequence:
                '你说了，尽量说得像是在陈述事实而不是告状。'
                '那位教授听完很久没说话，'
                '最后只说了一句"我知道了"，'
                '然后——你后来才知道——真的去查了。',
            effect: StoryEffect(
              setFlags: ['hbp_reported'],
              addKnowledge: ['hbp_told_staff'],
              reputation: 2,
              spirit: -1,
              targetNpcId: 'mcgonagall',
            ),
          ),
          StoryChoiceDef(
            id: 'look_away',
            text: '转过身，回公共休息室烤火',
            consequence:
                '你转身走了。'
                '火很暖，作业很多，日子照常过。'
                '半年以后你会反复想起这个转身——'
                '不是因为愧疚，是因为你当时真的以为那只是别人的事。',
            effect: StoryEffect(
              setFlags: ['hbp_looked_away'],
              addKnowledge: ['hbp_turned_back'],
              spirit: -1,
            ),
          ),
          StoryChoiceDef(
            id: 'stay_with_the_scared',
            text: '不走，留下来陪着那几个明显害怕的低年级生',
            consequence:
                '你没说什么大道理，只是坐下来，把自己的事讲给他们听：'
                '四年级那年的那一夜，你也这么怕过。'
                '讲到一半，最小的那个不抖了。',
            requireFlag: 'gof_spoke_for_victim',
            effect: StoryEffect(
              setFlags: ['hbp_stayed_with_scared'],
              reputation: 3,
              spirit: 5,
            ),
          ),

        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第三章 · 一本旧课本（1996 年 11 月）→ canon_hbp_potions_book
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'hbp_ch3',
    bookId: 'hbp',
    ordinal: 3,
    title: '一本旧课本',
    steps: [
      StoryStepDef(
        id: 'hbp_ch3_old_book',
        chapterId: 'hbp_ch3',
        timeCostDays: 10,
        onEnterText:
            '【第三章 · 一本旧课本】\n'
            '这一章讲的不是黑魔法，是一道题：'
            '如果有一本书早就把答案写好了，你抄不抄？',
        setup:
            '魔药学课上有位同学的坩埚开始发出不该有的颜色。'
            '后来你看到了他的课本——'
            '一本旧得发黄的二手书，页边写满了密密麻麻的批注，'
            '改了步骤、改了火候、还写了一句"捣碎而不是切，汁更多"。'
            '扉页上签着一个名字：混血王子。',
        ambient: [
          '批注的字迹很老气，像几十年前的写法。',
          '新教授激动得当场宣布要收藏这一锅。',
          '你把那本书借过来看了三分钟，手心有点出汗。',
        ],
        canonRefId: 'canon_hbp_potions_book',
        choices: [
          StoryChoiceDef(
            id: 'borrow_book',
            text: '开口借一晚上，把批注抄下来',
            consequence:
                '你借了一晚上。'
                '抄到凌晨三点，你在最后一页看到一行小字，'
                '是一句你没有见过的咒语名字，'
                '旁边没写用途。你抄了，但没念。',
            effect: StoryEffect(
              addItems: ['旧书'],
              addKnowledge: ['hbp_prince_notes'],
              setFlags: ['hbp_borrowed_notes'],
              spirit: 1,
            ),
            nextStepId: 'hbp_ch3_first_lesson',),
          StoryChoiceDef(
            id: 'ask_origin',
            text: '先问一句：这本书原来是谁的',
            consequence:
                '你问了。对方说"二手书店买的，便宜"。'
                '你又问了一句"扉页上的名字呢"，'
                '对方把书收了回去，说："你问得太多了。"',
            effect: StoryEffect(
              setFlags: ['hbp_questioned_origin'],
              addKnowledge: ['hbp_book_origin_doubt'],
              reputation: 1,
              spirit: -1,
            ),
            nextStepId: 'hbp_ch3_first_lesson',),
          StoryChoiceDef(
            id: 'refuse_shortcut',
            text: '不借，回去照课本原步骤重熬一次',
            consequence:
                '你没借。'
                '那天晚上你按原步骤熬了四遍，'
                '前三遍都失败了。'
                '第四遍成功的时候，你完全知道每一步为什么这么做——'
                '这是批注给不了你的东西。',
            effect: StoryEffect(
              addItems: ['白鲜香精'],
              addKnowledge: ['hbp_slow_way'],
              setFlags: ['hbp_refused_shortcut'],
              spirit: 2,
            ),
            nextStepId: 'hbp_ch3_first_lesson',),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch3_first_lesson',
        chapterId: 'hbp_ch3',
        timeCostDays: 2,
        setup:
            '新教授的第一堂课从"我今天不打算教你们任何咒语"开始。'
            '他把几只小瓶子摆在讲台上，'
            '说这一学期你们要做的是学会分辨——'
            '分辨哪瓶是解药，哪瓶是让你后悔一辈子的东西。',
        ambient: [
          '有人伸长脖子看那些瓶子，被叫起来说了个答案，答错了。',
          '教授没有生气，只是把瓶塞打开让他闻了一下。',
          '整间教室的人都闻到了那股苦味。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'guess_right',
            text: '按书上的顺序推断，认真答一个',
            consequence:
                '你答对了。教授"嗯"了一声，'
                '把那只瓶子推到你面前，让你再说一遍理由。'
                '你说完，他点了点头——这是他这节课唯一一次点头。',
            effect: StoryEffect(
              addKnowledge: ['hbp_potions_method'],
              setFlags: ['hbp_impressed_new_prof'],
              housePoints: 4,
              reputation: 2,
              targetNpcId: 'snape',
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'take_notes',
            text: '把每只瓶子的颜色和气味记下来',
            consequence:
                '你记了整整两页，把颜色、气味、黏稠度都标上。'
                '下课的时候，有人问你能不能借他抄一下。'
                '你借了。这份笔记从这个学期一直传到了考试前。',
            effect: StoryEffect(
              addKnowledge: ['hbp_potion_notes'],
              setFlags: ['hbp_kept_notes'],
              housePoints: 3,
              affection: 2,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'stay_back',
            text: '课后留下来，问那个答错的人怎么样了',
            consequence:
                '你找到他，他正蹲在走廊上擦手。'
                '他说那味道"像家里地下室"。'
                '你陪他站了一会儿，谁都没再提那瓶东西。',
            effect: StoryEffect(
              setFlags: ['hbp_comforted_peer'],
              affection: 3,
              spirit: 1,
              housePoints: 1,
            ),
            nextStepId: '',
          ),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch3_margins',
        chapterId: 'hbp_ch3',
        timeCostDays: 1,
        setup:
            '那本书的页边写满了字，字迹很挤，像是有人在赶时间。有几处还画了箭头，指向别页。你把它拿到窗边，借着光一行行看下去。',
        ambient: [
          '同页的印刷体已经被批注盖得看不清了。',
          '书脊裂了一道，被谁用胶粘过。',
          '有人凑过来看，你下意识合上了书。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'copy_notes',
            text: '把有用的批注抄到自己的本子上',
            consequence:
                '你抄了整整两个晚上。抄的过程中你发现，写这些字的人不只是在教配方，还在教怎么想。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['hbp_margin_notes'], setFlags: ['hbp_copied_notes'], spirit: 4),
          ),
          StoryChoiceDef(
            id: 'return_book',
            text: '把书还回去，不去碰别人的东西',
            consequence:
                '你把书放回了原处。走出图书馆的时候有点舍不得，但你不想靠这种东西赢。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['hbp_returned_book'], reputation: 2, spirit: 1),
          ),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch3_brewing',
        canonRefId: 'canon_hbp_slughorn_party',
        chapterId: 'hbp_ch3',
        timeCostDays: 15,
        setup:
            '抄来的批注真的很管用。'
            '按它写的做，你的药剂颜色比所有人都要正，'
            '新教授开始当众念你的名字。'
            '代价是：你不再知道自己做的每一步是什么意思。',
        ambient: [
          '同桌问你诀窍，你张了张嘴，答不上来为什么。',
          '教授把你的坩埚端到讲台上当作示范。',
          '你注意到有几个人看你的眼神不太对。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'brew_win',
            text: '照抄不误，把这学期的魔药学分数拉满',
            consequence:
                '你拿了全班第一。'
                '教授在课上说你是"这一届最让人惊喜的学生"。'
                '你笑了，心里有个很小的声音在问：'
                '如果明天把这本书拿走，你还剩多少？',
            effect: StoryEffect(
              addItems: ['活力滋补剂'],
              addKnowledge: ['hbp_shortcut_win'],
              setFlags: ['hbp_brew_success'],
              reputation: 3,
              spirit: 1,
            ),
          ),
          StoryChoiceDef(
            id: 'test_safe',
            text: '把批注里的每一步单独试一遍，弄清哪一步是关键',
            consequence:
                '你花了一周做了九组对照。'
                '最后发现真正起作用的只有其中两条，'
                '其余七条只是写得自信。'
                '你既学会了捷径，也学会了不迷信它。',
            effect: StoryEffect(
              addItems: ['黄铜天平', '月长石粉'],
              addKnowledge: ['hbp_verified_notes'],
              setFlags: ['hbp_brew_safe'],
              reputation: 2,
              spirit: 2,
            ),
          ),
          StoryChoiceDef(
            id: 'share_notes',
            text: '把抄本摊开，让同桌也看看',
            consequence:
                '你摊开了。'
                '两个人对着一页纸研究了整晚，'
                '最后还吵了一架——他说批注里有一条是错的。'
                '第二天你们一起去问了教授，发现他是对的。',
            effect: StoryEffect(
              addKnowledge: ['hbp_shared_notes'],
              setFlags: ['hbp_shared_notes'],
              affection: 3,
              spirit: 2,
              targetNpcId: 'hermione',
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch3_slug_party',
        chapterId: 'hbp_ch3',
        timeCostDays: 2,
        setup:
            '新教授办了一场晚宴，请了几个人。'
            '被请的人从走廊上走过来时脚步都轻一点，'
            '没被请的人则在公共休息室里用很正常的语气谈论别的事。'
            '两种人都很努力地表现得不在意。',
        ambient: [
          '被请的人回来时身上有很淡的甜酒味。',
          '有人整晚都在讲晚宴上谁坐在谁旁边。',
          '也有人一句话都没说，把书翻得比平时响。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'go_if_invited',
            text: '去了，就好好把这一晚过完',
            consequence:
                '屋里很暖，桌上摆了很多你没见过的东西。'
                '你被问了几句家里的事，答得磕磕巴巴。'
                '回来的时候你想，这大概就是"被看见"的感觉——'
                '它比你想象的更让人不舒服。',
            effect: StoryEffect(
              addKnowledge: ['hbp_slug_club_inside'],
              setFlags: ['hbp_went_to_party'],
              reputation: 3,
              affection: 2,
              targetNpcId: 'snape',
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'decline',
            text: '没去，说那天有别的安排',
            consequence:
                '你没去。你那天晚上在公共休息室读完了两章。'
                '有人问你怎么没去，你说不感兴趣。'
                '这个回答你后来想过很多次，觉得它有一半是真的。',
            effect: StoryEffect(
              addKnowledge: ['hbp_slug_club_outside'],
              setFlags: ['hbp_skipped_party'],
              housePoints: 2,
              spirit: 1,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'observe',
            text: '不去，但留意谁去了、谁没去、谁在装无所谓',
            consequence:
                '你坐在靠火的位置，把进屋的每个人都看了一遍。'
                '你发现真正不在意的人只有一个，'
                '而他那天晚上一直在翻同一页书。',
            effect: StoryEffect(
              addKnowledge: ['hbp_slug_club_circle'],
              setFlags: ['hbp_read_the_room'],
              housePoints: 3,
            ),
            nextStepId: '',
          ),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch3_price',
        canonRefId: 'canon_hbp_king_cross',
        chapterId: 'hbp_ch3',
        timeCostDays: 14,
        setup:
            '捷径迟早会亮出账单。'
            '有人在魔药课上照着不知道从哪抄来的步骤操作，'
            '坩埚炸了，半张脸被送去了医疗翼。'
            '那本旧课本被翻到最后一页，'
            '最后几行批注的语气，和前面完全不一样。',
        ambient: [
          '医疗翼外面站着三个人，都不敢进去。',
          '你把抄本翻到最后，那几行字你以前没仔细看。',
          '新教授第一次在课上发了脾气。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'dig_origin',
            text: '翻遍图书馆，查"混血王子"到底是谁',
            consequence:
                '你查了三周。'
                '年鉴里没有这个人，'
                '旧生的名册里也没有这个名字。'
                '但你在一本几十年前的旧校刊里找到了一个相似的签名。'
                '再往下就没有了。',
            effect: StoryEffect(
              addItems: ['旧书', '羊皮纸一包'],
              addKnowledge: ['hbp_prince_search'],
              setFlags: ['hbp_dug_rumor'],
              spirit: -1,
            ),
          ),
          StoryChoiceDef(
            id: 'warn_others',
            text: '把自己的抄本收起来，并在课上提醒别人别乱抄',
            consequence:
                '你收起了抄本，还当众说了一句"别照着不认识的人写的做"。'
                '有几个人笑你小题大做。'
                '一周后，那几个笑的人里有一个来问你借笔记。',
            effect: StoryEffect(
              setFlags: ['hbp_warned_others'],
              addKnowledge: ['hbp_spoke_up'],
              reputation: 2,
              spirit: 1,
            ),
          ),
          StoryChoiceDef(
            id: 'put_down',
            text: '把最后几页撕下来烧掉，从此按自己的方法做',
            consequence:
                '你撕了，烧了，灰落进壁炉的时候你盯着看了一会儿。'
                '从那天起你的成绩掉回了中上，'
                '但每一锅药剂你都敢自己喝一口。',
            effect: StoryEffect(
              clearFlags: ['hbp_borrowed_notes', 'hbp_brew_success'],
              addKnowledge: ['hbp_burned_pages'],
              setFlags: ['hbp_put_it_down'],
              spirit: 2,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第四章 · 冬与圣诞（1996-12 ~ 1997-02）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'hbp_ch4',
    bookId: 'hbp',
    ordinal: 4,
    title: '冬与圣诞',
    steps: [
      StoryStepDef(
        id: 'hbp_ch4_village_winter',
        chapterId: 'hbp_ch4',
        timeCostDays: 6,
        setup:
            '今年的第一个霍格莫德周末，去的人比往年少。'
            '三把扫帚里空着好几张桌子，'
            '蜂蜜公爵的橱窗也没换新花样。'
            '有几个人在门口站了一会儿，又决定回城堡。',
        ambient: [
          '街上风很大，雪被吹得贴着地面跑。',
          '有人把围巾拉到了鼻子以上。',
          '邮局门口堆着没寄出去的信，厚厚一摞。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'go_anyway',
            text: '照样把这条街走完',
            consequence:
                '你把该走的地方都走了一遍，还买了两样东西。'
                '回城堡的路上，雪停了。'
                '你觉得这一天没有被浪费——哪怕只是因为你还愿意出来。',
            effect: StoryEffect(
              setFlags: ['hbp_kept_traditions'],
              spirit: 4,
              galleons: -2,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'stay_inside',
            text: '太冷了，找家店坐一下午',
            consequence:
                '你在三把扫帚的角落坐了一下午，喝了三杯黄油啤酒。'
                '邻桌在说别的事，声音不大，但很安稳。'
                '你走的时候天已经黑了，你一点也不后悔。',
            effect: StoryEffect(
              addKnowledge: ['hbp_village_afternoon'],
              setFlags: ['hbp_quiet_afternoon'],
              spirit: 3,
              satiety: 5,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'head_back_early',
            text: '在街上只站了十分钟就回城堡',
            consequence:
                '回去的路上你遇到了两个同样早回的人。'
                '你们一起走完了那段路，谁都没说为什么早回。'
                '那天下午城堡里比想象中热闹。',
            effect: StoryEffect(
              addKnowledge: ['hbp_others_left_too'],
              setFlags: ['hbp_early_return'],
              affection: 2,
              housePoints: 1,
            ),
            nextStepId: '',
          ),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch4_party',
        canonRefId: 'canon_hbp_curfew',
        chapterId: 'hbp_ch4',
        timeCostDays: 27,
        setup:
            '新来的魔药学教授喜欢办晚宴。'
            '请柬发到手里的时候你才明白，'
            '那不是一份荣誉，是一张名单——'
            '被请去的人，要么是成绩好，要么是"家里有人"。',
        ambient: [
          '请柬是手写的，纸很厚，边缘烫了金。',
          '走廊里有人在打听自己为什么没收到。',
          '餐厅的角落里，有人把请柬折成了纸飞机。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'attend_party',
            text: '去，看看那份名单上都有谁',
            consequence:
                '你去了。房间不大，人不多，'
                '但每一个名字你都在报纸上见过。'
                '他们聊得很客气，也很空洞。'
                '临走时教授拍拍你的肩：'
                '"你将来会需要这些人的。"你想：也许吧。',
            effect: StoryEffect(
              addItems: ['坩埚蛋糕'],
              addKnowledge: ['hbp_party_list'],
              setFlags: ['hbp_party_attended'],
              reputation: 2,
            ),
            nextStepId: 'hbp_ch4_party_night',),
          StoryChoiceDef(
            id: 'decline_party',
            text: '不去，把那个晚上用来给家里写信',
            consequence:
                '你没去。'
                '你写了一封很长的信回家，'
                '写完发现也没什么可说的，'
                '就把最近读的一本书抄了一段进去。',
            effect: StoryEffect(
              addItems: ['手写贺卡', '新羽毛笔'],
              setFlags: ['hbp_party_declined'],
              spirit: 1,
            ),
            nextStepId: 'hbp_ch4_party_night',),
          StoryChoiceDef(
            id: 'observe_party',
            text: '不去，但记下谁进去了、待了多久',
            consequence:
                '你在楼梯口坐了一个小时，'
                '记下了进去的十一个人和出来时的表情。'
                '你不打算用这份名单做什么，'
                '只是想知道这座学校里，门是朝谁开的。',
            effect: StoryEffect(
              addKnowledge: ['hbp_door_opens_for_whom'],
              setFlags: ['hbp_party_observed'],
              spirit: -1,
            ),
            nextStepId: 'hbp_ch4_party_night',),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch4_party_night',
        chapterId: 'hbp_ch4',
        timeCostDays: 1,
        setup:
            '聚会开到一半，有人把窗帘拉开了一条缝。外面的天全黑了，雪落在窗台上不化。你靠在墙上，看屋里的人来来去去。',
        ambient: [
          '有人提议玩个游戏，规则讲了半天没讲明白。',
          '杯子里剩的东西谁也不肯喝。',
          '炉火把墙上的影子拉得很长。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'stay_late',
            text: '留到最后，帮人收拾',
            consequence:
                '散场之后你和几个人把桌子擦干净，把椅子一把把推回去。最后关灯的时候，屋里比开始时还整齐。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['hbp_stayed_late'], reputation: 2, spirit: 3),
          ),
          StoryChoiceDef(
            id: 'leave_early',
            text: '找个借口先走',
            consequence:
                '你说自己不舒服，先出来了。走廊很安静，冷风从窗缝里进来，你反倒觉得清醒了。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['hbp_left_early'], spirit: 1),
          ),
          StoryChoiceDef(
            id: 'name_the_year',
            text: '在心里把这两年的账算一遍，然后写下来',
            consequence:
                '四年八月、四年十一月、五年六月、六年十月。'
                '你把这几个日期写在纸上，中间画了线。'
                '这条线不是证据，谁也不会因为一张纸改变什么，'
                '但你知道自己从今往后不会再把这些事当成巧合了。',
            requireFlag: 'gof_tracked_odds',
            effect: StoryEffect(
              setFlags: ['hbp_wrote_the_timeline'],
              addKnowledge: ['hbp_knows_long_arc'],
              reputation: 2,
              spirit: -2,
            ),
          ),

        ],
      ),
      StoryStepDef(
        id: 'hbp_ch4_christmas',
        canonRefId: 'canon_hbp_apparition',
        chapterId: 'hbp_ch4',
        timeCostDays: 27,
        setup:
            '圣诞节。留校的人比往年多——'
            '不是因为想留，是因为家里的信里那句'
            '"今年先别回来了，路上不安全"。'
            '餐厅里装饰照旧，气氛不像往年。',
        ambient: [
          '留校的桌子拼成了一条长桌，只坐了不到二十个人。',
          '有人的礼物在半路延误了三个星期。',
          '壁炉里的火比哪一年都旺。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'stay_christmas',
            text: '留校，和大家一起把长桌坐满',
            consequence:
                '你留了下来。'
                '平安夜那顿饭，十七个人围着一条长桌，'
                '谁也没提那些空位子的事。'
                '你后来觉得，那是这七年里最好的一个圣诞。',
            effect: StoryEffect(
              addItems: ['巧克力蛙', '南瓜馅饼'],
              setFlags: ['hbp_stayed_christmas'],
              affection: 3,
              spirit: 3,
              targetNpcId: 'ron',
            ),
          ),
          StoryChoiceDef(
            id: 'go_home',
            text: '还是回一趟家，哪怕路上要转三趟',
            consequence:
                '你回了家，路上确实被查了两次身份。'
                '家里的门在你看清它之前就开了——'
                '有人在窗边等了你很久。'
                '那三天你睡得比整个学期加起来都好。',
            effect: StoryEffect(
              addItems: ['保暖毛线帽'],
              setFlags: ['hbp_went_home'],
              spirit: 3,
            ),
          ),
          StoryChoiceDef(
            id: 'visit_hagrid',
            text: '去小屋坐坐，帮着劈一冬天的柴',
            consequence:
                '你劈了三个下午的柴。'
                '他给你倒了满满一杯热的东西，'
                '说今年的禁林"比往年安静，安静得不太对劲"。'
                '你记住了这句话，也记住了他没往下说的那半句。',
            effect: StoryEffect(
              addItems: ['黄油啤酒'],
              addKnowledge: ['hbp_forest_quiet'],
              setFlags: ['hbp_visited_hagrid'],
              affection: 3,
              spirit: 2,
              targetNpcId: 'hagrid',
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch4_winter',
        canonRefId: 'canon_hbp_memory_lessons',
        chapterId: 'hbp_ch4',
        timeCostDays: 26,
        setup:
            '二月。坏消息终于不再以传闻的形式出现——'
            '它出现在早餐的报纸上，占了整个头版。'
            '餐厅里安静得能听见壁炉里的柴响。',
        ambient: [
          '有人把报纸翻过去，扣在桌上，继续吃麦片。',
          '有人的手一直在抖，杯子里的水洒了一桌。',
          '你读完了整版，一个字都没漏。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'winter_alert',
            text: '把头版抄下来，贴在宿舍的墙上',
            consequence:
                '你抄了一份贴在墙上。'
                '室友让你撕掉，说看着难受。'
                '你说："就是要看着难受。"',
            effect: StoryEffect(
              addItems: ['羊皮纸一包'],
              addKnowledge: ['hbp_headline_copy'],
              setFlags: ['hbp_winter_alert'],
              spirit: -2,
            ),
          ),
          StoryChoiceDef(
            id: 'winter_help',
            text: '去陪那个家里出事的同学坐一整天',
            consequence:
                '你什么也没说，就坐在他旁边一整天。'
                '傍晚他开口了，说的第一句话是'
                '"我这学期作业还没交"。'
                '你说："我帮你写。"',
            effect: StoryEffect(
              setFlags: ['hbp_winter_helped'],
              reputation: 2,
              affection: 4,
              spirit: -1,
              targetNpcId: 'neville',
            ),
          ),
          StoryChoiceDef(
            id: 'winter_quiet',
            text: '不去读报纸，给自己放一天假',
            consequence:
                '你给自己放了一天假，在湖边走了一圈。'
                '湖面结着薄冰。'
                '回来的时候你已经知道了，'
                '只是你选择让自己晚一点知道。',
            effect: StoryEffect(
              setFlags: ['hbp_winter_quiet'],
              addKnowledge: ['hbp_one_day_late'],
              spirit: -1,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第五章 · 记忆与传闻（1997-03 ~ 05）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'hbp_ch5',
    bookId: 'hbp',
    ordinal: 5,
    title: '记忆与传闻',
    steps: [
      StoryStepDef(
        id: 'hbp_ch5_memory',
        chapterId: 'hbp_ch5',
        timeCostDays: 30,
        setup:
            '校长办公室里有一只石盆。'
            '被叫去的人不多，'
            '出来时脸上都带着同一种表情——'
            '像是看了不该看的东西，又像是终于看明白了什么。',
        ambient: [
          '石盆里的东西不是水，会自己动。',
          '办公室里的银器很多，都在轻轻地响。',
          '门口的凤凰偶尔看你一眼，看得人心里发毛。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'enter_memory',
            text: '被邀请时就走进去，看清盆里那段往事',
            consequence:
                '你弯下腰，看见了很多年前的另一个孩子。'
                '你看见的不是故事，是一个人的少年时代——'
                '他当时也和你差不多年纪，也做了自以为聪明的选择。'
                '出来的时候你一句话都说不出。',
            effect: StoryEffect(
              addKnowledge: ['hbp_saw_memory'],
              setFlags: ['hbp_saw_memory'],
              spirit: -1,
              targetNpcId: 'dumbledore',
            ),
            nextStepId: 'hbp_ch5_think',),
          StoryChoiceDef(
            id: 'ask_question',
            text: '问一句："这些事为什么现在才让我们知道"',
            consequence:
                '你问了。屋里安静了几秒。'
                '然后他说了一句话，你记了很久：'
                '"因为你们这一代人要接手了。"'
                '"我宁可你们在我还活着的时候知道。"',
            effect: StoryEffect(
              setFlags: ['hbp_asked_question'],
              addKnowledge: ['hbp_why_now'],
              reputation: 3,
              spirit: -1,
              targetNpcId: 'dumbledore',
            ),
            nextStepId: 'hbp_ch5_think',),
          StoryChoiceDef(
            id: 'decline_memory',
            text: '站在门口，不进去',
            consequence:
                '你站在门口没有进去。'
                '你知道有些东西一旦看见就再也放不回去，'
                '而你觉得自己还没准备好背上它。',
            effect: StoryEffect(
              setFlags: ['hbp_declined_memory'],
              addKnowledge: ['hbp_stood_at_door'],
              spirit: -1,
            ),
            nextStepId: 'hbp_ch5_think',),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch5_think',
        chapterId: 'hbp_ch5',
        timeCostDays: 1,
        setup:
            '那几段记忆在你脑子里过了一夜，越想越觉得有些地方对不上。你翻身坐起来，把想到的写在纸上。',
        ambient: [
          '油灯烧到了底，光在墙上晃。',
          '有人的鼾声隔着床帘传过来。',
          '窗外的月亮被云挡住了一半。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'connect_dots',
            text: '把几件事按时间排一遍',
            consequence:
                '你排到第三遍的时候，发现有个人的名字出现了两次，而且中间隔了很久。你把这两个时间点圈了起来。',
            nextStepId: '',
            requireAnyFlags: ['hbp_borrowed_notes', 'hbp_copied_notes', 'hbp_kept_notes'],
            requireKnowledge: ['hbp_prince_search', 'hbp_rumor_timeline'],
            effect: StoryEffect(addKnowledge: ['hbp_timeline'], setFlags: ['hbp_connected'], spirit: 3),
          ),
          StoryChoiceDef(
            id: 'let_it_go',
            text: '把纸揉了，不想再想',
            consequence:
                '你把那张纸团起来扔进了炉子。有些事你想不明白，也许就是不该由你想明白。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['hbp_let_go'], spirit: -1),
          ),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch5_library',
        chapterId: 'hbp_ch5',
        timeCostDays: 4,
        setup:
            '你为了写论文去查一个很偏的词条，'
            '发现那一整卷里被撕掉了几页。'
            '不是被裁的，是被人小心地沿着装订线取走的——'
            '边缘留着很细的一圈纸。',
        ambient: [
          '同卷的其他几处也有同样的痕迹。',
          '平斯夫人的借书卡上，那几卷的经手记录是空的。',
          '有个高年级生在你旁边站了很久，然后走开了。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'report_it',
            text: '去告诉平斯夫人那几页不见了',
            consequence:
                '她听完，脸上的表情变了两次。'
                '她说她会查，让你不要再跟别人提这件事。'
                '第二天那几卷书从架子上消失了，'
                '登记为"送修"。',
            effect: StoryEffect(
              addKnowledge: ['hbp_pages_reported'],
              setFlags: ['hbp_reported_pages'],
              housePoints: 3,
              reputation: 2,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'copy_whats_left',
            text: '把还能看到的部分抄下来',
            consequence:
                '你把前后文抄了一遍，中间那段空着。'
                '抄着抄着，你大概猜到了那几页在讲什么——'
                '因为上下文的语气突然变得很郑重，'
                '像在交代一件不能写下来的事。',
            effect: StoryEffect(
              addKnowledge: ['hbp_blank_inference'],
              setFlags: ['hbp_made_the_gap'],
              housePoints: 4,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'leave_it',
            text: '把书放回去，当没看见',
            consequence:
                '你把书推回架子上，位置摆得和原来一样。'
                '后来你想起这件事，总觉得自己当时应该多问一句。'
                '但你也知道，问了大概也没人会说。',
            effect: StoryEffect(
              setFlags: ['hbp_ignored_gap'],
              spirit: -1,
            ),
            nextStepId: '',
          ),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch5_rumor',
        chapterId: 'hbp_ch5',
        timeCostDays: 30,
        setup:
            '有些词开始在走廊里流传：'
            '"他把灵魂分成了几份"。'
            '说的人多半压低声音，'
            '听的人多半笑一句"编的吧"就走开了——'
            '但第二天他们又会凑过来问还有没有下文。',
        ambient: [
          '图书馆关于这个词的书全被借空了。',
          '有教授听见这个词时，脸色变了。',
          '你把能找到的线索写在纸的背面，越写越冷。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'dig_rumor',
            text: '顺着线索往下查，哪怕查到的东西让人睡不着',
            consequence:
                '你查了两个月。'
                '越往下越清楚，也越往下越冷。'
                '最后你停在一个数字上——'
                '你希望自己是算错了，但你没有。',
            requireAnyFlags: ['hbp_asked_around', 'hbp_counted_names', 'hbp_watch_rumors'],
            requireKnowledge: ['hbp_rumor_timeline', 'hbp_watched_changes'],
            effect: StoryEffect(
              addItems: ['旧书', '神秘符号'],
              addKnowledge: ['hbp_horcrux_count'],
              setFlags: ['hbp_dug_rumor'],
              spirit: -2,
            ),
          ),
          StoryChoiceDef(
            id: 'dismiss_rumor',
            text: '认定这是吓唬人的话，把纸揉了扔进壁炉',
            consequence:
                '你把纸揉了，扔进壁炉。'
                '火苗蹿起来的一瞬间你有点后悔，'
                '但你告诉自己：'
                '明天还要考试，别想这些了。',
            effect: StoryEffect(
              setFlags: ['hbp_dismissed_rumor'],
              spirit: -1,
            ),
          ),
          StoryChoiceDef(
            id: 'warn_others',
            text: '不去查，但把听到的原原本本告诉每一个愿意听的人',
            consequence:
                '你讲给了七个人听。'
                '三个人信了，两个人生气了，'
                '还有两个人让你闭嘴。'
                '你没有闭嘴。',
            effect: StoryEffect(
              setFlags: ['hbp_warned_others', 'hbp_dismissed_rumor'],
              addKnowledge: ['hbp_told_seven'],
              reputation: 2,
              spirit: -1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch5_april',
        chapterId: 'hbp_ch5',
        timeCostDays: 1,
        setup:
            '四月过去了一半，城堡里的课程表开始变得奇怪：有几门课'
            '的老师频繁缺席，代课的人显然没准备好，讲得心不在焉。'
            '没有人正式宣布什么，也没有人解释原因，但所有人都'
            '感觉得到——这一年的节奏正在被什么东西悄悄改掉。'
        ,
        ambient: [
          '黑魔法防御术的教室门上贴了一张"本周自习"的条。',
          '图书馆里那几排旧报纸被人翻得乱七八糟。',
          '你注意到走廊尽头的门锁换了新的。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'track_absences',
            text: '把缺席的课和换过锁的门记在一起',
            consequence:
                '你列了一张单子：哪天哪门课没人来，哪扇门换了锁，'
                '哪几个人那几天不在。写完之后你盯着它看了很久——'
                '单独看每一条都不奇怪，换个人不会多想；'
                '可是排在一起，它们就长出形状来了。'
                '你把单子折好，塞进课本的最后一页。'
            ,
            effect: StoryEffect(
              addKnowledge: ['hbp_absence_pattern'],
              setFlags: ['hbp_counted_absences'],
              spirit: -1,
            ),
          ),
          StoryChoiceDef(
            id: 'keep_head_down',
            text: '不去想它，专心准备 N.E.W.T. 的内容',
            consequence:
                '你把注意力收回到课本上，把那张单子压到箱底。'
                '这一年里你能控制的只有这个——外面的世界可以'
                '变糟，但成绩不会因为世界变糟就变得不重要。'
                '你反复告诉自己这句话，后来也真的信了。'
            ,
            effect: StoryEffect(
              setFlags: ['hbp_stayed_focused'],
              spirit: 2,
              housePoints: 2,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch5_may',
        chapterId: 'hbp_ch5',
        timeCostDays: 1,
        onEnterText: '四月的单子还没弄清楚，五月就来了。',
        setup:
            '五月的第一个星期，城堡里忽然开始有人收拾东西。不是'
            '放假——是家长来信，把孩子接回去了。宿舍楼里有几个'
            '床铺一夜之间空了出来，枕头叠得整整齐齐，没有人'
            '解释，也没有人问，大家只是从旁边绕过去。'
        ,
        ambient: [
          '有个低年级学生在门厅里哭着等车。',
          '公共休息室的布告栏上多了一张"外出登记"表。',
          '你发现自己的室友开始把重要的东西收进箱子底层。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'help_juniors',
            text: '去帮那些被接走的人收东西、送他们到门口',
            consequence:
                '你帮三个人搬了箱子，一直送到城堡大门口，'
                '看着马车把他们拉走。其中一个走到一半回过头，'
                '问你："我们还会回来吧？"你说会。'
                '你当时并不确定这句话是不是真的，但还是说了。'
            ,
            effect: StoryEffect(
              setFlags: ['hbp_helped_leavers'],
              addKnowledge: ['hbp_spring_exodus'],
              affection: 3,
              spirit: -1,
            ),
          ),
          StoryChoiceDef(
            id: 'write_it_down',
            text: '把五月这几天的变化写进日记',
            consequence:
                '你写了三页，把能想起来的都写了下来：谁走了，'
                '哪天走的，走之前说了什么。写到最后你忽然'
                '意识到——如果明年有新来的学生问起这一年，'
                '你手上这份大概是全城堡最接近真相的东西。'
            ,
            effect: StoryEffect(
              addItems: ['记满的日记本'],
              setFlags: ['hbp_kept_record'],
              addKnowledge: ['hbp_spring_record'],
              spirit: 1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch5_vow',
        canonRefId: 'canon_hbp_year_ends_early',
        chapterId: 'hbp_ch5',
        timeCostDays: 26,
        setup:
            '期末前一个月，有人来找你。'
            '他没有说要去哪儿，也没有说什么时候回来，'
            '只问了一句：'
            '"如果今晚就要走，你会不会帮我守着这边。"',
        ambient: [
          '他说这话时没有看你，看着走廊尽头的窗。',
          '外面天已经黑了，城堡比平时安静。',
          '你听见自己的心跳声盖过了壁炉。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'offer_help',
            text: '答应，问清楚要守多久、守到什么信号',
            consequence:
                '你说"我守"。'
                '然后你问了三个问题：守多久、'
                '什么信号算结束、'
                '出了事找谁。'
                '他把三件事都告诉了你——'
                '因为你是唯一一个问的人。',
            effect: StoryEffect(
              addItems: ['守护符链'],
              addKnowledge: ['hbp_watch_plan'],
              setFlags: ['hbp_offered_help'],
              reputation: 3,
              affection: 4,
              targetNpcId: 'harry',
            ),
            requireFlag: 'hbp_dug_rumor',
          ),
          StoryChoiceDef(
            id: 'stay_back',
            text: '不答应，但也不问为什么',
            consequence:
                '你摇了摇头。'
                '他点了点头，什么也没说就走了。'
                '你后来想，沉默有时候比拒绝更伤人——'
                '但你当时确实不敢。',
            effect: StoryEffect(
              setFlags: ['hbp_stayed_back'],
              spirit: -2,
            ),
          ),
          StoryChoiceDef(
            id: 'keep_watch',
            text: '不跟着去，但那晚自己也在走廊上转了一圈',
            consequence:
                '你没答应，也没走开。'
                '那天夜里你在那条走廊上走了三个来回，'
                '什么也没等到。'
                '第二天早上你听说，他们果然是那晚动的身。',
            effect: StoryEffect(
              setFlags: ['hbp_kept_watch'],
              addKnowledge: ['hbp_walked_the_hall'],
              spirit: -1,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第六章 · 天文塔之夜（1997 年 6 月）→ canon_hbp_astronomy_tower
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'hbp_ch6',
    bookId: 'hbp',
    ordinal: 6,
    title: '天文塔之夜',
    steps: [
      StoryStepDef(
        id: 'hbp_ch6_night',
        chapterId: 'hbp_ch6',
        timeCostDays: 5,
        onEnterText:
            '【第六章 · 天文塔之夜】\n'
            '这一天之前，六年级还是六年级。'
            '这一天之后，它变成了"那一年"。',
        setup:
            '夜里你被一声闷响惊醒。'
            '走廊上有人跑，方向乱，喊声也乱。'
            '窗外最高的那座塔上，'
            '升起了一道你只在课本插图里见过的绿光。',
        ambient: [
          '有低年级生光着脚站在楼梯口，不知道该往哪跑。',
          '石头楼梯上有人摔倒，后面的人伸手把他拽了起来。',
          '黑袍的身影从走廊尽头掠过，没有停留。',
        ],
        canonRefId: 'canon_hbp_astronomy_tower',
        choices: [
          StoryChoiceDef(
            id: 'hold_corridor',
            text: '按约定的位置守住走廊，把住那道楼梯',
            consequence:
                '你站在那道楼梯口，'
                '魔杖举了很久，最后只用了缴械咒——'
                '但那几十秒里，身后二十几个低年级生跑过去了。'
                '那几十秒，你后来想了一辈子。',
            effect: StoryEffect(
              addItems: ['勇气勋章'],
              addKnowledge: ['hbp_held_the_stair'],
              setFlags: ['hbp_held_corridor'],
              reputation: 4,
              spirit: -2,
            ),
            requireFlag: 'hbp_offered_help',
            nextStepId: 'hbp_ch6_corridor_night',),
          StoryChoiceDef(
            id: 'lead_juniors',
            text: '把吓傻了的一年级生一个个拽起来往地下室带',
            consequence:
                '你数着人头，一个都不能少。'
                '最后一个孩子是被你夹在腋下抱下去的，'
                '他一直在哭，你一直在说"没事了没事了"——'
                '其实你也不知道有没有事。',
            effect: StoryEffect(
              addKnowledge: ['hbp_led_juniors'],
              setFlags: ['hbp_led_juniors'],
              reputation: 3,
              spirit: -1,
              targetNpcId: 'colin',
            ),
            nextStepId: 'hbp_ch6_corridor_night',),
          StoryChoiceDef(
            id: 'freeze',
            text: '待在原地，一步也挪不动',
            consequence:
                '你一步也没动。'
                '不是不想，是身体不听使唤——'
                '后来你花了很久才原谅自己那天晚上的三十秒。',
            effect: StoryEffect(
              setFlags: ['hbp_froze'],
              spirit: -3,
            ),
            nextStepId: 'hbp_ch6_corridor_night',),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch6_corridor_night',
        chapterId: 'hbp_ch6',
        timeCostDays: 1,
        setup:
            '那天夜里，宿舍的门被从外面锁上了。'
            '不是锁死，是"值夜的教授交代先别出去"。'
            '有人贴着门听，听了很久，什么都没听清。'
            '窗外偶尔有光闪过，不是闪电。',
        ambient: [
          '走廊上的脚步声来过两趟，第一趟很急，第二趟很慢。',
          '有人小声说"是不是出事了"，然后没人接话。',
          '值班的级长坐在门口，一直没走。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'stay_and_wait',
            text: '留在宿舍，把身边的人稳住',
            consequence:
                '你坐到离门最近的位置，跟同屋的人有一搭没一搭地说话。'
                '你说的话自己都不记得了，但他们都安静下来了。'
                '天亮之后你才知道，那一夜真的出事了。',
            requireAnyFlags: ['hbp_comforted_peer', 'hbp_checked_friends', 'hbp_owl_kind', 'hbp_train_kind', 'hbp_winter_helped'],
            effect: StoryEffect(
              setFlags: ['hbp_calmed_dorm'],
              reputation: 3,
              spirit: -3,
              housePoints: 2,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'try_the_window',
            text: '想办法从窗户看清外面',
            consequence:
                '你爬到窗台上，把脸贴在玻璃上。'
                '下面操场上站着几个人，正抬头看某个方向。'
                '你顺着他们的目光看过去——'
                '只看到一片被照亮的云。',
            effect: StoryEffect(
              addKnowledge: ['hbp_saw_from_window'],
              setFlags: ['hbp_watched_sky'],
              spirit: -4,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'sleep_through',
            text: '躺回去，强迫自己睡着',
            consequence:
                '你闭上了眼睛。你居然真的睡着了。'
                '第二天早上醒来，城堡里的一切都已经变了——'
                '你成了整层楼最后一个知道的人。',
            effect: StoryEffect(
              setFlags: ['hbp_slept_through'],
              spirit: -2,
              satiety: 6,
            ),
            nextStepId: '',
          ),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch6_wait',
        chapterId: 'hbp_ch6',
        timeCostDays: 1,
        setup:
            '那天夜里的动静持续了很久。有人被叫起来帮忙，更多的人只是站在窗边看着。你站在那儿，直到腿有些发麻也没挪动。',
        ambient: [
          '夜里的风很冷，吹得人睁不开眼。',
          '有人抱着衣服跑过走廊，没穿鞋。',
          '远处有几点光在移动，看不清是什么。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'offer_help',
            text: '穿好衣服下楼，看能帮上什么',
            consequence:
                '你被安排去帮着领人、递东西。天亮的时候你才发现自己一晚上没坐下过，但一点也不觉得累。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['hbp_helped_night'], reputation: 3, spirit: 3),
          ),
          StoryChoiceDef(
            id: 'stay_window',
            text: '留在窗边，把那晚记住了',
            consequence:
                '你从头看到尾，什么也没做。后来的很多年里，你都还记得那天夜里风的方向。',
            nextStepId: '',
            requireAnyFlags: ['hbp_kept_watch'],
            requireKnowledge: ['hbp_timeline', 'hbp_rumor_timeline', 'hbp_watch_plan'],
            effect: StoryEffect(setFlags: ['hbp_witnessed'], spirit: -3),
          ),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch6_morning',
        chapterId: 'hbp_ch6',
        timeCostDays: 1,
        setup:
            '第二天早上的礼堂，几乎没人说话。'
            '餐桌上摆着早饭，但大部分人只是坐着。'
            '教师席上有几个位置空着。'
            '有人进来的时候，整间屋子会短暂地安静一下。',
        ambient: [
          '有人在哭，但哭得很小声，边上有个人一直搭着他的肩。',
          '有个低年级生问"是不是放假提前了"，没人回答他。',
          '窗外天气很好，和屋里的气氛完全不搭。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'sit_with_someone',
            text: '坐到那个看起来最不好的人旁边',
            consequence:
                '你什么也没说，就坐下了。'
                '过了一会儿，他递给你一片面包，你接了。'
                '你们就这样把早饭吃完了。'
                '很多年以后你才明白，那种时候陪着就够了。',
            effect: StoryEffect(
              setFlags: ['hbp_sat_with_someone'],
              affection: 4,
              spirit: 1,
              housePoints: 2,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'ask_what_happened',
            text: '去找知道的老师问清楚',
            consequence:
                '老师看了你很久，然后说："校长不在了。"'
                '你问是怎么了，他摇了摇头。'
                '你站在原地没动，直到他走过去拍了拍你的肩。',
            effect: StoryEffect(
              addKnowledge: ['hbp_told_the_truth'],
              setFlags: ['hbp_heard_plainly'],
              spirit: -3,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'eat_and_move',
            text: '把饭吃完，然后去上课',
            consequence:
                '你吃完了，去上了那节课。'
                '课上到一半，老师放下了魔杖，说今天不讲新内容。'
                '那天所有的课都变成了这样。',
            effect: StoryEffect(
              setFlags: ['hbp_kept_going'],
              spirit: -1,
              housePoints: 2,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'do_what_worked_before',
            text: '照两年前那晚的办法，坐到人身边，什么都不问',
            consequence:
                '你记得那一夜后来是怎么熬过去的——不是靠谁讲道理，'
                '是靠有人一直在旁边。于是你也只是坐着。'
                '过了很久，对方说了一句「谢谢」，声音很小。',
            requireFlag: 'gof_gathered_friends',
            effect: StoryEffect(
              setFlags: ['hbp_sat_in_silence'],
              reputation: 2,
              spirit: 4,
            ),
          ),

        ],
      ),
      StoryStepDef(
        id: 'hbp_ch6_dawn',
        chapterId: 'hbp_ch6',
        timeCostDays: 1,
        setup:
            '天亮了。'
            '城堡还在，塔也还在，'
            '只是从塔上下来的名单少了一个名字。'
            '有学生亲眼看见了塔顶的绿光，'
            '也有人在混乱里看见那位六年级的同学被带离。',
        ambient: [
          '有人一整夜坐在楼梯上没起来。',
          '医疗翼的门一直开着，走廊上排了很长的队。',
          '窗外那只凤凰叫了一夜，天亮时停了。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'carry_message',
            text: '替守夜的人跑腿，把消息送到该送到的人手里',
            consequence:
                '你跑了七趟，鞋底磨穿了。'
                '最后一趟送完，'
                '收信的人说了声谢谢，声音哑得几乎听不见。',
            effect: StoryEffect(
              setFlags: ['hbp_cared_others'],
              addKnowledge: ['hbp_ran_seven_times'],
              reputation: 3,
              spirit: -1,
            ),
            requireFlag: 'hbp_led_juniors',
          ),
          StoryChoiceDef(
            id: 'sit_with',
            text: '在医疗翼外面坐一整天，谁出来都陪他走一段',
            consequence:
                '你坐在门口一整天。'
                '出来的人有的想说话，有的不想。'
                '你两样都接住了。',
            effect: StoryEffect(
              setFlags: ['hbp_cared_others'],
              reputation: 2,
              affection: 3,
              spirit: -1,
              targetNpcId: 'ginny',
            ),
          ),
          StoryChoiceDef(
            id: 'walk_alone',
            text: '一个人走到湖边，坐到天黑',
            consequence:
                '你在湖边坐到天黑。'
                '脑子里什么都没有，'
                '只有那道绿光一直在视网膜上晃。',
            effect: StoryEffect(
              setFlags: ['hbp_walked_alone'],
              spirit: -3,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch6_funeral',
        chapterId: 'hbp_ch6',
        timeCostDays: 1,
        setup:
            '葬礼在湖边举行。'
            '来的人不只是学校里的——'
            '半个魔法世界都来了，站满了整片草地。'
            '很多人在那天第一次意识到，'
            '自己一直以为会永远在那儿的那个人，真的不在了。',
        ambient: [
          '湖面上浮着一层薄雾，一直没散。',
          '有巨人站在最后排，哭得肩膀一抖一抖。',
          '你从来没见过这么多成年人同时沉默。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'attend_funeral',
            text: '站到最后，一直到人群散尽',
            consequence:
                '你站到最后。'
                '人群散尽之后，草地上留下很多脚印。'
                '你没有哭，'
                '你只是想把这些脚印记住。',
            effect: StoryEffect(
              setFlags: ['hbp_funeral_attended'],
              addKnowledge: ['hbp_last_to_leave'],
              reputation: 2,
              spirit: -2,
            ),
          ),
          StoryChoiceDef(
            id: 'write_down',
            text: '把这一天的每一个细节写下来',
            consequence:
                '你写了一整夜，写了七页。'
                '写到最后一句的时候你停了很久：'
                '"从今天起，没有人能替我们兜底了。"',
            effect: StoryEffect(
              addItems: ['羊皮纸一包', '银色钢笔'],
              addKnowledge: ['hbp_wrote_it_down'],
              setFlags: ['hbp_wrote_down'],
              spirit: -2,
            ),
          ),
          StoryChoiceDef(
            id: 'leave_early',
            text: '中途离开，回宿舍把行李收拾好',
            consequence:
                '你中途走了。'
                '收拾行李的时候手一直在抖，'
                '你把同一件毛衣叠了四遍。',
            effect: StoryEffect(
              setFlags: ['hbp_funeral_left'],
              spirit: -2,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第七章 · 学年提前结束（1997 年 7 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'hbp_ch7',
    bookId: 'hbp',
    ordinal: 7,
    title: '学年提前结束',
    steps: [
      StoryStepDef(
        id: 'hbp_ch7_exams',
        chapterId: 'hbp_ch7',
        timeCostDays: 1,
        setup:
            '期末考试取消了。'
            '通知贴在每一层楼的布告栏上，措辞简短：'
            '本学期提前结束，请于三日内离校。'
            '你准备了整整一年的东西，'
            '最后没有被考到。',
        ambient: [
          '有人在收拾行李，有人在收拾别人的行李。',
          '考场门口的封条已经贴上了。',
          '你把复习计划从墙上撕下来，撕得很慢。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'pack_quick',
            text: '尽快收拾好，别给学校添麻烦',
            consequence:
                '你两小时就收拾完了。'
                '合上箱子的时候你愣了一下——'
                '七年的东西，一个箱子就装完了。',
            effect: StoryEffect(
              setFlags: ['hbp_packed'],
              spirit: -1,
            ),
            nextStepId: 'hbp_ch7_last_breakfast',),
          StoryChoiceDef(
            id: 'stay_behind',
            text: '留到最后一天，帮忙把公共休息室恢复原样',
            consequence:
                '你留到了最后。'
                '把椅子一张张翻到桌上，'
                '把壁炉里的灰清干净，'
                '像是在给这段日子做最后一次打扫。',
            effect: StoryEffect(
              setFlags: ['hbp_stayed_behind'],
              reputation: 2,
              spirit: -1,
              targetNpcId: 'mcgonagall',
            ),
            nextStepId: 'hbp_ch7_last_breakfast',),
          StoryChoiceDef(
            id: 'write_it_down',
            text: '把这一年的每件事按日期写成一张年表',
            consequence:
                '你写了两张羊皮纸：'
                '九月开学、十一月那本书、'
                '二月头版、六月那道绿光。'
                '写完你才发现，'
                '平静的那部分比灾难的那部分长得多。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包', '新羽毛笔'],
              addKnowledge: ['hbp_year_table'],
              setFlags: ['hbp_wrote_down'],
              spirit: -1,
            ),
            nextStepId: 'hbp_ch7_last_breakfast',),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch7_last_breakfast',
        chapterId: 'hbp_ch7',
        timeCostDays: 1,
        setup:
            '学年提前结束了，但城堡还没放人走。'
            '早餐照常供应，课表却已经作废。'
            '有人把这个学期的课本堆成一摞放在桌上，'
            '没人去收。',
        ambient: [
          '礼堂里的声音还是不多，但比前几天好一些。',
          '有人在写东西，写了很久也没写完。',
          '窗外有猫头鹰飞过，比平时多几只。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'pack_properly',
            text: '回去把箱子好好收一遍',
            consequence:
                '你把每一样东西都按位置放好，包括那些你本来打算丢掉的。'
                '收完你坐了一会儿，然后把它扣上。'
                '这个箱子你后来又打开过很多次，每次都想起这一天。',
            effect: StoryEffect(
              addKnowledge: ['hbp_packed_carefully'],
              setFlags: ['hbp_packed_well'],
              spirit: 1,
              housePoints: 2,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'write_letters',
            text: '给家里写一封信，把这一年说清楚',
            consequence:
                '你写了三页，删掉了两页。'
                '最后寄出去的那一页只有几句话：我还好，学校提前放假了。'
                '你想说的其实不止这些，但剩下的说不出口。',
            effect: StoryEffect(
              addKnowledge: ['hbp_wrote_home'],
              setFlags: ['hbp_wrote_letter'],
              spirit: 2,
              affection: 2,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'sit_with_friends',
            text: '什么都不做，和同学在礼堂坐到很晚',
            consequence:
                '你们从早上坐到中午，又从中午坐到下午。'
                '话题从一开始那件事，慢慢变成了明年的计划。'
                '有人说明年要当级长，有人说要退出魁地奇。'
                '你们都没有提"明年还会不会有明年"。',
            effect: StoryEffect(
              addKnowledge: ['hbp_stayed_together'],
              setFlags: ['hbp_sat_together'],
              affection: 4,
              spirit: 3,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'pass_it_on',
            text: '把自己这两年记的几页纸，抄一份给低年级的学弟',
            consequence:
                '你把本子摊开，挑了几页抄给他：哪些时候要结伴走、'
                '哪些传闻不必当真、出事之后去哪里找谁。'
                '他收下的时候有点发愣，你说：「两年后你会用得上。」',
            requireFlag: 'hbp_cross_checked',
            effect: StoryEffect(
              setFlags: ['hbp_passed_notes_on'],
              reputation: 4,
              housePoints: 4,
              spirit: 4,
            ),
          ),

        ],
      ),
      StoryStepDef(
        id: 'hbp_ch7_result',
        chapterId: 'hbp_ch7',
        timeCostDays: 1,
        setup:
            '考试成绩出来的时候，大家挤在公告栏前面。有人看完就走，有人站在那里反复看。你把那张纸看了三遍，才慢慢走出人群。',
        ambient: [
          '有人的名字在很前面，自己都不敢信。',
          '旁边有人小声算着要达到什么线才能选那门课。',
          '公告栏的纸边被风吹得卷了起来。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'aim_high',
            text: '按想要的课去凑分数',
            consequence:
                '你算了半天，发现自己差一点点。你去找了那位教授，问能不能通融。他看了你很久，最后说"下个学期看你的表现"。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['hbp_course_plan'], setFlags: ['hbp_aimed_high'], spirit: 3),
          ),
          StoryChoiceDef(
            id: 'accept_result',
            text: '接受结果，按现有的选课',
            consequence:
                '你把能选的课排了一遍，发现自己其实还挺喜欢这个组合。有些路是走出来的，不是选出来的。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['hbp_accepted_result'], spirit: 2),
          ),
          StoryChoiceDef(
            id: 'trust_it_fully',
            text: '最后定一句：以后再有那种感觉，直接信它',
            consequence:
                '你回想这三年——每一次觉得不对，事后都证明你没错过。'
                '你没有把这件事说成什么天赋，只是给自己立了条规矩：'
                '不因为别人都说没事，就把自己的判断交出去。'
                '这条规矩，你后来用了很多年。',
            requireKnowledge: ['hbp_knows_long_arc'],
            effect: StoryEffect(
              setFlags: ['hbp_trusts_instinct'],
              addKnowledge: ['hbp_knows_own_judgement'],
              reputation: 4,
              spirit: 6,
            ),
          ),

        ],
      ),
      StoryStepDef(
        id: 'hbp_ch7_train',
        chapterId: 'hbp_ch7',
        timeCostDays: 1,
        setup:
            '回程的列车比来时空。'
            '不是因为人少了多少，'
            '是因为每个人都在自己的包厢里待着，'
            '谁也不去串门。',
        ambient: [
          '过道里没有跑来跑去的一年级生。',
          '窗外下了雨，看不清霍格莫德。',
          '你把额头抵在玻璃上，一直到天黑。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'count_seats',
            text: '从头走到尾，数一数还有几个空座',
            consequence:
                '你走完了整列车，数了十一个空座。'
                '来的时候这些位子上都有人。'
                '回到包厢你把这个数字写在了年表最后。',
            effect: StoryEffect(
              addKnowledge: ['hbp_eleven_seats'],
              setFlags: ['hbp_counted_seats'],
              spirit: -2,
            ),
          ),
          StoryChoiceDef(
            id: 'sit_with_them',
            text: '和那天夜里一起守过走廊的人坐同一个包厢',
            consequence:
                '你们挤在一个包厢里，'
                '一路上谁也没提那天晚上的事，'
                '但谁也没有换座位。'
                '临别时有人说："明年见。"'
                '所有人都接了这句。',
            effect: StoryEffect(
              setFlags: ['hbp_with_friends'],
              addItems: ['比比多味豆'],
              affection: 4,
              reputation: 2,
              spirit: 1,
              targetNpcId: 'neville',
            ),
            requireFlag: 'hbp_held_corridor',
          ),
          StoryChoiceDef(
            id: 'sit_alone',
            text: '找个没人的包厢，一个人坐到底',
            consequence:
                '你找了个没人的包厢。'
                '七个小时里你把年表读了三遍，'
                '到站的时候，你才第一次抬头。',
            effect: StoryEffect(
              setFlags: ['hbp_sat_alone'],
              spirit: -2,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'hbp_ch7_decision',
        chapterId: 'hbp_ch7',
        timeCostDays: 1,
        setup:
            '下车前，你想起开学时那张安全须知的最后一句：'
            '"是否返校由家庭自行决定。"'
            '当时你以为那只是句官话。'
            '现在你知道，那是一句真话——'
            '而这个问题，第一次真的摆在了你面前。',
        ambient: [
          '月台上站满了来接人的家长，比送行时多。',
          '有人的父母当场就说"明年别去了"。',
          '你捏着那张通知书，站在车门边没下去。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'will_return',
            text: '回去——第七年，我要在场',
            consequence:
                '你说：我要回去。'
                '家里沉默了很久，然后有人开始帮你收拾行李。'
                '你知道这一年会是什么样，'
                '你也知道如果缺席，剩下的六年都会变成遗憾。',
            effect: StoryEffect(
              addItems: ['勇气勋章'],
              addKnowledge: ['hbp_will_return'],
              setFlags: ['hbp_will_return'],
              reputation: 3,
              spirit: 3,
            ),
            requireFlag: 'hbp_held_corridor',
          ),
          StoryChoiceDef(
            id: 'unsure',
            text: '说"我还不知道"，先回家过完这个夏天',
            consequence:
                '你说你不知道。'
                '这个回答很诚实，也很沉重。'
                '整个夏天你都在想这件事，'
                '一直到开学前三天才做决定。',
            effect: StoryEffect(
              setFlags: ['hbp_unsure'],
              spirit: -1,
            ),
          ),
          StoryChoiceDef(
            id: 'will_not_return',
            text: '不回去了——有些代价我不想再付第二次',
            consequence:
                '你说不回去了。'
                '没有人责怪你——'
                '这一年里失去的东西，谁都看在眼里。'
                '你寄了一封信回学校，说明了原因，'
                '也把年表的副本夹了进去。',
            effect: StoryEffect(
              addItems: ['手写贺卡'],
              setFlags: ['hbp_will_not_return'],
              spirit: -2,
            ),
          ),
        ],
      ),
    ],
  ),
];

// ================================================================
// 结局（顺序即优先级，兜底规则放最后）
// ================================================================

const List<StoryEndingRule> _hbpEndings = [
  StoryEndingRule(
    id: 'hbp_ending_held_the_stair',
    title: '守住那道楼梯的人',
    body:
        '那天夜里你举着魔杖站在楼梯口，'
        '身后跑过去二十几个比你小的孩子。'
        '你用的只是缴械咒，只挡了几十秒——'
        '但这几十秒是六年级唯一的、真正的战果。'
        '第二年你会再次站到同样的位置，'
        '那时你会想起这个晚上，然后不再发抖。',
    requireFlags: ['hbp_held_corridor', 'hbp_cared_others'],
  ),
  StoryEndingRule(
    id: 'hbp_ending_questioner',
    title: '问出那句话的人',
    body:
        '你问过书是谁的，问过为什么现在才知道，'
        '也问过守多久、什么信号、出了事找谁。'
        '这一年里所有重要的门，都是被一句问题敲开的。'
        '捷径你试过，也放下了——'
        '你最后选择的是"知道自己在做什么"。',
    requireAnyFlags: [
      'hbp_questioned_origin',
      'hbp_asked_question',
      'hbp_dug_rumor',
      'hbp_brew_safe',
    ],
    minReputation: 6,
  ),
  StoryEndingRule(
    id: 'hbp_ending_last_ordinary_year',
    title: '最后一个平常的年份',
    body:
        '你留校过了圣诞，去劈过柴，抄过一页批注又把它烧掉。'
        '你在图书馆查到过深夜，也在长桌边和人抢过最后一块馅饼。'
        '这一年被那道绿光切成两半，'
        '但你记住的，多半是前半段。'
        '很多年后有人问起六年级，你说：'
        '"那是我们最后一次，能只担心考试的一年。"',
    requireAnyFlags: [
      'hbp_stayed_christmas',
      'hbp_visited_hagrid',
      'hbp_party_attended',
      'hbp_with_friends',
      'hbp_brew_success',
    ],
  ),
  StoryEndingRule(
    id: 'hbp_ending_thirty_seconds',
    title: '那三十秒',
    body:
        '你没守住楼梯，没跟着去，'
        '在那晚站了三十秒，一步也没动。'
        '你烧掉了抄本，绕开了布告栏，'
        '把每一件可以不管的事都放过去了。'
        '你平平安安读完了六年级——'
        '然后在回家列车上，把空座位一个个数了一遍。'
        '你对自己说：明年不会了。',
  ),
];

const StoryBookDef halfBloodPrince = StoryBookDef(
  id: 'hbp',
  title: '混血王子',
  chapters: _hbpChapters,
  endings: _hbpEndings,
  startYear: 1996,
  startMonth: 7,
  startDay: 25,
);
