/// 核心系统模型：时间系统、好感度、声望、恋爱、收藏、成就、信件、舆论
/// 依据设定文档第九、十一、十二、十三、十五部分。

import '../data/balance_constants.dart';

// ==================== 时间系统 ====================

/// 时段：晨间/上午/午间/下午/黄昏/晚间/深夜
class TimePeriod {
  static const List<String> periods = [
    '晨间',
    '上午',
    '午间',
    '下午',
    '黄昏',
    '晚间',
    '深夜',
  ];

  static String label(int index) {
    if (index < 0 || index >= periods.length) return '上午';
    return periods[index];
  }

  /// 根据当前时刻返回对应时段
  static int fromHour(int hour) {
    if (hour < 6) return 6; // 深夜
    if (hour < 9) return 0; // 晨间
    if (hour < 12) return 1; // 上午
    if (hour < 14) return 2; // 午间
    if (hour < 17) return 3; // 下午
    if (hour < 19) return 4; // 黄昏
    if (hour < 23) return 5; // 晚间
    return 6; // 深夜
  }
}

/// 时间戳：📅 [年份]年[月]月[日]日，[星期X]，[时段] [时:分]
class GameTime {
  int year;
  int month; // 1-12
  int day;
  int hour;
  int minute;
  int weekday; // 0=周日 1=周一 ...

  GameTime({
    this.year = 1991,
    this.month = 9,
    this.day = 1,
    this.hour = 9,
    this.minute = 0,
    int? weekday,
  }) : weekday = weekday ?? _weekdayFor(year, month, day);

  static const List<String> weekdays = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
  static const List<String> months = [
    '一月', '二月', '三月', '四月', '五月', '六月',
    '七月', '八月', '九月', '十月', '十一月', '十二月'
  ];

  /// 蔡勒公式计算星期（适用于格里高利历）
  static int _weekdayFor(int y, int m, int d) {
    if (m < 3) {
      m += 12;
      y -= 1;
    }
    final k = y % 100;
    final j = y ~/ 100;
    final h = (d + 13 * (m + 1) ~/ 5 + k + k ~/ 4 + j ~/ 4 + 5 * j) % 7;
    return (h + 5) % 7;
  }

  String get periodLabel => TimePeriod.label(TimePeriod.fromHour(hour));

  /// 一年中的第几天（用于计算暧昧持续时间等）
  int get dayOfYear {
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    int total = day;
    for (int m = 1; m < month; m++) {
      total += days[m - 1];
    }
    // 闰年修正
    if (month > 2 && _isLeapYear(year)) total += 1;
    return total;
  }

  /// 自 1991-01-01 起的绝对天数。
  /// 与 WorldEventRecord._estimateAbsoluteDay 保持一致，用于世界事件新鲜度衰减。
  int get absoluteDayIndex => (year - 1991) * 365 + dayOfYear;

  /// 格式化时间戳
  String format() {
    final datePart = '📅 $year年$month月$day日，${weekdays[weekday]}，$periodLabel $hour:${minute.toString().padLeft(2, '0')}';
    return datePart;
  }

  /// 仅格式化时间部分（小时:分钟）
  String get formattedTime => '$hour:${minute.toString().padLeft(2, '0')}';

  /// 简略日期
  String formatDate() => '$year年$month月$day日';

  /// 推进指定分钟
  void advanceMinutes(int minutes) {
    minute += minutes;
    while (minute >= 60) {
      minute -= 60;
      hour += 1;
      if (hour >= 24) {
        hour -= 24;
        _advanceDay();
      }
    }
  }

  void advanceHours(int hours) => advanceMinutes(hours * 60);

  void _advanceDay() {
    day += 1;
    weekday = (weekday + 1) % 7;
    final daysInMonth = _daysInMonth(year, month);
    if (day > daysInMonth) {
      day = 1;
      month += 1;
      if (month > 12) {
        month = 1;
        year += 1;
      }
    }
  }

