import 'dart:async';
import 'mixin_narrative_canon.dart';
import '../data/command_registry.dart';
// 只取 kDebugMode：给 _closeLoopIfMatched 的热路径日志加 `if (kDebugMode)`
// 保护时漏了这个 import，整包 analyze 直接红——典型的「改了 A 没改它的
// 对称面 B」（第八次审查 §4）。
import '../models/game_systems.dart';
import '../services/deepseek_service.dart';
import '../utils/prompt_sanitizer.dart';

import '../utils/confession_reply.dart';
import '../utils/crash_logger.dart';
import '../providers/game_provider_base.dart';
import '../narrative/narrative_source_gate.dart';
import '../data/faculty_data.dart';
import '../models/story_progress.dart';
import '../data/worldline_data.dart';
import 'mixin_narrative_continuity.dart';
import 'mixin_summary_memory.dart';
import 'mixin_narrative_offline.dart';
import 'mixin_narrative_prompt.dart';
import 'mixin_play.dart';
import 'mixin_story_engine.dart';
import '../utils/debug_log.dart';



mixin GameNarrativeMixin
    on
        GameProviderBase,
        GameNarrativeCanonMixin,
        GameNarrativeOfflineMixin,
        GameNarrativePromptMixin,
        GameNarrativeContinuityMixin,
        GameSummaryMemoryMixin,
        GameStoryEngineMixin {
  /// 命令分发切词（parseAction 每回合，预编译）。
  static final RegExp reWhitespaceNarrative = RegExp(r'\s+');

  /// 去重用的空白折叠正则（generateMoreSuggestions 候选过滤，预编译）。
  static final RegExp _collapseWs = RegExp(r'\s+');

  /// 选项文本去前缀非正文噪声（processChoice 每回合，预编译）。
  static final RegExp reLeadingNonTextNarrative =
      RegExp(r'^[^\u4e00-\u9fa5A-Za-z]*');


  /// 事件类指令（/决斗 /禁林 探险 等非面板指令）执行前的剧情快照，
  /// 供「回到剧情」选项恢复。仅事件指令覆盖剧情时写入；未命中为 null。
  ({String narrative, List<GameChoice> choices})? _storyBackup;

  /// Q5：取消当前正在进行的叙事/选项生成。
  ///
  /// UI 加载槽位的「取消」按钮对接这里。路由器掐断整条调用链（含底层
  /// HTTP），[processChoice] 捕获 [AiCanceledException] 后静默收尾——
  /// 不重试、不切 Key、不生成本地兜底剧情（否则玩家正在看的正文会被
  /// 替换成过渡文本）。
  void cancelCurrentNarrative() {
    final r = router;
    if (r == null || !isLoading) return;
    r.cancelCurrentCall();
  }

  @override
  Future<void> processChoice(GameChoice choice) async {
    if (player == null) return;
    CrashLogger.instance.logHeartbeat(
      'processChoice:start action=${choice.action.length > 30 ? choice.action.substring(0, 30) : choice.action}',
    );

    // 死亡后拦截：只剩查看终章/回望/引导三条路（/结局 与 /状态 放行，
    // 其余全部挡下；blockActionIfDead 已写好引导文案）
    if (blockActionIfDead()) {
      final a = choice.action.trim();
      if (a.startsWith('/结局') || a.startsWith('/状态') || a.startsWith('/传承')) {
        // 放行：这些是死亡后仍可查看的指令
      } else {
        notifyListeners();
        return;
      }
    }

    // 并发守卫。UI 侧三处入口是在 build 时把 isLoading 固化进 onTap 的，
    // 而 onTap 要从「可点」变成「不可点」得等下一帧重建——同一帧内连点两下
    // 就会进来两次。后果不是丢一次请求那么简单：turnCount +2、
    // 两个 AI 请求同时在飞、advanceTimeForAction 和 updateNPCsFromAction
    // 各结算两遍（时间/精力/被动好感都翻一番），最后返回慢的那个覆盖
    // currentNarrative，玩家看到剧情倒退。
    if (isLoading) return;

    // 本地指令解析
    var action = choice.action.trim();
    // 「//」转义：以 // 开头的输入按自由剧情发送（剥掉一个 /），
    // 这是玩家想聊 "/xxx" 内容的唯一途径——否则任何 / 开头都会被当指令吞掉。
    if (action.startsWith('//')) {
      action = action.substring(1);
    }
    String? causalResult;

    // ===== 主线剧情分支指令（必须排在其他解析之前）=====
    //
    // 【为什么位置这么靠前】剧情选项的 action 形如
    // `@@story:ps_ch1_letter:read_in_room@@`，它既不是 `/` 指令、
    // 也不含因果锚点关键词，理论上后面几个解析器都不会认。但**顺序不能赌**：
    // `parseCausalCommand` 是按关键词匹配的，一旦某天有人给某个剧情选项
    // 的文案里加了个与因果锚点撞词的字眼，分支语义就会被抢走。
    // 显式排在最前，是让"剧情指令优先"成为**结构性保证**而非巧合。
    //
    // 命中后直接进剧情回合，不走 AI 路径也不走沙盒兜底。
    // 问题4：「回到剧情」——恢复事件类指令执行前的剧情快照。
    // 不消耗回合、不触发 AI、不加 turnCount（直接 return）。
    if (action == '@@resume_story@@') {
      final backup = _storyBackup;
      if (backup != null) {
        currentNarrative = backup.narrative;
        choices = List<GameChoice>.from(backup.choices);
        commandResult = null;
        _storyBackup = null;
      }
      notifyListeners();
      return;
    }
    final storyCmd = parseStoryCommand(action);
    if (storyCmd != null && storyProgress.active) {
      runOfflineQuickTurn(action, causalResult: null);
      return;
    }

    // P7 玩法入口标记解析：选项面板生成的玩法选项 action 形如
    // `@@gameplay:quidditch`。在因果/教职/斜杠解析**之前**把它解析成
    // 可读自然文本，随后统一走「离线 → tryRouteGameplayIntent 关键词路由
    // → 完整玩法系统」或「AI → 自然文本进 Prompt」两条路径。
    // 标记本身绝不出现在叙事、Prompt、存档与记忆里；未知标记剥掉前缀
    // 后按自由文本处理，一次解析失败不卡死整回合。
    if (action.startsWith(kGameplayActionPrefix)) {
      final id = action.substring(kGameplayActionPrefix.length).trim();
      final text = kGameplayActionToText[id];
      if (text != null) {
        action = text;
      }
    }

    // 因果锚点抉择（见 lib/data/worldline_data.dart）：
    // 唯一一个「先本地结算、再继续走叙事」的入口。先记账（数值 + 痕迹），
    // 然后把选项自带的那段具体行动当成玩家输入发给 AI。
    // 少了后半步，玩家点完「上塔去」只看到一段后果文本，
    // 塔上究竟发生了什么永远没人写。
    final causal = parseCausalCommand(action);
    final faculty = parseFacultyCommand(action);
    if (causal != null) {
      causalResult = resolveCausalChoice(
        causal.anchor.anchorId,
        causal.option.id,
      );
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
        // 查看类指令（/状态 /关系 /收藏 等，注册时 CommandDef.panel=true）：
        // 输出进独立面板，不覆盖当前回合剧情。
        // 此前用「choices 是否为单个『返回/继续』」的启发式判断面板型，
        // /计划、/新NPC 生成 这类事件指令也设置了「返回」选项 → 被误判为
        // 面板型、执行结果剧情被还原成上一段（玩家看不到任何结果）。
        // 改为注册时显式声明 panel，判定不再猜（BUG-FIX）。
        final slashless = action.startsWith('/') ? action.substring(1) : action;
        final cmdHead = slashless.split(reWhitespaceNarrative).first;
        final def = CommandRegistry.instance.find(cmdHead);
        final isPanelOutput =
            def?.panel == true && currentNarrative != prevNarrative;
        if (isPanelOutput) {
          commandResult = currentNarrative;
          currentNarrative = prevNarrative;
          choices = prevChoices;
        } else {
          // 事件类指令（/计划 /快进 /新NPC 生成 等）正常替换剧情，同时关闭旧面板
          commandResult = null;
          // 问题4：记录事件执行前的剧情快照，并追加「回到剧情」选项，
          // 让玩家从事件结果剧情（如决斗结算 / 禁林探险）回到事件发生前。
          _storyBackup = (narrative: prevNarrative, choices: prevChoices);
          choices = [
            ...choices,
            GameChoice(text: '回到剧情', action: '@@resume_story@@'),
          ];
        }
        notifyListeners();
        unawaited(autoSave());
        return;
      }
    }

    // 用户自由文本在进入 Prompt 前做注入防御净化
    // 第16轮G：未识别的 / 开头输入（如选项带 "/强忍不安..." 或玩家误加 /）
    // 已由 handleLocalCommand 降级为自由行动，这里去掉 / 前缀再交给 AI，
    // 避免叙事/选项把 / 原样带回来形成循环。
    var effectiveAction = action;
    if (effectiveAction.startsWith('/')) {
      effectiveAction = effectiveAction.substring(1).trim();
    }
    final safeAction = PromptSanitizer.sanitizeAction(effectiveAction);

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

    if (router == null || !router!.hasNarrativeService) {
      // 审查 P0「无 AI 快速模式 + 本地兜底剧情」：未配 Key 时绝不静默卡死。
      // 开过离线模式 → 直接本地快速模式；否则给出明确指引让玩家去配置或开离线。
      if (!appProvider.offlineQuickMode) {
        error =
            '未配置可用的 AI Key，无法生成剧情。请到「设置」配置 AI Key，'
            '或开启「本地模式」完全本地游玩。';
        loadingStage = '';
        notifyListeners();
        return;
      }
      runOfflineQuickTurn(safeAction, causalResult: causalResult);
      return;
    }

    // P1 叙事来源判定：主动离线 / 自动降级 → 本地快速回合；否则走 AI。
    // 替换原先"只看 offlineQuickMode 是否开启"的两段分支——自动降级切入后
    // 即使没开离线模式也会切到本地，宽限期用尽又自动恢复尝试 AI。
    if (effectiveNarrativeSource == NarrativeSource.local) {
      narrativeSourceGate.onLocalTurn();
      runOfflineQuickTurn(safeAction, causalResult: causalResult);
      return;
    }

    // 提交真实行动时关闭指令面板；但因果抉择与留校答复的后果面板要留着，
    // 玩家得看见变动率跳了多少、或者自己到底签了什么。
    commandResult = causalResult;
    error = null; // 新一轮开始前清掉上一次的失败提示
    // S1：上一回合的流式预览（若有残留）不能带进新一轮。
    clearStreamingPreview();
    isLoading = true;
    turnCount++;
    lastScannedNarrativeHash = null;
    lastPlayerAction = safeAction;
    loadingStage = '正在构建请求...';
    notifyListeners();



    try {
      // 场景转移图（替换仅前12回合生效的 _checkOpeningRailroad）
      //  - 开局家中/对角巷/国王十字/特快/分院/公共休息室/第一节课 全阶段通用
      //  - 所有地点切换强制检查进度门+时间门，不满足只注入衔接锚点，绝不硬切 location
      runSceneTransitionGraph();

      // 场景停滞检测：回合开始时比较地点，若未变则累加停滞计数
      // buildPrompt 会读取 turnsAtSameLocation 决定是否注入强制推进指令
      updateLocationTracking();

      String buildPromptInternal() => buildPrompt(safeAction);
      String prompt = buildPromptInternal();
      // 记录本回合实际注入的锚点（推进时间后可能产生新锚点，不能误清）
      String? consumedAnchor = pendingAnchorDirective;
      loadingStage = '正在生成剧情...';
      notifyListeners();

      String response;
      // 世代守卫：await AI 期间若发生「重置游戏/读档」，旧局响应必须整体丢弃。
      // 否则旧局的好感/死伤/疤痕副作用会写进新局，玩家=null 时直接空指针崩。
      final int epoch = sessionEpoch;
      int retriesLeft = 2; // 允许 critical 级违规 / BUG-H(模型返回选项而非叙事) 自动重试 2 次
      List<Map<String, dynamic>> violations = const [];
      List<Map<String, dynamic>> forbiddenHits = const [];
      bool needsRetry;
      bool narrativeParseInvalid = false; // BUG-H 标记：模型返回的是选项不是叙事
      bool usedFallbackNarrative = false; // 走了本地兜底叙事 → 不再应用 AI 副作用
      String? finalResponseText; // 最终采纳的原始响应文本（供副作用解析）
      // 日志分析第16轮D：SenseNova 偶发空响应（10 次请求里 3 次），
      // 重试时复用同 prompt 没强化指令，命中率靠运气。给重试 prompt
      // 追加「直接输出正文」硬约束（per-call 临时后缀，不污染下次构建）。
      String currentPrompt = prompt;
      do {
        needsRetry = false;
        narrativeParseInvalid = false;
        try {
          response = (await callDeepSeek(currentPrompt, stream: true)).content;
        } on AiNonRetryableException {
          rethrow;
        } on AiCanceledException {
          // Q5：用户取消 → 不重试（重试会立刻再发起一次新请求），直接上抛。
          rethrow;
        } catch (e) {
          loadingStage = '请求失败，正在重试...';
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 500));
          // S1：这次尝试已作废，先丢掉它吐出的半截正文，再重来。
          clearStreamingPreview();
          notifyListeners();
          // 重试前强化指令：要求直接输出纯正文，禁止空行/前言/解释
          currentPrompt =
              '$prompt\n\n⚠️【重试指令】上一轮返回为空或不合规，请直接输出当前回合的剧情正文（中文纯文本），不要任何前言、解释、空行、Markdown 或代码块标记。';
          response = (await callDeepSeek(currentPrompt, stream: true)).content;
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
          debugLog(
            '❌ [BUG-H] 当前 parseNarrativeOnly 返回 false，视为 critical 级异常触发重试',
          );
        }

        // --- ContinuityBridge Step C：新叙事必须承接上回合末尾锚点 ---
        // 不衔接 → 开头自动补承接过渡句（不打回重写，以防"凭空换剧情"）
        if (!narrativeParseInvalid) {
          final bridged = enforceContinuityBridge(currentNarrative, safeAction);
          if (bridged != currentNarrative) {
            // 先保存当前已经提取好的好感度，避免被覆盖清空
            // ❗为什么：bridged 已经移除了好感区块（来自第一次 parseNarrativeOnly）
            // 重新解析时没有原始好感区块，会导致 lastAffectionSections 被清空
            final savedAffectionSections = List<String>.from(
              lastAffectionSections,
            );
            currentNarrative = bridged;
            // 重新跑 parseNarrativeOnly，但只重新解析头部位置/时间戳提取，不覆盖好感度
            // 因为好感变化区块在原始完整响应中已经提取过了
            // （applySideEffects: false —— 桥接后的正文已无好感区块，
            //  再跑一次副作用会让被动好感被重复结算一遍）
            parseNarrativeOnly(currentNarrative, applySideEffects: false);
            // 如果重新解析没有提取到新的好感度（本来就没有），恢复保存的好感度
            if (lastAffectionSections.isEmpty &&
                savedAffectionSections.isNotEmpty) {
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
            'message':
                '违和词命中(${h['category']}): ${h['word']} — 霍格沃茨世界观不应出现现代物品/跨IP角色/网络梗。',
            'evidence': h['word'],
            'at': DateTime.now().toIso8601String(),
          });
        }
        final criticalForbidden = forbiddenHits
            .where((h) => h['severity'] == 'critical')
            .toList();

        // --- P0-1 一致性看门狗：6 大类校验 ---
        violations = narrativeParseInvalid
            ? const []
            : validateNarrativeConsistency(currentNarrative);
        for (final v in violations) {
          recordConsistencyViolation(v);
        }
        final criticalViolations = violations
            .where((v) => v['severity'] == 'critical')
            .toList();

        // --- 判定：critical 违规 / critical 禁止词 / BUG-H(叙事返回选项) → 重试
        final anyCritical =
            criticalViolations.isNotEmpty ||
            criticalForbidden.isNotEmpty ||
            narrativeParseInvalid;
        if (retriesLeft > 0 && anyCritical) {
          final msgs = <String>[
            if (narrativeParseInvalid)
              '模型搞错场景了，本应生成剧情正文但返回了选项A/B/C/D。请严格按照【写作要求】输出600-800字剧情叙事，绝对不要包含任何选项格式的行(A./B./C./D.)！',
            ...criticalViolations.map((v) => '${v['rule']}: ${v['message']}'),
            ...criticalForbidden.map(
              (h) => '违和词(${h['category']}): ${h['word']}',
            ),
          ];
          debugLog(
            '⚠️ 叙事 critical 级异常，准备重试（剩余$retriesLeft次）：${msgs.take(3).join(" | ")}',
          );
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
          debugLog(
            '❌ [BUG-H] 2次重试后仍返回选项，切换为 generateFallbackNarrative() 本地兜底叙事',
          );
          currentNarrative = generateFallbackNarrative();
          usedFallbackNarrative = true;
          // P1：本轮 AI 叙事失败 → 记入降级门（连续失败会自动切本地）。
          narrativeSourceGate.recordFailure();
          // 兜底叙事是 Dart 代码生成的，不会夹带选项，也没有好感度区块
          // 所以不用再跑 parseNarrativeOnly，也不应用任何 AI 副作用，
          // 但要跑一遍地点同步等后续流程
          notifications.add(
            '📝 AI 返回了选项而非剧情（偶尔会发生），已为你切换为系统本地过渡剧情，确保不断链。稍后重跑会恢复正常。',
          );
          break;
        }

        // warn 级违规不必打回，只是记录到 consistencyViolations 并在下回合注入软提醒。
        // warn 也加到通知里，方便玩家/开发者看到
        final warnCount =
            violations.where((v) => v['severity'] == 'warn').length +
            forbiddenHits.where((h) => h['severity'] == 'warn').length;
        if (warnCount > 0) {
          notifications.add('📝 剧情逻辑警告：本回合有 $warnCount 处轻微违和，已记录。');
        }
        break; // 走到这里说明不重试
      } while (needsRetry);

      // ====== 叙事定稿：副作用此时才落库，且整回合只落一次 ======
      // 重试循环内被驳回的 response 不再污染好感度/声望/分院状态。
      if (epoch != sessionEpoch) {
        // 游戏已在 await 期间被重置/读档：旧局响应作废，只复位加载态
        isLoading = false;
        notifyListeners();
        return;
      }
      if (!usedFallbackNarrative) {
        applyNarrativeSideEffects(finalResponseText);
        // P1：真走了一次可用 AI 叙事 → 通知降级门记录成功（可即时撤销自动降级）。
        narrativeSourceGate.recordSuccess();
      }

      // ====== 信息密度调节器：检测本回合叙事的事件密度 ======
      // 密度低于阈值时记录警告，用于后续分析与 prompt 调优；
      // 兜底叙事密度过低时自动增强，确保离线模式也有足够的叙事张力。
      {
        final density = calculateInformationDensity(currentNarrative);
        lastNarrativeDensity = density;
        narrativeDensityHistory.add(NarrativeDensityRecord(
          turn: turnCount,
          density: density,
          isLow: density > 0.0 && density < 0.02,
          isOffline: false,
        ));
        if (density < 0.02 && density > 0.0) {
          debugLog('⚠️ 信息密度偏低: ${density.toStringAsFixed(4)}（阈值 0.02）');
          if (usedFallbackNarrative) {
            // 兜底叙事密度过低 → 自动增强：追加一段具体的环境/事件描述
            final p = player;
            if (p != null) {
              final location = worldState.currentLocation ?? '霍格沃茨';
              final weather = worldState.weather ?? '晴朗';
              final enhancement =
                  '\n\n你环顾四周，$location 的$weather天气下，'
                  '城堡的走廊里传来远处学生的笑闹声和隐约的脚步声。'
                  '墙上的画像低声交谈着最近的校园新闻，'
                  '一只猫头鹰从窗外掠过，带起一阵微风。';
              currentNarrative = currentNarrative.trimRight() + enhancement;
            }
          } else {
            notifications.add('📝 本回合叙事密度偏低，AI 可能写得过于笼统。');
          }
        }
      }

      // ====== 每回合周期性结算（原先只挂在 parseResponse 里 = 只在开局跑一次）======
      // parseResponse 的唯一调用点是 generateOpeningScene()，正常回合走的是
      // parseNarrativeOnly + applyNarrativeSideEffects，那边从来不调这些检查，
      // 于是「NPC 主动表白」「世界线变动率增长」两套系统在整局游戏里都是死的。
      // 这里改在每回合叙事定稿后执行，且必须早于选项生成：
      // checkNPCConfessions 会改写 currentNarrative 并给出「接受/婉拒」专属选项，
      // 被 AI 的 4 个通用选项覆盖掉的话，玩家就看不到对方面红耳赤地站在面前了。
      //
      // 结算本体抽到 settleAfterNarrative，与无 AI 快速模式共用同一份——
      // 第五轮只把「状态推进」搬去了离线路径，周期结算一项没搬。
      final bool confessedThisTurn = settleAfterNarrative();

      // 独立生成选项：基于已生成的剧情（与主叙事完全解耦，不再从叙事响应提取）
      // 注意：从 2026-08-23 起「写作要求」明确禁止主叙事 AI 输出选项，
      //       因此即使叙事响应里意外夹带了 ABCD（来自 T4 旧摘要污染），
      //       也绝对不再读入到选项里——否则会出现"海格/巨怪"等过期内容。
      final pendingCausal = pendingCausalAnchorId == null
          ? null
          : causalAnchorFor(pendingCausalAnchorId!);
      final causalDecided =
          pendingCausal != null &&
          worldState.causalChoices.containsKey(pendingCausal.anchorId);
      if (confessedThisTurn) {
        // 表白已就位：checkNPCConfessions 内部写入了专属的「接受/婉拒」两个选项，
        // 此时再让 AI 生成 4 个通用选项会把这个抉择冲掉。
        // 三个纯本地分支都不在这里 notify：下面 937 统一通知一次，
        // 中间没有 await，分支内通知是同一帧的重复 rebuild（F10/P4）。
        loadingStage = '';
      } else if (pendingFacultyOffer) {
        // 留校邀请：毕业后唯一一个"接下来的人生往哪走"的分岔。
        // 同样不让 AI 的通用选项冲掉——这是七年攒出来的东西换来的一个问句。
        choices = const [
          GameChoice(text: '留下来教书', action: '/教职 接受'),
          GameChoice(text: '婉拒，离校', action: '/教职 婉拒'),
        ];
        loadingStage = '';
      } else if (pendingCausal != null && !causalDecided) {
        // 命运时刻：选项只给这几个分支，AI 生成的通用选项全部让路。
        // 七年里能改写原著的机会一只手数得过来，
        // 混进「仔细查看四周」这种选项会把它稀释成一次普通的场景交互。
        choices = pendingCausal.options
            .map(
              (o) => GameChoice(
                text: o.text,
                action: '/抉择 ${pendingCausal.anchorId} ${o.id}',
              ),
            )
            .toList(growable: false);
        loadingStage = '';
      } else {
        loadingStage = '正在生成选项...';
        notifyListeners();

        // ---- 选项端也跑一次禁止词 & OOC软提示（轻微的OOC不会打回，改 prompt 软提醒）----
        final separateChoices = await generateChoicesSeparately(
          currentNarrative,
        );
        if (separateChoices.isNotEmpty) {
          choices = separateChoices;
        } else {
          // 独立选项生成失败时：直接走与超时同一套「末尾800字承接型」兜底，
          // 彻底弃用 generateContextualFallbackChoices（它会按关键词匹配出"仔细查看"这种简易选项，
          // 玩家点击后AI拿到与剧情结尾无关的动作，造成"刚生成的剧情没操作就被另一个剧情替换"的断链）。
          debugLog('独立选项生成失败，切换到末尾承接型兜底选项');
          choices = buildFallbackChoices(currentNarrative);
        }
      }
      // BUG-N 追踪：记录最终设置到Provider的选项
      // processChoice最终选项日志已移除
      // 立即通知 UI 刷新选项，确保用户看到最新选项
      notifyListeners();

      // 收尾落库（与离线快速模式共用，见 finalizeTurn）：
      // ContinuityBridge Step A —— 把本回合叙事的末尾锚点存档，下回合强制衔接。
      // 注意：先同步 location（syncLocationFromNarrative）后再 saveAnchor，
      // 确保 location 锚点是最新的。
      finalizeTurn(currentNarrative, action);
      // 锚点已成功注入本回合剧情，清除待注入状态（仅当未被新锚点替换时）
      if (consumedAnchor != null && pendingAnchorDirective == consumedAnchor) {
        pendingAnchorDirective = null;
      }

      maybeRunPeriodicSummary();

      loadingStage = '';
      isLoading = false;
      notifyListeners();
      unawaited(autoSave());
    } on AiCanceledException {
      // Q5：用户主动取消。不降级兜底（会覆盖当前正文/回合进度），
      // 只恢复可输入状态并给出轻量提示，让玩家重新输入行动。
      debugLog('⏹ 剧情/选项生成已被用户取消');
      notifications.add('⏹ 已取消本次 AI 生成，可重新输入行动');
      loadingStage = '';
      isLoading = false;
      notifyListeners();
    } catch (e) {
      // AI 全部提供商不可用时的本地兜底：给出过渡剧情与选项，保证游戏不卡死
      debugLog('❌ 剧情生成失败，启用本地兜底叙事: $e');
      CrashLogger.instance.logHeartbeat('narrative:fallback');
      // P1：本轮 AI 叙事失败 → 记入降级门（连续失败会自动切本地兜底）。
      narrativeSourceGate.recordFailure();
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
      unawaited(
        CrashLogger.instance.record(
          e,
          StackTrace.current,
          screen: 'processChoice',
          extra: 'action=$action, turn=$turnCount',
        ),
      );
    } finally {
      // 兜底：无论 try 正常完成、catch 兜底，还是 catch 内部自身抛了二次异常，
      // 都保证 isLoading 重置、UI 退出 loading 状态。
      // 否则玩家看到的就是"正在生成剧情..."转圈无限卡死（之前的 UI 反馈 bug）。
      //
      // S1：流式预览也必须在这里清掉。正文已定稿（写进 currentNarrative），
      // 预览若留着，UI 会先渲染一遍半截文本再切到定稿版——看起来像闪一下。
      // 放在 finally 里，取消 / 兜底 / 异常路径同样干净。
      clearStreamingPreview();
      loadingStage = '';
      if (isLoading) {
        isLoading = false;
        notifyListeners();
      }
    }
  }










  /// 导演节拍器的低张力场景判定：这些时刻转折概率减半。
  ///
  ///  - 暑假（term == 'summer'）：城堡空了，人都不在，强插冲突没有落点；
  ///  - 考试季（5-6 月）：叙事张力天然拉满，再来意外是叠加不是节奏；
  ///  - 深夜（23:00-06:00）：宵禁后的独处时段，适合让人物喘口气。
  ///
  /// 注意是"概率减半"不是"禁止转折"——低张力场景偶尔来一下反而是好的，
  /// 完全禁掉就成了另一种可预测的机械规则。
  /// 检测最近几回合的叙事节奏，生成安静期提示。
  /// 如果连续 3 回合以上没有转折（director beat 为 turn），
  /// 注入"本回合需要一点波澜"的指令，防止叙事陷入日常循环。
  /// 构建场景上下文信息（当前存在的NPC、时间提示等）

  /// 获取当前场景中的NPC

  // ==================== 场景停滞检测与地点同步 ====================

  /// 【场景豁免·地点白名单】：
  // ============================================================
  // 【宏观通用 M4 · StagnationDetector 停滞检测器】
  //
  // 把之前散落的 3 个独立函数（阈值分级/豁免地点/未解决钩子）+ buildPrompt 里的停滞文案拼接逻辑，
  // 集中封装成一个独立对象。好处：
  //   - 后期新增地点、新增"豁免剧情类型"，只改这一处数据 + 规则；
  //   - mixin_narrative / mixin_response / 未来其他 mixin 调用统一出口，不会出现各自 if 版本不一致；
  //   - "停滞 → 强制推进文案" 从 buildPrompt 里解耦出来，可单独单测。
  //
  // 旧 API（stagnationThresholdFor / narrativeHasUnresolvedHook）
  // 保持对外不变：内部委托给 StagnationDetector，不会破坏 GameProviderBase 的 abstract 签名。
  // isLocationExemptFromStagnation 已移除：判定收敛进 evaluate 后没有任何调用者。
  // ============================================================


  // 地点表在 lib/data/locations.dart（纯数据，测试和事件锚点校验都要用），
  // 归一化统一走 resolveLocationName，这里不再自己遍历别名。




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
    if (loc.contains('教室') || loc.contains('classroom') || loc.contains('讲堂')) {
      key = 'classroom';
    }
    if (loc.contains('大礼堂') || loc.contains('great hall')) key = 'great_hall';
    if (loc.contains('图书馆') || loc.contains('library')) key = 'library';
    if (loc.contains('走廊') || loc.contains('corridor')) key = 'corridor';
    if (loc.contains('城堡外') || loc.contains('outside') || loc.contains('草坪')) {
      key = 'outside';
    }
    if (loc.contains('公共休息室') || loc.contains('common')) key = 'common_room';
    if (loc.contains('禁林') || loc.contains('forbidden')) {
      key = 'forbidden_forest';
    }
    if (loc.contains('对角巷') || loc.contains('diagon')) key = 'diagon_alley';
    if (loc.contains('医疗翼') || loc.contains('hospital')) key = 'hospital';
    if (loc.contains('决斗') || loc.contains('duel')) key = 'duel_club';

    // 情境追加：根据叙事关键词添加专属建议
    final extra = <String>[];
    if (narrativeLower.contains('魁地奇') ||
        narrativeLower.contains('quidditch')) {
      extra.addAll(['前往魁地奇球场观看或加入训练', '与球队队员交谈获取赛事信息']);
    }
    if (narrativeLower.contains('食堂') ||
        narrativeLower.contains('餐') ||
        narrativeLower.contains('food')) {
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
      extra.add('参加$house学院的活动');
      extra.add('为$house学院的荣誉加分');
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



}

/// 从一条世界事件文本中取「叙事去重探测片段」。
///
/// 历史上这里直接写 `latestEvent.substring(0, latestEvent.length.clamp(10, 40))`：
/// 事件文本短于 10 字时 clamp 返回 10，substring 越界抛 RangeError，
/// 离线模式整回合崩溃（BUG-FIX）。提取成纯函数便于回归测试。
String narrativeEventProbe(String latestEvent) {
  if (latestEvent.isEmpty) return '';
  return latestEvent.length <= 40 ? latestEvent : latestEvent.substring(0, 40);
}

/// 单回合信息密度记录，用于结构化存储与后续分析。
class NarrativeDensityRecord {
  final int turn;
  final double density;
  final bool isLow;
  final bool isOffline;

  const NarrativeDensityRecord({
    required this.turn,
    required this.density,
    required this.isLow,
    required this.isOffline,
  });

  @override
  String toString() =>
      '[turn=$turn] density=${density.toStringAsFixed(4)} isLow=$isLow offline=$isOffline';

}