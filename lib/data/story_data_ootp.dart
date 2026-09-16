/// 《凤凰社》1995-1996 · 五年级 · 剧情内容表
///
/// 【这一部的气质】前四年是"危险在外面"，这一年是"危险坐在教室里"。
/// 魔法部派来的高级调查官不碰魔杖，也不动手——她只是把课表改了、
/// 把社团解散了、把每一条走廊都贴上了新规定。
/// 压迫感第一次以"规章制度"的形式出现，而反抗也第一次以
/// "一群学生在秘密教室里练习"的形式出现。
///
/// 【与哈利线的边界】组建学习小组的是他，去神秘事务司的也是他。
/// 但 DA 本身是几十个人的事——玩家可以是名单上的第 N 个名字：
/// 在场、签到、练习、被告密后一起跑。
/// 六月那场远征玩家不在列：你知道有人去了，
/// 你只知道消息传回来那天，餐厅里忽然少了几张脸。
///
/// 【原著节点覆盖】canon_ootp_return / canon_ootp_umbridge /
/// canon_ootp_da / canon_ootp_ministry_battle 四个节点各由一步剧情讲述。
library;

import 'package:hogwarts_life_simulator/models/story_progress.dart';

// ================================================================
// 《凤凰社》 1995-1996 · 五年级
//
// 【时间线】1995-07-25 开启锚点 → 1996-06 学年结束。
// 45 步 × 平均 7.5 天 ≈ 342 天，与 canon_ootp_* 节点的月份逐一对齐。
//
// 【密度补强】原为 39 步，七章分布 [6,6,4,7,6,5,5]——ch3 是全书唯一一个
// 只有 4 步的章，而它讲的正是 **DA 的成立与壮大**：原著里那件事跨了整整
// 一个学期，从一张小纸条长到几十个人。4 步装不下"一个地下组织是怎么
// 长出来的"，已扩为 10 步（第一次集会之后的沉默、名单怎么记、被拉进来
// 的人、一次临时取消、最后一次练习、寒假前的交代）。
// ================================================================

