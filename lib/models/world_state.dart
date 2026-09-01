import 'game_systems.dart';

class NarrativeEvent {
  final String text;
  final int? turn;
  final DateTime? at;

  const NarrativeEvent(this.text, {this.turn, this.at});

  Map<String, dynamic> toJson() => {
    't': text,
    if (turn != null) 'r': turn,
    if (at != null) 'a': at!.toIso8601String(),
  };

  factory NarrativeEvent.fromJson(dynamic src) {
    if (src is String) return NarrativeEvent(src);
    if (src is Map<String, dynamic>) {
      return NarrativeEvent(
        src['t'] as String? ?? src['text'] as String? ?? '',
        turn: src['r'] as int? ?? src['turn'] as int?,
        at: src['a'] != null ? DateTime.tryParse(src['a'] as String) : null,
      );
    }
    return const NarrativeEvent('');
  }
}

class WorldState {
  String academicYear;
  String term;
  String month; // 兼容旧存档（英文月份名）
  int dayOfMonth;
  String dayOfWeek; // 兼容旧存档
  String era;

  // 注：这里曾经有个 `Map<String, int> housePoints`，四个学院各 350 分起步，
  // 每月在月度事件播报之后 `+ random.nextInt(5) - 2` 随机游走一次。
  // 它跟学院杯**是两套互不相干的东西**：学院杯用的是
  // Player.houseCupPoints（玩家贡献分）+ 学年结算时临时算的对手基准分，
  // 从不读这个字段；而这个字段的 key 还是英文的（'Gryffindor'），
  // 跟学院杯系统的中文名也对不上。
  // 结果是：有一组数字在动、在存盘，玩家看不见、影响不了、也永远不会揭晓。
  // 已删除。旧存档里多一个 house_points 键不影响读取。
  List<NarrativeEvent> recentEvents;
  List<NarrativeEvent> recentNarrativeEvents;
  double playerImpactScore; // 玩家对世界的真实影响力(0.0~1.0): 关键行动/原著NPC互动/CG解锁/成就达成累计加分, 达到0.5+时原著NPC对玩家主动可见

  // ====== 设定文档扩展字段 ======
  GameTime time; // 完整时间系统
  String timeFlowMode; // 预留字段: 设计钩子, normal/story/fast, 当前仅显示不影响时间推进
  final List<String> specialMarkers; // 特殊标记: ⏳命运时刻/🌙满月/📜考试周/🎄圣诞/⚡事件触发
  String? currentLocation;
  String? currentLocationLabel; // 玩家为当前区域自定义的名称（地图页编辑）
  String? weather;
  int timelineChanges; // 世界线变动次数
  final List<String> timelineBranches; // 已分叉的世界线描述

  /// 世界线分叉时的世界快照（世界线重演的记录侧基建）。
  ///
  /// 与 [timelineBranches] 按下标一一对应：第 i 条分支附第 i 份快照。
  /// 快照只记"当时的世界长什么样"（日期/学年/地点/变动率/影响力），
  /// 不存可回放状态——交互式重演（改一个选择看世界怎么变）需要完整
  /// 状态快照与分支树，工程量大，是后续产品决策项。当前先让玩家能
  /// "回看"每个分叉点发生时的世界状态。
  final List<Map<String, dynamic>> timelineSnapshots;

  // ====== 学年系统扩展字段 ======
  final List<String> firedAnchorIds; // 已触发的事件锚点（防重复）

  /// 因果锚点抉择记录：事件锚点 id → 所选选项 id。
  ///
  /// 见 lib/data/worldline_data.dart。这是玩家"改写过什么"的唯一存档依据，
  /// 存的是 id 而不是文本——文案以后要改，存档里的旧 id 依然查得到。
  final Map<String, String> causalChoices;

  /// 月度事件 id → 上次发生的月份序号（`year * 12 + month`）。
  ///
  /// 月度事件此前每跨一个月就重抽一次，抽到什么都照播：
  /// 「魔法部宣布新一轮教育改革」上个月刚演过，这个月原样再来一遍，
  /// 玩家立刻就能感觉到世界是假的。现在用它做去重与互斥判定。
  final Map<String, int> monthlyEventFiredAt;

  bool graduated; // 玩家是否已毕业（七年级后）
  final Set<String> visitedLocations; // 玩家曾经到过的地点（自动去重，用于「探索者」成就校验）

  // ====== 短期断言系统（Short Assertions）======
  // 解决"上一回合刚做的事（封门/躲起来/受伤/被缴械）下一回合AI就失忆"的逻辑打脸bug。
  // - lastTurnAssertions：上一回合从叙事末尾提取的 3~5 条"生效中状态"，本回合 Prompt 必注入。
  //   每回合末轮换：旧的 → previousTurnAssertions，新的 → lastTurnAssertions（实现"断言生效 2 回合后自动过期"）。
  // - previousTurnAssertions：上上回合的断言，也一起注入给 AI 参考，但标注"可能已变化"，避免单回合内的临时状态跨太久。
  final List<String> lastTurnAssertions;
  final List<String> previousTurnAssertions;

