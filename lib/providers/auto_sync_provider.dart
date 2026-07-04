import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auto_library_sync_service.dart';
import '../services/mediastore_observer_service.dart';
import '../services/background_metadata_service.dart';

/// Single shared [BackgroundMetadataService] instance (Android only; null
/// elsewhere). Exposed so the "warm up" notice can trigger an immediate
/// extraction pass via the Speed-up action.
final backgroundMetadataServiceProvider = Provider<BackgroundMetadataService?>((
  ref,
) {
  if (!Platform.isAndroid) return null;
  final service = BackgroundMetadataService();
  ref.onDispose(service.stop);
  return service;
});

final autoLibrarySyncServiceProvider = Provider<AutoLibrarySyncService>((ref) {
  final observerService = Platform.isAndroid ? MediaStoreObserverService() : null;
  final backgroundMetadataService = ref.watch(backgroundMetadataServiceProvider);
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
