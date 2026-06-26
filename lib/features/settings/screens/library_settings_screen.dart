import 'dart:io';
import 'dart:math' show pi;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/data/entities/folder_entity.dart';
import 'package:flick/data/repositories/folder_repository.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/features/settings/screens/duplicate_cleaner_screen.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/services/android_audio_device_service.dart';
import 'package:flick/services/library_scan_preferences_service.dart';
import 'package:flick/services/library_scanner_service.dart';
import 'package:flick/services/music_folder_service.dart';
import 'package:flick/services/permission_service.dart';
import 'package:flick/widgets/common/glass_bottom_sheet.dart';
import 'package:flick/widgets/common/glass_dialog.dart';
import 'package:flick/widgets/common/vinyl_record.dart';

class LibrarySettingsScreen extends ConsumerStatefulWidget {
  const LibrarySettingsScreen({super.key});

  @override
  ConsumerState<LibrarySettingsScreen> createState() =>
      _LibrarySettingsScreenState();
}

class _LibrarySettingsScreenState extends ConsumerState<LibrarySettingsScreen>
    with TickerProviderStateMixin {
  final MusicFolderService _folderService = MusicFolderService();
  final LibraryScannerService _scannerService = LibraryScannerService();
  final SongRepository _songRepository = SongRepository();

  List<MusicFolder> _folders = [];
  final Map<String, FolderEntity> _folderEntities = {};
  int _songCount = 0;
  bool _isScanning = false;
  ScanProgress? _scanProgress;
  bool _showBatteryOptimizationNotice = false;
  bool _isXiaomiDevice = false;
  bool _scanSettingsExpanded = false;

  late final AnimationController _scanSettingsController;
  late final Animation<double> _scanSettingsRotation;
  late final AnimationController _vinylController;

  final ValueNotifier<ScanProgress?> _scanProgressNotifier = ValueNotifier(
    null,
  );
  final Stopwatch _scanStopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _scanSettingsController = AnimationController(
      duration: AppConstants.animationFast,
      vsync: this,
    );
    _scanSettingsRotation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _scanSettingsController, curve: Curves.easeInOut),
    );
    _vinylController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _loadLibraryData();
    _syncFoldersToDatabase();
    _loadAndroidDeviceNotices();
  }

  @override
  void dispose() {
    _scanProgressNotifier.dispose();
    _scanSettingsController.dispose();
    _vinylController.dispose();
    _scanStopwatch.stop();
    super.dispose();
  }

  Future<void> _syncFoldersToDatabase() async {
    final folders = await _folderService.getSavedFolders();
    final repository = FolderRepository();

    for (final folder in folders) {
      final existing = await repository.getFolderByUri(folder.uri);
      final entity = FolderEntity()
        ..uri = folder.uri
        ..displayName = folder.displayName
        ..dateAdded = folder.dateAdded
        ..songCount = existing?.songCount ?? 0
        ..useDeepScan = existing?.useDeepScan;
      await repository.upsertFolder(entity);
    }
  }

  Future<void> _loadLibraryData() async {
    final folders = await _folderService.getSavedFolders();
    final count = await _songRepository.getSongCount();
    final repo = FolderRepository();
    final entities = <String, FolderEntity>{};
    for (final folder in folders) {
      final entity = await repo.getFolderByUri(folder.uri);
      if (entity != null) entities[folder.uri] = entity;
    }
    if (mounted) {
      setState(() {
        _folders = folders;
        _folderEntities.clear();
        _folderEntities.addAll(entities);
        _songCount = count;
      });
    }
  }

  Future<void> _loadAndroidDeviceNotices() async {
    final permissionService = PermissionService();
    try {
      final isAndroid = Theme.of(context).platform == TargetPlatform.android;
      if (!isAndroid) return;

      final results = await Future.wait<dynamic>([
        AndroidAudioDeviceService.instance.refresh(),
        permissionService.isIgnoringBatteryOptimizations(),
        permissionService.isBatteryNoticeDismissed(),
      ]);
      final deviceInfo = results[0] as AndroidPlaybackDeviceInfo;
      final isIgnoringBatteryOptimizations = results[1] as bool;
      final isNoticeDismissed = results[2] as bool;

      if (!mounted) return;
      setState(() {
        _isXiaomiDevice = deviceInfo.isXiaomiDevice;
        _showBatteryOptimizationNotice =
            !isIgnoringBatteryOptimizations && !isNoticeDismissed;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _showBatteryOptimizationNotice = false);
    }
  }

  Future<void> _requestBatteryOptimizationDisable() async {
    final permissionService = PermissionService();
    try {
      final launched = await permissionService
          .requestIgnoreBatteryOptimizations();
      if (!mounted) return;
      if (!launched) {
        _showToast('Unable to open battery optimization settings');
      }
    } catch (e) {
      if (!mounted) return;
      _showToast('Failed to open battery optimization settings: $e');
    }
  }

  Future<void> _dismissBatteryNotice() async {
    final permissionService = PermissionService();
    await permissionService.dismissBatteryNotice();
    if (!mounted) return;
    setState(() => _showBatteryOptimizationNotice = false);
  }

  void _showToast(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _addFolder() async {
    try {
      final permissionService = PermissionService();
      final hasPermission = await permissionService.hasStoragePermission();

      if (!hasPermission && _folders.isEmpty) {
        final granted = await permissionService.requestStoragePermission();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Storage permission is required to add music folders',
                ),
              ),
            );
          }
          return;
        }
      }

      final folder = await _folderService.addFolder();
      if (folder != null) {
        await _loadLibraryData();
        await _scanFolder(folder.uri, folder.displayName);
      }
    } on FolderAlreadyExistsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), duration: const Duration(seconds: 3)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add folder: $e')));
      }
    }
  }

  Future<void> _removeFolder(MusicFolder folder) async {
    try {
      await _folderService.removeFolder(folder.uri);
      await _loadLibraryData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to remove folder: $e')));
      }
    }
  }

  Future<void> _scanFolder(String uri, String displayName) async {
    final previousCount = _songCount;
    setState(() {
      _isScanning = true;
      _scanProgress = null;
    });
    _scanStopwatch.reset();
    _scanStopwatch.start();
    _vinylController.repeat();
    _showScanningOverlay(displayName);

    await for (final progress in _scannerService.scanFolder(uri, displayName)) {
      if (mounted) {
        setState(() => _scanProgress = progress);
        _scanProgressNotifier.value = progress;
      }
    }

    _scanStopwatch.stop();
    _vinylController.stop();
    await _loadLibraryData();
    if (mounted) {
      Navigator.of(context).pop();
      _scanProgressNotifier.value = null;
      setState(() {
        _isScanning = false;
        _scanProgress = null;
      });
      final added = _songCount - previousCount;
      _showScanCompleteBottomSheet(
        scanDuration: _scanStopwatch.elapsed,
        songsScanned: added,
      );
    }
  }

  Future<void> _rescanAllFolders() async {
    final previousCount = _songCount;
    setState(() {
      _isScanning = true;
      _scanProgress = null;
    });
    _scanStopwatch.reset();
    _scanStopwatch.start();
    _vinylController.repeat();
    _showScanningOverlay('All Folders');

    await for (final progress in _scannerService.scanAllFolders()) {
      if (mounted) {
        setState(() => _scanProgress = progress);
        _scanProgressNotifier.value = progress;
      }
    }

    _scanStopwatch.stop();
    _vinylController.stop();
    await _loadLibraryData();
    if (mounted) {
      Navigator.of(context).pop();
      _scanProgressNotifier.value = null;
      setState(() {
        _isScanning = false;
        _scanProgress = null;
      });
      final added = _songCount - previousCount;
      _showScanCompleteBottomSheet(
        scanDuration: _scanStopwatch.elapsed,
        songsScanned: added,
      );
    }
  }

  void _openDuplicateCleaner() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const DuplicateCleanerScreen()),
    );
  }

  void _confirmRemoveFolder(MusicFolder folder) {
    showDialog(
      context: context,
      builder: (context) => GlassDialog(
        title: 'Remove Folder?',
        content: Text('Remove "${folder.displayName}" from your library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _removeFolder(folder);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showScanningOverlay(String folderName) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, animation, secondaryAnimation) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Blurred background
              BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: AppConstants.glassBlurSigma,
                  sigmaY: AppConstants.glassBlurSigma,
                ),
                child: const SizedBox.expand(),
              ),
              // Spinning vinyl centered
              Center(
                child: AnimatedBuilder(
                  animation: _vinylController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _vinylController.value * 2 * pi,
                      child: child,
                    );
                  },
                  child: const VinylRecord(size: 180),
                ),
              ),
              // Bottom sheet panel
              Align(
                alignment: Alignment.bottomCenter,
                child: ValueListenableBuilder<ScanProgress?>(
                  valueListenable: _scanProgressNotifier,
                  builder: (context, progress, _) {
                    return Container(
                      margin: const EdgeInsets.all(AppConstants.spacingLg),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.surfaceLight.withValues(alpha: 0.98),
                            AppColors.surface.withValues(alpha: 0.98),
                          ],
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppConstants.radiusXl),
                          bottom: Radius.circular(AppConstants.radiusXl),
                        ),
                        border: Border.all(color: AppColors.glassBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 20,
                            offset: const Offset(0, -6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(
                        AppConstants.spacingLg,
                        AppConstants.spacingSm,
                        AppConstants.spacingLg,
                        AppConstants.spacingLg,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Drag handle
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.textTertiary,
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusRound,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppConstants.spacingMd),
                          Text(
                            progress?.currentFolder ?? folderName,
                            style: const TextStyle(
                              fontFamily: 'ProductSans',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            progress?.currentFile ?? 'Initializing...',
                            style: const TextStyle(
                              fontFamily: 'ProductSans',
                              fontSize: 13,
                              color: AppColors.textTertiary,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppConstants.spacingLg),
                          Container(
                            padding: const EdgeInsets.all(AppConstants.spacingMd),
                            decoration: BoxDecoration(
                              color: AppColors.glassBackground,
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusMd,
                              ),
                              border: Border.all(color: AppColors.glassBorder),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildScanStat(
                                  'Songs Found',
                                  '${progress?.songsFound ?? 0}',
                                  LucideIcons.music,
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: AppColors.glassBorder,
                                ),
                                _buildScanStat(
                                  'Total Files',
                                  '${progress?.totalFiles ?? 0}',
                                  LucideIcons.file,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppConstants.spacingMd),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () {
                                _scannerService.cancelScan();
                                _vinylController.stop();
                                _scanStopwatch.stop();
                                Navigator.of(context).pop();
                                _scanProgressNotifier.value = null;
                                setState(() {
                                  _isScanning = false;
                                  _scanProgress = null;
                                });
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontFamily: 'ProductSans',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showScanCompleteBottomSheet({
    required Duration scanDuration,
    required int songsScanned,
  }) {
    final seconds = scanDuration.inSeconds;
    final milliseconds = scanDuration.inMilliseconds.remainder(1000);
    final timeText = seconds > 0
        ? '$seconds.${(milliseconds / 100).floor()}s'
        : '${milliseconds}ms';

    GlassBottomSheet.show(
      context: context,
      title: 'Scan Complete',
      isDismissible: true,
      enableDrag: true,
      maxHeightRatio: 0.35,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: AppConstants.spacingMd),
          Icon(
            LucideIcons.circleCheck,
            color: AppColors.accent,
            size: 48,
          ),
          const SizedBox(height: AppConstants.spacingLg),
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            decoration: BoxDecoration(
              color: AppColors.glassBackground,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildScanStat(
                  'Songs Scanned',
                  '$songsScanned',
                  LucideIcons.music,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: AppColors.glassBorder,
                ),
                _buildScanStat(
                  'Time Taken',
                  timeText,
                  LucideIcons.timer,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'ProductSans',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'ProductSans',
            fontSize: 12,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildLibraryInfo() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Row(
        children: [
          Container(
            width: context.scaleSize(AppConstants.containerSizeSm),
            height: context.scaleSize(AppConstants.containerSizeSm),
            decoration: BoxDecoration(
              color: AppColors.glassBackgroundStrong,
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: Icon(
              LucideIcons.music,
              color: AppColors.textSecondary,
              size: context.responsiveIcon(AppConstants.iconSizeMd),
            ),
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Library',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.adaptiveTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_songCount songs in ${_folders.length} ${_folders.length == 1 ? 'folder' : 'folders'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.adaptiveTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (_folders.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(
                LucideIcons.chevronDown,
                color: context.adaptiveTextSecondary,
                size: 20,
              ),
              tooltip: 'View scanned folders',
              itemBuilder:
                  (context) => _folders
                      .map(
                        (folder) => PopupMenuItem<String>(
                          value: folder.uri,
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.folder,
                                size: 18,
                                color: context.adaptiveTextSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(folder.displayName),
                            ],
                          ),
                        ),
                      )
                      .toList(),
              onSelected: (_) {},
            ),
        ],
      ),
    );
  }

  Widget _buildScanningIndicator() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.adaptiveTextPrimary,
            ),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          Text(
            'Scanning... ${_scanProgress?.songsFound ?? 0} songs found',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.adaptiveTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderItem(MusicFolder folder) {
    final globalDeepScan = ref.watch(libraryScanPreferencesProvider).useDeepScan;
    final entity = _folderEntities[folder.uri];
    final effectiveDeepScan = entity?.useDeepScan ?? globalDeepScan;

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: AppConstants.spacingSm,
        ),
        child: Row(
          children: [
            Container(
              width: context.scaleSize(AppConstants.containerSizeSm),
              height: context.scaleSize(AppConstants.containerSizeSm),
              decoration: BoxDecoration(
                color: AppColors.glassBackgroundStrong,
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              ),
              child: Icon(
                LucideIcons.folder,
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
                    folder.displayName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.adaptiveTextPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (Platform.isAndroid)
                    Text(
                      [
                        effectiveDeepScan ? 'Deep scan on' : 'Deep scan off',
                        if (folder.isRemovable == true)
                          (folder.volumeState != null &&
                                  folder.volumeState != 'mounted')
                              ? 'USB not connected'
                              : 'External',
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.adaptiveTextTertiary,
                      ),
                    ),
                ],
              ),
            ),
            if (Platform.isAndroid)
              CustomSwitch(
                value: effectiveDeepScan,
                onChanged: (value) async {
                  final repo = FolderRepository();
                  if (entity != null) {
                    entity.useDeepScan = value;
                    await repo.upsertFolder(entity);
                  } else {
                    final newEntity = FolderEntity()
                      ..uri = folder.uri
                      ..displayName = folder.displayName
                      ..dateAdded = folder.dateAdded
                      ..songCount = 0
                      ..useDeepScan = value;
                    await repo.upsertFolder(newEntity);
                  }
                  setState(() {});
                },
              ),
            IconButton(
              icon: Icon(
                LucideIcons.trash2,
                color: context.adaptiveTextTertiary,
                size: context.responsiveIcon(AppConstants.iconSizeSm),
              ),
              onPressed: () => _confirmRemoveFolder(folder),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableScanSettings(LibraryScanPreferences prefs) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() => _scanSettingsExpanded = !_scanSettingsExpanded);
              if (_scanSettingsExpanded) {
                _scanSettingsController.forward();
              } else {
                _scanSettingsController.reverse();
              }
            },
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
                      LucideIcons.settings2,
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
                          'Scanning Settings',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: context.adaptiveTextPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Filter files, size limits, and playlist import options',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.adaptiveTextTertiary),
                        ),
                      ],
                    ),
                  ),
                  RotationTransition(
                    turns: _scanSettingsRotation,
                    child: Icon(
                      LucideIcons.chevronDown,
                      color: context.adaptiveTextTertiary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizeTransition(
          sizeFactor: _scanSettingsController,
          child: Column(
            children: [
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.scanSearch,
                title: 'Filter Non-Music Files & Folders',
                subtitle:
                    'Skip unsupported files and hidden .nomedia directories',
                value: prefs.filterNonMusicFilesAndFolders,
                onChanged: (value) {
                  ref
                      .read(libraryScanPreferencesProvider.notifier)
                      .setFilterNonMusicFilesAndFolders(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.fileMinus,
                title: 'Ignore Tracks Under 500 KB',
                subtitle: 'Exclude tiny clips, previews, and accidental scraps',
                value: prefs.ignoreTracksSmallerThan500Kb,
                onChanged: (value) {
                  ref
                      .read(libraryScanPreferencesProvider.notifier)
                      .setIgnoreTracksSmallerThan500Kb(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.timerOff,
                title: 'Ignore Tracks Under 60 Seconds',
                subtitle: 'Hide short stingers, ringtones, and voice fragments',
                value: prefs.ignoreTracksShorterThan60Seconds,
                onChanged: (value) {
                  ref
                      .read(libraryScanPreferencesProvider.notifier)
                      .setIgnoreTracksShorterThan60Seconds(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.listMusic,
                title: 'Import M3U/M3U8 Playlists',
                subtitle:
                    'Create or refresh playlists found inside scanned folders',
                value: prefs.createPlaylistsFromM3uFiles,
                onChanged: (value) {
                  ref
                      .read(libraryScanPreferencesProvider.notifier)
                      .setCreatePlaylistsFromM3uFiles(value);
                },
              ),
              if (Platform.isAndroid) ...[
                const SettingsDivider(),
                ToggleSetting(
                  icon: LucideIcons.hardDrive,
                  title: 'Deep Scan',
                  subtitle:
                      'Use filesystem-level scanning instead of MediaStore for full tag accuracy',
                  value: prefs.useDeepScan,
                  onChanged: (value) {
                    ref
                        .read(libraryScanPreferencesProvider.notifier)
                        .setUseDeepScan(value);
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryScanPreferences = ref.watch(libraryScanPreferencesProvider);

    return SettingsScaffold(
      title: 'Library',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsSectionHeader('Library'),
          SettingsCard(
            children: [
              _buildLibraryInfo(),
              if (_showBatteryOptimizationNotice) ...[
                const SettingsDivider(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _requestBatteryOptimizationDisable,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(AppConstants.radiusLg),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppConstants.spacingMd),
                      child: Row(
                        children: [
                          Container(
                            width: context.scaleSize(
                              AppConstants.containerSizeSm,
                            ),
                            height: context.scaleSize(
                              AppConstants.containerSizeSm,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.glassBackgroundStrong,
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusSm,
                              ),
                            ),
                            child: Icon(
                              LucideIcons.batteryWarning,
                              color: context.adaptiveTextSecondary,
                              size: context.responsiveIcon(
                                AppConstants.iconSizeMd,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppConstants.spacingMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isXiaomiDevice
                                      ? 'Disable Battery Optimization (Recommended)'
                                      : 'Disable Battery Optimization',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: context.adaptiveTextPrimary,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isXiaomiDevice
                                      ? 'Required on many Xiaomi, Redmi, and POCO devices so rescans and background features keep working'
                                      : 'Allow Flick to run without aggressive background limits so rescans and background features keep working',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: context.adaptiveTextTertiary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppConstants.spacingSm),
                          IconButton(
                            icon: Icon(
                              LucideIcons.x,
                              size: context.responsiveIcon(
                                AppConstants.iconSizeSm,
                              ),
                              color: context.adaptiveTextTertiary,
                            ),
                            tooltip: 'Dismiss',
                            onPressed: _dismissBatteryNotice,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SettingsDivider(),
              if (_isScanning) ...[
                _buildScanningIndicator(),
                const SettingsDivider(),
              ],
              ..._folders.map(
                (folder) => Column(
                  children: [
                    _buildFolderItem(folder),
                    if (_folders.last != folder) const SettingsDivider(),
                  ],
                ),
              ),
              if (_folders.isNotEmpty) const SettingsDivider(),
              ActionButton(
                icon: LucideIcons.folderPlus,
                title: 'Add Music Folder',
                subtitle: 'Select a folder to scan',
                onTap: _isScanning ? null : _addFolder,
              ),
              if (_folders.isNotEmpty) ...[
                const SettingsDivider(),
                ActionButton(
                  icon: LucideIcons.refreshCw,
                  title: 'Rescan Library',
                  subtitle: 'Re-index all folders',
                  onTap: _isScanning ? null : _rescanAllFolders,
                ),
                const SettingsDivider(),
                ActionButton(
                  icon: LucideIcons.copy,
                  title: 'Remove Duplicates',
                  subtitle: 'Find and remove duplicate songs',
                  onTap: _isScanning ? null : _openDuplicateCleaner,
                ),
              ],
              const SettingsDivider(),
              _buildExpandableScanSettings(libraryScanPreferences),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SizedBox(height: AppConstants.navBarHeight + 40),
        ],
      ),
    );
  }
}
