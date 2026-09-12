/// 用户输入安全处理：在用户自由文本进入 Prompt 之前做净化，
/// 降低 Prompt 注入与超长输入破坏叙事结构的风险。
class PromptSanitizer {
  PromptSanitizer._();

  /// 用户自由行动 / 聊天输入的最大长度
  static const int maxInputLength = 500;

  // 疑似试图覆盖系统指令的短语（宽松匹配，仅做降级转义，不粗暴拒绝）
  static const List<String> _injectionMarkers = [
    '忽略以上',
    '忽略之前',
    'ignore previous',
    'ignore above',
    '你现在是',
    '新的指令',
    '系统提示词',
    'system prompt',
    '作为AI',
    'as an ai',
  ];

  /// 控制字符（保留换行、制表符）。
  static final RegExp _controlCharsRe = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');

  /// 行内连续空白 / 连续空行。
  static final RegExp _inlineWsRe = RegExp(r'[ \t]+');
  static final RegExp _blankLineRunRe = RegExp(r'\n{3,}');

  /// 预编译的注入标记正则。原 sanizite() 里是「先 contains 再编译」，
  /// 命中注入时每次都要现编译；这里一次性建好。
  static final Map<String, RegExp> _markerPatterns = <String, RegExp>{
    for (final m in _injectionMarkers)
      m: RegExp(RegExp.escape(m), caseSensitive: false),
  };

  /// 净化用户输入：去控制字符、折叠空白、限长、转义注入标记。
  static String sanitize(String raw) {
    var s = raw;

    // 1) 去除控制字符（保留换行、制表符用于格式）
    s = s.replaceAll(_controlCharsRe, '');

    // 2) 折叠连续空白
    s = s.replaceAll(_inlineWsRe, ' ');
    s = s.replaceAll(_blankLineRunRe, '\n\n');

    // 3) 限长
    if (s.length > maxInputLength) {
      s = s.substring(0, maxInputLength).trimRight();
    }

    // 4) 注入标记降级：在标记字符间插入零宽空格，打断连续指令语义
    for (final entry in _markerPatterns.entries) {
      final marker = entry.key;
      if (s.toLowerCase().contains(marker.toLowerCase())) {
        final broken = marker.split('').join('\u200B');
        s = s.replaceAll(entry.value, broken);
      }
    }

    return s.trim();
  }

  /// 净化并输出可直接嵌入 Prompt 的「玩家行动」文本。
  static String sanitizeAction(String raw) {
    final s = sanitize(raw);
    return s.isEmpty ? '（玩家未作任何表示）' : s;
  }
}