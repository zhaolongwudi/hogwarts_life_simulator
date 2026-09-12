/// 剧情模式的跨章推进与全书 E2E 测试。
///
/// 【为什么需要单独一个文件】批次 2 建立剧情引擎时全书只有一章，
/// 「跑完一章进下一章」的路径（`_finishStory` 的换章分支）从未被执行过；
/// 「一路玩到结局」的 26 步长管道同样没被压测过。内容填充到 9 章之后，
/// 这两条路径第一次成为**必经之路**——必须有测试钉死。
///
/// 【测什么】
///   1. 章末顺延：一章的最后一步选完，自动进入下一章首步，抬头换新章名；
///   2. 全书 E2E：从第一章开始反复点第一个选项，26 步全部完成后
///      判定出结局——这是"《魔法石》完整可玩"的验收线；
///   3. 跳章开局 E2E：station 开局（9 月）跳过暑假两章，同样能走到结局；
///   4. 离线红线：整本书跑完，AI 调用必须是 0。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/story_data.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/models/story_progress.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

import 'helpers/test_fixtures.dart';

/// letter 开局（从第一章收信开始）的剧情模式夹具。
Future<GameProvider> makeStoryGame() async {
  final gp = await makeGame(offlineQuickMode: true);
  gp.openingScene = 'letter';
  gp.enterStoryMode();
  return gp;
}

/// 全书 9 章的章名（换章抬头必须全部出现过）。
const _chapterTitles = [
  '女贞路的信',
  '对角巷与古灵阁',
  '九又四分之三站台',
  '分院帽',
  '城堡的第一课',
  '万圣节的巨怪',
  '冬天的城堡',
  '禁林与独角兽',
  '活板门之下',
];

