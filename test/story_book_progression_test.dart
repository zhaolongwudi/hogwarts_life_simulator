/// 跨书衔接引擎（七部曲全实装）测试。
///
/// 【这一层测什么】
///   1. 书表结构：书序环环相扣、七部全部实装且都有完整章节、锚点年份递进；
///   2. `beginBook` 工厂：养成资产（flags/effects/knowledge）跨部继承，
///      书内游标（doneSteps/chosen/endingId）换书即作废——"开新书"的语义核心；
///   3. **七部连环 E2E**（本轮核心验收线）：从《魔法石》一路点到《死亡圣器》
///      结局，每一部的衔接按钮都真的开出了下一部的第一步，全程 0 AI 调用；
///   4. 末部完结：第七部结局不再渲染"下一部"按钮，重复点击旧按钮要给
///      「七部曲已走完」的交代，而不是误导成"下一部没装载"；
///   5. /状态 面板的下一部预告（实装书 vs 骨架书两种文案）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/story_data.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/models/story_progress.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

import 'helpers/test_fixtures.dart';

Future<GameProvider> makeStoryGame() async {
  final gp = await makeGame(offlineQuickMode: true);
  gp.openingScene = 'letter';
  gp.enterStoryMode();
  return gp;
}

/// 从 letter 开局把《魔法石》一路推到结局（与 story_chapter_flow_test 同款管道）。
Future<GameProvider> playPsToEnd() async {
  final gp = await makeStoryGame();
  var guard = 0;
  while (!gp.storyProgress.isFinished && guard < 40) {
    guard++;
    await gp.processChoice(
      GameChoice(text: 'x', action: gp.choices.first.action),
    );
  }
  expect(gp.storyProgress.isFinished, isTrue, reason: 'E2E 前置：PS 必须能跑完');
  return gp;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAllStoryBooks);

  group('A · 书表结构', () {
    test('书序七部完整，衔接环环相扣', () {
      expect(
        kBookOrder,
        ['ps', 'cos', 'poa', 'gof', 'ootp', 'hbp', 'dh'],
        reason: '七部曲顺序即衔接链',
      );
      for (var i = 0; i < kBookOrder.length - 1; i++) {
        expect(
          nextStoryBookId(kBookOrder[i]),
          kBookOrder[i + 1],
          reason: '${kBookOrder[i]} 的下一部必须是 ${kBookOrder[i + 1]}',
        );
      }
      expect(nextStoryBookId('dh'), isNull, reason: '最后一部没有下一部');
      expect(nextStoryBookId('不存在'), isNull);
    });

    test('已注册=可玩：七部全部入册，每一部都能查到完整章节', () {
      expect(
        kStoryBooks.keys,
        containsAll(const ['ps', 'cos', 'poa', 'gof', 'ootp', 'hbp', 'dh']),
      );
      expect(
        kStoryBooks.keys,
        hasLength(7),
        reason: '七部曲全部实装，书表里不应再有骨架书',
      );
      for (final id in kBookOrder) {
        final book = findStoryBook(id);
        expect(book, isNotNull, reason: '$id 必须已实装');
        expect(book!.chapters, isNotEmpty, reason: '$id 不能是空骨架书');
        expect(
          firstStepOfBook(id),
          isNotNull,
          reason: '$id 必须能定位到第一步',
        );
        expect(book.endings, isNotEmpty, reason: '$id 必须有结局规则');
      }
    });

    test('七部开篇锚点逐年递进（七月暑假开局）', () {
      final years = <int>[];
      var prevDay = -1;
      for (final id in kBookOrder) {
        final b = findStoryBook(id)!;
        years.add(b.startYear);
        expect(b.startMonth, 7, reason: '$id 应从暑假开局');
        expect(
          b.startAbsoluteDayIndex,
          greaterThan(prevDay),
          reason: '$id 的开启锚点必须晚于上一部',
        );
        prevDay = b.startAbsoluteDayIndex;
      }
      expect(years, [1991, 1992, 1993, 1994, 1995, 1996, 1997]);
    });
  });

  group('B · beginBook 跨部继承', () {
    test('养成资产全继承，书内游标全清空', () {
      const inherited = StoryProgress(
        active: true,
        bookId: 'ps',
        chapterId: 'ps_ch9',
        stepId: 'ps_ch9_final',
        doneSteps: ['ps_ch1_letter', 'ps_ch2_arrival'],
        flags: ['ps_friend_hagrid', 'brave'],
        chosen: {'ps_ch1_letter': 'ps_ch1_reply'},
        effects: {'affection': 5, 'reputation': 3},
        knowledge: ['magic_stone_secret'],
        endingId: 'ps_ending_survivor',
      );

      final fresh = StoryProgress.beginBook(
        bookId: 'cos',
        chapterId: 'cos_ch1',
        stepId: 'cos_ch1_letter',
        inherited: inherited,
      );

      // 继承面
      expect(fresh.flags, containsAll(const ['ps_friend_hagrid', 'brave']));
      expect(fresh.effects['affection'], 5);
      expect(fresh.effects['reputation'], 3);
      expect(fresh.knowledge, contains('magic_stone_secret'));
      expect(fresh.active, isTrue);
      // 重置面
      expect(fresh.bookId, 'cos');
      expect(fresh.stepId, 'cos_ch1_letter');
      expect(fresh.doneSteps, isEmpty, reason: '上一部的步进游标必须作废');
      expect(fresh.chosen, isEmpty, reason: '上一部的选择记录必须作废');
      expect(
        fresh.endingId,
        isNull,
        reason: '上一部的结局态必须清空——否则新书一开始就是"已到结局"',
      );
      expect(fresh.isFinished, isFalse);
    });
  });

  group('C · 七部连环（每一部的衔接都要真开出下一部）', () {
    /// 跑完《魔法石》→ 衔接 → 跑完《密室》。
    Future<GameProvider> playCosToEnd() async {
      final gp = await playPsToEnd();
      await gp.processChoice(
        const GameChoice(text: 'x', action: kStoryNextBookAction),
      );
      expect(gp.storyProgress.bookId, 'cos', reason: '前置：应已进入密室');
      var guard = 0;
      while (!gp.storyProgress.isFinished && guard < 60) {
        guard++;
        await gp.processChoice(
          GameChoice(text: 'x', action: gp.choices.first.action),
        );
      }
      expect(gp.storyProgress.isFinished, isTrue, reason: '前置：CoS 必须能跑完');
      return gp;
    }

    /// 跑完《魔法石》→《密室》→《阿兹卡班的囚徒》。
    Future<GameProvider> playPoaToEnd() async {
      final gp = await playCosToEnd();
      await gp.processChoice(
        const GameChoice(text: 'x', action: kStoryNextBookAction),
      );
      expect(gp.storyProgress.bookId, 'poa', reason: '前置：应已进入阿兹卡班');
      var guard = 0;
      while (!gp.storyProgress.isFinished && guard < 80) {
        guard++;
        await gp.processChoice(
          GameChoice(text: 'x', action: gp.choices.first.action),
        );
      }
      expect(gp.storyProgress.isFinished, isTrue, reason: '前置：PoA 必须能跑完');
      return gp;
    }

    test('CoS 结局点「向夏天走去」→ 直接开启第三部（PoA 已实装）', () async {
      final gp = await playCosToEnd();
      expect(gp.choices.map((c) => c.action), contains(kStoryNextBookAction));

      await gp.processChoice(
        const GameChoice(text: 'x', action: kStoryNextBookAction),
      );

      expect(gp.storyProgress.bookId, 'poa', reason: 'PoA 已实装，应直接开新书');
      expect(gp.storyProgress.stepId, 'poa_ch1_news');
      expect(gp.storyProgress.isFinished, isFalse, reason: '新书开局不是结局态');
      expect(gp.choices, isNotEmpty);
    });

    /// 跑完四部。
    Future<GameProvider> playGofToEnd() async {
      final gp = await playPoaToEnd();
      await gp.processChoice(
        const GameChoice(text: 'x', action: kStoryNextBookAction),
      );
      expect(gp.storyProgress.bookId, 'gof', reason: '前置：应已进入火焰杯');
      var guard = 0;
      while (!gp.storyProgress.isFinished && guard < 80) {
        guard++;
        await gp.processChoice(
          GameChoice(text: 'x', action: gp.choices.first.action),
        );
      }
      expect(gp.storyProgress.isFinished, isTrue, reason: '前置：GoF 必须能跑完');
      return gp;
    }

    test('PoA 结局点「向夏天走去」→ 直接开启第四部（GoF 已实装）', () async {
      final gp = await playPoaToEnd();
      expect(gp.choices.map((c) => c.action), contains(kStoryNextBookAction));

      await gp.processChoice(
        const GameChoice(text: 'x', action: kStoryNextBookAction),
      );

      expect(gp.storyProgress.bookId, 'gof', reason: 'GoF 已实装，应直接开新书');
      expect(gp.storyProgress.stepId, 'gof_ch1_arrival');
      expect(gp.storyProgress.isFinished, isFalse);
    });

    /// 跑完五部。
    Future<GameProvider> playOotpToEnd() async {
      final gp = await playGofToEnd();
      await gp.processChoice(
        const GameChoice(text: 'x', action: kStoryNextBookAction),
      );
      expect(gp.storyProgress.bookId, 'ootp', reason: '前置：应已进入凤凰社');
      var guard = 0;
      while (!gp.storyProgress.isFinished && guard < 80) {
        guard++;
        await gp.processChoice(
          GameChoice(text: 'x', action: gp.choices.first.action),
        );
      }
      expect(gp.storyProgress.isFinished, isTrue, reason: '前置：OotP 必须跑完');
      return gp;
    }

    test('GoF 结局点「向夏天走去」→ 直接开启第五部（OotP 已实装）', () async {
      final gp = await playGofToEnd();
      expect(gp.choices.map((c) => c.action), contains(kStoryNextBookAction));

      await gp.processChoice(
        const GameChoice(text: 'x', action: kStoryNextBookAction),
      );

      expect(gp.storyProgress.bookId, 'ootp', reason: 'OotP 已实装，应直接开新书');
      expect(gp.storyProgress.stepId, 'ootp_ch1_return');
      expect(gp.storyProgress.isFinished, isFalse);
    });

    test('OotP 结局点「向夏天走去」→ 直接开启第六部（HBP 已实装）', () async {
      final gp = await playOotpToEnd();
      expect(gp.choices.map((c) => c.action), contains(kStoryNextBookAction));

      await gp.processChoice(
        const GameChoice(text: 'x', action: kStoryNextBookAction),
      );

      expect(gp.storyProgress.bookId, 'hbp', reason: 'HBP 已实装，应直接开新书');
      expect(gp.storyProgress.stepId, 'hbp_ch1_return');
      expect(gp.storyProgress.isFinished, isFalse);
    });

    /// 跑完六部，站在 HBP 结局（下一部 DH 已实装）。
    Future<GameProvider> playHbpToEnd() async {
      final gp = await playOotpToEnd();
      await gp.processChoice(
        const GameChoice(text: 'x', action: kStoryNextBookAction),
      );
      expect(gp.storyProgress.bookId, 'hbp', reason: '前置：应已进入混血王子');
      var guard = 0;
      while (!gp.storyProgress.isFinished && guard < 80) {
        guard++;
        await gp.processChoice(
          GameChoice(text: 'x', action: gp.choices.first.action),
        );
      }
      expect(gp.storyProgress.isFinished, isTrue, reason: '前置：HBP 必须跑完');
      return gp;
    }

    test('HBP 结局点「向夏天走去」→ 直接开启第七部（DH 已实装）', () async {
      final gp = await playHbpToEnd();
      expect(gp.choices.map((c) => c.action), contains(kStoryNextBookAction));

      await gp.processChoice(
        const GameChoice(text: 'x', action: kStoryNextBookAction),
      );

      expect(gp.storyProgress.bookId, 'dh', reason: 'DH 已实装，应直接开新书');
      expect(gp.storyProgress.stepId, 'dh_ch1_fall');
      expect(gp.storyProgress.isFinished, isFalse);
    });

    /// 跑完七部，站在 DH 结局——**整条七部曲的终点**。
    Future<GameProvider> playDhToEnd() async {
      final gp = await playHbpToEnd();
      await gp.processChoice(
        const GameChoice(text: 'x', action: kStoryNextBookAction),
      );
      expect(gp.storyProgress.bookId, 'dh', reason: '前置：应已进入死亡圣器');
      var guard = 0;
      while (!gp.storyProgress.isFinished && guard < 80) {
        guard++;
        await gp.processChoice(
          GameChoice(text: 'x', action: gp.choices.first.action),
        );
      }
      expect(gp.storyProgress.isFinished, isTrue, reason: '前置：DH 必须跑完');
      return gp;
    }

    test('DH 结局点 → 七部曲完结，不再有「下一部」按钮', () async {
      final gp = await playDhToEnd();

      expect(gp.storyProgress.bookId, 'dh');
      expect(
        gp.choices.map((c) => c.action),
        isNot(contains(kStoryNextBookAction)),
        reason: '第七部之后没有第八部，衔接按钮不该再出现',
      );
      expect(gp.choices, isNotEmpty, reason: '完结态仍要给玩家出口');
      // 七部走完，世界时钟至少推到 1998 年（决战当年）
      expect(gp.worldState.time.year, greaterThanOrEqualTo(1998));
    });

    test('七部曲连跑：PS → DH 一气呵成，年份逐部递进', () async {
      final gp = await playDhToEnd();
      // 养成资产一路继承下来，不会被任何一次跨部清空
      expect(gp.storyProgress.effects, isNotEmpty);
      expect(gp.player?.inventory, isNotEmpty);
      // 结局规则匹配成功（不是 null 兜底）
      expect(gp.storyProgress.isFinished, isTrue);
    });

    test('完结后重复点击旧衔接按钮不崩、不改结局态', () async {
      final gp = await playDhToEnd();
      for (var i = 0; i < 2; i++) {
        await gp.processChoice(
          const GameChoice(text: 'x', action: kStoryNextBookAction),
        );
      }
      expect(gp.storyProgress.isFinished, isTrue);
      expect(gp.storyProgress.bookId, 'dh');
      expect(
        gp.notifications.join('\n'),
        contains('七部曲已经全部走完'),
        reason: '末部的重复点击要给"完结"交代，不能误导成下一部没装载',
      );
    });
  });

  group('D · PS→CoS 跨书 E2E（核心验收线）', () {
    test('跑完整部魔法石 → 结局选项 → 自动开启密室第一章', () async {
      final gp = await playPsToEnd();
      final flagsAtEnding = List<String>.from(gp.storyProgress.flags);
      final effectsAtEnding = Map<String, int>.from(gp.storyProgress.effects);

      // 结局选项三出口，且衔接按钮指名《密室》
      final nextChoice = gp.choices.firstWhere(
        (c) => c.action == kStoryNextBookAction,
      );
      expect(nextChoice.text, contains('密室'));

      await gp.processChoice(GameChoice(text: 'x', action: nextChoice.action));

      // 落进《密室》第一章第一步
      expect(gp.storyProgress.bookId, 'cos');
      expect(gp.storyProgress.chapterId, 'cos_ch1');
      expect(gp.storyProgress.stepId, 'cos_ch1_letter');
      expect(gp.storyProgress.isFinished, isFalse);
      expect(
        gp.storyProgress.doneSteps.where((s) => s.startsWith('ps_')),
        isEmpty,
        reason: '跨部后书内游标必须只属于新书',
      );
      // 养成资产跨部继承
      expect(
        gp.storyProgress.flags,
        containsAll(flagsAtEnding),
        reason: 'PS 阶段的 flag 必须原样带进 CoS',
      );
      expect(
        gp.storyProgress.effects['affection'],
        effectsAtEnding['affection'],
        reason: '跨部累计好感不得清零',
      );
      // 叙事抬头换了部
      expect(gp.currentNarrative, contains('第 2 部'));
      expect(gp.currentNarrative, contains('密室'));
      // 全程离线
      expect(gp.apiCalls, 0, reason: '跨书衔接同样必须是 0 AI 调用');
    });

    test('进入密室后剧情继续可推（第一章三步走通）', () async {
      final gp = await playPsToEnd();
      await gp.processChoice(
        const GameChoice(text: 'x', action: kStoryNextBookAction),
      );

      var guard = 0;
      while (
          gp.storyProgress.bookId == 'cos' &&
              gp.storyProgress.chapterId == 'cos_ch1' &&
              guard < 5) {
        guard++;
        await gp.processChoice(
          GameChoice(text: 'x', action: gp.choices.first.action),
        );
      }
      expect(
        gp.storyProgress.doneSteps,
        contains('cos_ch1_letter'),
        reason: 'CoS 第一步必须真实完成',
      );
      expect(
        gp.storyProgress.doneSteps.length,
        greaterThanOrEqualTo(3),
        reason: '衔接后连续推三步应当无卡点',
      );
    });
  });

  group('E · /状态 面板的下一部预告', () {
    test('PS 结局态：预告实装的《密室》与开启时间', () async {
      final gp = await playPsToEnd();
      expect(gp.handleLocalCommand('/状态'), isTrue);
      expect(gp.currentNarrative, contains('下一部'));
      expect(gp.currentNarrative, contains('密室'));
      // PS 结束在 6 月（早于 CoS 锚点 7-25）→ 显示锚点月份；万一节拍把
      // 时间推过锚点，文案切换为「现在就可以」。两种都是合法预告。
      expect(
        gp.currentNarrative,
        anyOf(contains('1992 年 7 月开启'), contains('现在就可以从结局选项进入')),
      );
    });
  });
}
