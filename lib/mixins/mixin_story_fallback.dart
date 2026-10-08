import '../models/game_systems.dart';
import '../providers/game_provider_base.dart';
import 'mixin_narrative_continuity.dart';
import 'mixin_story_round_wrap.dart';
import 'mixin_systems.dart';

/// 上下文回退选项与叙事结算族（第十一轮 r11-3 拆分自 mixin_story_engine.dart）。
///
/// 覆盖：generateContextualFallbackChoices（按当前地点/时间/在场 NPC 生成
/// 离线兜底选项）与 settleAfterNarrative（叙事落定后的回合结算）。
mixin GameStoryFallbackMixin
    on GameProviderBase,
        GameStoryRoundWrapMixin,
        GameNarrativeContinuityMixin {
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
}
