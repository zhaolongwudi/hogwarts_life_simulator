import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/game_provider.dart';
import '../screens/save_load_screen.dart';
import '../theme/miuix_tokens.dart';
import '../theme/miuix_typography.dart';
import '../widgets/miui_magic_backdrop.dart';

/// 首页 = HyperOS「个人中心」式排版。
///
/// 设计语言（对应 Miuix 深色规范）：
/// * 一个视觉重心：顶部 Hero（未开局 = 金徽章入学卡；已开局 = 玩家头像卡）
/// * 克制用色：金色只出现在徽章 / 主按钮 / 图标与数值，其余全部中性表面
/// * 无描边卡片：大块 surface 同色分区，靠间距与字重分层，不做游戏 HUD
/// * 功能入口收成底部「坞」（3 个磁块），屏幕上下节奏均衡
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
            colors: [Color(0xFF0D0C10), Color(0xFF16141B)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 辉光微弱打底：暗色表面不至于死黑
            const MiuiMagicBackdrop(density: 0.55),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxH = constraints.maxHeight;
                  final topPad = maxH * 0.055;
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(24, topPad, 24, 12),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: maxH - topPad - 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (started)
                            _PlayerHero(
                              gameProvider: gameProvider,
                              onEnter: () =>
                                  Navigator.pushNamed(context, '/game'),
                            )
                          else
                            _WelcomeHero(
                              onStart: () =>
                                  Navigator.pushNamed(context, '/intro'),
                              onSaves: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SaveLoadScreen(),
                                ),
                              ),
                            ),
                          const SizedBox(height: 28),
                          _Dock(
                            started: started,
                            onSaves: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SaveLoadScreen(),
                              ),
                            ),
                            onSettings: () =>
                                Navigator.pushNamed(context, '/settings'),
                            offlineOn: appProvider.offlineQuickMode,
                            onOfflineMode: () => context
                                .read<AppProvider>()
                                .setOfflineQuickMode(
                                  !context.read<AppProvider>().offlineQuickMode,
                                ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'v1.0.0+100 · HyperOS Edition',
                            textAlign: TextAlign.center,
                            style: MiuiType.footnote2.copyWith(
                              color: MiuiColors.onSurfaceVariantSummary
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 主行动金按钮：HyperOS 的实心金胶囊（大圆角、无阴影、深字）。
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [MiuiColors.primaryVariant, MiuiColors.primary],
          ),
          borderRadius: BorderRadius.circular(MiuiRadius.button),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: MiuiColors.onPrimary),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: MiuiColors.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 未开局：金徽章入学 Hero