  // ====== 剧情一致性违规记录（调试+UI用）======
  // 最近 10 条被看门狗拦下的违规，方便调参和定位 AI 风格问题。
  final List<Map<String, dynamic>> consistencyViolations;

  // ====== 【宏观 M3 · ContinuityBridge 全局衔接桥】======
  // lastNarrativeAnchor：上一回合 narrative 末尾的"衔接锚点"（最后说话者/最后一句对话/最后未完成动作/当前地点）。
  //  任何时候生成新 narrative（正常/Critical重写/事件触发），都要：
  //   1) 生成前 → Prompt 强制注入此锚点；
  //   2) 生成后 → 正则校验新叙事是否与该锚点显式衔接；
  //   3) 不衔接 → 在叙事开头自动补一句承接过渡（不打回重写，避免"换剧情"观感）。
  // 用 Map<String,String> 存，便于后期扩展字段而不破旧存档。
  final Map<String, String> lastNarrativeAnchor;

  // 统计连续"不衔接"的次数，达到阈值会给玩家一条通知，避免一次误判就响警报。
  int continuityBridgeMisses;

  // ====== 学院杯 · 年度榜 ======
  // 学年榜不是学年末掷一次骰子：四院各从基准分起步，其他三院在学期内按
  // 上学日逐日自然增长（世界不因玩家而停转），玩家的学院行 = 基准 + 玩家
  // 本学年贡献。学年结算时揭晓并写入 houseCupYearHistory，随后清空开始新学年。
  final Map<String, int> houseCupYearly;

  /// 历届年度榜：学年名（"1991-1992"）→ 结算摘要。七年榜单可随时回顾。
  final Map<String, String> houseCupYearHistory;

  // ====== 学院杯 · 刷分防御 ======
  // 日常加分靠 AI 文本关键词触发，可被反复凑词刷分。这里按天/周记账，
  // 超上限后当天/本周不再通过叙事关键词加日常分（扣分不受限）。
  int narrativeHouseGainDay; // 当日已通过叙事关键词加的日常分
  int narrativeHouseGainDayKey; // 记账的绝对天数，跨天清零
  int narrativeHouseGainWeek; // 本周已通过叙事关键词加的日常分
  int narrativeHouseGainWeekKey; // 记账的游戏周序号，跨周清零

  WorldState({
    this.academicYear = '1991-1992',
    this.term = 'first',
    this.month = '9月',
    this.dayOfMonth = 1,
    this.dayOfWeek = 'Tuesday',
    this.era = 'harry_same',
    List<NarrativeEvent>? recentEvents,
    List<NarrativeEvent>? recentNarrativeEvents,
    this.playerImpactScore = 0.0,
    GameTime? time,
    this.timeFlowMode = 'normal',
    List<String>? specialMarkers,
    this.currentLocation,
    this.currentLocationLabel,
    this.weather,
    this.timelineChanges = 0,
    List<String>? timelineBranches,
    List<Map<String, dynamic>>? timelineSnapshots,
    List<String>? firedAnchorIds,
    Map<String, String>? causalChoices,
    Map<String, int>? monthlyEventFiredAt,
    this.graduated = false,
    Set<String>? visitedLocations,
    List<String>? lastTurnAssertions,
    List<String>? previousTurnAssertions,
    List<Map<String, dynamic>>? consistencyViolations,
    Map<String, String>? lastNarrativeAnchor,
    this.continuityBridgeMisses = 0,
    Map<String, int>? houseCupYearly,
    Map<String, String>? houseCupYearHistory,
    this.narrativeHouseGainDay = 0,
    this.narrativeHouseGainDayKey = 0,
    this.narrativeHouseGainWeek = 0,
    this.narrativeHouseGainWeekKey = 0,
  })  : time = time ?? GameTime(),
        recentEvents = List<NarrativeEvent>.from(recentEvents ?? <NarrativeEvent>[]),
        recentNarrativeEvents = List<NarrativeEvent>.from(recentNarrativeEvents ?? <NarrativeEvent>[]),
        specialMarkers = List<String>.from(specialMarkers ?? const []),
        timelineBranches = List<String>.from(timelineBranches ?? const []),
        timelineSnapshots = List<Map<String, dynamic>>.from(
            timelineSnapshots ?? const []),
        firedAnchorIds = List<String>.from(firedAnchorIds ?? const []),
        causalChoices = Map<String, String>.from(causalChoices ?? const {}),
        monthlyEventFiredAt =
            Map<String, int>.from(monthlyEventFiredAt ?? const {}),
        visitedLocations = Set<String>.from(visitedLocations ?? const {}),
        lastTurnAssertions = List<String>.from(lastTurnAssertions ?? const []),
        previousTurnAssertions = List<String>.from(previousTurnAssertions ?? const []),
        consistencyViolations = List<Map<String, dynamic>>.from(
            consistencyViolations ?? const <Map<String, dynamic>>[]),
        lastNarrativeAnchor = Map<String, String>.from(lastNarrativeAnchor ?? const {}),
        houseCupYearly = Map<String, int>.from(houseCupYearly ?? const {}),
        houseCupYearHistory =
            Map<String, String>.from(houseCupYearHistory ?? const {});

