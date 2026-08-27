import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart';
import '../models/npc.dart';
import '../models/game_systems.dart';
import '../services/deepseek_service.dart';
import '../models/player.dart';
import '../utils/prompt_sanitizer.dart';
import '../utils/story_text_renderer.dart';
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

    // 恋爱链路接线：玩家在选择「接受/婉拒表白」选项时直接结算，
    // 避免表白剧情永远悬置（此前 resolveConfession 无任何调用方）。
    final love = player!.loveState;
    if (love.awaitingConfession && love.consideringNpcName != null) {
      if (action.contains('接受')) {
        resolveConfession(true, love.consideringNpcName!);
      } else if (action.contains('婉拒') || action.contains('拒绝')) {
        resolveConfession(false, love.consideringNpcName!);
      }
    }

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
  ${buildContinuityBridgePromptLine()}
  $stagnationLine$anchorLine${extra.isNotEmpty ? extra + '\n' : ''}【玩家行动】
  $safeAction

$kNarrativeWritingRules
  ''';
    }

    try {
      // 场景转移图（替换仅前12回合生效的 _checkOpeningRailroad）
      //  - 开局家中/对角巷/国王十字/特快/分院/公共休息室/第一节课 全阶段通用
      //  - 所有地点切换强制检查进度门+时间门，不满足只注入衔接锚点，绝不硬切 location
      runSceneTransitionGraph();

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
      int retriesLeft = 2; // 允许 critical 级违规 / BUG-H(模型返回选项而非叙事) 自动重试 2 次
      List<Map<String, dynamic>> violations = const [];
      List<Map<String, dynamic>> forbiddenHits = const [];
      bool needsRetry;
      bool narrativeParseInvalid = false; // BUG-H 标记：模型返回的是选项不是叙事
      do {
        needsRetry = false;
        narrativeParseInvalid = false;
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
        final parseOk = parseNarrativeOnly(response);
        if (!parseOk) {
          // BUG-H：模型把 narrative 场景当 choice 场景用了，全返回 A.B.C.D.
          narrativeParseInvalid = true;
          debugPrint('❌ [BUG-H] 当前 parseNarrativeOnly 返回 false，视为 critical 级异常触发重试');
        }

        // --- ContinuityBridge Step C：新叙事必须承接上回合末尾锚点 ---
        // 不衔接 → 开头自动补承接过渡句（不打回重写，以防"凭空换剧情"）
        if (!narrativeParseInvalid) {
          final bridged = enforceContinuityBridge(currentNarrative, safeAction);
          if (bridged != currentNarrative) {
            currentNarrative = bridged;
            // 重新跑 parseNarrativeOnly（因为 currentNarrative 变了，好感/时间等解析要一致）
            // 注：bridged 是我们自己代码生成的 + 原叙事合并的，已经保证不是选项格式
            parseNarrativeOnly(currentNarrative);
          }
        }

        // --- P2-1 禁止词检测（现代物品/跨IP/网络梗）---
        forbiddenHits = narrativeParseInvalid
            ? const []
            : detectForbiddenWords(currentNarrative);
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
        violations = narrativeParseInvalid
            ? const []
            : validateNarrativeConsistency(currentNarrative);
        for (final v in violations) {
          recordConsistencyViolation(v);
        }
        final criticalViolations = violations.where((v) => v['severity'] == 'critical').toList();

        // --- 判定：critical 违规 / critical 禁止词 / BUG-H(叙事返回选项) → 重试
        final anyCritical = criticalViolations.isNotEmpty || criticalForbidden.isNotEmpty || narrativeParseInvalid;
        if (retriesLeft > 0 && anyCritical) {
          final msgs = <String>[
            if (narrativeParseInvalid) '模型搞错场景了，本应生成剧情正文但返回了选项A/B/C/D。请严格按照【写作要求】输出600-800字剧情叙事，绝对不要包含任何选项格式的行(A./B./C./D.)！',
            ...criticalViolations.map((v) => '${v['rule']}: ${v['message']}'),
            ...criticalForbidden.map((h) => '违和词(${h['category']}): ${h['word']}'),
          ];
          debugPrint('⚠️ 叙事 critical 级异常，准备重试（剩余${retriesLeft}次）：${msgs.take(3).join(" | ")}');
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
          loadingStage = narrativeParseInvalid
              ? '模型返回选项而非剧情，重跑中...'
              : '剧情${criticalViolations.length + criticalForbidden.length}处违规，重试中...';
          notifyListeners();
          continue;
        }

        // ====== 重试全部用完还是 BUG-H？ → 直接走本地兜底叙事（保证不是选项） ======
        if (narrativeParseInvalid && retriesLeft == 0) {
          debugPrint('❌ [BUG-H] 2次重试后仍返回选项，切换为 generateFallbackNarrative() 本地兜底叙事');
          currentNarrative = generateFallbackNarrative();
          // 兜底叙事是 Dart 代码生成的，不会夹带选项，也没有好感度区块
          // 所以不用再跑 parseNarrativeOnly，但要跑一遍地点同步等后续流程
          notifications.add('📝 AI 返回了选项而非剧情（偶尔会发生），已为你切换为系统本地过渡剧情，确保不断链。稍后重跑会恢复正常。');
          break;
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
        // 独立选项生成失败时：直接走与超时同一套「末尾800字承接型」兜底，
        // 彻底弃用 generateContextualFallbackChoices（它会按关键词匹配出"仔细查看"这种简易选项，
        // 玩家点击后AI拿到与剧情结尾无关的动作，造成"刚生成的剧情没操作就被另一个剧情替换"的断链）。
        debugPrint('独立选项生成失败，切换到末尾承接型兜底选项');
        choices = buildFallbackChoices(currentNarrative);
      }

      // --- ContinuityBridge Step A：把本回合叙事的末尾锚点存档，下回合强制衔接 ---
      // 注意：先同步 location（_syncLocationFromNarrative）后再 saveAnchor，确保 location 锚点是最新的
      saveContinuityAnchor(currentNarrative);

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

      // ====== 长线记忆提取：从摘要响应中解析结构化块写入 LongTermMemory ======
      // 这是记忆管线的核心——复用摘要调用（零额外 API），让数百回合后
      // AI 仍然拥有结构化的核心事实、未完结事项和世界事件。
      _extractMemoryFromSummary(rawSummary);

      // 从 narrativeSummary 中剥离结构化块（它们已写入 LongTermMemory，
      // 不需要在 T4 自然语言摘要中重复，避免 token 浪费）
      narrativeSummary = _stripStructuredBlocks(rawSummary);
      pendingSummary = '';
      debugPrint('✅ 剧情摘要已更新 (${narrativeSummary.length}字，上限=$hardLimit)');
    } catch (e) {
      debugPrint('❌ 摘要生成失败: $e');
    }
  }

  /// 从摘要响应中提取结构化记忆块，写入 LongTermMemory
  void _extractMemoryFromSummary(String rawSummary) {
    final ts = worldState.time.format();

    // 1. 提取【核心事实】→ T0 keyFacts
    final factsBlock = _extractBlock(rawSummary, '核心事实');
    if (factsBlock.isNotEmpty) {
      final facts = factsBlock
          .split('\n')
          .map((l) => l.replaceAll(RegExp(r'^[\s•·\-\d]+'), '').trim())
          .where((l) => l.isNotEmpty && l != '无' && l.length > 5)
          .take(10) // 每次摘要最多提取10条，防止爆炸
          .toList();
      for (final fact in facts) {
        // 用事实内容的前20字做去重 id
        final factId = 'auto_${fact.hashCode.toRadixString(36)}';
        memory = memory.addKeyFact(KeyFactRecord(
          id: factId,
          fact: fact.length > 80 ? fact.substring(0, 80) : fact,
          importance: 7, // 摘要提取的事实默认重要度7（低于身份级9，高于日常5）
          timestamp: ts,
          category: 'auto_extracted',
        ));
      }
      if (facts.isNotEmpty) {
        debugPrint('📝 记忆提取：${facts.length}条核心事实');
      }
    }

    // 2. 提取【伏笔】→ T1 openLoops
    final loopsBlock = _extractBlock(rawSummary, '伏笔');
    if (loopsBlock.isNotEmpty) {
      final loops = loopsBlock
          .split(RegExp(r'[;；\n]'))
          .map((l) => l.replaceAll(RegExp(r'^[\s•·\-\d]+'), '').trim())
          .where((l) => l.isNotEmpty && l != '无' && l.length > 5)
          .take(8)
          .toList();
      for (final loop in loops) {
        final loopId = 'auto_loop_${loop.hashCode.toRadixString(36)}';
        // 只添加新的（不覆盖已有的）
        final existing = memory.openLoops.where((l) => l.id == loopId);
        if (existing.isEmpty) {
          memory = memory.addOrUpdateOpenLoop(OpenLoopRecord(
            id: loopId,
            description: loop.length > 100 ? loop.substring(0, 100) : loop,
            status: 'open',
            importance: 6,
            openedAt: ts,
            loopType: 'foreshadow',
          ));
        }
      }
      if (loops.isNotEmpty) {
        debugPrint('📝 记忆提取：${loops.length}条伏笔/承诺');
      }
    }

    // 3. 提取【世界事件】→ T3 worldEvents
    final eventsBlock = _extractBlock(rawSummary, '世界事件');
    if (eventsBlock.isNotEmpty) {
      final events = eventsBlock
          .split('\n')
          .map((l) => l.replaceAll(RegExp(r'^[\s•·\-\d]+'), '').trim())
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
        memory = memory.addWorldEvent(WorldEventRecord(
          id: evId,
          timestamp: ts,
          title: title.length > 12 ? title.substring(0, 12) : title,
          description: desc.length > 60 ? desc.substring(0, 60) : desc,
          importance: 6,
          category: 'wizarding',
        ));
      }
      if (events.isNotEmpty) {
        debugPrint('📝 记忆提取：${events.length}条世界事件');
      }
    }
  }

  /// 提取摘要响应中指定块的内容
  String _extractBlock(String text, String blockName) {
    final pattern = RegExp('【$blockName】\\s*\\n?([\\s\\S]*?)(?=【|\$)');
    final match = pattern.firstMatch(text);
    return match?.group(1)?.trim() ?? '';
  }

  /// 从摘要中剥离结构化块（已写入 LongTermMemory，不需要在 T4 中重复）
  String _stripStructuredBlocks(String text) {
    var cleaned = text;
    // 剥离【关系】【伏笔】【核心事实】【世界事件】块
    cleaned = cleaned.replaceAll(RegExp(r'【关系】[\s\S]*?(?=【|$)'), '');
    cleaned = cleaned.replaceAll(RegExp(r'【伏笔】[\s\S]*?(?=【|$)'), '');
    cleaned = cleaned.replaceAll(RegExp(r'【核心事实】[\s\S]*?(?=【|$)'), '');
    cleaned = cleaned.replaceAll(RegExp(r'【世界事件】[\s\S]*?(?=【|$)'), '');
    return cleaned.trim();
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
  // ============================================================
  // 【宏观通用 M4 · StagnationDetector 停滞检测器】
  //
  // 把之前散落的 3 个独立函数（阈值分级/豁免地点/未解决钩子）+ buildPrompt 里的停滞文案拼接逻辑，
  // 集中封装成一个独立对象。好处：
  //   - 后期新增地点、新增"豁免剧情类型"，只改这一处数据 + 规则；
  //   - mixin_narrative / mixin_response / 未来其它 mixin 调用统一出口，不会出现各自 if 版本不一致；
  //   - "停滞 → 强制推进文案" 从 buildPrompt 里解耦出来，可单独单测。
  //
  // 旧 API（isLocationExemptFromStagnation / stagnationThresholdFor / narrativeHasUnresolvedHook）
  // 保持对外不变：内部委托给 StagnationDetector，不会破坏 GameProviderBase 的 abstract 签名。
  // ============================================================

  static const StagnationDetector _stagnation = StagnationDetector._();

  bool isLocationExemptFromStagnation(String location) =>
      _stagnation.isExempt(location);
  int stagnationThresholdFor(String location) =>
      _stagnation.thresholdFor(location);
  bool narrativeHasUnresolvedHook(String narrative) =>
      _stagnation.hasUnresolvedHook(narrative);

  String buildStagnationPromptLine({
    required String currentLocation,
    required int turnsAtSameLocation,
    required bool hasUnresolvedHook,
    required int turnCount,
  }) =>
      _stagnation.buildPromptLine(
        currentLocation: currentLocation,
        turnsAtSameLocation: turnsAtSameLocation,
        hasUnresolvedHook: hasUnresolvedHook,
        turnCount: turnCount,
      );


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

  // ============================================================
  // 【宏观通用 M3 · ContinuityBridge 全局衔接桥】
  //
  // 目标：**无论触发路径是什么（正常 narrative / CRITICAL 重写 / 用户自定义 action / 兜底叙事）**，
  //       新生成的 narrative 都必须与**上一段剧情的结尾**自然衔接，不允许"刚生成一段没操作就被另一段替换"。
  //
  // Pipeline：
  //   Step A) 每回合叙事结束 → extractContinuityAnchor(prevNarrative)：
  //             从上一段末尾 800 字抓 4 要素: last_speaker / last_dialog / last_action / location
  //             存入 worldState.lastNarrativeAnchor。
  //   Step B) 下回合 buildPrompt 生成前 → buildContinuityBridgePromptLine()：
  //             强制把锚点用"第一句必须承接"的约束注入 Prompt，AI 不可以开新场景。
  //   Step C) parseNarrativeOnly 后 → enforceContinuityBridge(newNarrative)：
  //             正则检查新叙事是否显式呼应锚点（提了同地点/同一说话者/同一未完成动作的后续）。
  //             若不衔接：不打回重写（避免"换剧情"观感），而是在 narrative 开头自动插入一句
  //             "承接过渡句"，把上一段锚点与新叙事的开头软连起来。连续 3 次不衔接 → 给一条通知。
  // ============================================================

  /// Step A：从一段 narrative 的末尾抓衔接锚点，存入 worldState.lastNarrativeAnchor。
  /// 之后所有生成新 narrative 的路径（无论哪种）都会被要求承接。
  void saveContinuityAnchor(String narrative) {
    if (narrative.isEmpty) {
      worldState.lastNarrativeAnchor.clear();
      return;
    }
    // BUG3b 修复·strip承接标记：在抓锚点之前，先清理内部 meta 标记
    // （承接前缀/SceneGraph debug 行），防止锚点被"承接：就在家中·卧室"
    // 这类元文本污染，导致下回合 enforceContinuityBridge 正则误判匹配、
    // 以及衔接桥 prompt 里注入用户可见的「承接：XXX」调试说明。
    final cleanNarrative = StoryTextRenderer.stripInternalMetaMarkers(narrative);
    final tail = cleanNarrative.length > 800 ? cleanNarrative.substring(cleanNarrative.length - 800) : cleanNarrative;
    final anchor = <String, String>{};

    // 1) location
    final loc = worldState.currentLocation;
    if (loc != null && loc.isNotEmpty) anchor['location'] = loc;

    // 2) last_speaker + last_dialog
    final afterQuoteRe = RegExp(
      r'[」"】][^，。！？\n]*?(养母|养父|海格|邓布利多|阿不思|斯内普|西弗勒斯|麦格|米勒娃|哈利|詹姆|波特|罗恩|韦斯莱|赫敏|格兰杰|马尔福|德拉科|纳威|隆巴顿|卢娜|洛夫古德|金妮|弗雷德|乔治|珀西|亚瑟|莫丽|小天狼星|布莱克|卢平|莱姆斯|教授|级长|妈妈|爸爸|同学|NPC)[^，。！？\n]{0,10}(说|开口|问|道|回答|叹了口气|笑了笑|低声|沉声|看着你)',
      caseSensitive: false,
    );
    final aqm = afterQuoteRe.allMatches(tail);
    if (aqm.isNotEmpty) anchor['last_speaker'] = aqm.last.group(1) ?? '';
    final dialogRe = RegExp(r'[「"]([^「"」]{2,40})[」"]', caseSensitive: false);
    final dm = dialogRe.allMatches(tail);
    if (dm.isNotEmpty) anchor['last_dialog'] = dm.last.group(1) ?? '';

    // 3) last_action（最后未完成动作）：正则抓"正/正要/刚/准备/就要/等着/听到敲门声/握着门把手/盯着"等时态
    final hangingRe = RegExp(r'((正要|刚要|准备|就要|等着|正看着|盯着|握着.*把手|听到.*敲门声|敲门声响起|还没|尚未)[^。！？\n]{0,40})');
    final hm = hangingRe.allMatches(tail);
    if (hm.isNotEmpty) {
      anchor['last_action'] = hm.last.group(1) ?? '';
    } else {
      // 兜底：最后一个动作动词
      final genericRe = RegExp(r'((你|你.+)[^。！？\n]{0,30}(站起身|走过去|坐下来|点点头|摇摇头|开口|问|说|笑了笑|叹了口气|伸出手|握住|接过|放下|看向|望向|转身))');
      final gm = genericRe.allMatches(tail);
      if (gm.isNotEmpty) anchor['last_action'] = gm.last.group(1) ?? '';
    }

    worldState.lastNarrativeAnchor.clear();
    worldState.lastNarrativeAnchor.addAll(anchor);
  }

  /// Step B：把衔接桥锚点注入 buildPrompt。返回一段文本，直接拼进【当前场景】后面。
  String buildContinuityBridgePromptLine() {
    final a = worldState.lastNarrativeAnchor;
    if (a.isEmpty) return '';
    final loc = a['location'];
    final sp = a['last_speaker'];
    final dg = a['last_dialog'];
    final ac = a['last_action'];
    if (loc == null && sp == null && ac == null) return '';
    final parts = <String>[];
    if (loc != null && loc.isNotEmpty) parts.add('地点=$loc');
    if (sp != null && sp.isNotEmpty) parts.add('最后说话者=$sp');
    if (dg != null && dg.isNotEmpty) parts.add('最后一句="$dg"');
    if (ac != null && ac.isNotEmpty) parts.add('最后动作/姿态=$ac');
    return '【🔗 衔接桥·必须遵守】\n'
        '上一段剧情结尾的锚点是：${parts.join('｜')}。\n'
        '本回合 narrative 的开头必须**直接承接这一刻**（例如：描写对方说完话后你的反应、继续完成最后那个未完成的动作、从那个地点的状态写起）。\n'
        '严禁毫无过渡地切换到一个不相关的新场景/新话题，严禁"跳过中间 1~2 小时的过程"直接写结果。\n'
        '如果本回合玩家行动确实需要换场景，你也必须先写 1~2 句承接段交代"从那个锚点是怎样过渡到新场景的"，再开始写新场景。\n\n';
  }

  /// Step C：对 AI 新吐出来的 narrative 做衔接校验；若不衔接则在开头自动插入承接句，不打回重写。
  /// 返回最终要存入 currentNarrative 的文本。
  String enforceContinuityBridge(String newNarrative, String playerActionText) {
    final a = worldState.lastNarrativeAnchor;
    if (a.isEmpty) {
      worldState.continuityBridgeMisses = 0;
      return newNarrative;
    }
    if (newNarrative.isEmpty) return newNarrative;

    final loc = a['location'] ?? '';
    final sp = a['last_speaker'] ?? '';
    final ac = a['last_action'] ?? '';
    final head = newNarrative.length > 300 ? newNarrative.substring(0, 300) : newNarrative;

    bool matched = false;
    // 简单判断：新叙事开头 300 字里至少出现锚点其中一个关键词 => 视为已衔接
    final checkHits = [loc, sp, ac]
        .where((e) => e.trim().length >= 2)
        .where((keyword) => head.contains(keyword))
        .toList();
    if (checkHits.isNotEmpty) matched = true;

    // 如果玩家本回合行动本身就是"换场景型动作"（出发/前往/动身/回家/去XX），允许直接写换场景，视为已衔接
    final travelRe = RegExp(r'(前往|出发|动身|去.*(车站|对角巷|大礼堂|特快|霍格沃茨)|回家|返校|走出门|下楼|走进)', caseSensitive: false);
    if (!matched && travelRe.hasMatch(playerActionText)) matched = true;

    if (matched) {
      worldState.continuityBridgeMisses = 0;
      return newNarrative;
    }

    // ---- 不衔接：在开头补一句承接过渡，**绝对不打回重写**（否则就是玩家观感的"换剧情"） ----
    worldState.continuityBridgeMisses += 1;
    final bridgeParts = <String>[];
    if (loc.isNotEmpty) bridgeParts.add('就在$loc');
    if (sp.isNotEmpty) bridgeParts.add('${sp}的话音刚落');
    if (ac.isNotEmpty) bridgeParts.add('你正$ac的那一刻');
    final bridgeSentence = (bridgeParts.isNotEmpty
            ? '（承接：${bridgeParts.join('、')}）'
            : '（承接上一段剧情的结尾）') +
        '—— 紧接着，';
    final repaired = bridgeSentence + newNarrative;

    // 连续 3 次不衔接：给一条通知提醒玩家"模型可能被上下文污染，若持续可新开档"，不报警
    if (worldState.continuityBridgeMisses >= 3) {
      notifications.add('🔗 衔接桥：最近连续${worldState.continuityBridgeMisses}回合叙事衔接偏弱，已自动在开头补承接过渡句。若剧情仍有断裂感，请把 ai_log 贴给作者调参。');
      worldState.continuityBridgeMisses = 0; // 清 0，避免每次都刷屏
    }
    debugPrint('🔗 ContinuityBridge 自动补承接: anchor=$a 插句长度=${bridgeSentence.length}');
    return repaired;
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

      // ============================================================
      // 【宏观通用 R3b 人设防线】替换掉"手写 if(斯内普/邓布利多/马尔福)+各写一份正则"的补丁式实现。
      // 核心：对 npcRegistry 里 ALL NPC（含动态生成的 isGenerated=true）生效，
      //      通过 NPC.allNames（全名/别名/姓氏/名字）× NPC.forbiddenActions 做笛卡尔匹配，
      //      命中「名称+≤15字禁动紧邻」=> OOC。bloodSupremacist 对麻瓜/混血玩家的热情对待另行拦截。
      //
      // 之前"手写 if"的 3 个痛点：
      //   1) 新 NPC/学年 NPC 裸奔，没有人设校验；
      //   2) 每条正则容易写出末尾空分支 `|)`，导致 100% 误判 CRITICAL 触发重写；
      //   3) 每条 severity 写死，剧情化 OOC 直接 CRITICAL→整段换剧情，玩家观感断链。
      // ============================================================
      if (npc.forbiddenActions.isNotEmpty) {
        for (final nameVariant in npc.allNames) {
          if (nameVariant.length < 2) continue;
          // ---- 【防误判·通用称谓保护】----
          // 如果 nameVariant 本身含有"校长/教授/院长"等通用词尾缀（如"邓布利多校长"），
          // 则额外要求：叙事里**必须同时出现该 NPC 的姓氏或全名**，否则判定为"其他人物 + 通用称谓"的误匹配。
          // 例：剧情写"麦格教授说..."，此时仅当叙事里也出现"麦格/米勒娃"，才会对"麦格教授"这个 alias 做OOC校验。
          const genericTitles = ['校长', '教授', '院长', '主任', '老师', '先生', '女士', '级长', '队长'];
          bool isTitledVariant = genericTitles.any((t) => nameVariant.contains(t));
          bool npcIdentityAlsoPresent = true;
          if (isTitledVariant) {
            final identityHints = <String>[
              // 拆分全名的姓氏、名字
              if (npc.name.contains('·')) ...npc.name.split('·'),
              if (npc.name.contains(' ')) ...npc.name.split(' '),
              npc.name,
              // 不含通用词的 aliases（短alias如"老邓"也可作为身份依据）
              ...npc.aliases.where((a) => !genericTitles.any((t) => a.contains(t))),
            ];
            npcIdentityAlsoPresent = identityHints.any((hint) =>
                hint.length >= 2 && nLower.contains(hint.toLowerCase()));
          }
          if (!npcIdentityAlsoPresent) continue;

          // 注意：下面 forbiddenActions.join('|') 由 forbiddenActions 列表项本身组成，
          // 列表项是纯短语（由 NPC._autoDeriveForbiddenActions 产生），不含空串，因此不会出现 `|)` 空分支。
          final joinedFbd = npc.forbiddenActions
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .map(RegExp.escape)
              .join('|');
          if (joinedFbd.isEmpty) continue;
          final oocRe = RegExp(
            '${RegExp.escape(nameVariant)}[^，。！？]{0,15}($joinedFbd)',
            caseSensitive: false,
          );
          if (oocRe.hasMatch(nLower)) {
            // 【熔断】默认降为 warn（软提醒下一回合修正），只有"禁动包含严重暴烈关键词"才升级为 CRITICAL。
            // 另外增加最终保护：命中文本中如果紧邻出现否定词（不/没/并非/从不/不会/不是），则忽略（
            // 避免"邓布利多不会暴怒/并不是刻薄的人"这种反向说明被误判为 OOC）。
            final m = oocRe.firstMatch(nLower);
            final hitVerb = m?.group(1) ?? '';
            final hitStart = m?.start ?? 0;
            final beforeHit = hitStart > 8
                ? nLower.substring(hitStart - 8, hitStart)
                : (hitStart > 0 ? nLower.substring(0, hitStart) : '');
            if (RegExp(r'(不|没|并非|从未|从不|不会|不是|何必|何苦)', caseSensitive: false).hasMatch(beforeHit)) {
              debugPrint('[OOC 跳过·否定词前置] ${npc.name}|$nameVariant|$hitVerb 前置="$beforeHit"');
              continue;
            }
            final severeRe = RegExp(r'(体罚|抽.*耳光|殴打|虐待|恶意陷害|栽赃|背叛|收受贿赂|徇私)', caseSensitive: false);
            final isSevere = severeRe.hasMatch(hitVerb);
            final sev = isSevere ? 'critical' : 'warn';
            final summary = npc.personality.isNotEmpty
                ? npc.personality.take(3).join('/')
                : '默认人设';
            addV(sev, 'R3b_ooc_generic',
                '人设冲突(${sev == "critical" ? "严重·会打回重写" : "轻微·仅提醒修正"})：NPC「${npc.name}」人设为「$summary」，不应描写为「$nameVariant … $hitVerb」这类与人设正相反的动作。',
                evidence: '${npc.name}|$nameVariant|$hitVerb');
            if (isSevere) {
              break; // 只要有一个严重禁动命中就记录一次 CRITICAL，避免同段剧情多次 CRITICAL 叠加
            }
          }
        }
      }
      // 纯血至上主义 NPC：对麻瓜出身/混血玩家，不能"主动热情交好/低声下气"（通用版马尔福 OOC）
      if (npc.bloodSupremacist) {
        final blood = player?.bloodType ?? '';
        if (blood == 'muggleborn' || blood == 'halfblood') {
          for (final nameVariant in npc.allNames) {
            if (nameVariant.length < 2) continue;
            final oocRe = RegExp(
              '${RegExp.escape(nameVariant)}[^，。！？]{0,20}(主动凑过来|亲热地|友好地|亲切地|对你有好感地|低声下气|鞠躬|讨好|巴结|谄媚)',
              caseSensitive: false,
            );
            if (oocRe.hasMatch(nLower)) {
              addV('warn', 'R3b_ooc_blood_supremacist',
                  '人设冲突：「${npc.name}」为纯血至上主义，对${blood == "muggleborn" ? "麻瓜出身" : "混血"}玩家，不应描写为"主动热情交好/低声下气"。',
                  evidence: '${npc.name}|blood=$blood');
              break;
            }
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

    // ---- BUG2b R3c: 原创主角≠哈利的家庭设定混淆检测（德思礼/女贞路杂交）----
    if (p != null && p.name.toLowerCase() != '哈利' && !p.name.contains('波特')) {
      // 命中1：好感变化/叙事里直接出现「XX·德思礼」作为玩家养母/养父（如玛吉·德思礼）
      final dursleyFamilyRe = RegExp(
        r'(玛吉|弗农|佩妮|达力)\s*[·.]?\s*德思礼|德思礼\s*(家|一家|夫妇|门口|住宅|姨父|姨妈|表哥)',
        caseSensitive: false,
      );
      final privetDriveRe = RegExp(r'女贞路\s*4\s*号|德文郡.*德思礼', caseSensitive: false);
      if (dursleyFamilyRe.hasMatch(narrative) || privetDriveRe.hasMatch(narrative)) {
        addV('critical', 'R3c_family_not_dursley',
            '家庭设定杂交：主角是原创玩家（非哈利·波特），本回合却出现德思礼一家/女贞路4号等哈利专属的家庭成员和地点。必须把养母/养父称呼为"养母/养父/妈妈/爸爸"或原创姓名，绝不能套用德思礼的姓和住址。',
            evidence: dursleyFamilyRe.stringMatch(narrative) ?? privetDriveRe.stringMatch(narrative) ?? '');
      }
      // 命中2：当"弗农/佩妮/达力"单独出现在"家门/楼下喊你/敲门"这种家庭成员语境时也命中
      final aloneDursley = RegExp(r'(弗农姨父|佩妮姨妈|达力表哥)', caseSensitive: false);
      if (aloneDursley.hasMatch(narrative)) {
        addV('critical', 'R3c_family_not_dursley',
            '家庭设定杂交：主角不是哈利，叙事里却直接称呼家人为"弗农姨父/佩妮姨妈/达力表哥"（这些是哈利专属亲属称谓）。原创角色的家人必须使用原创称呼或"养父/养母/妈妈/爸爸"。',
            evidence: aloneDursley.stringMatch(narrative) ?? '');
      }
    }

    // ---- BUG5 R1b: 开学时间/阶段错位（7月31日还在暑假却写分院/上课/特快正式开学）----
    final monthDayMatch = RegExp(r'(\d{4})年\s*(\d{1,2})月\s*(\d{1,2})日').firstMatch(nLower);
    if (monthDayMatch != null) {
      final m = int.tryParse(monthDayMatch.group(2) ?? '') ?? 0;
      final d = int.tryParse(monthDayMatch.group(3) ?? '') ?? 0;
      final md = m * 100 + d;
      // 7月31日 ~ 8月31日（开学前）绝对不允许出现"分院仪式/坐在学院长桌旁/正式上课/霍格沃茨特快已经开学当日抵达"这种已入学内容
      if (md >= 701 && md <= 831) {
        const forbiddenAfterAugust = ['分院仪式', '坐在学院长桌', '学院长桌旁', '正式上课', '第一节课', '分院帽叫到你的名字', '霍格沃茨特快抵达霍格莫德', '渡湖去大礼堂'];
        for (final fb in forbiddenAfterAugust) {
          if (nLower.contains(fb)) {
            addV('warn', 'R1b_school_date_misalign',
                '时间阶段错位：当前日期是${m}月${d}日（1991年暑假中/开学准备期），却写了"$fb"这种已入学场景。9月1日之前只能写"在家准备→对角巷采购→国王十字候车→登上特快"，正式分院/上课必须到9月1日之后。',
                evidence: '$md: $fb');
            break;
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

  // ============================================================
  // 【宏观通用 M2 · SceneTransitionGraph 场景转移图】
  // 替换掉"只对开局前 12 回合生效 + 用 if/else 写死 + forcedLocation 硬切地点"的 _checkOpeningRailroad。
  //
  // 核心思想：把"剧情应该怎么走"抽象成**带前置依赖的节点图**，任何阶段（开局/学年中/放假/大战前夕）都可以往
  // _transitionNodes 里加节点即可，不写死在代码分支里。
  //
  // 修复 2 个之前的宏观问题：
  //   1) forcedLocation 直接硬切 currentLocation 导致"7月31日在家→霍格沃茨大礼堂"跳场景 →
  //      现在：只有节点依赖 100% 满足时才允许更新 currentLocation；不满足则只注入 "过渡叙事锚点" 让 AI 补中间过程。
  //   2) 只有开局 12 回合有守卫，中后期玩家在地图/事件链上墨迹时完全无兜底 →
  //      现在：图上所有节点对当前地点匹配生效，不分阶段。
  // ============================================================

  /// 转移节点：「玩家当前应当位于 currentLocationPattern」→「当 turnsAtSameLocation 超过 turnRange 上限 或 turnCount∈[minT,maxT]」，
  /// 且 前置条件 requireVisited/requireDateInt/requireFlag 全部满足 → 给玩家注入 transitionAnchor（中间过程剧情要求），
  /// 最终让玩家抵达 nextLocation。
  static const List<_TransitionNode> _transitionNodes = [
    // ---------- 开局骨架链（家中收到信 → 对角巷 → 国王十字 → 特快 → 分院）----------
    _TransitionNode(
      id: 'opening_hagrid_visit',
      currentLocationPattern: r'(家中|家里|住宅|卧室|书房|庄园|别墅|密室|客厅|门厅)',
      requireVisited: const [], // 不需要前置地点
      requireNotVisited: const [r'(对角巷|国王十字|九又四分之三|站台|特快|列车|霍格沃茨)'],
      minTurn: 2,
      maxTurn: 3,
      requireOpeningScene: 'letter',
      // 锚点 = 中间过程：海格登门 + 和养父母告别 + 动身去伦敦 → 这一段必须 AI 完整写，不能跳
      transitionAnchor: '鲁伯·海格亲自登门送你（他受邓布利多委托亲自接新生去对角巷采购），他敲开大门、手里提着霍格沃茨的采购清单和火车票，笑着对你说："该走啦小子/姑娘，再晚就赶不上对角巷奥利凡德的预约了。" 本回合剧情必须自然融入：海格来访 → 和养父母告别 → 动身前往伦敦这三个中间阶段，不能跳帧直接进入采购画面。',
      nextLocation: null,
    ),
    _TransitionNode(
      id: 'opening_force_diagon_alley',
      currentLocationPattern: r'(家中|家里|住宅|卧室|书房|庄园|别墅|密室|客厅|门厅)',
      requireVisited: const [],
      requireNotVisited: const [r'对角巷'],
      minTurn: 4,
      maxTurn: 5,
      requireOpeningScene: 'letter',
      transitionAnchor: '养父母已经把你的行李收拾好，火车票和加隆都塞到了你手里。本回合请写出完整的衔接过程：你与海格一同抵达伦敦 → 经过破釜酒吧 → 穿过吧台后的砖墙入口 → 正式进入对角巷开始采购。必须把"从家到对角巷的过程"完整写出来，不能第一句就写"此刻你正在魔杖店门口"。',
      nextLocation: '对角巷',
      // 允许在 minT/maxT 到期且已过渡叙事写完后，更新 currentLocation（之前这里直接无依赖切 = 跳场景 bug）
      forceNextOnlyIfAnchorPresented: true,
    ),
    _TransitionNode(
      id: 'opening_diagon_to_station',
      currentLocationPattern: r'对角巷',
      requireVisited: const [r'对角巷'],
      requireNotVisited: const [r'(国王十字|九又四分之三|站台|特快|列车)'],
      minTurn: 6,
      maxTurn: 7,
      requireOpeningScene: 'letter',
      transitionAnchor: '采购收尾阶段：魔杖、课本、袍子都已买齐。海格看了看表："哎呀，十一点的特快！再不走就晚了！" 他拉着你通过骑士公共汽车/幻影移形赶往伦敦国王十字车站。本回合剧情必须包含完整过程：结算采购 → 赶车前往国王十字 → 来到 9 又 3/4 站台口 → 拿到霍格沃茨特快车票 → 最后一句必须已经进入站台或已登上特快。',
      nextLocation: '国王十字车站',
      forceNextOnlyIfAnchorPresented: true,
      // 进度门：时间 < 9月1日不允许跳（否则 7月31日就直接到了特快，与原著时间线冲突）
      minDateInt: 901,
    ),
    _TransitionNode(
      id: 'opening_station_to_express',
      currentLocationPattern: r'(国王十字|九又四分之三|站台)',
      requireVisited: const [r'对角巷', r'(国王十字|九又四分之三|站台)'],
      requireNotVisited: const [r'(特快|列车|火车)'],
      minTurn: 8,
      maxTurn: 9,
      requireOpeningScene: 'letter',
      minDateInt: 901,
      transitionAnchor: '你推着行李车穿过了 9 又 3/4 站台的柱子，鲜红色的霍格沃茨特快冒着白烟、汽笛轰鸣。级长扯着嗓子喊："新生快上车！马上就要发车了！" 本回合必须完整写出：穿过柱子 → 登上特快 → 找到包厢/遇见同学 → 列车启动发车离开伦敦这几个阶段。',
      nextLocation: '霍格沃茨特快列车',
      forceNextOnlyIfAnchorPresented: true,
    ),
    _TransitionNode(
      id: 'opening_express_to_sorting',
      currentLocationPattern: r'(特快|列车|火车|霍格莫德|车站)',
      requireVisited: const [r'(特快|列车|火车)', r'(国王十字|九又四分之三|站台)'],
      requireNotVisited: const [r'(霍格沃茨大礼堂|大礼堂|城堡内|分院)'],
      requireUngraded: true, // 还没分院
      minTurn: 10,
      maxTurn: 12,
      requireOpeningScene: 'letter',
      minDateInt: 901,
      transitionAnchor: '霍格沃茨特快抵达霍格莫德车站。海格举着巨大的灯笼在站台上喊："一年级新生跟我来！" 你们坐小船渡湖初见霍格沃茨城堡 → 穿过大门来到大礼堂入口 → 麦格教授拿着分院帽和长凳走出来 → 叫到了你的名字 → 分院结果正式公布。本回合剧情必须按顺序把中间过程完整写出来，不能第一句就写"你坐在学院长桌旁"。',
      nextLocation: '霍格沃茨大礼堂',
      forceNextOnlyIfAnchorPresented: true,
    ),
    // ---------- 开学后通用转移链（开局骨架退役后生效，不再只有前12回合保护）----------
    _TransitionNode(
      id: 'hogwarts_hall_to_common_room',
      currentLocationPattern: r'(霍格沃茨大礼堂|大礼堂)',
      requireVisited: const [r'(霍格沃茨|大礼堂|分院)'],
      requireNotVisited: const [r'(公共休息室|宿舍|学院公共)'],
      minTurn: 13,
      maxTurn: 14,
      transitionAnchor: '分院仪式结束，级长带着你们学院的新生穿过走廊与楼梯，说出公共休息室的入口口令（格兰芬多：胖夫人肖像；斯莱特林：石墙；拉文克劳：鹰形门环谜语；赫奇帕奇：厨房旁木桶节奏）→ 你第一次走进学院公共休息室并看到自己的 dorm 床位。',
      nextLocation: '学院公共休息室',
      forceNextOnlyIfAnchorPresented: true,
    ),
    _TransitionNode(
      id: 'first_class_next_day',
      currentLocationPattern: r'(公共休息室|宿舍|学院公共|大礼堂)',
      requireVisited: const [r'(公共休息室|学院公共|宿舍)'],
      requireGraded: true,
      minTurn: 15,
      maxTurn: 17,
      transitionAnchor: '第二天清晨被级长/室友叫醒，你去大礼堂吃了早餐后按照课表前往第一节正式课堂（变形课/魔药课/草药课/魔咒课四选一）。本回合必须写出"起床 → 早餐 → 找到对应教室门口 → 走进去坐到座位上 → 教授开始上课"的完整过程，不能跳帧直接写"教授在讲解魔法"。',
      nextLocation: '霍格沃茨·课堂',
      forceNextOnlyIfAnchorPresented: true,
    ),
  ];

  /// SceneTransitionGraph 主控（替换 _checkOpeningRailroad）
  /// 原则：
  ///   1. 遍历全部 _transitionNodes 节点，找 match 当前地点 + turn 范围 + 所有前置依赖满足 → 触发；
  ///   2. **没有 100% 满足前置依赖（visitedLocations / minDateInt）绝不切 currentLocation**，
  ///      只注入 transitionAnchor（要求 AI 补完过渡叙事），防止"在家 → 直接大礼堂"这类跳场景 bug；
  ///   3. 触发后立刻记录到 narrativeEvent，供后续节点判断"已经在走这条链了"，避免多节点同时注入多条锚点。
  void runSceneTransitionGraph() {
    final p = player;
    if (p == null) return;
    final loc = worldState.currentLocation ?? '';
    final visited = worldState.visitedLocations;
    final t = turnCount;
    final month = worldState.time.month;
    final day = worldState.time.day;
    final dateInt = month * 100 + day;

    String? chosenAnchor;
    String? chosenNextLocation;
    String? chosenId;
    bool allowNextUpdate = false;

    for (final node in _transitionNodes) {
      // 1) 当前地点匹配（开局骨架只对 openingScene=letter 生效）
      if (!RegExp(node.currentLocationPattern, caseSensitive: false).hasMatch(loc)) continue;
      if (node.requireOpeningScene != null && openingScene != node.requireOpeningScene) continue;
      // 2) 已触发过的节点跳过（避免每次重复注入同一条锚点）
      if (worldState.firedAnchorIds.contains(node.id)) continue;
      // 3) turn 范围
      if (t < node.minTurn || t > node.maxTurn) continue;
      // 4) requireGraded / requireUngraded
      if (node.requireGraded && !(p.house?.isNotEmpty ?? false)) continue;
      if (node.requireUngraded && (p.house?.isNotEmpty ?? false)) continue;
      // 5) minDateInt 时间门（保护 7月31不跳特快/分校）
      if (node.minDateInt != null && dateInt < node.minDateInt!) continue;
      // 6) requireVisited 进度门（之前没加进度门直接切大礼堂的 bug 根因）
      bool prereqVisitedOk = node.requireVisited.every(
          (pat) => visited.any((l) => RegExp(pat, caseSensitive: false).hasMatch(l)));
      if (!prereqVisitedOk) continue;
      // 7) requireNotVisited：已经过门过就别再推这条链
      bool notVisitedOk = node.requireNotVisited.every(
          (pat) => !visited.any((l) => RegExp(pat, caseSensitive: false).hasMatch(l)));
      if (!notVisitedOk) continue;

      // OK，命中此节点
      chosenAnchor = node.transitionAnchor;
      chosenId = node.id;
      // 【关键保护】只有 node.forceNextOnlyIfAnchorPresented=false（表示这是"玩家已经在锚点叙事里完成过渡"的节点）
      // 才允许我们直接改 currentLocation。其他情况一律**只注入锚点，不切 location**，
      // 让 _syncLocationFromNarrative 在 AI 把过渡叙事写完后自然同步到 nextLocation。
      allowNextUpdate = !(node.forceNextOnlyIfAnchorPresented ?? true);
      if (allowNextUpdate) {
        chosenNextLocation = node.nextLocation;
      } else {
        chosenNextLocation = null;
      }
      break; // 一次只注入一个节点，避免多锚点叠加导致 prompt 爆掉
    }

    if (chosenAnchor != null && pendingAnchorDirective == null) {
      pendingAnchorDirective = chosenAnchor;
      if (chosenId != null) worldState.firedAnchorIds.add(chosenId);
      notifications.add('🧭 剧情推进：下一阶段衔接已为你安排（节点=$chosenId）');
      worldState.addNarrativeEvent('🧭 SceneGraph: 触发节点 $chosenId（turn=$t loc=$loc）', turn: t);
      debugPrint('🧭 SceneTransitionGraph 命中 id=$chosenId; 切Location=${allowNextUpdate ? chosenNextLocation : "(依赖剧情走完后自动同步)"}');
    }
    if (chosenNextLocation != null && allowNextUpdate) {
      worldState.currentLocation = chosenNextLocation;
      lastTrackedLocation = chosenNextLocation;
      turnsAtSameLocation = 0;
      worldState.visitedLocations.add(chosenNextLocation);
    }
  }

  // ==================== P1-3 T1 未完结事项超期提醒 ====================
  // 给 narrative Prompt 拼注入文本用（在 buildPrompt 里调用）。
  String _buildOpenLoopsStagnationHint() {
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

/// 【宏观通用 M2】SceneTransitionGraph 的单个转移节点。
/// 把"剧情从 A 到 B"抽象为数据：当前地点、前置依赖（visited/时间/事件）、turn 区间、
/// 锚点文案（描述"从 A 到 B 的完整中间过程"，AI 必须把这段完整写出来，不能跳帧）、
/// 下一个地点、以及是否允许跳过过渡叙事直接改 currentLocation（一律默认 true=不允许硬切，除非 AI 已走完过渡叙事）。
class _TransitionNode {
  final String id;
  final String currentLocationPattern;
  final List<String> requireVisited;
  final List<String> requireNotVisited;
  final int minTurn;
  final int maxTurn;
  final int? minDateInt; // 月份*100+日，901=9月1日。null=不限制
  final String? requireOpeningScene; // 'letter' 或 null
  final bool requireGraded;
  final bool requireUngraded;
  final String transitionAnchor; // 必须写入 prompt，让 AI 补完整段过渡
  final String? nextLocation;
  final bool? forceNextOnlyIfAnchorPresented; // true=等 AI 把过渡叙事写完后自然同步 location，不在这硬切

  const _TransitionNode({
    required this.id,
    required this.currentLocationPattern,
    this.requireVisited = const [],
    this.requireNotVisited = const [],
    required this.minTurn,
    required this.maxTurn,
    this.minDateInt,
    this.requireOpeningScene,
    this.requireGraded = false,
    this.requireUngraded = false,
    required this.transitionAnchor,
    this.nextLocation,
    this.forceNextOnlyIfAnchorPresented,
  });
}

/// 封装后的"剧情停滞检测器"。
///
/// 宏观设计要点：
/// - 所有阈值/关键词/钩子都集中在这里，避免 mixin_narrative.dart 里到处 if；
/// - 对外暴露 4 个查询 API：isExempt / thresholdFor / hasUnresolvedHook / buildPromptLine；
/// - 所有 API 都是纯函数（参数 location/narrative/turnCount），不需要持有 GameProvider 引用，
///   因而未来能直接做单测。
class StagnationDetector {
  const StagnationDetector._();
  static const StagnationDetector instance = StagnationDetector._();

  // 【豁免地点】：这些场景本身就是"要多回合演剧情"的，阈值放 6 回合，避免把正在进行的
  // 上课/分院/购魔杖/图书馆查资料/魁地奇训练等硬打断。
  static const List<String> exemptLocationKeywords = [
    '大礼堂',
    '教室',
    '图书馆',
    '对角巷',
    '霍格莫德村',
    '公共休息室',
    '禁林',
    '医疗翼',
    '霍格沃茨·场地',
    '魁地奇',
    '决斗',
  ];

  // 【开局强压地点关键词】：开局家里 2 回合必须出门，防止墨迹
  static const List<String> homeKeywords = [
    '家中', '卧室', '住宅', '庄园', '别墅', '家里', '客厅', '门厅', '书房', '花园',
  ];

  bool isExempt(String location) {
    if (location.isEmpty) return false;
    return exemptLocationKeywords.any((k) => location.contains(k));
  }

  int thresholdFor(String location) {
    if (location.isEmpty) return 2;
    if (homeKeywords.any((k) => location.contains(k))) return 2;
    if (isExempt(location)) return 6;
    return 4;
  }

  bool hasUnresolvedHook(String narrative) {
    if (narrative.isEmpty) return false;
    final tail = narrative.length > 200
        ? narrative.substring(narrative.length - 200)
        : narrative;
    final re = RegExp(
      r'(\.\.\.|……|——|—\s*$)'
      r'|(刚|正要|正准备|突然|就在这时|正在|即将|尚未|还没|没等|未等)'
      r'|(看着你.*(回答|回应|开口)|等你(回答|回应|开口|出招)|点名叫|点了.*的名|注视着你|等你说话)'
      r'|(举起.*魔杖|瞄准|对峙|剑拔弩张|一触即发|准备迎战|严阵以待|蓄势待发)'
      r'|(分院帽.*(碰到|落下|停住|思考)|(考试|测验|仪式|宴会).(正在|进行中|刚刚开始|开始了))'
      r'|(门.*敲响|敲门声|有人敲门|脚步声.*临近|声音从.*传来)',
      caseSensitive: false,
    );
    return re.hasMatch(tail);
  }

  /// 统一输出"停滞强制推进提示"文案（之前散落在 buildPrompt 里）。
  /// return 为空字符串代表不需要强制推进。
  String buildPromptLine({
    required String currentLocation,
    required int turnsAtSameLocation,
    required bool hasUnresolvedHook,
    required int turnCount,
  }) {
    final threshold = thresholdFor(currentLocation);
    if (turnsAtSameLocation < threshold) return '';
    if (hasUnresolvedHook) return '';

    final stuckTurns = turnsAtSameLocation;
    final isExempt_ = isExempt(currentLocation);
    final extraHint = isExempt_
        ? '（注：你所在的「$currentLocation」是重要剧情场景，通常允许$threshold回合停留；现已达到上限，必须在下一阶段自然转换。）'
        : '';
    final earlyGame = (turnCount <= 3 && turnCount >= 1 &&
        (currentLocation.contains('家中') ||
            currentLocation.contains('卧室') ||
            currentLocation.isEmpty));
    String line;
    if (earlyGame) {
      line = '📌 【开局前3回合】：属于「收到信→准备出发」阶段，选项中必须至少包含1个"准备出发/前往九又四分之三站台"的推进型选项，避免玩家一直在家里反复施法徘徊。';
    } else if (hasUnresolvedHook && turnsAtSameLocation >= (threshold - 1)) {
      line = '💡 【剧情进行中】当前叙事结尾有未解决的冲突/悬念，选项优先承接「把当前这个悬念/冲突收尾」的动作；但至少要保证有1个选项带"场景转换趋势"（如"把这件事做完后前往下个地点"），不要所有选项都彻底原地打转。';
    } else {
      line = '【⚠️强制推进指令】玩家已在「$currentLocation」停留 $stuckTurns 回合（该场景允许阈值=$threshold），剧情已停滞！'
          '本回合必须发生场景转换——例如：有人敲门通知该出发、时间到了必须动身前往下一站、'
          '收到猫头鹰信件催促、窗外发生引人注意的事件、被召唤去某处等。$extraHint'
          '严禁继续在「$currentLocation」原地打转、反复施法、反复探索同一现象。'
          '本回合结尾必须让玩家处于「正在前往/即将到达下一场景」的状态。';
    }
    return line + '\n\n';
  }
}
