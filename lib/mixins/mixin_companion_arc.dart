/// P11 羁绊小剧场系统：与亲近之人之间的一场跨多回合小戏，靠好感解锁。
///
/// 【它解决什么问题】离线版的「世界在动」已有四个层：月度/学年事件（世界
/// 新闻）、节庆（特别的日子）、奇遇（随机落在你身上的小事）。本层补上的是
/// **"关系的分量"**——你对一个人的好感，不该只有一排会涨的数字，而该在
/// 情分到了的时候，真的演出一场戏来。好感推进（前幕自动演）、情分升温、
/// 最终幕留一次抉择，演完归宿。
///
/// 数据全在 `companion_arc_data.dart`；本 mixin 只做三层事：
///   ① 选人开演 & 推进（`maybeTriggerCompanion`）；
///   ② 最终幕抉择（`tryResolveCompanionChoice`，action 带 `羁绊:` 前缀）；
///   ③ 兜底（有进行中的最终幕而玩家做了别的事，自动按第一结局收尾）。
library;

import 'package:flutter/foundation.dart';

import '../data/companion_arc_data.dart';
import '../data/house_data.dart';
import '../data/item_data.dart';
import '../models/companion_arc.dart';
import '../models/game_systems.dart';
import '../models/player.dart';
import '../providers/game_provider_base.dart';

/// 羁绊最终幕抉择前缀：`羁绊:<arcId>:<idx>`。
const String kCompanionArcActionPrefix = '羁绊:';

/// 两幕之间（及开演后）的最小间隔（回合），让戏像现实一样慢慢演，别刷屏。
const int kCompanionArcSpacingTurns = 4;

