import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../data/quest_data.dart';
import '../../data/item_data.dart';
import '../../theme/miuix_tokens.dart';

/// 新玩法独立页面（v1.11）：委托板 + 装备管理。
/// 页面直接读写 GameProvider，所有操作复用本地判定 Mixin，零 token 消耗。

// ==================== 委托板 ====================

class QuestBoardScreen extends StatefulWidget {
  const QuestBoardScreen({super.key});

  @override
  State<QuestBoardScreen> createState() => _QuestBoardScreenState();
}

class _QuestBoardScreenState extends State<QuestBoardScreen> {
  final Random _random = Random();
  List<QuestTemplate> _board = const [];

  List<QuestTemplate> _computeBoard(GameProvider gp) {
    final p = gp.player;
    final taken = <String>{};
    for (final q in p?.quests ?? const <QuestRecord>[]) {
      taken.add(q.templateId);
    }
    final available = kQuestTemplates
        .where((t) => !taken.contains(t.id) && (t.minGrade <= (p?.grade ?? 1)))
        .toList()
      ..shuffle(_random);
    return available.take(3).toList();
  }

  /// 委托类型 → 中文名。表在 quest_data.dart（mixin_play 的 /委托 文案共用）。
  String _questTypeLabel(String type) => questTypeLabel(type);

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final p = gp.player;
    if (_board.isEmpty) _board = _computeBoard(gp);

    final takenIds = <String>{};
    for (final q in p?.quests ?? const <QuestRecord>[]) {
      takenIds.add(q.templateId);
    }
    final visibleBoard = _board.where((t) => !takenIds.contains(t.id)).toList();
    final quests = p?.quests ?? const <QuestRecord>[];

