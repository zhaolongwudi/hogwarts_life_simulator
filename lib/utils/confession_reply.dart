/// 表白回应语义解析（恋爱链路专用）
///
/// 为什么需要独立解析：玩家对表白的回应是**自由文本**，
/// 早先用 `action.contains('接受')` 判断，而中文里
///   「不接受他的表白」「拒绝接受这份感情」
/// 都包含「接受」二字 —— 拒绝会被误判成接受，
/// 恋爱状态机直接反向结算（进入恋爱 + 解锁 CG + 生成交往传闻）。
///
/// 规则：**否定词先于肯定词判断**，且只在能明确判断时返回结果，
/// 无法判断时返回 null（交给 AI 叙事继续推进，不做任何状态改动）。
library;

/// 返回：true = 接受表白 / false = 拒绝表白 / null = 无法判断（不是对表白的回应）
bool? parseConfessionReply(String action) {
  final text = action.trim();
  if (text.isEmpty) return null;

  // 1) 否定优先：含否定语义的回应一律视为拒绝
  //    注意「不接受」「拒绝接受」都含「接受」，必须先在这里拦截。
  const rejectWords = <String>[
    '不接受',
    '不能接受',
    '无法接受',
    '不答应',
    '不愿意',
    '拒绝',
    '婉拒',
    '回绝',
    '不同意',
    '抱歉',
    '对不起',
    '还是朋友',
    '做朋友',
    '当朋友',
    '算了',
  ];
  for (final w in rejectWords) {
    if (text.contains(w)) return false;
  }

  // 2) 肯定
  const acceptWords = <String>[
    '接受',
    '答应',
    '愿意',
    '我也喜欢你',
    '我也爱你',
    '在一起',
    '当然',
    '好啊',
    '好呀',
    '我愿意',
  ];
  for (final w in acceptWords) {
    if (text.contains(w)) return true;
  }

  return null;
}
