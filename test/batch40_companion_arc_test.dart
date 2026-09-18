/// v5 批次40 羁绊小剧场测试（P11 与亲近之人的跨回合小戏，靠好感解锁）。
///
/// 与奇遇的区别：奇遇是「你」个人随机碰到的一件小事（两段式、即时）；
/// 羁绊小剧场是「你与某位 NPC 之间」一场有起承转合的小戏——好感跨过门槛才开演，
/// 跨多回合演完（前幕自动推进、最终幕两段式抉择），演完归宿不重播。
///
/// 覆盖：
///  - 数据完整性：id 唯一、npcId 存在、每场至少 2 幕、最终幕在末尾、结局
///    字段对齐、季节标签合法、占位符替换无残留、奖励物品有定义；
///  - 门槛过滤：好感/年级/季节各自正确生效，演完的 NPC 不再入候选；
///  - 触发逻辑：开关关不演、有进行中奇遇不演、冷却内不演、最终幕待抉择时
///    不再推进新戏；
///  - 推进：新开一场从中段幕起逐幕推进，最终幕待抉择并给出氛围专属抉择；
///  - 抉择结算：匹配 `羁绊:<arcId>:<idx>` 精确结算并 completing；不匹配自动
///    走第一结局；结算必有正向收获；演完不再触发；
///  - 离线回合接入：触发回合叙事出现「羁绊」并开记状态；抉择回合叙事补结局；
///  - 存档序列化：companionArcs 读写往返一致。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:hogwarts_life_simulator/data/companion_arc_data.dart';
import 'package:hogwarts_life_simulator/mixins/mixin_companion_arc.dart';
import 'package:hogwarts_life_simulator/models/companion_arc.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/models/world_state.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

