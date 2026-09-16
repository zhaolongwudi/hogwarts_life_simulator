/// 剧情图的**结构完整性**测试：孤儿步 + 时间线落月。
///
/// 【为什么需要这个文件】扩写剧情内容时，有两类 bug 不会让代码编译失败，
/// 只会让玩家"少玩到几步"或者"剧情时间和原著对不上"，而且极难从
/// 测试报错信息里看出根因：
///
///   1. **孤儿步**——新加的步没有任何入边，玩家永远走不到。
///      曾经的 `ps_ch7_gifts` 就是这样：E2E 断言只告诉你
///      「doneSteps 里少了 ps_ch7_gifts」，却不说为什么少。
///
///   2. **时间线漂移**——某步声明了 `canonRefId: 'canon_xxx'`，
///      但按 `timeCostDays` 逐日推进后，它落在的月份和节点声明的
///      月份对不上。玩家会看到"十月的事被写在岁末"。
///
/// 这两个检查以前只存在于开发期的 Python 脚本里，脚本不在 CI 上跑，
/// 下次扩写内容时同样的坑还得再踩一遍。现在把它们钉进测试套件。
///
/// 【时间线判定的语义】引擎在**走完一步的天数之后**才比对月份
/// （见 `_runStoryTurn` / `advanceStoryTime`），所以这里也按
/// "加完本步 days 后的日期"来判定，与运行时完全一致。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/canon_events.dart';
import 'package:hogwarts_life_simulator/data/story_data.dart';
import 'package:hogwarts_life_simulator/models/story_progress.dart';

