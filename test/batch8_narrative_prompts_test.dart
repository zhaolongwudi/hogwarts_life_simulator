import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/prompts/narrative_prompts.dart';

/// Issue #17：narrative_prompts 分级（T0 常挂 / T1 抽样 / T2 动态）
///
/// 设计审查发现的问题：`kNarrativeWritingRules` 是一个超长常量，
/// 每回合都完整注入 prompt，token 消耗高且注意力被稀释。
/// 修法：拆成 T0（铁律，必注入）/ T1（质量类，抽样注入）/ T2（动态按需），
/// 通过 `buildNarrativeRules` 按场景拼装。
void main() {
  // ==================== T0 铁律：每回合必注入 ====================
  group('T0 铁律必注入', () {
    test('T0 包含选项禁令', () {
      expect(kNarrativeRulesCore, contains('选项将由独立步骤生成'));
      expect(kNarrativeRulesCore, contains('不需要生成选项'));
    });

    test('T0 包含时间铁律', () {
      expect(kNarrativeRulesCore, contains('时间只能向前推进'));
      expect(kNarrativeRulesCore, contains('严禁时间倒退'));
    });

    test('T0 包含场景推进铁律', () {
      expect(kNarrativeRulesCore, contains('场景推进铁律'));
      expect(kNarrativeRulesCore, contains('严禁原地打转'));
    });

    test('T0 包含反玛丽苏/反天选', () {
      expect(kNarrativeRulesCore, contains('反玛丽苏'));
      expect(kNarrativeRulesCore, contains('天选之子'));
    });

    test('T0 包含数值禁令', () {
      expect(kNarrativeRulesCore, contains('严禁出现任何数值描述'));
    });

    test('T0 包含在场的人', () {
      expect(kNarrativeRulesCore, contains('【在场的人】'));
      expect(kNarrativeRulesCore, contains('至少要有 1 人真的出场'));
    });

    test('T0 包含好感度与声望格式', () {
      expect(kNarrativeRulesCore, contains('【好感度变化】'));
      expect(kNarrativeRulesCore, contains('【声望变化】'));
    });

    test('T0 不包含 T1 质量类内容（多样性规则应在 T1）', () {
      expect(kNarrativeRulesCore, isNot(contains('叙事多样性规则')));
    });

    test('T0 不包含 T2 动态内容（地点合法性应在 T2）', () {
      expect(kNarrativeRulesCore, isNot(contains('地点合法性·开学前')));
    });
  });

  // ==================== T1 质量类：抽样注入 ====================
  group('T1 质量类抽样', () {
    test('T1 包含叙事多样性规则', () {
      expect(kNarrativeRulesQuality, contains('叙事多样性规则'));
      expect(kNarrativeRulesQuality, contains('动作开篇'));
      expect(kNarrativeRulesQuality, contains('对话开篇'));
      expect(kNarrativeRulesQuality, contains('感官开篇'));
    });

    test('T1 包含节奏变化规则', () {
      expect(kNarrativeRulesQuality, contains('节奏要变化'));
    });

    test('T1 不包含 T0 铁律内容（铁律应在 T0）', () {
      expect(kNarrativeRulesQuality, isNot(contains('时间只能向前推进')));
      expect(kNarrativeRulesQuality, isNot(contains('反玛丽苏')));
    });

    test('shouldInjectQualityRules 每 3 回合注入一次', () {
      // turn 0, 3, 6, 9 注入；turn 1, 2, 4, 5 不注入
      expect(shouldInjectQualityRules(0), isTrue);
      expect(shouldInjectQualityRules(1), isFalse);
      expect(shouldInjectQualityRules(2), isFalse);
      expect(shouldInjectQualityRules(3), isTrue);
      expect(shouldInjectQualityRules(4), isFalse);
      expect(shouldInjectQualityRules(5), isFalse);
      expect(shouldInjectQualityRules(6), isTrue);
    });

    test('shouldInjectQualityRules 是确定性的（同一 turn 结果一致）', () {
      for (var t = 0; t < 100; t++) {
        final a = shouldInjectQualityRules(t);
        final b = shouldInjectQualityRules(t);
        expect(a, b, reason: 'turn=$t 结果不一致');
      }
    });
  });

  // ==================== T2 动态规则：按场景按需追加 ====================
  group('T2 动态规则', () {
    test('T2 地点合法性规则包含关键约束', () {
      expect(kNarrativeRuleLocationGate, contains('地点合法性·开学前'));
      expect(kNarrativeRuleLocationGate, contains('9 月 1 日'));
      expect(kNarrativeRuleLocationGate, contains('霍格沃茨城堡'));
    });

    test('isPreSchoolYear 7 月 31 日（开学前）', () {
      expect(isPreSchoolYear(7, 31), isTrue);
    });

    test('isPreSchoolYear 8 月 31 日（开学前最后一天）', () {
      expect(isPreSchoolYear(8, 31), isTrue);
    });

    test('isPreSchoolYear 9 月 1 日（开学当天，不算开学前）', () {
      expect(isPreSchoolYear(9, 1), isFalse);
    });

    test('isPreSchoolYear 9 月 2 日（学期中）', () {
      expect(isPreSchoolYear(9, 2), isFalse);
    });

    test('isPreSchoolYear 12 月 31 日（学期末）', () {
      expect(isPreSchoolYear(12, 31), isFalse);
    });

    test('isPreSchoolYear 1 月 1 日（寒假，算开学前）', () {
      expect(isPreSchoolYear(1, 1), isTrue);
    });

    test('isPreSchoolYear 6 月 30 日（暑假结束前）', () {
      expect(isPreSchoolYear(6, 30), isTrue);
    });
  });

  // ==================== buildNarrativeRules 拼装入口 ====================
  group('buildNarrativeRules 拼装', () {
    test('turn=0 时包含 T0 + T1（抽样命中）', () {
      final rules = buildNarrativeRules(turn: 0);
      expect(rules, contains('选项将由独立步骤生成')); // T0
      expect(rules, contains('叙事多样性规则')); // T1
    });

    test('turn=1 时只包含 T0（抽样未命中）', () {
      final rules = buildNarrativeRules(turn: 1);
      expect(rules, contains('选项将由独立步骤生成')); // T0
      expect(rules, isNot(contains('叙事多样性规则'))); // T1 缺席
    });

    test('turn=3 时包含 T0 + T1（抽样命中）', () {
      final rules = buildNarrativeRules(turn: 3);
      expect(rules, contains('叙事多样性规则'));
    });

    test('extraRules 非空时追加到末尾', () {
      final rules = buildNarrativeRules(
        turn: 1,
        extraRules: kNarrativeRuleLocationGate,
      );
      expect(rules, contains('地点合法性·开学前'));
      // extraRules 在 T1 之后（T1 缺席时也在 T0 之后）
      final coreIdx = rules.indexOf('选项将由独立步骤生成');
      final extraIdx = rules.indexOf('地点合法性·开学前');
      expect(extraIdx, greaterThan(coreIdx));
    });

    test('extraRules 为空时不追加', () {
      final rules = buildNarrativeRules(turn: 1, extraRules: '');
      expect(rules, isNot(contains('地点合法性')));
    });

    test('extraRules 为 null 时不追加', () {
      final rules = buildNarrativeRules(turn: 1);
      expect(rules, isNot(contains('地点合法性')));
    });

    test('T0 铁律永远存在（无论 turn 和 extraRules）', () {
      for (var t = 0; t < 10; t++) {
        final rules = buildNarrativeRules(turn: t);
        expect(rules, contains('选项将由独立步骤生成'),
            reason: 'turn=$t 缺少 T0 铁律');
        expect(rules, contains('时间只能向前推进'),
            reason: 'turn=$t 缺少时间铁律');
      }
    });
  });

  // ==================== 向后兼容 ====================
  group('向后兼容', () {
    test('kNarrativeWritingRules 别名指向 T0 铁律', () {
      expect(kNarrativeWritingRules, equals(kNarrativeRulesCore));
    });

    test('kNarrativeWritingRules 仍包含选项禁令（旧测试依赖）', () {
      expect(kNarrativeWritingRules, contains('选项将由独立步骤生成'));
    });
  });

  // ==================== 接线检查：mixin_narrative.dart 真的用了 buildNarrativeRules ====================
  group('接线检查', () {
    test('mixin_narrative.dart 调用了 buildNarrativeRules', () {
      final src = File('lib/mixins/mixin_narrative.dart').readAsStringSync();
      expect(src.contains('buildNarrativeRules('), isTrue);
    });

    test('mixin_narrative.dart 不再直接引用 kNarrativeWritingRules', () {
      final src = File('lib/mixins/mixin_narrative.dart').readAsStringSync();
      // 旧代码是 `$kNarrativeWritingRules`，新代码应改为 buildNarrativeRules(...)
      expect(src.contains(r'$kNarrativeWritingRules'), isFalse,
          reason: 'mixin_narrative.dart 仍直接引用 kNarrativeWritingRules，'
              '应改用 buildNarrativeRules 按场景拼装');
    });

    test('mixin_narrative.dart 按开学前判定注入 T2 地点合法性', () {
      final src = File('lib/mixins/mixin_narrative.dart').readAsStringSync();
      expect(src.contains('isPreSchoolYear('), isTrue);
      expect(src.contains('kNarrativeRuleLocationGate'), isTrue);
    });

    test('mixin_narrative.dart 传递 turnCount 给 buildNarrativeRules', () {
      final src = File('lib/mixins/mixin_narrative.dart').readAsStringSync();
      expect(src.contains('turn: turnCount'), isTrue);
    });
  });

  // ==================== token 节省验证 ====================
  group('token 节省', () {
    test('T0 比旧版 kNarrativeWritingRules 短（T1/T2 被拆出）', () {
      // 旧版 kNarrativeWritingRules 包含 T0 + T1 + T2 全部内容
      // 新版 T0 只含铁律，T1/T2 被拆出
      // 这里验证 T0 确实比 T0+T1+T2 的总和短
      final total = kNarrativeRulesCore.length +
          kNarrativeRulesQuality.length +
          kNarrativeRuleLocationGate.length;
      expect(kNarrativeRulesCore.length, lessThan(total));
    });

    test('T1 抽样时每 3 回合节省一次 T1 token', () {
      // turn=0: T0 + T1
      // turn=1: T0 only
      // turn=2: T0 only
      // 平均每 3 回合节省 1 次 T1 的 token
      final rules0 = buildNarrativeRules(turn: 0);
      final rules1 = buildNarrativeRules(turn: 1);
      expect(rules0.length, greaterThan(rules1.length));
      // 节省的 token 约等于 T1 的长度
      final saved = rules0.length - rules1.length;
      expect(saved, greaterThan(kNarrativeRulesQuality.length - 10));
      expect(saved, lessThan(kNarrativeRulesQuality.length + 10));
    });
  });
}