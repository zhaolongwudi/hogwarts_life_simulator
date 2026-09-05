import 'package:flutter/material.dart';

import '../theme/miuix_motion.dart';
import '../theme/miuix_tokens.dart';
import '../theme/miuix_typography.dart';
import 'liquid_glass.dart';

/// 导航栏条目。
class LiquidNavItem {
  const LiquidNavItem({
    required this.icon,
    required this.label,
    this.activeIcon,
  });

  final IconData icon;
  final IconData? activeIcon;
  final String label;
}

/// 悬浮液态玻璃导航栏。
///
/// 融合了两部分设计：
/// * **Miuix FloatingNavigationBar** —— 悬浮药丸外形、52dp 最小高度、
///   选中靠 alpha + 字重表达（而非 Material 的指示器胶囊）、按压 Sink 缩放；
/// * **AndroidLiquidGlass LiquidBottomTabs** —— 玻璃主体的折射参数
///   （blur 8 / refraction 24×24，高度 64dp），以及选中滑块的
///   小尺寸高折射 + 色散（refraction 10×14 / chromaticAberration）。
///
/// 结构上与 LiquidBottomTabs 一致：主体与滑块各占一层玻璃，滑块在上。
/// 全屏同时存在的 BackdropFilter 数量为 2，在推荐上限内。
class LiquidGlassNavBar extends StatelessWidget {
  const LiquidGlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.height = MiuiSpace.floatingNavMinHeight,
    this.horizontalPadding = MiuiSpace.floatingNavOutside,
    this.bottomPadding = 26,
    this.enableChromaticAberration = true,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<LiquidNavItem> items;

  /// 药丸高度。原作 LiquidBottomTabs 为 64，Miuix FloatingNavigationBar 为 52。
  final double height;

  /// 距屏幕左右边缘的距离。
  final double horizontalPadding;

  /// 距屏幕底部的距离。
  final double bottomPadding;

  /// 选中滑块是否启用色散（成本约为普通折射的 7 倍）。
  final bool enableChromaticAberration;

  /// 滑块与玻璃边缘的内缩量。
  static const double _inset = 4;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: horizontalPadding,
        right: horizontalPadding,
        bottom: bottomPadding,
      ),
      child: SizedBox(
        height: height,
        child: _NavBarShell(
          height: height,
          currentIndex: currentIndex,
          items: items,
          onTap: onTap,
          inset: _inset,
          enableChromaticAberration: enableChromaticAberration,
        ),
      ),
    );
  }
}

class _NavBarShell extends StatelessWidget {
  const _NavBarShell({
    required this.height,
    required this.currentIndex,
    required this.items,
    required this.onTap,
    required this.inset,
    required this.enableChromaticAberration,
  });

  final double height;
  final int currentIndex;
  final List<LiquidNavItem> items;
  final ValueChanged<int> onTap;
  final double inset;
  final bool enableChromaticAberration;

  @override
  Widget build(BuildContext context) {
    const radius = MiuiRadius.pill;

    // Miuix FloatingNavigationBar 的投影：Shadow(10.dp, Black, 0.2f)
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(radius)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / items.length;
          final sliderWidth = itemWidth - inset * 2;
          final sliderHeight = height - inset * 2;

          return Stack(
            children: [
              // ① 玻璃主体：模糊 + 折射
              const Positioned.fill(
                child: RepaintBoundary(
                  child: LiquidGlass(
                    radius: radius,
                    blurRadius: 8,
                    refractionHeight: 24,
                    refractionAmount: 24,
                  ),
                ),
              ),

              // ② 选中滑块：小尺寸高折射 + 色散，跟随 index 弹簧位移
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: currentIndex.toDouble(), end: currentIndex.toDouble()),
                duration: SpringCurve
                    .by(dampingRatio: 0.9, stiffness: 438.6)
                    .duration,
                curve: SpringCurve.by(dampingRatio: 0.9, stiffness: 438.6),
                builder: (context, value, _) {
                  return Positioned(
                    left: inset + value * itemWidth,
                    top: inset,
                    width: sliderWidth,
                    height: sliderHeight,
                    child: RepaintBoundary(
                      child: LiquidGlass(
                        radius: sliderHeight / 2,
                        blurRadius: 4,
                        refractionHeight: 10,
                        refractionAmount: 14,
                        chromaticAberration: enableChromaticAberration,
                        highlightIntensity: 0.65,
                        surfaceAlpha: 0.22,
                      ),
                    ),
                  );
                },
              ),

              // ③ 图标与文字
              Positioned.fill(
                child: Row(
                  children: List.generate(items.length, (i) {
                    return Expanded(
                      child: _NavBarButton(
                        item: items[i],
                        selected: i == currentIndex,
                        onTap: () {
                          if (i != currentIndex) {
                            MiuiMotion.textHandleMove();
                            onTap(i);
                          }
                        },
                      ),
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 单个导航按钮：Miuix 的选中表达（alpha + 字重）+ 按压缩放。
class _NavBarButton extends StatefulWidget {
  const _NavBarButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final LiquidNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavBarButton> createState() => _NavBarButtonState();
}

class _NavBarButtonState extends State<_NavBarButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      value: 1.0,
      duration: SpringCurve(MiuiMotion.sink).duration,
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    _pressed = value;
    if (value) {
      _pressCtrl.animateTo(0.0, curve: SpringCurve(MiuiMotion.sink));
    } else {
      _pressCtrl.animateTo(1.0, curve: SpringCurve(MiuiMotion.sink));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final icon =
        selected ? (widget.item.activeIcon ?? widget.item.icon) : widget.item.icon;

    // Miuix：未选中 alpha 0.4；选中全不透明且标签加粗
    final contentColor = selected
        ? MiuiColors.primaryVariant
        : MiuiColors.onSurface.withValues(alpha: 0.4);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pressCtrl,
        builder: (context, child) {
          // Sink：1.0 → 0.94
          final scale = 1.0 - (1.0 - MiuiMotion.sinkAmount) * (1.0 - _pressCtrl.value);
          return Transform.scale(scale: scale, child: child);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: MiuiSpace.floatingNavIcon, color: contentColor),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: MiuiMotion.navDuration,
              curve: Curves.easeOut,
              style: (selected ? MiuiType.navLabelSelected : MiuiType.navLabel)
                  .copyWith(
                color: contentColor,
              ),
              child: Text(widget.item.label),
            ),
          ],
        ),
      ),
    );
  }
}
