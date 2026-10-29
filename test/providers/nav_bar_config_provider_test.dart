import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flick/models/nav_bar_config.dart';
import 'package:flick/providers/nav_bar_config_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reset during startup wins over saved navigation settings', () async {
    SharedPreferences.setMockInitialValues({
      'nav_bar_buttons': 'albums,settings',
      'nav_bar_hidden': 'songs',
      'nav_bar_size': 1.3,
      'nav_bar_show_labels': false,
      'nav_bar_width_fraction': 0.8,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(navBarConfigProvider.notifier).reset();
    expect(
      container.read(navBarConfigProvider),
      same(NavBarConfig.defaultConfig),
    );

    final reloaded = ProviderContainer();
    addTearDown(reloaded.dispose);
    reloaded.read(navBarConfigProvider);
    await Future<void>.delayed(Duration.zero);
    final restored = reloaded.read(navBarConfigProvider);
    expect(restored.enabledButtons, NavBarConfig.defaultConfig.enabledButtons);
    expect(restored.hidden, isEmpty);
    expect(restored.barSizeFactor, 1);
    expect(restored.buttonSpacingFactor, 1);
    expect(restored.iconSizeFactor, 1);
    expect(restored.showLabels, isTrue);
    expect(restored.widthFraction, 1);
  });

  test(
    'saved bar width is restored and clamped to the supported range',
    () async {
      SharedPreferences.setMockInitialValues({'nav_bar_width_fraction': 0.4});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(navBarConfigProvider);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(navBarConfigProvider).widthFraction, 0.7);

      await container.read(navBarConfigProvider.notifier).setWidthFraction(1.4);
      expect(container.read(navBarConfigProvider).widthFraction, 1);
    },
  );
}