  int _daysInMonth(int y, int m) {
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (m == 2 && _isLeapYear(y)) return 29;
    return days[m - 1];
  }

  bool _isLeapYear(int y) =>
      (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

  /// 满月判断（简化：以每月十五日为满月）
  bool get isFullMoon => day == 15;

  /// 学期判断：9月-6月为在校期间
  bool get isSchoolTerm => month >= 9 || month <= 6;

  Map<String, dynamic> toJson() => {
        'year': year,
        'month': month,
        'day': day,
        'hour': hour,
        'minute': minute,
        'weekday': weekday,
      };

  factory GameTime.fromJson(Map<String, dynamic> json) => GameTime(
        year: json['year'] ?? 1991,
        month: json['month'] ?? 9,
        day: json['day'] ?? 1,
        hour: json['hour'] ?? 9,
        minute: json['minute'] ?? 0,
        weekday: json['weekday'],
      );
}

/// 行动时间消耗（设定 9.4）
class ActionTimeCost {
  static const Map<String, int> costs = {
    '简短对话': 10,
    '一堂课': 90,
    '一餐': 30,
    '图书馆自习': 120,
    '魁地奇训练': 120,
    '霍格莫德一日游': 300,
    '禁林探索': 180,
    '一夜睡眠': 480,
  };
}

// ==================== 好感度系统 ====================

/// 好感度阶段（设定 11.1）
class AffectionStage {
  final String label;
  final String description;
  final int min;
  final int max;

  const AffectionStage({
    required this.label,
    required this.description,
    required this.min,
    required this.max,
  });
}

const List<AffectionStage> affectionStages = [
  AffectionStage(label: '死敌', description: '对方主动攻击、陷害', min: -100, max: -81),
  AffectionStage(label: '宿怨', description: '回避接触、公开贬低', min: -80, max: -51),
  AffectionStage(label: '反感', description: '冷淡回应、拒绝帮助', min: -50, max: -21),
  AffectionStage(label: '冷漠', description: '敷衍回应、目光掠过', min: -20, max: -10),
  AffectionStage(label: '中立', description: '正常社交、礼貌回应', min: -9, max: 9),
  AffectionStage(label: '好感', description: '主动打招呼、记住名字', min: 10, max: 29),
  AffectionStage(label: '友好', description: '邀请共餐、主动交谈', min: 30, max: 49),
  AffectionStage(label: '信任', description: '分享心事、主动保护', min: 50, max: 69),
  AffectionStage(label: '亲密', description: '暧昧剧情、独处', min: 70, max: 84),
  AffectionStage(label: '深爱', description: '表白、共享秘密', min: 85, max: 94),
  AffectionStage(label: '灵魂伴侣', description: '专属CG、心灵感应', min: 95, max: 100),
];

String affectionStageFor(int level) {
  for (final s in affectionStages) {
    if (level >= s.min && level <= s.max) return s.label;
  }
  return level > 100 ? '灵魂伴侣' : '死敌';
}

/// 好感度变化规则（设定 11.2）
class AffectionChange {
  final String type;
  final int min;
  final int max;
  const AffectionChange(this.type, this.min, this.max);
}

const List<AffectionChange> affectionChangeRules = [
  AffectionChange('日常对话（友好）', 1, 2),
  AffectionChange('日常对话（冲突）', -3, -1),
  AffectionChange('赠送礼物（一般）', 1, 3),
  AffectionChange('赠送礼物（喜欢）', 5, 8),
  AffectionChange('赠送礼物（挚爱）', 10, 15),
  AffectionChange('中等事件（帮助/共同冒险）', 4, 8),
  AffectionChange('重大事件（救命之恩）', 10, 20),
  AffectionChange('极端事件（生死与共）', 20, 30),
  AffectionChange('背叛/欺骗', -30, -15),
];

/// 好感锁机制（设定 11.3）
class AffectionLock {
  final String name;
  final int threshold;
  final String unlockCondition;
  final bool unlocked;

