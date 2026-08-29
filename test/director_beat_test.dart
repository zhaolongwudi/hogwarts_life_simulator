import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/director_beat_data.dart';

void main() {
  // ------------------------------------------------------------ 节拍选择
  group('导演指令的节拍选择', () {
    test('三回合一个循环，转折至少每三回合来一次', () {
      expect(directorBeatFor(turn: 0, hasUnresolvedHook: false), DirectorBeat.advance);
      expect(directorBeatFor(turn: 1, hasUnresolvedHook: false), DirectorBeat.daily);
      expect(directorBeatFor(turn: 2, hasUnresolvedHook: false), DirectorBeat.turn);
      // 第二轮同样
      expect(directorBeatFor(turn: 5, hasUnresolvedHook: false), DirectorBeat.turn);
    });

    test('上一回合停在半截时，轮到日常也要改判推进', () {
      // 读者正等着下文，此刻写气氛段落是最扫兴的
      expect(directorBeatFor(turn: 1, hasUnresolvedHook: true), DirectorBeat.advance);
      expect(directorBeatFor(turn: 4, hasUnresolvedHook: true), DirectorBeat.advance);
    });

    test('该转折的时候不被钩子抢走', () {
      expect(directorBeatFor(turn: 2, hasUnresolvedHook: true), DirectorBeat.turn);
      expect(directorBeatFor(turn: 0, hasUnresolvedHook: true), DirectorBeat.advance);
    });

    test('三种节拍在一个循环里都要出现，不能有一种永远轮不到', () {
      final seen = <DirectorBeat>{};
      for (var t = 0; t < 12; t++) {
        seen.add(directorBeatFor(turn: t, hasUnresolvedHook: false));
      }
      expect(seen, containsAll(DirectorBeat.values));
    });
  });

  // ------------------------------------------------------------ 指令文案
  group('导演指令的文案', () {
    test('每档都带标签和一句具体任务', () {
      for (final def in kDirectorBeats) {
        expect(def.label.isNotEmpty, isTrue);
        expect(def.task.isNotEmpty, isTrue);
        // 空话等于没说：任务描述不能只有十几个字
        expect(def.task.length, greaterThan(20));
      }
    });

    test('拼出来的行带【本回合任务】标记', () {
      for (final b in DirectorBeat.values) {
        final line = directorLineFor(b);
        expect(line.startsWith('【本回合任务】'), isTrue);
        expect(line.contains(beatDefFor(b).label), isTrue);
      }
    });
  });

  // ------------------------------------------------------------ 接线检查
  group('导演指令真的进了 prompt', () {
    test('叙事 prompt 里会注入', () {
      final src = File('lib/mixins/mixin_narrative.dart').readAsStringSync();
      expect(src.contains('directorLineFor'), isTrue);
      expect(src.contains('directorBeatFor(turn: turnCount'), isTrue);
      // 注入点得在返回模板里，光算出来不拼进去等于没做
      expect(src.contains(r'$directorLine'), isTrue);
    });

    test('复用了已经算好的钩子判定，不重复解析一遍叙事', () {
      final src = File('lib/mixins/mixin_narrative.dart').readAsStringSync();
      // hasHook 在停滞判定那里已经算过一次（那是一次正则匹配）
      expect(src.contains('hasUnresolvedHook: hasHook'), isTrue);
    });
  });

  // ------------------------------------------------------- 文风与在场规则
  group('文风硬规则', () {
    final src = File('lib/prompts/narrative_prompts.dart').readAsStringSync();

    test('视角与时态写死了', () {
      expect(src.contains('第二人称'), isTrue);
      expect(src.contains('现在时'), isTrue);
      // 光说"现在时"没用，得给正反例，否则模型不知道中文里怎么落
      expect(src.contains('你推开大门，冷风灌进来'), isTrue);
      expect(src.contains('你推开了大门，冷风灌了进来'), isTrue);
    });

    test('禁掉了 LLM 写中文叙事的高频套路', () {
      expect(src.contains('总结式收尾'), isTrue);
      expect(src.contains('自我提问'), isTrue);
      expect(src.contains('破折号'), isTrue);
      expect(src.contains('不要每回合都以环境描写开头'), isTrue);
    });
  });

  group('在场的人必须真的出场', () {
    final src = File('lib/prompts/narrative_prompts.dart').readAsStringSync();

    test('有【在场的人】这一段', () {
      // 【在场】名单早就拼进 prompt 了，但从没要求 AI 用它，
      // 结果 AI 常常无视名单自己造人
      expect(src.contains('【在场的人】'), isTrue);
      expect(src.contains('至少要有 1 人真的出场'), isTrue);
    });

    test('不许凭空拉进名单外的原作人物', () {
      expect(src.contains('名单之外的原作人物'), isTrue);
    });

    test('名单为空时不要硬塞人', () {
      expect(src.contains('别硬塞人'), isTrue);
    });
  });
}
