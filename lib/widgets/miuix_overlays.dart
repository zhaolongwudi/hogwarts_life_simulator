import 'package:flutter/material.dart';

import '../theme/miuix_motion.dart';
import '../theme/miuix_tokens.dart';

/// HyperOS 风格弹窗 / 轻提示（Miuix overlays 落地）。
///
/// [showMiuixDialog] 用 Folme 弹簧（阻尼比 0.9、刚度 ~438.6，与 Miuix
/// 源码 `spring(dampingRatio = 0.9f, stiffness = 438.6f)` 的 dialogIn 一致）
/// 驱动「缩放 0.92 → 1 + 淡入」，替换 Material 对话框默认的线性淡入，
/// 弹层带 HyperOS 的"蹦出后微回弹"手感。

/// 弹簧驱动对话框。签名与 [showDialog] 对齐（去掉不常用的高级参数），
/// 存量调用可直接把 `showDialog(` 换成 `showMiuixDialog(`。
Future<T?> showMiuixDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (dialogContext, _, __) => builder(dialogContext),
    transitionBuilder: (_, animation, __, child) {
      final spring = CurvedAnimation(
        parent: animation,
        curve: SpringCurve.folme(damping: 0.9, response: 0.3),
      );
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(spring),
          child: child,
        ),
      );
    },
  );
}

/// 游戏内轻提示：Miuix 浮动吐司（玻璃圆角卡 + 图标 + 主按钮同高）。
///
/// 相比裸 [SnackBar]，自带主色小图标与更克制的展示时长。
void miuixSnack(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle,
  Color color = MiuiColors.primary,
  Duration duration = const Duration(milliseconds: 1800),
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: duration,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MiuiRadius.card),
        ),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
}

/// 便捷确认弹窗：标题 + 说明 + 「取消 / 确认」。
Future<bool> miuixConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = '确认',
  String cancelText = '取消',
  bool danger = false,
}) async {
  final ok = await showMiuixDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelText),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            confirmText,
            style: TextStyle(
              color: danger ? MiuiColors.error : MiuiColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  return ok ?? false;
}
