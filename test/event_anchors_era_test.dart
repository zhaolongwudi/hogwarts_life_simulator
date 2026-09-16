import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/era_data.dart';
import 'package:hogwarts_life_simulator/data/event_anchors.dart';
import 'package:hogwarts_life_simulator/data/locations.dart';

/// 全部合法时代 key。与 [eraDefByEra] 能对上的才算数。
const List<String> kAllEraKeys = [
  'dumbledore',
  'marauders',
  'first_war',
  'harry_same',
  'post_war',
];

void main() {
  // ------------------------------------------------------------ 数据自洽
  group('锚点库数据自洽', () {
    test('id 唯一', () {
      final seen = <String>[];
      final dup = <String>[];
      for (final a in eventAnchors) {
        if (seen.contains(a.id)) {
          dup.add(a.id);
        } else {
          seen.add(a.id);
        }
      }
      expect(dup, isEmpty, reason: '重复的锚点 id: $dup');
    });

    test('era / excludedEras 只能填合法时代 key', () {
      for (final a in eventAnchors) {
        if (a.era != null) {
          expect(kAllEraKeys, contains(a.era),
              reason: '${a.id} 的 era="${a.era}" 不是合法时代 key');
        }
        for (final e in a.excludedEras) {
          expect(kAllEraKeys, contains(e),
              reason: '${a.id} 的 excludedEras 含非法值 "$e"');
        }
      }
    });

    test('era 与 excludedEras 不同时用在一个锚点上', () {
      // 同时写两边是自相矛盾：先按 era 筛、再按 excludedEras 排除，
      // 结果要么永远触发不了，要么永远排除不掉。
      for (final a in eventAnchors) {
        if (a.era != null) {
          expect(a.excludedEras, isEmpty,
              reason: '${a.id} 同时指定了 era 和 excludedEras');
        }
      }
    });

    test('月份在 1-12 之间，年级在 1-7 之间', () {
      for (final a in eventAnchors) {
        expect(a.month, inInclusiveRange(1, 12), reason: '${a.id} 月份越界');
        if (a.grade != null) {
          expect(a.grade, inInclusiveRange(1, 7), reason: '${a.id} 年级越界');
        }
      }
    });

    test('requiredLocation 必须是地点表里认得的词', () {
      // 写了认不出的地点，锚点会永远静默不触发——不报错、不写日志，
      // 只能靠"这个剧情怎么一直不出"来发现。
      for (final a in eventAnchors) {
        if (a.requiredLocation == null) continue;
        expect(locationKeywordResolvable(a.requiredLocation!), isTrue,
            reason: '${a.id} 的 requiredLocation="${a.requiredLocation}" '
                '在地点表里认不出来，这条锚点永远不会触发');
      }
    });

    test('requiredLocation 至少能匹配上一个已知地点', () {
      // 上一条只保证"词认得出来"，这条保证"真能匹配上"。
      // 两者都要：认得出来但谁都匹配不上的约束同样是死约束。
      for (final a in eventAnchors) {
        if (a.requiredLocation == null) continue;
        final hit = kLocationNames
            .where((loc) => locationMatches(loc, a.requiredLocation!));
        expect(hit, isNotEmpty,
            reason: '${a.id} 的 requiredLocation="${a.requiredLocation}" '
                '匹配不上任何一个已知地点');
      }
    });

    test('每个学年月份都有锚点，不留整月空白', () {
      final covered = eventAnchors.map((a) => a.month).toSet();
      final empty = <int>[];
      for (var m = 1; m <= 12; m++) {
        if (!covered.contains(m)) empty.add(m);
      }
      expect(empty, isEmpty,
          reason: '这些月份没有任何锚点，整整一个月的游戏内时间是空白: $empty');
    });
  });

  // ------------------------------------------- R17：子世代的压迫感升级
  group('R17 子世代专属锚点', () {
    /// 1991 入学的子世代，七年里逐年升级的压迫感线索。
    const List<String> kDarkRisingAnchors = [
      'g4_jun_dark_lord_return', // 四年级：赛事出了人命，官方说是意外
      'g5_oct_ministry_decree', // 五年级：新法令，有人在盯着
      'g5_dec_dementor_attack', // 五年级：摄魂怪与官方否认
      'g6_oct_classmate_loss', // 六年级：身边的人出事了
      'g6_jun_headmaster_fall', // 六年级：塔楼那一夜
      'g7_oct_on_the_run', // 七年级：点名、通缉、逃亡
      'g7_may_battle', // 七年级：城堡保卫战
    ];

    test('七条线索都存在且只属于 harry_same', () {
      final byId = {for (final a in eventAnchors) a.id: a};
      for (final id in kDarkRisingAnchors) {
        final a = byId[id];
        expect(a, isNotNull, reason: '缺少锚点 $id');
        expect(a!.era, 'harry_same', reason: '$id 应只属于子世代');
      }
    });

    test('每个年级至少有一条，压迫感逐年不断档', () {
      final byId = {for (final a in eventAnchors) a.id: a};
      for (final grade in [4, 5, 6, 7]) {
        final hit = kDarkRisingAnchors
            .map((id) => byId[id]!)
            .where((a) => a.grade == grade);
        expect(hit, isNotEmpty, reason: '${grade}年级没有子世代专属锚点');
      }
    });

    test('子世代按年级能依次触发到', () {
      // 模拟 1991 入学的一届，逐年走到对应月份，每条线索都应触发一次。
      final fired = <String>{};
      for (final a in eventAnchors) {
        if (!kDarkRisingAnchors.contains(a.id)) continue;
        final hit = anchorsFor(
          month: a.month,
          grade: a.grade!,
          era: 'harry_same',
          firedIds: fired,
        );
        expect(hit.map((e) => e.id), contains(a.id),
            reason: '${a.id} 在子世代的 ${a.month} 月没有触发');
        fired.add(a.id);
      }
    });

    test('这些线索不会串到别的时代去', () {
      for (final era in kAllEraKeys.where((e) => e != 'harry_same')) {
        for (final id in kDarkRisingAnchors) {
          final a = eventAnchors.firstWhere((e) => e.id == id);
          final hit = anchorsFor(
            month: a.month,
            grade: a.grade!,
            era: era,
            firedIds: const {},
          );
          expect(hit.map((e) => e.id), isNot(contains(id)),
              reason: '$id 不该出现在 $era 时代');
        }
      }
    });

    test('压迫感措辞保持旁观者视角，不把玩家塞成救世主', () {
      // 游戏核心理念是「你不是天命主角」。这些锚点写得再重，
      // 玩家也只能是听闻者、受波及者，不能变成力挽狂澜的人。
      final byId = {for (final a in eventAnchors) a.id: a};
      for (final id in kDarkRisingAnchors) {
        final d = byId[id]!.directive;
        for (final word in ['击败', '打败黑魔王', '拯救世界', '力挽狂澜', '命中注定']) {
          expect(d.contains(word), isFalse,
              reason: '$id 的指令里出现了「$word」，把玩家写成了救世主');
        }
      }
    });
  });

  // -------------------------------------------------- R18：时代穿帮过滤
  group('R18 时代穿帮过滤', () {
    test('三年级的尖叫棚屋传闻不会出现在 1892 年', () {
      // 尖叫棚屋是 1971 年为卢平建的，1892 年它还不存在。
      final hit1892 = anchorsFor(
        month: 11,
        grade: 3,
        era: 'dumbledore',
        firedIds: const {},
      );
      expect(hit1892.map((e) => e.id),
          isNot(contains('g3_nov_first_hogsmeade_trip')));

      // 1971 年入学的那一届正好赶上它落成，传闻就是从那时开始的。
      final hit1971 = anchorsFor(
        month: 11,
        grade: 3,
        era: 'marauders',
        firedIds: const {},
      );
      expect(hit1971.map((e) => e.id), contains('g3_nov_first_hogsmeade_trip'));
    });

    test('开学宴会的校长致辞排除了两端时代', () {
      // 1892 年邓布利多自己还是新生，2020 年他已逝世多年。
      final src = eventAnchors.firstWhere((a) => a.id == 'common_sep_feast');
      expect(src.excludedEras, contains('dumbledore'));
      expect(src.excludedEras, contains('post_war'));

      for (final era in const ['marauders', 'first_war', 'harry_same']) {
        final hit = anchorsFor(
          month: 9,
          grade: 1,
          era: era,
          firedIds: const {},
        );
        expect(hit.map((e) => e.id), contains('common_sep_feast'),
            reason: '$era 时代应该有开学宴会');
      }
    });

    test('每个时代每个月都有锚点可触发（不含年级限定的裸通用项除外）', () {
      // 防止某个时代被 era 过滤之后整片月份空白。
      for (final era in kAllEraKeys) {
        final months = <int>{};
        for (var m = 1; m <= 12; m++) {
          final hit = anchorsFor(
            month: m,
            grade: 3,
            era: era,
            firedIds: const {},
          );
          if (hit.isNotEmpty) months.add(m);
        }
        expect(months.length, greaterThanOrEqualTo(8),
            reason: '$era 时代只有 ${months.length} 个月有锚点，内容太薄');
      }
    });
  });
}
