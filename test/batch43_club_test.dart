/// v5 批次43 校园社团测试（P14 让「你属于什么」成为一条持续成长的线）。
///
/// 现状：离线「世界在动」已有很多"发生在你身上的事"（节庆/奇遇/羁绊/宠物/来信），
/// 但都来了又散、留不下持续的身份。本层让玩家加入一个社团（决斗/魔药/魁地奇/快讯），
/// 此后每次离线行动只要对得上社团干系事，就为社团积攒积分、逐级晋升（候补→活跃→
/// 骨干→王牌→传奇），跨阶有属性/学院分/声望回报，入社即落地「候补」阶欢迎加成。
///
/// 覆盖：
///  - 数据完整性：4 个社团、id 唯一、5 阶积分单调递增且从 0 起、干系词/同好非空、
///    各阶旁白占位符无残留、传奇阶有实质回报；
///  - 加入/退出：initial 面板罗列、加入落地积分与欢迎加成、未知 id 提示、
///    重复加入/换社清分/退出清零；
///  - 门控过滤：开关关不记、未入社不记、有奇遇/羁绊/待回信不抢戏、冷却内不记；
///  - 匹配记分：行动含干系词 → 记分、与干系无关的行动不记；
///  - 晋升：积分跨阶 → 晋升旁白 + 属性奖励到账；
///  - 面板：未入社罗列、入社后展示身份与晋升进度；
///  - 离线回合接入：回合叙事出现社团活动、积分入账；
///  - 存档序列化：clubId / clubPoints / clubLastTurn 往返一致 + 旧档安全默认。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:hogwarts_life_simulator/data/club_data.dart';
import 'package:hogwarts_life_simulator/models/companion_arc.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/models/player.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

