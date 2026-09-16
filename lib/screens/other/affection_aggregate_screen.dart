import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/rivalry_data.dart';
import '../../models/npc.dart';
import '../../providers/game_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/npc_avatar.dart';

/// 好感度汇总（排行榜 + 展开看单个 NPC 的明细）。
///
/// 原先这段藏在 phone_home_screen.dart 里，而那个文件从来没有被任何地方
/// import——等于这份排行榜做完了却谁也打不开。抽成独立文件后接到手机页。
class AffectionAggregateScreen extends StatefulWidget {
  const AffectionAggregateScreen({super.key});

  @override
  State<AffectionAggregateScreen> createState() => _AffectionAggregateScreenState();
}

class _AffectionAggregateScreenState extends State<AffectionAggregateScreen> {
  NPC? _expandedNpc;

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    // 只看认识的人。以前这里只过滤 isAlive，一进页面就是全部 70+ 个存活 NPC
    // （含十几个 grade:0 的教职工），绝大多数好感恒为 0、从未登场；
    // 而「魔法通讯」页是过滤 introduced 的，同一份数据在两处口径不一致。
    final npcs = gp.npcRegistry.values
        .where((n) => n.isAlive && n.introduced)
        .toList()
      ..sort((a, b) => b.affection.compareTo(a.affection));

