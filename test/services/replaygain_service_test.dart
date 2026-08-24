import 'dart:math' as math;

import 'package:flick/models/song.dart';
import 'package:flick/services/replaygain_service.dart';
import 'package:flutter_test/flutter_test.dart';

Song _song({
  double? trackGain,
  double? trackPeak,
  double? albumGain,
  double? albumPeak,
}) {
  return Song(
    id: '1',
    title: 't',
    artist: 'a',
    duration: const Duration(seconds: 60),
    fileType: 'FLAC',
    replaygainTrackGain: trackGain,
    replaygainTrackPeak: trackPeak,
    replaygainAlbumGain: albumGain,
    replaygainAlbumPeak: albumPeak,
  );
}

void main() {
  group('computeReplayGainDbForSong', () {
    test('mode off always returns 0', () {
      final s = _song(trackGain: 5.0);
      expect(
        computeReplayGainDbForSong(
          s,
          mode: ReplayGainMode.off,
          preampDb: 0,
          preventClipping: true,
        ),
        0.0,
      );
    });

    test('null song returns 0', () {
      expect(
        computeReplayGainDbForSong(
          null,
          mode: ReplayGainMode.track,
          preampDb: 0,
          preventClipping: true,
        ),
        0.0,
      );
    });

    test('track mode adds preamp', () {
      final s = _song(trackGain: 5.0);
      expect(
        computeReplayGainDbForSong(
          s,
          mode: ReplayGainMode.track,
          preampDb: 2.0,
          preventClipping: false,
        ),
        7.0,
      );
    });

    test('missing track tags yields 0', () {
      final s = _song();
      expect(
        computeReplayGainDbForSong(
          s,
          mode: ReplayGainMode.track,
          preampDb: 0,
          preventClipping: true,
        ),
        0.0,
      );
    });

    test('album mode falls back to track gain/peak', () {
      final s = _song(trackGain: 4.0, trackPeak: 0.9);
      expect(
        computeReplayGainDbForSong(
          s,
          mode: ReplayGainMode.album,
          preampDb: 0,
          preventClipping: false,
        ),
        4.0,
      );
    });

    test('clipping prevention caps positive gain at the peak', () {
      // Peak 0.5 = -6.02 dBFS -> max gain is +6.02 dB.
      final s = _song(trackGain: 10.0, trackPeak: 0.5);
      final gain = computeReplayGainDbForSong(
        s,
        mode: ReplayGainMode.track,
        preampDb: 0,
        preventClipping: true,
      );
      expect(gain, closeTo(6.0206, 0.001));
    });

    test('negative gain is never capped', () {
      final s = _song(trackGain: -10.0, trackPeak: 0.999);
      expect(
        computeReplayGainDbForSong(
          s,
          mode: ReplayGainMode.track,
          preampDb: -2.0,
          preventClipping: true,
        ),
        -12.0,
      );
    });

    test('clipping cap never raises above peak-limited max with preamp', () {
      // 8 dB total stays below the 0.25-peak cap (12 dB) — gain untouched.
      final s = _song(trackGain: 3.0, trackPeak: 0.25);
      final gain = computeReplayGainDbForSong(
        s,
        mode: ReplayGainMode.track,
        preampDb: 5.0,
        preventClipping: true,
      );
      expect(gain, closeTo(8.0, 0.001));
    });

    test('clipping cap applies when total exceeds the peak limit', () {
      // Peak 0.25 = -12 dBFS; preamp 5 + gain 12 = 17 dB total -> capped at 12.
      final s = _song(trackGain: 12.0, trackPeak: 0.25);
      final gain = computeReplayGainDbForSong(
        s,
        mode: ReplayGainMode.track,
        preampDb: 5.0,
        preventClipping: true,
      );
      expect(gain, closeTo(12.0412, 0.001));
    });

    test('album gain used when album mode', () {
      final s = _song(
        trackGain: 2.0,
        trackPeak: 0.99,
        albumGain: -3.0,
        albumPeak: 0.9,
      );
      expect(
        computeReplayGainDbForSong(
          s,
          mode: ReplayGainMode.album,
          preampDb: 0,
          preventClipping: false,
        ),
        -3.0,
      );
    });
  });

  group('db/linear conversion', () {
    test('round trip', () {
      for (final db in [-12.0, -6.0, 0.0, 3.0, 12.0]) {
        expect(replayGainLinearToDb(replayGainDbToLinear(db)), closeTo(db, 1e-9));
      }
    });

    test('identity at 0 dB', () {
      expect(replayGainDbToLinear(0), 1.0);
    });

    test('+6.02 dB doubles', () {
      expect(replayGainDbToLinear(6.0206), closeTo(2.0, 1e-3));
    });

    test('linearToDb of 0 is -60', () {
      expect(replayGainLinearToDb(0), -60.0);
    });

    test('peak cap = -20log10(peak)', () {
      final peak = 0.5;
      final expected = -20 * math.log(peak) / math.ln10;
      final gain = computeReplayGainDbForSong(
        _song(trackGain: 50.0, trackPeak: peak),
        mode: ReplayGainMode.track,
        preampDb: 0,
        preventClipping: true,
      );
      expect(gain, closeTo(expected, 1e-6));
    });
  });
}
