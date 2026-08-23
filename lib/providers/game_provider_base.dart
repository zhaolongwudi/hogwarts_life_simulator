import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'app_provider.dart';
import '../models/player.dart';
import '../models/npc.dart';
import '../models/world_state.dart';
import '../models/game_systems.dart';
import '../models/long_term_memory.dart';
import '../services/save_service.dart';
import '../services/npc_chat_service.dart';
import '../services/ai_router.dart';

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
  String? pendingAnchorDirective;
  String openingScene = 'station';

  // ============================================================
  // 跨 Mixin 调用 与 GameProvider 本体方法的 abstract 声明。
  // Dart 3 的 Mixin 静态分析只认识 `on X` 中的 X 类成员，不认识
  // 同一最终类中 `with A, B, C` 的其他 Mixin 的方法，所以这里统一声明。
  // 实现由：GameProvider 本体 / 6 个 Mixin 分别提供 @override。
  // ============================================================
  abstract String _formatTime();
  abstract int acceptJob(String jobId);
  abstract void accumulateForSummary(String newNarrative);
  abstract void advanceTimeForAction(String action);
  abstract void appendRecentTurn(String narrative);
  abstract String attrLabel(String key);
  abstract Future<void> autoSave();
  abstract String bloodStatusLabel(String status);
  abstract String buildPrompt();
  abstract String buildRelationshipSnapshot();
  abstract String buildSystemPrompt();
  abstract void bumpImpactScore(double delta, {String? debugReason});
  abstract int calculateAge();
  abstract Future<ChatResult> callDeepSeek(String prompt, {AiScene scene = AiScene.narrative});
  abstract void checkAffectionAchievements(NPC npc);
  abstract void checkAllAchievements();
  abstract Future<bool> checkConnection();
  abstract void checkLocks(NPC npc);
  abstract void checkNPCConfessions();
  abstract void checkSkillAchievements();
  abstract void checkWarHeroAchievement();
  abstract void checkWorldChangerAchievement();
  abstract void classroomInteraction();
  abstract String computeHouseLocal();
  abstract Future<bool> deleteSave(String slotId);
  abstract bool depositToBank(int amount);
  abstract void dispose();
  abstract Future<void> doSave({required bool debounce});
  abstract String eraLabel(Era era);
  abstract void fastForwardTime(int days);
  abstract String flowModeLabel(String mode);
  abstract String formatAffections({int maxEntries = 8});
  abstract String formatBloodRelatives();
  abstract String formatBoneMode();
  abstract String formatCollection();
  abstract String formatCourses();
  abstract String formatGoalProgress();
  abstract String formatLove();
  abstract String formatLoveStages();
  abstract String formatLoveWaiting();
  abstract String formatNpcRelationship(String npc1, String npc2);
  abstract String formatRelationships();
  abstract String formatReputation();
  abstract String formatRumors();
  abstract String formatWorldEvolution();
  abstract Future<List<GameChoice>> generateChoicesSeparately(String narrative);
  abstract List<GameChoice> generateContextualFallbackChoices();
  abstract Future<void> generateEnding();
  abstract List<GameChoice> generateFallbackChoices();
  abstract String generateFallbackNarrative();
  abstract void generateNewNPC();
  abstract String generateSortingNarrative(String house);
  abstract void handleLetterCommand(List<String> parts);
  abstract bool handleLocalCommand(String command);
  abstract void incrementWorldLineDeviation(double delta);
  abstract Future<void> initializeGame({    required String name,    required String bloodStatus,    required String birthLocation,    required List<String> personalityTraits,    String? gender,    String? appearance,    String? familyBackground,    List<String>? childhoodExperiences,    String? beliefs,    String? wandId,    String? petName,    String? petId,    String? sexOrientation,    String? birthday,    Map<String, int>? attributes,    Map<String, int>? houseDimensions,    String? initialTalent,    String? magicAptitude,    String? housePreference,    String? politicalTendency,    String? simulationStyle,    String? birthIdentity,    String openingScene = 'station',  });
  abstract bool isNearby(String npcId);
  abstract Future<List<Map<String, dynamic>>> listSaves();
  abstract Future<void> loadFromSave(String slotId);
  abstract void markIntroducedFromNarrative(String text);
  abstract void markNpcIntroduced(NPC npc);
  abstract void onApiKeyChange();
  abstract void parseNarrativeOnly(String text);
  abstract void parseResponse(String text);
  abstract Future<void> processChoice(GameChoice choice);
  abstract bool purchaseItem(String itemName, int price);
  abstract Future<void> quickSave();
  abstract void refreshClient();
  abstract void resetAllState();
  abstract void resetTokenUsage();
  abstract int roll(int min, int max);
  abstract Future<void> saveNow();
  abstract bool sellItem(int index, int price);
  abstract void syncRelationshipLevel(NPC npc);
  abstract String termLabel(String term);
  abstract void travelTo(String location);
  abstract Future<void> tryAutoLoad();
  abstract void unlockAchievement(String id);
  abstract void unlockCG(CgDef? cg);
  abstract void updateAcademicYearLabel();
  abstract Future<void> updateApiKey(String key);
  abstract void updateClient();
  abstract void updateNPCsFromAction(String action);
  abstract void updateNpcAffection(String npcId, int change, {String? reason});
  abstract void updatePlayerImpactScore(String action);
  abstract bool withdrawFromBank(int amount);
}
