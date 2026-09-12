/// 剧情回合运行时测试：一个完整的剧情回合能不能正确推进。
///
/// 【这一层测什么】数据层的纯函数已由 `story_data_test.dart` 钉死；
/// 这里测的是**接线**：
///   · 剧情模式下点选项 → 叙事换了、选项换了、进度前进了；
///   · 时间按章节节拍推进（不是按行动关键词猜的）；
///   · 关系/物品/flag 真的落到玩家与记忆上；
///   · 自由输入不会卡死（降级为自由行动）；
///   · 全程 0 AI 调用（离线红线）。
///
/// 【为什么用 `makeGame` 而不是手搓 provider】它是全项目唯一的共享夹具
/// （`test/helpers/test_fixtures.dart`），走真实初始化路径。自己搭一份
/// 会随着初始化逻辑变化而腐烂，且测不出"真实开局能不能进剧情模式"。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/story_data.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/models/story_progress.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_fixtures.dart';

/// 构造一个已进入剧情模式的 GameProvider。
///
/// 用 `offlineQuickMode: true` 是因为**剧情模式挂在离线分支上**：
/// 没有它，`processChoice` 会因为"没有 AI 服务且未开离线"直接报错返回。
/// `openingScene = 'letter'` 固定从第一章开始（批次 4 起，剧情开局
/// 会按开局场景跳章，夹具不固定的话默认 station 会落到第三章）。
Future<GameProvider> makeStoryGame() async {
  final gp = await makeGame(offlineQuickMode: true);
  gp.openingScene = 'letter';
  gp.enterStoryMode();
  return gp;
}

