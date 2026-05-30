import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/models/audio_output_diagnostics.dart';

/// Animated bit-perfect capsule that replaces the album name pill
/// when streaming bit-perfect audio.
///
/// Animates in with scale + fade + shimmer sweep, then breathes
/// with a subtle glow pulse.
class BitPerfectCapsule extends StatefulWidget {
  final AudioOutputDiagnostics diagnostics;
  final double horizontalPadding;
  final double verticalPadding;
  final double fontSize;

  const BitPerfectCapsule({
    super.key,
    required this.diagnostics,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.fontSize,
  });

  @override
  State<BitPerfectCapsule> createState() => _BitPerfectCapsuleState();
}

class _BitPerfectCapsuleState extends State<BitPerfectCapsule>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _glowController;
  late final AnimationController _shimmerController;

  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _shimmerAnimation;
  late final Animation<double> _iconRotation;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _iconRotation = Tween<double>(begin: -0.5, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.1, 0.6, curve: Curves.elasticOut),
      ),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _shimmerController,
        curve: Curves.easeInOut,
      ),
    );

    _entranceController.forward().then((_) {
      if (mounted) {
        _glowController.repeat(reverse: true);
        _shimmerController.forward();
      }
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _glowController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = widget.diagnostics.resamplerActive == true;
    final verified = !isLocked;

    final baseColor = verified
        ? Colors.green.withValues(alpha: 0.22)
        : Colors.amber.withValues(alpha: 0.18);
    final textColor = verified ? Colors.green.shade400 : Colors.amber.shade400;
    final borderColor = verified
        ? Colors.green.withValues(alpha: 0.5)
        : Colors.amber.withValues(alpha: 0.4);
    final glowColor = verified
        ? Colors.green.withValues(alpha: 0.35)
        : Colors.amber.withValues(alpha: 0.28);
    final iconData = verified ? Icons.verified_rounded : Icons.lock_rounded;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _entranceController,
        _glowController,
        _shimmerController,
      ]),
      builder: (context, child) {
        final glowAlpha = _glowAnimation.value * 0.25;
        final shimmerX = _shimmerAnimation.value;

        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value.clamp(0.0, 1.0),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: widget.horizontalPadding,
                vertical: widget.verticalPadding,
              ),
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withValues(alpha: glowAlpha),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: glowColor.withValues(alpha: glowAlpha * 0.5),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Stack(
                  children: [
                    if (_shimmerController.isAnimating &&
                        !_shimmerController.isCompleted)
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment(shimmerX, 0),
                          child: Container(
                            width: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.12),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.rotate(
                          angle: _iconRotation.value * math.pi * 2,
                          child: Icon(
                            iconData,
                            size: widget.fontSize + 2,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'BIT-PERFECT',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: context.responsiveText(
                              widget.fontSize,
                            ),
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
