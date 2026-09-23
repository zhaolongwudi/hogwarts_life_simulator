/// 批次 48 来信串联测试（P13 × P14/P11：社长邀请信 + 羁绊预热信）。
///
/// 设计来源：docs/来信串联设计.md（2026-09-22 预研）。
///
/// 在既有 batch42/47 来信体系之上新增两处「串联」：
///  - 社长邀请信（letter_club_*_invite，friendship + clubId）：
///    未入社 + 对应社长（senderId，好感 ≥ minAffection）达标 → 先于日常友情
///    投出；回信「好，我加入<社团>」→ 直接 joinClub 入社（含同好注入 A +5），
///    「我再想想」→ 婉拒不动。
///  - 羁绊预热信（letter_warmup_*，milestone + senderId）：
///    好感接近 P11 小剧场门槛时投出（走得通的 milestone 分支最低门槛），
///    onceOnly 防重，回信 +3 好感，为羁绊暖场。
///
/// 覆盖：
///  - 数据完整性：clubId 非空社长信 4 封 / 预热信 2 封 / senderLabel null /
///    占位符无残留；
///  - 触发：未入社 + 社长好感达标 → 收到社长信；已入社 → 不再投；
///    预热信在好感刚达标时命中；
///  - 回信：选「好，我加入」→ clubId 变更 + 回信文本含入社面板；
///    选「我再想想」→ clubId 不变；
///  - 防抢戏：预收 ministry/mystery 后社长信才轮到（优先级契约）；
///  - 存档字段：本批次零新增 Player 字段，无迁移（老档安全）。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:hogwarts_life_simulator/data/letter_data.dart';
import 'package:hogwarts_life_simulator/models/npc.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

