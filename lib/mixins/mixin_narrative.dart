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
import '../utils/stagnation_detector.dart';
import '../utils/confession_reply.dart';
import '../utils/crash_logger.dart';
import '../providers/game_provider_base.dart';
import '../data/locations.dart';
import '../data/attribute_data.dart';
import '../data/course_data.dart';
import '../data/director_beat_data.dart';
import '../data/foreshadow_data.dart';
import '../data/scar_data.dart';
import '../data/era_data.dart';
import '../data/faculty_data.dart';
import '../data/game_config_rules.dart';
import '../data/narrative_time_rules.dart';
import '../data/rivalry_data.dart';
import '../data/time_cost_rules.dart';
import '../data/wand_data.dart';
import '../data/worldline_data.dart';
import '../data/monthly_event_data.dart';
import '../data/npc_schedule_rules.dart';
import '../data/parallel_data.dart';
import '../prompts/narrative_prompts.dart';
import '../prompts/summary_prompts.dart';
import 'mixin_narrative_continuity.dart';

mixin GameNarrativeMixin on GameProviderBase, GameNarrativeContinuityMixin {
  Future<void> processChoice(GameChoice choice) async {
    if (player == null) return;

    // 并发守卫。UI 侧三处入口是在 build 时把 isLoading 固化进 onTap 的，
    // 而 onTap 要从「可点」变成「不可点」得等下一帧重建——同一帧内连点两下
    // 就会进来两次。后果不是丢一次请求那么简单：turnCount +2、
    // 两个 AI 请求同时在飞、advanceTimeForAction 和 updateNPCsFromAction
    // 各结算两遍（时间/精力/被动好感都翻一番），最后返回慢的那个覆盖
    // currentNarrative，玩家看到剧情倒退。
    if (isLoading) return;

    // 本地指令解析
    var action = choice.action.trim();
    String? causalResult;

    // 因果锚点抉择（见 lib/data/worldline_data.dart）：
    // 唯一一个「先本地结算、再继续走叙事」的入口。先记账（数值 + 痕迹），
    // 然后把选项自带的那段具体行动当成玩家输入发给 AI。
    // 少了后半步，玩家点完「上塔去」只看到一段后果文本，
    // 塔上究竟发生了什么永远没人写。
    final causal = parseCausalCommand(action);
    final faculty = parseFacultyCommand(action);
    if (causal != null) {
      causalResult =
          resolveCausalChoice(causal.anchor.anchorId, causal.option.id);
      action = causal.option.action;
    } else if (faculty != null) {
      // 留校邀请同上：先结算，再把"我留下来了"发给 AI 续写毕业后的第一天。
      causalResult = resolveFacultyOffer(faculty);
      action = facultyActionLineFor(faculty, player?.facultySubject ?? '魔咒学');
    } else if (action.startsWith('/')) {
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
        unawaited(autoSave());
        return;
      }
    }

    // 用户自由文本在进入 Prompt 前做注入防御净化
    final safeAction = PromptSanitizer.sanitizeAction(action);

    // 恋爱链路接线：玩家在选择「接受/婉拒表白」选项时直接结算，
    // 避免表白剧情永远悬置（此前 resolveConfession 无任何调用方）。
    final love = player!.loveState;
    if (love.awaitingConfession && love.consideringNpcName != null) {
      // 用语义解析代替子串匹配：「不接受」「拒绝接受」都含「接受」，
      // 简单 contains('接受') 会把拒绝当成答应，恋爱状态机直接推反。
      final reply = parseConfessionReply(safeAction);
      if (reply != null) {
        resolveConfession(reply, love.consideringNpcName!);
      }
      // 无法判断表态时不改动任何状态，交给后续 AI 叙事按玩家原文推进，
      // 避免 awaitingConfession 悬挂期间被无关文本误结算。
    }

    if (router == null || !router!.hasNarrativeService) return;

    // 提交真实行动时关闭指令面板；但因果抉择与留校答复的后果面板要留着，
    // 玩家得看见变动率跳了多少、或者自己到底签了什么。
    commandResult = causalResult;
    error = null; // 新一轮开始前清掉上一次的失败提示
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

        // ========== 硬设定：在任校长 / 杖芯 / 当前可达区域 ==========
        // 这三样以前都写在数据表里却没人读：
        //  - eraHeadmaster 零引用 → 开学宴的致辞者在 1892 年还是邓布利多
        //    （那年他本人是 11 岁的新生）；
        //  - wandCoreTraits 零引用 → 选什么杖芯对数值和叙事都没影响；
        //  - MapRegionDef.unlockCondition 只当文案打印 →
        //    写着「高年级开放」的禁林，一年级新生照样一个人走进去。
        final settingLine = <String>[
          '校长：${headmasterLineForEra(eraDefByEra(appProvider.era).eraKey)}',
          if (wandCoreTraitLine(wandById(p.wandId ?? '')?.core).isNotEmpty)
            wandCoreTraitLine(wandById(p.wandId ?? '')?.core),
        ].join('｜');
        contextBuffer.writeln('【本局硬设定】$settingLine');

        // 政治立场原先只在开局的 system prompt 里注入过一次。
        // LLM 记不住二十回合前的设定，中期立场会漂：开局定的「纯血至上」，
        // 二十回合后开始跟麻瓜出身的同学称兄道弟，玩家会觉得这人设是假的。
        // 每回合重述一次，成本一行。
        final stance = p.politicalTendency?.trim() ?? '';
        if (stance.isNotEmpty) {
          contextBuffer.writeln(
            '【政治立场】$stance（主角对纯血论、麻瓜出身、混血的态度；'
            'NPC 的台词与玩家可选的做法都需贴合此立场，'
            '不要因为剧情一时温情就软化或反转）',
          );
        }

        final isWeekend =
            worldState.time.weekday == 0 || worldState.time.weekday == 6;
        final lockedNow =
            lockedRegionsFor(grade: p.grade, isWeekend: isWeekend);
        if (lockedNow.isNotEmpty) {
          contextBuffer.writeln(
              '【当前无法进入的区域】${lockedNow.map((r) => '${r.name}（${r.unlockCondition ?? '未开放'}）').join('、')}'
              ' —— 玩家现在到不了这些地方，不要安排他独自前往；'
              '确有需要时必须有教授带队或给出明确的违规代价。');
        }
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
      final loopsHint = buildOpenLoopsStagnationHint();
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
        // 以前这里是「结构化事实少于 30 条才注入，否则整段不注入」。
        // 而 t0 数的是**未截断**的 importance≥4 事实：开局 10 条，
        // 每 15 回合一次摘要、每次最多 10 条，三次摘要后就稳稳超过 30，
        // 于是从中期开始 narrativeSummary 永久不再进入 prompt——
        // 摘要任务照样每 15 回合跑一次，结果却从来没人读。
        // 整段剧情脉络（谁跟谁好上了、结了什么怨、许过什么诺）只剩碎片。
        //
        // 改成按量给：事实越多，摘要给得越短，但永远不归零。
        final budget = structuredCount < 30
            ? 600
            : structuredCount < 60
                ? 400
                : 250;
        final trimmedSummary = narrativeSummary.length > budget
            ? '${narrativeSummary.substring(0, budget)}…'
            : narrativeSummary;
        // 强约束：只当"关系和转折"参考，严格禁止基于此生成当前回合选项/场景
        contextBuffer.write('【历史背景（仅供参考，严禁基于此生成当前回合的选项与场景）】\n$trimmedSummary\n\n');
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
          final k = e.replaceAll(_anchorIconPrefix, '').trim();
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
          final k = e.replaceAll(_anchorIconPrefix, '').trim();
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
      final curLoc = worldState.currentLocation ?? '当前地点';
      final threshold = stagnationThresholdFor(curLoc);
      final hasHook = narrativeHasUnresolvedHook(currentNarrative);
      // 判定统一走 StagnationDetector.evaluate，措辞按叙事 AI 的口径组织。
      // 此前这里只认「强制」一档，「开局」与「剧情进行中」两档在叙事端永远发不出去。
      final level = _stagnation.evaluate(
        currentLocation: curLoc,
        turnsAtSameLocation: turnsAtSameLocation,
        hasUnresolvedHook: hasHook,
        turnCount: turnCount,
      );
      final stagnationLine = switch (level) {
        StagnationLevel.forced =>
          '【⚠️强制推进指令】玩家已在「$curLoc」停留 $turnsAtSameLocation 回合（该场景允许阈值=$threshold），剧情已停滞！'
              '本回合必须发生场景转换——例如：有人敲门通知该出发、时间到了必须动身前往下一站、'
              '收到猫头鹰信件催促、窗外发生引人注意的事件、被召唤去某处等。'
              '${_stagnation.exemptHint(curLoc)}'
              '严禁继续在「$curLoc」原地打转、反复施法、反复探索同一现象。'
              '本回合结尾必须让玩家处于「正在前往/即将到达下一场景」的状态。\n\n',
        StagnationLevel.earlyGame =>
          '📌 【开局阶段】现在是「收到信 → 准备出发」这一段，本回合叙事请把玩家推向离家：'
              '收拾行李、与家人道别、动身前往对角巷采购入学用品（车站/九又四分之三站台要等 9 月 1 日开学当天才去）。'
              '不要让剧情继续停在$curLoc 原地打转。\n\n',
        StagnationLevel.inProgress =>
          '💡 【剧情进行中】上一回合收尾留有未解决的冲突或悬念，本回合优先把它收掉；'
              '收尾之后请带出场景转换的趋势（例如"做完这件事便动身前往下一处"），'
              '不要整回合停在「$curLoc」不动。\n\n',
        StagnationLevel.none => '',
      };

      // 导演指令：prompt 里塞的全是"状态 + 规则 + 上下文"，
      // 唯独没说这一回合要干嘛，于是 AI 每回合平均用力，一整局读下来是平的。
      // 三回合一个节奏单元（推进 → 日常 → 转折），转折至少每三回合来一次。
      final directorLine =
          directorLineFor(directorBeatFor(turn: turnCount, hasUnresolvedHook: hasHook));

      // 命运时刻：这一回合要把抉择摆到玩家面前，但不能替他做决定。
      // AI 一旦自己写"你冲了上去"或者"你转过身"，玩家点什么都没意义了。
      final pendingCausal = pendingCausalAnchorId == null
          ? null
          : causalAnchorFor(pendingCausalAnchorId!);
      final causalLine = pendingCausal != null &&
              !worldState.causalChoices.containsKey(pendingCausal.anchorId)
          ? '【命运时刻·${pendingCausal.title}】\n'
              '${pendingCausal.setup}\n'
              '本回合的叙事必须停在这个抉择的当口：把上面这个情境写出来，'
              '一直写到"要不要动手"的那一瞬间为止。'
              '严禁替玩家做出选择——不要写他冲上去了，也不要写他转身走了；'
              '不要给出倾向，不要预写后果，把决定权原样留在那一秒。\n\n'
          : '';

      return '''【世界上下文】
  $context

  ${statusTag.isNotEmpty ? '【状态】$statusTag\n' : ''}
  【当前场景】${worldState.timestamp}｜${worldState.currentLocation ?? '未知'}
  ${timeBudgetPromptLine(resolveActionCost(safeAction))}
  $sceneInfo
  ${buildContinuityBridgePromptLine()}
  $stagnationLine$anchorLine$causalLine$directorLine
  ${extra.isNotEmpty ? extra + '\n' : ''}【玩家行动】
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
      bool usedFallbackNarrative = false; // 走了本地兜底叙事 → 不再应用 AI 副作用
      String? finalResponseText; // 最终采纳的原始响应文本（供副作用解析）
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
        // ❗applySideEffects: false —— 重试循环内绝不落库好感/声望/分院，
        // 否则被打回的那次剧情的副作用不会回滚，一次行动会被结算多次。
        // 副作用统一在循环结束后对最终采纳的 response 执行一次。
        finalResponseText = response;
        final parseOk = parseNarrativeOnly(response, applySideEffects: false);
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
            // 先保存当前已经提取好的好感度，避免被覆盖清空
            // ❗为什么：bridged 已经移除了好感区块（来自第一次 parseNarrativeOnly）
            // 重新解析时没有原始好感区块，会导致 lastAffectionSections 被清空
            final savedAffectionSections = List<String>.from(lastAffectionSections);
            currentNarrative = bridged;
            // 重新跑 parseNarrativeOnly，但只重新解析头部位置/时间戳提取，不覆盖好感度
            // 因为好感变化区块在原始完整响应中已经提取过了
            // （applySideEffects: false —— 桥接后的正文已无好感区块，
            //  再跑一次副作用会让被动好感被重复结算一遍）
            parseNarrativeOnly(currentNarrative, applySideEffects: false);
            // 如果重新解析没有提取到新的好感度（本来就没有），恢复保存的好感度
            if (lastAffectionSections.isEmpty && savedAffectionSections.isNotEmpty) {
              lastAffectionSections = savedAffectionSections;
            }
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
          // ❗loadingStage 是玩家能看到的文案，不能出现"违规/节点/重试"这类
          // 内部术语——一句"剧情N处违规，重试中"能瞬间把人拽出剧情。
          loadingStage = narrativeParseInvalid
              ? '正在重新组织剧情...'
              : '剧情细节需要再打磨，正在重写...';
          notifyListeners();
          continue;
        }

        // ====== 重试全部用完还是 BUG-H？ → 直接走本地兜底叙事（保证不是选项） ======
        if (narrativeParseInvalid && retriesLeft == 0) {
          debugPrint('❌ [BUG-H] 2次重试后仍返回选项，切换为 generateFallbackNarrative() 本地兜底叙事');
          currentNarrative = generateFallbackNarrative();
          usedFallbackNarrative = true;
          // 兜底叙事是 Dart 代码生成的，不会夹带选项，也没有好感度区块
          // 所以不用再跑 parseNarrativeOnly，也不应用任何 AI 副作用，
          // 但要跑一遍地点同步等后续流程
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

      // ====== 叙事定稿：副作用此时才落库，且整回合只落一次 ======
      // 重试循环内被驳回的 response 不再污染好感度/声望/分院状态。
      if (!usedFallbackNarrative) {
        applyNarrativeSideEffects(finalResponseText);
      }

      // ====== 每回合周期性结算（原先只挂在 parseResponse 里 = 只在开局跑一次）======
      // parseResponse 的唯一调用点是 generateOpeningScene()，正常回合走的是
      // parseNarrativeOnly + applyNarrativeSideEffects，那边从来不调这些检查，
      // 于是「NPC 主动表白」「世界线变动率增长」两套系统在整局游戏里都是死的。
      // 这里改在每回合叙事定稿后执行，且必须早于选项生成：
      // checkNPCConfessions 会改写 currentNarrative 并给出「接受/婉拒」专属选项，
      // 被 AI 的 4 个通用选项覆盖掉的话，玩家就看不到对方面红耳赤地站在面前了。
      final bool confessedThisTurn = _maybeTriggerConfession();
      _tickWorldLineDeviation();

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
      final pendingCausal = pendingCausalAnchorId == null
          ? null
          : causalAnchorFor(pendingCausalAnchorId!);
      final causalDecided = pendingCausal != null &&
          worldState.causalChoices.containsKey(pendingCausal.anchorId);
      if (confessedThisTurn) {
        // 表白已就位：checkNPCConfessions 内部写入了专属的「接受/婉拒」两个选项，
        // 此时再让 AI 生成 4 个通用选项会把这个抉择冲掉。
        loadingStage = '';
        notifyListeners();
      } else if (pendingFacultyOffer) {
        // 留校邀请：毕业后唯一一个"接下来的人生往哪走"的分岔。
        // 同样不让 AI 的通用选项冲掉——这是七年攒出来的东西换来的一个问句。
        choices = const [
          GameChoice(text: '留下来教书', action: '/教职 接受'),
          GameChoice(text: '婉拒，离校', action: '/教职 婉拒'),
        ];
        loadingStage = '';
        notifyListeners();
      } else if (pendingCausal != null && !causalDecided) {
        // 命运时刻：选项只给这几个分支，AI 生成的通用选项全部让路。
        // 七年里能改写原著的机会一只手数得过来，
        // 混进「仔细查看四周」这种选项会把它稀释成一次普通的场景交互。
        choices = pendingCausal.options
            .map((o) => GameChoice(
                  text: o.text,
                  action: '/抉择 ${pendingCausal.anchorId} ${o.id}',
                ))
            .toList(growable: false);
        loadingStage = '';
        notifyListeners();
      } else {
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
      }
      // BUG-N 追踪：记录最终设置到Provider的选项
      // processChoice最终选项日志已移除
      // 立即通知 UI 刷新选项，确保用户看到最新选项
      notifyListeners();

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
      unawaited(autoSave());
    } catch (e) {
      // AI 全部提供商不可用时的本地兜底：给出过渡剧情与选项，保证游戏不卡死
      debugPrint('❌ 剧情生成失败，启用本地兜底叙事: $e');
      currentNarrative = generateFallbackNarrative();
      // 2026-08-28：统一使用 buildFallbackChoices（基于剧情末尾800字做承接式兜底）
      // 旧代码用 generateContextualFallbackChoices → 返回静态位置MAP选项（"去教室上课"等）
      // → 与当前剧情末尾脱节，玩家点击后下回合叙事完全跳场景
      choices = buildFallbackChoices(currentNarrative);
      appendRecentTurn(currentNarrative);
      // 关键：必须写 error。旧实现只往 notifications 里塞了一条，
      // 而 UI 顶部错误条监听的是 error 字段 → 玩家看到的只是"剧情突然变味了"，
      // 完全不知道是 AI 挂了，会以为是游戏内容就这样。
      error = 'AI 服务暂时不可用，已切换为本地过渡剧情。可稍后重试刚才的行动。';
      notifications.add('⚠️ AI 服务暂时不可用，已切换为本地过渡剧情，稍后可重试行动');
      loadingStage = '';
      isLoading = false;
      notifyListeners();
      unawaited(autoSave());
      unawaited(CrashLogger.instance.record(
        e,
        StackTrace.current,
        screen: 'processChoice',
        extra: 'action=$action, turn=$turnCount',
      ));
    }
  }

  /// 重试上一次失败的行动。
  ///
  /// AI 调用失败时游戏会切本地兜底剧情，玩家点「重试」即可用同一句话
  /// 重新走一遍正式流程（而不是手动把原话再敲一遍）。
  /// 失败前的兜底叙事会先撤掉，避免重试成功后新旧正文叠在一起。
  Future<void> retryLastAction() async {
    final action = lastPlayerAction.trim();
    if (action.isEmpty) return;
    error = null;
    await processChoice(GameChoice(text: action, action: action));
  }

  /// 手动关掉错误提示条（玩家点 ✕ 时用，不重跑任何逻辑）
  void clearError() {
    error = null;
    notifyListeners();
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
    final limit = turnCount <= 40
        ? 800
        : (turnCount <= 100 ? 1500 : 2400);
    final relationSnapshot = buildRelationshipSnapshot();

    final prompt = buildSummaryPrompt(
      limit: limit,
      previousSummary: narrativeSummary,
      newChunk: chunk,
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
      // 注意：这里不再清空 pendingSummary —— 待摘要内容在请求发出前就已取走，
      // 请求在飞期间新积累的回合仍留在缓冲里，等待下一次摘要。
    } catch (e) {
      debugPrint('❌ 摘要生成失败: $e');
      // 失败则把内容还回缓冲头部，下回合重试，避免剧情永久丢失
      pendingSummary = chunk + pendingSummary;
    } finally {
      isSummarizing = false;
    }
  }

  /// 给自动提取的事实打重要性分。
  ///
  /// 这个分数决定它在 [LongTermMemory.maxKeyFacts]（100 条）容量溢出时的存亡。
  /// 一律给 7 分的话，「你杀了一个人」和「今天魔药课拿了优秀」权重相同，
  /// 而前者到毕业那天都还在影响剧情，后者一周后就没人提了。
  ///
  /// 9 分及以上在淘汰时被永久豁免（见 addKeyFact），所以这里只对真正
  /// 不可逆、改写人生走向的事实给 9 分。
  int importanceForFact(String fact) {
    // 不可逆的重大变故 / 关系质变：永不淘汰
    const critical = [
      '死了', '死亡', '死去', '杀害', '杀死', '谋杀', '遇害', '殉职', '阵亡',
      '复仇', '血债', '命债',
      '订婚', '结婚', '婚礼', '婚约', '离婚', '分手', '决裂',
      '背叛', '出卖', '告密', '倒戈',
      '食死徒', '凤凰社', '加入', '宣誓', '誓言', '立誓', '效忠',
      '通缉', '逃亡', '除名', '开除', '驱逐', '流放', '阿兹卡班',
      '怀孕', '分娩', '出生', '孩子', '子女',
      '不可饶恕', '魂器', '黑魔标记', '继承人', '遗书', '遗嘱',
    ];
    // 有分量但仍在剧情中层：可以被更早的同类挤掉
    const notable = [
      '表白', '交往', '恋人', '暧昧', '亲吻', '初吻',
      '决斗', '重伤', '住院', '中毒', '诅咒',
      '魁地奇', '队长', '冠军', '学院杯',
      '学会', '掌握', '精通', '毕业', '留级', '跳级',
      '抄写', '禁闭', '扣分', '嘉奖', '表彰',
      '开店', '买下', '继承', '破产',
      '搬家', '转学', '退学', '复学',
      '发现了', '得知', '秘密', '真相',
    ];
    for (final w in critical) {
      if (fact.contains(w)) return 9;
    }
    for (final w in notable) {
      if (fact.contains(w)) return 7;
    }
    return 5; // 日常流水，容量吃紧时最先被淘汰
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
          // 以前一律给 7 分，导致 importance 这个字段在淘汰时完全失去区分度：
          // 100 条容量溢出时按分数排等于按插入顺序排，最早发生的事先被冲掉。
          // 于是第 200 回合 AI 会忘了你早已订婚、早已结仇、早已立下过誓言。
          importance: importanceForFact(fact),
          timestamp: ts,
          category: 'auto_extracted',
        ));
      }
      if (facts.isNotEmpty) {
        // 记忆提取日志已移除（核心事实）
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
            openedTurn: turnCount,
          ));
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
          .split(RegExp(r'[;；\n]'))
          .map((l) => l.replaceAll(RegExp(r'^[\s•·\-\d]+'), '').trim())
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

  /// 从摘要中剥离结构化块（已写入 LongTermMemory，不需要在 T4 中重复）
  String _stripStructuredBlocks(String text) {
    var cleaned = text;
    // 剥离【关系】【伏笔】【了结】【核心事实】【世界事件】块
    cleaned = cleaned.replaceAll(RegExp(r'【关系】[\s\S]*?(?=【|$)'), '');
    cleaned = cleaned.replaceAll(RegExp(r'【伏笔】[\s\S]*?(?=【|$)'), '');
    cleaned = cleaned.replaceAll(RegExp(r'【了结】[\s\S]*?(?=【|$)'), '');
    cleaned = cleaned.replaceAll(RegExp(r'【核心事实】[\s\S]*?(?=【|$)'), '');
    cleaned = cleaned.replaceAll(RegExp(r'【世界事件】[\s\S]*?(?=【|$)'), '');
    return cleaned.trim();
  }

  /// 认出并关掉一条伏笔。
  ///
  /// 匹配不上就**安静地什么都不做**——AI 有时候会写一些我们从没记过的事，
  /// 那不是错误，只是这一条没法挂到某条伏笔上。硬凑一个上去，
  /// 玩家会看到一件还没办的事被宣布了结。
  void _closeLoopIfMatched(String closedText, String ts) {
    final match =
        pickLoopToClose(closedText, memory.openLoops, currentTurn: turnCount);
    if (match == null) return;

    final l = match.loop;
    final held = l.openedTurn > 0 ? turnCount - l.openedTurn : 0;

    memory = memory.addOrUpdateOpenLoop(OpenLoopRecord(
      id: l.id,
      description: l.description,
      status: 'done',
      importance: l.importance,
      openedAt: l.openedAt,
      closedAt: ts,
      npcIds: l.npcIds,
      loopType: l.loopType,
      openedTurn: l.openedTurn,
    ));

    // 回响一：一条长期记忆。
    // 给 7 分而不是沿用伏笔自己的 6 分，是为了让它挤得过日常琐事——
    // 100 条容量溢出时按分数淘汰，伏笔了结该留下来。
    memory = memory.addKeyFact(KeyFactRecord(
      id: 'loop_closed_${l.id}',
      fact: loopClosedFact(l.description, l.loopType),
      importance: l.importance >= 8 ? 9 : 7,
      timestamp: ts,
      category: 'loop_closed',
      npcIds: l.npcIds,
    ));

    // 回响二：一句通知，带上这件事悬了多久
    notifications.add(loopClosedNotice(l.description, l.loopType, held));
    worldState.addNarrativeEvent(
        '🔗 了结${loopTypeLabel(l.loopType)}：${l.description}', turn: turnCount);

    // 回响三：一点声望与好感，按这件事的性质给
    final reward = rewardForLoop(l.loopType);
    final p = player;
    if (p != null) {
      for (final e in reward.reputation.entries) {
        p.playerReputation.add(e.key, e.value);
      }
    }
    if (reward.npcAffection > 0) {
      for (final id in l.npcIds) {
        updateNpcAffection(id, reward.npcAffection,
            reason: '了结了${loopTypeLabel(l.loopType)}');
      }
    }
    debugPrint(
        '🔗 伏笔了结 id=${l.id} score=${match.score.toStringAsFixed(2)} 悬了$held回合');
  }

  /// 把悬太久又没分量的伏笔放下。
  ///
  /// 玩家显然已经放弃了这些事，AI 也再没提起过；继续挂在 T1 里
  /// 只会挤掉真正重要的待办。这里是静默处理——
  /// 弹一句「你放弃了 XXX」纯属给人添堵，那是玩家用脚投的票。
  void _dropStaleLoops(String ts) {
    final drops = staleLoopsToDrop(memory.openLoops, turnCount);
    for (final l in drops) {
      memory = memory.addOrUpdateOpenLoop(OpenLoopRecord(
        id: l.id,
        description: l.description,
        status: 'dropped',
        importance: l.importance,
        openedAt: l.openedAt,
        closedAt: ts,
        npcIds: l.npcIds,
        loopType: l.loopType,
        openedTurn: l.openedTurn,
      ));
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
      // 原来这里筛的是 const {'智慧','魔力','勤奋'}——属性表里根本没有这三个
      // 名字，过滤结果恒为空，【学业】上下文从来没注入过。改成按课程会提升的
      // 属性筛（kStudyAttributeKeys，与 course_data 对齐）。
      final study = p.attributes.entries
          .where((e) => kStudyAttributeKeys.contains(e.key))
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

    // 宿敌单独成段。行为指令比较长，塞进【在场】里会把那一行撑爆；
    // 而且只有真有宿敌站在面前时才值得花这份 token，
    // 没有仇人的时候这几行一个字都不会出现。
    final today = ws.time.absoluteDayIndex;
    for (final r in npcsHere) {
      if (!r.introduced || !r.hasGrudge) continue;
      final tier = r.rivalryTier(today);
      if (tier == RivalryTier.none) continue;
      parts.add('【宿敌·${rivalryBadgeFor(tier)} ${r.name}】'
          '${rivalryDirectiveFor(tier, r.name, r.rivalryReason())}');
    }
    for (final r in npcsHere) {
      if (!r.introduced || !r.formerRival) continue;
      parts.add('【旧怨已了·${r.name}】${formerRivalLine(r.name)}');
    }

    // 【意外】他不该在这儿。
    // 作息例外让某些人出现在反常的地方，可如果 AI 只看见
    // "斯内普：55"这一行，写出来的就只是"斯内普在教室里"。
    // 有意思的不是他在哪儿，是他在这儿干什么——那句 reason 才是
    // 这段戏的引子（他在熬一种不能在地窖里熬的东西，
    // 被撞见时先做的动作是用身体挡住坩埚）。
    //
    // 跟【宿敌】同理：只有真有人撞上了才花这份 token，
    // 大多数回合这一段一个字都不会出现。
    for (final n in npcsHere) {
      if (!n.introduced) continue;
      final ex = scheduleExceptionFor(
        n.id,
        ws.time.hour,
        weekday: ws.time.weekday,
      );
      if (ex == null) continue;
      parts.add('【意外·${n.name}】他此刻不该在这儿：${ex.reason}'
          '（这是本回合免费送上门的一个场面，可以正经写一段，'
          '也可以只是路过时看见一眼）');
    }

    // 宿敌不一定正站在你面前。只让 AI 看见"眼前这个人恨你"，
    // 那"他在走廊尽头堵你""你摔倒时旁边有人笑"这类戏永远写不出来——
    // 因为 AI 压根不知道城堡另一头有这么一号人。
    // 只收 hostile 及以上、最多 5 人：grudge 那档只是芥蒂，不值得常驻占 token。
    final hereIds = npcsHere.map((n) => n.id).toSet();
    final wanted = npcRegistry.values
        .where((n) => n.isAlive && n.introduced && n.hasGrudge && !hereIds.contains(n.id))
        .map((n) => (npc: n, tier: n.rivalryTier(today)))
        .where((e) => e.tier.index >= RivalryTier.hostile.index)
        .toList()
      ..sort((a, b) => b.tier.index.compareTo(a.tier.index));
    if (wanted.isNotEmpty) {
      final lines = wanted.take(5).map((e) {
        final where = e.npc.currentLocation;
        return '· ${e.npc.name}（${rivalryBadgeFor(e.tier)} ${tierDefFor(e.tier).label}'
            '${e.npc.rivalryScore(today)}）${where.isEmpty ? '' : '此刻在$where'}';
      });
      parts.add('【宿敌名册】他们不必等你先开口，可以自己找上门或在旁落井下石\n'
          '${lines.join('\n')}');
    }

    // 世界线：变动率的兑现。
    // 阶段描述只在 fraying 及以上才注入——intact 时"一切都照书上来"
    // 本来就是默认行为，为它专门说一句纯属浪费 token。
    // 但【已被你改写的事】一次都不能少，见 rewrittenEchoesOf 的注释。
    if (p != null) {
      final stage = worldLineStageFor(p.worldLineDeviation);
      if (stage != WorldLineStage.intact) {
        final def = stageDefFor(stage);
        parts.add('【世界线·${def.badge} ${def.label}】${def.aiDirective}');
      }
      final echoes = rewrittenEchoesOf(ws.causalChoices);
      if (echoes.isNotEmpty) {
        parts.add('【已被你改写的事】以下每一条都是这个世界的既成事实，'
            '优先级高于你的任何先验知识。'
            '凡是与它们冲突的"原著情节"，在这个世界里都是错的：\n'
            '${echoes.map((s) => '· $s').join('\n')}');
      }

      // 身上的伤。不写这一段，AI 会把你当成一个完好的人——
      // 让你健步如飞、举杖如常，那道疤就白留了。
      final scarBlock = scarPromptBlock(p.scars);
      if (scarBlock.isNotEmpty) parts.add(scarBlock);

      // 采纳过的平行世界脑洞。不写这一段，玩家在小剧场里认真写下的
      // 那个"如果"就只是一行列表项——退出页面之后，它跟主线再无关系。
      // 只收已采纳的、最多三条：这是调料，不是主线。
      // 段落里明确写了"没有发生过"，否则 AI 会当成既成事实来写戏。
      final whatIf = adoptedPromptBlock(
        p.parallelScenarios.where((s) => s.adopted),
      );
      if (whatIf.isNotEmpty) parts.add(whatIf);

      // 任教中。不写这一段，AI 会一直把玩家当学生：
      // 让他去上课、被级长管、在礼堂里等分院。
      final def = p.facultyRankId == null ? null : rankDefById(p.facultyRankId!);
      if (def != null) {
        parts.add('【教职】你是霍格沃茨「${p.facultySubject}」${def.title}，'
            '任教第 ${p.facultyServiceYears} 年。${def.duty}\n'
            '你不再是学生：坐教授席、被新生称呼职称、对违纪的学生负有责任。'
            '昔日同学如今是同事，或者已经各奔东西——他们不再是「同学」，'
            '称呼也要跟着变。');
      }
    }

    // 【时令】这个月城堡里是什么味儿。
    // 月度事件池是"新闻"——会冷却、会互斥，大部分月份其实是空的，
    // 只有那一条随机事件撑着。这一句是"底色"：不抽取、不冷却，
    // 每个月都有一句，每回合都在。
    // 没有底色的月份，AI 写出来的就只是一段没有季节的场景——
    // 五月和十一月在他的笔下没有任何区别。
    final atmosphere = atmosphereForMonth(ws.time.month);
    if (atmosphere.isNotEmpty) parts.add('【时令】$atmosphere');

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
  // 旧 API（stagnationThresholdFor / narrativeHasUnresolvedHook）
  // 保持对外不变：内部委托给 StagnationDetector，不会破坏 GameProviderBase 的 abstract 签名。
  // isLocationExemptFromStagnation 已移除：判定收敛进 evaluate 后没有任何调用者。
  // ============================================================

  static const StagnationDetector _stagnation = StagnationDetector.instance;

  int stagnationThresholdFor(String location) =>
      _stagnation.thresholdFor(location);
  bool narrativeHasUnresolvedHook(String narrative) =>
      _stagnation.hasUnresolvedHook(narrative);

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

  // 地点表在 lib/data/locations.dart（纯数据，测试和事件锚点校验都要用），
  // 归一化统一走 resolveLocationName，这里不再自己遍历别名。

  /// 每回合尝试触发一次 NPC 主动表白，返回本回合是否真的表白了。
  ///
  /// 为什么单独抽成方法：checkNPCConfessions 原本只被 parseResponse 调用，
  /// 而 parseResponse 只在开局 generateOpeningScene 里跑一次（那时 turnCount==0，
  /// 连 `turnCount > 0` 的门槛都过不去）。正常回合走 parseNarrativeOnly +
  /// applyNarrativeSideEffects，那条链上根本没有它——也就是说，好感 85+、暧昧、
  /// 浪漫事件 2 次以上、暧昧满两周，四个条件全满足也永远不会有人来表白。
  /// 恋爱系统的高潮（以及 CG-CF-001/002/003、first_confession、in_love 成就、
  /// 整张 loveReputationEffects 声望表）全是死的。
  bool _maybeTriggerConfession() {
    final p = player;
    if (p == null) return false;
    // 已经有心事未了 / 正在等答复 / 名草有主，都不该再插一脚
    if (p.loveState.awaitingConfession) return false;
    if (p.loveState.status != '单身') return false;

    // 沿用原先的节奏：每 5 回合查一次，或玩家这回合明显在跟人互动。
    // 不每回合都查，一是省算力，二是表白来得太密会掉价。
    final interactive = lastPlayerAction.contains(RegExp(
        r'(与|和|跟|找|邀|问|对话|聊天|约会|见面|散步|陪|一起|独处|深入|表白|感情|心动)'));
    if (turnCount > 0 && (turnCount % 5 != 0) && !interactive) return false;

    final before = p.loveState.awaitingConfession;
    checkNPCConfessions();
    return !before && p.loveState.awaitingConfession;
  }

  /// 每 10 回合递增世界线变动率。
  ///
  /// 同样是从 parseResponse 里救出来的：原先只在开局那一回合 +0.005，
  /// 之后整局恒为 0.5%，world_changer 成就（≥10%）永远拿不到，
  /// 月度演化的「偏离加成」分支也永远进不去。
  void _tickWorldLineDeviation() {
    // 按游戏内天数走，不按回合数。原因见 kDeviationTickIntervalDays 的注释。
    final bucket =
        worldState.time.absoluteDayIndex ~/ kDeviationTickIntervalDays;
    if (bucket == lastDeviationTickBucket) return;
    final first = lastDeviationTickBucket < 0;
    lastDeviationTickBucket = bucket;
    // 开局那一桶不算：玩家还没来得及做任何事，不该凭空先偏一点。
    if (first || bucket == 0) return;
    incrementWorldLineDeviation(
        deviationDriftFor(player?.worldLineDeviation ?? 0.0));
  }

  /// 从叙事开头的【地点】**结构化标签**同步玩家所在地点到 worldState.currentLocation。
  ///
  /// 重要：本函数**只读取结构化【地点】标签**，绝不从叙事正文里用「抵达动词」正则
  /// 反推地点。正文里的「踏入/来到/走进」一律只当描写，不再改写硬状态——
  /// 否则「从明天踏入九又四分之三站台」这类未来式描写会把人当晚硬切去车站，
  /// 剧情时间与日历对不上（详见 commit 时间线错乱修复）。
  ///
  /// 地点变更的两条权威来源：
  ///   ① 本函数的【地点】标签（AI 标准输出格式，最准确）；
  ///   ② 场景图 runSceneTransitionGraph（强制/大节点过渡）。
  /// 二者之外的任何正文文本都不再是地点状态的输入。
  void _syncLocationFromNarrative(String narrative) {
    if (narrative.isEmpty) return;
    final cur = worldState.currentLocation ?? '';

    // ---- 只解析开头的【地点】标签（AI 标准输出格式，最准确）----
    String? detected;
    final locationTagMatch = RegExp(
      r'【地点】\s*([^\n]+)',
      dotAll: false,
    ).firstMatch(narrative);
    if (locationTagMatch != null && locationTagMatch.group(1) != null) {
      final tag = locationTagMatch.group(1)!.trim();
      // 统一走 resolveLocationName（lib/data/locations.dart）。
      detected = resolveLocationName(tag);
      // 如果标签没匹配到已知别名，但标签里提到了具体位置，
      // 检查是否属于"家中"大类（卧室/花园/书房/密室/起居室 都算家中）
      if (detected == null) {
        if (RegExp(r'(家中|家里|住宅|庄园|别墅|卧室|书房|花园|密室|走廊|客厅|门厅)', caseSensitive: false).hasMatch(tag)) {
          detected = '家中·卧室';
        }
      }
    }

    if (detected == null) return; // 【地点】标签未识别到任何已知地点，不改

    // 时间门：季节锁定的地点（车站/站台/特快/大礼堂）只在 9 月 1 日及之后才允许"抵达"，
    // 与 runSceneTransitionGraph 的 minDateInt 对齐。日期未到就保留上一地点，
    // 等场景图在日期到了之后再走正常过渡。
    final dateInt = worldState.time.month * 100 + worldState.time.day;
    final required = _seasonLockedMinDate.entries
        .where((e) => detected!.contains(e.key))
        .map((e) => e.value)
        .fold<int?>(null, (p, v) => p == null ? v : (v > p ? v : p));
    if (required != null && dateInt < required) {
      worldState.addNarrativeEvent(
        '⏱ 地点同步被时间门拦截：$detected（需 ${required ~/ 100}月${required % 100}日，'
        '当前 ${worldState.time.month}月${worldState.time.day}日）',
        turn: turnCount,
      );
      return; // 季节未到：保留上一地点
    }

    // 若检测到的地点与当前不同，则更新并清零停滞计数
    if (detected != cur) {
      worldState.currentLocation = detected;
      lastTrackedLocation = detected;
      turnsAtSameLocation = 0;
    }
  }

  /// 「换一批」：用本地分场景词库重掷选项，不消耗 token。
  /// 本地生成是纯同步的，外面套 isLoading 没有意义（中间不会渲染任何一帧，
  /// 玩家看不到转圈，只会白等），所以这里直接同步替换 choices 再通知 UI。
  void generateMoreSuggestions() {
    if (player == null || isLoading) return;
    error = null;
    final suggestions = _generateLocalSuggestions();
    if (suggestions.isEmpty) {
      error = '暂时想不出更多建议，请继续';
    } else {
      choices = suggestions;
    }
    notifyListeners();
  }

  /// 去重用的空白折叠正则，预先编译，避免在候选过滤循环里反复构造。
  static final RegExp _collapseWs = RegExp(r'\s+');

  /// 锚点去重时剥掉事件前缀图标。原先在两个 for 循环里各写一份，
  /// 每个事件都重新编译一次。
  static final RegExp _anchorIconPrefix = RegExp(r'^([\u{1F4CA}\u{1F464}\u{1F4AC}\u{1F4C5}\u{1F3C6}\u{1F31F}\u{1F4F0}])', unicode: true);

  /// 季节锁定地点 → 允许"抵达"的最早日期（MMDD）。
  /// 与 runSceneTransitionGraph 的 minDateInt 保持一致：国王十字车站 / 九又四分之三站台 /
  /// 霍格沃茨特快 / 大礼堂 均须 9 月 1 日（901）及之后——原作霍格沃茨特快 9 月 1 日才发车。
  /// _syncLocationFromNarrative 此前绕过了这个时间门，是"7 月底人就到了车站"的根因。
  static const Map<String, int> _seasonLockedMinDate = {
    '国王十字': 901,
    '九又四分之三': 901,
    '站台': 901,
    '特快': 901,
    '列车': 901,
    '大礼堂': 901,
    '霍格沃茨·大礼堂': 901,
  };

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
    // 去重并打乱。正则提到循环外编译——原先写在 where 回调里，
    // 每个候选短语都会重新编译一次正则。
    final seen = <String>{};
    final deduped = pool.where((s) {
      final k = s.replaceAll(_collapseWs, '');
      if (seen.contains(k)) return false;
      seen.add(k);
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
}
