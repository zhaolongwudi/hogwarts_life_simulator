/// 存档读写子系统（阶段 r4-1 拆分自 mixin_systems.dart）。
///
/// 【拆分说明】`_saveExtraData` / `writeSave` / `quickSave` / `saveGameNamed` /
/// `applySaveData`（含快照回滚与 `_migrateSave` 版本迁移）/ `loadFromSave` /
/// `tryAutoLoad` / `listSaves` / `deleteSave` / `exportSave` / `importSave`
/// 约 390 行，从 3300+ 行的 mixin_systems 迁入本文件。
/// `GameSystemsMixin` 声明 `on GameSaveSystemMixin`（跨 mixin 走 on 链，
/// 遵守 ADR-001），`GameProvider` 的 with 列表中 save 在 systems 之前。
/// 行为零变化：所有成员仍是 GameProvider 上的实例成员，测试契约不变。
library;

import 'dart:async';


import '../models/npc.dart';
import '../models/game_systems.dart';
import '../models/player.dart';
import '../models/long_term_memory.dart';
import '../models/story_progress.dart';
import '../models/world_state.dart';
import '../data/npc_schedule_rules.dart';
import '../services/save_service.dart';
import '../providers/game_provider_base.dart';
import '../utils/debug_log.dart';
import 'mixin_summary_memory.dart';

