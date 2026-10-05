import 'dart:async';
import 'mixin_academic_year.dart';
import '../models/world_state.dart';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../models/npc.dart';
import '../models/game_systems.dart';
import '../services/deepseek_service.dart';
import '../data/event_anchors.dart';
import '../data/game_config_rules.dart';
import '../data/locations.dart';
import '../data/time_cost_rules.dart';
import '../data/monthly_event_data.dart';
import '../data/blood_status.dart';
import '../data/ending_review_data.dart';
import '../data/scar_data.dart';
import '../data/house_data.dart';
import '../data/house_cup_data.dart';
import '../data/attribute_data.dart';
import '../models/player.dart';
import '../models/long_term_memory.dart';
import '../data/balance_constants.dart';
import '../data/goal_data.dart';
import '../data/parallel_data.dart';
import '../data/npc_schedule_rules.dart';
import '../data/rivalry_data.dart';
import '../data/wand_data.dart';
import '../data/worldline_data.dart';
import '../services/ai_router.dart';
import '../utils/npc_lookup.dart';
import '../providers/game_provider_base.dart';
import '../utils/debug_log.dart';
import 'mixin_game_save.dart';
import '../data/memory_importance_config.dart';

mixin GameSystemsMixin on GameProviderBase, GameAcademicYearMixin, GameSaveSystemMixin {

  /// 浪漫行动关键词（每回合 updateNPCsFromAction 热路径，预编译）。
  static final RegExp _reRomanticAction = RegExp(
      r'(约会|散步|独处|谈心|表白|浪漫|心仪|心动|一起去看|一起吃饭|单独)');

  /// 缓存：上次构建的 systemPrompt 和玩家状态哈希（用于检测是否需要重建）
  String? _lastSystemPrompt;
  String? _lastPlayerStateHash;

  /// 推进世界时钟，并统一执行所有周期性检查
  /// （游戏周、满月、学年切换、事件锚点、一致性、月度演化）。
  ///
  /// [days] 不为 null 时按整天快进（/快进 指令），否则按分钟推进。
  /// [fireAnchors] 为 false 时跳过事件锚点检测——长距离跳跃只在终点触发一次，
  /// 否则一次跳跃会灌入十几个剧情节点通知。
  void advanceWorldClock(int minutes, {int? days, bool fireAnchors = true}) {
    final oldMonth = worldState.time.month;
    final oldYear = worldState.time.year;
    final oldHour = worldState.time.hour;
    final oldDayIndex = worldState.time.absoluteDayIndex;
    if (days != null) {
      worldState.time.advanceDays(days);
    } else {
      worldState.time.advanceMinutes(minutes);
    }
    // 时钟是**跳**过去的，不是一格一格走的。事件锚点的时段窗口必须按
    // "经过的区间"来匹配，否则睡一觉（480 分钟）就能把窗口整个跨过去，
    // 那条剧情节点就静默消失了。
    final hourFrom = oldHour;
    final dayDelta = worldState.time.absoluteDayIndex - oldDayIndex;

    // 游戏周追踪（好感沉淀用）：以绝对天数 / 7 分桶，
    // 只有当绝对天数跨过整周边界时才推进游戏周，避免 dayOfYear 头尾截断导致开局即跨周。
    //
    // 基准通过 weekBucketBaseline 惰性建立：新开局/读档后第一次走到这里时，
    // 基准 = 当前桶号，跨周数为 0。这样**不依赖任何一处在别处补的初始化**——
    // 旧实现用 `lastWeekBucket = 0` 占位、靠 mixin_init/applySaveData 各补一次，
    // 漏一处就会把 gameWeek 一次性抬到几十（绝对周桶是从 1991 年起算的大数）。
    final newBucket = worldState.time.absoluteDayIndex ~/ 7;
    final baseline = weekBucketBaseline(worldState.time.absoluteDayIndex);
    if (newBucket > baseline) {
      // 补齐跨过的所有整周（快进时一次可能跨很多周）
      final weeksCrossed = newBucket - baseline;
      gameWeek += weeksCrossed;
      lastWeekBucket = newBucket;
      resetWeeklyAffectionCaps(weeksCrossed);
    }

    // 学院杯年度榜：跨过上学日时，其他三院逐日自然增长（世界不因玩家而停转）。
    // 学年末结算时揭晓真实排名，不再掷一次骰子。
    if (dayDelta > 0) {
      _accumulateHouseCupRivals(dayDelta);
    }

    // 轻伤会好。
    //
    // 这里是清空而不是"逐条好"：`injuries` 存的是纯文本、没有受伤时间，
    // 而擦伤、瘀青这类东西本来几天就该好。不清的话玩家身上会永远
    // 挂着一条三年前的「禁林擦伤」——它没有任何判定会读到，
    // 纯粹是 prompt 里的一行噪音。
    //
    // 重伤走另一条路（scars，见 tryScarFromNarrative），那个不会好。
    if (dayDelta > 0 && (player?.injuries.isNotEmpty ?? false)) {
      player!.injuries.clear();
    }

    // 深夜触发满月标记
    if (worldState.time.isFullMoon &&
        !worldState.specialMarkers.contains('🌙满月')) {
      worldState.specialMarkers.add('🌙满月');
    } else if (!worldState.time.isFullMoon) {
      worldState.specialMarkers.remove('🌙满月');
    }

    // 同步旧字段
    worldState.dayOfMonth = worldState.time.day;
    worldState.dayOfWeek = GameTime.weekdays[worldState.time.weekday];
    worldState.month = GameTime.months[worldState.time.month - 1];

    // NPC 位置刷新：时钟动了，人就该动。
    // 不刷的话 npc.currentLocation 永远是构造时的 '霍格沃茨'，
    // npcsInCurrentLocation() 的 contains 判定永远为假，prompt 里的【在场】
    // 一行一次都出现不了。
    refreshNpcLocations(
      npcRegistry.values,
      worldState.time.hour,
      worldState.time.weekday,
    );

    // 学年推进检测（9月1日触发）
    checkSchoolYearTransition(oldMonth, oldYear);

    // 事件锚点检测（按月份触发手写剧情骨架）
    if (fireAnchors) {
      checkEventAnchors(hourFrom: hourFrom, dayDelta: dayDelta);
    }

    // 孕期推进（结婚 → 备孕 → 分娩）
    advancePregnancy();

    runConsistencyChecks();

    checkMonthlyEvolution(oldMonth, oldYear);

    // ====== 传闻传播：从近期世界事件中自动生成传闻 ======
    if (dayDelta > 0 && player != null) {
      _maybeGenerateRumor();
    }
  }

  /// 从近期世界事件中自动生成一条传闻（约 20% 概率）
  ///
  /// Batch 8 · Issue #12：加近 7 天去重 + 「已被传闻化」标记 + 每日 1 条节流。
  /// 旧实现只靠 addRumor 的精确文本去重，但 prefix 随机导致同一事件生成不同
  /// 文本，绕过精确去重——同一事件可被反复传闻化。
  void _maybeGenerateRumor() {
    final p = player;
    if (p == null) return;
    final rand = random;

    // 1. 每日节流：一天最多生成 1 条传闻
    if (!canDoDaily('rumor')) return;

    // 2. 概率门槛（保留原 20%）
    if (rand.nextDouble() > 0.2) return;

    final recentEvents = worldState.recentNarrativeEvents;
    if (recentEvents.isEmpty) return;

    // 3. 排除近 7 天内已传闻化的事件
    final today = worldState.time.absoluteDayIndex;
    final candidates = recentEvents
        .where((e) {
          final lastDay = rumoredEventDays[e.text];
          return lastDay == null || (today - lastDay) >= 7;
        })
        .toList();
    if (candidates.isEmpty) return;

    final event = candidates[rand.nextInt(candidates.length)];
    final text = event.text;

    final rumorPrefixes = [
      '最近校园里大家都在议论：',
      '走廊上有人窃窃私语，说',
      '有消息灵通的学生透露，',
      '公共休息室里传开了：',
      '据可靠消息，',
    ];
    final prefix = rumorPrefixes[rand.nextInt(rumorPrefixes.length)];

    // 截取事件文本的核心部分（去掉标记和年份）
    final cleanText = text
        .replaceAll(RegExp(r'^【.*?】'), '')
        .replaceAll(RegExp(r'^\d{4}年\d{1,2}月'), '')
        .trim();
    if (cleanText.length < 5) return;

    final rumor = '$prefix$cleanText';
    addRumor(rumor);
    // 4. 标记该事件已被传闻化（记录当天，供 7 天去重判定）
    rumoredEventDays[text] = today;
    // 5. 记录每日节流计数
    recordDailyActivity('rumor');
  }

  @override
  void advanceTimeForAction(String action) {
    advanceWorldClock(resolveActionCost(action));
  }

  /// 学院杯年度榜：其他三院按上学日逐日自然增长。
  ///
  /// 由 `advanceWorldClock` 跨天时调用。只算上学日（周一~周五）且只在
  /// 学期内（第一/第二学期）增长——暑假大家都回家了，没有公开加分的
  /// 校规在跑。玩家学院的行不在这里加：它 = 基准 + 玩家本学年贡献，
  /// 由 `addHouseCupPoints` 实时同步，避免这里再加一遍把玩家学院顶飞。
  void _accumulateHouseCupRivals(int dayDelta) {
    if (dayDelta <= 0) return;
    if (worldState.term == 'summer') return;

    final yearly = worldState.houseCupYearly;
    // 四院缺谁补谁（putIfAbsent 不动已有的行）：
    // 玩家可能先挣分把自家学院行写进去——不能因为表非空就把其他三院漏掉。
    if (yearly.length < kHouseNames.length) {
      for (final h in kHouseNames) {
        yearly.putIfAbsent(h, () => kHouseCupBaseScore);
      }
    }

    final p = player;
    // 用 houseKeyOrNull 而不是 `p.house != null`：空串 / AI 写出的非四院名称
    // 会被 houseDisplayName 兜成「未分院」，于是「玩家的学院行只由贡献驱动」
    // 这条判断对不上任何一行，玩家的学院照样每天被 NPC 随机加分带着走。
    final myCn = p == null ? null : houseDisplayName(houseKeyOrNull);
    final curWeekday = worldState.time.weekday; // 0=周日 … 6=周六
    for (var i = 0; i < dayDelta; i++) {
      // 从当前周几往前数第 i 天；weekday 往前回绕要用模 +7 保正
      final wd = ((curWeekday - i) % 7 + 7) % 7;
      if (wd == 0 || wd == 6) continue; // 周末不上课
      for (final h in yearly.keys) {
        if (h == myCn) continue; // 玩家的学院行只由贡献驱动
        yearly[h] =
            yearly[h]! +
            random.nextInt(kHouseRivalDailyMax - kHouseRivalDailyMin + 1) +
            kHouseRivalDailyMin;
      }
    }
  }

  // ==================== 每日活动次数上限 ====================

  /// 每个游戏日允许的高收益活动次数上限。
  static const Map<String, int> kDailyActivityLimits = {
    'duel': 3,
    'quidditch': 2,
    'forest': 4,
    // 课堂互动有属性/声望收益：不限次数会击穿成长曲线（一天刷满全属性）。
    'classroom': 3,
    // 打工是稳定印钞机：每天最多两单，经济才不会被通胀。
    'job': 2,
    // 练咒是「优等生」成就（任一学业熟练度 ≥ 90）唯一稳定的熟练度来源，
    // 不设限的话一个下午就能把某门课顶到 90；设 3 次则七年的学业节奏刚好。
    'spell': 3,
    // 学新咒每天一个：咒语一共 26 个，一天全学会就没得玩了。
    'learn_spell': 1,
    // P14 社团日常记分（Batch 5 · Issue #7 统一口径）：一天之内
    // 能靠离线行动点亮几次属于本社团的活动。原为 6 回合冷却
    // ≈ 6 天，现改为 1 次/日 ——对齐已有断言『同一处干系事不会每个回合被点亮』。
    'club_activity': 1,
    // P15 club task progress: per-day push cap. requiredRounds is usually
    // 4~10, so 3 pushes/day completes a short task in ~3-4 days.
    'club_task': 3,
    // Batch 8 · Issue #12：传闻生成节流。
    // 旧实现每天 20% 概率触发，无近 N 天去重、无「已被传闻化」标记、无总量护栏——
    // 同一事件可被反复传闻化（prefix 随机导致同一事件生成不同文本，绕过 addRumor 的精确去重）。
    // 现改为：每天最多 1 条 + 同一事件 7 天内不重复 + 总量 20 条上限（addRumor 已有）。
    'rumor': 1,
  };

  /// 今日该活动已进行的次数（跨天自动归零）。
  @override
  int dailyCountOf(String activity) {
    _rollDailyActivityIfNeeded();
    return dailyActivityCount[activity] ?? 0;
  }

  @override
  int dailyLimitOf(String activity) => kDailyActivityLimits[activity] ?? 99;

  /// 今日是否还能进行该活动。
  @override
  bool canDoDaily(String activity) =>
      dailyCountOf(activity) < dailyLimitOf(activity);

  /// 记录一次活动。
  @override
  void recordDailyActivity(String activity) {
    _rollDailyActivityIfNeeded();
    dailyActivityCount[activity] = (dailyActivityCount[activity] ?? 0) + 1;
  }

  void _rollDailyActivityIfNeeded() {
    final t = worldState.time;
    final today = '$t.year-$t.month-$t.day';
    if (today != activityDate) {
      activityDate = today;
      dailyActivityCount.clear();
      // 决斗对手的「同一天不能连着挑战同一个人」限制也得跟着跨天解除。
      // 以前它只在 resetAllState 里清，于是打过马尔福之后，
      // 之后任何一天再挑战他都会被拒，而提示语还写着「今天已经比过一场了」。
      lastDuelOpponentId = null;
    }
  }

  // ==================== 玩家手记 ====================

  /// 新增一条手记。写入 Player 并落盘，返回后不会丢。
  void addDiaryEntry({
    required String title,
    required String content,
    String mood = '📖',
  }) {
    final p = player;
    if (p == null) return;
    final t = worldState.time;
    p.diary.insert(
      0,
      DiaryEntry(
        date: '$t.year年$t.month月$t.day日',
        time: '${t.hour}:${t.minute.toString().padLeft(2, '0')}',
        title: title,
        content: content,
        mood: mood,
      ),
    );
    // 与 forumPosts / jobHistory / letters 一样给个上限：
    // 这三个都有 50 条封顶，唯独 diary 只 insert(0) 不 trim，
    // 玩家每记一笔就多一条，万回合下来存档里堆的全是日记。
    if (p.diary.length > kMaxDiaryEntries) {
      p.diary.removeRange(kMaxDiaryEntries, p.diary.length);
    }
    notifyListeners();
    unawaited(autoSave());
  }

  void removeDiaryEntry(int index) {
    final p = player;
    if (p == null || index < 0 || index >= p.diary.length) return;
    p.diary.removeAt(index);
    notifyListeners();
    unawaited(autoSave());
  }

  // ==================== 平行世界小剧场 ====================

  /// 新增一条玩家自己写的脑洞。
  ///
  /// 「平行世界·小剧场」那一页以前把玩家写的东西存在 Widget 的局部变量里，
  /// 退出页面就没了；现在进 Player 随存档持久化，跟手记同一套处理。
  void addParallelScenario({
    required String title,
    required String description,
    String icon = '🎭',
  }) {
    final p = player;
    if (p == null) return;
    p.parallelScenarios.insert(
      0,
      ParallelScenario(title: title, description: description, icon: icon),
    );
    notifyListeners();
    unawaited(autoSave());
  }

  void removeParallelScenario(int index) {
    final p = player;
    if (p == null || index < 0 || index >= p.parallelScenarios.length) return;
    p.parallelScenarios.removeAt(index);
    notifyListeners();
    unawaited(autoSave());
  }

  /// 把一条脑洞「采纳」进主线。
  ///
  /// 采纳不是说它真的发生了——那会让玩家写一句就改一次世界，
  /// 世界线变动率那套"改写得付代价"的逻辑就成了空话。
  /// 采纳的落点是：它变成这个人心里的**一件事**。
  /// 详见 lib/data/parallel_data.dart 顶上的说明。
  ///
  /// 采纳过的不能撤销，也不能重复采纳：一个念头你只能决定留不留下一次，
  /// 反复采纳会把"想起它"这件事变成可以刷的东西。
  bool adoptParallelScenario(int index) {
    final p = player;
    if (p == null || index < 0 || index >= p.parallelScenarios.length) {
      return false;
    }
    final s = p.parallelScenarios[index];
    if (s.adopted) return false;

    p.parallelScenarios[index] = s.copyWith(adopted: true);

    // 一条长期记忆。6 分而不是更高：它重要，但没重要到挤掉
    // 真正发生过的事——它毕竟是"想过的"，不是"做过的"。
    memory = memory.addKeyFact(
      KeyFactRecord(
        id: 'whatif_${s.createdAt}_${s.title.hashCode}',
        fact: adoptedFactFor(s),
        importance: kImportanceWhatIf,
        timestamp: worldState.time.format(),
        category: 'what_if',
      ),
    );

    notifications.add(adoptedNoticeFor(s));
    notifyListeners();
    unawaited(autoSave());
    return true;
  }

  // ==================== 人生目标的剧情牵引 ====================

  /// 把玩家设定的人生目标拼成注入给 AI 的一行。
  ///
  /// LifeGoal.steeringHint 那段文案（「偏向傲罗方向成长：黑魔法防御、战斗声望」）
  /// 写了整整 10 条，却从来没有任何一处读取它——/目标 只把目标**名字**存进
  /// player.currentGoal，注入 prompt 时也只拼名字。AI 看到的是「傲罗」两个字，
  /// 看不到那条牵引。目标因此是「存了但没牵引」。
  @override
  String goalSteeringLine(String? goalName) {
    if (goalName == null || goalName.isEmpty) return '';
    final goal = goalByName(goalName);
    if (goal == null) return goalName;
    return '$goalName —— ${goal.steeringHint}';
  }

  // ==================== 魔法论坛 ====================
  //
  // 论坛页以前整页都是硬编码常量：五条署名赫敏/纳威的样板帖跟这局剧情毫无关系，
  // 玩家自己发的帖只是往 Widget 的局部 List 里 insert，退出页面即丢，
  // 点赞和回复数同理。现在玩家发的帖进 Player.forumPosts 随存档走。

  /// 发一帖。返回新帖 id，失败返回 null。
  String? addForumPost({required String category, required String content}) {
    final p = player;
    if (p == null) return null;
    final text = content.trim();
    if (text.isEmpty) return null;

    final id = 'fp_${DateTime.now().microsecondsSinceEpoch}';
    p.forumPosts.insert(
      0,
      ForumPost(
        id: id,
        category: category,
        content: text,
        author: p.name,
        timeLabel: worldState.timestamp,
      ),
    );
    // 只留最近 50 帖，避免存档无限膨胀
    if (p.forumPosts.length > 50) {
      p.forumPosts.removeRange(50, p.forumPosts.length);
    }
    notifyListeners();
    unawaited(autoSave());
    return id;
  }

  void removeForumPost(String id) {
    final p = player;
    if (p == null) return;
    final before = p.forumPosts.length;
    p.forumPosts.removeWhere((e) => e.id == id);
    if (p.forumPosts.length == before) return;
    notifyListeners();
    unawaited(autoSave());
  }

  /// 论坛帖子点赞切换。
  ///
  /// **仅计数的展示指标**（Batch 10 · Issue #23 豁免）：
  /// 点赞是玩家与帖子之间的二元关系（`post.liked` 已记录当前玩家是否点赞），
  /// 不引入独立实体（如 `LikeEntry`）。若未来需要展示"谁点了赞"或"点赞时间线"，
  /// 再升级为实体列表。当前 `likes` 字段仅用于 UI 数字展示。
  void toggleForumPostLike(String id) {
    final p = player;
    if (p == null) return;
    final post = p.forumPosts.where((e) => e.id == id).firstOrNull;
    if (post == null) return;
    post.liked = !post.liked;
    post.likes += post.liked ? 1 : -1;
    if (post.likes < 0) post.likes = 0;
    notifyListeners();
    unawaited(autoSave());
  }

  void addForumPostComment(String id, {required String text}) {
    final p = player;
    if (p == null) return;
    final post = p.forumPosts.where((e) => e.id == id).firstOrNull;
    if (post == null) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    // Batch 7 · Issue #11：回复落成实体，不再只 +1 计数
    post.commentList.add(
      ForumComment(
        id: 'fc_${DateTime.now().microsecondsSinceEpoch}',
        author: p.name,
        content: trimmed,
        timeLabel: worldState.timestamp,
      ),
    );
    // 同步计数（兼容旧 UI 展示）
    post.comments = post.commentList.length;
    notifyListeners();
    unawaited(autoSave());
  }

  // ==================== 时间快进（/快进） ====================

  /// 距本月最后一天还剩几天（返回 0 表示今天就是月末）。
  int _daysLeftInMonth(int year, int month, int day) {
    const dims = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    var dim = dims[(month - 1).clamp(0, 11)];
    if (month == 2 && ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0)) {
      dim = 29;
    }
    return (dim - day).clamp(0, dim);
  }

  /// 快进若干天。
  ///
  /// 动机：一回合平均只推进 60~90 分钟，七年制毕业需要约 6 万回合，
  /// 毕业结局、学院杯、高年级专属锚点实际上永远达不到。
  /// 快进让玩家能主动跳到"下一个假期/下一学年"，同时仍然逐步结算
  /// 月度演化与学年切换，不会把中间的过程整个吞掉。
  ///
  /// 返回本次快进产生的新通知列表（供 UI 汇总展示）。
  List<String> fastForwardDays(int days) {
    if (days <= 0) return const [];
    if (player == null) return const [];

    final startLabel = worldState.time.formatDate();
    final notifyFrom = notifications.length;

    var remaining = days;
    var guard = 0;
    while (remaining > 0 && guard++ < 200) {
      final t = worldState.time;
      // 每次最多走到次月 1 日：保证 checkMonthlyEvolution 每个月都能触发
      final step = min(remaining, _daysLeftInMonth(t.year, t.month, t.day) + 1);
      // 每一步都查锚点：只查末步会把跨过的整月锚点整个吞掉
      // （月份已经过去，错过即错过——但至少要触发"本月该发生的事"）。
      advanceWorldClock(0, days: step, fireAnchors: true);
      remaining -= step;
    }

    // 快进后清空停滞计数并同步追踪地点：玩家显然已经不在原来那个场景里了
    turnsAtSameLocation = 0;
    lastTrackedLocation = worldState.currentLocation;

    final endLabel = worldState.time.formatDate();
    worldState.addNarrativeEvent(
      '⏩ 时间快进 $days 天（$startLabel → $endLabel）',
      turn: turnCount,
    );

    if (notifications.length > notifyFrom) {
      return notifications.sublist(notifyFrom);
    }
    return const [];
  }

  /// 把「明天 / 下周 / 下月 / 下学期 / 假期 / 下学年 / N天」解析成天数。
  int resolveFastForwardDays(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return 7;
    final n = int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), ''));
    if (n != null && n > 0) return min(n, 365);

    final t = worldState.time;
    if (s.contains('明天')) return 1;
    if (s.contains('下周')) return 7;
    if (s.contains('两周')) return 14;
    if (s.contains('下月') || s.contains('下个月')) return 30;
    if (s.contains('圣诞') || s.contains('假期') || s.contains('放假')) {
      // 跳到下一个假期起点：12月(圣诞)或7月(暑假)
      return _daysUntilMonth(t.month == 12 ? 7 : 12);
    }
    if (s.contains('暑假')) return _daysUntilMonth(7);
    if (s.contains('学期') || s.contains('开学')) return _daysUntilMonth(9);
    if (s.contains('下学年') || s.contains('明年') || s.contains('下一年')) {
      return _daysUntilMonth(9);
    }
    return 7;
  }

  /// 从当前日期跳到下一个第 [targetMonth] 月 1 日，需要多少天。
  ///
  /// 已经身处目标月份时返回 0——玩家要的就是「快进到暑假」，
  /// 而 7 月里本来就在放暑假。
  /// 老实现从 `t.month + 1` 起算，`targetMonth == t.month` 时 while 循环
  /// 要绕满 12 个月才退出，于是 7 月里输「/快进 暑假」会一下跳掉约 351 天，
  /// 整整一年就这么没了。
  int _daysUntilMonth(int targetMonth) {
    final t = worldState.time;
    if (t.month == targetMonth) return 0;

    var days = _daysLeftInMonth(t.year, t.month, t.day) + 1; // 到次月1日
    var m = t.month + 1;
    var y = t.year;
    while (m != targetMonth) {
      const dims = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
      var dim = dims[(m - 1) % 12];
      if (m == 2 && ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0)) dim = 29;
      days += dim;
      m++;
      if (m > 12) {
        m = 1;
        y++;
      }
    }
    return max(1, days);
  }

  // ==================== 学年推进系统 ====================

  /// 计算当前学年起始年份（9月起为新学年）


  // ==================== 毕业结算系统 ====================

  /// 评估目标毕业条件，返回 (条件描述, 是否达成) 列表


  /// 毕业结算：评估人生目标、解锁成就、生成结算报告（追加到当前剧情后）


  /// /伤痕 的输出。
  ///
  /// 疤只在落下的那一瞬间弹过通知。没有这一屏的话，
  /// 玩家过两年就忘了自己身上有什么——而那些东西是永久的。
  @override
  String formatScars() {
    final p = player;
    if (p == null) return '尚未创建角色。';
    if (p.scars.isEmpty) {
      return '【伤痕】\n你身上还没有留下什么。\n'
          '不是每个人都做得到，好好珍惜。';
    }

    final penalties = scarPenaltiesOf(p.scars);
    final buf = StringBuffer()..writeln('【伤痕】永远不会好的那些');
    for (final s in p.scars) {
      final d = s.def;
      buf
        ..writeln()
        ..writeln('· ${d.label}　${s.since.isEmpty ? '' : '（${s.since}）'}')
        ..writeln('  ${d.aftermath}');
    }
    buf
      ..writeln()
      ..writeln('这些是永久的。它们也确实留下了点别的东西：');
    for (final e in penalties.entries) {
      final sign = e.value > 0 ? '+' : '';
      buf.writeln('  ${attrLabel(e.key)} $sign${e.value}');
    }
    return buf.toString().trimRight();
  }

  /// 读属性的唯一入口：基础值 + 永久修正（目前只有疤痕）。
  ///
  /// 数值夹在 0~100——属性本身永远在这个区间，
  /// 加了修正也不能跑出去，否则 UI 上会出现 103 这种数。
  @override
  int effectiveAttr(String key) {
    final p = player;
    if (p == null) return 50;
    final base = p.attributes[key] ?? 50;
    final delta = _currentScarPenalties[key] ?? 0;
    return (base + delta).clamp(0, 100);
  }

  /// 疤痕惩罚的缓存。按"身上有哪些疤"做键，内容变了才重算——
  /// 这个函数在决斗、学习、练习里被反复调用，每次都重算没必要。
  String _scarPenaltyKey = '';
  Map<String, int> _scarPenalties = const {};

  Map<String, int> get _currentScarPenalties {
    final p = player;
    if (p == null || p.scars.isEmpty) {
      _scarPenaltyKey = '';
      _scarPenalties = const {};
      return _scarPenalties;
    }
    final key = p.scars.map((s) => s.key).join('|');
    if (key != _scarPenaltyKey) {
      _scarPenaltyKey = key;
      _scarPenalties = scarPenaltiesOf(p.scars);
    }
    return _scarPenalties;
  }

  /// 把散在各处的状态收拢成一份"这七年"的事实。
  ///
  /// 这个方法只做收集，不做判断——所有取舍都在
  /// `ending_review_data` 的纯函数里，这样每条规则才能单独测。
  @override
  EndingFacts endingFactsOf(Player p) {
    final today = worldState.time.absoluteDayIndex;
    final rep = p.playerReputation;

    // 只有活着且真正打过照面的人才算"这七年里的人"——
    // npcRegistry 里有大批从未登场的名字，算进来会让「那些人」变成通讯录。
    final affections = <String, int>{};
    final rivals = <(String, String)>[];
    for (final n in npcRegistry.values) {
      if (!n.isAlive || !n.introduced) continue;
      affections[n.name] = n.affection;
      final tier = n.rivalryTier(today);
      if (tier.index >= RivalryTier.hostile.index) {
        rivals.add((n.name, tierDefFor(tier).label));
      }
    }
    // 仇深的那几个排在前面
    rivals.sort((a, b) => b.$2.compareTo(a.$2));

    return EndingFacts(
      playerName: p.name,
      house: houseDisplayName(p.house, fallback: '未分院'),
      bloodLabel: bloodStatusLabel(p.bloodType),
      keyFacts: memory.keyFacts,
      openLoops: memory.openLoops,
      worldEvents: memory.worldEvents,
      affections: affections,
      rivals: rivals,
      worldLineDeviation: p.worldLineDeviation,
      rewrittenEchoes: rewrittenEchoesOf(worldState.causalChoices),
      witnessedUnchanged: witnessedEchoesOf(worldState.causalChoices),
      deepBonds: affections.values.where((v) => v >= 50).length,
      wasFaculty: p.facultyRankId != null,
      scars: p.scars.map((sc) {
        final d = sc.def;
        return d.aftermath.isEmpty ? d.label : '${d.label}（${d.aftermath}）';
      }).toList(),
      moral: rep.moral,
      combat: rep.combat,
      academic: rep.academic,
      dark: rep.dark,
      leadership: rep.leadership,
    );
  }

  /// 目标进度查询（/目标 进度）

  @override
  String formatGoalProgress() {
    final p = player;
    if (p == null) return '尚未创建角色。';
    final goal = p.currentGoal != null ? goalByName(p.currentGoal!) : null;
    if (goal == null) {
      return '尚未设定人生目标。输入 /目标 查看并设定。';
    }
    final lines = evaluateGoalRequirement(goal.requirement);
    final met = lines.isNotEmpty && lines.every((e) => e.$2);
    final buf = StringBuffer()
      ..writeln('【目标进度】${goal.name}')
      ..writeln('『${goal.description}』')
      ..writeln();
    for (final (label, ok) in lines) {
      buf.writeln('${ok ? '✅' : '⬜'} $label');
    }
    buf.writeln();
    buf.writeln(
      met ? '🏆 所有毕业条件已达成！坚持到毕业即可在结算中获得「得偿所愿」。' : '继续朝着目标努力吧——毕业时将进行最终结算。',
    );
    return buf.toString();
  }

  // ==================== 事件锚点系统 ====================

  /// 按当前月份/年级/时代检查并触发手写事件锚点

  /// [hourFrom] / [dayDelta] 来自本次时钟推进前的时刻，用来判断时段窗口
  /// 是不是被"跨过去"了（详见 anchorsFor 的说明）。
  void checkEventAnchors({int? hourFrom, int dayDelta = 0}) {
    final p = player;
    if (p == null) return;
    if (worldState.graduated) return; // 毕业后不再触发校内锚点

    final t = worldState.time;
    final grade = p.grade ?? 1;
    // common 锚点（era==null）按学年触发：fired 记录带 '@年级' 后缀，
    // 这样开学宴/万圣节这类事件每年都能发生一次，而不是七年只响一次。
    // 老存档里的裸 id 仍然有效（兼容）。
    final rawFired = worldState.firedAnchorIds;
    final fired = <String>{...rawFired};
    for (final id in List.of(rawFired)) {
      final at = id.indexOf('@');
      if (at > 0 && id.substring(at + 1) == '$grade') {
        fired.add(id.substring(0, at));
      }
    }

    final due = anchorsFor(
      month: t.month,
      grade: grade,
      era: worldState.era,
      firedIds: fired,
      hour: t.hour,
      hourFrom: hourFrom,
      dayDelta: dayDelta,
      currentLocation: worldState.currentLocation,
    );

    // R9：事件锚点进度门（白名单数据化，替代原 id 硬编码特判）
    // 「暑假开始」锚点只在"真正上完了一学年之后"才触发：
    // - 学年是9月开学 → 次年6月结束 → 7月放暑假
    // - 所以1991年7月（入学前）不能触发，1992年7月及之后才可以
    if (due.isNotEmpty) {
      final acYearStart = RegExp(
        r'^(\d{4})',
      ).firstMatch(worldState.academicYear)?.group(1);
      final acYearStartInt = acYearStart != null
          ? int.tryParse(acYearStart)
          : null;
      // 用 removeWhere 而不是在 where(...) 的惰性迭代里边遍历边 remove：
      // due.where(...) 返回的是惰性 Iterable，迭代过程中结构性修改底层列表
      // 会直接抛 ConcurrentModificationError。现在只是恰好一条规则只匹配一个
      // 锚点才没炸，哪天同一条规则挂上第二个锚点（或同一个锚点被两条规则
      // 命中）就会在玩家推进剧情的瞬间崩掉。
      for (final rule in anchorGatedRules) {
        final matchedIds = due
            .where(
              (a) =>
                  a.id == rule.anchorId &&
                  !rule.predicate(t.year, t.month, acYearStartInt),
            )
            .map((a) => a.id)
            .toSet();
        if (matchedIds.isEmpty) continue;
        for (final a in due.where((a) => matchedIds.contains(a.id)).toList()) {
          debugLog(
            '📜 跳过「${a.title}」锚点：${rule.description} '
            '(academicYear=${worldState.academicYear}, year=${t.year})',
          );
        }
        due.removeWhere((a) => matchedIds.contains(a.id));
      }
    }

    if (due.isEmpty) return;

    // 每个回合最多注入一个锚点，避免信息过载；其余顺延
    final anchor = due.first;
    // common 锚点（era==null）按学年记录，时代锚点全局记录
    final anchorKey = anchor.era == null ? '${anchor.id}@$grade' : anchor.id;
    worldState.firedAnchorIds.add(anchorKey);
    pendingAnchorDirective = anchor.directive;
    notifications.add('📜 ${anchor.title}');
    worldState.addNarrativeEvent('📜 ${anchor.title}', turn: turnCount);
    debugLog('📜 事件锚点触发: ${anchor.id} (${anchor.title})');

    // 因果锚点：如果这个节点是原著里写死的大事，而玩家的世界线已经偏得够远，
    // 就把「干预 / 旁观」的抉择挂上去。
    //
    // 没解锁时不给任何提示——这一栏本来就是「你改变了多少世界」的兑现，
    // 提前告诉玩家"有个东西你够不着"只会变成倒计时 UI。
    final causal = causalAnchorFor(anchor.id);
    if (causal != null) {
      final dev = p.worldLineDeviation;
      final unlocked = isCausalAnchorUnlocked(
        causal,
        era: worldState.era,
        deviation: dev,
        decidedAnchorIds: worldState.causalChoices.keys.toSet(),
      );
      if (unlocked) {
        pendingCausalAnchorId = causal.anchorId;
        notifications.add('⏳ ${causal.title}');
      } else {
        final gap = deviationGapToUnlock(causal, dev);
        debugLog(
          '⏳ 因果锚点 ${causal.anchorId} 未解锁：'
          '还差 ${(gap * 100).toStringAsFixed(1)}% 变动率'
          '（当前 ${(dev * 100).toStringAsFixed(1)}%）',
        );
      }
    }
  }
  // ==================== 毕业后留校任教 ====================

  /// 当前是否有一份留校邀请等着答复。
  ///
  /// 只在「刚毕业 + 够格 + 还没答复过」时为真。挂上之后不会自己消失——
  /// 那封信在你做出答复之前一直压在箱子底下。


  @override

  // ==================== NPC 状态更新 ====================

  @override
  void updateNPCsFromAction(String action) {
    // 消耗资源 - 大幅降低消耗，让玩家有更多精力进行活动
    final p = player!;
    p.energy = max(0, p.energy - 2); // 从5降到2
    p.satiety = max(0, p.satiety - 2); // 从3降到2
    p.spirit = max(0, p.spirit - 1); // 从2降到1

    // 扩展恢复关键词，让更多行动可以恢复精力
    if (action.contains('吃饭') ||
        action.contains('用餐') ||
        action.contains('进食') ||
        action.contains('吃东西')) {
      p.satiety = min(100, p.satiety + 30);
      p.energy = min(100, p.energy + 5); // 吃饭也恢复少量精力
    }
    // S4：睡眠语义与时间表（time_cost_rules）对齐。原表 9 个词里
    // 「放松」「回房」不是睡眠动作，却在 30 分钟档（时间表不认它们）
    // 给满额 +50 精力——「放松一下」「回房拿东西」都能无限刷。
    // 现在满额组只保留真正的睡眠/休息语义（与时间表 120 分钟档一致），
    // 「放松」降为小恢复（散步级）。「回房」单独出现不恢复。
    if (action.contains('睡觉') ||
        action.contains('休息') ||
        action.contains('睡') ||
        action.contains('歇') ||
        action.contains('躺') ||
        action.contains('疗养') ||
        action.contains('休养') ||
        action.contains('养神') ||
        action.contains('小憩') ||
        action.contains('打盹') ||
        action.contains('躺下') ||
        action.contains('回房睡') ||
        action.contains('歇一会') ||
        action.contains('闭目养神') ||
        action.contains('回宿舍') ||
        action.contains('就寝') ||
        action.contains('睡大觉')) {
      p.energy = min(100, p.energy + 50); // 从40提升到50
      p.spirit = min(100, p.spirit + 30); // 从20提升到30
      p.satiety = min(100, p.satiety + 5);
    }
    if (action.contains('冥想') ||
        action.contains('打坐') ||
        action.contains('修炼') ||
        action.contains('学习')) {
      p.spirit = min(100, p.spirit + 15);
      p.energy = min(100, p.energy + 5);
    }
    if (action.contains('散步') ||
        action.contains('走') ||
        action.contains('逛') ||
        action.contains('活动')) {
      p.energy = min(100, p.energy + 3);
    }

    // 每日随机触发好感微调。
    // 改走 updateNpcAffection：直接改字段会绕过每周好感上限、记恨上限、
    // recentEvents 与长线记忆管线，等于给所有已认识的人开了个无上限的口子。
    // quiet=true：循环内不通知、不写档，整批跑完才统一一次。
    // 以前每命中一个 NPC 就 notifyListeners + autoSave（全量 rebuild +
    // 整档序列化），一回合 ~5 次，长局下来是最显眼的一处无谓开销。
    var dailyAffectionTouched = false;
    for (final npc in npcRegistry.values.toList()) {
      if (npc.affection > 0 && random.nextDouble() < 0.05) {
        updateNpcAffection(npc.id, 1, reason: '日常相处', quiet: true);
        dailyAffectionTouched = true;
      }
    }
    if (dailyAffectionTouched) {
      notifyListeners();
      unawaited(autoSave());
    }

    // 检测表白时机（恋爱剧情推进时）
    if (p.loveState.status == '恋爱' && random.nextDouble() < 0.1) {
      _spawnRomanticEvent();
    }

    // 恋爱链路接线：浪漫行动（约会/散步/独处等）为暧昧对象/恋人记录一次浪漫事件
    if (_reRomanticAction.hasMatch(action)) {
      final love = p.loveState;
      if (love.status == '恋爱' && love.partnerId != null) {
        final partner = npcRegistry[love.partnerId];
        if (partner != null) recordRomanticEventFor(partner);
      } else if (love.currentCrushName != null) {
        for (final n in npcRegistry.values) {
          if (n.name == love.currentCrushName) {
            recordRomanticEventFor(n);
            break;
          }
        }
      }
    }
  }

  void _spawnRomanticEvent() {
    final p = player;
    final partner = p?.loveState.partnerId;
    if (partner == null) return;
    final npc = npcRegistry[partner];
    if (npc == null) return;

    recordRomanticEventFor(npc);
    notifications.add('💕 与${npc.name}之间发生了一段浪漫插曲。');
    worldState.addNarrativeEvent(
      '💕 与${npc.name}之间发生了一段浪漫插曲。',
      turn: turnCount,
    );
  }

  // ==================== 快速推进 ====================
  // ==================== 查看人物 ====================

  /// `/查看 [名字]` 的输出。
  ///
  /// 原先这里只有一个 `getViewableCharacter`，返回 Map 给 UI 用——但没有任何
  /// UI 消费它，于是整套「可见性判定 + 档案组装」实际上死了。改成直接产出
  /// 玩家能读的文本，并新增 `/查看` 命令作为入口。
  @override
  String formatCharacterDossier(String idOrName) {
    final kw = idOrName.trim();
    final npc = npcRegistry[kw] ?? findNpcByKeyword(npcRegistry.values, kw);

    if (kw.isEmpty) {
      return '【查看】\n用法：/查看 [名字]，例如 /查看 斯内普\n\n$_visibleRoster';
    }
    if (npc == null) {
      return '【查看】\n你没听说过「$kw」这个人。\n\n$_visibleRoster';
    }
    if (!_isNPCVisible(npc)) {
      return '【查看 · ${npc.name}】\n你与${npc.name}素不相识，无从打量。'
          '\n先在同一间教室、同一张餐桌上碰过面，才会有东西可看。\n\n$_visibleRoster';
    }

    final buf = StringBuffer('【查看 · ${npc.name}】\n');
    final house = npc.house.isEmpty ? '未知学院' : npc.house;
    final gender = npc.gender.isEmpty ? '' : '｜${npc.gender}';
    buf.writeln(
      '$house｜${npc.grade}年级$gender｜${npcBloodStatusLabel(npc.bloodStatus)}',
    );
    buf.writeln(
      '所在：${npc.currentLocation}｜${_moodLabel(npc.mood)}'
      '${npc.isAlive ? '' : '｜已故'}',
    );

    final rel = player?.relationships[npc.id];
    // 信息分级（框架2 §6/§125：只能展示角色合理知道的信息）：
    //   · 浅关系（未正式结识/点头之交）→ 只有外表与位置；
    //   · 中等关系 → 好感档位（不露精确值）、日程；
    //   · 深关系（Level≥50 或明确朋友）→ 好感数值/心上事/知道/声望。
    final deep =
        rel != null &&
        (rel.level >= 50 ||
            rel.relationType == '朋友' ||
            rel.relationType == '可靠伙伴' ||
            rel.relationType == '挚友');
    final mid = rel != null && rel.level >= 25;
    if (rel != null) {
      buf.writeln('关系：${rel.relationType}（Lv.${rel.level}）');
    } else {
      buf.writeln('（同院同学，尚未正式结识。）');
    }
    if (deep) {
      buf.writeln('好感 ${npc.affection}（${npc.affectionStage}）');
    } else if (mid) {
      buf.writeln('TA对你的态度：${npc.affectionStage}');
    }

    // 原著角色的魔杖（canonWandFor 此前零调用，这里接上）
    if (npc.isCanon) {
      final wand = canonWandFor(npc.name);
      if (wand != null) buf.writeln('魔杖：$wand');
    }

    if (npc.personality.isNotEmpty) {
      buf.writeln('性格：${npc.personality.join('、')}');
    }
    if (npc.appearance.isNotEmpty) {
      buf.writeln('外貌：${npc.appearance}');
    }
    // 以下为「深交才知道」的私密信息（框架2 §6 信息限制）：
    if (deep && npc.personalGoal != null && npc.personalGoal!.isNotEmpty) {
      buf.writeln('心上事：${npc.personalGoal}');
    }
    if (deep && npc.knowsAbout.isNotEmpty) {
      buf.writeln('知道：${npc.knowsAbout.take(3).join('、')}');
    }
    if (mid && npc.schedule.isNotEmpty) {
      final slots = npc.schedule.entries
          .take(3)
          .map((e) => '${e.key} ${e.value}')
          .join('；');
      buf.writeln('日程：$slots');
    }

    final rep = npc.reputation;
    final repFilled = <String>[
      if (rep.academic != 0) '学术 ${rep.academic}',
      if (rep.social != 0) '社交 ${rep.social}',
      if (rep.combat != 0) '战斗 ${rep.combat}',
      if (rep.moral != 0) '道德 ${rep.moral}',
      if (rep.leadership != 0) '领导 ${rep.leadership}',
      if (rep.dark != 0) '黑魔法 ${rep.dark}',
    ];
    if (deep && repFilled.isNotEmpty) {
      buf.writeln('声望：${repFilled.join('｜')}');
    }

    if (npc.hasGrudge) {
      final day = worldState.time.absoluteDayIndex;
      final tier = npc.rivalryTier(day);
      final reason = npc.rivalryReason();
      buf.writeln(
        '${rivalryBadgeFor(tier)} 记恨着你：$reason'
        '（${tierDefFor(tier).label}｜宿敌分 ${npc.rivalryScore(day)}'
        '｜好感上限 ${npc.effectiveAffectionCap}）',
      );
      // 第几次结仇要写出来：结过三次梁子的人和只结过一次的，
      // 在 AI 手里不该是同一种态度。
      if (npc.grudges.length > 1) {
        buf.writeln('   这已经是第 ${npc.grudges.length} 笔旧账了。');
      }
    }
    if (npc.formerRival) {
      buf.writeln('🤝 曾经是你最难缠的对头，如今已经和解。');
    }
    if (npc.isConsideringConfession) {
      buf.writeln('💭 似乎在酝酿着什么话……');
    }
    // P2#14：新 NPC 的「背景故事」段落（来自 generatedProfile，老档 null 跳过）。
    // 日程/目标已在上面按字段展示，这里只补背景故事，避免整段档案重复。
    if (npc.isGenerated &&
        npc.generatedProfile != null &&
        npc.generatedProfile!.isNotEmpty) {
      final bgMatch = RegExp(
        r'【背景故事】(.*?)(?=【日常日程】|【人生目标】|$)',
      ).firstMatch(npc.generatedProfile!);
      if (bgMatch != null && bgMatch.group(1)!.trim().isNotEmpty) {
        buf.writeln('背景：${bgMatch.group(1)!.trim()}');
      }
    }
    return buf.toString();
  }

  /// 当前能查看的人（`/查看` 不带参数时的名册）。
  String get _visibleRoster {
    final visible = npcRegistry.values.where(_isNPCVisible).toList()
      ..sort((a, b) => b.affection.compareTo(a.affection));
    if (visible.isEmpty) {
      return '你现在还叫得出名字的人一个也没有——先去上课或者到公共休息室坐坐。';
    }
    final buf = StringBuffer('可查看的人（按好感排序）：\n');
    for (final n in visible.take(12)) {
      buf.writeln(
        '· ${n.name}（${n.affectionStage} ${n.affection}）'
        '${n.isAlive ? '' : ' · 已故'}',
      );
    }
    if (visible.length > 12) buf.writeln('…另有 ${visible.length - 12} 人');
    return buf.toString();
  }

  String _moodLabel(int mood) => switch (mood) {
    >= 80 => '心情极好',
    >= 60 => '心情不错',
    >= 40 => '心情平静',
    >= 20 => '心情低落',
    _ => '心情糟糕',
  };

  bool _isNPCVisible(NPC npc) {
    if (player == null) return false;
    if (player!.relationships.containsKey(npc.id)) return true;
    if (npc.house == player!.house) return true;
    if (npc.isCanon && worldState.playerImpactScore > 0.5) return true;
    return false;
  }

  @override
  bool isNearby(String npcId) {
    final npc = npcRegistry[npcId];
    if (npc == null || player == null) return false;
    // 统一走 isSameLocation：以前裸写 `==`，两边都不归一，
    // 「霍格沃茨·场地」和「魁地奇球场」明明是一个地方却永远算不上 nearby。
    return isSameLocation(npc.currentLocation, worldState.currentLocation);
  }

  /// 地图「前往此地」：统一走规范名归一化 + 时间门/年级门（与叙事同步同款校验）。
  ///
  /// 以前直接写 currentLocation，两个问题：
  ///   ① 地图传的是显示名（'大礼堂'、'天文塔'、'图书馆（含禁书区）'），不是
  ///      kKnownLocations 的规范主名（'霍格沃茨大礼堂'、'霍格沃茨·天文塔'），
  ///      下游凡是 loc.contains('霍格沃茨') 的判定（如学院杯日常加分）全部失效；
  ///   ② 7/31 打开地图照样能点进霍格沃茨 / 国王十字，绕过了开学前时间门。
  @override
  void travelTo(String location) {
    final cur = worldState.currentLocation ?? '';
    // 显示名 → 规范主名（认不出就保留原样，不把现有行为改坏）。
    final normalized = resolveLocationName(location) ?? location;
    final dateInt = worldState.time.month * 100 + worldState.time.day;

    if (blockedBySeasonGate(
      detected: normalized,
      current: cur,
      dateInt: dateInt,
    )) {
      worldState.addNarrativeEvent(
        '⏱ 地图旅行被时间门拦截：$location（需 9月1日，'
        '当前 ${worldState.time.month}月${worldState.time.day}日）',
        turn: turnCount,
      );
      notifyListeners();
      return;
    }
    // 区域门禁：与叙事同步路径共用同一判定（evaluateRegionGate）。
    // 地图是玩家**主动**点击的入口，更需要严格——玩家点了禁林/霍格莫德却进不去，
    // 必须有明确提示，而不是静默失败。这里不给教授带队豁免：带队是剧情事件，
    // 不是玩家在地图上能自助触发的。
    final gate = evaluateRegionGate(
      detected: normalized,
      grade: player?.grade,
      isWeekend: isWeekendWeekday(worldState.time.weekday),
    );
    if (gate.isBlocked) {
      final reasonText = switch (gate.reason!) {
        RegionGateReason.grade =>
          '需${gate.blocked!.minGrade}年级，当前${player?.grade ?? 1}年级',
        RegionGateReason.weekend => '仅周末开放',
      };
      worldState.addNarrativeEvent(
        '⏱ 地图旅行被区域门拦截：$location（${gate.blocked!.name}$reasonText）',
        turn: turnCount,
      );
      notifyListeners();
      return;
    }

    if (normalized != cur) {
      worldState.currentLocation = normalized;
      lastTrackedLocation = normalized;
      turnsAtSameLocation = 0;
    }
    // 室友系统：进入宿舍（首次，player.dormId 为空）时惰性补室友。
    if (normalized.contains('宿舍') || normalized == kDormLocation) {
      ensureRoommateNpcs();
    }
    notifyListeners();
  }

  /// 根据玩家行动累计影响力分数
  /// 每回合 +0.01，涉及原著NPC互动 +0.02，涉及关键剧情(恋爱/CG/成就) +0.05

  @override
  void updatePlayerImpactScore(String action) {
    double delta = 0.003; // 每回合基础增长：只要玩家做出选择，世界就有极小变动

    // 1. 与原著 NPC 互动：每次提到名字或与其对话，都代表蝴蝶翅膀拍动
    if (npcRegistry.isNotEmpty) {
      for (final npc in npcRegistry.values) {
        if (npc.isCanon && action.contains(npc.name)) {
          delta += 0.015;
          break;
        }
      }
    }

    // 2. 关键剧情关键词（越大的历史事件关键词加分越多）
    const weightedKeywords = <String, double>{
      '魂器': 0.05,
      '黑魔法': 0.03,
      '伏地魔': 0.06,
      '表白': 0.02,
      '恋爱': 0.015,
      '告白': 0.02,
      '战斗': 0.03,
      '决斗': 0.035,
      '冒险': 0.02,
      '秘密': 0.02,
      '发现': 0.015,
      '预言': 0.03,
      '死亡': 0.05,
      '杀死': 0.06,
      '拯救': 0.04,
      '入学': 0.02,
      'OWL': 0.025,
      'NEWT': 0.025,
      '毕业': 0.04,
      '魁地奇': 0.015,
      '学院杯': 0.02,
      '三强争霸': 0.04,
      '部长': 0.03,
      '魔法部': 0.02,
      '校长': 0.025,
    };
    for (final e in weightedKeywords.entries) {
      if (action.contains(e.key)) {
        delta += e.value;
        break; // 单关键词命中即加分，避免累计爆炸
      }
    }

    // 3. 世界线偏移量辅助：世界线已偏离越多，影响力增速越快（正反馈）
    if (player != null && player!.worldLineDeviation > 0.05) {
      delta *= 1 + player!.worldLineDeviation.clamp(0.0, 0.5);
    }

    worldState.playerImpactScore = (worldState.playerImpactScore + delta).clamp(
      0.0,
      1.0,
    );
  }

  /// 便捷入口：在非 action 场景（告白成功、CG解锁、事件锚点达成、月度事件、
  /// 新 NPC 生成、毕业结算等）直接给 playerImpactScore 加一次分，
  /// 避免这些"真正改变世界"的场景因为不从 updatePlayerImpactScore(action) 走而被忽略。

  @override
  void bumpImpactScore(double delta, {String? debugReason}) {
    if (worldState.playerImpactScore >= 1.0) return;
    worldState.playerImpactScore = (worldState.playerImpactScore + delta).clamp(
      0.0,
      1.0,
    );
    if (debugReason != null) {
      debugLog(
        '🌐 影响力+${delta.toStringAsFixed(3)} → ${worldState.playerImpactScore.toStringAsFixed(3)}（$debugReason）',
      );
    }
  }

  // ==================== 好感度操作（供UI调用） ====================

  @override
  void checkLocks(NPC npc) {
    if (npc.affection >= Balance.trustLockThreshold && !npc.hasLock('信任锁')) {
      npc.affectionLocks.add('信任锁');
    }
    if (npc.affection >= Balance.romanceLockThreshold && !npc.hasLock('情感锁')) {
      npc.affectionLocks.add('情感锁');
    }
  }

  @override
  Future<ChatResult> callDeepSeek(
    String prompt, {
    AiScene scene = AiScene.narrative,
    bool stream = false,
  }) async {
    if (router == null) throw Exception('AI 服务未初始化');
    // BUG-FIX: 检查与使用之间存在 await 间隙（buildSystemPrompt），
    // 若玩家在请求在飞时重置游戏（resetAllState 会把 router 置空），
    // router! 会抛 Null check operator used on a null value。
    final r = router;
    if (r == null) throw Exception('AI 服务已重置，请重试');
    String effectiveSystemPrompt;
    if (scene == AiScene.choice || scene == AiScene.summary) {
      // 选项/摘要场景：无需注入完整世界观 + 玩家档案，提示词本身已经包含了指令
      effectiveSystemPrompt = scene == AiScene.summary
          ? '你是严谨的剧情摘要员，忠实保留关键信息，不新增设定。'
          : '你是专业的游戏选项设计师，只输出符合要求的4个选项。';
    } else {
      // 每次 narrative/npcChat 调用前刷新系统提示词，确保玩家动态状态实时注入
      if (player != null) {
        final p = player!;
        // 构建玩家状态简单哈希，检测是否需要重建 systemPrompt
        final currentHash = '${p.name}_${p.house}_${p.grade}_${p.spirit}_${p.energy}';
        if (currentHash != _lastPlayerStateHash || _lastSystemPrompt == null) {
          // 哈希变化或缓存为空，需要重建
          systemPrompt = buildSystemPrompt();
          _lastSystemPrompt = systemPrompt;
          _lastPlayerStateHash = currentHash;
        } else {
          // 哈希未变化，复用缓存
          systemPrompt = _lastSystemPrompt;
        }
      }
      effectiveSystemPrompt = systemPrompt ?? '';
    }
    // 2026-08-24：maxTokens 按场景精细化分配
    //   narrative 主剧情：2000（600-800 字精练正文 ≈ 1100~1600 token，再叠加
    //                      【好感度变化】【声望变化】两个区块，1600 偏紧会截断
    //                      触发 BUG-H 重试 → 越截断越重试、越重试越打 AI，放大 429。
    //                      提到 2000 给区块留足余量，减少「截断→重试」的负反馈）
    //   choice 选项：500（只输出 4 行 ABCD ≈ 300 tokens，留余量给思考型模型的推理过程）
    //   summary 摘要：3000（输出 800-2400 字摘要 + 结构化记忆块）
    //   npcChat NPC聊天：500（对话场景不需要太长）
    int maxTokens = switch (scene) {
      AiScene.narrative => 2000,
      AiScene.choice => 500,
      AiScene.summary => 3000,
      AiScene.npcChat => 500,
    };
    // Token 自适应机制：游戏进入后期时自动降低 maxTokens 以节省 token。
    // P#2：旧实现按 totalTokens（含输入、随局龄只增不减）判定，输入 token 随
    // 累积事实/摘要缓冲膨胀，前 ~20 回合就会误触「后期」降额；改为按回合数
    // 判定真实进度，并豁免 summary（摘要是结构化长期记忆的唯一生产者，
    // 降额截断会丢【了结】/【世界事件】记忆块）。
    //
    // 注意：narrative 也不降额——600-800 字是 T0 铁律写死的硬要求，后期把
    // 1600 砍到 960 会让正文写不满被 parseNarrativeOnly 判成「返回选项」
    // 触发重试，省下的 token 反而变成多打的几次请求（429 的正反馈）。
    if (scene != AiScene.summary && scene != AiScene.narrative) {
      if (turnCount > 150) {
        maxTokens = (maxTokens * 0.6).floor(); // 后期：降低 40%
      } else if (turnCount > 80) {
        maxTokens = (maxTokens * 0.8).floor(); // 中期：降低 20%
      }
    }
    final result = await r.chatComplete(
      scene: scene,
      prompt: prompt,
      systemPrompt: effectiveSystemPrompt,
      temperature: 0.85,
      maxTokens: maxTokens,
      // S1：只有叙事路径开流式（选项/摘要/闲聊输出短，提前看到半句没有价值，
      // 却要多付一次 SSE 解析与逐帧 notify 的成本）。
      onDelta: stream ? handleNarrativeDelta : null,
    );
    // Q9：模型连续空响应触发降级（成功走了备用提供商）时，把「已切换备用
    // 模型 + 建议换稳定模型」的提示追加到通知栏，只提示一次。失败路径由
    // AiEmptyResponseException 自身的文案兜底，这里不必重复。
    final degradeNotice = r.lastDegradeNotice;
    if (degradeNotice != null && degradeNotice.isNotEmpty) {
      notifications.add('⚠️ $degradeNotice');
      r.clearDegradeNotice();
    }
    // 使用 try-catch 保护 token 统计，避免因 API 返回格式异常导致崩溃
    try {
      totalPromptTokens += result.usage.promptTokens;
      totalCompletionTokens += result.usage.completionTokens;
      totalTokens += result.usage.totalTokens;
      lastRoundTokens = result.usage.totalTokens;
      apiCalls++;
      notifyListeners();
    } catch (e) {
      debugLog('[GameProvider] Token 统计异常(不影响游戏): $e');
    }
    return result;
  }

  // ==================== 解析响应 ====================

  /// 从叙事文本中智能提取分院结果并赋值给 player.house
  /// 带语境判断：只有当文本中出现明确分院动作时才匹配。

  // ==================== 辅助方法 ====================

  /// 血统 key → 中文名。表本身在 lib/data/blood_status.dart（问卷 UI 共用）。
  @override
  String bloodStatusLabel(String status) => bloodStatusLabelOf(status);

  /// 属性 key → 中文名。表本身在 lib/data/attribute_data.dart
  /// （mixin_play 那边的物品加成/宠物训练文案共用同一份）。
  @override
  String attrLabel(String key) => attributeLabel(key);

  @override
  String termLabel(String term) {
    return {
          'first': '第一学期',
          'second': '第二学期',
          'third': '第三学期',
          'summer': '暑假',
        }[term] ??
        term;
  }

  @override
  String flowModeLabel(String mode) {
    return {'normal': '正常', 'story': '剧情加速', 'fast': '快速'}[mode] ?? mode;
  }

  @override
  void dispose() {
    // 注意：这里发起的 saveNow() 是异步写盘，进程回收时 Future 可能跑不完，
    // 真正的防丢档靠 GameProvider 的 WidgetsBindingObserver（退后台时提前存档）。
    // 这里保留 saveNow() 作为最后兜底（至少同步快照了状态）。
    saveNow();
    appProvider.removeListener(onApiKeyChange);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  void resetWeeklyAffectionCaps([int weeksCrossed = 1]) {
    for (final npc in npcRegistry.values) {
      npc.affectionGainedThisWeek = 0;
    }
    debugLog('📊 新的一周开始：好感周增量已重置');
    _applyAffectionDrift(weeksCrossed);
  }
  void checkMonthlyEvolution(int oldMonth, int oldYear) {
    final newMonth = worldState.time.month;
    final newYear = worldState.time.year;
    if (newMonth != oldMonth || newYear != oldYear) {
      _generateMonthlyEvent(newMonth, newYear);
    }
  }
  void _applyAffectionDrift(int weeksCrossed) {
    if (weeksCrossed <= 0) return;
    final p = player;
    final today = worldState.time.absoluteDayIndex;
    final decayWeeksCap = weeksCrossed.clamp(1, 4);
    final drifted = <String>[];

    for (final npc in npcRegistry.values) {
      if (!npc.isAlive || !npc.introduced) continue;
      if (npc.affection <= Balance.affectionDriftFloor) continue;
      if (npc.hasLock('信任锁')) continue;
      if (p != null && p.loveState.partnerId == npc.id) continue;
      // -1 = 老存档/从未互动：按刚刚互动过处理，豁免（见 NPC 字段注释）
      if (npc.lastAffectionTouchDay < 0) continue;

      final idleDays = today - npc.lastAffectionTouchDay;
      if (idleDays < Balance.affectionDriftIdleDays) continue;

      // idle 超过宽限期后，每多一周淡一次；本次跨了几周就最多补几周
      final overdueWeeks = (idleDays - Balance.affectionDriftIdleDays) ~/ 7 + 1;
      final weeks = overdueWeeks < decayWeeksCap ? overdueWeeks : decayWeeksCap;

      var total = 0;
      for (var i = 0; i < weeks; i++) {
        total +=
            Balance.affectionDriftPerWeekMin +
            random.nextInt(
              Balance.affectionDriftPerWeekMax -
                  Balance.affectionDriftPerWeekMin +
                  1,
            );
      }
      final before = npc.affection;
      npc.affection = (npc.affection - total).clamp(
        Balance.affectionDriftFloor,
        100,
      );
      if (npc.affection != before) {
        syncRelationshipLevel(npc);
        drifted.add(npc.name);
        // P1-10 观测日志：衰减体感/好感通胀速度留待真实数据调参，
        // 记录每次衰减的 NPC/天数/幅度，供后续根据实际档位校准
        // affectionDriftPerWeekMin/Max。
        if (kDebugMode) {
          debugLog(
            '[好感衰减] ${npc.name}: $before → ${npc.affection}'
            '（闲置 $idleDays 天，结算 $weeks 周，合计 -$total）',
          );
        }
      }
    }

    if (drifted.isNotEmpty) {
      // 聚合播报：一次跨多周时逐个刷通知是惩罚玩家，一句话说清即可
      final shown = drifted.take(3).join('、');
      final more = drifted.length > 3 ? ' 等 ${drifted.length} 人' : '';
      final text = '💨 有些日子没和 $shown$more 联系了，彼此似乎都生分了一点';
      notifications.add(text);
      worldState.addNarrativeEvent(text, turn: turnCount);
    }

    // 传闻时间衰减：超过 30 天的旧闻自动淡出（舆论不是永久档案）
    _decayRumors();
  }
  void _decayRumors() {
    final p = player;
    if (p == null || p.rumors.isEmpty) return;
    final today = worldState.time.absoluteDayIndex;
    final before = p.rumors.length;
    p.rumors.removeWhere((r) {
      final d = p.rumorDates[r];
      if (d == null) return false; // 老存档无日期：保留
      return today - d > 30;
    });
    if (p.rumors.length != before) {
      p.rumorDates.removeWhere((k, _) => !p.rumors.contains(k));
      debugLog('📰 传闻衰减：${before - p.rumors.length} 条旧闻淡出');
    }
  }
  void _generateMonthlyEvent(int month, int year) {
    // R6：月度事件池数据化（带权重、季节筛选、基础概率）
    final seasonTags = seasonTagsForMonth(month);
    // 月份序号，用来算"这条多久之前播过"
    final monthIndex = year * 12 + month;

    // 1) 季节匹配 + 基础概率过滤 + 去重/互斥过滤
    //
    // 以前这里每次跨月都从整池重抽：上个月刚播过「魔法部宣布新一轮教育
    // 改革」，这个月原样再来一遍，玩家一眼就能看出世界是假的。
    // 现在按两项规则剔除：
    //   a) 同一条事件 [MonthlyEventDef.repeatCooldownMonths] 个月内不重复；
    //   b) mutuallyExclusiveIds 里写的事件，在 [kMutuallyExclusiveMonths]
    //      个月内被抽中过的话，本条本次不参与。
    final candidates = <MonthlyEventDef>[];
    final rand = random;
    for (final e in monthlyEventPool) {
      final seasonMatch =
          e.seasonTags.isEmpty ||
          e.seasonTags.any((s) => seasonTags.contains(s));
      if (!seasonMatch) continue;
      if (e.baseChance < 1.0 && rand.nextDouble() > e.baseChance) continue;
      if (_monthlyEventOnCooldown(e, monthIndex)) continue;
      candidates.add(e);
    }
    // 全被冷却挡掉了（长局后期常见）：放宽到只保留互斥，忽略重复冷却，
    // 保证每个月总有一条世界新闻，而不是静悄悄地什么都不发生。
    if (candidates.isEmpty) {
      for (final e in monthlyEventPool) {
        final seasonMatch =
            e.seasonTags.isEmpty ||
            e.seasonTags.any((s) => seasonTags.contains(s));
        if (!seasonMatch) continue;
        if (_monthlyEventBlockedByExclusive(e, monthIndex)) continue;
        candidates.add(e);
      }
    }
    if (candidates.isEmpty) return;

    // 2) 权重抽取
    int totalWeight = 0;
    for (final e in candidates) {
      totalWeight += e.weight > 0 ? e.weight : 1;
    }
    int pick = rand.nextInt(totalWeight);
    MonthlyEventDef? selected;
    for (final e in candidates) {
      final w = e.weight > 0 ? e.weight : 1;
      if (pick < w) {
        selected = e;
        break;
      }
      pick -= w;
    }
    selected ??= candidates.last;

    // 3) 记账：下次抽取时靠这条记录做去重与互斥判定
    worldState.monthlyEventFiredAt[selected.id] = monthIndex;

    final event = '【$year年$month月·月度世界演化】${selected.text}';

    worldState.recentEvents.insert(0, NarrativeEvent(event, turn: turnCount));
    if (worldState.recentEvents.length > 50) {
      worldState.recentEvents.removeLast();
    }

    notifications.add('🌍 $event');
    worldState.addNarrativeEvent('🌍 $event', turn: turnCount);
  }

  @override
  void fastForwardTime(int days) {
    // P0-3 收敛：统一委托 fastForwardDays（内部走 advanceWorldClock 全量结算：
    // 游戏周/学院杯/NPC位置/学年推进/事件锚点/孕期/月度演化/传闻）。
    // 旧的独立实现按天循环，漏了 NPC 位置刷新、孕期推进、学院杯对手分、
    // 传闻生成，且 checkEventAnchors() 用默认 hourFrom/dayDelta 匹配，
    // 快进跨过的事件窗口会整体错位——两套实现因此不等价。
    // 注意：fastForwardDays 对超大天数有 guard 上限（200 步内每月推进），
    // 因此这里的超大值（如 /cheat 时间 999999）不会冻结主线程。
    fastForwardDays(days);
  }

  bool _monthlyEventOnCooldown(MonthlyEventDef e, int monthIndex) {
    final lastAt = worldState.monthlyEventFiredAt[e.id];
    if (lastAt != null &&
        monthIndex - lastAt < MonthlyEventDef.repeatCooldownMonths) {
      return true;
    }
    return _monthlyEventBlockedByExclusive(e, monthIndex);
  }

  bool _monthlyEventBlockedByExclusive(MonthlyEventDef e, int monthIndex) {
    for (final otherId in e.mutuallyExclusiveIds) {
      final lastAt = worldState.monthlyEventFiredAt[otherId];
      if (lastAt == null) continue;
      if (monthIndex - lastAt < kMutuallyExclusiveMonths) return true;
    }
    return false;
  }

}
