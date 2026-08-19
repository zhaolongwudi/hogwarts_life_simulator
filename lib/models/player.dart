import 'package:uuid/uuid.dart';

final _uuid = const Uuid();

class Player {
  final String id;
  String name;
  final String birthYear;
  static const String bloodStatus = ''; // 会在初始化时设置
  final String bloodType; // pureblood, halfblood, muggleborn, special
  final String birthLocation;
  final List<String> personalityTraits;
  final Map<String, int> attributes;
  final Map<String, SpellLevel> learnedSpells;
  final List<InventoryItem> inventory;
  final Map<String, Relationship> relationships;
  String? currentGoal;
  double worldLineDeviation;
  int health;
  final List<String> injuries;
  String? wandId;
  String? petId;
  String? house;
  int? grade;

  Player({
    String? id,
    required this.name,
    required this.birthYear,
    required this.bloodType,
    required this.birthLocation,
    this.personalityTraits = const [],
    Map<String, int>? attributes,
    Map<String, SpellLevel>? learnedSpells,
    this.inventory = const [],
    this.relationships = const {},
    this.currentGoal,
    this.worldLineDeviation = 0.0,
    this.health = 100,
    this.injuries = const [],
    this.wandId,
    this.petId,
    this.house,
    this.grade,
  })  : id = id ?? _uuid.v4(),
        attributes = attributes ?? _defaultAttributes,
        learnedSpells = learnedSpells ?? {};

  static const Map<String, int> _defaultAttributes = {
    'spell_understanding': 50,
    'transfiguration': 50,
    'potions': 50,
    'herbology': 50,
    'dda': 50,
    'flying': 50,
    'theory': 50,
    'memory': 50,
    'observation': 50,
    'magic_control': 50,
    'reaction_time': 50,
    'emotional_stability': 50,
    'creativity': 50,
    'social': 50,
    'courage': 50,
    'caution': 50,
    'willpower': 50,
  };

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'birth_year': birthYear,
        'blood_status': bloodType,
        'birth_location': birthLocation,
        'personality_traits': personalityTraits,
        'attributes': attributes,
        'learned_spells': learnedSpells.map((k, v) => MapEntry(k, v.toJson())),
        'inventory': inventory.map((e) => e.toJson()).toList(),
        'relationships': relationships.map((k, v) => MapEntry(k, v.toJson())),
        'current_goal': currentGoal,
        'world_line_deviation': worldLineDeviation,
        'health': health,
        'injuries': injuries,
        'wand_id': wandId,
        'pet_id': petId,
        'house': house,
        'grade': grade,
      };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'],
        name: json['name'],
        birthYear: json['birth_year'],
        bloodType: json['blood_status'] ?? '',
        birthLocation: json['birth_location'],
        personalityTraits: List<String>.from(json['personality_traits'] ?? []),
        attributes: Map<String, int>.from(json['attributes'] ?? _defaultAttributes),
        learnedSpells: (json['learned_spells'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, SpellLevel.fromJson(v))) ??
            {},
        inventory: (json['inventory'] as List<dynamic>?)
                ?.map((e) => InventoryItem.fromJson(e))
                .toList() ??
            [],
        relationships: (json['relationships'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, Relationship.fromJson(v))) ??
            {},
        currentGoal: json['current_goal'],
        worldLineDeviation: (json['world_line_deviation'] ?? 0.0).toDouble(),
        health: json['health'] ?? 100,
        injuries: List<String>.from(json['injuries'] ?? []),
        wandId: json['wand_id'],
        petId: json['pet_id'],
        house: json['house'],
        grade: json['grade'],
      );
}

class SpellLevel {
  final String spellName;
  final int level;
  final int practiceCount;

  SpellLevel({required this.spellName, this.level = 0, this.practiceCount = 0});

  Map<String, dynamic> toJson() => {
        'spell_name': spellName,
        'level': level,
        'practice_count': practiceCount,
      };

  factory SpellLevel.fromJson(Map<String, dynamic> json) => SpellLevel(
        spellName: json['spell_name'],
        level: json['level'] ?? 0,
        practiceCount: json['practice_count'] ?? 0,
      );
}

class InventoryItem {
  final String id;
  final String name;
  final String description;
  final String type;

  InventoryItem({
    required this.id,
    required this.name,
    this.description = '',
    this.type = 'item',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'type': type,
      };

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: json['id'],
        name: json['name'],
        description: json['description'] ?? '',
        type: json['type'] ?? 'item',
      );
}

class Relationship {
  final String targetId;
  final String targetName;
  String relationType;
  int level;
  final List<String> history;

  Relationship({
    required this.targetId,
    required this.targetName,
    this.relationType = 'acquaintance',
    this.level = 10,
    this.history = const [],
  });

  Map<String, dynamic> toJson() => {
        'target_id': targetId,
        'target_name': targetName,
        'relation_type': relationType,
        'level': level,
        'history': history,
      };

  factory Relationship.fromJson(Map<String, dynamic> json) => Relationship(
        targetId: json['target_id'],
        targetName: json['target_name'],
        relationType: json['relation_type'] ?? 'acquaintance',
        level: json['level'] ?? 10,
        history: List<String>.from(json['history'] ?? []),
      );
}