/// 取当前第一个选项的 action（即玩家的"点按钮"行为）。
String firstAction(GameProvider gp) => gp.choices.first.action;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAllStoryBooks);

  group('A · 进入剧情模式', () {
    test('首屏就是第一章第一步，且选项是剧情选项（不是兜底选项）', () async {
      final gp = await makeStoryGame();
      expect(gp.storyProgress.active, isTrue);
      expect(gp.storyProgress.bookId, 'ps');
      expect(gp.storyProgress.chapterId, 'ps_ch1');
      expect(gp.storyProgress.stepId, 'ps_ch1_letter');

      final book = findStoryBook('ps')!;
      expect(gp.currentNarrative, contains(book.title));
      expect(gp.currentNarrative, contains('女贞路的信'));

      final step = findStoryStep('ps', 'ps_ch1', 'ps_ch1_letter')!;
      expect(gp.choices.length, step.choices.length);
      // 关键：action 必须是剧情编码，而不是自由文本
      for (final c in gp.choices) {
        expect(
          isStoryAction(c.action),
          isTrue,
          reason: '选项「${c.text}」的 action 不是剧情编码：${c.action}',
        );
      }
    });

    test('首屏叙事里带章节抬头（玩家要知道自己在第几章）', () async {
      final gp = await makeStoryGame();
      expect(gp.currentNarrative, contains('第 1 章'));
    });

    test('开局进入剧情模式时不调用 AI（离线红线）', () async {
      final gp = await makeStoryGame();
      expect(gp.apiCalls, 0);
    });
  });

  group('B · 一个完整回合的推进', () {
    test('点第一个选项 → 进度前进、叙事换成下一步', () async {
      final gp = await makeStoryGame();
      final beforeStep = gp.storyProgress.stepId;
      final beforeTurn = gp.turnCount;

      await gp.processChoice(GameChoice(text: 'x', action: firstAction(gp)));

      expect(gp.turnCount, beforeTurn + 1, reason: '回合数必须推进');
      expect(
        gp.storyProgress.stepId,
        isNot(beforeStep),
        reason: '剧情游标必须前进',
      );
      expect(gp.storyProgress.stepId, 'ps_ch1_tell');
      expect(gp.storyProgress.doneSteps, contains('ps_ch1_letter'));
      expect(
        gp.storyProgress.chosen['ps_ch1_letter'],
        isNotNull,
        reason: '分支选择必须被记录',
      );
    });

    test('叙事里出现"你做了什么"（consequence），而不是只有情境', () async {
      final gp = await makeStoryGame();
      final step = findStoryStep('ps', 'ps_ch1', 'ps_ch1_letter')!;
      final choice = step.choices.first;

      await gp.processChoice(
        GameChoice(text: choice.text, action: firstAction(gp)),
      );

      // consequence 里的关键片段应能在叙事里找到（取前 12 字做探测，
      // 避免标点差异导致断言脆弱）
      final probe = choice.consequence.substring(0, 12);
      expect(
        gp.currentNarrative,
        contains(probe),
        reason: '选完之后读不到自己的行动，玩家会以为没生效',
      );
    });

    test('下一步的选项重新生成，且指向新的步', () async {
      final gp = await makeStoryGame();
      await gp.processChoice(GameChoice(text: 'x', action: firstAction(gp)));

      expect(gp.choices, isNotEmpty);
      final nextStep = findStoryStep('ps', 'ps_ch1', 'ps_ch1_tell')!;
      expect(gp.choices.length, nextStep.choices.length);
      for (final c in gp.choices) {
        final cmd = parseStoryCommand(c.action);
        expect(cmd, isNotNull);
        expect(
          cmd!.stepId,
          nextStep.id,
          reason: '选项必须指向当前步，否则点了会走错分支',
        );
      }
    });

    test('连点三次能一路走完第一章并进入第二章或结局', () async {
      final gp = await makeStoryGame();
      // 第一章共 3 步
      for (var i = 0; i < 3; i++) {
        if (gp.choices.isEmpty) break;
        final action = gp.choices.first.action;
        await gp.processChoice(GameChoice(text: 'x', action: action));
      }
      // 走完第一章后应换章（本书目前只有 1 章，故应到达结局）
      expect(
        gp.storyProgress.isFinished || gp.storyProgress.chapterId != 'ps_ch1',
        isTrue,
        reason: '第一章走完必须换章或收束到结局，不能原地踏步',
      );
    });
  });

  group('C · 时间按章节节拍推进（不是关键词推断）', () {
    test('推进天数等于本步声明的 timeCostDays', () async {
      final gp = await makeStoryGame();
      final beforeDay = gp.worldState.time.absoluteDayIndex;

      await gp.processChoice(GameChoice(text: 'x', action: firstAction(gp)));

      // 进入的是下一步 `ps_ch1_tell`，其 timeCostDays = 5
      final nextStep = findStoryStep('ps', 'ps_ch1', 'ps_ch1_tell')!;
      final delta = gp.worldState.time.absoluteDayIndex - beforeDay;
      expect(
        delta,
        nextStep.timeCostDays,
        reason: '时间必须按 nextStep.timeCostDays 推进，'
            '而不是被行动关键词猜出来',
      );
    });

    test('同一步重复进入时时间不会被推两遍（关键词推断已让位）', () async {
      final gp = await makeStoryGame();
      final step1 = findStoryStep('ps', 'ps_ch1', 'ps_ch1_tell')!;
      final before = gp.worldState.time.absoluteDayIndex;
      await gp.processChoice(GameChoice(text: 'x', action: firstAction(gp)));
      final afterFirst = gp.worldState.time.absoluteDayIndex;
      expect(afterFirst - before, step1.timeCostDays);
      // 再走一步，增量应等于**下一步**的步长（而不是叠加）
      final step2 = findStoryStep('ps', 'ps_ch1', 'ps_ch1_reply')!;
      await gp.processChoice(GameChoice(text: 'x', action: firstAction(gp)));
      final afterSecond = gp.worldState.time.absoluteDayIndex;
      expect(afterSecond - afterFirst, step2.timeCostDays);
    });

    test('worldState 的旧字段与时钟同步（month 字符串等）', () async {
      final gp = await makeStoryGame();
      await gp.processChoice(GameChoice(text: 'x', action: firstAction(gp)));
      final t = gp.worldState.time;
      expect(
        gp.worldState.month,
        GameTime.months[t.month - 1],
        reason: 'month 字符串必须跟着 time 走（fastForwardDays 内部同步）',
      );
      expect(gp.worldState.dayOfMonth, t.day);
    });

    test('回合收尾未丢：NPC/影响力/近期回合都在结算', () async {
      final gp = await makeStoryGame();
      await gp.processChoice(GameChoice(text: 'x', action: firstAction(gp)));
      expect(
        gp.recentTurns,
        isNotEmpty,
        reason: '近期回合必须落库（_finalizeTurn 共用）',
      );
    });
  });

  group('D · 效果落到玩家与记忆', () {
    test('选「先回房间拆信」→ 获得信物 + 情报 flag', () async {
      final gp = await makeStoryGame();
      final step = findStoryStep('ps', 'ps_ch1', 'ps_ch1_letter')!;
      final choice = step.choices.firstWhere((c) => c.id == 'read_in_room');

      await gp.processChoice(
        GameChoice(text: choice.text, action: encodeStoryAction(step.id, choice.id)),
      );

      expect(gp.storyProgress.flags, contains('ps_read_letter_first'));
      expect(gp.storyProgress.knowledge, contains('knows_hogwarts_acceptance'));
      expect(
        gp.player!.inventory.any((i) => i.name == '霍格沃茨的来信'),
        isTrue,
        reason: '道具应进背包（剧情白名单物品按中文名落库）',
      );
    });

    test('两回合累计的数值效果进 effects（供结局判定）', () async {
      final gp = await makeStoryGame();
      // 第一步选"直接问养父母"：spirit -3
      final s1 = findStoryStep('ps', 'ps_ch1', 'ps_ch1_letter')!;
      await gp.processChoice(
        GameChoice(
          text: 'x',
          action: encodeStoryAction(s1.id, 'ask_family'),
        ),
      );
      expect(gp.storyProgress.effects['spirit'], -3);
      final afterFirst = gp.storyProgress.effects['spirit']!;

      // 第二步选"把信摊开解释"：reputation +2 / spirit +8
      final s2 = findStoryStep('ps', 'ps_ch1', 'ps_ch1_tell')!;
      await gp.processChoice(
        GameChoice(
          text: 'x',
          action: encodeStoryAction(s2.id, 'tell_truth'),
        ),
      );
      expect(
        gp.storyProgress.effects['spirit'],
        afterFirst + 8,
        reason: '效果必须**累加**，否则结局判定会随剧情推进漂移',
      );
      expect(gp.storyProgress.effects['reputation'], 2);
      expect(gp.storyProgress.flags, contains('ps_family_supportive'));
    });

    test('获得情报时写进长期记忆的 T0 层（离线少有的沉淀机会）', () async {
      final gp = await makeStoryGame();
      final s1 = findStoryStep('ps', 'ps_ch1', 'ps_ch1_letter')!;
      await gp.processChoice(
        GameChoice(
          text: 'x',
          action: encodeStoryAction(s1.id, 'read_in_room'),
        ),
      );
      final facts = gp.memory.keyFacts.map((f) => f.id).toList();
      expect(
        facts,
        contains('story_knows_hogwarts_acceptance'),
        reason: '剧情情报必须沉淀到长期记忆，否则离线长局记忆全空转',
      );
    });
  });

  group('E · 健壮性（自由行动与失效分支）', () {
    test('自由输入不卡死：降级为自由行动并推进', () async {
      final gp = await makeStoryGame();
      final beforeStep = gp.storyProgress.stepId;

      await gp.processChoice(
        GameChoice(text: '四处看看', action: '四处看看'),
      );

      expect(
        gp.storyProgress.stepId,
        isNot(beforeStep),
        reason: '自由行动也要推进，否则玩家会卡在原地',
      );
      expect(gp.currentNarrative, contains('四处看看'));
      expect(gp.choices, isNotEmpty, reason: '推进后必须给出新选项');
    });

    test('伪造的分支 id 不崩，降级为自由行动', () async {
      final gp = await makeStoryGame();
      await gp.processChoice(
        GameChoice(
          text: 'x',
          action: encodeStoryAction('ps_ch1_letter', '不存在的分支'),
        ),
      );
      expect(gp.storyProgress.stepId, 'ps_ch1_tell');
      expect(gp.error, isNull);
    });

    test('stepId 对不上的旧 action 降级为自由行动（读档后 action 失效）', () async {
      final gp = await makeStoryGame();
      await gp.processChoice(
        GameChoice(
          text: 'x',
          // 故意用上一章的 stepId
          action: encodeStoryAction('ps_ch0_不存在', 'a'),
        ),
      );
      expect(gp.storyProgress.stepId, 'ps_ch1_tell');
      expect(gp.error, isNull);
    });

    test('剧情游标指向不存在的步时重置到首步，而不是卡死', () async {
      final gp = await makeStoryGame();
      gp.storyProgress = gp.storyProgress.copyWith(
        chapterId: 'ps_ch1',
        stepId: 'ps_ch1_已经删掉了',
      );
      await gp.processChoice(GameChoice(text: 'x', action: '随便走走'));
      expect(
        gp.storyProgress.stepId,
        isNot('ps_ch1_已经删掉了'),
        reason: '游标失效必须自愈',
      );
    });
  });

  group('F · 离线红线', () {
    test('整章跑完 apiCalls 仍为 0（全程 0 AI 调用）', () async {
      final gp = await makeStoryGame();
      for (var i = 0; i < 3 && gp.choices.isNotEmpty; i++) {
        await gp.processChoice(
          GameChoice(text: 'x', action: gp.choices.first.action),
        );
      }
      expect(gp.apiCalls, 0, reason: '剧情模式绝不能消耗 AI 额度');
      expect(gp.error, isNull);
    });
  });

  group('G · 沙盒路径不受影响', () {
    test('offlineQuickMode 但未进入剧情模式时，走的仍是沙盒兜底叙事', () async {
      // 不调 enterStoryModeForTest —— 这是"老存档/沙盒玩家"的路径
      SharedPreferences.setMockInitialValues({});
      final gp = await makeGame(offlineQuickMode: true);
      expect(gp.storyProgress.active, isFalse);

      await gp.processChoice(const GameChoice(text: '四处看看', action: '四处看看'));
      expect(gp.storyProgress.active, isFalse, reason: '沙盒模式不该被带进剧情');
      expect(gp.choices, isNotEmpty);
    });

    test('沙盒模式的选项不是剧情编码（两条路径互不污染）', () async {
      SharedPreferences.setMockInitialValues({});
      final gp = await makeGame(offlineQuickMode: true);
      await gp.processChoice(const GameChoice(text: '四处看看', action: '四处看看'));
      for (final c in gp.choices) {
        expect(
          isStoryAction(c.action),
          isFalse,
          reason: '沙盒选项不该带剧情编码：${c.action}',
        );
      }
    });
  });
}