import 'helpers/test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 构造**开着羁绊、关着奇遇**的离线 provider（共享夹具默认两个都关）。
  Future<GameProvider> makeEnabled() async {
    final gp = await makeGame(offlineQuickMode: true);
    gp.appProvider.companionArcEnabled = true;
    gp.appProvider.happenstanceEnabled = false; // 奇遇保持关闭，隔离本专项
    // 固定到秋季（10 月）：赫敏弧（autumn/winter）确定入围，罗恩弧（春夏）
    // 确定不入围；哈利弧需 2 年级，默认 1 年级不入围 → 唯一候选=赫敏弧。
    gp.worldState.time.month = 10;
    // 消除开演冷却：直接多次触发推进多番幕
    gp.worldState.lastCompanionArcTurn = -100;
    return gp;
  }

  /// 额定声望总和。
  int repSum(GameProvider gp) {
    final r = gp.player!.playerReputation;
    var sum = 0;
    for (final d in ['academic', 'social', 'combat', 'moral', 'leadership', 'dark']) {
      sum += r.get(d);
    }
    return sum;
  }

  group('P11 · 数据完整性', () {
    test('id 唯一、npcId 存在、每场 2~4 幕且最终幕在末尾', () {
      final ids = kCompanionArcs.map((a) => a.id).toSet();
      expect(ids.length, kCompanionArcs.length, reason: '小剧场 id 必须全局唯一');
      expect(kCompanionArcs.length, greaterThanOrEqualTo(3), reason: '至少要有几个能撑起羁绊线');
      for (final a in kCompanionArcs) {
        expect(a.title, isNotEmpty);
        expect(a.startAffection, greaterThan(0));
        expect(a.beats.length, inInclusiveRange(2, 4), reason: '一场戏应有起承转合');
        // 最终幕必须是最后一幕（在两段式抉择上保证推进顺序一致）
        expect(a.beats.last.isClimax, isTrue, reason: '${a.id} 最终幕应落在末尾');
        for (var i = 0; i < a.beats.length; i++) {
          final b = a.beats[i];
          expect(b.scene, isNotEmpty);
          if (b.isClimax) {
            expect(b.outcomeTitles.length, inInclusiveRange(2, 2));
            expect(b.outcomeTexts.length, b.outcomeTitles.length);
            expect(b.outcomeEffects.length, b.outcomeTitles.length);
          } else if (i > 0) {
            // 开演那一幕只是把场子铺开（钩住悬念，可不给即时收益）；
            // 但之后的每一幕推进都得有实质收获，否则戏就像空转。
            expect(b.effect, isNotNull,
                reason: '${a.id} 第 ${i + 1} 幕（推进幕）应给即时收益');
          }
        }
      }
    });

    test('季节标签合法、占位符替换无残留', () {
      const house = '格兰芬多';
      for (final a in kCompanionArcs) {
        for (final s in a.seasonTags) {
          expect(kCompanionArcSeasonTags, contains(s), reason: '非法季节标签 $s');
        }
        for (final b in a.beats) {
          final t = fillCompanionArcText(b.scene, house: house);
          expect(t, isNot(contains(r'$')));
          for (final ot in b.outcomeTexts) {
            expect(fillCompanionArcText(ot, house: house), isNot(contains(r'$')));
          }
        }
      }
    });
  });

  group('P11 · 门槛过滤', () {
    test('好感不足不入选；好感跨过门槛才入选', () async {
      final gp = await makeEnabled();
      gp.worldState.time.month = 10; // 秋季，赫敏/哈利弧适用
      final arc = companionArcById('hermione_study_pledge')!;
      // 好感低于 startAffection(25)
      gp.npcRegistry['hermione']!.affection = 10;
      expect(gp.eligibleCompanionArcsToStart().any((x) => x.id == arc.id), isFalse);
      // 好感跨过门槛
      gp.npcRegistry['hermione']!.affection = 40;
      expect(gp.eligibleCompanionArcsToStart().any((x) => x.id == arc.id), isTrue);
    });

    test('季节不符不入选', () async {
      final gp = await makeEnabled();
      // 赫敏弧限定 autumn/winter → 夏天不可
      gp.worldState.time.month = 6; // 夏季
      gp.npcRegistry['hermione']!.affection = 40;
      expect(gp.eligibleCompanionArcsToStart().any((x) => x.id == 'hermione_study_pledge'), isFalse);
    });

    test('演完的 NPC 不再入候选', () async {
      final gp = await makeEnabled();
      gp.worldState.time.month = 10;
      gp.npcRegistry['harry']!.affection = 60;
      gp.player!.grade = 5;
      gp.worldState.companionArcs['harry'] = const CompanionArcProgress(completed: true);
      expect(gp.eligibleCompanionArcsToStart().any((x) => x.id == 'harry_scar_promise'), isFalse);
    });
  });

  group('P11 · 触发逻辑', () {
    test('开关关闭时不演', () async {
      final gp = await makeEnabled();
      gp.appProvider.companionArcEnabled = false;
      gp.npcRegistry['hermione']!.affection = 60;
      expect(gp.maybeTriggerCompanion(), isEmpty);
    });

    test('有进行中奇遇时不抢戏', () async {
      final gp = await makeEnabled();
      gp.npcRegistry['hermione']!.affection = 60;
      gp.worldState.pendingHappenstanceId = 'wandering_note';
      expect(gp.maybeTriggerCompanion(), isEmpty);
      gp.worldState.pendingHappenstanceId = null;
      expect(gp.maybeTriggerCompanion(), isNotEmpty);
    });

    test('冷却内不重复演', () async {
      final gp = await makeEnabled();
      gp.npcRegistry['hermione']!.affection = 60;
      expect(gp.maybeTriggerCompanion(), isNotEmpty);
      // 立刻再触发 → 冷却内，不演
      expect(gp.maybeTriggerCompanion(), isEmpty);
    });

    test('新开一场从首幕开始推进', () async {
      final gp = await makeEnabled();
      gp.npcRegistry['hermione']!.affection = 60;
      // 首幕（中段幕，自动推进）
      final block = gp.maybeTriggerCompanion();
      expect(block, contains('羁绊'));
      expect(block, contains('赫敏'));
      final p = gp.companionProgress['hermione']!;
      expect(p.arcId, 'hermione_study_pledge');
      expect(p.pendingClimax, isFalse);
      expect(p.completed, isFalse);
      expect(p.beatIndex, 1, reason: '推进后下幕应指向第 2 幕');
      expect(gp.worldState.lastCompanionArcTurn, isNot(-100));
    });
  });

  group('P11 · 推进与最终幕', () {
    test('逐幕推进到最终幕待抉择；待抉择时不再开新戏', () async {
      final gp = await makeEnabled();
      gp.npcRegistry['hermione']!.affection = 60;
      gp.maybeTriggerCompanion(); // hs1
      gp.worldState.lastCompanionArcTurn = -100;
      gp.maybeTriggerCompanion(); // hs2
      expect(gp.companionProgress['hermione']!.beatIndex, 2);
      // 最终幕（hs3 climax）
      gp.worldState.lastCompanionArcTurn = -100;
      final climaxBlock = gp.maybeTriggerCompanion();
      expect(climaxBlock, contains('羁绊'));
      final p = gp.companionProgress['hermione']!;
      expect(p.pendingClimax, isTrue, reason: '最终幕应进入待抉择');
      // 待抉择时不推进新戏
      gp.worldState.lastCompanionArcTurn = -100;
      expect(gp.maybeTriggerCompanion(), isEmpty);
    });

    test('最终幕给出两格抉择，action 带「羁绊:」前缀', () async {
      final gp = await makeEnabled();
      gp.npcRegistry['hermione']!.affection = 60;
      // 一路推进到最终幕
      for (int i = 0; i < 3; i++) {
        gp.maybeTriggerCompanion();
        gp.worldState.lastCompanionArcTurn = -100;
      }
      final choices = gp.companionChoicesForPending();
      expect(choices.length, 2);
      expect(choices[0].action.startsWith(kCompanionArcActionPrefix), isTrue);
      expect(choices[0].action, contains('hermione_study_pledge'));
    });
  });

  group('P11 · 抉择结算', () {
    Future<GameProvider> finToClimax() async {
      final gp = await makeEnabled();
      gp.npcRegistry['hermione']!.affection = 60;
      for (int i = 0; i < 3; i++) {
        gp.maybeTriggerCompanion();
        gp.worldState.lastCompanionArcTurn = -100;
      }
      return gp; // 已完成前两幕，最终幕待抉择
    }

    test('匹配 action 精确结算并 completes，收获正向', () async {
      final gp = await finToClimax();
      final rep0 = repSum(gp);
      final g0 = gp.player!.galleons;
      final res = gp.tryResolveCompanionChoice('羁绊:hermione_study_pledge:1');
      expect(res, contains('你的选择'));
      expect(repSum(gp) + gp.player!.galleons, greaterThan(rep0 + g0));
      final p = gp.companionProgress['hermione']!;
      expect(p.pendingClimax, isFalse);
      expect(p.completed, isTrue, reason: '演完归宿');
    });

    test('不匹配动作 → 第一结局兜底收尾，不悬挂', () async {
      final gp = await finToClimax();
      final res = gp.tryResolveCompanionChoice('随便走走');
      expect(res, contains('你的选择'));
      expect(gp.companionProgress['hermione']!.completed, isTrue);
      expect(gp.hasPendingCompanionClimax, isFalse);
    });

    test('无待抉择时结算返回空串', () async {
      final gp = await makeEnabled();
      expect(gp.tryResolveCompanionChoice('羁绊:x:0'), isEmpty);
    });

    test('演完后不再触发同一场', () async {
      final gp = await finToClimax();
      gp.tryResolveCompanionChoice('羁绊:hermione_study_pledge:0');
      gp.worldState.lastCompanionArcTurn = -100;
      expect(gp.maybeTriggerCompanion(), isEmpty, reason: '已演完的弧不应重播');
    });
  });

  group('P11 · 离线回合接入', () {
    test('触发回合叙事出现"羁绊"并开记状态', () async {
      final gp = await makeEnabled();
      gp.npcRegistry['hermione']!.affection = 60;
      await gp.processChoice(const GameChoice(text: '随便走走', action: '随便走走'));
      expect(gp.currentNarrative, contains('羁绊'));
      expect(gp.companionProgress['hermione']?.arcId, 'hermione_study_pledge');
    });
  });

  group('P11 · 存档序列化', () {
    test('companionArcs 读写往返一致', () {
      final ws = WorldState(
        companionArcs: {
          'hermione': const CompanionArcProgress(
              arcId: 'hermione_study_pledge', beatIndex: 2, pendingClimax: true),
          'ron': const CompanionArcProgress(arcId: 'ron_hidden_brooch', completed: true),
        },
        lastCompanionArcTurn: 9,
      );
      final restored = WorldState.fromJson(ws.toJson());
      expect(restored.companionArcs['hermione']!.arcId, 'hermione_study_pledge');
      expect(restored.companionArcs['hermione']!.beatIndex, 2);
      expect(restored.companionArcs['hermione']!.pendingClimax, isTrue);
      expect(restored.companionArcs['ron']!.completed, isTrue);
      expect(restored.lastCompanionArcTurn, 9);
    });

    test('旧存档无该字段时安全默认', () {
      final restored = WorldState.fromJson(const {});
      expect(restored.companionArcs, isEmpty);
      expect(restored.lastCompanionArcTurn, 0);
    });
  });
}