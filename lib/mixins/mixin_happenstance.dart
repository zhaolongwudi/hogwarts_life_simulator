/// P10 霍格沃茨奇遇系统：随机发生在「你」身上的小故事，带两段式选择。
///
/// 【它解决什么问题】离线版的「世界在动」已有两个宏观层：月度/学年事件（世界
/// 新闻）与节庆（特别的日子）。但它们都是"世界围绕你发生"——玩家缺一个
/// "事情落到我头上、我说了算"的微观层。奇遇就是那层：没有固定日期，按
/// 季节 + 地点 + 年级过滤、加权抽取、带冷却；触发当回合给出 2~4 个「你打算
/// 怎么做」，下一回合选定后结算不同结局（奖励 / 声望 / 好感 / 物品）。
///
/// 数据全在 `happenstance_data.dart`，本 mixin 只做三层事：
///   ① 过滤 & 抽取（`maybeTriggerHappenstance`）；
///   ② 选择结算（`tryResolveHappenstanceChoice`，action 带 `奇遇:` 前缀）；
///   ③ 兜底（若有未决奇遇、玩家下回合却做了别的事，自动按中性结局收尾）。
library;

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/happenstance_data.dart';
import '../data/house_data.dart';
import '../data/item_data.dart';
import '../models/game_systems.dart';
import '../models/player.dart';
import '../providers/game_provider_base.dart';

/// 奇遇动作前缀：触发回合为每个选项生成 `奇遇:<id>:<idx>` 的动作，
/// 结算回合据此精确命中（不依赖本地化文本模糊匹配）。
const String kHappenstanceActionPrefix = '奇遇:';

/// 两次奇遇触发之间的最小间隔（回合）。避免玩家被奇遇追着跑。
const int kHappenstanceSpacingTurns = 6;

