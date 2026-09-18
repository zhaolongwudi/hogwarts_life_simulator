import 'dart:async';
import 'dart:math';
import '../data/command_registry.dart';
// 只取 kDebugMode：给 _closeLoopIfMatched 的热路径日志加 `if (kDebugMode)`
// 保护时漏了这个 import，整包 analyze 直接红——典型的「改了 A 没改它的
// 对称面 B」（第八次审查 §4）。
import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
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
import '../narrative/narrative_source_gate.dart';
import '../data/locations.dart';
import '../data/attribute_data.dart';
import '../data/course_data.dart';
import '../data/director_beat_data.dart';
import '../data/foreshadow_data.dart';
import '../data/scar_data.dart';
import '../data/era_data.dart';
import '../data/faculty_data.dart';
import '../data/game_config_rules.dart';
import '../data/canon_events.dart';
import '../data/item_data.dart';
import '../data/collection_data.dart';
import '../models/story_progress.dart';
import 'mixin_systems.dart';
import '../data/narrative_time_rules.dart';
import '../data/rivalry_data.dart';
import '../data/time_cost_rules.dart';
import '../data/wand_data.dart';
import '../data/pet_data.dart';
import '../data/worldline_data.dart';
import '../data/monthly_event_data.dart';
import '../data/npc_schedule_rules.dart';
import '../data/parallel_data.dart';
import '../prompts/narrative_prompts.dart';
import '../prompts/summary_prompts.dart';
import 'mixin_narrative_continuity.dart';
import 'mixin_play.dart';
import '../utils/debug_log.dart';

/// 情报 token 归一化：剥掉下划线与所有非文字字符（`_composeCausalText` 用）。
///
/// 【为什么提为文件级】它在 `_composeCausalText` 的循环里逐条情报调用，
/// 而本仓库有源码形状守卫（`test/regex_hotpath_test.dart`）专门禁止
/// "循环内现编译 RegExp"。这条守卫曾抓出过真实的性能回归，不是风格洁癖。
final RegExp _reNonWordChars = RegExp(r'[_\W]+');

