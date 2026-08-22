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
import '../services/deepseek_service.dart';
import '../services/deepseek_service.dart' show ChatResult;
import '../services/save_service.dart';
import '../services/npc_chat_service.dart';
import '../services/ai_router.dart';
import '../utils/crash_logger.dart';

class GameProvider extends ChangeNotifier {
  final AppProvider appProvider;
  AiRouter? _router;
  final SaveService _saveService = SaveService();
  final Random _random = Random();
  late final NpcChatService chatService;

  // ====== 预编译正则（避免循环内重复编译） ======
  static final _reChoiceOption = RegExp(r'^[A-E][\.\)]\s*');
  static final _reMultiNewline = RegExp(r'\n{3,}');
  static final _reAffectionSection = RegExp(r'【好感度变化】[\s\S]*?(?=【|$)');
  static final _reReputationSection = RegExp(r'【声望变化】[\s\S]*?(?=【|$)');
  static final _reChoiceMultiLine = RegExp(r'^[A-E][\.\)]\s', multiLine: true);
  static final _reSectionMarkers = RegExp(r'【[^】]+】');

  Player? _player;
  WorldState _worldState = WorldState();
  final Map<String, NPC> _npcRegistry = {};

  String _currentNarrative = '';
  String _narrativeSummary = '';
  String _pendingSummary = '';
  List<GameChoice> _choices = [];
  bool _isLoading = false;
  bool _isInitializing = false;
  String? _error;
  int _turnCount = 0;
  String _lastPlayerAction = '';
  String? _systemPrompt;
  String _loadingStage = '';
  final List<String> _notifications = [];
  Future<void>? _pendingSave;
  bool _saveScheduled = false;

