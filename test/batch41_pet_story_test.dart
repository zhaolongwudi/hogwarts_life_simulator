/// v5 批次41 宠物小插曲测试（P12 宠物在离线日常里偶尔有自己的生活）。
///
/// 现状：宠物只在玩家主动 `/宠物 喂食/玩耍/训练` 时存在；本层让宠物在离线的日常里
/// 偶尔冒出来一下——日常小插曲（门槛低、会重播）+ 羁绊里程碑（亲和跨 25/55/85 各演
/// 一次、演过不重播）。它是被动的一层小点缀（不结算回合、无玩家抉择），和奇遇/羁绊
/// 一起把「世界在动」补得更丰满。
///
/// 覆盖：
///  - 数据完整性：id 唯一、日常/里程碑都够、里程碑有实质羁绊奖励、占位符替换无残留；
///  - 门控过滤：没有宠物不演、开关关不演、亲和不足不入里程碑候选、演过的不再入选；
///  - 触发逻辑：冷却内不触发、有进行中奇遇/羁绊终幕时不抢戏；
///  - 里程碑：亲和达标先演最高未播里程碑、奖励正确到账、演过不重播；
///  - 日常：无里程碑达标时走日常小插曲并给一点点羁绊；
///  - 离线回合接入：离线回合叙事出现宠物小插曲；
///  - 存档序列化：petLastStoryTurn / petStoriesPlayed 读写往返一致。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:hogwarts_life_simulator/data/pet_story_data.dart';
import 'package:hogwarts_life_simulator/models/companion_arc.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/models/player.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

