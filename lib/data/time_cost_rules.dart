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

  // ====== 中优先级（明确动作）======
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

/// 默认耗时（所有规则都不匹配时）
const int kDefaultActionMinutes = 15;

int resolveActionCost(String action) {
  final sorted = [...timeCostRules]..sort((a, b) => b.priority.compareTo(a.priority));
  for (final rule in sorted) {
    if (rule.matches(action)) return rule.minutes;
  }
  return kDefaultActionMinutes;
}
