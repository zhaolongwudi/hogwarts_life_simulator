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

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../data/canon_events.dart';
import '../data/collection_data.dart';
import '../data/item_data.dart';
import '../data/worldline_data.dart';
import '../data/locations.dart';
import '../data/game_config_rules.dart';
import '../models/game_systems.dart';
import '../models/player.dart';
import '../models/long_term_memory.dart';
import '../models/story_progress.dart';
import '../providers/game_provider_base.dart';
import '../data/memory_importance_config.dart';
import '../utils/debug_log.dart';
import 'mixin_systems.dart';
import 'mixin_summary_memory.dart';

/// 主线剧情引擎（离线剧情模式的回合推进与效果落地）。
/// 挂在 [GameProviderBase] 上。
mixin GameStoryEngineMixin on GameProviderBase, GameSummaryMemoryMixin {
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

  /// 把 [StoryEffect] 落到玩家 / 世界 / 长期记忆上。
  ///
  /// 【为什么效果要用"累加"而不是"直接赋值"】
  /// `StoryProgress.effects` 是跨存档累计的，用于结局判定；
  /// 而 `Player` 上的数值会被剧情之外的行为改写（战斗、送礼…），
  /// 两者不能混用，否则结局判定会随日常行为漂移。
  void applyStoryEffect(StoryEffect effect) {
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
  /// 【为什么单独抽一个函数】`applyStoryEffect` 已经很长（数值 + 物品 +
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
          importance: kImportanceStoryEffectLoop,
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
  void markCanonForStep(StoryStepDef step) {
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
    // 【幂等】剧情模式可能重入同一步（读档、跳章开局），但 `markCanonForStep`
    // 上游有 `firedAnchorIds` 语义上的"讲过一次"守卫；即便重入，
    // `addWorldEvent` 按 id 去重、`unlockCG` 按 cgRecords 去重，
    // 三层都是幂等的，不会产生重复记录。
    sinkCanonNodeToMemory(ref);
  }

  /// 把一条原著节点的沉淀物（世界大事 / 悬念开启与了结 / CG）广播出去。
  ///
  /// 节点上三项都是可选的：没填就是"这条节点不产生长期记忆"，
  /// 保持与接线前完全一致的行为。
  void sinkCanonNodeToMemory(String canonId) {
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
              importance: kImportanceAiExtractedLoop,
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
      memory = closeStaleOfflineLoops();
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
  String composeStoryNarrative(StoryBeat beat) {
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
        final lines = localEventLinesWithRoommates(
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
  /// 实例版地点氛围池：在 [localEventLinesFor] 基础上叠加室友系统——
  /// 玩家在宿舍且存在室友时，优先取「室友互动小剧场池」（seed 轮换），
  /// 并把 `$roommate` 占位替换为实际室友名；无室友则退回原地点池。
  /// 供离线回合/沙盒两处实例调用（1719/3061），保持 static 版本不动
  /// 以免破坏既有静态调用测试（batch33_offline_ux_test）。
  List<String> localEventLinesWithRoommates({
    required String location,
    required int hour,
    required int seed,
  }) {
    final lines = localEventLinesFor(
      location: location,
      hour: hour,
      seed: seed,
    );
    if (!location.contains('宿舍')) return lines;
    final rms = roommates();
    if (rms.isEmpty) return lines;
    final roommateName = rms[seed % rms.length].name;
    if (_roommateSceneLines.isNotEmpty) {
      final scene = _roommateSceneLines[seed % _roommateSceneLines.length];
      return [scene.replaceAll('\$roommate', roommateName)];
    }
    return lines.map((l) => l.replaceAll('\$roommate', roommateName)).toList();
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
      // 室友系统人物句（设计文档 3.2：带 $roommate 占位，localEventLinesFor
      // 触发时若玩家在宿舍且存在室友 → 优先取人物句）
      '『再不起来要赶不上早餐了！』室友 \$roommate 一把掀开你的被子。',
      '熄灯后 \$roommate 翻了个身，压低声音问你最近是不是有心事。',
      '\$roommate 把课本摊在桌上，说『这段我猜必考』，拉着你一起背。',
      '\$roommate 摸出一袋滋滋蜜蜂糖，分了半袋给你。',
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

  /// 室友互动小剧场池（设计文档 3.4：8 条，seed 轮换，仅宿舍场景启用）。
  /// 与氛围句互斥：有人物句命中就不叠加环境句。
  /// 带 $roommate 占位，由 localEventLinesFor 替换为实际室友名。
  static const List<String> _roommateSceneLines = [
    '室友 \$roommate 打了一整晚呼噜，你翻来覆去怎么也睡不着。',
    '\$roommate 偷藏的零食被舍监抓了包，你帮忙打圆场才蒙混过去。',
    '你赖床不起，\$roommate 顺手帮你带了份早餐回来。',
    '\$roommate 在课上给你传了张纸条，上面写着隔壁班的新八卦。',
    '\$roommate 怂恿你翘课去霍格莫德，被你严词拒绝后他嘟囔了半天。',
    '你的校袍袖口开了线，\$roommate 翻出针线包帮你补好了。',
    '\$roommate 一脸疲惫地回来，抱怨魁地奇训练实在太累了。',
    '\$roommate 问你周末要不要一起去对角巷逛逛。',
  ];


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

  /// 关闭指令结果面板，恢复显示当前回合剧情（不消耗回合、不调用 AI）

  @override
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


/// 一次剧情推进的结果，供叙事拼装使用。

  void finalizeTurn(
    String narrative,
    String action, {
    int? storyTimeCostDays,
    String? semanticAction,
  }) {
    // ⓪ 图鉴收录（见 data/collection_data.dart）：扫描本回合叙事，命中
    // 新条目时把一行提示追加到叙事尾部——放在锚点/摘要**之前**，让收录
    // 提示随本回合文本一并入档，而不是悄悄消失。
    final collectionHint = scanCollectionUnlocks(narrative);
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

  /// 叙事定稿之后、选项生成之前的周期结算。返回本回合是否有人表白。
  ///
  /// AI 正式路径与无 AI 快速模式共用同一份，原因很实在：第五轮把「状态推进」
  /// （turnCount++ / lastPlayerAction / commandResult）搬进了离线路径，却把
  /// 周期结算整个漏掉了，于是离线玩法下
  ///   · NPC 主动表白永不触发（恋爱线是核心玩法）；
  ///   · 世界线变动率恒为 0.5%，world_changer 成就永远拿不到；
  ///   · 同地点停滞检测失效（updateLocationTracking 只挂在 buildPrompt 里，
  ///     离线不调 AI 就永远走不到）。
  /// 抽成方法之后，一边加结算另一边自动跟上。
  bool settleAfterNarrative() {
    final bool confessedThisTurn = maybeTriggerConfession();
    tickWorldLineDeviation();
    // 坏结局二「自由尽失」：黑魔法声望压过道德底线时，回合结算触发被捕
    // （内部自带 isDead/isImprisoned/无敌/年级 前置判定，无条件满足不动作）
    checkImprisonment();

    // 从叙事文本中提取新地点并同步 currentLocation
    // 这是「场景推进」的闭环：AI 写了换场景 → 状态同步 → 停滞计数清零
    // 否则 currentLocation 永远停在初始值，AI 会以为玩家还在原地
    syncLocationFromNarrative(currentNarrative);

    // --- P0-2 短期断言：从本回合叙事末尾提取生效状态，下回合 Prompt 必注入 ---
    final newAssertions = extractShortAssertions(currentNarrative);
    rotateTurnAssertions(newAssertions);
    return confessedThisTurn;
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

  /// 回合开始时更新地点停滞计数。
  /// 若 currentLocation 与上一回合相同，则 turnsAtSameLocation++；
  /// 若已变化（如玩家手动 travelTo），则清零并记录新地点。
  void updateLocationTracking() {
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

  @override
  void appendRecentTurn(String narrative) {
    final trimmed = narrative.trim();
    if (trimmed.isEmpty) return;
    recentTurns.add(trimmed);
    while (recentTurns.length > GameProviderBase.maxRecentTurns) {
      recentTurns.removeAt(0);
    }
  }

  /// 扫描一段叙事文本，把新命中的图鉴条目收录进 [collectionUnlocked]，
  /// 返回给玩家的收录提示行（无新收录时返回 null）。
  ///
  /// 【为什么挂在 finalizeTurn】剧情模式（`advanceStory`）与沙盒模式
  /// 最后都汇进 `finalizeTurn` 收尾——一处钩子，两条路径全覆盖。
  /// 只扫**本回合新增**文本：老内容反复被引用也不会重复提示（集合去重），
  /// `matchCollection` 是纯函数（~60 条 × contains），每回合一次开销可忽略。
  String? scanCollectionUnlocks(String text) {
    final fresh = matchCollection(text).difference(collectionUnlocked);
    if (fresh.isEmpty) return null;
    collectionUnlocked.addAll(fresh);
    final names =
        fresh.map((id) => collectionById(id)?.name ?? id).toList()..sort();
    final shown = names.take(3).join('、');
    final extra = names.length > 3 ? ' 等 ${names.length} 条' : '';
    return '✦ 图鉴收录：$shown$extra（/图鉴 查看）';
  }

  /// 每回合尝试触发一次 NPC 主动表白，返回本回合是否真的表白了。
  ///
  /// 为什么单独抽成方法：checkNPCConfessions 原本只被 parseResponse 调用，
  /// 而 parseResponse 只在开局 generateOpeningScene 里跑一次（那时 turnCount==0，
  /// 连 `turnCount > 0` 的门槛都过不去）。正常回合走 parseNarrativeOnly +
  /// applyNarrativeSideEffects，那条链上根本没有它——也就是说，好感 85+、暧昧、
  /// 浪漫事件 2 次以上、暧昧满两周，四个条件全满足也永远不会有人来表白。
  /// 恋爱系统的高潮（以及 CG-CF-001/002/003、first_confession、in_love 成就、
  /// 整张 loveReputationEffects 声望表）全是死的。
  bool maybeTriggerConfession() {
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
  void tickWorldLineDeviation() {
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
  void syncLocationFromNarrative(String narrative) {
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
        if (_reHomePlace.hasMatch(tag)) {
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

  /// 「家中」大类地点（syncLocationFromNarrative 每回合，预编译）。
  static final RegExp _reHomePlace =
      RegExp(r'(家中|家里|住宅|庄园|别墅|卧室|书房|花园|密室|走廊|客厅|门厅)',
          caseSensitive: false);

  /// 社交意图关键词（syncLocationFromNarrative 判定"是否与人互动"用）。
  static final RegExp _reSocialIntent =
      RegExp(r'(与|和|跟|找|邀|问|对话|聊天|约会|见面|散步|陪|一起|独处|深入|表白|感情|心动)');

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

/// 情报 token 归一化：剥掉下划线与所有非文字字符（`_composeCausalText` 用）。
///
/// 【为什么提为文件级】它在 `_composeCausalText` 的循环里逐条情报调用，
/// 而本仓库有源码形状守卫（`test/regex_hotpath_test.dart`）专门禁止
/// "循环内现编译 RegExp"。这条守卫曾抓出过真实的性能回归，不是风格洁癖。
final RegExp _reNonWordChars = RegExp(r'[_\W]+');