import '../models/long_term_memory.dart';
import '../models/npc.dart';
import '../models/player.dart';

/// 离线/无 AI 叙事用的「个性化上下文」。
///
/// 【为什么需要它】`generateFallbackNarrative` 原本只读名字 / 年级 / 地点 / 天气
/// （见 `mixin_response._fallbackSeedsFor`），在线 `buildPrompt` 注入的 T0~T4
/// 分层玩家上下文在离线路径里全被闲置。这个类把这些本地已有、但离线叙事没
/// 消费的数据——好感、关系、恋爱对象、未完结事项、长期事实、声望——收敛成
/// 一段段可以直接拼进兜底叙事的中文句子，让「AI 掉线了」时文案依然能反映
/// 这段存档自己的故事，而不是套模板。
///
/// 【为什么是纯数据类、不触发 AI】离线模式是「AI 不可用时的最后一道体面」，
/// 它必须永远走得通、零网络、零 Key，所以这里只做规则拼接，绝不调用模型。
class OfflineNarrativeContext {
  /// 按优先级排列的可选插入句（可为空）。
  ///
  /// 顺序即优先级：恋爱对象 → NPC 强关系 → 亲近关系 → 未完结事项 → 长期事实
  /// → 宠物 → 声望 → 性格。`pick(seq)` 在非空时按轮转取一条，避免长局里
  /// 同一句反复出现。
  final List<String> hooks;

  OfflineNarrativeContext._(this.hooks);

  /// 是否有可用的个性化内容。
  bool get isEmpty => hooks.isEmpty;

  /// 按单调递增的 seq 轮转取一条插入句；无内容时返回空串。
  String pick(int seq) {
    if (hooks.isEmpty) return '';
    return hooks[seq % hooks.length];
  }

  /// 从一份真实存档的玩家与长期记忆构建上下文。
  factory OfflineNarrativeContext.build({
    Player? player,
    LongTermMemory? memory,
    Map<String, NPC>? npcRegistry,
  }) {
    final hooks = <String>[];
    final p = player;
    if (p == null) return OfflineNarrativeContext._(hooks);

    // 1) 恋爱/暧昧对象钩子 —— 优先级最高。
    final love = p.loveState;
    final loveName = _firstNonEmpty(love.partnerName, love.consideringNpcName);
    if (loveName != null) {
      hooks.add('夜晚的空气里你莫名想起了$loveName——你们之间还隔着不少故事没有讲完，而今天不过是其中一页。');
    }

    // 2) NPC 强关系钩子（按好感绝对值取最有记忆点的一个，正负皆可）。
    final hookNpc = _mostMemorableNpc(npcRegistry);
    if (hookNpc != null) {
      hooks.add(hookNpc.affection > 0
          ? '${hookNpc.name}隔着人群朝你点了点头——你们之间的交情，在城堡里不是秘密。'
          : '你留意到${hookNpc.name}看你的眼神并不算友善——那根刺，还没有拔掉。');
    }

    // 3) 亲近关系钩子（T2 relationships，按 level 取最高）。
    final relation = _strongestRelation(p);
    if (relation != null) {
      final tone = _relationTone(relation.relationType);
      final hist = relation.history.isNotEmpty ? relation.history.last : '';
      if (hist.isNotEmpty) {
        hooks.add('$tone${relation.targetName}，你还记得你们之间的那件事。这份交情，不是一两句话能抹掉的。');
      } else {
        hooks.add('$tone${relation.targetName}——你们之间，已经不需要客套的开场。');
      }
    }

    // 4) 未完结事项钩子（T1 openLoops 中仍是 open 的最高重要度一条）。
    final openLoop = _highestOpenLoop(memory);
    if (openLoop != null) {
      hooks.add('一件没办完的事浮上你心头：${_shear(openLoop.description)}。它悬在那里，等着你回去把它落地。');
    }

    // 5) 重要长期事实钩子（T0 keyFacts 中重要度最高的一条）。
    final keyFact = _highestKeyFact(memory);
    if (keyFact != null) {
      hooks.add('有些事不会因为日子照常而褪色——${_shear(keyFact.fact)}。你心知肚明。');
    }

    // 6) 宠物钩子。
    final pet = _firstNonEmpty(p.petName);
    if (pet != null) {
      hooks.add('$pet蹭了蹭你的手。有它在，再紧绷的一天也像被拨松了一根弦。');
    }

    // 7) 声望钩子（只在社会性主要口碑成型后才值得写）。
    final repLabel = _topReputationLabel(p);
    if (repLabel != null) {
      hooks.add('走在人群里，你偶尔会捕捉到旁人对你的低声评价——「$repLabel」这几个字，能撬动很多人的态度。');
    }

    // 8) 性格钩子。
    final traits = p.personalityTraits.where((t) => t.isNotEmpty).toList();
    if (traits.isNotEmpty) {
      hooks.add('你一直是个${traits.join('、')}的人——这份底色，会在每个决定的缝隙里露出头来。');
    }

    return OfflineNarrativeContext._(hooks);
  }

