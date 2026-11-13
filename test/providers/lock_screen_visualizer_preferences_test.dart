import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flick/providers/app_preferences_provider.dart';
import 'package:flick/services/app_preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('lock-screen opt-in defaults off and copies independently', () async {
    const defaults = AppPreferences();
    expect(defaults.lockScreenVisualizerEnabled, isFalse);
    expect(
      (await AppPreferencesService().getPreferences())
          .lockScreenVisualizerEnabled,
      isFalse,
    );
    final enabled = defaults.copyWith(
      lockScreenVisualizerEnabled: true,
      visualizerEnabled: false,
    );
    expect(enabled.lockScreenVisualizerEnabled, isTrue);
    expect(enabled.visualizerEnabled, isFalse);
    expect(
      enabled.copyWith(hapticsEnabled: false).lockScreenVisualizerEnabled,
      isTrue,
    );
  });

  test('notifier persists opt-in without changing the in-app flag', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(appPreferencesProvider.notifier);
    await notifier.loaded;
    await notifier.setLockScreenVisualizerEnabled(true);
    expect(
      container.read(appPreferencesProvider).lockScreenVisualizerEnabled,
      isTrue,
    );
    var saved = await AppPreferencesService().getPreferences();
    expect(saved.lockScreenVisualizerEnabled, isTrue);
    expect(saved.visualizerEnabled, isTrue);
    await notifier.setLockScreenVisualizerEnabled(false);
    saved = await AppPreferencesService().getPreferences();
    expect(saved.lockScreenVisualizerEnabled, isFalse);
    expect(saved.visualizerEnabled, isTrue);
  });

  test('simulated AOD defaults off and persists independently', () async {
    const defaults = AppPreferences();
    expect(defaults.simulatedAodEnabled, isFalse);
    expect(
      (await AppPreferencesService().getPreferences()).simulatedAodEnabled,
      isFalse,
    );
    final copied = defaults.copyWith(
      lockScreenVisualizerEnabled: true,
      simulatedAodEnabled: true,
    );
    expect(copied.simulatedAodEnabled, isTrue);
    expect(copied.copyWith(hapticsEnabled: false).simulatedAodEnabled, isTrue);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(appPreferencesProvider.notifier);
    await notifier.loaded;
    await notifier.setSimulatedAodEnabled(true);
    expect(container.read(appPreferencesProvider).simulatedAodEnabled, isTrue);
    var saved = await AppPreferencesService().getPreferences();
    expect(saved.simulatedAodEnabled, isTrue);
    expect(saved.lockScreenVisualizerEnabled, isFalse);
    await notifier.setSimulatedAodEnabled(false);
    saved = await AppPreferencesService().getPreferences();
    expect(saved.simulatedAodEnabled, isFalse);
  });
}
