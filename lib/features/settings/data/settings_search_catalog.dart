import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/features/manual/screens/manual_screen.dart';
import 'package:flick/features/milestone/screens/milestones_screen.dart';
import 'package:flick/l10n/settings_l10n.dart';
import '../screens/app_info_settings_screen.dart';
import '../screens/audio_settings_screen.dart';
import '../screens/bluetooth_settings_screen.dart';
import '../screens/bottom_bar_settings_screen.dart';
import '../screens/casting_settings_screen.dart';
import '../screens/duplicate_cleaner_screen.dart';
import '../screens/equalizer_screen.dart';
import '../screens/integrations_settings_screen.dart';
import '../screens/interface_settings_screen.dart';
import '../screens/library_settings_screen.dart';
import '../screens/logs_screen.dart';
import '../screens/lyrics_settings_screen.dart';
import '../screens/missing_metadata_screen.dart';
import '../screens/network_sources_screen.dart';
import '../screens/orbit_settings_screen.dart';
import '../screens/playback_display_settings_screen.dart';
import '../screens/player_layout_settings_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../screens/queue_settings_screen.dart';
import '../screens/support_flick_screen.dart';
import '../screens/uac2_preferences_screen.dart';
import '../screens/uac2_settings_screen.dart';
import '../screens/ui_customization_settings_screen.dart';
import '../screens/visualizer_settings_screen.dart';
import '../screens/widget_settings_screen.dart';
import 'settings_search.dart';

SettingsSearchSection _section(
  String id,
  String title,
  List<(String, String)> items, {
  String keywords = '',
}) => SettingsSearchSection(id, title, [
  for (final item in items) SettingsSearchItem(item.$1, item.$2),
], keywords: keywords);

