import 'package:uuid/uuid.dart';
import 'game_systems.dart';

const _uuid = Uuid();

class Player {
  final String id;
  String name;
  final String birthYear;
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

  // ====== 设定文档扩展字段 ======
  int magic; // MP 魔力
  int spirit; // SP 精神力
  int satiety; // 饱食度
  int energy; // 精力值
  final Map<String, int> houseDimensions; // 学院四维: courage/wisdom/loyalty/ambition
  String gender;
  String? birthDay; // 具体生日
  String? sexOrientation;
  String? appearance; // 外貌与体格描述
  String? familyBackground; // 家族与血统
  final List<String> childhoodExperiences; // 童年经历
  String? beliefs; // 信仰与价值观
  String? initialTalent; // 初始天赋专精
  String? magicAptitude; // 魔法资质（第75章）
  String? housePreference; // 学院倾向（第75章）
  String? politicalTendency; // 初始政治倾向（第75章）
  String? simulationStyle; // 模拟风格（第75章）
  String? birthIdentity; // 出生身份（第75章）
  String? petName;
  int petBond; // 宠物羁绊
  LoveState loveState; // 恋爱状态
  Reputation playerReputation; // 玩家声望
  int houseReputation; // 学院声望
  int wizardingReputation; // 魔法界声望
  int factionReputation; // 阵营声望
  final List<String> collection; // 收藏品
  final Map<String, CgRecord> cgRecords; // 已解锁CG
  final List<String> achievements; // 已解锁成就
  bool boneMode; // 骨科模式
  final List<String> bloodRelatives; // 血缘亲属NPC名
  final List<Letter> letters; // 信件
  final List<String> rumors; // 舆论传闻

