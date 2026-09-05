import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/player.dart';
import '../../utils/ui_helpers.dart';
import '../../theme/miuix_tokens.dart';

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
      padding: const EdgeInsets.fromLTRB(16, 7, 16, 9),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              border: Border.all(color: Theme.of(context).colorScheme.primary),
            ),
            child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary, size: 20),
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
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: MiuiColors.primaryVariant, letterSpacing: 0.3)),
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
                          style: const TextStyle(fontSize: 10.5, color: MiuiColors.onSurfaceVariantSummary, letterSpacing: 0.1),
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
    final resources = <({String label, IconData icon, int value, Color color})>[
      (label: '生命', icon: Icons.favorite, value: player.health, color: AppColors.danger),
      (label: '魔力', icon: Icons.auto_awesome, value: player.magic, color: const Color(0xFF60A5FA)),
      (label: '精神', icon: Icons.psychology, value: player.spirit, color: const Color(0xFFA78BFA)),
      (label: '饱食', icon: Icons.restaurant, value: player.satiety, color: const Color(0xFFD97706)),
      (label: '精力', icon: Icons.flash_on, value: player.energy, color: AppColors.success),
    ];
    return SizedBox(
      height: 34,
      child: Row(
        children: List.generate(resources.length, (i) {
          final r = resources[i];
          final low = r.value < 30;
          final barColor = low ? MiuiColors.error : r.color;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < resources.length - 1 ? 5 : 0),
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: barColor.withValues(alpha: 0.35),
                    width: MiuiSpace.dividerThickness,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(r.icon, size: 12, color: barColor),
                    const SizedBox(width: 3),
                    Text('${r.value}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: low ? MiuiColors.error : barColor,
                        )),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
