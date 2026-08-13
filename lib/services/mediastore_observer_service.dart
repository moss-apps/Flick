import 'dart:async';
import 'music_folder_service.dart';
import 'library_scanner_service.dart';
import 'package:flick/core/utils/dev_log.dart';

class MediaStoreObserverService {
  final MusicFolderService _musicFolderService;
  final Stream<ScanProgress> Function() _scanAllFolders;
  final DateTime Function() _clock;

  StreamSubscription? _subscription;
  Timer? _debounce;
  bool _isProcessing = false;
  bool _pendingRescan = false;
  DateTime? _pausedAt;

  MediaStoreObserverService({
    MusicFolderService? musicFolderService,
    Stream<ScanProgress> Function()? scanAllFolders,
    DateTime Function()? clock,
  })  : _musicFolderService = musicFolderService ?? MusicFolderService(),
        _scanAllFolders =
            scanAllFolders ?? (() => LibraryScannerService().scanAllFolders()),
        _clock = clock ?? DateTime.now;

  void start() {
    try {
      _subscription = _musicFolderService.mediaStoreChanges.listen(
        _onChange,
        onError: (e) {
          devLog('MediaStoreObserver error: $e');
        },
      );
    } catch (e) {
      devLog('MediaStoreObserver failed to start: $e');
    }
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _debounce?.cancel();
    _debounce = null;
  }

  void _onChange(Map<String, dynamic> event) {
    _debounce?.cancel();
    if (_isProcessing) {
      _pendingRescan = true;
      return;
    }
    _debounce = Timer(const Duration(seconds: 3), _processChange);
  }

  void notifyPaused() {
    _pausedAt = _clock();
  }

  void notifyResumed() {
    final pausedAt = _pausedAt;
    _pausedAt = null;
    // ponytail: skip catch-up rescan after brief app switches (jank, #210);
    // the MediaStore change stream still covers real changes while away.
    if (pausedAt != null &&
        _clock().difference(pausedAt) < const Duration(minutes: 1)) {
      return;
    }
    _debounce?.cancel();
    if (_isProcessing) {
      _pendingRescan = true;
      return;
    }
    _debounce = Timer(const Duration(seconds: 1), _processChange);
  }

  Future<void> _processChange() async {
    if (_isProcessing) {
      _pendingRescan = true;
      return;
    }
    _isProcessing = true;
    _pendingRescan = false;

    try {
      await for (final _ in _scanAllFolders()) {}
      devLog('MediaStoreObserver: auto-rescan complete');
    } catch (e) {
      devLog('MediaStoreObserver rescan failed: $e');
    } finally {
      _isProcessing = false;
      if (_pendingRescan) {
        _pendingRescan = false;
        _debounce?.cancel();
        _debounce = Timer(const Duration(seconds: 3), _processChange);
      }
    }
  }
}
