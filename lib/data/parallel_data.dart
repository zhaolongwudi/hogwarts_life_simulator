import '../models/player.dart';

// ==================== 小剧场的产出回流 ====================
//
// 「平行世界小剧场」里玩家写的那些脑洞，此前只是躺在存档里的一堆字：
// 能在列表里翻到，能删，但**跟主线没有任何关系**。
// 玩家花心思写过的一个"如果……"，退出页面之后就只是一行列表项。
//
// 现在可以把它"采纳"进主线。
//
// ── 采纳是什么意思 ──
//
// 第一个念头是"采纳 = 它真的发生了"。这个念头被否掉了：
// 采纳一个"如果邓布利多开了家甜品店"的脑洞就把它变成既成事实，
// 那么世界线变动率那套系统（改写要付代价、要够门槛才能改写）
// 就成了一句空话——你写一句，世界就改一次。
//
// 所以采纳的落点是另一处：
//
//   **它不改变世界，它改变你看世界的方式。**
//
// 采纳之后，那个"如果"成了你心里的一件事。它不会让邓布利多真的
// 去开甜品店，但你会时不时想起那条没走过的路——
// 在你犹豫的时候、在你后悔的时候、在你看见别人走了那条路的时候。
// 这才是"另一个版本的你"该有的分量：不是改变发生过什么，
// 而是改变你怎么看待发生过什么。

/// 写进长期记忆时的正文上限。
///
/// KeyFactRecord.fact 的约定是"一行写完"（见 long_term_memory.dart），
/// 而小剧场的 description 是玩家自由输入的，多长都有可能。
const int kAdoptedFactMaxChars = 44;

/// prompt 里最多同时挂几条。
///
/// 采纳得多的玩家不该被自己的脑洞淹没：这是调料，不是主线。
const int kMaxAdoptedInPrompt = 3;

/// 把描述截到能一行写完的长度。
///
/// 从字符中间砍断会留下半个词，所以往回退到最后一个标点或空格处。
String _trim(String text, int max) {
  final s = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.length <= max) return s;
  final cut = s.substring(0, max);
  const breaks = {'，', '。', '、', '；', '：', '！', '？', '…', ' ', ',', '.'};
  for (var i = cut.length - 1; i > max ~/ 2; i--) {
    if (breaks.contains(cut[i])) return '${cut.substring(0, i)}…';
  }
  return '$cut…';
}

/// 采纳后写进长期记忆的那一句。
///
/// 用"你在心里排演过"而不是"发生过"——
/// 这一句要是写成陈述一个事实，AI 后面会把它当既成事实来写戏。
String adoptedFactFor(ParallelScenario s) {
  final brief = _trim(s.description, kAdoptedFactMaxChars);
  return '你认真想过另一种可能「${s.title}」：$brief';
}

/// 采纳时的通知文案。
String adoptedNoticeFor(ParallelScenario s) =>
    '🌗 你把「${s.title}」留在了心里。它不会发生，但你会想起它。';

/// 采纳之后的 prompt 段落；没有采纳过就返回空串。
///
/// 明确告诉 AI 两件事：这些没有发生过，以及它们该怎么用。
/// 只说"玩家想过这些"而不说清"它们不是事实"，
/// AI 大概率会当成背景设定写进去——那就变成了一键改世界。
String adoptedPromptBlock(Iterable<ParallelScenario> scenarios) {
  // 过滤放在这里而不是调用方：只收已采纳的。
  // 让调用方记得过滤的话，任何一个忘了的地方就会把玩家随手写着玩的
  // 脑洞全塞进 prompt——那是凭空给他加设定。
  final list = scenarios.where((s) => s.adopted).toList();
  if (list.isEmpty) return '';
  final shown = list.take(kMaxAdoptedInPrompt).toList();
  final lines = shown.map((s) {
    final brief = _trim(s.description, 60);
    return '· ${s.title}：$brief';
  });
  final more = list.length > shown.length
      ? '\n（此外还有 ${list.length - shown.length} 个）'
      : '';
  return '【另一种可能】以下这些都**没有发生过**，'
      '是这个人在心里排演过的别的版本。'
      '不要把它们写成既成事实，也不要让旁人知道；'
      '它们是独白，不是剧情。'
      '可以在他犹豫、后悔、或者看见别人走了那条路的时候，'
      '让他自己想起来一次：\n${lines.join('\n')}$more';
}
