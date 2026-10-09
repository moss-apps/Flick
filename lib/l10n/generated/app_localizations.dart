import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// lib/features/settings/screens/playback_display_settings_screen.dart:85
  ///
  /// In en, this message translates to:
  /// **'A draggable overlay shows while using other apps'**
  String get aDraggableOverlayShowsWhileUsing;

  /// lib/features/playlists/screens/playlists_screen.dart:444
  ///
  /// In en, this message translates to:
  /// **'A playlist with this name already exists'**
  String get aPlaylistWithThisNameAlready;

  /// lib/features/settings/screens/app_info_settings_screen.dart:470
  ///
  /// In en, this message translates to:
  /// **'A premium music player with custom UAC 2.0 powered by Rust for the best audio experience.'**
  String get aPremiumMusicPlayerWithCustom;

  /// lib/features/settings/screens/visualizer_settings_screen.dart:87
  ///
  /// In en, this message translates to:
  /// **'A smooth continuous wave across frequencies'**
  String get aSmoothContinuousWaveAcrossFrequencies;

  /// lib/features/settings/widgets/mini_player_customization.dart:369
  ///
  /// In en, this message translates to:
  /// **'A song with a long title to preview'**
  String get aSongWithALongTitle;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:680
  ///
  /// In en, this message translates to:
  /// **'AAudio'**
  String get aaudio;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:638
  ///
  /// In en, this message translates to:
  /// **'AAudio (Android 8.1+)'**
  String get aaudioAndroid81;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:637
  ///
  /// In en, this message translates to:
  /// **'AAudio with OpenSL ES fallback (default)'**
  String get aaudioWithOpenslEsFallbackDefault;

  /// lib/features/artists/screens/artist_detail_screen.dart:654
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// lib/features/settings/screens/app_info_settings_screen.dart:419
  ///
  /// In en, this message translates to:
  /// **'About Flick Player'**
  String get aboutFlickPlayer;

  /// lib/features/albums/screens/album_detail_screen.dart:519
  ///
  /// In en, this message translates to:
  /// **'About this album'**
  String get aboutThisAlbum;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:398
  ///
  /// In en, this message translates to:
  /// **'Absolute Volume Sync'**
  String get absoluteVolumeSync;

  /// lib/features/settings/screens/widget_settings_screen.dart:263
  ///
  /// In en, this message translates to:
  /// **'Accent Color'**
  String get accentColor;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:1102
  ///
  /// In en, this message translates to:
  /// **'AccurateRip'**
  String get accuraterip;

  /// lib/widgets/uac2/uac2_fallback_manager.dart:179
  ///
  /// In en, this message translates to:
  /// **'Activate Fallback'**
  String get activateFallback;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:670
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// lib/features/settings/screens/equalizer_screen.dart:2166
  ///
  /// In en, this message translates to:
  /// **'{activeCount} active bands'**
  String activeBands(Object activeCount);

  /// lib/features/settings/screens/interface_settings_screen.dart:276
  ///
  /// In en, this message translates to:
  /// **'Active Queue'**
  String get activeQueue;

  /// lib/features/settings/screens/interface_settings_screen.dart:211
  ///
  /// In en, this message translates to:
  /// **'Adaptive'**
  String get adaptive;

  /// lib/features/settings/screens/equalizer_screen.dart:3016
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// lib/features/songs/screens/songs_screen.dart:1847
  ///
  /// In en, this message translates to:
  /// **'Add a music folder in Settings'**
  String get addAMusicFolderInSettings;

  /// lib/features/settings/widgets/mini_player_customization.dart:185
  ///
  /// In en, this message translates to:
  /// **'Add a next-track button'**
  String get addANextTrackButton;

  /// lib/features/settings/widgets/mini_player_customization.dart:177
  ///
  /// In en, this message translates to:
  /// **'Add a previous-track button'**
  String get addAPreviousTrackButton;

  /// lib/features/player/screens/lyrics_sync_screen.dart:475
  ///
  /// In en, this message translates to:
  /// **'Add at least one lyric line first.'**
  String get addAtLeastOneLyricLine;

  /// lib/features/albums/screens/album_detail_screen.dart:313
  ///
  /// In en, this message translates to:
  /// **'Add Description'**
  String get addDescription;

  /// lib/features/albums/screens/album_detail_screen.dart:338
  ///
  /// In en, this message translates to:
  /// **'Add description'**
  String get addDescription2;

  /// lib/features/settings/screens/library_settings_screen.dart:2117
  ///
  /// In en, this message translates to:
  /// **'Add Music Folder'**
  String get addMusicFolder;

  /// lib/features/folders/screens/folders_screen.dart:376
  ///
  /// In en, this message translates to:
  /// **'Add music folders in Settings'**
  String get addMusicFoldersInSettings;

  /// lib/features/albums/screens/albums_screen.dart:450
  ///
  /// In en, this message translates to:
  /// **'Add music with album tags to see them here'**
  String get addMusicWithAlbumTagsTo;

  /// lib/features/artists/screens/artists_screen.dart:485
  ///
  /// In en, this message translates to:
  /// **'Add music with artist tags to see them here'**
  String get addMusicWithArtistTagsTo;

  /// lib/features/settings/screens/network_sources_screen.dart:154
  ///
  /// In en, this message translates to:
  /// **'Add Server'**
  String get addServer;

  /// lib/features/songs/screens/songs_screen.dart:1407
  ///
  /// In en, this message translates to:
  /// **'Add {arg1} songs to playlist'**
  String addSongsToPlaylist(Object arg1);

  /// lib/features/player/widgets/add_to_playlist_sheet.dart:52
  ///
  /// In en, this message translates to:
  /// **'Add {arg1} Songs to Playlist'**
  String addSongsToPlaylist2(Object arg1);

  /// lib/features/songs/screens/songs_screen.dart:2008
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addToFavorites;

  /// lib/features/songs/widgets/song_actions_bottom_sheet.dart:88
  ///
  /// In en, this message translates to:
  /// **'Add to Favorites'**
  String get addToFavorites2;

  /// lib/features/albums/screens/album_detail_screen.dart:344
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get addToPlaylist;

  /// lib/features/player/widgets/song_actions_sheet.dart:211
  ///
  /// In en, this message translates to:
  /// **'Add to Playlist'**
  String get addToPlaylist2;

  /// lib/features/player/widgets/song_actions_sheet.dart:202
  ///
  /// In en, this message translates to:
  /// **'Add to Queue'**
  String get addToQueue;

  /// lib/features/songs/screens/songs_screen.dart:2000
  ///
  /// In en, this message translates to:
  /// **'Add to queue'**
  String get addToQueue2;

  /// lib/features/player/widgets/add_to_playlist_sheet.dart:158
  ///
  /// In en, this message translates to:
  /// **'Added {arg1} songs to \"{arg2}\"'**
  String addedSongsTo(Object arg1, Object arg2);

  /// lib/features/songs/screens/songs_screen.dart:1489
  ///
  /// In en, this message translates to:
  /// **'Added {arg1} songs to {playlistName}'**
  String addedSongsTo2(Object arg1, Object playlistName);

  /// lib/features/albums/screens/album_detail_screen.dart:300
  ///
  /// In en, this message translates to:
  /// **'Added {arg1} songs to favorites'**
  String addedSongsToFavorites(Object arg1);

  /// lib/features/songs/screens/songs_screen.dart:1363
  ///
  /// In en, this message translates to:
  /// **'Added {arg1} songs to favorites'**
  String addedSongsToFavorites3(Object arg1);

  /// lib/features/songs/widgets/song_actions_bottom_sheet.dart:493
  ///
  /// In en, this message translates to:
  /// **'Added to {arg1}'**
  String addedTo(Object arg1);

  /// lib/features/player/widgets/add_to_playlist_sheet.dart:157
  ///
  /// In en, this message translates to:
  /// **'Added to \"{arg1}\"'**
  String addedTo2(Object arg1);

  /// lib/features/player/widgets/player_action_button_row.dart:487
  ///
  /// In en, this message translates to:
  /// **'Added to favorites'**
  String get addedToFavorites;

  /// lib/features/songs/screens/songs_screen.dart:1297
  ///
  /// In en, this message translates to:
  /// **'Added \"{arg1}\" to favorites'**
  String addedToFavorites2(Object arg1);

  /// lib/features/settings/screens/equalizer_screen.dart:3393
  ///
  /// In en, this message translates to:
  /// **'Adds pre-drive and catches peaks against a final output ceiling.'**
  String get addsPreDriveAndCatchesPeaks;

  /// lib/features/settings/screens/audio_settings_screen.dart:63
  ///
  /// In en, this message translates to:
  /// **'Adjust audio frequencies'**
  String get adjustAudioFrequencies;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:256
  ///
  /// In en, this message translates to:
  /// **'Adjust metadata text size in artwork card mode'**
  String get adjustMetadataTextSizeInArtwork;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:133
  ///
  /// In en, this message translates to:
  /// **'Adjust metadata text size in immersive mode'**
  String get adjustMetadataTextSizeInImmersive;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:275
  ///
  /// In en, this message translates to:
  /// **'Adjust spacing between buttons'**
  String get adjustSpacingBetweenButtons;

  /// lib/features/settings/widgets/mini_player_customization.dart:198
  ///
  /// In en, this message translates to:
  /// **'Adjust the mini player surface'**
  String get adjustTheMiniPlayerSurface;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:259
  ///
  /// In en, this message translates to:
  /// **'Adjust the size of the bottom bar'**
  String get adjustTheSizeOfTheBottom;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:291
  ///
  /// In en, this message translates to:
  /// **'Adjust the size of the icons'**
  String get adjustTheSizeOfTheIcons;

  /// lib/models/advance_list_order.dart:15
  ///
  /// In en, this message translates to:
  /// **'Advance to a random category'**
  String get advanceToARandomCategory;

  /// lib/models/advance_list_order.dart:13
  ///
  /// In en, this message translates to:
  /// **'Advance to the next category alphabetically'**
  String get advanceToTheNextCategoryAlphabetically;

  /// lib/models/advance_list_order.dart:14
  ///
  /// In en, this message translates to:
  /// **'Advance to the next most recently added category'**
  String get advanceToTheNextMostRecently;

  /// lib/features/player/screens/lyrics_sync_screen.dart:905
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// lib/features/player/screens/lyrics_sync_screen.dart:686
  ///
  /// In en, this message translates to:
  /// **'Advanced mode'**
  String get advancedMode;

  /// lib/features/settings/widgets/apple_music_settings_tile.dart:40
  ///
  /// In en, this message translates to:
  /// **'After scanning, match files with missing tags against Apple Music. Only confident matches apply automatically.'**
  String get afterScanningMatchFilesWithMissing;

  /// lib/features/settings/screens/equalizer_screen.dart:1891
  ///
  /// In en, this message translates to:
  /// **'Air'**
  String get air;

  /// lib/widgets/alac_conversion_indicator.dart:128
  ///
  /// In en, this message translates to:
  /// **'ALAC Audio'**
  String get alacAudio;

  /// lib/widgets/alac_conversion_indicator.dart:79
  ///
  /// In en, this message translates to:
  /// **'ALAC {arg1}-bit'**
  String alacBit(Object arg1);

  /// lib/features/albums/widgets/identify_album_sheet.dart:263
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get album;

  /// lib/features/settings/screens/widget_settings_screen.dart:200
  ///
  /// In en, this message translates to:
  /// **'Album Art'**
  String get albumArt;

  /// lib/features/settings/screens/privacy_policy_screen.dart:64
  ///
  /// In en, this message translates to:
  /// **'Album Art Import'**
  String get albumArtImport;

  /// lib/features/player/widgets/song_metadata_sheet.dart:68
  ///
  /// In en, this message translates to:
  /// **'Album Artist'**
  String get albumArtist;

  /// lib/features/search/models/search_category.dart:24
  ///
  /// In en, this message translates to:
  /// **'Album Artists'**
  String get albumArtists;

  /// lib/features/settings/screens/library_settings_screen.dart:2190
  ///
  /// In en, this message translates to:
  /// **'Album Artwork'**
  String get albumArtwork;

  /// lib/features/player/widgets/player_layout_sheet.dart:395
  ///
  /// In en, this message translates to:
  /// **'Album Colors'**
  String get albumColors;

  /// lib/features/artists/screens/artists_screen.dart:878
  ///
  /// In en, this message translates to:
  /// **'Album Count'**
  String get albumCount;

  /// lib/features/songs/screens/songs_screen.dart:2958
  ///
  /// In en, this message translates to:
  /// **'ALBUM LIMIT'**
  String get albumLimit;

  /// lib/features/albums/screens/albums_screen.dart:916
  ///
  /// In en, this message translates to:
  /// **'Album Name'**
  String get albumName;

  /// lib/features/songs/screens/songs_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Album options'**
  String get albumOptions;

  /// lib/features/albums/screens/albums_screen.dart:252
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get albums;

  /// lib/features/albums/screens/albums_screen.dart:260
  ///
  /// In en, this message translates to:
  /// **'{arg1} albums'**
  String albums2(Object arg1);

  /// lib/features/artists/screens/artists_screen.dart:401
  ///
  /// In en, this message translates to:
  /// **'{_totalAlbums} albums'**
  String albums3(Object _totalAlbums);

  /// lib/features/songs/screens/songs_screen.dart:2968
  ///
  /// In en, this message translates to:
  /// **'Albums shown per page'**
  String get albumsShownPerPage;

  /// lib/features/artists/screens/artist_detail_screen.dart:620
  ///
  /// In en, this message translates to:
  /// **'{arg1} albums • {arg2} songs'**
  String albumsSongs(Object arg1, Object arg2);

  /// lib/features/settings/screens/lyrics_settings_screen.dart:69
  ///
  /// In en, this message translates to:
  /// **'Align lyric text to the center'**
  String get alignLyricTextToTheCenter;

  /// lib/features/settings/screens/lyrics_settings_screen.dart:57
  ///
  /// In en, this message translates to:
  /// **'Align lyric text to the left edge'**
  String get alignLyricTextToTheLeft;

  /// lib/features/settings/screens/lyrics_settings_screen.dart:81
  ///
  /// In en, this message translates to:
  /// **'Align lyric text to the right edge'**
  String get alignLyricTextToTheRight;

  /// lib/features/search/widgets/search_filter_chips.dart:60
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// lib/features/artists/screens/artists_screen.dart:511
  ///
  /// In en, this message translates to:
  /// **'All Artists'**
  String get allArtists;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:264
  ///
  /// In en, this message translates to:
  /// **'All clear — no duplicates'**
  String get allClearNoDuplicates;

  /// lib/features/settings/screens/privacy_policy_screen.dart:41
  ///
  /// In en, this message translates to:
  /// **'All data is stored locally on your device only: music library metadata, play history, playlists, equalizer presets, and app preferences. Last.fm credentials are stored securely on-device. This data never leaves your device unless you explicitly use an integration.'**
  String get allDataIsStoredLocallyOn;

  /// lib/features/settings/screens/library_settings_screen.dart:682
  ///
  /// In en, this message translates to:
  /// **'All Folders'**
  String get allFolders;

  /// lib/providers/songs_provider.dart:116
  ///
  /// In en, this message translates to:
  /// **'All Formats'**
  String get allFormats;

  /// lib/features/settings/screens/visualizer_settings_screen.dart:125
  ///
  /// In en, this message translates to:
  /// **'All frequencies equally'**
  String get allFrequenciesEqually;

  /// lib/providers/equalizer_provider.dart:41
  ///
  /// In en, this message translates to:
  /// **'All Pass'**
  String get allPass;

  /// lib/features/player/widgets/online_lyrics_search_sheet.dart:701
  ///
  /// In en, this message translates to:
  /// **'All results are hidden by active filters.'**
  String get allResultsAreHiddenByActive;

  /// lib/models/playback_context.dart:15
  ///
  /// In en, this message translates to:
  /// **'All Songs'**
  String get allSongs;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1392
  ///
  /// In en, this message translates to:
  /// **'All words stamped'**
  String get allWordsStamped;

  /// lib/features/settings/screens/library_settings_screen.dart:1982
  ///
  /// In en, this message translates to:
  /// **'Allow Flick to run without aggressive background limits so rescans and background features keep working'**
  String get allowFlickToRunWithoutAggressive;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:683
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get allowed;

  /// lib/models/advance_list_order.dart:7
  ///
  /// In en, this message translates to:
  /// **'Alphabetical'**
  String get alphabetical;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:193
  ///
  /// In en, this message translates to:
  /// **'Alphabetical index rail on the songs screen'**
  String get alphabeticalIndexRailOnTheSongs;

  /// lib/features/settings/widgets/mini_player_customization.dart:234
  ///
  /// In en, this message translates to:
  /// **'Also respects your system text size'**
  String get alsoRespectsYourSystemTextSize;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:1003
  ///
  /// In en, this message translates to:
  /// **'Alt {arg1}'**
  String alt(Object arg1);

  /// lib/features/settings/screens/widget_settings_screen.dart:275
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get amber;

  /// lib/features/settings/screens/library_settings_screen.dart:2141
  ///
  /// In en, this message translates to:
  /// **'Analyze loudness and write ReplayGain tags for all songs'**
  String get analyzeLoudnessAndWriteReplaygainTags;

  /// lib/features/settings/screens/library_settings_screen.dart:798
  ///
  /// In en, this message translates to:
  /// **'Analyzing audio'**
  String get analyzingAudio;

  /// lib/features/settings/screens/library_settings_screen.dart:825
  ///
  /// In en, this message translates to:
  /// **'Analyzing loudness'**
  String get analyzingLoudness;

  /// lib/features/albums/widgets/identify_album_sheet.dart:58
  ///
  /// In en, this message translates to:
  /// **' and artwork'**
  String get andArtwork;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:346
  ///
  /// In en, this message translates to:
  /// **'Android Audio API'**
  String get androidAudioApi;

  /// lib/services/metadata_editor_service.dart:184
  ///
  /// In en, this message translates to:
  /// **'Android blocked writing to this file. Remove and re-add the folder in Settings to grant edit access, then try again.'**
  String get androidBlockedWritingToThisFile;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:352
  ///
  /// In en, this message translates to:
  /// **'Android Developer Options — the reliable way to switch codec (in-app forcing uses a hidden system API that is blocked on stock Android)'**
  String get androidDeveloperOptionsTheReliableWay;

  /// lib/features/settings/screens/uac2_settings_screen.dart:931
  ///
  /// In en, this message translates to:
  /// **'Android dock route'**
  String get androidDockRoute;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:797
  ///
  /// In en, this message translates to:
  /// **'Android-managed Rust playback path using the native Oboe backend.'**
  String get androidManagedRustPlaybackPathUsing;

  /// lib/features/settings/screens/uac2_settings_screen.dart:925
  ///
  /// In en, this message translates to:
  /// **'Android USB route'**
  String get androidUsbRoute;

  /// lib/features/settings/screens/ui_customization_settings_screen.dart:166
  ///
  /// In en, this message translates to:
  /// **'Animated Album Art'**
  String get animatedAlbumArt;

  /// lib/features/settings/screens/visualizer_settings_screen.dart:65
  ///
  /// In en, this message translates to:
  /// **'Animation Style'**
  String get animationStyle;

  /// lib/features/settings/screens/interface_settings_screen.dart:194
  ///
  /// In en, this message translates to:
  /// **'Animation style and frequency focus'**
  String get animationStyleAndFrequencyFocus;

  /// lib/features/settings/screens/interface_settings_screen.dart:87
  ///
  /// In en, this message translates to:
  /// **'Animations'**
  String get animations;

  /// lib/features/settings/screens/settings_screen.dart:187
  ///
  /// In en, this message translates to:
  /// **'Animations and haptic feedback'**
  String get animationsAndHapticFeedback;

  /// lib/features/settings/widgets/lastfm_settings_tile.dart:447
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get apiKey;

  /// lib/features/settings/screens/app_info_settings_screen.dart:598
  ///
  /// In en, this message translates to:
  /// **'App Info'**
  String get appInfo;

  /// Application name. Used by MaterialApp.onGenerateTitle and shown in the Android task switcher.
  ///
  /// In en, this message translates to:
  /// **'Flick Player'**
  String get appTitle;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:253
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:394
  ///
  /// In en, this message translates to:
  /// **'Appears in the overflow menu'**
  String get appearsInTheOverflowMenu;

  /// lib/features/albums/screens/album_detail_screen.dart:417
  ///
  /// In en, this message translates to:
  /// **'Apple Music data unavailable'**
  String get appleMusicDataUnavailable;

  /// lib/features/albums/screens/album_detail_screen.dart:416
  ///
  /// In en, this message translates to:
  /// **'Apple Music data updated'**
  String get appleMusicDataUpdated;

  /// lib/features/albums/widgets/identify_album_sheet.dart:141
  ///
  /// In en, this message translates to:
  /// **'Apple Music lookup failed. Check your connection.'**
  String get appleMusicLookupFailedCheckYour;

  /// lib/features/settings/screens/ui_customization_settings_screen.dart:168
  ///
  /// In en, this message translates to:
  /// **'Apple Music Motion Art on albums plus pan/zoom, ambient glow and smooth fade on heroes'**
  String get appleMusicMotionArtOnAlbums;

  /// lib/features/settings/screens/equalizer_screen.dart:497
  ///
  /// In en, this message translates to:
  /// **'Applied AutoEQ for {arg1}'**
  String appliedAutoeqFor(Object arg1);

  /// lib/features/settings/screens/equalizer_screen.dart:1073
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// lib/features/settings/screens/widgets/autoeq_search_sheet.dart:433
  ///
  /// In en, this message translates to:
  /// **'Apply {arg1}'**
  String apply2(Object arg1);

  /// lib/features/songs/widgets/album_art_picker_bottom_sheet.dart:351
  ///
  /// In en, this message translates to:
  /// **'Apply Selected'**
  String get applySelected;

  /// lib/features/albums/widgets/identify_album_sheet.dart:581
  ///
  /// In en, this message translates to:
  /// **'Apply to {count, plural, =1{{count} song} other{{count} songs}}'**
  String applyTo(int count);

  /// lib/features/milestone/screens/milestones_screen.dart:505
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get apr;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:596
  ///
  /// In en, this message translates to:
  /// **'aptX Adaptive'**
  String get aptxAdaptive;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:595
  ///
  /// In en, this message translates to:
  /// **'aptX HD'**
  String get aptxHd;

  /// lib/features/recently_played/screens/recently_played_screen.dart:198
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear your entire listening history? This cannot be undone.'**
  String get areYouSureYouWantTo2;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1440
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reset all UAC2 preferences? This action cannot be undone.'**
  String get areYouSureYouWantTo3;

  /// lib/features/settings/screens/orbit_settings_screen.dart:137
  ///
  /// In en, this message translates to:
  /// **'Art Resolution'**
  String get artResolution;

  /// lib/features/albums/widgets/identify_album_sheet.dart:254
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get artist;

  /// lib/features/player/widgets/player_navigation.dart:45
  ///
  /// In en, this message translates to:
  /// **'Artist is not available for this song'**
  String get artistIsNotAvailableForThis;

  /// lib/features/settings/screens/widget_settings_screen.dart:215
  ///
  /// In en, this message translates to:
  /// **'Artist Name'**
  String get artistName;

  /// lib/features/artists/screens/artists_screen.dart:253
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get artists;

  /// lib/features/artists/screens/artists_screen.dart:261
  ///
  /// In en, this message translates to:
  /// **'{arg1} artists'**
  String artists2(Object arg1);

  /// lib/features/menu/screens/menu_screen.dart:887
  ///
  /// In en, this message translates to:
  /// **'Artists In Rotation'**
  String get artistsInRotation;

  /// lib/features/settings/screens/library_settings_screen.dart:286
  ///
  /// In en, this message translates to:
  /// **'Artwork cache cleared'**
  String get artworkCacheCleared;

  /// lib/features/player/widgets/player_layout_sheet.dart:203
  ///
  /// In en, this message translates to:
  /// **'Artwork Card'**
  String get artworkCard;

  /// lib/features/player/widgets/player_layout_sheet.dart:239
  ///
  /// In en, this message translates to:
  /// **'Artwork placement'**
  String get artworkPlacement;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:288
  ///
  /// In en, this message translates to:
  /// **'Artwork Placement'**
  String get artworkPlacement2;

  /// lib/features/player/widgets/player_layout_sheet.dart:208
  ///
  /// In en, this message translates to:
  /// **'Artwork size'**
  String get artworkSize;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:239
  ///
  /// In en, this message translates to:
  /// **'Artwork Size'**
  String get artworkSize2;

  /// lib/models/song.dart:367
  ///
  /// In en, this message translates to:
  /// **'ASMR Dreams'**
  String get asmrDreams;

  /// lib/widgets/uac2/uac2_connection_manager.dart:88
  ///
  /// In en, this message translates to:
  /// **' at {arg1}kHz/{arg2}bit'**
  String atKhzBit(Object arg1, Object arg2);

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:1322
  ///
  /// In en, this message translates to:
  /// **'At least one version must stay.'**
  String get atLeastOneVersionMustStay;

  /// lib/features/settings/screens/equalizer_screen.dart:3345
  ///
  /// In en, this message translates to:
  /// **'Attack'**
  String get attack;

  /// lib/features/settings/screens/audio_settings_screen.dart:40
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audio;

  /// lib/features/settings/screens/uac2_settings_screen.dart:714
  ///
  /// In en, this message translates to:
  /// **'Audio Focus'**
  String get audioFocus;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:215
  ///
  /// In en, this message translates to:
  /// **'Audio Format'**
  String get audioFormat;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:237
  ///
  /// In en, this message translates to:
  /// **'Audio Format is disabled'**
  String get audioFormatIsDisabled;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:480
  ///
  /// In en, this message translates to:
  /// **'Audio Signal Path'**
  String get audioSignalPath;

  /// lib/features/settings/screens/support_flick_screen.dart:173
  ///
  /// In en, this message translates to:
  /// **'Audio Testing Equipment'**
  String get audioTestingEquipment;

  /// lib/features/milestone/screens/milestones_screen.dart:509
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get aug;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1224
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get auto;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1427
  ///
  /// In en, this message translates to:
  /// **'Auto Advance'**
  String get autoAdvance;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1716
  ///
  /// In en, this message translates to:
  /// **'Auto — BE-MSB default; only change if native DSD hisses'**
  String get autoBeMsbDefaultOnlyChange;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:491
  ///
  /// In en, this message translates to:
  /// **'Auto Bit-perfect for USB DACs'**
  String get autoBitPerfectForUsbDacs;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:77
  ///
  /// In en, this message translates to:
  /// **'Auto Collapse'**
  String get autoCollapse;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1689
  ///
  /// In en, this message translates to:
  /// **'Auto-fill'**
  String get autoFill;

  /// lib/features/settings/screens/interface_settings_screen.dart:137
  ///
  /// In en, this message translates to:
  /// **'Auto-Focus Search'**
  String get autoFocusSearch;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:216
  ///
  /// In en, this message translates to:
  /// **'Auto Full View'**
  String get autoFullView;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:205
  ///
  /// In en, this message translates to:
  /// **'Auto-hide Timeout'**
  String get autoHideTimeout;

  /// lib/features/settings/widgets/apple_music_settings_tile.dart:38
  ///
  /// In en, this message translates to:
  /// **'Auto-identify untagged albums'**
  String get autoIdentifyUntaggedAlbums;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1637
  ///
  /// In en, this message translates to:
  /// **'Auto — Native DSD on DAPs, DoP for USB DACs, PCM otherwise'**
  String get autoNativeDsdOnDapsDop;

  /// lib/widgets/uac2/uac2_connection_manager.dart:183
  ///
  /// In en, this message translates to:
  /// **'Auto-Reconnect'**
  String get autoReconnect;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:217
  ///
  /// In en, this message translates to:
  /// **'Auto-show full view after inactivity'**
  String get autoShowFullViewAfterInactivity;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:170
  ///
  /// In en, this message translates to:
  /// **'Auto-show the Spotify-style immersive full view after inactivity'**
  String get autoShowTheSpotifyStyleImmersive;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1731
  ///
  /// In en, this message translates to:
  /// **'Auto — U8 byte-interleaved (recommended)'**
  String get autoU8ByteInterleavedRecommended;

  /// lib/features/settings/screens/equalizer_screen.dart:758
  ///
  /// In en, this message translates to:
  /// **'AutoEQ headphones'**
  String get autoeqHeadphones;

  /// lib/features/settings/screens/widgets/autoeq_search_sheet.dart:188
  ///
  /// In en, this message translates to:
  /// **'AutoEQ Headphones'**
  String get autoeqHeadphones2;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:311
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get automatic;

  /// lib/features/settings/screens/app_info_settings_screen.dart:173
  ///
  /// In en, this message translates to:
  /// **'Automatic Update Checks'**
  String get automaticUpdateChecks;

  /// lib/features/settings/screens/interface_settings_screen.dart:138
  ///
  /// In en, this message translates to:
  /// **'Automatically open keyboard when switching to search'**
  String get automaticallyOpenKeyboardWhenSwitchingTo;

  /// lib/features/settings/screens/queue_settings_screen.dart:73
  ///
  /// In en, this message translates to:
  /// **'Autoplay on Queue End'**
  String get autoplayOnQueueEnd;

  /// lib/features/settings/screens/casting_settings_screen.dart:70
  ///
  /// In en, this message translates to:
  /// **'Available Devices'**
  String get availableDevices;

  /// lib/features/settings/screens/equalizer_screen.dart:2405
  ///
  /// In en, this message translates to:
  /// **'B{arg1}'**
  String b(Object arg1);

  /// lib/features/onboarding/widgets/tutorial_overlay.dart:338
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// lib/widgets/common/offline_notice.dart:137
  ///
  /// In en, this message translates to:
  /// **'Back online'**
  String get backOnline;

  /// lib/features/player/screens/full_player_screen.dart:731
  ///
  /// In en, this message translates to:
  /// **'Back to Locker'**
  String get backToLocker;

  /// lib/features/settings/screens/uac2_settings_screen.dart:632
  ///
  /// In en, this message translates to:
  /// **'Backend'**
  String get backend;

  /// lib/features/settings/screens/widget_settings_screen.dart:155
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get background;

  /// lib/features/settings/widgets/mini_player_customization.dart:197
  ///
  /// In en, this message translates to:
  /// **'Background Opacity'**
  String get backgroundOpacity;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:49
  ///
  /// In en, this message translates to:
  /// **'Background Playback Anchor'**
  String get backgroundPlaybackAnchor;

  /// lib/features/settings/screens/equalizer_screen.dart:3563
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// lib/features/settings/screens/equalizer_screen.dart:3515
  ///
  /// In en, this message translates to:
  /// **'Balance {arg1}'**
  String balance2(Object arg1);

  /// lib/features/settings/screens/equalizer_screen.dart:3550
  ///
  /// In en, this message translates to:
  /// **'Balance, tempo, damp, filter, delays, size, mix, and extra spread controls.'**
  String get balanceTempoDampFilterDelaysSize;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:505
  ///
  /// In en, this message translates to:
  /// **'Balanced quality and stability'**
  String get balancedQualityAndStability;

  /// lib/widgets/equalizer/interactive_eq_graph.dart:211
  ///
  /// In en, this message translates to:
  /// **'Band'**
  String get band;

  /// lib/features/settings/screens/equalizer_screen.dart:1822
  ///
  /// In en, this message translates to:
  /// **'Band Controls'**
  String get bandControls;

  /// lib/features/settings/screens/equalizer_screen.dart:2240
  ///
  /// In en, this message translates to:
  /// **'Band Editors'**
  String get bandEditors;

  /// lib/providers/equalizer_provider.dart:37
  ///
  /// In en, this message translates to:
  /// **'Band Pass'**
  String get bandPass;

  /// lib/features/settings/screens/equalizer_screen.dart:2578
  ///
  /// In en, this message translates to:
  /// **'Band {arg1}  •  {arg2}'**
  String bandU2022(Object arg1, Object arg2);

  /// lib/features/settings/screens/equalizer_screen.dart:2178
  ///
  /// In en, this message translates to:
  /// **'{arg1}/31 bands'**
  String bands(Object arg1);

  /// lib/widgets/equalizer/interactive_eq_graph.dart:294
  ///
  /// In en, this message translates to:
  /// **'{activeCount}/{arg1} bands active'**
  String bandsActive(Object activeCount, Object arg1);

  /// lib/features/settings/screens/equalizer_screen.dart:1749
  ///
  /// In en, this message translates to:
  /// **'{adjustedBands} bands adjusted'**
  String bandsAdjusted(Object adjustedBands);

  /// lib/widgets/equalizer/interactive_eq_graph.dart:291
  ///
  /// In en, this message translates to:
  /// **'{adjustedCount}/{arg1} bands adjusted'**
  String bandsAdjusted2(Object adjustedCount, Object arg1);

  /// lib/features/settings/screens/widgets/autoeq_search_sheet.dart:366
  ///
  /// In en, this message translates to:
  /// **'{arg1} bands · preamp {arg2} dB · {arg3}'**
  String bandsPreampDb(Object arg1, Object arg2, Object arg3);

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:258
  ///
  /// In en, this message translates to:
  /// **'Bar Height'**
  String get barHeight;

  /// lib/features/settings/screens/visualizer_settings_screen.dart:70
  ///
  /// In en, this message translates to:
  /// **'Bars'**
  String get bars;

  /// lib/features/settings/screens/orbit_settings_screen.dart:80
  ///
  /// In en, this message translates to:
  /// **'Base album-art size for each song card'**
  String get baseAlbumArtSizeForEach;

  /// lib/features/settings/screens/equalizer_screen.dart:1665
  ///
  /// In en, this message translates to:
  /// **'Bass'**
  String get bass;

  /// lib/features/settings/screens/equalizer_screen.dart:1639
  ///
  /// In en, this message translates to:
  /// **'Bass, Mid & Treble'**
  String get bassMidTreble;

  /// lib/features/settings/screens/visualizer_settings_screen.dart:156
  ///
  /// In en, this message translates to:
  /// **'Bass + Treble'**
  String get bassTreble;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:117
  ///
  /// In en, this message translates to:
  /// **'{battery}% battery'**
  String battery(Object battery);

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1722
  ///
  /// In en, this message translates to:
  /// **'BE-LSB — big-endian subslot, LSB first'**
  String get beLsbBigEndianSubslotLsb;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1718
  ///
  /// In en, this message translates to:
  /// **'BE-MSB — big-endian subslot, MSB first (default)'**
  String get beMsbBigEndianSubslotMsb;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1827
  ///
  /// In en, this message translates to:
  /// **'BE-MSB packing — the default wire convention'**
  String get beMsbPackingTheDefaultWire;

  /// lib/features/player/screens/lyrics_sync_screen.dart:499
  ///
  /// In en, this message translates to:
  /// **'Beside the song'**
  String get besideTheSong;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1832
  ///
  /// In en, this message translates to:
  /// **'Big-endian 32-bit subslot, MSB-first bits'**
  String get bigEndian32BitSubslotMsb;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1842
  ///
  /// In en, this message translates to:
  /// **'Big-endian subslot, LSB-first (bit-reversed) bits'**
  String get bigEndianSubslotLsbFirstBit;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1361
  ///
  /// In en, this message translates to:
  /// **'{depth}bit'**
  String bit(Object depth);

  /// lib/features/player/widgets/bit_perfect_indicator.dart:612
  ///
  /// In en, this message translates to:
  /// **'Bit depth'**
  String get bitDepth;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1350
  ///
  /// In en, this message translates to:
  /// **'Bit Depth'**
  String get bitDepth2;

  /// lib/features/settings/screens/uac2_settings_screen.dart:569
  ///
  /// In en, this message translates to:
  /// **'Bit Depths'**
  String get bitDepths;

  /// lib/features/player/widgets/bit_perfect_capsule.dart:144
  ///
  /// In en, this message translates to:
  /// **'BIT-PERFECT'**
  String get bitPerfect;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:420
  ///
  /// In en, this message translates to:
  /// **'Bit-perfect'**
  String get bitPerfect2;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:366
  ///
  /// In en, this message translates to:
  /// **'Bit-Perfect Capsule'**
  String get bitPerfectCapsule;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:459
  ///
  /// In en, this message translates to:
  /// **'Bit-perfect (DAP Internal)'**
  String get bitPerfectDapInternal;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:474
  ///
  /// In en, this message translates to:
  /// **'Bit-perfect (DAP Internal) disabled — software effects active.'**
  String get bitPerfectDapInternalDisabledSoftware;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:473
  ///
  /// In en, this message translates to:
  /// **'Bit-perfect (DAP Internal) enabled — all DSP bypassed.'**
  String get bitPerfectDapInternalEnabledAll;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:437
  ///
  /// In en, this message translates to:
  /// **'Bit-perfect enabled — parametric EQ is bypassed on the direct USB path. Restart the app to apply playback changes.'**
  String get bitPerfectEnabledParametricEqIs;

  /// lib/features/menu/screens/menu_screen.dart:512
  ///
  /// In en, this message translates to:
  /// **'Bit-perfect (USB DAC)'**
  String get bitPerfectUsbDac;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:426
  ///
  /// In en, this message translates to:
  /// **'Bit-perfect (USB DAC) could not be enabled. Check the USB diagnostics for the failure reason.'**
  String get bitPerfectUsbDacCouldNot;

  /// lib/widgets/uac2/usb_bit_perfect_prompt.dart:274
  ///
  /// In en, this message translates to:
  /// **'Bit-perfect (USB DAC) could not be enabled for {arg1}. Check the USB diagnostics.'**
  String bitPerfectUsbDacCouldNot2(Object arg1);

  /// lib/widgets/uac2/usb_bit_perfect_prompt.dart:273
  ///
  /// In en, this message translates to:
  /// **'Bit-perfect (USB DAC) enabled for {arg1}.'**
  String bitPerfectUsbDacEnabledFor(Object arg1);

  /// lib/features/player/widgets/bit_perfect_indicator.dart:490
  ///
  /// In en, this message translates to:
  /// **'Bit-perfect verified'**
  String get bitPerfectVerified;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1768
  ///
  /// In en, this message translates to:
  /// **'16-bit subslots: LL|RR per frame'**
  String get bitSubslotsLlRrPer;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1763
  ///
  /// In en, this message translates to:
  /// **'32-bit subslots: LLLL|RRRR per frame (legacy)'**
  String get bitSubslotsLlllRrrrPer;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:503
  ///
  /// In en, this message translates to:
  /// **'Bitrate adjusts to signal quality'**
  String get bitrateAdjustsToSignalQuality;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:683
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get blocked;

  /// lib/features/settings/screens/widget_settings_screen.dart:283
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get blue;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:225
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get bluetooth;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:558
  ///
  /// In en, this message translates to:
  /// **'Bluetooth codec info'**
  String get bluetoothCodecInfo;

  /// lib/features/settings/screens/uac2_settings_screen.dart:929
  ///
  /// In en, this message translates to:
  /// **'Bluetooth output'**
  String get bluetoothOutput;

  /// lib/models/album_color_mode.dart:39
  ///
  /// In en, this message translates to:
  /// **'Bold, saturated colors from album art.'**
  String get boldSaturatedColorsFromAlbumArt;

  /// lib/features/settings/screens/audio_settings_screen.dart:121
  ///
  /// In en, this message translates to:
  /// **'Boost beyond 100% (up to 200%)'**
  String get boostBeyond100UpTo200;

  /// lib/features/settings/widgets/mini_player_customization.dart:208
  ///
  /// In en, this message translates to:
  /// **'Border'**
  String get border;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:873
  ///
  /// In en, this message translates to:
  /// **'Both bit-perfect options are off on this DAP, so the standard engine is unavailable. You can still use Rust via Oboe or Isochronous USB.'**
  String get bothBitPerfectOptionsAreOff;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:27
  ///
  /// In en, this message translates to:
  /// **'Bottom Bar'**
  String get bottomBar;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:142
  ///
  /// In en, this message translates to:
  /// **'Bottom Bar Always Visible'**
  String get bottomBarAlwaysVisible;

  /// lib/features/settings/screens/visualizer_settings_screen.dart:169
  ///
  /// In en, this message translates to:
  /// **'Bouncy'**
  String get bouncy;

  /// lib/features/albums/screens/albums_screen.dart:348
  ///
  /// In en, this message translates to:
  /// **'Browse by artwork, open any album, and jump straight into the tracklist.'**
  String get browseByArtworkOpenAnyAlbum;

  /// lib/features/menu/screens/menu_screen.dart:1033
  ///
  /// In en, this message translates to:
  /// **'Browse More'**
  String get browseMore;

  /// lib/features/settings/screens/settings_screen.dart:238
  ///
  /// In en, this message translates to:
  /// **'Browse the full controls guide'**
  String get browseTheFullControlsGuide;

  /// lib/features/artists/screens/artists_screen.dart:378
  ///
  /// In en, this message translates to:
  /// **'Browse your artists, explore their discographies, and play their tracks.'**
  String get browseYourArtistsExploreTheirDiscographies;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:1024
  ///
  /// In en, this message translates to:
  /// **'Buffer'**
  String get buffer;

  /// lib/core/constants/app_constants.dart:6
  ///
  /// In en, this message translates to:
  /// **'{kAppVersion} (build {kAppBuild})'**
  String build(Object kAppVersion, Object kAppBuild);

  /// lib/features/settings/screens/equalizer_screen.dart:766
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get builtIn;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:274
  ///
  /// In en, this message translates to:
  /// **'Button Spacing'**
  String get buttonSpacing;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:110
  ///
  /// In en, this message translates to:
  /// **'Buttons'**
  String get buttons;

  /// lib/features/settings/screens/support_flick_screen.dart:212
  ///
  /// In en, this message translates to:
  /// **'Buy me a coffee'**
  String get buyMeACoffee;

  /// lib/features/songs/widgets/song_actions_bottom_sheet.dart:726
  ///
  /// In en, this message translates to:
  /// **'\"{arg1}\" by {arg2}'**
  String by(Object arg1, Object arg2);

  /// lib/features/settings/screens/uac2_preferences_screen.dart:461
  ///
  /// In en, this message translates to:
  /// **'Bypass all DSP (EQ, dynamics, crossfade, speed) on the native DAP internal high-res path. Disable to use software effects. Turning off Bit-perfect (USB DAC) also disables this.'**
  String get bypassAllDspEqDynamicsCrossfade;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1773
  ///
  /// In en, this message translates to:
  /// **'Byte-interleaved: LRLR stream'**
  String get byteInterleavedLrlrStream;

  /// lib/features/settings/screens/library_settings_screen.dart:2133
  ///
  /// In en, this message translates to:
  /// **'Cache waveforms and loudness for all songs'**
  String get cacheWaveformsAndLoudnessForAll;

  /// lib/features/settings/screens/library_settings_screen.dart:272
  ///
  /// In en, this message translates to:
  /// **'Cached album art ({arg1}) will be removed. Artwork reloads automatically as you browse.'**
  String cachedAlbumArtWillBeRemoved(Object arg1);

  /// lib/features/settings/screens/library_settings_screen.dart:402
  ///
  /// In en, this message translates to:
  /// **'Cached WAV conversions ({size}) will be removed. Files convert again on next playback.'**
  String cachedWavConversionsWillBeRemoved(Object size);

  /// lib/features/settings/screens/library_settings_screen.dart:250
  ///
  /// In en, this message translates to:
  /// **'Calculating size...'**
  String get calculatingSize;

  /// lib/models/song.dart:313
  ///
  /// In en, this message translates to:
  /// **'Calm Frequencies'**
  String get calmFrequencies;

  /// lib/features/settings/screens/privacy_policy_screen.dart:46
  ///
  /// In en, this message translates to:
  /// **'Camera and photo library access is used solely for the Flick Replay feature to create custom poster backgrounds for listening recap posters. Photos are only used at your explicit request and remain entirely on your device. No images are uploaded or transmitted.'**
  String get cameraAndPhotoLibraryAccessIs;

  /// lib/features/settings/screens/privacy_policy_screen.dart:44
  ///
  /// In en, this message translates to:
  /// **'Camera and Photos'**
  String get cameraAndPhotos;

  /// lib/features/player/widgets/online_lyrics_search_sheet.dart:1150
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// lib/features/settings/screens/interface_settings_screen.dart:224
  ///
  /// In en, this message translates to:
  /// **'Cap at 60Hz — balanced smoothness and battery'**
  String get capAt60hzBalancedSmoothnessAnd;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:1027
  ///
  /// In en, this message translates to:
  /// **'cap {arg1} ms'**
  String capMs(Object arg1);

  /// lib/features/settings/screens/uac2_settings_screen.dart:82
  ///
  /// In en, this message translates to:
  /// **'Capabilities'**
  String get capabilities;

  /// lib/features/settings/screens/uac2_settings_screen.dart:529
  ///
  /// In en, this message translates to:
  /// **'Capabilities not available'**
  String get capabilitiesNotAvailable;

  /// lib/features/settings/screens/uac2_settings_screen.dart:625
  ///
  /// In en, this message translates to:
  /// **'Capability State'**
  String get capabilityState;

  /// lib/features/settings/screens/orbit_settings_screen.dart:79
  ///
  /// In en, this message translates to:
  /// **'Card Size'**
  String get cardSize;

  /// lib/features/settings/screens/orbit_settings_screen.dart:91
  ///
  /// In en, this message translates to:
  /// **'Card Width'**
  String get cardWidth;

  /// lib/features/player/widgets/player_action_button_row.dart:843
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get cast;

  /// lib/features/settings/screens/casting_settings_screen.dart:66
  ///
  /// In en, this message translates to:
  /// **'Casting'**
  String get casting;

  /// lib/features/player/widgets/player_action_button_row.dart:843
  ///
  /// In en, this message translates to:
  /// **'Casting — tap to manage'**
  String get castingTapToManage;

  /// Snack bar shown after starting a cast session.
  ///
  /// In en, this message translates to:
  /// **'Casting to {deviceName}'**
  String castingTo(Object deviceName);

  /// lib/features/settings/screens/casting_settings_screen.dart:54
  ///
  /// In en, this message translates to:
  /// **'Casting to {arg1}'**
  String castingTo2(Object arg1);

  /// lib/models/shuffle_mode.dart:14
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// lib/features/settings/screens/equalizer_screen.dart:3420
  ///
  /// In en, this message translates to:
  /// **'Ceiling'**
  String get ceiling;

  /// lib/features/settings/screens/lyrics_settings_screen.dart:68
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get center;

  /// lib/features/settings/screens/ui_customization_settings_screen.dart:193
  ///
  /// In en, this message translates to:
  /// **'Center the title and info in the detail header'**
  String get centerTheTitleAndInfoIn;

  /// lib/features/settings/screens/ui_customization_settings_screen.dart:192
  ///
  /// In en, this message translates to:
  /// **'Centered Header Title'**
  String get centeredHeaderTitle;

  /// lib/features/settings/widgets/mini_player_customization.dart:91
  ///
  /// In en, this message translates to:
  /// **'Centered; widens to fit your controls'**
  String get centeredWidensToFitYourControls;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:621
  ///
  /// In en, this message translates to:
  /// **'{channels} ch'**
  String ch(Object channels);

  /// lib/features/player/widgets/bit_perfect_indicator.dart:932
  ///
  /// In en, this message translates to:
  /// **'{ch} ch'**
  String ch2(Object ch);

  /// lib/features/settings/screens/uac2_preferences_screen.dart:273
  ///
  /// In en, this message translates to:
  /// **'{arg1} / {arg2}ch'**
  String ch3(Object arg1, Object arg2);

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1234
  ///
  /// In en, this message translates to:
  /// **'Changing sample rate, bit depth, or channel handling can resample songs and may affect playback quality, pitch, speed, or stability on some devices.'**
  String get changingSampleRateBitDepthOr;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:620
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get channels;

  /// lib/features/settings/screens/uac2_settings_screen.dart:660
  ///
  /// In en, this message translates to:
  /// **'{arg1} channels'**
  String channels2(Object arg1);

  /// lib/widgets/uac2/uac2_stream_config.dart:185
  ///
  /// In en, this message translates to:
  /// **'{ch} channels'**
  String channels3(Object ch);

  /// lib/features/settings/screens/app_info_settings_screen.dart:609
  ///
  /// In en, this message translates to:
  /// **'Check Again'**
  String get checkAgain;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:1265
  ///
  /// In en, this message translates to:
  /// **'Check the versions you want to keep — unchecked ones will be removed from your library. At least one must stay.'**
  String get checkTheVersionsYouWantTo;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:321
  ///
  /// In en, this message translates to:
  /// **'Check versions to keep — unchecked will be removed'**
  String get checkVersionsToKeepUncheckedWill;

  /// lib/features/settings/screens/library_settings_screen.dart:1118
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get checking;

  /// lib/features/settings/screens/app_info_settings_screen.dart:133
  ///
  /// In en, this message translates to:
  /// **'Checking for Updates'**
  String get checkingForUpdates;

  /// lib/features/settings/screens/app_info_settings_screen.dart:608
  ///
  /// In en, this message translates to:
  /// **'Checking for Updates...'**
  String get checkingForUpdates2;

  /// lib/features/settings/screens/privacy_policy_screen.dart:79
  ///
  /// In en, this message translates to:
  /// **'Children\'s Privacy'**
  String get childrenSPrivacy;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:968
  ///
  /// In en, this message translates to:
  /// **'Choose Action'**
  String get chooseAction;

  /// lib/features/player/screens/lyrics_sync_screen.dart:494
  ///
  /// In en, this message translates to:
  /// **'Choose location…'**
  String get chooseLocationU2026;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:1178
  ///
  /// In en, this message translates to:
  /// **'Choose which to keep'**
  String get chooseWhichToKeep;

  /// lib/features/settings/screens/casting_settings_screen.dart:46
  ///
  /// In en, this message translates to:
  /// **'Chromecast'**
  String get chromecast;

  /// lib/features/settings/screens/visualizer_settings_screen.dart:112
  ///
  /// In en, this message translates to:
  /// **'Circular dots — radius follows amplitude'**
  String get circularDotsRadiusFollowsAmplitude;

  /// lib/models/song.dart:331
  ///
  /// In en, this message translates to:
  /// **'City Beats'**
  String get cityBeats;

  /// lib/features/settings/screens/uac2_settings_screen.dart:703
  ///
  /// In en, this message translates to:
  /// **'Claimed by Flick'**
  String get claimedByFlick;

  /// lib/models/progress_bar_style.dart:27
  ///
  /// In en, this message translates to:
  /// **'Clean straight line with precision scrubbing.'**
  String get cleanStraightLineWithPrecisionScrubbing;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1214
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:558
  ///
  /// In en, this message translates to:
  /// **'Clear all UAC2 settings'**
  String get clearAllUac2Settings;

  /// lib/features/settings/screens/library_settings_screen.dart:270
  ///
  /// In en, this message translates to:
  /// **'Clear Artwork Cache?'**
  String get clearArtworkCache;

  /// lib/features/settings/screens/library_settings_screen.dart:2162
  ///
  /// In en, this message translates to:
  /// **'Clear Artwork Cache'**
  String get clearArtworkCache2;

  /// lib/features/settings/screens/library_settings_screen.dart:2176
  ///
  /// In en, this message translates to:
  /// **'Clear Converted Audio'**
  String get clearConvertedAudio;

  /// lib/features/settings/screens/library_settings_screen.dart:400
  ///
  /// In en, this message translates to:
  /// **'Clear Converted Audio Cache?'**
  String get clearConvertedAudioCache;

  /// lib/features/player/widgets/online_lyrics_search_sheet.dart:807
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// lib/features/recently_played/screens/recently_played_screen.dart:196
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clearHistory;

  /// lib/features/settings/screens/logs_screen.dart:230
  ///
  /// In en, this message translates to:
  /// **'Clear logs?'**
  String get clearLogs;

  /// lib/features/settings/screens/interface_settings_screen.dart:174
  ///
  /// In en, this message translates to:
  /// **'Clear the counter and any unlocked streak milestones'**
  String get clearTheCounterAndAnyUnlocked;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1594
  ///
  /// In en, this message translates to:
  /// **'Clear Word'**
  String get clearWord;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1418
  ///
  /// In en, this message translates to:
  /// **'Clear Words'**
  String get clearWords;

  /// lib/features/settings/screens/library_settings_screen.dart:249
  ///
  /// In en, this message translates to:
  /// **'Clearing...'**
  String get clearing;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:144
  ///
  /// In en, this message translates to:
  /// **'Codec applied: {arg1}'**
  String codecApplied(Object arg1);

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:341
  ///
  /// In en, this message translates to:
  /// **'Codec Control'**
  String get codecControl;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:152
  ///
  /// In en, this message translates to:
  /// **'Codec forcing unavailable on this device — set it via Developer Options → Bluetooth Audio Codec.'**
  String get codecForcingUnavailableOnThisDevice;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:444
  ///
  /// In en, this message translates to:
  /// **'Codec Info'**
  String get codecInfo;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:336
  ///
  /// In en, this message translates to:
  /// **'Codec & Audio'**
  String get codecU0026Audio;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:91
  ///
  /// In en, this message translates to:
  /// **'Collapse After'**
  String get collapseAfter;

  /// lib/features/settings/widgets/mini_player_customization.dart:334
  ///
  /// In en, this message translates to:
  /// **'Collapsed'**
  String get collapsed;

  /// lib/features/albums/screens/albums_screen.dart:490
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get collection;

  /// lib/features/player/widgets/share/share_template.dart:9
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1664
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get comingSoon;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1213
  ///
  /// In en, this message translates to:
  /// **'Compatibility'**
  String get compatibility;

  /// lib/features/settings/screens/equalizer_screen.dart:668
  ///
  /// In en, this message translates to:
  /// **'Compatible with Poweramp EQ'**
  String get compatibleWithPowerampEq;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:393
  ///
  /// In en, this message translates to:
  /// **'Completely hidden from the bottom bar'**
  String get completelyHiddenFromTheBottomBar;

  /// lib/features/settings/screens/equalizer_screen.dart:3303
  ///
  /// In en, this message translates to:
  /// **'Compressor'**
  String get compressor;

  /// lib/features/settings/screens/equalizer_screen.dart:3263
  ///
  /// In en, this message translates to:
  /// **'Compressor off'**
  String get compressorOff;

  /// lib/features/settings/screens/equalizer_screen.dart:3263
  ///
  /// In en, this message translates to:
  /// **'Compressor on'**
  String get compressorOn;

  /// lib/features/settings/screens/audio_settings_screen.dart:50
  ///
  /// In en, this message translates to:
  /// **'Configure USB DAC/AMP devices'**
  String get configureUsbDacAmpDevices;

  /// lib/features/settings/screens/settings_screen.dart:312
  ///
  /// In en, this message translates to:
  /// **'Configure your music experience'**
  String get configureYourMusicExperience;

  /// lib/features/settings/widgets/listenbrainz_settings_tile.dart:785
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// lib/features/settings/screens/network_sources_screen.dart:155
  ///
  /// In en, this message translates to:
  /// **'Connect a music server'**
  String get connectAMusicServer;

  /// lib/features/settings/screens/network_sources_screen.dart:199
  ///
  /// In en, this message translates to:
  /// **'Connect a Subsonic, Jellyfin, WebDAV, UPnP, or Tidal server to stream your remote library.'**
  String get connectASubsonicJellyfinWebdavUpnp;

  /// lib/features/settings/screens/uac2_settings_screen.dart:296
  ///
  /// In en, this message translates to:
  /// **'Connect a USB DAC or audio interface'**
  String get connectAUsbDacOrAudio;

  /// lib/features/settings/widgets/listenbrainz_settings_tile.dart:651
  ///
  /// In en, this message translates to:
  /// **'Connect ListenBrainz'**
  String get connectListenbrainz;

  /// lib/features/settings/widgets/lastfm_settings_tile.dart:979
  ///
  /// In en, this message translates to:
  /// **'Connect to scrobble your listening history'**
  String get connectToScrobbleYourListeningHistory;

  /// lib/features/settings/widgets/lastfm_settings_tile.dart:356
  ///
  /// In en, this message translates to:
  /// **'Connect to scrobble your music'**
  String get connectToScrobbleYourMusic;

  /// lib/features/settings/widgets/listenbrainz_settings_tile.dart:481
  ///
  /// In en, this message translates to:
  /// **'Connect to submit your listening history'**
  String get connectToSubmitYourListeningHistory;

  /// lib/features/settings/screens/app_info_settings_screen.dart:80
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet to check for updates.'**
  String get connectToTheInternetToCheck;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:110
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// lib/features/settings/widgets/lastfm_settings_tile.dart:888
  ///
  /// In en, this message translates to:
  /// **'Connected Account'**
  String get connectedAccount;

  /// lib/features/settings/widgets/lastfm_settings_tile.dart:770
  ///
  /// In en, this message translates to:
  /// **'Connected as {username}'**
  String connectedAs(Object username);

  /// lib/features/settings/screens/uac2_settings_screen.dart:901
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get connecting;

  /// lib/features/settings/screens/network_server_edit_screen.dart:428
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connection;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:244
  ///
  /// In en, this message translates to:
  /// **'Connection Behavior'**
  String get connectionBehavior;

  /// lib/features/settings/screens/network_server_edit_screen.dart:355
  ///
  /// In en, this message translates to:
  /// **'Connection Failed — Retry'**
  String get connectionFailedRetry;

  /// lib/widgets/uac2/uac2_connection_manager.dart:140
  ///
  /// In en, this message translates to:
  /// **'Connection Management'**
  String get connectionManagement;

  /// Connection notice visibility setting in Interface settings
  ///
  /// In en, this message translates to:
  /// **'Connection notices'**
  String get connectionNotices;

  /// Description of the connection notice visibility setting
  ///
  /// In en, this message translates to:
  /// **'Show offline and back-online notices'**
  String get connectionNoticesDescription;

  /// lib/features/settings/screens/network_server_edit_screen.dart:353
  ///
  /// In en, this message translates to:
  /// **'Connection OK'**
  String get connectionOk;

  /// lib/features/settings/screens/uac2_settings_screen.dart:607
  ///
  /// In en, this message translates to:
  /// **'Connection Status'**
  String get connectionStatus;

  /// lib/features/settings/screens/equalizer_screen.dart:585
  ///
  /// In en, this message translates to:
  /// **'\"{presetName}\" contains values outside the supported ranges; these were adjusted:'**
  String containsValuesOutsideTheSupportedRanges(Object presetName);

  /// lib/features/settings/screens/widget_settings_screen.dart:195
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get content;

  /// lib/features/settings/widgets/mini_player_customization.dart:148
  ///
  /// In en, this message translates to:
  /// **'Content & Controls'**
  String get contentControls;

  /// lib/features/player/widgets/player_layout_sheet.dart:228
  ///
  /// In en, this message translates to:
  /// **'Content placement'**
  String get contentPlacement;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:271
  ///
  /// In en, this message translates to:
  /// **'Content Placement'**
  String get contentPlacement2;

  /// lib/features/settings/screens/interface_settings_screen.dart:253
  ///
  /// In en, this message translates to:
  /// **'Continue through the search results'**
  String get continueThroughTheSearchResults;

  /// lib/features/settings/screens/interface_settings_screen.dart:265
  ///
  /// In en, this message translates to:
  /// **'Continue through your entire library'**
  String get continueThroughYourEntireLibrary;

  /// lib/widgets/alac_conversion_indicator.dart:249
  ///
  /// In en, this message translates to:
  /// **'Conversion failed: {error}'**
  String conversionFailed(Object error);

  /// lib/features/settings/screens/library_settings_screen.dart:416
  ///
  /// In en, this message translates to:
  /// **'Converted audio cache cleared'**
  String get convertedAudioCacheCleared;

  /// lib/widgets/alac_conversion_indicator.dart:233
  ///
  /// In en, this message translates to:
  /// **'{fileName} converted successfully'**
  String convertedSuccessfully(Object fileName);

  /// lib/widgets/alac_conversion_indicator.dart:39
  ///
  /// In en, this message translates to:
  /// **'Converting audio...'**
  String get convertingAudio;

  /// lib/widgets/alac_conversion_indicator.dart:218
  ///
  /// In en, this message translates to:
  /// **'Converting {fileName} to WAV...'**
  String convertingToWav(Object fileName);

  /// lib/features/settings/screens/equalizer_screen.dart:3747
  ///
  /// In en, this message translates to:
  /// **'Convolver / Impulse Response'**
  String get convolverImpulseResponse;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:1077
  ///
  /// In en, this message translates to:
  /// **'{arg1} • {arg2} copies'**
  String copies(Object arg1, Object arg2);

  /// lib/features/settings/screens/logs_screen.dart:180
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// lib/features/settings/screens/logs_screen.dart:299
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// lib/features/settings/widgets/listenbrainz_settings_tile.dart:662
  ///
  /// In en, this message translates to:
  /// **'Copy your user token from ListenBrainz settings and paste it below.'**
  String get copyYourUserTokenFromListenbrainz;

  /// lib/features/songs/widgets/song_actions_bottom_sheet.dart:698
  ///
  /// In en, this message translates to:
  /// **'Copyright'**
  String get copyright;

  /// lib/features/settings/widgets/mini_player_customization.dart:136
  ///
  /// In en, this message translates to:
  /// **'Corner Radius'**
  String get cornerRadius;

  /// lib/models/song.dart:322
  ///
  /// In en, this message translates to:
  /// **'Cosmic Orchestra'**
  String get cosmicOrchestra;

  /// lib/features/settings/screens/app_info_settings_screen.dart:151
  ///
  /// In en, this message translates to:
  /// **'Could Not Check for Updates'**
  String get couldNotCheckForUpdates;

  /// lib/features/settings/widgets/lastfm_settings_tile.dart:81
  ///
  /// In en, this message translates to:
  /// **'Could not connect to Last.fm. Check your API credentials and try again.'**
  String get couldNotConnectToLastFm;

  /// lib/features/settings/widgets/listenbrainz_settings_tile.dart:609
  ///
  /// In en, this message translates to:
  /// **'Could not connect to ListenBrainz. Check your token and try again.'**
  String get couldNotConnectToListenbrainzCheck;

  /// lib/features/player/widgets/player_navigation.dart:85
  ///
  /// In en, this message translates to:
  /// **'Could not load album songs'**
  String get couldNotLoadAlbumSongs;

  /// lib/features/player/widgets/player_navigation.dart:56
  ///
  /// In en, this message translates to:
  /// **'Could not load artist songs'**
  String get couldNotLoadArtistSongs;

  /// lib/features/settings/screens/equalizer_screen.dart:3723
  ///
  /// In en, this message translates to:
  /// **'Could not load IR: {e}'**
  String couldNotLoadIr(Object e);

  /// lib/features/settings/widgets/lastfm_settings_tile.dart:755
  ///
  /// In en, this message translates to:
  /// **'Could not load session'**
  String get couldNotLoadSession;

  /// lib/features/settings/widgets/listenbrainz_settings_tile.dart:683
  ///
  /// In en, this message translates to:
  /// **'Could not open browser.'**
  String get couldNotOpenBrowser;

  /// lib/features/settings/screens/support_flick_screen.dart:110
  ///
  /// In en, this message translates to:
  /// **'Could not open link'**
  String get couldNotOpenLink;

  /// lib/features/settings/widgets/listenbrainz_settings_tile.dart:692
  ///
  /// In en, this message translates to:
  /// **'Could not open link: {e}'**
  String couldNotOpenLink2(Object e);

  /// lib/features/settings/screens/app_info_settings_screen.dart:584
  ///
  /// In en, this message translates to:
  /// **'Could not open the link'**
  String get couldNotOpenTheLink;

  /// lib/features/settings/screens/app_info_settings_screen.dart:588
  ///
  /// In en, this message translates to:
  /// **'Could not open the link: {e}'**
  String couldNotOpenTheLink2(Object e);

  /// lib/features/menu/screens/menu_screen.dart:237
  ///
  /// In en, this message translates to:
  /// **'Could not open the Play Store: {error}'**
  String couldNotOpenThePlayStore2(Object error);

  /// lib/features/settings/screens/app_info_settings_screen.dart:117
  ///
  /// In en, this message translates to:
  /// **'Could not open the Play Store'**
  String get couldNotOpenThePlayStore3;

  /// lib/features/player/widgets/inline_lyrics_panel.dart:129
  ///
  /// In en, this message translates to:
  /// **'Could not read the selected lyrics file.'**
  String get couldNotReadTheSelectedLyrics;

  /// lib/features/player/screens/lyrics_sync_screen.dart:565
  ///
  /// In en, this message translates to:
  /// **'Could not save the lyrics file.'**
  String get couldNotSaveTheLyricsFile;

  /// lib/features/player/widgets/inline_lyrics_panel.dart:142
  ///
  /// In en, this message translates to:
  /// **'Could not use the selected lyrics file.'**
  String get couldNotUseTheSelectedLyrics;

  /// lib/features/settings/screens/network_server_edit_screen.dart:589
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the browser automatically. Authorize on any device with this link — we\'ll finish signing in once you do:'**
  String get couldnTOpenTheBrowserAutomatically;

  /// lib/features/settings/screens/library_settings_screen.dart:985
  ///
  /// In en, this message translates to:
  /// **'Counting files…'**
  String get countingFiles;

  /// lib/features/settings/screens/library_settings_screen.dart:979
  ///
  /// In en, this message translates to:
  /// **'{done} / {total} covers'**
  String covers(Object done, Object total);

  /// lib/features/playlists/screens/playlists_screen.dart:403
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// lib/features/settings/screens/equalizer_screen.dart:738
  ///
  /// In en, this message translates to:
  /// **'Create a custom preset'**
  String get createACustomPreset;

  /// lib/features/player/widgets/inline_lyrics_panel.dart:208
  ///
  /// In en, this message translates to:
  /// **'Create Lyrics'**
  String get createLyrics;

  /// lib/features/songs/screens/songs_screen.dart:1442
  ///
  /// In en, this message translates to:
  /// **'Create new playlist'**
  String get createNewPlaylist;

  /// lib/features/songs/widgets/song_actions_bottom_sheet.dart:464
  ///
  /// In en, this message translates to:
  /// **'Create New Playlist'**
  String get createNewPlaylist2;

  /// lib/features/settings/screens/library_settings_screen.dart:1856
  ///
  /// In en, this message translates to:
  /// **'Create or refresh playlists found inside scanned folders'**
  String get createOrRefreshPlaylistsFoundInside;

  /// lib/features/playlists/screens/playlists_screen.dart:124
  ///
  /// In en, this message translates to:
  /// **'Create Playlist'**
  String get createPlaylist;

  /// lib/features/songs/screens/songs_screen.dart:1586
  ///
  /// In en, this message translates to:
  /// **'Create playlist from selected'**
  String get createPlaylistFromSelected;

  /// lib/features/songs/widgets/song_actions_bottom_sheet.dart:546
  ///
  /// In en, this message translates to:
  /// **'Created {arg1} and added song'**
  String createdAndAddedSong(Object arg1);

  /// lib/features/songs/screens/songs_screen.dart:1523
  ///
  /// In en, this message translates to:
  /// **'Created {name} and added {arg1} songs'**
  String createdAndAddedSongs(Object name, Object arg1);

  /// lib/features/settings/screens/equalizer_screen.dart:3505
  ///
  /// In en, this message translates to:
  /// **'Creative FX'**
  String get creativeFx;

  /// lib/features/settings/screens/network_sources_screen.dart:110
  ///
  /// In en, this message translates to:
  /// **'Credentials rejected by {arg1}. Re-enter the password.'**
  String credentialsRejectedByReEnterThe(Object arg1);

  /// lib/features/settings/widgets/lastfm_settings_tile.dart:622
  ///
  /// In en, this message translates to:
  /// **'Credentials saved successfully!'**
  String get credentialsSavedSuccessfully;

  /// lib/features/settings/screens/orbit_settings_screen.dart:167
  ///
  /// In en, this message translates to:
  /// **'Crispest — heavier during fast scrolling'**
  String get crispestHeavierDuringFastScrolling;

  /// lib/features/settings/screens/audio_settings_screen.dart:318
  ///
  /// In en, this message translates to:
  /// **'Crossfade'**
  String get crossfade;

  /// lib/features/settings/screens/audio_settings_screen.dart:372
  ///
  /// In en, this message translates to:
  /// **'Crossfade is most reliable on the Standard engine. On the high-quality (Rust) engine it can be unstable — switch to Standard for consistent crossfades.'**
  String get crossfadeIsMostReliableOnThe;

  /// lib/features/settings/screens/audio_settings_screen.dart:395
  ///
  /// In en, this message translates to:
  /// **'Crossfeed'**
  String get crossfeed;

  /// lib/features/settings/screens/audio_settings_screen.dart:428
  ///
  /// In en, this message translates to:
  /// **'Crossfeed (BS2B)'**
  String get crossfeedBs2b;

  /// lib/features/settings/screens/audio_settings_screen.dart:396
  ///
  /// In en, this message translates to:
  /// **'Crossfeed easy'**
  String get crossfeedEasy;

  /// lib/features/settings/screens/audio_settings_screen.dart:453
  ///
  /// In en, this message translates to:
  /// **'Crossfeed runs on the high-quality (Rust) engine only. The Standard engine plays without it.'**
  String get crossfeedRunsOnTheHighQuality;

  /// lib/models/song.dart:348
  ///
  /// In en, this message translates to:
  /// **'Crystal Caverns'**
  String get crystalCaverns;

  /// lib/services/metadata_editor_service.dart:67
  ///
  /// In en, this message translates to:
  /// **'CUE sheet tracks cannot be edited.'**
  String get cueSheetTracksCannotBeEdited;

  /// lib/features/songs/screens/metadata_editor_screen.dart:319
  ///
  /// In en, this message translates to:
  /// **'CUE sheet tracks cannot be edited'**
  String get cueSheetTracksCannotBeEdited2;

  /// lib/features/songs/widgets/album_art_picker_bottom_sheet.dart:327
  ///
  /// In en, this message translates to:
  /// **'Current artwork'**
  String get currentArtwork;

  /// lib/features/songs/widgets/album_art_picker_bottom_sheet.dart:326
  ///
  /// In en, this message translates to:
  /// **'Current custom art'**
  String get currentCustomArt;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1080
  ///
  /// In en, this message translates to:
  /// **'Current Playback Mode'**
  String get currentPlaybackMode;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:528
  ///
  /// In en, this message translates to:
  /// **'Current route: {arg1}.'**
  String currentRoute(Object arg1);

  /// lib/features/settings/widgets/mini_player_customization.dart:389
  ///
  /// In en, this message translates to:
  /// **'Current song · preview only'**
  String get currentSongPreviewOnly;

  /// lib/features/settings/screens/orbit_settings_screen.dart:26
  ///
  /// In en, this message translates to:
  /// **'Curvature'**
  String get curvature;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:129
  ///
  /// In en, this message translates to:
  /// **'Curvature, sizing, depth, and visuals'**
  String get curvatureSizingDepthAndVisuals;

  /// lib/features/settings/screens/audio_settings_screen.dart:571
  ///
  /// In en, this message translates to:
  /// **'Curve'**
  String get curve;

  /// lib/features/settings/screens/orbit_settings_screen.dart:27
  ///
  /// In en, this message translates to:
  /// **'Curve of the orbit arc — higher is gentler'**
  String get curveOfTheOrbitArcHigher;

  /// lib/features/settings/screens/equalizer_screen.dart:1778
  ///
  /// In en, this message translates to:
  /// **'Curve Preview'**
  String get curvePreview;

  /// lib/features/settings/screens/visualizer_settings_screen.dart:94
  ///
  /// In en, this message translates to:
  /// **'Curved Wave'**
  String get curvedWave;

  /// lib/features/settings/screens/equalizer_screen.dart:782
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:266
  ///
  /// In en, this message translates to:
  /// **'Custom Format'**
  String get customFormat;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1315
  ///
  /// In en, this message translates to:
  /// **'Custom format forces playback to the selected output format. If the chosen sample rate, bit depth, or channels do not suit the song or device, you may hear altered sound, pitch, speed, or instability.'**
  String get customFormatForcesPlaybackToThe;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:281
  ///
  /// In en, this message translates to:
  /// **'Custom format is disabled in Bit-perfect (USB DAC) mode because exact sample rate matching is required. Disable Bit-perfect (USB DAC) to set custom formats.'**
  String get customFormatIsDisabledInBit;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:286
  ///
  /// In en, this message translates to:
  /// **'Custom format is unavailable because Audio Format is disabled in Settings.'**
  String get customFormatIsUnavailableBecauseAudio;

  /// lib/features/settings/widgets/mini_player_customization.dart:90
  ///
  /// In en, this message translates to:
  /// **'Custom Width'**
  String get customWidth;

  /// lib/providers/tutorial_provider.dart:44
  ///
  /// In en, this message translates to:
  /// **'Customize audio, display, navigation, and integrations.'**
  String get customizeAudioDisplayNavigationAnd;

  /// lib/widgets/navigation/flick_nav_bar.dart:463
  ///
  /// In en, this message translates to:
  /// **'Customize Bottom Bar'**
  String get customizeBottomBar;

  /// lib/features/settings/screens/settings_screen.dart:223
  ///
  /// In en, this message translates to:
  /// **'Customize home screen widgets'**
  String get customizeHomeScreenWidgets;

  /// lib/features/settings/screens/orbit_settings_screen.dart:17
  ///
  /// In en, this message translates to:
  /// **'Customize Orbital'**
  String get customizeOrbital;

  /// lib/features/settings/screens/interface_settings_screen.dart:181
  ///
  /// In en, this message translates to:
  /// **'Customize which tabs appear and their size'**
  String get customizeWhichTabsAppearAndTheir;

  /// lib/features/recently_added/screens/recently_added_screen.dart:494
  ///
  /// In en, this message translates to:
  /// **'{arg1}d ago'**
  String dAgo2(Object arg1);

  /// lib/features/settings/screens/uac2_settings_screen.dart:700
  ///
  /// In en, this message translates to:
  /// **'DAC Claim'**
  String get dacClaim;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:514
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} DAC} other{{count} DACs}} will be offered again.'**
  String dacWillBeOfferedAgain(int count);

  /// lib/data/repositories/recently_played_repository.dart:14
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// lib/features/settings/screens/equalizer_screen.dart:3589
  ///
  /// In en, this message translates to:
  /// **'Damp'**
  String get damp;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1521
  ///
  /// In en, this message translates to:
  /// **'DAP Native Bit Order'**
  String get dapNativeBitOrder;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1532
  ///
  /// In en, this message translates to:
  /// **'DAP Native Byte Grouping'**
  String get dapNativeByteGrouping;

  /// lib/features/settings/screens/widget_settings_screen.dart:180
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// lib/features/settings/screens/privacy_policy_screen.dart:34
  ///
  /// In en, this message translates to:
  /// **'Data Collection'**
  String get dataCollection;

  /// lib/features/songs/widgets/song_actions_bottom_sheet.dart:697
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// lib/features/folders/screens/folders_screen.dart:2596
  ///
  /// In en, this message translates to:
  /// **'Date Added'**
  String get dateAdded;

  /// lib/features/settings/screens/interface_settings_screen.dart:161
  ///
  /// In en, this message translates to:
  /// **'Day Streaks'**
  String get dayStreaks;

  /// lib/features/settings/screens/equalizer_screen.dart:3320
  ///
  /// In en, this message translates to:
  /// **'{arg1} dB'**
  String db10(Object arg1);

  /// lib/features/settings/screens/equalizer_screen.dart:3421
  ///
  /// In en, this message translates to:
  /// **'{arg1} dB'**
  String db13(Object arg1);

  /// lib/widgets/uac2/iso_volume_popup.dart:275
  ///
  /// In en, this message translates to:
  /// **'{arg1}%  {arg2} dB'**
  String db15(Object arg1, Object arg2);

  /// lib/features/settings/screens/equalizer_screen.dart:1549
  ///
  /// In en, this message translates to:
  /// **'{value} dB'**
  String db2(Object value);

  /// lib/features/settings/screens/equalizer_screen.dart:2645
  ///
  /// In en, this message translates to:
  /// **'{arg1} dB'**
  String db9(Object arg1);

  /// lib/features/settings/screens/equalizer_screen.dart:2377
  ///
  /// In en, this message translates to:
  /// **'{arg1} dB cut'**
  String dbCut(Object arg1);

  /// lib/features/settings/screens/equalizer_screen.dart:1787
  ///
  /// In en, this message translates to:
  /// **'{arg1} dB max'**
  String dbMax(Object arg1);

  /// lib/widgets/uac2/uac2_fallback_manager.dart:178
  ///
  /// In en, this message translates to:
  /// **'Deactivate Fallback'**
  String get deactivateFallback;

  /// lib/features/milestone/screens/milestones_screen.dart:513
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get dec;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:917
  ///
  /// In en, this message translates to:
  /// **'Decode'**
  String get decode;

  /// lib/features/settings/screens/library_settings_screen.dart:1899
  ///
  /// In en, this message translates to:
  /// **'Decode songs after scanning to cache waveform peaks and loudness metrics'**
  String get decodeSongsAfterScanningToCache;

  /// lib/models/song.dart:353
  ///
  /// In en, this message translates to:
  /// **'Deep Earth'**
  String get deepEarth;

  /// lib/features/settings/screens/library_settings_screen.dart:1868
  ///
  /// In en, this message translates to:
  /// **'Deep Scan'**
  String get deepScan;

  /// lib/features/settings/screens/library_settings_screen.dart:1694
  ///
  /// In en, this message translates to:
  /// **'Deep scan off'**
  String get deepScanOff;

  /// lib/features/settings/screens/library_settings_screen.dart:1694
  ///
  /// In en, this message translates to:
  /// **'Deep scan on'**
  String get deepScanOn;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:761
  ///
  /// In en, this message translates to:
  /// **'Default Android playback engine used by Flick right now.'**
  String get defaultAndroidPlaybackEngineUsedBy;

  /// lib/features/recap/screens/listening_recap_screen.dart:859
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultLabel;

  /// lib/features/settings/screens/library_settings_screen.dart:1019
  ///
  /// In en, this message translates to:
  /// **'Del'**
  String get del;

  /// lib/features/settings/screens/equalizer_screen.dart:3615
  ///
  /// In en, this message translates to:
  /// **'Delays'**
  String get delays;

  /// lib/features/playlists/screens/playlists_screen.dart:649
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// lib/features/settings/screens/network_server_edit_screen.dart:329
  ///
  /// In en, this message translates to:
  /// **'Delete \"{arg1}\" and all songs and playlists synced from it? Cached downloads are kept.'**
  String deleteAndAllSongsAndPlaylists(Object arg1);

  /// lib/features/songs/widgets/song_actions_bottom_sheet.dart:753
  ///
  /// In en, this message translates to:
  /// **'Delete File'**
  String get deleteFile;

  /// lib/features/songs/screens/songs_screen.dart:1644
  ///
  /// In en, this message translates to:
  /// **'Delete Files'**
  String get deleteFiles;

  /// lib/features/settings/screens/equalizer_screen.dart:704
  ///
  /// In en, this message translates to:
  /// **'Delete Preset?'**
  String get deletePreset;

  /// lib/features/songs/screens/songs_screen.dart:1594
  ///
  /// In en, this message translates to:
  /// **'Delete selected'**
  String get deleteSelected;

  /// lib/features/songs/widgets/song_actions_bottom_sheet.dart:197
  ///
  /// In en, this message translates to:
  /// **'Delete Song'**
  String get deleteSong;

  /// lib/features/songs/widgets/song_actions_bottom_sheet.dart:718
  ///
  /// In en, this message translates to:
  /// **'Delete Song?'**
  String get deleteSong2;

  /// lib/features/songs/widgets/song_actions_bottom_sheet.dart:716
  ///
  /// In en, this message translates to:
  /// **'Delete song'**
  String get deleteSong3;

  /// lib/features/songs/screens/songs_screen.dart:1624
  ///
  /// In en, this message translates to:
  /// **'Delete {arg1} songs?'**
  String deleteSongs(Object arg1);

  /// lib/features/songs/screens/songs_screen.dart:1622
  ///
  /// In en, this message translates to:
  /// **'Delete songs'**
  String get deleteSongs2;

  /// lib/features/settings/screens/equalizer_screen.dart:705
  ///
  /// In en, this message translates to:
  /// **'Delete \"{arg1}\"? This cannot be undone.'**
  String deleteThisCannotBeUndone(Object arg1);

  /// lib/features/songs/widgets/song_actions_bottom_sheet.dart:829
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{arg1}\"'**
  String deleted(Object arg1);

  /// lib/features/songs/screens/songs_screen.dart:1714
  ///
  /// In en, this message translates to:
  /// **'Deleted {arg1} songs'**
  String deletedSongs(Object arg1);

  /// lib/features/settings/screens/orbit_settings_screen.dart:125
  ///
  /// In en, this message translates to:
  /// **'Depth'**
  String get depth;

  /// lib/features/songs/screens/songs_screen.dart:1574
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get deselectAll;

  /// lib/features/settings/screens/ui_customization_settings_screen.dart:137
  ///
  /// In en, this message translates to:
  /// **'Detail Screens'**
  String get detailScreens;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:359
  ///
  /// In en, this message translates to:
  /// **'Developer Mode'**
  String get developerMode;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:173
  ///
  /// In en, this message translates to:
  /// **'Developer Options is disabled. Enable it via Settings → About phone (tap Build number 7 times), then retry.'**
  String get developerOptionsIsDisabledEnableIt;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:641
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get device;

  /// lib/widgets/uac2/uac2_device_capabilities.dart:38
  ///
  /// In en, this message translates to:
  /// **'Device Capabilities'**
  String get deviceCapabilities;

  /// lib/widgets/uac2/uac2_hotplug_monitor.dart:48
  ///
  /// In en, this message translates to:
  /// **'Device connected'**
  String get deviceConnected;

  /// lib/features/settings/screens/uac2_settings_screen.dart:923
  ///
  /// In en, this message translates to:
  /// **'Device DAC'**
  String get deviceDac;

  /// lib/widgets/uac2/uac2_volume_control.dart:163
  ///
  /// In en, this message translates to:
  /// **'Device DAC Volume'**
  String get deviceDacVolume;

  /// lib/widgets/uac2/uac2_hotplug_monitor.dart:49
  ///
  /// In en, this message translates to:
  /// **'Device disconnected'**
  String get deviceDisconnected;

  /// lib/features/settings/screens/uac2_settings_screen.dart:79
  ///
  /// In en, this message translates to:
  /// **'Device Information'**
  String get deviceInformation;

  /// lib/features/settings/screens/uac2_settings_screen.dart:553
  ///
  /// In en, this message translates to:
  /// **'Device Type'**
  String get deviceType;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:306
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devices;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:657
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get direct;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1047
  ///
  /// In en, this message translates to:
  /// **'Direct ALSA output is active and bypassing the Android audio server.'**
  String get directAlsaOutputIsActiveAnd;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:830
  ///
  /// In en, this message translates to:
  /// **'Direct libusb isochronous USB engine. Best paired with Bit-perfect (USB DAC) for verified external DAC playback.'**
  String get directLibusbIsochronousUsbEngineBest;

  /// lib/widgets/uac2/uac2_player_status.dart:224
  ///
  /// In en, this message translates to:
  /// **'Direct USB'**
  String get directUsb;

  /// lib/features/settings/screens/uac2_settings_screen.dart:691
  ///
  /// In en, this message translates to:
  /// **'Direct USB device-managed'**
  String get directUsbDeviceManaged;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:500
  ///
  /// In en, this message translates to:
  /// **'Direct USB experimental'**
  String get directUsbExperimental;

  /// lib/features/settings/screens/library_settings_screen.dart:1972
  ///
  /// In en, this message translates to:
  /// **'Disable Battery Optimization'**
  String get disableBatteryOptimization;

  /// lib/features/settings/screens/library_settings_screen.dart:1971
  ///
  /// In en, this message translates to:
  /// **'Disable Battery Optimization (Recommended)'**
  String get disableBatteryOptimizationRecommended;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:185
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:274
  ///
  /// In en, this message translates to:
  /// **'Disabled in bit-perfect mode'**
  String get disabledInBitPerfectMode;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:235
  ///
  /// In en, this message translates to:
  /// **'Disabled in Bit-perfect (USB DAC) mode (exact rate required)'**
  String get disabledInBitPerfectUsbDac;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:760
  ///
  /// In en, this message translates to:
  /// **'Disabled while both bit-perfect options are off on this DAP.'**
  String get disabledWhileBothBitPerfectOptions;

  /// lib/features/player/widgets/song_metadata_sheet.dart:80
  ///
  /// In en, this message translates to:
  /// **'Disc'**
  String get disc;

  /// lib/features/songs/screens/metadata_editor_screen.dart:288
  ///
  /// In en, this message translates to:
  /// **'Disc #'**
  String get disc2;

  /// lib/features/player/screens/lyrics_sync_screen.dart:594
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// lib/features/player/screens/lyrics_sync_screen.dart:588
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardChanges;

  /// lib/features/songs/screens/metadata_editor_screen.dart:562
  ///
  /// In en, this message translates to:
  /// **'Discard Changes?'**
  String get discardChanges2;

  /// lib/features/settings/widgets/lastfm_settings_tile.dart:253
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// lib/features/settings/screens/settings_screen.dart:148
  ///
  /// In en, this message translates to:
  /// **'Disconnect behavior and codec info'**
  String get disconnectBehaviorAndCodecInfo;

  /// lib/features/settings/screens/casting_settings_screen.dart:113
  ///
  /// In en, this message translates to:
  /// **'Disconnect from {arg1}'**
  String disconnectFrom(Object arg1);

  /// lib/features/settings/widgets/lastfm_settings_tile.dart:156
  ///
  /// In en, this message translates to:
  /// **'Disconnect Last.fm?'**
  String get disconnectLastFm;

  /// lib/features/settings/widgets/listenbrainz_settings_tile.dart:95
  ///
  /// In en, this message translates to:
  /// **'Disconnect ListenBrainz?'**
  String get disconnectListenbrainz;

  /// lib/features/settings/screens/app_info_settings_screen.dart:501
  ///
  /// In en, this message translates to:
  /// **'Discord'**
  String get discord;

  /// lib/features/settings/screens/casting_settings_screen.dart:76
  ///
  /// In en, this message translates to:
  /// **'Discovers DLNA, UPnP and Chromecast receivers on your network'**
  String get discoversDlnaUpnpAndChromecastReceivers;

  /// lib/features/settings/screens/library_settings_screen.dart:2000
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// lib/features/settings/screens/lyrics_settings_screen.dart:38
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get display;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:205
  ///
  /// In en, this message translates to:
  /// **'Display file format and bitrate in immersive mode'**
  String get displayFileFormatAndBitrateIn;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:343
  ///
  /// In en, this message translates to:
  /// **'Display file format and bitrate in artwork card mode'**
  String get displayFileFormatAndBitrateIn2;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:307
  ///
  /// In en, this message translates to:
  /// **'Display text labels below icons'**
  String get displayTextLabelsBelowIcons;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:330
  ///
  /// In en, this message translates to:
  /// **'Display the album name in artwork card mode'**
  String get displayTheAlbumNameInArtwork;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:318
  ///
  /// In en, this message translates to:
  /// **'Display the artist name in artwork card mode'**
  String get displayTheArtistNameInArtwork;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:193
  ///
  /// In en, this message translates to:
  /// **'Display the artist name in immersive mode'**
  String get displayTheArtistNameInImmersive;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:306
  ///
  /// In en, this message translates to:
  /// **'Display the track title in artwork card mode'**
  String get displayTheTrackTitleInArtwork;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:181
  ///
  /// In en, this message translates to:
  /// **'Display the track title in immersive mode'**
  String get displayTheTrackTitleInImmersive;

  /// lib/features/settings/screens/orbit_settings_screen.dart:63
  ///
  /// In en, this message translates to:
  /// **'Distance between songs along the arc'**
  String get distanceBetweenSongsAlongTheArc;

  /// lib/features/settings/screens/casting_settings_screen.dart:300
  ///
  /// In en, this message translates to:
  /// **'DLNA and UPnP receivers are controlled directly in pure Dart — no extra dependencies. Chromecast support uses the native Cast SDK. Network sources (Subsonic, WebDAV, Jellyfin, UPnP), local files, and cached songs can all be cast — locals are served straight from this phone. While casting, volume keys and the system volume panel control the connected device.'**
  String get dlnaAndUpnpReceiversAreControlled;

  /// lib/features/settings/screens/casting_settings_screen.dart:45
  ///
  /// In en, this message translates to:
  /// **'DLNA / UPnP'**
  String get dlnaUpnp;

  /// lib/features/settings/screens/settings_screen.dart:160
  ///
  /// In en, this message translates to:
  /// **'DLNA, UPnP and Chromecast receivers'**
  String get dlnaUpnpAndChromecastReceivers;

  /// lib/features/settings/screens/support_flick_screen.dart:198
  ///
  /// In en, this message translates to:
  /// **'Donate'**
  String get donate;

  /// lib/features/settings/screens/app_info_settings_screen.dart:718
  ///
  /// In en, this message translates to:
  /// **'Donate, fund features, and keep the app alive'**
  String get donateFundFeaturesAndKeepThe;

  /// lib/features/player/screens/lyrics_sync_screen.dart:634
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:712
  ///
  /// In en, this message translates to:
  /// **'DoP'**
  String get dop;

  /// lib/features/settings/screens/visualizer_settings_screen.dart:111
  ///
  /// In en, this message translates to:
  /// **'Dots'**
  String get dots;

  /// lib/features/settings/screens/equalizer_screen.dart:1753
  ///
  /// In en, this message translates to:
  /// **'Double-tap a band to reset'**
  String get doubleTapABandToReset;

  /// lib/features/settings/screens/equalizer_screen.dart:383
  ///
  /// In en, this message translates to:
  /// **'Double-tap to reset'**
  String get doubleTapToReset;

  /// lib/features/settings/screens/equalizer_screen.dart:1904
  ///
  /// In en, this message translates to:
  /// **'Double-tap to reset this band'**
  String get doubleTapToResetThisBand;

  /// lib/features/player/widgets/player_layout_sheet.dart:566
  ///
  /// In en, this message translates to:
  /// **'{arg1} down'**
  String down(Object arg1);

  /// lib/features/settings/screens/app_info_settings_screen.dart:145
  ///
  /// In en, this message translates to:
  /// **'Download the latest APK from flick-player.site'**
  String get downloadTheLatestApkFromFlick;

  /// lib/features/settings/screens/app_info_settings_screen.dart:638
  ///
  /// In en, this message translates to:
  /// **'Download Update'**
  String get downloadUpdate;

  /// lib/features/settings/widgets/mini_player_customization.dart:107
  ///
  /// In en, this message translates to:
  /// **'{arg1} dp'**
  String dp(Object arg1);

  /// lib/features/settings/widgets/mini_player_customization.dart:131
  ///
  /// In en, this message translates to:
  /// **'{arg1} dp'**
  String dp2(Object arg1);

  /// lib/features/settings/widgets/mini_player_customization.dart:142
  ///
  /// In en, this message translates to:
  /// **'{arg1} dp'**
  String dp3(Object arg1);

  /// lib/features/player/screens/lyrics_sync_screen.dart:1705
  ///
  /// In en, this message translates to:
  /// **'Drag a boundary to stretch or shrink the word before it. The last boundary moves the next line.'**
  String get dragABoundaryToStretchOr;

  /// lib/widgets/equalizer/interactive_eq_graph.dart:129
  ///
  /// In en, this message translates to:
  /// **'Drag bands up or down'**
  String get dragBandsUpOrDown;

  /// lib/widgets/equalizer/interactive_eq_graph.dart:161
  ///
  /// In en, this message translates to:
  /// **'Drag to change frequency & gain'**
  String get dragToChangeFrequencyGain;

  /// lib/widgets/equalizer/interactive_eq_graph.dart:130
  ///
  /// In en, this message translates to:
  /// **'Drag to move • Pinch to widen/narrow'**
  String get dragToMovePinchToWiden;

  /// lib/widgets/equalizer/interactive_eq_graph.dart:160
  ///
  /// In en, this message translates to:
  /// **'Drag vertically to change gain'**
  String get dragVerticallyToChangeGain;

  /// lib/features/settings/screens/orbit_settings_screen.dart:180
  ///
  /// In en, this message translates to:
  /// **'Draw the curved arc behind the songs'**
  String get drawTheCurvedArcBehindThe;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:1040
  ///
  /// In en, this message translates to:
  /// **'Drift {arg1} ms'**
  String driftMs(Object arg1);

  /// lib/features/settings/screens/support_flick_screen.dart:180
  ///
  /// In en, this message translates to:
  /// **'DSD / DSF Playback'**
  String get dsdDsfPlayback;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:713
  ///
  /// In en, this message translates to:
  /// **'DSD mode'**
  String get dsdMode;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1508
  ///
  /// In en, this message translates to:
  /// **'DSD Output Mode'**
  String get dsdOutputMode;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:918
  ///
  /// In en, this message translates to:
  /// **'DSD stream'**
  String get dsdStream;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:243
  ///
  /// In en, this message translates to:
  /// **'Duck on Notifications'**
  String get duckOnNotifications;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:429
  ///
  /// In en, this message translates to:
  /// **'Duplicate Cleaner'**
  String get duplicateCleaner;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:947
  ///
  /// In en, this message translates to:
  /// **'Duplicates removed using recommended picks.'**
  String get duplicatesRemovedUsingRecommendedPicks;

  /// lib/features/settings/screens/audio_settings_screen.dart:330
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// lib/features/player/widgets/online_lyrics_search_sheet.dart:874
  ///
  /// In en, this message translates to:
  /// **'Duration Match'**
  String get durationMatch;

  /// lib/features/settings/screens/equalizer_screen.dart:3255
  ///
  /// In en, this message translates to:
  /// **'Dynamics'**
  String get dynamics;

  /// lib/data/repositories/recently_played_repository.dart:296
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get earlier;

  /// lib/features/settings/widgets/lastfm_settings_tile.dart:921
  ///
  /// In en, this message translates to:
  /// **'Edit Credentials'**
  String get editCredentials;

  /// lib/features/albums/screens/album_detail_screen.dart:313
  ///
  /// In en, this message translates to:
  /// **'Edit Description'**
  String get editDescription;

  /// lib/features/albums/screens/album_detail_screen.dart:339
  ///
  /// In en, this message translates to:
  /// **'Edit description'**
  String get editDescription2;

  /// lib/features/player/widgets/song_actions_sheet.dart:268
  ///
  /// In en, this message translates to:
  /// **'Edit Metadata'**
  String get editMetadata;

  /// lib/features/settings/screens/network_server_edit_screen.dart:368
  ///
  /// In en, this message translates to:
  /// **'Edit Server'**
  String get editServer;

  /// lib/features/player/widgets/inline_lyrics_panel.dart:208
  ///
  /// In en, this message translates to:
  /// **'Edit & Sync'**
  String get editSync;

  /// lib/features/player/screens/lyrics_sync_screen.dart:770
  ///
  /// In en, this message translates to:
  /// **'Edit Text'**
  String get editText;

  /// lib/features/settings/widgets/listenbrainz_settings_tile.dart:348
  ///
  /// In en, this message translates to:
  /// **'Edit Token'**
  String get editToken;

  /// lib/features/folders/screens/folders_screen.dart:2039
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get empty;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1143
  ///
  /// In en, this message translates to:
  /// **'(Empty line)'**
  String get emptyLine;

  /// lib/features/settings/screens/library_settings_screen.dart:2184
  ///
  /// In en, this message translates to:
  /// **'Empty the library; files on disk are kept'**
  String get emptyTheLibraryFilesOnDisk;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1589
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1584
  ///
  /// In en, this message translates to:
  /// **'Enable 432 Hz Tuning?'**
  String get enable432HzTuning;

  /// lib/features/settings/screens/interface_settings_screen.dart:88
  ///
  /// In en, this message translates to:
  /// **'Enable animated transitions and effects'**
  String get enableAnimatedTransitionsAndEffects;

  /// lib/features/settings/screens/equalizer_screen.dart:384
  ///
  /// In en, this message translates to:
  /// **'Enable EQ to edit'**
  String get enableEqToEdit;

  /// lib/features/settings/screens/library_settings_screen.dart:2049
  ///
  /// In en, this message translates to:
  /// **'Enable Full Library Access'**
  String get enableFullLibraryAccess;

  /// lib/features/settings/screens/interface_settings_screen.dart:101
  ///
  /// In en, this message translates to:
  /// **'Enable vibration on interactions'**
  String get enableVibrationOnInteractions;

  /// lib/features/settings/screens/equalizer_screen.dart:1200
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:998
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get endpoint;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:628
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get engine;

  /// lib/features/settings/screens/ui_customization_settings_screen.dart:101
  ///
  /// In en, this message translates to:
  /// **'Engine Selector'**
  String get engineSelector;

  /// lib/features/settings/screens/interface_settings_screen.dart:68
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// lib/features/songs/screens/metadata_editor_screen.dart:126
  ///
  /// In en, this message translates to:
  /// **'Enter a valid {label} number'**
  String enterAValidNumber(Object label);

  /// lib/features/settings/screens/widget_settings_screen.dart:743
  ///
  /// In en, this message translates to:
  /// **'Enter a value from {arg1}% to {arg2}%'**
  String enterAValueFromTo(Object arg1, Object arg2);

  /// lib/features/songs/screens/metadata_editor_screen.dart:115
  ///
  /// In en, this message translates to:
  /// **'Enter a year (1–9999)'**
  String get enterAYear19999;

  /// lib/features/settings/widgets/lastfm_settings_tile.dart:458
  ///
  /// In en, this message translates to:
  /// **'Enter your API key'**
  String get enterYourApiKey;

  /// lib/features/settings/widgets/lastfm_settings_tile.dart:512
  ///
  /// In en, this message translates to:
  /// **'Enter your shared secret'**
  String get enterYourSharedSecret;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:1000
  ///
  /// In en, this message translates to:
  /// **'EP {arg1}'**
  String ep(Object arg1);

  /// lib/features/settings/screens/equalizer_screen.dart:88
  ///
  /// In en, this message translates to:
  /// **'EQ & Dynamics'**
  String get eqDynamics;

  /// lib/features/settings/screens/audio_settings_screen.dart:245
  ///
  /// In en, this message translates to:
  /// **'Equal Power'**
  String get equalPower;

  /// lib/features/player/widgets/player_action_button_row.dart:756
  ///
  /// In en, this message translates to:
  /// **'Equalizer'**
  String get equalizer;

  /// lib/features/settings/screens/uac2_settings_screen.dart:226
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String error(Object error);

  /// lib/widgets/uac2/uac2_device_selector.dart:90
  ///
  /// In en, this message translates to:
  /// **'Error: {arg1}'**
  String error2(Object arg1);

  /// lib/features/settings/screens/uac2_settings_screen.dart:909
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error3;

  /// lib/widgets/uac2/uac2_device_capabilities.dart:89
  ///
  /// In en, this message translates to:
  /// **'Error loading capabilities: {error}'**
  String errorLoadingCapabilities(Object error);

  /// lib/features/player/widgets/add_to_playlist_sheet.dart:70
  ///
  /// In en, this message translates to:
  /// **'Error loading playlists'**
  String get errorLoadingPlaylists;

  /// lib/features/songs/screens/songs_screen.dart:1435
  ///
  /// In en, this message translates to:
  /// **'Error loading playlists: {error}'**
  String errorLoadingPlaylists2(Object error);

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1198
  ///
  /// In en, this message translates to:
  /// **'Error loading preference'**
  String get errorLoadingPreference;

  /// lib/features/songs/screens/songs_screen.dart:1834
  ///
  /// In en, this message translates to:
  /// **'Error loading songs'**
  String get errorLoadingSongs;

  /// lib/models/song.dart:349
  ///
  /// In en, this message translates to:
  /// **'Ethereal Tones'**
  String get etherealTones;

  /// lib/features/settings/screens/missing_metadata_screen.dart:78
  ///
  /// In en, this message translates to:
  /// **'Every album has artist and album tags.'**
  String get everyAlbumHasArtistAndAlbum;

  /// lib/features/settings/screens/library_settings_screen.dart:430
  ///
  /// In en, this message translates to:
  /// **'Every song is removed from your library. Files on disk are kept; rescan your folders to add them again.'**
  String get everySongIsRemovedFromYour;

  /// lib/features/player/widgets/online_lyrics_search_sheet.dart:363
  ///
  /// In en, this message translates to:
  /// **'Exact Match'**
  String get exactMatch;

  /// lib/features/settings/screens/library_settings_screen.dart:1830
  ///
  /// In en, this message translates to:
  /// **'Exclude tiny clips, previews, and accidental scraps'**
  String get excludeTinyClipsPreviewsAndAccidental;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1049
  ///
  /// In en, this message translates to:
  /// **'Exclusive direct PCM is active and bypassing the Android mixer at the track\'s native rate.'**
  String get exclusiveDirectPcmIsActiveAnd;

  /// lib/widgets/uac2/usb_bit_perfect_prompt.dart:254
  ///
  /// In en, this message translates to:
  /// **'Exclusive USB bit-perfect re-engaged.'**
  String get exclusiveUsbBitPerfectReEngaged;

  /// lib/widgets/uac2/usb_bit_perfect_prompt.dart:291
  ///
  /// In en, this message translates to:
  /// **'Exclusive USB dropped to the Android mixer. Bit-perfect is paused.'**
  String get exclusiveUsbDroppedToTheAndroid;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1045
  ///
  /// In en, this message translates to:
  /// **'Exclusive USB is active and bypassing the Android mixer.'**
  String get exclusiveUsbIsActiveAndBypassing;

  /// lib/widgets/uac2/usb_bit_perfect_prompt.dart:255
  ///
  /// In en, this message translates to:
  /// **'Exclusive USB is still unavailable. Check the USB diagnostics.'**
  String get exclusiveUsbIsStillUnavailableCheck;

  /// lib/features/settings/widgets/mini_player_customization.dart:329
  ///
  /// In en, this message translates to:
  /// **'Expanded'**
  String get expanded;

  /// lib/features/settings/screens/ui_customization_settings_screen.dart:179
  ///
  /// In en, this message translates to:
  /// **'Expanded Header Art'**
  String get expandedHeaderArt;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:96
  ///
  /// In en, this message translates to:
  /// **'Experimental'**
  String get experimental;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1559
  ///
  /// In en, this message translates to:
  /// **'Experimental — down-tune playback by 432/440. This disables bit-perfect passthrough and runs the DSP path.'**
  String get experimentalDownTunePlaybackBy432;

  /// lib/features/settings/screens/equalizer_screen.dart:751
  ///
  /// In en, this message translates to:
  /// **'Export current preset'**
  String get exportCurrentPreset;

  /// lib/features/settings/screens/equalizer_screen.dart:626
  ///
  /// In en, this message translates to:
  /// **'Export equalizer preset'**
  String get exportEqualizerPreset;

  /// lib/features/settings/screens/equalizer_screen.dart:652
  ///
  /// In en, this message translates to:
  /// **'Export format'**
  String get exportFormat;

  /// lib/features/settings/screens/equalizer_screen.dart:639
  ///
  /// In en, this message translates to:
  /// **'Exported preset to {savePath}'**
  String exportedPresetTo(Object savePath);

  /// lib/features/settings/screens/equalizer_screen.dart:645
  ///
  /// In en, this message translates to:
  /// **'Exported preset to {fallbackPath}'**
  String exportedPresetTo2(Object fallbackPath);

  /// lib/features/settings/screens/audio_settings_screen.dart:120
  ///
  /// In en, this message translates to:
  /// **'Extended Volume'**
  String get extendedVolume;

  /// lib/features/folders/screens/folders_screen.dart:782
  ///
  /// In en, this message translates to:
  /// **'External'**
  String get externalLabel;

  /// lib/services/metadata_editor_service.dart:73
  ///
  /// In en, this message translates to:
  /// **'External songs cannot be edited.'**
  String get externalSongsCannotBeEdited;

  /// lib/features/songs/screens/metadata_editor_screen.dart:318
  ///
  /// In en, this message translates to:
  /// **'External songs cannot be edited'**
  String get externalSongsCannotBeEdited2;

  /// lib/widgets/uac2/uac2_fallback_manager.dart:61
  ///
  /// In en, this message translates to:
  /// **'Failed to activate fallback'**
  String get failedToActivateFallback;

  /// lib/features/settings/screens/library_settings_screen.dart:488
  ///
  /// In en, this message translates to:
  /// **'Failed to add folder: {e}'**
  String failedToAddFolder(Object e);

  /// lib/features/songs/screens/songs_screen.dart:1289
  ///
  /// In en, this message translates to:
  /// **'Failed to add \"{arg1}\" to favorites'**
  String failedToAddToFavorites(Object arg1);

  /// lib/features/settings/screens/library_settings_screen.dart:288
  ///
  /// In en, this message translates to:
  /// **'Failed to clear cache: {e}'**
  String failedToClearCache(Object e);

  /// lib/widgets/uac2/uac2_fallback_manager.dart:81
  ///
  /// In en, this message translates to:
  /// **'Failed to deactivate fallback'**
  String get failedToDeactivateFallback;

  /// lib/features/settings/screens/equalizer_screen.dart:566
  ///
  /// In en, this message translates to:
  /// **'Failed to import preset file.'**
  String get failedToImportPresetFile;

  /// lib/features/settings/screens/library_settings_screen.dart:224
  ///
  /// In en, this message translates to:
  /// **'Failed to open All Files Access settings: {e}'**
  String failedToOpenAllFilesAccess(Object e);

  /// lib/features/settings/screens/library_settings_screen.dart:203
  ///
  /// In en, this message translates to:
  /// **'Failed to open battery optimization settings: {e}'**
  String failedToOpenBatteryOptimizationSettings(Object e);

  /// lib/features/settings/screens/library_settings_screen.dart:501
  ///
  /// In en, this message translates to:
  /// **'Failed to remove folder: {e}'**
  String failedToRemoveFolder(Object e);

  /// lib/features/settings/screens/library_settings_screen.dart:445
  ///
  /// In en, this message translates to:
  /// **'Failed to remove songs: {e}'**
  String failedToRemoveSongs(Object e);

  /// lib/services/metadata_editor_service.dart:100
  ///
  /// In en, this message translates to:
  /// **'Failed to save metadata: {e}'**
  String failedToSaveMetadata(Object e);

  /// lib/features/songs/screens/metadata_editor_screen.dart:204
  ///
  /// In en, this message translates to:
  /// **'Failed to save metadata.'**
  String get failedToSaveMetadata2;

  /// lib/widgets/uac2/uac2_stream_config.dart:270
  ///
  /// In en, this message translates to:
  /// **'Failed to start streaming'**
  String get failedToStartStreaming;

  /// lib/widgets/uac2/uac2_stream_config.dart:283
  ///
  /// In en, this message translates to:
  /// **'Failed to stop streaming'**
  String get failedToStopStreaming;

  /// lib/models/album_color_mode.dart:35
  ///
  /// In en, this message translates to:
  /// **'Faint hue shift from album art.'**
  String get faintHueShiftFromAlbumArt;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:706
  ///
  /// In en, this message translates to:
  /// **'Fallback'**
  String get fallback;

  /// lib/widgets/uac2/uac2_fallback_manager.dart:136
  ///
  /// In en, this message translates to:
  /// **'Fallback Audio'**
  String get fallbackAudio;

  /// lib/widgets/uac2/uac2_fallback_manager.dart:60
  ///
  /// In en, this message translates to:
  /// **'Fallback audio activated'**
  String get fallbackAudioActivated;

  /// lib/widgets/uac2/uac2_fallback_manager.dart:80
  ///
  /// In en, this message translates to:
  /// **'Fallback audio deactivated'**
  String get fallbackAudioDeactivated;

  /// lib/widgets/uac2/uac2_fallback_manager.dart:197
  ///
  /// In en, this message translates to:
  /// **'Fallback audio will be used if UAC2 device fails'**
  String get fallbackAudioWillBeUsedIf;

  /// lib/features/settings/screens/visualizer_settings_screen.dart:186
  ///
  /// In en, this message translates to:
  /// **'Fast direct tracking — immediate response'**
  String get fastDirectTrackingImmediateResponse;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:192
  ///
  /// In en, this message translates to:
  /// **'Fast Index Scrolling'**
  String get fastIndexScrolling;

  /// lib/widgets/common/detail_header.dart:257
  ///
  /// In en, this message translates to:
  /// **'Favorite all'**
  String get favoriteAll;

  /// lib/features/settings/screens/interface_settings_screen.dart:289
  ///
  /// In en, this message translates to:
  /// **'Favorite Removal'**
  String get favoriteRemoval;

  /// lib/features/favorites/screens/favorites_screen.dart:301
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// lib/features/milestone/screens/milestones_screen.dart:503
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get feb;

  /// lib/features/settings/screens/equalizer_screen.dart:3654
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:909
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// lib/features/songs/screens/metadata_editor_screen.dart:444
  ///
  /// In en, this message translates to:
  /// **'File Information'**
  String get fileInformation;

  /// lib/features/player/widgets/song_metadata_sheet.dart:82
  ///
  /// In en, this message translates to:
  /// **'File Path'**
  String get filePath;

  /// lib/features/settings/screens/library_settings_screen.dart:982
  ///
  /// In en, this message translates to:
  /// **'{done} / {total} files'**
  String files(Object done, Object total);

  /// lib/features/settings/screens/missing_metadata_screen.dart:128
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} file} other{{count} files}}'**
  String files2(int count);

  /// lib/features/settings/screens/library_settings_screen.dart:984
  ///
  /// In en, this message translates to:
  /// **'{arg1} files checked…'**
  String filesChecked(Object arg1);

  /// lib/features/settings/screens/equalizer_screen.dart:3602
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// lib/features/songs/screens/songs_screen.dart:2894
  ///
  /// In en, this message translates to:
  /// **'FILTER BY FORMAT'**
  String get filterByFormat;

  /// lib/features/settings/screens/library_settings_screen.dart:1781
  ///
  /// In en, this message translates to:
  /// **'Filter files, size limits, and playlist import options'**
  String get filterFilesSizeLimitsAndPlaylist;

  /// lib/features/settings/screens/logs_screen.dart:355
  ///
  /// In en, this message translates to:
  /// **'Filter logs…'**
  String get filterLogs;

  /// lib/features/settings/screens/library_settings_screen.dart:1815
  ///
  /// In en, this message translates to:
  /// **'Filter Non-Music Files & Folders'**
  String get filterNonMusicFilesFolders;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:395
  ///
  /// In en, this message translates to:
  /// **'Find and clean up duplicate songs'**
  String get findAndCleanUpDuplicateSongs;

  /// lib/features/settings/screens/library_settings_screen.dart:2148
  ///
  /// In en, this message translates to:
  /// **'Find and remove duplicate songs'**
  String get findAndRemoveDuplicateSongs;

  /// lib/features/search/screens/search_screen.dart:249
  ///
  /// In en, this message translates to:
  /// **'Find songs, artists, albums, folders…'**
  String get findSongsArtistsAlbumsFolders;

  /// lib/features/settings/screens/audio_settings_screen.dart:214
  ///
  /// In en, this message translates to:
  /// **'Fine-tune the overall gain'**
  String get fineTuneTheOverallGain;

  /// lib/features/settings/screens/library_settings_screen.dart:1170
  ///
  /// In en, this message translates to:
  /// **'Finishing metadata enrichment…'**
  String get finishingMetadataEnrichment;

  /// lib/features/menu/screens/restarting_screen.dart:13
  ///
  /// In en, this message translates to:
  /// **'Finishing up…'**
  String get finishingUp;

  /// lib/features/settings/screens/network_sources_screen.dart:116
  ///
  /// In en, this message translates to:
  /// **'Fix'**
  String get fix;

  /// lib/features/settings/screens/library_settings_screen.dart:2213
  ///
  /// In en, this message translates to:
  /// **'Fix Missing Metadata'**
  String get fixMissingMetadata;

  /// lib/features/settings/screens/equalizer_screen.dart:1741
  ///
  /// In en, this message translates to:
  /// **'31 fixed bands'**
  String get fixedBands;

  /// lib/features/settings/screens/equalizer_screen.dart:1780
  ///
  /// In en, this message translates to:
  /// **'Fixed center frequencies with a {arg1} dB range. Tap to interact.'**
  String fixedCenterFrequenciesWithADb(Object arg1);

  /// lib/features/player/widgets/player_layout_sheet.dart:1200
  ///
  /// In en, this message translates to:
  /// **'FLAC · 24-bit / 96 kHz'**
  String get flac24Bit96Khz;

  /// lib/services/eq_preset_service.dart:280
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get flat;

  /// lib/features/settings/screens/equalizer_screen.dart:1748
  ///
  /// In en, this message translates to:
  /// **'Flat response'**
  String get flatResponse;

  /// lib/features/settings/screens/app_info_settings_screen.dart:547
  ///
  /// In en, this message translates to:
  /// **'Flick'**
  String get flick;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:604
  ///
  /// In en, this message translates to:
  /// **'Flick can attempt to prefer a specific codec above, but success depends on your device, headset, and Android version. Codec forcing uses a hidden system API and may not work on non-rooted devices.'**
  String get flickCanAttemptToPreferA;

  /// lib/features/settings/screens/privacy_policy_screen.dart:71
  ///
  /// In en, this message translates to:
  /// **'Flick can receive playback handoffs from Locker (another Moss app). Playback intents contain only song file paths/metadata. No personal data is exchanged. The integration is entirely local.'**
  String get flickCanReceivePlaybackHandoffsFrom;

  /// lib/features/settings/screens/app_info_settings_screen.dart:176
  ///
  /// In en, this message translates to:
  /// **'Flick checks flick-player.site for updates whenever you are online'**
  String get flickChecksFlickPlayerSiteFor;

  /// lib/features/settings/screens/support_flick_screen.dart:138
  ///
  /// In en, this message translates to:
  /// **'Flick is built and maintained by one person with zero budget. No team, no funding, no ads.'**
  String get flickIsBuiltAndMaintainedBy;

  /// lib/features/settings/screens/logs_screen.dart:110
  ///
  /// In en, this message translates to:
  /// **'Flick logs'**
  String get flickLogs;

  /// lib/features/settings/screens/app_info_settings_screen.dart:444
  ///
  /// In en, this message translates to:
  /// **'Flick Player'**
  String get flickPlayer;

  /// lib/features/settings/screens/privacy_policy_screen.dart:36
  ///
  /// In en, this message translates to:
  /// **'Flick Player does not collect, store, or transmit any personal data. No personal information, usage analytics, crash reports, or advertising identifiers are gathered. No data is shared with third parties.'**
  String get flickPlayerDoesNotCollectStore;

  /// lib/features/player/widgets/player_layout_sheet.dart:930
  ///
  /// In en, this message translates to:
  /// **'Flick Preview'**
  String get flickPreview;

  /// lib/features/settings/screens/app_info_settings_screen.dart:175
  ///
  /// In en, this message translates to:
  /// **'Flick scans for Play Store updates whenever you are online'**
  String get flickScansForPlayStoreUpdates;

  /// lib/features/settings/screens/support_flick_screen.dart:145
  ///
  /// In en, this message translates to:
  /// **'Flick will always be free. Donations keep the project alive without paywalls or subscriptions.'**
  String get flickWillAlwaysBeFreeDonations;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:343
  ///
  /// In en, this message translates to:
  /// **'Flick will force your chosen codec on connect'**
  String get flickWillForceYourChosenCodec;

  /// lib/features/settings/screens/app_info_settings_screen.dart:230
  ///
  /// In en, this message translates to:
  /// **'FlickPlayer'**
  String get flickplayer;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:154
  ///
  /// In en, this message translates to:
  /// **'Floating Island'**
  String get floatingIsland;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:83
  ///
  /// In en, this message translates to:
  /// **'Floating Mini-Player'**
  String get floatingMiniPlayer;

  /// lib/models/playback_context.dart:13
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get folder;

  /// lib/features/folders/screens/folders_screen.dart:2258
  ///
  /// In en, this message translates to:
  /// **'FOLDER LIMIT'**
  String get folderLimit;

  /// lib/features/folders/screens/folders_screen.dart:2588
  ///
  /// In en, this message translates to:
  /// **'Folder Name'**
  String get folderName;

  /// lib/features/settings/screens/library_settings_screen.dart:996
  ///
  /// In en, this message translates to:
  /// **'Folder {current} of {total}'**
  String folderOf(Object current, Object total);

  /// lib/widgets/common/floating_scan_progress.dart:403
  ///
  /// In en, this message translates to:
  /// **'Folder {current} of {total}'**
  String folderOf2(Object current, Object total);

  /// lib/features/folders/screens/folders_screen.dart:2590
  ///
  /// In en, this message translates to:
  /// **'Folder Song Count'**
  String get folderSongCount;

  /// lib/features/folders/screens/folders_screen.dart:320
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get folders;

  /// lib/features/settings/screens/library_settings_screen.dart:1474
  ///
  /// In en, this message translates to:
  /// **'{arg1} folders'**
  String folders2(Object arg1);

  /// lib/features/settings/screens/settings_screen.dart:84
  ///
  /// In en, this message translates to:
  /// **'Folders, scanning, and duplicates'**
  String get foldersScanningAndDuplicates;

  /// lib/features/folders/screens/folders_screen.dart:2267
  ///
  /// In en, this message translates to:
  /// **'Folders shown per page'**
  String get foldersShownPerPage;

  /// lib/features/settings/screens/widget_settings_screen.dart:235
  ///
  /// In en, this message translates to:
  /// **'Font Scale'**
  String get fontScale;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1681
  ///
  /// In en, this message translates to:
  /// **'Force DoP'**
  String get forceDop;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1641
  ///
  /// In en, this message translates to:
  /// **'Force DoP — Always use DSD over PCM (USB DAC)'**
  String get forceDopAlwaysUseDsdOver;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1672
  ///
  /// In en, this message translates to:
  /// **'Force PCM'**
  String get forcePcm;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1639
  ///
  /// In en, this message translates to:
  /// **'Force PCM — Always convert DSD to PCM'**
  String get forcePcmAlwaysConvertDsdTo;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:551
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get format;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:218
  ///
  /// In en, this message translates to:
  /// **'Format controls are disabled. The engine uses its default format.'**
  String get formatControlsAreDisabledTheEngine;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:233
  ///
  /// In en, this message translates to:
  /// **'Format Strategy'**
  String get formatStrategy;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:217
  ///
  /// In en, this message translates to:
  /// **'Format strategy and custom format controls are active.'**
  String get formatStrategyAndCustomFormatControls;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:244
  ///
  /// In en, this message translates to:
  /// **'Format strategy is disabled in Bit-perfect (USB DAC) mode because exact sample rate matching is required. Disable Bit-perfect (USB DAC) to change format preferences.'**
  String get formatStrategyIsDisabledInBit;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:249
  ///
  /// In en, this message translates to:
  /// **'Format strategy is unavailable because Audio Format is disabled in Settings.'**
  String get formatStrategyIsUnavailableBecauseAudio;

  /// lib/features/settings/screens/widgets/autoeq_search_sheet.dart:121
  ///
  /// In en, this message translates to:
  /// **'Found \"{arg1}\" online.'**
  String foundOnline(Object arg1);

  /// lib/features/player/widgets/bit_perfect_indicator.dart:988
  ///
  /// In en, this message translates to:
  /// **'{arg1} fr/pkt'**
  String frPkt(Object arg1);

  /// lib/features/settings/screens/support_flick_screen.dart:143
  ///
  /// In en, this message translates to:
  /// **'Free & Open Source'**
  String get freeOpenSource;

  /// lib/features/settings/screens/equalizer_screen.dart:2623
  ///
  /// In en, this message translates to:
  /// **'Freq'**
  String get freq;

  /// lib/features/settings/screens/equalizer_screen.dart:2611
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequency;

  /// lib/features/settings/screens/visualizer_settings_screen.dart:119
  ///
  /// In en, this message translates to:
  /// **'Frequency Focus'**
  String get frequencyFocus;

  /// lib/widgets/common/fetched_description.dart:41
  ///
  /// In en, this message translates to:
  /// **'From {sourceLabel}'**
  String from(Object sourceLabel);

  /// lib/features/settings/widgets/mini_player_customization.dart:137
  ///
  /// In en, this message translates to:
  /// **'From square corners to a rounded bar'**
  String get fromSquareCornersToARounded;

  /// lib/models/player_screen_mode.dart:26
  ///
  /// In en, this message translates to:
  /// **'Full-bleed album art with the current cinematic look.'**
  String get fullBleedAlbumArtWithThe;

  /// lib/features/settings/screens/interface_settings_screen.dart:264
  ///
  /// In en, this message translates to:
  /// **'Full Library'**
  String get fullLibrary;

  /// lib/features/settings/screens/library_settings_screen.dart:1884
  ///
  /// In en, this message translates to:
  /// **'Full Library Access'**
  String get fullLibraryAccess;

  /// lib/providers/tutorial_provider.dart:48
  ///
  /// In en, this message translates to:
  /// **'Full Player'**
  String get fullPlayer;

  /// lib/features/settings/screens/library_settings_screen.dart:708
  ///
  /// In en, this message translates to:
  /// **'Full scan'**
  String get fullScan;

  /// lib/features/settings/screens/visualizer_settings_screen.dart:124
  ///
  /// In en, this message translates to:
  /// **'Full Spectrum'**
  String get fullSpectrum;

  /// lib/features/player/widgets/player_layout_sheet.dart:304
  ///
  /// In en, this message translates to:
  /// **'Full-view card size'**
  String get fullViewCardSize;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:164
  ///
  /// In en, this message translates to:
  /// **'Full-view Card Size'**
  String get fullViewCardSize2;

  /// lib/features/player/widgets/player_layout_sheet.dart:152
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get fullscreen;

  /// lib/features/settings/screens/support_flick_screen.dart:182
  ///
  /// In en, this message translates to:
  /// **'Funding native DSD/DSF playback development — a highly requested feature for audiophiles.'**
  String get fundingNativeDsdDsfPlaybackDevelopment;

  /// lib/features/settings/screens/equalizer_screen.dart:3511
  ///
  /// In en, this message translates to:
  /// **'FX off'**
  String get fxOff;

  /// lib/features/settings/screens/equalizer_screen.dart:3511
  ///
  /// In en, this message translates to:
  /// **'FX on'**
  String get fxOn;

  /// lib/features/settings/screens/equalizer_screen.dart:2666
  ///
  /// In en, this message translates to:
  /// **'Gain'**
  String get gain;

  /// lib/features/settings/widgets/mini_player_customization.dart:101
  ///
  /// In en, this message translates to:
  /// **'Gap Above Navigation'**
  String get gapAboveNavigation;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:272
  ///
  /// In en, this message translates to:
  /// **'Gapless Playback'**
  String get gaplessPlayback;

  /// lib/features/settings/screens/settings_screen.dart:104
  ///
  /// In en, this message translates to:
  /// **'Gapless, view mode, and appearance'**
  String get gaplessViewModeAndAppearance;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:26
  ///
  /// In en, this message translates to:
  /// **'{arg1} GB'**
  String gb(Object arg1);

  /// lib/features/player/widgets/song_metadata_sheet.dart:70
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get genre;

  /// lib/features/settings/screens/orbit_settings_screen.dart:21
  ///
  /// In en, this message translates to:
  /// **'Geometry'**
  String get geometry;

  /// lib/features/onboarding/screens/onboarding_screen.dart:269
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// lib/features/settings/screens/app_info_settings_screen.dart:639
  ///
  /// In en, this message translates to:
  /// **'Get the latest APK from flick-player.site'**
  String get getTheLatestApkFromFlick;

  /// lib/features/settings/widgets/lastfm_settings_tile.dart:404
  ///
  /// In en, this message translates to:
  /// **'Get your API credentials'**
  String get getYourApiCredentials;

  /// lib/features/settings/screens/app_info_settings_screen.dart:489
  ///
  /// In en, this message translates to:
  /// **'GitHub'**
  String get github;

  /// lib/features/player/widgets/song_actions_sheet.dart:324
  ///
  /// In en, this message translates to:
  /// **'Go to Album'**
  String get goToAlbum;

  /// lib/features/player/widgets/song_actions_sheet.dart:315
  ///
  /// In en, this message translates to:
  /// **'Go to Artist'**
  String get goToArtist;

  /// lib/features/settings/screens/support_flick_screen.dart:166
  ///
  /// In en, this message translates to:
  /// **'Google Play Developer Fees'**
  String get googlePlayDeveloperFees;

  /// lib/features/player/screens/lyrics_sync_screen.dart:721
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:235
  ///
  /// In en, this message translates to:
  /// **'Grant Bluetooth access'**
  String get grantBluetoothAccess;

  /// lib/features/settings/screens/library_settings_screen.dart:1886
  ///
  /// In en, this message translates to:
  /// **'Granted — scans read every volume directly, including DSD/DSF/WavPack'**
  String get grantedScansReadEveryVolumeDirectly;

  /// lib/features/settings/screens/equalizer_screen.dart:4162
  ///
  /// In en, this message translates to:
  /// **'Graphic'**
  String get graphic;

  /// lib/features/settings/screens/equalizer_screen.dart:1735
  ///
  /// In en, this message translates to:
  /// **'Graphic EQ'**
  String get graphicEq;

  /// lib/features/settings/screens/widget_settings_screen.dart:291
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get green;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:152
  ///
  /// In en, this message translates to:
  /// **'Grouping by title & artist — this is usually quick.'**
  String get groupingByTitleArtistThisIs;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:626
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groups;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:394
  ///
  /// In en, this message translates to:
  /// **'{arg1} groups • {arg2} to remove'**
  String groupsToRemove(Object arg1, Object arg2);

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:556
  ///
  /// In en, this message translates to:
  /// **'{arg1} groups • {toRemove} to remove'**
  String groupsToRemove2(Object arg1, Object toRemove);

  /// lib/features/settings/widgets/mini_player_customization.dart:126
  ///
  /// In en, this message translates to:
  /// **'Grows further if larger system text needs room'**
  String get growsFurtherIfLargerSystemText;

  /// lib/features/recently_added/screens/recently_added_screen.dart:493
  ///
  /// In en, this message translates to:
  /// **'{arg1}h ago'**
  String hAgo(Object arg1);

  /// lib/features/settings/screens/interface_settings_screen.dart:100
  ///
  /// In en, this message translates to:
  /// **'Haptic Feedback'**
  String get hapticFeedback;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:1153
  ///
  /// In en, this message translates to:
  /// **'Hardware (USB DAC)'**
  String get hardwareUsbDac;

  /// lib/widgets/uac2/uac2_volume_control.dart:246
  ///
  /// In en, this message translates to:
  /// **'Hardware volume is detected, but writes stay blocked while live direct USB playback is active.'**
  String get hardwareVolumeIsDetectedButWrites;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:1579
  ///
  /// In en, this message translates to:
  /// **'Has artwork'**
  String get hasArtwork;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:241
  ///
  /// In en, this message translates to:
  /// **'Having more than 4 buttons may cause text labels to compress. Consider reducing the button spacing below.'**
  String get havingMoreThan4ButtonsMay;

  /// lib/features/settings/screens/uac2_settings_screen.dart:715
  ///
  /// In en, this message translates to:
  /// **'Held'**
  String get held;

  /// lib/features/settings/screens/settings_screen.dart:230
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// lib/features/settings/screens/settings_screen.dart:237
  ///
  /// In en, this message translates to:
  /// **'Help & Manual'**
  String get helpManual;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:417
  ///
  /// In en, this message translates to:
  /// **'Hi-Res Direct'**
  String get hiResDirect;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:202
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get hidden;

  /// lib/features/player/widgets/player_action_button_row.dart:440
  ///
  /// In en, this message translates to:
  /// **'Hide lyrics'**
  String get hideLyrics;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:79
  ///
  /// In en, this message translates to:
  /// **'Hide navigation buttons after being idle'**
  String get hideNavigationButtonsAfterBeingIdle;

  /// lib/features/settings/screens/network_server_edit_screen.dart:765
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// lib/features/settings/screens/library_settings_screen.dart:1843
  ///
  /// In en, this message translates to:
  /// **'Hide short stingers, ringtones, and voice fragments'**
  String get hideShortStingersRingtonesAndVoice;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:157
  ///
  /// In en, this message translates to:
  /// **'Hide the floating mini-player pill'**
  String get hideTheFloatingMiniPlayerPill;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:206
  ///
  /// In en, this message translates to:
  /// **'Hide the index rail after inactivity'**
  String get hideTheIndexRailAfterInactivity;

  /// lib/features/player/widgets/player_action_button_row.dart:551
  ///
  /// In en, this message translates to:
  /// **'Hide visualizer'**
  String get hideVisualizer;

  /// lib/features/player/widgets/song_actions_sheet.dart:305
  ///
  /// In en, this message translates to:
  /// **'Hide Visualizer'**
  String get hideVisualizer2;

  /// lib/features/settings/screens/orbit_settings_screen.dart:158
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get high;

  /// lib/features/settings/screens/interface_settings_screen.dart:235
  ///
  /// In en, this message translates to:
  /// **'High (120Hz)'**
  String get high120hz;

  /// lib/features/settings/screens/visualizer_settings_screen.dart:149
  ///
  /// In en, this message translates to:
  /// **'High frequencies only'**
  String get highFrequenciesOnly;

  /// lib/providers/equalizer_provider.dart:35
  ///
  /// In en, this message translates to:
  /// **'High Pass'**
  String get highPass;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:487
  ///
  /// In en, this message translates to:
  /// **'High quality, widely supported'**
  String get highQualityWidelySupported;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:489
  ///
  /// In en, this message translates to:
  /// **'High-resolution aptX'**
  String get highResolutionAptx;

  /// lib/providers/equalizer_provider.dart:31
  ///
  /// In en, this message translates to:
  /// **'High Shelf'**
  String get highShelf;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:491
  ///
  /// In en, this message translates to:
  /// **'Highest bitrate (up to 990 kbps)'**
  String get highestBitrateUpTo990Kbps;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1211
  ///
  /// In en, this message translates to:
  /// **'Highest Quality'**
  String get highestQuality;

  /// lib/features/recently_played/screens/recently_played_screen.dart:208
  ///
  /// In en, this message translates to:
  /// **'History cleared'**
  String get historyCleared;

  /// lib/features/settings/screens/interface_settings_screen.dart:307
  ///
  /// In en, this message translates to:
  /// **'Hold a song to unfavorite'**
  String get holdASongToUnfavorite;

  /// lib/features/settings/screens/ui_customization_settings_screen.dart:24
  ///
  /// In en, this message translates to:
  /// **'Home Screen Sections'**
  String get homeScreenSections;

  /// lib/features/settings/screens/orbit_settings_screen.dart:50
  ///
  /// In en, this message translates to:
  /// **'Horizontal Reach'**
  String get horizontalReach;

  /// lib/features/settings/screens/orbit_settings_screen.dart:51
  ///
  /// In en, this message translates to:
  /// **'How far the arc opens from the left edge'**
  String get howFarTheArcOpensFrom;

  /// lib/features/settings/screens/orbit_settings_screen.dart:126
  ///
  /// In en, this message translates to:
  /// **'How much side cards shrink away from center'**
  String get howMuchSideCardsShrinkAway;

  /// lib/features/settings/screens/app_info_settings_screen.dart:667
  ///
  /// In en, this message translates to:
  /// **'How we handle your data'**
  String get howWeHandleYourData;

  /// lib/features/settings/screens/orbit_settings_screen.dart:92
  ///
  /// In en, this message translates to:
  /// **'How wide each card spans across the screen'**
  String get howWideEachCardSpansAcross;

  /// lib/features/settings/screens/network_server_edit_screen.dart:77
  ///
  /// In en, this message translates to:
  /// **'HTTP Basic needs it recoverable; stored encoded'**
  String get httpBasicNeedsItRecoverableStored;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:1145
  ///
  /// In en, this message translates to:
  /// **'{rate} Hz'**
  String hz(Object rate);

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:657
  ///
  /// In en, this message translates to:
  /// **'{hz} Hz'**
  String hz3(Object hz);

  /// lib/features/settings/screens/equalizer_screen.dart:2629
  ///
  /// In en, this message translates to:
  /// **'Hz'**
  String get hz5;

  /// lib/widgets/alac_conversion_indicator.dart:137
  ///
  /// In en, this message translates to:
  /// **'{arg1} Hz'**
  String hz6(Object arg1);

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1557
  ///
  /// In en, this message translates to:
  /// **'432 Hz Tuning'**
  String get hzTuning;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:290
  ///
  /// In en, this message translates to:
  /// **'Icon Size'**
  String get iconSize;

  /// lib/features/albums/widgets/identify_album_sheet.dart:64
  ///
  /// In en, this message translates to:
  /// **'Identified {count, plural, =1{{count} song} other{{count} songs}}{note}.'**
  String identified(int count, Object note);

  /// lib/features/albums/screens/album_detail_screen.dart:349
  ///
  /// In en, this message translates to:
  /// **'Identify album'**
  String get identifyAlbum;

  /// lib/features/albums/widgets/identify_album_sheet.dart:215
  ///
  /// In en, this message translates to:
  /// **'Identify Album'**
  String get identifyAlbum2;

  /// lib/features/settings/screens/library_settings_screen.dart:2214
  ///
  /// In en, this message translates to:
  /// **'Identify albums with unknown artist or title tags'**
  String get identifyAlbumsWithUnknownArtistOr;

  /// lib/features/settings/screens/uac2_settings_screen.dart:899
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get idle;

  /// lib/features/settings/screens/privacy_policy_screen.dart:61
  ///
  /// In en, this message translates to:
  /// **'If you connect your Last.fm account, credentials are stored securely on-device. Play data is sent only to Last.fm. We do not receive or process this data.'**
  String get ifYouConnectYourLastFm;

  /// lib/features/settings/screens/library_settings_screen.dart:1828
  ///
  /// In en, this message translates to:
  /// **'Ignore Tracks Under 500 KB'**
  String get ignoreTracksUnder500Kb;

  /// lib/features/settings/screens/library_settings_screen.dart:1841
  ///
  /// In en, this message translates to:
  /// **'Ignore Tracks Under 60 Seconds'**
  String get ignoreTracksUnder60Seconds;

  /// lib/features/player/widgets/player_layout_sheet.dart:278
  ///
  /// In en, this message translates to:
  /// **'Immersive'**
  String get immersive;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:168
  ///
  /// In en, this message translates to:
  /// **'Immersive Full View Timer'**
  String get immersiveFullViewTimer;

  /// lib/features/settings/screens/library_settings_screen.dart:1854
  ///
  /// In en, this message translates to:
  /// **'Import M3U/M3U8 Playlists'**
  String get importM3uM3u8Playlists;

  /// lib/features/settings/screens/equalizer_screen.dart:744
  ///
  /// In en, this message translates to:
  /// **'Import preset file'**
  String get importPresetFile;

  /// lib/features/settings/screens/equalizer_screen.dart:561
  ///
  /// In en, this message translates to:
  /// **'Imported \"{arg1}\"'**
  String imported(Object arg1);

  /// lib/features/songs/widgets/album_art_picker_bottom_sheet.dart:669
  ///
  /// In en, this message translates to:
  /// **'Imported art is saved inside the app and synced to every song in this album.'**
  String get importedArtIsSavedInsideThe;

  /// lib/features/songs/widgets/album_art_picker_bottom_sheet.dart:670
  ///
  /// In en, this message translates to:
  /// **'Imported art is saved inside the app for this song only.'**
  String get importedArtIsSavedInsideThe2;

  /// lib/features/settings/screens/equalizer_screen.dart:3762
  ///
  /// In en, this message translates to:
  /// **'Impulse response'**
  String get impulseResponse;

  /// lib/features/settings/screens/privacy_policy_screen.dart:74
  ///
  /// In en, this message translates to:
  /// **'In-App Updates'**
  String get inAppUpdates;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:1555
  ///
  /// In en, this message translates to:
  /// **'in {folder}'**
  String inLabel(Object folder);

  /// lib/features/recently_added/screens/recently_added_screen.dart:249
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} song} other{{count} songs}} in your library'**
  String inYourLibrary(int count);

  /// lib/features/player/widgets/bit_perfect_indicator.dart:670
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// lib/features/settings/screens/library_settings_screen.dart:1171
  ///
  /// In en, this message translates to:
  /// **'Initializing…'**
  String get initializing;

  /// lib/features/settings/screens/equalizer_screen.dart:3406
  ///
  /// In en, this message translates to:
  /// **'Input Gain'**
  String get inputGain;

  /// lib/features/player/widgets/online_lyrics_search_sheet.dart:885
  ///
  /// In en, this message translates to:
  /// **'Inst'**
  String get inst;

  /// lib/features/player/screens/lyrics_sync_screen.dart:775
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get instructions;

  /// lib/features/player/widgets/online_lyrics_search_sheet.dart:594
  ///
  /// In en, this message translates to:
  /// **'Instrumental'**
  String get instrumental;

  /// lib/features/settings/screens/integrations_settings_screen.dart:14
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get integrations;

  /// lib/widgets/equalizer/interactive_eq_graph.dart:121
  ///
  /// In en, this message translates to:
  /// **'Interactive EQ'**
  String get interactiveEq;

  /// lib/features/settings/screens/app_info_settings_screen.dart:693
  ///
  /// In en, this message translates to:
  /// **'Interactive Tutorial'**
  String get interactiveTutorial;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:693
  ///
  /// In en, this message translates to:
  /// **'Interface claimed'**
  String get interfaceClaimed;

  /// lib/features/settings/screens/interface_settings_screen.dart:36
  ///
  /// In en, this message translates to:
  /// **'Interface'**
  String get interfaceLabel;

  /// lib/features/settings/screens/library_settings_screen.dart:1254
  ///
  /// In en, this message translates to:
  /// **'{folder} is offline — retained songs still listed'**
  String isOfflineRetainedSongsStillListed(Object folder);

  /// lib/features/settings/screens/uac2_preferences_screen.dart:828
  ///
  /// In en, this message translates to:
  /// **'Isochronous USB'**
  String get isochronousUsb;

  /// lib/features/settings/screens/orbit_settings_screen.dart:62
  ///
  /// In en, this message translates to:
  /// **'Item Spacing'**
  String get itemSpacing;

  /// lib/features/folders/screens/folders_screen.dart:1185
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String items(Object count);

  /// lib/features/milestone/screens/milestones_screen.dart:502
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get jan;

  /// lib/features/settings/screens/network_server_edit_screen.dart:65
  ///
  /// In en, this message translates to:
  /// **'Jellyfin'**
  String get jellyfin;

  /// lib/features/settings/screens/network_server_edit_screen.dart:66
  ///
  /// In en, this message translates to:
  /// **'Jellyfin · Emby'**
  String get jellyfinEmby;

  /// lib/features/milestone/screens/milestones_screen.dart:508
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get jul;

  /// lib/features/settings/screens/app_info_settings_screen.dart:632
  ///
  /// In en, this message translates to:
  /// **'Jump to the Flick listing and update from there'**
  String get jumpToTheFlickListingAnd;

  /// lib/features/milestone/screens/milestones_screen.dart:507
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get jun;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:758
  ///
  /// In en, this message translates to:
  /// **'just_audio / ExoPlayer'**
  String get justAudioExoplayer;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:629
  ///
  /// In en, this message translates to:
  /// **'just_audio / ExoPlayer (default)'**
  String get justAudioExoplayerDefault;

  /// lib/features/recently_added/screens/recently_added_screen.dart:491
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// lib/features/settings/screens/lyrics_settings_screen.dart:43
  ///
  /// In en, this message translates to:
  /// **'Karaoke effect'**
  String get karaokeEffect;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1623
  ///
  /// In en, this message translates to:
  /// **'Karaoke Preview'**
  String get karaokePreview;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:22
  ///
  /// In en, this message translates to:
  /// **'{arg1} KB'**
  String kb(Object arg1);

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:1251
  ///
  /// In en, this message translates to:
  /// **'Keep all'**
  String get keepAll;

  /// lib/features/player/screens/lyrics_sync_screen.dart:598
  ///
  /// In en, this message translates to:
  /// **'Keep Editing'**
  String get keepEditing;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:143
  ///
  /// In en, this message translates to:
  /// **'Keep mini player and nav visible'**
  String get keepMiniPlayerAndNavVisible;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:274
  ///
  /// In en, this message translates to:
  /// **'Keep playback paused when a device reconnects'**
  String get keepPlaybackPausedWhenADevice;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:35
  ///
  /// In en, this message translates to:
  /// **'Keep Playing on Quit'**
  String get keepPlayingOnQuit;

  /// lib/features/settings/screens/audio_settings_screen.dart:206
  ///
  /// In en, this message translates to:
  /// **'Keep relative levels inside each album'**
  String get keepRelativeLevelsInsideEachAlbum;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:1016
  ///
  /// In en, this message translates to:
  /// **'Keeping • {type} • {br}'**
  String keeping(Object type, Object br);

  /// lib/features/settings/screens/support_flick_screen.dart:168
  ///
  /// In en, this message translates to:
  /// **'Keeping Flick on the Play Store costs \$25/year in developer registration fees.'**
  String get keepingFlickOnThePlayStore;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:1019
  ///
  /// In en, this message translates to:
  /// **'Keeping {keptCount} of {arg1} • {removeCount} to remove'**
  String keepingOfToRemove(Object keptCount, Object arg1, Object removeCount);

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:1531
  ///
  /// In en, this message translates to:
  /// **'Keeping this version'**
  String get keepingThisVersion;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:51
  ///
  /// In en, this message translates to:
  /// **'Keeps bit-perfect audio alive in the background'**
  String get keepsBitPerfectAudioAliveIn;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:796
  ///
  /// In en, this message translates to:
  /// **'Keeps software volume and DSP active on the DAP shared path.'**
  String get keepsSoftwareVolumeAndDspActive;

  /// lib/features/settings/screens/network_server_edit_screen.dart:69
  ///
  /// In en, this message translates to:
  /// **'Kept in secure storage to re-sign in when the token expires'**
  String get keptInSecureStorageToRe;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:1277
  ///
  /// In en, this message translates to:
  /// **'{keptCount} kept • {removeCount} will be removed'**
  String keptWillBeRemoved(Object keptCount, Object removeCount);

  /// lib/widgets/uac2/uac2_player_status.dart:186
  ///
  /// In en, this message translates to:
  /// **'{arg1}kHz'**
  String khz(Object arg1);

  /// lib/features/player/widgets/bit_perfect_indicator.dart:1143
  ///
  /// In en, this message translates to:
  /// **'{arg1} kHz'**
  String khz2(Object arg1);

  /// lib/widgets/uac2/uac2_player_status.dart:77
  ///
  /// In en, this message translates to:
  /// **'{arg1}kHz/{arg2}bit'**
  String khzBit(Object arg1, Object arg2);

  /// lib/widgets/uac2/uac2_status_indicator.dart:51
  ///
  /// In en, this message translates to:
  /// **'{arg1}kHz/{arg2}bit'**
  String khzBit2(Object arg1, Object arg2);

  /// lib/features/settings/screens/uac2_preferences_screen.dart:274
  ///
  /// In en, this message translates to:
  /// **'{arg1}kHz / {arg2}bit / {arg3}ch'**
  String khzBitCh(Object arg1, Object arg2, Object arg3);

  /// lib/features/settings/screens/network_server_edit_screen.dart:434
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get label;

  /// lib/features/songs/widgets/song_actions_bottom_sheet.dart:699
  ///
  /// In en, this message translates to:
  /// **'Label / Organization'**
  String get labelOrganization;

  /// Settings entry label and the title of the language picker.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Helper text under the language setting.
  ///
  /// In en, this message translates to:
  /// **'Choose the language used across the app.'**
  String get languageSectionDescription;

  /// Language option that follows the device locale.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemDefault;

  /// lib/features/settings/widgets/lastfm_settings_tile.dart:730
  ///
  /// In en, this message translates to:
  /// **'Last.fm'**
  String get lastFm;

  /// lib/features/settings/widgets/lastfm_settings_tile.dart:347
  ///
  /// In en, this message translates to:
  /// **'Last.fm Configuration'**
  String get lastFmConfiguration;

  /// lib/features/settings/widgets/lastfm_settings_tile.dart:829
  ///
  /// In en, this message translates to:
  /// **'Last.fm Connected'**
  String get lastFmConnected;

  /// lib/features/settings/widgets/lastfm_settings_tile.dart:97
  ///
  /// In en, this message translates to:
  /// **'Last.fm connected!'**
  String get lastFmConnected2;

  /// lib/features/settings/screens/settings_screen.dart:211
  ///
  /// In en, this message translates to:
  /// **'Last.fm & ListenBrainz scrobbling'**
  String get lastFmListenbrainzScrobbling;

  /// lib/features/settings/screens/privacy_policy_screen.dart:59
  ///
  /// In en, this message translates to:
  /// **'Last.fm Scrobbling'**
  String get lastFmScrobbling;

  /// lib/features/settings/screens/privacy_policy_screen.dart:98
  ///
  /// In en, this message translates to:
  /// **'Last Updated'**
  String get lastUpdated;

  /// lib/data/repositories/recently_played_repository.dart:291
  ///
  /// In en, this message translates to:
  /// **'Last Week'**
  String get lastWeek;

  /// lib/models/song.dart:344
  ///
  /// In en, this message translates to:
  /// **'Late Night Sessions'**
  String get lateNightSessions;

  /// lib/features/settings/screens/app_info_settings_screen.dart:250
  ///
  /// In en, this message translates to:
  /// **'Latest Update'**
  String get latestUpdate;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:98
  ///
  /// In en, this message translates to:
  /// **'Layout Mode'**
  String get layoutMode;

  /// lib/features/settings/screens/settings_screen.dart:126
  ///
  /// In en, this message translates to:
  /// **'Layout mode, sizing, and quick actions'**
  String get layoutModeSizingAndQuickActions;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:497
  ///
  /// In en, this message translates to:
  /// **'LDAC 330 kbps'**
  String get ldac330Kbps;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:498
  ///
  /// In en, this message translates to:
  /// **'LDAC 660 kbps'**
  String get ldac660Kbps;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:499
  ///
  /// In en, this message translates to:
  /// **'LDAC 990 kbps'**
  String get ldac990Kbps;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:496
  ///
  /// In en, this message translates to:
  /// **'LDAC Adaptive'**
  String get ldacAdaptive;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:380
  ///
  /// In en, this message translates to:
  /// **'LDAC bits per sample'**
  String get ldacBitsPerSample;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1724
  ///
  /// In en, this message translates to:
  /// **'LE-LSB — little-endian subslot, LSB first'**
  String get leLsbLittleEndianSubslotLsb;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1720
  ///
  /// In en, this message translates to:
  /// **'LE-MSB — little-endian subslot, MSB first'**
  String get leMsbLittleEndianSubslotMsb;

  /// lib/features/settings/screens/network_server_edit_screen.dart:460
  ///
  /// In en, this message translates to:
  /// **'Leave empty to keep the current credentials'**
  String get leaveEmptyToKeepTheCurrent;

  /// lib/features/settings/screens/lyrics_settings_screen.dart:56
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get left;

  /// lib/features/player/widgets/player_layout_sheet.dart:349
  ///
  /// In en, this message translates to:
  /// **'Left (bottom)'**
  String get leftBottom;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:410
  ///
  /// In en, this message translates to:
  /// **'Left (Bottom) Button'**
  String get leftBottomButton;

  /// lib/features/player/widgets/player_layout_sheet.dart:337
  ///
  /// In en, this message translates to:
  /// **'Left (top)'**
  String get leftTop;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:385
  ///
  /// In en, this message translates to:
  /// **'Left (Top) Button'**
  String get leftTopButton;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1838
  ///
  /// In en, this message translates to:
  /// **'Length:'**
  String get length;

  /// lib/features/settings/screens/audio_settings_screen.dart:331
  ///
  /// In en, this message translates to:
  /// **'Length of the overlap'**
  String get lengthOfTheOverlap;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1799
  ///
  /// In en, this message translates to:
  /// **'Length {arg1}s'**
  String lengthS(Object arg1);

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:485
  ///
  /// In en, this message translates to:
  /// **'Let Android choose the best codec'**
  String get letAndroidChooseTheBestCodec;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:312
  ///
  /// In en, this message translates to:
  /// **'Let Android choose the output device'**
  String get letAndroidChooseTheOutputDevice;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:344
  ///
  /// In en, this message translates to:
  /// **'Let Android negotiate the codec automatically'**
  String get letAndroidNegotiateTheCodecAutomatically;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:662
  ///
  /// In en, this message translates to:
  /// **'Let Oboe pick the best API. AAudio first, then OpenSL ES fallback.'**
  String get letOboePickTheBestApi;

  /// lib/providers/tutorial_provider.dart:8
  ///
  /// In en, this message translates to:
  /// **'Let\'s take a quick tour of your new music player.'**
  String get letSTakeAQuickTour;

  /// lib/features/settings/screens/interface_settings_screen.dart:212
  ///
  /// In en, this message translates to:
  /// **'Let the system decide — best battery life'**
  String get letTheSystemDecideBestBattery;

  /// lib/features/settings/screens/library_settings_screen.dart:2057
  ///
  /// In en, this message translates to:
  /// **'Lets Flick scan your entire library directly, including DSD/DSF/WavPack files some devices hide from the system media index'**
  String get letsFlickScanYourEntireLibrary;

  /// lib/features/settings/screens/audio_settings_screen.dart:511
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get level;

  /// lib/features/settings/screens/library_settings_screen.dart:443
  ///
  /// In en, this message translates to:
  /// **'Library emptied'**
  String get libraryEmptied;

  /// lib/features/settings/screens/interface_settings_screen.dart:149
  ///
  /// In en, this message translates to:
  /// **'Library Glance Card'**
  String get libraryGlanceCard;

  /// lib/features/menu/screens/menu_screen.dart:1051
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryLabel;

  /// lib/features/settings/screens/app_info_settings_screen.dart:659
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get licenses;

  /// lib/features/settings/screens/widget_settings_screen.dart:166
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// lib/features/favorites/screens/favorites_screen.dart:308
  ///
  /// In en, this message translates to:
  /// **'{arg1} liked songs'**
  String likedSongs(Object arg1);

  /// lib/features/settings/screens/equalizer_screen.dart:3016
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get limit;

  /// lib/features/settings/screens/audio_settings_screen.dart:230
  ///
  /// In en, this message translates to:
  /// **'Limit positive gain so the level never exceeds full scale'**
  String get limitPositiveGainSoTheLevel;

  /// lib/features/settings/screens/equalizer_screen.dart:3391
  ///
  /// In en, this message translates to:
  /// **'Limiter'**
  String get limiter;

  /// lib/features/settings/screens/equalizer_screen.dart:3269
  ///
  /// In en, this message translates to:
  /// **'Limiter off'**
  String get limiterOff;

  /// lib/features/settings/screens/equalizer_screen.dart:3269
  ///
  /// In en, this message translates to:
  /// **'Limiter on'**
  String get limiterOn;

  /// lib/models/progress_bar_style.dart:18
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get line;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1290
  ///
  /// In en, this message translates to:
  /// **'Line {arg1} of {arg2}'**
  String lineOf(Object arg1, Object arg2);

  /// lib/features/player/screens/lyrics_sync_screen.dart:1366
  ///
  /// In en, this message translates to:
  /// **'Line {arg1} of {arg2}  ·  {captured}/{segmentCount} words'**
  String lineOfWords(
    Object arg1,
    Object arg2,
    Object captured,
    Object segmentCount,
  );

  /// lib/features/player/widgets/bit_perfect_indicator.dart:919
  ///
  /// In en, this message translates to:
  /// **'Linear'**
  String get linear;

  /// lib/features/player/screens/lyrics_sync_screen.dart:865
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get lines;

  /// lib/features/player/widgets/online_lyrics_search_sheet.dart:952
  ///
  /// In en, this message translates to:
  /// **'{arg1} lines'**
  String lines2(Object arg1);

  /// lib/features/settings/screens/logs_screen.dart:170
  ///
  /// In en, this message translates to:
  /// **'Link ready'**
  String get linkReady;

  /// lib/features/player/widgets/inline_lyrics_panel.dart:140
  ///
  /// In en, this message translates to:
  /// **'Linked \"{arg1}\" to this song.'**
  String linkedToThisSong(Object arg1);

  /// lib/models/song_view_mode.dart:19
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get list;

  /// lib/features/settings/screens/casting_settings_screen.dart:258
  ///
  /// In en, this message translates to:
  /// **'List available local audio output devices'**
  String get listAvailableLocalAudioOutputDevices;

  /// lib/features/settings/widgets/listenbrainz_settings_tile.dart:426
  ///
  /// In en, this message translates to:
  /// **'ListenBrainz'**
  String get listenbrainz;

  /// lib/features/settings/widgets/listenbrainz_settings_tile.dart:259
  ///
  /// In en, this message translates to:
  /// **'ListenBrainz Connected'**
  String get listenbrainzConnected;

  /// lib/features/settings/widgets/listenbrainz_settings_tile.dart:599
  ///
  /// In en, this message translates to:
  /// **'ListenBrainz connected!'**
  String get listenbrainzConnected2;

  /// lib/features/player/widgets/share/share_bottom_sheet.dart:134
  ///
  /// In en, this message translates to:
  /// **'Listening to {arg1} by {arg2} on Flick'**
  String listeningToByOnFlick(Object arg1, Object arg2);

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1847
  ///
  /// In en, this message translates to:
  /// **'Little-endian subslot, LSB-first bits'**
  String get littleEndianSubslotLsbFirstBits;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1837
  ///
  /// In en, this message translates to:
  /// **'Little-endian subslot, MSB-first bits'**
  String get littleEndianSubslotMsbFirstBits;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:669
  ///
  /// In en, this message translates to:
  /// **'Live Preview'**
  String get livePreview;

  /// lib/features/settings/screens/equalizer_screen.dart:745
  ///
  /// In en, this message translates to:
  /// **'Load a JSON or TXT preset'**
  String get loadAJsonOrTxtPreset;

  /// lib/features/settings/screens/equalizer_screen.dart:3749
  ///
  /// In en, this message translates to:
  /// **'Load an impulse response for room reverb, crossfeed, cabinet, or correction.'**
  String get loadAnImpulseResponseForRoom;

  /// lib/features/settings/screens/equalizer_screen.dart:3787
  ///
  /// In en, this message translates to:
  /// **'Load IR'**
  String get loadIr;

  /// lib/features/settings/screens/equalizer_screen.dart:3717
  ///
  /// In en, this message translates to:
  /// **'Loaded IR: {displayName}'**
  String loadedIr(Object displayName);

  /// lib/features/settings/screens/library_settings_screen.dart:629
  ///
  /// In en, this message translates to:
  /// **'Loading artwork'**
  String get loadingArtwork;

  /// lib/features/settings/screens/library_settings_screen.dart:961
  ///
  /// In en, this message translates to:
  /// **'Loading artwork…'**
  String get loadingArtwork2;

  /// lib/features/settings/screens/app_info_settings_screen.dart:276
  ///
  /// In en, this message translates to:
  /// **'Loading patch notes...'**
  String get loadingPatchNotes;

  /// lib/features/settings/widgets/lastfm_settings_tile.dart:737
  ///
  /// In en, this message translates to:
  /// **'Loading session...'**
  String get loadingSession;

  /// lib/features/settings/screens/privacy_policy_screen.dart:39
  ///
  /// In en, this message translates to:
  /// **'Local Data'**
  String get localData;

  /// lib/features/milestone/screens/milestones_screen.dart:588
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get locked;

  /// lib/features/settings/screens/equalizer_screen.dart:2170
  ///
  /// In en, this message translates to:
  /// **'Log-frequency control'**
  String get logFrequencyControl;

  /// lib/features/settings/screens/logs_screen.dart:277
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// lib/features/settings/screens/logs_screen.dart:91
  ///
  /// In en, this message translates to:
  /// **'Logs copied'**
  String get logsCopied;

  /// lib/features/settings/screens/interface_settings_screen.dart:306
  ///
  /// In en, this message translates to:
  /// **'Long Press'**
  String get longPress;

  /// lib/features/settings/widgets/mini_player_customization.dart:244
  ///
  /// In en, this message translates to:
  /// **'Long Song Titles'**
  String get longSongTitles;

  /// lib/features/songs/widgets/album_art_picker_bottom_sheet.dart:471
  ///
  /// In en, this message translates to:
  /// **'Looking for cover art from MusicBrainz and Cover Art Archive.'**
  String get lookingForCoverArtFromMusicbrainz;

  /// lib/features/settings/screens/app_info_settings_screen.dart:136
  ///
  /// In en, this message translates to:
  /// **'Looking for the latest Flick release right now'**
  String get lookingForTheLatestFlickRelease;

  /// lib/features/settings/screens/app_info_settings_screen.dart:135
  ///
  /// In en, this message translates to:
  /// **'Looking for the latest Play Store update right now'**
  String get lookingForTheLatestPlayStore;

  /// lib/widgets/common/detail_header.dart:157
  ///
  /// In en, this message translates to:
  /// **' Lossless'**
  String get lossless;

  /// lib/widgets/alac_conversion_indicator.dart:158
  ///
  /// In en, this message translates to:
  /// **'Lossless quality preserved during conversion'**
  String get losslessQualityPreservedDuringConversion;

  /// lib/features/settings/screens/orbit_settings_screen.dart:142
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get low;

  /// lib/features/settings/screens/visualizer_settings_screen.dart:157
  ///
  /// In en, this message translates to:
  /// **'Low and high frequencies, scooped mids'**
  String get lowAndHighFrequenciesScoopedMids;

  /// lib/features/settings/screens/visualizer_settings_screen.dart:133
  ///
  /// In en, this message translates to:
  /// **'Low frequencies only'**
  String get lowFrequenciesOnly;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:488
  ///
  /// In en, this message translates to:
  /// **'Low latency, good quality'**
  String get lowLatencyGoodQuality;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:432
  ///
  /// In en, this message translates to:
  /// **'Low-latency Mode'**
  String get lowLatencyMode;

  /// lib/providers/equalizer_provider.dart:33
  ///
  /// In en, this message translates to:
  /// **'Low Pass'**
  String get lowPass;

  /// lib/providers/equalizer_provider.dart:29
  ///
  /// In en, this message translates to:
  /// **'Low Shelf'**
  String get lowShelf;

  /// lib/features/player/widgets/online_lyrics_search_sheet.dart:381
  ///
  /// In en, this message translates to:
  /// **'LRCLib'**
  String get lrclib;

  /// lib/features/player/widgets/share/share_template.dart:5
  ///
  /// In en, this message translates to:
  /// **'Lyric'**
  String get lyric;

  /// lib/features/player/widgets/song_actions_sheet.dart:295
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get lyrics;

  /// lib/features/player/widgets/online_lyrics_search_sheet.dart:1012
  ///
  /// In en, this message translates to:
  /// **'Lyrics Preview'**
  String get lyricsPreview;

  /// lib/features/player/widgets/inline_lyrics_panel.dart:162
  ///
  /// In en, this message translates to:
  /// **'Lyrics saved from LRCLib.'**
  String get lyricsSavedFromLrclib;

  /// lib/features/settings/screens/settings_screen.dart:172
  ///
  /// In en, this message translates to:
  /// **'Lyrics saving behavior'**
  String get lyricsSavingBehavior;

  /// lib/features/player/screens/lyrics_sync_screen.dart:647
  ///
  /// In en, this message translates to:
  /// **'Lyrics Sync Help'**
  String get lyricsSyncHelp;

  /// lib/features/player/screens/lyrics_sync_screen.dart:747
  ///
  /// In en, this message translates to:
  /// **'Lyrics Sync Studio'**
  String get lyricsSyncStudio;

  /// lib/features/player/screens/lyrics_sync_screen.dart:615
  ///
  /// In en, this message translates to:
  /// **'Lyrics Text'**
  String get lyricsText;

  /// lib/features/player/widgets/sleep_timer_bottom_sheet.dart:133
  ///
  /// In en, this message translates to:
  /// **'{arg1}m'**
  String m(Object arg1);

  /// lib/features/player/widgets/sleep_timer_bottom_sheet.dart:162
  ///
  /// In en, this message translates to:
  /// **'{arg1}m'**
  String m2(Object arg1);

  /// lib/features/recently_added/screens/recently_added_screen.dart:492
  ///
  /// In en, this message translates to:
  /// **'{arg1}m ago'**
  String mAgo(Object arg1);

  /// lib/features/menu/screens/menu_screen.dart:844
  ///
  /// In en, this message translates to:
  /// **'Made For You'**
  String get madeForYou;

  /// lib/features/settings/screens/equalizer_screen.dart:3372
  ///
  /// In en, this message translates to:
  /// **'Makeup'**
  String get makeup;

  /// lib/features/settings/screens/uac2_settings_screen.dart:468
  ///
  /// In en, this message translates to:
  /// **'Manufacturer'**
  String get manufacturer;

  /// lib/features/milestone/screens/milestones_screen.dart:504
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get mar;

  /// lib/features/settings/screens/equalizer_screen.dart:3273
  ///
  /// In en, this message translates to:
  /// **'Master bypassed'**
  String get masterBypassed;

  /// lib/features/settings/screens/lyrics_settings_screen.dart:25
  ///
  /// In en, this message translates to:
  /// **'Match Audio Filename'**
  String get matchAudioFilename;

  /// lib/features/albums/widgets/identify_album_sheet.dart:225
  ///
  /// In en, this message translates to:
  /// **'Match {count, plural, =1{{count} file} other{{count} files}} by artist, album and track length'**
  String matchByArtistAlbumAndTrack(int count);

  /// lib/features/settings/screens/equalizer_screen.dart:759
  ///
  /// In en, this message translates to:
  /// **'Match EQ to your headphone model'**
  String get matchEqToYourHeadphoneModel;

  /// lib/features/settings/widgets/mini_player_customization.dart:82
  ///
  /// In en, this message translates to:
  /// **'Match navigation'**
  String get matchNavigation;

  /// lib/features/albums/widgets/identify_album_sheet.dart:354
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get matches;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:1012
  ///
  /// In en, this message translates to:
  /// **'Max {arg1} B'**
  String maxB(Object arg1);

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:506
  ///
  /// In en, this message translates to:
  /// **'Maximum audio quality'**
  String get maximumAudioQuality;

  /// lib/features/settings/screens/interface_settings_screen.dart:236
  ///
  /// In en, this message translates to:
  /// **'Maximum smoothness — uses more battery'**
  String get maximumSmoothnessUsesMoreBattery;

  /// lib/features/milestone/screens/milestones_screen.dart:506
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get may;

  /// lib/features/settings/screens/privacy_policy_screen.dart:108
  ///
  /// In en, this message translates to:
  /// **'May 4, 2026'**
  String get may42026;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:52
  ///
  /// In en, this message translates to:
  /// **'May stop in the background on some devices'**
  String get mayStopInTheBackgroundOn;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:24
  ///
  /// In en, this message translates to:
  /// **'{arg1} MB'**
  String mb(Object arg1);

  /// lib/features/settings/screens/settings_screen.dart:76
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get media;

  /// lib/features/settings/screens/orbit_settings_screen.dart:150
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get medium;

  /// lib/models/nav_bar_config.dart:5
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// lib/features/settings/screens/integrations_settings_screen.dart:23
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get metadata;

  /// lib/models/song.dart:335
  ///
  /// In en, this message translates to:
  /// **'Metropolitan'**
  String get metropolitan;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:1141
  ///
  /// In en, this message translates to:
  /// **'{arg1} MHz'**
  String mhz(Object arg1);

  /// lib/features/settings/screens/equalizer_screen.dart:1680
  ///
  /// In en, this message translates to:
  /// **'Mid'**
  String get mid;

  /// lib/features/settings/screens/visualizer_settings_screen.dart:141
  ///
  /// In en, this message translates to:
  /// **'Mid frequencies only'**
  String get midFrequenciesOnly;

  /// lib/features/settings/screens/widget_settings_screen.dart:866
  ///
  /// In en, this message translates to:
  /// **'Midnight City Dreams'**
  String get midnightCityDreams;

  /// lib/features/player/widgets/player_layout_sheet.dart:914
  ///
  /// In en, this message translates to:
  /// **'Midnight Signal'**
  String get midnightSignal;

  /// lib/features/milestone/screens/milestones_screen.dart:122
  ///
  /// In en, this message translates to:
  /// **'Milestones'**
  String get milestones;

  /// lib/features/player/widgets/sleep_timer_bottom_sheet.dart:174
  ///
  /// In en, this message translates to:
  /// **'{arg1} min'**
  String min(Object arg1);

  /// lib/providers/tutorial_provider.dart:38
  ///
  /// In en, this message translates to:
  /// **'Mini Player'**
  String get miniPlayer;

  /// lib/features/settings/widgets/mini_player_customization.dart:193
  ///
  /// In en, this message translates to:
  /// **'Mini Player Appearance'**
  String get miniPlayerAppearance;

  /// lib/features/settings/widgets/mini_player_customization.dart:292
  ///
  /// In en, this message translates to:
  /// **'Mini player defaults restored'**
  String get miniPlayerDefaultsRestored;

  /// lib/features/settings/widgets/mini_player_customization.dart:125
  ///
  /// In en, this message translates to:
  /// **'Mini Player Height'**
  String get miniPlayerHeight;

  /// lib/features/settings/widgets/mini_player_customization.dart:64
  ///
  /// In en, this message translates to:
  /// **'Mini Player Layout'**
  String get miniPlayerLayout;

  /// lib/features/player/widgets/share/share_template.dart:13
  ///
  /// In en, this message translates to:
  /// **'Minimal'**
  String get minimal;

  /// lib/features/settings/screens/library_settings_screen.dart:1058
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get minimize;

  /// lib/features/settings/screens/network_server_edit_screen.dart:82
  ///
  /// In en, this message translates to:
  /// **'MinimServer · Serviio · Kodi'**
  String get minimserverServiioKodi;

  /// lib/features/player/widgets/player_layout_sheet.dart:1187
  ///
  /// In en, this message translates to:
  /// **'Mirror Test'**
  String get mirrorTest;

  /// lib/features/settings/screens/visualizer_settings_screen.dart:103
  ///
  /// In en, this message translates to:
  /// **'Mirrored'**
  String get mirrored;

  /// lib/features/settings/screens/app_info_settings_screen.dart:516
  ///
  /// In en, this message translates to:
  /// **'\nMIT License\n\nCopyright (c) 2026 Flick Player Contributors\n\nPermission is hereby granted, free of charge, to any person obtaining a copy\nof this software and associated documentation files (the \"Software\"), to deal\nin the Software without restriction, including without limitation the rights\nto use, copy, modify, merge, publish, distribute, sublicense, and/or sell\ncopies of the Software, and to permit persons to whom the Software is\nfurnished to do so, subject to the following conditions:\n\nThe above copyright notice and this permission notice shall be included in all\ncopies or substantial portions of the Software.\n\nTHE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\nIMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,\nFITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE\nAUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER\nLIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,\nOUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE\nSOFTWARE.\n'**
  String get mitLicenseCopyrightC2026Flick;

  /// lib/features/settings/screens/equalizer_screen.dart:3641
  ///
  /// In en, this message translates to:
  /// **'Mix'**
  String get mix;

  /// lib/features/settings/screens/equalizer_screen.dart:3523
  ///
  /// In en, this message translates to:
  /// **'Mix {arg1}'**
  String mix2(Object arg1);

  /// lib/features/player/widgets/bit_perfect_indicator.dart:659
  ///
  /// In en, this message translates to:
  /// **'Mixer'**
  String get mixer;

  /// lib/features/settings/screens/uac2_settings_screen.dart:688
  ///
  /// In en, this message translates to:
  /// **'Mixer Management'**
  String get mixerManagement;

  /// lib/features/settings/screens/library_settings_screen.dart:1014
  ///
  /// In en, this message translates to:
  /// **'Mod'**
  String get mod;

  /// lib/models/album_color_mode.dart:24
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get moderate;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:621
  ///
  /// In en, this message translates to:
  /// **'Mono'**
  String get mono;

  /// lib/data/repositories/recently_played_repository.dart:16
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// lib/features/settings/screens/logs_screen.dart:322
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// lib/features/songs/screens/songs_screen.dart:1556
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get moreActions;

  /// lib/features/artists/screens/artists_screen.dart:762
  ///
  /// In en, this message translates to:
  /// **'More artists'**
  String get moreArtists;

  /// lib/features/settings/screens/ui_customization_settings_screen.dart:154
  ///
  /// In en, this message translates to:
  /// **'More Artists'**
  String get moreArtists2;

  /// lib/features/albums/screens/album_detail_screen.dart:549
  ///
  /// In en, this message translates to:
  /// **'More from {arg1}'**
  String moreFrom(Object arg1);

  /// lib/features/artists/screens/artists_screen.dart:752
  ///
  /// In en, this message translates to:
  /// **'More from artist'**
  String get moreFromArtist;

  /// lib/features/settings/screens/ui_customization_settings_screen.dart:142
  ///
  /// In en, this message translates to:
  /// **'More from Artist'**
  String get moreFromArtist2;

  /// lib/features/settings/screens/privacy_policy_screen.dart:69
  ///
  /// In en, this message translates to:
  /// **'Moss Ecosystem'**
  String get mossEcosystem;

  /// lib/features/settings/screens/network_server_edit_screen.dart:85
  ///
  /// In en, this message translates to:
  /// **'Most DLNA servers need no password'**
  String get mostDlnaServersNeedNoPassword;

  /// lib/features/artists/screens/artist_detail_screen.dart:701
  ///
  /// In en, this message translates to:
  /// **'Most Played'**
  String get mostPlayed;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:64
  ///
  /// In en, this message translates to:
  /// **'Motion Art in Bit-Perfect'**
  String get motionArtInBitPerfect;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:67
  ///
  /// In en, this message translates to:
  /// **'Motion art is replaced while bit-perfect output is active'**
  String get motionArtIsReplacedWhileBit;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:66
  ///
  /// In en, this message translates to:
  /// **'Motion art plays during bit-perfect audio (may interrupt playback on some DAPs)'**
  String get motionArtPlaysDuringBitPerfect;

  /// lib/features/player/widgets/song_actions_sheet.dart:255
  ///
  /// In en, this message translates to:
  /// **'Motion art refreshed'**
  String get motionArtRefreshed;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1987
  ///
  /// In en, this message translates to:
  /// **'Move every stamped lyric forward or backward together.'**
  String get moveEveryStampedLyricForwardOr;

  /// lib/features/settings/screens/visualizer_settings_screen.dart:164
  ///
  /// In en, this message translates to:
  /// **'Movement'**
  String get movement;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:1025
  ///
  /// In en, this message translates to:
  /// **'{arg1} ms'**
  String ms(Object arg1);

  /// lib/features/settings/screens/equalizer_screen.dart:3346
  ///
  /// In en, this message translates to:
  /// **'{arg1} ms'**
  String ms2(Object arg1);

  /// lib/features/settings/screens/equalizer_screen.dart:3360
  ///
  /// In en, this message translates to:
  /// **'{arg1} ms'**
  String ms3(Object arg1);

  /// lib/features/settings/screens/equalizer_screen.dart:3434
  ///
  /// In en, this message translates to:
  /// **'{arg1} ms'**
  String ms4(Object arg1);

  /// lib/features/settings/screens/equalizer_screen.dart:3616
  ///
  /// In en, this message translates to:
  /// **'{arg1} ms'**
  String ms5(Object arg1);

  /// lib/features/settings/screens/equalizer_screen.dart:2174
  ///
  /// In en, this message translates to:
  /// **'Multi-filter bands'**
  String get multiFilterBands;

  /// lib/features/folders/screens/folders_screen.dart:327
  ///
  /// In en, this message translates to:
  /// **'{arg1} music folders'**
  String musicFolders(Object arg1);

  /// lib/widgets/uac2/iso_volume_popup.dart:260
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// lib/features/settings/screens/network_server_edit_screen.dart:435
  ///
  /// In en, this message translates to:
  /// **'My {arg1}'**
  String my(Object arg1);

  /// lib/widgets/uac2/iso_volume_popup.dart:292
  ///
  /// In en, this message translates to:
  /// **'{arg1}%\n{arg2} dB'**
  String nDb(Object arg1, Object arg2);

  /// lib/features/folders/screens/folders_screen.dart:2421
  ///
  /// In en, this message translates to:
  /// **'Name (A-Z)'**
  String get nameAZ;

  /// lib/features/settings/screens/equalizer_screen.dart:3493
  ///
  /// In en, this message translates to:
  /// **'{amount}% narrow'**
  String narrow(Object amount);

  /// lib/features/player/widgets/bit_perfect_indicator.dart:712
  ///
  /// In en, this message translates to:
  /// **'Native DSD'**
  String get nativeDsd;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1690
  ///
  /// In en, this message translates to:
  /// **'Native DSD (Experimental)'**
  String get nativeDsdExperimental;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1643
  ///
  /// In en, this message translates to:
  /// **'Native DSD — Experimental (may be buggy)'**
  String get nativeDsdExperimentalMayBeBuggy;

  /// lib/features/settings/screens/equalizer_screen.dart:661
  ///
  /// In en, this message translates to:
  /// **'Native Flick preset format'**
  String get nativeFlickPresetFormat;

  /// lib/features/settings/screens/visualizer_settings_screen.dart:178
  ///
  /// In en, this message translates to:
  /// **'Natural equalizer feel — responsive yet smooth'**
  String get naturalEqualizerFeelResponsiveYetSmooth;

  /// lib/models/song.dart:317
  ///
  /// In en, this message translates to:
  /// **'Nature Ambient'**
  String get natureAmbient;

  /// lib/features/settings/screens/network_server_edit_screen.dart:58
  ///
  /// In en, this message translates to:
  /// **'Navidrome · Airsonic · Gonic'**
  String get navidromeAirsonicGonic;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:216
  ///
  /// In en, this message translates to:
  /// **'Navigation Appearance'**
  String get navigationAppearance;

  /// lib/providers/tutorial_provider.dart:11
  ///
  /// In en, this message translates to:
  /// **'Navigation Bar'**
  String get navigationBar;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:298
  ///
  /// In en, this message translates to:
  /// **'Navigation defaults restored'**
  String get navigationDefaultsRestored;

  /// lib/features/settings/screens/missing_metadata_screen.dart:87
  ///
  /// In en, this message translates to:
  /// **'Needs metadata'**
  String get needsMetadata;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:519
  ///
  /// In en, this message translates to:
  /// **'Negotiated: {arg1}'**
  String negotiated(Object arg1);

  /// lib/models/song.dart:357
  ///
  /// In en, this message translates to:
  /// **'Neon Nights'**
  String get neonNights;

  /// lib/features/settings/screens/widget_settings_screen.dart:878
  ///
  /// In en, this message translates to:
  /// **'Neon Skyline'**
  String get neonSkyline;

  /// lib/models/playback_context.dart:16
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get network;

  /// lib/features/settings/screens/network_sources_screen.dart:136
  ///
  /// In en, this message translates to:
  /// **'Network Sources'**
  String get networkSources;

  /// lib/features/settings/screens/equalizer_screen.dart:3492
  ///
  /// In en, this message translates to:
  /// **'{amount}% neutral'**
  String neutral(Object amount);

  /// lib/features/settings/screens/network_sources_screen.dart:318
  ///
  /// In en, this message translates to:
  /// **'Never synced'**
  String get neverSynced;

  /// lib/features/settings/screens/library_settings_screen.dart:1009
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newLabel;

  /// lib/features/onboarding/screens/onboarding_screen.dart:269
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// lib/widgets/common/mini_player_bar.dart:266
  ///
  /// In en, this message translates to:
  /// **'Next song'**
  String get nextSong;

  /// lib/features/settings/widgets/mini_player_customization.dart:184
  ///
  /// In en, this message translates to:
  /// **'Next Song'**
  String get nextSong2;

  /// lib/features/settings/screens/network_server_edit_screen.dart:74
  ///
  /// In en, this message translates to:
  /// **'Nextcloud · ownCloud · SabreDAV'**
  String get nextcloudOwncloudSabredav;

  /// lib/features/settings/screens/logs_screen.dart:220
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// lib/features/settings/screens/settings_screen.dart:254
  ///
  /// In en, this message translates to:
  /// **'No achievements yet — keep listening'**
  String get noAchievementsYetKeepListening;

  /// lib/features/albums/screens/albums_screen.dart:442
  ///
  /// In en, this message translates to:
  /// **'No Albums Found'**
  String get noAlbumsFound;

  /// lib/features/albums/widgets/identify_album_sheet.dart:339
  ///
  /// In en, this message translates to:
  /// **'No Apple Music release found. Try editing the artist or album name and searching again.'**
  String get noAppleMusicReleaseFoundTry;

  /// lib/features/artists/screens/artists_screen.dart:477
  ///
  /// In en, this message translates to:
  /// **'No Artists Found'**
  String get noArtistsFound;

  /// lib/features/artists/screens/artists_screen.dart:533
  ///
  /// In en, this message translates to:
  /// **'No artists match \"{_searchQuery}\"'**
  String noArtistsMatch(Object _searchQuery);

  /// lib/features/settings/screens/library_settings_screen.dart:1427
  ///
  /// In en, this message translates to:
  /// **'No audio was found. If this folder contains music, a .nomedia file may be hiding it, or Android hasn\'t indexed it yet. Try enabling deep scan, or remove any .nomedia file and re-scan.'**
  String get noAudioWasFoundIfThis;

  /// lib/features/settings/screens/casting_settings_screen.dart:204
  ///
  /// In en, this message translates to:
  /// **'No casting devices found. Make sure your phone and the receiver are on the same network.'**
  String get noCastingDevicesFoundMakeSure;

  /// lib/features/search/screens/search_screen.dart:315
  ///
  /// In en, this message translates to:
  /// **'No categories selected'**
  String get noCategoriesSelected;

  /// lib/features/settings/screens/equalizer_screen.dart:788
  ///
  /// In en, this message translates to:
  /// **'No custom presets yet.'**
  String get noCustomPresetsYet;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:393
  ///
  /// In en, this message translates to:
  /// **'No duplicates found'**
  String get noDuplicatesFound;

  /// lib/features/favorites/screens/favorites_screen.dart:353
  ///
  /// In en, this message translates to:
  /// **'No Favorites Yet'**
  String get noFavoritesYet;

  /// lib/features/folders/screens/folders_screen.dart:368
  ///
  /// In en, this message translates to:
  /// **'No Folders Added'**
  String get noFoldersAdded;

  /// lib/features/recently_played/screens/recently_played_screen.dart:346
  ///
  /// In en, this message translates to:
  /// **'No History Yet'**
  String get noHistoryYet;

  /// lib/features/settings/widgets/lastfm_settings_tile.dart:80
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Please check your network and try again.'**
  String get noInternetConnectionPleaseCheckYour;

  /// lib/features/settings/screens/logs_screen.dart:441
  ///
  /// In en, this message translates to:
  /// **'No logs yet.'**
  String get noLogsYet;

  /// lib/features/player/widgets/online_lyrics_search_sheet.dart:166
  ///
  /// In en, this message translates to:
  /// **'No lyrics found online for this song.'**
  String get noLyricsFoundOnlineForThis;

  /// lib/features/player/widgets/inline_lyrics_panel.dart:413
  ///
  /// In en, this message translates to:
  /// **'No lyrics yet'**
  String get noLyricsYet;

  /// lib/features/albums/widgets/identify_album_sheet.dart:524
  ///
  /// In en, this message translates to:
  /// **'No match found'**
  String get noMatchFound;

  /// lib/features/settings/screens/logs_screen.dart:441
  ///
  /// In en, this message translates to:
  /// **'No matches.'**
  String get noMatches;

  /// lib/features/songs/screens/songs_screen.dart:1854
  ///
  /// In en, this message translates to:
  /// **'No matches found'**
  String get noMatchesFound;

  /// lib/features/settings/screens/widgets/autoeq_search_sheet.dart:317
  ///
  /// In en, this message translates to:
  /// **'No matches. Try fewer words or search online.'**
  String get noMatchesTryFewerWordsOr;

  /// lib/features/songs/screens/songs_screen.dart:1846
  ///
  /// In en, this message translates to:
  /// **'No Music Yet'**
  String get noMusicYet;

  /// lib/features/recently_added/screens/recently_added_screen.dart:318
  ///
  /// In en, this message translates to:
  /// **'No New Additions Yet'**
  String get noNewAdditionsYet;

  /// lib/features/settings/screens/app_info_settings_screen.dart:95
  ///
  /// In en, this message translates to:
  /// **'No new update found.'**
  String get noNewUpdateFound;

  /// lib/features/songs/widgets/album_art_picker_bottom_sheet.dart:489
  ///
  /// In en, this message translates to:
  /// **'No online artwork found'**
  String get noOnlineArtworkFound;

  /// lib/features/settings/screens/casting_settings_screen.dart:264
  ///
  /// In en, this message translates to:
  /// **'No output devices available.'**
  String get noOutputDevicesAvailable;

  /// lib/features/settings/screens/app_info_settings_screen.dart:251
  ///
  /// In en, this message translates to:
  /// **'No patch notes available yet.'**
  String get noPatchNotesAvailableYet;

  /// lib/features/menu/screens/menu_screen.dart:989
  ///
  /// In en, this message translates to:
  /// **'No playlists yet'**
  String get noPlaylistsYet;

  /// lib/features/player/widgets/add_to_playlist_sheet.dart:79
  ///
  /// In en, this message translates to:
  /// **'No playlists yet.\nCreate one in the Playlists tab.'**
  String get noPlaylistsYetNcreateOneIn;

  /// lib/features/search/screens/search_screen.dart:282
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String noResultsFor(Object query);

  /// lib/features/player/widgets/online_lyrics_search_sheet.dart:196
  ///
  /// In en, this message translates to:
  /// **'No results found for \"{query}\".'**
  String noResultsFoundFor(Object query);

  /// lib/features/player/widgets/bit_perfect_indicator.dart:1063
  ///
  /// In en, this message translates to:
  /// **'No rip data'**
  String get noRipData;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:229
  ///
  /// In en, this message translates to:
  /// **'No scan results yet'**
  String get noScanResultsYet;

  /// lib/features/settings/screens/network_sources_screen.dart:190
  ///
  /// In en, this message translates to:
  /// **'No servers connected'**
  String get noServersConnected;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:701
  ///
  /// In en, this message translates to:
  /// **'No song playing'**
  String get noSongPlaying;

  /// lib/features/folders/screens/folders_screen.dart:1362
  ///
  /// In en, this message translates to:
  /// **'No Songs Found'**
  String get noSongsFound;

  /// lib/features/settings/screens/app_info_settings_screen.dart:165
  ///
  /// In en, this message translates to:
  /// **'No Update Available'**
  String get noUpdateAvailable;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:965
  ///
  /// In en, this message translates to:
  /// **'No URB data'**
  String get noUrbData;

  /// lib/features/settings/screens/uac2_settings_screen.dart:289
  ///
  /// In en, this message translates to:
  /// **'No USB audio devices found'**
  String get noUsbAudioDevicesFound;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1698
  ///
  /// In en, this message translates to:
  /// **'No word timing yet. Auto-fill spreads the words evenly as a starting point — or capture them in Word Sync mode.'**
  String get noWordTimingYetAutoFill;

  /// lib/features/settings/screens/equalizer_screen.dart:3769
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// lib/features/settings/screens/audio_settings_screen.dart:198
  ///
  /// In en, this message translates to:
  /// **'Normalize each track to match loudness'**
  String get normalizeEachTrackToMatchLoudness;

  /// lib/widgets/alac_conversion_indicator.dart:112
  ///
  /// In en, this message translates to:
  /// **'Not an ALAC file'**
  String get notAnAlacFile;

  /// lib/features/settings/screens/audio_settings_screen.dart:308
  ///
  /// In en, this message translates to:
  /// **'Not available in bit-perfect mode'**
  String get notAvailableInBitPerfectMode;

  /// lib/features/settings/screens/widgets/autoeq_search_sheet.dart:123
  ///
  /// In en, this message translates to:
  /// **'Not found online. Try a different spelling.'**
  String get notFoundOnlineTryADifferent;

  /// lib/features/settings/screens/library_settings_screen.dart:1888
  ///
  /// In en, this message translates to:
  /// **'Not granted — enable so scans cover DSD/DSF/WavPack files the system index may skip'**
  String get notGrantedEnableSoScansCover;

  /// lib/features/settings/screens/uac2_settings_screen.dart:715
  ///
  /// In en, this message translates to:
  /// **'Not held'**
  String get notHeld;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1620
  ///
  /// In en, this message translates to:
  /// **'Not recommended for normal usage. DSD playback is unstable and may cause audio glitches.'**
  String get notRecommendedForNormalUsageDsd;

  /// lib/features/settings/screens/uac2_settings_screen.dart:705
  ///
  /// In en, this message translates to:
  /// **'Not registered'**
  String get notRegistered;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:275
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1156
  ///
  /// In en, this message translates to:
  /// **'Not stamped yet'**
  String get notStampedYet;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:1103
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get notVerified;

  /// lib/providers/equalizer_provider.dart:39
  ///
  /// In en, this message translates to:
  /// **'Notch'**
  String get notch;

  /// lib/features/settings/screens/equalizer_screen.dart:2642
  ///
  /// In en, this message translates to:
  /// **'Notch Depth'**
  String get notchDepth;

  /// lib/models/album_color_mode.dart:37
  ///
  /// In en, this message translates to:
  /// **'Noticeable tinting from album art.'**
  String get noticeableTintingFromAlbumArt;

  /// lib/features/milestone/screens/milestones_screen.dart:512
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get nov;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1032
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get now;

  /// lib/features/player/screens/full_player_screen.dart:604
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get nowPlaying;

  /// lib/models/song_tile_thumbnail_mode.dart:22
  ///
  /// In en, this message translates to:
  /// **'Number on Art'**
  String get numberOnArt;

  /// lib/features/settings/screens/network_server_edit_screen.dart:101
  ///
  /// In en, this message translates to:
  /// **'OAuth sign-in; no password stored here'**
  String get oauthSignInNoPasswordStored;

  /// lib/models/song.dart:312
  ///
  /// In en, this message translates to:
  /// **'Ocean Waves'**
  String get oceanWaves;

  /// lib/features/milestone/screens/milestones_screen.dart:511
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get oct;

  /// lib/features/settings/screens/audio_settings_screen.dart:189
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// lib/features/settings/screens/library_settings_screen.dart:2197
  ///
  /// In en, this message translates to:
  /// **'Off crops to fill the square; on stretches the artwork edge-to-edge'**
  String get offCropsToFillTheSquare;

  /// lib/features/settings/screens/app_info_settings_screen.dart:158
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// lib/features/settings/screens/equalizer_screen.dart:3911
  ///
  /// In en, this message translates to:
  /// **'On Android, the standard just_audio playback path now applies native counterparts for EQ, dynamics, balance, and spatial FX on supported devices. The Rust engine still delivers the most exact version of these controls, so some Android results are approximate.'**
  String get onAndroidTheStandardJustAudio;

  /// lib/features/songs/widgets/album_art_picker_bottom_sheet.dart:365
  ///
  /// In en, this message translates to:
  /// **'Online Results'**
  String get onlineResults;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:557
  ///
  /// In en, this message translates to:
  /// **'Only library entries are removed — your audio files stay on disk.'**
  String get onlyLibraryEntriesAreRemovedYour;

  /// lib/features/settings/screens/library_settings_screen.dart:702
  ///
  /// In en, this message translates to:
  /// **'Only re-read files that are new or changed.'**
  String get onlyReReadFilesThatAre;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:156
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:351
  ///
  /// In en, this message translates to:
  /// **'Open Bluetooth Codec Settings'**
  String get openBluetoothCodecSettings;

  /// lib/features/settings/screens/app_info_settings_screen.dart:401
  ///
  /// In en, this message translates to:
  /// **'Open Full Notes'**
  String get openFullNotes;

  /// lib/features/albums/screens/album_detail_screen.dart:360
  ///
  /// In en, this message translates to:
  /// **'Open in Apple Music'**
  String get openInAppleMusic;

  /// lib/features/settings/screens/network_server_edit_screen.dart:623
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get openInBrowser;

  /// lib/features/settings/screens/app_info_settings_screen.dart:631
  ///
  /// In en, this message translates to:
  /// **'Open in Play Store'**
  String get openInPlayStore;

  /// lib/features/settings/widgets/listenbrainz_settings_tile.dart:717
  ///
  /// In en, this message translates to:
  /// **'Open listenbrainz.org/settings'**
  String get openListenbrainzOrgSettings;

  /// lib/features/onboarding/widgets/tutorial_overlay.dart:345
  ///
  /// In en, this message translates to:
  /// **'Open Manual'**
  String get openManual;

  /// lib/features/settings/screens/app_info_settings_screen.dart:312
  ///
  /// In en, this message translates to:
  /// **'Open Release Notes'**
  String get openReleaseNotes;

  /// lib/features/settings/screens/app_info_settings_screen.dart:660
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get openSourceLicenses;

  /// lib/features/settings/screens/app_info_settings_screen.dart:144
  ///
  /// In en, this message translates to:
  /// **'Open the Play Store to install the latest Flick build'**
  String get openThePlayStoreToInstall;

  /// lib/features/player/screens/full_player_screen.dart:616
  ///
  /// In en, this message translates to:
  /// **'Opened from Locker'**
  String get openedFromLocker;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:700
  ///
  /// In en, this message translates to:
  /// **'OpenSL ES'**
  String get openslEs;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:639
  ///
  /// In en, this message translates to:
  /// **'OpenSL ES (legacy)'**
  String get openslEsLegacy;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:851
  ///
  /// In en, this message translates to:
  /// **'Or remove all using recommended picks'**
  String get orRemoveAllUsingRecommendedPicks;

  /// lib/models/song_view_mode.dart:17
  ///
  /// In en, this message translates to:
  /// **'Orbital'**
  String get orbital;

  /// lib/features/settings/screens/orbit_settings_screen.dart:205
  ///
  /// In en, this message translates to:
  /// **'Orbital settings reset'**
  String get orbitalSettingsReset;

  /// lib/features/settings/widgets/mini_player_customization.dart:209
  ///
  /// In en, this message translates to:
  /// **'Outline the mini player'**
  String get outlineTheMiniPlayer;

  /// lib/features/settings/screens/casting_settings_screen.dart:281
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get output;

  /// lib/features/settings/screens/casting_settings_screen.dart:120
  ///
  /// In en, this message translates to:
  /// **'Output Device'**
  String get outputDevice;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:408
  ///
  /// In en, this message translates to:
  /// **'Output Mode'**
  String get outputMode;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:601
  ///
  /// In en, this message translates to:
  /// **'Output rate'**
  String get outputRate;

  /// lib/features/settings/screens/audio_settings_screen.dart:321
  ///
  /// In en, this message translates to:
  /// **'Overlap the end of a track with the next'**
  String get overlapTheEndOfATrack;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:299
  ///
  /// In en, this message translates to:
  /// **'Overlay permission is required to show the floating player'**
  String get overlayPermissionIsRequiredToShow;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:110
  ///
  /// In en, this message translates to:
  /// **'Paired'**
  String get paired;

  /// lib/features/settings/screens/equalizer_screen.dart:4169
  ///
  /// In en, this message translates to:
  /// **'Parametric'**
  String get parametric;

  /// lib/features/settings/screens/equalizer_screen.dart:2205
  ///
  /// In en, this message translates to:
  /// **'{arg1} parametric bands with independent frequency, gain, and Q shaping. Tap to interact.'**
  String parametricBandsWithIndependentFrequency(Object arg1);

  /// lib/features/settings/screens/equalizer_screen.dart:2160
  ///
  /// In en, this message translates to:
  /// **'Parametric EQ'**
  String get parametricEq;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:682
  ///
  /// In en, this message translates to:
  /// **'Passthrough'**
  String get passthrough;

  /// lib/features/settings/screens/network_server_edit_screen.dart:456
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// lib/features/player/screens/lyrics_sync_screen.dart:623
  ///
  /// In en, this message translates to:
  /// **'Paste or type the song lyrics here — one line per row'**
  String get pasteOrTypeTheSongLyrics;

  /// lib/features/settings/widgets/listenbrainz_settings_tile.dart:741
  ///
  /// In en, this message translates to:
  /// **'Paste your ListenBrainz token'**
  String get pasteYourListenbrainzToken;

  /// lib/features/settings/screens/app_info_settings_screen.dart:259
  ///
  /// In en, this message translates to:
  /// **'Patch Notes'**
  String get patchNotes;

  /// lib/widgets/common/mini_player_bar.dart:262
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:260
  ///
  /// In en, this message translates to:
  /// **'Pause on Bluetooth Connect'**
  String get pauseOnBluetoothConnect;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:249
  ///
  /// In en, this message translates to:
  /// **'Pause on Disconnect'**
  String get pauseOnDisconnect;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:282
  ///
  /// In en, this message translates to:
  /// **'Pause on USB DAC Attach'**
  String get pauseOnUsbDacAttach;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:293
  ///
  /// In en, this message translates to:
  /// **'Pause on USB DAC Detach'**
  String get pauseOnUsbDacDetach;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:987
  ///
  /// In en, this message translates to:
  /// **'PCM Frames'**
  String get pcmFrames;

  /// lib/providers/equalizer_provider.dart:27
  ///
  /// In en, this message translates to:
  /// **'Peaking'**
  String get peaking;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:230
  ///
  /// In en, this message translates to:
  /// **'Permission'**
  String get permission;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:401
  ///
  /// In en, this message translates to:
  /// **'Phone and headset volume are independent'**
  String get phoneAndHeadsetVolumeAreIndependent;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:400
  ///
  /// In en, this message translates to:
  /// **'Phone and headset volume are linked'**
  String get phoneAndHeadsetVolumeAreLinked;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1390
  ///
  /// In en, this message translates to:
  /// **'Pick a line with lyrics'**
  String get pickALineWithLyrics;

  /// lib/features/player/screens/lyrics_sync_screen.dart:678
  ///
  /// In en, this message translates to:
  /// **'1. Pick a lyric line in Lines, then switch to Tools.\n2. Press play and tap the big \"Tap Word\" button as you hear each word — the first tap also stamps the line.\n3. Tap a word chip to nudge, re-time, or clear it.\n4. Lines with every word stamped save with per-word karaoke timing.'**
  String get pickALyricLineIn;

  /// lib/features/songs/widgets/album_art_picker_bottom_sheet.dart:341
  ///
  /// In en, this message translates to:
  /// **'Pick Image'**
  String get pickImage;

  /// lib/widgets/equalizer/interactive_eq_graph.dart:158
  ///
  /// In en, this message translates to:
  /// **'Pinch apart = narrower (higher Q)\nPinch together = wider (lower Q)'**
  String get pinchApartNarrowerHigherQNpinch;

  /// lib/features/player/widgets/pitch_bottom_sheet.dart:37
  ///
  /// In en, this message translates to:
  /// **'Pitch'**
  String get pitch;

  /// lib/features/player/widgets/pitch_bottom_sheet.dart:95
  ///
  /// In en, this message translates to:
  /// **'{semitones, plural, =1{{semitones} semitone} other{{semitones} semitones}}'**
  String pitchSemitones(int semitones);

  /// lib/features/settings/screens/orbit_settings_screen.dart:143
  ///
  /// In en, this message translates to:
  /// **'Pixelated — lightest on memory'**
  String get pixelatedLightestOnMemory;

  /// lib/features/player/widgets/online_lyrics_search_sheet.dart:581
  ///
  /// In en, this message translates to:
  /// **'Plain'**
  String get plain;

  /// lib/features/player/widgets/online_lyrics_search_sheet.dart:379
  ///
  /// In en, this message translates to:
  /// **'Plain Text'**
  String get plainText;

  /// lib/widgets/common/detail_header.dart:273
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// lib/data/repositories/recently_played_repository.dart:33
  ///
  /// In en, this message translates to:
  /// **'Play a few tracks today to build your daily recap.'**
  String get playAFewTracksTodayTo;

  /// lib/features/settings/screens/queue_settings_screen.dart:75
  ///
  /// In en, this message translates to:
  /// **'Play a random library song when the queue ends'**
  String get playARandomLibrarySongWhen;

  /// lib/features/settings/screens/audio_settings_screen.dart:190
  ///
  /// In en, this message translates to:
  /// **'Play at the recorded level'**
  String get playAtTheRecordedLevel;

  /// lib/models/shuffle_mode.dart:22
  ///
  /// In en, this message translates to:
  /// **'Play categories in random order, tracks in sequence'**
  String get playCategoriesInRandomOrderTracks;

  /// lib/models/shuffle_mode.dart:19
  ///
  /// In en, this message translates to:
  /// **'Play in order'**
  String get playInOrder;

  /// lib/features/settings/screens/privacy_policy_screen.dart:76
  ///
  /// In en, this message translates to:
  /// **'Play Store updates use Google Play In-App Update API (governed by Google\'s privacy policies). Patch notes are fetched from GitHub Releases API without sending personal data.'**
  String get playStoreUpdatesUseGooglePlay;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:28
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get playback;

  /// lib/features/settings/screens/library_settings_screen.dart:336
  ///
  /// In en, this message translates to:
  /// **'Playback Cache Limit'**
  String get playbackCacheLimit;

  /// lib/features/settings/screens/library_settings_screen.dart:328
  ///
  /// In en, this message translates to:
  /// **'Playback cache limit: {arg1}'**
  String playbackCacheLimit2(Object arg1);

  /// lib/features/settings/screens/library_settings_screen.dart:327
  ///
  /// In en, this message translates to:
  /// **'Playback cache unlimited'**
  String get playbackCacheUnlimited;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:263
  ///
  /// In en, this message translates to:
  /// **'Playback continues when a Bluetooth device connects'**
  String get playbackContinuesWhenABluetoothDevice;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:285
  ///
  /// In en, this message translates to:
  /// **'Playback continues when a USB DAC is plugged in'**
  String get playbackContinuesWhenAUsbDac;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:296
  ///
  /// In en, this message translates to:
  /// **'Playback continues when a USB DAC is unplugged'**
  String get playbackContinuesWhenAUsbDac2;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:252
  ///
  /// In en, this message translates to:
  /// **'Playback continues when audio output disconnects'**
  String get playbackContinuesWhenAudioOutput;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:37
  ///
  /// In en, this message translates to:
  /// **'Playback continues when the app is swiped away'**
  String get playbackContinuesWhenTheAppIs;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:24
  ///
  /// In en, this message translates to:
  /// **'Playback & Display'**
  String get playbackDisplay;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:324
  ///
  /// In en, this message translates to:
  /// **'Playback Engine'**
  String get playbackEngine;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1051
  ///
  /// In en, this message translates to:
  /// **'Playback is using Android-managed output and may be resampled.'**
  String get playbackIsUsingAndroidManagedOutput;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1053
  ///
  /// In en, this message translates to:
  /// **'Playback is using the standard Android output path.'**
  String get playbackIsUsingTheStandardAndroid;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1055
  ///
  /// In en, this message translates to:
  /// **'Playback mode will update after the next route or playback refresh.'**
  String get playbackModeWillUpdateAfterThe;

  /// lib/features/settings/screens/uac2_settings_screen.dart:616
  ///
  /// In en, this message translates to:
  /// **'Playback Path'**
  String get playbackPath;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:262
  ///
  /// In en, this message translates to:
  /// **'Playback pauses when a Bluetooth audio device connects'**
  String get playbackPausesWhenABluetoothAudio;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:284
  ///
  /// In en, this message translates to:
  /// **'Playback pauses when a USB DAC is plugged in'**
  String get playbackPausesWhenAUsbDac;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:295
  ///
  /// In en, this message translates to:
  /// **'Playback pauses when a USB DAC is physically unplugged'**
  String get playbackPausesWhenAUsbDac2;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:251
  ///
  /// In en, this message translates to:
  /// **'Playback pauses when Bluetooth or headphones disconnect'**
  String get playbackPausesWhenBluetoothOrHeadphones;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:246
  ///
  /// In en, this message translates to:
  /// **'Playback pauses while notification sounds play'**
  String get playbackPausesWhileNotificationSoundsPlay;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:273
  ///
  /// In en, this message translates to:
  /// **'Playback resumes when a device reconnects within 30 seconds'**
  String get playbackResumesWhenADeviceReconnects;

  /// lib/features/player/widgets/song_actions_sheet.dart:342
  ///
  /// In en, this message translates to:
  /// **'Playback Speed'**
  String get playbackSpeed;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:38
  ///
  /// In en, this message translates to:
  /// **'Playback stops when the app is swiped away'**
  String get playbackStopsWhenTheAppIs;

  /// lib/features/recently_played/screens/recently_played_screen.dart:268
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} song} other{{count} songs}} played'**
  String played(int count);

  /// lib/features/player/widgets/player_layout_sheet.dart:92
  ///
  /// In en, this message translates to:
  /// **'Player Layout'**
  String get playerLayout;

  /// lib/models/playback_context.dart:14
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get playlist2;

  /// lib/features/playlists/screens/playlists_screen.dart:356
  ///
  /// In en, this message translates to:
  /// **'Playlist name'**
  String get playlistName;

  /// lib/features/menu/screens/menu_screen.dart:1446
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlists;

  /// lib/features/settings/widgets/listenbrainz_settings_tile.dart:584
  ///
  /// In en, this message translates to:
  /// **'Please enter your ListenBrainz user token.'**
  String get pleaseEnterYourListenbrainzUserToken;

  /// lib/features/settings/screens/audio_settings_screen.dart:213
  ///
  /// In en, this message translates to:
  /// **'Pre-amp'**
  String get preAmp;

  /// lib/features/settings/screens/equalizer_screen.dart:1262
  ///
  /// In en, this message translates to:
  /// **'Preamp'**
  String get preamp;

  /// lib/features/settings/screens/uac2_settings_screen.dart:147
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// lib/features/settings/screens/library_settings_screen.dart:1897
  ///
  /// In en, this message translates to:
  /// **'Preload audio data'**
  String get preloadAudioData;

  /// lib/features/settings/screens/library_settings_screen.dart:2132
  ///
  /// In en, this message translates to:
  /// **'Preload Library Audio'**
  String get preloadLibraryAudio;

  /// lib/features/settings/screens/library_settings_screen.dart:785
  ///
  /// In en, this message translates to:
  /// **'Preloading Audio'**
  String get preloadingAudio;

  /// lib/features/settings/screens/library_settings_screen.dart:1376
  ///
  /// In en, this message translates to:
  /// **'Preloading audio {arg1}/{arg2}'**
  String preloadingAudio2(Object arg1, Object arg2);

  /// lib/widgets/common/floating_scan_progress.dart:379
  ///
  /// In en, this message translates to:
  /// **'Preloading audio'**
  String get preloadingAudio3;

  /// lib/features/settings/screens/equalizer_screen.dart:1890
  ///
  /// In en, this message translates to:
  /// **'Presence'**
  String get presence;

  /// lib/features/settings/screens/equalizer_screen.dart:90
  ///
  /// In en, this message translates to:
  /// **'Preset: {activePresetName}'**
  String preset(Object activePresetName);

  /// lib/features/settings/screens/equalizer_screen.dart:578
  ///
  /// In en, this message translates to:
  /// **'Preset imported with adjustments'**
  String get presetImportedWithAdjustments;

  /// lib/features/settings/screens/equalizer_screen.dart:438
  ///
  /// In en, this message translates to:
  /// **'Preset name'**
  String get presetName;

  /// lib/features/settings/screens/equalizer_screen.dart:66
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get presets;

  /// lib/features/settings/screens/audio_settings_screen.dart:228
  ///
  /// In en, this message translates to:
  /// **'Prevent Clipping'**
  String get preventClipping;

  /// lib/features/settings/screens/audio_settings_screen.dart:686
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// lib/features/player/widgets/online_lyrics_search_sheet.dart:457
  ///
  /// In en, this message translates to:
  /// **'Preview & Use'**
  String get previewUse;

  /// lib/widgets/common/mini_player_bar.dart:258
  ///
  /// In en, this message translates to:
  /// **'Previous song'**
  String get previousSong;

  /// lib/features/settings/widgets/mini_player_customization.dart:176
  ///
  /// In en, this message translates to:
  /// **'Previous Song'**
  String get previousSong2;

  /// lib/features/settings/screens/uac2_settings_screen.dart:905
  ///
  /// In en, this message translates to:
  /// **'Prewarming'**
  String get prewarming;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:504
  ///
  /// In en, this message translates to:
  /// **'Prioritise connection stability'**
  String get prioritiseConnectionStability;

  /// lib/features/settings/screens/app_info_settings_screen.dart:666
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// lib/features/settings/screens/equalizer_screen.dart:3273
  ///
  /// In en, this message translates to:
  /// **'Processing live'**
  String get processingLive;

  /// lib/features/settings/screens/uac2_settings_screen.dart:475
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get product;

  /// lib/features/settings/screens/uac2_settings_screen.dart:496
  ///
  /// In en, this message translates to:
  /// **'Product ID'**
  String get productId;

  /// lib/features/settings/widgets/mini_player_customization.dart:168
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// lib/features/settings/screens/ui_customization_settings_screen.dart:234
  ///
  /// In en, this message translates to:
  /// **'Progress Bar'**
  String get progressBar;

  /// lib/features/settings/screens/network_server_edit_screen.dart:372
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get protocol;

  /// lib/features/settings/screens/widget_settings_screen.dart:299
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get purple;

  /// lib/features/menu/screens/menu_screen.dart:1081
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queue;

  /// lib/features/player/screens/full_player_screen.dart:777
  ///
  /// In en, this message translates to:
  /// **'Queue {count}'**
  String queue2(Object count);

  /// lib/features/player/widgets/player_navigation.dart:25
  ///
  /// In en, this message translates to:
  /// **'Queued \"{arg1}\"'**
  String queued(Object arg1);

  /// lib/features/albums/screens/album_detail_screen.dart:263
  ///
  /// In en, this message translates to:
  /// **'Queued {arg1} songs'**
  String queuedSongs(Object arg1);

  /// lib/features/songs/screens/songs_screen.dart:1345
  ///
  /// In en, this message translates to:
  /// **'Queued {arg1} songs'**
  String queuedSongs3(Object arg1);

  /// lib/features/settings/screens/ui_customization_settings_screen.dart:29
  ///
  /// In en, this message translates to:
  /// **'Quick Access'**
  String get quickAccess;

  /// lib/features/player/widgets/player_layout_sheet.dart:333
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// lib/features/settings/screens/library_settings_screen.dart:2126
  ///
  /// In en, this message translates to:
  /// **'Quick or full re-index of all folders'**
  String get quickOrFullReIndexOf;

  /// lib/features/settings/screens/library_settings_screen.dart:701
  ///
  /// In en, this message translates to:
  /// **'Quick scan'**
  String get quickScan;

  /// lib/models/advance_list_order.dart:9
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get random;

  /// lib/features/settings/screens/library_settings_screen.dart:1035
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rate;

  /// lib/features/manual/data/manual_data.dart:236
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// lib/features/settings/screens/equalizer_screen.dart:3332
  ///
  /// In en, this message translates to:
  /// **'Ratio'**
  String get ratio;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1692
  ///
  /// In en, this message translates to:
  /// **'Raw DSD stream to DAC. Requires ENCODING_DSD hardware support; otherwise falls back to DoP or PCM automatically.'**
  String get rawDsdStreamToDacRequires;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:918
  ///
  /// In en, this message translates to:
  /// **'→ Raw PCM'**
  String get rawPcm;

  /// lib/features/settings/screens/library_settings_screen.dart:710
  ///
  /// In en, this message translates to:
  /// **'Re-read metadata for every file. Slower; use when tags look stale.'**
  String get reReadMetadataForEveryFile;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:1086
  ///
  /// In en, this message translates to:
  /// **'Read Mode'**
  String get readMode;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:784
  ///
  /// In en, this message translates to:
  /// **'Ready to remove {count, plural, =1{{count} song} other{{count} songs}} — keeping {kept} in total.'**
  String readyToRemoveSongKeepingIn(int count, Object kept);

  /// lib/features/menu/screens/menu_screen.dart:1428
  ///
  /// In en, this message translates to:
  /// **'Recently Added'**
  String get recentlyAdded;

  /// lib/features/menu/screens/menu_screen.dart:931
  ///
  /// In en, this message translates to:
  /// **'Recently Played'**
  String get recentlyPlayed;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:1515
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get recommended;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:1213
  ///
  /// In en, this message translates to:
  /// **'Recommended only'**
  String get recommendedOnly;

  /// lib/widgets/uac2/uac2_connection_manager.dart:160
  ///
  /// In en, this message translates to:
  /// **'Reconnect Attempts'**
  String get reconnectAttempts;

  /// lib/widgets/uac2/uac2_connection_manager.dart:205
  ///
  /// In en, this message translates to:
  /// **'Reconnect Now'**
  String get reconnectNow;

  /// lib/features/settings/screens/app_info_settings_screen.dart:614
  ///
  /// In en, this message translates to:
  /// **'Reconnect to the internet to scan for updates'**
  String get reconnectToTheInternetToScan;

  /// lib/features/settings/screens/app_info_settings_screen.dart:159
  ///
  /// In en, this message translates to:
  /// **'Reconnect to Wi-Fi or mobile data so Flick can scan again'**
  String get reconnectToWiFiOrMobile;

  /// lib/widgets/uac2/uac2_connection_manager.dart:72
  ///
  /// In en, this message translates to:
  /// **'Reconnection failed'**
  String get reconnectionFailed;

  /// lib/widgets/uac2/uac2_connection_manager.dart:72
  ///
  /// In en, this message translates to:
  /// **'Reconnection successful'**
  String get reconnectionSuccessful;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:869
  ///
  /// In en, this message translates to:
  /// **'Recorded'**
  String get recorded;

  /// lib/features/albums/screens/album_detail_screen.dart:365
  ///
  /// In en, this message translates to:
  /// **'Refresh Apple Music'**
  String get refreshAppleMusic;

  /// lib/features/settings/screens/uac2_settings_screen.dart:443
  ///
  /// In en, this message translates to:
  /// **'Refresh Devices'**
  String get refreshDevices;

  /// lib/widgets/uac2/uac2_device_selector.dart:179
  ///
  /// In en, this message translates to:
  /// **'Refresh devices'**
  String get refreshDevices2;

  /// lib/features/player/widgets/song_actions_sheet.dart:238
  ///
  /// In en, this message translates to:
  /// **'Refresh Motion Art'**
  String get refreshMotionArt;

  /// lib/features/settings/screens/casting_settings_screen.dart:257
  ///
  /// In en, this message translates to:
  /// **'Refresh outputs'**
  String get refreshOutputs;

  /// lib/features/settings/screens/interface_settings_screen.dart:206
  ///
  /// In en, this message translates to:
  /// **'Refresh Rate'**
  String get refreshRate;

  /// lib/features/albums/screens/album_detail_screen.dart:402
  ///
  /// In en, this message translates to:
  /// **'Refreshing Apple Music data'**
  String get refreshingAppleMusicData;

  /// lib/features/settings/screens/uac2_settings_screen.dart:704
  ///
  /// In en, this message translates to:
  /// **'Registered, not claimed'**
  String get registeredNotClaimed;

  /// lib/features/settings/screens/equalizer_screen.dart:3358
  ///
  /// In en, this message translates to:
  /// **'Release'**
  String get release;

  /// lib/features/queue/screens/queue_screen.dart:847
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:927
  ///
  /// In en, this message translates to:
  /// **'Remove all'**
  String get removeAll;

  /// lib/features/settings/screens/library_settings_screen.dart:428
  ///
  /// In en, this message translates to:
  /// **'Remove All Songs?'**
  String get removeAllSongs;

  /// lib/features/settings/screens/library_settings_screen.dart:2183
  ///
  /// In en, this message translates to:
  /// **'Remove All Songs'**
  String get removeAllSongs2;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:924
  ///
  /// In en, this message translates to:
  /// **'Remove all with best picks?'**
  String get removeAllWithBestPicks;

  /// lib/features/settings/screens/library_settings_screen.dart:838
  ///
  /// In en, this message translates to:
  /// **'Remove \"{arg1}\" and all of its songs from your library? Files on disk are not deleted.'**
  String removeAndAllOfItsSongs(Object arg1);

  /// lib/features/songs/widgets/album_art_picker_bottom_sheet.dart:357
  ///
  /// In en, this message translates to:
  /// **'Remove Custom Art'**
  String get removeCustomArt;

  /// lib/features/settings/screens/library_settings_screen.dart:2147
  ///
  /// In en, this message translates to:
  /// **'Remove Duplicates'**
  String get removeDuplicates;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:876
  ///
  /// In en, this message translates to:
  /// **'Remove {toRemove} duplicates?'**
  String removeDuplicates2(Object toRemove);

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:813
  ///
  /// In en, this message translates to:
  /// **'Remove {toRemove} duplicates'**
  String removeDuplicates3(Object toRemove);

  /// lib/features/settings/screens/library_settings_screen.dart:836
  ///
  /// In en, this message translates to:
  /// **'Remove Folder?'**
  String get removeFolder;

  /// lib/features/songs/widgets/song_actions_bottom_sheet.dart:88
  ///
  /// In en, this message translates to:
  /// **'Remove from Favorites'**
  String get removeFromFavorites;

  /// lib/widgets/common/detail_header.dart:257
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFromFavorites2;

  /// lib/features/songs/screens/songs_screen.dart:1639
  ///
  /// In en, this message translates to:
  /// **'Remove from Library'**
  String get removeFromLibrary;

  /// lib/features/songs/widgets/song_actions_bottom_sheet.dart:78
  ///
  /// In en, this message translates to:
  /// **'Remove from Playlist'**
  String get removeFromPlaylist;

  /// lib/features/settings/screens/network_server_edit_screen.dart:327
  ///
  /// In en, this message translates to:
  /// **'Remove server?'**
  String get removeServer;

  /// lib/features/settings/screens/network_server_edit_screen.dart:520
  ///
  /// In en, this message translates to:
  /// **'Remove server'**
  String get removeServer2;

  /// lib/features/songs/screens/songs_screen.dart:1629
  ///
  /// In en, this message translates to:
  /// **'Remove the database entries or delete the files from your device. This cannot be undone.'**
  String get removeTheDatabaseEntriesOrDelete;

  /// lib/features/songs/widgets/song_actions_bottom_sheet.dart:736
  ///
  /// In en, this message translates to:
  /// **'Remove the database entry or delete the file from your device. This cannot be undone.'**
  String get removeTheDatabaseEntryOrDelete;

  /// lib/features/songs/screens/songs_screen.dart:1630
  ///
  /// In en, this message translates to:
  /// **'Remove these songs from your library. The files on your device will not be affected.'**
  String get removeTheseSongsFromYourLibrary;

  /// lib/features/songs/widgets/song_actions_bottom_sheet.dart:737
  ///
  /// In en, this message translates to:
  /// **'Remove this song from your library. The file on your device will not be affected.'**
  String get removeThisSongFromYourLibrary;

  /// lib/features/songs/widgets/album_art_picker_bottom_sheet.dart:193
  ///
  /// In en, this message translates to:
  /// **'Removed custom album art for \"{arg1}\".'**
  String removedCustomAlbumArtFor(Object arg1);

  /// lib/features/songs/widgets/album_art_picker_bottom_sheet.dart:194
  ///
  /// In en, this message translates to:
  /// **'Removed custom album art for \"{arg1}\".'**
  String removedCustomAlbumArtFor2(Object arg1);

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:901
  ///
  /// In en, this message translates to:
  /// **'Removed {arg1} duplicates — kept {arg2}.'**
  String removedDuplicatesKept(Object arg1, Object arg2);

  /// lib/features/favorites/screens/favorites_screen.dart:61
  ///
  /// In en, this message translates to:
  /// **'Removed \"{arg1}\" from favorites'**
  String removedFromFavorites(Object arg1);

  /// lib/features/favorites/screens/favorites_screen.dart:126
  ///
  /// In en, this message translates to:
  /// **'Removed {arg1} from favorites'**
  String removedFromFavorites2(Object arg1);

  /// lib/features/player/widgets/player_action_button_row.dart:487
  ///
  /// In en, this message translates to:
  /// **'Removed from favorites'**
  String get removedFromFavorites3;

  /// lib/features/songs/widgets/song_actions_bottom_sheet.dart:830
  ///
  /// In en, this message translates to:
  /// **'Removed \"{arg1}\" from library'**
  String removedFromLibrary(Object arg1);

  /// lib/features/albums/screens/album_detail_screen.dart:299
  ///
  /// In en, this message translates to:
  /// **'Removed {arg1} songs from favorites'**
  String removedSongsFromFavorites(Object arg1);

  /// lib/features/songs/screens/songs_screen.dart:1715
  ///
  /// In en, this message translates to:
  /// **'Removed {arg1} songs from library'**
  String removedSongsFromLibrary(Object arg1);

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:813
  ///
  /// In en, this message translates to:
  /// **'Removing…'**
  String get removing;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:783
  ///
  /// In en, this message translates to:
  /// **'Removing duplicates…'**
  String get removingDuplicates;

  /// lib/features/settings/screens/equalizer_screen.dart:1082
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// lib/features/settings/screens/equalizer_screen.dart:437
  ///
  /// In en, this message translates to:
  /// **'Rename Preset'**
  String get renamePreset;

  /// lib/providers/tutorial_provider.dart:28
  ///
  /// In en, this message translates to:
  /// **'Reorder, filter, and shuffle from this header.'**
  String get reorderFilterAndShuffleFromThis;

  /// lib/features/player/widgets/player_controls.dart:218
  ///
  /// In en, this message translates to:
  /// **'Repeat: {arg1}'**
  String repeat(Object arg1);

  /// lib/features/player/widgets/loop_mode_sheet.dart:16
  ///
  /// In en, this message translates to:
  /// **'Repeat Mode'**
  String get repeatMode;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:368
  ///
  /// In en, this message translates to:
  /// **'Replace album name with a verified bit-perfect capsule when streaming bit-perfect'**
  String get replaceAlbumNameWithAVerified;

  /// lib/features/settings/screens/app_info_settings_screen.dart:680
  ///
  /// In en, this message translates to:
  /// **'Replay the tutorial and feature guide'**
  String get replayTheTutorialAndFeatureGuide;

  /// lib/features/settings/screens/audio_settings_screen.dart:184
  ///
  /// In en, this message translates to:
  /// **'ReplayGain'**
  String get replaygain;

  /// lib/features/settings/screens/library_settings_screen.dart:812
  ///
  /// In en, this message translates to:
  /// **'ReplayGain Scan'**
  String get replaygainScan;

  /// lib/features/settings/screens/uac2_settings_screen.dart:676
  ///
  /// In en, this message translates to:
  /// **'Reported Output Rate'**
  String get reportedOutputRate;

  /// lib/features/settings/screens/uac2_settings_screen.dart:667
  ///
  /// In en, this message translates to:
  /// **'Requested Output Rate'**
  String get requestedOutputRate;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:237
  ///
  /// In en, this message translates to:
  /// **'Required to detect devices, codecs, and battery levels'**
  String get requiredToDetectDevicesCodecsAnd;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:669
  ///
  /// In en, this message translates to:
  /// **'Resampler'**
  String get resampler;

  /// lib/features/settings/screens/library_settings_screen.dart:693
  ///
  /// In en, this message translates to:
  /// **'Rescan Library'**
  String get rescanLibrary;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:339
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:512
  ///
  /// In en, this message translates to:
  /// **'Reset Declined USB DACs'**
  String get resetDeclinedUsbDacs;

  /// lib/features/settings/screens/equalizer_screen.dart:3285
  ///
  /// In en, this message translates to:
  /// **'Reset Dynamics'**
  String get resetDynamics;

  /// lib/features/settings/screens/equalizer_screen.dart:3534
  ///
  /// In en, this message translates to:
  /// **'Reset FX'**
  String get resetFx;

  /// lib/features/settings/widgets/mini_player_customization.dart:279
  ///
  /// In en, this message translates to:
  /// **'Reset Mini Player to Defaults'**
  String get resetMiniPlayerToDefaults;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:283
  ///
  /// In en, this message translates to:
  /// **'Reset Navigation to Defaults'**
  String get resetNavigationToDefaults;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:557
  ///
  /// In en, this message translates to:
  /// **'Reset Preferences'**
  String get resetPreferences;

  /// lib/features/settings/screens/interface_settings_screen.dart:20
  ///
  /// In en, this message translates to:
  /// **'Reset streak data?'**
  String get resetStreakData;

  /// lib/features/settings/screens/interface_settings_screen.dart:173
  ///
  /// In en, this message translates to:
  /// **'Reset Streak Data'**
  String get resetStreakData2;

  /// lib/features/settings/screens/equalizer_screen.dart:2746
  ///
  /// In en, this message translates to:
  /// **'Reset to 0 dB'**
  String get resetTo0Db;

  /// lib/features/settings/screens/orbit_settings_screen.dart:199
  ///
  /// In en, this message translates to:
  /// **'Reset to Defaults'**
  String get resetToDefaults;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:560
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get resolution;

  /// lib/providers/equalizer_provider.dart:70
  ///
  /// In en, this message translates to:
  /// **'Resonance'**
  String get resonance;

  /// lib/widgets/common/engine_restart_notice.dart:88
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// lib/widgets/common/engine_restart_notice.dart:46
  ///
  /// In en, this message translates to:
  /// **'Restart required'**
  String get restartRequired;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:989
  ///
  /// In en, this message translates to:
  /// **'Restart the app to apply playback changes.'**
  String get restartTheAppToApplyPlayback;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1000
  ///
  /// In en, this message translates to:
  /// **'Restart your device to apply output format changes.'**
  String get restartYourDeviceToApplyOutput;

  /// lib/features/settings/screens/orbit_settings_screen.dart:200
  ///
  /// In en, this message translates to:
  /// **'Restore the original orbital layout'**
  String get restoreTheOriginalOrbitalLayout;

  /// lib/features/artists/screens/artists_screen.dart:510
  ///
  /// In en, this message translates to:
  /// **'Results ({arg1})'**
  String results(Object arg1);

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:271
  ///
  /// In en, this message translates to:
  /// **'Resume on Reconnect'**
  String get resumeOnReconnect;

  /// lib/models/song.dart:358
  ///
  /// In en, this message translates to:
  /// **'Retro Future'**
  String get retroFuture;

  /// lib/features/songs/screens/songs_screen.dart:1838
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:545
  ///
  /// In en, this message translates to:
  /// **'Review before you clean'**
  String get reviewBeforeYouClean;

  /// lib/features/settings/screens/lyrics_settings_screen.dart:80
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get right;

  /// lib/features/player/widgets/player_layout_sheet.dart:373
  ///
  /// In en, this message translates to:
  /// **'Right (bottom)'**
  String get rightBottom;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:460
  ///
  /// In en, this message translates to:
  /// **'Right (Bottom) Button'**
  String get rightBottomButton;

  /// lib/features/player/widgets/player_layout_sheet.dart:361
  ///
  /// In en, this message translates to:
  /// **'Right (top)'**
  String get rightTop;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:435
  ///
  /// In en, this message translates to:
  /// **'Right (Top) Button'**
  String get rightTopButton;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:1078
  ///
  /// In en, this message translates to:
  /// **'Rip Source'**
  String get ripSource;

  /// lib/services/sources/upnp_service.dart:239
  ///
  /// In en, this message translates to:
  /// **'Root'**
  String get root;

  /// lib/features/player/widgets/album_art_box.dart:704
  ///
  /// In en, this message translates to:
  /// **'rotation seek'**
  String get rotationSeek;

  /// lib/models/player_screen_mode.dart:28
  ///
  /// In en, this message translates to:
  /// **'Rounded album art card with a blurred album-art background.'**
  String get roundedAlbumArtCardWithA;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:654
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get route;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:419
  ///
  /// In en, this message translates to:
  /// **'Routes Bluetooth through the hi-res Rust engine'**
  String get routesBluetoothThroughTheHiRes;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:434
  ///
  /// In en, this message translates to:
  /// **'Routes Bluetooth through the Rust engine'**
  String get routesBluetoothThroughTheRustEngine;

  /// lib/features/settings/screens/app_info_settings_screen.dart:612
  ///
  /// In en, this message translates to:
  /// **'Run another Play Store update scan right now'**
  String get runAnotherPlayStoreUpdateScan;

  /// lib/features/settings/screens/app_info_settings_screen.dart:613
  ///
  /// In en, this message translates to:
  /// **'Run another update scan right now'**
  String get runAnotherUpdateScanRightNow;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:794
  ///
  /// In en, this message translates to:
  /// **'Rust via Oboe'**
  String get rustViaOboe;

  /// lib/models/audio_engine_type.dart:39
  ///
  /// In en, this message translates to:
  /// **'Rust via Oboe (high-res)'**
  String get rustViaOboeHighRes;

  /// lib/features/player/widgets/lyrics_word_timeline.dart:192
  ///
  /// In en, this message translates to:
  /// **'{arg1}s'**
  String s(Object arg1);

  /// lib/features/settings/screens/audio_settings_screen.dart:734
  ///
  /// In en, this message translates to:
  /// **'{arg1} s'**
  String s2(Object arg1);

  /// lib/widgets/uac2/uac2_hotplug_monitor.dart:103
  ///
  /// In en, this message translates to:
  /// **'{arg1}s ago'**
  String sAgo(Object arg1);

  /// lib/features/settings/screens/audio_settings_screen.dart:248
  ///
  /// In en, this message translates to:
  /// **'S-Curve'**
  String get sCurve;

  /// lib/features/settings/screens/network_server_edit_screen.dart:90
  ///
  /// In en, this message translates to:
  /// **'Samba · Windows share'**
  String get sambaWindowsShareTransportPending;

  /// lib/features/settings/widgets/mini_player_customization.dart:370
  ///
  /// In en, this message translates to:
  /// **'Sample artist'**
  String get sampleArtist;

  /// lib/features/player/widgets/player_layout_sheet.dart:874
  ///
  /// In en, this message translates to:
  /// **'Sample preview'**
  String get samplePreview;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:370
  ///
  /// In en, this message translates to:
  /// **'Sample rate'**
  String get sampleRate;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1319
  ///
  /// In en, this message translates to:
  /// **'Sample Rate'**
  String get sampleRate2;

  /// lib/features/settings/screens/uac2_settings_screen.dart:560
  ///
  /// In en, this message translates to:
  /// **'Sample Rates'**
  String get sampleRates;

  /// lib/features/settings/widgets/mini_player_customization.dart:388
  ///
  /// In en, this message translates to:
  /// **'Sample song · preview only'**
  String get sampleSongPreviewOnly;

  /// lib/widgets/alac_conversion_indicator.dart:144
  ///
  /// In en, this message translates to:
  /// **'Samples'**
  String get samples;

  /// lib/features/player/widgets/share/share_bottom_sheet.dart:299
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// lib/features/settings/screens/logs_screen.dart:325
  ///
  /// In en, this message translates to:
  /// **'Save as text'**
  String get saveAsText;

  /// lib/features/songs/screens/metadata_editor_screen.dart:545
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// lib/features/settings/widgets/lastfm_settings_tile.dart:656
  ///
  /// In en, this message translates to:
  /// **'Save & Connect'**
  String get saveConnect;

  /// lib/features/player/screens/lyrics_sync_screen.dart:2040
  ///
  /// In en, this message translates to:
  /// **'Save creates an `.lrc` file. If some lines are not stamped yet, Flick fills their times automatically so the file stays usable. Lines with fully stamped words export with per-word karaoke timing.'**
  String get saveCreatesAnLrcFileIf;

  /// lib/features/settings/screens/equalizer_screen.dart:737
  ///
  /// In en, this message translates to:
  /// **'Save current as preset'**
  String get saveCurrentAsPreset;

  /// lib/features/player/screens/lyrics_sync_screen.dart:503
  ///
  /// In en, this message translates to:
  /// **'Save in Flick'**
  String get saveInFlick;

  /// lib/features/settings/screens/logs_screen.dart:207
  ///
  /// In en, this message translates to:
  /// **'Save logs'**
  String get saveLogs;

  /// lib/features/player/screens/lyrics_sync_screen.dart:490
  ///
  /// In en, this message translates to:
  /// **'Save LRC File'**
  String get saveLrcFile;

  /// lib/features/player/screens/lyrics_sync_screen.dart:525
  ///
  /// In en, this message translates to:
  /// **'Save LRC file'**
  String get saveLrcFile2;

  /// lib/features/player/widgets/online_lyrics_search_sheet.dart:1184
  ///
  /// In en, this message translates to:
  /// **'Save Lyrics'**
  String get saveLyrics;

  /// lib/features/settings/screens/equalizer_screen.dart:437
  ///
  /// In en, this message translates to:
  /// **'Save Preset'**
  String get savePreset;

  /// lib/features/settings/screens/equalizer_screen.dart:752
  ///
  /// In en, this message translates to:
  /// **'Save the current EQ as JSON or TXT'**
  String get saveTheCurrentEqAsJson;

  /// lib/features/settings/screens/logs_screen.dart:217
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// lib/features/songs/screens/metadata_editor_screen.dart:187
  ///
  /// In en, this message translates to:
  /// **'Saved and verified'**
  String get savedAndVerified;

  /// lib/features/player/screens/lyrics_sync_screen.dart:557
  ///
  /// In en, this message translates to:
  /// **'Saved lyrics and linked them to this song.'**
  String get savedLyricsAndLinkedThemTo;

  /// lib/features/player/screens/lyrics_sync_screen.dart:556
  ///
  /// In en, this message translates to:
  /// **'Saved lyrics beside the song as an `.lrc` file.'**
  String get savedLyricsBesideTheSongAs;

  /// lib/features/player/screens/lyrics_sync_screen.dart:554
  ///
  /// In en, this message translates to:
  /// **'Saved lyrics to the chosen location.'**
  String get savedLyricsToTheChosenLocation;

  /// lib/features/player/widgets/share/share_bottom_sheet.dart:163
  ///
  /// In en, this message translates to:
  /// **'Saved to gallery'**
  String get savedToGallery;

  /// lib/features/settings/screens/logs_screen.dart:218
  ///
  /// In en, this message translates to:
  /// **'Saved to:\n{path}\n\nShare it now?'**
  String savedToNNNshareIt(Object path);

  /// lib/features/songs/screens/metadata_editor_screen.dart:195
  ///
  /// In en, this message translates to:
  /// **'Saved (verification pending)'**
  String get savedVerificationPending;

  /// lib/features/player/screens/lyrics_sync_screen.dart:791
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// lib/features/settings/screens/lyrics_settings_screen.dart:20
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get saving2;

  /// lib/features/settings/screens/orbit_settings_screen.dart:114
  ///
  /// In en, this message translates to:
  /// **'Scale of the centered, focused song card'**
  String get scaleOfTheCenteredFocusedSong;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:240
  ///
  /// In en, this message translates to:
  /// **'Scale the album art card'**
  String get scaleTheAlbumArtCard;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:165
  ///
  /// In en, this message translates to:
  /// **'Scale the full-view album art card'**
  String get scaleTheFullViewAlbumArt;

  /// lib/features/settings/screens/widget_settings_screen.dart:236
  ///
  /// In en, this message translates to:
  /// **'Scales with widget size automatically'**
  String get scalesWithWidgetSizeAutomatically;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:285
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get scanAgain;

  /// lib/features/settings/screens/library_settings_screen.dart:1299
  ///
  /// In en, this message translates to:
  /// **'Scan Complete'**
  String get scanComplete;

  /// lib/features/settings/screens/library_settings_screen.dart:556
  ///
  /// In en, this message translates to:
  /// **'Scan failed. Please try again.'**
  String get scanFailedPleaseTryAgain;

  /// lib/features/settings/screens/casting_settings_screen.dart:75
  ///
  /// In en, this message translates to:
  /// **'Scan for devices'**
  String get scanForDevices;

  /// lib/widgets/common/floating_scan_progress.dart:489
  ///
  /// In en, this message translates to:
  /// **'Scan progress'**
  String get scanProgress;

  /// lib/features/settings/screens/library_settings_screen.dart:2139
  ///
  /// In en, this message translates to:
  /// **'Scan ReplayGain'**
  String get scanReplaygain;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:142
  ///
  /// In en, this message translates to:
  /// **'Scanning for duplicates…'**
  String get scanningForDuplicates;

  /// lib/features/settings/screens/library_settings_screen.dart:1775
  ///
  /// In en, this message translates to:
  /// **'Scanning Settings'**
  String get scanningSettings;

  /// lib/features/settings/screens/library_settings_screen.dart:1640
  ///
  /// In en, this message translates to:
  /// **'Scanning... {count} songs found'**
  String scanningSongsFound(Object count);

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:390
  ///
  /// In en, this message translates to:
  /// **'Scanning your library…'**
  String get scanningYourLibrary;

  /// lib/features/settings/widgets/mini_player_customization.dart:248
  ///
  /// In en, this message translates to:
  /// **'Scroll'**
  String get scroll;

  /// lib/features/songs/screens/songs_screen.dart:3163
  ///
  /// In en, this message translates to:
  /// **'Scroll for more'**
  String get scrollForMore;

  /// lib/features/settings/widgets/mini_player_customization.dart:250
  ///
  /// In en, this message translates to:
  /// **'Scrolling pauses when reduced motion is enabled'**
  String get scrollingPausesWhenReducedMotionIs;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:275
  ///
  /// In en, this message translates to:
  /// **'Seamless transition between tracks'**
  String get seamlessTransitionBetweenTracks;

  /// lib/providers/tutorial_provider.dart:21
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// lib/providers/tutorial_provider.dart:22
  ///
  /// In en, this message translates to:
  /// **'Search across songs, artists, and albums instantly.'**
  String get searchAcrossSongsArtistsAndAlbums;

  /// lib/features/albums/widgets/identify_album_sheet.dart:241
  ///
  /// In en, this message translates to:
  /// **'Search Again'**
  String get searchAgain;

  /// lib/features/player/widgets/online_lyrics_search_sheet.dart:618
  ///
  /// In en, this message translates to:
  /// **'Search artist + title...'**
  String get searchArtistTitle;

  /// lib/features/artists/screens/artists_screen.dart:297
  ///
  /// In en, this message translates to:
  /// **'Search artists...'**
  String get searchArtists;

  /// lib/features/songs/widgets/album_art_picker_bottom_sheet.dart:479
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get searchFailed;

  /// lib/features/search/screens/search_screen.dart:220
  ///
  /// In en, this message translates to:
  /// **'Search failed: {e}'**
  String searchFailed2(Object e);

  /// lib/features/settings/screens/widgets/autoeq_search_sheet.dart:233
  ///
  /// In en, this message translates to:
  /// **'Search headphones…'**
  String get searchHeadphones;

  /// lib/features/settings/screens/widgets/autoeq_search_sheet.dart:233
  ///
  /// In en, this message translates to:
  /// **'Search {count, plural, =1{{count} model} other{{count} models}}…'**
  String searchModelCount(int count);

  /// lib/features/player/widgets/inline_lyrics_panel.dart:219
  ///
  /// In en, this message translates to:
  /// **'Search Online'**
  String get searchOnline;

  /// lib/features/settings/screens/widgets/autoeq_search_sheet.dart:414
  ///
  /// In en, this message translates to:
  /// **'Search online'**
  String get searchOnline2;

  /// lib/features/player/widgets/inline_lyrics_panel.dart:424
  ///
  /// In en, this message translates to:
  /// **'Search online, create your own synced lyrics, or import an existing file.'**
  String get searchOnlineCreateYourOwnSynced;

  /// lib/features/player/widgets/online_lyrics_search_sheet.dart:277
  ///
  /// In en, this message translates to:
  /// **'Search Online Lyrics'**
  String get searchOnlineLyrics;

  /// lib/features/settings/screens/interface_settings_screen.dart:247
  ///
  /// In en, this message translates to:
  /// **'Search Playback'**
  String get searchPlayback;

  /// lib/features/settings/screens/interface_settings_screen.dart:252
  ///
  /// In en, this message translates to:
  /// **'Search Results'**
  String get searchResults;

  /// lib/features/songs/screens/songs_screen.dart:206
  ///
  /// In en, this message translates to:
  /// **'Search songs, artists...'**
  String get searchSongsArtists;

  /// lib/features/search/screens/search_screen.dart:138
  ///
  /// In en, this message translates to:
  /// **'Search songs, artists, albums...'**
  String get searchSongsArtistsAlbums;

  /// lib/features/search/screens/search_screen.dart:240
  ///
  /// In en, this message translates to:
  /// **'Search your library'**
  String get searchYourLibrary;

  /// lib/features/settings/screens/casting_settings_screen.dart:75
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get searching;

  /// lib/features/songs/widgets/album_art_picker_bottom_sheet.dart:469
  ///
  /// In en, this message translates to:
  /// **'Searching online'**
  String get searchingOnline;

  /// lib/features/settings/screens/casting_settings_screen.dart:205
  ///
  /// In en, this message translates to:
  /// **'Searching the local network…'**
  String get searchingTheLocalNetwork;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:93
  ///
  /// In en, this message translates to:
  /// **'Seconds of inactivity before collapsing'**
  String get secondsOfInactivityBeforeCollapsing;

  /// lib/features/menu/screens/menu_screen.dart:939
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// lib/features/search/screens/search_screen.dart:371
  ///
  /// In en, this message translates to:
  /// **'See all {count}'**
  String seeAll2(Object count);

  /// lib/features/settings/screens/app_info_settings_screen.dart:624
  ///
  /// In en, this message translates to:
  /// **'See what is new in this update'**
  String get seeWhatIsNewInThis;

  /// lib/features/favorites/screens/favorites_screen.dart:182
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// lib/features/settings/screens/library_settings_screen.dart:2118
  ///
  /// In en, this message translates to:
  /// **'Select a folder to scan'**
  String get selectAFolderToScan;

  /// lib/features/player/screens/lyrics_sync_screen.dart:694
  ///
  /// In en, this message translates to:
  /// **'1. Select a line and edit its timestamp directly, or use \"Use Current Time\".\n2. In the word timeline, drag a boundary to stretch or shrink the segment before it — edits snap to 10ms.\n3. Tap letters in the inspector to split a word into separately timed syllables (slow-then-fast pacing), then drag their boundaries.\n4. Drag the last boundary (or use Length ±) to retime the next line. Use Auto-fill to seed evenly spaced words.\n5. Use the shift controls to move all stamped lyrics together.\n6. Save to generate the final `.lrc` file.'**
  String get selectALineAndEdit;

  /// lib/features/albums/widgets/identify_album_sheet.dart:580
  ///
  /// In en, this message translates to:
  /// **'Select a release'**
  String get selectARelease;

  /// lib/features/favorites/screens/favorites_screen.dart:263
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// lib/features/songs/screens/songs_screen.dart:1574
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll2;

  /// lib/widgets/uac2/uac2_device_selector.dart:58
  ///
  /// In en, this message translates to:
  /// **'Select Device'**
  String get selectDevice;

  /// lib/features/favorites/screens/favorites_screen.dart:252
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selected(Object count);

  /// lib/features/settings/screens/orbit_settings_screen.dart:113
  ///
  /// In en, this message translates to:
  /// **'Selected Size'**
  String get selectedSize;

  /// lib/features/milestone/screens/milestones_screen.dart:510
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get sep;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:60
  ///
  /// In en, this message translates to:
  /// **'Separate from Nav Bar'**
  String get separateFromNavBar;

  /// lib/features/settings/widgets/mini_player_customization.dart:115
  ///
  /// In en, this message translates to:
  /// **'Separate the mini player to customize its width and gap. Your custom values are saved while joined.'**
  String get separateTheMiniPlayerToCustomize;

  /// lib/features/settings/screens/uac2_settings_screen.dart:482
  ///
  /// In en, this message translates to:
  /// **'Serial Number'**
  String get serialNumber;

  /// lib/features/settings/screens/network_server_edit_screen.dart:442
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverUrl;

  /// lib/features/settings/screens/casting_settings_screen.dart:107
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get session;

  /// lib/features/player/widgets/song_actions_sheet.dart:220
  ///
  /// In en, this message translates to:
  /// **'Set Album Art'**
  String get setAlbumArt;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1589
  ///
  /// In en, this message translates to:
  /// **'Set to Now'**
  String get setToNow;

  /// lib/features/recap/screens/listening_recap_screen.dart:166
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// lib/features/settings/widgets/mini_player_customization.dart:216
  ///
  /// In en, this message translates to:
  /// **'Shadow'**
  String get shadow;

  /// lib/models/song.dart:340
  ///
  /// In en, this message translates to:
  /// **'Shadow Jazz'**
  String get shadowJazz;

  /// lib/features/player/widgets/player_action_button_row.dart:676
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// lib/features/player/widgets/share/share_bottom_sheet.dart:139
  ///
  /// In en, this message translates to:
  /// **'Share failed: {e}'**
  String shareFailed(Object e);

  /// lib/features/settings/widgets/lastfm_settings_tile.dart:500
  ///
  /// In en, this message translates to:
  /// **'Shared Secret'**
  String get sharedSecret;

  /// lib/features/settings/screens/orbit_settings_screen.dart:159
  ///
  /// In en, this message translates to:
  /// **'Sharp (recommended)'**
  String get sharpRecommended;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:149
  ///
  /// In en, this message translates to:
  /// **'Shift metadata text up or down'**
  String get shiftMetadataTextUpOrDown;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:289
  ///
  /// In en, this message translates to:
  /// **'Shift only the album art up or down'**
  String get shiftOnlyTheAlbumArtUp;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:272
  ///
  /// In en, this message translates to:
  /// **'Shift only the song details up or down'**
  String get shiftOnlyTheSongDetailsUp;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:86
  ///
  /// In en, this message translates to:
  /// **'Show a system overlay mini-player over other apps'**
  String get showASystemOverlayMiniPlayer;

  /// lib/features/settings/widgets/mini_player_customization.dart:169
  ///
  /// In en, this message translates to:
  /// **'Show a thin playback progress line'**
  String get showAThinPlaybackProgressLine;

  /// lib/features/player/widgets/player_layout_sheet.dart:261
  ///
  /// In en, this message translates to:
  /// **'Show album'**
  String get showAlbum;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:329
  ///
  /// In en, this message translates to:
  /// **'Show Album'**
  String get showAlbum2;

  /// lib/models/song_tile_thumbnail_mode.dart:29
  ///
  /// In en, this message translates to:
  /// **'Show album artwork.'**
  String get showAlbumArtwork;

  /// lib/features/settings/screens/widget_settings_screen.dart:201
  ///
  /// In en, this message translates to:
  /// **'Show album artwork on the mini player'**
  String get showAlbumArtworkOnTheMini;

  /// lib/features/player/widgets/player_layout_sheet.dart:256
  ///
  /// In en, this message translates to:
  /// **'Show artist'**
  String get showArtist;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:192
  ///
  /// In en, this message translates to:
  /// **'Show Artist'**
  String get showArtist2;

  /// lib/features/settings/screens/widget_settings_screen.dart:216
  ///
  /// In en, this message translates to:
  /// **'Show artist below song title'**
  String get showArtistBelowSongTitle;

  /// lib/features/player/widgets/player_layout_sheet.dart:266
  ///
  /// In en, this message translates to:
  /// **'Show file info'**
  String get showFileInfo;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:204
  ///
  /// In en, this message translates to:
  /// **'Show File Info'**
  String get showFileInfo2;

  /// lib/features/player/widgets/player_layout_sheet.dart:271
  ///
  /// In en, this message translates to:
  /// **'Show frame'**
  String get showFrame;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:354
  ///
  /// In en, this message translates to:
  /// **'Show Frame'**
  String get showFrame2;

  /// lib/features/settings/screens/orbit_settings_screen.dart:187
  ///
  /// In en, this message translates to:
  /// **'Show Glow'**
  String get showGlow;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:306
  ///
  /// In en, this message translates to:
  /// **'Show Labels'**
  String get showLabels;

  /// lib/features/search/screens/search_screen.dart:671
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get showLess;

  /// lib/features/player/widgets/player_action_button_row.dart:440
  ///
  /// In en, this message translates to:
  /// **'Show lyrics'**
  String get showLyrics;

  /// lib/features/songs/screens/songs_screen.dart:3180
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get showMore;

  /// lib/features/settings/screens/ui_customization_settings_screen.dart:181
  ///
  /// In en, this message translates to:
  /// **'Show more art by fading only the bottom of the header and lowering body content'**
  String get showMoreArtByFadingOnly;

  /// lib/features/settings/screens/settings_screen.dart:199
  ///
  /// In en, this message translates to:
  /// **'Show or hide home screen sections'**
  String get showOrHideHomeScreenSections;

  /// lib/features/settings/screens/orbit_settings_screen.dart:179
  ///
  /// In en, this message translates to:
  /// **'Show Orbit Path'**
  String get showOrbitPath;

  /// lib/features/artists/screens/artists_screen.dart:763
  ///
  /// In en, this message translates to:
  /// **'Show other artists on album pages'**
  String get showOtherArtistsOnAlbumPages;

  /// lib/features/settings/screens/network_server_edit_screen.dart:765
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// lib/features/settings/screens/ui_customization_settings_screen.dart:78
  ///
  /// In en, this message translates to:
  /// **'Show playlist previews on the home screen'**
  String get showPlaylistPreviewsOnTheHome;

  /// lib/features/settings/screens/ui_customization_settings_screen.dart:54
  ///
  /// In en, this message translates to:
  /// **'Show recently played artists on the home screen'**
  String get showRecentlyPlayedArtistsOnThe;

  /// lib/features/artists/screens/artists_screen.dart:753
  ///
  /// In en, this message translates to:
  /// **'Show related albums on album pages'**
  String get showRelatedAlbumsOnAlbumPages;

  /// lib/features/settings/screens/ui_customization_settings_screen.dart:42
  ///
  /// In en, this message translates to:
  /// **'Show smart mixes generated from your listening habits'**
  String get showSmartMixesGeneratedFromYour;

  /// lib/features/settings/widgets/mini_player_customization.dart:161
  ///
  /// In en, this message translates to:
  /// **'Show the artist below the song title'**
  String get showTheArtistBelowTheSong;

  /// lib/features/settings/screens/interface_settings_screen.dart:150
  ///
  /// In en, this message translates to:
  /// **'Show the \"at a glance\" summary on Artists/Albums'**
  String get showTheAtAGlanceSummary;

  /// lib/features/settings/screens/ui_customization_settings_screen.dart:102
  ///
  /// In en, this message translates to:
  /// **'Show the audio engine picker card on the home screen'**
  String get showTheAudioEnginePickerCard;

  /// lib/features/settings/screens/visualizer_settings_screen.dart:29
  ///
  /// In en, this message translates to:
  /// **'Show the audio visualizer (off saves battery)'**
  String get showTheAudioVisualizerOffSaves;

  /// lib/features/settings/screens/ui_customization_settings_screen.dart:90
  ///
  /// In en, this message translates to:
  /// **'Show the browse chips for library sections on the home screen'**
  String get showTheBrowseChipsForLibrary;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:156
  ///
  /// In en, this message translates to:
  /// **'Show the floating mini-player pill on screens'**
  String get showTheFloatingMiniPlayerPill;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:355
  ///
  /// In en, this message translates to:
  /// **'Show the glass frame around album art'**
  String get showTheGlassFrameAroundAlbum;

  /// lib/features/settings/screens/ui_customization_settings_screen.dart:30
  ///
  /// In en, this message translates to:
  /// **'Show the grid of shortcut cards on the home screen'**
  String get showTheGridOfShortcutCards;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:61
  ///
  /// In en, this message translates to:
  /// **'Show the mini player as its own bar above the buttons'**
  String get showTheMiniPlayerAsIts;

  /// lib/models/song_tile_thumbnail_mode.dart:33
  ///
  /// In en, this message translates to:
  /// **'Show the number over blurred art.'**
  String get showTheNumberOverBlurredArt;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:165
  ///
  /// In en, this message translates to:
  /// **'Show the {arg1} tab in the bottom bar'**
  String showTheTabInTheBottom(Object arg1);

  /// lib/models/song_tile_thumbnail_mode.dart:31
  ///
  /// In en, this message translates to:
  /// **'Show the track number.'**
  String get showTheTrackNumber;

  /// lib/features/settings/screens/ui_customization_settings_screen.dart:114
  ///
  /// In en, this message translates to:
  /// **'Show the USB volume bar on the home screen'**
  String get showTheUsbVolumeBarOn;

  /// lib/features/settings/screens/ui_customization_settings_screen.dart:126
  ///
  /// In en, this message translates to:
  /// **'Show the USB volume bar on the UAC2 settings screen'**
  String get showTheUsbVolumeBarOn2;

  /// lib/features/player/widgets/player_layout_sheet.dart:251
  ///
  /// In en, this message translates to:
  /// **'Show title'**
  String get showTitle;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:180
  ///
  /// In en, this message translates to:
  /// **'Show Title'**
  String get showTitle2;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:361
  ///
  /// In en, this message translates to:
  /// **'Show verbose audio diagnostics and engine/session trace logs.'**
  String get showVerboseAudioDiagnosticsAndEngine;

  /// lib/features/player/widgets/player_action_button_row.dart:551
  ///
  /// In en, this message translates to:
  /// **'Show visualizer'**
  String get showVisualizer;

  /// lib/features/settings/screens/ui_customization_settings_screen.dart:66
  ///
  /// In en, this message translates to:
  /// **'Show your recent listening history on the home screen'**
  String get showYourRecentListeningHistoryOn;

  /// lib/features/songs/screens/songs_screen.dart:3122
  ///
  /// In en, this message translates to:
  /// **'Showing all {totalCount} albums'**
  String showingAllAlbums(Object totalCount);

  /// lib/features/songs/screens/songs_screen.dart:3123
  ///
  /// In en, this message translates to:
  /// **'Showing {visibleCount} of {totalCount} albums'**
  String showingOfAlbums(Object visibleCount, Object totalCount);

  /// lib/features/settings/widgets/mini_player_customization.dart:153
  ///
  /// In en, this message translates to:
  /// **'Shown when there is room beside the controls'**
  String get shownWhenThereIsRoomBeside;

  /// lib/providers/tutorial_provider.dart:39
  ///
  /// In en, this message translates to:
  /// **'Shows what\'s playing. Tap to open the full player.'**
  String get showsWhatSPlayingTapTo;

  /// lib/widgets/common/detail_header.dart:267
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// lib/features/player/widgets/player_controls.dart:113
  ///
  /// In en, this message translates to:
  /// **'Shuffle: {arg1}'**
  String shuffle2(Object arg1);

  /// lib/features/player/widgets/shuffle_mode_sheet.dart:18
  ///
  /// In en, this message translates to:
  /// **'Shuffle Mode'**
  String get shuffleMode;

  /// lib/models/shuffle_mode.dart:21
  ///
  /// In en, this message translates to:
  /// **'Shuffle songs and jump between categories'**
  String get shuffleSongsAndJumpBetweenCategories;

  /// lib/models/shuffle_mode.dart:20
  ///
  /// In en, this message translates to:
  /// **'Shuffle songs in current list'**
  String get shuffleSongsInCurrentList;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'AccurateRip not verified'**
  String get signalAccurateUnverified;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'AccurateRip verified in log'**
  String get signalAccurateVerified;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Alt setting'**
  String get signalAltSetting;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Buffer capacity'**
  String get signalBufferCapacity;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Buffer fill'**
  String get signalBufferFill;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Buffer occupancy at open'**
  String get signalBufferOccupancy;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Buffer target'**
  String get signalBufferTarget;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Copy CRC'**
  String get signalCopyCrc;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Cannot compare'**
  String get signalCrcCannotCompare;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'CRC comparison'**
  String get signalCrcComparison;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get signalCrcMatch;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Mismatch'**
  String get signalCrcMismatch;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Drift from target'**
  String get signalDriftFromTarget;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'DSD bit rate'**
  String get signalDsdBitRate;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'File format'**
  String get signalFileFormat;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Frames / packet'**
  String get signalFramesPerPacket;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Max packet'**
  String get signalMaxPacket;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'No ripping or verification information was found for this track.'**
  String get signalNoRipDescription;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Not reported'**
  String get signalNotReported;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get signalNotVerified;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Rip history unavailable'**
  String get signalRecordingUnavailable;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Information from the rip log, not a stage of the current playback path.'**
  String get signalRipDescription;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Rip provenance'**
  String get signalRipProvenance;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Ripper'**
  String get signalRipper;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Service interval'**
  String get signalServiceInterval;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Snapshot'**
  String get signalSnapshot;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Snapshot at open'**
  String get signalSnapshotAtOpen;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Properties of the source file, not the output sent to the device.'**
  String get signalSourceDescription;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Source format details'**
  String get signalSourceDetails;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Subslot'**
  String get signalSubslot;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Sync type'**
  String get signalSyncType;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'target'**
  String get signalTarget;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Test CRC'**
  String get signalTestCrc;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get signalTransportFormat;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Underruns'**
  String get signalUnderruns;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Usage type'**
  String get signalUsageType;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Transport values available when this sheet opened. This is not a live packet trace.'**
  String get signalUsbDescription;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'URB details are only reported for the direct USB path. No transfer activity is inferred.'**
  String get signalUsbMissingDescription;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'USB transport'**
  String get signalUsbTransport;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'USB transport details unavailable'**
  String get signalUsbUnavailable;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Verification not reported'**
  String get signalVerificationMissing;

  /// lib/features/player/widgets/audio_signal_report.dart
  ///
  /// In en, this message translates to:
  /// **'Verified in log'**
  String get signalVerifiedInLog;

  /// lib/features/settings/screens/network_server_edit_screen.dart:355
  ///
  /// In en, this message translates to:
  /// **'Sign-in Failed — Retry'**
  String get signInFailedRetry;

  /// lib/features/settings/screens/network_server_edit_screen.dart:360
  ///
  /// In en, this message translates to:
  /// **'Sign in with Tidal'**
  String get signInWithTidal;

  /// lib/features/settings/screens/network_server_edit_screen.dart:98
  ///
  /// In en, this message translates to:
  /// **'Sign in with your account · HiFi lossless'**
  String get signInWithYourAccountHifi;

  /// lib/features/settings/screens/network_server_edit_screen.dart:419
  ///
  /// In en, this message translates to:
  /// **'Sign in with your own Tidal account. HiFi lossless (FLAC/ALAC) plays through the bit-perfect engine; HiRes/MQA and Atmos are gated by Tidal and will show an error instead of playing.'**
  String get signInWithYourOwnTidal;

  /// lib/features/settings/screens/network_server_edit_screen.dart:353
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get signedIn;

  /// lib/features/settings/screens/visualizer_settings_screen.dart:95
  ///
  /// In en, this message translates to:
  /// **'Silky smooth Bézier curves — fluid and organic'**
  String get silkySmoothBZierCurvesFluid;

  /// lib/features/artists/screens/artist_detail_screen.dart:730
  ///
  /// In en, this message translates to:
  /// **'Similar Artists'**
  String get similarArtists;

  /// lib/features/player/screens/lyrics_sync_screen.dart:901
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get simple;

  /// lib/features/player/screens/lyrics_sync_screen.dart:653
  ///
  /// In en, this message translates to:
  /// **'Simple mode'**
  String get simpleMode;

  /// lib/features/settings/screens/interface_settings_screen.dart:59
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get simplifiedChinese;

  /// lib/features/settings/screens/equalizer_screen.dart:3628
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// lib/features/settings/screens/orbit_settings_screen.dart:74
  ///
  /// In en, this message translates to:
  /// **'Sizing'**
  String get sizing;

  /// lib/features/onboarding/screens/onboarding_screen.dart:167
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// lib/features/settings/screens/library_settings_screen.dart:1817
  ///
  /// In en, this message translates to:
  /// **'Skip unsupported files and hidden .nomedia directories'**
  String get skipUnsupportedFilesAndHiddenNomedia;

  /// lib/features/albums/screens/album_detail_screen.dart:370
  ///
  /// In en, this message translates to:
  /// **'Sleep timer'**
  String get sleepTimer;

  /// lib/features/player/widgets/sleep_timer_bottom_sheet.dart:55
  ///
  /// In en, this message translates to:
  /// **'Sleep Timer'**
  String get sleepTimer2;

  /// lib/providers/equalizer_provider.dart:64
  ///
  /// In en, this message translates to:
  /// **'Slope'**
  String get slope;

  /// lib/features/settings/screens/network_server_edit_screen.dart:405
  ///
  /// In en, this message translates to:
  /// **'SMB2/3 shares connect through the built-in client. Enter the share URL (smb://host/share) and sign in if the server asks for it.'**
  String get smbSharesCanBeAddedNow;

  /// lib/features/settings/screens/visualizer_settings_screen.dart:177
  ///
  /// In en, this message translates to:
  /// **'Smooth'**
  String get smooth;

  /// lib/features/settings/screens/equalizer_screen.dart:3305
  ///
  /// In en, this message translates to:
  /// **'Smooths peaks and raises body before the limiter catches transients.'**
  String get smoothsPeaksAndRaisesBodyBefore;

  /// lib/features/settings/screens/visualizer_settings_screen.dart:185
  ///
  /// In en, this message translates to:
  /// **'Snappy'**
  String get snappy;

  /// lib/features/settings/screens/orbit_settings_screen.dart:151
  ///
  /// In en, this message translates to:
  /// **'Soft detail, balanced'**
  String get softDetailBalanced;

  /// lib/features/settings/screens/orbit_settings_screen.dart:188
  ///
  /// In en, this message translates to:
  /// **'Soft highlight behind the selected song'**
  String get softHighlightBehindTheSelectedSong;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:1155
  ///
  /// In en, this message translates to:
  /// **'Software (App-controlled)'**
  String get softwareAppControlled;

  /// lib/features/settings/screens/widget_settings_screen.dart:187
  ///
  /// In en, this message translates to:
  /// **'Solid'**
  String get solid;

  /// lib/features/settings/screens/support_flick_screen.dart:136
  ///
  /// In en, this message translates to:
  /// **'Solo Developer'**
  String get soloDeveloper;

  /// lib/widgets/common/offline_notice.dart:185
  ///
  /// In en, this message translates to:
  /// **'  ·  Some online features may not work'**
  String get someOnlineFeaturesMayNotWork;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1702
  ///
  /// In en, this message translates to:
  /// **'Some words are still untimed. Finish capturing in Word Sync mode.'**
  String get someWordsAreStillUntimedFinish;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:190
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// lib/features/playlists/screens/playlists_screen.dart:592
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} song} other{{count} songs}}'**
  String song2(int count);

  /// lib/features/songs/widgets/song_actions_button.dart:29
  ///
  /// In en, this message translates to:
  /// **'Song actions'**
  String get songActions;

  /// lib/features/folders/screens/folders_screen.dart:2594
  ///
  /// In en, this message translates to:
  /// **'Song Artist'**
  String get songArtist;

  /// lib/features/artists/screens/artists_screen.dart:876
  ///
  /// In en, this message translates to:
  /// **'Song Count'**
  String get songCount;

  /// lib/providers/tutorial_provider.dart:33
  ///
  /// In en, this message translates to:
  /// **'Song Gestures'**
  String get songGestures;

  /// lib/features/player/widgets/song_metadata_sheet.dart:42
  ///
  /// In en, this message translates to:
  /// **'Song Metadata'**
  String get songMetadata;

  /// lib/features/folders/screens/folders_screen.dart:2592
  ///
  /// In en, this message translates to:
  /// **'Song Title'**
  String get songTitle;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:115
  ///
  /// In en, this message translates to:
  /// **'Song View: List'**
  String get songViewList;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:103
  ///
  /// In en, this message translates to:
  /// **'Song View: Orbital'**
  String get songViewOrbital;

  /// lib/features/albums/screens/album_detail_screen.dart:666
  ///
  /// In en, this message translates to:
  /// **'{arg1} • {arg2} songs'**
  String songs(Object arg1, Object arg2);

  /// lib/features/search/screens/search_screen.dart:967
  ///
  /// In en, this message translates to:
  /// **'{arg1} songs'**
  String songs12(Object arg1);

  /// lib/features/search/screens/search_screen.dart:1080
  ///
  /// In en, this message translates to:
  /// **'{count} songs'**
  String songs13(Object count);

  /// lib/features/manual/data/manual_data.dart:29
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get songs14;

  /// lib/features/folders/screens/folders_screen.dart:776
  ///
  /// In en, this message translates to:
  /// **'{arg1} songs'**
  String songs15(Object arg1);

  /// lib/features/albums/screens/album_detail_screen.dart:889
  ///
  /// In en, this message translates to:
  /// **'{songCount} songs'**
  String songs2(Object songCount);

  /// lib/features/artists/screens/artist_detail_screen.dart:1058
  ///
  /// In en, this message translates to:
  /// **'{arg1} songs'**
  String songs3(Object arg1);

  /// lib/features/artists/screens/artists_screen.dart:396
  ///
  /// In en, this message translates to:
  /// **'{_totalSongs} songs'**
  String songs4(Object _totalSongs);

  /// lib/features/folders/screens/folders_screen.dart:1617
  ///
  /// In en, this message translates to:
  /// **'{arg1} songs'**
  String songs5(Object arg1);

  /// lib/features/player/widgets/add_to_playlist_sheet.dart:124
  ///
  /// In en, this message translates to:
  /// **'{arg1} songs'**
  String songs9(Object arg1);

  /// lib/features/albums/screens/album_detail_screen.dart:1010
  ///
  /// In en, this message translates to:
  /// **'{arg1} songs • {uniqueAlbums} albums'**
  String songsAlbums(Object arg1, Object uniqueAlbums);

  /// lib/features/search/screens/search_screen.dart:850
  ///
  /// In en, this message translates to:
  /// **'{arg1} songs · {albumCount} albums'**
  String songsAlbums2(Object arg1, Object albumCount);

  /// lib/features/settings/screens/queue_settings_screen.dart:50
  ///
  /// In en, this message translates to:
  /// **'Songs before the tapped track queue at the end'**
  String get songsBeforeTheTappedTrackQueue;

  /// lib/models/shuffle_mode.dart:13
  ///
  /// In en, this message translates to:
  /// **'Songs & Categories'**
  String get songsCategories;

  /// lib/features/settings/screens/network_sources_screen.dart:406
  ///
  /// In en, this message translates to:
  /// **'{arg1} songs found'**
  String songsFound(Object arg1);

  /// lib/features/settings/screens/library_settings_screen.dart:1600
  ///
  /// In en, this message translates to:
  /// **'{songs, plural, =1{{songs} song} other{{songs} songs}} in {folders, plural, =1{{folders} folder} other{{folders} folders}}'**
  String songsIn(int songs, int folders);

  /// lib/providers/tutorial_provider.dart:16
  ///
  /// In en, this message translates to:
  /// **'Songs Tab'**
  String get songsTab;

  /// lib/features/artists/screens/artists_screen.dart:675
  ///
  /// In en, this message translates to:
  /// **'{arg1} songs • {uniqueAlbums} albums'**
  String songsU2022Albums(Object arg1, Object uniqueAlbums);

  /// lib/features/recently_played/screens/recently_played_screen.dart:354
  ///
  /// In en, this message translates to:
  /// **'Songs you play will appear here'**
  String get songsYouPlayWillAppearHere;

  /// lib/features/recently_added/screens/recently_added_screen.dart:326
  ///
  /// In en, this message translates to:
  /// **'Songs you scan into your library will show up here'**
  String get songsYouScanIntoYourLibrary;

  /// lib/features/songs/screens/songs_screen.dart:2878
  ///
  /// In en, this message translates to:
  /// **'SORT BY'**
  String get sortBy;

  /// lib/providers/tutorial_provider.dart:27
  ///
  /// In en, this message translates to:
  /// **'Sort & Filter'**
  String get sortFilter;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:718
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:568
  ///
  /// In en, this message translates to:
  /// **'Source rate'**
  String get sourceRate;

  /// lib/features/settings/widgets/mini_player_customization.dart:102
  ///
  /// In en, this message translates to:
  /// **'Space between the two bars'**
  String get spaceBetweenTheTwoBars;

  /// lib/models/song.dart:326
  ///
  /// In en, this message translates to:
  /// **'Space Odyssey'**
  String get spaceOdyssey;

  /// lib/features/settings/screens/equalizer_screen.dart:3548
  ///
  /// In en, this message translates to:
  /// **'Spatial & Time'**
  String get spatialTime;

  /// lib/features/settings/screens/visualizer_settings_screen.dart:170
  ///
  /// In en, this message translates to:
  /// **'Spring physics — energetic and reactive'**
  String get springPhysicsEnergeticAndReactive;

  /// lib/features/settings/screens/audio_settings_screen.dart:247
  ///
  /// In en, this message translates to:
  /// **'Square Root'**
  String get squareRoot;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1202
  ///
  /// In en, this message translates to:
  /// **'Stamp & Next'**
  String get stampNext;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1202
  ///
  /// In en, this message translates to:
  /// **'Stamp Now'**
  String get stampNow;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1695
  ///
  /// In en, this message translates to:
  /// **'Stamp this line first to edit its word timeline.'**
  String get stampThisLineFirstToEdit;

  /// lib/features/settings/screens/interface_settings_screen.dart:223
  ///
  /// In en, this message translates to:
  /// **'Standard (60Hz)'**
  String get standard60hz;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:420
  ///
  /// In en, this message translates to:
  /// **'Standard Bluetooth routing via Android'**
  String get standardBluetoothRoutingViaAndroid;

  /// lib/models/song.dart:321
  ///
  /// In en, this message translates to:
  /// **'Starlight Serenade'**
  String get starlightSerenade;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1816
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1871
  ///
  /// In en, this message translates to:
  /// **'Start at Now'**
  String get startAtNow;

  /// lib/widgets/uac2/uac2_stream_config.dart:207
  ///
  /// In en, this message translates to:
  /// **'Start Streaming'**
  String get startStreaming;

  /// lib/features/settings/screens/equalizer_screen.dart:634
  ///
  /// In en, this message translates to:
  /// **'Started preset download.'**
  String get startedPresetDownload;

  /// lib/widgets/uac2/uac2_connection_manager.dart:152
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get state;

  /// lib/features/settings/screens/uac2_settings_screen.dart:87
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// lib/features/settings/screens/app_info_settings_screen.dart:694
  ///
  /// In en, this message translates to:
  /// **'Step-by-step walkthrough of the app'**
  String get stepByStepWalkthroughOfThe;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:621
  ///
  /// In en, this message translates to:
  /// **'Stereo'**
  String get stereo;

  /// lib/features/settings/screens/library_settings_screen.dart:1399
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// lib/features/settings/screens/queue_settings_screen.dart:51
  ///
  /// In en, this message translates to:
  /// **'Stop at the end of the current list'**
  String get stopAtTheEndOfThe;

  /// lib/features/settings/screens/casting_settings_screen.dart:112
  ///
  /// In en, this message translates to:
  /// **'Stop Casting'**
  String get stopCasting;

  /// lib/widgets/uac2/uac2_stream_config.dart:207
  ///
  /// In en, this message translates to:
  /// **'Stop Streaming'**
  String get stopStreaming;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:539
  ///
  /// In en, this message translates to:
  /// **'Stop USB on Quit'**
  String get stopUsbOnQuit;

  /// lib/features/settings/screens/queue_settings_screen.dart:76
  ///
  /// In en, this message translates to:
  /// **'Stop when the queue ends'**
  String get stopWhenTheQueueEnds;

  /// lib/features/player/widgets/sleep_timer_bottom_sheet.dart:113
  ///
  /// In en, this message translates to:
  /// **'Stopping in {arg1}'**
  String stoppingIn(Object arg1);

  /// lib/features/settings/screens/library_settings_screen.dart:2157
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storage;

  /// lib/features/settings/screens/privacy_policy_screen.dart:51
  ///
  /// In en, this message translates to:
  /// **'Storage access is required to scan and read music files, extract metadata, import/export EQ presets, and save recap images. All processing happens on-device.'**
  String get storageAccessIsRequiredToScan;

  /// lib/features/settings/screens/library_settings_screen.dart:461
  ///
  /// In en, this message translates to:
  /// **'Storage permission is required to add music folders'**
  String get storagePermissionIsRequiredToAdd;

  /// lib/features/settings/screens/privacy_policy_screen.dart:49
  ///
  /// In en, this message translates to:
  /// **'Storage Permissions'**
  String get storagePermissions;

  /// lib/features/settings/screens/network_server_edit_screen.dart:61
  ///
  /// In en, this message translates to:
  /// **'Stored as a salted hash, never in plaintext'**
  String get storedAsASaltedHashNever;

  /// lib/features/settings/screens/network_server_edit_screen.dart:93
  ///
  /// In en, this message translates to:
  /// **'Stored base64-encoded — required for NTLM sign-in'**
  String get storedEncodedPlaybackUnavailableInThis;

  /// lib/models/song.dart:376
  ///
  /// In en, this message translates to:
  /// **'Storm Chasers'**
  String get stormChasers;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:633
  ///
  /// In en, this message translates to:
  /// **'Strategy'**
  String get strategy;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:1035
  ///
  /// In en, this message translates to:
  /// **'Stream'**
  String get stream;

  /// lib/widgets/uac2/uac2_stream_config.dart:57
  ///
  /// In en, this message translates to:
  /// **'Stream configuration not available'**
  String get streamConfigurationNotAvailable;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:694
  ///
  /// In en, this message translates to:
  /// **'Stream stable'**
  String get streamStable;

  /// lib/features/settings/screens/uac2_settings_screen.dart:907
  ///
  /// In en, this message translates to:
  /// **'Streaming'**
  String get streaming;

  /// lib/features/settings/screens/library_settings_screen.dart:2195
  ///
  /// In en, this message translates to:
  /// **'Stretch Non-Square Art'**
  String get stretchNonSquareArt;

  /// lib/features/settings/widgets/mini_player_customization.dart:221
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get strong;

  /// lib/features/settings/screens/equalizer_screen.dart:1887
  ///
  /// In en, this message translates to:
  /// **'Sub'**
  String get sub;

  /// lib/features/folders/screens/folders_screen.dart:2033
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} subfolder} other{{count} subfolders}}'**
  String subfolderCount(int count);

  /// lib/features/settings/screens/network_server_edit_screen.dart:57
  ///
  /// In en, this message translates to:
  /// **'Subsonic'**
  String get subsonic;

  /// lib/features/settings/screens/settings_screen.dart:94
  ///
  /// In en, this message translates to:
  /// **'Subsonic servers, sync, and streaming'**
  String get subsonicServersSyncAndStreaming;

  /// lib/models/album_color_mode.dart:22
  ///
  /// In en, this message translates to:
  /// **'Subtle'**
  String get subtle;

  /// lib/features/settings/screens/app_info_settings_screen.dart:703
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// lib/features/settings/screens/support_flick_screen.dart:213
  ///
  /// In en, this message translates to:
  /// **'Support development on Ko-fi'**
  String get supportDevelopmentOnKoFi;

  /// lib/features/menu/screens/menu_screen.dart:367
  ///
  /// In en, this message translates to:
  /// **'Support Flick'**
  String get supportFlick;

  /// lib/features/settings/screens/lyrics_settings_screen.dart:45
  ///
  /// In en, this message translates to:
  /// **'Sweep a highlight through words as they are sung'**
  String get sweepAHighlightThroughWordsAs;

  /// lib/features/settings/screens/interface_settings_screen.dart:294
  ///
  /// In en, this message translates to:
  /// **'Swipe'**
  String get swipe;

  /// lib/features/settings/screens/interface_settings_screen.dart:125
  ///
  /// In en, this message translates to:
  /// **'Swipe Actions'**
  String get swipeActions;

  /// lib/features/settings/screens/equalizer_screen.dart:1823
  ///
  /// In en, this message translates to:
  /// **'Swipe horizontally to fine-tune each center band.'**
  String get swipeHorizontallyToFineTuneEach;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:49
  ///
  /// In en, this message translates to:
  /// **'Swipe left/right to skip tracks'**
  String get swipeLeftRightToSkipTracks;

  /// lib/features/settings/screens/interface_settings_screen.dart:295
  ///
  /// In en, this message translates to:
  /// **'Swipe left to unfavorite a song'**
  String get swipeLeftToUnfavoriteASong;

  /// lib/features/settings/screens/interface_settings_screen.dart:126
  ///
  /// In en, this message translates to:
  /// **'Swipe songs left to queue or right to favorite'**
  String get swipeSongsLeftToQueueOr;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:37
  ///
  /// In en, this message translates to:
  /// **'Swipe to show or hide the visualizer'**
  String get swipeToShowOrHideThe;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:48
  ///
  /// In en, this message translates to:
  /// **'Switch Songs'**
  String get switchSongs;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:493
  ///
  /// In en, this message translates to:
  /// **'Switch to the exclusive USB path automatically when a DAC is attached. Declined DACs are remembered.'**
  String get switchToTheExclusiveUsbPath;

  /// lib/features/player/widgets/inline_lyrics_panel.dart:151
  ///
  /// In en, this message translates to:
  /// **'Switched back to the automatic lyrics source.'**
  String get switchedBackToTheAutomaticLyrics;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1908
  ///
  /// In en, this message translates to:
  /// **'Syllables — tap a letter to split or merge:'**
  String get syllablesTapALetterToSplit;

  /// lib/features/settings/screens/visualizer_settings_screen.dart:104
  ///
  /// In en, this message translates to:
  /// **'Symmetrical bars mirrored from the center'**
  String get symmetricalBarsMirroredFromTheCenter;

  /// lib/features/settings/screens/network_sources_screen.dart:112
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {e}'**
  String syncFailed(Object e);

  /// lib/features/settings/screens/network_sources_screen.dart:285
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// lib/features/player/widgets/online_lyrics_search_sheet.dart:568
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get synced;

  /// lib/features/settings/screens/network_sources_screen.dart:318
  ///
  /// In en, this message translates to:
  /// **'Synced {arg1}'**
  String synced2(Object arg1);

  /// lib/features/player/widgets/online_lyrics_search_sheet.dart:377
  ///
  /// In en, this message translates to:
  /// **'Synced LRC'**
  String get syncedLrc;

  /// lib/features/settings/screens/network_sources_screen.dart:365
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncing;

  /// lib/models/song.dart:308
  ///
  /// In en, this message translates to:
  /// **'Synthwave City'**
  String get synthwaveCity;

  /// lib/features/settings/screens/casting_settings_screen.dart:243
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:1151
  ///
  /// In en, this message translates to:
  /// **'System (Android mixer)'**
  String get systemAndroidMixer;

  /// lib/services/metadata_editor_service.dart:131
  ///
  /// In en, this message translates to:
  /// **'Tags were written but could not be confirmed by re-reading the file. A library rescan will reconcile any difference.'**
  String get tagsWereWrittenButCouldNot;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1393
  ///
  /// In en, this message translates to:
  /// **'Tap: \"{label}\"'**
  String tap(Object label);

  /// lib/features/settings/screens/equalizer_screen.dart:2242
  ///
  /// In en, this message translates to:
  /// **'Tap a band to expand. Drag a knob to adjust. Tap a value to type directly.'**
  String get tapABandToExpandDrag;

  /// lib/features/search/screens/search_screen.dart:324
  ///
  /// In en, this message translates to:
  /// **'Tap All or enable a chip to see results'**
  String get tapAllOrEnableAChip;

  /// lib/features/search/screens/search_screen.dart:258
  ///
  /// In en, this message translates to:
  /// **'Tap chips to filter categories'**
  String get tapChipsToFilterCategories;

  /// lib/features/player/screens/lyrics_sync_screen.dart:661
  ///
  /// In en, this message translates to:
  /// **'1. Tap \"Edit Text\" (top right) and paste the lyrics — one line per row.\n2. Play the song.\n3. Pick the current line in the Lines list.\n4. Tap \"Stamp & Next\" when you hear that line.\n5. Save when done.'**
  String get tapEditTextTopRight;

  /// lib/providers/tutorial_provider.dart:12
  ///
  /// In en, this message translates to:
  /// **'Tap icons to switch tabs. Long-press to customize the bar.'**
  String get tapIconsToSwitchTabsLong;

  /// lib/features/favorites/screens/favorites_screen.dart:361
  ///
  /// In en, this message translates to:
  /// **'Tap the heart icon on any song\nto add it to your favorites'**
  String get tapTheHeartIconOnAny;

  /// lib/providers/tutorial_provider.dart:50
  ///
  /// In en, this message translates to:
  /// **'Tap the mini player for waveform seekbar, EQ, lyrics, and visualizer.'**
  String get tapTheMiniPlayerForWaveform;

  /// lib/providers/tutorial_provider.dart:34
  ///
  /// In en, this message translates to:
  /// **'Tap to play, long-press for options (queue, play next, info).'**
  String get tapToPlayLongPressFor;

  /// lib/features/player/widgets/online_lyrics_search_sheet.dart:955
  ///
  /// In en, this message translates to:
  /// **'Tap to preview'**
  String get tapToPreview;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:1028
  ///
  /// In en, this message translates to:
  /// **'target {arg1} ms'**
  String targetMs(Object arg1);

  /// lib/features/settings/screens/equalizer_screen.dart:3576
  ///
  /// In en, this message translates to:
  /// **'Tempo'**
  String get tempo;

  /// lib/features/settings/screens/equalizer_screen.dart:3519
  ///
  /// In en, this message translates to:
  /// **'Tempo {arg1}x'**
  String tempoX(Object arg1);

  /// lib/features/player/widgets/bit_perfect_indicator.dart:1096
  ///
  /// In en, this message translates to:
  /// **'Test: {arg1}'**
  String test(Object arg1);

  /// lib/features/settings/screens/network_server_edit_screen.dart:360
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get testConnection;

  /// lib/features/settings/widgets/mini_player_customization.dart:229
  ///
  /// In en, this message translates to:
  /// **'Text & Gestures'**
  String get textGestures;

  /// lib/features/player/widgets/player_layout_sheet.dart:293
  ///
  /// In en, this message translates to:
  /// **'Text placement'**
  String get textPlacement;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:148
  ///
  /// In en, this message translates to:
  /// **'Text Placement'**
  String get textPlacement2;

  /// lib/features/player/widgets/player_layout_sheet.dart:218
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize;

  /// lib/features/settings/screens/player_layout_settings_screen.dart:132
  ///
  /// In en, this message translates to:
  /// **'Text Size'**
  String get textSize2;

  /// lib/providers/tutorial_provider.dart:53
  ///
  /// In en, this message translates to:
  /// **'That\'s the tour!'**
  String get thatSTheTour;

  /// lib/features/settings/screens/privacy_policy_screen.dart:81
  ///
  /// In en, this message translates to:
  /// **'The app does not knowingly collect any information from anyone, regardless of age.'**
  String get theAppDoesNotKnowinglyCollect;

  /// lib/features/settings/screens/privacy_policy_screen.dart:66
  ///
  /// In en, this message translates to:
  /// **'The app queries public APIs (MusicBrainz/Cover Art Archive, iTunes, Deezer) to find matching album art. Search queries use local music metadata. Downloaded images are cached locally.'**
  String get theAppQueriesPublicApisMusicbrainz;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:541
  ///
  /// In en, this message translates to:
  /// **'The Isochronous USB engine will be stopped when the app quits.'**
  String get theIsochronousUsbEngineWillBe;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:542
  ///
  /// In en, this message translates to:
  /// **'The Isochronous USB engine will stay alive when the app quits.'**
  String get theIsochronousUsbEngineWillStay;

  /// lib/features/settings/screens/interface_settings_screen.dart:22
  ///
  /// In en, this message translates to:
  /// **'This clears your current day streak and any unlocked streak milestones. This cannot be undone.'**
  String get thisClearsYourCurrentDayStreak;

  /// lib/features/folders/screens/folders_screen.dart:1370
  ///
  /// In en, this message translates to:
  /// **'This folder appears to be empty'**
  String get thisFolderAppearsToBeEmpty;

  /// lib/data/repositories/recently_played_repository.dart:294
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonth;

  /// lib/data/repositories/recently_played_repository.dart:25
  ///
  /// In en, this message translates to:
  /// **'This Month\'s Recap'**
  String get thisMonthSRecap;

  /// lib/features/settings/screens/logs_screen.dart:232
  ///
  /// In en, this message translates to:
  /// **'This removes all {arg1} entries from memory.'**
  String thisRemovesAllEntriesFromMemory(Object arg1);

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1586
  ///
  /// In en, this message translates to:
  /// **'This slows playback to 432/440 (~1.8% lower pitch and tempo) and disables bit-perfect passthrough. Music will sound slightly lower in tone. Only enable this if you intentionally want A=432 tuning.'**
  String get thisSlowsPlaybackTo432440;

  /// lib/services/metadata_editor_service.dart:61
  ///
  /// In en, this message translates to:
  /// **'This song has no file path and cannot be edited.'**
  String get thisSongHasNoFilePath;

  /// lib/features/songs/widgets/album_art_picker_bottom_sheet.dart:491
  ///
  /// In en, this message translates to:
  /// **'This song is missing album metadata, so online matching is limited.'**
  String get thisSongIsMissingAlbumMetadata;

  /// lib/features/songs/widgets/album_art_picker_bottom_sheet.dart:412
  ///
  /// In en, this message translates to:
  /// **'This song only'**
  String get thisSongOnly;

  /// lib/data/repositories/recently_played_repository.dart:288
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// lib/data/repositories/recently_played_repository.dart:24
  ///
  /// In en, this message translates to:
  /// **'This Week\'s Recap'**
  String get thisWeekSRecap;

  /// lib/data/repositories/recently_played_repository.dart:26
  ///
  /// In en, this message translates to:
  /// **'This Year\'s Recap'**
  String get thisYearSRecap;

  /// lib/features/settings/screens/equalizer_screen.dart:3318
  ///
  /// In en, this message translates to:
  /// **'Threshold'**
  String get threshold;

  /// lib/models/song.dart:375
  ///
  /// In en, this message translates to:
  /// **'Thunder Road'**
  String get thunderRoad;

  /// lib/features/settings/screens/network_server_edit_screen.dart:97
  ///
  /// In en, this message translates to:
  /// **'Tidal'**
  String get tidal;

  /// lib/features/settings/screens/library_settings_screen.dart:1030
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1979
  ///
  /// In en, this message translates to:
  /// **'Time Shift'**
  String get timeShift;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1315
  ///
  /// In en, this message translates to:
  /// **'Timestamp'**
  String get timestamp;

  /// lib/features/player/screens/lyrics_sync_screen.dart:704
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get tips;

  /// lib/features/player/widgets/song_metadata_sheet.dart:53
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:636
  ///
  /// In en, this message translates to:
  /// **'To remove'**
  String get toRemove;

  /// lib/data/repositories/recently_played_repository.dart:283
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// lib/data/repositories/recently_played_repository.dart:23
  ///
  /// In en, this message translates to:
  /// **'Today\'s Recap'**
  String get todaySRecap;

  /// lib/features/settings/screens/equalizer_screen.dart:1632
  ///
  /// In en, this message translates to:
  /// **'Tone Controls'**
  String get toneControls;

  /// lib/features/player/screens/lyrics_sync_screen.dart:870
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tools;

  /// lib/features/recap/screens/listening_recap_screen.dart:456
  ///
  /// In en, this message translates to:
  /// **'Top Songs'**
  String get topSongs;

  /// lib/features/settings/screens/library_settings_screen.dart:1333
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// lib/features/settings/screens/audio_settings_screen.dart:197
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get track;

  /// lib/features/player/widgets/share/share_cards/album_art_share_card.dart:45
  ///
  /// In en, this message translates to:
  /// **'Track {arg1}'**
  String track2(Object arg1);

  /// lib/features/songs/screens/metadata_editor_screen.dart:284
  ///
  /// In en, this message translates to:
  /// **'Track #'**
  String get track3;

  /// lib/features/settings/screens/uac2_settings_screen.dart:648
  ///
  /// In en, this message translates to:
  /// **'Track Bit Depth'**
  String get trackBitDepth;

  /// lib/features/settings/screens/uac2_settings_screen.dart:655
  ///
  /// In en, this message translates to:
  /// **'Track Channels'**
  String get trackChannels;

  /// lib/features/settings/screens/interface_settings_screen.dart:162
  ///
  /// In en, this message translates to:
  /// **'Track consecutive listening days and show the popup'**
  String get trackConsecutiveListeningDaysAndShow;

  /// lib/features/albums/screens/albums_screen.dart:920
  ///
  /// In en, this message translates to:
  /// **'Track Count'**
  String get trackCount;

  /// lib/features/settings/screens/uac2_settings_screen.dart:641
  ///
  /// In en, this message translates to:
  /// **'Track DSD Rate'**
  String get trackDsdRate;

  /// lib/models/song_tile_thumbnail_mode.dart:20
  ///
  /// In en, this message translates to:
  /// **'Track Number'**
  String get trackNumber;

  /// lib/features/settings/screens/uac2_settings_screen.dart:641
  ///
  /// In en, this message translates to:
  /// **'Track Sample Rate'**
  String get trackSampleRate;

  /// lib/features/settings/screens/ui_customization_settings_screen.dart:204
  ///
  /// In en, this message translates to:
  /// **'Track Thumbnails'**
  String get trackThumbnails;

  /// lib/features/albums/screens/albums_screen.dart:366
  ///
  /// In en, this message translates to:
  /// **'{_totalTracks} tracks'**
  String tracks(Object _totalTracks);

  /// lib/features/albums/screens/albums_screen.dart:704
  ///
  /// In en, this message translates to:
  /// **'{arg1} tracks'**
  String tracks2(Object arg1);

  /// lib/features/folders/screens/folders_screen.dart:739
  ///
  /// In en, this message translates to:
  /// **'{arg1} tracks'**
  String tracks3(Object arg1);

  /// lib/features/folders/screens/folders_screen.dart:1581
  ///
  /// In en, this message translates to:
  /// **'{arg1} tracks'**
  String tracks4(Object arg1);

  /// lib/features/search/screens/search_screen.dart:915
  ///
  /// In en, this message translates to:
  /// **'{arg1} · {arg2} tracks'**
  String tracks5(Object arg1, Object arg2);

  /// lib/features/songs/screens/songs_screen.dart:2608
  ///
  /// In en, this message translates to:
  /// **'{arg1} tracks'**
  String tracks6(Object arg1);

  /// lib/features/songs/screens/songs_screen.dart:2784
  ///
  /// In en, this message translates to:
  /// **'{trackCount} tracks • {arg1}'**
  String tracks7(Object trackCount, Object arg1);

  /// lib/features/albums/widgets/identify_album_sheet.dart:458
  ///
  /// In en, this message translates to:
  /// **'{arg1} tracks'**
  String tracks8(Object arg1);

  /// lib/features/settings/screens/widget_settings_screen.dart:159
  ///
  /// In en, this message translates to:
  /// **'Transparent'**
  String get transparent;

  /// lib/features/settings/screens/equalizer_screen.dart:1695
  ///
  /// In en, this message translates to:
  /// **'Treble'**
  String get treble;

  /// lib/models/shuffle_mode.dart:23
  ///
  /// In en, this message translates to:
  /// **'True random (may repeat before list ends)'**
  String get trueRandomMayRepeatBeforeList;

  /// lib/features/settings/widgets/mini_player_customization.dart:247
  ///
  /// In en, this message translates to:
  /// **'Truncate'**
  String get truncate;

  /// lib/features/songs/screens/songs_screen.dart:1855
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your search query'**
  String get tryAdjustingYourSearchQuery;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:213
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// lib/features/search/screens/search_screen.dart:291
  ///
  /// In en, this message translates to:
  /// **'Try another keyword or enable more categories'**
  String get tryAnotherKeywordOrEnableMore;

  /// lib/features/player/widgets/online_lyrics_search_sheet.dart:782
  ///
  /// In en, this message translates to:
  /// **'Try original search'**
  String get tryOriginalSearch;

  /// lib/features/songs/widgets/album_art_picker_bottom_sheet.dart:492
  ///
  /// In en, this message translates to:
  /// **'Try picking a local image if the release metadata is uncommon.'**
  String get tryPickingALocalImageIf;

  /// lib/features/settings/screens/audio_settings_screen.dart:307
  ///
  /// In en, this message translates to:
  /// **'Turn off 432 Hz tuning to use crossfade'**
  String get turnOff432HzTuningTo;

  /// lib/features/settings/screens/audio_settings_screen.dart:421
  ///
  /// In en, this message translates to:
  /// **'Turn off 432 Hz tuning to use crossfeed'**
  String get turnOff432HzTuningTo2;

  /// lib/features/settings/screens/widgets/autoeq_search_sheet.dart:94
  ///
  /// In en, this message translates to:
  /// **'Type a brand and model to search online.'**
  String get typeABrandAndModelTo;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1735
  ///
  /// In en, this message translates to:
  /// **'U16 — 2-byte subslots, LL|RR'**
  String get u162ByteSubslotsLlRr;

  /// lib/features/settings/screens/equalizer_screen.dart:2415
  ///
  /// In en, this message translates to:
  /// **'{arg1}  •  {valueLabel}'**
  String u2022(Object arg1, Object valueLabel);

  /// lib/features/settings/screens/equalizer_screen.dart:2380
  ///
  /// In en, this message translates to:
  /// **'{arg1}  •  {gainLabel}'**
  String u20223(Object arg1, Object gainLabel);

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:524
  ///
  /// In en, this message translates to:
  /// **' • {arg1}-bit'**
  String u2022Bit(Object arg1);

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1733
  ///
  /// In en, this message translates to:
  /// **'U32 — 4-byte subslots, LLLL|RRRR (legacy)'**
  String get u324ByteSubslotsLlllRrrr;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1737
  ///
  /// In en, this message translates to:
  /// **'U8 — byte-interleaved LRLR'**
  String get u8ByteInterleavedLrlr;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1758
  ///
  /// In en, this message translates to:
  /// **'U8 — byte-interleaved, recommended default'**
  String get u8ByteInterleavedRecommendedDefault;

  /// lib/features/settings/screens/settings_screen.dart:138
  ///
  /// In en, this message translates to:
  /// **'UAC2 and equalizer'**
  String get uac2AndEqualizer;

  /// lib/features/settings/screens/uac2_settings_screen.dart:189
  ///
  /// In en, this message translates to:
  /// **'UAC2 is not available on this platform'**
  String get uac2IsNotAvailableOnThis;

  /// lib/widgets/uac2/uac2_device_selector.dart:20
  ///
  /// In en, this message translates to:
  /// **'UAC2 not available on this platform'**
  String get uac2NotAvailableOnThisPlatform;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:162
  ///
  /// In en, this message translates to:
  /// **'UAC2 Preferences'**
  String get uac2Preferences;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1456
  ///
  /// In en, this message translates to:
  /// **'UAC2 preferences reset successfully'**
  String get uac2PreferencesResetSuccessfully;

  /// lib/features/settings/screens/settings_screen.dart:198
  ///
  /// In en, this message translates to:
  /// **'UI Customization'**
  String get uiCustomization;

  /// lib/features/settings/screens/orbit_settings_screen.dart:166
  ///
  /// In en, this message translates to:
  /// **'Ultra'**
  String get ultra;

  /// lib/providers/update_check_provider.dart:177
  ///
  /// In en, this message translates to:
  /// **'Unable to check for updates right now.'**
  String get unableToCheckForUpdatesRight;

  /// lib/features/settings/screens/app_info_settings_screen.dart:300
  ///
  /// In en, this message translates to:
  /// **'Unable to load patch notes right now.'**
  String get unableToLoadPatchNotesRight;

  /// lib/features/settings/screens/library_settings_screen.dart:220
  ///
  /// In en, this message translates to:
  /// **'Unable to open All Files Access settings'**
  String get unableToOpenAllFilesAccess;

  /// lib/features/settings/screens/library_settings_screen.dart:199
  ///
  /// In en, this message translates to:
  /// **'Unable to open battery optimization settings'**
  String get unableToOpenBatteryOptimizationSettings;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1473
  ///
  /// In en, this message translates to:
  /// **'{featureName} Unavailable'**
  String unavailable(Object featureName);

  /// lib/features/player/widgets/bit_perfect_indicator.dart:1157
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable2;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:1037
  ///
  /// In en, this message translates to:
  /// **'{arg1} underruns'**
  String underruns(Object arg1);

  /// lib/features/favorites/screens/favorites_screen.dart:63
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// lib/features/favorites/screens/favorites_screen.dart:173
  ///
  /// In en, this message translates to:
  /// **'Unfavorite'**
  String get unfavorite;

  /// lib/features/favorites/screens/favorites_screen.dart:273
  ///
  /// In en, this message translates to:
  /// **'Unfavorite selected'**
  String get unfavoriteSelected;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:486
  ///
  /// In en, this message translates to:
  /// **'Universal compatibility'**
  String get universalCompatibility;

  /// lib/features/albums/screens/album_detail_screen.dart:950
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// lib/data/repositories/recently_played_repository.dart:588
  ///
  /// In en, this message translates to:
  /// **'Unknown Album'**
  String get unknownAlbum;

  /// lib/data/repositories/recently_played_repository.dart:578
  ///
  /// In en, this message translates to:
  /// **'Unknown Artist'**
  String get unknownArtist;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:1015
  ///
  /// In en, this message translates to:
  /// **'Unknown bitrate'**
  String get unknownBitrate;

  /// lib/features/search/providers/global_search_provider.dart:106
  ///
  /// In en, this message translates to:
  /// **'Unknown Folder'**
  String get unknownFolder;

  /// lib/services/playlist_service.dart:688
  ///
  /// In en, this message translates to:
  /// **'Unknown Title'**
  String get unknownTitle;

  /// lib/features/player/widgets/online_lyrics_search_sheet.dart:1051
  ///
  /// In en, this message translates to:
  /// **'Unknown Track'**
  String get unknownTrack;

  /// lib/features/settings/screens/settings_screen.dart:255
  ///
  /// In en, this message translates to:
  /// **'{_milestonesUnlocked} / {arg1} unlocked'**
  String unlocked3(Object _milestonesUnlocked, Object arg1);

  /// lib/widgets/uac2/iso_volume_popup.dart:260
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// lib/features/settings/screens/uac2_settings_screen.dart:678
  ///
  /// In en, this message translates to:
  /// **'Unreported'**
  String get unreported;

  /// lib/features/player/screens/lyrics_sync_screen.dart:586
  ///
  /// In en, this message translates to:
  /// **'Unsaved Changes'**
  String get unsavedChanges;

  /// lib/features/player/widgets/player_layout_sheet.dart:566
  ///
  /// In en, this message translates to:
  /// **'{arg1} up'**
  String up(Object arg1);

  /// lib/features/menu/screens/menu_screen.dart:1226
  ///
  /// In en, this message translates to:
  /// **'Update Available'**
  String get updateAvailable;

  /// lib/features/settings/screens/app_info_settings_screen.dart:87
  ///
  /// In en, this message translates to:
  /// **'Update available — download from flick-player.site'**
  String get updateAvailableDownloadFromFlickPlayer;

  /// lib/features/settings/screens/app_info_settings_screen.dart:85
  ///
  /// In en, this message translates to:
  /// **'Update available on the Play Store.'**
  String get updateAvailableOnThePlayStore;

  /// lib/features/songs/widgets/album_art_picker_bottom_sheet.dart:150
  ///
  /// In en, this message translates to:
  /// **'Updated album art for \"{arg1}\".'**
  String updatedAlbumArtFor(Object arg1);

  /// lib/features/songs/widgets/album_art_picker_bottom_sheet.dart:151
  ///
  /// In en, this message translates to:
  /// **'Updated album art for \"{arg1}\".'**
  String updatedAlbumArtFor2(Object arg1);

  /// lib/features/settings/screens/app_info_settings_screen.dart:602
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updates;

  /// lib/features/settings/screens/settings_screen.dart:267
  ///
  /// In en, this message translates to:
  /// **'Updates, about, and support'**
  String get updatesAboutAndSupport;

  /// lib/features/settings/screens/logs_screen.dart:132
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// lib/features/settings/screens/logs_screen.dart:156
  ///
  /// In en, this message translates to:
  /// **'Upload failed ({arg1}).'**
  String uploadFailed(Object arg1);

  /// lib/features/settings/screens/logs_screen.dart:159
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {e}'**
  String uploadFailed2(Object e);

  /// lib/features/settings/screens/logs_screen.dart:128
  ///
  /// In en, this message translates to:
  /// **'Upload logs as a link?'**
  String get uploadLogsAsALink;

  /// lib/features/settings/screens/network_server_edit_screen.dart:81
  ///
  /// In en, this message translates to:
  /// **'UPnP / DLNA'**
  String get upnpDlna;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:1010
  ///
  /// In en, this message translates to:
  /// **'URB Packet'**
  String get urbPacket;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:867
  ///
  /// In en, this message translates to:
  /// **'URB Transfer'**
  String get urbTransfer;

  /// lib/models/song.dart:330
  ///
  /// In en, this message translates to:
  /// **'Urban Echoes'**
  String get urbanEchoes;

  /// lib/features/settings/screens/privacy_policy_screen.dart:56
  ///
  /// In en, this message translates to:
  /// **'USB Audio Class 2.0 devices (external DACs/AMPs) are accessed locally for bit-perfect audio playback. No USB device information is transmitted externally.'**
  String get usbAudioClass20Devices;

  /// lib/widgets/uac2/uac2_device_selector.dart:36
  ///
  /// In en, this message translates to:
  /// **'USB Audio Device'**
  String get usbAudioDevice;

  /// lib/features/settings/screens/uac2_settings_screen.dart:66
  ///
  /// In en, this message translates to:
  /// **'USB Audio Devices'**
  String get usbAudioDevices;

  /// lib/widgets/uac2/uac2_error_notification.dart:55
  ///
  /// In en, this message translates to:
  /// **'USB Audio Error'**
  String get usbAudioError;

  /// lib/features/settings/screens/audio_settings_screen.dart:49
  ///
  /// In en, this message translates to:
  /// **'USB Audio (UAC2)'**
  String get usbAudioUac2;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:522
  ///
  /// In en, this message translates to:
  /// **'USB DAC auto bit-perfect offers reset.'**
  String get usbDacAutoBitPerfectOffers;

  /// lib/features/settings/screens/support_flick_screen.dart:175
  ///
  /// In en, this message translates to:
  /// **'USB DACs, headphones, and reference gear to test and improve playback quality.'**
  String get usbDacsHeadphonesAndReferenceGear;

  /// lib/features/settings/screens/privacy_policy_screen.dart:54
  ///
  /// In en, this message translates to:
  /// **'USB Device Access'**
  String get usbDeviceAccess;

  /// lib/features/folders/screens/folders_screen.dart:781
  ///
  /// In en, this message translates to:
  /// **'USB not connected'**
  String get usbNotConnected;

  /// lib/widgets/uac2/uac2_volume_control.dart:162
  ///
  /// In en, this message translates to:
  /// **'USB Route Volume'**
  String get usbRouteVolume;

  /// lib/features/settings/screens/library_settings_screen.dart:1244
  ///
  /// In en, this message translates to:
  /// **'USB storage not connected'**
  String get usbStorageNotConnected;

  /// lib/features/player/widgets/player_action_button_row.dart:726
  ///
  /// In en, this message translates to:
  /// **'USB Volume'**
  String get usbVolume;

  /// lib/features/settings/screens/ui_customization_settings_screen.dart:125
  ///
  /// In en, this message translates to:
  /// **'USB Volume in Settings'**
  String get usbVolumeInSettings;

  /// lib/features/settings/screens/ui_customization_settings_screen.dart:113
  ///
  /// In en, this message translates to:
  /// **'USB Volume on Home'**
  String get usbVolumeOnHome;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1250
  ///
  /// In en, this message translates to:
  /// **'Use a fixed 48kHz/16bit output for better compatibility'**
  String get useAFixed48khz16bitOutput;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:682
  ///
  /// In en, this message translates to:
  /// **'Use AAudio directly. Lowest latency on Android 8.1 and newer.'**
  String get useAaudioDirectlyLowestLatencyOn;

  /// lib/features/settings/screens/widget_settings_screen.dart:519
  ///
  /// In en, this message translates to:
  /// **'Use album art as background'**
  String get useAlbumArtAsBackground;

  /// lib/features/player/widgets/inline_lyrics_panel.dart:225
  ///
  /// In en, this message translates to:
  /// **'Use Auto Source'**
  String get useAutoSource;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1335
  ///
  /// In en, this message translates to:
  /// **'Use Current Time'**
  String get useCurrentTime;

  /// lib/features/player/widgets/inline_lyrics_panel.dart:214
  ///
  /// In en, this message translates to:
  /// **'Use Existing File'**
  String get useExistingFile;

  /// lib/features/player/screens/lyrics_sync_screen.dart:712
  ///
  /// In en, this message translates to:
  /// **'- \"Use Existing File\" in the lyrics panel links an `.lrc`, `.txt`, or `.xml` file.\n- If some lines are not stamped, Flick fills their times automatically.\n- Save writes beside the song when possible, otherwise Flick stores a linked copy.'**
  String get useExistingFileInTheLyrics;

  /// lib/features/settings/screens/library_settings_screen.dart:1870
  ///
  /// In en, this message translates to:
  /// **'Use filesystem-level scanning instead of MediaStore for full tag accuracy'**
  String get useFilesystemLevelScanningInsteadOf;

  /// lib/features/player/screens/lyrics_sync_screen.dart:418
  ///
  /// In en, this message translates to:
  /// **'Use mm:ss.cc, e.g. 01:23.45'**
  String get useMmSsCcEG;

  /// lib/features/settings/screens/lyrics_settings_screen.dart:27
  ///
  /// In en, this message translates to:
  /// **'Use the current audio file\'s name when saving lyrics internally'**
  String get useTheCurrentAudioFileS;

  /// lib/models/album_color_mode.dart:33
  ///
  /// In en, this message translates to:
  /// **'Use the default monochrome theme.'**
  String get useTheDefaultMonochromeTheme;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1241
  ///
  /// In en, this message translates to:
  /// **'Use the highest fixed output rate and bit depth available'**
  String get useTheHighestFixedOutputRate;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:702
  ///
  /// In en, this message translates to:
  /// **'Use the legacy OpenSL ES backend. Troubleshooting fallback for older or problematic devices.'**
  String get useTheLegacyOpenslEsBackend;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:116
  ///
  /// In en, this message translates to:
  /// **'Use the list songs browser'**
  String get useTheListSongsBrowser;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:104
  ///
  /// In en, this message translates to:
  /// **'Use the orbital songs browser'**
  String get useTheOrbitalSongsBrowser;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:399
  ///
  /// In en, this message translates to:
  /// **'Use the verified direct USB path and disable software DSP controls that would break bit-perfect playback on an external USB DAC.'**
  String get useTheVerifiedDirectUsbPath;

  /// lib/features/settings/widgets/listenbrainz_settings_tile.dart:740
  ///
  /// In en, this message translates to:
  /// **'User Token'**
  String get userToken;

  /// lib/features/settings/screens/network_server_edit_screen.dart:450
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// lib/features/settings/screens/library_settings_screen.dart:251
  ///
  /// In en, this message translates to:
  /// **'Using {arg1}'**
  String using(Object arg1);

  /// lib/features/settings/screens/library_settings_screen.dart:307
  ///
  /// In en, this message translates to:
  /// **'Using {arg1}'**
  String using2(Object arg1);

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:490
  ///
  /// In en, this message translates to:
  /// **'Variable bitrate, low latency'**
  String get variableBitrateLowLatency;

  /// lib/data/repositories/song_repository.dart:637
  ///
  /// In en, this message translates to:
  /// **'Various Artists'**
  String get variousArtists2;

  /// lib/models/song.dart:339
  ///
  /// In en, this message translates to:
  /// **'Velvet Noir'**
  String get velvetNoir;

  /// lib/features/settings/screens/uac2_settings_screen.dart:489
  ///
  /// In en, this message translates to:
  /// **'Vendor ID'**
  String get vendorId;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:379
  ///
  /// In en, this message translates to:
  /// **'Verbose Dart, Rust, and crash logs'**
  String get verboseDartRustAndCrashLogs;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:704
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// lib/features/settings/screens/app_info_settings_screen.dart:454
  ///
  /// In en, this message translates to:
  /// **'Version {kAppVersion}'**
  String version(Object kAppVersion);

  /// lib/features/settings/screens/visualizer_settings_screen.dart:71
  ///
  /// In en, this message translates to:
  /// **'Vertical bars — classic spectrum analyzer'**
  String get verticalBarsClassicSpectrumAnalyzer;

  /// lib/models/progress_bar_style.dart:25
  ///
  /// In en, this message translates to:
  /// **'Vertical bars that animate across the screen.'**
  String get verticalBarsThatAnimateAcrossThe;

  /// lib/features/settings/screens/orbit_settings_screen.dart:38
  ///
  /// In en, this message translates to:
  /// **'Vertical Position'**
  String get verticalPosition;

  /// lib/models/album_color_mode.dart:26
  ///
  /// In en, this message translates to:
  /// **'Vibrant'**
  String get vibrant;

  /// lib/features/songs/screens/songs_screen.dart
  ///
  /// In en, this message translates to:
  /// **'View as grid'**
  String get viewAsGrid;

  /// lib/features/songs/screens/songs_screen.dart
  ///
  /// In en, this message translates to:
  /// **'View as list'**
  String get viewAsList;

  /// lib/features/player/widgets/song_actions_sheet.dart:286
  ///
  /// In en, this message translates to:
  /// **'View Metadata'**
  String get viewMetadata;

  /// lib/features/settings/screens/app_info_settings_screen.dart:679
  ///
  /// In en, this message translates to:
  /// **'View Onboarding'**
  String get viewOnboarding;

  /// lib/features/albums/screens/album_detail_screen.dart:265
  ///
  /// In en, this message translates to:
  /// **'View queue'**
  String get viewQueue;

  /// lib/features/settings/screens/bottom_bar_settings_screen.dart:36
  ///
  /// In en, this message translates to:
  /// **'Visualizer'**
  String get visualizer;

  /// No description provided for @visualizerAlbumColorsDescription.
  ///
  /// In en, this message translates to:
  /// **'Follow the album cover colors; monochrome when unavailable'**
  String get visualizerAlbumColorsDescription;

  /// No description provided for @visualizerBlocks.
  ///
  /// In en, this message translates to:
  /// **'Fading Blocks'**
  String get visualizerBlocks;

  /// No description provided for @visualizerBlocksDescription.
  ///
  /// In en, this message translates to:
  /// **'Segmented bars with softly fading trails'**
  String get visualizerBlocksDescription;

  /// No description provided for @visualizerColors.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get visualizerColors;

  /// No description provided for @visualizerMonochrome.
  ///
  /// In en, this message translates to:
  /// **'Monochrome'**
  String get visualizerMonochrome;

  /// No description provided for @visualizerMonochromeDescription.
  ///
  /// In en, this message translates to:
  /// **'White and gray, independent of the album cover'**
  String get visualizerMonochromeDescription;

  /// No description provided for @visualizerRainbow.
  ///
  /// In en, this message translates to:
  /// **'Rainbow'**
  String get visualizerRainbow;

  /// No description provided for @visualizerRainbowDescription.
  ///
  /// In en, this message translates to:
  /// **'A spectrum of colors across the visualizer'**
  String get visualizerRainbowDescription;

  /// lib/features/settings/screens/orbit_settings_screen.dart:174
  ///
  /// In en, this message translates to:
  /// **'Visuals'**
  String get visuals;

  /// lib/features/player/widgets/bit_perfect_indicator.dart:646
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// lib/features/settings/screens/uac2_settings_screen.dart:95
  ///
  /// In en, this message translates to:
  /// **'Volume Control'**
  String get volumeControl;

  /// lib/features/settings/screens/playback_display_settings_screen.dart:245
  ///
  /// In en, this message translates to:
  /// **'Volume dips while notification sounds play'**
  String get volumeDipsWhileNotificationSoundsPlay;

  /// lib/features/player/widgets/volume_bottom_sheet.dart:112
  ///
  /// In en, this message translates to:
  /// **'Volume is fixed while bit-perfect passthrough is active and this DAC has no hardware volume control.'**
  String get volumeIsFixedWhileBitPerfect;

  /// lib/widgets/uac2/uac2_volume_control.dart:236
  ///
  /// In en, this message translates to:
  /// **'Volume is fixed while bit-perfect passthrough is active: the stream is sent untouched and this DAC has no hardware volume control.'**
  String get volumeIsFixedWhileBitPerfect2;

  /// lib/features/settings/widgets/lastfm_settings_tile.dart:978
  ///
  /// In en, this message translates to:
  /// **'Waiting for browser authorization...'**
  String get waitingForBrowserAuthorization;

  /// lib/features/settings/screens/uac2_preferences_screen.dart:1110
  ///
  /// In en, this message translates to:
  /// **'Waiting for playback'**
  String get waitingForPlayback;

  /// lib/providers/tutorial_provider.dart:55
  ///
  /// In en, this message translates to:
  /// **'Want every control documented? Open the in-app Manual anytime from Settings → Help & Manual.'**
  String get wantEveryControlDocumentedOpenThe;

  /// lib/features/albums/widgets/identify_album_sheet.dart:537
  ///
  /// In en, this message translates to:
  /// **'was: {arg1}'**
  String was(Object arg1);

  /// lib/features/settings/screens/visualizer_settings_screen.dart:86
  ///
  /// In en, this message translates to:
  /// **'Wave'**
  String get wave;

  /// lib/models/progress_bar_style.dart:16
  ///
  /// In en, this message translates to:
  /// **'Waveform'**
  String get waveform;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:926
  ///
  /// In en, this message translates to:
  /// **'We’ll keep the best-quality version in each group (prefers album art, then highest bitrate) and remove {count, plural, =1{{count} copy} other{{count} copies}}. Files on disk are not deleted.'**
  String weLlKeepTheBestQuality(int count);

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:878
  ///
  /// In en, this message translates to:
  /// **'We’ll keep your {kept, plural, =1{{kept} checked version} other{{kept} checked versions}} and remove the other {removed, plural, =1{{removed} copy} other{{removed} copies}} from your library. Audio files on disk are not deleted.'**
  String weLlKeepYourCheckedVersion(int kept, int removed);

  /// lib/features/settings/screens/network_server_edit_screen.dart:73
  ///
  /// In en, this message translates to:
  /// **'WebDAV'**
  String get webdav;

  /// lib/data/repositories/recently_played_repository.dart:15
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// lib/providers/tutorial_provider.dart:7
  ///
  /// In en, this message translates to:
  /// **'Welcome to Flick'**
  String get welcomeToFlick2;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:529
  ///
  /// In en, this message translates to:
  /// **'When you play over Bluetooth, Android negotiates the codec with your headphones or speaker.'**
  String get whenYouPlayOverBluetoothAndroid;

  /// lib/features/player/screens/lyrics_sync_screen.dart:491
  ///
  /// In en, this message translates to:
  /// **'Where should the .lrc file be saved?'**
  String get whereShouldTheLrcFileBe;

  /// lib/features/settings/screens/orbit_settings_screen.dart:39
  ///
  /// In en, this message translates to:
  /// **'Where the focal song sits vertically'**
  String get whereTheFocalSongSitsVertically;

  /// lib/features/settings/screens/support_flick_screen.dart:161
  ///
  /// In en, this message translates to:
  /// **'Where Your Money Goes'**
  String get whereYourMoneyGoes;

  /// lib/models/song.dart:371
  ///
  /// In en, this message translates to:
  /// **'Whisper World'**
  String get whisperWorld;

  /// lib/models/song.dart:366
  ///
  /// In en, this message translates to:
  /// **'Whispered Secrets'**
  String get whisperedSecrets;

  /// lib/features/settings/screens/widget_settings_screen.dart:267
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get white;

  /// lib/features/songs/widgets/album_art_picker_bottom_sheet.dart:404
  ///
  /// In en, this message translates to:
  /// **'Whole album'**
  String get wholeAlbum;

  /// lib/features/settings/screens/support_flick_screen.dart:131
  ///
  /// In en, this message translates to:
  /// **'Why Donate'**
  String get whyDonate;

  /// lib/features/settings/screens/equalizer_screen.dart:3493
  ///
  /// In en, this message translates to:
  /// **'{amount}% wide'**
  String wide(Object amount);

  /// lib/features/settings/screens/settings_screen.dart:222
  ///
  /// In en, this message translates to:
  /// **'Widgets'**
  String get widgets;

  /// lib/features/settings/screens/equalizer_screen.dart:3667
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get width;

  /// lib/models/song.dart:380
  ///
  /// In en, this message translates to:
  /// **'Wild Weather'**
  String get wildWeather;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:1531
  ///
  /// In en, this message translates to:
  /// **'Will be removed'**
  String get willBeRemoved;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:647
  ///
  /// In en, this message translates to:
  /// **'Will keep'**
  String get willKeep;

  /// lib/features/settings/screens/uac2_settings_screen.dart:927
  ///
  /// In en, this message translates to:
  /// **'Wired output'**
  String get wiredOutput;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1558
  ///
  /// In en, this message translates to:
  /// **'Word {arg1} · \"{arg2}\"'**
  String word(Object arg1, Object arg2);

  /// lib/features/player/screens/lyrics_sync_screen.dart:1788
  ///
  /// In en, this message translates to:
  /// **'Word {arg1} · \"{token}\"'**
  String word2(Object arg1, Object token);

  /// lib/features/player/screens/lyrics_sync_screen.dart:903
  ///
  /// In en, this message translates to:
  /// **'Word Sync'**
  String get wordSync;

  /// lib/features/player/screens/lyrics_sync_screen.dart:670
  ///
  /// In en, this message translates to:
  /// **'Word Sync mode (karaoke)'**
  String get wordSyncModeKaraoke;

  /// lib/features/player/screens/lyrics_sync_screen.dart:1678
  ///
  /// In en, this message translates to:
  /// **'Word Timeline · Line {arg1}'**
  String wordTimelineLine(Object arg1);

  /// lib/features/settings/screens/settings_screen.dart:116
  ///
  /// In en, this message translates to:
  /// **'Wrap-around and queue behavior'**
  String get wrapAroundAndQueueBehavior;

  /// lib/features/settings/screens/queue_settings_screen.dart:48
  ///
  /// In en, this message translates to:
  /// **'Wrap-around Queue'**
  String get wrapAroundQueue;

  /// lib/features/albums/screens/album_detail_screen.dart:314
  ///
  /// In en, this message translates to:
  /// **'Write a description'**
  String get writeADescription;

  /// lib/features/player/widgets/speed_bottom_sheet.dart:64
  ///
  /// In en, this message translates to:
  /// **'{min}x'**
  String x(Object min);

  /// lib/features/player/widgets/speed_bottom_sheet.dart:83
  ///
  /// In en, this message translates to:
  /// **'{max}x'**
  String x2(Object max);

  /// lib/features/player/widgets/speed_bottom_sheet.dart:94
  ///
  /// In en, this message translates to:
  /// **'{currentSpeed}x'**
  String x3(Object currentSpeed);

  /// lib/features/player/widgets/song_metadata_sheet.dart:72
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// lib/data/repositories/recently_played_repository.dart:17
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// lib/data/repositories/recently_played_repository.dart:285
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// lib/features/settings/screens/app_info_settings_screen.dart:168
  ///
  /// In en, this message translates to:
  /// **'You already have the latest Flick release'**
  String get youAlreadyHaveTheLatestFlick;

  /// lib/features/settings/screens/app_info_settings_screen.dart:167
  ///
  /// In en, this message translates to:
  /// **'You already have the latest Play Store release'**
  String get youAlreadyHaveTheLatestPlay;

  /// lib/features/settings/screens/bluetooth_settings_screen.dart:612
  ///
  /// In en, this message translates to:
  /// **'You can also change the codec in Android Developer Options under \"Bluetooth Audio Codec\".'**
  String get youCanAlsoChangeTheCodec;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:667
  ///
  /// In en, this message translates to:
  /// **'You customized which versions to keep. Nice — you\'re in control.'**
  String get youCustomizedWhichVersionsToKeep;

  /// lib/features/songs/screens/metadata_editor_screen.dart:564
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Are you sure you want to discard them?'**
  String get youHaveUnsavedChangesAreYou;

  /// lib/features/player/screens/lyrics_sync_screen.dart:590
  ///
  /// In en, this message translates to:
  /// **'You have unsaved lyric edits. Leave the Sync Studio without saving?'**
  String get youHaveUnsavedLyricEditsLeave;

  /// lib/widgets/common/offline_notice.dart:180
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get youReOffline;

  /// lib/widgets/common/offline_notice.dart:136
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Some online features may not work.'**
  String get youReOfflineSomeOnlineFeatures;

  /// lib/features/albums/screens/albums_screen.dart:333
  ///
  /// In en, this message translates to:
  /// **'Your collection at a glance'**
  String get yourCollectionAtAGlance;

  /// lib/features/songs/screens/songs_screen.dart:1883
  ///
  /// In en, this message translates to:
  /// **'Your Library'**
  String get yourLibrary;

  /// lib/features/artists/screens/artists_screen.dart:363
  ///
  /// In en, this message translates to:
  /// **'Your library at a glance'**
  String get yourLibraryAtAGlance;

  /// lib/features/settings/screens/duplicate_cleaner_screen.dart:274
  ///
  /// In en, this message translates to:
  /// **'Your library is tidy. We’ll let you know if new duplicates appear after the next scan.'**
  String get yourLibraryIsTidyWeLl;

  /// lib/features/settings/widgets/listenbrainz_settings_tile.dart:136
  ///
  /// In en, this message translates to:
  /// **'Your listens will remain on ListenBrainz, but Flick will stop submitting them.'**
  String get yourListensWillRemainOnListenbrainz;

  /// lib/features/settings/screens/logs_screen.dart:130
  ///
  /// In en, this message translates to:
  /// **'Your logs are uploaded to dpaste.com as an unlisted link that expires in 30 days. Anyone you share the link with can read them — logs may contain file paths and device details.'**
  String get yourLogsAreUploadedToDpaste;

  /// lib/data/repositories/recently_played_repository.dart:37
  ///
  /// In en, this message translates to:
  /// **'Your monthly recap needs a bit more listening time this month.'**
  String get yourMonthlyRecapNeedsABit;

  /// lib/features/settings/widgets/lastfm_settings_tile.dart:837
  ///
  /// In en, this message translates to:
  /// **'Your music is being scrobbled'**
  String get yourMusicIsBeingScrobbled;

  /// lib/features/settings/widgets/listenbrainz_settings_tile.dart:267
  ///
  /// In en, this message translates to:
  /// **'Your music is being submitted'**
  String get yourMusicIsBeingSubmitted;

  /// lib/widgets/common/engine_restart_notice.dart:54
  ///
  /// In en, this message translates to:
  /// **'Your new audio engine is ready. Restart Flick to apply it.'**
  String get yourNewAudioEngineIsReady;

  /// lib/features/menu/screens/menu_screen.dart:972
  ///
  /// In en, this message translates to:
  /// **'Your Playlists'**
  String get yourPlaylists;

  /// lib/features/settings/widgets/lastfm_settings_tile.dart:198
  ///
  /// In en, this message translates to:
  /// **'Your scrobbling history will remain on Last.fm, but Flick will stop sending scrobbles.'**
  String get yourScrobblingHistoryWillRemainOn;

  /// lib/data/repositories/recently_played_repository.dart:35
  ///
  /// In en, this message translates to:
  /// **'Your weekly recap appears once you start listening this week.'**
  String get yourWeeklyRecapAppearsOnceYou;

  /// lib/providers/tutorial_provider.dart:17
  ///
  /// In en, this message translates to:
  /// **'Your whole library lives here. Tap any song to play it.'**
  String get yourWholeLibraryLivesHereTap;

  /// lib/data/repositories/recently_played_repository.dart:39
  ///
  /// In en, this message translates to:
  /// **'Your yearly recap fills in as you keep listening throughout the year.'**
  String get yourYearlyRecapFillsInAs;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