  /// 当前时间戳字符串
  String get timestamp => time.format();
  /// 添加特殊标记
  void addMarker(String marker) {
    if (!specialMarkers.contains(marker)) {
      specialMarkers.add(marker);
    }
  }
  /// 判定是否为系统通知类事件。
  /// 系统通知只用于玩家 UI（notifications），不注入到 AI Prompt 的【世界近期重大事件】锚点，
  /// 防止"好感本周已达上限""记恨在心"这类机械状态刷屏挤占真正的剧情事件槽位（20 条上限）。
  static bool isSystemNotification(String event) {
    const blacklistPrefixes = <String>[
      '📊', // 好感上限/统计类
      '⚠️', // 信任受限/系统警告类
      '💔', // 记恨/背叛记录类
      '🧭', // SceneGraph 内部锚点命中提示（只走 notifications，不进事件记录）
    ];
    const blacklistKeywords = <String>[
      '好感本周已达上限',
      '周好感度已达上限',
      '对你的信任因过去的背叛而受限',
      '因你的行为而记恨在心',
      // ---- 内部 debug 标识（绝不能出现在玩家可见的事件面板里）----
      'SceneGraph:',
      'SceneGraph：',
      'SceneGraph',
      '触发节点',
      'opening_',
      'firedAnchorIds',
      'turn=',
      'loc=',
      // ---- 承接前缀（内部衔接元文本，不能出现在事件记录中）----
      '承接：',
      '承接:',
      '（承接：',
      '承接上回合',
    ];
    if (blacklistPrefixes.any(event.startsWith)) return true;
    if (blacklistKeywords.any(event.contains)) return true;
    return false;
  }

  void addNarrativeEvent(String event, {int? turn}) {
    if (isSystemNotification(event)) return;
    recentNarrativeEvents.insert(0, NarrativeEvent(event, turn: turn));
    if (recentNarrativeEvents.length > 20) {
      recentNarrativeEvents.removeLast();
    }
  }

  /// 记录一条世界线分支，并附上"当时的世界快照"（重演记录侧）。
  ///
  /// [snapshot] 由调用方构造（mixin 里能拿到 player 的变动率等数据），
  /// 传 null 时记一个空快照占位，保证两表下标始终对齐。
  void addTimelineBranch(String description,
      {Map<String, dynamic>? snapshot}) {
    timelineChanges += 1;
    timelineBranches.add(description);
    timelineSnapshots.add(snapshot ?? const {});
    if (timelineBranches.length > 20) {
      timelineBranches.removeAt(0);
      timelineSnapshots.removeAt(0);
    }
  }

  Map<String, dynamic> toJson() => {
        'academic_year': academicYear,
        'term': term,
        'month': month,
        'day_of_month': dayOfMonth,
        'day_of_week': dayOfWeek,
        'era': era,
        'recent_events': recentEvents.map((e) => e.toJson()).toList(),
        'recent_narrative_events': recentNarrativeEvents.map((e) => e.toJson()).toList(),
        'player_impact_score': playerImpactScore,
        'time': time.toJson(),
        'time_flow_mode': timeFlowMode,
        'special_markers': specialMarkers,
        'current_location': currentLocation,
        'current_location_label': currentLocationLabel,
        'weather': weather,
        'timeline_changes': timelineChanges,
        'timeline_branches': timelineBranches,
        'timeline_snapshots': timelineSnapshots,
        'fired_anchor_ids': firedAnchorIds,
        'causal_choices': causalChoices,
        'monthly_event_fired_at': monthlyEventFiredAt,
        'graduated': graduated,
        'visited_locations': visitedLocations.toList(),
        'last_turn_assertions': lastTurnAssertions,
        'previous_turn_assertions': previousTurnAssertions,
        'consistency_violations': consistencyViolations,
        'last_narrative_anchor': lastNarrativeAnchor,
        'continuity_bridge_misses': continuityBridgeMisses,
        'house_cup_yearly': houseCupYearly,
        'house_cup_year_history': houseCupYearHistory,
        'narrative_house_gain_day': narrativeHouseGainDay,
        'narrative_house_gain_day_key': narrativeHouseGainDayKey,
        'narrative_house_gain_week': narrativeHouseGainWeek,
        'narrative_house_gain_week_key': narrativeHouseGainWeekKey,
      };

