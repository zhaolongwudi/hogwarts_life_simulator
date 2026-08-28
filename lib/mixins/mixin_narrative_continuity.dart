import 'package:flutter/foundation.dart';
import '../providers/game_provider_base.dart';
import '../utils/stagnation_detector.dart';
import '../utils/story_text_renderer.dart';

/// 场景过渡图里的匹配串（currentLocationPattern / requireVisited /
/// requireNotVisited）是**运行时数据**，没法像字面量那样提到 static final
/// 一次性编译；但过渡图扫描是「节点 × 模式 × 已访问列表」的三重循环，
/// 每回合跑一遍就是成百上千次 RegExp 编译。这里按模式串 memo 一下。
final Map<String, RegExp> _loosePatternCache = <String, RegExp>{};

/// 取得忽略大小写的 [pattern] 对应正则，编译结果按 pattern 缓存。
RegExp _loosePattern(String pattern) => _loosePatternCache.putIfAbsent(
      pattern,
      () => RegExp(pattern, caseSensitive: false),
    );

// ===== 人设/断言校验用的固定正则 =====
// 这些原本写在 npcRegistry / lastTurnAssertions 的循环体内部，
// 每校验一个 NPC 或一条断言就重新编译一次。提到外面只编译一次。

/// 命中禁动时的前置否定词：「邓布利多不会暴怒」这种反向说明不算 OOC。
final RegExp _negationPrefixRe =
    RegExp(r'(不|没|并非|从未|从不|不会|不是|何必|何苦)', caseSensitive: false);

/// 严重禁动：命中才把 OOC 从 warn 升级为 critical（打回重写）。
final RegExp _severeForbiddenRe = RegExp(
    r'(体罚|抽.*耳光|殴打|虐待|恶意陷害|栽赃|背叛|收受贿赂|徇私)',
    caseSensitive: false);

/// R4 断言侧：门窗/密室被封死。
final RegExp _lockAssertionRe = RegExp(r'(锁死|封死|封住|挡死|堵死|施了锁门咒)');

/// R4 叙事侧：玩家直接走出去了（没有解锁过渡就走 = 打脸）。
final RegExp _walkedOutRe = RegExp(
    r'(你.*(走出门|推开大门|推开门|推开窗|走出密室|走到大厅|离开房间|下楼))',
    caseSensitive: false);

/// R4 豁免条件：玩家本回合行动里确实做了解锁/破开动作。
final RegExp _unlockActionRe = RegExp(
    r'(解锁|开锁|解开|破开|解除|打开|砸开|敲开|使用开锁咒|阿拉霍洞开|解除封)',
    caseSensitive: false);

/// R4 断言侧：魔杖不在手中。
final RegExp _wandLostAssertionRe =
    RegExp(r'(魔杖.*不在手中|魔杖.*掉在地上|魔杖.*脱手|魔杖.*被缴走)');

/// R4 叙事侧：直接挥杖施法。
final RegExp _castActionRe = RegExp(
    r'(你.*(挥杖|举起魔杖|挥动魔杖|念咒|施了.*咒|施展.*咒))',
    caseSensitive: false);

