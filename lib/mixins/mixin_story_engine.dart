/// 主线剧情模式（离线）· 剧情引擎（阶段 r5-1 拆分自 mixin_narrative.dart）。
///
/// 【拆分说明】剧情回合分发（`runStoryTurn` / `advanceStory`）、章节与
/// 书籍推进、自由插话、剧情效果落地（`applyStoryEffect` /
/// `_routeEffectToWorld`）、原著节点沉淀、叙事拼装与选项构建、离线氛围
/// 事件池（`localEventLinesFor` 等）约 1530 行 + `StoryBeat` 结构体，
/// 从 4165 行的 mixin_narrative 迁入本文件。
/// `GameNarrativeMixin` 声明 `on GameStoryEngineMixin`（跨 mixin 走 on 链，
/// 遵守 ADR-001），`GameProvider` 的 with 列表中 engine 在 narrative 之前。
/// 行为零变化：所有成员仍是 GameProvider 上的实例成员，测试契约不变。
library;


import 'dart:async';
import 'mixin_story_round_wrap.dart';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../data/canon_events.dart';
import '../models/game_systems.dart';
import '../models/long_term_memory.dart';
import '../models/story_progress.dart';
import '../providers/game_provider_base.dart';
import '../data/memory_importance_config.dart';
import '../utils/debug_log.dart';
import 'mixin_systems.dart';
import 'mixin_summary_memory.dart';
import 'mixin_story_wiring.dart';
import 'mixin_story_fallback.dart';
import 'mixin_story_compose.dart';

