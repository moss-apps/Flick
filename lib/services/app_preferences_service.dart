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
  final double immersiveTextScale;
  final double immersiveVerticalOffset;
  final double immersiveFullViewScale;

  const AppPreferences({
    this.animationsEnabled = true,
    this.hapticsEnabled = true,
    this.showSmartMixes = true,
    this.showRecentArtists = true,
    this.showRecentTracks = true,
    this.showPlaylistPreviews = true,
    this.showBrowseMore = true,
    this.showQuickAccess = true,
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
    this.immersiveTextScale = 1.0,
    this.immersiveVerticalOffset = 0.0,
    this.immersiveFullViewScale = 1.0,
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
    double? immersiveTextScale,
    double? immersiveVerticalOffset,
    double? immersiveFullViewScale,
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
      immersiveTextScale: immersiveTextScale ?? this.immersiveTextScale,
      immersiveVerticalOffset:
          immersiveVerticalOffset ?? this.immersiveVerticalOffset,
      immersiveFullViewScale:
          immersiveFullViewScale ?? this.immersiveFullViewScale,
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
  static const _immersiveTextScaleKey = 'immersive_text_scale';
  static const _immersiveVerticalOffsetKey = 'immersive_vertical_offset';
  static const _immersiveFullViewScaleKey = 'immersive_full_view_scale';

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
      immersiveTextScale: prefs.getDouble(_immersiveTextScaleKey) ?? 1.0,
      immersiveVerticalOffset:
          prefs.getDouble(_immersiveVerticalOffsetKey) ?? 0.0,
      immersiveFullViewScale:
          prefs.getDouble(_immersiveFullViewScaleKey) ?? 1.0,
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
}
