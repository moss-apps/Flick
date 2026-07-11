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

  Future<void> setShowEngineSelector(bool value) async {
    if (state.showEngineSelector == value) return;
    state = state.copyWith(showEngineSelector: value);
    await ref.read(appPreferencesServiceProvider).setShowEngineSelector(value);
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

  Future<void> setSearchPlaybackMode(String value) async {
    if (state.searchPlaybackMode == value) return;
    state = state.copyWith(searchPlaybackMode: value);
    await ref.read(appPreferencesServiceProvider).setSearchPlaybackMode(value);
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

  Future<void> setArtworkCardArtworkScale(double value) async {
    if (state.artworkCardArtworkScale == value) return;
    state = state.copyWith(artworkCardArtworkScale: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setArtworkCardArtworkScale(value);
  }

  Future<void> setArtworkCardTextScale(double value) async {
    if (state.artworkCardTextScale == value) return;
    state = state.copyWith(artworkCardTextScale: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setArtworkCardTextScale(value);
  }

  Future<void> setArtworkCardVerticalOffset(double value) async {
    if (state.artworkCardVerticalOffset == value) return;
    state = state.copyWith(artworkCardVerticalOffset: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setArtworkCardVerticalOffset(value);
  }

  Future<void> setArtworkCardShowTitle(bool value) async {
    if (state.artworkCardShowTitle == value) return;
    state = state.copyWith(artworkCardShowTitle: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setArtworkCardShowTitle(value);
  }

  Future<void> setArtworkCardShowArtist(bool value) async {
    if (state.artworkCardShowArtist == value) return;
    state = state.copyWith(artworkCardShowArtist: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setArtworkCardShowArtist(value);
  }

  Future<void> setArtworkCardShowAlbum(bool value) async {
    if (state.artworkCardShowAlbum == value) return;
    state = state.copyWith(artworkCardShowAlbum: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setArtworkCardShowAlbum(value);
  }

  Future<void> setArtworkCardShowFileInfo(bool value) async {
    if (state.artworkCardShowFileInfo == value) return;
    state = state.copyWith(artworkCardShowFileInfo: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setArtworkCardShowFileInfo(value);
  }

  Future<void> setArtworkCardShowFrame(bool value) async {
    if (state.artworkCardShowFrame == value) return;
    state = state.copyWith(artworkCardShowFrame: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setArtworkCardShowFrame(value);
  }

  Future<void> setImmersiveTextScale(double value) async {
    if (state.immersiveTextScale == value) return;
    state = state.copyWith(immersiveTextScale: value);
    await ref.read(appPreferencesServiceProvider).setImmersiveTextScale(value);
  }

  Future<void> setImmersiveVerticalOffset(double value) async {
    if (state.immersiveVerticalOffset == value) return;
    state = state.copyWith(immersiveVerticalOffset: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setImmersiveVerticalOffset(value);
  }

  Future<void> setImmersiveFullViewScale(double value) async {
    if (state.immersiveFullViewScale == value) return;
    state = state.copyWith(immersiveFullViewScale: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setImmersiveFullViewScale(value);
  }

  Future<void> setImmersiveShowTitle(bool value) async {
    if (state.immersiveShowTitle == value) return;
    state = state.copyWith(immersiveShowTitle: value);
    await ref.read(appPreferencesServiceProvider).setImmersiveShowTitle(value);
  }

  Future<void> setImmersiveShowArtist(bool value) async {
    if (state.immersiveShowArtist == value) return;
    state = state.copyWith(immersiveShowArtist: value);
    await ref.read(appPreferencesServiceProvider).setImmersiveShowArtist(value);
  }

  Future<void> setImmersiveShowFileInfo(bool value) async {
    if (state.immersiveShowFileInfo == value) return;
    state = state.copyWith(immersiveShowFileInfo: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setImmersiveShowFileInfo(value);
  }

  Future<void> setWidgetBgOpacity(int value) async {
    if (state.widgetBgOpacity == value) return;
    state = state.copyWith(widgetBgOpacity: value);
    await ref.read(appPreferencesServiceProvider).setWidgetBgOpacity(value);
  }

  Future<void> setWidgetShowAlbumArt(bool value) async {
    if (state.widgetShowAlbumArt == value) return;
    state = state.copyWith(widgetShowAlbumArt: value);
    await ref.read(appPreferencesServiceProvider).setWidgetShowAlbumArt(value);
  }

  Future<void> setWidgetShowArtist(bool value) async {
    if (state.widgetShowArtist == value) return;
    state = state.copyWith(widgetShowArtist: value);
    await ref.read(appPreferencesServiceProvider).setWidgetShowArtist(value);
  }

  Future<void> setWidgetAccentColor(String value) async {
    if (state.widgetAccentColor == value) return;
    state = state.copyWith(widgetAccentColor: value);
    await ref.read(appPreferencesServiceProvider).setWidgetAccentColor(value);
  }

  Future<void> setWidgetFlagshipTheme(String value) async {
    if (state.widgetFlagshipTheme == value) return;
    state = state.copyWith(widgetFlagshipTheme: value);
    await ref.read(appPreferencesServiceProvider).setWidgetFlagshipTheme(value);
  }

  Future<void> setWidgetFlagshipAccent(String value) async {
    if (state.widgetFlagshipAccent == value) return;
    state = state.copyWith(widgetFlagshipAccent: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setWidgetFlagshipAccent(value);
  }

  Future<void> setWidgetFlagshipShowArtist(bool value) async {
    if (state.widgetFlagshipShowArtist == value) return;
    state = state.copyWith(widgetFlagshipShowArtist: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setWidgetFlagshipShowArtist(value);
  }

  Future<void> setWidgetCompactBgOpacity(int value) async {
    if (state.widgetCompactBgOpacity == value) return;
    state = state.copyWith(widgetCompactBgOpacity: value);
    await ref.read(appPreferencesServiceProvider).setWidgetCompactBgOpacity(value);
  }

  Future<void> setWidgetCompactShowAlbumArt(bool value) async {
    if (state.widgetCompactShowAlbumArt == value) return;
    state = state.copyWith(widgetCompactShowAlbumArt: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setWidgetCompactShowAlbumArt(value);
  }

  Future<void> setWidgetCompactShowArtist(bool value) async {
    if (state.widgetCompactShowArtist == value) return;
    state = state.copyWith(widgetCompactShowArtist: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setWidgetCompactShowArtist(value);
  }

  Future<void> setWidgetCompactAccent(String value) async {
    if (state.widgetCompactAccent == value) return;
    state = state.copyWith(widgetCompactAccent: value);
    await ref.read(appPreferencesServiceProvider).setWidgetCompactAccent(value);
  }

  Future<void> setLyricsMatchAudioFilename(bool value) async {
    if (state.lyricsMatchAudioFilename == value) return;
    state = state.copyWith(lyricsMatchAudioFilename: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setLyricsMatchAudioFilename(value);
  }

  Future<void> setLeftActionButton(String value) async {
    if (state.leftActionButton == value) return;
    state = state.copyWith(leftActionButton: value);
    await ref.read(appPreferencesServiceProvider).setLeftActionButton(value);
  }

  Future<void> setRightActionButton(String value) async {
    if (state.rightActionButton == value) return;
    state = state.copyWith(rightActionButton: value);
    await ref.read(appPreferencesServiceProvider).setRightActionButton(value);
  }

  Future<void> setWelcomeCardDismissed(bool value) async {
    if (state.welcomeCardDismissed == value) return;
    state = state.copyWith(welcomeCardDismissed: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setWelcomeCardDismissed(value);
  }

  Future<void> setGlanceCardHidden(bool value) async {
    if (state.glanceCardHidden == value) return;
    state = state.copyWith(glanceCardHidden: value);
    await ref.read(appPreferencesServiceProvider).setGlanceCardHidden(value);
  }

  Future<void> setGlanceCardMinimized(bool value) async {
    if (state.glanceCardMinimized == value) return;
    state = state.copyWith(glanceCardMinimized: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setGlanceCardMinimized(value);
  }

  Future<void> setReplaceAlbumWithBitPerfectCapsule(bool value) async {
    if (state.replaceAlbumWithBitPerfectCapsule == value) return;
    state = state.copyWith(replaceAlbumWithBitPerfectCapsule: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setReplaceAlbumWithBitPerfectCapsule(value);
  }

  Future<void> setFolderGridPageSize(int value) async {
    if (state.folderGridPageSize == value) return;
    state = state.copyWith(folderGridPageSize: value);
    await ref.read(appPreferencesServiceProvider).setFolderGridPageSize(value);
  }

  Future<void> setLastSeenChangelogVersion(String? value) async {
    if (state.lastSeenChangelogVersion == value) return;
    state = state.copyWith(lastSeenChangelogVersion: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setLastSeenChangelogVersion(value);
  }

  Future<void> setBottomBarAutoCollapseEnabled(bool value) async {
    if (state.bottomBarAutoCollapseEnabled == value) return;
    state = state.copyWith(bottomBarAutoCollapseEnabled: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setBottomBarAutoCollapseEnabled(value);
  }

  Future<void> setBottomBarAutoCollapseSeconds(int value) async {
    if (state.bottomBarAutoCollapseSeconds == value) return;
    state = state.copyWith(bottomBarAutoCollapseSeconds: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setBottomBarAutoCollapseSeconds(value);
  }

  Future<void> setMiniPlayerSwipeAction(String value) async {
    if (state.miniPlayerSwipeAction == value) return;
    state = state.copyWith(miniPlayerSwipeAction: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setMiniPlayerSwipeAction(value);
  }

  Future<void> setKeepPlayingOnQuit(bool value) async {
    if (state.keepPlayingOnQuit == value) return;
    state = state.copyWith(keepPlayingOnQuit: value);
    await ref.read(appPreferencesServiceProvider).setKeepPlayingOnQuit(value);
  }

  Future<void> setPauseOnBluetoothDisconnect(bool value) async {
    if (state.pauseOnBluetoothDisconnect == value) return;
    state = state.copyWith(pauseOnBluetoothDisconnect: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setPauseOnBluetoothDisconnect(value);
  }

  Future<void> setResumeOnBluetoothReconnect(bool value) async {
    if (state.resumeOnBluetoothReconnect == value) return;
    state = state.copyWith(resumeOnBluetoothReconnect: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setResumeOnBluetoothReconnect(value);
  }

  Future<void> setPreferredBluetoothDevice(String value) async {
    if (state.preferredBluetoothDevice == value) return;
    state = state.copyWith(preferredBluetoothDevice: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setPreferredBluetoothDevice(value);
  }

  Future<void> setBtLdacBitrate(String value) async {
    if (state.btLdacBitrate == value) return;
    state = state.copyWith(btLdacBitrate: value);
    await ref.read(appPreferencesServiceProvider).setBtLdacBitrate(value);
  }

  Future<void> setBtPreferredCodec(int value) async {
    if (state.btPreferredCodec == value) return;
    state = state.copyWith(btPreferredCodec: value);
    await ref.read(appPreferencesServiceProvider).setBtPreferredCodec(value);
  }

  Future<void> setBtAbsoluteVolumeSync(bool value) async {
    if (state.btAbsoluteVolumeSync == value) return;
    state = state.copyWith(btAbsoluteVolumeSync: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setBtAbsoluteVolumeSync(value);
  }

  Future<void> setBtEnableCodecControl(bool value) async {
    if (state.btEnableCodecControl == value) return;
    state = state.copyWith(btEnableCodecControl: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setBtEnableCodecControl(value);
  }

  Future<void> setBtSampleRate(int value) async {
    if (state.btSampleRate == value) return;
    state = state.copyWith(btSampleRate: value);
    await ref.read(appPreferencesServiceProvider).setBtSampleRate(value);
  }

  Future<void> setBtLdacBitsPerSample(int value) async {
    if (state.btLdacBitsPerSample == value) return;
    state = state.copyWith(btLdacBitsPerSample: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setBtLdacBitsPerSample(value);
  }

  Future<void> setFloatingPlayerEnabled(bool value) async {
    if (state.floatingPlayerEnabled == value) return;
    state = state.copyWith(floatingPlayerEnabled: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setFloatingPlayerEnabled(value);
  }

  Future<void> setFloatingIslandEnabled(bool value) async {
    if (state.floatingIslandEnabled == value) return;
    state = state.copyWith(floatingIslandEnabled: value);
    await ref
        .read(appPreferencesServiceProvider)
        .setFloatingIslandEnabled(value);
  }

  Future<void> setAutoFocusSearch(bool value) async {
    if (state.autoFocusSearch == value) return;
    state = state.copyWith(autoFocusSearch: value);
    await ref.read(appPreferencesServiceProvider).setAutoFocusSearch(value);
  }

  Future<void> setRefreshRateMode(String value) async {
    if (state.refreshRateMode == value) return;
    state = state.copyWith(refreshRateMode: value);
    await ref.read(appPreferencesServiceProvider).setRefreshRateMode(value);
  }

  Future<void> setVisualizerEnabled(bool value) async {
    if (state.visualizerEnabled == value) return;
    state = state.copyWith(visualizerEnabled: value);
    await ref.read(appPreferencesServiceProvider).setVisualizerEnabled(value);
  }
}

final appPreferencesProvider =
    NotifierProvider<AppPreferencesNotifier, AppPreferences>(
      AppPreferencesNotifier.new,
    );
