/// P6 本地行动后果引擎：让离线回合「做了的事有结果」。
///
/// 【它解决什么问题】离线模式（`_runOfflineQuickTurn`）的叙事与选项此前都是
/// 纯文字——地点氛围句 + 承接式选项。玩家选「去图书馆自习」、选「练咒语」，
/// 世界只有时间在走、资源被 `updateNPCsFromAction` 静默扣一点，**没有任何
/// 可见的成长反馈**：属性不涨、NPC 好感不动、探索找不到东西。长局玩下来
/// 像在原地打转——这是离线模式最伤「好玩」的一点。
///
/// 【做法】在离线回合叙事成型后，用纯本地的关键词引擎把玩家本回合的行动
/// 归到 学习 / 练咒 / 运动 / 打工 / 探索 / 休息 / 社交 等类别，逐类结算
/// **真实、可见**的后果：
///   · 学习 → 对应属性 +N，精力消耗；
///   · 练咒 → 魔力控制/魔咒理解 +N，魔力消耗；
///   · 运动 → 飞行/反应 +N、魁地奇技巧 +1，精力大幅消耗；
///   · 打工 → 加隆 +N，精力消耗；
///   · 探索 → 按 seed 掷骰：找到加隆 / 捡到物品 / 只挖到氛围句；
///   · 休息 → 精神力/饱食回复（精力恢复由既有系统负责，不重复结算）；
///   · 社交（行动里出现已登场 NPC 名字）→ 好感 +N，与主类别**叠加**。
/// 所有后果以「【行动结果】…」的段落**追加进本回合叙事**，玩家一眼就能
/// 看到「我做了什么 → 世界怎么回应」。
///
/// 【红线】0 AI。整个引擎只做关键词 contains + 表驱动数值，零网络零 Key。
/// 随机性全部用 `turnCount` 播种的确定性 RNG，同一回合重放结果一致，单测
/// 也据此稳定。
///
/// 【接线范围】只在 `_runOfflineQuickTurn` 的沙盒路径调用；剧情模式
/// （`_runStoryTurn`）与 AI 正式路径一个字节都不碰。
library;

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/attribute_data.dart';
import '../data/item_data.dart';
import '../models/npc.dart';
import '../models/player.dart';
import '../narrative/offline_consequence_types.dart';
import '../providers/game_provider_base.dart';

/// 主类别 → 属性成长池（回合内随机取一个，避免同一类别永远涨同一项）。
const Map<OfflineActivity, List<String>> _activityAttrPool = {
  OfflineActivity.study: ['spell_understanding', 'theory', 'potions'],
  OfflineActivity.practice: ['magic_control', 'spell_understanding'],
  OfflineActivity.sport: ['flying', 'reaction_time'],
};

/// 探索可能捡到的「小宝藏」物品池（都在 item_data 里有定义，可正常入库）。
const List<String> _discoveryItems = [
  '巧克力蛙',
  '比比多味豆',
  '坩埚蛋糕',
  '南瓜馅饼',
  '黄油啤酒',
];

/// 探索骰到「氛围句」时，按地点给更有味道的发现；没有专属就落通用句。
const Map<String, String> _exploreFlavors = {
  '禁林': '你拨开一丛灌木，发现几枚发着微光的蛋壳，刚想细看就碎成了粉末。',
  '图书馆': '你在书架夹层里摸到一张写着旧批注的羊皮纸，落款是一个陌生的缩写。',
  '礼堂': '你在一张长桌底下捡到一枚被遗忘的徽章，边缘已经磨得发亮。',
  '温室': '你在花盆底下发现一株会偷偷挪位置的小幼苗，正往阳光的方向爬。',
  '塔楼': '你在窗台的缝隙里找到一个装着星图的铜盒，打开时发出轻轻的咔哒声。',
  '黑湖': '你蹲在岸边拨开浮萍，看到一枚螺壳，里面竟盛着一滴会发光的湖水。',
};

const String _genericExploreFlavor =
    '你随手翻了翻附近，没找到什么值钱的东西，倒是记住了几处平时不会注意的细节。';

