import '../models/npc.dart';

/// 在 NPC 注册表里按关键词找最匹配的那一个。
///
/// 项目里原本散着 4 份各写各的实现，语义还不一致：
///
/// * `mixin_relations._findNpcByName` —— 只比 `name` 的精确/包含，
///   **完全忽略 aliases**，玩家输别名或姓氏经常查不到人；
/// * `mixin_relations` 里的局部 `findNpc` —— 双向 contains，
///   查不到时造一个 `id` 为空的假 NPC 让调用方去判；
/// * `mixin_response_affection` 与 `game_narrative_tab` —— 各自手写一遍
///   「遍历取 `nameMatchScore` 最高分」的循环。
///
/// 后果是同一个名字在不同入口命中不同的 NPC，而且 `/拉郎配` 这类命令
/// 用的恰好是最弱的那份。这里统一收敛到 `NPC.nameMatchScore`
/// （含 aliases、中英文姓氏推导、长度加权打分），查不到就返回 null。
NPC? findNpcByKeyword(Iterable<NPC> npcs, String keyword, {int minScore = 0}) {
  final kw = keyword.trim();
  if (kw.isEmpty) return null;
  NPC? best;
  var bestScore = minScore;
  for (final n in npcs) {
    final score = n.nameMatchScore(kw);
    if (score > bestScore) {
      bestScore = score;
      best = n;
    }
  }
  return best;
}
