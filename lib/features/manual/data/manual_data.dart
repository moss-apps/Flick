import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flick/l10n/l10n.dart';

/// One manual entry.
///
/// The copy is resolved through [title] / [body] / [tips] rather than stored as
/// fields, for the same reason `TutorialStep` does it: a `const` list cannot
/// hold `l10n.*`, because `l10n` is a runtime accessor. Keeping the structure
/// `const` and the text behind functions is what makes this screen translatable
/// at all -- as plain fields it rendered English in every locale.
class ManualEntry {
  final String Function(AppLocalizations) title;
  final String Function(AppLocalizations) body;
  final List<String> Function(AppLocalizations)? tipsOf;

  const ManualEntry({
    required this.title,
    required this.body,
    this.tipsOf,
  });

  List<String>? tips(AppLocalizations l10n) => tipsOf?.call(l10n);
}

class ManualSection {
  final String id;
  final String Function(AppLocalizations) titleOf;
  final IconData icon;
  final List<ManualEntry> entries;

  const ManualSection({
    required this.id,
    required this.titleOf,
    required this.icon,
    required this.entries,
  });

  String title(AppLocalizations l10n) => titleOf(l10n);
}

final List<ManualSection> kManualSections = [
  ManualSection(
    id: 'songs',
    titleOf: (l10n) => l10n.manualSongs,
    icon: LucideIcons.music,
    entries: [
      ManualEntry(
        title: (l10n) => l10n.browsingYourLibrary,
        body: (l10n) => l10n.theSongsTabListsEvery,
      ),
      ManualEntry(
        title: (l10n) => l10n.sortFilter,
        body: (l10n) => l10n.tapTheSortIconTop,
        tipsOf: (l10n) => [
          l10n.sortPersistsAcrossSessions, l10n.shuffleFromTheHeaderPlays,
        ],
      ),
      ManualEntry(
        title: (l10n) => l10n.playingASong,
        body: (l10n) => l10n.tapAnySongToPlay,
      ),
      ManualEntry(
        title: (l10n) => l10n.longPressASong,
        body: (l10n) => l10n.opensTheActionsSheetPlay,
      ),
      ManualEntry(
        title: (l10n) => l10n.selectionMode,
        body: (l10n) => l10n.tapTheCheckIconIn,
      ),
      ManualEntry(
        title: (l10n) => l10n.fastScroll,
        body: (l10n) => l10n.dragTheScrollHandleOn,
      ),
    ],
  ),
  ManualSection(
    id: 'albums',
    titleOf: (l10n) => l10n.albums,
    icon: LucideIcons.disc3,
    entries: [
      ManualEntry(
        title: (l10n) => l10n.gridView,
        body: (l10n) => l10n.albumsAppearAsAGrid,
      ),
      ManualEntry(
        title: (l10n) => l10n.albumDetail,
        body: (l10n) => l10n.playTheWholeAlbumShuffle,
      ),
      ManualEntry(
        title: (l10n) => l10n.sort,
        body: (l10n) => l10n.sortAlbumsByTitleArtist,
      ),
    ],
  ),
  ManualSection(
    id: 'artists',
    titleOf: (l10n) => l10n.artists,
    icon: LucideIcons.mic,
    entries: [
      ManualEntry(
        title: (l10n) => l10n.artistList,
        body: (l10n) => l10n.browseAllArtistsInYour,
      ),
      ManualEntry(
        title: (l10n) => l10n.artistDetail,
        body: (l10n) => l10n.showsTheArtistsAlbums,
      ),
    ],
  ),
  ManualSection(
    id: 'playlists',
    titleOf: (l10n) => l10n.playlists,
    icon: LucideIcons.listMusic,
    entries: [
      ManualEntry(
        title: (l10n) => l10n.creatingPlaylists,
        body: (l10n) => l10n.tapTheButtonToCreate,
      ),
      ManualEntry(
        title: (l10n) => l10n.editing,
        body: (l10n) => l10n.openAPlaylistToReorder,
      ),
      ManualEntry(
        title: (l10n) => l10n.playing,
        body: (l10n) => l10n.tapAPlaylistToPlay,
      ),
    ],
  ),
  ManualSection(
    id: 'folders',
    titleOf: (l10n) => l10n.folders,
    icon: LucideIcons.folder,
    entries: [
      ManualEntry(
        title: (l10n) => l10n.browseByFolder,
        body: (l10n) => l10n.seeYourMusicOrganizedBy,
      ),
      ManualEntry(
        title: (l10n) => l10n.folderPlayback,
        body: (l10n) => l10n.tapAFolderToPlay,
      ),
    ],
  ),
  ManualSection(
    id: 'favorites',
    titleOf: (l10n) => l10n.favorites,
    icon: LucideIcons.heart,
    entries: [
      ManualEntry(
        title: (l10n) => l10n.addingFavorites,
        body: (l10n) => l10n.tapTheHeartOnA,
      ),
      ManualEntry(
        title: (l10n) => l10n.favoritesTab,
        body: (l10n) => l10n.allFavoritedTracksInOne,
      ),
    ],
  ),
  ManualSection(
    id: 'search',
    titleOf: (l10n) => l10n.search,
    icon: LucideIcons.search,
    entries: [
      ManualEntry(
        title: (l10n) => l10n.inTabSearch,
        body: (l10n) => l10n.eachBrowseTabHasIts,
      ),
      ManualEntry(
        title: (l10n) => l10n.dedicatedSearchTab,
        body: (l10n) => l10n.ifSearchIsInYour,
        tipsOf: (l10n) => [
          l10n.addTheSearchTabVia,
        ],
      ),
    ],
  ),
  ManualSection(
    id: 'mini_player',
    titleOf: (l10n) => l10n.miniPlayer,
    icon: LucideIcons.play,
    entries: [
      ManualEntry(
        title: (l10n) => l10n.whatItShows,
        body: (l10n) => l10n.theMiniPlayerSitsAbove,
      ),
      ManualEntry(
        title: (l10n) => l10n.openTheFullPlayer,
        body: (l10n) => l10n.tapAnywhereOnTheMini,
      ),
      ManualEntry(
        title: (l10n) => l10n.swipeToSwitch,
        body: (l10n) => l10n.swipeLeftRightOnThe,
        tipsOf: (l10n) => [
          l10n.configureSwipeBehaviorInSettings,
        ],
      ),
      ManualEntry(
        title: (l10n) => l10n.visualizerToggle,
        body: (l10n) => l10n.aSwipeGestureWhenConfigured,
      ),
    ],
  ),
  ManualSection(
    id: 'full_player',
    titleOf: (l10n) => l10n.fullPlayer,
    icon: LucideIcons.music4,
    entries: [
      ManualEntry(
        title: (l10n) => l10n.openingTheFullPlayer,
        body: (l10n) => l10n.tapTheMiniPlayerThe,
      ),
      ManualEntry(
        title: (l10n) => l10n.waveformSeekbar,
        body: (l10n) => l10n.dragAnywhereOnTheWaveform,
      ),
      ManualEntry(
        title: (l10n) => l10n.vinylMorph,
        body: (l10n) => l10n.tapTheAlbumArtTo,
      ),
      ManualEntry(
        title: (l10n) => l10n.playPauseNextPrevious,
        body: (l10n) => l10n.centralTransportControlsPreviousRestarts,
      ),
      ManualEntry(
        title: (l10n) => l10n.shuffleRepeat,
        body: (l10n) => l10n.tapShuffleToToggleRandom,
      ),
      ManualEntry(
        title: (l10n) => l10n.manualQueue2,
        body: (l10n) => l10n.tapTheQueueIconTo,
      ),
      ManualEntry(
        title: (l10n) => l10n.lyrics,
        body: (l10n) => l10n.tapTheLyricsIconTo,
        tipsOf: (l10n) => [
          l10n.tapTheEditIconIn,
        ],
      ),
      ManualEntry(
        title: (l10n) => l10n.equalizer,
        body: (l10n) => l10n.tapTheEQIconTo,
      ),
      ManualEntry(
        title: (l10n) => l10n.visualizer,
        body: (l10n) => l10n.toggleTheAudioVisualizerOn,
      ),
      ManualEntry(
        title: (l10n) => l10n.manualPlaybackSpeed,
        body: (l10n) => l10n.adjustPlaybackSpeed05x,
      ),
      ManualEntry(
        title: (l10n) => l10n.sleepTimer,
        body: (l10n) => l10n.setACountdownAfterWhich,
      ),
      ManualEntry(
        title: (l10n) => l10n.rating,
        body: (l10n) => l10n.starRateTheCurrentTrack,
      ),
      ManualEntry(
        title: (l10n) => l10n.share,
        body: (l10n) => l10n.generateAShareCardWith,
      ),
      ManualEntry(
        title: (l10n) => l10n.customActionButtons,
        body: (l10n) => l10n.theLeftAndRightAction,
      ),
      ManualEntry(
        title: (l10n) => l10n.immersiveView,
        body: (l10n) => l10n.tapToHideControlsFor,
      ),
      ManualEntry(
        title: (l10n) => l10n.manualBitPerfectCapsule,
        body: (l10n) => l10n.whenBitPerfectOutputIs,
      ),
    ],
  ),
  ManualSection(
    id: 'queue',
    titleOf: (l10n) => l10n.manualQueue2,
    icon: LucideIcons.listOrdered,
    entries: [
      ManualEntry(
        title: (l10n) => l10n.viewingTheQueue,
        body: (l10n) => l10n.openTheQueueFromThe,
      ),
      ManualEntry(
        title: (l10n) => l10n.reordering,
        body: (l10n) => l10n.dragTracksByTheirHandle,
      ),
      ManualEntry(
        title: (l10n) => l10n.manualRemoving,
        body: (l10n) => l10n.swipeATrackLeftOr,
      ),
      ManualEntry(
        title: (l10n) => l10n.manualPlayNext,
        body: (l10n) => l10n.fromAnySongsLong,
      ),
    ],
  ),
  ManualSection(
    id: 'equalizer',
    titleOf: (l10n) => l10n.equalizer,
    icon: LucideIcons.slidersHorizontal,
    entries: [
      ManualEntry(
        title: (l10n) => l10n.presets,
        body: (l10n) => l10n.chooseFromBuiltInPresets,
      ),
      ManualEntry(
        title: (l10n) => l10n.manualBands,
        body: (l10n) => l10n.dragEachFrequencyBandSlider,
      ),
      ManualEntry(
        title: (l10n) => l10n.enableDisable,
        body: (l10n) => l10n.toggleTheMasterSwitchAt,
      ),
    ],
  ),
  ManualSection(
    id: 'lyrics',
    titleOf: (l10n) => l10n.manualLyricsSyncStudio,
    icon: LucideIcons.fileText,
    entries: [
      ManualEntry(
        title: (l10n) => l10n.viewingLyrics,
        body: (l10n) => l10n.tapTheLyricsIconIn,
      ),
      ManualEntry(
        title: (l10n) => l10n.fetchingLyrics,
        body: (l10n) => l10n.flickFetchesLyricsAutomaticallyWhen,
      ),
      ManualEntry(
        title: (l10n) => l10n.syncStudio,
        body: (l10n) => l10n.openFromTheLyricsEdit,
        tipsOf: (l10n) => [
          l10n.useTheWaveformScrubberTo, l10n.reSyncALineBy,
        ],
      ),
    ],
  ),
  ManualSection(
    id: 'visualizer',
    titleOf: (l10n) => l10n.visualizer,
    icon: LucideIcons.activity,
    entries: [
      ManualEntry(
        title: (l10n) => l10n.toggling,
        body: (l10n) => l10n.inTheFullPlayerTap,
      ),
      ManualEntry(
        title: (l10n) => l10n.styles,
        body: (l10n) => l10n.longPressOrTapAgain,
        tipsOf: (l10n) => [
          l10n.configureDefaultStyleAndSensitivity,
        ],
      ),
    ],
  ),
  ManualSection(
    id: 'settings',
    titleOf: (l10n) => l10n.settings,
    icon: LucideIcons.settings,
    entries: [
      ManualEntry(
        title: (l10n) => l10n.library,
        body: (l10n) => l10n.manageScanFoldersTriggerRescans,
      ),
      ManualEntry(
        title: (l10n) => l10n.playbackDisplay,
        body: (l10n) => l10n.gaplessPlaybackCrossfadeViewModes,
      ),
      ManualEntry(
        title: (l10n) => l10n.playerLayout,
        body: (l10n) => l10n.layoutModeSizingMiniPlayer,
      ),
      ManualEntry(
        title: (l10n) => l10n.audio,
        body: (l10n) => l10n.uac2USBDACPreferencesAnd,
      ),
      ManualEntry(
        title: (l10n) => l10n.lyrics,
        body: (l10n) => l10n.configureLyricsSavingAndFetching,
      ),
      ManualEntry(
        title: (l10n) => l10n.interface,
        body: (l10n) => l10n.animationsAndHapticFeedbackToggles,
      ),
      ManualEntry(
        title: (l10n) => l10n.uiCustomization,
        body: (l10n) => l10n.showOrHideHomeScreen,
      ),
      ManualEntry(
        title: (l10n) => l10n.integrations,
        body: (l10n) => l10n.lastFmAndListenBrainzScrobbling,
      ),
      ManualEntry(
        title: (l10n) => l10n.widgets,
        body: (l10n) => l10n.customizeTheHomeScreenWidget,
      ),
      ManualEntry(
        title: (l10n) => l10n.manualBottomBar,
        body: (l10n) => l10n.longPressTheNavBar,
      ),
      ManualEntry(
        title: (l10n) => l10n.helpManual,
        body: (l10n) => l10n.thisScreenReopenAnytimeFrom,
      ),
      ManualEntry(
        title: (l10n) => l10n.replayTutorial,
        body: (l10n) => l10n.inAppInfoU2192Interactive,
      ),
    ],
  ),
  ManualSection(
    id: 'gestures',
    titleOf: (l10n) => l10n.gestures,
    icon: LucideIcons.hand,
    entries: [
      ManualEntry(
        title: (l10n) => l10n.manualTap,
        body: (l10n) => l10n.playASongOpenAn,
      ),
      ManualEntry(
        title: (l10n) => l10n.manualLongPress,
        body: (l10n) => l10n.openTheActionsSheetFor,
      ),
      ManualEntry(
        title: (l10n) => l10n.swipeHorizontallyOnMiniPlayer,
        body: (l10n) => l10n.nextPreviousTrackOrToggle,
      ),
      ManualEntry(
        title: (l10n) => l10n.swipeOnAQueueItem,
        body: (l10n) => l10n.removeItFromTheQueue,
      ),
      ManualEntry(
        title: (l10n) => l10n.drag,
        body: (l10n) => l10n.scrubTheWaveformSeekbarReorder,
      ),
      ManualEntry(
        title: (l10n) => l10n.dragScrollHandle,
        body: (l10n) => l10n.fastScrollThroughLongLists,
      ),
      ManualEntry(
        title: (l10n) => l10n.swipeBetweenTabs,
        body: (l10n) => l10n.manualSwipeLeftRightOnThe,
      ),
    ],
  ),
  ManualSection(
    id: 'home_widget',
    titleOf: (l10n) => l10n.homeScreenWidget,
    icon: LucideIcons.layoutGrid,
    entries: [
      ManualEntry(
        title: (l10n) => l10n.addingTheWidget,
        body: (l10n) => l10n.longPressYourHomeScreen,
      ),
      ManualEntry(
        title: (l10n) => l10n.controls,
        body: (l10n) => l10n.theWidgetShowsCurrentTrack,
      ),
      ManualEntry(
        title: (l10n) => l10n.customizing,
        body: (l10n) => l10n.configureWidgetAppearanceAndShown,
      ),
    ],
  ),
];
