/// P9 霍格沃茨年度节庆系统：日期触发、每学年只庆祝一次的固定日历事件。
///
/// 【它解决什么问题】离线版的「世界在动」此前由月度事件 + 原著时间线支撑，
/// 两者都偏「世界大事」，玩家没有「今天是个特别日子」的参与感。节庆是一套
/// 按日期命中的**可参与**事件：10月31 满城堡都是万圣节，当天走进离线回合，
/// 叙事里就会多出一段节庆，并附上一次真实的奖励结算。
///
/// 【设计】
///  - 纯本地 0 AI：只查日期 + 抽一种庆祝方式，随机用 `turnCount` 播种，确定可测；
///  - 每学年去重：`festivalCelebratedAt`（节日 id → 学年名）保证同一天只庆祝一次，
///    跨学年后同一节日还能再庆祝（元旦等落在学期内的节日按学年去重），
///    避免「同一个万圣节反复刷奖励」；
///  - 接线范围：只在 `_runOfflineQuickTurn` 的世界事件段调用；AI 路径一个字节不碰。
library;

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/festival_data.dart';
import '../data/house_data.dart';
import '../data/item_data.dart';
import '../models/player.dart';
import '../providers/game_provider_base.dart';

/// P9 节庆 mixin。挂在 [GameProviderBase] 上。
mixin GameFestivalMixin on GameProviderBase {
  /// 命中今天日期（纯函数式，含已庆祝判定）。
  @visibleForTesting
  FestivalDef? festivalDueToday() {
    final f = festivalForDate(worldState.time.month, worldState.time.day);
    if (f == null) return null;
    if (hasCelebratedFestival(f)) return null;
    return f;
  }

  /// 本学年是否已经庆祝过该节日。
  bool hasCelebratedFestival(FestivalDef f) =>
      worldState.festivalCelebratedAt[f.id] == worldState.academicYear;

  /// 结算一场节庆：选庆祝方式 → 结算奖励 → 记为已庆祝。
  /// 返回需要追加进叙事的一段节庆文块；当天没有可庆祝的节庆时返回空串。
  /// [seed] 决定抽到哪种庆祝方式，默认用 [turnCount]，同一回合重放结果一致。
  @override
  String celebrateFestival({int? seed}) {
    final f = festivalDueToday();
    if (f == null) return '';
    final p = player;
    if (p == null) return '';

    final house = houseDisplayName(p.house, fallback: '霍格沃茨');
    final rnd = Random(seed ?? turnCount);
    final outcome = f.outcomes[rnd.nextInt(f.outcomes.length)];
    final e = outcome.effect;

    final rewards = <String>[];
    if (e.reputationDim != null && e.reputationValue != 0) {
      p.playerReputation.add(e.reputationDim!, e.reputationValue);
      rewards.add('${p.playerReputation.labelOf(e.reputationDim!)} +${e.reputationValue}');
    }
    if (e.housePoints > 0) {
      addHouseCupPoints(e.housePoints, '节庆·${f.name}');
      rewards.add('学院杯积分 +${e.housePoints}');
    }
    if (e.galleons > 0) {
      p.galleons += e.galleons;
      rewards.add('${e.galleons} 加隆');
    }
    if (e.npcAffection != 0 && e.npcId != null) {
      updateNpcAffection(e.npcId!, e.npcAffection, reason: '节庆·${f.name}', quiet: true);
      rewards.add('与${npcRegistry[e.npcId]?.name ?? e.npcId}好感 +${e.npcAffection}');
    }
    if (e.energy > 0) {
      p.energy = (p.energy - e.energy).clamp(0, 100);
    }
    if (e.itemName != null && e.itemName!.isNotEmpty) {
      final existed = p.inventory.any((x) => x.name == e.itemName);
      if (!existed) {
        final def = itemDefByName(e.itemName!);
        p.inventory.add(InventoryItem(
          id: def?.id ?? e.itemName!,
          name: e.itemName!,
          type: def?.type ?? 'item',
          description: def?.desc ?? '',
        ));
      }
      rewards.add(e.itemName!);
    }

    worldState.festivalCelebratedAt[f.id] = worldState.academicYear;

    final buf = StringBuffer();
    buf.writeln();
    buf.writeln('———————🕯️ ${f.dateLabel} · ${f.name} 🕯️———————');
    buf.writeln(fillFestivalText(f.intro, house: house));
    buf.writeln();
    buf.writeln('【$house · 你选择了】${outcome.title}');
    buf.writeln(fillFestivalText(outcome.text, house: house));
    if (rewards.isNotEmpty) {
      buf.writeln();
      buf.writeln('（${f.name}的收获：${rewards.join('、')}）');
    }

    final blockText = buf.toString();
    worldState.addNarrativeEvent(blockText.trim(), turn: turnCount);
    return blockText;
  }
}