  static String? _firstNonEmpty(String? a, [String? b]) {
    if (a != null && a.isNotEmpty) return a;
    if (b != null && b.isNotEmpty) return b;
    return null;
  }

  /// 取好感绝对值最大、且达到「有明显记忆点」阈值的 NPC。
  static NPC? _mostMemorableNpc(Map<String, NPC>? npcRegistry) {
    if (npcRegistry == null || npcRegistry.isEmpty) return null;
    NPC? best;
    var bestAbs = 0;
    for (final n in npcRegistry.values) {
      final a = n.affection.abs();
      if (a > bestAbs) {
        bestAbs = a;
        best = n;
      }
    }
    if (best == null || bestAbs < 15 || best.name.isEmpty) return null;
    return best;
  }

  /// 取 level 最高的关系，并排除「化形羁绊」这类非人态占位。
  static Relationship? _strongestRelation(Player p) {
    Relationship? best;
    for (final rel in p.relationships.values) {
      if (rel.relationType == '化形羁绊') continue;
      final key = rel.level;
      if (key <= 0) continue;
      if (best == null || key > best.level) best = rel;
    }
    return best;
  }

  /// 按 relationType 给关系钩子定语气（默认中性偏暖）。
  static String _relationTone(String type) {
    if (type.contains('挚友') || type.contains('可靠伙伴')) return '你一眼就认出了';
    if (type.contains('朋友') || type.contains('同学')) return '一张熟悉的脸在人群里朝你点头——';
    return '有人叫住了你——那是';
  }

  /// openLoops 中仍处于 open、且重要度最高的一条。
  static OpenLoopRecord? _highestOpenLoop(LongTermMemory? memory) {
    if (memory == null) return null;
    OpenLoopRecord? best;
    for (final l in memory.openLoops) {
      if (l.status != 'open') continue;
      if (best == null || l.importance > best.importance) best = l;
    }
    return best;
  }

  /// keyFacts 中重要度最高的一条（用于叙事里引一句"值得记住的事"）。
  static KeyFactRecord? _highestKeyFact(LongTermMemory? memory) {
    if (memory == null) return null;
    KeyFactRecord? best;
    for (final f in memory.keyFacts) {
      if (best == null || f.importance > best.importance) best = f;
    }
    return best;
  }

  /// 若社会性主要口碑已成型（≥50），返回其中文标签；否则 null。
  static String? _topReputationLabel(Player p) {
    String? topKey;
    var topVal = -1;
    for (final k in p.playerReputation.dimensions) {
      final v = p.playerReputation.get(k);
      if (v > topVal) {
        topVal = v;
        topKey = k;
      }
    }
    if (topKey == null || topVal < 50) return null;
    return p.playerReputation.labelOf(topKey);
  }

  /// 截断过长的存档文本，避免插入句把叙事撑爆。
  static String _shear(String s, [int max = 42]) {
    final t = s.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }
}