/// P6 后果引擎 mixin。
///
/// 挂在 [GameProviderBase] 上：读取 player / npcRegistry / worldState /
/// turnCount / notifications，结算后由调用方负责把行拼进叙事。
mixin GameOfflineConsequenceMixin on GameProviderBase {
  /// 把一句行动文本归类到主类别（纯函数，单测直接钉）。
  ///
  /// 优先级：休息 > 打工 > 学习 > 练咒 > 运动 > 探索 > 社交。
  /// 社交不参与优先级竞争——它是**叠加项**，由 `_matchedNpc` 单独判定。
  @visibleForTesting
  static OfflineActivity classifyActivity(String action) {
    final a = action.trim();
    if (a.isEmpty) return OfflineActivity.none;

    // 休息：注意「休息日」「休息室」这类词不算休息动作。
    if (_containsAny(a, ['睡觉', '小憩', '打盹', '躺下', '回房睡', '休息一会', '歇一会', '闭目养神'])) {
      return OfflineActivity.rest;
    }
    if (_containsAny(a, ['打工', '兼职', '干活', '帮忙干活', '赚零花', '帮工'])) {
      return OfflineActivity.work;
    }
    if (_containsAny(a, [
      '学习', '自习', '看书', '阅读', '复习', '温习', '做作业', '写作业',
      '背书', '查阅', '图书馆', '上课', '查资料',
    ])) {
      return OfflineActivity.study;
    }
    if (_containsAny(a, [
      '练习咒语', '练咒', '施法', '挥动魔杖', '练习魔咒', '训练魔法',
      '练习变形', '练魔药', '试炼咒', '练习',
    ])) {
      return OfflineActivity.practice;
    }
    if (_containsAny(a, [
      '魁地奇', '打球', '跑步', '锻炼', '运动', '骑车', '踢球', '追球', '练球',
    ])) {
      return OfflineActivity.sport;
    }
    if (_containsAny(a, [
      '探索', '转转', '逛逛', '寻找', '找找', '翻找', '搜查', '搜索',
      '四处', '溜达', '翻箱倒柜', '查看周围', '看看周围',
    ])) {
      return OfflineActivity.explore;
    }
    return OfflineActivity.none;
  }

  /// 从行动文本里抓出第一个「已登场 NPC」（按名字匹配，按 registry 长度
  /// 天然稳定）。没提到任何 NPC 返回 null。社交只对**已认识**的人结算
  /// 好感——行动里冒出一个从没见过的人名，不硬加好感。
  @visibleForTesting
  NPC? matchedNpcForAction(String action) {
    if (action.trim().isEmpty) return null;
    for (final npc in npcRegistry.values) {
      if (npc.name.isEmpty) continue;
      if (action.contains(npc.name)) {
        return npc.introduced ? npc : null;
      }
    }
    return null;
  }

  /// 测试入口：直接结算一句行动，返回结果（不写叙事/通知）。
  @visibleForTesting
  OfflineConsequenceResult offlineConsequencesForTest(
    String action, {
    int? seed,
  }) {
    return settleOfflineConsequences(action, seed: seed ?? turnCount);
  }

  /// 结算本回合行动的全部后果（写入 player / npcRegistry 状态），返回
  /// 需要展示的文本行与通知行。
  ///
  /// 【为什么是 public】触发方在 `GameNarrativeMixin._runOfflineQuickTurn`，
  /// 实现在本 mixin。Dart 的 mixin 私有成员跨 mixin 不可见（同一批
  /// `buildFallbackChoices` 踩过的坑），因此方法对外可见、但只在离线回合
  /// 内部调用，AI 路径不会走到。
  @override
  OfflineConsequenceResult settleOfflineConsequences(String action,
      {int? seed}) {
    final p = player;
    if (p == null) return OfflineConsequenceResult.empty;

    final activity = classifyActivity(action);
    final npc = matchedNpcForAction(action);
    if (activity == OfflineActivity.none && npc == null) {
      return OfflineConsequenceResult.empty;
    }

    // 确定性 RNG：同回合（同 seed）重放结果一致。
    final rnd = Random(seed ?? turnCount);
    final lines = <String>[];
    final notes = <String>[];

    // ---- 主类别结算 ----
    switch (activity) {
      case OfflineActivity.study:
        final key = _activityAttrPool[OfflineActivity.study]![
            rnd.nextInt(3)];
        final gain = 2 + rnd.nextInt(2); // 2~3
        _gainAttr(p, key, gain);
        p.energy = max(0, p.energy - 4);
        p.satiety = max(0, p.satiety - 2);
        lines.add('你把心思放回了课业上，${attributeLabel(key)} +$gain。');
      case OfflineActivity.practice:
        final key = _activityAttrPool[OfflineActivity.practice]![
            rnd.nextInt(2)];
        final gain = 1 + rnd.nextInt(3); // 1~3
        _gainAttr(p, key, gain);
        p.magic = max(0, p.magic - 6);
        p.energy = max(0, p.energy - 3);
        lines.add('你反复练习了挥杖与咒语发音，${attributeLabel(key)} +$gain。');
      case OfflineActivity.sport:
        final key = _activityAttrPool[OfflineActivity.sport]![
            rnd.nextInt(2)];
        final gain = 1 + rnd.nextInt(2); // 1~2
        _gainAttr(p, key, gain);
        if (p.qSkill < 100) {
          p.qSkill = min(100, p.qSkill + 1);
          lines.add('一场大汗淋漓的练习后，你的${attributeLabel(key)} +$gain，魁地奇技巧 +1。');
        } else {
          lines.add('一场大汗淋漓的练习后，你的${attributeLabel(key)} +$gain。');
        }
        p.energy = max(0, p.energy - 8);
        p.satiety = max(0, p.satiety - 5);
      case OfflineActivity.work:
        final pay = 8 + rnd.nextInt(8); // 8~15
        p.galleons += pay;
        p.energy = max(0, p.energy - 6);
        p.satiety = max(0, p.satiety - 4);
        lines.add('你打了一份零工，赚到 $pay 加隆。');
        notes.add('🪙 打工收入 +$pay 加隆');
      case OfflineActivity.explore:
        p.energy = max(0, p.energy - 4);
        final roll = rnd.nextDouble();
        if (roll < 0.45) {
          final found = 3 + rnd.nextInt(6); // 3~8
          p.galleons += found;
          lines.add('你仔细翻找了一阵，在角落里发现了 $found 加隆。');
          notes.add('🪙 探索拾获 +$found 加隆');
        } else if (roll < 0.75) {
          final item = _discoveryItems[rnd.nextInt(_discoveryItems.length)];
          final owned = p.inventory.any((e) => e.name == item);
          if (owned) {
            p.galleons += 2;
            lines.add('你找到一份$item——可惜家里已经有了，转手卖回 2 加隆。');
            notes.add('🪙 发现重复物品，折现 +2 加隆');
          } else {
            _addItemQuiet(p, item);
            lines.add('你在角落里捡到一份$item，收进了口袋。');
            notes.add('🎒 拾获物品：$item');
          }
        } else {
          final where = worldState.currentLocation ?? '';
          String flavor = _genericExploreFlavor;
          for (final entry in _exploreFlavors.entries) {
            if (where.contains(entry.key)) {
              flavor = entry.value;
              break;
            }
          }
          lines.add(flavor);
        }
      case OfflineActivity.rest:
        p.spirit = min(100, p.spirit + 10);
        p.satiety = min(100, p.satiety + 5);
        lines.add('你抓紧时间歇了口气，精神恢复了少许。');
      case OfflineActivity.social:
        // 社交是叠加项，走到这里说明没有主类别 —— 不会发生。
        break;
      case OfflineActivity.none:
        break;
    }

    // ---- 社交叠加结算（提到已登场 NPC）----
    if (npc != null) {
      final delta = 2 + rnd.nextInt(2); // 2~3
      updateNpcAffection(npc.id, delta, reason: '本地互动', quiet: true);
      lines.add('你和${npc.name}相处了一阵，关系更近了一些（好感 +$delta）。');
      notes.add('💬 与${npc.name}好感 +$delta');
    }

    if (lines.isEmpty) return OfflineConsequenceResult.empty;
    return OfflineConsequenceResult(lines: lines, notes: notes);
  }

  /// 属性增长（封顶 100）。静默：后果引擎统一在回合末由调用方落档。
  void _gainAttr(Player player, String key, int gain) {
    player.attributes[key] =
        ((player.attributes[key] ?? 50) + gain).clamp(0, 100);
  }

  /// 物品入包（同名去重由调用侧保证；这里按既有 `_addItem` 口径写字段）。
  void _addItemQuiet(Player player, String name) {
    final def = itemDefByName(name);
    player.inventory.add(
      InventoryItem(
        id: def?.id ?? name,
        name: name,
        type: def?.type ?? 'item',
        description: def?.desc ?? '',
      ),
    );
  }

  static bool _containsAny(String text, List<String> keys) {
    for (final k in keys) {
      if (text.contains(k)) return true;
    }
    return false;
  }
}
