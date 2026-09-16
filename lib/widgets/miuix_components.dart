import 'package:flutter/material.dart';

import '../theme/miuix_motion.dart';
import '../theme/miuix_tokens.dart';
import '../theme/miuix_typography.dart';

/// Miuix 按压反馈。
///
/// Material 用水波纹（从触点扩散的 ripple），Miuix 用**整体缩放到 0.94**
/// （Sink）或**朝触点方向 3D 倾斜 8°**（Tilt），再叠一层极淡的黑色（10%）。
/// 这是两套语言手感差异最大的地方。
class MiuiPressFeedback extends StatefulWidget {
  const MiuiPressFeedback({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.sinkAmount = MiuiMotion.sinkAmount,
    this.tilt = false,
    this.borderRadius,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;

  /// 按压缩放目标值；1.0 表示不缩放。
  final double sinkAmount;

  /// 是否用 3D 倾斜代替缩放。
  final bool tilt;

  /// 叠加层的圆角（需与 child 形状一致）。
  final BorderRadius? borderRadius;

  final String? semanticLabel;

  @override
  State<MiuiPressFeedback> createState() => _MiuiPressFeedbackState();
}

class _MiuiPressFeedbackState extends State<MiuiPressFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  Offset _localPosition = Offset.zero;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      value: 1.0,
      duration: SpringCurve(MiuiMotion.sink).duration,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _down(Offset local, Size size) {
    _localPosition = local;
    _size = size;
    _ctrl.animateTo(0.0, curve: SpringCurve(MiuiMotion.sink));
  }

  void _up() {
    _ctrl.animateTo(1.0, curve: SpringCurve(MiuiMotion.sink));
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.borderRadius ?? MiuiRadius.cardRadius;

    Widget content = AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = 1.0 - _ctrl.value; // 0=未按，1=完全按下
        final scale = 1.0 - (1.0 - widget.sinkAmount) * t;

        Widget out = child!;
        if (widget.tilt && _size != Size.zero) {
          // Tilt：按触点所在象限决定旋转方向，cameraDistance 12×density
          final nx = (_localPosition.dx / _size.width) * 2 - 1;
          final ny = (_localPosition.dy / _size.height) * 2 - 1;
          final deg = MiuiMotion.tiltDegrees * t;
          out = Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              // 透视强度取屏幕像素比的 12 倍，与原作 cameraDistance 一致
              ..setEntry(3, 2, 0.001 * 12)
              ..rotateY(-nx * deg * 3.141592653589793 / 180)
              ..rotateX(ny * deg * 3.141592653589793 / 180),
            child: out,
          );
        } else {
          out = Transform.scale(scale: scale, child: out);
        }

        // 状态层：极淡黑叠加，替代 Material ripple
        return Stack(
          fit: StackFit.passthrough,
          children: [
            out,
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: ColoredBox(
                    color: Colors.black
                        .withValues(alpha: MiuiMotion.pressAlphaDelta * t),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: widget.child,
    );

    if (!widget.enabled) {
      content = Opacity(opacity: 0.45, child: content);
    }

    return Semantics(
      label: widget.semanticLabel,
      button: widget.onTap != null,
      enabled: widget.enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled
            ? (d) => _down(d.localPosition, context.size ?? Size.zero)
            : null,
        onTapUp: widget.enabled ? (_) => _up() : null,
        onTapCancel: widget.enabled ? _up : null,
        onTap: widget.enabled ? widget.onTap : null,
        onLongPress: widget.enabled ? widget.onLongPress : null,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 记录尺寸供 Tilt 计算触点归一化坐标
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _size = Size(constraints.maxWidth, constraints.maxHeight);
              }
            });
            return content;
          },
        ),
      ),
    );
  }
}

/// Miuix 卡片：16dp 圆角、surfaceContainer 底、默认零内边距。
///
/// 内边距由调用方决定——这是 Miuix 与 Material Card 的一个显著差异
/// （Material Card 自带 margin，Miuix Card 的 InsideMargin 是 0）。
class MiuiCard extends StatelessWidget {
  const MiuiCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(MiuiSpace.itemPadding),
    this.margin,
    this.color = MiuiColors.surfaceContainer,
    this.radius = MiuiRadius.card,
    this.onTap,
    this.pressFeedback = true,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color color;
  final double radius;
  final VoidCallback? onTap;
  final bool pressFeedback;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: border,
      ),
      child: child,
    );

    if (onTap != null && pressFeedback) {
      card = MiuiPressFeedback(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: card,
      );
    } else if (onTap != null) {
      card = GestureDetector(onTap: onTap, child: card);
    }

    return card;
  }
}

