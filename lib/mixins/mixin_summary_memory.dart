/// 长线记忆 · 摘要与记忆管线 mixin（阶段3 拆分自 mixin_narrative.dart）。
///
/// 【拆分说明】剧情摘要（在线 AI 摘要 + 离线本地摘要）、结构化记忆提取
/// （T0/T1/T3）、伏笔了结、关系快照等约 800 行，从 5000 行的
/// `mixin_narrative.dart` 迁入本文件。触发节奏常量、失败退避、
/// 纯函数判定（shouldRunPeriodicSummary / cooldownForFailCount）一并迁入，
/// `summary_rhythm_test.dart` 等测试改为引用本 mixin（接口不变）。
///
/// 本 mixin 仍 `on GameProviderBase`：摘要与玩家状态/NPC/记忆层耦合紧密，
/// 拆到独立类需要同步迁移字段（pendingSummary / narrativeSummary 等），
/// 属后续工作；本步先做文件级解耦，行为零变化。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/canon_events.dart';
import '../data/pet_data.dart';
import '../data/wand_data.dart';
import '../models/game_systems.dart';
import '../models/npc.dart';
import '../models/player.dart';
import '../models/long_term_memory.dart';
import '../prompts/summary_prompts.dart';
import '../services/ai_router.dart';
import '../utils/debug_log.dart';
import '../providers/game_provider_base.dart';
import '../data/foreshadow_data.dart';
import '../data/memory_importance_config.dart';
import '../data/rivalry_data.dart';
import '../models/story_progress.dart';
import 'mixin_narrative_continuity.dart';

