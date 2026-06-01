import 'dart:async';
import 'package:flutter/foundation.dart';
import 'music_folder_service.dart';
import 'library_scanner_service.dart';

class MediaStoreObserverService {
  final MusicFolderService _musicFolderService;
  final LibraryScannerService _scannerService;

  StreamSubscription? _subscription;
  Timer? _debounce;
  bool _isProcessing = false;

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
          debugPrint('MediaStoreObserver error: $e');
        },
      );
    } catch (e) {
      debugPrint('MediaStoreObserver failed to start: $e');
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
    _debounce = Timer(const Duration(seconds: 3), _processChange);
  }

  Future<void> _processChange() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      await for (final _ in _scannerService.scanAllFolders()) {}
      debugPrint('MediaStoreObserver: auto-rescan complete');
    } catch (e) {
      debugPrint('MediaStoreObserver rescan failed: $e');
    } finally {
      _isProcessing = false;
    }
  }
}
