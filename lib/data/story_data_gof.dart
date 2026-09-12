/// 《火焰杯》1994-1995 · 四年级 · 剧情内容表
///
/// 【这一部的气质】前三年是"城堡里有东西在威胁你"，这一年是"整座城堡
/// 变成了一座舞台"。三强争霸赛带来了外校的船、外校的学生、外校的口音，
/// 也带来了久违的兴奋。四年级的玩家第一次可以合法地站在人群里欢呼——
/// 而年末那场比赛的最后一个项目，会让所有欢呼戛然而止。
///
/// 【与哈利线的边界】被火焰杯吐出名字的是哈利，下湖、进迷宫、触摸奖杯
/// 的都是勇士。玩家的四年级由这些组成：为本院勇士加油、在舞会上踩错
/// 舞步、在第二个项目的看台上冻得跺脚、以及在六月那个夜晚之后
/// 学会"有些胜利不值得庆祝"。年末真正发生的事，玩家是从别人
/// 的表情和第二天早上的沉默里知道的。
///
/// 【原著节点覆盖】canon_gof_announce / canon_gof_champions /
/// canon_gof_yule_ball / canon_gof_maze 四个节点各由一步剧情讲述。
library;

import 'package:hogwarts_life_simulator/models/story_progress.dart';

// ================================================================
// 《火焰杯》 1994-1995 · 四年级
//
// 【时间线】1994-07-25 开启锚点 → 1995-06 学年结束。
// 24 步 × 平均 13 天 ≈ 320 天，与 canon_gof_* 节点的月份逐一对齐。
// ================================================================

