import 'game_systems.dart';
import '../data/balance_constants.dart';

class NPC {
  final String id;
  final String name;
  String house;
  int grade;
  final String bloodStatus;
  final bool isCanon;
  bool isAlive;
  final List<String> personality;
  String currentLocation;
  int mood;
  final List<String> knowsAbout;
  String? personalGoal;
  final List<String> lifeLog;
  final Map<String, int> relationships;
  final List<String> recentEvents;

  // ====== 设定文档扩展字段 ======
  final String appearance; // 电影形象外貌描述
  final String? sexOrientation; // 性取向
  int affection; // 对玩家的好感度 -100 ~ +100
  final List<String> affectionLocks; // 已解锁的好感锁
  final Map<String, int> giftPrefs; // 礼物偏好: 名称 -> 分值
  final Map<String, String> schedule; // 日程: 时段 -> 活动
  Reputation reputation; // 声望档案
  bool isConsideringConfession; // 是否正在考虑表白
  bool confessed; // 是否已表白
  final bool isGenerated; // 是否为动态生成的新NPC
  String? generatedProfile; // 新NPC完整档案文本

  // ====== 融合版：好感沉淀与记仇机制 ======
  int maxAffectionReached; // 历史最高好感（背叛后不可超越此值）
  final List<Map<String, dynamic>> grudges; // 记仇记录：类型+原因+时间
  int affectionGainedThisWeek; // 本周好感增量（第一周上限+30）
  int affectionGainedThisMonth; // 本月好感增量（第一个月上限+50）
  int lastGrudgeDay; // 上次记仇的游戏日
  bool introduced; // 是否已经在剧情中登场/被玩家认识

  NPC({
    required this.id,
    required this.name,
    this.house = '',
    this.grade = 1,
    this.bloodStatus = 'unknown',
    this.isCanon = false,
    this.isAlive = true,
    this.personality = const [],
    this.currentLocation = '霍格沃茨',
    this.mood = 50,
    this.knowsAbout = const [],
    this.personalGoal,
    this.lifeLog = const [],
    this.relationships = const {},
    List<String>? recentEvents,
    this.appearance = '',
    this.sexOrientation,
    this.affection = 0,
    List<String>? affectionLocks,
    this.giftPrefs = const {},
    this.schedule = const {},
    Reputation? reputation,
    this.isConsideringConfession = false,
    this.confessed = false,
    this.isGenerated = false,
    this.generatedProfile,
    this.maxAffectionReached = 0,
    List<Map<String, dynamic>>? grudges,
    this.affectionGainedThisWeek = 0,
    this.affectionGainedThisMonth = 0,
    this.lastGrudgeDay = -1,
    this.introduced = false,
  })  : reputation = reputation ?? Reputation(),
        recentEvents = List<String>.from(recentEvents ?? const []),
        affectionLocks = List<String>.from(affectionLocks ?? const []),
        grudges = List<Map<String, dynamic>>.from(
            grudges ?? const <Map<String, dynamic>>[]);

  String get affectionStage => affectionStageFor(affection);

  /// 查询好感锁是否解锁
  bool hasLock(String lockName) => affectionLocks.contains(lockName);

  /// 是否有记仇（好感不可恢复到背叛前水平）
  bool get hasGrudge => grudges.isNotEmpty;

  /// 获取有效好感上限（背叛后不可超越历史最高）
  int get effectiveAffectionCap {
    if (!hasGrudge) return 100;
    return maxAffectionReached > 0 ? maxAffectionReached : 0;
  }

  /// 添加记仇记录
  void addGrudge(String type, String reason, int day) {
    grudges.add({
      'type': type,
      'reason': reason,
      'day': day,
      'affection_at_time': affection,
    });
    lastGrudgeDay = day;
  }

  /// 获取好感沉淀修正值
  int getAffectionGainLimit(int currentDay, int gameWeek) {
    if (gameWeek <= 1) {
      final remaining = Balance.weekOneAffectionCap - affectionGainedThisWeek;
      return remaining > 0 ? remaining : 0;
    }
    return Balance.affectionMax;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'house': house,
        'grade': grade,
        'blood_status': bloodStatus,
        'is_canon': isCanon,
        'is_alive': isAlive,
        'personality': personality,
        'current_location': currentLocation,
        'mood': mood,
        'knows_about': knowsAbout,
        'personal_goal': personalGoal,
        'life_log': lifeLog,
        'relationships': relationships,
        'recent_events': recentEvents,
        'appearance': appearance,
        'sex_orientation': sexOrientation,
        'affection': affection,
        'affection_locks': affectionLocks,
        'gift_prefs': giftPrefs,
        'schedule': schedule,
        'reputation': reputation.toJson(),
        'is_considering_confession': isConsideringConfession,
        'confessed': confessed,
        'is_generated': isGenerated,
        'generated_profile': generatedProfile,
        'max_affection_reached': maxAffectionReached,
        'grudges': grudges,
        'affection_gained_this_week': affectionGainedThisWeek,
        'affection_gained_this_month': affectionGainedThisMonth,
        'last_grudge_day': lastGrudgeDay,
        'introduced': introduced,
      };

  factory NPC.fromJson(Map<String, dynamic> json) => NPC(
        id: json['id'],
        name: json['name'],
        house: json['house'] ?? '',
        grade: json['grade'] ?? 1,
        bloodStatus: json['blood_status'] ?? 'unknown',
        isCanon: json['is_canon'] ?? false,
        isAlive: json['is_alive'] ?? true,
        personality: List<String>.from(json['personality'] ?? []),
        currentLocation: json['current_location'] ?? '霍格沃茨',
        mood: json['mood'] ?? 50,
        knowsAbout: List<String>.from(json['knows_about'] ?? []),
        personalGoal: json['personal_goal'],
        lifeLog: List<String>.from(json['life_log'] ?? []),
        relationships: Map<String, int>.from(json['relationships'] ?? {}),
        recentEvents: List<String>.from(json['recent_events'] ?? []),
        appearance: json['appearance'] ?? '',
        sexOrientation: json['sex_orientation'],
        affection: json['affection'] ?? 0,
        affectionLocks: List<String>.from(json['affection_locks'] ?? []),
        giftPrefs: Map<String, int>.from(json['gift_prefs'] ?? {}),
        schedule: Map<String, String>.from(json['schedule'] ?? {}),
        reputation: Reputation.fromJson(
            Map<String, dynamic>.from(json['reputation'] ?? {})),
        isConsideringConfession: json['is_considering_confession'] ?? false,
        confessed: json['confessed'] ?? false,
        isGenerated: json['is_generated'] ?? false,
        generatedProfile: json['generated_profile'],
        maxAffectionReached: json['max_affection_reached'] ?? 0,
        grudges: List<Map<String, dynamic>>.from(
            (json['grudges'] as List<dynamic>? ?? []).map(
              (e) => Map<String, dynamic>.from(e as Map),
            ),
          ),
        affectionGainedThisWeek: json['affection_gained_this_week'] ?? 0,
        affectionGainedThisMonth: json['affection_gained_this_month'] ?? 0,
        lastGrudgeDay: json['last_grudge_day'] ?? -1,
        introduced: json['introduced'] ?? false,
      );
}
