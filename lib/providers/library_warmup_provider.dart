import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'songs_provider.dart';

/// Emits the number of songs still awaiting background metadata extraction
/// (`metadataComplete == false`).
///
/// Yields the current count first, then re-emits on every change to the songs
/// collection. A value of `0` means the library is warm. Naturally Android-only
/// in practice: on other platforms the scan sets `metadataComplete` inline, so
/// the count is 0 from the start and the notice never appears.
final libraryWarmupProvider = StreamProvider<int>((ref) async* {
  final repo = ref.watch(songRepositoryProvider);
  yield await repo.countIncompleteMetadataSongs();
  await for (final _ in repo.watchSongs()) {
    yield await repo.countIncompleteMetadataSongs();
  }
});
