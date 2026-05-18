import 'dart:io';

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

class LibrarySettingsScreen extends ConsumerStatefulWidget {
  const LibrarySettingsScreen({super.key});

  @override
  ConsumerState<LibrarySettingsScreen> createState() =>
      _LibrarySettingsScreenState();
}

class _LibrarySettingsScreenState extends ConsumerState<LibrarySettingsScreen>
    with SingleTickerProviderStateMixin {
  final MusicFolderService _folderService = MusicFolderService();
  final LibraryScannerService _scannerService = LibraryScannerService();
  final SongRepository _songRepository = SongRepository();

  List<MusicFolder> _folders = [];
  int _songCount = 0;
  bool _isScanning = false;
  ScanProgress? _scanProgress;
  bool _showBatteryOptimizationNotice = false;
  bool _isXiaomiDevice = false;
  bool _scanSettingsExpanded = false;

  late final AnimationController _scanSettingsController;
  late final Animation<double> _scanSettingsRotation;

  final ValueNotifier<ScanProgress?> _scanProgressNotifier = ValueNotifier(
    null,
  );

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
    _loadLibraryData();
    _syncFoldersToDatabase();
    _loadAndroidDeviceNotices();
  }

  @override
  void dispose() {
    _scanProgressNotifier.dispose();
    _scanSettingsController.dispose();
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
    if (mounted) {
      setState(() {
        _folders = folders;
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
    _showScanningBottomSheet(displayName);

    await for (final progress in _scannerService.scanFolder(uri, displayName)) {
      if (mounted) {
        setState(() => _scanProgress = progress);
        _scanProgressNotifier.value = progress;
      }
    }

    await _loadLibraryData();
    if (mounted) {
      Navigator.of(context).pop();
      _scanProgressNotifier.value = null;
      setState(() {
        _isScanning = false;
        _scanProgress = null;
      });
      final added = _songCount - previousCount;
      _showToast('Scan completed: $added songs added');
    }
  }

  Future<void> _rescanAllFolders() async {
    final previousCount = _songCount;
    setState(() {
      _isScanning = true;
      _scanProgress = null;
    });
    _showScanningBottomSheet('All Folders');

    await for (final progress in _scannerService.scanAllFolders()) {
      if (mounted) {
        setState(() => _scanProgress = progress);
        _scanProgressNotifier.value = progress;
      }
    }

    await _loadLibraryData();
    if (mounted) {
      Navigator.of(context).pop();
      _scanProgressNotifier.value = null;
      setState(() {
        _isScanning = false;
        _scanProgress = null;
      });
      final added = _songCount - previousCount;
      _showToast('Rescan completed: $added songs added');
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

  void _showScanningBottomSheet(String folderName) {
    GlassBottomSheet.show(
      context: context,
      title: 'Scanning Library',
      isDismissible: false,
      enableDrag: false,
      maxHeightRatio: 0.35,
      content: ValueListenableBuilder<ScanProgress?>(
        valueListenable: _scanProgressNotifier,
        builder: (context, progress, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppConstants.spacingMd),
              Row(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          progress?.currentFolder ?? folderName,
                          style: const TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
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
                        ),
                      ],
                    ),
                  ),
                ],
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
                    Navigator.of(context).pop();
                    _scanProgressNotifier.value = null;
                    setState(() {
                      _isScanning = false;
                      _scanProgress = null;
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
          );
        },
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
                    FutureBuilder<FolderEntity?>(
                      future: FolderRepository().getFolderByUri(folder.uri),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final entity = snapshot.data;
                        final globalDeepScan = ref.watch(libraryScanPreferencesProvider).useDeepScan;
                        final folderDeepScan = entity?.useDeepScan;
                        final effectiveDeepScan = folderDeepScan ?? globalDeepScan;
                        return Row(
                          children: [
                            Text(
                              'Deep scan',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: context.adaptiveTextTertiary,
                              ),
                            ),
                            const SizedBox(width: AppConstants.spacingXs),
                            SizedBox(
                              height: 20,
                              child: Switch(
                                value: effectiveDeepScan,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onChanged: (value) async {
                                  final repo = FolderRepository();
                                  final existing = await repo.getFolderByUri(folder.uri);
                                  if (existing != null) {
                                    existing.useDeepScan = value;
                                    await repo.upsertFolder(existing);
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
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
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

  Widget _buildAutoSyncToggle() {
    return Consumer(
      builder: (context, ref, child) {
        final autoSyncEnabled = ref.watch(autoSyncEnabledProvider);
        final autoSyncService = ref.watch(autoLibrarySyncServiceProvider);
        final autoSyncInterval = ref.watch(autoSyncIntervalProvider);

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
                  LucideIcons.refreshCcw,
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
                      'Auto-Sync Library',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: context.adaptiveTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Check for new songs every $autoSyncInterval minutes',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.adaptiveTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: autoSyncEnabled,
                onChanged: (value) {
                  ref.read(autoSyncEnabledProvider.notifier).set(value);
                  if (value) {
                    autoSyncService.syncInterval = Duration(
                      minutes: autoSyncInterval,
                    );
                    autoSyncService.start();
                  } else {
                    autoSyncService.stop();
                  }
                },
              ),
            ],
          ),
        );
      },
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
                const SettingsDivider(),
                _buildAutoSyncToggle(),
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
