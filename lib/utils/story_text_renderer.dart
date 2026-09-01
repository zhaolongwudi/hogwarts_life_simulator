import 'package:flutter/material.dart';

import '../data/item_data.dart';
import '../data/locations.dart';
import '../data/npc_data.dart';

// ==================== 小说式段落分类（v3.7 正文段落层次） ====================
//
// 正文不再是一整坨 600~800 字：按空行拆段后逐段分类，
// 叙述/对话/内心独白/时间戳各有独立的视觉形态（缩进、色系、背景）。
// 分类与 inline 高亮（人名/地点/物品）互不冲突——段落级样式管"这一段
// 读起来是什么"，inline 高亮管"这个词是什么"。
//
// Dart 不支持类内嵌套类型，故枚举与段落类放库顶层，
// StoryTextRenderer 内通过静态方法消费。

/// 段落类型。
enum ParagraphKind {
  /// 普通叙述：首行缩进两全角空格。
  narration,

  /// 对话段（含引号台词或「说话人：」开头）：顶格 + 左侧色条衬底。
  dialogue,

  /// 内心独白（括号包裹/心想/暗自）：斜体 + 浅紫。
  innerVoice,

  /// 时间戳 / 标记段（【时间戳】/📅/⏳ 开头）：金色胶囊。
  timestamp,
}

/// 分类后的剧情段落。
class StoryParagraph {
  final ParagraphKind kind;
  final String text;
  const StoryParagraph(this.kind, this.text);
}

class StoryTextRenderer {
  // ====== 解析缓存（key=文本内容，避免 hash 冲突） ======
  static final Map<String, List<TextSpan>> _cache = {};
  static const int _maxCacheSize = 32;

  // ====== 实体词表 ======
  //
  // 三张表原先都是手抄的字面量，抄完就跟数据层脱钩了：
  //  - 角色：71 个 NPC 里有 22 个从来没被高亮过，第一次巫师战争时代的 12 个
  //    原创 NPC 全军覆没。而这张表的用途远不止染色——好感行的识别正则、台
  //    词说话人判定都拿它拼，所以那个时代的玩家「马琳：+3」这类好感变化根
  //    本显示不出来。
  //  - 物品：53 个物品名只覆盖了 3 个。
  //  这已经是本项目第七次栽在「同一份表手抄 N 遍」上（房屋表 5 遍、CG 条件
  //  2 遍…），统一改成从数据层派生，加 NPC / 加物品自动跟上。
  //
  // 派生之后仍保留一份「补充词」，补的是数据层里没有、但剧情会提到的东西
  // （德思礼一家这类不在册人物、AI 爱用的简称、传说道具等）。

  /// NPC 名录之外的人物：有剧情但没进 NPC 表的角色，以及 AI 常用的简称。
  static const List<String> _extraCharacterWords = [
    '哈利·波特',
    '赫敏·格兰杰',
    '罗恩·韦斯莱',
    '纳威·隆巴顿',
    '查理·韦斯莱',
    '拉文德·布朗',
    '西莫·斐尼甘',
    '帕瓦蒂·帕蒂尔',
    '迪安·托马斯',
    '金妮·韦斯莱',
    '科林·克里维',
    '珀西·韦斯莱',
    '奥利弗·伍德',
    '弗雷德·韦斯莱',
    '乔治·韦斯莱',
    '李·乔丹',
    '安吉丽娜·约翰逊',
    '德拉科·马尔福',
    '文森特·克拉布',
    '格雷戈里·高尔',
    '潘西·帕金森',
    '阿斯托利亚·格林格拉斯',
    '西奥多·诺特',
    '布拉德利·扎比尼',
    '阿不思·邓布利多',
    '米勒娃·麦格',
    '西弗勒斯·斯内普',
    '鲁伯·海格',
    '菲利乌斯·弗立维',
    '波莫娜·斯普劳特',
    '罗兰达·霍琦',
    '西比尔·特里劳妮',
    '阿格斯·费尔奇',
    '伊尔玛·平斯',
    '波比·庞弗雷',
    '宾斯教授',
    '霍拉斯·斯拉格霍恩',
    '吉德罗·洛哈特',
    '多洛雷斯·乌姆里奇',
    '奥罗·布莱克',
    '贝拉特里克斯·莱斯特兰奇',
    '卢修斯·马尔福',
    '纳西莎·马尔福',
    '彼得·佩迪鲁',
    '小矮星彼得',
    '莱姆斯·卢平',
    '尼法朵拉·唐克斯',
    '天狼星·布莱克',
    '小天狼星',
    '詹姆·波特',
    '莉莉·波特',
    '莉莉·伊万斯',
    '西吉·格林',
    '弗农·德思礼',
    '佩妮·德思礼',
    '达力·德思礼',
    '莫丽·韦斯莱',
    '亚瑟·韦斯莱',
    '莉娜·斯特兰奇',
    '塞德里克·迪戈里',
    '卢娜·洛夫古德',
    '马克·麦克拉根',
    '罗米达·万尼',
    '克丽奥娜·张伯伦',
    '哈利',
    '赫敏',
    '罗恩',
    '纳威',
    '金妮',
    '弗雷德',
    '乔治',
    '马尔福',
    '斯内普',
    '邓布利多',
    '麦格',
    '海格',
    '弗立维',
    '斯普劳特',
    '特里劳妮',
    '费尔奇',
    '庞弗雷',
    '洛哈特',
    '卢平',
    '唐克斯',
    '布莱克',
    '波特',
    '韦斯莱',
    '迪戈里',
    '洛夫古德',
    '德拉科',
    '珀西',
    '克拉布',
    '高尔',
    '莉莉',
    '詹姆',
    '塞德里克',
    '卢娜',
    '霍琦',
    '斯拉格霍恩',
    '平斯',
    '费尔奇',
    '查理',
  ];

  /// 地点表（lib/data/locations.dart）之外的地名。
  static const List<String> _extraLocationWords = [
    '霍格沃茨',
    '霍格沃茨城堡',
    '霍格莫德',
    '霍格莫德村',
    '对角巷',
    '翻倒巷',
    '伦敦',
    '魔法部',
    '大礼堂',
    '天文塔',
    '拉文克劳塔',
    '格兰芬多塔',
    '斯莱特林地牢',
    '赫奇帕奇地下室',
    '黑湖',
    '禁林',
    '图书馆',
    '温室',
    '魔药课教室',
    '魔咒教室',
    '变形课教室',
    '黑魔法防御术教室',
    '决斗俱乐部',
    '训练场',
    '海格的小屋',
    '魁地奇球场',
    '国王十字车站',
    '格里莫广场12号',
    '圣芒戈魔法伤病医院',
    '破釜酒吧',
    '古灵阁',
    '古灵阁巫师银行',
    '蜂蜜公爵糖果店',
    '帕笛芙夫人茶馆',
    '佐科笑话店',
    '三把扫帚酒吧',
    '猪头酒吧',
    '霍格莫德车站',
    '霍格莫德邮局',
    '尖叫棚屋',
    '风雅牌巫师服装店',
    '德维斯和班斯商店',
    '奥利凡德魔杖店',
    '丽痕书店',
    '韦斯莱魔法把戏坊',
    '神奇动物商店',
    '药店',
    '博金·博克古董店',
    '陋居',
    '马尔福庄园',
    '女贞路4号',
    '诺特庄园',
    '霍格沃茨特快',
    '霍格沃茨特快列车',
  ];

  /// 物品表（lib/data/item_data.dart）之外的道具：传说器物、货币、刊物等。
  static const List<String> _extraItemWords = [
    '魔杖',
    '飞天扫帚',
    '光轮2000',
    '光轮2001',
    '火弩箭',
    '魂器',
    '死亡圣器',
    '魔法石',
    '贤者之石',
    '分院帽',
    '冥想盆',
    '厄里斯魔镜',
    '时间转换器',
    '比比多味豆',
    '巧克力蛙',
    '黄油啤酒',
    '南瓜汁',
    '复方汤剂',
    '福灵剂',
    '幸运水',
    '吐真剂',
    '隐形斗篷',
    '复活石',
    '接骨木魔杖',
    '凤凰尾羽',
    '猫狸子',
    '猫头鹰',
    '蟾蜍',
    '火龙',
    '鹰头马身有翼兽',
    '《预言家日报》',
    '《唱唱反调》',
    '《纯血统家族通览》',
    '加隆',
    '西可',
    '纳特',
    '魔法部徽章',
    '凤凰社徽章',
    '黑魔法防御术徽章',
    '活点地图',
    '真正的魔杖',
    '魂器碎片',
    '老魔杖',
    '接骨木魔杖',
    '紫杉木魔杖',
    '冬青木魔杖',
  ];

