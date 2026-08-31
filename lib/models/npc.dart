import 'game_systems.dart';
import '../data/balance_constants.dart';
import '../data/rivalry_data.dart';

class NPC {
  final String id;
  final String name;
  String house;
  int grade;
  final String bloodStatus;
  final bool isCanon;
  final List<String> aliases;  // 简称/别名列表
  bool isAlive;

  /// 死因。活着的时候是 null。
  ///
  /// 只记叙事里写得出来的死因（决斗、坠落、中毒……），
  /// 认不出就留 null——编一个比不记更糟。
  String? deathCause;

  /// 死亡时的游戏内时间文本。活着的时候是 null。
  String? diedOn;

  final List<String> personality;
  String currentLocation;
  int mood;
  final List<String> knowsAbout;
  String? personalGoal;
  final List<String> lifeLog;
  final Map<String, int> relationships;
  final List<String> recentEvents;

  // ====== 通用 OOC 人设防线（对所有 NPC 生效，不再手写邓布利多/斯内普/马尔福 if） ======
  // forbiddenActions: 与 personality 核心人设正相反的动作/语气短语。
  //   例：温和睿智的邓布利多 -> 暴怒、体罚、刁难学生；阴沉冷漠的斯内普 -> 热情大笑、主动拥抱。
  //   叙事里出现「该 NPC 任一名称（含 aliases/姓氏/名字） + 禁动紧邻（<=15字）」=> 命中 OOC。
  // bloodSupremacist: 纯血至上主义人设标记。对麻瓜出身/混血玩家"热情交好/低声下气" => 命中 OOC。
  final List<String> forbiddenActions;
  final bool bloodSupremacist;

  // ====== 设定文档扩展字段 ======
  final String appearance; // 电影形象外貌描述
  final String gender; // 性别：'男' / '女' / '' = 未知（恋爱取向匹配必需）
  // 非 final：/cheat 配对 性取向 会修改它（作弊功能），重置走玩家档案里的备份。
  String? sexOrientation; // 性取向：被吸引的性别（'男'/'女'/'双性'）
  int affection; // 对玩家的好感度 -100 ~ +100
  final List<String> affectionLocks; // 已解锁的好感锁
  final Map<String, int> giftPrefs; // 礼物偏好: 名称 -> 分值
  final Map<String, String> schedule; // 日程: 时段 -> 活动
  Reputation reputation; // 声望档案
  bool isConsideringConfession; // 是否正在考虑表白
  bool confessed; // 是否已表白
  final bool isGenerated; // 是否为动态生成的新NPC
  String? generatedProfile; // 新NPC完整档案文本

  // ====== 融合版：好感沉淀与记仇机制 ======
  int maxAffectionReached; // 历史最高好感（背叛后不可超越此值）
  final List<Map<String, dynamic>> grudges; // 记仇记录：类型+原因+时间
  int affectionGainedThisWeek; // 本周好感增量（第一周上限+30）
  int affectionGainedThisMonth; // 本月好感增量（第一个月上限+50）
  int affectionMonthKey; // 记录 affectionGainedThisMonth 所属月份（year*12+month），跨月自动重置
  int lastGrudgeDay; // 上次记仇的游戏日

  /// 最后一次好感互动（涨或跌都算）的 absoluteDayIndex。
  ///
  /// 好感维系衰减的 idle 计时起点：连续 [Balance.affectionDriftIdleDays] 天
  /// 没有互动，关系开始自然转淡。-1 = 老存档/从未互动过，按"刚刚互动过"
  /// 处理（豁免本次衰减），否则老存档一加载，所有 NPC 集体转淡——
  /// 玩家什么都没做就被惩罚，这是最差的一种系统惊喜。
  int lastAffectionTouchDay;

  /// 重大事件免疫衰减的起始绝对天数。
  ///
  /// 当一次好感变化触发重大事件免疫（如救命、牺牲、告白等），
  /// 记录当时的 absoluteDayIndex，在 [Balance.majorEventImmunityDays] 天内
  /// 该 NPC 的好感变化不受连续互动衰减影响。
  /// null = 未触发重大事件免疫。
  int? majorEventDate;

