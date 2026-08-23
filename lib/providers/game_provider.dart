import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'app_provider.dart';
import '../mixins/game_provider_mixins.dart';
import '../models/player.dart';
import '../models/npc.dart';
import '../models/world_state.dart';
import '../models/game_systems.dart';
import '../models/long_term_memory.dart';
import '../data/course_data.dart';
import '../data/wand_data.dart';
import '../data/pet_data.dart';
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
import '../prompts/prompts.dart';

/// GameProvider 本体：只保留 字段 / constructor / autoLoad / save 基础机制 /
/// 对外调度总入口 (processChoice / initializeGame / resetAllState)。
/// 所有业务方法分在 6 个 mixin 里：
///   GameInitMixin        - 构建系统提示词、开局特质/分院/魔杖、初始化
///   GameNarrativeMixin   - buildPrompt 组装、记忆注入、开场/更多建议、上下文
///   GameCommandsMixin    - 命令面板、作弊、本地指令
///   GameResponseMixin    - 模型响应解析、好感解析、摘要、token、分院提取
///   GameRelationsMixin   - NPC 生成/信件/表白/骨科/CG/成就/经济(购/售/存/取/打工)/人物
///   GameSystemsMixin     - 时间/学年/毕业/锚点/月度/一致性/快速推进/格式/存档/API
class GameProvider extends ChangeNotifier
    with
        GameInitMixin,
        GameNarrativeMixin,
        GameCommandsMixin,
        GameResponseMixin,
        GameRelationsMixin,
        GameSystemsMixin {
  final AppProvider appProvider;
  AiRouter? _router;
  final SaveService _saveService = SaveService();
  final Random _random = Random();
  late NpcChatService chatService;

  // ====== 预编译正则（避免循环内重复编译） ======
  static final reChoiceOption = RegExp(
    r'^\s*(?:[A-Ea-e]|[Ａ-Ｅａ-ｅ]|[\d]{1,2}|[一二三四五六七八九十]{1,3})\s*(?:[\.\．、\)）:：])\s*',
  );
  static final reMultiNewline = RegExp(r'\n{3,}');
  static final reAffectionSection = RegExp(r'【好感(?:度)?变化?】[\s\S]*?(?=【|$)');
  static final reReputationSection = RegExp(r'【声望变化?】[\s\S]*?(?=【|$)');
  static final reChoiceMultiLine = RegExp(
    r'(?:^|\n)\s*(?:[A-Ea-e]|[Ａ-Ｅａ-ｅ]|[\d]{1,2}|[一二三四五六七八九十]{1,3})\s*(?:[\.\．、\)）:：])\s+\S',
    multiLine: true,
  );

  Player? _player;
  WorldState _worldState = WorldState();
  final Map<String, NPC> _npcRegistry = {};
  LongTermMemory _memory = LongTermMemory();

  String _currentNarrative = '';
  String _narrativeSummary = '';
  String _pendingSummary = '';
  final List<String> _recentTurns = [];
  static const int maxRecentTurns = 12;
  List<GameChoice> _choices = [];
  String? _commandResult;
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
  int _gameWeek = 1;
  int _lastSchoolYearStart = 0;
  String? _pendingAnchorDirective;
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
  String? get commandResult => _commandResult;
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

  // ---------------------------------------------------------------
  // 自动读档 + 存档 (保留在 core，它们访问字段太多，mixins 也能访问)
  // ---------------------------------------------------------------
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
      _systemPrompt = buildSystemPrompt();

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
      _memory = LongTermMemory.fromJson(extraData['long_term_memory'] as Map<String, dynamic>?);
      _recentTurns
        ..clear()
        ..addAll((extraData['recent_turns'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            []);
      if (_recentTurns.isEmpty && _currentNarrative.isNotEmpty) {
        _recentTurns.add(_currentNarrative);
      }
      if (_choices.isEmpty) _choices = generateFallbackChoices();
      if (_choices.length > 4) _choices = _choices.sublist(0, 4);
      if (_currentNarrative.isEmpty) _currentNarrative = generateFallbackNarrative();

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

  Future<void> autoSave() async {
    if (_player == null) return;
    if (_saveScheduled) return;
    _saveScheduled = true;
    _pendingSave = _doSave(debounce: true);
    await _pendingSave;
  }

  Future<void> _saveNow() async {
    if (_player == null) return;
    if (_saveScheduled) return;
    _saveScheduled = true;
    await _doSave(debounce: false);
  }

  Future<void> _doSave({required bool debounce}) async {
    try {
      if (debounce) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
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
          'long_term_memory': _memory.toJson(),
        },
      );
    } catch (e) {
      debugPrint('❌ 自动存档失败: $e');
    } finally {
      _saveScheduled = false;
    }
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
    ResponseCache.instance.clear();
    _updateClient();
    chatService.refreshClient();
    notifyListeners();
  }

  void updateNpcAffection(String npcId, int change, {String? reason}) {
    final npc = _npcRegistry[npcId];
    if (npc == null) return;
    if (!npc.introduced) markNpcIntroduced(npc);

    final currentDay = _worldState.time.dayOfYear;
    int actualChange = change;
    if (change > 0) {
      final cap = npc.getAffectionGainLimit(currentDay, _gameWeek);
      if (cap <= 0) {
        actualChange = 0;
        if (npc.affectionGainedThisWeek == Balance.weekOneAffectionCap) {
          _notifications.add('📊 ${npc.name}的好感本周已达上限，无法继续提升');
          _worldState.addNarrativeEvent('📊 ${npc.name}的好感本周已达上限，无法继续提升');
        }
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
    checkAffectionAchievements(npc);
    notifyListeners();
    autoSave();
  }

  Future<void> updateApiKey(String key) async {
    await appProvider.saveApiKey(key);
    _updateClient();
    chatService.refreshClient();
  }


}
