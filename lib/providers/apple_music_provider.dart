import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:flick/services/apple_music/apple_music_metadata_service.dart';

part 'apple_music_provider.g.dart';

@Riverpod(keepAlive: true)
AppleMusicMetadataService appleMusicMetadataService(Ref ref) {
  return AppleMusicMetadataService.instance;
}

/// Apple Music metadata for an artist page. Auto-disposes when the page
/// closes; durable caching lives in [AppleMusicMetadataService].
@riverpod
class AppleMusicArtistNotifier extends _$AppleMusicArtistNotifier {
  @override
  Future<AppleMusicArtistData?> build(String artistName) => _load();

  /// Reloads from Apple Music. Returns true when fresh data arrived; on
  /// failure the previous value is kept so the page does not blank out.
  Future<bool> refresh() async {
    final previous = state;
    final next = await AsyncValue.guard(() => _load(refresh: true));
    if ((next.hasError || next.value == null) && previous.hasValue) {
      state = previous;
      return false;
    }
    state = next;
    return next.value != null;
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
  Future<AppleMusicAlbumData?> build((String, String) key) {
    final (album, artist) = key;
    return _load(album: album, artist: artist);
  }

  /// Reloads from Apple Music. Returns true when fresh data arrived; on
  /// failure the previous value is kept so the page does not blank out.
  Future<bool> refresh() async {
    final previous = state;
    final (album, artist) = key;
    final next = await AsyncValue.guard(
      () => _load(album: album, artist: artist, refresh: true),
    );
    if ((next.hasError || next.value == null) && previous.hasValue) {
      state = previous;
      return false;
    }
    state = next;
    return next.value != null;
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
