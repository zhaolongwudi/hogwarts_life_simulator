import 'dart:math';
import 'package:flutter/widgets.dart';
import 'app_provider.dart';
import '../models/player.dart';
import '../models/npc.dart';
import '../models/world_state.dart';
import '../models/game_systems.dart';
import '../models/long_term_memory.dart';
import '../services/save_service.dart';
import '../services/deepseek_service.dart';
import '../services/npc_chat_service.dart';
import '../services/ai_router.dart';
import '../data/cg_data.dart';

/// GameProviderBase: 字段承载抽象基类。
/// 必须放在 `with` 6个Mixin 之前被 6个Mixin 的 `on GameProviderBase` 引用，
/// 从而打破 Dart 3 中 recursive_interface_inheritance 继承环。
abstract class GameProviderBase extends ChangeNotifier {
  // ====== 依赖注入（构造时提供） ======
  AppProvider get appProvider;
  AiRouter? get router;
  set router(AiRouter? v);
  SaveService get saveService;
  Random get random;
  NpcChatService get chatService;

  // ====== 预编译正则（避免循环内重复编译） ======
  static final RegExp reChoiceOption = RegExp(
    r'^\s*(?:[A-Ea-e]|[Ａ-Ｅａ-ｅ]|[\d]{1,2}|[一二三四五六七八九十]{1,3})\s*(?:[\.\．、\)）:：])\s*',
  );
  static final RegExp reMultiNewline = RegExp(r'\n{3,}');
  static final RegExp reAffectionSection = RegExp(r'【好感(?:度)?变化?】[\s\S]*?(?=【|$)');
  static final RegExp reReputationSection = RegExp(r'【声望变化?】[\s\S]*?(?=【|$)');
  static final RegExp reChoiceMultiLine = RegExp(
    r'(?:^|\n)\s*(?:[A-Ea-e]|[Ａ-Ｅａ-ｅ]|[\d]{1,2}|[一二三四五六七八九十]{1,3})\s*(?:[\.\．、\)）:：])\s+\S',
    multiLine: true,
  );

  // ====== 核心状态字段（已从私有 _xxx public 化，Mixin 需要直接访问） ======
  Player? player;
  WorldState worldState = WorldState();
  final Map<String, NPC> npcRegistry = {};
  LongTermMemory memory = LongTermMemory();

  String currentNarrative = '';
  String narrativeSummary = '';
  String pendingSummary = '';
  final List<String> recentTurns = [];
  static const int maxRecentTurns = 12;
  List<GameChoice> choices = [];
  String? commandResult;
  bool isLoading = false;
  bool isInitializing = false;
  String? error;
  int turnCount = 0;
  String lastPlayerAction = '';
  String? systemPrompt;
  String loadingStage = '';
  List<String> lastAffectionSections = [];
  final List<String> notifications = [];

  int totalPromptTokens = 0;
  int totalCompletionTokens = 0;
  int totalTokens = 0;
  int lastRoundTokens = 0;
  int apiCalls = 0;
  int gameWeek = 1;
  int lastSchoolYearStart = 0;
  /// 用于判断跨周：上一状态对应的绝对天数除以 7 的桶编号。
  /// 与 gameWeek 一同在 new game/load game 时初始化，避免开局几天就跨周。
  int lastWeekBucket = 0;
  /// 学年制新NPC上限追踪：当前学年已生成的数量
  int npcGeneratedThisSchoolYear = 0;
  /// 记录 npcGeneratedThisSchoolYear 所属学年的起始年份
  int npcGenerationSchoolYear = 0;
  String? pendingAnchorDirective;
  String openingScene = 'station';
  int? lastScannedNarrativeHash;

  /// 跨 Mixin 共享：从 Player 或 LongTermMemory 的 T0 核心事实解析魔法资质。
  /// 初始化失败/旧存档缺失字段时，用 T0 事实回填，并把值写回 Player。
  String resolveMagicAptitude(Player p) {
    final direct = p.magicAptitude ?? '';
    if (direct.isNotEmpty) return direct;
    for (final fact in memory.keyFacts) {
      if (fact.importance >= 9 &&
          fact.category == 'ability' &&
          fact.id == 'ability:aptitude') {
        final m = RegExp(r'资质为([^，,。\s]+)').firstMatch(fact.fact);
        if (m != null && m.group(1) != null) {
          final value = m.group(1)!;
          p.magicAptitude = value;
          return value;
        }
      }
    }
    return '';
  }

