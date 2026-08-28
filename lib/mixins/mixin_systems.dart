import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart';
import '../models/npc.dart';
import '../models/game_systems.dart';
import '../services/deepseek_service.dart';
import '../data/event_anchors.dart';
import '../data/game_config_rules.dart';
import '../data/time_cost_rules.dart';
import '../data/monthly_event_data.dart';
import '../models/player.dart';
import '../models/long_term_memory.dart';
import '../data/balance_constants.dart';
import '../data/goal_data.dart';
import '../services/ai_router.dart';
import '../models/world_state.dart';
import '../providers/game_provider_base.dart';

mixin GameSystemsMixin on GameProviderBase {
  /// 推进世界时钟，并统一执行所有周期性检查
  /// （游戏周、满月、学年切换、事件锚点、一致性、月度演化）。
  ///
  /// [days] 不为 null 时按整天快进（/快进 指令），否则按分钟推进。
  /// [fireAnchors] 为 false 时跳过事件锚点检测——长距离跳跃只在终点触发一次，
  /// 否则一次跳跃会灌入十几个剧情节点通知。
  void _advanceWorldClock(
    int minutes, {
    int? days,
    bool fireAnchors = true,
  }) {
    final oldMonth = worldState.time.month;
    final oldYear = worldState.time.year;
    if (days != null) {
      worldState.time.advanceDays(days);
    } else {
      worldState.time.advanceMinutes(minutes);
    }

    // 游戏周追踪（好感沉淀用）：以绝对天数 / 7 分桶，
    // 只有当绝对天数跨过整周边界时才推进游戏周，避免 dayOfYear 头尾截断导致开局即跨周。
    final newBucket = worldState.time.absoluteDayIndex ~/ 7;
    if (newBucket > lastWeekBucket) {
      // 补齐跨过的所有整周（快进时一次可能跨很多周）
      gameWeek += newBucket - lastWeekBucket;
      lastWeekBucket = newBucket;
      _resetWeeklyAffectionCaps();
    }

    // 深夜触发满月标记
    if (worldState.time.isFullMoon && !worldState.specialMarkers.contains('🌙满月')) {
      worldState.specialMarkers.add('🌙满月');
    } else if (!worldState.time.isFullMoon) {
      worldState.specialMarkers.remove('🌙满月');
    }

    // 同步旧字段
    worldState.dayOfMonth = worldState.time.day;
    worldState.dayOfWeek = GameTime.weekdays[worldState.time.weekday];
    worldState.month = GameTime.months[worldState.time.month - 1];

    // 学年推进检测（9月1日触发）
    _checkSchoolYearTransition(oldMonth, oldYear);

    // 事件锚点检测（按月份触发手写剧情骨架）
    if (fireAnchors) {
      _checkEventAnchors();
    }

    // 孕期推进（结婚 → 备孕 → 分娩）
    this.advancePregnancy();

    _runConsistencyChecks();

    _checkMonthlyEvolution(oldMonth, oldYear);
  }

  void advanceTimeForAction(String action) {
    _advanceWorldClock(resolveActionCost(action));
  }

  // ==================== 每日活动次数上限 ====================

  /// 每个游戏日允许的高收益活动次数上限。
  static const Map<String, int> kDailyActivityLimits = {
    'duel': 3,
    'quidditch': 2,
    'forest': 4,
  };

  /// 今日该活动已进行的次数（跨天自动归零）。
  int dailyCountOf(String activity) {
    _rollDailyActivityIfNeeded();
    return dailyActivityCount[activity] ?? 0;
  }

  int dailyLimitOf(String activity) => kDailyActivityLimits[activity] ?? 99;

  /// 今日是否还能进行该活动。
  bool canDoDaily(String activity) =>
      dailyCountOf(activity) < dailyLimitOf(activity);

  /// 记录一次活动。
  void recordDailyActivity(String activity) {
    _rollDailyActivityIfNeeded();
    dailyActivityCount[activity] = (dailyActivityCount[activity] ?? 0) + 1;
  }

  void _rollDailyActivityIfNeeded() {
    final t = worldState.time;
    final today = '$t.year-$t.month-$t.day';
    if (today != activityDate) {
      activityDate = today;
      dailyActivityCount.clear();
    }
  }

  // ==================== 玩家手记 ====================

  /// 新增一条手记。写入 Player 并落盘，返回后不会丢。
  void addDiaryEntry({
    required String title,
    required String content,
    String mood = '📖',
  }) {
    final p = player;
    if (p == null) return;
    final t = worldState.time;
    p.diary.insert(
      0,
      DiaryEntry(
        date: '$t.year年$t.month月$t.day日',
        time: '${t.hour}:${t.minute.toString().padLeft(2, '0')}',
        title: title,
        content: content,
        mood: mood,
      ),
    );
    notifyListeners();
    unawaited(autoSave());
  }

  void removeDiaryEntry(int index) {
    final p = player;
    if (p == null || index < 0 || index >= p.diary.length) return;
    p.diary.removeAt(index);
    notifyListeners();
    unawaited(autoSave());
  }

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
      // 每次最多走到次月 1 日：保证 _checkMonthlyEvolution 每个月都能触发
      final step = min(remaining, _daysLeftInMonth(t.year, t.month, t.day) + 1);
      final isLastStep = step >= remaining;
      _advanceWorldClock(0, days: step, fireAnchors: isLastStep);
      remaining -= step;
    }

    // 快进后清空停滞计数并同步追踪地点：玩家显然已经不在原来那个场景里了
    turnsAtSameLocation = 0;
    lastTrackedLocation = worldState.currentLocation;

    final endLabel = worldState.time.formatDate();
    worldState.addNarrativeEvent('⏩ 时间快进 $days 天（$startLabel → $endLabel）',
        turn: turnCount);

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

  /// 从当前日期跳到下一个第 [targetMonth] 月 1 日，需要多少天
  int _daysUntilMonth(int targetMonth) {
    final t = worldState.time;
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

  // ==================== 学年推进系统 ====================

  /// 计算当前学年起始年份（9月起为新学年）

  int _schoolYearStartFor(int year, int month) {
    return month >= 9 ? year : year - 1;
  }

  /// 学年切换检测：当进入新的学年（9月）时，推进玩家与 NPC 年级

  void _checkSchoolYearTransition(int oldMonth, int oldYear) {
    final p = player;
    if (p == null) return;
    final t = worldState.time;

    final newStart = _schoolYearStartFor(t.year, t.month);
    if (lastSchoolYearStart == 0) {
      // 首次初始化追踪（不触发晋升）
      lastSchoolYearStart = newStart;
      return;
    }
    if (newStart <= lastSchoolYearStart) return;

    // 跨越了一个或多个学年
    final yearsPassed = newStart - lastSchoolYearStart;
    lastSchoolYearStart = newStart;

    // 玩家已毕业则不再推进
    if (worldState.graduated) {
      updateAcademicYearLabel();
      return;
    }

    final oldGrade = p.grade ?? 1;
    final newGrade = oldGrade + yearsPassed;

    if (newGrade > 7) {
      // 毕业
      // 先结算最后一学年的学院杯：原本这条分支直接毕业，导致七年级全年
      // 攒下的 houseCupPoints 永不结算、永不清零，house_cup_winner 成就
      // 在最后一年也无法达成。同届 NPC 同样需要走一次晋升/毕业。
      _promoteNpcs(yearsPassed);
      settleHouseCup();
      p.grade = 7;
      worldState.graduated = true;
      _onPlayerGraduated(oldGrade);
    } else {
      p.grade = newGrade;
      _promoteNpcs(yearsPassed);
      _onSchoolYearStart(newGrade);
    }
    updateAcademicYearLabel();
  }

  /// 更新学年标签（如 1992-1993）

  void updateAcademicYearLabel() {
    final t = worldState.time;
    final start = _schoolYearStartFor(t.year, t.month);
    worldState.academicYear = '$start-${start + 1}';
    // 学期：9-12月第一学期，1-6月第二学期，7-8月暑假
    if (t.month >= 9) {
      worldState.term = 'first';
    } else if (t.month <= 6) {
      worldState.term = 'second';
    } else {
      worldState.term = 'summer';
    }
  }

  /// 推进所有在校生 NPC 年级，七年级以上者毕业离校

  void _promoteNpcs(int yearsPassed) {
    final graduatedNames = <String>[];
    for (final npc in npcRegistry.values) {
      if (npc.grade <= 0) continue; // 教职/成人不推进
      if (npc.graduated) continue;
      npc.grade += yearsPassed;
      if (npc.grade > 7) {
        npc.graduated = true;
        npc.grade = 7;
        graduatedNames.add(npc.name);
      }
    }
    if (graduatedNames.isNotEmpty) {
      notifications.add('🎓 ${graduatedNames.take(5).join('、')}${graduatedNames.length > 5 ? '等' : ''} 已从霍格沃茨毕业');
      worldState.addNarrativeEvent('🎓 一批高年级学生毕业了：${graduatedNames.take(5).join('、')}', turn: turnCount);
    }
  }

  /// 新学年开始的叙事与通知

  void _onSchoolYearStart(int newGrade) {
    final p = player;
    if (p == null) return;
    // 学年结算：上一学年的学院杯排名揭晓（只结算有贡献的玩家）
    settleHouseCup();
    notifications.add('🏫 新学年开始：你升入了${newGrade}年级');
    worldState.addNarrativeEvent('🏫 ${worldState.time.year}年9月，你升入${newGrade}年级', turn: turnCount);
    worldState.addMarker('⏳新学年');
    // 新学年重置原创NPC生成计数（通过清理标记实现每学年限额）
    debugPrint('🎓 学年推进：玩家升入${newGrade}年级');
  }

  /// 玩家毕业（七年级结束）

  void _onPlayerGraduated(int oldGrade) {
    final p = player;
    if (p == null) return;
    notifications.add('🎓 你从霍格沃茨毕业了！七年的魔法生涯画上句点。');
    worldState.addNarrativeEvent('🎓 ${worldState.time.year}年，你从霍格沃茨毕业', turn: turnCount);
    worldState.addMarker('🎓毕业');
    debugPrint('🎓 玩家毕业（原${oldGrade}年级）');
    // 毕业结算：评估人生目标达成情况并生成结算报告
    _graduationSettlement();
  }

  // ==================== 毕业结算系统 ====================

  /// 评估目标毕业条件，返回 (条件描述, 是否达成) 列表

  List<(String, bool)> _evaluateGoalRequirement(GoalRequirement req) {
    final p = player;
    if (p == null) return [];
    final lines = <(String, bool)>[];
    if (req.reputationDim != null) {
      final cur = p.playerReputation.get(req.reputationDim!);
      lines.add(('${p.playerReputation.labelOf(req.reputationDim!)} ≥ ${req.reputationMin}（当前 $cur）', cur >= req.reputationMin));
    }
    if (req.attributeKey != null) {
      final cur = p.attributes[req.attributeKey!] ?? 0;
      lines.add(('${attrLabel(req.attributeKey!)} ≥ ${req.attributeMin}（当前 $cur）', cur >= req.attributeMin));
    }
    if (req.wealthMin > 0) {
      final cur = p.galleons + p.bankGalleons;
      lines.add(('资产 ≥ ${req.wealthMin} 加隆（当前 $cur）', cur >= req.wealthMin));
    }
    if (req.deepRelationsMin > 0) {
      final cur = npcRegistry.values.where((n) => n.isAlive && n.affection >= 50).length;
      lines.add(('深厚羁绊（好感≥50）≥ ${req.deepRelationsMin} 人（当前 $cur）', cur >= req.deepRelationsMin));
    }
    if (req.worldLineMin > 0) {
      final cur = p.worldLineDeviation;
      lines.add(('世界线变动率 ≥ ${(req.worldLineMin * 100).toStringAsFixed(0)}%（当前 ${(cur * 100).toStringAsFixed(1)}%）', cur >= req.worldLineMin));
    }
    return lines;
  }

  /// 毕业结算：评估人生目标、解锁成就、生成结算报告（追加到当前剧情后）

  void _graduationSettlement() {
    final p = player;
    if (p == null) return;

    unlockAchievement('graduated');

    final goal = p.currentGoal != null ? goalByName(p.currentGoal!) : null;
    final reqLines = goal != null ? _evaluateGoalRequirement(goal.requirement) : <(String, bool)>[];
    final goalMet = reqLines.isNotEmpty && reqLines.every((e) => e.$2);
    if (goalMet) {
      unlockAchievement('goal_achieved');
    }

    final buf = StringBuffer()
      ..writeln('╔══════════════════════════════════════╗')
      ..writeln('  🎓 毕业结算 · ${p.name}')
      ..writeln('╚══════════════════════════════════════╝')
      ..writeln();

    if (goal != null) {
      buf.writeln('【人生目标】${goal.name}');
      for (final (label, met) in reqLines) {
        buf.writeln('  ${met ? '✅' : '❌'} $label');
      }
      buf.writeln(goalMet
          ? '\n🏆 目标达成！你在霍格沃茨的七年，画上了一个方向明确的句号。'
          : '\n这个目标尚未完全达成——但毕业不是终点，你的人生仍可以继续书写。');
    } else {
      buf.writeln('【人生目标】未设定——你的七年平静而真实地流淌而过。');
    }

    final rep = p.playerReputation;
    final deepCount = npcRegistry.values.where((n) => n.isAlive && n.affection >= 50).length;
    buf
      ..writeln()
      ..writeln('【七年统计】')
      ..writeln('· 声望：学术${rep.academic}｜社交${rep.social}｜战斗${rep.combat}｜道德${rep.moral}｜领导${rep.leadership}')
      ..writeln('· 资产：${p.galleons + p.bankGalleons} 加隆')
      ..writeln('· 深厚羁绊：$deepCount 人')
      ..writeln('· 世界线变动率：${(p.worldLineDeviation * 100).toStringAsFixed(1)}%')
      ..writeln('· 成就：${p.achievements.length} / ${achievementCatalog.length}')
      ..writeln()
      ..writeln('输入 /结局 可生成完整终章评语，或继续你的毕业后人生。');

    // 追加到当前剧情之后，保留本回合叙事
    currentNarrative = currentNarrative.isEmpty
        ? buf.toString().trim()
        : '$currentNarrative\n\n${buf.toString().trim()}';
    worldState.addNarrativeEvent('🎓 毕业结算完成${goalMet ? '·人生目标达成' : ''}', turn: turnCount);
  }

  /// 目标进度查询（/目标 进度）

  String formatGoalProgress() {
    final p = player;
    if (p == null) return '尚未创建角色。';
    final goal = p.currentGoal != null ? goalByName(p.currentGoal!) : null;
    if (goal == null) {
      return '尚未设定人生目标。输入 /目标 查看并设定。';
    }
    final lines = _evaluateGoalRequirement(goal.requirement);
    final met = lines.isNotEmpty && lines.every((e) => e.$2);
    final buf = StringBuffer()
      ..writeln('【目标进度】${goal.name}')
      ..writeln('『${goal.description}』')
      ..writeln();
    for (final (label, ok) in lines) {
      buf.writeln('${ok ? '✅' : '⬜'} $label');
    }
    buf.writeln();
    buf.writeln(met
        ? '🏆 所有毕业条件已达成！坚持到毕业即可在结算中获得「得偿所愿」。'
        : '继续朝着目标努力吧——毕业时将进行最终结算。');
    return buf.toString();
  }

  // ==================== 事件锚点系统 ====================

  /// 按当前月份/年级/时代检查并触发手写事件锚点

  void _checkEventAnchors() {
    final p = player;
    if (p == null) return;
    if (worldState.graduated) return; // 毕业后不再触发校内锚点

    final t = worldState.time;
    final fired = worldState.firedAnchorIds.toSet();
    final grade = p.grade ?? 1;

    final due = anchorsFor(
      month: t.month,
      grade: grade,
      era: worldState.era,
      firedIds: fired,
      hour: t.hour,
      currentLocation: worldState.currentLocation,
    );

    // R9：事件锚点进度门（白名单数据化，替代原 id 硬编码特判）
    // 「暑假开始」锚点只在"真正上完了一学年之后"才触发：
    // - 学年是9月开学 → 次年6月结束 → 7月放暑假
    // - 所以1991年7月（入学前）不能触发，1992年7月及之后才可以
    if (due.isNotEmpty) {
      final acYearStart = RegExp(r'^(\d{4})').firstMatch(worldState.academicYear)?.group(1);
      final acYearStartInt = acYearStart != null ? int.tryParse(acYearStart) : null;
      for (final rule in anchorGatedRules) {
        final matchedAnchors = due.where((a) => a.id == rule.anchorId);
        for (final anchor in matchedAnchors) {
          final ok = rule.predicate(t.year, t.month, acYearStartInt);
          if (!ok) {
            due.remove(anchor);
            debugPrint('📜 跳过「${anchor.title}」锚点：${rule.description} (academicYear=${worldState.academicYear}, year=${t.year})');
          }
        }
      }
    }

    if (due.isEmpty) return;

    // 每个回合最多注入一个锚点，避免信息过载；其余顺延
    final anchor = due.first;
    worldState.firedAnchorIds.add(anchor.id);
    pendingAnchorDirective = anchor.directive;
    notifications.add('📜 剧情节点：${anchor.title}');
    worldState.addNarrativeEvent('📜 ${anchor.title}', turn: turnCount);
    debugPrint('📜 事件锚点触发: ${anchor.id} (${anchor.title})');
  }

  void _resetWeeklyAffectionCaps() {
    for (final npc in npcRegistry.values) {
      npc.affectionGainedThisWeek = 0;
    }
    debugPrint('📊 新的一周开始：好感周增量已重置');
  }

  void _checkMonthlyEvolution(int oldMonth, int oldYear) {
    final newMonth = worldState.time.month;
    final newYear = worldState.time.year;
    if (newMonth != oldMonth || newYear != oldYear) {
      _generateMonthlyEvent(newMonth, newYear);
    }
  }

  void _generateMonthlyEvent(int month, int year) {
    // R6：月度事件池数据化（带权重、季节筛选、基础概率）
    final seasonTags = seasonTagsForMonth(month);

    // 1) 季节匹配 + 基础概率过滤
    final candidates = <MonthlyEventDef>[];
    final rand = random;
    for (final e in monthlyEventPool) {
      final seasonMatch = e.seasonTags.isEmpty ||
          e.seasonTags.any((s) => seasonTags.contains(s));
      if (!seasonMatch) continue;
      if (e.baseChance < 1.0 && rand.nextDouble() > e.baseChance) continue;
      candidates.add(e);
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

    // 3) 互斥事件剔除（同一回合已抽到 selected，其他互斥的不参与后续月份事件）
    //    这里简化：月度事件每回合只出 1 条，所以只需要把互斥组内其他候选跳过即可
    //    （实际逻辑 = 本回合就选 1 条，其它互斥检查只在权重池 >1 条时有意义）

    final event = '【${year}年${month}月·月度世界演化】${selected.text}';

    worldState.recentEvents.insert(0, NarrativeEvent(event, turn: turnCount));
    if (worldState.recentEvents.length > 50) {
      worldState.recentEvents.removeLast();
    }

    worldState.housePoints = Map<String, int>.fromEntries(
      worldState.housePoints.entries.map((e) {
        final raw = e.value + random.nextInt(5) - 2;
        final newValue = raw.clamp(0, 9999).toInt();
        return MapEntry(e.key, newValue);
      }),
    );

    notifications.add('🌍 $event');
    worldState.addNarrativeEvent('🌍 $event', turn: turnCount);
  }

  void _runConsistencyChecks() {
    final p = player;
    if (p == null) return;
    final issues = <String>[];

    // ====== 资源值钳制 ======
    p.health = p.health.clamp(0, 100);
    p.magic = p.magic.clamp(0, 100);
    p.spirit = p.spirit.clamp(0, 100);
    p.satiety = p.satiety.clamp(0, 100);
    p.energy = p.energy.clamp(0, 100);

    // ====== 属性合理性检查 ======
    for (final entry in p.attributes.entries) {
      if (entry.value < 0) {
        p.attributes[entry.key] = 0;
        issues.add('属性"${entry.key}"负值，已归零');
      }
      if (entry.value > 100) {
        p.attributes[entry.key] = 100;
        issues.add('属性"${entry.key}"超过100，已钳制');
      }
    }

    // ====== 学院四维检查 ======
    for (final entry in p.houseDimensions.entries) {
      if (entry.value < 0) {
        p.houseDimensions[entry.key] = 0;
        issues.add('学院四维"${entry.key}"负值，已归零');
      }
      if (entry.value > 100) {
        p.houseDimensions[entry.key] = 100;
        issues.add('学院四维"${entry.key}"超过100，已钳制');
      }
    }

    // ====== 世界线变动率检查 ======
    if (p.worldLineDeviation < 0) {
      p.worldLineDeviation = 0;
      issues.add('世界线变动率负值，已修正');
    }
    if (p.worldLineDeviation > 1) {
      p.worldLineDeviation = 1;
      issues.add('世界线变动率超过100%，已钳制');
    }

    // ====== NPC好感与关系检查 ======
    for (final npc in npcRegistry.values) {
      npc.affection = npc.affection.clamp(-100, 100);
      if (!npc.isAlive && p.relationships.containsKey(npc.id)) {
        issues.add('NPC "${npc.name}" 已死亡但仍在关系列表中');
      }
      if (npc.affection > npc.maxAffectionReached) {
        npc.maxAffectionReached = npc.affection;
      }
      if (npc.hasGrudge && npc.affection > npc.effectiveAffectionCap) {
        npc.affection = npc.effectiveAffectionCap;
        issues.add('NPC "${npc.name}" 好感超过背叛前水平，已钳制');
      }
    }

    // ====== 恋爱状态一致性检查 ======
    if (p.loveState.status != '单身') {
      if (p.loveState.partnerId == null || p.loveState.partnerName == null) {
        p.loveState.status = '单身';
        p.loveState.partnerId = null;
        p.loveState.partnerName = null;
        issues.add('恋爱状态不一致（缺少伴侣信息），已重置为单身');
      } else {
        final partnerNpc = npcRegistry[p.loveState.partnerId];
        if (partnerNpc == null || !partnerNpc.isAlive) {
          p.loveState.status = '单身';
          p.loveState.partnerId = null;
          p.loveState.partnerName = null;
          issues.add('恋爱对象已不存在，已重置为单身');
        }
      }
    }

    // ====== 时间合理性检查 ======
    final year = worldState.time.year;
    if (year < 1890 || year > 2100) {
      issues.add('年份异常: $year');
    }
    final month = worldState.time.month;
    if (month < 1 || month > 12) {
      worldState.time.month = month.clamp(1, 12);
      issues.add('月份越界，已修正');
    }
    final day = worldState.time.day;
    if (day < 1 || day > 31) {
      worldState.time.day = day.clamp(1, 31);
      issues.add('日期越界，已修正');
    }

    // ====== 时代一致性检查 ======
    final eraName = worldState.era;
    final appEra = appProvider.era.name;
    if (eraName.isNotEmpty && eraName != appEra) {
      debugPrint('存档时代($eraName)与当前设置($appEra)不一致');
    }

    // ====== 货币合理性 ======
    if (p.galleons < 0) {
      p.galleons = 0;
      issues.add('加隆余额负值，已归零');
    }
    if (p.bankGalleons < 0) {
      p.bankGalleons = 0;
      issues.add('古灵阁存款负值，已归零');
    }

    // ====== 背包物品检查 ======
    p.inventory.removeWhere((item) => item.name.isEmpty);
    if (p.inventory.length > 100) {
      p.inventory.removeRange(100, p.inventory.length);
      issues.add('背包物品超过上限，已清理');
    }

    // ====== 声望合理性检查 ======
    final reputationFields = ['academic', 'social', 'combat', 'moral', 'leadership', 'dark'];
    for (final field in reputationFields) {
      final value = p.playerReputation.get(field);
      if (value < 0 || value > 100) {
        p.playerReputation.setValue(field, value.clamp(0, 100));
        issues.add('声望$field越界，已修正');
      }
    }

    // ====== 成就检查 ======
    checkAllAchievements();

    if (issues.isNotEmpty) {
      notifications.add('⚠️ 状态自修复：${issues.join('；')}');
      debugPrint('🛡️ 防崩坏自检: 修复${issues.length}项状态异常');
    }
  }

  void fastForwardTime(int days) {
    final oldMonth = worldState.time.month;
    final oldYear = worldState.time.year;
    for (int i = 0; i < days; i++) {
      worldState.time.advanceMinutes(24 * 60);
    }
    worldState.dayOfMonth = worldState.time.day;
    worldState.dayOfWeek = GameTime.weekdays[worldState.time.weekday];
    worldState.month = GameTime.months[worldState.time.month - 1];
    // 快进也要接入学年推进、月度演化与事件锚点，避免跳过年份/月份
    _checkSchoolYearTransition(oldMonth, oldYear);
    _checkMonthlyEvolution(oldMonth, oldYear);
    _checkEventAnchors();
    _runConsistencyChecks();
    // 同步游戏周：绝对天数跨过整周边界时推进
    final newBucket = worldState.time.absoluteDayIndex ~/ 7;
    if (newBucket > lastWeekBucket) {
      lastWeekBucket = newBucket;
      gameWeek++;
      _resetWeeklyAffectionCaps();
    }
  }

  // ==================== NPC 状态更新 ====================

  void updateNPCsFromAction(String action) {
    // 消耗资源 - 大幅降低消耗，让玩家有更多精力进行活动
    final p = player!;
    p.energy = max(0, p.energy - 2);  // 从5降到2
    p.satiety = max(0, p.satiety - 2);  // 从3降到2
    p.spirit = max(0, p.spirit - 1);  // 从2降到1

    // 扩展恢复关键词，让更多行动可以恢复精力
    if (action.contains('吃饭') || action.contains('用餐') || 
        action.contains('进食') || action.contains('吃东西')) {
      p.satiety = min(100, p.satiety + 30);
      p.energy = min(100, p.energy + 5);  // 吃饭也恢复少量精力
    }
    if (action.contains('睡觉') || action.contains('休息') || 
        action.contains('睡') || action.contains('歇') ||
        action.contains('躺') || action.contains('养') ||
        action.contains('放松') || action.contains('回房') ||
        action.contains('回宿舍') || action.contains('睡觉') ||
        action.contains('小憩')) {
      p.energy = min(100, p.energy + 50);  // 从40提升到50
      p.spirit = min(100, p.spirit + 30);  // 从20提升到30
      p.satiety = min(100, p.satiety + 5);
    }
    if (action.contains('冥想') || action.contains('打坐') ||
        action.contains('修炼') || action.contains('学习')) {
      p.spirit = min(100, p.spirit + 15);
      p.energy = min(100, p.energy + 5);
    }
    if (action.contains('散步') || action.contains('走') ||
        action.contains('逛') || action.contains('活动')) {
      p.energy = min(100, p.energy + 3);
    }

    // 每日随机触发好感微调。
    // 改走 updateNpcAffection：直接改字段会绕过每周好感上限、记恨上限、
    // recentEvents 与长线记忆管线，等于给所有已认识的人开了个无上限的口子。
    for (final npc in npcRegistry.values.toList()) {
      if (npc.affection > 0 && random.nextDouble() < 0.05) {
        this.updateNpcAffection(npc.id, 1, reason: '日常相处');
      }
    }

    // 检测表白时机（恋爱剧情推进时）
    if (p.loveState.status == '恋爱' && random.nextDouble() < 0.1) {
      _spawnRomanticEvent();
    }

    // 恋爱链路接线：浪漫行动（约会/散步/独处等）为暧昧对象/恋人记录一次浪漫事件
    if (RegExp(r'(约会|散步|独处|谈心|表白|浪漫|心仪|心动|一起去看|一起吃饭|单独)').hasMatch(action)) {
      final love = p.loveState;
      if (love.status == '恋爱' && love.partnerId != null) {
        final partner = npcRegistry[love.partnerId];
        if (partner != null) recordRomanticEventFor(partner);
      } else if (love.currentCrushName != null) {
        for (final n in npcRegistry.values) {
          if (n.name == love.currentCrushName) {
            recordRomanticEventFor(n);
            break;
          }
        }
      }
    }
  }

  void _spawnRomanticEvent() {
    final p = player;
    final partner = p?.loveState.partnerId;
    if (partner == null) return;
    final npc = npcRegistry[partner];
    if (npc == null) return;

    recordRomanticEventFor(npc);
    notifications.add('💕 与${npc.name}之间发生了一段浪漫插曲。');
    worldState.addNarrativeEvent('💕 与${npc.name}之间发生了一段浪漫插曲。', turn: turnCount);
  }

  // ==================== 快速推进 ====================

  Future<void> fastForward(int days) async {
    isLoading = true;
    notifyListeners();
    fastForwardTime(days);
    isLoading = false;
    notifyListeners();
  }

  // ==================== 查看人物 ====================
  Map<String, dynamic>? getViewableCharacter(String npcId) {
    final npc = npcRegistry[npcId];
    if (npc == null || !_isNPCVisible(npc)) return null;

    final rel = player?.relationships[npcId];
    return {
      'id': npc.id,
      'name': npc.name,
      'house': npc.house,
      'grade': npc.grade,
      'location': npc.currentLocation,
      'mood': npc.mood,
      'alive': npc.isAlive,
      'affection': npc.affection,
      'affectionStage': npc.affectionStage,
      'appearance': npc.appearance,
      'relationship': rel != null
          ? {'type': rel.relationType, 'level': rel.level}
          : null,
      'personality': npc.personality,
      'knowsAbout': npc.knowsAbout.take(3).toList(),
      'reputation': npc.reputation,
    };
  }

  bool _isNPCVisible(NPC npc) {
    if (player == null) return false;
    if (player!.relationships.containsKey(npc.id)) return true;
    if (npc.house == player!.house) return true;
    if (npc.isCanon && worldState.playerImpactScore > 0.5) return true;
    return false;
  }

  bool isNearby(String npcId) {
    final npc = npcRegistry[npcId];
    if (npc == null || player == null) return false;
    return npc.currentLocation == (worldState.currentLocation ?? '');
  }

  int getAffection(String npcId) {
    final rel = player?.relationships[npcId];
    if (rel != null) return rel.level;
    final npc = npcRegistry[npcId];
    return npc?.affection ?? 0;
  }

  void travelTo(String location) {
    worldState.currentLocation = location;
    notifyListeners();
  }

  /// 根据玩家行动累计影响力分数
  /// 每回合 +0.01，涉及原著NPC互动 +0.02，涉及关键剧情(恋爱/CG/成就) +0.05

  void updatePlayerImpactScore(String action) {
    double delta = 0.003; // 每回合基础增长：只要玩家做出选择，世界就有极小变动

    // 1. 与原著 NPC 互动：每次提到名字或与其对话，都代表蝴蝶翅膀拍动
    if (npcRegistry.isNotEmpty) {
      for (final npc in npcRegistry.values) {
        if (npc.isCanon && action.contains(npc.name)) {
          delta += 0.015;
          break;
        }
      }
    }

    // 2. 关键剧情关键词（越大的历史事件关键词加分越多）
    const weightedKeywords = <String, double>{
      '魂器': 0.05, '黑魔法': 0.03, '伏地魔': 0.06,
      '表白': 0.02, '恋爱': 0.015, '告白': 0.02,
      '战斗': 0.03, '决斗': 0.035, '冒险': 0.02,
      '秘密': 0.02, '发现': 0.015, '预言': 0.03,
      '死亡': 0.05, '杀死': 0.06, '拯救': 0.04,
      '入学': 0.02, 'OWL': 0.025, 'NEWT': 0.025, '毕业': 0.04,
      '魁地奇': 0.015, '学院杯': 0.02, '三强争霸': 0.04,
      '部长': 0.03, '魔法部': 0.02, '校长': 0.025,
    };
    for (final e in weightedKeywords.entries) {
      if (action.contains(e.key)) {
        delta += e.value;
        break; // 单关键词命中即加分，避免累计爆炸
      }
    }

    // 3. 世界线偏移量辅助：世界线已偏离越多，影响力增速越快（正反馈）
    if (player != null && player!.worldLineDeviation > 0.05) {
      delta *= 1 + player!.worldLineDeviation.clamp(0.0, 0.5);
    }

    worldState.playerImpactScore = (worldState.playerImpactScore + delta).clamp(0.0, 1.0);
  }

  /// 便捷入口：在非 action 场景（告白成功、CG解锁、事件锚点达成、月度事件、
  /// 新 NPC 生成、毕业结算等）直接给 playerImpactScore 加一次分，
  /// 避免这些"真正改变世界"的场景因为不从 updatePlayerImpactScore(action) 走而被忽略。

  void bumpImpactScore(double delta, {String? debugReason}) {
    if (worldState.playerImpactScore >= 1.0) return;
    worldState.playerImpactScore = (worldState.playerImpactScore + delta).clamp(0.0, 1.0);
    if (debugReason != null) {
      debugPrint('🌐 影响力+${delta.toStringAsFixed(3)} → ${worldState.playerImpactScore.toStringAsFixed(3)}（$debugReason）');
    }
  }

  // ==================== 好感度操作（供UI调用） ====================

  void checkLocks(NPC npc) {
    if (npc.affection >= Balance.trustLockThreshold && !npc.hasLock('信任锁')) {
      npc.affectionLocks.add('信任锁');
    }
    if (npc.affection >= Balance.romanceLockThreshold && !npc.hasLock('情感锁')) {
      npc.affectionLocks.add('情感锁');
    }
  }

  Future<ChatResult> callDeepSeek(String prompt, {AiScene scene = AiScene.narrative}) async {
    if (router == null) throw Exception('AI 服务未初始化');
    String effectiveSystemPrompt;
    if (scene == AiScene.choice || scene == AiScene.summary) {
      // 选项/摘要场景：无需注入完整世界观 + 玩家档案，提示词本身已经包含了指令
      effectiveSystemPrompt = scene == AiScene.summary
          ? '你是严谨的剧情摘要员，忠实保留关键信息，不新增设定。'
          : '你是专业的游戏选项设计师，只输出符合要求的4个选项。';
    } else {
      // 每次 narrative/npcChat 调用前刷新系统提示词，确保玩家动态状态实时注入
      if (player != null) {
        systemPrompt = buildSystemPrompt();
      }
      effectiveSystemPrompt = systemPrompt ?? '';
    }
    // 2026-08-24：maxTokens 按场景精细化分配
    //   narrative 主剧情：4000（配合 600-800 字精练叙事要求，总 token 约 2000-3000）
    //   choice 选项：1000（只输出 4 行 ABCD ≈ 300 tokens，留余量给思考型模型的推理过程）
    //   summary 摘要：4000（输出 800-2400 字摘要 + 结构化记忆块）
    //   npcChat NPC聊天：4000（对话场景需要一定长度）
    final maxTokens = switch (scene) {
      AiScene.narrative => 4000,
      AiScene.choice => 1000,
      AiScene.summary => 4000,
      AiScene.npcChat => 4000,
    };
    final result = await router!.chatComplete(
      scene: scene,
      prompt: prompt,
      systemPrompt: effectiveSystemPrompt,
      temperature: 0.85,
      maxTokens: maxTokens,
    );
    // 使用 try-catch 保护 token 统计，避免因 API 返回格式异常导致崩溃
    try {
      totalPromptTokens += result.usage.promptTokens;
      totalCompletionTokens += result.usage.completionTokens;
      totalTokens += result.usage.totalTokens;
      lastRoundTokens = result.usage.totalTokens;
      apiCalls++;
      notifyListeners();
    } catch (e) {
      debugPrint('[GameProvider] Token 统计异常(不影响游戏): $e');
    }
    return result;
  }

  // ==================== 解析响应 ====================

  /// 从叙事文本中智能提取分院结果并赋值给 player.house
  /// 带语境判断：只有当文本中出现明确分院动作时才匹配。

  Future<void> quickSave() async {
    if (player == null) return;
    await saveService.saveGame(
      player: player!.toJson(),
      worldState: worldState.toJson(),
      npcRegistry: npcRegistry.map((k, v) => MapEntry(k, v.toJson())),
      narrative: currentNarrative,
      choices: choices.map((c) => {'text': c.text, 'action': c.action}).toList(),
      turnCount: turnCount,
      slotName: '快速存档',
      extraData: {
        'narrative_summary': narrativeSummary,
        'pending_summary': pendingSummary,
        'recent_turns': recentTurns,
        'game_week': gameWeek,
        'last_school_year_start': lastSchoolYearStart,
        'last_round_tokens': lastRoundTokens,
        'api_calls': apiCalls,
        'total_prompt_tokens': totalPromptTokens,
        'total_completion_tokens': totalCompletionTokens,
        'total_tokens': totalTokens,
        // 千回合级结构化长期记忆（永不压缩的纯事实层）
        'long_term_memory': memory.toJson(),
      },
    );
  }

  /// 使用用户自定义名称保存存档（slotId 由名称生成，保证可读且唯一可寻址）
  Future<void> saveGameNamed(String slotName) async {
    if (player == null) return;
    final safeName = slotName
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    if (safeName.isEmpty) return;
    await saveService.saveGame(
      player: player!.toJson(),
      worldState: worldState.toJson(),
      npcRegistry: npcRegistry.map((k, v) => MapEntry(k, v.toJson())),
      narrative: currentNarrative,
      choices: choices.map((c) => {'text': c.text, 'action': c.action}).toList(),
      turnCount: turnCount,
      slotName: safeName,
      extraData: {
        'narrative_summary': narrativeSummary,
        'pending_summary': pendingSummary,
        'recent_turns': recentTurns,
        'game_week': gameWeek,
        'last_school_year_start': lastSchoolYearStart,
        'last_round_tokens': lastRoundTokens,
        'api_calls': apiCalls,
        'total_prompt_tokens': totalPromptTokens,
        'total_completion_tokens': totalCompletionTokens,
        'total_tokens': totalTokens,
        'long_term_memory': memory.toJson(),
      },
    );
  }

  static const int _saveVersion = 2;

  Future<void> loadFromSave(String slotId) async {
    final data = await saveService.loadGame(slotId);
    if (data == null) return;

    final version = data['save_version'] as int? ?? 1;
    _migrateSave(data, version);

    player = Player.fromJson(data['player'] as Map<String, dynamic>);
    worldState = WorldState.fromJson(data['world_state'] as Map<String, dynamic>);
    npcRegistry.clear();
    final npcMap = data['npc_registry'] as Map<String, dynamic>? ?? <String, dynamic>{};
    npcMap.forEach((k, v) {
      npcRegistry[k] = NPC.fromJson(v as Map<String, dynamic>);
    });
    // 在 player/worldState/npc 赋值之后再构建系统提示词（_buildSystemPrompt 会用到）
    systemPrompt = buildSystemPrompt();

    currentNarrative = data['narrative'] as String? ?? '';
    choices = (data['choices'] as List<dynamic>?)
        ?.map((c) => GameChoice(text: c['text'] as String, action: c['action'] as String))
        .toList() ?? [];
    turnCount = data['turn_count'] as int? ?? 0;
    final extraData = data['extra_data'] as Map<String, dynamic>? ?? {};
    narrativeSummary = extraData['narrative_summary'] as String? ?? '';
    pendingSummary = extraData['pending_summary'] as String? ?? '';
    gameWeek = extraData['game_week'] as int? ?? 1;
    lastSchoolYearStart = extraData['last_school_year_start'] as int? ?? 0;
    lastWeekBucket = worldState.time.absoluteDayIndex ~/ 7;
    lastRoundTokens = extraData['last_round_tokens'] as int? ?? 0;
    apiCalls = extraData['api_calls'] as int? ?? 0;
    totalPromptTokens = extraData['total_prompt_tokens'] as int? ?? 0;
    totalCompletionTokens = extraData['total_completion_tokens'] as int? ?? 0;
    totalTokens = extraData['total_tokens'] as int? ?? 0;
    // 加载千回合级结构化长期记忆
    memory = LongTermMemory.fromJson(
        extraData['long_term_memory'] as Map<String, dynamic>?);

    recentTurns
      ..clear()
      ..addAll((extraData['recent_turns'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          []);
    if (recentTurns.isEmpty && currentNarrative.isNotEmpty) {
      recentTurns.add(currentNarrative);
    }

    // 完整性兜底：只在空的时候补默认
    if (choices.isEmpty) choices = generateFallbackChoices();
    if (choices.length > 4) choices = choices.sublist(0, 4);
    if (currentNarrative.isEmpty) currentNarrative = generateFallbackNarrative();

    // 任何读档之后都必须确保 isLoading=false / isInitializing=false，
    // 否则"继续游戏"后会卡住或误触发再次请求
    isLoading = false;
    isInitializing = false;
    error = null;
    loadingStage = '';

    _runConsistencyChecks();
    appProvider.setGameStarted(true);
    notifyListeners();
    unawaited(autoSave());
  }

  void _migrateSave(Map<String, dynamic> data, int version) {
    if (version < 2) {
      final ws = data['world_state'] as Map<String, dynamic>?;
      if (ws != null) {
        const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
        final oldMonth = ws['month'] as String?;
        if (oldMonth != null) {
          final idx = monthNames.indexOf(oldMonth);
          if (idx >= 0) {
            ws['month'] = GameTime.months[idx];
            debugPrint('存档迁移: month "$oldMonth" -> "${ws['month']}"');
          }
        }
        if (!ws.containsKey('time')) {
          debugPrint('存档迁移: 从旧字段推导 time 字段');
          final yearStr = ws['academic_year'] ?? '1991-1992';
          final yearMatch = RegExp(r'^(\d{4})').firstMatch(yearStr.toString());
          final year = yearMatch != null ? int.tryParse(yearMatch.group(1)!) ?? 1991 : 1991;
          final monthIdx = monthNames.indexOf(ws['month'] as String? ?? '') + 1;
          ws['time'] = {
            'year': year,
            'month': monthIdx > 0 ? monthIdx : 9,
            'day': ws['day_of_month'] as int? ?? 1,
            'weekday': 2,
            'hour': 9,
            'minute': 0,
          };
        }
      }
      data['save_version'] = _saveVersion;
    }
  }

  Future<List<Map<String, dynamic>>> listSaves() async {
    return saveService.listSaves();
  }

  Future<bool> deleteSave(String slotId) async {
    return saveService.deleteSave(slotId);
  }

  /// 导出存档为 JSON 字符串（用于备份/跨设备迁移）
  Future<String?> exportSave(String slotId) async {
    return saveService.exportSave(slotId);
  }

  /// 从 JSON 字符串导入存档，返回新槽 id
  Future<String?> importSave(String jsonString) async {
    return saveService.importSave(jsonString);
  }

  // ==================== API 检查 ====================

  Future<bool> checkConnection() async {
    if (router == null) return false;
    final provider = appProvider.aiProvider;
    return await router!.checkBalance(provider) != null ||
        appProvider.hasKey(provider);
  }

  Future<double?> get balance async {
    if (router == null) return null;
    final provider = appProvider.aiProvider;
    return await router!.checkBalance(provider);
  }

  Future<Map<String, dynamic>?> get quotaInfo async {
    if (router == null) return null;
    final provider = appProvider.aiProvider;
    final services = router!.getServices(provider);
    if (services == null || services.isEmpty) return null;
    return await services.first.getQuotaInfo();
  }

  void resetTokenUsage() {
    totalPromptTokens = 0;
    totalCompletionTokens = 0;
    totalTokens = 0;
    apiCalls = 0;
    notifyListeners();
  }

  // ==================== 辅助方法 ====================

  String bloodStatusLabel(String status) {
    return {
      'muggleborn': '麻瓜出身',
      'halfblood': '混血巫师',
      'pureblood': '纯血',
      'pureblood_side': '纯血旁支',
      'pureblood_sacred': '神圣二十八族',
      'special': '特殊家庭',
      'squib': '哑炮',
      'obscurial': '默然者',
      'veela': '混血媚娃',
      'werewolf': '狼人',
      'half_giant': '半巨人',
      'muggle_family': '麻瓜家庭',
      'custom': '自定义',
    }[status] ?? status;
  }

  String attrLabel(String key) {
    return {
      'spell_understanding': '魔咒理解',
      'transfiguration': '变形术',
      'potions': '魔药',
      'herbology': '草药学',
      'dda': '黑魔法防御',
      'flying': '飞行',
      'theory': '理论知识',
      'memory': '记忆力',
      'observation': '观察力',
      'magic_control': '魔法控制',
      'reaction_time': '反应速度',
      'emotional_stability': '情绪稳定',
      'creativity': '创造力',
      'social': '社交',
      'courage': '勇气',
      'caution': '谨慎',
      'willpower': '意志',
      'logic': '逻辑',
      'intuition': '直觉',
    }[key] ?? key;
  }

  String termLabel(String term) {
    return {
      'first': '第一学期',
      'second': '第二学期',
      'third': '第三学期',
      'summer': '暑假',
    }[term] ?? term;
  }

  String flowModeLabel(String mode) {
    return {
      'normal': '正常',
      'story': '剧情加速',
      'fast': '快速',
    }[mode] ?? mode;
  }

  @override

  void dispose() {
    saveNow(); // 异步但会同步快照状态并立即写盘，避免 300ms 防抖未完成导致存档丢失
    appProvider.removeListener(onApiKeyChange);
    super.dispose();
  }
}