/// 剧情模式起点的"年中锚点"：暑假开始（各书 `startMonth` / `startDay` 声明，
/// 魔法石是 7-18，其余六部是 7-25）。这里不写死，统一从书定义里读。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAllStoryBooks);

  group('A · 剧情图可达性（没有走不到的步）', () {
    test('七部曲全部步都有入边——不存在孤儿步', () {
      final books = kStoryBooks.values.toList();
      expect(books, isNotEmpty, reason: '书表应当已注册');

      final problems = <String>[];

      for (final book in books) {
        // 收集全书步与显式边
        final allSteps = <StoryStepDef>[];
        for (final ch in book.chapters) {
          allSteps.addAll(ch.steps);
        }
        if (allSteps.isEmpty) continue;

        final ids = {for (final s in allSteps) s.id};
        final explicitTargets = <String>{};
        for (final s in allSteps) {
          for (final c in s.choices) {
            final n = c.nextStepId;
            if (n.isNotEmpty) explicitTargets.add(n);
          }
        }

        final reachable = <String>{...explicitTargets};

        // ① 全书第一步：剧情模式从这里开局，天然可达。
        reachable.add(allSteps.first.id);

        // ② 每章第一步：章末 `_resolveNextStep` 返回 null 时，
        //    `_finishStory` 会自动跳到下一章首步，所以天然可达。
        for (final ch in book.chapters) {
          if (ch.steps.isNotEmpty) reachable.add(ch.steps.first.id);
        }

        // ③ 「顺延」：某步的**所有**分支都落到 `''`（含未声明 nextStepId，
        //    因为 `StoryChoiceDef.nextStepId` 默认就是 `''`）时，它会顺延到
        //    本章的下一个未完成步——即本章文件顺序里它之后的任意步。
        for (final ch in book.chapters) {
          for (var i = 0; i < ch.steps.length; i++) {
            final s = ch.steps[i];
            final hasExplicit =
                s.choices.any((c) => c.nextStepId.isNotEmpty);
            if (!hasExplicit) {
              for (var j = i + 1; j < ch.steps.length; j++) {
                reachable.add(ch.steps[j].id);
              }
            }
          }
        }

        // ④ 每个显式边的目标必须真实存在（防手误写错 id）
        for (final t in explicitTargets) {
          if (!ids.contains(t)) {
            problems.add('${book.id}: 边指向不存在的步 "$t"');
          }
        }

        // ⑤ 孤儿步
        for (final s in allSteps) {
          if (!reachable.contains(s.id)) {
            problems.add('${book.id}: 孤儿步 "${s.id}"（无任何入边，玩家走不到）');
          }
        }
      }

      expect(
        problems,
        isEmpty,
        reason: '剧情图存在结构问题，玩家会少玩到内容：\n${problems.join('\n')}',
      );
    });

    test('每一步的选择数 >= 2（不能有单选项的"伪选择"）', () {
      final problems = <String>[];
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            if (s.choices.length < 2) {
              problems.add('${book.id}/${s.id}: 只有 ${s.choices.length} 个选择');
            }
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('显式边不构成环——有环玩家会卡死，永远跑不完全书', () {
      // 【为什么必须查】孤儿步的后果是"少玩几步"（doneSteps 断言会说少了几步），
      // 而**环**的后果是"永远跑不完"——E2E 只会报一句"GoF 必须能跑完"，
      // 没有任何信息指向出问题的那一步。
      //
      // 【这个测试是被一次真实事故逼出来的】往《火焰杯》第一章插入新步时，
      // 新步被排到了某已有步之前，而那个已有步的出边仍指着更靠前的步，
      // 于是引擎在 `goblet` 与 `guests` 之间来回跳，guard 打满 200 次。
      //
      // 【只查显式边】`nextStepId: ''` 是"顺延到本章下一个未完成步"，
      // 按文件顺序单调前进，不可能成环。
      final cycles = <String>[];

      for (final book in kStoryBooks.values) {
        // 建图：步 id → 显式出边（限本书内）
        final edges = <String, List<String>>{};
        final allIds = <String>{};
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            allIds.add(s.id);
          }
        }
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            edges[s.id] = s.choices
                .map((c) => c.nextStepId)
                .where((n) => n.isNotEmpty && allIds.contains(n))
                .toList();
          }
        }

        // 三色 DFS 找环
        const white = 0, gray = 1, black = 2;
        final color = <String, int>{for (final id in allIds) id: white};
        final stack = <String>[];

        void dfs(String u) {
          color[u] = gray;
          stack.add(u);
          for (final v in edges[u] ?? const <String>[]) {
            if (color[v] == gray) {
              final at = stack.indexOf(v);
              cycles.add('${book.id}: ${stack.sublist(at).join(' → ')} → $v');
            } else if (color[v] == white) {
              dfs(v);
            }
          }
          stack.removeLast();
          color[u] = black;
        }

        for (final id in allIds) {
          if (color[id] == white) dfs(id);
        }
      }

      expect(
        cycles,
        isEmpty,
        reason: '剧情图存在环，玩家会在这几步之间无限循环：\n${cycles.join('\n')}',
      );
    });

    test('步 id 与选择 id 全局唯一（防复制粘贴产生重名）', () {
      final stepIds = <String, String>{}; // id -> "book/step"
      final dupSteps = <String>[];
      final dupChoices = <String>[];

      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            if (stepIds.containsKey(s.id)) {
              dupSteps.add('${s.id}（${stepIds[s.id]} 与 ${book.id}/${ch.id}）');
            } else {
              stepIds[s.id] = '${book.id}/${ch.id}';
            }
            final local = <String>{};
            for (final c in s.choices) {
              if (!local.add(c.id)) {
                dupChoices.add('${book.id}/${s.id}/${c.id}（同步内重名）');
              }
            }
          }
        }
      }

      expect(dupSteps, isEmpty, reason: '重复的步 id：\n${dupSteps.join('\n')}');
      expect(dupChoices, isEmpty, reason: '重复的选择 id：\n${dupChoices.join('\n')}');
    });
  });

  group('B · 原著节点与剧情的对应关系', () {
    test('canonRefId 不指向幽灵节点', () {
      final ghost = <String>[];
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            final ref = s.canonRefId;
            if (ref != null && ref.isNotEmpty && canonEventById(ref) == null) {
              ghost.add('${book.id}/${s.id} → $ref');
            }
          }
        }
      }
      expect(ghost, isEmpty, reason: 'canonRefId 指向不存在的节点：\n${ghost.join('\n')}');
    });

    test('同一个 canon 节点不被两步重复声明', () {
      final owners = <String, List<String>>{};
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            final ref = s.canonRefId;
            if (ref != null && ref.isNotEmpty) {
              owners.putIfAbsent(ref, () => []).add('${book.id}/${s.id}');
            }
          }
        }
      }
      final dup = owners.entries.where((e) => e.value.length > 1).toList();
      expect(
        dup,
        isEmpty,
        reason: '同一节点被多步声明（"节点唯一性"被破坏）：\n'
            '${dup.map((e) => '${e.key}: ${e.value.join(", ")}').join('\n')}',
      );
    });

    test('每部书声明的节点都落在该书的学年范围内', () {
      final problems = <String>[];
      for (final book in kStoryBooks.values) {
        final startY = book.startYear;
        // 起始 7 月 → 学年跨到次年 7 月
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            final ref = s.canonRefId;
            if (ref == null || ref.isEmpty) continue;
            final node = canonEventById(ref);
            if (node == null) continue;
            final ok = (node.year == startY && node.month >= book.startMonth) ||
                node.year == startY + 1;
            if (!ok) {
              problems.add(
                '${book.id}/${s.id}: 声明 $ref 落在 ${node.year}-${node.month}，'
                '不在 ${book.startYear}-07 ~ ${book.startYear + 1}-07 内',
              );
            }
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  });

  group('C · 时间线落月（剧情走到的月份要和节点一致）', () {
    test('每个带 canonRefId 的步，走完后的月份等于节点月份', () {
      final problems = <String>[];

      for (final book in kStoryBooks.values) {
        // 从书起始日（每年 7 月 25 日）开始逐日推进。
        // 【为什么用 DateTime 而不是 (年,月,日) 三元组】day 是判定月份的依据：
        // 只记录 (年,月) 会把每月多出的天数抹平，跨年时误差累积到 1~2 个月，
        // 于是绝大多数节点都会被误报成"错位"。必须保留完整的日期。
        var cursor = DateTime(
          book.startYear,
          book.startMonth,
          book.startDay,
        );

        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            // 引擎语义：先加天数，再判定月份
            cursor = cursor.add(Duration(days: s.timeCostDays));

            final ref = s.canonRefId;
            if (ref == null || ref.isEmpty) continue;
            final node = canonEventById(ref);
            if (node == null) continue;

            if (node.year != cursor.year || node.month != cursor.month) {
              problems.add(
                '${book.id}/${s.id}: 声明 $ref（原著 ${node.year}-${node.month}），'
                '但剧情推进到 ${cursor.year}-${cursor.month}',
              );
            }
          }
        }
      }

      expect(
        problems,
        isEmpty,
        reason: '剧情时间与原著节点错位：\n${problems.join('\n')}',
      );
    });
  });
}
