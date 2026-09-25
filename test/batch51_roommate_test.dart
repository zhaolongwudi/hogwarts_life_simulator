/// 批次 51 室友系统测试（框架2 §31 · 批次 D 测试层）。
///
/// 设计来源：docs/室友系统设计.md（2026-09-22 预研）。
///
/// 覆盖：
///  - 入舍自动补室友：ensureRoommateNpcs 按学院+性别生成 1~2 位同 dormId
///    生成 NPC（isGenerated=true），且老档 player.dormId=null 零迁移安全；
///  - playerDormId 推导：house+gender → 'gryffindor_boys' 等；
///  - /室友 列表：显示同 dormId 室友 + 好感/状态；
///  - /室友 聊天：好感 +1（走 updateNpcAffection）+ 冷却 3 回合；
///  - /室友 早起：概率性事件，精力 +1；
///  - 宿舍池人物句：localEventLinesWithRoommates 命中时替换 $roommate
///    占位为实际室友名；无室友退回环境句（行为不变）；
///  - 存档往返：dormId 持久化（Player.dormId + NPC.dormId）。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/models/npc.dart';
import 'package:hogwarts_life_simulator/models/player.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';
import 'helpers/test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 构造离线 provider，把玩家设为格兰芬多男生（可推 dormId）。
  /// [withRoommateNpcs] 为 true 时预置一位同宿舍室友（绕过随机生成）。
  Future<GameProvider> makeRoommateGame({bool withRoommateNpcs = false}) async {
    final gp = await makeGame(offlineQuickMode: true);
    final p = gp.player!;
    p.house = 'gryffindor';
    p.gender = '男';
    p.dormId = null; // 老档缺省
    if (withRoommateNpcs) {
      gp.npcRegistry.clear();
      gp.npcRegistry['roommate_test_1'] = NPC(
        id: 'roommate_test_1',
        name: '西奥多·布莱克',
        gender: '男',
        house: 'gryffindor',
        grade: p.grade ?? 1,
        dormId: 'gryffindor_boys',
        currentLocation: '霍格沃茨·宿舍',
        isGenerated: true,
        introduced: true,
        affection: 30,
        personality: const ['直率', '热情'],
        appearance: '高挑，笑容明亮',
        generatedProfile: '格兰芬多·室友',
      );
    }
    return gp;
  }

  group('R1 · playerDormId 推导与老档安全', () {
    test('格兰芬多男生 → gryffindor_boys；无 house 返回 null', () async {
      final gp = await makeRoommateGame();
      final p = gp.player!;
      p.house = 'gryffindor';
      p.gender = '男';
      expect(gp.playerDormId, 'gryffindor_boys');
      p.house = null;
      expect(gp.playerDormId, isNull);
      p.house = 'slytherin';
      p.gender = '女';
      expect(gp.playerDormId, 'slytherin_girls');
    });
  });

  group('R2 · 入舍自动补室友', () {
    test('ensureRoommateNpcs 生成 1~2 位同 dormId 室友并赋值', () async {
      final gp = await makeRoommateGame();
      final p = gp.player!;
      expect(p.dormId, isNull);
      gp.ensureRoommateNpcs();
      expect(p.dormId, 'gryffindor_boys');
      final rms = gp.roommates();
      expect(rms.length, inInclusiveRange(1, 2));
      for (final n in rms) {
        expect(n.dormId, 'gryffindor_boys');
        expect(n.isGenerated, isTrue);
        expect(n.isAlive, isTrue);
        expect(n.graduated, isFalse);
        expect(n.currentLocation, '霍格沃茨·宿舍');
      }
    });

    test('已有室友时不重复生成', () async {
      final gp = await makeRoommateGame(withRoommateNpcs: true);
      gp.ensureRoommateNpcs();
      expect(gp.roommates().length, 1);
      gp.ensureRoommateNpcs();
      expect(gp.roommates().length, 1); // 幂等
    });
  });

  group('R3 · /室友 命令族', () {
    test('/室友 列表：无室友提示回宿舍', () async {
      final gp = await makeRoommateGame();
      gp.handleLocalCommand('/室友');
      expect(gp.currentNarrative, contains('你还没有室友'));
    });

    test('/室友 列表：有室友显示好感与状态', () async {
      final gp = await makeRoommateGame(withRoommateNpcs: true);
      gp.handleLocalCommand('/室友');
      expect(gp.currentNarrative, contains('西奥多·布莱克'));
      expect(gp.currentNarrative, contains('好感 30'));
    });

    test('/室友 聊天：好感 +1', () async {
      final gp = await makeRoommateGame(withRoommateNpcs: true);
      final npc = gp.npcRegistry['roommate_test_1']!;
      final before = npc.affection;
      gp.handleLocalCommand('/室友 聊天');
      expect(npc.affection, before + 1);
      expect(gp.currentNarrative, contains('好感 +1'));
    });

    test('/室友 聊天：冷却 3 回合', () async {
      final gp = await makeRoommateGame(withRoommateNpcs: true);
      gp.handleLocalCommand('/室友 聊天');
      final after1 = gp.npcRegistry['roommate_test_1']!.affection;
      gp.handleLocalCommand('/室友 聊天'); // 冷却中
      expect(gp.npcRegistry['roommate_test_1']!.affection, after1,
          reason: '冷却中不重复加好感');
      expect(gp.currentNarrative, contains('冷却'));
      gp.turnCount += 3;
      gp.handleLocalCommand('/室友 聊天');
      expect(gp.npcRegistry['roommate_test_1']!.affection, after1 + 1,
          reason: '冷却结束后可再次聊天');
    });

    test('/室友 早起：概率事件不崩，精力不变或 +1', () async {
      final gp = await makeRoommateGame(withRoommateNpcs: true);
      final energyBefore = gp.player!.energy;
      gp.handleLocalCommand('/室友 早起');
      final energyAfter = gp.player!.energy;
      expect(energyAfter, inInclusiveRange(energyBefore, energyBefore + 1));
      expect(gp.currentNarrative, isNotEmpty);
    });
  });

  group('R4 · 宿舍池人物句与 $roommate 替换', () {
    test('宿舍有室友：命中室友互动小剧场并替换占位', () async {
      final gp = await makeRoommateGame(withRoommateNpcs: true);
      final lines = gp.localEventLinesWithRoommates(
        location: '霍格沃茨·宿舍',
        hour: 15,
        seed: 0,
      );
      expect(lines, isNotEmpty);
      expect(lines.first, isNot(contains('\$roommate')));
      expect(lines.first, contains('西奥多'));
    });

    test('宿舍无室友：退回环境句（无占位残留）', () async {
      final gp = await makeRoommateGame();
      final lines = gp.localEventLinesWithRoommates(
        location: '霍格沃茨·宿舍',
        hour: 15,
        seed: 0,
      );
      expect(lines, isNotEmpty);
      expect(lines.first, isNot(contains('\$roommate')));
    });

    test('非宿舍地点：不启用室友小剧场', () async {
      final gp = await makeRoommateGame(withRoommateNpcs: true);
      final lines = gp.localEventLinesWithRoommates(
        location: '霍格沃茨·大礼堂',
        hour: 15,
        seed: 0,
      );
      expect(lines, isNotEmpty);
      expect(lines.first, isNot(contains('西奥多')));
    });
  });

  group('R5 · 存档往返（dormId 持久化）', () {
    test('Player.dormId 与 NPC.dormId 序列化往返不丢', () async {
      final gp = await makeRoommateGame(withRoommateNpcs: true);
      final p = gp.player!;
      p.dormId = 'gryffindor_boys';
      final data = p.toJson();
      final restored = Player.fromJson(data);
      expect(restored.dormId, 'gryffindor_boys');
      final npc = gp.npcRegistry['roommate_test_1']!;
      final npcData = npc.toJson();
      final npcRestored = NPC.fromJson(npcData);
      expect(npcRestored.dormId, 'gryffindor_boys');
    });
  });
}
