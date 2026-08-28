import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/utils/confession_reply.dart';

void main() {
  group('表白回应解析（否定优先）', () {
    test('明确接受', () {
      expect(parseConfessionReply('我接受他的表白'), isTrue);
      expect(parseConfessionReply('接受'), isTrue);
      expect(parseConfessionReply('我愿意和你在一起'), isTrue);
      expect(parseConfessionReply('我也喜欢你'), isTrue);
      expect(parseConfessionReply('答应他'), isTrue);
    });

    test('回归：含「接受」的否定句必须判为拒绝（旧实现会误判为接受）', () {
      // 这几个用例是 bug 现场：旧代码 `action.contains('接受')` 先命中，
      // 导致「不接受」被结算成接受表白。
      expect(parseConfessionReply('不接受他的表白'), isFalse);
      expect(parseConfessionReply('我拒绝接受这份感情'), isFalse);
      expect(parseConfessionReply('我不能接受'), isFalse);
      expect(parseConfessionReply('无法接受，抱歉'), isFalse);
    });

    test('明确拒绝', () {
      expect(parseConfessionReply('婉拒他'), isFalse);
      expect(parseConfessionReply('拒绝'), isFalse);
      expect(parseConfessionReply('对不起，我们还是做朋友吧'), isFalse);
      expect(parseConfessionReply('还是算了'), isFalse);
      expect(parseConfessionReply('我不同意'), isFalse);
    });

    test('无法判断时返回 null（不改动恋爱状态）', () {
      expect(parseConfessionReply('我想先考虑一下'), isNull);
      expect(parseConfessionReply('今天天气不错'), isNull);
      expect(parseConfessionReply(''), isNull);
    });

    test('「不答应」「不愿意」优先于其中的肯定字眼', () {
      expect(parseConfessionReply('不答应'), isFalse);
      expect(parseConfessionReply('不愿意'), isFalse);
    });
  });
}
