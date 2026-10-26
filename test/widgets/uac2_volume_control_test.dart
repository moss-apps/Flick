import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/features/player/widgets/volume_bottom_sheet.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/providers/player_provider.dart';
import 'package:flick/providers/uac2_provider.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/uac2_service.dart';
import 'package:flick/widgets/uac2/iso_volume_popup.dart';
import 'package:flick/widgets/uac2/uac2_volume_control.dart';

const _device = Uac2DeviceInfo(
  vendorId: 1,
  productId: 2,
  productName: 'Test USB DAC',
  manufacturer: 'Test',
  deviceName: '/dev/bus/usb/001/002',
);

Uac2DeviceStatus _status({
  bool hardware = false,
  bool? muted,
  double volume = 0.13,
}) => Uac2DeviceStatus(
  device: _device,
  state: Uac2State.streaming,
  routeType: Uac2RouteType.externalUsb,
  routeLabel: 'Test USB DAC',
  isExternalRoute: true,
  volumeMode: hardware ? Uac2VolumeMode.hardware : Uac2VolumeMode.unavailable,
  hasVolumeControl: hardware,
  volumeControlWritable: hardware,
  volume: hardware ? volume : null,
  muted: muted,
);

class _TestPlayer extends Fake implements PlayerService {
  _TestPlayer(VolumeTier tier) : volumeTierNotifier = ValueNotifier(tier);

  @override
  final ValueNotifier<VolumeTier> volumeTierNotifier;

  @override
  double currentVolume = 0.13;

  @override
  double get maxVolume => 1.0;

  @override
  bool get isHardwareVolumeAuthority =>
      volumeTierNotifier.value == VolumeTier.hardware;

  final writes = <double>[];
  bool acceptWrites = true;

  @override
  Future<void> setVolume(double volume) async {
    writes.add(volume);
    if (acceptWrites) currentVolume = volume;
  }
}

class _TestStatus extends Uac2DeviceStatusNotifier {
  _TestStatus(this.initial);

  final Uac2DeviceStatus initial;
  final muteWrites = <bool>[];

  @override
  Uac2DeviceStatus build() => initial;

  @override
  Future<bool> setMute(bool muted) async {
    muteWrites.add(muted);
    state = state!.copyWith(muted: muted);
    return true;
  }
}

Future<void> _pumpControl(
  WidgetTester tester, {
  required _TestPlayer player,
  required _TestStatus status,
  bool popup = false,
  double textScale = 1.0,
}) async {
  final buttonKey = GlobalKey();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playerServiceProvider.overrideWithValue(player),
        uac2DeviceStatusProvider.overrideWith(() => status),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData.fromView(
              tester.view,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: popup
                ? Builder(
                    builder: (context) => Align(
                      alignment: Alignment.bottomCenter,
                      child: TextButton(
                        key: buttonKey,
                        onPressed: () => showIsoVolumePopup(context, buttonKey),
                        child: const Text('Open volume'),
                      ),
                    ),
                  )
                : const SingleChildScrollView(child: Uac2VolumeControl()),
          ),
        ),
      ),
    ),
  );
  if (popup) {
    await tester.tap(find.text('Open volume'));
    await tester.pumpAndSettle();
  }
}