/// 主线剧情引擎（离线剧情模式的回合推进与效果落地）。
/// 挂在 [GameProviderBase] 上。
mixin GameStoryEngineMixin on GameProviderBase,
        GameStoryRoundWrapMixin,
        GameStoryWiringMixin,
        GameSummaryMemoryMixin,
        GameStoryFallbackMixin,
        GameStoryComposeMixin {

  /// [r11-4] 实现已迁至 [GameStoryComposeMixin.localEventLinesFor]（氛围拼装族）。
  /// 保留 static 转发以维持 batch33 等静态调用契约（零行为变化）。
  static List<String> localEventLinesFor({
    required String location,
    required int hour,
    required int seed,
  }) =>
      GameStoryComposeMixin.localEventLinesFor(
          location: location, hour: hour, seed: seed);
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
  //   1. 全程 0 AI 调用（`maybeRunPeriodicSummary` 内部已按离线直接 return）；
  //   2. 不进入 `buildFallbackChoices`——那个函数的 `hookAnswer` 判据含
  //      `tail.contains('你的选择')`，而离线兜底叙事框架句恰有
  //      「你的选择，会把它推向不同的方向。」→ 在离线路径下**恒为真**，
  //      会把剧情选项全部冲掉。用独立的 `buildStoryChoices` 从根上绕开。
  //   3. 后半段结算（`settleAfterNarrative` / `finalizeTurn`）**必须共用**，
  //      否则时间/精力/NPC/影响力/存档会与沙盒路径全线不一致。

  /// 一整个剧情回合。与沙盒回合共用后半段结算，前半段完全走剧情引擎。
  ///
  /// 【为什么不 declare `@visibleForTesting`】它是生产路径
  /// （`_runOfflineQuickTurn` 分发）真正要调的，加了会直接报错。
  void runStoryTurn(String action, {String? causalResult}) {
    commandResult = causalResult;
    error = null;
    turnCount++;
    lastScannedNarrativeHash = null;
    lastPlayerAction = action;

    updateLocationTracking();

    // 「开启下一部」专用通道（结局后选项）。必须在剧情推进之前拦截：
    // 若放行，parseStoryCommand 解析不出合法分支 → isFreeAction 降级，
    // 玩家点按钮只会白白烧一个回合。这里直接走衔接逻辑并提前收尾。
    if (action == kStoryNextBookAction) {
      _runNextBookTransition();
      return;
    }

    // ① 推进剧情：解析分支 → 查定义 → 落效果 → 定位下一步。
    //    返回本回合要写进叙事的"你做了什么"，null 表示走到了结局。
    final beat = advanceStory(action);

    // ② 拼叙事（三层三明治）。
    currentNarrative = composeStoryNarrative(beat);

    // ③ 结算与收尾：与沙盒路径**同一套函数**，只有时间推进方式不同
    //    （章节节拍式天数，见 finalizeTurn 的参数说明）。
    //    表白可能改写 currentNarrative——剧情模式下不采纳它的改写
    //    （剧情文本优先），但表白状态机照常落库。
    settleAfterNarrative();
    finalizeTurn(
      currentNarrative,
      action,
      storyTimeCostDays: beat.timeCostDays,
      semanticAction: semanticActionOf(beat, action),
    );

    // ④ 剧情选项（独立构建器，不进 buildFallbackChoices）。
    choices = buildStoryChoices();

    // ⑤ 结局态的世界衔接：玩家自由行动把时间玩到了下一部锚点 →
    //    自动开新书并覆盖本回合的叙事/选项（结局文本已经看过了）。
    if (storyProgress.isFinished && _maybeAutoBeginNextBook()) {
      choices = buildStoryChoices();
    }

    maybeRunPeriodicSummary();
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
      // 【为什么显式转型】与 `finalizeTurn` 内的既有口径一致（见该处注释）。
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
    settleAfterNarrative();
    // 快进已经手动做过，这里只按常规节拍再走 1 天（锚点日当天的结算）。
    finalizeTurn(currentNarrative, kStoryNextBookAction, storyTimeCostDays: 1);
    choices = buildStoryChoices();

    maybeRunPeriodicSummary();
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
    markCanonForStep(first);

    turnCount = 0;
    lastPlayerAction = '';
    lastScannedNarrativeHash = null;

    final ordinal = kBookOrder.indexOf(nextId) + 1;
    currentNarrative = composeStoryNarrative(
      StoryBeat(
        step: first,
        choice: null,
        consequence: '',
        onEnterText: '—— 第 $ordinal 部 · ${nextBook.title} ——\n'
            '${first.onEnterText ?? ''}'.trim(),
      ),
    );
    choices = buildStoryChoices();
    notifications.add('📖 新篇章：《${nextBook.title}》');
    memory = memory.addWorldEvent(
      WorldEventRecord(
        id: 'story_begin_$nextId',
        timestamp: worldState.time.format(),
        title: '新篇章开启',
        description: '《${nextBook.title}》的剧情开始了。',
        importance: kImportanceStoryBegin,
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

  /// 用一个小结构体而不是一堆 out 参数，是因为叙事需要同时知道
  /// "选了什么"、"效果是什么"、"有没有插曲"——拆成参数会变成 4 个可空值。
  StoryBeat advanceStory(String action) {
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
      return advanceStory(action);
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
    // 【为什么放在这里而不是 runStoryTurn】选分支与插话共用
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
    // 【顺序要命】`applyStoryEffect` 内部会 `storyProgress = ...copyWith(...)`
    // 把 effects/flags/knowledge 写进去。所以它之后**必须**以
    // `storyProgress`（最新值）为基底继续构造，而不是用上面那个
    // `progress` 局部快照——否则新建的 `updated` 会把刚落的 effects
    // 覆盖回空，表现为"选项点了、剧情走了，但数值和 flag 全丢了"。
    // 这个缺陷是 `story_turn_test.dart` 的 D 组抓出来的。
    final effect = choice.effect;
    applyStoryEffect(effect);
    final latest = storyProgress;

    // 记录选择与完成步。
    final doneSteps = List<String>.from(latest.doneSteps);
    if (!doneSteps.contains(step.id)) doneSteps.add(step.id);
    final chosen = Map<String, String>.from(latest.chosen);
    chosen[step.id] = choice.id;

    // 节拍式时间推进：**不用 advanceTimeForAction 的关键词推断**。
    // 具体推进在 `finalizeTurn(storyTimeCostDays:)` 里做（那里才拿得到
    // `fastForwardDays` 的全量结算），这里只把本步的步长带到叙事结构上，
    // 供 `runStoryTurn` 取用。这样时间只推一次，不会与关键词推断叠加。

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
    markCanonForStep(nextStep);

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
      // 传了会让 `composeCausalText` 织出"你此前的做法还留有余波"这种
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
  /// 【为什么这里同步返回而不是 async】`runStoryTurn` 整条链路是同步的
  /// （它要保证"点一下按钮 = 一个完整回合"的原子性，包括自动存档）。
  /// AI 续写是**可选的增强**，为它把整条链路改成异步会波及
  /// `finalizeTurn` / `settleAfterNarrative` / `autoSave` 的时序契约，
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
      markCanonForStep(first);
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
    // 所以必须用**结算后的** progress（effects 已在 applyStoryEffect 里累加）。
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
        importance: kImportanceStoryEnding,
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




  /// 构建剧情选项。
  ///
  /// 【为什么不能用 `buildFallbackChoices`】那个函数的 `hookAnswer` 判据含
  /// `tail.contains('你的选择')`（`mixin_response.dart:1097`），而离线兜底
  /// 叙事的框架句 2 恰有固定句「你的选择，会把它推向不同的方向。」
  /// → **整个离线路径下 `hookAnswer` 恒为真**，任何排在它后面的分支都是死代码。
  /// 剧情模式直接读 `StoryStepDef.choices`，不进入那个函数，从根上绕开。
  List<GameChoice> buildStoryChoices() {
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
    markCanonForStep(first);

    turnCount = 0;
    lastPlayerAction = '';
    commandResult = null;
    error = null;
    lastScannedNarrativeHash = null;

    currentNarrative = composeStoryNarrative(
      StoryBeat(
        step: first,
        choice: null,
        consequence: '',
        onEnterText: first.onEnterText,
      ),
    );
    choices = buildStoryChoices();
    appendRecentTurn(currentNarrative);
    accumulateForSummary(currentNarrative);

    notifications.add('📖 主线剧情开始：《魔法石》');
    memory = memory.addWorldEvent(
      WorldEventRecord(
        id: 'story_start_${first.id}',
        timestamp: worldState.time.format(),
        title: '主线剧情开始',
        description: '你开始按原著时间线经历这一学年。',
        importance: kImportanceStoryStart,
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

  /// 室友互动小剧场池（设计文档 3.4：8 条，seed 轮换，仅宿舍场景启用）。
  /// 与氛围句互斥：有人物句命中就不叠加环境句。




  /// 重试上一次失败的行动。
  ///
  /// AI 调用失败时游戏会切本地兜底剧情，玩家点「重试」即可用同一句话
  /// 重新走一遍正式流程（而不是手动把原话再敲一遍）。
  /// 失败前的兜底叙事会先撤掉，避免重试成功后新旧正文叠在一起。
  @override
  Future<void> retryLastAction() async {
    final action = lastPlayerAction.trim();
    if (action.isEmpty) return;
    error = null;
    await processChoice(GameChoice(text: action, action: action));
  }

  /// 手动关掉错误提示条（玩家点 ✕ 时用，不重跑任何逻辑）
  @override
  void clearError() {
    error = null;
    notifyListeners();
  }


  /// 回合收尾落库：锚点、摘要缓冲、近期回合、时间/精力、NPC、影响力。
  ///
  /// 与 [settleAfterNarrative] 一起构成「一整个回合」的后半段，
  /// 两条路径必须共用（理由同上）。
  ///
  /// [storyTimeCostDays] 非空时走**章节节拍式时间**：直接按显式天数推进，
  /// 不做行动关键词推断。为什么剧情模式必须这样：
  ///   · `advanceTimeForAction` 按关键词猜时长（"去图书馆查资料"可能算半天），
  ///     剧情 8 章只该跨几个月，猜出来的时间会让原著节点的月份整体错位；
  ///   · `fastForwardDays` 内部走 `advanceWorldClock` 全量结算（游戏周/
  ///     学院杯/NPC 位置/学年推进/事件锚点/月度演化），语义比"猜时长"精确得多。
  /// 把一回合的剧情节拍压成一段**给关键词系统读的中文行动串**。
  ///
  /// 【为什么需要它】见 `finalizeTurn` 里 `semanticAction` 的说明：
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
  String semanticActionOf(StoryBeat beat, String fallback) {
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


  /// 直接落一份剧情效果（测试用）。
  ///
  /// 【为什么需要】`_applyStoryEffect` 的新接线字段（openLoops / addQuests /
  /// addWorldEvents / unlockCgs / energy / satiety）目前只有运行时路径会走到，
  /// 而运行时路径必须先有内容层声明这些字段——内容层还没铺到那儿时，
  /// 接线本身就成了"没有测试覆盖的代码"。这个入口让接线可以被**独立**钉死，
  /// 不必等 102 个节点的内容全部补完。
  @visibleForTesting
  void applyStoryEffectForTest(StoryEffect effect) =>
      applyStoryEffect(effect);

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
      sinkCanonNodeToMemory(canonId);


  void injectCanonEventIntoOfflineNarrative() {
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

}
