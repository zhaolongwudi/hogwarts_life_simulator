/// 剧情模式 · 效果接线（v2）：StoryEffect 应用、世界路由、正典锚点/记忆下沉。
///
/// 【拆分说明】r7-3 拆分自 `mixin_story_engine.dart`。这一层是「剧情选择 → 各功能
/// 系统」的接线汇总：`applyStoryEffect` 的累加语义、效果按类型路由到世界线/物品/
/// 关系/学业、原著正典节点的标记与记忆下沉、以及因果文案与数值变动的可读格式化。
/// `GameStoryEngineMixin` 声明 `on GameStoryWiringMixin`（跨 mixin 走 on 链，遵守
/// ADR-001），`GameProvider` 的 with 列表中 wiring 在 engine 之前。行为零变化。
library;

import '../data/canon_events.dart';
import '../data/item_data.dart';
import '../models/player.dart';
import '../models/long_term_memory.dart';
import '../models/story_progress.dart';
import '../providers/game_provider_base.dart';
import '../data/memory_importance_config.dart';
import '../utils/debug_log.dart';
import 'mixin_summary_memory.dart';

mixin GameStoryWiringMixin on GameProviderBase, GameSummaryMemoryMixin {
  /// 把 [StoryEffect] 落到玩家 / 世界 / 长期记忆上。
  ///
  /// 【为什么效果要用"累加"而不是"直接赋值"】
  /// `StoryProgress.effects` 是跨存档累计的，用于结局判定；
  /// 而 `Player` 上的数值会被剧情之外的行为改写（战斗、送礼…），
  /// 两者不能混用，否则结局判定会随日常行为漂移。
  void applyStoryEffect(StoryEffect effect) {
    if (effect.isEmpty) return;
    final p = player;
    final acc = Map<String, int>.from(storyProgress.effects);

    void bump(String key, int delta) {
      if (delta == 0) return;
      acc[key] = (acc[key] ?? 0) + delta;
    }

    if (p != null) {
      if (effect.spirit != 0) {
        p.spirit = (p.spirit + effect.spirit).clamp(0, 100);
      }
      // 精力/饱食：剧情推进不再是"体力系统的法外之地"。
      // 负数消耗、正数恢复，越界一律夹回 [0,100]——与
      // `updateNPCsFromAction` 的既有口径一致（那里是 max(0,...)，
      // 这里上下都夹，因为剧情可以给正值）。
      if (effect.energy != 0) {
        p.energy = (p.energy + effect.energy).clamp(0, 100);
      }
      if (effect.satiety != 0) {
        p.satiety = (p.satiety + effect.satiety).clamp(0, 100);
      }
      if (effect.galleons != 0) {
        p.galleons = (p.galleons + effect.galleons).clamp(0, 1 << 30);
      }
      if (effect.housePoints != 0) {
        // 【守卫约束】学院杯加分必须走 `addHouseCupPoints(amount, reason)`：
        // 它内部记录来源明细（houseCupSources），学年结算要按来源展示。
        // 裸写 `p.houseCupPoints += ...` 会被
        // test/progression_fix_test.dart 的源码形状守卫抓出来。
        addHouseCupPoints(effect.housePoints, '主线剧情');
      }
      if (effect.reputation != 0) {
        p.playerReputation.add('story', effect.reputation);
      }
      if (effect.affection != 0 && effect.targetNpcId != null) {
        // 【守卫约束】好感必须走 `updateNpcAffection` 统一入口——
        // 它内部带状态同步/去重/通知管线，裸写 `npc.affection = ...`
        // 会被 test/progression_fix_test.dart 的源码形状守卫抓出来
        // （本轮实测被抓，改走统一入口）。
        updateNpcAffection(
          effect.targetNpcId!,
          effect.affection,
          reason: '主线剧情',
          quiet: true,
        );
      }
      for (final item in effect.addItems) {
        // 【口径】`addItems` 填的是**物品名**，不是 id。
        // 原因是本项目的背包存的是名字：`itemDefById` 已被删除
        // （见 `item_data.dart:499` 的注释），全项目的物品查找入口是
        // `itemDefByName`。这里跟随既有口径，避免造出第二种语义。
        //
        // 用名字去重（与 `_addItem` 一致）：同名物品玩家只该有一件。
        final def = itemDefByName(item);
        final key = def?.name ?? item;
        if (!p.inventory.any((i) => i.name == key)) {
          p.inventory.add(
            InventoryItem(
              id: def?.id ?? item,
              name: key,
              type: def?.type ?? '剧情',
              description: def?.desc ?? '在主线剧情中获得。',
            ),
          );
        }
      }
    }

    bump('affection', effect.affection);
    bump('reputation', effect.reputation);
    bump('housePoints', effect.housePoints);
    bump('spirit', effect.spirit);
    bump('galleons', effect.galleons);

    final flags = List<String>.from(storyProgress.flags);
    final knowledge = List<String>.from(storyProgress.knowledge);
    for (final f in effect.setFlags) {
      if (!flags.contains(f)) flags.add(f);
    }
    for (final f in effect.clearFlags) {
      flags.remove(f);
    }
    for (final k in effect.addKnowledge) {
      if (!knowledge.contains(k)) knowledge.add(k);
      // 情报同时写进长期记忆的 T0 核心事实层：
      // 离线模式长期记忆几乎空转（唯一写入入口挂在 AI 摘要上），
      // 剧情情报是少数能真正沉淀下来的东西，值得占一个 T0 位。
      memory = memory.addKeyFact(
        KeyFactRecord(
          id: 'story_$k',
          fact: '剧情情报：$k',
          importance: kPersistentFactImportance,
          timestamp: worldState.time.format(),
          category: 'story',
        ),
      );
    }

    storyProgress = storyProgress.copyWith(
      effects: acc,
      flags: flags,
      knowledge: knowledge,
    );

    // ================================================================
    // 与项目各功能系统的接线（v2）
    // ================================================================
    // 放在最后：上面已经把 flags/knowledge 收敛进 storyProgress，这里做的
    // 是"把剧情结论广播给世界"，与 storyProgress 本身无关，顺序上互不影响。
    _routeEffectToWorld(effect);
  }

  /// 把剧情效果广播给长期记忆 / 委托 / 图鉴三个系统。
  ///
  /// 【为什么单独抽一个函数】`applyStoryEffect` 已经很长（数值 + 物品 +
  /// flag + 情报），再接四段接线会把它压垮。这四段的共同点是：
  /// **都只跟 `effect` 与世界态有关，不碰 `storyProgress`**——边界干净，
  /// 可以独立读、独立测。
  ///
  /// 【为什么全部做了容错】内容层会持续增删（现在 100+ 节点，后面还会加），
  /// 写错一个 quest id / cg id 不该让玩家的一回合崩掉。三个系统各自的
  /// 写入口本身也都带幂等去重，重复触发是安全的。
  void _routeEffectToWorld(StoryEffect effect) {
    final p = player;
    if (p == null) return;
    final now = worldState.time.format();

    // ① 悬念：开启。描述按第一个 `|` 切成 id 与正文。
    for (final raw in effect.openLoops) {
      final sep = raw.indexOf('|');
      if (sep <= 0 || sep >= raw.length - 1) continue;
      final id = raw.substring(0, sep).trim();
      final desc = raw.substring(sep + 1).trim();
      if (id.isEmpty || desc.isEmpty) continue;
      memory = memory.addOrUpdateOpenLoop(
        OpenLoopRecord(
          id: id,
          description: desc,
          status: 'open',
          importance: kImportanceStoryEffectLoop,
          openedAt: now,
          openedTurn: turnCount,
          loopType: 'question',
        ),
      );
    }

    // ② 悬念：了结。找不到就静默跳过（内容层改 id 不该崩）。
    for (final id in effect.closeLoops) {
      final idx = memory.openLoops.indexWhere((r) => r.id == id);
      if (idx < 0) continue;
      final old = memory.openLoops[idx];
      if (old.status == 'done') continue;
      memory = memory.addOrUpdateOpenLoop(
        OpenLoopRecord(
          id: old.id,
          description: old.description,
          status: 'done',
          importance: old.importance,
          openedAt: old.openedAt,
          closedAt: now,
          npcIds: old.npcIds,
          loopType: old.loopType,
          openedTurn: old.openedTurn,
        ),
      );
    }

    // ③ 委托：复用 `acceptQuestTemplate` —— 它已经带年级门、去重与
    //    T1「未完结事项」登记（见 mixin_play.dart:1456）。剧情模式只需要
    //    "触发"，不该把那一整套口径重抄一遍（抄一遍就是两处口径，早晚漂）。
    //
    //    【为什么它会在剧情里静默失败】年级不够 / 已接过 / 模板不存在时，
    //    它走 `_finishLocal` 给一句提示。剧情模式下 `commandResult` 会被
    //    本回合的叙事覆盖，提示读不到——但委托**确实没发**，这是正确行为：
    //    内容层把一条超纲委托挂在一年级节点上，本来就该发不出去。
    for (final qid in effect.addQuests) {
      acceptQuestTemplate(qid);
    }

    // ④ 世界大事：写进长期记忆 T3 层，让原著主线跨部留存。
    for (final raw in effect.addWorldEvents) {
      final sep = raw.indexOf('|');
      final title = (sep > 0 ? raw.substring(0, sep) : raw).trim();
      final desc = sep > 0 ? raw.substring(sep + 1).trim() : '';
      if (title.isEmpty) continue;
      memory = memory.addWorldEvent(
        WorldEventRecord(
          id: 'story_$title',
          timestamp: now,
          title: title,
          description: desc.isEmpty ? title : desc,
          importance: effect.worldEventImportance,
          category: 'wizarding',
          location: worldState.currentLocation,
        ),
      );
    }

    // ⑤ 图鉴：解锁 CG（`unlockCG` 内部按 cgRecords 幂等）。
    for (final cgId in effect.unlockCgs) {
      unlockCG(cgById(cgId));
    }
  }

  /// 剧情模式下原著节点的处理。
  ///
  /// 若该步声明了 `canonRefId`，就把它记进 `firedAnchorIds`（防二次触发），
  /// 并清掉 `lastCanonEventTitle`——因为这件事已经由**剧情文本**讲述过了，
  /// 不该再由 `buildFallbackChoices` 生成一条"去打听…"的通用选项。
  void markCanonForStep(StoryStepDef step) {
    final ref = step.canonRefId;
    if (ref == null) return;
    if (!worldState.firedAnchorIds.contains(ref)) {
      worldState.firedAnchorIds.add(ref);
    }
    lastCanonEventTitle = null;
    lastCanonEventDirective = null;
    debugLog('📖 剧情步已讲述原著节点: $ref（${step.id}）');

    // 原著节点 → 长期记忆 / 图鉴。
    //
    // 【为什么在这里而不是在内容层逐条写 effect】
    // `canonRefId` 是"这一步讲述的是哪条原著节点"的**唯一权威声明**，
    // 已经存在、已经被 102 条节点校验过覆盖度。把沉淀挂在这个既有点上，
    // 等于给整条七部曲时间线一次性接上长期记忆，不必改一个字节的剧情步。
    //
    // 【幂等】剧情模式可能重入同一步（读档、跳章开局），但 `markCanonForStep`
    // 上游有 `firedAnchorIds` 语义上的"讲过一次"守卫；即便重入，
    // `addWorldEvent` 按 id 去重、`unlockCG` 按 cgRecords 去重，
    // 三层都是幂等的，不会产生重复记录。
    sinkCanonNodeToMemory(ref);
  }

  /// 把一条原著节点的沉淀物（世界大事 / 悬念开启与了结 / CG）广播出去。
  ///
  /// 节点上三项都是可选的：没填就是"这条节点不产生长期记忆"，
  /// 保持与接线前完全一致的行为。
  void sinkCanonNodeToMemory(String canonId) {
    final node = canonEventById(canonId);
    if (node == null) return;
    final p = player;
    if (p == null) return;

    final worldEvent = node.worldEvent;
    if (worldEvent != null && worldEvent.trim().isNotEmpty) {
      memory = memory.addWorldEvent(
        WorldEventRecord(
          id: 'canon_${node.id}',
          timestamp: worldState.time.format(),
          title: node.title,
          description: worldEvent.trim(),
          importance: node.worldEventImportance,
          category: 'wizarding',
          location: worldState.currentLocation,
        ),
      );
    }

    final open = node.openLoop;
    if (open != null && open.trim().isNotEmpty) {
      final sep = open.indexOf('|');
      if (sep > 0 && sep < open.length - 1) {
        final id = open.substring(0, sep).trim();
        final desc = open.substring(sep + 1).trim();
        if (id.isNotEmpty && desc.isNotEmpty) {
          memory = memory.addOrUpdateOpenLoop(
            OpenLoopRecord(
              id: id,
              description: desc,
              status: 'open',
              importance: kImportanceAiExtractedLoop,
              openedAt: worldState.time.format(),
              openedTurn: turnCount,
              loopType: 'question',
            ),
          );
        }
      }
    }

    // 悬念了结。一条节点可以同时收束多条线索（学年末一次回答好几个问题），
    // 因此 `closeLoops` 是列表。
    //
    // 【为什么找不到就跳过而不报错】节点与悬念分处两张表，改一条悬念 id
    // 不该让玩家的这一回合崩掉；`openLoops` 同理。真正的一致性由
    // `canon_events_test.dart` 的"开过的都要关"静态断言保证，
    // 不需要在运行时兜。
    for (final close in node.closeLoops) {
      final id = close.trim();
      if (id.isEmpty) continue;
      final idx = memory.openLoops.indexWhere((r) => r.id == id);
      if (idx >= 0 && memory.openLoops[idx].status != 'done') {
        final old = memory.openLoops[idx];
        memory = memory.addOrUpdateOpenLoop(
          OpenLoopRecord(
            id: old.id,
            description: old.description,
            status: 'done',
            importance: old.importance,
            openedAt: old.openedAt,
            closedAt: worldState.time.format(),
            npcIds: old.npcIds,
            loopType: old.loopType,
            openedTurn: old.openedTurn,
          ),
        );
      }
    }

    // 学年末：把所有 `offline_loop_*` 一并了结。
    //
    // 【为什么必须在这里收】`offline_loop_*` 是离线摘要为"起了头但还没
    // 下文"的剧情 flag 自动登记的（见 `_digestOfflineLocally`）。但 flag
    // 一旦置位就永远留在 `storyProgress.flags` 里，没有对应的"清除"动作，
    // 于是这些事项**永远关不掉**——实测跑完七部后，玩家的「未完结事项」
    // 面板上挂着二十多条已经翻篇几百天的旧事。学年末节点是全书唯一
    // 可靠的"这一段结束了"信号，在这里收口最合适：既不会提前了一结，
    // 也不会让旧事无限堆积。
    if (node.closeLoops.isNotEmpty) {
      memory = closeStaleOfflineLoops();
    }

    final cg = node.unlockCg;
    if (cg != null && cg.trim().isNotEmpty) {
      unlockCG(cgById(cg.trim()));
    }
  }
}
