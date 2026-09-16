import 'package:flutter/material.dart';

/// 区域地形绘制：按 area/subArea 分发到专属画法。
/// 从 world_map_screen.dart 抽出，保持地图页可读性。
class MapAreaPainter extends CustomPainter {
  final String area;
  final String? subArea;
  MapAreaPainter(this.area, this.subArea);

  @override
  void paint(Canvas canvas, Size size) {
    switch (subArea ?? area) {
      case '对角巷':
        _paintDiagonAlley(canvas, size);
        break;
      case '翻倒巷':
        _paintKnockturnAlley(canvas, size);
        break;
      default:
        _paintArea(canvas, size);
    }
  }

  void _paintArea(Canvas canvas, Size size) {
    final groundColor = area == '伦敦'
        ? const Color(0xFFA0825A).withValues(alpha: 0.25)
        : area == '住宅区'
            ? const Color(0xFFB8A88A).withValues(alpha: 0.3)
            : area == '霍格莫德村'
                ? const Color(0xFF8FA07A).withValues(alpha: 0.3)
                : const Color(0xFF5A6B4A).withValues(alpha: 0.3);

    final groundPaint = Paint()..color = groundColor..style = PaintingStyle.fill;
    final path1 = Path()
      ..moveTo(size.width * 0.15, size.height * 0.25)
      ..quadraticBezierTo(size.width * 0.35, size.height * 0.15, size.width * 0.55, size.height * 0.20)
      ..lineTo(size.width * 0.85, size.height * 0.22)
      ..quadraticBezierTo(size.width * 0.90, size.height * 0.40, size.width * 0.80, size.height * 0.45)
      ..lineTo(size.width * 0.50, size.height * 0.42)
      ..quadraticBezierTo(size.width * 0.30, size.height * 0.38, size.width * 0.15, size.height * 0.35)
      ..close();
    canvas.drawPath(path1, groundPaint);

    final hillColor = area == '霍格莫德村'
        ? const Color(0xFF5A6B50).withValues(alpha: 0.25)
        : area == '住宅区'
            ? const Color(0xFF8A9A7B).withValues(alpha: 0.2)
            : const Color(0xFF3E5B4A).withValues(alpha: 0.25);
    final hillPaint = Paint()..color = hillColor..style = PaintingStyle.fill;
    final hillPath = Path()
      ..moveTo(size.width * 0.05, size.height * 0.55)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.48, size.width * 0.45, size.height * 0.55)
      ..quadraticBezierTo(size.width * 0.65, size.height * 0.60, size.width * 0.85, size.height * 0.52)
      ..lineTo(size.width * 0.95, size.height * 0.65)
      ..lineTo(size.width * 0.95, size.height * 0.85)
      ..lineTo(size.width * 0.05, size.height * 0.85)
      ..close();
    canvas.drawPath(hillPath, hillPaint);

    if (area != '伦敦') {
      final waterPaint = Paint()..color = const Color(0xFF4A6B8A).withValues(alpha: 0.35)..style = PaintingStyle.fill;
      final waterPath = Path()
        ..moveTo(size.width * 0.50, size.height * 0.62)
        ..quadraticBezierTo(size.width * 0.65, size.height * 0.60, size.width * 0.75, size.height * 0.68)
        ..lineTo(size.width * 0.70, size.height * 0.78)
        ..quadraticBezierTo(size.width * 0.55, size.height * 0.82, size.width * 0.45, size.height * 0.75)
        ..close();
      canvas.drawPath(waterPath, waterPaint);
    }

