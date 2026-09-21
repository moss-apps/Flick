import 'dart:async';
import 'dart:io';
import 'dart:math' show pi;
import 'dart:ui';

import 'package:flick/widgets/common/flick_dialog.dart';
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
import 'package:flick/services/album_art_service.dart';
import 'package:flick/services/alac_converter_service.dart';
import 'package:flick/services/android_audio_device_service.dart';
import 'package:flick/services/artwork_backfill_tracker.dart';
import 'package:flick/services/audio_preload_service.dart';
import 'package:flick/services/playback_cache_preferences_service.dart';
import 'package:flick/services/replaygain_scan_service.dart';
import 'package:flick/services/scan_session_controller.dart';
import 'package:flick/services/library_scan_preferences_service.dart';
import 'package:flick/services/library_scanner_service.dart';
import 'package:flick/services/music_folder_service.dart';
import 'package:flick/services/permission_service.dart';
import 'package:flick/widgets/common/glass_bottom_sheet.dart';
import 'package:flick/widgets/common/vinyl_record.dart';

class LibrarySettingsScreen extends ConsumerStatefulWidget {
  const LibrarySettingsScreen({super.key});

  @override
  ConsumerState<LibrarySettingsScreen> createState() =>
      _LibrarySettingsScreenState();
}

class _LibrarySettingsScreenState extends ConsumerState<LibrarySettingsScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final MusicFolderService _folderService = MusicFolderService();
  final LibraryScannerService _scannerService = LibraryScannerService();
  final SongRepository _songRepository = SongRepository();

  List<MusicFolder> _folders = [];
  final Map<String, FolderEntity> _folderEntities = {};
  int _songCount = 0;
  bool _isScanning = false;
  ScanProgress? _scanProgress;
  bool _showBatteryOptimizationNotice = false;
  bool _showAllFilesAccessNotice = false;
  bool _allFilesAccessGranted = false;
  bool _isXiaomiDevice = false;
  bool _scanSettingsExpanded = false;
  bool _libraryExpanded = false;
  int _artworkCacheBytes = -1;
  bool _isClearingCache = false;
  int _wavCacheBytes = -1;
  bool _isClearingWavCache = false;
  int _cacheCapBytes = kPlaybackCacheDefaultMaxBytes;

  late final AnimationController _vinylController;

  final ValueNotifier<ScanProgress?> _scanProgressNotifier = ValueNotifier(
    null,
  );
  final Stopwatch _scanStopwatch = Stopwatch();
  Timer? _elapsedTimer;
  final ValueNotifier<Duration> _elapsedNotifier = ValueNotifier(Duration.zero);
  bool _scanOverlayOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _vinylController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _loadLibraryData();
    _syncFoldersToDatabase();
    _loadAndroidDeviceNotices();
    _refreshCacheSize();
    _refreshWavCacheSize();
    _loadCacheCap();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // All Files Access is granted from the system settings screen; refresh
      // status when the user comes back.
      _loadAndroidDeviceNotices();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _elapsedTimer?.cancel();
    _elapsedNotifier.dispose();
    _scanProgressNotifier.dispose();
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
        permissionService.hasAllFilesAccess(),
        permissionService.isAllFilesNoticeDismissed(),
      ]);
      final deviceInfo = results[0] as AndroidPlaybackDeviceInfo;
      final isIgnoringBatteryOptimizations = results[1] as bool;
      final isNoticeDismissed = results[2] as bool;
      final allFilesAccess = results[3] as bool;
      final isAllFilesNoticeDismissed = results[4] as bool;

      if (!mounted) return;
      setState(() {
        _isXiaomiDevice = deviceInfo.isXiaomiDevice;
        _showBatteryOptimizationNotice =
            !isIgnoringBatteryOptimizations && !isNoticeDismissed;
        _allFilesAccessGranted = allFilesAccess;
        _showAllFilesAccessNotice =
            !allFilesAccess && !isAllFilesNoticeDismissed;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _showBatteryOptimizationNotice = false;
        _showAllFilesAccessNotice = false;
      });
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

  Future<void> _openAllFilesAccessSettings() async {
    final permissionService = PermissionService();
    try {
      final launched = await permissionService.openAllFilesAccessSettings();
      if (!mounted) return;
      if (!launched) {
        _showToast('Unable to open All Files Access settings');
      }
    } catch (e) {
      if (!mounted) return;
      _showToast('Failed to open All Files Access settings: $e');
    }
  }

  Future<void> _dismissAllFilesNotice() async {
    final permissionService = PermissionService();
    await permissionService.dismissAllFilesNotice();
    if (!mounted) return;
    setState(() => _showAllFilesAccessNotice = false);
  }

  void _showToast(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _refreshCacheSize() async {
    final bytes = await AlbumArtService.instance.getCacheSize();
    if (mounted) setState(() => _artworkCacheBytes = bytes);
  }

  String get _cacheSizeLabel {
    if (_isClearingCache) return 'Clearing...';
    if (_artworkCacheBytes < 0) return 'Calculating size...';
    return 'Using ${_formatBytes(_artworkCacheBytes)}';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(size >= 100 || unit == 0 ? 0 : 1)} ${units[unit]}';
  }

  void _confirmClearArtworkCache() {
    unawaited(
      FlickDialogs.confirm(
        context,
        title: 'Clear Artwork Cache?',
        message:
            'Cached album art (${_formatBytes(_artworkCacheBytes)}) will be removed. '
            'Artwork reloads automatically as you browse.',
        confirmLabel: 'Clear',
      ).then((confirmed) {
        if (confirmed) _clearArtworkCache();
      }),
    );
  }

  Future<void> _clearArtworkCache() async {
    setState(() => _isClearingCache = true);
    try {
      await AlbumArtService.instance.clearCache();
      await _refreshCacheSize();
      if (mounted) _showToast('Artwork cache cleared');
    } catch (e) {
      if (mounted) _showToast('Failed to clear cache: $e');
    } finally {
      if (mounted) setState(() => _isClearingCache = false);
    }
  }

  Future<void> _refreshWavCacheSize() async {
    final bytes = await AlacConverterService.getCacheSize();
    if (mounted) setState(() => _wavCacheBytes = bytes);
  }

  Future<void> _loadCacheCap() async {
    final cap = await PlaybackCachePreferencesService().getMaxCacheBytes();
    if (mounted) setState(() => _cacheCapBytes = cap);
  }

  String get _wavCacheSizeLabel {
    if (_isClearingWavCache) return 'Clearing...';
    if (_wavCacheBytes < 0) return 'Calculating size...';
    return 'Using ${_formatBytes(_wavCacheBytes)}';
  }

  String get _cacheCapLabel {
    for (final (label, bytes) in kPlaybackCacheCapPresets) {
      if (bytes == _cacheCapBytes) return label;
    }
    return _formatBytes(_cacheCapBytes);
  }

  Future<void> _setCacheCap(int bytes) async {
    await PlaybackCachePreferencesService().setMaxCacheBytes(bytes);
    if (!mounted) return;
    setState(() => _cacheCapBytes = bytes);
    // Shrinking the cap evicts immediately; staging prunes on next stage.
    await AlacConverterService.enforceCacheCap(bytes);
    await _refreshWavCacheSize();
    if (mounted) {
      _showToast(
        bytes == kPlaybackCacheUnlimited
            ? 'Playback cache unlimited'
            : 'Playback cache limit: ${_formatBytes(bytes)}',
      );
    }
  }

  void _showCacheCapSheet() {
    GlassBottomSheet.show(
      context: context,
      title: 'Playback Cache Limit',
      isDismissible: true,
      enableDrag: true,
      maxHeightRatio: 0.5,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppConstants.spacingSm),
          for (final (label, bytes) in kPlaybackCacheCapPresets)
            _buildCapOption(label, bytes),
          const SizedBox(height: AppConstants.spacingLg),
        ],
      ),
    );
  }

  Widget _buildCapOption(String label, int bytes) {
    final selected = _cacheCapBytes == bytes;
    return InkWell(
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      onTap: () {
        Navigator.of(context).pop();
        unawaited(_setCacheCap(bytes));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: AppConstants.spacingMd,
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.hardDrive,
              size: context.responsiveIcon(AppConstants.iconSizeSm),
              color: selected ? AppColors.accent : context.adaptiveTextTertiary,
            ),
            const SizedBox(width: AppConstants.spacingMd),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? AppColors.accent
                      : context.adaptiveTextPrimary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected)
              Icon(
                LucideIcons.check,
                size: context.responsiveIcon(AppConstants.iconSizeSm),
                color: AppColors.accent,
              ),
          ],
        ),
      ),
    );
  }

  void _confirmClearWavCache() {
    unawaited(
      FlickDialogs.confirm(
        context,
        title: 'Clear Converted Audio Cache?',
        message:
            'Cached WAV conversions (${_formatBytes(_wavCacheBytes < 0 ? 0 : _wavCacheBytes)}) '
            'will be removed. Files convert again on next playback.',
        confirmLabel: 'Clear',
      ).then((confirmed) {
        if (confirmed) _clearWavCache();
      }),
    );
  }

  Future<void> _clearWavCache() async {
    setState(() => _isClearingWavCache = true);
    try {
      await AlacConverterService.clearCache();
      await _refreshWavCacheSize();
      if (mounted) _showToast('Converted audio cache cleared');
    } catch (e) {
      if (mounted) _showToast('Failed to clear cache: $e');
    } finally {
      if (mounted) setState(() => _isClearingWavCache = false);
    }
  }

  void _confirmRemoveAllSongs() {
    unawaited(
      FlickDialogs.confirm(
        context,
        title: 'Remove All Songs?',
        message:
            'Every song is removed from your library. Files on disk are kept; '
            'rescan your folders to add them again.',
        confirmLabel: 'Remove',
        destructive: true,
      ).then((confirmed) {
        if (confirmed) _removeAllSongs();
      }),
    );
  }

  Future<void> _removeAllSongs() async {
    try {
      await SongRepository().deleteAllSongs();
      if (mounted) _showToast('Library emptied');
    } catch (e) {
      if (mounted) _showToast('Failed to remove songs: $e');
    }
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
          SnackBar(
            content: Text(e.message),
            duration: const Duration(seconds: 3),
          ),
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

  Future<void> _runScanSession({
    required String title,
    required ScanSessionKind kind,
    required VoidCallback onCancel,
    required Stream<ScanProgress> Function() run,
    bool includeProgressInSummary = true,
    Future<void> Function()? artworkBackfill,
  }) async {
    setState(() {
      _isScanning = true;
      _scanProgress = null;
    });
    _scanStopwatch.reset();
    _scanStopwatch.start();
    _vinylController.repeat();
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _elapsedNotifier.value = _scanStopwatch.elapsed,
    );
    final generation = ScanSessionController.instance.begin(
      title: title,
      kind: kind,
      onCancel: onCancel,
    );
    _showScanningOverlay(title, generation);

    // The stream's `isComplete` event is the real finish line: stop consuming
    // as soon as it arrives so post-scan bookkeeping can finish in the
    // background instead of holding the overlay open.
    var completed = false;
    ScanProgress? lastProgress;
    try {
      await for (final progress in run()) {
        if (!ScanSessionController.instance.isCurrent(generation)) break;
        lastProgress = progress;
        ScanSessionController.instance.update(generation, progress);
        if (mounted) {
          setState(() => _scanProgress = progress);
          _scanProgressNotifier.value = progress;
        }
        if (progress.isComplete) {
          completed = true;
          break;
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Scan session "$title" failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan failed. Please try again.')),
        );
      }
    }

    // A Stop action ends the session before the stream drains; the completion
    // sheet would misreport cancelled work as finished.
    final wasCancelled = !ScanSessionController.instance.isCurrent(generation);

    // Metadata is scanned; covers may still be resolving in the background.
    // Hold the session open and show progress so the library is actually
    // ready when it reports done. Skip lets the work continue detached.
    if (completed &&
        !wasCancelled &&
        artworkBackfill != null &&
        lastProgress?.unavailable != true) {
      await _awaitArtworkBackfill(
        generation: generation,
        backfill: artworkBackfill,
        lastProgress: lastProgress,
      );
    }

    _scanStopwatch.stop();
    _vinylController.stop();
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    ScanSessionController.instance.end(generation);
    await _loadLibraryData();
    if (mounted) {
      if (_scanOverlayOpen) Navigator.of(context).pop();
      _scanProgressNotifier.value = null;
      final finalProgress = lastProgress ?? _scanProgress;
      setState(() {
        _isScanning = false;
        _scanProgress = null;
      });
      if (!wasCancelled && completed && finalProgress?.unavailable != true) {
        _showScanCompleteBottomSheet(
          scanDuration: _scanStopwatch.elapsed,
          progress: includeProgressInSummary ? finalProgress : null,
          totalSongs: _songCount,
        );
      }
    }
  }

  /// Keeps the scan session alive while post-scan artwork backfill runs,
  /// mirroring its progress as a synthetic `Loading artwork` phase. The user
  /// can request a skip (dashboard button or floating pill), after which the
  /// backfill keeps running detached.
  Future<void> _awaitArtworkBackfill({
    required int generation,
    required Future<void> Function() backfill,
    required ScanProgress? lastProgress,
  }) async {
    final controller = ScanSessionController.instance;
    if (!controller.isCurrent(generation)) return;
    controller.postProcessing.value = true;

    void pushProgress(ArtworkBackfillProgress art) {
      final progress = (lastProgress ??
              ScanProgress(songsFound: 0, totalFiles: art.total))
          .copyWith(
            phase: 'Loading artwork',
            filesProcessed: art.completed,
            totalFiles: art.total,
            isComplete: false,
          );
      controller.update(generation, progress);
      if (mounted) {
        setState(() => _scanProgress = progress);
        _scanProgressNotifier.value = progress;
      }
    }

    void onArtworkProgress() {
      final art = _scannerService.artworkBackfillProgress.value;
      if (art == null) return;
      pushProgress(art);
    }

    final skipSignal = Completer<void>();
    void onSkipRequest() {
      if (!skipSignal.isCompleted) skipSignal.complete();
    }

    _scannerService.artworkBackfillProgress.addListener(onArtworkProgress);
    controller.skipRequests.addListener(onSkipRequest);
    // If another folder's backfill is already tracked, reflect it right away.
    onArtworkProgress();
    try {
      await Future.any<void>([
        backfill().catchError((Object error) {
          debugPrint('Artwork backfill wait failed: $error');
        }),
        skipSignal.future,
      ]);
    } finally {
      _scannerService.artworkBackfillProgress.removeListener(onArtworkProgress);
      controller.skipRequests.removeListener(onSkipRequest);
      controller.postProcessing.value = false;
    }
  }

  Future<void> _scanFolder(String uri, String displayName) {
    return _runScanSession(
      title: displayName,
      kind: ScanSessionKind.scan,
      onCancel: _scannerService.cancelScan,
      run: () => _scannerService.scanFolder(uri, displayName),
      artworkBackfill: () => _scannerService.awaitArtworkBackfill(uri),
    );
  }

  Future<void> _rescanAllFolders({ScanMode mode = ScanMode.quick}) {
    return _runScanSession(
      title: 'All Folders',
      kind: ScanSessionKind.scan,
      onCancel: _scannerService.cancelScan,
      run: () => _scannerService.scanAllFolders(mode: mode),
      artworkBackfill: _scannerService.awaitAllArtworkBackfill,
    );
  }

  Future<void> _showRescanModeChooser() async {
    final mode = await GlassBottomSheet.show<ScanMode>(
      context: context,
      title: 'Rescan Library',
      maxHeightRatio: 0.4,
      content: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRescanModeTile(
              icon: LucideIcons.zap,
              title: 'Quick scan',
              subtitle: 'Only re-read files that are new or changed.',
              onTap: () => Navigator.of(sheetContext).pop(ScanMode.quick),
            ),
            const SettingsDivider(),
            _buildRescanModeTile(
              icon: LucideIcons.refreshCw,
              title: 'Full scan',
              subtitle:
                  'Re-read metadata for every file. Slower; use when tags look stale.',
              onTap: () => Navigator.of(sheetContext).pop(ScanMode.full),
            ),
          ],
        ),
      ),
    );

    if (mode != null && mounted) {
      await _rescanAllFolders(mode: mode);
    }
  }

  Widget _buildRescanModeTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: AppConstants.spacingMd,
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 22),
            const SizedBox(width: AppConstants.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDuplicateCleaner() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const DuplicateCleanerScreen()),
    );
  }

  Future<void> _preloadLibraryAudio() async {
    final songs = await _songRepository.getAllSongEntities();
    if (songs.isEmpty) return;
    if (!mounted) return;

    final service = AudioPreloadService.instance;
    await _runScanSession(
      title: 'Preloading Audio',
      kind: ScanSessionKind.preload,
      onCancel: service.cancel,
      includeProgressInSummary: false,
      run: () => service
          .preloadSongs(songs, forceAll: false)
          .map(
            (progress) => ScanProgress(
              songsFound: progress.completed,
              totalFiles: progress.total,
              filesProcessed: progress.completed,
              currentFile: progress.currentFile,
              currentFolder: 'Preloading Audio',
              phase: 'Analyzing audio',
              isComplete: progress.isComplete,
            ),
          ),
    );
  }

  Future<void> _scanReplayGain() async {
    final songs = await _songRepository.getAllSongEntities();
    if (songs.isEmpty) return;
    if (!mounted) return;

    final service = ReplayGainScanService();
    await _runScanSession(
      title: 'ReplayGain Scan',
      kind: ScanSessionKind.replayGain,
      onCancel: service.cancel,
      includeProgressInSummary: false,
      run: () => service
          .scanLibrary(songs)
          .map(
            (progress) => ScanProgress(
              songsFound: progress.completed,
              totalFiles: progress.total,
              filesProcessed: progress.completed,
              currentFile: progress.currentFile,
              currentFolder: 'ReplayGain Scan',
              phase: 'Analyzing loudness',
              isComplete: progress.isComplete,
            ),
          ),
    );
  }

  void _confirmRemoveFolder(MusicFolder folder) {
    unawaited(
      FlickDialogs.confirm(
        context,
        title: 'Remove Folder?',
        message:
            'Remove "${folder.displayName}" and all of its songs from your '
            'library? Files on disk are not deleted.',
        confirmLabel: 'Remove',
        destructive: true,
      ).then((confirmed) {
        if (confirmed) _removeFolder(folder);
      }),
    );
  }

  void _showScanningOverlay(String folderName, int generation) {
    _scanOverlayOpen = true;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: AppConstants.glassBlurSigma,
                  sigmaY: AppConstants.glassBlurSigma,
                ),
                child: const SizedBox.expand(),
              ),
              SafeArea(
                child: ValueListenableBuilder<ScanProgress?>(
                  valueListenable: _scanProgressNotifier,
                  builder: (context, progress, _) {
                    if (progress?.unavailable == true) {
                      return _buildUnavailableState(progress!, folderName);
                    }
                    return _buildScanDashboard(progress, folderName);
                  },
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      // Covers minimize, system-back, cancel, and natural completion: if the
      // work is still running, the floating pill takes over.
      _scanOverlayOpen = false;
      ScanSessionController.instance.overlayDismissed(generation);
    });
  }

  Widget _buildScanDashboard(ScanProgress? progress, String folderName) {
    final fraction = progress?.progressFraction ?? 0;
    final bgRunning = progress?.backgroundTasksRunning ?? false;
    final displayFraction = bgRunning ? 1.0 : fraction;
    final totalFiles = progress?.totalFiles ?? 0;
    final loadingArtwork = progress?.phase == 'Loading artwork';
    // Every file is accounted for but the stream has not sent its completion
    // event yet: keep telling the user something is still happening.
    final finishingUp =
        !bgRunning &&
        !loadingArtwork &&
        totalFiles > 0 &&
        (progress?.filesProcessed ?? 0) >= totalFiles &&
        progress?.isComplete != true;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingXl,
        vertical: AppConstants.spacingLg,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(200, 200),
                        painter: _ProgressRingPainter(
                          fraction: displayFraction,
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _vinylController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _vinylController.value * 2 * pi,
                            child: child,
                          );
                        },
                        child: const VinylRecord(size: 120),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.spacingXl),
                Text(
                  progress?.currentFolder ?? folderName,
                  style: const TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppConstants.spacingSm),
                _buildPhaseRow(
                  finishingUp
                      ? 'Finishing up…'
                      : loadingArtwork
                      ? 'Loading artwork…'
                      : progress?.phase,
                  bgRunning,
                ),
                const SizedBox(height: AppConstants.spacingLg),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                  child: LinearProgressIndicator(
                    value: totalFiles > 0 ? displayFraction : null,
                    backgroundColor: AppColors.glassBackground,
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingXs),
                Text(
                  loadingArtwork
                      ? totalFiles > 0
                            ? '${progress?.filesProcessed ?? 0} / $totalFiles covers'
                            : 'Loading artwork…'
                      : totalFiles > 0
                      ? '${progress?.filesProcessed ?? 0} / $totalFiles files'
                      : (progress?.filesProcessed ?? 0) > 0
                      ? '${progress!.filesProcessed} files checked…'
                      : 'Counting files…',
                  style: const TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
                if (progress?.folders != null &&
                    progress!.folders!.length > 1) ...[
                  const SizedBox(height: AppConstants.spacingMd),
                  Text(
                    'Folder ${progress.foldersCompleted ?? 0} of ${progress.foldersTotal ?? progress.folders!.length}',
                    style: const TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingSm),
                  ...progress.folders!.map(_buildFolderProgressRow),
                ],
                const SizedBox(height: AppConstants.spacingLg),
                _buildStatRow([
                  _buildScanStat(
                    'New',
                    '${progress?.newSongs ?? 0}',
                    LucideIcons.plus,
                  ),
                  _buildScanStat(
                    'Mod',
                    '${progress?.modifiedSongs ?? 0}',
                    LucideIcons.refreshCw,
                  ),
                  _buildScanStat(
                    'Del',
                    '${progress?.deletedSongs ?? 0}',
                    LucideIcons.trash2,
                  ),
                ]),
                const SizedBox(height: AppConstants.spacingMd),
                ValueListenableBuilder<Duration>(
                  valueListenable: _elapsedNotifier,
                  builder: (context, elapsed, _) {
                    return _buildStatRow([
                      _buildScanStat(
                        'Time',
                        _formatDuration(elapsed),
                        LucideIcons.timer,
                      ),
                      _buildScanStat(
                        'Rate',
                        _formatRate(progress?.filesProcessed ?? 0, elapsed),
                        LucideIcons.gauge,
                      ),
                      _buildScanStat(
                        'Engine',
                        progress?.scanEngine ?? '—',
                        LucideIcons.cpu,
                      ),
                    ]);
                  },
                ),
                const SizedBox(height: AppConstants.spacingXl),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Minimize',
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingMd),
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          if (loadingArtwork) {
                            // Covers keep resolving in the background; just
                            // stop waiting on them.
                            ScanSessionController.instance.requestSkip();
                            return;
                          }
                          ScanSessionController.instance.stop();
                          _vinylController.stop();
                          _scanStopwatch.stop();
                          _elapsedTimer?.cancel();
                          _elapsedTimer = null;
                          Navigator.of(context).pop();
                          _scanProgressNotifier.value = null;
                          setState(() {
                            _isScanning = false;
                            _scanProgress = null;
                          });
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          loadingArtwork ? 'Skip' : 'Cancel',
                          style: const TextStyle(
                            fontFamily: 'ProductSans',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
  }

  Widget _buildFolderProgressRow(FolderScanProgress folder) {
    final status = folder.unavailable
        ? 'Unavailable'
        : folder.totalFiles > 0
        ? '${folder.filesProcessed}/${folder.totalFiles}'
        : folder.isComplete
        ? 'Done'
        : 'Checking…';

    return Padding(
      padding: const EdgeInsets.only(top: AppConstants.spacingXs),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              folder.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          Expanded(
            flex: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusRound),
              child: LinearProgressIndicator(
                value: folder.totalFiles > 0 ? folder.progressFraction : null,
                backgroundColor: AppColors.glassBackground,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          SizedBox(
            width: 76,
            child: Text(
              status,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseRow(String? phase, bool bgRunning) {
    final text = bgRunning
        ? 'Finishing metadata enrichment…'
        : (phase ?? 'Initializing…');
    if (bgRunning) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 13,
              color: AppColors.accent,
            ),
          ),
        ],
      );
    }
    return AnimatedBuilder(
      animation: _vinylController,
      builder: (context, _) {
        final v = _vinylController.value;
        final pulse = v < 0.5 ? v * 2 : 2 - v * 2;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: 0.3 + 0.7 * pulse,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 13,
                color: AppColors.accent,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUnavailableState(ScanProgress progress, String folderName) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.usb,
              size: 64,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppConstants.spacingLg),
            const Text(
              'USB storage not connected',
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              '${progress.currentFolder ?? folderName} is offline — retained songs still listed',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingXl),
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
      ),
    );
  }

  void _showScanCompleteBottomSheet({
    required Duration scanDuration,
    ScanProgress? progress,
    int totalSongs = 0,
  }) {
    final songs = progress?.songsFound ?? totalSongs;

    GlassBottomSheet.show(
      context: context,
      title: 'Scan Complete',
      isDismissible: true,
      enableDrag: true,
      maxHeightRatio: 0.42,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: AppConstants.spacingMd),
          const Icon(
            LucideIcons.circleCheck,
            color: AppColors.accent,
            size: 48,
          ),
          const SizedBox(height: AppConstants.spacingLg),
          _buildStatRow([
            _buildScanStat(
              'New',
              '${progress?.newSongs ?? 0}',
              LucideIcons.plus,
            ),
            _buildScanStat(
              'Mod',
              '${progress?.modifiedSongs ?? 0}',
              LucideIcons.refreshCw,
            ),
            _buildScanStat(
              'Del',
              '${progress?.deletedSongs ?? 0}',
              LucideIcons.trash2,
            ),
          ]),
          const SizedBox(height: AppConstants.spacingMd),
          _buildStatRow([
            _buildScanStat('Total', '$songs', LucideIcons.music),
            _buildScanStat(
              'Time',
              _formatDuration(scanDuration),
              LucideIcons.timer,
            ),
            _buildScanStat(
              'Rate',
              _formatRate(progress?.filesProcessed ?? songs, scanDuration),
              LucideIcons.gauge,
            ),
          ]),
          if (progress?.scanEngine != null ||
              progress?.foldersTotal != null) ...[
            const SizedBox(height: AppConstants.spacingMd),
            _buildEngineInfoChip(progress),
          ],
          ValueListenableBuilder<PreloadProgress?>(
            valueListenable: AudioPreloadService.instance.progress,
            builder: (context, preload, _) {
              if (preload == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: AppConstants.spacingMd),
                child: Container(
                  padding: const EdgeInsets.all(AppConstants.spacingSm),
                  decoration: BoxDecoration(
                    color: AppColors.glassBackground,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.activity,
                        color: AppColors.accent,
                        size: 18,
                      ),
                      const SizedBox(width: AppConstants.spacingXs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Preloading audio ${preload.completed}/${preload.total}',
                              style: const TextStyle(
                                fontFamily: 'ProductSans',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (preload.currentFile != null)
                              Text(
                                preload.currentFile!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'ProductSans',
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: AudioPreloadService.instance.cancel,
                        child: const Text('Stop'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (songs == 0) ...[
            const SizedBox(height: AppConstants.spacingMd),
            Container(
              padding: const EdgeInsets.all(AppConstants.spacingSm),
              decoration: BoxDecoration(
                color: AppColors.glassBackground,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    LucideIcons.info,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                  const SizedBox(width: AppConstants.spacingXs),
                  Expanded(
                    child: Text(
                      'No audio was found. If this folder contains music, a '
                      '.nomedia file may be hiding it, or Android hasn\'t '
                      'indexed it yet. Try enabling deep scan, or remove any '
                      '.nomedia file and re-scan.',
                      style: TextStyle(
                        fontFamily: 'ProductSans',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppConstants.spacingLg),
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

  Widget _buildEngineInfoChip(ScanProgress? progress) {
    final parts = <String>[];
    if (progress?.scanEngine != null) parts.add(progress!.scanEngine!);
    if (progress?.foldersTotal != null) {
      parts.add('${progress!.foldersTotal} folders');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.cpu, size: 12, color: AppColors.accent),
          const SizedBox(width: 5),
          Text(
            parts.join(' · '),
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 12,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(List<Widget> stats) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.glassBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (int i = 0; i < stats.length; i++) ...[
            if (i > 0)
              Container(width: 1, height: 40, color: AppColors.glassBorder),
            stats[i],
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes > 0) {
      return '${d.inMinutes}:${(d.inSeconds.remainder(60)).toString().padLeft(2, '0')}';
    }
    return '${d.inSeconds}s';
  }

  String _formatRate(int count, Duration elapsed) {
    final secs = elapsed.inSeconds;
    if (secs < 1) return '—';
    final rate = count / secs;
    return rate < 10 ? '${rate.toStringAsFixed(1)}/s' : '${rate.round()}/s';
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _folders.isEmpty
            ? null
            : () => setState(() => _libraryExpanded = !_libraryExpanded),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          child: Row(
            children: [
              Container(
                width: context.scaleSize(AppConstants.containerSizeMd),
                height: context.scaleSize(AppConstants.containerSizeMd),
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: context.adaptiveTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_songCount songs in ${_folders.length} ${_folders.length == 1 ? 'folder' : 'folders'}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.adaptiveTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_folders.isNotEmpty)
                AnimatedRotation(
                  turns: _libraryExpanded ? 0.5 : 0,
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
    final globalDeepScan = ref
        .watch(libraryScanPreferencesProvider)
        .useDeepScan;
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
            onTap: () =>
                setState(() => _scanSettingsExpanded = !_scanSettingsExpanded),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              child: Row(
                children: [
                  Container(
                    width: context.scaleSize(AppConstants.containerSizeMd),
                    height: context.scaleSize(AppConstants.containerSizeMd),
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
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: context.adaptiveTextPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Filter files, size limits, and playlist import options',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: context.adaptiveTextTertiary),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _scanSettingsExpanded ? 0.5 : 0,
                    duration: AppConstants.animationNormal,
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
        AnimatedSize(
          duration: AppConstants.animationNormal,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedOpacity(
            duration: AppConstants.animationNormal,
            opacity: _scanSettingsExpanded ? 1.0 : 0.0,
            child: _scanSettingsExpanded
                ? Column(
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
                        subtitle:
                            'Exclude tiny clips, previews, and accidental scraps',
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
                        subtitle:
                            'Hide short stingers, ringtones, and voice fragments',
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
                        const SettingsDivider(),
                        NavigationSetting(
                          icon: _allFilesAccessGranted
                              ? LucideIcons.shieldCheck
                              : LucideIcons.folderSearch,
                          title: 'Full Library Access',
                          subtitle: _allFilesAccessGranted
                              ? 'Granted — scans read every volume directly, '
                                    'including DSD/DSF/WavPack'
                              : 'Not granted — enable so scans cover DSD/DSF/WavPack '
                                    'files the system index may skip',
                          onTap: _openAllFilesAccessSettings,
                        ),
                      ],
                      const SettingsDivider(),
                      ToggleSetting(
                        icon: LucideIcons.audioWaveform,
                        title: 'Preload audio data',
                        subtitle:
                            'Decode songs after scanning to cache waveform peaks and loudness metrics',
                        value: prefs.preloadAudioData,
                        onChanged: (value) {
                          ref
                              .read(libraryScanPreferencesProvider.notifier)
                              .setPreloadAudioData(value);
                        },
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryScanPreferences = ref.watch(libraryScanPreferencesProvider);
    final appPreferences = ref.watch(appPreferencesProvider);

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
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: context.adaptiveTextPrimary,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isXiaomiDevice
                                      ? 'Required on many Xiaomi, Redmi, and POCO devices so rescans and background features keep working'
                                      : 'Allow Flick to run without aggressive background limits so rescans and background features keep working',
                                  style: Theme.of(context).textTheme.bodyMedium
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
              if (_showAllFilesAccessNotice) ...[
                const SettingsDivider(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openAllFilesAccessSettings,
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
                              LucideIcons.folderSearch,
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
                                  'Enable Full Library Access',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: context.adaptiveTextPrimary,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Lets Flick scan your entire library directly, '
                                  'including DSD/DSF/WavPack files some devices '
                                  'hide from the system media index',
                                  style: Theme.of(context).textTheme.bodyMedium
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
                            onPressed: _dismissAllFilesNotice,
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
              AnimatedSize(
                duration: AppConstants.animationNormal,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedOpacity(
                  duration: AppConstants.animationNormal,
                  opacity: _libraryExpanded ? 1.0 : 0.0,
                  child: _libraryExpanded && _folders.isNotEmpty
                      ? Column(
                          children: [
                            for (final folder in _folders) ...[
                              _buildFolderItem(folder),
                              if (_folders.last != folder)
                                const SettingsDivider(),
                            ],
                            const SettingsDivider(),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ),
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
                  subtitle: 'Quick or full re-index of all folders',
                  onTap: _isScanning ? null : _showRescanModeChooser,
                ),
                const SettingsDivider(),
                ActionButton(
                  icon: LucideIcons.audioWaveform,
                  title: 'Preload Library Audio',
                  subtitle: 'Cache waveforms and loudness for all songs',
                  onTap: _isScanning ? null : _preloadLibraryAudio,
                ),
                const SettingsDivider(),
                ActionButton(
                  icon: LucideIcons.gauge,
                  title: 'Scan ReplayGain',
                  subtitle:
                      'Analyze loudness and write ReplayGain tags for all songs',
                  onTap: _isScanning ? null : _scanReplayGain,
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
          const SettingsSectionHeader('Storage'),
          SettingsCard(
            children: [
              ActionButton(
                icon: LucideIcons.image,
                title: 'Clear Artwork Cache',
                subtitle: _cacheSizeLabel,
                onTap: _isClearingCache ? null : _confirmClearArtworkCache,
              ),
              const SettingsDivider(),
              ActionButton(
                icon: LucideIcons.database,
                title: 'Playback Cache Limit',
                subtitle: _cacheCapLabel,
                onTap: _showCacheCapSheet,
              ),
              const SettingsDivider(),
              ActionButton(
                icon: LucideIcons.fileAudio,
                title: 'Clear Converted Audio',
                subtitle: _wavCacheSizeLabel,
                onTap: _isClearingWavCache ? null : _confirmClearWavCache,
              ),
              const SettingsDivider(),
              ActionButton(
                icon: LucideIcons.trash2,
                title: 'Remove All Songs',
                subtitle: 'Empty the library; files on disk are kept',
                onTap: _confirmRemoveAllSongs,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('Album Artwork'),
          SettingsCard(
            children: [
              ToggleSetting(
                icon: LucideIcons.crop,
                title: 'Stretch Non-Square Art',
                subtitle:
                    'Off crops to fill the square; on stretches the artwork edge-to-edge',
                value: appPreferences.albumsStretchArtwork,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setAlbumsStretchArtwork(value);
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SizedBox(height: AppConstants.navBarHeight + 40),
        ],
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double fraction;

  _ProgressRingPainter({required this.fraction});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 8;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paint..color = AppColors.glassBorder);

    if (fraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        fraction * 2 * pi,
        false,
        paint..color = AppColors.accent,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) => old.fraction != fraction;
}
