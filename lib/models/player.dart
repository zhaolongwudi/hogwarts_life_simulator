import 'package:uuid/uuid.dart';
import 'game_systems.dart';
import '../data/quest_data.dart';

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
  String signature; // 个性签名（可编辑，展示于通讯/地图等界面）
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
  // 说明：wizardingReputation / factionReputation 原本是独立 int 字段，
  // 但全项目没有任何写入点 → 永远显示 0，与六维声望系统完全脱节。
  // 现已改为由 playerReputation 派生的 getter（见下方），保证显示真实值。

  /// 魔法界声望（派生）：五维正向声望的均值（0~100）。
  /// 黑魔法声望不计入——它在巫师界是贬义，混入均值会让"恶名"变"美名"。
  int get wizardingReputation {
    final r = playerReputation;
    return ((r.academic + r.social + r.combat + r.moral + r.leadership) / 5)
        .round()
        .clamp(0, 100);
  }

  /// 阵营声望（派生）：黑魔法声望 − 道德声望，范围 −100~100。
  /// 正值＝在黑暗阵营那边有口碑，负值＝在凤凰社一方有口碑。
  int get factionReputation =>
      (playerReputation.dark - playerReputation.moral).clamp(-100, 100);
  final List<String> collection; // 收藏品
  final Map<String, CgRecord> cgRecords; // 已解锁CG
  final List<String> achievements; // 已解锁成就
  bool boneMode; // 骨科模式
  int galleons; // 加隆余额（魔法货币）
  int bankGalleons; // 古灵阁存储
  final List<String> jobHistory; // 打工历史
  final List<String> bloodRelatives; // 血缘亲属NPC名
  final List<Letter> letters; // 信件
  final List<String> rumors; // 舆论传闻
  final List<String> traits; // 开局特质 id 列表

  // ====== 新玩法扩展字段（v1.10） ======
  final Map<String, String> equipped; // 装备槽 → 物品名（robe/hat/broom/amulet）
  final List<String> bestiary; // 已发现生物 id
  final List<QuestRecord> quests; // 已接取委托
  int houseCupPoints; // 本学年学院杯积分（玩家贡献）
  int petLastFedDay; // 上次喂食绝对天数（每日限1次）
  int petInteractDay; // 上次玩耍/训练绝对天数
  bool petTransformDone; // 化人形事件是否已触发
  int qSkill; // 魁地奇技巧（50起步）
  String qPosition; // 位置：找球手/追球手/守门员/击球手
  int qMatches; // 参赛场次
  int qWins; // 获胜场次
  int qLastWeek; // 本周是否已比赛（周数去重）

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
    this.signature = '',
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
    List<String>? collection,
    Map<String, CgRecord>? cgRecords,
    List<String>? achievements,
    this.boneMode = false,
    this.galleons = 500,
    this.bankGalleons = 0,
    List<String>? jobHistory,
    List<String>? bloodRelatives,
    List<Letter>? letters,
    List<String>? rumors,
    List<String>? traits,
    Map<String, String>? equipped,
    List<String>? bestiary,
    List<QuestRecord>? quests,
    this.houseCupPoints = 0,
    this.petLastFedDay = -1,
    this.petInteractDay = -1,
    this.petTransformDone = false,
    this.qSkill = 50,
    this.qPosition = '找球手',
    this.qMatches = 0,
    this.qWins = 0,
    this.qLastWeek = 0,
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
        rumors = List<String>.from(rumors ?? const []),
        traits = List<String>.from(traits ?? const []),
        jobHistory = List<String>.from(jobHistory ?? const []),
        equipped = Map<String, String>.from(equipped ?? const {}),
        bestiary = List<String>.from(bestiary ?? const []),
        quests = List<QuestRecord>.from(quests ?? const []);

  /// 是否为合法属性键。
  ///
  /// 物品/奖励的 effect map 里会混进控制标记（如 `learn_spell` 学咒、
  /// `special` 随机口味），它们不是属性，绝不能写进 attributes。
  static bool isAttributeKey(String key) => _defaultAttributes.containsKey(key);

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
        'signature': signature,
        'birth_day': birthDay,
        'sex_orientation': sexOrientation,
        'appearance': appearance,
        'family_background': familyBackground,
        'childhood_experiences': childhoodExperiences,
        'beliefs': beliefs,
        'initial_talent': initialTalent,
        'magic_aptitude': magicAptitude,
        'house_preference': housePreference,
        'simulation_style': simulationStyle,
        'birth_identity': birthIdentity,
        'pet_name': petName,
        'pet_bond': petBond,
        'love_state': loveState.toJson(),
        'player_reputation': playerReputation.toJson(),
        'house_reputation': houseReputation,
        'collection': collection,
        'cg_records': cgRecords.map((k, v) => MapEntry(k, v.toJson())),
        'achievements': achievements,
        'bone_mode': boneMode,
        'galleons': galleons,
        'bank_galleons': bankGalleons,
        'job_history': jobHistory,
        'blood_relatives': bloodRelatives,
        'letters': letters.map((e) => e.toJson()).toList(),
        'rumors': rumors,
        'traits': traits,
        'political_tendency': politicalTendency,
        'equipped': equipped,
        'bestiary': bestiary,
        'quests': quests.map((e) => e.toJson()).toList(),
        'house_cup_points': houseCupPoints,
        'pet_last_fed_day': petLastFedDay,
        'pet_interact_day': petInteractDay,
        'pet_transform_done': petTransformDone,
        'q_skill': qSkill,
        'q_position': qPosition,
        'q_matches': qMatches,
        'q_wins': qWins,
        'q_last_week': qLastWeek,
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
        signature: json['signature'] ?? '',
        birthDay: json['birth_day'],
        sexOrientation: json['sex_orientation'],
        appearance: json['appearance'],
        familyBackground: json['family_background'],
        childhoodExperiences:
            List<String>.from(json['childhood_experiences'] ?? []),
        beliefs: json['beliefs'],
        initialTalent: json['initial_talent'],
        magicAptitude: json['magic_aptitude'],
        housePreference: json['house_preference'],
        simulationStyle: json['simulation_style'],
        birthIdentity: json['birth_identity'],
        petName: json['pet_name'],
        petBond: json['pet_bond'] ?? 0,
        loveState: LoveState.fromJson(
            Map<String, dynamic>.from(json['love_state'] ?? {})),
        playerReputation: Reputation.fromJson(
            Map<String, dynamic>.from(json['player_reputation'] ?? {})),
        houseReputation: json['house_reputation'] ?? 0,
        collection: List<String>.from(json['collection'] ?? []),
        cgRecords: (json['cg_records'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, CgRecord.fromJson(v))) ??
            {},
        achievements: List<String>.from(json['achievements'] ?? []),
        boneMode: json['bone_mode'] ?? false,
        galleons: json['galleons'] ?? 500,
        bankGalleons: json['bank_galleons'] ?? 0,
        jobHistory: List<String>.from(json['job_history'] ?? []),
        bloodRelatives: List<String>.from(json['blood_relatives'] ?? []),
        letters: (json['letters'] as List<dynamic>?)
                ?.map((e) => Letter.fromJson(e))
                .toList() ??
            [],
        rumors: List<String>.from(json['rumors'] ?? []),
        traits: List<String>.from(json['traits'] ?? []),
        politicalTendency: json['political_tendency'] ?? json['politicalTendency'],
        equipped: Map<String, String>.from(json['equipped'] ?? {}),
        bestiary: List<String>.from(json['bestiary'] ?? []),
        quests: (json['quests'] as List<dynamic>?)
                ?.map((e) => QuestRecord.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        houseCupPoints: json['house_cup_points'] ?? 0,
        petLastFedDay: json['pet_last_fed_day'] ?? -1,
        petInteractDay: json['pet_interact_day'] ?? -1,
        petTransformDone: json['pet_transform_done'] ?? false,
        qSkill: json['q_skill'] ?? 50,
        qPosition: json['q_position'] ?? '找球手',
        qMatches: json['q_matches'] ?? 0,
        qWins: json['q_wins'] ?? 0,
        qLastWeek: json['q_last_week'] ?? 0,
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