mixin GameNarrativeMixin on GameProviderBase, GameNarrativeContinuityMixin {
  /// 上一回合的叙事信息密度（0.0 ~ 1.0），用于调试与调优
  double _lastNarrativeDensity = 0.0;

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
        final cmdHead = slashless.split(RegExp(r'\s+')).first;
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
      final aptitudeForPrompt = effectiveAptitude.isEmpty
          ? '普通'
          : effectiveAptitude;

      final profileLine =
          '【档案】${p.name}·${p.house ?? '未分院'}·${p.grade}年·天赋$aptitudeForPrompt·精神${p.spirit}·精力${p.energy}';
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
      t0.removeWhere((f) => _factConflictsWithAuthority(f.fact));
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
      int _t3Cmp(WorldEventRecord a, WorldEventRecord b) {
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
      ).where((e) => ts - e.absoluteDay <= 60).toList()..sort(_t3Cmp);
      final oldEvents = List<WorldEventRecord>.from(
        memory.worldEvents,
      ).where((e) => ts - e.absoluteDay > 60).toList()..sort(_t3Cmp);
      final t3 = <WorldEventRecord>[
        ...recentEvents.take(30),
        ...oldEvents.take(10),
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
        final clean = text.replaceAll(RegExp(r'^[^\u4e00-\u9fa5A-Za-z]*'), '');
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
        if (RegExp(
              r'(结识|认识了|正式见面|成为朋友|初见了)',
              caseSensitive: false,
            ).hasMatch(clean) ||
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
            if (worldAnchors.length >= 12) break;
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
            if (worldAnchors.length >= 16) break;
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
  ${extra.isNotEmpty ? extra + '\n' : ''}【玩家行动】
  $safeAction

${buildForwardConstraintBlock()}
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
          response = (await callDeepSeek(currentPrompt)).content;
        } on AiNonRetryableException {
          rethrow;
        } on AiCanceledException {
          // Q5：用户取消 → 不重试（重试会立刻再发起一次新请求），直接上抛。
          rethrow;
        } catch (e) {
          loadingStage = '请求失败，正在重试...';
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 500));
          // 重试前强化指令：要求直接输出纯正文，禁止空行/前言/解释
          currentPrompt =
              '$prompt\n\n⚠️【重试指令】上一轮返回为空或不合规，请直接输出当前回合的剧情正文（中文纯文本），不要任何前言、解释、空行、Markdown 或代码块标记。';
          response = (await callDeepSeek(currentPrompt)).content;
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
            '⚠️ 叙事 critical 级异常，准备重试（剩余${retriesLeft}次）：${msgs.take(3).join(" | ")}',
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
      // 结算本体抽到 _settleAfterNarrative，与无 AI 快速模式共用同一份——
      // 第五轮只把「状态推进」搬去了离线路径，周期结算一项没搬。
      final bool confessedThisTurn = _settleAfterNarrative();

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

      // 收尾落库（与离线快速模式共用，见 _finalizeTurn）：
      // ContinuityBridge Step A —— 把本回合叙事的末尾锚点存档，下回合强制衔接。
      // 注意：先同步 location（_syncLocationFromNarrative）后再 saveAnchor，
      // 确保 location 锚点是最新的。
      _finalizeTurn(currentNarrative, action);
      // 锚点已成功注入本回合剧情，清除待注入状态（仅当未被新锚点替换时）
      if (consumedAnchor != null && pendingAnchorDirective == consumedAnchor) {
        pendingAnchorDirective = null;
      }

      _maybeRunPeriodicSummary();

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
      loadingStage = '';
      if (isLoading) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  /// 叙事定稿之后、选项生成之前的周期结算。返回本回合是否有人表白。
  ///
  /// AI 正式路径与无 AI 快速模式共用同一份，原因很实在：第五轮把「状态推进」
  /// （turnCount++ / lastPlayerAction / commandResult）搬进了离线路径，却把
  /// 周期结算整个漏掉了，于是离线玩法下
  ///   · NPC 主动表白永不触发（恋爱线是核心玩法）；
  ///   · 世界线变动率恒为 0.5%，world_changer 成就永远拿不到；
  ///   · 同地点停滞检测失效（_updateLocationTracking 只挂在 buildPrompt 里，
  ///     离线不调 AI 就永远走不到）。
  /// 抽成方法之后，一边加结算另一边自动跟上。
  bool _settleAfterNarrative() {
    final bool confessedThisTurn = _maybeTriggerConfession();
    _tickWorldLineDeviation();
    // 坏结局二「自由尽失」：黑魔法声望压过道德底线时，回合结算触发被捕
    // （内部自带 isDead/isImprisoned/无敌/年级 前置判定，无条件满足不动作）
    checkImprisonment();

    // 从叙事文本中提取新地点并同步 currentLocation
    // 这是「场景推进」的闭环：AI 写了换场景 → 状态同步 → 停滞计数清零
    // 否则 currentLocation 永远停在初始值，AI 会以为玩家还在原地
    _syncLocationFromNarrative(currentNarrative);

    // --- P0-2 短期断言：从本回合叙事末尾提取生效状态，下回合 Prompt 必注入 ---
    final newAssertions = extractShortAssertions(currentNarrative);
    rotateTurnAssertions(newAssertions);
    return confessedThisTurn;
  }

  /// 回合收尾落库：锚点、摘要缓冲、近期回合、时间/精力、NPC、影响力。
  ///
  /// 与 [_settleAfterNarrative] 一起构成「一整个回合」的后半段，
  /// 两条路径必须共用（理由同上）。
  ///
  /// [storyTimeCostDays] 非空时走**章节节拍式时间**：直接按显式天数推进，
  /// 不做行动关键词推断。为什么剧情模式必须这样：
  ///   · `advanceTimeForAction` 按关键词猜时长（"去图书馆查资料"可能算半天），
  ///     剧情 8 章只该跨几个月，猜出来的时间会让原著节点的月份整体错位；
  ///   · `fastForwardDays` 内部走 `_advanceWorldClock` 全量结算（游戏周/
  ///     学院杯/NPC 位置/学年推进/事件锚点/月度演化），语义比"猜时长"精确得多。
  /// 把一回合的剧情节拍压成一段**给关键词系统读的中文行动串**。
  ///
  /// 【为什么需要它】见 `_finalizeTurn` 里 `semanticAction` 的说明：
  /// 剧情模式的 action 是机器编码，直接喂给 `updateNPCsFromAction` /
  /// `updatePlayerImpactScore` 会让关键词判定全部落空。
  ///
  /// 【拼装口径】按"信息量从高到低"取三样：
  ///   1. 玩家选的那句行动（`StoryChoiceDef.text`）——最接近玩家意图；
  ///   2. 选择结果（`consequence`）——原著 NPC 名字与事件多出现在这里；
  ///   3. 已解锁的情报 id（`addKnowledge`）——把"知道了密室"这类状态
  ///      转成关键词可命中的文本（下划线替换成空格）。
  ///
  /// 三者按空格拼成一段，不去重也不截断：下游三个函数都只做 `contains`，
  /// 串长对它们没有性能影响（每回合一次）。
  ///
  /// 【跳步场景的兜底】自由插话（`isFreeformInterjection`）与结局回合
  /// 没有 choice，用玩家原文 + 叙事首段兜底——玩家自己打的字本来就是
  /// 最真实的行为描述。都没有时回落到 [fallback]（编码 action），
  /// 保持与改动前完全一致的行为，不会因为本函数让任何路径变差。
  String _semanticActionOf(StoryBeat beat, String fallback) {
    final buf = <String>[];

    final freeform = beat.freeActionText;
    if (freeform != null && freeform.trim().isNotEmpty) {
      buf.add(freeform.trim());
    }

    final choice = beat.choice;
    if (choice != null) {
      buf.add(choice.text);
      if (choice.consequence.trim().isNotEmpty) {
        buf.add(choice.consequence.trim());
      }
    }

    final step = beat.step;
    if (step != null) {
      // onEnterText 是"进入这一步时世界发生的事"，往往写着原著事件名；
      // setup 是情境，行长但关键词密度高，同样值得进串。
      final enter = step.onEnterText;
      if (enter != null && enter.trim().isNotEmpty) buf.add(enter.trim());
      if (step.setup.trim().isNotEmpty) buf.add(step.setup.trim());
    }

    final joined = buf.join(' ').trim();
    return joined.isEmpty ? fallback : joined;
  }

  void _finalizeTurn(
    String narrative,
    String action, {
    int? storyTimeCostDays,
    String? semanticAction,
  }) {
    // ⓪ 图鉴收录（见 data/collection_data.dart）：扫描本回合叙事，命中
    // 新条目时把一行提示追加到叙事尾部——放在锚点/摘要**之前**，让收录
    // 提示随本回合文本一并入档，而不是悄悄消失。
    final collectionHint = _scanCollectionUnlocks(narrative);
    if (collectionHint != null) {
      narrative = '$narrative\n$collectionHint';
      currentNarrative = narrative;
    }
    saveContinuityAnchor(narrative);
    accumulateForSummary(narrative);
    appendRecentTurn(narrative);

    // 【语义行动串：为什么必须换掉 action】
    //
    // 剧情模式的 `action` 是 `@@story:<stepId>:<choiceId>@@` 这种**机器编码**
    // （见 `encodeStoryAction`：这是唯一能穿过存档通道的载体）。可下游有三个
    // 系统是**按中文关键词**做判断的：
    //   · `advanceTimeForAction` —— 猜本回合耗时；
    //   · `updateNPCsFromAction` —— 精力/饱食/精神消耗与恢复；
    //   · `updatePlayerImpactScore` —— 提及原著 NPC 加分、原著大事关键词加分。
    // 把编码串喂进去，`action.contains('哈利')` 这类判定**永远为假**：
    // 玩家在剧情里和赫敏一起复习了十次，影响力分数里一次都没算过。
    // 剧情模式的时间推进本来就走 `storyTimeCostDays` 绕过关键词，但 NPC 与
    // 影响力这两条没有旁路，于是整条"剧情 → 世界"的接线是**断的**。
    //
    // 【为什么用语义串而不是直接传中文选项文案】
    // 选项文案（`StoryChoiceDef.text`）本身就是给玩家读的中文行动句
    // （"夜里循着传闻找到那间教室"），它天然承载了关键词。但**跳过步数的
    // 场景**（自由插话、结局后行动、自动开新书）没有 choice，回落到 action。
    // 拼接 consequence 而不是只给 text，是因为 consequence 里才会出现
    // NPC 名字与事件名（"你和纳威一起…"），这才是加分项的真正来源。
    final effectAction = (semanticAction != null && semanticAction.trim().isNotEmpty)
        ? semanticAction
        : action;

    if (storyTimeCostDays != null && storyTimeCostDays > 0) {
      // 【为什么显式转型】`fastForwardDays` 实现在 `GameSystemsMixin`，
      // 本项目实测：即使它已在 `GameProviderBase` 上声明，在
      // `GameNarrativeMixin` 里裸写名字仍报 `undefined_method`。
      // 既有的 `/快进` 指令（`mixin_commands.dart:90`）用的就是
      // `gm.fastForwardDays(days)` 这一显式转型写法——跟随既有口径，
      // 而不是再造第三种调用方式。
      (this as GameSystemsMixin).fastForwardDays(storyTimeCostDays);
    } else {
      advanceTimeForAction(effectAction);
    }
    updateNPCsFromAction(effectAction);
    updatePlayerImpactScore(effectAction);
  }

  /// 扫描一段叙事文本，把新命中的图鉴条目收录进 [collectionUnlocked]，
  /// 返回给玩家的收录提示行（无新收录时返回 null）。
  ///
  /// 【为什么挂在 _finalizeTurn】剧情模式（`_advanceStory`）与沙盒模式
  /// 最后都汇进 `_finalizeTurn` 收尾——一处钩子，两条路径全覆盖。
  /// 只扫**本回合新增**文本：老内容反复被引用也不会重复提示（集合去重），
  /// `matchCollection` 是纯函数（~60 条 × contains），每回合一次开销可忽略。
  String? _scanCollectionUnlocks(String text) {
    final fresh = matchCollection(text).difference(collectionUnlocked);
    if (fresh.isEmpty) return null;
    collectionUnlocked.addAll(fresh);
    final names =
        fresh.map((id) => collectionById(id)?.name ?? id).toList()..sort();
    final shown = names.take(3).join('、');
    final extra = names.length > 3 ? ' 等 ${names.length} 条' : '';
    return '✦ 图鉴收录：$shown$extra（/图鉴 查看）';
  }

  /// 定期摘要：v5 复查(P1)回调到每20回合，缓冲提前阈值 6800 字。
  /// 配合 _maxPendingSummaryChars=8000，每次摘要覆盖更长时间线，摘要调用频次
  /// 相对旧值(15回合)约省 25%，且因 Q4 输入分层压缩输入 token 有上限。
  ///
  /// 单独抽出来是因为它是长期记忆（T0/T1/T3）的**唯一生产者**：
  /// 离线路径以前根本不调它，纯离线玩 200 回合后记忆库只剩开局那几条。
  void _maybeRunPeriodicSummary() {
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
              : 6,
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
          importance: 5,
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
          importance: 4,
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
  LongTermMemory _closeStaleOfflineLoops() {
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
  ///
  /// 触发条件（满足其一）且缓冲非空：
  ///   · 回合数到达 [kSummaryIntervalTurns] 的整数倍；
  ///   · 待摘要字数超过 [kSummaryEarlyTriggerChars]（长剧情提前压缩）。
  ///
  /// 【失败退避】[consecutiveFails] > 0 时**不触发**，直到
  /// [cooldownRemaining] 归零。修复前的时序缺陷是：
  /// 摘要失败会把 chunk 原样还回缓冲（`:1613` 等），缓冲立刻又满足
  /// 「字数 > 阈值」→ 下一回合立即重试 → 再失败。在配额耗尽/服务不可用时，
  /// 这形成"每回合烧一次失败调用"的风暴，正是免费按次配额最怕的形态。
  ///
  /// 退避长度随连续失败次数线性增长（见 [kSummaryFailCooldownTurns]），
  /// 上限 [_summaryFailCooldownMaxTurns]，避免长局把摘要永久停掉。
  ///
  /// 【关于"或"关系】`turnCount % N == 0` 与字数阈值是**或**关系，
  /// 而正常叙事 600-800 字/回合 → 约 9~11 回合就会由字数分支触发，
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
      _runStoryTurn(action, causalResult: causalResult);
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
    if (this.tryRouteGameplayIntent(action)) {
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
    _updateLocationTracking();

    // ====== P10 奇遇结算（先于叙事组装）======
    // 上一回合触发的奇遇，在本回合用玩家的「奇遇:<id>:<idx>」动作结算结局。
    // 结算文本作为本回合的开篇，再接常规叙事——玩家先看到"你决定怎么做
    // 之后发生了什么"，再去过普通的一天。action 不匹配时混用兜底自动收尾。
    final hpResolution = this.tryResolveHappenstanceChoice(action);

    // ====== P11 羁绊最终幕结算（紧随奇遇之后、叙事组装之前）======
    // 上一回合让玩家做抉择的最终幕，本回合用玩家的「羁绊:<arcId>:<idx>」
    // 动作结算这出小戏的结局；action 不匹配时混用第一结局自动收尾。
    final companionResolution = this.tryResolveCompanionChoice(action);

    currentNarrative = generateFallbackNarrative();
    if (companionResolution.isNotEmpty) {
      currentNarrative = '$companionResolution\n\n$currentNarrative';
    }
    if (hpResolution.isNotEmpty) {
      currentNarrative = '$hpResolution\n\n$currentNarrative';
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
          final eventLines = localEventLinesFor(
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

    // 与 AI 正式路径同一套周期结算（详见 _settleAfterNarrative 的注释）。
    // 表白会改写 currentNarrative 并写好「接受/婉拒」两个专属选项，
    // 这时候不能再用承接型兜底选项把它冲掉。
    final confessedThisTurn = _settleAfterNarrative();

    _finalizeTurn(currentNarrative, action);

    // ====== 离线模式补齐关键事件：将月度/学年事件融入叙事 ======
    // _finalizeTurn → advanceTimeForAction → _advanceWorldClock 已在上面触发
    // 了 _checkMonthlyEvolution / _checkEventAnchors 等事件检测，
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
      final festivalBlock = this.celebrateFestival();
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
    //   3. 每回合最多注入一条，与 _checkEventAnchors 的节流口径一致。
    _injectCanonEventIntoOfflineNarrative();

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

    // 【顺序很关键】兜底选项必须在**原著节点注入之后**才生成。
    // 原先这一行写在 _finalizeTurn 之前，比注入早了两步，导致两个后果：
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
      hpScene = this.triggerHappenstance();
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
      companionScene = this.maybeTriggerCompanion();
    }
    if (companionScene != null && companionScene.isNotEmpty) {
      currentNarrative = '$currentNarrative\n\n$companionScene';
    }

    if (!confessedThisTurn) {
      choices = buildFallbackChoices(currentNarrative);
      // 优先让「羁绊最终幕」用它的抉择选项覆盖承接选项（它是更个人的一岀戏），
      // 其次才是奇遇的专属选项。玩家下回合据此真正"决定这场戏怎么收场"。
      final companionChoices = this.companionChoicesForPending();
      if (companionChoices.isNotEmpty) {
        choices = companionChoices;
      } else {
        final hpChoices = this.happenstanceChoicesForPending();
        if (hpChoices.isNotEmpty) {
          choices = hpChoices;
        }
      }
    }

    _maybeRunPeriodicSummary();
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

    final where = worldState.currentLocation ?? '霍格沃茨';

    try {
      final result = await router.chatComplete(
        scene: AiScene.narrative,
        temperature: 0.7,
        maxTokens: 900,
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
        currentNarrative = polished;
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
  void injectCanonEventForTest() => _injectCanonEventIntoOfflineNarrative();

  /// 直接落一份剧情效果（测试用）。
  ///
  /// 【为什么需要】`_applyStoryEffect` 的新接线字段（openLoops / addQuests /
  /// addWorldEvents / unlockCgs / energy / satiety）目前只有运行时路径会走到，
  /// 而运行时路径必须先有内容层声明这些字段——内容层还没铺到那儿时，
  /// 接线本身就成了"没有测试覆盖的代码"。这个入口让接线可以被**独立**钉死，
  /// 不必等 102 个节点的内容全部补完。
  @visibleForTesting
  void applyStoryEffectForTest(StoryEffect effect) =>
      _applyStoryEffect(effect);

  /// 直接广播一条原著节点的沉淀物（测试用）。
  ///
  /// 【为什么需要】`_sinkCanonNodeToMemory` 的悬念分支（openLoop / closeLoops）
  /// 过去只有**数据层**断言兜着——「开过的都能对上关节点」这种表内自洽检查
  /// 证明不了运行时分支被走到过。结果四条悬念开了从未被关，静默悬了一整个
  /// 学年才被发现。这个入口让悬念的开→关生命周期可以被独立钉死。
  ///
  /// 与 `applyStoryEffectForTest` 的分工：那个测 `StoryEffect` 的三个列表
  /// 字段（给剧情步用），这个测 `CanonEvent` 的节点沉淀（给原著节点用）。
  /// 两套内容层走两条不同的接线，不能互相代偿。
  @visibleForTesting
  void sinkCanonNodeToMemoryForTest(String canonId) =>
      _sinkCanonNodeToMemory(canonId);


  void _injectCanonEventIntoOfflineNarrative() {
    final p = player;
    if (p == null) return;

    final t = worldState.time;
    final due = dueCanonEvents(
      year: t.year,
      month: t.month,
      grade: p.grade ?? 1,
      era: worldState.era,
      firedIds: worldState.firedAnchorIds,
      limit: 1,
    );
    if (due.isEmpty) return;

    final event = due.first;

    // 【剧情模式白名单抑制（批次 5）】
    // 若当前剧情步的 canonRefId 正好声明讲述这条节点，就不再贴 📖 旁白块
    // ——那段原著由剧情文本讲述（有情境、分支与后果），重复贴块玩家会
    // 把同一件事读到两遍。`firedAnchorIds` 照写：节点视为已消费，
    // 之后任何路径都不会再对它注入。
    //
    // 【为什么是防御层】当前分发下，剧情模式的全部回合（含自由行动降级
    // 与结局后行动）都走 `_runStoryTurn`，本函数只被**沙盒模式**的离线
    // 回合调用，这段分支平时不会执行。它是给未来改动的保险：若有人把
    // 剧情回合重新接回普通离线回合，这里保证「已由剧情讲述」优先于
    // 「旁白注入」。防回归由 test/canon_story_dedup_test.dart 钉死。
    if (storyProgress.active) {
      final step = findStoryStep(
        storyProgress.bookId,
        storyProgress.chapterId,
        storyProgress.stepId,
      );
      if (step != null && step.canonRefId == event.id) {
        worldState.firedAnchorIds.add(event.id);
        lastCanonEventTitle = null;
        lastCanonEventDirective = null;
        debugLog(
          '📖 原著节点 ${event.id} 由剧情步 ${step.id} 讲述，跳过旁白注入',
        );
        return;
      }
    }

    worldState.firedAnchorIds.add(event.id);

    final block = '📖 ${event.title}\n${event.directive}';
    if (!currentNarrative.contains(event.title)) {
      currentNarrative = '$currentNarrative\n\n$block';
    }
    notifications.add('📖 ${event.title}');
    worldState.addNarrativeEvent('📖 ${event.title}', turn: turnCount);

    // 把刚触发的节点名记下来，供 buildFallbackChoices 生成「有针对性的选项」。
    // 为什么不在选项侧重新过滤一遍：buildFallbackChoices 拿不到「本回合
    // 触发的是哪条」，再跑一次 dueCanonEvents 会因为 id 已被写进
    // firedAnchorIds 而返回空。所以由触发方单向告知。
    lastCanonEventTitle = event.title;
    lastCanonEventDirective = event.directive;

    debugLog('📖 原著节点注入: ${event.id}（${event.bookRef}）');
  }

  // ================================================================
  // 主线剧情模式（离线）· 剧情引擎
  // ================================================================
  //
  // 【它解决什么问题】离线模式此前是「一套去掉了所有剧情推进器官的回合循环」：
  // 它复用了 AI 路径的回合收尾（时间/精力/NPC/影响力/原著节点注入），
  // 却完全绕开了剧情上下文构建、伏笔回收、任务推进、记忆写入四大块，
  // 于是"剧情"表现为每月往叙事尾巴贴一段旁白——没有前因、没有分支、没有推进。
  //
  // 【它怎么解决】把剧情拆成 书 → 章 → 步 → 分支 四层：
  //   · 内容全是 `lib/data/story_data.dart` 里的 const 表（后六部只填表）；
  //   · 进度是 `StoryProgress`（走存档 extra_data，老存档零迁移）；
  //   · 每回合从当前步的 setup 出发生成叙事、由当前步的 choices 生成选项、
  //     按玩家所选推进到下一步，并把效果落到玩家/世界/长期记忆上。
  //
  // 【三条红线】
  //   1. 全程 0 AI 调用（`_maybeRunPeriodicSummary` 内部已按离线直接 return）；
  //   2. 不进入 `buildFallbackChoices`——那个函数的 `hookAnswer` 判据含
  //      `tail.contains('你的选择')`，而离线兜底叙事框架句恰有
  //      「你的选择，会把它推向不同的方向。」→ 在离线路径下**恒为真**，
  //      会把剧情选项全部冲掉。用独立的 `_buildStoryChoices` 从根上绕开。
  //   3. 后半段结算（`_settleAfterNarrative` / `_finalizeTurn`）**必须共用**，
  //      否则时间/精力/NPC/影响力/存档会与沙盒路径全线不一致。

  /// 一整个剧情回合。与沙盒回合共用后半段结算，前半段完全走剧情引擎。
  ///
  /// 【为什么不 declare `@visibleForTesting`】它是生产路径
  /// （`_runOfflineQuickTurn` 分发）真正要调的，加了会直接报错。
  void _runStoryTurn(String action, {String? causalResult}) {
    commandResult = causalResult;
    error = null;
    turnCount++;
    lastScannedNarrativeHash = null;
    lastPlayerAction = action;

    _updateLocationTracking();

    // 「开启下一部」专用通道（结局后选项）。必须在剧情推进之前拦截：
    // 若放行，parseStoryCommand 解析不出合法分支 → isFreeAction 降级，
    // 玩家点按钮只会白白烧一个回合。这里直接走衔接逻辑并提前收尾。
    if (action == kStoryNextBookAction) {
      _runNextBookTransition();
      return;
    }

    // ① 推进剧情：解析分支 → 查定义 → 落效果 → 定位下一步。
    //    返回本回合要写进叙事的"你做了什么"，null 表示走到了结局。
    final beat = _advanceStory(action);

    // ② 拼叙事（三层三明治）。
    currentNarrative = _composeStoryNarrative(beat);

    // ③ 结算与收尾：与沙盒路径**同一套函数**，只有时间推进方式不同
    //    （章节节拍式天数，见 _finalizeTurn 的参数说明）。
    //    表白可能改写 currentNarrative——剧情模式下不采纳它的改写
    //    （剧情文本优先），但表白状态机照常落库。
    _settleAfterNarrative();
    _finalizeTurn(
      currentNarrative,
      action,
      storyTimeCostDays: beat.timeCostDays,
      semanticAction: _semanticActionOf(beat, action),
    );

    // ④ 剧情选项（独立构建器，不进 buildFallbackChoices）。
    choices = _buildStoryChoices();

    // ⑤ 结局态的世界衔接：玩家自由行动把时间玩到了下一部锚点 →
    //    自动开新书并覆盖本回合的叙事/选项（结局文本已经看过了）。
    if (storyProgress.isFinished && _maybeAutoBeginNextBook()) {
      choices = _buildStoryChoices();
    }

    _maybeRunPeriodicSummary();
    error = null;
    loadingStage = '';
    isLoading = false;
    notifyListeners();
    unawaited(autoSave());
  }

  /// 「开启下一部」按钮回合：结局态 → 衔接下一部（跨部继承养成状态）。
  ///
  /// 【时间怎么推】PS 结局在 6 月，而《密室》从 7 月底讲起——中间的暑假
  /// 不能让玩家干等几十个空回合，这里一次性快进到下一部开启锚点日，
  /// 再进入新书第一步。快进走 `fastForwardDays` 全量结算（假期事件/
  /// 学院杯/月度演化一个不丢），而不是裸跳时间。
  void _runNextBookTransition() {
    // 【七部曲已走完】最后一部没有下一部。正常流程下这个按钮不会渲染，
    // 能走到这里只可能是旧存档的重放或重复点击——必须给出"完结"的交代，
    // 绝不能误导成"下一部还没装载"。
    final isFinalBook = nextStoryBookId(storyProgress.bookId) == null;
    final days = _bookTransitionDays();
    if (days > 0) {
      // 【为什么显式转型】与 `_finalizeTurn` 内的既有口径一致（见该处注释）。
      (this as GameSystemsMixin).fastForwardDays(days);
    }
    final opened = isFinalBook ? false : _enterNextBook();
    if (!opened) {
      // 未实装书：不快进白烧时间。已经快进的天数当作暑假的一部分——
      // 玩家至少"过完了假期"，提示也给了，不亏。
      notifications.add(
        isFinalBook
            ? '🎓 七部曲已经全部走完了——'
                '从今往后的每一天，都是你在霍格沃茨自己写下的时间。'
            : '📚 下一部的主线还没装载进当前版本，沙盒里的每一年照常可玩。',
      );
    }
    _settleAfterNarrative();
    // 快进已经手动做过，这里只按常规节拍再走 1 天（锚点日当天的结算）。
    _finalizeTurn(currentNarrative, kStoryNextBookAction, storyTimeCostDays: 1);
    choices = _buildStoryChoices();

    _maybeRunPeriodicSummary();
    error = null;
    loadingStage = '';
    isLoading = false;
    notifyListeners();
    unawaited(autoSave());
  }

  /// 距下一部开启锚点还有多少天（已到/已过/无下一部 = 0）。
  int _bookTransitionDays() {
    final nextId = nextStoryBookId(storyProgress.bookId);
    if (nextId == null) return 0;
    final b = findStoryBook(nextId);
    if (b == null) return 0;
    final delta = b.startAbsoluteDayIndex - worldState.time.absoluteDayIndex;
    return delta > 0 ? delta : 0;
  }

  /// 把剧情进度切到下一部书的第一步。
  ///
  /// 【继承口径】见 `StoryProgress.beginBook`：养成全继承、游标全重置。
  /// 【为什么 turnCount 归零】与 `_enterStoryMode` 同一口径——步长进度、
  /// 摘要节奏、事件种子都按"新书新回合"重新计；游戏周/学院杯等
  /// 世界态在 `worldState`/`Player` 上，不受影响。
  bool _enterNextBook() {
    final sp = storyProgress;
    final nextId = nextStoryBookId(sp.bookId);
    if (nextId == null) return false;
    final nextBook = findStoryBook(nextId);
    final first = firstStepOfBook(nextId);
    if (nextBook == null ||
        nextBook.chapters.isEmpty ||
        first == null) {
      _notifyPendingBookOnce(nextId);
      return false;
    }
    storyProgress = StoryProgress.beginBook(
      bookId: nextId,
      chapterId: first.chapterId,
      stepId: first.id,
      inherited: sp,
    );
    _markCanonForStep(first);

    turnCount = 0;
    lastPlayerAction = '';
    lastScannedNarrativeHash = null;

    final ordinal = kBookOrder.indexOf(nextId) + 1;
    currentNarrative = _composeStoryNarrative(
      StoryBeat(
        step: first,
        choice: null,
        consequence: '',
        onEnterText: '—— 第 $ordinal 部 · ${nextBook.title} ——\n'
            '${first.onEnterText ?? ''}'.trim(),
      ),
    );
    choices = _buildStoryChoices();
    notifications.add('📖 新篇章：《${nextBook.title}》');
    memory = memory.addWorldEvent(
      WorldEventRecord(
        id: 'story_begin_${nextId}',
        timestamp: worldState.time.format(),
        title: '新篇章开启',
        description: '《${nextBook.title}》的剧情开始了。',
        importance: 8,
        category: 'personal',
      ),
    );
    debugLog('📖 衔接下一部：$nextId，首步=${first.id}');
    return true;
  }

  /// 未实装书的「敬请期待」提示（每个下一部只弹一次，用 flag 去重）。
  void _notifyPendingBookOnce(String nextId) {
    final flag = 'kNextBookNotice_$nextId';
    if (storyProgress.flags.contains(flag)) return;
    storyProgress = storyProgress.copyWith(
      flags: [...storyProgress.flags, flag],
    );
    final title = findStoryBook(nextId)?.title ?? nextId;
    notifications.add(
      '📚 《$title》的主线还没装载进当前版本——沙盒里的每一年照常可玩，'
      '原著事件网也不会停。',
    );
  }

  /// 世界时钟自然走到下一部开启锚点时的自动衔接（每回合结局态检查）。
  ///
  /// 【与手动按钮的分工】按钮是「不想干等，快进到夏天」；这个是玩家
  /// 自由行动玩到了 7 月底——时间到位就自动开新书，不打扰节奏。
  bool _maybeAutoBeginNextBook() {
    if (!storyProgress.isFinished) return false;
    final nextId = nextStoryBookId(storyProgress.bookId);
    if (nextId == null) return false;
    final b = findStoryBook(nextId);
    if (b == null || b.chapters.isEmpty) return false;
    if (worldState.time.absoluteDayIndex < b.startAbsoluteDayIndex) {
      return false;
    }
    return _enterNextBook();
  }

  /// 一次剧情推进的结果，供叙事拼装使用。
  /// 用一个小结构体而不是一堆 out 参数，是因为叙事需要同时知道
  /// "选了什么"、"效果是什么"、"有没有插曲"——拆成参数会变成 4 个可空值。
  StoryBeat _advanceStory(String action) {
    final progress = storyProgress;

    // 已到结局：不再推进，只把结局文本重新呈现一次。
    if (progress.isFinished) {
      final book = findStoryBook(progress.bookId);
      final ending = book?.endings.firstWhere(
        (e) => e.id == progress.endingId,
        orElse: () => book.endings.last,
      );
      return StoryBeat(
        step: null,
        choice: null,
        consequence: '',
        onEnterText: null,
        endingTitle: ending?.title,
        endingBody: ending?.body,
      );
    }

    final step = findStoryStep(
      progress.bookId,
      progress.chapterId,
      progress.stepId,
    );
    // 游标指向了不存在的步（手改档 / 内容改动 / 版本升级）：不去猜，
    // 直接把进度重置到本部第一步，玩家最多重玩一章，而不是卡死。
    if (step == null) {
      debugLog('⚠️ 剧情游标失效(${progress.stepId})，重置到本部首步');
      final first = firstStepOfBook(progress.bookId);
      if (first == null) {
        storyProgress = progress.copyWith(endingId: 'missing_content');
        return const StoryBeat(
          step: null,
          choice: null,
          consequence: '',
          onEnterText: null,
          endingTitle: '剧情内容缺失',
          endingBody: '这一部的章节数据没有加载成功。',
        );
      }
      storyProgress = progress.copyWith(
        chapterId: first.chapterId,
        stepId: first.id,
      );
      return _advanceStory(action);
    }

    // 找玩家选的分支。
    final cmd = parseStoryCommand(action);
    StoryChoiceDef? choice;
    if (cmd != null && cmd.stepId == step.id) {
      for (final c in step.choices) {
        if (c.id == cmd.choiceId) {
          choice = c;
          break;
        }
      }
    }
    // 【风险 1 的对策】分支失效（读档后 action 被改写、内容升级后 id 变了、
    // 玩家手打了别的东西）一律降级为"自由行动"：不抛错、不卡死。
    final bool isFreeAction = choice == null;

    // 【自由插话：不消耗剧情步】玩家在剧情步之间打了一句自己的话。
    //
    // 【修的是什么】旧实现在这里空效果推进到下一步，于是"说一句话"的代价
    // 是白白花掉一个剧情步——玩家想聊聊当前处境，主线的剧情步却凭空少了一格，
    // 几百步的长局会因此被啃掉一大块。既然自由插话**不改变剧情状态**
    // （无效果、无 flag、无推进），它就**不应该移动游标**。
    //
    // 【为什么放在这里而不是 _runStoryTurn】选分支与插话共用
    // "action 解析 → 找 choice"这条前缀，判据（`choice == null`）只有在
    // 解析完成后才拿得到。提前到入口会把这个解析写两遍。
    //
    // 【与 AI 旁路的关系】若开了"剧情骨架 + AI 自由发挥"且 AI 可用
    // （`_tryStoryFreeform` 返回 true），插话文本由 AI 在原著框架内续写；
    // 否则用本地氛围池兜底。**两条路径都不移动游标**，所以纯本地玩家
    // 也照样不会丢剧情步。
    if (isFreeAction) {
      return _handleStoryFreeform(step, action);
    }

    // 落效果。
    //
    // 【顺序要命】`_applyStoryEffect` 内部会 `storyProgress = ...copyWith(...)`
    // 把 effects/flags/knowledge 写进去。所以它之后**必须**以
    // `storyProgress`（最新值）为基底继续构造，而不是用上面那个
    // `progress` 局部快照——否则新建的 `updated` 会把刚落的 effects
    // 覆盖回空，表现为"选项点了、剧情走了，但数值和 flag 全丢了"。
    // 这个缺陷是 `story_turn_test.dart` 的 D 组抓出来的。
    final effect = choice.effect;
    _applyStoryEffect(effect);
    final latest = storyProgress;

    // 记录选择与完成步。
    final doneSteps = List<String>.from(latest.doneSteps);
    if (!doneSteps.contains(step.id)) doneSteps.add(step.id);
    final chosen = Map<String, String>.from(latest.chosen);
    chosen[step.id] = choice.id;

    // 节拍式时间推进：**不用 advanceTimeForAction 的关键词推断**。
    // 具体推进在 `_finalizeTurn(storyTimeCostDays:)` 里做（那里才拿得到
    // `fastForwardDays` 的全量结算），这里只把本步的步长带到叙事结构上，
    // 供 `_runStoryTurn` 取用。这样时间只推一次，不会与关键词推断叠加。

    // 定位下一步。
    final nextStep = _resolveNextStep(step, choice);

    var updated = latest.copyWith(
      doneSteps: doneSteps,
      chosen: chosen,
      stepTurnSeed: latest.stepTurnSeed + 1,
    );

    if (nextStep == null) {
      // 本章（或本部）走完 → 判定结局。
      return _finishStory(step, choice, effect, false, action, updated);
    }

    updated = updated.copyWith(
      chapterId: nextStep.chapterId,
      stepId: nextStep.id,
    );
    storyProgress = updated;

    // 原著节点：剧情模式下由剧情文本讲述，但仍写 firedAnchorIds 防止
    // 玩家退出剧情模式后同一件事再弹一次。
    _markCanonForStep(nextStep);

    return StoryBeat(
      step: nextStep,
      prevStep: step,
      choice: choice,
      consequence: choice.consequence,
      onEnterText: nextStep.onEnterText,
      freeActionText: null,
      effect: effect,
      // 时间步长取自**已迈入的** nextStep：玩家读到的情境就是新一步的，
      // 时间也该按新一步的节拍走，否则"过场文本已经到十一月、
      // 时钟还停在十月"。
      timeCostDays: nextStep.timeCostDays,
    );
  }

  // ================================================================
  // 剧情模式 · 自由插话（剧情骨架 + AI 自由发挥）
  // ================================================================
  //
  // 【它解决什么问题】剧情模式原先只有"点选项"一种交互：玩家想说点什么、
  // 想多看一眼现场、想问旁边的人一句话，唯一能做的是点一个不相关的选项。
  // 而旧实现里自由输入会**空效果推进到下一步**——聊一句丢掉一个剧情步，
  // 在 600+ 步的长局里这是实打实的损失。
  //
  // 【它怎么解决】插话 = "在当前步里加一段"，而不是"走到下一步"：
  //   · 游标（bookId/chapterId/stepId）**完全不动**；
  //   · 不落任何 StoryEffect、不写 flag、不写知识；
  //   · 叙事 = 当前步的情境 + 玩家原文 + （AI 续写 或 本地氛围池兜底）；
  //   · 选项 = **当前步的选项原样重发**，玩家接着选，一步都不少。
  //
  // 【为什么 AI 是可选的】没配 Key / AI 失败时走本地氛围池，玩家体验
  // 降级为"确认收到了你的行动"，但**功能完整**——仍然不丢步、仍有原选项。
  // 这是"离线模式配合 AI"的落点：AI 是增强，不是依赖。

  /// 处理一次自由插话。**不移动剧情游标。**
  ///
  /// [step] 是玩家当前所在的步；[action] 是玩家原文。
  StoryBeat _handleStoryFreeform(StoryStepDef step, String action) {
    // AI 续写：开了开关 + AI 可用时才走。返回 null 表示"没续写"，
    // 此时叙事只呈现玩家原文 + 本地氛围句。
    final aiText = _tryStoryFreeformAi(step, action);

    // stepTurnSeed 递增：让 ambient 池轮转，玩家连续插话会读到不同的氛围句，
    // 而不是同一句重复贴。**这不影响剧情推进**，只是文本层面的变化。
    storyProgress = storyProgress.copyWith(
      stepTurnSeed: storyProgress.stepTurnSeed + 1,
    );

    return StoryBeat(
      step: step,
      // 【为什么 prevStep 传 null】插话没有"上一步的选择"可以承接，
      // 传了会让 `_composeCausalText` 织出"你此前的做法还留有余波"这种
      // 与当前动作无关的过渡句。
      prevStep: null,
      choice: null,
      consequence: '',
      freeActionText: action,
      isFreeformInterjection: true,
      freeformAiText: aiText,
      effect: StoryEffect.none,
      // 【为什么是 0 天】插话是场景内的一句话，不该推进章节节拍。
      // 剧情模式的日历由 `timeCostDays` 驱动、要与原著节点月份对齐，
      // 让闲聊推动日历会让时间线整体漂移。
      timeCostDays: 0,
    );
  }

  /// 尝试让 AI 为这次插话续写一段（在原著框架内）。
  ///
  /// 返回 `null` = 不续写（未开开关 / 没配 AI），调用方走本地兜底。
  ///
  /// 【为什么这里同步返回而不是 async】`_runStoryTurn` 整条链路是同步的
  /// （它要保证"点一下按钮 = 一个完整回合"的原子性，包括自动存档）。
  /// AI 续写是**可选的增强**，为它把整条链路改成异步会波及
  /// `_finalizeTurn` / `_settleAfterNarrative` / `autoSave` 的时序契约，
  /// 风险远大于收益。因此插话的 AI 续写走"上一回合已取到的文本"模式：
  /// 由 `requestStoryFreeformNarration`（见 mixin_story_freeform.dart）
  /// 预先取回并缓存在 `_pendingFreeformText`，这里只做读取。
  ///
  /// 未开开关时**不发起任何请求**，保证纯本地路径 0 AI 调用。
  String? _tryStoryFreeformAi(StoryStepDef step, String action) {
    if (!storyProgress.freeformEnabled) return null;
    return takePendingFreeformText(step.id, action);
  }

  /// 走到本章末尾时的收束：要么进下一章，要么判定全书结局。
  StoryBeat _finishStory(
    StoryStepDef finishedStep,
    StoryChoiceDef? choice,
    StoryEffect effect,
    bool isFreeAction,
    String action,
    StoryProgress updated,
  ) {
    final book = findStoryBook(updated.bookId);
    final nextChapter = book == null
        ? null
        : _nextChapterAfter(book, finishedStep.chapterId);
    debugLog(
      '📖 剧情章末: ${finishedStep.chapterId} → '
      '${nextChapter?.id ?? '（本部结束）'}',
    );

    if (nextChapter != null && nextChapter.steps.isNotEmpty) {
      final first = nextChapter.steps.first;
      final progressed = updated.copyWith(
        chapterId: nextChapter.id,
        stepId: first.id,
      );
      storyProgress = progressed;
      _markCanonForStep(first);
      return StoryBeat(
        step: first,
        prevStep: finishedStep,
        choice: choice,
        consequence: choice?.consequence ?? '你决定：$action',
        onEnterText: '—— ${nextChapter.title} ——\n'
            '${first.onEnterText ?? ''}'.trim(),
        freeActionText: isFreeAction ? action : null,
        effect: effect,
        timeCostDays: first.timeCostDays,
      );
    }

    // 本部结束 → 判定结局。结局由 flags + 累计数值决定，
    // 所以必须用**结算后的** progress（effects 已在 _applyStoryEffect 里累加）。
    final ending = book == null ? null : resolveStoryEnding(book, updated);
    final finish = updated.copyWith(
      endingId: ending?.id ?? 'default',
    );
    storyProgress = finish;
    notifications.add('🏁 ${ending?.title ?? '结局'}');
    worldState.addNarrativeEvent(
      '🏁 剧情结局：${ending?.title ?? '结局'}',
      turn: turnCount,
    );

    // 结局也写进长期记忆：这是整局最该被记住的事。
    memory = memory.addWorldEvent(
      WorldEventRecord(
        id: 'story_ending_${finish.bookId}',
        timestamp: worldState.time.format(),
        title: '剧情结局',
        description: ending?.title ?? '结局',
        importance: 9,
        category: 'personal',
      ),
    );

    // 最后一部结束 = 毕业。
    //
    // 【为什么必须在这里补这一刀】年级推进挂在 `_checkSchoolYearTransition`
    // 上，而它只在时钟**走进 9 月**时才推进年级。剧情模式的第七部在
    // 1998 年 7 月就收尾了（`dh` 学年末节点落在 7 月底），玩家此生再也
    // 走不到 1998 年 9 月——于是：
    //   · `grade` 停在 7，`newGrade > 7` 那条分支永远不执行；
    //   · `worldState.graduated` 恒为 false；
    //   · 「七年之约」成就拿不到，`_graduationSettlement` 的人生目标评估
    //     与毕业结算报告**一屏都不会出现**。
    // 实测：七部全跑完（57 章 / 335 步 / 结局已出）之后仍是
    // `grade=7 graduated=false`，玩家读完七本书却拿不到毕业。
    //
    // 剧情模式的时间轴与学年制两条线在这里是对不上的：剧情线是"原著讲到
    // 哪算哪"，学年线是"九月升级"。既然玩家已经把七部走完，毕业就是唯一
    // 正确的语义——这比让他卡在七年级等一个永远不会到来的九月强。
    //
    // 【为什么用 `nextStoryBookId == null` 判定而不是写死 'dh'】
    // 书序是引擎语义（`kBookOrder`），将来若加外传/后续，判定自动跟着走。
    if (nextStoryBookId(finish.bookId) == null && !worldState.graduated) {
      onPlayerGraduated(player?.grade ?? 7);
    }

    return StoryBeat(
      step: null,
      prevStep: finishedStep,
      choice: choice,
      consequence: choice?.consequence ?? '你决定：$action',
      onEnterText: null,
      endingTitle: ending?.title,
      endingBody: ending?.body,
      freeActionText: isFreeAction ? action : null,
      effect: effect,
    );
  }

  /// 定位下一步：优先用分支声明的 [StoryChoiceDef.nextStepId]，
  /// 否则顺延到本章下一个未完成的步；本章没有就返回 null（= 换章）。
  StoryStepDef? _resolveNextStep(StoryStepDef step, StoryChoiceDef? choice) {
    final book = findStoryBook(storyProgress.bookId);
    if (book == null) return null;
    final chapter = findStoryChapter(book.id, step.chapterId);
    if (chapter == null) return null;

    if (choice != null && choice.nextStepId.isNotEmpty) {
      for (final s in chapter.steps) {
        if (s.id == choice.nextStepId) return s;
      }
      // 声明的目标不存在 —— 与"分支失效"同一处理口径：不抛错，走顺延。
      debugLog('⚠️ 分支 ${step.id}/${choice.id} 指向的步不存在，改为顺延');
    }

    final idx = chapter.steps.indexWhere((s) => s.id == step.id);
    if (idx >= 0 && idx + 1 < chapter.steps.length) {
      return chapter.steps[idx + 1];
    }
    return null;
  }

  /// 取 [chapterId] 之后的下一章。
  StoryChapterDef? _nextChapterAfter(StoryBookDef book, String chapterId) {
    for (var i = 0; i < book.chapters.length; i++) {
      if (book.chapters[i].id == chapterId) {
        return i + 1 < book.chapters.length ? book.chapters[i + 1] : null;
      }
    }
    return null;
  }

  /// 把 [StoryEffect] 落到玩家 / 世界 / 长期记忆上。
  ///
  /// 【为什么效果要用"累加"而不是"直接赋值"】
  /// `StoryProgress.effects` 是跨存档累计的，用于结局判定；
  /// 而 `Player` 上的数值会被剧情之外的行为改写（战斗、送礼…），
  /// 两者不能混用，否则结局判定会随日常行为漂移。
  void _applyStoryEffect(StoryEffect effect) {
    if (effect.isEmpty) return;
    final p = player;
    final acc = Map<String, int>.from(storyProgress.effects);

    void bump(String key, int delta) {
      if (delta == 0) return;
      acc[key] = (acc[key] ?? 0) + delta;
    }

    if (p != null) {
      if (effect.spirit != 0) {
        p.spirit = (p.spirit + effect.spirit).clamp(0, 100);
      }
      // 精力/饱食：剧情推进不再是"体力系统的法外之地"。
      // 负数消耗、正数恢复，越界一律夹回 [0,100]——与
      // `updateNPCsFromAction` 的既有口径一致（那里是 max(0,...)，
      // 这里上下都夹，因为剧情可以给正值）。
      if (effect.energy != 0) {
        p.energy = (p.energy + effect.energy).clamp(0, 100);
      }
      if (effect.satiety != 0) {
        p.satiety = (p.satiety + effect.satiety).clamp(0, 100);
      }
      if (effect.galleons != 0) {
        p.galleons = (p.galleons + effect.galleons).clamp(0, 1 << 30);
      }
      if (effect.housePoints != 0) {
        // 【守卫约束】学院杯加分必须走 `addHouseCupPoints(amount, reason)`：
        // 它内部记录来源明细（houseCupSources），学年结算要按来源展示。
        // 裸写 `p.houseCupPoints += ...` 会被
        // test/progression_fix_test.dart 的源码形状守卫抓出来。
        addHouseCupPoints(effect.housePoints, '主线剧情');
      }
      if (effect.reputation != 0) {
        p.playerReputation.add('story', effect.reputation);
      }
      if (effect.affection != 0 && effect.targetNpcId != null) {
        // 【守卫约束】好感必须走 `updateNpcAffection` 统一入口——
        // 它内部带状态同步/去重/通知管线，裸写 `npc.affection = ...`
        // 会被 test/progression_fix_test.dart 的源码形状守卫抓出来
        // （本轮实测被抓，改走统一入口）。
        updateNpcAffection(
          effect.targetNpcId!,
          effect.affection,
          reason: '主线剧情',
          quiet: true,
        );
      }
      for (final item in effect.addItems) {
        // 【口径】`addItems` 填的是**物品名**，不是 id。
        // 原因是本项目的背包存的是名字：`itemDefById` 已被删除
        // （见 `item_data.dart:499` 的注释），全项目的物品查找入口是
        // `itemDefByName`。这里跟随既有口径，避免造出第二种语义。
        //
        // 用名字去重（与 `_addItem` 一致）：同名物品玩家只该有一件。
        final def = itemDefByName(item);
        final key = def?.name ?? item;
        if (!p.inventory.any((i) => i.name == key)) {
          p.inventory.add(
            InventoryItem(
              id: def?.id ?? item,
              name: key,
              type: def?.type ?? '剧情',
              description: def?.desc ?? '在主线剧情中获得。',
            ),
          );
        }
      }
    }

    bump('affection', effect.affection);
    bump('reputation', effect.reputation);
    bump('housePoints', effect.housePoints);
    bump('spirit', effect.spirit);
    bump('galleons', effect.galleons);

    final flags = List<String>.from(storyProgress.flags);
    final knowledge = List<String>.from(storyProgress.knowledge);
    for (final f in effect.setFlags) {
      if (!flags.contains(f)) flags.add(f);
    }
    for (final f in effect.clearFlags) {
      flags.remove(f);
    }
    for (final k in effect.addKnowledge) {
      if (!knowledge.contains(k)) knowledge.add(k);
      // 情报同时写进长期记忆的 T0 核心事实层：
      // 离线模式长期记忆几乎空转（唯一写入入口挂在 AI 摘要上），
      // 剧情情报是少数能真正沉淀下来的东西，值得占一个 T0 位。
      memory = memory.addKeyFact(
        KeyFactRecord(
          id: 'story_$k',
          fact: '剧情情报：$k',
          importance: kPersistentFactImportance,
          timestamp: worldState.time.format(),
          category: 'story',
        ),
      );
    }

    storyProgress = storyProgress.copyWith(
      effects: acc,
      flags: flags,
      knowledge: knowledge,
    );

    // ================================================================
    // 与项目各功能系统的接线（v2）
    // ================================================================
    // 放在最后：上面已经把 flags/knowledge 收敛进 storyProgress，这里做的
    // 是"把剧情结论广播给世界"，与 storyProgress 本身无关，顺序上互不影响。
    _routeEffectToWorld(effect);
  }

  /// 把剧情效果广播给长期记忆 / 委托 / 图鉴三个系统。
  ///
  /// 【为什么单独抽一个函数】`_applyStoryEffect` 已经很长（数值 + 物品 +
  /// flag + 情报），再接四段接线会把它压垮。这四段的共同点是：
  /// **都只跟 `effect` 与世界态有关，不碰 `storyProgress`**——边界干净，
  /// 可以独立读、独立测。
  ///
  /// 【为什么全部做了容错】内容层会持续增删（现在 100+ 节点，后面还会加），
  /// 写错一个 quest id / cg id 不该让玩家的一回合崩掉。三个系统各自的
  /// 写入口本身也都带幂等去重，重复触发是安全的。
  void _routeEffectToWorld(StoryEffect effect) {
    final p = player;
    if (p == null) return;
    final now = worldState.time.format();

    // ① 悬念：开启。描述按第一个 `|` 切成 id 与正文。
    for (final raw in effect.openLoops) {
      final sep = raw.indexOf('|');
      if (sep <= 0 || sep >= raw.length - 1) continue;
      final id = raw.substring(0, sep).trim();
      final desc = raw.substring(sep + 1).trim();
      if (id.isEmpty || desc.isEmpty) continue;
      memory = memory.addOrUpdateOpenLoop(
        OpenLoopRecord(
          id: id,
          description: desc,
          status: 'open',
          importance: 6,
          openedAt: now,
          openedTurn: turnCount,
          loopType: 'question',
        ),
      );
    }

    // ② 悬念：了结。找不到就静默跳过（内容层改 id 不该崩）。
    for (final id in effect.closeLoops) {
      final idx = memory.openLoops.indexWhere((r) => r.id == id);
      if (idx < 0) continue;
      final old = memory.openLoops[idx];
      if (old.status == 'done') continue;
      memory = memory.addOrUpdateOpenLoop(
        OpenLoopRecord(
          id: old.id,
          description: old.description,
          status: 'done',
          importance: old.importance,
          openedAt: old.openedAt,
          closedAt: now,
          npcIds: old.npcIds,
          loopType: old.loopType,
          openedTurn: old.openedTurn,
        ),
      );
    }

    // ③ 委托：复用 `acceptQuestTemplate` —— 它已经带年级门、去重与
    //    T1「未完结事项」登记（见 mixin_play.dart:1456）。剧情模式只需要
    //    "触发"，不该把那一整套口径重抄一遍（抄一遍就是两处口径，早晚漂）。
    //
    //    【为什么它会在剧情里静默失败】年级不够 / 已接过 / 模板不存在时，
    //    它走 `_finishLocal` 给一句提示。剧情模式下 `commandResult` 会被
    //    本回合的叙事覆盖，提示读不到——但委托**确实没发**，这是正确行为：
    //    内容层把一条超纲委托挂在一年级节点上，本来就该发不出去。
    for (final qid in effect.addQuests) {
      acceptQuestTemplate(qid);
    }

    // ④ 世界大事：写进长期记忆 T3 层，让原著主线跨部留存。
    for (final raw in effect.addWorldEvents) {
      final sep = raw.indexOf('|');
      final title = (sep > 0 ? raw.substring(0, sep) : raw).trim();
      final desc = sep > 0 ? raw.substring(sep + 1).trim() : '';
      if (title.isEmpty) continue;
      memory = memory.addWorldEvent(
        WorldEventRecord(
          id: 'story_$title',
          timestamp: now,
          title: title,
          description: desc.isEmpty ? title : desc,
          importance: effect.worldEventImportance,
          category: 'wizarding',
          location: worldState.currentLocation,
        ),
      );
    }

    // ⑤ 图鉴：解锁 CG（`unlockCG` 内部按 cgRecords 幂等）。
    for (final cgId in effect.unlockCgs) {
      unlockCG(cgById(cgId));
    }
  }

  /// 剧情模式下原著节点的处理。
  ///
  /// 若该步声明了 `canonRefId`，就把它记进 `firedAnchorIds`（防二次触发），
  /// 并清掉 `lastCanonEventTitle`——因为这件事已经由**剧情文本**讲述过了，
  /// 不该再由 `buildFallbackChoices` 生成一条"去打听…"的通用选项。
  void _markCanonForStep(StoryStepDef step) {
    final ref = step.canonRefId;
    if (ref == null) return;
    if (!worldState.firedAnchorIds.contains(ref)) {
      worldState.firedAnchorIds.add(ref);
    }
    lastCanonEventTitle = null;
    lastCanonEventDirective = null;
    debugLog('📖 剧情步已讲述原著节点: $ref（${step.id}）');

    // 原著节点 → 长期记忆 / 图鉴。
    //
    // 【为什么在这里而不是在内容层逐条写 effect】
    // `canonRefId` 是"这一步讲述的是哪条原著节点"的**唯一权威声明**，
    // 已经存在、已经被 102 条节点校验过覆盖度。把沉淀挂在这个既有点上，
    // 等于给整条七部曲时间线一次性接上长期记忆，不必改一个字节的剧情步。
    //
    // 【幂等】剧情模式可能重入同一步（读档、跳章开局），但 `_markCanonForStep`
    // 上游有 `firedAnchorIds` 语义上的"讲过一次"守卫；即便重入，
    // `addWorldEvent` 按 id 去重、`unlockCG` 按 cgRecords 去重，
    // 三层都是幂等的，不会产生重复记录。
    _sinkCanonNodeToMemory(ref);
  }

  /// 把一条原著节点的沉淀物（世界大事 / 悬念开启与了结 / CG）广播出去。
  ///
  /// 节点上三项都是可选的：没填就是"这条节点不产生长期记忆"，
  /// 保持与接线前完全一致的行为。
  void _sinkCanonNodeToMemory(String canonId) {
    final node = canonEventById(canonId);
    if (node == null) return;
    final p = player;
    if (p == null) return;

    final worldEvent = node.worldEvent;
    if (worldEvent != null && worldEvent.trim().isNotEmpty) {
      memory = memory.addWorldEvent(
        WorldEventRecord(
          id: 'canon_${node.id}',
          timestamp: worldState.time.format(),
          title: node.title,
          description: worldEvent.trim(),
          importance: node.worldEventImportance,
          category: 'wizarding',
          location: worldState.currentLocation,
        ),
      );
    }

    final open = node.openLoop;
    if (open != null && open.trim().isNotEmpty) {
      final sep = open.indexOf('|');
      if (sep > 0 && sep < open.length - 1) {
        final id = open.substring(0, sep).trim();
        final desc = open.substring(sep + 1).trim();
        if (id.isNotEmpty && desc.isNotEmpty) {
          memory = memory.addOrUpdateOpenLoop(
            OpenLoopRecord(
              id: id,
              description: desc,
              status: 'open',
              importance: 7,
              openedAt: worldState.time.format(),
              openedTurn: turnCount,
              loopType: 'question',
            ),
          );
        }
      }
    }

    // 悬念了结。一条节点可以同时收束多条线索（学年末一次回答好几个问题），
    // 因此 `closeLoops` 是列表。
    //
    // 【为什么找不到就跳过而不报错】节点与悬念分处两张表，改一条悬念 id
    // 不该让玩家的这一回合崩掉；`openLoops` 同理。真正的一致性由
    // `canon_events_test.dart` 的"开过的都要关"静态断言保证，
    // 不需要在运行时兜。
    for (final close in node.closeLoops) {
      final id = close.trim();
      if (id.isEmpty) continue;
      final idx = memory.openLoops.indexWhere((r) => r.id == id);
      if (idx >= 0 && memory.openLoops[idx].status != 'done') {
        final old = memory.openLoops[idx];
        memory = memory.addOrUpdateOpenLoop(
          OpenLoopRecord(
            id: old.id,
            description: old.description,
            status: 'done',
            importance: old.importance,
            openedAt: old.openedAt,
            closedAt: worldState.time.format(),
            npcIds: old.npcIds,
            loopType: old.loopType,
            openedTurn: old.openedTurn,
          ),
        );
      }
    }

    // 学年末：把所有 `offline_loop_*` 一并了结。
    //
    // 【为什么必须在这里收】`offline_loop_*` 是离线摘要为"起了头但还没
    // 下文"的剧情 flag 自动登记的（见 `_digestOfflineLocally`）。但 flag
    // 一旦置位就永远留在 `storyProgress.flags` 里，没有对应的"清除"动作，
    // 于是这些事项**永远关不掉**——实测跑完七部后，玩家的「未完结事项」
    // 面板上挂着二十多条已经翻篇几百天的旧事。学年末节点是全书唯一
    // 可靠的"这一段结束了"信号，在这里收口最合适：既不会提前了一结，
    // 也不会让旧事无限堆积。
    if (node.closeLoops.isNotEmpty) {
      memory = _closeStaleOfflineLoops();
    }

    final cg = node.unlockCg;
    if (cg != null && cg.trim().isNotEmpty) {
      unlockCG(cgById(cg.trim()));
    }
  }

  /// 叙事三层拼装：
  ///   [层1 情境] 本步 setup（+ 过场文本）
  ///   [层2 因果] 由选择结果与知识库生成的过渡句
  ///   [层3 世界] 地点氛围池（复用沙盒的 `localEventLinesFor`）
  ///   末尾附上"你做了什么"（consequence）与数值变动的可读提示。
  String _composeStoryNarrative(StoryBeat beat) {
    final parts = <String>[];

    // 结局回合：只呈现结局，不再有情境与选项。
    if (beat.endingTitle != null) {
      parts.add('🏁 结局 · ${beat.endingTitle}');
      if (beat.endingBody != null && beat.endingBody!.trim().isNotEmpty) {
        parts.add(beat.endingBody!.trim());
      }
      parts.add(
        '（这一部的剧情到此结束。你可以继续在城堡里自由活动，'
        '或在设置中开始新的存档。）',
      );
      return parts.join('\n\n');
    }

    final step = beat.step;
    if (step == null) {
      return '剧情数据暂时不可用，请尝试重新开始一局。';
    }

    // [层1] 情境层，带章节抬头——让玩家时刻知道"我在第几章"。
    final book = findStoryBook(storyProgress.bookId);
    final chapter = findStoryChapter(storyProgress.bookId, step.chapterId);
    final header = book != null && chapter != null
        ? '《${book.title}》第 ${chapter.ordinal} 章 · ${chapter.title}'
        : '主线剧情';
    parts.add('📖 $header');

    // 【自由插话回合】不走"情境三明治"，而是"你做了什么 → 世界如何回应"：
    // 玩家上一句还在读这一步的情境，再贴一遍 setup 会显得像重开了一屏。
    // 这里只呈现插话本身 + 现场回应，末尾提示剧情仍在原地等他继续。
    if (beat.isFreeformInterjection) {
      parts.add('你选择按自己的方式行动：${beat.freeActionText ?? ''}。');
      final ai = beat.freeformAiText;
      if (ai != null && ai.trim().isNotEmpty) {
        parts.add(ai.trim());
      } else if (step.ambient.isNotEmpty) {
        // 本地兜底：AI 不可用时用当前步的氛围池回应一句，
        // 让玩家感到"这句话被听见了"，而不是打了一行字毫无反应。
        parts.add(step.ambient[storyProgress.stepTurnSeed % step.ambient.length]);
      }
      parts.add('（主线仍在原处等你——上面的选项依然有效。）');
      return parts.join('\n\n');
    }

    if (beat.onEnterText != null && beat.onEnterText!.trim().isNotEmpty) {
      parts.add(beat.onEnterText!.trim());
    }
    parts.add(step.setup.trim());

    // [层2] 因果层：把上一步的选择与本步串起来。
    final causal = _composeCausalText(beat);
    if (causal.isNotEmpty) parts.add(causal);

    // [层3] 世界层：地点氛围（复用沙盒的地点池，保证两套玩法读到的
    // "城堡的样子"是一致的）。
    if (step.ambient.isNotEmpty) {
      parts.add(step.ambient[storyProgress.stepTurnSeed % step.ambient.length]);
    } else {
      final p = player;
      if (p != null) {
        final location = worldState.currentLocation ?? '霍格沃茨';
        final hour = worldState.time.hour;
        final lines = localEventLinesFor(
          location: location,
          hour: hour,
          seed: storyProgress.stepTurnSeed,
        );
        if (lines.isNotEmpty) {
          parts.add(lines[storyProgress.stepTurnSeed % lines.length]);
        }
      }
    }

    // 收束层：玩家做了什么 + 数值变动的可读回馈。
    if (beat.consequence.trim().isNotEmpty) {
      if (beat.freeActionText != null) {
        parts.add('你选择按自己的方式行动：${beat.freeActionText}。');
      }
      parts.add(beat.consequence.trim());
    }
    final delta = _formatStoryDelta(beat.effect);
    if (delta.isNotEmpty) parts.add(delta);

    return parts.join('\n\n');
  }

  /// [层2 因果层] 把上一步的选择与获得的情报，织成一句过渡。
  ///
  /// 【为什么需要这一层】没有它，每一步都是独立的情境描写，读起来像
  /// "在同一个地方反复醒来"。有了它，玩家能看见自己的选择正在生效——
  /// 这是"有因果"在文本上唯一的证据。
  String _composeCausalText(StoryBeat beat) {
    final prev = beat.prevStep;
    if (prev == null) return '';
    final lines = <String>[];

    // 情报引用：优先引用与本步 setup 相关的那条（简单的子串重叠判定），
    // 引不到就引用最近一条——总比不说强。
    final knowledge = storyProgress.knowledge;
    if (knowledge.isNotEmpty) {
      final corpus = '${beat.step?.setup ?? ''}${prev.setup}';
      String? picked;
      for (final k in knowledge.reversed) {
        // 正则已提为文件级预编译（_reNonWordChars）：
        // 这个方法每回合都会跑，而本仓库有源码形状守卫
        // （test/regex_hotpath_test.dart）专门抓循环内现编译 RegExp。
        final token = k.replaceAll(_reNonWordChars, '');
        if (token.isNotEmpty && corpus.contains(token)) {
          picked = k;
          break;
        }
      }
      picked ??= knowledge.last;
      lines.add('你还记得之前留意到的那件事（$picked），于是脚步没有停。');
    }

    // 选择引用：上一步做了什么。
    final chosenId = storyProgress.chosen[prev.id];
    if (chosenId != null) {
      for (final c in prev.choices) {
        if (c.id == chosenId) {
          lines.add('你此前的做法还留有余波：${c.text}。');
          break;
        }
      }
    }

    return lines.join('\n');
  }

  /// 把数值变动转成玩家能读懂的一行。全部为 0 时返回空串（不显示噪声）。
  String _formatStoryDelta(StoryEffect e) {
    final bits = <String>[];
    if (e.housePoints != 0) {
      bits.add('学院分 ${e.housePoints > 0 ? '+' : ''}${e.housePoints}');
    }
    if (e.reputation != 0) {
      bits.add('声望 ${e.reputation > 0 ? '+' : ''}${e.reputation}');
    }
    if (e.spirit != 0) {
      bits.add('精神 ${e.spirit > 0 ? '+' : ''}${e.spirit}');
    }
    if (e.affection != 0) {
      bits.add('好感 ${e.affection > 0 ? '+' : ''}${e.affection}');
    }
    if (e.galleons != 0) {
      bits.add('加隆 ${e.galleons > 0 ? '+' : ''}${e.galleons}');
    }
    if (e.addItems.isNotEmpty) {
      bits.add('获得物品×${e.addItems.length}');
    }
    if (e.addKnowledge.isNotEmpty) {
      bits.add('获得情报×${e.addKnowledge.length}');
    }
    return bits.isEmpty ? '' : '（${bits.join('，')}）';
  }

  /// 构建剧情选项。
  ///
  /// 【为什么不能用 `buildFallbackChoices`】那个函数的 `hookAnswer` 判据含
  /// `tail.contains('你的选择')`（`mixin_response.dart:1097`），而离线兜底
  /// 叙事的框架句 2 恰有固定句「你的选择，会把它推向不同的方向。」
  /// → **整个离线路径下 `hookAnswer` 恒为真**，任何排在它后面的分支都是死代码。
  /// 剧情模式直接读 `StoryStepDef.choices`，不进入那个函数，从根上绕开。
  List<GameChoice> _buildStoryChoices() {
    final progress = storyProgress;

    // 已到结局：留"衔接下一部 / 回头看 / 继续自由活动"三个出口。
    //
    // 【为什么衔接按钮在未实装时也显示】玩家需要知道"故事还有下一章"——
    // 点下去会得到一次明确的「筹备中」提示（flag 去重，只弹一次），
    // 而不是在结局文本里猜还有没有后续。
    if (progress.isFinished) {
      final nextId = nextStoryBookId(progress.bookId);
      final nextBook = nextId == null ? null : findStoryBook(nextId);
      final nextReady = nextBook != null && nextBook.chapters.isNotEmpty;
      return [
        if (nextId != null)
          GameChoice(
            text: nextReady
                ? '别过这一年，向夏天走去（开启《${nextBook.title}》）'
                : '别过这一年，向夏天走去',
            action: kStoryNextBookAction,
          ),
        GameChoice(
          text: nextId == null ? '🎓 回望这七年' : '回望这段经历',
          action: '/状态',
        ),
        const GameChoice(text: '在城堡里四处走走', action: '在城堡里四处走走'),
      ];
    }

    final step = findStoryStep(
      progress.bookId,
      progress.chapterId,
      progress.stepId,
    );
    if (step == null) return const [];

    final flags = progress.flags.toSet();
    // 【为什么把 knowledge / reputation 也传进去】内容表里越来越多的选项
    // 需要"玩家知道什么"和"玩家在这一带的份量"两个维度来把关：
    //   · knowledge——打听过内情的人才能看懂的出路；
    //   · reputation——还没出名的低调出路 / 已经站稳脚的人才敢走的路。
    // 这三样合起来，剧情选择才真正受玩家历史影响，而不是人人同一套按钮。
    final avail = availableStoryChoices(
      step,
      flags,
      knowledge: progress.knowledge.toSet(),
      reputation: player?.wizardingReputation ?? 0,
    );

    // 上限 4 条：与 AI 路径的选项数口径一致，也避免长表把按钮区撑爆。
    return avail
        .take(4)
        .map(
          (c) => GameChoice(
            text: c.text,
            action: encodeStoryAction(step.id, c.id),
          ),
        )
        .toList();
  }

  /// 开局/读档后进入剧情模式：把进度初始化到第一部第一步，
  /// 并用该步的内容生成首屏叙事与选项（**不调用任何 AI**）。
  ///
  /// 实现的是基类抽象声明 `enterStoryMode`（调用方在 `GameInitMixin`）。
  @override
  void enterStoryMode() => _enterStoryMode();

  void _enterStoryMode() {
    // 【开局场景定位】9 月开局不该从 7 月的信开始（时间倒流）——
    // 按玩家选的开局场景跳过已经发生的暑假章节。
    final first =
        storyStartStepFor(openingScene) ??
        firstStepOfBook(kFirstStoryBookId);
    if (first == null) {
      debugLog('⚠️ 剧情内容未加载，无法进入剧情模式');
      storyProgress = StoryProgress.inactive;
      return;
    }
    storyProgress = StoryProgress(
      active: true,
      bookId: kFirstStoryBookId,
      chapterId: first.chapterId,
      stepId: first.id,
      // 把设置页的「剧情 + AI 自由发挥」偏好带进新局。
      // 【为什么在开局时抄一次而不是每回合读偏好】一局的开关状态要跟着存档走
      // （玩家可能中途改），偏好只在开局播种，之后以存档里的值为准。
      freeformEnabled: appProvider.storyFreeformPreference,
    );
    _markCanonForStep(first);

    turnCount = 0;
    lastPlayerAction = '';
    commandResult = null;
    error = null;
    lastScannedNarrativeHash = null;

    currentNarrative = _composeStoryNarrative(
      StoryBeat(
        step: first,
        choice: null,
        consequence: '',
        onEnterText: first.onEnterText,
      ),
    );
    choices = _buildStoryChoices();
    appendRecentTurn(currentNarrative);
    accumulateForSummary(currentNarrative);

    notifications.add('📖 主线剧情开始：《魔法石》');
    memory = memory.addWorldEvent(
      WorldEventRecord(
        id: 'story_start_${first.id}',
        timestamp: worldState.time.format(),
        title: '主线剧情开始',
        description: '你开始按原著时间线经历这一学年。',
        importance: 7,
        category: 'personal',
      ),
    );
    debugLog('📖 进入剧情模式，首步=${first.id}');
  }

  /// Q13：本地兜底叙事的事件种子池——按地点分池 + 时间条件化 + 大通用池轮转。
  ///
  /// 修复前：只有一个 5 条的事件池，`turnCount % 5` 选句，长玩 5 回合必重复，
  /// 且完全不看玩家在哪、几点。现在：
  ///   - 霍格沃茨常见地点有专属池（礼堂/图书馆/温室/塔楼/禁林/魔药教室…），
  ///     让「在禁林」和「在图书馆」读到的不是同一批句子；
  ///   - 深夜有专属池（熄灯后的氛围本就不该纯说白天的琐事）；
  ///   - 其余走 20 条通用池，seed 递增 → 长会话也不急着撞句。
  @visibleForTesting
  static List<String> localEventLinesFor({
    required String location,
    required int hour,
    required int seed,
  }) {
    final isNight = hour < 6 || hour >= 21;
    if (isNight) return _nightEventLines;

    // 地点池精确匹配失败时退化为「子串双向匹配」：
    // currentLocation 存的是规范名（如「霍格沃茨·礼堂」），而池 key 是短名
    // （如「礼堂」）——只做 `_locationEventLines[location]` 精确查找的话，
    // 专属池几乎永远落空、全走通用池（P5 实地发现：离线玩法读到的几乎
    // 全是通用句，礼堂/图书馆/禁林全在 "某角落" 的句子里打转）。
    // 向后兼容：短名直查 / 长名包含短名 / 短名包含长名都能命中。
    final exact = _locationEventLines[location];
    if (exact != null) return exact;
    for (final entry in _locationEventLines.entries) {
      if (location.contains(entry.key) || entry.key.contains(location)) {
        return entry.value;
      }
    }
    return _genericEventLines[(seed ~/ 3) % _genericEventLines.length];
  }

  /// 深夜专属事件池（熄灯后的霍格沃茨氛围）。
  static const List<String> _nightEventLines = [
    '窗外月光洒在走廊的地板上，墙上的画像正闭眼休息，只有你的脚步声在回荡。',
    '远处传来城堡大钟低沉又悠远的报时，惊起了一只在窗棂上打盹的猫头鹰。',
    '守夜的老门卫提着马灯从走廊尽头走过，灯光在地板上拉出一条长长的影子。',
    '几盏蜡烛在半空无声地漂浮着，像一个没人注意的幽灵缓缓飘过走廊。',
    '图书馆的方向还亮着一盏微弱的灯，不知是谁还在一排排书架间流连。',
    '窗外的禁林里隐约传来某种低沉的嗡鸣，转瞬又归于寂静蹊跷。',
    '走廊尽头的盔甲忽然像活了一样，发出一声很轻的金属摩擦声。',
    '公共休息室的壁炉火苗已经压得很低，沙发旁还摊着一本没合上的《预言家日报》。',
    '头顶传来一阵窸窣，大概是淘气的皮皮鬼，你决定假装没听见。',
    '潮湿的晚风从某扇没关严的窗缝溜进来，烛火跟着晃了晃。',
  ];

  /// 常见地点各自的专属事件池——按地点名精确或子串匹配。
  static const Map<String, List<String>> _locationEventLines = {
    '礼堂': [
      '四张长桌旁的家养小精灵正在无声地收拾残羹，动作熟练得像影子。',
      '天花板外的夜空露出几颗星，食物被施了保暖咒仍冒着热气。',
      '一位教授正对着空无一人的餐桌低声念着什么咒语，像是在加固防尘屏障。',
      '格兰芬多的长桌上有人围成一圈低声讨论着什么，忽而又散开了。',
      '邓布利多的座椅背后，一只家养小精灵已经在打瞌睡，头一点一点。',
    ],
    '图书馆': [
      '平斯夫人推着满载的书车经过，对你投来一个「安静看书」的提醒眼神。',
      '几本书在书架上轻微颤动，像是有人刚刚触碰过它们又移开了手。',
      '角落的禁书区被链子拴着的书发出低低的翻页声，却不见有手翻动。',
      '一本《魔法史》被翻开又合上，页边空白处写满细密的铅笔批注。',
      '靠窗的座位还留着上一节课主动留下来的几根羽毛笔和一小叠羊皮纸。',
    ],
    '禁林': [
      '树影间一双发亮的眼睛一闪而过，你定神再看时已经没了踪影。',
      '地面传来一阵细碎的沙沙声，像是有什么小东西正沿着灌木丛边缘快速挪动。',
      '某棵树干上刻着新鲜的爪痕，摩擦的毛边还没有被时间磨圆。',
      '一株会张合叶片的植物在脚边动了动，像在试探要不要咬你一口。',
      '远处传来马蹄声与一声低沉的嘶鸣，随即又被更深处的黑暗吞没。',
    ],
    '温室': [
      '一株曼德拉草幼苗在盆里轻轻扭动了一阵，随后又安静下来。',
      '暖房里的空气又湿又暖，某种从未见过的花朵正在悄然绽放。',
      '霍格沃茨的家养小精灵正小心地往一株食人藤的根部浇水，看见你后他迅速移开了视线。',
      '一排番茄也属的魔法植物结出会发光的果实，在暖光下轻轻晃动。',
      '石板缝隙里钻出几根会攀爬的藤蔓，正朝旁边一盆跳跳球茎悄悄伸去。',
    ],
    '塔楼': [
      '风从塔楼的窗缝里灌进来，吹得羽毛笔和羊皮纸在桌上轻轻挪动。',
      '楼下传来争论课表的声音，被塔楼的风吹得断断续续。',
      '一架望远镜正对着夜空，等待着一颗迟迟没有出现的流星。',
      '盘旋的楼梯尽头，某幅肖像画在你经过时偷偷睁开了半只眼睛。',
      '天文台上的星图被风吹动一角，上面的墨水还没完全干透。',
    ],
    '魔药教室': [
      '坩埚里残留的液体冒出几缕向上的烟，空气中还留着薄荷与苦草的气息。',
      '柜子里一排瓶瓶罐罐轻轻碰了一下，像是有人刚取走过一瓶又放回一瓶。',
      '黑板上的魔药配方还没擦去，末尾的几行字被打了个记号。',
      '一只烧杯里的液体一小会儿变一个颜色，隔着毛玻璃也看得很清楚。',
      '讲台上的教具蛇在地下静静蜷着，通体透着一股虎视眈眈的凉意。',
    ],
    '厨房': [
      '一排家养小精灵正排着队把刚出炉的馅饼往碗柜里码，热腾腾的香气扑鼻。',
      '某只家养小精灵朝你鞠了一躬，又忙不迭地回到灶台边翻炒着什么。',
      '橱柜顶放着的一罐蜂蜜突然抖了抖，大概是什么零食咒在下午茶时间发作。',
      '角落堆着一摞洗好的餐具，正自己一蹦一蹦地跳回各自的架子上。',
    ],
    '场地': [
      '远处的魁地奇球场空无一人，只有几面旗帜在风中猎猎作响。',
      '黑湖的水面泛着幽光，一阵波纹从岸边扩散开去，像有什么刚从水下经过。',
      '海格的南瓜地里，最大的那几颗南瓜正忙着抢占地盘，越挤越紧。',
      '草坪上散落着几把练习用的扫帚，一只咿呀飞行的雏鹰正绕着看台盘旋。',
    ],
    '宿舍': [
      '公共休息室的壁炉噼啪作响，几个同学窝在扶手椅里下巫师棋。',
      '床上叠着一件还没干的校袍，估计是谁刚施过烘干咒的成果。',
      '窗台上蹲着室友的猫头鹰，歪头用一只圆眼打量你翻找东西。',
      '桌上的棋局还停在原处，一枚棋子趁没人注意偷偷换了个位置。',
    ],
    '球场': [
      '扫帚架上的飞天扫帚排得整整齐齐，有几把还缠着练习用的毛线球。',
      '看台上有人落下一副护目镜，在阳光下闪闪发亮。',
      '更衣室的门半掩着，里面飘出几句关于战术的争论。',
    ],
    '黑湖': [
      '湖面平静得像一面深色的镜子，偶尔被某条跃出的鳍划开一道涟漪。',
      '岸边水草丛里，一只螃蟹用钳子夹着一片浮萍，慢吞吞地横着爬。',
      '水下的阴影比别处浓重，像有一双眼睛在湖水的光斑间注视着你。',
    ],
  };

  /// 通用事件池——覆盖没有专属池的地点，seed 驱动轮转避免长会话撞句。
  static const List<List<String>> _genericEventLines = [
    [
      '走廊里几个低年级学生抱着书本匆匆跑过，其中一本差点掉在地上。',
      '墙上的画像们正在争论魁地奇比赛的历史最佳找球手，声音越来越大。',
      '窗外传来猫头鹰扑打翅膀的声音，一封新信被扔进了窗台。',
    ],
    [
      '远处的教室传来一阵整齐的咒语吟唱声，听起来像是弗立维教授的魔咒课。',
      '拐角处皮皮鬼唱着怪调的歌飘过，又突然折返往另一个方向去了。',
      '一个胖乎乎的家养小精灵用布巾抹了一下额头，又消失在拐角。',
    ],
    [
      '走廊尽头挂着一幅正在打瞌睡的画像，鼾声里混着几句含糊的梦话。',
      '头顶的吊灯轻轻晃动了一下，像是有什么大东西刚从天花板上走过。',
      '一阵轻微的低语从墙后传来，仔细听又只剩下风声。',
    ],
    [
      '一只猫头鹰落在窗台上，歪着头观察了你片刻后才展翅离去。',
      '空地上散落的几根羽毛被风卷起，打了个旋又落回原处。',
      '远处传来几声被压抑的惊呼，很快又归于一片安静。',
    ],
    [
      '走廊的盔甲突然做好像动了动最外面的那只手，随后又纹丝不动。',
      '某个房间的门半掩着，里面透出昏黄的烛光，却听不见任何声音。',
      '你在墙角发现一枚被遗落的加隆，边缘在灯光下微微发亮。',
    ],
    [
      '墙上的藏书地图某处皱起一角，像被反复翻看过。',
      '有人的脚步声在你身后停了一下，你回头时走廊却空无一人。',
      '一阵冷风不知从哪个方向吹来，蜡烛的火苗齐齐偏向了同一个方向。',
    ],
    [
      '班上的幽灵正漂浮在天花板附近，对你说完「别太晚」后穿墙而去。',
      '远处的炊烟混着洋葱和烤面包的香气飘过来，勾起了你的食欲。',
      '窗边的挂毯上绣着的魔法生物，似乎在某个瞬间眨了眨眼睛。',
    ],
  ];

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
    // 第16轮E：玩家误用 `/` 开头的输入时，原样存入会让离线兜底选项把 `/xxx`
    // 原样当选项文本（"A. /握紧魔杖..."），玩家点选即回到原输入 → 死循环。
    // 兜底场景下清洗：去掉 `/` 前缀当作自由行动。
    final actionForChoice = playerAction.startsWith('/')
        ? playerAction.substring(1)
        : playerAction;

    // 基于玩家最近的行动生成相关选项
    final actionRelatedChoices = <GameChoice>[];

    // 如果有玩家行动，生成延续性选项
    if (actionForChoice.isNotEmpty) {
      actionRelatedChoices.addAll([
        GameChoice(text: '$actionForChoice（继续）', action: '$actionForChoice（继续）'),
        GameChoice(text: '改变策略', action: '改变策略'),
      ]);
    }

    // 基于剧情内容生成情境相关选项
    final narrativeBasedChoices = <GameChoice>[];

    if (narrativeLower.contains('决斗') ||
        narrativeLower.contains('战斗') ||
        narrativeLower.contains('对抗')) {
      narrativeBasedChoices.addAll([
        GameChoice(text: '应战', action: '应战'),
        GameChoice(text: '寻求帮助', action: '寻求帮助'),
      ]);
    }
    if (narrativeLower.contains('对话') ||
        narrativeLower.contains('交谈') ||
        narrativeLower.contains('聊天')) {
      narrativeBasedChoices.addAll([
        GameChoice(text: '继续交谈', action: '继续交谈'),
        GameChoice(text: '告辞离开', action: '告辞离开'),
      ]);
    }
    if (narrativeLower.contains('受伤') ||
        narrativeLower.contains('疼痛') ||
        narrativeLower.contains('流血')) {
      narrativeBasedChoices.addAll([
        GameChoice(text: '寻求医疗帮助', action: '寻求医疗帮助'),
        GameChoice(text: '自己处理伤势', action: '自己处理伤势'),
      ]);
    }
    if (narrativeLower.contains('发现') ||
        narrativeLower.contains('找到') ||
        narrativeLower.contains('看到')) {
      narrativeBasedChoices.addAll([
        GameChoice(text: '仔细查看', action: '仔细查看'),
        GameChoice(text: '报告他人', action: '报告他人'),
      ]);
    }
    if (narrativeLower.contains('魔法') ||
        narrativeLower.contains('咒语') ||
        narrativeLower.contains('施法')) {
      narrativeBasedChoices.addAll([
        GameChoice(text: '尝试施法', action: '尝试施法'),
        GameChoice(text: '研究魔法理论', action: '研究魔法理论'),
      ]);
    }

    // 基于当前地点生成基础选项
    final locationChoices = {
      '霍格沃茨': [('继续探索', '继续探索'), ('找人询问', '找人询问'), ('观察环境', '观察环境')],
      '霍格莫德村': [('继续逛街', '继续逛街'), ('进店看看', '进店看看'), ('返回学校', '返回霍格沃茨')],
      '对角巷': [('继续购物', '继续购物'), ('逛其他店铺', '逛其他店铺'), ('返回霍格沃茨', '返回霍格沃茨')],
      '禁林': [('小心前进', '小心前进'), ('观察周围', '观察周围'), ('原路返回', '原路返回')],
      '大礼堂': [('继续用餐', '继续用餐'), ('与人交谈', '与人交谈'), ('离席活动', '离席活动')],
      '教室': [('认真听讲', '认真听讲'), ('做笔记', '做笔记'), ('课后请教', '课后请教')],
      '图书馆': [('查阅资料', '查阅资料'), ('安静阅读', '安静阅读'), ('借阅书籍', '借阅书籍')],
    };

    final locationOptions =
        locationChoices[currentLoc] ??
        [('继续前进', '继续前进'), ('仔细观察', '仔细观察'), ('与人交谈', '与人交谈')];

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

  /// 截断叙事上下文，只保留末尾 maxChars 字，保证连贯性同时控制 token
  /// （日志分析第16轮D：硬切字符会把「8月1日」切成「日」——AI 读断词，
  /// 截断点回退到段落/句末边界）

  String _truncateNarrativeContext(String narrative, int maxChars) {
    if (narrative.length <= maxChars) return narrative;
    final cut = snapCutToBoundary(narrative, narrative.length - maxChars);
    return '…（前情略）${narrative.substring(cut)}';
  }

  /// 第16轮G：T0 核心事实与 Player 权威设定冲突检测（过滤历史错误摘要污染）。
  /// 保守匹配，只拦已知的硬冲突，避免误伤其他事实：
  ///  - 宠物物种错：玩家契约宠物是九尾灵狐，事实却写"猫头鹰绯月"
  ///  - 哈利特征张冠李戴：主角非哈利，事实却写"闪电形伤疤"
  bool _factConflictsWithAuthority(String fact) {
    final p = player;
    if (p == null || fact.isEmpty) return false;
    final isHarry = p.name.toLowerCase() == '哈利' || p.name.contains('波特');
    // 宠物冲突：权威宠物是狐类，事实却写猫头鹰（绯月不是猫头鹰）
    if (p.petId != null && p.petId!.isNotEmpty) {
      final pd = petById(p.petId!);
      final species = pd?.species ?? '';
      if (species.contains('狐') && fact.contains('猫头鹰')) {
        return true;
      }
    }
    // 闪电形伤疤：哈利专属（主角的疤不是闪电形，家庭设定红线）
    if (!isHarry && fact.contains('闪电形') && fact.contains('伤疤')) {
      return true;
    }
    return false;
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

  /// 每回合递减退避计数（在 _maybeRunPeriodicSummary 里调用一次）。
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
              importance: 6,
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
            importance: 6,
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

  /// 从摘要中剥离结构化块（已写入 LongTermMemory，不需要在 T4 中重复）
  String _stripStructuredBlocks(String text) {
    var cleaned = text;
    // 剥离【关系】【伏笔】【了结】【核心事实】【世界事件】块
    cleaned = cleaned.replaceAll(RegExp(r'【关系】[\s\S]*?(?=【|$)'), '');
    cleaned = cleaned.replaceAll(RegExp(r'【伏笔】[\s\S]*?(?=【|$)'), '');
    cleaned = cleaned.replaceAll(RegExp(r'【了结】[\s\S]*?(?=【|$)'), '');
    cleaned = cleaned.replaceAll(RegExp(r'【核心事实】[\s\S]*?(?=【|$)'), '');
    cleaned = cleaned.replaceAll(RegExp(r'【世界事件】[\s\S]*?(?=【|$)'), '');
    // 日志分析第16轮D：摘要 AI 常把指令编号也输出（"1. 精简剧情摘要"），
    // 剥掉行首「数字+句点」序号残渣，避免摘要正文带着编号注入前情
    cleaned = cleaned.replaceAll(RegExp(r'^\s*\d{1,2}[.．、]\s*', multiLine: true), '');
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

  // ====== 热路径预编译正则 ======
  //
  // 这些正则位于「每回合必然执行」的路径上（_buildCriticalContext、
  // _syncLocationFromNarrative）。Dart 的 RegExp 每次构造都要重新解析
  // 并编译 pattern，在长局里是纯浪费的 CPU 与 GC 压力。
  // 统一提为 static final（只编译一次），语义完全不变。
  // 参考实现见 mixin_response_affection.dart 与 mixin_response.dart 的
  // _stripPatternCache —— 本项目的既有惯例就是「热路径正则必须预编译」。

  static final RegExp _reCombatKeywords =
      RegExp(r'(战斗|决斗|攻击|防御|施展咒语|施法|黑魔法|施咒|念咒|反击)');

  static final RegExp _reStudyKeywords =
      RegExp(r'(上课|考试|测验|作业|复习|学习|论文|写论文|做功课)');

  static final RegExp _reRomanceKeywords =
      RegExp(r'(约会|表白|心动|拥抱|接吻|单独见面|私聊)');

  static final RegExp _reEconomyKeywords =
      RegExp(r'(购买|出售|购物|交易|取钱|存钱|存取古灵阁)');

  /// 社交意图关键词（_syncLocationFromNarrative 判定"是否与人互动"用）。
  static final RegExp _reSocialIntent =
      RegExp(r'(与|和|跟|找|邀|问|对话|聊天|约会|见面|散步|陪|一起|独处|深入|表白|感情|心动)');

  /// 结构化块内条目前的列表符号 / 序号前缀（`- `、`• `、`1. ` 等）。
  /// `_extractMemoryFromSummary` 里曾重复内联 4 次，现统一。
  static final RegExp _reListPrefix = RegExp(r'^[\s•·\-\d]+');

  /// 结构化块条目分隔符（中英文分号 / 换行）。曾重复内联 2 次。
  static final RegExp _reListSeparator = RegExp(r'[;；\n]');

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
    final interactive = lastPlayerAction.contains(_reSocialIntent);
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
      deviationDriftFor(player?.worldLineDeviation ?? 0.0),
    );
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
    // 用 [^\S\n]*（空白但不含换行）替代 \s*：AI 写「【地点】」后直接换行时，
    // 旧正则 \s* 会跨行把正文首行吞成"地点"——若该行含 走廊/家里/花园/书房，
    // 硬状态被误切成「家中·卧室」。空值标签现在匹配失败，保持原地点不动。
    final locationTagMatch = RegExp(
      r'【地点】[^\S\n]*([^\n]+)',
      dotAll: false,
    ).firstMatch(narrative);
    if (locationTagMatch != null && locationTagMatch.group(1) != null) {
      final tag = locationTagMatch.group(1)!.trim();
      // 统一走 resolveLocationName（lib/data/locations.dart）。
      detected = resolveLocationName(tag);
      // 如果标签没匹配到已知别名，但标签里提到了具体位置，
      // 检查是否属于"家中"大类（卧室/花园/书房/密室/起居室 都算家中）
      if (detected == null) {
        if (RegExp(
          r'(家中|家里|住宅|庄园|别墅|卧室|书房|花园|密室|走廊|客厅|门厅)',
          caseSensitive: false,
        ).hasMatch(tag)) {
          detected = '家中·卧室';
        }
      }
    }

    if (detected == null) return; // 【地点】标签未识别到任何已知地点，不改

    // 时间门：只拦"开学前从校外首次入校 / 错切车站"（见 kSeasonLockedMinDate）。
    // 已在校内换房间永远不被这道门拦——学年 1–6 月玩家每天在城堡里走动，
    // 无年份 MMDD 无脑拦会把整个学年的校内同步全堵死（第三次审查 N2）。
    final dateInt = worldState.time.month * 100 + worldState.time.day;
    if (blockedBySeasonGate(
      detected: detected,
      current: cur,
      dateInt: dateInt,
    )) {
      worldState.addNarrativeEvent(
        '⏱ 地点同步被时间门拦截：$detected（需 9月1日，'
        '当前 ${worldState.time.month}月${worldState.time.day}日）',
        turn: turnCount,
      );
      return; // 季节未到：保留上一地点
    }

    // 区域门禁：年级 / 周末限制统一判定（数据源见 lib/data/game_config_rules.dart 的 mapRegions）。
    //
    // 【历史 bug】本处原先只调 `blockedByGradeGate`，而它内部写死 `'霍格莫德'`，
    // 于是禁林的 `minGrade: 2` 从未在状态层拦过（一年级玩家被 AI 写进禁林照样切），
    // 霍格莫德的 `weekendOnly: true` 也从未生效。现在统一走 `evaluateRegionGate`，
    // 它是数据表的唯一消费入口——数据改一处，这里行为跟着改。
    //
    // 教授带队豁免：禁林的 unlockCondition 明确写了"或由教授带队"，
    // 所以从叙事正文里识别带队词后放行（霍格莫德不受豁免，村民通行是制度性的）。
    const escortWords = ['教授带队', '教授带领', '随队', '带队', '老师带领', '教授陪同'];
    final gate = evaluateRegionGate(
      detected: detected,
      grade: player?.grade,
      isWeekend: isWeekendWeekday(worldState.time.weekday),
      escortExempt: escortWords.any(narrative.contains),
    );
    if (gate.isBlocked) {
      final reasonText = switch (gate.reason!) {
        RegionGateReason.grade =>
          '需${gate.blocked!.minGrade}年级，当前${player?.grade ?? 1}年级',
        RegionGateReason.weekend => '仅周末开放',
      };
      worldState.addNarrativeEvent(
        '⏱ 地点同步被区域门拦截：$detected（$reasonText）',
        turn: turnCount,
      );
      return;
    }

    // B 类漂移防护（软一致性）：detected 与当前不同，但叙事正文并未佐证该地点
    // （既无移动动词、也未复现地点名/别名，且已排除【地点】标签自身）→ 疑似标签笔误，
    // 保留上一地点，避免"叙述说在家、标签写大礼堂"这类漂移型硬切。
    if (detected != cur &&
        !narrativeCorroboratesLocation(detected, cur, narrative)) {
      worldState.addNarrativeEvent(
        '⚠ 地点漂移被拦截：$detected（正文未提及该地点，疑似标签笔误）',
        turn: turnCount,
      );
      return;
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
    if (loc.contains('教室') || loc.contains('classroom') || loc.contains('讲堂'))
      key = 'classroom';
    if (loc.contains('大礼堂') || loc.contains('great hall')) key = 'great_hall';
    if (loc.contains('图书馆') || loc.contains('library')) key = 'library';
    if (loc.contains('走廊') || loc.contains('corridor')) key = 'corridor';
    if (loc.contains('城堡外') || loc.contains('outside') || loc.contains('草坪'))
      key = 'outside';
    if (loc.contains('公共休息室') || loc.contains('common')) key = 'common_room';
    if (loc.contains('禁林') || loc.contains('forbidden'))
      key = 'forbidden_forest';
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

/// 一次剧情推进的结果，供叙事拼装使用。
///
/// 【为什么抽成结构体】叙事需要同时知道"选了什么 / 效果是什么 / 有没有过场 /
/// 是不是走到了结局"。用一堆可空 out 参数传会变成 6 个 `String?`，
/// 调用点读起来完全不知道哪个对应什么。
class StoryBeat {
  /// 本回合要展示的步（`null` = 走到了结局，或内容缺失）。
  final StoryStepDef? step;

  /// 上一步（因果层引用它来织过渡句）。
  final StoryStepDef? prevStep;

  /// 玩家所做的分支（自由行动时为 `null`）。
  final StoryChoiceDef? choice;

  /// 要写进叙事的"你做了什么"。
  final String consequence;

  /// 进入本步的过场文本。
  final String? onEnterText;

  /// 非空 = 本回合到达结局。
  final String? endingTitle;
  final String? endingBody;

  /// 玩家原文（自由行动降级路径用）。
  final String? freeActionText;

  /// 本回合是否为"自由插话"（不推进剧情步，游标原地不动）。
  ///
  /// 与 [freeActionText] 的区别：[freeActionText] 只表示"这段文本来自玩家原文"，
  /// 本字段表示**引擎语义**——剧情游标没有被移动。叙事拼装与选项构建都要
  /// 据此走不同分支：插话回合必须复用**当前这一步**的选项，否则玩家会看到
  /// 一个没有出口的界面。
  final bool isFreeformInterjection;

  /// AI 为这次插话续写的正文（仅 freeform 路径、且 AI 可用时非空）。
  final String? freeformAiText;

  /// 本回合生效的效果（用于生成可读的数值变动提示）。
  final StoryEffect effect;

  /// 本回合应推进的天数（章节节拍式时间）。
  ///
  /// 【为什么由 beat 携带而不是就地推进】时间推进必须走
  /// `_finalizeTurn → fastForwardDays → _advanceWorldClock` 这条全量结算路径
  /// （游戏周/学院杯/NPC位置/学年推进/事件锚点/月度演化都在里面）。
  /// 在 `_advanceStory` 里就地 `advanceDays` 只会推时钟，漏掉全部结算，
  /// 而且随后 `_finalizeTurn` 还会再按关键词推一次——时间被推两遍。
  final int timeCostDays;

  const StoryBeat({
    required this.step,
    this.prevStep,
    required this.choice,
    required this.consequence,
    this.onEnterText,
    this.endingTitle,
    this.endingBody,
    this.freeActionText,
    this.isFreeformInterjection = false,
    this.freeformAiText,
    this.effect = StoryEffect.none,
    this.timeCostDays = 0,
  });
}

