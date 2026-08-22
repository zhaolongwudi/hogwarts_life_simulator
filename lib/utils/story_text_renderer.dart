import 'package:flutter/material.dart';

class StoryTextRenderer {
  // ====== 解析缓存（key=文本内容，避免 hash 冲突） ======
  static final Map<String, List<TextSpan>> _cache = {};
  static const int _maxCacheSize = 32;

  static final List<String> _characterNames = [
    '哈利·波特', '赫敏·格兰杰', '罗恩·韦斯莱', '纳威·隆巴顿',
    '查理·韦斯莱',
    '拉文德·布朗', '西莫·斐尼甘', '帕瓦蒂·帕蒂尔', '迪安·托马斯',
    '金妮·韦斯莱', '科林·克里维', '珀西·韦斯莱', '奥利弗·伍德',
    '弗雷德·韦斯莱', '乔治·韦斯莱', '李·乔丹', '安吉丽娜·约翰逊',
    '德拉科·马尔福', '文森特·克拉布', '格雷戈里·高尔', '潘西·帕金森',
    '阿斯托利亚·格林格拉斯', '西奥多·诺特', '布拉德利·扎比尼',
    '阿不思·邓布利多', '米勒娃·麦格', '西弗勒斯·斯内普', '鲁伯·海格',
    '菲利乌斯·弗立维', '波莫娜·斯普劳特', '罗兰达·霍琦', '西比尔·特里劳妮',
    '阿格斯·费尔奇', '伊尔玛·平斯', '波比·庞弗雷', '宾斯教授',
    '霍拉斯·斯拉格霍恩', '吉德罗·洛哈特', '多洛雷斯·乌姆里奇',
    '奥罗·布莱克', '贝拉特里克斯·莱斯特兰奇', '卢修斯·马尔福',
    '纳西莎·马尔福', '彼得·佩迪鲁', '小矮星彼得',
    '莱姆斯·卢平', '尼法朵拉·唐克斯', '天狼星·布莱克', '小天狼星',
    '詹姆·波特', '莉莉·波特', '莉莉·伊万斯', '西吉·格林', '弗农·德思礼',
    '佩妮·德思礼', '达力·德思礼', '莫丽·韦斯莱', '亚瑟·韦斯莱',
    '莉娜·斯特兰奇', '塞德里克·迪戈里', '卢娜·洛夫古德',
    '马克·麦克拉根', '罗米达·万尼', '克丽奥娜·张伯伦',
    '哈利', '赫敏', '罗恩', '纳威', '金妮', '弗雷德', '乔治',
    '马尔福', '斯内普', '邓布利多', '麦格', '海格', '弗立维',
    '斯普劳特', '特里劳妮', '费尔奇', '庞弗雷', '洛哈特',
    '卢平', '唐克斯', '布莱克', '波特', '韦斯莱', '迪戈里', '洛夫古德',
    '德拉科', '珀西', '克拉布', '高尔', '莉莉', '詹姆', '塞德里克',
    '卢娜', '霍琦', '斯拉格霍恩', '平斯', '费尔奇',
    '查理',
  ];

  static final List<String> _locations = [
    '霍格沃茨', '霍格沃茨城堡', '霍格莫德', '霍格莫德村',
    '对角巷', '翻倒巷', '伦敦', '魔法部',
    '大礼堂', '天文塔', '拉文克劳塔', '格兰芬多塔', '斯莱特林地牢',
    '赫奇帕奇地下室', '黑湖', '禁林', '图书馆', '温室',
    '魔药课教室', '魔咒教室', '变形课教室', '黑魔法防御术教室',
    '决斗俱乐部', '训练场', '海格的小屋', '魁地奇球场',
    '国王十字车站', '格里莫广场12号', '圣芒戈魔法伤病医院',
    '破釜酒吧', '古灵阁', '古灵阁巫师银行',
    '蜂蜜公爵糖果店', '帕笛芙夫人茶馆', '佐科笑话店',
    '三把扫帚酒吧', '猪头酒吧', '霍格莫德车站', '霍格莫德邮局',
    '尖叫棚屋', '风雅牌巫师服装店', '德维斯和班斯商店',
    '奥利凡德魔杖店', '丽痕书店', '韦斯莱魔法把戏坊',
    '神奇动物商店', '药店', '博金·博克古董店',
    '陋居', '马尔福庄园', '女贞路4号', '诺特庄园',
    '霍格沃茨特快', '霍格沃茨特快列车',
  ];

