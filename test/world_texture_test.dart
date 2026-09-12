import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/locations.dart';
import 'package:hogwarts_life_simulator/data/monthly_event_data.dart';
import 'package:hogwarts_life_simulator/data/npc_data.dart';
import 'package:hogwarts_life_simulator/data/npc_schedule_rules.dart';
import 'package:hogwarts_life_simulator/models/npc.dart';

/// 例外在一周里覆盖的小时数。跨午夜的按两段算。
int _hoursCovered(ScheduleException e) {
  if (e.fromHour == null && e.toHour == null) return 24 * 7;
  if (e.fromHour == null) return (e.toHour! + 1) * 7;
  if (e.toHour == null) return (24 - e.fromHour!) * 7;
  final span = e.fromHour! <= e.toHour!
      ? e.toHour! - e.fromHour! + 1
      : (24 - e.fromHour!) + e.toHour! + 1;
  return span * (e.weekday == null ? 7 : 1);
}

/// 造一个只带必要字段的 NPC，给 npcExpectedLocation 用。
NPC _npc(String id, {int grade = 1}) => NPC(
      id: id,
      name: id,
      house: '格兰芬多',
      grade: grade,
    );

void main() {
  // ============================================================ 例外表数据
  group('作息例外表', () {
    test('每一条都指向真实存在的 NPC', () {
      // 写一个不存在（或拼错）的 id 不会报错，
      // 只是这条例外永远不生效——跟没写一样，而且查不出来。
      final known = kAllNpcSeeds.map((s) => s.id).toSet();
      for (final e in kScheduleExceptions) {
        expect(known, contains(e.npcId),
            reason: '例外指向的 NPC "${e.npcId}" 不存在');
      }
    });

    test('每条都有 reason，而且写得够具体', () {
      // reason 是喂给 AI 的。短到"在熬药"这种程度，
      // AI 只能写出"斯内普在熬药"——那例外就白开了。
      for (final e in kScheduleExceptions) {
        expect(e.reason.trim(), isNotEmpty, reason: '${e.npcId} 没有理由');
        expect(e.reason.length, greaterThanOrEqualTo(30),
            reason: '${e.npcId} 的理由只有 ${e.reason.length} 字，太敷衍');
      }
    });

    test('地点名能解析', () {
      // 写一个 locations.dart 里没有的名字，NPC 会被放到一个
      // npcsInCurrentLocation() 永远匹配不上的地方——
      // 这个人就从世界里消失了。
      for (final e in kScheduleExceptions) {
        expect(locationKeywordResolvable(e.location), isTrue,
            reason: '${e.npcId} 的例外地点「${e.location}」解析不了');
      }
    });

    test('窗口要窄：覆盖大半天的例外不叫例外', () {
      // 例外之所以是例外，因为它少见。一条覆盖 10 小时的例外
      // 会退化成"这个人的新常态"，而推导表里那套逻辑就白写了。
      for (final e in kScheduleExceptions) {
        expect(_hoursCovered(e), lessThanOrEqualTo(6 * 7),
            reason: '${e.npcId} 的例外覆盖 ${_hoursCovered(e)} 小时，太宽了');
      }
    });

    test('整周占比极低：绝大多数时候他们还是在常规位置', () {
      // 把所有例外的覆盖时间加起来，也要远小于一周的总时长。
      // 这张表是调料，不是主菜。
      final total = kScheduleExceptions.fold<int>(
        0,
        (sum, e) => sum + _hoursCovered(e),
      );
      final weekHours = 24 * 7 * kScheduleExceptions.length;
      expect(total / weekHours, lessThan(0.15),
          reason: '例外总共覆盖了 ${(total / weekHours * 100).toStringAsFixed(1)}%'
              ' 的时间，太密了');
    });
  });

  // ============================================================ 例外判定
  group('例外判定', () {
    test('跨午夜的窗口：23-1 点命中，22 点和 2 点不命中', () {
      // 跨午夜是最容易写错的一处：`hour >= 23 && hour <= 1`
      // 这种写法永远为 false，那条例外就永远不生效。
      expect(scheduleExceptionFor('snape', 23, weekday: 2), isNotNull);
      expect(scheduleExceptionFor('snape', 0, weekday: 2), isNotNull);
      expect(scheduleExceptionFor('snape', 1, weekday: 2), isNotNull);
      expect(scheduleExceptionFor('snape', 22, weekday: 2), isNull);
      expect(scheduleExceptionFor('snape', 2, weekday: 2), isNull);
    });

    test('星期对不上就不生效', () {
      // 斯内普的例外是周二。周三晚上他在地窖，不该在教室。
      expect(scheduleExceptionFor('snape', 23, weekday: 3), isNull);
      expect(scheduleExceptionFor('snape', 23, weekday: 2), isNotNull);
    });

    test('不限星期的例外每天都生效', () {
      for (var d = 0; d < 7; d++) {
        expect(scheduleExceptionFor('dumbledore', 2, weekday: d), isNotNull,
            reason: '邓布利多的例外没有限定星期，星期$d 却没生效');
      }
    });

    test('没被点到名的人永远走常规位置', () {
      // ron 不在例外表里：任何时候查他都该落空。
      // 这条防的是"给一个人开了例外，结果全年级都被带过去了"。
      for (final hour in const [0, 3, 6, 7, 12, 21, 23]) {
        for (var d = 0; d < 7; d++) {
          expect(scheduleExceptionFor('ron', hour, weekday: d), isNull,
              reason: 'ron 没有作息例外，星期$d 的 $hour 点却命中了');
        }
      }
    });

    test('闭区间的两端都在内，外一格就在外', () {
      // hermione：周日 6-8 点。8 点算在内，9 点不算。
      expect(scheduleExceptionFor('hermione', 6, weekday: 0), isNotNull);
      expect(scheduleExceptionFor('hermione', 8, weekday: 0), isNotNull);
      expect(scheduleExceptionFor('hermione', 5, weekday: 0), isNull);
      expect(scheduleExceptionFor('hermione', 9, weekday: 0), isNull);
      // 周一早上她在教室/图书馆，不在例外里
      expect(scheduleExceptionFor('hermione', 7, weekday: 1), isNull);
    });
  });

  // ============================================================ 接线
  group('真的接进了游戏', () {
    test('例外会改写 NPC 的推算位置', () {
      // 只测数据不算接线：npcExpectedLocation 里没查例外的话，
      // 上面那些测试全过，世界里也什么都不会发生。
      final snape = _npc('snape', grade: 0);
      // 周二深夜：在教室熬药，不在地窖
      expect(npcExpectedLocation(snape, 23, weekday: 2), '霍格沃茨·教室');
      // 周三深夜：回地窖
      expect(npcExpectedLocation(snape, 23, weekday: 3), '霍格沃茨·地窖');
    });

    test('refreshNpcLocations 会把例外写进 currentLocation', () {
      final snape = _npc('snape', grade: 0);
      snape.currentLocation = '霍格沃茨·地窖';
      final changed = refreshNpcLocations([snape], 23, 2);
      expect(changed, 1);
      expect(snape.currentLocation, '霍格沃茨·教室');
    });

    test('prompt 里真的有一段【意外】', () {
      final src = File('lib/mixins/mixin_narrative.dart').readAsStringSync();
      expect(src.contains('scheduleExceptionFor('), isTrue,
          reason: '场景上下文里没有查作息例外——'
              'AI 只会看见"斯内普在教室"，不知道他在干什么');
      expect(src.contains('【意外·'), isTrue);
    });

    test('【意外】只在有人撞上时才会出现', () {
      // 它必须在 npcsHere 的循环里，不能无条件注入——
      // 否则每一回合都要为十几个不在场的人花 token。
      final src = File('lib/mixins/mixin_narrative.dart').readAsStringSync();
      final iBlock = src.indexOf('【意外·');
      final iHere = src.indexOf('for (final n in npcsHere)', iBlock - 400);
      expect(iHere, greaterThan(-1), reason: '【意外】段不在在场名单的循环里');
      expect(iHere, lessThan(iBlock));
    });
  });

  // ============================================================ 月度气氛
  group('月度气氛', () {
    test('12 个月都有', () {
      for (var m = 1; m <= 12; m++) {
        expect(atmosphereForMonth(m).trim(), isNotEmpty,
            reason: '$m 月没有气氛文案');
      }
    });

    test('月份越界给空串，不乱说', () {
      expect(atmosphereForMonth(0), isEmpty);
      expect(atmosphereForMonth(13), isEmpty);
      expect(atmosphereForMonth(-1), isEmpty);
    });

    test('每句都够长', () {
      // 短到"十月起雾"这种程度，AI 用不上——
      // 它需要的不是信息，是可以直接化进叙事里的画面。
      for (var m = 1; m <= 12; m++) {
        expect(atmosphereForMonth(m).length, greaterThanOrEqualTo(30),
            reason: '$m 月只有 ${atmosphereForMonth(m).length} 字');
      }
    });

    test('不提年份：五个时代都得能用', () {
      // 一旦写进"1991 年的秋天"，这条在其余四个时代就是穿帮。
      final yearRe = RegExp(r'1[89]\d\d|20[0-9]\d');
      for (var m = 1; m <= 12; m++) {
        final text = atmosphereForMonth(m);
        expect(yearRe.hasMatch(text), isFalse,
            reason: '$m 月的文案提到了具体年份：$text');
      }
    });

    test('不提人名、不提具体事件：那是新闻的事，不是底色', () {
      // 新闻（monthly_event_pool）可以提人名和事件，
      // 底色不行——它会跟事件锚点打架，也会被冷却之外的机制重复注入。
      for (var m = 1; m <= 12; m++) {
        final text = atmosphereForMonth(m);
        for (final name in const ['邓布利多', '哈利', '斯内普', '伏地魔', '海格']) {
          expect(text.contains(name), isFalse,
              reason: '$m 月的气氛提到了 $name，它该是新闻而不是底色');
        }
      }
    });

    test('12 句不重复', () {
      final seen = <String>{};
      for (var m = 1; m <= 12; m++) {
        seen.add(atmosphereForMonth(m));
      }
      expect(seen.length, 12, reason: '有月份的气氛文案是重复的');
    });

    test('prompt 里真的有一段【时令】', () {
      final src = File('lib/mixins/mixin_narrative.dart').readAsStringSync();
      expect(src.contains('atmosphereForMonth('), isTrue,
          reason: '场景上下文里没有注入月度气氛');
      expect(src.contains('【时令】'), isTrue);
    });
  });
}
