import 'package:flick/core/utils/app_haptics.dart';
import 'package:flick/features/player/widgets/ambient_background.dart';
import 'package:flick/widgets/common/flick_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/audio_metadata_utils.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/services/duplicate_cleaner_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _formatFileSize(int? bytes) {
  if (bytes == null || bytes <= 0) return '—';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

String _fileName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final parts = normalized.split('/');
  return parts.isNotEmpty ? parts.last : path;
}

String _folderName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final parts = normalized.split('/');
  if (parts.length >= 2) return parts[parts.length - 2];
  return '';
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class DuplicateCleanerScreen extends ConsumerStatefulWidget {
  const DuplicateCleanerScreen({super.key});

  @override
  ConsumerState<DuplicateCleanerScreen> createState() =>
      _DuplicateCleanerScreenState();
}

class _DuplicateCleanerScreenState extends ConsumerState<DuplicateCleanerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(duplicateScanProvider.notifier).scanForDuplicates();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(duplicateScanProvider);
    final currentSong = ref.watch(currentSongProvider);

    return Stack(
      children: [
        Positioned.fill(child: AmbientBackground(song: currentSong)),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  scanState: scanState,
                  onBack: () => Navigator.of(context).pop(),
                  onRefresh: () => ref
                      .read(duplicateScanProvider.notifier)
                      .scanForDuplicates(),
                ),
                Expanded(child: _buildBody(context, scanState)),
                if (scanState.result != null &&
                    scanState.result!.totalDuplicates > 0)
                  _BottomActionBar(scanState: scanState),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, DuplicateScanState scanState) {
    if (scanState.isScanning) {
      return _buildScanningView(context);
    }
    if (scanState.error != null) {
      return _buildErrorView(context, scanState.error!);
    }
    if (scanState.result == null) {
      return _buildEmptyView(context);
    }
    if (scanState.result!.totalDuplicates == 0) {
      return _buildNoDuplicatesView(context);
    }
    return _buildDuplicatesView(context, scanState);
  }

  Widget _buildScanningView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            Text(
              'Scanning for duplicates…',
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: context.adaptiveTextPrimary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              'Grouping by title & artist — this is usually quick.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 13,
                height: 1.4,
                color: context.adaptiveTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.errorDim,
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                border: Border.all(color: AppColors.errorBorder),
              ),
              child: Icon(
                LucideIcons.triangleAlert,
                size: 32,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.adaptiveTextPrimary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 13,
                height: 1.4,
                color: context.adaptiveTextSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            SizedBox(
              width: double.infinity,
              child: FlickDialogButton(
                label: 'Try again',
                style: FlickDialogButtonStyle.primary,
                onPressed: () => ref
                    .read(duplicateScanProvider.notifier)
                    .scanForDuplicates(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(BuildContext context) {
    return Center(
      child: Text(
        'No scan results yet',
        style: TextStyle(
          fontFamily: 'ProductSans',
          fontSize: 15,
          color: context.adaptiveTextSecondary,
        ),
      ),
    );
  }

  Widget _buildNoDuplicatesView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppConstants.radiusXl),
                border: Border.all(
                  color: Colors.green.withValues(alpha: 0.28),
                ),
              ),
              child: const Icon(
                LucideIcons.sparkles,
                size: 40,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            Text(
              'All clear — no duplicates',
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: context.adaptiveTextPrimary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              'Your library is tidy. We’ll let you know if new duplicates appear after the next scan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 13,
                height: 1.45,
                color: context.adaptiveTextSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            FlickDialogButton(
              label: 'Scan again',
              style: FlickDialogButtonStyle.secondary,
              onPressed: () => ref
                  .read(duplicateScanProvider.notifier)
                  .scanForDuplicates(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDuplicatesView(
    BuildContext context,
    DuplicateScanState scanState,
  ) {
    final result = scanState.result!;

    return Column(
      children: [
        _SummaryCard(scanState: scanState, result: result),
        const SizedBox(height: AppConstants.spacingSm),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
          ),
          child: Row(
            children: [
              const Icon(
                LucideIcons.mousePointerClick,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Check versions to keep — unchecked will be removed',
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (scanState.hasCustomSelection)
                GestureDetector(
                  onTap: () {
                    AppHaptics.tap();
                    ref
                        .read(duplicateScanProvider.notifier)
                        .resetAllToRecommended();
                  },
                  child: const Text(
                    'Reset',
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.textPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.spacingSm),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMd,
            ).copyWith(bottom: AppConstants.spacingMd),
            itemCount: result.duplicateGroups.length,
            itemBuilder: (context, index) {
              final group = result.duplicateGroups[index];
              return _DuplicateGroupCard(group: group);
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.scanState,
    required this.onBack,
    required this.onRefresh,
  });

  final DuplicateScanState scanState;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final hasResult = scanState.result != null;
    final subtitle = scanState.isScanning
        ? 'Scanning your library…'
        : hasResult
            ? (scanState.result!.totalDuplicates == 0
                ? 'No duplicates found'
                : '${scanState.result!.totalGroups} groups • ${scanState.result!.totalDuplicates} to remove')
            : 'Find and clean up duplicate songs';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      child: Row(
        children: [
          Material(
            color: AppColors.surface.withValues(alpha: 0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusRound),
              side: BorderSide(color: AppColors.glassBorder),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppConstants.radiusRound),
              onTap: onBack,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  LucideIcons.chevronLeft,
                  size: context.responsiveIcon(AppConstants.iconSizeMd),
                  color: context.adaptiveTextPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Duplicate Cleaner',
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.adaptiveTextPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: context.adaptiveTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          if (hasResult && !scanState.isScanning)
            Material(
              color: AppColors.surface.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                side: BorderSide(color: AppColors.glassBorder),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                onTap: onRefresh,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    LucideIcons.refreshCw,
                    size: 18,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary card
// ---------------------------------------------------------------------------

class _SummaryCard extends ConsumerStatefulWidget {
  const _SummaryCard({required this.scanState, required this.result});

  final DuplicateScanState scanState;
  final DuplicateScanResult result;

  @override
  ConsumerState<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends ConsumerState<_SummaryCard> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final scanState = widget.scanState;
    final result = widget.result;
    final toRemove = scanState.selectedRemoveCount;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd)
          .copyWith(top: AppConstants.spacingSm),
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.glassBorderStrong),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  border: Border.all(color: AppColors.glassBorderStrong),
                ),
                child: const Icon(
                  LucideIcons.copy,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppConstants.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Review before you clean',
                      style: TextStyle(
                        fontFamily: 'ProductSans',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _collapsed
                          ? '${result.totalGroups} groups • $toRemove to remove'
                          : 'Only library entries are removed — your audio files stay on disk.',
                      style: TextStyle(
                        fontFamily: 'ProductSans',
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.textSecondary
                            .withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              GestureDetector(
                onTap: () {
                  AppHaptics.tap();
                  setState(() => _collapsed = !_collapsed);
                },
                child: AnimatedRotation(
                  turns: _collapsed ? -0.25 : 0,
                  duration: AppConstants.animationNormal,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.glassBackgroundStrong,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Icon(
                      LucideIcons.chevronDown,
                      color: context.adaptiveTextSecondary,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: AppConstants.animationNormal,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedOpacity(
              duration: AppConstants.animationNormal,
              opacity: _collapsed ? 0.0 : 1.0,
              child: _collapsed
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppConstants.spacingMd),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.spacingMd,
                            vertical: AppConstants.spacingSm,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundLight
                                .withValues(alpha: 0.9),
                            borderRadius:
                                BorderRadius.circular(AppConstants.radiusMd),
                            border: Border.all(
                                color: AppColors.glassBorderStrong),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _SummaryStat(
                                label: 'Groups',
                                value: result.totalGroups.toString(),
                                icon: LucideIcons.layers,
                              ),
                              Container(
                                width: 1,
                                height: 36,
                                color: AppColors.glassBorder,
                              ),
                              _SummaryStat(
                                label: 'To remove',
                                value: toRemove.toString(),
                                icon: LucideIcons.trash2,
                                highlight: true,
                              ),
                              Container(
                                width: 1,
                                height: 36,
                                color: AppColors.glassBorder,
                              ),
                              _SummaryStat(
                                label: 'Will keep',
                                value: scanState.selectedKeepCount
                                    .toString(),
                                icon: LucideIcons.shieldCheck,
                              ),
                            ],
                          ),
                        ),
                        if (scanState.hasCustomSelection) ...[
                          const SizedBox(height: AppConstants.spacingSm),
                          Row(
                            children: [
                              const Icon(
                                LucideIcons.info,
                                size: 13,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  "You customized which versions to keep. Nice — you're in control.",
                                  style: TextStyle(
                                    fontFamily: 'ProductSans',
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 18,
          color: highlight
              ? AppColors.textPrimary
              : context.adaptiveTextSecondary,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'ProductSans',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.adaptiveTextPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'ProductSans',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom action bar
// ---------------------------------------------------------------------------

class _BottomActionBar extends ConsumerWidget {
  const _BottomActionBar({required this.scanState});

  final DuplicateScanState scanState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toRemove = scanState.selectedRemoveCount;
    final isRemoving = scanState.isRemoving;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppConstants.spacingMd,
        AppConstants.spacingMd,
        AppConstants.spacingMd,
        MediaQuery.paddingOf(context).bottom + AppConstants.spacingMd,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.86),
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.info,
                size: 14,
                color: context.adaptiveTextTertiary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isRemoving
                      ? 'Removing duplicates…'
                      : 'Ready to remove $toRemove song${toRemove == 1 ? '' : 's'} — keeping ${scanState.selectedKeepCount} in total.',
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.adaptiveTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingSm),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isRemoving || toRemove == 0
                  ? null
                  : () => _confirmRemoveSelected(context, ref, toRemove),
              icon: isRemoving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(LucideIcons.trash2, size: 18),
              label: Text(
                isRemoving ? 'Removing…' : 'Remove $toRemove duplicates',
                style: const TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error.withValues(alpha: 0.92),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.glassBackgroundStrong.withValues(alpha: 0.5),
                disabledForegroundColor: context.adaptiveTextTertiary,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingXs),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: isRemoving
                  ? null
                  : () => _confirmRemoveAll(context, ref, toRemove),
              style: TextButton.styleFrom(
                foregroundColor: context.adaptiveTextSecondary,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
              ),
              child: Text(
                'Or remove all using recommended picks',
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.adaptiveTextSecondary,
                  decoration: TextDecoration.underline,
                  decorationColor: context.adaptiveTextTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemoveSelected(
    BuildContext context,
    WidgetRef ref,
    int toRemove,
  ) async {
    final kept = ref.read(duplicateScanProvider).selectedKeepCount;
    final confirmed = await FlickDialogs.confirm(
      context,
      title: 'Remove $toRemove duplicates?',
      message:
          'We’ll keep your $kept checked version${kept == 1 ? '' : 's'} and remove the other ${toRemove == 1 ? 'copy' : 'copies'} from your library. Audio files on disk are not deleted.',
      confirmLabel: 'Remove',
      destructive: true,
      icon: LucideIcons.trash2,
    );
    if (!confirmed) return;
    final result =
        await ref.read(duplicateScanProvider.notifier).removeSelected();
    if (!context.mounted) return;
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceLight,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
          content: Row(
            children: [
              const Icon(LucideIcons.check, size: 18, color: Colors.green),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Removed ${result.removedCount} duplicates — kept ${result.keptCount}.',
                  style: const TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _confirmRemoveAll(
    BuildContext context,
    WidgetRef ref,
    int toRemove,
  ) async {
    final confirmed = await FlickDialogs.confirm(
      context,
      title: 'Remove all with best picks?',
      message:
          'We’ll keep the best-quality version in each group (prefers album art, then highest bitrate) and remove $toRemove ${toRemove == 1 ? 'copy' : 'copies'}. Files on disk are not deleted.',
      confirmLabel: 'Remove all',
      destructive: true,
      icon: LucideIcons.sparkles,
    );
    if (!confirmed) return;
    await ref.read(duplicateScanProvider.notifier).removeAllDuplicates();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        content: Row(
          children: [
            const Icon(LucideIcons.check, size: 18, color: Colors.green),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Duplicates removed using recommended picks.',
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Group card — multi-keep selection (check any versions to keep)
// ---------------------------------------------------------------------------

class _DuplicateGroupCard extends ConsumerStatefulWidget {
  const _DuplicateGroupCard({required this.group});

  final DuplicateGroup group;

  @override
  ConsumerState<_DuplicateGroupCard> createState() =>
      _DuplicateGroupCardState();
}

class _DuplicateGroupCardState extends ConsumerState<_DuplicateGroupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(duplicateScanProvider);
    final keepSet = scanState.keepSelection[widget.group.key] ??
        {widget.group.recommendedKeep.id};
    final keptCount = keepSet.length;
    final removeCount = widget.group.songs.length - keptCount;
    final isRemoving = scanState.isRemoving;

    // Sort so kept + recommended appear first for quicker scanning.
    final songs = List.of(widget.group.songs);
    songs.sort((a, b) {
      final aKept = keepSet.contains(a.id);
      final bKept = keepSet.contains(b.id);
      if (aKept && !bKept) return -1;
      if (!aKept && bKept) return 1;
      final aRec = a.id == widget.group.recommendedKeep.id;
      final bRec = b.id == widget.group.recommendedKeep.id;
      if (aRec && !bRec) return -1;
      if (!aRec && bRec) return 1;
      return 0;
    });

    final String keepingBadgeText;
    if (keptCount == 1) {
      final kept = widget.group.songs.firstWhere(
        (s) => keepSet.contains(s.id),
        orElse: () => widget.group.recommendedKeep,
      );
      final type = kept.fileType?.toUpperCase() ?? '—';
      final br = AudioMetadataUtils.formatBitrateLabel(
            kept.bitrate,
            sampleRate: kept.sampleRate,
            bitDepth: kept.bitDepth,
          ) ??
          'Unknown bitrate';
      keepingBadgeText = 'Keeping • $type • $br';
    } else {
      keepingBadgeText =
          'Keeping $keptCount of ${widget.group.songs.length} • $removeCount to remove';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.glassBorderStrong),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              onTap: isRemoving
                  ? null
                  : () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                child: Row(
                  children: [
                    Container(
                      width: context.scaleSize(AppConstants.containerSizeSm),
                      height: context.scaleSize(AppConstants.containerSizeSm),
                      decoration: BoxDecoration(
                        color: AppColors.glassBackgroundStrong,
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusSm,
                        ),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Icon(
                        LucideIcons.copy,
                        color: context.adaptiveTextSecondary,
                        size: context.responsiveIcon(AppConstants.iconSizeMd),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.group.songs.first.title,
                            style: TextStyle(
                              fontFamily: 'ProductSans',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.adaptiveTextPrimary,
                              letterSpacing: -0.15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${widget.group.songs.first.artist} • ${widget.group.songs.length} copies',
                            style: TextStyle(
                              fontFamily: 'ProductSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(
                                    AppConstants.radiusRound,
                                  ),
                                  border: Border.all(
                                    color: Colors.green
                                        .withValues(alpha: 0.28),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      LucideIcons.shieldCheck,
                                      size: 11,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      keepingBadgeText,
                                      style: const TextStyle(
                                        fontFamily: 'ProductSans',
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: AppConstants.animationNormal,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.glassBackgroundStrong,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Icon(
                          LucideIcons.chevronDown,
                          color: context.adaptiveTextSecondary,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
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
                      padding: const EdgeInsets.only(
                        left: AppConstants.spacingMd,
                        right: AppConstants.spacingMd,
                        bottom: AppConstants.spacingMd,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 1,
                            color: AppColors.glassBorder,
                          ),
                          const SizedBox(height: AppConstants.spacingSm),
                          Row(
                            children: [
                              const Text(
                                'Choose which to keep',
                                style: TextStyle(
                                  fontFamily: 'ProductSans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              if (keptCount != 1 ||
                                  !keepSet.contains(
                                      widget.group.recommendedKeep.id))
                                GestureDetector(
                                  onTap: isRemoving
                                      ? null
                                      : () {
                                          AppHaptics.tap();
                                          ref
                                              .read(duplicateScanProvider
                                                  .notifier)
                                              .resetKeepToRecommended(
                                                  widget.group.key);
                                        },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.backgroundLight
                                          .withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(
                                          AppConstants.radiusRound),
                                      border: Border.all(
                                          color: AppColors.glassBorderStrong),
                                    ),
                                    child: const Text(
                                      'Recommended only',
                                      style: TextStyle(
                                        fontFamily: 'ProductSans',
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: isRemoving
                                    ? null
                                    : () {
                                        AppHaptics.tap();
                                        ref
                                            .read(
                                                duplicateScanProvider.notifier)
                                            .setKeepSet(
                                              widget.group.key,
                                              widget.group.songs
                                                  .map((s) => s.id)
                                                  .toSet(),
                                            );
                                      },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundLight
                                        .withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(
                                        AppConstants.radiusRound),
                                    border: Border.all(
                                        color: AppColors.glassBorderStrong),
                                  ),
                                  child: const Text(
                                    'Keep all',
                                    style: TextStyle(
                                      fontFamily: 'ProductSans',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppConstants.spacingXs),
                          Text(
                            'Check the versions you want to keep — unchecked ones will be removed from your library. At least one must stay.',
                            style: TextStyle(
                              fontFamily: 'ProductSans',
                              fontSize: 11.5,
                              height: 1.35,
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.9),
                            ),
                          ),
                          if (keepSet.length > 1) ...[
                            const SizedBox(height: 6),
                            Text(
                              '$keptCount kept • $removeCount will be removed',
                              style: TextStyle(
                                fontFamily: 'ProductSans',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.green.shade300,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppConstants.spacingSm),
                          ...songs.map(
                            (song) {
                              final isKept = keepSet.contains(song.id);
                              final canToggleOff = keepSet.length > 1;
                              return _SongSelectRow(
                                song: song,
                                group: widget.group,
                                selected: isKept,
                                isRecommended:
                                    song.id == widget.group.recommendedKeep.id,
                                enabled: !isRemoving,
                                canToggleOff: canToggleOff,
                                onTap: () {
                                  AppHaptics.selection();
                                  final ok = ref
                                      .read(duplicateScanProvider.notifier)
                                      .toggleKeep(widget.group.key, song.id);
                                  if (!ok && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor:
                                            AppColors.surfaceLight,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              AppConstants.radiusMd),
                                        ),
                                        content: const Row(
                                          children: [
                                            Icon(LucideIcons.info,
                                                size: 16,
                                                color: Colors.amber),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'At least one version must stay.',
                                                style: TextStyle(
                                                  fontFamily: 'ProductSans',
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          ),
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

class _SongSelectRow extends StatelessWidget {
  const _SongSelectRow({
    required this.song,
    required this.group,
    required this.selected,
    required this.isRecommended,
    required this.enabled,
    required this.onTap,
    this.canToggleOff = true,
  });

  final dynamic song;
  final DuplicateGroup group;
  final bool selected;
  final bool isRecommended;
  final bool enabled;
  final bool canToggleOff;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bitrateLabel = AudioMetadataUtils.formatBitrateLabel(
          song.bitrate,
          sampleRate: song.sampleRate,
          bitDepth: song.bitDepth,
        ) ??
        'Unknown bitrate';
    final typeLabel = (song.fileType as String?)?.toUpperCase() ?? 'Unknown';
    final sizeLabel = _formatFileSize(song.fileSize as int?);
    final file = _fileName(song.filePath as String);
    final folder = _folderName(song.filePath as String);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingXs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          child: Ink(
            padding: const EdgeInsets.all(AppConstants.spacingSm),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF1D2E1F).withValues(alpha: 0.98)
                  : AppColors.surfaceLight.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(
                color: selected
                    ? Colors.green.withValues(alpha: 0.45)
                    : AppColors.glassBorderStrong.withValues(alpha: 0.9),
                width: selected ? 1.3 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: selected
                        ? Colors.green
                        : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? Colors.green
                          : AppColors.textSecondary.withValues(alpha: 0.65),
                      width: 1.4,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          LucideIcons.check,
                          size: 13,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: AppConstants.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.green.withValues(alpha: 0.22)
                                  : AppColors.backgroundLight
                                      .withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusXs,
                              ),
                              border: Border.all(
                                color: selected
                                    ? Colors.green.withValues(alpha: 0.38)
                                    : AppColors.glassBorderStrong,
                              ),
                            ),
                            child: Text(
                              typeLabel,
                              style: TextStyle(
                                fontFamily: 'ProductSans',
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: selected
                                    ? Colors.green.shade300
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '$bitrateLabel • $sizeLabel',
                              style: TextStyle(
                                fontFamily: 'ProductSans',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.green.shade300
                                    : AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isRecommended) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusRound,
                                ),
                                border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.32),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    LucideIcons.star,
                                    size: 10,
                                    color: Colors.amber,
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'Recommended',
                                    style: TextStyle(
                                      fontFamily: 'ProductSans',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        selected ? 'Keeping this version' : 'Will be removed',
                        style: TextStyle(
                          fontFamily: 'ProductSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? Colors.green.shade300
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        file,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'ProductSans',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (folder.isNotEmpty)
                        Text(
                          'in $folder',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.95),
                          ),
                        ),
                      if ((song.albumArtPath as String?) != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.image,
                                size: 11,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Has artwork',
                                style: TextStyle(
                                  fontFamily: 'ProductSans',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
