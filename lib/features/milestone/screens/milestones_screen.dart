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
  int _playCount = 0;
  int _listenSeconds = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final records = await _service.getShownMilestones();
    _playCount = await _service.getHistoryCount();
    _listenSeconds = await _service.getAccumulatedListenSeconds();
    if (!mounted) return;
    setState(() {
      _records = {for (final r in records) r.type: r};
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
    return GridView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingMd,
      ),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisSpacing: AppConstants.spacingMd,
        crossAxisSpacing: AppConstants.spacingMd,
        childAspectRatio: 1.5,
      ),
      itemCount: MilestoneType.values.length,
      itemBuilder: (context, index) {
        final type = MilestoneType.values[index];
        final record = _records[type];
        return _MilestoneTile(
          type: type,
          record: record,
          playCount: _playCount,
          listenSeconds: _listenSeconds,
          onTap: () => _handleTileTap(type, record),
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
              nextLabel: next.next?.shortLabel,
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
    final current = type.isSongBased ? _playCount : (_listenSeconds ~/ 3600);
    final remaining = (type.threshold - current).clamp(0, type.threshold);
    final unit = type.isSongBased
        ? (remaining == 1 ? 'song' : 'songs')
        : (remaining == 1 ? 'hour' : 'hours');
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

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({
    required this.type,
    required this.record,
    required this.playCount,
    required this.listenSeconds,
    required this.onTap,
  });

  final MilestoneType type;
  final MilestoneRecord? record;
  final int playCount;
  final int listenSeconds;
  final VoidCallback onTap;

  bool get _unlocked => record != null;

  @override
  Widget build(BuildContext context) {
    final tierColor = type.tierColor;
    final unlocked = _unlocked;
    // Tinted icon badge — reuses the app's settings _CategoryTile pattern.
    final iconBg = unlocked
        ? Color.alphaBlend(
            tierColor.withValues(alpha: 0.85),
            _darkBaseFor(type),
          )
        : AppColors.glassBackgroundStrong;
    final iconFg = unlocked ? Colors.white : AppColors.textTertiary;

    final current = type.isSongBased ? playCount : (listenSeconds ~/ 3600);
    final progress = (current / type.threshold).clamp(0.0, 1.0);
    final unit = type.isSongBased ? 'songs' : 'hours';

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
              Expanded(
                child: Row(
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

  /// Per-tier darker base color so the icon badge has the tier identity but
  /// still reads as a "filled" pill on the dark glass surface (not washed out).
  Color _darkBaseFor(MilestoneType type) {
    return switch (type) {
      MilestoneType.songs100 => const Color(0xFF2A1E14),
      MilestoneType.songs500 => const Color(0xFF1F2429),
      MilestoneType.songs1000 => const Color(0xFF2B2417),
      MilestoneType.hours10 => const Color(0xFF152238),
      MilestoneType.hours50 => const Color(0xFF251E36),
    };
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
                    ? 'Listen to $remaining more $unit to unlock.'
                    : 'You\'ve hit the threshold — keep listening!',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
