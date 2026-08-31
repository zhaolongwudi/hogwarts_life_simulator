import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/player.dart';
import '../../utils/ui_helpers.dart';

class GameTopBar extends StatelessWidget {
  const GameTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final player = gp.player;
    if (player == null) return const SizedBox.shrink();

    // BUG-2 分院前人物简介提前显示学院：最终防线
    // 只有当成就 'sorted' 已解锁（本地逻辑分院/骨架链分院/AI文本解析分院 都会解锁），
    // 才认为 house 真的有效；即便 player.house 因 OOC 被意外赋值，也不渲染。
    final houseSorted = player.achievements.contains('sorted');
    final houseLabel = {
      'Gryffindor': '格兰芬多',
      'Slytherin': '斯莱特林',
      'Ravenclaw': '拉文克劳',
      'Hufflepuff': '赫奇帕奇',
    }[(houseSorted ? player.house : null) ?? ''] ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              border: Border.all(color: Theme.of(context).colorScheme.primary),
            ),
            child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(player.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE6EDF3))),
                    ),
                    if (houseLabel.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          houseLabel,
                          style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 12, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(gp.worldState.timestamp,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              await gp.quickSave();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ 已存档'), duration: Duration(seconds: 1)),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.save, size: 20, color: Theme.of(context).colorScheme.primary),
            ),
          ),
          ],
          ),
          const SizedBox(height: 8),
          _buildResourceBars(player),
        ],
      ),
    );
  }

  /// 顶部 HUD：5 条细长状态条（生命/魔力/精神力/饱食/精力），低值变红提醒
  Widget _buildResourceBars(Player player) {
    final resources = <({String label, int value, Color color})>[
      (label: '生命', value: player.health, color: AppColors.danger),
      (label: '魔力', value: player.magic, color: const Color(0xFF2563EB)),
      (label: '精神', value: player.spirit, color: const Color(0xFF7C3AED)),
      (label: '饱食', value: player.satiety, color: const Color(0xFFD97706)),
      (label: '精力', value: player.energy, color: AppColors.success),
    ];
    return Row(
      children: List.generate(resources.length, (i) {
        final r = resources[i];
        final low = r.value < 30;
        final barColor = low ? const Color(0xFFEF4444) : r.color;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < resources.length - 1 ? 6 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(r.label,
                        style: const TextStyle(fontSize: 9, color: Color(0xFF8B949E))),
                    Text('${r.value}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: low ? const Color(0xFFEF4444) : const Color(0xFFE6EDF3),
                        )),
                  ],
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (r.value / 100).clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: barColor.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(barColor),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
