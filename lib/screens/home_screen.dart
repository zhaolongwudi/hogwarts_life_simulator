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
                if (!appProvider.hasAnyKey && !appProvider.offlineQuickMode)
                  _buildAiSetupHint(context, theme),
                const SizedBox(height: 20),
                const Spacer(),
                _buildActions(context, theme),
                const SizedBox(height: 30),
                Text(
                  'v1.0.0+100 | AI Powered',
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
    // BUG-2 分院前最终防线：只有成就 'sorted' 已解锁，player.house 才真正生效
    // （即使AI文本OOC解析把 house 写错了，也不显示学院颜色/标签，避免分院前就挂错学院）
    final sortedUnlocked = player.achievements.contains('sorted');
    final effectiveHouse = sortedUnlocked ? player.house : null;
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
                  backgroundColor: UiHelpers.getHouseColor(effectiveHouse ?? ''),
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
                      Text('${effectiveHouse ?? '未分院'} · ${gp.worldState.academicYear}',
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
                _buildStatItem('🏛️', effectiveHouse ?? '待分院', theme),
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

  /// P0-4 新手引导：还没配 AI Key 时给一条醒目的提示（第一道断崖的工程侧缓解）。
  Widget _buildAiSetupHint(BuildContext context, ThemeData theme) {
    final appProvider = context.read<AppProvider>();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Material(
        color: const Color(0xFF7A2E0E).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.pushNamed(context, '/settings'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Text('🎯', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '还没配置 AI Key',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: const Color(0xFFD3A625),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '剧情由 AI 生成，需要先在设置里填入 API Key；'
                        '也可以开启「无 AI 快速模式」完全离线游玩。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFC9D1D9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF8B949E)),
              ],
            ),
          ),
        ),
      ),
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