  // ====== 宿敌系统（长在 grudges 之上的一层） ======
  // 记仇是流水账，只增不减；宿敌分才是"现在有多恨你"，
  // 可以被时间、被玩家的补救消掉。两者分开，
  // 才能在 UI 上既显示历史旧账、又不让旧账把当下锁死。
  int rivalryRelief; // 玩家补救累计减免的宿敌分
  int reliefGivenDay; // 上次减免的游戏日（防止一天刷白）
  int reliefGivenToday; // 当天已减免量
  bool formerRival; // 曾为宿敌并已和解（叙事彩蛋用）
  int maxRivalryScoreReached; // 历史最高宿敌分：只结过小芥蒂的不算"曾是宿敌"
  /// 累计但尚未结清的怨气。
  ///
  /// 单次好感变化被解析器压在 -5，靠"一次暴跌"永远结不了仇；
  /// 于是改成积少成多——攒够 [kSpiteAccumulateThreshold] 就翻脸。
  int pendingSpite;

  bool introduced; // 是否已经在剧情中登场/被玩家认识
  bool graduated; // 在校生是否已毕业离校

  /// /cheat 固定好感：锁定后好感不随任何系统变动（含衰减/背叛/送礼）。
  /// 作弊项，存档兼容老档（缺省 false）。
  bool affectionLocked;

  NPC({
    required this.id,
    required this.name,
    this.house = '',
    this.grade = 1,
    this.bloodStatus = 'unknown',
    this.isCanon = false,
    this.isAlive = true,
    this.affectionLocked = false,

    /// 死因。活着的时候是 null。
    ///
    /// 只记叙事里写得出来的死因（决斗、坠落、中毒……），
    /// 认不出就留 null——编一个比不记更糟。
    this.deathCause,

    /// 死亡时的游戏内时间文本。活着的时候是 null。
    this.diedOn,
    this.aliases = const [],
    this.personality = const [],
    List<String>? forbiddenActions,
    this.bloodSupremacist = false,
    this.currentLocation = '霍格沃茨',
    this.mood = 50,
    this.knowsAbout = const [],
    this.personalGoal,
    this.lifeLog = const [],
    this.relationships = const {},
    List<String>? recentEvents,
    this.appearance = '',
    this.gender = '',
    this.sexOrientation,
    this.affection = 0,
    List<String>? affectionLocks,
    this.giftPrefs = const {},
    this.schedule = const {},
    Reputation? reputation,
    this.isConsideringConfession = false,
    this.confessed = false,
    this.isGenerated = false,
    this.generatedProfile,
    this.maxAffectionReached = 0,
    List<Map<String, dynamic>>? grudges,
    this.affectionGainedThisWeek = 0,
    this.affectionGainedThisMonth = 0,
    this.affectionMonthKey = 0,
    this.lastGrudgeDay = -1,
    this.lastAffectionTouchDay = -1,
    this.majorEventDate,
    this.rivalryRelief = 0,
    this.reliefGivenDay = -1,
    this.reliefGivenToday = 0,
    this.formerRival = false,
    this.maxRivalryScoreReached = 0,
    this.pendingSpite = 0,
    this.introduced = false,
    this.graduated = false,
  })  : forbiddenActions =
            forbiddenActions ?? _autoDeriveForbiddenActions(personality, name, bloodSupremacist),
        reputation = reputation ?? Reputation(),
        recentEvents = List<String>.from(recentEvents ?? const []),
        affectionLocks = List<String>.from(affectionLocks ?? const []),
        grudges = List<Map<String, dynamic>>.from(
            grudges ?? const <Map<String, dynamic>>[]);

