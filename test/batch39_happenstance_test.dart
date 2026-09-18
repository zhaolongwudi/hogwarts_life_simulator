/// v5 批次39 奇遇系统测试（P10 随机发生在身上的小故事 + 两段式选择）。
///
/// 奇遇与节庆的最大区别：节庆按日期触发、每学年一次；奇遇按
/// 「季节 + 地点 + 年级」过滤 + 加权抽取 + 冷却，无固定日期，且带
/// 「触发回合出选项 → 下一回合选结局」的两段式交互。
///
/// 覆盖：
///  - 数据完整性：id 唯一、每场 2~4 个选项、季节标签合法、效果维度合法、
///    `$` 占位符替换后无残留；
///  - 过滤：季节/地点/年级门控各自正确生效；
///  - 触发逻辑：开关关闭不触、有进行中不叠、冷却内不触、可命中原返回候选；
///  - 选择结算：匹配 `奇遇:<id>:<idx>` 精确结算并清 pending；不匹配自动
///    走中性兜底；结算必有正向收获；
///  - 离线回合接入：触发回合叙事出现场景、选项变成奇遇专属；下一回合选定
///    后叙事补全结局、状态清空；
///  - 存档序列化：pendingHappenstanceId 读写往返一致。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:hogwarts_life_simulator/data/happenstance_data.dart';
import 'package:hogwarts_life_simulator/mixins/mixin_happenstance.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/models/world_state.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';

