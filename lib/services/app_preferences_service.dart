import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  final bool animationsEnabled;
  final bool hapticsEnabled;
  final bool showSmartMixes;
  final bool showRecentArtists;
  final bool showRecentTracks;
  final bool showPlaylistPreviews;
  final bool showBrowseMore;
  final bool showQuickAccess;
  final bool showEngineSelector;
  final bool crossfadeEnabled;
  final double crossfadeDurationSecs;
  final int crossfadeCurveIndex;
  final bool swipeActionsEnabled;
  final String favoriteRemovalMode; // 'swipe' or 'longpress'
  final bool fastIndexEnabled;
  final int fastIndexTimeoutSeconds;
  final int immersiveAutoFullViewSeconds;
  final String visualizerAnimationStyle;
  final String visualizerFrequencyMode;
  final String visualizerMovementMode;
  final double artworkCardArtworkScale;
  final double artworkCardTextScale;
  final double artworkCardVerticalOffset;
  final bool artworkCardShowTitle;
  final bool artworkCardShowArtist;
  final bool artworkCardShowAlbum;
  final bool artworkCardShowFileInfo;
  final double immersiveTextScale;
  final double immersiveVerticalOffset;
  final double immersiveFullViewScale;
  final bool immersiveShowTitle;
  final bool immersiveShowArtist;
  final bool immersiveShowFileInfo;
  final int widgetBgOpacity;
  final bool widgetShowAlbumArt;
  final bool widgetShowArtist;
  final String widgetAccentColor;
  final String widgetFlagshipTheme;
  final String widgetFlagshipAccent;
  final bool widgetFlagshipShowArtist;
  final bool lyricsMatchAudioFilename;
  final String leftActionButton;
  final String rightActionButton;
  final bool welcomeCardDismissed;
  final bool replaceAlbumWithBitPerfectCapsule;
  final int folderGridPageSize;
  final String? lastSeenChangelogVersion;
  final bool bottomBarAutoCollapseEnabled;
  final int bottomBarAutoCollapseSeconds;
  final bool keepPlayingOnQuit;
  final bool floatingPlayerEnabled;
  final bool autoFocusSearch;

  const AppPreferences({
    this.animationsEnabled = true,
    this.hapticsEnabled = true,
    this.showSmartMixes = true,
    this.showRecentArtists = true,
    this.showRecentTracks = true,
    this.showPlaylistPreviews = true,
    this.showBrowseMore = true,
    this.showQuickAccess = true,
    this.showEngineSelector = true,
    this.crossfadeEnabled = false,
    this.crossfadeDurationSecs = 3.0,
    this.crossfadeCurveIndex = 0,
    this.swipeActionsEnabled = false,
    this.favoriteRemovalMode = 'longpress',
    this.fastIndexEnabled = true,
    this.fastIndexTimeoutSeconds = 3,
    this.immersiveAutoFullViewSeconds = 0,
    this.visualizerAnimationStyle = 'bars',
    this.visualizerFrequencyMode = 'full',
    this.visualizerMovementMode = 'bouncy',
    this.artworkCardArtworkScale = 1.0,
    this.artworkCardTextScale = 1.0,
    this.artworkCardVerticalOffset = 0.0,
    this.artworkCardShowTitle = true,
    this.artworkCardShowArtist = true,
    this.artworkCardShowAlbum = true,
    this.artworkCardShowFileInfo = true,
    this.immersiveTextScale = 1.0,
    this.immersiveVerticalOffset = 0.0,
    this.immersiveFullViewScale = 1.0,
    this.immersiveShowTitle = true,
    this.immersiveShowArtist = true,
    this.immersiveShowFileInfo = true,
    this.widgetBgOpacity = 3,
    this.widgetShowAlbumArt = true,
    this.widgetShowArtist = true,
    this.widgetAccentColor = 'white',
    this.widgetFlagshipTheme = 'art_dominant',
    this.widgetFlagshipAccent = 'white',
    this.widgetFlagshipShowArtist = true,
    this.lyricsMatchAudioFilename = false,
    this.leftActionButton = 'lyrics',
    this.rightActionButton = 'favorites',
    this.welcomeCardDismissed = false,
    this.replaceAlbumWithBitPerfectCapsule = false,
    this.folderGridPageSize = 8,
    this.lastSeenChangelogVersion,
    this.bottomBarAutoCollapseEnabled = false,
    this.bottomBarAutoCollapseSeconds = 5,
    this.keepPlayingOnQuit = false,
    this.floatingPlayerEnabled = false,
    this.autoFocusSearch = false,
  });

  AppPreferences copyWith({
    bool? animationsEnabled,
    bool? hapticsEnabled,
    bool? showSmartMixes,
    bool? showRecentArtists,
    bool? showRecentTracks,
    bool? showPlaylistPreviews,
    bool? showBrowseMore,
    bool? showQuickAccess,
    bool? showEngineSelector,
    bool? crossfadeEnabled,
    double? crossfadeDurationSecs,
    int? crossfadeCurveIndex,
    bool? swipeActionsEnabled,
    String? favoriteRemovalMode,
    bool? fastIndexEnabled,
    int? fastIndexTimeoutSeconds,
    int? immersiveAutoFullViewSeconds,
    String? visualizerAnimationStyle,
    String? visualizerFrequencyMode,
    String? visualizerMovementMode,
    double? artworkCardArtworkScale,
    double? artworkCardTextScale,
    double? artworkCardVerticalOffset,
    bool? artworkCardShowTitle,
    bool? artworkCardShowArtist,
    bool? artworkCardShowAlbum,
    bool? artworkCardShowFileInfo,
    double? immersiveTextScale,
    double? immersiveVerticalOffset,
    double? immersiveFullViewScale,
    bool? immersiveShowTitle,
    bool? immersiveShowArtist,
    bool? immersiveShowFileInfo,
    int? widgetBgOpacity,
    bool? widgetShowAlbumArt,
    bool? widgetShowArtist,
    String? widgetAccentColor,
    String? widgetFlagshipTheme,
    String? widgetFlagshipAccent,
    bool? widgetFlagshipShowArtist,
    bool? lyricsMatchAudioFilename,
    String? leftActionButton,
    String? rightActionButton,
    bool? welcomeCardDismissed,
    bool? replaceAlbumWithBitPerfectCapsule,
    int? folderGridPageSize,
    String? lastSeenChangelogVersion,
    bool? bottomBarAutoCollapseEnabled,
    int? bottomBarAutoCollapseSeconds,
    bool? keepPlayingOnQuit,
    bool? floatingPlayerEnabled,
    bool? autoFocusSearch,
  }) {
    return AppPreferences(
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      showSmartMixes: showSmartMixes ?? this.showSmartMixes,
      showRecentArtists: showRecentArtists ?? this.showRecentArtists,
      showRecentTracks: showRecentTracks ?? this.showRecentTracks,
      showPlaylistPreviews: showPlaylistPreviews ?? this.showPlaylistPreviews,
      showBrowseMore: showBrowseMore ?? this.showBrowseMore,
      showQuickAccess: showQuickAccess ?? this.showQuickAccess,
      showEngineSelector: showEngineSelector ?? this.showEngineSelector,
      crossfadeEnabled: crossfadeEnabled ?? this.crossfadeEnabled,
      crossfadeDurationSecs:
          crossfadeDurationSecs ?? this.crossfadeDurationSecs,
      crossfadeCurveIndex: crossfadeCurveIndex ?? this.crossfadeCurveIndex,
      swipeActionsEnabled: swipeActionsEnabled ?? this.swipeActionsEnabled,
      favoriteRemovalMode: favoriteRemovalMode ?? this.favoriteRemovalMode,
      fastIndexEnabled: fastIndexEnabled ?? this.fastIndexEnabled,
      fastIndexTimeoutSeconds:
          fastIndexTimeoutSeconds ?? this.fastIndexTimeoutSeconds,
      immersiveAutoFullViewSeconds:
          immersiveAutoFullViewSeconds ?? this.immersiveAutoFullViewSeconds,
      visualizerAnimationStyle:
          visualizerAnimationStyle ?? this.visualizerAnimationStyle,
      visualizerFrequencyMode:
          visualizerFrequencyMode ?? this.visualizerFrequencyMode,
      visualizerMovementMode:
          visualizerMovementMode ?? this.visualizerMovementMode,
      artworkCardArtworkScale:
          artworkCardArtworkScale ?? this.artworkCardArtworkScale,
      artworkCardTextScale: artworkCardTextScale ?? this.artworkCardTextScale,
      artworkCardVerticalOffset:
          artworkCardVerticalOffset ?? this.artworkCardVerticalOffset,
      artworkCardShowTitle: artworkCardShowTitle ?? this.artworkCardShowTitle,
      artworkCardShowArtist:
          artworkCardShowArtist ?? this.artworkCardShowArtist,
      artworkCardShowAlbum: artworkCardShowAlbum ?? this.artworkCardShowAlbum,
      artworkCardShowFileInfo:
          artworkCardShowFileInfo ?? this.artworkCardShowFileInfo,
      immersiveTextScale: immersiveTextScale ?? this.immersiveTextScale,
      immersiveVerticalOffset:
          immersiveVerticalOffset ?? this.immersiveVerticalOffset,
      immersiveFullViewScale:
          immersiveFullViewScale ?? this.immersiveFullViewScale,
      immersiveShowTitle: immersiveShowTitle ?? this.immersiveShowTitle,
      immersiveShowArtist: immersiveShowArtist ?? this.immersiveShowArtist,
      immersiveShowFileInfo:
          immersiveShowFileInfo ?? this.immersiveShowFileInfo,
      widgetBgOpacity: widgetBgOpacity ?? this.widgetBgOpacity,
      widgetShowAlbumArt: widgetShowAlbumArt ?? this.widgetShowAlbumArt,
      widgetShowArtist: widgetShowArtist ?? this.widgetShowArtist,
      widgetAccentColor: widgetAccentColor ?? this.widgetAccentColor,
      widgetFlagshipTheme: widgetFlagshipTheme ?? this.widgetFlagshipTheme,
      widgetFlagshipAccent: widgetFlagshipAccent ?? this.widgetFlagshipAccent,
      widgetFlagshipShowArtist:
          widgetFlagshipShowArtist ?? this.widgetFlagshipShowArtist,
      lyricsMatchAudioFilename:
          lyricsMatchAudioFilename ?? this.lyricsMatchAudioFilename,
      leftActionButton: leftActionButton ?? this.leftActionButton,
      rightActionButton: rightActionButton ?? this.rightActionButton,
      welcomeCardDismissed: welcomeCardDismissed ?? this.welcomeCardDismissed,
      replaceAlbumWithBitPerfectCapsule:
          replaceAlbumWithBitPerfectCapsule ??
          this.replaceAlbumWithBitPerfectCapsule,
      folderGridPageSize: folderGridPageSize ?? this.folderGridPageSize,
      lastSeenChangelogVersion:
          lastSeenChangelogVersion ?? this.lastSeenChangelogVersion,
      bottomBarAutoCollapseEnabled:
          bottomBarAutoCollapseEnabled ?? this.bottomBarAutoCollapseEnabled,
      bottomBarAutoCollapseSeconds:
          bottomBarAutoCollapseSeconds ?? this.bottomBarAutoCollapseSeconds,
      keepPlayingOnQuit: keepPlayingOnQuit ?? this.keepPlayingOnQuit,
      floatingPlayerEnabled:
          floatingPlayerEnabled ?? this.floatingPlayerEnabled,
      autoFocusSearch: autoFocusSearch ?? this.autoFocusSearch,
    );
  }
}

