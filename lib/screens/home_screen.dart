import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/game_provider.dart';
import '../screens/save_load_screen.dart';
import '../utils/ui_helpers.dart';

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
            colors: [Color(0xFF0d1117), Color(0xFF161b22)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildHeader(theme),
                const SizedBox(height: 40),
                _buildBadge(theme),
                const SizedBox(height: 30),
                if (appProvider.isGameStarted && gameProvider.player != null)
                  _buildGameStatus(gameProvider, theme),
                const Spacer(),
                _buildActions(context, theme),
                const SizedBox(height: 30),
                Text(
                  'v0.5.7+57 | AI Powered',
                  style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF8B949E)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        Text(
          '魔法人生模拟器',
          style: theme.textTheme.displayLarge?.copyWith(
                fontSize: 32,
                letterSpacing: 2,
              ),
        ),
        const SizedBox(height: 8),
        Text('Hogwarts Life Simulator',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 14)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF740001).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF740001)),
          ),
          child: Text(
            '✨ 你的魔法人生 awaits',
            style: theme.textTheme.labelMedium?.copyWith(
                  color: const Color(0xFFD3A625),
                  fontSize: 12,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(ThemeData theme) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(colors: [Color(0xFF2a1f0e), Color(0xFF1a1508)]),
        border: Border.all(color: const Color(0xFFD3A625), width: 3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD3A625).withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Icon(Icons.auto_awesome, size: 70, color: Color(0xFFD3A625)),
    );
  }

  Widget _buildGameStatus(GameProvider gp, ThemeData theme) {
    final player = gp.player!;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: UiHelpers.getHouseColor(player.house ?? ''),
                  child: Text(
                    player.name.isNotEmpty ? player.name.substring(0, 1).toUpperCase() : '?',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(player.name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFD3A625))),
                      Text('${player.house ?? '未分院'} · ${gp.worldState.academicYear}',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0d1117),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Text('第 ${gp.turnCount} 回合',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('📅', '${gp.worldState.month} ${gp.worldState.dayOfMonth}日', theme),
                _buildStatItem('🏛️', player.house ?? '待分院', theme),
                _buildStatItem('❤️', '${player.health}%', theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String icon, String value, ThemeData theme) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
      ],
    );
  }

  Widget _buildActions(BuildContext context, ThemeData theme) {
    final appProvider = context.read<AppProvider>();
    return Column(
      children: [
        _buildActionButton(
          context,
          theme,
          icon: '⚡',
          title: appProvider.isGameStarted ? '继续冒险' : '开始新人生',
          subtitle: appProvider.isGameStarted
              ? '${context.read<GameProvider>().player?.name ?? ''} 的故事'
              : '创建全新的巫师角色',
          onTap: () => Navigator.pushNamed(
            context,
            appProvider.isGameStarted ? '/game' : '/intro',
          ),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          context,
          theme,
          icon: '📚',
          title: '存档 / 读档',
          subtitle: '管理你的游戏进度',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SaveLoadScreen()),
          ),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          context,
          theme,
          icon: '⚙️',
          title: '设置',
          subtitle: 'API Key、显示模式、时代选择',
          onTap: () => Navigator.pushNamed(context, '/settings'),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    ThemeData theme, {
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE6EDF3))),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
