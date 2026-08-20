import 'game_systems.dart';

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
    this.recentEvents = const [],
    this.appearance = '',
    this.sexOrientation,
    this.affection = 0,
    this.affectionLocks = const [],
    this.giftPrefs = const {},
    this.schedule = const {},
    Reputation? reputation,
    this.isConsideringConfession = false,
    this.confessed = false,
    this.isGenerated = false,
    this.generatedProfile,
  }) : reputation = reputation ?? Reputation();

  String get affectionStage => affectionStageFor(affection);

  /// 查询好感锁是否解锁
  bool hasLock(String lockName) => affectionLocks.contains(lockName);

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
      );
}
