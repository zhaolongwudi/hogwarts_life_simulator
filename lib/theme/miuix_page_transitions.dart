import 'package:flutter/material.dart';

import 'miuix_motion.dart';

/// HyperOS / Miuix 风格页面转场。
///
/// 前进：新页从右侧轻滑入场 + 淡入 + 0.985→1 微缩放（Folme 弹簧驱动，
/// 临界阻尼无过冲，收敛干脆）；返回：镜像曲线回弹。相比 Material 3 的
/// fadeUpwards 与 iOS 的整页平移，这套更接近 HyperOS 设置页的
/// "轻推 + 柔和聚焦" 手感。
///
/// 曲线使用 [SpringCurve.folme(damping: 1.0, response: 0.35)]（与 Miuix
/// 页面转场默认参数一致）—— 弹簧的解析阶跃响应作为 Curve，零误差零状态，
/// 不会引入未收敛的物理模拟。
class MiuixPageTransitionsBuilder extends PageTransitionsBuilder {
  const MiuixPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 根路由（首页）无需进场动画，避免冷启动时出现多余位移。
    if (route.isFirst) return child;

    final springCurve = SpringCurve.folme(damping: 1.0, response: 0.35);
    final enter = CurvedAnimation(parent: animation, curve: springCurve);
    final slide = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(enter);
    final scale = Tween<double>(begin: 0.985, end: 1.0).animate(enter);
    final fade = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: ScaleTransition(scale: scale, child: child),
      ),
    );
  }
}

/// 全局 [PageTransitionsTheme]：所有平台统一使用 Miuix 转场。
const miuixPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: MiuixPageTransitionsBuilder(),
    TargetPlatform.iOS: MiuixPageTransitionsBuilder(),
    TargetPlatform.macOS: MiuixPageTransitionsBuilder(),
    TargetPlatform.windows: MiuixPageTransitionsBuilder(),
    TargetPlatform.linux: MiuixPageTransitionsBuilder(),
    TargetPlatform.fuchsia: MiuixPageTransitionsBuilder(),
  },
);