  static final List<String> _items = [
    '魔杖', '飞天扫帚', '光轮2000', '光轮2001', '火弩箭',
    '魂器', '死亡圣器', '魔法石', '贤者之石',
    '分院帽', '冥想盆', '厄里斯魔镜', '时间转换器',
    '比比多味豆', '巧克力蛙', '黄油啤酒', '南瓜汁',
    '复方汤剂', '福灵剂', '幸运水', '吐真剂',
    '隐形斗篷', '复活石', '接骨木魔杖', '凤凰尾羽',
    '猫狸子', '猫头鹰', '蟾蜍', '火龙', '鹰头马身有翼兽',
    '《预言家日报》', '《唱唱反调》', '《纯血统家族通览》',
    '加隆', '西可', '纳特',
    '魔法部徽章', '凤凰社徽章', '黑魔法防御术徽章',
    '活点地图', '真正的魔杖', '魂器碎片',
    '老魔杖', '接骨木魔杖', '紫杉木魔杖', '冬青木魔杖',
  ];

  static const Color _narrationColor = Color(0xFFC9D1D9);
  static const Color _dialogueColor = Color(0xFF58A6FF);
  static const Color _dialogueSpeakerColor = Color(0xFFFFA657);
  static const Color _characterColor = Color(0xFFE3B341);
  static const Color _locationColor = Color(0xFF56D364);
  static const Color _itemColor = Color(0xFFBC8CFF);

  static TextStyle _narrationStyle = const TextStyle(
    fontSize: 15, height: 1.8, color: _narrationColor,
  );

  static TextStyle _dialogueStyle = const TextStyle(
    fontSize: 15, height: 1.8, color: _dialogueColor,
    fontWeight: FontWeight.w500,
  );

  static TextStyle _dialogueSpeakerStyle = const TextStyle(
    fontSize: 15, height: 1.8, color: _dialogueSpeakerColor,
    fontWeight: FontWeight.w700,
  );

  static TextStyle _characterStyle = const TextStyle(
    fontSize: 15, height: 1.8, color: _characterColor,
    fontWeight: FontWeight.w600,
  );

  static TextStyle _locationStyle = const TextStyle(
    fontSize: 15, height: 1.8, color: _locationColor,
    fontWeight: FontWeight.w500,
  );

  static TextStyle _itemStyle = const TextStyle(
    fontSize: 15, height: 1.8, color: _itemColor,
    fontWeight: FontWeight.w500,
  );

  static const Color _affectionColor = Color(0xFF8B949E);
  static TextStyle _affectionStyle = const TextStyle(
    fontSize: 12, height: 1.8, color: _affectionColor,
    fontStyle: FontStyle.italic,
  );
  static TextStyle _affectionCharacterStyle = const TextStyle(
    fontSize: 12, height: 1.8, color: _affectionColor,
    fontStyle: FontStyle.italic, fontWeight: FontWeight.w600,
  );

