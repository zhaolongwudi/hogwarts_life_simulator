import 'dart:async';
import 'package:flutter/widgets.dart';
import '../providers/app_provider.dart';
import '../models/npc.dart';
import '../models/game_systems.dart';
import '../utils/story_text_renderer.dart';
import '../services/ai_router.dart';
import '../providers/game_provider_base.dart';
import '../prompts/choice_prompts.dart';

mixin GameResponseMixin on GameProviderBase {
  void _tryExtractHouseFromNarrative(String text) {
    if (player == null || player!.house != null) return;
    const houseGroup = '格兰芬多|斯莱特林|拉文克劳|赫奇帕奇'
        '|Gryffindor|Slytherin|Ravenclaw|Hufflepuff';

    // 1. 强语境：必须出现"分院动作词"
    final hasSortingAction = RegExp(
      r'分到|分进|被分到|被分进|进入了|进了|戴上分院帽'
      r'|分院帽.*喊出|分院帽.*叫道|分院帽.*说|分院帽.*唱'
      r'|Sorting\s*Hat|hat\s*(?:said|shouted|sang)',
      caseSensitive: false,
    ).hasMatch(text);

    // 1b. 兜底强信号：分院帽说话模式 + 分院语境同时出现
    final hasContext = RegExp(
      r'分院|分院帽|大礼堂|长桌|四大学院|入学典礼',
      caseSensitive: false,
    ).hasMatch(text);

    if (!hasSortingAction) {
      final hatShout = RegExp(
        '($houseGroup)\\s*[\uff01!]{2,}',
        caseSensitive: false,
      ).hasMatch(text);
      if (!(hasContext && hatShout)) return;
    }

    // 2. 匹配学院名（三级优先级）
    final housePatterns = <Pattern>[
      // 紧邻动作词：分到/分进/被分到/被分进/进入了 XX
      RegExp(
        '(?:分到|分进|被分到|被分进|进入了|进了)\\s*($houseGroup)',
        caseSensitive: false,
      ),
      // 分院帽说话：引号包裹 + 连续感叹号
      RegExp(
        '["\']?($houseGroup)\\s*[\uff01!]{2,}["\']?',
        caseSensitive: false,
      ),
      // 明确"XX学院"且上文已判定为分院语境
      RegExp(
        '($houseGroup)\\s*学院',
        caseSensitive: false,
      ),
    ];

    String? matched;
    for (final pat in housePatterns) {
      if (pat is RegExp) {
        final m = pat.firstMatch(text);
        if (m != null && m.groupCount >= 1) {
          matched = m.group(1);
          if (matched != null) break;
        }
      }
    }
    if (matched == null) return;

    const cnToEn = <String, String>{
      '格兰芬多': 'Gryffindor',
      '斯莱特林': 'Slytherin',
      '拉文克劳': 'Ravenclaw',
      '赫奇帕奇': 'Hufflepuff',
    };
    final normalized = matched.toLowerCase();
    String? en;
    for (final e in cnToEn.entries) {
      if (e.key == matched || e.value.toLowerCase() == normalized) {
        en = e.value;
        break;
      }
    }
    en ??= '${matched[0].toUpperCase()}${matched.substring(1).toLowerCase()}';

    player!.house = en;
    unlockAchievement('sorted');
    debugPrint('⚡ 分院结果自动提取：${player!.house}（匹配到 "$matched"）');
  }

  /// 只解析叙事文本（不含选项），用于独立选项生成模式

  void parseNarrativeOnly(String text) {
    currentNarrative = '';
    choices = [];

    // 移除结构化区块（选项、好感、声望等）
    var cleaned = text;
    cleaned = cleaned.replaceAllMapped(GameProviderBase.reAffectionSection, (m) => '');
    cleaned = cleaned.replaceAllMapped(GameProviderBase.reReputationSection, (m) => '');

    const stripSections = [
      '可选行动', '自由行动', '行动建议', '备选行动',
      '剧情选项', '下回合选择', '选择建议',
    ];
    for (final section in stripSections) {
      final pat = RegExp(r'【' + RegExp.escape(section) + r'】[\s\S]*?(?=【|$)');
      cleaned = cleaned.replaceAllMapped(pat, (m) => '');
    }

    // 移除选项行（A.xxx, B.xxx 等）
    final lines = cleaned.split('\n');
    final narrativeLines = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      // 跳过选项格式的行
      if (GameProviderBase.reChoiceOption.hasMatch(trimmed)) {
        continue;
      }
      narrativeLines.add(line);
    }

    var narrative = narrativeLines.join('\n');

    // 清理多余空行
    narrative = narrative.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

    // 自动段落排版
    narrative = StoryTextRenderer.autoParagraph(narrative);

    currentNarrative = narrative;

    // 提取好感区块用于UI显示
    final extracted = StoryTextRenderer.extractAffectionSections(text);
    lastAffectionSections = extracted['affectionSections'] as List<String>? ?? [];

    // 解析好感和声望变化（从原始文本）
    _parseAffectionChanges(text);
    _parseReputationChanges(text);

    // 标记NPC登场
    if (markScanIfNew(currentNarrative)) markIntroducedFromNarrative(currentNarrative);

    // 分院结果自动提取（使用带语境判断的公共函数）
    _tryExtractHouseFromNarrative(text);
  }

  void parseResponse(String text) {
    final lines = text.split('\n');
    currentNarrative = '';
    choices = [];
    // 标记是否遇到过显式的【叙事】标题：遇到后严格按结构化走，
    // 否则走"整段正文直到选项区块开始之前"的宽松模式
    bool sawExplicitNarrativeMarker = false;
    bool inNarrative = false;
    // 显式区块（选项/好感/声望）之后就不再把后面的任何文字当正文
    bool anyExplicitBlockPassed = false;
    // 新增：连续选项计数，防止正文中的选项格式被误识别
    int consecutiveChoiceLines = 0;
    // 新增：正文最小长度阈值，低于此值不触发选项区切换
    const minNarrativeLength = 50;

    // Pass 1: Try structured parsing with explicit markers
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed == '【叙事】' || trimmed == '【剧情】' || trimmed == '【正文】') {
        sawExplicitNarrativeMarker = true;
        inNarrative = true;
        anyExplicitBlockPassed = false;
        consecutiveChoiceLines = 0;
        continue;
      }

      final isBlockHeader = trimmed.startsWith('【可选行动】') ||
          trimmed.startsWith('【自由行动】') ||
          trimmed.startsWith('【行动建议】') ||
          trimmed.startsWith('【备选行动】') ||
          trimmed.startsWith('【剧情选项】') ||
          trimmed.startsWith('【好感度变化】') ||
          trimmed.startsWith('【好感变化】') ||
          trimmed.startsWith('【声望变化】');
      if (isBlockHeader) {
        inNarrative = false;
        anyExplicitBlockPassed = true;
        consecutiveChoiceLines = 0;
        continue;
      }

      if (inNarrative) {
        // 在【叙事】块内部：除了好感度独立行外全收
        if (trimmed.isNotEmpty) {
          currentNarrative += '$line\n';
        } else {
          currentNarrative += '\n';
        }
        consecutiveChoiceLines = 0;
      } else if (!sawExplicitNarrativeMarker && !anyExplicitBlockPassed) {
        // 没有出现过显式【叙事】标题，且尚未进入任何结构化区块：
        // 这一段默认按正文处理（AI忘写标题的情况最常见）
        if (GameProviderBase.reChoiceOption.hasMatch(trimmed)) {
          // 关键修复：只有当正文已经足够长（>50字）且连续2行都是选项格式时
          // 才认为进入选项区，防止正文中的选项格式被误识别
          if (currentNarrative.trim().length >= minNarrativeLength) {
            consecutiveChoiceLines++;
            if (consecutiveChoiceLines >= 2) {
              anyExplicitBlockPassed = true;
              final rawAction = trimmed.replaceFirst(GameProviderBase.reChoiceOption, '').trim();
              final action = sanitizeChoiceText(rawAction);
              if (action.isNotEmpty) {
                choices.add(GameChoice(text: action, action: action));
              }
            } else {
              // 第一行选项格式，暂时仍当作正文处理（可能是剧情描述）
              if (trimmed.isNotEmpty) {
                currentNarrative += '$line\n';
              } else {
                currentNarrative += '\n';
              }
            }
          } else {
            // 正文太短，可能是开局或错误，仍然按选项处理
            anyExplicitBlockPassed = true;
            final rawAction = trimmed.replaceFirst(GameProviderBase.reChoiceOption, '').trim();
            final action = sanitizeChoiceText(rawAction);
            if (action.isNotEmpty) {
              choices.add(GameChoice(text: action, action: action));
            }
          }
        } else {
          consecutiveChoiceLines = 0;
          if (trimmed.isNotEmpty) {
            currentNarrative += '$line\n';
          } else {
            currentNarrative += '\n';
          }
        }
      } else if (GameProviderBase.reChoiceOption.hasMatch(trimmed)) {
        // 在显式选项区块之后，逐行收集选项
        final rawAction = trimmed.replaceFirst(GameProviderBase.reChoiceOption, '').trim();
        final action = sanitizeChoiceText(rawAction);
        if (action.isNotEmpty && choices.length < 6) {
          choices.add(GameChoice(text: action, action: action));
        }
      }
    }

    // 检测并截断"下回合泄漏"：如果正文中包含新的📅时间戳，
    // 说明 AI 把下回合的预告也输出了，需要截断
    final timestampPattern = RegExp(r'📅\s*\d{4}年\d{1,2}月\d{1,2}日');
    final narrativeLines = currentNarrative.split('\n');
    final truncatedLines = <String>[];
    bool foundSecondTimestamp = false;
    for (final line in narrativeLines) {
      if (foundSecondTimestamp) break;
      if (timestampPattern.hasMatch(line.trim())) {
        if (truncatedLines.isNotEmpty) {
          foundSecondTimestamp = true;
          break;
        }
      }
      truncatedLines.add(line);
    }
    if (foundSecondTimestamp) {
      currentNarrative = truncatedLines.join('\n').trimRight();
    }

    // Pass 2: 如果叙事 < 20 字，按"原始文本 - 好感/声望 - 选项区块"兜底提取，
    // 但注意兜底函数 _extractNarrativeFromRawText 已经不再做 split('\n\n').first
    // 的毁灭性截断，所以即使走到这里也能保住长文。
    if (currentNarrative.trim().length < 20) {
      _extractNarrativeFromRawText(text);
    }

    // 先提取好感变化区块（用于独立卡片显示）
    final extracted = StoryTextRenderer.extractAffectionSections(text);
    lastAffectionSections = extracted['affectionSections'] as List<String>? ?? [];
    var narrativeForDisplay = extracted['narrative'] as String? ?? currentNarrative;

    narrativeForDisplay = narrativeForDisplay.replaceAllMapped(
      RegExp(r'【好感(?:度)?变化?】[\s\S]*?(?=【|$)'), (m) => '');
    narrativeForDisplay = narrativeForDisplay.replaceAllMapped(
      RegExp(r'【声望变化?】[\s\S]*?(?=【|$)'), (m) => '');
    narrativeForDisplay = narrativeForDisplay.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    narrativeForDisplay = narrativeForDisplay.replaceAllMapped(
      RegExp(r'【可选行动】[\s\S]*$'), (m) => '').trimRight();
    narrativeForDisplay = narrativeForDisplay.replaceAllMapped(
      RegExp(r'【自由行动】[\s\S]*$'), (m) => '').trimRight();

    // 自动段落排版（为无分行的 AI 输出插入合理段落）
    narrativeForDisplay = StoryTextRenderer.autoParagraph(narrativeForDisplay);
    narrativeForDisplay = narrativeForDisplay
        .replaceAll(GameProviderBase.reMultiNewline, '\n\n')
        .trim();

    currentNarrative = narrativeForDisplay;

    // Pass 3: 若依然正文为空，才生成兜底叙事（兜底叙事的特点：短、单段、以📅开头）
    if (currentNarrative.isEmpty) {
      currentNarrative = generateFallbackNarrative();
    }

    // Parse affection changes（总是从完整原始响应解析，而不是从裁剪后的正文中解析）
    _parseAffectionChanges(text);

    // Parse reputation changes
    _parseReputationChanges(text);

    // 根据剧情文本中出现的人名，标记 NPC 为已登场（让世界页和通讯列表更准确）
    if (markScanIfNew(currentNarrative)) markIntroducedFromNarrative(currentNarrative);

    if (choices.isEmpty) {
      // 先尝试从原始文本中智能提取选项（防止解析逻辑遗漏）
      final extractedChoices = _extractChoicesFromRawText(text);
      if (extractedChoices.isNotEmpty) {
        choices.addAll(extractedChoices);
      } else {
        // 最后才使用兜底选项（但现在也基于剧情生成，而不是静态位置选项）
        choices.addAll(generateContextualFallbackChoices());
      }
    }
    // 避免出现过多选项：裁剪到 4 个
    if (choices.length > 4) {
      choices = choices.sublist(0, 4);
    }

    // 选项质量清理：移除不合格的选项（含残余markdown/图片/过长）
    final beforeClean = choices.length;
    choices.removeWhere((c) => !isChoiceQualityAcceptable(c.text));
    if (choices.length < beforeClean) {
      debugPrint('选项质量清理: ${beforeClean}→${choices.length} (移除含markdown/图片的不合格选项)');
    }
    // 如果清理后选项不足，补充兜底选项
    if (choices.isEmpty) {
      choices.addAll(_buildFallbackChoices(currentNarrative));
    }

    if (turnCount > 0 && (turnCount % 5 == 0 || lastPlayerAction.contains(RegExp(r'(与|和|跟|找|邀|问|对话|聊天|约会|见面|散步|陪|一起|独处|深入|表白|感情|心动)')))) {
      checkNPCConfessions();
    }

    checkSkillAchievements();
    checkWorldChangerAchievement();
    checkWarHeroAchievement();

    // 每10回合增加少量世界线变动率
    if (turnCount % 10 == 0) {
      incrementWorldLineDeviation(0.005);
    }

    // 分院结果自动提取（开局叙事通过 parseResponse，必须也走这里）
    _tryExtractHouseFromNarrative(text);

    notifyListeners();
  }

  void _extractNarrativeFromRawText(String text) {
    var cleaned = text;

    // 1. 先删【好感度变化】和【声望变化】整块（它们是结构化输出区块，不属于正文叙事）
    cleaned = cleaned.replaceAllMapped(GameProviderBase.reAffectionSection, (m) => '');
    cleaned = cleaned.replaceAllMapped(GameProviderBase.reReputationSection, (m) => '');

    // 2. 删除其他已知结构化区块（整体移除，连同标题行一起）
    const stripSections = [
      '可选行动', '自由行动', '行动建议', '备选行动',
      '剧情选项', '下回合选择', '选择建议',
    ];
    for (final s in stripSections) {
      // 从出现 【$s】 或 行首 $s： 开始，到下一个【 标题 或 末尾结束
      final pat = RegExp(
        r'(?:【' + RegExp.escape(s) + r'】|^\s*' + RegExp.escape(s) + r'\s*[：:])[\s\S]*?(?=\n【|$)',
        multiLine: true,
      );
      cleaned = cleaned.replaceAllMapped(pat, (m) => '');
    }

    // 3. 找到「选项区块」的起点：某一行以「A./B./1./一、A)」开头且后面是文字
    //    把起点之后的内容全部认为是选项而丢弃
    final choiceMatch = GameProviderBase.reChoiceMultiLine.firstMatch(cleaned);
    if (choiceMatch != null) {
      int end;
      if (choiceMatch.group(0)!.startsWith('\n')) {
        end = choiceMatch.start + 1; // 保留换行，让正文末尾完整
      } else {
        end = choiceMatch.start;
      }
      cleaned = cleaned.substring(0, end);
    }
    // 注意：已经不再用 split('\n\n').first 这种会把正文长文裁成第一段的危险做法
    // 叙事区的完整性对游戏体验至关重要（哪怕读回带残留文字，总比丢剧情强）

    // 4. 去掉【章节标题】等方括号记号但保留文字内容之间的空行
    cleaned = cleaned
        .replaceAllMapped(RegExp(r'^【[^】\n]*】\s*$', multiLine: true), (m) => '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    if (cleaned.isNotEmpty && cleaned.length > 10) {
      currentNarrative = cleaned;
    }
  }

  String generateFallbackNarrative() {
    final p = player;
    if (p == null) return '你站在霍格沃茨的走廊上，等待着下一段旅程。';

    final location = worldState.currentLocation ?? '霍格沃茨';
    final time = worldState.timestamp;
    final weather = worldState.weather ?? '晴朗';

    final fallbacks = [
      '📅 $time\n\n你在$location，感受着魔法世界的脉搏。周围的一切都在等待你的下一步行动。',
      '📅 $time\n\n$location的空气中弥漫着魔法的气息。$weather的天气让人想继续探索这个奇妙的世界。',
      '📅 $time\n\n作为一名${p.grade}年级的学生，你在$location经历着霍格沃茨的又一天。每件事都可能改变故事的走向。',
      '📅 $time\n\n${p.name}，你身处$location。接下来会发生什么，完全取决于你的选择。',
    ];

    final idx = turnCount % fallbacks.length;
    return fallbacks[idx];
  }

  List<GameChoice> generateFallbackChoices() {
    final location = worldState.currentLocation ?? '霍格沃茨';

    final locationChoices = {
      '霍格沃茨': [
        ('去教室上课', '前往教室学习'),
        ('在走廊散步', '在走廊里走动'),
        ('去大礼堂', '前往大礼堂'),
        ('找朋友聊天', '与朋友交谈'),
      ],
      '霍格莫德村': [
        ('去三把扫帚酒吧', '前往三把扫帚'),
        ('逛蜂蜜公爵糖果店', '去糖果店'),
        ('拜访邮局', '去邮局寄信'),
        ('返回霍格沃茨', '回到学校'),
      ],
      '对角巷': [
        ('去魔杖店', '前往奥利凡德'),
        ('逛魔法部', '去魔法部'),
        ('去古灵阁', '去古灵阁银行'),
        ('返回霍格沃茨', '回到学校'),
      ],
      '禁林': [
        ('小心深入探索', '深入禁林'),
        ('观察神奇生物', '观察生物'),
        ('原路返回', '返回安全区'),
        ('寻找光源', '寻找光源'),
      ],
    };

    final options = locationChoices[location] ?? [
      ('继续前进', '继续探索'),
      ('仔细观察', '观察周围'),
      ('与人交谈', '和周围的人交流'),
      ('返回原地', '回到之前的位置'),
    ];

    final idx = turnCount % options.length;
    final rotated = [
      options[idx],
      options[(idx + 1) % options.length],
      options[(idx + 2) % options.length],
    ];

    return rotated
        .map((e) => GameChoice(text: e.$1, action: e.$2))
        .toList();
  }

  /// 从AI原始响应文本中智能提取选项（用于解析失败后的兜底提取）

  /// 清理选项文本中的 markdown 图片/链接/HTML 标签/Emoji/乱码
  /// 防止 AI 返回形如 `A. ![图](url) 仔细查看` 导致选项显示异常
  /// 采用两遍扫描确保彻底清除嵌套格式
  static String sanitizeChoiceText(String raw) {
    var s = raw.trim();

    // === 第一遍：清除结构化 Markdown ===
    // 删markdown图片 ![alt](url) 或 ![alt][ref]
    s = s.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'!\[[^\]]*\]\[[^\]]*\]', caseSensitive: false), '');
    // 删markdown链接 [text](url) → text (保留文字)
    s = s.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)', caseSensitive: false), (m) => m.group(1) ?? '');
    // 删裸URL
    s = s.replaceAll(RegExp(r'https?://\S+', caseSensitive: false), '');
    // 删base64图片
    s = s.replaceAll(RegExp(r'data:image/[^;]+;base64,[^\s)]+', caseSensitive: false), '');
    // 删HTML <img> 标签
    s = s.replaceAll(RegExp(r'<img\s[^>]*>', caseSensitive: false), '');
    // 删HTML <a> 标签（保留文字）
    s = s.replaceAllMapped(RegExp(r'<a[^>]*>([\s\S]*?)</a>', caseSensitive: false), (m) {
      final inner = m.group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '';
      return inner;
    });
    // 删所有HTML标签
    s = s.replaceAll(RegExp(r'</?[^>]+>', caseSensitive: false), '');
    // 删inline markdown粗体/斜体/删除线
    s = s.replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m.group(1) ?? '');
    s = s.replaceAllMapped(RegExp(r'(?<!\*)\*([^*]+)\*(?!\*)'), (m) => m.group(1) ?? '');
    s = s.replaceAllMapped(RegExp(r'~~([^~]+)~~'), (m) => m.group(1) ?? '');
    // 删inline代码
    s = s.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m.group(1) ?? '');
    // 删HTML实体
    s = s.replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&quot;', '"').replaceAll('&#39;', "'");
    // 删反斜杠转义
    s = s.replaceAllMapped(RegExp(r'\\([\\`*_{}\[\]()#+\-.!])'), (m) => m.group(1) ?? '');

    // === 第二遍：清除第一遍可能残留的破坏结构 ===
    // 再次扫描残留的markdown图片/链接（处理嵌套情况）
    s = s.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)', caseSensitive: false), '');
    s = s.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)', caseSensitive: false), (m) => m.group(1) ?? '');
    // 清除孤立的方括号（如图片删除后残留的 [alt]）
    s = s.replaceAll(RegExp(r'\[[^\]]*\]', caseSensitive: false), '');
    // 清除孤立的星号（如粗体删除后残留的 *）
    s = s.replaceAll(RegExp(r'\*+', caseSensitive: false), '');
    // 清除反引号
    s = s.replaceAll(RegExp(r'`+'), '');
    // 清除孤立的下划线
    s = s.replaceAll(RegExp(r'_{2,}'), '');
    // 清除Emoji和零宽字符（保留中文标点和常用符号）
    // 注意：Dart 正则不支持高位 Unicode 范围如 [\u{1F300}-\u{1F9FF}]，
    // 必须使用 runes 手动过滤，否则会抛 FormatException 导致整页崩溃
    final runes = s.runes.toList();
    final filtered = StringBuffer();
    for (final rune in runes) {
      // 跳过 Emoji 范围 (U+1F300 ~ U+1FAFF)
      if (rune >= 0x1F300 && rune <= 0x1FAFF) continue;
      // 跳过零宽字符 (U+200B ~ U+200D, U+FEFF)
      if ((rune >= 0x200B && rune <= 0x200D) || rune == 0xFEFF) continue;
      filtered.writeCharCode(rune);
    }
    s = filtered.toString();

    // === 最终清理 ===
    s = s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    // 单行限制
    if (s.length > 100) s = '${s.substring(0, 97).trim()}...';
    return s;
  }

  /// 验证选项文本质量：sanitize后不应包含残余markdown/图片/异常格式
  /// 返回 true 表示质量合格，false 表示需要重试
  static bool isChoiceQualityAcceptable(String text) {
    if (text.isEmpty || text.length < 2) return false;
    // 检查残余markdown图片语法
    if (RegExp(r'!\[.*\]\(', caseSensitive: false).hasMatch(text)) return false;
    // 检查残余markdown链接
    if (RegExp(r'\[.*\]\(.*\)', caseSensitive: false).hasMatch(text)) return false;
    // 检查孤立的方括号（可能是未清除的markdown残留）
    if (RegExp(r'\[[^\]]+\]', caseSensitive: false).hasMatch(text)) return false;
    // 检查base64图像数据
    if (RegExp(r'data:image/', caseSensitive: false).hasMatch(text)) return false;
    // 检查HTML标签
    if (RegExp(r'<\s*(img|a|div|span|p|br|hr)\b', caseSensitive: false).hasMatch(text)) return false;
    // 检查内联markdown标记（粗体、斜体、删除线、代码）
    if (RegExp(r'\*\*.*\*\*').hasMatch(text)) return false;
    if (RegExp(r'`[^`]+`').hasMatch(text)) return false;
    if (RegExp(r'~~.+~~').hasMatch(text)) return false;
    // 检查裸URL
    if (RegExp(r'https?://', caseSensitive: false).hasMatch(text)) return false;
    // 检查过长
    if (text.length > 150) return false;
    return true;
  }

  List<GameChoice> _extractChoicesFromRawText(String text) {
    final choices = <GameChoice>[];
    final lines = text.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final match = GameProviderBase.reChoiceOption.firstMatch(trimmed);
      if (match != null) {
        final rawAction = trimmed.replaceFirst(GameProviderBase.reChoiceOption, '').trim();
        final action = sanitizeChoiceText(rawAction);
        if (action.isNotEmpty && action.length >= 2) {
          choices.add(GameChoice(text: action, action: action));
        }
      }

      if (choices.length >= 4) break;
    }

    return choices;
  }

  /// 最终兜底选项：当AI连续失败时，基于当前剧情生成4个合理选项
  /// 兜底选项（严格基于「剧情末尾800字」生成，不能输出"仔细观察/面对情况"这种会断链的空选项）
  ///
  /// 触发时机：选项 AI 生成超时(20s) / 返回内容不合格 / 网络异常。
  /// 核心原则：从「剧情最末尾的最后一位说话者 / 最后一个未完成动作 / 最后一个氛围钩子」出发，
  ///          产出 A(勇敢/主动) B(谨慎/观察) C(人际/沟通) D(取巧/隐忍) 四个风格，
  ///          玩家点任何一个都会让剧情**自然衔接**，不会出现"选了仔细查看 → 下回合叙事完全跳场景"的断链。
  List<GameChoice> _buildFallbackChoices(String narrative) {
    final p = player;
    final energy = p?.energy ?? 100;
    final location = worldState.currentLocation ?? '';
    final atHome = location.contains('家中') || location.contains('卧室') || location.contains('客厅') || location.contains('餐厅');
    final isNight = worldState.timestamp.contains('深夜') ||
        worldState.timestamp.contains('晚间') ||
        worldState.timestamp.contains('黄昏');
    final tail = narrative.length > 800 ? narrative.substring(narrative.length - 800) : narrative;

    // ---------- Step 1: 从末尾 800 字抓最后一位说话者 + 最后一句对话关键词 ----------
    String? lastSpeaker;
    String? lastDialogTopic;
    final afterQuoteRe = RegExp(
      r'[」"】][^，。！？\n]*?(养母|养父|海格|邓布利多|斯内普|麦格|哈利|罗恩|赫敏|马尔福|教授|同学|级长|妈妈|爸爸|NPC)[^，。！？\n]{0,10}(说|开口|问|道|回答|叹了口气|笑了笑|低声|沉声|看着你)',
      caseSensitive: false,
    );
    final aqm = afterQuoteRe.allMatches(tail);
    if (aqm.isNotEmpty) lastSpeaker = aqm.last.group(1);
    final dialogRe = RegExp(r'[「"]([^「"」]{2,40})[」"]', caseSensitive: false);
    final dm = dialogRe.allMatches(tail);
    if (dm.isNotEmpty) lastDialogTopic = dm.last.group(1);

    // ---------- Step 2: 抓末尾的未完成动作钩子 ----------
    final hookPacking = tail.contains('收拾') || tail.contains('行李') || tail.contains('整理');
    final hookLeaving = tail.contains('早点休息') || tail.contains('明天') || tail.contains('出发') || tail.contains('车票') || tail.contains('站台');
    final hookGoodbye = tail.contains('圣诞节') || tail.contains('答应我') || tail.contains('一定要回来') || tail.contains('告别') || tail.contains('舍不得');
    final hookAnswer = tail.contains('等你回答') || tail.contains('你的选择') || tail.contains('打算怎么做') || tail.contains('那你打算') || (lastSpeaker != null && (lastDialogTopic?.contains('吗') ?? false));
    final hookDoor = tail.contains('敲门') || tail.contains('敲门声') || tail.contains('门外');
    final hookLetter = tail.contains('录取通知书') || tail.contains('信封') || tail.contains('霍格沃茨的') || tail.contains('羊皮纸');

    final fallback = <GameChoice>[];

    // ---- A 勇敢/主动型 ----
    if (hookGoodbye) {
      fallback.add(GameChoice(
          text: '和养父母认真告别后收拾行李，明天一早前往国王十字车站',
          action: '和养父母认真拥抱告别，随即开始收拾行李，确认车票、魔杖和加隆都已入箱，准备明天前往国王十字车站的九又四分之三站台'));
    } else if (hookAnswer) {
      fallback.add(GameChoice(
          text: '正面回应「${lastSpeaker ?? '对方'}」的问题，说出你的真实想法',
          action: '直面${lastSpeaker ?? '对方'}的提问，坦诚回答你对${lastDialogTopic ?? '这件事'}的真实想法和接下来的打算'));
    } else if (hookPacking || hookLeaving) {
      fallback.add(GameChoice(
          text: '立刻收拾行李，和家人道晚安后为明天出发做最后确认',
          action: '立刻动手收拾行李，把魔杖匣、课本和换洗衣物装好，去和养父母道晚安，最后确认一遍车票与加隆，准备明天一早前往九又四分之三站台'));
    } else if (hookDoor) {
      fallback.add(GameChoice(text: '立刻过去开门，看看门外究竟是谁', action: '深吸一口气，快步走向大门，握住门把手直接打开看看门外到底是谁'));
    } else if (hookLetter) {
      fallback.add(GameChoice(
          text: '当着养父母的面拆开录取通知书并仔细阅读全文',
          action: '当着养父母的面撕开火漆，把霍格沃茨录取通知书从头到尾读完，确认开学日期、采购清单和九又四分之三站台说明'));
    } else if (energy < 25) {
      fallback.add(GameChoice(text: '先抓紧休息恢复精神体力', action: '不再逞强，找个安全的地方坐下或躺下休息，先把精力恢复到可行动水平再做下一步'));
    } else {
      fallback.add(GameChoice(text: '主动面对眼前状况并迈出第一步', action: '不再犹豫，鼓起勇气直接面对当前的局面，立刻着手处理最紧急的那件事'));
    }

    // ---- B 谨慎/观察/智取 ----
    if (hookAnswer) {
      fallback.add(GameChoice(
          text: '不急于回答，先反问「${lastSpeaker ?? '对方'}」几个关键细节再决定',
          action: '先不动声色地反问${lastSpeaker ?? '对方'}两个关于${lastDialogTopic ?? '这件事'}的具体细节，确认信息完全后再做出稳妥的回应'));
    } else if (hookPacking) {
      fallback.add(GameChoice(
          text: '先列一张行李清单检查不落下必需品，再慢慢收拾',
          action: '拿羊皮纸列出开学必需品清单：魔杖、课本、袍子、加隆、私人物品，逐一核对后再动手收拾，确保不落下关键物件'));
    } else if (hookDoor) {
      fallback.add(GameChoice(
          text: '先从门缝/猫眼确认来人，再决定开门与否',
          action: '先不急着开门，从门缝或猫眼确认一下门外的人是谁、带什么东西，确认安全后再决定是否开门'));
    } else if (hookLetter) {
      fallback.add(GameChoice(
          text: '先收好信不声张，观察养父母的反应再决定下一步',
          action: '不动声色地把录取信先收进怀里，先观察养父母的表情和态度，揣摩他们知道多少内情再决定怎么谈'));
    } else {
      fallback.add(GameChoice(text: '先沉默观察几秒钟，理清所有信息再行动', action: '先不要急着做决定，安静观察周围的人和环境，把已知信息理一遍再选最稳妥的行动'));
    }

    // ---- C 人际/沟通/结盟 ----
    if (lastSpeaker != null) {
      fallback.add(GameChoice(
          text: '和「$lastSpeaker」坐下来好好聊清楚${lastDialogTopic ?? '接下来的打算'}再决定',
          action: '拉着$lastSpeaker坐下来，把关于${lastDialogTopic ?? '接下来的安排'}的顾虑、担忧、期望都聊清楚，先把双方理解对齐再行动'));
    } else if (hookGoodbye || hookLeaving) {
      fallback.add(GameChoice(
          text: '坐下来和养父母吃最后一顿晚饭，聊聊对魔法界的担忧与期待',
          action: '先不急着收拾，坐到餐桌边陪养父母再吃一顿饭（哪怕是凉的），把彼此对魔法界的担忧和期待都说出来，给家人一个安心的告别'));
    } else if (atHome) {
      fallback.add(GameChoice(text: '去找养父母或家人聊聊，确认他们的看法和建议', action: '去找养父母或家里最信任的亲人聊一聊，问他们对这件事的真实想法和建议，再决定下一步怎么走'));
    } else {
      fallback.add(GameChoice(text: '找附近熟悉的NPC了解情况再做判断', action: '先和周围看起来面善或认识的NPC聊两句，确认一下当前事态、别人都在做什么，避免自己信息不足做错决定'));
    }

    // ---- D 取巧/隐忍/代价型 ----
    if (hookPacking || hookLeaving) {
      fallback.add(GameChoice(
          text: '先把最重要的魔杖和车票揣进内袋，其余物品明天清早再收拾',
          action: '不做全面打包，只把魔杖匣子、车票和大面额加隆贴身收好，其余衣物课本留到明天清晨再装，先睡一觉保证明天出发时精神饱满'));
    } else if (hookAnswer) {
      fallback.add(GameChoice(
          text: '对「${lastSpeaker ?? '对方'}」的问题先模糊应付，保留信息差不亮底牌',
          action: '面对${lastSpeaker ?? '对方'}关于${lastDialogTopic ?? '这件事'}的提问，先模糊点头/打哈哈应付过去，不把自己真实想法和底牌亮出来，给自己留后路'));
    } else if (hookDoor) {
      fallback.add(GameChoice(
          text: '假装不在房间/没听见，先躲在一边观察外面动静再决定',
          action: '先假装屋里没人、不去开门，悄悄躲在门后或窗边听外面的脚步声/说话声，确认安全情况再做进一步打算'));
    } else if (atHome && isNight) {
      fallback.add(GameChoice(text: '借口很累先去睡，明早趁家人不注意偷偷出发', action: '借口精神不济先回房间休息，悄悄把最重要的行李整理好，第二天清早趁家人还没睡醒就拿着车票和加隆悄然出发'));
    } else {
      fallback.add(GameChoice(text: '暂时隐忍不表态，等时机更成熟再出手', action: '把情绪压下去，不急于表明立场也不急于行动，先观察局势变化，等对自己最有利的时机出现再出手'));
    }

    // 保险：裁剪/补齐到 4 条
    if (fallback.length > 4) fallback.removeRange(4, fallback.length);
    if (fallback.length < 4) {
      fallback.add(GameChoice(text: '先在脑中过一遍所有后果，再选择最稳妥的做法', action: '把接下来可选动作的各种后果在脑子里快速过一遍，评估风险后再选最稳妥的那一步'));
    }
    while (fallback.length < 4) {
      fallback.add(GameChoice(text: '冷静下来整理思路后再决定下一步', action: '先深呼吸让情绪平稳下来，把已知的事实、未知的风险、自己的目标整理清楚，再继续下一步'));
    }
    return fallback;
  }

  /// 独立生成选项：接收已生成的剧情文本，让 AI 专门基于此生成选项
  Future<List<GameChoice>> generateChoicesSeparately(String narrative) async {
    if (router == null) return [];

    final p = player!;
    final currentLoc = worldState.currentLocation ?? '';
    final timestamp = worldState.timestamp;
    final playerAction = lastPlayerAction;

    // 只取叙事末尾 800 字作为选项依据——重点在「结尾的即时动作/最后一位说话者/场面氛围」
    // 选项必须直接承接这一刻，不得跨越到下一节课/明天/下一个地点。
    final narrativeTail = narrative.length > 800
        ? '…（前略，以下为当前剧情的最末尾800字，请严格按结尾最后几行生成选项）\n' + narrative.substring(narrative.length - 800)
        : narrative;

    // ---- 注入玩家硬状态：避免生成不可能的选项 ----
    // Player 真实字段：grade(int? 年级), house(String?), health, energy, galleons, bankGalleons
    final grade = p.grade ?? 0;
    final yearLabel = grade > 0 && grade <= 7 ? '${grade}年级' : '新生';
    final houseVal = p.house;
    final houseText = (houseVal != null && houseVal.isNotEmpty)
        ? '学院：$houseVal'
        : '学院：未分院';
    final healthText = '生命：${p.health}/100';
    final energyText = '精力：${p.energy}/100（${p.energy < 25 ? '极低，高强度动作会失败' : p.energy < 50 ? '偏低，避免持久战' : '充足'}）';
    final galleonsText = '加隆：${p.galleons}·古灵阁存${p.bankGalleons}';

    // 学会的魔法（SpellLevel是带level int的对象，不是enum；0=入门 1=基础 2=熟练 3=精通 4=大师）
    // level >= 2 视为可在战斗/高风险场景中使用的魔法  2026-08-23：6→12
    final knownSpells = p.learnedSpells.entries
        .where((e) => e.value.level >= 2)
        .take(12)
        .map((e) => e.key)
        .toList();
    final spellsText = knownSpells.isEmpty
        ? '已知魔法：只会基本入门（荧光闪烁、开锁等）'
        : '已知魔法：${knownSpells.join('、')}';

    // 背包中值得一提的物品（前 12 个，6→12）
    final invItems = p.inventory.take(12).map((i) => i.name).toList();
    final inventoryText = invItems.isEmpty
        ? '背包：空'
        : '背包：${invItems.join('、')}';

    // 从当前剧情 + 结构化记忆中提取"承诺/未完结事项"，防止选项说话不算话
    // 2026-08-23：importance≥5（≥6→≥5），条数 3→6，重要承诺/伏笔/未完成任务更多注入
    final openLoopsBrief = memory.openLoops
        .where((l) => l.status == 'open' && l.importance >= 5)
        .take(6)
        .map((l) => '· ${l.description}')
        .join('\n');

    // 近期 NPC：
    //  - 必须 introduced=true（剧情中正式认识/互动过）才会出现。
    //  - 不再用「好感绝对值≥10」作为筛选——开局NPC全被塞了0~15随机好感，会导致"还没见过面就+14"伪造。
    //  - 最多 8 个（12→8），避免 token 被NPC池污染。
    //  - P1-1 新增：同时注入「人设3关键词 / 说话风格」，防止选项AI写出"斯内普热情邀你一起吃零食"这种 OOC 选项。
    final nearbyNpcList = npcRegistry.values.where((n) => n.introduced).take(8).toList();
    String nearbyNpcsFormat(NPC n) {
      final stage = n.affection >= 60
          ? '挚友'
          : n.affection >= 30
              ? '好友'
              : n.affection >= 5
                  ? '朋友'
                  : n.affection > -5
                      ? '熟人'
                      : n.affection > -30
                          ? '冷淡'
                          : '敌对';
      // personality 取前3个作为核心人设；如果是空列表，fallback 给一个默认人设
      final traits = (n.personality.isNotEmpty ? n.personality.take(3).join('/') : '沉稳/含蓄/有礼貌');
      return '${n.name}(好感${n.affection >= 0 ? '+' : ''}${n.affection}·$stage｜人设:$traits)';
    }
    final nearbyNpcs = nearbyNpcList.map(nearbyNpcsFormat).join('、');

    // P1-1 轻度 OOC 软提醒：上回合有 warn 级违规时，给选项 AI 一段温和提醒（不打回，只提示修正风格）
    final prevViolations = worldState.consistencyViolations
        .where((v) => v['severity'] == 'warn')
        .take(2)
        .map((v) => '• ${v['message']}')
        .join('\n');
    final oocWarn = prevViolations.isNotEmpty
        ? '【上回合轻微逻辑违和提醒（选项请避免同类问题）】\n$prevViolations\n'
        : '';

    // 断言块（与叙事AI端共用同一份 buildAssertionsPromptBlock）
    final assertionsBlock = buildAssertionsPromptBlock();

    // 禁止词对选项的提示：选项 AI 也要避免现代/跨IP/网络梗
    const forbiddenHint = '【生成选项·禁用词清单·请注意】\n'
        '严禁出现：手机/互联网/微信/高铁/飞机/扫码 等现代物品；柯南/路飞/原神/三体 等跨IP；yyds/绝绝子/社死/破防/打call/666 等网络梗。';

    // 场景停滞提示：传给选项生成器，让它按规则2b/2c强制提供"推进下一场景"选项
    // 与叙事AI端保持完全一致的豁免+分级逻辑：
    //   - 开局家中(2回合)才严厉，重要剧情场景(6回合)宽松，过路点(4回合)中等
    //   - 叙事末段存在"未解决钩子"时不强制，避免把正在进行中的决斗/点名/悬念硬打断
    final threshold = stagnationThresholdFor(currentLoc);
    final unresolved = narrativeHasUnresolvedHook(narrative);
    final stagnationHint = (turnsAtSameLocation >= threshold && !unresolved)
        ? '⚠️ 【同一地点停留】玩家已在「$currentLoc」连续停留 $turnsAtSameLocation 回合（该场景允许阈值=$threshold回合），剧情停滞！按规则必须生成至少2个前往下一场景的选项（例：收拾行李去车站、出门、告别家人、动身前往国王十字车站等）。严禁生成4个原地不动的选项。'
        : (turnCount <= 3 && turnCount >= 1 && (currentLoc.contains('家中') || currentLoc.contains('卧室') || currentLoc.isEmpty)
            ? '📌 【开局前3回合】：属于「收到信→准备出发」阶段，选项中必须至少包含1个"准备出发/前往九又四分之三站台"的推进型选项，避免玩家一直在家里反复施法徘徊。'
            : (unresolved && turnsAtSameLocation >= (threshold - 1))
                ? '💡 【剧情进行中】当前叙事结尾有未解决的冲突/悬念，选项优先承接「把当前这个悬念/冲突收尾」的动作；但至少要保证有1个选项带"场景转换趋势"（如"把这件事做完后前往下个地点"），不要所有选项都彻底原地打转。'
                : '');

    final choicePrompt = '''$kChoicePromptPreamble
  ===== 游戏世界背景 =====
  【当前剧情末尾处境】（你所有选项必须直接衔接这一段结尾的最后一个动作/对话/场面）
  $narrativeTail

  【玩家硬状态】
  $timestamp｜$currentLoc｜$yearLabel｜$houseText
  $healthText｜$energyText｜$galleonsText
  $spellsText
  $inventoryText
  ${nearbyNpcs.isNotEmpty ? '附近/重要NPC：' + nearbyNpcs : ''}
  【身份模式】${appProvider.identityMode == IdentityMode.transmigration ? '穿越者：对原作命运有隐约记忆，可作为行动依据' : '原住民：对命运走向一无所知，只凭判断与本能行事，选项严禁出现主角不可能知道的信息'}
  【上回合玩家动作】$playerAction
  ${stagnationHint.isNotEmpty ? stagnationHint : ''}
  ${assertionsBlock.isNotEmpty ? assertionsBlock : ''}
  ${oocWarn.isNotEmpty ? oocWarn : ''}
  ${forbiddenHint}

  ${openLoopsBrief.isNotEmpty ? '【当前承诺（不得违背）】\n' + openLoopsBrief : ''}
  【T0 核心事实（选项不能违背）】
  ${memory.keyFacts.where((f) => f.importance >= 4).map((f) => '· ${f.fact}').take(10).join('\n')}

$kChoicePromptSuffix''';

    try {
      final response = await callDeepSeek(
        choicePrompt,
        scene: AiScene.choice,
      );

      final content = response.content.trim();
      final choices = <GameChoice>[];
      final lines = content.split('\n');

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        final match = GameProviderBase.reChoiceOption.firstMatch(trimmed);
        if (match != null) {
          final rawAction = trimmed.replaceFirst(GameProviderBase.reChoiceOption, '').trim();
          final action = sanitizeChoiceText(rawAction);
          if (action.isNotEmpty && action.length >= 2) {
            choices.add(GameChoice(text: action, action: action));
          }
        }

        if (choices.length >= 4) break;
      }

      // 质量检查：检查选项数量和内容质量
      final qualityPassed = choices.length >= 2 &&
          choices.every((c) => isChoiceQualityAcceptable(c.text));

      // 兜底: 选项不足2条 或 质量不合格 → 自动重试1次
      if (!qualityPassed) {
        final qualityReasons = <String>[];
        if (choices.length < 2) qualityReasons.add('数量不足(${choices.length}/4)');
        final badChoices = choices.where((c) => !isChoiceQualityAcceptable(c.text)).toList();
        if (badChoices.isNotEmpty) qualityReasons.add('${badChoices.length}条含markdown/图片/异常格式');
        debugPrint('选项质量检测: ${qualityReasons.join("、")}，自动重试...');

        final retryPrompt = '''你是严格的纯文本选项生成器。请生成 4 个玩家选择，绝对禁止使用任何Markdown格式！
严格规则：
1. 纯文本输出，不得出现 ![]、[]()、**、*、` 等任何markdown语法
2. 格式严格为 A.xxx / B.xxx / C.xxx / D.xxx，每行一条
3. 内容为20-50字的具体动作描述
4. 直接承接当前剧情结尾

请直接输出4行选项，不要任何其他内容：''';

        final retryResponse = await callDeepSeek(
          retryPrompt,
          scene: AiScene.choice,
        );
        final retryContent = retryResponse.content.trim();
        final retryChoices = <GameChoice>[];
        final retryLines = retryContent.split('\n');
        for (final line in retryLines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          final match = GameProviderBase.reChoiceOption.firstMatch(trimmed);
          if (match != null) {
            final rawAction = trimmed.replaceFirst(GameProviderBase.reChoiceOption, '').trim();
            final action = sanitizeChoiceText(rawAction);
            if (action.isNotEmpty && action.length >= 2 && isChoiceQualityAcceptable(action)) {
              retryChoices.add(GameChoice(text: action, action: action));
            }
          }
          if (retryChoices.length >= 4) break;
        }
        // 用重试结果替换全部选项（如果重试结果更好）
        if (retryChoices.length >= 2) {
          choices
            ..clear()
            ..addAll(retryChoices);
        } else if (choices.isEmpty) {
          choices.addAll(retryChoices);
        }
      }

      // 最终兜底：如果仍然没有合格选项，生成静态默认选项
      if (choices.isEmpty) {
        debugPrint('选项生成全部失败，使用默认兜底选项');
        choices.addAll(_buildFallbackChoices(narrative));
      }

      return choices;
    } catch (e) {
      // 关键修复：以前这里 return [] → 外层走 generateContextualFallbackChoices → 生成不承接剧情末尾的"仔细查看"
      // → 玩家点了之后下一回合叙事就完全跳开上一段剧情结尾，造成"刚生成的剧情没操作就被另一个剧情替换"
      // 现在统一走 _buildFallbackChoices，严格基于 narrative 末尾 800 字做承接式兜底，保证不断链。
      debugPrint('独立选项生成异常(使用承接式兜底): $e');
      return _buildFallbackChoices(narrative);
    }
  }

  /// 基于当前上下文生成的兜底选项（比静态位置选项更智能）

  void _parseAffectionChanges(String text) {
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
    // P1-2 好感变化逻辑校验（避免"羞辱了你 → +8 好感"的违和）
    // ============================================================
    // 输入：完整叙事 text（查关键词判断是正面还是负面互动）、NPC名、delta。
    // 输出：true=通过 / false=丢弃这条好感变化（不打回整段剧情，只丢弃假好感，给玩家真体验）。
    bool validateAffectionLogic(String npcName, String narrative, int delta) {
      if (delta == 0) return false;
      // --- 规则1：叙事里出现明确的负面互动关键词，delta 必须是负数（或 ≤ +1 的极微弱正向） ---
      final negRe = RegExp(
        r'(侮辱|羞辱|嘲笑|讥讽|嘲讽|骂|叱责|指责|当众.*丢脸|陷害|背叛|出卖|偷窃|恶意|骗了|欺骗|勒索|霸凌|针对|敌对|决斗|攻击|施咒伤害|下咒|诅咒)',
      );
      // --- 规则2：叙事里出现明确的重大正向事件，才允许 |delta|≥10  ---
      final hugePositiveRe = RegExp(
        r'(救了.*命|舍身|挡在.*前面|替.*挡|救命|以身犯险|告白|求婚|说出了真心话|坦白|赠予.*贵重|赠送.*传家|为.*背叛.*|不惜.*帮助)',
      );
      // --- 规则3：NPC 当前好感阶段必须匹配 delta 强度 ---
      //   - 陌生人(<0) 不能一下 +10，除非救命级别
      //   - 敌意阶段(<=-30) 不能一下正面 +5
      NPC? target;
      try {
        target = npcRegistry.values.firstWhere((n) => n.nameMatches(npcName));
      } catch (_) {
        target = null;
      }
      if (negRe.hasMatch(narrative)) {
        if (delta > 0) {
          debugPrint('[P1-2 好感校验] 丢弃「$npcName+$delta」：叙事里含负面互动关键词，好感却正向变化。');
          return false;
        }
      }
      if (delta.abs() >= 8 && !hugePositiveRe.hasMatch(narrative)) {
        debugPrint('[P1-2 好感校验] 丢弃「$npcName ${delta > 0 ? '+' : ''}$delta」：变化幅度≥8但叙事里没有"救命/告白/挡刀"等重大事件。');
        return false;
      }
      if (delta.abs() >= 4 && delta > 0 && target != null) {
        final aff = target.affection;
        final introduced = target.introduced;
        if (!introduced) {
          // 还没认识，不能直接 +4+
          debugPrint('[P1-2 好感校验] 丢弃「$npcName +$delta」：该NPC尚未在剧情中登场(introduced=false)。');
          return false;
        }
        if (aff <= -20) {
          debugPrint('[P1-2 好感校验] 丢弃「$npcName +$delta」：当前好感=$aff（敌对阶段），不能一下正向大跳涨。');
          return false;
        }
      }
      return true;
    }

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

        // ---- P1-2 好感校验：逻辑不合理就直接丢弃，不更新也不做推断 ----
        if (!validateAffectionLogic(npcName, text, delta)) continue;

        if (delta > 5) delta = (delta * 0.5).round().clamp(1, 5);
        if (delta < -5) delta = (delta * 0.7).round().clamp(-5, -1);
        try {
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
      // 被动好感只作用于已登场的 NPC，避免未出场的角色被“隔空”加好感
      if (!npc.introduced) continue;
      // 检查 NPC 是否在剧情文本中出现
      bool mentioned = false;
      for (final alias in npc.allNames) {
        if (alias.runes.length < 2) continue;
        if (_standaloneNameMentioned(narrativeText, alias)) {
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
        debugPrint('[被动好感] ${npc.name}: $before → $after (推断${delta > 0 ? "+" : ""}$delta)');
        checkLocks(npc);
        syncRelationshipLevel(npc);
      }
    }
  }

  void _parseReputationChanges(String text) {
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

  /// 判断叙事文本中是否独立提到了某个别名
  /// - 中文名：前后不得紧跟汉字（中文无空格，按汉字边界判断，避免“赫敏”被“赫敏格”吞并）
  /// - 拉丁名：前后不得为字母/数字/下划线
  bool _standaloneNameMentioned(String text, String name) {
    if (name.isEmpty) return false;
    final escaped = RegExp.escape(name);
    final hasHan = RegExp(r'\p{Script=Han}', unicode: true).hasMatch(name);
    if (hasHan) {
      final pattern = RegExp(r'(?<![\p{Script=Han}])' + escaped + r'(?![\p{Script=Han}])', unicode: true);
      return pattern.hasMatch(text);
    }
    final pattern = RegExp(r'(?<!\p{L})(?<!\p{N})(?<!_)' + escaped + r'(?!\p{L})(?!\p{N})(?!_)', unicode: true);
    return pattern.hasMatch(text);
  }

  // ==================== 更多建议（本地生成，不消耗 token） ====================
}
