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

  /// 净化用户输入：去控制字符、折叠空白、限长、转义注入标记。
  static String sanitize(String raw) {
    var s = raw;

    // 1) 去除控制字符（保留换行、制表符用于格式）
    s = s.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

    // 2) 折叠连续空白
    s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // 3) 限长
    if (s.length > maxInputLength) {
      s = s.substring(0, maxInputLength).trimRight();
    }

    // 4) 注入标记降级：用全角括号弱化其指令语义
    for (final marker in _injectionMarkers) {
      if (s.toLowerCase().contains(marker.toLowerCase())) {
        s = s.replaceAll(
          RegExp(marker, caseSensitive: false),
          '[${marker.replaceAll(' ', '')}]',
        );
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