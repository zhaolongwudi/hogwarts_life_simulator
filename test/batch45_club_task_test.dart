/// v5 批次45 跨回合社团任务测试（P15 让社团从「被动攒分」升级为「有目标地出力」）。
///
/// 覆盖：
///  - 数据完整性：每社 3 条任务、id 全局唯一、requiredRounds>0、奖励为正、
///    rewardNote 占位符替换无残留、clubId 都能对上真实社团；
///  - 面板：未入社提示、已入社列出当前社全部任务、接取状态与进度展示；
///  - 接取/放弃：非法 id 提示、跨社任务不可接、接取落地状态、重复接取提示、
///    放弃清零；
///  - 推进：命中干系事的行动推进任务进度 +1、与日常记分共用命中不额外冷却、
///    未接取不推进、已完成未领奖不重复推进；
///  - 领奖：未完成不可领、完成后领奖落地大额积分 + 属性奖励、领奖后清空接取；
///  - 存档序列化：clubTask 字段往返一致 + 旧档安全默认。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:hogwarts_life_simulator/data/club_data.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/models/npc.dart';
import 'package:hogwarts_life_simulator/models/player.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

import 'helpers/test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 构造**开着社团**的离线 provider，默认加入决斗俱乐部并消除冷却。
  Future<GameProvider> makeEnabled({bool joinedDuel = true}) async {
    final gp = await makeGame(offlineQuickMode: true);
    gp.appProvider.clubEnabled = true;
    gp.appProvider.happenstanceEnabled = false;
    gp.appProvider.companionArcEnabled = false;
    gp.appProvider.petStoryEnabled = false;
    gp.appProvider.letterEnabled = false;
    if (joinedDuel) {
      gp.joinClub('duel');
      gp.player!.clubLastTurn = -100;
    }
    return gp;
  }

  group('P15 · 数据完整性', () {
    test('每社 3 条任务、id 唯一、奖励为正、占位符无残留', () {
      final ids = kClubTasks.map((t) => t.id).toSet();
      expect(ids.length, kClubTasks.length, reason: '任务 id 必须全局唯一');
      for (final c in kClubs) {
        final tasks = clubTasksFor(c.id);
        expect(tasks.length, 3, reason: '${c.name} 应有 3 条任务');
        for (final t in tasks) {
          expect(t.clubId, c.id);
          expect(t.title, isNotEmpty);
          expect(t.desc, isNotEmpty);
          expect(t.requiredRounds, greaterThan(0), reason: '${t.id} 所需回合数应 >0');
          expect(t.clubPointsReward, greaterThan(0), reason: '${t.id} 积分奖励应 >0');
          // 占位符替换后无残留
          final note = fillClubText(t.rewardNote, club: c.name, rank: '候补');
          expect(note, isNot(contains(r'$')),
              reason: '${t.id} rewardNote 占位符不应有残留');
          // 若声明了社团名占位符，替换后应带社团名（未声明的跳过，不强求）
          if (t.rewardNote.contains(r'$club')) {
            expect(note, contains(c.name),
                reason: '${t.id} 完成旁白应带社团名');
          }
        }
      }
      // 属性 key 必须存在于属性表（若声明了）
      for (final t in kClubTasks) {
        if (t.attrKey != null && t.attrValue > 0) {
          expect(Player.isAttributeKey(t.attrKey!), isTrue,
              reason: '${t.id} 属性 key ${t.attrKey} 应存在于属性表');
        }
      }
    });
  });

  group('P15 · 面板与接取', () {
    test('未入社时任务面板提示先入社', () async {
      final gp = await makeEnabled(joinedDuel: false);
      expect(gp.clubTaskPanel(), contains('还没有加入任何社团'));
    });

    test('已入社面板列出本社全部任务与接取入口', () async {
      final gp = await makeEnabled();
      final panel = gp.clubTaskPanel();
      expect(panel, contains('决斗俱乐部'));
      expect(panel, contains('十场切磋'));
      expect(panel, contains('duel_ten_spars'));
      expect(panel, contains('接取'));
    });

    test('接取任务落地状态；未知 id / 跨社任务提示', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      final txt = gp.acceptClubTask('duel_ten_spars');
      expect(txt, contains('十场切磋'));
      expect(p.clubTaskId, 'duel_ten_spars');
      expect(p.clubTaskProgress, 0);
      expect(p.clubTaskIssuedTurn, -1); // -1 = 尚未推进过
      // 未知 id
      expect(gp.acceptClubTask('不存在的任务'), contains('没有叫'));
      // 跨社任务（魔药部的不属于决斗社）
      expect(gp.acceptClubTask('potion_stable_pot'), contains('没有叫'));
      // 重复接取同一条（已有进度）提示
      p.clubTaskProgress = 1;
      expect(gp.acceptClubTask('duel_ten_spars'), contains('已经在进行'));
    });

    test('放弃任务清零并回到可接新任务', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      gp.acceptClubTask('duel_ten_spars');
      p.clubTaskProgress = 2;
      final txt = gp.abandonClubTask();
      expect(txt, contains('搁下'));
      expect(p.clubTaskId, isNull);
      expect(p.clubTaskProgress, 0);
      expect(p.clubTaskIssuedTurn, -1);
    });
  });

  group('P15 · 推进', () {
    test('命中干系事的行动推进任务进度 +1（独立于日常积分冷却）', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      gp.acceptClubTask('duel_ten_spars'); // requiredRounds: 4
      p.clubLastTurn = -100; // 消除日常记分冷却
      final before = p.clubPoints;
      // 任务推进是独立方法：即使日常记分在冷却内也能推进
      final s = gp.advanceClubTaskForAction('在会堂与人切磋对练');
      expect(s, contains('进度 1/4'), reason: '首次命中应推进到 1/4');
      expect(p.clubTaskProgress, 1);
      // 同一回合重复调用不重复推进（每回合最多 1 次）
      expect(gp.advanceClubTaskForAction('继续切磋对练'), '');
      expect(p.clubTaskProgress, 1);
      // 日常记分照常独立工作（冷却已消 → 应记分）
      final s2 = gp.maybeRunClubActivity('在会堂与人切磋对练');
      expect(p.clubPoints, greaterThan(before), reason: '日常记分照常入账');
      expect(s2, isNotEmpty);
      // 未接取任务时不推进
      final gp2 = await makeEnabled();
      gp2.player!.clubLastTurn = -100;
      expect(gp2.advanceClubTaskForAction('与人切磋对练'), '',
          reason: '未接取时不出现任务提示');
    });

    test('已完成未领奖时不重复推进，但提示领奖', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      gp.acceptClubTask('duel_ten_spars');
      p.clubTaskProgress = 4; // 已达成
      p.clubTaskIssuedTurn = -1;
      final s = gp.advanceClubTaskForAction('与人切磋对练');
      expect(s, contains('已完成'));
      expect(p.clubTaskProgress, 4, reason: '已完成不应再叠加');
    });

    test('任务推进与日常记分共用互斥门控（奇遇进行中不抢戏）', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      gp.acceptClubTask('duel_ten_spars');
      gp.worldState.pendingHappenstanceId = 'wandering_note';
      expect(gp.advanceClubTaskForAction('与人切磋对练'), '',
          reason: '有进行中奇遇时任务提示不应抢正戏');
      expect(p.clubTaskProgress, 0);
    });
  });

  group('P15 · 领奖', () {
    test('未完成不可领；完成后领奖落地积分与属性奖励', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      gp.acceptClubTask('duel_ten_spars');
      p.clubLastTurn = -100;
      // 未完成
      expect(gp.claimClubTask(), contains('还没完成'));
      // 手动推满
      p.clubTaskProgress = 4;
      final rtBefore = p.attributes['reaction_time']!;
      final ptsBefore = p.clubPoints;
      final txt = gp.claimClubTask();
      expect(txt, contains('任务完成'));
      expect(p.clubPoints, ptsBefore + 40, reason: '任务奖励积分应到账');
      expect(p.attributes['reaction_time'], rtBefore + 5,
          reason: '任务属性奖励应到账');
      // 领奖后清空接取
      expect(p.clubTaskId, isNull);
      expect(p.clubTaskProgress, 0);
      expect(p.clubTaskIssuedTurn, -1);
    });

    test('未接取时领奖提示', () async {
      final gp = await makeEnabled();
      expect(gp.claimClubTask(), contains('没有进行中的社团任务'));
    });
  });

  group('P15 · 存档序列化', () {
    test('clubTask 字段往返一致', () {
      final p = Player(
        name: '测试',
        birthYear: '1980',
        bloodType: 'pureblood',
        birthLocation: '伦敦',
        clubId: 'duel',
        clubTaskId: 'duel_ten_spars',
        clubTaskProgress: 3,
        clubTaskIssuedTurn: 7,
        clubTaskClaimed: false,
      );
      final r = Player.fromJson(p.toJson());
      expect(r.clubTaskId, 'duel_ten_spars');
      expect(r.clubTaskProgress, 3);
      expect(r.clubTaskIssuedTurn, 7);
      expect(r.clubTaskClaimed, isFalse);
    });

    test('旧存档无 clubTask 字段时安全默认', () {
      final p = Player.fromJson(<String, dynamic>{});
      expect(p.clubTaskId, isNull);
      expect(p.clubTaskProgress, 0);
      expect(p.clubTaskIssuedTurn, -1);
      expect(p.clubTaskClaimed, isFalse);
    });
  });

  group('P15 · 离线回合接入', () {
    test('离线回合命中干系事时任务推进并写入叙事', () async {
      final gp = await makeEnabled(joinedDuel: false);
      // 用魔药部避开决斗类行动（会触发既有「巫师决斗」子系统抢占叙事）
      gp.joinClub('potion');
      final p = gp.player!;
      // joinClub 会把冷却重置为 -1，任务接取后消除任务推进冷却
      gp.acceptClubTask('potion_stable_pot');
      p.clubLastTurn = -100;
      p.clubTaskIssuedTurn = -100;
      await gp.processChoice(const GameChoice(
          text: '去魔药教室安心熬制药剂', action: '去魔药教室安心熬制药剂'));
      expect(p.clubTaskProgress, greaterThan(0),
          reason: '离线回合应推进任务进度');
      expect(gp.currentNarrative, contains('社团任务'),
          reason: '任务进度提示应出现在叙事里');
    });
  });

  group('P16 · 社团晋升回访信', () {
    test('晋升王牌/传奇时同好回访信出现（已结识同好优先）', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      // 摆一位已结识的同好（决斗社同好：西莫/弗雷德/乔治）
      gp.npcRegistry['fred'] = NPC(
        id: 'fred', name: '弗雷德', affection: 60, introduced: true);
      // 跨阶到王牌（duel 王牌门槛 250）
      p.clubPoints = 245;
      p.clubLastTurn = -100;
      final s = gp.maybeRunClubActivity('在会堂与人切磋对练');
      expect(s, contains('猫头鹰'), reason: '晋升王牌应有回访信');
      expect(s, contains('弗雷德'), reason: '已结识同好应作为寄信人');
      expect(s, contains('王牌'), reason: '回访信应点明晋升的阶');
    });

    test('无已结识同好时回访信不出现（不阻塞晋升）', () async {
      final gp = await makeEnabled();
      final p = gp.player!;
      // 清空 NPC 注册表，确保「无任何已结识 NPC」的场景
      gp.npcRegistry.clear();
      p.clubPoints = 245;
      p.clubLastTurn = -100;
      final s = gp.maybeRunClubActivity('在会堂与人切磋对练');
      // 无任何已结识 NPC → 无回访信，但晋升仍发生
      expect(s, contains('王牌'), reason: '晋升不受影响');
      expect(s, isNot(contains('猫头鹰')), reason: '无同好可写信时不出现回访');
    });
  });
}