  /// 宏观默认 OOC 禁动推导：根据 personality（核心人设关键词）+ 名字 + 纯血人设标记，
  /// 自动生成"反向动作词"列表，**保证任何新增 NPC 哪怕是动态生成的(isGenerated=true)都不会裸奔无校验**。
  /// 只做"人设正反向反义词"的粗拦截，不做细粒度。详细剧情化 OOC 用 warn 不重写。
  static List<String> _autoDeriveForbiddenActions(
      List<String> personality, String name, bool bloodSupremacist) {
    final pers = personality.join('、');
    final lower = pers.toLowerCase();
    final nameLower = name.toLowerCase();
    final forbidden = <String>{};

    // ---- 通用正反向映射（只要 personality 命中正向词，对应的反向词就进 forbiddenActions）----
    final oppositeMap = <List<String>, List<String>>{
      // 温和组（温和/温柔/慈祥/稳重/睿智/和蔼/亲切/平静）
      // ↓ 关键词：只写**具体的、不易被正面语境触发的**动作。"刻薄/刁难"太宽泛（会匹配"不是刻薄的人"），移除。
      ['温和', '温柔', '慈祥', '睿智', '和蔼', '亲切', '平静', '稳重', '包容']:
          const ['暴怒', '凶狠地', '厉声喝骂', '抽耳光', '体罚', '殴打'],
      // 阴沉/冷漠/刻薄组（斯内普型）
      ['阴沉', '冷漠', '刻薄', '冷淡', '疏离', '毒舌', '古板']:
          const ['满脸笑容地拥抱', '亲热地搂着', '宠溺地摸头'],
      // 友善/开朗/热情组（哈利/罗恩/赫敏普通朋友）
      ['友善', '开朗', '热情', '活泼', '热心', '大方', '外向']:
          const ['厉声喝骂', '恶意陷害', '背后捅刀'],
      // 胆小/羞怯/迟钝组（纳威型）
      ['胆小', '羞怯', '腼腆', '迟钝', '内向', '害羞']:
          const ['大声呵斥别人', '当众斥责'],
      // 高傲/傲慢/自大组（马尔福型）
      ['高傲', '傲慢', '自大', '骄傲', '目中无人', '优越感']:
          const ['低声下气讨好', '谄媚巴结', '卑微哀求'],
      // 忠诚/正直/正义组
      ['忠诚', '正直', '正义', '诚实', '勇敢', '守信']:
          const ['背叛同伴', '恶意欺骗栽赃', '撒谎骗取信任'],
      // 严格/严厉组（麦格/弗立维等教授）
      ['严格', '严厉', '一丝不苟', '公正']:
          const ['故意偏袒', '收受贿赂', '徇私舞弊'],
    };
    oppositeMap.forEach((positives, negatives) {
      if (positives.any((k) => lower.contains(k.toLowerCase()))) {
        forbidden.addAll(negatives);
      }
    });

    // ---- 按名字的原作角色默认兜底（personality 为空时才触发，保证旧档兼容）----
    // 不是写死 if，而是"名字关键词 + personality 为空"→ 补一组默认禁动，动态生成 NPC 不受影响。
    if (personality.isEmpty) {
      if (nameLower.contains('邓布利多') || nameLower.contains('dumbledore')) {
        forbidden.addAll(['暴怒', '凶狠', '刻薄', '刁难', '恶意', '厉声喝骂', '抽耳光', '体罚', '针对学生']);
      } else if (nameLower.contains('斯内普') || nameLower.contains('snape')) {
        forbidden.addAll(['热情地', '亲切地', '笑呵呵', '满脸笑容', '大笑', '拍肩', '主动帮助', '大大夸奖', '温柔地', '宠溺地', '给你一个拥抱', '搂着你']);
      } else if (nameLower.contains('麦格') || nameLower.contains('mcgonagall')) {
        forbidden.addAll(['故意偏袒', '恶意刁难学生', '徇私舞弊']);
      } else if (nameLower.contains('海格') || nameLower.contains('hagrid')) {
        forbidden.addAll(['虐待动物', '故意伤害神奇动物', '出卖学生', '对孩子恶语相向']);
      }
    }

    return forbidden.toList();
  }

