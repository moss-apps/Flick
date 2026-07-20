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
  final bool artworkCardShowFrame;
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
  final int widgetCompactBgOpacity;
  final bool widgetCompactShowAlbumArt;
  final bool widgetCompactShowArtist;
  final String widgetCompactAccent;
  final bool lyricsMatchAudioFilename;
  final String leftActionButton;
  final String rightActionButton;
  final bool welcomeCardDismissed;
  final bool glanceCardHidden;
  final bool glanceCardMinimized;
  final bool replaceAlbumWithBitPerfectCapsule;
  final bool albumsStretchArtwork;
  final bool animatedAlbumArt;
  final int folderGridPageSize;
  final String? lastSeenChangelogVersion;
  final bool bottomBarAutoCollapseEnabled;
  final int bottomBarAutoCollapseSeconds;
  final String miniPlayerSwipeAction;
  final bool keepPlayingOnQuit;
  final bool pauseOnBluetoothDisconnect;
  final bool resumeOnBluetoothReconnect;
  final bool pauseOnUsbDacDisconnect;
  final String preferredBluetoothDevice;
  final int btPreferredCodec;
  final String btLdacBitrate;
  final bool btAbsoluteVolumeSync;
  final bool btEnableCodecControl;
  final int btSampleRate;
  final int btLdacBitsPerSample;
  final bool floatingPlayerEnabled;
  final bool floatingIslandEnabled;
  final bool autoFocusSearch;
  final String searchPlaybackMode; // 'results', 'library', or 'queue'
  final String refreshRateMode; // 'high', 'standard', 'adaptive'
  final bool visualizerEnabled;
  final double orbitRadiusRatio;
  final double orbitCenterOffsetRatio;
  final double orbitCenterYRatio;
  final double orbitItemSpacing;
  final double orbitSelectedScale;
  final double orbitDepth;
  final int orbitVisibleItems;
  final double orbitCardArtSize;
  final double orbitCardWidthRatio;
  final double orbitArtResolutionMultiplier;
  final bool orbitShowPath;
  final bool orbitShowGlow;
  final bool streaksEnabled;
  final bool showMoreFromArtist;
  final bool showMoreArtists;

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
    this.artworkCardShowFrame = true,
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
    this.widgetCompactBgOpacity = 3,
    this.widgetCompactShowAlbumArt = true,
    this.widgetCompactShowArtist = true,
    this.widgetCompactAccent = 'white',
    this.lyricsMatchAudioFilename = false,
    this.leftActionButton = 'lyrics',
    this.rightActionButton = 'favorites',
    this.welcomeCardDismissed = false,
    this.glanceCardHidden = false,
    this.glanceCardMinimized = false,
    this.replaceAlbumWithBitPerfectCapsule = false,
    this.albumsStretchArtwork = false,
    this.animatedAlbumArt = true,
    this.folderGridPageSize = 8,
    this.lastSeenChangelogVersion,
    this.bottomBarAutoCollapseEnabled = false,
    this.bottomBarAutoCollapseSeconds = 5,
    this.miniPlayerSwipeAction = 'visualizer',
    this.keepPlayingOnQuit = false,
    this.pauseOnBluetoothDisconnect = true,
    this.resumeOnBluetoothReconnect = false,
    this.pauseOnUsbDacDisconnect = true,
    this.preferredBluetoothDevice = '',
    this.btPreferredCodec = -1,
    this.btLdacBitrate = 'adaptive',
    this.btAbsoluteVolumeSync = false,
    this.btEnableCodecControl = false,
    this.btSampleRate = 0,
    this.btLdacBitsPerSample = 0,
    this.floatingPlayerEnabled = false,
    this.floatingIslandEnabled = true,
    this.autoFocusSearch = false,
    this.searchPlaybackMode = 'results',
    this.refreshRateMode = 'high',
    this.visualizerEnabled = true,
    this.orbitRadiusRatio = 1.0,
    this.orbitCenterOffsetRatio = -0.5,
    this.orbitCenterYRatio = 0.42,
    this.orbitItemSpacing = 0.28,
    this.orbitSelectedScale = 1.25,
    this.orbitDepth = 0.75,
    this.orbitVisibleItems = 5,
    this.orbitCardArtSize = 64.0,
    this.orbitCardWidthRatio = 0.68,
    this.orbitArtResolutionMultiplier = 2.0,
    this.orbitShowPath = true,
    this.orbitShowGlow = true,
    this.streaksEnabled = true,
    this.showMoreFromArtist = true,
    this.showMoreArtists = true,
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
    bool? artworkCardShowFrame,
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
    int? widgetCompactBgOpacity,
    bool? widgetCompactShowAlbumArt,
    bool? widgetCompactShowArtist,
    String? widgetCompactAccent,
    bool? lyricsMatchAudioFilename,
    String? leftActionButton,
    String? rightActionButton,
    bool? welcomeCardDismissed,
    bool? glanceCardHidden,
    bool? glanceCardMinimized,
    bool? replaceAlbumWithBitPerfectCapsule,
    bool? albumsStretchArtwork,
    bool? animatedAlbumArt,
    int? folderGridPageSize,
    String? lastSeenChangelogVersion,
    bool? bottomBarAutoCollapseEnabled,
    int? bottomBarAutoCollapseSeconds,
    String? miniPlayerSwipeAction,
    bool? keepPlayingOnQuit,
    bool? pauseOnBluetoothDisconnect,
    bool? resumeOnBluetoothReconnect,
    bool? pauseOnUsbDacDisconnect,
    String? preferredBluetoothDevice,
    int? btPreferredCodec,
    String? btLdacBitrate,
    bool? btAbsoluteVolumeSync,
    bool? btEnableCodecControl,
    int? btSampleRate,
    int? btLdacBitsPerSample,
    bool? floatingPlayerEnabled,
    bool? floatingIslandEnabled,
    bool? autoFocusSearch,
    String? searchPlaybackMode,
    String? refreshRateMode,
    bool? visualizerEnabled,
    double? orbitRadiusRatio,
    double? orbitCenterOffsetRatio,
    double? orbitCenterYRatio,
    double? orbitItemSpacing,
    double? orbitSelectedScale,
    double? orbitDepth,
    int? orbitVisibleItems,
    double? orbitCardArtSize,
    double? orbitCardWidthRatio,
    double? orbitArtResolutionMultiplier,
    bool? orbitShowPath,
    bool? orbitShowGlow,
    bool? streaksEnabled,
    bool? showMoreFromArtist,
    bool? showMoreArtists,
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
      artworkCardShowFrame: artworkCardShowFrame ?? this.artworkCardShowFrame,
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
      widgetCompactBgOpacity:
          widgetCompactBgOpacity ?? this.widgetCompactBgOpacity,
      widgetCompactShowAlbumArt:
          widgetCompactShowAlbumArt ?? this.widgetCompactShowAlbumArt,
      widgetCompactShowArtist:
          widgetCompactShowArtist ?? this.widgetCompactShowArtist,
      widgetCompactAccent: widgetCompactAccent ?? this.widgetCompactAccent,
      lyricsMatchAudioFilename:
          lyricsMatchAudioFilename ?? this.lyricsMatchAudioFilename,
      leftActionButton: leftActionButton ?? this.leftActionButton,
      rightActionButton: rightActionButton ?? this.rightActionButton,
      welcomeCardDismissed: welcomeCardDismissed ?? this.welcomeCardDismissed,
      glanceCardHidden: glanceCardHidden ?? this.glanceCardHidden,
      glanceCardMinimized: glanceCardMinimized ?? this.glanceCardMinimized,
      replaceAlbumWithBitPerfectCapsule:
          replaceAlbumWithBitPerfectCapsule ??
          this.replaceAlbumWithBitPerfectCapsule,
      albumsStretchArtwork:
          albumsStretchArtwork ?? this.albumsStretchArtwork,
      animatedAlbumArt: animatedAlbumArt ?? this.animatedAlbumArt,
      folderGridPageSize: folderGridPageSize ?? this.folderGridPageSize,
      lastSeenChangelogVersion:
          lastSeenChangelogVersion ?? this.lastSeenChangelogVersion,
      bottomBarAutoCollapseEnabled:
          bottomBarAutoCollapseEnabled ?? this.bottomBarAutoCollapseEnabled,
      bottomBarAutoCollapseSeconds:
          bottomBarAutoCollapseSeconds ?? this.bottomBarAutoCollapseSeconds,
      miniPlayerSwipeAction:
          miniPlayerSwipeAction ?? this.miniPlayerSwipeAction,
      keepPlayingOnQuit: keepPlayingOnQuit ?? this.keepPlayingOnQuit,
      pauseOnBluetoothDisconnect:
          pauseOnBluetoothDisconnect ?? this.pauseOnBluetoothDisconnect,
      resumeOnBluetoothReconnect:
          resumeOnBluetoothReconnect ?? this.resumeOnBluetoothReconnect,
      pauseOnUsbDacDisconnect:
          pauseOnUsbDacDisconnect ?? this.pauseOnUsbDacDisconnect,
      preferredBluetoothDevice:
          preferredBluetoothDevice ?? this.preferredBluetoothDevice,
      btPreferredCodec: btPreferredCodec ?? this.btPreferredCodec,
      btLdacBitrate: btLdacBitrate ?? this.btLdacBitrate,
      btAbsoluteVolumeSync:
          btAbsoluteVolumeSync ?? this.btAbsoluteVolumeSync,
      btEnableCodecControl:
          btEnableCodecControl ?? this.btEnableCodecControl,
      btSampleRate: btSampleRate ?? this.btSampleRate,
      btLdacBitsPerSample:
          btLdacBitsPerSample ?? this.btLdacBitsPerSample,
      floatingPlayerEnabled:
          floatingPlayerEnabled ?? this.floatingPlayerEnabled,
      floatingIslandEnabled:
          floatingIslandEnabled ?? this.floatingIslandEnabled,
      autoFocusSearch: autoFocusSearch ?? this.autoFocusSearch,
      searchPlaybackMode:
          searchPlaybackMode ?? this.searchPlaybackMode,
      refreshRateMode: refreshRateMode ?? this.refreshRateMode,
      visualizerEnabled: visualizerEnabled ?? this.visualizerEnabled,
      orbitRadiusRatio: orbitRadiusRatio ?? this.orbitRadiusRatio,
      orbitCenterOffsetRatio:
          orbitCenterOffsetRatio ?? this.orbitCenterOffsetRatio,
      orbitCenterYRatio: orbitCenterYRatio ?? this.orbitCenterYRatio,
      orbitItemSpacing: orbitItemSpacing ?? this.orbitItemSpacing,
      orbitSelectedScale: orbitSelectedScale ?? this.orbitSelectedScale,
      orbitDepth: orbitDepth ?? this.orbitDepth,
      orbitVisibleItems: orbitVisibleItems ?? this.orbitVisibleItems,
      orbitCardArtSize: orbitCardArtSize ?? this.orbitCardArtSize,
      orbitCardWidthRatio: orbitCardWidthRatio ?? this.orbitCardWidthRatio,
      orbitArtResolutionMultiplier:
          orbitArtResolutionMultiplier ?? this.orbitArtResolutionMultiplier,
      orbitShowPath: orbitShowPath ?? this.orbitShowPath,
      orbitShowGlow: orbitShowGlow ?? this.orbitShowGlow,
      streaksEnabled: streaksEnabled ?? this.streaksEnabled,
      showMoreFromArtist: showMoreFromArtist ?? this.showMoreFromArtist,
      showMoreArtists: showMoreArtists ?? this.showMoreArtists,
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
  static const _artworkCardShowFrameKey = 'artwork_card_show_frame';
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
  static const _widgetCompactBgOpacityKey = 'widget_compact_bg_opacity';
  static const _widgetCompactShowAlbumArtKey = 'widget_compact_show_album_art';
  static const _widgetCompactShowArtistKey = 'widget_compact_show_artist';
  static const _widgetCompactAccentKey = 'widget_compact_accent';
  static const _lyricsMatchAudioFilenameKey = 'lyrics_match_audio_filename';
  static const _leftActionButtonKey = 'left_action_button';
  static const _rightActionButtonKey = 'right_action_button';
  static const _welcomeCardDismissedKey = 'welcome_card_dismissed';
  static const _glanceCardHiddenKey = 'glance_card_hidden';
  static const _glanceCardMinimizedKey = 'glance_card_minimized';
  static const _replaceAlbumWithBitPerfectCapsuleKey =
      'replace_album_with_bit_perfect_capsule';
  static const _albumsStretchArtworkKey = 'albums_stretch_artwork';
  static const _animatedAlbumArtKey = 'album_animated_art';
  static const _folderGridPageSizeKey = 'folder_grid_page_size';
  static const _lastSeenChangelogVersionKey = 'last_seen_changelog_version';
  static const _bottomBarAutoCollapseEnabledKey =
      'bottom_bar_auto_collapse_enabled';
  static const _bottomBarAutoCollapseSecondsKey =
      'bottom_bar_auto_collapse_seconds';
  static const _miniPlayerSwipeActionKey = 'mini_player_swipe_action';
  static const _keepPlayingOnQuitKey = 'app_keep_playing_on_quit';
  static const _pauseOnBluetoothDisconnectKey =
      'app_pause_on_bluetooth_disconnect';
  static const _resumeOnBluetoothReconnectKey =
      'app_resume_on_bluetooth_reconnect';
  static const _pauseOnUsbDacDisconnectKey = 'app_pause_on_usb_dac_disconnect';
  static const _preferredBluetoothDeviceKey = 'app_preferred_bluetooth_device';
  static const _btPreferredCodecKey = 'app_bt_preferred_codec';
  static const _btLdacBitrateKey = 'app_bt_ldac_bitrate';
  static const _btAbsoluteVolumeSyncKey = 'app_bt_absolute_volume_sync';
  static const _btEnableCodecControlKey = 'app_bt_enable_codec_control';
  static const _btSampleRateKey = 'app_bt_sample_rate';
  static const _btLdacBitsPerSampleKey = 'app_bt_ldac_bits_per_sample';
  static const _floatingPlayerEnabledKey = 'app_floating_player_enabled';
  static const _floatingIslandEnabledKey = 'app_floating_island_enabled';
  static const _autoFocusSearchKey = 'app_auto_focus_search';
  static const _searchPlaybackModeKey = 'app_search_playback_mode';
  static const _refreshRateModeKey = 'app_refresh_rate_mode';
  static const _visualizerEnabledKey = 'visualizer_enabled';
  static const _orbitRadiusRatioKey = 'orbit_radius_ratio';
  static const _orbitCenterOffsetRatioKey = 'orbit_center_offset_ratio';
  static const _orbitCenterYRatioKey = 'orbit_center_y_ratio';
  static const _orbitItemSpacingKey = 'orbit_item_spacing';
  static const _orbitSelectedScaleKey = 'orbit_selected_scale';
  static const _orbitDepthKey = 'orbit_depth';
  static const _orbitVisibleItemsKey = 'orbit_visible_items';
  static const _orbitCardArtSizeKey = 'orbit_card_art_size';
  static const _orbitCardWidthRatioKey = 'orbit_card_width_ratio';
  static const _orbitArtResolutionMultiplierKey =
      'orbit_art_resolution_multiplier';
  static const _orbitShowPathKey = 'orbit_show_path';
  static const _orbitShowGlowKey = 'orbit_show_glow';
  static const _streaksEnabledKey = 'streaks_enabled';
  static const _showMoreFromArtistKey = 'album_show_more_from_artist';
  static const _showMoreArtistsKey = 'album_show_more_artists';
  static const _shuffleModeKey = 'playback_shuffle_mode';
  static const _loopModeKey = 'playback_loop_mode';
  static const _advanceListOrderKey = 'playback_advance_list_order';
  static const _wrapAroundQueueKey = 'playback_wrap_around_queue';

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
      artworkCardShowFrame: prefs.getBool(_artworkCardShowFrameKey) ?? true,
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
      widgetCompactBgOpacity:
          prefs.getInt(_widgetCompactBgOpacityKey) ?? 3,
      widgetCompactShowAlbumArt:
          prefs.getBool(_widgetCompactShowAlbumArtKey) ?? true,
      widgetCompactShowArtist:
          prefs.getBool(_widgetCompactShowArtistKey) ?? true,
      widgetCompactAccent:
          prefs.getString(_widgetCompactAccentKey) ?? 'white',
      lyricsMatchAudioFilename:
          prefs.getBool(_lyricsMatchAudioFilenameKey) ?? false,
      leftActionButton: prefs.getString(_leftActionButtonKey) ?? 'lyrics',
      rightActionButton: prefs.getString(_rightActionButtonKey) ?? 'favorites',
      welcomeCardDismissed: prefs.getBool(_welcomeCardDismissedKey) ?? false,
      glanceCardHidden: prefs.getBool(_glanceCardHiddenKey) ?? false,
      glanceCardMinimized: prefs.getBool(_glanceCardMinimizedKey) ?? false,
      replaceAlbumWithBitPerfectCapsule:
          prefs.getBool(_replaceAlbumWithBitPerfectCapsuleKey) ?? false,
      albumsStretchArtwork:
          prefs.getBool(_albumsStretchArtworkKey) ?? false,
      animatedAlbumArt: prefs.getBool(_animatedAlbumArtKey) ?? true,
      folderGridPageSize: prefs.getInt(_folderGridPageSizeKey) ?? 8,
      lastSeenChangelogVersion: prefs.getString(_lastSeenChangelogVersionKey),
      bottomBarAutoCollapseEnabled:
          prefs.getBool(_bottomBarAutoCollapseEnabledKey) ?? false,
      bottomBarAutoCollapseSeconds:
          prefs.getInt(_bottomBarAutoCollapseSecondsKey) ?? 5,
      miniPlayerSwipeAction:
          prefs.getString(_miniPlayerSwipeActionKey) ?? 'visualizer',
      keepPlayingOnQuit: prefs.getBool(_keepPlayingOnQuitKey) ?? false,
      pauseOnBluetoothDisconnect:
          prefs.getBool(_pauseOnBluetoothDisconnectKey) ?? true,
      resumeOnBluetoothReconnect:
          prefs.getBool(_resumeOnBluetoothReconnectKey) ?? false,
      pauseOnUsbDacDisconnect:
          prefs.getBool(_pauseOnUsbDacDisconnectKey) ?? true,
      preferredBluetoothDevice:
          prefs.getString(_preferredBluetoothDeviceKey) ?? '',
      btPreferredCodec: prefs.getInt(_btPreferredCodecKey) ?? -1,
      btLdacBitrate: prefs.getString(_btLdacBitrateKey) ?? 'adaptive',
      btAbsoluteVolumeSync:
          prefs.getBool(_btAbsoluteVolumeSyncKey) ?? false,
      btEnableCodecControl:
          prefs.getBool(_btEnableCodecControlKey) ?? false,
      btSampleRate: prefs.getInt(_btSampleRateKey) ?? 0,
      btLdacBitsPerSample: prefs.getInt(_btLdacBitsPerSampleKey) ?? 0,
      floatingPlayerEnabled:
          prefs.getBool(_floatingPlayerEnabledKey) ?? false,
      floatingIslandEnabled:
          prefs.getBool(_floatingIslandEnabledKey) ?? true,
      autoFocusSearch: prefs.getBool(_autoFocusSearchKey) ?? false,
      searchPlaybackMode:
          prefs.getString(_searchPlaybackModeKey) ?? 'results',
      refreshRateMode: prefs.getString(_refreshRateModeKey) ?? 'high',
      visualizerEnabled: prefs.getBool(_visualizerEnabledKey) ?? true,
      orbitRadiusRatio: prefs.getDouble(_orbitRadiusRatioKey) ?? 1.0,
      orbitCenterOffsetRatio:
          prefs.getDouble(_orbitCenterOffsetRatioKey) ?? -0.5,
      orbitCenterYRatio: prefs.getDouble(_orbitCenterYRatioKey) ?? 0.42,
      orbitItemSpacing: prefs.getDouble(_orbitItemSpacingKey) ?? 0.28,
      orbitSelectedScale: prefs.getDouble(_orbitSelectedScaleKey) ?? 1.25,
      orbitDepth: prefs.getDouble(_orbitDepthKey) ?? 0.75,
      orbitVisibleItems: prefs.getInt(_orbitVisibleItemsKey) ?? 5,
      orbitCardArtSize: prefs.getDouble(_orbitCardArtSizeKey) ?? 64.0,
      orbitCardWidthRatio: prefs.getDouble(_orbitCardWidthRatioKey) ?? 0.68,
      orbitArtResolutionMultiplier:
          prefs.getDouble(_orbitArtResolutionMultiplierKey) ?? 2.0,
      orbitShowPath: prefs.getBool(_orbitShowPathKey) ?? true,
      orbitShowGlow: prefs.getBool(_orbitShowGlowKey) ?? true,
      streaksEnabled: prefs.getBool(_streaksEnabledKey) ?? true,
      showMoreFromArtist: prefs.getBool(_showMoreFromArtistKey) ?? true,
      showMoreArtists: prefs.getBool(_showMoreArtistsKey) ?? true,
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

  Future<bool> getArtworkCardShowFrame() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_artworkCardShowFrameKey) ?? true;
  }

  Future<void> setArtworkCardShowFrame(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_artworkCardShowFrameKey, value);
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

  Future<int> getWidgetCompactBgOpacity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_widgetCompactBgOpacityKey) ?? 3;
  }

  Future<void> setWidgetCompactBgOpacity(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_widgetCompactBgOpacityKey, value);
  }

  Future<bool> getWidgetCompactShowAlbumArt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_widgetCompactShowAlbumArtKey) ?? true;
  }

  Future<void> setWidgetCompactShowAlbumArt(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_widgetCompactShowAlbumArtKey, value);
  }

  Future<bool> getWidgetCompactShowArtist() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_widgetCompactShowArtistKey) ?? true;
  }

  Future<void> setWidgetCompactShowArtist(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_widgetCompactShowArtistKey, value);
  }

  Future<String> getWidgetCompactAccent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_widgetCompactAccentKey) ?? 'white';
  }

  Future<void> setWidgetCompactAccent(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_widgetCompactAccentKey, value);
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

  Future<bool> getGlanceCardHidden() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_glanceCardHiddenKey) ?? false;
  }

  Future<void> setGlanceCardHidden(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_glanceCardHiddenKey, value);
  }

  Future<bool> getGlanceCardMinimized() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_glanceCardMinimizedKey) ?? false;
  }

  Future<void> setGlanceCardMinimized(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_glanceCardMinimizedKey, value);
  }

  Future<bool> getReplaceAlbumWithBitPerfectCapsule() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_replaceAlbumWithBitPerfectCapsuleKey) ?? false;
  }

  Future<void> setReplaceAlbumWithBitPerfectCapsule(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_replaceAlbumWithBitPerfectCapsuleKey, value);
  }

  Future<bool> getAlbumsStretchArtwork() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_albumsStretchArtworkKey) ?? false;
  }

  Future<void> setAlbumsStretchArtwork(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_albumsStretchArtworkKey, value);
  }

  Future<bool> getAnimatedAlbumArt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_animatedAlbumArtKey) ?? true;
  }

  Future<void> setAnimatedAlbumArt(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_animatedAlbumArtKey, value);
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

  Future<String> getMiniPlayerSwipeAction() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_miniPlayerSwipeActionKey) ?? 'visualizer';
  }

  Future<void> setMiniPlayerSwipeAction(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_miniPlayerSwipeActionKey, value);
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

  Future<bool> getWrapAroundQueue() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_wrapAroundQueueKey) ?? true;
  }

  Future<void> setWrapAroundQueue(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wrapAroundQueueKey, value);
  }

  Future<bool> getKeepPlayingOnQuit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keepPlayingOnQuitKey) ?? false;
  }

  Future<void> setKeepPlayingOnQuit(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keepPlayingOnQuitKey, value);
  }

  Future<bool> getPauseOnBluetoothDisconnect() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pauseOnBluetoothDisconnectKey) ?? true;
  }

  Future<void> setPauseOnBluetoothDisconnect(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pauseOnBluetoothDisconnectKey, value);
  }

  Future<bool> getPauseOnUsbDacDisconnect() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pauseOnUsbDacDisconnectKey) ?? true;
  }

  Future<void> setPauseOnUsbDacDisconnect(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pauseOnUsbDacDisconnectKey, value);
  }

  Future<bool> getResumeOnBluetoothReconnect() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_resumeOnBluetoothReconnectKey) ?? false;
  }

  Future<void> setResumeOnBluetoothReconnect(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_resumeOnBluetoothReconnectKey, value);
  }

  Future<String> getPreferredBluetoothDevice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_preferredBluetoothDeviceKey) ?? '';
  }

  Future<void> setPreferredBluetoothDevice(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferredBluetoothDeviceKey, value);
  }

  Future<int> getBtPreferredCodec() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_btPreferredCodecKey) ?? -1;
  }

  Future<void> setBtPreferredCodec(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_btPreferredCodecKey, value);
  }

  Future<String> getBtLdacBitrate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_btLdacBitrateKey) ?? 'adaptive';
  }

  Future<void> setBtLdacBitrate(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_btLdacBitrateKey, value);
  }

  Future<bool> getBtAbsoluteVolumeSync() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_btAbsoluteVolumeSyncKey) ?? false;
  }

  Future<void> setBtAbsoluteVolumeSync(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_btAbsoluteVolumeSyncKey, value);
  }

  Future<bool> getBtEnableCodecControl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_btEnableCodecControlKey) ?? false;
  }

  Future<void> setBtEnableCodecControl(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_btEnableCodecControlKey, value);
  }

  Future<int> getBtSampleRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_btSampleRateKey) ?? 0;
  }

  Future<void> setBtSampleRate(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_btSampleRateKey, value);
  }

  Future<int> getBtLdacBitsPerSample() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_btLdacBitsPerSampleKey) ?? 0;
  }

  Future<void> setBtLdacBitsPerSample(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_btLdacBitsPerSampleKey, value);
  }

  Future<bool> getFloatingPlayerEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_floatingPlayerEnabledKey) ?? false;
  }

  Future<void> setFloatingPlayerEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_floatingPlayerEnabledKey, value);
  }

  Future<bool> getFloatingIslandEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_floatingIslandEnabledKey) ?? true;
  }

  Future<void> setFloatingIslandEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_floatingIslandEnabledKey, value);
  }

  Future<bool> getAutoFocusSearch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoFocusSearchKey) ?? false;
  }

  Future<void> setAutoFocusSearch(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoFocusSearchKey, value);
  }

  Future<String> getSearchPlaybackMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_searchPlaybackModeKey) ?? 'results';
  }

  Future<void> setSearchPlaybackMode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_searchPlaybackModeKey, value);
  }

  Future<String> getRefreshRateMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshRateModeKey) ?? 'high';
  }

  Future<void> setRefreshRateMode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshRateModeKey, value);
  }

  Future<bool> getVisualizerEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_visualizerEnabledKey) ?? true;
  }

  Future<void> setVisualizerEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_visualizerEnabledKey, value);
  }

  Future<void> setOrbitRadiusRatio(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_orbitRadiusRatioKey, value);
  }

  Future<void> setOrbitCenterOffsetRatio(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_orbitCenterOffsetRatioKey, value);
  }

  Future<void> setOrbitCenterYRatio(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_orbitCenterYRatioKey, value);
  }

  Future<void> setOrbitItemSpacing(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_orbitItemSpacingKey, value);
  }

  Future<void> setOrbitSelectedScale(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_orbitSelectedScaleKey, value);
  }

  Future<void> setOrbitDepth(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_orbitDepthKey, value);
  }

  Future<void> setOrbitVisibleItems(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_orbitVisibleItemsKey, value);
  }

  Future<void> setOrbitCardArtSize(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_orbitCardArtSizeKey, value);
  }

  Future<void> setOrbitCardWidthRatio(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_orbitCardWidthRatioKey, value);
  }

  Future<void> setOrbitArtResolutionMultiplier(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_orbitArtResolutionMultiplierKey, value);
  }

  Future<void> setOrbitShowPath(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_orbitShowPathKey, value);
  }

  Future<void> setOrbitShowGlow(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_orbitShowGlowKey, value);
  }

  Future<bool> getStreaksEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_streaksEnabledKey) ?? true;
  }

  Future<void> setStreaksEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_streaksEnabledKey, value);
  }

  Future<bool> getShowMoreFromArtist() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showMoreFromArtistKey) ?? true;
  }

  Future<void> setShowMoreFromArtist(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showMoreFromArtistKey, value);
  }

  Future<bool> getShowMoreArtists() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showMoreArtistsKey) ?? true;
  }

  Future<void> setShowMoreArtists(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showMoreArtistsKey, value);
  }

  Future<void> clearOrbitSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_orbitRadiusRatioKey);
    await prefs.remove(_orbitCenterOffsetRatioKey);
    await prefs.remove(_orbitCenterYRatioKey);
    await prefs.remove(_orbitItemSpacingKey);
    await prefs.remove(_orbitSelectedScaleKey);
    await prefs.remove(_orbitDepthKey);
    await prefs.remove(_orbitVisibleItemsKey);
    await prefs.remove(_orbitCardArtSizeKey);
    await prefs.remove(_orbitCardWidthRatioKey);
    await prefs.remove(_orbitArtResolutionMultiplierKey);
    await prefs.remove(_orbitShowPathKey);
    await prefs.remove(_orbitShowGlowKey);
  }
}