const List<StoryChapterDef> _gofChapters = [
  // --------------------------------------------------------------
  // 第一章 · 火焰杯（1994 年 9 月）→ canon_gof_announce
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'gof_ch1',
    bookId: 'gof',
    ordinal: 1,
    title: '火焰杯',
    steps: [
      StoryStepDef(
        id: 'gof_ch1_arrival',
        chapterId: 'gof_ch1',
        timeCostDays: 52,
        onEnterText:
            '—— 第 4 部 · 火焰杯 ——\n'
            '四年级的开学宴上，校长宣布了两件事：今年有客人要来，'
            '以及——比赛要重启了。',
        setup:
            '礼堂比往年挤。长桌尽头摆着一只木杯，里面跳动着蓝白色的火。'
            '校长说，想参加的人把名字写进杯里，杯子会自己选出勇士。'
            '同桌的人已经在小声盘算自己还差几个月到十七岁。',
        ambient: [
          '火焰在杯口一跳一跳，把前排的脸照得发蓝。',
          '有人掏出羊皮纸开始写名字，笔尖戳破了纸。',
          '你听见身后有人说："十七岁才让报，这不公平。"',
        ],
        canonRefId: 'canon_gof_announce',
        choices: [
          StoryChoiceDef(
            id: 'read_rules',
            text: '把报名规则抄下来，逐条琢磨',
            consequence:
                '你抄了三条规则，其中最要紧的是年龄线：'
                '未满十七岁，杯子不接受你的名字。'
                '你在心里松了口气——又有点说不清的遗憾。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包'],
              addKnowledge: ['gof_tournament_rules'],
              setFlags: ['gof_knows_rules'],
              spirit: 1,
            ),
          ),
          StoryChoiceDef(
            id: 'cheer_house',
            text: '先弄清楚本院谁最可能报名',
            consequence:
                '你打听了一圈，发现本院报名的只有一个四年级生，'
                '还是被哥哥们推着去的。你决定到时候给他最大的那声加油。',
            effect: StoryEffect(
              setFlags: ['gof_support_cedric'],
              reputation: 1,
              affection: 2,
              targetNpcId: 'cedric',
            ),
          ),
          StoryChoiceDef(
            id: 'watch_cup',
            text: '盯着那只杯子看，直到宴席散场',
            consequence:
                '你一直看着那只杯子。火焰偶尔窜高一下，'
                '像在挑人。散场时你最后一个离开——'
                '你说不清自己是在期待还是在害怕。',
            effect: StoryEffect(
              addKnowledge: ['gof_cup_omen'],
              setFlags: ['gof_knows_rules'],
              spirit: -1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'gof_ch1_guests',
        chapterId: 'gof_ch1',
        timeCostDays: 12,
        setup:
            '十月底，两所学校的人到了。一队的制服是深蓝的，'
            '一队披着毛皮斗篷。走廊里从此多了听不懂的语言，'
            '也多了互相打量的目光。',
        ambient: [
          '餐厅的菜单上多了两栏看不懂的菜名。',
          '有外校学生把 cloak 甩到椅背上，动作漂亮得像排练过。',
          '本院的人开始自发地跟在他们后面走。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'be_host',
            text: '主动给迷路的外校生指路',
            consequence:
                '你给一个在楼梯口转了三圈的外校生指了路，'
                '对方用很重的口音说了句谢谢。'
                '后来在走廊遇见，他会主动跟你点头。',
            effect: StoryEffect(
              setFlags: ['gof_host_manners'],
              reputation: 2,
              spirit: 1,
            ),
          ),
          StoryChoiceDef(
            id: 'learn_about_them',
            text: '去图书馆查另外两所学校的资料',
            consequence:
                '你查了两小时。一所在北方，校规严得吓人；'
                '一所在南方，据说课表里有一半是马术和草药。'
                '你合上书时想：原来世界这么大。',
            effect: StoryEffect(
              addKnowledge: ['gof_schools_dossier'],
              setFlags: ['gof_knows_rules'],
              spirit: 2,
            ),
          ),
          StoryChoiceDef(
            id: 'keep_distance',
            text: '不凑热闹，照旧走自己的路',
            consequence:
                '你照旧走自己的路。热闹是他们的，'
                '你的四年级有自己的节奏。'
                '只是偶尔会想，如果主动一点会不会不一样。',
            effect: StoryEffect(
              addKnowledge: ['gof_kept_distance'],
              spirit: 1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'gof_ch1_dark_news',
        chapterId: 'gof_ch1',
        timeCostDays: 14,
        setup:
            '秋天里有一则消息在报纸角落里待了三天才被人注意到：'
            '暑假期间，有一户麻瓜看门人在深夜遇袭，'
            '而那一夜的天空上，出现过一个谁也说不清的标记。',
        ambient: [
          '报道只有豆腐块大，配图模糊。',
          '有人把它剪下来贴在寝室墙上。',
          '餐厅里第一次有人公开说出了那个名字，然后被旁人制止。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'clip_news',
            text: '把那则报道剪下来收好',
            consequence:
                '你把报道剪了下来，夹在课本里。'
                '你不知道为什么要留着——只是觉得，'
                '如果以后真出事，这张纸会证明"早就有人说过"。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包'],
              addKnowledge: ['gof_summer_attack'],
              setFlags: ['gof_tracks_news'],
              spirit: -1,
            ),
          ),
          StoryChoiceDef(
            id: 'ask_professor',
            text: '拿着报纸去问教授是不是真的',
            consequence:
                '你问了。教授看完报纸，说"谣言止于智者"，'
                '然后把报纸还给你，补了一句：'
                '"但晚上别一个人去禁林。"——这句不算解释。',
            effect: StoryEffect(
              setFlags: ['gof_tracks_news'],
              addKnowledge: ['gof_official_brushoff'],
              affection: 1,
              targetNpcId: 'mcgonagall',
            ),
          ),
          StoryChoiceDef(
            id: 'ignore_news',
            text: '不去看，把注意力留给课业和比赛',
            consequence:
                '你把注意力放在课业上。四年级的课业忽然变重了，'
                '你每天都在赶作业。这让你过得踏实——'
                '也让你错过了最早的那批信号。',
            effect: StoryEffect(
              addKnowledge: ['gof_focused_study'],
              spirit: 1,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第二章 · 勇士之夜（1994 年 10-11 月）→ canon_gof_champions
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'gof_ch2',
    bookId: 'gof',
    ordinal: 2,
    title: '勇士之夜',
    steps: [
      StoryStepDef(
        id: 'gof_ch2_selection',
        chapterId: 'gof_ch2',
        timeCostDays: 5,
        canonRefId: 'canon_gof_champions',
        setup:
            '万圣节前的那个晚上，礼堂熄了灯，只留那只杯子的火。'
            '名字一条条被吐出来。第四个名字念完之后，'
            '整个礼堂安静了三秒——那是个不该出现的名字。',
        ambient: [
          '火焰窜得比上次高，把穹顶照出一片蓝。',
          '有人站起来想说什么，被旁边的人拉了回去。',
          '本院那位勇士坐在原地，表情很平静。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'stand_up',
            text: '跟着本院的人一起站起来喊名字',
            consequence:
                '你跟着喊了本院勇士的名字，喊到嗓子发哑。'
                '那一刻你真心为他高兴——'
                '后来你回想，那是这一年最后一段纯粹的兴奋。',
            effect: StoryEffect(
              setFlags: ['gof_support_cedric'],
              reputation: 2,
              affection: 3,
              spirit: 3,
              targetNpcId: 'cedric',
            ),
          ),
          StoryChoiceDef(
            id: 'note_injustice',
            text: '在本子上记下：名单有第四条',
            consequence:
                '你记下了第四条，也记下了礼堂里那三秒沉默。'
                '规则被改写了，而所有人都假装没看见——'
                '这件事你一直记到了学年结束。',
            effect: StoryEffect(
              addItems: ['计划书'],
              addKnowledge: ['gof_fourth_name'],
              setFlags: ['gof_sense_wrong'],
              spirit: -1,
            ),
          ),
          StoryChoiceDef(
            id: 'find_the_boy',
            text: '散场后去人群里找那个被点到的男孩',
            consequence:
                '你没找到他——他被人围住了，也可能是躲起来了。'
                '你只看见几个高年级生凑在一起说话，'
                '声音压得很低，其中一个说了句"这不合规矩"。',
            effect: StoryEffect(
              addKnowledge: ['gof_aftermath_whispers'],
              setFlags: ['gof_sense_wrong'],
              reputation: 1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'gof_ch2_support',
        chapterId: 'gof_ch2',
        timeCostDays: 17,
        setup:
            '勇士确定之后，本院的人开始做同一件事：'
            '给他做徽章、给他留座位、在走廊上拦住他说加油。'
            '也有人把另一枚徽章做得很难听。',
        ambient: [
          '徽章上的字会变，一天一个样。',
          '有人把两种徽章别在同一件袍子上，被瞪了。',
          '那位勇士每次都笑着接过徽章，一个不落。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'make_badge',
            text: '亲手做一枚像样的徽章送过去',
            consequence:
                '你花了一晚上做徽章，字写得不算好看，'
                '但他别在袍子上戴了一整个赛季。'
                '你后来在走廊上见过那枚徽章很多次。',
            effect: StoryEffect(
              setFlags: ['gof_support_cedric'],
              addItems: ['勇气勋章'],
              reputation: 2,
              affection: 3,
              spirit: 2,
              targetNpcId: 'cedric',
            ),
          ),
          StoryChoiceDef(
            id: 'refuse_mockery',
            text: '有人发难听的徽章，你当众拒收',
            consequence:
                '有人往你手里塞了一枚难听的，你当着他的面放回了桌上。'
                '"不干。"你说完就走了，手心全是汗。'
                '第二天有人私下跟你说：你做得对。',
            effect: StoryEffect(
              setFlags: ['gof_stood_up'],
              reputation: 3,
              spirit: 1,
            ),
          ),
          StoryChoiceDef(
            id: 'stay_neutral',
            text: '两种徽章都不碰，只当普通观众',
            consequence:
                '你哪种都没拿。你想等第一个项目看完再说——'
                '比赛是比出来的，不是喊出来的。'
                '这个决定让你整个秋天都很轻松，也很边缘。',
            effect: StoryEffect(
              addKnowledge: ['gof_neutral_stance'],
              spirit: 1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'gof_ch2_first_task',
        chapterId: 'gof_ch2',
        timeCostDays: 20,
        setup:
            '第一个项目的看台搭在禁林边上。木板被踩得咚咚响，'
            '下面围着的围栏里有什么在动，'
            '声音大得能穿过木板传上来。',
        ambient: [
          '看台上的风比地面大，帽子得用手按着。',
          '有人紧张得把薯片捏成了粉。',
          '裁判席上坐着五个人，都在往下看。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'cheer_loud',
            text: '站起来，把嗓子喊哑',
            consequence:
                '你喊到失声。那位勇士从场地中央抬头看了一眼看台，'
                '大概是听见了。十分钟以后他完成了项目，'
                '站起来时冲看台挥了下手——不一定是在挥给你，你当是了。',
            effect: StoryEffect(
              setFlags: ['gof_cheered_task'],
              reputation: 2,
              affection: 2,
              spirit: 3,
              targetNpcId: 'cedric',
            ),
          ),
          StoryChoiceDef(
            id: 'take_notes',
            text: '把每个勇士的打法记下来',
            consequence:
                '你记满了两页：谁快、谁稳、谁用了从没见过的咒。'
                '回宿舍后有人借去看，看完说：'
                '"你这哪是看比赛，你这是备课。"',
            effect: StoryEffect(
              addItems: ['羊皮纸一包', '新羽毛笔'],
              addKnowledge: ['gof_task_notes'],
              setFlags: ['gof_cheered_task'],
              reputation: 1,
              spirit: 2,
            ),
          ),
          StoryChoiceDef(
            id: 'watch_crowd',
            text: '不看成绩，看周围人的脸',
            consequence:
                '你发现最好看的不是场地，是看台：'
                '有人攥着栏杆，有人闭着眼，'
                '有个外校的女孩全程没看场地，只盯着一位勇士。'
                '你把这些记在了心里，比比分清楚。',
            effect: StoryEffect(
              addKnowledge: ['gof_crowd_faces'],
              setFlags: ['gof_watched_people'],
              spirit: 2,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第三章 · 圣诞舞会（1994 年 12 月）→ canon_gof_yule_ball
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'gof_ch3',
    bookId: 'gof',
    ordinal: 3,
    title: '圣诞舞会',
    steps: [
      StoryStepDef(
        id: 'gof_ch3_invite',
        chapterId: 'gof_ch3',
        timeCostDays: 17,
        setup:
            '舞会的消息贴出来那天，走廊里最热门的问题不是"去不去"，'
            '而是"跟谁去"。四年级的圣诞忽然有了一点大人的味道——'
            '有点甜，也有点烫手。',
        ambient: [
          '有人在楼梯间练习邀请词，被路过的级长笑话了。',
          '礼袍的图样在女生宿舍传了三轮。',
          '你手里的那句话，在喉咙里卡了两天。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'ask_early',
            text: '早点开口，把邀请说出去',
            consequence:
                '你在周三下午说了。对方先是愣了一下，然后说好。'
                '回去的路上你脚步轻得不像话——'
                '原来最难的部分是说出口之前那两天。',
            effect: StoryEffect(
              setFlags: ['gof_ball_ready'],
              reputation: 2,
              affection: 3,
              spirit: 3,
              targetNpcId: 'cho',
            ),
          ),
          StoryChoiceDef(
            id: 'go_with_friends',
            text: '跟一群朋友一起去，谁也不邀请谁',
            consequence:
                '你们约好六个人一起进场，谁也不欠谁。'
                '舞会那晚你们笑得最大声，跳得最难看，'
                '回宿舍时还在走廊里滑了一跤。',
            effect: StoryEffect(
              setFlags: ['gof_ball_ready'],
              reputation: 2,
              affection: 2,
              spirit: 3,
              targetNpcId: 'ron',
            ),
          ),
          StoryChoiceDef(
            id: 'skip_ball',
            text: '不去，把那晚留给安静的图书馆',
            consequence:
                '你去了图书馆。那天晚上整栋楼只有三个人，'
                '你看了六个小时书，什么也没记住。'
                '远处传来的音乐，隔着两层楼还是听得见。',
            effect: StoryEffect(
              addKnowledge: ['gof_skipped_ball'],
              spirit: -1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'gof_ch3_ball',
        chapterId: 'gof_ch3',
        timeCostDays: 7,
        canonRefId: 'canon_gof_yule_ball',
        setup:
            '礼堂被改成了银色和白色。冰雕立在角落，'
            '乐队在台上，而所有人都比昨天老了两岁——'
            '男生把头发梳得一丝不苟，女生的礼袍会发光。',
        ambient: [
          '冰雕上的光一闪一闪，落在每个人的肩膀上。',
          '第一支舞开始时有几十个人同时踩错了脚。',
          '角落里的 punches 碗被偷偷加了料，有人喝了脸通红。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'dance_badly',
            text: '上场，哪怕跳得很难看',
            consequence:
                '你上场了，踩了对方三次脚，'
                '但整支曲子你都在笑。散场时你的袜子湿了，'
                '心情却是这一年最好的一次。',
            effect: StoryEffect(
              setFlags: ['gof_danced'],
              reputation: 2,
              affection: 3,
              spirit: 3,
              targetNpcId: 'cho',
            ),
          ),
          StoryChoiceDef(
            id: 'talk_to_stranger',
            text: '在露台上跟一个不认识的人聊天',
            consequence:
                '你在露台上遇见一个外校的学生，'
                '你们用半通不通的英语聊了二十分钟，'
                '聊的都是废话，却比什么都好——那晚你们都只是学生。',
            effect: StoryEffect(
              setFlags: ['gof_danced', 'gof_host_manners'],
              reputation: 3,
              spirit: 2,
            ),
          ),
          StoryChoiceDef(
            id: 'watch_from_corner',
            text: '靠在柱子边，把这一晚看完整',
            consequence:
                '你靠在柱子边看了一整晚。'
                '你看勇士被围着合影，看有人被拒绝了邀请，'
                '也看见有人在露台上一个人吹了很久的风。'
                '你没跳舞，但你把这一晚记住了。',
            effect: StoryEffect(
              setFlags: ['gof_watched_people'],
              addKnowledge: ['gof_ball_scenes'],
              spirit: 2,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'gof_ch3_after_ball',
        chapterId: 'gof_ch3',
        timeCostDays: 18,
        setup:
            '舞会结束后的日子有点空。假期里留校的人不多，'
            '城堡的走廊恢复了长度。'
            '你在这种安静里第一次认真想：明年这个时候，我会是什么样。',
        ambient: [
          '礼堂的冰雕化了，地上留了一小片水迹。',
          '有人把舞会那晚的胸花夹进了书里。',
          '你给家里写了一封比平时长的信。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'write_home',
            text: '给家里写一封很长的信',
            consequence:
                '你写了三页，把舞会、比赛、新朋友都写进去了。'
                '回信里只有一句被你反复看：'
                '"你听起来长大了。"',
            effect: StoryEffect(
              addItems: ['手写贺卡'],
              setFlags: ['gof_wrote_home'],
              spirit: 3,
            ),
          ),
          StoryChoiceDef(
            id: 'plan_career',
            text: '去查四年级末要选的职业方向',
            consequence:
                '你翻出了职业指导的小册子，一页页看下来，'
                '发现每条路都要先把某门课考到某个分数。'
                '你第一次有了"要开始准备"的实感。',
            effect: StoryEffect(
              addItems: ['计划书'],
              addKnowledge: ['gof_career_plan'],
              setFlags: ['gof_planned_ahead'],
              spirit: 2,
            ),
          ),
          StoryChoiceDef(
            id: 'rest',
            text: '什么都不想，先睡三天',
            consequence:
                '你睡了很久，起来吃了顿很晚的早饭。'
                '有时候什么都不做才是对的做法——'
                '假期结束那天你是精神最好的那个人。',
            effect: StoryEffect(
              setFlags: ['gof_rested'],
              spirit: 3,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第四章 · 第二个项目（1995 年 2 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'gof_ch4',
    bookId: 'gof',
    ordinal: 4,
    title: '第二个项目',
    steps: [
      StoryStepDef(
        id: 'gof_ch4_clue',
        chapterId: 'gof_ch4',
        timeCostDays: 25,
        setup:
            '二月的湖面没有化。勇士们拿到了一句提示，'
            '说要"从水底带回一样被夺走的东西"。'
            '看台这次架在湖边，风从水面上直吹过来。',
        ambient: [
          '有人在座位上垫了三层毯子。',
          '湖心插着一根标竿，绳子上系着什么在飘。',
          '等待开始的那十分钟，全场没人说话。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'guess_riddle',
            text: '跟人打赌那句提示是什么意思',
            consequence:
                '你赌的是"要带走的人里有一个是本院的"。'
                '你赌对了，但赢的那份糖你没吃——'
                '看着湖面等一小时，比吃糖难多了。',
            effect: StoryEffect(
              addItems: ['比比多味豆'],
              addKnowledge: ['gof_second_riddle'],
              setFlags: ['gof_cheered_task'],
              reputation: 1,
              spirit: 1,
            ),
          ),
          StoryChoiceDef(
            id: 'help_prepare',
            text: '帮那位勇士把要用的东西备齐',
            consequence:
                '你帮他跑了两趟——毛巾、热饮、还有一条干袍子。'
                '他上岸时你第一个递过去。'
                '他哆嗦着说了句"谢了"，声音都在抖。',
            effect: StoryEffect(
              setFlags: ['gof_support_cedric'],
              addItems: ['保暖毛线帽', '黄油啤酒'],
              reputation: 2,
              affection: 3,
              targetNpcId: 'cedric',
            ),
          ),
          StoryChoiceDef(
            id: 'time_the_wait',
            text: '掐表记录每个勇士在水下待了多久',
            consequence:
                '你记了时间：最长的那个超过了一小时。'
                '你在纸上写"这不合理"，'
                '然后有人提醒你，勇士是可以用魔法的。',
            effect: StoryEffect(
              addItems: ['计划书'],
              addKnowledge: ['gof_task_timing'],
              spirit: 1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'gof_ch4_after',
        chapterId: 'gof_ch4',
        timeCostDays: 22,
        setup:
            '项目结束那晚，城堡里有一种松了口气的热闹。'
            '但你在走廊里听见两个高年级生争吵：'
            '一个说"有人在帮勇士"，另一个说"别管了，反正赢了"。',
        ambient: [
          '公共休息室的火被拨得很旺。',
          '有人在复述水下那段，加了好多想象。',
          '那位勇士早早回房了，说累。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'note_oddities',
            text: '把今年所有不对劲的地方列成一张单子',
            consequence:
                '你列了七条：第四个名字、裁判席上那个总不露面的、'
                '有人偷偷给勇士递消息、暑假的那则新闻……'
                '单子列完你自己都愣住了：原来一年攒了这么多。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包'],
              addKnowledge: ['gof_oddity_list'],
              setFlags: ['gof_sense_wrong', 'gof_tracks_news'],
              spirit: -2,
            ),
          ),
          StoryChoiceDef(
            id: 'talk_to_prefect',
            text: '把单子拿给级长看',
            consequence:
                '级长看完，说你想太多了，'
                '然后把单子还给你，又说了句：'
                '"不过……你要是真担心，就别一个人待着。"',
            effect: StoryEffect(
              setFlags: ['gof_sense_wrong'],
              reputation: 1,
              affection: 2,
              targetNpcId: 'percy',
            ),
          ),
          StoryChoiceDef(
            id: 'enjoy_moment',
            text: '把单子锁进抽屉，先享受这一晚',
            consequence:
                '你把纸锁进抽屉，下楼加入了热闹。'
                '有些夜晚就该用来高兴——'
                '何况你不知道这样的夜晚还剩几个。',
            effect: StoryEffect(
              setFlags: ['gof_cheered_task'],
              reputation: 1,
              spirit: 3,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'gof_ch4_spring',
        chapterId: 'gof_ch4',
        timeCostDays: 29,
        setup:
            '三月之后天气转暖，禁林边上的草长得飞快。'
            '第三个项目定在六月，据说是一座迷宫。'
            '这学期剩下的时间，忽然变得很珍贵。',
        ambient: [
          '有人开始为考试发愁，有人开始为暑假计划。',
          '操场边搭起了脚手架，迷宫正在长出来。',
          '你说不清自己更想快点毕业，还是想慢一点。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'study_hard',
            text: '把这段时间拿来冲刺五年级的课',
            consequence:
                '你开始认真读书。四年级的课本忽然变厚了，'
                '但你发现自己能坐住两个小时不分心了。'
                '这种变化比任何分数都重要。',
            effect: StoryEffect(
              setFlags: ['gof_planned_ahead'],
              addItems: ['标准咒语书'],
              reputation: 1,
              spirit: 2,
            ),
          ),
          StoryChoiceDef(
            id: 'roam_grounds',
            text: '把城堡和场地都走一遍，记住它们',
            consequence:
                '你花了几周把湖、禁林边、魁地奇球场、'
                '还有那条你一年级不敢走的路都走了一遍。'
                '你隐隐觉得，以后会想念这些地方。',
            effect: StoryEffect(
              addKnowledge: ['gof_grounds_tour'],
              setFlags: ['gof_watched_people'],
              spirit: 3,
            ),
          ),
          StoryChoiceDef(
            id: 'reconnect',
            text: '去把这一年疏远的人重新约出来',
            consequence:
                '你约了几个这半年没怎么说话的人，'
                '在三把扫帚坐了一下午。'
                '有人说了句"我还以为你忘了我们"，你没接话，只是又点了一轮。',
            effect: StoryEffect(
              setFlags: ['gof_host_manners'],
              reputation: 2,
              affection: 3,
              spirit: 2,
              targetNpcId: 'hermione',
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第五章 · 迷宫长成（1995 年 4-5 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'gof_ch5',
    bookId: 'gof',
    ordinal: 5,
    title: '迷宫长成',
    steps: [
      StoryStepDef(
        id: 'gof_ch5_maze_rise',
        chapterId: 'gof_ch5',
        timeCostDays: 29,
        setup:
            '魁地奇球场上那圈树篱已经长到两人高，'
            '从看台上看下去像一片会移动的绿色。'
            '有人说里面放了东西，有人说那才是真正的考试。',
        ambient: [
          '树篱会在夜里发出很轻的摩擦声。',
          '有学生在打赌哪个入口最短，赔率一天三变。',
          '勇士们这几天都睡得很早。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'map_hedges',
            text: '站在看台最高处，描一张迷宫的草图',
            consequence:
                '你描了张草图，描到第三遍才发现：'
                '它每天长得都不一样。你把草图撕了——'
                '有些东西本来就不该被提前算清。',
            effect: StoryEffect(
              addItems: ['全效望远镜'],
              addKnowledge: ['gof_maze_sketch'],
              setFlags: ['gof_maze_watched'],
              spirit: 1,
            ),
          ),
          StoryChoiceDef(
            id: 'encourage_champion',
            text: '在走廊上拦住本院那位勇士，说句话',
            consequence:
                '你拦住他，说了句"我们都在"。'
                '他笑了一下，说"我知道"，'
                '然后拍了拍你的肩就走了——他的手心是凉的。',
            effect: StoryEffect(
              setFlags: ['gof_support_cedric'],
              reputation: 2,
              affection: 3,
              targetNpcId: 'cedric',
            ),
          ),
          StoryChoiceDef(
            id: 'avoid_maze',
            text: '不看它，绕开球场走另一条路',
            consequence:
                '你绕开球场走了两周。'
                '越接近六月，越不想看见那片绿色——'
                '你后来才明白，那是一种预感。',
            effect: StoryEffect(
              addKnowledge: ['gof_avoided_maze'],
              spirit: -1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'gof_ch5_exams',
        chapterId: 'gof_ch5',
        timeCostDays: 27,
        setup:
            '五年级的考试近在眼前，四年级的结业考也压了上来。'
            '图书馆的位子开始不够坐，'
            '连走廊窗台上都坐着背书的人。',
        ambient: [
          '有人把重点抄在手臂上，被监考请出去了。',
          '图书馆闭馆时间延长了两小时。',
          '你发现自己第一次主动去了自习室。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'study_marathon',
            text: '连着两周泡图书馆',
            consequence:
                '你泡了两周，考完那天在桌上趴了十分钟才缓过来。'
                '成绩出来后你盯着那几个数字看了很久——'
                '原来努力是可以被看见的。',
            effect: StoryEffect(
              setFlags: ['gof_planned_ahead'],
              addItems: ['标准咒语书', '提神剂'],
              reputation: 2,
              spirit: 2,
            ),
          ),
          StoryChoiceDef(
            id: 'study_with_champion',
            text: '跟那位勇士一起复习（他也得考试）',
            consequence:
                '你们在角落里互相抽背。他一边背一边打哈欠，'
                '说"要是能睡一整年就好了"。'
                '你当时笑了，这句话后来怎么也忘不掉。',
            effect: StoryEffect(
              setFlags: ['gof_support_cedric', 'gof_planned_ahead'],
              reputation: 2,
              affection: 3,
              spirit: 2,
              targetNpcId: 'cedric',
            ),
          ),
          StoryChoiceDef(
            id: 'help_junior',
            text: '把笔记借给一个快崩溃的低年级生',
            consequence:
                '你把笔记给了他，还陪他过了一遍重点。'
                '他说"你以后一定能当级长"，你说别瞎说。'
                '但你心里那句话留了很久。',
            effect: StoryEffect(
              setFlags: ['gof_host_manners'],
              reputation: 3,
              affection: 2,
              targetNpcId: 'colin',
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'gof_ch5_tension',
        chapterId: 'gof_ch5',
        timeCostDays: 22,
        setup:
            '赛前最后两周，城堡里的气氛不太对：'
            '有教授临时请假，有家长提前把孩子接走了，'
            '还有传言说，今年的比赛不该办。',
        ambient: [
          '餐厅里空出了几个座位，没人解释。',
          '走廊挂毯后面有人在压着嗓子争论。',
          '你注意到今年没有人再打赌谁会赢。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'ask_someone',
            text: '直接问一个高年级生到底在怕什么',
            consequence:
                '那人看了你很久，最后说：'
                '"我也不知道。但我觉得，六月那晚最好别一个人待着。"'
                '你听进去了，从那天起你再没落过单。',
            effect: StoryEffect(
              setFlags: ['gof_sense_wrong', 'gof_kept_question'],
              addKnowledge: ['gof_unexplained_fear'],
              reputation: 1,
              affection: 2,
              targetNpcId: 'angelina',
            ),
          ),
          StoryChoiceDef(
            id: 'stay_with_people',
            text: '什么也不问，但从此不再一个人走',
            consequence:
                '你开始跟人结伴：去图书馆、回宿舍、'
                '甚至去洗手间。没有人问为什么，'
                '因为那两周所有人都是这么做的。',
            effect: StoryEffect(
              setFlags: ['gof_sense_wrong'],
              reputation: 1,
              spirit: 1,
            ),
          ),
          StoryChoiceDef(
            id: 'write_it_all',
            text: '把这一年的不对劲整理成一封信，写给未来的自己',
            consequence:
                '你写了一封信，封好，压在箱底。'
                '信里最后一句是：'
                '"如果这封信有一天变得很重要，那说明最坏的事发生了。"',
            effect: StoryEffect(
              addItems: ['手写贺卡'],
              addKnowledge: ['gof_letter_to_future'],
              setFlags: ['gof_kept_question'],
              spirit: -2,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第六章 · 第三个项目（1995 年 6 月）→ canon_gof_maze
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'gof_ch6',
    bookId: 'gof',
    ordinal: 6,
    title: '第三个项目',
    steps: [
      StoryStepDef(
        id: 'gof_ch6_maze_start',
        chapterId: 'gof_ch6',
        timeCostDays: 9,
        canonRefId: 'canon_gof_maze',
        setup:
            '六月的晚上，看台坐满了。迷宫入口的黑洞一个接一个，'
            '勇士们按抽签顺序进去。奖杯摆在迷宫中心，'
            '规则只有一句：先碰到的人赢。',
        ambient: [
          '树篱在灯下绿得发黑，风一过就晃。',
          '看台上有人自发地唱起了院歌。',
          '你手里攥着什么，自己都没注意。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'cheer_house_champion',
            text: '为本院那位勇士喊到最大声',
            consequence:
                '你喊了他的名字。他进迷宫前回头看了一眼看台，'
                '举了下手指——那个动作你记了一辈子。',
            effect: StoryEffect(
              setFlags: ['gof_support_cedric', 'gof_maze_watched'],
              reputation: 2,
              affection: 3,
              spirit: 2,
              targetNpcId: 'cedric',
            ),
          ),
          StoryChoiceDef(
            id: 'count_time',
            text: '掐着表，数他们进去了多久',
            consequence:
                '你掐了表。四十分钟、一小时、一个半小时。'
                '看台上的歌声慢慢停了，'
                '因为所有人都发现：太久了。',
            effect: StoryEffect(
              addItems: ['计划书'],
              addKnowledge: ['gof_maze_duration'],
              setFlags: ['gof_maze_watched', 'gof_sense_wrong'],
              spirit: -2,
            ),
          ),
          StoryChoiceDef(
            id: 'watch_the_center',
            text: '眼睛盯着迷宫中心那只奖杯',
            consequence:
                '你一直盯着那只奖杯。它在灯下很亮，'
                '亮得不太真实。后来你想，'
                '那天晚上所有人都在盯着错误的东西。',
            effect: StoryEffect(
              addKnowledge: ['gof_cup_focus'],
              setFlags: ['gof_maze_watched'],
              spirit: -1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'gof_ch6_return',
        chapterId: 'gof_ch6',
        timeCostDays: 2,
        setup:
            '然后是一道光。一个勇士出现在迷宫外，'
            '手里抓着另一个人——那个人没有再站起来。'
            '看台上的欢呼卡在半空，然后变成另一种声音。',
        ambient: [
          '有人喊了什么，声音劈了。',
          '灯光还亮着，但整个球场一下子暗了。',
          '你旁边的两个人抱在了一起，谁也没说话。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'stand_still',
            text: '站在原地，把这一刻看清楚',
            consequence:
                '你没动，也没喊。你把这一刻看得清清楚楚：'
                '光、奖杯、地毯上那个不动的身影、'
                '还有那个跪在地上不肯起来的男孩。',
            effect: StoryEffect(
              setFlags: ['gof_after_silence'],
              addKnowledge: ['gof_that_moment'],
              spirit: -3,
            ),
          ),
          StoryChoiceDef(
            id: 'help_crowd',
            text: '去扶身边站不稳的人',
            consequence:
                '你扶住了身边一个一年级生，他一直在发抖。'
                '你把他带到看台边上坐下，'
                '给他倒了杯水——你自己的手也在抖。',
            effect: StoryEffect(
              setFlags: ['gof_after_silence', 'gof_host_manners'],
              reputation: 3,
              spirit: -1,
            ),
          ),
          StoryChoiceDef(
            id: 'go_find_teacher',
            text: '跑去找大人，越快越好',
            consequence:
                '你跑下看台去找教授，'
                '一路上撞到了三个人，说了无数句"对不起"。'
                '等你把人带到，该发生的已经发生了——但你去了。',
            effect: StoryEffect(
              setFlags: ['gof_after_silence'],
              addKnowledge: ['gof_ran_for_help'],
              reputation: 2,
              spirit: -2,
              affection: 1,
              targetNpcId: 'mcgonagall',
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'gof_ch6_night',
        chapterId: 'gof_ch6',
        timeCostDays: 3,
        setup:
            '那一夜城堡没有熄灯，也没有人睡。'
            '第二天早上，餐厅里有一把椅子空着，'
            '没有人去坐，也没有人让人去搬走。',
        ambient: [
          '走廊上的挂毯被换成了深色。',
          '有人在公告栏前站了很久，什么也没贴。',
          '你听见两个平时很闹的人，说话声比谁都小。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'light_candle',
            text: '在角落里点一支蜡烛',
            consequence:
                '你点了一支蜡烛，什么也没说。'
                '一整天，那附近陆续多出了几十支。'
                '原来所有人都在找同一件事做。',
            effect: StoryEffect(
              setFlags: ['gof_after_silence'],
              reputation: 2,
              spirit: 2,
            ),
          ),
          StoryChoiceDef(
            id: 'sit_with_friend',
            text: '什么都不说，就陪人坐着',
            consequence:
                '你陪一个人坐了一下午，一句话没说。'
                '临走时他说："谢谢你没劝我。"'
                '你后来才懂，那句话是这一年最高的评价。',
            effect: StoryEffect(
              setFlags: ['gof_after_silence'],
              reputation: 2,
              affection: 3,
              spirit: 1,
              targetNpcId: 'cho',
            ),
          ),
          StoryChoiceDef(
            id: 'write_down',
            text: '把他的名字写进自己的本子',
            consequence:
                '你在本子第一页写下了他的名字，'
                '又在后面写了一行：'
                '"他教过我怎么把球打回去。"——这是你记得的他。',
            effect: StoryEffect(
              addItems: ['手写贺卡'],
              addKnowledge: ['gof_remembered_name'],
              setFlags: ['gof_after_silence'],
              spirit: -1,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第七章 · 学年结束（1995 年 6 月）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'gof_ch7',
    bookId: 'gof',
    ordinal: 7,
    title: '学年结束',
    steps: [
      StoryStepDef(
        id: 'gof_ch7_feast',
        chapterId: 'gof_ch7',
        timeCostDays: 4,
        setup:
            '结束宴照常举行，只是今年的祝词很短。'
            '校长站起来说了一句话，然后请所有人举杯——'
            '那句话你听得很清楚，一个字都没漏。',
        ambient: [
          '礼堂顶上的蜡烛今年没有变颜色。',
          '有人在桌下紧紧攥着另一个人的手。',
          '你第一次注意到，原来整个礼堂可以这么安静。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'listen_carefully',
            text: '把校长那句话逐字记住',
            consequence:
                '他把话说得很慢，也很清楚：'
                '有些事要来了，而我们得准备好。'
                '你把这句抄在了本子上——不是因为懂，是因为它重要。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包'],
              addKnowledge: ['gof_headmaster_warning'],
              setFlags: ['gof_kept_question'],
              spirit: -1,
            ),
          ),
          StoryChoiceDef(
            id: 'raise_glass',
            text: '举杯，跟所有人一起',
            consequence:
                '你举了杯。杯子碰到桌面的声音连成一片，'
                '像一场很轻的雨。'
                '你喝了一口，觉得今年的南瓜汁特别苦。',
            effect: StoryEffect(
              setFlags: ['gof_after_silence'],
              reputation: 1,
              spirit: 1,
            ),
          ),
          StoryChoiceDef(
            id: 'leave_early',
            text: '中途离席，去院子里站一会儿',
            consequence:
                '你出去了。六月的夜风很暖，'
                '远处迷宫的树篱正在被拆。'
                '你站到宴会结束才回去。',
            effect: StoryEffect(
              addKnowledge: ['gof_left_feast'],
              setFlags: ['gof_after_silence'],
              spirit: -1,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'gof_ch7_packing',
        chapterId: 'gof_ch7',
        timeCostDays: 4,
        setup:
            '收拾行李时你翻出了这一年的东西：'
            '一枚徽章、一张舞会的门票根、'
            '还有那张被你锁进抽屉的不对劲清单。',
        ambient: [
          '箱子比去年重，你不知道多了什么。',
          '有人的猫头鹰在笼子里等着出发。',
          '你把那张清单又读了一遍。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'keep_list',
            text: '把清单带走，五年级还要用',
            consequence:
                '你把清单折好放进内袋。'
                '你有一种很明确的预感：'
                '明年这些东西都有用——虽然你不希望它有用。',
            effect: StoryEffect(
              setFlags: ['gof_kept_question', 'gof_tracks_news'],
              spirit: -1,
            ),
          ),
          StoryChoiceDef(
            id: 'burn_list',
            text: '把它烧掉，试着像往常一样过暑假',
            consequence:
                '你在壁炉里烧了它。火苗蹿起来那一瞬间你后悔了，'
                '但已经来不及。整个暑假你都在试着'
                '回忆上面写了哪七条。',
            effect: StoryEffect(
              addKnowledge: ['gof_burned_list'],
              spirit: 1,
            ),
          ),
          StoryChoiceDef(
            id: 'show_someone',
            text: '把清单给一个你信得过的人看',
            consequence:
                '你给那个人看了。他看完沉默了很久，'
                '然后说："五年级我们一起盯。"'
                '你第一次觉得，明年也许没那么可怕。',
            effect: StoryEffect(
              setFlags: ['gof_kept_question'],
              reputation: 2,
              affection: 3,
              spirit: 2,
              targetNpcId: 'hermione',
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'gof_ch7_train',
        chapterId: 'gof_ch7',
        timeCostDays: 2,
        setup:
            '回家的列车上，一半人在睡觉，一半人在看窗外。'
            '今年没有人玩牌，也没有人串车厢。'
            '你把额头抵在玻璃上，看熟悉的田野退回去。',
        ambient: [
          '车厢里有人在小声哼一首院歌，哼了一半停了。',
          '你把那枚徽章别在了包带上。',
          '列车进站还有两个小时。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'talk_future',
            text: '跟同座认真讨论明年该怎么办',
            consequence:
                '你们聊了两个小时，最后约定：'
                '如果真有事发生，互相通知。'
                '这个约定让你在剩下的旅程里睡得很沉。',
            effect: StoryEffect(
              setFlags: ['gof_kept_question'],
              reputation: 2,
              affection: 2,
              spirit: 2,
              targetNpcId: 'ron',
            ),
          ),
          StoryChoiceDef(
            id: 'sleep_through',
            text: '睡一觉，什么都不想',
            consequence:
                '你睡了整整一路，到站才被叫醒。'
                '下车时你看了眼站台，'
                '忽然很不想松开行李箱的把手。',
            effect: StoryEffect(
              setFlags: ['gof_rested'],
              spirit: 2,
            ),
          ),
          StoryChoiceDef(
            id: 'write_resolution',
            text: '在摇晃的桌上给自己写下一条决心',
            consequence:
                '你写的是："明年，不要只是看着。"'
                '写完你盯着这行字看了很久，'
                '然后把纸收进那本五年级要用的书里。',
            effect: StoryEffect(
              addItems: ['计划书'],
              addKnowledge: ['gof_resolution'],
              setFlags: ['gof_kept_question'],
              reputation: 2,
              spirit: 3,
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

const List<StoryEndingRule> _gofEndings = [
  StoryEndingRule(
    id: 'gof_ending_clear_eyed',
    title: '不再只是看着的人',
    body:
        '你从秋天那则小新闻开始留意，在春天把不对劲的地方列成了单子，'
        '在最后一个夜晚把该记住的都记住了。'
        '你没有改变任何一件大事——但你是少数几个'
        '在事情发生之前就相信"它正在发生"的人。'
        '五年级开学那天，你比大多数人早到了整整一个月。',
    requireFlags: ['gof_kept_question', 'gof_sense_wrong'],
  ),
  StoryEndingRule(
    id: 'gof_ending_support',
    title: '站在他身后的人',
    body:
        '这一年的勇士不是你，但每一次他需要毛巾、需要热水、'
        '需要有人在看台上喊他名字的时候，你都在。'
        '你做过的最大一件事，是让别人知道自己不是一个人。'
        '这份工作在六月之后，忽然变得非常非常重要。',
    requireAnyFlags: ['gof_support_cedric'],
    minReputation: 6,
  ),
  StoryEndingRule(
    id: 'gof_ending_ball_light',
    title: '冰雕下的那支舞',
    body:
        '你会记住的这一年，是礼堂里银白的光、'
        '是踩错的舞步、是露台上那个用半通不通的英语聊天的人。'
        '黑暗确实在逼近，但那个夜晚是真的，'
        '你在场，你笑过——这一点谁也拿不走。',
    requireAnyFlags: ['gof_danced', 'gof_ball_ready'],
  ),
  StoryEndingRule(
    id: 'gof_ending_fade',
    title: '被收走的一年',
    body:
        '这一年你一直在场边：没报上名，没跳那支舞，'
        '也没问出那个一直想问的问题。'
        '六月之后你才明白，有些年份只给一次机会——'
        '你在心里对自己说：五年级，我要站到场地中央去。',
  ),
];

const StoryBookDef gobletOfFire = StoryBookDef(
  id: 'gof',
  title: '火焰杯',
  chapters: _gofChapters,
  endings: _gofEndings,
  startYear: 1994,
  startMonth: 7,
  startDay: 25,
);
