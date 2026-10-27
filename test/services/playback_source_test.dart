import 'package:flick/models/song.dart';
import 'package:flick/services/playback_source.dart';
import 'package:flick/src/rust/audio/source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

Song song({int? start, int? end}) => Song(
  id: 'cue-${start ?? 'file'}',
  title: 'Track',
  artist: 'Artist',
  duration: const Duration(seconds: 20),
  fileType: 'FLAC',
  filePath: '/music/album.flac',
  startOffsetMs: start,
  endOffsetMs: end,
);

SourceIdentity source({double start = 0, double? end}) => SourceIdentity(
  path: '/music/album.flac',
  range: PlaybackRange(startSecs: start, endSecs: end),
);

void main() {
  test('zero-start CUE track still clips its finite end', () {
    final original = AudioSource.uri(Uri.file('/music/album.flac'));
    final clipped = clipPlaybackSource(song(start: 0, end: 13000), original);

    expect(clipped, isA<ClippingAudioSource>());
    final clip = clipped as ClippingAudioSource;
    expect(clip.child, same(original));
    expect(clip.start, Duration.zero);
    expect(clip.end, const Duration(seconds: 13));
  });

  test('final CUE track runs from its start to EOF', () {
    final original = AudioSource.uri(Uri.file('/music/album.flac'));
    final clipped =
        clipPlaybackSource(song(start: 13000), original) as ClippingAudioSource;

    expect(clipped.start, const Duration(seconds: 13));
    expect(clipped.end, isNull);
  });

  test('ordinary files keep the original unclipped source', () {
    final original = AudioSource.uri(Uri.file('/music/album.flac'));
    expect(clipPlaybackSource(song(), original), same(original));
  });

  test('shared paths do not identify adjacent CUE tracks', () {
    final first = song(start: 0, end: 13000);
    final second = song(start: 13000, end: 31000);
    final incoming = source(start: 13, end: 31);

    expect(matchesPlaybackSource(first, first.filePath, incoming), isFalse);
    expect(matchesPlaybackSource(second, second.filePath, incoming), isTrue);
    expect(
      matchesPlaybackSource(first, first.filePath, source(end: 13)),
      isTrue,
    );
    expect(matchesPlaybackSource(first, first.filePath, source()), isFalse);
    expect(matchesPlaybackSource(song(), first.filePath, source()), isTrue);
  });

  test('matching includes an open end and the resolved path', () {
    final finalTrack = song(start: 31000);
    expect(
      matchesPlaybackSource(finalTrack, finalTrack.filePath, source(start: 31)),
      isTrue,
    );
    expect(
      matchesPlaybackSource(
        finalTrack,
        finalTrack.filePath,
        source(start: 31, end: 60),
      ),
      isFalse,
    );
    expect(
      matchesPlaybackSource(finalTrack, '/other.flac', source(start: 31)),
      isFalse,
    );
    expect(matchesPlaybackSource(finalTrack, null, source(start: 31)), isFalse);
    expect(
      matchesPlaybackSource(finalTrack, finalTrack.filePath, null),
      isFalse,
    );
  });
}
