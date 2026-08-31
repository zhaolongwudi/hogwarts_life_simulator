/// 玩家死亡系统（框架2 §74 死亡真实存在 + §118 三类坏结局之一）
///
/// 之前玩家的 health 处处 clamp(1,100)，永远不会归零——这个世界里
/// 只有 NPC 会死，玩家本人是不死的。现在补上：
///   · 决斗/禁林/委托等伤害结算允许 health 归零；
///   · health ≤ 0 触发玩家死亡：写入档案、记入长期记忆、生成死亡终章；
///   · 死亡不可逆：后续行动被拦截，只能查看终章或开始新的人生；
///   · /cheat 无敌 可免疫死亡（作弊项）。
///
/// 死亡不是"游戏失败"——它是这段人生的句号。终章里会回望这一生。

import '../models/game_systems.dart';
import '../models/long_term_memory.dart';
import '../providers/game_provider_base.dart';

mixin GameDeathMixin on GameProviderBase {
  /// 伤害结算后调用：health ≤ 0 且未死亡时触发死亡流程。
  /// [cause] 是叙事友好文案（如「决斗中被咒语击中」「禁林深处的怪物袭击」）。
  void checkPlayerDeath(String cause) {
    final p = player;
    if (p == null || p.isDead) return;
    if (p.health > 0) return;
    // /cheat 无敌：伤害不会致死
    if (p.cheatInvincible) {
      p.health = 1;
      notifications.add('🛡️ 无敌模式挡住了致命一击。');
      return;
    }
    _doPlayerDeath(cause);
  }

  void _doPlayerDeath(String cause) {
    final p = player!;
    p.isDead = true;
    p.deathCause = cause;
    p.deadOn = worldState.time.format();
    p.endingType = 'death';

    // 长期记忆：死亡是不可磨灭的事实
    final ts = worldState.time.format();
    memory = memory.addKeyFact(KeyFactRecord(
      id: 'player_death',
      fact: '主角于$ts死亡，死因为$cause。',
      importance: 10,
      timestamp: ts,
      category: 'identity',
    ));

    // 世界涟漪：至交记念
    final mourners = <String>[];
    for (final npc in npcRegistry.values) {
      if (!npc.isAlive) continue;
      if (npc.affection >= 50) {
        updateNpcAffection(npc.id, 5, reason: '悼念你的离去', quiet: true);
        npc.recentEvents.insert(0, '为你的死感到悲痛');
        if (npc.recentEvents.length > 10) npc.recentEvents.removeLast();
        mourners.add(npc.name);
      }
    }
    worldState.addNarrativeEvent('💀 你死了——$cause', turn: turnCount);

    // 死亡终章
    currentNarrative = _deathEndingNarrative(cause, mourners);
    choices = [
      GameChoice(text: '查看人生终章（AI 版）', action: '/结局'),
      GameChoice(text: '回望这一生', action: '/状态'),
    ];
    notifyListeners();
    unawaitedSafe(autoSave());
  }

  String _deathEndingNarrative(String cause, List<String> mourners) {
    final p = player!;
    final age = calculateAge();
    final rep = p.playerReputation;
    final buf = StringBuffer()
      ..writeln('═══ 人生终章 · 死亡 ═══')
      ..writeln()
      ..writeln('${worldState.time.format()}，你的故事在这里停下。')
      ..writeln()
      ..writeln('$cause。')
      ..writeln()
      ..writeln('你这一生，止步于 ${age} 岁。')
      ..writeln()
      ..writeln('【此生的痕迹】')
      ..writeln('· 学院：${p.house ?? '未分院'} · ${p.grade ?? 1}年级')
      ..writeln('· 学术声望 ${rep.academic} ｜ 社交 ${rep.social} ｜ 战斗 ${rep.combat} ｜ 道德 ${rep.moral}')
      ..writeln('· 世界线变动率：${(p.worldLineDeviation * 100).toStringAsFixed(1)}%')
      ..writeln('· 成就解锁：${p.achievements.length} 项');
    if (p.loveState.partnerName != null) {
      buf.writeln('· 曾与 ${p.loveState.partnerName} ${p.loveState.status}');
    }
    if (p.children.isNotEmpty) {
      buf.writeln('· 留下了 ${p.children.length} 个孩子');
    }
    if (mourners.isNotEmpty) {
      buf.writeln();
      buf.writeln('【有人记得你】');
      buf.writeln('${mourners.take(5).join('、')}${mourners.length > 5 ? ' 等' : ''} 为你的离去而悲痛。');
    }
    buf
      ..writeln()
      ..writeln('死亡是真实的，不可读档，不可重来。')
      ..writeln('但这一生留下的每一道痕迹，都还在那个世界里。');
    return buf.toString();
  }

  /// 死亡后拦截普通行动：只能查看终章或开启新人生。
  /// 在 processChoice 入口调用，返回 true 表示已拦截。
  bool blockActionIfDead() {
    final p = player;
    if (p == null || !p.isDead) return false;
    currentNarrative = '你已不在人间。这段人生的最后一页已经写完。\n\n'
        '你可以：\n'
        '  · /结局 — 查看完整的 AI 人生终章\n'
        '  · /状态 — 回望这一生的最后模样\n'
        '  · 开启新的人生：点右下角「设置」→「开始新游戏」（若你有孩子，'
        '/传承 可让下一代接过这个故事）';
    choices = [
      GameChoice(text: '查看人生终章（AI 版）', action: '/结局'),
      GameChoice(text: '回望这一生', action: '/状态'),
    ];
    return true;
  }

  // 避免在此引入 dart:async 依赖的辅助
  void unawaitedSafe(Future<void> f) {
    f.ignore();
  }
}