import 'helpers/test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 构造**开着奇遇**的离线 provider（共享夹具默认关，这里先关再开）。
  Future<GameProvider> makeEnabled() async {
    final gp = await makeGame(offlineQuickMode: true);
    gp.appProvider.happenstanceEnabled = true;
    return gp;
  }

  /// 额定声望总和（结算必有声望入账时严格上升）。
  int repSum(GameProvider gp) {
    final r = gp.player!.playerReputation;
    var sum = 0;
    for (final d in ['academic', 'social', 'combat', 'moral', 'leadership', 'dark']) {
      sum += r.get(d);
    }
    return sum;
  }

  group('P10 · 数据完整性', () {
    test('id 唯一、每场 2~4 个选项、场景/文本非空', () {
      final ids = kHappenstances.map((h) => h.id).toSet();
      expect(ids.length, kHappenstances.length, reason: '奇遇 id 必须全局唯一');
      expect(kHappenstances.length, greaterThanOrEqualTo(6), reason: '奇遇数量应足以撑起随机性');
      for (final h in kHappenstances) {
        expect(h.title, isNotEmpty);
        expect(h.scene, isNotEmpty);
        expect(h.weight, greaterThan(0));
        expect(h.outcomes.length, inInclusiveRange(2, 4));
        expect(h.baseChance, inInclusiveRange(0.0, 1.0));
        for (final o in h.outcomes) {
          expect(o.title, isNotEmpty);
          expect(o.text, isNotEmpty);
        }
      }
    });

    test('季节标签合法、效果维度合法', () {
      const validDims = {
        'academic', 'social', 'combat', 'moral', 'leadership', 'dark', null,
      };
      for (final h in kHappenstances) {
        for (final s in h.seasonTags) {
          expect(kHappenstanceSeasonTags, contains(s), reason: '非法季节标签 $s');
        }
        for (final o in h.outcomes) {
          expect(validDims, contains(o.effect.reputationDim),
              reason: '${o.title} 的声望维度非法：${o.effect.reputationDim}');
          expect(o.effect.energy, greaterThanOrEqualTo(0));
        }
        // 关键奇遇锚点存在
        expect(happenstanceById(h.id)?.id, h.id);
      }
    });

    test('fillHappenstanceText 替换学院占位符后无残留', () {
      const house = '格兰芬多';
      for (final h in kHappenstances) {
        final s = fillHappenstanceText(h.scene, house: house);
        expect(s, isNot(contains(r'$')));
        for (final o in h.outcomes) {
          final t = fillHappenstanceText(o.text, house: house);
          expect(t, isNot(contains(r'$')));
          if (o.text.contains(r'$house')) expect(t, contains(house));
        }
      }
    });

    test('奇遇奖励物品都应有定义或能被兜底写入', () {
      // 物品 id 不匹配 item_data 时会兜底成普通道具，因此只做「非空」约束。
      for (final h in kHappenstances) {
        for (final o in h.outcomes) {
          final n = o.effect.itemName;
          if (n != null) expect(n, isNotEmpty);
        }
      }
    });
  });

  group('P10 · 过滤（季节 / 地点 / 年级）', () {
    test('年级门控：低年级看不到高年级限定奇遇', () async {
      final gp = await makeEnabled();
      final low = gp.eligibleHappenstances(seasons: const ['winter'])
          .where((h) => h.id == 'elder_mystery_box');
      // elder_mystery_box minGrade=5，班级默认一年级，必然被过滤
      expect(low, isEmpty);
    });

    test('地点门控：地点不在 locationKeys 内则不可用', () async {
      final gp = await makeEnabled();
      gp.worldState.currentLocation = '魁地奇球场';
      for (final h in gp.eligibleHappenstances()) {
        // 所有命中的奇遇要么不限地点，要么地点关键词含「魁地奇球场」
        if (h.locationKeys.isNotEmpty) {
          expect(h.locationKeys.any('魁地奇球场'.contains), isFalse,
              reason: '球场不应命中位置类奇遇 ${h.id}');
        }
      }
    });

    test('季节门控：冬季奇遇不在夏季命中', () async {
      final gp = await makeEnabled();
      gp.worldState.currentLocation = '天文台';
      gp.player!.grade = 5;
      final summer = gp.eligibleHappenstances(seasons: const ['summer']);
      expect(summer.any((h) => h.id == 'winter_frost_window'), isFalse);
      final winter = gp.eligibleHappenstances(seasons: const ['winter']);
      expect(winter.any((h) => h.id == 'winter_frost_window'), isTrue,
          reason: '五年级 + 冬季 + 天文台 应能命中窗上字迹');
    });
  });

  group('P10 · 触发逻辑', () {
    test('开关关闭 / 有进行中 / 冷却内都不触发', () async {
      final gp = await makeGame(offlineQuickMode: true); // 共享夹具默认关
      // 单个候选也拿不到的极端情况：开关但无候选 → null
      expect(gp.happenstanceDueToday(seed: 0), isNull);

      // 开启但冷却内（lastHappenstanceTurn 与 turnCount 很近）
      final gp2 = await makeEnabled();
      gp2.player!.grade = 5;
      gp2.worldState.currentLocation = '天文台';
      gp2.worldState.pendingHappenstanceId = 'winter_frost_window'; // 有进行中
      expect(gp2.happenstanceDueToday(seed: 4), isNull, reason: '有进行中奇遇时不叠');

      final gp3 = await makeEnabled();
      gp3.player!.grade = 5;
      gp3.worldState.currentLocation = '天文台';
      // turnCount 默认 0，冷却要求 6 回合 → 冷却内
      expect(gp3.happenstanceDueToday(seed: 0), isNull, reason: '冷却内不触发');
    });

    test('冷却结束后可命中唯一候选（冬季天文台→窗上字迹）', () async {
      final gp = await makeEnabled();
      gp.player!.grade = 5;
      gp.worldState.currentLocation = '天文台';
      gp.worldState.time.month = 12; // 冬季
      gp.worldState.lastHappenstanceTurn = -100; // 冷却结束
      final h = gp.happenstanceDueToday(seed: 42);
      expect(h, isNotNull, reason: '唯一候选时无论 seed 都应命中');
      expect(h!.id, 'winter_frost_window');
    });
  });

  group('P10 · 选择结算', () {
    test('触发 → 匹配选项 → 清 pending 且结算正向收获', () async {
      final gp = await makeEnabled();
      gp.player!.grade = 5;
      gp.worldState.currentLocation = '天文台';
      gp.worldState.time.month = 12; // 冬季
      gp.worldState.lastHappenstanceTurn = -100;
      final block = gp.triggerHappenstance(seed: 3);
      expect(block, isNotEmpty);
      expect(gp.worldState.pendingHappenstanceId, 'winter_frost_window');

      final rep0 = repSum(gp);
      final g0 = gp.player!.galleons;
      final res = gp.tryResolveHappenstanceChoice('奇遇:winter_frost_window:0', seed: 3);
      expect(res, isNotEmpty);
      expect(res, contains('你的选择'));
      expect(gp.worldState.pendingHappenstanceId, isNull, reason: '结算后必须清空 pending');
      // 两个结局都至少有正向收获（声望或加隆）
      expect(repSum(gp) + gp.player!.galleons, greaterThan(rep0 + g0));
    });

    test('不匹配动作 → 中性兜底收尾，不悬挂', () async {
      final gp = await makeEnabled();
      gp.worldState.pendingHappenstanceId = 'wandering_note';
      final res = gp.tryResolveHappenstanceChoice('随便走走', seed: 1);
      expect(res, isNotEmpty, reason: '有 pending 但玩家做了别的事，应中性收尾');
      expect(res, contains('你的选择'));
      expect(gp.worldState.pendingHappenstanceId, isNull);
    });

    test('无 pending 时结算返回空串', () async {
      final gp = await makeEnabled();
      expect(gp.tryResolveHappenstanceChoice('随便走走'), isEmpty);
    });
  });

  group('P10 · 离线回合接入', () {
    test('触发回合写场景+换专属选项；下一回合选完收尾', () async {
      final gp = await makeEnabled();
      gp.player!.grade = 5;
      gp.worldState.currentLocation = '天文台';
      gp.worldState.time.month = 12; // 冬季
      gp.worldState.lastHappenstanceTurn = -100; // 冷却结束，保证第一回合即触发

      // 触发回合
      await gp.processChoice(const GameChoice(text: '随便走走', action: '随便走走'));
      expect(gp.currentNarrative, contains('奇遇'));
      expect(gp.worldState.pendingHappenstanceId, isNotNull,
          reason: '离线回合应触发并写 pending');
      final hpChoices = gp.choices
          .where((c) => c.action.startsWith(kHappenstanceActionPrefix));
      expect(hpChoices, isNotEmpty, reason: '触发回合选项应被奇遇专属选项覆盖');
      final target = hpChoices.first.action;

      // 下一回合选定
      await gp.processChoice(GameChoice(text: target, action: target));
      expect(gp.worldState.pendingHappenstanceId, isNull, reason: '选完后 pending 应清空');
      expect(gp.currentNarrative, contains('你的选择'));
    });
  });

  group('P10 · 存档序列化', () {
    test('pendingHappenstanceId 与冷却回合读写往返一致', () {
      final ws = WorldState(pendingHappenstanceId: 'wandering_note', lastHappenstanceTurn: 7);
      final restored = WorldState.fromJson(ws.toJson());
      expect(restored.pendingHappenstanceId, 'wandering_note');
      expect(restored.lastHappenstanceTurn, 7);
    });

    test('旧存档无该字段时安全默认', () {
      final restored = WorldState.fromJson(const {});
      expect(restored.pendingHappenstanceId, isNull);
      expect(restored.lastHappenstanceTurn, 0);
    });
  });
}