/// P10 奇遇 mixin。挂在 [GameProviderBase] 上。
mixin GameHappenstanceMixin on GameProviderBase {
  bool get _happenstanceOn => appProvider.happenstanceEnabled;

  /// 是否有进行中的未结算奇遇。
  bool get hasPendingHappenstance =>
      worldState.pendingHappenstanceId != null;

  /// 对当前世界（季节/地点/年级）可用的奇遇候选。
  @visibleForTesting
  List<HappenstanceDef> eligibleHappenstances({List<String>? seasons}) {
    final ws = worldState;
    final season = (seasons ?? seasonTagsForMonth(ws.time.month));
    final location = ws.currentLocation ?? '';
    final grade = player?.grade ?? 1;
    return kHappenstances.where((h) {
      if (h.minGrade > grade) return false;
      if (h.locationKeys.isNotEmpty && !h.locationKeys.any(location.contains)) {
        return false;
      }
      if (h.seasonTags.isNotEmpty && !h.seasonTags.any(season.contains)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// 命中一「场」奇遇：启用中、无进行中奇遇、冷却已过、且抽中（加权 × 概率）。
  /// 纯函数式，[seed] 默认 [turnCount]，同一回合重放一致。返回空 = 本回合不触发。
  @visibleForTesting
  HappenstanceDef? happenstanceDueToday({int? seed}) {
    if (!_happenstanceOn) return null;
    final ws = worldState;
    if (ws.pendingHappenstanceId != null) return null; // 已有进行中，不再叠
    if (turnCount - ws.lastHappenstanceTurn < kHappenstanceSpacingTurns) {
      return null;
    }
    final pool = eligibleHappenstances();
    if (pool.isEmpty) return null;
    final rnd = Random(seed ?? turnCount);
    final totalWeight = pool.fold<int>(0, (s, h) => s + h.weight);
    var roll = rnd.nextInt(totalWeight);
    HappenstanceDef? picked;
    for (final h in pool) {
      roll -= h.weight;
      if (roll < 0) {
        picked = h;
        break;
      }
    }
    picked ??= pool.last;
    // 按奇遇自身的基础概率再判定一次触发
    if (rnd.nextDouble() > picked.baseChance) return null;
    return picked;
  }

  /// 触发一「场」奇遇：置 pending、写死专属选项。返回需要追加进叙事的场景文块；
  /// 未触发返回空串。触发后 [worldState.pendingHappenstanceId] 与
  /// [worldState.lastHappenstanceTurn] 即为本轮状态，便于下回合/存档接续。
  String triggerHappenstance({int? seed}) {
    final h = happenstanceDueToday(seed: seed);
    if (h == null) return '';
    worldState.pendingHappenstanceId = h.id;
    worldState.lastHappenstanceTurn = turnCount;
    final house = houseDisplayName(player?.house ?? '', fallback: '霍格沃茨');
    final block = StringBuffer();
    block.writeln('———————✨ 奇遇 · ${h.title} ✨———————');
    block.writeln(fillHappenstanceText(h.scene, house: house));
    final text = block.toString().trim();
    return text;
  }

  /// 生成本回合奇遇专属选项（供触发回合覆写兜底选项）。
  List<GameChoice> happenstanceChoicesForPending() {
    final id = worldState.pendingHappenstanceId;
    final h = id == null ? null : happenstanceById(id);
    if (h == null) return const [];
    return List<GameChoice>.generate(h.outcomes.length, (i) {
      return GameChoice(text: h.outcomes[i].title, action: '$kHappenstanceActionPrefix$id:$i');
    });
  }

  /// 结算一场进行中的奇遇。action 形如 `奇遇:<id>:<idx>` 时精确结算对应选项；
  /// 若 pending 存在、但玩家本回合做了别的事，则按该奇遇的「中性兜底选项」
  /// （取中间项）收尾，避免奇遇永远悬着。返回需要追加进叙事的结局文块；无
  /// pending 时返回空串。
  String tryResolveHappenstanceChoice(String action, {int? seed}) {
    final pendingId = worldState.pendingHappenstanceId;
    if (pendingId == null) return '';
    final h = happenstanceById(pendingId);
    if (h == null) {
      worldState.pendingHappenstanceId = null;
      return '';
    }
    // 解析玩家动作 → 选项下标（缺省视为未选，走中性兜底）。
    int? index;
    if (action.startsWith(kHappenstanceActionPrefix)) {
      final parts = action.split(':');
      if (parts.length >= 3 && parts[1] == h.id) {
        index = int.tryParse(parts[2]);
        if (index != null && (index < 0 || index >= h.outcomes.length)) {
          index = null;
        }
      }
    }
    index ??= h.outcomes.length ~/ 2; // 中性兜底：中间项
    final outcome = h.outcomes[index];
    _applyHappenstanceEffect(h, outcome);

    worldState.pendingHappenstanceId = null;

    final house = houseDisplayName(player?.house ?? '', fallback: '霍格沃茨');
    final buf = StringBuffer();
    buf.writeln('———————✨ ${h.title} ✨———————');
    buf.writeln('【你的选择】${outcome.title}');
    buf.writeln(fillHappenstanceText(outcome.text, house: house));
    final notes = _effectNotes(h, outcome);
    if (notes.isNotEmpty) {
      buf.writeln();
      buf.writeln('（这场奇遇，你带走了${notes.join('、')}）');
    }
    // P17 奇遇结果沉淀：结算完成即写入「人生回忆」事件流（/档案 回忆 可回看），
    // 让奇遇不再是一次性数值——它是这段人生里真正发生过的一段切片。
    worldState.addNarrativeEvent(
      '✨ 奇遇「${h.title}」：${outcome.title}'
      '${notes.isNotEmpty ? '（带走${notes.join('、')}）' : ''}',
      turn: turnCount,
    );
    return buf.toString().trim();
  }

  void _applyHappenstanceEffect(HappenstanceDef h, HappenstanceOutcomeDef o) {
    final p = player;
    if (p == null) return;
    final e = o.effect;
    if (e.reputationDim != null && e.reputationValue != 0) {
      p.playerReputation.add(e.reputationDim!, e.reputationValue);
    }
    if (e.housePoints > 0) {
      addHouseCupPoints(e.housePoints, '奇遇·${h.title}');
    }
    if (e.galleons > 0) {
      p.galleons += e.galleons;
    }
    if (e.npcAffection != 0 && e.npcId != null) {
      updateNpcAffection(e.npcId!, e.npcAffection, reason: '奇遇·${h.title}', quiet: true);
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
    }
  }

  List<String> _effectNotes(HappenstanceDef h, HappenstanceOutcomeDef o) {
    final p = player;
    if (p == null) return const [];
    final e = o.effect;
    final notes = <String>[];
    if (e.reputationDim != null && e.reputationValue != 0) {
      notes.add('${p.playerReputation.labelOf(e.reputationDim!)} +${e.reputationValue}');
    }
    if (e.housePoints > 0) notes.add('学院杯积分 +${e.housePoints}');
    if (e.galleons > 0) notes.add('${e.galleons} 加隆');
    if (e.npcAffection != 0 && e.npcId != null) {
      notes.add('与${npcRegistry[e.npcId]?.name ?? e.npcId}好感 +${e.npcAffection}');
    }
    if (e.itemName != null && e.itemName!.isNotEmpty) notes.add(e.itemName!);
    return notes;
  }
}

/// 月份 → 季节标签（与月度事件池同口径，避免这里另写一套）。
List<String> seasonTagsForMonth(int month) {
  if (month >= 3 && month <= 5) return const ['spring'];
  if (month >= 6 && month <= 8) return const ['summer'];
  if (month >= 9 && month <= 11) return const ['autumn'];
  return const ['winter'];
}