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
        GameNarrativeContinuityMixin,
        GameNarrativeMixin,
        GameCommandsMixin,
        GameResponseChoiceMixin,
        GameResponseAffectionMixin,
        GameResponseMixin,
        GameRelationsMixin,
        GameSystemsMixin,
        GamePlayMixin {
  @override
  bool markScanIfNew(String narrative) {
    final h = narrative.hashCode;
    if (lastScannedNarrativeHash != null && h == lastScannedNarrativeHash) {
      return false;
    }
    lastScannedNarrativeHash = h;
    return true;
  }
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
      lastWeekBucket = worldState.time.absoluteDayIndex ~/ 7;
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
      lastSchoolYearStart = extraData['last_school_year_start'] as int? ?? 0;
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
          'last_school_year_start': lastSchoolYearStart,
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
    // 注册每个提供商的所有 API Key（每个 Key 注册一个独立的服务，实现独立限流 + 自动轮询）
    for (final p in AiProvider.values) {
      if (appProvider.hasKey(p)) {
        final configs = appProvider.configsForProvider(p);
        for (final cfg in configs) {
          newRouter.register(cfg);
        }
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
    // 注意：不再在此处自动 markNpcIntroduced。
    // introduced 必须仅在 markIntroducedFromNarrative（剧情扫描）或
    // 显式的 markNpcIntroduced 调用路径中触发。否则任何被动好感推断
    // （如 _inferPassiveAffection 的 +1/+2）都会把尚未见面的 NPC 标记为已结识，
    // 导致「附近/重要NPC」里出现还没登场的人物。
    // （如果确实需要在好感变化时引入 NPC，调用方应显式调用 markNpcIntroduced。）

    // 统一使用 absoluteDayIndex（跨年单调递增）作为"当前天数"口径，
    // 避免 dayOfYear 跨年相减为负/口径不一致。
    final currentDay = worldState.time.absoluteDayIndex;
    // 跨月自动重置本月好感增量（affectionMonthKey 记录 monthKey）
    final monthKey = worldState.time.year * 12 + worldState.time.month;
    if (npc.affectionMonthKey != monthKey) {
      npc.affectionMonthKey = monthKey;
      npc.affectionGainedThisMonth = 0;
    }
    int actualChange = change;
    if (change > 0) {
      final cap = npc.getAffectionGainLimit(gameWeek);
      if (cap <= 0) {
        actualChange = 0;
        if (npc.affectionGainedThisWeek == Balance.weekOneAffectionCap) {
          notifications.add('📊 ${npc.name}的好感本周已达上限，无法继续提升');
          worldState.addNarrativeEvent('📊 ${npc.name}的好感本周已达上限，无法继续提升', turn: turnCount);
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
        worldState.addNarrativeEvent('⚠️ ${npc.name}对你的信任因过去的背叛而受限', turn: turnCount);
      }
    }
    if (change < -15) {
      npc.addGrudge('betrayal', reason ?? '背叛/欺骗', currentDay);
      notifications.add('💔 ${npc.name}因你的行为而记恨在心');
      worldState.addNarrativeEvent('💔 ${npc.name}因你的行为而记恨在心', turn: turnCount);
    }
    npc.affection = (npc.affection + actualChange).clamp(-100, 100);
    if (npc.affection > npc.maxAffectionReached) {
      npc.maxAffectionReached = npc.affection;
    }
    _advanceLoveStage(npc);
    if (actualChange != 0) {
      final eventText = '好感 ${actualChange > 0 ? '+' : ''}$actualChange：${reason ?? '互动'}';
      npc.recentEvents.insert(0, eventText);
      if (npc.recentEvents.length > 10) npc.recentEvents.removeLast();
    }
    // ====== 长线记忆写入：好感显著变化时更新 T2 关系锚点 ======
    // 只有 |change| >= 5 的显著变化才写入，避免日常 +1/+2 刷屏记忆库。
    // 这是"数百回合后 AI 仍记得关系演变"的关键管线。
    if (actualChange.abs() >= 5) {
      _recordRelationshipMoment(npc, actualChange, reason);
    }
    checkAffectionAchievements(npc);
    notifyListeners();
    autoSave();
  }

  /// 好感显著变化时写入 T2 关系锚点（关键转折点）
  void _recordRelationshipMoment(NPC npc, int change, String? reason) {
    final ts = worldState.time.format();
    final moment = '$ts 好感${change > 0 ? '+' : ''}$change（${reason ?? '互动'}），当前好感${npc.affection}';
    // 根据好感值推断关系阶段
    String stage;
    if (npc.affection <= -30) {
      stage = '敌对';
    } else if (npc.affection < 0) {
      stage = '冷淡';
    } else if (npc.affection < 20) {
      stage = '认识';
    } else if (npc.affection < 50) {
      stage = '朋友';
    } else if (npc.affection < 70) {
      stage = '好友';
    } else if (npc.affection < 85) {
      stage = '亲密';
    } else {
      stage = '深爱';
    }
    memory = memory.upsertRelationshipAnchor(NpcRelationshipAnchor(
      npcId: npc.id,
      firstMeeting: '', // 空=保留已有初见记录
      keyMoments: [moment],
      currentStage: stage,
      lastUpdatedTurn: turnCount,
    ));
  }

  /// 恋爱链路接线：好感跨过阈值时推进关系阶段（陌生→好感→暧昧）。
  /// 暧昧阶段是 NPC 主动表白的前置条件，此前该链路无人调用导致表白永远无法触发。
  void _advanceLoveStage(NPC npc) {
    final p = player;
    if (p == null) return;
    final love = p.loveState;
    if (love.status != '单身') return;
    final stage = love.stageFor(npc.name);
    if (stage == '暧昧' || stage == '亲密') return;
    final absDay = worldState.time.absoluteDayIndex;
    if (npc.affection >= Balance.romanceLockThreshold) {
      love.setStage(npc.name, '暧昧', currentDay: absDay);
      notifications.add('💗 你和${npc.name}之间的关系变得暧昧起来……');
      worldState.addNarrativeEvent('💗 你和${npc.name}之间的关系变得暧昧起来……', turn: turnCount);
    } else if (npc.affection >= Balance.trustLockThreshold && stage == '陌生') {
      love.setStage(npc.name, '好感');
    }
  }

  @override
  Future<void> updateApiKey(String key) async {
    await appProvider.saveApiKey(key);
    updateClient();
    chatService.refreshClient();
  }

  @override
  void updatePlayerSignature(String text) {
    final p = player;
    if (p == null) return;
    p.signature = text;
    notifyListeners();
    autoSave();
  }

  @override
  void setCurrentLocationLabel(String label) {
    worldState.currentLocationLabel = label;
    notifyListeners();
    autoSave();
  }
}
