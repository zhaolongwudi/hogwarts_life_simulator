import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/rivalry_data.dart';
import 'package:hogwarts_life_simulator/models/npc.dart';

/// 造一条记仇记录，与 NPC.addGrudge 写入的结构一致。
Map<String, dynamic> _grudge(String type, int day, {String reason = '某事'}) =>
    {'type': type, 'reason': reason, 'day': day, 'affection_at_time': -20};

void main() {
  // ------------------------------------------------------------ 成因识别
  group('宿敌成因', () {
    test('按理由文字分门别类', () {
      expect(causeFromReason('你当众顶撞了他'), RivalryCause.publicHumiliation);
      expect(causeFromReason('你抢了他的风头'), RivalryCause.outshone);
      expect(causeFromReason('你们喜欢同一个人'), RivalryCause.romance);
      expect(causeFromReason('你打伤了他的朋友'), RivalryCause.harmed);
      expect(causeFromReason('你们在血统问题上谈不拢'), RivalryCause.principle);
      expect(causeFromReason('学院杯之争'), RivalryCause.house);
    });

    test('认不出来时退回背叛，与既有存档口径一致', () {
      expect(causeFromReason('随便什么事'), RivalryCause.betrayal);
      expect(causeFromReason(null), RivalryCause.betrayal);
      expect(causeFromReason(''), RivalryCause.betrayal);
    });

    test('成因 key 与老存档里的 betrayal 对得上', () {
      expect(causeKeyFor(RivalryCause.betrayal), 'betrayal');
    });

    test('每种成因都有权重和文案，没有漏填', () {
      for (final c in kRivalryCauses) {
        expect(c.weight, greaterThan(0), reason: '${c.label} 权重没填');
        expect(c.label.trim(), isNotEmpty);
        expect(c.note.trim(), isNotEmpty);
      }
    });

    test('背叛比抢风头严重，学院对立最轻', () {
      expect(grudgeWeightFor('betrayal'), greaterThan(grudgeWeightFor('outshone')));
      expect(grudgeWeightFor('outshone'), greaterThan(grudgeWeightFor('house')));
    });
  });

  // -------------------------------------------------------------- 时间衰减
  group('旧账会凉，但不会彻底凉透', () {
    test('当天不衰减', () {
      expect(decayFactorFor(0), 1.0);
      expect(decayFactorFor(-5), 1.0);
    });

    test('一个周期后按 0.85 计', () {
      expect(decayFactorFor(30), closeTo(0.85, 0.001));
      expect(decayFactorFor(60), closeTo(0.85 * 0.85, 0.001));
    });

    test('衰减有下限：挂机几个月洗不白', () {
      // 没有下限的话，玩家什么都不做、快进一年就能自动和解所有宿敌。
      expect(decayFactorFor(3650), kDecayFloor);
      expect(kDecayFloor, greaterThan(0.0));
    });
  });

  // ---------------------------------------------------------------- 宿敌分
  group('宿敌分与等级', () {
    test('没有记仇就是 0', () {
      expect(rivalryScoreFor([], currentDay: 100), 0);
      expect(tierForScore(0), RivalryTier.none);
    });

    test('一条背叛够不上敌意，两条就到宿敌', () {
      final one = rivalryScoreFor([_grudge('betrayal', 100)],
          currentDay: 100, affection: 0);
      expect(one, 40);
      expect(tierForScore(one), RivalryTier.grudge);

      final two = rivalryScoreFor(
        [_grudge('betrayal', 100), _grudge('betrayal', 100)],
        currentDay: 100,
        affection: 0,
      );
      expect(two, 80);
      expect(tierForScore(two), RivalryTier.nemesis);
    });

    test('三条背叛到死敌', () {
      final score = rivalryScoreFor(
        [_grudge('betrayal', 100), _grudge('betrayal', 100), _grudge('betrayal', 100)],
        currentDay: 100,
        affection: 0,
      );
      expect(tierForScore(score), RivalryTier.archenemy);
    });

    test('一年前的旧账只剩四分之一分量', () {
      final fresh = rivalryScoreFor([_grudge('betrayal', 100)],
          currentDay: 100, affection: 0);
      final old = rivalryScoreFor([_grudge('betrayal', 100 - 365)],
          currentDay: 100, affection: 0);
      expect(old, lessThan(fresh));
      expect(old, closeTo(40 * kDecayFloor, 1));
    });

    test('关系回暖后旧账打折', () {
      final cold = rivalryScoreFor([_grudge('betrayal', 100)],
          currentDay: 100, affection: 0);
      final warm = rivalryScoreFor([_grudge('betrayal', 100)],
          currentDay: 100, affection: 60);
      expect(warm, lessThan(cold));
      expect(warm, closeTo(cold * 0.4, 1));
    });

    test('减免能把宿敌分抹平，但不会变成负数', () {
      final score = rivalryScoreFor([_grudge('betrayal', 100)],
          currentDay: 100, affection: 0, relief: 999);
      expect(score, 0);
    });

    test('等级阈值单调递增且从 0 起', () {
      var last = -1;
      for (final t in kRivalryTiers) {
        expect(t.threshold, greaterThan(last));
        last = t.threshold;
      }
      expect(kRivalryTiers.first.threshold, 0);
    });
  });

  // ---------------------------------------------------------------- 行为
  group('每档行为指令', () {
    test('没有宿敌时不注入任何指令', () {
      expect(rivalryDirectiveFor(RivalryTier.none, '张三', '某事'), isEmpty);
    });

    test('等级越高写得越重，且都点名了具体做法', () {
      // 光说"态度不好"AI 演不出来，指令必须写清做什么。
      final g = rivalryDirectiveFor(RivalryTier.grudge, '张三', '某事');
      final n = rivalryDirectiveFor(RivalryTier.nemesis, '张三', '某事');
      expect(g, contains('张三'));
      expect(n, contains('张三'));
      expect(g, isNot(equals(n)));
      // 宿敌档要真的动手
      expect(n, contains('动手'));
    });

    test('指令里带上结仇原因，AI 才知道他为什么恨', () {
      final d = rivalryDirectiveFor(RivalryTier.nemesis, '张三', '你当众顶撞了他');
      expect(d, contains('你当众顶撞了他'));
    });

    test('每档都有徽标，供在场列表使用', () {
      for (final t in RivalryTier.values) {
        if (t == RivalryTier.none) {
          expect(rivalryBadgeFor(t), isEmpty);
        } else {
          expect(rivalryBadgeFor(t).trim(), isNotEmpty);
        }
      }
    });
  });

  // ------------------------------------------------------- NPC 上的宿敌状态
  group('NPC 宿敌状态', () {
    NPC npcWith(List<Map<String, dynamic>> grudges, {int affection = 0}) =>
        NPC(id: 'x', name: '某人', grudges: grudges, affection: affection);

    test('宿敌分与等级跟着 grudges 走', () {
      final npc = npcWith([_grudge('betrayal', 100)], affection: -30);
      expect(npc.hasGrudge, isTrue);
      expect(npc.rivalryScore(100), 40);
      expect(npc.rivalryTier(100), RivalryTier.grudge);
    });

    test('补救有每日上限，刷不白', () {
      final npc = npcWith([_grudge('betrayal', 100), _grudge('betrayal', 100)]);
      final before = npc.rivalryScore(100);

      // 同一天连补四次
      final gains = <int>[
        npc.applyAmends(100),
        npc.applyAmends(100),
        npc.applyAmends(100),
        npc.applyAmends(100),
      ];
      final total = gains.reduce((a, b) => a + b);
      expect(total, kMaxReliefPerDay, reason: '当天减免不该超过上限');
      expect(npc.rivalryScore(100), before - total);

      // 换一天又能补
      expect(npc.applyAmends(101), greaterThan(0));
    });

    test('没结仇时不给减免，免得把 relief 刷成负资产', () {
      final npc = npcWith([]);
      expect(npc.applyAmends(100), 0);
      expect(npc.rivalryRelief, 0);
    });

    test('峰值单独记，被时间冲淡后仍查得出"曾经真恨过"', () {
      final npc = npcWith([
        _grudge('betrayal', 0),
        _grudge('betrayal', 0),
      ]);
      npc.tickRivalry(0);
      expect(npc.maxRivalryScoreReached, greaterThanOrEqualTo(70));

      // 快进五年：分数被时间冲得很低，但峰值还在
      npc.tickRivalry(1825);
      expect(npc.rivalryScore(1825), lessThan(70));
      expect(npc.maxRivalryScoreReached, greaterThanOrEqualTo(70));
    });

    test('只结过小芥蒂的不算"化敌为友"', () {
      // 峰值没到敌意档就和解，不值得专门记一笔。
      final npc = npcWith([_grudge('house', 100)], affection: 50);
      npc.tickRivalry(100);
      expect(npc.maxRivalryScoreReached, lessThan(kFormerRivalMinPeak));
      expect(npc.formerRival, isFalse);
    });

    test('真恨过、又修好了，才算化敌为友', () {
      final npc = npcWith([
        _grudge('betrayal', 100),
        _grudge('betrayal', 100),
      ]);
      npc.tickRivalry(100);
      expect(npc.formerRival, isFalse);

      // 把分减到 0，好感拉回正值
      npc.rivalryRelief = 999;
      npc.affection = 50;
      final justHealed = npc.tickRivalry(100);
      expect(justHealed, isTrue);
      expect(npc.formerRival, isTrue);

      // 再调一次不该重复触发
      expect(npc.tickRivalry(100), isFalse);
    });

    test('化敌为友的文案能拿到', () {
      expect(formerRivalLine('张三'), contains('张三'));
    });
  });

  // ------------------------------------------------------------ 存档兼容
  group('存档兼容', () {
    test('老存档（没有宿敌字段）能读出 NPC 且能算宿敌分', () {
      final old = <String, dynamic>{
        'id': 'old',
        'name': '老存档的人',
        'grudges': [
          {'type': 'betrayal', 'reason': '背叛', 'day': 100},
        ],
        'affection': -30,
        // 故意不含 rivalry_relief / former_rival / max_rivalry_score_reached
      };
      final npc = NPC.fromJson(old);
      expect(npc.rivalryRelief, 0);
      expect(npc.formerRival, isFalse);
      expect(npc.maxRivalryScoreReached, 0);
      // 宿敌分仍能从 grudges 算出来，不需要迁移脚本
      expect(npc.rivalryScore(100), 40);
      expect(npc.rivalryTier(100), RivalryTier.grudge);
    });

    test('新字段能完整往返', () {
      final npc = NPC(
        id: 'n',
        name: '某人',
        grudges: [_grudge('outshone', 50)],
        affection: 40,
      );
      npc.tickRivalry(50);
      npc.applyAmends(50);
      final peak = npc.maxRivalryScoreReached;
      final relief = npc.rivalryRelief;

      final revived = NPC.fromJson(npc.toJson());
      expect(revived.rivalryRelief, relief);
      expect(revived.maxRivalryScoreReached, peak);
      expect(revived.reliefGivenToday, npc.reliefGivenToday);
      expect(revived.rivalryScore(50), npc.rivalryScore(50));
    });
  });

  // ---------------------------------------------------- 一场决斗的分寸
  group('决斗结仇要有分寸', () {
    test('赢一场最多结下芥蒂，不能直接顶到敌意', () {
      // 抢风头权重只有 20，单条不至于跨过 hostile 档（45）。
      // 否则赢一场决斗就多个死敌，打一圈下来全校没朋友了。
      final score = rivalryScoreFor([_grudge('outshone', 100)],
          currentDay: 100, affection: 0);
      expect(score, grudgeWeightFor('outshone'));
      expect(tierForScore(score), RivalryTier.grudge);
      expect(score, lessThan(45));
    });

    test('决斗胜利后确实会走宿敌判定', () {
      final src = File('lib/mixins/mixin_play.dart').readAsStringSync();
      expect(src.contains('_maybeRivalFromDuel'), isTrue);
    });

    test('已经有仇的对手不再叠加', () {
      // 不打这层保护，反复赢同一个人就能把他一路顶到死敌。
      final src = File('lib/mixins/mixin_play.dart').readAsStringSync();
      final fn = src.substring(src.indexOf('_maybeRivalFromDuel'));
      expect(fn.contains('rivalryTier(day) != RivalryTier.none'), isTrue);
    });

    test('决斗结仇是概率事件，不是必然', () {
      final src = File('lib/mixins/mixin_play.dart').readAsStringSync();
      final fn = src.substring(src.indexOf('_maybeRivalFromDuel'));
      expect(fn.contains('random.nextDouble()'), isTrue);
    });
  });

  // ------------------------------------------------------------ 接线检查
  group('宿敌接进了叙事与界面', () {
    test('叙事 prompt 会为在场的宿敌注入行为指令', () {
      final src = File('lib/mixins/mixin_narrative.dart').readAsStringSync();
      expect(src.contains('【宿敌·'), isTrue);
      expect(src.contains('rivalryDirectiveFor'), isTrue);
      // 没有仇人的时候不该花这份 token
      expect(src.contains('if (tier == RivalryTier.none) continue;'), isTrue);
    });

    test('和解过的人会有一句交代', () {
      final src = File('lib/mixins/mixin_narrative.dart').readAsStringSync();
      expect(src.contains('【旧怨已了·'), isTrue);
    });

    test('人物详情里能看到宿敌等级与第几笔旧账', () {
      final src = File('lib/mixins/mixin_systems.dart').readAsStringSync();
      expect(src.contains('rivalryBadgeFor(tier)'), isTrue);
      expect(src.contains('这已经是第'), isTrue);
    });

    test('好感回升能减免宿敌分，且门槛挡住了日常寒暄', () {
      final src = File('lib/providers/game_provider.dart').readAsStringSync();
      expect(src.contains('applyAmends'), isTrue);
      expect(src.contains('actualChange >= 8'), isTrue,
          reason: '没有这个门槛，日常 +1 的寒暄也会算赎罪，宿敌会被悄悄刷白');
    });

    test('化敌为友会留一笔，且不暴露内部数值', () {
      final src = File('lib/providers/game_provider.dart').readAsStringSync();
      expect(src.contains('formerRivalLine'), isTrue);
      // 玩家可见文案里不许出现"宿敌分"这种系统术语
      expect(src.contains('宿敌分 -'), isFalse);
    });
  });

  // ------------------------------------------------ 好感路径接上了成因识别
  group('好感路径会按成因分门别类', () {
    final src = File('lib/providers/game_provider.dart').readAsStringSync();

    test('不再一律记成 betrayal', () {
      expect(src.contains('causeFromReason'), isTrue);
      // 旧的写死调用应当已被替换
      expect(src.contains("addGrudge('betrayal'"), isFalse);
    });

    test('升档会给玩家提示', () {
      // 宿敌这件事必须让玩家感知得到，
      // 否则他只注意到好感涨不上去，不知道对面多了个仇人。
      expect(src.contains('tierAfter.index > tierBefore.index'), isTrue);
      expect(src.contains('已经把你当成宿敌'), isTrue);
    });
  });

  // ------------------------------------------------------- 玩家侧看得见
  group('宿敌在界面上可见', () {
    test('好感总览页折叠态就带等级徽标，不必展开', () {
      final src =
          File('lib/screens/other/affection_aggregate_screen.dart').readAsStringSync();
      expect(src.contains('rivalryBadgeFor(tier)'), isTrue);
      // 徽标必须挂在 _buildNpcTile（折叠态）里，只在展开详情里出现等于看不见
      final tileStart = src.indexOf('Widget _buildNpcTile(');
      final detailStart = src.indexOf('Widget _buildAffectionDetail(');
      expect(tileStart, greaterThan(0));
      expect(detailStart, greaterThan(tileStart));
      final tileBody = src.substring(tileStart, detailStart);
      expect(tileBody.contains('rivalryBadgeFor'), isTrue,
          reason: '宿敌等级只在展开详情里显示，列表扫一眼根本不知道谁在恨你');
      expect(tileBody.contains('旧怨已了'), isTrue);
    });

    test('展开与折叠用的是同一个 today，不会自己算一套天数', () {
      final src =
          File('lib/screens/other/affection_aggregate_screen.dart').readAsStringSync();
      // 天数必须从 build 里取一次再往下传，
      // 否则某个分支拿 dayOfYear、另一个拿 absoluteDayIndex，两边的分数就对不上
      expect(src.contains('_buildNpcList(npcs, gp.worldState.time.absoluteDayIndex)'), isTrue);
      expect(src.contains('_buildNpcTile(npcs[index], today)'), isTrue);
      expect(src.contains('_buildAffectionDetail(npc, today)'), isTrue);
      // 除了 build 那一处取天数，别处不许再摸 worldState
      final gpUses = 'gp.worldState'.allMatches(src).length;
      expect(gpUses, 1, reason: '天数应当在 build 里取一次往下传，不该每个组件各取各的');
    });

    test('关系列表命令也带宿敌标记', () {
      final src = File('lib/mixins/mixin_relations.dart').readAsStringSync();
      expect(src.contains('rivalryBadgeFor'), isTrue);
      // 和好的人显示"旧怨已了"而不是继续挂仇恨徽标
      expect(src.contains('旧怨已了'), isTrue);
    });
  });

  group('宿敌不在场时 AI 也知道有这号人', () {
    final src = File('lib/mixins/mixin_narrative.dart').readAsStringSync();

    test('有全局宿敌名册段', () {
      // 只让 AI 看见"眼前这个人恨你"，那"他在走廊尽头堵你"这类戏永远写不出来
      expect(src.contains('【宿敌名册】'), isTrue);
      expect(src.contains('可以自己找上门'), isTrue);
    });

    test('名册只收 hostile 及以上，芥蒂不常驻占 token', () {
      expect(src.contains('e.tier.index >= RivalryTier.hostile.index'), isTrue);
    });

    test('已经站在面前的宿敌不重复进名册', () {
      // 在场的有单独的【宿敌·姓名】段带完整行为指令，名册里再写一遍是浪费
      expect(src.contains('hereIds'), isTrue);
      expect(src.contains('!hereIds.contains(n.id)'), isTrue);
    });
  });
}