  const AffectionLock({
    required this.name,
    required this.threshold,
    required this.unlockCondition,
    this.unlocked = false,
  });
}

// ==================== 声望系统 ====================

/// 声望维度（设定 13.1）
class Reputation {
  int academic; // 学术声望
  int social; // 社交声望
  int combat; // 战斗声望
  int moral; // 道德声望
  int leadership; // 领导声望
  int dark; // 黑魔法声望

  Reputation({
    this.academic = 0,
    this.social = 0,
    this.combat = 0,
    this.moral = 0,
    this.leadership = 0,
    this.dark = 0,
  });

  static const List<String> dimensions = ['academic', 'social', 'combat', 'moral', 'leadership', 'dark'];

  String labelOf(String dim) {
    return {
      'academic': '学术声望',
      'social': '社交声望',
      'combat': '战斗声望',
      'moral': '道德声望',
      'leadership': '领导声望',
      'dark': '黑魔法声望',
    }[dim] ?? dim;
  }

  int get(String dim) {
    switch (_normalize(dim)) {
      case 'academic':
        return academic;
      case 'social':
        return social;
      case 'combat':
        return combat;
      case 'moral':
        return moral;
      case 'leadership':
        return leadership;
      case 'dark':
        return dark;
    }
    return 0;
  }

  void add(String dim, int value) {
    switch (_normalize(dim)) {
      case 'academic':
        academic = _clamp(academic + value);
        break;
      case 'social':
        social = _clamp(social + value);
        break;
      case 'combat':
        combat = _clamp(combat + value);
        break;
      case 'moral':
        moral = _clamp(moral + value);
        break;
      case 'leadership':
        leadership = _clamp(leadership + value);
        break;
      case 'dark':
        dark = _clamp(dark + value);
        break;
    }
  }

  void setValue(String dim, int value) {
    switch (_normalize(dim)) {
      case 'academic':
        academic = _clamp(value);
        break;
      case 'social':
        social = _clamp(value);
        break;
      case 'combat':
        combat = _clamp(value);
        break;
      case 'moral':
        moral = _clamp(value);
        break;
      case 'leadership':
        leadership = _clamp(value);
        break;
      case 'dark':
        dark = _clamp(value);
        break;
    }
  }

  /// 兼容中文标签与英文键名
  String _normalize(String dim) {
    const map = {
      '学术声望': 'academic',
      'academic': 'academic',
      '学术': 'academic',
      '社交声望': 'social',
      'social': 'social',
      '社交': 'social',
      '战斗声望': 'combat',
      'combat': 'combat',
      '战斗': 'combat',
      '道德声望': 'moral',
      'moral': 'moral',
      '道德': 'moral',
      '领导声望': 'leadership',
      'leadership': 'leadership',
      '领导': 'leadership',
      '黑魔法声望': 'dark',
      'dark': 'dark',
      '黑魔法': 'dark',
    };
    return map[dim.trim()] ?? dim;
  }

  int _clamp(int v) => v.clamp(0, 100);

  Map<String, dynamic> toJson() => {
        'academic': academic,
        'social': social,
        'combat': combat,
        'moral': moral,
        'leadership': leadership,
        'dark': dark,
      };

