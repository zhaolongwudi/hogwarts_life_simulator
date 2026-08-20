import 'game_systems.dart';

class WorldState {
  String academicYear;
  String term;
  String month; // 兼容旧存档（英文月份名）
  int dayOfMonth;
  String dayOfWeek; // 兼容旧存档
  String era;
  Map<String, int> housePoints;
  List<String> recentEvents;
  double playerImpactScore;

  // ====== 设定文档扩展字段 ======
  GameTime time; // 完整时间系统
  String timeFlowMode; // 时间流速: normal/story/fast
  final List<String> specialMarkers; // 特殊标记: ⏳命运时刻/🌙满月/📜考试周/🎄圣诞/⚡事件触发
  String? currentLocation;
  String? weather;
  int timelineChanges; // 世界线变动次数
  final List<String> timelineBranches; // 已分叉的世界线描述

  WorldState({
    this.academicYear = '1991-1992',
    this.term = 'first',
    this.month = 'September',
    this.dayOfMonth = 1,
    this.dayOfWeek = 'Tuesday',
    this.era = 'harry_same',
    this.housePoints = const {
      'Gryffindor': 350,
      'Slytherin': 350,
      'Ravenclaw': 350,
      'Hufflepuff': 350,
    },
    this.recentEvents = const [],
    this.playerImpactScore = 0.0,
    GameTime? time,
    this.timeFlowMode = 'normal',
    this.specialMarkers = const [],
    this.currentLocation,
    this.weather,
    this.timelineChanges = 0,
    this.timelineBranches = const [],
  }) : time = time ?? GameTime();

  /// 当前时间戳字符串
  String get timestamp => time.format();

  /// 特殊标记列表文本
  String get markersText {
    if (specialMarkers.isEmpty) return '';
    return ' ⚡标记: ${specialMarkers.join(' ')}';
  }

  /// 添加特殊标记
  void addMarker(String marker) {
    if (!specialMarkers.contains(marker)) {
      specialMarkers.add(marker);
    }
  }

  void removeMarker(String marker) {
    specialMarkers.remove(marker);
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
        'recent_events': recentEvents,
        'player_impact_score': playerImpactScore,
        'time': time.toJson(),
        'time_flow_mode': timeFlowMode,
        'special_markers': specialMarkers,
        'current_location': currentLocation,
        'weather': weather,
        'timeline_changes': timelineChanges,
        'timeline_branches': timelineBranches,
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
      recentEvents: List<String>.from(json['recent_events'] ?? []),
      playerImpactScore: (json['player_impact_score'] ?? 0.0).toDouble(),
      time: time ??
          GameTime.fromJson(Map<String, dynamic>.from(json['time'] ?? {})),
      timeFlowMode: json['time_flow_mode'] ?? 'normal',
      specialMarkers: List<String>.from(json['special_markers'] ?? []),
      currentLocation: json['current_location'],
      weather: json['weather'],
      timelineChanges: json['timeline_changes'] ?? 0,
      timelineBranches: List<String>.from(json['timeline_branches'] ?? []),
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