const List<StoryChapterDef> _ootpChapters = [
  // --------------------------------------------------------------
  // 第一章 · 五年级开学（1995 年 9 月）→ canon_ootp_return
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'ootp_ch1',
    bookId: 'ootp',
    ordinal: 1,
    title: '五年级开学',
    steps: [
      StoryStepDef(
        id: 'ootp_ch1_grimmauld',
        chapterId: 'ootp_ch1',
        timeCostDays: 14,
        setup:
            '八月末，你被接到一栋从外面看根本不该有人住的房子。'
            '门牌号会自己跳数字，窗帘后面有人在看街上。'
            '屋里比外面更像一整个夏天没开过窗——'
            '而楼上那间客厅里坐着的人，你只在报纸上见过照片。',
        ambient: [
          '厨房里有人在争论，声音压得很低，但隔着楼板还是听得到。',
          '一顶旧帽子在门厅的衣架上睡着，醒了一次又睡回去。',
          '有人把一整面墙的画像用布盖了起来，布角一直在动。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'listen_at_door',
            text: '在楼梯口多站一会儿，把听到的记下来',
            consequence:
                '你听见了几个地名、两个日期和一个人名。'
                '那些词当时读不通，'
                '但等你九月回到城堡，它们一个个都长出了意义。',
            effect: StoryEffect(
              addKnowledge: ['ootp_order_house'],
              setFlags: ['ootp_knows_order'],
              spirit: -1,
            ),
            nextStepId: 'ootp_ch1_sorting_night',
          ),
          StoryChoiceDef(
            id: 'help_clean',
            text: '挽起袖子帮忙打扫那间没人愿意进的屋子',
            consequence:
                '你清掉了十七袋垃圾、三窝不认识的小动物，'
                '还有一柜子会咬人的银器。'
                '中午有人给你盛了双份的汤，'
                '你意识到这大概是这里表达认可的方式。',
            effect: StoryEffect(
              addItems: ['旧银器盒'],
              setFlags: ['ootp_earned_trust'],
              reputation: 2,
              spirit: -2,
              energy: -8,
              affection: 3,
              targetNpcId: 'hagrid',
            ),
            nextStepId: 'ootp_ch1_sorting_night',
          ),
          StoryChoiceDef(
            id: 'keep_to_room',
            text: '待在被安排的房间里，看书到天黑',
            consequence:
                '你把带来的课本从头翻了一遍。'
                '楼下有人上来敲过两次门，你都假装睡着了。'
                '第三天早上，没人再来敲。',
            effect: StoryEffect(
              addKnowledge: ['ootp_study_bubble'],
              setFlags: ['ootp_stayed_out'],
              spirit: 2,
            ),
            nextStepId: 'ootp_ch1_sorting_night',
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch1_sorting_night',
        chapterId: 'ootp_ch1',
        timeCostDays: 14,
        setup:
            '分院仪式在开学第一晚照常举行。'
            '也照常只有一年级新生排着队上前。'
            '但你注意到今年新生坐下时，'
            '四张长桌上的掌声比往年稀疏——'
            '有人在低头说话，有人根本没在看。',
        ambient: [
          '帽子唱了一首新歌，歌词里有一句关于"团结"的提醒。',
          '教师席最右边那把椅子换人了，没人解释原因。',
          '你左边的人整晚没说一句话，右边的人在不停看门口。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'clap_loud',
            text: '每一个名字都用力鼓掌',
            consequence:
                '你把手拍红了。有个一年级生分完院坐下时，'
                '特意朝你这边看了一眼——'
                '在这个人人都盯着别处的晚上，'
                '你至少让一个人觉得自己是被欢迎的。',
            effect: StoryEffect(
              setFlags: ['ootp_welcomed_firstyears'],
              reputation: 2,
              spirit: 3,
            ),
            nextStepId: 'ootp_ch1_return',
          ),
          StoryChoiceDef(
            id: 'watch_staff_table',
            text: '把注意力放在教师席上',
            consequence:
                '你看见三个人整晚没动过面前的杯子，'
                '也看见有两个人在传纸条。'
                '这个晚上，'
                '真正的消息不在新生的名字里。',
            effect: StoryEffect(
              addKnowledge: ['ootp_staff_watch'],
              setFlags: ['ootp_reads_room'],
              spirit: -1,
            ),
            nextStepId: 'ootp_ch1_return',
          ),
          StoryChoiceDef(
            id: 'talk_to_neighbour',
            text: '主动和两边的人搭话',
            consequence:
                '你左边的人只回了一个字，右边的人跟你说了十分钟。'
                '十分钟里你听懂了：'
                '这个学期会很难，而且大部分人已经决定好了不站队。',
            effect: StoryEffect(
              setFlags: ['ootp_made_contacts'],
              addKnowledge: ['ootp_mood_read'],
              spirit: 2,
              affection: 2,
              targetNpcId: 'neville',
            ),
            nextStepId: 'ootp_ch1_return',
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch1_return',
        chapterId: 'ootp_ch1',
        timeCostDays: 14,
        onEnterText:
            '—— 第 5 部 · 凤凰社 ——\n'
            '暑假里没有人提那件事，但每个人都带着它返校。'
            '五年级了——O.W.L.s 年。',
        setup:
            '开学宴上校长的讲话比往年短，也比方才说的更重。'
            '他只提醒了一句：这一年，请相信你们亲眼看见的东西。'
            '同桌的人低头戳着盘子里的馅饼，没人接话。',
        ambient: [
          '餐厅里有人抬头看天花板，像在找什么。',
          '你注意到教工席上多了两个陌生位置。',
          '五年级的课本堆在桌下，比去年高出一截。',
        ],
        canonRefId: 'canon_ootp_return',
        choices: [
          StoryChoiceDef(
            id: 'listen_speech',
            text: '把校长每一句话都记下来',
            consequence:
                '你记了满满一页。那句"相信亲眼看见的东西"'
                '你画了两道线——当时你还不知道，'
                '这句话会在半年后被反复引用。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包'],
              addKnowledge: ['ootp_speech_note'],
              setFlags: ['ootp_heard_speech'],
              spirit: 1,
            ),
            nextStepId: 'ootp_ch1_letters',),
          StoryChoiceDef(
            id: 'check_seats',
            text: '数一数教工席上少了谁、多了谁',
            consequence:
                '你数了三遍：熟悉的位子少了两个，'
                '多了两个从没见过的——其中一个穿一身刺眼的粉。'
                '你把这件事告诉了同桌，对方说"别多嘴"。',
            effect: StoryEffect(
              addKnowledge: ['ootp_staff_changes'],
              setFlags: ['ootp_noticed_changes'],
              spirit: -1,
            ),
            nextStepId: 'ootp_ch1_letters',),
          StoryChoiceDef(
            id: 'plan_owls',
            text: '回宿舍先把 O.W.L.s 的考试范围摊开',
            consequence:
                '你把各科的考纲摊了一床，越看越清醒：'
                '这一年拼的不是聪明，是能不能坐得住。'
                '你在墙上贴了一张倒计时表。',
            effect: StoryEffect(
              addItems: ['计划书'],
              addKnowledge: ['ootp_owls_scope'],
              setFlags: ['ootp_owls_focus'],
              spirit: 1,
            ),
            nextStepId: 'ootp_ch1_letters',),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch1_letters',
        chapterId: 'ootp_ch1',
        timeCostDays: 6,
        setup:
            '回到学校以后，你发现同学们的信比往年多了一倍。每封都写得很短，而且读完之后大多被烧掉了。',
        ambient: [
          '公共休息室的炉火烧得特别旺。',
          '有人一边写信一边往门口看。',
          '窗外的天一直没晴过。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'write_home',
            text: '也给家里写一封，但只说学校里的事',
            consequence:
                '你把能写的都写了：课程、天气、新换的教授。不能写的那些，你在纸上停了好几次，最后空着。信封封上之前你又拆开看了一遍。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['ootp_wrote_home'], spirit: 2),
          ),
          StoryChoiceDef(
            id: 'burn_drafts',
            text: '写完就烧，不留草稿',
            consequence:
                '你写了三稿，一稿比一稿短。最后烧掉的是最短的那一版。看着纸在火里卷起来，你忽然明白大人们在怕什么。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['ootp_caution'], setFlags: ['ootp_burned_drafts'], spirit: -1),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch1_defense_class',
        canonRefId: 'canon_ootp_owl_exams',
        chapterId: 'ootp_ch1',
        timeCostDays: 5,
        setup:
            '黑魔法防御术今年换了人：一位穿粉色开衫的女士。'
            '她微笑着宣布，这门课今年"不学任何危险的东西"，'
            '课本是纯理论，魔杖留在包里就好。',
        ambient: [
          '教室里有人当场举手提问，被微笑着驳回。',
          '新课本的扉页印着教育令编号，一本比一本薄。',
          '你把魔杖往包里塞了塞，没敢拿出来。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'ask_question',
            text: '举手问：不练的话考试怎么考',
            consequence:
                '你举了手。她笑着回答"考试考理论"，'
                '然后让你抄写第一章二十遍。'
                '你抄到半夜，但旁边三个人都来问你要不要借抄。',
            effect: StoryEffect(
              setFlags: ['ootp_questioner'],
              addKnowledge: ['ootp_decree_basics'],
              reputation: 2,
              spirit: -2,
            ),
          ),
          StoryChoiceDef(
            id: 'read_between',
            text: '把教育令的编号一条条抄下来对照',
            consequence:
                '你抄了编号，发现它们是一年内递增的：'
                '每一条都在收紧一点。你把编号按时间排好，'
                '那张表看起来像一条正在合拢的线。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包', '新羽毛笔'],
              addKnowledge: ['ootp_decree_timeline'],
              setFlags: ['ootp_noticed_changes'],
              spirit: -1,
            ),
          ),
          StoryChoiceDef(
            id: 'obey_quietly',
            text: '照做，把魔杖收好',
            consequence:
                '你照做了。整节课你一个字没多说。'
                '下课后有人问你为什么不说话，'
                '你说："我想看看她下一步要干什么。"',
            effect: StoryEffect(
              addKnowledge: ['ootp_watchful_silence'],
              setFlags: ['ootp_noticed_changes'],
              spirit: 1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch1_whispers',
        chapterId: 'ootp_ch1',
        timeCostDays: 6,
        setup:
            '开学两周，城堡里流传着两种说法：'
            '一种说去年六月那件事是谎话，'
            '另一种——说这话的人第二天就不说了。',
        ambient: [
          '公告栏上贴着新的行为守则，措辞很客气。',
          '有人的猫头鹰被扣下来检查了两天。',
          '走廊上的低年级生被提醒"别问不该问的"。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'back_the_boy',
            text: '公开说你相信那个男孩的话',
            consequence:
                '你在餐厅里说了。声音不大，但那一片都安静了。'
                '当天下午你被叫去谈话，对方问你"为什么这么说"，'
                '你说"因为我去年六月在场"。',
            effect: StoryEffect(
              setFlags: ['ootp_stood_for_truth'],
              reputation: 3,
              affection: 2,
              spirit: 2,
              targetNpcId: 'harry',
            ),
          ),
          StoryChoiceDef(
            id: 'gather_evidence',
            text: '把去年六月自己看到的东西写下来存档',
            consequence:
                '你写了整整两页，只写亲眼所见，'
                '不写听说的。你把纸封好，'
                '在上面写："如果有一天需要证人，这两页算一份。"',
            effect: StoryEffect(
              addItems: ['羊皮纸一包'],
              addKnowledge: ['ootp_eyewitness_note'],
              setFlags: ['ootp_stood_for_truth'],
              spirit: 1,
            ),
          ),
          StoryChoiceDef(
            id: 'say_nothing',
            text: '什么都不说，把头低下去',
            consequence:
                '你什么都没说。那两周你睡得比谁都好，'
                '也第一次尝到"明知道却不出声"的滋味。'
                '后来你把它写进了日记，用了整整一页。',
            effect: StoryEffect(
              addKnowledge: ['ootp_silence_cost'],
              spirit: -2,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第二章 · 接管（1995 年 9-10 月）→ canon_ootp_umbridge
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'ootp_ch2',
    bookId: 'ootp',
    ordinal: 2,
    title: '接管',
    steps: [
      StoryStepDef(
        id: 'ootp_ch2_inspector',
        chapterId: 'ootp_ch2',
        timeCostDays: 5,
        canonRefId: 'canon_ootp_umbridge',
        setup:
            '她开始"听课"。每节课她都坐在教室后排，'
            '拿一支笔在小本子上记。被她听过的老师，'
            '第二周就会收到一份评估——措辞客气，分数很低。',
        ambient: [
          '后排那支笔的声音比讲课时还清楚。',
          '有教授被听课时把教案重讲了一遍，讲得很僵。',
          '学生中间开始有人模仿她咳嗽的声调。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'warn_teacher',
            text: '课后悄悄提醒老师她会来听',
            consequence:
                '你留下来提醒了一位教授。他愣了一下，'
                '说"谢谢你，孩子"，然后把教案换成了最稳的那版。'
                '两周后评估结果出来：他过了。',
            effect: StoryEffect(
              setFlags: ['ootp_protected_teacher'],
              reputation: 2,
              affection: 3,
              spirit: 1,
              targetNpcId: 'trelawney',
            ),
            nextStepId: 'ootp_ch2_quidditch_ban',),
          StoryChoiceDef(
            id: 'log_inspections',
            text: '记录她每一次出现的日期和班级',
            consequence:
                '你记了一个月，画出规律：'
                '她总在周四听三年级，周三下午空着——'
                '周三下午是她去魔法部汇报的日子。',
            effect: StoryEffect(
              addItems: ['计划书'],
              addKnowledge: ['ootp_inspection_pattern'],
              setFlags: ['ootp_noticed_changes'],
              spirit: 1,
            ),
            nextStepId: 'ootp_ch2_quidditch_ban',),
          StoryChoiceDef(
            id: 'mimic_her',
            text: '跟着大家在背后模仿她，宣泄一下',
            consequence:
                '你跟着笑了几次，笑完又觉得空。'
                '嘲讽能让人撑过一天，'
                '但第二天她还是坐在后排，笔还是那支笔。',
            effect: StoryEffect(
              setFlags: ['ootp_mocked'],
              reputation: 1,
              spirit: 1,
            ),
            nextStepId: 'ootp_ch2_quidditch_ban',),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch2_quidditch_ban',
        canonRefId: 'canon_ootp_quidditch_ban',
        chapterId: 'ootp_ch2',
        timeCostDays: 8,
        setup:
            '魁地奇赛季刚开始就出了变故：'
            '院队几名主力被处以终身禁赛，'
            '理由是"行为不当"。'
            '告示贴在公共休息室门口，'
            '下面很快围了一圈人，然后一个个沉默着走开。',
        ambient: [
          '有人把告示撕了一半，第二天又贴了一张新的，撕的那张不见了。',
          '训练场今天空着，球箱上落了灰。',
          '扫帚棚的门被人锁上了，锁是新的。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'join_protest',
            text: '和一群人去院长办公室门口静站',
            consequence:
                '你们站了一个下午，没喊口号，也没举牌子。'
                '院长出来看过两次，什么都没说。'
                '解散的时候，有人低声说了句"明天继续"——'
                '第二天果然还有人站着。',
            effect: StoryEffect(
              setFlags: ['ootp_quidditch_protest'],
              reputation: 3,
              spirit: -2,
              energy: -6,
              affection: 3,
              targetNpcId: 'mcgonagall',
            ),
            nextStepId: 'ootp_ch2_first_class',
          ),
          StoryChoiceDef(
            id: 'organise_own',
            text: '私下组织一场没有正式名分的对抗赛',
            consequence:
                '你们在清晨六点占了半个球场，'
                '用别人的旧扫帚打了四十分钟。'
                '有个巡逻的人从场边走过去，'
                '假装没看见——'
                '你后来知道，他是故意绕的路。',
            effect: StoryEffect(
              setFlags: ['ootp_unofficial_match'],
              addKnowledge: ['ootp_silent_allies'],
              spirit: 5,
              energy: -10,
            ),
            nextStepId: 'ootp_ch2_first_class',
          ),
          StoryChoiceDef(
            id: 'let_it_go',
            text: '把球衣收进箱底，去图书馆占位',
            consequence:
                '你把球衣叠好放进箱底，压在两本课本下面。'
                '那天的图书馆很安静，'
                '你做题做到闭馆，'
                '然后一个人走回宿舍，一次都没往球场方向看。',
            effect: StoryEffect(
              setFlags: ['ootp_owls_focus'],
              spirit: -3,
            ),
            nextStepId: 'ootp_ch2_first_class',
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch2_first_class',
        chapterId: 'ootp_ch2',
        timeCostDays: 12,
        setup:
            '新来的那位坐在教室最前面，手里拿着一块板和一支笔。她一整节课都在写，没有抬头。你在下面坐得笔直，眼睛盯着黑板。',
        ambient: [
          '有人在下面偷偷交换眼神。',
          '讲义发下来，比往年薄了一半。',
          '窗外有乌鸦落在窗台上，看了两眼就飞走了。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'take_notes',
            text: '把该记的都记下来',
            consequence:
                '你照常记笔记，一个字都没漏。下课后有人问你怕不怕，你说怕，但课上讲的东西考试要考。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['ootp_theory_notes'], setFlags: ['ootp_took_notes'], spirit: 2),
          ),
          StoryChoiceDef(
            id: 'ask_question',
            text: '举手问她一个课本上的问题',
            consequence:
                '她看了你一眼，说这个问题不该由你来问。全班安静了三秒。你说好，坐下。手指在桌下攥了一下。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['ootp_asked_question'], reputation: 1, spirit: -2),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch2_decrees',
        canonRefId: 'canon_ootp_da',
        chapterId: 'ootp_ch2',
        timeCostDays: 11,
        setup:
            '教育令一条接一条贴出来：社团必须重新登记、'
            '三人以上聚会要申报、学生刊物要先审。'
            '整面公告栏变成了粉色。',
        ambient: [
          '有社团的牌子被摘下来收进了柜子。',
          '公告栏前的人越来越少——大家已经懒得读了。',
          '你在第二十七条下面看见有人用指甲刻了个词。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'copy_decrees',
            text: '把每一条教育令抄一份留底',
            consequence:
                '你抄了二十七条。抄到第十八条时你手发凉：'
                '它规定"未经许可的解散"是违规的——'
                '这意味着任何组织都可以被一句话取缔。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包'],
              addKnowledge: ['ootp_decree_full'],
              setFlags: ['ootp_noticed_changes', 'ootp_owls_focus'],
              spirit: -2,
            ),
          ),
          StoryChoiceDef(
            id: 're_register',
            text: '按规矩把社团重新登记一遍',
            consequence:
                '你老老实实填了表，交了三份材料。'
                '批下来那天你发现，'
                '新章程里多了一条"活动须接受检查"。',
            effect: StoryEffect(
              setFlags: ['ootp_complied'],
              reputation: 1,
              spirit: -1,
            ),
          ),
          StoryChoiceDef(
            id: 'peel_notice',
            text: '趁没人，撕掉一张公告',
            consequence:
                '你撕了一张，撕得手心全是汗，'
                '撕完攥在口袋里走了一整天才敢扔。'
                '第二天那里又贴了一张新的，材质更结实。',
            effect: StoryEffect(
              setFlags: ['ootp_stood_for_truth'],
              reputation: 1,
              spirit: 1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch2_edict_creep',
        chapterId: 'ootp_ch2',
        timeCostDays: 8,
        setup:
            '墙上的教育令一张接一张地多起来，'
            '新的压着旧的，边角层层叠叠。'
            '每条都只改一点点：'
            '谁能管什么、谁不能做什么、'
            '哪句话算违规。'
            '单看每一条都不算什么，'
            '摞在一起的时候，你忽然发现走廊已经不剩多少能自由走的地方了。',
        ambient: [
          '有人拿尺子量过告示墙，说已经铺到第一百二十七条了。',
          '那条"禁止三人以上聚集"的告示下面，站着三个人在看。',
          '有人把每条教育令的编号抄在袖口内侧。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'copy_all_edicts',
            text: '把每一条都完整抄下来，编号存档',
            consequence:
                '你抄了整整三卷羊皮纸。'
                '抄到后面你发现了一件事：'
                '这些条款里有五条互相矛盾——'
                '也就是说，'
                '他们自己也没想清楚要管到什么程度。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包'],
              addKnowledge: ['ootp_edict_contradictions'],
              setFlags: ['ootp_archivist'],
              spirit: -2,
              energy: -6,
            ),
            nextStepId: 'ootp_ch2_skills',
          ),
          StoryChoiceDef(
            id: 'test_edges',
            text: '故意在条款的缝里试几次边界',
            consequence:
                '你先站了三个人，又站了两个人，'
                '最后是一个人在空教室里待满一小时。'
                '三次都没人管。'
                '你把结果记下来：'
                '规定很密，执行很松，'
                '这意味着真正的力量在别的地方。',
            effect: StoryEffect(
              setFlags: ['ootp_tests_boundaries'],
              addKnowledge: ['ootp_enforcement_gap'],
              spirit: 2,
            ),
            nextStepId: 'ootp_ch2_skills',
          ),
          StoryChoiceDef(
            id: 'keep_head_down',
            text: '绕开告示墙，走远路去上课',
            consequence:
                '你给自己规划了一条新路线，'
                '多走四分钟，'
                '但一天下来能少经过两次那张桌子。'
                '那个学期结束时，'
                '你对这条远路比对自己的课表还熟。',
            effect: StoryEffect(
              setFlags: ['ootp_avoided_notices'],
              spirit: -1,
              energy: 3,
            ),
            nextStepId: 'ootp_ch2_skills',
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch2_skills',
        chapterId: 'ootp_ch2',
        timeCostDays: 8,
        setup:
            '五年级的实操课越来越少，'
            '而每个人心里都清楚：真正需要练习的东西，'
            '恰恰是课上不教的那些。',
        ambient: [
          '有人偷偷在空教室里对着蜡烛练除你武器。',
          '图书馆里关于实战咒的书全被借空了。',
          '你包里那根魔杖，已经一周没出过口袋。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'practice_alone',
            text: '找个空教室，一个人偷偷练',
            consequence:
                '你练了三周，最好的成绩是打飞了三根蜡烛。'
                '一个人练的问题是没人纠正你——'
                '你为此付出的代价是养成了两个坏习惯。',
            effect: StoryEffect(
              setFlags: ['ootp_practiced_alone'],
              addKnowledge: ['ootp_solo_drill'],
              spirit: 2,
            ),
          ),
          StoryChoiceDef(
            id: 'find_partners',
            text: '打听谁也在偷偷练，约到一起',
            consequence:
                '你打听到了四个人，其中一个说：'
                '"再拉几个人吧，光我们几个不够。"'
                '你没意识到，这句话是一切的开头。',
            effect: StoryEffect(
              setFlags: ['ootp_seeking_group'],
              reputation: 2,
              affection: 2,
              spirit: 2,
              targetNpcId: 'neville',
            ),
          ),
          StoryChoiceDef(
            id: 'focus_exams',
            text: '不练了，把时间全给 O.W.L.s',
            consequence:
                '你把时间全给了考试。成绩确实上去了，'
                '但每次路过那间空教室，'
                '你都会加快脚步——怕自己改主意。',
            effect: StoryEffect(
              setFlags: ['ootp_owls_focus'],
              addItems: ['标准咒语书', '提神剂'],
              reputation: 1,
              spirit: 1,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第三章 · 秘密学习小组（1995 年 10 月）→ canon_ootp_da
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'ootp_ch3',
    bookId: 'ootp',
    ordinal: 3,
    title: '秘密学习小组',
    steps: [
      StoryStepDef(
        id: 'ootp_ch3_invitation',
        canonRefId: 'canon_ootp_edicts',
        chapterId: 'ootp_ch3',
        timeCostDays: 7,
        setup:
            '一张纸条塞进你手里，上面只有一行字：'
            '"想知道怎么真正用魔杖吗？今晚八点，八楼。"'
            '字迹很急，末尾画了一个很小的闪电。',
        ambient: [
          '纸条在你手心攥出了褶皱。',
          '走廊上有人跟你擦肩而过，什么也没说。',
          '你把纸条读了四遍，然后烧掉了。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'go_to_meeting',
            text: '去，八点准时到',
            consequence:
                '你去了。八楼那间屋子以前从没见过，'
                '里面已经站了二十几个人，'
                '有人说："既然都来了，那就开始吧。"',
            effect: StoryEffect(
              setFlags: ['ootp_joined_da'],
              addKnowledge: ['ootp_da_first_night'],
              reputation: 2,
              spirit: 3,
              affection: 2,
              targetNpcId: 'hermione',
            ),
            nextStepId: 'ootp_ch3_after_first',),
          StoryChoiceDef(
            id: 'send_someone',
            text: '让别人先去，自己先打听清楚',
            consequence:
                '你让室友先去，自己留在宿舍等消息。'
                '他回来时眼睛亮得吓人，说了三个字："你也去。"'
                '第二周你补上了第一次。',
            effect: StoryEffect(
              setFlags: ['ootp_joined_da'],
              addKnowledge: ['ootp_da_secondhand'],
              reputation: 1,
              affection: 2,
              spirit: 2,
              targetNpcId: 'seamus',
            ),
            nextStepId: 'ootp_ch3_after_first',),
          StoryChoiceDef(
            id: 'decline',
            text: '不去，把纸条烧掉',
            consequence:
                '你把纸条烧了。接下来的半年，'
                '你无数次在走廊上看见那群人交换眼神，'
                '而你知道自己不在那个圈子里。',
            effect: StoryEffect(
              setFlags: ['ootp_stayed_out'],
              addKnowledge: ['ootp_declined_da'],
              spirit: -2,
            ),
            nextStepId: 'ootp_ch3_after_first',),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch3_after_first',
        chapterId: 'ootp_ch3',
        timeCostDays: 3,
        setup:
            '第一次练习散场的时候，没有人一起走。'
            '大家从不同的门出去，隔几分钟走一个，'
            '像是不认识彼此。'
            '你最后一个离开，屋里还留着垫子被踩过的味道。',
        ambient: [
          '走廊上遇到同学，对方只是点了一下头。',
          '回到公共休息室，有人问你刚才去哪儿了，你说去图书馆了。',
          '那天晚上你睡得很沉。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'keep_the_secret',
            text: '谁都不说，连朋友也不说',
            consequence:
                '你守住了。接下来几个星期，你在饭桌上听到有人猜"到底有没有那么个地方"，你跟着一起猜。'
                '你没有说谎，只是没说真话。'
                '这大概是这一年你学会的第一件事。',
            effect: StoryEffect(
              addKnowledge: ['ootp_da_secrecy'],
              setFlags: ['ootp_kept_silent'],
              housePoints: 3,
              spirit: -1,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'bring_a_friend',
            text: '下次带一个你信得过的人来',
            consequence:
                '你挑了一个想了很久的人，只说了时间，没说地点。'
                '他跟着你走了很久，一路上什么也没问。'
                '进门之前他才说了一句："你就是带我来这个？"'
                '然后他笑了，走了进去。',
            effect: StoryEffect(
              addKnowledge: ['ootp_recruited_one'],
              setFlags: ['ootp_brought_friend'],
              affection: 4,
              reputation: 2,
              housePoints: 2,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'ask_how_it_started',
            text: '去问那个贴纸条的人：这是谁牵的头',
            consequence:
                '他看了你一会儿，说"别问这个"。'
                '过了一会儿又补了一句："你只要知道，现在不只你一个人想学。"'
                '你没再问。但这句话你记住了。',
            effect: StoryEffect(
              addKnowledge: ['ootp_da_origin_hint'],
              setFlags: ['ootp_asked_origin'],
              housePoints: 2,
              spirit: 1,
            ),
            nextStepId: '',
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch3_signup',
        chapterId: 'ootp_ch3',
        timeCostDays: 6,
        setup:
            '有人在公共休息室的墙上贴了一张很小的纸条，上面只有一句话和一个记号。看过的人都装作没看见。',
        ambient: [
          '那个记号第二天就被人撕掉了。',
          '有人在你耳边说了个时间，然后就走开了。',
          '炉火边坐着的人比平时多了几个。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'sign_name',
            text: '在纸条背面写下自己的名字',
            consequence:
                '你写得很快，写完就走开了。第二天你发现自己不是唯一一个——那张纸的背面挤满了名字，有些写在角落里。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['ootp_group_meeting'], setFlags: ['ootp_joined_group'], spirit: 5),
          ),
          StoryChoiceDef(
            id: 'think_first',
            text: '记下时间和记号，先不表态',
            consequence:
                '你把那个记号在心里描了好几遍。你没有写名字，但那天晚上你按写的时间去了门外。站在门口听了五分钟，又走开了。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['ootp_hesitated'], spirit: -1),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch3_the_list',
        chapterId: 'ootp_ch3',
        timeCostDays: 3,
        setup:
            '到第三周，来的人比第一次多了不少。'
            '有人提议把名字记下来，也立刻就有人反对——'
            '写下来的东西会被人看见，会被人拿走。'
            '屋里沉默了一会儿。',
        ambient: [
          '有人提议用绰号代替真名。',
          '有人说干脆谁都不记，靠脑子。',
          '坐在角落里的人一直没说话，最后开口说：那要是有人出事了呢。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'memorize_only',
            text: '不写，全部记在脑子里',
            consequence:
                '你花了几个晚上把每一张脸和名字对上。'
                '这不是什么了不起的技能，但你做到了。'
                '后来有一回名单被搜走了，只有你脑子里的那份还在。',
            effect: StoryEffect(
              addKnowledge: ['ootp_da_memory_list'],
              setFlags: ['ootp_no_written_list'],
              housePoints: 4,
              reputation: 2,
              energy: -3,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'use_codes',
            text: '用只有自己人看得懂的记号',
            consequence:
                '你们定了一套很笨的记号：星座代替姓氏，数字代替年级。'
                '写出来像一张星图。'
                '外人看了什么都不会想到，熟人一眼就懂。'
                '这套记号后来传到了别的年级。',
            effect: StoryEffect(
              addKnowledge: ['ootp_da_codes'],
              setFlags: ['ootp_made_codes'],
              housePoints: 3,
              affection: 2,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'keep_it_open',
            text: '不设名单，谁想来都可以',
            consequence:
                '你说服了他们：越是藏，被找到的时候越难看。'
                '从那以后门一直开着，来的人自己知道该守什么。'
                '这件事后来帮了你们，也让你们吃过一次亏。',
            effect: StoryEffect(
              addKnowledge: ['ootp_da_open_door'],
              setFlags: ['ootp_kept_open'],
              reputation: 3,
              spirit: 2,
              housePoints: 2,
            ),
            nextStepId: '',
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch3_first_drill',
        chapterId: 'ootp_ch3',
        timeCostDays: 5,
        setup:
            '第一次练习。屋里摆着一圈旧垫子，'
            '教学的是那个男孩——他自己说：'
            '"我去年真的用过这些，所以我能教你们。"',
        ambient: [
          '垫子被咒语打得啪啪响。',
          '有人第一次成功时，全场一起喊了出来。',
          '门口有人负责望风，每隔十分钟换一次。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'volunteer_first',
            text: '第一个站出来当靶子',
            consequence:
                '你第一个上，被击倒了四次。'
                '第五次你终于挡了下来——'
                '后来有人说，那天你是全场进步最快的人。',
            effect: StoryEffect(
              setFlags: ['ootp_da_active'],
              reputation: 2,
              affection: 2,
              spirit: 3,
              targetNpcId: 'harry',
            ),
          ),
          StoryChoiceDef(
            id: 'take_notes',
            text: '不抢着上，把每个咒的要点记下来',
            consequence:
                '你记了满满三页要点，第二天抄了一份给没能来的人。'
                '后来这份笔记在小组里传了半个月，'
                '落款处有人替你加了一行"谢谢记录员"。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包', '新羽毛笔'],
              addKnowledge: ['ootp_da_notes'],
              setFlags: ['ootp_da_active'],
              reputation: 2,
              spirit: 2,
            ),
          ),
          StoryChoiceDef(
            id: 'stand_watch',
            text: '去门口望风，守住大家',
            consequence:
                '你站了两个小时，冷得直跺脚，'
                '一次也没让人进来。散场时那男孩对你说：'
                '"今晚多亏你了。"——望风也是上课。',
            effect: StoryEffect(
              setFlags: ['ootp_da_active', 'ootp_da_watch'],
              reputation: 3,
              spirit: 1,
              affection: 2,
              targetNpcId: 'luna',
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch3_newcomer',
        chapterId: 'ootp_ch3',
        timeCostDays: 4,
        setup:
            '第五次集会来了一个你不认识的低年级生。'
            '他站在门口不敢进来，直到有人朝他招了招手。'
            '练习到一半他问了一句：如果家里知道了会怎么样。'
            '没人马上回答。',
        ambient: [
          '他手上还带着家里给的护身符。',
          '有人把自己的垫子让给他。',
          '散场之后他还坐着，看着别人收拾东西。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'tell_him_the_truth',
            text: '如实说：家里知道会有麻烦',
            consequence:
                '你告诉他，可能会收到信，可能会被叫回去，'
                '也可能什么都没有——但不会有好事。'
                '他听完点了点头，说"那我更想学了"。'
                '他后来一次都没缺过。',
            effect: StoryEffect(
              addKnowledge: ['ootp_newcomer_truth'],
              setFlags: ['ootp_told_truth'],
              affection: 4,
              reputation: 2,
              housePoints: 3,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'tell_him_itll_be_fine',
            text: '跟他说：不会有事的，别怕',
            consequence:
                '你说了那句话，他松了口气。'
                '那一晚他练得很起劲。'
                '三周之后他没再来——你后来听说，他家里真的知道了。'
                '你一直觉得那句"不会有事的"说得太轻巧。',
            effect: StoryEffect(
              setFlags: ['ootp_reassured_newcomer'],
              spirit: -2,
              housePoints: 1,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'walk_him_back',
            text: '不问，散场后陪他走一段',
            consequence:
                '你们走了一段很长的走廊，谁都没提练习的事。'
                '他讲了他家的事，你讲了你的事。'
                '到楼梯口他说"我自己走就行"。'
                '你看着他上了楼才转身。',
            effect: StoryEffect(
              addKnowledge: ['ootp_newcomer_walked'],
              setFlags: ['ootp_walked_back'],
              affection: 5,
              housePoints: 2,
            ),
            nextStepId: '',
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch3_cancelled',
        chapterId: 'ootp_ch3',
        timeCostDays: 3,
        setup:
            '有一次，约好的那晚门上多了一张小纸条：'
            '今晚不练，原路返回。'
            '你在门口站了一会儿，走廊两头都有人正在走开，'
            '谁都没有回头。',
        ambient: [
          '第二天听说那晚有人在附近巡视。',
          '纸条被谁揭走了，没人知道。',
          '接下来那一周，来的人反而更多了。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'go_back_quietly',
            text: '按纸条说的做，原路回去',
            consequence:
                '你转身就走了，脚步和平时一样。'
                '躺到床上才觉得后背有点凉。'
                '第二天什么也没发生，这让你更确信那张纸条是对的。',
            effect: StoryEffect(
              addKnowledge: ['ootp_learned_the_warning'],
              setFlags: ['ootp_followed_warning'],
              housePoints: 3,
              spirit: 1,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'circle_around',
            text: '绕到另一头看看谁在巡视',
            consequence:
                '你从另一道楼梯上去，远远看到两个人影在走廊里走。'
                '他们没有找什么，只是在走。'
                '你在阴影里等了很久，直到他们离开。'
                '回去之后你把看到的时间记了下来。',
            effect: StoryEffect(
              addKnowledge: ['ootp_patrol_pattern'],
              setFlags: ['ootp_scouted_patrol'],
              housePoints: 4,
              reputation: 2,
              spirit: -1,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'warn_others',
            text: '想办法提醒还没收到消息的人',
            consequence:
                '你等在楼梯拐角，把每一个往这边走的人拦下来。'
                '你拦了六个人，其中两个不太高兴。'
                '散场时你什么也没练到，但那天晚上没有一个人撞上去。',
            effect: StoryEffect(
              addKnowledge: ['ootp_warned_the_line'],
              setFlags: ['ootp_warned_others'],
              affection: 4,
              reputation: 3,
              housePoints: 2,
            ),
            nextStepId: '',
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch3_last_drill',
        chapterId: 'ootp_ch3',
        timeCostDays: 3,
        setup:
            '期末之前最后一次集会，练到很晚。'
            '灯只剩一盏，垫子上坐满了人。'
            '有人说再来一次，大家都同意了。'
            '这一晚没有人先走。',
        ambient: [
          '屋里热得厉害，窗户开了一条缝。',
          '有人在墙角把每个人练习的次数记在手上。',
          '结束的时候有人鼓了一下掌，很快被按住了。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'stay_to_last',
            text: '留到最后，把场地收拾干净',
            consequence:
                '你等所有人都走了才开始收垫子。'
                '有两个人留下来帮你，你们谁也没说话。'
                '锁门的时候你在里面站了一会儿——'
                '这间屋子明天就不属于你们了，但今晚还是。',
            effect: StoryEffect(
              addKnowledge: ['ootp_da_room_memory'],
              setFlags: ['ootp_stayed_to_last'],
              spirit: 4,
              affection: 3,
              housePoints: 2,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'promise_to_continue',
            text: '跟几个人约好：寒假回来接着办',
            consequence:
                '你们把手叠在一起，谁都没说话，只是互相看了一眼。'
                '这不是什么正式的誓言，但后来谁都没忘。'
                '开学第一周，就有人来问你什么时候开始。',
            effect: StoryEffect(
              addKnowledge: ['ootp_da_continues'],
              setFlags: ['ootp_made_a_promise'],
              affection: 5,
              reputation: 2,
              housePoints: 3,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'teach_someone',
            text: '临走前把今天学的教给一个新来的',
            consequence:
                '你把那个人叫住，用最后十分钟把要点说了一遍。'
                '他学得很慢，你就又说了第二遍。'
                '你们是最后两个离开的。',
            effect: StoryEffect(
              addKnowledge: ['ootp_passed_it_on'],
              setFlags: ['ootp_taught_newcomer'],
              affection: 4,
              housePoints: 3,
              energy: -3,
            ),
            nextStepId: '',
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch3_before_break',
        chapterId: 'ootp_ch3',
        timeCostDays: 2,
        setup:
            '放假前的最后一晚，有人把留下的几个人叫到一起。'
            '说的是很实际的事：谁留校、谁回家、'
            '下学期开工的暗号改成什么、出了事找谁。'
            '没有人提那些更大的问题。',
        ambient: [
          '有人把暗号写在手心，写完又擦掉了。',
          '留校的人比预计的少。',
          '窗外在下雪，屋里没人往外看。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'stay_and_hold',
            text: '报名留校，把地方守住',
            consequence:
                '你报了名字。'
                '整个寒假，那间屋子每周开门一次，只有三四个人来。'
                '你们练得不多，但谁都没有让它空着。',
            effect: StoryEffect(
              addKnowledge: ['ootp_held_over_break'],
              setFlags: ['ootp_stayed_over_break'],
              reputation: 4,
              housePoints: 4,
              spirit: -2,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'go_home_rest',
            text: '回家休息，把精神养回来',
            consequence:
                '你回了家，睡了很多，把课本翻了一遍。'
                '开学的时候你是那几个人里精神最好的一个。'
                '有人开玩笑说你偷懒，你说不然撑不到期末。',
            effect: StoryEffect(
              setFlags: ['ootp_rested_over_break'],
              spirit: 5,
              satiety: 6,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'carry_the_word',
            text: '回家路上，把消息带给该知道的人',
            consequence:
                '你绕了一段路，去了两个地方，说了三句话。'
                '没有人让你这么做，你也没跟任何人报备。'
                '寒假结束后有三个你不认识的人来敲门，'
                '报的暗号是对的。',
            effect: StoryEffect(
              addKnowledge: ['ootp_carried_word'],
              setFlags: ['ootp_carried_word'],
              reputation: 3,
              affection: 3,
              energy: -4,
              housePoints: 3,
            ),
            nextStepId: '',
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch3_growth',
        canonRefId: 'canon_ootp_inspection',
        chapterId: 'ootp_ch3',
        timeCostDays: 1,
        setup:
            '第四次集会时，屋里已经站了三十几个人。'
            '有人开始能连续挡住三次攻击，'
            '也有人第一次承认：原来自己没那么笨。',
        ambient: [
          '垫子不够用了，有人从宿舍抱来了毯子。',
          '墙上贴了一张进度表，画满了对勾。',
          '两个学院的人第一次坐在一起切磋。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'pair_up',
            text: '主动找那个总是一个人练的人组队',
            consequence:
                '你跟那个总落单的人组了队。'
                '六周后他挡下了人生第一个咒，'
                '转头看你的那一下，比任何成绩都值。',
            effect: StoryEffect(
              setFlags: ['ootp_da_active'],
              reputation: 2,
              affection: 3,
              spirit: 3,
              targetNpcId: 'neville',
            ),
          ),
          StoryChoiceDef(
            id: 'archive_progress',
            text: '维护那张进度表，记录每个人的成长',
            consequence:
                '你把进度表维护到了年底。'
                '那张纸后来成了小组唯一的成绩单——'
                '它证明这一年的进步是真的。',
            effect: StoryEffect(
              addItems: ['计划书'],
              addKnowledge: ['ootp_da_roster'],
              setFlags: ['ootp_da_active', 'ootp_owls_focus'],
              reputation: 1,
              spirit: 2,
            ),
          ),
          StoryChoiceDef(
            id: 'recruit_carefully',
            text: '帮着甄别新人，别让不靠谱的人混进来',
            consequence:
                '你参与筛选了三个新人，其中两个留下了。'
                '你学会了一件课本上没有的事：'
                '信任需要门槛，也需要给得起。',
            effect: StoryEffect(
              setFlags: ['ootp_da_active', 'ootp_da_watch'],
              reputation: 2,
              spirit: 1,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第四章 · 圣诞与禁令（1995 年 12 月 - 1996 年 1 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'ootp_ch4',
    bookId: 'ootp',
    ordinal: 4,
    title: '圣诞与禁令',
    steps: [
      StoryStepDef(
        id: 'ootp_ch4_christmas',
        canonRefId: 'canon_ootp_da_meetings',
        chapterId: 'ootp_ch4',
        timeCostDays: 31,
        setup:
            '五年级的圣诞来得没什么气氛。'
            '礼堂的装饰照旧，但每个人心里都装着别的事。'
            '有人想回家，有人不敢回。',
        ambient: [
          '寄回家的信今年要过一道检查。',
          '有人的包裹被拆开过，封口贴着重封的痕迹。',
          '你在礼堂角落看见有人在偷偷练手语。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'stay_and_train',
            text: '留校，把假期用来加练',
            consequence:
                '你留下了，假期里小组偷偷加了三次练。'
                '你在那三次里补上了最弱的一门，'
                '开学时已经能教别人了。',
            effect: StoryEffect(
              setFlags: ['ootp_da_active', 'ootp_owls_focus'],
              reputation: 2,
              spirit: 3,
            ),
            nextStepId: 'ootp_ch4_holiday',),
          StoryChoiceDef(
            id: 'visit_hospital',
            text: '假期去看望还住在圣芒戈的人',
            consequence:
                '你去了医院。那个人认得出你，却说不出完整的话。'
                '你在床边坐了一小时，'
                '出来时第一次真正明白这场仗意味着什么。',
            effect: StoryEffect(
              setFlags: ['ootp_stood_for_truth'],
              addKnowledge: ['ootp_hospital_visit'],
              reputation: 2,
              spirit: -2,
              affection: 2,
              targetNpcId: 'mcgonagall',
            ),
            nextStepId: 'ootp_ch4_holiday',),
          StoryChoiceDef(
            id: 'write_home_careful',
            text: '给家里写一封字斟句酌的信',
            consequence:
                '你写了七遍才寄出。信里只说课业、天气和伙食，'
                '一个字都没提城堡里发生的事。'
                '年后的回信里，妈妈说"你长大了"。',
            effect: StoryEffect(
              addItems: ['手写贺卡'],
              setFlags: ['ootp_complied'],
              spirit: 2,
            ),
            nextStepId: 'ootp_ch4_holiday',),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch4_holiday',
        chapterId: 'ootp_ch4',
        timeCostDays: 7,
        setup:
            '圣诞假期留校的人比往年多，大概是都不想回家。大礼堂的树照旧摆着，但没多少人去看。',
        ambient: [
          '有人把收到的礼物堆在床边，一件都没拆。',
          '厨房的伙食比平时丰盛。',
          '走廊里那几个穿粉色的人假期也没休息。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'open_gifts',
            text: '把礼物一件件拆开，给送礼的人回信',
            consequence:
                '你拆了很久。其中有一件是你没想到的，包装很糙，但那个东西你后来一直留着。',
            nextStepId: '',
            effect: StoryEffect(addItems: ['手写贺卡'], setFlags: ['ootp_opened_gifts'], spirit: 5),
          ),
          StoryChoiceDef(
            id: 'leave_unopened',
            text: '先放着，等学期结束再说',
            consequence:
                '你把那堆东西推到了床底下。有些好意你现在接不住。也许以后可以。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['ootp_left_gifts'], spirit: -1),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch4_raid',
        chapterId: 'ootp_ch4',
        timeCostDays: 6,
        setup:
            '一月的一个晚上，集会进行到一半，'
            '走廊尽头传来了脚步声——不只一个人。'
            '望风的人来不及喊，灯先灭了。',
        ambient: [
          '垫子被踢翻的声音在黑暗里特别响。',
          '有人从窗户翻了出去，落在了草地上。',
          '你踩到了什么软的东西，没敢低头看。',
        ],
        choices: [
          // 【条件选项】只有先前真的把教育令的条款一条条比对过
          // （ootp_edict_contradictions，ch2 的情报线）的人，才会知道
          // 搜查本身不合规——这条出路是对"提前做功课"的回报。
          StoryChoiceDef(
            id: 'cite_the_rules',
            text: '引用教育令的条例，拖住他们几分钟',
            requireKnowledge: ['ootp_edict_contradictions'],
            consequence:
                '你站在门口，一条一条地把教育令念了出来——'
                '第几条允许抽查，第几条不允许翻私人箱柜。'
                '领头的那个愣了两秒，这两秒里窗户那边的人全跑干净了。'
                '你后来才知道，有几十个人是因为这两秒才没被记名字。',
            effect: StoryEffect(
              setFlags: ['ootp_da_active', 'ootp_protected_others', 'ootp_rule_lawyer'],
              addKnowledge: ['ootp_rules_as_shield'],
              reputation: 4,
              spirit: 2,
            ),
            nextStepId: 'ootp_ch4_raid_after',
          ),
          StoryChoiceDef(
            id: 'cover_escape',
            text: '拦住门口那一下，给大家多十秒',
            consequence:
                '你用身体顶住了门。十秒，只撑了十秒，'
                '但那十秒里跑掉了十几个人。'
                '你被记了名字，也因此第一次在名单上有了自己的条目。',
            effect: StoryEffect(
              setFlags: ['ootp_da_active', 'ootp_detention'],
              reputation: 3,
              spirit: -1,
            ),
            nextStepId: 'ootp_ch4_raid_after',),
          StoryChoiceDef(
            id: 'grab_roster',
            text: '先把那张名单抢下来再跑',
            consequence:
                '你扑过去把名单抓在手里，'
                '从窗口翻出去时还攥着它。'
                '第二天那张纸变成了灰——但没人因此被叫去谈话。',
            effect: StoryEffect(
              setFlags: ['ootp_da_active', 'ootp_protected_others'],
              addItems: ['计划书'],
              reputation: 3,
              spirit: 1,
            ),
            nextStepId: 'ootp_ch4_raid_after',),
          StoryChoiceDef(
            id: 'run_first',
            text: '跟着人流往外跑',
            consequence:
                '你跑了。跑得比谁都快，'
                '回宿舍后心跳了整整一小时。'
                '你没有做错什么——但你知道自己没做到最好。',
            effect: StoryEffect(
              setFlags: ['ootp_da_active'],
              addKnowledge: ['ootp_fled_raid'],
              spirit: -2,
            ),
            nextStepId: 'ootp_ch4_raid_after',),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch4_raid_after',
        chapterId: 'ootp_ch4',
        timeCostDays: 6,
        setup:
            '搜查的事情传开以后，公共休息室里的东西少了很多。有人把书藏到了床垫底下。有人低声说，下个星期可能还要再来一次。',
        ambient: [
          '走廊里有几间教室的门被贴了封条。',
          '有人在收拾抽屉，动作很快。',
          '窗外的雪停了，天还是灰的。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'help_hide',
            text: '帮朋友把东西藏起来',
            consequence:
                '你们把东西分成了几份，分别放在几个人身上。做完之后谁也没说话，但都笑了一下。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['ootp_helped_hide'], spirit: 3, targetNpcId: 'ginny', affection: 2),
          ),
          StoryChoiceDef(
            id: 'stay_clear',
            text: '不参与，把自己的东西理清楚',
            consequence:
                '你把自己的抽屉从头到尾理了一遍。该扔的扔，该留的收好。你想，至少自己的这一格是干净的。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['ootp_stayed_clear'], spirit: 1),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch4_aftermath',
        chapterId: 'ootp_ch4',
        timeCostDays: 6,
        setup:
            '搜查之后，集会被迫停了三周。'
            '城堡里开始互相打量：'
            '那天晚上是谁开的门？名单是怎么泄露的？',
        ambient: [
          '走廊上的低语在你走近时会停。',
          '有人的名字被人用指甲划掉了。',
          '小组里第一次出现了不信任的眼神。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'defend_friend',
            text: '有人被无端怀疑，你站出来替他说话',
            consequence:
                '你替那个被怀疑的人说了话，'
                '说了三分钟，把那天晚上他一直在你旁边的事实讲清楚。'
                '怀疑散了，而你们从此是真的朋友。',
            effect: StoryEffect(
              setFlags: ['ootp_protected_others'],
              reputation: 3,
              affection: 3,
              spirit: 2,
              targetNpcId: 'dean',
            ),
          ),
          StoryChoiceDef(
            id: 'hunt_mole',
            text: '自己私下排查到底是谁告的密',
            consequence:
                '你查了三周，列出三个嫌疑人，'
                '一个都没查实。最后你停下来了——'
                '怀疑会传染，而你已经开始怀疑朋友了。',
            effect: StoryEffect(
              addKnowledge: ['ootp_mole_hunt'],
              setFlags: ['ootp_da_watch'],
              spirit: -2,
            ),
          ),
          StoryChoiceDef(
            id: 'restart_group',
            text: '不去追查，先把集会重新组织起来',
            consequence:
                '你挨个联系，换了地点、改了暗号、'
                '把警戒从两个人加到四个人。'
                '三周后集会重新开始，到场的人比之前还多。',
            effect: StoryEffect(
              setFlags: ['ootp_da_active', 'ootp_protected_others'],
              reputation: 3,
              spirit: 3,
              affection: 2,
              targetNpcId: 'ginny',
            ),
          ),
        ],
      ),

      StoryStepDef(
        id: 'ootp_ch4_informant',
        canonRefId: 'canon_ootp_betrayal',
        chapterId: 'ootp_ch4',
        timeCostDays: 6,
        setup:
            '小组的活动被人报上去了。'
            '名单上多出来的那个名字，'
            '是上周还在帮你收风的一个。'
            '没有人当面对质——'
            '只是从某天开始，'
            '走廊里的问候少了，'
            '有人换座位，有人不再抬头。',
        ambient: [
          '那个人的柜子里被塞了东西，第二天又被清空了。',
          '有人在课桌上刻了个词，很快被人用墨水涂掉。',
          '小组的活动地点换了第三次，没人再写在纸上。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'confront',
            text: '当面去问清楚',
            consequence:
                '你把他堵在楼梯口。'
                '他说了实话：家里人被威胁了。'
                '你没骂他，也没原谅他，'
                '只是从此把该藏的都藏得更深了一点点。',
            effect: StoryEffect(
              setFlags: ['ootp_confronted_informant'],
              addKnowledge: ['ootp_real_pressure'],
              spirit: -3,
            ),
            nextStepId: 'ootp_ch4_trust',
          ),
          StoryChoiceDef(
            id: 'protect_group',
            text: '先改规则，把小组变得更难被出卖',
            consequence:
                '你把小组拆成了三个互不知道彼此存在的圈子。'
                '每个人只知道自己的那一圈。'
                '这样即使再有人开口，'
                '能伤到的也只有三分之一。',
            effect: StoryEffect(
              setFlags: ['ootp_cell_structure'],
              addKnowledge: ['ootp_compartmentalised'],
              reputation: 2,
              spirit: -1,
            ),
            nextStepId: 'ootp_ch4_trust',
          ),
          StoryChoiceDef(
            id: 'let_it_be',
            text: '什么都不做，照常去上课',
            consequence:
                '你没有去找他，也没有改组里的规矩。'
                '接下来两周，'
                '每个人都自己决定要跟谁说话。'
                '小组没有散，'
                '但那种"我们是一伙的"的感觉，'
                '再也没有回来。',
            effect: StoryEffect(
              setFlags: ['ootp_group_cooled'],
              spirit: -4,
            ),
            nextStepId: 'ootp_ch4_trust',
          ),
        ],
      ),

      StoryStepDef(
        id: 'ootp_ch4_trust',
        chapterId: 'ootp_ch4',
        timeCostDays: 4,
        setup:
            '有人开口之后，剩下的人反而知道该怎么办了。'
            '那天晚上，几个人在公共休息室的角落里坐到很晚，'
            '把能说的都说了一遍——包括各自家里收到过什么信。',
        ambient: [
          '有人把一直瞒着的事说了出来，说完长长地呼了口气。',
          '壁炉的火快灭了，没人去添。',
          '有人问你：接下来还练不练。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'keep_going',
            text: '"练。但以后只练有用的。"',
            consequence:
                '你说完这句话，屋里安静了两秒，'
                '然后有人点头，有人笑了一声。'
                '第二天，练习照旧——'
                '只是从此没人再把名字写在任何地方。',
            effect: StoryEffect(
              setFlags: ['ootp_da_active', 'ootp_protected_others'],
              reputation: 3,
              spirit: 3,
              affection: 2,
              targetNpcId: 'ginny',
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'pause_for_owls',
            text: '"先停一停吧，考试要紧。"',
            consequence:
                '你说停，没人反对。'
                '练习停了三个月，'
                '等再想重新开始的时候，'
                '有几个人已经找不回来了。',
            effect: StoryEffect(
              setFlags: ['ootp_da_paused'],
              addKnowledge: ['ootp_da_paused_cost'],
              spirit: -1,
            ),
            nextStepId: '',
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第五章 · O.W.L.s 与春天（1996 年 2-5 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'ootp_ch5',
    bookId: 'ootp',
    ordinal: 5,
    title: 'O.W.L.s 与春天',
    steps: [
      StoryStepDef(
        id: 'ootp_ch5_revision',
        chapterId: 'ootp_ch5',
        timeCostDays: 4,
        setup:
            '二月开始，图书馆的开门时间提前了一个小时。'
            '五年级的人集体消失了——'
            '如果你在走廊上看见一个眼神发直的人，那一定是五年级的。',
        ambient: [
          '有人在羊皮纸上贴满了彩色标签，五颜六色。',
          '有位教授主动开了三次义务答疑，座无虚席。',
          '你把咖啡当水喝，喝到第三周开始失眠。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'study_group_da',
            text: '跟小组的人组复习局，边复习边警戒',
            consequence:
                '你们把复习和集会合并了：一半时间背咒语，'
                '一半时间练实操。那六周里你既过了科目，'
                '也第一次教了别人——教才是最好的学。',
            effect: StoryEffect(
              setFlags: ['ootp_owls_focus', 'ootp_da_active'],
              addItems: ['标准咒语书', '提神剂'],
              reputation: 2,
              spirit: 2,
              affection: 2,
              targetNpcId: 'hermione',
            ),
            nextStepId: 'ootp_ch5_group_study',),
          StoryChoiceDef(
            id: 'solo_sprint',
            text: '一个人闭关，按计划表死磕',
            consequence:
                '你按计划表闭关了六周，中间只出过三次门。'
                '考完那天你走出图书馆，'
                '发现外面的树已经全绿了。',
            effect: StoryEffect(
              setFlags: ['ootp_owls_focus'],
              addItems: ['提神剂', '计划书'],
              reputation: 1,
              spirit: 1,
            ),
            nextStepId: 'ootp_ch5_group_study',),
          StoryChoiceDef(
            id: 'help_others_revise',
            text: '把自己的笔记印给别人，边给边讲',
            consequence:
                '你印了二十份笔记，讲到嗓子哑。'
                '考完有六个人来谢你，'
                '其中三个说："要不是你那张表，我这科就挂了。"',
            effect: StoryEffect(
              setFlags: ['ootp_owls_focus', 'ootp_protected_others'],
              addItems: ['羊皮纸一包', '新羽毛笔'],
              reputation: 3,
              affection: 2,
              spirit: 2,
              targetNpcId: 'susan',
            ),
            nextStepId: 'ootp_ch5_group_study',),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch5_group_study',
        chapterId: 'ootp_ch5',
        timeCostDays: 3,
        setup:
            '考试临近，有人把课本上的东西重新分了一遍。不按章节分，按"考试会不会考"分。屋里的人都在埋头写字，没什么人说话。',
        ambient: [
          '有人把三本笔记订成了一本。',
          '靠窗的位置总是最先被坐满。',
          '有人在桌上画了张很长的图，画到桌角外面去了。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'join_review',
            text: '加入他们，把最难的部分分给自己',
            consequence:
                '你挑了最没人愿意碰的那一章。啃了两天，居然真让你理出了头绪。讲给别人的时候你自己也清楚了不少。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['ootp_reviewed'], setFlags: ['ootp_led_review'], spirit: 5),
          ),
          StoryChoiceDef(
            id: 'self_study',
            text: '自己按自己的节奏来',
            consequence:
                '你没有加入任何一组。按自己的顺序把书过了一遍，最后合上书的时候，居然没什么可慌的。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['ootp_reviewed'], setFlags: ['ootp_self_study'], spirit: 3),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch5_club',
        canonRefId: 'canon_ootp_club',
        chapterId: 'ootp_ch5',
        timeCostDays: 3,
        setup:
            '三月，公告板上的教育令已经贴满了一整面墙。'
            '有人想办一个「课外小组」，'
            '问你要不要一起去递申请——'
            '按规定，这类团体要报备，'
            '而报备意味着要把成员名单交上去。',
        ambient: [
          '公告板前面的墙被人用尺子量过，说是刚好贴满。',
          '有人提议把名字写成绰号，被否掉了。',
          '走廊尽头，高级调查官办公室的门开着一条缝。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'apply_officially',
            text: '按规矩递申请，把名单交上去',
            consequence:
                '批下来了，条件是"活动内容需经审查"。'
                '你们每周三下午在空教室里读报纸，'
                '读那些被印出来的部分。'
                '至少，这件事是允许的。',
            effect: StoryEffect(
              setFlags: ['ootp_club_approved'],
              addItems: ['课外小组批准函'],
              reputation: 2,
            ),
            nextStepId: 'ootp_ch5_exams',
          ),
          StoryChoiceDef(
            id: 'skip_paperwork',
            text: '不报备，改成"几个朋友一起复习"',
            consequence:
                '你们没交任何东西，只是每周在同一间教室出现。'
                '没人管你们读什么——因为墙上没有你们的名字。'
                '这很有效，也很累：'
                '你们要一直装作只是"刚好坐在一起"。',
            effect: StoryEffect(
              setFlags: ['ootp_club_unofficial'],
              addKnowledge: ['ootp_no_paper_trail'],
              spirit: -1,
            ),
            nextStepId: 'ootp_ch5_exams',
          ),
          StoryChoiceDef(
            id: 'put_it_off',
            text: '算了，这学期不折腾这个',
            consequence:
                '你说算了。'
                '接下来的几个月，公告板上的纸越来越多，'
                '而你们什么都没做。'
                '学期末你想起来，已经不记得当初想办的是什么了。',
            effect: StoryEffect(
              setFlags: ['ootp_club_dropped'],
              spirit: -2,
            ),
            nextStepId: 'ootp_ch5_exams',
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch5_exams',
        chapterId: 'ootp_ch5',
        timeCostDays: 12,
        setup:
            '考场设在大礼堂。桌子摆成一行行，'
            '每张桌上放着一支羽毛笔和一瓶墨水，'
            '上午理论，下午实操——实操由一位外部考官看着。',
        ambient: [
          '有人把墨水打翻在卷子上，当场哭了。',
          '下午的实操考场外面排着长队，安静得可怕。',
          '你交卷时手是抖的，但脑子是空的——那感觉很怪。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'exam_focus',
            text: '把每场都当成最后一场来考',
            consequence:
                '你考完了十一场，每场都用尽全力。'
                '最后一场结束时你在桌上趴了五分钟，'
                '然后站起来去吃了两盘晚饭。',
            effect: StoryEffect(
              setFlags: ['ootp_exams_done', 'ootp_owls_focus'],
              reputation: 2,
              spirit: 2,
            ),
          ),
          StoryChoiceDef(
            id: 'calm_others',
            text: '开考前帮旁边的人稳住情绪',
            consequence:
                '每场开考前你都会对旁边的人说一句"你能行"。'
                '考完最后一场，那个人跑来跟你说：'
                '"你那句话我记了十一场。"',
            effect: StoryEffect(
              setFlags: ['ootp_exams_done', 'ootp_protected_others'],
              reputation: 3,
              affection: 3,
              spirit: 2,
              targetNpcId: 'parvati',
            ),
          ),
          StoryChoiceDef(
            id: 'watch_proctors',
            text: '留意考官席上那些陌生脸孔的举动',
            consequence:
                '你注意到那位外部考官在实操考试上'
                '特别留意几个学生的表现，还做了记录。'
                '你把这件事写进了本子——它后来被证明是有用的。',
            effect: StoryEffect(
              setFlags: ['ootp_exams_done', 'ootp_da_watch'],
              addKnowledge: ['ootp_examiner_notes'],
              reputation: 1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch5_st_mungo',
        canonRefId: 'canon_ootp_career_advice',
        chapterId: 'ootp_ch5',
        timeCostDays: 11,
        setup:
            '春天有一次机会跟着去圣芒戈。'
            '那栋楼从外面看是一间旧百货商店，'
            '橱窗里只有一个穿睡衣的假人。'
            '进门要报姓名和事由，'
            '候诊室的椅子是硬的，'
            '走廊尽头有人在哭，'
            '但哭声被门挡着，听不真切。',
        ambient: [
          '一个病人坚持认为自己是一把茶壶，见人就问要不要倒水。',
          '墙上挂着"治愈咒语伤害"的科室指示牌，箭头被擦得发白。',
          '有个床位空着，床头卡上的名字被人用指甲划花了。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'visit_long_term',
            text: '去长期病房看看那些回不了家的人',
            consequence:
                '你在长期病房待了二十分钟。'
                '有个女病人认不出任何人，'
                '却在有人提到某个名字时忽然安静下来。'
                '你出来后在楼梯间站了很久，'
                '第一次想清楚自己想学什么。',
            effect: StoryEffect(
              addKnowledge: ['ootp_longterm_ward'],
              setFlags: ['ootp_wants_healing'],
              spirit: -3,
              reputation: 2,
            ),
            nextStepId: 'ootp_ch5_unease',
          ),
          StoryChoiceDef(
            id: 'talk_therapist',
            text: '找治疗师问几个正经问题',
            consequence:
                '你问了三个问题，得到了两个答案和一个"这个不能告诉你"。'
                '那个不能告诉你的，'
                '恰恰是你最想知道的。'
                '但你拿到了一个名字——'
                '一个以后可能会用得上的人。',
            effect: StoryEffect(
              addKnowledge: ['ootp_healer_contact'],
              setFlags: ['ootp_career_healer'],
              reputation: 1,
            ),
            nextStepId: 'ootp_ch5_unease',
          ),
          StoryChoiceDef(
            id: 'leave_fast',
            text: '办完事就出来，不往别的病房去',
            consequence:
                '你在候诊室坐了一小时，'
                '拿完东西就出来了。'
                '阳光照在脸上时你松了口气，'
                '然后为这口气感到有点羞愧。',
            effect: StoryEffect(
              spirit: -1,
            ),
            nextStepId: 'ootp_ch5_unease',
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch5_unease',
        chapterId: 'ootp_ch5',
        timeCostDays: 35,
        setup:
            '考完之后本该轻松，但城堡里反而更紧了。'
            '有教授在夜里匆匆离开，'
            '也有学生在食堂忽然压低了声音。',
        ambient: [
          '教工席上又空了两个位置。',
          '走廊上出现了一支从没见过的巡逻队。',
          '你连续三晚梦见了同一个走廊转角。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'keep_contacts',
            text: '跟小组的人约好：有情况立刻互相通知',
            consequence:
                '你们约了一套暗号：'
                '图书馆第三排书架放一支红羽毛笔，代表有急事。'
                '三天后那支笔出现了。',
            effect: StoryEffect(
              setFlags: ['ootp_da_active', 'ootp_da_watch', 'ootp_kept_vigil'],
              reputation: 2,
              spirit: 1,
            ),
          ),
          StoryChoiceDef(
            id: 'pack_go_bag',
            text: '悄悄收拾一个随时能带走的小包',
            consequence:
                '你收拾了一个小包：魔杖、干粮、一小瓶白鲜、'
                '还有去年那张写着"我在场"的纸。'
                '你把它塞在床底下，谁也没告诉。',
            effect: StoryEffect(
              addItems: ['白鲜香精'],
              setFlags: ['ootp_kept_vigil'],
              spirit: -1,
            ),
          ),
          StoryChoiceDef(
            id: 'pretend_normal',
            text: '假装一切照常，按部就班过日子',
            consequence:
                '你照常吃饭、睡觉、整理行李。'
                '假装正常本身就是一种力气活——'
                '你做到了，只是每天都很累。',
            effect: StoryEffect(
              setFlags: ['ootp_complied'],
              spirit: 1,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第六章 · 神秘事务司（1996 年 6 月）→ canon_ootp_ministry_battle
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'ootp_ch6',
    bookId: 'ootp',
    ordinal: 6,
    title: '神秘事务司',
    steps: [
      StoryStepDef(
        id: 'ootp_ch6_owl_results',
        canonRefId: 'canon_ootp_owl_exam_week',
        chapterId: 'ootp_ch6',
        timeCostDays: 34,
        setup:
            'O.W.L. 的成绩在学期末一个早上发下来。'
            '猫头鹰成群结队地落在礼堂，'
            '每封信落下来都会有人当场拆开。'
            '有人跳起来，有人走出去，'
            '大部分人是看一眼就折好收进口袋。',
        ambient: [
          '你旁边的人盯着自己那张纸看了很久，然后什么也没说。',
          '有教授在教师席上朝某个方向点头。',
          '礼堂出口那段路上，有人一直在擦眼睛。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'open_publicly',
            text: '当着大家的面拆开',
            consequence:
                '你拆开看了，然后把它举起来给大家看了一眼。'
                '不高不低，'
                '但足够让关心你的人放心。'
                '那天之后，有人开始向你问问题。',
            effect: StoryEffect(
              addItems: ['O.W.L. 成绩单'],
              setFlags: ['ootp_owl_shared'],
              reputation: 2,
              spirit: 3,
            ),
            nextStepId: 'ootp_ch6_departure',
          ),
          StoryChoiceDef(
            id: 'read_privately',
            text: '拿到手先揣着，回宿舍再看',
            consequence:
                '你把信揣了一整天。'
                '晚上拆开的时候，'
                '宿舍里只有你一个人。'
                '你把这个数字记住了，'
                '没告诉任何人——包括你自己将来想告诉的人。',
            effect: StoryEffect(
              addItems: ['O.W.L. 成绩单'],
              setFlags: ['ootp_owl_private'],
              spirit: 1,
            ),
            nextStepId: 'ootp_ch6_departure',
          ),
          StoryChoiceDef(
            id: 'help_others',
            text: '先去安慰那些考砸了的人',
            consequence:
                '你陪三个人在湖边坐了一下午。'
                '你一句安慰的话都没说出口，'
                '只是和他们一起坐着。'
                '天黑的时候，其中一个忽然说"谢谢你"。',
            effect: StoryEffect(
              setFlags: ['ootp_comforted_peers'],
              affection: 4,
              spirit: -2,
              targetNpcId: 'neville',
            ),
            nextStepId: 'ootp_ch6_departure',
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch6_departure',
        chapterId: 'ootp_ch6',
        timeCostDays: 6,
        setup:
            '六月的某一天，几个人忽然不见了。'
            '他们的床铺是空的，书还摊在桌上，'
            '而傍晚时分，城堡里几乎所有教授都不见了。',
        ambient: [
          '有人看见他们在走廊尽头跑，方向是壁炉房。',
          '级长被要求清点人数，脸色很白。',
          '你站在楼梯口，忽然不知道该做什么。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'gather_who_left',
            text: '把离开的人名字一个个记下来',
            consequence:
                '你记了六个名字。'
                '你不知道他们去了哪里，但你知道——'
                '如果有人要问起，这份名单就是证据。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包'],
              addKnowledge: ['ootp_departed_list'],
              setFlags: ['ootp_kept_vigil', 'ootp_heard_news'],
              spirit: -1,
            ),
          ),
          StoryChoiceDef(
            id: 'hold_the_room',
            text: '把低年级生集中在公共休息室，别让他们乱跑',
            consequence:
                '你把十几个低年级生聚到休息室，'
                '生着火，讲了一晚上的无聊故事。'
                '他们睡了，你守到天亮。',
            effect: StoryEffect(
              setFlags: ['ootp_protected_others', 'ootp_kept_vigil'],
              reputation: 3,
              spirit: 1,
            ),
          ),
          StoryChoiceDef(
            id: 'go_look',
            text: '偷偷溜出去，往壁炉房方向看一眼',
            consequence:
                '你溜到了走廊尽头，只看见一个空荡的壁炉'
                '和地上一小撮飞路粉。'
                '你伸手摸了摸，还是热的。',
            effect: StoryEffect(
              setFlags: ['ootp_kept_vigil'],
              addKnowledge: ['ootp_empty_fireplace'],
              spirit: -2,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch6_waiting',
        chapterId: 'ootp_ch6',
        timeCostDays: 6,
        setup:
            '那一夜没有人睡。公共休息室里坐满了人，'
            '谁也不说话，只在有人推门时集体抬头。'
            '壁炉里的火苗偶尔蹿一下，让所有人同时转头。',
        ambient: [
          '钟摆的声音在安静里显得特别重。',
          '有人把去年那枚徽章攥在手心里。',
          '你数着时间：一小时、两小时、四小时。',
        ],
        choices: [
          // 【条件选项】参加过集会、知道那些人是谁的人，这一夜才有
          // "具体要等谁"的概念；只是在走廊上听说过传闻的人，等的是
          // 一个模糊的消息，而不是六个具体的人。
          StoryChoiceDef(
            id: 'wait_named',
            text: '把那几个名字在心里默念了一遍又一遍',
            requireAnyFlags: ['ootp_da_active', 'ootp_cell_structure'],
            consequence:
                '你把名字念了一遍：六个。'
                '念到第三个的时候你才意识到，'
                '其中有两个你其实没说过几句话——'
                '但这一年里，你和他们一起练过、跑过、被记过。'
                '那一夜你等的是六个具体的人，'
                '不是一条模糊的消息。',
            effect: StoryEffect(
              setFlags: ['ootp_kept_vigil', 'ootp_knew_them'],
              addKnowledge: ['ootp_six_names'],
              affection: 3,
              spirit: -2,
            ),
            nextStepId: 'ootp_ch6_before_news',
          ),
          StoryChoiceDef(
            id: 'keep_fire',
            text: '守着火，一夜不让它灭',
            consequence:
                '你守了一夜的火。天亮时有人接了班，'
                '你才发现自己的手被火星燎了三个泡。'
                '"火不能灭"——那晚所有人都这么想。',
            effect: StoryEffect(
              setFlags: ['ootp_kept_vigil', 'ootp_protected_others'],
              reputation: 2,
              spirit: -1,
            ),
            nextStepId: 'ootp_ch6_before_news',),
          StoryChoiceDef(
            id: 'write_letters',
            text: '给那几个人各写一封没寄出的信',
            consequence:
                '你写了六封，都没寄。'
                '信里只有一句相同的话：'
                '"等你回来，我们有话要说。"',
            effect: StoryEffect(
              addItems: ['手写贺卡'],
              addKnowledge: ['ootp_unsent_letters'],
              setFlags: ['ootp_kept_vigil'],
              spirit: -2,
            ),
            nextStepId: 'ootp_ch6_before_news',),
          StoryChoiceDef(
            id: 'sleep_somehow',
            text: '逼自己睡一会儿，别拖垮身体',
            consequence:
                '你强迫自己睡了三个小时。'
                '醒来时事情已经结束——'
                '你后来一直庆幸自己当时是清醒的。',
            effect: StoryEffect(
              setFlags: ['ootp_kept_vigil'],
              spirit: 2,
            ),
            nextStepId: 'ootp_ch6_before_news',),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch6_before_news',
        chapterId: 'ootp_ch6',
        timeCostDays: 5,
        setup:
            '等消息的那几天，学校里没人能安下心做事。有人一遍遍往校门方向走，有人干脆在门厅里坐着，谁也不肯散。',
        ambient: [
          '有人把写好的信又撕了，说等有消息再写。',
          '医疗翼的灯一直亮着。',
          '夜里的风里带着一点烧焦的味道。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'wait_outside',
            text: '在门厅外面等着，不愿回宿舍',
            consequence:
                '你站了很久，脚都麻了。有人来劝你回去，你摇了摇头。后来你才发现，那天晚上很多人在不同的地方做同一件事。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['ootp_waited_all_night'], spirit: -3),
          ),
          StoryChoiceDef(
            id: 'write_it_down',
            text: '回宿舍，把这一年的事写下来',
            consequence:
                '你写了整整两页，写完自己读了一遍。有些事写下来以后反而没那么重了。你把纸折好收了起来，然后才躺下。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['ootp_wrote_it_down'], spirit: 2),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch6_news',
        chapterId: 'ootp_ch6',
        timeCostDays: 5,
        canonRefId: 'canon_ootp_ministry_battle',
        setup:
            '天亮之后消息才来：他们去了魔法部，'
            '在那里和一群人正面撞上。'
            '回来的人有的拄着拐，有的没有回来。',
        ambient: [
          '餐厅里那天没有人说话，只有勺子碰盘子的声音。',
          '报纸第二天全变了口径，一夜之间换了说法。',
          '有人把去年那张"我在场"的纸翻了出来。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'believe_them',
            text: '不管报纸怎么说，你选择相信他们',
            consequence:
                '你把这句话说给了三个人听，'
                '第二天变成了十个人，'
                '一周后整个年级都知道了：我们亲眼看见的才算。',
            effect: StoryEffect(
              setFlags: ['ootp_stood_for_truth', 'ootp_heard_news'],
              reputation: 3,
              spirit: 2,
              affection: 2,
              targetNpcId: 'seamus',
            ),
          ),
          StoryChoiceDef(
            id: 'collect_testimony',
            text: '把回来的人说的话一字不漏地记下来',
            consequence:
                '你记了整整七页。'
                '那些细节后来被人反复引用——'
                '因为当官方说法一夜间改变时，只有记录还在。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包', '新羽毛笔'],
              addKnowledge: ['ootp_battle_testimony'],
              setFlags: ['ootp_heard_news'],
              reputation: 2,
              spirit: -1,
            ),
          ),
          StoryChoiceDef(
            id: 'mourn_quietly',
            text: '什么都不做，只是安静地难过',
            consequence:
                '你什么都没做，只是坐在窗边坐了一整天。'
                '后来有人在你旁边坐下，'
                '也什么都没说——那是这一年最好的陪伴。',
            effect: StoryEffect(
              setFlags: ['ootp_heard_news'],
              spirit: -2,
              affection: 2,
              targetNpcId: 'cho',
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第七章 · 学年结束（1996 年 6 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'ootp_ch7',
    bookId: 'ootp',
    ordinal: 7,
    title: '学年结束',
    steps: [
      StoryStepDef(
        id: 'ootp_ch7_aftermath',
        chapterId: 'ootp_ch7',
        timeCostDays: 1,
        setup:
            '那件事之后的一周，城堡里发生了两件小事：'
            '粉色的公告被一张张撕了下来，'
            '而教工席上，有人回来了。',
        ambient: [
          '撕公告的人排成了一条队，一个接一个。',
          '走廊里第一次有人大声说出了那个名字。',
          '你把去年抄的二十七条教育令扔进了火里。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'tear_notice',
            text: '去撕一张公告，亲眼看着它落地',
            consequence:
                '你撕了第二十七条。'
                '纸落地那一下特别轻——'
                '原来压了你一整年的东西，重量只有这么一点。',
            effect: StoryEffect(
              setFlags: ['ootp_stood_for_truth'],
              reputation: 2,
              spirit: 3,
            ),
            nextStepId: 'ootp_ch7_silence',),
          StoryChoiceDef(
            id: 'welcome_back',
            text: '去跟回来的教授说声欢迎',
            consequence:
                '你去了。那位教授看着你，说：'
                '"我听说你们自己练了一年。"'
                '你说是。他说："那这一年就没白过。"',
            effect: StoryEffect(
              setFlags: ['ootp_da_active'],
              reputation: 2,
              affection: 3,
              spirit: 2,
              targetNpcId: 'dumbledore',
            ),
            nextStepId: 'ootp_ch7_silence',),
          StoryChoiceDef(
            id: 'burn_decrees',
            text: '把抄了一年的那份清单烧掉',
            consequence:
                '你把它烧了。火很旺，'
                '二十七条规矩在十秒内变成了灰。'
                '你看着灰烬想：记住它们的，不只是纸。',
            effect: StoryEffect(
              addKnowledge: ['ootp_burned_decrees'],
              setFlags: ['ootp_heard_news'],
              spirit: 2,
            ),
            nextStepId: 'ootp_ch7_silence',),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch7_silence',
        chapterId: 'ootp_ch7',
        timeCostDays: 1,
        setup:
            '战后那几天，城堡里安静得不像话。连平时最爱说话的人都不怎么开口了。你把脚步放得很轻，怕吵到谁。',
        ambient: [
          '有人在礼堂的角落坐了一整个下午。',
          '有几间教室的门一直关着。',
          '操场的草长得很快，没人去修剪。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'sit_with_them',
            text: '陪那些说不出话的人坐一会儿',
            consequence:
                '你坐过去，什么也没说。过了很久对方把头靠过来，你把自己的外套给了他。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['ootp_comforted'], spirit: 3, targetNpcId: 'ginny', affection: 3),
          ),
          StoryChoiceDef(
            id: 'keep_busy',
            text: '找点事做，别停下来',
            consequence:
                '你去帮忙搬东西、整理书、擦桌子。一天下来手都酸了，但至少没有一秒钟是空着的。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['ootp_kept_busy'], reputation: 2, spirit: 1),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch7_accounting',
        chapterId: 'ootp_ch7',
        timeCostDays: 1,
        setup:
            '学年最后两周，城堡里忽然开始清账。'
            '被撤的告示重新挂上，'
            '被禁的队员收到通知，'
            '被记过的名字一个个被划掉。'
            '但有些东西不是划掉就能回来的——'
            '比如那个学期里没能上完的课，'
            '和没能被救回来的人。',
        ambient: [
          '有人把撤下来的教育令收了一整套，说要留着做纪念。',
          '球场重新开了，但一个学期没人训练过，草长得不像样。',
          '公告栏上贴出补课安排，时间表排到了七月中。',
        ],
        choices: [
          // 【条件选项】这一年在校内已经有份量的人（声望 ≥ 45）才会被
          // 推举去说这件事；否则这个位置根本轮不到你，选项不显示。
          StoryChoiceDef(
            id: 'speak_for_group',
            text: '被推举去替大家把这一年的账说出来',
            minReputation: 45,
            consequence:
                '他们推你上去，因为你这一年在场的时候最多。'
                '你说了十二分钟，'
                '把被停学的、被记过的、被撤掉资格的名字一个个念了出来。'
                '有人中途鼓掌，也有人一直低着头。'
                '你说完坐下的时候，手心全是汗。',
            effect: StoryEffect(
              setFlags: ['ootp_rebuilt', 'ootp_spoke_for_all'],
              addKnowledge: ['ootp_the_year_told'],
              reputation: 5,
              affection: 3,
              spirit: 5,
            ),
            nextStepId: 'ootp_ch7_goodbye',
          ),
          StoryChoiceDef(
            id: 'help_rebuild',
            text: '报名参加暑期的球场和教室修缮',
            consequence:
                '你在球场拔了两周草，'
                '又在大礼堂擦了三天的长桌。'
                '最后一天收工时，'
                '有人把一只旧手套塞给你，'
                '说"明年还要打"。',
            effect: StoryEffect(
              setFlags: ['ootp_rebuilt'],
              reputation: 3,
              spirit: 4,
              energy: -12,
            ),
            nextStepId: 'ootp_ch7_goodbye',
          ),
          StoryChoiceDef(
            id: 'write_record',
            text: '把这一年的事完整写下来',
            consequence:
                '你写了很长的一份东西，'
                '从九月写到六月，'
                '把每个日期、每个名字、每条规定都写清楚了。'
                '你没打算给谁看——'
                '但这件事实在太容易被人改写，'
                '你想留一份自己的版本。',
            effect: StoryEffect(
              addItems: ['厚笔记本'],
              addKnowledge: ['ootp_year_record'],
              setFlags: ['ootp_kept_record'],
              spirit: 2,
            ),
            nextStepId: 'ootp_ch7_goodbye',
          ),
          StoryChoiceDef(
            id: 'go_quiet',
            text: '什么都不参与，安静地把行李收好',
            consequence:
                '你提前三天就收拾完了。'
                '最后那几天你每天去湖边坐一会儿，'
                '看着城堡，'
                '然后回宿舍睡觉。'
                '有些年，'
                '能完整地过完就已经是件不容易的事。',
            effect: StoryEffect(
              spirit: 3,
              energy: 6,
            ),
            nextStepId: 'ootp_ch7_goodbye',
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch7_goodbye',
        chapterId: 'ootp_ch7',
        timeCostDays: 1,
        setup:
            '最后几天，小组的人聚了一次——这一次不用暗号，'
            '不用望风，就在明亮的公共休息室里。'
            '有人说：明年还来吗？',
        ambient: [
          '有人把那张进度表裱了起来。',
          '有人第一次在公开场合练了一个咒。',
          '你看着屋里这些脸，数了两遍。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'promise_return',
            text: '说：来，明年还在这儿',
            consequence:
                '你说"来"。十几个人一起说了"来"。'
                '你们没有立字据，也没有宣誓——'
                '但所有人都记着这句话。',
            effect: StoryEffect(
              setFlags: ['ootp_da_active', 'ootp_protected_others'],
              reputation: 3,
              affection: 3,
              spirit: 3,
              targetNpcId: 'ginny',
            ),
          ),
          StoryChoiceDef(
            id: 'keep_roster',
            text: '把那张进度表收好带走',
            consequence:
                '你把进度表卷起来带走了。'
                '它现在是最没用、也最舍不得扔的一张纸——'
                '上面三十几个对勾，每一个都是一个人。',
            effect: StoryEffect(
              addItems: ['计划书'],
              addKnowledge: ['ootp_roster_kept'],
              setFlags: ['ootp_da_active'],
              spirit: 2,
            ),
          ),
          StoryChoiceDef(
            id: 'say_thanks',
            text: '当众对那个教了大家一年的男孩说谢谢',
            consequence:
                '你当着所有人的面说了谢谢。'
                '他愣了一下，说"该我谢你们"。'
                '那一刻屋里所有人都明白：这一年是互相教出来的。',
            effect: StoryEffect(
              setFlags: ['ootp_da_active'],
              reputation: 3,
              affection: 3,
              spirit: 3,
              targetNpcId: 'harry',
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'ootp_ch7_home',
        chapterId: 'ootp_ch7',
        timeCostDays: 1,
        setup:
            '回家的列车上，五年级的人看起来都比去年老。'
            '窗外是熟悉的田野，'
            '而你口袋里多了一张写着三十几个名字的纸。',
        ambient: [
          '有人一上车就睡着了，怎么叫都叫不醒。',
          '车厢里没人打牌，也没人串座。',
          '你把那张纸摸了三次，确认还在。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'plan_next_year',
            text: '在摇晃的桌上写下六年级要做的事',
            consequence:
                '你写了三条：继续练、继续记录、继续相信亲眼所见。'
                '写到第三条时你笑了——'
                '原来"相信"也是一件需要练习的事。',
            effect: StoryEffect(
              addItems: ['计划书'],
              addKnowledge: ['ootp_next_year_plan'],
              setFlags: ['ootp_owls_focus'],
              reputation: 2,
              spirit: 3,
            ),
          ),
          StoryChoiceDef(
            id: 'sit_together',
            text: '什么都不说，跟大家一起坐着',
            consequence:
                '你们坐了一路，谁也没说话。'
                '但每一站下车时，都会有一只手在肩膀上按一下。'
                '这比任何告别词都管用。',
            effect: StoryEffect(
              setFlags: ['ootp_protected_others'],
              reputation: 2,
              affection: 3,
              spirit: 2,
              targetNpcId: 'ron',
            ),
          ),
          StoryChoiceDef(
            id: 'watch_fields',
            text: '看窗外，把这一年在心里过一遍',
            consequence:
                '你看了三个小时的田野。'
                '这一年你被罚过、被搜过、被怀疑过，'
                '也挡下过第一个咒——你想，值了。',
            effect: StoryEffect(
              setFlags: ['ootp_heard_news'],
              addKnowledge: ['ootp_year_review'],
              spirit: 2,
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

const List<StoryEndingRule> _ootpEndings = [
  StoryEndingRule(
    id: 'ootp_ending_da_core',
    title: '名单上的第 N 个名字',
    body:
        '你加入了那个不被允许存在的教室，'
        '在告密的夜晚护住过名单，也在被搜捕之后把人一个个重新聚起来。'
        '你不是发起人，却是让它没散掉的那几个人之一。'
        '很多年后有人问起那年，你说：我在名单上，也在门口望过风。',
    requireFlags: ['ootp_joined_da', 'ootp_protected_others'],
  ),
  StoryEndingRule(
    id: 'ootp_ending_truth_teller',
    title: '说出那句话的人',
    body:
        '在所有人都不敢提那个名字的时候，你提了。'
        '你说的是"我在场"，是"我看见了"，'
        '是一句在半年里被反复引用、也被反复打压的话。'
        '六月之后，全世界终于改口——而你已经说了整整一年。',
    requireAnyFlags: ['ootp_stood_for_truth'],
    minReputation: 6,
  ),
  StoryEndingRule(
    id: 'ootp_ending_watcher',
    title: '守夜的人',
    body:
        '你挡过十秒钟的门，也守过一整夜的火。'
        '你没有冲在最前面，但每一次有人需要退路、'
        '需要暗号、需要一个不睡的人，都在。'
        '这场仗里，守夜和冲锋一样重要。',
    requireAnyFlags: ['ootp_da_watch', 'ootp_da_active'],
  ),
  StoryEndingRule(
    id: 'ootp_ending_silence',
    title: '低着头的那一年',
    body:
        '那张纸条你烧掉了，那句话你没说出口，'
        '那扇门你也没有去挡。你平平安安地读完了五年级，'
        '成绩单很干净，心里却留着一个一直没填的空格。'
        '回家的列车上你写下一句话：下一年，我要站出来。',
  ),
];

const StoryBookDef orderOfThePhoenix = StoryBookDef(
  id: 'ootp',
  title: '凤凰社',
  chapters: _ootpChapters,
  endings: _ootpEndings,
  startYear: 1995,
  startMonth: 7,
  startDay: 25,
);