    final pathPaint = Paint()
      ..color = area == '伦敦' ? const Color(0xFF8A7B5A).withValues(alpha: 0.5) : const Color(0xFFC4A574).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.20, size.height * 0.30)
        ..quadraticBezierTo(size.width * 0.40, size.height * 0.50, size.width * 0.55, size.height * 0.55)
        ..quadraticBezierTo(size.width * 0.70, size.height * 0.58, size.width * 0.82, size.height * 0.40),
      pathPaint,
    );

    if (area != '伦敦') {
      final treePaint = Paint()..color = const Color(0xFF2D3E2A).withValues(alpha: 0.4)..style = PaintingStyle.fill;
      for (int i = 0; i < 12; i++) {
        final tx = (i * 0.083 + 0.05) * size.width;
        final ty = (0.75 + (i % 3) * 0.04) * size.height;
        canvas.drawCircle(Offset(tx, ty), 8 + (i % 3).toDouble() * 3, treePaint);
      }
    } else {
      final buildingPaint = Paint()..color = const Color(0xFF8A7B5A).withValues(alpha: 0.35)..style = PaintingStyle.fill;
      for (int i = 0; i < 8; i++) {
        final bx = (i * 0.12 + 0.08) * size.width;
        final bw = size.width * 0.06;
        final bh = size.height * (0.15 + (i % 3) * 0.08);
        canvas.drawRect(Rect.fromLTWH(bx, size.height * 0.55 - bh, bw, bh), buildingPaint);
      }
    }

    if (area == '住宅区') {
      final housePaint = Paint()..color = const Color(0xFFB88A6A).withValues(alpha: 0.3)..style = PaintingStyle.fill;
      for (int i = 0; i < 6; i++) {
        final hx = (i * 0.16 + 0.1) * size.width;
        final hy = size.height * (0.78 + (i % 2) * 0.05);
        canvas.drawRect(Rect.fromLTWH(hx, hy, size.width * 0.08, size.height * 0.06), housePaint);
        final roofPaint = Paint()..color = const Color(0xFF8A5A3A).withValues(alpha: 0.3)..style = PaintingStyle.fill;
        canvas.drawPath(
          Path()
            ..moveTo(hx - size.width * 0.01, hy)
            ..lineTo(hx + size.width * 0.04, hy - size.height * 0.03)
            ..lineTo(hx + size.width * 0.09, hy)
            ..close(),
          roofPaint,
        );
      }
    }

    if (area == '霍格莫德村') {
      final snowPaint = Paint()..color = const Color(0xFFFFFF).withValues(alpha: 0.2)..style = PaintingStyle.fill;
      for (int i = 0; i < 20; i++) {
        final sx = (i * 0.05 + 0.02) * size.width;
        final sy = (i * 0.047 + 0.03) * size.height;
        canvas.drawCircle(Offset(sx, sy), 2 + (i % 3).toDouble(), snowPaint);
      }
    }
  }

  void _paintDiagonAlley(Canvas canvas, Size size) {
    final groundPaint = Paint()..color = const Color(0xFF8A7B5A).withValues(alpha: 0.4)..style = PaintingStyle.fill;
    final groundPath = Path()
      ..moveTo(size.width * 0.05, size.height * 0.3)
      ..lineTo(size.width * 0.95, size.height * 0.3)
      ..lineTo(size.width * 0.95, size.height * 0.85)
      ..lineTo(size.width * 0.05, size.height * 0.85)
      ..close();
    canvas.drawPath(groundPath, groundPaint);

    final roadPaint = Paint()..color = const Color(0xFF6B5B3A).withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 8;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.05, size.height * 0.55)
        ..lineTo(size.width * 0.95, size.height * 0.55),
      roadPaint,
    );

    final shopPaint = Paint()..color = const Color(0xFFC4A574).withValues(alpha: 0.35)..style = PaintingStyle.fill;
    for (int i = 0; i < 8; i++) {
      final sx = (i * 0.12 + 0.06) * size.width;
      final sy = size.height * 0.35;
      final sw = size.width * 0.08;
      final sh = size.height * 0.18;
      canvas.drawRect(Rect.fromLTWH(sx, sy, sw, sh), shopPaint);
    }
  }

  void _paintKnockturnAlley(Canvas canvas, Size size) {
    final groundPaint = Paint()..color = const Color(0xFF2A2530).withValues(alpha: 0.5)..style = PaintingStyle.fill;
    final groundPath = Path()
      ..moveTo(size.width * 0.1, size.height * 0.35)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.30, size.width * 0.5, size.height * 0.40)
      ..lineTo(size.width * 0.70, size.height * 0.70)
      ..quadraticBezierTo(size.width * 0.50, size.height * 0.80, size.width * 0.30, size.height * 0.75)
      ..close();
    canvas.drawPath(groundPath, groundPaint);

    final wallPaint = Paint()..color = const Color(0xFF1A1520).withValues(alpha: 0.6)..style = PaintingStyle.fill;
    final wallPath = Path()
      ..moveTo(size.width * 0.05, size.height * 0.85)
      ..lineTo(size.width * 0.05, size.height * 0.25)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.20, size.width * 0.45, size.height * 0.30)
      ..lineTo(size.width * 0.50, size.height * 0.85)
      ..close();
    canvas.drawPath(wallPath, wallPaint);

    final wallPath2 = Path()
      ..moveTo(size.width * 0.95, size.height * 0.85)
      ..lineTo(size.width * 0.95, size.height * 0.35)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.30, size.width * 0.55, size.height * 0.45)
      ..lineTo(size.width * 0.50, size.height * 0.85)
      ..close();
    canvas.drawPath(wallPath2, wallPaint);

    final glowPaint = Paint()..color = const Color(0xFF8B4A2A).withValues(alpha: 0.2)..style = PaintingStyle.fill;
    for (int i = 0; i < 5; i++) {
      final gx = (i * 0.2 + 0.15) * size.width;
      final gy = (0.55 + (i % 2) * 0.15) * size.height;
      canvas.drawCircle(Offset(gx, gy), 15 + (i % 3).toDouble() * 5, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant MapAreaPainter oldDelegate) {
    return oldDelegate.area != area || oldDelegate.subArea != subArea;
  }
}