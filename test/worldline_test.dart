import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/data/worldline_data.dart';
import 'package:hogwarts_life_simulator/data/event_anchors.dart';
import 'package:hogwarts_life_simulator/models/world_state.dart';

void main() {
  // ==================== 阶段门槛 ====================
  group('世界线阶段门槛', () {
    test('边界值归到正确的档', () {
      expect(worldLineStageFor(0.0), WorldLineStage.intact);
      expect(worldLineStageFor(0.099), WorldLineStage.intact);
      expect(worldLineStageFor(0.10), WorldLineStage.fraying);
      expect(worldLineStageFor(0.239), WorldLineStage.fraying);
      expect(worldLineStageFor(0.24), WorldLineStage.diverging);
      expect(worldLineStageFor(0.399), WorldLineStage.diverging);
      expect(worldLineStageFor(0.40), WorldLineStage.rewritten);
      expect(worldLineStageFor(0.599), WorldLineStage.rewritten);
      expect(worldLineStageFor(0.60), WorldLineStage.unrecognizable);
      expect(worldLineStageFor(1.0), WorldLineStage.unrecognizable);
    });

    test('越界输入被 clamp，不抛异常', () {
      expect(worldLineStageFor(-0.5), WorldLineStage.intact);
      expect(worldLineStageFor(3.7), WorldLineStage.unrecognizable);
    });

    test('门槛单调不回头', () {
      var last = -1.0;
      for (final s in kWorldLineStages) {
        expect(s.minDeviation, greaterThan(last), reason: '${s.label} 门槛没升高');
        last = s.minDeviation;
      }
    });

    test('每档都有徽标、名字、以及给 AI 的指令', () {
      for (final s in kWorldLineStages) {
        expect(s.badge, isNotEmpty);
        expect(s.label, isNotEmpty);
        // 这条是 AI 感知"世界被改写过"的唯一通道，空了就全断了
        expect(s.aiDirective.length, greaterThan(20),
            reason: '${s.label} 的 AI 指令太短，说不清楚这一档意味着什么');
      }
    });

    test('高级档的指令明确要求压过原著', () {
      // 不写死这句，AI 会在玩家把塔楼那一夜改掉之后，
      // 下一回合照旧写"校长死了"——它的训练数据里就是这么写的。
      for (final st in [WorldLineStage.rewritten, WorldLineStage.unrecognizable]) {
        expect(stageDefFor(st).aiDirective, contains('已被你改写的事'),
            reason: '${stageDefFor(st).label} 没让 AI 去查改写记录');
      }
    });

    test('gapToNextStage 在顶档返回 null，其余为正', () {
      expect(gapToNextStage(0.0), isNotNull);
      expect(gapToNextStage(0.0), closeTo(0.10, 1e-9));
      expect(gapToNextStage(0.15), closeTo(0.09, 1e-9));
      expect(gapToNextStage(0.75), isNull); // 已在面目全非
      expect(gapToNextStage(1.0), isNull);
    });
  });

  // ==================== 数据完整性 ====================
  group('因果锚点数据完整性', () {
    test('每个因果锚点都绑到一个真实存在的事件锚点上', () {
      // 这是整套系统最容易死的地方：绑错 id，抉择永远不会出现，
      // 而没有任何报错——只是玩家玩到毕业也没见过它。
      final realIds = eventAnchors.map((a) => a.id).toSet();
      for (final c in kCausalAnchors) {
        expect(realIds, contains(c.anchorId),
            reason: '因果锚点「${c.title}」绑的 ${c.anchorId} 在 event_anchors.dart 里不存在');
      }
    });

    test('同一个事件锚点不挂两个因果分支', () {
      final seen = <String>{};
      for (final c in kCausalAnchors) {
        expect(seen.add(c.anchorId), isTrue,
            reason: '${c.anchorId} 被两个因果锚点抢了');
      }
    });

    test('每个锚点都有干预项和旁观项', () {
      for (final c in kCausalAnchors) {
        final intervene = c.options.where((o) => o.isIntervention);
        final aside = c.options.where((o) => o.id == 'standAside');
        expect(intervene, isNotEmpty, reason: '「${c.title}」没有能改写历史的选项');
        expect(aside, isNotEmpty, reason: '「${c.title}」没有旁观的余地');
      }
    });

    test('干预抬升变动率，旁观压低变动率', () {
      for (final c in kCausalAnchors) {
        for (final o in c.options) {
          if (o.isIntervention) {
            expect(o.deviationDelta, greaterThan(0),
                reason: '「${c.title}/${o.text}」是干预却没抬升变动率');
          } else {
            expect(o.deviationDelta, lessThan(0),
                reason: '「${c.title}/${o.text}」是旁观却没压低变动率');
          }
        }
      }
    });

    test('干预留痕、旁观不留痕', () {
      for (final c in kCausalAnchors) {
        for (final o in c.options) {
          if (o.isIntervention) {
            expect(o.echo.length, greaterThan(20),
                reason: '「${c.title}/${o.text}」的痕迹太短，AI 接不住');
          } else {
            // 旁观意味着世界照原典走，不该留下任何"被改写"的痕迹
            expect(o.echo, isEmpty);
          }
        }
      }
    });

    test('选项文案是具体动作，不是选项标签', () {
      // action 会直接当玩家输入发给 AI。写成"选项A"AI 接不住。
      for (final c in kCausalAnchors) {
        for (final o in c.options) {
          expect(o.action.length, greaterThan(8),
              reason: '「${c.title}/${o.text}」的 action 太短，AI 没法接着写');
          expect(o.action, isNot(contains('/')),
              reason: '「${c.title}/${o.text}」的 action 混进了指令符号');
        }
      }
    });

    test('每个选项都写了让玩家读的后果', () {
      for (final c in kCausalAnchors) {
        for (final o in c.options) {
          expect(o.consequence.length, greaterThan(30),
              reason: '「${c.title}/${o.text}」的后果写得太敷衍');
        }
      }
    });

    test('越硬的定数，门槛越高', () {
      // 塔楼那一夜必须比决斗俱乐部难得多，否则"定数"这个词没有意义
      final tower = kCausalAnchors.firstWhere(
          (c) => c.anchorId == 'g6_jun_headmaster_fall');
      final duel =
          kCausalAnchors.firstWhere((c) => c.anchorId == 'g2_feb_duelling');
      expect(tower.minStage.index, greaterThan(duel.minStage.index));
      expect(tower.minStage, WorldLineStage.rewritten);
    });

    test('越硬的定数，改起来偏移越大', () {
      final tower = kCausalAnchors.firstWhere(
              (c) => c.anchorId == 'g6_jun_headmaster_fall')
          .options
          .firstWhere((o) => o.isIntervention);
      final duel = kCausalAnchors
              .firstWhere((c) => c.anchorId == 'g2_feb_duelling')
          .options
          .firstWhere((o) => o.isIntervention);
      expect(tower.deviationDelta, greaterThan(duel.deviationDelta));
    });

    test('干预的代价是真的代价：健康、声望、属性至少动一处', () {
      for (final c in kCausalAnchors) {
        for (final o in c.options.where((x) => x.isIntervention)) {
          final costly = o.healthDelta < 0 ||
              o.reputation.values.any((v) => v < 0) ||
              o.attributes.values.any((v) => v < 0);
          expect(costly, isTrue,
              reason: '「${c.title}/${o.text}」改写了历史却毫无代价');
        }
      }
    });

    test('至少有不限时代的分歧点，非战争周目也有得玩', () {
      final anyEra = kCausalAnchors.where((c) => c.era == null);
      expect(anyEra, isNotEmpty,
          reason: '所有分歧点都限定在 harry_same，别的时代玩家完全碰不到这套系统');
    });

    test('第一个分歧点来得够早', () {
      // 二年级就能碰到——"世界线是可以被改动的"这件事必须一开始就让玩家看见，
      // 等到七年级才出现，绝大多数人根本活不到那时候。
      final earliest = kCausalAnchors
          .map((c) => c.minStage)
          .reduce((a, b) => a.index <= b.index ? a : b);
      expect(earliest, WorldLineStage.fraying);
      final anyEraEarly = kCausalAnchors
          .where((c) => c.era == null && c.minStage == WorldLineStage.fraying);
      expect(anyEraEarly, isNotEmpty,
          reason: '不限时代的分歧点里没有低门槛的，非战争周目开局够不着');
    });
  });

  // ==================== 解锁判定 ====================
  group('解锁判定', () {
    const era = 'harry_same';

    bool unlocked(String anchorId,
            {double dev = 0.0, Set<String> decided = const {}}) =>
        isCausalAnchorUnlocked(causalAnchorFor(anchorId)!,
            era: era, deviation: dev, decidedAnchorIds: decided);

    test('intact 阶段所有分歧点都锁着——不能白送', () {
      for (final c in kCausalAnchors) {
        if (c.era != null && c.era != era) continue;
        expect(unlocked(c.anchorId, dev: 0.0), isFalse,
            reason: '${c.title} 在世界线还没偏移时就解锁了');
      }
    });

    test('变动率够了就解锁', () {
      expect(unlocked('g2_feb_duelling', dev: 0.10), isTrue);
      expect(unlocked('g2_feb_duelling', dev: 0.09), isFalse);
    });

    test('做过的不再重来', () {
      expect(
          unlocked('g2_feb_duelling',
              dev: 0.9, decided: {'g2_feb_duelling'}),
          isFalse,
          reason: '同一个分歧点被做了两次');
    });

    test('时代对不上时不解锁', () {
      final war = kCausalAnchors.firstWhere(
          (c) => c.anchorId == 'g6_jun_headmaster_fall');
      expect(
          isCausalAnchorUnlocked(war,
              era: 'dumbledore',
              deviation: 1.0,
              decidedAnchorIds: const {}),
          isFalse);
      expect(
          isCausalAnchorUnlocked(war,
              era: 'harry_same',
              deviation: 1.0,
              decidedAnchorIds: const {}),
          isTrue);
    });

    test('deviationGapToUnlock 给的是正数，够格了给 0', () {
      final tower = causalAnchorFor('g6_jun_headmaster_fall')!;
      expect(deviationGapToUnlock(tower, 0.0), closeTo(0.40, 1e-9));
      expect(deviationGapToUnlock(tower, 0.30), closeTo(0.10, 1e-9));
      expect(deviationGapToUnlock(tower, 0.40), 0.0);
      expect(deviationGapToUnlock(tower, 0.99), 0.0);
    });
  });

  // ==================== 指令解析 ====================
  group('抉择指令解析', () {
    test('能解析出锚点与选项', () {
      final r = parseCausalCommand('/抉择 g6_jun_headmaster_fall intervene');
      expect(r, isNotNull);
      expect(r!.anchor.anchorId, 'g6_jun_headmaster_fall');
      expect(r.option.id, 'intervene');
      expect(r.option.action, isNotEmpty);
    });

    test('容忍多余空白', () {
      expect(parseCausalCommand('  /抉择  g2_feb_duelling   standAside  '),
          isNotNull);
    });

    test('认不出就返回 null，不能误伤别的指令', () {
      expect(parseCausalCommand('/状态'), isNull);
      expect(parseCausalCommand('/抉择'), isNull);
      expect(parseCausalCommand('/抉择 g2_feb_duelling'), isNull);
      expect(parseCausalCommand('/抉择 nonexistent intervene'), isNull);
      expect(parseCausalCommand('/抉择 g2_feb_duelling no_such_option'), isNull);
      expect(parseCausalCommand('我要上塔去'), isNull);
    });
  });

  // ==================== 痕迹 ====================
  group('改写痕迹', () {
    test('只收干预项，不收旁观', () {
      final echoes = rewrittenEchoesOf({
        'g6_jun_headmaster_fall': 'intervene',
        'g2_feb_duelling': 'standAside',
      });
      expect(echoes.length, 1);
      expect(echoes.first, contains('塔楼'));
    });

    test('按原著时间顺序返回，不跟着 Map 的迭代顺序走', () {
      final echoes = rewrittenEchoesOf({
        'g7_oct_on_the_run': 'intervene',
        'g2_feb_duelling': 'intervene',
        'g5_oct_ministry_decree': 'intervene',
      });
      final idxDuel = echoes.indexWhere((e) => e.contains('决斗'));
      final idxDecree = echoes.indexWhere((e) => e.contains('名单'));
      final idxRun = echoes.indexWhere((e) => e.contains('回校名单'));
      expect(idxDuel, lessThan(idxDecree));
      expect(idxDecree, lessThan(idxRun));
    });

    test('空存档返回空列表', () {
      expect(rewrittenEchoesOf(const {}), isEmpty);
    });

    test('认不出 id 时不炸，只是没有痕迹', () {
      expect(rewrittenEchoesOf({'garbage': 'intervene'}), isEmpty);
      expect(rewrittenEchoesOf({'g2_feb_duelling': 'garbage'}), isEmpty);
    });
  });

  group('旁观痕迹', () {
    test('只收旁观，不收干预', () {
      final witnessed = witnessedEchoesOf({
        'g6_jun_headmaster_fall': 'standAside',
        'g2_feb_duelling': 'intervene',
      });
      expect(witnessed.length, 1);
      expect(witnessed.first, contains('塔楼'));
    });

    test('没碰过的分歧点不写进来——否则「你什么都没做」会变成流水账', () {
      expect(witnessedEchoesOf(const {}), isEmpty);
    });

    test('改写过的和旁观过的是互斥的两栏', () {
      final choices = {
        'g2_feb_duelling': 'intervene',
        'g6_jun_headmaster_fall': 'standAside',
      };
      expect(rewrittenEchoesOf(choices).length, 1);
      expect(witnessedEchoesOf(choices).length, 1);
    });

    test('同样按原著时间顺序返回', () {
      final witnessed = witnessedEchoesOf({
        'g7_oct_on_the_run': 'standAside',
        'g2_feb_duelling': 'standAside',
        'g5_oct_ministry_decree': 'standAside',
      });
      final idxDuel = witnessed.indexWhere((e) => e.contains('决斗'));
      final idxDecree = witnessed.indexWhere((e) => e.contains('名单'));
      expect(idxDuel, lessThan(idxDecree));
    });
  });

  // ==================== 闭环可行性（这条最关键）====================
  //
  // 前面所有测试都只能证明"数据是对的"。这一组要证明的是
  // **这套系统真能被玩到**——之前那个 0.005 的 tick 就是死在这儿：
  // 数据一点没错，但三年级时所有门槛就都失效了，"抉择"不再是抉择。
  group('闭环可行性', () {
    /// 按原著时间线排出 harry_same 时代的分歧点顺序
    List<CausalAnchor> warLineInOrder() {
      final order = [
        'g2_feb_duelling', // 二年级 2 月
        'g5_jun_owls', // 五年级 6 月
        'g5_oct_ministry_decree', // 五年级 10 月
        'g6_jun_headmaster_fall', // 六年级 6 月
        'g6_oct_classmate_loss', // 六年级 10 月
        'g7_may_battle', // 七年级 5 月
        'g7_oct_on_the_run', // 七年级 10 月
      ];
      return order.map((id) => causalAnchorFor(id)!).toList();
    }

    /// 从入学起经过 [days] 个游戏日之后，光靠时间漂出来的变动率。
    ///
    /// 按天积分，不走回合——一回合推进多少分钟取决于玩家在做什么
    /// （默认 15 分钟，睡一觉 480 分钟），按回合算的数字没有意义。
    double driftOnly(double days) {
      var dev = 0.0;
      for (var d = kDeviationTickIntervalDays;
          d <= days;
          d += kDeviationTickIntervalDays) {
        dev = (dev + deviationDriftFor(dev)).clamp(0.0, 1.0);
      }
      return dev;
    }

    /// 各分歧点距入学当天的游戏日数。
    ///
    /// 一学年九月初到六月底 ≈ 270 天，暑假 7-8 月照常算日历天数
    /// （世界不会因为你放假就停摆）。
    const daysAt = <String, double>{
      'g2_feb_duelling': 1.4 * 365,
      'g5_jun_owls': 4.3 * 365,
      'g5_oct_ministry_decree': 4.6 * 365,
      'g6_jun_headmaster_fall': 5.3 * 365,
      'g6_oct_classmate_loss': 5.6 * 365,
      'g7_may_battle': 6.3 * 365,
      'g7_oct_on_the_run': 6.6 * 365,
    };

    /// 跑完一整局，返回（最终变动率, 实际解锁到的锚点 id）。
    (double, List<String>) run({required bool intervene}) {
      var dev = 0.0;
      final decided = <String>{};
      final unlocked = <String>[];
      var prevDays = 0.0;
      for (final a in warLineInOrder()) {
        final days = daysAt[a.anchorId]!;
        // 按天把漂移补上（driftOnly 从 0 起算，这里要的是增量段）
        var d = prevDays + kDeviationTickIntervalDays;
        while (d <= days) {
          dev = (dev + deviationDriftFor(dev)).clamp(0.0, 1.0);
          d += kDeviationTickIntervalDays;
        }
        prevDays = days;

        if (!isCausalAnchorUnlocked(a,
            era: 'harry_same', deviation: dev, decidedAnchorIds: decided)) {
          continue; // 够不着：世界线照原典走，这一夜就那么过去了
        }
        decided.add(a.anchorId);
        unlocked.add(a.anchorId);
        final opt = intervene
            ? a.options.firstWhere((o) => o.isIntervention)
            : a.options.firstWhere((o) => o.id == 'standAside');
        dev = (dev + opt.deviationDelta).clamp(0.0, 1.0);
      }
      return (dev, unlocked);
    }

    test('阻尼：偏得越远漂得越慢，到顶就停', () {
      expect(deviationDriftFor(0.0), closeTo(kDeviationTickBase, 1e-9));
      expect(deviationDriftFor(0.20), lessThan(deviationDriftFor(0.0)));
      expect(deviationDriftFor(0.40), lessThan(deviationDriftFor(0.20)));
      expect(deviationDriftFor(0.45), 0.0);
      expect(deviationDriftFor(0.90), 0.0);
      // 负数当作 0 处理，绝不能倒过来漂出负增量
      expect(deviationDriftFor(-0.3), closeTo(kDeviationTickBase, 1e-9));
      expect(deviationDriftFor(double.nan), 0.0, reason: 'NaN 不能污染存档');
    });

    test('划水到毕业也够不到「已被改写」——想改原著必须先伸手', () {
      // 这是整套门槛的立身之本：什么都不做，塔楼那一夜就只能是史书上那样。
      final end = driftOnly(6.6 * 365);
      expect(end, lessThan(0.40),
          reason: '划水七年漂到 ${(end * 100).toStringAsFixed(1)}%，'
              '那"要不要干预"就没意义了');
    });

    test('但划水也能碰到第一个分歧点——系统不能是死的', () {
      // 上一条的反面：门槛也不能高到玩家一辈子见不着一个抉择。
      final atG2 = driftOnly(1.4 * 365);
      expect(atG2, greaterThanOrEqualTo(0.10),
          reason: '二年级 2 月只漂到 ${(atG2 * 100).toStringAsFixed(1)}%，'
              'fraying 那一档见不着，玩家会以为这套系统根本没在跑');
    });

    test('一路干预：塔楼那一夜与终局之战都够得着', () {
      final (end, unlocked) = run(intervene: true);
      expect(unlocked, contains('g6_jun_headmaster_fall'),
          reason: '一路伸手也只能到 ${(end * 100).toStringAsFixed(1)}%，'
              '塔楼那一夜永远够不着——那这套系统的招牌就没了');
      expect(unlocked, contains('g7_may_battle'));
      expect(unlocked, contains('g7_oct_on_the_run'));
    });

    test('一路干预能推到面目全非', () {
      final (end, _) = run(intervene: true);
      expect(end, greaterThan(0.60),
          reason: '一路干预只到 ${(end * 100).toStringAsFixed(1)}%，'
              'unrecognizable 那一档够不着');
    });

    test('一路旁观：改写过的世界一件都没有', () {
      final (end, unlocked) = run(intervene: false);
      // 旁观项也能解锁（门槛只看变动率），但一个痕迹都不会留下
      expect(unlocked, isNotEmpty);
      expect(end, lessThan(0.40),
          reason: '旁观了七年反而漂到 ${(end * 100).toStringAsFixed(1)}%');
    });

    test('干预与旁观的差距足够大，选择才是有分量的', () {
      final (yes, _) = run(intervene: true);
      final (no, _) = run(intervene: false);
      expect(yes - no, greaterThan(0.35),
          reason: '两种玩法只差 ${((yes - no) * 100).toStringAsFixed(1)}%，'
              '玩家感受不到自己在做选择');
    });

    test('门槛之间是咬合的：跳过一步，后面就够不着了', () {
      // 只干预第一个、其余全部旁观——塔楼那一夜应当够不着。
      // 它证明"每一步都算数"，而不是躺赢。
      var dev = 0.0;
      final decided = <String>{};
      var prevDays = 0.0;
      String? towerOutcome;
      for (final a in warLineInOrder()) {
        final days = daysAt[a.anchorId]!;
        var d = prevDays + kDeviationTickIntervalDays;
        while (d <= days) {
          dev = (dev + deviationDriftFor(dev)).clamp(0.0, 1.0);
          d += kDeviationTickIntervalDays;
        }
        prevDays = days;
        if (a.anchorId == 'g6_jun_headmaster_fall') {
          towerOutcome = isCausalAnchorUnlocked(a,
                  era: 'harry_same', deviation: dev, decidedAnchorIds: decided)
              ? 'open'
              : 'locked';
          // 到这儿为止，只干预了第一个
          break;
        }
        if (isCausalAnchorUnlocked(a,
            era: 'harry_same', deviation: dev, decidedAnchorIds: decided)) {
          decided.add(a.anchorId);
          final opt = a.anchorId == 'g2_feb_duelling'
              ? a.options.firstWhere((o) => o.isIntervention)
              : a.options.firstWhere((o) => o.id == 'standAside');
          dev = (dev + opt.deviationDelta).clamp(0.0, 1.0);
        }
      }
      expect(towerOutcome, 'locked',
          reason: '只干预了二年级那一次、其余全旁观，'
              '塔楼那一夜居然还开着——那前面几步就白选了'
              '（此时变动率 ${(dev * 100).toStringAsFixed(1)}%）');
    });
  });

  // ==================== 存档兼容 ====================
  group('存档', () {
    test('causalChoices 有 JSON 往返', () {
      final ws = WorldState(
        causalChoices: {'g6_jun_headmaster_fall': 'intervene'},
      );
      final json = ws.toJson();
      expect(json['causal_choices'],
          containsPair('g6_jun_headmaster_fall', 'intervene'));
      final back = WorldState.fromJson(json);
      expect(back.causalChoices['g6_jun_headmaster_fall'], 'intervene');
    });

    test('老存档没有这个字段时读到空 Map，不炸', () {
      final ws = WorldState();
      final old = Map<String, dynamic>.from(ws.toJson())
        ..remove('causal_choices');
      final back = WorldState.fromJson(old);
      expect(back.causalChoices, isEmpty);
      // 老存档开局不该凭空多出痕迹
      expect(rewrittenEchoesOf(back.causalChoices), isEmpty);
    });

    test('值被存成非字符串也能兜住', () {
      final ws = WorldState();
      final json = Map<String, dynamic>.from(ws.toJson())
        ..['causal_choices'] = {'g2_feb_duelling': 1};
      expect(WorldState.fromJson(json).causalChoices['g2_feb_duelling'], '1');
    });
  });
}