  /// 别名里的通用称谓/名词，不进高亮表。
  ///
  /// NPC 别名本来是给命令解析用的（玩家输入「送礼物 老邓」也认），里面混着
  /// 「妹妹」「叛徒」「级长」这类普通名词。直接拿来高亮的话，「他是个叛徒」
  /// 「双胞胎走进来」这种叙述文字会被染成角色色，比不高亮还糟。
  ///
  /// 这里显式排除。每个词都必须真的出现在某个 NPC 的别名里——有测试盯着，
  /// 免得这份清单以后变成一堆没人认领的字符串。
  static const Set<String> _aliasesTooGeneric = {
    '双胞胎',
    '叛徒',
    '妹妹',
    '护士长',
    '校医',
    '教父',
    '看门人',
    '管理员',
    '级长',
    '追球手',
    '解说员',
    '蝎子',
  };

  /// 角色名 = 补充词 + NPC 全名 + NPC 别名（去掉通用称谓）。
  static final Set<String> _characterNameSet = <String>{
    ..._extraCharacterWords,
    for (final npc in kAllNpcSeeds) npc.name,
    for (final npc in kAllNpcSeeds)
      ...npc.aliases.where(
        (a) => a.isNotEmpty && !_aliasesTooGeneric.contains(a),
      ),
  };

  static final List<String> _characterNames = _characterNameSet.toList();

  /// 物品名 = 补充词 + 物品目录 + 采集材料，去掉已被角色名占掉的。
  static final List<String> _items = _unclaimed(<String>[
    ..._extraItemWords,
    ...kItemCatalog.map((i) => i.name),
    ...kCommonLootMaterials,
    ...kRareLootMaterials,
  ], _characterNameSet);

  /// 地点名 = 补充词 + 地点表的主名与别名，去掉已被角色名/物品名占掉的。
  ///
  /// 为什么物品排在地点前面：地点表里的别名是「关联词」而不是「地名词」——
  /// 霍格沃茨大礼堂的别名里挂着「分院帽」「分院仪式」，一个是物件一个是
  /// 活动，都不算地名。照单全收去高亮，就会把「分院帽」染成地点绿，而它
  /// 本来是物品紫。
  static final List<String> _locations = _unclaimed(
    <String>[..._extraLocationWords, ...allLocationAliases],
    <String>{..._characterNameSet, ..._items},
  );

  /// 已被优先级更高的类别占掉的词不再重复收录。
  ///
  /// _splitNarration 按 角色 → 地点 → 物品 的顺序占位，先到先得，所以一个
  /// 词同时属于两类时必须先在这里去掉，否则低优先级那份永远轮不到，染出
  /// 来的颜色取决于哪份列表先被遍历——这种顺序依赖出一次问题要查半天。
  static List<String> _unclaimed(Iterable<String> words, Set<String> claimed) {
    final out = <String>[];
    final seen = <String>{};
    for (final w in words) {
      if (w.isEmpty || claimed.contains(w)) continue;
      if (seen.add(w)) out.add(w);
    }
    return out;
  }

  // 预排序（长词在前）：实体高亮优先命中长词（如「霍格莫德车站」优先于
  // 「霍格莫德」、「古灵阁巫师银行」优先于「古灵阁」），且只排序一次，
  // 避免每次解析时对列表重新排序。
  static final List<String> _characterNamesByLengthDesc = List<String>.from(
    _characterNames,
  )..sort((a, b) => b.length.compareTo(a.length));
  static final List<String> _locationsByLengthDesc = List<String>.from(
    _locations,
  )..sort((a, b) => b.length.compareTo(a.length));
  static final List<String> _itemsByLengthDesc = List<String>.from(_items)
    ..sort((a, b) => b.length.compareTo(a.length));

  // ====== 语义化颜色体系（深色主题·柔和调色板） ======
  //
  // 设计原则：
  // 1. 基色（叙述）为暖灰白，不刺眼、支撑长时间阅读
  // 2. 高亮色降低饱和度，减少互相争夺注意力
  // 3. 蓝色只用于对话引用，金色只用于说话人，避免混淆
  // 4. 角色/地点/物品三类实体高亮使用柔和的低饱和色
  static const Color _narrationColor = Color(0xFFD0D7DE);
  static const Color _dialogueColor = Color(0xFF79C0FF);
  static const Color _dialogueSpeakerColor = Color(0xFFFFC87A);
  static const Color _characterColor = Color(0xFFDDB54A);
  static const Color _locationColor = Color(0xFF7EE787);
  static const Color _itemColor = Color(0xFFD2A8FF);

  /// 共同行高：1.6 在中文长文本中提供舒适的阅读间距，
  /// 相比 1.8 更紧凑，让每个屏幕能多显示 2-3 行正文。
  static const double _bodyLineHeight = 1.6;

  static TextStyle _narrationStyle = const TextStyle(
    fontSize: 15,
    height: _bodyLineHeight,
    color: _narrationColor,
  );

  static TextStyle _dialogueStyle = const TextStyle(
    fontSize: 15,
    height: _bodyLineHeight,
    color: _dialogueColor,
    fontWeight: FontWeight.w500,
  );

  static TextStyle _dialogueSpeakerStyle = const TextStyle(
    fontSize: 15,
    height: _bodyLineHeight,
    color: _dialogueSpeakerColor,
    fontWeight: FontWeight.w700,
  );

  static TextStyle _characterStyle = const TextStyle(
    fontSize: 15,
    height: _bodyLineHeight,
    color: _characterColor,
    fontWeight: FontWeight.w600,
  );

  static TextStyle _locationStyle = const TextStyle(
    fontSize: 15,
    height: _bodyLineHeight,
    color: _locationColor,
    fontWeight: FontWeight.w500,
  );

  static TextStyle _itemStyle = const TextStyle(
    fontSize: 15,
    height: _bodyLineHeight,
    color: _itemColor,
    fontWeight: FontWeight.w500,
  );

  static const Color _affectionColor = Color(0xFF8B949E);
  static TextStyle _affectionStyle = const TextStyle(
    fontSize: 12,
    height: _bodyLineHeight,
    color: _affectionColor,
    fontStyle: FontStyle.italic,
  );
  static TextStyle _affectionCharacterStyle = const TextStyle(
    fontSize: 12,
    height: _bodyLineHeight,
    color: _affectionColor,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w600,
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

      if (markerText == '【好感度变化】' || markerText == '【好感变化】') {
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
      spans.addAll(parseNarrative(cleaned.substring(currentPos)));
    }

    return spans;
  }

  /// AI 偶尔失控写出的结构化提纲标签（"环境氛围：""NPC的言行举止："
  /// "玩家的心理活动：""重要物品/事件的细节描写："等）。
  /// 原先是 _stripOutlineLabels 里的局部非 const 列表（每次调用重建一次）。
  static const List<String> _outlineLabels = [
    '环境氛围',
    '场景氛围',
    'NPC的言行举止',
    'NPC 言行举止',
    'NPC言行举止',
    '人物言行',
    '玩家的心理活动',
    '玩家心理活动',
    '心理活动',
    '重要物品/事件的细节描写',
    '重要物品与事件细节',
    '重要物品',
    '事件细节',
    '细节描写',
    '一、命运回响',
    '二、命运回响',
    '三、命运回响',
    '命运回响',
    '世界回响',
    '回响',
  ];

  /// 提纲标签的剥离正则，按标签预编译。_stripOutlineLabels 每次渲染都跑，
  /// 原先 20 个标签在循环里现编译 20 遍。
  static final Map<String, RegExp> _outlineLabelPatterns = <String, RegExp>{
    for (final label in _outlineLabels)
      label: RegExp(
        r'(?<=^|\n)\s*' + RegExp.escape(label) + r'\s*[：:]\s*',
        multiLine: true,
      ),
  };

  /// 整行只有一对括号说明（"……（低声）"的下一行），要跟上一行一起包进引用块。
  static final RegExp _parenOnlyLineRe = RegExp(r'^\s*[（(][^）)\n]*[）)]\s*$');

