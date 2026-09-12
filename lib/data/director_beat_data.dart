/// 导演指令（数据层）
///
/// prompt 里塞的是"状态 + 规则 + 上下文"，唯独没说**这一回合要干嘛**。
/// 结果就是 AI 每回合平均用力：既没有气氛段落，也不会主动回收悬着的钩子，
/// 一整局读下来是平的。
///
/// 这里给出三选一的节拍：日常 / 推进 / 转折。
///
/// 第九次审查：三回合固定循环（turn % 3）改为「概率 + 状态感知」。
/// 固定相位有两个问题：
///  1. 可预测——长线玩家会隐约摸到"平静两回合后必出事"，意外的惊喜感没了；
///  2. 场景错配——考试周、暑假、深夜本该低张力，转折仍按相位强插。
/// 现在是：转折按「距上次转折越久概率越高」抽取，低张力场景概率减半，
/// 且有 2 回合最小间隔；日常与推进交替出现（钩子未完时强制推进）。
library;

import 'dart:math';

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
/// 转折不再是固定相位，而是「基础概率 + 久未转折权重递增」：
/// [turnsSinceLastTurn] 是距上次转折的回合数，间隔越久概率越高
/// （0.15 + 0.10 × 间隔，封顶 0.55）——转折不会缺席太久，但具体哪
/// 一回合来，玩家摸不到规律。
///
/// 两道闸门：
///  - 最小间隔：[turnsSinceLastTurn] < 2 不转折，意外需要铺垫，连着转是噪音；
///  - 场景校验：[calmContext] 为 true（考试周/暑假/深夜等低张力场景）时
///    转折概率减半——不是不转，是这个时刻更适合让人物喘口气。
///
/// [hasUnresolvedHook] 表示上一回合的叙事停在半截（"他举起魔杖……"），
/// 这时就算轮到「日常」也要改判「推进」——读者正等着下文，
/// 此刻写气氛段落是最扫兴的。（转折不受钩子拦截：转折本身就能收钩子。）
///
/// [random] 可注入以便测试确定性；缺省用全局 Random。
DirectorBeat directorBeatFor({
  required int turn,
  required bool hasUnresolvedHook,
  int turnsSinceLastTurn = 99,
  bool calmContext = false,
  Random? random,
}) {
  final rng = random ?? Random();

  // 转折抽取：久未转折权重递增，低张力场景减半，最小间隔 2 回合
  if (turnsSinceLastTurn >= 2) {
    var p = 0.15 + 0.10 * turnsSinceLastTurn;
    if (p > 0.55) p = 0.55;
    if (calmContext) p /= 2;
    if (rng.nextDouble() < p) return DirectorBeat.turn;
  }

  // 钩子未完：读者正等着下文，此刻写气氛段落是最扫兴的
  if (hasUnresolvedHook) return DirectorBeat.advance;

  // 日常与推进交替，保证两种底色都轮得到
  return turn % 2 == 0 ? DirectorBeat.advance : DirectorBeat.daily;
}

/// 拼成塞进 prompt 的一行。
String directorLineFor(DirectorBeat beat) {
  final def = beatDefFor(beat);
  return '【本回合任务】${def.label} —— ${def.task}';
}
