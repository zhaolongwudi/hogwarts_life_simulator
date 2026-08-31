/// 行动→耗时映射表（R4：数据化，替代 advanceTimeForAction 硬编码 if 链）
///
/// 每条规则：
///   - patterns：任一匹配成功即命中（区分优先级，priority 高的先尝试）
///   - minutes：对应推进的分钟数
///   - priority：优先级，越大越先匹配（解决「包含关键词冲突」）
class TimeCostRule {
  final List<String> patterns;
  final int minutes;
  final int priority;

  const TimeCostRule({
    required this.patterns,
    required this.minutes,
    this.priority = 0,
  });

  bool matches(String action) => patterns.any(action.contains);
}

const List<TimeCostRule> timeCostRules = [
  // ====== 高优先级（长尾/特殊行为，先匹配以防被通用项先吃掉）======
  TimeCostRule(
    patterns: ['睡觉', '休息', '就寝'],
    minutes: 480,
    priority: 100,
  ),
  TimeCostRule(
    patterns: ['霍格莫德'],
    minutes: 300,
    priority: 90,
  ),
  TimeCostRule(
    patterns: ['禁林'],
    minutes: 180,
    priority: 90,
  ),
  // 决斗是一场正经对抗：一场至少要约场地、行礼、打完收场，
  // 旧实现走的是默认 15 分钟（duelNpc 里传的是'对话'），
  // 导致一回合 10 分钟就能刷一次奖励，经济与声望双双通胀。
  TimeCostRule(
    patterns: ['决斗'],
    minutes: 60,
    priority: 95,
  ),

  // ====== 中优先级（明确动作）======
  // 练一个咒语（/咒语 练习）比上课短、比聊天长：一次 3 遍魔杖挥下来，
  // 一小时是合理的。以前没有这条规则，"练习魔咒"会落到默认 15 分钟，
  // 每天 3 次只花 45 分钟就能把熟练度往上推，学业节奏整个垮掉。
  TimeCostRule(
    patterns: ['练习'],
    minutes: 60,
    priority: 85,
  ),
  TimeCostRule(
    patterns: ['图书馆', '自习', '学习', '看书'],
    minutes: 120,
    priority: 70,
  ),
  TimeCostRule(
    patterns: ['魁地奇', '训练'],
    minutes: 120,
    priority: 70,
  ),
  TimeCostRule(
    patterns: ['上课', '听课', '教室'],
    minutes: 90,
    priority: 60,
  ),
  TimeCostRule(
    patterns: ['吃饭', '用餐', '早餐', '午餐', '晚餐'],
    minutes: 30,
    priority: 50,
  ),
  TimeCostRule(
    patterns: ['探索', '闲逛', '散步'],
    minutes: 60,
    priority: 40,
  ),

  // ====== 低优先级（短互动）======
  TimeCostRule(
    patterns: ['对话', '聊天', '交谈', '打招呼'],
    minutes: 10,
    priority: 10,
  ),
];

/// 默认耗时（所有规则都不匹配时）：15 分钟对自由行动（探索/观察/发愣）太碎，
/// 十回合才过两小时，剧情永远困在同一天。默认提到 30 分钟，
/// 配合上面的场景转移规则（90 分钟），"收到信→出门对角巷"3 回合内可完成。
const int kDefaultActionMinutes = 30;

/// 按优先级降序排好的规则表。排序结果只算一次——原来每次调用
/// resolveActionCost 都要复制一份列表再排一遍。
final List<TimeCostRule> _rulesByPriority = [...timeCostRules]
  ..sort((a, b) => b.priority.compareTo(a.priority));

int resolveActionCost(String action) {
  for (final rule in _rulesByPriority) {
    if (rule.matches(action)) return rule.minutes;
  }
  return kDefaultActionMinutes;
}
