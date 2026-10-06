import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/balance_constants.dart';
import '../data/monthly_event_data.dart';
import '../models/world_state.dart';
import '../providers/game_provider_base.dart';
import '../utils/debug_log.dart';
import 'mixin_systems.dart';

/// 日历与月度演化（第九轮 r9-3 拆分自 mixin_systems.dart）。
///
/// 【拆分说明】时间快进族（/快进 指令后端：fastForwardDays 全量结算 /
/// resolveFastForwardDays 参数解析 / 月末日数计算）与月度演化族
/// （checkMonthlyEvolution / _generateMonthlyEvent / 好感漂移 / 传闻衰减 /
/// monthly 互斥冷却）约 300 行，从 mixin_systems 迁入本文件。
/// `GameSystemsMixin` 声明 `on GameSystemsCalendarMixin`（跨 mixin 走 on 链，
/// 遵守 ADR-001），`GameProvider` 的 with 列表中 calendar 在 systems 之前。
/// 行为零变化：所有成员仍是 GameProvider 上的实例成员，测试契约不变。
mixin GameSystemsCalendarMixin on GameProviderBase {

    // ==================== 时间快进（/快进） ====================

  /// 距本月最后一天还剩几天（返回 0 表示今天就是月末）。
  int _daysLeftInMonth(int year, int month, int day) {
    const dims = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    var dim = dims[(month - 1).clamp(0, 11)];
    if (month == 2 && ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0)) {
      dim = 29;
    }
    return (dim - day).clamp(0, dim);
  }

  /// 快进若干天。
  ///
  /// 动机：一回合平均只推进 60~90 分钟，七年制毕业需要约 6 万回合，
  /// 毕业结局、学院杯、高年级专属锚点实际上永远达不到。
  /// 快进让玩家能主动跳到"下一个假期/下一学年"，同时仍然逐步结算
  /// 月度演化与学年切换，不会把中间的过程整个吞掉。
  ///
  /// 返回本次快进产生的新通知列表（供 UI 汇总展示）。
  List<String> fastForwardDays(int days) {
    if (days <= 0) return const [];
    if (player == null) return const [];

    final startLabel = worldState.time.formatDate();
    final notifyFrom = notifications.length;

    var remaining = days;
    var guard = 0;
    while (remaining > 0 && guard++ < 200) {
      final t = worldState.time;
      // 每次最多走到次月 1 日：保证 checkMonthlyEvolution 每个月都能触发
      final step = min(remaining, _daysLeftInMonth(t.year, t.month, t.day) + 1);
      // 每一步都查锚点：只查末步会把跨过的整月锚点整个吞掉
      // （月份已经过去，错过即错过——但至少要触发"本月该发生的事"）。
      (this as GameSystemsMixin).advanceWorldClock(0, days: step, fireAnchors: true);
      remaining -= step;
    }

    // 快进后清空停滞计数并同步追踪地点：玩家显然已经不在原来那个场景里了
    turnsAtSameLocation = 0;
    lastTrackedLocation = worldState.currentLocation;

    final endLabel = worldState.time.formatDate();
    worldState.addNarrativeEvent(
      '⏩ 时间快进 $days 天（$startLabel → $endLabel）',
      turn: turnCount,
    );

    if (notifications.length > notifyFrom) {
      return notifications.sublist(notifyFrom);
    }
    return const [];
  }

  /// 把「明天 / 下周 / 下月 / 下学期 / 假期 / 下学年 / N天」解析成天数。
  int resolveFastForwardDays(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return 7;
    final n = int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), ''));
    if (n != null && n > 0) return min(n, 365);

    final t = worldState.time;
    if (s.contains('明天')) return 1;
    if (s.contains('下周')) return 7;
    if (s.contains('两周')) return 14;
    if (s.contains('下月') || s.contains('下个月')) return 30;
    if (s.contains('圣诞') || s.contains('假期') || s.contains('放假')) {
      // 跳到下一个假期起点：12月(圣诞)或7月(暑假)
      return _daysUntilMonth(t.month == 12 ? 7 : 12);
    }
    if (s.contains('暑假')) return _daysUntilMonth(7);
    if (s.contains('学期') || s.contains('开学')) return _daysUntilMonth(9);
    if (s.contains('下学年') || s.contains('明年') || s.contains('下一年')) {
      return _daysUntilMonth(9);
    }
    return 7;
  }

  /// 从当前日期跳到下一个第 [targetMonth] 月 1 日，需要多少天。
  ///
  /// 已经身处目标月份时返回 0——玩家要的就是「快进到暑假」，
  /// 而 7 月里本来就在放暑假。
  /// 老实现从 `t.month + 1` 起算，`targetMonth == t.month` 时 while 循环
  /// 要绕满 12 个月才退出，于是 7 月里输「/快进 暑假」会一下跳掉约 351 天，
  /// 整整一年就这么没了。
  int _daysUntilMonth(int targetMonth) {
    final t = worldState.time;
    if (t.month == targetMonth) return 0;

    var days = _daysLeftInMonth(t.year, t.month, t.day) + 1; // 到次月1日
    var m = t.month + 1;
    var y = t.year;
    while (m != targetMonth) {
      const dims = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
      var dim = dims[(m - 1) % 12];
      if (m == 2 && ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0)) dim = 29;
      days += dim;
      m++;
      if (m > 12) {
        m = 1;
        y++;
      }
    }
    return max(1, days);
  }


    void resetWeeklyAffectionCaps([int weeksCrossed = 1]) {
    for (final npc in npcRegistry.values) {
      npc.affectionGainedThisWeek = 0;
    }
    debugLog('📊 新的一周开始：好感周增量已重置');
    _applyAffectionDrift(weeksCrossed);
  }
  void checkMonthlyEvolution(int oldMonth, int oldYear) {
    final newMonth = worldState.time.month;
    final newYear = worldState.time.year;
    if (newMonth != oldMonth || newYear != oldYear) {
      _generateMonthlyEvent(newMonth, newYear);
    }
  }
  void _applyAffectionDrift(int weeksCrossed) {
    if (weeksCrossed <= 0) return;
    final p = player;
    final today = worldState.time.absoluteDayIndex;
    final decayWeeksCap = weeksCrossed.clamp(1, 4);
    final drifted = <String>[];

    for (final npc in npcRegistry.values) {
      if (!npc.isAlive || !npc.introduced) continue;
      if (npc.affection <= Balance.affectionDriftFloor) continue;
      if (npc.hasLock('信任锁')) continue;
      if (p != null && p.loveState.partnerId == npc.id) continue;
      // -1 = 老存档/从未互动：按刚刚互动过处理，豁免（见 NPC 字段注释）
      if (npc.lastAffectionTouchDay < 0) continue;

      final idleDays = today - npc.lastAffectionTouchDay;
      if (idleDays < Balance.affectionDriftIdleDays) continue;

      // idle 超过宽限期后，每多一周淡一次；本次跨了几周就最多补几周
      final overdueWeeks = (idleDays - Balance.affectionDriftIdleDays) ~/ 7 + 1;
      final weeks = overdueWeeks < decayWeeksCap ? overdueWeeks : decayWeeksCap;

      var total = 0;
      for (var i = 0; i < weeks; i++) {
        total +=
            Balance.affectionDriftPerWeekMin +
            random.nextInt(
              Balance.affectionDriftPerWeekMax -
                  Balance.affectionDriftPerWeekMin +
                  1,
            );
      }
      final before = npc.affection;
      npc.affection = (npc.affection - total).clamp(
        Balance.affectionDriftFloor,
        100,
      );
      if (npc.affection != before) {
        syncRelationshipLevel(npc);
        drifted.add(npc.name);
        // P1-10 观测日志：衰减体感/好感通胀速度留待真实数据调参，
        // 记录每次衰减的 NPC/天数/幅度，供后续根据实际档位校准
        // affectionDriftPerWeekMin/Max。
        if (kDebugMode) {
          debugLog(
            '[好感衰减] ${npc.name}: $before → ${npc.affection}'
            '（闲置 $idleDays 天，结算 $weeks 周，合计 -$total）',
          );
        }
      }
    }

    if (drifted.isNotEmpty) {
      // 聚合播报：一次跨多周时逐个刷通知是惩罚玩家，一句话说清即可
      final shown = drifted.take(3).join('、');
      final more = drifted.length > 3 ? ' 等 ${drifted.length} 人' : '';
      final text = '💨 有些日子没和 $shown$more 联系了，彼此似乎都生分了一点';
      notifications.add(text);
      worldState.addNarrativeEvent(text, turn: turnCount);
    }

    // 传闻时间衰减：超过 30 天的旧闻自动淡出（舆论不是永久档案）
    _decayRumors();
  }
  void _decayRumors() {
    final p = player;
    if (p == null || p.rumors.isEmpty) return;
    final today = worldState.time.absoluteDayIndex;
    final before = p.rumors.length;
    p.rumors.removeWhere((r) {
      final d = p.rumorDates[r];
      if (d == null) return false; // 老存档无日期：保留
      return today - d > 30;
    });
    if (p.rumors.length != before) {
      p.rumorDates.removeWhere((k, _) => !p.rumors.contains(k));
      debugLog('📰 传闻衰减：${before - p.rumors.length} 条旧闻淡出');
    }
  }
  void _generateMonthlyEvent(int month, int year) {
    // R6：月度事件池数据化（带权重、季节筛选、基础概率）
    final seasonTags = seasonTagsForMonth(month);
    // 月份序号，用来算"这条多久之前播过"
    final monthIndex = year * 12 + month;

    // 1) 季节匹配 + 基础概率过滤 + 去重/互斥过滤
    //
    // 以前这里每次跨月都从整池重抽：上个月刚播过「魔法部宣布新一轮教育
    // 改革」，这个月原样再来一遍，玩家一眼就能看出世界是假的。
    // 现在按两项规则剔除：
    //   a) 同一条事件 [MonthlyEventDef.repeatCooldownMonths] 个月内不重复；
    //   b) mutuallyExclusiveIds 里写的事件，在 [kMutuallyExclusiveMonths]
    //      个月内被抽中过的话，本条本次不参与。
    final candidates = <MonthlyEventDef>[];
    final rand = random;
    for (final e in monthlyEventPool) {
      final seasonMatch =
          e.seasonTags.isEmpty ||
          e.seasonTags.any((s) => seasonTags.contains(s));
      if (!seasonMatch) continue;
      if (e.baseChance < 1.0 && rand.nextDouble() > e.baseChance) continue;
      if (_monthlyEventOnCooldown(e, monthIndex)) continue;
      candidates.add(e);
    }
    // 全被冷却挡掉了（长局后期常见）：放宽到只保留互斥，忽略重复冷却，
    // 保证每个月总有一条世界新闻，而不是静悄悄地什么都不发生。
    if (candidates.isEmpty) {
      for (final e in monthlyEventPool) {
        final seasonMatch =
            e.seasonTags.isEmpty ||
            e.seasonTags.any((s) => seasonTags.contains(s));
        if (!seasonMatch) continue;
        if (_monthlyEventBlockedByExclusive(e, monthIndex)) continue;
        candidates.add(e);
      }
    }
    if (candidates.isEmpty) return;

    // 2) 权重抽取
    int totalWeight = 0;
    for (final e in candidates) {
      totalWeight += e.weight > 0 ? e.weight : 1;
    }
    int pick = rand.nextInt(totalWeight);
    MonthlyEventDef? selected;
    for (final e in candidates) {
      final w = e.weight > 0 ? e.weight : 1;
      if (pick < w) {
        selected = e;
        break;
      }
      pick -= w;
    }
    selected ??= candidates.last;

    // 3) 记账：下次抽取时靠这条记录做去重与互斥判定
    worldState.monthlyEventFiredAt[selected.id] = monthIndex;

    final event = '【$year年$month月·月度世界演化】${selected.text}';

    worldState.recentEvents.insert(0, NarrativeEvent(event, turn: turnCount));
    if (worldState.recentEvents.length > 50) {
      worldState.recentEvents.removeLast();
    }

    notifications.add('🌍 $event');
    worldState.addNarrativeEvent('🌍 $event', turn: turnCount);
  }

  @override
  void fastForwardTime(int days) {
    // P0-3 收敛：统一委托 fastForwardDays（内部走 advanceWorldClock 全量结算：
    // 游戏周/学院杯/NPC位置/学年推进/事件锚点/孕期/月度演化/传闻）。
    // 旧的独立实现按天循环，漏了 NPC 位置刷新、孕期推进、学院杯对手分、
    // 传闻生成，且 checkEventAnchors() 用默认 hourFrom/dayDelta 匹配，
    // 快进跨过的事件窗口会整体错位——两套实现因此不等价。
    // 注意：fastForwardDays 对超大天数有 guard 上限（200 步内每月推进），
    // 因此这里的超大值（如 /cheat 时间 999999）不会冻结主线程。
    fastForwardDays(days);
  }

  bool _monthlyEventOnCooldown(MonthlyEventDef e, int monthIndex) {
    final lastAt = worldState.monthlyEventFiredAt[e.id];
    if (lastAt != null &&
        monthIndex - lastAt < MonthlyEventDef.repeatCooldownMonths) {
      return true;
    }
    return _monthlyEventBlockedByExclusive(e, monthIndex);
  }

  bool _monthlyEventBlockedByExclusive(MonthlyEventDef e, int monthIndex) {
    for (final otherId in e.mutuallyExclusiveIds) {
      final lastAt = worldState.monthlyEventFiredAt[otherId];
      if (lastAt == null) continue;
      if (monthIndex - lastAt < kMutuallyExclusiveMonths) return true;
    }
    return false;
  }

}
