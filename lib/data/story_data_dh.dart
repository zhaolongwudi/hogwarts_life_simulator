/// 《死亡圣器》1997-1998 · 七年级 · 剧情内容表
///
/// 【这一部的气质】前六年，城堡是避难所；这一年，城堡本身成了需要逃出去
/// 或者夺回来的地方。整部书只有一条主线：**一个普通学生，在被占领的学校
/// 里，还能剩下多少选择。**
/// 这一年几乎没有"课业"——取而代之的是三道每天都要重新答一遍的题：
///   1. 看到不对的事，你出不出声；
///   2. 被点名站队时，你站哪边；
///   3. 有人需要藏起来时，你开不开门。
/// 第七年的戏剧位不在"打败谁"，而在"你在最坏的环境里成为什么样的人"。
///
/// 【与哈利线的边界】这一年的原著主线大多是"校外三人组"的旅程，
/// 校内线才是玩家的主场：地下组织、有求必应屋、被追查的同学、
/// 巡查队的名单、以及最后那场发生在城堡里的战斗。
/// 玩家可以参与守夜、藏人、传信、掩护低年级生撤离，
/// 也可以在决战中选择守住哪一道门。
/// 玩家不寻找圣器、不作那个赴死的决定、不接下那件斗篷。
///
/// 【原著节点覆盖】canon_dh_last_year / canon_dh_fall /
/// canon_dh_underground / canon_dh_final_battle 四个节点各由一步剧情讲述。
library;

import 'package:hogwarts_life_simulator/models/story_progress.dart';

// ================================================================
// 《死亡圣器》 1997-1998 · 七年级
//
// 【时间线】1997-07-25 开启锚点 → 1998-05 决战 → 学年终止。
// 42 步 × 平均 8.6 天 ≈ 360 天，与 canon_dh_* 节点的月份逐一对齐：
//   08 被控制 / 09 返校 / 11 地下 / 12-02 寒冬 / 03-04 潜回 / 05 决战
//
// 【密度补强】原为 31 步。第七年的戏剧位不在"打败谁"，而在"你在最坏的
// 环境里成为什么样的人"——而那种磨损只能靠**日常的重复**堆出来。
// 补入 11 个"占领下的日常"场景步：阁楼上的收音机、第一节新课、
// 贴出来的名单、有求必应屋的第一夜、走廊上的传话、写了整夜的那只手、
// 地下电台的第一晚、撤离前的一节课、战斗中的一层楼、天亮之后、
// 空下来的教室。它们不推进情节，只累积代价——这正是长期可玩性的来源。
// ================================================================

