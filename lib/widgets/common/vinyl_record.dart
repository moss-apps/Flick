import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A hand-painted vinyl record — concentric grooves, a tinted center label
/// with the Flick logo, and a center hole. Sized at 104×104 by default.
class VinylRecord extends StatelessWidget {
  const VinylRecord({
    super.key,
    this.size = 104,
    this.labelColor,
  });

  final double size;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final color = labelColor ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _VinylPainter(
          labelColor: color,
          grooveColor: color.withValues(alpha: 0.18),
        ),
        child: Center(
          child: SvgPicture.asset(
            'assets/icons/flicklogo_svg.svg',
            width: size * 0.19,
            height: size * 0.23,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}

class _VinylPainter extends CustomPainter {
  _VinylPainter({required this.labelColor, required this.grooveColor});

  final Color labelColor;
  final Color grooveColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.shortestSide / 2;

    // Outer disc body — dark gradient to suggest a glossy record.
    final discPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 0.95,
        colors: [const Color(0xFF2A2A2A), const Color(0xFF0A0A0A)],
      ).createShader(Rect.fromCircle(center: center, radius: outerRadius));
    canvas.drawCircle(center, outerRadius, discPaint);

    // Concentric grooves — thin tinted rings, skipping the label area.
    final groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = grooveColor;
    const labelRatio = 0.44;
    final labelRadius = outerRadius * labelRatio;
    const grooves = 9;
    for (var i = 0; i < grooves; i++) {
      final t = (i + 1) / (grooves + 1);
      final r = labelRadius + (outerRadius - labelRadius) * t;
      canvas.drawCircle(center, r, groovePaint);
    }

    // Subtle highlight on top-left to suggest light catching the disc.
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.45, -0.45),
        radius: 0.55,
        colors: [
          Colors.white.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: outerRadius));
    canvas.drawCircle(center, outerRadius, highlightPaint);

    // Center label — the tier/accent color.
    final labelPaint = Paint()..color = labelColor;
    canvas.drawCircle(center, labelRadius, labelPaint);

    // Subtle inner shadow on the label edge for depth.
    final labelEdgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.black.withValues(alpha: 0.25);
    canvas.drawCircle(center, labelRadius, labelEdgePaint);

    // Center spindle hole.
    final holePaint = Paint()..color = const Color(0xFF0A0A0A);
    canvas.drawCircle(center, outerRadius * 0.05, holePaint);
  }

  @override
  bool shouldRepaint(covariant _VinylPainter oldDelegate) {
    return oldDelegate.labelColor != labelColor ||
        oldDelegate.grooveColor != grooveColor;
  }
}
