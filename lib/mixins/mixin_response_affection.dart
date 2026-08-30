import 'dart:async';

import 'package:flutter/foundation.dart';
import '../data/balance_constants.dart';
import '../providers/game_provider_base.dart';
import '../models/npc.dart';
import '../utils/affection_validator.dart';
import '../utils/narrative_section_parser.dart';
import '../utils/npc_lookup.dart';
import 'mixin_response_choices.dart';

mixin GameResponseAffectionMixin on GameProviderBase, GameResponseChoiceMixin {
  /// 好感行必须带 +数字 / -数字。原先写在逐行扫描的循环里，每行都重新编译一次。
  static final RegExp _hasSignedNumber = RegExp(r'[+-]\d');

  /// 好感行。逐行解析，原先每行现编译。
  ///
  /// 冒号是可选的——_fallbackAffectionScan 的注释一直声称支持「NPC名 +X」
  /// 这种写法，但老正则强制要求半角/全角冒号，于是 AI 一旦漏掉冒号
  /// （「赫敏 +3」「赫敏·格兰杰　+2」这种全角空格分隔），整行就静默漏解析，
  /// 只能靠 _inferPassiveAffection 补一个 +1/+2，玩家感觉"好感涨得莫名其妙地慢"。
  /// 行尾的括号备注要能带上：「赫敏 -8（你当众反驳了她）」是 AI 最常见的
  /// 写法之一，老正则要求行尾必须是数字，于是这类整行静默漏解析——
  /// 好感不动、宿敌不记，玩家只觉得"我明明得罪了他却什么都没发生"。
  /// 备注同时被 [group 3] 捕获，用作记仇的理由文本。
  static final RegExp _affectionLineRe =
      RegExp(r'^\s*(.*?)\s*(?:[:：]\s*)?([+＋-]?\d+)\s*(?:[（(](.*?)[）)])?\s*$');

  /// 倒装写法：「+3 赫敏」。AI 偶尔把数字写在名字前面。
  static final RegExp _affectionLineReversedRe =
      RegExp(r'^\s*([+＋-]?\d+)\s+(.{1,12}?)\s*$');

  /// 名字后面跟的括号备注（「赫敏（犹豫了一下）：+2」）要剥掉。
  static final RegExp _parenRemarkRe = RegExp(r'[（(].*?[）)]');

  /// 连续互动回合追踪：NPC id → 当前连续回合数。
  /// 每次调用 [parseAffectionChanges] 时先清空，[applySocialCost] 负责递增。
  final Map<String, int> _consecutiveInteractionTurns = {};

  /// 在好感度变化落地前应用社交成本——连续互动衰减。
  ///
  /// 从 [_consecutiveInteractionTurns] 获取当前 NPC 的连续互动回合数，
  /// 调用 [Balance.consecutiveInteractionDecay] 获取衰减系数，
  /// 将 [rawChange] 乘以衰减系数后取整返回，并在计数器 +1。
  int _applySocialCost(String npcId, int rawChange) {
    final consecutiveTurns = _consecutiveInteractionTurns[npcId] ?? 0;
    final decay = Balance.consecutiveInteractionDecay(consecutiveTurns);
    final result = (rawChange * decay).round();
    _consecutiveInteractionTurns[npcId] = consecutiveTurns + 1;
    return result;
  }

  /// 重置指定 NPC 的连续互动计数器。
  ///
  /// 当玩家与不同 NPC 互动时，重置之前 NPC 的连续计数器。
  /// 每次调用 [parseAffectionChanges] 时整批清空，只保留当前文本中出现的 NPC。
  void resetConsecutiveInteractions(String npcId) {
    _consecutiveInteractionTurns.remove(npcId);
  }

  /// 检查某个好感变化是否触发了"重大事件免疫衰减"。
  ///
  /// 如果 [reason] 包含"救命""牺牲""告白""背叛""救""生死"等关键词，
  /// 且 [rawChange.abs() >= 10]，标记该 NPC 为"重大事件免疫"——
  /// 设置 [npc.majorEventDate] 为当前绝对天数。
  /// 如果 NPC 模型没有 [majorEventDate] 字段则跳过该逻辑。
  /// 返回 true 表示触发免疫。
  bool _checkMajorEventImmunity(NPC npc, int rawChange, String reason) {
    const keywords = ['救命', '牺牲', '告白', '背叛', '救', '生死'];
    final matched = keywords.any((k) => reason.contains(k));
    if (!matched || rawChange.abs() < 10) return false;
    // 如果 NPC 模型有 majorEventDate 字段则设置
    // 使用反射/interface 不可行，这里在编译期检查字段是否存在；
    // NPC 类已添加 majorEventDate 字段，直接赋值即可。
    npc.majorEventDate = worldState.time.absoluteDayIndex;
    return true;
  }

  void parseAffectionChanges(String text) {
    if (npcRegistry.isEmpty) return;

    // 每次解析新文本时清空连续互动计数器，只追踪本轮内的连续互动
    _consecutiveInteractionTurns.clear();

    // 修复：使用捕获组提取内容，避免 replaceFirst 把整段匹配（header+body）都删掉
    // 旧代码：sectionMatch.group(0)!.replaceFirst(sectionPattern, '') 会用同一个
    //         sectionPattern 再次匹配整段文本然后替换为空 → section 永远是 "" →
    //         所有好感度变化都不会被解析 → NPC 好感度永远不变
    final sectionPattern = RegExp(r'【好感(?:度)?变化?】\s*([\s\S]*?)(?=【|$)');

    // 修复（第五次审查 P2-4.3）：AI 偶尔会把好感变化拆成两个【好感度变化】区块
    // （如先列主线、再列支线）。以前只取 firstMatch → 第二个区块静默丢弃，
    // 玩家明明惹恼了支线 NPC 却毫无反应。现在拼接所有区块一起解析，
    // 与声望侧共用 _allSectionText，避免这类「只修 A 面」再次发生。
    final sectionText =
        allSectionText(text, sectionPattern) ?? _fallbackAffectionScan(text);

    // ============================================================
    // P1-2 好感变化逻辑校验（宏观通用·统一出口，避免假好感"羞辱了你 → +8 好感"）
    // 注意：校验逻辑已封装为独立顶层类 AffectionValidator，与 StagnationDetector 同一层级，
    //       任何 mixin 解析好感度时都统一调用它，不会出现"这里校验了那里没校验"的不一致。
    // ============================================================
    const validator = AffectionValidator.instance;

    final explicitChanged = <String>{};

    if (sectionText != null && sectionText.isNotEmpty) {
      for (final line in sectionText.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        var match = _affectionLineRe.firstMatch(trimmed);
        var npcName = match?.group(1)?.trim() ?? '';
        var deltaStr = match?.group(2) ?? '';
        // 倒装（「+3 赫敏」）：名字与数字对调
        if (match == null) {
          final rev = _affectionLineReversedRe.firstMatch(trimmed);
          if (rev != null) {
            npcName = rev.group(2)!.trim();
            deltaStr = rev.group(1)!;
          }
        }
        if (npcName.isEmpty) continue;
        // 全角加号/减号：AI 在中文语境里常写成「＋3」
        deltaStr = deltaStr.replaceAll('＋', '+').replaceAll('－', '-');
        var delta = int.tryParse(deltaStr) ?? 0;
        if (delta == 0 || npcName.isEmpty) continue;
        // 括号里的话是 AI 给的理由，以前剥掉就扔了。
        // 现在留下来：它既是记仇理由，也是成因识别的唯一输入——
        // 否则宿敌表里那 7 种成因在 AI 路径上永远只会认出默认的「背叛」。
        final trailing = match?.group(3)?.trim();
        String? remark;
        final inName = _parenRemarkRe.firstMatch(npcName)?.group(0);
        if (inName != null) {
          remark = inName.substring(1, inName.length - 1).trim();
        }
        // 两个位置都有括号时以行尾的为准：prompt 约定的格式是
        // 「NPC名:±X(原因)」，行尾那个是原因，名字后面的多半只是神态描写。
        if (trailing != null && trailing.isNotEmpty) remark = trailing;
        npcName = npcName.replaceFirst(_parenRemarkRe, '').trim();
        if (npcName.isEmpty) continue;

        // ---- P1-2 好感校验 + NPC 模糊匹配（先匹配再校验）----
        // BUG-M 修复：AI 会写出"塞德里克·邓布利多"这种混淆名（塞德里克·迪戈里 + 阿不思·邓布利多）
        // 旧顺序：先 validator.validate(npcRegistry, npcName, ...) → "塞德里克·邓布利多"不在注册表 → 拒绝
        // 新顺序：先模糊匹配找到最相似的注册NPC → 用真名做校验 → 通过则更新好感
        // 统一走 findNpcByKeyword（含别名+姓氏推导），不再自己手写取最高分的循环
        final npc = findNpcByKeyword(npcRegistry.values, npcName);
        if (npc == null) {
          // 热路径：每回合对每个好感行都跑一遍，release 版也往 stdout 写，
          // 长局下来是纯 I/O 浪费。调试日志一律收进 kDebugMode。
          if (kDebugMode) debugPrint('[好感解析] 未找到匹配NPC: $npcName');
          continue;
        }
        // 用匹配到的真名做校验（而不是 AI 写的混淆名）
        if (!validator.validate(npcRegistry, npc.name, text, delta)) continue;

        // 压缩数值是为了不让好感一回合暴涨暴跌——那是数值层的事。
        // 但 AI 写下 -30 是在说"这件事很严重"，这个意图不能一起被压掉：
        // 结仇判定看的是下面这个 raw，不是压缩后的 delta。
        //
        // 第九次审查：一刀切 ±5 改为分段映射（Balance.compressAffectionDelta）。
        // 旧公式 (delta*0.5).clamp(1,5) 把「救命 +20」和「帮忙 +8」都压成 +5，
        // 大事件的反馈层次被抹平；分段后 6-10→5-7、11-20→7-9、20+→10，
        // 上限仍在，但"这件事有多大"在数值上看得出来。
        // 副作用（有意为之）：+8/+9 现在可达，updateNpcAffection 里
        // 「actualChange >= 8 才算赎罪」的和解门从此能被重大示好推开——
        // 那道门本来就是为大事准备的，旧压缩下它永远开不了。
        final rawDelta = delta;
        delta = Balance.compressAffectionDelta(delta);

        // 应用社交成本——连续互动衰减，对压缩后的好感值进行衰减
        delta = _applySocialCost(npc.id, delta);

        // 检查是否触发重大事件免疫衰减
        final reasonText = (remark == null || remark.isEmpty) ? '剧情互动' : remark;
        _checkMajorEventImmunity(npc, rawDelta, reasonText);

        try {
          // 热路径：这几条日志每回合、每个好感行都要写一次，release 版照样
          // 往 stdout 打，长局下来是纯粹的 I/O 浪费。调试日志统一收进
          // kDebugMode（同文件其它 debug 日志同理）。
          if (kDebugMode) {
            debugPrint('[好感解析] ${npc.name} ${delta > 0 ? '+' : ''}$delta'
                '${rawDelta == delta ? '' : '（原文 $rawDelta）'}');
          }
          final before = npc.affection;
          // 一次解析出多行好感变化时静默批量更新，循环结束后统一通知一次
          // （见 parseAffectionChanges 末尾的 explicitChanged 判断）。
          updateNpcAffection(npc.id, delta,
              reason: reasonText,
              severity: rawDelta,
              quiet: true);
          final after = npc.affection;
          if (before != after) {
            if (kDebugMode) debugPrint('[好感更新] ${npc.name}: $before → $after');
            explicitChanged.add(npc.id);
          } else {
            if (kDebugMode) {
              debugPrint('[好感未变] ${npc.name}: 保持 $before (可能触达上限)');
            }
          }
          checkLocks(npc);
          syncRelationshipLevel(npc);
          checkAffectionAchievements(npc);
        } catch (e) {
          if (kDebugMode) debugPrint('[好感解析错误] $npcName: $e');
        }
      }
    }
    // 上面整批是 quiet 的，这里补上唯一一次通知与写档。
    if (explicitChanged.isNotEmpty) {
      notifyListeners();
      unawaited(autoSave());
    }

    // Fallback 2：对剧情中出现但没有显式好感变化的 NPC，推断被动好感
    _inferPassiveAffection(text, excludeIds: explicitChanged);
  }

  /// Fallback：AI 没有输出【好感度变化】标签头时，尝试从全文提取散落的好感行
  /// 匹配格式：NPC名:+X / NPC名：-X / NPC名 +X 等
  String? _fallbackAffectionScan(String text) {
    final lines = text.split('\n');
    final found = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      // 跳过叙事正文（太长的行大概率是叙事，不是好感度行）
      if (trimmed.length > 40) continue;
      // 必须包含 +数字 或 -数字
      if (!_hasSignedNumber.hasMatch(trimmed)) continue;
      // 不能是选项行
      if (GameProviderBase.reChoiceOption.hasMatch(trimmed)) continue;
      found.add(trimmed);
    }
    return found.isEmpty ? null : found.join('\n');
  }

  /// 被动好感推断：当 AI 未输出好感变化、或剧情中出现的 NPC 没有被覆盖时，
  /// 根据玩家行动的关键词推断小幅好感变化。
  /// - 只对剧情文本中出现且未被显式好感变化覆盖的 NPC 生效
  /// - 每回合最多 3 个 NPC 获得被动好感
  /// - 变化幅度小：正面互动 +1~+2，负面互动 -1
  void _inferPassiveAffection(String narrativeText, {Set<String>? excludeIds}) {
    if (npcRegistry.isEmpty || player == null) return;

    final action = lastPlayerAction.toLowerCase();
    // 判断玩家行动的情感倾向
    // 注意：不要放「和/与/跟」这类连词——中文行动描述几乎必然包含它们，
    // 会导致「骂了马尔福」也被判成正面互动，反向加好感。
    // 单字关键字（如"打"）必须与上下文结合判断，避免"打招呼"→负面误判
    final positiveKeywords = [
      '聊天', '对话', '帮助', '帮', '救', '约', '邀', '送礼', '送',
      '陪伴', '陪', '鼓励', '安慰', '保护', '支持', '信任', '赞同',
      '微笑', '友好', '亲切', '称赞', '夸', '感谢', '谢',
      '一起', '散步',
    ];
    final negativeKeywords = [
      '攻击', '骂', '辱骂', '殴打', '欺骗', '骗', '背叛', '出卖',
      '嘲笑', '讽刺', '忽视', '无视', '拒绝', '反对', '争吵', '吵架',
      '冲突', '打架', '偷', '抢', '伤害', '恶意',
    ];
    // 排除"打招呼"类误判：已从前面的关键字列表中移除"打"单字，
    // 改用"殴打""打架"等更精确的双字词覆盖负面场景
    final isPositive = positiveKeywords.any((k) => action.contains(k));
    final isNegative = negativeKeywords.any((k) => action.contains(k));
    if (!isPositive && !isNegative) return;

    // 从剧情文本中找出出现的 NPC（未被显式好感覆盖的）
    final candidates = <NPC>[];
    final npcs = npcRegistry.values.toList()
      ..sort((a, b) => b.name.length.compareTo(a.name.length));
    for (final npc in npcs) {
      if (excludeIds != null && excludeIds.contains(npc.id)) continue;
      if (!npc.isAlive) continue;
      // 被动好感只作用于已登场的 NPC，避免未出场的角色被"隔空"加好感
      if (!npc.introduced) continue;
      // 检查 NPC 是否在剧情文本中出现
      bool mentioned = false;
      for (final alias in npc.allNames) {
        if (alias.runes.length < 2) continue;
        if (standaloneNameMentioned(narrativeText, alias)) {
          mentioned = true;
          break;
        }
      }
      if (mentioned) {
        candidates.add(npc);
      }
    }

    // 负面优先：同时命中正负关键词时（如「骂了和罗恩吵架的马尔福」）
    // 按负面处理，否则歧义行动会反向加好感。
    // 且负面只惩罚最相关的一位——在场旁观者不该被连坐。
    final negative = isNegative;
    final maxPassive = negative ? 1 : 3;
    var touched = false;
    for (int i = 0; i < candidates.length && i < maxPassive; i++) {
      final npc = candidates[i];
      final delta = negative
          ? -1
          : 1 + random.nextInt(2); // +1 or +2
      final before = npc.affection;
      updateNpcAffection(npc.id, delta,
          reason: '剧情互动(推断)', quiet: true);
      final after = npc.affection;
      if (before != after) {
        // [被动好感] 日志已移除
        checkLocks(npc);
        syncRelationshipLevel(npc);
        touched = true;
      }
    }
    if (touched) {
      notifyListeners();
      unawaited(autoSave());
    }
  }

  void parseReputationChanges(String text) {
    if (player == null) return;
    // 区块拼接与逐行解析都抽到了 utils/narrative_section_parser.dart：
    // 一是与好感侧共用同一份拼接逻辑（AI 拆段时第二块不再被丢掉），
    // 二是这段逻辑终于可以直接写行为测试，不必先造一个完整 Provider。
    for (final d in extractReputationDeltas(text)) {
      try {
        // AI 偶尔会写出 +50 这种离谱值，这里限幅到 ±5（与 prompt 约定一致）
        player!.playerReputation.add(d.dimension, d.delta.clamp(-5, 5));
      } catch (e) {
        // 维度名不在白名单里（AI 自造词）→ 静默忽略，不影响其它维度
      }
    }
  }
}