  /// 使用说明：解析文本并将【好感度变化】标记后的段落以柔和样式渲染。
  /// 好感度变化段落的字体更小（fontSize: 12）、颜色更淡（#8B949E）、斜体显示，
  /// 使其与正文叙述形成视觉层次。
  /// 同时兼容正文里直接出现的「姓名：+5（说明）」/「好感+N」这种裸好感度行，
  /// 统一以好感度柔和样式渲染。
  /// 常规段落与 [parse] 方法保持一致的渲染效果。
  static List<TextSpan> parseWithAffectionStyle(String text) {
    if (text.isEmpty) return [];
    var cleaned = _stripOutlineLabels(text);
    cleaned = _stripChoiceBlocks(cleaned);
    cleaned = _preStripChoices(cleaned);
    cleaned = _promoteAffectionLines(cleaned);

    final spans = <TextSpan>[];
    final markerPattern = RegExp(r'【[^】]*】');
    final matches = markerPattern.allMatches(cleaned).toList();

    if (matches.isEmpty) {
      return parse(cleaned);
    }

    int currentPos = 0;

    for (final match in matches) {
      if (match.start > currentPos) {
        spans.addAll(parse(cleaned.substring(currentPos, match.start)));
      }

      final markerText = match.group(0)!;
      final sectionEnd = _nextMarkerOrEnd(cleaned, match.end);

      if (markerText == '【好感度变化】') {
        spans.add(TextSpan(text: markerText, style: _narrationStyle));
        spans.addAll(
          _parseAffectionSection(cleaned.substring(match.end, sectionEnd)),
        );
      } else {
        spans.addAll(parse(cleaned.substring(match.start, sectionEnd)));
      }

      currentPos = sectionEnd;
    }

    if (currentPos < cleaned.length) {
      spans.addAll(parse(cleaned.substring(currentPos)));
    }

    return spans;
  }

  /// 预处理：把 AI 偶尔失控写出的结构化提纲标签（"环境氛围：""NPC的言行举止："
  /// "玩家的心理活动：""重要物品/事件的细节描写："等）剥掉，让它们后面的内容直接融入正文。
  /// 这是 Prompt 之外的兜底渲染保护。
  static String _stripOutlineLabels(String text) {
    final labels = [
      '环境氛围', '场景氛围',
      'NPC的言行举止', 'NPC 言行举止', 'NPC言行举止', '人物言行',
      '玩家的心理活动', '玩家心理活动', '心理活动',
      '重要物品/事件的细节描写', '重要物品与事件细节',
      '重要物品', '事件细节', '细节描写',
      '一、命运回响', '二、命运回响', '三、命运回响',
      '命运回响', '世界回响', '回响',
    ];
    String result = text;
    for (final label in labels) {
      // 匹配：行首/空白  label  冒号（全角/半角）  → 删除 label+冒号
      final pattern = RegExp(
        r'(?<=^|\n)\s*' + RegExp.escape(label) + r'\s*[：:]\s*',
        multiLine: true,
      );
      result = result.replaceAllMapped(pattern, (m) {
        // 保留原换行，删除 label+冒号+后续空白
        return '';
      });
    }
    // 处理序号小节标题（"一、xxx"）：仅当后面紧跟的内容为环境/心理/动作类空泛词时才剥
    return result;
  }

  static String _stripChoiceBlocks(String text) {
    final blockPatterns = [
      RegExp(r'【可选行动】[\s\S]*$'),
      RegExp(r'【自由行动】[\s\S]*$'),
      RegExp(r'【行动建议】[\s\S]*$'),
      RegExp(r'【备选行动】[\s\S]*$'),
      RegExp(r'【剧情选项】[\s\S]*$'),
      RegExp(r'【下回合选择】[\s\S]*$'),
      RegExp(r'【选择建议】[\s\S]*$'),
    ];
    var result = text;
    for (final pat in blockPatterns) {
      result = result.replaceAllMapped(pat, (m) => '');
    }
    return result.replaceAll(RegExp(r'\n{3,}'), '\n\n').trimRight();
  }

