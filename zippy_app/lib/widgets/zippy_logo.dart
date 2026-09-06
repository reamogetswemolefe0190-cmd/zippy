import 'package:flutter/material.dart';
import 'package:zippy_app/core/zippy_theme.dart';

/// Official vector brand logo for Zippy.
///
/// Implements "The Bilateral Split" (Variant 02): two interlocking rounded
/// ribbon arcs forming an energetic 'Z' monogram, symbolizing mutual exchange,
/// merchant till payments, and social bill-splitting balance.
class ZippyLogo extends StatelessWidget {
  /// The width and height of the logo widget.
  final double size;

  /// The primary color of the top ribbon (defaults to white).
  final Color primaryColor;

  /// The accent color of the bottom ribbon (defaults to [ZippyTheme.primaryGreen]).
  final Color accentColor;

  /// Creates a [ZippyLogo] instance.
  const ZippyLogo({
    super.key,
    this.size = 32.0,
    this.primaryColor = Colors.white,
    this.accentColor = ZippyTheme.primaryGreen,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ZippyLogoPainter(
          primaryColor: primaryColor,
          accentColor: accentColor,
        ),
      ),
    );
  }
}

class _ZippyLogoPainter extends CustomPainter {
  final Color primaryColor;
  final Color accentColor;

  _ZippyLogoPainter({
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 100.0;
    canvas.save();
    canvas.scale(scale, scale);

    // 1. Top Sender Ribbon
    final topPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final topPath = Path()
      ..moveTo(26, 28)
      ..lineTo(66, 28)
      ..cubicTo(72.6, 28, 78, 33.4, 78, 40)
      ..lineTo(78, 42)
      ..cubicTo(78, 48.6, 72.6, 54, 66, 54)
      ..lineTo(50, 54);

    canvas.drawPath(topPath, topPaint);

    // 2. Bottom Receiver Ribbon
    final bottomPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final bottomPath = Path()
      ..moveTo(74, 72)
      ..lineTo(34, 72)
      ..cubicTo(27.4, 72, 22, 66.6, 22, 60)
      ..lineTo(22, 58)
      ..cubicTo(22, 51.4, 27.4, 46, 34, 46)
      ..lineTo(50, 46);

    canvas.drawPath(bottomPath, bottomPaint);

    // 3. Convergence Node Dots
    final topDotPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(50, 54), 3.5, topDotPaint);

    final bottomDotPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(50, 46), 3.5, bottomDotPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ZippyLogoPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor || oldDelegate.accentColor != accentColor;
  }
}
