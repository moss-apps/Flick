import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/milestone_service.dart';

/// Launch-day streak popup. Shows a rolling 7-day window of containers; the
/// trailing [streak] days are "checked" and animate in with a staggered
/// scale + checkmark reveal, while today's container gently pulses.
///
/// The streak is a contiguous run ending today (see `MilestoneService`), so
/// the active days in the window are simply the last `streak` columns.
class StreakPopup extends StatefulWidget {
  const StreakPopup({
    super.key,
    required this.streak,
    this.onDismiss,
    this.onSnooze,
  });

  final int streak;
  final VoidCallback? onDismiss;
  final VoidCallback? onSnooze;

  @override
  State<StreakPopup> createState() => _StreakPopupState();
}

class _StreakPopupState extends State<StreakPopup>
    with TickerProviderStateMixin {
  static const _window = 7;
  static const _weekdayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  late final AnimationController _reveal;
  late final AnimationController _pulse;
  late final AnimationController _flame;
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _flame = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    // Shimmer sweeps faster as the streak climbs tiers.
    _shimmer = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2400 - 400 * _tierCount),
    );
    _reveal.forward();
    _flame.repeat(reverse: true);
    if (_tierCount > 0) {
      _shimmer.repeat(reverse: true);
    }
    // Only pulse once the today cell has revealed.
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _pulse.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _reveal.dispose();
    _pulse.dispose();
    _flame.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  /// Tier accent (bronze/silver/gold) once a streak tier is met, else the
  /// neutral app accent — keeps short streaks monochrome.
  Color get _tierColor =>
      MilestoneCategory.dayStreak.tierColorFor(widget.streak) ?? AppColors.accent;

  /// How many streak tiers are met (0–3). Scales highlight intensity.
  int get _tierCount =>
      MilestoneCategory.dayStreak.tierCountFor(widget.streak);

  /// Index in the 7-day window of the cell representing today (rightmost).
  int get _todayIndex => _window - 1;

  /// A cell is checked if it falls within the trailing [streak] days. Today
  /// is always checked (activity is recorded on launch before this popup).
  bool _isChecked(int index) {
    final activeCount = widget.streak.clamp(0, _window);
    return index >= _window - activeCount;
  }

  String get _motivationalMessage {
    final s = widget.streak;
    if (s <= 1) return "Welcome back — let's start a streak.";
    if (s < 7) return 'Keep it going. Open tomorrow to add another day.';
    if (s < 30) return 'A week and counting — your dedication shows.';
    return 'Incredible — over a month of daily listening.';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppConstants.glassBlurSigma,
            sigmaY: AppConstants.glassBlurSigma,
          ),
          child: Container(
            width: 340,
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spacingLg,
              AppConstants.spacingXl,
              AppConstants.spacingLg,
              AppConstants.spacingLg,
            ),
            decoration: BoxDecoration(
              color: AppColors.glassBackground,
              borderRadius: BorderRadius.circular(AppConstants.radiusXl),
              border: Border.all(color: AppColors.glassBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildFlameIcon(),
                const SizedBox(height: AppConstants.spacingLg),
                _buildHeader(context),
                const SizedBox(height: AppConstants.spacingXl),
                _buildDayRow(),
                const SizedBox(height: AppConstants.spacingLg),
                _buildMessage(context),
                const SizedBox(height: AppConstants.spacingLg),
                _buildContinueButton(context),
                const SizedBox(height: AppConstants.spacingXs),
                _buildSnoozeButton(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlameIcon() {
    return AnimatedBuilder(
      animation: _flame,
      builder: (context, child) {
        // Glow amplitude and spread climb with each met streak tier.
        final glow = 0.08 + (0.04 + 0.05 * _tierCount) * _flame.value;
        final scale = 1.0 + 0.04 * _flame.value;
        final blur = 20.0 + 10.0 * _tierCount;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _tierColor.withValues(alpha: 0.08),
              border: Border.all(
                color: _tierColor.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _tierColor.withValues(alpha: glow),
                  blurRadius: blur,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              LucideIcons.flame,
              size: 30,
              color: _tierColor,
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildShimmerNumber(context),
            const SizedBox(width: AppConstants.spacingSm),
            Text(
              'day streak',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The streak count, with an animated tier-colored shimmer band sweeping
  /// across it once a streak tier is met. Below tier 7 the number is plain.
  Widget _buildShimmerNumber(BuildContext context) {
    final number = Text(
      '${widget.streak}',
      style: Theme.of(context).textTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    if (_tierCount == 0) return number;
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, child) {
        final t = _shimmer.value;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) {
            const span = 0.45;
            final center = -1.0 + 2.0 * t;
            return LinearGradient(
              begin: Alignment(center - span, 0),
              end: Alignment(center + span, 0),
              colors: [
                AppColors.textPrimary,
                _tierColor,
                AppColors.textPrimary,
              ],
            ).createShader(rect);
          },
          child: child,
        );
      },
      child: number,
    );
  }

  Widget _buildDayRow() {
    final now = DateTime.now();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_window, (i) {
        final day = now.subtract(Duration(days: _window - 1 - i));
        final checked = _isChecked(i);
        final isToday = i == _todayIndex;
        return _DayCell(
          letter: _weekdayLetters[day.weekday % 7],
          dayNumber: day.day,
          checked: checked,
          isToday: isToday,
          color: _tierColor,
          glowTier: _tierCount,
          reveal: _reveal,
          revealStart: _revealStartFor(i),
          pulse: isToday ? _pulse : null,
        );
      }),
    );
  }

  /// Stagger each checked cell, oldest active first, leaving the unchecked
  /// cells out of the reveal (they render instantly in their dim state).
  double _revealStartFor(int index) {
    if (!_isChecked(index)) return 1.0;
    final activeIndex = index - (_window - widget.streak.clamp(0, _window));
    const perCell = 0.11;
    final start = activeIndex * perCell;
    return start.clamp(0.0, 0.85);
  }

  Widget _buildMessage(BuildContext context) {
    return Text(
      _motivationalMessage,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AppColors.textSecondary,
        height: 1.4,
      ),
    );
  }

  Widget _buildContinueButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: () {
          Navigator.of(context).pop();
          widget.onDismiss?.call();
        },
        style: FilledButton.styleFrom(
          backgroundColor: _tierColor,
          foregroundColor: AppColors.background,
          padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
        ),
        child: const Text(
          'Continue',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildSnoozeButton(BuildContext context) {
    return TextButton(
      onPressed: () {
        Navigator.of(context).pop();
        widget.onSnooze?.call();
      },
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingSm,
          vertical: AppConstants.spacingXs,
        ),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        "Don't show again today",
        style: TextStyle(
          color: AppColors.textTertiary,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.letter,
    required this.dayNumber,
    required this.checked,
    required this.isToday,
    required this.color,
    required this.glowTier,
    required this.reveal,
    required this.revealStart,
    this.pulse,
  });

  final String letter;
  final int dayNumber;
  final bool checked;
  final bool isToday;
  final Color color;
  final int glowTier;
  final AnimationController reveal;
  final double revealStart;
  final AnimationController? pulse;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          letter,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isToday ? AppColors.textPrimary : AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: AppConstants.spacingXs),
        SizedBox(
          width: 34,
          height: 34,
          child: _buildBox(),
        ),
        const SizedBox(height: AppConstants.spacingXs),
        Text(
          '$dayNumber',
          style: TextStyle(
            fontSize: 11,
            color: isToday ? AppColors.textSecondary : AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildBox() {
    if (!checked) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.glassBackground,
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          border: Border.all(color: AppColors.glassBorder, width: 1),
        ),
      );
    }

    final revealCurve = CurvedAnimation(
      parent: reveal,
      curve: Interval(
        revealStart,
        (revealStart + 0.18).clamp(0.0, 1.0),
        curve: Curves.easeOutBack,
      ),
    );
    final checkFade = CurvedAnimation(
      parent: reveal,
      curve: Interval(
        (revealStart + 0.04).clamp(0.0, 1.0),
        (revealStart + 0.16).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );

    Widget box = AnimatedBuilder(
      animation: reveal,
      builder: (context, _) {
        final scale = revealCurve.value.clamp(0.001, double.infinity);
        return Transform.scale(
          scale: scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              border: Border.all(
                color: Color.lerp(color, Colors.white, 0.25)!.withValues(alpha: 0.6),
                width: 1,
              ),
              boxShadow: isToday
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.25 + 0.05 * glowTier),
                        blurRadius: 12 + 2.0 * glowTier,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: FadeTransition(
                opacity: checkFade,
                child: const Icon(
                  LucideIcons.check,
                  size: 18,
                  color: AppColors.background,
                ),
              ),
            ),
          ),
        );
      },
    );

    if (pulse != null) {
      box = AnimatedBuilder(
        animation: pulse!,
        builder: (context, child) {
          final p = 1.0 + 0.06 * pulse!.value;
          return Transform.scale(scale: p, child: child);
        },
        child: box,
      );
    }

    return box;
  }
}
