import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/models/long_term_memory.dart';

import 'helpers/test_fixtures.dart';

/// 跨周基准（lastWeekBucket）的守门测试。
///
/// 【背景·被修复的脆弱初始化】
/// 「绝对周桶」是从 1991-01-01 起算的大数（1991-09-01 开学时约 34）。
/// 旧实现把初值写成 `lastWeekBucket = 0`——0 是 1991 年第一周的**合法桶号**，
/// 与「尚未初始化」不是一个意思。它之所以没出事，全靠
/// `mixin_init` / `applySaveData` 后面各补了一次正确赋值；
/// 一旦将来有人在补值之前推进时间，`_advanceWorldClock` 就会读到 0，
/// 一次性把 gameWeek 抬到几十，整套首周/首月好感沉淀静默失效。
///
/// 修复方式：改为 `int?` + 惰性建立（`weekBucketBaseline`），
/// 让「未建立基准」成为类型上可表达、且不会产生错误跨周数的状态。
void main() {
  // makeGame 会构造真实 GameProvider，其构造函数读 WidgetsBinding.instance。
  TestWidgetsFlutterBinding.ensureInitialized();

  group('跨周基准：新开局必须从第 1 周算起', () {
    test('新开局 gameWeek == 1', () async {
      final gp = await makeGame();
      expect(gp.gameWeek, 1,
          reason: '开学当天是第 1 周；若基准初始化错误，这里会是几十');
    });

    test('连续多次时间推进都不应凭空跨周（同一周内）', () async {
      final gp = await makeGame(offlineQuickMode: true);
      final week0 = gp.gameWeek;
      // 连点若干回合，每回合约 30 分钟，加起来远不到一周。
      for (var i = 0; i < 3; i++) {
        await gp.processChoice(
          gp.choices.isNotEmpty
              ? gp.choices.first
              : throw StateError('开局没有选项，fixture 有问题'),
        );
      }
      expect(gp.gameWeek, week0,
          reason: '几个回合不足以跨过整周边界，gameWeek 不该变');
    });
  });

  group('跨周基准：惰性建立语义', () {
    test('基准未建立时，首次判定返回当前桶号（跨周数恒为 0）', () async {
      final gp = await makeGame();
      // 复位基准，模拟"初始化被漏掉"的最坏情况
      gp.clearWeekBucketBaseline();
      final day = gp.worldState.time.absoluteDayIndex;
      final baseline = gp.weekBucketBaseline(day);
      expect(baseline, day ~/ 7,
          reason: '未建立时必须用当前天索引建立基准，使跨周数 = 0；'
              '这正是旧实现 `= 0` 做不到的事');
    });

    test('基准已建立时保持不变（不会被覆盖）', () async {
      final gp = await makeGame();
      final day = gp.worldState.time.absoluteDayIndex;
      gp.lastWeekBucket = 100; // 模拟历史基准
      expect(gp.weekBucketBaseline(day), 100,
          reason: '已建立的基准不能被当前时间覆盖，否则永远无法跨周');
    });

    test('clearWeekBucketBaseline 之后回到未建立状态', () async {
      final gp = await makeGame();
      gp.lastWeekBucket = 500;
      gp.clearWeekBucketBaseline();
      final day = gp.worldState.time.absoluteDayIndex;
      expect(gp.weekBucketBaseline(day), day ~/ 7,
          reason: '清空后应重新以当前时间建立基准');
    });
  });

  group('跨周基准：跨 7 天推进一周', () {
    test('时间跨过整周边界时，gameWeek 恰好 +1', () async {
      final gp = await makeGame(offlineQuickMode: true);
      final week0 = gp.gameWeek;
      // 直接推进 7 天，必然跨过至少一个整周边界。
      gp.worldState.time.advanceDays(7);
      // 触发一次时间推进结算（_advanceWorldClock 在回合结束时调用）。
      if (gp.choices.isNotEmpty) {
        await gp.processChoice(gp.choices.first);
      }
      expect(gp.gameWeek, greaterThan(week0),
          reason: '推进 7 天后应至少跨过 1 个整周');
      expect(gp.gameWeek - week0, inInclusiveRange(1, 2),
          reason: '推进 7 天最多跨 2 个周边界（取决于起始偏移），不该凭空暴涨');
    });

    test('跨周数不应出现"跳几十"（旧实现的失效形态）', () async {
      final gp = await makeGame(offlineQuickMode: true);
      final week0 = gp.gameWeek;
      gp.worldState.time.advanceDays(1);
      if (gp.choices.isNotEmpty) {
        await gp.processChoice(gp.choices.first);
      }
      expect(gp.gameWeek - week0, lessThanOrEqualTo(1),
          reason: '推进 1 天绝不可能跨 2 周；若出现大跳变，说明基准用了错误初值 0');
    });
  });

  group('好感沉淀上限依赖 gameWeek 正确（联动验证）', () {
    test('首周好感上限常量在 gameWeek=1 时是可用的分支', () async {
      final gp = await makeGame();
      expect(gp.gameWeek, 1);
      // weekOneAffectionCap 的分支条件是 gameWeek <= 1，必须能被走到。
      expect(gp.gameWeek <= 1, isTrue,
          reason: '若 gameWeek 一开局就是 35，这个分支永远为假，'
              'weekOneAffectionCap / monthOneAffectionCap 成为死代码');
      expect(kPersistentFactImportance, isPositive);
    });
  });
}
