import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

/// Launch-day streak popup. Shows a rolling 7-day window of containers; the
/// trailing [streak] days are "checked" and animate in with a staggered
/// scale + checkmark reveal, while today's container gently pulses.
///
/// The streak is a contiguous run ending today (see `MilestoneService`), so
/// the active days in the window are simply the last `streak` columns.
class StreakPopup extends StatefulWidget {
  const StreakPopup({super.key, required this.streak, this.onDismiss});

  final int streak;
  final VoidCallback? onDismiss;

  @override
  State<StreakPopup> createState() => _StreakPopupState();
}

class _StreakPopupState extends State<StreakPopup>
    with TickerProviderStateMixin {
  static const _window = 7;
  static const _weekdayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  late final AnimationController _reveal;
  late final AnimationController _pulse;

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
    _reveal.forward();
    // Only pulse once the today cell has revealed.
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _pulse.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _reveal.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// Index in the 7-day window of the cell representing today (rightmost).
  int get _todayIndex => _window - 1;

  /// A cell is checked if it falls within the trailing [streak] days. Today
  /// is always checked (activity is recorded on launch before this popup).
  bool _isChecked(int index) {
    final activeCount = widget.streak.clamp(0, _window);
    return index >= _window - activeCount;
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
            width: 320,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: AppConstants.spacingXl),
                _buildDayRow(),
                const SizedBox(height: AppConstants.spacingXl),
                _buildActions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DAY STREAK',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppConstants.spacingXs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${widget.streak}',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: AppConstants.spacingSm),
            Text(
              widget.streak == 1 ? 'day' : 'days',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingXs),
        Text(
          widget.streak <= 1
              ? "Welcome back — let's start a streak."
              : 'Keep it going. Open tomorrow to add another day.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
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

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onDismiss?.call();
          },
          child: Text(
            'Continue',
            style: TextStyle(color: AppColors.accent),
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.letter,
    required this.dayNumber,
    required this.checked,
    required this.isToday,
    required this.reveal,
    required this.revealStart,
    this.pulse,
  });

  final String letter;
  final int dayNumber;
  final bool checked;
  final bool isToday;
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
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              border: Border.all(
                color: AppColors.accentLight.withValues(alpha: 0.6),
                width: 1,
              ),
              boxShadow: isToday
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.25),
                        blurRadius: 12,
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