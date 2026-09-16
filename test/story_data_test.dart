/// 剧情数据层测试：纯函数 + const 表不变量 + 存档序列化往返。
///
/// 【为什么要单独测这一层】运行时（`_runStoryTurn`）只能验证"跑得通"，
/// 而查步/分支过滤/结局判定这些纯函数一旦错了，症状会出现在很远的地方
/// （玩家点了个选项跳到不存在的步，或者永远拿不到某个结局）。
/// 纯函数没有副作用，测试成本极低，必须钉死。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/canon_events.dart';
import 'package:hogwarts_life_simulator/data/story_data.dart';
import 'package:hogwarts_life_simulator/models/story_progress.dart';

void main() {
  setUpAll(registerAllStoryBooks);

  group('A · action 编解码', () {
    test('编码后再解析，往返一致', () {
      const stepId = 'ps_ch1_letter';
      const choiceId = 'read_in_room';
      final encoded = encodeStoryAction(stepId, choiceId);
      expect(encoded, '@@story:ps_ch1_letter:read_in_room@@');
      final parsed = parseStoryCommand(encoded);
      expect(parsed, isNotNull);
      expect(parsed!.stepId, stepId);
      expect(parsed.choiceId, choiceId);
    });

    test('普通自由行动不会被误判为剧情指令', () {
      for (final a in [
        '四处看看',
        '/状态',
        '//这是一句以斜杠开头的话',
        '',
        '   ',
      ]) {
        expect(parseStoryCommand(a), isNull, reason: '不该把「$a」判成剧情指令');
      }
    });

    test('容忍前后空白、缺收尾 @@、choiceId 含冒号', () {
      expect(
        parseStoryCommand('  @@story:s:c@@  ')?.stepId,
        's',
        reason: '前后空白应被容忍',
      );
      expect(
        parseStoryCommand('@@story:s:c')?.choiceId,
        'c',
        reason: '缺收尾 @@ 也应能解析',
      );
      expect(
        parseStoryCommand('@@story:s:a:b')?.choiceId,
        'a:b',
        reason: '只按第一个冒号切分，choiceId 里的冒号要保留',
      );
    });

    test('残缺输入一律返回 null，不抛异常', () {
      for (final a in [
        '@@story:',
        '@@story:s:',
        '@@story::c',
        '@@story@@',
        'story:s:c',
      ]) {
        expect(parseStoryCommand(a), isNull, reason: '「$a」应判定为非法');
      }
    });

    test('isStoryAction 与 parseStoryCommand 口径一致', () {
      expect(isStoryAction('@@story:s:c@@'), isTrue);
      expect(isStoryAction('随便走走'), isFalse);
    });
  });

  group('B · StoryEffect', () {
    test('默认构造为空效果', () {
      expect(const StoryEffect().isEmpty, isTrue);
      expect(StoryEffect.none.isEmpty, isTrue);
    });

    test('任一字段非零即不为空', () {
      expect(const StoryEffect(spirit: 1).isEmpty, isFalse);
      expect(const StoryEffect(addItems: ['x']).isEmpty, isFalse);
      expect(const StoryEffect(setFlags: ['f']).isEmpty, isFalse);
      expect(const StoryEffect(clearFlags: ['f']).isEmpty, isFalse);
      expect(const StoryEffect(reputation: -1).isEmpty, isFalse);
    });
  });

  group('C · StoryProgress 序列化', () {
    test('fromJson(null) 得到 inactive（老存档兼容的关键一行）', () {
      expect(StoryProgress.fromJson(null).active, isFalse);
      expect(StoryProgress.inactive.active, isFalse);
    });

    test('active 不为 true 时一律 inactive', () {
      expect(StoryProgress.fromJson({'active': false}).active, isFalse);
      expect(StoryProgress.fromJson({'book_id': 'ps'}).active, isFalse);
    });

    test('完整往返：字段一个不少', () {
      const p = StoryProgress(
        active: true,
        bookId: 'ps',
        chapterId: 'ps_ch1',
        stepId: 'ps_ch1_letter',
        doneSteps: ['a', 'b'],
        flags: ['ps_accepted'],
        chosen: {'ps_ch1_letter': 'read_in_room'},
        effects: {'affection': 12, 'reputation': 5, 'housePoints': -3},
        endingId: 'ps_ending_steady',
        knowledge: ['knows_hogwarts_acceptance'],
        stepTurnSeed: 7,
      );
      final back = StoryProgress.fromJson(p.toJson());
      expect(back.active, isTrue);
      expect(back.bookId, 'ps');
      expect(back.chapterId, 'ps_ch1');
      expect(back.stepId, 'ps_ch1_letter');
      expect(back.doneSteps, ['a', 'b']);
      expect(back.flags, ['ps_accepted']);
      expect(back.chosen, {'ps_ch1_letter': 'read_in_room'});
      expect(back.effects['affection'], 12);
      expect(back.effects['housePoints'], -3);
      expect(back.endingId, 'ps_ending_steady');
      expect(back.knowledge, ['knows_hogwarts_acceptance']);
      expect(back.stepTurnSeed, 7);
    });

    test('缺字段/脏字段安全降级，不抛异常', () {
      final p = StoryProgress.fromJson({
        'active': true,
        'effects': {'affection': '9', 'reputation': null, 'bad': 'x'},
      });
      expect(p.effects['affection'], 9, reason: '数字字符串应被容忍');
      expect(p.effects['reputation'], 0, reason: 'null 应降级为 0');
      expect(p.effects['bad'], 0, reason: '解析不了的应降级为 0');
      expect(p.flags, isEmpty);
      expect(p.chosen, isEmpty);
      expect(p.bookId, 'ps', reason: '缺 book_id 应用默认值');
    });

    test('isFinished 与 endingId 联动', () {
      expect(StoryProgress.inactive.isFinished, isFalse);
      expect(
        StoryProgress.inactive.copyWith(endingId: 'e1').isFinished,
        isTrue,
      );
    });

    test('数值汇总 getter 与 effects 一致', () {
      const p = StoryProgress(
        active: true,
        effects: {'affection': 30, 'reputation': 12, 'housePoints': 40},
      );
      expect(p.totalAffection, 30);
      expect(p.totalReputation, 12);
      expect(p.totalHousePoints, 40);
    });

    test('copyWith 只改指定字段', () {
      const base = StoryProgress(
        active: true,
        chapterId: 'ps_ch1',
        stepId: 's1',
      );
      final next = base.copyWith(stepId: 's2');
      expect(next.stepId, 's2');
      expect(next.chapterId, 'ps_ch1', reason: '未指定的字段必须原样保留');
      expect(next.active, isTrue);
    });
  });

  group('D · 查步 / 分支过滤', () {
    test('三元组查步命中，错一个就查不到', () {
      expect(findStoryStep('ps', 'ps_ch1', 'ps_ch1_letter'), isNotNull);
      expect(findStoryStep('ps', 'ps_ch1', '不存在'), isNull);
      expect(findStoryStep('ps', '不存在', 'ps_ch1_letter'), isNull);
      expect(findStoryStep('不存在', 'ps_ch1', 'ps_ch1_letter'), isNull);
    });

    test('findStoryStepAnywhere 能跨章找到', () {
      final s = findStoryStepAnywhere('ps', 'ps_ch1_reply');
      expect(s, isNotNull);
      expect(s!.chapterId, 'ps_ch1');
    });

    test('无 requireFlag 时全部选项可选', () {
      final step = findStoryStep('ps', 'ps_ch1', 'ps_ch1_letter')!;
      final ok = availableStoryChoices(step, const {});
      expect(ok.length, step.choices.length);
    });

    test('requireFlag 未持有 → 该选项被过滤', () {
      const step = StoryStepDef(
        id: 's',
        chapterId: 'c',
        setup: 'x',
        choices: [
          StoryChoiceDef(id: 'plain', text: '普通', consequence: 'x'),
          StoryChoiceDef(
            id: 'locked',
            text: '需要情报',
            consequence: 'x',
            requireFlag: 'knows_secret',
          ),
        ],
      );
      final without = availableStoryChoices(step, const {});
      expect(without.map((c) => c.id), ['plain']);
      final with_ = availableStoryChoices(step, const {'knows_secret'});
      expect(with_.map((c) => c.id), ['plain', 'locked']);
    });

    test('全部被过滤时退回全部选项（绝不给出空选择列表）', () {
      const step = StoryStepDef(
        id: 's',
        chapterId: 'c',
        setup: 'x',
        choices: [
          StoryChoiceDef(
            id: 'locked',
            text: '需要情报',
            consequence: 'x',
            requireFlag: 'never_set',
          ),
        ],
      );
      final ok = availableStoryChoices(step, const {});
      expect(ok.length, 1, reason: '退回全部选项，玩家不能面对空选择列表');
      expect(ok.first.id, 'locked');
    });
  });

  group('E · 结局判定', () {
    StoryBookDef book() => kStoryBooks['ps']!;

    test('规则按顺序取第一个满足的', () {
      // 同时满足"被记住的新生"与兜底规则，应取排在前面的那条
      const p = StoryProgress(
        active: true,
        flags: ['ps_family_supportive'],
        effects: {'affection': 99, 'reputation': 99},
      );
      expect(resolveStoryEnding(book(), p)!.id, 'ps_ending_trusted');
    });

    test('好感/声望不够 → 落到下一条规则', () {
      const p = StoryProgress(
        active: true,
        flags: ['ps_family_supportive'],
        effects: {'affection': 1, 'reputation': 1},
      );
      final e = resolveStoryEnding(book(), p)!;
      expect(e.id, 'ps_ending_steady', reason: '数值不达标应落到稳态结局');
    });

    test('没有任何 flag 时返回末位兜底规则', () {
      const p = StoryProgress(active: true);
      final e = resolveStoryEnding(book(), p)!;
      expect(e.id, 'ps_ending_detached');
      expect(e.requireFlags, isEmpty);
    });

    test('requireAnyFlags 语义：至少命中一个即可', () {
      const rule = StoryEndingRule(
        id: 'r',
        title: 't',
        body: 'b',
        requireAnyFlags: ['x', 'y'],
      );
      expect(rule.matches(const StoryProgress(active: true, flags: ['x'])), isTrue);
      expect(rule.matches(const StoryProgress(active: true, flags: ['y'])), isTrue);
      expect(rule.matches(const StoryProgress(active: true, flags: ['z'])), isFalse);
      expect(rule.matches(const StoryProgress(active: true)), isFalse);
    });

    test('完全没有结局规则的书返回 null，不崩', () {
      const empty = StoryBookDef(id: 'x', title: 'x', chapters: []);
      expect(resolveStoryEnding(empty, StoryProgress.inactive), isNull);
    });
  });

  group('F · 书表结构不变量', () {
    test('《魔法石》已注册，且 id 与标题正确', () {
      final book = findStoryBook('ps');
      expect(book, isNotNull);
      expect(book!.title, '魔法石');
      expect(kFirstStoryBookId, 'ps');
    });

    test('全部章/步的归属字段自洽', () {
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          expect(
            ch.bookId,
            book.id,
            reason: '章 ${ch.id} 的 bookId 与所属书不一致',
          );
          for (final s in ch.steps) {
            expect(
              s.chapterId,
              ch.id,
              reason: '步 ${s.id} 的 chapterId 与所属章不一致',
            );
          }
        }
      }
    });

    test('步 id 全书唯一', () {
      for (final book in kStoryBooks.values) {
        final seen = <String>{};
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            expect(seen.add(s.id), isTrue, reason: '步 id 重复：${s.id}');
          }
        }
      }
    });

    test('章 id 全书唯一，章序从 1 连续递增', () {
      for (final book in kStoryBooks.values) {
        final seen = <String>{};
        for (var i = 0; i < book.chapters.length; i++) {
          final ch = book.chapters[i];
          expect(seen.add(ch.id), isTrue, reason: '章 id 重复：${ch.id}');
          expect(
            ch.ordinal,
            i + 1,
            reason: '章 ${ch.id} 的 ordinal 应为 ${i + 1}',
          );
        }
      }
    });

    test('每章至少 1 步，每步至少 2 个分支（分支点是剧情的最小单元）', () {
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          expect(ch.steps, isNotEmpty, reason: '章 ${ch.id} 没有步');
          for (final s in ch.steps) {
            expect(
              s.choices.length >= 2,
              isTrue,
              reason: '步 ${s.id} 只有 ${s.choices.length} 个选项，不成其为分支点',
            );
          }
        }
      }
    });

    test('步内分支 id 唯一', () {
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            final seen = <String>{};
            for (final c in s.choices) {
              expect(
                seen.add(c.id),
                isTrue,
                reason: '步 ${s.id} 内分支 id 重复：${c.id}',
              );
            }
          }
        }
      }
    });

    test('nextStepId 要么为空（顺延），要么指向本步所在章里真实存在的步', () {
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          final ids = ch.steps.map((s) => s.id).toSet();
          for (final s in ch.steps) {
            for (final c in s.choices) {
              if (c.nextStepId.isEmpty) continue;
              expect(
                ids.contains(c.nextStepId),
                isTrue,
                reason:
                    '分支 ${s.id}/${c.id} 指向的步 ${c.nextStepId}'
                    ' 不在本章（跨章跳转请用空串顺延）',
              );
            }
          }
        }
      }
    });

    test('setup / consequence / text 均非空（空文本玩家会看到空白）', () {
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            expect(s.setup.trim(), isNotEmpty, reason: '步 ${s.id} 的 setup 为空');
            for (final c in s.choices) {
              expect(
                c.text.trim(),
                isNotEmpty,
                reason: '分支 ${s.id}/${c.id} 的 text 为空',
              );
              expect(
                c.consequence.trim(),
                isNotEmpty,
                reason: '分支 ${s.id}/${c.id} 的 consequence 为空',
              );
            }
          }
        }
      }
    });

    test('timeCostDays 为正数（时间只能向前）', () {
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            expect(
              s.timeCostDays > 0,
              isTrue,
              reason: '步 ${s.id} 的 timeCostDays 必须为正',
            );
          }
        }
      }
    });

    test('有结局规则的书，末位规则必须是兜底规则（无任何条件）', () {
      for (final book in kStoryBooks.values) {
        if (book.endings.isEmpty) continue;
        final last = book.endings.last;
        expect(
          last.requireFlags,
          isEmpty,
          reason: '书 ${book.id} 的末位结局带了 requireFlags，会让不满足者落到 null',
        );
        expect(last.requireAnyFlags, isEmpty);
        expect(last.minAffectionTotal, isNull);
        expect(last.minReputation, isNull);
      }
    });

    test('canonRefId 若声明，必须在 canon_events.dart 里有对应节点', () {
      // 这里只做前缀与格式校验：真正的存在性由批次 5 的去重测试覆盖
      // （避免本测试文件依赖 canon_events 的过滤逻辑）。
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            final ref = s.canonRefId;
            if (ref == null) continue;
            expect(
              isCanonEventId(ref),
              isTrue,
              reason: '步 ${s.id} 的 canonRefId「$ref」不是 canon_ 前缀',
            );
          }
        }
      }
    });

    test('storyStats 统计与手数一致（防误删整段）', () {
      final stats = storyStats;
      expect(stats.bookCount, kStoryBooks.length);
      expect(stats.chapterCount, greaterThan(0));
      expect(stats.stepCount, greaterThan(0));
      expect(stats.choiceCount, greaterThanOrEqualTo(stats.stepCount * 2));
    });

    test('firstStepOfBook 返回第一部第一步', () {
      final first = firstStepOfBook('ps');
      expect(first, isNotNull);
      expect(first!.chapterId, 'ps_ch1');
      expect(findStoryStep('ps', first.chapterId, first.id), isNotNull);
    });

    test('nextStoryChapter 逐章推进，末章返回 null', () {
      final book = findStoryBook('ps')!;
      final first = book.chapters.first;
      final second = nextStoryChapter(book, first.id);
      if (book.chapters.length == 1) {
        expect(second, isNull);
      } else {
        expect(second!.ordinal, 2);
      }
      expect(nextStoryChapter(book, book.chapters.last.id), isNull);
      expect(nextStoryChapter(book, '不存在的章'), isNull);
    });

    test('registerAllStoryBooks 幂等（重复调用不产生重复书）', () {
      final before = storyStats.stepCount;
      registerAllStoryBooks();
      registerAllStoryBooks();
      expect(storyStats.stepCount, before);
    });
  });

  group('G · 平行世界红线（剧情内容层）', () {
    test('不出现「玩家即哈利」的禁用措辞', () {
      const forbidden = <String>[
        '你是哈利',
        '你，哈利',
        '你的伤疤',
        '你额上的闪电',
        '闪电形伤疤',
        '你举起了魔杖对着蛇怪',
        '你杀死了蛇怪',
        '你作为救世主',
        '救世主的你',
        '你的父母被伏地魔',
        '你住在女贞路4号',
        '你的姨妈是佩妮',
        '你拿到了分院帽的',
      ];
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            final corpus = [
              s.setup,
              if (s.onEnterText != null) s.onEnterText!,
              ...s.ambient,
              for (final c in s.choices) c.text,
              for (final c in s.choices) c.consequence,
            ].join('\n');
            for (final bad in forbidden) {
              expect(
                corpus.contains(bad),
                isFalse,
                reason: '步 ${s.id} 出现「玩家即哈利」措辞：$bad',
              );
            }
          }
        }
      }
    });

    test('原著关键场景若出现，必须同时有 NPC 或「有人」作为行为主体', () {
      // 玩家可以"看见有人饮下独角兽的血"，但不能"自己饮下"。
      const keyScenes = <String, String>{'独角兽的血': '饮'};
      const subjSignals = [
        '有人', '他', '她', '他们', '那身影', '那道身影', '黑袍',
        '奇洛', '斯内普', '海格', '邓布利多', '费尔奇', '马尔福',
      ];
      for (final book in kStoryBooks.values) {
        for (final ch in book.chapters) {
          for (final s in ch.steps) {
            final corpus = [
              s.setup,
              if (s.onEnterText != null) s.onEnterText!,
              ...s.ambient,
              for (final c in s.choices) c.consequence,
            ].join('\n');
            keyScenes.forEach((scene, verb) {
              if (!corpus.contains(scene)) return;
              // 出现了关键场景词：同一段里必须有第三方主体
              // （否则很容易写成"你饮下了独角兽的血"——那是别人做的事）
              final hasSubject = subjSignals.any(corpus.contains);
              expect(
                hasSubject,
                isTrue,
                reason:
                    '步 ${s.id} 提到「$scene（$verb）」却没有第三方行为主体，'
                    '容易写成玩家自己动手',
              );
            });
          }
        }
      }
    });

    test('结局文本同样不得出现「玩家即哈利」措辞', () {
      const forbidden = <String>['你是哈利', '救世主的你', '你杀死了伏地魔'];
      for (final book in kStoryBooks.values) {
        for (final e in book.endings) {
          for (final bad in forbidden) {
            expect(
              (e.title + e.body).contains(bad),
              isFalse,
              reason: '结局 ${e.id} 出现禁用措辞：$bad',
            );
          }
        }
      }
    });
  });
}
