import 'package:flutter/material.dart';

class StoryTextRenderer {
  static final List<String> _characterNames = [
    '哈利·波特', '赫敏·格兰杰', '罗恩·韦斯莱', '纳威·隆巴顿',
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
    '莱姆斯·卢平', '尼法朵拉·唐克斯', '天狼星·布莱克',
    '詹姆·波特', '莉莉·波特', '西吉·格林', '弗农·德思礼',
    '佩妮·德思礼', '达力·德思礼', '莫丽·韦斯莱', '亚瑟·韦斯莱',
    '莉娜·斯特兰奇', '塞德里克·迪戈里', '卢娜·洛夫古德',
    '马克·麦克拉根', '罗米达·万尼', '克丽奥娜·张伯伦',
    '哈利', '赫敏', '罗恩', '纳威', '金妮', '弗雷德', '乔治',
    '马尔福', '斯内普', '邓布利多', '麦格', '海格', '弗立维',
    '斯普劳特', '特里劳妮', '费尔奇', '庞弗雷', '洛哈特',
    '卢平', '唐克斯', '布莱克', '波特', '韦斯莱', '迪戈里', '洛夫古德',
    '德拉科', '珀西', '克拉布', '高尔',
  ];

  static final List<String> _locations = [
    '霍格沃茨', '霍格沃茨城堡', '霍格莫德', '霍格莫德村',
    '对角巷', '翻倒巷', '伦敦', '魔法部',
    '大礼堂', '天文塔', '拉文克劳塔', '格兰芬多塔', '斯莱特林地牢',
    '赫奇帕奇地下室', '黑湖', '禁林', '图书馆', '温室',
    '魔药课教室', '魔咒教室', '变形课教室', '魔法防御术教室',
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

  static TextStyle _narrationStyle = const TextStyle(
    fontSize: 15, height: 1.8, color: Color(0xFF4A3728),
  );

  static TextStyle _dialogueStyle = const TextStyle(
    fontSize: 15, height: 1.8, color: Color(0xFF1565C0),
    fontWeight: FontWeight.w500,
  );

  static TextStyle _characterStyle = const TextStyle(
    fontSize: 15, height: 1.8, color: Color(0xFFB45309),
    fontWeight: FontWeight.w600,
  );

  static TextStyle _locationStyle = const TextStyle(
    fontSize: 15, height: 1.8, color: Color(0xFF059669),
    fontWeight: FontWeight.w500,
  );

  static TextStyle _itemStyle = const TextStyle(
    fontSize: 15, height: 1.8, color: Color(0xFF7C3AED),
    fontWeight: FontWeight.w500,
  );

  static List<TextSpan> parse(String text) {
    if (text.isEmpty) return [];

    final spans = <TextSpan>[];
    final tokens = _tokenize(text);

    for (final token in tokens) {
      if (token is _DialogueToken) {
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

    return spans;
  }

  static List<_Token> _tokenize(String text) {
    final tokens = <_Token>[];
    int i = 0;

    final dialoguePatterns = [
      RegExp(r'「[^」]*」'),
      RegExp(r'"[^"]*"'),
      RegExp(r'『[^』]*』'),
      RegExp(r'"[^"]*"'),
    ];

    final dialogueRanges = <_Range>[];
    for (final pattern in dialoguePatterns) {
      for (final match in pattern.allMatches(text)) {
        dialogueRanges.add(_Range(match.start, match.end, match.group(0)!));
      }
    }
    dialogueRanges.sort((a, b) => a.start.compareTo(b.start));

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

    final matchedDialogue = <_Range>[];
    int dIdx = 0;
    for (final range in dialogueRanges) {
      if (dIdx < dialogueRanges.length && range == dialogueRanges[dIdx]) {
        matchedDialogue.add(range);
        dIdx++;
      }
    }

    int dPointer = 0;
    while (i < text.length) {
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

  static List<_Token> _splitNarration(String text) {
    final tokens = <_Token>[];
    final replacements = <_Replacement>[];

    for (final name in _characterNames) {
      int idx = 0;
      while (true) {
        idx = text.indexOf(name, idx);
        if (idx == -1) break;
        replacements.add(_Replacement(idx, name, _TokenType.character));
        idx += name.length;
      }
    }

    for (final loc in _locations) {
      int idx = 0;
      while (true) {
        idx = text.indexOf(loc, idx);
        if (idx == -1) break;
        final alreadyCovered = replacements.any((r) =>
            idx >= r.start && idx < r.start + r.word.length);
        if (!alreadyCovered) {
          replacements.add(_Replacement(idx, loc, _TokenType.location));
        }
        idx += loc.length;
      }
    }

    for (final item in _items) {
      int idx = 0;
      while (true) {
        idx = text.indexOf(item, idx);
        if (idx == -1) break;
        final alreadyCovered = replacements.any((r) =>
            idx >= r.start && idx < r.start + r.word.length);
        if (!alreadyCovered) {
          replacements.add(_Replacement(idx, item, _TokenType.item));
        }
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

class _CharacterToken extends _Token {
  const _CharacterToken(super.text);
}

class _LocationToken extends _Token {
  const _LocationToken(super.text);
}

class _ItemToken extends _Token {
  const _ItemToken(super.text);
}