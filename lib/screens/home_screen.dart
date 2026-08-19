import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/game_provider.dart';
import '../screens/save_load_screen.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final gameProvider = context.watch<GameProvider>();

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0d1117), Color(0xFF161b22)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildHeader(),
                  const SizedBox(height: 40),
                  _buildBadge(),
                  const SizedBox(height: 30),
                  if (appProvider.isGameStarted && gameProvider.player != null)
                    _buildGameStatus(gameProvider),
                  const Spacer(),
                  _buildActions(context),
                  const SizedBox(height: 30),
                  Text(
                    'v1.0.0 | DeepSeek Powered',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white38,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Text(
          '魔法人生模拟器',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFFD3A625),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Hogwarts Life Simulator',
          style: TextStyle(fontSize: 14, color: Colors.grey[400]),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF740001).withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF740001)),
          ),
          child: const Text(
            '✨ 你的魔法人生 awaits',
            style: TextStyle(fontSize: 12, color: Color(0xFFD3A625)),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF2a1f0e), Color(0xFF1a1508)],
        ),
        border: Border.all(color: const Color(0xFFD3A625), width: 3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD3A625).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Icon(
        Icons.auto_awesome,
        size: 70,
        color: Color(0xFFD3A625),
      ),
    );
  }

  Widget _buildGameStatus(GameProvider gp) {
    final player = gp.player!;
    return Card(
      color: const Color(0xFF161b22).withOpacity(0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF30363d)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _getHouseColor(player.house ?? ''),
                  child: Text(
                    player.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
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
                      Text(
                        player.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD3A625),
                        ),
                      ),
                      Text(
                        '${player.house ?? '未分院'} · ${gp.worldState.academicYear}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF21262d),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '第 ${gp.turnCount} 回合',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const Divider(color: Color(0xFF30363d)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('📅', '${gp.worldState.month} ${gp.worldState.dayOfMonth}日'),
                _buildStatItem('🏛️', player.house ?? '待分院'),
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
        Text(value, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    final appProvider = context.read<AppProvider>();
    return Column(
      children: [
        _buildActionButton(
          context,
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
          icon: '⚙️',
          title: '设置',
          subtitle: 'API Key、显示模式、时代选择',
          onTap: () => Navigator.pushNamed(context, '/settings'),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF21262d),
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Color _getHouseColor(String house) {
    return switch (house.toLowerCase()) {
      'gryffindor' => const Color(0xFF740001),
      'slytherin' => const Color(0xFF1a472a),
      'ravenclaw' => const Color(0xFF0e1a40),
      'hufflepuff' => const Color(0xFFecbe22),
      _ => Colors.grey,
    };
  }
}
