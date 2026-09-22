import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flick/services/audio_preload_service.dart';
import 'package:flick/services/library_scan_preferences_service.dart';

final libraryScanPreferencesServiceProvider =
    Provider<LibraryScanPreferencesService>((ref) {
      return LibraryScanPreferencesService();
    });

final audioPreloadServiceProvider = Provider<AudioPreloadService>((ref) {
  return AudioPreloadService.instance;
});

class LibraryScanPreferencesNotifier extends Notifier<LibraryScanPreferences> {
  bool _loaded = false;
  Future<void>? _loadFuture;

  @override
  LibraryScanPreferences build() {
    _loadFuture ??= _loadPreferences();
    return const LibraryScanPreferences();
  }

  Future<void> _loadPreferences() async {
    final preferences = await ref
        .read(libraryScanPreferencesServiceProvider)
        .getPreferences();
    _loaded = true;
    if (ref.mounted) {
      state = preferences;
    }
  }

  /// Setters must not compare against the pristine default state while the
  /// persisted values are still loading: that race early-returned without
  /// persisting, leaving the toggle at odds with what the scanner reads.
  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    await (_loadFuture ??= _loadPreferences());
  }

  Future<void> setFilterNonMusicFilesAndFolders(bool value) async {
    await _ensureLoaded();
    if (state.filterNonMusicFilesAndFolders == value) return;
    state = state.copyWith(filterNonMusicFilesAndFolders: value);
    await ref
        .read(libraryScanPreferencesServiceProvider)
        .setFilterNonMusicFilesAndFolders(value);
  }

  Future<void> setIgnoreTracksSmallerThan500Kb(bool value) async {
    await _ensureLoaded();
    if (state.ignoreTracksSmallerThan500Kb == value) return;
    state = state.copyWith(ignoreTracksSmallerThan500Kb: value);
    await ref
        .read(libraryScanPreferencesServiceProvider)
        .setIgnoreTracksSmallerThan500Kb(value);
  }

  Future<void> setIgnoreTracksShorterThan60Seconds(bool value) async {
    await _ensureLoaded();
    if (state.ignoreTracksShorterThan60Seconds == value) return;
    state = state.copyWith(ignoreTracksShorterThan60Seconds: value);
    await ref
        .read(libraryScanPreferencesServiceProvider)
        .setIgnoreTracksShorterThan60Seconds(value);
  }

  Future<void> setCreatePlaylistsFromM3uFiles(bool value) async {
    await _ensureLoaded();
    if (state.createPlaylistsFromM3uFiles == value) return;
    state = state.copyWith(createPlaylistsFromM3uFiles: value);
    await ref
        .read(libraryScanPreferencesServiceProvider)
        .setCreatePlaylistsFromM3uFiles(value);
  }

  Future<void> setUseDeepScan(bool value) async {
    await _ensureLoaded();
    if (state.useDeepScan == value) return;
    state = state.copyWith(useDeepScan: value);
    await ref
        .read(libraryScanPreferencesServiceProvider)
        .setUseDeepScan(value);
  }

  Future<void> setPreloadAudioData(bool value) async {
    await _ensureLoaded();
    if (state.preloadAudioData == value) return;
    state = state.copyWith(preloadAudioData: value);
    await ref
        .read(libraryScanPreferencesServiceProvider)
        .setPreloadAudioData(value);
    final preloadService = ref.read(audioPreloadServiceProvider);
    if (value) {
      preloadService.clearAutoSuppression();
    } else {
      // A pass from an earlier scan may still be decoding. Turning the setting
      // off has to stop it (and its floating pill), not just prevent the next.
      preloadService.cancel();
    }
  }
}

final libraryScanPreferencesProvider =
    NotifierProvider<LibraryScanPreferencesNotifier, LibraryScanPreferences>(
      LibraryScanPreferencesNotifier.new,
    );
