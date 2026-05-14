import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flick/services/app_preferences_service.dart';

final appPreferencesServiceProvider = Provider<AppPreferencesService>((ref) {
  return AppPreferencesService();
});

class AppPreferencesNotifier extends Notifier<AppPreferences> {
  bool _initialized = false;

  @override
  AppPreferences build() {
    if (!_initialized) {
      _initialized = true;
      Future<void>.microtask(_loadPreferences);
    }
    return const AppPreferences();
  }

  Future<void> _loadPreferences() async {
    final preferences = await ref
        .read(appPreferencesServiceProvider)
        .getPreferences();
    if (ref.mounted) {
      state = preferences;
    }
  }

  Future<void> setAnimationsEnabled(bool value) async {
    if (state.animationsEnabled == value) return;
    state = state.copyWith(animationsEnabled: value);
    await ref.read(appPreferencesServiceProvider).setAnimationsEnabled(value);
  }

  Future<void> setHapticsEnabled(bool value) async {
    if (state.hapticsEnabled == value) return;
    state = state.copyWith(hapticsEnabled: value);
    await ref.read(appPreferencesServiceProvider).setHapticsEnabled(value);
  }

  Future<void> setShowSmartMixes(bool value) async {
    if (state.showSmartMixes == value) return;
    state = state.copyWith(showSmartMixes: value);
    await ref.read(appPreferencesServiceProvider).setShowSmartMixes(value);
  }

  Future<void> setShowRecentArtists(bool value) async {
    if (state.showRecentArtists == value) return;
    state = state.copyWith(showRecentArtists: value);
    await ref.read(appPreferencesServiceProvider).setShowRecentArtists(value);
  }

  Future<void> setShowRecentTracks(bool value) async {
    if (state.showRecentTracks == value) return;
    state = state.copyWith(showRecentTracks: value);
    await ref.read(appPreferencesServiceProvider).setShowRecentTracks(value);
  }

  Future<void> setShowPlaylistPreviews(bool value) async {
    if (state.showPlaylistPreviews == value) return;
    state = state.copyWith(showPlaylistPreviews: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setShowPlaylistPreviews(value);
  }

  Future<void> setShowBrowseMore(bool value) async {
    if (state.showBrowseMore == value) return;
    state = state.copyWith(showBrowseMore: value);
    await ref.read(appPreferencesServiceProvider).setShowBrowseMore(value);
  }

  Future<void> setShowQuickAccess(bool value) async {
    if (state.showQuickAccess == value) return;
    state = state.copyWith(showQuickAccess: value);
    await ref.read(appPreferencesServiceProvider).setShowQuickAccess(value);
  }

  Future<void> setCrossfadeEnabled(bool value) async {
    if (state.crossfadeEnabled == value) return;
    state = state.copyWith(crossfadeEnabled: value);
    await ref.read(appPreferencesServiceProvider).setCrossfadeEnabled(value);
  }

  Future<void> setCrossfadeDurationSecs(double value) async {
    if (state.crossfadeDurationSecs == value) return;
    state = state.copyWith(crossfadeDurationSecs: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setCrossfadeDurationSecs(value);
  }

  Future<void> setCrossfadeCurveIndex(int value) async {
    if (state.crossfadeCurveIndex == value) return;
    state = state.copyWith(crossfadeCurveIndex: value);
    await ref.read(appPreferencesServiceProvider).setCrossfadeCurveIndex(value);
  }

  Future<void> setSwipeActionsEnabled(bool value) async {
    if (state.swipeActionsEnabled == value) return;
    state = state.copyWith(swipeActionsEnabled: value);
    await ref.read(appPreferencesServiceProvider).setSwipeActionsEnabled(value);
  }

  Future<void> setFavoriteRemovalMode(String value) async {
    if (state.favoriteRemovalMode == value) return;
    state = state.copyWith(favoriteRemovalMode: value);
    await ref.read(appPreferencesServiceProvider).setFavoriteRemovalMode(value);
  }

  Future<void> setFastIndexEnabled(bool value) async {
    if (state.fastIndexEnabled == value) return;
    state = state.copyWith(fastIndexEnabled: value);
    await ref.read(appPreferencesServiceProvider).setFastIndexEnabled(value);
  }

  Future<void> setFastIndexTimeoutSeconds(int value) async {
    if (state.fastIndexTimeoutSeconds == value) return;
    state = state.copyWith(fastIndexTimeoutSeconds: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setFastIndexTimeoutSeconds(value);
  }

  Future<void> setImmersiveAutoFullViewSeconds(int value) async {
    if (state.immersiveAutoFullViewSeconds == value) return;
    state = state.copyWith(immersiveAutoFullViewSeconds: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setImmersiveAutoFullViewSeconds(value);
  }

  Future<void> setVisualizerAnimationStyle(String value) async {
    if (state.visualizerAnimationStyle == value) return;
    state = state.copyWith(visualizerAnimationStyle: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setVisualizerAnimationStyle(value);
  }

  Future<void> setVisualizerFrequencyMode(String value) async {
    if (state.visualizerFrequencyMode == value) return;
    state = state.copyWith(visualizerFrequencyMode: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setVisualizerFrequencyMode(value);
  }

  Future<void> setVisualizerMovementMode(String value) async {
    if (state.visualizerMovementMode == value) return;
    state = state.copyWith(visualizerMovementMode: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setVisualizerMovementMode(value);
  }
}

final appPreferencesProvider =
    NotifierProvider<AppPreferencesNotifier, AppPreferences>(
      AppPreferencesNotifier.new,
    );