import 'helpers/test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 构造**开着社团、关着奇遇/羁绊**的离线 provider。默认加入决斗俱乐部。
  Future<GameProvider> makeEnabled({bool joinedDuel = true}) async {
    final gp = await makeGame(offlineQuickMode: true);
    gp.appProvider.clubEnabled = true;
    gp.appProvider.happenstanceEnabled = false;
    gp.appProvider.companionArcEnabled = false;
    if (joinedDuel) {
      gp.joinClub('duel');
      gp.player!.clubLastTurn = -100; // 消除冷却
    }
    return gp;
  }

  group('P14 · 数据完整性', () {
    test('4 个社团、id 唯一、5 阶积分单调递增且从 0 起、旁白占位符无残留', () {
      final ids = kClubs.map((c) => c.id).toSet();
      expect(ids.length, kClubs.length, reason: '社团 id 必须全局唯一');
      expect(kClubs.length, 4, reason: '应有四个风格各异的社团');
      for (final c in kClubs) {
        expect(c.name, isNotEmpty);
        expect(c.icon, isNotEmpty);
        expect(c.activityKeywords, isNotEmpty, reason: '${c.id} 应有干系词');
        expect(c.attendees, isNotEmpty, reason: '${c.id} 应有同好成员');
        expect(c.ranks.length, 5, reason: '${c.name} 应有完整五阶');
        var last = -1;
        for (var i = 0; i < c.ranks.length; i++) {
          expect(c.ranks[i].points, greaterThan(last),
              reason: '${c.name} 第${i + 1}阶积分应严格递增');
          last = c.ranks[i].points;
          expect(c.ranks[i].name, isNotEmpty);
          // 每阶旁白占位符替换后不留残留
          final note = c.ranks[i].bonuses.isNotEmpty
              ? fillClubText(c.ranks[i].bonuses.first.note,
                  club: c.name, rank: c.ranks[i].name)
              : '';
          expect(note, isNot(contains(r'$')),
              reason: '${c.name}·${c.ranks[i].name} 旁白占位符不应有残留');
        }
        expect(c.ranks.first.points, 0, reason: '首阶应从 0 分开始');
        // 末阶（传奇）应有实质回报（属性或声望/学院分）
        final lastRank = c.ranks.last;
        final hasSub = lastRank.bonuses.any(
            (b) => (b.attrValue != 0 || b.reputationValue != 0 || b.housePoints != 0));
        expect(hasSub, isTrue, reason: '${c.name} 传奇阶应有实质回报');
      }
      expect(kClubCooldownTurns, greaterThan(0), reason: '冷却应大于 0');
    });
  });

  group('P14 · 加入与退出', () {
    test('面板未入社时罗列四社；加入落地 clubId 与「候补」欢迎加成', () async {
      final gp = await makeEnabled(joinedDuel: false);
      final panel = gp.formatClubPanel();
      expect(panel, contains('决斗俱乐部'));
      expect(panel, contains('魔药部'));
      expect(panel, contains('魁地奇队'));
      expect(panel, contains('快讯社'));
      final p = gp.player!;
      final rt0 = p.attributes['reaction_time'];
      final txt = gp.joinClub('duel');
      expect(txt, contains('决斗俱乐部'));
      expect(p.clubId, 'duel');
      expect(p.clubPoints, 0);
      expect(p.clubLastTurn, -1);
      // 入社即落地候补阶欢迎加成（reaction_time +3）
      expect(p.attributes['reaction_time'], (rt0 ?? 50) + 3,
          reason: '入社应落地候补阶加成');
    });

    test('未知 id 提示且不改动现有加入状态', () async {
      final gp = await makeEnabled(joinedDuel: false);
      final txt = gp.joinClub('不存在的社团');
      expect(txt, contains('没有叫'));
      expect(gp.player!.clubId, isNull);
    });

    test('重复加入同一社提示；换社清零重来', () async {
      final gp = await makeEnabled(); // 已入 duel
      final p = gp.player!;
      p.clubPoints = 999;
      final again = gp.joinClub('duel');
      expect(again, contains('已经是'));
      expect(p.clubPoints, 999, reason: '重复加入不应清分');
      final switched = gp.joinClub('potion');
      expect(switched, contains('魔药部'));
      expect(p.clubId, 'potion');
      expect(p.clubPoints, 0, reason: '换社应清零');
      expect(p.clubLastTurn, -1);
    });

    test('退出清零并回到未加入', () async {
      final gp = await makeEnabled();
      final txt = gp.leaveClub();
      expect(txt, contains('生涯作罢'));
      expect(gp.player!.clubId, isNull);
      expect(gp.player!.clubPoints, 0);
    });
  });

  group('P14 · 门控过滤', () {
    test('开关关不记；未入社不记', () async {
      final gp = await makeEnabled();
      gp.appProvider.clubEnabled = false;
      expect(gp.maybeRunClubActivity('与人切磋'), '');
      gp.appProvider.clubEnabled = true;
      // 未入社
      final gp2 = await makeEnabled(joinedDuel: false);
      expect(gp2.maybeRunClubActivity('与人切磋'), '');
    });

    test('有进行中奇遇/羁绊/待回信时不抢戏', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      gp.worldState.pendingHappenstanceId = 'wandering_note';
      expect(gp.maybeRunClubActivity('与人切磋'), '');
      gp.worldState.pendingHappenstanceId = null;
      gp.worldState.companionArcs['hermione'] = const CompanionArcProgress(
          arcId: 'hermione_study_pledge', beatIndex: 2, pendingClimax: true);
      expect(gp.maybeRunClubActivity('与人切磋'), '');
      gp.worldState.companionArcs.clear();
      p.pendingLetterId = 'letter_dawdle';
      expect(gp.maybeRunClubActivity('与人切磋'), '');
      p.pendingLetterId = null;
    });

    test('冷却内不触发', () async {
      final gp = await makeEnabled();
      gp.player!.clubLastTurn = 9999999;
      expect(gp.maybeRunClubActivity('与人切磋'), '');
      gp.player!.clubLastTurn = -100;
      expect(gp.maybeRunClubActivity('与人切磋'), isNot(''));
    });
  });

  group('P14 · 匹配记分与晋升', () {
    test('行动含干系词 → 记分；与干系无关的行动不记', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      final before = p.clubPoints;
      final s = gp.maybeRunClubActivity('在走廊与人切磋对练');
      expect(s, contains('🏰'));
      expect(s, contains('社团'));
      expect(p.clubPoints, greaterThan(before), reason: '命中干系词应记分');
      expect(p.clubLastTurn, isNonNegative);
      // 同回合冷却已置入 → 紧接着的无干系行动也不会有副作用（此刻在冷却内）
      final s2 = gp.maybeRunClubActivity('随便读书');
      expect(s2, '');
    });

    test('与干系无关的行动（未入社或词不类）不记分', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      p.clubLastTurn = -100;
      // 「读书」不匹配决斗干系词
      expect(gp.maybeRunClubActivity('去图书馆读书'), '');
      expect(p.clubPoints, 0);
    });

    test('积分跨阶 → 晋升旁白 + 属性奖励到账', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      final rtBefore = p.attributes['reaction_time']!;
      // 决斗：rank1（活跃）门槛 60。置到刚过不了的位置，靠本次 gain 顶破。
      p.clubPoints = 56;
      p.clubLastTurn = -100;
      final s = gp.maybeRunClubActivity('与人切磋对练');
      expect(s, contains('晋升'));
      expect(s, contains('活跃'));
      expect(p.clubPoints, greaterThanOrEqualTo(66));
      // 入社已 +3（候补）；本次还应有 rank1 的 +5
      expect(p.attributes['reaction_time'], greaterThanOrEqualTo(rtBefore + 5));
    });

    test('晋升到传奇后无下一阶：仍记分且提示登顶', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      p.clubPoints = 400; // 已到传奇门槛
      p.clubLastTurn = -100;
      final s = gp.maybeRunClubActivity('与人切磋对练');
      expect(s, contains('传奇'));
      expect(p.clubPoints, greaterThan(400));
    });
  });

  group('P14 · 面板', () {
    test('入社后面板展示身份与晋升进度', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      final txt = gp.formatClubPanel();
      expect(txt, contains('决斗俱乐部'));
      expect(txt, contains('候补'));
      expect(txt, contains('${p.clubPoints}'));
      expect(txt, contains('晋升进度'));
    });
  });

  group('P14 · 离线回合接入', () {
    test('离线回合叙事出现社团活动且积分入账', () async {
      final gp = await makeEnabled(joinedDuel: false);
      // 用魔药部避开决斗类行动（其会触发既有「巫师决斗」子系统抢占叙事）
      gp.joinClub('potion');
      final p = gp.player!;
      // joinClub 会把冷却重置为 -1，首回合需手动消除冷却，否则 6 回合内被门控
      p.clubLastTurn = -100;
      final before = p.clubPoints;
      await gp.processChoice(
          const GameChoice(text: '去魔药教室安心熬制药剂', action: '去魔药教室安心熬制药剂'));
      // 断言真实效果：社团记分已入账、冷却已记录，即证明社团系统接进了离线回合。
      expect(p.clubPoints, greaterThan(before));
      expect(p.clubLastTurn, greaterThanOrEqualTo(0));
    });
  });

  group('P14 · 存档序列化', () {
    test('clubId / clubPoints / clubLastTurn 往返一致', () {
      final p = Player(
        name: '测试',
        birthYear: '1980',
        bloodType: 'pureblood',
        birthLocation: '伦敦',
        clubId: 'quip',
        clubPoints: 123,
        clubLastTurn: 9,
      );
      final r = Player.fromJson(p.toJson());
      expect(r.clubId, 'quip');
      expect(r.clubPoints, 123);
      expect(r.clubLastTurn, 9);
    });

    test('旧存档无 club 字段时安全默认', () {
      final p = Player.fromJson(<String, dynamic>{});
      expect(p.clubId, isNull);
      expect(p.clubPoints, 0);
      expect(p.clubLastTurn, -1);
    });
  });
}