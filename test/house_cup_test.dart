import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/house_cup_data.dart';

/// lib/ 下各文件的源码，给接线断言用。
String _src(String path) => File('lib/$path').readAsStringSync();

/// 去掉注释后的源码。
///
/// 接线断言扫的是"代码里有没有这么写"，而注释里经常出现
/// 「以前这里是 `p.houseCupPoints += n`」这种反例说明——
/// 不剥掉注释的话，守门测试会去咬那些它自己该咬的东西的反面。
String _code(String path) {
  final out = <String>[];
  var inBlock = false;
  for (final line in _src(path).split('\n')) {
    var l = line;
    if (inBlock) {
      final end = l.indexOf('*/');
      if (end < 0) continue;
      l = l.substring(end + 2);
      inBlock = false;
    }
    final start = l.indexOf('/*');
    if (start >= 0 && l.indexOf('*/', start) < 0) {
      l = l.substring(0, start);
      inBlock = true;
    }
    if (l.trimLeft().startsWith('//')) continue;
    out.add(l);
  }
  return out.join('\n');
}

/// 一段普通叙事——绝大多数回合长这样，不该触发任何加减分。
const _boringTexts = [
  '你沿着走廊往回走，火把在墙上投下摇晃的影子。',
  '魔药课的教室在地下，空气里常年有一股熬煮的味道。',
  '你把书放回架上，忽然想起还有什么事没做。',
  '窗外又开始下雨了。',
  '他看了你一眼，什么也没说。',
  '你在长桌边坐下，旁边的人正在争论下一场比赛的阵容。',
  '晚饭吃得很安静。',
];