  /// 预处理：从剧情文本中剥掉内嵌的 A./B./C./D./E. 选项行（这些在下方「可选行动」区块单独显示）
  /// 支持：半角字母、全角字母（Ａ-Ｅ）、半角/全角句号、右括号、中文顿号「、」
  static String _preStripChoices(String text) {
    final buffer = StringBuffer();
    final choiceLinePattern = RegExp(
      r'^\s*(?:[A-Ea-e]|[Ａ-Ｅ])\s*(?:[\.\．、\)）])\s*',
    );
    // 兼容"1.""(1)"等数字编号，以及中文一、二、三、编号
    final numberedPattern = RegExp(
      r'^\s*(?:\d{1,2}\s*[\.\．、\)）]|[一二三四五六七八九十]{1,3}\s*[、\.．])\s*',
    );
    for (final line in text.split('\n')) {
      // 选项行：空行后紧跟选项说明（排除叙事里的正常句子引用）
      if (choiceLinePattern.hasMatch(line)) {
        final after = line.replaceFirst(choiceLinePattern, '');
        if (after.trim().isNotEmpty && after.trim().length <= 60) {
          continue; // 典型选项行：< 60 字的一句话行动
        }
      }
      if (numberedPattern.hasMatch(line)) {
        final after = line.replaceFirst(numberedPattern, '');
        if (after.trim().isNotEmpty && after.trim().length <= 60) {
          continue;
        }
      }
      buffer.writeln(line);
    }
    return buffer.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  static int _nextMarkerOrEnd(String text, int from) {
    final idx = text.indexOf('【', from);
    return idx == -1 ? text.length : idx;
  }

  /// 把正文里直接出现的「裸好感度行」提升包装成【好感度变化】区块，
  /// 以便统一用柔和样式渲染（淡色+斜体+名字加粗）。
  ///
  /// 支持的模式（行尾或独立行）：
  ///   莉莉：+5
  ///   （鼓励和支持）
  ///   → 包装成 【好感度变化】莉莉：+5\n（鼓励和支持）
  ///
  ///   莉莉：-3（背叛）、马尔福 +2、好感度：哈利 +10
  ///   → 同样识别
  static String _promoteAffectionLines(String text) {
    // 按行扫描，找：角色名 + 冒号? + [+-]数字 + 可选括号说明
    // 同时允许下一行紧跟着的（说明）一起包进去
    final sortedNames = List<String>.from(_characterNames)
      ..sort((a, b) => b.length.compareTo(a.length));
    final nameUnion = sortedNames.map(RegExp.escape).join('|');

    // 模式1: 行内包含 "姓名：+/-N" 或 "姓名 +/-N"（必须是行末，不跟其他叙述文字混在同一行非好感内容后面）
    // 模式2: 独立的好感度标签（"好感度变化："/"好感："前缀）
    final lineAffection = RegExp(
      r'^(?<prefix>.*?)'
      r'(?:'
        r'(?<name>' + nameUnion + r')\s*[：:]?\s*'
        r'(?<delta>[+-]\d{1,3})'
        r'\s*(?<note>[（(][^）)\n]*[）)])?'
      r'|'
        r'(?:好感度?变化?|声望变化?)\s*[：:]\s*.+'
      r')'
      r'\s*$',
      multiLine: true,
      unicode: true,
    );

    final lines = text.split('\n');
    final buffer = <String>[];
    int i = 0;
    bool inBlock = false; // 正在拼接裸好感度行
    final blockBuffer = StringBuffer();

    void flushBlock() {
      if (blockBuffer.isEmpty) return;
      buffer.add('【好感度变化】${blockBuffer.toString().trimRight()}');
      blockBuffer.clear();
      inBlock = false;
    }

    while (i < lines.length) {
      final line = lines[i];
      final match = lineAffection.firstMatch(line);

      if (match != null) {
        final prefix = match.namedGroup('prefix') ?? '';
        final namePart = match.namedGroup('name');
        // 必须：名字存在 + 前缀（prefix）不包含过长叙述内容
        // 如果前缀只有空白或结尾分隔符，认为这是独立好感度行（或行尾好感度），需要包起来
        bool isAffectionStandalone = false;
        if (namePart != null) {
          final trimmedPrefix = prefix.trim();
          // 前缀要么空，要么末尾是句子分隔符（句号/逗号/顿号等）
          if (trimmedPrefix.isEmpty) {
            isAffectionStandalone = true;
          } else {
            final last = trimmedPrefix.runes.last;
            const separators = [0x3002, 0xFF0C, 0x3001, 0xFF1B, 0x2026, 0x002E, 0x002C, 0x003B]; // 。，、；….,;
            if (separators.contains(last)) {
              isAffectionStandalone = true;
            }
          }
        } else {
          // 走 "好感度变化：xxx" 分支
          isAffectionStandalone = true;
        }

        if (isAffectionStandalone) {
          // 如果前缀有句子残留叙述（比如"...。莉莉：+5"），先把前缀部分输出为普通行，
          // 再把后面的"莉莉：+5"包进好感度区块
          final trimmedPrefix = prefix.trimRight();
          if (trimmedPrefix.isNotEmpty) {
            flushBlock();
            buffer.add(trimmedPrefix);
          }
          // 取本好感度行的内容（去掉前缀）
          final affContent = line.substring(prefix.length).trim();
          if (!inBlock) {
            inBlock = true;
          } else {
            blockBuffer.writeln();
          }
          blockBuffer.write(affContent);
          // 检查下一行是否全是（说明）括号 — 如果是就一起包进去
          if (i + 1 < lines.length) {
            final nextLine = lines[i + 1];
            if (RegExp(r'^\s*[（(][^）)\n]*[）)]\s*$').hasMatch(nextLine)) {
              blockBuffer.writeln();
              blockBuffer.write(nextLine.trim());
              i++;
            }
          }
          i++;
          continue;
        }
      }

      flushBlock();
      buffer.add(line);
      i++;
    }
    flushBlock();

    return buffer.join('\n');
  }

  static List<TextSpan> _parseAffectionSection(String text) {
    final spans = <TextSpan>[];
    final lines = text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: '\n'));
      final line = lines[i];
      if (line.isEmpty) continue;