/// Rebuilt for the current settings locale. IDs must match section anchors;
/// translated text is display/search data only, never a navigation address.
/// Dynamic devices, servers, presets and utility content use page-level links.
List<SettingsSearchPage> buildSettingsSearchCatalog() {
  final media = l10n.media;
  final system = l10n.system;
  final about = l10n.about;
  SettingsSearchPage page(
    String id,
    String title,
    String category,
    IconData icon,
    Widget Function(String?) builder, {
    String keywords = '',
    List<SettingsSearchSection> sections = const [],
  }) => SettingsSearchPage(
    id: id,
    title: title,
    category: category,
    icon: icon,
    buildPage: builder,
    keywords: keywords,
    sections: sections,
  );

  return [
    page(
      'library_settings',
      l10n.libraryLabel,
      media,
      LucideIcons.library,
      (id) => LibrarySettingsScreen(initialSection: id),
      keywords: 'folders scan rescan music files storage cache',
      sections: [
        _section('libraryLabel', l10n.libraryLabel, [
          ('addMusicFolder', l10n.addMusicFolder),
          ('rescanLibrary', l10n.rescanLibrary),
          ('preloadLibraryAudio', l10n.preloadLibraryAudio),
          ('scanReplaygain', l10n.scanReplaygain),
        ]),
        _section(
          'scanningSettings',
          l10n.scanningSettings,
          [
            ('filterNonMusicFilesFolders', l10n.filterNonMusicFilesFolders),
            ('ignoreTracksUnder500Kb', l10n.ignoreTracksUnder500Kb),
            ('ignoreTracksUnder60Seconds', l10n.ignoreTracksUnder60Seconds),
            ('importM3uM3u8Playlists', l10n.importM3uM3u8Playlists),
            ('deepScan', l10n.deepScan),
            ('fullLibraryAccess', l10n.fullLibraryAccess),
            ('preloadAudioData', l10n.preloadAudioData),
          ],
          keywords:
              'scanning filters minimum duration file size m3u m3u8 playlists',
        ),
        _section('storage', l10n.storage, [
          ('clearArtworkCache2', l10n.clearArtworkCache2),
          ('playbackCacheLimit', l10n.playbackCacheLimit),
          ('clearConvertedAudio', l10n.clearConvertedAudio),
          ('removeAllSongs2', l10n.removeAllSongs2),
        ]),
        _section('albumArtwork', l10n.albumArtwork, [
          ('stretchNonSquareArt', l10n.stretchNonSquareArt),
        ]),
        _section('metadata', l10n.metadata, []),
      ],
    ),
    page(
      'network_sources',
      l10n.networkSources,
      media,
      LucideIcons.cloud,
      (_) => const NetworkSourcesScreen(),
      keywords:
          'subsonic jellyfin webdav upnp dlna smb tidal server sync streaming network add source',
    ),
    page(
      'playback_display_settings',
      l10n.playbackDisplay,
      media,
      LucideIcons.play,
      (id) => PlaybackDisplaySettingsScreen(initialSection: id),
      sections: [
        SettingsSearchSection('playback', l10n.playback, [
          SettingsSearchItem('gaplessPlayback', l10n.gaplessPlayback),
          SettingsSearchItem('keepPlayingOnQuit', l10n.keepPlayingOnQuit),
          SettingsSearchItem(
            'backgroundPlaybackAnchor',
            l10n.backgroundPlaybackAnchor,
          ),
          SettingsSearchItem(
            'motionArtInBitPerfect',
            l10n.motionArtInBitPerfect,
          ),
          SettingsSearchItem(
            'duckOnNotifications',
            l10n.duckOnNotifications,
            keywords: 'interruption audio focus',
          ),
          SettingsSearchItem('floatingMiniPlayer', l10n.floatingMiniPlayer),
        ]),
        _section('display', l10n.display, [
          ('songViewOrbital', l10n.songViewOrbital),
          ('songViewList', l10n.songViewList),
          ('bottomBarAlwaysVisible', l10n.bottomBarAlwaysVisible),
          ('floatingIsland', l10n.floatingIsland),
          ('immersiveFullViewTimer', l10n.immersiveFullViewTimer),
        ]),
        _section('fastIndexScrolling', l10n.fastIndexScrolling, [
          ('fastIndexScrolling', l10n.fastIndexScrolling),
          ('autoHideTimeout', l10n.autoHideTimeout),
        ], keywords: 'alphabet index rail'),
      ],
    ),
    page(
      'queue_settings',
      l10n.queue,
      media,
      LucideIcons.listOrdered,
      (id) => QueueSettingsScreen(initialSection: id),
      sections: [
        _section('queue', l10n.queue, [
          ('wrapAroundQueue', l10n.wrapAroundQueue),
          ('autoplayOnQueueEnd', l10n.autoplayOnQueueEnd),
        ]),
      ],
    ),
    page(
      'player_layout_settings',
      l10n.playerLayout,
      media,
      LucideIcons.layoutPanelTop,
      (id) => PlayerLayoutSettingsScreen(initialSection: id),
      sections: [
        _section('layoutMode', l10n.layoutMode, [
          ('immersive', l10n.immersive),
          ('artworkCard', l10n.artworkCard),
        ]),
        _section('immersive', l10n.immersive, [
          ('textSize2', l10n.textSize2),
          ('textPlacement2', l10n.textPlacement2),
          ('fullViewCardSize2', l10n.fullViewCardSize2),
          ('showTitle2', l10n.showTitle2),
          ('showArtist2', l10n.showArtist2),
          ('showFileInfo2', l10n.showFileInfo2),
          ('autoFullView', l10n.autoFullView),
        ]),
        _section('artworkCard', l10n.artworkCard, [
          ('artworkSize2', l10n.artworkSize2),
          ('textSize2', l10n.textSize2),
          ('contentPlacement2', l10n.contentPlacement2),
          ('artworkPlacement2', l10n.artworkPlacement2),
          ('showTitle2', l10n.showTitle2),
          ('showArtist2', l10n.showArtist2),
          ('showAlbum2', l10n.showAlbum2),
          ('showFileInfo2', l10n.showFileInfo2),
          ('showFrame2', l10n.showFrame2),
          ('bitPerfectCapsule', l10n.bitPerfectCapsule),
        ]),
        _section('quickActions', l10n.quickActions, [
          ('leftTopButton', l10n.leftTopButton),
          ('leftBottomButton', l10n.leftBottomButton),
          ('rightTopButton', l10n.rightTopButton),
          ('rightBottomButton', l10n.rightBottomButton),
        ]),
      ],
    ),
    page(
      'audio_settings',
      l10n.audio,
      media,
      LucideIcons.headphones,
      (id) => AudioSettingsScreen(initialSection: id),
      sections: [
        _section('audio', l10n.audio, []),
        _section('volume', l10n.volume, [
          ('extendedVolume', l10n.extendedVolume),
        ]),
        _section('replaygain', l10n.replaygain, [
          ('off', l10n.off),
          ('track', l10n.track),
          ('album', l10n.album),
          ('preAmp', l10n.preAmp),
          ('preventClipping', l10n.preventClipping),
        ], keywords: 'replay gain loudness normalize normalization'),
        _section('crossfade', l10n.crossfade, [
          ('crossfade', l10n.crossfade),
          ('duration', l10n.duration),
          ('equalPower', l10n.equalPower),
          ('linear', l10n.linear),
          ('squareRoot', l10n.squareRoot),
          ('sCurve', l10n.sCurve),
        ], keywords: 'curve overlap fade'),
        _section('crossfeedBs2b', l10n.crossfeedBs2b, [
          ('off', l10n.off),
          ('defaultLabel', l10n.defaultLabel),
          ('crossfeed', l10n.crossfeed),
          ('crossfeedEasy', l10n.crossfeedEasy),
        ], keywords: 'crossfeed headphones bs2b level'),
      ],
    ),
    page(
      'bluetooth_settings',
      l10n.bluetooth,
      media,
      LucideIcons.bluetooth,
      (id) => BluetoothSettingsScreen(initialSection: id),
      keywords: 'bt wireless',
      sections: [
        _section('permission', l10n.permission, [
          ('grantBluetoothAccess', l10n.grantBluetoothAccess),
        ]),
        _section('connectionBehavior', l10n.connectionBehavior, [
          ('pauseOnDisconnect', l10n.pauseOnDisconnect),
          ('pauseOnBluetoothConnect', l10n.pauseOnBluetoothConnect),
          ('resumeOnReconnect', l10n.resumeOnReconnect),
          ('pauseOnUsbDacAttach', l10n.pauseOnUsbDacAttach),
          ('pauseOnUsbDacDetach', l10n.pauseOnUsbDacDetach),
        ]),
        _section('devices', l10n.devices, [
          ('automatic', l10n.automatic),
        ], keywords: 'paired output'),
        _section('codecU0026Audio', l10n.codecU0026Audio, [
          ('codecControl', l10n.codecControl),
          ('openBluetoothCodecSettings', l10n.openBluetoothCodecSettings),
          ('absoluteVolumeSync', l10n.absoluteVolumeSync),
        ], keywords: 'ldac sbc aac aptx codec sample rate bits bitrate'),
        _section('outputMode', l10n.outputMode, [
          ('hiResDirect', l10n.hiResDirect),
          ('lowLatencyMode', l10n.lowLatencyMode),
        ]),
        _section('codecInfo', l10n.codecInfo, []),
      ],
    ),
    page(
      'casting_settings',
      l10n.casting,
      media,
      LucideIcons.cast,
      (id) => CastingSettingsScreen(initialSection: id),
      keywords: 'dlna upnp chromecast cast receiver',
      sections: [
        _section('availableDevices', l10n.availableDevices, [
          ('scanForDevices', l10n.scanForDevices),
        ]),
        _section('session', l10n.session, [('stopCasting', l10n.stopCasting)]),
        _section('outputDevice', l10n.outputDevice, [
          ('refreshOutputs', l10n.refreshOutputs),
        ]),
        _section('about', l10n.about, []),
      ],
    ),
    page(
      'lyrics_settings',
      l10n.lyrics,
      media,
      LucideIcons.fileText,
      (id) => LyricsSettingsScreen(initialSection: id),
      keywords: 'lrc karaoke alignment',
      sections: [
        _section('saving2', l10n.saving2, [
          ('matchAudioFilename', l10n.matchAudioFilename),
        ]),
        _section('display', l10n.display, [
          ('karaokeEffect', l10n.karaokeEffect),
          ('left', l10n.left),
          ('center', l10n.center),
          ('right', l10n.right),
        ]),
      ],
    ),
    page(
      'interface_settings',
      l10n.interfaceLabel,
      system,
      LucideIcons.layoutDashboard,
      (id) => InterfaceSettingsScreen(initialSection: id),
      sections: [
        _section(
          'language',
          l10n.language,
          [],
          keywords: 'locale english chinese taglish filipino baybayin',
        ),
        SettingsSearchSection('interfaceLabel', l10n.interfaceLabel, [
          SettingsSearchItem('animations', l10n.animations),
          SettingsSearchItem(
            'hapticFeedback',
            l10n.hapticFeedback,
            keywords: 'vibration vibrate haptics',
          ),
          SettingsSearchItem('connectionNotices', l10n.connectionNotices),
          SettingsSearchItem('swipeActions', l10n.swipeActions),
          SettingsSearchItem(
            'autoFocusSearch',
            l10n.autoFocusSearch,
            keywords: 'keyboard',
          ),
          SettingsSearchItem('libraryGlanceCard', l10n.libraryGlanceCard),
          SettingsSearchItem('dayStreaks', l10n.dayStreaks),
          SettingsSearchItem('resetStreakData2', l10n.resetStreakData2),
        ]),
        _section('refreshRate', l10n.refreshRate, [
          ('adaptive', l10n.adaptive),
          ('standard60hz', l10n.standard60hz),
          ('high120hz', l10n.high120hz),
        ]),
        _section('searchPlayback', l10n.searchPlayback, [
          ('searchResults', l10n.searchResults),
          ('fullLibrary', l10n.fullLibrary),
          ('activeQueue', l10n.activeQueue),
        ]),
        _section('favoriteRemoval', l10n.favoriteRemoval, [
          ('swipe', l10n.swipe),
          ('longPress', l10n.longPress),
        ]),
      ],
    ),
    page(
      'ui_customization_settings',
      l10n.uiCustomization,
      system,
      LucideIcons.palette,
      (id) => UiCustomizationSettingsScreen(initialSection: id),
      sections: [
        _section('homeScreenSections', l10n.homeScreenSections, [
          ('quickAccess', l10n.quickAccess),
          ('madeForYou', l10n.madeForYou),
          ('artistsInRotation', l10n.artistsInRotation),
          ('recentlyPlayed', l10n.recentlyPlayed),
          ('yourPlaylists', l10n.yourPlaylists),
          ('browseMore', l10n.browseMore),
          ('engineSelector', l10n.engineSelector),
          ('usbVolumeOnHome', l10n.usbVolumeOnHome),
          ('usbVolumeInSettings', l10n.usbVolumeInSettings),
        ]),
        _section('detailScreens', l10n.detailScreens, [
          ('moreFromArtist2', l10n.moreFromArtist2),
          ('moreArtists2', l10n.moreArtists2),
          ('animatedAlbumArt', l10n.animatedAlbumArt),
          ('expandedHeaderArt', l10n.expandedHeaderArt),
          ('centeredHeaderTitle', l10n.centeredHeaderTitle),
        ]),
        _section('trackThumbnails', l10n.trackThumbnails, [
          ('albumArt', l10n.albumArt),
          ('trackNumber', l10n.trackNumber),
          ('numberOnArt', l10n.numberOnArt),
        ], keywords: 'artwork thumbnail'),
        _section('progressBar', l10n.progressBar, [
          ('waveform', l10n.waveform),
          ('line', l10n.line),
        ], keywords: 'seekbar'),
        _section('albumColors', l10n.albumColors, [
          ('off', l10n.off),
          ('subtle', l10n.subtle),
          ('moderate', l10n.moderate),
          ('vibrant', l10n.vibrant),
        ], keywords: 'palette'),
      ],
    ),
    page(
      'integrations_settings',
      l10n.integrations,
      system,
      LucideIcons.plug,
      (id) => IntegrationsSettingsScreen(initialSection: id),
      sections: [
        _section('integrations', l10n.integrations, [
          ('lastFm', l10n.lastFm),
          ('listenbrainz', l10n.listenbrainz),
        ], keywords: 'scrobble scrobbling last.fm listenbrainz login'),
        _section('metadata', l10n.metadata, [
          ('autoIdentifyUntaggedAlbums', l10n.autoIdentifyUntaggedAlbums),
        ], keywords: 'apple music album identification tags'),
      ],
    ),
    for (var tab = 0; tab < 4; tab++)
      page(
        'widget_settings_$tab',
        '${l10n.widgets} · ${[l10n.miniPlayer, '4×3 Flagship', '2×2', 'Replay'][tab]}',
        system,
        LucideIcons.layoutGrid,
        (id) => WidgetSettingsScreen(initialTab: tab, initialSection: id),
        keywords: 'home screen widget',
        sections: [
          if (tab != 1)
            _section(
              'background',
              l10n.background,
              [
                if (tab != 3) ...[
                  ('transparent', l10n.transparent),
                  ('light', l10n.light),
                  ('medium', l10n.medium),
                  ('dark', l10n.dark),
                  ('solid', l10n.solid),
                ],
              ],
              keywords:
                  'opacity transparent light medium dark solid replay lime ink orange cover',
            ),
          if (tab != 3) ...[
            _section('content', l10n.content, [
              if (tab != 1) ('albumArt', l10n.albumArt),
              ('artistName', l10n.artistName),
            ]),
            _section('textSize2', l10n.textSize2, [
              ('fontScale', l10n.fontScale),
            ]),
            _section(
              'accentColor',
              l10n.accentColor,
              [],
              keywords: 'color colour',
            ),
          ],
        ],
      ),
    page(
      'bottom_bar_settings',
      l10n.bottomBar,
      system,
      LucideIcons.panelBottom,
      (id) => BottomBarSettingsScreen(initialSection: id),
      keywords: 'navigation mini player',
      sections: [
        _section('preview', l10n.preview, []),
        _section('miniPlayerLayout', l10n.miniPlayerLayout, [
          ('separateFromNavBar', l10n.separateFromNavBar),
          ('width', l10n.width),
          ('customWidth', l10n.customWidth),
          ('gapAboveNavigation', l10n.gapAboveNavigation),
          ('miniPlayerHeight', l10n.miniPlayerHeight),
          ('cornerRadius', l10n.cornerRadius),
        ]),
        _section('contentControls', l10n.contentControls, [
          ('albumArtwork', l10n.albumArtwork),
          ('artist', l10n.artist),
          ('progress', l10n.progress),
          ('previousSong2', l10n.previousSong2),
          ('nextSong2', l10n.nextSong2),
        ]),
        _section('miniPlayerAppearance', l10n.miniPlayerAppearance, [
          ('backgroundOpacity', l10n.backgroundOpacity),
          ('border', l10n.border),
          ('shadow', l10n.shadow),
        ]),
        _section('textGestures', l10n.textGestures, [
          ('textSize2', l10n.textSize2),
          ('longSongTitles', l10n.longSongTitles),
          ('visualizer', l10n.visualizer),
          ('switchSongs', l10n.switchSongs),
          ('resetMiniPlayerToDefaults', l10n.resetMiniPlayerToDefaults),
        ], keywords: 'truncate scroll marquee'),
        _section('autoCollapse', l10n.autoCollapse, [
          ('autoCollapse', l10n.autoCollapse),
          ('collapseAfter', l10n.collapseAfter),
        ]),
        _section(
          'buttons',
          l10n.buttons,
          [
            ('menu', l10n.menu),
            ('songs14', l10n.songs14),
            ('settings', l10n.settings),
            ('albums', l10n.albums),
            ('artists', l10n.artists),
            ('folders', l10n.folders),
            ('playlists', l10n.playlists),
            ('favorites', l10n.favorites),
            ('search', l10n.search),
          ],
          keywords:
              'tabs reorder home songs albums artists folders playlists settings',
        ),
        _section('disabled', l10n.disabled, []),
        _section('hidden', l10n.hidden, []),
        _section('navigationAppearance', l10n.navigationAppearance, [
          ('barHeight', l10n.barHeight),
          ('buttonSpacing', l10n.buttonSpacing),
          ('iconSize', l10n.iconSize),
          ('showLabels', l10n.showLabels),
        ]),
      ],
    ),
    page(
      'visualizer_settings',
      l10n.visualizer,
      system,
      LucideIcons.audioLines,
      (id) => VisualizerSettingsScreen(initialSection: id),
      sections: [
        _section('visualizer', l10n.visualizer, [
          ('visualizer', l10n.visualizer),
        ]),
        _section('visualizerColors', l10n.visualizerColors, [
          ('albumArt', l10n.albumArt),
          ('visualizerRainbow', l10n.visualizerRainbow),
          ('visualizerMonochrome', l10n.visualizerMonochrome),
        ]),
        _section('animationStyle', l10n.animationStyle, [
          ('bars', l10n.bars),
          ('visualizerBlocks', l10n.visualizerBlocks),
          ('wave', l10n.wave),
          ('curvedWave', l10n.curvedWave),
          ('mirrored', l10n.mirrored),
          ('dots', l10n.dots),
        ]),
        _section('frequencyFocus', l10n.frequencyFocus, [
          ('fullSpectrum', l10n.fullSpectrum),
          ('bass', l10n.bass),
          ('mid', l10n.mid),
          ('treble', l10n.treble),
          ('bassTreble', l10n.bassTreble),
        ]),
        _section('movement', l10n.movement, [
          ('bouncy', l10n.bouncy),
          ('smooth', l10n.smooth),
          ('snappy', l10n.snappy),
        ]),
      ],
    ),
    page(
      'orbit_settings',
      l10n.customizeOrbital,
      media,
      LucideIcons.orbit,
      (id) => OrbitSettingsScreen(initialSection: id),
      sections: [
        _section('geometry', l10n.geometry, [
          ('curvature', l10n.curvature),
          ('verticalPosition', l10n.verticalPosition),
          ('horizontalReach', l10n.horizontalReach),
          ('itemSpacing', l10n.itemSpacing),
        ]),
        _section('sizing', l10n.sizing, [
          ('cardSize', l10n.cardSize),
          ('cardWidth', l10n.cardWidth),
        ]),
        _section('depth', l10n.depth, [
          ('selectedSize', l10n.selectedSize),
          ('depth', l10n.depth),
        ]),
        _section('artResolution', l10n.artResolution, [
          ('low', l10n.low),
          ('medium', l10n.medium),
          ('high', l10n.high),
          ('ultra', l10n.ultra),
        ]),
        _section('visuals', l10n.visuals, [
          ('showOrbitPath', l10n.showOrbitPath),
          ('showGlow', l10n.showGlow),
          ('resetToDefaults', l10n.resetToDefaults),
        ]),
      ],
    ),
    page(
      'uac2_settings',
      l10n.usbAudioUac2,
      media,
      LucideIcons.usb,
      (_) => const Uac2SettingsScreen(),
      keywords: 'dac usb devices capabilities native dsd dop volume',
    ),
    page(
      'uac2_preferences',
      l10n.uac2Preferences,
      media,
      LucideIcons.slidersHorizontal,
      (id) => Uac2PreferencesScreen(initialSection: id),
      keywords: 'usb dac dap audio engine preferences',
      sections: [
        _section(
          'audioFormat',
          l10n.audioFormat,
          [
            ('audioFormat', l10n.audioFormat),
            ('formatStrategy', l10n.formatStrategy),
            ('customFormat', l10n.customFormat),
          ],
          keywords:
              'sample rate bit depth channels highest quality compatibility pcm',
        ),
        _section('experimental', l10n.experimental, [
          ('dsdOutputMode', l10n.dsdOutputMode),
          ('dapNativeBitOrder', l10n.dapNativeBitOrder),
          ('dapNativeByteGrouping', l10n.dapNativeByteGrouping),
          ('hzTuning', l10n.hzTuning),
        ], keywords: 'dsd native dop 432hz tuning'),
        _section('advanced', l10n.advanced, [
          ('playbackEngine', l10n.playbackEngine),
          ('androidAudioApi', l10n.androidAudioApi),
          ('developerMode', l10n.developerMode),
          ('bitPerfectUsbDac', l10n.bitPerfectUsbDac),
          ('bitPerfectDapInternal', l10n.bitPerfectDapInternal),
          ('autoBitPerfectForUsbDacs', l10n.autoBitPerfectForUsbDacs),
          ('resetDeclinedUsbDacs', l10n.resetDeclinedUsbDacs),
          ('stopUsbOnQuit', l10n.stopUsbOnQuit),
          ('resetPreferences', l10n.resetPreferences),
          ('currentPlaybackMode', l10n.currentPlaybackMode),
        ], keywords: 'aaudio oboe opensl exclusive isochronous diagnostics'),
        _section('volume', l10n.volume, []),
      ],
    ),
    page(
      'equalizer',
      l10n.equalizer,
      media,
      LucideIcons.slidersHorizontal,
      (_) => const EqualizerScreen(),
      keywords: 'eq peq parametric bands frequency gain q presets autoeq',
    ),
    page(
      'equalizer_dynamics',
      '${l10n.equalizer} · ${l10n.dynamics}',
      media,
      LucideIcons.slidersHorizontal,
      (_) => const EqualizerScreen(initialPage: 1),
      keywords: 'compressor limiter threshold ratio attack release dynamics',
    ),
    page(
      'equalizer_fx',
      '${l10n.equalizer} · FX',
      media,
      LucideIcons.slidersHorizontal,
      (_) => const EqualizerScreen(initialPage: 2),
      keywords: 'effects reverb convolution impulse response wet dry fx',
    ),
    page(
      'missing_metadata',
      l10n.fixMissingMetadata,
      media,
      LucideIcons.tags,
      (_) => const MissingMetadataScreen(),
      keywords: 'unknown artist album tags missing metadata',
    ),
    page(
      'duplicate_cleaner',
      l10n.removeDuplicates,
      media,
      LucideIcons.copy,
      (_) => const DuplicateCleanerScreen(),
      keywords: 'duplicate cleaner songs tracks',
    ),
    page(
      'logs',
      l10n.logs,
      system,
      LucideIcons.bug,
      (_) => const LogsScreen(),
      keywords: 'debug diagnostics developer logs export',
    ),
    page(
      'manual',
      l10n.helpManual,
      l10n.help,
      LucideIcons.bookOpen,
      (_) => const ManualScreen(),
      keywords: 'guide help manual controls tutorial',
    ),
    page(
      'milestones',
      l10n.milestones,
      about,
      LucideIcons.trophy,
      (_) => const MilestonesScreen(),
      keywords: 'achievements unlocked streaks',
    ),
    page(
      'app_info_settings',
      l10n.appInfo,
      about,
      LucideIcons.info,
      (id) => AppInfoSettingsScreen(initialSection: id),
      sections: [
        _section('updates', l10n.updates, [
          ('checkAgain', l10n.checkAgain),
          ('automaticUpdateChecks', l10n.automaticUpdateChecks),
          ('patchNotes', l10n.patchNotes),
          ('openInPlayStore', l10n.openInPlayStore),
          ('downloadUpdate', l10n.downloadUpdate),
        ], keywords: 'check for updates version release'),
        _section('about', l10n.about, [
          ('aboutFlickPlayer', l10n.aboutFlickPlayer),
          ('buildFlavor', l10n.buildFlavor),
          ('licenses', l10n.licenses),
          ('viewOnboarding', l10n.viewOnboarding),
          ('interactiveTutorial', l10n.interactiveTutorial),
        ]),
        _section('support', l10n.support, []),
      ],
    ),
    page(
      'privacy_policy',
      l10n.privacyPolicy,
      about,
      LucideIcons.shield,
      (_) => const PrivacyPolicyScreen(),
      keywords: 'privacy data',
    ),
    page(
      'support_flick',
      l10n.supportFlick,
      about,
      LucideIcons.heart,
      (_) => const SupportFlickScreen(),
      keywords: 'donate donation support coffee',
    ),
  ];
}
