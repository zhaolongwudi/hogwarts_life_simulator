import 'package:flutter/material.dart';
import '../theme/miuix_tokens.dart';

/// 统一「页面/区块加载态」。
///
/// 各页不要再各自写 `Center(CircularProgressIndicator())` + 自定文案，
/// 一律用本组件收口加载中的视觉与文案层级（图标/转圈 / 主文案 / 可选副文案）。
class PageLoading extends StatelessWidget {
  const PageLoading({
    super.key,
    this.title = '加载中…',
    this.subtitle,
    this.icon,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Widget spinner = SizedBox(
      width: compact ? 22 : MiuiSpace.circularProgressSize,
      height: compact ? 22 : MiuiSpace.circularProgressSize,
      child: const CircularProgressIndicator(
        strokeWidth: 2.5,
        color: MiuiColors.primaryVariant,
      ),
    );

    if (compact) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Center(child: spinner),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 40, color: MiuiColors.onSurfaceVariantActions),
              const SizedBox(height: 12),
              spinner,
            ] else
              spinner,
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: MiuiColors.onSurfaceVariantSummary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: MiuiColors.onSurfaceVariantActions,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 统一「空态」。优先复用，避免各页自写空态图标 + 文案组合漂移。
///
/// 已有 `MiuiEmptyState`，本组件是带推荐动作按钮 & 副文案的便捷封装；
/// 若项目其它处已稳定引用 `MiuiEmptyState`，可在此转发合并，保持单一入口。
class EmptyPlaceholder extends StatelessWidget {
  const EmptyPlaceholder({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = MiuiColors.onSurfaceVariantSummary;
    if (compact) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 13, color: color)),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: MiuiColors.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: MiuiColors.onSurfaceVariantActions),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: MiuiColors.onSurface,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: MiuiColors.onSurfaceVariantSummary),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}