import 'dart:async';

import 'package:flutter/foundation.dart';

import '../providers/game_provider_base.dart';
import '../narrative/narrative_source_gate.dart';
import '../services/ai_router.dart';
import '../utils/debug_log.dart';
import 'mixin_narrative.dart';
import 'mixin_narrative_canon.dart';
import 'mixin_narrative_continuity.dart';
import 'mixin_story_engine.dart';
import 'mixin_story_round_wrap.dart';
import 'mixin_summary_memory.dart';

/// 离线回合管线（第九轮 r9-1 拆分自 mixin_narrative.dart）。
///
/// 【拆分说明】无 AI 快速模式整回合管线（`runOfflineQuickTurn`：奇遇/羁绊/
/// 回信结算、世界事件补齐、节庆、原著节点、行动后果、社团活动、各触发器、
/// 兜底选项生成）与可选 AI 润色（`maybePolishLocalNarrative`）约 390 行，
/// 从 mixin_narrative 迁入本文件。`GameNarrativeMixin` 声明
/// `on GameNarrativeOfflineMixin`（跨 mixin 走 on 链，遵守 ADR-001），
/// `GameProvider` 的 with 列表中 offline 在 narrative 之前。
/// 行为零变化：所有成员仍是 GameProvider 上的实例成员，测试契约不变。
  /// 上一回合的叙事信息密度（0.0 ~ 1.0），用于调试与调优
  double lastNarrativeDensity = 0.0;

  /// 上次执行润色的回合（节流用）。润色是「可选增强」，不该每回合都打 AI：
  /// 与主叙事/摘要共用同一把 Key，频繁触发只会稀释省 Key 的意义（审批 3.1）。
  int lastPolishTurn = -1;

  /// 每回合信息密度历史记录，用于调试与调优
  final List<NarrativeDensityRecord> narrativeDensityHistory = [];

mixin GameNarrativeOfflineMixin on GameProviderBase, GameNarrativeCanonMixin,
    GameStoryEngineMixin, GameStoryRoundWrapMixin, GameNarrativeContinuityMixin,
    GameSummaryMemoryMixin {
  /// 无 AI 快速模式：完全不调用 AI，用本地模板叙事 + 承接式选项推进一整回合。
  /// 审查 P0「无 AI 快速模式 + 本地兜底剧情」：免费额度耗尽 / 未配 Key 时保底可玩。
  /// 与 AI 失败时的瞬时兜底不同：这里**消耗回合**（推进时间/精力/NPC/影响力），
  /// 因为这是玩家主动选择的正式离线玩法，而不是需要重试的失败。
  void runOfflineQuickTurn(String action, {String? causalResult}) {
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
      lastNarrativeDensity = density;
      narrativeDensityHistory.add(NarrativeDensityRecord(
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
    unawaited(maybePolishLocalNarrative());
  }

  /// 可选「AI 润色」：对本回合已生成的本地叙事做一次轻量措辞润色。
  ///
  /// 【红线】本地模式核心仍是 0 AI——本方法只在 `narrativePolishEnabled`
  /// 已开启 **且** 当前叙事确实来自本地时才触发；任何异常都静默回退原文。
  @visibleForTesting
  Future<String?> polishLocalNarrativeForTest(String text) =>
      maybePolishLocalNarrative(textOverride: text);

  Future<String?> maybePolishLocalNarrative({String? textOverride}) async {
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
    if (textOverride == null && turnCount - lastPolishTurn < 5) return null;

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
        lastPolishTurn = turnCount;
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

  /// 把命中的原著剧情节点融进离线叙事（`runOfflineQuickTurn` 调用）。
  ///
  /// 【为什么单独抽成方法而不是内联】它有三条需要被单测直接钉住的规则
  /// （时代过滤 / 一次性触发 / 每回合最多一条），内联在 1300 行的方法里
  /// 就只能靠"跑整个离线回合"间接验证，定位失败原因成本很高。
  @visibleForTesting
  void injectCanonEventForTest() => injectCanonEventIntoOfflineNarrative();
}
