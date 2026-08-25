import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart';
import '../models/npc.dart';
import '../models/game_systems.dart';
import '../services/deepseek_service.dart';
import '../models/player.dart';
import '../utils/prompt_sanitizer.dart';
import '../models/long_term_memory.dart';
import '../services/ai_router.dart';
import '../utils/crash_logger.dart';
import '../providers/game_provider_base.dart';
import '../prompts/narrative_prompts.dart';
import '../prompts/summary_prompts.dart';

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
    lastScannedNarrativeHash = null;
    lastPlayerAction = safeAction;
    loadingStage = '正在构建请求...';
    notifyListeners();

    String _formatImpact(double score) {
        if (score >= 1.0) return '极高影响力（深度改变历史走向）';
        if (score >= 0.5) return '高影响力（知名人物/学院领袖候选）';
        if (score >= 0.2) return '中等影响力（小有名气）';
        if (score >= 0.05) return '低影响力（普通学生）';
        return '无影响力（边缘人物）';
      }

      String buildPrompt() {
        final p = player!;

        final contextBuffer = StringBuffer();

        // 优先使用 Player 字段；若为 null，resolveMagicAptitude 会从 T0 核心事实回填
        // （并写回 Player，避免后续每回合都解析）
        final effectiveAptitude = resolveMagicAptitude(p);
        final aptitudeForPrompt = effectiveAptitude.isEmpty ? '普通' : effectiveAptitude;

        final profileLine = '【档案】${p.name}·${p.house ?? '未分院'}·${p.grade}年·天赋$aptitudeForPrompt·精神${p.spirit}·精力${p.energy}';
        final impactLine = '影响力：${_formatImpact(worldState.playerImpactScore)}';
        contextBuffer.writeln('$profileLine｜$impactLine');
        contextBuffer.writeln('');

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
      // ========== 短期断言：上回合生效的物理/姿态/状态事实（防止 AI 失忆打脸） ==========
      final assertionsBlock = buildAssertionsPromptBlock();
      if (assertionsBlock.isNotEmpty) {
        contextBuffer.write(assertionsBlock);
      }
      // ========== T1 超期未推进的"别忘了这些重要伏笔"提醒 ==========
      final loopsHint = _buildOpenLoopsStagnationHint();
      if (loopsHint.isNotEmpty) {
        contextBuffer.write(loopsHint);
      }
      // T2: NPC 关键关系（按 |好感| 取前 24 个 NPC 的结构化关系锚，仅展示已登场NPC）
      final topNpcs = npcRegistry.values
          .where((npc) => npc.introduced == true)
          .toList()
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
        for (final ev in ws.recentEvents.reversed) {
          final e = ev.text;
          if (e.contains('好感本周已达上限') || e.contains('周好感度已达上限')) continue;
          if (looksFake(e)) continue;
          final k = e.replaceAll(RegExp(r'^(📊|👤|💬|📅|🏆|🌟|📰)'), '').trim();
          if (!alreadyAnchors.add(k)) continue;
          worldAnchors.add(e);
          if (worldAnchors.length >= 12) break;
        }
      }
      if (ws.recentNarrativeEvents.isNotEmpty) {
        for (final ev in ws.recentNarrativeEvents.reversed) {
          final e = ev.text;
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

      // 只注入最近 2 回合（而非3），避免历史叙事过多导致 AI 被旧场景文本"锚定"而原地打转
      final filteredTurns = <String>[];
      for (int i = recentTurns.length - 1; i >= 0; i--) {
        final entry = recentTurns[i];
        filteredTurns.insert(0, entry);
        if (filteredTurns.length >= 2) break;
      }
      final recentBuffer = filteredTurns.isNotEmpty
          ? filteredTurns.join('\n\n')
          : currentNarrative;
      // 截断到 800 字（而非1600），只保留末尾用于理解当前处境
      // 过多的前情文本会让AI认为场景还应该在前一个地点继续
      final recent = _truncateNarrativeContext(recentBuffer, 800);
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

      // 场景停滞强制推进：玩家在同一地点停留过久时，注入强制场景转换指令
      // 这是「最后一道防线」——prompt 规则 + 上下文压缩都失效时的硬性兜底
      // （已加入三级豁免：地点白名单、叙事钩子未解决、分级阈值，避免打断重要剧情）
      String stagnationLine = '';
      final curLoc = worldState.currentLocation ?? '当前地点';
      final threshold = stagnationThresholdFor(curLoc);
      final hasHook = narrativeHasUnresolvedHook(currentNarrative);
      if (turnsAtSameLocation >= threshold && !hasHook) {
        final stuckTurns = turnsAtSameLocation;
        final isExempt = isLocationExemptFromStagnation(curLoc);
        final extraHint = isExempt
            ? '（注：你所在的「$curLoc」是重要剧情场景，通常允许$threshold回合停留；现已达到上限，必须在下一阶段自然转换。）'
            : '';
        stagnationLine = '【⚠️强制推进指令】玩家已在「$curLoc」停留 $stuckTurns 回合（该场景允许阈值=$threshold），剧情已停滞！'
            '本回合必须发生场景转换——例如：有人敲门通知该出发、时间到了必须动身前往下一站、'
            '收到猫头鹰信件催促、窗外发生引人注意的事件、被召唤去某处等。$extraHint'
            '严禁继续在「$curLoc」原地打转、反复施法、反复探索同一现象。'
            '本回合结尾必须让玩家处于「正在前往/即将到达下一场景」的状态。\n\n';
      }

      return '''【世界上下文】
  $context

  ${statusTag.isNotEmpty ? '【状态】$statusTag\n' : ''}
  【当前场景】${worldState.timestamp}｜${worldState.currentLocation ?? '未知'}
  $sceneInfo

  $stagnationLine$anchorLine${extra.isNotEmpty ? extra + '\n' : ''}【玩家行动】
  $safeAction

$kNarrativeWritingRules
  ''';
    }

    try {
      // 开局硬骨架守卫（仅前12回合 & 家中开局 & 还没入校才生效），把还没出门的玩家硬推出去
      _checkOpeningRailroad();

      // 场景停滞检测：回合开始时比较地点，若未变则累加停滞计数
      // buildPrompt 会读取 turnsAtSameLocation 决定是否注入强制推进指令
      _updateLocationTracking();

      String buildPromptInternal() => buildPrompt();
      String prompt = buildPromptInternal();
      // 记录本回合实际注入的锚点（推进时间后可能产生新锚点，不能误清）
      String? consumedAnchor = pendingAnchorDirective;
      loadingStage = '正在生成剧情...';
      notifyListeners();

      String response;
      int retriesLeft = 1; // 允许 critical 级违规后自动重试 1 次（太多次会慢）
      List<Map<String, dynamic>> violations = const [];
      List<Map<String, dynamic>> forbiddenHits = const [];
      bool needsRetry;
      do {
        needsRetry = false;
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

        // --- P2-1 禁止词检测（现代物品/跨IP/网络梗）---
        forbiddenHits = detectForbiddenWords(currentNarrative);
        for (final h in forbiddenHits) {
          recordConsistencyViolation({
            'severity': h['severity'],
            'rule': 'R6_forbidden_${h['category']}',
            'message': '违和词命中(${h['category']}): ${h['word']} — 霍格沃茨世界观不应出现现代物品/跨IP角色/网络梗。',
            'evidence': h['word'],
            'at': DateTime.now().toIso8601String(),
          });
        }
        final criticalForbidden = forbiddenHits.where((h) => h['severity'] == 'critical').toList();

        // --- P0-1 一致性看门狗：6 大类校验 ---
        violations = validateNarrativeConsistency(currentNarrative);
        for (final v in violations) {
          recordConsistencyViolation(v);
        }
        final criticalViolations = violations.where((v) => v['severity'] == 'critical').toList();

        // --- P1-2 好感变化校验（放到 _parseAffectionChanges 内部做拦截丢弃）---
        // 这里不打回整段，只记录 warn 级。

        // 判定：critical 违规 or critical 禁止词命中 → 重试一次
        if (retriesLeft > 0 && (criticalViolations.isNotEmpty || criticalForbidden.isNotEmpty)) {
          final msgs = <String>[
            ...criticalViolations.map((v) => '${v['rule']}: ${v['message']}'),
            ...criticalForbidden.map((h) => '违和词(${h['category']}): ${h['word']}'),
          ];
          debugPrint('⚠️ 叙事一致性 critical 违规，准备重试 ${msgs.length} 条：${msgs.take(3).join(" | ")}');
          // 给新 prompt 加一段"修正要求"，明确告诉 AI 错在哪
          final correction = StringBuffer();
          correction.writeln('【⚠️ 上一次生成被驳回，必须严格修正以下问题再重写】');
          for (int i = 0; i < msgs.length && i < 5; i++) {
            correction.writeln('${i + 1}. ${msgs[i]}');
          }
          correction.writeln('请按以上要求重写一整段叙事。保持【玩家行动】不变，但剧情走向必须完全符合规则。\n');
          prompt = correction.toString() + prompt;
          needsRetry = true;
          retriesLeft -= 1;
          loadingStage = '剧情${criticalViolations.length + criticalForbidden.length}处违规，重试中...';
          notifyListeners();
          continue;
        }

        // warn 级违规不必打回，只是记录到 consistencyViolations 并在下回合注入软提醒。
        // warn 也加到通知里，方便玩家/开发者看到
        final warnCount = violations.where((v) => v['severity'] == 'warn').length +
            forbiddenHits.where((h) => h['severity'] == 'warn').length;
        if (warnCount > 0) {
          notifications.add('📝 剧情逻辑警告：本回合有 $warnCount 处轻微违和，已记录。');
        }
        break; // 走到这里说明不重试
      } while (needsRetry);

      // 从叙事文本中提取新地点并同步 currentLocation
      // 这是「场景推进」的闭环：AI 写了换场景 → 状态同步 → 停滞计数清零
      // 否则 currentLocation 永远停在初始值，AI 会以为玩家还在原地
      _syncLocationFromNarrative(currentNarrative);

      // --- P0-2 短期断言：从本回合叙事末尾提取生效状态，下回合 Prompt 必注入 ---
      final newAssertions = extractShortAssertions(currentNarrative);
      rotateTurnAssertions(newAssertions);

      // 独立生成选项：基于已生成的剧情（与主叙事完全解耦，不再从叙事响应提取）
      // 注意：从 2026-08-23 起「写作要求」明确禁止主叙事 AI 输出选项，
      //       因此即使叙事响应里意外夹带了 ABCD（来自 T4 旧摘要污染），
      //       也绝对不再读入到选项里——否则会出现"海格/巨怪"等过期内容。
      loadingStage = '正在生成选项...';
      notifyListeners();

      // ---- 选项端也跑一次禁止词 & OOC软提示（轻微的OOC不会打回，改 prompt 软提醒）----
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

    final prompt = buildSummaryPrompt(
      limit: limit,
      previousSummary: narrativeSummary,
      newChunk: pendingSummary,
      relSnapshot: relationSnapshot,
    );

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
    final npcs = npcRegistry.values
        .where((n) => n.introduced && n.affection != 0)
        .toList()
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
      final npcNames = npcsHere
          .where((n) => n.introduced)
          .map((n) {
        final status = n.isAlive ? n.affection.toString() : '';
        return '${n.name}$status';
      }).join('、');
      if (npcNames.isNotEmpty) {
        parts.add('【在场】$npcNames');
      }
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
      return npc.introduced && npc.currentLocation.toLowerCase().contains(location.toLowerCase());
    }).toList();
  }

  // ==================== 场景停滞检测与地点同步 ====================

  /// 【场景豁免·地点白名单】：
  /// 这些场景本来就是"要多回合演剧情"的（上课/分院/购魔杖/图书馆查资料等），
  /// 如果跟开局家里一样用 2 回合的严格阈值，反而会把重要剧情硬打断。
  /// 匹配规则：currentLocation 的主名称包含下面任一关键词即豁免。
  static const List<String> _kStagnationExemptLocations = [
    '大礼堂',     // 分院、宴会、重要集会 → 可能要3-4回合
    '教室',       // 上课、小测验、课堂互动 → 可能3-4回合
    '图书馆',     // 查资料、发现线索、遇NPC → 可能3回合
    '对角巷',     // 采购魔杖/袍子/书、逛店铺、遇NPC → 可能4-5回合
    '霍格莫德村', // 周末逛街、三把扫帚、蜂蜜公爵 → 多回合正常
    '公共休息室', // 社交、练咒、写作业 → 停留正常
    '禁林',       // 探索、遭遇神奇生物、任务线 → 多回合正常
    '医疗翼',     // 治伤、养病、剧情 → 多回合正常
    '霍格沃茨·场地', // 魁地奇训练/比赛、草坪互动 → 多回合正常
  ];

  /// 判断当前地点是否为"重要剧情场景（豁免强制推进）"。
  /// （跨 Mixin 公开方法：GameProviderBase 声明了 abstract，mixin_response 需要调用）
  bool isLocationExemptFromStagnation(String location) {
    if (location.isEmpty) return false;
    return _kStagnationExemptLocations.any(
      (keyword) => location.contains(keyword),
    );
  }

  /// 【停滞触发阈值·分级】：
  /// - 起始家中（卧室/庄园/家里等）：2 回合 → 严，防止开局墨迹不出发
  /// - 豁免地点（大礼堂/教室/对角巷等）：6 回合 → 非常宽松，确保有足够回合演完重要剧情
  /// - 其它普通地点（车站/走廊/特快等过路型）：4 回合 → 中等，防止在过路费卡
  /// （跨 Mixin 公开方法：GameProviderBase 声明了 abstract，mixin_response 需要调用）
  int stagnationThresholdFor(String location) {
    if (location.isEmpty) return 2;
    // 开局的"家中·卧室"（含别名）严格按 2 回合
    const atHomeKeywords = ['家中', '卧室', '住宅', '庄园', '别墅', '家里'];
    if (atHomeKeywords.any((k) => location.contains(k))) return 2;
    // 豁免剧情地点放宽到 6 回合
    if (isLocationExemptFromStagnation(location)) return 6;
    // 其它：4 回合
    return 4;
  }

  /// 【停滞豁免·叙事钩子检测】：
  /// 如果上一回合叙事**末尾**（最后200字）明确存在"冲突未解决/对话未结束/悬念未落地/正在发生中"
  /// 的剧情钩子，说明此刻强制推进会毁体验，本回合跳过强制推进，让剧情自然收束。
  /// 例：分院帽接触头发突然停住、斯内普刚点名叫你、对手举着魔杖等你出招、门被敲响正要去开……
  /// （跨 Mixin 公开方法：GameProviderBase 声明了 abstract，mixin_response 需要调用）
  bool narrativeHasUnresolvedHook(String narrative) {
    if (narrative.isEmpty) return false;
    final tail = narrative.length > 200
        ? narrative.substring(narrative.length - 200)
        : narrative;
    // 匹配：1) 省略号/破折号结尾的悬念；2) "刚/正要/突然/正在/即将/尚未/还没/没等"这类未完成动作词；
    //       3) 点名/提问/对话未闭合（"看着你等你回答""点名叫你""注视着你""等你开口""等你回应"）；
    //       4) 决斗/对峙正酣的关键词（"举起魔杖""瞄准""对峙""剑拔弩张""一触即发""准备迎战"）；
    //       5) 分院/考试/仪式正进行中。
    final re = RegExp(
      r'(\.\.\.|……|——|—\s*$)'                       // 悬念标点结尾
      r'|(刚|正要|正准备|突然|就在这时|正在|即将|尚未|还没|没等|未等)', // 未完成动作
      r'|(看着你.*(回答|回应|开口)|等你(回答|回应|开口|出招)|点名叫|点了.*的名|注视着你|等你说话)', // 对话/点名待回应
      r'|(举起.*魔杖|瞄准|对峙|剑拔弩张|一触即发|准备迎战|严阵以待|蓄势待发)', // 战斗/对峙
      r'|(分院帽.*(碰到|落下|停住|思考)|(考试|测验|仪式|宴会).(正在|进行中|刚刚开始|开始了))', // 正进行中的关键事件
      r'|(门.*敲响|敲门声|有人敲门|脚步声.*临近|声音从.*传来)', // 即将发生事件的铺垫
      , caseSensitive: false,
    );
    return re.hasMatch(tail);
  }

  /// 回合开始时更新地点停滞计数。
  /// 若 currentLocation 与上一回合相同，则 turnsAtSameLocation++；
  /// 若已变化（如玩家手动 travelTo），则清零并记录新地点。
  void _updateLocationTracking() {
    final cur = worldState.currentLocation ?? '';
    if (lastTrackedLocation == null) {
      // 首次追踪：记录但不计停滞
      lastTrackedLocation = cur;
      turnsAtSameLocation = 0;
      return;
    }
    if (cur == lastTrackedLocation) {
      turnsAtSameLocation++;
    } else {
      // 地点已变（可能是 travelTo 或上一回合叙事同步触发）
      lastTrackedLocation = cur;
      turnsAtSameLocation = 0;
    }
  }

  /// HP 世界已知地点关键词表（按开局推进路线排序）。
  /// 叙事中出现这些关键词即认为玩家已到达该地点。
  /// 使用 「主要关键词 + 别名列表」结构，匹配任一别名即归入主地点。
  static const List<(String, List<String>)> _knownLocations = [
    ('家中·卧室', ['家中', '卧室', '自己的房间']),
    ('国王十字车站', ['国王十字', '国王十字车站', '九又四分之三站台', '9¾站台', '站台']),
    ('霍格沃茨特快列车', ['霍格沃茨特快', '特快列车', '火车包厢', '车厢']),
    ('霍格沃茨大礼堂', ['大礼堂', '分院仪式', '分院帽']),
    ('霍格沃茨·公共休息室', ['公共休息室', '休息室']),
    ('霍格沃茨·教室', ['教室', '课堂', '阶梯教室']),
    ('霍格沃茨·图书馆', ['图书馆', '禁书区']),
    ('霍格沃茨·医疗翼', ['医疗翼', '医院翼']),
    ('霍格沃茨·走廊', ['走廊', '楼梯', '移动楼梯']),
    ('霍格沃茨·场地', ['草坪', '魁地奇球场', '魁地奇看台', '黑湖']),
    ('禁林', ['禁林', '黑暗森林']),
    ('对角巷', ['对角巷', '奥利凡德', '摩金夫人']),
    ('古灵阁', ['古灵阁', '妖精银行']),
    ('霍格莫德村', ['霍格莫德', '三把扫帚', '蜂蜜公爵']),
  ];

  /// 从叙事文本中提取玩家当前所在地点，并同步到 worldState.currentLocation。
  /// 检查两处：1) 开头【地点】标签；2) 叙事末尾 200 字（确保玩家真的抵达）。
  /// 别名匹配优化：同一主地点的不同细分房间（卧室/花园/书房）统一归到主地点，不造成假阳性转换。
  /// 同步成功后重置停滞计数，让强制推进指令不再触发。
  void _syncLocationFromNarrative(String narrative) {
    if (narrative.isEmpty) return;
    final cur = worldState.currentLocation ?? '';

    // ---- 第1步：解析开头的【地点】标签（AI 标准输出格式，最准确）----
    String? detected;
    final locationTagMatch = RegExp(
      r'【地点】\s*([^\n]+)',
      dotAll: false,
    ).firstMatch(narrative);
    if (locationTagMatch != null && locationTagMatch.group(1) != null) {
      final tag = locationTagMatch.group(1)!.trim();
      // 把标签与已知地点别名做匹配
      for (final (mainName, aliases) in _knownLocations) {
        for (final alias in aliases) {
          if (tag.contains(alias)) {
            detected = mainName;
            break;
          }
        }
        if (detected != null) break;
      }
      // 如果标签没匹配到已知别名，但标签里提到了具体位置，
      // 检查是否属于"家中"大类（卧室/花园/书房/密室/起居室 都算家中）
      if (detected == null) {
        if (RegExp(r'(家中|家里|住宅|庄园|别墅|卧室|书房|花园|密室|走廊|客厅|门厅)', caseSensitive: false).hasMatch(tag)) {
          detected = '家中·卧室';
        }
      }
    }

    // ---- 第2步：再检查叙事末尾 200 字的「抵达性」关键词（以防开头标签写错）----
    // 只认 "抵达/到达/走进/来到/出现在/登上/进入 + 地点" 这类明确到达的语境，
    // 不认 "想到明天去对角巷" 这种未来的提及
    final tail = narrative.length > 200
        ? narrative.substring(narrative.length - 200)
        : narrative;
    final arrivalRe = RegExp(
      r'(抵达|到达|走进|走入|来到|出现在|登上|进入|下车|到站|赶到|踏入|推开.*门.*(发现|看见|来到))',
    );
    if (arrivalRe.hasMatch(tail)) {
      int lastPos = -1;
      for (final (mainName, aliases) in _knownLocations) {
        for (final alias in aliases) {
          int pos = tail.lastIndexOf(alias);
          if (pos > lastPos) {
            lastPos = pos;
            detected = mainName;
          }
        }
      }
    }

    // ---- 第3步：家中细分场景（卧室/书房/花园/密室）都统一归为「家中·卧室」----
    // 避免玩家从卧室走到书房就被判定为"换了地点"，停滞计数清零
    // 导致强制推进不触发
    const atHomeAliases = ['家中', '家里', '住宅', '庄园', '别墅', '卧室', '书房', '花园', '密室', '客厅', '门厅', '走廊'];
    if (detected == null) {
      // 如果【地点】标签和末尾都没识别到，但开头标签里是家中的某个房间，归到家中
      if (locationTagMatch != null) {
        final tag = locationTagMatch.group(1)!.trim();
        if (atHomeAliases.any((a) => tag.contains(a))) {
          detected = '家中·卧室';
        }
      }
    }

    if (detected == null) return; // 末尾没提到任何已知地点，不改

    // 若检测到的地点与当前不同，则更新并清零停滞计数
    if (detected != cur) {
      worldState.currentLocation = detected;
      lastTrackedLocation = detected;
      turnsAtSameLocation = 0;
      debugPrint('📍 地点同步: $cur → $detected (停滞计数已清零)');
    }
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

  // ==================== 短期断言系统（Short Assertions）====================

  /// 从本回合叙事正文提取 3~5 条"当前生效中"的状态断言（纯规则关键词版，稳定）。
  /// 存入 worldState.lastTurnAssertions，下回合 prompt 强制注入防止 AI 失忆打脸。
  /// 断言范围：物理状态（门锁/被封）、持有物、位置/姿态、受伤/魔法状态、正发生的关键动作。
  List<String> extractShortAssertions(String narrative) {
    if (narrative.isEmpty) return const [];
    // 只扫末尾 500 字，避免开头过期状态被提回来
    final tail = narrative.length > 500
        ? narrative.substring(narrative.length - 500)
        : narrative;
    final seen = <String>{};
    final result = <String>[];

    void addAssertion(String text) {
      if (text.length < 6) return;
      final key = text.replaceAll(RegExp(r'\s+'), '');
      if (seen.add(key) && result.length < 5) {
        result.add('• $text');
      }
    }

    // ---- 1) 物理封锁/屏障类 ----
    final lockRe = RegExp(
      r'((门窗|大门|房门|窗户|门|窗|密室入口|走廊)[^，。！？]{0,12}(被|已|已经|用.*|以.*)(锁死|封死|封上|封住|加固|上锁|挡死|堵死|施了锁门咒|施展了锁门咒))',
    );
    for (final m in lockRe.allMatches(tail)) {
      addAssertion('${m.group(1)}（玩家行动必须先解锁/破开才能直接通过）');
    }
    // 反过来："锁/封被打开/解除/破坏/破开"要覆盖前面的断言
    final unlockRe = RegExp(
      r'((锁|封|屏障|封印|加固)[^，。！？]{0,12}(被|已|已经|被你)(打开|解开|破开|破坏|解除|击碎|敲碎|摧毁))',
    );
    for (final m in unlockRe.allMatches(tail)) {
      addAssertion('${m.group(1)}（此前的封锁/屏障状态已失效）');
    }

    // ---- 2) 持有/姿态类：手里拿着 XX，魔杖被缴，你躲在 XX ----
    final holdRe = RegExp(
      r'(手里(紧紧)?(攥着|握着|拿着|捏着|握着|举着|提着)[^，。！？]{0,10})',
    );
    for (final m in holdRe.allMatches(tail)) {
      addAssertion('${m.group(1)}');
    }
    final disarmRe = RegExp(
      r'((你的)?魔杖[^，。！？]{0,8}(被击飞|被缴走|脱手|不在手中|丢到了一边|掉在地上))',
    );
    for (final m in disarmRe.allMatches(tail)) {
      addAssertion('${m.group(1)}（本回合若无"捡/拾/召唤"动作，不能直接写魔杖重新回到手中）');
    }
    final hideRe = RegExp(
      r'(你(正)?(躲|藏|蹲|蜷缩)[^，。！？]{0,12}(在|到|进)[^，。！？]{0,14})',
    );
    for (final m in hideRe.allMatches(tail)) {
      addAssertion('${m.group(1)}（若无"走出来/离开"动作，不能直接出现在别的房间）');
    }

    // ---- 3) 受伤/状态类：XX 部位受伤，中了 XX 毒/诅咒，精疲力竭 ----
    final injuryRe = RegExp(
      r'((你的|你)(手臂|腿|肩膀|头|胸口|腹部|背部)[^，。！？]{0,12}(被划伤|被擦伤|出血|剧痛|麻木|骨折|瘀青|中了|中毒|被诅咒|被击中|受伤))',
    );
    for (final m in injuryRe.allMatches(tail)) {
      addAssertion('${m.group(1)}（本回合动作描写要考虑伤势限制）');
    }

    // ---- 4) 关键物件/仪式生效中：分院帽正扣在头上，分院帽在思考 ----
    final hatRe = RegExp(
      r'((分院帽)[^，。！？]{0,10}(扣在|落在|戴在|碰到|触到|停在)[^，。！？]{0,10}|'
      r'(分院帽)[^，。！？]{0,10}(正在思考|在犹豫|沉吟|没说话|没出声))',
    );
    for (final m in hatRe.allMatches(tail)) {
      addAssertion('${m.group(0)}（分院进行中，玩家本回合不应离开大礼堂）');
    }

    // ---- 5) 事件未落地：敲门声刚响起、信刚送到、点名刚叫你 ----
    final knockRe = RegExp(
      r'((敲门声|门[^，。！？]{0,4}被.*敲|有人敲门)[^，。！？]{0,10}(响起|传来|刚落下|刚响))',
    );
    for (final m in knockRe.allMatches(tail)) {
      addAssertion('${m.group(1)}（门外有人，尚未开门。下一动作先回应敲门更自然）');
    }
    final calledRe = RegExp(
      r'((教授|级长|老师|NPC|同学)[^，。！？]{0,6}(点名叫|点了你的名|叫你的名字|喊你|注视着你等你回答))',
    );
    for (final m in calledRe.allMatches(tail)) {
      addAssertion('${m.group(1)}（被点名/提问，优先回应再做别的动作）');
    }

    return result;
  }

  /// 每回合末把断言"滚动一代"：上上回合丢弃，上回合→上次，新提取→本回合。
  void rotateTurnAssertions(List<String> newAssertions) {
    worldState.previousTurnAssertions.clear();
    worldState.previousTurnAssertions.addAll(worldState.lastTurnAssertions);
    worldState.lastTurnAssertions.clear();
    worldState.lastTurnAssertions.addAll(newAssertions);
  }

  /// 组装要注入给叙事/选项 AI 的断言 Prompt 块（统一格式，避免两端不一致）
  String buildAssertionsPromptBlock() {
    final last = worldState.lastTurnAssertions;
    final prev = worldState.previousTurnAssertions;
    if (last.isEmpty && prev.isEmpty) return '';
    final buf = StringBuffer();
    if (last.isNotEmpty) {
      buf.writeln('【上回合生效状态·严禁直接打脸】');
      buf.writeln('以下是从上一回合剧情末尾提取的、此时仍应有效的物理/姿态/状态事实。'
          '除非本回合玩家行动里明确写了"解锁/破开/捡起/走出来"等过渡动作，严禁直接跳到相反状态。');
      buf.writeln(last.join('\n'));
      buf.writeln('');
    }
    if (prev.isNotEmpty) {
      buf.writeln('【上上回合状态·参考】');
      buf.writeln('这些状态已过了两回合，可能已经变化，作为参考；若与上回合状态矛盾，以上回合为准。');
      buf.writeln(prev.join('\n'));
      buf.writeln('');
    }
    return buf.toString();
  }

  // ==================== P0-1 一致性看门狗（Validate Narrative Consistency）====================

  /// 对 AI 刚吐出来的叙事做 6 大类硬性校验，命中严重违规时要求重试。
  /// 返回：违规列表（每个违规 {severity: critical/warn, rule: id, message: str, evidence: str}）。
  /// severity=critical → 本次响应当作废，触发重试一次；severity=warn → 记录但不打回，下一回合 prompt 软提醒。
  List<Map<String, dynamic>> validateNarrativeConsistency(String narrative) {
    if (narrative.isEmpty) return const [];
    final p = player;
    final ws = worldState;
    final violations = <Map<String, dynamic>>[];
    final nLower = narrative;

    void addV(String severity, String rule, String message, {String? evidence}) {
      violations.add(<String, dynamic>{
        'severity': severity,
        'rule': rule,
        'message': message,
        if (evidence != null) 'evidence': evidence,
        'at': DateTime.now().toIso8601String(),
      });
    }

    // ---- R1: 时间不倒流。从 narrative 提取📅时间戳与 worldState.time 对比 ----
    final tsMatch = RegExp(r'📅\s*([^\n]+)').firstMatch(narrative);
    if (tsMatch != null && p != null) {
      // 只做粗校验：若旧时间是 7月31日，新叙事不能写 7月30 日或更早的日期
      final oldMonth = ws.time.month;
      final oldDay = ws.time.day;
      final newTxt = tsMatch.group(1) ?? '';
      final nM = RegExp(r'(\d{1,2})\s*月').firstMatch(newTxt);
      final nD = RegExp(r'(\d{1,2})\s*日').firstMatch(newTxt);
      if (nM != null && nD != null) {
        final newMonth = int.tryParse(nM.group(1)!) ?? 0;
        final newDay = int.tryParse(nD.group(1)!) ?? 0;
        if (newMonth > 0 && newDay > 0) {
          bool earlier = false;
          if (newMonth < oldMonth) earlier = true;
          if (newMonth == oldMonth && newDay < oldDay) earlier = true;
          // 同月同日允许（不同时段）；只有更早的日期判倒流
          if (earlier) {
            addV('critical', 'R1_time_regression',
                '时间倒流：当前世界时间 ${ws.timestamp}，叙事却写了 $newTxt，严禁时间倒退。',
                evidence: newTxt);
          }
        }
      }
    }

    // ---- R2: 学年状态自洽：刚入学 grade=1 & 9月开学前 → 不允许"学年结束/放暑假/上学期期末考已结束" ----
    if (p != null && !ws.graduated) {
      final grade = p.grade ?? 0;
      final month = ws.time.month;
      const summerEndedKeywords = [
        '学年结束', '暑假开始', '期末考结束', '学期已经结束', '放暑假了', '离校回家',
        '这一学年告一段落', '学期末尾', '年终宴会',
      ];
      bool contradiction = false;
      if (grade == 1 && month <= 9) {
        contradiction = summerEndedKeywords.any((k) => nLower.contains(k));
      }
      // 通用：月份是开学初(9月)/学期中(10-12/1-5)，不能出现"学年结束暑假开始"
      if ([9, 10, 11, 12, 1, 2, 3, 4, 5].contains(month)) {
        if (summerEndedKeywords.any((k) => nLower.contains(k)) && grade >= 1 && grade <= 7) {
          // 只有月份=6或7才允许写学年结束
          contradiction = true;
        }
      }
      if (contradiction) {
        addV('critical', 'R2_academic_contradiction',
            '学年状态矛盾：玩家 grade=$grade，世界月份=$month月（学期内/刚开学），叙事却写"学年结束/放暑假"等剧情，会造成设定错乱。',
            evidence: 'month=$month grade=$grade');
      }
    }

    // ---- R3: 死人不复活 / 未结识NPC不能熟络对话 ----
    for (final entry in npcRegistry.entries) {
      final npc = entry.value;
      // 死人复活：NPC isAlive=false，但叙事里写了他说话/动作
      if (!npc.isAlive) {
        final actionRe = RegExp(
          '${RegExp.escape(npc.name)}[^，。！？]{0,20}(说|笑|走|看|站|伸出|握住|拍|打|喊|叫|望|转身|回答|点头|摇头)',
          caseSensitive: false,
        );
        if (actionRe.hasMatch(narrative)) {
          addV('critical', 'R3_dead_npc_active',
              '死人复活：NPC「${npc.name}」当前已标记死亡(isAlive=false)，但叙事里仍把他写为活人的动作/说话。',
              evidence: npc.name);
        }
      }
      // 未结识但熟络：introduced=false，不能写"XX笑着拍你肩/跟你熟络聊天/你和XX约定好了"
      if (!npc.introduced) {
        final closeRe = RegExp(
          '${RegExp.escape(npc.name)}[^，。！？]{0,20}(笑着|笑了笑|拍.*肩|熟络|亲热|拍.*背|搂着|挽着|跟你.*商量|和你.*约定|早已认识|老朋友)',
          caseSensitive: false,
        );
        if (closeRe.hasMatch(narrative)) {
          addV('warn', 'R3_npc_introduced_familiar',
              '未结识先熟络：NPC「${npc.name}」尚未正式登场(introduced=false)，叙事里却写了熟络互动，下一回合请先写成陌生人碰面。',
              evidence: npc.name);
        }
      }

      // ---- R3b (P1-1)：人设冲突·硬打脸（critical 级会打回重写）----
      // 常见严重 OOC：斯内普"热情/笑/亲切/主动帮/夸学生"、邓布利多"暴怒/刻薄/针对学生"、
      // 德拉科"低声下气/热情对待麻瓜出身"、纳威"冷静大胆主导全场"。
      // 命中规则：人名 + 与人设正相反的关键词 → 判 critical（因为这些是玩家一眼就出戏的 OOC）
      final n = npc.name;
      if (n == '西弗勒斯·斯内普' || n == '斯内普') {
        final oocRe = RegExp(
            r'(斯内普[^，。！？]{0,15}(热情地|亲切地|笑呵呵|满脸笑容|大笑|拍.*肩|主动.*帮|大大夸奖|温柔地|宠溺地|宠溺地|给你一个拥抱|搂着你))',
            caseSensitive: false);
        if (oocRe.hasMatch(nLower)) {
          addV('critical', 'R3b_ooc_snape', '人设冲突(CRITICAL)：斯内普的核心人设是刻薄/阴沉/冷漠，不能描写他"热情亲切大笑拍肩"。',
              evidence: n);
        }
      }
      if (n == '阿不思·邓布利多' || n == '邓布利多') {
        final oocRe = RegExp(
            r'(邓布利多[^，。！？]{0,15}(暴怒地|凶狠地|刻薄地|刁难|针对学生|恶意地|厉声喝骂|抽.*耳光|))',
            caseSensitive: false);
        if (oocRe.hasMatch(nLower) && nLower.contains('邓布')) {
          addV('critical', 'R3b_ooc_dumbledore', '人设冲突(CRITICAL)：邓布利多是睿智温和的校长，不能描写他暴怒刻薄体罚学生。',
              evidence: n);
        }
      }
      if (n == '德拉科·马尔福' || n == '马尔福') {
        // 对麻瓜出身/非纯血 不能"主动热情交好"
        final blood = player?.bloodType ?? '';
        if (blood == 'muggleborn' || blood == 'halfblood') {
          final oocRe = RegExp(
              r'(德拉科|马尔福)[^，。！？]{0,20}(主动凑过来|亲热地|友好地|亲切地|对你有好感地|低声下气|鞠躬|讨好)',
              caseSensitive: false);
          if (oocRe.hasMatch(nLower)) {
            addV('warn', 'R3b_ooc_malfoy_blood',
                '人设冲突：德拉科·马尔福(纯血至上主义)对${blood == "muggleborn" ? "麻瓜出身" : "混血"}玩家，不应描写为"主动热情交好/低声下气"。',
                evidence: '$n vs blood=$blood');
          }
        }
      }
    }

    // ---- R4: 断言打脸（本回合写的动作直接违反上回合注入的断言）----
    for (final assertion in ws.lastTurnAssertions) {
      // 简单匹配：如果断言里含"(锁死/封死/封住)"且叙事出现"你走出门/推开大门/推开窗/走出密室" → 判打脸
      if (RegExp(r'(锁死|封死|封住|挡死|堵死|施了锁门咒)').hasMatch(assertion)) {
        final walked = RegExp(r'(你.*(走出门|推开大门|推开门|推开窗|走出密室|走到大厅|离开房间|下楼))',
            caseSensitive: false);
        if (walked.hasMatch(narrative)) {
          // 但如果玩家本回合行动里含"解锁/破开/解除/打开"的话，允许
          final playerAction = lastPlayerAction;
          final unlockedByPlayer =
              RegExp(r'(解锁|开锁|解开|破开|解除|打开|砸开|敲开|使用开锁咒|阿拉霍洞开|解除封)',
                      caseSensitive: false)
                  .hasMatch(playerAction);
          if (!unlockedByPlayer) {
            addV('warn', 'R4_assertion_lock_violation',
                '物理状态打脸：上回合断言提到门窗/密室被封死，但本回合叙事直接写玩家"走出/推开"了（没有任何解锁/破开动作过渡）。',
                evidence: assertion);
          }
        }
      }
      // 断言"魔杖不在手中"，直接写"你挥杖施法"
      if (RegExp(r'(魔杖.*不在手中|魔杖.*掉在地上|魔杖.*脱手|魔杖.*被缴走)').hasMatch(assertion)) {
        if (RegExp(r'(你.*(挥杖|举起魔杖|挥动魔杖|念咒|施了.*咒|施展.*咒))', caseSensitive: false)
            .hasMatch(narrative)) {
          addV('warn', 'R4_assertion_wand_violation',
              '状态打脸：上回合断言说魔杖不在手中，本回合直接施法却没有"捡/拾/召唤"动作过渡。',
              evidence: assertion);
        }
      }
    }

    // ---- R5: 魔法资质 / 已学会咒语校验（只拦严重的：一年级放守护神咒/夺魂咒这种）----
    if (p != null) {
      final grade = p.grade ?? 1;
      const tooPowerfulForFirst = [
        '守护神咒', '呼神护卫', 'Expecto Patronum', '夺魂咒', '魂魄出窍', 'Imperius',
        '钻心咒', '钻心剜骨', 'Crucio', '杀戮咒', '阿瓦达索命', 'Avada Kedavra',
        '伏地魔', '魂器', '死亡圣器', '有求必应屋', // 主角预知类（对原住民模式）
      ];
      if (grade <= 1) {
        for (final spell in tooPowerfulForFirst) {
          if (nLower.contains(spell) && !p.learnedSpells.containsKey(spell)) {
            addV('warn', 'R5_spell_power_creep',
                '战力膨胀/剧情预知：一年级新生/主角尚未知道的秘密，本回合叙事直接写了「$spell」的成功释放或预知性互动。',
                evidence: spell);
          }
        }
      }
    }

    return violations;
  }

  /// 记录一致性违规（保留最近 20 条，便于 UI 展示和人工调参）
  void recordConsistencyViolation(Map<String, dynamic> v) {
    worldState.consistencyViolations.insert(0, v);
    while (worldState.consistencyViolations.length > 20) {
      worldState.consistencyViolations.removeLast();
    }
  }

  // ==================== P0-3 开局硬骨架守卫（前12回合强制推进链）====================
  // 开局是 AI 最容易墨迹、玩家印象最深的阶段。
  // 不依赖 AI 自觉，按 turn 数强塞"海格敲门/养父母催/特快发车"等硬骨架锚点 + 必要时直接切 currentLocation。
  // 只在前 12 回合生效，12 回合后自动停用（玩家已自由）。
  void _checkOpeningRailroad() {
    if (turnCount >= 12) return;
    final p = player;
    if (p == null) return;
    final loc = worldState.currentLocation ?? '';
    // 只对"家中开局(openingScene=letter)且还没到学校"的玩家起作用：
    // 若用户一开始就选 station 开局则不需要骨架守卫
    if (openingScene != 'letter') return;
    if ((p.house?.isNotEmpty ?? false) && p.grade != null && p.grade! >= 1 && loc.contains('霍格沃茨')) {
      // 已经分完院并在霍格沃茨里了 → 骨架守卫退役
      return;
    }

    final t = turnCount; // 本回合执行前计数（processChoice 里 turnCount++ 发生在更早），实际对应"玩家第t+1次行动"
    // t=0 是初始化 → 首次行动之前；turnCount++ 之后进入判断，范围刚好
    final curLoc = worldState.currentLocation ?? '';

    String? forcedAnchor;
    String? forcedLocation;

    // Turn 1~3（在家 2+ 回合还没出门）→ 海格上门
    final atHome = RegExp(r'(家中|家里|住宅|卧室|书房|庄园|别墅|密室|客厅)', caseSensitive: false);
    if (t >= 2 && t <= 3 && atHome.hasMatch(curLoc) && pendingAnchorDirective == null) {
      forcedAnchor = '鲁伯·海格亲自登门送你（他受邓布利多委托亲自接新生去对角巷采购），'
          '他敲开大门、手里提着霍格沃茨的采购清单和火车票，笑着对你说："该走啦小子/姑娘，再晚就赶不上对角巷奥利凡德的预约了。"'
          ' 这一回合必须自然融入海格来访、和养父母告别、动身前往伦敦的剧情。';
    }
    // Turn 4~5 还在家 → 养父母直接催 + 直接把 currentLocation 推到对角巷入口
    if (t >= 4 && t <= 5 && atHome.hasMatch(curLoc) && pendingAnchorDirective == null) {
      forcedAnchor = '养父母已经把你的行李收拾好，火车票和加隆都塞到了你手里。'
          '（本回合剧情请直接写：海格与你一同抵达伦敦，走进了破釜酒吧后的对角巷入口。采购正式开始。）';
      forcedLocation = '对角巷';
    }
    // Turn 6~7 还没到国王十字/特快 → 对角巷收尾，动身去车站
    final atDiagon = RegExp(r'(对角巷|奥利凡德|摩金夫人|破釜)', caseSensitive: false);
    final atStation = RegExp(r'(国王十字|九又四分之三|站台|特快|列车|火车)', caseSensitive: false);
    if (t >= 6 && t <= 7 && !atStation.hasMatch(curLoc) && pendingAnchorDirective == null) {
      if (atDiagon.hasMatch(curLoc) || atHome.hasMatch(curLoc)) {
        forcedAnchor = '采购收尾：魔杖、课本、袍子都已买齐。海格看了看表："哎呀，十一点的特快！再不走就晚了！"'
            '他一把拉着你幻影移形/乘骑士公共汽车赶往伦敦国王十字车站，'
            '在9又3/4站台口给了你一张霍格沃茨特快车票并嘱咐你"别撞墙撞错了，对着柱子冲过去就行"。'
            ' 本回合剧情结尾必须让你登上特快。';
        if (t >= 7) forcedLocation = '国王十字车站';
      }
    }
    // Turn 8~9 还没到特快 → 直接切到站台并强制"级长喊新生上车"
    if (t >= 8 && t <= 9 && !atStation.hasMatch(curLoc) && pendingAnchorDirective == null) {
      forcedAnchor = '你已抵达国王十字车站，推着行李车穿过了9又3/4站台的柱子。'
          '鲜红色的霍格沃茨特快冒着白烟、汽笛轰鸣。级长扯着嗓子喊："新生快上车！马上就要发车了！"'
          ' 本回合必须写你登上特快、找到包厢坐下的剧情。';
      forcedLocation = '霍格沃茨特快列车';
    }
    // Turn 10~12 还未分院 → 到霍格莫德 + 坐船/马车去城堡 + 分院
    if (t >= 10 && t <= 12 && !(p.house?.isNotEmpty ?? false)) {
      forcedAnchor = '霍格沃茨特快抵达霍格莫德车站。海格举着巨大的灯笼在站台上喊："一年级新生跟我来！"'
          '你们坐小船渡湖初见霍格沃茨城堡，穿过大门来到大礼堂，分院仪式开始。'
          '麦格教授拿着分院帽和凳子走出来，叫到了你的名字。请自然带出分院剧情并最终确定玩家学院。';
      if (t >= 11) forcedLocation = '霍格沃茨大礼堂';
    }

    if (forcedAnchor != null && pendingAnchorDirective == null) {
      pendingAnchorDirective = forcedAnchor;
      notifications.add('🚂 开局骨架推进：下一站剧情已为你安排（turn=$t）');
      worldState.addNarrativeEvent('🚂 开局骨架：turn=${t} 注入强制推进节点', turn: turnCount);
      debugPrint('🚂 开局骨架守卫 turn=$t 注入锚点；forcedLocation=$forcedLocation');
    }
    if (forcedLocation != null) {
      worldState.currentLocation = forcedLocation;
      lastTrackedLocation = forcedLocation;
      turnsAtSameLocation = 0;
    }
  }

  // ==================== P1-3 T1 未完结事项超期提醒 ====================
  // 给 narrative Prompt 拼注入文本用（在 buildPrompt 里调用）。
  String _buildOpenLoopsStagnationHint() {
    final today = worldState.time.absoluteDayIndex;
    final stale = <String>[];
    // 每条 open loop 有 importance 与可能隐含的 lastTouched；
    // 这里做简化：超过 15 回合仍为 open 状态 & importance >= 6 的，给一条提醒
    for (final l in memory.openLoops) {
      if (l.status != 'open') continue;
      if (l.importance < 6) continue;
      final lastTouched = l.id.isEmpty
          ? -1
          : int.tryParse(RegExp(r't(\d+)$').firstMatch(l.id)?.group(1) ?? '') ?? -1;
      final turnsPassed = lastTouched >= 0
          ? turnCount - lastTouched
          : 15; // 没记录的当 15
      if (turnsPassed >= 15 && stale.length < 2) {
        stale.add('• ${l.description}（已悬而未决约${turnsPassed}回合，重要性${l.importance}）');
      }
    }
    if (stale.isEmpty) return '';
    return '【别忘了这些重要伏笔（别让玩家觉得石沉大海）】\n'
        '${stale.join('\n')}\n'
        '提示：本回合可适当推进其中一条，或通过对话/事件给玩家一个"还没忘掉"的信号。\n\n';
  }

  // ==================== P2 禁止词/违和词表 与 P2-2 咒语分级 ====================

  /// 检查叙事/选项里的违和词：现代物品、跨IP、网络梗。
  /// 返回命中列表；命中 1+ 条 critical 级则判需重试。
  List<Map<String, dynamic>> detectForbiddenWords(String text) {
    const modernItems = <String>[
      '手机', '智能手机', '电话', '互联网', '因特网', '微信', 'QQ', '电子邮件', 'email', 'E-mail', '推特', 'Twitter',
      '高铁', '动车', '飞机', '民航', '地铁', '打车', '网约车', '计算机', '电脑', '笔记本电脑', '平板', 'iPad',
      'APP', 'app', '应用程序', '游戏主机', 'PS5', 'Switch', '电视', '冰箱', '空调',
      '加隆兑换人民币', '汇率', '电子支付', '扫码', '二维码',
    ];
    const crossIp = <String>[
      '柯南', '工藤新一', '海贼王', '路飞', '火影忍者', '鸣人', '佐助', '原神', '旅行者', '刻晴', '钟离',
      '斗罗大陆', '唐三', '斗破苍穹', '萧炎', '三体', '逻辑', '三体人', '智子',
    ];
    const internetSlang = <String>[
      'yyds', 'YYDS', '绝绝子', '社死', '打call', '破防了', '内卷', '躺平', 'emo', 'EMO',
      '栓Q', '666', '233', 'awsl', 'AWSL', 'xswl', 'XSWL', '笑死我了哈哈哈哈',
      '大冤种', 'emo了', '我不李姐', '咱就是说', '一整个爱住',
    ];
    final hits = <Map<String, dynamic>>[];
    final lower = text;
    for (final w in modernItems) {
      if (lower.contains(w)) hits.add({'severity': 'critical', 'category': 'modern', 'word': w});
    }
    for (final w in crossIp) {
      if (lower.contains(w)) hits.add({'severity': 'critical', 'category': 'cross_ip', 'word': w});
    }
    for (final w in internetSlang) {
      if (lower.contains(w)) hits.add({'severity': 'warn', 'category': 'slang', 'word': w});
    }
    return hits;
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
