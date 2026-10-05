import 'dart:async';
import 'mixin_narrative_canon.dart';
import 'dart:math';
import '../data/command_registry.dart';
// 只取 kDebugMode：给 _closeLoopIfMatched 的热路径日志加 `if (kDebugMode)`
// 保护时漏了这个 import，整包 analyze 直接红——典型的「改了 A 没改它的
// 对称面 B」（第八次审查 §4）。
import 'package:flutter/foundation.dart' show visibleForTesting;
import '../models/npc.dart';
import '../models/game_systems.dart';
import '../services/deepseek_service.dart';
import '../utils/prompt_sanitizer.dart';

import '../models/long_term_memory.dart';
import '../services/ai_router.dart';
import '../utils/stagnation_detector.dart';
import '../utils/confession_reply.dart';
import '../utils/crash_logger.dart';
import '../providers/game_provider_base.dart';
import '../narrative/narrative_source_gate.dart';
import '../data/locations.dart';
import '../data/attribute_data.dart';
import '../data/course_data.dart';
import '../data/director_beat_data.dart';
import '../data/scar_data.dart';
import '../data/era_data.dart';
import '../data/faculty_data.dart';
import '../data/game_config_rules.dart';
import '../models/story_progress.dart';
import '../data/narrative_time_rules.dart';
import '../data/rivalry_data.dart';
import '../data/time_cost_rules.dart';
import '../data/wand_data.dart';
import '../data/worldline_data.dart';
import '../data/monthly_event_data.dart';
import '../data/npc_schedule_rules.dart';
import '../data/parallel_data.dart';
import '../prompts/narrative_prompts.dart';
import 'mixin_narrative_continuity.dart';
import 'mixin_summary_memory.dart';
import 'mixin_play.dart';
import 'mixin_story_engine.dart';
import '../utils/debug_log.dart';