/// 分组小标题：14sp Bold，onBackgroundVariant 色，内边距 (28, 8)。
class MiuiSmallTitle extends StatelessWidget {
  const MiuiSmallTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MiuiSpace.smallTitleH,
        MiuiSpace.smallTitleV,
        MiuiSpace.smallTitleH,
        MiuiSpace.smallTitleV,
      ),
      child: Row(
        children: [
          Expanded(child: Text(text, style: MiuiType.subtitle)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Miuix 列表行：最小高度 56dp，16dp 水平内边距，左/中/右三段布局。
///
/// 取自 BasicComponent（所有 Preference 的基类）。
class MiuiListItem extends StatelessWidget {
  const MiuiListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showDivider = true,
    this.titleStyle,
    this.dense = false,
    this.selected = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;
  final TextStyle? titleStyle;
  final bool dense;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: BoxConstraints(
        minHeight: dense ? 48 : MiuiSpace.itemMinHeight,
      ),
      padding: const EdgeInsets.symmetric(horizontal: MiuiSpace.itemPadding),
      child: Row(
        children: [
          if (leading != null) ...[
            IconTheme(
              data: IconThemeData(
                color: selected
                    ? MiuiColors.primaryVariant
                    : MiuiColors.onSurfaceSecondary,
                size: 24,
              ),
              child: leading!,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: titleStyle ??
                      MiuiType.headline1.copyWith(
                        color: selected
                            ? MiuiColors.primaryVariant
                            : MiuiColors.onSurface,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: MiuiType.body2,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            IconTheme(
              data: const IconThemeData(
                color: MiuiColors.onSurfaceVariantActions,
                size: 20,
              ),
              child: trailing!,
            ),
          ],
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onTap != null)
          MiuiPressFeedback(onTap: onTap, child: content)
        else
          content,
        if (showDivider)
          // Miuix 的分隔线左缩进到与标题对齐
          const Padding(
            padding: EdgeInsets.only(left: MiuiSpace.itemPadding),
            child: Divider(height: MiuiSpace.dividerThickness),
          ),
      ],
    );
  }
}

/// 卡片内的列表分组：一整块卡片，行与行之间用极细分隔线。
///
/// 这是 HyperOS 设置页最典型的结构。
class MiuiListSection extends StatelessWidget {
  const MiuiListSection({
    super.key,
    this.title,
    required this.children,
    this.margin = const EdgeInsets.symmetric(
      horizontal: MiuiSpace.page,
      vertical: MiuiSpace.cardGap,
    ),
  });

  final String? title;
  final List<Widget> children;

  /// 外边距。默认左右 16、上下 12。
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    // 最后一行不画分隔线
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
    }

    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(
                left: MiuiSpace.itemPadding - 12,
                bottom: MiuiSpace.itemGap,
              ),
              child: Text(title!, style: MiuiType.subtitle),
            ),
          Container(
            decoration: BoxDecoration(
              color: MiuiColors.surfaceContainer,
              borderRadius: MiuiRadius.cardRadius,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: rows,
            ),
          ),
        ],
      ),
    );
  }
}

/// Miuix 主按钮：16dp 圆角，58×40 最小尺寸。
class MiuiButton extends StatelessWidget {
  const MiuiButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = true,
    this.expand = false,
    this.icon,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// true = 主色填充；false = 中性填充（Miuix 的默认按钮其实是中性色）。
  final bool primary;

  /// 是否撑满宽度。
  final bool expand;

  final IconData? icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final bg = !enabled
        ? MiuiColors.disabledPrimaryButton
        : danger
            ? MiuiColors.error
            : primary
                ? MiuiColors.primary
                : MiuiColors.secondaryVariant;
    final fg = !enabled
        ? MiuiColors.disabledOnPrimaryButton
        : danger
            ? MiuiColors.onError
            : primary
                ? MiuiColors.onPrimary
                : MiuiColors.onSecondaryVariant;

    Widget button = Container(
      constraints: const BoxConstraints(
        minWidth: MiuiSpace.buttonMinWidth,
        minHeight: MiuiSpace.buttonMinHeight,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: MiuiRadius.buttonRadius,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 6),
          ],
          Text(label, style: MiuiType.button.copyWith(color: fg)),
        ],
      ),
    );

    if (expand) {
      button = SizedBox(width: double.infinity, child: button);
    }

    if (!enabled) return Opacity(opacity: 0.6, child: button);

    return MiuiPressFeedback(
      onTap: onPressed,
      borderRadius: MiuiRadius.buttonRadius,
      child: button,
    );
  }
}

/// Miuix 分段控件：12dp 圆角，指示器位移 200ms 线性。
class MiuiSegmented<T extends Object> extends StatelessWidget {
  const MiuiSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.height = 42,
    this.fixedWidth,
  });

  final Map<T, String> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  /// 胶囊总高度。剧情页顶部需要更矮的导航条时可传 34。
  final double height;

  /// 显式宽度：传入时胶囊不再拉通父级宽度（用于顶部居中导航等场景）。
  final double? fixedWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fixedWidth,
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: MiuiColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(MiuiRadius.tab),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = segments.length;
          final itemWidth = (constraints.maxWidth - 8) / count;
          final index = segments.keys.toList().indexOf(selected);

          return Stack(
            children: [
              // 指示器
              TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: index.toDouble(),
                  end: index.toDouble(),
                ),
                duration: MiuiMotion.tabDuration,
                curve: Curves.linear,
                builder: (context, value, _) {
                  return Positioned(
                    left: 4 + value * itemWidth,
                    top: 4,
                    width: itemWidth,
                    height: height - 8,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            MiuiColors.primaryVariant,
                            MiuiColors.primary,
                          ],
                        ),
                        borderRadius:
                            BorderRadius.circular(MiuiRadius.small),
                        boxShadow: [
                          BoxShadow(
                            color: MiuiColors.primary
                                .withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Row(
                children: segments.entries.map((e) {
                  final isSelected = e.key == selected;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (!isSelected) {
                          MiuiMotion.segmentTick();
                          onChanged(e.key);
                        }
                      },
                      child: Center(
                        child: Text(
                          e.value,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? MiuiColors.onPrimary
                                : MiuiColors.onSurfaceVariantSummary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 空状态占位。
class MiuiEmptyState extends StatelessWidget {
  const MiuiEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: MiuiColors.disabledOnSurface),
            const SizedBox(height: 16),
            Text(
              message,
              style: MiuiType.body1.copyWith(
                color: MiuiColors.onSurfaceVariantSummary,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
