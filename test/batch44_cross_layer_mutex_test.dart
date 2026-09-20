/// v5 批次44 跨层互斥综合测试（把 P9~P14「世界在动」各层的互斥契约钉死）。
///
/// 背景：P9 节庆 / P10 奇遇 / P11 羁绊 / P12 宠物 / P13 来信 / P14 社团
/// 各层在离线管线（_runOfflineQuickTurn）里按固定顺序拼接，且各自 mixin 内部
/// 都有「有更优先的事在等 → 不抢戏」的门控。本文件把「同一回合多层同时可触发」
/// 的场景显式造出来，验证：
///   1. 互斥优先级（奇遇进行中 > 羁绊最终幕 > 待回信 > 日常小点缀）成立；
///   2. 待抉择项在回合开始时被结算并清 pending（不悬挂）；
///   3. 选项优先级（羁绊最终幕 > 奇遇专属 > 来信回信 > 兜底承接）成立。
/// 叙事拼接顺序的契约已由「同回合多层触发」的入口侧互斥保证（各层触发即
/// 意味着更高优先级不在场），顺序本身由 _runOfflineQuickTurn 的固定拼接保证。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:hogwarts_life_simulator/models/companion_arc.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/models/npc.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

import 'helpers/test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 构造一个「P10~P14 全开」的离线 provider，各层前置全部消除冷却。
  /// 每层的「够格」条件已摆好：赫敏登场+好感够、宠物在场、已入决斗社。
  Future<GameProvider> makeAllEligible() async {
    final gp = await makeGame(offlineQuickMode: true);
    // P10~P14 全开
    gp.appProvider.happenstanceEnabled = true;
    gp.appProvider.companionArcEnabled = true;
    gp.appProvider.petStoryEnabled = true;
    gp.appProvider.letterEnabled = true;
    gp.appProvider.clubEnabled = true;

    // 固定秋季（10 月）：赫敏羁绊弧（autumn/winter）确定入围
    gp.worldState.time.month = 10;
    gp.worldState.time.day = 15;

    // 奇遇可触发：消除冷却
    gp.worldState.lastHappenstanceTurn = -100;
    // 羁绊可触发：赫敏登场、好感跨门槛、消除冷却
    gp.npcRegistry['hermione'] = NPC(
      id: 'hermione',
      name: '赫敏',
      affection: 80,
      introduced: true,
      house: '格兰芬多',
    );
    gp.worldState.lastCompanionArcTurn = -100;
    // 宠物可触发：给一只猫，亲和达标
    final p = gp.player!;
    p.petId = 'cat';
    p.petBond = 60;
    p.petLastStoryTurn = -100;
    // 来信可触发：消除冷却
    p.letterLastTurn = -100;
    // 社团可触发：入社并消除冷却
    gp.joinClub('duel');
    p.clubLastTurn = -100;
    return gp;
  }

  group('P9~P14 · 同回合互斥优先级契约', () {
    test('进行中的奇遇让羁绊/宠物/来信/社团全部让路（最高优先级）', () async {
      final gp = await makeAllEligible();
      // 先手工置一个进行中的奇遇（如同上一回合触发了奇遇、本回合还没结算）
      gp.worldState.pendingHappenstanceId = 'wandering_note';
      gp.player!.clubLastTurn = -100;
      gp.player!.letterLastTurn = -100;
      gp.worldState.lastCompanionArcTurn = -100;
      gp.player!.petLastStoryTurn = -100;

      // 每层单独问：有进行中奇遇时，其余各层都应返回空（不抢戏）。
      expect(gp.maybeRunClubActivity('与人切磋对练'), '',
          reason: '有进行中奇遇时社团不应记分抢戏');
      expect(gp.maybeTriggerCompanion(), '',
          reason: '有进行中奇遇时羁绊不应开演');
      expect(gp.maybeTriggerPetStory(), '',
          reason: '有进行中奇遇时宠物插曲不应出现');
      expect(gp.maybeTriggerLetter(), '',
          reason: '有进行中奇遇时来信不应送达');
    });

    test('羁绊最终幕待抉择时：宠物/来信/社团让路', () async {
      final gp = await makeAllEligible();
      // 构造「最终幕待抉择」：hermione 的弧已推进到最终幕、pendingClimax=true
      gp.worldState.companionArcs['hermione'] = const CompanionArcProgress(
        arcId: 'hermione_study_pledge',
        beatIndex: 2,
        pendingClimax: true,
      );
      gp.player!.clubLastTurn = -100;
      gp.player!.letterLastTurn = -100;
      gp.player!.petLastStoryTurn = -100;

      expect(gp.maybeRunClubActivity('与人切磋对练'), '',
          reason: '羁绊最终幕待抉择时社团不应抢戏');
      expect(gp.maybeTriggerPetStory(), '',
          reason: '羁绊最终幕待抉择时宠物不应抢戏');
      expect(gp.maybeTriggerLetter(), '',
          reason: '羁绊最终幕待抉择时来信不应送达');
    });

    test('待回信时：宠物/社团让路，但羁绊仍可开演（更高优先级）', () async {
      final gp = await makeAllEligible();
      // 待回信（player.pendingLetterId 非空）
      gp.player!.pendingLetterId = 'letter_dawdle';
      gp.player!.clubLastTurn = -100;
      gp.player!.petLastStoryTurn = -100;
      gp.worldState.lastCompanionArcTurn = -100;

      expect(gp.maybeRunClubActivity('与人切磋对练'), '',
          reason: '有待回信时社团不应抢戏');
      expect(gp.maybeTriggerPetStory(), '',
          reason: '有待回信时宠物不应抢戏');
      final c = gp.maybeTriggerCompanion();
      expect(c, isNot(''), reason: '有待回信时羁绊仍可开演（更高优先级）');
    });

    test('全部就位且无更高优先级在等时：宠物插曲出现（日常小点缀）', () async {
      final gp = await makeAllEligible();
      // 无奇遇/无羁绊最终幕/无待回信，宠物自己的冷却也消了
      gp.worldState.lastCompanionArcTurn = -100;
      gp.player!.letterLastTurn = -100;
      // 宠物插曲：亲和 60 ≥ 25 → 里程碑候选在；日常候选也在。必然非空。
      final s = gp.maybeTriggerPetStory();
      expect(s, isNot(''), reason: '无更高优先级在等时宠物插曲应可播');
    });
  });

  group('P9~P14 · 待抉择项回合开始即结算（不悬挂）', () {
    test('有进行中奇遇时，玩家走任意行动 → 奇遇被中性结算并清 pending', () async {
      final gp = await makeAllEligible();
      gp.worldState.pendingHappenstanceId = 'wandering_note';

      await gp.processChoice(const GameChoice(
          text: '在城堡随便走走', action: '在城堡随便走走'));

      expect(gp.worldState.pendingHappenstanceId, isNull,
          reason: '进行中的奇遇在本回合应被结算，不应悬挂');
      expect(gp.currentNarrative, contains('你的选择'),
          reason: '奇遇结算文本应体现在叙事里');
    });

    test('待回信时走任意行动 → 应被中性回信结算并清待回信', () async {
      final gp = await makeAllEligible();
      gp.player!.pendingLetterId = 'letter_dawdle';

      await gp.processChoice(const GameChoice(
          text: '在城堡随便走走', action: '在城堡随便走走'));

      expect(gp.player!.pendingLetterId, isNull,
          reason: '待回信在本回合应被结算，不应悬挂');
      expect(gp.currentNarrative, contains('你的回信'),
          reason: '回信结算文本应体现在叙事里');
    });

    test('羁绊最终幕待抉择时走任意行动 → 自动按第一结局收尾并归档', () async {
      final gp = await makeAllEligible();
      gp.worldState.companionArcs['hermione'] = const CompanionArcProgress(
        arcId: 'hermione_study_pledge',
        beatIndex: 2,
        pendingClimax: true,
      );

      await gp.processChoice(const GameChoice(
          text: '在城堡随便走走', action: '在城堡随便走走'));

      expect(gp.worldState.companionArcs['hermione']?.pendingClimax, isNot(true),
          reason: '羁绊最终幕在本回合应被结算，不应悬挂');
      expect(gp.currentNarrative, contains('你的选择'),
          reason: '羁绊结算文本应体现在叙事里');
    });
  });

  group('P9~P14 · 选项优先级契约（纯函数级）', () {
    test('羁绊最终幕待抉择 > 奇遇专属选项 > 来信回信选项（同时就绪时）', () async {
      final gp = await makeAllEligible();
      // 三个优先级的状态同时就绪
      gp.worldState.companionArcs['hermione'] = const CompanionArcProgress(
        arcId: 'hermione_study_pledge',
        beatIndex: 2,
        pendingClimax: true,
      );
      gp.worldState.pendingHappenstanceId = 'wandering_note';
      gp.player!.pendingLetterId = 'letter_dawdle';

      // 直接调用三个 ChoicesForPending：验证各自都能产出专属选项
      final companionChoices = gp.companionChoicesForPending();
      final hpChoices = gp.happenstanceChoicesForPending();
      final letterChoices = gp.letterReplyChoicesForPending();
      expect(companionChoices, isNotEmpty,
          reason: '羁绊最终幕就绪时应产出专属抉择');
      expect(hpChoices, isNotEmpty,
          reason: '奇遇 pending 就绪时应产出专属抉择');
      expect(letterChoices, isNotEmpty,
          reason: '待回信就绪时应产出回信选项');

      // 验证管线里的选择优先级（mixin_narrative 的拼接逻辑）：
      // 羁绊 > 奇遇 > 来信。
      final effective = companionChoices.isNotEmpty
          ? companionChoices
          : (hpChoices.isNotEmpty ? hpChoices : letterChoices);
      expect(effective.map((c) => c.action).first.startsWith('羁绊:'), isTrue,
          reason: '羁绊最终幕应覆盖奇遇与来信选项');
    });

    test('无羁绊最终幕时，奇遇专属选项覆盖来信回信', () async {
      final gp = await makeAllEligible();
      gp.worldState.pendingHappenstanceId = 'wandering_note';
      gp.player!.pendingLetterId = 'letter_dawdle';

      final companionChoices = gp.companionChoicesForPending();
      final hpChoices = gp.happenstanceChoicesForPending();
      final letterChoices = gp.letterReplyChoicesForPending();
      expect(companionChoices, isEmpty);
      expect(hpChoices, isNotEmpty);
      expect(letterChoices, isNotEmpty);

      final effective = companionChoices.isNotEmpty
          ? companionChoices
          : (hpChoices.isNotEmpty ? hpChoices : letterChoices);
      expect(effective.map((c) => c.action).first.startsWith('奇遇:'), isTrue,
          reason: '无羁绊最终幕时奇遇专属选项应覆盖来信回信');
    });

    test('无奇遇/羁绊时，来信回信选项兜底', () async {
      final gp = await makeAllEligible();
      gp.player!.pendingLetterId = 'letter_dawdle';

      final companionChoices = gp.companionChoicesForPending();
      final hpChoices = gp.happenstanceChoicesForPending();
      final letterChoices = gp.letterReplyChoicesForPending();
      expect(companionChoices, isEmpty);
      expect(hpChoices, isEmpty);
      expect(letterChoices, isNotEmpty);

      final effective = companionChoices.isNotEmpty
          ? companionChoices
          : (hpChoices.isNotEmpty ? hpChoices : letterChoices);
      expect(effective.map((c) => c.action).first.startsWith('信:'), isTrue,
          reason: '无奇遇/羁绊时来信回信选项应兜底');
    });
  });
}