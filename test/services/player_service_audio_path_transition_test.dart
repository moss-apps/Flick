import 'package:flutter_test/flutter_test.dart';
import 'package:flick/models/audio_engine_type.dart';
import 'package:flick/models/audio_output_diagnostics.dart';
import 'package:flick/services/player_service.dart';

AudioOutputDiagnostics _diagnostics({
  AudioEngineType selected = AudioEngineType.usbDacExperimental,
  AudioEngineType? initialized = AudioEngineType.usbDacExperimental,
  AudioPathManagement path = AudioPathManagement.directUsbExperimental,
  String strategy = 'USB direct',
  bool bitPerfect = true,
  bool resampler = false,
  int? requested = 96000,
  int? reported = 96000,
  String? fallback,
  String? verification,
}) {
  return AudioOutputDiagnostics(
    selectedMode: selected,
    initializedMode: initialized,
    detectedDap: false,
    detectedDapBrand: null,
    pathManagement: path,
    outputStrategyLabel: strategy,
    capabilityStateLabel: 'Verified USB direct',
    backendDescription: 'Rust engine via libusb direct USB (verified)',
    routeType: 'usb',
    routeLabel: 'USB DAC',
    outputDeviceLabel: 'FiiO JA11',
    isMixerManaged: false,
    audioFocusHeld: true,
    directUsbRegistered: true,
    usbInterfaceClaimed: true,
    usbStreamStable: true,
    trackSampleRate: requested,
    requestedOutputSampleRate: requested,
    reportedOutputSampleRate: reported,
    resamplerActive: resampler,
    passthroughAllowed: bitPerfect,
    activeOutputSignature: 'android-uac2:1.2',
    verificationReason: verification,
    fallbackReason: fallback,
    capabilityFlags: AudioCapabilityFlags(
      supportsExclusiveUsbOwnership: true,
      supportsDirectSampleRateSwitching: true,
      supportsVerifiedBitPerfect: bitPerfect,
      supportsAndroidManagedHighResOnly: false,
      supportsInternalDapPathOnly: false,
    ),
  );
}

void main() {
  group('audioPathTransitionFields', () {
    test('captures engine, path, bit-perfect and rates', () {
      final fields = audioPathTransitionFields(_diagnostics());
      expect(fields['engine'], AudioEngineType.usbDacExperimental.logLabel);
      expect(fields['path'], 'directUsbExperimental');
      expect(fields['bitPerfect'], 'on');
      expect(fields['requested'], '96000');
      expect(fields['reported'], '96000');
      expect(fields['fallback'], 'none');
    });

    test('falls back to selected mode and reports lost verification', () {
      final fields = audioPathTransitionFields(
        _diagnostics(
          selected: AudioEngineType.normalAndroid,
          initialized: null,
          path: AudioPathManagement.androidManagedShared,
          strategy: 'Android shared',
          bitPerfect: false,
          requested: null,
          reported: null,
          fallback: 'USB DAC_EXPERIMENTAL -> NORMAL_ANDROID: clock lost',
          verification: 'Direct USB verification failed',
        ),
      );
      expect(fields['engine'], AudioEngineType.normalAndroid.logLabel);
      expect(fields['bitPerfect'], 'off');
      expect(fields['requested'], 'none');
      expect(
        fields['fallback'],
        'USB DAC_EXPERIMENTAL -> NORMAL_ANDROID: clock lost',
      );
      expect(fields['verification'], 'Direct USB verification failed');
    });
  });

  group('audioPathTransitionChanges', () {
    test('returns nothing for the first snapshot', () {
      expect(audioPathTransitionChanges(null, {'path': 'a'}), isEmpty);
    });

    test('returns nothing when the snapshot is unchanged', () {
      final fields = audioPathTransitionFields(_diagnostics());
      expect(audioPathTransitionChanges(fields, fields), isEmpty);
    });

    test('reports each changed field with old and new values', () {
      final before = audioPathTransitionFields(_diagnostics());
      final after = audioPathTransitionFields(
        _diagnostics(bitPerfect: false, fallback: 'direct USB refused'),
      );
      final changes = audioPathTransitionChanges(before, after);
      expect(changes, contains('bitPerfect: on -> off'));
      expect(changes, contains('fallback: none -> direct USB refused'));
    });

    test('handles a field with no previous entry', () {
      final changes = audioPathTransitionChanges(
        {'engine': 'USB DAC'},
        {'engine': 'USB DAC', 'extra': '1'},
      );
      expect(changes, ['extra: none -> 1']);
    });
  });

  group('shouldLogAudioPathTransition', () {
    test('allows while under the per-window cap', () {
      expect(
        shouldLogAudioPathTransition(
          logsInWindow: 29,
          windowAge: const Duration(seconds: 10),
        ),
        isTrue,
      );
    });

    test('blocks once the cap is reached inside the window', () {
      expect(
        shouldLogAudioPathTransition(
          logsInWindow: 30,
          windowAge: const Duration(seconds: 59),
        ),
        isFalse,
      );
    });

    test('allows again once the window elapses', () {
      expect(
        shouldLogAudioPathTransition(
          logsInWindow: 30,
          windowAge: const Duration(minutes: 1),
        ),
        isTrue,
      );
    });
  });
}
