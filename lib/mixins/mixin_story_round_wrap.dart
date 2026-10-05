/// 剧情回合 · 地点与时刻收尾（r8-3 拆分自 mixin_story_engine.dart）。
///
/// 覆盖：`updateLocationTracking`（地点停滞计数）、`appendRecentTurn`（回合尾
/// 追加叙事）、`scanCollectionUnlocks`（叙事扫收藏解锁）、`maybeTriggerConfession`
/// （表白触发）、`tickWorldLineDeviation`（世界线偏移）、`syncLocationFromNarrative`
/// （从叙事文本反推地点/社交意图）与两条预编译正则。
/// `GameStoryEngineMixin` 声明 `on GameStoryRoundWrapMixin`（跨 mixin 走 on 链，
/// 遵守 ADR-001）。行为零变化。
library;

import '../data/collection_data.dart';
import '../data/worldline_data.dart';
import '../data/locations.dart';
import '../data/game_config_rules.dart';
import '../providers/game_provider_base.dart';

mixin GameStoryRoundWrapMixin on GameProviderBase {
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
}