  /// 获取所有匹配名称：全名 + 简称 + 自动推导的姓氏
  List<String> get allNames {
    final result = <String>{name};
    result.addAll(aliases);
    
    // 自动推导中文姓氏（"西弗勒斯·斯内普" → "斯内普"）
    if (name.contains('·')) {
      final parts = name.split('·');
      if (parts.length >= 2) {
        result.add(parts.last);  // 姓氏
        result.add(parts.first);  // 名字
      }
    }
    
    // 英文名字推导（"Harry Potter" → "Potter"、"Harry"）
    if (name.contains(' ')) {
      final parts = name.split(' ');
      if (parts.length >= 2) {
        result.add(parts.last);
        result.add(parts.first);
      }
    }
    
    // ---- 防误判黑名单：移除**过度通用的称谓词**（避免"校长/教授/院长/先生/女士"单拿出来匹配到无关剧情文本）----
    const genericTitles = <String>{'校长', '教授', '院长', '先生', '女士', '老师', '主任', '部长', '主席', '队长', '级长'};
    result.removeWhere((n) {
      if (n.length < 2) return true;
      if (genericTitles.contains(n)) return true; // 纯通用词直接剔除
      // 长度 2 的纯中文词如果只是姓氏（如"李""王"）风险低，暂时放行；这里只过滤职位词。
      return false;
    });
    
    return result.toList();
  }
  
  /// 检查某个名字是否与该NPC匹配
  bool nameMatches(String queryName) {
    return nameMatchScore(queryName) > 0;
  }

  /// 返回名称匹配分数（0=不匹配，越大越精确），用于多个候选时选最佳
  int nameMatchScore(String queryName) {
    if (queryName.isEmpty) return 0;
    int bestScore = 0;
    for (final n in allNames) {
      int score = 0;
      if (n == queryName) {
        score = 1000 + n.length * 10;  // 完全匹配，权重最高
      } else if (n.contains(queryName)) {
        score = 100 + queryName.length * 5;  // 别名包含查询词
      } else if (queryName.contains(n)) {
        score = 50 + n.length * 3;  // 查询词包含别名
      } else {
        continue;
      }
      // 对更具体的别名（更长）加分，避免模糊词胜出
      if (aliases.contains(n)) score += 5;
      if (score > bestScore) bestScore = score;
    }
    return bestScore;
  }

  String get affectionStage => affectionStageFor(affection);

  /// 恋爱取向双向兼容性判定。
  ///
  /// 正确语义：取向 = "被吸引的性别"。因此需要**双向**校验：
  ///   1. NPC 的取向包含玩家性别（NPC 喜欢玩家）
  ///   2. 玩家的取向包含 NPC 性别（玩家喜欢 NPC）
  /// '双性' 匹配任意性别；性别或取向未知时不拦截（交给叙事层处理）。
  ///
  /// 旧实现用 `npc.sexOrientation == player.sexOrientation`（取向对取向），
  /// 语义颠倒，导致生成的 NPC 取向被设为玩家取向的"反向"后永远无法通过校验。
  static bool orientationMatches({
    required String npcGender,
    required String? npcOrientation,
    required String playerGender,
    required String? playerOrientation,
  }) {
    bool attracted(String? orientation, String targetGender) {
      if (orientation == null || orientation.isEmpty) return true;
      if (orientation == '双性') return true;
      if (targetGender.isEmpty) return true;
      return orientation == targetGender;
    }

    return attracted(npcOrientation, playerGender) &&
        attracted(playerOrientation, npcGender);
  }

  /// 查询好感锁是否解锁
  bool hasLock(String lockName) => affectionLocks.contains(lockName);

  /// 是否有记仇（好感不可恢复到背叛前水平）
  bool get hasGrudge => grudges.isNotEmpty;

  /// 获取有效好感上限（背叛后不可超越历史最高）
  int get effectiveAffectionCap {
    if (!hasGrudge) return 100;
    return maxAffectionReached > 0 ? maxAffectionReached : 0;
  }

  // ==================== 宿敌系统 ====================

  /// 当前宿敌分。
  ///
  /// 与 [hasGrudge] 的区别：记仇是流水账，只增不减；
  /// 宿敌分是"他现在有多恨你"，会被时间和你的补救消掉。
  int rivalryScore(int currentDay) => rivalryScoreFor(
        grudges,
        currentDay: currentDay,
        relief: rivalryRelief,
        affection: affection,
      );

  /// 当前宿敌等级。
  RivalryTier rivalryTier(int currentDay) => tierForScore(rivalryScore(currentDay));

  /// 宿敌成因的文字概括（取最近一条）。
  String rivalryReason() {
    if (grudges.isEmpty) return '';
    final last = grudges.last;
    return '${last['reason'] ?? '原因不明'}';
  }

