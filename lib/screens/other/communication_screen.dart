import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/npc.dart';
import '../../providers/game_provider.dart';
import '../npc_chat_screen.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/npc_avatar.dart';
import '../../theme/miuix_tokens.dart';

// ==================== 魔法通讯 ====================
class CommunicationScreen extends StatefulWidget {
  const CommunicationScreen({super.key});

  @override
  State<CommunicationScreen> createState() => _CommunicationScreenState();
}

class _CommunicationScreenState extends State<CommunicationScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    // 魔法通讯只显示：剧情中已登场 / 已产生好感互动 / 关系等级建立 的 NPC（没认识的不显示）
    final npcs = gp.npcRegistry.values.where((n) {
      return n.introduced;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('魔法通讯'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: npcs.isEmpty
                ? _buildEmptyState()
                : _buildContactsList(npcs),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showNewMessageDialog(npcs);
        },
        child: const Icon(Icons.edit),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
        ),
      ),
      alignment: Alignment.center,
      child: ListView(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        children: [
          _buildFilterChip('全部', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('格兰芬多', 'Gryffindor'),
          const SizedBox(width: 8),
          _buildFilterChip('斯莱特林', 'Slytherin'),
          const SizedBox(width: 8),
          _buildFilterChip('拉文克劳', 'Ravenclaw'),
          const SizedBox(width: 8),
          _buildFilterChip('赫奇帕奇', 'Hufflepuff'),
          const SizedBox(width: 8),
          _buildFilterChip('教职工', 'staff'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        constraints: const BoxConstraints(minHeight: 36, minWidth: 56),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
              : Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.0,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.phone_in_talk, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('还没有联系人', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Text('开始游戏后会自动添加NPC', style: TextStyle(fontSize: 14, color: Colors.grey.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _buildContactsList(List<NPC> npcs) {
    final filtered = npcs.where((npc) {
      if (_filter == 'all') return true;
      if (_filter == 'staff') return npc.grade == 0;
      return npc.house == _filter;
    }).toList()
      ..sort((a, b) => b.affection.compareTo(a.affection));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final npc = filtered[index];
        return _buildContactTile(npc);
      },
    );
  }

  Widget _buildContactTile(NPC npc) {
    final houseColor = UiHelpers.getHouseColor(npc.house);
    final affLevel = UiHelpers.getAffectionLabel(npc.affection);
    final isAlive = npc.isAlive;
    final canChat = npc.isAlive;
    final roleTags = UiHelpers.npcRoleTags(npc); // 身份标签替代外貌描述

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: !isAlive ? Colors.grey.withValues(alpha: 0.3) : Theme.of(context).dividerColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canChat
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NpcChatScreen(npc: npc)),
                  );
                }
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                NpcAvatar(
                  npcId: npc.id,
                  npcName: npc.name,
                  houseColor: houseColor,
                  size: 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              npc.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: !isAlive ? Colors.grey : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (npc.isConsideringConfession)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: MiuiColors.error.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('酝酿中', style: TextStyle(fontSize: 10, color: MiuiColors.error)),
                            ),
                          if (!isAlive)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('已离场', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ),
                          _buildAffectionBadge(npc.affection),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        affLevel,
                        style: TextStyle(
                          fontSize: 12,
                          color: !isAlive ? Colors.grey : UiHelpers.getAffectionColor(npc.affection),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // 身份标签（不写外貌，只写让用户记起角色的定位标签）
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: roleTags.take(2).map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: houseColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(fontSize: 10.5, color: houseColor, fontWeight: FontWeight.w500),
                          ),
                        )).toList(),
                      ),
                      if (npc.recentEvents.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_stories, size: 12, color: Colors.amber.shade700),
                                  const SizedBox(width: 3),
                                  Text(
                                    '近期 · ${npc.recentEvents.first}',
                                    style: TextStyle(fontSize: 10, color: Colors.amber.shade800),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: canChat ? Theme.of(context).dividerColor : Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAffectionBadge(int affection) {
    final color = UiHelpers.getAffectionColor(affection);
    final icon = affection >= 50 ? Icons.favorite : affection >= 0 ? Icons.sentiment_satisfied : Icons.sentiment_dissatisfied;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            '$affection',
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showNewMessageDialog(List<NPC> npcs) {
    if (npcs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('还没有联系人')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择联系人'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: npcs.length,
            itemBuilder: (context, index) {
              final npc = npcs[index];
              return ListTile(
                title: Text(npc.name),
                subtitle: Text(UiHelpers.getAffectionLabel(npc.affection)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NpcChatScreen(npc: npc)),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// ==================== 魔法论坛 ====================