import 'helpers/test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 构造**开着宠物插曲、关着奇遇/羁绊**的离线 provider，并让玩家养一只雪鸮。
  Future<GameProvider> makeEnabled() async {
    final gp = await makeGame(offlineQuickMode: true);
    gp.appProvider.petStoryEnabled = true;
    gp.appProvider.happenstanceEnabled = false; // 奇遇隔离
    gp.appProvider.companionArcEnabled = false; // 羁绊隔离
    final p = gp.player!;
    p.petId = 'owl';
    p.petName = '雪鸮';
    // 消除冷却：让第一回合即可触发
    p.petLastStoryTurn = -100;
    return gp;
  }

  group('P12 · 数据完整性', () {
    test('id 唯一、日常/里程碑都够、里程碑有实质奖励、占位符无残留', () {
      final ids = kPetStories.map((s) => s.id).toSet();
      expect(ids.length, kPetStories.length, reason: '插曲 id 必须全局唯一');
      final routine = kPetStories.where((s) => !s.milestone).length;
      final milestone = kPetStories.where((s) => s.milestone).length;
      expect(routine, greaterThanOrEqualTo(3), reason: '日常小插曲要几段兜住手感');
      expect(milestone, greaterThanOrEqualTo(3), reason: '里程碑应覆盖亲和上升曲线');
      for (final s in kPetStories) {
        expect(s.id, isNotEmpty);
        expect(s.scene, isNotEmpty);
        expect(s.minBond, inInclusiveRange(0, 100));
        if (s.milestone) {
          expect(s.effect.petBond, greaterThan(0), reason: '里程碑应有实质羁绊奖励');
          expect(s.minBond, greaterThan(0), reason: '里程碑应设定亲和门槛');
        }
        final t = fillPetStoryText(s.scene, house: '格兰芬多', pet: '雪鸮');
        expect(t, isNot(contains(r'$')), reason: '${s.id} 占位符替换后不应有残留');
      }
      expect(kPetStoryCooldownTurns, greaterThan(0), reason: '冷却应大于 0');
    });

    test('日常/里程碑亲和门槛单调上升', () {
      final milestones = kPetStories.where((s) => s.milestone).toList();
      final gates = milestones.map((s) => s.minBond).toList()..sort();
      expect(gates, milestones.map((s) => s.minBond).toList(),
          reason: '里程碑门槛应各不相同且随亲和上升');
    });
  });

  group('P12 · 门控过滤', () {
    test('没有宠物不演；开关关不演', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      gp.appProvider.petStoryEnabled = false;
      expect(gp.maybeTriggerPetStory(), '');
      gp.appProvider.petStoryEnabled = true;
      p.petId = null;
      p.petName = null;
      expect(gp.maybeTriggerPetStory(), '');
    });

    test('亲和不足不入里程碑候选（eligiblePetStories）', () async {
      final gp = await makeEnabled();
      gp.player!.petBond = 10; // 低于里程碑 25
      expect(gp.eligiblePetStories(milestonesOnly: true), isEmpty);
      expect(gp.eligiblePetStories(milestonesOnly: false), isNotEmpty,
          reason: '日常门槛为 0 仍可入选');
    });

    test('演过的里程碑不再入选', () async {
      final gp = await makeEnabled();
      gp.player!
        ..petBond = 85
        ..petStoriesPlayed = ['pet_bond_family', 'pet_bond_trust', 'pet_bond_devotion'];
      expect(gp.eligiblePetStories(milestonesOnly: true), isEmpty);
    });
  });

  group('P12 · 触发与协同', () {
    test('冷却内不触发', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      p.petBond = 5;
      p.petLastStoryTurn = 9999999; // 刚演过不久 → 冷却内
      expect(gp.maybeTriggerPetStory(), '');
      p.petLastStoryTurn = -100; // 冷却结束
      expect(gp.maybeTriggerPetStory(), isNot(''));
    });

    test('有进行中奇遇 / 羁绊终幕时不抢戏', () async {
      final gp = await makeEnabled();
      gp.player!.petLastStoryTurn = -100;
      gp.worldState.pendingHappenstanceId = 'wandering_note';
      expect(gp.maybeTriggerPetStory(), '');
      gp.worldState.pendingHappenstanceId = null;
      gp.worldState.companionArcs['hermione'] = const CompanionArcProgress(
          arcId: 'hermione_study_pledge', beatIndex: 2, pendingClimax: true);
      expect(gp.maybeTriggerPetStory(), '');
    });
  });

  group('P12 · 里程碑与日常', () {
    test('亲和 55 时先演最高未播里程碑，奖励到账', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      p.petBond = 55;
      p.petLastStoryTurn = -100;
      final moralBefore = p.playerReputation.get('moral');
      final s = gp.maybeTriggerPetStory();
      expect(s, isNotEmpty);
      // 达到 trust(55)：册坑 family(25)/trust(55) → 优先最高的 trust
      expect(p.petStoriesPlayed, ['pet_bond_trust']);
      expect(p.petBond, 60); // 55 + 5
      expect(p.playerReputation.get('social'), greaterThan(0));
      expect(moralBefore, p.playerReputation.get('moral'));
    });

    test('亲和 85 的里程碑演过不重播', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      p.petBond = 85;
      p.galleons = 0;
      p.petLastStoryTurn = -100;
      gp.maybeTriggerPetStory();
      expect(p.petBond, 90);
      expect(p.petStoriesPlayed, contains('pet_bond_devotion'));
      // 再触发：devotion 已播 → 转向未播的 trust
      p.petLastStoryTurn = -100;
      final s2 = gp.maybeTriggerPetStory();
      expect(s2, isNot(''));
      expect(p.petStoriesPlayed, contains('pet_bond_trust'));
      expect(
        p.petStoriesPlayed.where((x) => x == 'pet_bond_devotion').length,
        1,
        reason: 'devotion 只能演一次',
      );
    });

    test('无里程碑达标时走日常小插曲并给一点点羁绊', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      p.petBond = 5;
      p.petStoriesPlayed = ['pet_bond_family', 'pet_bond_trust', 'pet_bond_devotion'];
      p.petLastStoryTurn = -100;
      final before = p.petBond;
      final s = gp.maybeTriggerPetStory();
      expect(s, contains('🐾'));
      expect(p.petBond, before + 1, reason: '日常小插曲给 1 点羁绊');
    });
  });

  group('P12 · 离线回合接入', () {
    test('离线回合叙事出现宠物小插曲', () async {
      final gp = await makeEnabled();
      gp.player!.petBond = 5;
      gp.player!.petLastStoryTurn = -100;
      await gp.processChoice(const GameChoice(text: '随便走走', action: '随便走走'));
      expect(gp.currentNarrative, contains('🐾'),
          reason: '离线回合应出现宠物小插曲');
      expect(gp.player!.petLastStoryTurn, greaterThan(-100), reason: '冷却应已更新');
    });
  });

  group('P12 · 存档序列化', () {
    test('petLastStoryTurn / petStoriesPlayed 读写往返一致', () {
      final p = Player(
        name: '测试',
        birthYear: '1980',
        bloodType: 'pureblood',
        birthLocation: '伦敦',
        petLastStoryTurn: 9,
        petStoriesPlayed: ['pet_bond_family', 'pet_bond_trust'],
      );
      final restored = Player.fromJson(p.toJson());
      expect(restored.petLastStoryTurn, 9);
      expect(restored.petStoriesPlayed, ['pet_bond_family', 'pet_bond_trust']);
    });

    test('旧存档无 pet 字段时安全默认', () {
      final p = Player.fromJson(<String, dynamic>{});
      expect(p.petLastStoryTurn, -1);
      expect(p.petStoriesPlayed, isEmpty);
    });
  });
}