class AppPreferencesService {
  static const _animationsKey = 'app_animations_enabled';
  static const _hapticsKey = 'app_haptics_enabled';
  static const _showSmartMixesKey = 'menu_show_smart_mixes';
  static const _showRecentArtistsKey = 'menu_show_recent_artists';
  static const _showRecentTracksKey = 'menu_show_recent_tracks';
  static const _showPlaylistPreviewsKey = 'menu_show_playlist_previews';
  static const _showBrowseMoreKey = 'menu_show_browse_more';
  static const _showQuickAccessKey = 'menu_show_quick_access';
  static const _showEngineSelectorKey = 'menu_show_engine_selector';
  static const _crossfadeEnabledKey = 'audio_crossfade_enabled';
  static const _crossfadeDurationKey = 'audio_crossfade_duration_secs';
  static const _crossfadeCurveKey = 'audio_crossfade_curve_index';
  static const _swipeActionsEnabledKey = 'swipe_actions_enabled';
  static const _favoriteRemovalModeKey = 'favorite_removal_mode';
  static const _fastIndexEnabledKey = 'fast_index_enabled';
  static const _fastIndexTimeoutKey = 'fast_index_timeout_seconds';
  static const _immersiveAutoFullViewKey = 'immersive_auto_full_view_seconds';
  static const _visualizerAnimationStyleKey = 'visualizer_animation_style';
  static const _visualizerFrequencyModeKey = 'visualizer_frequency_mode';
  static const _visualizerMovementModeKey = 'visualizer_movement_mode';
  static const _artworkCardArtworkScaleKey = 'artwork_card_artwork_scale';
  static const _artworkCardTextScaleKey = 'artwork_card_text_scale';
  static const _artworkCardVerticalOffsetKey = 'artwork_card_vertical_offset';
  static const _artworkCardShowTitleKey = 'artwork_card_show_title';
  static const _artworkCardShowArtistKey = 'artwork_card_show_artist';
  static const _artworkCardShowAlbumKey = 'artwork_card_show_album';
  static const _artworkCardShowFileInfoKey = 'artwork_card_show_file_info';
  static const _immersiveTextScaleKey = 'immersive_text_scale';
  static const _immersiveVerticalOffsetKey = 'immersive_vertical_offset';
  static const _immersiveFullViewScaleKey = 'immersive_full_view_scale';
  static const _immersiveShowTitleKey = 'immersive_show_title';
  static const _immersiveShowArtistKey = 'immersive_show_artist';
  static const _immersiveShowFileInfoKey = 'immersive_show_file_info';
  static const _widgetBgOpacityKey = 'widget_bg_opacity';
  static const _widgetShowAlbumArtKey = 'widget_show_album_art';
  static const _widgetShowArtistKey = 'widget_show_artist';
  static const _widgetAccentColorKey = 'widget_accent_color';
  static const _widgetFlagshipThemeKey = 'widget_flagship_theme';
  static const _widgetFlagshipAccentKey = 'widget_flagship_accent';
  static const _widgetFlagshipShowArtistKey = 'widget_flagship_show_artist';
  static const _lyricsMatchAudioFilenameKey = 'lyrics_match_audio_filename';
  static const _leftActionButtonKey = 'left_action_button';
  static const _rightActionButtonKey = 'right_action_button';
  static const _welcomeCardDismissedKey = 'welcome_card_dismissed';
  static const _replaceAlbumWithBitPerfectCapsuleKey =
      'replace_album_with_bit_perfect_capsule';
  static const _folderGridPageSizeKey = 'folder_grid_page_size';
  static const _lastSeenChangelogVersionKey = 'last_seen_changelog_version';
  static const _bottomBarAutoCollapseEnabledKey =
      'bottom_bar_auto_collapse_enabled';
  static const _bottomBarAutoCollapseSecondsKey =
      'bottom_bar_auto_collapse_seconds';
  static const _keepPlayingOnQuitKey = 'app_keep_playing_on_quit';
  static const _floatingPlayerEnabledKey = 'app_floating_player_enabled';
  static const _autoFocusSearchKey = 'app_auto_focus_search';
  static const _shuffleModeKey = 'playback_shuffle_mode';
  static const _loopModeKey = 'playback_loop_mode';
  static const _advanceListOrderKey = 'playback_advance_list_order';

