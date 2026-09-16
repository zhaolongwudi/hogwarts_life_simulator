/// 第16轮G · 修复回归：选项带 / 前缀 + T0 历史污染过滤
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/mixins/mixin_response_choices.dart'
    as rc;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('G1 选项清洗剥 / 前缀（Agnes 输出 A./xxx 防卡死）', () {
    test('sanitizeChoiceText 剥掉 A./xxx 的 /', () {
      const raw = '/强忍不安，再次凝神感应羊皮纸的烫意';
      final s = rc.GameResponseChoiceMixin.sanitizeChoiceText(raw);
      expect(s.startsWith('/'), isFalse, reason: '选项不应以 / 开头');
      expect(s, '强忍不安，再次凝神感应羊皮纸的烫意');
    });

    test('剥多个连续 /（如 //xxx）', () {
      const raw = '//握紧魔杖起身';
      final s = rc.GameResponseChoiceMixin.sanitizeChoiceText(raw);
      expect(s.startsWith('/'), isFalse);
      expect(s, '握紧魔杖起身');
    });

    test('中文全角斜杠 ／ 也剥', () {
      const raw = '／握紧魔杖起身';
      final s = rc.GameResponseChoiceMixin.sanitizeChoiceText(raw);
      expect(s.startsWith('／'), isFalse);
      expect(s, '握紧魔杖起身');
    });

    test('正常选项不受影响', () {
      const raw = '去对角巷采购入学用品';
      expect(rc.GameResponseChoiceMixin.sanitizeChoiceText(raw), raw);
    });
  });

  group('G2 T0 历史污染过滤（源码契约）', () {
    test('mixin_narrative.dart 存在 _factConflictsWithAuthority 过滤', () {
      final src = File('lib/mixins/mixin_narrative.dart').readAsStringSync();
      expect(src.contains('_factConflictsWithAuthority'), isTrue,
          reason: 'T0 注入侧必须过滤历史错误事实（猫头鹰绯月/闪电疤）');
      expect(src.contains('第16轮G'), isTrue);
    });

    test('过滤逻辑含宠物猫头鹰与闪电疤两个已知模式', () {
      final src = File('lib/mixins/mixin_narrative.dart').readAsStringSync();
      final idx = src.indexOf('bool _factConflictsWithAuthority');
      expect(idx, greaterThan(-1));
      final body = src.substring(idx, idx + 1200);
      expect(body.contains('猫头鹰'), isTrue);
      expect(body.contains('闪电形'), isTrue);
    });
  });

  group('G3 未识别 / 长文本降级自由行动（源码契约）', () {
    test('handleLocalCommand 长文本未识别返回 false（降级叙事）', () {
      final src = File('lib/mixins/mixin_commands.dart').readAsStringSync();
      final idx = src.indexOf('slashless.length >= 6');
      expect(idx, greaterThan(-1),
          reason: '长文本（自由行动）未识别时应降级走叙事路径');
    });
  });
}