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

/// 首页 = HyperOS 桌面式磁贴。
///
/// 结构：中央标题 → 个人磁贴（已开局显示角色卡；未开局显示「开始」引导卡）
/// → AI Key 提示 → 2×2 功能磁贴（继续/存档/设置/无AI）。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final gameProvider = context.watch<GameProvider>();
    final started = appProvider.isGameStarted && gameProvider.player != null;

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
            const MiuiMagicBackdrop(density: 0.7),
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  children: [
                    const Text(
                      '魔法人生模拟器',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: MiuiColors.primaryVariant,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'HOGWARTS LIFE SIMULATOR',
                      style: MiuiType.body2.copyWith(
                        color: MiuiColors.onSurfaceVariantSummary,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (started)
                      _PlayerTile(gameProvider: gameProvider)
                    else
                      _WelcomeTile(appProvider: appProvider),
                    const SizedBox(height: 16),

                    if (!appProvider.hasAnyKey &&
                        !appProvider.offlineQuickMode)
                      _AiHintTile(context),

                    const SizedBox(height: 20),
                    _FunctionGrid(
                      started: started,
                      onContinue: () => Navigator.pushNamed(
                        context,
                        started ? '/game' : '/intro',
                      ),
                      onSaves: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SaveLoadScreen(),
                        ),
                      ),
                      onSettings: () =>
                          Navigator.pushNamed(context, '/settings'),
                      offlineOn: appProvider.offlineQuickMode,
                      onOfflineMode: () =>
                          context.read<AppProvider>().setOfflineQuickMode(
                              !context.read<AppProvider>().offlineQuickMode),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'v1.0.0+100 | AI Powered · HyperOS Edition',
                      style: MiuiType.footnote2.copyWith(
                        color: MiuiColors.onSurfaceVariantSummary,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 已开局：角色磁贴
// ============================================================================
class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.gameProvider});

  final GameProvider gameProvider;

  @override
  Widget build(BuildContext context) {
    final player = gameProvider.player!;
    final houseUnlocked = player.achievements.contains('sorted');
    final house = houseUnlocked ? player.house : null;
    final houseColor = UiHelpers.getHouseColorBright(house ?? '');

    return MiuiCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: houseColor.withValues(alpha: 0.22),
                  border: Border.all(
                    color: MiuiColors.primary.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  player.name.isNotEmpty
                      ? player.name.substring(0, 1).toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: houseColor,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: MiuiColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${house ?? '未分院'} · ${gameProvider.worldState.academicYear} · 第 ${gameProvider.turnCount} 回合',
                        maxLines: 1,
                        style: MiuiType.body2.copyWith(
                          color: MiuiColors.onSurfaceVariantSummary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/game'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: MiuiColors.tertiaryContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: MiuiColors.primary.withValues(alpha: 0.4),
                      width: MiuiSpace.dividerThickness,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '进入',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: MiuiColors.primaryVariant,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward,
                          size: 14, color: MiuiColors.primaryVariant),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ResourceChips(
            health: player.health,
            magic: player.magic,
            energy: player.energy,
            galleons: player.galleons,
          ),
        ],
      ),
    );
  }
}

class _ResourceChips extends StatelessWidget {
  const _ResourceChips({
    required this.health,
    required this.magic,
    required this.energy,
    required this.galleons,
  });

  final int health;
  final int magic;
  final int energy;
  final int galleons;

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData icon, int value, Color color) {
      return Expanded(
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withValues(alpha: 0.35),
              width: MiuiSpace.dividerThickness,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(Icons.favorite, health, MiuiColors.error),
        const SizedBox(width: 6),
        chip(Icons.auto_awesome, magic, const Color(0xFF60A5FA)),
        const SizedBox(width: 6),
        chip(Icons.flash_on, energy, MiuiColors.success),
        const SizedBox(width: 6),
        chip(Icons.monetization_on, galleons, MiuiColors.primaryVariant),
      ],
    );
  }
}

