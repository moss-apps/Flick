import 'package:flick/models/song.dart';
import 'package:flick/src/rust/audio/source.dart';
import 'package:just_audio/just_audio.dart';

/// A shared file path is not a track identity for CUE albums.
bool matchesPlaybackSource(
  Song song,
  String? resolvedPath,
  SourceIdentity? source,
) {
  if (resolvedPath == null || source == null || source.path != resolvedPath) {
    return false;
  }
  final start = (song.startOffsetMs ?? 0) / 1000;
  final end = song.endOffsetMs;
  return (source.range.startSecs - start).abs() < 0.000001 &&
      (end == null
          ? source.range.endSecs == null
          : source.range.endSecs != null &&
                (source.range.endSecs! - end / 1000).abs() < 0.000001);
}

/// Zero is a valid CUE start; its finite end must still be enforced.
AudioSource clipPlaybackSource(Song song, UriAudioSource source) {
  if (song.startOffsetMs == null && song.endOffsetMs == null) return source;
  return ClippingAudioSource(
    child: source,
    start: Duration(milliseconds: song.startOffsetMs ?? 0),
    end: song.endOffsetMs == null
        ? null
        : Duration(milliseconds: song.endOffsetMs!),
  );
}
