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
  /// ===== BUG-K 最终防线：分院结果文本解析（极度收紧规则）=====
  /// 旧问题：AI 写"你想被分进斯莱特林吗？"这种第三人称设问/假设句，
  /// 正则直接命中"被分进+斯莱特林"→ 分院成就解锁 + player.house 赋值，
  /// 主角实际上还在霍格沃茨特快上，根本没进大礼堂。
  ///
  /// 新规则（必须同时满足）：
  /// 1. 成就锁：sorted 成就已解锁 → 直接return，绝不再次修改
  /// 2. 强信号：正文必须出现"分院仪式的强锚点"（二选一）：
  ///    A. 分院帽+你的名字/头上 信号（分院帽扣在/戴在/落在 你的/凌天的 头上，或者 叫到你的名字/念到了你的名字）
  ///    B. "分院结果公布/正式宣布你"模式
  /// 3. 假设句过滤：匹配到的学院名，上下文 ±20字内 不能有
  ///    "如果/假如/要是/万一/想/想要/会不会/是否/难道/不是/除非/可以吗/或者/？"
  ///    （设问/假设/条件不是真分院）
  /// 4. 主语锚定："分到/被分到/分进/被分进/进入了/进了" 这些动词 前10字内
  ///    必须出现"你/我/凌天/主角"，不能是"马尔福被分进"或"如果他被分进"
  /// 5. 位置约束：学院名匹配处 必须在 强信号锚点 之后（不能是正文开头提到
  ///    "回忆去年分院"或"马尔福来自斯莱特林"时的"斯莱特林"）
  void _tryExtractHouseFromNarrative(String text) {
    if (player == null) return;
    // 1) 成就锁：sorted一旦解锁，绝不可能再分院
    if (player!.achievements.contains('sorted')) return;
    // 兼容防御：house写了但成就没解锁？先清空，等真分院
    if (player!.house != null) {
      player!.house = null;
    }

    const houseGroup = '格兰芬多|斯莱特林|拉文克劳|赫奇帕奇'
        '|Gryffindor|Slytherin|Ravenclaw|Hufflepuff';

    // 2) 强信号A：分院仪式真正发生在主角身上的证据（必须有一个命中）
    final ceremonyAnchors = <Pattern>[
      // 分院帽和主角头直接接触
      RegExp(r'分院帽[^，。！？\n]{0,20}(扣在|戴在|落在|碰到|触到|停在)[^，。！？\n]{0,20}(你的|凌天的|我的|主角的|头上)', caseSensitive: false),
      // 叫名字（麦格教授/分院仪式上/叫到你的名字）
      RegExp(r'(叫到|念到|喊道|点到)[^，。！？\n]{0,15}(你的名字|凌天|你了)', caseSensitive: false),
      // 走流程到你
      RegExp(r'(终于|终于轮到|下一个就是|走到你面前)[^，。！？\n]{0,20}(你|凌天)', caseSensitive: false),
    ];
    int? anchorIdx;
    for (final p in ceremonyAnchors) {
      final m = p is RegExp ? p.firstMatch(text) : null;
      if (m != null) {
        anchorIdx = m.start;
        break;
      }
    }
    // 强信号B：正式宣布结果句式
    if (anchorIdx == null) {
      final announce = RegExp(
        r'(分院仪式上|在大礼堂里|教授宣布|正式宣布|帽子宣布|分院帽[^，。！？\n]{0,5}(喊|叫|说|宣布))',
        caseSensitive: false,
      ).firstMatch(text);
      if (announce != null) anchorIdx = announce.start;
    }
    if (anchorIdx == null) {
      // 完全没有分院仪式强信号 → 不解析
      return;
    }
    // 额外：叫到了主角名字但还没到你 → 也不算（比如AI写了"叫到了纳威·隆巴顿"）
    // => anchorIdx 本身已要求 "叫到 你的名字/凌天/你了"，所以已排除

    // 3) 候选匹配：学院名匹配必须发生在 anchorIdx 之后（不能是正文开头的"马尔福来自斯莱特林"）
    //    并且满足：紧邻动作词 或 分院帽喊出（!!） 或 结果宣布
    final candidates = <(int, String)>[
      // 模式1：动作词+学院（必须主语是你/凌天/我）
      ...RegExp(
        '(你|我|凌天|主角)[^，。！？\n]{0,10}(?:分到|分进|被分到|被分进|进入了|进了|分到了|进了)\\s*($houseGroup)',
        caseSensitive: false,
      ).allMatches(text).map((m) => (m.start, m.group(2)!)),
      // 模式2：分院帽喊（连续感叹号+学院名）
      ...RegExp(
        '["\']?($houseGroup)\\s*[\uff01!]{2,}["\']?',
        caseSensitive: false,
      ).allMatches(text).map((m) => (m.start, m.group(1)!)),
      // 模式3：结果宣布句式
      ...RegExp(
        '(宣布|公布|决定|结果是)[^，。！？\n]{0,15}($houseGroup)',
        caseSensitive: false,
      ).allMatches(text).map((m) => (m.start, m.group(2)!)),
    ];
    // 过滤：必须在强信号锚点之后
    // 注意：L66 已 if (anchorIdx == null) return; 所以这里一定非空
    candidates.removeWhere((c) => c.$1 < anchorIdx!);
    if (candidates.isEmpty) return;

    // 4) 假设/设问过滤：对每个候选，取 ±20 字符做"假设词否定"检查
    const forbiddenHypo = ['如果', '假如', '要是', '万一', '想 ', '想要', '想被', '会不会',
      '是否', '难道', '不是', '除非', '可以吗', '或者', '或许', '可能', '也许', '？', '?'];
    int safeStart(int i, String s) => i < 0 ? 0 : (i > s.length ? s.length : i);
    (int, String)? finalPick;
    for (final cand in candidates) {
      final (idx, name) = cand;
      final ctxStart = safeStart(idx - 22, text);
      final ctxEnd = safeStart(idx + name.length + 22, text);
      final ctx = text.substring(ctxStart, ctxEnd);
      bool bad = false;
      for (final w in forbiddenHypo) {
        if (ctx.contains(w)) { bad = true; break; }
      }
      if (!bad) { finalPick = cand; break; }
    }
    if (finalPick == null) return;

    // L112 已经判定 finalPick != null，Dart flow analysis 已提升为非空，不需要 !
    final matched = finalPick.$2;

    // 5) 中英转换
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
    debugPrint('⚡ [分院解析·强信号通过] 自动提取：${player!.house}（匹配 "$matched" 在 L? 锚点后）');
  }

  /// 只解析叙事文本（不含选项），用于独立选项生成模式
  /// 
  /// 返回值：是否解析出了"有效的叙事正文"（BUG-H 防御）。
  ///   若模型搞混了narrative/choice场景，返回了全是A.B.C.D.选项，
  ///   则解析结果是空/过短的narrative + 一堆choices，这时候返回 false，
  ///   让调用方（narrative生成流程）按"生成失败"处理：重试/兜底叙事，
  ///   绝对不允许把A.B.C.D.选项文本写进剧情存档/前情回顾。
  bool parseNarrativeOnly(String text) {
    currentNarrative = '';
    choices = [];

    // 注意：不再调用 sanitizeNarrativeForArchive 预清洗！
    // 之前 BUG-J 的 sanitize 会剥离【时间戳】【地点】📅 行 → 用户看不到时间戳/地点。
    // 正确做法：display narrative 保留 AI 写的【时间戳】【地点】（用户需要看到），
    //          只在 accumulateForSummary 喂 summary buffer 时才清洗（防污染摘要）。
    var cleaned = text;

    // 移除结构化区块（好感/声望/选项等）— 这些由独立 UI 面板展示，不混在正文里
    cleaned = cleaned.replaceAllMapped(GameProviderBase.reAffectionSection, (m) => '');
    cleaned = cleaned.replaceAllMapped(GameProviderBase.reReputationSection, (m) => '');

    // ❗重要：时间戳和地点是头部元数据，由独立卡片展示，不应该混在正文，但也不应该被完全移除（否则_extractHeader找不到）
    // 我们只移除选项相关的区块，保留时间戳/地点给_extractHeader提取。
    const stripSections = [
      '可选行动', '自由行动', '行动建议', '备选行动',
      '剧情选项', '下回合选择', '选择建议',
    ];
    for (final section in stripSections) {
      final pat = RegExp(r'【' + RegExp.escape(section) + r'】[\s\S]*?(?=【|$)');
      cleaned = cleaned.replaceAllMapped(pat, (m) => '');
    }

    // 移除选项行（A.xxx, B.xxx 等），同时统计：原始文本里选项行有多少
    final allLines = text.split('\n');
    int rawChoiceLines = 0;
    for (final l in allLines) {
      final t = l.trim();
      if (GameProviderBase.reChoiceOption.hasMatch(t)) rawChoiceLines++;
    }

    final lines = cleaned.split('\n');
    final narrativeLines = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (GameProviderBase.reChoiceOption.hasMatch(trimmed)) {
        continue;
      }
      narrativeLines.add(line);
    }

    var narrative = narrativeLines.join('\n');
    narrative = narrative.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    narrative = StoryTextRenderer.autoParagraph(narrative);
    currentNarrative = narrative;

    // ===== BUG-H: narrative 返回选项的有效性校验 =====
    // 判据：
    // 1. 解析后 narrative 正文 < 150 字（正常 narrative 600~800字）
    //    同时 原始文本里选项行 >= 3 → 模型大概率搞错场景，返回了选项而非叙事
    // 2. 或者 narrative 完全为空
    final bool invalid = (narrative.trim().length < 150 && rawChoiceLines >= 3)
                      || narrative.trim().isEmpty;
    if (invalid) {
      debugPrint('❌ [parseNarrativeOnly·BUG-H] 判定模型返回的是选项而非叙事！'
          '正文长度=${narrative.trim().length}，选项行数=$rawChoiceLines。标记为失败，'
          '调用方需走重试/兜底叙事。');
      currentNarrative = '';
      choices = [];
      return false;
    }

    // 提取好感区块用于UI显示
    final extracted = StoryTextRenderer.extractAffectionSections(text);
    lastAffectionSections = extracted['affectionSections'] as List<String>? ?? [];

    // R13 修复·好感度同步问题：先标记 NPC 登场，再解析好感度
    if (markScanIfNew(currentNarrative)) markIntroducedFromNarrative(currentNarrative);
    // 解析好感和声望变化（从原始文本）
    _parseAffectionChanges(text);
    _parseReputationChanges(text);

    // 分院结果自动提取（使用带强信号约束的新版函数）
    _tryExtractHouseFromNarrative(text);

    return true;
  }

  void parseResponse(String text) {
    // 注意：不再 sanitize — 保留【时间戳】【地点】等行供用户阅读
    // sanitizeNarrativeForArchive 只在 accumulateForSummary 里使用（防 summary 污染）
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

    // BUG1 修复·好感度同步问题：先标记 NPC 登场(introduced=true)，再解析好感变化
    // （旧顺序相反：_parseAffectionChanges 时 NPC introduced=false，
    //   AffectionValidator 校验直接丢弃 ≥+4 的大好感变化；
    //   markIntroducedFromNarrative 之后 NPC introduced=true，但好感已被丢）
    // 注：这个顺序必须与 parseNarrativeOnly() 保持完全一致。
    if (markScanIfNew(currentNarrative)) markIntroducedFromNarrative(currentNarrative);

    // Parse affection changes（总是从完整原始响应解析，而不是从裁剪后的正文中解析）
    _parseAffectionChanges(text);

    // Parse reputation changes
    _parseReputationChanges(text);

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
    // BUG2c 一年级禁咒选项过滤：去掉选项里"一年级不可能会的咒语"（如A选项"吟唱守护神咒"）
    // （叙事侧的R5_spell_power_creep已经覆盖narrative，这里是选项侧的对称保护）
    final grade = player?.grade ?? 1;
    const forbiddenChoiceForFirstYear = [
      '守护神咒', '呼神护卫', 'Expecto Patronum', '夺魂咒', '魂魄出窍', 'Imperius',
      '钻心咒', '钻心剜骨', 'Crucio', '杀戮咒', '阿瓦达索命', 'Avada Kedavra',
      '伏地魔', '魂器', '死亡圣器', '有求必应屋',
    ];
    if (grade <= 1) {
      final beforeSpell = choices.length;
      choices.removeWhere((c) {
        final lower = c.text.toLowerCase();
        for (final w in forbiddenChoiceForFirstYear) {
          if (lower.contains(w.toLowerCase()) && !(player?.learnedSpells.containsKey(w) ?? false)) {
            debugPrint('[选项禁咒] 移除一年级禁咒选项「${c.text}」: 命中「$w」');
            return true;
          }
        }
        return false;
      });
      if (choices.length < beforeSpell) {
        debugPrint('[选项禁咒] 一年级禁咒过滤: $beforeSpell→${choices.length}');
      }
    }
    if (choices.length < beforeClean) {
      debugPrint('选项质量清理: ${beforeClean}→${choices.length} (移除含markdown/图片的不合格选项)');
    }
    // 如果清理后选项不足，补充兜底选项
    if (choices.isEmpty) {
      choices.addAll(buildFallbackChoices(currentNarrative));
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
  /// BUG-L 修复：方括号检查过于严苛 → "前往[图书馆]"或"[低声]询问"被判废 →
  ///   4条里1条废就触发重试 → 极简prompt覆盖好结果。现在只拒绝markdown链接/图片语法。
  static bool isChoiceQualityAcceptable(String text) {
    if (text.isEmpty || text.length < 2) return false;
    // 检查残余markdown图片语法 ![](
    if (RegExp(r'!\[.*\]\(', caseSensitive: false).hasMatch(text)) return false;
    // 检查残余markdown链接 [text](url)
    if (RegExp(r'\[.*\]\(.*\)', caseSensitive: false).hasMatch(text)) return false;
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
  /// 触发时机：选项 AI 生成超时(45s，与 ai_router.dart 配置一致) / 返回内容不合格 / 网络异常。
  /// 核心原则：从「剧情最末尾的最后一位说话者 / 最后一个未完成动作 / 最后一个氛围钩子」出发，
  ///          产出 A(勇敢/主动) B(谨慎/观察) C(人际/沟通) D(取巧/隐忍) 四个风格，
  ///          玩家点任何一个都会让剧情**自然衔接**，不会出现"选了仔细查看 → 下回合叙事完全跳场景"的断链。
  List<GameChoice> buildFallbackChoices(String narrative) {
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

    // ---------- Step 2: 抓末尾的未完成动作钩子（关键：位置门控，防止场景错位） ----------
    // 在家中/卧室/客厅/餐厅 才激活的居家专属钩子
    final hookPacking = atHome && (tail.contains('收拾') || tail.contains('行李') || tail.contains('整理'));
    final hookDoor = atHome && (tail.contains('敲门') || tail.contains('敲门声') || tail.contains('门外'));
    // 录取信钩子：只有在家中 + 明确出现「录取通知书」关键词才激活
    // （霍格沃茨到处都是羊皮纸/信封/霍格沃茨的，去掉这些误判词）
    final hookLetter = atHome && tail.contains('录取通知书');
    // 通用钩子不受位置限制
    final hookLeaving = tail.contains('早点休息') || tail.contains('明天') || tail.contains('出发') || tail.contains('车票') || tail.contains('站台');
    final hookGoodbye = tail.contains('圣诞节') || tail.contains('答应我') || tail.contains('一定要回来') || tail.contains('告别') || tail.contains('舍不得');
    final hookAnswer = tail.contains('等你回答') || tail.contains('你的选择') || tail.contains('打算怎么做') || tail.contains('那你打算') || (lastSpeaker != null && (lastDialogTopic?.contains('吗') ?? false));
    // 霍格沃茨场景专属钩子
    final atHogwarts = location.contains('霍格沃茨') || location.contains('大礼堂') || location.contains('走廊') || location.contains('教室') || location.contains('公共休息室') || location.contains('特快');
    final hookClass = atHogwarts && (tail.contains('上课') || tail.contains('教授') || tail.contains('课本') || tail.contains('笔记') || tail.contains('作业'));
    final hookGreatHall = atHogwarts && location.contains('大礼堂');
    final hogwartsLastNPC = lastSpeaker ?? (tail.contains('麦格') ? '麦格教授' :
        tail.contains('邓布利多') ? '邓布利多校长' :
        tail.contains('斯内普') ? '斯内普教授' :
        tail.contains('海格') ? '海格' :
        tail.contains('哈利') ? '哈利' :
        tail.contains('罗恩') ? '罗恩' :
        tail.contains('赫敏') ? '赫敏' : null);

    final fallback = <GameChoice>[];

    // ---- A 勇敢/主动出击型（推进按钮会优先选这档！）----
    if (hookGoodbye && atHome) {
      fallback.add(GameChoice(
          text: '和养父母认真告别后收拾行李，明天一早前往国王十字车站',
          action: '和养父母认真拥抱告别，随即开始收拾行李，确认车票、魔杖和加隆都已入箱，准备明天前往国王十字车站的九又四分之三站台'));
    } else if (hookAnswer) {
      fallback.add(GameChoice(
          text: '正面回应「${lastSpeaker ?? '对方'}」的问题，说出你的真实想法',
          action: '直面${lastSpeaker ?? '对方'}的提问，坦诚回答你对${lastDialogTopic ?? '这件事'}的真实想法和接下来的打算'));
    } else if ((hookPacking || hookLeaving) && atHome) {
      fallback.add(GameChoice(
          text: '立刻收拾行李，和家人道晚安后为明天出发做最后确认',
          action: '立刻动手收拾行李，把魔杖匣、课本和换洗衣物装好，去和养父母道晚安，最后确认一遍车票与加隆，准备明天一早前往九又四分之三站台'));
    } else if (hookDoor) {
      fallback.add(GameChoice(text: '立刻过去开门，看看门外究竟是谁', action: '深吸一口气，快步走向大门，握住门把手直接打开看看门外到底是谁'));
    } else if (hookLetter) {
      fallback.add(GameChoice(
          text: '当着养父母的面拆开录取通知书并仔细阅读全文',
          action: '当着养父母的面撕开火漆，把霍格沃茨录取通知书从头到尾读完，确认开学日期、采购清单和九又四分之三站台说明'));
    } else if (hookGreatHall) {
      // 霍格沃茨大礼堂专属A选项：分院刚结束/晚宴进行中
      fallback.add(GameChoice(
          text: '主动转向身边的${hogwartsLastNPC ?? '新同学'}打招呼并自我介绍，拉近距离融入新集体',
          action: '大方转向身边的${hogwartsLastNPC ?? '新同学'}，露出友好笑容做自我介绍，顺势聊起对分院结果和学院的初印象，主动融入新环境'));
    } else if (hookClass) {
      fallback.add(GameChoice(
          text: '鼓起勇气举手回答教授的提问，展现你对魔咒学/当前课堂内容的理解',
          action: '深吸一口气，鼓起勇气举手回答教授的提问，把自己平时从书本和天赋里积累的理解有条理地说出来，争取给教授留下正面印象'));
    } else if (atHogwarts && hookLeaving) {
      // 霍格沃茨场景下的推进/出发动作
      fallback.add(GameChoice(
          text: '起身准备前往下一地点：拿起书包确认课程表，大步朝目标方向走去',
          action: '动作利落地把课本和笔记收进书包，确认一遍下一节课的教室和时间，迈开步伐朝目的地走去，不在原地浪费时间'));
    } else if (energy < 25) {
      fallback.add(GameChoice(text: '先抓紧休息恢复精神体力', action: '不再逞强，找个安全的地方坐下或躺下休息，先把精力恢复到可行动水平再做下一步'));
    } else if (atHogwarts && isNight) {
      fallback.add(GameChoice(text: '起身点亮魔杖，沿着走廊主动探索午夜城堡的秘密', action: '不再犹豫，点亮魔杖起身沿着月光下的走廊前进，主动探索城堡在午夜的秘密——被费尔奇抓到风险大，但往往能发现白天看不到的东西'));
    } else if (energy < 30) {
      fallback.add(GameChoice(text: '先抓紧时间恢复体力，再考虑下一步行动', action: '感觉身体已经快到极限了，不再硬撑，找个安全的地方坐下或靠墙闭目养神，先把体力和精力恢复到能正常行动的水平再考虑下一步'));
    } else {
      // 默认 A 选项：基于当前场景生成不同风格的主动型选项，避免多回合相同
      final defaultA = turnCount % 3 == 0
          ? GameChoice(text: '主动面对眼前状况并迈出第一步', action: '不再犹豫，鼓起勇气直接面对当前的局面，立刻着手处理最紧急的那件事')
          : turnCount % 3 == 1
              ? GameChoice(text: '打起精神，大步向前迎接接下来的挑战', action: '深吸一口气振作精神，迈开大步向前走，用积极的态度迎接即将到来的每一件事')
              : GameChoice(text: '果断行动，不让犹豫耽误当前良机', action: '直觉告诉自己不能再等了，果断采取行动抓住当下的时机，在悔意追上之前把事情推进下去');
      fallback.add(defaultA);
    }

    // ---- B 谨慎/智取/观察型 ----
    if (hookAnswer) {
      fallback.add(GameChoice(
          text: '不急于回答，先反问「${lastSpeaker ?? '对方'}」几个关键细节再决定',
          action: '先不动声色地反问${lastSpeaker ?? '对方'}两个关于${lastDialogTopic ?? '这件事'}的具体细节，确认信息完全后再做出稳妥的回应'));
    } else if (hookPacking && atHome) {
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
    } else if (hookGreatHall) {
      fallback.add(GameChoice(
          text: '先安静用餐，观察各个学院桌的氛围和同学的气质再决定社交节奏',
          action: '不急于社交，先拿起刀叉安静享用晚宴，同时暗中观察四个学院长桌的氛围、同学的气质和教授们的神态，把局势看清楚再决定怎么社交'));
    } else if (atHogwarts) {
      fallback.add(GameChoice(
          text: '先找个安静角落把课程表和学院地图理清楚，规划好今日行程',
          action: '先避开人流，找一个走廊的安静角落，把课程表、学院公共休息室位置和今天要做的事情逐一列清楚，避免走错教室或遗漏重要事项'));
    } else {
      // 默认 B 选项：基于回合数和场景变化
      final defaultB = turnCount % 3 == 0
          ? GameChoice(text: '先沉默观察几秒钟，理清所有信息再行动', action: '先不要急着做决定，安静观察周围的人和环境，把已知信息理一遍再选最稳妥的行动')
          : turnCount % 3 == 1
              ? GameChoice(text: '停在原地静观其变，等局势明朗再做判断', action: '不急于踏出下一步，先停在原地感受周围氛围的变化，等关键信息浮现或局势明朗之后再做出冷静的判断')
              : GameChoice(text: '先绕着周围走一圈，摸清地形和人员分布再决定', action: '不急于行动，先不动声色地绕着周围走一圈，把地形、出入口、周围人员分布都摸清楚，掌握全局信息再制定计划');
      fallback.add(defaultB);
    }

    // ---- C 人际/沟通/结盟型 ----
    if (lastSpeaker != null) {
      fallback.add(GameChoice(
          text: '和「$lastSpeaker」坐下来好好聊清楚${lastDialogTopic ?? '接下来的打算'}再决定',
          action: '拉着$lastSpeaker坐下来，把关于${lastDialogTopic ?? '接下来的安排'}的顾虑、担忧、期望都聊清楚，先把双方理解对齐再行动'));
    } else if ((hookGoodbye || hookLeaving) && atHome) {
      fallback.add(GameChoice(
          text: '坐下来和养父母吃最后一顿晚饭，聊聊对魔法界的担忧与期待',
          action: '先不急着收拾，坐到餐桌边陪养父母再吃一顿饭（哪怕是凉的），把彼此对魔法界的担忧和期待都说出来，给家人一个安心的告别'));
    } else if (atHome) {
      fallback.add(GameChoice(text: '去找养父母或家人聊聊，确认他们的看法和建议', action: '去找养父母或家里最信任的亲人聊一聊，问他们对这件事的真实想法和建议，再决定下一步怎么走'));
    } else if (hookGreatHall) {
      fallback.add(GameChoice(
          text: '向邻座伸出手自我介绍，主动结识同院的第一位朋友',
          action: '面带微笑转向身边最近的同院同学，礼貌地伸出手做自我介绍，顺势询问对方的名字、出身和对学院的看法，争取在学院里找到第一位朋友'));
    } else if (atHogwarts) {
      fallback.add(GameChoice(
          text: '找路过的${hogwartsLastNPC ?? '学长'}或同学确认下节课的教室方向和注意事项',
          action: '拦住一位看起来面善的路过的${hogwartsLastNPC ?? '高年级学长'}或同学，礼貌询问下一节课的教室位置、教授的上课风格和注意事项，确保自己不迟到踩雷'));
    } else {
      // 默认 C 选项：基于回合数和场景变化
      final defaultC = turnCount % 3 == 0
          ? GameChoice(text: '找附近熟悉的NPC了解情况再做判断', action: '先和周围看起来面善或认识的NPC聊两句，确认一下当前事态、别人都在做什么，避免自己信息不足做错决定')
          : turnCount % 3 == 1
              ? GameChoice(text: '环顾四周寻找可信任的人，主动搭话建立联系', action: '目光扫过周围的人，找一个看起来靠谱或眼熟的面孔主动搭话，先建立初步联系再了解当前处境')
              : GameChoice(text: '写好一封短信让猫头鹰送给信任的朋友，寻求建议', action: '拿出羊皮纸快速写一封短信，简单说明当前处境和困惑，让猫头鹰送给最信任的朋友，等对方回信获得建议后再行动');
      fallback.add(defaultC);
    }

    // ---- D 取巧/隐忍/代价型 ----
    if ((hookPacking || hookLeaving) && atHome) {
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
    } else if (hookGreatHall) {
      fallback.add(GameChoice(
          text: '低调坐在长桌角落默默吃饭，不主动社交但暗中观察所有人的互动',
          action: '端着餐盘悄悄挪到拉文克劳长桌最不起眼的角落坐下，安静吃饭不主动搭话，但暗中观察教授们、级长们和同学们之间的互动，默默收集情报'));
    } else if (atHogwarts) {
      fallback.add(GameChoice(
          text: '拿出提前准备好的笔记，把今天观察到的关键信息快速记下来建立情报优势',
          action: '掏出随身的羊皮纸小本和羽毛笔，把今天观察到的教授特点、同学性格、重要地点位置快速整理记录，建立属于自己的情报笔记方便日后利用'));
    } else {
      // 默认 D 选项：基于回合数和场景变化
      final defaultD = turnCount % 3 == 0
          ? GameChoice(text: '暂时隐忍不表态，等时机更成熟再出手', action: '把情绪压下去，不急于表明立场也不急于行动，先观察局势变化，等对自己最有利的时机出现再出手')
          : turnCount % 3 == 1
              ? GameChoice(text: '退到边缘地带观察全局，不抢着出头但随时准备行动', action: '安静退到人群或场景的边缘，让主角光环落在别人身上，自己默默观察整个局面的走向，等需要你的时候再果断出手')
              : GameChoice(text: '绕到对手侧后方，寻找可利用的机会出其不意', action: '不正面硬拼，悄悄绕到侧后方观察对手暴露的弱点，寻找对方意想不到的机会，出其不意掌握主动权');
      fallback.add(defaultD);
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

  /// 【推进按钮智能选策略】——替代原先的 choices.first，防止剧情回滚
  /// 选择优先级：
  ///  1) 先过滤掉与当前地点/时间完全错位的选项（如在霍格沃茨就去掉「拆录取通知书」「找养父母」）
  ///  2) 在剩余选项里，优先选含「推进型关键词」的选项（出发/动身/前往/告别/收拾/起程/离开/走下楼梯/走出房间）
  ///  3) 如果仍有多个候选，优先选 index 为 0 的 A 档（勇敢主动型）
  ///  4) 最后兜底：choices.first
  GameChoice pickAutoAdvanceChoice() {
    if (choices.isEmpty) {
      return GameChoice(text: '主动面对眼前状况', action: '不再犹豫，鼓起勇气直接面对当前局面，立刻处理最紧急的那件事');
    }
    final loc = (worldState.currentLocation ?? '').toLowerCase();
    final atHome = loc.contains('家中') || loc.contains('卧室') || loc.contains('客厅') || loc.contains('餐厅');
    final atHogwarts = loc.contains('霍格沃茨') || loc.contains('大礼堂') || loc.contains('走廊') || loc.contains('教室') || loc.contains('公共休息室') || loc.contains('特快') || loc.contains('对角巷') || loc.contains('站台');

    // 居家错位关键词：在霍格沃茨/对角巷/特快 场景下，选项里出现这些词视为错位
    final homeMisplacedKeywords = const <String>[
      '养父母', '录取通知书', '撕开火漆', '九又四分之三站台', '德思礼',
      '弗农姨父', '佩妮姨妈', '麻瓜郊区', '家中的客厅', '家里的卧室', '回家睡', '回家休息',
    ];
    // 霍格沃茨错位关键词：在家中场景，选项出现这些词视为错位
    final hogwartsMisplacedKeywords = const <String>[
      '大礼堂', '分院', '教授', '学院长桌', '级长', '公共休息室', '走廊', '城堡', '禁林',
      '魁地奇', '教室', '同学自我介绍', '同院', '霍格沃茨特快',
    ];

    // Step 1: 过滤错位选项
    var candidates = List<GameChoice>.from(choices);
    candidates.retainWhere((c) {
      final text = c.text + c.action;
      if (atHogwarts) {
        // 非居家场景：去掉居家专属词
        for (final kw in homeMisplacedKeywords) {
          if (text.contains(kw)) return false;
        }
      }
      if (atHome) {
        // 居家场景：去掉霍格沃茨专属词
        for (final kw in hogwartsMisplacedKeywords) {
          if (text.contains(kw)) return false;
        }
      }
      return true;
    });
    if (candidates.isEmpty) candidates = List<GameChoice>.from(choices);

    // Step 2: 推进型关键词加分（优先排序）
    const advanceKeywords = <String>[
      '出发', '动身', '前往', '告别', '收拾', '起程', '离开', '走下楼梯',
      '走出房间', '去车站', '去对角巷', '出发前往', '立刻去', '大步走',
      '拥抱告别', '转身走向', '动身前往', '准备明天',
    ];
    int score(GameChoice c) {
      var s = 0;
      final text = c.text + c.action;
      for (final kw in advanceKeywords) {
        if (text.contains(kw)) s += 10;
      }
      return s;
    }
    candidates.sort((a, b) => score(b).compareTo(score(a)));

    // Step 3: 同分/都为0分时，优先原列表更靠前的（A > B > C > D）
    final topScore = score(candidates.first);
    final topPool = candidates.where((c) => score(c) == topScore).toList();
    if (topPool.length <= 1) return topPool.first;
    // 在最高分池中找原 choices 里 index 最小的
    GameChoice? best;
    for (final c in choices) {
      if (topPool.any((x) => x.action == c.action && x.text == c.text)) {
        best = c;
        break;
      }
    }
    return best ?? candidates.first;
  }

  /// 「推进」按钮入口：调用 pickAutoAdvanceChoice() 后再 processChoice
  Future<void> processAutoAdvanceChoice() async {
    final choice = pickAutoAdvanceChoice();
    debugPrint('▶️ 推进按钮选中: choice=${choice.text.substring(0, choice.text.length > 30 ? 30 : choice.text.length)} (候选池=${choices.length})');
    return processChoice(choice);
  }

  /// 独立生成选项：接收已生成的剧情文本，让 AI 专门基于此生成选项
  Future<List<GameChoice>> generateChoicesSeparately(String narrative) async {
    if (router == null) return [];

    final p = player!;
    final currentLoc = worldState.currentLocation ?? '';
    final timestamp = worldState.timestamp;
    final playerAction = lastPlayerAction;

    // BUG3a 修复·strip承接标记：在提取末尾800字作为选项依据之前，
    // 先清理叙事中的内部meta标记（「承接：XXX」「SceneGraph:触发节点」等），
    // 防止选项 AI 把这些内部衔接说明当作"当前剧情末尾处境"的一部分，
    // 从而在新叙事里反复输出「（承接：家中·卧室）——紧接着，时间戳...」这种用户可见的调试文本。
    final cleanNarrativeForChoice = StoryTextRenderer.stripInternalMetaMarkers(narrative);
    // 只取叙事末尾 800 字作为选项依据——重点在「结尾的即时动作/最后一位说话者/场面氛围」
    // 选项必须直接承接这一刻，不得跨越到下一节课/明天/下一个地点。
    final narrativeTail = cleanNarrativeForChoice.length > 800
        ? '…（前略，以下为当前剧情的最末尾800字，请严格按结尾最后几行生成选项）\n' + cleanNarrativeForChoice.substring(cleanNarrativeForChoice.length - 800)
        : cleanNarrativeForChoice;

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
      debugPrint('[选项AI原始] 解析到${choices.length}条选项: ${choices.map((c) => c.text.substring(0, c.text.length > 30 ? 30 : c.text.length)).join(" | ")}');

      // ===== BUG-3 陌生NPC过滤（AI捏造"霍尔"等未出场角色的选项必须丢弃）=====
      // 选项生成器经常在需要"冲突对手"时随意捏造 NPC 名字（如日志 L1459 的"霍尔"），
      // 导致玩家点了跟完全不存在的人对话，剧情断链+世界感崩塌。
      // 过滤规则：选项里提到的"2~4字像人名的词"必须满足其一：
      //   a) 已 introduced 的 NPC（全名或别名匹配）
      //   b) narrativeTail（当前剧情末尾）文本里出现过（本回合刚遇到的路人临时允许）
      //   c) 玩家自己（p.name）
      final npcWhitelistNames = <String>{};
      final npcNameAll = <String, bool>{}; // 用于快速判断某字符串是否NPC（不管introduced）
      for (final n in npcRegistry.values) {
        npcNameAll[n.name] = true;
        for (final alias in n.aliases) npcNameAll[alias] = true;
        if (n.introduced) {
          npcWhitelistNames.add(n.name);
          npcWhitelistNames.addAll(n.aliases);
        }
      }
      npcWhitelistNames.add(p.name); // 玩家自己永远允许
      // 结尾叙事里出现过的候选人名（临时白名单，允许本回合刚碰到的路人/列车员/对角巷店员出现在选项）
      final tailNameMatches = RegExp(
        r'(?<!\w)([\u4e00-\u9fa5]{2,4})(?!\w)',
        unicode: true,
      ).allMatches(cleanNarrativeForChoice);
      for (final m in tailNameMatches) {
        final candidate = m.group(1)!;
        // 不要把"学院/车站/大厅/列车/走廊/图书馆"这些常见叙述词当成"人名临时白名单"
        if (!_looksLikeNarrationWord(candidate)) npcWhitelistNames.add(candidate);
      }
      // "一年级/二年级/新生/学长/学姐" 这种称呼（不是具体人名）允许，
      // 但我们只在命中"像具体人名的霍尔"这种时才过滤，所以不需要额外加。
      //
      // BUG修复：白名单需要包含整个剧情中出现的人名，不仅是末尾800字。
      // 否则如果NPC名字出现在前半段剧情，不在末尾800字，即使已经出场也会被误过滤。
      final fullNarrativeNameMatches = RegExp(
        r'(?<!\w)([\u4e00-\u9fa5]{2,4})(?!\w)',
        unicode: true,
      ).allMatches(cleanNarrativeForChoice.length > 800 ? narrative : cleanNarrativeForChoice);
      for (final m in fullNarrativeNameMatches) {
        final candidate = m.group(1)!;
        if (!_looksLikeNarrationWord(candidate)) npcWhitelistNames.add(candidate);
      }

      final beforeFilter = choices.length;
      choices.removeWhere((c) => _choiceMentionsUnintroducedNpc(c.text, npcWhitelistNames, npcNameAll));
      final filtered = beforeFilter - choices.length;
      if (filtered > 0) {
        debugPrint('[选项NPC门] 丢弃$filtered条选项：提到未登场/捏造的NPC（如"霍尔"）。剩余合格选项:${choices.length}');
      }

      // 质量检查：只要有 ≥2 条合格选项就保留合格子集，不再要求 4 条全部合格
      // BUG-L 修复：旧代码用 choices.every(...) → 1条不合格就全部重试 →
      //   极简prompt(411token无上下文)的结果覆盖了完整prompt(2508token)的好结果
      final goodChoices = choices.where((c) => isChoiceQualityAcceptable(c.text)).toList();
      final qualityPassed = goodChoices.length >= 2;

      // 只有 <2 条合格才重试，且重试必须带完整剧情上下文
      if (!qualityPassed) {
        final qualityReasons = <String>[];
        if (choices.length < 2) qualityReasons.add('数量不足(${choices.length}/4)');
        final badChoices = choices.where((c) => !isChoiceQualityAcceptable(c.text)).toList();
        if (badChoices.isNotEmpty) qualityReasons.add('${badChoices.length}条含markdown/图片/异常格式');
        debugPrint('选项质量检测: ${qualityReasons.join("、")}，自动重试(带完整剧情上下文)...');

        // BUG-L 关键修复：重试 prompt 必须包含剧情末尾+玩家状态，不能用极简 prompt！
        // 旧极简 prompt 只有 411 token 无任何上下文 → 生成通用战斗选项 → 与剧情脱节
        final narrativeTail = narrative.length > 800
            ? narrative.substring(narrative.length - 800)
            : narrative;
        final retryPrompt = '''$kChoicePromptPreamble

===== 游戏世界背景 =====
【当前剧情末尾处境】（你所有选项必须直接衔接这一段结尾的最后一个动作/对话/场面）
$narrativeTail

【玩家硬状态】
📅 $timestamp｜${worldState.currentLocation ?? '霍格沃茨'}
生命：${player?.health ?? 100}｜精力：${player?.energy ?? 100}
身份模式：${appProvider.identityMode == IdentityMode.transmigration ? "穿越者" : "原住民"}

请直接输出 4 行纯文本选项（不要任何markdown格式）：
A.xxxxxx
B.xxxxxx
C.xxxxxx
D.xxxxxx
---
$kChoicePromptSuffix''';

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
        // 重试选项也要过陌生NPC门（防止重试再生成一堆"霍尔"选项）
        // 重试也需要用完整的白名单（整个剧情），不能只用末尾
        final fullRetryNarrativeNameMatches = RegExp(
          r'(?<!\w)([\u4e00-\u9fa5]{2,4})(?!\w)',
          unicode: true,
        ).allMatches(narrativeTail);
        for (final m in fullRetryNarrativeNameMatches) {
          final candidate = m.group(1)!;
          if (!_looksLikeNarrationWord(candidate)) npcWhitelistNames.add(candidate);
        }
        final retryBefore = retryChoices.length;
        retryChoices.removeWhere((c) => _choiceMentionsUnintroducedNpc(c.text, npcWhitelistNames, npcNameAll));
        final retryFiltered = retryBefore - retryChoices.length;
        if (retryFiltered > 0) {
          debugPrint('[选项NPC门·重试] 丢弃$retryFiltered条选项（陌生捏造NPC），重试剩余:${retryChoices.length}');
        }
        // BUG-L 关键修复：不要无脑 clear() 好选项！
        // 旧代码：retryChoices.length >= 2 → choices..clear()..addAll(retryChoices)
        //   → 第一轮的好选项被极简prompt的通用选项覆盖
        // 新策略：保留第一轮的合格选项，只补充不足的部分
        final goodRetry = retryChoices.where((c) => isChoiceQualityAcceptable(c.text)).toList();
        if (goodRetry.length >= 2 && goodRetry.length > goodChoices.length) {
          // 重试结果整体更好 → 用重试结果
          choices
            ..clear()
            ..addAll(goodRetry);
        } else if (goodChoices.isNotEmpty) {
          // 第一轮已有合格选项 → 只保留合格的，不替换
          choices
            ..clear()
            ..addAll(goodChoices);
        } else if (goodRetry.isNotEmpty) {
          // 第一轮全不合格，重试有合格 → 用重试的
          choices
            ..clear()
            ..addAll(goodRetry);
        }
      } else {
        // qualityPassed=true → 只保留合格选项，丢弃不合格的（不重试）
        if (goodChoices.length < choices.length) {
          debugPrint('[选项质量] 保留${goodChoices.length}条合格选项，丢弃${choices.length - goodChoices.length}条不合格');
          choices
            ..clear()
            ..addAll(goodChoices);
        }
      }

      // 最终兜底：如果仍然没有合格选项，生成承接式兜底选项并通知玩家
      if (choices.isEmpty) {
        debugPrint('选项生成全部失败，使用承接式兜底选项');
        notifications.add('⏱️ 选项生成较慢，已为你基于当前剧情临时生成4个选项（可直接输入自由行动替代）。');
        choices.addAll(buildFallbackChoices(narrative));
      }

      // BUG-N 追踪日志：输出最终返回给UI的选项，方便定位不一致问题
      debugPrint('▶️ 最终选项(${choices.length}条): ${choices.map((c) => c.text.substring(0, c.text.length > 30 ? 30 : c.text.length)).join(" | ")}');
      return choices;
    } catch (e) {
      // 关键修复：以前这里 return [] → 外层走 generateContextualFallbackChoices → 生成不承接剧情末尾的"仔细查看"
      // → 玩家点了之后下一回合叙事就完全跳开上一段剧情结尾，造成"刚生成的剧情没操作就被另一个剧情替换"
      // 现在统一走 buildFallbackChoices，严格基于 narrative 末尾 800 字做承接式兜底，保证不断链；同时 UI 明确通知玩家。
      debugPrint('独立选项生成异常/超时(使用承接式兜底): $e');
      final msg = e.toString().contains('超时')
          ? '⏱️ 选项生成超时（网络波动或服务商限流），已为你基于剧情末尾临时生成4个承接选项；稍后可通过输入框输入自由行动获得更新鲜选项。'
          : '⏱️ 选项生成异常，已为你基于当前剧情临时生成4个承接选项（不影响剧情，自由行动照常输入）。';
      notifications.add(msg);
      return buildFallbackChoices(narrative);
    }
  }

  /// 基于当前上下文生成的兜底选项（比静态位置选项更智能）

  // ===== BUG-3 辅助：选项是否提到了"未登场/捏造的NPC名"（如"霍尔"）=====
  // 返回 true = 该选项要丢弃
  bool _choiceMentionsUnintroducedNpc(
    String text,
    Set<String> whitelist,
    Map<String, bool> npcNameAll,
  ) {
    if (text.isEmpty) return false;
    // 找出所有2~4字的"像人名的候选"：纯汉字、非代词虚词
    final candidates = RegExp(
      r'(?<!\w)([\u4e00-\u9fa5]{2,4})(?!\w)',
      unicode: true,
    ).allMatches(text).map((m) => m.group(1)!).toSet().toList();

    for (final cand in candidates) {
      // (1) 白名单（introduced的NPC+别名 / 玩家名 / 正文末尾出现过的路人）命中就放行
      if (whitelist.contains(cand)) continue;
      // (2) 明显是叙述词/虚词（教授/夫人/小姐/先生/同学/新生/大家/他们...）→ 放行
      if (_looksLikeNarrationWord(cand)) continue;

      // (3) 候选命中 npcRegistry 的全名或别名，但是 introduced=false → 说明这是"还没出场的已知角色"
      //     比如开局前几回合就写"去找斯内普"，玩家根本没见过 → 要丢弃
      if (npcNameAll.containsKey(cand)) {
        debugPrint('[选项NPC门] 命中登记但未introduced的NPC：「$cand」，移除选项「${text.substring(0, text.length > 24 ? 24 : text.length)}…」');
        return true;
      }
      // (4) 4字词几乎不可能是捏造NPC名（中文人名通常2~3字），直接放行
      if (cand.length >= 4) continue;
      // (5) 既不在白名单，也不像叙述词，还不是登记过的NPC，且是2-3字 →
      //     额外检查是否真的是人名模样：不含常见非人名用字 → 才判定为AI捏造的"霍尔"等假人
      //     BUG-N 修复：之前无条件丢弃所有未知2-4字词，导致"仔细观察""周围环境"等
      //     常见选项用词被误判为捏造NPC，绝大多数选项都被过滤掉。
      if (_candidateLooksLikeFabricatedNpcName(cand)) {
        debugPrint('[选项NPC门] 疑似捏造陌生NPC：「$cand」，移除选项「${text.substring(0, text.length > 24 ? 24 : text.length)}…」');
        return true;
      }
      // 否则不像捏造NPC名 → 放行（可能是普通动词/名词）
    }
    return false;
  }

  /// 检查候选词是否像是AI捏造的NPC名（如"霍尔"）
  /// 规则：2-3字中文，不含任何明确非人名用字，且符合中文人名常见模式
  bool _candidateLooksLikeFabricatedNpcName(String cand) {
    if (cand.length < 2 || cand.length > 3) return false;
    // 如果包含常见的非人名汉字 → 不是捏造NPC名
    // 这些字在中文普通词汇中高频出现，但极少出现在NPC名字中
    if (RegExp(r'[仔细观察周围环境线索寻找练习检查尝试继续准备考虑决定选择告诉讨论商量确认提醒建议邀请帮助跟随收集整理收拾出发前往拜访搭话转身点头摇头沉默叹气微笑皱眉盯着望着低头抬头伸手举手放下拿起掏出插入抽出推开拉开站起坐下躺下靠在躲在藏在次遍趟件事情]').hasMatch(cand)) {
      return false;
    }
    return true;
  }

  /// 快速过滤：2~4字中文更像"叙述/地点/身份词"还是"人名"
  static bool _looksLikeNarrationWord(String s) {
    if (s.length < 2) return true;
    // 含叙述高频字 → 判定非人名
    if (RegExp(r'[的地得是去来到处在把让给和与或从向对被和就都也又便很还没不知说道看听闻想走跑站坐笑哭吃打学教练写读感思起起上下出入回开关过好]').hasMatch(s)) return true;
    // 身份/头衔/场所后缀（这类一般是"列车长/管理员/教授/新生"等，不是具体人名）
    const suffixes = ['教授', '院长', '夫人', '小姐', '先生', '同学', '新生', '学长', '学姐', '级长',
      '列车长', '管理员', '老板', '店员', '经理', '裁判', '队长', '队员', '首领', '仆人', '管家',
      '车站', '礼堂', '大道', '教室', '宿舍', '学院', '走廊', '塔', '图书馆', '书店', '酒吧',
      '火车', '列车', '公共', '休息', '大厅', '入口', '出口', '今天', '明天', '昨天', '现在',
      '上午', '下午', '中午', '晚上', '深夜', '大家', '他们', '你们', '我们', '自己', '什么',
      '怎么', '这样', '那样', '这个', '那个', '这里', '那里', '一点', '一些', '东西', '事情'];
    for (final sfx in suffixes) {
      if (s.endsWith(sfx) || s == sfx) return true;
    }
    return false;
  }

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

// ============================================================
// 【宏观通用 M5 · AffectionValidator 好感校验器】
//
// 把之前写在 _parseAffectionChanges 内部的私有 validateAffectionLogic 函数，
// 抽成独立的顶层工具类（同 StagnationDetector 的层级）。
//
// 宏观好处：
// - 任何 mixin / 任何解析点（主动叙事、后台推断、玩家手动事件）只要调用同一个
//   AffectionValidator.instance.validate()，就能保证校验口径 100% 一致。
// - 纯函数：所有数据都通过参数传入（npcRegistry / npcName / narrative / delta），
//   不持有 GameProvider 引用，易于后期写单测。
// ============================================================
class AffectionValidator {
  const AffectionValidator._();
  static const AffectionValidator instance = AffectionValidator._();

  static final RegExp _negRe = RegExp(
    r'(侮辱|羞辱|嘲笑|讥讽|嘲讽|骂|叱责|指责|当众.*丢脸|陷害|背叛|出卖|偷窃|恶意|骗了|欺骗|勒索|霸凌|针对|敌对|决斗|攻击|施咒伤害|下咒|诅咒)',
  );

  static final RegExp _hugePositiveRe = RegExp(
    r'(救了.*命|舍身|挡在.*前面|替.*挡|救命|以身犯险|告白|求婚|说出了真心话|坦白|赠予.*贵重|赠送.*传家|为.*背叛.*|不惜.*帮助)',
  );

  /// 统一好感校验入口。
  /// [npcRegistry] 传当前的 NPC 注册表（用于按 name 反查 NPC 状态）
  /// [npcName] 要校验的 NPC 名称（含别名/昵称均可）
  /// [narrative] 完整叙事，用于匹配正向/负向关键词判断互动属性
  /// [delta] 玩家（AI）声称的好感变化值
  ///
  /// return true = 校验通过，允许写入；false = 逻辑不合理，直接丢弃此条变化（不打回整段剧情）
  bool validate(
    Map<String, NPC> npcRegistry,
    String npcName,
    String narrative,
    int delta,
  ) {
    if (delta == 0) return false;
    if (npcName.isEmpty || npcRegistry.isEmpty) return false;

    // 规则1：负面互动关键词 → 不允许正向 delta
    if (_negRe.hasMatch(narrative)) {
      if (delta > 0) {
        debugPrint('[P1-2 好感校验] 丢弃「$npcName+$delta」：叙事里含负面互动关键词，好感却正向变化。');
        return false;
      }
    }

    // 规则2：|delta| ≥ 8 必须有救命/告白/挡刀 等重大事件支撑
    if (delta.abs() >= 8 && !_hugePositiveRe.hasMatch(narrative)) {
      debugPrint('[P1-2 好感校验] 丢弃「$npcName ${delta > 0 ? '+' : ''}$delta」：变化幅度≥8但叙事里没有"救命/告白/挡刀"等重大事件。');
      return false;
    }

    // 规则3：大幅正向（≥+4）需匹配 NPC 当前阶段（是否登场、是否敌对）
    if (delta >= 4) {
      NPC? target;
      for (final n in npcRegistry.values) {
        if (n.nameMatches(npcName)) {
          target = n;
          break;
        }
      }
      if (target != null) {
        if (!target.introduced) {
          debugPrint('[P1-2 好感校验] 丢弃「$npcName +$delta」：该NPC尚未在剧情中登场(introduced=false)。');
          return false;
        }
        if (target.affection <= -20) {
          debugPrint('[P1-2 好感校验] 丢弃「$npcName +$delta」：当前好感=${target.affection}（敌对阶段），不能一下正向大跳涨。');
          return false;
        }
      }
    }

    return true;
  }
}
