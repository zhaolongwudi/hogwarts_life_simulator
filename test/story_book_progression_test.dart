/// 跨书衔接引擎（批次 6：七部曲骨架 + 《密室》精做）测试。
///
/// 【这一层测什么】
///   1. 书表结构：书序环环相扣、只有实装书注册（骨架书防打穿）、锚点年份递进；
///   2. `beginBook` 工厂：养成资产（flags/effects/knowledge）跨部继承，
///      书内游标（doneSteps/chosen/endingId）换书即作废——"开新书"的语义核心；
///   3. 空书防御：PS 结局点「别过这一年」→ PoA 未实装 → 得到明确提示，
///      进度不崩、flag 去重不刷屏；
///   4. **PS→CoS 跨书 E2E**（本轮的核心验收线）：跑完整本《魔法石》→
///      结局选项点「向夏天走去」→ 快进到 1992 年夏 → 自动开启《密室》第一章，
///      继承的养成资产原样带过去，全程 0 AI 调用；
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

    test('已注册=可玩：只有 ps/cos 入册，骨架书不可查但可显示书名', () {
      expect(kStoryBooks.keys, containsAll(const ['ps', 'cos']));
      expect(
        kStoryBooks.keys,
        hasLength(2),
        reason: 'poa~dh 是骨架书，注册空书会让守卫测试与玩家点击打穿引擎',
      );
      for (final id in const ['poa', 'gof', 'ootp', 'hbp', 'dh']) {
        expect(findStoryBook(id), isNull, reason: '$id 未实装，查表必须为 null');
        expect(
          bookDisplayName(id),
          isNotEmpty,
          reason: '$id 的书名必须能显示（/状态 面板预告用）',
        );
      }
    });

    test('两部实装书的开篇锚点年份递进（七月暑假开局）', () {
      final ps = findStoryBook('ps')!;
      final cos = findStoryBook('cos')!;
      expect(ps.startYear, 1991);
      expect(cos.startYear, 1992);
      expect(cos.startAbsoluteDayIndex, greaterThan(ps.startAbsoluteDayIndex));
      // 锚点落在暑假：剧情从假期开始，开学前就把信送到位
      expect(ps.startMonth, 7);
      expect(cos.startMonth, 7);
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

  group('C · 空书防御（下一部未实装）', () {
    /// 跑完《魔法石》→ 衔接 → 跑完《密室》，到达"下一部是骨架书"的结局态。
    ///
    /// 【为什么这么绕】PS 的下一部（CoS）已实装，点按钮直接开新书；
    /// 空书防御要等玩家站在《密室》结局（下一部 PoA 未实装）才触发。
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

    test('CoS 结局点「向夏天走去」→ 明确提示 + 进度不崩（PoA 未实装）', () async {
      final gp = await playCosToEnd();
      expect(gp.choices.map((c) => c.action), contains(kStoryNextBookAction));

      await gp.processChoice(
        const GameChoice(text: 'x', action: kStoryNextBookAction),
      );

      expect(
        gp.notifications.join('\n'),
        contains('还没装载进当前版本'),
        reason: 'PoA 未实装，必须给出明确提示而不是静默失败',
      );
      expect(gp.storyProgress.isFinished, isTrue, reason: '结局态不得被破坏');
      expect(gp.storyProgress.bookId, 'cos');
      expect(gp.choices, isNotEmpty, reason: '点击后仍要回到结局三出口');
      // 骨架书没有锚点（findStoryBook(poa) == null → 不快进），时间停在 1993
      expect(gp.worldState.time.year, 1993);
    });

    test('连续两次点击不崩、不改变结局态', () async {
      final gp = await playCosToEnd();
      for (var i = 0; i < 2; i++) {
        await gp.processChoice(
          const GameChoice(text: 'x', action: kStoryNextBookAction),
        );
      }
      expect(gp.storyProgress.isFinished, isTrue);
      expect(gp.storyProgress.bookId, 'cos');
      expect(gp.choices.map((c) => c.action), contains(kStoryNextBookAction));
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