/// 《魔法石》全部步 id（E2E 完成度断言用）。
Set<String> allPsStepIds() => {
  for (final ch in findStoryBook('ps')!.chapters)
    for (final s in ch.steps) s.id,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAllStoryBooks);

  group('A · 章与章的推进（批次 2 没覆盖的换章分支）', () {
    test('跑完第一章三步 → 自动进入第二章首步', () async {
      final gp = await makeStoryGame();

      for (var i = 0; i < 3; i++) {
        expect(
          gp.storyProgress.chapterId,
          'ps_ch1',
          reason: '第 ${i + 1} 次选择前应该还在第一章',
        );
        await gp.processChoice(
          GameChoice(text: 'x', action: gp.choices.first.action),
        );
      }

      expect(gp.storyProgress.chapterId, 'ps_ch2');
      expect(gp.storyProgress.stepId, 'ps_ch2_arrival');
      expect(
        gp.storyProgress.doneSteps,
        containsAll(const ['ps_ch1_letter', 'ps_ch1_tell', 'ps_ch1_reply']),
      );
    });

    test('换章叙事带新章的抬头与过场', () async {
      final gp = await makeStoryGame();
      for (var i = 0; i < 3; i++) {
        await gp.processChoice(
          GameChoice(text: 'x', action: gp.choices.first.action),
        );
      }
      expect(gp.currentNarrative, contains('第 2 章'));
      expect(gp.currentNarrative, contains('对角巷与古灵阁'));
    });

    test('换章后选项重新指向新步', () async {
      final gp = await makeStoryGame();
      for (var i = 0; i < 3; i++) {
        await gp.processChoice(
          GameChoice(text: 'x', action: gp.choices.first.action),
        );
      }
      expect(gp.choices, isNotEmpty);
      for (final c in gp.choices) {
        final cmd = parseStoryCommand(c.action);
        expect(cmd, isNotNull);
        expect(cmd!.stepId, 'ps_ch2_arrival');
      }
    });
  });

  group('B · 全书 E2E：从第一封信到学年结束', () {
    test('letter 开局：26 步全部完成 → 判定出结局', () async {
      final gp = await makeStoryGame();
      final seenNarratives = <String>[];

      var guard = 0;
      while (!gp.storyProgress.isFinished && guard < 40) {
        guard++;
        final action = gp.choices.first.action;
        expect(
          parseStoryCommand(action),
          isNotNull,
          reason: '第 $guard 回合的选项不是剧情指令：$action',
        );
        await gp.processChoice(GameChoice(text: 'x', action: action));
        seenNarratives.add(gp.currentNarrative);
      }

      expect(gp.storyProgress.isFinished, isTrue, reason: '26 步后必须到结局');
      expect(
        gp.storyProgress.endingId,
        startsWith('ps_ending_'),
        reason: '结局 id 必须来自书表的规则表',
      );
      expect(
        gp.storyProgress.doneSteps.toSet(),
        allPsStepIds(),
        reason: 'E2E 应该把全书 26 步全部完成',
      );
      expect(
        gp.storyProgress.chosen,
        hasLength(allPsStepIds().length),
        reason: '每一步的选择都应该被记录',
      );

      // 换章抬头的完整性：9 个章名全部在历史回合里出现过。
      final history = seenNarratives.join('\n');
      for (final title in _chapterTitles) {
        expect(
          history.contains(title),
          isTrue,
          reason: '整本书跑完却没见过章「$title」的抬头',
        );
      }

      // 效果确实累计了（结局判定的数据基础）
      expect(
        gp.storyProgress.effects['spirit'],
        isNotNull,
        reason: '整本书跑完 effects 里必须有精神变化',
      );
    });

    test('整本书跑完 AI 调用为 0（离线红线的全书压测）', () async {
      final gp = await makeStoryGame();
      var guard = 0;
      while (!gp.storyProgress.isFinished && guard < 40) {
        guard++;
        await gp.processChoice(
          GameChoice(text: 'x', action: gp.choices.first.action),
        );
      }
      expect(gp.apiCalls, 0, reason: '剧情模式全程 0 AI 调用——整本书也一样');
    });

    test('好感管线在长跑中被真实走到（E2E 路径累计好感为正）', () async {
      final gp = await makeStoryGame();
      var guard = 0;
      while (!gp.storyProgress.isFinished && guard < 40) {
        guard++;
        await gp.processChoice(
          GameChoice(text: 'x', action: gp.choices.first.action),
        );
      }
      expect(
        gp.storyProgress.totalAffection,
        greaterThan(0),
        reason: 'E2E 第一选项路径会帮纳威/分享零食/陪海格——好感必须落库',
      );
    });
  });

  group('C · 跳章开局 E2E', () {
    test('station 开局（9 月）跳过暑假两章，同样能走到结局', () async {
      final gp = await makeGame(offlineQuickMode: true);
      gp.openingScene = 'station';
      gp.enterStoryMode();
      expect(gp.storyProgress.stepId, 'ps_ch3_platform');

      var guard = 0;
      while (!gp.storyProgress.isFinished && guard < 40) {
        guard++;
        await gp.processChoice(
          GameChoice(text: 'x', action: gp.choices.first.action),
        );
      }

      expect(gp.storyProgress.isFinished, isTrue);
      expect(
        gp.storyProgress.doneSteps,
        isNot(contains('ps_ch1_letter')),
        reason: 'station 开局不该回头补 7 月的信',
      );
      expect(
        gp.storyProgress.doneSteps,
        isNot(contains('ps_ch2_arrival')),
      );
    });

    test('eve 开局直接从分院夜开始', () async {
      final gp = await makeGame(offlineQuickMode: true);
      gp.openingScene = 'eve';
      gp.enterStoryMode();
      expect(gp.storyProgress.stepId, 'ps_ch4_sorting');
      expect(gp.storyProgress.chapterId, 'ps_ch4');
      expect(gp.currentNarrative, contains('分院帽'));
      // 跳章开局同样是 0 AI
      expect(gp.apiCalls, 0);
    });
  });

  group('D · 结局之后', () {
    test('结局后继续选「自由活动」不崩、不重新触发剧情', () async {
      final gp = await makeStoryGame();
      var guard = 0;
      while (!gp.storyProgress.isFinished && guard < 40) {
        guard++;
        await gp.processChoice(
          GameChoice(text: 'x', action: gp.choices.first.action),
        );
      }

      await gp.processChoice(
        const GameChoice(text: '在城堡里四处走走', action: '在城堡里四处走走'),
      );
      expect(gp.storyProgress.isFinished, isTrue);
      expect(
        gp.storyProgress.endingId,
        isNotNull,
        reason: '结局后的自由行动不得清空结局状态',
      );
      expect(gp.choices, isNotEmpty);
    });
  });

  group('E · 进度面板（/状态 里的主线剧情块）', () {
    test('跑进第二章后，/状态 显示书名、当前章与步数进度', () async {
      final gp = await makeStoryGame();
      // 4 次选择：走完第一章 3 步 + 第二章首步 → 游标落在 ps_ch2_bank
      for (var i = 0; i < 4; i++) {
        await gp.processChoice(
          GameChoice(text: 'x', action: gp.choices.first.action),
        );
      }
      expect(gp.storyProgress.chapterId, 'ps_ch2');
      expect(gp.storyProgress.doneSteps, hasLength(4));

      final ok = gp.handleLocalCommand('/状态');
      expect(ok, isTrue, reason: '/状态 命令必须正常执行');
      expect(gp.currentNarrative, contains('主线剧情'));
      expect(gp.currentNarrative, contains('魔法石'));
      expect(gp.currentNarrative, contains('第 2 章'));
      expect(gp.currentNarrative, contains('对角巷与古灵阁'));
      expect(
        gp.currentNarrative.contains('已走 4/26 步'),
        isTrue,
        reason: '进度必须反映真实步数：${gp.currentNarrative}',
      );
    });

    test('非剧情模式的 /状态 不出现主线剧情块', () async {
      final gp = await makeGame(offlineQuickMode: true);
      final ok = gp.handleLocalCommand('/状态');
      expect(ok, isTrue);
      expect(
        gp.currentNarrative.contains('主线剧情'),
        isFalse,
        reason: '沙盒模式不该看到剧情进度面板',
      );
    });
  });
}
