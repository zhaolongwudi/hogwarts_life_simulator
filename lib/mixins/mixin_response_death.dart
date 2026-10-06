import 'dart:async';
import '../models/npc.dart';
import '../data/scar_data.dart';
import '../data/death_data.dart';
import '../data/rivalry_data.dart';
import '../models/long_term_memory.dart';
import '../providers/game_provider_base.dart';
import '../utils/debug_log.dart';
import '../data/memory_importance_config.dart';


/// 死亡与疤痕结算族（第十轮 r10-1 自 mixin_response 拆出）。
/// tryDeathFromNarrative：从叙事认出指名道姓的死亡并落账；
/// _rippleDeathTo：死亡涟漪（宿敌关系/未闭环/OpenLoop 连锁）；
/// tryScarFromNarrative：伤痕记忆（Scar）落疤。
mixin GameResponseDeathMixin on GameProviderBase {
  /// 从叙事里认出死亡，把它变成一件回不去的事。
  ///
  /// 判定在 `death_data.deathInNarrative`：必须指名道姓，
  /// 而且不能是"差点死了""以为他要死了"这类说法。
  void tryDeathFromNarrative(String text) {
    if (player == null) return;

    // 只认还活着的——已经死了的人不会再死一次
    final living = npcRegistry.values
        .where((n) => n.isAlive && n.introduced)
        .toList(growable: false);
    if (living.isEmpty) return;

    final hitName = deathInNarrative(text, living.map((n) => n.name));
    if (hitName == null) return;

    NPC? dead;
    for (final n in living) {
      if (n.name == hitName) dead = n;
    }
    if (dead == null) return;

    final ts = worldState.time.format();
    final cause = deathCauseIn(text);
    dead.isAlive = false;
    dead.deathCause = cause;
    dead.diedOn = ts;

    notifications.add(deathNoticeFor(dead.name, cause));
    memory = memory.addKeyFact(
      KeyFactRecord(
        id: 'death_${dead.id}',
        fact: deathFactFor(dead.name, cause),
        // 身份级（kIdentityFactImportance）：一个人的死不能被淘汰掉——
        // 100 条容量溢出时按分数淘汰，而这件事必须留到最后。
        importance: kIdentityFactImportance,
        timestamp: ts,
        category: 'death',
        npcIds: {dead.id},
      ),
    );
    worldState.addNarrativeEvent('💀 ${dead.name} 死了', turn: turnCount);
    _rippleDeathTo(dead, ts);
    debugLog('💀 ${dead.name} 死了（${cause ?? '死因不明'}）@ turn=$turnCount');
  }

  /// 一个人死后，活着的人会怎么样。
  ///
  /// 三件事：你恨过他的话那笔账就此了结、跟他关系好的人被波及、
  /// 他没做完的事永远做不到了。
  void _rippleDeathTo(NPC dead, String ts) {
    final today = worldState.time.absoluteDayIndex;

    // 死者是玩家的宿敌：你恨了七年的人没了，那七年突然没有地方放。
    //
    // 宿敌分不用清零——他已经死了，会被「在场」「宿敌名册」那些
    // isAlive 过滤挡在叙事之外。要留下的是**这一笔记忆**。
    if (dead.rivalryTier(today).index >= RivalryTier.hostile.index) {
      memory = memory.addKeyFact(
        KeyFactRecord(
          id: 'rival_ended_${dead.id}',
          fact: rivalEndedFactFor(dead.name),
          importance: kImportanceRivalEnded,
          timestamp: ts,
          category: 'rivalry',
          npcIds: {dead.id},
        ),
      );
    }

    // 死亡涟漪会扫过所有已登场且还活着的 NPC。以前每人一次 notifyListeners
    // + 一次全量写档，一场葬礼就是上百次全量 rebuild 与上百次整档序列化——
    // 偏偏这一刻 UI 最卡。改成静默批量，循环外只通知一次。
    var deathRippleTouched = false;
    for (final n in npcRegistry.values) {
      if (n.id == dead.id || !n.isAlive || !n.introduced) continue;

      final ripple = rippleFor(n.affection);
      if (ripple.affectionDelta == 0) continue;
      updateNpcAffection(
        n.id,
        ripple.affectionDelta,
        reason: '共同失去了${dead.name}',
        quiet: true,
      );
      deathRippleTouched = true;
    }
    if (deathRippleTouched) {
      notifyListeners();
      unawaited(autoSave());
    }

    // 最重的一笔：他参与的、还没了结的事，永远做不到了。
    final broken = loopsBrokenByDeath(memory.openLoops, dead.id);
    for (final l in broken) {
      memory = memory.addOrUpdateOpenLoop(
        OpenLoopRecord(
          id: l.id,
          description: l.description,
          status: 'dropped',
          importance: l.importance,
          openedAt: l.openedAt,
          closedAt: ts,
          npcIds: l.npcIds,
          loopType: l.loopType,
          openedTurn: l.openedTurn,
        ),
      );
      memory = memory.addKeyFact(
        KeyFactRecord(
          id: 'promise_broken_${l.id}',
          fact: brokenPromiseFactFor(l.description),
          // 永不遗忘层（kPersistentFactImportance）：他答应过的事永远做不到了，
          // 这条事实不该被「今天魔药课拿了优秀」挤掉。
          importance: kPersistentFactImportance,
          timestamp: ts,
          category: 'promise_broken',
          npcIds: l.npcIds,
        ),
      );
    }
  }

  /// 从叙事里认出重伤，在身上留一道永久的疤。
  ///
  /// 判定在 `scar_data.scarFromNarrative`：必须同时伤得够重、
  /// 又说得出伤在哪个部位，两者缺一都不留——
  /// 只说"受了重伤"不知道伤在哪，只说"手臂疼"不知道够不够重。
  void tryScarFromNarrative(String text) {
    final p = player;
    if (p == null) return;

    final def = scarFromNarrative(text);
    if (def == null) return;
    // 同一个部位不重复记——它已经在那儿了
    if (p.scars.any((s) => s.site == def.site)) return;

    final ts = worldState.time.format();
    p.scars.add(Scar(site: def.site, since: ts));

    notifications.add(scarNoticeFor(def));
    memory = memory.addKeyFact(
      KeyFactRecord(
        id: 'scar_${def.key}',
        fact: '你的${def.label}永远不会好：${def.aftermath}',
        // 永不遗忘层（kPersistentFactImportance）：它是"这件事定义了我这七年"
        // 级别的东西，100 条容量溢出时按分数淘汰，疤该留下来。
        importance: kPersistentFactImportance,
        timestamp: ts,
        category: 'scar',
      ),
    );
    worldState.addNarrativeEvent('🩹 ${def.label}', turn: turnCount);
    debugLog('🩹 落疤 ${def.key} @ turn=$turnCount');
  }
}
