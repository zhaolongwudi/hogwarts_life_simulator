import 'dart:math';
import 'package:flutter/widgets.dart';
import 'app_provider.dart';
import '../models/player.dart';
import '../models/npc.dart';
import '../models/world_state.dart';
import '../models/game_systems.dart';
import '../models/long_term_memory.dart';
import '../data/faculty_data.dart';
import '../data/house_data.dart';
import '../data/ending_review_data.dart';
import '../data/legacy_data.dart';
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

  /// 从 T0 核心事实「资质为XX」里回填魔法资质。原先写在 keyFacts 循环内部，
  /// 每条事实重新编译一次。
  static final RegExp reAptitudeFact = RegExp(r'资质为([^，,。\s]+)');

  /// narrative / summary buffer 清洗公共函数（mixin_narrative / mixin_response 共用）
  /// 
  /// 剥离：📅 状态栏整行 / 【时间戳】【地点】整行 / -----分隔线 /
  /// 可选：好感度/声望变化结构化区块（summary不需要，但解析好感的地方要保留）
  static String sanitizeNarrativeForArchive(String text, {bool keepStructuredBlocks = true}) {
    var cleaned = text;
    // 1) 📅 状态栏整行（AI写的：📅 1991年X月X日｜XX｜XX｜学院：XX）
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'^\s*📅[^\n]*\n', multiLine: true),
      (m) => '\n',
    );
    // 2) 【时间戳】【地点】整行（AI narrative 输出时写的这些标签，不该进存档/摘要）
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'^\s*【(时间戳|地点|时间|当前时间|当前地点)】[^\n]*\n', multiLine: true, caseSensitive: false),
      (m) => '\n',
    );
    // 3) 大段 --- / ─── 分隔线（summary / narrative 输入输出的装饰线）
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'^\s*[-─═]{5,}\s*$', multiLine: true),
      (m) => '\n',
    );
    // 4) 如果 keepStructuredBlocks=false，再去掉【好感度变化】【声望变化】
    if (!keepStructuredBlocks) {
      cleaned = cleaned.replaceAllMapped(reAffectionSection, (m) => '');
      cleaned = cleaned.replaceAllMapped(reReputationSection, (m) => '');
    }
    // 5) 收敛空行
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    return cleaned;
  }

  /// 玩家所属学院的「有效 key」：未分院 / 空串 / AI 编的四院之外的词 → null。
  ///
  /// 学院杯那三处守卫以前是三套口径（`!= null && isNotEmpty` / `!= null` /
  /// `== null`），第五轮只改了其中一处：空串仍会被 houseDisplayName 兜成
  /// 「未分院」写进年度榜，凭空多出第 5 行——奖牌位虽然退化成空白挡住了
  /// 崩溃，但「未分院：1000 分」照样稳稳显示在榜单上。判定收口到这里，
  /// 所有 mixin 与 UI 共用同一个答案。
  String? get houseKeyOrNull => normalizeHouseKey(player?.house);

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
  bool isSummarizing = false;
  String? error;
  int turnCount = 0;
  String lastPlayerAction = '';
  String? systemPrompt;
  String loadingStage = '';
  List<String> lastAffectionSections = [];
  final List<String> notifications = [];

  /// 当前委托板上展示的模板 ID（按展示顺序）。
  /// 旧实现每次调 _board() 都重新 shuffle，玩家看到「1. 收集月光草」
  /// 后输入 `/委托 接受 1` 却会接到另一个随机委托。
  /// 现在板子内容缓存到此处，只有显式 `/委托 刷新`、跨周补货或缓存失效才重排。
  List<String> questBoardIds = [];

  /// 上次补货的游戏周。跨周时委托板自动进新货，避免板面万年不变。
  int questBoardWeek = 0;

  /// 当日已完成的活动计数（key = 活动名），配合 [_activityDate] 跨天清零。
  /// 用于给高收益活动（决斗、魁地奇、禁林）加每日次数上限，
  /// 防止玩家在一个游戏日里无限刷奖励。
  final Map<String, int> dailyActivityCount = {};

  /// [dailyActivityCount] 对应的游戏日期（"年-月-日"），跨天即清零重计。
  String activityDate = '';

  /// 上一场决斗的对手 id（同一天不能连着挑战同一个人）。
  String? lastDuelOpponentId;

  /// 场景停滞检测：记录玩家当前地点已停留的回合数
  /// （public 化以供 mixin_narrative 跨文件访问，与其它核心字段一致）
  String? lastTrackedLocation;
  int turnsAtSameLocation = 0;

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
  /// 导演节拍器：距上次「转折」节拍的回合数。
  /// 99 = 开局即视为"很久没转折"，不挡第一次转折抽取。
  /// 不进存档：读档后从 99 重新开始计，影响只是一次转折可能来得早一点。
  int turnsSinceLastTurnBeat = 99;
  /// 学年制新NPC上限追踪：当前学年已生成的数量
  int npcGeneratedThisSchoolYear = 0;
  /// 记录 npcGeneratedThisSchoolYear 所属学年的起始年份
  int npcGenerationSchoolYear = 0;
  String? pendingAnchorDirective;

  /// 上一次漂移结算落在第几个「10 天」桶里。
  /// 用来保证漂移是按游戏内天数走、而不是每回合走（一回合推进多久取决于
  /// 玩家在做什么，按回合计费会让平衡数字完全失控）。
  int lastDeviationTickBucket = -1;

  /// 当前正等着玩家做抉择的因果锚点 id（见 lib/data/worldline_data.dart）。
  ///
  /// 非空时：叙事 AI 会收到"这一回合必须把抉择摆到玩家面前"的指令，
  /// 而 UI 上的选项直接就是那几个分支。玩家选完即清空。
  String? pendingCausalAnchorId;
  String openingScene = 'station';
  int? lastScannedNarrativeHash;

  /// 跨 Mixin 共享：从 Player 或 LongTermMemory 的 T0 核心事实解析魔法资质。
  /// 初始化失败/旧存档缺失字段时，用 T0 事实回填，并把值写回 Player。
  String resolveMagicAptitude(Player p) {
    final direct = p.magicAptitude ?? '';
    if (direct.isNotEmpty) return direct;
    for (final fact in memory.keyFacts) {
      if (fact.importance >= kPersistentFactImportance &&
          fact.category == 'ability' &&
          fact.id == 'ability:aptitude') {
        final m = reAptitudeFact.firstMatch(fact.fact);
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

  /// /伤痕 的输出。实现在 GameSystemsMixin。
  String formatScars();

  /// 读属性时**必须**走这里：它是基础值加上永久修正（疤痕）之后的结果。
  ///
  /// 直接读 `player.attributes[key]` 会让身上的疤在计算里完全消失——
  /// 那道疤就白留了。实现在 GameSystemsMixin。
  int effectiveAttr(String key);

  /// 学院杯加减分的唯一入口。实现在 GamePlayMixin。
  ///
  /// 所有加减分都得走它：它会把 reason 累计进来源明细，
  /// `/学院杯` 才能告诉玩家这一年分数是从哪儿挣来的。
  void addHouseCupPoints(int amount, String reason);

  Future<void> autoSave();
  String bloodStatusLabel(String status);
  String buildRelationshipSnapshot();
  String buildSystemPrompt();
  void bumpImpactScore(double delta, {String? debugReason});
  int calculateAge();
  Future<ChatResult> callDeepSeek(String prompt, {AiScene scene = AiScene.narrative});
  void checkAffectionAchievements(NPC npc);
  CgDef? cgById(String id);
  bool addCollectible(String id);
  void checkAllAchievements();
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
  Future<String?> exportSave(String slotId);
  void fastForwardTime(int days);
  String flowModeLabel(String mode);
  String formatAffections({int maxEntries = 8});
  String formatBloodRelatives();
  String formatBoneMode();
  String formatCollection();
  String formatCourses();
  String formatGoalProgress();
  String goalSteeringLine(String? goalName);
  String formatLove();
  String formatLoveStages();
  String formatLoveWaiting();
  String formatNpcRelationship(String npc1, String npc2);
  String formatRelationships();
  String formatSpells();
  String formatSpellDetail(String name);
  void learnSpell(String name);
  void practiseSpell(String name);
  String formatCharacterDossier(String idOrName);
  String giveGift(String npcKeyword, String itemName);
  String formatReputation();
  String formatRumors();
  void addRumor(String text);
  String formatWorldEvolution();
  Future<List<GameChoice>> generateChoicesSeparately(String narrative);
  List<GameChoice> generateContextualFallbackChoices();
  Future<void> generateEnding();
  List<GameChoice> generateFallbackChoices();
  String generateFallbackNarrative();
  // 统一的「叙事末尾承接型兜底选项」入口：
  // 当独立选项生成超时/内容不合格时，GameNarrativeMixin 和 GameResponseMixin 都走同一套，
  // 避免一个走老的简易关键词池、一个走新的末尾800字承接池，造成断链。
  List<GameChoice> buildFallbackChoices(String narrative);
  void generateNewNPC();
  String generateSortingNarrative(String house);
  void handleLetterCommand(List<String> parts);
  bool handleLocalCommand(String command);
  void incrementWorldLineDeviation(double delta);

  /// 结算一次因果锚点抉择，返回展示给玩家的后果文本。
  /// 实现在 GameSystemsMixin。
  String resolveCausalChoice(String anchorId, String optionId);

  /// /世界线 的输出。实现在 GameSystemsMixin。
  String formatWorldLine();

  /// 毕业时是否有一份留校邀请正等着答复。
  bool get pendingFacultyOffer;

  /// 答复留校邀请，返回展示给玩家的文本。实现在 GameSystemsMixin。
  String resolveFacultyOffer(bool accept);

  /// /教职 的输出。实现在 GameSystemsMixin。
  String formatFaculty();

  /// 留校资格评估（/教职 与毕业结算共用）。实现在 GameSystemsMixin。
  FacultyEligibility evaluateFacultyOffer();

  /// /传承 的输出。实现在 GameSystemsMixin。
  String formatLegacy();

  /// 把这一生交棒给 [childName]，开一局新的。实现在 GameSystemsMixin。
  Future<bool> startLegacy(String childName);

  /// 已到入学年龄、可以接棒的孩子。实现在 GameSystemsMixin。
  List<ChildRecord> heirsOfAge();

  /// 把传承来的世交与世仇落到 NPC 身上。实现在 GameSystemsMixin。
  void applyLegacyRelations(LegacyCarryover legacy);

  /// 把散在各处的状态收拢成一份「这七年」的事实。实现在 GameSystemsMixin。
  EndingFacts endingFactsOf(Player p);

  Future<void> initializeGame({    required String name,    required String bloodStatus,    required String birthLocation,    required List<String> personalityTraits,    String? gender,    String? appearance,    String? familyBackground,    List<String>? childhoodExperiences,    String? beliefs,    String? wandId,    String? petName,    String? petId,    String? sexOrientation,    String? birthday,    Map<String, int>? attributes,    Map<String, int>? houseDimensions,    String? initialTalent,    String? magicAptitude,    String? housePreference,    String? politicalTendency,    String? simulationStyle,    String? birthIdentity,    String openingScene = 'station',    LegacyCarryover? legacy,  });
  bool isNearby(String npcId);
  Future<String?> importSave(String jsonString);
  Future<List<Map<String, dynamic>>> listSaves();
  Future<void> loadFromSave(String slotId);
  void markIntroducedFromNarrative(String text);
  void markNpcIntroduced(NPC npc);
  bool markScanIfNew(String narrative);
  void onApiKeyChange();
  bool parseNarrativeOnly(String text, {bool applySideEffects = true});

  /// 叙事定稿后落库副作用（好感度/声望/分院/NPC登场），每回合只调一次
  void applyNarrativeSideEffects(String text);
  void parseResponse(String text);
  void parseAffectionChanges(String text);
  void parseReputationChanges(String text);
  Future<void> processChoice(GameChoice choice);

  /// 重试上一次失败的行动（AI 不可用时的兜底路径用）
  Future<void> retryLastAction();

  /// 手动清掉错误提示条
  void clearError();

  /// 今日该高收益活动已进行的次数（跨天自动归零）
  int dailyCountOf(String activity);

  /// 该活动每日次数上限
  int dailyLimitOf(String activity);

  /// 今日是否还能进行该活动
  bool canDoDaily(String activity);

  /// 记录一次活动
  void recordDailyActivity(String activity);
  bool purchaseItem(String itemName, int price, {String type, String description});
  Future<void> quickSave();
  Future<void> saveGameNamed(String slotName);

  /// 统一的存档写入：自动存档 / 快速存档 / 命名存档三处共用。
  /// 以前三处各写一份 extraData，漏写一个字段读档时就静默归零。
  /// 实现在 GameSystemsMixin。
  Future<void> writeSave({required String slotId, required String slotName});

  /// 把一份存档数据灌回 provider：自动读档与槽位读档共用。
  /// 含存档迁移（_migrateSave）和一致性检查——自动读档以前漏了这两步。
  /// 实现在 GameSystemsMixin。
  void applySaveData(Map<String, dynamic> data);

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
  String? startShipping(String nameA, String nameB);
  void stopShipping(int index);
  void advanceShippings(String narrative);
  String formatShippings();
  String? proposeMarriage();
  String? holdWedding();
  String? tryConceive();
  void advancePregnancy();
  String formatFamily();
  void travelTo(String location);
  Future<void> tryAutoLoad();
  void unlockAchievement(String id);
  void unlockCG(CgDef? cg);
  void updateAcademicYearLabel();
  void updatePlayerSignature(String text);
  Future<void> updateApiKey(String key);
  void updateClient();
  void updateNPCsFromAction(String action);
  /// [quiet] = true 时本次调用不触发 notifyListeners/autoSave。
  ///
  /// 批量更新（日常好感微调、一次解析出多行好感变化）必须传 true 并在循环
  /// 结束后统一通知一次：否则 N 个人就是 N 次全量 rebuild + N 次全量写档。
  void updateNpcAffection(String npcId, int change,
      {String? reason, int? severity, bool quiet = false});
  void updatePlayerImpactScore(String action);
  bool withdrawFromBank(int amount);

  // ========== 场景停滞检测（跨 Mixin 访问：mixin_response 需要读取停滞阈值/钩子检测结果）==========
  // 实现由 mixin_narrative.dart 提供。
  int stagnationThresholdFor(String location);
  bool narrativeHasUnresolvedHook(String narrative);

  // ========== 剧情一致性 & 短期断言（跨 Mixin 访问）==========
  // 断言提取 & 轮换：mixin_narrative 在回合结束调用；Prompt 两端（叙事+选项）都要读取断言注入。
  // 一致性校验：mixin_response 在 parseNarrativeOnly 之后调用，失败走重试/兜底。
  List<String> extractShortAssertions(String narrative);
  void rotateTurnAssertions(List<String> newAssertions);
  String buildAssertionsPromptBlock();
  List<Map<String, dynamic>> validateNarrativeConsistency(String narrative);
  void recordConsistencyViolation(Map<String, dynamic> v);

  // ====== 新玩法（GamePlayMixin）=====
  void acceptQuest(int index);
  void acceptQuestTemplate(String id);
  void deliverQuest(int index);
  void duelNpc(String? name);
  void equipItem(String name);
  void exploreForbiddenForest();
  String formatBestiary();
  String formatEquip();
  String formatHouseCup();
  String formatItemUseHelp();
  String formatQuests();
  String formatQuidditch();
  void petInteract(String action);

  /// 对角巷「咿啦猫头鹰商店」的在售清单。实现在 GamePlayMixin。
  String formatPetShop();

  /// 买一只宠物；[keyword] 为空时返回在售清单。实现在 GamePlayMixin。
  String buyPet(String keyword);

  void playQuidditch();
  void refreshQuestBoard();
  void settleHouseCup();
  void setQuidditchPosition(String pos);
  void unequipItem(String slot);
  void useItem(String name);
}
