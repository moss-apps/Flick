import 'package:flick/features/player/widgets/bit_perfect_indicator.dart';
import 'package:flick/l10n/english_l10n.dart';
import 'package:flick/models/album_color_mode.dart';
import 'package:flick/models/audio_engine_type.dart';
import 'package:flick/models/audio_output_diagnostics.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/services/app_preferences_service.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/visualizer_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _song = Song(
  id: 'track',
  title: 'Track',
  artist: 'Artist',
  duration: Duration(minutes: 3),
  fileType: 'FLAC',
  sampleRate: 96000,
  bitDepth: 24,
);

AudioOutputDiagnostics _diagnostics({
  required bool direct,
  required bool verified,
  int? requestedRate = 96000,
  int? reportedRate,
}) {
  final mode = direct
      ? AudioEngineType.usbDacExperimental
      : AudioEngineType.normalAndroid;
  final strategy = direct ? 'Direct USB' : 'Android shared';
  return AudioOutputDiagnostics(
    selectedMode: mode,
    initializedMode: mode,
    detectedDap: false,
    detectedDapBrand: null,
    pathManagement: direct
        ? AudioPathManagement.directUsbExperimental
        : AudioPathManagement.androidManagedShared,
    outputStrategyLabel: strategy,
    capabilityStateLabel: strategy,
    backendDescription: direct ? 'Rust engine' : 'just_audio / ExoPlayer',
    routeType: 'usb',
    routeLabel: 'USB DAC',
    outputDeviceLabel: 'DAC',
    isMixerManaged: !direct,
    audioFocusHeld: true,
    directUsbRegistered: direct,
    usbInterfaceClaimed: direct,
    usbStreamStable: verified,
    trackSampleRate: 96000,
    requestedOutputSampleRate: requestedRate,
    reportedOutputSampleRate: reportedRate,
    resamplerActive: false,
    passthroughAllowed: verified,
    activeOutputSignature: null,
    verificationReason: null,
    fallbackReason: direct ? null : 'USB transfer timed out',
    capabilityFlags: AudioCapabilityFlags(
      supportsExclusiveUsbOwnership: direct,
      supportsDirectSampleRateSwitching: direct,
      supportsVerifiedBitPerfect: verified,
      supportsAndroidManagedHighResOnly: false,
      supportsInternalDapPathOnly: false,
    ),
  );
}

final _verifiedUsb = _diagnostics(
  direct: true,
  verified: true,
  reportedRate: 96000,
);
final _pendingUsb = _diagnostics(direct: true, verified: false);
final _androidShared = _diagnostics(direct: false, verified: false);

class _FakePlayer extends Fake implements PlayerService {
  @override
  final currentSongNotifier = ValueNotifier<Song?>(_song);
  @override
  final isPlayingNotifier = ValueNotifier(false);
  @override
  final positionNotifier = ValueNotifier(Duration.zero);
  @override
  final volumeTierNotifier = ValueNotifier(VolumeTier.system);
  @override
  final audioOutputDiagnosticsNotifier = ValueNotifier<AudioOutputDiagnostics?>(
    _verifiedUsb,
  );
}

class _TestPreferences extends AppPreferencesNotifier {
  @override
  AppPreferences build() => const AppPreferences(visualizerEnabled: false);
}

class _TestAlbumColorMode extends AlbumColorModeNotifier {
  @override
  AlbumColorMode build() => AlbumColorMode.off;
}

class _SilentVisualizer extends VisualizerSource {
  @override
  VisualizerSourceMode get mode => VisualizerSourceMode.unavailable;
  @override
  List<double>? get bars => null;
  @override
  bool get isAvailable => false;
  @override
  bool get needsPermission => false;
  @override
  Future<bool> prepare() async => false;
  @override
  void acquire() {}
  @override
  void release() {}
}

Future<_FakePlayer> _openSheet(WidgetTester tester) async {
  final player = _FakePlayer();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(411, 960);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playerServiceProvider.overrideWithValue(player),
        appPreferencesProvider.overrideWith(_TestPreferences.new),
        albumColorModeProvider.overrideWith(_TestAlbumColorMode.new),
        albumDominantColorSyncProvider.overrideWithValue(null),
        visualizerSourceProvider.overrideWith((ref) => _SilentVisualizer()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => BitPerfectIndicator.showInfoSheet(
                context,
                song: _song,
                diagnostics: _verifiedUsb,
                deviceStatus: null,
                playerService: player,
              ),
              child: const Text('Open sheet'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open sheet'));
  await tester.pumpAndSettle();
  return player;
}

Finder _rowChild(String label, Finder child) {
  final row = find.ancestor(of: find.text(label), matching: find.byType(Row));
  expect(row, findsOneWidget);
  return find.descendant(of: row, matching: child);
}

void main() {
  testWidgets('only the reported rate gets a match indicator after fallback', (
    tester,
  ) async {
    final player = await _openSheet(tester);
    final check = find.byIcon(Icons.check_circle_rounded);
    final rate = find.text(l10n.khz2('96.0'));

    expect(find.text(l10n.bitPerfectVerified).hitTestable(), findsOneWidget);
    expect(_rowChild(l10n.outputRate, rate), findsOneWidget);
    expect(_rowChild(l10n.outputRate, check), findsOneWidget);

    player.audioOutputDiagnosticsNotifier.value = _androidShared;
    await tester.pumpAndSettle();

    expect(find.text(l10n.bitPerfectVerified), findsNothing);
    expect(find.text(l10n.direct), findsNothing);
    expect(find.text(l10n.mixer), findsOneWidget);
    expect(find.text(l10n.outputRate), findsNothing);
    expect(_rowChild(l10n.requestedOutputRate, rate), findsOneWidget);
    expect(_rowChild(l10n.requestedOutputRate, check), findsNothing);

    player.audioOutputDiagnosticsNotifier.value = _diagnostics(
      direct: false,
      verified: false,
      requestedRate: null,
    );
    await tester.pumpAndSettle();

    expect(_rowChild(l10n.outputRate, find.text(l10n.unknown)), findsOneWidget);
    expect(_rowChild(l10n.outputRate, check), findsNothing);
  });

  testWidgets('expanded verification chip follows live diagnostics', (
    tester,
  ) async {
    final player = await _openSheet(tester);
    await tester.tap(find.byIcon(Icons.open_in_full_rounded));
    await tester.pumpAndSettle();
    expect(find.text(l10n.bitPerfect2).hitTestable(), findsOneWidget);

    player.audioOutputDiagnosticsNotifier.value = _pendingUsb;
    await tester.pumpAndSettle();
    expect(find.text(l10n.bitPerfect2), findsNothing);
    expect(find.text(l10n.directUsb).hitTestable(), findsOneWidget);

    player.audioOutputDiagnosticsNotifier.value = _androidShared;
    await tester.pumpAndSettle();
    expect(find.text(l10n.bitPerfect2), findsNothing);
    expect(find.text(l10n.directUsb), findsNothing);
  });
}
