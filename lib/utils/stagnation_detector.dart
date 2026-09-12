class TransitionNode {
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

  /// 在这些时代不触发（eraKey：dumbledore / marauders / first_war /
  /// harry_same / post_war）。用于锚点里写死了某个只在特定年代存在的人物时。
  final List<String> excludedEras;

  /// 按 eraKey 替换 [transitionAnchor] 的文案。
  ///
  /// 开局链上「海格登门接你去对角巷」是 1991 年的经典桥段，但海格 1928 年
  /// 才出生——1892 和 1971 时代他会凭空出现。这里给那些时代换一个
  /// 当时确实在世的引导者。没列出的时代仍用默认文案。
  final Map<String, String> eraAnchorOverrides;

  const TransitionNode({
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
    this.excludedEras = const [],
    this.eraAnchorOverrides = const {},
  });

  /// 取这个时代该用的锚点文案。
  String anchorFor(String eraKey) =>
      eraAnchorOverrides[eraKey] ?? transitionAnchor;
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
    // 注意别把「——」「正在」「突然」「刚」这类高频标点/副词算作未决钩子：
    // 中文叙事几乎必然命中，hasUnresolvedHook 恒为 true，
    // 会让下面的「⚠️强制推进」永远发不出去，停滞兜底形同虚设。
    final re = RegExp(
      r'(\.\.\.|……)'
      r'|(刚想|刚要|正要|正准备|就在这时|话音未落|还没来得及|话还没说完|尚未|没等|未等)'
      r'|(看着你.*(回答|回应|开口)|等你(回答|回应|开口|出招)|点名叫|点了.*的名|注视着你|等你说话)'
      r'|(举起.*魔杖|瞄准|对峙|剑拔弩张|一触即发|准备迎战|严阵以待|蓄势待发)'
      r'|(分院帽.*(碰到|落下|停住|思考)|(考试|测验|仪式|宴会).(正在|进行中|刚刚开始|开始了))'
      r'|(门.*敲响|敲门声|有人敲门|脚步声.*临近|声音从.*传来)',
      caseSensitive: false,
    );
    return re.hasMatch(tail);
  }

  /// 判定当前该发哪一档推进提示。
  ///
  /// 判定逻辑曾经有三份，而且已经漂移了：
  ///
  /// * `mixin_narrative` 里内联一份，只认「强制」那一档，开局与"剧情进行中"
  ///   两档在叙事端**根本发不出去**；
  /// * `mixin_response` 里内联一份（给选项生成器），三档齐全，且"剧情进行中"
  ///   提前一回合（`threshold - 1`）就发；
  /// * 本类里的 `buildPromptLine` 一份——写得最完整，却**零调用**。
  ///
  /// 三份并存意味着改一次阈值语义，叙事端和选项端就会给出互相矛盾的指令。
  /// 这里收敛成唯一的判定入口，取三份里最合理的语序与时机
  /// （沿用选项端的：开局提示不等阈值、"剧情进行中"提前一回合）；
  /// 措辞仍由各端自己组织——叙事 AI 要的是"本回合必须转换场景"，
  /// 选项 AI 要的是"必须生成至少 2 个离开的选项"，本来就不该共用一句话。
  StagnationLevel evaluate({
    required String currentLocation,
    required int turnsAtSameLocation,
    required bool hasUnresolvedHook,
    required int turnCount,
  }) {
    final threshold = thresholdFor(currentLocation);
    final stuck = turnsAtSameLocation >= threshold;

    // 「有未决钩子就不强制推进」这条规则有个致命副作用：上面的钩子正则
    // 在中文叙事里的命中率极高（「刚想」「就在这时」「注视着你」几乎每段都有），
    // 于是 hasUnresolvedHook 恒为 true，forced 这一档永远走不到——
    // 玩家在图书馆连着五六回合翻书、思考、又翻书，强制推进指令一次也没发过。
    //
    // 给未决钩子一个"宽限额度"：停留达到阈值 2 倍时，不管还有没有悬念
    // 都强制推进。钩子本来就是一回合的事，卡两倍时长还收不了尾，
    // 说明 AI 一直在原地打转。
    final severelyStuck = turnsAtSameLocation >= threshold * 2;

    if (severelyStuck || (stuck && !hasUnresolvedHook)) {
      return StagnationLevel.forced;
    }

    if (turnCount >= 1 &&
        turnCount <= 3 &&
        (currentLocation.isEmpty || isHome(currentLocation))) {
      return StagnationLevel.earlyGame;
    }

    // 剧情正在推进（有未决钩子）：提前一回合给软提示，别等真停滞了才说
    if (hasUnresolvedHook && turnsAtSameLocation >= threshold - 1) {
      return StagnationLevel.inProgress;
    }
    return StagnationLevel.none;
  }

  /// 开局"家里/卧室"这类必须尽快离开的地点。
  bool isHome(String location) =>
      location.isEmpty ? true : homeKeywords.any((k) => location.contains(k));

  /// 「重要剧情场景」到达上限时的补充说明（豁免地点专用）。
  String exemptHint(String currentLocation) {
    final threshold = thresholdFor(currentLocation);
    return isExempt(currentLocation)
        ? '（注：你所在的「$currentLocation」是重要剧情场景，通常允许$threshold回合停留；'
            '现已达到上限，必须在下一阶段自然转换。）'
        : '';
  }
}

/// 推进提示的档位，由 [StagnationDetector.evaluate] 判定。
enum StagnationLevel {
  /// 无需提示
  none,

  /// 📌 开局前 3 回合在家里：该出门了
  earlyGame,

  /// 💡 叙事末尾有未决钩子：承接悬念，但别全员原地打转
  inProgress,

  /// ⚠️ 已停滞：本回合必须转换场景
  forced,
}