  Player({
    String? id,
    required this.name,
    required this.birthYear,
    required this.bloodType,
    required this.birthLocation,
    List<String>? personalityTraits,
    Map<String, int>? attributes,
    Map<String, SpellLevel>? learnedSpells,
    List<InventoryItem>? inventory,
    Map<String, Relationship>? relationships,
    this.currentGoal,
    this.worldLineDeviation = 0.0,
    this.health = 100,
    List<String>? injuries,
    this.wandId,
    this.petId,
    this.house,
    this.grade,
    this.magic = 100,
    this.spirit = 100,
    this.satiety = 100,
    this.energy = 100,
    Map<String, int>? houseDimensions,
    this.gender = '',
    this.birthDay,
    this.sexOrientation,
    this.appearance,
    this.familyBackground,
    List<String>? childhoodExperiences,
    this.beliefs,
    this.initialTalent,
    this.magicAptitude,
    this.housePreference,
    this.politicalTendency,
    this.simulationStyle,
    this.birthIdentity,
    this.petName,
    this.petBond = 0,
    LoveState? loveState,
    Reputation? playerReputation,
    this.houseReputation = 0,
    this.wizardingReputation = 0,
    this.factionReputation = 0,
    List<String>? collection,
    Map<String, CgRecord>? cgRecords,
    List<String>? achievements,
    this.boneMode = false,
    List<String>? bloodRelatives,
    List<Letter>? letters,
    List<String>? rumors,
  })  : id = id ?? _uuid.v4(),
        personalityTraits = List<String>.from(personalityTraits ?? const []),
        attributes = Map<String, int>.from(attributes ?? _defaultAttributes),
        learnedSpells = Map<String, SpellLevel>.from(learnedSpells ?? const {}),
        inventory = List<InventoryItem>.from(inventory ?? const []),
        relationships = Map<String, Relationship>.from(relationships ?? const {}),
        injuries = List<String>.from(injuries ?? const []),
        childhoodExperiences = List<String>.from(childhoodExperiences ?? const []),
        houseDimensions = Map<String, int>.from(houseDimensions ?? _defaultHouseDimensions),
        loveState = loveState ?? LoveState(),
        playerReputation = playerReputation ?? Reputation(),
        collection = List<String>.from(collection ?? const []),
        cgRecords = Map<String, CgRecord>.from(cgRecords ?? const {}),
        achievements = List<String>.from(achievements ?? const []),
        bloodRelatives = List<String>.from(bloodRelatives ?? const []),
        letters = List<Letter>.from(letters ?? const []),
        rumors = List<String>.from(rumors ?? const []);

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
    'logic': 50,
    'intuition': 50,
  };

  /// 学院四维：勇气/智慧/忠诚/野心
  static const Map<String, int> _defaultHouseDimensions = {
    'courage': 50,
    'wisdom': 50,
    'loyalty': 50,
    'ambition': 50,
  };

  /// 从学院四维计算分院的倾向
  String get recommendedHouse {
    final scores = {
      'Gryffindor': houseDimensions['courage'] ?? 50,
      'Ravenclaw': houseDimensions['wisdom'] ?? 50,
      'Hufflepuff': houseDimensions['loyalty'] ?? 50,
      'Slytherin': houseDimensions['ambition'] ?? 50,
    };
    return scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

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
        'magic': magic,
        'spirit': spirit,
        'satiety': satiety,
        'energy': energy,
        'house_dimensions': houseDimensions,
        'gender': gender,
        'birth_day': birthDay,
        'sex_orientation': sexOrientation,
        'appearance': appearance,
        'family_background': familyBackground,
        'childhood_experiences': childhoodExperiences,
        'beliefs': beliefs,
        'initial_talent': initialTalent,
        'pet_name': petName,
        'pet_bond': petBond,
        'love_state': loveState.toJson(),
        'player_reputation': playerReputation.toJson(),
        'house_reputation': houseReputation,
        'wizarding_reputation': wizardingReputation,
        'faction_reputation': factionReputation,
        'collection': collection,
        'cg_records': cgRecords.map((k, v) => MapEntry(k, v.toJson())),
        'achievements': achievements,
        'bone_mode': boneMode,
        'blood_relatives': bloodRelatives,
        'letters': letters.map((e) => e.toJson()).toList(),
        'rumors': rumors,
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
        magic: json['magic'] ?? 100,
        spirit: json['spirit'] ?? 100,
        satiety: json['satiety'] ?? 100,
        energy: json['energy'] ?? 100,
        houseDimensions:
            Map<String, int>.from(json['house_dimensions'] ?? _defaultHouseDimensions),
        gender: json['gender'] ?? '',
        birthDay: json['birth_day'],
        sexOrientation: json['sex_orientation'],
        appearance: json['appearance'],
        familyBackground: json['family_background'],
        childhoodExperiences:
            List<String>.from(json['childhood_experiences'] ?? []),
        beliefs: json['beliefs'],
        initialTalent: json['initial_talent'],
        petName: json['pet_name'],
        petBond: json['pet_bond'] ?? 0,
        loveState: LoveState.fromJson(
            Map<String, dynamic>.from(json['love_state'] ?? {})),
        playerReputation: Reputation.fromJson(
            Map<String, dynamic>.from(json['player_reputation'] ?? {})),
        houseReputation: json['house_reputation'] ?? 0,
        wizardingReputation: json['wizarding_reputation'] ?? 0,
        factionReputation: json['faction_reputation'] ?? 0,
        collection: List<String>.from(json['collection'] ?? []),
        cgRecords: (json['cg_records'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, CgRecord.fromJson(v))) ??
            {},
        achievements: List<String>.from(json['achievements'] ?? []),
        boneMode: json['bone_mode'] ?? false,
        bloodRelatives: List<String>.from(json['blood_relatives'] ?? []),
        letters: (json['letters'] as List<dynamic>?)
                ?.map((e) => Letter.fromJson(e))
                .toList() ??
            [],
        rumors: List<String>.from(json['rumors'] ?? []),
      );
}

/// CG 记录
class CgRecord {
  final String cgId;
  final String name;
  final String unlockedDate;
  final String chapter;

  const CgRecord({
    required this.cgId,
    required this.name,
    required this.unlockedDate,
    this.chapter = '',
  });

  Map<String, dynamic> toJson() => {
        'cg_id': cgId,
        'name': name,
        'unlocked_date': unlockedDate,
        'chapter': chapter,
      };

  factory CgRecord.fromJson(Map<String, dynamic> json) => CgRecord(
        cgId: json['cg_id'],
        name: json['name'],
        unlockedDate: json['unlocked_date'],
        chapter: json['chapter'] ?? '',
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
    List<String>? history,
  }) : history = List<String>.from(history ?? const []);

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
