import 'package:flutter/foundation.dart';
import '../providers/game_provider_base.dart';
import '../models/npc.dart';
import '../utils/affection_validator.dart';
import 'mixin_response_choices.dart';

mixin GameResponseAffectionMixin on GameProviderBase, GameResponseChoiceMixin {
  void parseAffectionChanges(String text) {
    if (npcRegistry.isEmpty) return;

    // 修复：使用捕获组提取内容，避免 replaceFirst 把整段匹配（header+body）都删掉
    // 旧代码：sectionMatch.group(0)!.replaceFirst(sectionPattern, '') 会用同一个
    //         sectionPattern 再次匹配整段文本然后替换为空 → section 永远是 "" →
    //         所有好感度变化都不会被解析 → NPC 好感度永远不变
    final sectionPattern = RegExp(r'【好感(?:度)?变化?】\s*([\s\S]*?)(?=【|$)');
    final sectionMatch = sectionPattern.firstMatch(text);

    String? sectionText;
    if (sectionMatch != null) {
      sectionText = sectionMatch.group(1)!.trim();
    }

    // Fallback 1：AI 未输出【好感度变化】标签头时，扫描全文寻找散落的好感行
    if (sectionText == null || sectionText.isEmpty) {
      sectionText = _fallbackAffectionScan(text);
    }

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
        final match = RegExp(r'^(.*?)[:：]\s*([+-]?\d+)').firstMatch(trimmed);
        if (match == null) continue;
        var npcName = match.group(1)!.trim();
        var delta = int.tryParse(match.group(2)!) ?? 0;
        if (delta == 0 || npcName.isEmpty) continue;
        npcName = npcName.replaceFirst(RegExp(r'[（(].*?[）)]'), '').trim();
        if (npcName.isEmpty) continue;

        // ---- P1-2 好感校验 + NPC 模糊匹配（先匹配再校验）----
        // BUG-M 修复：AI 会写出"塞德里克·邓布利多"这种混淆名（塞德里克·迪戈里 + 阿不思·邓布利多）
        // 旧顺序：先 validator.validate(npcRegistry, npcName, ...) → "塞德里克·邓布利多"不在注册表 → 拒绝
        // 新顺序：先模糊匹配找到最相似的注册NPC → 用真名做校验 → 通过则更新好感
        NPC? npc;
        int bestScore = 0;
        for (final n in npcRegistry.values) {
          final score = n.nameMatchScore(npcName);
          if (score > bestScore) {
            bestScore = score;
            npc = n;
          }
        }
        if (npc == null || bestScore == 0) {
          debugPrint('[好感解析] 未找到匹配NPC: $npcName');
          continue;
        }
        // 用匹配到的真名做校验（而不是 AI 写的混淆名）
        if (!validator.validate(npcRegistry, npc.name, text, delta)) continue;

        if (delta > 5) delta = (delta * 0.5).round().clamp(1, 5);
        if (delta < -5) delta = (delta * 0.7).round().clamp(-5, -1);
        try {
          // npc 和 bestScore 已在上面模糊匹配阶段赋值，这里直接使用
          debugPrint('[好感解析] ${npc.name} ${delta > 0 ? '+' : ''}$delta (匹配分=$bestScore)');
          final before = npc.affection;
          updateNpcAffection(npc.id, delta, reason: '剧情互动');
          final after = npc.affection;
          if (before != after) {
            debugPrint('[好感更新] ${npc.name}: $before → $after');
            explicitChanged.add(npc.id);
          } else {
            debugPrint('[好感未变] ${npc.name}: 保持 $before (可能触达上限)');
          }
          checkLocks(npc);
          syncRelationshipLevel(npc);
          checkAffectionAchievements(npc);
        } catch (e) {
          debugPrint('[好感解析错误] $npcName: $e');
        }
      }
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
      if (!RegExp(r'[+-]\d').hasMatch(trimmed)) continue;
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
    final positiveKeywords = [
      '聊天', '对话', '帮助', '帮', '救', '约', '邀', '送礼', '送',
      '陪伴', '陪', '鼓励', '安慰', '保护', '支持', '信任', '赞同',
      '微笑', '友好', '亲切', '称赞', '夸', '感谢', '谢',
      '一起', '散步', '聊天', '聊天', '和', '与', '跟',
    ];
    final negativeKeywords = [
      '攻击', '打', '骂', '辱骂', '欺骗', '骗', '背叛', '出卖',
      '嘲笑', '讽刺', '忽视', '无视', '拒绝', '反对', '争吵', '吵架',
      '冲突', '打架', '偷', '抢', '伤害', '恶意',
    ];

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

    // 最多 3 个 NPC 获得被动好感
    final maxPassive = 3;
    for (int i = 0; i < candidates.length && i < maxPassive; i++) {
      final npc = candidates[i];
      final delta = isPositive
          ? 1 + random.nextInt(2)  // +1 or +2
          : -1;                     // -1
      final before = npc.affection;
      updateNpcAffection(npc.id, delta, reason: '剧情互动(推断)');
      final after = npc.affection;
      if (before != after) {
        // [被动好感] 日志已移除
        checkLocks(npc);
        syncRelationshipLevel(npc);
      }
    }
  }

  void parseReputationChanges(String text) {
    if (player == null) return;
    // 修复：与 _parseAffectionChanges 同样的 bug——replaceFirst 把整段内容删掉
    final sectionPattern = RegExp(r'【声望变化?】\s*([\s\S]*?)(?=【|$)');
    final sectionMatch = sectionPattern.firstMatch(text);
    if (sectionMatch == null) return;
    final section = sectionMatch.group(1)!.trim();
    if (section.isEmpty) return;
    for (final line in section.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final match = RegExp(r'^(.*?)[:：]\s*([+-]?\d+)').firstMatch(trimmed);
      if (match == null) continue;
      final dim = match.group(1)!.trim();
      final delta = int.tryParse(match.group(2)!) ?? 0;
      if (delta == 0 || dim.isEmpty) continue;
      try {
        player!.playerReputation.add(dim, delta);
      } catch (e) {
      }
    }
  }
}