// ============================================================================
class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({
    required this.onStart,
    required this.onSaves,
  });

  final VoidCallback onStart;
  final VoidCallback onSaves;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 18),
        // 金徽章：HyperOS「应用图标」式的视觉重心
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MiuiColors.primaryVariant, MiuiColors.primary],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: MiuiColors.primary.withValues(alpha: 0.25),
                blurRadius: 32,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.auto_awesome,
            size: 46,
            color: MiuiColors.onPrimary,
          ),
        ),
        const SizedBox(height: 26),
        const Text(
          '魔法人生模拟器',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: MiuiColors.primaryVariant,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'HOGWARTS LIFE SIMULATOR',
          style: MiuiType.footnote1.copyWith(
            color: MiuiColors.onSurfaceVariantSummary,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '一段以你为主角的霍格沃茨魔法人生',
          style: MiuiType.body2.copyWith(
            color: MiuiColors.onSurfaceVariantSummary,
          ),
        ),
        const SizedBox(height: 36),
        _PrimaryButton(
          label: '开始新人生',
          icon: Icons.auto_awesome,
          onTap: onStart,
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: onSaves,
          child: Text(
            '从存档继续',
            style: MiuiType.body2.copyWith(
              color: MiuiColors.onSurfaceVariantSummary,
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

// ============================================================================
// 已开局：玩家 Hero（头像 + 资源点 + 进入）
// ============================================================================
class _PlayerHero extends StatelessWidget {
  const _PlayerHero({
    required this.gameProvider,
    required this.onEnter,
  });

  final GameProvider gameProvider;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final player = gameProvider.player!;
    final houseUnlocked = player.achievements.contains('sorted');
    final house = houseUnlocked ? player.house : null;
    final houseCn = {
      'Gryffindor': '格兰芬多',
      'Slytherin': '斯莱特林',
      'Ravenclaw': '拉文克劳',
      'Hufflepuff': '赫奇帕奇',
    }[house ?? ''];

    final low = player.health < 30 || player.magic < 30 || player.energy < 30;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MiuiColors.surfaceContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // 大头像 + 金色光环
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      MiuiColors.primary.withValues(alpha: 0.55),
                      MiuiColors.primary.withValues(alpha: 0.12),
                    ],
                  ),
                  border: Border.all(
                    color: MiuiColors.primary.withValues(alpha: 0.7),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  player.name.isNotEmpty
                      ? player.name.substring(0, 1).toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: MiuiColors.primaryVariant,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: MiuiColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (houseCn != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: MiuiColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              houseCn,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: MiuiColors.onSurfaceSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${gameProvider.worldState.academicYear} · 第 ${gameProvider.turnCount} 回合',
                              maxLines: 1,
                              style: MiuiType.footnote1.copyWith(
                                color: MiuiColors.onSurfaceVariantSummary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          // 资源点：中性小胶囊 + 金色图标/数值（低值才转红）
          Row(
            children: [
              _dot(Icons.favorite, player.health),
              const SizedBox(width: 8),
              _dot(Icons.auto_awesome, player.magic),
              const SizedBox(width: 8),
              _dot(Icons.flash_on, player.energy),
              const SizedBox(width: 8),
              _dot(Icons.monetization_on, player.galleons),
            ],
          ),
          const SizedBox(height: 24),
          _PrimaryButton(
            label: '进入魔法世界',
            icon: Icons.arrow_forward,
            onTap: onEnter,
          ),
          if (low) ...[
            const SizedBox(height: 10),
            Text(
              '你的状态不佳，建议先休息或进食',
              textAlign: TextAlign.center,
              style: MiuiType.footnote1.copyWith(
                color: MiuiColors.error.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dot(IconData icon, int value) {
    final danger = value < 30;
    final color = danger ? MiuiColors.error : MiuiColors.primaryVariant;
    return Expanded(
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: MiuiColors.surfaceContainerHigh.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: danger ? MiuiColors.error : MiuiColors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 底部坞：存档 / 设置 / 无 AI 快速模式
// ============================================================================
class _Dock extends StatelessWidget {
  const _Dock({
    required this.started,
    required this.onSaves,
    required this.onSettings,
    required this.offlineOn,
    required this.onOfflineMode,
  });

  final bool started;
  final VoidCallback onSaves;
  final VoidCallback onSettings;
  final bool offlineOn;
  final VoidCallback onOfflineMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DockTile(
            icon: Icons.save_outlined,
            label: '存档读档',
            onTap: onSaves,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DockTile(
            icon: Icons.settings_outlined,
            label: '设置',
            onTap: onSettings,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DockTile(
            icon: Icons.bolt_outlined,
            label: '无 AI 模式',
            trailing: offlineOn,
            onTap: onOfflineMode,
          ),
        ),
      ],
    );
  }
}

class _DockTile extends StatelessWidget {
  const _DockTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// true = 点亮态（无 AI 模式启用：金色徽标）
  final bool trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 92,
        decoration: BoxDecoration(
          color: trailing
              ? MiuiColors.primary.withValues(alpha: 0.16)
              : MiuiColors.surfaceContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: trailing
                ? MiuiColors.primary.withValues(alpha: 0.45)
                : MiuiColors.outline.withValues(alpha: 0.35),
            width: MiuiSpace.dividerThickness,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: trailing
                  ? MiuiColors.primaryVariant
                  : MiuiColors.onSurfaceSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: trailing
                    ? MiuiColors.primaryVariant
                    : MiuiColors.onSurfaceSecondary,
              ),
            ),
            if (trailing) ...[
              const SizedBox(height: 3),
              const Text(
                '已开启',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: MiuiColors.primaryVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
