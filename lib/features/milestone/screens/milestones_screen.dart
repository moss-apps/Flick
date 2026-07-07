import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/services/milestone_service.dart';
import 'package:flick/features/player/widgets/ambient_background.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/features/milestone/widgets/milestone_card.dart';
import 'package:flick/features/milestone/widgets/streak_popup.dart';

/// Achievement-style collection view of every milestone tier. Unlocked tiles
/// re-open the celebration card on tap; locked tiles show a small bottom
/// sheet with the requirement and current progress.
class MilestonesScreen extends ConsumerStatefulWidget {
  const MilestonesScreen({super.key});

  @override
  ConsumerState<MilestonesScreen> createState() => _MilestonesScreenState();
}

class _MilestonesScreenState extends ConsumerState<MilestonesScreen> {
  final _service = MilestoneService();
  bool _loading = true;
  Map<MilestoneType, MilestoneRecord> _records = {};
  Map<MilestoneCategory, int> _current = const {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final records = await _service.getShownMilestones();
    final playCount = await _service.getHistoryCount();
    final listenSeconds = await _service.getAccumulatedListenSeconds();
    final streak = await _service.getCurrentDayStreak();
    final artists = await _service.getUniqueArtistCount();
    if (!mounted) return;
    setState(() {
      _records = {for (final r in records) r.type: r};
      _current = {
        MilestoneCategory.songs: playCount,
        MilestoneCategory.hours: listenSeconds ~/ 3600,
        MilestoneCategory.dayStreak: streak,
        MilestoneCategory.uniqueArtists: artists,
      };
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = _records.length;
    final currentSong = ref.watch(currentSongProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.backgroundGradient,
            ),
          ),
          Positioned.fill(
            child: AmbientBackground(song: currentSong),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, unlocked),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          child: _buildGrid(context),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int unlocked) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingMd,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(LucideIcons.arrowLeft),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: AppConstants.spacingXs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Milestones',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$unlocked / ${MilestoneType.values.length} unlocked',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.adaptiveTextTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final cats = MilestoneCategory.values;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingMd,
      ),
      itemCount: cats.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppConstants.spacingMd),
            child: _StreakBanner(
              streak: _current[MilestoneCategory.dayStreak] ?? 0,
              onTap: _showStreakDialog,
            ),
          );
        }
        final cat = cats[index - 1];
        return Padding(
          padding: EdgeInsets.only(
            bottom: index - 1 < cats.length - 1 ? AppConstants.spacingMd : 0,
          ),
          child: _CategorySection(
            category: cat,
            records: _records,
            current: _current,
            onTileTap: _handleTileTap,
          ),
        );
      },
    );
  }

  void _showStreakDialog() {
    final streak = _current[MilestoneCategory.dayStreak] ?? 0;
    if (streak < 1) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Day streak',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            ),
            child: StreakPopup(
              streak: streak,
              onSnooze: () => _service.snoozeStreakPopup(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleTileTap(
    MilestoneType type,
    MilestoneRecord? record,
  ) async {
    if (record != null) {
      await _showCelebration(type, achievedAt: record.achievedAt);
    } else {
      await _showLockedSheet(type);
    }
  }

  Future<void> _showCelebration(
    MilestoneType type, {
    required DateTime achievedAt,
  }) async {
    final next = await _service.getNextMilestone();
    if (!mounted) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Milestone',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            ),
            child: MilestoneCard(
              milestone: type,
              achievedAt: achievedAt,
              nextMilestone: next.next,
              nextRemaining: next.next == null ? null : next.remaining,
              supportLabel: 'Close',
              dismissLabel: 'Done',
            ),
          ),
        );
      },
    );
  }

  Future<void> _showLockedSheet(MilestoneType type) async {
    final current = _current[type.category] ?? 0;
    final remaining = (type.threshold - current).clamp(0, type.threshold);
    final unit = remaining == 1 ? type.category.unitSingular : type.unit;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (sheetContext) {
        return _LockedSheet(
          type: type,
          current: current,
          remaining: remaining,
          unit: unit,
        );
      },
    );
  }
}

class _CategorySection extends StatefulWidget {
  const _CategorySection({
    required this.category,
    required this.records,
    required this.current,
    required this.onTileTap,
  });

