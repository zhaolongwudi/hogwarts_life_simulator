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

  NPC({
    required this.id,
    required this.name,
    this.house = '',
    this.grade = 1,
    this.bloodStatus = 'unknown',
    this.isCanon = false,
    this.isAlive = true,
    this.personality = const [],
    this.currentLocation = 'Hogwarts',
    this.mood = 50,
    this.knowsAbout = const [],
    this.personalGoal,
    this.lifeLog = const [],
    this.relationships = const {},
    this.recentEvents = const [],
  });

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
        currentLocation: json['current_location'] ?? 'Hogwarts',
        mood: json['mood'] ?? 50,
        knowsAbout: List<String>.from(json['knows_about'] ?? []),
        personalGoal: json['personal_goal'],
        lifeLog: List<String>.from(json['life_log'] ?? []),
        relationships: Map<String, int>.from(json['relationships'] ?? {}),
        recentEvents: List<String>.from(json['recent_events'] ?? []),
      );
}
