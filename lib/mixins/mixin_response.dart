import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../services/rate_limiter.dart';
import '../data/pet_data.dart';
import '../providers/app_provider.dart';
import '../models/npc.dart';
import '../models/game_systems.dart';
import '../services/save_service.dart';
import '../services/deepseek_service.dart';
import '../data/cg_data.dart';
import '../utils/story_text_renderer.dart';
import '../services/npc_chat_service.dart';
import '../data/world_rules.dart';
import '../data/event_anchors.dart';
import '../models/player.dart';
import '../utils/prompt_sanitizer.dart';
import '../data/trait_data.dart';
import '../data/npc_data.dart';
import '../prompts/prompts.dart';
import '../models/long_term_memory.dart';
import '../data/course_data.dart';
import '../data/balance_constants.dart';
import '../data/goal_data.dart';
import '../data/wand_data.dart';
import '../services/ai_router.dart';
import '../models/world_state.dart';
import '../utils/crash_logger.dart';

mixin GameResponseMixin on GameProvider {
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
    final normalized = matched!.toLowerCase();
    String? en;
    for (final e in cnToEn.entries) {
      if (e.key == matched || e.value.toLowerCase() == normalized) {
        en = e.value;
        break;
      }
    }
    en ??= '${matched[0].toUpperCase()}${matched.substring(1).toLowerCase()}';

    player!.house = en;
    _unlockAchievement('sorted');
    debugPrint('⚡ 分院结果自动提取：${player!.house}（匹配到 "$matched"）');
  }

  /// 只解析叙事文本（不含选项），用于独立选项生成模式

  void _parseNarrativeOnly(String text) {
    currentNarrative = '';
    choices = [];

    // 移除结构化区块（选项、好感、声望等）
    var cleaned = text;
    cleaned = cleaned.replaceAllMapped(GameProvider.reAffectionSection, (m) => '');
    cleaned = cleaned.replaceAllMapped(GameProvider.reReputationSection, (m) => '');

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
      if (GameProvider.reChoiceOption.hasMatch(trimmed)) {
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
    _markIntroducedFromNarrative(currentNarrative);

    // 分院结果自动提取（使用带语境判断的公共函数）
    _tryExtractHouseFromNarrative(text);
  }

  void _parseResponse(String text) {
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
        if (GameProvider.reChoiceOption.hasMatch(trimmed)) {
          // 关键修复：只有当正文已经足够长（>50字）且连续2行都是选项格式时
          // 才认为进入选项区，防止正文中的选项格式被误识别
          if (currentNarrative.trim().length >= minNarrativeLength) {
            consecutiveChoiceLines++;
            if (consecutiveChoiceLines >= 2) {
              anyExplicitBlockPassed = true;
              final action = trimmed.replaceFirst(GameProvider.reChoiceOption, '').trim();
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
            final action = trimmed.replaceFirst(GameProvider.reChoiceOption, '').trim();
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
      } else if (GameProvider.reChoiceOption.hasMatch(trimmed)) {
        // 在显式选项区块之后，逐行收集选项
        final action = trimmed.replaceFirst(GameProvider.reChoiceOption, '').trim();
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
        .replaceAll(GameProvider.reMultiNewline, '\n\n')
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
    _markIntroducedFromNarrative(currentNarrative);

    if (choices.isEmpty) {
      // 先尝试从原始文本中智能提取选项（防止解析逻辑遗漏）
      final extractedChoices = _extractChoicesFromRawText(text);
      if (extractedChoices.isNotEmpty) {
        choices.addAll(extractedChoices);
      } else {
        // 最后才使用兜底选项（但现在也基于剧情生成，而不是静态位置选项）
        choices.addAll(_generateContextualFallbackChoices());
      }
    }
    // 避免出现过多选项：裁剪到 4 个
    if (choices.length > 4) {
      choices = choices.sublist(0, 4);
    }

    if (turnCount > 0 && (turnCount % 5 == 0 || lastPlayerAction.contains(RegExp(r'(与|和|跟|找|邀|问|对话|聊天|约会|见面|散步|陪|一起|独处|深入|表白|感情|心动)')))) {
      checkNPCConfessions();
    }

    _checkSkillAchievements();
    _checkWorldChangerAchievement();
    _checkWarHeroAchievement();

    // 每10回合增加少量世界线变动率
    if (turnCount % 10 == 0) {
      _incrementWorldLineDeviation(0.005);
    }

    // 分院结果自动提取（开局叙事通过 _parseResponse，必须也走这里）
    _tryExtractHouseFromNarrative(text);

    notifyListeners();
  }

  void _extractNarrativeFromRawText(String text) {
    var cleaned = text;

    // 1. 先删【好感度变化】和【声望变化】整块（它们是结构化输出区块，不属于正文叙事）
    cleaned = cleaned.replaceAllMapped(GameProvider.reAffectionSection, (m) => '');
    cleaned = cleaned.replaceAllMapped(GameProvider.reReputationSection, (m) => '');

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
    final choiceMatch = GameProvider.reChoiceMultiLine.firstMatch(cleaned);
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

  List<GameChoice> _extractChoicesFromRawText(String text) {
    final choices = <GameChoice>[];
    final lines = text.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // 直接使用预编译的正则，匹配所有选项格式
      final match = GameProvider.reChoiceOption.firstMatch(trimmed);
      if (match != null) {
        final action = trimmed.replaceFirst(GameProvider.reChoiceOption, '').trim();
        if (action.isNotEmpty && action.length >= 2) {
          choices.add(GameChoice(text: action, action: action));
        }
      }

      if (choices.length >= 4) break;
    }

    return choices;
  }

  /// 独立生成选项：接收已生成的剧情文本，让 AI 专门基于此生成选项
  Future<List<GameChoice>> _generateChoicesSeparately(String narrative) async {
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
    final nearbyNpcs = npcRegistry.values
        .where((n) => n.introduced)
        .take(8)
        .map((n) => '${n.name}(好感${n.affection >= 0 ? '+' : ''}${n.affection})')
        .join('、');

    final choicePrompt = '''你是《哈利波特·魔法人生模拟器》的专业选项设计师。任务：只生成 4 个互斥的玩家选择。
  你的输出只有 4 行（A/B/C/D），不要任何前置说明、正文、理由或【好感变化】等标签。

  ===== 四选一设计规则（严格执行，违反必重生成）=====
  规则1：4个选项必须分别覆盖「4 种决策风格」——
  A 直面/主动出击/勇敢型（直接面对冲突、施法、站出来、揭穿）
  B 谨慎/智取/观察型（撤退到安全、收集情报、等待时机、叫外援）
  C 人际/沟通/结盟型（求助、谈判、说谎、拉路人、找 NPC）
  D 规则内取巧/黑魔法边缘/代价型（铤而走险、用禁咒、牺牲物品、变身、隐忍装死）
  规则2：选项必须直接承接【当前剧情】最后一两句的「即时动作/最后一位说话者/当前场面氛围」，必须是"玩家此刻马上会做的事"，严禁跳到下一个地点、下一节课、明天、下个月等未来时间/地点！
  规则3：绝对禁止重复之前剧情中"已经发生/已经完成"的内容。
  规则4：绝对禁止"剧情预知类"选项——
  • 原住民模式：严禁出现「寻找有求必应屋」「进入密室」「试探魂器」「找死亡圣器」「预言伏地魔」等主角此时不可能知道的内容
  • 穿越者模式：可写"感觉这条走廊很眼熟"等模糊预感，但不能出现「因为哈利三年级会遇到…所以我要…」这类具体未来事件的知识
  规则5：严格遵守玩家硬状态限制——
  • 一年级生无法单挑成年巫师（会输）
  • 精力<25 不允许高强度战斗/长距离奔跑选项
  • 没学会的魔法不能写"用XX咒"；没带的物品不能写"拿出XX"
  • 不能违背未完结事项中的承诺
  规则6：每个选项 20~50 字之间，为"具体动作+明确意图"，不要"随便走走""休息一下"这种无意义选项。
  规则7：严格格式，只输出 A./B./C./D. + 内容，每行 1 条，刚好 4 行，不多不少。

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

  ${openLoopsBrief.isNotEmpty ? '【当前承诺（不得违背）】\n' + openLoopsBrief : ''}
  【T0 核心事实（选项不能违背）】
  ${memory.keyFacts.where((f) => f.importance >= 4).map((f) => '· ${f.fact}').take(10).join('\n')}

  请直接输出 4 行：
  A.xxxxxx
  B.xxxxxx
  C.xxxxxx
  D.xxxxxx''';

    try {
      final response = await _callDeepSeek(
        choicePrompt,
        scene: AiScene.choice,
      );

      final content = response.content.trim();
      final choices = <GameChoice>[];
      final lines = content.split('\n');

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        final match = GameProvider.reChoiceOption.firstMatch(trimmed);
        if (match != null) {
          final action = trimmed.replaceFirst(GameProvider.reChoiceOption, '').trim();
          if (action.isNotEmpty && action.length >= 2) {
            choices.add(GameChoice(text: action, action: action));
          }
        }

        if (choices.length >= 4) break;
      }

      return choices;
    } catch (e) {
      debugPrint('独立选项生成失败(回退到文本解析): $e');
      return [];
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
          _checkLocks(npc);
          _syncRelationshipLevel(npc);
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
      if (GameProvider.reChoiceOption.hasMatch(trimmed)) continue;
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
        _checkLocks(npc);
        _syncRelationshipLevel(npc);
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

  // ==================== 更多建议（本地生成，不消耗 token） ====================
}