import 'helpers/test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 构造开着来信、关着奇遇/羁绊/宠物的离线 provider，并按需放入确定的 NPC。
  /// 默认预收 ministry/mystery（防抢 3.5 社长信分支）、月份固定 7 月（无节点信）。
  /// [npc] 形如 {'seamus': ('西莫', 25)}：id → (中文名, 好感)。
  /// 中文名必须与 club_data.dart 的 attendees 一致，否则 joinClub 内
  /// findNpcByKeyword 按名字匹配会失败（同好注入 +5 不生效）。
  Future<GameProvider> makeEnabled(
      {Map<String, (String, int)> npc = const {},
      List<String> preReceived = const [
        'letter_ministry_owls',
        'letter_ministry_forbidden',
        'letter_mystery_riddle',
      ]}) async {
    final gp = await makeGame(offlineQuickMode: true);
    gp.appProvider.letterEnabled = true;
    gp.appProvider.happenstanceEnabled = false;
    gp.appProvider.companionArcEnabled = false;
    gp.npcRegistry.clear();
    for (final e in npc.entries) {
      gp.npcRegistry[e.key] = NPC(
          id: e.key,
          name: e.value.$1,
          affection: e.value.$2,
          introduced: true,
          house: '格兰芬多');
    }
    final p = gp.player!;
    p.letterLastTurn = -100; // 消除冷却
    p.receivedLetters = List<String>.from(preReceived);
    gp.worldState.time.month = 7;
    gp.worldState.time.day = 15;
    return gp;
  }

  group('R1 · 数据完整性', () {
    test('4 封社长邀请信 + 2 封羁绊预热信结构合法 + 占位符无残留', () {
      final clubInvites = kLetters.where((l) => l.clubId != null).toList();
      expect(clubInvites.length, 4, reason: '四社各一封邀请信');
      for (final l in clubInvites) {
        expect(l.kind, LetterKind.friendship, reason: '${l.id} 应走 friendship 通道');
        expect(l.senderId, isNotNull, reason: '${l.id} 应指定社长寄信人');
        expect(l.senderLabel, isNull, reason: '${l.id} 应走 NPC 通道（非机构/匿名）');
        expect(l.minAffection, greaterThanOrEqualTo(20),
            reason: '${l.id} 需要好感达标才投');
      }
      // 四社 id 齐全
      expect(clubInvites.map((l) => l.clubId).toSet(),
          {'duel', 'potion', 'broom', 'quip'});

      final warmups = kLetters
          .where((l) => l.id.startsWith('letter_warmup_'))
          .toList();
      expect(warmups.length, greaterThanOrEqualTo(2), reason: '至少 2 封预热信');
      for (final l in warmups) {
        expect(l.kind, LetterKind.milestone, reason: '${l.id} 应是 milestone');
        expect(l.onceOnly, isTrue, reason: '${l.id} 演过不重播');
        expect(l.senderId, isNotNull, reason: '${l.id} 指定羁绊对象');
        expect(l.clubId, isNull, reason: '${l.id} 与社团无关');
      }

      // 占位符替换后无残留
      for (final l in kLetters) {
        final t = fillLetterText(
            l.scene, player: '玩家', sender: '寄信人', house: '格兰芬多');
        expect(t, isNot(contains(r'$')), reason: '${l.id} 信件占位符不应残留');
        for (final rep in l.replies) {
          final rt = fillLetterText(
              rep.text, player: '玩家', sender: '寄信人', house: '格兰芬多');
          expect(rt, isNot(contains(r'$')), reason: '${l.id} 回信占位符不应残留');
        }
      }
    });
  });

  group('R2 · 社长邀请信触发', () {
    test('未入社 + 社长好感达标 → 收到社长邀请信', () async {
      final gp = await makeEnabled(npc: {'seamus': ('西莫', 25)});
      final p = gp.player!;
      final s = gp.maybeTriggerLetter(seed: 7);
      expect(s, contains('🦉'));
      expect(s, contains('决斗俱乐部'), reason: '应收到决斗社社长的邀请');
      expect(p.pendingLetterId, 'letter_club_duel_invite',
          reason: '邀请信应进入待回信');
    });

    test('已入社 → 不再投该社邀请信（走日常友情暖场）', () async {
      final gp = await makeEnabled(npc: {
        'seamus': ('西莫', 25),
        'hermione': ('赫敏', 60),
      });
      final p = gp.player!;
      p.clubId = 'duel'; // 已入决斗社
      final s = gp.maybeTriggerLetter(seed: 7);
      // 3.5 分支因 clubId != null 跳过；应落到日常友情（赫敏好感 60 ≥35 等）
      expect(s, contains('🦉'), reason: '入社后仍有日常来信');
      expect(s, isNot(contains('决斗俱乐部')), reason: '已入社不应再收该社邀请');
      expect(p.pendingLetterId, isNot('letter_club_duel_invite'),
          reason: '不应进入社长信待回信');
    });

    test('社长好感未达标 → 暂不投（无戏则不抢分支）', () async {
      final gp = await makeEnabled(npc: {'seamus': ('西莫', 10)});
      final p = gp.player!;
      final s = gp.maybeTriggerLetter(seed: 7);
      // seamus 好感 10 < 20 → 3.5 分支无人可选；且无其他日常信 → 返回空串
      expect(s, isEmpty, reason: '好感未达标且无其他来信源时不应投信');
      expect(p.pendingLetterId, isNull);
    });
  });

  group('R3 · 社长邀请信回信', () {
    test('选「好，我加入」→ 直接入社 + 回信文本含入社面板', () async {
      final gp = await makeEnabled(npc: {'seamus': ('西莫', 25)});
      final p = gp.player!;
      gp.maybeTriggerLetter(seed: 7);
      expect(p.pendingLetterId, 'letter_club_duel_invite');

      final res =
          gp.tryResolveLetterReplyChoice('信:letter_club_duel_invite:0');
      expect(p.clubId, 'duel', reason: '回信「好，我加入」应触发 joinClub 入社');
      expect(res, contains('你的回信'), reason: '回信文本应呈现');
      expect(res, contains('加入社团'), reason: '回信末尾应附 joinClub 面板文本');
      expect(p.pendingLetterId, isNull, reason: '回信后清空待回信');
    });

    test('选「我再想想」→ 婉拒不入社', () async {
      final gp = await makeEnabled(npc: {'seamus': ('西莫', 25)});
      final p = gp.player!;
      gp.maybeTriggerLetter(seed: 7);
      final res =
          gp.tryResolveLetterReplyChoice('信:letter_club_duel_invite:1');
      expect(p.clubId, isNull, reason: '婉拒不应入社');
      expect(res, contains('你的回信'));
      expect(p.pendingLetterId, isNull);
    });

    test('回信入社叠加同好注入 A（attendees 好感 +5）', () async {
      final gp = await makeEnabled(npc: {'seamus': ('西莫', 25)});
      final p = gp.player!;
      gp.maybeTriggerLetter(seed: 7);
      // seamus 是 attendees 之一：joinClub 内 updateNpcAffection(seamus, +5)
      gp.tryResolveLetterReplyChoice('信:letter_club_duel_invite:0');
      final seamus = gp.npcRegistry['seamus']!;
      expect(seamus.affection, greaterThan(25),
          reason: '入社同好注入应对社长好感 +5');
    });
  });

  group('R4 · 羁绊预热信', () {
    test('好感接近 P11 门槛 → 命中预热信（milestone 最低门槛先投）', () async {
      final gp = await makeEnabled(npc: {'hermione': ('赫敏', 15)});
      final p = gp.player!;
      final s = gp.maybeTriggerLetter(seed: 3);
      expect(s, contains('🦉'));
      expect(s, contains('旧书'), reason: '应收到赫敏的预热信（内容含旧书回忆）');
      expect(p.pendingLetterId, 'letter_warmup_hermione',
          reason: '预热信进入待回信');
    });

    test('预热信 onceOnly：演过不重播', () async {
      final gp = await makeEnabled(npc: {'hermione': ('赫敏', 15)});
      final p = gp.player!;
      gp.maybeTriggerLetter(seed: 3);
      // 回信一次，标记已收
      gp.tryResolveLetterReplyChoice('信:letter_warmup_hermione:0');
      expect(p.receivedLetters, contains('letter_warmup_hermione'),
          reason: 'milestone 完成后应记为已收');
      // 冷却重置后再触发：hermione 好感 15+3=18 仍<30（letter_first_owl），
      // 预热信已收 → milestone 分支无戏 → 落到友情
      p.letterLastTurn = -100;
      expect(p.receivedLetters, contains('letter_warmup_hermione'));
      final s2 = gp.maybeTriggerLetter(seed: 3);
      expect(s2, isNot(contains('旧书')), reason: '预热信不重播');
    });

    test('预热信回信 +3 好感', () async {
      final gp = await makeEnabled(npc: {'hermione': ('赫敏', 15)});
      gp.maybeTriggerLetter(seed: 3);
      gp.tryResolveLetterReplyChoice('信:letter_warmup_hermione:0');
      final hermione = gp.npcRegistry['hermione']!;
      expect(hermione.affection, greaterThan(15),
          reason: '预热信回信「我也记得」应 +好感');
    });
  });

  group('R5 · 与既有来信体系共存（优先级契约）', () {
    test('预收 milestone 后 ministry 仍优先于社长邀请（不破坏 batch47 契约）',
        () async {
      final gp = await makeEnabled(npc: {
        'seamus': ('西莫', 25),
        'hermione': ('赫敏', 60),
      });
      final p = gp.player!;
      p.receivedLetters = kLetters
          .where((l) => l.kind == LetterKind.milestone)
          .map((l) => l.id)
          .toList();
      gp.worldState.time.month = 5; // O.W.L.s 报名月
      final s = gp.maybeTriggerLetter(seed: 42);
      expect(s, contains('魔法部'), reason: 'ministry 优先级仍高于社长邀请');
    });
  });
}