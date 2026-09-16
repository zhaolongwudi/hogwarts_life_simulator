/// P0-一致性幻觉成本 · 正向约束数据层（生成前约束，而非事后打回）。
///
/// 背景：现在 warn 级违规只回喂给「选项 AI」（mixin_response），叙事 AI 下回合
/// 完全看不到自己上回合犯过什么错，同类违和每回合重犯，只能靠 20+ 层事后补丁
/// （看门狗/衔接桥/地点对账）拦。这里把两类「正向约束」前置到生成前：
///   1) 上一回合 warn 违规的温和反馈（数据驱动：读 worldState.consistencyViolations）；
///   2) 基于当前世界状态的动态铁律（月份/年级/主角身份 → 本回合硬禁止项）。
/// 纯函数，便于单测；mixin 侧只负责喂入当前状态并拼接文本。

/// 基于当前状态动态生成「本回合铁律」条目。
///
/// 只输出与当前状态相关的禁止项，避免静态铁律被 AI 当样板忽略。
List<String> narrativeForwardRules({
  required int month,
  required bool graduated,
  required int grade,
  required bool isHarry,
}) {
  final rules = <String>[];

  // R2：学期内月份严禁「学年结束/放暑假」（学年 6 月才结束，与看门狗同口径）
  if ([9, 10, 11, 12, 1, 2, 3, 4, 5].contains(month) && !graduated) {
    rules.add(
      '当前为 $month 月（学期内），严禁出现「学年结束/放暑假/期末考结束/'
      '离校回家/年终宴会」等学年收尾剧情——本学年要到 6 月才结束。',
    );
  }

  // R5：一年级战力/知识防膨胀（与看门狗 R5 同口径）
  if (grade <= 1) {
    rules.add(
      '当前一年级：严禁使用或成功释放守护神咒/呼神护卫、夺魂咒、钻心咒、'
      '杀戮咒等超纲魔法，严禁提及魂器/死亡圣器等一年级不可能知晓的秘密。',
    );
  }

  // R3c：原创主角 ≠ 哈利，禁止套用德思礼设定（与看门狗 R3c 同口径）
  if (!isHarry) {
    rules.add(
      '家人请一律写作「养母/养父/妈妈/爸爸」或原创姓名，严禁套用德思礼一家'
      '（弗农/佩妮/达力）与「女贞路4号」——那是哈利·波特专属设定。',
    );
  }

  return rules;
}

/// 把上一回合 warn 级违规转成温和反馈行（最多 2 条，供叙事 AI 生成前自省）。
/// [currentTurn] 当前回合号：只反馈「上一回合」（turn == currentTurn-1）新增的
/// 违规——历史旧违规（如早期回合的「战力膨胀」）不得每回合重复注入污染
/// prompt（AI 会困惑"我明明没写，为什么说我写了"）；同一条按 message 去重。
List<String> prevWarnFeedbackLines(
  List<Map<String, dynamic>> violations, {
  required int currentTurn,
}) {
  final seen = <String>{};
  final out = <String>[];
  for (final v in violations) {
    if (v['severity'] != 'warn') continue;
    final turn = v['turn'];
    // 无 turn 字段的旧记录（历史存档）视为不满足时效，直接跳过；
    // 有 turn 则必须恰为上一回合
    if (turn is! int || turn != currentTurn - 1) continue;
    final msg = v['message'] as String? ?? '';
    if (msg.isEmpty || !seen.add(msg)) continue;
    out.add('• $msg');
    if (out.length >= 2) break;
  }
  return out;
}
