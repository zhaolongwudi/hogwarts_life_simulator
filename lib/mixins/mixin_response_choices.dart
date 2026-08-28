
import '../providers/game_provider_base.dart';
import '../models/game_systems.dart';

mixin GameResponseChoiceMixin on GameProviderBase {
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
  List<GameChoice> extractChoicesFromRawText(String text) {
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
  int score(GameChoice c) {
    const advanceKeywords = <String>[
      '出发', '动身', '前往', '告别', '收拾', '起程', '离开', '走下楼梯',
      '走出房间', '去车站', '去对角巷', '出发前往', '立刻去', '大步走',
      '拥抱告别', '转身走向', '动身前往', '准备明天',
    ];
    var s = 0;
    final text = c.text + c.action;
    for (final kw in advanceKeywords) {
      if (text.contains(kw)) s += 10;
    }
    return s;
  }
  bool choiceMentionsUnintroducedNpc(
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
      if (looksLikeNarrationWord(cand)) continue;

      // (3) 候选命中 npcRegistry 的全名或别名，但是 introduced=false → 说明这是"还没出场的已知角色"
      //     比如开局前几回合就写"去找斯内普"，玩家根本没见过 → 要丢弃
      if (npcNameAll.containsKey(cand)) {
        // [选项NPC门] 命中登记但未introduced的NPC日志已移除
        return true;
      }
      // (4) 4字词几乎不可能是捏造NPC名（中文人名通常2~3字），直接放行
      if (cand.length >= 4) continue;
      // (5) 既不在白名单，也不像叙述词，还不是登记过的NPC，且是2-3字 →
      //     额外检查是否真的是人名模样：不含常见非人名用字 → 才判定为AI捏造的"霍尔"等假人
      //     BUG-N 修复：之前无条件丢弃所有未知2-4字词，导致"仔细观察""周围环境"等
      //     常见选项用词被误判为捏造NPC，绝大多数选项都被过滤掉。
      if (_candidateLooksLikeFabricatedNpcName(cand)) {
        // [选项NPC门] 疑似捏造陌生NPC日志已移除
        return true;
      }
      // 否则不像捏造NPC名 → 放行（可能是普通动词/名词）
    }
    return false;
  }
  bool _candidateLooksLikeFabricatedNpcName(String cand) {
    if (cand.length < 2 || cand.length > 3) return false;
    // 如果包含常见的非人名汉字 → 不是捏造NPC名
    // 这些字在中文普通词汇中高频出现，但极少出现在NPC名字中
    if (RegExp(r'[仔细观察周围环境线索寻找练习检查尝试继续准备考虑决定选择告诉讨论商量确认提醒建议邀请帮助跟随收集整理收拾出发前往拜访搭话转身点头摇头沉默叹气微笑皱眉盯着望着低头抬头伸手举手放下拿起掏出插入抽出推开拉开站起坐下躺下靠在躲在藏在次遍趟件事情]').hasMatch(cand)) {
      return false;
    }
    return true;
  }
  static bool looksLikeNarrationWord(String s) {
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
  bool standaloneNameMentioned(String text, String name) {
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
}
