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
  Map<String, int> housePoints;
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

  // ====== 学年系统扩展字段 ======
  final List<String> firedAnchorIds; // 已触发的事件锚点（防重复）
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

  WorldState({
    this.academicYear = '1991-1992',
    this.term = 'first',
    this.month = '9月',
    this.dayOfMonth = 1,
    this.dayOfWeek = 'Tuesday',
    this.era = 'harry_same',
    Map<String, int>? housePoints,
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
    List<String>? firedAnchorIds,
    this.graduated = false,
    Set<String>? visitedLocations,
    List<String>? lastTurnAssertions,
    List<String>? previousTurnAssertions,
    List<Map<String, dynamic>>? consistencyViolations,
    Map<String, String>? lastNarrativeAnchor,
    this.continuityBridgeMisses = 0,
  })  : time = time ?? GameTime(),
        housePoints = Map<String, int>.from(housePoints ?? const {
          'Gryffindor': 350,
          'Slytherin': 350,
          'Ravenclaw': 350,
          'Hufflepuff': 350,
        }),
        recentEvents = List<NarrativeEvent>.from(recentEvents ?? <NarrativeEvent>[]),
        recentNarrativeEvents = List<NarrativeEvent>.from(recentNarrativeEvents ?? <NarrativeEvent>[]),
        specialMarkers = List<String>.from(specialMarkers ?? const []),
        timelineBranches = List<String>.from(timelineBranches ?? const []),
        firedAnchorIds = List<String>.from(firedAnchorIds ?? const []),
        visitedLocations = Set<String>.from(visitedLocations ?? const {}),
        lastTurnAssertions = List<String>.from(lastTurnAssertions ?? const []),
        previousTurnAssertions = List<String>.from(previousTurnAssertions ?? const []),
        consistencyViolations = List<Map<String, dynamic>>.from(
            consistencyViolations ?? const <Map<String, dynamic>>[]),
        lastNarrativeAnchor = Map<String, String>.from(lastNarrativeAnchor ?? const {});

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

  /// 记录一条世界线分支
  void addTimelineBranch(String description) {
    timelineChanges += 1;
    timelineBranches.add(description);
    if (timelineBranches.length > 20) {
      timelineBranches.removeAt(0);
    }
  }

  Map<String, dynamic> toJson() => {
        'academic_year': academicYear,
        'term': term,
        'month': month,
        'day_of_month': dayOfMonth,
        'day_of_week': dayOfWeek,
        'era': era,
        'house_points': housePoints,
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
        'fired_anchor_ids': firedAnchorIds,
        'graduated': graduated,
        'visited_locations': visitedLocations.toList(),
        'last_turn_assertions': lastTurnAssertions,
        'previous_turn_assertions': previousTurnAssertions,
        'consistency_violations': consistencyViolations,
        'last_narrative_anchor': lastNarrativeAnchor,
        'continuity_bridge_misses': continuityBridgeMisses,
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
      housePoints: Map<String, int>.from(json['house_points'] ?? {}),
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
      firedAnchorIds: List<String>.from(json['fired_anchor_ids'] ?? []),
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
