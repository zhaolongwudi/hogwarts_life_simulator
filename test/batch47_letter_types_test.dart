/// 批次 47 更多来信类型测试（P13 扩展：魔法部公函 / 神秘信件 / 毕业旧友重联）。
///
/// 设计来源：docs/更多来信类型设计.md（2026-09-22 预研）。
///
/// 在既有 batch42 三型来信（friendship/rivalry/milestone）之上新增三型：
///  - ministry：魔法部公函（senderLabel 机构署名，onceOnly，学期节点低频）；
///  - mystery：神秘信件（senderLabel 匿名署名，onceOnly，低概率彩蛋）；
///  - reunion：毕业旧友重联（senderId 指定已毕业 NPC，可重播）。
///
/// 覆盖：
///  - 数据完整性：LetterKind 六型、senderLabel 条目、onceOnly 防重、占位符无残留；
///  - 落款解析：senderLabel 信不查 NPC pool；reunion 只在已毕业 NPC 中挑；
///  - 触发：ministry 优先于友情（once 未收时）；mystery 低概率不抢戏；
///  - 投递：匿名信署名取 senderLabel（非 NPC 名）；机构信效果走匿名结算；
///  - 回信：匿名信回信署名正确、效果结算走匿名通道；
///  - 存档：老档无新字段安全默认。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:hogwarts_life_simulator/data/letter_data.dart';
import 'package:hogwarts_life_simulator/models/npc.dart';
import 'package:hogwarts_life_simulator/models/player.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

