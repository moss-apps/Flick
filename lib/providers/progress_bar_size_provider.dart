import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flick/models/progress_bar_size.dart';
import 'package:flick/services/progress_bar_size_preference_service.dart';

final progressBarSizePreferenceServiceProvider =
    Provider<ProgressBarSizePreferenceService>((ref) {
      return ProgressBarSizePreferenceService();
    });

class ProgressBarSizeNotifier extends Notifier<ProgressBarSizes> {
  late Future<void> _ready;
  Future<void> _writes = Future.value();
  bool _loaded = false;
  final _pending = <ProgressBarSizes Function(ProgressBarSizes)>[];

  @override
  ProgressBarSizes build() {
    _loaded = false;
    _pending.clear();
    _ready = Future<void>.microtask(_loadFromPreferences);
    return ProgressBarSizes.defaults;
  }

  Future<void> _loadFromPreferences() async {
    var sizes = await ref
        .read(progressBarSizePreferenceServiceProvider)
        .getSizes();
    if (!ref.mounted) return;
    for (final change in _pending) {
      sizes = change(sizes);
    }
    _pending.clear();
    _loaded = true;
    state = sizes;
  }

  Future<void> setWaveformHeight(double height) {
    final clamped = ProgressBarSizes.clampWaveformHeight(height);
    return _update((sizes) => sizes.copyWith(waveformHeight: clamped));
  }

  Future<void> setLineThickness(double thickness) {
    final clamped = ProgressBarSizes.clampLineThickness(thickness);
    return _update((sizes) => sizes.copyWith(lineThickness: clamped));
  }

  Future<void> resetWaveformHeight() {
    return setWaveformHeight(ProgressBarSizes.defaultWaveformHeight);
  }

  Future<void> resetLineThickness() {
    return setLineThickness(ProgressBarSizes.defaultLineThickness);
  }

  Future<void> _update(
    ProgressBarSizes Function(ProgressBarSizes) change,
  ) async {
    if (!_loaded) _pending.add(change);
    state = change(state);
    await _ready;
    if (!ref.mounted) return;

    final snapshot = state;
    final write = _writes.then(
      (_) =>
          ref.read(progressBarSizePreferenceServiceProvider).setSizes(snapshot),
    );
    _writes = write.catchError((Object _) {});
    await write;
  }
}

final progressBarSizeProvider =
    NotifierProvider<ProgressBarSizeNotifier, ProgressBarSizes>(
      ProgressBarSizeNotifier.new,
    );
