import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flick/models/player_screen_mode.dart';
import 'package:flick/services/player_screen_mode_preference_service.dart';

final playerScreenModePreferenceServiceProvider =
    Provider<PlayerScreenModePreferenceService>((ref) {
  return PlayerScreenModePreferenceService();
});

class PlayerScreenModeNotifier extends Notifier<PlayerScreenMode> {
  bool _initialized = false;

  @override
  PlayerScreenMode build() {
    if (!_initialized) {
      _initialized = true;
      Future<void>.microtask(_loadFromPreferences);
    }
    return PlayerScreenMode.immersive;
  }

  Future<void> _loadFromPreferences() async {
    final mode =
        await ref.read(playerScreenModePreferenceServiceProvider).getMode();
    if (ref.mounted && state != mode) {
      state = mode;
    }
  }

  Future<void> setMode(PlayerScreenMode mode) async {
    if (state == mode) return;
    state = mode;
    await ref.read(playerScreenModePreferenceServiceProvider).setMode(mode);
  }
}

final playerScreenModeProvider =
    NotifierProvider<PlayerScreenModeNotifier, PlayerScreenMode>(
  PlayerScreenModeNotifier.new,
);