/// 存档读写（写档盖章 / 读档快照回滚 / 版本迁移）。挂在 [GameProviderBase] 上。
mixin GameSaveSystemMixin on GameProviderBase, GameSummaryMemoryMixin {

  void runConsistencyChecks() {
    final p = player;
    if (p == null) return;
    final issues = <String>[];

    // 通知栏以前只增不清：全项目 40 多处 notifications.add，唯一的清理点是
    // resetAllState（只有「开新游戏」走得到）。长局内存无限增长，
    // /通知 又只展示最近 10 条，多出来的永远看不见。这里裁到 50 条。
    if (notifications.length > 50) {
      notifications.removeRange(0, notifications.length - 50);
    }

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
    for (final npc in npcRegistry.values) {
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
        final partnerNpc = npcRegistry[p.loveState.partnerId];
        if (partnerNpc == null || !partnerNpc.isAlive) {
          p.loveState.status = '单身';
          p.loveState.partnerId = null;
          p.loveState.partnerName = null;
          issues.add('恋爱对象已不存在，已重置为单身');
        }
      }
    }

    // ====== 时间合理性检查 ======
    final year = worldState.time.year;
    if (year < 1890 || year > 2100) {
      issues.add('年份异常: $year');
    }
    final month = worldState.time.month;
    if (month < 1 || month > 12) {
      worldState.time.month = month.clamp(1, 12);
      issues.add('月份越界，已修正');
    }
    final day = worldState.time.day;
    if (day < 1 || day > 31) {
      worldState.time.day = day.clamp(1, 31);
      issues.add('日期越界，已修正');
    }

    // ====== 时代一致性检查 ======
    final eraName = worldState.era;
    final appEra = appProvider.era.name;
    if (eraName.isNotEmpty && eraName != appEra) {
      debugLog('存档时代($eraName)与当前设置($appEra)不一致');
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
    final reputationFields = [
      'academic',
      'social',
      'combat',
      'moral',
      'leadership',
      'dark',
    ];
    for (final field in reputationFields) {
      final value = p.playerReputation.get(field);
      if (value < 0 || value > 100) {
        p.playerReputation.setValue(field, value.clamp(0, 100));
        issues.add('声望$field越界，已修正');
      }
    }

    // ====== 成就检查 ======
    checkAllAchievements();

    if (issues.isNotEmpty) {
      notifications.add('⚠️ 状态自修复：${issues.join('；')}');
      debugLog('🛡️ 防崩坏自检: 修复${issues.length}项状态异常');
    }
  }

  /// 写入存档时附带的扩展字段。
  ///
  /// 之前 quickSave / saveGameNamed / doSave 各写一份这个 Map，字段一多就
  /// 会有人漏写——漏写的字段读档时静默归零，不报错也不崩。合并成一份。
  Map<String, dynamic> _saveExtraData() => {
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
    // 千回合级结构化长期记忆（永不压缩的纯事实层）
    'long_term_memory': memory.toJson(),

    // ↓↓↓ 每日限额与一次性状态。
    // 这几项以前都不入档，于是「打满 3 场决斗 → 存档 → 读档」又能打 3 场，
    // 禁林、练咒、学咒同理，打赢过的 NPC 读档后可以再打赢一次再拿 +2 好感。
    'daily_activity_count': dailyActivityCount,
    'activity_date': activityDate,
    'last_duel_opponent_id': lastDuelOpponentId,
    'rumored_event_days': rumoredEventDays,
    'quest_board_ids': questBoardIds,
    'quest_board_week': questBoardWeek,
    'npc_generated_this_school_year': npcGeneratedThisSchoolYear,
    'npc_generation_school_year': npcGenerationSchoolYear,
    // 主线剧情进度（null = 非剧情模式，老存档自然没有这个 key）。
    // 走 extra_data 通道而不是 Player/WorldState 的 fromJson，
    // 是为了零迁移风险——见 lib/models/story_progress.dart 的文件头注释。
    'story_progress': storyProgress.toJson(),
    // 魔法世界图鉴（百科收集）已收录 id。同走 extra_data 通道零迁移。
    'collection': collectionUnlocked.toList(),
  };

  /// 统一的存档写入：快速存档 / 命名存档 / 自动存档都走这里。
  @override
  Future<void> writeSave({
    required String slotId,
    required String slotName,
  }) async {
    if (player == null) return;
    await saveService.saveGame(
      slotId: slotId,
      player: player!.toJson(),
      worldState: worldState.toJson(),
      npcRegistry: npcRegistry.map((k, v) => MapEntry(k, v.toJson())),
      narrative: currentNarrative,
      choices: choices
          .map((c) => {'text': c.text, 'action': c.action})
          .toList(),
      turnCount: turnCount,
      slotName: slotName,
      extraData: _saveExtraData(),
    );
  }

  @override
  Future<void> quickSave() async {
    await writeSave(slotId: SaveService.quickSaveSlotId, slotName: '快速存档');
  }

  /// 使用用户自定义名称保存存档（slotId 由名称生成，保证可读且唯一可寻址）
  @override
  Future<void> saveGameNamed(String slotName) async {
    final safeName = slotName
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    if (safeName.isEmpty) return;
    await writeSave(slotId: safeName, slotName: safeName);
  }

  /// 把一份存档数据灌回 provider。
  ///
  /// 自动读档（tryAutoLoad）和槽位读档（loadFromSave）必须走同一套逻辑。
  /// 之前 tryAutoLoad 是复制粘贴出来的，漏了两件事：
  ///  1. 存档版本迁移（本文件 `GameSystemsMixin._migrateSave`，约 3050 行起）
  ///     —— v1 老存档自动加载时月份字段不迁移、time 字段不补全，
  ///     世界时间直接错乱；而手动读同一个存档却是好的。
  ///  2. `runConsistencyChecks`（本文件同 mixin 内）—— 损坏的自动存档
  ///     不会被钳制，可能载入负血值。
  ///
  /// 注：迁移函数的版本判定依赖 `lib/services/save_service.dart` 中的
  /// `kSaveVersion`；升级该常量时必须同步在 `_migrateSave` 里补一个
  /// `if (version < N)` 分支，否则老档会静默跳过新字段补全。
  @override
  void applySaveData(Map<String, dynamic> data) {
    // ====== 快照：读档中途失败必须整体回滚，绝不留「新旧混合」状态 ======
    // 历史病根：player/worldState/npcRegistry 依次替换，NPC 解析中途抛异常
    // 时 player 已是新档、npcRegistry 已半清空，UI 报错但游戏跑在损坏状态上，
    // 下一回合 autoSave 还会把半截状态写盘固化。
    final snapPlayer = player;
    final snapWorld = worldState;
    final snapNpc = Map<String, NPC>.from(npcRegistry);
    final snapMemory = memory;
    final snapNarrative = currentNarrative;
    final snapChoices = List<GameChoice>.from(choices);
    final snapTurn = turnCount;
    try {
      invalidateSessionEpoch(); // 在飞 AI 请求的世代号作废，返回后丢弃
      final version = data['save_version'] as int? ?? 1;
      _migrateSave(data, version);

      player = Player.fromJson(data['player'] as Map<String, dynamic>);
      worldState = WorldState.fromJson(
        data['world_state'] as Map<String, dynamic>,
      );
      npcRegistry.clear();
      final npcMap =
          data['npc_registry'] as Map<String, dynamic>? ?? <String, dynamic>{};
      npcMap.forEach((k, v) {
        npcRegistry[k] = NPC.fromJson(v as Map<String, dynamic>);
      });
      // 在 player/worldState/npc 赋值之后再构建系统提示词（_buildSystemPrompt 会用到）
      systemPrompt = buildSystemPrompt();

      // ====== 会话态字段复位 ======
      // 这些字段以前只被 resetAllState 清（那条路只有「开新游戏」和设置页走），
      // 读档时一个都不动。于是从 A 档切到 B 档，B 档会带着 A 档的：
      // 今日决斗/禁林次数、刚打过的决斗对手、委托板板面、新 NPC 配额……
      // 更隐蔽的是跨天清零用的 activityDate 也是 A 档的，跨天判定直接错乱。
      // 这里统一先清成默认值，再让 extraData 覆盖——存档里有的用存档的，
      // 没有的（老档）就保持「干净开局」，不会串味。
      dailyActivityCount.clear();
      activityDate = '';
      lastDuelOpponentId = null;
      rumoredEventDays.clear();
      questBoardIds = [];
      questBoardWeek = 0;
      npcGeneratedThisSchoolYear = 0;
      npcGenerationSchoolYear = 0;
      lastTrackedLocation = null;
      turnsAtSameLocation = 0;
      commandResult = null;
      notifications.clear();
      lastAffectionSections.clear();
      // 摘要连续失败计数是 static（P#10）：读档不归零会让上一局/上一个档的
      // 失败计数串到新档，误触发「记忆未保存」提示。这里显式归零。
      GameSummaryMemoryMixin.resetSummaryFailCounter();

      // 读档后按当前时钟重新安排每个人的位置。存档里 NPC 带着
      // currentLocation 字段，但老档里它恒为 '霍格沃茨'，刷新一次最稳。
      refreshNpcLocations(
        npcRegistry.values,
        worldState.time.hour,
        worldState.time.weekday,
      );

      currentNarrative = data['narrative'] as String? ?? '';
      choices =
          (data['choices'] as List<dynamic>?)
              ?.map(
                (c) => GameChoice(
                  text: c['text'] as String,
                  action: c['action'] as String,
                ),
              )
              .toList() ??
          [];
      turnCount = data['turn_count'] as int? ?? 0;
      final extraData = data['extra_data'] as Map<String, dynamic>? ?? {};
      narrativeSummary = extraData['narrative_summary'] as String? ?? '';
      pendingSummary = extraData['pending_summary'] as String? ?? '';
      gameWeek = extraData['game_week'] as int? ?? 1;
      lastSchoolYearStart = extraData['last_school_year_start'] as int? ?? 0;
      // 读档：以存档时间为跨周基准，避免把"存档前的旧桶号"与"当前时间"相比
      // 导致读档瞬间误判跨周。惰性建立同样安全，这里显式设置是为了语义清晰。
      lastWeekBucket = worldState.time.absoluteDayIndex ~/ 7;
      lastRoundTokens = extraData['last_round_tokens'] as int? ?? 0;
      apiCalls = extraData['api_calls'] as int? ?? 0;
      totalPromptTokens = extraData['total_prompt_tokens'] as int? ?? 0;
      totalCompletionTokens = extraData['total_completion_tokens'] as int? ?? 0;
      totalTokens = extraData['total_tokens'] as int? ?? 0;
      // 加载千回合级结构化长期记忆
      memory = LongTermMemory.fromJson(
        extraData['long_term_memory'] as Map<String, dynamic>?,
      );

      // 每日限额与一次性状态：老档没有这些键，读到 null 就保持上面清好的默认值
      final savedDaily =
          extraData['daily_activity_count'] as Map<String, dynamic>?;
      if (savedDaily != null) {
        savedDaily.forEach((k, v) {
          if (v is int) dailyActivityCount[k] = v;
        });
      }
      activityDate = extraData['activity_date'] as String? ?? activityDate;
      lastDuelOpponentId = extraData['last_duel_opponent_id'] as String?;
      // Batch 8 · Issue #12：读档 rumoredEventDays（老档没有这个键，保持空 map）
      final savedRumored =
          extraData['rumored_event_days'] as Map<String, dynamic>?;
      if (savedRumored != null) {
        savedRumored.forEach((k, v) {
          if (v is int) rumoredEventDays[k] = v;
        });
      }
      questBoardIds =
          (extraData['quest_board_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          questBoardIds;
      questBoardWeek = extraData['quest_board_week'] as int? ?? questBoardWeek;
      npcGeneratedThisSchoolYear =
          extraData['npc_generated_this_school_year'] as int? ??
          npcGeneratedThisSchoolYear;
      npcGenerationSchoolYear =
          extraData['npc_generation_school_year'] as int? ??
          npcGenerationSchoolYear;

      // 主线剧情进度。老存档没有这个 key → fromJson(null) 返回 inactive，
      // 行为与加此功能之前完全一致（零迁移）。这是设计里"老存档兼容"的落点。
      //
      // 【为什么手写 as 而不是直接 cast】手改/损坏的存档里这个 key 可能是
      // 任意类型（字符串、列表…）。`as Map<String, dynamic>?` 抛出的
      // TypeError 会打断整个 applySaveData（整局读档失败），而剧情进度
      // 丢了最多回到沙盒模式。局部 try 包住，脏数据只损失剧情进度本身。
      try {
        storyProgress = StoryProgress.fromJson(
          extraData['story_progress'] as Map<String, dynamic>?,
        );
      } catch (e) {
        debugLog('[mixin_systems] 剧情进度恢复失败，按未激活处理: $e');
        storyProgress = StoryProgress.inactive;
      }

      // 图鉴收录：老存档没有该键 → 空集合，行为与加此功能前一致（零迁移）。
      collectionUnlocked
        ..clear()
        ..addAll(
          (extraData['collection'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const <String>[],
        );

      recentTurns
        ..clear()
        ..addAll(
          (extraData['recent_turns'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
        );
      if (recentTurns.isEmpty && currentNarrative.isNotEmpty) {
        recentTurns.add(currentNarrative);
      }

      // 完整性兜底：只在空的时候补默认
      if (choices.isEmpty) choices = buildFallbackChoices(currentNarrative);
      if (choices.length > 4) choices = choices.sublist(0, 4);
      if (currentNarrative.isEmpty) {
        currentNarrative = generateFallbackNarrative();
      }

      // 任何读档之后都必须确保 isLoading=false / isInitializing=false，
      // 否则"继续游戏"后会卡住或误触发再次请求
      isLoading = false;
      isInitializing = false;
      error = null;
      loadingStage = '';

      runConsistencyChecks();
    } catch (e, st) {
      // 整体回滚到读档前状态，让调用方（loadFromSave）只负责报错提示
      player = snapPlayer;
      worldState = snapWorld;
      npcRegistry
        ..clear()
        ..addAll(snapNpc);
      memory = snapMemory;
      currentNarrative = snapNarrative;
      choices = snapChoices;
      turnCount = snapTurn;
      debugLog('❌ applySaveData 解析失败，已整体回滚: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<void> loadFromSave(String slotId) async {
    try {
      final data = await saveService.loadGame(slotId);
      if (data == null) {
        // 存档不存在或已损坏且无备份可回滚：静默 return 会让 UI 毫无反馈（BUG-FIX）
        error = '存档加载失败：存档不存在或已损坏（slot $slotId）';
        notifyListeners();
        return;
      }
      applySaveData(data);
      // _applySaveData 里已经把 isLoading/isInitializing 复位了
      appProvider.setGameStarted(true);
      notifyListeners();
      unawaited(autoSave());
    } catch (e, st) {
      // 解析中途抛异常会留下半截状态（player 已换、npc 已清），必须兜底
      error = '存档加载失败：$e';
      debugLog('❌ loadFromSave($slotId) failed: $e\n$st');
      notifyListeners();
    }
  }

  /// 存档格式升级：把老版本 data 就地补全到当前 [kSaveVersion] 形状。
  ///
  /// 触发点只有一处：[applySaveData] 在解析 JSON 之后、构造 `Player`/`WorldState`
  /// 之前调用（见上方 `_migrateSave(data, version)`）。调用前 `version` 取自
  /// `data['save_version']`，缺失按 v1 处理。
  ///
  /// 新增版本的规矩：升级 [kSaveVersion]（`lib/services/save_service.dart`）
  /// 时，这里必须补一个 `if (version < N) { ... }` 分支，并在分支末尾写入
  /// `data['save_version'] = kSaveVersion`，否则存档会被反复迁移。
  void _migrateSave(Map<String, dynamic> data, int version) {
    if (version < 2) {
      final ws = data['world_state'] as Map<String, dynamic>?;
      if (ws != null) {
        const monthNames = [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ];
        final oldMonth = ws['month'] as String?;
        if (oldMonth != null) {
          final idx = monthNames.indexOf(oldMonth);
          if (idx >= 0) {
            ws['month'] = GameTime.months[idx];
            debugLog('存档迁移: month "$oldMonth" -> "${ws['month']}"');
          }
        }
        if (!ws.containsKey('time')) {
          debugLog('存档迁移: 从旧字段推导 time 字段');
          final yearStr = ws['academic_year'] ?? '1991-1992';
          final yearMatch = RegExp(r'^(\d{4})').firstMatch(yearStr.toString());
          final year = yearMatch != null
              ? int.tryParse(yearMatch.group(1)!) ?? 1991
              : 1991;
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
      data['save_version'] = kSaveVersion;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listSaves() async {
    return saveService.listSaves();
  }

  @override
  Future<bool> deleteSave(String slotId) async {
    return saveService.deleteSave(slotId);
  }

  /// 导出存档为 JSON 字符串（用于备份/跨设备迁移）
  @override
  Future<String?> exportSave(String slotId) async {
    return saveService.exportSave(slotId);
  }

  /// 从 JSON 字符串导入存档，返回新槽 id
  @override
  Future<String?> importSave(String jsonString) async {
    return saveService.importSave(jsonString);
  }

  @override
  void resetTokenUsage() {
    totalPromptTokens = 0;
    totalCompletionTokens = 0;
    totalTokens = 0;
    apiCalls = 0;
    notifyListeners();
  }
}