  Future<AppPreferences> getPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return AppPreferences(
      animationsEnabled: prefs.getBool(_animationsKey) ?? true,
      hapticsEnabled: prefs.getBool(_hapticsKey) ?? true,
      showSmartMixes: prefs.getBool(_showSmartMixesKey) ?? true,
      showRecentArtists: prefs.getBool(_showRecentArtistsKey) ?? true,
      showRecentTracks: prefs.getBool(_showRecentTracksKey) ?? true,
      showPlaylistPreviews: prefs.getBool(_showPlaylistPreviewsKey) ?? true,
      showBrowseMore: prefs.getBool(_showBrowseMoreKey) ?? true,
      showQuickAccess: prefs.getBool(_showQuickAccessKey) ?? true,
      showEngineSelector: prefs.getBool(_showEngineSelectorKey) ?? true,
      crossfadeEnabled: prefs.getBool(_crossfadeEnabledKey) ?? false,
      crossfadeDurationSecs: prefs.getDouble(_crossfadeDurationKey) ?? 3.0,
      crossfadeCurveIndex: prefs.getInt(_crossfadeCurveKey) ?? 0,
      swipeActionsEnabled: prefs.getBool(_swipeActionsEnabledKey) ?? false,
      favoriteRemovalMode:
          prefs.getString(_favoriteRemovalModeKey) ?? 'longpress',
      fastIndexEnabled: prefs.getBool(_fastIndexEnabledKey) ?? true,
      fastIndexTimeoutSeconds: prefs.getInt(_fastIndexTimeoutKey) ?? 3,
      immersiveAutoFullViewSeconds:
          prefs.getInt(_immersiveAutoFullViewKey) ?? 0,
      visualizerAnimationStyle:
          prefs.getString(_visualizerAnimationStyleKey) ?? 'bars',
      visualizerFrequencyMode:
          prefs.getString(_visualizerFrequencyModeKey) ?? 'full',
      visualizerMovementMode:
          prefs.getString(_visualizerMovementModeKey) ?? 'bouncy',
      artworkCardArtworkScale:
          prefs.getDouble(_artworkCardArtworkScaleKey) ?? 1.0,
      artworkCardTextScale: prefs.getDouble(_artworkCardTextScaleKey) ?? 1.0,
      artworkCardVerticalOffset:
          prefs.getDouble(_artworkCardVerticalOffsetKey) ?? 0.0,
      artworkCardShowTitle: prefs.getBool(_artworkCardShowTitleKey) ?? true,
      artworkCardShowArtist: prefs.getBool(_artworkCardShowArtistKey) ?? true,
      artworkCardShowAlbum: prefs.getBool(_artworkCardShowAlbumKey) ?? true,
      artworkCardShowFileInfo:
          prefs.getBool(_artworkCardShowFileInfoKey) ?? true,
      immersiveTextScale: prefs.getDouble(_immersiveTextScaleKey) ?? 1.0,
      immersiveVerticalOffset:
          prefs.getDouble(_immersiveVerticalOffsetKey) ?? 0.0,
      immersiveFullViewScale:
          prefs.getDouble(_immersiveFullViewScaleKey) ?? 1.0,
      immersiveShowTitle: prefs.getBool(_immersiveShowTitleKey) ?? true,
      immersiveShowArtist: prefs.getBool(_immersiveShowArtistKey) ?? true,
      immersiveShowFileInfo: prefs.getBool(_immersiveShowFileInfoKey) ?? true,
      widgetBgOpacity: prefs.getInt(_widgetBgOpacityKey) ?? 3,
      widgetShowAlbumArt: prefs.getBool(_widgetShowAlbumArtKey) ?? true,
      widgetShowArtist: prefs.getBool(_widgetShowArtistKey) ?? true,
      widgetAccentColor: prefs.getString(_widgetAccentColorKey) ?? 'white',
      widgetFlagshipTheme:
          prefs.getString(_widgetFlagshipThemeKey) ?? 'art_dominant',
      widgetFlagshipAccent:
          prefs.getString(_widgetFlagshipAccentKey) ?? 'white',
      widgetFlagshipShowArtist:
          prefs.getBool(_widgetFlagshipShowArtistKey) ?? true,
      lyricsMatchAudioFilename:
          prefs.getBool(_lyricsMatchAudioFilenameKey) ?? false,
      leftActionButton: prefs.getString(_leftActionButtonKey) ?? 'lyrics',
      rightActionButton: prefs.getString(_rightActionButtonKey) ?? 'favorites',
      welcomeCardDismissed: prefs.getBool(_welcomeCardDismissedKey) ?? false,
      replaceAlbumWithBitPerfectCapsule:
          prefs.getBool(_replaceAlbumWithBitPerfectCapsuleKey) ?? false,
      folderGridPageSize: prefs.getInt(_folderGridPageSizeKey) ?? 8,
      lastSeenChangelogVersion: prefs.getString(_lastSeenChangelogVersionKey),
      bottomBarAutoCollapseEnabled:
          prefs.getBool(_bottomBarAutoCollapseEnabledKey) ?? false,
      bottomBarAutoCollapseSeconds:
          prefs.getInt(_bottomBarAutoCollapseSecondsKey) ?? 5,
      keepPlayingOnQuit: prefs.getBool(_keepPlayingOnQuitKey) ?? false,
      floatingPlayerEnabled:
          prefs.getBool(_floatingPlayerEnabledKey) ?? false,
      autoFocusSearch: prefs.getBool(_autoFocusSearchKey) ?? false,
    );
  }

  Future<bool> getAnimationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_animationsKey) ?? true;
  }

  Future<void> setAnimationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_animationsKey, value);
  }

  Future<bool> getHapticsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hapticsKey) ?? true;
  }

  Future<void> setHapticsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticsKey, value);
  }

  Future<bool> getShowSmartMixes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showSmartMixesKey) ?? true;
  }

  Future<void> setShowSmartMixes(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showSmartMixesKey, value);
  }

  Future<bool> getShowRecentArtists() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showRecentArtistsKey) ?? true;
  }

  Future<void> setShowRecentArtists(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showRecentArtistsKey, value);
  }

  Future<bool> getShowRecentTracks() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showRecentTracksKey) ?? true;
  }

  Future<void> setShowRecentTracks(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showRecentTracksKey, value);
  }

  Future<bool> getShowPlaylistPreviews() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showPlaylistPreviewsKey) ?? true;
  }

  Future<void> setShowPlaylistPreviews(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showPlaylistPreviewsKey, value);
  }

  Future<bool> getShowBrowseMore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showBrowseMoreKey) ?? true;
  }

  Future<void> setShowBrowseMore(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showBrowseMoreKey, value);
  }

  Future<bool> getShowQuickAccess() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showQuickAccessKey) ?? true;
  }

  Future<void> setShowQuickAccess(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showQuickAccessKey, value);
  }

  Future<bool> getShowEngineSelector() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showEngineSelectorKey) ?? true;
  }

  Future<void> setShowEngineSelector(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showEngineSelectorKey, value);
  }

  Future<bool> getCrossfadeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_crossfadeEnabledKey) ?? false;
  }

  Future<void> setCrossfadeEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_crossfadeEnabledKey, value);
  }

  Future<double> getCrossfadeDurationSecs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_crossfadeDurationKey) ?? 3.0;
  }

  Future<void> setCrossfadeDurationSecs(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_crossfadeDurationKey, value);
  }

  Future<int> getCrossfadeCurveIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_crossfadeCurveKey) ?? 0;
  }

  Future<void> setCrossfadeCurveIndex(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_crossfadeCurveKey, value);
  }

  Future<bool> getSwipeActionsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_swipeActionsEnabledKey) ?? false;
  }

  Future<void> setSwipeActionsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_swipeActionsEnabledKey, value);
  }

  Future<String> getFavoriteRemovalMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_favoriteRemovalModeKey) ?? 'longpress';
  }

  Future<void> setFavoriteRemovalMode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_favoriteRemovalModeKey, value);
  }

  Future<bool> getFastIndexEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_fastIndexEnabledKey) ?? true;
  }

  Future<void> setFastIndexEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_fastIndexEnabledKey, value);
  }

  Future<int> getFastIndexTimeoutSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_fastIndexTimeoutKey) ?? 3;
  }

  Future<void> setFastIndexTimeoutSeconds(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_fastIndexTimeoutKey, value);
  }

  Future<int> getImmersiveAutoFullViewSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_immersiveAutoFullViewKey) ?? 0;
  }

  Future<void> setImmersiveAutoFullViewSeconds(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_immersiveAutoFullViewKey, value);
  }

  Future<String> getVisualizerAnimationStyle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_visualizerAnimationStyleKey) ?? 'bars';
  }

  Future<void> setVisualizerAnimationStyle(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_visualizerAnimationStyleKey, value);
  }

  Future<String> getVisualizerFrequencyMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_visualizerFrequencyModeKey) ?? 'full';
  }

  Future<void> setVisualizerFrequencyMode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_visualizerFrequencyModeKey, value);
  }

  Future<String> getVisualizerMovementMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_visualizerMovementModeKey) ?? 'bouncy';
  }

  Future<void> setVisualizerMovementMode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_visualizerMovementModeKey, value);
  }

  Future<void> setArtworkCardArtworkScale(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_artworkCardArtworkScaleKey, value);
  }

  Future<void> setArtworkCardTextScale(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_artworkCardTextScaleKey, value);
  }

  Future<void> setArtworkCardVerticalOffset(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_artworkCardVerticalOffsetKey, value);
  }

  Future<bool> getArtworkCardShowTitle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_artworkCardShowTitleKey) ?? true;
  }

  Future<void> setArtworkCardShowTitle(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_artworkCardShowTitleKey, value);
  }

  Future<bool> getArtworkCardShowArtist() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_artworkCardShowArtistKey) ?? true;
  }

  Future<void> setArtworkCardShowArtist(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_artworkCardShowArtistKey, value);
  }

  Future<bool> getArtworkCardShowAlbum() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_artworkCardShowAlbumKey) ?? true;
  }

  Future<void> setArtworkCardShowAlbum(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_artworkCardShowAlbumKey, value);
  }

  Future<bool> getArtworkCardShowFileInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_artworkCardShowFileInfoKey) ?? true;
  }

  Future<void> setArtworkCardShowFileInfo(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_artworkCardShowFileInfoKey, value);
  }

  Future<void> setImmersiveTextScale(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_immersiveTextScaleKey, value);
  }

  Future<void> setImmersiveVerticalOffset(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_immersiveVerticalOffsetKey, value);
  }

  Future<void> setImmersiveFullViewScale(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_immersiveFullViewScaleKey, value);
  }

  Future<bool> getImmersiveShowTitle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_immersiveShowTitleKey) ?? true;
  }

  Future<void> setImmersiveShowTitle(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_immersiveShowTitleKey, value);
  }

  Future<bool> getImmersiveShowArtist() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_immersiveShowArtistKey) ?? true;
  }

  Future<void> setImmersiveShowArtist(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_immersiveShowArtistKey, value);
  }

  Future<bool> getImmersiveShowFileInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_immersiveShowFileInfoKey) ?? true;
  }

  Future<void> setImmersiveShowFileInfo(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_immersiveShowFileInfoKey, value);
  }

  Future<void> setWidgetBgOpacity(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_widgetBgOpacityKey, value);
  }

  Future<void> setWidgetShowAlbumArt(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_widgetShowAlbumArtKey, value);
  }

  Future<void> setWidgetShowArtist(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_widgetShowArtistKey, value);
  }

  Future<void> setWidgetAccentColor(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_widgetAccentColorKey, value);
  }

  Future<String> getWidgetFlagshipTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_widgetFlagshipThemeKey) ?? 'art_dominant';
  }

  Future<void> setWidgetFlagshipTheme(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_widgetFlagshipThemeKey, value);
  }

  Future<String> getWidgetFlagshipAccent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_widgetFlagshipAccentKey) ?? 'white';
  }

  Future<void> setWidgetFlagshipAccent(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_widgetFlagshipAccentKey, value);
  }

  Future<bool> getWidgetFlagshipShowArtist() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_widgetFlagshipShowArtistKey) ?? true;
  }

  Future<void> setWidgetFlagshipShowArtist(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_widgetFlagshipShowArtistKey, value);
  }

  Future<bool> getLyricsMatchAudioFilename() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_lyricsMatchAudioFilenameKey) ?? false;
  }

  Future<void> setLyricsMatchAudioFilename(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lyricsMatchAudioFilenameKey, value);
  }

  Future<String> getLeftActionButton() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_leftActionButtonKey) ?? 'lyrics';
  }

  Future<void> setLeftActionButton(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_leftActionButtonKey, value);
  }

  Future<String> getRightActionButton() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_rightActionButtonKey) ?? 'favorites';
  }

  Future<void> setRightActionButton(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rightActionButtonKey, value);
  }

  Future<bool> getWelcomeCardDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_welcomeCardDismissedKey) ?? false;
  }

  Future<void> setWelcomeCardDismissed(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomeCardDismissedKey, value);
  }

  Future<bool> getReplaceAlbumWithBitPerfectCapsule() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_replaceAlbumWithBitPerfectCapsuleKey) ?? false;
  }

  Future<void> setReplaceAlbumWithBitPerfectCapsule(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_replaceAlbumWithBitPerfectCapsuleKey, value);
  }

  Future<int> getFolderGridPageSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_folderGridPageSizeKey) ?? 8;
  }

  Future<void> setFolderGridPageSize(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_folderGridPageSizeKey, value);
  }

  Future<String?> getLastSeenChangelogVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSeenChangelogVersionKey);
  }

  Future<void> setLastSeenChangelogVersion(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_lastSeenChangelogVersionKey);
    } else {
      await prefs.setString(_lastSeenChangelogVersionKey, value);
    }
  }

  Future<bool> getBottomBarAutoCollapseEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_bottomBarAutoCollapseEnabledKey) ?? false;
  }

  Future<void> setBottomBarAutoCollapseEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bottomBarAutoCollapseEnabledKey, value);
  }

  Future<int> getBottomBarAutoCollapseSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_bottomBarAutoCollapseSecondsKey) ?? 5;
  }

  Future<void> setBottomBarAutoCollapseSeconds(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bottomBarAutoCollapseSecondsKey, value);
  }

  Future<int> getShuffleMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_shuffleModeKey) ?? 0;
  }

  Future<void> setShuffleMode(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_shuffleModeKey, value);
  }

  Future<int> getLoopMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_loopModeKey) ?? 2;
  }

  Future<void> setLoopMode(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_loopModeKey, value);
  }

  Future<int> getAdvanceListOrder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_advanceListOrderKey) ?? 0;
  }

  Future<void> setAdvanceListOrder(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_advanceListOrderKey, value);
  }

  Future<bool> getKeepPlayingOnQuit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keepPlayingOnQuitKey) ?? false;
  }

  Future<void> setKeepPlayingOnQuit(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keepPlayingOnQuitKey, value);
  }

  Future<bool> getFloatingPlayerEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_floatingPlayerEnabledKey) ?? false;
  }

  Future<void> setFloatingPlayerEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_floatingPlayerEnabledKey, value);
  }

  Future<bool> getAutoFocusSearch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoFocusSearchKey) ?? false;
  }

  Future<void> setAutoFocusSearch(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoFocusSearchKey, value);
  }
}
