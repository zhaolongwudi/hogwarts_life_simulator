import 'package:flutter/material.dart';
import '../../providers/game_provider.dart';
import '../../models/npc.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/npc_avatar.dart';

class WorldTab extends StatelessWidget {
  final GameProvider gp;

  const WorldTab({super.key, required this.gp});

  @override
  Widget build(BuildContext context) {
    final npcs = gp.npcRegistry.values.toList();
    final appeared = npcs.where((n) => n.introduced).toList()
      ..sort((a, b) => b.affection.compareTo(a.affection));
    final others = npcs.where((n) => !n.introduced).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWorldHeader(context, appeared.length, others.length),
          const SizedBox(height: 12),
          _buildWorldActionRow(context),
          const SizedBox(height: 12),
          _buildNpcSection(context, '🌟 已登场人物', appeared, false),
          const SizedBox(height: 8),
          _buildNpcSection(context, '👥 未登场/未结识', others, true),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildWorldHeader(BuildContext context, int appeared, int unmet) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerTheme.color!),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.public, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('世界', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '第${_currentYear()}年·9月 · 已登场 $appeared 人 · 未登场 $unmet 人',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium!.color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorldActionRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              final name = gp.meetRandomNpc();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(name == null
                      ? '已经没有还没打过照面的人了'
                      : '你在人群中注意到了 $name，你们算是认识了'),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerTheme.color!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_border, color: Theme.of(context).colorScheme.secondary, size: 18),
                  const SizedBox(width: 6),
                  const Text('随机结识', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              final before = gp.npcRegistry.length;
              gp.generateNewNPC();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(gp.npcRegistry.length > before
                      ? '新人物已加入这个世界，可在下方名单里找到'
                      : gp.currentNarrative.isNotEmpty
                          ? gp.currentNarrative
                          : '本学年新人物已达上限（每学年最多 4 位）'),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Theme.of(context).colorScheme.primary, size: 18),
                  const SizedBox(width: 6),
                  Text('新建 NPC', style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNpcSection(BuildContext context, String title, List<NPC> npcs, bool initiallyCollapsed) {
    final isEmpty = npcs.isEmpty;
    return StatefulBuilder(
      builder: (context, setInnerState) {
        final collapsed = ValueNotifier<bool>(initiallyCollapsed);
        final visibleCount = ValueNotifier<int>(15);
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerTheme.color!),
          ),
          child: Column(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: collapsed,
                builder: (context, isCollapsed, _) {
                  return GestureDetector(
                    onTap: () => collapsed.value = !collapsed.value,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          AnimatedRotation(
                            turns: isCollapsed ? 0 : 0.25,
                            duration: const Duration(milliseconds: 150),
                            child: Icon(Icons.keyboard_arrow_right, size: 20, color: Theme.of(context).textTheme.bodyMedium!.color),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFE6EDF3)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${npcs.length}',
                              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '暂无',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium!.color),
                  ),
                )
              else
                ValueListenableBuilder<bool>(
                  valueListenable: collapsed,
                  builder: (context, isCollapsed, _) {
                    if (isCollapsed) return const SizedBox.shrink();
                    // 名单默认只展示前 15 位。以前底部那句「还有 N 人未显示」
                    // 点了只是把同一句话再弹一遍，没有任何展开入口——
                    // 已登场人物超过 15 个之后，后一半人在这个页面永远看不到。
                    return ValueListenableBuilder<int>(
                      valueListenable: visibleCount,
                      builder: (context, limit, _) {
                        final displayList = initiallyCollapsed
                            ? npcs
                            : (npcs.length > limit ? npcs.take(limit).toList() : npcs);
                        final remaining = npcs.length - displayList.length;
                        return Column(
                          children: [
                            ...displayList.map((npc) => _buildNpcDetailCard(context, npc)),
                            if (!initiallyCollapsed && remaining > 0)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                                child: GestureDetector(
                                  onTap: () => visibleCount.value = limit + 20,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '… 还有 $remaining 人，点击展开',
                                        style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 6),
                          ],
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNpcDetailCard(BuildContext context, NPC npc) {
    final isNearby = gp.isNearby(npc.id);
    final hasAppeared = npc.introduced;
    final relationLabel = _getRelationLabel(npc);
    final hasRecentEvents = npc.recentEvents.isNotEmpty;
    final roleTags = UiHelpers.npcRoleTags(npc);
    final houseColor = _getHouseColor(npc.house);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerTheme.color!.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NpcAvatar(
                npcId: npc.id,
                npcName: npc.name,
                houseColor: houseColor,
                size: 42,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(npc.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFE6EDF3))),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: hasAppeared ? Colors.green.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            hasAppeared ? '已登场' : '未登场',
                            style: TextStyle(fontSize: 10.5, color: hasAppeared ? Colors.green : Colors.grey, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (isNearby) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('同地点', style: TextStyle(fontSize: 10.5, color: Colors.blue, fontWeight: FontWeight.w600)),
                          ),
                        ],
                        if (npc.isConsideringConfession) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('酝酿中', style: TextStyle(fontSize: 10.5, color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(relationLabel, style: TextStyle(fontSize: 11.5, color: _getAffectionColor(npc.affection), fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Text(npc.introduced == true ? '好感 ${npc.affection >= 0 ? '+' : ''}${npc.affection}' : '好感 —', style: TextStyle(fontSize: 10.5, color: Theme.of(context).textTheme.bodyMedium!.color)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: roleTags.map((tag) {
                        final isJob = tag.contains('教授') || tag.contains('校长') || tag.contains('管理') || tag.contains('护士') || tag.contains('看守') || tag.contains('解说') || tag.contains('部长') || tag.contains('傲罗') || tag.contains('级长') || tag.contains('队长') || tag.contains('母亲') || tag.contains('父亲') || tag.contains('母亲') || tag.contains('教父') || tag.contains('家主') || tag.contains('夫人') || tag.contains('姨夫') || tag.contains('姨妈') || tag.contains('表哥') || tag.contains('跟班') || tag.contains('女友') || tag.contains('食死徒') || tag.contains('黑巫师') || tag.contains('叛徒');
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isJob ? const Color(0xFFD3A625).withValues(alpha: 0.12) : houseColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(tag,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: isJob ? const Color(0xFFD3A625) : houseColor,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasAppeared && hasRecentEvents) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_stories, size: 12, color: Colors.amber.shade700),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '曾在「${npc.recentEvents.first == '初次见面' ? '首次出现' : npc.recentEvents.first}」中出现',
                      style: TextStyle(fontSize: 10.5, color: Colors.amber.shade800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getHouseColor(String house) {
    switch (house) {
      case 'Gryffindor':
        return const Color(0xFFB8860B);
      case 'Slytherin':
        return const Color(0xFF2D6A4F);
      case 'Ravenclaw':
        return const Color(0xFF3B82F6);
      case 'Hufflepuff':
        return const Color(0xFFD97706);
      case 'staff':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF5A6B4A);
    }
  }

  Color _getAffectionColor(int affection) {
    if (affection <= -30) return const Color(0xFFEF4444);
    if (affection <= -10) return const Color(0xFFF97316);
    if (affection <= 10) return const Color(0xFF6B7280);
    if (affection <= 30) return const Color(0xFF3B82F6);
    if (affection <= 50) return const Color(0xFF10B981);
    if (affection <= 70) return const Color(0xFF8B5CF6);
    if (affection <= 90) return const Color(0xFFEC4899);
    return const Color(0xFFD946EF);
  }

  String _getRelationLabel(NPC npc) {
    if (npc.affection <= -30) return '敌对';
    if (npc.affection <= -10) return '冷淡';
    if (npc.affection <= 10) return '关系未明';
    if (npc.affection <= 30) return '初识';
    if (npc.affection <= 50) return '朋友';
    if (npc.affection <= 70) return '好友';
    if (npc.affection <= 90) return '亲密';
    return '挚友';
  }

  int _currentYear() {
    final yearStr = gp.worldState.academicYear;
    try {
      final startYear = int.parse(yearStr.split('-')[0]);
      final baseYear = switch (gp.worldState.era) {
        'dumbledore' => 1892,
        'marauders' => 1971,
        'first_war' => 1976,
        'post_war' => 2020,
        _ => 1991,
      };
      return startYear - baseYear + 1;
    } catch (_) {
      return 1;
    }
  }
}
