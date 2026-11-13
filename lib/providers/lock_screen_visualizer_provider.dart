import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flick/providers/album_color_provider.dart';
import 'package:flick/providers/app_preferences_provider.dart';
import 'package:flick/providers/player_provider.dart';
import 'package:flick/providers/visualizer_source_provider.dart';
import 'package:flick/services/lock_screen_visualizer_service.dart';

/// Installed at app scope so native visibility still drives capture while the
/// Flutter Activity (and all in-app visualizer widgets) is paused.
final lockScreenVisualizerProvider = Provider<LockScreenVisualizerService>((
  ref,
) {
  final player = ref.watch(playerServiceProvider);
  final service = LockScreenVisualizerService(
    source: ref.watch(visualizerSourceProvider.notifier),
    isPlaying: player.isPlayingNotifier,
    currentSong: player.currentSongNotifier,
  );
  void configure() => service.configure(
    ref.read(appPreferencesProvider),
    albumColor: ref.read(albumDominantColorSyncProvider),
  );
  ref.listen(appPreferencesProvider, (_, _) => configure());
  ref.listen(albumDominantColorSyncProvider, (_, _) => configure());
  configure();
  ref.onDispose(service.dispose);
  return service;
});
