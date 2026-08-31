/// 2026-09-01 第九轮全面审查修复的回归测试。
///
/// 本轮审查修复的关键 bug：
///  1. narrativeEventProbe：短事件文本（<10 字）substring 越界崩溃（S1）。
///     mixin_narrative 离线模式用该函数做「叙事去重探测」，原实现
///     `substring(0, length.clamp(10,40))` 在事件文本短于 10 字时抛 RangeError。
///  2. 分院识别主语锚点（M6）改为动态 player.name 后，正则改为运行时拼接，
///     此文件不直接覆盖（需要完整 GameProvider 实例），详见 mixin_response.dart。
import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/mixins/mixin_narrative.dart';

void main() {
  group('narrativeEventProbe（短事件文本不崩，S1 回归）', () {
    test('短于 10 字的文本原样返回，不再越界', () {
      expect(narrativeEventProbe('巨怪'), '巨怪');
      expect(narrativeEventProbe('雪崩'), '雪崩');
      expect(narrativeEventProbe('今天无事发生'), '今天无事发生');
    });

    test('空文本安全返回', () {
      expect(narrativeEventProbe(''), '');
    });

    test('10~40 字文本原样返回', () {
      final s = '十二个字的事件文本内容';
      expect(narrativeEventProbe(s), s);
    });

    test('超过 40 字截断为前 40 字', () {
      final long = '这是一条非常长非常长非常长非常长非常长非常长非常长的世界事件描述文本，'
          '远远超过了四十个字的长度限制，需要被截断成探测片段。';
      final probe = narrativeEventProbe(long);
      expect(probe.length, 40);
      expect(long.startsWith(probe), isTrue);
    });
  });
}
