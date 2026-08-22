import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'app_provider.dart';
import '../models/player.dart';
import '../models/npc.dart';
import '../models/world_state.dart';
import '../models/game_systems.dart';
import '../data/course_data.dart';
import '../data/wand_data.dart';
import '../data/cg_data.dart';
import '../data/npc_data.dart';
import '../data/world_rules.dart';
import '../data/goal_data.dart';
import '../data/balance_constants.dart';
import '../data/event_anchors.dart';
import '../data/trait_data.dart';
import '../services/deepseek_service.dart';
import '../services/save_service.dart';
import '../services/npc_chat_service.dart';
import '../services/ai_router.dart';
import '../services/rate_limiter.dart';
import '../utils/crash_logger.dart';
import '../utils/prompt_sanitizer.dart';
import '../utils/story_text_renderer.dart';

class GameProvider extends ChangeNotifier {
  final AppProvider appProvider;
  AiRouter? _router;
  final SaveService _saveService = SaveService();
  final Random _random = Random();
  late NpcChatService chatService;

  // ====== 预编译正则（避免循环内重复编译） ======
  // 选项行开头：半角 A-E.  全角Ａ-Ｅ．  中文顿号、  右括号  冒号  空格(至少1个)
  static final _reChoiceOption = RegExp(
    r'^\s*(?:[A-Ea-e]|[Ａ-Ｅａ-ｅ]|[\d]{1,2}|[一二三四五六七八九十]{1,3})\s*(?:[\.\．、\)）:：])\s*',
  );
  static final _reMultiNewline = RegExp(r'\n{3,}');
  static final _reAffectionSection = RegExp(r'【好感(?:度)?变化?】[\s\S]*?(?=【|$)');
  static final _reReputationSection = RegExp(r'【声望变化?】[\s\S]*?(?=【|$)');
  // 匹配任意一行：(开头/上一行换行后) 编号(A-E/数字/中文数字) + 分隔符(./、/)/):/： + 空格 + 选项文字
  // 用来定位整个 AI 响应中「选项区块」的起点
  static final _reChoiceMultiLine = RegExp(
    r'(?:^|\n)\s*(?:[A-Ea-e]|[Ａ-Ｅａ-ｅ]|[\d]{1,2}|[一二三四五六七八九十]{1,3})\s*(?:[\.\．、\)）:：])\s+\S',
    multiLine: true,
  );

  Player? _player;
  WorldState _worldState = WorldState();
  final Map<String, NPC> _npcRegistry = {};

  String _currentNarrative = '';
  String _narrativeSummary = '';
  String _pendingSummary = '';
  /// 最近几回合剧情环形缓冲（避免 AI 只有单回合记忆，保持短期连贯性）
  final List<String> _recentTurns = [];
  static const int _maxRecentTurns = 4;
  List<GameChoice> _choices = [];
  bool _isLoading = false;
  bool _isInitializing = false;
  String? _error;
  int _turnCount = 0;
  String _lastPlayerAction = '';
  String? _systemPrompt;
  String _loadingStage = '';
  List<String> _lastAffectionSections = [];
  final List<String> _notifications = [];
  Future<void>? _pendingSave;
  bool _saveScheduled = false;

  int _totalPromptTokens = 0;
  int _totalCompletionTokens = 0;
  int _totalTokens = 0;
  int _lastRoundTokens = 0;
  int _apiCalls = 0;
  int _gameWeek = 1; // 用于好感沉淀（第一周上限+30）
  int _lastSchoolYearStart = 0; // 学年推进追踪（当前学年起始年份）
  String? _pendingAnchorDirective; // 待注入的事件锚点指令
  String _openingScene = 'station';

  int get totalPromptTokens => _totalPromptTokens;
  int get totalCompletionTokens => _totalCompletionTokens;
  int get totalTokens => _totalTokens;
  int get lastRoundTokens => _lastRoundTokens;
  int get apiCalls => _apiCalls;
  String get loadingStage => _loadingStage;

  Player? get player => _player;
  WorldState get worldState => _worldState;
  String get currentNarrative => _currentNarrative;
  List<GameChoice> get choices => _choices;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get error => _error;
  int get turnCount => _turnCount;
  Map<String, NPC> get npcRegistry => _npcRegistry;
  List<String> get notifications => List.unmodifiable(_notifications);
  List<String> get lastAffectionSections => List.unmodifiable(_lastAffectionSections);