const List<StoryChapterDef> _dhChapters = [
  // --------------------------------------------------------------
  // 第一章 · 开学之前（1997 年 8 月）→ canon_dh_fall
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'dh_ch1',
    bookId: 'dh',
    ordinal: 1,
    title: '开学之前',
    steps: [
      StoryStepDef(
        id: 'dh_ch1_fall',
        chapterId: 'dh_ch1',
        timeCostDays: 11,
        onEnterText:
            '—— 第 7 部 · 死亡圣器 ——\n'
            '第七年。通知书照旧寄到，'
            '只是这一次，去不去已经不再是个理所当然的问题。',
        setup:
            '暑假里消息一条比一条坏：部里换了人，'
            '学校也要换管理班子。'
            '两位曾经的教授接管了校务，'
            '新的规定第一条就是血统审查——'
            '麻瓜出身的巫师得去"证明"自己的家世。',
        ambient: [
          '报纸上的措辞变了，很多词被换成了别的词。',
          '有同学写信来说，家里不让来了。',
          '你把通知书翻来覆去看了三遍，像在找一句能撤回的话。',
        ],
        canonRefId: 'canon_dh_fall',
        choices: [
          StoryChoiceDef(
            id: 'read_rules',
            text: '把新规定逐条抄下来，看清每一条到底在问什么',
            consequence:
                '你抄了九条。'
                '抄到第五条你明白了：'
                '这些条文的目的不是管理，是筛选——'
                '它们要的从不是秩序，是名单。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包', '新羽毛笔'],
              addKnowledge: ['dh_rules_copied'],
              setFlags: ['dh_read_rules'],
              spirit: -2,
            ),
            nextStepId: 'dh_ch1_radio',),
          StoryChoiceDef(
            id: 'warn_family',
            text: '先给可能上名单的同学家里去一封信',
            consequence:
                '你写了六封信。'
                '有三封没有回音——'
                '你后来才知道，那三家在信寄到之前就已经搬走了。',
            effect: StoryEffect(
              addItems: ['手写贺卡'],
              setFlags: ['dh_warned_family'],
              reputation: 2,
              spirit: -1,
            ),
            nextStepId: 'dh_ch1_radio',),
          StoryChoiceDef(
            id: 'hide_paper',
            text: '把通知书收起来，当做什么都没发生',
            consequence:
                '你把通知书压到了箱子最底下。'
                '整个八月你一次也没打开过箱子。'
                '但每次经过楼梯口，你都会下意识地往信箱看一眼。',
            effect: StoryEffect(
              setFlags: ['dh_hid_notice'],
              addKnowledge: ['dh_august_silence'],
              spirit: -2,
            ),
            nextStepId: 'dh_ch1_radio',),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch1_radio',
        chapterId: 'dh_ch1',
        timeCostDays: 12,
        setup:
            '开学前那几天，你住的那条街上有人开始把收音机音量调小。'
            '频道里没什么新东西，只是每隔一段时间就换一个说法，'
            '把同一件事说成不同的样子。'
            '你父亲把天线转了半圈，还是那样。最后他关了。',
        ambient: [
          '隔壁人家整个白天都没有开窗。',
          '邮差送来的报纸头版很薄，翻过去才发现里面有几页粘在一起了。',
          '傍晚有猫头鹰落在窗台上，脚上什么都没系。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'keep_listening',
            text: '换到那个总是说得很小声的频道',
            consequence:
                '你把音量调到刚好能听清的地步，趴在桌上听了一个下午。'
                '那个频道的人说话很慢，中间有很多停顿——'
                '像是在想下一句能不能说。'
                '你记住了几个数字，后来在别的地方又听到了一次。',
            effect: StoryEffect(
              addKnowledge: ['dh_pirate_radio'],
              setFlags: ['dh_listened_hidden'],
              spirit: 2,
              housePoints: 1,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'ask_parent',
            text: '问父亲为什么不听了',
            consequence:
                '他说："听得多了会睡不着。"'
                '停了一会儿又补了一句："你去学校，少说话。"'
                '这是他这个假期跟你说得最长的一段话。',
            effect: StoryEffect(
              addKnowledge: ['dh_parent_warning'],
              setFlags: ['dh_got_family_warning'],
              affection: 3,
              spirit: -1,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'turn_it_off_first',
            text: '不等他动手，自己先关了',
            consequence:
                '你伸手把旋钮拧到底，声音断了。'
                '屋里安静下来，你听见楼下有人在喊孩子回家。'
                '那天的晚饭你们谁都没提收音机。',
            effect: StoryEffect(
              setFlags: ['dh_avoided_news'],
              spirit: 1,
              satiety: 4,
            ),
            nextStepId: '',
          ),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch1_family',
        canonRefId: 'canon_dh_diagon_deserted',
        chapterId: 'dh_ch1',
        timeCostDays: 11,
        setup:
            '出事之后，你花了整整两天把家里的东西看了一遍。该带走的、该藏起来的、该说再见的。',
        ambient: [
          '有人在门口站了很久，没进来。',
          '屋里比平时安静很多。',
          '窗外的街上没人，连狗都不叫了。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'pack_family_things',
            text: '把家人的东西收好，带上几件',
            consequence:
                '你挑了很小的一两件，塞在行李最里面。知道它们没有用处，但带上了。',
            nextStepId: '',
            effect: StoryEffect(addItems: ['旧书'], setFlags: ['dh_took_family_things'], spirit: 2),
          ),
          StoryChoiceDef(
            id: 'travel_light',
            text: '什么都不带，能走就行',
            consequence:
                '你把行李减到最少，最后只剩几件换洗的。越轻越好，这一年你随时可能要走。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['dh_travelled_light'], spirit: -1),
          ),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch1_decision',
        chapterId: 'dh_ch1',
        timeCostDays: 4,
        setup:
            '家里为"去不去"吵了三个晚上。'
            '去的理由很实在：不去，就等于承认他们赢了；'
            '不去的理由也很实在：去了，你可能回不来。'
            '这不是一道勇敢的题，是一道算术题——'
            '而答案只有你自己能算。',
        ambient: [
          '母亲把校袍洗了又补，一句话也没说。',
          '父亲把行李箱从阁楼上搬下来，擦了三遍灰。',
          '你在门口站了很久，才伸手推开那扇门。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'go_back',
            text: '回去——我要在场',
            consequence:
                '你说我要回去。'
                '父亲没劝，只把行李箱推到你脚边，'
                '说了一句："那就别做让自己后悔的事。"'
                '你后来才明白，这句话里藏着多大的允许。',
            effect: StoryEffect(
              setFlags: ['dh_went_back'],
              addKnowledge: ['dh_choice_return'],
              reputation: 3,
              spirit: 2,
            ),
          ),
          StoryChoiceDef(
            id: 'go_under_alias',
            text: '回去，但先准备一份能应付审查的身份说辞',
            consequence:
                '你花了两周编了一份说辞：'
                '祖上三代、入学年份、家徽纹样，全都对得上。'
                '你甚至提前练了一遍签字的手抖程度。'
                '这一年里，这份说辞救了你两次。',
            effect: StoryEffect(
              addItems: ['伪装帽'],
              addKnowledge: ['dh_alias_ready'],
              setFlags: ['dh_alias_ready'],
              spirit: -1,
            ),
          ),
          StoryChoiceDef(
            id: 'not_go',
            text: '不回去——这一年我留在校外',
            consequence:
                '你没有回去。'
                '整个冬天你都在外面，'
                '听着收音机里念出的一个个名字，'
                '把去过的地方在地图上连成一条断断续续的线。'
                '这也是一种在场，只是没有证人的那种。',
            effect: StoryEffect(
              setFlags: ['dh_stayed_out'],
              addKnowledge: ['dh_outside_year'],
              spirit: -3,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch1_platform',
        canonRefId: 'canon_dh_train_search',
        chapterId: 'dh_ch1',
        timeCostDays: 4,
        setup:
            '九又四分之三站台今年没有送行的家长。'
            '取而代之的是一排穿黑袍的检查者，'
            '他们挨个核对名册，'
            '念到名字的人要先走过一道门才能上车。',
        ambient: [
          '有人的名字被念了两遍，因为检查者没听清。',
          '站台尽头站着两个你从没见过的成年巫师，一直在看。',
          '你前面的同学手里的箱子一直在响。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'walk_through',
            text: '低着头走过去，一个字不多说',
            consequence:
                '你低着头走过去了。'
                '门框上有什么东西冷了一下，很快就松开。'
                '上了车你才发现，手心里全是汗。',
            effect: StoryEffect(
              setFlags: ['dh_passed_check'],
              spirit: -1,
            ),
          ),
          StoryChoiceDef(
            id: 'help_behind',
            text: '回头帮身后那位被反复盘问的同学答了两句',
            consequence:
                '你回了头，说了两句——'
                '"他和我同院，我认得他，他父亲在部里做事。"'
                '后半句是假的。'
                '检查者挥手放行了。'
                '上车以后他一直没看你，只说了句"谢谢"。',
            effect: StoryEffect(
              setFlags: ['dh_helped_at_gate'],
              addKnowledge: ['dh_lied_at_gate'],
              reputation: 2,
              affection: 3,
              spirit: -1,
              targetNpcId: 'susan',
            ),
          ),
          StoryChoiceDef(
            id: 'count_missing',
            text: '站在旁边，数一数今年有多少人没出现',
            consequence:
                '你数了。'
                '名册上有，站台上没有的，一共十四个。'
                '你把这十四个名字记住了——'
                '这是你能为他们做的唯一一件事。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包'],
              addKnowledge: ['dh_fourteen_names'],
              setFlags: ['dh_counted_missing'],
              spirit: -3,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第二章 · 返校（1997 年 9 月）→ canon_dh_last_year
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'dh_ch2',
    bookId: 'dh',
    ordinal: 2,
    title: '返校',
    steps: [
      StoryStepDef(
        id: 'dh_ch2_opening',
        chapterId: 'dh_ch2',
        timeCostDays: 11,
        setup:
            '开学宴上换了一张新面孔主持秩序。'
            '他笑着宣布了几条此前从未有过的新规矩：'
            '课程调整、出入口登记、'
            '以及"为了安全起见"的晨间点名。'
            '餐厅里的餐具还是那些餐具，气氛完全不一样了。',
        ambient: [
          '教工席上多了两个空位，没人解释为什么。',
          '有人小声说了一句什么，被旁边的人按住了。',
          '你把叉子放下，因为手在抖。',
        ],
        canonRefId: 'canon_dh_last_year',
        choices: [
          StoryChoiceDef(
            id: 'memorize_routes',
            text: '把新规定的出入口和巡逻时间摸清楚',
            consequence:
                '你花了一周把城堡重新走了一遍：'
                '哪道门几点锁、哪条走廊几点没人、'
                '哪段楼梯会在夜里多出一阶。'
                '这份地图后来被很多人用过。',
            effect: StoryEffect(
              addItems: ['计划书', '全效望远镜'],
              addKnowledge: ['dh_castle_map'],
              setFlags: ['dh_knows_routes'],
              spirit: -1,
            ),
            nextStepId: 'dh_ch2_first_class',),
          StoryChoiceDef(
            id: 'sit_with_juniors',
            text: '主动坐到那几个没人敢挨着的一年级生旁边',
            consequence:
                '你坐了过去。'
                '整顿饭那几个孩子一句话都没敢说，'
                '但吃完的时候，最小的那个把盘子往你这边推了推——'
                '那是他能拿出来的全部。',
            effect: StoryEffect(
              setFlags: ['dh_sat_with_juniors'],
              reputation: 3,
              spirit: -1,
              targetNpcId: 'colin',
            ),
            nextStepId: 'dh_ch2_first_class',),
          StoryChoiceDef(
            id: 'keep_invisible',
            text: '尽量不引人注意，安静读完每一天',
            consequence:
                '你把自己缩得很小：'
                '不举手、不发言、坐在第三排靠墙的位置。'
                '整整一个月，没有人记住你的名字。'
                '这很安全，也很冷。',
            effect: StoryEffect(
              setFlags: ['dh_invisible'],
              addKnowledge: ['dh_month_of_silence'],
              spirit: -2,
            ),
            nextStepId: 'dh_ch2_first_class',),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch2_first_class',
        chapterId: 'dh_ch2',
        timeCostDays: 6,
        setup:
            '第一周的新课表发下来，多了一门谁都没报过的课。'
            '上课的人不是原来的老师，讲的东西也和课本不一样——'
            '前半节讲规矩，后半节讲"为什么要守规矩"。'
            '没有人问问题。',
        ambient: [
          '讲课的人念到某个词时，坐在前面的同学把头低了一下。',
          '黑板上写的东西，一下课就有人擦掉了。',
          '有人从头到尾在抄，抄完把纸折得很小。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'take_notes_anyway',
            text: '按他讲的抄，一个字不落',
            consequence:
                '你抄了整整两页，连他重复的句子都记了下来。'
                '回宿舍的路上你读了一遍，发现它其实什么都没说——'
                '但每一个字都在告诉你该说什么。'
                '你把这两页夹进了别的笔记里。',
            effect: StoryEffect(
              addKnowledge: ['dh_new_doctrine'],
              setFlags: ['dh_kept_record'],
              housePoints: 2,
              spirit: -1,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'do_whats_asked',
            text: '照他说的做，不引人注意',
            consequence:
                '你按他说的抄了、点头了、下课就走了。'
                '这一节你没被叫起来，也没被记住。'
                '走出教室的时候你想，这大概就是他要的效果。',
            effect: StoryEffect(
              setFlags: ['dh_kept_head_down'],
              spirit: 1,
              housePoints: 1,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'sit_with_friends',
            text: '不抄，和旁边的人小声对一对眼神',
            consequence:
                '你什么也没写，只是转头看了一眼同桌。'
                '他也看了你一眼，然后把视线收回去。'
                '整节课你们说了三句话，全是废话——'
                '但下课的时候，你觉得比他抄的那两页有用。',
            effect: StoryEffect(
              addKnowledge: ['dh_silent_signals'],
              setFlags: ['dh_found_allies'],
              affection: 3,
              spirit: 2,
            ),
            nextStepId: '',
          ),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch2_first_day',
        canonRefId: 'canon_dh_new_curriculum',
        chapterId: 'dh_ch2',
        timeCostDays: 5,
        setup:
            '开学第一天，点名的方式和往年不一样了。点到谁，谁就要站起来说清楚自己的来历。你把手放在膝盖上，尽量让自己看起来平常。',
        ambient: [
          '有人回答得很快，像是背过。',
          '教室后面站着两个人，从头到尾没坐下。',
          '窗外的天阴沉沉的。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'answer_plain',
            text: '按最普通的说法回答',
            consequence:
                '你说得很简单，简单到对方都懒得多问一句。你坐下的时候，背后有人在看你。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['dh_answered_plain'], spirit: 1),
          ),
          StoryChoiceDef(
            id: 'answer_proud',
            text: '把自己的来历说得清清楚楚',
            consequence:
                '你站直了说完。教室里安静了一下。那两个人交换了一个眼神，把你记下来了。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['dh_answered_proud'], reputation: 3, spirit: -2),
          ),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch2_new_class',
        canonRefId: 'canon_dh_quidditch_quiet',
        chapterId: 'dh_ch2',
        timeCostDays: 23,
        setup:
            '有一门课被改了内容。'
            '新课本上讲的东西，'
            '你在三年级的课本里见过——'
            '只不过那一年它被叫做"黑魔法"。'
            '而另一门课，现在叫"麻瓜研究"，'
            '课本里写着麻瓜"像动物一样低等"。',
        ambient: [
          '有人在课上当场站起来，被带走了。',
          '讲台上的那个人一直笑着，笑容没有到眼睛里。',
          '你把课本合上，听见心跳声。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'contradict',
            text: '在课上指出课本里那句话是错的',
            consequence:
                '你说了。声音不大，但整个教室都听见了。'
                '代价是关禁闭一整周。'
                '禁闭结束那天，'
                '有六个人在走廊上装作路过，'
                '其中一个朝你点了下头。',
            effect: StoryEffect(
              setFlags: ['dh_spoke_in_class'],
              addKnowledge: ['dh_said_it_wrong'],
              reputation: 4,
              spirit: -3,
            ),
          ),
          StoryChoiceDef(
            id: 'rewrite_notes',
            text: '不顶撞，但把正确的版本抄给每一个问你要笔记的人',
            consequence:
                '你抄了十一份正确的笔记。'
                '每一份的封面都写在别的东西底下。'
                '这件事比当众顶嘴慢，'
                '但到学期末，十一个人都还记得正确版本。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包', '银色钢笔'],
              addKnowledge: ['dh_eleven_copies'],
              setFlags: ['dh_kept_truth'],
              reputation: 2,
              spirit: -1,
            ),
          ),
          StoryChoiceDef(
            id: 'endure',
            text: '忍下来，把牙咬紧听完每一节课',
            consequence:
                '你听完了每一节课，一个字也没反驳。'
                '你告诉自己：'
                '撑到学期结束就好了。'
                '但学期结束还远得很。',
            effect: StoryEffect(
              setFlags: ['dh_endured'],
              spirit: -3,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch2_name_list',
        chapterId: 'dh_ch2',
        timeCostDays: 6,
        setup:
            '第二周，一张名单贴在了公共休息室的公告板上。'
            '不是成绩，也不是课表，是"需要额外留意"的人。'
            '有几个名字你认识——他们这周都还没回来。',
        ambient: [
          '有人站在名单前看了很久，然后走开了，没说一个字。',
          '第二天那张纸的边角被撕掉了一小块。',
          '有人开始避免和名单上的人走在一起。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'memorize_names',
            text: '把名单上每个名字都记住',
            consequence:
                '你在心里念了两遍，记住了大部分。'
                '后来的几个月里，你靠着这份名单躲开了一些麻烦，'
                '也靠着它认出了哪些人是可以说话的。',
            effect: StoryEffect(
              addKnowledge: ['dh_watch_list'],
              setFlags: ['dh_knew_the_list'],
              housePoints: 2,
              spirit: -2,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'tell_someone',
            text: '去告诉你认识的那个人：名单上有你',
            consequence:
                '你找到他，把他拉到楼梯拐角说了这件事。'
                '他听完点了点头，像是早就知道。'
                '"那我这周先不回去了。"——他说得很平静。'
                '你后来想过很多次，那天你至少做对了一件事。',
            effect: StoryEffect(
              addKnowledge: ['dh_warned_by_name'],
              setFlags: ['dh_warned_them'],
              affection: 5,
              reputation: 2,
              spirit: 2,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'stay_away',
            text: '不看了，走开',
            consequence:
                '你没看完就走了。'
                '你告诉自己那跟你没关系。'
                '但那几个名字你其实都记得——你只是不想承认。',
            effect: StoryEffect(
              setFlags: ['dh_looked_away'],
              spirit: -3,
            ),
            nextStepId: '',
          ),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch2_roll_call',
        chapterId: 'dh_ch2',
        timeCostDays: 5,
        setup:
            '新成立的巡查队开始在大厅点名。'
            '被点到的人要站到一边，'
            '然后被带走，'
            '第二天早上回来——或者第二天早上也没回来。'
            '名单是有人写的，这一点所有人都心知肚明。',
        ambient: [
          '大厅里站了不到二十个人，却安静得像没人。',
          '点名的声音很平，不带任何情绪。',
          '你盯着自己的鞋尖，一直没抬起来。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'stand_beside',
            text: '往被点名的人那边挪一步，站在他旁边',
            consequence:
                '你挪了一步。'
                '就一步。'
                '巡查队看了你两眼，没说话。'
                '那天晚上，被点名的那个人来敲了你的门，'
                '什么也没说，只是坐在门口待了一会儿。',
            effect: StoryEffect(
              setFlags: ['dh_stood_beside'],
              addKnowledge: ['dh_one_step'],
              reputation: 4,
              spirit: -2,
              targetNpcId: 'neville',
            ),
          ),
          StoryChoiceDef(
            id: 'copy_list',
            text: '把每一份名单都默记下来，晚上抄一份藏好',
            consequence:
                '你抄了四十七个名字。'
                '藏的地方只有你自己知道。'
                '这件事你没告诉任何人——'
                '包括你最信任的人。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包', '神秘符号'],
              addKnowledge: ['dh_list_of_47'],
              setFlags: ['dh_copied_list'],
              spirit: -2,
            ),
          ),
          StoryChoiceDef(
            id: 'look_down',
            text: '一直盯着地面，直到点名结束',
            consequence:
                '你盯着地面。'
                '点名结束了，人走了，'
                '你也走了。'
                '回宿舍的路你走了很久，'
                '每一步都像踩在别人的名字上。',
            effect: StoryEffect(
              setFlags: ['dh_looked_down'],
              spirit: -3,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第三章 · 地下（1997 年 11 月）→ canon_dh_underground
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'dh_ch3',
    bookId: 'dh',
    ordinal: 3,
    title: '地下',
    steps: [
      StoryStepDef(
        id: 'dh_ch3_room',
        chapterId: 'dh_ch3',
        timeCostDays: 5,
        onEnterText:
            '【第三章 · 地下】\n'
            '八楼那面墙上，有一扇只有"真的需要它"的时候才会出现的门。'
            '这一年，需要它的人很多。',
        setup:
            '有人在八楼的墙前来回走了三次。'
            '第四次，墙上出现了一扇门。'
            '门后面是一间堆满东西的屋子，'
            '角落里铺着七八张床，'
            '还有一台一直在低声说话的收音机。',
        ambient: [
          '屋里有你不认识的人，也有你以为已经离校的人。',
          '墙上挂着一张地图，上面有很多会动的小点。',
          '有人递给你一杯热的东西，手很稳。',
        ],
        canonRefId: 'canon_dh_underground',
        choices: [
          StoryChoiceDef(
            id: 'join_underground',
            text: '加入，问清楚能做什么、什么时候轮班',
            consequence:
                '你加入了。'
                '第一件事是排班：'
                '送饭、望风、记名单、擦地板。'
                '你领到的第一份活是——'
                '每天夜里十二点，把走廊尽头那扇窗打开一条缝。',
            effect: StoryEffect(
              addItems: ['计划书'],
              addKnowledge: ['dh_underground_shift'],
              setFlags: ['dh_joined_underground'],
              reputation: 3,
              spirit: 2,
              targetNpcId: 'neville',
            ),
            nextStepId: 'dh_ch3_first_night',),
          StoryChoiceDef(
            id: 'supply_only',
            text: '不加入，但每周留一包吃的在墙角',
            consequence:
                '你不加入，但每周偷偷留一包东西在墙角。'
                '第三周，墙角多了一张纸条：'
                '"够吃了，谢谢你。"'
                '你把纸条收好，一直留到最后。',
            effect: StoryEffect(
              addItems: ['南瓜馅饼', '巧克力蛙'],
              addKnowledge: ['dh_quiet_supply'],
              setFlags: ['dh_supplied_quietly'],
              reputation: 2,
              spirit: 1,
            ),
            nextStepId: 'dh_ch3_first_night',),
          StoryChoiceDef(
            id: 'stay_away',
            text: '绕开八楼，从那面墙前面快步走过去',
            consequence:
                '你绕开了。'
                '每次经过八楼，你都走得很快，'
                '眼睛看着前面。'
                '你知道那里有一扇门，'
                '你也知道自己没有走进去。',
            effect: StoryEffect(
              setFlags: ['dh_avoided_room'],
              addKnowledge: ['dh_walked_past'],
              spirit: -2,
            ),
            nextStepId: 'dh_ch3_first_night',),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch3_first_night',
        chapterId: 'dh_ch3',
        timeCostDays: 11,
        setup:
            '有求必应屋的门第一次为你打开是十一月的某个夜里。'
            '里面比你想的暖和，地上铺着几张毯子，'
            '角落里堆着不知道谁搬进来的面包。'
            '已经有三个人在了，看到你进来，谁都没有问为什么。',
        ambient: [
          '有人递给你一杯水，没说话。',
          '门口一直有个人守着，隔一会儿就贴着门听一下。',
          '有人在小声教一个新来的怎么走才不会被人看见。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'stay_overnight',
            text: '留下来，睡在这边',
            consequence:
                '你把毯子拉过来，在靠墙的位置躺下。'
                '夜里有人翻身的动静，也有人一直没睡。'
                '天亮之前你醒了，看到门口那个人还在那儿坐着。'
                '这是你第一次觉得，躲起来也可以是一种抵抗。',
            effect: StoryEffect(
              addKnowledge: ['dh_room_of_req_first'],
              setFlags: ['dh_slept_in_shelter'],
              affection: 4,
              spirit: 2,
              housePoints: 2,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'learn_the_route',
            text: '先学会怎么走，再决定留不留',
            consequence:
                '你跟着那个人走了两趟：'
                '从八楼那幅挂毯后面数三块砖，走廊走到头再折回来。'
                '这套走法你后来带过至少五个人。'
                '有人叫它"迷路"，其实它是这一年最清楚的一条路。',
            effect: StoryEffect(
              addKnowledge: ['dh_secret_route'],
              setFlags: ['dh_learned_route'],
              housePoints: 3,
              reputation: 2,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'bring_supplies',
            text: '回去一趟，把能带的东西都拿来',
            consequence:
                '你回宿舍把柜子里存的东西翻了一遍：'
                '两条围巾、半包饼干、一支多余的羽毛笔。'
                '第二天你抱着这些东西回去，门口的人接过去，'
                '说了那天晚上的第二句话："谢了。"',
            effect: StoryEffect(
              addKnowledge: ['dh_shelter_supplies'],
              setFlags: ['dh_brought_supplies'],
              affection: 3,
              satiety: -3,
              housePoints: 2,
            ),
            nextStepId: '',
          ),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch3_broadcast',
        canonRefId: 'canon_dh_banned_list',
        chapterId: 'dh_ch3',
        timeCostDays: 11,
        setup:
            '有人弄到一台旧收音机，每天晚上在固定时间转旋钮。大多数时候只有杂音。每到那个时候，屋里的人都会自觉安静下来。',
        ambient: [
          '有几次旋到某个位置，声音清楚了一下又没了。',
          '收音机放在床垫下面，天线用铁丝接着。',
          '有人负责望风。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'take_shift',
            text: '接过望风的那一班',
            consequence:
                '你守在门口听了两个小时。中间有一次脚步声靠近，你咳嗽了一声，里面的人立刻把收音机关了。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['dh_took_shift'], spirit: 3, targetNpcId: 'ginny', affection: 2),
          ),
          StoryChoiceDef(
            id: 'listen_only',
            text: '只听，不参与安排',
            consequence:
                '你每晚都听，坐在最边上。听的时候你什么也不说，但每一次杂音里出现的人名，你都在心里记一遍。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['dh_resistance_info'], setFlags: ['dh_listened_only'], spirit: 1),
          ),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch3_rumor',
        chapterId: 'dh_ch3',
        timeCostDays: 3,
        setup:
            '这个冬天走廊上最忙的人是传话的。'
            '一句"东边那间教室今晚别去"，传到第三个人嘴里'
            '就变成了"东边要出事"。'
            '没有人是故意说谎的，只是每一个人都想多说一点。',
        ambient: [
          '有两个人为了同一件事吵了起来，因为听到的版本不一样。',
          '有人开始在传话之前先问"你是从谁那儿听来的"。',
          '最安静的那个同学，反而是掌握最多消息的人。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'pass_it_exactly',
            text: '一句话只照原样传，不加一个字',
            consequence:
                '有人来问你听说了什么，你只说你知道的那半句。'
                '对方等了一会儿，见你不往下说，就走了。'
                '你传过的每一条消息后来都没有出过差错——'
                '在那一年，这已经算是很了不起的名声。',
            effect: StoryEffect(
              addKnowledge: ['dh_reliable_line'],
              setFlags: ['dh_exact_messenger'],
              reputation: 3,
              housePoints: 2,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'check_source',
            text: '先自己去看一眼再说',
            consequence:
                '你去了那间教室，门锁着，里面什么都没有。'
                '你回来把结论告诉他们，有两个人松了口气，'
                '还有一个不太高兴——他本来是打算晚上去的。'
                '从这天起，有几件事他们会先来问你。',
            effect: StoryEffect(
              addKnowledge: ['dh_verified_rumor'],
              setFlags: ['dh_verified_things'],
              housePoints: 3,
              reputation: 2,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'stop_passing',
            text: '不传了，别人来问就说不知道',
            consequence:
                '你开始对所有人说"我不知道"。'
                '一开始有人觉得你胆小，后来也没人再来问你了。'
                '你的这个冬天过得格外清净，也格外不知道外面在发生什么。',
            effect: StoryEffect(
              setFlags: ['dh_stopped_gossip'],
              spirit: 1,
              housePoints: 1,
            ),
            nextStepId: '',
          ),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch3_hiding',
        chapterId: 'dh_ch3',
        timeCostDays: 3,
        setup:
            '有人需要藏起来。'
            '不是一个模糊的"有人"——'
            '是一个你认识的人，'
            '此刻正站在你的门口，'
            '问能不能在你这儿待一晚上。',
        ambient: [
          '走廊上传来巡查队的脚步声，由远及近。',
          '你房间的壁橱刚好能塞进一个人。',
          '他在等你回答，没有催。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'open_door',
            text: '拉他进来，把壁橱清空',
            consequence:
                '你把他拉了进来，清空了壁橱。'
                '巡查队敲了你的门，你开了，'
                '说"我在复习"。'
                '他们看了看，走了。'
                '门关上的时候，你的后背全湿了。',
            effect: StoryEffect(
              addItems: ['勇气勋章'],
              addKnowledge: ['dh_opened_the_door'],
              setFlags: ['dh_opened_door'],
              reputation: 4,
              spirit: 1,
            ),
          ),
          StoryChoiceDef(
            id: 'give_cloak',
            text: '不开门，但把自己的斗篷和两枚加隆塞给他',
            consequence:
                '你没开门。'
                '你把斗篷从门缝里塞了出去，还有两枚加隆。'
                '"往北边走，"你说，"别走大路。"'
                '脚步声远了以后，你在门后坐了很久。',
            effect: StoryEffect(
              addItems: ['冬季斗篷'],
              galleons: -2,
              addKnowledge: ['dh_gave_the_cloak'],
              setFlags: ['dh_gave_cloak'],
              reputation: 2,
              spirit: -2,
            ),
          ),
          StoryChoiceDef(
            id: 'close_door',
            text: '关灯，装作已经睡了',
            consequence:
                '你关了灯。'
                '脚步声在门口停了一下，然后继续往前。'
                '那一晚上你没有睡着，'
                '第二天早上走廊干干净净，'
                '什么痕迹都没有。',
            effect: StoryEffect(
              setFlags: ['dh_closed_door'],
              spirit: -3,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch3_radio',
        canonRefId: 'canon_dh_room_of_requirement',
        chapterId: 'dh_ch3',
        timeCostDays: 2,
        setup:
            '有一台秘密的电台，每天夜里念一串名字。'
            '念的都是失踪的、被关起来的、'
            '以及已经确认不在了的人。'
            '很多人冒着风险在听。'
            '这一晚你也在。',
        ambient: [
          '收音机的信号很差，要把耳朵贴上去才听得清。',
          '屋里没有人说话，只有电流声。',
          '念到某个名字的时候，有人转过了身。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'write_names',
            text: '把每一个被念到的名字抄下来',
            consequence:
                '你抄了满满两页。'
                '抄到最后一页时手抖得握不住笔，'
                '你把笔放下，'
                '换了一只手继续。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包', '新羽毛笔'],
              addKnowledge: ['dh_radio_names'],
              setFlags: ['dh_wrote_names'],
              spirit: -3,
            ),
          ),
          StoryChoiceDef(
            id: 'hold_someone',
            text: '关掉收音机，先陪那个听到熟人名字的人坐一会儿',
            consequence:
                '你伸手把收音机关了。'
                '屋里先是一静，'
                '然后那个人出声了——'
                '第一次出声。'
                '他讲了一个关于那个名字的、很好的故事。',
            effect: StoryEffect(
              setFlags: ['dh_held_someone'],
              reputation: 2,
              affection: 4,
              spirit: -1,
              targetNpcId: 'luna',
            ),
          ),
          StoryChoiceDef(
            id: 'keep_listening',
            text: '什么都不说，一直听到信号断掉',
            consequence:
                '你一直听到信号彻底断掉。'
                '电流声停了以后，屋里安静了很久，'
                '大家才一个个起身，'
                '各自回到各自的位置上去。',
            effect: StoryEffect(
              setFlags: ['dh_kept_listening'],
              spirit: -2,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第四章 · 寒冬（1997-12 ~ 1998-02）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'dh_ch4',
    bookId: 'dh',
    ordinal: 4,
    title: '寒冬',
    steps: [
      StoryStepDef(
        id: 'dh_ch4_quiet_holiday',
        chapterId: 'dh_ch4',
        timeCostDays: 23,
        setup:
            '圣诞假期留校的人比往年多，礼堂里照样摆了树、点了蜡烛，'
            '长桌却空了一多半。留校的学生三三两两坐得很开，'
            '谁都不太说话。窗外的雪下得很轻，几乎听不见声音。'
            '这是一个所有人都在心里对不上账的假期。',
        ambient: [
          '有人在桌角堆了一小摞没人认领的圣诞卡片。',
          '蜡烛烧到一半，蜡油顺着烛台流下来凝成一小片。',
          '远处的走廊里传来脚步声，走过去之后又安静了。',
        ],
        canonRefId: 'canon_dh_holidays_alone',
        onEnterText: '今年没有人唱歌。',
        choices: [
          StoryChoiceDef(
            id: 'write_names',
            text: '把还认识的名字一个个写下来，收好',
            consequence:
                '你在羊皮纸背面写了十几个名字，写完发现其中两个'
                '你已经很久没有见过了。你把纸折成很小一块塞进内袋，'
                '觉得这大概是这个假期唯一有用的事。',
            effect: StoryEffect(
              addItems: ['写着名字的纸片'],
              addKnowledge: ['dh_kept_names_list'],
              setFlags: ['dh_kept_a_list'],
              spirit: -2,
            ),
            nextStepId: 'dh_ch4_burnt_hand',
          ),
          StoryChoiceDef(
            id: 'help_kitchen',
            text: '去厨房帮忙，让留下来的低年级至少吃顿热的',
            consequence:
                '家养小精灵们忙得脚不沾地，看见有人来帮忙慌得直鞠躬。'
                '你和几个留校的同学把热汤端到长桌尽头，'
                '那顿饭吃得很安静，但没有人空着肚子离开。',
            effect: StoryEffect(
              addKnowledge: ['dh_holiday_kitchen_help'],
              setFlags: ['dh_helped_holiday_meal'],
              affection: 2,
              targetNpcId: 'hannah',
              spirit: 3,
              housePoints: 2,
            ),
            nextStepId: 'dh_ch4_burnt_hand',
          ),
          StoryChoiceDef(
            id: 'stay_hidden',
            text: '大部分时间待在有求必应屋，不主动露面',
            consequence:
                '那间屋子这几天一直开着，里面的人轮流去厨房取东西。'
                '你把自己的时间花在记录从各种渠道听来的消息上，'
                '写满了两页就换一张新的。安静是这里唯一的优点。',
            effect: StoryEffect(
              addKnowledge: ['dh_kept_records'],
              setFlags: ['dh_stayed_hidden_holiday'],
              spirit: -1,
            ),
            nextStepId: 'dh_ch4_burnt_hand',
          ),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch4_burnt_hand',
        chapterId: 'dh_ch4',
        timeCostDays: 12,
        setup:
            '罚抄结束之后，你的右手握不住笔。'
            '回到宿舍，同屋的人把台灯挪过来，'
            '谁都没问罚了多少遍，只是把洗手的水放好了。',
        ambient: [
          '那支用过的笔被放到抽屉最里层，你没有再拿出来。',
          '第二天有人问你手怎么了，你说写字写多了。',
          '那周交上来的一份作业，字迹明显和以前不一样。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'let_them_help',
            text: '把手伸出去，让他们帮你上药',
            consequence:
                '有人替你缠上布条，缠得不好看但很紧。'
                '你们聊了些别的，从头到尾没提那件事。'
                '第二天早上，布条是新的。',
            effect: StoryEffect(
              addKnowledge: ['dh_they_helped'],
              setFlags: ['dh_accepted_help'],
              affection: 4,
              spirit: 3,
              housePoints: 2,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'hide_it',
            text: '把手插进口袋，谁也不说',
            consequence:
                '你把手收起来，吃饭用左手，写字也歪着写。'
                '没有一个人问第二次。'
                '你保住了不想被看见的那部分，代价是什么都要自己扛。',
            effect: StoryEffect(
              setFlags: ['dh_hid_the_mark'],
              spirit: -2,
              housePoints: 2,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'write_with_left',
            text: '练着用左手写字',
            consequence:
                '你花了三个晚上让左手能写出能认的字。'
                '到周末的时候，你的左撇子已经能应付作业了。'
                '这个技能后来在好几节要记东西的课上帮了你。',
            effect: StoryEffect(
              addKnowledge: ['dh_left_hand'],
              setFlags: ['dh_learned_lefthand'],
              housePoints: 3,
              energy: -4,
            ),
            nextStepId: '',
          ),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch4_punishment',
        canonRefId: 'canon_dh_underground_resistance',
        chapterId: 'dh_ch4',
        timeCostDays: 11,
        setup:
            '冬天最难熬的不是冷，是"惩罚"开始有了正式的样式。'
            '关禁闭不再是抄写，'
            '而是一整夜一整夜地做某种重复而无意义的事，'
            '第二天照常上课，'
            '谁也不准提昨晚去哪了。',
        ambient: [
          '有人回来的时候手上多了几道口子。',
          '你学会了在袖口里藏一小块白鲜。',
          '走廊的窗玻璃上结了很厚的霜，看不见外面。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'carry_dose',
            text: '在袖口里藏一小瓶药，谁回来就递给谁',
            consequence:
                '你藏了整整一个冬天。'
                '递出去十七次。'
                '第十七次的那个孩子问你为什么总有这个，'
                '你说："因为我上次没有。"',
            effect: StoryEffect(
              addItems: ['白鲜香精'],
              addKnowledge: ['dh_seventeen_times'],
              setFlags: ['dh_carried_medicine'],
              reputation: 3,
              spirit: -1,
            ),
            nextStepId: 'dh_ch4_after_punish',),
          StoryChoiceDef(
            id: 'take_turn',
            text: '替一个已经扛了三晚的同学去一次',
            consequence:
                '你替他去了一晚。'
                '那一晚很长，'
                '但你回来的时候他站在门口等你，'
                '手里端着一杯热的东西。',
            effect: StoryEffect(
              setFlags: ['dh_took_a_turn'],
              reputation: 3,
              affection: 4,
              spirit: -2,
              targetNpcId: 'ginny',
            ),
            nextStepId: 'dh_ch4_after_punish',),
          StoryChoiceDef(
            id: 'endure_winter',
            text: '熬过去，把每一天当成最后一天来过',
            consequence:
                '你熬了过来。'
                '冬天结束的时候你瘦了整整一圈，'
                '但你一次也没有被记在名单上。',
            effect: StoryEffect(
              setFlags: ['dh_endured_winter'],
              spirit: -3,
            ),
            nextStepId: 'dh_ch4_after_punish',),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch4_after_punish',
        chapterId: 'dh_ch4',
        timeCostDays: 11,
        setup:
            '被罚的人回宿舍的时候手都在抖。有人想帮他，被他摆手推开了。屋里的人都围了过来，但谁也没先开口。',
        ambient: [
          '有人把热水倒在杯子里递过去。',
          '屋里的人一个都没出去。',
          '窗外的风把窗框吹得直响。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'sit_close',
            text: '坐到他旁边，不说话',
            consequence:
                '你坐过去，什么也没问。过了很久他小声说了句谢谢。你说嗯，然后继续坐着。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['dh_comforted'], spirit: 2, targetNpcId: 'ginny', affection: 3),
          ),
          StoryChoiceDef(
            id: 'organize_help',
            text: '把大家组织起来，轮流照看他',
            consequence:
                '你排了个班，谁什么时候来看一眼、带什么。有人笑你小题大做，但没人不照做。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['dh_organized_help'], reputation: 3, spirit: 2),
          ),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch4_radio_night',
        chapterId: 'dh_ch4',
        timeCostDays: 10,
        setup:
            '地下电台第一次被接进公共休息室那个晚上，'
            '屋里的人比平时多了一倍，灯是关着的。'
            '广播里的声音是熟悉的，念了一段没什么感情的话，'
            '然后放了一首歌。',
        ambient: [
          '有人跟着哼了两句，被旁边的人按住了肩膀。',
          '门口一直有人看着走廊。',
          '歌放完之后，整间屋子安静了几秒才重新有人说话。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'listen_all',
            text: '从头听到尾，一句话不落',
            consequence:
                '你听完了整段，包括中间那几秒的杂音。'
                '有人问你听懂了没有，你说没有。'
                '"没关系。"他说，"知道还有人在说话就够了。"',
            effect: StoryEffect(
              addKnowledge: ['dh_radio_voice'],
              setFlags: ['dh_heard_the_signal'],
              spirit: 4,
              affection: 2,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'keep_watch',
            text: '不进去听，站在门口守夜',
            consequence:
                '你在门外站了整整四十分钟，'
                '听见里面的人笑了一声、又安静下去。'
                '歌说完之后有人出来换你，问你要不要进去听听，'
                '你说不用了，我都听见了。',
            effect: StoryEffect(
              addKnowledge: ['dh_stood_guard'],
              setFlags: ['dh_kept_watch'],
              reputation: 3,
              housePoints: 3,
              energy: -3,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'write_it_down',
            text: '记下广播里说的那几个人名',
            consequence:
                '你摸黑在本子上写了几个字，写得很歪。'
                '第二天你核对了公告板，发现有一个名字不在上面——'
                '也就是说，广播比公告板多知道一个人。'
                '这条消息你后来一直留在身上。',
            effect: StoryEffect(
              addKnowledge: ['dh_radio_names'],
              setFlags: ['dh_recorded_names'],
              housePoints: 3,
              spirit: -1,
            ),
            nextStepId: '',
          ),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch4_christmas',
        canonRefId: 'canon_dh_patrol_squads',
        chapterId: 'dh_ch4',
        timeCostDays: 10,
        setup:
            '圣诞。'
            '城堡里的装饰被换成了另一种颜色，'
            '餐厅的长桌被拆成了一张张小桌。'
            '往年这时候，会有人在走廊里追着撒彩带。'
            '今年整层楼没有一点声音。',
        ambient: [
          '壁炉照常烧，但没人围过去。',
          '有低年级生偷偷在枕头下塞了一只袜子。',
          '你把去年留下的那截彩带找了出来。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'hang_ribbon',
            text: '把去年留下的那截彩带挂到公共休息室门口',
            consequence:
                '你挂了上去。'
                '第二天早上它还在——'
                '要知道，这一年的任何东西都留不到第二天。'
                '再后来，门口挂了七八截不同颜色的。',
            effect: StoryEffect(
              setFlags: ['dh_hung_ribbon'],
              addKnowledge: ['dh_eight_ribbons'],
              reputation: 3,
              spirit: 2,
            ),
            nextStepId: 'dh_ch4_quiet_christmas',),
          StoryChoiceDef(
            id: 'small_gift',
            text: '给每一个还在的人准备一份很小很小的东西',
            consequence:
                '你准备了二十份：'
                '一块糖、一张卡片、一句写下来的话。'
                '分完最后一份，'
                '你给自己留了一张空白的——'
                '因为你想不出该对自己说什么。',
            effect: StoryEffect(
              addItems: ['手写贺卡', '巧克力蛙'],
              setFlags: ['dh_small_gifts'],
              reputation: 2,
              affection: 3,
              spirit: 1,
              targetNpcId: 'luna',
            ),
            nextStepId: 'dh_ch4_quiet_christmas',),
          StoryChoiceDef(
            id: 'alone_christmas',
            text: '一个人待着，哪也不去',
            consequence:
                '你一个人待了一整天。'
                '天黑的时候有人敲了门，'
                '你说"我睡了"。'
                '门外的人站了一会儿，走了。',
            effect: StoryEffect(
              setFlags: ['dh_alone_christmas'],
              spirit: -2,
            ),
            nextStepId: 'dh_ch4_quiet_christmas',),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch4_quiet_christmas',
        chapterId: 'dh_ch4',
        timeCostDays: 14,
        setup:
            '这个圣诞没有树，也没有宴会。留下来的人凑在炉火边，各自说着以前在家怎么过节。炉火噼啪响着，把屋子照得很暖。',
        ambient: [
          '有人用纸折了个很小的星星挂在窗上。',
          '炉火映在每个人的脸上。',
          '外面在下雪，落在地上就化了。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'share_stories',
            text: '讲一个自己家的圣诞',
            consequence:
                '你讲了个很小的事——小时候家里怎么抢最后一块点心。大家都笑了，有人也接着讲了一个。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['dh_shared_stories'], spirit: 5, targetNpcId: 'ron', affection: 2),
          ),
          StoryChoiceDef(
            id: 'keep_watch',
            text: '不多说，坐在靠门的位置',
            consequence:
                '你坐在能看见门口的地方。听着他们说话，偶尔起身去看一眼走廊。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['dh_kept_watch'], spirit: 1),
          ),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch4_escape',
        canonRefId: 'canon_dh_spring_tension',
        chapterId: 'dh_ch4',
        timeCostDays: 14,
        setup:
            '二月的某天夜里，地下组织被人告发了。'
            '屋子被查，'
            '大部分人从一条早就准备好的通道撤了出去，'
            '但还有三个人没来得及。'
            '消息传到的时候，你只有几分钟。',
        ambient: [
          '八楼的走廊上全是脚步声和喊声。',
          '那面墙上现在什么都没有——门不再出现了。',
          '有人把一张纸条塞进你手里就跑了。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'run_distract',
            text: '往相反方向跑，把追的人引开',
            consequence:
                '你往相反的方向跑，'
                '一路撞翻了三个烛台。'
                '他们跟了你两条走廊。'
                '你被抓住了，'
                '但那三个人走了。'
                '这笔账你自己算过，觉得划算。',
            effect: StoryEffect(
              addItems: ['勇气勋章'],
              addKnowledge: ['dh_ran_the_wrong_way'],
              setFlags: ['dh_distracted'],
              reputation: 5,
              spirit: -3,
            ),
          ),
          StoryChoiceDef(
            id: 'open_passage',
            text: '按原计划去开那条通道，然后守在门口数人头',
            consequence:
                '你去开了通道。'
                '你站在门口数：'
                '十一个、十二个、十三个……'
                '最后一个是你自己。'
                '门在身后合上的时候，你听见外面有人在喊你的名字。',
            effect: StoryEffect(
              setFlags: ['dh_held_passage'],
              addKnowledge: ['dh_counted_thirteen'],
              reputation: 4,
              spirit: -1,
            ),
          ),
          StoryChoiceDef(
            id: 'hide_self',
            text: '先把自己藏好——这也是计划的一部分',
            consequence:
                '你藏好了自己。'
                '这确实是计划里写的一条：'
                '"保全自己，才有下一次。"'
                '只是那天晚上，'
                '这句话念起来格外不像一句安慰。',
            effect: StoryEffect(
              setFlags: ['dh_saved_self'],
              spirit: -2,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第五章 · 潜回（1998-03 ~ 04）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'dh_ch5',
    bookId: 'dh',
    ordinal: 5,
    title: '潜回',
    steps: [
      StoryStepDef(
        id: 'dh_ch5_return',
        chapterId: 'dh_ch5',
        timeCostDays: 11,
        setup:
            '三月。有人回来了。'
            '不是从大门回来的——'
            '是从一条谁都没料到的通道，'
            '直接出现在了霍格莫德。'
            '消息像火一样传遍了城堡，'
            '所有人都在等一个信号。',
        ambient: [
          '走廊里第一次有人敢抬头看巡查队。',
          '有人在墙上刻了一个记号，第二天出现了十几个。',
          '你把藏了半年的那份名单又翻了出来。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'spread_signal',
            text: '把"他们回来了"这件事，用最安全的方式传下去',
            consequence:
                '你用了三年级学的一个办法：'
                '只在两个人都认识第三个人的时候才开口。'
                '一天之内，整座城堡都知道了。'
                '巡查队到晚上才发现。',
            effect: StoryEffect(
              setFlags: ['dh_spread_signal'],
              addKnowledge: ['dh_three_person_rule'],
              reputation: 3,
              spirit: 2,
            ),
            nextStepId: 'dh_ch5_news',),
          StoryChoiceDef(
            id: 'prepare_room',
            text: '提前把有求必应屋重新打开，铺好床、备好水',
            consequence:
                '你在八楼的墙前走了三次。'
                '第四次，门出现了。'
                '你一个人铺了三十张床，'
                '铺到一半的时候，后面有人接过了你手里的毯子。',
            effect: StoryEffect(
              addItems: ['保暖毛线帽'],
              setFlags: ['dh_prepared_room'],
              addKnowledge: ['dh_thirty_beds'],
              reputation: 3,
              spirit: 1,
            ),
            nextStepId: 'dh_ch5_news',),
          StoryChoiceDef(
            id: 'wait_quiet',
            text: '不动，等明确的信号出来再说',
            consequence:
                '你按兵不动。'
                '事实证明你是对的——'
                '那天有六个人因为太早行动被抓了。'
                '谨慎也是勇气的一种，只是没人会为它发勋章。',
            effect: StoryEffect(
              setFlags: ['dh_waited'],
              spirit: -1,
            ),
            nextStepId: 'dh_ch5_news',),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch5_news',
        chapterId: 'dh_ch5',
        timeCostDays: 10,
        setup:
            '回来的人带来了外面的消息，一条比一条重。有人听完就出去了。有人不停地往门口看，像是在等谁。',
        ambient: [
          '礼堂里的人越来越多，椅子不够坐。',
          '有人在门口小声通报着还有什么人到了。',
          '蜡烛的光比平时亮，像是要照清每一张脸。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'find_friends',
            text: '先把自己认识的人找齐',
            consequence:
                '你挨个看过去，在人堆里找到了几个熟悉的脸。你们什么也没说，只是站得近了一点。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['dh_found_friends'], spirit: 4, targetNpcId: 'ginny', affection: 3),
          ),
          StoryChoiceDef(
            id: 'listen_briefing',
            text: '挤到前面去听安排',
            consequence:
                '你挤到前排，把每一条安排都听清了。听到关键的地方，你在心里默念了一遍。',
            nextStepId: '',
            effect: StoryEffect(addKnowledge: ['dh_battle_plan'], setFlags: ['dh_heard_briefing'], spirit: 1),
          ),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch5_evacuate',
        canonRefId: 'canon_dh_evacuation_prep',
        chapterId: 'dh_ch5',
        timeCostDays: 10,
        setup:
            '开战前最重要的一件事不是打，是走。'
            '所有未满年龄的学生都要从同一条通道撤离，'
            '而这条通道的入口，'
            '在白天是巡查队的必经之路。',
        ambient: [
          '撤离名单上有四百多个名字，孩子占了一半。',
          '有人把一年级生排在最前面，因为走得慢。',
          '你在门口站着，一遍遍核对人数。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'lead_evacuation',
            text: '带一队低年级生走，自己最后一个进通道',
            consequence:
                '你带了十四个孩子。'
                '路上最小的那个鞋掉了，'
                '你把他背了最后一段。'
                '你最后一个进通道，'
                '回身把入口的画框扶正。',
            effect: StoryEffect(
              addItems: ['勇气勋章'],
              addKnowledge: ['dh_last_one_in'],
              setFlags: ['dh_led_evacuation'],
              reputation: 5,
              spirit: 1,
              targetNpcId: 'colin',
            ),
            nextStepId: 'dh_ch5_last_lesson',),
          StoryChoiceDef(
            id: 'guard_entrance',
            text: '守在通道口，撑到最后一队进去再撤',
            consequence:
                '你守在入口。'
                '第一队、第二队……'
                '第七队进去的时候，'
                '走廊尽头出现了黑袍。'
                '你撑了大概四十秒，'
                '然后跟着第八队一起滑了进去。',
            effect: StoryEffect(
              setFlags: ['dh_guarded_entrance'],
              addKnowledge: ['dh_forty_seconds'],
              reputation: 4,
              spirit: -1,
            ),
            nextStepId: 'dh_ch5_last_lesson',),
          StoryChoiceDef(
            id: 'stay_and_fight',
            text: '不走——留下的人里也得有会拿魔杖的',
            consequence:
                '你没走。'
                '你在名单上把自己的名字划掉了，'
                '签在了另一张纸的最后一行。'
                '签完你抬头，'
                '发现那张纸上已经写满了名字。',
            effect: StoryEffect(
              setFlags: ['dh_stayed_to_fight'],
              addKnowledge: ['dh_signed_the_last_line'],
              reputation: 4,
              spirit: 2,
            ),
            nextStepId: 'dh_ch5_last_lesson',),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch5_last_lesson',
        chapterId: 'dh_ch5',
        timeCostDays: 8,
        setup:
            '要转移低年级生的那几天，课还在照常上。'
            '来上课的老师看了一眼空出来的几个位置，'
            '没有点名，直接把书翻开讲新课。'
            '那一节讲得比平时慢。',
        ambient: [
          '有人一边听课一边把行李收在桌子下面。',
          '这一节课的笔记，很多人抄得格外认真。',
          '下课铃响了，老师站了一会儿才说"下课"。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'copy_it_fully',
            text: '把板书完整抄下来，给要走的人留一份',
            consequence:
                '你抄完了一整页，字比平时工整。'
                '你把纸折起来塞给那个下午就要走的同学。'
                '他愣了一下，说了句"我等下看"。'
                '这张纸后来被转手过几次，你也不知道到了谁手上。',
            effect: StoryEffect(
              addKnowledge: ['dh_last_notes'],
              setFlags: ['dh_shared_notes'],
              affection: 4,
              housePoints: 3,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'help_pack',
            text: '不听了，帮他们把箱子搬到楼下',
            consequence:
                '你一个下午上下楼梯跑了六趟。'
                '最后一趟下来的时候，马车已经等在门口了。'
                '有人探出车窗喊了你的名字，喊了两次，你听见了。',
            effect: StoryEffect(
              addKnowledge: ['dh_helped_evacuate'],
              setFlags: ['dh_helped_pack'],
              affection: 5,
              reputation: 2,
              energy: -5,
              housePoints: 3,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'stay_for_class',
            text: '留下来把这节课上完',
            consequence:
                '你是少数几个把课听完的人之一。'
                '老师讲到最后一页，抬头看了看那些空位置，'
                '然后合上了书。'
                '你忽然明白，他今天讲慢一点，是在等他们。',
            effect: StoryEffect(
              addKnowledge: ['dh_saw_teacher_gesture'],
              setFlags: ['dh_stayed_to_end'],
              housePoints: 4,
              spirit: 2,
            ),
            nextStepId: '',
          ),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch5_send_off',
        chapterId: 'dh_ch5',
        timeCostDays: 8,
        setup:
            '低年级的人要先走。通道口排起了长队，有人一路都没有回头。你站在旁边，看着队伍一点一点往前挪。',
        ambient: [
          '有人把围巾解下来给了比自己小的。',
          '通道里的火把一根接一根点起来。',
          '外面的声音隔着石壁传进来，闷闷的。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'help_queue',
            text: '在队尾帮着维持秩序',
            consequence:
                '你一个个点过去，把人送到门口。有个一年级的小孩抓着你的袖子不肯放，你蹲下来跟他说了几句话才松开。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['dh_helped_evacuate'], reputation: 3, spirit: 2),
          ),
          StoryChoiceDef(
            id: 'send_one',
            text: '专门送一个认识的人走',
            consequence:
                '你一直把她送到通道口。她回头看了你一眼，你冲她摆了摆手，让她快走。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['dh_sent_off'], spirit: 3, targetNpcId: 'ginny', affection: 4),
          ),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch5_night_before',
        chapterId: 'dh_ch5',
        timeCostDays: 7,
        setup:
            '决战前一夜。'
            '城堡里没有课，没有点名，也没有宵禁——'
            '因为没有人还有心思去管这些。'
            '所有人都在做同一件事：'
            '把明天要做的事，在心里过一遍。',
        ambient: [
          '有人把校袍换成了方便跑动的衣服。',
          '有人第一次给家里写信，写了整整一夜。',
          '窗外很静，静得能听见湖水的声音。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'write_letter',
            text: '给家里写一封可能寄不出去的信',
            consequence:
                '你写了一夜。'
                '写完你把它塞进信封，'
                '写上地址，放在枕头下面。'
                '第二天早上你把它带在身上，'
                '一直到很多天后才寄出去。',
            effect: StoryEffect(
              addItems: ['手写贺卡', '银色钢笔'],
              setFlags: ['dh_wrote_letter'],
              spirit: -1,
            ),
          ),
          StoryChoiceDef(
            id: 'check_others',
            text: '挨个走一遍，确认每个人都睡了一会儿',
            consequence:
                '你走遍了整层楼。'
                '有三个人没睡，你也劝不动，'
                '就坐下来陪他们各待了一会儿。'
                '天亮的时候，你反而是最清醒的那个。',
            effect: StoryEffect(
              setFlags: ['dh_checked_others'],
              reputation: 2,
              affection: 3,
              spirit: 1,
              targetNpcId: 'ron',
            ),
          ),
          StoryChoiceDef(
            id: 'sharpen_wand',
            text: '一个人去空教室，把会用的咒从头练一遍',
            consequence:
                '你练到手指发麻。'
                '缴械咒、铁甲咒、昏睡咒——'
                '你只练这三样，'
                '因为你清楚明天用得上的就是这三样。',
            effect: StoryEffect(
              addKnowledge: ['dh_three_spells'],
              setFlags: ['dh_practiced'],
              spirit: 1,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第六章 · 大决战（1998 年 5 月）→ canon_dh_final_battle
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'dh_ch6',
    bookId: 'dh',
    ordinal: 6,
    title: '大决战',
    steps: [
      StoryStepDef(
        id: 'dh_ch6_battle',
        chapterId: 'dh_ch6',
        timeCostDays: 2,
        onEnterText:
            '【第六章 · 大决战】\n'
            '这一夜之后，城堡的名字前面会多两个字——"保卫"。'
            '而你，会记得自己那天站在哪里。',
        setup:
            '战斗是天黑之后开始的。'
            '城堡的每一道门、每一段楼梯、每一座桥都成了阵地。'
            '有人守着通往塔楼的通道，'
            '有人在院子里和比自己大三倍的东西对峙。'
            '而你被分配到的位置，'
            '是通往低年级生藏身处的最后一道门。',
        ambient: [
          '石头在震动，灰尘从天花板上落下来。',
          '有人在你身边倒下，又被人拖了下去。',
          '你听见有人在喊你的名字，但看不清是谁。',
        ],
        canonRefId: 'canon_dh_final_battle',
        choices: [
          StoryChoiceDef(
            id: 'hold_the_door',
            text: '守住那道门，退一步都不退',
            consequence:
                '你守住了。'
                '不是因为你强——'
                '是因为每退一步，后面就有十几个孩子。'
                '你后来才知道，你守的那道门，'
                '一整夜都没有被打开过。',
            effect: StoryEffect(
              addItems: ['勇气勋章'],
              addKnowledge: ['dh_held_the_last_door'],
              setFlags: ['dh_held_the_door'],
              reputation: 5,
              spirit: -2,
            ),
            requireFlag: 'dh_stayed_to_fight',
            nextStepId: 'dh_ch6_floor',),
          StoryChoiceDef(
            id: 'carry_wounded',
            text: '在走廊上来回跑，把受伤的人往医疗点拖',
            consequence:
                '你记不清自己跑了多少趟。'
                '只记得每一次放下人，'
                '手上都是热的。'
                '有一趟你拖的是教过你三年书的先生，'
                '他比你想的轻得多。',
            effect: StoryEffect(
              addItems: ['白鲜香精'],
              addKnowledge: ['dh_carried_the_wounded'],
              setFlags: ['dh_carried_wounded'],
              reputation: 4,
              spirit: -1,
              targetNpcId: 'pomfrey',
            ),
            nextStepId: 'dh_ch6_floor',),
          StoryChoiceDef(
            id: 'guard_children',
            text: '去藏身处，守在孩子们外面，一个都不让进来',
            consequence:
                '你守在门外。'
                '里面有人想出来帮忙，被你拦了回去。'
                '一个十岁的孩子隔着门问："我们是不是要死了。"'
                '你说："不会，我在。"'
                '——你那天说了整整一夜的"我在"。',
            effect: StoryEffect(
              setFlags: ['dh_guarded_children'],
              addKnowledge: ['dh_said_i_am_here'],
              reputation: 4,
              spirit: -1,
            ),
            nextStepId: 'dh_ch6_floor',),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch6_floor',
        chapterId: 'dh_ch6',
        timeCostDays: 1,
        setup:
            '战斗开始之后，你被分到七楼的一段走廊。'
            '任务是"别让任何东西从这头过去"。'
            '这层楼只剩三盏灯还亮着，其余全灭了。',
        ambient: [
          '墙上的画里早就空了，画框后面的洞还是热的。',
          '楼下的声音一阵一阵传上来，说不清是什么。',
          '有人不停地从你身边跑过去，又有人从另一头跑回来。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'hold_position',
            text: '站在原处，寸步不移',
            consequence:
                '你在那个位置站了很久，久到腿都麻了。'
                '中间有东西撞过两次门，你和旁边的人一起顶住了。'
                '后来有人来换班，说了一句"这层没丢"。'
                '你这才知道，"守住"原来是这么具体的一件事。',
            effect: StoryEffect(
              addKnowledge: ['dh_held_the_line'],
              setFlags: ['dh_held_floor'],
              reputation: 4,
              housePoints: 4,
              spirit: -2,
              energy: -6,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'carry_wounded',
            text: '不管守不守，先把受伤的人送下去',
            consequence:
                '你扶着一个人下了两段楼梯。'
                '他比你想的重，中途停下来歇过一次。'
                '送到楼下的时候有人接手，你转身又上去了。'
                '那一天你上下楼跑的次数，你自己都数不清。',
            effect: StoryEffect(
              addKnowledge: ['dh_carried_wounded'],
              setFlags: ['dh_saved_others'],
              affection: 5,
              reputation: 3,
              energy: -8,
              housePoints: 3,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'find_friends',
            text: '离开岗位，先去找你认识的人',
            consequence:
                '你跑遍了三层楼找他们。'
                '找到两个，还有一个没找到。'
                '你们没有再分开，一直到天亮。'
                '那个没找到的人，第二天早上你在礼堂里见到了。',
            effect: StoryEffect(
              addKnowledge: ['dh_found_friends'],
              setFlags: ['dh_left_post_for_them'],
              affection: 6,
              spirit: -2,
              housePoints: 2,
            ),
            nextStepId: '',
          ),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch6_inside',
        chapterId: 'dh_ch6',
        timeCostDays: 1,
        setup:
            '战斗打起来之后，城堡里的每一个走廊都成了战场。有人守在这里，有人往那边跑。你贴着墙往前走，尽量避开窗口的位置。',
        ambient: [
          '墙上的画像全都空了。',
          '有台阶被咒语击塌了一角。',
          '远处传来一声很响的轰塌声。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'hold_position',
            text: '守住自己被安排的位置',
            consequence:
                '你守了很长时间。中间有人从你面前跑过去，你差点认错人。后来有人来换班，你才发现自己腿都站麻了。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['dh_held_position'], reputation: 3, spirit: 1),
          ),
          StoryChoiceDef(
            id: 'run_to_help',
            text: '听见有人喊，往那个方向跑',
            consequence:
                '你跑过去的时候已经晚了半步。但你把人拖了出来。拖出来的时候你的手在抖。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['dh_ran_to_help'], reputation: 2, spirit: -2),
          ),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch6_after_dawn',
        chapterId: 'dh_ch6',
        timeCostDays: 2,
        setup:
            '天亮之后，所有能站起来的人都到了礼堂。'
            '地上并排放着一些人，盖着东西。'
            '没有人说话，连咳嗽的声音都显得很响。',
        ambient: [
          '有人一家一家地找，找到就坐到旁边去。',
          '有人站在门口一直没进来。',
          '窗外的天很好，亮得有点不真实。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'find_and_sit',
            text: '先找到你的那几个，然后坐下',
            consequence:
                '你把他们都找到了，一个不少。'
                '你们在靠墙的位置坐成一排，谁也没有靠住谁。'
                '坐到中午的时候，有人开始说饿了。'
                '那一刻你觉得，这句话比什么都好。',
            effect: StoryEffect(
              addKnowledge: ['dh_all_found'],
              setFlags: ['dh_sat_together_dawn'],
              affection: 5,
              spirit: 3,
              housePoints: 2,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'help_tend',
            text: '去帮忙照顾受伤的人',
            consequence:
                '你跟着几个高年级生跑了一上午。'
                '你做不了什么，只是帮着递东西、按住绷带。'
                '有个平时从没跟你说过话的人，握了一下你的手腕。',
            effect: StoryEffect(
              addKnowledge: ['dh_tended_wounded'],
              setFlags: ['dh_helped_after'],
              reputation: 4,
              affection: 3,
              energy: -5,
              housePoints: 3,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'go_outside',
            text: '一个人走到外面去',
            consequence:
                '你走出礼堂，穿过门厅，站到了城堡的台阶上。'
                '操场上到处是夜里留下的痕迹。'
                '你在那儿站了很久，直到有人出来叫你回去。'
                '你回去的时候，手里攥着一样根本不记得什么时候捡的东西。',
            effect: StoryEffect(
              addKnowledge: ['dh_alone_at_dawn'],
              setFlags: ['dh_walked_out'],
              spirit: -1,
              housePoints: 1,
            ),
            nextStepId: '',
          ),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch6_dawn',
        chapterId: 'dh_ch6',
        timeCostDays: 12,
        setup:
            '天亮了。'
            '战斗停下来的方式很奇怪——'
            '不是一声号令，'
            '而是忽然之间，'
            '对面的人开始往后退，然后跑，然后不见了。',
        ambient: [
          '大厅的屋顶塌了一半，阳光从破口照进来。',
          '有人坐在废墟上，手里还握着魔杖。',
          '你看见有人在找人，也有人在躲着被找到。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'start_counting',
            text: '开始清点：谁能站起来，谁需要人扶，谁不在了',
            consequence:
                '你清点了整整一个上午。'
                '三个名单：能走的、要扶的、和最后一份。'
                '第三份最短，'
                '但你写得最慢。',
            effect: StoryEffect(
              addItems: ['羊皮纸一包'],
              addKnowledge: ['dh_three_lists'],
              setFlags: ['dh_counted_survivors'],
              reputation: 3,
              spirit: -3,
            ),
          ),
          StoryChoiceDef(
            id: 'help_clear',
            text: '先去大厅帮忙抬石头、清出一条能走的路',
            consequence:
                '你抬了六个小时的石头，肩膀磨破了皮。'
                '清出来的第一条路，'
                '是通往医疗翼的。',
            effect: StoryEffect(
              setFlags: ['dh_cleared_the_hall'],
              reputation: 2,
              spirit: -1,
            ),
          ),
          StoryChoiceDef(
            id: 'sit_in_ruins',
            text: '找个地方坐下，什么都不做',
            consequence:
                '你在一块断掉的横梁上坐了很久。'
                '有人给你递了水，你接了，'
                '喝了一口才发现自己渴得厉害。',
            effect: StoryEffect(
              setFlags: ['dh_sat_in_ruins'],
              spirit: -2,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch6_after',
        chapterId: 'dh_ch6',
        timeCostDays: 9,
        setup:
            '战后第一天，所有人都在大厅里过夜。'
            '没有人回宿舍——'
            '因为大家不想一个人待着。'
            '有人弹起了走调的曲子，'
            '有人开始收拾地上的碎石头。',
        ambient: [
          '壁炉重新生起来了，火比哪一年都小，却没人去添柴。',
          '有猫头鹰飞进来，落在塌了一半的栏杆上。',
          '你把自己的校袍脱下来，盖在了旁边睡着的人身上。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'help_rebuild',
            text: '加入修房子的人，从自己住的那层楼开始',
            consequence:
                '你修了三天。'
                '把走廊的画挂回去、把门装回去、'
                '把墙上那个被熏黑的字迹擦掉。'
                '擦到一半你停下了——'
                '你想，也许该留着它。',
            effect: StoryEffect(
              setFlags: ['dh_helped_rebuild'],
              addKnowledge: ['dh_left_the_mark'],
              reputation: 3,
              spirit: 2,
            ),
          ),
          StoryChoiceDef(
            id: 'sit_with_names',
            text: '把那份名单拿出来，和留下的人一起一个个念完',
            consequence:
                '你们念了一整夜。'
                '念到某个名字的时候，'
                '总会有人说出一个和它有关的小事——'
                '他偷过谁的南瓜汁，她把书签借给过谁。'
                '念完天就亮了。',
            effect: StoryEffect(
              setFlags: ['dh_read_the_names'],
              reputation: 3,
              affection: 4,
              spirit: -1,
              targetNpcId: 'hermione',
            ),
          ),
          StoryChoiceDef(
            id: 'walk_out',
            text: '走到院子里，一个人看一会儿太阳',
            consequence:
                '你在院子里站了很久。'
                '太阳照在塌了一半的围墙上，'
                '很普通，很暖。'
                '你想：原来结束是这个样子的。',
            effect: StoryEffect(
              setFlags: ['dh_walked_out'],
              spirit: 1,
            ),
          ),
        ],
      ),
    ],
  ),

  // --------------------------------------------------------------
  // 第七章 · 七年之后（1998 年 5 月以后）
  // --------------------------------------------------------------
  StoryChapterDef(
    id: 'dh_ch7',
    bookId: 'dh',
    ordinal: 7,
    title: '七年之后',
    steps: [
      StoryStepDef(
        id: 'dh_ch7_leaving',
        chapterId: 'dh_ch7',
        timeCostDays: 11,
        setup:
            '离校那天没有仪式。'
            '没有期末考试，没有学院杯，'
            '甚至连一场像样的告别都没有。'
            '你只是把箱子合上，'
            '然后走下那段走了七年的楼梯。',
        ambient: [
          '楼梯还是那道楼梯，中间有一阶被炸塌了，得跨过去。',
          '墙上挂着的那排画像，少了几幅。',
          '你走到一半又回头看了一眼。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'last_walk',
            text: '把整个城堡再走一遍，从地窖走到塔楼',
            consequence:
                '你走了一遍。'
                '从地窖到塔楼，'
                '每一处都停一下。'
                '走到天文塔下面的时候你没上去，'
                '只是站了一会儿。',
            effect: StoryEffect(
              setFlags: ['dh_last_walk'],
              addKnowledge: ['dh_walked_it_all'],
              spirit: 1,
            ),
            nextStepId: 'dh_ch7_look_back',),
          StoryChoiceDef(
            id: 'say_goodbye',
            text: '找到那几个还在的人，认真地说一句再见',
            consequence:
                '你找到了他们。'
                '说了再见，'
                '也说了"下次什么时候见"。'
                '你们都知道这个"下次"可能会拖很久，'
                '但还是把日期定下来了。',
            effect: StoryEffect(
              setFlags: ['dh_said_goodbye'],
              reputation: 2,
              affection: 4,
              spirit: 2,
              targetNpcId: 'neville',
            ),
            nextStepId: 'dh_ch7_look_back',),
          StoryChoiceDef(
            id: 'leave_quick',
            text: '直接走，头也不回',
            consequence:
                '你直接走了。'
                '一直走到霍格莫德，'
                '才敢回头看一眼。'
                '城堡在远处，很完整，也很旧。',
            effect: StoryEffect(
              setFlags: ['dh_left_quickly'],
              spirit: -1,
            ),
            nextStepId: 'dh_ch7_look_back',),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch7_look_back',
        chapterId: 'dh_ch7',
        timeCostDays: 1,
        setup:
            '离开的时候要经过一段很长的走廊。墙上原来的画都没了，只剩下挂过画的痕迹。你停下来喘了口气，才继续往前。',
        ambient: [
          '有人在走廊尽头站着，没有跟上来。',
          '有一扇窗的玻璃碎了，风灌进来。',
          '走廊很长，脚步声一声接一声。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'walk_slow',
            text: '慢慢走，把这一路看仔细',
            consequence:
                '你走得很慢。每一扇门、每一段台阶，你都看了一眼。走到尽头的时候你回头了。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['dh_looked_back'], spirit: 3),
          ),
          StoryChoiceDef(
            id: 'walk_fast',
            text: '低着头快步走过去',
            consequence:
                '你没有看两边，一直盯着前面。走到门口的时候你才敢抬头。门外的天比里面亮得多。',
            nextStepId: '',
            effect: StoryEffect(setFlags: ['dh_walked_fast'], spirit: -1),
          ),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch7_empty_room',
        chapterId: 'dh_ch7',
        timeCostDays: 6,
        setup:
            '离校之前，你一个人上了七楼。'
            '那间教室的门开着，桌椅还按上次的样子摆着，'
            '黑板上留着一个写到一半的公式。'
            '没有人来擦。',
        ambient: [
          '窗台上那盆东西已经干死了。',
          '地上有几张踩过的纸，捡起来一看是去年的作业。',
          '走廊尽头有风，门一直没关严。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'clean_it_up',
            text: '把桌椅摆正，擦干净黑板',
            consequence:
                '你把桌椅一张张摆回原位，把黑板擦干净。'
                '干到一半你自己也觉得没意义——反正下学期没人补课了。'
                '但你干完了。'
                '走的时候你顺手把门带上，让它是关着的。',
            effect: StoryEffect(
              addKnowledge: ['dh_left_it_tidy'],
              setFlags: ['dh_cleaned_room'],
              spirit: 3,
              housePoints: 3,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'take_something',
            text: '拿一样东西走，当作记号',
            consequence:
                '你从讲台上拿走了那半根粉笔。'
                '很小，放进口袋里几乎感觉不到。'
                '后来很多年，你换过好几次住处，它都还在。',
            effect: StoryEffect(
              addKnowledge: ['dh_kept_a_token'],
              setFlags: ['dh_took_token'],
              spirit: 2,
              affection: 1,
            ),
            nextStepId: '',
          ),
          StoryChoiceDef(
            id: 'just_stand',
            text: '什么都不做，站一会儿就走',
            consequence:
                '你在门口站着，数了数有多少张桌子。'
                '然后你就走了。'
                '下楼梯的时候你没有回头——'
                '你告诉自己，记着就够了。',
            effect: StoryEffect(
              addKnowledge: ['dh_remembered_silently'],
              setFlags: ['dh_stood_then_left'],
              spirit: 1,
              housePoints: 1,
            ),
            nextStepId: '',
          ),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch7_choice',
        chapterId: 'dh_ch7',
        timeCostDays: 14,
        setup:
            '回到家，第一个问题不是"你还好吗"，'
            '而是"接下来打算做什么"。'
            '你可以回去补上被战争吃掉的那一年，'
            '也可以直接开始工作——'
            '这一年里，很多人已经没有"慢慢来"的余地了。',
        ambient: [
          '桌上放着三封信：学校、部里、还有一个陌生的徽章。',
          '母亲把最后一封信放在最上面，没有说话。',
          '你在一个星期里，第一次有时间坐下来想这件事。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'return_eighth',
            text: '回去补完第八年——我想把这一年好好读完',
            consequence:
                '你决定回去。'
                '不是为了成绩，'
                '是为了能在没有宵禁、没有点名的走廊上，'
                '好好走一年。',
            effect: StoryEffect(
              addItems: ['计划书'],
              addKnowledge: ['dh_eighth_year'],
              setFlags: ['dh_returned_eighth'],
              reputation: 2,
              spirit: 3,
            ),
          ),
          StoryChoiceDef(
            id: 'rebuild_job',
            text: '去做重建的工作——哪里缺人就去哪',
            consequence:
                '你去了最缺人的地方。'
                '第一年的工作内容是：'
                '把塌掉的房子扶起来，'
                '把走散的人找回来。'
                '你干得很好。',
            effect: StoryEffect(
              addItems: ['勇气勋章'],
              setFlags: ['dh_joined_rebuild'],
              reputation: 3,
              spirit: 2,
            ),
          ),
          StoryChoiceDef(
            id: 'rest_a_while',
            text: '什么都不做，先休息一个夏天',
            consequence:
                '你休息了一整个夏天。'
                '每天睡到自然醒，'
                '在院子里种了点东西。'
                '到秋天的时候，'
                '你终于能完整地想起这一年，而不只是碎片。',
            effect: StoryEffect(
              setFlags: ['dh_rested'],
              spirit: 3,
            ),
          ),
        ],
      ),
      StoryStepDef(
        id: 'dh_ch7_end',
        chapterId: 'dh_ch7',
        timeCostDays: 9,
        setup:
            '很多年后有人问你：'
            '"那七年里，你最记得哪一年。"'
            '你想了很久。'
            '不是最危险的那一年，'
            '也不是最风光的那一年。',
        ambient: [
          '窗外的雨停了，天边亮起来一条线。',
          '桌上的旧课本还在，页边写满了字——是你自己的字。',
          '你把杯子放下，准备回答。',
        ],
        choices: [
          StoryChoiceDef(
            id: 'answer_first',
            text: '"第一年——那年我什么都不知道，却什么都要学。"',
            consequence:
                '你说了第一年。'
                '那年你第一次拿到魔杖，'
                '第一次在餐厅里找不到自己的位子，'
                '第一次知道"朋友"这个词要怎么写。'
                '所有的后来，都是从那一年长出来的。',
            effect: StoryEffect(
              setFlags: ['dh_answer_first'],
              addKnowledge: ['dh_answer_first_year'],
              spirit: 3,
            ),
          ),
          StoryChoiceDef(
            id: 'answer_seventh',
            text: '"第七年——那年我终于成了能挡在别人前面的人。"',
            consequence:
                '你说了第七年。'
                '那一年你没打赢任何人，'
                '但你守住了该守的东西：'
                '一道门、一份名单、一句"我在"。'
                '你最记得那一年，'
                '因为那一年你终于配得上第一年那个自己。',
            effect: StoryEffect(
              addItems: ['勇气勋章'],
              setFlags: ['dh_answer_seventh'],
              addKnowledge: ['dh_answer_seventh_year'],
              reputation: 3,
              spirit: 3,
            ),
            requireFlag: 'dh_held_the_door',
          ),
          StoryChoiceDef(
            id: 'answer_all',
            text: '"每一年——它们是一整件事，不能拆开算。"',
            consequence:
                '你说：不能拆开算。'
                '七年是一整件事——'
                '有人的部分，有书的部分，'
                '有被吓到的部分，也有挡住门的部分。'
                '问的人笑了，说这个答案很狡猾。'
                '你说：因为它是对的。',
            effect: StoryEffect(
              setFlags: ['dh_answer_all'],
              addKnowledge: ['dh_answer_all_years'],
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

const List<StoryEndingRule> _dhEndings = [
  StoryEndingRule(
    id: 'dh_ending_the_last_door',
    title: '最后那道门',
    body:
        '那一夜你守住的不是一道门，'
        '是"孩子们可以不用参战"这件事。'
        '你没有打赢谁，你只是没让开。'
        '很多年后那道门还在原处，'
        '门框上有一道很浅的痕迹——'
        '那是你的魔杖在石头上蹭出来的。',
    requireFlags: ['dh_held_the_door', 'dh_stayed_to_fight'],
  ),
  StoryEndingRule(
    id: 'dh_ending_the_underground',
    title: '地下的人',
    body:
        '你排过班、藏过人、抄过名单，'
        '也在最冷的那几个月里，'
        '每天夜里十二点把走廊尽头那扇窗打开一条缝。'
        '没人给你发过勋章，'
        '但那扇窗后面的人，'
        '每一个都还记得那条缝里进来的风。',
    requireAnyFlags: [
      'dh_joined_underground',
      'dh_opened_door',
      'dh_held_passage',
      'dh_led_evacuation',
    ],
    minReputation: 8,
  ),
  StoryEndingRule(
    id: 'dh_ending_i_am_here',
    title: '「我在」',
    body:
        '你这一年的全部贡献，'
        '说到底只是两个字：在场。'
        '你在名单旁边站过一步，'
        '在藏身处的门外坐过一夜，'
        '在被念到名字的时候出过声。'
        '你没能改变局势，'
        '但你改变了几个人对"有没有人站在我这边"这个问题的答案。',
    requireAnyFlags: [
      'dh_stood_beside',
      'dh_guarded_children',
      'dh_spread_signal',
      'dh_hung_ribbon',
      'dh_sat_with_juniors',
    ],
  ),
  StoryEndingRule(
    id: 'dh_ending_walked_past',
    title: '从那面墙前走过去的人',
    body:
        '你绕开过八楼，'
        '关过一次灯，'
        '也在点名时一直盯着自己的鞋尖。'
        '你活下来了——这从来不是一件该被嘲笑的事。'
        '只是后来每次有人讲起那一年，'
        '你都只能安静地听，'
        '然后在心里补一句：'
        '"如果再来一次，我会开门。"',
  ),
];

const StoryBookDef deathlyHallows = StoryBookDef(
  id: 'dh',
  title: '死亡圣器',
  chapters: _dhChapters,
  endings: _dhEndings,
  startYear: 1997,
  startMonth: 7,
  startDay: 25,
);