  // ============================================================
  // 跨 Mixin 调用 与 GameProvider 本体方法的 abstract 声明。
  // Dart 3 的 Mixin 静态分析只认识 `on X` 中的 X 类成员，不认识
  // 同一最终类中 `with A, B, C` 的其他 Mixin 的方法，所以这里统一声明。
  // 实现由：GameProvider 本体 / 6 个 Mixin 分别提供 @override。
  // ============================================================
  int acceptJob(String jobId);
  void accumulateForSummary(String newNarrative);
  void advanceTimeForAction(String action);
  void appendRecentTurn(String narrative);
  String attrLabel(String key);
  Future<void> autoSave();
  String bloodStatusLabel(String status);
  String buildRelationshipSnapshot();
  String buildSystemPrompt();
  void bumpImpactScore(double delta, {String? debugReason});
  int calculateAge();
  Future<ChatResult> callDeepSeek(String prompt, {AiScene scene = AiScene.narrative});
  void checkAffectionAchievements(NPC npc);
  void checkAllAchievements();
  Future<bool> checkConnection();
  void checkLocks(NPC npc);
  void checkNPCConfessions();
  void checkSkillAchievements();
  void checkWarHeroAchievement();
  void checkWorldChangerAchievement();
  void classroomInteraction();
  String computeHouseLocal();
  Future<bool> deleteSave(String slotId);
  bool depositToBank(int amount);
  Future<void> doSave({required bool debounce});
  String eraLabel(Era era);
  void fastForwardTime(int days);
  String flowModeLabel(String mode);
  String formatAffections({int maxEntries = 8});
  String formatBloodRelatives();
  String formatBoneMode();
  String formatCollection();
  String formatCourses();
  String formatGoalProgress();
  String formatLove();
  String formatLoveStages();
  String formatLoveWaiting();
  String formatNpcRelationship(String npc1, String npc2);
  String formatRelationships();
  String formatReputation();
  String formatRumors();
  String formatWorldEvolution();
  Future<List<GameChoice>> generateChoicesSeparately(String narrative);
  List<GameChoice> generateContextualFallbackChoices();
  Future<void> generateEnding();
  List<GameChoice> generateFallbackChoices();
  String generateFallbackNarrative();
  void generateNewNPC();
  String generateSortingNarrative(String house);
  void handleLetterCommand(List<String> parts);
  bool handleLocalCommand(String command);
  void incrementWorldLineDeviation(double delta);
  Future<void> initializeGame({    required String name,    required String bloodStatus,    required String birthLocation,    required List<String> personalityTraits,    String? gender,    String? appearance,    String? familyBackground,    List<String>? childhoodExperiences,    String? beliefs,    String? wandId,    String? petName,    String? petId,    String? sexOrientation,    String? birthday,    Map<String, int>? attributes,    Map<String, int>? houseDimensions,    String? initialTalent,    String? magicAptitude,    String? housePreference,    String? politicalTendency,    String? simulationStyle,    String? birthIdentity,    String openingScene = 'station',  });
  bool isNearby(String npcId);
  Future<List<Map<String, dynamic>>> listSaves();
  Future<void> loadFromSave(String slotId);
  void markIntroducedFromNarrative(String text);
  void markNpcIntroduced(NPC npc);
  bool markScanIfNew(String narrative);
  void onApiKeyChange();
  void parseNarrativeOnly(String text);
  void parseResponse(String text);
  Future<void> processChoice(GameChoice choice);
  bool purchaseItem(String itemName, int price, {String type, String description});
  Future<void> quickSave();
  Future<void> saveGameNamed(String slotName);
  void recordRomanticEventFor(NPC npc);
  void refreshClient();
  void resetAllState();
  void resetTokenUsage();
  void resolveConfession(bool accepted, String npcName);
  void setCurrentLocationLabel(String label);
  int roll(int min, int max);
  Future<void> saveNow();
  bool sellItem(int index, int price);
  void syncRelationshipLevel(NPC npc);
  String termLabel(String term);
  void travelTo(String location);
  Future<void> tryAutoLoad();
  void unlockAchievement(String id);
  void unlockCG(CgDef? cg);
  void updateAcademicYearLabel();
  void updatePlayerSignature(String text);
  Future<void> updateApiKey(String key);
  void updateClient();
  void updateNPCsFromAction(String action);
  void updateNpcAffection(String npcId, int change, {String? reason});
  void updatePlayerImpactScore(String action);
  bool withdrawFromBank(int amount);
}
