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

class DuplicateCleanerScreen extends ConsumerStatefulWidget {
  const DuplicateCleanerScreen({super.key});

  @override
  ConsumerState<DuplicateCleanerScreen> createState() =>
      _DuplicateCleanerScreenState();
}

class _DuplicateCleanerScreenState
    extends ConsumerState<DuplicateCleanerScreen> {
  @override
  void initState() {
    super.initState();
    // Start scanning on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(duplicateScanProvider.notifier).scanForDuplicates();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(duplicateScanProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            LucideIcons.chevronLeft,
            color: context.adaptiveTextPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Duplicate Cleaner',
          style: TextStyle(
            fontFamily: 'ProductSans',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.adaptiveTextPrimary,
          ),
        ),
        actions: [
          if (scanState.result != null && !scanState.isScanning)
            IconButton(
              icon: Icon(
                LucideIcons.refreshCw,
                color: context.adaptiveTextPrimary,
              ),
              onPressed: () {
                ref.read(duplicateScanProvider.notifier).scanForDuplicates();
              },
            ),
        ],
      ),
      body: _buildBody(context, scanState),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.textPrimary),
          const SizedBox(height: AppConstants.spacingLg),
          Text(
            'Scanning for duplicates...',
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 16,
              color: context.adaptiveTextSecondary,
            ),
          ),
        ],
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
            Icon(
              Icons.error_outline,
              size: 64,
              color: context.adaptiveTextTertiary,
            ),
            const SizedBox(height: AppConstants.spacingLg),
            Text(
              'Error Scanning',
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 20,
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
                fontSize: 14,
                color: context.adaptiveTextSecondary,
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
        'No scan results',
        style: TextStyle(
          fontFamily: 'ProductSans',
          fontSize: 16,
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
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            const SizedBox(height: AppConstants.spacingLg),
            Text(
              'No Duplicates Found',
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.adaptiveTextPrimary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              'Your library is clean!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 14,
                color: context.adaptiveTextSecondary,
              ),
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
        // Summary card
        Container(
          margin: const EdgeInsets.all(AppConstants.spacingMd),
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(color: AppColors.glassBorder, width: 1),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat(
                    context,
                    'Duplicate Groups',
                    result.totalGroups.toString(),
                    LucideIcons.copy,
                  ),
                  _buildStat(
                    context,
                    'Songs to Remove',
                    result.totalDuplicates.toString(),
                    LucideIcons.trash2,
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingLg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: scanState.isRemoving
                      ? null
                      : () => _showRemoveAllConfirmation(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppConstants.spacingMd,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusMd,
                      ),
                    ),
                  ),
                  child: scanState.isRemoving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Remove All Duplicates',
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),

        // Duplicate groups list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMd,
            ),
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

  Widget _buildStat(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, size: 32, color: context.adaptiveTextSecondary),
        const SizedBox(height: AppConstants.spacingSm),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'ProductSans',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: context.adaptiveTextPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'ProductSans',
            fontSize: 12,
            color: context.adaptiveTextTertiary,
          ),
        ),
      ],
    );
  }

  Future<void> _showRemoveAllConfirmation(BuildContext context) async {
    final result = ref.read(duplicateScanProvider).result!;

    final confirmed = await FlickDialogs.confirm(
      context,
      title: 'Remove All Duplicates?',
      message:
          'This will remove ${result.totalDuplicates} duplicate songs, keeping the best quality version of each. This action cannot be undone.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (confirmed) {
      ref.read(duplicateScanProvider.notifier).removeAllDuplicates();
    }
  }
}

class _DuplicateGroupCard extends StatefulWidget {
  const _DuplicateGroupCard({required this.group});

  final dynamic group;

  @override
  State<_DuplicateGroupCard> createState() => _DuplicateGroupCardState();
}

class _DuplicateGroupCardState extends State<_DuplicateGroupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final songToKeep = widget.group.songToKeep;
    final songsToRemove = widget.group.songsToRemove;

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              onTap: () => setState(() => _expanded = !_expanded),
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
                            songToKeep.title,
                            style: TextStyle(
                              fontFamily: 'ProductSans',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.adaptiveTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${songToKeep.artist} • ${songsToRemove.length + 1} copies',
                            style: TextStyle(
                              fontFamily: 'ProductSans',
                              fontSize: 13,
                              color: context.adaptiveTextTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: AppConstants.animationNormal,
                      child: Icon(
                        LucideIcons.chevronDown,
                        color: context.adaptiveTextSecondary,
                        size: 20,
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
                        children: [
                          _buildSongItem(context, songToKeep, isKeeping: true),
                          const SizedBox(height: AppConstants.spacingSm),
                          ...songsToRemove.map(
                            (song) => _buildSongItem(context, song),
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

  Widget _buildSongItem(
    BuildContext context,
    dynamic song, {
    bool isKeeping = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      decoration: BoxDecoration(
        color: isKeeping
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        border: Border.all(
          color: isKeeping
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isKeeping ? LucideIcons.check : LucideIcons.x,
            size: 16,
            color: isKeeping ? Colors.green : Colors.red,
          ),
          const SizedBox(width: AppConstants.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isKeeping ? 'Keep' : 'Remove',
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isKeeping ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${song.fileType ?? 'Unknown'} • ${AudioMetadataUtils.formatBitrateLabel(song.bitrate, sampleRate: song.sampleRate, bitDepth: song.bitDepth) ?? 'Unknown bitrate'}',
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 11,
                    color: context.adaptiveTextTertiary,
                  ),
                ),
                if (song.albumArtPath != null)
                  Text(
                    'Has album art',
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: 11,
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
}
