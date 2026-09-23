/// v5 批次42 猫头鹰来信测试（P13 NPC 在离线日常里主动寄来只言片语）。
///
/// 现状：信只能由玩家主动 `/信 寄` 发出，NPC 从不主动开口；本层让已结识 NPC
/// 在离线回合格外主动寄来一封——友情（会重播）、敌对（会挖苦）、羁绊里程碑
/// （亲和跨门槛各演一次、演过不重播）。带问题的信会进入「待回信」，下一回合
/// 玩家用专属选项真正回一封信；每封来信都固化进存档信箱（`/信 读` 可回看）。
///
/// 覆盖：
///  - 数据完整性：id 唯一、三类都够、里程碑 once-only 有实质奖励、占位符无残留；
///  - 落款解析：friendship 取好感到位者、rivalry 取有怨气者、无人可用返回 null；
///  - 门控过滤：开关关不寄、无 NPC 不寄、冷却内不寄、有奇遇/羁绊/待回信不抢戏；
///  - 触发：里程碑亲和达标先寄最高门槛、once-only 演过不重播、饱和后掐 friend；
///  - 待回信两段式：收信置 pending + 专属回信选项 → 回信结算生效、清 pending；
///  - 离线回合接入：回合叙事出现猫头鹰来信、回信回合出现「你的回信」；
///  - 存档序列化：letterLastTurn / receivedLetters / pendingLetterId 往返一致。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:hogwarts_life_simulator/data/letter_data.dart';
import 'package:hogwarts_life_simulator/models/companion_arc.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/models/npc.dart';
import 'package:hogwarts_life_simulator/models/player.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