  /// 推进宿敌状态：记录峰值，判定化敌为友。
  ///
  /// 每回合调一次。峰值单独存，是因为宿敌分会被时间冲淡——
  /// 不记峰值的话，等玩家真把关系修好，就查不出"他曾经真恨过你"，
  /// 那段化敌为友的叙事彩蛋也就无从谈起。
  bool tickRivalry(int currentDay) {
    final s = rivalryScore(currentDay);
    if (s > maxRivalryScoreReached) maxRivalryScoreReached = s;
    if (formerRival) return false;
    if (canBecomeFormerRival(s, affection, maxRivalryScoreReached)) {
      formerRival = true;
      return true; // 本回合刚和解，调用方负责给一句叙事
    }
    return false;
  }

  /// 记录一次补救，返回实际减免的分数（0 表示当天已刷满）。
  ///
  /// 有每日上限：否则"同一个下午连送十份礼物"就能把死敌洗白，
  /// 宿敌的时间成本就没意义了。
  int applyAmends(int currentDay) {
    if (grudges.isEmpty) return 0;
    if (reliefGivenDay != currentDay) {
      reliefGivenDay = currentDay;
      reliefGivenToday = 0;
    }
    final remain = kMaxReliefPerDay - reliefGivenToday;
    if (remain <= 0) return 0;
    final give = remain < kReliefPerAmends ? remain : kReliefPerAmends;
    reliefGivenToday += give;
    rivalryRelief += give;
    return give;
  }

  /// 添加记仇记录
  /// 上限保护：最多保留最近 10 条（防止反复背叛同一 NPC 导致存档无限膨胀）
  void addGrudge(String type, String reason, int day) {
    grudges.add({
      'type': type,
      'reason': reason,
      'day': day,
      'affection_at_time': affection,
    });
    if (grudges.length > 10) {
      grudges.removeRange(0, grudges.length - 10);
    }
    lastGrudgeDay = day;
  }

  /// 获取好感沉淀修正值
  /// 第1周：受单周上限(+30)与首月上限(+50)双重约束；
  /// 第2~4周：仅受首月上限约束；
  /// 之后：恢复正常（上限100）。
  ///
  /// 注：本方法只依赖 gameWeek 与累计增量，不需要"当前天数"。
  /// 旧签名带有一个从未使用的 currentDay 参数，且调用方分别传
  /// dayOfYear / absoluteDayIndex 两种口径，造成混淆，已移除。
  int getAffectionGainLimit(int gameWeek) {
    int remainingWeek = Balance.affectionMax;
    if (gameWeek <= 1) {
      remainingWeek = Balance.weekOneAffectionCap - affectionGainedThisWeek;
    }
    int remainingMonth = Balance.affectionMax;
    if (gameWeek <= 4) {
      remainingMonth = Balance.monthOneAffectionCap - affectionGainedThisMonth;
    }
    final remaining = remainingWeek < remainingMonth ? remainingWeek : remainingMonth;
    return remaining > 0 ? remaining : 0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'aliases': aliases,
        'house': house,
        'grade': grade,
        'blood_status': bloodStatus,
        'is_canon': isCanon,
        'is_alive': isAlive,
        'death_cause': deathCause,
        'died_on': diedOn,
        'personality': personality,
        'forbidden_actions': forbiddenActions,
        'blood_supremacist': bloodSupremacist,
        'current_location': currentLocation,
        'mood': mood,
        'knows_about': knowsAbout,
        'personal_goal': personalGoal,
        'life_log': lifeLog,
        'relationships': relationships,
        'recent_events': recentEvents,
        'appearance': appearance,
        'gender': gender,
        'sex_orientation': sexOrientation,
        'affection': affection,
        'affection_locks': affectionLocks,
        'gift_prefs': giftPrefs,
        'schedule': schedule,
        'reputation': reputation.toJson(),
        'is_considering_confession': isConsideringConfession,
        'confessed': confessed,
        'is_generated': isGenerated,
        'generated_profile': generatedProfile,
        'max_affection_reached': maxAffectionReached,
        'grudges': grudges,
        'affection_gained_this_week': affectionGainedThisWeek,
        'affection_gained_this_month': affectionGainedThisMonth,
        'affection_month_key': affectionMonthKey,
        'last_grudge_day': lastGrudgeDay,
        'last_affection_touch_day': lastAffectionTouchDay,
        'major_event_date': majorEventDate,
        'rivalry_relief': rivalryRelief,
        'relief_given_day': reliefGivenDay,
        'relief_given_today': reliefGivenToday,
        'former_rival': formerRival,
        'max_rivalry_score_reached': maxRivalryScoreReached,
        'pending_spite': pendingSpite,
        'introduced': introduced,
        'graduated': graduated,
        'affection_locked': affectionLocked,
      };

