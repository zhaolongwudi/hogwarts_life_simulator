import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/narrative_forward_rules.dart';

void main() {
  group('narrativeForwardRules · 学期内禁止学年收尾', () {
    for (final month in [9, 10, 11, 12, 1, 2, 3, 4, 5]) {
      test('学期内 $month 月 → 含学年收尾禁止项', () {
        final rules = narrativeForwardRules(
          month: month,
          graduated: false,
          grade: 3,
          isHarry: false,
        );
        expect(
          rules.any((r) => r.contains('学年结束') && r.contains('严禁')),
          isTrue,
          reason: '$month 月是学期内，必须禁止「学年结束/放暑假」',
        );
      });
    }

    test('6 月（学年收尾月）→ 不禁止学年收尾', () {
      final rules = narrativeForwardRules(
        month: 6,
        graduated: false,
        grade: 3,
        isHarry: false,
      );
      expect(rules.any((r) => r.contains('学年结束')), isFalse);
    });

    test('毕业后 → 不禁止学年收尾', () {
      final rules = narrativeForwardRules(
        month: 3,
        graduated: true,
        grade: 7,
        isHarry: false,
      );
      expect(rules.any((r) => r.contains('学年结束')), isFalse);
    });
  });

  group('narrativeForwardRules · 一年级战力防膨胀', () {
    test('一年级 → 含超纲魔法禁止项', () {
      final rules = narrativeForwardRules(
        month: 10,
        graduated: false,
        grade: 1,
        isHarry: false,
      );
      expect(rules.any((r) => r.contains('守护神咒')), isTrue);
    });

    test('高年级 → 不含超纲魔法禁止项', () {
      final rules = narrativeForwardRules(
        month: 10,
        graduated: false,
        grade: 5,
        isHarry: false,
      );
      expect(rules.any((r) => r.contains('守护神咒')), isFalse);
    });
  });

  group('narrativeForwardRules · 原创主角 ≠ 哈利', () {
    test('原创主角 → 含德思礼禁止项', () {
      final rules = narrativeForwardRules(
        month: 7,
        graduated: false,
        grade: 1,
        isHarry: false,
      );
      expect(rules.any((r) => r.contains('德思礼')), isTrue);
    });

    test('哈利本人 → 不含德思礼禁止项', () {
      final rules = narrativeForwardRules(
        month: 7,
        graduated: false,
        grade: 1,
        isHarry: true,
      );
      expect(rules.any((r) => r.contains('德思礼')), isFalse);
    });
  });

  group('prevWarnFeedbackLines · 上回合违规反馈', () {
    test('只取 warn 级、最多 2 条', () {
      final lines = prevWarnFeedbackLines([
        {'severity': 'warn', 'message': '违和A'},
        {'severity': 'critical', 'message': '严重B'},
        {'severity': 'warn', 'message': '违和C'},
        {'severity': 'warn', 'message': '违和D'},
      ]);
      expect(lines, ['• 违和A', '• 违和C']);
    });

    test('无 warn 违规 → 空列表', () {
      expect(
        prevWarnFeedbackLines([
          {'severity': 'critical', 'message': '严重B'},
        ]),
        isEmpty,
      );
    });
  });
}
