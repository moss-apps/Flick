import 'dart:async';
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
import 'package:flick/services/album_art_service.dart';
import 'package:flick/services/android_audio_device_service.dart';
import 'package:flick/services/audio_preload_service.dart';
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
  bool _libraryExpanded = false;
  int _artworkCacheBytes = -1;
  bool _isClearingCache = false;

  late final AnimationController _vinylController;

  final ValueNotifier<ScanProgress?> _scanProgressNotifier = ValueNotifier(
    null,
  );
  final Stopwatch _scanStopwatch = Stopwatch();
  Timer? _elapsedTimer;
  final ValueNotifier<Duration> _elapsedNotifier = ValueNotifier(Duration.zero);

  @override
  void initState() {
    super.initState();
    _vinylController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _loadLibraryData();
    _syncFoldersToDatabase();
    _loadAndroidDeviceNotices();
    _refreshCacheSize();
  }

  @override
  void dispose() {
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
    showDialog(
      context: context,
      builder: (context) => GlassDialog(
        title: 'Clear Artwork Cache?',
        content: Text(
          'Cached album art (${_formatBytes(_artworkCacheBytes)}) will be removed. '
          'Artwork reloads automatically as you browse.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _clearArtworkCache();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
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
    _showScanningOverlay(displayName);

    await for (final progress in _scannerService.scanFolder(uri, displayName)) {
      if (mounted) {
        setState(() => _scanProgress = progress);
        _scanProgressNotifier.value = progress;
      }
    }

    _scanStopwatch.stop();
    _vinylController.stop();
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    await _loadLibraryData();
    if (mounted) {
      Navigator.of(context).pop();
      _scanProgressNotifier.value = null;
      final lastProgress = _scanProgress;
      setState(() {
        _isScanning = false;
        _scanProgress = null;
      });
      if (lastProgress?.unavailable != true) {
        _showScanCompleteBottomSheet(
          scanDuration: _scanStopwatch.elapsed,
          progress: lastProgress,
          totalSongs: _songCount,
        );
      }
    }
  }

  Future<void> _rescanAllFolders() async {
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
    _showScanningOverlay('All Folders');

    await for (final progress in _scannerService.scanAllFolders()) {
      if (mounted) {
        setState(() => _scanProgress = progress);
        _scanProgressNotifier.value = progress;
      }
    }

    _scanStopwatch.stop();
    _vinylController.stop();
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    await _loadLibraryData();
    if (mounted) {
      Navigator.of(context).pop();
      _scanProgressNotifier.value = null;
      final lastProgress = _scanProgress;
      setState(() {
        _isScanning = false;
        _scanProgress = null;
      });
      if (lastProgress?.unavailable != true) {
        _showScanCompleteBottomSheet(
          scanDuration: _scanStopwatch.elapsed,
          progress: lastProgress,
          totalSongs: _songCount,
        );
      }
    }
  }

  void _openDuplicateCleaner() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const DuplicateCleanerScreen()),
    );
  }

  Future<void> _preloadLibraryAudio() async {
    final songs = await _songRepository.getAllSongEntities();
    if (songs.isEmpty) return;

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
    _showScanningOverlay('Preloading Audio');

    final service = AudioPreloadService();
    await for (final progress in service.preloadSongs(songs, forceAll: false)) {
      if (mounted) {
        _scanProgressNotifier.value = ScanProgress(
          songsFound: progress.completed,
          totalFiles: progress.total,
          currentFile: progress.currentFile,
          currentFolder: 'Preloading Audio',
          phase: 'Analyzing audio',
          isComplete: progress.isComplete,
        );
      }
    }

    _scanStopwatch.stop();
    _vinylController.stop();
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    await _loadLibraryData();
    if (mounted) {
      Navigator.of(context).pop();
      _scanProgressNotifier.value = null;
      setState(() {
        _isScanning = false;
        _scanProgress = null;
      });
      _showScanCompleteBottomSheet(
        scanDuration: _scanStopwatch.elapsed,
        progress: null,
        totalSongs: _songCount,
      );
    }
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
    );
  }

  Widget _buildScanDashboard(ScanProgress? progress, String folderName) {
    final fraction = progress?.progressFraction ?? 0;
    final bgRunning = progress?.backgroundTasksRunning ?? false;
    final displayFraction = bgRunning ? 1.0 : fraction;
    final totalFiles = progress?.totalFiles ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingXl,
        vertical: AppConstants.spacingLg,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(200, 200),
                  painter: _ProgressRingPainter(fraction: displayFraction),
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
          _buildPhaseRow(progress?.phase, bgRunning),
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
            totalFiles > 0
                ? '${progress?.filesProcessed ?? 0} / $totalFiles files'
                : 'Counting files…',
            style: const TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
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
          if (progress?.foldersTotal != null &&
              progress!.foldersTotal! > 1) ...[
            const SizedBox(height: AppConstants.spacingMd),
            Text(
              'Folder ${progress.foldersCompleted ?? 0} of ${progress.foldersTotal}',
              style: const TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppConstants.spacingXl),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                _scannerService.cancelScan();
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
    return rate < 10
        ? '${rate.toStringAsFixed(1)}/s'
        : '${rate.round()}/s';
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
            onTap: () =>
                setState(() => _scanSettingsExpanded = !_scanSettingsExpanded),
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
                  subtitle: 'Re-index all folders',
                  onTap: _isScanning ? null : _rescanAllFolders,
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