/// P11 羁绊小剧场 mixin。挂在 [GameProviderBase] 上。
mixin GameCompanionArcMixin on GameProviderBase {
  bool get _companionOn => appProvider.companionArcEnabled;

  /// 当前是否有一场最终幕正等你做抉择。
  @override
  bool get hasPendingCompanionClimax => companionProgress.values.any(
        (p) => p.pendingClimax,
      );

  /// 按 npcId 索引的羁绊进度（直接读写 worldState.companionArcs）。
  Map<String, CompanionArcProgress> get companionProgress =>
      worldState.companionArcs;

  CompanionArcProgress _progressFor(String npcId) =>
      companionProgress[npcId] ?? const CompanionArcProgress();

  /// 对当前世界（季节）可开演、且好感/年级门槛已满足、这位 NPC 还没演完的小剧场。
  /// 作用是「该轮到谁开一场新戏」的候选集，决策权重用 [weight] + 好感排序。
  @visibleForTesting
  List<CompanionArcDef> eligibleCompanionArcsToStart({List<String>? seasons}) {
    final ws = worldState;
    final season = (seasons ?? companionSeasonTagsForMonth(ws.time.month));
    final grade = player?.grade ?? 1;
    final list = <CompanionArcDef>[];
    for (final arc in kCompanionArcs) {
      if (arc.minGrade > grade) continue;
      if (arc.seasonTags.isNotEmpty && !arc.seasonTags.any(season.contains)) {
        continue;
      }
      final npcName = npcRegistry[arc.npcId];
      if (npcName == null) continue; // 该 NPC 尚未登场/不存在
      if (npcName.affection < arc.startAffection) continue;
      final p = _progressFor(arc.npcId);
      if (p.completed) continue; // 演完归宿
      if (p.arcId != null) continue; // 已有在演/待抉择的弧
      list.add(arc);
    }
    return list;
  }

  /// 命中一「位」要开演/推进的 NPC 的桥接对象：要么继续演在场的那场中段
  /// 戏，要么新开一场（好感最高的优先）。返回 {arcId, beatIndex, npcId}；
  /// 无条件为 null = 本回合无事可演。
  ({String arcId, int beatIndex, String npcId})? _nextPlaynable() {
    if (!_companionOn) return null;
    final ws = worldState;
    // 已有最终幕待抉择 → 停住，等玩家（本回合不再开新的推进）
    if (hasPendingCompanionClimax) return null;
    // 有进行中的奇遇 → 等奇遇先讲完，避免两件事抢戏
    if (hasPendingHappenstance) return null;
    final turn = turnCount;
    if (turn - ws.lastCompanionArcTurn < kCompanionArcSpacingTurns) return null;

    // 1) 优先推进已在演的中段戏
    for (final entry in companionProgress.entries) {
      final p = entry.value;
      if (p.arcId == null || p.completed || p.pendingClimax) continue;
      final def = companionArcById(p.arcId!);
      if (def == null) continue;
      if (p.beatIndex >= def.beats.length) continue; // 已全部播完（异常态）
      return (arcId: def.id, beatIndex: p.beatIndex, npcId: entry.key);
    }

    // 2) 否则新开一场：好感越高的越优先
    final candidates = eligibleCompanionArcsToStart();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final diff = (npcRegistry[b.npcId]?.affection ?? 0) -
          (npcRegistry[a.npcId]?.affection ?? 0);
      if (diff != 0) return diff;
      return b.weight - a.weight;
    });
    final arc = candidates.first;
    return (arcId: arc.id, beatIndex: 0, npcId: arc.npcId);
  }

  /// 推进并返回本回合要追加进叙事的场景文块（开演中段戏 / 新开一场都走这）。
  /// 无法触发返回空串。最终幕的事故（`isClimax`）本回合只「播场景 + 记待抉择」，
  /// 不结算；结算在下一回合的 [tryResolveCompanionChoice]。
  @override
  String maybeTriggerCompanion() {
    final play = _nextPlaynable();
    if (play == null) return '';
    final def = companionArcById(play.arcId)!;
    final beat = def.beats[play.beatIndex];

    final progress = _progressFor(play.npcId).copyWith(
      arcId: def.id,
      pendingClimax: beat.isClimax,
    );
    if (!beat.isClimax) {
      // 中段幕：推进到位，下幕指向下一位
      worldState.companionArcs[play.npcId] = progress.copyWith(
        beatIndex: play.beatIndex + 1,
      );
      _applyEffect(def, beat.effect);
    } else {
      // 最终幕：停住等抉择，beatIndex 仍指向这一幕，供抉择时解析结局
      worldState.companionArcs[play.npcId] = progress.copyWith(
        beatIndex: play.beatIndex,
      );
    }
    worldState.lastCompanionArcTurn = turnCount;

    final house = houseDisplayName(player?.house ?? '', fallback: '霍格沃茨');
    final npcName = npcRegistry[play.npcId]?.name ?? play.npcId;
    final buf = StringBuffer();
    buf.writeln('———————💞 羁绊 · ${def.title}（与$npcName）💞———————');
    buf.writeln(fillCompanionArcText(beat.scene, house: house));
    return buf.toString().trim();
  }

  /// 当前待抉择最终幕的抉择选项（供触发回合覆写兜底承接选项）。无则空。
  @override
  List<GameChoice> companionChoicesForPending() {
    for (final entry in companionProgress.entries) {
      final p = entry.value;
      if (!p.pendingClimax || p.arcId == null) continue;
      final def = companionArcById(p.arcId!);
      if (def == null || p.beatIndex >= def.beats.length) continue;
      final beat = def.beats[p.beatIndex];
      return List<GameChoice>.generate(beat.outcomeTitles.length, (i) {
        return GameChoice(
          text: beat.outcomeTitles[i],
          action: '$kCompanionArcActionPrefix${def.id}:$i',
        );
      });
    }
    return const [];
  }

  /// 结算一场待抉择的最终幕。action 形如 `羁绊:<arcId>:<idx>` 时精确结算；
  /// 若有待抉择但玩家本回合做了别的事，则按第一结局收尾（不悬挂）。返回需要
  /// 追加进叙事的结局文块；无待抉择返回空串。
  @override
  String tryResolveCompanionChoice(String action) {
    // 找出待抉择的地方
    String? arcId;
    int beatIndex = 0;
    for (final entry in companionProgress.entries) {
      final p = entry.value;
      if (p.pendingClimax && p.arcId != null) {
        arcId = p.arcId;
        beatIndex = p.beatIndex;
        break;
      }
    }
    if (arcId == null) return '';
    final def = companionArcById(arcId);
    if (def == null || beatIndex >= def.beats.length) {
      // 异常态：清掉待抉择，防悬挂
      companionProgress.removeWhere((_, p) => p.pendingClimax);
      return '';
    }
    final beat = def.beats[beatIndex];

    // 解析玩家动作 → 结局下标（缺省/不匹配 → 第一结局兜底）。
    int idx = 0;
    if (action.startsWith(kCompanionArcActionPrefix)) {
      final parts = action.split(':');
      if (parts.length >= 3 && parts[1] == def.id) {
        final v = int.tryParse(parts[2]);
        if (v != null && v >= 0 && v < beat.outcomeTitles.length) idx = v;
      }
    }
    final outcomeText = idx < beat.outcomeTexts.length ? beat.outcomeTexts[idx] : '';
    final outcomeEffect =
        idx < beat.outcomeEffects.length ? beat.outcomeEffects[idx] : null;
    _applyEffect(def, outcomeEffect);
    _recordCompleted(def.npcId);

    final house = houseDisplayName(player?.house ?? '', fallback: '霍格沃茨');
    final npcName = npcRegistry[def.npcId]?.name ?? def.npcId;
    final buf = StringBuffer();
    buf.writeln('———————💞 ${def.title}（与$npcName）💞———————');
    buf.writeln('【你的选择】${beat.outcomeTitles[idx]}');
    if (outcomeText.isNotEmpty) {
      buf.writeln(fillCompanionArcText(outcomeText, house: house));
    }
    final notes = _effectNotes(def, outcomeEffect);
    if (notes.isNotEmpty) {
      buf.writeln();
      buf.writeln('（这段羁绊，你记下了${notes.join('、')}）');
    }
    return buf.toString().trim();
  }

  void _recordCompleted(String npcId) {
    final cur = _progressFor(npcId);
    companionProgress[npcId] = cur.copyWith(
      pendingClimax: false,
      completed: true,
    );
  }

  void _applyEffect(CompanionArcDef def, CompanionArcEffectDef? e) {
    if (e == null) return;
    final p = player;
    if (p == null) return;
    if (e.reputationDim != null && e.reputationValue != 0) {
      p.playerReputation.add(e.reputationDim!, e.reputationValue);
    }
    if (e.housePoints > 0) {
      addHouseCupPoints(e.housePoints, '羁绊·${def.title}');
    }
    if (e.galleons > 0) {
      p.galleons += e.galleons;
    }
    if (e.npcAffection != 0) {
      updateNpcAffection(def.npcId, e.npcAffection,
          reason: '羁绊·${def.title}', quiet: true);
    }
    if (e.energy > 0) {
      p.energy = (p.energy - e.energy).clamp(0, 100);
    }
    if (e.itemName != null && e.itemName!.isNotEmpty) {
      final existed = p.inventory.any((x) => x.name == e.itemName);
      if (!existed) {
        final itemDef = itemDefByName(e.itemName!);
        p.inventory.add(InventoryItem(
          id: itemDef?.id ?? e.itemName!,
          name: e.itemName!,
          type: itemDef?.type ?? 'item',
          description: itemDef?.desc ?? '',
        ));
      }
    }
  }

  List<String> _effectNotes(CompanionArcDef def, CompanionArcEffectDef? e) {
    final p = player;
    if (p == null || e == null) return const [];
    final notes = <String>[];
    if (e.reputationDim != null && e.reputationValue != 0) {
      notes.add('${p.playerReputation.labelOf(e.reputationDim!)} +${e.reputationValue}');
    }
    if (e.housePoints > 0) notes.add('学院杯积分 +${e.housePoints}');
    if (e.galleons > 0) notes.add('${e.galleons} 加隆');
    if (e.npcAffection != 0) {
      notes.add('与${npcRegistry[def.npcId]?.name ?? def.npcId}好感 +${e.npcAffection}');
    }
    if (e.itemName != null && e.itemName!.isNotEmpty) notes.add(e.itemName!);
    return notes;
  }
}

/// 月份 → 季节标签（与奇遇同口径）。
List<String> companionSeasonTagsForMonth(int month) {
  if (month >= 3 && month <= 5) return const ['spring'];
  if (month >= 6 && month <= 8) return const ['summer'];
  if (month >= 9 && month <= 11) return const ['autumn'];
  return const ['winter'];
}