class _TransitionNode {
  final String id;
  final String currentLocationPattern;
  final List<String> requireVisited;
  final List<String> requireNotVisited;
  final int minTurn;
  final int maxTurn;
  final int? minDateInt; // 月份*100+日，901=9月1日。null=不限制
  final String? requireOpeningScene; // 'letter' 或 null
  final bool requireGraded;
  final bool requireUngraded;
  final String transitionAnchor; // 必须写入 prompt，让 AI 补完整段过渡
  final String? nextLocation;
  final bool? forceNextOnlyIfAnchorPresented; // true=等 AI 把过渡叙事写完后自然同步 location，不在这硬切

  const _TransitionNode({
    required this.id,
    required this.currentLocationPattern,
    this.requireVisited = const [],
    this.requireNotVisited = const [],
    required this.minTurn,
    required this.maxTurn,
    this.minDateInt,
    this.requireOpeningScene,
    this.requireGraded = false,
    this.requireUngraded = false,
    required this.transitionAnchor,
    this.nextLocation,
    this.forceNextOnlyIfAnchorPresented,
  });
}

/// 封装后的"剧情停滞检测器"。
///
/// 宏观设计要点：
/// - 所有阈值/关键词/钩子都集中在这里，避免 mixin_narrative.dart 里到处 if；
/// - 对外暴露 4 个查询 API：isExempt / thresholdFor / hasUnresolvedHook / buildPromptLine；
/// - 所有 API 都是纯函数（参数 location/narrative/turnCount），不需要持有 GameProvider 引用，
///   因而未来能直接做单测。
class StagnationDetector {
  const StagnationDetector._();
  static const StagnationDetector instance = StagnationDetector._();

  // 【豁免地点】：这些场景本身就是"要多回合演剧情"的，阈值放 6 回合，避免把正在进行的
  // 上课/分院/购魔杖/图书馆查资料/魁地奇训练等硬打断。
  static const List<String> exemptLocationKeywords = [
    '大礼堂',
    '教室',
    '图书馆',
    '对角巷',
    '霍格莫德村',
    '公共休息室',
    '禁林',
    '医疗翼',
    '霍格沃茨·场地',
    '魁地奇',
    '决斗',
  ];

  // 【开局强压地点关键词】：开局家里 2 回合必须出门，防止墨迹
  static const List<String> homeKeywords = [
    '家中', '卧室', '住宅', '庄园', '别墅', '家里', '客厅', '门厅', '书房', '花园',
  ];

  bool isExempt(String location) {
    if (location.isEmpty) return false;
    return exemptLocationKeywords.any((k) => location.contains(k));
  }

  int thresholdFor(String location) {
    if (location.isEmpty) return 2;
    if (homeKeywords.any((k) => location.contains(k))) return 2;
    if (isExempt(location)) return 6;
    return 4;
  }

  bool hasUnresolvedHook(String narrative) {
    if (narrative.isEmpty) return false;
    final tail = narrative.length > 200
        ? narrative.substring(narrative.length - 200)
        : narrative;
    final re = RegExp(
      r'(\.\.\.|……|——|—\s*$)'
      r'|(刚|正要|正准备|突然|就在这时|正在|即将|尚未|还没|没等|未等)'
      r'|(看着你.*(回答|回应|开口)|等你(回答|回应|开口|出招)|点名叫|点了.*的名|注视着你|等你说话)'
      r'|(举起.*魔杖|瞄准|对峙|剑拔弩张|一触即发|准备迎战|严阵以待|蓄势待发)'
      r'|(分院帽.*(碰到|落下|停住|思考)|(考试|测验|仪式|宴会).(正在|进行中|刚刚开始|开始了))'
      r'|(门.*敲响|敲门声|有人敲门|脚步声.*临近|声音从.*传来)',
      caseSensitive: false,
    );
    return re.hasMatch(tail);
  }

  /// 统一输出"停滞强制推进提示"文案（之前散落在 buildPrompt 里）。
  /// return 为空字符串代表不需要强制推进。
  String buildPromptLine({
    required String currentLocation,
    required int turnsAtSameLocation,
    required bool hasUnresolvedHook,
    required int turnCount,
  }) {
    final threshold = thresholdFor(currentLocation);
    if (turnsAtSameLocation < threshold) return '';
    if (hasUnresolvedHook) return '';

    final stuckTurns = turnsAtSameLocation;
    final isExempt_ = isExempt(currentLocation);
    final extraHint = isExempt_
        ? '（注：你所在的「$currentLocation」是重要剧情场景，通常允许$threshold回合停留；现已达到上限，必须在下一阶段自然转换。）'
        : '';
    final earlyGame = (turnCount <= 3 && turnCount >= 1 &&
        (currentLocation.contains('家中') ||
            currentLocation.contains('卧室') ||
            currentLocation.isEmpty));
    String line;
    if (earlyGame) {
      line = '📌 【开局前3回合】：属于「收到信→准备出发」阶段，选项中必须至少包含1个"准备出发/前往九又四分之三站台"的推进型选项，避免玩家一直在家里反复施法徘徊。';
    } else if (hasUnresolvedHook && turnsAtSameLocation >= (threshold - 1)) {
      line = '💡 【剧情进行中】当前叙事结尾有未解决的冲突/悬念，选项优先承接「把当前这个悬念/冲突收尾」的动作；但至少要保证有1个选项带"场景转换趋势"（如"把这件事做完后前往下个地点"），不要所有选项都彻底原地打转。';
    } else {
      line = '【⚠️强制推进指令】玩家已在「$currentLocation」停留 $stuckTurns 回合（该场景允许阈值=$threshold），剧情已停滞！'
          '本回合必须发生场景转换——例如：有人敲门通知该出发、时间到了必须动身前往下一站、'
          '收到猫头鹰信件催促、窗外发生引人注意的事件、被召唤去某处等。$extraHint'
          '严禁继续在「$currentLocation」原地打转、反复施法、反复探索同一现象。'
          '本回合结尾必须让玩家处于「正在前往/即将到达下一场景」的状态。';
    }
    return line + '\n\n';
  }
}
