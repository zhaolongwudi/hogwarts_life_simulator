/// 玩法通用工具（r6-2 拆分自 mixin_play.dart）。
///
/// 【为什么独立】`mixin_play` 的物品/咒语/宠物与竞技玩法（魁地奇/决斗/
/// 魔药部/快讯社）都要用这组本地结算工具（finishLocal / 加删物品 /
/// 属性读取 / 战力评估 / 待结算死因 / 决斗战绩）。拆出竞技块后两组件
/// 共用，提为独立 mixin：`GamePlayArenaMixin on GamePlayToolsMixin`、
/// `GamePlayMixin on GamePlayToolsMixin, GamePlayArenaMixin`（on 链单向，
/// 遵守 ADR-001）。本文件零 AI 调用。
library;

import '../data/attribute_data.dart';
import '../data/item_data.dart';
import '../data/wand_data.dart';
import 'dart:async';
import '../models/game_systems.dart';
import '../models/player.dart';
import '../providers/game_provider_base.dart';

mixin GamePlayToolsMixin on GameProviderBase {
  /// 最近一次伤害结算可能致死的候选死因；finishLocal 统一检查。
  String pendingDeathCause = '';

  /// 已被击败过的 NPC id（打赢只加一次好感，避免反复刷同一个对手）
  final Set<String> duelBeatenNpcIds = {};

  // ==================== 通用工具 ====================

  void finishLocal(String narrative) {
    currentNarrative = narrative;
    choices = [GameChoice(text: '返回', action: '继续')];
    // 本地结算路径的致命伤害在这里统一判定（会覆写为死亡终章）
    if (pendingDeathCause.isNotEmpty) {
      final cause = pendingDeathCause;
      pendingDeathCause = '';
      checkPlayerDeath(cause);
    }
    notifyListeners();
    unawaited(autoSave());
  }

  bool hasItem(String name) =>
      (player?.inventory ?? []).any((e) => e.name == name);

  void removeItem(String name) {
    final inv = player?.inventory;
    if (inv == null) return;
    final idx = inv.indexWhere((e) => e.name == name);
    if (idx >= 0) inv.removeAt(idx);
  }

  void addItem(String name, {String? type, String? desc}) {
    final def = itemDefByName(name);
    player!.inventory.add(
      InventoryItem(
        id: def?.id ?? name,
        name: name,
        type: type ?? def?.type ?? 'item',
        description: desc ?? def?.desc ?? '',
      ),
    );
  }

  /// 获得一件物品并自动推进 gather 类委托
  void gainItem(String name) {
    addItem(name);
    progressQuest('gather', name, 1);
  }

  // 走 effectiveAttr 而不是直接读 attributes：
  // 身上有疤的话，这两个数是不一样的，而判定该用带疤的那个。
  int attr(String key) => effectiveAttr(key);

  String attrLabelZh(String key) => attributeLabel(key);

  /// 装备加成走 lib/data/item_data.dart 的纯函数——装备页显示的数字和
  /// 打决斗实际用的必须是同一个算法。
  int equipmentCombatBonus() =>
      player == null ? 0 : equippedCombatBonus(player!.equipped);

  int equipmentCastBonus() =>
      player == null ? 0 : equippedCastBonus(player!.equipped);

  /// 决斗战力：技能熟练度均值 + 装备加成 + 宠物助战（羁绊≥40）+ 杖芯倾向
  double playerPower() {
    final p = player!;
    final base =
        (attr('dda') + attr('spell_understanding') + attr('magic_control')) /
        3;
    var power = base + equipmentCombatBonus();
    if (p.petBond >= 40) power += 3;
    // 龙心脏腱索打中更疼，凤凰羽毛略微加成，独角兽毛不加威力
    final core = wandById(p.wandId ?? '')?.core;
    power *= 1 + wandCorePowerBonusFor(core);
    return power;
  }

  void progressQuest(String type, String target, int amount) {
    final qs = player?.quests;
    if (qs == null) return;
    for (final q in qs) {
      if (q.status != 'active' || q.type != type || q.target != target) {
        continue;
      }
      q.progress = (q.progress + amount).clamp(0, q.targetCount);
      if (q.isDone) {
        q.status = 'completed';
        notifications.add('📜 委托完成：${q.title}（/委托 交付 领取奖励）');
      }
    }
  }
}
