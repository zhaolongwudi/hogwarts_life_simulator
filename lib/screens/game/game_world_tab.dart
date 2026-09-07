import 'dart:ui';
import 'package:flutter/material.dart';
import '../../providers/game_provider.dart';
import '../../models/npc.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/npc_avatar.dart';
import '../../theme/miuix_tokens.dart';

/// 世界 Tab：NPC 管理（参考图 601b4b32 风格）
///
/// 玻璃拟态头部 + 温暖卡其底色 + NPC 卡片（头像/姓名/标签/地点/好感度）
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

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF5F0E8), Color(0xFFEDE6D8)],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildWorldHeader(context, appeared.length, others.length),
              const SizedBox(height: 12),
              _buildWorldActionRow(context),
              const SizedBox(height: 16),
              _buildNpcSection(context, '🌟 已登场人物', appeared, false),
              const SizedBox(height: 8),
              _buildNpcSection(context, '👥 未登场人物', others, true),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// 玻璃拟态头部：世界图标 + 统计信息
  Widget _buildWorldHeader(BuildContext context, int appeared, int unmet) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12, tileMode: TileMode.clamp),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MiuiColors.surfaceContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: MiuiColors.primary.withValues(alpha: 0.15),
              width: MiuiSpace.dividerThickness,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      MiuiColors.primary.withValues(alpha: 0.2),
                      MiuiColors.primaryVariant.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.public, color: MiuiColors.primaryVariant, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('世界', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: MiuiColors.onSurface)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: MiuiColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_currentYear()}年',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: MiuiColors.primaryVariant),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '已登场 $appeared 人 · 未登场 $unmet 人',
                      style: TextStyle(fontSize: 12, color: MiuiColors.onSurfaceVariantSummary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 操作行：随机结识 + 新建 NPC（参考图圆角胶囊按钮）
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
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: MiuiColors.surfaceContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: MiuiColors.outline.withValues(alpha: 0.4),
                  width: MiuiSpace.dividerThickness,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_border, color: MiuiColors.primaryVariant, size: 17),
                  const SizedBox(width: 6),
                  const Text('随机结识', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: MiuiColors.onSurface)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
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
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    MiuiColors.primary.withValues(alpha: 0.12),
                    MiuiColors.primaryVariant.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: MiuiColors.primary.withValues(alpha: 0.3),
                  width: MiuiSpace.dividerThickness,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: MiuiColors.primaryVariant, size: 17),
                  const SizedBox(width: 6),
                  Text('新建 NPC', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: MiuiColors.primaryVariant)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// NPC 分组面板（可折叠）
  Widget _buildNpcSection(BuildContext context, String title, List<NPC> npcs, bool initiallyCollapsed) {
    final isEmpty = npcs.isEmpty;
    return StatefulBuilder(
      builder: (context, setInnerState) {
        final collapsed = ValueNotifier<bool>(initiallyCollapsed);
        final visibleCount = ValueNotifier<int>(15);
        return Container(
          decoration: BoxDecoration(
            color: MiuiColors.surfaceContainer.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: MiuiColors.outline.withValues(alpha: 0.3),
              width: MiuiSpace.dividerThickness,
            ),
          ),
          child: Column(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: collapsed,
                builder: (context, isCollapsed, _) {
                  return GestureDetector(
                    onTap: () => collapsed.value = !collapsed.value,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(
                        children: [
                          AnimatedRotation(
                            turns: isCollapsed ? 0 : 0.25,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(Icons.keyboard_arrow_right, size: 20, color: MiuiColors.onSurfaceVariantSummary),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: MiuiColors.onSurface),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: MiuiColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${npcs.length}',
                              style: TextStyle(fontSize: 12, color: MiuiColors.primaryVariant, fontWeight: FontWeight.w600),
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.travel_explore, size: 32, color: MiuiColors.onSurfaceVariantActions),
                      const SizedBox(height: 8),
                      Text(
                        '暂无内容\n多行动，世界会回应你',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: MiuiColors.onSurfaceVariantSummary),
                      ),
                    ],
                  ),
                )
              else
                ValueListenableBuilder<bool>(
                  valueListenable: collapsed,
                  builder: (context, isCollapsed, _) {
                    if (isCollapsed) return const SizedBox.shrink();
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
                                      color: MiuiColors.primary.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '… 还有 $remaining 人，点击展开',
                                        style: TextStyle(fontSize: 11.5, color: MiuiColors.primaryVariant, fontWeight: FontWeight.w500),
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

  /// NPC 详情卡片（参考图 601b4b32 风格：头像 + 姓名 + 标签 + 地点 + 描述）
  Widget _buildNpcDetailCard(BuildContext context, NPC npc) {
    final isNearby = gp.isNearby(npc.id);
    final hasAppeared = npc.introduced;
    final relationLabel = _getRelationLabel(npc);
    final hasRecentEvents = npc.recentEvents.isNotEmpty;
    final roleTags = UiHelpers.npcRoleTags(npc);
    final houseColor = _getHouseColor(npc.house);
    final affectionColor = _getAffectionColor(npc.affection);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: MiuiColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MiuiColors.outline.withValues(alpha: 0.25),
          width: MiuiSpace.dividerThickness,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：头像 + 姓名 + 状态标签
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
                          child: Text(npc.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: MiuiColors.onSurface)),
                        ),
                        // 状态标签组
                        ..._buildStatusBadges(isNearby, hasAppeared, npc),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // 关系标签 + 好感度
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: affectionColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            relationLabel,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: affectionColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (hasAppeared)
                          Text(
                            '好感 ${npc.affection >= 0 ? '+' : ''}${npc.affection}',
                            style: TextStyle(fontSize: 11, color: affectionColor),
                          ),
                      ],
                    ),
                    // 地点标签
                    if (hasAppeared) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 11, color: MiuiColors.onSurfaceVariantActions),
                          const SizedBox(width: 2),
                          Text(
                            npc.currentLocation ?? '未知',
                            style: TextStyle(fontSize: 11, color: MiuiColors.onSurfaceVariantSummary),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          // 角色标签行
          if (roleTags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: roleTags.map((tag) {
                final isJob = tag.contains('教授') || tag.contains('校长') || tag.contains('管理') || tag.contains('护士') || tag.contains('看守') || tag.contains('解说') || tag.contains('部长') || tag.contains('傲罗') || tag.contains('级长') || tag.contains('队长') || tag.contains('母亲') || tag.contains('父亲') || tag.contains('教父') || tag.contains('家主') || tag.contains('夫人') || tag.contains('姨夫') || tag.contains('姨妈') || tag.contains('表哥') || tag.contains('跟班') || tag.contains('女友') || tag.contains('食死徒') || tag.contains('黑巫师') || tag.contains('叛徒');
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isJob ? MiuiColors.primary.withValues(alpha: 0.1) : houseColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(tag,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: isJob ? MiuiColors.primaryVariant : houseColor,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          // 最近事件
          if (hasAppeared && hasRecentEvents) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: MiuiColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_stories, size: 11, color: MiuiColors.primaryVariant),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '曾在「${npc.recentEvents.first == '初次见面' ? '首次出现' : npc.recentEvents.first}」中出现',
                      style: TextStyle(fontSize: 10.5, color: MiuiColors.primaryVariant),
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

  /// 构建状态标签组（同地点 / 已登场 / 酝酿中）
  List<Widget> _buildStatusBadges(bool isNearby, bool hasAppeared, NPC npc) {
    final badges = <Widget>[];
    if (hasAppeared) {
      badges.add(_buildBadge('已登场', Colors.green));
    } else {
      badges.add(_buildBadge('未登场', Colors.grey));
    }
    if (isNearby) {
      badges.add(const SizedBox(width: 4));
      badges.add(_buildBadge('同地点', MiuiColors.primaryVariant));
    }
    if (npc.isConsideringConfession) {
      badges.add(const SizedBox(width: 4));
      badges.add(_buildBadge('酝酿中', MiuiColors.error));
    }
    return badges;
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
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
        return MiuiColors.onSurfaceVariantActions;
      default:
        return const Color(0xFF5A6B4A);
    }
  }

  Color _getAffectionColor(int affection) =>
      UiHelpers.getAffectionColor(affection);

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