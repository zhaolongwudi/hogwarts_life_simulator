import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/utils/stagnation_detector.dart';

void main() {
  final d = StagnationDetector.instance;

  StagnationLevel eval({
    String location = '走廊',
    int turns = 0,
    bool hook = false,
    int turnCount = 10,
  }) =>
      d.evaluate(
        currentLocation: location,
        turnsAtSameLocation: turns,
        hasUnresolvedHook: hook,
        turnCount: turnCount,
      );

  group('阈值分级', () {
    test('家里/卧室 2 回合就催', () {
      expect(d.thresholdFor('家中'), 2);
      expect(d.thresholdFor('卧室'), 2);
    });

    test('重要剧情场景放宽到 6 回合', () {
      expect(d.thresholdFor('教室'), 6);
      expect(d.thresholdFor('图书馆'), 6);
      expect(d.thresholdFor('对角巷'), 6);
    });

    test('过路点 4 回合', () {
      expect(d.thresholdFor('走廊'), 4);
      expect(d.thresholdFor('城堡外的草坪'), 4);
    });

    test('空地点按家里处理，2 回合', () {
      expect(d.thresholdFor(''), 2);
    });
  });

  group('未决钩子判定', () {
    test('省略号算未决', () {
      expect(d.hasUnresolvedHook('他说到一半忽然停住了……'), isTrue);
    });

    test('「就在这时」「刚要」算未决', () {
      expect(d.hasUnresolvedHook('你刚要开口，门外传来脚步声'), isTrue);
    });

    test('普通叙述不算未决——否则强制推进永远发不出去', () {
      expect(d.hasUnresolvedHook('你沿着走廊慢慢走着，两侧的画像在低声交谈。'), isFalse);
    });

    test('只看末尾 200 字，开头有钩子不算', () {
      final long =
          '他举起魔杖瞄准你……' + '你沿着走廊慢慢走着。' * 40;
      expect(d.hasUnresolvedHook(long), isFalse);
    });
  });

  group('档位判定', () {
    test('没卡住且不在开局 → none', () {
      expect(eval(turns: 1), StagnationLevel.none);
    });

    test('过路点卡满 4 回合且无钩子 → forced', () {
      expect(eval(location: '走廊', turns: 4), StagnationLevel.forced);
    });

    test('有钩子时不发强制指令，避免打断正在进行的剧情', () {
      expect(eval(location: '走廊', turns: 6, hook: true),
          isNot(StagnationLevel.forced));
    });

    test('剧情进行中提前一回合给软提示', () {
      // 阈值 4，第 3 回合就提示，而不是等真卡满
      expect(eval(location: '走廊', turns: 3, hook: true),
          StagnationLevel.inProgress);
    });

    test('开局在家即使没卡满也催出门', () {
      expect(eval(location: '家中', turns: 0, turnCount: 1),
          StagnationLevel.earlyGame);
    });

    test('开局提示只在头 3 回合', () {
      expect(eval(location: '家中', turns: 0, turnCount: 4),
          isNot(StagnationLevel.earlyGame));
    });

    test('家里卡满 2 回合且无钩子 → forced 优先于 earlyGame', () {
      expect(eval(location: '家中', turns: 2, turnCount: 2),
          StagnationLevel.forced);
    });

    test('重要场景卡满 6 回合才强制', () {
      expect(eval(location: '教室', turns: 5), isNot(StagnationLevel.forced));
      expect(eval(location: '教室', turns: 6), StagnationLevel.forced);
    });
  });

  group('豁免场景补充说明', () {
    test('豁免地点给出额外说明', () {
      expect(d.exemptHint('教室'), contains('重要剧情场景'));
    });

    test('非豁免地点没有补充说明', () {
      expect(d.exemptHint('走廊'), isEmpty);
    });
  });

  group('判定逻辑只有一份', () {
    test('mixin 里不再各自内联阈值比较', () {
      final offenders = <String>[];
      for (final path in [
        'lib/mixins/mixin_narrative.dart',
        'lib/mixins/mixin_response.dart',
      ]) {
        final src = File(path).readAsStringSync();
        // 允许出现 stagnationThresholdFor 的调用（用于文案里的阈值数字），
        // 但不允许再拿它跟 turnsAtSameLocation 比大小——那是判定的活
        if (RegExp(r'turnsAtSameLocation\s*>=\s*threshold')
            .hasMatch(src.replaceAll(RegExp(r'//.*$'), ''))) {
          offenders.add(path);
        }
      }
      expect(offenders, isEmpty,
          reason: '停滞判定应统一走 StagnationDetector.evaluate，'
              '散落的阈值比较会让叙事端与选项端给出互相矛盾的指令：\n'
              '${offenders.join('\n')}');
    });

    test('两端都引用了同一个枚举', () {
      for (final path in [
        'lib/mixins/mixin_narrative.dart',
        'lib/mixins/mixin_response.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(src.contains('StagnationLevel'), isTrue, reason: path);
      }
    });
  });
}