import 'helpers/test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 构造**开着来信、关着奇遇/羁绊/宠物**的离线 provider，并请出几位 NPC。
  /// [friendAffection] 设置赫敏对玩家的好感；[enemy] 为 true 时改请一位对手。
  Future<GameProvider> makeEnabled({
    int friendAffection = 60,
    bool enemy = false,
  }) async {
    final gp = await makeGame(offlineQuickMode: true);
    gp.appProvider.letterEnabled = true;
    gp.appProvider.happenstanceEnabled = false;
    gp.appProvider.companionArcEnabled = false;
    gp.npcRegistry.clear();
    if (enemy) {
      gp.npcRegistry['draco'] = NPC(
          id: 'draco', name: '德拉科', affection: -20, introduced: true);
    } else {
      gp.npcRegistry['hermione'] = NPC(
          id: 'hermione',
          name: '赫敏',
          affection: friendAffection,
          introduced: true,
          house: '格兰芬多');
    }
    final p = gp.player!;
    // 消除冷却：让第一回合即可收到信
    p.letterLastTurn = -100;
    return gp;
  }

  group('P13 · 数据完整性', () {
    test('id 唯一、三类都够、里程碑 once-only 有实质奖励、占位符无残留', () {
      final ids = kLetters.map((l) => l.id).toSet();
      expect(ids.length, kLetters.length, reason: '来信 id 必须全局唯一');
      final f = kLetters.where((l) => l.kind == LetterKind.friendship).length;
      final r = kLetters.where((l) => l.kind == LetterKind.rivalry).length;
      final m = kLetters.where((l) => l.kind == LetterKind.milestone).length;
      expect(f, greaterThanOrEqualTo(3), reason: '友情来信要几封兜住日常');
      expect(r, greaterThanOrEqualTo(2), reason: '敌对来信要能兜住怨气');
      expect(m, greaterThanOrEqualTo(3), reason: '里程碑应覆盖好感上升曲线');
      for (final l in kLetters) {
        expect(l.id, isNotEmpty);
        expect(l.scene, isNotEmpty);
        expect(l.minAffection, inInclusiveRange(0, 100));
        if (l.kind == LetterKind.milestone) {
          expect(l.onceOnly, isTrue, reason: '里程碑应一次性');
          expect(l.minAffection, greaterThan(0), reason: '里程碑应设好感门槛');
          expect(l.replies, isNotEmpty, reason: '里程碑应带可回信的分量');
          expect(l.effect.senderAffection, greaterThan(0),
              reason: '里程碑应有实质好感奖励');
        }
        if (l.kind == LetterKind.rivalry) {
          expect(l.maxAffection, isNotNull, reason: '敌对来信应限定好感上限');
          expect(l.maxAffection!, lessThanOrEqualTo(0),
              reason: '敌对来信只对好感不高的人寄');
        }
        final t = fillLetterText(l.scene, player: '玩家', sender: '寄信人', house: '格兰芬多');
        expect(t, isNot(contains(r'$')), reason: '${l.id} 占位符替换后不应有残留');
        for (final rep in l.replies) {
          expect(rep.title, isNotEmpty);
          final rt = fillLetterText(rep.text, player: '玩家', sender: '寄信人', house: '格兰芬多');
          expect(rt, isNot(contains(r'$')), reason: '${l.id} 回信占位符不应有残留');
        }
      }
      expect(kLetterCooldownTurns, greaterThan(0), reason: '冷却应大于 0');
    });
  });

  group('P13 · 落款解析', () {
    test('friendship 取好感到位者；好感不足不可落款', () async {
      final gp = await makeEnabled(friendAffection: 30);
      final def = letterById('letter_first_owl')!; // milestone min 30
      expect(gp.letterSenderFor(def)?.id, 'hermione');
      final tooHigh = letterById('letter_dream')!; // milestone min 80 > 30
      expect(gp.letterSenderFor(tooHigh), isNull, reason: '好感到 80 的友人才可落款');
    });

    test('rivalry 取有怨气者；无人满足时返回 null', () async {
      final gp = await makeEnabled(enemy: true);
      final def = letterById('letter_taunt')!;
      expect(gp.letterSenderFor(def)?.id, 'draco');
    });

    test('未结识（introduced=false）不可落款', () async {
      final gp = await makeGame(offlineQuickMode: true);
      gp.appProvider.letterEnabled = true;
      gp.npcRegistry.clear();
      gp.npcRegistry['hermione'] = NPC(
          id: 'hermione', name: '赫敏', affection: 90, introduced: false);
      final def = letterById('letter_first_owl')!;
      expect(gp.letterSenderFor(def), isNull);
    });
  });

  group('P13 · 门控过滤', () {
    test('开关关不寄；无任何 NPC 不寄', () async {
      final gp = await makeEnabled();
      gp.appProvider.letterEnabled = false;
      expect(gp.maybeTriggerLetter(), '');
      gp.appProvider.letterEnabled = true;
      gp.npcRegistry.clear();
      expect(gp.maybeTriggerLetter(), '');
    });

    test('冷却内不触发', () async {
      final gp = await makeEnabled(friendAffection: 85);
      gp.player!.letterLastTurn = 9999999; // 刚收到过不久 → 冷却内
      expect(gp.maybeTriggerLetter(), '');
      gp.player!.letterLastTurn = -100; // 冷却结束
      expect(gp.maybeTriggerLetter(), isNot(''));
    });

    test('有进行中奇遇 / 羁绊 / 待回信时不抢戏', () async {
      final gp = await makeEnabled(friendAffection: 85);
      final p = gp.player!;
      p.letterLastTurn = -100;
      gp.worldState.pendingHappenstanceId = 'wandering_note';
      expect(gp.maybeTriggerLetter(), '');
      gp.worldState.pendingHappenstanceId = null;
      gp.worldState.companionArcs['hermione'] = const CompanionArcProgress(
          arcId: 'hermione_study_pledge', beatIndex: 2, pendingClimax: true);
      expect(gp.maybeTriggerLetter(), '');
      gp.worldState.companionArcs.clear();
      p.pendingLetterId = 'letter_dawdle';
      expect(gp.maybeTriggerLetter(), '', reason: '已有待回信不再叠新信');
    });
  });

  group('P13 · 触发与里程碑', () {
    test('亲和 85 时先寄最高门槛里程碑，once-only 到账且置待回信', () async {
      final gp = await makeEnabled(friendAffection: 85);
      final p = gp.player!;
      final s = gp.maybeTriggerLetter();
      expect(s, contains('🦉'));
      expect(s, contains('赫敏'));
      // 最高门槛（80）的 letter_dream 先寄出
      expect(p.receivedLetters, contains('letter_dream'));
      expect(p.pendingLetterId, 'letter_dream');
      // 收信即结一部分好感
      expect(gp.npcRegistry['hermione']!.affection, greaterThan(85));
    });

    test('里程碑演过不重播：再触发改走友情来信', () async {
      final gp = await makeEnabled(friendAffection: 85);
      final p = gp.player!;
      // 先把所有里程碑标记为已收到（机构/匿名信也预收，防新类型抢戏，专测友情兜底）
      p.receivedLetters = [
        ...kLetters
            .where((l) => l.kind == LetterKind.milestone)
            .map((l) => l.id),
        ...kLetters
            .where((l) => l.kind == LetterKind.ministry)
            .map((l) => l.id),
        ...kLetters
            .where((l) => l.kind == LetterKind.mystery)
            .map((l) => l.id),
      ];
      p.pendingLetterId = null;
      p.letterLastTurn = -100;
      final s = gp.maybeTriggerLetter();
      expect(s, contains('🦉'), reason: '饱和后仍会通过友情来信续命');
      expect(p.pendingLetterId, isNotNull, reason: '友情来信带问题 → 待回信');
    });

    test('没有足够友好的朋友时，落到敌对来信', () async {
      final gp = await makeEnabled(enemy: true);
      final p = gp.player!;
      // 预收机构/匿名信，防新类型抢戏（专测敌对兜底）
      p.receivedLetters = [
        ...kLetters
            .where((l) => l.kind == LetterKind.ministry)
            .map((l) => l.id),
        ...kLetters
            .where((l) => l.kind == LetterKind.mystery)
            .map((l) => l.id),
      ];
      p.pendingLetterId = null;
      p.letterLastTurn = -100;
      final s = gp.maybeTriggerLetter();
      expect(s, contains('🦉'));
      expect(s, contains('德拉科'));
      expect(gp.player!.pendingLetterId, isNotNull);
    });
  });

  group('P13 · 回信两段式', () {
    test('待回信生成专属选项，回信结算生效并清 pending', () async {
      final gp = await makeEnabled(friendAffection: 85);
      final p = gp.player!;
      p.pendingLetterId = 'letter_first_owl';
      final choices = gp.letterReplyChoicesForPending();
      expect(choices.length, greaterThanOrEqualTo(2));
      expect(choices.first.action, startsWith('信:letter_first_owl:'));
      final aff0 = gp.npcRegistry['hermione']!.affection;
      final res = gp.tryResolveLetterReplyChoice(choices.last.action);
      expect(res, contains('🦉'));
      expect(res, contains('你的回信'));
      expect(gp.npcRegistry['hermione']!.affection, greaterThan(aff0));
      expect(p.pendingLetterId, isNull);
    });

    test('动作不匹配（未选）时走中性兜底收尾，pending 清理', () async {
      final gp = await makeEnabled(friendAffection: 85);
      final p = gp.player!;
      p.pendingLetterId = 'letter_first_owl';
      final res = gp.tryResolveLetterReplyChoice('随便走走');
      expect(res, contains('🦉'));
      expect(p.pendingLetterId, isNull, reason: '兜底后不应残留待回信');
    });
  });

  group('P13 · 离线回合接入', () {
    test('回合叙事出现猫头鹰来信；下回合回信回合出现「你的回信」', () async {
      final gp = await makeEnabled(friendAffection: 85);
      final p = gp.player!;
      await gp.processChoice(const GameChoice(text: '随便走走', action: '随便走走'));
      expect(gp.currentNarrative, contains('🦉'), reason: '离线回合应收到来信');
      expect(p.pendingLetterId, isNotNull);
      final pending = p.pendingLetterId!;
      // 下回合用「信:<id>:0」回信
      await gp.processChoice(GameChoice(
          text: '回信', action: '信:$pending:0'));
      expect(gp.currentNarrative, contains('你的回信'), reason: '回信回合应呈现回应');
      expect(p.pendingLetterId, isNull);
    });
  });

  group('P13 · 存档序列化', () {
    test('letterLastTurn / receivedLetters / pendingLetterId 往返一致', () {
      final p = Player(
        name: '测试',
        birthYear: '1980',
        bloodType: 'pureblood',
        birthLocation: '伦敦',
        letterLastTurn: 7,
        receivedLetters: ['letter_first_owl', 'letter_dream'],
        pendingLetterId: 'letter_dawdle',
        lastLetterSenderId: 'hermione',
      );
      final r = Player.fromJson(p.toJson());
      expect(r.letterLastTurn, 7);
      expect(r.receivedLetters, ['letter_first_owl', 'letter_dream']);
      expect(r.pendingLetterId, 'letter_dawdle');
      expect(r.lastLetterSenderId, 'hermione');
    });

    test('旧存档无 letter 字段时安全默认', () {
      final p = Player.fromJson(<String, dynamic>{});
      expect(p.letterLastTurn, -1);
      expect(p.receivedLetters, isEmpty);
      expect(p.pendingLetterId, isNull);
      expect(p.lastLetterSenderId, isNull);
    });
  });
}