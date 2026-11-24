import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/models/album_color_mode.dart';
import 'package:flick/providers/album_color_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('provider starts on vibrant before preferences load', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(albumColorModeProvider), AlbumColorMode.vibrant);

    await pumpEventQueue();
    expect(container.read(albumColorModeProvider), AlbumColorMode.vibrant);
  });

  test('provider upgrades a stored off to vibrant', () async {
    SharedPreferences.setMockInitialValues({'album_color_mode': 'off'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(albumColorModeProvider);
    await pumpEventQueue();

    expect(container.read(albumColorModeProvider), AlbumColorMode.vibrant);
  });

  test('provider keeps a saved subtle choice', () async {
    SharedPreferences.setMockInitialValues({'album_color_mode': 'subtle'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(albumColorModeProvider);
    await pumpEventQueue();

    expect(container.read(albumColorModeProvider), AlbumColorMode.subtle);
  });
}
