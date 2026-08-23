import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../services/rate_limiter.dart';
import '../data/pet_data.dart';
import '../providers/app_provider.dart';
import '../models/npc.dart';
import '../models/game_systems.dart';
import '../services/save_service.dart';
import '../services/deepseek_service.dart';
import '../data/cg_data.dart';
import '../utils/story_text_renderer.dart';
import '../services/npc_chat_service.dart';
import '../data/world_rules.dart';
import '../data/event_anchors.dart';
import '../models/player.dart';
import '../utils/prompt_sanitizer.dart';
import '../data/trait_data.dart';
import '../data/npc_data.dart';
import '../prompts/prompts.dart';
import '../models/long_term_memory.dart';
import '../data/course_data.dart';
import '../data/balance_constants.dart';
import '../data/goal_data.dart';
import '../data/wand_data.dart';
import '../services/ai_router.dart';
import '../models/world_state.dart';
import '../utils/crash_logger.dart';
import '../providers/game_provider_base.dart';

mixin GameNarrativeMixin on GameProviderBase {
  Future<void> processChoice(GameChoice choice) async {
    if (player == null) return;

    // 本地指令解析
    final action = choice.action.trim();
    if (action.startsWith('/')) {
      final prevNarrative = currentNarrative;
      final prevChoices = List<GameChoice>.from(choices);
      final handled = handleLocalCommand(action);
      if (handled) {
        // 查看类指令（/状态 /关系 /信 /课堂 互动 等，特征是结尾选项为
        // 「返回/继续」）：输出进独立面板，不覆盖当前回合剧情。
        // 此前指令直接改写剧情，而「返回」的 action 又是「继续」，
        // 会作为玩家行动发给 AI 重新生成，导致当前回合剧情丢失。
        final isPanelOutput = currentNarrative != prevNarrative &&
            choices.length == 1 &&
            choices[0].action == '继续' &&
            (choices[0].text == '返回' || choices[0].text == '继续');
        if (isPanelOutput) {
          commandResult = currentNarrative;
          currentNarrative = prevNarrative;
          choices = prevChoices;
        } else {
          // 事件类指令（/新NPC /结局 等）正常替换剧情，同时关闭旧面板
          commandResult = null;
        }
        notifyListeners();
        autoSave();
        return;
      }
    }

    // 用户自由文本在进入 Prompt 前做注入防御净化
    final safeAction = PromptSanitizer.sanitizeAction(action);

    if (router == null || !router!.hasNarrativeService) return;

    commandResult = null; // 提交真实行动时关闭指令面板
    isLoading = true;
    turnCount++;
    lastPlayerAction = safeAction;
    loadingStage = '正在构建请求...';
    notifyListeners();

    String buildPrompt() {
      final p = player!;

      final contextBuffer = StringBuffer();

      // ========== T0 / T1 / T2 / T3 结构化长期记忆注入（永不压缩的纯事实层） ==========
      // 永远放在【世界上下文】最前面，防止后面截断看不到
      // 2026-08-23：模型能力升级，所有条数限制整体翻倍
      // T0: 核心事实 (importance ≥ 4，重要性高到低，最多60条；importance 10永远保留)
      final t0 = memory.keyFacts
          .where((f) => f.importance >= 4)
          .toList()
        ..sort((a, b) => b.importance.compareTo(a.importance));
      if (t0.isNotEmpty) {
        contextBuffer.writeln('【T0 核心事实（永不遗忘；纯事实，不得更改或遗忘）】');
        for (int i = 0; i < t0.length && i < 60; i++) {
          final f = t0[i];
          contextBuffer.writeln('• [${f.importance}] ${f.fact}');
        }
        contextBuffer.writeln('');
      }
      // T1: 未完结事项 (open 状态优先，importance 排序，最多 40 条)
      final t1 = memory.openLoops.where((l) => l.status == 'open').toList()
        ..sort((a, b) => b.importance.compareTo(a.importance));
      if (t1.isNotEmpty) {
        contextBuffer.writeln('【T1 未完结事项（承诺/债务/约定/未完成任务，说话要算数）】');
        for (int i = 0; i < t1.length && i < 40; i++) {
          final l = t1[i];
          contextBuffer.writeln('• [${l.importance}] ${l.description}');
        }
        contextBuffer.writeln('');
      }
      // T2: NPC 关键关系（按 |好感| 取前 24 个 NPC 的结构化关系锚）
      final topNpcs = npcRegistry.values.toList()
        ..sort((a, b) => b.affection.abs().compareTo(a.affection.abs()));
      final t2Lines = <String>[];
      for (int i = 0; i < topNpcs.length && i < 24; i++) {
        final npc = topNpcs[i];
        final anchor = memory.relationshipAnchors[npc.id];
        if (anchor == null) continue;
        final buf = StringBuffer();
        buf.write('${npc.name}(好感${npc.affection >= 0 ? '+' : ''}${npc.affection}，${anchor.currentStage})');
        if (anchor.firstMeeting.isNotEmpty) buf.write('｜初见:${anchor.firstMeeting}');
        if (anchor.keyMoments.isNotEmpty) {
          // 注入最后 6 个关键转折点（3→6）
          buf.write('｜关键:${anchor.keyMoments.skip(max(0, anchor.keyMoments.length - 6)).join("；")}');
        }
        if (anchor.secretsShared.isNotEmpty) buf.write('｜交换秘密:${anchor.secretsShared.take(6).join("；")}');
        if (anchor.promisesExchanged.isNotEmpty) buf.write('｜承诺:${anchor.promisesExchanged.take(6).join("；")}');
        t2Lines.add('• ${buf.toString()}');
      }
      if (t2Lines.isNotEmpty) {
        contextBuffer.writeln('【T2 NPC 关键关系（纯事实结构锚，永不压缩）】');
        contextBuffer.writeln(t2Lines.join('\n'));
        contextBuffer.writeln('');
      }
      // T3: 世界事件银行（重要性 * 新鲜度 取前 40 条）
      final ts = worldState.time.absoluteDayIndex;
      final t3 = List<WorldEventRecord>.from(memory.worldEvents)
        ..sort((a, b) => b.score(ts).compareTo(a.score(ts)));
      if (t3.isNotEmpty) {
        contextBuffer.writeln('【T3 世界事件银行（按重要性+新鲜度排序）】');
        for (int i = 0; i < t3.length && i < 40; i++) {
          final e = t3[i];
          final cons = e.consequences.isNotEmpty
              ? ' → 后续:${e.consequences.join(";")}'
              : '';
          contextBuffer.writeln(
              '• [${e.importance}]${e.timestamp} ${e.category}｜${e.title}:${e.description}$cons');
        }
        contextBuffer.writeln('');
      }

      // ========== T4 自然语言摘要（有损压缩历史背景，权重最低，严格控量） ==========
      // 重要：T4 是 LLM 压缩的「模糊历史记忆」，可能包含过期/错误细节（如"开局巨怪事件"）
      //      → 模型能力升级后放宽到 600 字注入，但仍保持"不能用于生成当前选项"的强约束
      //      → 跳过阈值从 12 条放宽到 30 条，给模型更多参考
      if (narrativeSummary.isNotEmpty) {
        final structuredCount = t0.length + t1.length;
        if (structuredCount < 30) {
          // 2026-08-23：200→600 字，给长线剧情更多参考
          final trimmedSummary = narrativeSummary.length > 600
              ? '${narrativeSummary.substring(0, 600)}…'
              : narrativeSummary;
          // 强约束：只当"关系和转折"参考，严格禁止基于此生成当前回合选项/场景
          contextBuffer.write('【历史背景（仅供参考，严禁基于此生成当前回合的选项与场景）】\n$trimmedSummary\n\n');
        } else {
          debugPrint('T4 跳过注入：结构化事实 T0(${t0.length})+T1(${t1.length}) ≥ 30，信息充足');
        }
      }

      // 保留旧的 world_state.recent* 注入，作为软备份（与 T3 并存不冲突）
      // 2026-08-23：6→12 条；过滤"好感本周已达上限"这类系统通知刷屏
      final ws = worldState;
      final worldAnchors = <String>[];
      final alreadyAnchors = <String>{}; // 去重
      // 世界重大事件锚点「伪造事件」真校验：
      // - 🏆成就类：必须真正解锁才允许注入（check against player.achievements）
      // - 👤结识类：必须对应 NPC 确实 introduced=true 才允许注入
      // - 否则直接丢弃（AI 之前乱塞"你认识哈利""你获得了什么什么成就"都是伪造事件）
      final introducedSet = npcRegistry.values.where((n) => n.introduced).map((n) => n.name).toSet();

      bool looksFake(String text) {
        final clean = text.replaceAll(RegExp(r'^[^\u4e00-\u9fa5A-Za-z]*'), '');
        // 成就类伪造：含"成就/🏆"，但 achievement 关键词不在已解锁集合
        if (clean.contains('成就') || text.contains('🏆')) {
          final unlocked = player?.achievements ?? const <String>[];
          // 尝试找成就id/名称；若在已解锁集合找不到，算伪造
          if (unlocked.isEmpty) return true; // 宣称解锁但全局没解过任何成就=假
          // 按名称匹配：把 clean 与已解锁成就描述做交集
          final names = achievementCatalog.map((a) => a.id).toSet()..addAll(achievementCatalog.map((a) => a.name));
          final hitAch = names.any((n) => n.isNotEmpty && clean.contains(n));
          // 双重校验：还必须有具体成就 ID 出现在已解锁列表中（避免文案命中但未解锁）
          final hitUnlocked = unlocked.any((id) => clean.contains(id) || clean.contains(achievementCatalog.firstWhere((a) => a.id == id, orElse: () => achievementCatalog.first).name));
          if (!(hitAch && hitUnlocked)) return true;
        }
        // 结识类伪造：含"结识/认识/见面/认识了/👤"但对应NPC没introduced
        if (RegExp(r'(结识|认识了|正式见面|成为朋友|初见了)', caseSensitive: false).hasMatch(clean) || text.contains('👤')) {
          final hitNpc = introducedSet.any((n) => n.isNotEmpty && clean.contains(n));
          if (!hitNpc) return true;
        }
        return false;
      }
      if (ws.recentEvents.isNotEmpty) {
        for (final e in ws.recentEvents.reversed) {
          if (e.contains('好感本周已达上限') || e.contains('周好感度已达上限')) continue;
          if (looksFake(e)) continue; // 过滤掉"结识了/成就"类伪造事件
          final k = e.replaceAll(RegExp(r'^(📊|👤|💬|📅|🏆|🌟|📰)'), '').trim();
          if (!alreadyAnchors.add(k)) continue;
          worldAnchors.add(e);
          if (worldAnchors.length >= 12) break;
        }
      }
      if (ws.recentNarrativeEvents.isNotEmpty) {
        for (final e in ws.recentNarrativeEvents.reversed) {
          if (e.contains('好感本周已达上限') || e.contains('周好感度已达上限')) continue;
          if (looksFake(e)) continue;
          final k = e.replaceAll(RegExp(r'^(📊|👤|💬|📅|🏆|🌟|📰)'), '').trim();
          if (!alreadyAnchors.add(k)) continue;
          worldAnchors.add('剧情锚：$e');
          if (worldAnchors.length >= 16) break;
        }
      }
      if (worldAnchors.isNotEmpty) {
        contextBuffer.writeln('【世界近期重大事件（硬锚，不能丢）】');
        contextBuffer.writeln(worldAnchors.join('\n'));
        contextBuffer.writeln('');
      }

      // 只注入最近 3 回合（而非10），避免历史叙事过多导致 AI 重复输出
      final filteredTurns = <String>[];
      for (int i = recentTurns.length - 1; i >= 0; i--) {
        final entry = recentTurns[i];
        filteredTurns.insert(0, entry);
        if (filteredTurns.length >= 3) break;
      }
      final recentBuffer = filteredTurns.isNotEmpty
          ? filteredTurns.join('\n\n')
          : currentNarrative;
      // 截断到 1600 字（而非4800），只保留末尾用于理解当前处境
      final recent = _truncateNarrativeContext(recentBuffer, 1600);
      // 关键改进：明确标注为"已生成的前情"，禁止 AI 重复或改写
      contextBuffer.write('【前情回顾（已生成内容，严禁重复或改写其中任何段落，仅用于理解当前处境）】\n$recent');

      final context = contextBuffer.toString();
      final statusTag = _buildStatusTag(p);
      final extra = _buildCriticalContext(safeAction);
      final sceneInfo = _buildSceneContext();

      // 事件锚点注入：手写剧情骨架，保证关键节点在正确时间发生
      final anchorLine = pendingAnchorDirective != null
          ? '【剧情节点】本回合请自然融入以下既定剧情骨架（不必生硬转折，可结合玩家行动展开）：\n$pendingAnchorDirective\n\n'
          : '';

      return '''【世界上下文】
  $context

  ${statusTag.isNotEmpty ? '【状态】$statusTag\n' : ''}
  【当前场景】${worldState.timestamp}｜${worldState.currentLocation ?? '未知'}
  $sceneInfo

  $anchorLine${extra.isNotEmpty ? extra + '\n' : ''}【玩家行动】
  $safeAction

  【重要规则】
  - 选项将由独立步骤生成，本回合只需生成叙事和好感变化
  - 确保叙事符合当前地点（${worldState.currentLocation ?? '未知'}）和当前时间（${worldState.timestamp}）

  【写作要求】
  - 叙事:1500-2500字小说正文，融入感官细节、对话、心理、环境描写，分4-8段用空行分隔
  - 叙事正文严禁使用【】标签、序号、大纲结构
  - 剧情要有实际进展和转折，避免无意义的日常描述
  - 严禁重复【前情回顾】中的任何内容！只写本回合新的剧情发展，从玩家行动之后开始续写

  叙事结束后，在末尾输出好感度变化区块（必须严格使用以下格式）：
  【好感度变化】
  NPC名:±X(原因)

  示例：
  【好感度变化】
  金妮: +5(因为帮助了她)
  赫敏: -3(对玩家的言论不满)

  规则：每行一条，只写本回合有实际互动的NPC；无变化时省略整个区块。

  - 不需要生成选项，选项将在下一步单独生成
  ''';
    }

    try {
      final prompt = buildPrompt();
      // 记录本回合实际注入的锚点（推进时间后可能产生新锚点，不能误清）
      final consumedAnchor = pendingAnchorDirective;
      loadingStage = '正在生成剧情...';
      notifyListeners();

      String response;
      try {
        response = (await callDeepSeek(prompt)).content;
      } on AiNonRetryableException {
        rethrow;
      } catch (e) {
        loadingStage = '请求失败，正在重试...';
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 500));
        response = (await callDeepSeek(prompt)).content;
      }

      loadingStage = '正在解析剧情...';
      notifyListeners();

      // 先解析叙事文本（不含选项）
      parseNarrativeOnly(response);

      // 独立生成选项：基于已生成的剧情（与主叙事完全解耦，不再从叙事响应提取）
      // 注意：从 2026-08-23 起「写作要求」明确禁止主叙事 AI 输出选项，
      //       因此即使叙事响应里意外夹带了 ABCD（来自 T4 旧摘要污染），
      //       也绝对不再读入到选项里——否则会出现"海格/巨怪"等过期内容。
      loadingStage = '正在生成选项...';
      notifyListeners();

      final separateChoices = await generateChoicesSeparately(currentNarrative);
      if (separateChoices.isNotEmpty) {
        choices = separateChoices;
      } else {
        // 独立选项生成失败时，只用本地上下文兜底选项生成器（不碰 AI 的响应文本）
        debugPrint('独立选项生成失败，切换到本地上下文兜底选项');
        choices = generateContextualFallbackChoices();
      }

      accumulateForSummary(currentNarrative);
      appendRecentTurn(currentNarrative);
      advanceTimeForAction(action);
      updateNPCsFromAction(action);
      updatePlayerImpactScore(action);
      // 锚点已成功注入本回合剧情，清除待注入状态（仅当未被新锚点替换时）
      if (consumedAnchor != null && pendingAnchorDirective == consumedAnchor) {
        pendingAnchorDirective = null;
      }

      // 定期摘要：模型能力升级后回调到每15回合，缓冲阈值从3200→6000字
      // 配合 _maxPendingSummaryChars=8000，每次摘要覆盖更长时间线，长线逻辑性更强
      if ((turnCount % 15 == 0 || pendingSummary.length > 6000) && pendingSummary.isNotEmpty) {
        unawaited(Future.microtask(() async {
          try {
            await _summarizeNarrative();
          } catch (e) {
            debugPrint('摘要生成失败(不影响游戏): $e');
          }
        }));
      }

      loadingStage = '';
      isLoading = false;
      notifyListeners();
      autoSave();
    } catch (e) {
      // AI 全部提供商不可用时的本地兜底：给出过渡剧情与选项，保证游戏不卡死
      debugPrint('❌ 剧情生成失败，启用本地兜底叙事: $e');
      currentNarrative = generateFallbackNarrative();
      choices = generateContextualFallbackChoices();
      appendRecentTurn(currentNarrative);
      notifications.add('⚠️ AI 服务暂时不可用，已切换为本地过渡剧情，稍后可重试行动');
      loadingStage = '';
      isLoading = false;
      notifyListeners();
      autoSave();
      unawaited(CrashLogger.instance.record(
        e,
        StackTrace.current,
        screen: 'processChoice',
        extra: 'action=$action, turn=$turnCount',
      ));
    }
  }

  /// 关闭指令结果面板，恢复显示当前回合剧情（不消耗回合、不调用 AI）

  List<GameChoice> generateContextualFallbackChoices() {
    final currentLoc = worldState.currentLocation ?? '';
    final narrativeLower = currentNarrative.toLowerCase();
    final playerAction = lastPlayerAction;

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

  void appendRecentTurn(String narrative) {
    final trimmed = narrative.trim();
    if (trimmed.isEmpty) return;
    recentTurns.add(trimmed);
    while (recentTurns.length > GameProviderBase.maxRecentTurns) {
      recentTurns.removeAt(0);
    }
  }

  // ==================== 剧情摘要机制：模型升级后放宽规模 ====================

  /// 待摘要缓冲上限：模型能力升级后 4000→8000 字，一次摘要可以压缩更多回合，减少摘要 AI 调用频次
  static const int _maxPendingSummaryChars = 8000;

  void accumulateForSummary(String newNarrative) {
    pendingSummary += '$newNarrative\n';
    if (pendingSummary.length > _maxPendingSummaryChars) {
      // 保留最近的剧情（尾部），丢弃最早的部分
      final cut = pendingSummary.length - _maxPendingSummaryChars;
      pendingSummary = '…（更早剧情略）\n${pendingSummary.substring(cut)}';
    }
  }

  Future<void> _summarizeNarrative() async {
    if (pendingSummary.length < 50) {
      pendingSummary = '';
      return;
    }

    // 摘要长度随游戏进度逐步放宽
    // 2026-08-23：模型能力升级，整体翻倍放开
    final limit = turnCount <= 40
        ? 800
        : (turnCount <= 100 ? 1500 : 2400);
    final relationSnapshot = buildRelationshipSnapshot();

    // 关键改进：明确要求 AI 只保留"人物关系"和"重要转折"，不保留具体场景描述
    final prompt = '''请将以下剧情内容压缩成摘要。重要规则：
  1. 只保留【人物关系变化】和【重要剧情转折】
  2. 淘汰具体场景描述（如"在车站"、"在教室"、"列车走廊"等地点信息），这些会严重干扰后续剧情生成
  3. 淘汰具体行动描述（如"检票上车"、"拿出魔杖"等），除非是关键转折点
  4. 保留 NPC 好感度变化（如"赫敏:友好+10"）、学院分配、重要事件等
  5. 保留关键伏笔、NPC承诺、秘密、未完成任务、冲突起源、长期目标（这些是长线剧情的锚，必须单独归纳）
  6. 用简洁的第三人称
  7. 绝对禁止保留一次性冲突/怪物事件（如"巨怪事件""某个小决斗"）的具体场景和过程，仅保留对人物关系造成的长期影响（例如："与罗恩因共同抗敌建立信任"而非"在厕所击败巨怪"）
  8. 严格遵守【精简剧情摘要】不超过 $limit 字，超过部分会被直接截断，超出规则会导致后续剧情冲突

  【前情摘要】
  ${narrativeSummary.isNotEmpty ? narrativeSummary : '（开局）'}

  【新剧情】
  $pendingSummary

  【当前关系状态】（以此为准校准）
  ${relationSnapshot.isNotEmpty ? relationSnapshot : '暂无'}

  请输出：
  1. 精简剧情摘要（不超过$limit字，聚焦关系和转折，不要保留具体场景）
  2. 末尾单独一行【关系】列出当前重要NPC的关系状态（如：赫敏:友好/72；马尔福:敌对/-30）
  3. 如果有伏笔/承诺/秘密/未完成任务，再单独一行【伏笔】列出（例如：斯内普答应给主角保密身份；主角欠邓布利多一次夜探；小天狼星留了一把钥匙）''';

    try {
      final result = await callDeepSeek(
        prompt,
        scene: AiScene.summary,
      );

      // 硬限制摘要保存长度——如果 AI 不肯遵守字数限制，直接强截断前 limit×1.2 字
      // 防止出现 1500+ 字摘要，造成下回合 prompt 暴涨 5000 tokens
      var rawSummary = result.content.trim();
      final hardLimit = (limit * 1.2).toInt();
      if (rawSummary.length > hardLimit) {
        rawSummary = '${rawSummary.substring(0, hardLimit)}…(已截短)';
      }
      narrativeSummary = rawSummary;
      pendingSummary = '';
      debugPrint('✅ 剧情摘要已更新 (${narrativeSummary.length}字，上限=$hardLimit)');
    } catch (e) {
      debugPrint('❌ 摘要生成失败: $e');
    }
  }

  /// 生成当前重要NPC关系快照（取好感绝对值最高的前5位）

  String buildRelationshipSnapshot() {
    final npcs = npcRegistry.values.where((n) => n.affection != 0).toList()
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
    final p = player;
    if (p == null) return '';
    final a = action.toLowerCase();
    final parts = <String>[];

    // 战斗/冲突 → 注入关键属性、魔咒、HP
    if (a.contains(RegExp(r'(战斗|决斗|攻击|防御|施展咒语|施法|黑魔法|施咒|念咒|反击)'))) {
      final combatAttrs = p.attributes.entries
          .where((e) => e.value != 0)
          .take(3)
          .map((e) => '${attrLabel(e.key)}:${e.value}')
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
          .where((e) => const {'智慧', '魔力', '勤奋'}.contains(attrLabel(e.key)))
          .where((e) => e.value != 0)
          .map((e) => '${attrLabel(e.key)}:${e.value}')
          .join(' ');
      if (study.isNotEmpty) parts.add('【学业】$study');
    }

    // 社交/对话：若行动中提到具体NPC名则精准注入其好感，否则按关键词注入
    final mentioned = npcRegistry.values
        .where((n) => action.contains(n.name))
        .toList();
    if (mentioned.isNotEmpty) {
      final affs = mentioned.take(2)
          .map((n) => '${n.name}:好感${n.affection}(${n.affectionStage})')
          .join('；');
      parts.add('【关系】$affs');
    } else if (a.contains(RegExp(r'(约会|表白|心动|拥抱|接吻|单独见面|私聊)'))) {
      final affs = formatAffections(maxEntries: 2);
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

    // 防御：worldState 有默认值（非空）但为防止未来改类型，统一局部变量引用；
    // player 为可空类型，必须判空
    final ws = worldState;
    final p = player;

    // worldState 始终非空，此处无需 null 判断（避免 analyzer unnecessary_null_comparison）
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
    final location = worldState.currentLocation;
    if (location == null || location.isEmpty) return [];
    return npcRegistry.values.where((npc) {
      return npc.currentLocation.toLowerCase().contains(location.toLowerCase());
    }).toList();
  }

  Future<void> generateMoreSuggestions() async {
    if (player == null || isLoading) return;

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final suggestions = _generateLocalSuggestions();
      if (suggestions.isEmpty) {
        error = '暂时想不出更多建议，请继续';
      } else {
        choices = suggestions;
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  List<GameChoice> _generateLocalSuggestions() {
    final location = worldState.currentLocation ?? '霍格沃茨';
    final house = player!.house ?? '';
    final personality = player!.personalityTraits;
    final narrativeLower = currentNarrative.toLowerCase();

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
    deduped.shuffle(random);

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
    if (player == null) {
      return {'house': 'Gryffindor', 'narrative': ''};
    }

    isLoading = true;
    notifyListeners();

    try {
      final house = computeHouseLocal();
      final narrative = generateSortingNarrative(house);
      player!.house = house;
      unlockAchievement('sorted');

      isLoading = false;
      notifyListeners();
      return {'house': house, 'narrative': narrative};
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return {'house': 'Gryffindor', 'narrative': ''};
    }
  }
}
