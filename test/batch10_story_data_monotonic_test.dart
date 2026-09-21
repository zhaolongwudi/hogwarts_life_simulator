/// Batch 10 · Issue #19：story_data 五书时间单调性静态校验。
///
/// 审查报告 §四.19 指出：五部原著剧本共 532KB 是「内容资产主体，当前零
/// 审查」，跨书时间/年龄一致性无人校验。本测试把「时间线单调」从开发期
/// Python 脚本提升为 CI 常驻检查，覆盖：
///
///   ① 书锚点全局单调：七部书 startYear/month/day 逐年递进（暑假开局），
///      且后书锚点严格晚于前书（防衔接时时间倒流）；
///   ② 书内时间单调：按章节顺序累加 timeCostDays 得到的每步时间戳严格递增；
///   ③ 跨书衔接不重叠：每书按全部步推进后的「完成日」不得晚于下一书锚点，
///      否则玩家从上一部结局进入下一部时会时间倒流；
///   ④ 每书总天数逐年 sanity 区间 [200, 420]：过长=误加整段、过短=误删整段；
///   ⑤ 每书完成日应落在学年尾（6~8 月）：剧情要覆盖整个学年的闭环；
///   ⑥ 源码静态存在性：story_data*.dart 六文件都注册了对应书，无幽灵文件、
///      无幽灵书。
///
/// 【为什么用 DateTime 而不是 (年,月,日) 三元组】day 是判定跨月/跨年的依据，
/// 只记 (年,月) 会把每月多出的天数抹平，跨年误差累积到 1~2 个月，
/// 绝大多数「错位」会被误报成正常。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/story_data.dart';
import 'package:hogwarts_life_simulator/models/story_progress.dart';

/// 从书的锚点开始，按章节/步骤顺序推进，返回每步的时间戳
/// （stepId, 推进后的日期）。
///
/// 【引擎语义】`_runStoryTurn` / `advanceStoryTime` 在**走完本步天数之后**
/// 才进入该步的日期，所以「本步时间戳 = 起点 + 累计到本步的天数」。
List<(String, DateTime)> _stepTimeline(StoryBookDef book) {
  var cursor = DateTime(book.startYear, book.startMonth, book.startDay);
  final out = <(String, DateTime)>[];
  for (final ch in book.chapters) {
    for (final s in ch.steps) {
      cursor = cursor.add(Duration(days: s.timeCostDays));
      out.add((s.id, cursor));
    }
  }
  return out;
}

/// 书内全部步骤推进后的最终日期（剧情模式的「本部完成日」）。
DateTime _bookEndDate(StoryBookDef book) {
  final tl = _stepTimeline(book);
  if (tl.isEmpty) {
    return DateTime(book.startYear, book.startMonth, book.startDay);
  }
  return tl.last.$2;
}

