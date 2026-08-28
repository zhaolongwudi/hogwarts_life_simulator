import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/models/game_systems.dart';
import 'package:hogwarts_life_simulator/models/player.dart';
import 'package:hogwarts_life_simulator/mixins/mixin_response.dart';

void main() {
  group('GameTime 整天快进', () {
    test('跨月：1991-09-01 快进 31 天 → 1991-10-02', () {
      final t = GameTime(year: 1991, month: 9, day: 1);
      t.advanceDays(31);
      expect(t.year, 1991);
      expect(t.month, 10);
      expect(t.day, 2);
    });

    test('跨年：1991-12-01 快进 60 天 → 1992-01-30', () {
      final t = GameTime(year: 1991, month: 12, day: 1);
      t.advanceDays(60);
      expect(t.year, 1992);
      expect(t.month, 1);
      expect(t.day, 30);
    });

    test('闰年：1992-02-27 快进 2 天 → 1992-02-29', () {
      final t = GameTime(year: 1992, month: 2, day: 27);
      t.advanceDays(2);
      expect(t.month, 2);
      expect(t.day, 29);
    });

    test('快进后星期与按日期构造的结果一致（不发生漂移）', () {
      final t = GameTime(year: 1991, month: 9, day: 1);
      t.advanceDays(123);
      final fresh = GameTime(year: t.year, month: t.month, day: t.day);
      expect(t.weekday, fresh.weekday);
      expect(GameTime.weekdays[t.weekday], GameTime.weekdays[fresh.weekday]);
    });

    test('快进后时刻落在早晨（不是深夜）', () {
      final t = GameTime(year: 1991, month: 9, day: 1, hour: 23, minute: 45);
      t.advanceDays(1);
      expect(t.hour, 8);
      expect(t.minute, 0);
    });

    test('非正数不推进', () {
      final t = GameTime(year: 1991, month: 9, day: 1);
      t.advanceDays(0);
      t.advanceDays(-5);
      expect('${t.year}-${t.month}-${t.day}', '1991-9-1');
    });
  });

  group('正文清洗：结构化区块不得泄漏进叙事', () {
    test('9 种选项块标题全部剥离', () {
      const blocks = [
        '可选行动',
        '自由行动',
        '行动建议',
        '备选行动',
        '剧情选项',
        '下回合选择',
        '选择建议',
        '行动选项',
        '你可以',
      ];
      for (final b in blocks) {
        final text = '你推开大门。\n【$b】\nA. 向左走\nB. 向右走';
        final out = stripStructuredSections(text);
        expect(out.contains('A. 向左走'), isFalse, reason: '区块【$b】未被剥离');
        expect(out.contains('推开大门'), isTrue, reason: '正文被误删（区块【$b】）');
      }
    });

    test('toEnd=true 时截断区块之后的所有内容', () {
      final out = stripStructuredSections('正文。\n【剧情选项】\nA. x\nB. y',
          toEnd: true);
      expect(out.trim(), '正文。');
    });

    test('bareLabel=true 支持无【】的「可选行动：」写法', () {
      final out = stripStructuredSections(
        '正文。\n可选行动：\nA. x\n【声望变化】\n学术: +3',
        bareLabel: true,
      );
      expect(out.contains('A. x'), isFalse);
      expect(out.contains('正文'), isTrue);
    });
  });

  group('声望派生值', () {
        Player makePlayer(Reputation r) =>
            Player(
                name: '测试',
                birthYear: '1980',
                bloodType: '混血',
                birthLocation: '伦敦',
                playerReputation: r);

    test('魔法界声望 = 五维均值（黑魔法不计入）', () {
      final p = makePlayer(Reputation(
        academic: 60,
        social: 40,
        combat: 30,
        moral: 50,
        leadership: 20,
        dark: 100, // 恶名不应拉高"魔法界声望"
      ));
      expect(p.wizardingReputation, 40);
    });

    test('阵营声望 = 黑魔法 − 道德，且带倾向解读', () {
      final dark = makePlayer(Reputation(dark: 80, moral: 20));
      expect(dark.factionReputation, 60);
      final light = makePlayer(Reputation(dark: 10, moral: 90));
      expect(light.factionReputation, -80);
    });

    test('回归：旧实现里两个派生声望恒为 0（现已随六维变化）', () {
      final p = makePlayer(Reputation(academic: 100));
      expect(p.wizardingReputation, 20);
      expect(p.wizardingReputation, isNot(0));
    });
  });
}
