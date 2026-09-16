import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/player.dart';
import '../../theme/miuix_tokens.dart';

class GameTopBar extends StatelessWidget {
  const GameTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final player = gp.player;
    if (player == null) return const SizedBox.shrink();

    final houseSorted = player.achievements.contains('sorted');
    final houseLabel = {
      'Gryffindor': '格兰芬多',
      'Slytherin': '斯莱特林',
      'Ravenclaw': '拉文克劳',
      'Hufflepuff': '赫奇帕奇',
    }[(houseSorted ? player.house : null) ?? ''] ?? '';

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 16,
          sigmaY: 16,
          tileMode: TileMode.clamp,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 7, 16, 9),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.55),
                Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.40),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: MiuiColors.primary.withValues(alpha: 0.16),
                width: MiuiSpace.dividerThickness,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 主行：头像 + 玩家信息 + 时间控制胶囊 + 存档
              Row(
                children: [
                  // 头像（参考图风格：圆形头像带角色首字母）
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MiuiColors.primary.withValues(alpha: 0.15),
                      border: Border.all(
                        color: MiuiColors.primary.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: MiuiColors.primaryVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 玩家名字 + 学院标签
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                player.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: MiuiColors.primaryVariant,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            if (houseLabel.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: MiuiColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  houseLabel,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: MiuiColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 时间控制胶囊（参考图 Screenshot_00-09-17 风格）
                  _buildTimeCapsule(gp),
                  const SizedBox(width: 8),
                  // 存档按钮
                  Semantics(
                    button: true,
                    label: '快速存档',
                    child: GestureDetector(
                      onTap: () async {
                        await gp.quickSave();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ 已存档'),
                              duration: MiuiDuration.snackbarShort,
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: MiuiColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.save,
                          size: 18,
                          color: MiuiColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 资源胶囊条
              _buildResourceBars(player),
            ],
          ),
        ),
      ),
    );
  }

  /// 时间控制胶囊（参考图 Screenshot_00-09-17 风格）
  Widget _buildTimeCapsule(GameProvider gp) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: MiuiColors.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: MiuiColors.primary.withValues(alpha: 0.2),
          width: MiuiSpace.dividerThickness,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 时间显示
          Icon(
            Icons.schedule,
            size: 12,
            color: MiuiColors.primaryVariant.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 4),
          Text(
            gp.worldState.timestamp,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: MiuiColors.primaryVariant.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  /// 资源胶囊条（参考图风格：紧凑中性胶囊，低值转红）
  Widget _buildResourceBars(Player player) {
    final resources = <({IconData icon, int value})>[
      (icon: Icons.favorite, value: player.health),
      (icon: Icons.auto_awesome, value: player.magic),
      (icon: Icons.psychology, value: player.spirit),
      (icon: Icons.restaurant, value: player.satiety),
      (icon: Icons.flash_on, value: player.energy),
    ];
    return SizedBox(
      height: 28,
      child: Row(
        children: List.generate(resources.length, (i) {
          final r = resources[i];
          final low = r.value < 30;
          final accent = low ? MiuiColors.error : MiuiColors.primaryVariant;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < resources.length - 1 ? 4 : 0),
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: MiuiColors.surfaceContainerHigh.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.25),
                    width: MiuiSpace.dividerThickness,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(r.icon, size: 11, color: accent),
                    const SizedBox(width: 2),
                    Text(
                      '${r.value}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
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