  factory Reputation.fromJson(Map<String, dynamic> json) => Reputation(
        academic: json['academic'] ?? 0,
        social: json['social'] ?? 0,
        combat: json['combat'] ?? 0,
        moral: json['moral'] ?? 0,
        leadership: json['leadership'] ?? 0,
        dark: json['dark'] ?? 0,
      );
}

/// 声望等级（设定 13.2）
String reputationGrade(int value) {
  if (value >= 90) return '传奇';
  if (value >= 70) return '卓越';
  if (value >= 50) return '良好';
  if (value >= 30) return '一般';
  if (value >= 10) return '低';
  return '边缘';
}

/// 恋爱声望影响（设定 13.3）
class LoveReputationEffect {
  final String type;
  final int min;
  final int max;
  const LoveReputationEffect(this.type, this.min, this.max);
}

const List<LoveReputationEffect> loveReputationEffects = [
  LoveReputationEffect('同学院恋爱', 2, 5),
  LoveReputationEffect('跨学院恋爱', -5, -3),
  LoveReputationEffect('跨血统恋爱', -10, -5),
  LoveReputationEffect('跨阵营恋爱', -15, -8),
  LoveReputationEffect('师生恋', -25, -15),
];

// ==================== 恋爱状态 ====================

class LoveState {
  String status; // 单身/暧昧/恋爱/订婚/结婚
  String? partnerId;
  String? partnerName;
  bool awaitingConfession; // 是否有NPC正在考虑表白
  String? consideringNpcName;
  final List<Map<String, String>> history;

  // ====== 融合版扩展字段 ======
  final Map<String, int> romanticEventCounts; // 每位NPC的浪漫事件计数
  final Map<String, String> relationshipStages; // 每位NPC的关系阶段与开始时间
  String? currentCrushName; // 当前暧昧对象
  int? crushStartDay; // 暧昧开始日期（用于计算≥2周）

  LoveState({
    this.status = '单身',
    this.partnerId,
    this.partnerName,
    this.awaitingConfession = false,
    this.consideringNpcName,
    List<Map<String, String>>? history,
    Map<String, int>? romanticEventCounts,
    Map<String, String>? relationshipStages,
    this.currentCrushName,
    this.crushStartDay,
  })  : history = List<Map<String, String>>.from(history ?? const []),
        romanticEventCounts = Map<String, int>.from(romanticEventCounts ?? {}),
        relationshipStages = Map<String, String>.from(relationshipStages ?? {});

  Map<String, dynamic> toJson() => {
        'status': status,
        'partner_id': partnerId,
        'partner_name': partnerName,
        'awaiting_confession': awaitingConfession,
        'considering_npc': consideringNpcName,
        'history': history,
        'romantic_event_counts': romanticEventCounts,
        'relationship_stages': relationshipStages,
        'current_crush': currentCrushName,
        'crush_start_day': crushStartDay,
      };

  factory LoveState.fromJson(Map<String, dynamic> json) => LoveState(
        status: json['status'] ?? '单身',
        partnerId: json['partner_id'],
        partnerName: json['partner_name'],
        awaitingConfession: json['awaiting_confession'] ?? false,
        consideringNpcName: json['considering_npc'],
        history: (json['history'] as List<dynamic>? ?? [])
            .map((e) => Map<String, String>.from(e as Map))
            .toList(),
        romanticEventCounts: Map<String, int>.from(
            json['romantic_event_counts'] as Map<String, dynamic>? ?? {},
        ),
        relationshipStages: Map<String, String>.from(
            json['relationship_stages'] as Map<String, dynamic>? ?? {},
        ),
        currentCrushName: json['current_crush'],
        crushStartDay: json['crush_start_day'] as int?,
      );

  // ====== 融合版方法 ======

  /// 记录一次浪漫事件
  void recordRomanticEvent(String npcName) {
    romanticEventCounts[npcName] = (romanticEventCounts[npcName] ?? 0) + 1;
  }

  /// 获取某NPC的浪漫事件计数
  int romanticEventsFor(String npcName) => romanticEventCounts[npcName] ?? 0;

  /// 获取某NPC的关系阶段
  String stageFor(String npcName) => relationshipStages[npcName] ?? '陌生';

  /// 设置某NPC的关系阶段
  void setStage(String npcName, String stage, {int? currentDay}) {
    relationshipStages[npcName] = stage;
    if (stage == '暧昧' && currentDay != null && currentCrushName != npcName) {
      currentCrushName = npcName;
      crushStartDay = currentDay;
    }
  }