  int _totalPromptTokens = 0;
  int _totalCompletionTokens = 0;
  int _totalTokens = 0;
  int _lastRoundTokens = 0;
  int _apiCalls = 0;
  int _gameWeek = 1; // 用于好感沉淀（第一周上限+30）

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
      _systemPrompt = _buildSystemPrompt();
      _npcRegistry.clear();
      (data['npc_registry'] as Map<String, dynamic>).forEach((k, v) {
        _npcRegistry[k] = NPC.fromJson(v as Map<String, dynamic>);
      });
      _currentNarrative = data['narrative'] as String? ?? '';
      _choices = (data['choices'] as List<dynamic>?)
          ?.map((c) => GameChoice(text: c['text'] as String, action: c['action'] as String))
          .toList() ?? [];
      _turnCount = data['turn_count'] as int? ?? 0;
      final extraData = data['extra_data'] as Map<String, dynamic>? ?? {};
      _narrativeSummary = extraData['narrative_summary'] as String? ?? '';
      _pendingSummary = extraData['pending_summary'] as String? ?? '';
      _gameWeek = extraData['game_week'] as int? ?? 1;
      _isInitializing = false;
      debugPrint('✅ 自动存档加载成功: ${_player?.name} 第$_turnCount回合 (第$_gameWeek周)');
      notifyListeners();
    } catch (e) {
      _isInitializing = false;
      debugPrint('❌ 自动存档加载失败: $e');
      appProvider.setGameStarted(false);
      _error = '存档加载失败: $e';
      notifyListeners();
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
            'game_week': _gameWeek,
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
    );
    final router = AiRouter(config);
    for (final p in AiProvider.values) {
      if (appProvider.hasKey(p)) {
        router.register(appProvider.configForProvider(p));
      }
    }
    _router = router;
  }

  void updateNpcAffection(String npcId, int change, {String? reason}) {
    final npc = _npcRegistry[npcId];
    if (npc == null) return;

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
    _updateClient();
    chatService.refreshClient();
    notifyListeners();
  }

  // ==================== 系统提示词（精简版 + 玩家档案嵌入） ====================
  String _buildSystemPrompt() {
    final p = _player;
    final effectiveEra = _worldState.era.isNotEmpty ? _worldState.era : appProvider.era.name;
    final eraName = _eraLabelShort(_parseEra(effectiveEra));

    final profile = p != null
        ? '【玩家档案】${p.name}｜${_bloodStatusLabel(p.bloodType)}｜${p.house ?? '未分院'}｜${p.grade}年级｜${p.magicAptitude ?? '普通'}天赋｜${p.gender}｜精神力${p.spirit}精力${p.energy}'
        : '';

    final worldRules = kUseFusedCompact ? kWorldRulesFusedCompact : kWorldRulesFused;

    return '''$worldRules

$profile
【时代】$eraName
【当前状态】${_buildSceneContext()}''';
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
  }) async {
    _isLoading = true;
    _error = null;
    _notifications.clear();
    notifyListeners();

    try {
      final birthYear = _calculateBirthYear();
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
      );

      _worldState = WorldState(
        era: appProvider.era.name,
        academicYear: _academicYearForEra(appProvider.era),
        time: GameTime(
          year: int.parse(birthYear),
          month: 9,
          day: 1,
          hour: startHour,
          minute: startMinute,
        ),
      );

      // 必须在 _player 和 _worldState 都赋值后再构建系统提示词
      _systemPrompt = _buildSystemPrompt();

      _initializeNPCsByEra();
      _assignInitialRelationships();
      await _generateOpeningScene();

      appProvider.setGameStarted(true);
      _unlockAchievement('first_letter');
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

  /// 建立玩家初始关系（同年级同学认识）
  void _assignInitialRelationships() {
    final p = _player;
    if (p == null) return;
    for (final npc in _npcRegistry.values) {
      if (npc.grade > 0 && npc.grade == (p.grade ?? 1)) {
        p.relationships[npc.id] = Relationship(
          targetId: npc.id,
          targetName: npc.name,
          relationType: '同学',
          level: 10,
        );
      }
    }
  }

  String _calculateBirthYear() {
    return switch (appProvider.era) {
      Era.dumbledore => '1881',
      Era.marauders => '1960',
      Era.first_war => '1965',
      Era.harry_same => '1980',
      Era.post_war => '2009',
      Era.random => '1980',
    };
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
    profile.add('时代：${_eraLabelShort(appProvider.era)}');
    profile.add('魔杖：$wandInfo');
    profile.add('宠物：$petInfo');

    final prompt = '''【开场叙事】J.K.罗琳风格，3+感官细节。

【玩家资料】
${profile.join('｜')}

【起始场景】$startPoint

【要求】300-400字，📅时间戳开头，自然融入魔杖/宠物/血统，体现性格。

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
      return;
    }

    try {
      final response = await _callDeepSeek(prompt);
      _parseResponse(response.content);
      _accumulateForSummary(_currentNarrative);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _currentNarrative =
          '${p.name}，故事即将开始。请稍候，魔法正在酝酿。';
      _choices = [GameChoice(text: '继续', action: '继续')];
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
    // 可根据玩家选择或默认生成
    final starts = [
      '故事从你收到霍格沃茨录取通知书的那一刻开始——那只迟来的猫头鹰终于叩响了你的窗。',
      '故事从你站在九又四分之三站台前开始——蒸汽火车冒着白烟等待着你。',
      '故事从你第一次踏入霍格沃茨大礼堂开始——金色的烛光在长桌上方摇曳。',
      '故事从分院仪式前夜开始——你躺在床上翻来覆去，想着明天会被分到哪个学院。',
    ];
    return starts[_random.nextInt(starts.length)];
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

    if (_router == null || !_router!.hasNarrativeService) return;

    _isLoading = true;
    _turnCount++;
    _lastPlayerAction = action;
    _loadingStage = '正在构建请求...';
    notifyListeners();

    String buildPrompt() {
      final p = _player!;

      final contextBuffer = StringBuffer();
      if (_narrativeSummary.isNotEmpty) {
        contextBuffer.write('【前情摘要】\n$_narrativeSummary\n\n');
      }
      final recent = _truncateNarrativeContext(_currentNarrative, 400);
      contextBuffer.write('【近期剧情】\n$recent');

      final context = contextBuffer.toString();
      final statusTag = _buildStatusTag(p);
      final extra = _buildCriticalContext(action);
      final sceneInfo = _buildSceneContext();

      return '''【世界上下文】
$context

【玩家状态】$statusTag
【当前场景】${_worldState.timestamp}｜${_worldState.currentLocation ?? '未知'}
$sceneInfo

${extra.isNotEmpty ? extra + '\n' : ''}【玩家行动】
$action

【写作要求】
1. 叙事要求:300-450字，详细描写：
   - 环境氛围（声音、气味、光线等3-5种感官细节）
   - NPC的言行举止、表情反应、对话交流
   - 玩家的心理活动、情绪变化
   - 重要物品/事件的细节描写
   - 场景氛围的变化和渲染

2. 好感变化:NPC名:±X(原因)

3. 可选行动:A/B/C/D（具体选项，各选项体现不同性格/策略）

4. 可选行动:''';
    }

    try {
      final prompt = buildPrompt();
      _loadingStage = '正在生成剧情...';
      notifyListeners();

      String response;
      try {
        response = (await _callDeepSeek(prompt)).content;
      } catch (e) {
        _loadingStage = '请求失败，正在重试...';
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 500));
        response = (await _callDeepSeek(prompt)).content;
      }

      _loadingStage = '正在解析回应...';
      notifyListeners();

      _parseResponse(response);
      _accumulateForSummary(_currentNarrative);
      _advanceTimeForAction(action);
      _updateNPCsFromAction(action);
      _updatePlayerImpactScore(action);

      if (_turnCount % 10 == 0 && _pendingSummary.isNotEmpty) {
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
      _loadingStage = '';
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
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

      case '/课程':
        _currentNarrative = _formatCourses();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/收藏':
        _currentNarrative = _formatCollection();
        _choices = [GameChoice(text: '返回', action: '继续')];
        return true;

      case '/日记':
        _currentNarrative = _formatDiary();
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
        _currentNarrative = _formatLetters();
        _choices = [GameChoice(text: '返回', action: '继续')];
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
/课程 — 查看课程表与进度
/收藏 — 查看收藏品
/日记 — 查看CG图鉴与日记
/档案 — 查看角色完整档案
/成就 — 查看成就
/宠物 — 查看宠物状态
/信 — 查看收到的信件
/新NPC — 生成一位新NPC（每学年限4次）
/血缘 — 查看血缘亲属
/联动 — 查看时代联动痕迹
/cheat — 作弊指令（详见 /cheat）''';
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

  String _formatCourses() {
    final buf = StringBuffer('【课程系统】\n必修课：\n');
    for (final c in requiredCourses) {
      buf.writeln('· ${c.name}（${c.professor}）');
    }
    buf.writeln('\n选修课（三年级起，至少选2门）：');
    for (final c in electiveCourses) {
      buf.writeln('· ${c.name}（${c.professor}）');
    }
    return buf.toString();
  }

  String _formatCollection() {
    if (_player!.collection.isEmpty) {
      return '【收藏】\n暂无收藏品。在冒险中收集独特物品，如巧克力蛙画片、日记本等。';
    }
    return '【收藏】\n${_player!.collection.map((c) => '· $c').join('\n')}';
  }

  String _formatDiary() {
    if (_player!.cgRecords.isEmpty) {
      return '【日记 / CG图鉴】\n暂无解锁CG。在关键剧情节点将解锁专属CG。';
    }
    return '【日记 / CG图鉴】（已解锁 ${_player!.cgRecords.length}/36）\n'
        '${_player!.cgRecords.values.map((c) => '· ${c.cgId} ${c.name}（${c.unlockedDate}）').join('\n')}';
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

  String _formatLetters() {
    if (_player!.letters.isEmpty) {
      return '【信件】\n暂无信件。';
    }
    return '【信件】\n${_player!.letters.map((l) => '· ${l.sender}（${l.date}）：${l.content.length > 30 ? '${l.content.substring(0, 30)}…' : l.content}').join('\n')}';
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
      if (!n.isAlive || n.affection < 85 || n.confessed) return false;
      if (n.sexOrientation != null && n.sexOrientation != p.sexOrientation) {
        return false;
      }
      // 检查关系阶段
      final stage = p.loveState.stageFor(n.name);
      if (stage != '暧昧' && stage != '亲密') return false;
      // 检查浪漫事件计数
      if (p.loveState.romanticEventsFor(n.name) < 2) return false;
      // 检查暧昧持续时间
      if (p.loveState.currentCrushName == n.name && !p.loveState.isCrushMature(currentDay)) {
        return false;
      }
      return true;
    }).toList();

    if (candidates.isEmpty) return;

    // 融合版：概率触发（基础20% + 条件达标加成）
    double triggerProb = 0.2;
    // 好感超过90%时概率增加
    for (final c in candidates) {
      if (c.affection >= 90) triggerProb += 0.1;
    }
    triggerProb = triggerProb.clamp(0.0, 0.6);

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
    final npc = _npcRegistry.values
        .firstWhere((n) => n.name == npcName, orElse: () => _npcRegistry.values.first);
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
      _currentNarrative =
          '你点了点头，${npc.name}的眼睛瞬间亮了起来，像被月光点亮。\n\n'
          '他/她握住你的手，声音里带着掩饰不住的喜悦："真的吗？太好了……"\n\n'
          '你们在月色下相视而笑，霍格沃茨的钟声在远处敲响，仿佛在为这段感情祝福。';
    } else {
      npc.affection -= 5;
      _unlockCG(cgById('CG-CF-002'));
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

    _runConsistencyChecks();

    _checkMonthlyEvolution(oldMonth, oldYear);
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
    for (int i = 0; i < days; i++) {
      _worldState.time.advanceMinutes(24 * 60);
    }
    _worldState.dayOfMonth = _worldState.time.day;
    _worldState.dayOfWeek = GameTime.weekdays[_worldState.time.weekday];
    _worldState.month = GameTime.months[_worldState.time.month - 1];
  }

  // ==================== NPC 状态更新 ====================
  void _updateNPCsFromAction(String action) {
    // 消耗资源
    final p = _player!;
    p.energy = max(0, p.energy - 5);
    p.satiety = max(0, p.satiety - 3);
    p.spirit = max(0, p.spirit - 2);

    if (action.contains('吃饭') || action.contains('用餐')) {
      p.satiety = min(100, p.satiety + 25);
    }
    if (action.contains('睡觉') || action.contains('休息')) {
      p.energy = min(100, p.energy + 40);
      p.spirit = min(100, p.spirit + 20);
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
    if (npc.affection >= 50 && !npc.hasLock('信任锁')) {
      npc.affectionLocks.add('信任锁');
    }
    if (npc.affection >= 70 && !npc.hasLock('情感锁')) {
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
    final result = await _router!.chatComplete(
      scene: scene,
      prompt: prompt,
      systemPrompt: _systemPrompt ?? '',
      temperature: 0.85,
      maxTokens: scene == AiScene.narrative ? 1800 : 2500,
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
  void _parseResponse(String text) {
    final lines = text.split('\n');
    _currentNarrative = '';
    _choices = [];
    bool inNarrative = false;

    // Pass 1: Try structured parsing with explicit markers
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed == '【叙事】') {
        inNarrative = true;
        continue;
      } else if (trimmed.startsWith('【可选行动】') ||
          trimmed.startsWith('【自由行动】') ||
          trimmed.startsWith('【好感度变化】') ||
          trimmed.startsWith('【声望变化】')) {
        inNarrative = false;
        continue;
      }
      if (inNarrative) {
        if (trimmed.isNotEmpty) {
          _currentNarrative += '$trimmed\n';
        }
      } else if (_reChoiceOption.hasMatch(trimmed)) {
        final action =
            trimmed.replaceFirst(_reChoiceOption, '').trim();
        if (action.isNotEmpty) {
          _choices.add(GameChoice(text: action, action: action));
        }
      }
    }

    // Pass 2: If narrative is empty or too short (< 20 chars), try
    // to extract from raw text before choices
    if (_currentNarrative.isEmpty || _currentNarrative.length < 20) {
      _extractNarrativeFromRawText(text);
    }

    _currentNarrative = _currentNarrative
        .replaceAll(_reMultiNewline, '\n\n')
        .trim();

    // Pass 3: If still empty, generate a fallback narrative
    if (_currentNarrative.isEmpty) {
      _currentNarrative = _generateFallbackNarrative();
    }

    // Parse affection changes
    _parseAffectionChanges(text);

    // Parse reputation changes
    _parseReputationChanges(text);

    if (_choices.isEmpty) {
      _choices.addAll(_generateFallbackChoices());
    }

    if (_turnCount % 5 == 0 || _lastPlayerAction.contains(RegExp(r'(与|和|跟|找|邀|问|对话|聊天|约会|见面|散步|陪|一起|独处|深入|表白|感情|心动)'))) {
      checkNPCConfessions();
    }

    _checkSkillAchievements();
    _checkWorldChangerAchievement();
    _checkWarHeroAchievement();

    // 每10回合增加少量世界线变动率
    if (_turnCount % 10 == 0) {
      _incrementWorldLineDeviation(0.005);
    }
  }

  void _extractNarrativeFromRawText(String text) {
    var cleaned = text;

    cleaned = cleaned.replaceAllMapped(_reAffectionSection, (m) => '');
    cleaned = cleaned.replaceAllMapped(_reReputationSection, (m) => '');

    final choiceMatch = _reChoiceMultiLine.firstMatch(cleaned);
    if (choiceMatch != null) {
      cleaned = cleaned.substring(0, choiceMatch.start);
    } else {
      cleaned = cleaned.split('\n\n').first;
    }

    cleaned = cleaned
        .replaceAll(_reSectionMarkers, '')
        .replaceAll(RegExp(r'\n{2,}'), '\n\n')
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

  // ==================== Token 优化：上下文截断 + 状态精简 ====================

  /// 截断叙事上下文，只保留末尾 maxChars 字，保证连贯性同时控制 token
  String _truncateNarrativeContext(String narrative, int maxChars) {
    if (narrative.length <= maxChars) return narrative;
    final cut = narrative.length - maxChars;
    return '…（前情略）${narrative.substring(cut)}';
  }

  // ==================== 剧情摘要机制：每10回合压缩历史 ====================

  void _accumulateForSummary(String newNarrative) {
    _pendingSummary += '$newNarrative\n';
  }

  Future<void> _summarizeNarrative() async {
    if (_pendingSummary.length < 50) {
      _pendingSummary = '';
      return;
    }

    final prompt = '''请将以下剧情内容压缩成5-8句话的摘要，保留关键事件、NPC互动、重要转折和玩家状态变化。用第三人称。

【前情摘要】
${_narrativeSummary.isNotEmpty ? _narrativeSummary : '（开局）'}

【新剧情】
$_pendingSummary

请输出合并后的完整摘要(不超过300字)：''';

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

  /// 只在状态异常时输出状态标签（HP低/MP低/精力低/受伤），正常则不写
  String _buildStatusTag(Player p) {
    final tags = <String>[];
    if (p.health <= 30) tags.add('HP低:${p.health}');
    if (p.magic <= 20) tags.add('MP低:${p.magic}');
    if (p.energy <= 20) tags.add('精力低:${p.energy}');
    if (p.injuries.isNotEmpty) {
      tags.add(p.injuries.take(2).join('、'));
    }
    if (tags.isEmpty) return '状态良好';
    return tags.join('｜');
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

    // 社交/对话 → 注入最多2个相关NPC好感
    if (a.contains(RegExp(r'(约会|表白|心动|拥抱|接吻|单独见面|私聊)'))) {
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
        final status = n.isAlive ? '好感${n.affection}' : '';
        return '${n.name}($status)';
      }).join('、');
      parts.add('【在场NPC】$npcNames');
    }

    final hour = ws.time.hour;
    final timeDesc = hour >= 22 || hour < 6 ? '深夜' :
                     hour >= 18 ? '夜晚' :
                     hour >= 14 ? '下午' :
                     hour >= 10 ? '上午' : '清晨';
    parts.add('【时间氛围】$timeDesc（${ws.time.formattedTime}）');

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
    if (_npcRegistry.isEmpty) return;
    final inSection = text.split('【好感度变化】');
    if (inSection.length < 2) return;
    final section = inSection[1].split('【').first;
    for (final line in section.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final match = RegExp(r'^(.*?)[:：]\s*([+-]?\d+)').firstMatch(trimmed);
      if (match == null) continue;
      final npcName = match.group(1)!.trim();
      final delta = int.tryParse(match.group(2)!) ?? 0;
      if (delta == 0 || npcName.isEmpty) continue;
      try {
        final npc = _npcRegistry.values.firstWhere(
          (n) => n.name == npcName,
          orElse: () => _npcRegistry.values.first,
        );
        if (npc.name == npcName) {
          updateNpcAffection(npc.id, delta, reason: '剧情互动');
          _checkLocks(npc);
          _syncRelationshipLevel(npc);
          _checkAffectionAchievements(npc);
        }
      } catch (e) {
        // 空注册表或注册表为空时静默忽略
      }
    }
  }

  void _parseReputationChanges(String text) {
    if (_player == null) return;
    final inSection = text.split('【声望变化】');
    if (inSection.length < 2) return;
    final section = inSection[1].split('【').first;
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
        // 维度不存在时静默忽略
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
        'game_week': _gameWeek,
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
    _systemPrompt = _buildSystemPrompt();
    _npcRegistry.clear();
    final npcMap = data['npc_registry'] as Map<String, dynamic>? ?? <String, dynamic>{};
    npcMap.forEach((k, v) {
      _npcRegistry[k] = NPC.fromJson(v as Map<String, dynamic>);
    });
    _currentNarrative = data['narrative'] as String? ?? '';
    _choices = (data['choices'] as List<dynamic>?)
        ?.map((c) => GameChoice(text: c['text'] as String, action: c['action'] as String))
        .toList() ?? [];
    _turnCount = data['turn_count'] as int? ?? 0;
    final extraData = data['extra_data'] as Map<String, dynamic>? ?? {};
    _narrativeSummary = extraData['narrative_summary'] as String? ?? '';
    _pendingSummary = extraData['pending_summary'] as String? ?? '';
    _gameWeek = extraData['game_week'] as int? ?? 1;
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
