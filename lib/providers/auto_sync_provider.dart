import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auto_library_sync_service.dart';
import '../services/mediastore_observer_service.dart';
import '../services/background_metadata_service.dart';

final autoLibrarySyncServiceProvider = Provider<AutoLibrarySyncService>((ref) {
  final observerService = Platform.isAndroid ? MediaStoreObserverService() : null;
  final backgroundMetadataService = Platform.isAndroid ? BackgroundMetadataService() : null;
  final service = AutoLibrarySyncService(
    observerService: observerService,
    backgroundMetadataService: backgroundMetadataService,
  );

  service.start();

  ref.onDispose(() {
    service.stop();
  });

  return service;
});