    return Scaffold(
      appBar: AppBar(title: const Text('支线委托板')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('进行中的委托', count: quests.length),
          if (quests.isEmpty)
            _emptyCard('还没有接下任何委托', '去下方板子挑一个试试，完成有加隆和学院杯积分奖励。')
          else
            ...quests.asMap().entries.map((entry) {
              final index = entry.key;
              final q = entry.value;
              return _buildQuestCard(gp, q, index);
            }),
          const SizedBox(height: 24),
          _sectionHeader(
            '板子上的委托',
            count: visibleBoard.length,
            trailing: TextButton(
              onPressed: () => setState(() => _board = _computeBoard(gp)),
              child: const Text('刷新'),
            ),
          ),
          if (visibleBoard.isEmpty)
            _emptyCard('暂时没有适合你的委托', '提升年级后会有更多委托刷新，也可以稍后再来看看。')
          else
            ...visibleBoard.map((t) => _buildTemplateCard(gp, t)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {int? count, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: MiuiColors.onSurface)),
          ),
          if (count != null)
            Text('$count 条',
                style: const TextStyle(fontSize: 12, color: MiuiColors.onSurfaceVariantSummary)),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _emptyCard(String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 32, color: Theme.of(context).textTheme.bodyMedium!.color),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 13, color: MiuiColors.onSurface)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 11, color: MiuiColors.onSurfaceVariantSummary), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildQuestCard(GameProvider gp, QuestRecord q, int index) {
    final claimed = q.status == 'claimed';
    final done = q.isDone && !claimed;
    final statusColor = claimed
        ? MiuiColors.onSurfaceVariantActions
        : done
            ? MiuiColors.primary
            : Theme.of(context).colorScheme.primary;
    final statusLabel = claimed ? '已领取' : done ? '可交付' : '进行中';
    final progress = (q.targetCount <= 0) ? 0.0 : (q.progress / q.targetCount).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done ? MiuiColors.primary.withValues(alpha: 0.6) : Theme.of(context).dividerTheme.color!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(statusLabel,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(q.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: MiuiColors.onSurface)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(q.desc, style: const TextStyle(fontSize: 12, color: MiuiColors.onSurface)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('进度 ${q.progress}/${q.targetCount}（${q.target}）',
                        style: const TextStyle(fontSize: 11, color: MiuiColors.onSurfaceVariantSummary)),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: statusColor.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation(statusColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text('${q.rewardGalleons}加隆 +${q.rewardHousePoints}分',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: MiuiColors.primary)),
            ],
          ),
          if (done) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MiuiColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: () {
                  final wasDone = q.isDone && !claimed;
                  gp.deliverQuest(index);
                  if (wasDone) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已交付「${q.title}」，奖励到账')),
                    );
                  }
                },
                child: const Text('交付委托 · 领取奖励', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTemplateCard(GameProvider gp, QuestTemplate t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${_questTypeLabel(t.type)} · ${t.minGrade}年级+',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(t.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: MiuiColors.onSurface)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(t.desc, style: const TextStyle(fontSize: 12, color: MiuiColors.onSurface)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text('目标：${t.target} ×${t.targetCount}',
                    style: const TextStyle(fontSize: 11, color: MiuiColors.onSurfaceVariantSummary)),
              ),
              Text('${t.rewardGalleons}加隆 +${t.rewardHousePoints}分',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: MiuiColors.primary)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onPressed: () {
                gp.acceptQuestTemplate(t.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已接取委托「${t.title}」')),
                );
              },
              child: const Text('接受委托', style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 装备管理 ====================

class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({super.key});

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  static const List<(String, String)> _slots = [
    ('robe', '袍子'),
    ('hat', '帽子'),
    ('broom', '扫帚'),
    ('amulet', '饰品'),
  ];

  // 加成算法在 lib/data/item_data.dart，和 /决斗 实际用的是同一个。
  int _combatBonus(GameProvider gp) =>
      gp.player == null ? 0 : equippedCombatBonus(gp.player!.equipped);

  int _castBonus(GameProvider gp) =>
      gp.player == null ? 0 : equippedCastBonus(gp.player!.equipped);

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final p = gp.player;
    if (p == null) return const SizedBox.shrink();

    final ownedCount = <String, int>{};
    for (final e in p.inventory) {
      ownedCount[e.name] = (ownedCount[e.name] ?? 0) + 1;
    }
    final equippable = equippableItems().where((d) => (ownedCount[d.name] ?? 0) > 0).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('装备管理')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MiuiColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MiuiColors.primary.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 18, color: MiuiColors.primary),
                const SizedBox(width: 8),
                Text(
                  '当前加成：战斗 +${_combatBonus(gp)} ｜ 施法成功率 +${(_castBonus(gp) / 10).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: MiuiColors.onSurface),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('已穿戴', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: MiuiColors.onSurface)),
          const SizedBox(height: 8),
          ..._slots.map((s) => _buildSlotRow(gp, s.$1, s.$2)),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text('背包中的装备', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: MiuiColors.onSurface)),
              ),
              Text('${equippable.length} 件', style: const TextStyle(fontSize: 12, color: MiuiColors.onSurfaceVariantSummary)),
            ],
          ),
          const SizedBox(height: 8),
          if (equippable.isEmpty)
            _emptyEquipCard()
          else
            ...equippable.map((d) => _buildEquipCard(gp, d, ownedCount[d.name] ?? 0)),
        ],
      ),
    );
  }

  Widget _emptyEquipCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: const Column(
        children: [
          Icon(Icons.shield_outlined, size: 32, color: MiuiColors.onSurfaceVariantSummary),
          SizedBox(height: 8),
          Text('背包里还没有装备', style: TextStyle(fontSize: 13, color: MiuiColors.onSurface)),
          SizedBox(height: 4),
          Text('去对角巷淘一件，买回来就能在这里穿戴', style: TextStyle(fontSize: 11, color: MiuiColors.onSurfaceVariantSummary)),
        ],
      ),
    );
  }

  Widget _buildSlotRow(GameProvider gp, String slot, String label) {
    final name = gp.player?.equipped[slot];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Row(
        children: [
          Icon(Icons.checkroom, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: MiuiColors.onSurfaceVariantSummary)),
                Text(name ?? '（空）',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: name == null ? MiuiColors.onSurfaceVariantActions : MiuiColors.onSurface,
                    )),
              ],
            ),
          ),
          if (name != null)
            GestureDetector(
              onTap: () {
                gp.unequipItem(slot);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已卸下「$name」，回到背包')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('卸下', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEquipCard(GameProvider gp, ItemDef def, int count) {
    final slot = def.equipSlot;
    final worn = slot != null && gp.player?.equipped[slot] == def.name;
    if (worn) return const SizedBox.shrink();

    final bonusParts = <String>[];
    if (def.statBonus.isNotEmpty) {
      bonusParts.add(def.statBonus.entries.map((e) => '${e.key} +${e.value}').join(' '));
    }
    if (def.combatBonus > 0) bonusParts.add('战斗 +${def.combatBonus}');
    if (def.castBonus > 0) bonusParts.add('施法 +${(def.castBonus / 10).toStringAsFixed(1)}%');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('可装备 · x$count',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.teal)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(def.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: MiuiColors.onSurface)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${def.desc}${bonusParts.isNotEmpty ? '｜${bonusParts.join(' · ')}' : ''}',
              style: const TextStyle(fontSize: 11, color: MiuiColors.onSurface)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onPressed: () {
                gp.equipItem(def.name);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已装备「${def.name}」')),
                );
              },
              child: const Text('穿戴', style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
