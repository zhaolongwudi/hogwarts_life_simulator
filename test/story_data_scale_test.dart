/// 剧情内容规模守卫——「长期可玩」这条产品要求的自动化验收线。
///
/// 【为什么需要这个文件】`story_data_test.dart` 守的是"每一块内容都合法"，
/// `canon_story_parallel_test.dart` 守的是"原著节点都被讲到"，
/// 但它们都不关心**内容够不够多**。而"离线模式只能玩几十回合"这个
/// 缺陷的根因恰恰是内容量：166 步 × 每回合一天，玩家不到一小时就走完七部。
///
/// 这里把"够长"本身写成断言：每章步数下限、每部总步数下限、七部总步数下限。
/// 以后谁把内容删回去、或者新增章节时偷懒只放两步，都会在这里撞墙。
///
/// 【口径说明】下限取"当前实装值"，不是"目标值"——它的作用是**防止回退**，
/// 不是限制增长。玩家侧的完整体验时长还取决于 AI 自由发挥与沙盒回合，
/// 这里只钉死剧情骨架本身的体量。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/story_data.dart';
import 'package:hogwarts_life_simulator/models/story_progress.dart';

/// 每章步数下限。低于它，一章只有两三个节拍，玩家点两下就翻章了。
const int kMinStepsPerChapter = 2;

/// 每部书的总步数下限（七部曲各自的最低体量）。
///
/// 【这组数字怎么来的】它是"已完成扩写"的既有规模，而不是拍脑袋的目标：
/// 低于它说明有人把内容删回去了。七部曲现已全部扩写完毕，
/// 各部下限 = 当前实际步数。
const Map<String, int> kMinStepsPerBook = {
  'ps': 56,
  'cos': 64,
  'poa': 46,
  'gof': 42,
  'ootp': 45,
  'hbp': 39,
  'dh': 42,
};

/// 七部曲总步数下限（当前 56+64+46+42+45+39+42 = 334）。
const int kMinTotalSteps = 334;

/// 一部书总步数。
int _stepsOf(StoryBookDef book) =>
    book.chapters.fold<int>(0, (n, c) => n + c.steps.length);

void main() {
  setUpAll(registerAllStoryBooks);

  group('A · 单章体量', () {
    test('每章至少 $kMinStepsPerChapter 步', () {
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          expect(
            ch.steps.length,
            greaterThanOrEqualTo(kMinStepsPerChapter),
            reason: '章 ${ch.id}（${ch.title}）只有 ${ch.steps.length} 步，'
                '玩家两下就翻章了',
          );
        }
      }
    });

    test('每章至少 4 个选择点（两步 × 两分支）', () {
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          final choices =
              ch.steps.fold<int>(0, (n, s) => n + s.choices.length);
          expect(
            choices,
            greaterThanOrEqualTo(4),
            reason: '章 ${ch.id} 只有 $choices 个选择点',
          );
        }
      }
    });

    test('每步至少 2 个分支（一步 1 个选项不构成"选择弧"）', () {
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            expect(
              s.choices.length,
              greaterThanOrEqualTo(2),
              reason: '步 ${s.id} 只有 ${s.choices.length} 个分支',
            );
          }
        }
      }
    });
  });

  group('B · 单部体量', () {
    test('七部全部实装，每部步数不低于下限', () {
      for (final entry in kMinStepsPerBook.entries) {
        final book = findStoryBook(entry.key);
        expect(book, isNotNull, reason: '${entry.key} 必须已实装');
        final steps = _stepsOf(book!);
        expect(
          steps,
          greaterThanOrEqualTo(entry.value),
          reason: '《${book.title}》只有 $steps 步，低于体量下限 '
              '${entry.value}——内容被删回去了？',
        );
      }
    });

    test('每部章节数不低于 6（一部书的学年至少六个大段落）', () {
      for (final book in kStoryBooks.values) {
        expect(
          book.chapters.length,
          greaterThanOrEqualTo(6),
          reason: '《${book.title}》只有 ${book.chapters.length} 章',
        );
      }
    });
  });

  group('C · 全曲体量', () {
    test('七部曲总步数不低于 $kMinTotalSteps 步', () {
      var total = 0;
      for (final book in kStoryBooks.values) {
        total += _stepsOf(book);
      }
      expect(
        total,
        greaterThanOrEqualTo(kMinTotalSteps),
        reason: '七部曲一共只有 $total 步——"长期可玩"无从谈起',
      );
    });

    test('总选择点不低于总步数的 2 倍（平均每步 ≥2 个分支）', () {
      var steps = 0;
      var choices = 0;
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          steps += ch.steps.length;
          choices +=
              ch.steps.fold<int>(0, (n, s) => n + s.choices.length);
        }
      }
      expect(
        choices,
        greaterThanOrEqualTo(steps * 2),
        reason: '总步数 $steps、总选择点 $choices——平均每步不足 2 个分支',
      );
    });

    test('每部书的步数记账与全局扫描一致（防止漏注册）', () {
      // 若某部书在 story_data.dart 里定义了却没 registerStoryBook，
      // 它就不在 kStoryBooks 里，上面所有下限都会被"绕过"。
      expect(
        kStoryBooks.keys.toSet(),
        {'ps', 'cos', 'poa', 'gof', 'ootp', 'hbp', 'dh'},
        reason: '七部曲必须全部注册；有书漏注册时体量断言会失去意义',
      );
    });
  });

  group('D · 内容密度（叙事文本不得空转）', () {
    test('每步 setup 不少于 40 字（情境层要真的在铺陈）', () {
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            expect(
              s.setup.trim().length,
              greaterThanOrEqualTo(40),
              reason: '步 ${s.id} 的 setup 只有 ${s.setup.trim().length} 字，'
                  '撑不起一个节拍',
            );
          }
        }
      }
    });

    test('每步至少 2 条氛围句（世界层不能空）', () {
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            expect(
              s.ambient.length,
              greaterThanOrEqualTo(2),
              reason: '步 ${s.id} 只有 ${s.ambient.length} 条氛围句',
            );
          }
        }
      }
    });

    test('每个分支的 consequence 不少于 30 字（选择后果要写出来）', () {
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            for (final c in s.choices) {
              expect(
                c.consequence.trim().length,
                greaterThanOrEqualTo(30),
                reason: '分支 ${s.id}/${c.id} 的 consequence 只有 '
                    '${c.consequence.trim().length} 字',
              );
            }
          }
        }
      }
    });
  });

  group('E · flag 供给充足（长局要有长局的记忆量）', () {
    test('七部曲总 flag 数不低于总步数（平均每步至少置一个 flag）', () {
      var steps = 0;
      final flags = <String>{};
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          steps += ch.steps.length;
          for (final s in ch.steps) {
            for (final c in s.choices) {
              flags.addAll(c.effect.setFlags);
            }
          }
        }
      }
      expect(
        flags.length,
        greaterThanOrEqualTo(steps),
        reason: '总步数 $steps，但只有 ${flags.length} 个不同 flag——'
            '长局的分支记忆会迅速耗尽',
      );
    });
  });
}
