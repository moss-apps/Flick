import 'dart:async';
import 'music_folder_service.dart';
import 'library_scanner_service.dart';
import 'package:flick/core/utils/dev_log.dart';

class MediaStoreObserverService {
  final MusicFolderService _musicFolderService;
  final LibraryScannerService _scannerService;

  StreamSubscription? _subscription;
  Timer? _debounce;
  bool _isProcessing = false;
  bool _pendingRescan = false;

  MediaStoreObserverService({
    MusicFolderService? musicFolderService,
    LibraryScannerService? scannerService,
  })  : _musicFolderService = musicFolderService ?? MusicFolderService(),
        _scannerService = scannerService ?? LibraryScannerService();

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

  void notifyResumed() {
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
      await for (final _ in _scannerService.scanAllFolders()) {}
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