    return Scaffold(
      appBar: AppBar(
        title: const Text('好感度汇总'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: npcs.isEmpty
          ? const Center(child: Text('暂无NPC数据'))
          : Column(
              children: [
                _buildTopChart(npcs),
                const Divider(height: 1),
                Expanded(child: _buildNpcList(npcs, gp.worldState.time.absoluteDayIndex)),
              ],
            ),
    );
  }

  Widget _buildTopChart(List<NPC> npcs) {
    final top5 = npcs.take(5).toList();
    if (top5.isEmpty) return const SizedBox.shrink();
    final maxAff = top5.first.affection.abs() > 0 ? top5.first.affection.abs() : 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '🏆 好感度 Top 5',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium!.color,
              ),
            ),
          ),
          ...top5.asMap().entries.map((entry) {
            final index = entry.key;
            final npc = entry.value;
            final houseColor = UiHelpers.getHouseColor(npc.house);
            final affColor = UiHelpers.getAffectionColor(npc.affection);
            final barWidth = (npc.affection.abs() / maxAff).clamp(0.1, 1.0);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 8),
                  NpcAvatar(
                    npcId: npc.id,
                    npcName: npc.name,
                    houseColor: houseColor,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                npc.name,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${npc.affection >= 0 ? '+' : ''}${npc.affection}',
                              style: TextStyle(fontSize: 12, color: affColor, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: barWidth,
                            backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(affColor),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNpcList(List<NPC> npcs, int today) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: npcs.length,
      itemBuilder: (context, index) => _buildNpcTile(npcs[index], today),
    );
  }

  Widget _buildNpcTile(NPC npc, int today) {
    final houseColor = UiHelpers.getHouseColor(npc.house);
    final houseLabel = UiHelpers.getHouseLabel(npc.house);
    final affColor = UiHelpers.getAffectionColor(npc.affection);
    final affLabel = UiHelpers.getAffectionLabel(npc.affection);
    final isExpanded = _expandedNpc?.id == npc.id;
    final lastReason = _getLastAffectionReason(npc);
    final tier = npc.rivalryTier(today);
    final tierColor = _rivalryColor(tier);

    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() {
            _expandedNpc = isExpanded ? null : npc;
          }),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isExpanded
                    ? houseColor.withValues(alpha: 0.5)
                    : Theme.of(context).dividerColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                NpcAvatar(
                  npcId: npc.id,
                  npcName: npc.name,
                  houseColor: houseColor,
                  size: 44,
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
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: houseColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              houseLabel,
                              style: TextStyle(fontSize: 10, color: houseColor, fontWeight: FontWeight.w500),
                            ),
                          ),
                          // 宿敌等级直接挂在名字后面：不展开也要看得见谁在恨你。
                          // 好感是"-30"这种抽象数字，宿敌徽标才是"他会主动来找茬"。
                          if (tier != RivalryTier.none || npc.formerRival) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: tierColor.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: tierColor.withValues(alpha: 0.45)),
                              ),
                              child: Text(
                                npc.formerRival ? '🤝 旧怨已了' : '${rivalryBadgeFor(tier)} ${tierDefFor(tier).label}',
                                style: TextStyle(fontSize: 10, color: tierColor, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (npc.affection.abs() / 100).clamp(0.0, 1.0),
                                backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                                valueColor: AlwaysStoppedAnimation<Color>(affColor),
                                minHeight: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${npc.affection >= 0 ? '+' : ''}${npc.affection}',
                            style: TextStyle(fontSize: 13, color: affColor, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 12, color: affColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '$affLabel · $lastReason',
                              style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Theme.of(context).hintColor,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          _buildAffectionDetail(npc, today),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildAffectionDetail(NPC npc, int today) {
    final houseColor = UiHelpers.getHouseColor(npc.house);
    final entries = <Widget>[];

    if (npc.grudges.isNotEmpty) {
      final tier = npc.rivalryTier(today);
      final tierColor = _rivalryColor(tier);
      entries.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(
            children: [
              Icon(Icons.warning_amber, size: 14, color: Colors.orange),
              const SizedBox(width: 4),
              Text(
                '记仇记录 (${npc.grudges.length})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange),
              ),
              const Spacer(),
              // 记仇是流水账，看不出"他现在有多恨你"。
              // 等级和分数才是当下的温度，也告诉玩家还差多远能和解。
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tierColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '${rivalryBadgeFor(tier)} ${npc.rivalryScore(today)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: tierColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      if (tier != RivalryTier.none) {
        entries.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              tierDefFor(tier).desc,
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: tierColor.withValues(alpha: 0.9),
              ),
            ),
          ),
        );
      }
      if (npc.formerRival) {
        entries.add(
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              '🤝 曾经是你最难缠的对头，如今已经和解。',
              style: TextStyle(fontSize: 11, color: AppColors.success),
            ),
          ),
        );
      }
      for (final g in npc.grudges) {
        entries.add(
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        g['type']?.toString() ?? '未知类型',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.orange),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '第${g['day'] ?? '?'}天',
                      style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  g['reason']?.toString() ?? '无原因描述',
                  style: const TextStyle(fontSize: 12),
                ),
                if (g['affection_at_time'] != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '当时好感: ${g['affection_at_time']}',
                    style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor),
                  ),
                ],
              ],
            ),
          ),
        );
      }
    }

    if (npc.recentEvents.isNotEmpty) {
      entries.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(
            children: [
              Icon(Icons.event_note, size: 14, color: houseColor),
              const SizedBox(width: 4),
              Text(
                '近期事件 (${npc.recentEvents.length})',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: houseColor),
              ),
            ],
          ),
        ),
      );
      for (final event in npc.recentEvents.reversed.take(5)) {
        entries.add(
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: houseColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: houseColor.withValues(alpha: 0.2)),
            ),
            child: Text(
              event,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        );
      }
    }

    if (entries.isEmpty) {
      entries.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              '暂无好感变动记录',
              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('当前', '${npc.affection}', UiHelpers.getAffectionColor(npc.affection)),
                _buildStatItem('最高', '${npc.maxAffectionReached}', const Color(0xFFEC4899)),
                _buildStatItem('本周+', '${npc.affectionGainedThisWeek}', Colors.blue),
                _buildStatItem('有锁', '${npc.hasGrudge ? '是' : '否'}',
                    npc.hasGrudge ? Colors.orange : Colors.green),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...entries,
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  String _getLastAffectionReason(NPC npc) {
    if (npc.grudges.isNotEmpty) {
      final last = npc.grudges.last;
      return last['reason']?.toString() ?? '记仇';
    }
    if (npc.recentEvents.isNotEmpty) {
      return npc.recentEvents.last;
    }
    return '累计变动';
  }
}

/// 宿敌等级的配色：从灰到深红，一眼能看出这段关系有多糟。
Color _rivalryColor(RivalryTier tier) => switch (tier) {
      RivalryTier.none => Colors.grey,
      RivalryTier.grudge => Colors.amber,
      RivalryTier.hostile => Colors.deepOrange,
      RivalryTier.nemesis => AppColors.danger,
      RivalryTier.archenemy => const Color(0xFFB71C1C),
    };
