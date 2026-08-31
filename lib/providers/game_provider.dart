import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'app_provider.dart';
import 'game_provider_base.dart';
import '../mixins/game_provider_mixins.dart';
import '../data/balance_constants.dart';
import '../data/rivalry_data.dart';
import '../services/save_service.dart';
import '../services/npc_chat_service.dart';
import '../services/ai_router.dart';
import '../services/rate_limiter.dart';
import '../utils/crash_logger.dart';
import '../models/npc.dart';
import '../models/long_term_memory.dart';
// 裸导入是为了拿 CgDef 类型；别名导入是为了调到顶层 cgById()，
// 不然会和下面的 cgById 方法名撞上。两个都需要。
import '../data/cg_data.dart';
import '../data/cg_data.dart' as cgData;

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
        GamePlayMixin,
        GameAnimagusMixin,
        GameDeathMixin,
        GameCareerMixin {
  @override
  bool markScanIfNew(String narrative) {
    final h = narrative.hashCode;
    if (lastScannedNarrativeHash != null && h == lastScannedNarrativeHash) {
      return false;
    }
    lastScannedNarrativeHash = h;
    return true;
  }

  /// CG 数据表查询。实现直接复用 cg_data.dart 的顶层同名函数
  /// （用 show-as 别名避开与自身方法名冲突）。
  /// 声明在基类上是为了让各 mixin 也能通过基类接口访问它。
  @override
  CgDef? cgById(String id) => cgData.cgById(id);
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
      // 与槽位读档共用一套灌数据逻辑（含存档迁移 + 一致性检查）。
      // 之前这里是复制粘贴的，漏了 _migrateSave：v1 老存档自动加载时月份
      // 字段不迁移、time 字段不补全，世界时间直接错乱，而手动读同一个存档
      // 却是好的。_applySaveData 内部已复位 isLoading/isInitializing/error。
      applySaveData(data);

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
    // 旧实现：`if (_saveScheduled) return;` —— 手动存档时若恰好有一次
    // 自动存档在途（300ms 防抖 + 写盘），这次手动保存会被**静默丢弃**，
    // 玩家以为存了，其实没存。改成先等在途的那次落地，再立刻无条件存一次。
    final pending = _pendingSave;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {
        // 在途自动存档失败不影响手动存档，继续往下走
      }
    }
    _saveScheduled = false;
    await doSave(debounce: false);
  }

  @override
  Future<void> doSave({required bool debounce}) async {
    try {
      if (debounce) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
      await writeSave(
        slotId: SaveService.autoSaveSlotId,
        slotName: '自动存档',
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
  /// [severity] 是 AI 写下的原始幅度（未压缩）。
  ///
  /// 好感解析器会把一次 -30 压成 -5 以抑制数值膨胀——那是数值层的事；
  /// 但"这件事有多大"是另一回事，结仇判定得看原始意图，
  /// 否则 AI 永远写不出一次真正的翻脸。不传就退回落地值 [change]。
  void updateNpcAffection(String npcId, int change,
      {String? reason, int? severity, bool quiet = false}) {
    final npc = npcRegistry[npcId];
    if (npc == null) return;
    // /cheat 固定好感：锁定后好感对一切系统变动免疫（衰减/背叛/送礼/事件），
    // 只有 /cheat 好感 直接改数值本身才动得了。
    if (npc.affectionLocked) return;
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
      // 和解的门留在这儿：结了仇不是死局，一次真心实意的示好能削掉一点旧账。
      // 门槛设在 8，是因为日常 +1/+2 的寒暄不该算赎罪——
      // 那会让宿敌在不知不觉中被时间刷白，玩家的补救也就没了意义。
      if (actualChange >= 8 && npc.applyAmends(currentDay) > 0) {
        notifications.add('🕊️ ${npc.name}对你的态度松动了一些');
        worldState.addNarrativeEvent('🕊️ ${npc.name}对你的态度松动了一些', turn: turnCount);
      }
      if (npc.tickRivalry(currentDay)) {
        // 从死对头到能坐下来喝一杯，这条线索值得单独留一笔
        notifications.add('🤝 你和${npc.name}之间那笔旧账，就这么过去了');
        worldState.addNarrativeEvent(formerRivalLine(npc.name), turn: turnCount);
      }
    }
    // ====== 怨气累计与结仇判定 ======
    // 原先这里的门槛是 change < -15。但好感解析器会把 AI 写的一次 -30
    // 压成 -5（抑制数值膨胀），于是这条分支在实战里永远进不去——
    // 宿敌系统除了决斗那条路，七年也触发不了一次。
    //
    // 改成两路并行：
    //  · burst：AI 的原始幅度够狠（severity <= -8），当场翻脸；
    //  · accumulated：单次不够狠的先攒进 pendingSpite，攒够了再爆。
    npc.pendingSpite = change < 0
        ? accumulateSpite(npc.pendingSpite, change)
        : relieveSpite(npc.pendingSpite, change);
    final burst = (severity ?? change) <= kBurstSeverityThreshold;

    if (shouldRecordGrudge(
        change: change, severity: severity, pendingSpite: npc.pendingSpite)) {
      // 宿敌成因从 reason 里认。原先一律记成 'betrayal'，
      // 于是"当众让他下不来台"和"骗了他"在宿敌分里完全等价，
      // 玩家自然也感觉不出区别。
      final cause = burst ? causeFromReason(reason) : RivalryCause.accumulated;
      final causeKey = causeKeyFor(cause);
      final why = burst ? (reason ?? '背叛/欺骗') : '一次次的摩擦，攒够了';
      // 得在 addGrudge 之前抓：那个方法会把 lastGrudgeDay 改写成今天。
      final alreadyNotifiedToday = npc.lastGrudgeDay == currentDay;
      final tierBefore = npc.rivalryTier(currentDay);
      npc.pendingSpite = 0;
      npc.addGrudge(causeKey, why, currentDay);
      npc.tickRivalry(currentDay);
      final tierAfter = npc.rivalryTier(currentDay);

      // 同一天同一个人不重复播报"记恨着你"——升档那句还是会照常说。
      if (!alreadyNotifiedToday) {
        final base = '💔 ${npc.name}记恨着你（${causeLabelFor(causeKey)}）';
        notifications.add(base);
        worldState.addNarrativeEvent(base, turn: turnCount);
      }

      // 升档单独提示一次。宿敌这件事必须让玩家感知得到，
      // 否则他只注意到"好感涨不上去了"，却不知道对面多了个仇人。
      // 一局里每个人最多提示四次，不会刷屏。
      if (tierAfter.index > tierBefore.index) {
        final escalated = switch (tierAfter) {
          RivalryTier.grudge => '🙄 你和${npc.name}之间有了芥蒂',
          RivalryTier.hostile => '😠 ${npc.name}开始公开跟你过不去',
          RivalryTier.nemesis => '⚔️ ${npc.name}已经把你当成宿敌',
          RivalryTier.archenemy => '💀 ${npc.name}恨你入骨，且不在乎代价了',
          RivalryTier.none => '',
        };
        if (escalated.isNotEmpty) {
          notifications.add(escalated);
          worldState.addNarrativeEvent(escalated, turn: turnCount);
        }
      }
    }
    npc.affection = (npc.affection + actualChange).clamp(-100, 100);
    if (npc.affection > npc.maxAffectionReached) {
      npc.maxAffectionReached = npc.affection;
    }
    // 好感真的动过才算"互动过"——维系衰减的 idle 计时从这天重新起算。
    // 注意要用 actualChange（落地值）而不是 change（意图值）：
    // 被周上限挡掉的 +0 不算互动，否则顶着上限硬刷也能保鲜。
    if (actualChange != 0) {
      npc.lastAffectionTouchDay = currentDay;
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
    // 批量调用（quiet）由调用方在循环结束后统一通知一次：
    // 以前「日常好感微调」遍历全 NPC，每人一次 notifyListeners + 一次
    // 全量写档，一回合下来 5 次全量 rebuild、5 次整档序列化。
    if (quiet) return;
    notifyListeners();
    unawaited(autoSave());
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
    unawaited(autoSave());
  }

  @override
  void setCurrentLocationLabel(String label) {
    worldState.currentLocationLabel = label;
    notifyListeners();
    unawaited(autoSave());
  }
}
