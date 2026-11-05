import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flick/models/progress_bar_size.dart';
import 'package:flick/providers/progress_bar_size_provider.dart';
import 'package:flick/services/progress_bar_size_preference_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults are used when nothing is saved', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(progressBarSizeProvider);
    await pumpEventQueue();

    expect(container.read(progressBarSizeProvider), ProgressBarSizes.defaults);
  });

  test('waveform height and line thickness persist independently', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    final notifier = container.read(progressBarSizeProvider.notifier);

    await notifier.setWaveformHeight(80);
    await notifier.setLineThickness(10);
    container.dispose();

    final reloaded = ProviderContainer();
    addTearDown(reloaded.dispose);
    reloaded.read(progressBarSizeProvider);
    await pumpEventQueue();

    final sizes = reloaded.read(progressBarSizeProvider);
    expect(sizes.waveformHeight, 80);
    expect(sizes.lineThickness, 10);
  });

  test('reset only restores the selected style', () async {
    SharedPreferences.setMockInitialValues({
      ProgressBarSizePreferenceService.waveformHeightKey: 80.0,
      ProgressBarSizePreferenceService.lineThicknessKey: 10.0,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(progressBarSizeProvider);
    await pumpEventQueue();
    await container
        .read(progressBarSizeProvider.notifier)
        .resetWaveformHeight();

    final sizes = container.read(progressBarSizeProvider);
    expect(sizes.waveformHeight, ProgressBarSizes.defaultWaveformHeight);
    expect(sizes.lineThickness, 10);
  });

  test('saved values outside the supported range are clamped', () async {
    SharedPreferences.setMockInitialValues({
      ProgressBarSizePreferenceService.waveformHeightKey: 500.0,
      ProgressBarSizePreferenceService.lineThicknessKey: -3.0,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(progressBarSizeProvider);
    await pumpEventQueue();

    final sizes = container.read(progressBarSizeProvider);
    expect(sizes.waveformHeight, ProgressBarSizes.maxWaveformHeight);
    expect(sizes.lineThickness, ProgressBarSizes.minLineThickness);
  });

  test('rapid edits persist the final state', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(progressBarSizeProvider.notifier);

    await Future.wait([
      notifier.setWaveformHeight(32),
      notifier.setWaveformHeight(48),
      notifier.setLineThickness(7),
      notifier.setLineThickness(9),
    ]);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getDouble(ProgressBarSizePreferenceService.waveformHeightKey),
      48,
    );
    expect(
      prefs.getDouble(ProgressBarSizePreferenceService.lineThicknessKey),
      9,
    );
  });
}
