import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'app_provider.dart';
import 'game_provider_base.dart';
import '../mixins/game_provider_mixins.dart';
import '../data/balance_constants.dart';
import '../services/save_service.dart';
import '../services/npc_chat_service.dart';
import '../services/ai_router.dart';
import '../services/rate_limiter.dart';
import '../services/deepseek_service.dart';
import '../utils/crash_logger.dart';
import '../models/player.dart';
import '../models/world_state.dart';
import '../models/npc.dart';
import '../models/game_systems.dart';
import '../models/long_term_memory.dart';

/// GameProvider 本体：只保留 constructor / autoSave / saveNow / onApiKeyChange
/// / updateClient / refreshClient / updateNpcAffection / updateApiKey 等调度入口。
/// 所有字段和静态正则已经迁移到抽象基类 GameProviderBase 供 6 个 Mixin 通过
/// `mixin X on GameProviderBase` 访问，从而解决 recursive_interface_inheritance。
class GameProvider extends GameProviderBase
    with
        GameInitMixin,
        GameNarrativeMixin,
        GameCommandsMixin,
        GameResponseMixin,
        GameRelationsMixin,
        GameSystemsMixin {
  @override
  final AppProvider appProvider;
  @override
  AiRouter? router;
  @override
  final SaveService saveService = SaveService();
  @override
  final Random random = Random();
  @override
  late NpcChatService chatService;

  Future<void>? _pendingSave;
  bool _saveScheduled = false;

  GameProvider(this.appProvider) {
    chatService = NpcChatService(appProvider: appProvider);
    updateClient();
    appProvider.addListener(onApiKeyChange);
    if (appProvider.isGameStarted) {
      isInitializing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        tryAutoLoad();
      });
    }
  }

  // ---------------------------------------------------------------
  // 自动读档 + 存档
  // ---------------------------------------------------------------
  @override
  Future<void> tryAutoLoad() async {
    if (!appProvider.isGameStarted) return;
    final data = await saveService.loadAutoSave();
    if (data == null) {
      isInitializing = false;
      appProvider.setGameStarted(false);
      notifyListeners();
      return;
    }
    try {
      player = Player.fromJson(data['player'] as Map<String, dynamic>);
      worldState = WorldState.fromJson(data['world_state'] as Map<String, dynamic>);
      npcRegistry.clear();
      (data['npc_registry'] as Map<String, dynamic>).forEach((k, v) {
        npcRegistry[k] = NPC.fromJson(v as Map<String, dynamic>);
      });
      systemPrompt = buildSystemPrompt();

      currentNarrative = data['narrative'] as String? ?? '';
      choices = (data['choices'] as List<dynamic>?)
          ?.map((c) => GameChoice(text: c['text'] as String, action: c['action'] as String))
          .toList() ?? [];
      turnCount = data['turn_count'] as int? ?? 0;

      final extraData = data['extra_data'] as Map<String, dynamic>? ?? {};
      narrativeSummary = extraData['narrative_summary'] as String? ?? '';
      pendingSummary = extraData['pending_summary'] as String? ?? '';
      gameWeek = extraData['game_week'] as int? ?? 1;
      lastRoundTokens = extraData['last_round_tokens'] as int? ?? 0;
      apiCalls = extraData['api_calls'] as int? ?? 0;
      totalPromptTokens = extraData['total_prompt_tokens'] as int? ?? 0;
      totalCompletionTokens = extraData['total_completion_tokens'] as int? ?? 0;
      totalTokens = extraData['total_tokens'] as int? ?? 0;
      memory = LongTermMemory.fromJson(extraData['long_term_memory'] as Map<String, dynamic>?);
      recentTurns
        ..clear()
        ..addAll((extraData['recent_turns'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            []);
      if (recentTurns.isEmpty && currentNarrative.isNotEmpty) {
        recentTurns.add(currentNarrative);
      }
      if (choices.isEmpty) choices = generateFallbackChoices();
      if (choices.length > 4) choices = choices.sublist(0, 4);
      if (currentNarrative.isEmpty) currentNarrative = generateFallbackNarrative();

      isLoading = false;
      isInitializing = false;
      error = null;
      loadingStage = '';
      debugPrint('✅ 自动存档加载成功: ${player?.name} 第$turnCount回合 (第$gameWeek周) 叙事${currentNarrative.length}字');
      notifyListeners();
    } catch (e) {
      isLoading = false;
      isInitializing = false;
      debugPrint('❌ 自动存档加载失败: $e');
      appProvider.setGameStarted(false);
      error = '存档加载失败: $e';
      notifyListeners();
      unawaited(CrashLogger.instance.record(
        e,
        StackTrace.current,
        screen: 'autoLoad',
        extra: 'error during tryAutoLoad',
      ));
    }
  }

  @override
  Future<void> autoSave() async {
    if (player == null) return;
    if (_saveScheduled) return;
    _saveScheduled = true;
    _pendingSave = doSave(debounce: true);
    await _pendingSave;
  }

  @override
  Future<void> saveNow() async {
    if (player == null) return;
    if (_saveScheduled) return;
    _saveScheduled = true;
    await doSave(debounce: false);
  }

  @override
  Future<void> doSave({required bool debounce}) async {
    try {
      if (debounce) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
      await saveService.autoSave(
        player: player!.toJson(),
        worldState: worldState.toJson(),
        npcRegistry: npcRegistry.map((k, v) => MapEntry(k, v.toJson())),
        narrative: currentNarrative,
        choices: choices.map((c) => {'text': c.text, 'action': c.action}).toList(),
        turnCount: turnCount,
        extraData: {
          'narrative_summary': narrativeSummary,
          'pending_summary': pendingSummary,
          'recent_turns': recentTurns,
          'game_week': gameWeek,
          'last_round_tokens': lastRoundTokens,
          'api_calls': apiCalls,
          'total_prompt_tokens': totalPromptTokens,
          'total_completion_tokens': totalCompletionTokens,
          'total_tokens': totalTokens,
          'long_term_memory': memory.toJson(),
        },
      );
    } catch (e) {
      debugPrint('❌ 自动存档失败: $e');
    } finally {
      _saveScheduled = false;
    }
  }

  @override
  void onApiKeyChange() {
    updateClient();
    chatService.refreshClient();
  }

  @override
  void updateClient() {
    final config = AiRouterConfig(
      narrativeProvider: appProvider.providerForScene(AiScene.narrative),
      summaryProvider: appProvider.providerForScene(AiScene.summary),
      npcChatProvider: appProvider.providerForScene(AiScene.npcChat),
      choiceProvider: appProvider.providerForScene(AiScene.choice),
    );
    final newRouter = AiRouter(config);
    for (final p in AiProvider.values) {
      if (appProvider.hasKey(p)) {
        newRouter.register(appProvider.configForProvider(p));
      }
    }
    router = newRouter;
  }

  @override
  void refreshClient() {
    ResponseCache.instance.clear();
    updateClient();
    chatService.refreshClient();
    notifyListeners();
  }

  @override
  void updateNpcAffection(String npcId, int change, {String? reason}) {
    final npc = npcRegistry[npcId];
    if (npc == null) return;
    if (!npc.introduced) markNpcIntroduced(npc);

    final currentDay = worldState.time.dayOfYear;
    int actualChange = change;
    if (change > 0) {
      final cap = npc.getAffectionGainLimit(currentDay, gameWeek);
      if (cap <= 0) {
        actualChange = 0;
        if (npc.affectionGainedThisWeek == Balance.weekOneAffectionCap) {
          notifications.add('📊 ${npc.name}的好感本周已达上限，无法继续提升');
          worldState.addNarrativeEvent('📊 ${npc.name}的好感本周已达上限，无法继续提升');
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
        notifications.add('⚠️ ${npc.name}对你的信任因过去的背叛而受限');
        worldState.addNarrativeEvent('⚠️ ${npc.name}对你的信任因过去的背叛而受限');
      }
    }
    if (change < -15) {
      npc.addGrudge('betrayal', reason ?? '背叛/欺骗', currentDay);
      notifications.add('💔 ${npc.name}因你的行为而记恨在心');
      worldState.addNarrativeEvent('💔 ${npc.name}因你的行为而记恨在心');
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

  @override
  Future<void> updateApiKey(String key) async {
    await appProvider.saveApiKey(key);
    updateClient();
    chatService.refreshClient();
  }
}
