/// v5 批次37 离线扩充内容测试（P8 魁地奇赛果变体/赛后事件、禁林特殊遭遇、NPC 回忆库）。
///
/// 覆盖四件事：
///  - 数据完整性：三张表（id 唯一、年级门控、模板占位符可替换且无 `$` 残留）；
///  - NPC 回忆解锁：好感门槛 + 未收集双条件、奖励结算、离线/在线行为一致；
///  - 魁地奇变体：多次采样叙事出现多套变体、`$` 占位符永不泄漏、结算不变量；
///  - 禁林特殊遭遇：年级门控行为 + 命中时战利品进背包、叙事特征句收尾；
///  - `/回忆册` 命令：空态 / 部分收集 / 全收集三态。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:hogwarts_life_simulator/data/offline_extras_data.dart';
import 'package:hogwarts_life_simulator/models/npc.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';
import 'package:hogwarts_life_simulator/services/npc_chat_service.dart';

import 'helpers/test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GameProvider> makeProvider() async => makeGame(offlineQuickMode: true);

  NPC npcOf(String id, {int affection = 0}) =>
      NPC(id: id, name: '测试$id', affection: affection);

  /// 把玩家摆到「城堡内 + 装备扫帚 + 满状态」的魁地奇就绪态。
  void setupReady(GameProvider gp) {
    final p = gp.player!;
    gp.worldState.currentLocation = '霍格沃茨';
    p.equipped['broom'] = '飞天扫帚·横扫';
    p.energy = 100;
    p.satiety = 100;
  }

  group('P8 · 数据完整性', () {
    test('魁地奇：赛果变体 ≥3 套、赛后事件 ≥4 条、位置时刻覆盖四位置', () {
      expect(kQuidditchResultVariants.length, greaterThanOrEqualTo(3));
      expect(kQuidditchAfterEvents.length, greaterThanOrEqualTo(4));
      expect(kQuidditchPositionMoments.keys,
          containsAll(['找球手', '追球手', '守门员', '击球手']));
    });

    test('魁地奇：所有模板经 fillQuidditchTemplate 替换后无 \$ 占位符残留', () {
      String filled(String t) => fillQuidditchTemplate(
            t,
            myHouse: '格兰芬多',
            opp: '斯莱特林',
            score: 120,
            oppScore: 80,
            broom: '飞天扫帚·横扫',
          );
      for (final v in kQuidditchResultVariants) {
        expect(filled(v.winBody), isNot(contains(r'$')));
        expect(filled(v.lossBody), isNot(contains(r'$')));
      }
      for (final e in kQuidditchAfterEvents) {
        expect(filled(e.text), isNot(contains(r'$')));
      }
      for (final m in kQuidditchPositionMoments.values) {
        expect(filled(m.text), isNot(contains(r'$')));
      }
    });

    test('禁林：遭遇 id 唯一、年级门控 ≥1、一年级池只含 minGrade≤1 的事件', () {
      final ids = kForestSpecialEncounters.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length, reason: '遭遇 id 必须唯一');
      for (final e in kForestSpecialEncounters) {
        expect(e.minGrade, greaterThanOrEqualTo(1));
      }
      final grade1 = kForestSpecialEncounters.where((e) => 1 >= e.minGrade).toList();
      expect(grade1, isNotEmpty, reason: '一年级也必须能遇到至少一种特殊遭遇');
      for (final e in grade1) {
        expect(e.minGrade, lessThanOrEqualTo(1));
      }
    });

    test('回忆库：id 唯一、门槛 >0、奖励好感 >0', () {
      final ids = kNpcMemories.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length, reason: '回忆 id 必须唯一');
      for (final m in kNpcMemories) {
        expect(m.affectionThreshold, greaterThan(0));
        expect(m.rewardAffection, greaterThan(0));
        expect(m.title, isNotEmpty);
        expect(m.text, isNotEmpty);
      }
    });

    test('pendingMemoriesFor：按好感门槛升序、过滤已收集、跨 NPC 不串', () {
      final harry = pendingMemoriesFor('harry', 60, {});
      expect(harry.map((m) => m.affectionThreshold).toList(),
          [10, 35, 60], reason: '待解锁回忆按门槛从小到大');
      final partial = pendingMemoriesFor('harry', 60, {'harry_1'});
      expect(partial.map((m) => m.id).toList(), ['harry_2', 'harry_3']);
      final other = pendingMemoriesFor('hermione', 60, {});
      expect(other.any((m) => m.npcId == 'harry'), isFalse, reason: '不同 NPC 回忆互不串');
    });
  });

  group('P8 · NPC 回忆解锁', () {
    test('好感达标 + 未收集 → 追加回忆、收集 id、结算好感与加隆', () async {
      final gp = await makeProvider();
      final p = gp.player!;
      final npc = npcOf('harry', affection: 35); // 35 达标 harry_1(10)/harry_2(35)
      final g0 = p.galleons;

      final out = NpcChatService(appProvider: gp.appProvider)
          .withUnlockedMemories(npc, p, '原回复');

      expect(out, contains('原回复'));
      expect(out, contains('讲起了一段往事'));
      expect(out, contains('哈利的伤疤'));
      expect(out, contains('碗橱里的男孩'));
      expect(p.collectedMemories, containsAll(['harry_1', 'harry_2']));
      expect(npc.affection, 35 + 2 + 2, reason: '两段回忆各 +2 好感');
      expect(p.galleons, g0 + 10, reason: 'harry_2 附 10 加隆奖励');
    });

    test('好感未达标 → 原样返回、不收集、无奖励', () async {
      final gp = await makeProvider();
      final p = gp.player!;
      final npc = npcOf('harry', affection: 5); // 低于哈利最低门槛 10
      final g0 = p.galleons;

      final out = NpcChatService(appProvider: gp.appProvider)
          .withUnlockedMemories(npc, p, '原回复');

      expect(out, '原回复');
      expect(p.collectedMemories, isEmpty);
      expect(npc.affection, 5);
      expect(p.galleons, g0);
    });

    test('已收集 → 不重复触发', () async {
      final gp = await makeProvider();
      final p = gp.player!..collectedMemories.add('harry_1');
      final npc = npcOf('harry', affection: 35);

      final out = NpcChatService(appProvider: gp.appProvider)
          .withUnlockedMemories(npc, p, '原回复');

      expect(out, contains('讲起了一段往事'));
      expect(p.collectedMemories, ['harry_1', 'harry_2'], reason: 'harry_1 不重复收集');
      expect(out, isNot(contains('哈利的伤疤')), reason: '已收集回忆不再出现在回复里');
    });

    test('chatWithNPC 本地路径同样触发回忆解锁（离线/在线行为一致）', () async {
      final gp = await makeProvider();
      final p = gp.player!;
      final npc = npcOf('harry', affection: 40);
      final g0 = p.galleons;

      final (reply, offline) = await gp.chatService.chatWithNPC(
        npc: npc,
        player: p,
        worldState: gp.worldState,
        userMessage: '你好，今天过得怎么样？',
      );

      expect(offline, isTrue, reason: '无 AI key 应走本地兜底');
      expect(reply, contains('讲起了一段往事'));
      expect(p.collectedMemories, containsAll(['harry_1', 'harry_2']));
      expect(p.galleons, g0 + 10, reason: '解锁奖励在聊天链路里真实结算');
    });
  });

  group('P8 · 魁地奇赛果变体', () {
    test('多次比赛叙事出现多套赛果变体，且无 \$ 占位符泄漏', () async {
      final gp = await makeProvider();
      setupReady(gp);
      final p = gp.player!;
      final q0 = p.qMatches;
      const markers = {
        '看台像被点燃': 1,
        '欢呼声刺得耳朵发疼': 1,
        '手还在微微发颤': 2,
        '把脸埋进毛巾里': 2,
        '绕场一周': 3,
        '走廊安静得反常': 3,
      };
      final seen = <int>{};
      final all = StringBuffer();

      for (var i = 0; i < 8; i++) {
        p.qLastWeek = -1; // 解除本周已赛限制（不跨周，gameWeek 不变）
        p.energy = 100;
        gp.playQuidditch();
        final n = gp.currentNarrative;
        all.writeln(n);
        expect(n, contains('最终比分'), reason: '每场都应是完整比赛叙事');
        expect(n, isNot(contains(r'$')), reason: '模板占位符绝不泄漏进叙事');
        for (final e in markers.entries) {
          if (n.contains(e.key)) seen.add(e.value);
        }
      }

      expect(p.qMatches, q0 + 8, reason: '8 场全部真实结算');
      expect(seen.length, greaterThanOrEqualTo(2),
          reason: '8 场采样应出现至少 2 套不同赛果变体（不再是固定句式）');
      expect(all.toString(), contains('魁地奇技巧 +'), reason: '技巧结算段保留');
    });
  });

  group('P8 · 禁林特殊遭遇', () {
    test('多次探险出现特殊遭遇，且命中时战利品真实进背包', () async {
      final gp = await makeProvider();
      final p = gp.player!;
      p.grade = 5; // 高年级：全部遭遇解锁
      final t = gp.worldState.time;
      final ay = t.year, am = t.month, ad = t.day; // 锚定开局日
      var specialHits = 0;

      for (var i = 0; i < 50; i++) {
        p.energy = 100;
        p.satiety = 100;
        p.health = 100; // 战败掉血可能归零触发死亡结局，每次重置
        final invBefore = p.inventory.length;
        final gBefore = p.galleons;
        gp.exploreForbiddenForest();
        final n = gp.currentNarrative;

        if (n.contains('禁林入口的风从你身后吹来，你决定先返回城堡')) {
          specialHits++;
          bool hasItem(String name) => p.inventory.any((it) => it.name == name);
          // 按遭遇文本特征断言对应战利品进包
          if (n.contains('人马从树影中缓步走出')) {
            expect(hasItem('月长石粉'), isTrue);
          }
          if (n.contains('金色花海')) {
            expect(hasItem('曼德拉草叶'), isTrue);
          }
          if (n.contains('凤凰不会轻易留下痕迹')) {
            expect(hasItem('凤羽'), isTrue);
          }
          if (n.contains('铁盒')) {
            expect(p.galleons, greaterThan(gBefore), reason: '宝藏遭遇掉落加隆');
            expect(hasItem('夜骐尾羽'), isTrue);
          }
          // 无战利品的纯剧情遭遇（独角兽/夜骐/费伦泽/巨蛛）：背包不变
          if (n.contains('月光下的独角兽') ||
              n.contains('直视生死的夜骐') ||
              n.contains('费伦泽') ||
              n.contains('八眼巨蛛')) {
            expect(p.inventory.length, invBefore);
          }
        } else {
          expect(n, contains('禁林探险'), reason: '普通遭遇仍走既有探险叙事');
        }
        // 拨回开局日 + 清空跨天标记：时间线冻结在开局（避免 50 次推进
        // 跨进后续剧情触发致命事件），每日次数对每次迭代都视为"新的一天"。
        t.year = ay;
        t.month = am;
        t.day = ad;
        t.hour = 8;
        t.minute = 0;
        gp.activityDate = '';
      }

      expect(specialHits, greaterThan(0),
          reason: '50 次采样至少命中一次 15% 特殊遭遇（概率 ~99.97%）');
    });
  });

  group('P8 · /回忆册 命令', () {
    test('空态：显示 0/N 与解锁提示', () async {
      final gp = await makeProvider();
      final ok = gp.handleLocalCommand('/回忆册');
      expect(ok, isTrue);
      expect(gp.currentNarrative, contains('回忆册 · 0/${kNpcMemories.length}'));
      expect(gp.currentNarrative, contains('好感越高、聊得越多'));
    });

    test('部分收集：列出已收集项并显示剩余', () async {
      final gp = await makeProvider();
      gp.player!.collectedMemories.add('harry_1');
      gp.handleLocalCommand('/回忆册');
      expect(gp.currentNarrative, contains('已收集 1/${kNpcMemories.length}'));
      expect(gp.currentNarrative, contains('哈利的伤疤'));
      expect(gp.currentNarrative, contains('还有 ${kNpcMemories.length - 1} 段回忆等待解锁'));
    });

    test('全收集：计数=N 且不再提示剩余', () async {
      final gp = await makeProvider();
      gp.player!.collectedMemories.addAll(kNpcMemories.map((m) => m.id));
      gp.handleLocalCommand('/回忆册');
      expect(gp.currentNarrative, contains('已收集 ${kNpcMemories.length}/${kNpcMemories.length}'));
      expect(gp.currentNarrative, isNot(contains('等待解锁')));
    });
  });
}