  GameProvider(this.appProvider) {
    chatService = NpcChatService(appProvider: appProvider);
    _updateClient();
    appProvider.addListener(_onApiKeyChange);
    if (appProvider.isGameStarted) {
      _isInitializing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryAutoLoad();
      });
    }
  }

  Future<void> _tryAutoLoad() async {
    if (!appProvider.isGameStarted) return;
    final data = await _saveService.loadAutoSave();
    if (data == null) {
      _isInitializing = false;
      appProvider.setGameStarted(false);
      notifyListeners();
      return;
    }
    try {
      _player = Player.fromJson(data['player'] as Map<String, dynamic>);
      _worldState = WorldState.fromJson(data['world_state'] as Map<String, dynamic>);
      _npcRegistry.clear();
      (data['npc_registry'] as Map<String, dynamic>).forEach((k, v) {
        _npcRegistry[k] = NPC.fromJson(v as Map<String, dynamic>);
      });
      // 系统提示词必须在 player 和 worldState 赋值之后构建
      _systemPrompt = _buildSystemPrompt();

      // 叙事/选项：直接加载存档值（即使短也保留原貌，用户可点「推进」重生成剧情）
      _currentNarrative = data['narrative'] as String? ?? '';
      _choices = (data['choices'] as List<dynamic>?)
          ?.map((c) => GameChoice(text: c['text'] as String, action: c['action'] as String))
          .toList() ?? [];
      _turnCount = data['turn_count'] as int? ?? 0;

      final extraData = data['extra_data'] as Map<String, dynamic>? ?? {};
      _narrativeSummary = extraData['narrative_summary'] as String? ?? '';
      _pendingSummary = extraData['pending_summary'] as String? ?? '';
      _gameWeek = extraData['game_week'] as int? ?? 1;
      _lastRoundTokens = extraData['last_round_tokens'] as int? ?? 0;
      _apiCalls = extraData['api_calls'] as int? ?? 0;
      _totalPromptTokens = extraData['total_prompt_tokens'] as int? ?? 0;
      _totalCompletionTokens = extraData['total_completion_tokens'] as int? ?? 0;
      _totalTokens = extraData['total_tokens'] as int? ?? 0;

      _recentTurns
        ..clear()
        ..addAll((extraData['recent_turns'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            []);
      if (_recentTurns.isEmpty && _currentNarrative.isNotEmpty) {
        _recentTurns.add(_currentNarrative);
      }

      // 完整性兜底：若读档后正文极短 (< 20字) 或完全没有选项，
      // 则补发兜底选项，但**不立即覆盖 _currentNarrative 为生成式兜底**——
      // 否则老存档里已被错误截断的短叙事会被替换成"你在霍格沃茨走廊上..."
      // 这种无内容模板，导致读档体验更差；若玩家不满内容，点「推进」就会重新生成
      if (_choices.isEmpty) {
        _choices = _generateFallbackChoices();
      }
      if (_choices.length > 4) {
        _choices = _choices.sublist(0, 4);
      }
      if (_currentNarrative.isEmpty) {
        _currentNarrative = _generateFallbackNarrative();
      }

      // 加载后绝对不能让 _isLoading 残留为 true — 否则界面永远转圈或读档后
      // 自动按残留 loading 触发再次请求
      _isLoading = false;
      _isInitializing = false;
      _error = null;
      _loadingStage = '';
      debugPrint('✅ 自动存档加载成功: ${_player?.name} 第$_turnCount回合 (第$_gameWeek周) 叙事${_currentNarrative.length}字');
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _isInitializing = false;
      debugPrint('❌ 自动存档加载失败: $e');
      appProvider.setGameStarted(false);
      _error = '存档加载失败: $e';
      notifyListeners();
      unawaited(CrashLogger.instance.record(
        e,
        StackTrace.current,
        screen: 'autoLoad',
        extra: 'error during tryAutoLoad',
      ));
    }
  }

  Future<void> _autoSave() async {
    if (_player == null) return;
    if (_saveScheduled) return;
    _saveScheduled = true;

    _pendingSave = () async {
      try {
        await Future.delayed(const Duration(milliseconds: 300));
        await _saveService.autoSave(
          player: _player!.toJson(),
          worldState: _worldState.toJson(),
          npcRegistry: _npcRegistry.map((k, v) => MapEntry(k, v.toJson())),
          narrative: _currentNarrative,
          choices: _choices.map((c) => {'text': c.text, 'action': c.action}).toList(),
          turnCount: _turnCount,
          extraData: {
            'narrative_summary': _narrativeSummary,
            'pending_summary': _pendingSummary,
            'recent_turns': _recentTurns,
            'game_week': _gameWeek,
            'last_round_tokens': _lastRoundTokens,
            'api_calls': _apiCalls,
            'total_prompt_tokens': _totalPromptTokens,
            'total_completion_tokens': _totalCompletionTokens,
            'total_tokens': _totalTokens,
          },
        );
      } catch (e) {
        debugPrint('❌ 自动存档失败: $e');
      } finally {
        _saveScheduled = false;
      }
    }();
    await _pendingSave;
  }

  void _onApiKeyChange() {
    _updateClient();
    chatService.refreshClient();
  }

  void _updateClient() {
    final config = AiRouterConfig(
      narrativeProvider: appProvider.providerForScene(AiScene.narrative),
      summaryProvider: appProvider.providerForScene(AiScene.summary),
      npcChatProvider: appProvider.providerForScene(AiScene.npcChat),
      choiceProvider: appProvider.providerForScene(AiScene.choice),
    );
    final router = AiRouter(config);
    for (final p in AiProvider.values) {
      if (appProvider.hasKey(p)) {
        router.register(appProvider.configForProvider(p));
      }
    }
    _router = router;
  }

  void refreshClient() {
    // 清理响应缓存，防止旧模型的响应泄漏到新路由
    ResponseCache.instance.clear();
    _updateClient();
    chatService.refreshClient();
    notifyListeners();
  }

  void updateNpcAffection(String npcId, int change, {String? reason}) {
    final npc = _npcRegistry[npcId];
    if (npc == null) return;

    // 只要产生了好感互动，就标记为已登场/认识
    if (!npc.introduced) markNpcIntroduced(npc);

    final currentDay = _worldState.time.dayOfYear;
    int actualChange = change;

    if (change > 0) {
      final cap = npc.getAffectionGainLimit(currentDay, _gameWeek);
      if (cap <= 0) {
        actualChange = 0;
        _notifications.add('📊 ${npc.name}的好感本周已达上限，无法继续提升');
        _worldState.addNarrativeEvent('📊 ${npc.name}的好感本周已达上限，无法继续提升');
      } else if (change > cap) {
        actualChange = cap;
      }
      npc.affectionGainedThisWeek += actualChange;
      npc.affectionGainedThisMonth += actualChange;
    }

    if (actualChange > 0 && npc.hasGrudge) {
      final cap = npc.effectiveAffectionCap;
      final projected = npc.affection + actualChange;
      if (projected > cap) {
        actualChange = cap - npc.affection;
        if (actualChange < 0) actualChange = 0;
        _notifications.add('⚠️ ${npc.name}对你的信任因过去的背叛而受限');
        _worldState.addNarrativeEvent('⚠️ ${npc.name}对你的信任因过去的背叛而受限');
      }
    }

    if (change < -15) {
      npc.addGrudge('betrayal', reason ?? '背叛/欺骗', currentDay);
      _notifications.add('💔 ${npc.name}因你的行为而记恨在心');
      _worldState.addNarrativeEvent('💔 ${npc.name}因你的行为而记恨在心');
    }

    npc.affection = (npc.affection + actualChange).clamp(-100, 100);
    if (npc.affection > npc.maxAffectionReached) {
      npc.maxAffectionReached = npc.affection;
    }

    if (actualChange != 0) {
      final eventText = '好感 ${actualChange > 0 ? '+' : ''}$actualChange：${reason ?? '互动'}';
      npc.recentEvents.insert(0, eventText);
      if (npc.recentEvents.length > 10) npc.recentEvents.removeLast();
    }
    _checkAffectionAchievements(npc);
    notifyListeners();
    _autoSave();
  }

  Future<void> updateApiKey(String key) async {
    await appProvider.saveApiKey(key);
    _updateClient();
    chatService.refreshClient();
  }

  // ==================== 系统提示词（精简版 + 玩家档案嵌入） ====================
  String _buildSystemPrompt() {
    final p = _player;
    final effectiveEra = _worldState.era.isNotEmpty ? _worldState.era : appProvider.era.name;
    final eraName = _eraLabelShort(_parseEra(effectiveEra));

    final profile = p != null
        ? '【档案】${p.name}·${_bloodStatusLabel(p.bloodType)}·${p.house ?? '未分院'}·${p.grade}年·天赋${p.magicAptitude ?? '普通'}·精神${p.spirit}·精力${p.energy}'
        : '';

    // 身份模式：穿越者拥有对原作剧情的隐约记忆，原住民则一无所知
    final identityLine = appProvider.identityMode == IdentityMode.transmigration
        ? '【身份模式】穿越者：你对原作的命运走向留有隐约记忆，可作为行动依据，但他人不会轻信"预言"；引用未来信息需克制并举证自洽。'
        : '【身份模式】原住民：你对命运走向一无所知，只凭自己的判断与本能行事。';

    // 人生目标：若已设定，注入为剧情牵引方向（非强制任务）
    final goalLine = (p != null && p.currentGoal != null && p.currentGoal!.isNotEmpty)
        ? '【人生目标】${p.currentGoal}（仅作剧情牵引方向，玩家仍可自由行动，切勿变成每回合的任务推送）'
        : '';

    final worldRules = kUseFusedCompact ? kWorldRulesFusedCompact : kWorldRulesFused;

    final buffer = StringBuffer()
      ..write(worldRules)
      ..write('\n\n')
      ..write(profile)
      ..write('\n【时代】')
      ..write(eraName)
      ..write('\n')
      ..write(identityLine);
    if (goalLine.isNotEmpty) {
      buffer
        ..write('\n')
        ..write(goalLine);
    }
    final traitLine = _traitNarrativeHints();
    if (traitLine.isNotEmpty) {
      buffer
        ..write('\n')
        ..write(traitLine);
    }
    return buffer.toString();
  }

  String _eraLabel(Era era) {
    return switch (era) {
      Era.dumbledore => '邓布利多时代（1892-1899）：少年阿不思·邓布利多在霍格沃茨求学，认识盖勒特·格林德沃。',
      Era.marauders => '亲世代（1971-1978）：掠夺者四人组与莉莉·伊万斯同窗的时代。',
      Era.first_war => '第一次巫师战争（1970s后期）：社会氛围紧张，伏地魔崛起的阴影笼罩魔法界。',
      Era.harry_same => '子世代（1991-1998）：哈利·波特在霍格沃茨的求学时期。',
      Era.post_war => '现代（2020+）：战后重建的魔法世界，阿不思·波特与斯科皮·马尔福的时代。',
      Era.random => '随机时代：由叙事开始时随机决定。',
    };
  }

  /// 短版时代描述（节省 token。系统提示词和开场叙事中使用）
  String _eraLabelShort(Era era) {
    return switch (era) {
      Era.dumbledore => '邓布利多时代 1892（少年邓布利多求学）',
      Era.marauders => '亲世代 1971（掠夺者同窗）',
      Era.first_war => '一战末期 1976（伏地魔崛起）',
      Era.harry_same => '子世代 1991（哈利入学）',
      Era.post_war => '战后 2020（阿不思·波特时代）',
      Era.random => '随机时代',
    };
  }

  Era _parseEra(String eraStr) {
    return Era.values.firstWhere(
      (e) => e.name == eraStr.toLowerCase(),
      orElse: () => Era.marauders,
    );
  }

  // ==================== 重置全部游戏状态 ====================
  /// 用于「开始新游戏」时彻底清空旧存档上下文，避免新游戏的第一回合仍被旧摘要、
  /// 旧剧情缓冲、旧回合计数器影响，导致 AI"接着之前的剧情写"。
  void resetAllState() {
    _player = null;
    _worldState = WorldState();
    _npcRegistry.clear();
    _currentNarrative = '';
    _narrativeSummary = '';
    _pendingSummary = '';
    _recentTurns.clear();
    _choices.clear();
    _isLoading = false;
    _isInitializing = false;
    _error = null;
    _turnCount = 0;
    _lastPlayerAction = '';
    _systemPrompt = null;
    _loadingStage = '';
    _notifications.clear();
    _gameWeek = 1;
    _lastSchoolYearStart = 0;
    _pendingAnchorDirective = null;
    _totalTokens = 0;
    _lastRoundTokens = 0;
    _apiCalls = 0;
    _openingScene = 'station';
    // 清除响应缓存（重要：防止旧剧情数据泄漏到新游戏）
    ResponseCache.instance.clear();
    // 清除速率限制器状态
    AgnesRateLimiter.instance.reset();
    SenseNovaQuotaManager.instance.reset();
    // 销毁旧路由器（清除响应缓存、已注册的服务实例）
    _router = null;
    // 清除 NPC 聊天缓存（对话历史、路由器）
    chatService.clearCache();
    chatService.refreshClient();
    notifyListeners();
  }

  // ==================== 初始化游戏 ====================
  Future<void> initializeGame({
    required String name,
    required String bloodStatus,
    required String birthLocation,
    required List<String> personalityTraits,
    String? gender,
    String? appearance,
    String? familyBackground,
    List<String>? childhoodExperiences,
    String? beliefs,
    String? wandId,
    String? petName,
    String? petId,
    String? sexOrientation,
    String? birthday,
    Map<String, int>? attributes,
    Map<String, int>? houseDimensions,
    String? initialTalent,
    String? magicAptitude,
    String? housePreference,
    String? politicalTendency,
    String? simulationStyle,
    String? birthIdentity,
    String openingScene = 'station',
  }) async {
    // 先彻底清空所有旧状态（防止新开局把旧摘要/近期剧情注入到 Prompt）
    resetAllState();
    // 重新创建路由器（resetAllState 已将 _router 置空）
    _updateClient();
    // 清空旧自动存档文件（防止新游戏误加载到旧存档）
    try {
      await _saveService.clearAutoSave();
    } catch (e) {
      debugPrint('清理旧存档失败(不影响游戏): $e');
    }
    _isLoading = true;
    notifyListeners();

    try {
      final birthYear = _calculateBirthYear();
      final startYear = _startYearForEra(appProvider.era);
      final startHour = 9;
      final startMinute = 0;

      _player = Player(
        name: name,
        birthYear: birthYear,
        bloodType: bloodStatus,
        birthLocation: birthLocation,
        personalityTraits: personalityTraits,
        gender: gender ?? '',
        appearance: appearance,
        familyBackground: familyBackground,
        childhoodExperiences: childhoodExperiences ?? const [],
        beliefs: beliefs,
        wandId: wandId,
        petId: petId,
        petName: petName,
        sexOrientation: sexOrientation,
        birthDay: birthday,
        attributes: attributes,
        houseDimensions: houseDimensions,
        initialTalent: initialTalent,
        magicAptitude: magicAptitude,
        housePreference: housePreference,
        politicalTendency: politicalTendency,
        simulationStyle: simulationStyle,
        birthIdentity: birthIdentity,
        grade: 1,
      );

      // 开局特质抽取（3个，软保底稀有度）
      final rolledTraits = _rollStartingTraits();
      _player!.traits.addAll(rolledTraits.map((t) => t.id));
      _applyTraitBonuses(rolledTraits);

      _worldState = WorldState(
        era: appProvider.era.name,
        academicYear: _academicYearForEra(appProvider.era),
        time: GameTime(
          year: startYear,
          month: 9,
          day: 1,
          hour: startHour,
          minute: startMinute,
        ),
      );
      _lastSchoolYearStart = startYear;
      _updateAcademicYearLabel();

      // 必须在 _player 和 _worldState 都赋值后再构建系统提示词
      _systemPrompt = _buildSystemPrompt();

      _initializeNPCsByEra();
      _assignInitialRelationships();
      _openingScene = openingScene;
      await _generateOpeningScene();

      appProvider.setGameStarted(true);
      _unlockAchievement('first_letter');
      if (_player!.letters.isEmpty) {
        _player!.letters.add(Letter(
          id: 'L_admission',
          sender: '霍格沃茨魔法学校',
          date: '${_player!.birthYear}年7月',
          content: '亲爱的${_player!.name}小姐/先生：\n\n我们愉快地通知您，您已获准在霍格沃茨魔法学校就读。随信附上所需书籍与装备一览表。\n学期定于九月一日开始，我们将于七月三十一日前静候您的猫头鹰带来回音。\n\n您忠诚的\n副校长（女）\n米勒娃·麦格 谨上',
        ));
      }
      _isLoading = false;
      notifyListeners();
      _autoSave();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      unawaited(CrashLogger.instance.record(
        e,
        StackTrace.current,
        screen: 'openingInit',
        extra: 'name=$name, era=${appProvider.era.name}',
      ));
    }
  }

  String _academicYearForEra(Era era) {
    return switch (era) {
      Era.dumbledore => '1892-1893',
      Era.marauders => '1971-1972',
      Era.first_war => '1976-1977',
      Era.harry_same => '1991-1992',
      Era.post_war => '2020-2021',
      Era.random => '1991-1992',
    };
  }

  /// 按时代初始化 NPC（数据层 npc_data.dart）
  void _initializeNPCsByEra() {
    _npcRegistry.clear();
    final eraKey = _eraKey(appProvider.era);
    final seeds = eraNpcSeeds[eraKey] ?? [];

    for (final seed in seeds) {
      _npcRegistry[seed.id] = NPC(
        id: seed.id,
        name: seed.name,
        house: seed.house,
        grade: seed.grade,
        bloodStatus: seed.bloodStatus,
        isCanon: true,
        personality: List.of(seed.personality),
        appearance: seed.appearance,
        sexOrientation: seed.sexOrientation,
        giftPrefs: Map.of(seed.giftPrefs),
        personalGoal: seed.personalGoal,
        affection: _initialAffectionFor(seed),
        reputation: Reputation(
          academic: _roll(15, 45),
          social: _roll(15, 45),
          combat: _roll(10, 40),
          moral: _roll(20, 50),
          leadership: _roll(10, 40),
          dark: seed.era == 'dumbledore' || seed.id == 'grindelwald'
              ? _roll(30, 60)
              : _roll(0, 20),
        ),
      );
    }
  }

  String _eraKey(Era era) {
    return switch (era) {
      Era.dumbledore => 'dumbledore',
      Era.marauders => 'marauders',
      Era.first_war => 'marauders',
      Era.harry_same => 'harry_same',
      Era.post_war => 'post_war',
      Era.random => 'random',
    };
  }

  int _initialAffectionFor(NpcSeed seed) {
    if (seed.grade == 0) return _roll(0, 10);
    return _roll(0, 15);
  }

  int _roll(int min, int max) => min + _random.nextInt(max - min + 1);

  /// 建立玩家初始关系
  /// 说明：开局不自动把「同年级同学」标记为已认识——必须在剧情中正式见面/产生互动才会 introduced=true。
  /// 仅对血缘亲属、开场设定的宠物绯月等明确认识的角色默认 introduced。
  void _assignInitialRelationships() {
    final p = _player;
    if (p == null) return;
    for (final npc in _npcRegistry.values) {
      if (npc.grade > 0 && npc.grade == (p.grade ?? 1)) {
        p.relationships[npc.id] = Relationship(
          targetId: npc.id,
          targetName: npc.name,
          relationType: '同学',
          level: 0, // 仅登记关系档案，好感待剧情中建立
        );
      }
    }
  }

  /// 显式标记某 NPC 已登场/被玩家认识（并记录认识事件）
  void markNpcIntroduced(NPC npc) {
    if (npc.introduced) return;
    npc.introduced = true;
    final event = '初次见面';
    if (!npc.recentEvents.contains(event)) {
      npc.recentEvents.insert(0, event);
      if (npc.recentEvents.length > 10) npc.recentEvents.removeLast();
    }
    _worldState.addNarrativeEvent('👤 你结识了 ${npc.name}');
  }

  /// 扫描剧情文本，匹配到已知 NPC 名字时自动标记 introduced
  /// （严格模式：仅当名字独立出现、前后不是其他汉字字母时才认定登场；
  ///  额外限制：单回合最多标记 5 人，避免 AI 列大纲时一次性把所有角色「登记」）
  void _markIntroducedFromNarrative(String text) {
    if (text.isEmpty) return;  // 移除 _npcRegistry.isEmpty 检查，允许在空注册表时也能工作
    
    // 先自动注册可能出现的新NPC
    _autoRegisterNPCsFromNarrative(text);
    
    if (_npcRegistry.isEmpty) return;
    
    int markedThisRound = 0;
    const maxPerRound = 5;
    // 按名字长度降序，长名优先匹配（避免「哈利」在「哈利·波特」之前匹配到）
    final names = _npcRegistry.values.toList()
      ..sort((a, b) => b.name.length.compareTo(a.name.length));
    for (final npc in names) {
      if (npc.introduced) continue;
      if (markedThisRound >= maxPerRound) break;
      // 名字必须 >= 2 字符才参与自动匹配（过短的昵称/单字容易误匹配）
      if (npc.name.runes.length < 2) continue;
      if (_standaloneNameMentioned(text, npc.name)) {
        markNpcIntroduced(npc);
        markedThisRound++;
      }
    }
  }

  /// 从剧情文本中自动检测并注册新NPC
  void _autoRegisterNPCsFromNarrative(String text) {
    if (text.isEmpty) return;
    
    // 提取可能的人名模式（中文和英文）
    final namePatterns = [
      // 英文人名: Mr./Mrs./Ms./Professor/Dr. + 姓氏
      RegExp(r'(?:Mr\.|Mrs\.|Ms\.|Professor|Dr\.)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)'),
      // 中文人名: 2-4个汉字，常见姓氏开头
      RegExp(r'([\u4e00-\u9fff]{2,4})(?:[·\s][\u4e00-\u9fff]{1,4})?'),
      // 称呼: 先生/小姐/夫人/教授 + 姓氏
      RegExp(r'([\u4e00-\u9fff]{1,2})(?:先生|小姐|夫人|教授|老师)'),
    ];
    
    final existingNames = _npcRegistry.values.map((n) => n.name).toSet();
    final detectedNames = <String>{};
    
    for (final pattern in namePatterns) {
      for (final match in pattern.allMatches(text)) {
        final name = match.group(1)?.trim() ?? '';
        if (name.length < 2 || name.length > 10) continue;
        
        // 排除常见非人名词汇
        if (_isLikelyNotName(name)) continue;
        
        // 检查是否已存在或已被检测
        final exists = existingNames.any((n) => 
          n == name || n.contains(name) || name.contains(n));
        if (exists) continue;
        
        // 检查是否在当前文本中多次出现（可能是重要角色）
        final occurrences = _countNameOccurrences(text, name);
        if (occurrences >= 2) {
          detectedNames.add(name);
        }
      }
    }
    
    // 注册检测到的新NPC
    for (final name in detectedNames) {
      if (_npcRegistry.length >= 50) break;  // 限制NPC总数
      final id = 'auto_${DateTime.now().millisecondsSinceEpoch}_${_npcRegistry.length}';
      final npc = _createAutoGeneratedNPC(id, name);
      _npcRegistry[id] = npc;
      markNpcIntroduced(npc);
      debugPrint('[自动注册] 新NPC: $name (id: $id)');
    }
  }
  
  /// 判断字符串是否可能不是人名
  bool _isLikelyNotName(String str) {
    final nonNameWords = {
      '霍格沃茨', '对角巷', '翻倒巷', '霍格莫德', '禁林',
      '城堡', '大礼堂', '图书馆', '教室', '宿舍',
      '魔法', '咒语', '魔杖', '扫帚', '猫头鹰',
      '学生', '老师', '教授', '校长', '院长',
      '比赛', '考试', '假期', '学期', '学年',
      '魔法部', '凤凰社', '食死徒', '傲罗',
    };
    return nonNameWords.any((w) => str.contains(w));
  }
  
  /// 统计名字在文本中出现的次数
  int _countNameOccurrences(String text, String name) {
    int count = 0;
    int idx = 0;
    while (true) {
      idx = text.indexOf(name, idx);
      if (idx == -1) break;
      count++;
      idx += name.length;
    }
    return count;
  }
  
  /// 创建自动生成的NPC档案
  NPC _createAutoGeneratedNPC(String id, String name) {
    // 随机分配属性
    final houses = ['格兰芬多', '斯莱特林', '拉文克劳', '赫奇帕奇'];
    final personalities = ['友善', '内向', '活泼', '严肃', '幽默', '神秘'];
    final locations = ['霍格沃茨', '大礼堂', '图书馆', '走廊', '教室'];
    
    final house = houses[_random.nextInt(houses.length)];
    final personality = personalities[_random.nextInt(personalities.length)];
    final location = locations[_random.nextInt(locations.length)];
    final grade = 1 + _random.nextInt(7);  // 1-7年级
    
    return NPC(
      id: id,
      name: name,
      house: house,
      grade: grade,
      bloodStatus: 'unknown',
      isCanon: false,
      isGenerated: true,
      personality: [personality],
      currentLocation: location,
      mood: 50 + _random.nextInt(30) - 15,
      affection: 0,
      introduced: true,
      lifeLog: ['$name 出现在霍格沃茨'],
      recentEvents: ['$name 首次登场'],
    );
  }

  /// 判断 name 在 text 中是否以「独立词」出现（前后被标点/空格/行边界包围，
  /// 而不是嵌在更长的词组里）
  static bool _standaloneNameMentioned(String text, String name) {
    bool isBoundary(int charCode) {
      if (charCode == 0) return true; // 虚拟位置
      // CJK Unified Ideographs 基本区 + 扩展 A
      if (charCode >= 0x4E00 && charCode <= 0x9FFF) return false;
      if (charCode >= 0x3400 && charCode <= 0x4DBF) return false;
      // 字母（含全角）、数字
      if ((charCode >= 0x41 && charCode <= 0x5A) ||
          (charCode >= 0x61 && charCode <= 0x7A) ||
          (charCode >= 0xFF21 && charCode <= 0xFF3A) ||
          (charCode >= 0xFF41 && charCode <= 0xFF5A) ||
          (charCode >= 0x30 && charCode <= 0x39) ||
          (charCode >= 0xFF10 && charCode <= 0xFF19)) return false;
      // 点·/-下划线等连接符（中间名、外国人姓氏连字符）
      if (charCode == 0x00B7 || charCode == 0x2022 ||
          charCode == 0x2D || charCode == 0x5F) return false;
      return true;
    }

    int idx = 0;
    while (true) {
      idx = text.indexOf(name, idx);
      if (idx == -1) return false;
      final before = idx == 0 ? 0 : text.codeUnitAt(idx - 1);
      final after = idx + name.length >= text.length
          ? 0
          : text.codeUnitAt(idx + name.length);
      if (isBoundary(before) && isBoundary(after)) return true;
      idx += name.length;
    }
  }

  String _calculateBirthYear() {
    // 入学时11岁：出生年份 = 时代入学年份 - 11
    return (_startYearForEra(appProvider.era) - 11).toString();
  }

  /// 时代对应的入学年份（游戏开始年份）
  int _startYearForEra(Era era) {
    return switch (era) {
      Era.dumbledore => 1892,
      Era.marauders => 1971,
      Era.first_war => 1976,
      Era.harry_same => 1991,
      Era.post_war => 2020,
      Era.random => 1991,
    };
  }

  // ==================== 开局特质抽取（软保底） ====================

  /// 抽取 3 个开局特质，稀有度软保底
  List<TraitDef> _rollStartingTraits() {
    final byRarity = traitsByRarity();
    final commons = byRarity['common'] ?? [];
    final rares = byRarity['rare'] ?? [];
    final legendaries = byRarity['legendary'] ?? [];

    final picked = <TraitDef>[];
    final usedIds = <String>{};
    int pity = 0; // 连续未出稀有/传说的次数

    while (picked.length < 3) {
      // 软保底：连续未出高稀有度时提升概率
      final pityBoost = (pity ~/ TraitRarityWeights.pityThreshold) * TraitRarityWeights.pityBonus;
      final legendaryP = TraitRarityWeights.legendaryBase + pityBoost * 0.5;
      final rareP = TraitRarityWeights.rareBase + pityBoost;

      final roll = _random.nextDouble();
      String rarity;
      if (roll < legendaryP && legendaries.isNotEmpty) {
        rarity = 'legendary';
      } else if (roll < legendaryP + rareP && rares.isNotEmpty) {
        rarity = 'rare';
      } else {
        rarity = 'common';
      }

      final pool = switch (rarity) {
        'legendary' => legendaries,
        'rare' => rares,
        _ => commons,
      };
      final available = pool.where((t) => !usedIds.contains(t.id)).toList();
      if (available.isEmpty) {
        // 该稀有度已抽完，回退到普通
        final fallback = commons.where((t) => !usedIds.contains(t.id)).toList();
        if (fallback.isEmpty) break;
        final t = fallback[_random.nextInt(fallback.length)];
        picked.add(t);
        usedIds.add(t.id);
        continue;
      }

      final trait = available[_random.nextInt(available.length)];
      picked.add(trait);
      usedIds.add(trait.id);
      if (rarity == 'common') {
        pity++;
      } else {
        pity = 0;
      }
    }
    return picked;
  }

  /// 应用特质属性加成
  void _applyTraitBonuses(List<TraitDef> traits) {
    final p = _player;
    if (p == null) return;
    for (final t in traits) {
      t.attributeBonus.forEach((key, bonus) {
        // energy/health 等是顶层字段，attributes 是技能属性
        switch (key) {
          case 'energy':
            p.energy = (p.energy + bonus).clamp(0, 100);
            break;
          case 'health':
            p.health = (p.health + bonus).clamp(0, 100);
            break;
          case 'moral':
            p.playerReputation.add('moral', bonus);
            break;
          case 'spirit':
            p.spirit = (p.spirit + bonus).clamp(0, 100);
            break;
          case 'social':
            // social 既是属性也是声望，这里加到属性
            p.attributes['social'] = ((p.attributes['social'] ?? 50) + bonus).clamp(0, 100);
            break;
          default:
            p.attributes[key] = ((p.attributes[key] ?? 50) + bonus).clamp(0, 100);
        }
      });
      // 节俭特质：初始加隆略多
      if (t.id == 'thrifty') {
        p.galleons += 100;
      }
    }
    if (traits.isNotEmpty) {
      _notifications.add('✨ 你获得了特质：${traits.map((t) => t.name).join('、')}');
    }
  }

  /// 特质叙事提示（注入系统提示词）
  String _traitNarrativeHints() {
    final p = _player;
    if (p == null || p.traits.isEmpty) return '';
    final hints = p.traits
        .map((id) => traitById(id))
        .where((t) => t != null && t.narrativeHint.isNotEmpty)
        .map((t) => t!.narrativeHint)
        .toList();
    if (hints.isEmpty) return '';
    return '【出身特质】${hints.join('；')}';
  }

  

  // ==================== 生成开场场景 ====================
  Future<void> _generateOpeningScene() async {
    if (_player == null) return;

    final p = _player!;
    final wandData = p.wandId != null ? wandById(p.wandId!) : null;
    final wandInfo = wandData != null
        ? '${wandData.name}（${wandData.wood}·${wandData.core}·${wandData.length}）'
        : '尚未选择的魔杖';

    final petInfo = _buildPetDescriptionShort(p);
    final startPoint = _buildStartPointNarrative();

    // 只收集已设定字段，减少 token 噪声
    final profile = <String>[];
    profile.add('姓名：${p.name}｜11岁｜${_bloodStatusLabel(p.bloodType)}｜${p.birthLocation}');
    if (p.personalityTraits.isNotEmpty) profile.add('性格：${p.personalityTraits.join('、')}');
    if (p.birthIdentity != null && p.birthIdentity!.isNotEmpty) profile.add('出身：${p.birthIdentity}');
    if (p.appearance != null && p.appearance!.isNotEmpty) profile.add('外貌：${p.appearance}');
    if (p.familyBackground != null && p.familyBackground!.isNotEmpty) profile.add('家族：${p.familyBackground}');
    if (p.childhoodExperiences.isNotEmpty) profile.add('童年：${p.childhoodExperiences.join('；')}');
    if (p.beliefs != null && p.beliefs!.isNotEmpty) profile.add('信念：${p.beliefs}');
    if (p.magicAptitude != null && p.magicAptitude!.isNotEmpty) profile.add('资质：${p.magicAptitude}');
    if (p.initialTalent != null && p.initialTalent!.isNotEmpty) profile.add('天赋：${p.initialTalent}');
    if (p.housePreference != null && p.housePreference!.isNotEmpty) profile.add('学院倾向：${p.housePreference}');
    if (p.traits.isNotEmpty) {
      final traitNames = p.traits
          .map((id) => traitById(id)?.name)
          .where((n) => n != null)
          .join('、');
      if (traitNames.isNotEmpty) profile.add('出身特质：$traitNames');
    }
    profile.add('时代：${_eraLabelShort(appProvider.era)}');
    profile.add('魔杖：$wandInfo');
    profile.add('宠物：$petInfo');

    final prompt = '''【开场叙事】J.K.罗琳风格，3+感官细节。

【玩家资料】
${profile.join('｜')}

【起始场景】$startPoint

【要求】500-600字，📅时间戳开头，自然融入魔杖/宠物/血统，体现性格，要有具体场景和事件，避免空洞描述。

【格式】
【叙事】（正文）
【可选行动】A/B/C（具体）
【自由行动】''';

    if (_router == null || !_router!.hasNarrativeService) {
      _currentNarrative =
          '${p.name}，你在${p.birthLocation}长大，等待来自霍格沃茨的信已经等了很久。\n\n📅 ${_worldState.timestamp}\n\n魔法世界的大门即将为你打开。';
      _choices = [
        GameChoice(text: '等待猫头鹰送来的信', action: '等待猫头鹰送来的信'),
        GameChoice(text: '收拾行李，准备出发', action: '收拾行李，准备出发'),
        GameChoice(text: '再检查一遍霍格沃茨的入学清单', action: '再检查一遍霍格沃茨的入学清单'),
      ];
      _appendRecentTurn(_currentNarrative);
      return;
    }

    try {
      final response = await _callDeepSeek(prompt);
      _parseResponse(response.content);
      _accumulateForSummary(_currentNarrative);
      _appendRecentTurn(_currentNarrative);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _currentNarrative =
          '${p.name}，故事即将开始。请稍候，魔法正在酝酿。';
      _choices = [GameChoice(text: '继续', action: '继续')];
      _appendRecentTurn(_currentNarrative);
      notifyListeners();
      unawaited(CrashLogger.instance.record(
        e,
        StackTrace.current,
        screen: 'generateOpeningScene',
        extra: 'player=${p.name}, era=${appProvider.era.name}',
      ));
    }
  }

  // ==================== 开场辅助：宠物描述（短版，省token） ====================
  String _buildPetDescriptionShort(Player p) {
    final petId = p.petId;
    final petName = p.petName ?? '';
    if (petId == null) return '未饲养';
    switch (petId) {
      case 'owl': return '$petName（猫头鹰·聪明忠诚）';
      case 'cat': return '$petName（猫·神秘敏感）';
      case 'toad': return '$petName（蟾蜍·传统伴侣）';
      case 'rat': return '$petName（老鼠·机灵小巧）';
      case 'kyuubi': return '绯月（九尾灵狐·东方青丘祥瑞，可化人形·幻术/灵视·完全效忠）';
      default: return '$petName（特殊伙伴）';
    }
  }

  // ==================== 开场辅助：剧情起点 ====================
  String _buildStartPointNarrative() {
    switch (_openingScene) {
      case 'letter':
        return '故事从你收到霍格沃茨录取通知书的那一刻开始——那只迟来的猫头鹰终于叩响了你的窗。';
      case 'station':
        return '故事从你站在九又四分之三站台前开始——蒸汽火车冒着白烟等待着你。';
      case 'hall':
        return '故事从你第一次踏入霍格沃茨大礼堂开始——金色的烛光在长桌上方摇曳。';
      case 'eve':
        return '故事从分院仪式前夜开始——你躺在床上翻来覆去，想着明天会被分到哪个学院。';
      default:
        return '故事从你站在九又四分之三站台前开始——蒸汽火车冒着白烟等待着你。';
    }
  }

  // ==================== 处理选择 / 指令 ====================
  Future<void> processChoice(GameChoice choice) async {
    if (_player == null) return;

    // 本地指令解析
    final action = choice.action.trim();
    if (action.startsWith('/')) {
      final handled = _handleLocalCommand(action);
      if (handled) {
        notifyListeners();
        _autoSave();
        return;
      }
    }

    // 用户自由文本在进入 Prompt 前做注入防御净化
    final safeAction = PromptSanitizer.sanitizeAction(action);

    if (_router == null || !_router!.hasNarrativeService) return;

    _isLoading = true;
    _turnCount++;
    _lastPlayerAction = safeAction;
    _loadingStage = '正在构建请求...';
    notifyListeners();

    String buildPrompt() {
      final p = _player!;

      final contextBuffer = StringBuffer();
      if (_narrativeSummary.isNotEmpty) {
        // 关键改进：明确标注前情摘要是"历史背景"，不要基于此生成选项
        contextBuffer.write('【历史背景（仅作参考，不要基于此生成当前场景的选项）】\n$_narrativeSummary\n\n');
      }

      final currentLoc = _worldState.currentLocation ?? '';
      final filteredTurns = <String>[];
      for (int i = _recentTurns.length - 1; i >= 0; i--) {
        final entry = _recentTurns[i];
        filteredTurns.insert(0, entry);
        if (filteredTurns.length >= 3) break;
      }
      final recentBuffer = filteredTurns.isNotEmpty
          ? filteredTurns.join('\n\n')
          : _currentNarrative;
      final recent = _truncateNarrativeContext(recentBuffer, 1600);
      // 关键改进：明确标注近期剧情是"当前场景上下文"，选项必须基于此
      contextBuffer.write('【当前场景上下文（以此生成选项）】\n$recent');

      final context = contextBuffer.toString();
      final statusTag = _buildStatusTag(p);
      final extra = _buildCriticalContext(safeAction);
      final sceneInfo = _buildSceneContext();

      // 事件锚点注入：手写剧情骨架，保证关键节点在正确时间发生
      final anchorLine = _pendingAnchorDirective != null
          ? '【剧情节点】本回合请自然融入以下既定剧情骨架（不必生硬转折，可结合玩家行动展开）：\n$_pendingAnchorDirective\n\n'
          : '';

      return '''【世界上下文】
$context

${statusTag.isNotEmpty ? '【状态】$statusTag\n' : ''}
【当前场景】${_worldState.timestamp}｜${_worldState.currentLocation ?? '未知'}
$sceneInfo

$anchorLine${extra.isNotEmpty ? extra + '\n' : ''}【玩家行动】
$safeAction

【重要规则】
- 选项将由独立步骤生成，本回合只需生成叙事和好感变化
- 确保叙事符合当前地点（${_worldState.currentLocation ?? '未知'}）和当前时间（${_worldState.timestamp}）

【写作要求】
- 叙事:500-800字小说正文，融入感官细节、对话、心理、环境描写，分3-5段用空行分隔，严禁结构化标签或序号
- 剧情要有实际进展和转折，避免无意义的日常描述
- 好感:NPC名±X(原因)，独立成段，可多条
- 不需要生成选项，选项将在下一步单独生成
''';
    }

    try {
      final prompt = buildPrompt();
      // 记录本回合实际注入的锚点（推进时间后可能产生新锚点，不能误清）
      final consumedAnchor = _pendingAnchorDirective;
      _loadingStage = '正在生成剧情...';
      notifyListeners();

      String response;
      try {
        response = (await _callDeepSeek(prompt)).content;
      } on AiNonRetryableException {
        rethrow;
      } catch (e) {
        _loadingStage = '请求失败，正在重试...';
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 500));
        response = (await _callDeepSeek(prompt)).content;
      }

      _loadingStage = '正在解析剧情...';
      notifyListeners();

      // 先解析叙事文本（不含选项）
      _parseNarrativeOnly(response);

      // 如果叙事解析失败，回退到完整解析
      if (_currentNarrative.isEmpty) {
        _parseResponse(response);
      }

      // 独立生成选项：基于已生成的剧情
      _loadingStage = '正在生成选项...';
      notifyListeners();

      final separateChoices = await _generateChoicesSeparately(_currentNarrative);

      if (separateChoices.isNotEmpty) {
        // 使用独立生成的选项
        _choices = separateChoices;
      } else {
        // 独立生成失败，尝试从原始响应中提取
        _parseResponse(response);
        // 如果还是空，使用兜底选项
        if (_choices.isEmpty) {
          _choices = _extractChoicesFromRawText(response);
          if (_choices.isEmpty) {
            _choices = _generateContextualFallbackChoices();
          }
        }
      }

      _accumulateForSummary(_currentNarrative);
      _appendRecentTurn(_currentNarrative);
      _advanceTimeForAction(action);
      _updateNPCsFromAction(action);
      _updatePlayerImpactScore(action);
      // 锚点已成功注入本回合剧情，清除待注入状态（仅当未被新锚点替换时）
      if (consumedAnchor != null && _pendingAnchorDirective == consumedAnchor) {
        _pendingAnchorDirective = null;
      }

      // 定期摘要：每10回合，或待摘要缓冲过长（>3000字）时提前压缩，控制单次摘要输入规模
      if ((_turnCount % 10 == 0 || _pendingSummary.length > 3000) && _pendingSummary.isNotEmpty) {
        unawaited(Future.microtask(() async {
          try {
            await _summarizeNarrative();
          } catch (e) {
            debugPrint('摘要生成失败(不影响游戏): $e');
          }
        }));
      }

      _loadingStage = '';
      _isLoading = false;
      notifyListeners();
      _autoSave();
    } catch (e) {
      // AI 全部提供商不可用时的本地兜底：给出过渡剧情与选项，保证游戏不卡死
      debugPrint('❌ 剧情生成失败，启用本地兜底叙事: $e');
      _currentNarrative = _generateFallbackNarrative();
      _choices = _generateContextualFallbackChoices();
      _appendRecentTurn(_currentNarrative);
      _notifications.add('⚠️ AI 服务暂时不可用，已切换为本地过渡剧情，稍后可重试行动');
      _loadingStage = '';
      _isLoading = false;
      notifyListeners();
      _autoSave();
      unawaited(CrashLogger.instance.record(
        e,
        StackTrace.current,
        screen: 'processChoice',
        extra: 'action=$action, turn=$_turnCount',
      ));
    }
  }

  /// 本地指令解析（设定文档第X部分指令系统）
  bool _handleLocalCommand(String command) {
    final p = _player;
    if (p == null) return false;
    final parts = command.split(RegExp(r'\s+'));
    final cmd = parts[0];

    switch (cmd) {
      case '/状态':
        _currentNarrative = _formatStatus();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/时间':
        _currentNarrative = _formatTime();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/地图':
        _currentNarrative = _formatMap();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/通知':
        _currentNarrative = _formatNotifications();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/帮助':
        _currentNarrative = _formatHelp();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/关系':
        _currentNarrative = _formatRelationships();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/恋爱':
        _currentNarrative = _formatLove();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/声望':
        _currentNarrative = _formatReputation();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/舆论':
      case '/传闻':
        _currentNarrative = _formatRumors();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/课程':
        _currentNarrative = _formatCourses();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/课堂':
        if (parts.length >= 2 && parts[1] == '互动') {
          _classroomInteraction();
        } else {
          _currentNarrative = '【课堂互动】\n输入 /课堂 互动 触发当前课堂的互动环节（教授提问、实践练习、同桌互动、随机意外）。\n\n当前课表见 /课程。';
          _choices = [GameChoice(text: '返回', action: '继续')];
        }
        return true;

      case '/收藏':
        _currentNarrative = _formatCollection();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/日记':
        if (parts.length >= 2 && parts[1] == '统计') {
          _currentNarrative = _formatDiaryStats();
        } else if (parts.length >= 3 && parts[1] == '重播') {
          _currentNarrative = _replayCg(parts[2]);
        } else if (parts.length >= 2) {
          _currentNarrative = _formatCgDetail(parts[1]);
        } else {
          _currentNarrative = _formatDiary();
        }
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/档案':
        _currentNarrative = _formatArchive();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/成就':
        _currentNarrative = _formatAchievements();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/宠物':
        _currentNarrative = _formatPet();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/信':
        _handleLetterCommand(parts);
        return true;

      case '/血缘':
        _currentNarrative = _formatBloodRelatives();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/联动':
        _currentNarrative = '【联动系统】\n当前时代：${_eraLabel(appProvider.era)}\n'
            '联动系统允许你在特定节点与其他时代剧情产生关联（例如在子世代时遇到亲世代留下的物品或信件）。\n'
            '当前已触发的联动痕迹：\n${_worldState.timelineBranches.isEmpty ? '暂无。' : _worldState.timelineBranches.map((b) => '· $b').join('\n')}';
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/世界演化':
        _currentNarrative = _formatWorldEvolution();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/新NPC':
        _generateNewNPC();
        return true;

      case '/恋爱等待':
      case '/恋爱 等待':
        _currentNarrative = _formatLoveWaiting();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/恋爱阶段':
        _currentNarrative = _formatLoveStages();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/关系网络':
      case '/关系 网络':
        if (parts.length >= 4) {
          _currentNarrative = _formatNpcRelationship(parts[2], parts[3]);
        } else {
          _currentNarrative = '请输入两位NPC的名字：/关系网络 [NPC1] [NPC2]';
        }
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/骨科':
      case '/骨科状态':
        _currentNarrative = _formatBoneMode();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/目标':
        if (parts.length >= 2 && (parts[1] == '进度' || parts[1] == 'progress')) {
          _currentNarrative = _formatGoalProgress();
          _choices = [GameChoice(text: '返回', action: '继续')];
          return true;
        }
        if (parts.length >= 2) {
          final arg = parts.sublist(1).join(' ');
          LifeGoal? goal;
          final idx = int.tryParse(arg);
          if (idx != null && idx >= 1 && idx <= lifeGoalCatalog.length) {
            goal = lifeGoalCatalog[idx - 1];
          } else {
            goal = goalById(arg) ?? goalByName(arg);
          }
          if (goal != null) {
            p.currentGoal = goal.name;
            _currentNarrative = '✅ 已设定人生目标：${goal.name}\n'
                '『${goal.description}』\n\n'
                '这条目标将牵引后续剧情方向，但你仍可自由行动。\n'
                '输入 /目标 可重新查看或更换。';
          } else {
            _currentNarrative = '未找到目标"$arg"。输入 /目标 查看全部目标。';
          }
        } else {
          _currentNarrative = _formatGoals();
        }
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/结局':
      case '/终章':
        _startEndingSequence();
        return true;

      case '/cheat':
        _handleCheat(parts);
        return true;
    }
    return false;
  }

  // ==================== 作弊指令（设定 8.1-8.5） ====================
  void _handleCheat(List<String> parts) {
    final p = _player;
    if (p == null) return;
    if (parts.length < 2) {
      _currentNarrative = _formatCheatHelp();
      _choices = [GameChoice(text: '返回', action: '继续')];
      return;
    }
    final sub = parts[1];

    switch (sub) {
      case '好感':
      case 'affection':
        if (parts.length >= 4) {
          final nameKey = parts[2];
          NPC? npc;
          for (final n in _npcRegistry.values) {
            if (n.name.contains(nameKey)) { npc = n; break; }
          }
          npc ??= _npcRegistry[nameKey];
          if (npc == null) {
            final allNames = _npcRegistry.values.map((n) => n.name).join('、');
            _currentNarrative = '未找到NPC "$nameKey"。可用：$allNames';
            break;
          }
          final delta = int.tryParse(parts[3]);
          if (delta != null) {
            npc.affection = (npc.affection + delta).clamp(-100, 100);
            _currentNarrative = '已调整「${npc.name}」的好感度：${npc.affection}（${npc.affectionStage}）';
          }
        }
        break;

      case '资源':
      case 'resources':
        if (parts.length >= 4) {
          final amount = int.tryParse(parts[2]) ?? 0;
          switch (parts[3]) {
            case '魔力':
            case 'mp':
              p.magic = (p.magic + amount).clamp(0, 100);
              break;
            case '精神力':
            case 'sp':
              p.spirit = (p.spirit + amount).clamp(0, 100);
              break;
            case '饱食':
            case 'sat':
              p.satiety = (p.satiety + amount).clamp(0, 100);
              break;
            case '精力':
            case 'energy':
              p.energy = (p.energy + amount).clamp(0, 100);
              break;
            case '生命':
            case 'hp':
              p.health = (p.health + amount).clamp(0, 100);
              break;
          }
          _currentNarrative = '资源已调整。';
        }
        break;

      case '声望':
      case 'reputation':
        if (parts.length >= 4) {
          final amount = int.tryParse(parts[2]) ?? 0;
          p.playerReputation.add(parts[3], amount);
          _currentNarrative =
              '${p.playerReputation.labelOf(parts[3])} ${p.playerReputation.get(parts[3])}';
        }
        break;

      case '时间':
      case 'time':
        if (parts.length >= 3) {
          final days = int.tryParse(parts[2]);
          if (days != null) _fastForwardTime(days);
          _currentNarrative = '时间已推进 $days 天。\n${_worldState.timestamp}';
        }
        break;

      case '骨科':
        if (parts.length >= 3 && parts[2] == '无视') {
          p.boneMode = true;
          _currentNarrative =
              '【骨科模式已开启】三代内血亲的禁忌限制已解除，但这意味着你的选择将付出更沉重的代价。';
        } else {
          _currentNarrative = '使用方式：/cheat 骨科 无视（开启骨科模式）';
        }
        break;

      case '舆论':
      case 'rumor':
        if (parts.length >= 3 && parts[2] == '重置') {
          p.rumors.clear();
          _currentNarrative = '已清除所有舆论传闻。';
        } else if (parts.length >= 4 && parts[2] == '清除') {
          final key = parts.sublist(3).join(' ');
          final before = p.rumors.length;
          p.rumors.removeWhere((r) => r.contains(key));
          _currentNarrative = '已清除 ${before - p.rumors.length} 条相关传闻。';
        } else {
          _currentNarrative = '使用方式：/cheat 舆论 清除 <关键词> 或 /cheat 舆论 重置';
        }
        break;

      case '解锁CG':
      case 'cg':
        if (parts.length >= 3) {
          final cg = cgById(parts[2]);
          if (cg != null) {
            _unlockCG(cg);
            _currentNarrative = '已解锁 CG：${cg.name}';
          } else {
            _currentNarrative = '未找到该 CG，可用：${allCgs().map((c) => c.id).take(10).join(', ')}...';
          }
        }
        break;

      default:
        _currentNarrative = _formatCheatHelp();
    }
    _choices = [GameChoice(text: '返回', action: '继续')];
  }

  String _formatCheatHelp() {
    return '''【作弊指令】
/cheat 好感 <NPC名> <数值>  — 调整好感度
/cheat 资源 <数值> <魔力|精神力|饱食|精力|生命>
/cheat 声望 <数值> <academic|social|combat|moral|leadership|dark>
/cheat 时间 <天数>
/cheat 骨科 无视 — 开启骨科模式
/cheat 舆论 清除 <关键词> — 清除相关传闻
/cheat 舆论 重置 — 清空所有传闻
/cheat 解锁CG <CG编号> — 解锁指定CG''';
  }

  // ==================== 生成新NPC（增强版：多人格+多样化） ====================
  void _generateNewNPC() {
    final p = _player;
    if (p == null) return;

    final count = _npcRegistry.values.where((n) => n.isGenerated).length;
    if (count >= 4) {
      _currentNarrative = '新NPC数量已达到上限（每学年最多新增4位）。';
      _choices = [GameChoice(text: '返回', action: '继续')];
      return;
    }

    final surnames = [
      '布莱克', '隆巴顿', '洛夫古德', '迪戈里', '波特', '马尔福',
      '沙比尼', '韦斯莱', '克鲁姆', '安德森', '塞尔温', '罗斯',
      '阿什福德', '格雷', '芬尼甘', '博恩斯', '艾博', '普莱斯',
    ];
    final givenMale = [
      '西奥多', '塞巴斯蒂安', '艾德里安', '卡斯珀', '伊万', '诺亚',
      '奥利弗', '利奥', '马库斯', '朱利安', '塞缪尔', '内森',
    ];
    final givenFemale = [
      '塞西莉亚', '艾拉', '薇奥拉', '罗莎琳', '埃洛伊斯', '伊莎贝拉',
      '莉莉安', '海伦娜', '卡珊德拉', '奥利维亚', '克洛伊', '斯嘉丽',
    ];

    final houseNames = {
      'Gryffindor': '格兰芬多',
      'Slytherin': '斯莱特林',
      'Ravenclaw': '拉文克劳',
      'Hufflepuff': '赫奇帕奇',
    };

    final personalityTemplates = <String, List<String>>{
      '勇敢型': ['勇敢', '直率', '热情', '正义'],
      '智慧型': ['理性', '聪明', '好奇', '独立'],
      '温柔型': ['善良', '温柔', '体贴', '细腻'],
      '野心型': ['野心', '精明', '果断', '领导'],
      '忠诚型': ['忠诚', '正直', '勤勉', '耐心'],
      '神秘型': ['神秘', '内敛', '深沉', '敏感'],
      '幽默型': ['幽默', '乐观', '热情', '善于交际'],
      '叛逆型': ['叛逆', '独立', '直率', '挑战权威'],
    };

    final appearanceTemplates = <String, List<String>>{
      'Gryffindor': [
        '红棕色的头发在风中微扬，绿色的眼睛里闪着热情的光芒',
        '高大挺拔，肩膀宽阔，笑容明亮而坦荡',
        '一头金色的短发，脸上有几颗雀斑，眼神坚定',
      ],
      'Slytherin': [
        '乌黑的长发披在肩上，眼睛是深邃的灰绿色',
        '身材修长，举手投足间带着一种与生俱来的优雅',
        '皮肤苍白，深色的眼睛里藏着不易察觉的心思',
      ],
      'Ravenclaw': [
        '一头凌乱的棕色卷发，戴着一副圆形眼镜',
        '目光锐利而充满好奇，总是在观察着周围的一切',
        '纤细的身影，眼神中带着几分聪慧的狡黠',
      ],
      'Hufflepuff': [
        '棕色的直发垂到肩际，笑容温暖而真诚',
        '体格健壮，给人踏实可靠的感觉',
        '圆圆的脸蛋，金色的眼睛里满是善意',
      ],
    };

    final isMale = _random.nextBool();
    final givenNames = isMale ? givenMale : givenFemale;
    final name = '${givenNames[_random.nextInt(givenNames.length)]}·${surnames[_random.nextInt(surnames.length)]}';
    final houses = ['Gryffindor', 'Slytherin', 'Ravenclaw', 'Hufflepuff'];
    final house = houses[_random.nextInt(houses.length)];
    final id = 'generated_${DateTime.now().millisecondsSinceEpoch}';
    final grade = p.grade ?? 1;

    final archetypes = personalityTemplates.keys.toList();
    final archetype = archetypes[_random.nextInt(archetypes.length)];
    final personality = List<String>.from(personalityTemplates[archetype] ?? ['友善', '独立']);
    final appearanceDesc = (appearanceTemplates[house] ?? ['面容清秀，眼神里带着好奇'])[_random.nextInt((appearanceTemplates[house] ?? ['面容清秀，眼神里带着好奇']).length)];
    final houseLabel = houseNames[house] ?? house;

    final orientationOptions = [p.sexOrientation ?? '女', '男', '女'];
    orientationOptions.removeWhere((e) => e == p.sexOrientation);
    final sexOrientation = orientationOptions[_random.nextInt(orientationOptions.length)];

    final npc = NPC(
      id: id,
      name: name,
      house: house,
      grade: grade,
      bloodStatus: 'unknown',
      personality: personality,
      appearance: '$appearanceDesc。这位$houseLabel的${isMale ? '男生' : '女生'}，属于$archetype气质。',
      sexOrientation: sexOrientation,
      mood: _roll(40, 70),
      affection: _roll(5, 15),
      isGenerated: true,
      generatedProfile: '$archetype气质｜$houseLabel｜${isMale ? '男' : '女'}生｜与你同年级',
      giftPrefs: _generateGiftPrefs(archetype),
      personalGoal: _generatePersonalGoal(archetype, house),
      schedule: _generateNpcSchedule(house, grade),
      knowsAbout: _generateKnownFacts(archetype),
      reputation: _generateNpcReputation(archetype, house),
    );

    _npcRegistry[id] = npc;
    p.relationships[id] = Relationship(
      targetId: id,
      targetName: name,
      relationType: '同学',
      level: 10,
    );
    _notifications.add('📬 新同学加入了你的圈子：$name（$archetype）');
    _currentNarrative =
        '一位新的同学出现在霍格沃茨的走廊里——$name，来自$houseLabel学院。\n\n'
        '$appearanceDesc。从他/她的言行举止来看，这是一位$archetype气质的人。\n\n'
        '${_generateNpcBackstoryFlavor(archetype, isMale, house)}\n\n'
        '也许你们会有一段值得书写的故事。';
    _choices = [
      GameChoice(text: '上前与$name打招呼', action: '上前与$name打招呼'),
      GameChoice(text: '保持距离，暗中观察', action: '保持距离，暗中观察'),
      GameChoice(text: '请$name帮个小忙', action: '请$name帮个小忙'),
    ];

    _checkGenerationArtistAchievement();
  }

  Map<String, int> _generateGiftPrefs(String archetype) {
    switch (archetype) {
      case '勇敢型':
        return {'魁地奇徽章': 8, '勇气勋章': 6, '巧克力蛙': 2};
      case '智慧型':
        return {'旧书': 8, '羽毛笔': 5, '巧克力蛙': 2};
      case '温柔型':
        return {'花束': 7, '手写贺卡': 5, '巧克力蛙': 3};
      case '野心型':
        return {'计划书': 7, '银色钢笔': 6, '巧克力蛙': 2};
      case '忠诚型':
        return {'编织围巾': 8, '自制点心': 5, '巧克力蛙': 3};
      case '神秘型':
        return {'神秘符号': 8, '魔法道具': 6, '巧克力蛙': 2};
      case '幽默型':
        return {'恶作剧玩具': 7, '笑话集': 5, '巧克力蛙': 3};
      case '叛逆型':
        return {'朋克饰品': 8, '摇滚专辑': 6, '巧克力蛙': 2};
      default:
        return {'巧克力蛙': 2};
    }
  }

  String? _generatePersonalGoal(String archetype, String house) {
    final goals = <String, List<String>>{
      '勇敢型': ['成为魁地奇队长', '证明自己的勇气', '保护身边的朋友'],
      '智慧型': ['解开一个古老的魔法谜题', '成为级长', '研究禁忌咒文'],
      '温柔型': ['治愈所有受伤的生物', '建立一个温暖的朋友圈', '守护一段珍贵的友谊'],
      '野心型': ['成为学生会主席', '掌握高阶黑魔法防御术', '建立自己的魔法家族'],
      '忠诚型': ['为学院赢得学院杯', '成为朋友最可靠的依靠', '守护家族的荣誉'],
      '神秘型': ['探索霍格沃茨的秘密', '理解自己的魔法天赋', '找到传说中的密室'],
      '幽默型': ['成为霍格沃茨的笑话大王', '让所有人都开怀大笑', '发明新的恶作剧道具'],
      '叛逆型': ['打破陈规', '证明传统可以被挑战', '追随自己的道路'],
    };
    final houseGoals = <String, List<String>>{
      'Gryffindor': ['赢得魁地奇冠军', '成为格兰芬多的骄傲'],
      'Slytherin': ['在斯莱特林出人头地', '成为最优秀的蛇院学生'],
      'Ravenclaw': ['解开图书馆的秘密', '拉文克劳最聪明的学生'],
      'Hufflepuff': ['证明赫奇帕奇的价值', '成为最努力工作的学生'],
    };
    final pool = <String>[];
    pool.addAll(goals[archetype] ?? []);
    pool.addAll(houseGoals[house] ?? []);
    if (pool.isEmpty) return null;
    return pool[_random.nextInt(pool.length)];
  }

  Map<String, String> _generateNpcSchedule(String house, int grade) {
    final schedules = <String, Map<String, String>>{
      'Gryffindor': {
        '早晨': '在魁地奇训练场练习',
        '上午': '在教室里认真听讲',
        '下午': '在格兰芬多公共休息室休息',
        '晚上': '在图书馆查阅魁地奇战术',
      },
      'Slytherin': {
        '早晨': '在黑魔法防御术教室',
        '上午': '在魔药课实验室',
        '下午': '在斯莱特林公共休息室',
        '晚上': '在有求必应屋学习',
      },
      'Ravenclaw': {
        '早晨': '在图书馆占座',
        '上午': '在教室积极发言',
        '下午': '在天文塔观察星象',
        '晚上': '在图书馆研读古籍',
      },
      'Hufflepuff': {
        '早晨': '在厨房准备早餐',
        '上午': '在草药课温室',
        '下午': '在赫奇帕奇公共休息室',
        '晚上': '在厨房帮家养小精灵',
      },
    };
    return schedules[house] ?? {
      '早晨': '在教室',
      '上午': '在上课',
      '下午': '在公共休息室',
      '晚上': '在图书馆',
    };
  }

  List<String> _generateKnownFacts(String archetype) {
    final facts = <String, List<String>>{
      '勇敢型': ['听说过禁林的传说', '知道如何找到秘密通道', '认识魁地奇队的人'],
      '智慧型': ['读过大部分图书馆的书', '知道一些古老的咒语', '对霍格沃茨的历史很了解'],
      '温柔型': ['知道谁需要帮助', '了解霍格沃茨的家养小精灵', '认识医院的护士'],
      '野心型': ['了解魔法部的运作', '知道哪些教授有影响力', '认识一些高年级学生'],
      '忠诚型': ['知道如何让朋友开心', '了解每个同学的喜好', '认识所有家养小精灵的名字'],
      '神秘型': ['听说过密室的传说', '知道一些不为人知的咒语', '对霍格沃茨的秘密很感兴趣'],
      '幽默型': ['知道所有恶作剧的秘密', '认识弗雷德和乔治的粉丝', '了解霍格沃茨的笑话'],
      '叛逆型': ['知道哪些规则可以打破', '了解有求必应屋的秘密', '认识一些反叛的学生'],
    };
    return facts[archetype] ?? ['知道一些校园的小秘密'];
  }

  Reputation _generateNpcReputation(String archetype, String house) {
    final rep = Reputation();
    switch (archetype) {
      case '勇敢型':
        rep.setValue('combat', _roll(40, 70));
        rep.setValue('moral', _roll(30, 60));
        break;
      case '智慧型':
        rep.setValue('academic', _roll(50, 80));
        rep.setValue('dark', _roll(10, 30));
        break;
      case '温柔型':
        rep.setValue('moral', _roll(50, 80));
        rep.setValue('social', _roll(40, 70));
        break;
      case '野心型':
        rep.setValue('leadership', _roll(40, 70));
        rep.setValue('dark', _roll(20, 50));
        break;
      case '忠诚型':
        rep.setValue('moral', _roll(50, 75));
        rep.setValue('social', _roll(35, 65));
        break;
      case '神秘型':
        rep.setValue('dark', _roll(30, 60));
        rep.setValue('academic', _roll(30, 60));
        break;
      case '幽默型':
        rep.setValue('social', _roll(50, 80));
        break;
      case '叛逆型':
        rep.setValue('dark', _roll(40, 70));
        rep.setValue('combat', _roll(30, 60));
        break;
      default:
        rep.setValue('social', _roll(30, 60));
    }
    return rep;
  }

  String _generateNpcBackstoryFlavor(String archetype, bool isMale, String house) {
    final prefix = isMale ? '他' : '她';
    final flavors = <String, List<String>>{
      '勇敢型': [
        '$prefix的父亲曾是${house}的魁地奇队长，$prefix从小就梦想着继承这份荣耀。',
        '据说$prefix在二年级时就独自面对过一只博格特，展现了超乎年龄的勇气。',
        '$prefix总是第一个冲入危险的人，朋友们常常担心$prefix的安全。',
      ],
      '智慧型': [
        '$prefix在入学前就已经读完了大部分霍格沃茨的教科书。',
        '$prefix的论文总是被教授们当作范本，据说连邓布利多都曾关注过$prefix的学业。',
        '$prefix喜欢独自在图书馆待上几个小时，研究那些被其他学生忽略的角落。',
      ],
      '温柔型': [
        '$prefix来自一个温暖的家庭，$prefix的母亲是一位治疗师。',
        '$prefix经常在医务室帮忙照顾受伤的同学，院长阿姨对$prefix赞不绝口。',
        '$prefix总是能察觉别人的情绪变化，是朋友圈里最好的倾听者。',
      ],
      '野心型': [
        '$prefix的父母都是魔法部的高级官员，$prefix从小就被培养成未来的领袖。',
        '据说$prefix已经在为自己的政治生涯做准备，学生会主席是$prefix的第一个目标。',
        '$prefix做事有条不紊，目标明确，很少有人能动摇$prefix的决心。',
      ],
      '忠诚型': [
        '$prefix的家族代代都在${house}，家族传统让$prefix对学院有着深厚的感情。',
        '$prefix是朋友圈里最值得信赖的人，任何秘密告诉$prefix都绝对安全。',
        '$prefix喜欢在厨房帮家养小精灵的忙，认为尊重每一个生灵是最重要的品质。',
      ],
      '神秘型': [
        '$prefix身上有一种说不清的气质，似乎总是能感知到别人感知不到的东西。',
        '$prefix对霍格沃茨的历史了如指掌，甚至包括那些被官方历史遗漏的片段。',
        '据说$prefix在入学时就表现出特殊的魔法天赋，让分院帽犹豫了很长时间。',
      ],
      '幽默型': [
        '$prefix是霍格沃茨的笑话大王，几乎每一天都能让身边的人开怀大笑。',
        '$prefix和弗雷德、乔治是好友，经常一起策划各种恶作剧。',
        '$prefix有一个特殊的天赋，能在任何场合找到笑点。',
      ],
      '叛逆型': [
        '$prefix的家庭背景有些特殊，这让$prefix从小就对权威持怀疑态度。',
        '$prefix拒绝遵守一些在$prefix看来不合理的规定，这让$prefix在某些圈子里很有名。',
        '$prefix信奉"规则是用来被打破的"，但$prefix有自己的底线。',
      ],
    };
    final list = flavors[archetype] ?? ['$prefix是一个有故事的人。'];
    return list[_random.nextInt(list.length)];
  }

  int _calculateAge() {
    final p = _player;
    if (p == null) return 11;
    try {
      final birthYear = int.parse(p.birthYear);
      return _worldState.time.year - birthYear;
    } catch (_) {
      return 11;
    }
  }

  int get totalWealth {
    final p = _player;
    if (p == null) return 0;
    return p.galleons + p.bankGalleons;
  }

  bool purchaseItem(String itemName, int price) {
    final p = _player;
    if (p == null) return false;
    if (p.galleons < price) return false;
    p.galleons -= price;
    p.inventory.add(InventoryItem(id: DateTime.now().millisecondsSinceEpoch.toString(), name: itemName, description: '购买的$itemName'));
    _notifications.add('💰 购买了 $itemName，花费 $price 加隆');
    notifyListeners();
    _autoSave();
    return true;
  }

  bool sellItem(int index, int price) {
    final p = _player;
    if (p == null) return false;
    if (index < 0 || index >= p.inventory.length) return false;
    final item = p.inventory.removeAt(index);
    p.galleons += price;
    _notifications.add('💰 出售了 ${item.name}，获得 $price 加隆');
    notifyListeners();
    _autoSave();
    return true;
  }

  bool depositToBank(int amount) {
    final p = _player;
    if (p == null || amount <= 0) return false;
    if (p.galleons < amount) return false;
    p.galleons -= amount;
    p.bankGalleons += amount;
    _notifications.add('🏦 存入古灵阁 $amount 加隆');
    notifyListeners();
    _autoSave();
    return true;
  }

  bool withdrawFromBank(int amount) {
    final p = _player;
    if (p == null || amount <= 0) return false;
    if (p.bankGalleons < amount) return false;
    p.bankGalleons -= amount;
    p.galleons += amount;
    _notifications.add('🏦 从古灵阁取出 $amount 加隆');
    notifyListeners();
    _autoSave();
    return true;
  }

  int acceptJob(String jobId) {
    const jobs = {
      'flourish_blotts': 15,
      'apothecary': 25,
      'gringotts': 30,
      'honeydukes': 12,
      'quills': 18,
    };
    final pay = jobs[jobId] ?? 10;
    final p = _player;
    if (p == null) return 0;
    p.galleons += pay;
    p.jobHistory.add('$jobId: +$pay加隆 (${_worldState.time.month}月${_worldState.time.day}日)');
    _worldState.time.advanceMinutes(240);
    p.energy = (p.energy - 15).clamp(0, 100);
    _notifications.add('💼 打工完成（$jobId），获得 $pay 加隆');
    notifyListeners();
    _autoSave();
    return pay;
  }

  // ==================== 指令格式化 ====================
  String _formatStatus() {
    final p = _player!;
    final w = _worldState;
    final buf = StringBuffer()
      ..writeln('╔══════════════════════════════════════╗')
      ..writeln('  《哈利·波特·魔法纪元·人生状态》')
      ..writeln('╚══════════════════════════════════════╝')
      ..writeln()
      ..writeln('【时间】${w.timestamp}')
      ..writeln('【年龄】${_calculateAge()}岁')
      ..writeln('【血统】${_bloodStatusLabel(p.bloodType)}')
      ..writeln('【身份】${p.birthIdentity ?? '未设定'}')
      ..writeln('【所在地】${w.currentLocation ?? '未知'}')
      ..writeln('【学院】${p.house ?? '未分院'} · ${p.grade ?? 1}年级')
      ..writeln('【职业】${p.initialTalent ?? '学生'}')
      ..writeln('【财富】💰 ${p.galleons}金加隆 · 🏦 ${p.bankGalleons}古灵阁')
      ..writeln('【家庭】${p.familyBackground ?? '未设定'}')
      ..writeln('【社会地位】学院声望${p.houseReputation} · 魔法界声望${p.wizardingReputation} · 阵营声望${p.factionReputation}')
      ..writeln()
      ..writeln('【生存状态】')
      ..writeln('❤️ 生命：${p.health}/100')
      ..writeln('🔮 魔力：${p.magic}/100')
      ..writeln('🧠 精神力：${p.spirit}/100')
      ..writeln('🍗 饱食度：${p.satiety}/100')
      ..writeln('⚡ 精力：${p.energy}/100')
      ..writeln()
      ..writeln('【魔法能力】')
      ..writeln('魔法资质：${p.magicAptitude ?? '普通'}')
      ..writeln('主修天赋：${p.initialTalent ?? '未设定'}')
      ..writeln('已学魔咒：${p.learnedSpells.isEmpty ? '尚未学会任何魔咒' : '${p.learnedSpells.length}个咒语'}')
      ..writeln()
      ..writeln('【学院四维】')
      ..writeln('勇气：${p.houseDimensions['courage']}  智慧：${p.houseDimensions['wisdom']}')
      ..writeln('忠诚：${p.houseDimensions['loyalty']}  野心：${p.houseDimensions['ambition']}')
      ..writeln()
      ..writeln('【政治倾向】${p.politicalTendency ?? '未设定'}')
      ..writeln('【模拟风格】${p.simulationStyle ?? '混合模式'}')
      ..writeln('【恋爱状态】${p.loveState.status}${p.loveState.partnerName != null ? '（${p.loveState.partnerName}）' : ''}')
      ..writeln('【世界线变动率】${(p.worldLineDeviation * 100).toStringAsFixed(1)}%')
      ..writeln()
      ..writeln('【当前目标】${p.currentGoal ?? '尚未设定目标'}');
    return buf.toString();
  }

  String _formatTime() {
    final w = _worldState;
    return '【当前时间】\n${w.timestamp}\n'
        '学年：${w.academicYear}\n'
        '学期：${_termLabel(w.term)}\n'
        '流速模式：${_flowModeLabel(w.timeFlowMode)}\n'
        '${w.specialMarkers.isEmpty ? '' : '特殊标记：${w.specialMarkers.join(' ')}'}';
  }

  String _formatMap() {
    return '''【霍格沃茨地图】
当前地点：${_worldState.currentLocation ?? '九又四分之三站台 / 霍格沃茨特快'}

已知区域：
🏰 城堡主楼（大礼堂、各学院公共休息室、图书馆、教室）
🧙 各学院公共休息室
🌳 禁林（高年级或特定课程开放）
🧪 地下教室（魔药学、斯莱特林公共休息室）
🏟️ 魁地奇球场
🏘️ 霍格莫德村（周末开放）
🧹 天文塔
📚 图书馆（含禁书区）

各NPC当前位置：
${_npcRegistry.values.where((n) => n.isAlive).take(6).map((n) => '· ${n.name}：${n.currentLocation}').join('\n')}''';
  }

  String _formatNotifications() {
    if (_notifications.isEmpty) {
      return '【通知】\n暂无新通知。';
    }
    return '【通知】\n${_notifications.reversed.take(10).map((n) => '· $n').join('\n')}';
  }

  String _formatHelp() {
    return '''【指令系统】
/状态 — 查看角色完整状态
/时间 — 查看当前时间与特殊标记
/地图 — 查看霍格沃茨地图与NPC位置
/通知 — 查看未读通知
/帮助 — 查看指令说明
/关系 — 查看所有NPC好感度与关系
/恋爱 — 查看恋爱状态
/声望 — 查看声望档案
/舆论 — 查看校园里的传闻/谣言
/课程 — 查看课程表与进度
/课堂 互动 — 触发课堂互动（提问/练习/同桌/意外）
/收藏 — 查看收藏品
/日记 — 查看CG图鉴（/日记 统计·/日记 [编号]·/日记 重播 [编号]）
/档案 — 查看角色完整档案
/成就 — 查看成就
/宠物 — 查看宠物状态
/信 — 查看收到的信件（/信 读 [编号] · /信 回 [编号] [内容] · /信 寄 [NPC] [内容]）
/新NPC — 生成一位新NPC（每学年限4次）
/血缘 — 查看血缘亲属
/联动 — 查看时代联动痕迹
/目标 — 查看/设定人生目标（/目标 [编号]）
/结局 — 生成终章报告
/cheat — 作弊指令（详见 /cheat）''';
  }

  // ==================== 人生目标系统 ====================
  String _formatGoals() {
    final p = _player;
    final current = p?.currentGoal;
    final buf = StringBuffer()
      ..writeln('╔══════════════════════════════════════╗')
      ..writeln('  《人生目标》')
      ..writeln('╚══════════════════════════════════════╝')
      ..writeln()
      ..writeln('【当前目标】${(current == null || current.isEmpty) ? '尚未设定' : current}');
    if (current != null && current.isNotEmpty) {
      final g = goalByName(current);
      if (g != null) {
        buf.writeln('  『${g.description}』');
      }
    }
    buf
      ..writeln()
      ..writeln('【可选目标】（输入 /目标 [编号] 设定）');
    for (int i = 0; i < lifeGoalCatalog.length; i++) {
      final g = lifeGoalCatalog[i];
      buf.writeln('${i + 1}. ${g.name}（${g.category}）— ${g.description}');
    }
    if (current != null && current.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('💡 输入 /目标 进度 查看当前目标的毕业条件达成情况。');
    }
    return buf.toString();
  }

  // ==================== 终章 / 结局 ====================
  void _startEndingSequence() {
    if (_player == null) return;
    _isLoading = true;
    _loadingStage = '正在书写你的终章…';
    _currentNarrative = '';
    _choices = [];
    notifyListeners();
    unawaited(_generateEnding());
  }

  Future<void> _generateEnding() async {
    final p = _player;
    if (p == null) {
      _isLoading = false;
      _loadingStage = '';
      notifyListeners();
      return;
    }

    final relationSnapshot = _buildRelationshipSnapshot();
    final unlockedNames = achievementCatalog
        .where((a) => p.achievements.contains(a.id))
        .map((a) => a.name)
        .toList();
    final rep = p.playerReputation;
    final repSummary =
        '学术${rep.academic} 社交${rep.social} 战斗${rep.combat} 道德${rep.moral} 领导${rep.leadership} 黑魔法${rep.dark}';

    final header = '╔══════════════════════════════════════╗\n'
        '  《终章报告》· ${p.name}的魔法人生\n'
        '╚══════════════════════════════════════╝\n\n'
        '【时代】${_eraLabel(appProvider.era)}\n'
        '【学院】${p.house ?? '未分院'} · ${p.grade ?? 1}年级\n'
        '【爱情】${p.loveState.status}${p.loveState.partnerName != null ? '（${p.loveState.partnerName}）' : ''}\n'
        '【财富】${p.galleons}金加隆 · 银行${p.bankGalleons}\n'
        '【世界线变动率】${(p.worldLineDeviation * 100).toStringAsFixed(1)}%\n'
        '【人生目标】${p.currentGoal ?? '未设定'}\n'
        '【声望】$repSummary\n'
        '【成就】${unlockedNames.isEmpty ? '尚无' : unlockedNames.join('、')}\n'
        '【重要羁绊】${relationSnapshot.isEmpty ? '暂无深入关系' : relationSnapshot}\n';

    // 本地回退（无 AI 或调用失败时使用）
    final localFallback = header +
        '\n这段魔法人生走到终点。你曾站在九又四分之三站台，见证过霍格沃茨的晨昏，'
        '也与一些人结下过或深或浅的羁绊。无论结局如何，那些选择都已化作你独有的世界线，'
        '在无数平行世界里继续生长。\n\n'
        '—— 你的故事，到此暂告一段落。\n\n（提示：配置 AI 提供商后，/结局 可生成更完整的终章评语。）';

    var ending = localFallback;
    try {
      if (_router != null && _router!.hasNarrativeService) {
        final prompt = '''请为玩家撰写一份《终章报告》的评语部分，作为这段魔法人生的结局回顾。用第二人称"你"，小说化文笔，情感克制而有温度，600字以内。

【玩家档案】
姓名：${p.name}｜${p.gender}｜${_bloodStatusLabel(p.bloodType)}｜${p.house ?? '未分院'}｜时代：${_eraLabel(appProvider.era)}

【人生目标】${p.currentGoal ?? '未设定'}（评价：是否实现、以怎样的方式实现或错失）

【重要羁绊】${relationSnapshot.isEmpty ? '暂无深入关系' : relationSnapshot}

【声望】$repSummary
【成就】${unlockedNames.isEmpty ? '尚无' : unlockedNames.join('、')}

【前情摘要】
${_narrativeSummary.isNotEmpty ? _narrativeSummary : '（这是一段从一年级开始的旅程）'}

请按此结构输出：
一、命运回响
二、重要羁绊
三、人生目标达成
四、终章评语''';

        final result = await _callDeepSeek(
          prompt,
          scene: AiScene.summary,
        );
        final content = result.content.trim();
        if (content.isNotEmpty) {
          ending = header + '\n' + content;
        }
      }
    } catch (e) {
      debugPrint('终章生成失败，使用本地回退: $e');
    }

    _currentNarrative = ending;
    _choices = [GameChoice(text: '继续旅程', action: '继续')];
    _isLoading = false;
    _loadingStage = '';
    notifyListeners();
    _autoSave();
  }

  String _formatRelationships() {
    if (_npcRegistry.isEmpty) return '暂无认识的人。';
    final buf = StringBuffer('【关系列表】\n');
    final list = _npcRegistry.values.where((n) => n.isAlive).toList()
      ..sort((a, b) => b.affection.compareTo(a.affection));
    for (final n in list.take(15)) {
      buf.writeln('· ${n.name}：好感 ${n.affection}（${n.affectionStage}）');
    }
    return buf.toString();
  }

  String _formatLove() {
    final love = _player!.loveState;
    if (love.status == '单身') {
      return '【恋爱状态】单身\n'
          '${_formatHighAffectionHints()}';
    }
    return '【恋爱状态】${love.status}\n'
        '对象：${love.partnerName}\n'
        '${love.history.isEmpty ? '' : '恋爱历程：\n${love.history.map((h) => '· ${h['date']}：${h['event']}').join('\n')}'}';
  }

  String _formatHighAffectionHints() {
    final hints = _npcRegistry.values
        .where((n) => n.affection >= 70 && n.isAlive && !n.confessed)
        .map((n) => '· ${n.name}（好感 ${n.affection}）${n.isConsideringConfession ? '—— 似乎正在酝酿着什么……' : ''}')
        .toList();
    if (hints.isEmpty) return '还没有人对你表现出特别的好感。';
    return '对你有较高好感的NPC：\n${hints.join('\n')}';
  }

  // ==================== 恋爱等待状态 ====================
  String _formatLoveWaiting() {
    if (_player == null) return '【恋爱等待】\n尚未创建角色。';
    final love = _player!.loveState;
    final considering = _npcRegistry.values
        .where((n) => n.isConsideringConfession && n.isAlive)
        .map((n) => '· ${n.name}（好感 ${n.affection}）')
        .toList();
    final buf = StringBuffer('【恋爱等待】\n');
    if (love.awaitingConfession && love.consideringNpcName != null) {
      buf.writeln('${love.consideringNpcName} 正在认真考虑向你表白……');
      buf.writeln('请耐心等待，或继续与 TA 互动来推一把。');
    } else if (considering.isNotEmpty) {
      buf.writeln('以下 NPC 似乎正在酝酿感情：');
      buf.writeln(considering.join('\n'));
      buf.writeln('\n多互动可以加快表白时机。');
    } else {
      buf.writeln('目前没有 NPC 正在考虑向你表白。');
      buf.writeln(_formatHighAffectionHints());
    }
    return buf.toString();
  }

  // ==================== 恋爱阶段一览 ====================
  String _formatLoveStages() {
    if (_player == null) return '【恋爱阶段】\n尚未创建角色。';
    final love = _player!.loveState;
    final stages = <String>[];
    if (love.partnerName != null) {
      stages.add('· ${love.partnerName}：${love.status}（正式伴侣）');
    }
    for (final entry in love.relationshipStages.entries) {
      if (entry.key == love.partnerName) continue;
      final events = love.romanticEventsFor(entry.key);
      stages.add('· ${entry.key}：${entry.value}（浪漫事件 $events 次）');
    }
    final highAffection = _npcRegistry.values
        .where((n) =>
            n.affection >= 60 &&
            n.isAlive &&
            !love.relationshipStages.containsKey(n.name) &&
            n.name != love.partnerName)
        .take(5)
        .map((n) => '· ${n.name}：${n.affectionStage}（好感 ${n.affection}）')
        .toList();
    if (stages.isEmpty && highAffection.isEmpty) {
      return '【恋爱阶段】\n暂无任何 NPC 关系记录。多多互动会建立各种缘分。';
    }
    final buf = StringBuffer('【恋爱阶段】\n');
    if (stages.isNotEmpty) {
      buf.writeln('已建立关系：');
      buf.writeln(stages.join('\n'));
    }
    if (highAffection.isNotEmpty) {
      if (stages.isNotEmpty) buf.writeln();
      buf.writeln('高好感潜力对象：');
      buf.writeln(highAffection.join('\n'));
    }
    return buf.toString();
  }

  // ==================== NPC 关系网络查询 ====================
  String _formatNpcRelationship(String npc1, String npc2) {
    if (_player == null) return '【关系网络】\n尚未创建角色。';
    NPC findNpc(String keyword) {
      return _npcRegistry.values.firstWhere(
        (n) => n.name.contains(keyword) || keyword.contains(n.name),
        orElse: () => NPC(id: '', name: '「$keyword」', house: ''),
      );
    }

    final a = findNpc(npc1);
    final b = findNpc(npc2);
    if (a.id.isEmpty || b.id.isEmpty) {
      return '【${a.name} 与 ${b.name} 的关系】\n其中有 NPC 不在你的社交圈中，信息不足。';
    }
    // 基础关系推理
    final tags = <String>[];
    if (a.house.isNotEmpty && b.house.isNotEmpty) {
      tags.add(a.house == b.house ? '同学院' : '跨学院');
    }
    // 共同认识的人（通过玩家关系推断）
    final relMap = _player!.relationships;
    final aKnows = relMap.containsKey(a.id);
    final bKnows = relMap.containsKey(b.id);
    if (aKnows && bKnows) {
      tags.add('你们有共同好友（你）');
    }
    // 好感差异
    final diff = (a.affection - b.affection).abs();
    final closeness = a.affection > b.affection ? a.name : b.name;
    tags.add('你对 $closeness 更亲近（好感差 $diff）');
    // 血缘亲属检查
    final bloodRel = _player!.bloodRelatives;
    final aIsBlood = bloodRel.any((name) => name == a.name || a.name.contains(name) || name.contains(a.name));
    final bIsBlood = bloodRel.any((name) => name == b.name || b.name.contains(name) || name.contains(b.name));
    if (aIsBlood && bIsBlood) tags.add('两人都是你的血缘亲属');
    return '【${a.name} 与 ${b.name} 的关系】\n'
        '标签：${tags.isEmpty ? '无特殊关联' : tags.join(' · ')}\n'
        '${a.house.isNotEmpty ? '${a.name}：${a.house}\n' : ''}'
        '${b.house.isNotEmpty ? '${b.name}：${b.house}\n' : ''}'
        '\n基于目前观察，他们属于${tags.length >= 2 ? '有交集的' : '普通的'}同学/熟人关系。';
  }

  // ==================== 骨科模式状态 ====================
  String _formatBoneMode() {
    if (_player == null) return '【骨科模式】\n尚未创建角色。';
    final bloodRel = _player!.bloodRelatives;
    final buf = StringBuffer(_player!.boneMode
        ? '【骨科模式】已开启\n允许与血缘亲属发展浪漫关系。\n\n'
        : '【骨科模式】已关闭\n无法与血缘亲属发展浪漫关系。\n\n');
    if (bloodRel.isEmpty) {
      buf.writeln('当前血缘亲属列表：（暂无记录）');
    } else {
      buf.writeln('当前血缘亲属列表：');
      for (final name in bloodRel.take(10)) {
        final npc = _npcRegistry.values.firstWhere(
          (n) => n.name == name || name.contains(n.name) || n.name.contains(name),
          orElse: () => NPC(id: '', name: name, house: ''),
        );
        final extra = npc.house.isNotEmpty ? ' · ${npc.house}' : '';
        buf.writeln('· $name$extra');
      }
      if (bloodRel.length > 10) buf.writeln('  ……等共 ${bloodRel.length} 位');
    }
    return buf.toString();
  }

  String _formatReputation() {
    final rep = _player!.playerReputation;
    final p = _player!;
    return '''【声望档案】
学术声望：${rep.academic}（${reputationGrade(rep.academic)}）
社交声望：${rep.social}（${reputationGrade(rep.social)}）
战斗声望：${rep.combat}（${reputationGrade(rep.combat)}）
道德声望：${rep.moral}（${reputationGrade(rep.moral)}）
领导声望：${rep.leadership}（${reputationGrade(rep.leadership)}）
黑魔法声望：${rep.dark}（${reputationGrade(rep.dark)}）

学院声望：${p.houseReputation}
魔法界声望：${p.wizardingReputation}
阵营声望：${p.factionReputation}''';
  }

  /// 舆论/传闻系统（设定文档 7.3 / 第十三部分）
  String _formatRumors() {
    final rumors = _player!.rumors;
    if (rumors.isEmpty) {
      return '【舆论】\n目前校园里还没有关于你的传闻。你只是个普通学生——至少现在还是。';
    }
    final buf = StringBuffer('【舆论 / 传闻】\n');
    for (final r in rumors) {
      buf.writeln('· $r');
    }
    buf.writeln('\n（输入 /cheat 舆论 清除 可删除传闻）');
    return buf.toString();
  }

  /// 追加一条传闻（去重 + 保留最近 20 条，避免无限膨胀）
  void _addRumor(String text) {
    final p = _player;
    if (p == null) return;
    if (p.rumors.contains(text)) return;
    p.rumors.insert(0, text);
    if (p.rumors.length > 20) {
      p.rumors.removeRange(20, p.rumors.length);
    }
  }

  String _formatCourses() {
    final buf = StringBuffer('【课程系统】\n必修课：\n');
    for (final c in requiredCourses) {
      buf.writeln('· ${c.name}（${c.professor}）');
    }
    buf.writeln('\n选修课（三年级起，至少选2门）：');
    for (final c in electiveCourses) {
      buf.writeln('· ${c.name}（${c.professor}）');
    }
    buf.writeln('\n（输入 /课堂 互动 进入当前课堂的互动环节）');
    return buf.toString();
  }

  /// 课堂互动（设定 10.3，全程本地判定，零 token 消耗）
  void _classroomInteraction() {
    final p = _player;
    if (p == null) return;
    final roll = _random.nextInt(100);
    String result;

    if (roll < 40) {
      // 教授提问：影响学术声望
      final correct = _random.nextBool();
      if (correct) {
        p.playerReputation.add('academic', 2);
        result = '【课堂互动 · 教授提问】\n'
            '教授的目光扫过教室，最后停在你身上，抛出一个刁钻的问题。\n'
            '你略一思索，给出了答案。教室里响起几声低低的惊叹，教授罕见地点了点头。\n'
            '\n学术声望 +2';
      } else {
        result = '【课堂互动 · 教授提问】\n'
            '教授突然点你的名。你心头一跳，答案卡在喉咙里，最后只好摇了摇头。\n'
            '几个同学投来同情的目光，你决定下次好好预习。\n'
            '\n（本次无变化）';
      }
    } else if (roll < 70) {
      // 实践操作：影响技能熟练度
      const skills = ['魔咒学', '变形术', '魔药学', '草药学'];
      const skillAttrs = {
        '魔咒学': 'spell_understanding',
        '变形术': 'transfiguration',
        '魔药学': 'potions',
        '草药学': 'herbology',
      };
      final skill = skills[_random.nextInt(skills.length)];
      final attr = skillAttrs[skill]!;
      p.attributes[attr] = ((p.attributes[attr] ?? 50) + 1).clamp(0, 100);
      result = '【课堂互动 · 实践操作】\n'
          '你握紧魔杖，全神贯注地练习$skill。魔杖尖端的光芒稳定而流畅，眼前的材料随着你的咒语乖巧地变化。\n'
          '\n$skill 熟练度 +1';
    } else if (roll < 90) {
      // 同桌互动：影响 NPC 好感
      final alive = _npcRegistry.values.where((n) => n.isAlive).toList();
      if (alive.isNotEmpty) {
        final npc = alive[_random.nextInt(alive.length)];
        final delta = 1 + _random.nextInt(2); // +1 ~ +2
        npc.affection = (npc.affection + delta).clamp(-100, 100);
        result = '【课堂互动 · 同桌】\n'
            '趁教授转身，${npc.name}悄悄递来一张纸条，上面写着刚才没听懂的笔记要点。\n'
            '你冲对方感激地笑了笑。\n'
            '\n与 ${npc.name} 的好感 +$delta';
      } else {
        result = '【课堂互动 · 同桌】\n你环顾四周，身边的座位空着，只得独自琢磨刚才的内容。';
      }
    } else {
      // 特殊意外：纯叙事
      const events = [
        '魔药课上，你的坩埚突然冒出诡异的绿烟，被斯内普教授冷冷地盯了三秒。',
        '温室里，你险些被曼德拉草的尖叫声震晕，幸好及时堵住了耳朵。',
        '黑魔法防御课上，你被选中上台示范，紧张中竟意外地漂亮完成了动作。',
        '天文课上，你透过望远镜瞥见了一颗罕见的流星，全班都循声凑了过来。',
      ];
      result = '【课堂互动 · 意外】\n${events[_random.nextInt(events.length)]}\n\n（一段课堂上的小插曲，世界线纹丝不动）';
    }

    _currentNarrative = result;
    _choices = [GameChoice(text: '继续', action: '继续')];
  }

  String _formatCollection() {
    if (_player!.collection.isEmpty) {
      return '【收藏】\n暂无收藏品。在冒险中收集独特物品，如巧克力蛙画片、日记本等。';
    }
    return '【收藏】\n${_player!.collection.map((c) => '· $c').join('\n')}';
  }

  String _formatDiary() {
    if (_player!.cgRecords.isEmpty) {
      return '【日记 / CG图鉴】\n暂无解锁CG。在关键剧情节点将解锁专属CG。\n\n（输入 /日记 统计 查看进度；/日记 [编号] 查看详情）';
    }
    final buf = StringBuffer('【日记 / CG图鉴】（已解锁 ${_player!.cgRecords.length}/${allCgs().length}）\n');
    for (final cg in allCgs()) {
      final rec = _player!.cgRecords[cg.id];
      if (rec == null) continue;
      buf.writeln('· ${cg.id} ${cg.name}（${rec.unlockedDate}）');
    }
    return buf.toString();
  }

  /// CG 数量与等级分布（设定 7.5 /日记 统计）
  String _formatDiaryStats() {
    final unlocked = _player!.cgRecords;
    final all = allCgs();
    final byStars = <int, int>{2: 0, 3: 0, 4: 0, 5: 0};
    final byChapter = <String, int>{};
    for (final cg in all) {
      if (unlocked.containsKey(cg.id)) {
        byStars[cg.stars] = (byStars[cg.stars] ?? 0) + 1;
        byChapter[cg.chapter] = (byChapter[cg.chapter] ?? 0) + 1;
      }
    }
    final buf = StringBuffer()
      ..writeln('【日记统计】')
      ..writeln('已解锁：${unlocked.length}/${all.length}')
      ..writeln()
      ..writeln('【等级分布】')
      ..writeln('★★ 二星：${byStars[2] ?? 0}')
      ..writeln('★★★ 三星：${byStars[3] ?? 0}')
      ..writeln('★★★★ 四星：${byStars[4] ?? 0}')
      ..writeln('★★★★★ 五星：${byStars[5] ?? 0}')
      ..writeln()
      ..writeln('【章节分布】');
    if (byChapter.isEmpty) {
      buf.writeln('（暂无）');
    } else {
      for (final e in byChapter.entries) {
        buf.writeln('· ${e.key}：${e.value}');
      }
    }
    return buf.toString();
  }

  /// 查看指定 CG 详情（设定 7.5 /日记 [编号]）
  String _formatCgDetail(String id) {
    final cg = cgById(id);
    if (cg == null) {
      return '未找到 CG「$id」。可用编号见 /日记。';
    }
    final rec = _player!.cgRecords[cg.id];
    if (rec == null) {
      return '【${cg.id} ${cg.name}】🔒 尚未解锁\n'
          '章节：${cg.chapter}｜等级：${cg.starText}\n'
          '解锁条件：${cg.condition}';
    }
    return '【${cg.id} ${cg.name}】${cg.starText}\n'
        '章节：${cg.chapter}\n'
        '解锁条件：${cg.condition}\n'
        '解锁于：${rec.unlockedDate}';
  }

  /// 重播指定 CG（精简版，设定 7.5 /日记 重播）
  String _replayCg(String id) {
    final cg = cgById(id);
    if (cg == null) {
      return '未找到 CG「$id」。可用编号见 /日记。';
    }
    final rec = _player!.cgRecords[cg.id];
    if (rec == null) {
      return '【${cg.id} ${cg.name}】尚未解锁，无法重播。\n解锁条件：${cg.condition}';
    }
    return '【重播 · ${cg.name}】${cg.starText}\n\n'
        '—— 记忆被重新点亮。\n\n'
        '你仿佛又回到了那一刻：旧羊皮纸与蜡烛的气味在空气里浮动，远处的钟声在石墙之间低低回荡，而「${cg.name}」的画面，如月光一般温柔地重新铺展在你眼前。\n\n'
        '（${cg.chapter}）解锁于 ${rec.unlockedDate}';
  }

  String _formatArchive() {
    final p = _player!;
    return '''【角色完整档案】
姓名：${p.name}｜性别：${p.gender.isEmpty ? '未设定' : p.gender}
生日：${p.birthDay ?? '未设定'}｜出生年份：${p.birthYear}
血统：${_bloodStatusLabel(p.bloodType)}｜出生地：${p.birthLocation}
学院：${p.house ?? '未分院'}｜年级：${p.grade ?? 1}
性取向：${p.sexOrientation ?? '未设定'}
魔杖：${p.wandId != null ? wandById(p.wandId!)?.name ?? p.wandId : '未选择'}
宠物：${p.petName ?? '无'}
外貌：${p.appearance ?? '未设定'}
家族背景：${p.familyBackground ?? '未设定'}
童年经历：${p.childhoodExperiences.isEmpty ? '未设定' : p.childhoodExperiences.join('；')}
信仰与价值观：${p.beliefs ?? '未设定'}
初始天赋：${p.initialTalent ?? '未设定'}
性格特质：${p.personalityTraits.isEmpty ? '未设定' : p.personalityTraits.join('、')}
当前目标：${p.currentGoal ?? '无'}''';
  }

  String _formatAchievements() {
    final unlocked = _player!.achievements;
    final catalog = achievementCatalog;
    final buf = StringBuffer('【成就】（${unlocked.length}/${catalog.length}）\n');
    for (final a in catalog) {
      final has = unlocked.contains(a.id);
      buf.writeln('${has ? '✅' : '🔒'} ${a.name}${has ? ' — ${a.description}' : ''}');
    }
    return buf.toString();
  }

  String _formatPet() {
    final p = _player!;
    if (p.petId == null && p.petName == null) {
      return '【宠物】\n你还没有宠物。可以去对角巷挑选一只猫头鹰、猫或蟾蜍。';
    }
    return '【宠物】\n名字：${p.petName ?? '未命名'}\n羁绊：${p.petBond}/100\n宠物可以帮你送信、在冒险中提供帮助。';
  }

  // ==================== 信件互动系统 ====================

  /// 处理 /信 系列子指令：读 / 回 / 寄
  void _handleLetterCommand(List<String> parts) {
    final back = () {
      _choices = [GameChoice(text: '返回', action: '继续')];
    };

    if (parts.length < 2) {
      _currentNarrative = _formatLetters();
      back();
      return;
    }

    switch (parts[1]) {
      case '读':
        final idx = int.tryParse(parts.length > 2 ? parts[2] : '');
        _currentNarrative = idx == null
            ? '【信件】\n请输入信件编号：/信 读 [编号]'
            : _formatLetterDetail(idx);
        back();
        return;
      case '回':
        final idx = int.tryParse(parts.length > 2 ? parts[2] : '');
        if (idx == null) {
          _currentNarrative = '【回信】\n请输入：/信 回 [编号] [回信内容]';
        } else {
          final content = parts.length > 3 ? parts.sublist(3).join(' ') : '';
          _currentNarrative = _replyToLetter(idx, content);
        }
        back();
        return;
      case '寄':
        final name = parts.length > 2 ? parts[2] : '';
        final content = parts.length > 3 ? parts.sublist(3).join(' ') : '';
        _currentNarrative = name.isEmpty
            ? '【寄信】\n请输入：/信 寄 [NPC名字] [信件内容]'
            : _sendLetterToNpc(name, content);
        back();
        return;
      default:
        _currentNarrative = _formatLetters();
        back();
        return;
    }
  }

  String _formatLetters() {
    final letters = _player!.letters;
    if (letters.isEmpty) {
      return '【信件】\n暂无信件。\n\n你可以通过猫头鹰给某人寄信：/信 寄 [NPC名字] [内容]';
    }
    final buf = StringBuffer()
      ..writeln('【信件】共 ${letters.length} 封（✉ 表示未读）')
      ..writeln();
    for (int i = 0; i < letters.length; i++) {
      final l = letters[i];
      final mark = l.read ? '　' : '✉';
      buf.writeln('[$mark ${i + 1}] ${l.sender}（${l.date}）');
      final preview = l.content.length > 26 ? '${l.content.substring(0, 26)}…' : l.content;
      buf.writeln('      $preview');
      buf.writeln();
    }
    buf.writeln('用法：/信 读 [编号] · /信 回 [编号] [内容] · /信 寄 [NPC名字] [内容]');
    return buf.toString();
  }

  String _formatLetterDetail(int index) {
    final letters = _player!.letters;
    if (index < 1 || index > letters.length) {
      return '【信件】\n没有第 $index 封信。当前共 ${letters.length} 封。';
    }
    final l = letters[index - 1];
    l.read = true;
    return '【书信】\n寄信人：${l.sender}\n日期：${l.date}\n\n${l.content}';
  }

  /// 寄信给 NPC（本地逻辑，不消耗 AI token）
  String _sendLetterToNpc(String npcName, String content) {
    final p = _player;
    if (p == null) return '【寄信】\n尚未创建角色。';
    if (content.trim().isEmpty) {
      return '【寄信】\n请写明信件内容：/信 寄 [$npcName] [信件内容]';
    }

    NPC? npc;
    for (final n in _npcRegistry.values) {
      if (n.name.contains(npcName) || npcName.contains(n.name)) {
        npc = n;
        break;
      }
    }
    if (npc == null) {
      return '【寄信】\n你没有找到名叫「$npcName」的人。可输入 /关系 查看已认识的NPC。';
    }
    if (!npc.isAlive) {
      return '【寄信】\n${npc.name}已经无法收到你的信了……';
    }

    // 寄信耗时（猫头鹰往返）
    _worldState.time.advanceMinutes(15);

    // 信件是低成本的维系方式：好感小幅提升
    final stage = affectionStageFor(npc.affection);
    int change = 1;
    if (stage == '友好' || stage == '信任') change = 2;
    if (stage == '亲密' || stage == '深爱' || stage == '灵魂伴侣') change = 3;
    updateNpcAffection(npc.id, change, reason: '寄信联络');

    // 对方回信（本地模板，不消耗 AI token）
    _addLetter(sender: npc.name, content: _generateLetterReply(npc));

    final warm = stage == '死敌' || stage == '宿怨' || stage == '反感'
        ? '（对方似乎并不领情）'
        : '（你们的关系似乎更近了一点）';
    return '【寄信】\n你把写好的信交给猫头鹰，目送它振翅飞向${npc.name}。$warm\n\n几天后，猫头鹰带回了回信——输入 /信 读 查看最新一封。';
  }

  /// 回信给某封信的寄信人
  String _replyToLetter(int index, String content) {
    final letters = _player!.letters;
    if (index < 1 || index > letters.length) {
      return '【回信】\n没有第 $index 封信。当前共 ${letters.length} 封。';
    }
    final letter = letters[index - 1];
    letter.read = true;
    return _sendLetterToNpc(letter.sender, content);
  }

  /// 添加一封来信
  void _addLetter({required String sender, required String content}) {
    _player!.letters.add(Letter(
      id: 'L${DateTime.now().microsecondsSinceEpoch}',
      sender: sender,
      content: content,
      date: _worldState.time.formatDate(),
    ));
    _notifications.add('📬 收到来自 $sender 的信');
  }

  /// 根据好感阶段生成 NPC 回信（本地模板）
  String _generateLetterReply(NPC npc) {
    final stage = affectionStageFor(npc.affection);
    final name = npc.name;
    switch (stage) {
      case '死敌':
      case '宿怨':
      case '反感':
        return '（${name}读完你的信后，随手把它揉成一团扔进了壁炉。）\n你对${name}的来信，只换来了冷冰冰的沉默。';
      case '冷漠':
      case '中立':
        return '几天后，一只猫头鹰送来${name}的回信，措辞礼貌而疏远：\n「来信收悉，谢谢。祝好。」';
      case '好感':
      case '友好':
        return '${name}的回信语气轻快：\n「收到你的信啦，很高兴。等我忙完这阵子，我们在礼堂一起喝杯南瓜汁吧。」';
      case '信任':
      case '亲密':
        return '${name}的回信写得很长，字里行间透着真诚与信任，末了还留了一句：「有什么心事，随时告诉我。」';
      case '深爱':
      case '灵魂伴侣':
        return '${name}的回信字迹微微颤抖，情意几乎溢出纸面：「你的信我读了一遍又一遍……等见面时，我有话想亲口对你说。」';
      default:
        return '几天后，${name}简短地回了信。';
    }
  }

  String _formatBloodRelatives() {
    if (_player!.bloodRelatives.isEmpty) {
      return '【血缘】\n未设定血缘亲属关系。三代内血亲不可攻略（除非开启骨科模式）。';
    }
    return '【血缘】\n${_player!.bloodRelatives.join('、')}\n${_player!.boneMode ? '（骨科模式已开启，禁忌限制解除）' : '（三代内血亲不可攻略）'}';
  }

  /// 月度世界演化报告（第47章）
  String _formatWorldEvolution() {
    final w = _worldState;
    final eraName = _eraLabel(appProvider.era);
    final buf = StringBuffer()
      ..writeln('╔══════════════════════════════════════╗')
      ..writeln('  《月度世界演化报告》')
      ..writeln('╚══════════════════════════════════════╝')
      ..writeln()
      ..writeln('【当前时代】$eraName')
      ..writeln('【时间】${w.timestamp}')
      ..writeln('【学年】${w.academicYear}')
      ..writeln()
      ..writeln('【九大文明支柱状态】');
    for (int i = 0; i < kCivilizationPillars.length; i++) {
      buf.writeln('  ${i + 1}. ${kCivilizationPillars[i]}');
    }
    buf
      ..writeln()
      ..writeln('【世界五层结构】');
    for (final layer in kWorldLayers) {
      buf.writeln('  $layer');
    }
    buf
      ..writeln()
      ..writeln('【区域危险度】');
    for (final zone in kDangerZones) {
      buf.writeln('  $zone');
    }
    buf
      ..writeln()
      ..writeln('【货币体系】$kCurrencyRate')
      ..writeln()
      ..writeln('【当前地点】${w.currentLocation ?? '未知'}')
      ..writeln('【天气】${w.weather ?? '晴朗'}')
      ..writeln()
      ..writeln('【近期世界事件】')
      ..writeln(w.recentEvents.isEmpty ? '暂无记录' : w.recentEvents.map((e) => '· $e').join('\n'))
      ..writeln()
      ..writeln('【世界线变动率】${(_player?.worldLineDeviation ?? 0) * 100}%')
      ..writeln()
      ..writeln('【终极原则】');
    for (final principle in kUltimatePrinciples) {
      buf.writeln('  $principle');
    }
    return buf.toString();
  }

  String _formatAffections({int maxEntries = 8}) {
    final list = _player == null
        ? const <NPC>[]
        : _npcRegistry.values
            .where((n) => n.affection.abs() >= 30 || _player!.relationships.containsKey(n.id))
            .toList()
          ..sort((a, b) => b.affection.compareTo(a.affection));
    if (list.isEmpty) return '暂无深入关系';
    final entries = list.take(maxEntries).map((n) => '${n.name}(${n.affection})').join('、');
    if (list.length > maxEntries) return '$entries 等${list.length}人';
    return entries;
  }

  // ==================== NPC 主动表白机制 ====================
  void checkNPCConfessions() {
    final p = _player;
    if (p == null || p.loveState.status != '单身') return;
    if (p.loveState.awaitingConfession) return;

    for (final n in _npcRegistry.values) {
      n.isConsideringConfession = false;
    }

    // 融合版条件：好感≥85 + 关系阶段为"暧昧" + 浪漫事件≥2次 + 持续≥2周
    final currentDay = _worldState.time.dayOfYear;
    final candidates = _npcRegistry.values.where((n) {
      if (!n.isAlive || n.affection < Balance.confessionMinAffection || n.confessed) return false;
      if (n.sexOrientation != null && n.sexOrientation != p.sexOrientation) {
        return false;
      }
      // 检查关系阶段
      final stage = p.loveState.stageFor(n.name);
      if (stage != '暧昧' && stage != '亲密') return false;
      // 检查浪漫事件计数
      if (p.loveState.romanticEventsFor(n.name) < Balance.confessionMinRomanticEvents) return false;
      // 检查暧昧持续时间
      if (p.loveState.currentCrushName == n.name && !p.loveState.isCrushMature(currentDay)) {
        return false;
      }
      return true;
    }).toList();

    if (candidates.isEmpty) return;

    // 融合版：概率触发（基础20% + 条件达标加成）
    double triggerProb = Balance.confessionBaseProbability;
    // 好感超过90%时概率增加
    for (final c in candidates) {
      if (c.affection >= Balance.confessionHighAffectionThreshold) {
        triggerProb += Balance.confessionHighAffectionBonus;
      }
    }
    triggerProb = triggerProb.clamp(0.0, Balance.confessionMaxProbability);

    if (_random.nextDouble() > triggerProb) {
      // 标记"正在考虑"
      final npc = candidates[_random.nextInt(candidates.length)];
      npc.isConsideringConfession = true;
      return;
    }

    // 选择好感最高的候选者（更合理的表白对象）
    candidates.sort((a, b) => b.affection.compareTo(a.affection));
    final npc = candidates.first;
    npc.isConsideringConfession = true;
    npc.isAlive = true;

    final originalNarrative = _currentNarrative;
    _currentNarrative =
        (originalNarrative.isEmpty ? '' : '$originalNarrative\n\n') +
            _buildConfessionNarrative(npc, p);
    _choices = [
      GameChoice(text: '接受这份心意', action: '接受${npc.name}的表白'),
      GameChoice(text: '婉拒，但保持朋友关系', action: '婉拒${npc.name}，希望保持朋友关系'),
    ];
    p.loveState.awaitingConfession = true;
    p.loveState.consideringNpcName = npc.name;
  }

  /// 融合版表白叙事：根据NPC人格生成不同风格
  String _buildConfessionNarrative(NPC npc, Player p) {
    final personality = npc.personality;
    final traits = personality.join('');

    // 根据NPC特质选择表白风格
    if (traits.contains('勇敢') || traits.contains('直率')) {
      return '${npc.name}鼓起勇气走到你面前，眼睛里闪烁着坚定的光。\n\n'
          '"${p.name}，我有件事藏在心里很久了。" 他/她深吸一口气，\n'
          '"我喜欢你。不是一时兴起，是真的想和你在一起。"\n\n'
          '走廊里的烛光轻轻摇曳，你的心跳似乎漏了一拍。';
    } else if (traits.contains('理性') || traits.contains('聪明')) {
      return '${npc.name}似乎经过了一番深思熟虑才找到你。\n\n'
          '"${p.name}，我一直在想，该怎么说这件事才合适。" 他/她的声音平稳，\n'
          '"经过这么久的相处，我确定——我想和你在一起。不是因为冲动，而是因为我想认真地走下去。"\n\n'
          '理性的话语下，是一颗同样在跳动的心。';
    } else if (traits.contains('害羞') || traits.contains('内向')) {
      return '${npc.name}的脸涨得通红，低着头不敢看你。\n\n'
          '"${p.name}…我…" 他/她的声音很小，几乎被风声盖过，\n'
          '"我喜欢你…可以吗？"\n\n'
          '月光下，${npc.name}的耳朵尖都红了，你第一次发现原来害羞的人表白时这么可爱。';
    } else {
      return '${npc.name}站在你面前，深深地吸了一口气。\n\n'
          '"${p.name}，有件事我想让你知道。" 他/她的眼神认真而温柔，\n'
          '"我喜欢你。如果你愿意，我想和你一起走下去。"\n\n'
          '夜风拂过，一切仿佛都在等待你的回答。';
    }
  }

  /// 处理表白回应
  void resolveConfession(bool accepted, String npcName) {
    final p = _player;
    if (p == null) return;
    NPC? npc;
    try {
      npc = _npcRegistry.values.firstWhere((n) => n.name == npcName);
    } catch (_) {
      try {
        npc = _npcRegistry.values.firstWhere(
          (n) => n.name.contains(npcName) || npcName.contains(n.name),
        );
      } catch (_) {
        return;
      }
    }
    if (npc == null) return;
    npc.confessed = true;
    npc.isConsideringConfession = false;
    p.loveState.awaitingConfession = false;
    p.loveState.consideringNpcName = null;

    if (accepted) {
      p.loveState.status = '恋爱';
      p.loveState.partnerId = npc.id;
      p.loveState.partnerName = npc.name;
      p.loveState.history.add({
        'date': _worldState.timestamp,
        'event': '接受了${npc.name}的表白',
      });
      _unlockCG(cgById('CG-010'));
      _unlockCG(cgById('CG-CF-001'));
      _unlockAchievement('first_confession');
      _unlockAchievement('in_love');
      _notifications.add('💕 你与${npc.name}开始了恋爱！');
      _worldState.addNarrativeEvent('💕 你与${npc.name}开始了恋爱！');
      _addRumor('你与${npc.name}正在交往的消息，像野火一样传遍了霍格沃茨。');
      _currentNarrative =
          '你点了点头，${npc.name}的眼睛瞬间亮了起来，像被月光点亮。\n\n'
          '他/她握住你的手，声音里带着掩饰不住的喜悦："真的吗？太好了……"\n\n'
          '你们在月色下相视而笑，霍格沃茨的钟声在远处敲响，仿佛在为这段感情祝福。';
    } else {
      npc.affection -= 5;
      _unlockCG(cgById('CG-CF-002'));
      _addRumor('听说${npc.name}向你表白，却被你拒绝了。');
      _currentNarrative =
          '你温和地摇了摇头。${npc.name}的眼神黯淡了一下，但很快挤出一个微笑。\n\n'
          '"我明白了……那我们，还是朋友吧？"\n\n'
          '他/她松开手，向你露出一个勉强却真心的笑容。月光依旧明亮，只是空气里多了一丝惆怅。';
    }
    _choices = [GameChoice(text: '继续', action: '继续')];
  }
  // ==================== 时间格式化 ====================
  String _formatDate() {
    final t = _worldState.time;
    final year = t.year;
    final months = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];
    final month = (t.month >= 1 && t.month <= 12) ? months[t.month - 1] : '${t.month}月';
    final day = _worldState.dayOfMonth;
    final weekday = _worldState.dayOfWeek;
    final hour = t.hour.toString().padLeft(2, '0');
    final minute = t.minute.toString().padLeft(2, '0');
    return '📅 $year年$month$day日，$weekday，[$hour:$minute]';
  }


  // ==================== CG 解锁 ====================
  void _unlockCG(CgDef? cg) {
    final p = _player;
    if (cg == null || p == null) return;
    if (p.cgRecords.containsKey(cg.id)) return;
    p.cgRecords[cg.id] = CgRecord(
      cgId: cg.id,
      name: cg.name,
      unlockedDate: _formatDate(),
      chapter: cg.chapter,
    );
    _notifications.add('📸 解锁CG：${cg.name}');
    _worldState.addNarrativeEvent('📸 解锁CG：${cg.name}');
  }

  void _unlockAchievement(String id) {
    final p = _player;
    if (p == null) return;
    if (p.achievements.contains(id)) return;
    final ach = achievementCatalog.firstWhere(
      (a) => a.id == id,
      orElse: () => Achievement(id: id, name: id, description: ''),
    );
    p.achievements.add(id);
    _notifications.add('🏆 解锁成就：${ach.name}');
    _worldState.addNarrativeEvent('🏆 解锁成就：${ach.name}');
  }

  void _checkAffectionAchievements(NPC npc) {
    if (npc.affection >= 20) {
      _unlockAchievement('first_friend');
    }
    _checkCGUnlockByAffection(npc);
  }

  void _checkCGUnlockByAffection(NPC npc) {
    final p = _player;
    if (p == null) return;
    final aff = npc.affection;
    final isCrush = p.loveState.currentCrushName == npc.name;
    final isPartner = p.loveState.partnerId == npc.id;

    final cgChecks = <int, String>{};

    if (aff >= 20) cgChecks[20] = 'CG-001';
    if (aff >= 35) cgChecks[35] = 'CG-004';
    if (aff >= 40) {
      cgChecks[40] = 'CG-005';
      cgChecks[41] = 'CG-006';
    }
    if (aff >= 60 && isCrush) cgChecks[60] = 'CG-007';
    if (aff >= 65 && isCrush) cgChecks[65] = 'CG-008';
    if (aff >= 70 && isCrush) cgChecks[70] = 'CG-009';
    if (aff >= 80 && isCrush) cgChecks[80] = 'CG-011';
    if (aff >= 90 && (isPartner || aff >= 90)) cgChecks[90] = 'CG-013';
    if (aff >= 92 && aff < 95) cgChecks[92] = 'CG-014';
    if (aff >= 95) {
      cgChecks[95] = 'CG-015';
      cgChecks[96] = 'CG-017';
    }
    if (aff >= 93) cgChecks[93] = 'CG-018';
    if (aff >= 96) cgChecks[96] = 'CG-019';
    if (aff >= 98) cgChecks[98] = 'CG-020';

    for (final cgId in cgChecks.values) {
      _unlockCG(cgById(cgId));
    }

    if (p.boneMode && isCrush) {
      if (npc.confessed) _unlockCG(cgById('CG-BONE-001'));
    }
  }

  void _checkSkillAchievements() {
    final p = _player;
    if (p == null) return;
    for (final s in p.learnedSpells.values) {
      if (s.level >= 90) {
        _unlockAchievement('honor_student');
        return;
      }
    }
  }

  void _checkWorldChangerAchievement() {
    final p = _player;
    if (p == null) return;
    if (p.worldLineDeviation >= 0.1) {
      _unlockAchievement('world_changer');
    }
  }

  void _checkWarHeroAchievement() {
    final p = _player;
    if (p == null) return;
    final combat = p.playerReputation.get('combat');
    if (combat >= 80) {
      _unlockAchievement('war_hero');
    }
  }

  void _checkExplorerAchievement() {
    final p = _player;
    if (p == null) return;
    final visited = <String>{};
    visited.add(_worldState.currentLocation ?? '');
    if (visited.length >= 5) _unlockAchievement('explorer');
  }

  void _checkRichWizardAchievement() {
    final p = _player;
    if (p == null) return;
    if (totalWealth >= 100) _unlockAchievement('rich_wizard');
  }

  void _checkBookwormAchievement() {
    final p = _player;
    if (p == null) return;
    if (p.learnedSpells.length >= 10) _unlockAchievement('bookworm');
  }

  void _checkSocialButterflyAchievement() {
    final p = _player;
    if (p == null) return;
    final friendCount = _npcRegistry.values.where((n) => n.isAlive).length;
    if (friendCount >= 10) _unlockAchievement('social_butterfly');
  }

  void _checkDeepRelationshipAchievement() {
    for (final npc in _npcRegistry.values) {
      if (npc.affection >= 80) {
        _unlockAchievement('deep_relationship');
        return;
      }
    }
  }

  void _checkBetrayalSurvivorAchievement() {
    for (final npc in _npcRegistry.values) {
      if (npc.hasGrudge && npc.affection > npc.maxAffectionReached * 0.8) {
        _unlockAchievement('betrayal_survivor');
        return;
      }
    }
  }

  void _checkMonthlyEvolutionAchievement() {
    if (_worldState.recentEvents.where((e) => e.contains('月度世界演化')).length >= 3) {
      _unlockAchievement('monthly_evolution');
    }
  }

  void _checkGenerationArtistAchievement() {
    final count = _npcRegistry.values.where((n) => n.isGenerated).length;
    if (count >= 5) _unlockAchievement('generation_artist');
  }

  void _checkCGCollectorAchievement() {
    final p = _player;
    if (p == null) return;
    if (p.cgRecords.length >= 10) _unlockAchievement('cg_collector');
  }

  void _checkRelationshipMasterAchievement() {
    final highAffectionCount = _npcRegistry.values
        .where((n) => n.affection >= 60)
        .length;
    if (highAffectionCount >= 3) _unlockAchievement('relationship_master');
  }

  void _checkTimeMasterAchievement() {
    final startYear = 1991;
    final currentYear = _worldState.time.year;
    if (currentYear - startYear >= 2) _unlockAchievement('time_master');
  }

  void _checkAllAchievements() {
    _checkSkillAchievements();
    _checkWorldChangerAchievement();
    _checkWarHeroAchievement();
    _checkExplorerAchievement();
    _checkRichWizardAchievement();
    _checkBookwormAchievement();
    _checkSocialButterflyAchievement();
    _checkDeepRelationshipAchievement();
    _checkBetrayalSurvivorAchievement();
    _checkMonthlyEvolutionAchievement();
    _checkGenerationArtistAchievement();
    _checkCGCollectorAchievement();
    _checkRelationshipMasterAchievement();
    _checkTimeMasterAchievement();
  }

  void _incrementWorldLineDeviation(double delta) {
    final p = _player;
    if (p == null) return;
    p.worldLineDeviation = (p.worldLineDeviation + delta).clamp(0.0, 1.0);
    _checkWorldChangerAchievement();
  }

  // ==================== 时间推进 ====================
  void _advanceTimeForAction(String action) {
    int minutes = 15;
    if (action.contains('吃饭') || action.contains('用餐') || action.contains('早餐') || action.contains('午餐') || action.contains('晚餐')) {
      minutes = 30;
    } else if (action.contains('上课') || action.contains('听课') || action.contains('教室')) {
      minutes = 90;
    } else if (action.contains('图书馆') || action.contains('自习') || action.contains('学习') || action.contains('看书')) {
      minutes = 120;
    } else if (action.contains('魁地奇') || action.contains('训练')) {
      minutes = 120;
    } else if (action.contains('霍格莫德')) {
      minutes = 300;
    } else if (action.contains('禁林')) {
      minutes = 180;
    } else if (action.contains('睡觉') || action.contains('休息') || action.contains('就寝')) {
      minutes = 480;
    } else if (action.contains('对话') || action.contains('聊天') || action.contains('交谈') || action.contains('打招呼')) {
      minutes = 10;
    } else if (action.contains('探索') || action.contains('闲逛') || action.contains('散步')) {
      minutes = 60;
    }

    final oldDayOfYear = _worldState.time.dayOfYear;
    final oldMonth = _worldState.time.month;
    final oldYear = _worldState.time.year;
    _worldState.time.advanceMinutes(minutes);

    // 游戏周追踪（好感沉淀用）
    final newDayOfYear = _worldState.time.dayOfYear;
    if ((newDayOfYear ~/ 7) > (oldDayOfYear ~/ 7)) {
      _gameWeek++;
      _resetWeeklyAffectionCaps();
    }

    // 深夜触发满月标记
    if (_worldState.time.isFullMoon && !_worldState.specialMarkers.contains('🌙满月')) {
      _worldState.specialMarkers.add('🌙满月');
    } else if (!_worldState.time.isFullMoon) {
      _worldState.specialMarkers.remove('🌙满月');
    }

    // 同步旧字段
    _worldState.dayOfMonth = _worldState.time.day;
    _worldState.dayOfWeek = GameTime.weekdays[_worldState.time.weekday];
    _worldState.month = GameTime.months[_worldState.time.month - 1];

    // 学年推进检测（9月1日触发）
    _checkSchoolYearTransition(oldMonth, oldYear);

    // 事件锚点检测（按月份触发手写剧情骨架）
    _checkEventAnchors();

    _runConsistencyChecks();

    _checkMonthlyEvolution(oldMonth, oldYear);
  }

  // ==================== 学年推进系统 ====================

  /// 计算当前学年起始年份（9月起为新学年）
  int _schoolYearStartFor(int year, int month) {
    return month >= 9 ? year : year - 1;
  }

  /// 学年切换检测：当进入新的学年（9月）时，推进玩家与 NPC 年级
  void _checkSchoolYearTransition(int oldMonth, int oldYear) {
    final p = _player;
    if (p == null) return;
    final t = _worldState.time;

    final newStart = _schoolYearStartFor(t.year, t.month);
    if (_lastSchoolYearStart == 0) {
      // 首次初始化追踪（不触发晋升）
      _lastSchoolYearStart = newStart;
      return;
    }
    if (newStart <= _lastSchoolYearStart) return;

    // 跨越了一个或多个学年
    final yearsPassed = newStart - _lastSchoolYearStart;
    _lastSchoolYearStart = newStart;

    // 玩家已毕业则不再推进
    if (_worldState.graduated) {
      _updateAcademicYearLabel();
      return;
    }

    final oldGrade = p.grade ?? 1;
    final newGrade = oldGrade + yearsPassed;

    if (newGrade > 7) {
      // 毕业
      p.grade = 7;
      _worldState.graduated = true;
      _onPlayerGraduated(oldGrade);
    } else {
      p.grade = newGrade;
      _promoteNpcs(yearsPassed);
      _onSchoolYearStart(newGrade);
    }
    _updateAcademicYearLabel();
  }

  /// 更新学年标签（如 1992-1993）
  void _updateAcademicYearLabel() {
    final t = _worldState.time;
    final start = _schoolYearStartFor(t.year, t.month);
    _worldState.academicYear = '$start-${start + 1}';
    // 学期：9-12月第一学期，1-6月第二学期，7-8月暑假
    if (t.month >= 9) {
      _worldState.term = 'first';
    } else if (t.month <= 6) {
      _worldState.term = 'second';
    } else {
      _worldState.term = 'summer';
    }
  }

  /// 推进所有在校生 NPC 年级，七年级以上者毕业离校
  void _promoteNpcs(int yearsPassed) {
    final graduatedNames = <String>[];
    for (final npc in _npcRegistry.values) {
      if (npc.grade <= 0) continue; // 教职/成人不推进
      if (npc.graduated) continue;
      npc.grade += yearsPassed;
      if (npc.grade > 7) {
        npc.graduated = true;
        npc.grade = 7;
        graduatedNames.add(npc.name);
      }
    }
    if (graduatedNames.isNotEmpty) {
      _notifications.add('🎓 ${graduatedNames.take(5).join('、')}${graduatedNames.length > 5 ? '等' : ''} 已从霍格沃茨毕业');
      _worldState.addNarrativeEvent('🎓 一批高年级学生毕业了：${graduatedNames.take(5).join('、')}');
    }
  }

  /// 新学年开始的叙事与通知
  void _onSchoolYearStart(int newGrade) {
    final p = _player;
    if (p == null) return;
    _notifications.add('🏫 新学年开始：你升入了${newGrade}年级');
    _worldState.addNarrativeEvent('🏫 ${_worldState.time.year}年9月，你升入${newGrade}年级');
    _worldState.addMarker('⏳新学年');
    // 新学年重置原创NPC生成计数（通过清理标记实现每学年限额）
    debugPrint('🎓 学年推进：玩家升入${newGrade}年级');
  }

  /// 玩家毕业（七年级结束）
  void _onPlayerGraduated(int oldGrade) {
    final p = _player;
    if (p == null) return;
    _notifications.add('🎓 你从霍格沃茨毕业了！七年的魔法生涯画上句点。');
    _worldState.addNarrativeEvent('🎓 ${_worldState.time.year}年，你从霍格沃茨毕业');
    _worldState.addMarker('🎓毕业');
    debugPrint('🎓 玩家毕业（原${oldGrade}年级）');
    // 毕业结算：评估人生目标达成情况并生成结算报告
    _graduationSettlement();
  }

  // ==================== 毕业结算系统 ====================

  /// 评估目标毕业条件，返回 (条件描述, 是否达成) 列表
  List<(String, bool)> _evaluateGoalRequirement(GoalRequirement req) {
    final p = _player;
    if (p == null) return [];
    final lines = <(String, bool)>[];
    if (req.reputationDim != null) {
      final cur = p.playerReputation.get(req.reputationDim!);
      lines.add(('${p.playerReputation.labelOf(req.reputationDim!)} ≥ ${req.reputationMin}（当前 $cur）', cur >= req.reputationMin));
    }
    if (req.attributeKey != null) {
      final cur = p.attributes[req.attributeKey!] ?? 0;
      lines.add(('${_attrLabel(req.attributeKey!)} ≥ ${req.attributeMin}（当前 $cur）', cur >= req.attributeMin));
    }
    if (req.wealthMin > 0) {
      final cur = p.galleons + p.bankGalleons;
      lines.add(('资产 ≥ ${req.wealthMin} 加隆（当前 $cur）', cur >= req.wealthMin));
    }
    if (req.deepRelationsMin > 0) {
      final cur = _npcRegistry.values.where((n) => n.isAlive && n.affection >= 50).length;
      lines.add(('深厚羁绊（好感≥50）≥ ${req.deepRelationsMin} 人（当前 $cur）', cur >= req.deepRelationsMin));
    }
    if (req.worldLineMin > 0) {
      final cur = p.worldLineDeviation;
      lines.add(('世界线变动率 ≥ ${(req.worldLineMin * 100).toStringAsFixed(0)}%（当前 ${(cur * 100).toStringAsFixed(1)}%）', cur >= req.worldLineMin));
    }
    return lines;
  }

  /// 毕业结算：评估人生目标、解锁成就、生成结算报告（追加到当前剧情后）
  void _graduationSettlement() {
    final p = _player;
    if (p == null) return;

    _unlockAchievement('graduated');

    final goal = p.currentGoal != null ? goalByName(p.currentGoal!) : null;
    final reqLines = goal != null ? _evaluateGoalRequirement(goal.requirement) : <(String, bool)>[];
    final goalMet = reqLines.isNotEmpty && reqLines.every((e) => e.$2);
    if (goalMet) {
      _unlockAchievement('goal_achieved');
    }

    final buf = StringBuffer()
      ..writeln('╔══════════════════════════════════════╗')
      ..writeln('  🎓 毕业结算 · ${p.name}')
      ..writeln('╚══════════════════════════════════════╝')
      ..writeln();

    if (goal != null) {
      buf.writeln('【人生目标】${goal.name}');
      for (final (label, met) in reqLines) {
        buf.writeln('  ${met ? '✅' : '❌'} $label');
      }
      buf.writeln(goalMet
          ? '\n🏆 目标达成！你在霍格沃茨的七年，画上了一个方向明确的句号。'
          : '\n这个目标尚未完全达成——但毕业不是终点，你的人生仍可以继续书写。');
    } else {
      buf.writeln('【人生目标】未设定——你的七年平静而真实地流淌而过。');
    }

    final rep = p.playerReputation;
    final deepCount = _npcRegistry.values.where((n) => n.isAlive && n.affection >= 50).length;
    buf
      ..writeln()
      ..writeln('【七年统计】')
      ..writeln('· 声望：学术${rep.academic}｜社交${rep.social}｜战斗${rep.combat}｜道德${rep.moral}｜领导${rep.leadership}')
      ..writeln('· 资产：${p.galleons + p.bankGalleons} 加隆')
      ..writeln('· 深厚羁绊：$deepCount 人')
      ..writeln('· 世界线变动率：${(p.worldLineDeviation * 100).toStringAsFixed(1)}%')
      ..writeln('· 成就：${p.achievements.length} / ${achievementCatalog.length}')
      ..writeln()
      ..writeln('输入 /结局 可生成完整终章评语，或继续你的毕业后人生。');

    // 追加到当前剧情之后，保留本回合叙事
    _currentNarrative = _currentNarrative.isEmpty
        ? buf.toString().trim()
        : '$_currentNarrative\n\n${buf.toString().trim()}';
    _worldState.addNarrativeEvent('🎓 毕业结算完成${goalMet ? '·人生目标达成' : ''}');
  }

  /// 目标进度查询（/目标 进度）
  String _formatGoalProgress() {
    final p = _player;
    if (p == null) return '尚未创建角色。';
    final goal = p.currentGoal != null ? goalByName(p.currentGoal!) : null;
    if (goal == null) {
      return '尚未设定人生目标。输入 /目标 查看并设定。';
    }
    final lines = _evaluateGoalRequirement(goal.requirement);
    final met = lines.isNotEmpty && lines.every((e) => e.$2);
    final buf = StringBuffer()
      ..writeln('【目标进度】${goal.name}')
      ..writeln('『${goal.description}』')
      ..writeln();
    for (final (label, ok) in lines) {
      buf.writeln('${ok ? '✅' : '⬜'} $label');
    }
    buf.writeln();
    buf.writeln(met
        ? '🏆 所有毕业条件已达成！坚持到毕业即可在结算中获得「得偿所愿」。'
        : '继续朝着目标努力吧——毕业时将进行最终结算。');
    return buf.toString();
  }

  // ==================== 事件锚点系统 ====================

  /// 按当前月份/年级/时代检查并触发手写事件锚点
  void _checkEventAnchors() {
    final p = _player;
    if (p == null) return;
    if (_worldState.graduated) return; // 毕业后不再触发校内锚点

    final t = _worldState.time;
    final fired = _worldState.firedAnchorIds.toSet();
    final grade = p.grade ?? 1;

    final due = anchorsFor(
      month: t.month,
      grade: grade,
      era: _worldState.era,
      firedIds: fired,
    );
    if (due.isEmpty) return;

    // 每个回合最多注入一个锚点，避免信息过载；其余顺延
    final anchor = due.first;
    _worldState.firedAnchorIds.add(anchor.id);
    _pendingAnchorDirective = anchor.directive;
    _notifications.add('📜 剧情节点：${anchor.title}');
    _worldState.addNarrativeEvent('📜 ${anchor.title}');
    debugPrint('📜 事件锚点触发: ${anchor.id} (${anchor.title})');
  }

  void _resetWeeklyAffectionCaps() {
    for (final npc in _npcRegistry.values) {
      npc.affectionGainedThisWeek = 0;
    }
    debugPrint('📊 新的一周开始：好感周增量已重置');
  }

  void _checkMonthlyEvolution(int oldMonth, int oldYear) {
    final newMonth = _worldState.time.month;
    final newYear = _worldState.time.year;
    if (newMonth != oldMonth || newYear != oldYear) {
      _generateMonthlyEvent(newMonth, newYear);
    }
  }

  void _generateMonthlyEvent(int month, int year) {
    final templates = <String, List<String>>{
      'ministry': [
        '魔法部宣布了新一轮的魔法教育改革方案，涉及到所有魔法学校的课程调整。',
        '魔法部对黑魔法防御术进行了专项检查，霍格沃茨的师资队伍通过了严格审核。',
        '魔法部发布了新的禁咒名单，三种黑魔法被列入最高级别管制。',
        '魔法部与妖精家族达成了新的古灵阁运营协议，加强了对魔法经济的监管。',
      ],
      'hogwarts': [
        '霍格沃茨宣布了本学期的魁地奇比赛安排，各院队长已经开始紧张训练。',
        '霍格沃茨图书馆收到了一批珍贵的古籍捐赠，其中包括几本失传已久的魔法著作。',
        '霍格沃茨的幽灵们最近异常活跃，据说地下室里传来了奇怪的声响。',
        '霍格沃茨大礼堂进行了季节性装饰，墙壁上挂满了与当前月份相关的魔法旗帜。',
      ],
      'economy': [
        '古灵阁的金币汇率本月波动较大，加隆对英镑的比值创下了近年来的新高。',
        '魔法药品市场供应紧张，几种常用药水的价格上涨了约15%。',
        '魔法物品交易会在对角巷举行，吸引了来自全国各地的巫师商人。',
        '由于天气原因，猫头鹰邮递的效率有所下降，信件送达时间延迟了1-2天。',
      ],
      'dark': [
        '黑巫师的活动在欧洲大陆有所增加，魔法部派遣了更多的傲罗前往边境地区。',
        '一座废弃的城堡被黑巫师占据，魔法界对此高度关注。',
        '有关黑魔法社团的传闻在学生中流传，霍格沃茨加强了夜间巡逻。',
        '魔法部截获了一批非法交易的魔法生物，其中包括几只受保护的独角兽幼崽。',
      ],
      'creature': [
        '禁林中的独角兽族群迁徙了新的领地，生物学家对此进行了密切观察。',
        '一只罕见的凤凰在霍格沃茨上空出现了数天，引发了学生们的热烈讨论。',
        '家养小精灵权益促进会（S.P.E.W.）发起了新一轮的签名请愿活动。',
        '挪威脊背龙的幼崽在冰岛被发现，生物学家正在研究它的生活习性。',
      ],
    };

    final pool = <String>[];
    final monthKey = _monthSeasonKey(month);
    pool.addAll(templates[monthKey] ?? []);
    pool.addAll(templates['ministry']!);
    pool.addAll(templates['hogwarts']!);
    pool.addAll(templates['economy']!);
    if (_random.nextDouble() < 0.3) pool.addAll(templates['dark']!);
    if (_random.nextDouble() < 0.4) pool.addAll(templates['creature']!);

    pool.shuffle(_random);
    final event = '【${year}年${month}月·月度世界演化】${pool.first}';

    _worldState.recentEvents.insert(0, event);
    if (_worldState.recentEvents.length > 50) {
      _worldState.recentEvents.removeLast();
    }

    _worldState.housePoints = Map<String, int>.fromEntries(
      _worldState.housePoints.entries.map((e) {
        final raw = e.value + _random.nextInt(5) - 2;
        final newValue = raw.clamp(0, 9999).toInt();
        return MapEntry(e.key, newValue);
      }),
    );

    _notifications.add('🌍 $event');
    _worldState.addNarrativeEvent('🌍 $event');
  }

  String _monthSeasonKey(int month) {
    if (month >= 3 && month <= 5) return 'creature';
    if (month >= 6 && month <= 8) return 'dark';
    if (month >= 9 && month <= 11) return 'hogwarts';
    return 'ministry';
  }

  void _runConsistencyChecks() {
    final p = _player;
    if (p == null) return;
    final issues = <String>[];

    // ====== 资源值钳制 ======
    p.health = p.health.clamp(0, 100);
    p.magic = p.magic.clamp(0, 100);
    p.spirit = p.spirit.clamp(0, 100);
    p.satiety = p.satiety.clamp(0, 100);
    p.energy = p.energy.clamp(0, 100);

    // ====== 属性合理性检查 ======
    for (final entry in p.attributes.entries) {
      if (entry.value < 0) {
        p.attributes[entry.key] = 0;
        issues.add('属性"${entry.key}"负值，已归零');
      }
      if (entry.value > 100) {
        p.attributes[entry.key] = 100;
        issues.add('属性"${entry.key}"超过100，已钳制');
      }
    }

    // ====== 学院四维检查 ======
    for (final entry in p.houseDimensions.entries) {
      if (entry.value < 0) {
        p.houseDimensions[entry.key] = 0;
        issues.add('学院四维"${entry.key}"负值，已归零');
      }
      if (entry.value > 100) {
        p.houseDimensions[entry.key] = 100;
        issues.add('学院四维"${entry.key}"超过100，已钳制');
      }
    }

    // ====== 世界线变动率检查 ======
    if (p.worldLineDeviation < 0) {
      p.worldLineDeviation = 0;
      issues.add('世界线变动率负值，已修正');
    }
    if (p.worldLineDeviation > 1) {
      p.worldLineDeviation = 1;
      issues.add('世界线变动率超过100%，已钳制');
    }

    // ====== NPC好感与关系检查 ======
    for (final npc in _npcRegistry.values) {
      npc.affection = npc.affection.clamp(-100, 100);
      if (!npc.isAlive && p.relationships.containsKey(npc.id)) {
        issues.add('NPC "${npc.name}" 已死亡但仍在关系列表中');
      }
      if (npc.affection > npc.maxAffectionReached) {
        npc.maxAffectionReached = npc.affection;
      }
      if (npc.hasGrudge && npc.affection > npc.effectiveAffectionCap) {
        npc.affection = npc.effectiveAffectionCap;
        issues.add('NPC "${npc.name}" 好感超过背叛前水平，已钳制');
      }
    }

    // ====== 恋爱状态一致性检查 ======
    if (p.loveState.status != '单身') {
      if (p.loveState.partnerId == null || p.loveState.partnerName == null) {
        p.loveState.status = '单身';
        p.loveState.partnerId = null;
        p.loveState.partnerName = null;
        issues.add('恋爱状态不一致（缺少伴侣信息），已重置为单身');
      } else {
        final partnerNpc = _npcRegistry[p.loveState.partnerId];
        if (partnerNpc == null || !partnerNpc.isAlive) {
          p.loveState.status = '单身';
          p.loveState.partnerId = null;
          p.loveState.partnerName = null;
          issues.add('恋爱对象已不存在，已重置为单身');
        }
      }
    }

    // ====== 时间合理性检查 ======
    final year = _worldState.time.year;
    if (year < 1890 || year > 2100) {
      issues.add('年份异常: $year');
    }
    final month = _worldState.time.month;
    if (month < 1 || month > 12) {
      _worldState.time.month = month.clamp(1, 12);
      issues.add('月份越界，已修正');
    }
    final day = _worldState.time.day;
    if (day < 1 || day > 31) {
      _worldState.time.day = day.clamp(1, 31);
      issues.add('日期越界，已修正');
    }

    // ====== 时代一致性检查 ======
    final eraName = _worldState.era;
    final appEra = appProvider.era.name;
    if (eraName.isNotEmpty && eraName != appEra) {
      debugPrint('存档时代($eraName)与当前设置($appEra)不一致');
    }

    // ====== 货币合理性 ======
    if (p.galleons < 0) {
      p.galleons = 0;
      issues.add('加隆余额负值，已归零');
    }
    if (p.bankGalleons < 0) {
      p.bankGalleons = 0;
      issues.add('古灵阁存款负值，已归零');
    }

    // ====== 背包物品检查 ======
    p.inventory.removeWhere((item) => item.name.isEmpty);
    if (p.inventory.length > 100) {
      p.inventory.removeRange(100, p.inventory.length);
      issues.add('背包物品超过上限，已清理');
    }

    // ====== 声望合理性检查 ======
    final reputationFields = ['academic', 'social', 'combat', 'moral', 'leadership', 'dark'];
    for (final field in reputationFields) {
      final value = p.playerReputation.get(field);
      if (value < 0 || value > 100) {
        p.playerReputation.setValue(field, value.clamp(0, 100));
        issues.add('声望$field越界，已修正');
      }
    }

    // ====== 成就检查 ======
    _checkAllAchievements();

    if (issues.isNotEmpty) {
      _notifications.add('⚠️ 状态自修复：${issues.join('；')}');
      debugPrint('🛡️ 防崩坏自检: 修复${issues.length}项状态异常');
    }
  }

  void _fastForwardTime(int days) {
    final oldMonth = _worldState.time.month;
    final oldYear = _worldState.time.year;
    for (int i = 0; i < days; i++) {
      _worldState.time.advanceMinutes(24 * 60);
    }
    _worldState.dayOfMonth = _worldState.time.day;
    _worldState.dayOfWeek = GameTime.weekdays[_worldState.time.weekday];
    _worldState.month = GameTime.months[_worldState.time.month - 1];
    // 快进也要接入学年推进与事件锚点，避免跳过年份
    _checkSchoolYearTransition(oldMonth, oldYear);
    _checkEventAnchors();
  }

  // ==================== NPC 状态更新 ====================
  void _updateNPCsFromAction(String action) {
    // 消耗资源 - 大幅降低消耗，让玩家有更多精力进行活动
    final p = _player!;
    p.energy = max(0, p.energy - 2);  // 从5降到2
    p.satiety = max(0, p.satiety - 2);  // 从3降到2
    p.spirit = max(0, p.spirit - 1);  // 从2降到1

    // 扩展恢复关键词，让更多行动可以恢复精力
    if (action.contains('吃饭') || action.contains('用餐') || 
        action.contains('进食') || action.contains('吃东西')) {
      p.satiety = min(100, p.satiety + 30);
      p.energy = min(100, p.energy + 5);  // 吃饭也恢复少量精力
    }
    if (action.contains('睡觉') || action.contains('休息') || 
        action.contains('睡') || action.contains('歇') ||
        action.contains('躺') || action.contains('养') ||
        action.contains('放松') || action.contains('回房') ||
        action.contains('回宿舍') || action.contains('睡觉') ||
        action.contains('小憩')) {
      p.energy = min(100, p.energy + 50);  // 从40提升到50
      p.spirit = min(100, p.spirit + 30);  // 从20提升到30
      p.satiety = min(100, p.satiety + 5);
    }
    if (action.contains('冥想') || action.contains('打坐') ||
        action.contains('修炼') || action.contains('学习')) {
      p.spirit = min(100, p.spirit + 15);
      p.energy = min(100, p.energy + 5);
    }
    if (action.contains('散步') || action.contains('走') ||
        action.contains('逛') || action.contains('活动')) {
      p.energy = min(100, p.energy + 3);
    }

    // 每日随机触发好感微调
    for (final npc in _npcRegistry.values) {
      if (npc.affection > 0 && _random.nextDouble() < 0.05) {
        npc.affection = (npc.affection + 1).clamp(-100, 100);
        _checkAffectionAchievements(npc);
      }
    }

    // 检测表白时机（恋爱剧情推进时）
    if (p.loveState.status == '恋爱' && _random.nextDouble() < 0.1) {
      _spawnRomanticEvent();
    }
  }

  void _spawnRomanticEvent() {
    final p = _player;
    final partner = p?.loveState.partnerId;
    if (partner == null) return;
    final npc = _npcRegistry[partner];
    if (npc == null) return;

    _notifications.add('💕 与${npc.name}之间发生了一段浪漫插曲。');
    _worldState.addNarrativeEvent('💕 与${npc.name}之间发生了一段浪漫插曲。');
  }

  // ==================== 快速推进 ====================
  Future<void> fastForward(int days) async {
    _isLoading = true;
    notifyListeners();
    _fastForwardTime(days);
    _isLoading = false;
    notifyListeners();
  }

  // ==================== 查看人物 ====================
  Map<String, dynamic>? getViewableCharacter(String npcId) {
    final npc = _npcRegistry[npcId];
    if (npc == null || !_isNPCVisible(npc)) return null;

    final rel = _player?.relationships[npcId];
    return {
      'id': npc.id,
      'name': npc.name,
      'house': npc.house,
      'grade': npc.grade,
      'location': npc.currentLocation,
      'mood': npc.mood,
      'alive': npc.isAlive,
      'affection': npc.affection,
      'affectionStage': npc.affectionStage,
      'appearance': npc.appearance,
      'relationship': rel != null
          ? {'type': rel.relationType, 'level': rel.level}
          : null,
      'personality': npc.personality,
      'knowsAbout': npc.knowsAbout.take(3).toList(),
      'reputation': npc.reputation,
    };
  }

  bool _isNPCVisible(NPC npc) {
    if (_player == null) return false;
    if (_player!.relationships.containsKey(npc.id)) return true;
    if (npc.house == _player!.house) return true;
    if (npc.isCanon && _worldState.playerImpactScore > 0.5) return true;
    return false;
  }

  bool isNearby(String npcId) {
    final npc = _npcRegistry[npcId];
    if (npc == null || _player == null) return false;
    return npc.currentLocation == (_worldState.currentLocation ?? '');
  }

  int getAffection(String npcId) {
    final rel = _player?.relationships[npcId];
    if (rel != null) return rel.level;
    final npc = _npcRegistry[npcId];
    return npc?.affection ?? 0;
  }

  void travelTo(String location) {
    _worldState.currentLocation = location;
    notifyListeners();
  }

  /// 根据玩家行动累计影响力分数
  /// 每回合 +0.01，涉及原著NPC互动 +0.02，涉及关键剧情(恋爱/CG/成就) +0.05
  void _updatePlayerImpactScore(String action) {
    double delta = 0.01;

    if (_npcRegistry.isNotEmpty) {
      for (final npc in _npcRegistry.values) {
        if (npc.isCanon && action.contains(npc.name)) {
          delta += 0.02;
          break;
        }
      }
    }

    // 关键剧情关键词
    const keywords = ['恋爱', '表白', '冒险', '战斗', '发现', '秘密', '魂器', '黑魔法'];
    for (final kw in keywords) {
      if (action.contains(kw)) {
        delta += 0.02;
        break;
      }
    }

    _worldState.playerImpactScore = (_worldState.playerImpactScore + delta).clamp(0.0, 1.0);
  }

  // ==================== 好感度操作（供UI调用） ====================
  void adjustAffection(String npcId, int delta, {String? reason}) {
    updateNpcAffection(npcId, delta, reason: reason);
    final npc = _npcRegistry[npcId];
    if (npc != null) {
      _checkLocks(npc);
      _syncRelationshipLevel(npc);
    }
  }

  void _checkLocks(NPC npc) {
    if (npc.affection >= Balance.trustLockThreshold && !npc.hasLock('信任锁')) {
      npc.affectionLocks.add('信任锁');
    }
    if (npc.affection >= Balance.romanceLockThreshold && !npc.hasLock('情感锁')) {
      npc.affectionLocks.add('情感锁');
    }
  }

  void _syncRelationshipLevel(NPC npc) {
    final p = _player;
    if (p == null) return;
    final rel = p.relationships[npc.id];
    if (rel != null) {
      rel.level = npc.affection.clamp(0, 100);
    }
  }

  // ==================== DeepSeek 调用 ====================
  Future<ChatResult> _callDeepSeek(String prompt, {AiScene scene = AiScene.narrative}) async {
    if (_router == null) throw Exception('AI 服务未初始化');
    // 每次调用前刷新系统提示词，确保玩家动态状态（人生目标、身份模式等）实时注入
    if (_player != null) {
      _systemPrompt = _buildSystemPrompt();
    }
    final result = await _router!.chatComplete(
      scene: scene,
      prompt: prompt,
      systemPrompt: _systemPrompt ?? '',
      temperature: 0.85,
      maxTokens: scene == AiScene.narrative ? 3000 : 3500,  // 从1800/2500提高到3000/3500
    );
    // 使用 try-catch 保护 token 统计，避免因 API 返回格式异常导致崩溃
    try {
      _totalPromptTokens += result.usage.promptTokens;
      _totalCompletionTokens += result.usage.completionTokens;
      _totalTokens += result.usage.totalTokens;
      _lastRoundTokens = result.usage.totalTokens;
      _apiCalls++;
      notifyListeners();
    } catch (e) {
      debugPrint('[GameProvider] Token 统计异常(不影响游戏): $e');
    }
    return result;
  }

  // ==================== 解析响应 ====================

  /// 只解析叙事文本（不含选项），用于独立选项生成模式
  void _parseNarrativeOnly(String text) {
    _currentNarrative = '';
    _choices = [];

    // 移除结构化区块（选项、好感、声望等）
    var cleaned = text;
    cleaned = cleaned.replaceAllMapped(_reAffectionSection, (m) => '');
    cleaned = cleaned.replaceAllMapped(_reReputationSection, (m) => '');

    const stripSections = [
      '可选行动', '自由行动', '行动建议', '备选行动',
      '剧情选项', '下回合选择', '选择建议',
    ];
    for (final s in stripSections) {
      final pat = RegExp(r'【$s】[\s\S]*?(?=【|$)');
      cleaned = cleaned.replaceAllMapped(pat, (m) => '');
    }

    // 移除选项行（A.xxx, B.xxx 等）
    final lines = cleaned.split('\n');
    final narrativeLines = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      // 跳过选项格式的行
      if (_reChoiceOption.hasMatch(trimmed)) {
        continue;
      }
      narrativeLines.add(line);
    }

    var narrative = narrativeLines.join('\n');

    // 清理多余空行
    narrative = narrative.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

    // 自动段落排版
    narrative = StoryTextRenderer.autoParagraph(narrative);

    _currentNarrative = narrative;

    // 提取好感区块用于UI显示
    final extracted = StoryTextRenderer.extractAffectionSections(text);
    _lastAffectionSections = extracted['affectionSections'] as List<String>? ?? [];

    // 解析好感和声望变化（从原始文本）
    _parseAffectionChanges(text);
    _parseReputationChanges(text);

    // 标记NPC登场
    _markIntroducedFromNarrative(_currentNarrative);
  }

  void _parseResponse(String text) {
    final lines = text.split('\n');
    _currentNarrative = '';
    _choices = [];
    // 标记是否遇到过显式的【叙事】标题：遇到后严格按结构化走，
    // 否则走"整段正文直到选项区块开始之前"的宽松模式
    bool sawExplicitNarrativeMarker = false;
    bool inNarrative = false;
    // 显式区块（选项/好感/声望）之后就不再把后面的任何文字当正文
    bool anyExplicitBlockPassed = false;
    // 新增：连续选项计数，防止正文中的选项格式被误识别
    int consecutiveChoiceLines = 0;
    // 新增：正文最小长度阈值，低于此值不触发选项区切换
    const minNarrativeLength = 50;

    // Pass 1: Try structured parsing with explicit markers
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed == '【叙事】' || trimmed == '【剧情】' || trimmed == '【正文】') {
        sawExplicitNarrativeMarker = true;
        inNarrative = true;
        anyExplicitBlockPassed = false;
        consecutiveChoiceLines = 0;
        continue;
      }

      final isBlockHeader = trimmed.startsWith('【可选行动】') ||
          trimmed.startsWith('【自由行动】') ||
          trimmed.startsWith('【行动建议】') ||
          trimmed.startsWith('【备选行动】') ||
          trimmed.startsWith('【剧情选项】') ||
          trimmed.startsWith('【好感度变化】') ||
          trimmed.startsWith('【好感变化】') ||
          trimmed.startsWith('【声望变化】');
      if (isBlockHeader) {
        inNarrative = false;
        anyExplicitBlockPassed = true;
        consecutiveChoiceLines = 0;
        continue;
      }

      if (inNarrative) {
        // 在【叙事】块内部：除了好感度独立行外全收
        if (trimmed.isNotEmpty) {
          _currentNarrative += '$line\n';
        } else {
          _currentNarrative += '\n';
        }
        consecutiveChoiceLines = 0;
      } else if (!sawExplicitNarrativeMarker && !anyExplicitBlockPassed) {
        // 没有出现过显式【叙事】标题，且尚未进入任何结构化区块：
        // 这一段默认按正文处理（AI忘写标题的情况最常见）
        if (_reChoiceOption.hasMatch(trimmed)) {
          // 关键修复：只有当正文已经足够长（>50字）且连续2行都是选项格式时
          // 才认为进入选项区，防止正文中的选项格式被误识别
          if (_currentNarrative.trim().length >= minNarrativeLength) {
            consecutiveChoiceLines++;
            if (consecutiveChoiceLines >= 2) {
              anyExplicitBlockPassed = true;
              final action = trimmed.replaceFirst(_reChoiceOption, '').trim();
              if (action.isNotEmpty) {
                _choices.add(GameChoice(text: action, action: action));
              }
            } else {
              // 第一行选项格式，暂时仍当作正文处理（可能是剧情描述）
              if (trimmed.isNotEmpty) {
                _currentNarrative += '$line\n';
              } else {
                _currentNarrative += '\n';
              }
            }
          } else {
            // 正文太短，可能是开局或错误，仍然按选项处理
            anyExplicitBlockPassed = true;
            final action = trimmed.replaceFirst(_reChoiceOption, '').trim();
            if (action.isNotEmpty) {
              _choices.add(GameChoice(text: action, action: action));
            }
          }
        } else {
          consecutiveChoiceLines = 0;
          if (trimmed.isNotEmpty) {
            _currentNarrative += '$line\n';
          } else {
            _currentNarrative += '\n';
          }
        }
      } else if (_reChoiceOption.hasMatch(trimmed)) {
        // 在显式选项区块之后，逐行收集选项
        final action = trimmed.replaceFirst(_reChoiceOption, '').trim();
        if (action.isNotEmpty && _choices.length < 6) {
          _choices.add(GameChoice(text: action, action: action));
        }
      }
    }

    // 检测并截断"下回合泄漏"：如果正文中包含新的📅时间戳，
    // 说明 AI 把下回合的预告也输出了，需要截断
    final timestampPattern = RegExp(r'📅\s*\d{4}年\d{1,2}月\d{1,2}日');
    final narrativeLines = _currentNarrative.split('\n');
    final truncatedLines = <String>[];
    bool foundSecondTimestamp = false;
    for (final line in narrativeLines) {
      if (foundSecondTimestamp) break;
      if (timestampPattern.hasMatch(line.trim())) {
        if (truncatedLines.isNotEmpty) {
          foundSecondTimestamp = true;
          break;
        }
      }
      truncatedLines.add(line);
    }
    if (foundSecondTimestamp) {
      _currentNarrative = truncatedLines.join('\n').trimRight();
    }

    // Pass 2: 如果叙事 < 20 字，按"原始文本 - 好感/声望 - 选项区块"兜底提取，
    // 但注意兜底函数 _extractNarrativeFromRawText 已经不再做 split('\n\n').first
    // 的毁灭性截断，所以即使走到这里也能保住长文。
    if (_currentNarrative.trim().length < 20) {
      _extractNarrativeFromRawText(text);
    }

    // 先提取好感变化区块（用于独立卡片显示）
    final extracted = StoryTextRenderer.extractAffectionSections(text);
    _lastAffectionSections = extracted['affectionSections'] as List<String>? ?? [];
    var narrativeForDisplay = extracted['narrative'] as String? ?? _currentNarrative;

    narrativeForDisplay = narrativeForDisplay.replaceAllMapped(
      RegExp(r'【好感(?:度)?变化?】[\s\S]*?(?=【|$)'), (m) => '');
    narrativeForDisplay = narrativeForDisplay.replaceAllMapped(
      RegExp(r'【声望变化?】[\s\S]*?(?=【|$)'), (m) => '');
    narrativeForDisplay = narrativeForDisplay.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    narrativeForDisplay = narrativeForDisplay.replaceAllMapped(
      RegExp(r'【可选行动】[\s\S]*$'), (m) => '').trimRight();
    narrativeForDisplay = narrativeForDisplay.replaceAllMapped(
      RegExp(r'【自由行动】[\s\S]*$'), (m) => '').trimRight();

    // 自动段落排版（为无分行的 AI 输出插入合理段落）
    narrativeForDisplay = StoryTextRenderer.autoParagraph(narrativeForDisplay);
    narrativeForDisplay = narrativeForDisplay
        .replaceAll(_reMultiNewline, '\n\n')
        .trim();

    _currentNarrative = narrativeForDisplay;

    // Pass 3: 若依然正文为空，才生成兜底叙事（兜底叙事的特点：短、单段、以📅开头）
    if (_currentNarrative.isEmpty) {
      _currentNarrative = _generateFallbackNarrative();
    }

    // Parse affection changes（总是从完整原始响应解析，而不是从裁剪后的正文中解析）
    _parseAffectionChanges(text);

    // Parse reputation changes
    _parseReputationChanges(text);

    // 根据剧情文本中出现的人名，标记 NPC 为已登场（让世界页和通讯列表更准确）
    _markIntroducedFromNarrative(_currentNarrative);

    if (_choices.isEmpty) {
      // 先尝试从原始文本中智能提取选项（防止解析逻辑遗漏）
      final extractedChoices = _extractChoicesFromRawText(text);
      if (extractedChoices.isNotEmpty) {
        _choices.addAll(extractedChoices);
      } else {
        // 最后才使用兜底选项（但现在也基于剧情生成，而不是静态位置选项）
        _choices.addAll(_generateContextualFallbackChoices());
      }
    }
    // 避免出现过多选项：裁剪到 4 个
    if (_choices.length > 4) {
      _choices = _choices.sublist(0, 4);
    }

    if (_turnCount > 0 && (_turnCount % 5 == 0 || _lastPlayerAction.contains(RegExp(r'(与|和|跟|找|邀|问|对话|聊天|约会|见面|散步|陪|一起|独处|深入|表白|感情|心动)')))) {
      checkNPCConfessions();
    }

    _checkSkillAchievements();
    _checkWorldChangerAchievement();
    _checkWarHeroAchievement();

    // 每10回合增加少量世界线变动率
    if (_turnCount % 10 == 0) {
      _incrementWorldLineDeviation(0.005);
    }

    notifyListeners();
  }

  void _extractNarrativeFromRawText(String text) {
    var cleaned = text;

    // 1. 先删【好感度变化】和【声望变化】整块（它们是结构化输出区块，不属于正文叙事）
    cleaned = cleaned.replaceAllMapped(_reAffectionSection, (m) => '');
    cleaned = cleaned.replaceAllMapped(_reReputationSection, (m) => '');

    // 2. 删除其他已知结构化区块（整体移除，连同标题行一起）
    const stripSections = [
      '可选行动', '自由行动', '行动建议', '备选行动',
      '剧情选项', '下回合选择', '选择建议',
    ];
    for (final s in stripSections) {
      // 从出现 【$s】 或 行首 $s： 开始，到下一个【 标题 或 末尾结束
      final pat = RegExp(
        r'(?:【' + RegExp.escape(s) + r'】|^\s*' + RegExp.escape(s) + r'\s*[：:])[\s\S]*?(?=\n【|$)',
        multiLine: true,
      );
      cleaned = cleaned.replaceAllMapped(pat, (m) => '');
    }

    // 3. 找到「选项区块」的起点：某一行以「A./B./1./一、A)」开头且后面是文字
    //    把起点之后的内容全部认为是选项而丢弃
    final choiceMatch = _reChoiceMultiLine.firstMatch(cleaned);
    if (choiceMatch != null) {
      int end;
      if (choiceMatch.group(0)!.startsWith('\n')) {
        end = choiceMatch.start + 1; // 保留换行，让正文末尾完整
      } else {
        end = choiceMatch.start;
      }
      cleaned = cleaned.substring(0, end);
    }
    // 注意：已经不再用 split('\n\n').first 这种会把正文长文裁成第一段的危险做法
    // 叙事区的完整性对游戏体验至关重要（哪怕读回带残留文字，总比丢剧情强）

    // 4. 去掉【章节标题】等方括号记号但保留文字内容之间的空行
    cleaned = cleaned
        .replaceAllMapped(RegExp(r'^【[^】\n]*】\s*$', multiLine: true), (m) => '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    if (cleaned.isNotEmpty && cleaned.length > 10) {
      _currentNarrative = cleaned;
    }
  }

  String _generateFallbackNarrative() {
    final p = _player;
    if (p == null) return '你站在霍格沃茨的走廊上，等待着下一段旅程。';

    final location = _worldState.currentLocation ?? '霍格沃茨';
    final time = _worldState.timestamp;
    final weather = _worldState.weather ?? '晴朗';

    final fallbacks = [
      '📅 $time\n\n你在$location，感受着魔法世界的脉搏。周围的一切都在等待你的下一步行动。',
      '📅 $time\n\n$location的空气中弥漫着魔法的气息。$weather的天气让人想继续探索这个奇妙的世界。',
      '📅 $time\n\n作为一名${p.grade}年级的学生，你在$location经历着霍格沃茨的又一天。每件事都可能改变故事的走向。',
      '📅 $time\n\n${p.name}，你身处$location。接下来会发生什么，完全取决于你的选择。',
    ];

    final idx = _turnCount % fallbacks.length;
    return fallbacks[idx];
  }

  List<GameChoice> _generateFallbackChoices() {
    final location = _worldState.currentLocation ?? '霍格沃茨';

    final locationChoices = {
      '霍格沃茨': [
        ('去教室上课', '前往教室学习'),
        ('在走廊散步', '在走廊里走动'),
        ('去大礼堂', '前往大礼堂'),
        ('找朋友聊天', '与朋友交谈'),
      ],
      '霍格莫德村': [
        ('去三把扫帚酒吧', '前往三把扫帚'),
        ('逛蜂蜜公爵糖果店', '去糖果店'),
        ('拜访邮局', '去邮局寄信'),
        ('返回霍格沃茨', '回到学校'),
      ],
      '对角巷': [
        ('去魔杖店', '前往奥利凡德'),
        ('逛魔法部', '去魔法部'),
        ('去古灵阁', '去古灵阁银行'),
        ('返回霍格沃茨', '回到学校'),
      ],
      '禁林': [
        ('小心深入探索', '深入禁林'),
        ('观察神奇生物', '观察生物'),
        ('原路返回', '返回安全区'),
        ('寻找光源', '寻找光源'),
      ],
    };

    final options = locationChoices[location] ?? [
      ('继续前进', '继续探索'),
      ('仔细观察', '观察周围'),
      ('与人交谈', '和周围的人交流'),
      ('返回原地', '回到之前的位置'),
    ];

    final idx = _turnCount % options.length;
    final rotated = [
      options[idx],
      options[(idx + 1) % options.length],
      options[(idx + 2) % options.length],
    ];

    return rotated
        .map((e) => GameChoice(text: e.$1, action: e.$2))
        .toList();
  }

  /// 从AI原始响应文本中智能提取选项（用于解析失败后的兜底提取）
  List<GameChoice> _extractChoicesFromRawText(String text) {
    final choices = <GameChoice>[];
    final lines = text.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // 直接使用预编译的正则，匹配所有选项格式
      final match = _reChoiceOption.firstMatch(trimmed);
      if (match != null) {
        final action = trimmed.replaceFirst(_reChoiceOption, '').trim();
        if (action.isNotEmpty && action.length >= 2) {
          choices.add(GameChoice(text: action, action: action));
        }
      }

      if (choices.length >= 4) break;
    }

    return choices;
  }

  /// 独立生成选项：接收已生成的剧情文本，让 AI 专门基于此生成选项
  Future<List<GameChoice>> _generateChoicesSeparately(String narrative) async {
    if (_router == null) return [];

    final currentLoc = _worldState.currentLocation ?? '';
    final timestamp = _worldState.timestamp;
    final playerAction = _lastPlayerAction;

    final choicePrompt = '''你是一个游戏剧情选项生成器。请根据以下剧情内容，生成 4 个互斥的玩家选择。

【当前剧情】
$narrative

【当前场景】$timestamp｜$currentLoc
【玩家刚执行的行动】$playerAction

【要求】
- 生成 4 个选项，每个选项体现不同的策略或态度
- 选项必须与剧情紧密相关，不能脱离当前场景
- 选项风格要符合霍格沃茨魔法世界的背景
- 每个选项一行，使用以下格式：
  A.选项文字
  B.选项文字
  C.选项文字
  D.选项文字

【示例格式】
A.勇敢地走上前，询问发生了什么事
B.谨慎地躲在一旁观察情况
C.立刻去找其他同学来帮忙
D.尝试用魔法解决眼前的问题

请直接输出选项，不要添加任何其他说明。''';

    try {
      final response = await _callDeepSeek(
        choicePrompt,
        scene: AiScene.choice,
      );

      final content = response.content.trim();
      final choices = <GameChoice>[];
      final lines = content.split('\n');

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        final match = _reChoiceOption.firstMatch(trimmed);
        if (match != null) {
          final action = trimmed.replaceFirst(_reChoiceOption, '').trim();
          if (action.isNotEmpty && action.length >= 2) {
            choices.add(GameChoice(text: action, action: action));
          }
        }

        if (choices.length >= 4) break;
      }

      return choices;
    } catch (e) {
      debugPrint('独立选项生成失败(回退到文本解析): $e');
      return [];
    }
  }

  /// 基于当前上下文生成的兜底选项（比静态位置选项更智能）
  List<GameChoice> _generateContextualFallbackChoices() {
    final currentLoc = _worldState.currentLocation ?? '';
    final narrativeLower = _currentNarrative.toLowerCase();
    final playerAction = _lastPlayerAction;

    // 基于玩家最近的行动生成相关选项
    final actionRelatedChoices = <GameChoice>[];

    // 如果有玩家行动，生成延续性选项
    if (playerAction.isNotEmpty) {
      actionRelatedChoices.addAll([
        GameChoice(text: '$playerAction（继续）', action: '$playerAction（继续）'),
        GameChoice(text: '改变策略', action: '改变策略'),
      ]);
    }

    // 基于剧情内容生成情境相关选项
    final narrativeBasedChoices = <GameChoice>[];
    
    if (narrativeLower.contains('决斗') || narrativeLower.contains('战斗') || narrativeLower.contains('对抗')) {
      narrativeBasedChoices.addAll([
        GameChoice(text: '应战', action: '应战'),
        GameChoice(text: '寻求帮助', action: '寻求帮助'),
      ]);
    }
    if (narrativeLower.contains('对话') || narrativeLower.contains('交谈') || narrativeLower.contains('聊天')) {
      narrativeBasedChoices.addAll([
        GameChoice(text: '继续交谈', action: '继续交谈'),
        GameChoice(text: '告辞离开', action: '告辞离开'),
      ]);
    }
    if (narrativeLower.contains('受伤') || narrativeLower.contains('疼痛') || narrativeLower.contains('流血')) {
      narrativeBasedChoices.addAll([
        GameChoice(text: '寻求医疗帮助', action: '寻求医疗帮助'),
        GameChoice(text: '自己处理伤势', action: '自己处理伤势'),
      ]);
    }
    if (narrativeLower.contains('发现') || narrativeLower.contains('找到') || narrativeLower.contains('看到')) {
      narrativeBasedChoices.addAll([
        GameChoice(text: '仔细查看', action: '仔细查看'),
        GameChoice(text: '报告他人', action: '报告他人'),
      ]);
    }
    if (narrativeLower.contains('魔法') || narrativeLower.contains('咒语') || narrativeLower.contains('施法')) {
      narrativeBasedChoices.addAll([
        GameChoice(text: '尝试施法', action: '尝试施法'),
        GameChoice(text: '研究魔法理论', action: '研究魔法理论'),
      ]);
    }

    // 基于当前地点生成基础选项
    final locationChoices = {
      '霍格沃茨': [
        ('继续探索', '继续探索'),
        ('找人询问', '找人询问'),
        ('观察环境', '观察环境'),
      ],
      '霍格莫德村': [
        ('继续逛街', '继续逛街'),
        ('进店看看', '进店看看'),
        ('返回学校', '返回霍格沃茨'),
      ],
      '对角巷': [
        ('继续购物', '继续购物'),
        ('逛其他店铺', '逛其他店铺'),
        ('返回霍格沃茨', '返回霍格沃茨'),
      ],
      '禁林': [
        ('小心前进', '小心前进'),
        ('观察周围', '观察周围'),
        ('原路返回', '原路返回'),
      ],
      '大礼堂': [
        ('继续用餐', '继续用餐'),
        ('与人交谈', '与人交谈'),
        ('离席活动', '离席活动'),
      ],
      '教室': [
        ('认真听讲', '认真听讲'),
        ('做笔记', '做笔记'),
        ('课后请教', '课后请教'),
      ],
      '图书馆': [
        ('查阅资料', '查阅资料'),
        ('安静阅读', '安静阅读'),
        ('借阅书籍', '借阅书籍'),
      ],
    };

    final locationOptions = locationChoices[currentLoc] ?? [
      ('继续前进', '继续前进'),
      ('仔细观察', '仔细观察'),
      ('与人交谈', '与人交谈'),
    ];

    final fallbackChoices = locationOptions
        .map((e) => GameChoice(text: e.$1, action: e.$2))
        .toList();

    // 合并所有选项：优先剧情相关 > 玩家行动相关 > 地点相关
    final result = <GameChoice>[];
    if (narrativeBasedChoices.isNotEmpty) {
      result.addAll(narrativeBasedChoices.take(2));
    }
    if (actionRelatedChoices.isNotEmpty) {
      result.addAll(actionRelatedChoices.take(2));
    }
    result.addAll(fallbackChoices);

    // 去重并限制数量
    final seen = <String>{};
    final unique = <GameChoice>[];
    for (final c in result) {
      if (seen.add(c.text) && unique.length < 4) {
        unique.add(c);
      }
    }

    return unique;
  }

  // ==================== Token 优化：上下文截断 + 状态精简 ====================

  /// 截断叙事上下文，只保留末尾 maxChars 字，保证连贯性同时控制 token
  String _truncateNarrativeContext(String narrative, int maxChars) {
    if (narrative.length <= maxChars) return narrative;
    final cut = narrative.length - maxChars;
    return '…（前情略）${narrative.substring(cut)}';
  }

  /// 把一回合剧情加入近期缓冲，裁剪到最近 N 回合
  void _appendRecentTurn(String narrative) {
    final trimmed = narrative.trim();
    if (trimmed.isEmpty) return;
    _recentTurns.add(trimmed);
    while (_recentTurns.length > _maxRecentTurns) {
      _recentTurns.removeAt(0);
    }
  }

  // ==================== 剧情摘要机制：每10回合压缩历史 ====================

  /// 待摘要缓冲上限：摘要服务反复失败时防止缓冲无限膨胀撑爆后续请求
  static const int _maxPendingSummaryChars = 6000;

  void _accumulateForSummary(String newNarrative) {
    _pendingSummary += '$newNarrative\n';
    if (_pendingSummary.length > _maxPendingSummaryChars) {
      // 保留最近的剧情（尾部），丢弃最早的部分
      final cut = _pendingSummary.length - _maxPendingSummaryChars;
      _pendingSummary = '…（更早剧情略）\n${_pendingSummary.substring(cut)}';
    }
  }

  Future<void> _summarizeNarrative() async {
    if (_pendingSummary.length < 50) {
      _pendingSummary = '';
      return;
    }

    // 摘要长度随游戏进度逐步放宽，避免长线信息被过度压缩丢失
    final limit = _turnCount <= 40
        ? 300
        : (_turnCount <= 100 ? 500 : 700);
    final relationSnapshot = _buildRelationshipSnapshot();

    // 关键改进：明确要求 AI 只保留"人物关系"和"重要转折"，不保留具体场景描述
    // 这样开局的"车站"、"检票"等场景会被自然淘汰，只保留"与赫敏建立友谊"、"被分到格兰芬多"等重要信息
    final prompt = '''请将以下剧情内容压缩成摘要。重要规则：
1. 只保留【人物关系变化】和【重要剧情转折】
2. 淘汰具体场景描述（如"在车站"、"在教室"等地点信息），这些会干扰后续剧情生成
3. 淘汰具体行动描述（如"检票上车"、"拿出魔杖"等），除非是关键转折点
4. 保留 NPC 好感度变化（如"赫敏:友好+10"）、学院分配、重要事件等
5. 用简洁的第三人称

【前情摘要】
${_narrativeSummary.isNotEmpty ? _narrativeSummary : '（开局）'}

【新剧情】
$_pendingSummary

【当前关系状态】（以此为准校准）
${relationSnapshot.isNotEmpty ? relationSnapshot : '暂无'}

请输出：
1. 精简剧情摘要（不超过$limit字，聚焦关系和转折，不要保留具体场景）
2. 末尾单独一行【关系】列出当前重要NPC的关系状态（如：赫敏:友好/72；马尔福:敌对/-30）''';

    try {
      final result = await _callDeepSeek(
        prompt,
        scene: AiScene.summary,
      );

      _narrativeSummary = result.content.trim();
      _pendingSummary = '';
      debugPrint('✅ 剧情摘要已更新 (${_narrativeSummary.length}字)');
    } catch (e) {
      debugPrint('❌ 摘要生成失败: $e');
    }
  }

  /// 生成当前重要NPC关系快照（取好感绝对值最高的前5位）
  String _buildRelationshipSnapshot() {
    final npcs = _npcRegistry.values.where((n) => n.affection != 0).toList()
      ..sort((a, b) => b.affection.abs().compareTo(a.affection.abs()));
    return npcs.take(5)
        .map((n) => '${n.name}:${n.affectionStage}/${n.affection}')
        .join('；');
  }

  /// 只在状态异常时输出状态标签（HP低/MP低/精力低/受伤），正常则不写
  String _buildStatusTag(Player p) {
    final tags = <String>[];
    if (p.health <= 30) tags.add('HP${p.health}');
    if (p.magic <= 20) tags.add('MP${p.magic}');
    if (p.energy <= 20) tags.add('精力${p.energy}');
    if (p.injuries.isNotEmpty) {
      tags.add(p.injuries.take(2).join('、'));
    }
    if (tags.isEmpty) return '';
    return '异常:${tags.join('｜')}';
  }

  /// 根据行动关键词，只在关键剧情节点临时注入相关上下文（平时不注入）
  String _buildCriticalContext(String action) {
    final p = _player;
    if (p == null) return '';
    final a = action.toLowerCase();
    final parts = <String>[];

    // 战斗/冲突 → 注入关键属性、魔咒、HP
    if (a.contains(RegExp(r'(战斗|决斗|攻击|防御|施展咒语|施法|黑魔法|施咒|念咒|反击)'))) {
      final combatAttrs = p.attributes.entries
          .where((e) => e.value != 0)
          .take(3)
          .map((e) => '${_attrLabel(e.key)}:${e.value}')
          .join(' ');
      if (combatAttrs.isNotEmpty) parts.add('【战斗】$combatAttrs');
      if (p.learnedSpells.isNotEmpty) {
        final spells = p.learnedSpells.entries.take(3).map((e) => e.key).join('、');
        parts.add('魔咒:$spells');
      }
      parts.add('HP:${p.health} MP:${p.magic}');
    }

    // 学业/考试 → 注入相关属性
    if (a.contains(RegExp(r'(上课|考试|测验|作业|复习|学习|论文|写论文|做功课)'))) {
      final study = p.attributes.entries
          .where((e) => const {'智慧', '魔力', '勤奋'}.contains(_attrLabel(e.key)))
          .where((e) => e.value != 0)
          .map((e) => '${_attrLabel(e.key)}:${e.value}')
          .join(' ');
      if (study.isNotEmpty) parts.add('【学业】$study');
    }

    // 社交/对话：若行动中提到具体NPC名则精准注入其好感，否则按关键词注入
    final mentioned = _npcRegistry.values
        .where((n) => action.contains(n.name))
        .toList();
    if (mentioned.isNotEmpty) {
      final affs = mentioned.take(2)
          .map((n) => '${n.name}:好感${n.affection}(${n.affectionStage})')
          .join('；');
      parts.add('【关系】$affs');
    } else if (a.contains(RegExp(r'(约会|表白|心动|拥抱|接吻|单独见面|私聊)'))) {
      final affs = _formatAffections(maxEntries: 2);
      if (affs.isNotEmpty && !affs.contains('暂无深入关系')) parts.add('【关系】$affs');
    }

    // 购物/交易 → 注入金币和前3背包物品
    if (a.contains(RegExp(r'(购买|出售|购物|交易|取钱|存钱|存取古灵阁)'))) {
      parts.add('【经济】加隆:${p.galleons} 银行:${p.bankGalleons}');
      if (p.inventory.isNotEmpty) {
        final inv = p.inventory.take(3).map((e) => e.name).join('、');
        parts.add('背包:$inv');
      }
    }

    return parts.isNotEmpty ? '【状态】\n${parts.join('\n')}' : '';
  }

  /// 构建场景上下文信息（当前存在的NPC、时间提示等）
  String _buildSceneContext() {
    final parts = <String>[];

    // 防御：_worldState 有默认值（非空）但为防止未来改类型，统一局部变量引用；
    // _player 为可空类型，必须判空
    final ws = _worldState;
    final p = _player;

    // _worldState 始终非空，此处无需 null 判断（避免 analyzer unnecessary_null_comparison）
    final npcsHere = npcsInCurrentLocation();
    if (npcsHere.isNotEmpty) {
      final npcNames = npcsHere.map((n) {
        final status = n.isAlive ? n.affection.toString() : '';
        return '${n.name}$status';
      }).join('、');
      parts.add('【在场】$npcNames');
    }

    final hour = ws.time.hour;
    final timeDesc = hour >= 22 || hour < 6 ? '深夜' :
                     hour >= 18 ? '夜晚' :
                     hour >= 14 ? '下午' :
                     hour >= 10 ? '上午' : '清晨';
    parts.add('【时段】$timeDesc·${ws.time.formattedTime}');

    if (p != null && p.energy < 30) {
      parts.add('【提示】玩家精力较低，建议休息');
    }

    return parts.join('\n');
  }

  /// 获取当前场景中的NPC
  List<NPC> npcsInCurrentLocation() {
    final location = _worldState.currentLocation;
    if (location == null || location.isEmpty) return [];
    return _npcRegistry.values.where((npc) {
      return npc.currentLocation.toLowerCase().contains(location.toLowerCase());
    }).toList();
  }

  void _parseAffectionChanges(String text) {
    // 移除 _npcRegistry.isEmpty 检查，允许在空注册表时也能工作
    final sectionPattern = RegExp(r'【好感(?:度)?变化?】[\s\S]*?(?=【|$)');
    final sectionMatch = sectionPattern.firstMatch(text);
    if (sectionMatch == null) return;
    final section = sectionMatch.group(0)!.replaceFirst(sectionPattern, '').trim();
    if (section.isEmpty) return;
    for (final line in section.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final match = RegExp(r'^(.*?)[:：]\s*([+-]?\d+)').firstMatch(trimmed);
      if (match == null) continue;
      var npcName = match.group(1)!.trim();
      var delta = int.tryParse(match.group(2)!) ?? 0;
      if (delta == 0 || npcName.isEmpty) continue;
      npcName = npcName.replaceFirst(RegExp(r'[（(].*?[）)]'), '').trim();
      if (npcName.isEmpty) continue;
      if (delta > 5) delta = (delta * 0.5).round().clamp(1, 5);
      if (delta < -5) delta = (delta * 0.7).round().clamp(-5, -1);
      try {
        NPC? npc;
        // 先查找已存在的NPC
        if (_npcRegistry.isNotEmpty) {
          try {
            npc = _npcRegistry.values.firstWhere((n) => n.name == npcName);
          } catch (_) {
            for (final n in _npcRegistry.values) {
              if (n.name.contains(npcName) || npcName.contains(n.name)) {
                npc = n;
                break;
              }
            }
            if (npc == null) {
              for (final n in _npcRegistry.values) {
                final surname = n.name.split('·').isNotEmpty ? n.name.split('·').last : n.name;
                if (npcName.contains(surname) || surname.contains(npcName)) {
                  npc = n;
                  break;
                }
              }
            }
          }
        }
        
        // 如果找不到NPC，自动注册一个新的
        if (npc == null && npcName.length >= 2) {
          final id = 'aff_${DateTime.now().millisecondsSinceEpoch}_${_npcRegistry.length}';
          npc = _createAutoGeneratedNPC(id, npcName);
          _npcRegistry[id] = npc;
          markNpcIntroduced(npc);
          debugPrint('[好感系统] 自动注册NPC: $npcName (id: $id)');
        }
        
        if (npc != null) {
          updateNpcAffection(npc.id, delta, reason: '剧情互动');
          _checkLocks(npc);
          _syncRelationshipLevel(npc);
          _checkAffectionAchievements(npc);
        }
      } catch (e) {
      }
    }
  }

  void _parseReputationChanges(String text) {
    if (_player == null) return;
    final sectionPattern = RegExp(r'【声望变化?】[\s\S]*?(?=【|$)');
    final sectionMatch = sectionPattern.firstMatch(text);
    if (sectionMatch == null) return;
    final section = sectionMatch.group(0)!.replaceFirst(sectionPattern, '').trim();
    if (section.isEmpty) return;
    for (final line in section.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final match = RegExp(r'^(.*?)[:：]\s*([+-]?\d+)').firstMatch(trimmed);
      if (match == null) continue;
      final dim = match.group(1)!.trim();
      final delta = int.tryParse(match.group(2)!) ?? 0;
      if (delta == 0 || dim.isEmpty) continue;
      try {
        _player!.playerReputation.add(dim, delta);
      } catch (e) {
      }
    }
  }

  // ==================== 更多建议（本地生成，不消耗 token） ====================
  Future<void> generateMoreSuggestions() async {
    if (_player == null || _isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final suggestions = _generateLocalSuggestions();
      if (suggestions.isEmpty) {
        _error = '暂时想不出更多建议，请继续';
      } else {
        _choices = suggestions;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<GameChoice> _generateLocalSuggestions() {
    final location = _worldState.currentLocation ?? '霍格沃茨';
    final house = _player!.house ?? '';
    final personality = _player!.personalityTraits;
    final narrativeLower = _currentNarrative.toLowerCase();

    final bucket = <String, List<String>>{
      'classroom': [
        '认真听教授讲课并做笔记',
        '举手回答教授的提问',
        '与邻座同学小声讨论课堂内容',
        '对教授的讲解提出疑问',
        '利用上课时间偷偷翻阅其他书籍',
      ],
      'great_hall': [
        '前往大礼堂享用早餐',
        '与舍友讨论今天的课程安排',
        '观察四周的同学和幽灵',
        '向魁地奇球队的同学打听训练情况',
        '阅读《预言家日报》了解近期新闻',
      ],
      'library': [
        '查阅相关资料完成作业',
        '在禁书区寻找有趣的书',
        '与图书馆管理员交流',
        '研究某门学科的进阶内容',
        '整理笔记并复习重点',
      ],
      'corridor': [
        '在走廊上与同学闲聊',
        '前往下一节课的教室',
        '观察走廊上的画像与装饰物',
        '和路过的幽灵打声招呼',
        '去盥洗室整理一下',
      ],
      'outside': [
        '在草坪上晒太阳放松',
        '观看魁地奇球队训练',
        '探索城堡周围的小径',
        '和朋友一起散步聊天',
        '观察禁林边缘的动植物',
      ],
      'common_room': [
        '在公共休息室与舍友聊天',
        '练习今天所学的魔咒',
        '整理物品与学习资料',
        '玩一局巫师棋放松',
        '写一封家书',
      ],
      'forbidden_forest': [
        '小心翼翼地探索森林边缘',
        '寻找稀有草药',
        '观察神奇生物的踪迹',
        '沿原路返回，避免深入',
        '留下标记以便返回',
      ],
      'diagon_alley': [
        '前往魔杖店/书店/药店采购',
        '在三把扫帚喝一杯黄油啤酒',
        '逛逛恶作剧商店淘点新奇货',
        '打听最新的魔法界传闻',
        '留意周围可疑的人物',
      ],
      'hospital': [
        '去医疗翼探望受伤的同学',
        '向庞弗雷夫人请教健康问题',
        '领取常用的治疗药水',
        '在医疗翼休息片刻',
        '了解常见伤病的处理方法',
      ],
      'duel_club': [
        '报名加入决斗俱乐部',
        '观摩高年级学生的切磋',
        '与同学进行安全的练习',
        '向助教请教防御技巧',
        '研究非战斗类的实用魔咒',
      ],
      'default': [
        '继续前进，看看会发生什么',
        '观察周围环境，留意细节',
        '与附近的NPC交流',
        '回到熟悉的地方',
        '尝试一个新的地点',
      ],
    };

    String key = 'default';
    final loc = location.toLowerCase();
    if (loc.contains('教室') || loc.contains('classroom') || loc.contains('讲堂')) key = 'classroom';
    if (loc.contains('大礼堂') || loc.contains('great hall')) key = 'great_hall';
    if (loc.contains('图书馆') || loc.contains('library')) key = 'library';
    if (loc.contains('走廊') || loc.contains('corridor')) key = 'corridor';
    if (loc.contains('城堡外') || loc.contains('outside') || loc.contains('草坪')) key = 'outside';
    if (loc.contains('公共休息室') || loc.contains('common')) key = 'common_room';
    if (loc.contains('禁林') || loc.contains('forbidden')) key = 'forbidden_forest';
    if (loc.contains('对角巷') || loc.contains('diagon')) key = 'diagon_alley';
    if (loc.contains('医疗翼') || loc.contains('hospital')) key = 'hospital';
    if (loc.contains('决斗') || loc.contains('duel')) key = 'duel_club';

    // 情境追加：根据叙事关键词添加专属建议
    final extra = <String>[];
    if (narrativeLower.contains('魁地奇') || narrativeLower.contains('quidditch')) {
      extra.addAll([
        '前往魁地奇球场观看或加入训练',
        '与球队队员交谈获取赛事信息',
      ]);
    }
    if (narrativeLower.contains('食堂') || narrativeLower.contains('餐') || narrativeLower.contains('food')) {
      extra.addAll(['前往厨房准备一些食物', '请家养小精灵帮忙准备餐点']);
    }
    if (narrativeLower.contains('黑魔法') || narrativeLower.contains('dark')) {
      extra.addAll(['向教授请教防御方法', '了解相关历史背景']);
    }
    if (narrativeLower.contains('课') || narrativeLower.contains('homework')) {
      extra.addAll(['集中精力完成作业', '请同学帮忙讲解难点']);
    }
    if (narrativeLower.contains('朋友') || narrativeLower.contains('friend')) {
      extra.addAll(['邀请朋友一起活动', '与朋友分享最近的见闻']);
    }
    if (house.isNotEmpty) {
      extra.add('参加${house}学院的活动');
      extra.add('为${house}学院的荣誉加分');
    }
    for (final t in personality) {
      if (t.contains('勇敢') || t.contains('勇气')) extra.add('勇敢地面对当前的挑战');
      if (t.contains('聪明') || t.contains('智慧')) extra.add('冷静分析当前局势');
      if (t.contains('忠诚')) extra.add('坚定地支持朋友');
      if (t.contains('野心') || t.contains('ambitious')) extra.add('把握机会证明自己');
    }

    final pool = <String>[...?bucket[key], ...extra];
    // 去重并打乱
    final seen = <String>{};
    final deduped = pool.where((s) {
      final key = s.replaceAll(RegExp(r'\s+'), '');
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();
    deduped.shuffle(_random);

    final result = <GameChoice>[];
    for (int i = 0; i < deduped.length && result.length < 4; i++) {
      result.add(GameChoice(text: deduped[i], action: deduped[i]));
    }
    if (result.length < 2) {
      for (final s in bucket['default']!) {
        if (result.length >= 4) break;
        result.add(GameChoice(text: s, action: s));
      }
    }
    return result;
  }

  // ==================== 分院仪式（本地逻辑，不消耗 token） ====================
  Future<Map<String, String>> sortPlayer() async {
    if (_player == null) {
      return {'house': 'Gryffindor', 'narrative': ''};
    }

    _isLoading = true;
    notifyListeners();

    try {
      final house = _computeHouseLocal();
      final narrative = _generateSortingNarrative(house);
      _player!.house = house;
      _unlockAchievement('sorted');

      _isLoading = false;
      notifyListeners();
      return {'house': house, 'narrative': narrative};
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'house': 'Gryffindor', 'narrative': ''};
    }
  }

  String _computeHouseLocal() {
    final traits = _player!.personalityTraits.join(' ');
    final dims = _player!.houseDimensions;

    // 学院倾向优先
    final pref = _player!.housePreference;
    if (pref != null && pref != '系统判定') {
      if (pref.contains('格兰芬多')) return 'Gryffindor';
      if (pref.contains('斯莱特林')) return 'Slytherin';
      if (pref.contains('拉文克劳')) return 'Ravenclaw';
      if (pref.contains('赫奇帕奇')) return 'Hufflepuff';
    }

    final scores = <String, int>{
      'Gryffindor': 0,
      'Slytherin': 0,
      'Ravenclaw': 0,
      'Hufflepuff': 0,
    };

    // 基于性格特质
    final gryffindorTraits = ['勇敢', '勇气', '无畏', '热情', '骑士', '正义'];
    final slytherinTraits = ['野心', '精明', '狡猾', '意志', '血统', '领导'];
    final ravenclawTraits = ['智慧', '聪明', '好奇', '知识', '创造', '学习'];
    final hufflepuffTraits = ['忠诚', '勤勉', '公平', '坚韧', '正直', '耐心'];

    for (final t in gryffindorTraits) {
      if (traits.contains(t)) scores['Gryffindor'] = (scores['Gryffindor'] ?? 0) + 2;
    }
    for (final t in slytherinTraits) {
      if (traits.contains(t)) scores['Slytherin'] = (scores['Slytherin'] ?? 0) + 2;
    }
    for (final t in ravenclawTraits) {
      if (traits.contains(t)) scores['Ravenclaw'] = (scores['Ravenclaw'] ?? 0) + 2;
    }
    for (final t in hufflepuffTraits) {
      if (traits.contains(t)) scores['Hufflepuff'] = (scores['Hufflepuff'] ?? 0) + 2;
    }

    // 基于学院四维（houseDimensions）
    final courage = dims['courage'] ?? 50;
    final ambition = dims['ambition'] ?? 50;
    final wisdom = dims['wisdom'] ?? 50;
    final loyalty = dims['loyalty'] ?? 50;
    scores['Gryffindor'] = (scores['Gryffindor'] ?? 0) + courage;
    scores['Slytherin'] = (scores['Slytherin'] ?? 0) + ambition;
    scores['Ravenclaw'] = (scores['Ravenclaw'] ?? 0) + wisdom;
    scores['Hufflepuff'] = (scores['Hufflepuff'] ?? 0) + loyalty;

    // 政治倾向加分
    final pol = _player!.politicalTendency ?? '';
    if (pol.contains('纯血')) scores['Slytherin'] = (scores['Slytherin'] ?? 0) + 1;
    if (pol.contains('平等') || pol.contains('凤凰社')) scores['Gryffindor'] = (scores['Gryffindor'] ?? 0) + 1;

    // 血统背景
    final blood = _player!.bloodType;
    if (blood == 'pureblood') scores['Slytherin'] = (scores['Slytherin'] ?? 0) + 1;
    if (blood == 'muggleborn') scores['Gryffindor'] = (scores['Gryffindor'] ?? 0) + 1;

    // 如果都是0，默认可变随机
    final maxScore = scores.values.reduce((a, b) => a > b ? a : b);
    if (maxScore == 0) {
      final houses = ['Gryffindor', 'Slytherin', 'Ravenclaw', 'Hufflepuff'];
      return houses[_random.nextInt(4)];
    }

    // 最高分校，但加入少量随机扰动（防止同质化）
    final candidates = scores.entries.where((e) => e.value == maxScore).toList();
    candidates.shuffle(_random);
    return candidates.first.key;
  }

  String _generateSortingNarrative(String house) {
    final houseName = switch (house) {
      'Gryffindor' => '格兰芬多',
      'Slytherin' => '斯莱特林',
      'Ravenclaw' => '拉文克劳',
      'Hufflepuff' => '赫奇帕奇',
      _ => '格兰芬多',
    };

    final thoughts = [
      '嗯……有意思。这个孩子有${_player!.personalityTraits.join('、')}的特质。',
      '让我想想……勇敢？智慧？忠诚？野心？',
      '这很有趣，真的很有趣。',
      '决定了——',
    ];
    thoughts.shuffle(_random);

    return '分院帽在你的头顶停留了片刻，轻声低语：「${thoughts.join(' ')}」\n\n'
        '最终它大声宣布：**$houseName**！';
  }

  // ==================== 魔杖选择（本地逻辑，不消耗 token） ====================
  Future<Map<String, dynamic>> selectWand(List<Map<String, dynamic>> options) async {
    if (_player == null) {
      return {'selected': options.first, 'narrative': ''};
    }

    _isLoading = true;
    notifyListeners();

    try {
      final selected = _computeWandLocal(options);
      _player!.wandId = selected['id'] as String?;
      _unlockAchievement('first_wand');
      final narrative = _generateWandNarrative(selected);

      _isLoading = false;
      notifyListeners();
      return {'selected': selected, 'narrative': narrative};
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'selected': options.first, 'narrative': ''};
    }
  }

  Map<String, dynamic> _computeWandLocal(List<Map<String, dynamic>> options) {
    if (options.isEmpty) return {};

    final personality = _player!.personalityTraits.join(' ');
    final dims = _player!.houseDimensions;

    // 根据玩家特质为每根魔杖打分
    final scored = <String, double>{};
    for (final wand in options) {
      double score = 0.0;
      final suit = (wand['suitType'] ?? '') as String;
      final desc = (wand['description'] ?? '') as String;
      final wood = (wand['wood'] ?? '') as String;
      final core = (wand['core'] ?? '') as String;

      final combined = '$suit $desc $wood $core';

      // 性格匹配
      final traitKeywords = <String, int>{
        '勇敢': 2, '勇气': 2, '无畏': 2,
        '野心': 2, '精明': 2, '领导': 2,
        '智慧': 2, '聪明': 2, '好奇': 2,
        '忠诚': 2, '正直': 2, '勤勉': 2,
        '温柔': 1, '善良': 1, '慷慨': 1,
        '狡猾': 1, '意志': 1, '坚强': 1,
        '创造': 1, '学习': 1, '知识': 1,
        '坚韧': 1, '耐心': 1, '公平': 1,
      };
      for (final entry in traitKeywords.entries) {
        if (personality.contains(entry.key) && combined.contains(entry.key)) {
          score += entry.value;
        }
      }

      // 杖芯属性
      if (core == '独角兽毛') score += 1;
      if (core == '龙心脏腱索') score += 1;
      if (core == '凤凰羽毛') score += 1;

      // 学院四维加成
      final courage = dims['courage'] ?? 50;
      final ambition = dims['ambition'] ?? 50;
      final wisdom = dims['wisdom'] ?? 50;
      final loyalty = dims['loyalty'] ?? 50;

      if (wood == '冬青木' || wood == '橡木') score += courage * 0.05;
      if (wood == '紫杉木' || wood == '榆木') score += ambition * 0.05;
      if (wood == '葡萄藤木' || wood == '枫木') score += wisdom * 0.05;
      if (wood == '樱桃木' || wood == '雪松木' || wood == '柳木') score += loyalty * 0.05;

      final wid = wand['id'] ?? wand['name'] ?? '';
      scored[wid] = score;
    }

    // 选最高分，同分随机
    final maxScore = scored.values.isEmpty ? 0.0 : scored.values.reduce((a, b) => a > b ? a : b);
    final candidates = scored.keys.where((w) => scored[w] == maxScore).toList();
    candidates.shuffle(_random);
    final bestId = candidates.first;
    for (final wand in options) {
      if ((wand['id'] ?? wand['name']) == bestId) return wand;
    }
    return options.first;
  }

  String _generateWandNarrative(Map<String, dynamic> wand) {
    final name = wand['name'] ?? '未知魔杖';
    final wood = wand['wood'] ?? '';
    final core = wand['core'] ?? '';
    final len = wand['length'] ?? '';
    final suit = wand['suitType'] ?? '';

    final lines = [
      '奥利凡德先生用他那双近乎透明的眼睛凝视着你，片刻后低语：「有意思……很是有意思。」',
      '他在一排排积满灰尘的魔杖盒前缓缓踱步，抽出一根又一根——',
      '最终，当一根触碰到你指尖的瞬间，它迸发出一簇暖金色的火花，空气中响起一声清脆的共鸣。',
      '「$name，$wood，$core，$len。」他轻声介绍，「这根魔杖适合$suit的人。」',
      '你握着它，感到一股熟悉的力量在掌心流淌。',
    ];
    return lines.join('\n\n');
  }

  // ==================== 存档系统 ====================
  Future<void> quickSave() async {
    if (_player == null) return;
    await _saveService.saveGame(
      player: _player!.toJson(),
      worldState: _worldState.toJson(),
      npcRegistry: _npcRegistry.map((k, v) => MapEntry(k, v.toJson())),
      narrative: _currentNarrative,
      choices: _choices.map((c) => {'text': c.text, 'action': c.action}).toList(),
      turnCount: _turnCount,
      slotName: '快速存档',
      extraData: {
        'narrative_summary': _narrativeSummary,
        'pending_summary': _pendingSummary,
        'recent_turns': _recentTurns,
        'game_week': _gameWeek,
        'last_round_tokens': _lastRoundTokens,
        'api_calls': _apiCalls,
        'total_prompt_tokens': _totalPromptTokens,
        'total_completion_tokens': _totalCompletionTokens,
        'total_tokens': _totalTokens,
      },
    );
  }

  static const int _saveVersion = 2;

  Future<void> loadFromSave(String slotId) async {
    final data = await _saveService.loadGame(slotId);
    if (data == null) return;

    final version = data['save_version'] as int? ?? 1;
    _migrateSave(data, version);

    _player = Player.fromJson(data['player'] as Map<String, dynamic>);
    _worldState = WorldState.fromJson(data['world_state'] as Map<String, dynamic>);
    _npcRegistry.clear();
    final npcMap = data['npc_registry'] as Map<String, dynamic>? ?? <String, dynamic>{};
    npcMap.forEach((k, v) {
      _npcRegistry[k] = NPC.fromJson(v as Map<String, dynamic>);
    });
    // 在 player/worldState/npc 赋值之后再构建系统提示词（_buildSystemPrompt 会用到）
    _systemPrompt = _buildSystemPrompt();

    _currentNarrative = data['narrative'] as String? ?? '';
    _choices = (data['choices'] as List<dynamic>?)
        ?.map((c) => GameChoice(text: c['text'] as String, action: c['action'] as String))
        .toList() ?? [];
    _turnCount = data['turn_count'] as int? ?? 0;
    final extraData = data['extra_data'] as Map<String, dynamic>? ?? {};
    _narrativeSummary = extraData['narrative_summary'] as String? ?? '';
    _pendingSummary = extraData['pending_summary'] as String? ?? '';
    _gameWeek = extraData['game_week'] as int? ?? 1;
    _lastRoundTokens = extraData['last_round_tokens'] as int? ?? 0;
    _apiCalls = extraData['api_calls'] as int? ?? 0;
    _totalPromptTokens = extraData['total_prompt_tokens'] as int? ?? 0;
    _totalCompletionTokens = extraData['total_completion_tokens'] as int? ?? 0;
    _totalTokens = extraData['total_tokens'] as int? ?? 0;

    _recentTurns
      ..clear()
      ..addAll((extraData['recent_turns'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          []);
    if (_recentTurns.isEmpty && _currentNarrative.isNotEmpty) {
      _recentTurns.add(_currentNarrative);
    }

    // 完整性兜底：只在空的时候补默认
    if (_choices.isEmpty) _choices = _generateFallbackChoices();
    if (_choices.length > 4) _choices = _choices.sublist(0, 4);
    if (_currentNarrative.isEmpty) _currentNarrative = _generateFallbackNarrative();

    // 任何读档之后都必须确保 isLoading=false / isInitializing=false，
    // 否则"继续游戏"后会卡住或误触发再次请求
    _isLoading = false;
    _isInitializing = false;
    _error = null;
    _loadingStage = '';

    _runConsistencyChecks();
    appProvider.setGameStarted(true);
    notifyListeners();
    _autoSave();
  }

  void _migrateSave(Map<String, dynamic> data, int version) {
    if (version < 2) {
      final ws = data['world_state'] as Map<String, dynamic>?;
      if (ws != null) {
        const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
        final oldMonth = ws['month'] as String?;
        if (oldMonth != null) {
          final idx = monthNames.indexOf(oldMonth);
          if (idx >= 0) {
            ws['month'] = GameTime.months[idx];
            debugPrint('存档迁移: month "$oldMonth" -> "${ws['month']}"');
          }
        }
        if (!ws.containsKey('time')) {
          debugPrint('存档迁移: 从旧字段推导 time 字段');
          final yearStr = ws['academic_year'] ?? '1991-1992';
          final yearMatch = RegExp(r'^(\d{4})').firstMatch(yearStr.toString());
          final year = yearMatch != null ? int.tryParse(yearMatch.group(1)!) ?? 1991 : 1991;
          final monthIdx = monthNames.indexOf(ws['month'] as String? ?? '') + 1;
          ws['time'] = {
            'year': year,
            'month': monthIdx > 0 ? monthIdx : 9,
            'day': ws['day_of_month'] as int? ?? 1,
            'weekday': 2,
            'hour': 9,
            'minute': 0,
          };
        }
      }
      data['save_version'] = _saveVersion;
    }
  }

  Future<List<Map<String, dynamic>>> listSaves() async {
    return _saveService.listSaves();
  }

  Future<bool> deleteSave(String slotId) async {
    return _saveService.deleteSave(slotId);
  }

  // ==================== API 检查 ====================
  Future<bool> checkConnection() async {
    if (_router == null) return false;
    final provider = appProvider.aiProvider;
    return await _router!.checkBalance(provider) != null ||
        appProvider.hasKey(provider);
  }

  Future<double?> get balance async {
    if (_router == null) return null;
    final provider = appProvider.aiProvider;
    return await _router!.checkBalance(provider);
  }

  Future<Map<String, dynamic>?> get quotaInfo async {
    if (_router == null) return null;
    final provider = appProvider.aiProvider;
    final service = _router!.getService(provider);
    if (service == null) return null;
    return await service.getQuotaInfo();
  }

  void resetTokenUsage() {
    _totalPromptTokens = 0;
    _totalCompletionTokens = 0;
    _totalTokens = 0;
    _apiCalls = 0;
    notifyListeners();
  }

  // ==================== 辅助方法 ====================
  String _bloodStatusLabel(String status) {
    return {
      'muggleborn': '麻瓜出身',
      'halfblood': '混血巫师',
      'pureblood': '纯血',
      'pureblood_side': '纯血旁支',
      'pureblood_sacred': '神圣二十八族',
      'special': '特殊家庭',
      'squib': '哑炮',
      'obscurial': '默然者',
      'veela': '混血媚娃',
      'werewolf': '狼人',
      'half_giant': '半巨人',
      'muggle_family': '麻瓜家庭',
      'custom': '自定义',
    }[status] ?? status;
  }

  String _attrLabel(String key) {
    return {
      'spell_understanding': '魔咒理解',
      'transfiguration': '变形术',
      'potions': '魔药',
      'herbology': '草药学',
      'dda': '黑魔法防御',
      'flying': '飞行',
      'theory': '理论知识',
      'memory': '记忆力',
      'observation': '观察力',
      'magic_control': '魔法控制',
      'reaction_time': '反应速度',
      'emotional_stability': '情绪稳定',
      'creativity': '创造力',
      'social': '社交',
      'courage': '勇气',
      'caution': '谨慎',
      'willpower': '意志',
      'logic': '逻辑',
      'intuition': '直觉',
    }[key] ?? key;
  }

  String _termLabel(String term) {
    return {
      'first': '第一学期',
      'second': '第二学期',
      'third': '第三学期',
      'summer': '暑假',
    }[term] ?? term;
  }

  String _flowModeLabel(String mode) {
    return {
      'normal': '正常',
      'story': '剧情加速',
      'fast': '快速',
    }[mode] ?? mode;
  }

  @override
  void dispose() {
    _autoSave();
    appProvider.removeListener(_onApiKeyChange);
    super.dispose();
  }
}

class GameChoice {
  final String text;
  final String action;
  GameChoice({required this.text, required this.action});
}
