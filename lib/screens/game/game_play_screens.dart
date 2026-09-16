import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../data/quest_data.dart';
import '../../data/item_data.dart';
import '../../theme/miuix_tokens.dart';
import '../../utils/ui_helpers.dart';

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
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.assignment, size: 20, color: AppColors.gold),
            const SizedBox(width: 8),
            const Text('支线委托板'),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A2E).withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      extendBody: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF1A1A2E), const Color(0xFF0D0D1A)],
          ),
        ),
        child: ListView(
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
              trailing: TextButton.icon(
                onPressed: () => setState(() => _board = _computeBoard(gp)),
                icon: const Icon(Icons.refresh, size: 16, color: AppColors.gold),
                label: const Text('刷新', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600)),
              ),
            ),
            if (visibleBoard.isEmpty)
              _emptyCard('暂时没有适合你的委托', '提升年级后会有更多委托刷新，也可以稍后再来看看。')
            else
              ...visibleBoard.map((t) => _buildTemplateCard(gp, t)),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {int? count, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.gold, AppColors.goldDeep],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          if (count != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$count 条',
                  style: const TextStyle(fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.w600)),
            ),
          if (trailing != null) const SizedBox(width: 8),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _emptyCard(String title, String desc) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3A3A5C).withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 36, color: const Color(0xFF5A5A7A)),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF8A8AAA)), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestCard(GameProvider gp, QuestRecord q, int index) {
    final claimed = q.status == 'claimed';
    final done = q.isDone && !claimed;
    final statusColor = claimed
        ? const Color(0xFF5A5A7A)
        : done
            ? AppColors.gold
            : AppColors.goldBright;
    final statusLabel = claimed ? '已领取' : done ? '可交付' : '进行中';
    final progress = (q.targetCount <= 0) ? 0.0 : (q.progress / q.targetCount).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: done ? AppColors.gold.withValues(alpha: 0.5) : const Color(0xFF3A3A5C).withValues(alpha: 0.4),
              width: done ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (done) ...[
                          const Icon(Icons.check_circle, size: 12, color: AppColors.gold),
                          const SizedBox(width: 4),
                        ],
                        if (claimed) ...[
                          const Icon(Icons.check, size: 12, color: Color(0xFF5A5A7A)),
                          const SizedBox(width: 4),
                        ],
                        Text(statusLabel,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(q.title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(q.desc, style: const TextStyle(fontSize: 12, color: Color(0xFFB0B0C8))),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('进度 ${q.progress}/${q.targetCount}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF8A8AAA))),
                            const SizedBox(width: 4),
                            Text('（${q.target}）',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF6A6A8A))),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor: const Color(0xFF2A2A4A),
                            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${q.rewardGalleons}加隆 +${q.rewardHousePoints}分',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.gold)),
                  ),
                ],
              ),
              if (done) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: const Color(0xFF1A1A2E),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
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
                    icon: const Icon(Icons.redeem, size: 16),
                    label: const Text('交付委托 · 领取奖励', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateCard(GameProvider gp, QuestTemplate t) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF3A3A5C).withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.gold.withValues(alpha: 0.2), AppColors.goldDeep.withValues(alpha: 0.1)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 12, color: AppColors.gold),
                        const SizedBox(width: 4),
                        Text('${_questTypeLabel(t.type)} · ${t.minGrade}年级+',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.gold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(t.title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(t.desc, style: const TextStyle(fontSize: 12, color: Color(0xFFB0B0C8))),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.flag, size: 14, color: const Color(0xFF6A6A8A)),
                        const SizedBox(width: 4),
                        Text('目标：${t.target} ×${t.targetCount}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF8A8AAA))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${t.rewardGalleons}加隆 +${t.rewardHousePoints}分',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.gold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: const Color(0xFF1A1A2E),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    gp.acceptQuestTemplate(t.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已接取委托「${t.title}」')),
                    );
                  },
                  icon: const Icon(Icons.add_task, size: 16),
                  label: const Text('接受委托', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
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
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.shield, size: 20, color: AppColors.gold),
            const SizedBox(width: 8),
            const Text('装备管理'),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A2E).withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      extendBody: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF1A1A2E), const Color(0xFF0D0D1A)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 当前加成卡片
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.25),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.topLeft,
                            radius: 1.2,
                            colors: [AppColors.gold.withValues(alpha: 0.3), AppColors.goldDeep.withValues(alpha: 0.1)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
                        ),
                        child: Icon(Icons.auto_awesome, size: 20, color: AppColors.gold),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('当前加成',
                                style: TextStyle(fontSize: 12, color: Color(0xFF8A8AAA), fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text(
                              '战斗 +${_combatBonus(gp)} ｜ 施法成功率 +${(_castBonus(gp) / 10).toStringAsFixed(1)}%',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.goldBright),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.gold, AppColors.goldDeep],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('已穿戴', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 10),
            ..._slots.map((s) => _buildSlotRow(gp, s.$1, s.$2)),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.gold, AppColors.goldDeep],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('背包中的装备', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${equippable.length} 件',
                      style: const TextStyle(fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (equippable.isEmpty)
              _emptyEquipCard()
            else
              ...equippable.map((d) => _buildEquipCard(gp, d, ownedCount[d.name] ?? 0)),
          ],
        ),
      ),
    );
  }

  Widget _emptyEquipCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3A3A5C).withValues(alpha: 0.4)),
          ),
          child: const Column(
            children: [
              Icon(Icons.shield_outlined, size: 36, color: Color(0xFF5A5A7A)),
              SizedBox(height: 10),
              Text('背包里还没有装备', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
              SizedBox(height: 6),
              Text('去对角巷淘一件，买回来就能在这里穿戴', style: TextStyle(fontSize: 12, color: Color(0xFF8A8AAA))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlotRow(GameProvider gp, String slot, String label) {
    final name = gp.player?.equipped[slot];
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: name != null
                ? const Color(0xFF1A1A2E).withValues(alpha: 0.65)
                : const Color(0xFF1A1A2E).withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: name != null
                  ? AppColors.gold.withValues(alpha: 0.3)
                  : const Color(0xFF3A3A5C).withValues(alpha: 0.4),
              width: name != null ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: name != null
                      ? AppColors.gold.withValues(alpha: 0.15)
                      : const Color(0xFF2A2A4A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  slot == 'robe' ? Icons.checkroom :
                  slot == 'hat' ? Icons.face :
                  slot == 'broom' ? Icons.flight :
                  Icons.diamond,
                  size: 18,
                  color: name != null ? AppColors.gold : const Color(0xFF5A5A7A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF8A8AAA))),
                    const SizedBox(height: 2),
                    Text(name ?? '（空）',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: name == null ? const Color(0xFF5A5A7A) : Colors.white,
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('卸下', style: TextStyle(fontSize: 12, color: Color(0xFFE05050), fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
        ),
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF3A3A5C).withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.gold.withValues(alpha: 0.2), AppColors.goldDeep.withValues(alpha: 0.1)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 12, color: AppColors.gold),
                        const SizedBox(width: 4),
                        Text('可装备 · x$count',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.gold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(def.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${def.desc}${bonusParts.isNotEmpty ? '｜${bonusParts.join(' · ')}' : ''}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFB0B0C8))),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: const Color(0xFF1A1A2E),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    gp.equipItem(def.name);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已装备「${def.name}」')),
                    );
                  },
                  icon: const Icon(Icons.checkroom, size: 16),
                  label: const Text('穿戴', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
