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
import 'package:hogwarts_life_simulator/data/canon_events.dart';
import 'package:hogwarts_life_simulator/data/cg_data.dart';
import 'package:hogwarts_life_simulator/data/story_data.dart';
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
///
/// 【陷阱：`availableStoryChoices` 有空处境兜底】
/// 过滤后若**一条都不剩**，它会退回返回**全部**选项（防止玩家撞上空界面）。
/// 所以"某个选项不在返回集合里"**不能**证明它被门槛挡住了——
/// 也可能是因为该步所有出路都被挡掉、于是兜底生效、它又回来了。
/// 需要断言"被门槛挡住"时请用 [isVisibleNow]，别用本函数。
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

/// 某个选项在某组 flag/knowledge 下**是否真的通过门槛**。
///
/// 与 [visibleIds] 的区别：这里直接问 `StoryChoiceDef.isVisible`，
/// 不经过 `availableStoryChoices` 的"空则全给"兜底，所以
/// **可以**用来断言"被门槛挡住了"。
bool isVisibleNow(
  String stepId,
  String choiceId, {
  Set<String> flags = const {},
  Set<String> knowledge = const {},
  int reputation = 0,
}) {
  final c = step(stepId).choices.firstWhere(
    (x) => x.id == choiceId,
    orElse: () => throw StateError('$stepId 里找不到 $choiceId'),
  );
  return c.isVisible(
    flags: flags,
    knowledge: knowledge,
    reputation: reputation,
  );
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

      // 【为什么用 isVisibleNow 而不是 visibleIds】这条出路的两半
      // 都是条件，空处境下它被挡住；但该步其余出路也大多带条件，
      // 一旦全被挡掉，`availableStoryChoices` 会走"空则全给"兜底，
      // 于是 visibleIds 里又出现它——那会掩盖门槛的真实状态。
      expect(isVisibleNow(sid, cid), isFalse);

      // 门槛＝flag 半边 AND 情报半边。"当年打听过"且"手里凑齐两条情报"
      // 才放行——两半来自同一批更早的章。
      //
      // 【为什么情报要给两条】`requireKnowledge` 是**每一项都要满足**的
      // AND 语义（`isVisible` 里是 `for (k in requireKnowledge) if
      // (!knowledge.contains(k)) return false;`）。这条出路的
      // requireKnowledge 实装为 `[hbp_rumor_timeline, hbp_watched_changes]`，
      // 只给一条**不该**放行——上一条断言正是在验这一点。
      expect(
        isVisibleNow(
          sid,
          cid,
          flags: {'hbp_asked_around'},
          knowledge: {'hbp_rumor_timeline', 'hbp_watched_changes'},
        ),
        isTrue,
      );
      // 只给一半不算数：这正是批次 7-D 修掉的
      // "门槛看似在跑、其实永远不命中"（情报名被误写进 requireAnyFlags）
      expect(
        isVisibleNow(
          sid,
          cid,
          flags: {'hbp_asked_around'},
          knowledge: {'hbp_rumor_timeline'},
        ),
        isFalse,
        reason: 'requireKnowledge 是 AND：只给一半情报，不该解锁这条出路',
      );

      // requireAnyFlags 的 OR 语义：另两条打听路径同样解锁
      for (final f in ['hbp_counted_names', 'hbp_watch_rumors']) {
        expect(
          isVisibleNow(
            sid,
            cid,
            flags: {f},
            knowledge: {'hbp_rumor_timeline', 'hbp_watched_changes'},
          ),
          isTrue,
          reason: 'requireAnyFlags 是 OR：$f 这条打听路径也该解锁',
        );
      }
    });

    test('GOF：ch1 读过赛史的人，第一项任务时才会认真记打法', () {
      const sid = 'gof_ch2_first_task';
      const cid = 'take_notes';
      expect(isVisibleNow(sid, cid), isFalse);
      // 【门槛由 flag + 情报两半组成，必须都给】`requireAnyFlags` 与
      // `requireKnowledge` 之间是 **AND**（各自内部才是 OR）。
      // 这条出路要求"读过赛史"（flag）**且**凑齐两条情报
      // （`[gof_tournament_history, gof_focused_study]`）——两半来自
      // ch1 的两次不同选择，所以这条出路奖励的是"读赛史 + 也顾学业"的人。
      expect(
        isVisibleNow(
          sid,
          cid,
          flags: {'gof_read_history'},
          knowledge: {'gof_tournament_history', 'gof_focused_study'},
        ),
        isTrue,
        reason: '读过赛史的人应当解锁"认真记打法"这条出路',
      );
      // requireKnowledge 是 AND：只给一条情报不放行
      expect(
        isVisibleNow(
          sid,
          cid,
          flags: {'gof_read_history'},
          knowledge: {'gof_tournament_history'},
        ),
        isFalse,
        reason: '情报只凑齐一半，不该解锁——requireKnowledge 内部是 AND',
      );
      // 只给 flag、不给情报同样不放行：这正是批次 7-D 修掉的
      // "门槛看似在跑其实永远不命中"
      expect(
        isVisibleNow(sid, cid, flags: {'gof_read_history'}),
        isFalse,
        reason: '只知道赛史、没读过报道，凑不齐这条出路',
      );
      // requireAnyFlags 的 OR：另一条"守规矩"路径同样解锁
      expect(
        isVisibleNow(
          sid,
          cid,
          flags: {'gof_knows_rules'},
          knowledge: {'gof_tournament_history', 'gof_focused_study'},
        ),
        isTrue,
        reason: 'requireAnyFlags 是 OR：懂规矩的人也该能认真记打法',
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

      // 七部书的中段章都必须出现在名单里。
      // 只钉 POA/GOF/HBP 会掩盖其余四部的空白——PS 与 CoS 的
      // flag 消费率一度只有 4% / 5%，就是因为没人按书检查。
      for (final ch in [
        'ps_ch8',
        'ps_ch9',
        'cos_ch9',
        'cos_ch10',
        'cos_ch11',
        'poa_ch6',
        'poa_ch7',
        'gof_ch2',
        'gof_ch3',
        'gof_ch4',
        'gof_ch5',
        'ootp_ch5',
        'ootp_ch6',
        'ootp_ch7',
        'hbp_ch5',
        'hbp_ch6',
        'dh_ch5',
        'dh_ch6',
        'dh_ch7',
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
      // 实装值 93（批次 7-A 补 17 条条件出路之前是 76）。下限留出余量，
      // 但不允许明显倒退。
      final total = perChapter.values.fold<int>(0, (a, b) => a + b);
      expect(total, greaterThanOrEqualTo(88),
          reason: '带条件的选项总数掉到 $total，长期养成回馈基本失效');
    });

    test('flag 消费率：七部书各自都要有足够的 flag 被读回', () {
      // 【为什么按书分别断言】总量达标会掩盖单部书的空白。
      // 接线前 PS 产出 116 个 flag 只读 5 个（4%），但当时
      // "总量护栏"照样通过——因为它只数绝对条数，不看比例。
      // 这里对每部书单独算消费率。
      // 下限按实装值留一点余量。注意这个口径只数 flag（不含
      // requireKnowledge 那类知识门槛），所以 POA 的实测值 21 与
      // 上面的 25 会有小差。
      // 批次 7-A 后实测：ps 29 / cos 30 / poa 20 / gof 9 /
      // ootp 34 / hbp 16 / dh 45。
      const floors = {
        'ps': 27,
        'cos': 28,
        'poa': 20,
        'gof': 9,
        'ootp': 28,
        'hbp': 15,
        'dh': 40,
      };

      String bookOf(String stepId) => stepId.split('_').first;

      final produced = <String, Set<String>>{};
      final consumed = <String, Set<String>>{};
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            final b = bookOf(s.id);
            for (final c in s.choices) {
              produced.putIfAbsent(b, () => <String>{}).addAll(c.effect.setFlags);
              consumed.putIfAbsent(b, () => <String>{}).addAll({
                if (c.requireFlag != null) c.requireFlag!,
                ...c.requireAllFlags,
                ...c.requireAnyFlags,
                if (c.hideIfFlag != null) c.hideIfFlag!,
              });
            }
          }
        }
      }

      for (final entry in floors.entries) {
        final p = produced[entry.key] ?? const <String>{};
        final u = consumed[entry.key] ?? const <String>{};
        final hit = p.intersection(u).length;
        expect(
          hit,
          greaterThanOrEqualTo(entry.value),
          reason: '《${entry.key}》产出 ${p.length} 个 flag，'
              '只有 $hit 个被后续节点读回（下限 ${entry.value}）——'
              '前面攒的东西后面没人问，长期养成的意义就没了',
        );
      }
    });

    test('纯 2 选 1 的步不能超过总步数的一半', () {
      // 【为什么钉这条】"长期可玩"不只是步数够多，还要求每一步**真的有得选**。
      // 两步两分支的步玩起来是"二选一的是非题"，点得再多也没有决策感。
      //
      // 批次 7-A 之前实测 168/335 步（50%）是纯 2 选 1，PS 与 CoS 最严重
      // （ps_ch1 9/9、cos_ch10 6/6…），而那正是长局开局——玩家第一小时
      // 看到的内容最单调。补条件出路之后降到 152/335（45%）。
      //
      // 注意：这条**不是**要求每步都有 3 个选项（那既不现实也不必要）。
      // 它只是一条回退线：谁再把整章写成是非题就撞墙。
      var twoChoice = 0;
      var total = 0;
      final worst = <String, int>{};

      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          var tc = 0;
          for (final s in ch.steps) {
            total++;
            if (s.choices.length == 2) {
              tc++;
              twoChoice++;
            }
          }
          if (tc > 0) worst[ch.id] = tc;
        }
      }

      expect(
        twoChoice * 2,
        lessThanOrEqualTo(total),
        reason: '纯 2 选 1 的步有 $twoChoice/$total，超过一半——'
            '玩家会一路点"是非题"，长局的选择密度被稀释',
      );

      // 单章级护栏：不接受"整章 2 选 1"。批次 7-A 前 PS 有 6 个章、
      // CoS 有 9 个章整章都是是非题。
      final allMonotone = worst.entries
          .where((e) {
            for (final book in kStoryBooks.values) {
              for (final ch in book.chapters) {
                if (ch.id == e.key) return ch.steps.length == e.value;
              }
            }
            return false;
          })
          .map((e) => e.key)
          .toList()
        ..sort();

      expect(
        allMonotone.length,
        lessThanOrEqualTo(12),
        reason: '整章都是 2 选 1 的章有 ${allMonotone.length} 个：'
            '$allMonotone——这些章玩家点十几次都没遇到一个三选项',
      );
    });

    test('新增的条件出路都真的走得通（门槛可达 + 空处境不挡路）', () {
      // 【为什么钉这条】批次 7-A 起往内容里补了一批**条件**出路。
      // 条件出路有两个容易写坏的地方，两种都不会编译报错：
      //   ① 引用的 flag 在整条时间线里**根本没有生产者**——这条出路永远是死的；
      //   ② 引用由**更晚**的步产生的 flag——理论可达，实战走到这一步时
      //      玩家还没拿到，等于死代码。
      //
      // 【跨部继承是合法的，别误判】`StoryProgress.beginBook` 明确规定
      // flags / knowledge **跨部保留**（"七部一场长局"的根基）。
      // 所以"由《火焰杯》的角色写在《混血王子》里读到"是**正确**写法，
      // 不是 bug。判据按**全局部序**算：
      //   · 生产者在**更早的书**里           → 可达
      //   · 生产者在**同一本书更早的步**里   → 可达
      //   · 生产者在同一本书更晚的步 / 本书无生产者但更晚的书里有 → 不可达
      const bookOrder = ['ps', 'cos', 'poa', 'gof', 'ootp', 'hbp', 'dh'];
      final bookRank = {
        for (var i = 0; i < bookOrder.length; i++) bookOrder[i]: i,
      };

      // 全局 flag / knowledge 生产表：(书序, 步序) —— 取"最早出现"的那次。
      final flagWriter = <String, (int, int)>{};
      final knowWriter = <String, (int, int)>{};
      for (final b in bookOrder) {
        final book = kStoryBooks[b];
        if (book == null) continue;
        final br = bookRank[b]!;
        var i = 0;
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            for (final c in s.choices) {
              for (final f in c.effect.setFlags) {
                flagWriter.putIfAbsent(f, () => (br, i));
              }
              for (final k in c.effect.addKnowledge) {
                knowWriter.putIfAbsent(k, () => (br, i));
              }
            }
            i++;
          }
        }
      }

      // 该步的全局坐标
      bool defined(String id) => kStoryBooks[id] != null;

      final dead = <String>[];
      final late = <String>[];

      for (final b in bookOrder) {
        final book = kStoryBooks[b];
        if (book == null) continue;
        final br = bookRank[b]!;
        var i = 0;
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            for (final c in s.choices) {
              void check(String key, (int, int)? w, String kind) {
                if (w == null) {
                  dead.add('$b/${s.id}/${c.id} → $key（整条时间线无生产者）');
                  return;
                }
                final (wr, wi) = w;
                // 更早的书 → 可达；同书必须严格更早
                if (wr == br && wi >= i) {
                  late.add('$b/${s.id}/${c.id} → $key（同书更晚的步 #$wi，'
                      '本步 #$i）');
                } else if (wr > br) {
                  late.add('$b/${s.id}/${c.id} → $key（更晚的书）');
                }
              }

              if (c.requireFlag != null) {
                check(c.requireFlag!, flagWriter[c.requireFlag!], 'flag');
              }
              for (final f in [...c.requireAllFlags, ...c.requireAnyFlags]) {
                check(f, flagWriter[f], 'flag');
              }
              for (final k in c.requireKnowledge) {
                check(k, knowWriter[k], 'knowledge');
              }
            }
            i++;
          }
        }
      }

      expect(defined('ps'), isTrue, reason: '书表应当已注册');
      expect(dead, isEmpty, reason: '条件出路引用了没人写的东西，永远是死的：\n${dead.join('\n')}');
      expect(late, isEmpty, reason: '条件出路依赖更晚才出现的东西，实战走不到：\n${late.join('\n')}');
    });

    test('情报消费率不能归零（当时多留的心眼要在后面兑现）', () {
      // 全库 knowledge 产出约 90 条。批次 7-A/B 之前只有 1 条被读——
      // 等于"知道了一件事"这个机制基本没接线。7-B 接回 5 条，
      // 这里的下限就钉在实装值上，防止再掉回去。
      final produced = <String>{};
      final consumed = <String>{};
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            for (final c in s.choices) {
              produced.addAll(c.effect.addKnowledge);
              consumed.addAll(c.requireKnowledge);
            }
          }
        }
      }
      final hit = produced.intersection(consumed);
      expect(
        hit.length,
        greaterThanOrEqualTo(6),
        reason: '全库产出 ${produced.length} 条情报，只有 ${hit.length} 条被读回——'
            '"玩家知道了什么"这件事在后续剧情里得不到任何体现',
      );
    });

    test('批次 7-A 补的条件出路逐条可验证', () {
      // 抽几个代表逐条验收：门槛满足 → 出现；空处境 → 不出现；
      // 且该步在空处境下**仍有**至少两条出路（不会被过滤成空界面）。
      // 【为什么是 (步, 出路) 的列表而不是 Map】同一个步可能被补了不止
      // 一条出路（`cos_ch2_schedule` 补了 check_signature 与 mark_overlap），
      // Map 的键会撞掉其中一条。
      const cases = <(String, String)>[
        ('ps_ch1_window', 'tell_neighbor_truth'),
        ('ps_ch1_tell', 'show_letter_as_proof'),
        ('ps_ch1_list', 'ask_budget'),
        ('ps_ch1_study', 'show_letters_to_family'),
        ('ps_ch1_visit', 'ask_about_war'),
        ('ps_ch1_reply', 'write_alone'),
        ('ps_ch1_postbox', 'tell_family_before'),
        ('ps_ch1_last_night', 'reread_letter_once'),
        ('ps_ch2_arrival', 'a_owl_office'),
        ('cos_ch2_seat', 'greet_by_name'),
        ('cos_ch2_schedule', 'check_signature'),
        ('cos_ch2_schedule', 'mark_overlap'),
        ('cos_ch4_crowd', 'join_lockhart_fans'),
        ('cos_ch4_morning_after', 'write_down_facts'),
        ('cos_ch6_watch_club', 'copy_stance'),
        ('cos_ch6_after_club', 'recheck_corridors'),
        ('cos_ch6_wind', 'listen_to_wind'),
      ];

      for (final (sid, cid) in cases) {
        final s = step(sid);
        final c = s.choices.firstWhere(
          (x) => x.id == cid,
          orElse: () => throw StateError('$sid 里找不到 $cid'),
        );
        final gate = c.requireFlag;
        expect(gate, isNotNull, reason: '$sid/$cid 应当带门槛');

        // 空处境：这条出路必须**不**出现（否则它就不是"条件出路"）
        expect(
          visibleIds(sid).contains(cid),
          isFalse,
          reason: '$sid/$cid 在空处境下就可见，门槛没起作用',
        );

        // 满足门槛：必须出现
        expect(
          visibleIds(sid, flags: {gate!}).contains(cid),
          isTrue,
          reason: '$sid/$cid 满足 requireFlag=$gate 后仍不可见',
        );

        // 空处境下必须还有别的出路，否则玩家会撞上空选择界面
        expect(
          visibleIds(sid).length,
          greaterThanOrEqualTo(2),
          reason: '$sid 空处境下只剩 ${visibleIds(sid).length} 条出路',
        );
      }
    });
  });

  // ================================================================
  // E · 原著节点接线：剧情步 → canon 节点 → 长期记忆/悬念/图鉴
  // ================================================================
  //
  // 【这一组在防什么】项目里长期记忆的沉淀**不是**走 `StoryEffect`
  // 的 `addWorldEvents` / `openLoops` / `unlockCgs` 那几个字段，而是走
  // 「剧情步声明 `canonRefId` → 引擎按该 id 找到原著节点 →
  // 把节点自己声明的 worldEvent / openLoop / closeLoops / unlockCg
  // 广播出去」（见 `mixin_narrative.dart` 的 `_markCanonForStep` →
  // `_sinkCanonNodeToMemory`）。
  //
  // 也就是说 `canonRefId` 是这条链路的**唯一权威声明**。它一旦写错
  // （拼错 id）或者漏写，后果是：这一步在剧情上明明讲的是原著大事，
  // 但长期记忆、悬念、图鉴**一个都不会收到信号**——而且**没有任何报错**，
  // 因为 `canonEventById` 查不到就 `return`，静默跳过。
  //
  // 这跟批次 7-D 修的"死门槛"是同一类失效：**接线断了但不报错**。
  // 只能靠断言守住。
  group('E · 原著节点接线完整（剧情步 → canon → 记忆/悬念/图鉴）', () {
    test('每个 canonRefId 都能在原著节点表里查到', () {
      final bad = <String>[];
      var withRef = 0;
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            final r = s.canonRefId;
            if (r == null) continue;
            withRef++;
            if (canonEventById(r) == null) bad.add('${s.id} → $r');
          }
        }
      }

      expect(withRef, greaterThan(0),
          reason: '一条 canonRefId 都没有，长期记忆链路整个是断的');
      expect(
        bad,
        isEmpty,
        reason: '以下剧情步引用了不存在的原著节点，'
            '这一步的世界大事/悬念/图鉴都会静默丢失：$bad',
      );
    });

    test('原著节点表里没有节点被漏讲（覆盖率不倒退）', () {
      // 【为什么要求 100%】`canonRefId` 是节点被讲述的唯一声明。
      // 一个节点没被任何剧情步引用，意味着它的 worldEvent / 悬念
      // 永远不会被广播——玩家跑完七部也见不到那条原著大事。
      // 【为什么这条不是"过度约束"】加节点时顺手在剧情步上补一个
      // `canonRefId` 是内容创作的常规动作；真漏了，这条断言会在
      // 提交前就拦下来，比玩家玩了三百回合才发现要好。
      final covered = <String>{};
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            final r = s.canonRefId;
            if (r != null) covered.add(r);
          }
        }
      }
      final uncovered =
          canonEvents.map((e) => e.id).toSet().difference(covered);
      expect(
        uncovered,
        isEmpty,
        reason: '以下原著节点没有任何剧情步讲述，其长期记忆/悬念/图鉴'
            '永远不会触发：${uncovered.toList()..sort()}',
      );
    });

    test('悬念成对：开过的都要关（跨 canon 表全局判定）', () {
      // 【为什么在内容侧再测一遍】`canon_offline_integration_test.dart`
      // 已有一条同语义断言。这里重测的理由是：那条测的是"canon 表自身
      // 自洽"，本文件测的是"**能通过剧情步走到的** canon 子集"——
      // 若某个开启悬念的节点恰好没被任何剧情步引用（上一条断言会挡住），
      // 该悬念在实战中永远不会开，也就永远不需要关。两处口径不同，
      // 都值得守。
      final opened = <String, String>{};
      final closed = <String>{};
      for (final e in canonEvents) {
        final o = e.openLoop;
        if (o != null && o.trim().isNotEmpty) {
          final sep = o.indexOf('|');
          final id = (sep > 0 ? o.substring(0, sep) : o).trim();
          if (id.isNotEmpty) opened.putIfAbsent(id, () => e.id);
        }
        closed.addAll(e.closeLoops.map((x) => x.trim()));
      }

      expect(opened, isNotEmpty,
          reason: '一条悬念都没有，长期记忆 T1 层形同虚设');

      final dangling = opened.keys.toSet().difference(closed);
      expect(
        dangling,
        isEmpty,
        reason: '以下悬念开了却从未了结，玩家会看到一条永远没有下文的'
            '伏笔，AI 还会把它当仍在推进的线索继续加码：'
            '${dangling.map((d) => '$d(开启于 ${opened[d]})').toList()..sort()}',
      );
    });

    test('图鉴：canon 节点引用的 CG id 都在图鉴表里', () {
      // `unlockCG(cgById(cgId))`——查不到时 `cgById` 返回 null，
      // `unlockCG` 对 null 静默忽略。写错一个 CG id 的后果是
      // "这个名场面永远解不开图鉴"，同样不报错。
      final bad = <String>[];
      var cgRefs = 0;
      for (final e in canonEvents) {
        final cg = e.unlockCg;
        if (cg == null) continue;
        cgRefs++;
        if (cgById(cg) == null) bad.add('${e.id} → $cg');
      }
      expect(cgRefs, greaterThan(0), reason: 'CG 接线一条都没用上');
      expect(bad, isEmpty,
          reason: '以下原著节点引用了不存在的 CG id，图鉴永远解不开：$bad');
    });
  });
}
