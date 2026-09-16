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
    memory = memory.addKeyFact(
      KeyFactRecord(
        id: 'player_death',
        fact: '主角于$ts死亡，死因为$cause。',
        importance: 10,
        timestamp: ts,
        category: 'identity',
      ),
    );

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
      ..writeln(
        '· 学术声望 ${rep.academic} ｜ 社交 ${rep.social} ｜ 战斗 ${rep.combat} ｜ 道德 ${rep.moral}',
      )
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
      buf.writeln(
        '${mourners.take(5).join('、')}${mourners.length > 5 ? ' 等' : ''} 为你的离去而悲痛。',
      );
    }
    buf
      ..writeln()
      ..writeln('死亡是真实的，不可读档，不可重来。')
      ..writeln('但这一生留下的每一道痕迹，都还在那个世界里。');
    return buf.toString();
  }

  /// 回合结算时调用：犯罪累积到一定程度（黑魔法声望压过道德底线）且
  /// 未无敌时，触发坏结局二「自由尽失」——被捕入狱，人生进入终章。
  ///
  /// 框架2 §118：玩家仍然活着，但因长期犯罪或重大事件被囚禁/放逐，
  /// 失去原有生活，人生进入无法挽回的方向。
  /// 判定做成确定性（条件满足即结算），不做随机——框架2 §75 强调
  /// 「明知极度危险仍故意挑战强敌，世界应该真实结算」，不能靠掷骰子
  /// 决定要不要抓你。触发点放在每回合的 _settleAfterNarrative 里。
  void checkImprisonment() {
    final p = player;
    if (p == null || p.isDead || p.isImprisoned) return;
    if (p.cheatInvincible) return; // /cheat 无敌：罪行不影响自由
    final rep = p.playerReputation;
    if (rep.dark < 75 || rep.moral >= 40) return;
    // 未成年巫师在校内犯罪通常先送魔法部训诫，成年或毕业后才真正入狱；
    // 简化处理：只要罪证确凿（黑魔法声望压过道德）且不是儿童保护阶段，
    // 一律真实结算。grade 空（已毕业）或 >=6（六年级起）视为可被追责。
    final grade = p.grade ?? 1;
    if (grade < 6) return;
    _doImprisonment(
      '魔法法律执行司查实了你长期的黑魔法活动与罪行，'
      '威森加摩在《预言家日报》记者的注视下宣判：阿兹卡班。',
    );
  }

  void _doImprisonment(String cause) {
    final p = player!;
    p.isImprisoned = true;
    p.imprisonedOn = worldState.time.format();
    p.endingType = 'imprisoned';

    // 长期记忆：被捕是不可磨灭的事实
    final ts = worldState.time.format();
    memory = memory.addKeyFact(
      KeyFactRecord(
        id: 'player_imprisoned',
        fact: '主角于$ts因黑魔法罪行被判入阿兹卡班，人生就此改道。',
        importance: 10,
        timestamp: ts,
        category: 'identity',
      ),
    );

    // 世界涟漪：关系网络震动
    final shocked = <String>[];
    for (final npc in npcRegistry.values) {
      if (!npc.isAlive) continue;
      if (npc.affection >= 50) {
        updateNpcAffection(npc.id, -8, reason: '你的入狱令其震惊', quiet: true);
        npc.recentEvents.insert(0, '震惊于你被捕入狱');
        if (npc.recentEvents.length > 10) npc.recentEvents.removeLast();
        shocked.add(npc.name);
      }
    }
    worldState.addNarrativeEvent('⚖️ 你被捕了——自由尽失', turn: turnCount);

    // 终章
    currentNarrative = _imprisonmentEndingNarrative(cause, shocked);
    choices = [
      GameChoice(text: '查看人生终章（AI 版）', action: '/结局'),
      GameChoice(text: '回望这一生', action: '/状态'),
    ];
    notifyListeners();
    unawaitedSafe(autoSave());
  }

  String _imprisonmentEndingNarrative(String cause, List<String> shocked) {
    final p = player!;
    final age = calculateAge();
    final rep = p.playerReputation;
    final buf = StringBuffer()
      ..writeln('═══ 人生终章 · 自由尽失 ═══')
      ..writeln()
      ..writeln('${worldState.time.format()}，法庭的锤声落定。')
      ..writeln()
      ..writeln('$cause')
      ..writeln()
      ..writeln('你仍活着——这是比死亡更沉重的判决。')
      ..writeln()
      ..writeln('你这一生，在 ${age} 岁这一年失去了自由。')
      ..writeln()
      ..writeln('【此生的痕迹】')
      ..writeln('· 学院：${p.house ?? '未分院'} · ${p.grade ?? 1}年级')
      ..writeln(
        '· 学术声望 ${rep.academic} ｜ 社交 ${rep.social} ｜ 战斗 ${rep.combat} ｜ 道德 ${rep.moral} ｜ 黑魔法 ${rep.dark}',
      )
      ..writeln('· 世界线变动率：${(p.worldLineDeviation * 100).toStringAsFixed(1)}%')
      ..writeln('· 成就解锁：${p.achievements.length} 项');
    if (p.loveState.partnerName != null) {
      buf.writeln('· 曾与 ${p.loveState.partnerName} ${p.loveState.status}');
    }
    if (p.children.isNotEmpty) {
      buf.writeln('· 留下了 ${p.children.length} 个孩子');
    }
    if (shocked.isNotEmpty) {
      buf.writeln();
      buf.writeln('【有人记得你】');
      buf.writeln(
        '${shocked.take(5).join('、')}${shocked.length > 5 ? ' 等' : ''} 至今仍不敢相信那天的判决。',
      );
    }
    buf
      ..writeln()
      ..writeln(
        '自由尽失不是一句游戏失败——它是你这些年每一个选择'
        '累积出来的、无法挽回的方向。',
      )
      ..writeln('但这段人生留下的每一道痕迹，都还在那个世界里。');
    return buf.toString();
  }

  /// 死亡/囚禁后拦截普通行动：只能查看终章或开启新人生。
  /// 在 processChoice 入口调用，返回 true 表示已拦截。
  bool blockActionIfDead() {
    final p = player;
    if (p == null || (!p.isDead && !p.isImprisoned)) return false;
    final imprisoned = !p.isDead && p.isImprisoned;
    currentNarrative = imprisoned
        ? '你已被押往阿兹卡班。镣铐的寒意贴在手腕上，摄魂怪在铁栏外徘徊。'
              '这段人生的最后一页已经被命运合上。\n\n'
              '你可以：\n'
              '  · /结局 — 查看完整的 AI 人生终章\n'
              '  · /状态 — 回望这一生的最后模样\n'
              '  · 开启新的人生：点右下角「设置」→「开始新游戏」（若你有孩子，'
              '/传承 可让下一代接过这个故事）'
        : '你已不在人间。这段人生的最后一页已经写完。\n\n'
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
