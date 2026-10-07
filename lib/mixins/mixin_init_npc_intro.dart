import 'dart:async';
import '../data/memory_importance_config.dart';
import '../models/npc.dart';
import '../models/long_term_memory.dart';
import '../providers/game_provider_base.dart';

/// NPC 引导族（第十一轮 r11-2 拆分自 mixin_init.dart）。
///
/// 覆盖：随机遇见 NPC / 标记登场 / 从叙事识别 NPC 首次登场（签名档范围校验、
/// CJK 名称识别、拉丁名严格边界检查）。
mixin GameInitNpcIntroMixin on GameProviderBase {
String? meetRandomNpc() {
    final candidates = npcRegistry.values
        .where((n) => n.isAlive && !n.introduced)
        .toList();
    if (candidates.isEmpty) return null;
    final npc = candidates[random.nextInt(candidates.length)];
    markNpcIntroduced(npc);
    notifyListeners();
    unawaited(autoSave());
    return npc.name;
  }

  @override
  void markNpcIntroduced(NPC npc) {
    if (npc.introduced) return;
    npc.introduced = true;
    final event = '初次见面';
    if (!npc.recentEvents.contains(event)) {
      npc.recentEvents.insert(0, event);
      if (npc.recentEvents.length > 10) npc.recentEvents.removeLast();
    }
    worldState.addNarrativeEvent('👤 你结识了 ${npc.name}', turn: turnCount);

    // ====== 长线记忆写入：T2 关系锚点 + T3 世界事件 ======
    // 这是记忆管线的关键入口——NPC 登场时写入结构化关系锚点，
    // 确保数百回合后 AI 仍然知道玩家认识谁、关系如何。
    final ts = worldState.time.format();
    memory = memory.upsertRelationshipAnchor(
      NpcRelationshipAnchor(
        npcId: npc.id,
        firstMeeting: '$ts 初次见面',
        currentStage: '认识',
        lastUpdatedTurn: turnCount,
      ),
    );
    memory = memory.addWorldEvent(
      WorldEventRecord(
        id: 'meet_${npc.id}_$turnCount',
        timestamp: ts,
        title: '结识${npc.name}',
        description: '主角初次结识了${npc.name}',
        importance: kImportanceMeetNpc,
        category: 'personal',
        npcIds: {npc.id},
      ),
    );

    // 初次相遇 → CG-003（对角巷的偶然回眸）。
    // 这张 2 星卡此前没有任何解锁路径：cgUnlockConditions 里没登记，
    // 硬编码分支里也没写，玩家永远拿不到。
    unlockCG(cgById('CG-003'));
  }

  static const List<String> signoffKeywords = [
    '敬启',
    '谨启',
    '谨致',
    '此致',
    '敬礼',
    '敬意',
    '顺颂',
    '顺颂时祺',
    '顺颂安祺',
    '祝好',
    '祝安好',
    '谨上',
    '敬上',
    '顿首',
    '拜上',
    '签名',
    '落款',
    '联系人',
    '联系电话',
    '地址：',
    '邮编：',
    '校长：',
    '副校长：',
    '院长：',
    '教授：',
    '老师：',
    '魔法部部长：',
    '傲罗办公室主任：',
    '司长：',
    '厅长：',
    'Headmaster ',
    'Deputy Head',
    'Professor ',
    'Mr.',
    'Mrs.',
    'Miss',
    'Ms.',
    'Sincerely',
    'Yours truly',
    'Best regards',
    'Kind regards',
    'Warm regards',
    'From,',
    'With love,',
    'Cheers,',
    'Regards,',
  ];

  List<(int, int)> signatureRanges(String text) {
    final ranges = <(int, int)>[];
    if (text.isEmpty) return ranges;

    final lines = text.split('\n');
    if (lines.isEmpty) return ranges;

    int currentOffset = 0;
    final lineOffsets = <int>[];
    for (final line in lines) {
      lineOffsets.add(currentOffset);
      currentOffset += line.length + 1;
    }

    int signatureStartLine = -1;
    int consecutiveHits = 0;
    const maxSignatureLines = 15;

    for (int i = lines.length - 1; i >= 0; i--) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        if (signatureStartLine != -1) {
          consecutiveHits++;
          if (consecutiveHits > 2) break;
        }
        continue;
      }

      bool isSignatureLine = false;

      for (final keyword in signoffKeywords) {
        if (line.contains(keyword)) {
          isSignatureLine = true;
          break;
        }
      }

      if (!isSignatureLine) {
        final titlePattern = RegExp(r'^[\u4e00-\u9fa5A-Za-z]{2,15}[：:]\s*\S');
        if (titlePattern.hasMatch(line)) {
          isSignatureLine = true;
        }
      }

      if (isSignatureLine) {
        signatureStartLine = i;
        consecutiveHits = 0;
      } else if (signatureStartLine != -1) {
        consecutiveHits++;
        if (consecutiveHits > 2) break;
      }

      if (signatureStartLine != -1 &&
          (signatureStartLine - i) >= maxSignatureLines) {
        break;
      }
    }

    if (signatureStartLine != -1) {
      final startOffset = lineOffsets[signatureStartLine];
      final endOffset = text.length;
      ranges.add((startOffset, endOffset));
    }

    return ranges;
  }

  bool inSignatureRange(int idx, List<(int, int)> ranges) {
    for (final range in ranges) {
      if (idx >= range.$1 && idx <= range.$2) {
        return true;
      }
    }
    return false;
  }

  bool sliceOverlapsSignature(int start, int end, List<(int, int)> ranges) {
    for (final range in ranges) {
      final overlapStart = start > range.$1 ? start : range.$1;
      final overlapEnd = end < range.$2 ? end : range.$2;
      final overlapLen = overlapEnd > overlapStart
          ? overlapEnd - overlapStart
          : 0;
      final sliceLen = end - start;
      if (sliceLen > 0 && overlapLen * 2 >= sliceLen) {
        return true;
      }
    }
    return false;
  }

  /// 扫描剧情文本，匹配到已知 NPC 名字时自动标记 introduced

  @override
  void markIntroducedFromNarrative(String text) {
    if (text.isEmpty || npcRegistry.isEmpty) return;

    final ranges = signatureRanges(text);

    const interactionVerbs = [
      '见面',
      '握手',
      '介绍',
      '对视',
      '打招呼',
      '对话',
      '交谈',
      '自我介绍',
      '走进',
      '进来',
      '敲门',
      '推开',
      '开门',
      '向你走',
      '看到你',
      '来到',
      '回应你',
      '你唤',
      '你叫',
      '你问',
      '问你',
      '对你说',
      '告诉你',
      '递给你',
      '你接过',
      '你握',
      '拥抱',
      '拍肩',
      '微笑着',
      '点头',
      '行礼',
      '鞠躬',
      '一起坐',
      '坐下',
      '上楼',
      '下楼',
      '同行',
      '并肩',
      '相遇',
      '遇见',
      '碰上',
      '撞见',
      '结识',
      '认识',
      '熟悉',
    ];

    // 获取当前位置，判断玩家是否已经在霍格沃茨
    final currentLocation = worldState.currentLocation ?? '';
    final isAtHogwarts =
        currentLocation.contains('霍格沃茨') ||
        currentLocation.contains('Hogwarts') ||
        (player?.house != null && player!.house!.isNotEmpty);

    int markedThisRound = 0;
    const maxPerRound = 3; // 减少每回合最大标记数
    final npcs = npcRegistry.values.toList()
      ..sort((a, b) => b.name.length.compareTo(a.name.length));
    for (final npc in npcs) {
      if (npc.introduced) continue;
      if (markedThisRound >= maxPerRound) break;

      final hitMidpoints = <int>{};
      bool contextHasInteraction = false;

      for (final alias in npc.allNames) {
        if (alias.runes.length < 2) continue;
        if (!standaloneNameMentioned(text, alias)) continue;

        int searchFrom = 0;
        while (true) {
          final idx = text.indexOf(alias, searchFrom);
          if (idx == -1) break;

          if (inSignatureRange(idx, ranges)) {
            searchFrom = idx + alias.length;
            continue;
          }

          final midpoint = idx + (alias.length ~/ 2);
          bool isDuplicate = false;
          for (final existing in hitMidpoints) {
            if ((existing - midpoint).abs() < alias.length) {
              isDuplicate = true;
              break;
            }
          }
          if (!isDuplicate) {
            hitMidpoints.add(midpoint);
          }

          final start = idx - 100 < 0 ? 0 : idx - 100;
          final end = idx + alias.length + 100 > text.length
              ? text.length
              : idx + alias.length + 100;

          if (!sliceOverlapsSignature(start, end, ranges)) {
            final slice = text.substring(start, end);
            if (interactionVerbs.any((v) => slice.contains(v))) {
              contextHasInteraction = true;
              break;
            }
          }

          searchFrom = idx + alias.length;
        }
        if (contextHasInteraction) break;
      }

      // 只有当有明确的互动行为时才标记为已结识
      // 仅名字出现不足以证明"结识"
      if (contextHasInteraction) {
        // 关键修复：玩家在开学前（在家中/对角巷/车站等非霍格沃茨位置），
        // grade==0 的霍格沃茨教职工/幽灵/管理员不可能面对面与玩家互动，
        // 但他们的别名（如"管理员""图书馆""看门人"）在任何文本都可能被命中，
        // 必须在此阶段过滤掉 grade==0 的 NPC，避免开局就把"费尔奇/平斯/邓布利多"
        // 等教职工标记为"已结识"。
        if (!isAtHogwarts && npc.grade == 0) {
          continue;
        }

        markNpcIntroduced(npc);
        markedThisRound++;
      }
    }
  }

  /// 判断 name 是否在 text 中以「可识别方式」出现。
  /// 关键修复：中文（CJK）文本不用空格分词，因此「金妮」嵌在「捕捉到了金妮骤然...」
  /// 中间就是正常的独立出现——如果还要求前后字符不是汉字就会永远匹配失败，
  /// 造成所有 NPC 剧情里出现了但大世界永远显示「未登场 0 人」。
  ///
  /// 规则：
  ///   - 主要由 CJK 字符构成的名称（中文姓名）：只要文本 contains 就算。
  ///     另外对「姓氏两字简称」（如"韦斯莱"）加一层宽松保护：若前后紧接更多
  ///     CJK 字符构成更长真实姓名的一部分也允许匹配（剧情里常简称姓氏）。
  ///   - 主要由拉丁/数字构成的名称（英文代号）：仍执行严格边界检查，
  ///     防止 "哈利" 匹配进 "哈利波特童装店" 这种英文子串误命中场景。
  static bool standaloneNameMentioned(String text, String name) {
    if (name.isEmpty || text.isEmpty) return false;

    // 统计 name 中 CJK 字符比例
    int cjkCount = 0;
    for (final code in name.codeUnits) {
      if ((code >= 0x4E00 && code <= 0x9FFF) ||
          (code >= 0x3400 && code <= 0x4DBF)) {
        cjkCount++;
      }
    }
    final mostlyCjk = cjkCount * 2 >= name.length; // ≥50% 字符是 CJK 视为中文名称

    if (mostlyCjk) {
      // 中文名称：只要包含即可出现即算。
      // 故事文本里出现「了金妮骤」「·韦斯莱僵」这种就是角色名字正常出现，
      // 中文不用空格分词，不存在"嵌在更长词组里就不算"的问题。
      return text.contains(name);
    }

    // ====== 拉丁/数字为主的名称：走严格边界检查 ======

    bool isBoundary(int charCode) {
      if (charCode == 0) return true;
      if ((charCode >= 0x4E00 && charCode <= 0x9FFF) ||
          (charCode >= 0x3400 && charCode <= 0x4DBF)) {
        return true; // CJK 对英文名字天然视作分隔
      }
      if ((charCode >= 0x41 && charCode <= 0x5A) ||
          (charCode >= 0x61 && charCode <= 0x7A) ||
          (charCode >= 0xFF21 && charCode <= 0xFF3A) ||
          (charCode >= 0xFF41 && charCode <= 0xFF5A) ||
          (charCode >= 0x30 && charCode <= 0x39) ||
          (charCode >= 0xFF10 && charCode <= 0xFF19)) {
        return false;
      }
      if (charCode == 0x00B7 ||
          charCode == 0x2022 ||
          charCode == 0x2D ||
          charCode == 0x5F) {
        return false;
      }
      return true;
    }

    int idx = 0;
    while (true) {
      idx = text.indexOf(name, idx);
      if (idx == -1) return false;
      final before = idx == 0 ? 0 : text.codeUnitAt(idx - 1);
      final after = idx + name.length >= text.length
          ? 0
          : text.codeUnitAt(idx + name.length);
      if (isBoundary(before) && isBoundary(after)) return true;
      idx += name.length;
    }
  }
}