/// 长线记忆 · 摘要与记忆管线。挂在 [GameProviderBase] 上。
mixin GameSummaryMemoryMixin on GameProviderBase, GameNarrativeContinuityMixin {
  /// 行首列表符号（- / * / • / 1. 等），清洗 AI 返回的列表行时剥掉。
  static final RegExp _reListPrefix = RegExp(r'^\s*(?:[-*•]|\d+[.、)])\s*');
  /// 列表行分隔（空行 / 换行 / 中文分号）。
  static final RegExp _reListSeparator = RegExp(r'\n\s*\n|\n|；');

  // ==================== 剧情摘要机制：模型升级后放宽规模 ====================

  /// 待摘要缓冲上限：模型能力升级后 4000→8000 字，一次摘要可以压缩更多回合，减少摘要 AI 调用频次
  static const int _maxPendingSummaryChars = 8000;

  // ====== 摘要节奏常量（集中定义，消除散落的魔法数字）======

  /// 摘要的回合数触发间隔。
  ///
  /// 【注意】它不是实际触发间隔——字数分支通常先命中（见 shouldRunPeriodicSummary）。
  static const int kSummaryIntervalTurns = 20;

  /// 待摘要字数提前触发阈值。必须 < [_maxPendingSummaryChars]，
  /// 才能在缓冲溢出丢字之前先压缩一次。二者关系由测试断言。
  static const int kSummaryEarlyTriggerChars = 6800;

  /// 摘要失败后的基础冷却回合数（第 1 次失败）。
  static const int _summaryFailCooldownTurns = 2;

  /// 摘要失败冷却的回合数上限（避免长局把摘要永久停掉）。
  static const int _summaryFailCooldownMaxTurns = 10;

  /// 当前剩余的退避回合数。> 0 时 shouldRunPeriodicSummary 不触发。
  static int _summaryCooldownRemaining = 0;

  /// 剩余退避回合数（测试/诊断读取）。
  @visibleForTesting
  static int get summaryCooldownRemaining => _summaryCooldownRemaining;

  /// 失败后设定退避（纯逻辑，供测试直接调用）。
  @visibleForTesting
  static void applySummaryCooldown(int consecutiveFails) {
    _summaryCooldownRemaining = cooldownForFailCount(consecutiveFails);
  }

  /// 每回合递减退避计数（在 maybeRunPeriodicSummary 里调用一次）。
  static void tickSummaryCooldown() {
    if (_summaryCooldownRemaining > 0) _summaryCooldownRemaining--;
  }

  /// 摘要连续失败计数（Q8 玩家感知）。
  ///
  /// 修复前：摘要失败只写 debugLog，玩家完全无感知——长线局若摘要持续失败
  /// （如配额耗尽），玩家不知道「记忆正在丢」，最老部分会被截断标记替代。
  /// 连续失败达到 [_summaryFailNotifyThreshold] 次时给玩家一次性弱提示；
  /// 成功一次即清零，避免反复打扰。
  static const int _summaryFailNotifyThreshold = 3;
  static int _summaryConsecutiveFails = 0;

  /// 摘要连续失败计数（测试/诊断读取）。
  @visibleForTesting
  static int get summaryConsecutiveFails => _summaryConsecutiveFails;

  /// 摘要连续失败前进一次；返回「本次是否恰好跨过通知阈值」。
  ///
  /// 独立成纯静态方法便于测试：Q8 的核心是「连续失败 ≥ N 才通知，
  /// 成功清零」。把计数与是否通知分开，测试可直接断言边界而不必
  /// 真正发起一次失败的 AI 摘要请求。
  @visibleForTesting
  static bool advanceSummaryFailCounter() {
    _summaryConsecutiveFails++;
    return _summaryConsecutiveFails == _summaryFailNotifyThreshold;
  }

  /// 重置摘要连续失败计数与退避（读档 / 新开局复位；测试隔离也复用）。
  static void resetSummaryFailCounter() {
    _summaryConsecutiveFails = 0;
    _summaryCooldownRemaining = 0;
  }

  @override
  void accumulateForSummary(String newNarrative) {
    // BUG-I：喂 summary buffer 之前必须先清洗！
    // 旧代码直接把 AI 返回的 raw narrative 塞进去，导致：
    //  1) AI 写的【时间戳】📅1991年9月1日星期六10:45（星期/时间错）被 summary 模型
    //     当作事实吸收进剧情摘要，后续 narrative prompt 就看到这个错误时间
    //  2) AI 写的【地点】标签 / 📅 状态栏（含错误"学院：Slytherin"）污染摘要
    //  3) 好感度变化/声望变化结构化区块干扰 summary 聚焦关系和转折
    final cleaned = GameProviderBase.sanitizeNarrativeForArchive(
      newNarrative,
      keepStructuredBlocks: false, // summary 不需要好感/声望区块
    );
    pendingSummary += '$cleaned\n';
    if (pendingSummary.length > _maxPendingSummaryChars) {
      // 保留最近的剧情（尾部），丢弃最早的部分
      final cut = pendingSummary.length - _maxPendingSummaryChars;
      pendingSummary = '…（更早剧情略）\n${pendingSummary.substring(cut)}';
    }
  }

  Future<void> _summarizeNarrative() async {
    // 并发保护：摘要请求在飞时不重复发起（否则同一段剧情会被摘要两次）
    if (isSummarizing) return;
    if (pendingSummary.length < 50) {
      pendingSummary = '';
      return;
    }
    isSummarizing = true;

    // ❗先把本次要摘要的内容「取走」，再发起异步请求。
    // 旧代码在 await 返回后才清空 pendingSummary，于是请求在飞期间
    // accumulateForSummary 新积累的回合会被一起清掉 —— 那段剧情永远
    // 进不了 narrativeSummary，长线剧情出现断档。
    final chunk = pendingSummary;
    pendingSummary = '';

    // 摘要长度随游戏进度逐步放宽
    // 2026-08-23：模型能力升级，整体翻倍放开
    final limit = turnCount <= 40 ? 800 : (turnCount <= 100 ? 1500 : 2400);
    final relationSnapshot = buildRelationshipSnapshot();

    final prompt = buildSummaryPrompt(
      limit: limit,
      previousSummary: narrativeSummary,
      newChunk: chunk,
      relSnapshot: relationSnapshot,
      coreFacts: buildCoreFactsForSummary(),
    );

    try {
      final int epoch = sessionEpoch;
      final result = await callDeepSeek(prompt, scene: AiScene.summary);

      // 世代守卫：await 期间游戏被重置/读档 → 旧局摘要作废，内容交还缓冲
      if (epoch != sessionEpoch) {
        pendingSummary = chunk + pendingSummary;
        isSummarizing = false;
        return;
      }

      // 硬限制摘要保存长度——如果 AI 不肯遵守字数限制，直接强截断前 limit×1.2 字
      // 防止出现 1500+ 字摘要，造成下回合 prompt 暴涨 5000 tokens
      var rawSummary = result.content.trim();
      final hardLimit = (limit * 1.2).toInt();
      if (rawSummary.length > hardLimit) {
        rawSummary = '${rawSummary.substring(0, hardLimit)}…(已截短)';
      }

      // ====== 长线记忆提取：从摘要响应中解析结构化块写入 LongTermMemory ======
      // 这是记忆管线的核心——复用摘要调用（零额外 API），让数百回合后
      // AI 仍然拥有结构化的核心事实、未完结事项和世界事件。
      _extractMemoryFromSummary(rawSummary);

      // 从 narrativeSummary 中剥离结构化块（它们已写入 LongTermMemory，
      // 不需要在 T4 自然语言摘要中重复，避免 token 浪费）
      narrativeSummary = _stripStructuredBlocks(rawSummary);
      // 摘要成功 → 连续失败计数与退避一起清零（Q8 + 退避修复）
      _summaryConsecutiveFails = 0;
      _summaryCooldownRemaining = 0;
      // 注意：这里不再清空 pendingSummary —— 待摘要内容在请求发出前就已取走，
      // 请求在飞期间新积累的回合仍留在缓冲里，等待下一次摘要。
    } catch (e) {
      debugLog('❌ 摘要生成失败: $e');
      // 失败则把内容还回缓冲头部，下回合重试，避免剧情永久丢失
      pendingSummary = chunk + pendingSummary;
      // Q8：连续失败计数 + 达到阈值后告知玩家「记忆可能未保存」。
      // 摘要失败本身是自恢复的（下回合重试），不能每次失败都弹提示刷屏，
      // 只在「持续失败」的边界给一次弱提示，让玩家知道该去查 AI 配置/配额。
      final crossed = advanceSummaryFailCounter();
      // 退避：失败后暂停摘要若干回合，避免"失败→内容还回缓冲→字数仍超阈值
      // →下回合立即重试→再失败"的风暴（配额耗尽时每回合烧一次调用）。
      applySummaryCooldown(_summaryConsecutiveFails);
      if (crossed) {
        notifications.add(
          '📌 长线记忆连续多次未保存，请检查 AI 服务或更换模型；'
          '失败期间最老的剧情会被截断标记替代。',
        );
        notifyListeners();
      }
    } finally {
      isSummarizing = false;
    }
  }

  // 事实打分已下沉到 lib/models/long_term_memory.dart 的 [importanceForFact]：
  // 写入侧（这里）与读取侧（KeyFactRecord.fromJson 的缺省回填）必须用同一份
  // 表，否则一次结构变更丢掉 importance 字段时，读档会把「XX 死了」这类
  // 身份级事实统统按 5 分日常流水回填，静默失去永不淘汰的豁免。

  /// 从摘要响应中提取结构化记忆块，写入 LongTermMemory
  void _extractMemoryFromSummary(String rawSummary) {
    final ts = worldState.time.format();

    // 1. 提取【核心事实】→ T0 keyFacts
    final factsBlock = _extractBlock(rawSummary, '核心事实');
    if (factsBlock.isNotEmpty) {
      final facts = factsBlock
          .split('\n')
          .map((l) => l.replaceAll(_reListPrefix, '').trim())
          .where((l) => l.isNotEmpty && l != '无' && l.length > 5)
          .take(10) // 每次摘要最多提取10条，防止爆炸
          .toList();
      for (final fact in facts) {
        // 用事实内容的前20字做去重 id
        final factId = 'auto_${fact.hashCode.toRadixString(36)}';
        memory = memory.addKeyFact(
          KeyFactRecord(
            id: factId,
            fact: fact.length > 80 ? fact.substring(0, 80) : fact,
            // 以前一律给 7 分，导致 importance 这个字段在淘汰时完全失去区分度：
            // 100 条容量溢出时按分数排等于按插入顺序排，最早发生的事先被冲掉。
            // 于是第 200 回合 AI 会忘了你早已订婚、早已结仇、早已立下过誓言。
            importance: importanceForFact(fact),
            timestamp: ts,
            category: 'auto_extracted',
          ),
        );
      }
      if (facts.isNotEmpty) {
        // 记忆提取日志已移除（核心事实）
      }
    }

    // 2. 提取【伏笔】→ T1 openLoops
    final loopsBlock = _extractBlock(rawSummary, '伏笔');
    if (loopsBlock.isNotEmpty) {
      final loops = loopsBlock
          .split(_reListSeparator)
          .map((l) => l.replaceAll(_reListPrefix, '').trim())
          .where((l) => l.isNotEmpty && l != '无' && l.length > 5)
          .take(8)
          .toList();
      for (final loop in loops) {
        final loopId = 'auto_loop_${loop.hashCode.toRadixString(36)}';
        // 只添加新的（不覆盖已有的）
        final existing = memory.openLoops.where((l) => l.id == loopId);
        if (existing.isEmpty) {
          memory = memory.addOrUpdateOpenLoop(
            OpenLoopRecord(
              id: loopId,
              description: loop.length > 100 ? loop.substring(0, 100) : loop,
              status: 'open',
              importance: kImportanceAiForeshadowLoop,
              openedAt: ts,
              loopType: 'foreshadow',
              openedTurn: turnCount,
            ),
          );
        }
      }
      if (loops.isNotEmpty) {
        // 记忆提取日志已移除（伏笔/承诺）
      }
    }

    // 2.5 提取【了结】→ 关掉对应的伏笔，并给一句回响
    //
    // 伏笔在这套系统里原本是**只增不减**的：AI 每回合往 openLoops 里写，
    // 但除了委托交付之外没有任何一处会把伏笔置为 done。
    // 于是玩家从头到尾看不到任何一件悬着的事被了结，
    // 而「别忘了这些重要伏笔」那条提醒会一直念着
    // 早就因为容量溢出被悄悄丢掉的事。
    final closedBlock = _extractBlock(rawSummary, '了结');
    if (closedBlock.isNotEmpty) {
      final closedLines = closedBlock
          .split(_reListSeparator)
          .map((l) => l.replaceAll(_reListPrefix, '').trim())
          .where((l) => l.isNotEmpty && l != '无' && l.length > 4)
          .take(4) // 一段剧情里能了结的事不会太多，别让误伤扩散
          .toList();
      for (final line in closedLines) {
        _closeLoopIfMatched(line, ts);
      }
    }

    // 3. 提取【世界事件】→ T3 worldEvents
    final eventsBlock = _extractBlock(rawSummary, '世界事件');
    if (eventsBlock.isNotEmpty) {
      final events = eventsBlock
          .split('\n')
          .map((l) => l.replaceAll(_reListPrefix, '').trim())
          .where((l) => l.isNotEmpty && l != '无' && l.contains('|'))
          .take(6)
          .toList();
      for (final ev in events) {
        final parts = ev.split('|');
        if (parts.length < 2) continue;
        final title = parts[0].trim();
        final desc = parts.sublist(1).join('|').trim();
        if (title.isEmpty || desc.isEmpty) continue;
        final evId = 'auto_ev_${title.hashCode.toRadixString(36)}';
        memory = memory.addWorldEvent(
          WorldEventRecord(
            id: evId,
            timestamp: ts,
            title: title.length > 12 ? title.substring(0, 12) : title,
            description: desc.length > 60 ? desc.substring(0, 60) : desc,
            importance: kImportanceAiWorldEvent,
            category: 'wizarding',
          ),
        );
      }
      if (events.isNotEmpty) {
        // 记忆提取日志已移除（世界事件）
      }
    }

    // 4. 顺手把悬太久的伏笔放下。
    //    放在最后是因为它读的是刚更新过的 openLoops。
    _dropStaleLoops(ts);
  }

  /// 提取摘要响应中指定块的内容
  String _extractBlock(String text, String blockName) {
    final pattern = RegExp('【$blockName】\\s*\\n?([\\s\\S]*?)(?=【|\$)');
    final match = pattern.firstMatch(text);
    return match?.group(1)?.trim() ?? '';
  }

  /// 结构化块剥离（预编译，阶段4 铁律：热路径禁止现编译 RegExp）。
  static final RegExp _reBlockRelation =
      RegExp(r'【关系】[\s\S]*?(?=【|$)');
  static final RegExp _reBlockForeshadow =
      RegExp(r'【伏笔】[\s\S]*?(?=【|$)');
  static final RegExp _reBlockClosure =
      RegExp(r'【了结】[\s\S]*?(?=【|$)');
  static final RegExp _reBlockCoreFacts =
      RegExp(r'【核心事实】[\s\S]*?(?=【|$)');
  static final RegExp _reBlockWorldEvent =
      RegExp(r'【世界事件】[\s\S]*?(?=【|$)');

  /// 行首「数字+句点」序号残渣（预编译）。
  static final RegExp _reLeadingListNumber =
      RegExp(r'^\s*\d{1,2}[.．、]\s*', multiLine: true);

  /// 从摘要中剥离结构化块（已写入 LongTermMemory，不需要在 T4 中重复）
  String _stripStructuredBlocks(String text) {
    var cleaned = text;
    // 剥离【关系】【伏笔】【了结】【核心事实】【世界事件】块
    cleaned = cleaned.replaceAll(_reBlockRelation, '');
    cleaned = cleaned.replaceAll(_reBlockForeshadow, '');
    cleaned = cleaned.replaceAll(_reBlockClosure, '');
    cleaned = cleaned.replaceAll(_reBlockCoreFacts, '');
    cleaned = cleaned.replaceAll(_reBlockWorldEvent, '');
    // 日志分析第16轮D：摘要 AI 常把指令编号也输出（"1. 精简剧情摘要"），
    // 剥掉行首「数字+句点」序号残渣，避免摘要正文带着编号注入前情
    cleaned = cleaned.replaceAll(_reLeadingListNumber, '');
    return cleaned.trim();
  }

  /// 认出并关掉一条伏笔。
  ///
  /// 匹配不上就**安静地什么都不做**——AI 有时候会写一些我们从没记过的事，
  /// 那不是错误，只是这一条没法挂到某条伏笔上。硬凑一个上去，
  /// 玩家会看到一件还没办的事被宣布了结。
  void _closeLoopIfMatched(String closedText, String ts) {
    final match = pickLoopToClose(
      closedText,
      memory.openLoops,
      currentTurn: turnCount,
    );
    if (match == null) return;

    final l = match.loop;
    final held = l.openedTurn > 0 ? turnCount - l.openedTurn : 0;

    memory = memory.addOrUpdateOpenLoop(
      OpenLoopRecord(
        id: l.id,
        description: l.description,
        status: 'done',
        importance: l.importance,
        openedAt: l.openedAt,
        closedAt: ts,
        npcIds: l.npcIds,
        loopType: l.loopType,
        openedTurn: l.openedTurn,
      ),
    );

    // 回响一：一条长期记忆。
    // 给 7 分而不是沿用伏笔自己的 6 分，是为了让它挤得过日常琐事——
    // 100 条容量溢出时按分数淘汰，伏笔了结该留下来。
    memory = memory.addKeyFact(
      KeyFactRecord(
        id: 'loop_closed_${l.id}',
        fact: loopClosedFact(l.description, l.loopType),
        // 伏笔本身够重（≥8，即只比永不遗忘层低一档）→ 它的了结也进永不遗忘层。
        importance: l.importance >= kPersistentFactImportance - 1
            ? kPersistentFactImportance
            : 7,
        timestamp: ts,
        category: 'loop_closed',
        npcIds: l.npcIds,
      ),
    );

    // 回响二：一句通知，带上这件事悬了多久
    notifications.add(loopClosedNotice(l.description, l.loopType, held));
    worldState.addNarrativeEvent(
      '🔗 了结${loopTypeLabel(l.loopType)}：${l.description}',
      turn: turnCount,
    );

    // 回响三：一点声望与好感，按这件事的性质给
    final reward = rewardForLoop(l.loopType);
    final p = player;
    if (p != null) {
      for (final e in reward.reputation.entries) {
        p.playerReputation.add(e.key, e.value);
      }
    }
    if (reward.npcAffection > 0) {
      var touched = false;
      for (final id in l.npcIds) {
        updateNpcAffection(
          id,
          reward.npcAffection,
          reason: '了结了${loopTypeLabel(l.loopType)}',
          quiet: true,
        );
        touched = true;
      }
      if (touched) {
        notifyListeners();
        unawaited(autoSave());
      }
    }
    // 热路径：每次了结一条伏笔就打一行，长局下来是纯 I/O 浪费，
    // 收进 kDebugMode（第八次审查 P2-4）。
    if (kDebugMode) {
      debugLog(
        '🔗 伏笔了结 id=${l.id} score=${match.score.toStringAsFixed(2)} 悬了$held回合',
      );
    }
  }

  /// 把悬太久又没分量的伏笔放下。
  ///
  /// 玩家显然已经放弃了这些事，AI 也再没提起过；继续挂在 T1 里
  /// 只会挤掉真正重要的待办。这里是静默处理——
  /// 弹一句「你放弃了 XXX」纯属给人添堵，那是玩家用脚投的票。
  void _dropStaleLoops(String ts) {
    final drops = staleLoopsToDrop(memory.openLoops, turnCount);
    for (final l in drops) {
      memory = memory.addOrUpdateOpenLoop(
        OpenLoopRecord(
          id: l.id,
          description: l.description,
          status: 'dropped',
          importance: l.importance,
          openedAt: l.openedAt,
          closedAt: ts,
          npcIds: l.npcIds,
          loopType: l.loopType,
          openedTurn: l.openedTurn,
        ),
      );
    }
  }

  /// 生成当前重要NPC关系快照（喂给摘要 AI，用于校正长期关系记忆）。
  ///
  /// 【为什么要分层而不是只取前 5】旧实现是 `.take(5)`（按 |affection| 排序）。
  /// 摘要 AI 只看到这 5 人，第 6 人起的关系**只能凭印象写**，而写出的偏差会被
  /// `_extractMemoryFromSummary` 固化成 9 分 T0 事实，再注入 prompt 影响后续叙事——
  /// 形成"偏差 → 固化 → 注入 → 更大偏差"的闭环，且随局龄单调加重。
  ///
  /// 现在的分层规则：
  ///   1. **强关系层全量**：恋人 / 高宿敌分 / 好感 |x| ≥ [kSnapshotStrongAffection]
  ///      的 NPC，无论多少人全部入选——这些是剧情主干，错了伤最重；
  ///   2. **其余层补足**：按 |affection| 降序补齐到 [kSnapshotMaxNpcs] 人。
  ///
  /// 这样既保证主干关系不缺，又给快照一个确定的上界（避免长局 prompt 无界膨胀）。
  @override
  String buildRelationshipSnapshot() {
    final love = player?.loveState;
    final partnerId = love?.partnerId;
    final crushName = love?.currentCrushName;
    final nowDay = worldState.time.absoluteDayIndex;

    final all =
        npcRegistry.values
            .where((n) => n.introduced && n.affection != 0)
            .toList()
          ..sort((a, b) => b.affection.abs().compareTo(a.affection.abs()));

    // 第 1 层：强关系（恋人/暧昧对象/高宿敌分/高好感绝对值），全量保留
    final strong = <NPC>[];
    final rest = <NPC>[];
    for (final n in all) {
      final isPartner = partnerId != null && n.id == partnerId;
      final isCrush = crushName != null && n.name == crushName;
      final isStrong =
          isPartner ||
          isCrush ||
          n.affection.abs() >= kSnapshotStrongAffection ||
          n.rivalryTier(nowDay) != RivalryTier.none;
      (isStrong ? strong : rest).add(n);
    }

    // 第 2 层：其余按 |affection| 补足到总上限
    final remain = kSnapshotMaxNpcs - strong.length;
    final picked = <NPC>[
      ...strong,
      if (remain > 0) ...rest.take(remain),
    ];

    return picked
        .map((n) => '${n.name}:${affectionStageFor(n.affection)}/${n.affection}')
        .join('；');
  }

  /// 只在状态异常时输出状态标签（HP低/MP低/精力低/受伤），正常则不写

  String buildStatusTag(Player p) {
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

  void maybeRunPeriodicSummary() {
    // 退避计数每回合递减一次。放在最前面（在离线早退之前），
    // 这样离线期间退避也在走时钟，切回在线时不会带着过期的冷却状态。
    tickSummaryCooldown();
    // 离线快速模式红线（P#3）：全程 0 AI 调用。摘要会走 callDeepSeek(AiScene.summary)
    // 产生一次 AI 请求，离线分支必须跳过。
    //
    // 【但"不能调 AI"不等于"不能沉淀记忆"】这里以前是裸 `return`，
    // 于是离线长局的记忆彻底停摆——而 `_summarizeNarrative` 是
    // LongTermMemory 唯一的**批量**生产者。纯离线玩 200 回合后，
    // memory 里只剩开局那几条 + 剧情情报转来的 T0。
    // 现在改为走**纯本地摘要**：同样把 pendingSummary 消化掉、
    // 同样写 T0/T1/T3，只是不经过模型——0 次 AI 调用，红线不破。
    if (appProvider.offlineQuickMode) {
      _runOfflineLocalSummary();
      return;
    }
    if (shouldRunPeriodicSummary(
      turnCount,
      pendingSummary.length,
      consecutiveFails: _summaryConsecutiveFails,
      cooldownRemaining: _summaryCooldownRemaining,
    )) {
      unawaited(
        Future.microtask(() async {
          try {
            await _summarizeNarrative();
          } catch (e) {
            debugLog('摘要生成失败(不影响游戏): $e');
          }
        }),
      );
    }
  }

  /// 离线本地摘要：不调用任何模型，用本地规则把叙事缓冲压成长期记忆。
  ///
  /// 【它解决什么问题】离线模式的记忆生产者是**零个**。`_summarizeNarrative`
  /// 被离线守卫挡在门外，而它是 T0 核心事实、T1 未完结事项、T3 世界大事
  /// 唯一的批量写入方。玩家越是用离线模式长期玩（正是本项目的目标玩法），
  /// 记忆库越空——玩到第 300 回合，AI 换回来时对前 290 回合一无所知。
  ///
  /// 【怎么在 0 次 AI 调用下做到】
  /// 摘要的**本质**是把"一段流水账"抽成"几条结论"。AI 做的是语义抽象；
  /// 本地能做的是**结构化抽取**——`pendingSummary` 里其实已经写着结论，
  /// 只是散落在叙事文本中：
  ///   · 「📖 剧情步已讲述原著节点」这类引擎日志 → 世界大事；
  ///   · 剧情 `knowledge`（`addKnowledge` 写的）→ 核心事实；
  ///   · `storyProgress.flags` 里带语义前缀的 → 未完结事项的线索。
  /// 本地摘要就是把这些**已经存在**的结构化信号捞出来写进记忆，
  /// 再把缓冲清掉（避免无界增长）。
  ///
  /// 【与在线摘要的分工】在线摘要是"语义抽象 + 结构化抽取"两者都做；
  /// 离线只做后者。所以离线玩出来的记忆**条目更少但每条都确凿**——
  /// 这不是降级，是不同来源的合理分工。
  ///
  /// 【为什么必须清缓冲】不清的话 `pendingSummary` 会一路涨到
  /// `_maxPendingSummaryChars` 然后被截断丢弃——那些剧情就真的没了。
  void _runOfflineLocalSummary() {
    // 触发节奏沿用在线那套（20 回合 / 6800 字），但**忽略退避**：
    // 退避是为"AI 调用失败"设计的，本地路径不会失败，跟着退避只会少沉淀。
    if (!shouldRunPeriodicSummary(
      turnCount,
      pendingSummary.length,
      consecutiveFails: 0,
      cooldownRemaining: 0,
    )) {
      return;
    }

    final chunk = pendingSummary;
    // 【先取走再处理】与 `_summarizeNarrative` 同一口径：这样本回合
    // 新积累的内容不会被误清。
    pendingSummary = '';
    if (chunk.trim().length < 50) return;

    final ts = worldState.time.format();
    var wrote = 0;

    // ① 世界大事：chunk 里的引擎日志「📖 剧情步已讲述原著节点: <canon id>」。
    //    这条日志说明"本段剧情讲到了某个原著节点"，正是最该沉淀的东西。
    for (final m in RegExp(r'剧情步已讲述原著节点:\s*(canon_[a-z0-9_]+)')
        .allMatches(chunk)) {
      final node = canonEventById(m.group(1)!);
      if (node == null) continue;
      final desc = node.worldEvent?.trim();
      memory = memory.addWorldEvent(
        WorldEventRecord(
          id: 'offline_${node.id}',
          timestamp: ts,
          title: node.title,
          // 节点没声明 worldEvent 时用 directive 首句兜底——
          // 至少让"这件事发生过"留下来，而不是整个丢掉。
          description: (desc != null && desc.isNotEmpty)
              ? desc
              : _firstSentenceOf(node.directive),
          importance: node.worldEvent?.isNotEmpty == true
              ? node.worldEventImportance
              : kImportanceOfflineWorldEvent,
          category: 'wizarding',
          location: worldState.currentLocation,
        ),
      );
      wrote++;
    }

    // ② 核心事实：剧情情报（`addKnowledge` 写进 storyProgress.knowledge
    //    且已在 `_applyStoryEffect` 里进过 T0）。这里补的是**叙事文本里
    //    出现的原著角色名字**——"你和赫敏·格兰杰一起…"这类句子说明
    //    这段关系有实质进展，值得留一条。
    final seenNpc = <String>{};
    for (final npc in npcRegistry.values) {
      if (!npc.isCanon) continue;
      if (!chunk.contains(npc.name)) continue;
      if (!seenNpc.add(npc.name)) continue;
      memory = memory.addKeyFact(
        KeyFactRecord(
          id: 'offline_npc_${npc.id}',
          fact: '这段时间你和${npc.name}有过直接往来。',
          importance: kImportanceOfflineNpcRelation,
          timestamp: ts,
          category: 'relationship',
          npcIds: {npc.id},
        ),
      );
      wrote++;
    }

    // ③ 悬而未决的剧情 flag：`ps_`/`cos_` 等前缀的 flag 是"某件事被打开了"，
    //    登记成 T1 未完结事项，让长局里"还没了结的事"有账可查。
    //    只在 flag 数超过阈值时抽最近的一批——逐条登记会让 T1 爆炸。
    //
    //    【描述文本：绝不把 flag id 抄给玩家看】原来的写法是
    //    `'剧情里的「$f」还没了结。'`，于是玩家的「未完结事项」面板里
    //    会直接出现 `剧情里的「ps_read_letter_first」还没了结。`——一串
    //    英文蛇形 id，既读不懂，名字本身还在剧透（`ps_family_supportive`
    //    等于告诉玩家"你和家人的关系是支持性的"这件事被系统记了一笔）。
    //    flag id 本来就没有中文还原方式（实测 683 个 flag 含中文的为 0），
    //    所以要靠**同一局里已发生过的中文叙事**来还原它指的是哪件事：
    //    优先用解锁该 flag 的那个选择写下的 `consequence` 首句，
    //    退而求其次用情报词条，都没有才回落到"还有一件事没有了结"这种
    //    不带 id 的泛化说法。宁可说得含糊，也不能把 id 抖出来。
    const flagPrefixes = ['ps_', 'cos_', 'poa_', 'gof_', 'ootp_', 'hbp_', 'dh_'];
    final storyFlags = storyProgress.flags
        .where((f) => flagPrefixes.any(f.startsWith))
        .toList();
    for (final f in storyFlags.take(3)) {
      final loopId = 'offline_loop_$f';
      if (memory.openLoops.any((r) => r.id == loopId)) continue;
      final label = _humanizeStoryFlag(f) ?? '有一件在剧情里起了头的事';
      memory = memory.addOrUpdateOpenLoop(
        OpenLoopRecord(
          id: loopId,
          description: _unresolvedLine(label),
          status: 'open',
          importance: kImportanceOfflineFlagLoop,
          openedAt: ts,
          openedTurn: turnCount,
          loopType: 'question',
        ),
      );
      wrote++;
    }

    debugLog('🧠 离线本地摘要：消化 ${chunk.length} 字，写入 $wrote 条长期记忆');
  }

  /// 把一个剧情 flag 还原成"玩家读得懂的中文句子"，还原不出返回 null。
  ///
  /// 【为什么能还原】flag 是在玩家做选择时写下的，而那个选择自带一段
  /// 中文 `consequence`（"你抄满了整整两页纸……"）。所以只要反查
  /// `storyProgress.chosen` 里哪一次选择置位了这个 flag，就能拿回当时
  /// 的叙事——这比给 683 个 flag 手写一份中文映射表可靠得多，也不会漂。
  ///
  /// 【还原不出就不硬凑】跨部继承的 flag 可能在上一部种下，本部的
  /// `chosen` 里查不到；这时返回 null，由调用方降级成不含 id 的泛化说法。
  String? _humanizeStoryFlag(String flag) {
    // 反查：本局里哪一次选择置位了这个 flag。
    for (final entry in storyProgress.chosen.entries) {
      final step = findStoryStepAnywhere(storyProgress.bookId, entry.key);
      if (step == null) continue;
      for (final c in step.choices) {
        if (c.id != entry.value) continue;
        if (!c.effect.setFlags.contains(flag)) continue;
        final cons = _firstSentenceOf(c.consequence);
        if (cons.isNotEmpty) return cons;
      }
    }
    // 退一步：情报词条里若含中文且能对上 flag 名字，也可以当标签用。
    // （实测 407 条情报全是英文 id，这条分支基本不会命中，留着是防御。）
    for (final k in storyProgress.knowledge) {
      if (k.contains(flag)) {
        final s = _firstSentenceOf(k);
        if (s.isNotEmpty && s.runes.any((r) => r >= 0x4E00 && r <= 0x9FFF)) {
          return s;
        }
      }
    }
    return null;
  }

  /// 把一句"某件事"写成适合挂在「未完结事项」里的说法。
  ///
  /// 【为什么措辞要中立】同一条记录的 `description` 在 `status` 从
  /// `open` 翻到 `done` 之后**不会重写**（`addOrUpdateOpenLoop` 沿用旧
  /// description，只换状态）。所以描述里不能写死"至今还没有了结"——
  /// 了结之后玩家回看这一条，会读到"你把信读完了。至今还没有了结"。
  /// 描述只陈述**这件事本身**，状态由 `status` 字段表达。
  ///
  /// 【为什么要单独一个函数】`_firstSentenceOf` 保留原句末尾的句号
  /// （"你把门反锁，坐在床沿把信读完。"）。句末是终止标点时原样返回，
  /// 否则补一个句号，避免出现"读完了，。"这种叠标点。
  String _unresolvedLine(String label) {
    final t = label.trim();
    if (t.isEmpty) return '有一件在剧情里起了头的事。';
    final last = t.runes.last;
    const enders = {0x3002, 0xFF01, 0xFF1F, 0x2026}; // 。！？…
    return enders.contains(last) ? t : '$t。';
  }

  /// 学年末收口：把积压的 `offline_loop_*` 全部标记为已了结。
  ///
  /// 【为什么需要一个"集体了结"的出口】这些事项的 id 锚在剧情 flag 上，
  /// 而 flag 一旦置位就不会被清除（它们的设计意图是"某件事被打开了"，
  /// 长期有效）。于是没有人会给它们写 `closeLoops`，
  /// 它们会一直以 `status: 'open'` 挂在玩家的「未完结事项」面板上。
  ///
  /// 【为什么不干脆不登记它们】它们在长局里是有价值的：玩家中途查看
  /// 「未完结事项」，能想起"哦对，我还揽过这摊事"。有价值的是**进行中**
  /// 的部分，而不是让七年前的琐事永远占用版面。学年末正是天然的收口点。
  ///
  /// 【为什么要写"了结"记忆】和 `_closeLoopIfMatched` 保持一致：了结
  /// 一件事该在长期记忆里留一笔，否则回看时"它什么时候结束的"无从追溯。
  /// 这里刻意**不发声望奖励**——学年末一次性收掉好几条，逐条发奖励
  /// 会让声望在赛季边界上跳一下，看起来像 bug。
  LongTermMemory closeStaleOfflineLoops() {
    final ts = worldState.time.format();
    var closed = 0;
    for (final l in List<OpenLoopRecord>.from(memory.openLoops)) {
      if (l.status == 'done') continue;
      if (!l.id.startsWith('offline_loop_')) continue;
      memory = memory.addOrUpdateOpenLoop(
        OpenLoopRecord(
          id: l.id,
          description: l.description,
          status: 'done',
          importance: l.importance,
          openedAt: l.openedAt,
          closedAt: ts,
          npcIds: l.npcIds,
          loopType: l.loopType,
          openedTurn: l.openedTurn,
        ),
      );
      closed++;
    }
    if (closed > 0) {
      debugLog('📖 学年末收口：了结 $closed 条积压的剧情未完结事项');
    }
    return memory;
  }

  /// 取一段文本的第一句（给没写 worldEvent 的节点兜底用）。
  String _firstSentenceOf(String text) {
    final t = text.trim();
    if (t.isEmpty) return '';
    final idx = t.indexOf('。');
    final cut = idx > 0 ? t.substring(0, idx + 1) : t;
    return cut.length > 80 ? '${cut.substring(0, 80)}…' : cut;
  }

  /// 摘要触发判定（v5 P1 节奏 + Q8-fix 失败退避）。
  /// 因此实际节奏由字数主导，回合数分支只在剧情很短时才起作用。
  /// 这不是缺陷（早触发意味着缓冲不溢出、丢字更少），但**不能**按
  /// `20/15` 的间隔比去估算省下的调用数——那个估算只在"回合是唯一触发路径"
  /// 时成立。相关断言见 test/summary_rhythm_test.dart。
  static bool shouldRunPeriodicSummary(
    int turnCount,
    int pendingSummaryChars, {
    int consecutiveFails = 0,
    int cooldownRemaining = 0,
  }) {
    if (pendingSummaryChars <= 0) return false;
    if (cooldownRemaining > 0) return false; // 退避中
    return turnCount % kSummaryIntervalTurns == 0 ||
        pendingSummaryChars > kSummaryEarlyTriggerChars;
  }

  /// 本次失败后应设定的冷却回合数（纯函数，便于单测）。
  ///
  /// 第 1 次失败冷却 [_summaryFailCooldownTurns] 回合，之后每次 +1，
  /// 上限 [_summaryFailCooldownMaxTurns]。线性而非指数，是因为摘要失败
  /// 多半是"配额耗尽"这类需要玩家介入的问题，指数退避会让记忆停顿过久。
  static int cooldownForFailCount(int consecutiveFails) {
    if (consecutiveFails <= 0) return 0;
    final raw = _summaryFailCooldownTurns + (consecutiveFails - 1);
    return raw > _summaryFailCooldownMaxTurns
        ? _summaryFailCooldownMaxTurns
        : raw;
  }
  /// 摘要用主角既定事实（权威字段，非记忆层——防止摘要 AI 凭叙事猜测，
  /// 把哈利特征张冠李戴到原创主角身上，如"闪电疤/猫头鹰宠物"）。
  String buildCoreFactsForSummary() {
    final p = player;
    if (p == null) return '';
    final lines = <String>[];
    lines.add('- 主角是${p.name}（原创角色，不是哈利·波特，严禁把哈利特征写给他）');
    if (p.familyBackground != null && p.familyBackground!.isNotEmpty) {
      lines.add('- 家族与血统：${p.familyBackground}');
    }
    if (p.wandId != null && p.wandId!.isNotEmpty) {
      final wd = wandById(p.wandId!);
      if (wd != null) {
        final woodClean = wd.wood.endsWith('木') ? wd.wood : '${wd.wood}木';
        lines.add('- 魔杖：$woodClean·${wd.core}·${wd.length}');
      }
    }
    if (p.petId != null && p.petId!.isNotEmpty) {
      final pd = petById(p.petId!);
      final petName = (p.petName != null && p.petName!.isNotEmpty)
          ? p.petName
          : (pd?.name ?? '宠物');
      lines.add('- 契约宠物：$petName（${pd?.species ?? '未知'}）');
    }
    if (p.initialTalent != null && p.initialTalent!.isNotEmpty) {
      lines.add('- 初始天赋专精：${p.initialTalent}');
    }
    return lines.join('\n');
  }

}
