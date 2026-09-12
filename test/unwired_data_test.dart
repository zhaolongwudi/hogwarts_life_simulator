import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/course_data.dart';
import 'package:hogwarts_life_simulator/data/era_data.dart';
import 'package:hogwarts_life_simulator/data/game_config_rules.dart';
import 'package:hogwarts_life_simulator/data/monthly_event_data.dart';
import 'package:hogwarts_life_simulator/data/wand_data.dart';

void main() {
  // ==================== 在任校长 ====================
  // eraHeadmaster 以前是零引用的死表：开学宴的致辞者写死成「邓布利多式
  // 校长致辞」，可 1892 年邓布利多本人还是 11 岁的新生。

  group('在任校长表', () {
    test('五个时代都有校长，且 1892 年不是邓布利多', () {
      for (final def in allEraDefs) {
        if (def.eraKey == 'random') continue;
        expect(eraHeadmaster.containsKey(def.eraKey), isTrue,
            reason: '${def.eraKey} 没有校长条目');
      }
      expect(eraHeadmaster['dumbledore'], isNot(contains('邓布利多')),
          reason: '1892 年邓布利多还在上学，不能当校长');
      expect(eraHeadmaster['post_war'], contains('麦格'),
          reason: '1997 年之后校长是麦格');
    });

    test('未知时代给出不含人名的兜底，绝不能默认成邓布利多', () {
      final fallback = headmasterLineForEra('some_unknown_era');
      expect(fallback, isNotEmpty);
      expect(fallback, isNot(contains('邓布利多')));
      expect(fallback, isNot(contains('麦格')));
    });

    test('校长表真的进了 prompt', () {
      final src = File('lib/mixins/mixin_narrative.dart').readAsStringSync();
      expect(src, contains('headmasterLineForEra'),
          reason: 'eraHeadmaster 又变成没人读的死表了');
    });
  });

  // ==================== 杖芯 ====================

  group('杖芯特质真的有效果', () {
    test('三种杖芯的施法/威力修正各不相同', () {
      final cores = wandCoreTraits.keys.toList();
      expect(cores, hasLength(3));
      final cast = cores.map(wandCoreCastBonusFor).toSet();
      final power = cores.map(wandCorePowerBonusFor).toSet();
      // 独角兽毛稳、龙心弦狠、凤凰居中：三种不能是同一个数
      expect(cast.length, greaterThan(1), reason: '三种杖芯的施法修正完全一样');
      expect(power.length, greaterThan(1), reason: '三种杖芯的威力修正完全一样');
    });

    test('每一条 wandCoreTraits 都配了数值修正', () {
      for (final core in wandCoreTraits.keys) {
        expect(wandCoreCastBonus.containsKey(core), isTrue,
            reason: '$core 有描述但没有施法修正');
        expect(wandCorePowerBonus.containsKey(core), isTrue,
            reason: '$core 有描述但没有威力修正');
      }
    });

    test('每支魔杖的杖芯都在特质表里（否则选了等于没选）', () {
      for (final w in wands) {
        expect(wandCoreTraits.containsKey(w.core), isTrue,
            reason: '${w.name} 的杖芯「${w.core}」不在 wandCoreTraits 里');
      }
    });

    test('未知杖芯按 0 处理，不给意外加成也不惩罚', () {
      expect(wandCoreCastBonusFor(null), 0.0);
      expect(wandCorePowerBonusFor(null), 0.0);
      expect(wandCoreCastBonusFor('未知杖芯'), 0.0);
    });

    test('杖芯修正真的进了决斗公式', () {
      final src = File('lib/mixins/mixin_play.dart').readAsStringSync();
      expect(src, contains('wandCoreCastBonusFor'),
          reason: '施法成功率没算杖芯，选魔杖只是选了段描述文字');
      expect(src, contains('wandCorePowerBonusFor'));
    });
  });

  // ==================== 地图区域解锁 ====================
  // unlockCondition 以前只在 /地点 里当文案打印：写着「高年级开放」的
  // 禁林，一年级新生照样能一个人走进去。

  group('地图区域解锁真的会判定', () {
    test('禁林一年级进不去，二年级可以', () {
      final forest = mapRegions.firstWhere((r) => r.name.contains('禁林'));
      expect(forest.isUnlocked(grade: 1, isWeekend: true), isFalse);
      expect(forest.isUnlocked(grade: 2, isWeekend: true), isTrue);
    });

    test('霍格莫德三年级才开，而且只在周末', () {
      final hogsmeade = mapRegions.firstWhere((r) => r.name.contains('霍格莫德'));
      expect(hogsmeade.isUnlocked(grade: 3, isWeekend: false), isFalse);
      expect(hogsmeade.isUnlocked(grade: 2, isWeekend: true), isFalse);
      expect(hogsmeade.isUnlocked(grade: 3, isWeekend: true), isTrue);
    });

    test('没写条件的区域默认开放', () {
      for (final r in mapRegions) {
        if (r.unlockCondition == null) {
          expect(r.isUnlocked(grade: 1, isWeekend: false), isTrue,
              reason: '${r.name} 没有解锁条件却进不去');
        }
      }
    });

    test('年级未知（还没入学）按一年级算，不会误开放受限区域', () {
      expect(lockedRegionsFor(grade: null, isWeekend: true)
          .any((r) => r.name.contains('霍格莫德')), isTrue);
    });

    test('开放/未开放两份判定互为补集', () {
      for (final grade in [1, 2, 3, 7]) {
        for (final weekend in [true, false]) {
          final open = unlockedRegionsFor(grade: grade, isWeekend: weekend);
          final shut = lockedRegionsFor(grade: grade, isWeekend: weekend);
          expect(open.length + shut.length, mapRegions.length);
          expect(open.toSet().intersection(shut.toSet()), isEmpty);
        }
      }
    });

    test('未开放区域会注入 prompt（否则 AI 照样写「独自深入禁林」）', () {
      final src = File('lib/mixins/mixin_narrative.dart').readAsStringSync();
      expect(src, contains('lockedRegionsFor'),
          reason: '解锁条件又变回只打印不判定的文案了');
    });
  });

  // ==================== 月度事件互斥 ====================
  // mutuallyExclusiveIds 声明了、注释写了，但抽取时一次都没读过，
  // 而且 27 条数据里没有任何一条填过它。

  group('月度事件互斥与去重', () {
    test('互斥关系双向声明（A 写了 B，B 也要写 A）', () {
      final byId = {for (final e in monthlyEventPool) e.id: e};
      for (final e in monthlyEventPool) {
        for (final otherId in e.mutuallyExclusiveIds) {
          final other = byId[otherId];
          expect(other, isNotNull,
              reason: '${e.id} 的互斥表里写了不存在的 id：$otherId');
          expect(other!.mutuallyExclusiveIds, contains(e.id),
              reason: '${e.id} 声明了与 $otherId 互斥，但 $otherId 没有反向声明');
        }
      }
    });

    test('互斥表里的 id 都存在（没有拼错的死引用）', () {
      final ids = monthlyEventPool.map((e) => e.id).toSet();
      for (final e in monthlyEventPool) {
        for (final otherId in e.mutuallyExclusiveIds) {
          expect(ids, contains(otherId), reason: '${e.id} → $otherId 不存在');
        }
      }
    });

    test('确实有数据用上了互斥（不能只是字段声明）', () {
      final used = monthlyEventPool
          .where((e) => e.mutuallyExclusiveIds.isNotEmpty)
          .length;
      expect(used, greaterThanOrEqualTo(6),
          reason: '只有 $used 条事件用了互斥，这个字段又成了摆设');
    });

    test('事件 id 不重复', () {
      final ids = monthlyEventPool.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('抽取时真的会按互斥/冷却剔除候选', () {
      final src = File('lib/mixins/mixin_systems.dart').readAsStringSync();
      final body = src.substring(src.indexOf('_generateMonthlyEvent'));
      expect(body, contains('mutuallyExclusiveIds'),
          reason: '抽取逻辑没读过 mutuallyExclusiveIds');
      expect(body, contains('monthlyEventFiredAt'),
          reason: '没有记账就拿不到"上次什么时候播过"');
      expect(body, isNot(contains('这里简化')));
    });
  });

  // ==================== 死数据 ====================

  group('被取代的旧模型没有复活', () {
    test('game_systems.dart 里没有零引用的空壳模型', () {
      final src = File('lib/models/game_systems.dart').readAsStringSync();
      expect(src, isNot(contains('class AffectionLock')),
          reason: 'AffectionLock 又回来了，好感锁的实际实现是 NPC.affectionLocks');
      expect(src, isNot(contains('class CollectionItem')),
          reason: 'CollectionItem 又回来了，收藏的实际实现在 collectible_data.dart');
    });
  });
}
