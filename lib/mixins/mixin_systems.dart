import 'dart:async';
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
import '../services/save_service.dart';
import '../models/player.dart';
import '../models/long_term_memory.dart';
import '../data/balance_constants.dart';
import '../data/goal_data.dart';
import '../data/parallel_data.dart';
import '../data/npc_schedule_rules.dart';
import '../data/rivalry_data.dart';
import '../data/exam_data.dart';
import '../data/wand_data.dart';
import '../data/faculty_data.dart';
import '../data/legacy_data.dart';
import '../data/worldline_data.dart';
import '../services/ai_router.dart';
import '../models/world_state.dart';
import '../utils/npc_lookup.dart';
import '../providers/game_provider_base.dart';

mixin GameSystemsMixin on GameProviderBase {
  /// 推进世界时钟，并统一执行所有周期性检查
  /// （游戏周、满月、学年切换、事件锚点、一致性、月度演化）。
  ///
  /// [days] 不为 null 时按整天快进（/快进 指令），否则按分钟推进。
  /// [fireAnchors] 为 false 时跳过事件锚点检测——长距离跳跃只在终点触发一次，
  /// 否则一次跳跃会灌入十几个剧情节点通知。
  void _advanceWorldClock(
    int minutes, {
    int? days,
    bool fireAnchors = true,
  }) {
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
    final newBucket = worldState.time.absoluteDayIndex ~/ 7;
    if (newBucket > lastWeekBucket) {
      // 补齐跨过的所有整周（快进时一次可能跨很多周）
      final weeksCrossed = newBucket - lastWeekBucket;
      gameWeek += weeksCrossed;
      lastWeekBucket = newBucket;
      _resetWeeklyAffectionCaps(weeksCrossed);
    }

    // 学院杯年度榜：跨过上学日时，其它三院逐日自然增长（世界不因玩家而停转）。
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
    if (worldState.time.isFullMoon && !worldState.specialMarkers.contains('🌙满月')) {
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
    refreshNpcLocations(npcRegistry.values, worldState.time.hour,
        worldState.time.weekday);

    // 学年推进检测（9月1日触发）
    _checkSchoolYearTransition(oldMonth, oldYear);

    // 事件锚点检测（按月份触发手写剧情骨架）
    if (fireAnchors) {
      _checkEventAnchors(hourFrom: hourFrom, dayDelta: dayDelta);
    }

    // 孕期推进（结婚 → 备孕 → 分娩）
    this.advancePregnancy();

    _runConsistencyChecks();

    _checkMonthlyEvolution(oldMonth, oldYear);

    // ====== 传闻传播：从近期世界事件中自动生成传闻 ======
    if (dayDelta > 0 && player != null) {
      _maybeGenerateRumor();
    }
  }

  /// 从近期世界事件中自动生成一条传闻（约 20% 概率）
  void _maybeGenerateRumor() {
    final p = player;
    if (p == null) return;
    final rand = random;
    if (rand.nextDouble() > 0.2) return;

    final recentEvents = worldState.recentEvents;
    if (recentEvents.isEmpty) return;

    final event = recentEvents[rand.nextInt(recentEvents.length)];
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
  }

  void advanceTimeForAction(String action) {
    _advanceWorldClock(resolveActionCost(action));
  }

  /// 学院杯年度榜：其它三院按上学日逐日自然增长。
  ///
  /// 由 `_advanceWorldClock` 跨天时调用。只算上学日（周一~周五）且只在
  /// 学期内（第一/第二学期）增长——暑假大家都回家了，没有公开加分的
  /// 校规在跑。玩家学院的行不在这里加：它 = 基准 + 玩家本学年贡献，
  /// 由 `addHouseCupPoints` 实时同步，避免这里再加一遍把玩家学院顶飞。
  void _accumulateHouseCupRivals(int dayDelta) {
    if (dayDelta <= 0) return;
    if (worldState.term == 'summer') return;

    final yearly = worldState.houseCupYearly;
    // 四院缺谁补谁（putIfAbsent 不动已有的行）：
    // 玩家可能先挣分把自家学院行写进去——不能因为表非空就把其它三院漏掉。
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
        yearly[h] = yearly[h]! +
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
  };

  /// 今日该活动已进行的次数（跨天自动归零）。
  int dailyCountOf(String activity) {
    _rollDailyActivityIfNeeded();
    return dailyActivityCount[activity] ?? 0;
  }

  int dailyLimitOf(String activity) => kDailyActivityLimits[activity] ?? 99;

  /// 今日是否还能进行该活动。
  bool canDoDaily(String activity) =>
      dailyCountOf(activity) < dailyLimitOf(activity);

  /// 记录一次活动。
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
    memory = memory.addKeyFact(KeyFactRecord(
      id: 'whatif_${s.createdAt}_${s.title.hashCode}',
      fact: adoptedFactFor(s),
      importance: 6,
      timestamp: worldState.time.format(),
      category: 'what_if',
    ));

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
  String? addForumPost({
    required String category,
    required String content,
  }) {
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

  void addForumPostComment(String id) {
    final p = player;
    if (p == null) return;
    final post = p.forumPosts.where((e) => e.id == id).firstOrNull;
    if (post == null) return;
    post.comments += 1;
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
      // 每次最多走到次月 1 日：保证 _checkMonthlyEvolution 每个月都能触发
      final step = min(remaining, _daysLeftInMonth(t.year, t.month, t.day) + 1);
      // 每一步都查锚点：只查末步会把跨过的整月锚点整个吞掉
      // （月份已经过去，错过即错过——但至少要触发"本月该发生的事"）。
      _advanceWorldClock(0, days: step, fireAnchors: true);
      remaining -= step;
    }

    // 快进后清空停滞计数并同步追踪地点：玩家显然已经不在原来那个场景里了
    turnsAtSameLocation = 0;
    lastTrackedLocation = worldState.currentLocation;

    final endLabel = worldState.time.formatDate();
    worldState.addNarrativeEvent('⏩ 时间快进 $days 天（$startLabel → $endLabel）',
        turn: turnCount);

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

  int _schoolYearStartFor(int year, int month) {
    return month >= 9 ? year : year - 1;
  }

  /// 学年切换检测：当进入新的学年（9月）时，推进玩家与 NPC 年级

  void _checkSchoolYearTransition(int oldMonth, int oldYear) {
    final p = player;
    if (p == null) return;
    final t = worldState.time;

    final newStart = _schoolYearStartFor(t.year, t.month);
    if (lastSchoolYearStart == 0) {
      // 首次初始化追踪（不触发晋升）
      lastSchoolYearStart = newStart;
      return;
    }
    if (newStart <= lastSchoolYearStart) return;

    // 跨越了一个或多个学年
    final yearsPassed = newStart - lastSchoolYearStart;
    lastSchoolYearStart = newStart;

    // 玩家已毕业则不再推进年级，但教职与正式职业要照常走年结：
    // 任教年限、年薪、晋升考核都挂在九月这个节点上。
    if (worldState.graduated) {
      _settleFacultyYear(yearsPassed);
      settleCareerYear(yearsPassed);
      updateAcademicYearLabel();
      return;
    }

    final oldGrade = p.grade ?? 1;
    final newGrade = oldGrade + yearsPassed;

    if (newGrade > 7) {
      // 毕业
      // 先结算最后一学年的学院杯：原本这条分支直接毕业，导致七年级全年
      // 攒下的 houseCupPoints 永不结算、永不清零，house_cup_winner 成就
      // 在最后一年也无法达成。同届 NPC 同样需要走一次晋升/毕业。
      _promoteNpcs(yearsPassed);
      settleHouseCup();
      p.grade = 7;
      worldState.graduated = true;
      // 七年级末的 N.E.W.T（终极巫师等级考试）与最后一次期末考
      _settleExams('Y7');
      _settleExams('NEWT', newt: true);
      _onPlayerGraduated(oldGrade);
    } else {
      p.grade = newGrade;
      _promoteNpcs(yearsPassed);
      _onSchoolYearStart(newGrade);
    }
    updateAcademicYearLabel();
  }

  /// 更新学年标签（如 1992-1993）

  void updateAcademicYearLabel() {
    final t = worldState.time;
    final start = _schoolYearStartFor(t.year, t.month);
    worldState.academicYear = '$start-${start + 1}';
    // 学期：9-12月第一学期，1-6月第二学期，7-8月暑假
    if (t.month >= 9) {
      worldState.term = 'first';
    } else if (t.month <= 6) {
      worldState.term = 'second';
    } else {
      worldState.term = 'summer';
    }
  }

  /// 推进所有在校生 NPC 年级，七年级以上者毕业离校

  void _promoteNpcs(int yearsPassed) {
    final graduatedNames = <String>[];
    for (final npc in npcRegistry.values) {
      if (npc.grade <= 0) continue; // 教职/成人不推进
      if (npc.graduated) continue;
      npc.grade += yearsPassed;
      if (npc.grade > 7) {
        npc.graduated = true;
        npc.grade = 7;
        graduatedNames.add(npc.name);
      }
    }
    if (graduatedNames.isNotEmpty) {
      notifications.add('🎓 ${graduatedNames.take(5).join('、')}${graduatedNames.length > 5 ? '等' : ''} 已从霍格沃茨毕业');
      worldState.addNarrativeEvent('🎓 一批高年级学生毕业了：${graduatedNames.take(5).join('、')}', turn: turnCount);
    }
  }

  /// 新学年开始的叙事与通知

  void _onSchoolYearStart(int newGrade) {
    final p = player;
    if (p == null) return;
    // 学年结算：上一学年的学院杯排名揭晓（只结算有贡献的玩家）
    settleHouseCup();
    notifications.add('🏫 新学年开始：你升入了${newGrade}年级');

    // ====== 期末考试成绩结算（框架2 第60条：考试真实存在） ======
    // 上一学年末的期末考成绩此时揭晓。成绩由平时熟练度主导，
    // 全科优秀的概率极低——差生不会因为过了一个暑假就变天才。
    _settleExams('Y${newGrade - 1}');
    if (newGrade == 6) {
      // 五年级末的 O.W.L（普通巫师等级考试）
      _settleExams('OWL', owl: true);
    }

    // ====== 学年里程碑：注入学年特有的事件叙事 ======
    {
      final milestoneText = schoolYearEventText(newGrade, seed: turnCount);
      if (milestoneText != null) {
        notifications.add('📜 $milestoneText');
        worldState.addNarrativeEvent(
          '📜 第${newGrade}学年里程碑：$milestoneText',
          turn: turnCount,
        );
      }
    }

    worldState.addNarrativeEvent('🏫 ${worldState.time.year}年9月，你升入${newGrade}年级', turn: turnCount);
    worldState.addMarker('⏳新学年');
    // 学年子目标：从 SubGoal 池抽一条作为本学年的记忆锚点（此前整个池是死数据）。
    // 注入 AI 指令让这一年有方向感，但不强制——玩家仍可自由行动。
    try {
      final sub = selectYearGoal(newGrade, seed: turnCount);
      if (sub.steeringHint.isNotEmpty) {
        pendingAnchorDirective = (pendingAnchorDirective ?? '')
            .isEmpty ? sub.steeringHint : '$pendingAnchorDirective\n${sub.steeringHint}';
        notifications.add('🎯 本学年方向：${sub.label}');
      }
    } catch (_) {
      // 子目标池为空/异常时静默降级，不影响学年推进
    }
    // 新学年重置原创NPC生成计数（通过清理标记实现每学年限额）
    debugPrint('🎓 学年推进：玩家升入${newGrade}年级');
  }

  // ==================== 考试成绩结算（框架2 第60条） ====================

  /// 结算一场考试：按玩家当前熟练度 + 临场随机算出各科成绩，写入
  /// player.examRecords[key]，并发通知。同 key 已结算过则不重复覆盖
  /// （一场考试一辈子只有一次成绩，重读档也不该变）。
  void _settleExams(String key, {bool owl = false, bool newt = false}) {
    final p = player;
    if (p == null) return;
    if (p.examRecords.containsKey(key)) return;

    final records = settleExams(
      playerAttrs: p.attributes,
      nextDouble: random.nextDouble,
      owl: owl,
      newt: newt,
    );
    p.examRecords[key] = records;
    final s = examSummary(records);

    final buf = StringBuffer();
    if (owl) {
      buf.writeln('📜 【O.W.L. 普通巫师等级考试成绩揭晓】');
      worldState.addNarrativeEvent('📜 O.W.L. 考试成绩揭晓：${s.oCount}个O，${s.eCount}个E', turn: turnCount);
    } else if (newt) {
      buf.writeln('📜 【N.E.W.T. 终极巫师等级考试成绩揭晓】');
      worldState.addNarrativeEvent('📜 N.E.W.T. 考试成绩揭晓：${s.oCount}个O，${s.eCount}个E', turn: turnCount);
    } else {
      buf.writeln('📜 【第$key 学年期末考试成绩揭晓】');
      worldState.addNarrativeEvent('📜 $key 学年期末考试成绩揭晓：${s.oCount}个O，${s.eCount}个E', turn: turnCount);
    }
    buf.writeln(formatExamSheet(records));
    if (s.oCount >= 3) {
      buf.writeln('\n🏅 ${s.oCount} 个「O」——全年级都听说过你的名字了。');
      p.playerReputation.add('academic', 8);
    } else if (s.aPlusCount >= 6) {
      buf.writeln('\n📖 大部分科目都拿到了 A 以上，教授们对你印象不错。');
      p.playerReputation.add('academic', 4);
    } else if (s.aPlusCount <= 2) {
      buf.writeln('\n⚠️ 成绩单不太好看。教授们看你的眼神里多了几分欲言又止。');
      p.playerReputation.add('academic', -3);
    }
    notifications.add(buf.toString());
  }

  /// 玩家毕业（七年级结束）

  void _onPlayerGraduated(int oldGrade) {
    final p = player;
    if (p == null) return;
    notifications.add('🎓 你从霍格沃茨毕业了！七年的魔法生涯画上句点。');
    worldState.addNarrativeEvent('🎓 ${worldState.time.year}年，你从霍格沃茨毕业', turn: turnCount);
    worldState.addMarker('🎓毕业');
    // 毕业是世界线上最明确的不可逆节点：从此不再跟着学年走。
    // timelineBranches 此前一次都没被写过（只有测试在调用 addTimelineBranch），
    // 而 /联动 又把它显示给玩家，于是那一栏永远只有「暂无。」。
    worldState.addTimelineBranch(
        '${worldState.time.year} 年从霍格沃茨毕业，人生轨迹自此不再跟着既定的学年走');
    debugPrint('🎓 玩家毕业（原${oldGrade}年级）');
    // 毕业结算：评估人生目标达成情况并生成结算报告
    _graduationSettlement();
    // 职业引导：毕业不是结局——用成绩与名声去叩开职业的大门
    notifications.add('💼 毕业不是结局：/职业 列表 看看你七年攒下的成绩能叩开哪扇门');
  }

  // ==================== 毕业结算系统 ====================

  /// 评估目标毕业条件，返回 (条件描述, 是否达成) 列表

  List<(String, bool)> _evaluateGoalRequirement(GoalRequirement req) {
    final p = player;
    if (p == null) return [];
    final lines = <(String, bool)>[];
    if (req.reputationDim != null) {
      final cur = p.playerReputation.get(req.reputationDim!);
      lines.add(('${p.playerReputation.labelOf(req.reputationDim!)} ≥ ${req.reputationMin}（当前 $cur）', cur >= req.reputationMin));
    }
    if (req.attributeKey != null) {
      final cur = p.attributes[req.attributeKey!] ?? 0;
      lines.add(('${attrLabel(req.attributeKey!)} ≥ ${req.attributeMin}（当前 $cur）', cur >= req.attributeMin));
    }
    if (req.wealthMin > 0) {
      final cur = p.galleons + p.bankGalleons;
      lines.add(('资产 ≥ ${req.wealthMin} 加隆（当前 $cur）', cur >= req.wealthMin));
    }
    if (req.deepRelationsMin > 0) {
      final cur = npcRegistry.values.where((n) => n.isAlive && n.affection >= 50).length;
      lines.add(('深厚羁绊（好感≥50）≥ ${req.deepRelationsMin} 人（当前 $cur）', cur >= req.deepRelationsMin));
    }
    if (req.worldLineMin > 0) {
      final cur = p.worldLineDeviation;
      lines.add(('世界线变动率 ≥ ${(req.worldLineMin * 100).toStringAsFixed(0)}%（当前 ${(cur * 100).toStringAsFixed(1)}%）', cur >= req.worldLineMin));
    }
    return lines;
  }

  /// 毕业结算：评估人生目标、解锁成就、生成结算报告（追加到当前剧情后）

  void _graduationSettlement() {
    final p = player;
    if (p == null) return;

    unlockAchievement('graduated');

    final goal = p.currentGoal != null ? goalByName(p.currentGoal!) : null;
    final reqLines = goal != null ? _evaluateGoalRequirement(goal.requirement) : <(String, bool)>[];
    final goalMet = reqLines.isNotEmpty && reqLines.every((e) => e.$2);
    if (goalMet) {
      unlockAchievement('goal_achieved');
    }

    final buf = StringBuffer()
      ..writeln('╔══════════════════════════════════════╗')
      ..writeln('  🎓 毕业结算 · ${p.name}')
      ..writeln('╚══════════════════════════════════════╝')
      ..writeln();

    if (goal != null) {
      buf.writeln('【人生目标】${goal.name}');
      for (final (label, met) in reqLines) {
        buf.writeln('  ${met ? '✅' : '❌'} $label');
      }
      buf.writeln(goalMet
          ? '\n🏆 目标达成！你在霍格沃茨的七年，画上了一个方向明确的句号。'
          : '\n这个目标尚未完全达成——但毕业不是终点，你的人生仍可以继续书写。');
    } else {
      buf.writeln('【人生目标】未设定——你的七年平静而真实地流淌而过。');
    }

    final rep = p.playerReputation;
    final deepCount = npcRegistry.values.where((n) => n.isAlive && n.affection >= 50).length;
    buf
      ..writeln()
      ..writeln('【七年统计】')
      ..writeln('· 声望：学术${rep.academic}｜社交${rep.social}｜战斗${rep.combat}｜道德${rep.moral}｜领导${rep.leadership}')
      ..writeln('· 资产：${p.galleons + p.bankGalleons} 加隆')
      ..writeln('· 深厚羁绊：$deepCount 人')
      ..writeln('· 世界线变动率：${(p.worldLineDeviation * 100).toStringAsFixed(1)}%')
      ..writeln('· 成就：${p.achievements.length} / ${achievementCatalog.length}')
      ..writeln();

    // 学业总评：与官方毕业期望对比（growthExpectation 此前从未被读过）
    buf.writeln('【学业总评】');
    var metCount = 0;
    var totalCount = 0;
    for (final e in Balance.growthExpectation.entries) {
      // 'charms' 是课程键，对应属性键 spell_understanding
      final attrKey = e.key == 'charms' ? 'spell_understanding' : e.key;
      final cur = p.attributes[attrKey] ?? 50;
      final exp = e.value['graduate'] ?? 50;
      totalCount++;
      final ok = cur >= exp;
      if (ok) metCount++;
      buf.writeln('  ${ok ? '✅' : '▫️'} ${attrLabel(attrKey)}：$cur（毕业期望 $exp）');
    }
    buf.writeln(metCount >= totalCount * 0.7
        ? '\n你拿着这份成绩单，可以理直气壮地叩开大多数职业的大门。'
        : '\n部分科目未达到毕业期望——但人生不只有成绩单，你还有别的路。');
    buf.writeln();
    buf.writeln('输入 /结局 可生成完整终章评语，或继续你的毕业后人生。');

    // 回望：把七年编成一篇能读的文章。
    //
    // 上面那一屏全是数字——声望、资产、成就——全对，
    // 但读完之后你不知道这七年发生了什么。玩家花几十个小时走完的七年，
    // 最后一屏不该是一张成绩单。
    final review = formatEndingReview(buildEndingReview(endingFactsOf(p)));
    if (review.isNotEmpty) {
      buf..writeln()..writeln(review);
    }

    // 够格的话，把留校邀请挂到结算报告末尾。
    // 放在这儿而不是通知里：毕业那一刻玩家正在读七年总账，
    // 顺手就能看到「你被留下了」，比弹一条转瞬即逝的通知有分量。
    _maybeOfferFacultyPosition(buf);

    // 追加到当前剧情之后，保留本回合叙事
    currentNarrative = currentNarrative.isEmpty
        ? buf.toString().trim()
        : '$currentNarrative\n\n${buf.toString().trim()}';
    worldState.addNarrativeEvent('🎓 毕业结算完成${goalMet ? '·人生目标达成' : ''}', turn: turnCount);
  }

  /// /伤痕 的输出。
  ///
  /// 疤只在落下的那一瞬间弹过通知。没有这一屏的话，
  /// 玩家过两年就忘了自己身上有什么——而那些东西是永久的。
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

  String formatGoalProgress() {
    final p = player;
    if (p == null) return '尚未创建角色。';
    final goal = p.currentGoal != null ? goalByName(p.currentGoal!) : null;
    if (goal == null) {
      return '尚未设定人生目标。输入 /目标 查看并设定。';
    }
    final lines = _evaluateGoalRequirement(goal.requirement);
    final met = lines.isNotEmpty && lines.every((e) => e.$2);
    final buf = StringBuffer()
      ..writeln('【目标进度】${goal.name}')
      ..writeln('『${goal.description}』')
      ..writeln();
    for (final (label, ok) in lines) {
      buf.writeln('${ok ? '✅' : '⬜'} $label');
    }
    buf.writeln();
    buf.writeln(met
        ? '🏆 所有毕业条件已达成！坚持到毕业即可在结算中获得「得偿所愿」。'
        : '继续朝着目标努力吧——毕业时将进行最终结算。');
    return buf.toString();
  }

  // ==================== 事件锚点系统 ====================

  /// 按当前月份/年级/时代检查并触发手写事件锚点

  /// [hourFrom] / [dayDelta] 来自本次时钟推进前的时刻，用来判断时段窗口
  /// 是不是被"跨过去"了（详见 anchorsFor 的说明）。
  void _checkEventAnchors({int? hourFrom, int dayDelta = 0}) {
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
      final acYearStart = RegExp(r'^(\d{4})').firstMatch(worldState.academicYear)?.group(1);
      final acYearStartInt = acYearStart != null ? int.tryParse(acYearStart) : null;
      // 用 removeWhere 而不是在 where(...) 的惰性迭代里边遍历边 remove：
      // due.where(...) 返回的是惰性 Iterable，迭代过程中结构性修改底层列表
      // 会直接抛 ConcurrentModificationError。现在只是恰好一条规则只匹配一个
      // 锚点才没炸，哪天同一条规则挂上第二个锚点（或同一个锚点被两条规则
      // 命中）就会在玩家推进剧情的瞬间崩掉。
      for (final rule in anchorGatedRules) {
        final matchedIds = due
            .where((a) => a.id == rule.anchorId && !rule.predicate(t.year, t.month, acYearStartInt))
            .map((a) => a.id)
            .toSet();
        if (matchedIds.isEmpty) continue;
        for (final a in due.where((a) => matchedIds.contains(a.id)).toList()) {
          debugPrint('📜 跳过「${a.title}」锚点：${rule.description} '
              '(academicYear=${worldState.academicYear}, year=${t.year})');
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
    debugPrint('📜 事件锚点触发: ${anchor.id} (${anchor.title})');

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
        debugPrint('⏳ 因果锚点 ${causal.anchorId} 未解锁：'
            '还差 ${(gap * 100).toStringAsFixed(1)}% 变动率'
            '（当前 ${(dev * 100).toStringAsFixed(1)}%）');
      }
    }
  }

  // ==================== 世界线变动率的兑现：因果锚点 ====================

  /// 结算一次因果锚点抉择，返回展示给玩家的后果文本。
  ///
  /// 这是 `player.worldLineDeviation` 唯一的兑现点：
  /// 之前那个数字只在成就、目标门槛、影响力增速三处被读，玩家看不见它到底干嘛用。
  @override
  String resolveCausalChoice(String anchorId, String optionId) {
    final p = player;
    final anchor = causalAnchorFor(anchorId);
    if (p == null || anchor == null) return '这个抉择已经不在了。';
    // 幂等：同一夜只能选一次。UI 上的按钮在快速连点时可能进来两趟。
    if (worldState.causalChoices.containsKey(anchorId)) {
      return '你已经在这一夜做过选择了。';
    }
    CausalOption? opt;
    for (final o in anchor.options) {
      if (o.id == optionId) opt = o;
    }
    if (opt == null) return '没有这个选项。';

    // 先记档再结算：下面 deviation 会被 clamp 到 [0,1]，
    // 而"这一夜做过了没有"只看记档，不能依赖 clamp 之后的数值。
    worldState.causalChoices[anchorId] = opt.id;
    if (pendingCausalAnchorId == anchorId) pendingCausalAnchorId = null;

    final before = p.worldLineDeviation;
    incrementWorldLineDeviation(opt.deviationDelta);
    final after = p.worldLineDeviation;

    for (final e in opt.reputation.entries) {
      p.playerReputation.add(e.key, e.value);
    }
    for (final e in opt.attributes.entries) {
      p.attributes[e.key] =
          ((p.attributes[e.key] ?? 50) + e.value).clamp(0, 100);
    }
    if (opt.healthDelta != 0) {
      p.health = (p.health + opt.healthDelta).clamp(0, 100);
    }
    if (opt.impactDelta != 0.0) {
      worldState.playerImpactScore =
          (worldState.playerImpactScore + opt.impactDelta).clamp(0.0, 1.0);
    }

    final buf = StringBuffer()
      ..writeln('【${anchor.title}】')
      ..writeln()
      ..writeln(opt.consequence);

    // 改写留下的痕迹要落到两个地方：
    // 1) /联动 的「已记录的分叉」——玩家随时能翻自己改过什么
    // 2) 之后每一回合的 AI 上下文——不然 AI 下一回合就照着原著写回去了
    if (opt.echo.isNotEmpty) {
      worldState.addTimelineBranch(opt.echo);
      worldState.addNarrativeEvent('⏳ ${anchor.title}·你选择了「${opt.text}」',
          turn: turnCount);
      notifications.add('⏳ 你改写了一段已经写好的历史');
      if (p.health <= 0) {
        buf.writeln();
        buf.writeln('（你的健康状况已经跌到极限——先去医疗翼。）');
      }
    }

    buf.writeln();
    final pctBefore = (before * 100).toStringAsFixed(1);
    final pctAfter = (after * 100).toStringAsFixed(1);
    final arrow = opt.deviationDelta > 0 ? '↑' : '↓';
    buf.writeln('世界线变动率：$pctBefore% $arrow $pctAfter%'
        '（${stageDefFor(worldLineStageFor(after)).badge} '
        '${stageDefFor(worldLineStageFor(after)).label}）');

    notifyListeners();
    return buf.toString();
  }

  /// /世界线 的输出。
  ///
  /// 关键是**把"还差多少"摆出来**。变动率是个只有小数点后三位的数字，
  /// 不给出通往下一个分歧点的距离，玩家永远不知道自己该做什么、
  /// 也不知道这套系统到底在不在跑。
  /// 世界线变动率的文本进度条（20 格），让「0.3 黑箱」一眼可见（P1-9）。
  String _worldLineBar(double dev) {
    final filled = (dev.clamp(0.0, 1.0) * 20).round();
    return '[' +
        ('█' * filled) +
        ('░' * (20 - filled)) +
        ']';
  }

  /// 属性成长总账：开局定型值 vs 现在（P1-9）。
  String formatGrowth() {
    final p = player;
    if (p == null) return '尚未创建角色。';
    final keys = {...p.attributes.keys, ...p.initialAttributes.keys};
    if (keys.isEmpty) return '【成长总账】\n暂无属性数据。';
    final buf = StringBuffer('【成长总账】\n');
    var totalGain = 0;
    var totalAttrs = 0;
    for (final k in keys) {
      final cur = p.attributes[k] ?? 0;
      final init = p.initialAttributes[k] ?? cur;
      final diff = cur - init;
      totalGain += diff;
      totalAttrs += cur;
      buf.writeln('· ${attributeLabel(k)}：$init → $cur'
          '${diff == 0 ? '' : (diff > 0 ? '  ▲+$diff' : '  ▼$diff')}');
    }
    buf.writeln();
    buf.writeln('属性总值 $totalAttrs｜累计成长 '
        '${totalGain >= 0 ? '+' : ''}$totalGain');
    buf.writeln('（初始值记录于开局定型时，老存档显示差值 0）');
    return buf.toString();
  }

  String formatWorldLine() {
    final p = player;
    if (p == null) return '尚未创建角色。';
    final dev = p.worldLineDeviation;
    final stage = worldLineStageFor(dev);
    final def = stageDefFor(stage);

    final buf = StringBuffer()
      ..writeln('【世界线】${def.badge} ${def.label}')
      ..writeln('变动率 ${(dev * 100).toStringAsFixed(1)}%　'
          '（世界影响力 ${(worldState.playerImpactScore * 100).toStringAsFixed(0)}%）')
      ..writeln(_worldLineBar(dev))
      ..writeln()
      ..writeln(def.aiDirective)
      ..writeln();

    // 已被你改写的事
    final echoes = rewrittenEchoesOf(worldState.causalChoices);
    buf.writeln('【已被你改写的事】');
    if (echoes.isEmpty) {
      buf.writeln('暂无——史书上写的，至今都还是真的。');
    } else {
      for (final e in echoes) {
        buf.writeln('· $e');
      }
      buf.writeln();
      buf.writeln('以上每一条都会一直生效。这个世界是照着它们往下走的，'
          '不是照着原著。');
    }
    buf.writeln();

    // 还没走到的分歧点：给出门槛与差距
    final pending = <CausalAnchor>[];
    for (final a in kCausalAnchors) {
      if (a.era != null && a.era != worldState.era) continue;
      if (worldState.causalChoices.containsKey(a.anchorId)) continue;
      pending.add(a);
    }
    buf.writeln('【尚未解锁的分歧点】');
    if (pending.isEmpty) {
      buf.writeln('这个时代能改的，你都改完了。');
    } else {
      for (final a in pending) {
        final need = stageDefFor(a.minStage);
        final gap = deviationGapToUnlock(a, dev);
        final ok = gap <= 0;
        buf.writeln(ok
            ? '✅ ${a.title}　（需 ${need.label} —— 已达成，等它发生时会出现抉择）'
            : '🔒 ${a.title}　（需 ${need.label} ${(need.minDeviation * 100).toStringAsFixed(0)}%'
                ' —— 还差 ${(gap * 100).toStringAsFixed(1)}%）');
      }
      buf.writeln();
      buf.writeln('变动率随你在这个世界里留下的痕迹缓慢上升，'
          '而每一次「干预」都会让它跳一大截，每一次「旁观」都会把它压回去。');
    }

    return buf.toString();
  }

  // ==================== 毕业后留校任教 ====================

  /// 当前是否有一份留校邀请等着答复。
  ///
  /// 只在「刚毕业 + 够格 + 还没答复过」时为真。挂上之后不会自己消失——
  /// 那封信在你做出答复之前一直压在箱子底下。
  bool _facultyOfferPending = false;

  @override
  bool get pendingFacultyOffer => _facultyOfferPending;

  /// 在职教授的名字 → 好感。教授的 grade 是 0（学生是 1-7）。
  Map<String, int> _teacherAffections() {
    final out = <String, int>{};
    for (final n in npcRegistry.values) {
      if (!n.isAlive) continue;
      if (n.grade != 0) continue; // 学生
      if (n.affection <= 0) continue; // 关系不好就不算"愿意推荐你"
      out[n.name] = n.affection;
    }
    return out;
  }

  @override
  FacultyEligibility evaluateFacultyOffer() {
    final p = player;
    final rep = p?.playerReputation;
    if (p == null || rep == null) {
      return const FacultyEligibility(
        eligible: false,
        checks: [],
        startingRank: FacultyRank.none,
        subject: '魔咒学',
        allies: [],
      );
    }
    return evaluateFacultyEligibility(
      academic: rep.academic,
      moral: rep.moral,
      dark: rep.dark,
      attributes: p.attributes,
      teacherAffections: _teacherAffections(),
    );
  }

  /// 当代在任校长的名字；认不出来就返回 null（由文案退回「校方」）。
  ///
  /// 不能写死"邓布利多"——1892 年他自己还是一年级新生，
  /// 2020 年他已经逝世二十多年。
  String? _headmasterName() {
    for (final n in npcRegistry.values) {
      if (!n.isAlive || n.grade != 0) continue;
      final aliases = <String>{n.name};
      if (n.name.contains('邓布利多') ||
          aliases.any((a) => a.contains('校长'))) {
        return n.name;
      }
    }
    return null;
  }

  /// 毕业时挂上留校邀请。够格才挂；不够格的一个字都不提——
  /// 事后再告诉玩家「你当年差 3 点学术声望」纯属给人添堵。
  void _maybeOfferFacultyPosition(StringBuffer report) {
    final p = player;
    if (p == null) return;
    if (p.facultyOfferDeclined || p.facultyRankId != null) return;

    final e = evaluateFacultyOffer();
    if (!e.eligible) return;

    _facultyOfferPending = true;
    final line = facultyOfferLineFor(
      e: e,
      headmasterName: _headmasterName(),
      playerName: p.name,
    );
    report
      ..writeln()
      ..writeln('──────────────────────────────')
      ..writeln(line)
      ..writeln()
      ..writeln('输入 /教职 接受 或 /教职 婉拒。');
  }

  @override
  String resolveFacultyOffer(bool accept) {
    final p = player;
    if (p == null) return '尚未创建角色。';
    if (p.facultyRankId != null) {
      return '你已经在霍格沃茨任教了。';
    }
    if (p.facultyOfferDeclined) {
      return '那封信你当年已经回绝了。有些门一旦关上就不会再开第二次。';
    }

    final e = evaluateFacultyOffer();

    if (!accept) {
      p.facultyOfferDeclined = true;
      _facultyOfferPending = false;
      final buf = StringBuffer()
        ..writeln('【婉拒留校】')
        ..writeln()
        ..writeln(kFacultyDeclineLine);
      worldState.addNarrativeEvent('婉拒了霍格沃茨的留校邀请', turn: turnCount);
      notifyListeners();
      return buf.toString();
    }

    if (!e.eligible) {
      _facultyOfferPending = false;
      return '邀请已经失效了——这一年的教席安排已经定了。';
    }

    final rank = rankDefFor(e.startingRank);
    p.facultyRankId = rank.id;
    p.facultySubject = e.subject;
    p.facultyServiceYears = 0;
    p.currentJobTitle = '霍格沃茨${rank.title}';
    _facultyOfferPending = false;

    // 预付半年薪水：刚毕业的人总得先安顿下来
    final advance = rank.annualPay ~/ 2;
    p.galleons += advance;

    worldState.addNarrativeEvent(
        '🎓 留校任教：${e.subject}${rank.title}', turn: turnCount);
    // 和毕业、成婚一样，这是回不了头的节点
    worldState.addTimelineBranch(
        '${worldState.time.year} 年留校任教，任「${e.subject}」${rank.title}');
    notifications.add('🏫 你留下了，教${e.subject}');

    final buf = StringBuffer()
      ..writeln('【留校任教】${e.subject}·${rank.title}')
      ..writeln()
      ..writeln(rank.duty)
      ..writeln()
      ..writeln('预付半年薪水：$advance 加隆。')
      ..writeln()
      ..writeln('推荐你的教授：${e.allies.join('、')}。')
      ..writeln('往后每年九月会结算年薪并考核晋升（/教职 查看进度）。')
      ..writeln()
      ..writeln('明天你就要从行李里翻出当年自己那本课本了——'
          '只是这一次，站在讲台上的是你。');

    notifyListeners();
    return buf.toString();
  }

  /// 每年九月：发年薪、加一年服务期、考核晋升。
  ///
  /// [yearsPassed] 是这次学年切换跨过的年数（/快进 可能一次跨好几年）。
  void _settleFacultyYear(int yearsPassed) {
    final p = player;
    final rankId = p?.facultyRankId;
    if (p == null || rankId == null) return;
    final cur = rankDefById(rankId);
    if (cur == null) return;

    p.facultyServiceYears += yearsPassed;
    p.galleons += cur.annualPay * yearsPassed;

    final rep = p.playerReputation;
    final next = promotionFor(
      current: cur.rank,
      serviceYears: p.facultyServiceYears,
      academic: rep.academic,
      leadership: rep.leadership,
    );
    if (next == null) return;

    p.facultyRankId = next.id;
    p.currentJobTitle = '霍格沃茨${next.title}';
    notifications.add('🏫 晋升为${next.title}');
    worldState.addNarrativeEvent(
        '🏫 晋升：${p.facultySubject ?? ''}${next.title}', turn: turnCount);
    worldState.addTimelineBranch(
        '${worldState.time.year} 年晋升为「${p.facultySubject ?? ''}」${next.title}');
  }

  // ==================== 家族传承 ====================

  /// 某个孩子现在几岁
  int childAgeOf(ChildRecord child) =>
      (worldState.time.absoluteDayIndex - child.bornAbsDay) ~/ 365;

  /// 够格接棒的孩子：年满入学年龄（11 岁）
  List<ChildRecord> heirsOfAge() {
    final p = player;
    if (p == null) return const [];
    return p.children
        .where((c) => childAgeOf(c) >= kHeirEntranceAge)
        .toList(growable: false);
  }

  /// 配偶的血统。找不到就当混血——总比凭空冒出个纯血强。
  String _spouseBloodTypeOf(String name) {
    for (final n in npcRegistry.values) {
      if (n.name == name) return n.bloodStatus;
    }
    return 'halfblood';
  }

  /// 为某个孩子算出一份传承清单
  LegacyCarryover buildLegacyFor(ChildRecord child) {
    final p = player!;
    final rep = p.playerReputation;
    final surname = child.name.isNotEmpty ? child.name[0] : p.name[0];
    final spouseBlood = _spouseBloodTypeOf(child.otherParentName);

    // 世交：父母处得好的人，孩子开局就认识
    final affections = <String, int>{};
    for (final n in npcRegistry.values) {
      if (n.isAlive) affections[n.name] = n.affection;
    }
    // 世仇：宿敌（hostile 及以上）会把梁子传下去
    final today = worldState.time.absoluteDayIndex;
    final rivals = npcRegistry.values
        .where((n) =>
            n.isAlive &&
            n.introduced &&
            n.rivalryTier(today).index >= RivalryTier.hostile.index)
        .map((n) => n.name)
        .toList(growable: false);

    final age = childAgeOf(child);
    final startYear = worldState.time.year - (age - kHeirEntranceAge);
    final inheritance = inheritedWealth(p.galleons + p.bankGalleons);
    final summary = summarizeParent(
      parentName: p.name,
      academic: rep.academic,
      combat: rep.combat,
      moral: rep.moral,
      dark: rep.dark,
      leadership: rep.leadership,
      wasFaculty: p.facultyRankId != null,
      worldLinePercent: (p.worldLineDeviation * 100).round(),
    );

    return LegacyCarryover(
      heirName: child.name,
      heirGender: child.gender,
      surname: surname,
      bloodType: mixBloodType(p.bloodType, spouseBlood, random.nextInt(100)),
      familyBackground: buildFamilyBackground(
        surname: surname,
        parentName: p.name,
        parentSummary: summary,
        rivals: rivals,
        inheritance: inheritance,
      ),
      reputation: inheritedReputation(
        academic: rep.academic,
        social: rep.social,
        combat: rep.combat,
        moral: rep.moral,
        leadership: rep.leadership,
        dark: rep.dark,
      ),
      allies: inheritedAllies(affections),
      rivals: rivals,
      inheritance: inheritance,
      parentName: p.name,
      startYear: startYear,
      parentSummary: summary,
    );
  }

  @override
  String formatLegacy() {
    final p = player;
    if (p == null) return '尚未创建角色。';

    if (p.children.isEmpty) {
      return '【传承】\n你还没有孩子。\n'
          '结婚之后可以备孕，等孩子长到 $kHeirEntranceAge 岁，'
          '就能把这一生交给他。';
    }

    final heirs = heirsOfAge();
    if (heirs.isEmpty) {
      final buf = StringBuffer()
        ..writeln('【传承】还没有人够年纪接棒')
        ..writeln();
      for (final c in p.children) {
        final age = childAgeOf(c);
        buf.writeln('· ${c.name}（${c.gender}）${age} 岁，'
            '还差 ${kHeirEntranceAge - age} 年到入学年龄');
      }
      buf
        ..writeln()
        ..writeln('用 /快进 把时间推到他收到录取通知书那年。');
      return buf.toString();
    }

    final buf = StringBuffer()
      ..writeln('【传承】')
      ..writeln();
    for (final c in heirs) {
      final legacy = buildLegacyFor(c);
      buf
        ..writeln('· ${c.name}（${c.gender}，${childAgeOf(c)} 岁）'
            '　${bloodStatusLabel(legacy.bloodType)}')
        ..writeln('  带走：${legacy.inheritance} 加隆')
        ..writeln('  声望：学术${legacy.reputation['academic']}'
            '｜社交${legacy.reputation['social']}'
            '｜战斗${legacy.reputation['combat']}'
            '｜道德${legacy.reputation['moral']}'
            '｜领导${legacy.reputation['leadership']}');
      if (legacy.hasAllies) {
        buf.writeln('  世交 ${legacy.allies.length} 人：'
            '${legacy.allies.keys.take(3).join('、')}'
            '${legacy.allies.length > 3 ? '等' : ''}');
      }
      if (legacy.hasRivals) {
        // 这一栏要单独成行并且放在最后——它是整份清单里最该被看见的东西
        buf.writeln('  ⚠ 世仇 ${legacy.rivals.length} 人：'
            '${legacy.rivals.take(3).join('、')}'
            '${legacy.rivals.length > 3 ? '等' : ''}'
            '——你结下的梁子会跟着这个姓传下去');
      }
      buf.writeln();
    }
    buf
      ..writeln('输入 /传承 名字 把这一生交给他。')
      ..writeln('这会开一局新的：剧情从头开始，'
          '但你的姓、你的血统、你结下的梁子会跟着走。');
    return buf.toString();
  }

  /// 把传承来的世交与世仇落到 NPC 身上。
  ///
  /// 必须在 `_initializeNPCsByEra()` 之后调——名字对不上的话，
  /// 这两栏会静默地什么都不生效，玩家永远不会知道自己继承了什么。
  ///
  /// 这里**刻意不走** `updateNpcAffection`：那是一条「一次好感变化」的管线，
  /// 会记本周增量、撞周上限（30）、记事件、发通知、甚至触发成就。
  /// 而传承写的是**开局初始值**——它不占本周额度，也不该在开始界面
  /// 弹出一串「本周好感已达上限」。继承上限 35 比周上限 30 还高，
  /// 走统一入口会先被砍一刀，那传承就名不副实了。
  @override
  void applyLegacyRelations(LegacyCarryover legacy) {
    final day = worldState.time.absoluteDayIndex;
    for (final npc in npcRegistry.values) {
      final inherited = legacy.allies[npc.name];
      if (inherited != null) {
        npc.affection = inherited;
        npc.maxAffectionReached = inherited;
        npc.introduced = true; // 你从小就认识他
        continue;
      }
      if (legacy.rivals.contains(npc.name)) {
        // 宿敌分靠 grudges 推，一次「积怨」是 18 分（grudge 档门槛 15）。
        // 七成的梁子传下来，正好够让孩子一进校门就被人另眼相看——
        // 但还不至于开局就有人要他的命，那是上一代自己的分量。
        npc.affection = -20;
        npc.introduced = true;
        npc.addGrudge('accumulated', '父辈的旧账', day);
      }
    }
  }

  @override
  Future<bool> startLegacy(String childName) async {
    final p = player;
    if (p == null) return false;
    ChildRecord? heir;
    for (final c in heirsOfAge()) {
      if (c.name == childName) heir = c;
    }
    if (heir == null) return false;

    final legacy = buildLegacyFor(heir);
    await initializeGame(
      name: legacy.heirName,
      bloodStatus: legacy.bloodType,
      birthLocation: p.birthLocation,
      personalityTraits: heir.traits.take(3).toList(),
      gender: legacy.heirGender,
      familyBackground: legacy.familyBackground,
      legacy: legacy,
    );
    return true;
  }

  @override
  String formatFaculty() {
    final p = player;
    if (p == null) return '尚未创建角色。';
    final rankId = p.facultyRankId;

    if (rankId == null) {
      final e = evaluateFacultyOffer();
      final buf = StringBuffer()..writeln('【教职】尚未任教');
      if (p.facultyOfferDeclined) {
        buf
          ..writeln()
          ..writeln('你婉拒过霍格沃茨的留校邀请。那扇门不会再开第二次。');
        return buf.toString();
      }
      if (!worldState.graduated) {
        buf
          ..writeln()
          ..writeln('毕业时若够格，会收到留校邀请。目前差在：');
      } else {
        buf
          ..writeln()
          ..writeln('你没能拿到那封邀请信。差在：');
      }
      for (final (label, ok) in e.checks) {
        buf.writeln('${ok ? '✅' : '⬜'} $label');
      }
      buf
        ..writeln()
        ..writeln('你最拿得出手的一门课是「${e.subject}」。'
            '它就是你将来会被问到的那门课。');
      if (e.allies.isNotEmpty) {
        buf.writeln('愿意替你说话的教授：${e.allies.join('、')}。');
      }
      return buf.toString();
    }

    final def = rankDefById(rankId)!;
    final buf = StringBuffer()
      ..writeln('【教职】${p.facultySubject ?? ''}·${def.title}')
      ..writeln('任教年限：${p.facultyServiceYears} 年　年薪：${def.annualPay} 加隆')
      ..writeln()
      ..writeln(def.duty)
      ..writeln()
      ..writeln('【晋升】')
      ..writeln(promotionHintFor(
        current: def.rank,
        serviceYears: p.facultyServiceYears,
        academic: p.playerReputation.academic,
        leadership: p.playerReputation.leadership,
      ));
    return buf.toString();
  }

  void _resetWeeklyAffectionCaps([int weeksCrossed = 1]) {
    for (final npc in npcRegistry.values) {
      npc.affectionGainedThisWeek = 0;
    }
    debugPrint('📊 新的一周开始：好感周增量已重置');
    _applyAffectionDrift(weeksCrossed);
  }

  /// 好感维系衰减：关系不经营是会淡的。
  ///
  /// 第九次审查前，好感只有「沉淀」（涨得慢）没有「维系」（不联系会回落），
  /// 玩家可以把一排 NPC 刷到 85+ 然后放着不管——集邮式社交，
  /// 关系网后期失真，也跟「NPC 有自己的生活」的设定矛盾。
  ///
  /// 规则（常量在 Balance）：
  ///  - 连续 [Balance.affectionDriftIdleDays] 天没有任何好感互动后，
  ///    每个游戏周自然转淡 1~2 点；
  ///  - 只淡正好感，且在 [Balance.affectionDriftFloor]（「好感」段下沿）停住：
  ///    会变生分，不会淡回素不相识；
  ///  - 豁免：持有「信任锁」的（老朋友不联系也不会变陌生）、
  ///    当前恋人、未登场的、已去世的、负好感（记恨不随时间消，那是宿敌系统的事）；
  ///  - 快进跨多周时按实际跨过的周数结算，但每人每次最多补 4 周，
  ///    防止一次长跳过把一段关系直接跳没。
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
        total += Balance.affectionDriftPerWeekMin +
            random.nextInt(Balance.affectionDriftPerWeekMax -
                Balance.affectionDriftPerWeekMin +
                1);
      }
      final before = npc.affection;
      npc.affection =
          (npc.affection - total).clamp(Balance.affectionDriftFloor, 100);
      if (npc.affection != before) {
        syncRelationshipLevel(npc);
        drifted.add(npc.name);
        // P1-10 观测日志：衰减体感/好感通胀速度留待真实数据调参，
        // 记录每次衰减的 NPC/天数/幅度，供后续根据实际档位校准
        // affectionDriftPerWeekMin/Max。
        if (kDebugMode) {
          debugPrint('[好感衰减] ${npc.name}: $before → ${npc.affection}'
              '（闲置 $idleDays 天，结算 $weeks 周，合计 -$total）');
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

  /// 传闻衰减：旧闻（超过 30 个游戏日）从传闻列表里淡出。
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
      debugPrint('📰 传闻衰减：${before - p.rumors.length} 条旧闻淡出');
    }
  }

  void _checkMonthlyEvolution(int oldMonth, int oldYear) {
    final newMonth = worldState.time.month;
    final newYear = worldState.time.year;
    if (newMonth != oldMonth || newYear != oldYear) {
      _generateMonthlyEvent(newMonth, newYear);
    }
  }

  /// [e] 的互斥伙伴里，有没有谁是在 [kMutuallyExclusiveMonths] 个月内刚播过的。
  bool _monthlyEventBlockedByExclusive(MonthlyEventDef e, int monthIndex) {
    for (final otherId in e.mutuallyExclusiveIds) {
      final lastAt = worldState.monthlyEventFiredAt[otherId];
      if (lastAt == null) continue;
      if (monthIndex - lastAt < kMutuallyExclusiveMonths) return true;
    }
    return false;
  }

  /// [e] 本次是否不该参与抽取（自身重复冷却 + 互斥窗口）。
  bool _monthlyEventOnCooldown(MonthlyEventDef e, int monthIndex) {
    final lastAt = worldState.monthlyEventFiredAt[e.id];
    if (lastAt != null &&
        monthIndex - lastAt < MonthlyEventDef.repeatCooldownMonths) {
      return true;
    }
    return _monthlyEventBlockedByExclusive(e, monthIndex);
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
      final seasonMatch = e.seasonTags.isEmpty ||
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
        final seasonMatch = e.seasonTags.isEmpty ||
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

    final event = '【${year}年${month}月·月度世界演化】${selected.text}';

    worldState.recentEvents.insert(0, NarrativeEvent(event, turn: turnCount));
    if (worldState.recentEvents.length > 50) {
      worldState.recentEvents.removeLast();
    }

    notifications.add('🌍 $event');
    worldState.addNarrativeEvent('🌍 $event', turn: turnCount);
  }

  void _runConsistencyChecks() {
    final p = player;
    if (p == null) return;
    final issues = <String>[];

    // 通知栏以前只增不清：全项目 40 多处 notifications.add，唯一的清理点是
    // resetAllState（只有「开新游戏」走得到）。长局内存无限增长，
    // /通知 又只展示最近 10 条，多出来的永远看不见。这里裁到 50 条。
    if (notifications.length > 50) {
      notifications.removeRange(0, notifications.length - 50);
    }

    // ====== 资源值钳制 ======
    p.health = p.health.clamp(0, 100);
    p.magic = p.magic.clamp(0, 100);
    p.spirit = p.spirit.clamp(0, 100);
    p.satiety = p.satiety.clamp(0, 100);
    p.energy = p.energy.clamp(0, 100);

    // ====== 属性合理性检查 ======
    for (final entry in p.attributes.entries) {
      if (entry.value < 0) {
        p.attributes[entry.key] = 0;
        issues.add('属性"${entry.key}"负值，已归零');
      }
      if (entry.value > 100) {
        p.attributes[entry.key] = 100;
        issues.add('属性"${entry.key}"超过100，已钳制');
      }
    }

    // ====== 学院四维检查 ======
    for (final entry in p.houseDimensions.entries) {
      if (entry.value < 0) {
        p.houseDimensions[entry.key] = 0;
        issues.add('学院四维"${entry.key}"负值，已归零');
      }
      if (entry.value > 100) {
        p.houseDimensions[entry.key] = 100;
        issues.add('学院四维"${entry.key}"超过100，已钳制');
      }
    }

    // ====== 世界线变动率检查 ======
    if (p.worldLineDeviation < 0) {
      p.worldLineDeviation = 0;
      issues.add('世界线变动率负值，已修正');
    }
    if (p.worldLineDeviation > 1) {
      p.worldLineDeviation = 1;
      issues.add('世界线变动率超过100%，已钳制');
    }

    // ====== NPC好感与关系检查 ======
    for (final npc in npcRegistry.values) {
      npc.affection = npc.affection.clamp(-100, 100);
      if (!npc.isAlive && p.relationships.containsKey(npc.id)) {
        issues.add('NPC "${npc.name}" 已死亡但仍在关系列表中');
      }
      if (npc.affection > npc.maxAffectionReached) {
        npc.maxAffectionReached = npc.affection;
      }
      if (npc.hasGrudge && npc.affection > npc.effectiveAffectionCap) {
        npc.affection = npc.effectiveAffectionCap;
        issues.add('NPC "${npc.name}" 好感超过背叛前水平，已钳制');
      }
    }

    // ====== 恋爱状态一致性检查 ======
    if (p.loveState.status != '单身') {
      if (p.loveState.partnerId == null || p.loveState.partnerName == null) {
        p.loveState.status = '单身';
        p.loveState.partnerId = null;
        p.loveState.partnerName = null;
        issues.add('恋爱状态不一致（缺少伴侣信息），已重置为单身');
      } else {
        final partnerNpc = npcRegistry[p.loveState.partnerId];
        if (partnerNpc == null || !partnerNpc.isAlive) {
          p.loveState.status = '单身';
          p.loveState.partnerId = null;
          p.loveState.partnerName = null;
          issues.add('恋爱对象已不存在，已重置为单身');
        }
      }
    }

    // ====== 时间合理性检查 ======
    final year = worldState.time.year;
    if (year < 1890 || year > 2100) {
      issues.add('年份异常: $year');
    }
    final month = worldState.time.month;
    if (month < 1 || month > 12) {
      worldState.time.month = month.clamp(1, 12);
      issues.add('月份越界，已修正');
    }
    final day = worldState.time.day;
    if (day < 1 || day > 31) {
      worldState.time.day = day.clamp(1, 31);
      issues.add('日期越界，已修正');
    }

    // ====== 时代一致性检查 ======
    final eraName = worldState.era;
    final appEra = appProvider.era.name;
    if (eraName.isNotEmpty && eraName != appEra) {
      debugPrint('存档时代($eraName)与当前设置($appEra)不一致');
    }

    // ====== 货币合理性 ======
    if (p.galleons < 0) {
      p.galleons = 0;
      issues.add('加隆余额负值，已归零');
    }
    if (p.bankGalleons < 0) {
      p.bankGalleons = 0;
      issues.add('古灵阁存款负值，已归零');
    }

    // ====== 背包物品检查 ======
    p.inventory.removeWhere((item) => item.name.isEmpty);
    if (p.inventory.length > 100) {
      p.inventory.removeRange(100, p.inventory.length);
      issues.add('背包物品超过上限，已清理');
    }

    // ====== 声望合理性检查 ======
    final reputationFields = ['academic', 'social', 'combat', 'moral', 'leadership', 'dark'];
    for (final field in reputationFields) {
      final value = p.playerReputation.get(field);
      if (value < 0 || value > 100) {
        p.playerReputation.setValue(field, value.clamp(0, 100));
        issues.add('声望$field越界，已修正');
      }
    }

    // ====== 成就检查 ======
    checkAllAchievements();

    if (issues.isNotEmpty) {
      notifications.add('⚠️ 状态自修复：${issues.join('；')}');
      debugPrint('🛡️ 防崩坏自检: 修复${issues.length}项状态异常');
    }
  }

  void fastForwardTime(int days) {
    // P0-3 收敛：统一委托 fastForwardDays（内部走 _advanceWorldClock 全量结算：
    // 游戏周/学院杯/NPC位置/学年推进/事件锚点/孕期/月度演化/传闻）。
    // 旧的独立实现按天循环，漏了 NPC 位置刷新、孕期推进、学院杯对手分、
    // 传闻生成，且 _checkEventAnchors() 用默认 hourFrom/dayDelta 匹配，
    // 快进跨过的事件窗口会整体错位——两套实现因此不等价。
    // 注意：fastForwardDays 对超大天数有 guard 上限（200 步内每月推进），
    // 因此这里的超大值（如 /cheat 时间 999999）不会冻结主线程。
    fastForwardDays(days);
  }

  // ==================== NPC 状态更新 ====================

  void updateNPCsFromAction(String action) {
    // 消耗资源 - 大幅降低消耗，让玩家有更多精力进行活动
    final p = player!;
    p.energy = max(0, p.energy - 2);  // 从5降到2
    p.satiety = max(0, p.satiety - 2);  // 从3降到2
    p.spirit = max(0, p.spirit - 1);  // 从2降到1

    // 扩展恢复关键词，让更多行动可以恢复精力
    if (action.contains('吃饭') || action.contains('用餐') || 
        action.contains('进食') || action.contains('吃东西')) {
      p.satiety = min(100, p.satiety + 30);
      p.energy = min(100, p.energy + 5);  // 吃饭也恢复少量精力
    }
    if (action.contains('睡觉') || action.contains('休息') || 
        action.contains('睡') || action.contains('歇') ||
        action.contains('躺') || action.contains('养') ||
        action.contains('放松') || action.contains('回房') ||
        action.contains('回宿舍') || action.contains('睡觉') ||
        action.contains('小憩')) {
      p.energy = min(100, p.energy + 50);  // 从40提升到50
      p.spirit = min(100, p.spirit + 30);  // 从20提升到30
      p.satiety = min(100, p.satiety + 5);
    }
    if (action.contains('冥想') || action.contains('打坐') ||
        action.contains('修炼') || action.contains('学习')) {
      p.spirit = min(100, p.spirit + 15);
      p.energy = min(100, p.energy + 5);
    }
    if (action.contains('散步') || action.contains('走') ||
        action.contains('逛') || action.contains('活动')) {
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
        this.updateNpcAffection(npc.id, 1, reason: '日常相处', quiet: true);
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
    if (RegExp(r'(约会|散步|独处|谈心|表白|浪漫|心仪|心动|一起去看|一起吃饭|单独)').hasMatch(action)) {
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
    worldState.addNarrativeEvent('💕 与${npc.name}之间发生了一段浪漫插曲。', turn: turnCount);
  }

  // ==================== 快速推进 ====================
  // ==================== 查看人物 ====================

  /// `/查看 [名字]` 的输出。
  ///
  /// 原先这里只有一个 `getViewableCharacter`，返回 Map 给 UI 用——但没有任何
  /// UI 消费它，于是整套「可见性判定 + 档案组装」实际上死了。改成直接产出
  /// 玩家能读的文本，并新增 `/查看` 命令作为入口。
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
    buf.writeln('$house｜${npc.grade}年级$gender｜${npcBloodStatusLabel(npc.bloodStatus)}');
    buf.writeln('所在：${npc.currentLocation}｜${_moodLabel(npc.mood)}'
        '${npc.isAlive ? '' : '｜已故'}');

    final rel = player?.relationships[npc.id];
    if (rel != null) {
      buf.writeln('关系：${rel.relationType}（Lv.${rel.level}）｜'
          '好感 ${npc.affection}（${npc.affectionStage}）');
    } else {
      buf.writeln('好感 ${npc.affection}（${npc.affectionStage}）｜尚未建立正式关系');
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
    if (npc.personalGoal != null && npc.personalGoal!.isNotEmpty) {
      buf.writeln('心上事：${npc.personalGoal}');
    }
    if (npc.knowsAbout.isNotEmpty) {
      buf.writeln('知道：${npc.knowsAbout.take(3).join('、')}');
    }
    if (npc.schedule.isNotEmpty) {
      final slots = npc.schedule.entries.take(3)
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
    if (repFilled.isNotEmpty) buf.writeln('声望：${repFilled.join('｜')}');

    if (npc.hasGrudge) {
      final day = worldState.time.absoluteDayIndex;
      final tier = npc.rivalryTier(day);
      final reason = npc.rivalryReason();
      buf.writeln('${rivalryBadgeFor(tier)} 记恨着你：$reason'
          '（${tierDefFor(tier).label}｜宿敌分 ${npc.rivalryScore(day)}'
          '｜好感上限 ${npc.effectiveAffectionCap}）');
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
    return buf.toString();
  }

  /// 当前能查看的人（`/查看` 不带参数时的名册）。
  String get _visibleRoster {
    final visible = npcRegistry.values
        .where(_isNPCVisible)
        .toList()
      ..sort((a, b) => b.affection.compareTo(a.affection));
    if (visible.isEmpty) {
      return '你现在还叫得出名字的人一个也没有——先去上课或者到公共休息室坐坐。';
    }
    final buf = StringBuffer('可查看的人（按好感排序）：\n');
    for (final n in visible.take(12)) {
      buf.writeln('· ${n.name}（${n.affectionStage} ${n.affection}）'
          '${n.isAlive ? '' : ' · 已故'}');
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
  void travelTo(String location) {
    final cur = worldState.currentLocation ?? '';
    // 显示名 → 规范主名（认不出就保留原样，不把现有行为改坏）。
    final normalized = resolveLocationName(location) ?? location;
    final dateInt = worldState.time.month * 100 + worldState.time.day;

    if (blockedBySeasonGate(detected: normalized, current: cur, dateInt: dateInt)) {
      worldState.addNarrativeEvent(
        '⏱ 地图旅行被时间门拦截：$location（需 9月1日，'
        '当前 ${worldState.time.month}月${worldState.time.day}日）',
        turn: turnCount,
      );
      notifyListeners();
      return;
    }
    if (blockedByGradeGate(detected: normalized, grade: player?.grade ?? 1)) {
      worldState.addNarrativeEvent(
        '⏱ 地图旅行被年级门拦截：$location（霍格莫德需三年级，当前${player?.grade ?? 1}年级）',
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
    notifyListeners();
  }

  /// 根据玩家行动累计影响力分数
  /// 每回合 +0.01，涉及原著NPC互动 +0.02，涉及关键剧情(恋爱/CG/成就) +0.05

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
      '魂器': 0.05, '黑魔法': 0.03, '伏地魔': 0.06,
      '表白': 0.02, '恋爱': 0.015, '告白': 0.02,
      '战斗': 0.03, '决斗': 0.035, '冒险': 0.02,
      '秘密': 0.02, '发现': 0.015, '预言': 0.03,
      '死亡': 0.05, '杀死': 0.06, '拯救': 0.04,
      '入学': 0.02, 'OWL': 0.025, 'NEWT': 0.025, '毕业': 0.04,
      '魁地奇': 0.015, '学院杯': 0.02, '三强争霸': 0.04,
      '部长': 0.03, '魔法部': 0.02, '校长': 0.025,
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

    worldState.playerImpactScore = (worldState.playerImpactScore + delta).clamp(0.0, 1.0);
  }

  /// 便捷入口：在非 action 场景（告白成功、CG解锁、事件锚点达成、月度事件、
  /// 新 NPC 生成、毕业结算等）直接给 playerImpactScore 加一次分，
  /// 避免这些"真正改变世界"的场景因为不从 updatePlayerImpactScore(action) 走而被忽略。

  void bumpImpactScore(double delta, {String? debugReason}) {
    if (worldState.playerImpactScore >= 1.0) return;
    worldState.playerImpactScore = (worldState.playerImpactScore + delta).clamp(0.0, 1.0);
    if (debugReason != null) {
      debugPrint('🌐 影响力+${delta.toStringAsFixed(3)} → ${worldState.playerImpactScore.toStringAsFixed(3)}（$debugReason）');
    }
  }

  // ==================== 好感度操作（供UI调用） ====================

  void checkLocks(NPC npc) {
    if (npc.affection >= Balance.trustLockThreshold && !npc.hasLock('信任锁')) {
      npc.affectionLocks.add('信任锁');
    }
    if (npc.affection >= Balance.romanceLockThreshold && !npc.hasLock('情感锁')) {
      npc.affectionLocks.add('情感锁');
    }
  }

  Future<ChatResult> callDeepSeek(String prompt, {AiScene scene = AiScene.narrative}) async {
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
        systemPrompt = buildSystemPrompt();
      }
      effectiveSystemPrompt = systemPrompt ?? '';
    }
    // 2026-08-24：maxTokens 按场景精细化分配
    //   narrative 主剧情：4000（配合 600-800 字精练叙事要求，总 token 约 2000-3000）
    //   choice 选项：1000（只输出 4 行 ABCD ≈ 300 tokens，留余量给思考型模型的推理过程）
    //   summary 摘要：4000（输出 800-2400 字摘要 + 结构化记忆块）
    //   npcChat NPC聊天：4000（对话场景需要一定长度）
    final maxTokens = switch (scene) {
      AiScene.narrative => 4000,
      AiScene.choice => 1000,
      AiScene.summary => 4000,
      AiScene.npcChat => 4000,
    };
    final result = await r.chatComplete(
      scene: scene,
      prompt: prompt,
      systemPrompt: effectiveSystemPrompt,
      temperature: 0.85,
      maxTokens: maxTokens,
    );
    // 使用 try-catch 保护 token 统计，避免因 API 返回格式异常导致崩溃
    try {
      totalPromptTokens += result.usage.promptTokens;
      totalCompletionTokens += result.usage.completionTokens;
      totalTokens += result.usage.totalTokens;
      lastRoundTokens = result.usage.totalTokens;
      apiCalls++;
      notifyListeners();
    } catch (e) {
      debugPrint('[GameProvider] Token 统计异常(不影响游戏): $e');
    }
    return result;
  }

  // ==================== 解析响应 ====================

  /// 从叙事文本中智能提取分院结果并赋值给 player.house
  /// 带语境判断：只有当文本中出现明确分院动作时才匹配。

  /// 写入存档时附带的扩展字段。
  ///
  /// 之前 quickSave / saveGameNamed / doSave 各写一份这个 Map，字段一多就
  /// 会有人漏写——漏写的字段读档时静默归零，不报错也不崩。合并成一份。
  Map<String, dynamic> _saveExtraData() => {
        'narrative_summary': narrativeSummary,
        'pending_summary': pendingSummary,
        'recent_turns': recentTurns,
        'game_week': gameWeek,
        'last_school_year_start': lastSchoolYearStart,
        'last_round_tokens': lastRoundTokens,
        'api_calls': apiCalls,
        'total_prompt_tokens': totalPromptTokens,
        'total_completion_tokens': totalCompletionTokens,
        'total_tokens': totalTokens,
        // 千回合级结构化长期记忆（永不压缩的纯事实层）
        'long_term_memory': memory.toJson(),

        // ↓↓↓ 每日限额与一次性状态。
        // 这几项以前都不入档，于是「打满 3 场决斗 → 存档 → 读档」又能打 3 场，
        // 禁林、练咒、学咒同理，打赢过的 NPC 读档后可以再打赢一次再拿 +2 好感。
        'daily_activity_count': dailyActivityCount,
        'activity_date': activityDate,
        'last_duel_opponent_id': lastDuelOpponentId,
        'quest_board_ids': questBoardIds,
        'quest_board_week': questBoardWeek,
        'npc_generated_this_school_year': npcGeneratedThisSchoolYear,
        'npc_generation_school_year': npcGenerationSchoolYear,
      };

  /// 统一的存档写入：快速存档 / 命名存档 / 自动存档都走这里。
  @override
  Future<void> writeSave({required String slotId, required String slotName}) async {
    if (player == null) return;
    await saveService.saveGame(
      slotId: slotId,
      player: player!.toJson(),
      worldState: worldState.toJson(),
      npcRegistry: npcRegistry.map((k, v) => MapEntry(k, v.toJson())),
      narrative: currentNarrative,
      choices: choices.map((c) => {'text': c.text, 'action': c.action}).toList(),
      turnCount: turnCount,
      slotName: slotName,
      extraData: _saveExtraData(),
    );
  }

  Future<void> quickSave() async {
    await writeSave(slotId: SaveService.quickSaveSlotId, slotName: '快速存档');
  }

  /// 使用用户自定义名称保存存档（slotId 由名称生成，保证可读且唯一可寻址）
  Future<void> saveGameNamed(String slotName) async {
    final safeName = slotName
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    if (safeName.isEmpty) return;
    await writeSave(slotId: safeName, slotName: safeName);
  }

  /// 把一份存档数据灌回 provider。
  ///
  /// 自动读档（tryAutoLoad）和槽位读档（loadFromSave）必须走同一套逻辑。
  /// 之前 tryAutoLoad 是复制粘贴出来的，漏了两件事：
  ///  1. _migrateSave —— v1 老存档自动加载时月份字段不迁移、time 字段不补全，
  ///     世界时间直接错乱；而手动读同一个存档却是好的。
  ///  2. _runConsistencyChecks —— 损坏的自动存档不会被钳制，可能载入负血值。
  @override
  void applySaveData(Map<String, dynamic> data) {
    final version = data['save_version'] as int? ?? 1;
    _migrateSave(data, version);

    player = Player.fromJson(data['player'] as Map<String, dynamic>);
    worldState = WorldState.fromJson(data['world_state'] as Map<String, dynamic>);
    npcRegistry.clear();
    final npcMap = data['npc_registry'] as Map<String, dynamic>? ?? <String, dynamic>{};
    npcMap.forEach((k, v) {
      npcRegistry[k] = NPC.fromJson(v as Map<String, dynamic>);
    });
    // 在 player/worldState/npc 赋值之后再构建系统提示词（_buildSystemPrompt 会用到）
    systemPrompt = buildSystemPrompt();

    // ====== 会话态字段复位 ======
    // 这些字段以前只被 resetAllState 清（那条路只有「开新游戏」和设置页走），
    // 读档时一个都不动。于是从 A 档切到 B 档，B 档会带着 A 档的：
    // 今日决斗/禁林次数、刚打过的决斗对手、委托板板面、新 NPC 配额……
    // 更隐蔽的是跨天清零用的 activityDate 也是 A 档的，跨天判定直接错乱。
    // 这里统一先清成默认值，再让 extraData 覆盖——存档里有的用存档的，
    // 没有的（老档）就保持「干净开局」，不会串味。
    dailyActivityCount.clear();
    activityDate = '';
    lastDuelOpponentId = null;
    questBoardIds = [];
    questBoardWeek = 0;
    npcGeneratedThisSchoolYear = 0;
    npcGenerationSchoolYear = 0;
    lastTrackedLocation = null;
    turnsAtSameLocation = 0;
    commandResult = null;
    notifications.clear();
    lastAffectionSections.clear();

    // 读档后按当前时钟重新安排每个人的位置。存档里 NPC 带着
    // currentLocation 字段，但老档里它恒为 '霍格沃茨'，刷新一次最稳。
    refreshNpcLocations(npcRegistry.values, worldState.time.hour,
        worldState.time.weekday);

    currentNarrative = data['narrative'] as String? ?? '';
    choices = (data['choices'] as List<dynamic>?)
        ?.map((c) => GameChoice(text: c['text'] as String, action: c['action'] as String))
        .toList() ?? [];
    turnCount = data['turn_count'] as int? ?? 0;
    final extraData = data['extra_data'] as Map<String, dynamic>? ?? {};
    narrativeSummary = extraData['narrative_summary'] as String? ?? '';
    pendingSummary = extraData['pending_summary'] as String? ?? '';
    gameWeek = extraData['game_week'] as int? ?? 1;
    lastSchoolYearStart = extraData['last_school_year_start'] as int? ?? 0;
    lastWeekBucket = worldState.time.absoluteDayIndex ~/ 7;
    lastRoundTokens = extraData['last_round_tokens'] as int? ?? 0;
    apiCalls = extraData['api_calls'] as int? ?? 0;
    totalPromptTokens = extraData['total_prompt_tokens'] as int? ?? 0;
    totalCompletionTokens = extraData['total_completion_tokens'] as int? ?? 0;
    totalTokens = extraData['total_tokens'] as int? ?? 0;
    // 加载千回合级结构化长期记忆
    memory = LongTermMemory.fromJson(
        extraData['long_term_memory'] as Map<String, dynamic>?);

    // 每日限额与一次性状态：老档没有这些键，读到 null 就保持上面清好的默认值
    final savedDaily = extraData['daily_activity_count'] as Map<String, dynamic>?;
    if (savedDaily != null) {
      savedDaily.forEach((k, v) {
        if (v is int) dailyActivityCount[k] = v;
      });
    }
    activityDate = extraData['activity_date'] as String? ?? activityDate;
    lastDuelOpponentId = extraData['last_duel_opponent_id'] as String?;
    questBoardIds = (extraData['quest_board_ids'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        questBoardIds;
    questBoardWeek = extraData['quest_board_week'] as int? ?? questBoardWeek;
    npcGeneratedThisSchoolYear =
        extraData['npc_generated_this_school_year'] as int? ??
            npcGeneratedThisSchoolYear;
    npcGenerationSchoolYear = extraData['npc_generation_school_year'] as int? ??
        npcGenerationSchoolYear;

    recentTurns
      ..clear()
      ..addAll((extraData['recent_turns'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          []);
    if (recentTurns.isEmpty && currentNarrative.isNotEmpty) {
      recentTurns.add(currentNarrative);
    }

    // 完整性兜底：只在空的时候补默认
    if (choices.isEmpty) choices = buildFallbackChoices(currentNarrative);
    if (choices.length > 4) choices = choices.sublist(0, 4);
    if (currentNarrative.isEmpty) currentNarrative = generateFallbackNarrative();

    // 任何读档之后都必须确保 isLoading=false / isInitializing=false，
    // 否则"继续游戏"后会卡住或误触发再次请求
    isLoading = false;
    isInitializing = false;
    error = null;
    loadingStage = '';

    _runConsistencyChecks();
  }

  Future<void> loadFromSave(String slotId) async {
    try {
      final data = await saveService.loadGame(slotId);
      if (data == null) {
        // 存档不存在或已损坏且无备份可回滚：静默 return 会让 UI 毫无反馈（BUG-FIX）
        error = '存档加载失败：存档不存在或已损坏（slot $slotId）';
        notifyListeners();
        return;
      }
      applySaveData(data);
      // _applySaveData 里已经把 isLoading/isInitializing 复位了
      appProvider.setGameStarted(true);
      notifyListeners();
      unawaited(autoSave());
    } catch (e, st) {
      // 解析中途抛异常会留下半截状态（player 已换、npc 已清），必须兜底
      error = '存档加载失败：$e';
      debugPrint('❌ loadFromSave($slotId) failed: $e\n$st');
      notifyListeners();
    }
  }

  void _migrateSave(Map<String, dynamic> data, int version) {
    if (version < 2) {
      final ws = data['world_state'] as Map<String, dynamic>?;
      if (ws != null) {
        const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
        final oldMonth = ws['month'] as String?;
        if (oldMonth != null) {
          final idx = monthNames.indexOf(oldMonth);
          if (idx >= 0) {
            ws['month'] = GameTime.months[idx];
            debugPrint('存档迁移: month "$oldMonth" -> "${ws['month']}"');
          }
        }
        if (!ws.containsKey('time')) {
          debugPrint('存档迁移: 从旧字段推导 time 字段');
          final yearStr = ws['academic_year'] ?? '1991-1992';
          final yearMatch = RegExp(r'^(\d{4})').firstMatch(yearStr.toString());
          final year = yearMatch != null ? int.tryParse(yearMatch.group(1)!) ?? 1991 : 1991;
          final monthIdx = monthNames.indexOf(ws['month'] as String? ?? '') + 1;
          ws['time'] = {
            'year': year,
            'month': monthIdx > 0 ? monthIdx : 9,
            'day': ws['day_of_month'] as int? ?? 1,
            'weekday': 2,
            'hour': 9,
            'minute': 0,
          };
        }
      }
      data['save_version'] = kSaveVersion;
    }
  }

  Future<List<Map<String, dynamic>>> listSaves() async {
    return saveService.listSaves();
  }

  Future<bool> deleteSave(String slotId) async {
    return saveService.deleteSave(slotId);
  }

  /// 导出存档为 JSON 字符串（用于备份/跨设备迁移）
  Future<String?> exportSave(String slotId) async {
    return saveService.exportSave(slotId);
  }

  /// 从 JSON 字符串导入存档，返回新槽 id
  Future<String?> importSave(String jsonString) async {
    return saveService.importSave(jsonString);
  }


  void resetTokenUsage() {
    totalPromptTokens = 0;
    totalCompletionTokens = 0;
    totalTokens = 0;
    apiCalls = 0;
    notifyListeners();
  }

  // ==================== 辅助方法 ====================

  /// 血统 key → 中文名。表本身在 lib/data/blood_status.dart（问卷 UI 共用）。
  String bloodStatusLabel(String status) => bloodStatusLabelOf(status);

  /// 属性 key → 中文名。表本身在 lib/data/attribute_data.dart
  /// （mixin_play 那边的物品加成/宠物训练文案共用同一份）。
  String attrLabel(String key) => attributeLabel(key);

  String termLabel(String term) {
    return {
      'first': '第一学期',
      'second': '第二学期',
      'third': '第三学期',
      'summer': '暑假',
    }[term] ?? term;
  }

  String flowModeLabel(String mode) {
    return {
      'normal': '正常',
      'story': '剧情加速',
      'fast': '快速',
    }[mode] ?? mode;
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
}
