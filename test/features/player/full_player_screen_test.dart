import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flick/app/app.dart';
import 'package:flick/data/database.dart';
import 'package:flick/features/player/screens/full_player_screen.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/connectivity_provider.dart';
import 'package:flick/providers/equalizer_provider.dart';
import 'package:flick/providers/onboarding_provider.dart';
import 'package:flick/services/player_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestEqualizer extends EqualizerNotifier {
  @override
  EqualizerState build() => EqualizerState.initial();
}

class _CompletedOnboarding extends OnboardingCompletedNotifier {
  @override
  bool build() => true;
}

class _OfflineConnectivity extends ConnectivityNotifier {
  @override
  ConnectivityStatus build() => ConnectivityStatus.offline;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  Directory? databaseDirectory;

  setUpAll(() async {
    await Isar.initializeIsarCore(libraries: {Abi.current(): _isarCorePath()});
    final directory = await Directory.systemTemp.createTemp('flick_player_ui');
    databaseDirectory = directory;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProvider,
      (_) async => directory.path,
    );
    await Database.init();
  });

  tearDownAll(() async {
    await Database.close();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(pathProvider, null);
    await databaseDirectory?.delete(recursive: true);
  });

  testWidgets('main shell opens the library without a provider error', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'nav_bar_buttons': 'menu,equalizer,songs,settings,search',
      'streak_popup_snoozed_until': 99991231,
    });
    const homeWidget = MethodChannel('home_widget');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(homeWidget, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(homeWidget, null));
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectivityProvider.overrideWith(_OfflineConnectivity.new),
            equalizerProvider.overrideWith(_TestEqualizer.new),
            onboardingCompletedProvider.overrideWith(_CompletedOnboarding.new),
          ],
          child: const FlickPlayerApp(),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Your Library'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('full player reopens with the current song selected', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    // Allow the real library reads started by the player to finish.
    await tester.runAsync(() async {
      final player = PlayerService();
      player.currentSongNotifier.value = const Song(
        id: 'selected-song',
        title: 'Selected track',
        artist: 'Test artist',
        duration: Duration(minutes: 3),
        fileType: 'FLAC',
      );
      final navigator = GlobalKey<NavigatorState>();
      try {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              navigatorKey: navigator,
              locale: kFallbackLocale,
              localizationsDelegates: kAppLocalizationsDelegates,
              home: const SizedBox.shrink(),
            ),
          ),
        );

        for (var opening = 0; opening < 2; opening++) {
          unawaited(
            navigator.currentState!.push<void>(
              MaterialPageRoute(builder: (_) => const FullPlayerScreen()),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Selected track'), findsAtLeastNWidgets(1));
          navigator.currentState!.pop();
          await tester.pumpAndSettle();
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        player.currentSongNotifier.value = null;
      }
    });
  });
}

String _isarCorePath() {
  final override = Platform.environment['ISAR_CORE_LIB'];
  if (override != null) return override;

  final library = switch (Abi.current()) {
    Abi.linuxX64 => 'linux/libisar.so',
    Abi.macosX64 || Abi.macosArm64 => 'macos/libisar.dylib',
    Abi.windowsX64 => 'windows/libisar.dll',
    _ => throw UnsupportedError('Set ISAR_CORE_LIB for ${Abi.current()}'),
  };
  final config = File('.dart_tool/package_config.json').absolute;
  final packages = jsonDecode(config.readAsStringSync())['packages'] as List;
  final isarPackage = packages.firstWhere(
    (package) => package['name'] == 'isar_community_flutter_libs',
  );
  final packageRoot = Directory.fromUri(
    config.uri.resolve(isarPackage['rootUri'] as String),
  );
  return packageRoot.uri.resolve(library).toFilePath();
}
