import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/models/album_color_mode.dart';
import 'package:flick/services/album_color_mode_preference_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('new installations default to vibrant and persist it', () async {
    final service = AlbumColorModePreferenceService();

    expect(await service.getMode(), AlbumColorMode.vibrant);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('album_color_mode'), 'vibrant');
  });

  test('an upgrade rewrites a stored off to vibrant', () async {
    SharedPreferences.setMockInitialValues({'album_color_mode': 'off'});

    final service = AlbumColorModePreferenceService();

    expect(await service.getMode(), AlbumColorMode.vibrant);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('album_color_mode'), 'vibrant');
  });

  for (final mode in [
    AlbumColorMode.subtle,
    AlbumColorMode.moderate,
    AlbumColorMode.vibrant,
  ]) {
    test(
      'a stored ${mode.storageValue} choice survives the migration',
      () async {
        SharedPreferences.setMockInitialValues({
          'album_color_mode': mode.storageValue,
        });

        final service = AlbumColorModePreferenceService();
        await service.migrateToVibrantDefault();

        expect(await service.getMode(), mode);
      },
    );
  }

  test('off chosen after the migration survives restarts', () async {
    final service = AlbumColorModePreferenceService();
    await service.migrateToVibrantDefault();
    await service.setMode(AlbumColorMode.off);

    expect(
      await AlbumColorModePreferenceService().getMode(),
      AlbumColorMode.off,
    );
  });

  test('the migration only runs once', () async {
    final service = AlbumColorModePreferenceService();
    await service.migrateToVibrantDefault();
    await service.setMode(AlbumColorMode.off);

    await AlbumColorModePreferenceService().migrateToVibrantDefault();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('album_color_mode'), 'off');
  });
}
