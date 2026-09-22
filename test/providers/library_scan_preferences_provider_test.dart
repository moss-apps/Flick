import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flick/providers/library_scan_preferences_provider.dart';
import 'package:flick/services/audio_preload_service.dart';
import 'package:flick/services/library_scan_preferences_service.dart';

class _FakePreferencesService implements LibraryScanPreferencesService {
  Completer<LibraryScanPreferences>? loadCompleter;
  LibraryScanPreferences loaded = const LibraryScanPreferences();
  final List<(String, bool)> writes = [];

  @override
  Future<LibraryScanPreferences> getPreferences() {
    final completer = loadCompleter;
    return completer == null ? Future.value(loaded) : completer.future;
  }

  @override
  Future<void> setFilterNonMusicFilesAndFolders(bool value) async {
    writes.add(('filterNonMusicFilesAndFolders', value));
  }

  @override
  Future<void> setIgnoreTracksSmallerThan500Kb(bool value) async {
    writes.add(('ignoreTracksSmallerThan500Kb', value));
  }

  @override
  Future<void> setIgnoreTracksShorterThan60Seconds(bool value) async {
    writes.add(('ignoreTracksShorterThan60Seconds', value));
  }

  @override
  Future<void> setCreatePlaylistsFromM3uFiles(bool value) async {
    writes.add(('createPlaylistsFromM3uFiles', value));
  }

  @override
  Future<void> setUseDeepScan(bool value) async {
    writes.add(('useDeepScan', value));
  }

  @override
  Future<void> setPreloadAudioData(bool value) async {
    writes.add(('preloadAudioData', value));
  }
}

void main() {
  late _FakePreferencesService service;
  late AudioPreloadService preloadService;
  late ProviderContainer container;

  setUp(() {
    service = _FakePreferencesService();
    preloadService = AudioPreloadService();
    container = ProviderContainer(
      overrides: [
        libraryScanPreferencesServiceProvider.overrideWithValue(service),
        audioPreloadServiceProvider.overrideWithValue(preloadService),
      ],
    );
  });

  tearDown(() => container.dispose());

  LibraryScanPreferences read() =>
      container.read(libraryScanPreferencesProvider);

  test('loads persisted values', () async {
    service.loaded = const LibraryScanPreferences(preloadAudioData: true);

    container.read(libraryScanPreferencesProvider);
    await pumpEventQueue();

    expect(read().preloadAudioData, isTrue);
  });

  test('a toggle before the persisted load lands still wins and persists', () async {
    service.loadCompleter = Completer<LibraryScanPreferences>();

    final toggle = container
        .read(libraryScanPreferencesProvider.notifier)
        .setPreloadAudioData(true);
    service.loadCompleter!.complete(const LibraryScanPreferences());
    await toggle;

    expect(read().preloadAudioData, isTrue);
    expect(service.writes, contains(('preloadAudioData', true)));
  });

  test('a toggle made after load is persisted', () async {
    service.loaded = const LibraryScanPreferences(preloadAudioData: true);

    container.read(libraryScanPreferencesProvider);
    await pumpEventQueue();

    await container
        .read(libraryScanPreferencesProvider.notifier)
        .setPreloadAudioData(false);

    expect(read().preloadAudioData, isFalse);
    expect(service.writes, contains(('preloadAudioData', false)));
  });

  test('a no-op toggle does not rewrite the stored value', () async {
    service.loaded = const LibraryScanPreferences();

    container.read(libraryScanPreferencesProvider);
    await pumpEventQueue();

    await container
        .read(libraryScanPreferencesProvider.notifier)
        .setPreloadAudioData(false);

    expect(service.writes, isEmpty);
  });

  test('turning preload off cancels a running pass and suppresses auto passes', () async {
    service.loaded = const LibraryScanPreferences(preloadAudioData: true);

    container.read(libraryScanPreferencesProvider);
    await pumpEventQueue();

    expect(preloadService.isAutoSuppressed, isFalse);

    await container
        .read(libraryScanPreferencesProvider.notifier)
        .setPreloadAudioData(false);

    expect(read().preloadAudioData, isFalse);
    expect(preloadService.isAutoSuppressed, isTrue);
    expect(preloadService.isRunning, isFalse);
  });

  test('turning preload on lifts auto suppression', () async {
    service.loaded = const LibraryScanPreferences(preloadAudioData: false);

    container.read(libraryScanPreferencesProvider);
    await pumpEventQueue();

    preloadService.cancel();
    expect(preloadService.isAutoSuppressed, isTrue);

    await container
        .read(libraryScanPreferencesProvider.notifier)
        .setPreloadAudioData(true);

    expect(preloadService.isAutoSuppressed, isFalse);
  });
}