  /// 检查暧昧是否持续足够时间（≥14天/2周）
  bool isCrushMature(int currentDay) {
    if (currentCrushName == null || crushStartDay == null) return false;
    return currentDay - crushStartDay! >= Balance.confessionCrushMatureDays;
  }
}

// ==================== 收藏与成就 ====================

class CollectionItem {
  final String id;
  final String name;
  final String description;
  final String category;
  final String acquiredDate;

  const CollectionItem({
    required this.id,
    required this.name,
    this.description = '',
    this.category = '一般',
    this.acquiredDate = '',
  });
}

class Achievement {
  final String id;
  final String name;
  final String description;
  final bool unlocked;

  const Achievement({
    required this.id,
    required this.name,
    this.description = '',
    this.unlocked = false,
  });
}

/// 成就定义（本地常量）
const List<Achievement> achievementCatalog = [
  Achievement(id: 'first_letter', name: '猫头鹰的信', description: '收到霍格沃茨录取通知书'),
  Achievement(id: 'sorted', name: '分院仪式', description: '被分院帽分入学院'),
  Achievement(id: 'first_wand', name: '魔杖的选择', description: '在奥利凡德买到魔杖'),
  Achievement(id: 'first_friend', name: '第一位朋友', description: '好感度达到友好'),
  Achievement(id: 'first_confession', name: '月光下的告白', description: '被NPC表白'),
  Achievement(id: 'in_love', name: '恋爱开始', description: '进入恋爱阶段'),
  Achievement(id: 'world_changer', name: '世界线变动者', description: '世界线变动率达到10%'),
  Achievement(id: 'honor_student', name: '优等生', description: '任一技能熟练度达到90'),
  Achievement(id: 'war_hero', name: '战争英雄', description: '参与关键战役'),
  Achievement(id: 'explorer', name: '探索者', description: '访问5个以上不同地点'),
  Achievement(id: 'rich_wizard', name: '小富翁', description: '累计拥有100加隆'),
  Achievement(id: 'bookworm', name: '书虫', description: '学习10个以上魔咒'),
  Achievement(id: 'social_butterfly', name: '社交蝴蝶', description: '认识10个以上NPC'),
  Achievement(id: 'deep_relationship', name: '挚友', description: '与NPC好感度达到80'),
  Achievement(id: 'betrayal_survivor', name: '背叛幸存者', description: '被NPC记仇后仍恢复好感'),
  Achievement(id: 'monthly_evolution', name: '时代见证者', description: '经历3次以上月度世界演化'),
  Achievement(id: 'generation_artist', name: '创作者', description: '生成5位原创NPC'),
  Achievement(id: 'cg_collector', name: '收藏大师', description: '解锁10张以上CG'),
  Achievement(id: 'relationship_master', name: '关系大师', description: '同时与3位NPC保持高好感'),
  Achievement(id: 'time_master', name: '时间行者', description: '游戏内时间推进超过1年'),
  Achievement(id: 'graduated', name: '七年之约', description: '从霍格沃茨毕业'),
  Achievement(id: 'goal_achieved', name: '得偿所愿', description: '毕业时达成人生目标的数值条件'),
  Achievement(id: 'bone_mode', name: '血脉的悖论', description: '开启骨科模式，踏上禁忌之路'),
];

// ==================== 信件 ====================

class Letter {
  final String id;
  final String sender;
  final String content;
  final String date;
  bool read;

  Letter({
    required this.id,
    required this.sender,
    required this.content,
    required this.date,
    this.read = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender': sender,
        'content': content,
        'date': date,
        'read': read,
      };

  factory Letter.fromJson(Map<String, dynamic> json) => Letter(
        id: json['id'],
        sender: json['sender'],
        content: json['content'],
        date: json['date'],
        read: json['read'] ?? false,
      );
}

// ==================== 舆论/传闻 ====================

class Rumor {
  final String id;
  final String text;
  final String spreadAt;
  final String scope; // 学院/全校/魔法界

  const Rumor({
    required this.id,
    required this.text,
    required this.spreadAt,
    this.scope = '全校',
  });
}
