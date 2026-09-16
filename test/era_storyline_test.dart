import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/era_data.dart';
import 'package:hogwarts_life_simulator/data/event_anchors.dart';
import 'package:hogwarts_life_simulator/data/worldline_data.dart';
import 'package:hogwarts_life_simulator/providers/app_provider.dart';

/// 全部合法时代 key。
const List<String> kEraKeys = [
  'dumbledore',
  'marauders',
  'first_war',
  'harry_same',
  'post_war',
];

/// 本批新增的四个时代（harry_same 本来就有一套完整主线）。
const List<String> kNewStorylineEras = [
  'dumbledore',
  'marauders',
  'first_war',
  'post_war',
];

/// 只属于某个时代的锚点。
List<EventAnchor> _exclusiveFor(String era) =>
    eventAnchors.where((a) => a.era == era).toList();

/// 模拟一个时代走完七年，返回**按时间顺序**实际会触发的专属锚点。
///
/// 走法跟真机一致：每个年级、1-12 月各扫一遍，触发过的 id 记进 fired，
/// 之后不再触发（anchorsFor 就是这么筛的）。
List<EventAnchor> _playThrough(String era) {
  final fired = <String>{};
  final hit = <EventAnchor>[];
  for (var grade = 1; grade <= 7; grade++) {
    for (var month = 1; month <= 12; month++) {
      final due = anchorsFor(
        month: month,
        grade: grade,
        era: era,
        firedIds: fired,
      );
      for (final a in due) {
        if (a.era != era) continue; // 只要时代专属的
        fired.add(a.id);
        hit.add(a);
      }
    }
  }
  return hit;
}