  /// 单字叙述动词（说/道/问…）必须左右都不是中文才算独立动词，
  /// 否则"冷笑"里的"笑"会被当成动词命中。按动词预编译——
  /// _validSpeakerNameEnd 对每一行都要跑一遍这个循环。
  static final Map<String, RegExp> _singleCharVerbPatterns = <String, RegExp>{
    for (final v in _speechVerbs)
      if (v.length == 1)
        v: RegExp(
          r'(?:^|[^\u4e00-\u9fa5])' +
              RegExp.escape(v) +
              r'(?:$|[^\u4e00-\u9fa5])',
        ),
  };

  /// 预处理：把 AI 偶尔失控写出的结构化提纲标签（"环境氛围：""NPC的言行举止："
  /// "玩家的心理活动：""重要物品/事件的细节描写："等）剥掉，让它们后面的内容直接融入正文。
  /// 这是 Prompt 之外的兜底渲染保护。
  static String _stripOutlineLabels(String text) {
    String result = text;
    for (final entry in _outlineLabelPatterns.entries) {
      // 匹配：行首/空白  label  冒号（全角/半角）  → 删除 label+冒号
      final pattern = entry.value;
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
    final lines = text.split('\n');
    final choiceLinePattern = RegExp(
      r'^\s*(?:[A-Ea-e]|[Ａ-Ｅ])\s*(?:[\.\．、\)）])\s*',
    );
    // 兼容"1.""(1)"等数字编号，以及中文一、二、三、编号
    final numberedPattern = RegExp(
      r'^\s*(?:\d{1,2}\s*[\.\．、\)）]|[一二三四五六七八九十]{1,3}\s*[、\.．])\s*',
    );

    // 一行是否像选项：短祈使短语、不以句号/感叹号/省略号收尾
    bool isChoiceLike(String line) {
      for (final p in [choiceLinePattern, numberedPattern]) {
        final m = p.firstMatch(line);
        if (m == null) continue;
        final after = line.substring(m.end).trim();
        if (after.isEmpty || after.length > 60) return false;
        if (after.endsWith('。') || after.endsWith('！') || after.endsWith('…')) {
          return false;
        }
        return true;
      }
      return false;
    }

    final choiceLike = lines.map(isChoiceLike).toList();
    final buffer = StringBuffer();
    for (int i = 0; i < lines.length; i++) {
      if (choiceLike[i]) {
        // 选项总是成块出现：前一行是空行/选项，或后一行紧跟选项。
        // 满足其一才剥离，避免误删以「A.」「一、」开头的正常叙述句。
        final prevBlank =
            i == 0 || lines[i - 1].trim().isEmpty || choiceLike[i - 1];
        final nextChoice = i + 1 < lines.length && choiceLike[i + 1];
        if (prevBlank || nextChoice) continue;
      }
      buffer.writeln(lines[i]);
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
  /// 行内好感变化正则。
  ///
  /// 名字表改成从 NPC 数据派生后有 300 多个分支，而这个正则是在解析缓存
  /// 之前构造的（见 parseWithAffectionStyle），原先每次渲染都重新拼一遍
  /// 字符串、重新编译一次。名字表是静态的，正则也应该是静态的。
  static final RegExp _lineAffection = RegExp(
    r'^(?<prefix>.*?)'
            r'(?:'
            r'(?<name>' +
        _affectionNameUnion +
        r')\s*[：:]?\s*'
            r'(?<delta>[+-]\d{1,3})'
            r'\s*(?<note>[（(][^）)\n]*[）)])?'
            r'|'
            r'(?:好感度?变化?|声望变化?)\s*[：:]\s*.+'
            r')'
            r'\s*$',
    multiLine: true,
    unicode: true,
  );

  /// 名字分支（长名在前，保证「哈利·波特」优先于「哈利」）。
  static final String _affectionNameUnion =
      (_characterNames.toList()..sort((a, b) => b.length.compareTo(a.length)))
          .map(RegExp.escape)
          .join('|');

  static String _promoteAffectionLines(String text) {
    // 按行扫描，找：角色名 + 冒号? + [+-]数字 + 可选括号说明
    // 同时允许下一行紧跟着的（说明）一起包进去

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
      final match = _lineAffection.firstMatch(line);

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
            const separators = [
              0x3002,
              0xFF0C,
              0x3001,
              0xFF1B,
              0x2026,
              0x002E,
              0x002C,
              0x003B,
            ]; // 。，、；….,;
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
            if (_parenOnlyLineRe.hasMatch(nextLine)) {
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
          TextSpan(
            text: line.substring(characterName.length),
            style: _affectionStyle,
          ),
        );
      } else {
        spans.add(TextSpan(text: line, style: _affectionStyle));
      }
    }

    return spans;
  }

  static String? _findCharacterAtStart(String line) {
    // 直接用预排序好的那份：以前这里每调用一次就复制 + 重排一遍全量角色名
    // （~480 条），而 parse 是逐行调它的，一段 30 行的叙事就是 30 次全量排序。
    for (final name in _characterNamesByLengthDesc) {
      if (line.startsWith(name)) return name;
    }
    return null;
  }

  static List<TextSpan> parse(String text) => _parse(text, quiet: false);

  /// 正文专用解析：地点/物品的颜色降级为 narration（与正文同色）。
  /// 保留人名/说话人/对话/内心独白的颜色——核心信息（是谁、说了什么、心里想）。
  /// 设计意图：上一版所有实体词都上色导致正文"花里胡哨"，阅读疲劳；
  /// 现在只有语义关键的颜色存在，地点/物品与正文融为一体。
  static List<TextSpan> parseNarrative(String text) =>
      _parse(text, quiet: true);

  static List<TextSpan> _parse(String text, {required bool quiet}) {
    if (text.isEmpty) return [];
    var cleaned = _stripOutlineLabels(text);
    cleaned = _stripChoiceBlocks(cleaned);
    cleaned = _preStripChoices(cleaned);

    // 命中缓存时刷新插入顺序（近似 LRU）
    final cached = _cache.remove(cleaned);
    if (cached != null) {
      _cache[cleaned] = cached;
      return cached;
    }

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
        // quiet 模式：地点融入正文，不上色；full 模式保持原色（其他模块可能用）
        spans.add(
          TextSpan(
            text: token.text,
            style: quiet ? _narrationStyle : _locationStyle,
          ),
        );
      } else if (token is _ItemToken) {
        spans.add(
          TextSpan(
            text: token.text,
            style: quiet ? _narrationStyle : _itemStyle,
          ),
        );
      } else {
        spans.add(TextSpan(text: token.text, style: _narrationStyle));
      }
    }

    // 缓存满时淘汰最旧条目（保留其余命中），而不是整表清空
    while (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[cleaned] = spans;
    return spans;
  }

