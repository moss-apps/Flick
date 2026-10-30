import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flick/features/recap/widgets/replay_style.dart';

/// Authored vector artwork, not pretend library data or player controls.
class OnboardingGraphic extends StatefulWidget {
  const OnboardingGraphic({
    super.key,
    required this.index,
    required this.active,
    required this.foreground,
    required this.accent,
    required this.background,
  });

  final int index;
  final bool active;
  final Color foreground;
  final Color accent;
  final Color background;

  @override
  State<OnboardingGraphic> createState() => _OnboardingGraphicState();
}

class _OnboardingGraphicState extends State<OnboardingGraphic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  bool _played = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateMotion();
  }

  @override
  void didUpdateWidget(OnboardingGraphic oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateMotion();
  }

  void _updateMotion() {
    if (!widget.active || ReplayStyle.duration(context) == Duration.zero) {
      _entrance.value = 1;
      if (widget.active) _played = true;
    } else if (!_played) {
      _played = true;
      _entrance.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _PosterPainter(
          index: widget.index,
          foreground: widget.foreground,
          accent: widget.accent,
          background: widget.background,
          entrance: _entrance,
        ),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _PosterPainter extends CustomPainter {
  _PosterPainter({
    required this.index,
    required this.foreground,
    required this.accent,
    required this.background,
    required this.entrance,
  }) : super(repaint: entrance);

  final int index;
  final Color foreground;
  final Color accent;
  final Color background;
  final Animation<double> entrance;

  double get _t => Curves.easeOutQuart.transform(entrance.value);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 360, size.height / 244);
    canvas.save();
    canvas.translate(
      (size.width - 360 * scale) / 2,
      (size.height - 244 * scale) / 2,
    );
    canvas.scale(scale);
    canvas.clipRect(const Rect.fromLTWH(0, 0, 360, 244));
    switch (index) {
      case 0:
        _welcome(canvas);
      case 1:
        _library(canvas);
      case 2:
        _browse(canvas);
      case 3:
        _playback(canvas);
      case 4:
        _ready(canvas);
    }
    _registration(canvas, const Offset(8, 8));
    _registration(canvas, const Offset(352, 236));
    canvas.restore();
  }

  void _welcome(Canvas canvas) {
    _dots(canvas, const Offset(16, 38), foreground, columns: 5, rows: 4);
    _stripes(canvas, const Rect.fromLTWH(-16, 174, 174, 62), foreground);
    canvas.drawLine(
      const Offset(0, 148),
      Offset(112 * _t, 148),
      Paint()..color = foreground,
    );
    canvas.drawCircle(const Offset(112, 148), 5, Paint()..color = accent);
    _mark(canvas, const Rect.fromLTWH(166, 0, 194, 235), foreground);
  }

  void _library(Canvas canvas) {
    canvas.save();
    canvas.translate(0, (1 - _t) * 24);
    final outline = Paint()
      ..color = foreground.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(const Rect.fromLTWH(96, 16, 202, 188), outline);
    canvas.drawRect(const Rect.fromLTWH(67, 33, 202, 188), outline);
    canvas.drawRect(
      const Rect.fromLTWH(38, 50, 202, 188),
      Paint()..color = accent,
    );
    _record(canvas, const Offset(139, 144), 73, background, accent);
    _dots(canvas, const Offset(49, 61), background, columns: 3, rows: 2);
    canvas.restore();
    _stripes(canvas, const Rect.fromLTWH(270, 128, 100, 56), accent);
    canvas.drawLine(
      const Offset(278, 204),
      const Offset(346, 204),
      Paint()..color = foreground,
    );
  }

  void _browse(Canvas canvas) {
    const left = 8.0;
    const top = 20.0;
    const cell = 114.0;
    final ink = Paint()..color = foreground;
    canvas.drawRect(const Rect.fromLTWH(left, top, cell, 204), ink);
    _record(canvas, const Offset(65, 76), 43, background, foreground);
    _dots(canvas, const Offset(30, 154), background, columns: 5, rows: 4);

    canvas.drawRect(
      const Rect.fromLTWH(122, top, cell, 204),
      Paint()..color = ReplayStyle.acid,
    );
    _stripes(canvas, const Rect.fromLTWH(122, 20, 114, 92), foreground);
    final arrow = Path()
      ..moveTo(142, 191)
      ..lineTo(198, 135)
      ..lineTo(167, 135)
      ..lineTo(167, 119)
      ..lineTo(224, 119)
      ..lineTo(224, 176)
      ..lineTo(208, 176)
      ..lineTo(208, 146)
      ..lineTo(153, 202)
      ..close();
    canvas.drawPath(arrow, ink);

    final rule = Paint()
      ..color = foreground.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke;
    canvas.drawRect(const Rect.fromLTWH(236, top, cell, 204), rule);
    _record(canvas, const Offset(293, 76), 43, foreground, background);
    canvas.drawRect(
      const Rect.fromLTWH(236, 122, cell, 102),
      Paint()..color = accent,
    );
    canvas.drawArc(
      const Rect.fromLTWH(255, 140, 76, 76),
      -math.pi / 2,
      math.pi * (0.65 + 0.85 * _t),
      true,
      ink,
    );
    canvas.drawCircle(const Offset(293, 178), 9, Paint()..color = accent);
  }

  void _playback(Canvas canvas) {
    _stripes(canvas, const Rect.fromLTWH(-22, 28, 158, 78), foreground);
    const center = Offset(234, 122);
    canvas.save();
    // Keep the entire record inside the artboard, including its entrance travel.
    canvas.translate((1 - _t) * 10, 0);
    _record(canvas, center, 112, foreground, background);
    canvas.drawCircle(center, 31, Paint()..color = accent);
    canvas.drawCircle(center, 6, Paint()..color = foreground);
    canvas.restore();
    canvas.drawLine(
      const Offset(0, 186),
      const Offset(110, 186),
      Paint()
        ..color = foreground
        ..strokeWidth = 2,
    );
    _dots(canvas, const Offset(8, 211), foreground, columns: 6, rows: 2);
  }

  void _ready(Canvas canvas) {
    canvas.drawCircle(const Offset(231, 120), 112, Paint()..color = accent);
    _mark(canvas, const Rect.fromLTWH(168, 38, 132, 160), background);
    _stripes(canvas, const Rect.fromLTWH(-24, 166, 130, 62), foreground);
    _dots(canvas, const Offset(16, 46), accent, columns: 4, rows: 3);
  }

  void _record(
    Canvas canvas,
    Offset center,
    double radius,
    Color ink,
    Color label,
  ) {
    canvas.drawCircle(center, radius, Paint()..color = ink);
    final groove = Paint()
      ..color = label.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (final fraction in [0.62, 0.76, 0.9]) {
      canvas.drawCircle(center, radius * fraction, groove);
    }
    canvas.drawCircle(center, radius * 0.25, Paint()..color = label);
    canvas.drawCircle(center, radius * 0.055, Paint()..color = ink);
  }

  void _stripes(Canvas canvas, Rect bounds, Color color) {
    canvas.save();
    canvas.clipRect(bounds);
    canvas.translate((1 - _t) * -28, 0);
    final paint = Paint()..color = color;
    for (
      double x = bounds.left - bounds.height;
      x < bounds.right + 64;
      x += 32
    ) {
      canvas.drawPath(
        Path()
          ..moveTo(x, bounds.bottom)
          ..lineTo(x + 15, bounds.bottom)
          ..lineTo(x + bounds.height + 15, bounds.top)
          ..lineTo(x + bounds.height, bounds.top)
          ..close(),
        paint,
      );
    }
    canvas.restore();
  }

  void _dots(
    Canvas canvas,
    Offset origin,
    Color color, {
    required int columns,
    required int rows,
  }) {
    final paint = Paint()..color = color;
    for (var x = 0; x < columns; x++) {
      for (var y = 0; y < rows; y++) {
        canvas.drawCircle(origin + Offset(x * 12, y * 12), 2.2, paint);
      }
    }
  }

  void _registration(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = foreground.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    canvas.drawLine(
      center - const Offset(4, 0),
      center + const Offset(4, 0),
      paint,
    );
    canvas.drawLine(
      center - const Offset(0, 4),
      center + const Offset(0, 4),
      paint,
    );
  }

  void _mark(Canvas canvas, Rect bounds, Color color) {
    final paint = Paint()..color = color;
    for (var i = 0; i < _logoDots.length; i++) {
      final t = Interval(
        i * 0.012,
        0.72 + i * 0.012,
        curve: Curves.easeOutQuart,
      ).transform(entrance.value);
      final dot = _logoDots[i];
      final center = Offset(
        bounds.left + dot.dx * bounds.width,
        bounds.top + dot.dy * bounds.height,
      );
      canvas.drawCircle(
        center +
            Offset(
              (1 - t) * (-70 - i % 3 * 14),
              (1 - t) * (i.isEven ? 18 : -18),
            ),
        bounds.width * (29.4994 / 606) * (0.8 + 0.2 * t),
        paint,
      );
    }
  }

  // Circle centers transformed directly from assets/icons/flicklogo_svg.svg.
  // Keep its 606:734 proportions and all 18 dots; this is the official mark.
  static const _logoDots = [
    Offset(0.938466, 0.822157),
    Offset(0.784463, 0.779958),
    Offset(0.630459, 0.737761),
    Offset(0.631196, 0.345784),
    Offset(0.631196, 0.479750),
    Offset(0.631196, 0.613716),
    Offset(0.328776, 0.122214),
    Offset(0.479865, 0.171068),
    Offset(0.630954, 0.219922),
    Offset(0.177080, 0.197360),
    Offset(0.328169, 0.246215),
    Offset(0.479256, 0.295068),
    Offset(0.479499, 0.429279),
    Offset(0.187999, 0.079650),
    Offset(0.048679, 0.040190),
    Offset(0.937916, 0.948444),
    Offset(0.783913, 0.906247),
    Offset(0.629910, 0.864048),
  ];

  @override
  bool shouldRepaint(_PosterPainter oldDelegate) =>
      index != oldDelegate.index ||
      foreground != oldDelegate.foreground ||
      accent != oldDelegate.accent ||
      background != oldDelegate.background ||
      entrance != oldDelegate.entrance;
}
