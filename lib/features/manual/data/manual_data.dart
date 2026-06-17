import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ManualEntry {
  final String title;
  final String body;
  final List<String>? tips;

  const ManualEntry({required this.title, required this.body, this.tips});
}

class ManualSection {
  final String id;
  final String title;
  final IconData icon;
  final List<ManualEntry> entries;

  const ManualSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.entries,
  });
}

const List<ManualSection> kManualSections = [
  ManualSection(
    id: 'songs',
    title: 'Songs',
    icon: LucideIcons.music,
    entries: [
      ManualEntry(
        title: 'Browsing your library',
        body: 'The Songs tab lists every track Flick has scanned. Scroll to browse, or use the search bar to filter by title or artist.',
      ),
      ManualEntry(
        title: 'Sort & Filter',
        body: 'Tap the sort icon (top-right of the header) to open the Sort & Filter sheet. Reorder by title, artist, album, date added, or last played. Filter by file type (FLAC, MP3, etc.).',
        tips: [
          'Sort persists across sessions.',
          'Shuffle from the header plays the whole library in random order.',
        ],
      ),
      ManualEntry(
        title: 'Playing a song',
        body: 'Tap any song to play it immediately. The queue is rebuilt starting from that song.',
      ),
      ManualEntry(
        title: 'Long-press a song',
        body: 'Opens the actions sheet: Play Next, Add to Queue, Add to Playlist, Go to Album, Go to Artist, Share, View Info, or Delete.',
      ),
      ManualEntry(
        title: 'Selection mode',
        body: 'Tap the check icon in the header to enter selection mode. Select multiple songs to queue, add to a playlist, or delete in bulk.',
      ),
      ManualEntry(
        title: 'Fast scroll',
        body: 'Drag the scroll handle on the right edge to jump through the alphabet. A bubble shows the current letter.',
      ),
    ],
  ),
  ManualSection(
    id: 'albums',
    title: 'Albums',
    icon: LucideIcons.disc3,
    entries: [
      ManualEntry(
        title: 'Grid view',
        body: 'Albums appear as a grid of cover art. Tap any album to open its detail screen with the full tracklist.',
      ),
      ManualEntry(
        title: 'Album detail',
        body: 'Play the whole album, shuffle it, or pick individual tracks. Album art, year, and artist are shown at the top.',
      ),
      ManualEntry(
        title: 'Sort',
        body: 'Sort albums by title, artist, year, or date added from the sort icon.',
      ),
    ],
  ),
  ManualSection(
    id: 'artists',
    title: 'Artists',
    icon: LucideIcons.mic,
    entries: [
      ManualEntry(
        title: 'Artist list',
        body: 'Browse all artists in your library. Tap an artist to see their albums and tracks.',
      ),
      ManualEntry(
        title: 'Artist detail',
        body: 'Shows the artist\'s albums and a complete track list. Play all, shuffle, or pick a starting track.',
      ),
    ],
  ),
  ManualSection(
    id: 'playlists',
    title: 'Playlists',
    icon: LucideIcons.listMusic,
    entries: [
      ManualEntry(
        title: 'Creating playlists',
        body: 'Tap the + button to create a new playlist. Name it, then add songs via long-press on any song \u2192 Add to Playlist.',
      ),
      ManualEntry(
        title: 'Editing',
        body: 'Open a playlist to reorder tracks (drag the handle), remove tracks (swipe or long-press), or rename/delete the playlist from its menu.',
      ),
      ManualEntry(
        title: 'Playing',
        body: 'Tap a playlist to play it in order, or use the shuffle button for random order.',
      ),
    ],
  ),
  ManualSection(
    id: 'folders',
    title: 'Folders',
    icon: LucideIcons.folder,
    entries: [
      ManualEntry(
        title: 'Browse by folder',
        body: 'See your music organized by the folder structure on disk. Useful if you organize files manually.',
      ),
      ManualEntry(
        title: 'Folder playback',
        body: 'Tap a folder to play all tracks inside it, including subfolders.',
      ),
    ],
  ),
  ManualSection(
    id: 'favorites',
    title: 'Favorites',
    icon: LucideIcons.heart,
    entries: [
      ManualEntry(
        title: 'Adding favorites',
        body: 'Tap the heart on a song (in the full player or long-press menu) to mark it as a favorite.',
      ),
      ManualEntry(
        title: 'Favorites tab',
        body: 'All favorited tracks in one place. Play, shuffle, or manage from here.',
      ),
    ],
  ),
  ManualSection(
    id: 'search',
    title: 'Search',
    icon: LucideIcons.search,
    entries: [
      ManualEntry(
        title: 'In-tab search',
        body: 'Each browse tab has its own search bar at the top that filters that tab\'s content live as you type.',
      ),
      ManualEntry(
        title: 'Dedicated Search tab',
        body: 'If Search is in your nav bar, it searches across songs, albums, and artists simultaneously with grouped results.',
        tips: ['Add the Search tab via long-press on the nav bar \u2192 Bottom Bar Settings.'],
      ),
    ],
  ),
  ManualSection(
    id: 'mini_player',
    title: 'Mini Player',
    icon: LucideIcons.play,
    entries: [
      ManualEntry(
        title: 'What it shows',
        body: 'The mini player sits above the nav bar and shows the current track\'s art, title, and artist with a progress indicator.',
      ),
      ManualEntry(
        title: 'Open the full player',
        body: 'Tap anywhere on the mini player to expand into the full player.',
      ),
      ManualEntry(
        title: 'Swipe to switch',
        body: 'Swipe left/right on the mini player to go to next/previous track (if enabled in settings).',
        tips: ['Configure swipe behavior in Settings \u2192 Player Layout \u2192 Mini Player Swipe.'],
      ),
      ManualEntry(
        title: 'Visualizer toggle',
        body: 'A swipe gesture (when configured) toggles an inline visualizer inside the mini player.',
      ),
    ],
  ),
  ManualSection(
    id: 'full_player',
    title: 'Full Player',
    icon: LucideIcons.music4,
    entries: [
      ManualEntry(
        title: 'Opening the full player',
        body: 'Tap the mini player. The full player expands with album art, the waveform seekbar, and all playback controls.',
      ),
      ManualEntry(
        title: 'Waveform seekbar',
        body: 'Drag anywhere on the waveform to scrub through the track. The waveform reflects the audio\'s loudness over time.',
      ),
      ManualEntry(
        title: 'Vinyl morph',
        body: 'Tap the album art to morph between the cover view and a spinning vinyl record view.',
      ),
      ManualEntry(
        title: 'Play / Pause / Next / Previous',
        body: 'Central transport controls. Previous restarts the track if you\'re past 3 seconds in.',
      ),
      ManualEntry(
        title: 'Shuffle & Repeat',
        body: 'Tap shuffle to toggle random order. Tap repeat to cycle: off \u2192 all \u2192 one. Long-press either for advanced options.',
      ),
      ManualEntry(
        title: 'Queue',
        body: 'Tap the queue icon to view and reorder upcoming tracks. Drag to reorder, swipe to remove.',
      ),
      ManualEntry(
        title: 'Lyrics',
        body: 'Tap the lyrics icon to open the lyrics view. If synced lyrics are available, they highlight in time with the music.',
        tips: ['Tap the edit icon in lyrics to open the Lyrics Sync Studio.'],
      ),
      ManualEntry(
        title: 'Equalizer',
        body: 'Tap the EQ icon to open the equalizer with presets and manual band control.',
      ),
      ManualEntry(
        title: 'Visualizer',
        body: 'Toggle the audio visualizer on/off and cycle through visualizer styles from the visualizer icon.',
      ),
      ManualEntry(
        title: 'Playback speed',
        body: 'Adjust playback speed (0.5x\u20132x) from the speed control. Pitch is preserved.',
      ),
      ManualEntry(
        title: 'Sleep timer',
        body: 'Set a countdown after which playback stops. Options: 5, 10, 15, 30, 45, 60 minutes, or end of track.',
      ),
      ManualEntry(
        title: 'Rating',
        body: 'Star-rate the current track. Ratings are stored and can be used for sorting.',
      ),
      ManualEntry(
        title: 'Share',
        body: 'Generate a share card with the album art and track info, or share the file directly.',
      ),
      ManualEntry(
        title: 'Custom action buttons',
        body: 'The left and right action buttons above the transport row can be customized in Settings \u2192 Player Layout \u2192 Quick Actions.',
      ),
      ManualEntry(
        title: 'Immersive view',
        body: 'Tap to hide controls for a clean album-art-only view. Tap again to bring them back.',
      ),
      ManualEntry(
        title: 'Bit-perfect capsule',
        body: 'When bit-perfect output is active, a capsule shows the sample rate and bit depth being sent to your DAC.',
      ),
    ],
  ),
  ManualSection(
    id: 'queue',
    title: 'Queue',
    icon: LucideIcons.listOrdered,
    entries: [
      ManualEntry(
        title: 'Viewing the queue',
        body: 'Open the queue from the full player. The currently playing track is highlighted; upcoming tracks are listed below.',
      ),
      ManualEntry(
        title: 'Reordering',
        body: 'Drag tracks by their handle to reorder. Changes apply immediately.',
      ),
      ManualEntry(
        title: 'Removing',
        body: 'Swipe a track left or right to remove it from the queue.',
      ),
      ManualEntry(
        title: 'Play Next',
        body: 'From any song\'s long-press menu, choose Play Next to insert it right after the current track.',
      ),
    ],
  ),
  ManualSection(
    id: 'equalizer',
    title: 'Equalizer',
    icon: LucideIcons.slidersHorizontal,
    entries: [
      ManualEntry(
        title: 'Presets',
        body: 'Choose from built-in presets (Flat, Bass Boost, Treble Boost, Vocal, etc.) or save your own.',
      ),
      ManualEntry(
        title: 'Manual bands',
        body: 'Drag each frequency band slider to shape the sound. The EQ applies system-wide to Flick\'s output.',
      ),
      ManualEntry(
        title: 'Enable / Disable',
        body: 'Toggle the master switch at the top to bypass the EQ without losing your settings.',
      ),
    ],
  ),
  ManualSection(
    id: 'lyrics',
    title: 'Lyrics & Sync Studio',
    icon: LucideIcons.fileText,
    entries: [
      ManualEntry(
        title: 'Viewing lyrics',
        body: 'Tap the lyrics icon in the full player. Synced lyrics scroll and highlight automatically; unsynced lyrics show as plain text.',
      ),
      ManualEntry(
        title: 'Fetching lyrics',
        body: 'Flick fetches lyrics automatically when available. You can also paste or edit them manually.',
      ),
      ManualEntry(
        title: 'Sync Studio',
        body: 'Open from the lyrics edit icon. Tap "Set" as each line plays to time-sync lyrics to the music. Save to persist the sync.',
        tips: [
          'Use the waveform scrubber to jump to a line you missed.',
          'Re-sync a line by tapping it again at the right moment.',
        ],
      ),
    ],
  ),
  ManualSection(
    id: 'visualizer',
    title: 'Visualizer',
    icon: LucideIcons.activity,
    entries: [
      ManualEntry(
        title: 'Toggling',
        body: 'In the full player, tap the visualizer icon to turn it on or off.',
      ),
      ManualEntry(
        title: 'Styles',
        body: 'Long-press or tap again to cycle through visualizer styles (bars, wave, radial, etc.).',
        tips: ['Configure default style and sensitivity in Settings \u2192 Visualizer.'],
      ),
    ],
  ),
  ManualSection(
    id: 'settings',
    title: 'Settings',
    icon: LucideIcons.settings,
    entries: [
      ManualEntry(
        title: 'Library',
        body: 'Manage scan folders, trigger rescans, and run the duplicate cleaner.',
      ),
      ManualEntry(
        title: 'Playback & Display',
        body: 'Gapless playback, crossfade, view modes, and theme appearance.',
      ),
      ManualEntry(
        title: 'Player Layout',
        body: 'Layout mode, sizing, mini player swipe action, and custom quick action buttons.',
      ),
      ManualEntry(
        title: 'Audio',
        body: 'UAC2 USB DAC preferences and equalizer settings.',
      ),
      ManualEntry(
        title: 'Lyrics',
        body: 'Configure lyrics saving and fetching behavior.',
      ),
      ManualEntry(
        title: 'Interface',
        body: 'Animations and haptic feedback toggles.',
      ),
      ManualEntry(
        title: 'UI Customization',
        body: 'Show or hide home screen sections and tabs.',
      ),
      ManualEntry(
        title: 'Integrations',
        body: 'Last.fm and ListenBrainz scrobbling setup.',
      ),
      ManualEntry(
        title: 'Widgets',
        body: 'Customize the home screen widget appearance.',
      ),
      ManualEntry(
        title: 'Bottom Bar',
        body: 'Long-press the nav bar, or open Settings \u2192 Bottom Bar, to choose which tabs appear and in what order.',
      ),
      ManualEntry(
        title: 'Help & Manual',
        body: 'This screen. Reopen anytime from Settings \u2192 Help & Manual.',
      ),
      ManualEntry(
        title: 'Replay tutorial',
        body: 'In App Info \u2192 Interactive Tutorial, replay the spotlight tour. View Onboarding replays the welcome screens.',
      ),
    ],
  ),
  ManualSection(
    id: 'gestures',
    title: 'Gestures',
    icon: LucideIcons.hand,
    entries: [
      ManualEntry(
        title: 'Tap',
        body: 'Play a song, open an album, toggle a control.',
      ),
      ManualEntry(
        title: 'Long-press',
        body: 'Open the actions sheet for a song, or customize the nav bar.',
      ),
      ManualEntry(
        title: 'Swipe horizontally on mini player',
        body: 'Next / previous track (or toggle visualizer, depending on settings).',
      ),
      ManualEntry(
        title: 'Swipe on a queue item',
        body: 'Remove it from the queue.',
      ),
      ManualEntry(
        title: 'Drag',
        body: 'Scrub the waveform seekbar, reorder queue items, reorder playlist tracks.',
      ),
      ManualEntry(
        title: 'Drag scroll handle',
        body: 'Fast-scroll through long lists (Songs tab).',
      ),
      ManualEntry(
        title: 'Swipe between tabs',
        body: 'Swipe left/right on the main page area to move between nav bar tabs.',
      ),
    ],
  ),
  ManualSection(
    id: 'home_widget',
    title: 'Home Screen Widget',
    icon: LucideIcons.layoutGrid,
    entries: [
      ManualEntry(
        title: 'Adding the widget',
        body: 'Long-press your home screen \u2192 Add widget \u2192 Flick. Choose a size and drop it on the home screen.',
      ),
      ManualEntry(
        title: 'Controls',
        body: 'The widget shows current track art and title with play/pause and skip controls. Tapping art opens the app.',
      ),
      ManualEntry(
        title: 'Customizing',
        body: 'Configure widget appearance and shown controls in Settings \u2192 Widgets.',
      ),
    ],
  ),
];
