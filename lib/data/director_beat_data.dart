/// 导演指令（数据层）
///
/// prompt 里塞的是"状态 + 规则 + 上下文"，唯独没说**这一回合要干嘛**。
/// 结果就是 AI 每回合平均用力：既没有气氛段落，也不会主动回收悬着的钩子，
/// 一整局读下来是平的。
///
/// 这里给出三选一的节拍：日常 → 推进 → 转折，三回合一个节奏单元。
library;

/// 本回合的叙事节拍。
enum DirectorBeat {
  /// 日常：不推进大事件，把场景和气氛写实
  daily,

  /// 推进：把悬着的事往前推一步
  advance,

  /// 转折：出点意外、代价或冲突
  turn,
}

class DirectorBeatDef {
  final DirectorBeat beat;

  /// 给玩家/日志看的短标签
  final String label;

  /// 一句话任务。塞进 prompt 的【本回合任务】段。
  final String task;

  const DirectorBeatDef({
    required this.beat,
    required this.label,
    required this.task,
  });
}

const List<DirectorBeatDef> kDirectorBeats = [
  DirectorBeatDef(
    beat: DirectorBeat.daily,
    label: '日常',
    task: '不推进任何大事件。把当下这个场景写实：一个具体的动作、一种气味或声音、'
        '一个无关紧要却让人记住的细节。让这一回合值回它占用的时间。',
  ),
  DirectorBeatDef(
    beat: DirectorBeat.advance,
    label: '推进',
    task: '把悬着的事往前推一步——上一回合没说完的话、没做成的事、悬而未决的关系。'
        '给出进展，或给出进展被挡住的理由，不要原地打转。',
  ),
  DirectorBeatDef(
    beat: DirectorBeat.turn,
    label: '转折',
    task: '打破当下的平稳。来一个意外、一次代价、一场冲突，或者某个人的态度突然改变。'
        '转折要有后果，不能只是吓一跳。',
  ),
];

DirectorBeatDef beatDefFor(DirectorBeat beat) =>
    kDirectorBeats.firstWhere((b) => b.beat == beat);

/// 每回合选一个节拍。
///
/// 基础是三回合一个循环（[turn] % 3），保证"转折"至少每三回合来一次，
/// 不必另外维护"多久没转折了"的计数器。
///
/// [hasUnresolvedHook] 表示上一回合的叙事停在半截（"他举起魔杖……"），
/// 这时就算轮到「日常」也要改判「推进」——读者正等着下文，
/// 此刻写气氛段落是最扫兴的。
DirectorBeat directorBeatFor({
  required int turn,
  required bool hasUnresolvedHook,
}) {
  final base = switch (turn % 3) {
    0 => DirectorBeat.advance,
    1 => DirectorBeat.daily,
    _ => DirectorBeat.turn,
  };
  if (base == DirectorBeat.daily && hasUnresolvedHook) {
    return DirectorBeat.advance;
  }
  return base;
}

/// 拼成塞进 prompt 的一行。
String directorLineFor(DirectorBeat beat) {
  final def = beatDefFor(beat);
  return '【本回合任务】${def.label} —— ${def.task}';
}
