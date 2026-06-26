import 'dart:io';
import 'mediastore_observer_service.dart';
import 'background_metadata_service.dart';
import 'package:flick/core/utils/dev_log.dart';

class AutoLibrarySyncService {
  final MediaStoreObserverService? _observerService;
  final BackgroundMetadataService? _backgroundMetadataService;

  bool _isRunning = false;

  AutoLibrarySyncService({
    MediaStoreObserverService? observerService,
    BackgroundMetadataService? backgroundMetadataService,
  })  : _observerService = observerService,
        _backgroundMetadataService = backgroundMetadataService;

  void start() {
    if (_isRunning) return;

    _isRunning = true;
    devLog('Auto library sync started (event-driven)');

    if (Platform.isAndroid && _observerService != null) {
      _observerService.start();
    }

    _backgroundMetadataService?.startPeriodicExtraction();
  }

  void stop() {
    _observerService?.stop();
    _backgroundMetadataService?.stop();
    _isRunning = false;
    devLog('Auto library sync stopped');
  }

  void notifyResumed() {
    if (!_isRunning) return;
    _observerService?.notifyResumed();
  }

  bool get isRunning => _isRunning;
}