mixin GameNarrativeMixin
    on
        GameProviderBase,
        GameNarrativeCanonMixin,
        GameNarrativeContinuityMixin,
        GameSummaryMemoryMixin,
        GameStoryEngineMixin {
  /// 命令分发切词（parseAction 每回合，预编译）。
  static final RegExp reWhitespaceNarrative = RegExp(r'\s+');

  /// 选项文本去前缀非正文噪声（processChoice 每回合，预编译）。
  static final RegExp reLeadingNonTextNarrative =
      RegExp(r'^[^\u4e00-\u9fa5A-Za-z]*');

  /// 上一回合的叙事信息密度（0.0 ~ 1.0），用于调试与调优
  double _lastNarrativeDensity = 0.0;

  /// 上次执行润色的回合（节流用）。润色是「可选增强」，不该每回合都打 AI：
  /// 与主叙事/摘要共用同一把 Key，频繁触发只会稀释省 Key 的意义（审批 3.1）。
  int _lastPolishTurn = -1;

  /// 事件类指令（/决斗 /禁林 探险 等非面板指令）执行前的剧情快照，
  /// 供「回到剧情」选项恢复。仅事件指令覆盖剧情时写入；未命中为 null。
  ({String narrative, List<GameChoice> choices})? _storyBackup;

  /// 上一回合的叙事信息密度（只读）。
  ///
  /// 保留这个出口是为了让"密度"这个只在内部算过的数有被观察到的机会：
  /// 调试面板、控制台、未来的自适应阈值都从这里取值，否则字段写进去
  /// 却永远没人读，analyzer 版本一升级就会被判成死代码。
  double get lastNarrativeDensity => _lastNarrativeDensity;

  /// 上一次注入的政治立场值，用于检测变化（没变化时跳过重复注入）
  String _lastPoliticalStance = '';

  /// 每回合信息密度历史记录，用于调试与调优
  final List<_NarrativeDensityRecord> _narrativeDensityHistory = [];

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
      _runOfflineQuickTurn(action, causalResult: null);
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
      _runOfflineQuickTurn(safeAction, causalResult: causalResult);
      return;
    }

    // P1 叙事来源判定：主动离线 / 自动降级 → 本地快速回合；否则走 AI。
    // 替换原先"只看 offlineQuickMode 是否开启"的两段分支——自动降级切入后
    // 即使没开离线模式也会切到本地，宽限期用尽又自动恢复尝试 AI。
    if (effectiveNarrativeSource == NarrativeSource.local) {
      narrativeSourceGate.onLocalTurn();
      _runOfflineQuickTurn(safeAction, causalResult: causalResult);
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

    String formatImpact(double score) {
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
      final aptitudeForPrompt = effectiveAptitude.isEmpty
          ? '普通'
          : effectiveAptitude;

      final profileLine =
          '【档案】${p.name}·${p.house ?? '未分院'}·${p.grade}年·天赋$aptitudeForPrompt·精神${p.spirit}·精力${p.energy}';
      final impactLine = '影响力：${formatImpact(worldState.playerImpactScore)}';
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
      // 每回合重述一次，成本一行。只在变化时注入，避免重复。
      final stance = p.politicalTendency?.trim() ?? '';
      if (stance.isNotEmpty && stance != _lastPoliticalStance) {
        _lastPoliticalStance = stance;
        contextBuffer.writeln(
          '【政治立场】$stance（主角对纯血论、麻瓜出身、混血的态度；'
          'NPC 的台词与玩家可选的做法都需贴合此立场，'
          '不要因为剧情一时温情就软化或反转）',
        );
      }

      final isWeekend = isWeekendWeekday(worldState.time.weekday);
      final lockedNow = lockedRegionsFor(grade: p.grade, isWeekend: isWeekend);
      if (lockedNow.isNotEmpty) {
        contextBuffer.writeln(
          '【当前无法进入的区域】${lockedNow.map((r) => '${r.name}（${r.unlockCondition ?? '未开放'}）').join('、')}'
          ' —— 玩家现在到不了这些地方，不要安排他独自前往；'
          '确有需要时必须有教授带队或给出明确的违规代价。',
        );
      }
      contextBuffer.writeln('');

      // ========== T0 / T1 / T2 / T3 结构化长期记忆注入（永不压缩的纯事实层） ==========
      // 永远放在【世界上下文】最前面，防止后面截断看不到
      // T0: 核心事实 (importance ≥ 5，重要性高到低)
      //   分层注入（修复"永不遗忘层在注入侧被截断"）：
      //     · importance ≥ kPersistentFactImportance（9）→ 全量注入，
      //       上限 kT0InjectionPersistentQuota（= 存储容量 kMaxPersistentKeyFacts）
      //     · 其余 → 按分数选，上限 kT0InjectionRegularQuota
      //   旧实现写死 `i < 40`，而存储层允许永不遗忘层留 60 条，
      //   导致第 41 条起的 9 分事实（结婚/死亡/誓言）存着但永远读不到。
      final t0 = memory.keyFacts.where((f) => f.importance >= 5).toList()
        ..sort((a, b) {
          final c = b.importance.compareTo(a.importance);
          // 同分按写入时间新的靠前：Dart 的 sort 不稳定，大量 9 分并列时
          // 若不加次级键，前 N 条每回合可能换一批，AI 记住的旧事随机漂移。
          if (c != 0) return c;
          return b.absoluteDay.compareTo(a.absoluteDay);
        });
      // 第16轮G：过滤与 Player 权威事实冲突的历史污染条目。
      // P0-1 修复后新摘要不会写错，但更早版本的错误摘要已写进 keyFacts
      // （如"宠物猫头鹰绯月"——绯月是九尾灵狐；"闪电形伤疤"——主角非哈利）。
      // 这里在注入侧拦截，不改存档数据，AI 不再读到冲突事实。
      t0.removeWhere((f) => factConflictsWithAuthority(f.fact));
      if (t0.isNotEmpty) {
        // 配额由纯函数算，便于单测（test/t0_injection_quota_test.dart）。
        final quota = computeT0InjectionQuota(
          t0.map((f) => f.importance).toList(),
        );
        contextBuffer.writeln('【T0 核心事实（永不遗忘；纯事实，不得更改或遗忘）】');
        for (var i = 0; i < quota.total; i++) {
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
      // T2: NPC 关键关系（场景感知裁剪，同场景全量+高好感摘要）
      final currentLoc = worldState.currentLocation ?? '';
      final allIntroduced = npcRegistry.values.where((npc) => npc.introduced == true).toList()
        ..sort((a, b) => b.affection.abs().compareTo(a.affection.abs()));

      // 同场景NPC（全量注入）
      final sameLocationNpcs = allIntroduced.where((n) => n.currentLocation == currentLoc).take(5).toList();
      // 高好感场景外NPC（摘要注入）
      final otherHighAffection = allIntroduced
        .where((n) => n.currentLocation != currentLoc && !sameLocationNpcs.contains(n))
        .take(3)
        .toList();

      final t2Lines = <String>[];
      for (final npc in sameLocationNpcs) {
        final anchor = memory.relationshipAnchors[npc.id];
        if (anchor == null) continue;
        final buf = StringBuffer();
        buf.write('${npc.name}(好感${npc.affection >= 0 ? '+' : ''}${npc.affection}，${anchor.currentStage})');
        if (anchor.firstMeeting.isNotEmpty) buf.write('｜初见:${anchor.firstMeeting}');
        if (anchor.keyMoments.isNotEmpty) {
          buf.write('｜关键:${anchor.keyMoments.skip(max(0, anchor.keyMoments.length - 3)).join("；")}');
        }
        if (anchor.secretsShared.isNotEmpty) buf.write('｜交换秘密:${anchor.secretsShared.take(3).join("；")}');
        if (anchor.promisesExchanged.isNotEmpty) buf.write('｜承诺:${anchor.promisesExchanged.take(3).join("；")}');
        t2Lines.add('• ${buf.toString()}');
      }
      for (final npc in otherHighAffection) {
        final anchor = memory.relationshipAnchors[npc.id];
        if (anchor == null) continue;
        t2Lines.add('• ${npc.name}(好感${npc.affection >= 0 ? '+' : ''}${npc.affection}，${anchor.currentStage})');
      }
      if (t2Lines.isNotEmpty) {
        contextBuffer.writeln('【T2 NPC 关键关系（纯事实结构锚，永不压缩）】');
        contextBuffer.writeln(t2Lines.join('\n'));
        contextBuffer.writeln('');
      }
      // T3: 世界事件银行（重要性 * 新鲜度，近期优先 + 高分补位，总 40 条）
      // 审查 F7：老事件（>60 天）分数低但仍占名额，事件多时把近期事件挤掉，
      // AI 参考的是"几个月前的旧闻"。改为：近 60 天事件取前 30 条，
      // 60 天外的高分事件最多补 10 条——近期优先，重要旧事不丢。
      final ts = worldState.time.absoluteDayIndex;
      final t3Order = <WorldEventRecord, int>{
        for (var i = 0; i < memory.worldEvents.length; i++)
          memory.worldEvents[i]: i,
      };
      int t3Cmp(WorldEventRecord a, WorldEventRecord b) {
        final c = b.score(ts).compareTo(a.score(ts));
        if (c != 0) return c;
        // 与淘汰侧同一套次级键：自动提取的事件 importance 恒为 6，500 条
        // 里大量同分，不补键的话 Dart 的不稳定排序会让每回合注入的前 40 条
        // 换一批，玩家感觉 AI 记的世界线在随机漂移。
        final d = b.absoluteDay.compareTo(a.absoluteDay);
        if (d != 0) return d;
        return (t3Order[b] ?? 0).compareTo(t3Order[a] ?? 0);
      }

      final recentEvents = List<WorldEventRecord>.from(
        memory.worldEvents,
      ).where((e) => ts - e.absoluteDay <= 60).toList()..sort(t3Cmp);
      final oldEvents = List<WorldEventRecord>.from(
        memory.worldEvents,
      ).where((e) => ts - e.absoluteDay > 60).toList()..sort(t3Cmp);
      final t3 = <WorldEventRecord>[
        // S3 减法：原先 近期 30 + 旧 10 = 40 条，每回合注入约 800~1500 token，
        // 而其中绝大多数对「本回合该怎么写」零信息量（自动提取的事件 importance
        // 恒为 6，同分堆叠）。降到 近期 12 + 旧 3 = 15 条：保留「最近发生了什么」
        // 的骨架，把预算让给 T0 事实与在场人物。
        ...recentEvents.take(12),
        ...oldEvents.take(3),
      ];
      if (t3.isNotEmpty) {
        contextBuffer.writeln('【T3 世界事件银行（近期优先，按重要性+新鲜度排序）】');
        for (final e in t3) {
          final cons = e.consequences.isNotEmpty
              ? ' → 后续:${e.consequences.join(";")}'
              : '';
          contextBuffer.writeln(
            '• [${e.importance}]${e.timestamp} ${e.category}｜${e.title}:${e.description}$cons',
          );
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
        // 每 20 回合一次摘要、每次最多 10 条，三次摘要后就稳稳超过 30，
        // 于是从中期开始 narrativeSummary 永久不再进入 prompt——
        // 摘要任务照样每 20 回合跑一次，结果却从来没人读。
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
        contextBuffer.write(
          '【历史背景（仅供参考，严禁基于此生成当前回合的选项与场景）】\n$trimmedSummary\n\n',
        );
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
      final introducedSet = npcRegistry.values
          .where((n) => n.introduced)
          .map((n) => n.name)
          .toSet();

      bool looksFake(String text) {
        final clean = text.replaceAll(reLeadingNonTextNarrative, '');
        // 成就类伪造：含"成就/🏆"，但 achievement 关键词不在已解锁集合
        if (clean.contains('成就') || text.contains('🏆')) {
          final unlocked = player?.achievements ?? const <String>[];
          // 尝试找成就id/名称；若在已解锁集合找不到，算伪造
          if (unlocked.isEmpty) return true; // 宣称解锁但全局没解过任何成就=假
          // 按名称匹配：把 clean 与已解锁成就描述做交集
          final names = achievementCatalog.map((a) => a.id).toSet()
            ..addAll(achievementCatalog.map((a) => a.name));
          final hitAch = names.any((n) => n.isNotEmpty && clean.contains(n));
          // 双重校验：还必须有具体成就 ID 出现在已解锁列表中（避免文案命中但未解锁）
          final hitUnlocked = unlocked.any(
            (id) =>
                clean.contains(id) ||
                clean.contains(
                  achievementCatalog
                      .firstWhere(
                        (a) => a.id == id,
                        orElse: () => achievementCatalog.first,
                      )
                      .name,
                ),
          );
          if (!(hitAch && hitUnlocked)) return true;
        }
        // 结识类伪造：含"结识/认识/见面/认识了/👤"但对应NPC没introduced
        if (_reAcquaintanceKeywords.hasMatch(clean) ||
            text.contains('👤')) {
          final hitNpc = introducedSet.any(
            (n) => n.isNotEmpty && clean.contains(n),
          );
          if (!hitNpc) return true;
        }
        return false;
      }

      // 近期事件锚点注入（如果 T3 已经注入足够近期事件，则跳过重复注入）
      if (t3.isNotEmpty && t3.any((e) => ts - e.absoluteDay <= 3)) {
        // T3 已包含近期事件，跳过重复注入
      } else {
        // 日志分析第16轮D：CG/成就类锚点对 AI 当前回合零信息量却刷屏
        // （16 条里 14 条是「解锁CG」），挤掉真正的剧情事件 → 降权：
        // 成就/CG 全局最多保留 2 条（且只取最新的），剧情事件优先占满。
        bool isMetaEvent(String e) =>
            e.contains('🏆') || e.contains('📸') || e.contains('解锁成就') ||
            e.contains('解锁CG');
        var metaKept = 0;
        if (ws.recentEvents.isNotEmpty) {
          for (final ev in ws.recentEvents.reversed) {
            final e = ev.text;
            if (e.contains('好感本周已达上限') || e.contains('周好感度已达上限')) continue;
            if (looksFake(e)) continue;
            if (isMetaEvent(e)) {
              if (metaKept >= 2) continue;
              metaKept++;
            }
            final k = e.replaceAll(_anchorIconPrefix, '').trim();
            if (!alreadyAnchors.add(k)) continue;
            worldAnchors.add(e);
            // S3 减法：锚点总量 12+16=28 上限 → 合计 6 条。锚点是「硬锚」，
            // 6 条足以钉住世界线主干；再多只是把 T3 已经说过的事换个说法重述。
            if (worldAnchors.length >= 6) break;
          }
        }
        if (ws.recentNarrativeEvents.isNotEmpty) {
          for (final ev in ws.recentNarrativeEvents.reversed) {
            final e = ev.text;
            if (e.contains('好感本周已达上限') || e.contains('周好感度已达上限')) continue;
            if (looksFake(e)) continue;
            if (isMetaEvent(e)) {
              if (metaKept >= 2) continue;
              metaKept++;
            }
            final k = e.replaceAll(_anchorIconPrefix, '').trim();
            if (!alreadyAnchors.add(k)) continue;
            worldAnchors.add('剧情锚：$e');
            if (worldAnchors.length >= 6) break;
          }
        }
        if (worldAnchors.isNotEmpty) {
          contextBuffer.writeln('【世界近期重大事件（硬锚，不能丢）】');
          contextBuffer.writeln(worldAnchors.join('\n'));
          contextBuffer.writeln('');
        }
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
      final recent = truncateNarrativeContext(recentBuffer, 800);
      // 关键改进：明确标注为"已生成的前情"，禁止 AI 重复或改写
      contextBuffer.write('【前情回顾（已生成内容，严禁重复或改写其中任何段落，仅用于理解当前处境）】\n$recent');

      final context = contextBuffer.toString();
      final statusTag = buildStatusTag(p);
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
      // 第九次审查：三回合固定相位改为概率抽取（久未转折权重递增）+ 场景感知
      // （考试周/暑假/深夜转折概率减半），转折仍不会缺席太久，但玩家摸不到规律。
      final beat = directorBeatFor(
        turn: turnCount,
        hasUnresolvedHook: hasHook,
        turnsSinceLastTurn: turnsSinceLastTurnBeat,
        calmContext: _isCalmNarrativeContext(),
        random: random,
      );
      turnsSinceLastTurnBeat = beat == DirectorBeat.turn
          ? 0
          : turnsSinceLastTurnBeat + 1;
      final directorLine = directorLineFor(beat);

      // 命运时刻：这一回合要把抉择摆到玩家面前，但不能替他做决定。
      // AI 一旦自己写"你冲了上去"或者"你转过身"，玩家点什么都没意义了。
      final pendingCausal = pendingCausalAnchorId == null
          ? null
          : causalAnchorFor(pendingCausalAnchorId!);
      final causalLine =
          pendingCausal != null &&
              !worldState.causalChoices.containsKey(pendingCausal.anchorId)
          ? '【命运时刻·${pendingCausal.title}】\n'
                '${pendingCausal.setup}\n'
                '本回合的叙事必须停在这个抉择的当口：把上面这个情境写出来，'
                '一直写到"要不要动手"的那一瞬间为止。'
                '严禁替玩家做出选择——不要写他冲上去了，也不要写他转身走了；'
                '不要给出倾向，不要预写后果，把决定权原样留在那一秒。\n\n'
          : '';  // 保持原样，但确认没有额外开销（只在有实际锚点时生成字符串）

      // 安静期提示：检测最近几回合是否连续平淡，若连续3回合以上无转折，
      // 注入"本回合需要一点波澜"的指令，防止叙事陷入日常循环。
      // 审查 F6：停滞 forced 档已下发"必须换场景"的强指令，此时再注入
      // "来点小波澜"会形成两条长指令叠加，Agnes 注意力被分散——互斥跳过。
      final quietPeriodHint = level == StagnationLevel.forced
          ? ''
          : _buildQuietPeriodHint();

      return '''【世界上下文】
  $context

  ${statusTag.isNotEmpty ? '【状态】$statusTag\n' : ''}
  【当前场景】${worldState.timestamp}｜${worldState.currentLocation ?? '未知'}
  ${timeBudgetPromptLine(resolveActionCost(safeAction))}
  $sceneInfo
  ${buildContinuityBridgePromptLine()}
  $stagnationLine$anchorLine$causalLine$directorLine$quietPeriodHint
  ${extra.isNotEmpty ? '$extra\n' : ''}【玩家行动】
  $safeAction

${buildForwardConstraintBlock()}
${buildNarrativeRules(turn: turnCount)}
  ''';
    }

    try {
      // 场景转移图（替换仅前12回合生效的 _checkOpeningRailroad）
      //  - 开局家中/对角巷/国王十字/特快/分院/公共休息室/第一节课 全阶段通用
      //  - 所有地点切换强制检查进度门+时间门，不满足只注入衔接锚点，绝不硬切 location
      runSceneTransitionGraph();

      // 场景停滞检测：回合开始时比较地点，若未变则累加停滞计数
      // buildPrompt 会读取 turnsAtSameLocation 决定是否注入强制推进指令
      updateLocationTracking();

      String buildPromptInternal() => buildPrompt();
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
        _lastNarrativeDensity = density;
        _narrativeDensityHistory.add(_NarrativeDensityRecord(
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





  /// 无 AI 快速模式：完全不调用 AI，用本地模板叙事 + 承接式选项推进一整回合。
  /// 审查 P0「无 AI 快速模式 + 本地兜底剧情」：免费额度耗尽 / 未配 Key 时保底可玩。
  /// 与 AI 失败时的瞬时兜底不同：这里**消耗回合**（推进时间/精力/NPC/影响力），
  /// 因为这是玩家主动选择的正式离线玩法，而不是需要重试的失败。
  void _runOfflineQuickTurn(String action, {String? causalResult}) {
    // ===== 主线剧情模式分发（12 行，不改下面 129 行）=====
    //
    // 【为什么在顶部 return 而不是在里面加 if】
    // 下面那段是"沙盒兜底叙事"，逻辑完好、测试完备（batch33_offline_ux_test
    // 等十余个文件在钉它）。剧情模式的叙事来源、选项来源、推进方式**全都不同**，
    // 硬塞进去只会让两条路径互相污染——上一轮 `hookAnswer` 恒真的教训就在眼前。
    // 这里只做一件事：分流。沙盒路径一个字节都不动。
    if (storyProgress.active) {
      runStoryTurn(action, causalResult: causalResult);
      return;
    }

    // ====== P7 玩法意图路由：自然语言 → 完整玩法系统 ======
    // 在常规叙事组装**之前**拦截：玩家说「去打魁地奇」「找哈利决斗」时，
    // 本回合的正文应当就是那场完整的比赛/决斗，而不是一句「你向球场走去」
    // 的泛化兜底叙事。玩法函数内部已结算时间/精力/奖励、写好叙事与选项
    // 并落盘（_finishLocal），这里补上回合推进状态保持与正式回合一致。
    //
    // 【为什么不进常规叙事管道】玩法函数的叙事是**自成一体**的完整事件
    // （比分/战果/收获），再叠加兜底叙事只会互相覆盖；斜杠指令路径同样
    // 不经过叙事组装，两条玩法入口行为天然一致。原著节点注入仍是按
    // 游戏内日期触发的，下一回合叙事会自动补上，不会因玩法回合丢失。
    // 用 this. 显式从基类抽象成员解析：GamePlayMixin 覆写实现，
    // GameNarrativeMixin 自身不定义该方法，不带限定符会被分析器判为未定义。
    if (tryRouteGameplayIntent(action)) {
      commandResult = causalResult;
      error = null;
      turnCount++;
      lastScannedNarrativeHash = null;
      lastPlayerAction = action;
      notifyListeners();
      unawaited(autoSave());
      return;
    }

    // 与 AI 正式路径保持完全一致的「回合推进」状态。
    // 这些原本写在 processChoice 的正式分支里（commandResult / turnCount++ /
    // lastPlayerAction），而快速模式是在那之前 return 的，于是长期漏掉：
    //   ① turnCount 恒为 0 → directorBeatFor(turn:) 永远停在第一拍；
    //   ② `turnCount % 15 == 0` 而 0 % 15 == 0 恒真 → 摘要每回合都触发；
    //   ③ mixin_init 里 `id: 'meet_${npc.id}_$turnCount'` 在同一回合结识两名
    //      NPC 时会生成重复 id；
    //   ④ retryLastAction() 读的是 lastPlayerAction，会重试上一个行动；
    //   ⑤ commandResult 不赋值 → 因果抉择/留校答复的后果面板丢失。
    // 快速模式是同步执行的（没有 await 让出点），因此不需要 isLoading 并发守卫。
    commandResult = causalResult;
    error = null;
    turnCount++;
    lastScannedNarrativeHash = null;
    lastPlayerAction = action;

    // 地点停滞追踪：正式路径挂在 buildPrompt 里（生成叙事之前跑一次），
    // 离线模式不调 AI 就没有 buildPrompt，这里补上，否则同地点停滞检测
    // 在离线玩法下永远失效。
    updateLocationTracking();

    // ====== P10 奇遇结算（先于叙事组装）======
    // 上一回合触发的奇遇，在本回合用玩家的「奇遇:<id>:<idx>」动作结算结局。
    // 结算文本作为本回合的开篇，再接常规叙事——玩家先看到"你决定怎么做
    // 之后发生了什么"，再去过普通的一天。action 不匹配时混用兜底自动收尾。
    final hpResolution = tryResolveHappenstanceChoice(action);

    // ====== P11 羁绊最终幕结算（紧随奇遇之后、叙事组装之前）======
    // 上一回合让玩家做抉择的最终幕，本回合用玩家的「羁绊:<arcId>:<idx>」
    // 动作结算这出小戏的结局；action 不匹配时混用第一结局自动收尾。
    final companionResolution = tryResolveCompanionChoice(action);

    // ====== P13 回信结算（紧随羁绊之后、叙事组装之前）======
    // 上一回合收到的「待回信」，本回合用玩家的「信:<id>:<idx>」动作结算回信；
    // action 不匹配时混用中性兜底（中间项）自动收尾。
    final letterResolution = tryResolveLetterReplyChoice(action);

    currentNarrative = generateFallbackNarrative();
    if (companionResolution.isNotEmpty) {
      currentNarrative = '$companionResolution\n\n$currentNarrative';
    }
    if (hpResolution.isNotEmpty) {
      currentNarrative = '$hpResolution\n\n$currentNarrative';
    }
    if (letterResolution.isNotEmpty) {
      currentNarrative = '$letterResolution\n\n$currentNarrative';
    }

    // ====== 信息密度调节器：离线模式兜底叙事自动增强 ======
    {
      final density = calculateInformationDensity(currentNarrative);
      _lastNarrativeDensity = density;
      _narrativeDensityHistory.add(_NarrativeDensityRecord(
        turn: turnCount,
        density: density,
        isLow: density > 0.0 && density < 0.02,
        isOffline: true,
      ));
      if (density < 0.02 && density > 0.0) {
        debugLog('⚠️ [离线] 信息密度偏低: ${density.toStringAsFixed(4)}，自动增强');
        final p = player;
        if (p != null) {
          final location = worldState.currentLocation ?? '霍格沃茨';
          final weather = worldState.weather ?? '晴朗';
          final hour = worldState.time.hour;
          final timeDesc = hour < 6
              ? '深夜'
              : hour < 12
              ? '上午'
              : hour < 14
              ? '正午'
              : hour < 18
              ? '下午'
              : '傍晚';
          final eventSeed = turnCount;
          final eventLines = localEventLinesWithRoommates(
            location: location,
            hour: hour,
            seed: eventSeed,
          );
          final enhancement =
              '\n\n你环顾四周，$timeDesc的$location在$weather中显得格外宁静。'
              '${eventLines[eventSeed % eventLines.length]}';
          currentNarrative = currentNarrative.trimRight() + enhancement;
        }
      }
    }

    // 与 AI 正式路径同一套周期结算（详见 settleAfterNarrative 的注释）。
    // 表白会改写 currentNarrative 并写好「接受/婉拒」两个专属选项，
    // 这时候不能再用承接型兜底选项把它冲掉。
    final confessedThisTurn = settleAfterNarrative();

    finalizeTurn(currentNarrative, action);

    // ====== 离线模式补齐关键事件：将月度/学年事件融入叙事 ======
    // finalizeTurn → advanceTimeForAction → advanceWorldClock 已在上面触发
    // 了 checkMonthlyEvolution / checkEventAnchors 等事件检测，
    // 但事件文本只进了 notifications 列表，没有写进 currentNarrative。
    // 这里将最新的一条世界事件追加到叙事末尾，让离线模式也有"世界在动"的感觉。
    {
      final recentEvents = worldState.recentEvents;
      if (recentEvents.isNotEmpty) {
        // 找当前回合的最新事件（turnCount 匹配的）
        final turnEvents = recentEvents
            .where((e) => e.turn == turnCount)
            .toList();
        if (turnEvents.isNotEmpty) {
          final latestEvent = turnEvents.last.text;
          // 如果叙事末尾还没提到这个事件，追加进去
          // 取前 10~40 字作为探测片段；事件文本可能短于 10 字，
          // clamp(10,40) 对短文本会返回 10 导致 substring 越界崩溃（BUG-FIX），
          // 这里直接用「全文（≤40 字）或前 40 字」的探测片段。
          final probe = narrativeEventProbe(latestEvent);
          if (!currentNarrative.contains(probe)) {
            currentNarrative = '$currentNarrative\n\n$latestEvent';
          }
        }
      }
    }

    // ====== P9 年度节庆 ======
    // 放在世界事件补齐之后、原著节点注入之前：节日是「今天恰好是特别的日子」，
    // 应当紧接在氛围与月度事件后出现，再让原著大事续在后面。当天命中且本学年
    // 尚未庆祝过时，追加一段节庆文块并结算奖励、记档去重（详见 mixin_festival）。
    {
      final festivalBlock = celebrateFestival();
      if (festivalBlock.isNotEmpty) {
        currentNarrative = '$currentNarrative\n\n$festivalBlock';
      }
    }

    // ====== 原著剧情线注入（离线叙事升级）======
    // 离线模式以前只有「地点氛围句 + 学年日历事件」，读起来像在原地打转：
    // 世界不会因为处于 1993 年而提到小天狼星越狱，也不会因为是 1995 年
    // 而提到魔法部接管学校。这里接入原著时间线，让「年份」真正有分量。
    //
    // 三个关键点：
    //   1. 走 dueCanonEvents 纯函数，与 AI 路径的锚点机制**分离**——
    //      原著大事是「整个存档一次」，不同于 EventAnchor 的「每学年一次」，
    //      混用会让 1991 年发生过的密室在 1992 年又冒出来。
    //   2. 与 EventAnchor **共用** firedAnchorIds 做去重（id 带 `canon_` 前缀），
    //      避免两个系统各记一份、存档里出现同义的两套已触发集合。
    //   3. 每回合最多注入一条，与 checkEventAnchors 的节流口径一致。
    injectCanonEventLocally();

    // ====== P6 本地行动后果引擎 ======
    // 在叙事全部成型后结算玩家本回合行动的可见后果（学习/练咒/运动/打工/
    // 探索/休息/社交），把「【行动结果】…」段追加到叙事末尾。
    //
    // 【顺序】放在原著节点注入**之后**：节点是"世界发生了什么"，行动结果是
    // "你做了什么、世界怎么回应"，后者应当作为本回合的收尾呈现，也正好让
    // buildFallbackChoices 的承接式选项（读末尾 800 字）感知到行动成果。
    // 表白回合不受影响：后果段只是追加，不触碰「接受/婉拒」专属选项。
    {
      final result = settleOfflineConsequences(action);
      if (result.lines.isNotEmpty) {
        currentNarrative = '$currentNarrative\n\n【行动结果】${result.lines.join('')}';
      }
      for (final note in result.notes) {
        notifications.add(note);
        worldState.addNarrativeEvent(note, turn: turnCount);
      }
    }

    // ====== P14 校园社团活动触发 ======
    // 紧随行动结果之后：社团活动源自玩家本回合的离线行动（对得上社团干系事），
    // 自然是「行动结果」的同门收尾。加入的成员若行动里带着社团的干系事，就为
    // 社团积攒积分、跨阶晋升（候补→活跃→骨干→王牌→传奇）。自带冷却与互斥门控，
    // 不会被奇遇/羁绊/待回信抢跑，也不会天天刷屏。
    String? clubScene;
    if (!confessedThisTurn) {
      clubScene = maybeRunClubActivity(action);
    }
    if (clubScene != null && clubScene.isNotEmpty) {
      currentNarrative = '$currentNarrative\n\n$clubScene';
    }
    // P15 跨回合社团任务：行动命中干系事时推进任务进度（独立于日常积分冷却）。
    // 紧接社团活动后：任务进度提示是「你为社团出力」的延伸，自然收在同一段。
    if (!confessedThisTurn) {
      final taskNote = advanceClubTaskForAction(action);
      if (taskNote.isNotEmpty) {
        currentNarrative = '$currentNarrative\n\n$taskNote';
      }
    }

    // 【顺序很关键】兜底选项必须在**原著节点注入之后**才生成。
    // 原先这一行写在 finalizeTurn 之前，比注入早了两步，导致两个后果：
    //   1. 节点标题还没进 currentNarrative，buildFallbackChoices 拿到的
    //      末尾文本里根本没有事件，自然生成不出事件相关选项；
    //   2. `lastCanonEventTitle` 当时还是上一回合的旧值（或 null），
    //      选项侧读到的是过时信息。
    // 现在挪到注入之后，玩家能立刻对这个月刚发生的原著事件做出反应。
    // 表白那回合仍不覆盖——它有自己的「接受/婉拒」专属选项。

    // ====== P10 奇遇触发 ======
    // 放在所有叙事块之后、兜底选项之前：这是本回合最"贴近你"的一件事，
    // 场景应当浮在日程上方，并用自己的专属选项覆盖兜底承接选项。表白回合
    // 不触发（避免和「接受/婉拒」抢注意力）。奇遇自带冷却间隔，不会和节庆
    // 抢戏也不至于连续刷屏。
    String? hpScene;
    if (!confessedThisTurn) {
      hpScene = triggerHappenstance();
    }
    if (hpScene != null && hpScene.isNotEmpty) {
      currentNarrative = '$currentNarrative\n\n$hpScene';
    }

    // ====== P11 羁绊触发 ======
    // 紧随奇遇之后（奇遇为"落在我头上的小事"，羁绊为"我与某人的一岀戏"）。
    // 好感跨过门槛后这岀戏会跨回合慢慢演：前幕自动推进、最终幕记待抉择。
    // 奇遇进行中不抢戏；自带冷却，不会和节庆/奇遇连续刷屏。
    String? companionScene;
    if (!confessedThisTurn) {
      companionScene = maybeTriggerCompanion();
    }
    if (companionScene != null && companionScene.isNotEmpty) {
      currentNarrative = '$currentNarrative\n\n$companionScene';
    }

    // ====== P12 宠物小插曲触发 ======
    // 紧随羁绊之后（宠物是被动的一层小点缀，不像奇遇/羁绊那样有玩家抉择）。
    // 养的宠物偶尔在离线日常里冒出来：门槛低会重播的日常小插曲 + 亲和跨 25/55/85
    // 各演一次的羁绊里程碑。不结算回合，也没有选项，只让宠物"被看见"。奇遇/羁绊
    // 有待办时不抢戏；自带冷却，不会刷屏。
    String? petScene;
    if (!confessedThisTurn) {
      petScene = maybeTriggerPetStory();
    }
    if (petScene != null && petScene.isNotEmpty) {
      currentNarrative = '$currentNarrative\n\n$petScene';
    }

    // ====== P13 猫头鹰来信触发 ======
    // 紧随宠物之后（宠物是养在身边的小家伙，来信则是"世界那头的朋友"伸来的
    // 只言片语）。已结识 NPC 偶尔主动寄来一封：友情/敌对/里程碑。带问题的信会
    // 进入「待回信」，由下面的选项作主。有奇遇/羁绊/待回信时不抢戏；自带冷却。
    String? letterScene;
    if (!confessedThisTurn) {
      letterScene = maybeTriggerLetter();
    }
    if (letterScene != null && letterScene.isNotEmpty) {
      currentNarrative = '$currentNarrative\n\n$letterScene';
    }

    if (!confessedThisTurn) {
      choices = buildFallbackChoices(currentNarrative);
      // 优先让「羁绊最终幕」用它的抉择选项覆盖承接选项（它是更个人的一岀戏），
      // 其次才是奇遇的专属选项。玩家下回合据此真正"决定这场戏怎么收场"。
      final companionChoices = companionChoicesForPending();
      if (companionChoices.isNotEmpty) {
        choices = companionChoices;
      } else {
        final hpChoices = happenstanceChoicesForPending();
        if (hpChoices.isNotEmpty) {
          choices = hpChoices;
        } else {
          // P13 回信选项优先级最低：一封待回的信，不抢奇遇/羁绊的正戏。
          final replyChoices = letterReplyChoicesForPending();
          if (replyChoices.isNotEmpty) {
            choices = replyChoices;
          }
        }
      }
    }

    maybeRunPeriodicSummary();
    error = null;
    loadingStage = '';
    isLoading = false;
    notifyListeners();
    unawaited(autoSave());

    // ====== 可选 AI 润色（异步，不阻塞本地回合）======
    // 本地叙事先成型、先落盘，再在后台用少量 AI 润色措辞；成功才替换展示文本
    // 并二次落盘，失败/超时/取消一律保留原文，绝不把「润色」变成新的断点。
    unawaited(_maybePolishLocalNarrative());
  }

  /// 可选「AI 润色」：对本回合已生成的本地叙事做一次轻量措辞润色。
  ///
  /// 【红线】本地模式核心仍是 0 AI——本方法只在 `narrativePolishEnabled`
  /// 已开启 **且** 当前叙事确实来自本地时才触发；任何异常都静默回退原文。
  @visibleForTesting
  Future<String?> polishLocalNarrativeForTest(String text) =>
      _maybePolishLocalNarrative(textOverride: text);

  Future<String?> _maybePolishLocalNarrative({String? textOverride}) async {
    final polishEnabled = appProvider.narrativePolishEnabled;
    if (!polishEnabled) return null;
    // 主动离线或自动降级到本地时才有润色价值；AI 路径的叙事本身已是 AI 生成。
    if (effectiveNarrativeSource != NarrativeSource.local) return null;
    final router = this.router;
    if (router == null || !router.hasNarrativeService) return null;

    final source = textOverride ?? currentNarrative;
    if (source.trim().isEmpty) return null;

    // 节流：距上次润色至少间隔 5 回合（测试直调 textOverride 时绕过）。
    // 润色是后台可选增强，逐回合触发只会把「省 Key 的本地模式」重新变成
    // 悄悄烧 Key（审批 3.1）。
    if (textOverride == null && turnCount - _lastPolishTurn < 5) return null;

    // 会话纪元 + 回合双校验：润色是异步的，期间玩家可能已读完档重开
    // 或推进了下一回合——旧回合的润色结果不得覆盖当前叙事（审批 3.1）。
    final int epoch = sessionEpoch;
    final int polishTurn = turnCount;
    final where = worldState.currentLocation ?? '霍格沃茨';

    try {
      final result = await router.chatComplete(
        scene: AiScene.narrative,
        temperature: 0.7,
        maxTokens: 900,
        // 润色失败不写叙事 Key 熔断：可选增强不该把健康 Key 记上冷却（审批 3.1）。
        trackCircuit: false,
        prompt: '''
你是一名哈利·波特世界的文字润色师。下面是本地引擎生成的一段剧情叙事。
请只润色措辞、节奏与感染力，让段落更像真人执笔的文学叙事；不得改变情节走向、人物设定、已发生的事实，也不得新增或删减关键信息。用简体中文，直接输出润色后的段落，不要加任何点评或前言。

【地点】$where

【原叙事】
$source
''',
      );
      final polished = result.content.trim();
      if (polished.isEmpty) return null;
      if (textOverride == null) {
        // 返回时若会话已重开（epoch 变化）或回合已推进，丢弃这次润色结果。
        if (epoch != sessionEpoch || polishTurn != turnCount) return null;
        currentNarrative = polished;
        _lastPolishTurn = turnCount;
        notifications.add('✨ 本地叙事已由 AI 润色');
        error = null;
        notifyListeners();
        unawaited(autoSave());
      }
      return polished;
    } catch (e) {
      debugLog('⚠️ ⚠️ 润色失败，保留本地原文: $e');
      return null;
    }
  }

  /// 把命中的原著剧情节点融进离线叙事（`_runOfflineQuickTurn` 调用）。
  ///
  /// 【为什么单独抽成方法而不是内联】它有三条需要被单测直接钉住的规则
  /// （时代过滤 / 一次性触发 / 每回合最多一条），内联在 1300 行的方法里
  /// 就只能靠"跑整个离线回合"间接验证，定位失败原因成本很高。
  @visibleForTesting
  void injectCanonEventForTest() => injectCanonEventIntoOfflineNarrative();

  static final RegExp _reAcquaintanceKeywords = RegExp(
      r'(结识|认识了|正式见面|成为朋友|初见了)',
      caseSensitive: false);

  static final RegExp _reCombatKeywords =
      RegExp(r'(战斗|决斗|攻击|防御|施展咒语|施法|黑魔法|施咒|念咒|反击)');

  static final RegExp _reStudyKeywords =
      RegExp(r'(上课|考试|测验|作业|复习|学习|论文|写论文|做功课)');

  static final RegExp _reRomanceKeywords =
      RegExp(r'(约会|表白|心动|拥抱|接吻|单独见面|私聊)');

  static final RegExp _reEconomyKeywords =
      RegExp(r'(购买|出售|购物|交易|取钱|存钱|存取古灵阁)');





  String _buildCriticalContext(String action) {
    final p = player;
    if (p == null) return '';
    final a = action.toLowerCase();
    final parts = <String>[];

    // 战斗/冲突 → 注入关键属性、魔咒、HP
    if (a.contains(_reCombatKeywords)) {
      final combatAttrs = p.attributes.entries
          .where((e) => e.value != 0)
          .take(3)
          .map((e) => '${attrLabel(e.key)}:${e.value}')
          .join(' ');
      if (combatAttrs.isNotEmpty) parts.add('【战斗】$combatAttrs');
      if (p.learnedSpells.isNotEmpty) {
        final spells = p.learnedSpells.entries
            .take(3)
            .map((e) => e.key)
            .join('、');
        parts.add('魔咒:$spells');
      }
      parts.add('HP:${p.health} MP:${p.magic}');
    }

    // 学业/考试 → 注入相关属性
    if (a.contains(_reStudyKeywords)) {
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
      final affs = mentioned
          .take(2)
          .map((n) => '${n.name}:好感${n.affection}(${n.affectionStage})')
          .join('；');
      parts.add('【关系】$affs');
    } else if (a.contains(_reRomanceKeywords)) {
      final affs = formatAffections(maxEntries: 2);
      if (affs.isNotEmpty && !affs.contains('暂无深入关系')) parts.add('【关系】$affs');
    }

    // 购物/交易 → 注入金币和前3背包物品
    if (a.contains(_reEconomyKeywords)) {
      parts.add('【经济】加隆:${p.galleons} 银行:${p.bankGalleons}');
      if (p.inventory.isNotEmpty) {
        final inv = p.inventory.take(3).map((e) => e.name).join('、');
        parts.add('背包:$inv');
      }
    }

    return parts.isNotEmpty ? '【状态】\n${parts.join('\n')}' : '';
  }

  /// 导演节拍器的低张力场景判定：这些时刻转折概率减半。
  ///
  ///  - 暑假（term == 'summer'）：城堡空了，人都不在，强插冲突没有落点；
  ///  - 考试季（5-6 月）：叙事张力天然拉满，再来意外是叠加不是节奏；
  ///  - 深夜（23:00-06:00）：宵禁后的独处时段，适合让人物喘口气。
  ///
  /// 注意是"概率减半"不是"禁止转折"——低张力场景偶尔来一下反而是好的，
  /// 完全禁掉就成了另一种可预测的机械规则。
  bool _isCalmNarrativeContext() {
    final t = worldState.time;
    if (worldState.term == 'summer') return true;
    if (t.month == 5 || t.month == 6) return true;
    if (t.hour >= 23 || t.hour < 6) return true;
    return false;
  }

  /// 检测最近几回合的叙事节奏，生成安静期提示。
  /// 如果连续 3 回合以上没有转折（director beat 为 turn），
  /// 注入"本回合需要一点波澜"的指令，防止叙事陷入日常循环。
  String _buildQuietPeriodHint() {
    // 如果最近一次转折回合数缺失（开局），跳过
    if (turnsSinceLastTurnBeat < 0) return '';

    // 连续 5 回合以上无转折 → 更强提示
    if (turnsSinceLastTurnBeat >= 5) {
      return '\n📌 【安静期提示】已经连续 $turnsSinceLastTurnBeat 回合没有转折，'
          '本回合必须发生一件实质性的事件——可以是新情报、新冲突、新人物登场，'
          '或者一个旧悬念的重新浮现。不能让剧情继续在原地打转。\n\n';
    }

    // 连续 3 回合无转折 → 提示注入小波澜
    if (turnsSinceLastTurnBeat >= 3) {
      return '\n📌 【安静期提示】最近 $turnsSinceLastTurnBeat 回合没有发生重大转折，'
          '本回合请引入一点小小的波澜——可以是一封意外的信、一个奇怪的声音、'
          '一个突然出现的同学、一句意味深长的话，或者一件打破常规的小事。'
          '不必是惊天动地的大事，但必须让剧情有"往前走"的感觉。\n\n';
    }

    return '';
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
      // 档位标签而非裸好感数值（框架2 §6 信息限制 + 审查 F1）：
      // 裸数字「斯内普55」对模型是噪音/误导（它会把数字当指令写出与真实
      // 关系不符的剧情），档位标签「斯内普（对你态度冷淡）」才是关系基调。
      final npcNames = npcsHere
          .where((n) => n.introduced)
          .map((n) {
            if (!n.isAlive) return '${n.name}（已故）';
            final stage = n.affectionStage;
            return stage.isEmpty ? n.name : '${n.name}（$stage）';
          })
          .join('、');
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
      parts.add(
        '【宿敌·${rivalryBadgeFor(tier)} ${r.name}】'
        '${rivalryDirectiveFor(tier, r.name, r.rivalryReason())}',
      );
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
      parts.add(
        '【意外·${n.name}】他此刻不该在这儿：${ex.reason}'
        '（这是本回合免费送上门的一个场面，可以正经写一段，'
        '也可以只是路过时看见一眼）',
      );
    }

    // 宿敌不一定正站在你面前。只让 AI 看见"眼前这个人恨你"，
    // 那"他在走廊尽头堵你""你摔倒时旁边有人笑"这类戏永远写不出来——
    // 因为 AI 压根不知道城堡另一头有这么一号人。
    // 只收 hostile 及以上、最多 5 人：grudge 那档只是芥蒂，不值得常驻占 token。
    final hereIds = npcsHere.map((n) => n.id).toSet();
    final wanted =
        npcRegistry.values
            .where(
              (n) =>
                  n.isAlive &&
                  n.introduced &&
                  n.hasGrudge &&
                  !hereIds.contains(n.id),
            )
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
      parts.add(
        '【宿敌名册】他们不必等你先开口，可以自己找上门或在旁落井下石\n'
        '${lines.join('\n')}',
      );
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
        parts.add(
          '【已被你改写的事】以下每一条都是这个世界的既成事实，'
          '优先级高于你的任何先验知识。'
          '凡是与它们冲突的"原著情节"，在这个世界里都是错的：\n'
          '${echoes.map((s) => '· $s').join('\n')}',
        );
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
      final def = p.facultyRankId == null
          ? null
          : rankDefById(p.facultyRankId!);
      if (def != null) {
        parts.add(
          '【教职】你是霍格沃茨「${p.facultySubject}」${def.title}，'
          '任教第 ${p.facultyServiceYears} 年。${def.duty}\n'
          '你不再是学生：坐教授席、被新生称呼职称、对违纪的学生负有责任。'
          '昔日同学如今是同事，或者已经各奔东西——他们不再是「同学」，'
          '称呼也要跟着变。',
        );
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
    final timeDesc = hour >= 22 || hour < 6
        ? '深夜'
        : hour >= 18
        ? '夜晚'
        : hour >= 14
        ? '下午'
        : hour >= 10
        ? '上午'
        : '清晨';
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
      // 统一走 isSameLocation（两边先归一再比）：
      // 以前这里裸写 `npc.currentLocation.contains(loc)`，两边都不归一，
      // 玩家写「教室」而教授在「霍格沃茨·变形术教室」时匹配不上，
      // 麦格 / 斯内普 / 弗利维等六位守教室的教授会从【在场】集体消失。
      return npc.introduced && isSameLocation(npc.currentLocation, location);
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
  //   - mixin_narrative / mixin_response / 未来其他 mixin 调用统一出口，不会出现各自 if 版本不一致；
  //   - "停滞 → 强制推进文案" 从 buildPrompt 里解耦出来，可单独单测。
  //
  // 旧 API（stagnationThresholdFor / narrativeHasUnresolvedHook）
  // 保持对外不变：内部委托给 StagnationDetector，不会破坏 GameProviderBase 的 abstract 签名。
  // isLocationExemptFromStagnation 已移除：判定收敛进 evaluate 后没有任何调用者。
  // ============================================================

  static const StagnationDetector _stagnation = StagnationDetector.instance;

  @override
  int stagnationThresholdFor(String location) =>
      _stagnation.thresholdFor(location);
  @override
  bool narrativeHasUnresolvedHook(String narrative) =>
      _stagnation.hasUnresolvedHook(narrative);


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

  /// 去重用的空白折叠正则，预先编译，避免在候选过滤循环里反复构造。
  static final RegExp _collapseWs = RegExp(r'\s+');

  /// 锚点去重时剥掉事件前缀图标。原先在两个 for 循环里各写一份，
  /// 每个事件都重新编译一次。
  static final RegExp _anchorIconPrefix = RegExp(
    r'^([\u{1F4CA}\u{1F464}\u{1F4AC}\u{1F4C5}\u{1F3C6}\u{1F31F}\u{1F4F0}])',
    unicode: true,
  );

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
class _NarrativeDensityRecord {
  final int turn;
  final double density;
  final bool isLow;
  final bool isOffline;

  const _NarrativeDensityRecord({
    required this.turn,
    required this.density,
    required this.isLow,
    required this.isOffline,
  });

  @override
  String toString() =>
      '[turn=$turn] density=${density.toStringAsFixed(4)} isLow=$isLow offline=$isOffline';

}