  final MilestoneCategory category;
  final Map<MilestoneType, MilestoneRecord> records;
  final Map<MilestoneCategory, int> current;
  final void Function(MilestoneType, MilestoneRecord?) onTileTap;

  @override
  State<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<_CategorySection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    final types = MilestoneType.values
        .where((t) => t.category == cat)
        .toList();
    final unlocked = types.where((t) => widget.records[t] != null).length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              child: Row(
                children: [
                  Icon(
                    types.first.tierIcon,
                    size: 20,
                    color: context.adaptiveTextTertiary,
                  ),
                  const SizedBox(width: AppConstants.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _categoryLabel(cat),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: context.adaptiveTextPrimary,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$unlocked / ${types.length} unlocked',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.adaptiveTextTertiary),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: AppConstants.animationNormal,
                    child: Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: context.adaptiveTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppConstants.animationNormal,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedOpacity(
              duration: AppConstants.animationNormal,
              opacity: _expanded ? 1.0 : 0.0,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppConstants.spacingMd,
                        0,
                        AppConstants.spacingMd,
                        AppConstants.spacingMd,
                      ),
                      child: Column(
                        children: [
                          for (final type in types) ...[
                            _MilestoneTile(
                              type: type,
                              record: widget.records[type],
                              current: widget.current[type.category] ?? 0,
                              onTap: () =>
                                  widget.onTileTap(type, widget.records[type]),
                            ),
                            const SizedBox(height: AppConstants.spacingSm),
                          ],
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

String _categoryLabel(MilestoneCategory cat) => switch (cat) {
  MilestoneCategory.songs => 'Songs',
  MilestoneCategory.hours => 'Listening Hours',
  MilestoneCategory.dayStreak => 'Day Streak',
  MilestoneCategory.uniqueArtists => 'Unique Artists',
};

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({
    required this.type,
    required this.record,
    required this.current,
    required this.onTap,
  });

  final MilestoneType type;
  final MilestoneRecord? record;
  final int current;
  final VoidCallback onTap;

  bool get _unlocked => record != null;

  @override
  Widget build(BuildContext context) {
    final tierColor = type.tierColor;
    final unlocked = _unlocked;
    // Tinted icon badge — a dark tint of the tier color keeps each tier's
    // identity while reading as a filled pill on the glass surface.
    final iconBg = unlocked
        ? Color.alphaBlend(tierColor.withValues(alpha: 0.8), AppColors.surfaceDark)
        : AppColors.glassBackgroundStrong;
    final iconFg = unlocked ? Colors.white : AppColors.textTertiary;

    final progress = (current / type.threshold).clamp(0.0, 1.0);
    final unit = type.unit;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(
              color: unlocked
                  ? tierColor.withValues(alpha: 0.35)
                  : AppColors.glassBorder,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ColoredSettingsIcon(
                    icon: type.tierIcon,
                    backgroundColor: iconBg,
                    iconColor: iconFg,
                  ),
                  const SizedBox(width: AppConstants.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          type.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: unlocked
                                    ? context.adaptiveTextPrimary
                                    : context.adaptiveTextTertiary,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          unlocked
                              ? 'Achieved ${_formatDate(record!.achievedAt)}'
                              : 'Locked',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.adaptiveTextTertiary),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    unlocked
                        ? LucideIcons.circleCheck
                        : LucideIcons.chevronRight,
                    color: unlocked
                        ? tierColor
                        : context.adaptiveTextTertiary,
                    size: 18,
                  ),
                ],
              ),
              if (!unlocked) ...[
                const SizedBox(height: AppConstants.spacingSm),
                _MiniProgressBar(value: progress, color: tierColor),
                const SizedBox(height: 4),
                Text(
                  '$current / ${type.threshold} $unit',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.adaptiveTextTertiary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _MiniProgressBar extends StatelessWidget {
  const _MiniProgressBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 3,
        backgroundColor: AppColors.glassBorder,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

class _LockedSheet extends StatelessWidget {
  const _LockedSheet({
    required this.type,
    required this.current,
    required this.remaining,
    required this.unit,
  });

  final MilestoneType type;
  final int current;
  final int remaining;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final tierColor = type.tierColor;
    final progress = (current / type.threshold).clamp(0.0, 1.0);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Container(
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppConstants.radiusXl),
            border: Border.all(color: AppColors.glassBorder, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ColoredSettingsIcon(
                    icon: type.tierIcon,
                    backgroundColor: tierColor.withValues(alpha: 0.85),
                    iconColor: Colors.white,
                  ),
                  const SizedBox(width: AppConstants.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Locked',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.adaptiveTextTertiary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingLg),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.glassBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                ),
              ),
              const SizedBox(height: AppConstants.spacingSm),
              Text(
                '$current / ${type.threshold} $unit',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.adaptiveTextTertiary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: AppConstants.spacingXs),
              Text(
                remaining > 0
                    ? '$remaining more $unit to unlock.'
                    : 'You\'ve hit the threshold — keep it up!',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakBanner extends StatefulWidget {
  const _StreakBanner({required this.streak, this.onTap});

  final int streak;
  final VoidCallback? onTap;

  @override
  State<_StreakBanner> createState() => _StreakBannerState();
}

class _StreakBannerState extends State<_StreakBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  Color get _tierColor =>
      MilestoneCategory.dayStreak.tierColorFor(widget.streak) ?? AppColors.accent;

  int get _tierCount =>
      MilestoneCategory.dayStreak.tierCountFor(widget.streak);

  @override
  Widget build(BuildContext context) {
    final streak = widget.streak;
    final nextTier = MilestoneType.values
        .where((t) =>
            t.category == MilestoneCategory.dayStreak && t.threshold > streak)
        .toList()
      ..sort((a, b) => a.threshold.compareTo(b.threshold));
    final next = nextTier.isEmpty ? null : nextTier.first;

    return AnimatedBuilder(
      animation: _sweep,
      builder: (context, child) {
        return CustomPaint(
          painter: _BorderSweepPainter(
            progress: _sweep.value,
            radius: AppConstants.radiusLg,
            color: _tierColor,
            peakAlpha: 0.55 + 0.1 * _tierCount,
          ),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          child: Container(
            padding: const EdgeInsets.all(AppConstants.spacingLg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.surface.withValues(alpha: 0.8),
                  AppColors.surfaceDark.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              border: Border.all(
                color: _tierColor.withValues(alpha: 0.15 + 0.05 * _tierCount),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _sweep,
                  builder: (context, _) {
                    // Derive a smooth pulse from the sweep controller so
                    // no second ticker is needed.
                    final pulse =
                        (math.sin(_sweep.value * 2 * math.pi) + 1) / 2;
                    final glow = _tierCount == 0
                        ? 0.0
                        : 0.15 + 0.15 * pulse * (_tierCount / 3);
                    return Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _tierColor.withValues(alpha: 0.1),
                        border: Border.all(
                          color: _tierColor.withValues(alpha: 0.25),
                          width: 1,
                        ),
                        boxShadow: glow > 0
                            ? [
                                BoxShadow(
                                  color: _tierColor.withValues(alpha: glow),
                                  blurRadius: 14 + 6 * pulse,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        LucideIcons.flame,
                        size: 26,
                        color: _tierColor,
                      ),
                    );
                  },
                ),
                const SizedBox(width: AppConstants.spacingLg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Streak',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.adaptiveTextTertiary,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$streak',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.adaptiveTextPrimary,
                            ),
                          ),
                          const SizedBox(width: AppConstants.spacingXs),
                          Text(
                            streak == 1 ? 'day' : 'days',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                              color: context.adaptiveTextTertiary,
                            ),
                          ),
                        ],
                      ),
                      if (next != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${next.threshold - streak} more to ${next.title}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.adaptiveTextTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: context.adaptiveTextTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BorderSweepPainter extends CustomPainter {
  _BorderSweepPainter({
    required this.progress,
    required this.radius,
    required this.color,
    required this.peakAlpha,
  });

  final double progress;
  final double radius;
  final Color color;
  final double peakAlpha;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.75),
      Radius.circular(radius),
    );

    final sweep = SweepGradient(
      startAngle: 0,
      endAngle: 2 * math.pi,
      colors: [
        color.withValues(alpha: 0),
        color.withValues(alpha: 0),
        color.withValues(alpha: peakAlpha),
        color.withValues(alpha: 0),
        color.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
      transform: GradientRotation(progress * 2 * math.pi),
    );

    final paint = Paint()
      ..shader = sweep.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_BorderSweepPainter old) =>
      old.progress != progress || old.peakAlpha != peakAlpha;
}
