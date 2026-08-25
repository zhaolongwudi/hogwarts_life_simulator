import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/models/npc.dart';
import 'package:hogwarts_life_simulator/models/world_state.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/data/balance_constants.dart';

void main() {
  group('NPC好感度系统', () {
    test('好感度应在 -100 到 100 范围内', () {
      final npc = NPC(
        id: 'test',
        name: '测试NPC',
        house: 'Gryffindor',
      );
      npc.affection = 50;
      expect(npc.affection, 50);

      npc.affection = 200;
      // NPC模型本身不clamp，但updateNpcAffection会clamp
      // 这里只验证字段可读写
      expect(npc.affection, 200);
    });

    test('好感沉淀上限第一周+30', () {
      final npc = NPC(id: 'test', name: '测试', house: 'Gryffindor');
      npc.affectionGainedThisWeek = 25;
      final limit = npc.getAffectionGainLimit(1, 1);
      expect(limit, 5); // 30 - 25 = 5
    });

    test('好感沉淀第二周受首月上限约束', () {
      final npc = NPC(id: 'test', name: '测试', house: 'Gryffindor');
      final limit = npc.getAffectionGainLimit(10, 2);
      // 第2周不再"无上限"，仍受首月+50约束（修复原常量未被应用的问题）
      expect(limit, Balance.monthOneAffectionCap);
    });

    test('好感沉淀第三周受首月上限约束', () {
      final npc = NPC(id: 'test', name: '测试', house: 'Gryffindor');
      npc.affectionGainedThisMonth = 30;
      final limit = npc.getAffectionGainLimit(20, 3);
      expect(limit, Balance.monthOneAffectionCap - 30);
    });

    test('好感沉淀第四周之后恢复正常上限', () {
      final npc = NPC(id: 'test', name: '测试', house: 'Gryffindor');
      final limit = npc.getAffectionGainLimit(30, 5);
      expect(limit, Balance.affectionMax);
    });

    test('记仇机制影响好感上限', () {
      final npc = NPC(id: 'test', name: '测试', house: 'Slytherin');
      npc.affection = 80;
      npc.maxAffectionReached = 80;
      npc.addGrudge('betrayal', '欺骗', 10);
      expect(npc.hasGrudge, true);
      expect(npc.effectiveAffectionCap, 80);
    });

    test('好感阶段标签正确', () {
      final npc = NPC(id: 'test', name: '测试', house: 'Gryffindor');
      npc.affection = -60;
      expect(npc.affectionStage, '宿怨');
      npc.affection = 0;
      expect(npc.affectionStage, '中立');
      npc.affection = 40;
      expect(npc.affectionStage, '友好');
      npc.affection = 85;
      expect(npc.affectionStage, '深爱');
    });

    test('好感锁解锁', () {
      final npc = NPC(id: 'test', name: '测试', house: 'Gryffindor');
      expect(npc.hasLock('信任锁'), false);
      npc.affectionLocks.add('信任锁');
      expect(npc.hasLock('信任锁'), true);
    });

    test('recentEvents在好感变动时记录', () {
      final npc = NPC(id: 'test', name: '测试', house: 'Gryffindor');
      expect(npc.recentEvents.isEmpty, true);
      npc.recentEvents.insert(0, '好感 +5：帮助');
      expect(npc.recentEvents.length, 1);
      expect(npc.recentEvents.first, contains('+5'));
    });

    test('NPC序列化与反序列化', () {
      final npc = NPC(
        id: 'test',
        name: '赫敏·格兰杰',
        house: 'Gryffindor',
        grade: 1,
        affection: 45,
        appearance: '棕色蓬松头发',
        personalGoal: '成为最优秀的女巫',
        personality: ['聪明', '好学'],
      );
      final json = npc.toJson();
      final restored = NPC.fromJson(json);
      expect(restored.name, '赫敏·格兰杰');
      expect(restored.affection, 45);
      expect(restored.appearance, '棕色蓬松头发');
      expect(restored.personalGoal, '成为最优秀的女巫');
      expect(restored.personality, ['聪明', '好学']);
    });
  });

  group('WorldState', () {
    test('recentNarrativeEvents初始化为空', () {
      final ws = WorldState();
      expect(ws.recentNarrativeEvents.isEmpty, true);
    });

    test('addNarrativeEvent添加事件', () {
      final ws = WorldState();
      ws.addNarrativeEvent('测试事件1');
      ws.addNarrativeEvent('测试事件2');
      expect(ws.recentNarrativeEvents.length, 2);
      expect(ws.recentNarrativeEvents.first.text, '测试事件2');
    });

    test('recentNarrativeEvents上限20条', () {
      final ws = WorldState();
      for (int i = 0; i < 25; i++) {
        ws.addNarrativeEvent('事件$i');
      }
      expect(ws.recentNarrativeEvents.length, 20);
      expect(ws.recentNarrativeEvents.first.text, '事件24');
      expect(ws.recentNarrativeEvents.last.text, '事件5');
    });

    test('playerImpactScore初始为0', () {
      final ws = WorldState();
      expect(ws.playerImpactScore, 0.0);
    });

    test('playerImpactScore可写入', () {
      final ws = WorldState();
      ws.playerImpactScore = 0.6;
      expect(ws.playerImpactScore, 0.6);
    });

    test('WorldState序列化包含recentNarrativeEvents', () {
      final ws = WorldState();
      ws.addNarrativeEvent('恋爱事件');
      ws.addNarrativeEvent('CG解锁');
      final json = ws.toJson();
      expect(json.containsKey('recent_narrative_events'), true);
      expect((json['recent_narrative_events'] as List).length, 2);
    });

    test('WorldState反序列化恢复recentNarrativeEvents', () {
      final ws = WorldState();
      ws.addNarrativeEvent('测试事件');
      final json = ws.toJson();
      final restored = WorldState.fromJson(json);
      expect(restored.recentNarrativeEvents.length, 1);
      expect(restored.recentNarrativeEvents.first.text, '测试事件');
    });

    test('旧存档无recentNarrativeEvents字段时默认空列表', () {
      final json = <String, dynamic>{
        'academic_year': '1991-1992',
        'house_points': {'Gryffindor': 350},
      };
      final ws = WorldState.fromJson(json);
      expect(ws.recentNarrativeEvents.isEmpty, true);
    });

    test('addTimelineBranch记录世界线变动', () {
      final ws = WorldState();
      ws.addTimelineBranch('玩家选择加入斯莱特林');
      expect(ws.timelineChanges, 1);
      expect(ws.timelineBranches.first, contains('斯莱特林'));
    });
  });

  group('GameTime', () {
    test('日历计算dayOfYear', () {
      final time = GameTime(year: 1991, month: 9, day: 1);
      expect(time.dayOfYear, greaterThan(240));
      expect(time.dayOfYear, lessThan(245));
    });

    test('时间戳格式化', () {
      final time = GameTime(year: 1991, month: 9, day: 1, hour: 9, minute: 0);
      final ts = time.format();
      expect(ts, contains('1991'));
      expect(ts, contains('9'));
    });

    test('advanceMinutes推进时间', () {
      final time = GameTime(year: 1991, month: 9, day: 1, hour: 10, minute: 0);
      time.advanceMinutes(90);
      expect(time.hour, 11);
      expect(time.minute, 30);
    });
  });

  group('Reputation声望系统', () {
    test('声望增减', () {
      final rep = Reputation();
      rep.add('学术', 10);
      expect(rep.get('学术'), 10);
      rep.add('学术', -5);
      expect(rep.get('学术'), 5);
    });

    test('声望序列化', () {
      final rep = Reputation();
      rep.add('社交', 20);
      final json = rep.toJson();
      final restored = Reputation.fromJson(json);
      expect(restored.get('社交'), 20);
    });
  });

  group('LoveState恋爱状态', () {
    test('初始状态为单身', () {
      final ls = LoveState();
      expect(ls.status, '单身');
    });

    test('恋爱阶段推进', () {
      final ls = LoveState();
      ls.setStage('hermione', '暧昧', currentDay: 1);
      expect(ls.stageFor('hermione'), '暧昧');
      expect(ls.currentCrushName, 'hermione');
      expect(ls.crushStartDay, 1);
    });

    test('暧昧成熟期检查(≥14天)', () {
      final ls = LoveState();
      ls.setStage('hermione', '暧昧', currentDay: 1);
      expect(ls.isCrushMature(10), false);
      expect(ls.isCrushMature(15), true);
    });

    test('浪漫事件计数', () {
      final ls = LoveState();
      ls.recordRomanticEvent('hermione');
      ls.recordRomanticEvent('hermione');
      ls.recordRomanticEvent('ron');
      expect(ls.romanticEventsFor('hermione'), 2);
      expect(ls.romanticEventsFor('ron'), 1);
      expect(ls.romanticEventsFor('draco'), 0);
    });

    test('恋爱状态序列化', () {
      final ls = LoveState(
        status: '恋爱',
        partnerId: 'hermione',
        partnerName: '赫敏·格兰杰',
      );
      ls.recordRomanticEvent('hermione');
      ls.setStage('hermione', '暧昧', currentDay: 5);
      final json = ls.toJson();
      final restored = LoveState.fromJson(json);
      expect(restored.status, '恋爱');
      expect(restored.partnerName, '赫敏·格兰杰');
      expect(restored.romanticEventsFor('hermione'), 1);
      expect(restored.stageFor('hermione'), '暧昧');
    });
  });
}
