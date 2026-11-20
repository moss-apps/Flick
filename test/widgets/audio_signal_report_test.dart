import 'dart:async';
import 'dart:typed_data';

import 'package:flick/features/player/widgets/audio_signal_report.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/audio_engine_type.dart';
import 'package:flick/models/audio_output_diagnostics.dart';
import 'package:flick/models/song.dart';
import 'package:flick/src/rust/api/audio_analysis.dart';
import 'package:flick/src/rust/frb_generated.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _song = Song(
  id: 'song',
  title: 'Test',
  artist: 'Artist',
  duration: Duration(minutes: 2),
  fileType: 'FLAC',
  sampleRate: 96000,
  bitDepth: 24,
);

class _AnalysisApi implements RustLibApi {
  final jobs = <_AnalysisJob>[];

  @override
  AudioSourceAnalysisJob crateApiAudioAnalysisCreateSourceAudioAnalysisJob() {
    final job = _AnalysisJob();
    jobs.add(job);
    return job;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AnalysisJob implements AudioSourceAnalysisJob {
  final result = Completer<AudioSourceAnalysis>();
  String? path;
  bool cancelled = false;

  @override
  bool isDisposed = false;

  @override
  Future<AudioSourceAnalysis> analyze({required String path}) {
    this.path = path;
    return result.future;
  }

  @override
  void cancel() => cancelled = true;

  @override
  void dispose() => isDisposed = true;

  @override
  double progress() => 0.5;
}

const _flags = AudioCapabilityFlags(
  supportsExclusiveUsbOwnership: true,
  supportsDirectSampleRateSwitching: true,
  supportsVerifiedBitPerfect: true,
  supportsAndroidManagedHighResOnly: false,
  supportsInternalDapPathOnly: false,
);

AudioOutputDiagnostics _diagnostics(UrbTransportInfo? urb) =>
    AudioOutputDiagnostics(
      selectedMode: AudioEngineType.values.first,
      initializedMode: null,
      detectedDap: false,
      detectedDapBrand: null,
      pathManagement: AudioPathManagement.directUsbExperimental,
      outputStrategyLabel: 'Direct USB',
      capabilityStateLabel: 'Ready',
      backendDescription: 'Rust',
      routeType: 'usb',
      routeLabel: 'USB DAC',
      outputDeviceLabel: 'DAC',
      isMixerManaged: false,
      audioFocusHeld: true,
      directUsbRegistered: true,
      usbInterfaceClaimed: true,
      usbStreamStable: true,
      trackSampleRate: 96000,
      requestedOutputSampleRate: 96000,
      reportedOutputSampleRate: 96000,
      resamplerActive: false,
      passthroughAllowed: true,
      activeOutputSignature: null,
      verificationReason: null,
      fallbackReason: null,
      capabilityFlags: _flags,
      urbTransport: urb,
    );

Future<void> _mount(
  WidgetTester tester, {
  required AudioSignalReportPage page,
  Song song = _song,
  AudioOutputDiagnostics? diagnostics,
  bool expanded = true,
  double width = 320,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: expanded ? 480 : 100,
            child: AudioSignalReport(
              song: song,
              diagnostics: diagnostics,
              page: page,
              expanded: expanded,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => LocaleController.instance.bindLocale(const Locale('en')));
  tearDown(() => LocaleController.instance.bindLocale(const Locale('en')));

  testWidgets('source only reports file properties and distinguishes DSD', (
    tester,
  ) async {
    await _mount(tester, page: AudioSignalReportPage.source);
    expect(find.text('FLAC'), findsWidgets);
    expect(find.text('96.0 kHz'), findsOneWidget);
    expect(find.text('24-bit'), findsOneWidget);
    expect(find.text('Sample rate'), findsOneWidget);
    expect(tester.takeException(), isNull);

    const dsd = Song(
      id: 'dsd',
      title: 'DSD',
      artist: 'Artist',
      duration: Duration(minutes: 2),
      fileType: 'DSF',
      sampleRate: 2822400,
    );
    await _mount(tester, page: AudioSignalReportPage.source, song: dsd);
    expect(find.text('DSD bit rate'), findsOneWidget);
    expect(find.text('1-bit DSD'), findsOneWidget);
    expect(find.text('DSF · DSD64'), findsOneWidget);
    expect(find.text('Raw PCM'), findsNothing);
  });

  testWidgets('source analysis can be cancelled and retried', (tester) async {
    const path = '/music/track.flac';
    final api = _AnalysisApi();
    RustLib.initMock(api: api);
    addTearDown(RustLib.dispose);

    await _mount(
      tester,
      page: AudioSignalReportPage.source,
      song: _song.copyWith(filePath: path),
    );
    await tester.scrollUntilVisible(find.text(l10n.analyzeTrack), 120);
    await tester.tap(find.text(l10n.analyzeTrack));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    final first = api.jobs.single;
    expect(first.path, path);
    expect(find.textContaining('50%'), findsOneWidget);

    await tester.tap(find.text(l10n.audioAnalysisCancel));
    await tester.pump();
    expect(first.cancelled, isTrue);
    expect(find.text(l10n.audioAnalysisCancelled), findsOneWidget);
    await tester.tap(find.text(l10n.audioAnalysisRetry));
    await tester.pump();
    expect(api.jobs, hasLength(1));

    final result = AudioSourceAnalysis(
      status: AudioSourceAnalysisStatus.ok,
      fileSizeBytes: BigInt.from(42),
      durationSeconds: 4,
      channelPeakDb: Float64List.fromList([-1.1]),
      channelRmsDb: Float64List.fromList([-4.1]),
      channels: 1,
      truePeakDb: 2.5,
      silent: false,
      clipping: false,
      clippedSamples: BigInt.zero,
    );
    first.result.complete(result);
    await tester.pump();
    expect(first.isDisposed, isTrue);
    expect(api.jobs, hasLength(2));
    expect(find.text(l10n.audioAnalysisTruePeak), findsNothing);

    final retry = api.jobs.last;
    expect(retry.path, path);
    retry.result.complete(result);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(l10n.audioAnalysisTruePeak),
      150,
      scrollable: find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('+2.5 dBTP'), findsOneWidget);
    expect(retry.isDisposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('USB unavailable and snapshot values never invent measurements', (
    tester,
  ) async {
    await _mount(tester, page: AudioSignalReportPage.urb, expanded: false);
    expect(find.text('USB transport details unavailable'), findsOneWidget);
    expect(find.text('No URB data'), findsOneWidget);

    await _mount(
      tester,
      page: AudioSignalReportPage.urb,
      diagnostics: _diagnostics(
        const UrbTransportInfo(
          activeEndpointAddress: 1,
          transportFormat: 'PCM',
          activeMaxPacketBytes: 512,
          bufferFillMs: 7,
          bufferTargetMs: 10,
          bufferCapacityMs: 20,
          underrunCount: 0,
        ),
      ),
    );
    expect(find.textContaining('not a live packet trace'), findsOneWidget);
    expect(find.text('0x01'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Max packet'), 180);
    expect(find.text('512 B'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Buffer fill'), 180);
    expect(find.text('7 ms'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Buffer occupancy at open'), 180);
    expect(find.text('Buffer occupancy at open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chinese copy renders and compact pages fit narrow screens', (
    tester,
  ) async {
    LocaleController.instance.bindLocale(const Locale('zh', 'CN'));
    await _mount(tester, page: AudioSignalReportPage.source, width: 280);
    expect(find.text(l10n.signalSourceDescription), findsOneWidget);
    expect(
      find.text(
        'Properties of the source file, not the output sent to the device.',
      ),
      findsNothing,
    );
    for (final page in AudioSignalReportPage.values) {
      await _mount(tester, page: page, expanded: false, width: 280);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('URB missing buffer values do not produce an occupancy meter', (
    tester,
  ) async {
    await _mount(
      tester,
      page: AudioSignalReportPage.urb,
      diagnostics: _diagnostics(const UrbTransportInfo()),
    );
    expect(find.text('Not reported'), findsWidgets);
    expect(find.text('Buffer occupancy at open'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'recorded distinguishes missing, matching and mismatched rip evidence',
    (tester) async {
      await _mount(
        tester,
        page: AudioSignalReportPage.recorded,
        expanded: false,
      );
      expect(find.text('No rip data'), findsOneWidget);
      await _mount(
        tester,
        page: AudioSignalReportPage.recorded,
        song: _song.copyWith(ripper: '   '),
        expanded: false,
      );
      expect(find.text('No rip data'), findsOneWidget);

      final matching = _song.copyWith(
        testCrc: 'aBcD',
        copyCrc: 'ABCD',
        accurateRip: true,
      );
      await _mount(
        tester,
        page: AudioSignalReportPage.recorded,
        song: matching,
      );
      await tester.scrollUntilVisible(find.text('AccurateRip'), 180);
      expect(find.text('Match'), findsOneWidget);
      expect(find.text('Verified in log'), findsOneWidget);

      final mismatched = _song.copyWith(
        testCrc: 'ABCD',
        copyCrc: '1234',
        accurateRip: false,
      );
      await _mount(
        tester,
        page: AudioSignalReportPage.recorded,
        song: mismatched,
      );
      expect(find.text('Mismatch'), findsOneWidget);
      expect(find.text('Not verified'), findsOneWidget);

      final incomplete = _song.copyWith(testCrc: 'ABCD');
      await _mount(
        tester,
        page: AudioSignalReportPage.recorded,
        song: incomplete,
      );
      expect(find.text('Cannot compare'), findsOneWidget);
      expect(find.text('Not reported'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