      final characterName = _findCharacterAtStart(line);
      if (characterName != null) {
        spans.add(
          TextSpan(text: characterName, style: _affectionCharacterStyle),
        );
        spans.add(
          TextSpan(text: line.substring(characterName.length), style: _affectionStyle),
        );
      } else {
        spans.add(TextSpan(text: line, style: _affectionStyle));
      }
    }

    return spans;
  }

  static String? _findCharacterAtStart(String line) {
    final sortedNames = List<String>.from(_characterNames)
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final name in sortedNames) {
      if (line.startsWith(name)) return name;
    }
    return null;
  }

  static List<TextSpan> parse(String text) {
    if (text.isEmpty) return [];
    var cleaned = _stripOutlineLabels(text);
    cleaned = _stripChoiceBlocks(cleaned);
    cleaned = _preStripChoices(cleaned);

    final cached = _cache[cleaned];
    if (cached != null) return cached;

    final spans = <TextSpan>[];
    final tokens = _tokenize(cleaned);

    for (final token in tokens) {
      if (token is _DialogueSpeakerToken) {
        spans.add(TextSpan(text: token.text, style: _dialogueSpeakerStyle));
      } else if (token is _DialogueToken) {
        spans.add(TextSpan(text: token.text, style: _dialogueStyle));
      } else if (token is _CharacterToken) {
        spans.add(TextSpan(text: token.text, style: _characterStyle));
      } else if (token is _LocationToken) {
        spans.add(TextSpan(text: token.text, style: _locationStyle));
      } else if (token is _ItemToken) {
        spans.add(TextSpan(text: token.text, style: _itemStyle));
      } else {
        spans.add(TextSpan(text: token.text, style: _narrationStyle));
      }
    }

    if (_cache.length >= _maxCacheSize) {
      _cache.clear();
    }
    _cache[cleaned] = spans;
    return spans;
  }

  static List<_Token> _tokenize(String text) {
    final tokens = <_Token>[];
    int i = 0;

    final dialoguePatterns = [
      RegExp(r'「[^」]*」'),
      RegExp(r'"[^"]*"'),
      RegExp(r'『[^』]*』'),
      RegExp(r'“[^”]*”'),
      RegExp(r'‘[^’]*’'),
    ];

    final dialogueRanges = <_Range>[];
    for (final pattern in dialoguePatterns) {
      for (final match in pattern.allMatches(text)) {
        dialogueRanges.add(_Range(match.start, match.end, match.group(0)!));
      }
    }
    dialogueRanges.sort((a, b) => a.start.compareTo(b.start));

    // 冒号对话模式：「说话人：台词」/「说话人（情绪）：台词」
    // 逐行检测，排除时间（09:00）、日期（📅 年月日 星期）、叙述性「说：」等误判。
    final colonSegments = <_ColonSegment>[];
    {
      int lineStart = 0;
      while (lineStart <= text.length) {
        final newlineIdx = text.indexOf('\n', lineStart);
        final lineEnd = newlineIdx == -1 ? text.length : newlineIdx;
        final k = _findDialogueColon(text, lineStart, lineEnd);
        if (k >= 0) {
          colonSegments.add(_ColonSegment(
            speakerStart: _speakerStart(text, lineStart, k),
            speakerEnd: k,
            colonEnd: k + 1,
            contentEnd: lineEnd,
          ));
        }
        if (newlineIdx == -1) break;
        lineStart = newlineIdx + 1;
      }
    }
    // 按出现顺序排序（避免重复叠加）
    colonSegments.sort((a, b) => a.speakerStart.compareTo(b.speakerStart));

    void addToken(_Token token) {
      if (token.text.isNotEmpty) tokens.add(token);
    }

    StringBuffer currentNarration = StringBuffer();

    void flushNarration() {
      if (currentNarration.isNotEmpty) {
        final text = currentNarration.toString();
        final subTokens = _splitNarration(text);
        for (final t in subTokens) {
          addToken(t);
        }
        currentNarration.clear();
      }
    }

    final matchedDialogue = dialogueRanges;
    int dPointer = 0;
    int cPointer = 0;

    while (i < text.length) {
      // 优先判断冒号对话（通常比引号台词更准地定位说话人）
      if (cPointer < colonSegments.length && i == colonSegments[cPointer].speakerStart) {
        flushNarration();
        final seg = colonSegments[cPointer];
        final speaker = text.substring(seg.speakerStart, seg.speakerEnd);
        final colon = text.substring(seg.speakerEnd, seg.colonEnd);
        final content = text.substring(seg.colonEnd, seg.contentEnd);
        addToken(_DialogueSpeakerToken(speaker));
        addToken(_DialogueToken(colon));
        addToken(_DialogueToken(content));
        i = seg.contentEnd;
        cPointer++;
        continue;
      }
      if (dPointer < matchedDialogue.length && i == matchedDialogue[dPointer].start) {
        flushNarration();
        final dEnd = matchedDialogue[dPointer].end;
        addToken(_DialogueToken(text.substring(i, dEnd)));
        i = dEnd;
        dPointer++;
      } else {
        currentNarration.writeCharCode(text.codeUnitAt(i));
        i++;
      }
    }

    flushNarration();
    return tokens;
  }

  /// 在 [text] 的 [lineStart, lineEnd) 区间内查找对话冒号（说话人：台词）的位置。
  /// 找不到返回 -1。
  static int _findDialogueColon(String text, int lineStart, int lineEnd) {
    for (int i = lineStart; i < lineEnd; i++) {
      final ch = text[i];
      if (ch != '：' && ch != ':') continue;
      // 时钟时间（数字:数字，如 9:00 / 09:00）不算对话
      if (_isClockColon(text, i)) continue;
      final speaker =
          text.substring(_speakerStart(text, lineStart, i), i).trim();
      if (_isValidSpeaker(speaker)) return i;
    }
    return -1;
  }

  /// 冒号前后是否紧邻数字（时钟格式）。
  static bool _isClockColon(String text, int i) {
    if (i <= 0 || i >= text.length - 1) return false;
    final b = text.codeUnitAt(i - 1);
    final a = text.codeUnitAt(i + 1);
    return b >= 0x30 && b <= 0x39 && a >= 0x30 && a <= 0x39;
  }

  /// 行内说话人起点：跳过行首空白 + 允许说话人跟在句子分隔符（句号/问号/感叹号/分号等）之后。
  /// 例：「心中涌起一股暖流。莉莉：+5」应提取说话人「莉莉」，而不是从行首开始。
  static int _speakerStart(String text, int lineStart, int colonIdx) {
    // 1. 找到最近的句子分隔符（句号/问号/感叹号/分号/逗号/顿号/省略号…）
    int s = lineStart;
    int lastSentenceBreak = lineStart - 1;
    for (int i = lineStart; i < colonIdx; i++) {
      final c = text[i];
      if (c == '。' || c == '！' || c == '？' || c == '；' || c == '…' ||
          c == '.' || c == '!' || c == '?' || c == ';' || c == '~') {
        lastSentenceBreak = i;
      }
    }
    if (lastSentenceBreak >= lineStart) {
      s = lastSentenceBreak + 1; // 从分隔符的下一个字符开始
    }
    // 2. 跳过开头空白（空格/Tab/不换行空格）
    while (s < colonIdx) {
      final c = text.codeUnitAt(s);
      if (c != 0x20 && c != 0x09 && c != 0xA0) break;
      s++;
    }
    return s;
  }

  /// 判断冒号前文本是否为合理的说话人（角色名/短人名），排除时间、日期、标签、叙述。
  static bool _isValidSpeaker(String raw) {
    if (raw.isEmpty || raw.length > 24) return false;
    // 结构标记 / 时间戳方括号
    if (raw.contains('【') ||
        raw.contains('】') ||
        raw.contains('[') ||
        raw.contains(']')) {
      return false;
    }
    // emoji 前缀（时间戳 📅 等）
    if (_startsWithEmoji(raw)) return false;

    // 提取纯名字：去掉「（情绪）」「(动作)」「好感+1」等修饰
    String name = raw;
    final bracket = name.indexOf(RegExp(r'[（(]'));
    if (bracket >= 0) name = name.substring(0, bracket);
    final gk = name.indexOf('好感');
    if (gk >= 0) name = name.substring(0, gk);
    name = name.trim();
    if (name.isEmpty) return false;

    // 已知角色名（含带修饰的原始串）
    if (_characterNames.contains(name) || _characterNames.contains(raw)) {
      return true;
    }

    // 时间/日期/状态等标签不是人名
    const labels = ['时间', '日期', '星期', '月份', '地点', '位置', '状态', '身份',
      '模式', '目标', '学年', '学期', '年级', '天气', '场景', '当前', '剩余'];
    for (final l in labels) {
      if (name.contains(l)) return false;
    }

    // 长度 1~8，允许中文/字母/数字/·/空格；纯数字或含叙述标点则排除
    if (name.length > 8) return false;
    if (RegExp(r'^[\d\s.:,，、]+$').hasMatch(name)) return false;
    if (RegExp(r'[，。！？、；：:]').hasMatch(name)) return false;

    return true;
  }

  static bool _startsWithEmoji(String s) {
    if (s.isEmpty) return false;
    final first = s.runes.first;
    return (first >= 0x1F300 && first <= 0x1FAFF) ||
        (first >= 0x2600 && first <= 0x27BF) ||
        (first >= 0x2B00 && first <= 0x2BFF);
  }

  /// 自动段落排版：将长文本按句号/问号/感叹号 + 长度阈值自动分段
  static String autoParagraph(String text) {
    if (text.isEmpty) return '';
    
    final buffer = StringBuffer();
    int sentenceCount = 0;
    int paragraphLength = 0;
    
    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      buffer.write(ch);
      paragraphLength++;
      
      // 检测段落结束：句末标点 + 长度达标
      if (ch == '。' || ch == '！' || ch == '？' || ch == '.' || ch == '!' || ch == '?') {
        sentenceCount++;
        // 每 2-3 句话 或 段落长度达到 100-150 字符时分段
        if ((sentenceCount >= 3 && paragraphLength >= 80) || 
            paragraphLength >= 150) {
          buffer.write('\n\n');
          sentenceCount = 0;
          paragraphLength = 0;
        }
      }
      
      // 保留原有的双换行（AI 主动分段）
      if (ch == '\n' && i + 1 < text.length && text[i + 1] == '\n') {
        sentenceCount = 0;
        paragraphLength = 0;
      }
    }
    
    // 清理多余空行
    var result = buffer.toString();
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return result.trim();
  }

  /// 从文本中提取好感变化区块（返回 Map：纯叙事文本 + 好感变化文本列表）
  static Map<String, dynamic> extractAffectionSections(String text) {
    final affectionPattern = RegExp(r'【好感度变化】[\s\S]*?(?=【|$)');
    final reputationPattern = RegExp(r'【声望变化】[\s\S]*?(?=【|$)');
    
    final affectionMatches = affectionPattern.allMatches(text);
    final reputationMatches = reputationPattern.allMatches(text);
    
    final affectionSections = <String>[];
    for (final m in affectionMatches) {
      final section = text.substring(m.start, m.end).trim();
      if (section.isNotEmpty) affectionSections.add(section);
    }
    for (final m in reputationMatches) {
      final section = text.substring(m.start, m.end).trim();
      if (section.isNotEmpty) affectionSections.add(section);
    }
    
    // 从原文本中移除好感/声望区块，返回纯叙事
    var narrative = text;
    narrative = narrative.replaceAllMapped(affectionPattern, (m) => '');
    narrative = narrative.replaceAllMapped(reputationPattern, (m) => '');
    narrative = narrative.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    narrative = narrative.trim();
    
    return {
      'narrative': narrative,
      'affectionSections': affectionSections,
    };
  }

  static List<_Token> _splitNarration(String text) {
    final tokens = <_Token>[];
    final replacements = <_Replacement>[];
    final coveredRanges = <_Range>{};

    void addReplacement(int start, String word, _TokenType type) {
      final range = _Range(start, start + word.length, word);
      final overlap = coveredRanges.any((r) =>
          range.start < r.end && range.end > r.start);
      if (!overlap) {
        coveredRanges.add(range);
        replacements.add(_Replacement(start, word, type));
      }
    }

    final sortedNames = List<String>.from(_characterNames)
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final name in sortedNames) {
      int idx = 0;
      while (true) {
        idx = text.indexOf(name, idx);
        if (idx == -1) break;
        addReplacement(idx, name, _TokenType.character);
        idx += name.length;
      }
    }

    for (final loc in _locations) {
      int idx = 0;
      while (true) {
        idx = text.indexOf(loc, idx);
        if (idx == -1) break;
        addReplacement(idx, loc, _TokenType.location);
        idx += loc.length;
      }
    }

    for (final item in _items) {
      int idx = 0;
      while (true) {
        idx = text.indexOf(item, idx);
        if (idx == -1) break;
        addReplacement(idx, item, _TokenType.item);
        idx += item.length;
      }
    }

    replacements.sort((a, b) => a.start.compareTo(b.start));

    int pos = 0;
    for (final rep in replacements) {
      if (rep.start > pos) {
        tokens.add(_NarrationToken(text.substring(pos, rep.start)));
      }
      switch (rep.type) {
        case _TokenType.character:
          tokens.add(_CharacterToken(rep.word));
          break;
        case _TokenType.location:
          tokens.add(_LocationToken(rep.word));
          break;
        case _TokenType.item:
          tokens.add(_ItemToken(rep.word));
          break;
      }
      pos = rep.start + rep.word.length;
    }

    if (pos < text.length) {
      tokens.add(_NarrationToken(text.substring(pos)));
    }

    return tokens.isEmpty ? [_NarrationToken(text)] : tokens;
  }
}

enum _TokenType { character, location, item }

class _Range {
  final int start;
  final int end;
  final String text;
  _Range(this.start, this.end, this.text);
}

class _ColonSegment {
  final int speakerStart;
  final int speakerEnd;
  final int colonEnd;
  final int contentEnd;
  _ColonSegment({
    required this.speakerStart,
    required this.speakerEnd,
    required this.colonEnd,
    required this.contentEnd,
  });
}

class _Replacement {
  final int start;
  final String word;
  final _TokenType type;
  _Replacement(this.start, this.word, this.type);
}

class _Token {
  final String text;
  const _Token(this.text);
}

class _NarrationToken extends _Token {
  const _NarrationToken(super.text);
}

class _DialogueToken extends _Token {
  const _DialogueToken(super.text);
}

class _DialogueSpeakerToken extends _Token {
  const _DialogueSpeakerToken(super.text);
}

class _CharacterToken extends _Token {
  const _CharacterToken(super.text);
}

class _LocationToken extends _Token {
  const _LocationToken(super.text);
}

class _ItemToken extends _Token {
  const _ItemToken(super.text);
}
