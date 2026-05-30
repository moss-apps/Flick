import 'package:flutter/material.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/models/audio_output_diagnostics.dart';

enum _CapsulePhase { entering, visible, exiting, hidden }

/// Animated bit-perfect capsule that replaces the album name pill
/// when streaming bit-perfect audio.
///
/// Animates in/out with a deterministic micro-pixel build.
class BitPerfectCapsule extends StatefulWidget {
  final AudioOutputDiagnostics diagnostics;
  final double horizontalPadding;
  final double verticalPadding;
  final double fontSize;
  final VoidCallback? onTap;
  final VoidCallback? onDismissed;

  const BitPerfectCapsule({
    super.key,
    required this.diagnostics,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.fontSize,
    this.onTap,
    this.onDismissed,
  });

  @override
  State<BitPerfectCapsule> createState() => _BitPerfectCapsuleState();
}

class _BitPerfectCapsuleState extends State<BitPerfectCapsule>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _pixelBuildAnimation;

  _CapsulePhase _phase = _CapsulePhase.hidden;

  bool get _isVerified =>
      widget.diagnostics.capabilityFlags.supportsVerifiedBitPerfect == true;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _pixelBuildAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.addStatusListener(_onAnimationStatus);

    if (_isVerified) {
      _phase = _CapsulePhase.entering;
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant BitPerfectCapsule oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasVerified = oldWidget.diagnostics.capabilityFlags
        .supportsVerifiedBitPerfect ==
        true;

    if (wasVerified && !_isVerified) {
      _phase = _CapsulePhase.exiting;
      _controller.reverse();
    } else if (!wasVerified && _isVerified) {
      _phase = _CapsulePhase.entering;
      _controller.forward();
    }
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        _phase == _CapsulePhase.entering) {
      setState(() => _phase = _CapsulePhase.visible);
    } else if (status == AnimationStatus.dismissed &&
        _phase == _CapsulePhase.exiting) {
      setState(() => _phase = _CapsulePhase.hidden);
      widget.onDismissed?.call();
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _CapsulePhase.hidden) {
      return const SizedBox.shrink();
    }

    final verified = _isVerified;
    final baseColor = verified
        ? Colors.green.withValues(alpha: 0.22)
        : Colors.amber.withValues(alpha: 0.18);
    final textColor = verified ? Colors.green.shade400 : Colors.amber.shade400;
    final borderColor = verified
        ? Colors.green.withValues(alpha: 0.5)
        : Colors.amber.withValues(alpha: 0.4);
    final iconData = verified ? Icons.verified_rounded : Icons.lock_rounded;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return ClipPath(
            clipper: _MicroPixelBuildClipper(
              progress: _pixelBuildAnimation.value,
            ),
            child: child,
          );
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.horizontalPadding,
            vertical: widget.verticalPadding,
          ),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconData, size: widget.fontSize + 2, color: textColor),
              const SizedBox(width: 4),
              Text(
                'BIT-PERFECT',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: context.responsiveText(widget.fontSize),
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MicroPixelBuildClipper extends CustomClipper<Path> {
  final double progress;

  const _MicroPixelBuildClipper({required this.progress});

  @override
  Path getClip(Size size) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    if (clampedProgress >= 1.0) {
      return Path()..addRect(Offset.zero & size);
    }
    if (clampedProgress <= 0.0) {
      return Path();
    }

    final path = Path();
    const cellSize = 2.0;
    final columns = (size.width / cellSize).ceil();
    final rows = (size.height / cellSize).ceil();

    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final horizontalBias = columns <= 1 ? 0.0 : column / (columns - 1);
        final verticalBias = rows <= 1 ? 0.0 : (row - rows / 2).abs() / rows;
        final threshold =
            (horizontalBias * 0.72) +
            (_hash(column, row) * 0.22) +
            (verticalBias * 0.06);

        if (threshold <= clampedProgress) {
          path.addRect(
            Rect.fromLTWH(
              column * cellSize,
              row * cellSize,
              cellSize,
              cellSize,
            ),
          );
        }
      }
    }

    return path;
  }

  double _hash(int column, int row) {
    final value = (column * 73856093) ^ (row * 19349663);
    return (value & 0x3ff) / 0x3ff;
  }

  @override
  bool shouldReclip(_MicroPixelBuildClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}
