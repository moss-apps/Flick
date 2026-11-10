import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/providers/app_preferences_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> newContainer() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(appPreferencesProvider.notifier).loaded;
    return container;
  }

  test(
    'landscape layout keeps the previous landscape render as defaults',
    () async {
      final container = await newContainer();
      final prefs = container.read(appPreferencesProvider);

      expect(prefs.orbitLandscapeRadiusRatio, 1.0);
      expect(prefs.orbitLandscapeCenterYRatio, 0.48);
      expect(prefs.orbitLandscapeItemSpacing, 0.28);
      expect(prefs.orbitLandscapeSelectedScale, 1.25);
      expect(prefs.orbitLandscapeDepth, 0.75);
      expect(prefs.orbitLandscapeVisibleItems, 5);
      expect(prefs.orbitLandscapeCardWidthRatio, 0.68);
      expect(prefs.orbitCardBackgroundStyle, 'black_gradient');
    },
  );

  test('an explicitly chosen background survives the default change', () async {
    SharedPreferences.setMockInitialValues({
      'orbit_card_background_style': 'blur_gradient',
    });

    final container = await newContainer();
    expect(
      container.read(appPreferencesProvider).orbitCardBackgroundStyle,
      'blur_gradient',
    );

    // Loading must not rewrite a stored choice to the new default.
    final stored = await SharedPreferences.getInstance();
    expect(stored.getString('orbit_card_background_style'), 'blur_gradient');
  });

  test('portrait and landscape layouts persist independently', () async {
    final container = await newContainer();
    final notifier = container.read(appPreferencesProvider.notifier);

    await notifier.setOrbitRadiusRatio(0.82);
    await notifier.setOrbitCenterYRatio(0.36);
    await notifier.setOrbitItemSpacing(0.19);
    await notifier.setOrbitSelectedScale(1.4);
    await notifier.setOrbitDepth(0.5);
    await notifier.setOrbitVisibleItems(7);
    await notifier.setOrbitCardWidthRatio(0.58);
    await notifier.setOrbitCardBackgroundStyle('album_color_gradient');

    await notifier.setOrbitLandscapeRadiusRatio(1.36);
    await notifier.setOrbitLandscapeCenterYRatio(0.56);
    await notifier.setOrbitLandscapeItemSpacing(0.41);
    await notifier.setOrbitLandscapeSelectedScale(1.7);
    await notifier.setOrbitLandscapeDepth(0.3);
    await notifier.setOrbitLandscapeVisibleItems(9);
    await notifier.setOrbitLandscapeCardWidthRatio(0.78);

    final restored = await newContainer();
    final prefs = restored.read(appPreferencesProvider);
    expect(prefs.orbitRadiusRatio, 0.82);
    expect(prefs.orbitCenterYRatio, 0.36);
    expect(prefs.orbitItemSpacing, 0.19);
    expect(prefs.orbitSelectedScale, 1.4);
    expect(prefs.orbitDepth, 0.5);
    expect(prefs.orbitVisibleItems, 7);
    expect(prefs.orbitCardWidthRatio, 0.58);
    expect(prefs.orbitCardBackgroundStyle, 'album_color_gradient');
    expect(prefs.orbitLandscapeRadiusRatio, 1.36);
    expect(prefs.orbitLandscapeCenterYRatio, 0.56);
    expect(prefs.orbitLandscapeItemSpacing, 0.41);
    expect(prefs.orbitLandscapeSelectedScale, 1.7);
    expect(prefs.orbitLandscapeDepth, 0.3);
    expect(prefs.orbitLandscapeVisibleItems, 9);
    expect(prefs.orbitLandscapeCardWidthRatio, 0.78);
  });

  test('saved portrait settings do not leak into landscape defaults', () async {
    SharedPreferences.setMockInitialValues({
      'orbit_radius_ratio': 0.74,
      'orbit_center_offset_ratio': -0.8,
      'orbit_center_y_ratio': 0.33,
      'orbit_item_spacing': 0.44,
      'orbit_selected_scale': 1.6,
      'orbit_depth': 0.2,
      'orbit_visible_items': 9,
      'orbit_card_art_size': 96.0,
      'orbit_card_width_ratio': 0.8,
    });

    final container = await newContainer();
    final prefs = container.read(appPreferencesProvider);
    expect(prefs.orbitRadiusRatio, 0.74);
    expect(prefs.orbitCenterYRatio, 0.33);
    expect(prefs.orbitLandscapeRadiusRatio, 1.0);
    expect(prefs.orbitLandscapeCenterYRatio, 0.48);
    expect(prefs.orbitLandscapeItemSpacing, 0.28);
    expect(prefs.orbitLandscapeSelectedScale, 1.25);
    expect(prefs.orbitLandscapeDepth, 0.75);
    expect(prefs.orbitLandscapeVisibleItems, 5);
    expect(prefs.orbitLandscapeCardWidthRatio, 0.68);
  });

  test(
    'resetting one layout leaves the other and shared visuals untouched',
    () async {
      final container = await newContainer();
      final notifier = container.read(appPreferencesProvider.notifier);

      await notifier.setOrbitRadiusRatio(0.82);
      await notifier.setOrbitVisibleItems(7);
      await notifier.setOrbitLandscapeRadiusRatio(1.36);
      await notifier.setOrbitLandscapeCenterYRatio(0.56);
      await notifier.setOrbitLandscapeVisibleItems(9);
      await notifier.setOrbitCardBackgroundStyle('black_gradient');
      await notifier.setOrbitArtResolutionMultiplier(3.0);
      await notifier.setOrbitShowPath(false);
      await notifier.setOrbitShowGlow(false);

      await notifier.resetOrbitLayout(landscape: true);

      var prefs = container.read(appPreferencesProvider);
      expect(prefs.orbitLandscapeRadiusRatio, 1.0);
      expect(prefs.orbitLandscapeCenterYRatio, 0.48);
      expect(prefs.orbitLandscapeItemSpacing, 0.28);
      expect(prefs.orbitLandscapeSelectedScale, 1.25);
      expect(prefs.orbitLandscapeDepth, 0.75);
      expect(prefs.orbitLandscapeVisibleItems, 5);
      expect(prefs.orbitLandscapeCardWidthRatio, 0.68);
      expect(prefs.orbitRadiusRatio, 0.82);
      expect(prefs.orbitVisibleItems, 7);
      expect(prefs.orbitCardBackgroundStyle, 'black_gradient');
      expect(prefs.orbitArtResolutionMultiplier, 3.0);
      expect(prefs.orbitShowPath, isFalse);
      expect(prefs.orbitShowGlow, isFalse);

      var stored = await SharedPreferences.getInstance();
      expect(stored.getDouble('orbit_landscape_radius_ratio'), isNull);
      expect(stored.getDouble('orbit_radius_ratio'), 0.82);
      expect(stored.getDouble('orbit_art_resolution_multiplier'), 3.0);
      expect(stored.getBool('orbit_show_path'), isFalse);

      await notifier.resetOrbitLayout(landscape: false);

      prefs = container.read(appPreferencesProvider);
      expect(prefs.orbitRadiusRatio, 1.0);
      expect(prefs.orbitCenterOffsetRatio, -0.5);
      expect(prefs.orbitCenterYRatio, 0.42);
      expect(prefs.orbitItemSpacing, 0.28);
      expect(prefs.orbitSelectedScale, 1.25);
      expect(prefs.orbitDepth, 0.75);
      expect(prefs.orbitVisibleItems, 5);
      expect(prefs.orbitCardArtSize, 64.0);
      expect(prefs.orbitCardWidthRatio, 0.68);
      expect(prefs.orbitCardBackgroundStyle, 'black_gradient');
      expect(prefs.orbitLandscapeRadiusRatio, 1.0);
      expect(prefs.orbitArtResolutionMultiplier, 3.0);

      stored = await SharedPreferences.getInstance();
      expect(stored.getDouble('orbit_radius_ratio'), isNull);
      expect(stored.getDouble('orbit_landscape_radius_ratio'), isNull);
      expect(stored.getString('orbit_card_background_style'), isNull);
      expect(stored.getDouble('orbit_art_resolution_multiplier'), 3.0);
    },
  );
}