  factory NPC.fromJson(Map<String, dynamic> json) => NPC(
        id: json['id'],
        name: json['name'],
        aliases: List<String>.from(json['aliases'] ?? []),
        house: json['house'] ?? '',
        grade: json['grade'] ?? 1,
        bloodStatus: json['blood_status'] ?? 'unknown',
        isCanon: json['is_canon'] ?? false,
        isAlive: json['is_alive'] ?? true,
        deathCause: json['death_cause'] as String?,
        diedOn: json['died_on'] as String?,
        personality: List<String>.from(json['personality'] ?? []),
        forbiddenActions: List<String>.from(json['forbidden_actions'] ?? const []),
        bloodSupremacist: json['blood_supremacist'] ?? false,
        currentLocation: json['current_location'] ?? '霍格沃茨',
        mood: json['mood'] ?? 50,
        knowsAbout: List<String>.from(json['knows_about'] ?? []),
        personalGoal: json['personal_goal'],
        lifeLog: List<String>.from(json['life_log'] ?? []),
        relationships: Map<String, int>.from(json['relationships'] ?? {}),
        recentEvents: List<String>.from(json['recent_events'] ?? []),
        appearance: json['appearance'] ?? '',
        gender: json['gender'] ?? '',
        sexOrientation: json['sex_orientation'],
        affection: json['affection'] ?? 0,
        affectionLocks: List<String>.from(json['affection_locks'] ?? []),
        giftPrefs: Map<String, int>.from(json['gift_prefs'] ?? {}),
        schedule: Map<String, String>.from(json['schedule'] ?? {}),
        reputation: Reputation.fromJson(
            Map<String, dynamic>.from(json['reputation'] ?? {})),
        isConsideringConfession: json['is_considering_confession'] ?? false,
        confessed: json['confessed'] ?? false,
        isGenerated: json['is_generated'] ?? false,
        generatedProfile: json['generated_profile'],
        maxAffectionReached: json['max_affection_reached'] ?? 0,
        grudges: List<Map<String, dynamic>>.from(
            (json['grudges'] as List<dynamic>? ?? []).map(
              (e) => Map<String, dynamic>.from(e as Map),
            ),
          ),
        affectionGainedThisWeek: json['affection_gained_this_week'] ?? 0,
        affectionGainedThisMonth: json['affection_gained_this_month'] ?? 0,
        affectionMonthKey: json['affection_month_key'] ?? 0,
        lastGrudgeDay: json['last_grudge_day'] ?? -1,
        // 老存档没有这个键：-1 按"刚刚互动过"豁免衰减（见字段注释）
        lastAffectionTouchDay: json['last_affection_touch_day'] ?? -1,
        // 老存档没有这个键，按 null 处理（从未触发重大事件免疫）
        majorEventDate: json['major_event_date'] as int?,
        // 老存档没有这几个键，读出来按"从没补救过、从没结仇"处理，
        // 宿敌分仍能从 grudges 算出来——不需要迁移脚本。
        rivalryRelief: json['rivalry_relief'] ?? 0,
        reliefGivenDay: json['relief_given_day'] ?? -1,
        reliefGivenToday: json['relief_given_today'] ?? 0,
        formerRival: json['former_rival'] ?? false,
        maxRivalryScoreReached: json['max_rivalry_score_reached'] ?? 0,
        pendingSpite: json['pending_spite'] ?? 0,
        introduced: json['introduced'] ?? false,
        graduated: json['graduated'] ?? false,
        affectionLocked: json['affection_locked'] ?? false,
      );
}