import 'helpers/test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 构造开着来信、关着奇遇/羁绊/宠物的离线 provider，并请出几位 NPC。
  /// [graduateOldFriend] 为 true 时额外放入一位已毕业旧友（reunion 用）。
  Future<GameProvider> makeEnabled({bool graduateOldFriend = false}) async {
    final gp = await makeGame(offlineQuickMode: true);
    gp.appProvider.letterEnabled = true;
    gp.appProvider.happenstanceEnabled = false;
    gp.appProvider.companionArcEnabled = false;
    gp.npcRegistry.clear();
    gp.npcRegistry['hermione'] = NPC(
        id: 'hermione',
        name: '赫敏',
        affection: 60,
        introduced: true,
        house: '格兰芬多');
    if (graduateOldFriend) {
      gp.npcRegistry['charlie'] = NPC(
          id: 'charlie',
          name: '查理·韦斯莱',
          affection: 40,
          introduced: true,
          graduated: true);
    }
    final p = gp.player!;
    // 消除冷却：让第一回合即可收到信
    p.letterLastTurn = -100;
    return gp;
  }

  group('R1 · 数据完整性', () {
    test('LetterKind 六型 + senderLabel 条目合法 + 占位符无残留', () {
      // 六型枚举存在
      expect(LetterKind.values.length, 6, reason: '扩展后应有三型来信');
      expect(LetterKind.values, containsAll([
        LetterKind.friendship,
        LetterKind.rivalry,
        LetterKind.milestone,
        LetterKind.ministry,
        LetterKind.mystery,
        LetterKind.reunion,
      ]));

      // 新三型各至少 1 条
      final ministry = kLetters.where((l) => l.kind == LetterKind.ministry);
      final mystery = kLetters.where((l) => l.kind == LetterKind.mystery);
      final reunion = kLetters.where((l) => l.kind == LetterKind.reunion);
      expect(ministry.length, greaterThanOrEqualTo(1), reason: '魔法部公函至少 1 条');
      expect(mystery.length, greaterThanOrEqualTo(1), reason: '神秘信件至少 1 条');
      expect(reunion.length, greaterThanOrEqualTo(1), reason: '旧友重联至少 1 条');

      // 机构/匿名信必须有 senderLabel
      for (final l in [...ministry, ...mystery]) {
        expect(l.senderLabel, isNotNull, reason: '${l.id} 机构/匿名信应有署名标签');
        expect(l.senderLabel!.trim(), isNotEmpty);
        expect(l.onceOnly, isTrue, reason: '${l.id} 机构/彩蛋信应一次性');
      }
      // reunion 用 NPC 寄信人（senderId 可空，但 senderLabel 必须为空）
      for (final l in reunion) {
        expect(l.senderLabel, isNull, reason: '${l.id} 旧友重联应走 NPC 通道');
      }

      // 占位符替换后无残留
      for (final l in kLetters) {
        final t = fillLetterText(l.scene, player: '玩家', sender: '寄信人', house: '格兰芬多');
        expect(t, isNot(contains(r'$')), reason: '${l.id} 占位符替换后不应有残留');
        for (final rep in l.replies) {
          final rt = fillLetterText(rep.text, player: '玩家', sender: '寄信人', house: '格兰芬多');
          expect(rt, isNot(contains(r'$')), reason: '${l.id} 回信占位符不应有残留');
        }
      }
    });
  });

  group('R1 · 落款解析', () {
    test('senderLabel 信不查 NPC pool（letterSenderFor 返回 null）', () async {
      final gp = await makeEnabled();
      final m = letterById('letter_ministry_owls')!;
      expect(gp.letterSenderFor(m), isNull, reason: '机构信不落 NPC 款');
      final my = letterById('letter_mystery_riddle')!;
      expect(gp.letterSenderFor(my), isNull, reason: '匿名信不落 NPC 款');
    });

    test('reunion 只在已毕业 NPC 中挑；无毕业生返回 null', () async {
      // 无毕业生
      final gp0 = await makeEnabled();
      final r = letterById('letter_reunion_old_friend')!;
      expect(gp0.letterSenderFor(r), isNull, reason: '无毕业生时旧友信不可落款');
      // 有毕业生（毕业的查理在 pool，在校的赫敏不在）
      final gp = await makeEnabled(graduateOldFriend: true);
      expect(gp.letterSenderFor(r)?.id, 'charlie', reason: 'reunion 只认已毕业 NPC');
      // 指定 senderId 为在校生（赫敏）→ 不可落款（未毕业）
      final def = LetterDef(
          id: 't_reunion_wrong',
          kind: LetterKind.reunion,
          senderId: 'hermione',
          scene: 'x');
      expect(gp.letterSenderFor(def), isNull, reason: 'reunion 不落在校生款');
    });
  });

  group('R1 · 触发与投递', () {
    test('ministry 未收时优先于友情（once 防重）', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      // 预填所有 milestone 为已收，让 ministry 分支成为保留项
      p.receivedLetters = kLetters
          .where((l) => l.kind == LetterKind.milestone)
          .map((l) => l.id)
          .toList();
      p.pendingLetterId = null;
      p.letterLastTurn = -100;
      final s = gp.maybeTriggerLetter(seed: 42); // 固定 seed 消除随机性
      expect(s, contains('🦉'));
      expect(s, contains('魔法部'), reason: '机构信署名应为魔法部');
      // 收信即标记 received（两封 ministry 之一）
      final gotMinistry = p.receivedLetters.any(
          (id) => letterById(id)?.kind == LetterKind.ministry);
      expect(gotMinistry, isTrue, reason: '应收到一封魔法部公函');
      expect(p.pendingLetterId, isNotNull, reason: '公函带待回信');
      // 再触发：ministry 已收，走 friendship
      p.letterLastTurn = -100;
      p.pendingLetterId = null;
      final s2 = gp.maybeTriggerLetter(seed: 42);
      expect(s2, contains('🦉'), reason: '收完公函后仍会来友情信');
    });

    test('mystery 低概率：seed 固定时命中不重复，未命中不崩', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      // 预填 milestone + ministry 全已收，让 mystery 分支可被走到
      p.receivedLetters = [
        ...kLetters
            .where((l) => l.kind == LetterKind.milestone)
            .map((l) => l.id),
        ...kLetters
            .where((l) => l.kind == LetterKind.ministry)
            .map((l) => l.id),
      ];
      p.pendingLetterId = null;
      p.letterLastTurn = -100;
      final s = gp.maybeTriggerLetter(seed: 7);
      expect(s, isNotEmpty, reason: '本轮必然来信（mystery 命中或落到 friendship）');
      // 无论命中与否，流程不得崩、且 pending 不残留上一封
      if (p.receivedLetters.contains('letter_mystery_riddle')) {
        // 命中：onceOnly 不重播
        p.letterLastTurn = -100;
        p.pendingLetterId = null;
        final s2 = gp.maybeTriggerLetter(seed: 7);
        expect(s2.contains('匿名的寄信人'), isFalse, reason: '神秘信 onceOnly 不重播');
      }
    });

    test('匿名信署名取 senderLabel，效果走匿名通道（无好感变动）', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      // 预填 milestone 全已收，让 ministry 先投（此时无毕业生，reunion 跳过）
      p.receivedLetters = kLetters
          .where((l) => l.kind == LetterKind.milestone)
          .map((l) => l.id)
          .toList();
      p.pendingLetterId = null;
      p.letterLastTurn = -100;
      final aff0 = gp.npcRegistry['hermione']!.affection;
      final s = gp.maybeTriggerLetter(seed: 42);
      // 两封 ministry 均以「魔法部」署名、均不落 NPC 名、均走匿名结算
      expect(s, contains('魔法部'), reason: '署名用 senderLabel（魔法部）');
      expect(s, isNot(contains('赫敏')), reason: '不落赫敏的名');
      expect(gp.npcRegistry['hermione']!.affection, aff0, reason: '匿名信不动 NPC 好感');
      final gotMinistry = p.receivedLetters.any(
          (id) => letterById(id)?.kind == LetterKind.ministry);
      expect(gotMinistry, isTrue, reason: '应收到一封魔法部公函');
    });
  });

  group('R1 · 回信', () {
    test('匿名信回信署名 senderLabel，效果走匿名通道', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      final house0 = p.houseCupPoints;
      p.pendingLetterId = 'letter_ministry_owls';
      final choices = gp.letterReplyChoicesForPending();
      expect(choices.length, greaterThanOrEqualTo(2));
      final res = gp.tryResolveLetterReplyChoice(choices.first.action);
      expect(res, contains('魔法部·考试管理局'), reason: '回信对象用 senderLabel');
      expect(res, contains('你的回信'));
      expect(p.pendingLetterId, isNull);
      // ministry 回信「确认报名」→ +3 学院分
      expect(p.houseCupPoints, greaterThan(house0), reason: '公函回信应结学院分');
    });

    test('reunion 回信走 NPC 通道（好感 +3）', () async {
      final gp = await makeEnabled(graduateOldFriend: true);
      final p = gp.player!;
      p.pendingLetterId = 'letter_reunion_old_friend';
      final aff0 = gp.npcRegistry['charlie']!.affection;
      final choices = gp.letterReplyChoicesForPending();
      final res = gp.tryResolveLetterReplyChoice(choices.first.action);
      expect(res, contains('查理·韦斯莱'), reason: 'reunion 回信对象是毕业旧友');
      expect(gp.npcRegistry['charlie']!.affection, greaterThan(aff0));
      expect(p.pendingLetterId, isNull);
    });
  });

  group('R1 · 存档兼容', () {
    test('LetterDef 无 senderLabel 的旧构造仍可用（默认 null）', () {
      const def = LetterDef(
        id: 'x',
        kind: LetterKind.friendship,
        scene: 'x',
      );
      expect(def.senderLabel, isNull);
    });

    test('旧存档无新增字段时安全默认（letters 空、received 空）', () {
      final p = Player.fromJson(<String, dynamic>{});
      expect(p.letters, isEmpty);
      expect(p.receivedLetters, isEmpty);
      expect(p.pendingLetterId, isNull);
    });
  });
}