/// 叙事连续性 Mixin — 从 [GameNarrativeMixin] 中拆分。
///
/// 包含：短期断言系统、连续性桥接（ContinuityBridge）、
/// 叙事一致性校验（ValidateNarrativeConsistency）、
/// 场景过渡图（SceneTransitionGraph）、违禁词检测。
mixin GameNarrativeContinuityMixin on GameProviderBase {
  // ==================== 短期断言系统（Short Assertions）====================

  /// 从本回合叙事正文提取 3~5 条"当前生效中"的状态断言（纯规则关键词版，稳定）。
  /// 存入 worldState.lastTurnAssertions，下回合 prompt 强制注入防止 AI 失忆打脸。
  /// 断言范围：物理状态（门锁/被封）、持有物、位置/姿态、受伤/魔法状态、正发生的关键动作。
  List<String> extractShortAssertions(String narrative) {
    if (narrative.isEmpty) return const [];
    // 只扫末尾 500 字，避免开头过期状态被提回来
    final tail = narrative.length > 500
        ? narrative.substring(narrative.length - 500)
        : narrative;
    final seen = <String>{};
    final result = <String>[];

    void addAssertion(String text) {
      if (text.length < 6) return;
      final key = text.replaceAll(RegExp(r'\s+'), '');
      if (seen.add(key) && result.length < 5) {
        result.add('• $text');
      }
    }

    // ---- 1) 物理封锁/屏障类 ----
    final lockRe = RegExp(
      r'((门窗|大门|房门|窗户|门|窗|密室入口|走廊)[^，。！？]{0,12}(被|已|已经|用.*|以.*)(锁死|封死|封上|封住|加固|上锁|挡死|堵死|施了锁门咒|施展了锁门咒))',
    );
    for (final m in lockRe.allMatches(tail)) {
      addAssertion('${m.group(1)}（玩家行动必须先解锁/破开才能直接通过）');
    }
    // 反过来："锁/封被打开/解除/破坏/破开"要覆盖前面的断言
    final unlockRe = RegExp(
      r'((锁|封|屏障|封印|加固)[^，。！？]{0,12}(被|已|已经|被你)(打开|解开|破开|破坏|解除|击碎|敲碎|摧毁))',
    );
    for (final m in unlockRe.allMatches(tail)) {
      addAssertion('${m.group(1)}（此前的封锁/屏障状态已失效）');
    }

    // ---- 2) 持有/姿态类：手里拿着 XX，魔杖被缴，你躲在 XX ----
    final holdRe = RegExp(
      r'(手里(紧紧)?(攥着|握着|拿着|捏着|握着|举着|提着)[^，。！？]{0,10})',
    );
    for (final m in holdRe.allMatches(tail)) {
      addAssertion('${m.group(1)}');
    }
    final disarmRe = RegExp(
      r'((你的)?魔杖[^，。！？]{0,8}(被击飞|被缴走|脱手|不在手中|丢到了一边|掉在地上))',
    );
    for (final m in disarmRe.allMatches(tail)) {
      addAssertion('${m.group(1)}（本回合若无"捡/拾/召唤"动作，不能直接写魔杖重新回到手中）');
    }
    final hideRe = RegExp(
      r'(你(正)?(躲|藏|蹲|蜷缩)[^，。！？]{0,12}(在|到|进)[^，。！？]{0,14})',
    );
    for (final m in hideRe.allMatches(tail)) {
      addAssertion('${m.group(1)}（若无"走出来/离开"动作，不能直接出现在别的房间）');
    }

    // ---- 3) 受伤/状态类：XX 部位受伤，中了 XX 毒/诅咒，精疲力竭 ----
    final injuryRe = RegExp(
      r'((你的|你)(手臂|腿|肩膀|头|胸口|腹部|背部)[^，。！？]{0,12}(被划伤|被擦伤|出血|剧痛|麻木|骨折|瘀青|中了|中毒|被诅咒|被击中|受伤))',
    );
    for (final m in injuryRe.allMatches(tail)) {
      addAssertion('${m.group(1)}（本回合动作描写要考虑伤势限制）');
    }

    // ---- 4) 关键物件/仪式生效中：分院帽正扣在头上，分院帽在思考 ----
    final hatRe = RegExp(
      r'((分院帽)[^，。！？]{0,10}(扣在|落在|戴在|碰到|触到|停在)[^，。！？]{0,10}|'
      r'(分院帽)[^，。！？]{0,10}(正在思考|在犹豫|沉吟|没说话|没出声))',
    );
    for (final m in hatRe.allMatches(tail)) {
      addAssertion('${m.group(0)}（分院进行中，玩家本回合不应离开大礼堂）');
    }

    // ---- 5) 事件未落地：敲门声刚响起、信刚送到、点名刚叫你 ----
    final knockRe = RegExp(
      r'((敲门声|门[^，。！？]{0,4}被.*敲|有人敲门)[^，。！？]{0,10}(响起|传来|刚落下|刚响))',
    );
    for (final m in knockRe.allMatches(tail)) {
      addAssertion('${m.group(1)}（门外有人，尚未开门。下一动作先回应敲门更自然）');
    }
    final calledRe = RegExp(
      r'((教授|级长|老师|NPC|同学)[^，。！？]{0,6}(点名叫|点了你的名|叫你的名字|喊你|注视着你等你回答))',
    );
    for (final m in calledRe.allMatches(tail)) {
      addAssertion('${m.group(1)}（被点名/提问，优先回应再做别的动作）');
    }

    return result;
  }

  /// 每回合末把断言"滚动一代"：上上回合丢弃，上回合→上次，新提取→本回合。
  void rotateTurnAssertions(List<String> newAssertions) {
    worldState.previousTurnAssertions.clear();
    worldState.previousTurnAssertions.addAll(worldState.lastTurnAssertions);
    worldState.lastTurnAssertions.clear();
    worldState.lastTurnAssertions.addAll(newAssertions);
  }
  // ============================================================
  // 【宏观通用 M3 · ContinuityBridge 全局衔接桥】
  //
  // 目标：**无论触发路径是什么（正常 narrative / CRITICAL 重写 / 用户自定义 action / 兜底叙事）**，
  //       新生成的 narrative 都必须与**上一段剧情的结尾**自然衔接，不允许"刚生成一段没操作就被另一段替换"。
  //
  // Pipeline：
  //   Step A) 每回合叙事结束 → extractContinuityAnchor(prevNarrative)：
  //             从上一段末尾 800 字抓 4 要素: last_speaker / last_dialog / last_action / location
  //             存入 worldState.lastNarrativeAnchor。
  //   Step B) 下回合 buildPrompt 生成前 → buildContinuityBridgePromptLine()：
  //             强制把锚点用"第一句必须承接"的约束注入 Prompt，AI 不可以开新场景。
  //   Step C) parseNarrativeOnly 后 → enforceContinuityBridge(newNarrative)：
  //             正则检查新叙事是否显式呼应锚点（提了同地点/同一说话者/同一未完成动作的后续）。
  //             若不衔接：不打回重写（避免"换剧情"观感），而是在 narrative 开头自动插入一句
  //             "承接过渡句"，把上一段锚点与新叙事的开头软连起来。连续 3 次不衔接 → 给一条通知。
  // ============================================================

  /// Step A：从一段 narrative 的末尾抓衔接锚点，存入 worldState.lastNarrativeAnchor。
  /// 之后所有生成新 narrative 的路径（无论哪种）都会被要求承接。
  void saveContinuityAnchor(String narrative) {
    if (narrative.isEmpty) {
      worldState.lastNarrativeAnchor.clear();
      return;
    }
    // BUG3b 修复·strip承接标记：在抓锚点之前，先清理内部 meta 标记
    // （承接前缀/SceneGraph debug 行），防止锚点被"承接：就在家中·卧室"
    // 这类元文本污染，导致下回合 enforceContinuityBridge 正则误判匹配、
    // 以及衔接桥 prompt 里注入用户可见的「承接：XXX」调试说明。
    final cleanNarrative = StoryTextRenderer.stripInternalMetaMarkers(narrative);
    final tail = cleanNarrative.length > 800 ? cleanNarrative.substring(cleanNarrative.length - 800) : cleanNarrative;
    final anchor = <String, String>{};

    // 1) location
    final loc = worldState.currentLocation;
    if (loc != null && loc.isNotEmpty) anchor['location'] = loc;

    // 2) last_speaker + last_dialog
    final afterQuoteRe = RegExp(
      r'[」"】][^，。！？\n]*?(养母|养父|海格|邓布利多|阿不思|斯内普|西弗勒斯|麦格|米勒娃|哈利|詹姆|波特|罗恩|韦斯莱|赫敏|格兰杰|马尔福|德拉科|纳威|隆巴顿|卢娜|洛夫古德|金妮|弗雷德|乔治|珀西|亚瑟|莫丽|小天狼星|布莱克|卢平|莱姆斯|教授|级长|妈妈|爸爸|同学|NPC)[^，。！？\n]{0,10}(说|开口|问|道|回答|叹了口气|笑了笑|低声|沉声|看着你)',
      caseSensitive: false,
    );
    final aqm = afterQuoteRe.allMatches(tail);
    if (aqm.isNotEmpty) anchor['last_speaker'] = aqm.last.group(1) ?? '';
    final dialogRe = RegExp(r'[「"]([^「"」]{2,40})[」"]', caseSensitive: false);
    final dm = dialogRe.allMatches(tail);
    if (dm.isNotEmpty) anchor['last_dialog'] = dm.last.group(1) ?? '';

    // 3) last_action（最后未完成动作）：正则抓"正/正要/刚/准备/就要/等着/听到敲门声/握着门把手/盯着"等时态
    final hangingRe = RegExp(r'((正要|刚要|准备|就要|等着|正看着|盯着|握着.*把手|听到.*敲门声|敲门声响起|还没|尚未)[^。！？\n]{0,40})');
    final hm = hangingRe.allMatches(tail);
    if (hm.isNotEmpty) {
      anchor['last_action'] = hm.last.group(1) ?? '';
    } else {
      // 兜底：最后一个动作动词
      final genericRe = RegExp(r'((你|你.+)[^。！？\n]{0,30}(站起身|走过去|坐下来|点点头|摇摇头|开口|问|说|笑了笑|叹了口气|伸出手|握住|接过|放下|看向|望向|转身))');
      final gm = genericRe.allMatches(tail);
      if (gm.isNotEmpty) anchor['last_action'] = gm.last.group(1) ?? '';
    }

    worldState.lastNarrativeAnchor.clear();
    worldState.lastNarrativeAnchor.addAll(anchor);
  }

  /// Step B：把衔接桥锚点注入 buildPrompt。返回一段文本，直接拼进【当前场景】后面。
  String buildContinuityBridgePromptLine() {
    final a = worldState.lastNarrativeAnchor;
    if (a.isEmpty) return '';
    final loc = a['location'];
    final sp = a['last_speaker'];
    final dg = a['last_dialog'];
    final ac = a['last_action'];
    if (loc == null && sp == null && ac == null) return '';
    final parts = <String>[];
    if (loc != null && loc.isNotEmpty) parts.add('地点=$loc');
    if (sp != null && sp.isNotEmpty) parts.add('最后说话者=$sp');
    if (dg != null && dg.isNotEmpty) parts.add('最后一句="$dg"');
    if (ac != null && ac.isNotEmpty) parts.add('最后动作/姿态=$ac');
    return '【🔗 衔接桥·必须遵守】\n'
        '上一段剧情结尾的锚点是：${parts.join('｜')}。\n'
        '本回合 narrative 的开头必须**直接承接这一刻**（例如：描写对方说完话后你的反应、继续完成最后那个未完成的动作、从那个地点的状态写起）。\n'
        '严禁毫无过渡地切换到一个不相关的新场景/新话题，严禁"跳过中间 1~2 小时的过程"直接写结果。\n'
        '如果本回合玩家行动确实需要换场景，你也必须先写 1~2 句承接段交代"从那个锚点是怎样过渡到新场景的"，再开始写新场景。\n\n';
  }
  /// Step C：对 AI 新吐出来的 narrative 做衔接校验；若不衔接则在开头自动插入承接句，不打回重写。
  /// 返回最终要存入 currentNarrative 的文本。
  String enforceContinuityBridge(String newNarrative, String playerActionText) {
    final a = worldState.lastNarrativeAnchor;
    if (a.isEmpty) {
      worldState.continuityBridgeMisses = 0;
      return newNarrative;
    }
    if (newNarrative.isEmpty) return newNarrative;

    final loc = a['location'] ?? '';
    final sp = a['last_speaker'] ?? '';
    final ac = a['last_action'] ?? '';
    final head = newNarrative.length > 300 ? newNarrative.substring(0, 300) : newNarrative;

    bool matched = false;
    // 简单判断：新叙事开头 300 字里至少出现锚点其中一个关键词 => 视为已衔接
    final checkHits = [loc, sp, ac]
        .where((e) => e.trim().length >= 2)
        .where((keyword) => head.contains(keyword))
        .toList();
    if (checkHits.isNotEmpty) matched = true;

    // 如果玩家本回合行动本身就是"换场景型动作"（出发/前往/动身/回家/去XX），允许直接写换场景，视为已衔接
    final travelRe = RegExp(r'(前往|出发|动身|去.*(车站|对角巷|大礼堂|特快|霍格沃茨)|回家|返校|走出门|下楼|走进)', caseSensitive: false);
    if (!matched && travelRe.hasMatch(playerActionText)) matched = true;

    if (matched) {
      worldState.continuityBridgeMisses = 0;
      return newNarrative;
    }

    // ---- 不衔接：在开头补一句承接过渡，**绝对不打回重写**（否则就是玩家观感的"换剧情"） ----
    worldState.continuityBridgeMisses += 1;
    final bridgeParts = <String>[];
    if (loc.isNotEmpty) bridgeParts.add('就在$loc');
    if (sp.isNotEmpty) bridgeParts.add('${sp}的话音刚落');
    if (ac.isNotEmpty) bridgeParts.add('你正$ac的那一刻');
    final bridgeSentence = (bridgeParts.isNotEmpty
            ? '（承接：${bridgeParts.join('、')}）'
            : '（承接上一段剧情的结尾）') +
        '—— 紧接着，';
    final repaired = bridgeSentence + newNarrative;

    // 连续 3 次不衔接：给一条通知提醒玩家"模型可能被上下文污染，若持续可新开档"，不报警
    if (worldState.continuityBridgeMisses >= 3) {
      notifications.add('🔗 衔接桥：最近连续${worldState.continuityBridgeMisses}回合叙事衔接偏弱，已自动在开头补承接过渡句。若剧情仍有断裂感，请把 ai_log 贴给作者调参。');
      worldState.continuityBridgeMisses = 0; // 清 0，避免每次都刷屏
    }
    debugPrint('🔗 ContinuityBridge 自动补承接: anchor=$a 插句长度=${bridgeSentence.length}');
    return repaired;
  }
  /// 组装要注入给叙事/选项 AI 的断言 Prompt 块（统一格式，避免两端不一致）
  String buildAssertionsPromptBlock() {
    final last = worldState.lastTurnAssertions;
    final prev = worldState.previousTurnAssertions;
    if (last.isEmpty && prev.isEmpty) return '';
    final buf = StringBuffer();
    if (last.isNotEmpty) {
      buf.writeln('【上回合生效状态·严禁直接打脸】');
      buf.writeln('以下是从上一回合剧情末尾提取的、此时仍应有效的物理/姿态/状态事实。'
          '除非本回合玩家行动里明确写了"解锁/破开/捡起/走出来"等过渡动作，严禁直接跳到相反状态。');
      buf.writeln(last.join('\n'));
      buf.writeln('');
    }
    if (prev.isNotEmpty) {
      buf.writeln('【上上回合状态·参考】');
      buf.writeln('这些状态已过了两回合，可能已经变化，作为参考；若与上回合状态矛盾，以上回合为准。');
      buf.writeln(prev.join('\n'));
      buf.writeln('');
    }
    return buf.toString();
  }
  // ==================== P0-1 一致性看门狗（Validate Narrative Consistency）====================

  /// 对 AI 刚吐出来的叙事做 6 大类硬性校验，命中严重违规时要求重试。
  /// 返回：违规列表（每个违规 {severity: critical/warn, rule: id, message: str, evidence: str}）。
  /// severity=critical → 本次响应当作废，触发重试一次；severity=warn → 记录但不打回，下一回合 prompt 软提醒。
  List<Map<String, dynamic>> validateNarrativeConsistency(String narrative) {
    if (narrative.isEmpty) return const [];
    final p = player;
    final ws = worldState;
    final violations = <Map<String, dynamic>>[];
    final nLower = narrative;

    void addV(String severity, String rule, String message, {String? evidence}) {
      violations.add(<String, dynamic>{
        'severity': severity,
        'rule': rule,
        'message': message,
        if (evidence != null) 'evidence': evidence,
        'at': DateTime.now().toIso8601String(),
      });
    }

    // ---- R1: 时间不倒流。从 narrative 提取📅时间戳与 worldState.time 对比 ----
    final tsMatch = RegExp(r'📅\s*([^\n]+)').firstMatch(narrative);
    if (tsMatch != null && p != null) {
      // 只做粗校验：若旧时间是 7月31日，新叙事不能写 7月30 日或更早的日期
      final oldMonth = ws.time.month;
      final oldDay = ws.time.day;
      final newTxt = tsMatch.group(1) ?? '';
      final nM = RegExp(r'(\d{1,2})\s*月').firstMatch(newTxt);
      final nD = RegExp(r'(\d{1,2})\s*日').firstMatch(newTxt);
      if (nM != null && nD != null) {
        final newMonth = int.tryParse(nM.group(1)!) ?? 0;
        final newDay = int.tryParse(nD.group(1)!) ?? 0;
        if (newMonth > 0 && newDay > 0) {
          bool earlier = false;
          if (newMonth < oldMonth) earlier = true;
          if (newMonth == oldMonth && newDay < oldDay) earlier = true;
          // 同月同日允许（不同时段）；只有更早的日期判倒流
          if (earlier) {
            addV('critical', 'R1_time_regression',
                '时间倒流：当前世界时间 ${ws.timestamp}，叙事却写了 $newTxt，严禁时间倒退。',
                evidence: newTxt);
          }
        }
      }
    }

    // ---- R2: 学年状态自洽：刚入学 grade=1 & 9月开学前 → 不允许"学年结束/放暑假/上学期期末考已结束" ----
    if (p != null && !ws.graduated) {
      final grade = p.grade ?? 0;
      final month = ws.time.month;
      const summerEndedKeywords = [
        '学年结束', '暑假开始', '期末考结束', '学期已经结束', '放暑假了', '离校回家',
        '这一学年告一段落', '学期末尾', '年终宴会',
      ];
      bool contradiction = false;
      if (grade == 1 && month <= 9) {
        contradiction = summerEndedKeywords.any((k) => nLower.contains(k));
      }
      // 通用：月份是开学初(9月)/学期中(10-12/1-5)，不能出现"学年结束暑假开始"
      if ([9, 10, 11, 12, 1, 2, 3, 4, 5].contains(month)) {
        if (summerEndedKeywords.any((k) => nLower.contains(k)) && grade >= 1 && grade <= 7) {
          // 只有月份=6或7才允许写学年结束
          contradiction = true;
        }
      }
      if (contradiction) {
        addV('critical', 'R2_academic_contradiction',
            '学年状态矛盾：玩家 grade=$grade，世界月份=$month月（学期内/刚开学），叙事却写"学年结束/放暑假"等剧情，会造成设定错乱。',
            evidence: 'month=$month grade=$grade');
      }
    }

    // ---- R3: 死人不复活 / 未结识NPC不能熟络对话 ----
    for (final entry in npcRegistry.entries) {
      final npc = entry.value;
      // 死人复活：NPC isAlive=false，但叙事里写了他说话/动作
      if (!npc.isAlive) {
        final actionRe = _loosePattern(
          '${RegExp.escape(npc.name)}[^，。！？]{0,20}(说|笑|走|看|站|伸出|握住|拍|打|喊|叫|望|转身|回答|点头|摇头)',
        );
        if (actionRe.hasMatch(narrative)) {
          addV('critical', 'R3_dead_npc_active',
              '死人复活：NPC「${npc.name}」当前已标记死亡(isAlive=false)，但叙事里仍把他写为活人的动作/说话。',
              evidence: npc.name);
        }
      }
      // 未结识但熟络：introduced=false，不能写"XX笑着拍你肩/跟你熟络聊天/你和XX约定好了"
      if (!npc.introduced) {
        final closeRe = _loosePattern(
          '${RegExp.escape(npc.name)}[^，。！？]{0,20}(笑着|笑了笑|拍.*肩|熟络|亲热|拍.*背|搂着|挽着|跟你.*商量|和你.*约定|早已认识|老朋友)',
        );
        if (closeRe.hasMatch(narrative)) {
          addV('warn', 'R3_npc_introduced_familiar',
              '未结识先熟络：NPC「${npc.name}」尚未正式登场(introduced=false)，叙事里却写了熟络互动，下一回合请先写成陌生人碰面。',
              evidence: npc.name);
        }
      }

      // ============================================================
      // 【宏观通用 R3b 人设防线】替换掉"手写 if(斯内普/邓布利多/马尔福)+各写一份正则"的补丁式实现。
      // 核心：对 npcRegistry 里 ALL NPC（含动态生成的 isGenerated=true）生效，
      //      通过 NPC.allNames（全名/别名/姓氏/名字）× NPC.forbiddenActions 做笛卡尔匹配，
      //      命中「名称+≤15字禁动紧邻」=> OOC。bloodSupremacist 对麻瓜/混血玩家的热情对待另行拦截。
      //
      // 之前"手写 if"的 3 个痛点：
      //   1) 新 NPC/学年 NPC 裸奔，没有人设校验；
      //   2) 每条正则容易写出末尾空分支 `|)`，导致 100% 误判 CRITICAL 触发重写；
      //   3) 每条 severity 写死，剧情化 OOC 直接 CRITICAL→整段换剧情，玩家观感断链。
      // ============================================================
      if (npc.forbiddenActions.isNotEmpty) {
        for (final nameVariant in npc.allNames) {
          if (nameVariant.length < 2) continue;
          // ---- 【防误判·通用称谓保护】----
          // 如果 nameVariant 本身含有"校长/教授/院长"等通用词尾缀（如"邓布利多校长"），
          // 则额外要求：叙事里**必须同时出现该 NPC 的姓氏或全名**，否则判定为"其他人物 + 通用称谓"的误匹配。
          // 例：剧情写"麦格教授说..."，此时仅当叙事里也出现"麦格/米勒娃"，才会对"麦格教授"这个 alias 做OOC校验。
          const genericTitles = ['校长', '教授', '院长', '主任', '老师', '先生', '女士', '级长', '队长'];
          bool isTitledVariant = genericTitles.any((t) => nameVariant.contains(t));
          bool npcIdentityAlsoPresent = true;
          if (isTitledVariant) {
            final identityHints = <String>[
              // 拆分全名的姓氏、名字
              if (npc.name.contains('·')) ...npc.name.split('·'),
              if (npc.name.contains(' ')) ...npc.name.split(' '),
              npc.name,
              // 不含通用词的 aliases（短alias如"老邓"也可作为身份依据）
              ...npc.aliases.where((a) => !genericTitles.any((t) => a.contains(t))),
            ];
            npcIdentityAlsoPresent = identityHints.any((hint) =>
                hint.length >= 2 && nLower.contains(hint.toLowerCase()));
          }
          if (!npcIdentityAlsoPresent) continue;

          // 注意：下面 forbiddenActions.join('|') 由 forbiddenActions 列表项本身组成，
          // 列表项是纯短语（由 NPC._autoDeriveForbiddenActions 产生），不含空串，因此不会出现 `|)` 空分支。
          final joinedFbd = npc.forbiddenActions
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .map(RegExp.escape)
              .join('|');
          if (joinedFbd.isEmpty) continue;
          final oocRe = _loosePattern(
            '${RegExp.escape(nameVariant)}[^，。！？]{0,15}($joinedFbd)',
          );
          if (oocRe.hasMatch(nLower)) {
            // 【熔断】默认降为 warn（软提醒下一回合修正），只有"禁动包含严重暴烈关键词"才升级为 CRITICAL。
            // 另外增加最终保护：命中文本中如果紧邻出现否定词（不/没/并非/从不/不会/不是），则忽略（
            // 避免"邓布利多不会暴怒/并不是刻薄的人"这种反向说明被误判为 OOC）。
            final m = oocRe.firstMatch(nLower);
            final hitVerb = m?.group(1) ?? '';
            final hitStart = m?.start ?? 0;
            final beforeHit = hitStart > 8
                ? nLower.substring(hitStart - 8, hitStart)
                : (hitStart > 0 ? nLower.substring(0, hitStart) : '');
            if (_negationPrefixRe.hasMatch(beforeHit)) {
              debugPrint('[OOC 跳过·否定词前置] ${npc.name}|$nameVariant|$hitVerb 前置="$beforeHit"');
              continue;
            }
            final isSevere = _severeForbiddenRe.hasMatch(hitVerb);
            final sev = isSevere ? 'critical' : 'warn';
            final summary = npc.personality.isNotEmpty
                ? npc.personality.take(3).join('/')
                : '默认人设';
            addV(sev, 'R3b_ooc_generic',
                '人设冲突(${sev == "critical" ? "严重·会打回重写" : "轻微·仅提醒修正"})：NPC「${npc.name}」人设为「$summary」，不应描写为「$nameVariant … $hitVerb」这类与人设正相反的动作。',
                evidence: '${npc.name}|$nameVariant|$hitVerb');
            if (isSevere) {
              break; // 只要有一个严重禁动命中就记录一次 CRITICAL，避免同段剧情多次 CRITICAL 叠加
            }
          }
        }
      }
      // 纯血至上主义 NPC：对麻瓜出身/混血玩家，不能"主动热情交好/低声下气"（通用版马尔福 OOC）
      if (npc.bloodSupremacist) {
        final blood = player?.bloodType ?? '';
        if (blood == 'muggleborn' || blood == 'halfblood') {
          for (final nameVariant in npc.allNames) {
            if (nameVariant.length < 2) continue;
            final oocRe = _loosePattern(
              '${RegExp.escape(nameVariant)}[^，。！？]{0,20}(主动凑过来|亲热地|友好地|亲切地|对你有好感地|低声下气|鞠躬|讨好|巴结|谄媚)',
            );
            if (oocRe.hasMatch(nLower)) {
              addV('warn', 'R3b_ooc_blood_supremacist',
                  '人设冲突：「${npc.name}」为纯血至上主义，对${blood == "muggleborn" ? "麻瓜出身" : "混血"}玩家，不应描写为"主动热情交好/低声下气"。',
                  evidence: '${npc.name}|blood=$blood');
              break;
            }
          }
        }
      }
    }

    // ---- R4: 断言打脸（本回合写的动作直接违反上回合注入的断言）----
    for (final assertion in ws.lastTurnAssertions) {
      // 简单匹配：如果断言里含"(锁死/封死/封住)"且叙事出现"你走出门/推开大门/推开窗/走出密室" → 判打脸
      if (_lockAssertionRe.hasMatch(assertion)) {
        if (_walkedOutRe.hasMatch(narrative)) {
          // 但如果玩家本回合行动里含"解锁/破开/解除/打开"的话，允许
          final playerAction = lastPlayerAction;
          final unlockedByPlayer = _unlockActionRe.hasMatch(playerAction);
          if (!unlockedByPlayer) {
            addV('warn', 'R4_assertion_lock_violation',
                '物理状态打脸：上回合断言提到门窗/密室被封死，但本回合叙事直接写玩家"走出/推开"了（没有任何解锁/破开动作过渡）。',
                evidence: assertion);
          }
        }
      }
      // 断言"魔杖不在手中"，直接写"你挥杖施法"
      if (_wandLostAssertionRe.hasMatch(assertion)) {
        if (_castActionRe.hasMatch(narrative)) {
          addV('warn', 'R4_assertion_wand_violation',
              '状态打脸：上回合断言说魔杖不在手中，本回合直接施法却没有"捡/拾/召唤"动作过渡。',
              evidence: assertion);
        }
      }
    }

    // ---- R5: 魔法资质 / 已学会咒语校验（只拦严重的：一年级放守护神咒/夺魂咒这种）----
    if (p != null) {
      final grade = p.grade ?? 1;
      const tooPowerfulForFirst = [
        '守护神咒', '呼神护卫', 'Expecto Patronum', '夺魂咒', '魂魄出窍', 'Imperius',
        '钻心咒', '钻心剜骨', 'Crucio', '杀戮咒', '阿瓦达索命', 'Avada Kedavra',
        '伏地魔', '魂器', '死亡圣器', '有求必应屋', // 主角预知类（对原住民模式）
      ];
      if (grade <= 1) {
        for (final spell in tooPowerfulForFirst) {
          if (nLower.contains(spell) && !p.learnedSpells.containsKey(spell)) {
            addV('warn', 'R5_spell_power_creep',
                '战力膨胀/剧情预知：一年级新生/主角尚未知道的秘密，本回合叙事直接写了「$spell」的成功释放或预知性互动。',
                evidence: spell);
          }
        }
      }
    }

    // ---- BUG2b R3c: 原创主角≠哈利的家庭设定混淆检测（德思礼/女贞路杂交）----
    if (p != null && p.name.toLowerCase() != '哈利' && !p.name.contains('波特')) {
      // 命中1：好感变化/叙事里直接出现「XX·德思礼」作为玩家养母/养父（如玛吉·德思礼）
      final dursleyFamilyRe = RegExp(
        r'(玛吉|弗农|佩妮|达力)\s*[·.]?\s*德思礼|德思礼\s*(家|一家|夫妇|门口|住宅|姨父|姨妈|表哥)',
        caseSensitive: false,
      );
      final privetDriveRe = RegExp(r'女贞路\s*4\s*号|德文郡.*德思礼', caseSensitive: false);
      if (dursleyFamilyRe.hasMatch(narrative) || privetDriveRe.hasMatch(narrative)) {
        addV('critical', 'R3c_family_not_dursley',
            '家庭设定杂交：主角是原创玩家（非哈利·波特），本回合却出现德思礼一家/女贞路4号等哈利专属的家庭成员和地点。必须把养母/养父称呼为"养母/养父/妈妈/爸爸"或原创姓名，绝不能套用德思礼的姓和住址。',
            evidence: dursleyFamilyRe.stringMatch(narrative) ?? privetDriveRe.stringMatch(narrative) ?? '');
      }
      // 命中2：当"弗农/佩妮/达力"单独出现在"家门/楼下喊你/敲门"这种家庭成员语境时也命中
      final aloneDursley = RegExp(r'(弗农姨父|佩妮姨妈|达力表哥)', caseSensitive: false);
      if (aloneDursley.hasMatch(narrative)) {
        addV('critical', 'R3c_family_not_dursley',
            '家庭设定杂交：主角不是哈利，叙事里却直接称呼家人为"弗农姨父/佩妮姨妈/达力表哥"（这些是哈利专属亲属称谓）。原创角色的家人必须使用原创称呼或"养父/养母/妈妈/爸爸"。',
            evidence: aloneDursley.stringMatch(narrative) ?? '');
      }
    }

    // ---- BUG5 R1b: 开学时间/阶段错位（7月31日还在暑假却写分院/上课/特快正式开学）----
    final monthDayMatch = RegExp(r'(\d{4})年\s*(\d{1,2})月\s*(\d{1,2})日').firstMatch(nLower);
    if (monthDayMatch != null) {
      final m = int.tryParse(monthDayMatch.group(2) ?? '') ?? 0;
      final d = int.tryParse(monthDayMatch.group(3) ?? '') ?? 0;
      final md = m * 100 + d;
      // 7月31日 ~ 8月31日（开学前）绝对不允许出现"分院仪式/坐在学院长桌旁/正式上课/霍格沃茨特快已经开学当日抵达"这种已入学内容
      if (md >= 701 && md <= 831) {
        const forbiddenAfterAugust = ['分院仪式', '坐在学院长桌', '学院长桌旁', '正式上课', '第一节课', '分院帽叫到你的名字', '霍格沃茨特快抵达霍格莫德', '渡湖去大礼堂'];
        for (final fb in forbiddenAfterAugust) {
          if (nLower.contains(fb)) {
            addV('warn', 'R1b_school_date_misalign',
                '时间阶段错位：当前日期是${m}月${d}日（1991年暑假中/开学准备期），却写了"$fb"这种已入学场景。9月1日之前只能写"在家准备→对角巷采购→国王十字候车→登上特快"，正式分院/上课必须到9月1日之后。',
                evidence: '$md: $fb');
            break;
          }
        }
      }
    }

    return violations;
  }
  /// 记录一致性违规（保留最近 20 条，便于 UI 展示和人工调参）
  void recordConsistencyViolation(Map<String, dynamic> v) {
    worldState.consistencyViolations.insert(0, v);
    while (worldState.consistencyViolations.length > 20) {
      worldState.consistencyViolations.removeLast();
    }
  }
  // ============================================================
  // 【宏观通用 M2 · SceneTransitionGraph 场景转移图】
  // 替换掉"只对开局前 12 回合生效 + 用 if/else 写死 + forcedLocation 硬切地点"的 _checkOpeningRailroad。
  //
  // 核心思想：把"剧情应该怎么走"抽象成**带前置依赖的节点图**，任何阶段（开局/学年中/放假/大战前夕）都可以往
  // _transitionNodes 里加节点即可，不写死在代码分支里。
  //
  // 修复 2 个之前的宏观问题：
  //   1) forcedLocation 直接硬切 currentLocation 导致"7月31日在家→霍格沃茨大礼堂"跳场景 →
  //      现在：只有节点依赖 100% 满足时才允许更新 currentLocation；不满足则只注入 "过渡叙事锚点" 让 AI 补中间过程。
  //   2) 只有开局 12 回合有守卫，中后期玩家在地图/事件链上墨迹时完全无兜底 →
  //      现在：图上所有节点对当前地点匹配生效，不分阶段。
  // ============================================================

  /// 转移节点：「玩家当前应当位于 currentLocationPattern」→「当 turnsAtSameLocation 超过 turnRange 上限 或 turnCount∈[minT,maxT]」，
  /// 且 前置条件 requireVisited/requireDateInt/requireFlag 全部满足 → 给玩家注入 transitionAnchor（中间过程剧情要求），
  /// 最终让玩家抵达 nextLocation。
  static const List<TransitionNode> _transitionNodes = [
    // ---------- 开局骨架链（家中收到信 → 对角巷 → 国王十字 → 特快 → 分院）----------
    TransitionNode(
      id: 'opening_hagrid_visit',
      currentLocationPattern: r'(家中|家里|住宅|卧室|书房|庄园|别墅|密室|客厅|门厅)',
      requireVisited: const [], // 不需要前置地点
      requireNotVisited: const [r'(对角巷|国王十字|九又四分之三|站台|特快|列车|霍格沃茨)'],
      minTurn: 2,
      maxTurn: 3,
      requireOpeningScene: 'letter',
      // 锚点 = 中间过程：海格登门 + 和养父母告别 + 动身去伦敦 → 这一段必须 AI 完整写，不能跳
      transitionAnchor: '鲁伯·海格亲自登门送你（他受邓布利多委托亲自接新生去对角巷采购），他敲开大门、手里提着霍格沃茨的采购清单和火车票，笑着对你说："该走啦小子/姑娘，再晚就赶不上对角巷奥利凡德的预约了。" 本回合剧情必须自然融入：海格来访 → 和养父母告别 → 动身前往伦敦这三个中间阶段，不能跳帧直接进入采购画面。',
      nextLocation: null,
    ),
    TransitionNode(
      id: 'opening_force_diagon_alley',
      currentLocationPattern: r'(家中|家里|住宅|卧室|书房|庄园|别墅|密室|客厅|门厅)',
      requireVisited: const [],
      requireNotVisited: const [r'对角巷'],
      minTurn: 4,
      maxTurn: 5,
      requireOpeningScene: 'letter',
      transitionAnchor: '养父母已经把你的行李收拾好，火车票和加隆都塞到了你手里。本回合请写出完整的衔接过程：你与海格一同抵达伦敦 → 经过破釜酒吧 → 穿过吧台后的砖墙入口 → 正式进入对角巷开始采购。必须把"从家到对角巷的过程"完整写出来，不能第一句就写"此刻你正在魔杖店门口"。',
      nextLocation: '对角巷',
      // 允许在 minT/maxT 到期且已过渡叙事写完后，更新 currentLocation（之前这里直接无依赖切 = 跳场景 bug）
      forceNextOnlyIfAnchorPresented: true,
    ),
    TransitionNode(
      id: 'opening_diagon_to_station',
      currentLocationPattern: r'对角巷',
      requireVisited: const [r'对角巷'],
      requireNotVisited: const [r'(国王十字|九又四分之三|站台|特快|列车)'],
      minTurn: 6,
      maxTurn: 7,
      requireOpeningScene: 'letter',
      transitionAnchor: '采购收尾阶段：魔杖、课本、袍子都已买齐。海格看了看表："哎呀，十一点的特快！再不走就晚了！" 他拉着你通过骑士公共汽车/幻影移形赶往伦敦国王十字车站。本回合剧情必须包含完整过程：结算采购 → 赶车前往国王十字 → 来到 9 又 3/4 站台口 → 拿到霍格沃茨特快车票 → 最后一句必须已经进入站台或已登上特快。',
      nextLocation: '国王十字车站',
      forceNextOnlyIfAnchorPresented: true,
      // 进度门：时间 < 9月1日不允许跳（否则 7月31日就直接到了特快，与原著时间线冲突）
      minDateInt: 901,
    ),
    TransitionNode(
      id: 'opening_station_to_express',
      currentLocationPattern: r'(国王十字|九又四分之三|站台)',
      requireVisited: const [r'对角巷', r'(国王十字|九又四分之三|站台)'],
      requireNotVisited: const [r'(特快|列车|火车)'],
      minTurn: 8,
      maxTurn: 9,
      requireOpeningScene: 'letter',
      minDateInt: 901,
      transitionAnchor: '你推着行李车穿过了 9 又 3/4 站台的柱子，鲜红色的霍格沃茨特快冒着白烟、汽笛轰鸣。级长扯着嗓子喊："新生快上车！马上就要发车了！" 本回合必须完整写出：穿过柱子 → 登上特快 → 找到包厢/遇见同学 → 列车启动发车离开伦敦这几个阶段。',
      nextLocation: '霍格沃茨特快列车',
      forceNextOnlyIfAnchorPresented: true,
    ),
    TransitionNode(
      id: 'opening_express_to_sorting',
      currentLocationPattern: r'(特快|列车|火车|霍格莫德|车站)',
      requireVisited: const [r'(特快|列车|火车)', r'(国王十字|九又四分之三|站台)'],
      requireNotVisited: const [r'(霍格沃茨大礼堂|大礼堂|城堡内|分院)'],
      requireUngraded: true, // 还没分院
      minTurn: 10,
      maxTurn: 12,
      requireOpeningScene: 'letter',
      minDateInt: 901,
      transitionAnchor: '霍格沃茨特快抵达霍格莫德车站。海格举着巨大的灯笼在站台上喊："一年级新生跟我来！" 你们坐小船渡湖初见霍格沃茨城堡 → 穿过大门来到大礼堂入口 → 麦格教授拿着分院帽和长凳走出来 → 叫到了你的名字 → 分院结果正式公布。本回合剧情必须按顺序把中间过程完整写出来，不能第一句就写"你坐在学院长桌旁"。',
      nextLocation: '霍格沃茨大礼堂',
      forceNextOnlyIfAnchorPresented: true,
    ),
    // ---------- 开学后通用转移链（开局骨架退役后生效，不再只有前12回合保护）----------
    TransitionNode(
      id: 'hogwarts_hall_to_common_room',
      currentLocationPattern: r'(霍格沃茨大礼堂|大礼堂)',
      requireVisited: const [r'(霍格沃茨|大礼堂|分院)'],
      requireNotVisited: const [r'(公共休息室|宿舍|学院公共)'],
      minTurn: 13,
      maxTurn: 14,
      transitionAnchor: '分院仪式结束，级长带着你们学院的新生穿过走廊与楼梯，说出公共休息室的入口口令（格兰芬多：胖夫人肖像；斯莱特林：石墙；拉文克劳：鹰形门环谜语；赫奇帕奇：厨房旁木桶节奏）→ 你第一次走进学院公共休息室并看到自己的 dorm 床位。',
      nextLocation: '学院公共休息室',
      forceNextOnlyIfAnchorPresented: true,
    ),
    TransitionNode(
      id: 'first_class_next_day',
      currentLocationPattern: r'(公共休息室|宿舍|学院公共|大礼堂)',
      requireVisited: const [r'(公共休息室|学院公共|宿舍)'],
      requireGraded: true,
      minTurn: 15,
      maxTurn: 17,
      transitionAnchor: '第二天清晨被级长/室友叫醒，你去大礼堂吃了早餐后按照课表前往第一节正式课堂（变形课/魔药课/草药课/魔咒课四选一）。本回合必须写出"起床 → 早餐 → 找到对应教室门口 → 走进去坐到座位上 → 教授开始上课"的完整过程，不能跳帧直接写"教授在讲解魔法"。',
      nextLocation: '霍格沃茨·课堂',
      forceNextOnlyIfAnchorPresented: true,
    ),
  ];
  /// SceneTransitionGraph 主控（替换 _checkOpeningRailroad）
  /// 原则：
  ///   1. 遍历全部 _transitionNodes 节点，找 match 当前地点 + turn 范围 + 所有前置依赖满足 → 触发；
  ///   2. **没有 100% 满足前置依赖（visitedLocations / minDateInt）绝不切 currentLocation**，
  ///      只注入 transitionAnchor（要求 AI 补完过渡叙事），防止"在家 → 直接大礼堂"这类跳场景 bug；
  ///   3. 触发后立刻记录到 narrativeEvent，供后续节点判断"已经在走这条链了"，避免多节点同时注入多条锚点。
  void runSceneTransitionGraph() {
    final p = player;
    if (p == null) return;
    final loc = worldState.currentLocation ?? '';
    final visited = worldState.visitedLocations;
    final t = turnCount;
    final month = worldState.time.month;
    final day = worldState.time.day;
    final dateInt = month * 100 + day;

    String? chosenAnchor;
    String? chosenNextLocation;
    String? chosenId;
    bool allowNextUpdate = false;

    for (final node in _transitionNodes) {
      // 1) 当前地点匹配（开局骨架只对 openingScene=letter 生效）
      if (!_loosePattern(node.currentLocationPattern).hasMatch(loc)) continue;
      if (node.requireOpeningScene != null && openingScene != node.requireOpeningScene) continue;
      // 2) 已触发过的节点跳过（避免每次重复注入同一条锚点）
      if (worldState.firedAnchorIds.contains(node.id)) continue;
      // 3) turn 范围
      if (t < node.minTurn || t > node.maxTurn) continue;
      // 4) requireGraded / requireUngraded
      if (node.requireGraded && !(p.house?.isNotEmpty ?? false)) continue;
      if (node.requireUngraded && (p.house?.isNotEmpty ?? false)) continue;
      // 5) minDateInt 时间门（保护 7月31不跳特快/分校）
      if (node.minDateInt != null && dateInt < node.minDateInt!) continue;
      // 6) requireVisited 进度门（之前没加进度门直接切大礼堂的 bug 根因）
      bool prereqVisitedOk = node.requireVisited.every(
          (pat) => visited.any((l) => _loosePattern(pat).hasMatch(l)));
      if (!prereqVisitedOk) continue;
      // 7) requireNotVisited：已经过门过就别再推这条链
      bool notVisitedOk = node.requireNotVisited.every(
          (pat) => !visited.any((l) => _loosePattern(pat).hasMatch(l)));
      if (!notVisitedOk) continue;

      // OK，命中此节点
      chosenAnchor = node.transitionAnchor;
      chosenId = node.id;
      // 【关键保护】只有 node.forceNextOnlyIfAnchorPresented=false（表示这是"玩家已经在锚点叙事里完成过渡"的节点）
      // 才允许我们直接改 currentLocation。其他情况一律**只注入锚点，不切 location**，
      // 让 _syncLocationFromNarrative 在 AI 把过渡叙事写完后自然同步到 nextLocation。
      allowNextUpdate = !(node.forceNextOnlyIfAnchorPresented ?? true);
      if (allowNextUpdate) {
        chosenNextLocation = node.nextLocation;
      } else {
        chosenNextLocation = null;
      }
      break; // 一次只注入一个节点，避免多锚点叠加导致 prompt 爆掉
    }

    if (chosenAnchor != null && pendingAnchorDirective == null) {
      pendingAnchorDirective = chosenAnchor;
      if (chosenId != null) worldState.firedAnchorIds.add(chosenId);
      notifications.add('🧭 剧情推进：下一阶段衔接已为你安排（节点=$chosenId）');
      worldState.addNarrativeEvent('🧭 SceneGraph: 触发节点 $chosenId（turn=$t loc=$loc）', turn: t);
      debugPrint('🧭 SceneTransitionGraph 命中 id=$chosenId; 切Location=${allowNextUpdate ? chosenNextLocation : "(依赖剧情走完后自动同步)"}');
    }
    if (chosenNextLocation != null && allowNextUpdate) {
      worldState.currentLocation = chosenNextLocation;
      lastTrackedLocation = chosenNextLocation;
      turnsAtSameLocation = 0;
      worldState.visitedLocations.add(chosenNextLocation);
    }
  }
  // ==================== P1-3 T1 未完结事项超期提醒 ====================
  // 给 narrative Prompt 拼注入文本用（在 buildPrompt 里调用）。
  String buildOpenLoopsStagnationHint() {
    final stale = <String>[];
    // 每条 open loop 有 importance 与可能隐含的 lastTouched；
    // 这里做简化：超过 15 回合仍为 open 状态 & importance >= 6 的，给一条提醒
    for (final l in memory.openLoops) {
      if (l.status != 'open') continue;
      if (l.importance < 6) continue;
      // 旧实现从 id 尾部正则解析 `t<回合>`，但实际 id 形如
      // `auto_loop_<hash>` / `quest_<id>`，永远匹配不到 → lastTouched 恒 -1
      // → 新伏笔一诞生就被标注「已悬而未决约 15 回合」，提醒完全失真。
      // 改为直接用记录上的 openedTurn（旧存档为 0，按「很久以前」处理）。
      final turnsPassed = l.openedTurn > 0 ? turnCount - l.openedTurn : 15;
      if (turnsPassed >= 15 && stale.length < 2) {
        stale.add('• ${l.description}（已悬而未决约${turnsPassed}回合，重要性${l.importance}）');
      }
    }
    if (stale.isEmpty) return '';
    return '【别忘了这些重要伏笔（别让玩家觉得石沉大海）】\n'
        '${stale.join('\n')}\n'
        '提示：本回合可适当推进其中一条，或通过对话/事件给玩家一个"还没忘掉"的信号。\n\n';
  }
  // ==================== P2 禁止词/违和词表 与 P2-2 咒语分级 ====================

  /// 检查叙事/选项里的违和词：现代物品、跨IP、网络梗。
  /// 返回命中列表；命中 1+ 条 critical 级则判需重试。
  List<Map<String, dynamic>> detectForbiddenWords(String text) {
    const modernItems = <String>[
      '手机', '智能手机', '电话', '互联网', '因特网', '微信', 'QQ', '电子邮件', 'email', 'E-mail', '推特', 'Twitter',
      '高铁', '动车', '飞机', '民航', '地铁', '打车', '网约车', '计算机', '电脑', '笔记本电脑', '平板', 'iPad',
      'APP', 'app', '应用程序', '游戏主机', 'PS5', 'Switch', '电视', '冰箱', '空调',
      '加隆兑换人民币', '汇率', '电子支付', '扫码', '二维码',
    ];
    const crossIp = <String>[
      '柯南', '工藤新一', '海贼王', '路飞', '火影忍者', '鸣人', '佐助', '原神', '旅行者', '刻晴', '钟离',
      '斗罗大陆', '唐三', '斗破苍穹', '萧炎', '三体', '三体人', '智子', '罗辑', '叶文洁',
      // ⚠️ 这里原本写的是「逻辑」，应为三体角色「罗辑」。
      // 「逻辑」是中文常用词，放在 critical 级会让几乎每回合的叙事都被判违和、
      // 触发最多 3 次重生成（烧 token 且拖慢出文）。
    ];
    const internetSlang = <String>[
      'yyds', 'YYDS', '绝绝子', '社死', '打call', '破防了', '内卷', '躺平', 'emo', 'EMO',
      '栓Q', '666', '233', 'awsl', 'AWSL', 'xswl', 'XSWL', '笑死我了哈哈哈哈',
      '大冤种', 'emo了', '我不李姐', '咱就是说', '一整个爱住',
    ];
    final hits = <Map<String, dynamic>>[];
    final lower = text;
    for (final w in modernItems) {
      if (lower.contains(w)) hits.add({'severity': 'critical', 'category': 'modern', 'word': w});
    }
    for (final w in crossIp) {
      if (lower.contains(w)) hits.add({'severity': 'critical', 'category': 'cross_ip', 'word': w});
    }
    for (final w in internetSlang) {
      if (lower.contains(w)) hits.add({'severity': 'warn', 'category': 'slang', 'word': w});
    }
    return hits;
  }
}