  factory WorldState.fromJson(Map<String, dynamic> json) {
    // 兼容旧存档：无 time 字段时从旧日期字段推导
    final hasTime = json.containsKey('time') && json['time'] != null;
    GameTime? time;
    if (!hasTime) {
      time = _timeFromLegacy(json);
    }
    return WorldState(
      academicYear: json['academic_year'] ?? '1991-1992',
      term: json['term'] ?? 'first',
      month: json['month'] ?? 'September',
      dayOfMonth: json['day_of_month'] ?? 1,
      dayOfWeek: json['day_of_week'] ?? 'Tuesday',
      era: json['era'] ?? 'harry_same',
      recentEvents: (json['recent_events'] as List<dynamic>? ?? []).map((s) => NarrativeEvent.fromJson(s)).toList(),
      recentNarrativeEvents: (json['recent_narrative_events'] as List<dynamic>? ?? []).map((s) => NarrativeEvent.fromJson(s)).toList(),
      playerImpactScore: (json['player_impact_score'] ?? 0.0).toDouble(),
      time: time ??
          GameTime.fromJson(Map<String, dynamic>.from(json['time'] ?? {})),
      timeFlowMode: json['time_flow_mode'] ?? 'normal',
      specialMarkers: List<String>.from(json['special_markers'] ?? []),
      currentLocation: json['current_location'],
      currentLocationLabel: json['current_location_label'],
      weather: json['weather'],
      timelineChanges: json['timeline_changes'] ?? 0,
      timelineBranches: List<String>.from(json['timeline_branches'] ?? []),
      timelineSnapshots: List<Map<String, dynamic>>.from(
          json['timeline_snapshots'] as List<dynamic>? ?? const []),
      firedAnchorIds: List<String>.from(json['fired_anchor_ids'] ?? []),
      causalChoices: Map<String, String>.from(
          (json['causal_choices'] as Map<String, dynamic>? ?? const {})
              .map((k, v) => MapEntry(k, v.toString()))),
      monthlyEventFiredAt: Map<String, int>.from(
          (json['monthly_event_fired_at'] as Map<String, dynamic>? ?? const {})
              .map((k, v) => MapEntry(k, v is int ? v : int.tryParse('$v') ?? 0))),
      graduated: json['graduated'] ?? false,
      visitedLocations: Set<String>.from(json['visited_locations'] ?? const {}),
      lastTurnAssertions: List<String>.from(json['last_turn_assertions'] ?? const []),
      previousTurnAssertions: List<String>.from(json['previous_turn_assertions'] ?? const []),
      consistencyViolations: (json['consistency_violations'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      lastNarrativeAnchor: Map<String, String>.from(
          (json['last_narrative_anchor'] as Map<String, dynamic>? ?? const {})
              .map((k, v) => MapEntry(k.toString(), v.toString()))),
      continuityBridgeMisses: json['continuity_bridge_misses'] as int? ?? 0,
      houseCupYearly: Map<String, int>.from(
          (json['house_cup_yearly'] as Map<String, dynamic>? ?? const {})
              .map((k, v) => MapEntry(k.toString(), v is int ? v : int.tryParse('$v') ?? 0))),
      houseCupYearHistory: Map<String, String>.from(
          (json['house_cup_year_history'] as Map<String, dynamic>? ?? const {})
              .map((k, v) => MapEntry(k.toString(), v.toString()))),
      narrativeHouseGainDay: json['narrative_house_gain_day'] as int? ?? 0,
      narrativeHouseGainDayKey: json['narrative_house_gain_day_key'] as int? ?? 0,
      narrativeHouseGainWeek: json['narrative_house_gain_week'] as int? ?? 0,
      narrativeHouseGainWeekKey: json['narrative_house_gain_week_key'] as int? ?? 0,
    );
  }

  /// 从旧存档的英文月份与星期推导 GameTime
  static GameTime? _timeFromLegacy(Map<String, dynamic> json) {
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December',
    ];
    final yearStr = json['academic_year'] ?? '';
    final yearMatch = RegExp(r'^(\d{4})').firstMatch(yearStr.toString());
    final year = yearMatch != null ? int.tryParse(yearMatch.group(1)!) : null;
    final month = monthNames.indexOf(json['month'] ?? '') + 1;
    final day = json['day_of_month'] as int? ?? 1;
    final weekday = GameTime.weekdays.indexOf(json['day_of_week'] ?? '');
    if (year == null || month <= 0) return null;
    return GameTime(
      year: year,
      month: month,
      day: day,
      weekday: weekday >= 0 ? weekday : null,
    );
  }
}
