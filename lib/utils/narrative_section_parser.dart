/// AI 输出里「【XXX】…」区块的解析工具。
///
/// 抽成纯函数（不依赖 Provider / ChangeNotifier / NPC 注册表）只有一个目的：
/// 好感与声望的解析是全项目最容易静默失效的一段逻辑——AI 换个写法就整段
/// 丢数据，而它以前只存在于 mixin 内部，测试根本没法直接调用
/// （第六次审查实测：deepseek_service / ai_router / mixin_response 三条
/// 主动脉的行为测试为 0，其中就包括这里）。
library;

/// 把一个「【XXX】…」区块的**所有**出现拼成一段。
///
/// AI 偶尔会把同一类区块拆成两段（先列主线、再列支线）。好感侧很早就改成
/// allMatches 了，声望侧却一直是 firstMatch——与好感侧逐字同构的 bug，
/// 只修了 A 面：AI 一拆段，第二个区块就静默丢弃，玩家明明在支线上出了风头，
/// 声望却一动不动。现在两侧共用这一个函数，不会再漏改。
///
/// 全部区块都为空时返回 null，交给调用方决定走不走 fallback。
String? allSectionText(String text, RegExp pattern) {
  final matches = pattern.allMatches(text).toList();
  if (matches.isEmpty) return null;
  final joined = matches
      .map((m) => m.group(1)?.trim() ?? '')
      .where((s) => s.isNotEmpty)
      .join('\n');
  return joined.isEmpty ? null : joined;
}

/// 声望区块的标签头。兼容【声望变化】与【声望变】两种写法。
final RegExp kReputationSectionRe = RegExp(r'【声望变化?】\s*([\s\S]*?)(?=【|$)');

/// 声望行：兼容全角冒号、全角加号、「· 战斗：+2」这类带项目符号的写法。
final RegExp kReputationLineRe =
    RegExp(r'^[\s\-•·*]*([^:：+\-0-9]{1,10}?)\s*[:：]?\s*([+＋-]?\d+)');

/// 一条解析出来的声望变化。
class ReputationDelta {
  /// AI 写的维度名（可能不在白名单里，由调用方决定是忽略还是记日志）。
  final String dimension;

  /// 原始变化量，未限幅。
  final int delta;

  const ReputationDelta(this.dimension, this.delta);

  @override
  String toString() => '$dimension ${delta > 0 ? '+' : ''}$delta';
}

/// 从完整的 AI 输出里提取所有声望变化。
///
/// 会拼接**所有**【声望变化】区块（见 [allSectionText] 的说明），
/// 并对每行做一次结构解析；认不出维度的行直接跳过，不影响其它行。
List<ReputationDelta> extractReputationDeltas(String text) {
  final section = allSectionText(text, kReputationSectionRe);
  if (section == null) return const [];
  final out = <ReputationDelta>[];
  for (final line in section.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    final match = kReputationLineRe.firstMatch(trimmed);
    if (match == null) continue;
    final dim = match.group(1)!.trim();
    final raw = match.group(2)!.replaceAll('＋', '+');
    final delta = int.tryParse(raw) ?? 0;
    if (delta == 0 || dim.isEmpty) continue;
    out.add(ReputationDelta(dim, delta));
  }
  return out;
}