void main() {
  // ================================================================ 覆盖
  group('每个时代都得有自己的主线', () {
    for (final era in kNewStorylineEras) {
      test('$era 有时代专属锚点（≥6 条）', () {
        final n = _exclusiveFor(era).length;
        expect(n, greaterThanOrEqualTo(6),
            reason: '$era 只有 $n 条专属锚点，七年里会没有主线');
      });
    }

    test('五个时代全部有专属锚点，不只是 harry_same', () {
      // 这一条是整个批次存在的理由：在补这批之前，
      // 9 条时代专属锚点全部是 harry_same 的，
      // 其余四个时代走完七年一条主线都碰不到。
      for (final era in kEraKeys) {
        expect(_exclusiveFor(era), isNotEmpty, reason: '$era 一条专属锚点都没有');
      }
    });

    test('专属锚点不会串到别的时代', () {
      for (final era in kEraKeys) {
        final others = kEraKeys.where((e) => e != era);
        for (final a in _exclusiveFor(era)) {
          for (final other in others) {
            final leaked = anchorsFor(
              month: a.month,
              grade: a.grade ?? 1,
              era: other,
              firedIds: const {},
            );
            expect(leaked.where((x) => x.id == a.id), isEmpty,
                reason: '${a.id}（$era 专属）在 $other 时代也会触发');
          }
        }
      }
    });

    test('时代专属锚点全部带年级', () {
      // 不带年级的锚点每年都会重复参与筛选。时代主线应该按年推进，
      // 否则七年里同一件事会被念七遍。
      for (final era in kEraKeys) {
        for (final a in _exclusiveFor(era)) {
          expect(a.grade, isNotNull, reason: '${a.id} 是时代主线，却没定年级');
        }
      }
    });
  });

  // ================================================================ 可达
  group('走完七年真的能碰到它们', () {
    for (final era in kNewStorylineEras) {
      test('$era 七年里能触发的专属锚点 ≥6 条', () {
        final hit = _playThrough(era);
        expect(hit.length, greaterThanOrEqualTo(6),
            reason: '$era 七年只触发了 ${hit.length} 条专属锚点');
      });
    }

    test('每个时代每一年都有东西发生', () {
      // 不能出现"某个年级整年空白"——玩家会在那一年明显感觉到游戏没内容。
      for (final era in kNewStorylineEras) {
        final hit = _playThrough(era);
        for (var grade = 1; grade <= 7; grade++) {
          final inYear = hit.where((a) => a.grade == grade).length;
          expect(inYear, greaterThan(0), reason: '$era 的 ${grade}年级整年没有专属锚点');
        }
      }
    });

    test('七年里触发的都是不同的锚点（不会重复触发同一条）', () {
      for (final era in kNewStorylineEras) {
        final hit = _playThrough(era);
        final ids = hit.map((a) => a.id).toList();
        expect(ids.toSet().length, ids.length,
            reason: '$era 有锚点在七年里被重复触发');
      }
    });
  });

  // ================================================================ 穿帮
  group('时代穿帮', () {
    test('1892 邓布利多时代不能叫他校长', () {
      // 1892-99 年他在念书，1956 年才当上校长。
      // 这是这个世界里最容易犯的时代错误——他太有名了。
      for (final a in _exclusiveFor('dumbledore')) {
        final text = '${a.title}${a.directive}';
        expect(text.contains('校长'), isFalse,
            reason: '${a.id} 提到了"校长"：1892 年他还只是一年级新生');
      }
    });

    test('1892 时代不该出现伏地魔', () {
      // 汤姆·里德尔 1927 年生，1892-99 年他连他妈都还没出生。
      for (final a in _exclusiveFor('dumbledore')) {
        final text = '${a.title}${a.directive}';
        expect(text.contains('伏地魔'), isFalse,
            reason: '${a.id} 提到了伏地魔：1892 年他还没出生');
      }
    });

    test('1892 时代格林德沃只能出现在毕业之后', () {
      // 原著里格林德沃 1899 年夏才到戈德里克山谷，那时邓布利多已毕业。
      // 所以这批锚点里，涉及他的那条必须是七年级的——而且是"毕业之后
      // 传回来的消息"，不是玩家在校亲历。
      for (final a in _exclusiveFor('dumbledore')) {
        final text = '${a.title}${a.directive}';
        if (!text.contains('德姆斯特朗')) continue;
        expect(a.grade, 7,
            reason: '${a.id} 提到了德姆斯特朗来的少年，但它是 ${a.grade} 年级的');
      }
    });

    test('1971 与 1976 时代不该出现哈利', () {
      // 哈利 1980 年生。1971 入学的玩家毕业时才 1978 年；
      // 1976 入学的玩家五年级（1980-81）那年他才刚出生——
      // 所以这两批锚点里都不该直接点名。
      for (final era in const ['marauders', 'first_war']) {
        for (final a in _exclusiveFor(era)) {
          final text = '${a.title}${a.directive}';
          expect(text.contains('哈利'), isFalse,
              reason: '${a.id}（$era）点名了哈利，太早了');
        }
      }
    });

    test('每条锚点都有 title 和非空的 directive', () {
      for (final a in eventAnchors) {
        expect(a.title.trim(), isNotEmpty, reason: '${a.id} 没有标题');
        expect(a.directive.trim(), isNotEmpty, reason: '${a.id} 没有指令');
      }
    });

    test('directive 够长，不是在给 AI 出填空题', () {
      // 短指令等于没写：AI 会把它当成背景说明而不是"这一回合要干嘛"。
      for (final era in kNewStorylineEras) {
        for (final a in _exclusiveFor(era)) {
          expect(a.directive.length, greaterThanOrEqualTo(60),
              reason: '${a.id} 的指令只有 ${a.directive.length} 字，太短');
        }
      }
    });
  });

  // ================================================================ 因果锚点
  group('因果锚点挂接', () {
    test('新挂的两条找得到对应的事件锚点', () {
      // 挂空的因果锚点是死数据：causalAnchorFor 永远返回 null，
      // 抉择永远不会出现，而没有任何报错。
      for (final id in const ['mr_g5_jun_worst_memory', 'fw_g6_nov_he_is_gone']) {
        expect(causalAnchorFor(id), isNotNull, reason: '$id 没有对应的因果锚点');
        expect(eventAnchors.any((a) => a.id == id), isTrue,
            reason: '因果锚点 $id 挂的事件锚点根本不存在');
      }
    });

    test('每个因果锚点都挂在一个真实存在的事件锚点上', () {
      final allIds = eventAnchors.map((a) => a.id).toSet();
      for (final c in kCausalAnchors) {
        expect(allIds, contains(c.anchorId),
            reason: '因果锚点 ${c.anchorId} 挂空了');
      }
    });

    test('因果锚点的时代要和它挂的事件锚点对得上', () {
      // 对不上就永远解锁不了：事件锚点只在 marauders 触发，
      // 而因果锚点只在 harry_same 解锁，两者永不相见。
      for (final c in kCausalAnchors) {
        final host = eventAnchors.where((a) => a.id == c.anchorId).firstOrNull;
        if (host == null) continue;
        if (c.era == null) continue;
        expect(host.era, c.era,
            reason: '${c.anchorId}：事件锚点是 ${host.era}，因果锚点却限定 ${c.era}');
      }
    });

    test('干预选项留痕迹，旁观选项不留', () {
      // echo 是"世界真的被改写过"的唯一凭证。
      // 旁观留 echo 会把没发生过的改写写进【已被你改写的事】。
      for (final c in kCausalAnchors) {
        for (final o in c.options) {
          if (o.id == 'standAside') {
            expect(o.echo, isEmpty, reason: '${c.anchorId} 的旁观选项留了痕迹');
          } else {
            expect(o.echo, isNotEmpty,
                reason: '${c.anchorId} 的干预选项「${o.text}」没有留痕迹');
          }
        }
      }
    });

    test('选项的 action 是具体动作，不是选项标签', () {
      // action 会当成玩家输入直接发给叙事 AI。
      // 写"选项A"或者跟 text 一模一样，AI 接不住，会自己编一段。
      for (final c in kCausalAnchors) {
        for (final o in c.options) {
          expect(o.action.trim(), isNotEmpty, reason: '${c.anchorId} 有空动作');
          expect(o.action.length, greaterThanOrEqualTo(10),
              reason: '${c.anchorId} 的「${o.text}」动作太短："${o.action}"');
          expect(o.action, isNot(equals(o.text)),
              reason: '${c.anchorId} 的「${o.text}」把标签当动作发给了 AI');
          expect(o.action.startsWith('选项'), isFalse,
              reason: '${c.anchorId} 的「${o.text}」动作写的是选项编号');
        }
      }
    });

    test('每条因果锚点至少有一个干预选项', () {
      for (final c in kCausalAnchors) {
        expect(c.options.where((o) => o.isIntervention), isNotEmpty,
            reason: '${c.anchorId} 没有任何干预选项，那这一夜就只是走过场');
      }
    });

    test('新挂的两条都有门槛，且不是最低档', () {
      // 这两条改的是配角命运，不该在世界线还没松动时就能碰到。
      for (final id in const ['mr_g5_jun_worst_memory', 'fw_g6_nov_he_is_gone']) {
        final c = causalAnchorFor(id)!;
        expect(c.minStage.index, greaterThan(WorldLineStage.fraying.index),
            reason: '$id 的门槛太低了');
      }
    });
  });

  // ============================================================ 随机时代
  group('「随机时代」得真的随机出个时代', () {
    test('非随机时代原样返回', () {
      for (final era in kEraKeys) {
        final e = Era.values.firstWhere((x) => x.name == era);
        expect(resolveEra(e, 0.0), e);
        expect(resolveEra(e, 0.99), e,
            reason: '$era 不该被随机改写');
      }
    });

    test('随机时代永远落定成具体时代，不会回落到 random', () {
      // 'random' 不是任何时代的 eraKey：落定不成具体时代，
      // 玩家就会进入一个没有锚点、没有时代 NPC 的空世界。
      for (var i = 0; i < 200; i++) {
        final roll = i / 200;
        final got = resolveEra(Era.random, roll);
        expect(got, isNot(Era.random), reason: 'roll=$roll 没有落定');
        expect(kEraKeys, contains(got.name),
            reason: 'roll=$roll 落定成了 ${got.name}，它不是合法时代 key');
      }
    });

    test('五个时代都掷得到（掷 500 次全覆盖）', () {
      final seen = <String>{};
      for (var i = 0; i < 500; i++) {
        seen.add(resolveEra(Era.random, i / 500).name);
      }
      expect(seen.length, kEraKeys.length,
          reason: '掷了 500 次只掷出 ${seen.length} 个时代：$seen');
    });

    test('骰子边界不越界', () {
      expect(resolveEra(Era.random, 0.0), kRandomEraChoices.first);
      expect(resolveEra(Era.random, 0.999999), kRandomEraChoices.last);
      // Random.nextDouble() 取不到 1.0，但保一手：越界也要落在合法时代上
      expect(kRandomEraChoices, contains(resolveEra(Era.random, 1.0)));
      expect(kRandomEraChoices, contains(resolveEra(Era.random, -0.1)));
    });

    test('每个能掷到的时代都有自己的一套专属锚点', () {
      // 落定成具体时代之后，这个时代必须真的有内容——
      // 否则"修好了随机"也只是随机掉进一个空时代。
      for (final era in kRandomEraChoices) {
        expect(_exclusiveFor(era.name), isNotEmpty,
            reason: '${era.name} 能被掷到，但它一条专属锚点都没有');
      }
    });

    test('真的接进了游戏 开局时落定随机时代', () {
      final src = File('lib/mixins/mixin_init.dart').readAsStringSync();
      expect(src.contains('resolveEra('), isTrue,
          reason: 'initializeGame 里没有落定随机时代');
      // 必须落在 worldState 建好之前，否则那局的世界已经带着 'random' 了。
      // 用 era: 那一行当标志：resetAllState() 里也有一个 worldState = WorldState()，
      // 拿它当锚点会误判。
      final iResolve = src.indexOf('resolveEra(appProvider.era');
      final iWorld = src.indexOf('era: appProvider.era.name');
      expect(iResolve, greaterThan(-1));
      expect(iWorld, greaterThan(-1));
      expect(iWorld, greaterThan(iResolve),
          reason: '落定发生在 worldState 创建之后，来不及了');
    });

    test('落定走 lockEra 而不是 setEra', () {
      // 用 setEra 会把掷到的时代写进 SharedPreferences，
      // 从此"随机时代"这个偏好就没了——下局不再随机。
      final src = File('lib/mixins/mixin_init.dart').readAsStringSync();
      final iResolve = src.indexOf('resolveEra(');
      final seg = src.substring(iResolve, iResolve + 600);
      expect(seg.contains('lockEra'), isTrue,
          reason: '随机落定必须走 lockEra（不落盘）');
    });
  });
}
