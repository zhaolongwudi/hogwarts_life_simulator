import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/director_beat_data.dart';

/// 永不抽中转折的 Random（nextDouble 恒大于任何概率）
class _NeverTurn implements Random {
  @override
  double nextDouble() => 0.999;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}

/// 永远抽中转折的 Random
class _AlwaysTurn implements Random {
  @override
  double nextDouble() => 0.0;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => true;
}

/// 固定掷出指定值的 Random（用于卡概率边界）
class _FixedRoll implements Random {
  _FixedRoll(this.value);
  final double value;

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => value < 0.5;
}

void main() {
  // ------------------------------------------------------------ 节拍选择
  group('导演指令的节拍选择', () {
    test('不抽中转折时，日常与推进交替出现', () {
      final rng = _NeverTurn();
      expect(
          directorBeatFor(turn: 0, hasUnresolvedHook: false, random: rng),
          DirectorBeat.advance);
      expect(
          directorBeatFor(turn: 1, hasUnresolvedHook: false, random: rng),
          DirectorBeat.daily);
      expect(
          directorBeatFor(turn: 2, hasUnresolvedHook: false, random: rng),
          DirectorBeat.advance);
      expect(
          directorBeatFor(turn: 3, hasUnresolvedHook: false, random: rng),
          DirectorBeat.daily);
    });

    test('转折有 2 回合最小间隔：刚转折过，掷骰再小也不转折', () {
      // turnsSinceLastTurn < 2 时连概率抽取都不进
      expect(
        directorBeatFor(
            turn: 2,
            hasUnresolvedHook: false,
            turnsSinceLastTurn: 1,
            random: _AlwaysTurn()),
        isNot(DirectorBeat.turn),
      );
    });

    test('久未转折时必然抽中（间隔够大 → 概率封顶 0.55，必中骰必转折）', () {
      expect(
        directorBeatFor(
            turn: 0,
            hasUnresolvedHook: false,
            turnsSinceLastTurn: 4,
            random: _FixedRoll(0.54)),
        DirectorBeat.turn,
      );
    });

    test('低张力场景转折概率减半', () {
      // turnsSinceLastTurn = 3 → 基础概率 0.45；roll 0.40：
      // 普通场景 0.40 < 0.45 抽中；低张力减半到 0.225 抽不中
      expect(
        directorBeatFor(
            turn: 0,
            hasUnresolvedHook: false,
            turnsSinceLastTurn: 3,
            calmContext: false,
            random: _FixedRoll(0.40)),
        DirectorBeat.turn,
      );
      expect(
        directorBeatFor(
            turn: 0,
            hasUnresolvedHook: false,
            turnsSinceLastTurn: 3,
            calmContext: true,
            random: _FixedRoll(0.40)),
        isNot(DirectorBeat.turn),
      );
    });

    test('上一回合停在半截时，轮到日常也要改判推进', () {
      // 读者正等着下文，此刻写气氛段落是最扫兴的
      expect(
          directorBeatFor(
              turn: 1, hasUnresolvedHook: true, random: _NeverTurn()),
          DirectorBeat.advance);
      expect(
          directorBeatFor(
              turn: 3, hasUnresolvedHook: true, random: _NeverTurn()),
          DirectorBeat.advance);
    });

    test('转折不被钩子拦截：转折本身就能收钩子', () {
      expect(
        directorBeatFor(
            turn: 2,
            hasUnresolvedHook: true,
            turnsSinceLastTurn: 5,
            random: _AlwaysTurn()),
        DirectorBeat.turn,
      );
    });

    test('长线模拟：转折不连续、不缺席太久、三种节拍都出现', () {
      // 守性质不守定义式：固定 seed 下模拟 300 回合，
      // 转折间隔恒 ≥2、相邻两次转折的间隔有界、三种节拍都轮得到。
      final rng = Random(42);
      final seen = <DirectorBeat>{};
      var sinceTurn = 99; // 开局即"很久没转折"——与生产侧初始值一致
      var maxGap = 0;
      var turnCount = 0;
      for (var t = 0; t < 300; t++) {
        final beat = directorBeatFor(
          turn: t,
          hasUnresolvedHook: false,
          turnsSinceLastTurn: sinceTurn,
          random: rng,
        );
        seen.add(beat);
        if (beat == DirectorBeat.turn) {
          expect(sinceTurn, greaterThanOrEqualTo(2),
              reason: '转折间隔不得小于 2 回合');
          // 首次转折的 sinceTurn=99 是初始值不是真间隔，从第二次起才统计
          if (turnCount > 0 && sinceTurn > maxGap) maxGap = sinceTurn;
          turnCount++;
          sinceTurn = 0;
        } else {
          sinceTurn++;
        }
      }
      expect(seen, containsAll(DirectorBeat.values));
      expect(turnCount, greaterThanOrEqualTo(10), reason: '300 回合里转折不该是稀有动物');
      expect(maxGap, lessThanOrEqualTo(15), reason: '转折不得缺席太久');
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
      expect(src.contains('directorBeatFor('), isTrue);
      expect(src.contains('turn: turnCount'), isTrue);
      // 注入点得在返回模板里，光算出来不拼进去等于没做
      expect(src.contains(r'$directorLine'), isTrue);
    });

    test('复用了已经算好的钩子判定，不重复解析一遍叙事', () {
      final src = File('lib/mixins/mixin_narrative.dart').readAsStringSync();
      // hasHook 在停滞判定那里已经算过一次（那是一次正则匹配）
      expect(src.contains('hasUnresolvedHook: hasHook'), isTrue);
    });

    test('节拍状态真的被追踪并回写', () {
      final src = File('lib/mixins/mixin_narrative.dart').readAsStringSync();
      // 概率化节拍依赖"距上次转折几回合"的状态，只算不回写等于没做
      expect(src.contains('turnsSinceLastTurnBeat'), isTrue);
      expect(src.contains('turnsSinceLastTurn: turnsSinceLastTurnBeat'), isTrue);
      // 场景感知接线
      expect(src.contains('calmContext:'), isTrue);
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
