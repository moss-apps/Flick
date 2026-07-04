import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/utils/app_haptics.dart';

/// A circular rotary knob for parameter control.
///
/// Uses a custom gesture recognizer that eagerly accepts drag events,
/// preventing parent scrollables (e.g. PageView, ListView) from
/// intercepting horizontal/vertical swipes while the user is turning
/// the knob.
class RotaryKnob extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final double size;
  final ValueChanged<double>? onChanged;
  final String label;
  final Color? accentColor;
  final bool showLabel;

  const RotaryKnob({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.size = 110,
    required this.onChanged,
    required this.label,
    this.accentColor,
    this.showLabel = false,
  });

  @override
  State<RotaryKnob> createState() => _RotaryKnobState();
}

class _RotaryKnobState extends State<RotaryKnob>
    with SingleTickerProviderStateMixin {
  double _currentValue = 0.0;
  double _lastHapticValue = 0.0;
  double _targetValue = 0.0;
  bool _isDragging = false;
  late AnimationController _animController;

  Offset _lastGlobalPosition = Offset.zero;
  double _lastAngle = 0.0;
  // Full turns of arc drag for a full min->max sweep. Tuned for fine control.
  static const double _fullSweepTurns = 1.5;
  // Pixels of vertical drag (center fallback) for a full sweep.
  static const double _fullSweepPixels = 360.0;

  @override
  void initState() {
    super.initState();
    _targetValue = widget.value.clamp(widget.min, widget.max).toDouble();
    _currentValue = _targetValue;
    _lastHapticValue = _currentValue;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _animController.addListener(() {
      if (mounted) {
        setState(() {
          _currentValue = _animController.value;
        });
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _animateTo(double newValue) {
    _animController
      ..stop()
      ..duration = const Duration(milliseconds: 350)
      ..value = _currentValue;
    _animController.animateTo(
      newValue,
      curve: Curves.easeOutBack,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void didUpdateWidget(covariant RotaryKnob oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newTarget = widget.value.clamp(widget.min, widget.max).toDouble();
    if ((newTarget - _targetValue).abs() > 0.001) {
      _targetValue = newTarget;
      if (_isDragging) {
        _animController.stop();
        _currentValue = newTarget;
        _lastHapticValue = newTarget;
      } else {
        _animateTo(newTarget);
      }
    }
  }

  double _valueToAngle() {
    final t = (_currentValue - widget.min) / (widget.max - widget.min);
    final clampedT = t.clamp(0.0, 1.0);
    return math.pi * 0.75 + clampedT * (1.5 * math.pi);
  }

  void _handleDragStart(Offset globalPosition) {
    if (widget.onChanged == null) return;
    _animController.stop();
    _isDragging = true;
    _lastGlobalPosition = globalPosition;
    _lastAngle = _angleFromCenter(globalPosition);
  }

  double _angleFromCenter(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return 0.0;
    final localPos = box.globalToLocal(globalPosition);
    final center = Offset(widget.size / 2, widget.size / 2);
    return math.atan2(localPos.dy - center.dy, localPos.dx - center.dx);
  }

  double _radiusFromCenter(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return 0.0;
    final localPos = box.globalToLocal(globalPosition);
    final center = Offset(widget.size / 2, widget.size / 2);
    return (localPos - center).distance;
  }

  void _handleDragUpdate(Offset globalPosition) {
    if (widget.onChanged == null || !_isDragging) return;
    final range = widget.max - widget.min;
    final radius = _radiusFromCenter(globalPosition);

    double valueDelta;
    if (radius > widget.size * 0.15) {
      final angle = _angleFromCenter(globalPosition);
      var delta = angle - _lastAngle;
      // Shortest signed delta, handling the ±π wraparound.
      if (delta > math.pi) {
        delta -= 2 * math.pi;
      } else if (delta < -math.pi) {
        delta += 2 * math.pi;
      }
      _lastAngle = angle;
      // Clockwise (positive delta in screen coords) = increase.
      valueDelta = delta / (_fullSweepTurns * 2 * math.pi) * range;
    } else {
      final dy = globalPosition.dy - _lastGlobalPosition.dy;
      _lastAngle = _angleFromCenter(globalPosition);
      valueDelta = -dy * range / _fullSweepPixels;
    }

    _lastGlobalPosition = globalPosition;

    final newValue =
        (_currentValue + valueDelta).clamp(widget.min, widget.max);
    final snapped = (newValue * 10).round() / 10.0;

    final diff = (snapped - _lastHapticValue).abs();
    if (diff >= 0.5) {
      AppHaptics.selection();
      _lastHapticValue = snapped;
    }

    setState(() => _currentValue = snapped);
    widget.onChanged!(_currentValue);
  }

  void _handleDragEnd() {
    _isDragging = false;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;
    final angle = _valueToAngle();
    final accent = widget.accentColor ??
        (enabled ? context.adaptiveTextPrimary : context.adaptiveTextTertiary);

    return RawGestureDetector(
      gestures: {
        _KnobDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<_KnobDragGestureRecognizer>(
          () => _KnobDragGestureRecognizer(),
          (instance) {
            instance.onDragStart = _handleDragStart;
            instance.onDragUpdate = _handleDragUpdate;
            instance.onDragEnd = _handleDragEnd;
          },
        ),
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: widget.size,
        height: widget.size + (widget.showLabel ? 20 : 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF141414),
                      border: Border.all(
                        color: AppColors.glassBorder.withValues(alpha: 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(
                            alpha: _isDragging ? 0.15 : 0.06,
                          ),
                          blurRadius: _isDragging ? 20 : 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: KnobArcPainter(
                      angle: angle,
                      color: accent,
                      trackColor: AppColors.glassBorderStrong,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.showLabel) ...[
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class KnobArcPainter extends CustomPainter {
  final double angle;
  final Color color;
  final Color trackColor;

  KnobArcPainter({
    required this.angle,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const startAngle = math.pi * 0.75;
    final sweepAngle = angle - startAngle;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      1.5 * math.pi,
      false,
      trackPaint,
    );

    final activePaint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle.clamp(0.0, 1.5 * math.pi),
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant KnobArcPainter oldPainter) {
    return oldPainter.angle != angle || oldPainter.color != color;
  }
}

/// A custom gesture recognizer that eagerly accepts the pointer,
/// preventing parent scrollables from stealing drag events.
class _KnobDragGestureRecognizer extends OneSequenceGestureRecognizer {
  _KnobDragGestureRecognizer();

  void Function(Offset globalPosition)? onDragStart;
  void Function(Offset globalPosition)? onDragUpdate;
  void Function()? onDragEnd;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer);
    // Eagerly accept — this wins the gesture arena over parent
    // scrollables (e.g. PageView, ListView) immediately.
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      onDragUpdate?.call(event.position);
    }
    if (event is PointerDownEvent) {
      onDragStart?.call(event.position);
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
      onDragEnd?.call();
    }
  }

  @override
  String get debugDescription => '_KnobDragGestureRecognizer';

  @override
  void didStopTrackingLastPointer(int pointer) {}
}
