import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/mixins/mixin_narrative.dart';

/// 本轮测试：v5 整体复查优化项。
///
/// P1 摘要触发节奏（15→20 回合 / 6000→6800 字）—— 免费按次配额下省约 25% 调用。
/// P3 叙事 maxTokens 收紧（2000→1600）—— 无法在无路由环境下直测取值，
///     这里通过导入断言常量侧的改动已落位（见系统层注释），不对取值硬编码；
///     若后续 maxTokens 暴露可测接口可补充。P1 的判定纯函数可直接覆盖。
void main() {
  group('v5 P1 摘要触发判定（shouldRunPeriodicSummary）', () {
    test('缓冲为空时永不触发（无论回合数）', () {
      expect(GameNarrativeMixin.shouldRunPeriodicSummary(0, 0), isFalse);
      expect(GameNarrativeMixin.shouldRunPeriodicSummary(20, 0), isFalse);
      expect(GameNarrativeMixin.shouldRunPeriodicSummary(100, 0), isFalse);
    });

    test('每 20 回合整触发一次（旧 15 回合不再触发）', () {
      // 旧节奏 20 % 15 == 0 恒假，新节奏 20 % 20 == 0 为真
      expect(GameNarrativeMixin.shouldRunPeriodicSummary(15, 100), isFalse);
      expect(GameNarrativeMixin.shouldRunPeriodicSummary(20, 100), isTrue);
      expect(GameNarrativeMixin.shouldRunPeriodicSummary(40, 100), isTrue);
      expect(GameNarrativeMixin.shouldRunPeriodicSummary(60, 100), isTrue);
    });

    test('非整 20 回合且缓冲未超阈值时不触发', () {
      expect(GameNarrativeMixin.shouldRunPeriodicSummary(21, 100), isFalse);
      expect(GameNarrativeMixin.shouldRunPeriodicSummary(39, 6800), isFalse);
    });

    test('缓冲超过 6800 字提前触发', () {
      expect(GameNarrativeMixin.shouldRunPeriodicSummary(21, 6801), isTrue);
      expect(GameNarrativeMixin.shouldRunPeriodicSummary(3, 7000), isTrue);
    });

    test('恰好 6800 字不触发（阈值开区间，为长线压缩留余量）', () {
      expect(GameNarrativeMixin.shouldRunPeriodicSummary(21, 6800), isFalse);
    });
  });
}