void main() {
  // ============================================================ 判定本身
  group('从叙事里认出学院分', () {
    test('绝大多数回合返回 null', () {
      // 这条是整个系统的命门：宁可漏，不可乱加。
      // 一篇课文里连写三句"教授点了点头"就加 30 分的话，
      // 学院分就不是玩家挣的，是系统发的。
      for (final t in _boringTexts) {
        expect(housePointFromNarrative(t), isNull,
            reason: '这句不该触发加减分：「$t」');
      }
    });

    test('空文本返回 null', () {
      expect(housePointFromNarrative(''), isNull);
    });

    test('课堂上的赞许加 5 分', () {
      final d = housePointFromNarrative('斯普劳特教授赞许地点了点头。');
      expect(d, isNotNull);
      expect(d!.value, 5);
      expect(d.reason, isNotEmpty);
    });

    test('救了人加 10 分', () {
      final d = housePointFromNarrative('你挡在他前面，救了他一命。');
      expect(d, isNotNull);
      expect(d!.value, 10);
    });

    test('夜游被抓扣 10 分', () {
      final d = housePointFromNarrative('费尔奇的灯笼照过来，你被抓到了。');
      expect(d, isNotNull);
      expect(d!.value, -10);
    });

    test('关禁闭扣 20 分', () {
      final d = housePointFromNarrative('麦格教授说：关禁闭，今晚就去。');
      expect(d, isNotNull);
      expect(d!.value, -20);
    });

    test('迟到扣 5 分', () {
      final d = housePointFromNarrative('你迟到了整整十分钟，教室门已经关上。');
      expect(d, isNotNull);
      expect(d!.value, -5);
    });

    test('扣分优先于加分：先闯祸后补救，记的是闯祸那次', () {
      // 一条叙事里先炸了坩埚、再把同学扶起来——
      // 人被扣分往往比被加分记得住，而且"闯了祸又做件好事就当没发生过"
      // 会让扣分这件事失去分量。
      final d = housePointFromNarrative(
          '你的坩埚炸了，溅了旁边人一身。你赶紧扶起他，还帮他把东西捡了回来。');
      expect(d, isNotNull);
      expect(d!.value, lessThan(0),
          reason: '先闯祸后补救，该记的是闯祸那次');
    });

    test('一段叙事最多加减一次', () {
      // 返回值是单个 HousePointDelta?，天然只可能一次。
      // 这条钉住的是"别哪天改成了返回 List"。
      final d = housePointFromNarrative(
          '教授表扬了你。全班只有你做成了，连教授都站起来看了看。你又帮了同桌一把。');
      expect(d, isNotNull);
      expect(d!.value, lessThanOrEqualTo(10),
          reason: '三个加分词叠在一起也只该记一次最大的');
    });

    // ---------------------------------------------------------- hedge
    group('把事件否掉的说法不作数', () {
      const hedged = [
        '你差点被抓到，心跳得厉害。',
        '幸好没炸，教室里只是一阵白烟。',
        '你以为会被关禁闭，结果只是被说了两句。',
        '险些迟到了，还好赶上了。',
        '虚惊一场——他没有被抓到。',
      ];
      for (final t in hedged) {
        test('「$t」不加减', () {
          expect(housePointFromNarrative(t), isNull,
              reason: '差点/幸好不是真出事');
        });
      }
    });

    test('hedge 只管附近，不该吃掉远处真发生的事', () {
      // 窗口是前 8 后 4 个字。一句话开头说"差点"，
      // 结尾真救了人，那还是得记。
      final d = housePointFromNarrative(
          '你差点在楼梯上摔下去，站稳之后顺手扶起了前面那个摔倒的一年级生，'
          '教授看见了，赞许地点了点头。');
      expect(d, isNotNull, reason: '结尾那次是真好');
      expect(d!.value, greaterThan(0));
    });

    // ---------------------------------------------------------- reason
    test('reason 是一句能进来源明细的话', () {
      final d = housePointFromNarrative('教室里安静了一秒，然后教授表扬了你的答案。');
      expect(d, isNotNull);
      final r = d!.reason;
      expect(r, isNotEmpty);
      expect(r, isNot(contains('\n')));
      expect(r.length, lessThanOrEqualTo(30),
          reason: '来源明细里塞一整段叙事就没法看了');
      expect(r, contains('表扬'), reason: 'reason 该说清是为什么');
    });

    test('跨越标点时 reason 从分句开头切起', () {
      final d = housePointFromNarrative('他先笑了一阵。然后教授站起来鼓掌了。');
      expect(d, isNotNull);
      expect(d!.reason, isNot(contains('笑')),
          reason: '不该把上一个分句的内容拖进来');
    });
  });

  // ============================================================ 规则表守门
  group('加减分规则表', () {
    test('加分都是正数，扣分都是负数', () {
      for (final e in kHousePointGainRules.entries) {
        expect(e.key, greaterThan(0));
        expect(e.value, isNotEmpty);
      }
      for (final e in kHousePointLossRules.entries) {
        expect(e.key, lessThan(0));
        expect(e.value, isNotEmpty);
      }
    });

    test('同一个词不能既加分又扣分', () {
      // 否则判定的结果取决于两张表的遍历顺序，
      // 而那个顺序在代码里看不出来——纯靠运气。
      final gains = kHousePointGainRules.values.expand((v) => v).toSet();
      final losses = kHousePointLossRules.values.expand((v) => v).toSet();
      expect(gains.intersection(losses), isEmpty);
    });

    test('同一个词不能跨档重复', () {
      // 写了两遍的话，生效的永远是列表里靠前那档，另一档是死代码。
      final all = <String>[];
      for (final v in kHousePointGainRules.values) {
        all.addAll(v);
      }
      expect(all.toSet().length, all.length);
      final allLoss = <String>[];
      for (final v in kHousePointLossRules.values) {
        allLoss.addAll(v);
      }
      expect(allLoss.toSet().length, allLoss.length);
    });

    test('规则词里不含 hedge 词', () {
      // 一条规则词如果本身就带着"差点/幸好"的意思，
      // 那它永远不会触发。
      for (final w in [
        ...kHousePointGainRules.values.expand((v) => v),
        ...kHousePointLossRules.values.expand((v) => v),
      ]) {
        for (final h in kHousePointHedgeWords) {
          expect(w.contains(h), isFalse,
              reason: '规则词「$w」含 hedge 词「$h」，永远不会触发');
        }
      }
    });

    test('没有裸的「炸了」这类会被口语误伤的词', () {
      // 「礼堂笑炸了」「全班乐炸了」是夸你，不是扣你分。
      // 要扣也得写成「坩埚炸」「魔药炸」。
      const bareWords = ['炸了', '坏了', '完了', '废了'];
      for (final w in kHousePointLossRules.values.expand((v) => v)) {
        expect(bareWords, isNot(contains(w)));
      }
    });

    test('加减分都不超过魁地奇取胜的三分之一', () {
      // 魁地奇取胜 +30。日常的分数要是能到 30，
      // 那场比赛就不值钱了。
      final max = kHousePointGainRules.keys.reduce((a, b) => a > b ? a : b);
      expect(max, lessThan(30));
    });
  });

  // ============================================================ 来源标签
  group('来源明细的分类名', () {
    test('加分归「日常表现」，扣分归「日常扣分」', () {
      expect(houseCupSourceLabelFor(const HousePointDelta(5, 'x')), '日常表现');
      expect(houseCupSourceLabelFor(const HousePointDelta(-10, 'x')), '日常扣分');
    });
  });

  // ============================================================ 接线
  group('接线', () {
    test('tryHousePointsFromNarrative 挂在叙事副作用里', () {
      // 判定写得再准，没挂上去就一个回合都不会跑。
      final src = _code('mixins/mixin_response.dart');
      final fn = src.indexOf('void applyNarrativeSideEffects');
      final call = src.indexOf('tryHousePointsFromNarrative(text)');
      expect(fn, greaterThan(-1));
      expect(call, greaterThan(fn),
          reason: 'tryHousePointsFromNarrative 没在 applyNarrativeSideEffects 里调用');
    });

    test('只认在校期间：暑假在家答对问题不加学院分', () {
      final src = _code('mixins/mixin_response.dart');
      final fn = src.indexOf('void tryHousePointsFromNarrative');
      final guard = src.indexOf("contains('霍格沃茨')", fn);
      final decide = src.indexOf('housePointFromNarrative(text)', fn);
      expect(fn, greaterThan(-1));
      expect(guard, greaterThan(fn));
      expect(decide, greaterThan(guard),
          reason: '地点判断必须在判定之前，否则在校外也会加分');
    });

    test('未分院时直接返回', () {
      final src = _code('mixins/mixin_response.dart');
      final fn = src.indexOf('void tryHousePointsFromNarrative');
      final body = src.substring(fn, src.indexOf('\n  }', fn));
      expect(body, contains('p.house == null'),
          reason: '没分院就记学院分的话，分记到哪个院去？');
    });

    test('走 addHouseCupPoints 统一入口，不直接改字段', () {
      // 直接改 p.houseCupPoints 的话，/学院杯 的来源明细里
      // 永远看不到"日常"这一项。
      final src = _code('mixins/mixin_response.dart');
      final fn = src.indexOf('void tryHousePointsFromNarrative');
      final body = src.substring(fn, src.indexOf('\n  }', fn));
      expect(body, contains('addHouseCupPoints'));
      expect(body, isNot(contains('houseCupPoints +=')));
    });

    test('lib 下没有绕过统一入口的学院分改动', () {
      // 除了 addHouseCupPoints 内部那一次、和学年清零那一次，
      // 任何地方都不该直接写 houseCupPoints。
      final offenders = <String>[];
      for (final f in [
        'mixins/mixin_play.dart',
        'mixins/mixin_response.dart',
        'mixins/mixin_systems.dart',
      ]) {
        final lines = _code(f).split('\n');
        for (var i = 0; i < lines.length; i++) {
          final l = lines[i];
          if (!l.contains('houseCupPoints +=') &&
              !(l.contains('houseCupPoints =') &&
                  !l.contains('houseCupPoints =='))) continue;
          // 允许的例外：统一入口内部、学年结算清零
          if (l.contains('p.houseCupPoints += amount')) continue;
          if (l.contains('p.houseCupPoints = 0;')) continue;
          offenders.add('$f:${i + 1}: ${l.trim()}');
        }
      }
      expect(offenders, isEmpty,
          reason: '这些地方绕过了 addHouseCupPoints：\n${offenders.join('\n')}');
    });

    test('负分玩家也能结算', () {
      // 原来是 `<= 0 return`：只扣过分的人既看不到结算，
      // 那些负分也永远不清零，会一路滚到下一个学年，越欠越多。
      final src = _code('mixins/mixin_play.dart');
      final fn = src.indexOf('void settleHouseCup()');
      final body = src.substring(fn, src.indexOf('\n  }', fn));
      expect(body, contains('houseCupPoints == 0'));
      expect(body, isNot(contains('houseCupPoints <= 0')));
    });

    test('结算会清零，负分不会滚到下一学年', () {
      final src = _code('mixins/mixin_play.dart');
      final fn = src.indexOf('void settleHouseCup()');
      final body = src.substring(fn, src.indexOf('\n  }', fn));
      expect(body, contains('p.houseCupPoints = 0;'));
      expect(body, contains('p.houseCupSources.clear()'));
    });

    test('来源明细里扣分不显示成 +-5', () {
      final src = _code('mixins/mixin_play.dart');
      final fn = src.indexOf('String formatHouseCup()');
      final body = src.substring(fn, src.indexOf('\n  }', fn));
      expect(body, contains("e.value >= 0 ? '+' : ''"),
          reason: '否则来源明细会出现「日常扣分 +-5」');
    });

    test('静态说明里提到了日常这条途径', () {
      // 不打魁地奇的玩家点开 /学院杯，看见的全是自己做不了的事。
      final src = _code('mixins/mixin_play.dart');
      final fn = src.indexOf('String formatHouseCup()');
      final body = src.substring(fn, src.indexOf('\n  }', fn));
      expect(body, contains('日常'));
    });

    test('addHouseCupPoints 在基类有声明（跨 mixin 可见）', () {
      // mixin_response 用的是 mixin_play 里的方法，
      // 必须在抽象基类里声明，否则编译不过。
      final base = _code('providers/game_provider_base.dart');
      expect(base, contains('void addHouseCupPoints(int amount, String reason);'));
    });
  });

  // ============================================================ 回归
  group('假系统已删除', () {
    test('WorldState 里那个没人读的 housePoints 不在了', () {
      // 它每月给四个学院各自 random.nextInt(5) - 2 地随机游走，
      // 全项目零读取。而且 key 是英文（'Gryffindor'），
      // 跟学院杯系统用的中文院名从来就对不上。
      final ws = _code('models/world_state.dart');
      expect(ws, isNot(contains('housePoints')));
      expect(ws, isNot(contains('house_points')));

      final play = _code('mixins/mixin_play.dart');
      expect(play, isNot(contains('worldState.housePoints')));
    });

    test('house_cup_data 不重复造学院杯', () {
      // 学院杯系统本来就是完好的（统一入口、/学院杯、学年结算、成就）。
      // 这里只补日常加减分，不该再有一套排名逻辑。
      final src = _code('data/house_cup_data.dart');
      for (final forbidden in [
        'settleHouseCup',
        'kHouses',
        'houseCupAnnouncementFor',
        'rivalDriftFor',
      ]) {
        expect(src, isNot(contains(forbidden)),
            reason: '$forbidden 属于 mixin_play 的学院杯系统，这里不该有第二份');
      }
    });
  });
}
