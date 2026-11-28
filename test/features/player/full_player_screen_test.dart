import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flick/core/utils/navigation_helper.dart';
import 'package:flick/data/database.dart';
import 'package:flick/features/player/screens/full_player_screen.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/player_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      final home = GlobalKey();
      try {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              navigatorKey: navigator,
              locale: kFallbackLocale,
              localizationsDelegates: kAppLocalizationsDelegates,
              home: SizedBox.shrink(key: home),
            ),
          ),
        );

        for (var opening = 0; opening < 2; opening++) {
          unawaited(
            NavigationHelper.navigateToFullPlayer(
              home.currentContext!,
              heroTag: 'widget_now_playing',
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Selected track'), findsAtLeastNWidgets(1));
          final playerState = tester.state(find.byType(FullPlayerScreen));
          unawaited(
            navigator.currentState!.push<void>(
              MaterialPageRoute(
                builder: (_) => const SizedBox(key: Key('queue')),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('queue')), findsOneWidget);
          await NavigationHelper.navigateToFullPlayer(
            home.currentContext!,
            heroTag: 'widget_now_playing',
            revealExisting: true,
          );
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('queue')), findsNothing);
          expect(
            tester.state(find.byType(FullPlayerScreen)),
            same(playerState),
          );
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