// ============================================================================
// 未开局：欢迎引导磁贴
// ============================================================================
class _WelcomeTile extends StatelessWidget {
  const _WelcomeTile({required this.appProvider});

  final AppProvider appProvider;

  @override
  Widget build(BuildContext context) {
    return MiuiCard(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
      radius: 24,
      onTap: () => Navigator.pushNamed(context, '/intro'),
      child: Column(
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFF2A2110), Color(0xFF0D0C08)],
              ),
              border:
                  Border.all(color: MiuiColors.primaryVariant, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: MiuiColors.primary.withValues(alpha: 0.25),
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: MiuiColors.primary.withValues(alpha: 0.4),
                      width: 0.75,
                    ),
                  ),
                ),
                const Icon(
                  Icons.auto_awesome,
                  size: 34,
                  color: MiuiColors.primaryVariant,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '准备入学霍格沃茨',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: MiuiColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '从一次分院开始，书写只属于你的巫师故事',
            style: MiuiType.body2.copyWith(
              color: MiuiColors.onSurfaceVariantSummary,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: MiuiColors.primary,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: MiuiColors.primary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '创建你的巫师',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: MiuiColors.onPrimary,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward,
                    size: 16, color: MiuiColors.onPrimary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// AI Key 提示
// ============================================================================
class _AiHintTile extends StatelessWidget {
  const _AiHintTile(this.context);

  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: MiuiCard(
        color: MiuiColors.warningContainer,
        radius: 18,
        onTap: () => Navigator.pushNamed(context, '/settings'),
        child: const Row(
          children: [
            Text('🎯', style: TextStyle(fontSize: 18)),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '还没配置 AI Key',
                    style: TextStyle(
                      color: MiuiColors.warning,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '设置里填入 API Key 即可让 AI 生成剧情；或开启无 AI 快速模式',
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
}

// ============================================================================
// 2×2 功能磁贴
// ============================================================================
class _FunctionGrid extends StatelessWidget {
  const _FunctionGrid({
    required this.started,
    required this.onContinue,
    required this.onSaves,
    required this.onSettings,
    required this.onOfflineMode,
    required this.offlineOn,
  });

  final bool started;
  final VoidCallback onContinue;
  final VoidCallback onSaves;
  final VoidCallback onSettings;
  final VoidCallback onOfflineMode;
  final bool offlineOn;

  @override
  Widget build(BuildContext context) {
    Widget row(Widget a, Widget b) => Row(
          children: [
            Expanded(child: a),
            const SizedBox(width: 12),
            Expanded(child: b),
          ],
        );

    return Column(
      children: [
        row(
          _Tile(
            icon: Icons.auto_stories_outlined,
            iconColor: MiuiColors.primaryVariant,
            title: started ? '继续冒险' : '开始新人生',
            subtitle: started ? '回到你的故事' : '创建角色',
            onTap: onContinue,
          ),
          _Tile(
            icon: Icons.save_outlined,
            iconColor: const Color(0xFF60A5FA),
            title: '存档 / 读档',
            subtitle: '管理进度',
            onTap: onSaves,
          ),
        ),
        const SizedBox(height: 12),
        row(
          _Tile(
            icon: Icons.tune,
            iconColor: const Color(0xFFA78BFA),
            title: '设置',
            subtitle: 'Key / 时代 / 模式',
            onTap: onSettings,
          ),
          _Tile(
            icon: offlineOn ? Icons.offline_bolt : Icons.cloud_outlined,
            iconColor: MiuiColors.success,
            title: '无 AI 快速模式',
            subtitle: offlineOn ? '已开启' : '完全离线',
            onTap: onOfflineMode,
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MiuiCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: MiuiColors.onSurface,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            style: MiuiType.body2.copyWith(
              color: MiuiColors.onSurfaceVariantSummary,
            ),
          ),
        ],
      ),
    );
  }
}
