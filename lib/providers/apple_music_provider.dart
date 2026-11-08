import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:flick/services/apple_music/apple_music_metadata_service.dart';
import 'package:flick/services/apple_music/apple_music_settings.dart';

part 'apple_music_provider.g.dart';

@Riverpod(keepAlive: true)
AppleMusicMetadataService appleMusicMetadataService(Ref ref) {
  return AppleMusicMetadataService.instance;
}

@Riverpod(keepAlive: true)
AppleMusicSettings appleMusicSettings(Ref ref) {
  return AppleMusicSettings();
}

/// Whether artist and album pages may load Apple Music page information.
/// Keep-alive so the persisted preference is read once and shared by every
/// open detail page and the settings toggle.
@Riverpod(keepAlive: true)
class AppleMusicPageInfoEnabledNotifier
    extends _$AppleMusicPageInfoEnabledNotifier {
  @override
  Future<bool> build() {
    return ref.watch(appleMusicSettingsProvider).pageInfoEnabled();
  }

  Future<void> setEnabled(bool value) async {
    await ref.read(appleMusicSettingsProvider).setPageInfoEnabled(value);
    if (!ref.mounted) return;
    state = AsyncData(value);
  }
}

/// Apple Music metadata for an artist page. Auto-disposes when the page
/// closes; durable caching lives in [AppleMusicMetadataService].
@riverpod
class AppleMusicArtistNotifier extends _$AppleMusicArtistNotifier {
  @override
  Future<AppleMusicArtistData?> build(String artistName) async {
    if (!await ref.watch(appleMusicPageInfoEnabledProvider.future)) {
      return null;
    }
    return _load();
  }

  /// Reloads from Apple Music. Returns true when fresh data arrived; on
  /// failure the previous value is kept so the page does not blank out.
  Future<bool> refresh() async {
    if (!await _pageInfoEnabled()) {
      _clear();
      return false;
    }
    final previous = state;
    final next = await AsyncValue.guard(() => _load(refresh: true));
    if (!ref.mounted) return false;
    // The user may switch page information off while the request is in
    // flight. Do not let its late result restore hidden content.
    if (!await _pageInfoEnabled()) {
      _clear();
      return false;
    }
    if ((next.hasError || next.value == null) && previous.hasValue) {
      state = previous;
      return false;
    }
    state = next;
    return next.value != null;
  }

  Future<bool> _pageInfoEnabled() {
    return ref.read(appleMusicSettingsProvider).pageInfoEnabled();
  }

  void _clear() {
    if (ref.mounted) state = const AsyncData(null);
  }

  Future<AppleMusicArtistData?> _load({bool refresh = false}) {
    return ref
        .read(appleMusicMetadataServiceProvider)
        .getArtistData(artistName, refresh: refresh);
  }
}

/// Apple Music metadata for an album page, keyed by `(album, artist)`.
@riverpod
class AppleMusicAlbumNotifier extends _$AppleMusicAlbumNotifier {
  @override
  Future<AppleMusicAlbumData?> build((String, String) key) async {
    if (!await ref.watch(appleMusicPageInfoEnabledProvider.future)) {
      return null;
    }
    final (album, artist) = key;
    return _load(album: album, artist: artist);
  }

  /// Reloads from Apple Music. Returns true when fresh data arrived; on
  /// failure the previous value is kept so the page does not blank out.
  Future<bool> refresh() async {
    if (!await _pageInfoEnabled()) {
      _clear();
      return false;
    }
    final previous = state;
    final (album, artist) = key;
    final next = await AsyncValue.guard(
      () => _load(album: album, artist: artist, refresh: true),
    );
    if (!ref.mounted) return false;
    // The user may switch page information off while the request is in
    // flight. Do not let its late result restore hidden content.
    if (!await _pageInfoEnabled()) {
      _clear();
      return false;
    }
    if ((next.hasError || next.value == null) && previous.hasValue) {
      state = previous;
      return false;
    }
    state = next;
    return next.value != null;
  }

  Future<bool> _pageInfoEnabled() {
    return ref.read(appleMusicSettingsProvider).pageInfoEnabled();
  }

  void _clear() {
    if (ref.mounted) state = const AsyncData(null);
  }

  Future<AppleMusicAlbumData?> _load({
    required String album,
    required String artist,
    bool refresh = false,
  }) {
    return ref
        .read(appleMusicMetadataServiceProvider)
        .getAlbumData(album: album, artist: artist, refresh: refresh);
  }
}