  static List<_Token> _tokenize(String text) {
    final tokens = <_Token>[];
    int i = 0;
    final int textLen =
        text.length; // BUG-CRASH: text 可能在子串操作后被改变？这里固定一份长度缓存，全程用 textLen 校验

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

    // 冒号对话模式：「说话人：台词」/「说话人（情绪）：台词」/「说话人说：台词」
    // 逐行检测，排除时间（09:00）、日期（📅 年月日 星期）、叙述性「说：」等误判。
    final colonSegments = <_ColonSegment>[];
    {
      final safeMax = text.length; // 闭包级安全边界
      int lineStart = 0;
      while (lineStart <= safeMax) {
        final newlineIdx = text.indexOf('\n', lineStart);
        final lineEnd = newlineIdx == -1 ? safeMax : newlineIdx;
        if (lineStart > lineEnd || lineStart > safeMax) break;
        final k = _findDialogueColon(text, lineStart, lineEnd);
        if (k >= lineStart && k < lineEnd) {
          final speakerStartIdx = _speakerStart(text, lineStart, k);
          // BUG-CRASH 修复：speakerStartIdx 必须在 [lineStart, k] 内，否则 substring 越界
          final safeSpeakerStart =
              (speakerStartIdx < lineStart || speakerStartIdx > k)
              ? lineStart
              : speakerStartIdx;
          final raw = text.substring(safeSpeakerStart, k).trim();
          final nameEndInRaw = _validSpeakerNameEnd(raw);
          if (nameEndInRaw < 0) continue; // 无效，跳过这段
          // BUG-CRASH 修复：nameEndInRaw（raw内）转 absolute 后不能超过 k（冒号前）
          final safeNameEnd = safeSpeakerStart + nameEndInRaw;
          if (safeNameEnd < safeSpeakerStart || safeNameEnd > k) continue;
          // k + 1（colonEnd）不能超 safeMax
          final colonEnd = k + 1;
          if (colonEnd > safeMax) continue;
          // lineEnd（contentEnd）不能超 safeMax
          final contentEnd = lineEnd;
          colonSegments.add(
            _ColonSegment(
              speakerStart: safeSpeakerStart,
              nameEnd: safeNameEnd,
              speakerEnd: k,
              colonEnd: colonEnd,
              contentEnd: contentEnd > safeMax ? safeMax : contentEnd,
            ),
          );
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

    while (i < textLen) {
      // 跳过已被越过（被跨行引号台词范围覆盖）的冒号段落
      while (cPointer < colonSegments.length &&
          i > colonSegments[cPointer].speakerStart) {
        cPointer++;
      }
      // 优先判断冒号对话（通常比引号台词更准地定位说话人）
      if (cPointer < colonSegments.length &&
          i == colonSegments[cPointer].speakerStart) {
        flushNarration();
        final seg = colonSegments[cPointer];
        // BUG-CRASH 终极安全门：所有 substring 边界都用 RangeError.checkValidRange 前的显式钳制
        int ss = seg.speakerStart;
        int se = seg.nameEnd;
        int ce = seg.colonEnd;
        int spe = seg.speakerEnd;
        int cte = seg.contentEnd;
        if (ss < 0) ss = 0;
        if (se < ss) se = ss; // nameEnd 最小 = speakerStart（空 speaker 也行，不 crash）
        if (spe < se) spe = se;
        if (ce < spe) ce = spe;
        if (cte < ce) cte = ce;
        if (se > textLen) se = textLen;
        if (spe > textLen) spe = textLen;
        if (ce > textLen) ce = textLen;
        if (cte > textLen) cte = textLen;
        final speaker = text.substring(ss, se);
        final content = text.substring(ce, cte);
        addToken(_DialogueSpeakerToken(speaker));
        if (se < spe) {
          // 「名字+叙述动词」：动词连同冒号按叙述色渲染（如 赫敏说："…"）
          final verbAndColon = se <= ce ? text.substring(se, ce) : '';
          addToken(_NarrationToken(verbAndColon));
        } else {
          // 纯「名字：」：冒号紧贴台词，按对话色渲染
          final colonStr = spe <= ce ? text.substring(spe, ce) : '';
          addToken(_DialogueToken(colonStr));
        }
        addToken(_DialogueToken(content));
        i = cte;
        cPointer++;
        continue;
      }
      if (dPointer < matchedDialogue.length &&
          i == matchedDialogue[dPointer].start) {
        flushNarration();
        int dStart = matchedDialogue[dPointer].start;
        int dEnd = matchedDialogue[dPointer].end;
        if (dStart < 0) dStart = 0;
        if (dEnd < dStart) dEnd = dStart;
        if (dEnd > textLen) dEnd = textLen;
        addToken(_DialogueToken(text.substring(dStart, dEnd)));
        i = dEnd;
        dPointer++;
      } else {
        if (i < textLen) {
          currentNarration.writeCharCode(text.codeUnitAt(i));
          i++;
        } else {
          break;
        }
      }
    }

    flushNarration();
    return tokens;
  }

  /// 在 [text] 的 [lineStart, lineEnd) 区间内查找对话冒号（说话人：台词）的位置。
  /// 找不到返回 -1。
  static int _findDialogueColon(String text, int lineStart, int lineEnd) {
    if (lineStart < 0) lineStart = 0;
    if (lineEnd > text.length) lineEnd = text.length;
    if (lineStart >= lineEnd) return -1;
    for (int i = lineStart; i < lineEnd; i++) {
      final ch = text[i];
      if (ch != '：' && ch != ':') continue;
      // 时钟时间（数字:数字，如 9:00 / 09:00）不算对话
      if (_isClockColon(text, i)) continue;

      // ===== BUGFIX-1 强信号：冒号后紧跟引号 → 必然是对话冒号 =====
      // 不管冒号前是什么叙述修饰（"露出玩味的笑容：""语气一冷："），
      // 只要冒号后 0~1 个字符内出现引号，就认定这是台词的起点，
      // 走宽松 speaker 提取规则（允许中间夹带「的/地」等情绪修饰）。
      final afterColon = (i + 1 <= lineEnd)
          ? text.substring(i + 1, lineEnd).trimLeft()
          : '';
      final quoteFollow = RegExp(r'^[\s]*["「『“‘]').hasMatch(afterColon);

      final speakerStartIdx = _speakerStart(text, lineStart, i);
      final safeSpeakerStart =
          (speakerStartIdx < lineStart || speakerStartIdx > i)
          ? lineStart
          : speakerStartIdx;
      if (safeSpeakerStart > i) continue;
      final raw = text.substring(safeSpeakerStart, i).trim();
      final nameEndInRaw = quoteFollow
          ? _validSpeakerNameEndRelaxed(raw) // 后跟引号→宽松规则
          : _validSpeakerNameEnd(raw); // 默认严格规则
      if (nameEndInRaw >= 0 && nameEndInRaw <= raw.length) return i;
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
      if (c == '。' ||
          c == '！' ||
          c == '？' ||
          c == '；' ||
          c == '…' ||
          c == '.' ||
          c == '!' ||
          c == '?' ||
          c == ';' ||
          c == '~') {
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

  /// 叙述动词（长词在前，保证贪婪匹配）：「赫敏说：」中「说」归叙述、不进说话人。
  /// 2026-08-26 扩展：AI 极爱写「露出玩味笑容：」「挑眉：」「语气一冷：」这类
  /// "情绪/表情修饰 + 冒号 + 引号台词"的模式，之前会被整体当成叙述短语漏掉，
  /// 现在把高频情绪短语也纳入"尾部叙述修饰"，剥掉后再找纯角色名。
  static const List<String> _speechVerbs = [
    '轻声说道',
    '低声说道',
    '大声喊道',
    '笑着说道',
    '淡淡地说',
    '玩味地笑',
    '玩味一笑',
    '微微一笑',
    '淡淡一笑',
    '冷笑一声',
    '皱起眉头',
    '挑了挑眉',
    '挑挑眉梢',
    '眉头一挑',
    '眉头微皱',
    '语气一冷',
    '语气平淡',
    '语气不善',
    '压低声音',
    '放缓语气',
    '带着笑意',
    '收敛笑容',
    '忽然开口',
    '率先打破沉默',
    '说道',
    '问道',
    '喊道',
    '笑道',
    '答道',
    '叫道',
    '叹道',
    '低语',
    '回答',
    '说',
    '道',
    '问',
    '喊',
    '答',
    '叫',
    '笑',
    '叹',
  ];

  /// 情绪/神态/动作修饰短语（剥掉后再找纯角色名，2~8字常见）
  static const List<String> _moodModifiers = [
    '玩味的笑容',
    '玩味的笑意',
    '一丝玩味的笑容',
    '一丝玩味的笑意',
    '淡淡的笑容',
    '浅浅的笑意',
    '一抹微笑',
    '一脸冷笑',
    '戏谑的表情',
    '挑了挑眉',
    '挑挑眉梢',
    '眉头一挑',
    '眉头微皱',
    '皱起眉头',
    '语气一冷',
    '语气平淡',
    '语气不善',
    '压着声音',
    '压低声音',
    '带着笑意',
    '收敛笑容',
    '轻轻摇头',
    '摇了摇头',
    '点了点头',
    '轻声',
    '低声',
    '大声',
    '冷冷',
    '淡淡',
    '笑眯眯',
    '笑吟吟',
    '苦笑',
    '（冷笑）',
    '（挑眉）',
    '（皱眉）',
    '（摇头）',
    '（叹气）',
    '（试探）',
    '（审视）',
    '（微笑）',
    '（警惕）',
    '（平静）',
    '（傲慢）',
    '（玩味）',
    '（严肃）',
    '（温柔）',
    '（好奇）',
  ];

  /// 按长度降序的静态排序表（_validSpeakerNameEnd 的热路径用，避免每行重建）。
  /// 复刻 `List.from(_moodModifiers)..sort(...)` 的结果；排序只依赖长度，
  /// 两张表都是 const，长度顺序恒定，静态缓存是安全的。
  static final List<String> _sortedMoodByLength = List<String>.of(
    _moodModifiers,
  )..sort((a, b) => b.length.compareTo(a.length));
  static final List<String> _sortedSpeechByLength = List<String>.of(
    _speechVerbs,
  )..sort((a, b) => b.length.compareTo(a.length));

  /// 判断 [raw]（冒号前的整段文本）是否为合理说话人。
  /// 返回「纯名字」在 raw 中的结束位置（用于把尾部叙述动词切给叙述色）；不合法返回 -1。
  ///
  /// 关键返回规则：
  ///  - 返回 raw.length → 整段 raw（直到冒号前）都是说话人色，冒号按对话蓝（例如"赫敏：""德拉科（冷笑）："）
  ///  - 返回 < raw.length → 0..返回值=说话人橙，返回值..raw.length+1（冒号）=叙述灰 + 冒号叙述灰（例如"罗恩说：""莉娜问道："）
  static int _validSpeakerNameEnd(String raw) {
    if (raw.isEmpty || raw.length > 40) return -1;
    // 结构标记 / 时间戳方括号
    if (raw.contains('【') ||
        raw.contains('】') ||
        raw.contains('[') ||
        raw.contains(']')) {
      return -1;
    }
    // 含引号（如 他说："赫敏：你好"）：说话人名字不会带引号
    if (RegExp(r'["「」『』“”‘’"]').hasMatch(raw)) return -1;
    // emoji 前缀（时间戳 📅 等）
    if (_startsWithEmoji(raw)) return -1;

    // 第一步：去掉「（情绪）」「(动作)」「好感+1」，提取候选前缀 name（始终是 raw 的前缀，从 0 开始）
    final hasModifier = RegExp(r'[（(]').hasMatch(raw) || raw.contains('好感');
    String name = raw;
    int bracketIdx = name.indexOf(RegExp(r'[（(]'));
    if (bracketIdx < 0) bracketIdx = name.indexOf('好感');
    if (bracketIdx < 0) bracketIdx = name.length;
    name = name.substring(0, bracketIdx).trim();

    // 第二步："name 之后到 raw 末尾"的部分（情绪修饰/括号神态等），有没有任何真正的叙述动词？
    // 叙述动词 _speechVerbs 命中 → 要切成叙述灰；否则（只是括号/微笑/玩味的笑容这类神态）→ 整段按说话人橙
    final afterName = raw.substring(bracketIdx); // 例如"（冷笑）"、"说道"、空
    bool hasTrueSpeechVerb = false;
    final afterNameTrim = afterName.trim();
    // 快速通道：如果 afterNameTrim 只是一堆（神态）/ (动作) 括号对，中间没有叙述动词的文字
    // → 说明这是"（冷笑）（审视）"纯神态，绝无可能是"说/道/问道"等叙述动词！
    //    挡住 _speechVerbs 中"笑"单字 contains 命中"冷笑"的 BUG。
    final onlyBrackets = RegExp(
      r'^(\s*[（(][^（）()]{1,10}[）)]\s*)+$',
    ).hasMatch(afterNameTrim);
    if (!onlyBrackets && afterNameTrim.isNotEmpty) {
      for (final v in _speechVerbs) {
        if (v.length == 1) {
          // 单字词（说/道/问/喊/答/叫/笑/叹）：不能直接 contains，因为 contains 会把"冷笑"
          // 里的"笑"当成独立动词"笑"命中；必须左右都不是中文字（是括号/标点/边界）
          final around = _singleCharVerbPatterns[v];
          if (around != null && around.hasMatch(afterNameTrim)) {
            hasTrueSpeechVerb = true;
            break;
          }
        } else {
          // 多字词（说道/问道/冷笑一声）→ 直接 contains（足够精确）
          if (afterNameTrim.contains(v)) {
            hasTrueSpeechVerb = true;
            break;
          }
        }
      }
    }

    // 第三步：逐步剥掉 情绪短语 / 叙述动词 / 情绪 / 叙述 ... 最多6轮，得最终 base（仍是前缀）
    String base = name;
    // 静态排序表（此前每行每次调用都 List.from+sort 重建两份，O(行×词) 的热点）
    final sortedMood = _sortedMoodByLength;
    final sortedSpeech = _sortedSpeechByLength;
    bool changed = true;
    int safety = 0;
    while (changed && safety++ < 6) {
      changed = false;
      for (final m in sortedMood) {
        if (base.endsWith(m)) {
          base = base.substring(0, base.length - m.length).trimRight();
          changed = true;
          break;
        }
      }
      if (changed) continue;
      for (final v in sortedSpeech) {
        if (base.endsWith(v)) {
          base = base.substring(0, base.length - v.length).trimRight();
          changed = true;
          hasTrueSpeechVerb = true; // 剥到了叙述动词，标记要切成叙述灰
          break;
        }
      }
    }
    base = base.trim();
    if (base.isEmpty) return -1;

    // ========== 分支 1：base 是已知角色 ==========
    if (_characterNames.contains(base)) {
      // 判断：这段到冒号前（raw 全段）是否要"整段橙"？
      // 条件：既没有叙述动词（剥除循环没剥到 _speechVerbs 的词，afterName 里也没有）
      //       → 也即：raw 从 base 结束之后的内容只是"括号神态/情绪短语/空白"
      if (!hasTrueSpeechVerb) {
        // 整段按说话人橙 → 返回 raw.length。这样 seg.nameEnd == seg.speakerEnd → 冒号蓝色。
        // 测试 2 模式："德拉科（冷笑）：何必自讨苦吃。" → speaker = "德拉科（冷笑）"橙色，冒号蓝
        // 测试 1 模式："赫敏：我们去图书馆吧。" → speaker = "赫敏"橙色，冒号蓝
        return raw.length;
      }
      // 有叙述动词（"罗恩说：""赫敏淡淡的说道："）→ 角色名结束位置 = base 的前缀长度（因为 base 是 raw 前缀）
      // 测试 3 模式："罗恩说："等等我！"" → nameEnd=2 < speakerEnd=5（冒号位置5），所以"说："叙述灰
      // 但 base 是从 name 里剥出来的，name 是 raw 的前缀 (raw[0..bracketIdx))，所以 base 是 name 的前缀，也就是 raw 的前缀
      // 所以 base 相对于 raw 的前缀长度就是 base.length + ？不对：name = raw[0..bracketIdx].trim()，
      // 但 name 本身是 raw 的前缀，没有被改开头，trim() 只去尾部。那 base 是 name 剥后缀后的，那 base 的长度就是 raw 的前缀长度。
      // 比如 raw = "罗恩说"，bracketIdx=3，name = "罗恩说"，base = "罗恩"，base.length=2 = raw前缀2 → 正确。
      // 比如 raw = "赫敏淡淡的说道"，bracketIdx=6，name = "赫敏淡淡的说道"，base = 剥 淡淡的说道 → "赫敏"，base.length=2
      //   但 raw[0..2] = "赫敏" → 正确。
      return base.length;
    }

    // ========== 分支 2：带 hasModifier 但 base 不认识 → 严格拒绝（不像人名就跳过，避免误判叙述词）==========
    if (hasModifier) return -1;

    // ========== 分支 3：未知名字（AI 生成随机 NPC，2~8字，不含虚词/数字/标点）==========
    if (_looksLikeNarrationPhrase(base)) return -1;
    if (base.length < 2 || base.length > 8) return -1;
    if (RegExp(r'[\d]').hasMatch(base)) return -1;
    if (RegExp(r'[，。！？、；：]').hasMatch(base)) return -1;
    // 同已知角色：有没有叙述动词？有 → 只染 base.length（莉娜），后面"问道："叙述灰（测试4：莉娜问道：今晚要一起自习吗？）
    //            没 → 整段 raw.length 染橙（莉娜：今晚要一起自习吗？→ 模式）
    return hasTrueSpeechVerb ? base.length : raw.length;
  }

  /// 宽松版说话人判定（冒号后紧跟引号时使用，强对话信号）。
  /// 即使整段 speaker 含"德拉科显然对你冷淡，他玩味的笑容"这类大量叙述，
  /// 只要最后面能找到一个"已知角色名"或"2-4 字像人名的字符串"，
  /// 就把它作为说话人（其余内容归叙述色），最大限度不漏对话上色。
  static int _validSpeakerNameEndRelaxed(String raw) {
    if (raw.isEmpty || raw.length > 80) return -1;
    if (raw.contains('【') || raw.contains('】')) return -1;
    if (_startsWithEmoji(raw)) return -1;

    // 预排序已知角色（长词在前，先找完整全名）——直接复用类级预排序的那份，
    // 这个函数按行调用，原地重排等于每行一次全量排序。
    final sortedNames = _characterNamesByLengthDesc;

    // 在 raw 的"后半段"（最后 20 个字符或 1/3 长度，取较大者）找最后一个角色命中
    final lookBack = raw.length > 20 ? 20 : (raw.length ~/ 3).clamp(8, 20);
    final searchZoneStart = raw.length - lookBack < 0
        ? 0
        : raw.length - lookBack;
    final rawLen = raw.length;

    String? foundName;
    int foundNameEnd = -1;
    for (final name in sortedNames) {
      if (name.isEmpty) continue;
      final idx = raw.lastIndexOf(name);
      if (idx < 0) continue;
      final end = idx + name.length;
      if (end > rawLen) continue; // 超界安全
      if ((idx >= searchZoneStart || raw.endsWith(name)) &&
          end > foundNameEnd) {
        foundName = name;
        foundNameEnd = end;
      }
    }
    if (foundName != null && foundNameEnd > 0 && foundNameEnd <= rawLen) {
      return foundNameEnd; // 命中已知角色，直接使用
    }

    // Fallback：在最后 12 个字里找"2-4 个汉字、像人名"的片段（标点/虚词结尾不算）
    if (searchZoneStart >= rawLen) return -1;
    final tail = raw.substring(searchZoneStart, rawLen);
    final nameLike = RegExp(
      r'([\u4e00-\u9fa5]{2,4})(?=[，、。！？\s]*$)',
    ).firstMatch(tail);
    if (nameLike != null) {
      final candidate = nameLike.group(1);
      if (candidate != null && !_looksLikeNarrationPhrase(candidate)) {
        final result = searchZoneStart + nameLike.end;
        if (result <= rawLen) return result;
      }
    }
    return -1;
  }

  /// 判断短语是否更像叙述而非人名（含虚词/时间词/地点/章节标记/状态标签）。
  static bool _looksLikeNarrationPhrase(String s) {
    if (s.isEmpty) return true;
    // 常见叙述虚词：人名几乎不会包含这些字
    // 注意：代词（你我他她它）、常见叙述动词（抬低扫盯闻感）、
    // 指示代词（这那哪）都绝不可能是说话人名字的一部分。
    if (RegExp(
      r'[的在地是着了很都也又便就已经仍和与或者把被让想看见听走进出来去边样个你我他她它抬低扫盯闻感这那哪]',
    ).hasMatch(s)) {
      return true;
    }
    // 时间词开头（清晨的霍格沃茨：… / 下午三点：…）
    const timePrefixes = [
      '清晨',
      '早晨',
      '早上',
      '上午',
      '中午',
      '午后',
      '下午',
      '傍晚',
      '晚上',
      '夜晚',
      '深夜',
      '午夜',
      '凌晨',
      '黄昏',
      '夜里',
      '当夜',
      '今天',
      '明天',
      '昨天',
      '后天',
      '前天',
      '次日',
      '翌日',
      '此刻',
      '此时',
      '这时',
      '那时',
      '瞬间',
      '突然',
      '忽然',
    ];
    for (final t in timePrefixes) {
      if (s.startsWith(t)) return true;
    }
    // 含已知地点名（场景描述短语，如 清晨的霍格沃茨）
    for (final loc in _locations) {
      if (s.contains(loc)) return true;
    }
    // 章节序号
    if (s.startsWith('第') ||
        s.contains('章') ||
        s.contains('卷') ||
        s.contains('回')) {
      return true;
    }
    // 状态/结构标签
    const labels = [
      '时间',
      '日期',
      '星期',
      '月份',
      '地点',
      '位置',
      '状态',
      '身份',
      '模式',
      '目标',
      '学年',
      '学期',
      '年级',
      '天气',
      '场景',
      '当前',
      '剩余',
      '选项',
      '行动',
      '提示',
      '备注',
      '说明',
      '编号',
      '总结',
      '建议',
      '效果',
      '结果',
      '影响',
      '关系',
      '评价',
      '反馈',
      '概括',
    ];
    for (final l in labels) {
      if (s.contains(l)) return true;
    }
    return false;
  }

  static bool _startsWithEmoji(String s) {
    if (s.isEmpty) return false;
    final first = s.runes.first;
    return (first >= 0x1F300 && first <= 0x1FAFF) ||
        (first >= 0x2600 && first <= 0x27BF) ||
        (first >= 0x2B00 && first <= 0x2BFF);
  }

  /// 剥离 AI/系统在叙事开头注入的内部 meta 标记。
  /// 这些标记是程序生成的"衔接说明/调度标记"，不是剧情正文的一部分，
  /// 绝不能出现在玩家看到的 UI 里，否则会让玩家困惑、造成时间戳识别重复。
  ///
  /// 清理示例：
  ///   "(承接：就在家中-卧室、你正准备好了接受它的指引的那一刻) —紧接着，【时间戳】..."
  ///   → 清理为 "【时间戳】..."
  ///   "承接上回合剧情：他刚走出门 ——【时间戳】📅 ..."
  ///   → 清理为 "【时间戳】📅 ..."
  static String stripInternalMetaMarkers(String text) {
    if (text.isEmpty) return text;
    var s = text;

    // 1) 清理括号包裹的「承接：XXX」（中文括号/英文括号都要处理）
    //    贪婪匹配到最近的 【时间戳】或段落开头，避免误伤正文括号。
    s = s.replaceAllMapped(
      RegExp(r'^\s*[(（][^）)]*承接[^）)]*[）)]\s*[—\-]*\s*'),
      (m) => '',
    );

    // 2) 清理行首直接写的「承接：... ——」「承接上回合：... 紧接着」
    s = s.replaceAllMapped(
      RegExp(r'^\s*承接[^：:]*[:：][^\n—\-]{0,200}?([—\-]{1,3}|紧接着，?|然后，?)\s*'),
      (m) => '',
    );

    // 3) 清理「——紧接着，【时间戳】」这种把「紧接着」放在【时间戳】前面的冗余连接词
    s = s.replaceAllMapped(
      RegExp(r'([—\-]{1,3}|紧接着，?|然后，?)\s*(?=【时间戳】|📅)'),
      (m) => '',
    );

    // 4) 清理 SceneGraph/Anchor 这类 debug 文本行（整行）
    s = s.replaceAllMapped(
      RegExp(
        r'^\s*(🧭)?\s*SceneGraph[:：].*$\n?',
        caseSensitive: false,
        multiLine: true,
      ),
      (m) => '',
    );

    return s.trimLeft();
  }

  // ==================== 输出侧正文兜底清洗（v3.8） ====================
  //
  // 输入侧已有 PromptSanitizer（注入防御/限长）；这里是输出侧兜底——
  // AI 生成内容偶尔带 Markdown 残留或整段复读，玩家不该看到。

  /// 轻量 Markdown 残留清理（正文侧兜底）。
  ///
  /// 保守处理，避免误伤正文标点：
  ///  - **加粗** / __斜体__ → 去掉成对标记
  ///  - 中文内容被单星号包裹（*斜体*）→ 去掉星号（数字算式不受影响）
  ///  - 行首 ### 标题符、- / * / 1. 列表符 → 去符号留文本
  static String stripMarkdownArtifacts(String text) {
    if (text.isEmpty) return text;
    var s = text;
    // 注意：Dart 的 replaceAll 对 RegExp 的替换串按字面量处理（不支持 $1），
    // 反向引用必须用 replaceAllMapped
    s = s.replaceAllMapped(RegExp(r'\*\*([^*\n]+)\*\*'), (m) => m.group(1)!);
    s = s.replaceAllMapped(RegExp(r'__([^_\n]+)__'), (m) => m.group(1)!);
    // 单星号包裹：仅当内容是中文（避免误伤 3*4=12 这类算式）
    s = s.replaceAllMapped(
      RegExp(r'\*([\u4e00-\u9fa5][^*\n]{0,40})\*'),
      (m) => m.group(1)!,
    );
    // 行首标题符（Dart RegExp 不支持 (?m) 内联标志，用 multiLine 参数）
    s = s.replaceAll(RegExp(r'^\s*#+\s*', multiLine: true), '');
    // 行首列表符（- * • 数字. 数字、）→ 去符号留文本
    s = s.replaceAll(RegExp(r'^\s*[-*•]\s+(?=\S)', multiLine: true), '');
    s = s.replaceAll(RegExp(r'^\s*\d{1,2}[.、]\s+(?=\S)', multiLine: true), '');
    return s.trim();
  }

  /// 相邻重复段落去重：AI 输出偶尔整段复读（复制粘贴式/首尾呼应式）。
  /// 只处理「与上一条完全相同的段落」，保留第一条。
  static String dedupeRepeatedParagraphs(String text) {
    if (text.isEmpty) return text;
    final paras = text.split(RegExp(r'\n{2,}'));
    if (paras.length < 2) return text;
    final out = <String>[];
    String? prev;
    for (final p in paras) {
      final t = p.trim();
      if (t == prev) continue;
      out.add(p);
      prev = t;
    }
    return out.join('\n\n');
  }

  /// 自动段落排版：将长文本按句号/问号/感叹号 + 长度阈值自动分段
  static String autoParagraph(String text) {
    if (text.isEmpty) return '';

    // 先剥离内部 meta 标记（承接/SceneGraph 等内部衔接说明）—— 保证 UI 永远不渲染这些调度信息
    text = stripInternalMetaMarkers(text);

    final buffer = StringBuffer();
    int sentenceCount = 0;
    int paragraphLength = 0;

    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      buffer.write(ch);
      paragraphLength++;

      // 检测段落结束：句末标点 + 长度达标
      if (ch == '。' ||
          ch == '！' ||
          ch == '？' ||
          ch == '.' ||
          ch == '!' ||
          ch == '?') {
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
    final affectionPattern = RegExp(r'【好感(?:度)?变化?】[\s\S]*?(?=【|$)');
    final reputationPattern = RegExp(r'【声望变化?】[\s\S]*?(?=【|$)');

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

    return {'narrative': narrative, 'affectionSections': affectionSections};
  }

  // ==================== 小说式段落排版支持 ====================

  /// 把叙述段按空行拆成段落列表。
  ///
  /// 单换行不拆——那是段内折行（或 AI 写的单行短段，
  /// 与下一段没有空行隔开时不该自作主张拆成两段）。
  static List<String> splitParagraphs(String text) {
    return text
        .split(RegExp(r'\n{2,}'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// 按段落解析：与 [parse] 相同的高亮规则，
  /// 但段首加两个全角字符的首行缩进。
  ///
  /// 中文长篇阅读的眼睛锚点：齐头排的 600 字是一堵墙，
  /// 尤其与对话气泡混排时，没有缩进的叙述段和气泡会糊成一片。
  /// 缩进用全角空格而不是缩进 widget——RichText 内部完成，
  /// 不引入额外的布局层，也跟随 ScaledRichText 的字号缩放。
  static List<TextSpan> parseParagraph(String paragraph, {bool indent = true}) {
    final spans = parse(paragraph);
    if (!indent || spans.isEmpty) return spans;
    return [TextSpan(text: '　　', style: _narrationStyle), ...spans];
  }

  // ==================== 小说式段落分类：段落级样式与分类逻辑 ====================

  // 内心独白：比正文淡一档的紫，斜体制造"声音在脑内"的层次
  static const Color _innerVoiceColor = Color(0xFFB8A6E3);
  static TextStyle _innerVoiceStyle = const TextStyle(
    fontSize: 15,
    height: _bodyLineHeight,
    color: _innerVoiceColor,
    fontStyle: FontStyle.italic,
  );

  // 时间戳：与金色主题同族的深金，胶囊内展示
  static const Color _timestampColor = Color(0xFFE3B341);
  static TextStyle _timestampStyle = const TextStyle(
    fontSize: 12.5,
    height: 1.4,
    color: _timestampColor,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );

  /// 整段括号包裹（（内心独白））的判定。
  static final RegExp _parenWrappedRe = RegExp(r'^\s*[（(][^（(]*[）)]\s*$');

  /// 内心独白关键词：出现即把整段当作内心活动。
  static final RegExp _innerVoiceHintRe = RegExp(
    r'心想|心里想|暗自想|暗自|默默|默念|暗暗|心里说|在心底',
  );

  /// 时间戳/标记段：以这些标记开头。
  static final RegExp _timestampStartRe = RegExp(r'^\s*(【时间戳】|📅|⏰|⏳|🕐|🗓)');

  /// 按空行拆段 + 逐段分类，供段落式 UI 渲染。
  ///
  /// 分类口径：
  ///  - 时间戳段：以【时间戳】/📅/⏳ 等标记开头；
  ///  - 对话段：段内含成对引号台词（"「『 等），或行首是「说话人：」台词；
  ///  - 内心独白：整段括号包裹，或含心想/暗自/默默等提示词；
  ///  - 其余为普通叙述。
  static List<StoryParagraph> classifyParagraphs(String text) {
    if (text.isEmpty) return const [];
    var cleaned = stripInternalMetaMarkers(text);
    cleaned = _stripOutlineLabels(cleaned);
    cleaned = _stripChoiceBlocks(cleaned);
    cleaned = _promoteAffectionLines(cleaned);

    return splitParagraphs(cleaned).map((para) {
      return StoryParagraph(_classifyParagraph(para), para);
    }).toList();
  }

  static ParagraphKind _classifyParagraph(String para) {
    // 1) 时间戳/标记段：前缀后只跟着短时间文本才算；若后面还拖着正文
    //    （AI 用单换行把时间戳和正文连在一起），降级为叙述段，避免
    //    整段被金色胶囊吞掉。
    if (_timestampStartRe.hasMatch(para)) {
      final rest = stripTimestampPrefix(para);
      if (rest.length <= 30 && !rest.contains('。') && !rest.contains('\n')) {
        return ParagraphKind.timestamp;
      }
      return ParagraphKind.narration;
    }
    // 2) 整段括号包裹 → 内心独白
    if (_parenWrappedRe.hasMatch(para)) {
      return ParagraphKind.innerVoice;
    }
    // 3) 内心独白关键词
    if (_innerVoiceHintRe.hasMatch(para)) {
      return ParagraphKind.innerVoice;
    }
    // 4) 含引号台词 → 对话段
    if (para.contains('"') ||
        para.contains('「') ||
        para.contains('『') ||
        para.contains('”') ||
        para.contains('』') ||
        para.contains('“')) {
      return ParagraphKind.dialogue;
    }
    // 5) 行首「说话人：」+ 台词（复用冒号检测口径）
    for (final line in para.split('\n')) {
      final colon = _findDialogueColon(line, 0, line.length);
      if (colon > 0) {
        final rest = line.substring(colon + 1).trimLeft();
        if (rest.startsWith('"') ||
            rest.startsWith('「') ||
            rest.startsWith('“') ||
            rest.startsWith('『')) {
          return ParagraphKind.dialogue;
        }
      }
    }
    // 6) 其余
    return ParagraphKind.narration;
  }

  /// 去掉段落前的时间戳标记词（【时间戳】/📅/⏳…），留下时间正文。
  static String stripTimestampPrefix(String para) {
    return para.replaceFirst(RegExp(r'^\s*(【时间戳】|📅|⏰|⏳|🕐|🗓)\s*'), '').trim();
  }

  /// 按段落类型渲染：叙述带首行缩进、对话顶格（内部高亮已染说话人/台词）、
  /// 内心独白统一浅紫斜体、时间戳金色小字。
  static List<TextSpan> parseParagraphStyled(
    StoryParagraph p, {
    bool indent = true,
  }) {
    switch (p.kind) {
      case ParagraphKind.narration:
        return parseParagraph(p.text, indent: indent);
      case ParagraphKind.dialogue:
        // parse 内部已把「说话人：」染橙、台词染蓝，段落级不再叠色
        return parse(p.text);
      case ParagraphKind.innerVoice:
        // 内心独白整段统一紫斜体：内部的词级颜色（人名/地点）让位，
        // 保证"这一段是在心里想"的第一眼可读性
        return [
          for (final s in parse(p.text))
            TextSpan(text: s.text, style: _innerVoiceStyle),
        ];
      case ParagraphKind.timestamp:
        return [
          TextSpan(text: stripTimestampPrefix(p.text), style: _timestampStyle),
        ];
    }
  }

  /// 解析好感变化行（「姓名：+5（说明）」）：说话人/人名照常高亮，
  /// 数值按正负着色——正绿（#7EE787）负红（#FF7B72），一眼看清谁升温谁降温。
  static List<TextSpan> parseAffectionLine(String line) {
    final out = <TextSpan>[];
    final re = RegExp(r'([+-]\d+)');
    for (final s in parse(line)) {
      final text = s.text;
      if (text == null) {
        out.add(s);
        continue;
      }
      var last = 0;
      for (final m in re.allMatches(text)) {
        if (m.start > last) {
          out.add(
            TextSpan(text: text.substring(last, m.start), style: s.style),
          );
        }
        final v = int.tryParse(m.group(1)!);
        out.add(
          TextSpan(
            text: m.group(1),
            style: TextStyle(
              color: (v ?? 0) >= 0
                  ? const Color(0xFF7EE787)
                  : const Color(0xFFFF7B72),
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        last = m.end;
      }
      if (last < text.length) {
        out.add(TextSpan(text: text.substring(last), style: s.style));
      }
    }
    return out;
  }

  // ==================== 对话气泡支持：叙事分段 ====================

  /// 把剧情正文切分为「叙述段 / 对话行」混合序列，供气泡式 UI 渲染。
  /// 对话行识别复用 [parse] 的冒号说话人检测（_findDialogueColon +
  /// _validSpeakerNameEnd/Relaxed），与正文高亮保持同一套判定口径。
  static List<NarrativeSegment> splitIntoSegments(String text) {
    if (text.isEmpty) return const [];
    var cleaned = _stripOutlineLabels(text);
    cleaned = _stripChoiceBlocks(cleaned);
    cleaned = _preStripChoices(cleaned);

    final segments = <NarrativeSegment>[];
    final narrationBuffer = StringBuffer();

    void flushNarration() {
      final t = narrationBuffer.toString().trim();
      if (t.isNotEmpty) segments.add(NarrativeSegment.narration(t));
      narrationBuffer.clear();
    }

    for (final line in cleaned.split('\n')) {
      final dialogue = _extractLineDialogue(line);
      if (dialogue != null) {
        flushNarration();
        segments.add(
          NarrativeSegment.dialogue(
            speaker: dialogue.speaker,
            mood: dialogue.mood,
            text: dialogue.content,
          ),
        );
      } else {
        narrationBuffer.writeln(line);
      }
    }
    flushNarration();
    return segments;
  }

  /// 单行对话提取：命中「说话人：台词」返回 (干净名字, 神态, 台词内容)，否则 null。
  static ({String speaker, String mood, String content})? _extractLineDialogue(
    String line,
  ) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;
    // 结构化标签行（【好感度变化】等）不当对话
    if (trimmed.startsWith('【')) return null;

    final k = _findDialogueColon(line, 0, line.length);
    if (k < 0) return null;

    final afterColon = (k + 1 <= line.length)
        ? line.substring(k + 1).trim()
        : '';
    if (afterColon.isEmpty) return null;
    // 好感度裸行（莉莉：+5）不是对话
    if (RegExp(r'^[+-]\d').hasMatch(afterColon)) return null;

    final quoteFollow = RegExp(r'^[\s]*["「『“‘]').hasMatch(afterColon);
    final speakerStartIdx = _speakerStart(line, 0, k);
    final safeStart = (speakerStartIdx < 0 || speakerStartIdx > k)
        ? 0
        : speakerStartIdx;
    final raw = line.substring(safeStart, k).trim();
    final nameEnd = quoteFollow
        ? _validSpeakerNameEndRelaxed(raw)
        : _validSpeakerNameEnd(raw);
    if (nameEnd < 0) return null;
    final safeNameEnd = safeStart + nameEnd;
    if (safeNameEnd < safeStart || safeNameEnd > k) return null;

    final fullSpeaker = line.substring(safeStart, safeNameEnd).trim();
    if (fullSpeaker.isEmpty) return null;

    // 拆出尾部括号神态：德拉科（冷笑） → 德拉科 + （冷笑）
    final moodMatch = RegExp(r'([（(][^（）()]*[）)])\s*$').firstMatch(fullSpeaker);
    final mood = moodMatch?.group(1) ?? '';
    final speaker =
        (moodMatch != null
                ? fullSpeaker.substring(0, moodMatch.start)
                : fullSpeaker)
            .trim();
    if (speaker.isEmpty) return null;

    // 未知说话人（不在已知角色表中）且 3 字以上 → 必须冒号后跟引号才算对话
    // 防止「环顾四周：」「清晨的霍格沃茨：」等叙述被误判为对话
    if (!_characterNames.contains(speaker) &&
        speaker.length > 3 &&
        !quoteFollow) {
      return null;
    }

    final content = _stripOuterQuotes(afterColon);
    if (content.isEmpty) return null;
    return (speaker: speaker, mood: mood, content: content);
  }

  /// 剥掉台词最外层的成对引号（「」/“”/『』/""/''）
  static String _stripOuterQuotes(String s) {
    var t = s.trim();
    const pairs = [('「', '」'), ('“', '”'), ('『', '』'), ('"', '"'), ('‘', '’')];
    for (final (open, close) in pairs) {
      if (t.length >= open.length + close.length &&
          t.startsWith(open) &&
          t.endsWith(close)) {
        t = t.substring(open.length, t.length - close.length).trim();
      }
    }
    return t;
  }

  static List<_Token> _splitNarration(String text) {
    final tokens = <_Token>[];
    final replacements = <_Replacement>[];
    final coveredRanges = <_Range>{};

    void addReplacement(int start, String word, _TokenType type) {
      final range = _Range(start, start + word.length, word);
      final overlap = coveredRanges.any(
        (r) => range.start < r.end && range.end > r.start,
      );
      if (!overlap) {
        coveredRanges.add(range);
        replacements.add(_Replacement(start, word, type));
      }
    }

    // 三类实体统一用「长词在前」的预排序列表：
    // 否则「霍格莫德」会先于「霍格莫德车站」命中并占据区间，
    // 导致长地名/长物品名（古灵阁巫师银行、霍格沃茨特快列车等）
    // 永远无法整体高亮。
    for (final name in _characterNamesByLengthDesc) {
      int idx = 0;
      while (true) {
        idx = text.indexOf(name, idx);
        if (idx == -1) break;
        addReplacement(idx, name, _TokenType.character);
        idx += name.length;
      }
    }

    for (final loc in _locationsByLengthDesc) {
      int idx = 0;
      while (true) {
        idx = text.indexOf(loc, idx);
        if (idx == -1) break;
        addReplacement(idx, loc, _TokenType.location);
        idx += loc.length;
      }
    }

    for (final item in _itemsByLengthDesc) {
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

  // 重叠检查会把候选区间两两比较（O(R²)），靠 Set 去重压缩规模。
  // 没有 == / hashCode 时 Set 退化成引用比较，去重形同虚设：
  // 重叠区间照样重复进表，后面的剔除逻辑拿到的还是全量——
  // 而"剔除重叠"正是这里建 Set 的唯一目的。
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Range && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '_Range($start, $end, $text)';
}

class _ColonSegment {
  final int speakerStart;
  final int nameEnd; // 说话人纯名字结束位置（其后到冒号之间是叙述动词）
  final int speakerEnd;
  final int colonEnd;
  final int contentEnd;
  _ColonSegment({
    required this.speakerStart,
    required this.nameEnd,
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

/// 叙事分段：叙述段（普通正文）或对话行（说话人+台词）。
/// 供气泡式剧情渲染使用。
class NarrativeSegment {
  final bool isDialogue;

  /// 对话说话人（isDialogue=true 时有效，已剥离神态括号）
  final String speaker;

  /// 说话人神态（如「（冷笑）」），可能为空
  final String mood;

  /// 正文内容（叙述段全文 / 台词内容）
  final String text;

  const NarrativeSegment.narration(this.text)
    : isDialogue = false,
      speaker = '',
      mood = '';

  const NarrativeSegment.dialogue({
    required this.speaker,
    required this.text,
    this.mood = '',
  }) : isDialogue = true;
}
