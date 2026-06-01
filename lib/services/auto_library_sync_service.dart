import 'dart:io';
import 'package:flutter/foundation.dart';
import 'mediastore_observer_service.dart';
import 'background_metadata_service.dart';

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
    debugPrint('Auto library sync started (event-driven)');

    if (Platform.isAndroid && _observerService != null) {
      _observerService.start();
    }

    _backgroundMetadataService?.startPeriodicExtraction();
  }

  void stop() {
    _observerService?.stop();
    _backgroundMetadataService?.stop();
    _isRunning = false;
    debugPrint('Auto library sync stopped');
  }

  bool get isRunning => _isRunning;
}