/// 书内全部 timeCostDays 之和。
int _bookTotalDays(StoryBookDef book) {
  var total = 0;
  for (final ch in book.chapters) {
    for (final s in ch.steps) {
      total += s.timeCostDays;
    }
  }
  return total;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAllStoryBooks);

  group('Batch 10 · Issue #19：书锚点全局单调', () {
    test('七部书按 kBookOrder 锚点严格递增（年份递进 + 同窗日不重叠）', () {
      final problems = <String>[];
      for (var i = 0; i < kBookOrder.length; i++) {
        final b = findStoryBook(kBookOrder[i])!;
        expect(b.startMonth, 7, reason: '${b.id} 应从暑假开局');
        if (i > 0) {
          final prev = findStoryBook(kBookOrder[i - 1])!;
          if (prev.startAbsoluteDayIndex >= b.startAbsoluteDayIndex) {
            problems.add(
              '${b.id} 锚点 (${b.startYear}-${b.startMonth}-${b.startDay}) '
              '不晚于上一部 ${prev.id} 锚点 '
              '(${prev.startYear}-${prev.startMonth}-${prev.startDay})',
            );
          }
        }
      }
      expect(
        problems,
        isEmpty,
        reason: '书锚点存在倒流（衔接时玩家时间会倒退）：\n${problems.join('\n')}',
      );
    });

    test('书锚点年份与七部次序一致（1991~1997，逐部 +1）', () {
      final years = <int>[];
      for (final id in kBookOrder) {
        years.add(findStoryBook(id)!.startYear);
      }
      expect(years, [1991, 1992, 1993, 1994, 1995, 1996, 1997]);
    });
  });

  group('Batch 10 · Issue #19：书内时间单调', () {
    test('每书按步骤推进后的时间戳严格递增（时间只能向前）', () {
      final problems = <String>[];
      for (final book in kStoryBooks.values) {
        DateTime? prev;
        for (final (stepId, ts) in _stepTimeline(book)) {
          if (prev != null && !ts.isAfter(prev)) {
            problems.add(
              '${book.id}/$stepId: 时间戳 $ts 未晚于上一步 $prev'
              '（timeCostDays 应全为正）',
            );
          }
          prev = ts;
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('每章推进天数 > 0（时间在章内也必须前进）', () {
      final problems = <String>[];
      for (final book in kStoryBooks.values) {
        var chapterTotal = 0;
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            chapterTotal += s.timeCostDays;
          }
          if (chapterTotal <= 0) {
            problems.add('${book.id}/${ch.id}: 本章累计天数 $chapterTotal 非正');
          }
          chapterTotal = 0;
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  });

  group('Batch 10 · Issue #19：跨书衔接不重叠', () {
    test('每书完成日不得晚于下一书锚点（防接口时间倒流）', () {
      final problems = <String>[];
      for (var i = 0; i < kBookOrder.length - 1; i++) {
        final cur = findStoryBook(kBookOrder[i])!;
        final nxt = findStoryBook(kBookOrder[i + 1])!;
        final end = _bookEndDate(cur);
        final nxtStart = DateTime(nxt.startYear, nxt.startMonth, nxt.startDay);
        if (end.isAfter(nxtStart)) {
          problems.add(
            '${cur.id} 完成日 $end 晚于下一部 ${nxt.id} 锚点 $nxtStart'
            '（玩家走完 ${cur.id} 结局后进入 ${nxt.id} 会时间倒流）',
          );
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('每书完成日落在学年尾（6~8 月）——剧情覆盖完整学年闭环', () {
      final problems = <String>[];
      for (final book in kStoryBooks.values) {
        // 未实装/半实装的骨架书（chapters 为空）跳过。
        if (book.chapters.isEmpty) continue;
        final end = _bookEndDate(book);
        // 七年开学锚点都是 7 月；完结应落在次年暑假（6~8 月）。
        final expectedYear = book.startYear + 1;
        if (end.year != expectedYear ||
            end.month < 6 ||
            end.month > 8) {
          problems.add(
            '${book.id}: 完成日 $end 不在 ${expectedYear} 年 6~8 月'
            '（剧情应覆盖一整学年，完结于学年末暑假）',
          );
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  });

  group('Batch 10 · Issue #19：内容规模 sanity', () {
    test('每书总天数落在合理区间 [200, 420]（防误删/误加整段）', () {
      final problems = <String>[];
      for (final book in kStoryBooks.values) {
        final total = _bookTotalDays(book);
        if (total < 200 || total > 420) {
          problems.add(
            '${book.id}: 总天数 $total 超出 [200, 420]'
            '（过短=可能误删整段剧情，过长=可能误加整段）',
          );
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('每书至少 1 章、每章至少 1 步、全书至少有 step 能推进时间', () {
      for (final book in kStoryBooks.values) {
        expect(book.chapters, isNotEmpty, reason: '${book.id} 不能是空骨架书');
        var steps = 0;
        for (final ch in book.chapters) {
          expect(ch.steps, isNotEmpty, reason: '${book.id}/${ch.id} 不能没有步');
          steps += ch.steps.length;
        }
        expect(steps, greaterThan(0), reason: '${book.id} 应有可取的时间步');
      }
    });
  });

  group('Batch 10 · Issue #19：源码静态存在性', () {
    const storyDataFiles = <String>[
      'lib/data/story_data.dart',
      'lib/data/story_data_poa.dart',
      'lib/data/story_data_gof.dart',
      'lib/data/story_data_ootp.dart',
      'lib/data/story_data_hbp.dart',
      'lib/data/story_data_dh.dart',
    ];

    test('story_data*.dart 六文件都存在且含章节定义', () {
      for (final f in storyDataFiles) {
        expect(File(f).existsSync(), isTrue, reason: '$f 应存在');
        final txt = File(f).readAsStringSync();
        expect(txt.contains('StoryChapterDef'), isTrue,
            reason: '$f 应含章节定义');
        expect(txt.contains('StoryStepDef'), isTrue,
            reason: '$f 应含步骤定义');
      }
    });

    test('七部书全部注册，含 ps/cos 同文件（story_data.dart）', () {
      expect(
        kStoryBooks.keys,
        containsAll(const ['ps', 'cos', 'poa', 'gof', 'ootp', 'hbp', 'dh']),
      );
      expect(kStoryBooks, hasLength(7), reason: '七部曲全部实装');
      // ps 与 cos 共用 story_data.dart（历史结构），其余一书一文件。
      final mainFile = File('lib/data/story_data.dart').readAsStringSync();
      expect(mainFile.contains("id: 'ps'"), isTrue);
      expect(mainFile.contains("id: 'cos'"), isTrue);
    });

    test('每个注册书在 kBookOrder 中都有位置（无幽灵书）', () {
      final orderSet = kBookOrder.toSet();
      for (final id in kStoryBooks.keys) {
        expect(orderSet.contains(id), isTrue,
            reason: '$id 已注册但不在 kBookOrder 里（幽灵书）');
      }
    });
  });
}