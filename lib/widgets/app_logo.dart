import 'dart:math' as math;
import 'package:flutter/material.dart';

/// OrganiSR Architectural Logo:
/// An isometric nested structure representing infinite hierarchy,
/// precision organization, and an offline sanctuary.
class OrganiSRLogoPainter extends CustomPainter {
  final double animationValue;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;

  OrganiSRLogoPainter({
    this.animationValue = 1.0,
    this.primaryColor = Colors.white,
    this.secondaryColor = const Color(0xFF6E6E6E),
    this.accentColor = const Color(0xFF333333),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = math.min(w, h) / 2;

    final progress = animationValue.clamp(0.0, 1.0);

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Subtle breathing/rotation during splash
    final rotation = (1.0 - progress) * (math.pi / 4);
    canvas.rotate(rotation);

    // Scale
    final scale = 0.85 + (0.15 * progress);
    canvas.scale(scale);

    // 1. Outer Hexagonal Shield / Portal Perimeter (Isometric Monogram)
    final hexRadius = radius * 0.92;
    final hexPath = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * math.pi / 3) - (math.pi / 2);
      final x = hexRadius * math.cos(angle);
      final y = hexRadius * math.sin(angle);
      if (i == 0) {
        hexPath.moveTo(x, y);
      } else {
        hexPath.lineTo(x, y);
      }
    }
    hexPath.close();

    final outerStrokePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.9 * progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(hexPath, outerStrokePaint);

    // 2. Three Isometric Internal Segments (Forming 3D Nested Blocks)
    // Connecting center to vertices 0 (top), 2 (bottom-right), 4 (bottom-left)
    final axisPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.85 * progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round;

    for (int vertexIndex in [0, 2, 4]) {
      final angle = (vertexIndex * math.pi / 3) - (math.pi / 2);
      final endX = hexRadius * 0.96 * math.cos(angle);
      final endY = hexRadius * 0.96 * math.sin(angle);
      canvas.drawLine(Offset.zero, Offset(endX, endY), axisPaint);
    }

    // 3. Inner Concentric Stepped Rhombus (The Nested Depth Portal)
    // Rhombus in top facet
    _drawSteppedFacet(
      canvas,
      w,
      center: Offset(0, -hexRadius * 0.38),
      size: hexRadius * 0.42 * progress,
      color: primaryColor,
      opacity: 0.95,
      isFilled: false,
    );

    // Rhombus in bottom-right facet
    _drawSteppedFacet(
      canvas,
      w,
      center: Offset(hexRadius * 0.34, hexRadius * 0.20),
      size: hexRadius * 0.42 * progress,
      color: secondaryColor,
      opacity: 0.7,
      isFilled: false,
    );

    // Rhombus in bottom-left facet
    _drawSteppedFacet(
      canvas,
      w,
      center: Offset(-hexRadius * 0.34, hexRadius * 0.20),
      size: hexRadius * 0.42 * progress,
      color: secondaryColor,
      opacity: 0.7,
      isFilled: false,
    );

    // 4. Center Core Focus Gem (The Atom of Knowledge)
    final gemSize = hexRadius * 0.18 * progress;
    final gemPath = Path()
      ..moveTo(0, -gemSize)
      ..lineTo(gemSize * 0.9, 0)
      ..lineTo(0, gemSize)
      ..lineTo(-gemSize * 0.9, 0)
      ..close();

    final gemPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(gemPath, gemPaint);

    canvas.restore();
  }

  void _drawSteppedFacet(
    Canvas canvas,
    double w, {
    required Offset center,
    required double size,
    required Color color,
    required double opacity,
    bool isFilled = false,
  }) {
    if (size <= 0) return;
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx + (size * 0.86), center.dy)
      ..lineTo(center.dx, center.dy + size)
      ..lineTo(center.dx - (size * 0.86), center.dy)
      ..close();

    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = isFilled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant OrganiSRLogoPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.primaryColor != primaryColor;
  }
}

class OrganiSRLogo extends StatelessWidget {
  final double size;
  final double animationValue;

  const OrganiSRLogo({
    super.key,
    this.size = 32,
    this.animationValue = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: OrganiSRLogoPainter(animationValue: animationValue),
      ),
    );
  }
}
