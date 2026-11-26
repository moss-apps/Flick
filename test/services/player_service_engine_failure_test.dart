import 'package:flutter_test/flutter_test.dart';
import 'package:flick/services/player_service.dart';

void main() {
  group('isDeadRustEngineError', () {
    test('matches direct backend output loss', () {
      expect(
        isDeadRustEngineError(
          'Audio engine output lost: DSD ALSA write failed (EPIPE)',
        ),
        isTrue,
      );
    });

    test('matches managed Oboe callback failure with silenced output', () {
      expect(
        isDeadRustEngineError(
          'Audio engine output lost: Android managed output callback failure: '
          'output burst of 4096 frames exceeds scratch capacity of 16384 '
          'frames (output silenced)',
        ),
        isTrue,
      );
    });

    test('matches the legacy crash markers', () {
      expect(isDeadRustEngineError('Rust audio engine thread crashed'), isTrue);
      expect(isDeadRustEngineError('disconnected channel'), isTrue);
    });

    test('ignores unrelated playback errors', () {
      expect(isDeadRustEngineError('USB DAC disconnected'), isFalse);
      expect(isDeadRustEngineError('unsupported audio format'), isFalse);
    });
  });

  group('shouldForceRustEngineFallback', () {
    final now = DateTime(2026, 9, 30, 12, 0, 0);

    test('does not force fallback for the first failure', () {
      expect(
        shouldForceRustEngineFallback(
          recoveryTimestamps: <DateTime>[now],
          now: now,
        ),
        isFalse,
      );
    });

    test('forces fallback for a second failure inside the window', () {
      expect(
        shouldForceRustEngineFallback(
          recoveryTimestamps: <DateTime>[
            now.subtract(const Duration(seconds: 30)),
            now,
          ],
          now: now,
        ),
        isTrue,
      );
    });

    test('ignores failures older than the window', () {
      expect(
        shouldForceRustEngineFallback(
          recoveryTimestamps: <DateTime>[
            now.subtract(
              deadRustEngineRecoveryWindow + const Duration(seconds: 1),
            ),
            now,
          ],
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('shouldStopForRustOnlyContainer', () {
    test('stops when the engine is dead and ExoPlayer cannot decode', () {
      expect(
        shouldStopForRustOnlyContainer(
          revived: false,
          requiresRustDecoder: true,
        ),
        isTrue,
      );
    });

    test('keeps the ExoPlayer fallback for system-decodable tracks', () {
      expect(
        shouldStopForRustOnlyContainer(
          revived: false,
          requiresRustDecoder: false,
        ),
        isFalse,
      );
    });

    test('replays on the Rust engine after a successful respawn', () {
      expect(
        shouldStopForRustOnlyContainer(
          revived: true,
          requiresRustDecoder: true,
        ),
        isFalse,
      );
      expect(
        shouldStopForRustOnlyContainer(
          revived: true,
          requiresRustDecoder: false,
        ),
        isFalse,
      );
    });
  });
}