void main() {
  for (final popup in [false, true]) {
    final surface = popup ? 'popup' : 'inline';

    testWidgets(
      '$surface fixed output does not display stale app attenuation',
      (tester) async {
        final player = _TestPlayer(VolumeTier.unavailable);
        addTearDown(player.volumeTierNotifier.dispose);
        await _pumpControl(
          tester,
          player: player,
          status: _TestStatus(_status()),
          popup: popup,
        );

        final slider = tester.widget<Slider>(find.byType(Slider));
        expect(slider.onChanged, isNull);
        expect(slider.label, l10n.unavailable2);
        expect(find.text('—'), findsOneWidget);
        expect(find.textContaining('13%'), findsNothing);
        expect(find.textContaining('-52.2'), findsNothing);
        expect(
          tester.widget<IconButton>(find.byType(IconButton)).onPressed,
          isNull,
        );
        if (!popup) {
          expect(find.text(l10n.volumeIsFixedWhileBitPerfect2), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$surface DSP volume works without native USB controls', (
      tester,
    ) async {
      final player = _TestPlayer(VolumeTier.software);
      final status = _TestStatus(_status());
      addTearDown(player.volumeTierNotifier.dispose);
      await _pumpControl(tester, player: player, status: status, popup: popup);

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.onChanged, isNotNull);
      slider.onChangeEnd!(0.4);
      await tester.pumpAndSettle();
      expect(player.writes, [0.4]);

      await tester.tap(find.byTooltip(l10n.mute));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l10n.unmute));
      await tester.pumpAndSettle();
      expect(player.writes, [0.4, 0.0, 0.4]);
      expect(status.muteWrites, isEmpty);
    });

    testWidgets('$surface unknown hardware mute does not disable volume', (
      tester,
    ) async {
      final player = _TestPlayer(VolumeTier.hardware);
      addTearDown(player.volumeTierNotifier.dispose);
      await _pumpControl(
        tester,
        player: player,
        status: _TestStatus(_status(hardware: true, volume: 0.4)),
        popup: popup,
      );

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.onChanged, isNotNull);
      expect(slider.value, 0.4);
      expect(slider.label, '40%');
      expect(find.text('40%'), findsOneWidget);
      expect(find.textContaining('dB'), findsNothing);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
    });

    testWidgets('$surface hardware mute preserves the independent DAC level', (
      tester,
    ) async {
      final player = _TestPlayer(VolumeTier.hardware);
      final status = _TestStatus(_status(hardware: true, muted: false));
      addTearDown(player.volumeTierNotifier.dispose);
      await _pumpControl(tester, player: player, status: status, popup: popup);

      await tester.tap(find.byTooltip(l10n.mute));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l10n.unmute));
      await tester.pumpAndSettle();
      expect(status.muteWrites, [true, false]);
      expect(player.writes, isEmpty);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 0.13);
    });

    testWidgets(
      '$surface ignored hardware volume write cannot unmute the DAC',
      (tester) async {
        final player = _TestPlayer(VolumeTier.hardware)..acceptWrites = false;
        final status = _TestStatus(_status(hardware: true, muted: true));
        addTearDown(player.volumeTierNotifier.dispose);
        await _pumpControl(
          tester,
          player: player,
          status: status,
          popup: popup,
        );

        tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(0.8);
        await tester.pumpAndSettle();
        expect(player.writes, [0.8]);
        expect(status.muteWrites, isEmpty);
        expect(tester.widget<Slider>(find.byType(Slider)).value, 0.13);
        expect(find.byTooltip(l10n.unmute), findsOneWidget);
      },
    );

    testWidgets('$surface reacts when hardware authority fails or recovers', (
      tester,
    ) async {
      final player = _TestPlayer(VolumeTier.hardware);
      addTearDown(player.volumeTierNotifier.dispose);
      await _pumpControl(
        tester,
        player: player,
        status: _TestStatus(_status(hardware: true, muted: false)),
        popup: popup,
      );

      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNotNull);
      player.volumeTierNotifier.value = VolumeTier.unavailable;
      await tester.pump();
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
      expect(find.text('—'), findsOneWidget);
      player.volumeTierNotifier.value = VolumeTier.hardware;
      await tester.pump();
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNotNull);
      expect(find.text('13%'), findsOneWidget);
    });
  }

  testWidgets('fixed output fits a narrow screen with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final player = _TestPlayer(VolumeTier.unavailable);
    addTearDown(player.volumeTierNotifier.dispose);
    await _pumpControl(
      tester,
      player: player,
      status: _TestStatus(_status()),
      textScale: 2.0,
    );
    expect(find.text(l10n.volumeIsFixedWhileBitPerfect2), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Taglish fixed-volume notice is English', (tester) async {
    addTearDown(() => LocaleController.instance.bindLocale(kFallbackLocale));
    final player = _TestPlayer(VolumeTier.unavailable);
    addTearDown(player.volumeTierNotifier.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerServiceProvider.overrideWithValue(player),
          uac2DeviceStatusProvider.overrideWith(() => _TestStatus(_status())),
        ],
        child: MaterialApp(
          locale: kFilipinoLocale,
          supportedLocales: kSupportedLocales,
          localizationsDelegates: kAppLocalizationsDelegates,
          localeResolutionCallback: resolveAppLocale,
          builder: (context, child) {
            LocaleController.instance.bind(AppLocalizations.of(context));
            return child!;
          },
          home: const Scaffold(
            body: SingleChildScrollView(child: Uac2VolumeControl()),
          ),
        ),
      ),
    );

    final english = lookupFlickLocalizations(kFallbackLocale);
    final taglish = lookupFlickLocalizations(kFilipinoLocale);
    expect(find.text(english.volumeIsFixedWhileBitPerfect2), findsOneWidget);
    expect(find.text(taglish.volumeIsFixedWhileBitPerfect2), findsNothing);
  });

  testWidgets(
    'volume sheet reacts to fixed output and discards failed writes',
    (tester) async {
      final player = _TestPlayer(VolumeTier.software)..acceptWrites = false;
      addTearDown(player.volumeTierNotifier.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: VolumeBottomSheet(playerService: player)),
        ),
      );
      tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(0.8);
      await tester.pump();
      expect(tester.widget<Slider>(find.byType(Slider)).value, 0.13);
      player.volumeTierNotifier.value = VolumeTier.unavailable;
      await tester.pump();
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
      expect(find.text('—'), findsOneWidget);
      expect(find.textContaining('13%'), findsNothing);
    },
  );
}
