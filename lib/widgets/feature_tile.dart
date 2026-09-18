import 'package:flutter/material.dart';
import '../theme/miuix_tokens.dart';
import 'miuix_components.dart';

/// 统一「功能入口 tile」—— 用于把游戏内各项系统/功能归纳成清晰、可发现的入口。
///
/// 设计目标：
///  · 一个功能 = 一个 tile（图标 + 名称 + 一句话说明 + 可选徽标），信息一眼可见；
///  · 分成「列表式」与「宫格式」两种形态：`compact: true` 时只显示图标 + 名，
///    适合放在紧凑宫格/快捷区；默认横条形态带说明，适合放在系统分组下。
///
/// 所有入口统一走本组件，避免各页自写一套图标块（消除视觉漂移）。
class FeatureTile extends StatelessWidget {
  const FeatureTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.color = MiuiColors.primary,
    this.coloredBlock = true,
    this.compact = false,
    this.onInfo,
  });

  /// 入口图标
  final IconData icon;
  /// 入口名称
  final String title;
  /// 一句话说明（列表式必填，宫格式可省略）
  final String? subtitle;
  /// 可选徽标文案（如「新」「3」）
  final String? badge;
  /// 强调色（图标块 / 图标着色）
  final Color color;
  /// 是否给图标一个色块底
  final bool coloredBlock;
  /// 点击回调
  final VoidCallback? onTap;
  /// 宫格式（紧凑）：仅图标 + 名，去掉说明与箭头
  final bool compact;

  /// 可选的「这是什么 / 怎么玩」说明回调：非空时在箭头前渲染一个小问号按钮，
  /// 点击（不触发主 onTap）由宿主弹出系统引导。用于新玩家识别玩法系统。
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact(context);
    return _buildRow(context);
  }

  /// 列表式：图标块 + 名称/说明 + 徽标 + 箭头
  Widget _buildRow(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: MiuiSpace.itemPadding, vertical: 10),
      child: Row(
        children: [
          _iconBlock(36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: MiuiColors.onSurface,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.3,
                      color: MiuiColors.onSurfaceVariantSummary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (onInfo != null)
            Semantics(
              button: true,
              label: '查看说明',
              child: InkWell(
                onTap: onInfo,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.help_outline,
                    size: 18,
                    color: MiuiColors.onSurfaceVariantActions,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 2),
          const Icon(
            Icons.chevron_right,
            size: 20,
            color: MiuiColors.onSurfaceVariantActions,
          ),
        ],
      ),
    );

    return MiuiCard(
      margin: const EdgeInsets.symmetric(horizontal: MiuiSpace.page, vertical: 4),
      color: MiuiColors.surfaceContainer,
      onTap: onTap,
      child: content,
    );
  }

  /// 宫格式：图标 + 名（可配合 Wrap/GridView 复用）
  Widget _buildCompact(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(MiuiRadius.small),
        onTap: onTap,
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _iconBlock(56, blockRadius: 16),
                  if (badge != null)
                    Positioned(
                      top: 0,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: MiuiColors.error,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: MiuiColors.onError,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  color: MiuiColors.onSurfaceVariantSummary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBlock(double size, {double blockRadius = MiuiRadius.small}) {
    final Widget iconView = Icon(icon, color: color, size: size * 0.46);
    if (!coloredBlock) return iconView;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(blockRadius),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Center(child: iconView),
    );
  }
}

/// SectionHeader：统一的「分区标题」，供各页面按一致层级组织信息。
///
/// 视觉对齐 Miuix 小标题风格（金色左侧强调条 + 主标题 + 可选副标题/右操作）。
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.trailing,
    this.accent = true,
    this.padding = const EdgeInsets.only(top: 18, bottom: 8),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool accent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (accent)
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: MiuiColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          if (accent) const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: MiuiColors.onSurfaceVariantSummary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: MiuiColors.onSurfaceVariantActions,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}