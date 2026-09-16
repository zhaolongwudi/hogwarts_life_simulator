/// 剧情选项条件门槛的**真实路径**测试。
///
/// 【为什么需要这一层】`StoryChoiceDef.isVisible` 有完整的单测
/// （`story_data_test.dart`：AND 语义、hideIfFlag 优先级、区间声望…），
/// 那测的是**判定函数**。但判定函数对不对，和"内容层有没有真的挂上条件"
/// 是两件事——后者才是玩家能不能感知到的部分。
///
/// 实测发现的问题：七部内容层产出 500+ 个 flag，消费率只有约 10%，
/// 而且带条件的选项**全部集中在每部书的最后一章**。也就是说玩家在
/// ch1 做的选择、设的 flag，要到全书末章才第一次起作用——中间十个月
/// 完全没有任何回馈。
///
/// 本文件从**真实剧情步**出发断言三件事：
///   1. 拿过更早章节的 flag → 该选项出现（门槛真的在生效）；
///   2. 没拿过 → 该选项不出现（门槛不是摆设）；
///   3. 无论哪种，该步都至少还有一条出路（不会被过滤成空）。
///
/// 【为什么不用 isVisible 直接测】那样测的还是判定函数。这里走
/// `availableStoryChoices(step, flags, knowledge:)`——即引擎实际调用的
/// 那个入口，覆盖"从 true 表取步 + 从 progress 取 flag"这一整段。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/story_data.dart';
import 'package:hogwarts_life_simulator/data/story_data_dh.dart';
import 'package:hogwarts_life_simulator/data/story_data_gof.dart';
import 'package:hogwarts_life_simulator/data/story_data_hbp.dart';
import 'package:hogwarts_life_simulator/data/story_data_ootp.dart';
import 'package:hogwarts_life_simulator/data/story_data_poa.dart';
import 'package:hogwarts_life_simulator/models/story_progress.dart';

/// 从全局书表里取一步（书表由 registerAllStoryBooks 注入）。
StoryStepDef step(String stepId) {
  final s = findStoryStepAnywhere('ps', stepId) ??
      // ps 的书表只含 ps/cos；其余书挨个找
      _findAny(stepId);
  if (s == null) throw StateError('找不到剧情步: $stepId');
  return s;
}

StoryStepDef? _findAny(String stepId) {
  for (final book in kStoryBooks.values) {
    for (final ch in book.chapters) {
      for (final s in ch.steps) {
        if (s.id == stepId) return s;
      }
    }
  }
  return null;
}

