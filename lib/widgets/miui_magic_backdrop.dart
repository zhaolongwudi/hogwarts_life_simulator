import 'package:flutter/material.dart';

/// 魔法辉光背景层。
///
/// 深空底色上浮着极淡的金色辉光斑与星尘。用途有二：
/// 1. 给整层 UI 提供一种「古老城堡深处的魔法空气」氛围，而非死黑；
/// 2. 为悬浮液态玻璃提供可折射/模糊的**内容**——纯色背景上玻璃效果几乎不可见，
///    有了光斑与星尘，折射与模糊立刻可感知。
///
/// 全部静态绘制（单次画完缓存），无逐帧动画，性能与纯色背景等价。
class MiuiMagicBackdrop extends StatelessWidget {
  const MiuiMagicBackdrop({super.key, this.density = 1.0});

  /// 光斑密度缩放。
  final double density;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _MagicPainter(density),
        size: Size.infinite,
      ),
    );
  }
}

class _MagicPainter extends CustomPainter {
  _MagicPainter(this.density);

  final double density;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    // ===== ① 大而淡的金色光斑 =====
    // 位置按屏幕比例固定，保证不同机型布局一致
    const spots = <(double, double, double)>[
      // (x比例, y比例, 相对半径)
      (0.08, 0.15, 0.22),
      (0.92, 0.28, 0.28),
      (0.18, 0.72, 0.26),
      (0.85, 0.85, 0.20),
      (0.55, 0.45, 0.16),
    ];

    for (final (xr, yr, rr) in spots) {
      final cx = w * xr;
      final cy = h * yr;
      final radius = w * rr * density;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFD3A625).withValues(alpha: 0.05),
            const Color(0xFFD3A625).withValues(alpha: 0.012),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }

    // ===== ② 底部金色辉光带（液态玻璃折射的主要取景） =====
    final bottomGlow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          const Color(0xFFD3A625).withValues(alpha: 0.028),
          const Color(0xFFB8860B).withValues(alpha: 0.05),
        ],
        stops: const [0.0, 0.72, 1.0],
      ).createShader(Rect.fromLTWH(0, h * 0.7, w, h * 0.3));
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.7, w, h * 0.3),
      bottomGlow,
    );

    // ===== ③ 星尘 =====
    // 用确定性伪随机（固定种子）避免逐帧重建
    final rng = _SeededRandom(0x9E3779B9);
    final count = (w * h / 42000 * density).round().clamp(18, 90);
    for (var i = 0; i < count; i++) {
      final x = rng.next() * w;
      final y = rng.next() * h;
      // 星尘不要盖住顶部状态栏区域与正文密集区底部，稍微偏向两侧
      final r = 0.4 + rng.next() * 0.9;
      final alpha = 0.10 + rng.next() * 0.22;
      final paint = Paint()
        ..color = const Color(0xFFF3DFA0).withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MagicPainter oldDelegate) =>
      oldDelegate.density != density;
}

/// 简单确定性随机：同一行代码每次构建都得到相同"星座"。
class _SeededRandom {
  _SeededRandom(this._seed);

  int _seed;

  double next() {
    // xorshift32
    var x = _seed;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    _seed = x;
    return (x & 0x7FFFFFFF) / 0x7FFFFFFF;
  }
}
