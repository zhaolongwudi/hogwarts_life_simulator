import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/game_provider.dart';
import '../screens/save_load_screen.dart';
import '../theme/miuix_tokens.dart';
import '../theme/miuix_typography.dart';
import '../utils/ui_helpers.dart';
import '../widgets/miui_magic_backdrop.dart';
import '../widgets/miuix_components.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final gameProvider = context.watch<GameProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0A0C), Color(0xFF111216)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 魔法辉光背景
            const MiuiMagicBackdrop(density: 0.7),
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 28),
                    _buildHeader(theme),
                    const SizedBox(height: 36),
                    _buildBadge(),
                    const SizedBox(height: 36),
                    if (appProvider.isGameStarted && gameProvider.player != null)
                      _buildGameStatus(context, gameProvider, theme),
                    if (!appProvider.hasAnyKey && !appProvider.offlineQuickMode)
                      _buildAiSetupHint(context, theme),
                    const SizedBox(height: 28),
                    _buildActions(context, theme),
                    const SizedBox(height: 32),
                    Text(
                      'v1.0.0+100 | AI Powered · HyperOS Edition',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: MiuiColors.onSurfaceVariantSummary),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        const Text(
          '魔法人生模拟器',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w600,
            color: MiuiColors.onBackground,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Hogwarts Life Simulator',
          style: MiuiType.body2.copyWith(
            color: MiuiColors.onSurfaceVariantSummary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: MiuiColors.tertiaryContainer,
            borderRadius: BorderRadius.circular(MiuiRadius.pill),
            border: Border.all(
              color: MiuiColors.primary.withValues(alpha: 0.35),
            ),
          ),
          child: const Text(
            '✨ 你的魔法人生 awaits',
            style: TextStyle(
              color: MiuiColors.primaryVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// 首页徽章：HyperOS 式大圆角质感 + 金色符文环。
  Widget _buildBadge() {
    return Container(
      width: 148,
      height: 148,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF2A2110), Color(0xFF0D0C08)],
          stops: [0.0, 1.0],
        ),
        border: Border.all(color: MiuiColors.primaryVariant, width: 2),
        boxShadow: [
          BoxShadow(
            color: MiuiColors.primary.withValues(alpha: 0.28),
            blurRadius: 34,
            spreadRadius: 6,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 内侧细环
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: MiuiColors.primary.withValues(alpha: 0.4),
                width: 0.75,
              ),
            ),
          ),
          // 中心符文光
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  MiuiColors.primary.withValues(alpha: 0.22),
                  Colors.transparent,
                ],
              ),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 42,
              color: MiuiColors.primaryVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameStatus(
    BuildContext context,
    GameProvider gp,
    ThemeData theme,
  ) {
    final player = gp.player!;
    // BUG-2 分院前最终防线：只有成就 'sorted' 已解锁，player.house 才真正生效
    final sortedUnlocked = player.achievements.contains('sorted');
    final effectiveHouse = sortedUnlocked ? player.house : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: MiuiCard(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        onTap: () => Navigator.pushNamed(context, '/game'),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      UiHelpers.getHouseColorBright(effectiveHouse ?? ''),
                  child: Text(
                    player.name.isNotEmpty
                        ? player.name.substring(0, 1).toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(player.name, style: MiuiType.headline1),
                      Text(
                        '${effectiveHouse ?? '未分院'} · ${gp.worldState.academicYear}',
                        style: MiuiType.body2,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: MiuiColors.tertiaryContainer,
                    borderRadius: BorderRadius.circular(MiuiRadius.pill),
                  ),
                  child: Text(
                    '第 ${gp.turnCount} 回合',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: MiuiColors.primaryVariant,
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: MiuiSpace.dividerThickness),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('📅', '${gp.worldState.month} ${gp.worldState.dayOfMonth}日'),
                _buildStatItem('🏛️', effectiveHouse ?? '待分院'),
                _buildStatItem('❤️', '${player.health}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String icon, String value) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: MiuiType.footnote1.copyWith(color: MiuiColors.onSurface),
        ),
      ],
    );
  }

  /// P0-4 新手引导：还没配 AI Key 时给一条醒目的提示。
  Widget _buildAiSetupHint(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MiuiCard(
        onTap: () => Navigator.pushNamed(context, '/settings'),
        color: MiuiColors.warningContainer,
        radius: 16,
        child: const Row(
          children: [
            Text('🎯', style: TextStyle(fontSize: 20)),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '还没配置 AI Key',
                    style: TextStyle(
                      color: MiuiColors.warning,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '剧情由 AI 生成，需要先在设置里填入 API Key；'
                    '也可以开启「无 AI 快速模式」完全离线游玩。',
                    style: TextStyle(
                      color: MiuiColors.onSurfaceSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: MiuiColors.onSurfaceVariantActions),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, ThemeData theme) {
    final appProvider = context.read<AppProvider>();
    return Column(
      children: [
        MiuiListSection(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          children: [
            MiuiListItem(
              title: appProvider.isGameStarted ? '继续冒险' : '开始新人生',
              subtitle: appProvider.isGameStarted
                  ? '${context.read<GameProvider>().player?.name ?? ''} 的故事'
                  : '创建全新的巫师角色',
              leading: const _ActionIcon(emoji: '⚡', color: MiuiColors.primaryVariant),
              trailing: const Icon(Icons.chevron_right),
              showDivider: true,
              onTap: () => Navigator.pushNamed(
                context,
                appProvider.isGameStarted ? '/game' : '/intro',
              ),
            ),
            MiuiListItem(
              title: '存档 / 读档',
              subtitle: '管理你的游戏进度',
              leading: const _ActionIcon(emoji: '📚', color: MiuiColors.info),
              trailing: const Icon(Icons.chevron_right),
              showDivider: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SaveLoadScreen()),
              ),
            ),
            MiuiListItem(
              title: '设置',
              subtitle: 'API Key、显示模式、时代选择',
              leading: const _ActionIcon(emoji: '⚙️', color: MiuiColors.success),
              trailing: const Icon(Icons.chevron_right),
              showDivider: false,
              onTap: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.emoji, required this.color});

  final String emoji;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 20)),
    );
  }
}