/// 该步在某组 flag/knowledge 下可见的选项 id 集合。
Set<String> visibleIds(
  String stepId, {
  Set<String> flags = const {},
  Set<String> knowledge = const {},
  int reputation = 0,
}) {
  final s = step(stepId);
  return availableStoryChoices(
    s,
    flags,
    knowledge: knowledge,
    reputation: reputation,
  ).map((c) => c.id).toSet();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAllStoryBooks);

  group('A · 条件门槛真的在生效（前面积累 → 后面解锁）', () {
    test('POA：ch1 读过报道后，ch6 才问得出"当时在场的人"', () {
      const sid = 'poa_ch6_incident';
      const cid = 'ask_victim_side';

      // 什么都没做过的新玩家：看不到这条
      expect(
        visibleIds(sid).contains(cid),
        isFalse,
        reason: '没读过任何报道的人，不该凭空知道去问什么',
      );

      // 在 ch1 把报道读过之后：出现
      expect(
        visibleIds(sid, flags: {'poa_read_news'}).contains(cid),
        isTrue,
        reason: 'ch1 读过的报道，必须在 ch6 兑现成一条专属出路——'
            '这就是"前面积累解锁后面出路"的验收点',
      );
    });

    test('POA：ch3 记过笔记 + ch1 读过报道，ch6 才递得出材料', () {
      const sid = 'poa_ch6_hearing';
      const cid = 'pass_evidence';

      // 两个条件缺一不可（requireAllFlags 的 AND 语义）
      expect(visibleIds(sid).contains(cid), isFalse);
      expect(
        visibleIds(sid, flags: {'poa_studied_reports'}).contains(cid),
        isFalse,
        reason: '只有报道没有笔记，手上还是没有可以递的东西',
      );
      expect(
        visibleIds(sid, flags: {'poa_took_notes'}).contains(cid),
        isFalse,
        reason: '只有笔记没读过报道，同样凑不齐',
      );
      expect(
        visibleIds(
          sid,
          flags: {'poa_studied_reports', 'poa_took_notes'},
        ).contains(cid),
        isTrue,
        reason: '两个条件都满足才该出现——AND 语义必须在真实内容上成立',
      );
    });

    test('POA：照顾过生物的人，ch6 才会想到再去小屋放点东西', () {
      const sid = 'poa_ch6_after_verdict';
      const cid = 'leave_gift';
      expect(visibleIds(sid).contains(cid), isFalse);
      expect(
        visibleIds(sid, flags: {'poa_care_creatures'}).contains(cid),
        isTrue,
      );
    });

    test('HBP：ch2 打听过的人，ch5 才会顺着线索往下查', () {
      const sid = 'hbp_ch5_rumor';
      const cid = 'dig_rumor';
      expect(visibleIds(sid).contains(cid), isFalse);
      expect(
        visibleIds(sid, flags: {'hbp_asked_around'}).contains(cid),
        isTrue,
      );
      // requireAnyFlags 的 OR 语义：另一条路径同样解锁
      expect(
        visibleIds(sid, flags: {'hbp_counted_names'}).contains(cid),
        isTrue,
        reason: '用另一种方式打听到消息也该解锁，不能只认一条路径',
      );
    });

    test('GOF：ch1 读过赛史的人，第一项任务时才会认真记打法', () {
      const sid = 'gof_ch2_first_task';
      const cid = 'take_notes';
      expect(visibleIds(sid).contains(cid), isFalse);
      expect(
        visibleIds(sid, flags: {'gof_read_history'}).contains(cid),
        isTrue,
      );
    });
  });

  group('B · hideIfFlag：做过就不该再出现第二次', () {
    test('POA：已经递过材料的人，不该再"第一次"递一遍', () {
      const sid = 'poa_ch6_hearing';
      const cid = 'pass_evidence';
      final both = {
        'poa_studied_reports',
        'poa_took_notes',
      };

      // 满足门槛时可见
      expect(visibleIds(sid, flags: both).contains(cid), isTrue);
      // 但已经递过一次之后，即使门槛仍满足也必须消失
      expect(
        visibleIds(sid, flags: {...both, 'poa_evidence_handed'}).contains(cid),
        isFalse,
        reason: '已经做过的事不该还能再做一遍——'
            '这是 hideIfFlag 存在的唯一理由',
      );
    });

    test('POA：已经签过联名的人，不必再"第一次"签名', () {
      const sid = 'poa_ch6_waiting';
      const cid = 'sign_paper';
      expect(visibleIds(sid).contains(cid), isTrue);
      expect(
        visibleIds(sid, flags: {'poa_signed_petition'}).contains(cid),
        isFalse,
      );
    });
  });

  group('C · maxReputation：低声誉专属的低调出路', () {
    test('POA：还没出名的人，才谈得上"一个人躲进图书馆"', () {
      const sid = 'poa_ch7_exams';
      const cid = 'solo_cram';
      expect(
        visibleIds(sid, reputation: 0).contains(cid),
        isTrue,
        reason: '声望为 0 的新玩家应该有这条低调出路',
      );
      expect(
        visibleIds(sid, reputation: 50).contains(cid),
        isFalse,
        reason: '声望已经很高的人，不该还能选"一个人躲起来"——'
            '那是还没被注意到的人才有的选项',
      );
    });
  });

  group('D · 结构性护栏', () {
    test('每个带条件的步都至少留一条无条件出路', () {
      // 【为什么必须有这条】三条出路全挂条件时，新玩家一条都看不到，
      // `availableStoryChoices` 会走到"过滤后为空 → 退回全部"的兜底分支，
      // 门槛静默失效。这种失效没有任何报错，只能靠断言挡住。
      const guarded = <String, List<String>>{
        'poa_ch6_incident': ['poa_ch6_incident'],
        'poa_ch6_hearing': ['poa_ch6_hearing'],
        'poa_ch6_after_verdict': ['poa_ch6_after_verdict'],
        'poa_ch6_waiting': ['poa_ch6_waiting'],
        'poa_ch7_rumors': ['poa_ch7_rumors'],
        'poa_ch7_exams': ['poa_ch7_exams'],
        'poa_ch7_patrol_night': ['poa_ch7_patrol_night'],
        'gof_ch2_first_task': ['gof_ch2_first_task'],
        'gof_ch3_ball': ['gof_ch3_ball'],
        'gof_ch4_clue': ['gof_ch4_clue'],
        'gof_ch5_maze_rise': ['gof_ch5_maze_rise'],
        'hbp_ch5_rumor': ['hbp_ch5_rumor'],
        'hbp_ch5_think': ['hbp_ch5_think'],
        'hbp_ch6_corridor_night': ['hbp_ch6_corridor_night'],
        'hbp_ch6_wait': ['hbp_ch6_wait'],
      };

      for (final sid in guarded.keys) {
        final s = step(sid);
        final total = s.choices.length;

        // 该步里"在空处境下本来就可见"的出路有几条。
        //
        // 【为什么要按字段类型分别判断】空处境（无 flag / 无情报 / 声望 0）
        // 下，各类条件的效果并不一样：
        //   - requireFlag / requireAllFlags / requireAnyFlags /
        //     requireKnowledge / minReputation → 空处境下**不满足**，挡掉
        //   - hideIfFlag / maxReputation → 空处境下**满足**，放行
        // 早期版本把"有任何一个条件字段"一律当成会被挡掉，
        // 于是把只挂了 hideIfFlag 的选项误判成不可见。
        bool visibleWhenBlank(StoryChoiceDef c) {
          if (c.requireFlag != null) return false;
          if (c.requireAllFlags.isNotEmpty) return false;
          if (c.requireAnyFlags.isNotEmpty) return false;
          if (c.requireKnowledge.isNotEmpty) return false;
          if (c.minReputation != null && 0 < c.minReputation!) return false;
          // hideIfFlag：空处境下没有那个 flag，所以不会隐藏
          // maxReputation：0 < max 时满足，可见
          return true;
        }

        // 该步是否挂了任何条件（用来断言门槛确实存在）
        bool hasAnyCondition(StoryChoiceDef c) =>
            c.requireFlag != null ||
            c.requireAllFlags.isNotEmpty ||
            c.requireAnyFlags.isNotEmpty ||
            c.requireKnowledge.isNotEmpty ||
            c.hideIfFlag != null ||
            c.minReputation != null ||
            c.maxReputation != null;

        final blankVisible =
            s.choices.where(visibleWhenBlank).length;
        final conditioned =
            s.choices.where(hasAnyCondition).length;

        expect(
          blankVisible,
          greaterThan(0),
          reason: '$sid 在空处境下一条出路都不可见——'
              '新玩家会撞上空选择界面',
        );

        // 用最严苛的处境实际算一遍，必须与静态推断一致。
        final shown = visibleIds(sid).length;
        expect(
          shown,
          blankVisible,
          reason: '$sid 在空处境下可见 $shown 条，静态推断应为 $blankVisible 条'
              '（共 $total 条）',
        );

        // 该步必须真的挂了条件，否则这条护栏没意义
        expect(
          conditioned,
          greaterThan(0),
          reason: '$sid 一条条件选项都没有，门槛没起作用',
        );
      }
    });

    test('flag 消费率：条件门槛覆盖到中段章节，不只在末章', () {
      // 【为什么钉这条】内容一度是"所有带条件的选项都在每部书最后一章"，
      // 意味着玩家前中期做的选择要等一整年才第一次生效。
      // 这里按章统计，要求中段章节也必须有条件选项。
      final perChapter = <String, int>{};
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          var n = 0;
          for (final s in ch.steps) {
            for (final c in s.choices) {
              if (c.requireFlag != null ||
                  c.requireAllFlags.isNotEmpty ||
                  c.requireAnyFlags.isNotEmpty ||
                  c.requireKnowledge.isNotEmpty ||
                  c.hideIfFlag != null ||
                  c.minReputation != null ||
                  c.maxReputation != null) {
                n++;
              }
            }
          }
          if (n > 0) perChapter[ch.id] = n;
        }
      }

      // POA / GOF / HBP 的中段章必须出现在名单里
      for (final ch in [
        'poa_ch6',
        'poa_ch7',
        'gof_ch2',
        'gof_ch3',
        'gof_ch4',
        'gof_ch5',
        'hbp_ch5',
        'hbp_ch6',
      ]) {
        expect(
          perChapter.containsKey(ch),
          isTrue,
          reason: '$ch 一条条件选项都没有——'
              '中段章节没有门槛，玩家的积累在整年中间得不到任何回响（'
              '当前有条件选项的章：${perChapter.keys.toList()..sort()}）',
        );
      }

      // 总量护栏
      final total = perChapter.values.fold<int>(0, (a, b) => a + b);
      expect(total, greaterThanOrEqualTo(30),
          reason: '带条件的选项总数掉到 $total，长期养成回馈基本失效');
    });
  });
}
