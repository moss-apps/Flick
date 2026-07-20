/// Structured changelog data shown to the user in the "What's New" bottom
/// sheet. Entries are keyed by version string and must match `kAppVersion`
/// exactly to be considered "new".
class ChangelogEntry {
  const ChangelogEntry({
    required this.version,
    required this.date,
    required this.sections,
  });

  final String version;
  final String date;
  final List<ChangelogSection> sections;
}

class ChangelogSection {
  const ChangelogSection({
    required this.title,
    this.subsections = const [],
    this.bullets = const [],
  });

  final String title;
  final List<ChangelogSubsection> subsections;
  final List<String> bullets;
}

class ChangelogSubsection {
  const ChangelogSubsection({this.title, required this.bullets});

  /// `null` when the section has no sub-headers and the bullets belong
  /// directly to the section.
  final String? title;
  final List<String> bullets;
}

/// All changelog data known to the app, in reverse chronological order.
///
/// When a new release ships:
///   1. Bump `kAppVersion` in `core/constants/app_constants.dart`.
///   2. Prepend a new [ChangelogEntry] matching that version here.
///
/// The "What's New" bottom sheet on first launch after an update will
/// automatically surface the entry whose `version` equals `kAppVersion`.
const List<ChangelogEntry> kChangelogEntries = [
  ChangelogEntry(
    version: '0.20.4-beta.5',
    date: '2026-07-03',
    sections: [
      ChangelogSection(
        title: 'Pitch Shifter (SoundTouch)',
        bullets: [
          'Real-time pitch shifting via the **SoundTouch** audio processing library, integrated into the DSP chain.',
          'Lock-free bypass flag — zero-cost when pitch is at 1.0×.',
          'Pitch shift semitones API with FFI bridge and notifier.',
          'Pitch control bottom sheet with semitone slider.',
          'Pitch control option added to the song actions sheet.',
          'Pitch resets automatically to 1.0× when playback stops.',
        ],
      ),
      ChangelogSection(
        title: 'Android Audio API Preference',
        bullets: [
          'Choose your Android audio API: **AAudio** (recommended, Android 8+), **OpenSL ES** (legacy), or **Auto**.',
          'Preference persisted across sessions with instant apply on change.',
          'Exposed in UAC2 settings and Rust debug state.',
          '`AudioApiPreference` enum with FFI getter/setter and Dart bridge.',
        ],
      ),
      ChangelogSection(
        title: 'Blurred Backgrounds Everywhere',
        bullets: [
          '`BlurredSongBackground` widget wraps all library screens for a consistent glass look.',
          'Fade-only route transition keeps the background stable between screens.',
          'Applied to songs, recently played, recently added, queue, favorites, playlists, folders, artists, and albums.',
        ],
      ),
      ChangelogSection(
        title: 'Orbit Customization',
        bullets: [
          'Dedicated orbital settings screen — tune geometry, sizing, depth, art resolution, and visual toggles.',
          'Orbit parameters live in `AppPreferences` with setters and reset.',
          '`SongCard` sizing is now fully configurable.',
          'Orbit config passed into `OrbitView` as widget fields; unused constants removed.',
        ],
      ),
      ChangelogSection(
        title: 'Album Artwork Stretch',
        bullets: [
          'Album artwork can now stretch to fill the card — toggle from Library settings.',
          'Single-image album display with stretch support.',
          '`albumsStretchArtwork` preference.',
        ],
      ),
      ChangelogSection(
        title: 'Lyrics Performance',
        bullets: [
          'In-memory cache with timeout reduces redundant API calls on repeated lyrics searches.',
          'Shared HTTP client prevents connection pool exhaustion.',
          'Exact and fuzzy lyrics searches now run in parallel — first match wins.',
        ],
      ),
      ChangelogSection(
        title: 'Streaks & Preference Controls',
        bullets: [
          'Streaks can be disabled entirely with a reset option — clears all streak data.',
          'Day streak milestone hidden when streaks are disabled.',
          '"More from Artist" and "More Artists" sections on album detail screens can be toggled independently.',
          'Display preferences added to artist sort sheet.',
        ],
      ),
      ChangelogSection(
        title: 'Artwork Reliability',
        bullets: [
          'Only cache confirmed-existing artwork paths — prevents phantom thumbnails.',
          'Prefer songs with embedded album art for source path fallback.',
          'Artwork source path picks the song whose art matches the album art.',
        ],
      ),
      ChangelogSection(
        title: 'UI Polish & Fixes',
        bullets: [
          'Engine selector refactored to use glass bottom sheet with hero gradient styling.',
          'Songs screen header now responsive with `Flexible` labels.',
          'Drag near screen edge no longer accidentally triggers song navigation.',
          'Sort sheet dismiss margin fixed; redundant `Navigator.pop` calls removed.',
          'Docs: audio preload scan plan, scan details revamp, audio analysis feature requests.',
        ],
      ),
    ],
  ),
  ChangelogEntry(
    version: '0.20.3-beta.4',
    date: '2026-06-30',
    sections: [
      ChangelogSection(
        title: 'Full Player Refactor & Widgets',
        bullets: [
          '`FullPlayerScreen` refactored into composable widgets: `PlayerControls`, `PlayerActionButtonRow`, `AnimatedSongScene`, `AnimatedAlbumArt`.',
          'Multi-layout player support — the scene widget adapts to different player configurations.',
          'Vinyl morph and rotation seek extracted into `AnimatedAlbumArt` for reuse.',
          'Player action bottom sheets: song actions (queue, favorite, playlist add, share, delete), volume control, playback speed, sleep timer, player layout customization.',
          '`PlayerNavigation` class centralizes queue and navigation actions.',
          '`VisualizerArtBox` widget with frame and shadow styling.',
          'Duration formatting utility shared across the player.',
          'Interactive seek lifecycle fix — suppresses engine position writes during drag, cleans up on widget dispose.',
        ],
      ),
      ChangelogSection(
        title: 'Lyrics Panel & Waveform',
        bullets: [
          '**Inline lyrics panel** with synced and plain lyrics views — sing along without leaving the player.',
          'Lyrics mode waveform strip with swipe gesture for switching to lyrics view.',
          'Animated arrow indicator for the lyrics swipe affordance.',
          'Waveform layer extracted for reusable progress bar styling.',
        ],
      ),
      ChangelogSection(
        title: 'Multi-Artist Album Grouping',
        bullets: [
          'Album grouping refactored to support multi-artist compilations — tracks from the same album with different artists now group correctly.',
          'Album filtering narrowed to match only `albumArtist` field.',
          'Unit tests for `SongRepository.resolveGroupArtist` covering compilation edge cases.',
        ],
      ),
      ChangelogSection(
        title: 'Artwork Performance',
        bullets: [
          'Artwork extraction paused during scroll to prevent scroll jank.',
          'Debounced extraction pause — waits for scroll momentum to settle before resuming.',
          'Always decode at 2× art size to prevent OOM on fast fling through large libraries.',
          'Path existence checks memoized to avoid redundant filesystem I/O.',
        ],
      ),
      ChangelogSection(
        title: 'Widget Sync Fix',
        bullets: [
          'Widget playback state synced when the audio service is killed and restarted.',
          '`updateAllWidgets` helper on `WidgetPrefs` for batch widget refresh.',
        ],
      ),
      ChangelogSection(
        title: 'Queue Settings & Playlist Context',
        bullets: [
          'Dedicated **Queue Settings** screen with wrap-around toggle — moved from Playback settings.',
          'Playlist context passed when tapping a recently played or recently added song — scrobbling and shuffle now scoped correctly.',
        ],
      ),
    ],
  ),
  ChangelogEntry(
    version: '0.20.2-beta.3',
    date: '2026-06-27',
    sections: [
      ChangelogSection(
        title: 'Bluetooth Codec Control',
        bullets: [
          '**Bluetooth Hi-Res Direct mode** — forces the highest-quality codec path for capable headphones.',
          'Per-codec preference controls with persistence (AAC, aptX, LDAC, etc.).',
          'Codec preferences applied on Bluetooth init and on device connect.',
          'Device connection state tracking with codec configuration feedback.',
          'Hi-Res Direct mode resolved before low-latency in audio route selection.',
          'Bluetooth settings refactored with codec control, device filtering, and UI refinements.',
          'Developer mode toggle in Bluetooth settings for advanced codec debugging.',
        ],
      ),
      ChangelogSection(
        title: 'Glance Cards & Albums',
        bullets: [
          'Glance card visibility toggle — show, hide, or minimize the Quick Access card on the menu screen.',
          'Per-card hidden and minimized preferences persisted across sessions.',
          '`AlbumsScreen` migrated to `ConsumerStatefulWidget` (Riverpod) with app preferences integration.',
          'Single-art and empty-art edge cases handled; album year displayed on album cards.',
          '`AlbumArtPickerBottomSheet.show()` returns change status for reactive UI updates.',
          'Stale song provider prevented on in-place album art updates.',
        ],
      ),
      ChangelogSection(
        title: 'Streak & Milestone Polish',
        bullets: [
          'Animated shimmer streak number replaced with static tier-colored text for performance.',
          'Dynamic tier colors and glow effects on the streak popup banner.',
          'Tier-based shimmer effect on streak popup background.',
          'Tier color and count helpers added to `MilestoneCategoryX`.',
          'New tests for milestone tier colors and counts.',
        ],
      ),
      ChangelogSection(
        title: 'USB Audio Fixes',
        bullets: [
          '**Write-only USB clocks** supported — trusts `SET_CUR` when readback is unavailable from the device.',
          'USB permission `PendingIntent` fixed for devices that don\'t support explicit packages.',
        ],
      ),
      ChangelogSection(
        title: 'Artwork Cache Improvements',
        bullets: [
          'Embedded album art normalized before caching for consistent lookups.',
          'Content-based cache keys replace path-based keys — same art from different files shares one cache entry.',
        ],
      ),
      ChangelogSection(
        title: 'Queue & Playback',
        bullets: [
          'Playlist restart from end when wrap-around queue is enabled.',
          'Duplicate recently-played entry check removed — prevents missing play-count updates.',
        ],
      ),
      ChangelogSection(
        title: 'Debug & Developer',
        bullets: [
          'Debug logging added to audio strategy and decoder selection paths.',
          'Feature requests tracking document added to docs.',
        ],
      ),
    ],
  ),
  ChangelogEntry(
    version: '0.20.1-beta.2',
    date: '2026-06-24',
    sections: [
      ChangelogSection(
        title: 'AutoEQ Headphone Matching',
        bullets: [
          'Browse and apply AutoEQ presets by headphone brand and model — find your headphones in the catalog and auto-tune the EQ.',
          'AutoEQ brand catalog with searchable bottom sheet.',
          'Pre-bundled AutoEQ brand/model asset files.',
          'AutoEq catalog service handles preset lookup and JSON parsing.',
          'Dev-only catalog generator for maintaining the AutoEQ database.',
          'LSC and HSC band type codes correctly mapped to low/high shelf filter types.',
        ],
      ),
      ChangelogSection(
        title: 'App Logging System',
        bullets: [
          'In-app log viewer screen (Settings → UAC2 → Developer → Logs) for real-time debugging.',
          'Singleton `AppLog` with change notifications for reactive UI updates.',
          'Log sink FFI bridging Rust `dev_eprintln!` output into the Dart log system.',
          'Developer debug output forwarded to the logging sink.',
          'Default error handler catches uncaught exceptions and writes them to the log.',
          'Audio probe format exposed via FFI for USB device diagnostics in logs.',
        ],
      ),
      ChangelogSection(
        title: 'Library Warmup',
        bullets: [
          'Background metadata extraction runs after the first scan — populates missing album art, year, genre without blocking the UI.',
          '`BackgroundMetadataService` extracted as a shared Riverpod provider.',
          'Snackbar notifies when warmup starts and completes.',
          '`countIncompleteMetadataSongs` on `SongRepository` tracks warmup progress.',
        ],
      ),
      ChangelogSection(
        title: 'Recently Added Screen',
        bullets: [
          'New "Recently Added" screen with paginated song list accessible from Quick Access.',
          '`getRecentlyAddedSongs` on `SongRepository` with cursor-based pagination.',
          'Quick access menu entry added.',
        ],
      ),
      ChangelogSection(
        title: 'Visualizer & Display Settings',
        bullets: [
          'Refresh rate mode setting — choose between auto, 60Hz, 90Hz, or 120Hz.',
          'Visualizer on/off toggle with independent settings screen.',
          '`DisplayModeWrapper` migrated to Riverpod with multi-mode support.',
          'Visualizer state passed to mini player and full player; disabled visualizer skips the render pipeline.',
        ],
      ),
      ChangelogSection(
        title: 'Floating Island Toggle',
        bullets: [
          'Floating island (mini-player overlay) can now be toggled on/off from Settings → Playback → Display.',
          'Preference check before showing the floating mini player.',
        ],
      ),
      ChangelogSection(
        title: 'Wrap-Around Queue Playback',
        bullets: [
          'Queue wraps around: when the last track in the queue finishes, playback jumps back to the first.',
          'Toggle in Settings → Playback.',
        ],
      ),
      ChangelogSection(
        title: 'Fingerprint Cache Reliability',
        bullets: [
          'Fingerprint cache cleared on database incompatibility (Isar rebuild).',
          'Cache cleaned up when a folder is removed from the library.',
          'Orphaned cache entries filtered on reload.',
          'Cache cleared on full database rebuild.',
        ],
      ),
      ChangelogSection(
        title: 'Performance Improvements',
        bullets: [
          'Recently Played screen refactored to pre-build row objects for `ListView`.',
          'Recently Added screen builds rows list for sliver-based rendering.',
          'Folder list converted to `SliverList` for smoother infinite scrolling.',
          'Album group computation memoized in artist detail screen.',
        ],
      ),
      ChangelogSection(
        title: 'USB Audio & Engine Fixes',
        bullets: [
          '**Isochronous feedback polling** enabled for Android USB output — improves clock sync with external DACs.',
          'AAudio exclusive mode guarded by Android API level check (API 26+).',
          'Mid-stream USB fallback handles Rust backend refusal gracefully.',
          'Unknown USB speed inferred from sysfs and supported sample rates.',
          'Custom `CacheManager` with configurable stale period for artwork.',
          'Artwork cache management added to Library settings.',
        ],
      ),
      ChangelogSection(
        title: 'Lyrics & Share Cards',
        bullets: [
          'Lyric share card gains dynamic font sizing and dedicated font size controls.',
          'False lyrics scroll jump on transient position dips fixed.',
        ],
      ),
      ChangelogSection(
        title: 'Polish & Cleanup',
        bullets: [
          'Rotary knob drag precision improved for smoother EQ adjustments.',
          'README rewritten with concise overview, UAC 2.0 API docs, and transparency section.',
          'Stale ponytail comments, outdated developer notes, and obsolete comments removed across the codebase.',
        ],
      ),
    ],
  ),
  ChangelogEntry(
    version: '0.20.0-beta.2',
    date: '2026-06-21',
    sections: [
      ChangelogSection(
        title: 'Compact Home Widget',
        bullets: [
          'New 2×2 compact widget with text and transport controls — add from your launcher\'s widget picker.',
          'Compact-specific preferences with dedicated settings tab.',
          'Widget settings screen gains swipe gesture between tabs and animated transitions.',
          'Semi-transparent scrim overlay on mini player widget; visibility matches album art presence.',
        ],
      ),
      ChangelogSection(
        title: 'Milestone Streaks & New Tiers',
        bullets: [
          '**Day streak tracking** — consecutive days of listening, with motivational flame icon popup and snooze.',
          '**Unique artist count milestone** — tracks distinct artists played over lifetime.',
          '**Emerald tier** added for new milestone thresholds.',
          'Streak popup with animated day-cell grid and motivational messages.',
          'Milestones grouped by category with collapsible sections in the collection view.',
          '`MilestoneService` refactored with category-based current-value tracking.',
          'New tests for streak and unique-artist milestone logic.',
        ],
      ),
      ChangelogSection(
        title: 'Audio Convolver — Impulse Response Reverb',
        bullets: [
          '**Direct-time-domain convolver** processes impulse response (IR) files for convolution reverb.',
          'Offline IR loader supports standard WAV IR files.',
          'Full control API: enable/disable, dry/wet mix, load IR, clear.',
          'Integrated into the equalizer service with persistent `ConvolverSettings`.',
          'Convolver section added to the equalizer screen in Settings.',
          'Rust public API (`convolver_enable`, `convolver_mix`, `convolver_load_ir`, `convolver_clear`).',
        ],
      ),
      ChangelogSection(
        title: 'Crossfade Engine (Rust)',
        bullets: [
          'Crossfade between tracks in the Android audio engine — no more abrupt transitions.',
          '`CrossfadeCurve` enum with configurable fade curves.',
          'Pending crossfade configuration via atomics survives engine recreation.',
          'Applied automatically on audio state update.',
          'Dart FFI API for pending crossfade and DSD override options.',
          'Crossfade tests for the Android audio engine.',
          'Reliability note for non-standard engine paths.',
        ],
      ),
      ChangelogSection(
        title: 'DSD Transport Overrides',
        bullets: [
          'Per-device DSD byte-order and subslot overrides for USB Direct transport.',
          'Unified quirk database drives `sub_slot_size`, `bit_order`, and `byte_reverse` settings.',
          'Override preferences synced to the Rust engine before playback starts.',
          '24-bit DSD over USB DoP with corrected bits-per-frame calculation.',
          'DSD ring rate fix and payload integrity checks.',
          'UAC2 alt-settings probed for DSD/DoP capability before stream start.',
        ],
      ),
      ChangelogSection(
        title: 'Removable Storage & SAF Scanning',
        bullets: [
          '**Removable storage scanning** via Android SAF — SD cards and USB drives now scannable.',
          'Per-volume MediaStore support with `mediaStoreVolume` on `FolderEntity`.',
          '`FolderEntity` gains `isRemovable` and `volumeState` fields.',
          'Volume info resolved when adding a music folder; external status label on root folder card.',
          'USB/removable status displayed inline during deep scans.',
          'Handles unmount events gracefully with instant SAF scan fallback.',
          'SAF tree walk refactored to `contentResolver.query` per directory for faster traversal.',
          'Tests for removable volume handling in `MusicFolderService`.',
        ],
      ),
      ChangelogSection(
        title: 'Bluetooth Management',
        bullets: [
          '**Bluetooth settings screen** with codec info (A2DP) and device management.',
          'Bluetooth service layer with device and codec DTOs.',
          'A2DP codec detection and battery level display for connected devices.',
          '**Low-latency mode** preference — selects Rust Oboe engine for Bluetooth to minimize latency.',
          '**Pause-on-disconnect** setting automatically pauses playback when Bluetooth drops.',
          '**Reconnect resume** — playback resumes when the Bluetooth device reconnects.',
          'Bluetooth connect permission added for Android 12+ compatibility.',
        ],
      ),
      ChangelogSection(
        title: 'Metadata Editor Improvements',
        bullets: [
          'Tag write verification with typed outcomes (success, permission-denied, format-unsupported, etc.).',
          'Metadata validation before save with improved error reporting.',
          'Original file copied to temp path before writing tags — safe rollback on failure.',
          'SAF fallback for tag writes on Android scoped storage.',
          'Write URI permission requested and persisted alongside read permission.',
        ],
      ),
      ChangelogSection(
        title: 'Albums & Search',
        bullets: [
          'Album list view mode with multi-selection actions.',
          'Queue all songs button on album detail screen.',
          'Search playback mode preference — control what happens when tapping a search result.',
        ],
      ),
      ChangelogSection(
        title: 'UI Polish & Cleanup',
        bullets: [
          'Removed "Player" from app name — now simply "Flick". Google Play badge added to README.',
          'Lyric font size increased to 34 and max lines to 4 for better readability.',
          '"Flick Replay" browse chip highlighted with accent style.',
          'Scan settings animation replaced with `AnimatedSize` and `AnimatedOpacity`.',
          'Duplicate group card extracted into standalone stateful widget.',
          '"Show in Files" action replaced with share functionality.',
          'Flutter migrator properties added to Gradle config.',
          'Unused imports, dead auto-sync guard code, and deprecated test file removed.',
          '`SizeTransition` `axisAlignment` deprecation fixed.',
          'Vendored and generated files excluded from static analysis.',
        ],
      ),
    ],
  ),
  ChangelogEntry(
    version: '0.19.1-beta.2',
    date: '2026-06-18',
    sections: [
      ChangelogSection(
        title: 'Home Widgets Redesigned',
        bullets: [
          '**Mini player widget** redesigned with bitmap text rendering for RemoteViews font compatibility across Android versions.',
          '**WidgetTextRenderer** class extracts text-to-bitmap rendering, making widget labels crisp on all devices.',
          '**Flagship 2×2 widget** enabled — redesigned layout with transport controls, shuffle/repeat buttons, accent color support, and per-widget content settings.',
          'Widget art loading with max-pixel-dimension parameter for performance.',
          'Removed unused widget drawables, themes, progress drawable preferences, and dead layout code.',
        ],
      ),
      ChangelogSection(
        title: 'Crossfade Fixes & Polish',
        bullets: [
          '**Crossfade advance pending flag** prevents duplicate track advancement during crossfade transitions.',
          'Crossfade state tracking moved to `RustAudioService` for accurate lifecycle management.',
          'Crossfader diagnostics improved with stream restart on Oboe interruption.',
          '`rebind_sample_rate` preserves crossfader settings across sample rate changes.',
          'Prevent redundant crossfade re-queuing on duration-change events.',
          'Separate configured vs. active crossfade durations — fade clamps to half the track length.',
          'Crossfade forces DSP audio path; suppressed under 432 Hz tuning.',
          'Crossfade section tagged as experimental in settings.',
        ],
      ),
      ChangelogSection(
        title: 'Help & Manual System',
        bullets: [
          '**Manual screen** with search bar and collapsible sections covering all app features.',
          'Full manual data models with organized help content across the entire app.',
          '**Tutorial overlay** with dynamic spotlight positioning that highlights UI elements.',
          'Tutorial target registry and anchor widget for consistent tutorial UI.',
          '`TutorialStep` enum refactored with metadata (title, description, target).',
          'Help & Manual section added to Settings.',
          'Song search bar and sort button wrapped in tutorial targets.',
          'Nav bar and mini player wrapped in tutorial targets for guided onboarding.',
        ],
      ),
      ChangelogSection(
        title: 'Songs Screen: Album Grid Mode',
        bullets: [
          'Songs screen refactored from folder-based grouping to album-based grid mode.',
          'Album-based sorting replaces folder sort option.',
          'Folder sort option removed in favor of album sort.',
        ],
      ),
      ChangelogSection(
        title: 'Folder Tree View',
        bullets: [
          'New folder tree view mode with expandable hierarchy, glass styling, and guide lines.',
          'Toggle between grid and tree view for folder browsing.',
        ],
      ),
      ChangelogSection(
        title: 'Nav Bar & Bottom Sheet Polish',
        bullets: [
          '`FlickNavBar` converted to `StatefulWidget` with directional slide animation on item select/deselect.',
          'Removed sliding animation from nav bar items for simpler interaction.',
          'Bottom sheets dismiss on tap outside.',
          'Optional tag badge on `SettingsSectionHeader` for marking experimental features.',
        ],
      ),
      ChangelogSection(
        title: 'Artwork Card Frame',
        bullets: [
          'Optional glass frame around album art cards — toggle in Settings.',
          '`showArtworkCardFrame` preference with persistence.',
          'Artwork sizing adjusted to accommodate the frame.',
        ],
      ),
      ChangelogSection(
        title: 'Audio Engine & UAC1',
        bullets: [
          '**UAC1 sample rate handling** via endpoint SET_CUR requests for older UAC 1.0 devices.',
          'Audio engine defaults to `rustOboe` only when `exoPlayer` preference is selected.',
          'Refined DAP shared path logic and audio engine selection UI.',
        ],
      ),
      ChangelogSection(
        title: 'UI Polish',
        bullets: [
          'Milestone collection grid switched to list layout for cleaner scrolling.',
          '`AnimatedCrossFade` replaced with `AnimatedSize` for smoother section expansion in settings.',
          'Removed unused manual screen sections; extracted entry content widget.',
          'Tutorial overlay logic and state management refactored.',
        ],
      ),
    ],
  ),
  ChangelogEntry(
    version: '0.19.0-beta.1',
    date: '2026-06-15',
    sections: [
      ChangelogSection(
        title: 'ListenBrainz Scrobbling',
        bullets: [
          'Full offline-safe ListenBrainz scrobbling with queued submissions via SharedPreferences persistence.',
          '**ListenBrainz API client** with rate-limit handling (respects retry-after headers).',
          '**ListenBrainzAuthService** for token validation and session management.',
          '**Freezed models** for session tokens and listen entries (track metadata, timestamps).',
          'Track-start and track-end scrobble events on app resume.',
          'Settings tile under Settings → Integrations.',
        ],
      ),
      ChangelogSection(
        title: 'Floating Player Overlay',
        bullets: [
          'Android floating mini-player overlay (SYSTEM_ALERT_WINDOW) with drag-to-move and tap-to-open.',
          'Lifecycle-aware pause/resume handlers integrated into audio service.',
          '"Keep Playing on Quit" setting prevents audio shutdown when exiting the app.',
          'Floating player toggle in Settings → Playback.',
          'Configurable mini-player swipe action (open visualizer, next track, etc.).',
          'Floating player integrated across all screens — albums, artists, playlists, folders, equalizer.',
          'Nav bar visibility enforced on every screen so the player is always reachable.',
        ],
      ),
      ChangelogSection(
        title: 'Playback Modes Overhaul',
        bullets: [
          '**AdvanceListOrder**: choose how playback advances — by album, artist, folder, playlist, or default.',
          '**ShuffleMode** categories: off, shuffle all, shuffle within source context.',
          '**PlaybackContext** model tracks the current playback source (album, artist, folder, playlist) for scoped shuffle and advance.',
          'A-B repeat mode for looping a section of a track.',
          'New loop modes: off, track, context, all.',
          'Long-press shuffle/loop buttons now open mode selection bottom sheets instead of cycling blindly. Snackbar feedback on change.',
          'Playback modes restored when resuming the last played song.',
          'Icons for each advance mode category.',
        ],
      ),
      ChangelogSection(
        title: 'Experimental 432 Hz Tuning',
        bullets: [
          'A4=432 Hz pitch tuning via Rust FFI, toggled from Settings → Audio → UAC2.',
          'Preference persisted across sessions with confirmation dialog before enabling.',
          '432 Hz cache initialized alongside the audio session manager.',
          'Integration with bit-perfect mode defaults.',
        ],
      ),
      ChangelogSection(
        title: 'Bass / Mid / Treble Tone Controls',
        bullets: [
          'Three-band tone stack (bass, mid, treble) layered on top of the 31-band parametric EQ.',
          'Per-band offset affects the EQ graph rendering, hit detection, and parametric curve building.',
          'BMT fields added to `EqPreset` for preset import/export.',
          'Smooth animated transitions on equalizer `RotaryKnob` controls.',
          'Animated slider widget extracted for reuse across the EQ band editor.',
        ],
      ),
      ChangelogSection(
        title: 'Opus Audio Codec',
        bullets: [
          'Vendored **opus-sys** crate with full Opus 1.x sources — CELT + SILK codecs.',
          'Multi-architecture optimizations: SSE4.1, ARM NEON, ARM EDSP, MIPSr1.',
          'Opus decoder Rust bindings integrated into the audio pipeline.',
          'OGG container extension hints normalized; custom Opus decoder support for `.opus` files.',
          'Includes training scripts, fuzzers, and unit tests for SILK and CELT components.',
        ],
      ),
      ChangelogSection(
        title: 'Recently Played Redesign',
        bullets: [
          'Paginated loading replaces infinite scroll — smoother performance on large histories.',
          'Smart date grouping: entries grouped by Today, Yesterday, This Week, and older months.',
          'Reactive song info in bottom sheet actions updates without full rebuild.',
        ],
      ),
      ChangelogSection(
        title: 'Developer Mode & Logging',
        bullets: [
          '**Developer mode toggle** in Android `MainActivity` via JNI. When off, verbose logging is suppressed.',
          '`devLog` utility replaces all `debugPrint` calls across ~20 Dart services — output gated behind developer mode.',
          '`dev_eprintln!` macro replaces `eprintln!` in Rust for USB, audio debug, and DSD transport logging.',
          'Zero-cost logging path when developer mode is disabled.',
        ],
      ),
      ChangelogSection(
        title: 'Vinyl Record & Animations',
        bullets: [
          'Shared **VinylRecord** widget component — custom-painted radial-gradient disc with grooves and label area — replaces inline implementations across the player and milestone screens.',
          'Album art scope toggle: display vinyl from a single song\'s art or the whole album\'s art.',
          'Vinyl mode state tracked per-player to prevent gesture conflicts during rotation.',
          'Waveform seek bar and line seek bar now animate in on song change via `appearProgress`.',
          'Waveform layer nests its animation inside a consumer for reactive updates.',
          'Mini-player song changes animate with a directional slide transition.',
        ],
      ),
      ChangelogSection(
        title: 'Scanner & Library UX',
        bullets: [
          'Scanner backend migrated from `jwalk` to `walkdir` for simpler, more maintainable directory traversal.',
          'Scanning UI replaced bottom sheet with a fullscreen overlay and a scan-complete summary sheet.',
          'Pending-rescan flag prevents missed scanner events during concurrent processing.',
          'Auto library sync fires on app resume — keeps the database fresh without manual scans.',
        ],
      ),
      ChangelogSection(
        title: 'Song Deletion & MediaStore',
        bullets: [
          'Static `removeFromMediaStore` method for safe file removal from Android\'s MediaStore database.',
          'Song deleted from the Isar repository before the file is removed from disk.',
          'MediaStore removal fallback in `deleteDocumentViaSaf` for content URI files.',
          'Confirmation dialog before song deletion.',
        ],
      ),
      ChangelogSection(
        title: 'USB Audio Improvements',
        bullets: [
          '**UAC1 sampling frequency negotiation** added for older UAC 1.0 devices.',
          'USB volume preference check — falls back to bit-perfect default (-40 dB) when no saved volume exists.',
          'Long-press gesture on album art correctly handled without triggering an accidental tap.',
          'Audio interruption handling improved with duck-aware pause/resume logic.',
        ],
      ),
      ChangelogSection(
        title: 'Code Formatting & Polish',
        bullets: [
          'Mass Rust reformatting pass — 100-column limit, consistent struct initializers, organized imports.',
          'Consistent code style across the Android Direct USB module, audio engine, DSD decoder, and UAC2 APIs.',
          'Dismissible update notice with slide-fade animation on the menu screen.',
          'Reactive `FolderEntity` cached with `FutureBuilder` to avoid redundant deep-scan lookups.',
          'Album art bitmap cached to avoid redundant decoding per render frame.',
          'NaN guards on non-finite scale and opacity values in visualizer rendering.',
          'Auto-focus search field preference (Settings → Interface) — only auto-focuses the keyboard when enabled.',
          'Volume button added to player action buttons with a bottom-sheet volume control.',
          'Equalizer initialized on app start and reapplied across audio session changes.',
        ],
      ),
    ],
  ),
  ChangelogEntry(
    version: '0.18.0-beta.1',
    date: '2026-06-07',
    sections: [
      ChangelogSection(
        title: 'UAC 1.0 & 2.0 Descriptor Parsing',
        bullets: [
          'USB Audio Class 1.0 and 2.0 descriptor parsing with version detection (header, unit, endpoint). Split version-specific structs and types.',
          'UAC 1.0/2.0 class constants for descriptors, controls, and requests.',
          'Active descriptor parsing via UAC2 interfaces with unified quirk database fallback.',
          'Generic USB audio device model for UAC2 compatibility.',
          'USB diagnostics refactored with UrbTransportInfo model for transport data isolation.',
        ],
      ),
      ChangelogSection(
        title: 'DSD Bit Order & Native USB Direct',
        subsections: [
          ChangelogSubsection(
            title: 'DsdBitOrder & Quirks',
            bullets: [
              '**DsdBitOrder enum** (LSB/MSB) with per-source detection across all DSD format decoders (DSF, DFF, WavPack). Bit order normalization in the DSD output router.',
              '**Global DSD bit reverse override:** `set_dsd_bit_reverse_override()` FFI function exposing manual byte-order control to Flutter.',
              '**USB native DSD output:** `AndroidDirectUsbPlaybackFormat` now carries `dsd_bit_rate`. Multi-byte interleaved USB payload packing with configurable endianness.',
              '**DSD quirks table:** `KNOWN_DSD_QUIRKS` with per-device entries (vendor/product IDs, endianness, bit reversal, preferred subslot size). Includes MOONDROP Dawn Pro quirk.',
              '**DoP word building refactored** into reusable `build_dop_word()` method with I32 packing for integer streams.',
              '**Default DSD bit rate initialization** for newly configured USB playback formats.',
            ],
          ),
          ChangelogSubsection(
            title: 'DSD Hardware Transport',
            bullets: [
              '**UAC2 feature enabled by default:** Multi-byte DSD slots now active without opt-in.',
              '**Pipeline mode based on output strategy:** `PipelineMode::Dop` set for USB DSD Native and DSD DoP strategies (bit-perfect passthrough). `Passthrough` for PCM bit-perfect. `Dsp` for standard processing.',
              '**DAP flag in native DSD detection:** DSD Native mode now considered available on DAP devices even without explicit DSD encoding support.',
              '**Transport labels made descriptive:** Debug transport labels updated from short codes to `usb-native-dsd-u{subslot}x{bits}-bit`, `usb-dop-{bits}-bit`, `usb-pcm`.',
              '**`DsdBitOrder` passed through DSD decoder thread** to `DsdOutputRouter` for per-track byte normalization.',
            ],
          ),
          ChangelogSubsection(
            title: 'Integer (I32) Stream Support',
            bullets: [
              '**`AndroidManagedStreamKind` enum:** Replaces hardcoded f32 stream with `F32` and `I32` variants.',
              '**`AndroidOutputCallbackI32`:** Reads f32 from pipeline, extracts raw bit patterns via `f32::to_bits()`, writes i32 to AAudio — preserving DoP markers and DSD data intact.',
              '**`open_android_output_stream()`** gains `use_integer_format` parameter; opens i32 stream with format conversion disabled for DoP/native DSD on DAP.',
              '**Fallback stream logic** adapted to work with both f32 and i32 streams.',
            ],
          ),
        ],
      ),
      ChangelogSection(
        title: 'Artist & Playlist Theming',
        bullets: [
          '**ArtistEntity** (Isar collection): `id`, `name` (unique, case-insensitive), `artPath` (nullable). Auto-generated Isar bindings.',
          '**ArtistRepository:** `getByName()`, `setArt()`, `clearArt()` for persistent artist art path caching.',
          '**ArtistDetailScreen:** Migrated from `StatefulWidget` to `ConsumerStatefulWidget` (Riverpod). Dynamic color theming via `ColorExtractionService` from resolved album art. Full-bleed artist image background with animated tinted app bar. Removed old circular avatar + stat chips layout.',
          '**PlaylistDetailScreen:** Dynamic playlist color from most-played song\'s album art via `getMostPlayedSongAmong()`. `TweenAnimationBuilder` tinted background. Info chips (track count, total duration, created/updated dates). "Other Playlists" horizontal section. Back button repositioned to overlay. Removed 4-tile cover grid.',
          '**`getMostPlayedSongAmong()`** in `RecentlyPlayedRepository`: Returns most-played song from a given list for playlist color extraction.',
        ],
      ),
      ChangelogSection(
        title: 'Vinyl Disc & Gesture Seeking',
        bullets: [
          '**Vinyl disc morph animation:** Tap album art to morph into a spinning vinyl record. `_VinylDiscPainter` draws radial-gradient disc with grooves and highlight. `_morphController` (700ms) controls transition; `_spinController` (16s rotation) spins the disc. Album art shrinks to center label size. Song change resets to art mode. Haptic feedback on toggle.',
          '**Rotational gesture seek control** on album art with haptic feedback.',
          '**Vinyl outline animation** on single tap to enable rotation seeking.',
          '**Album color in visualizer preview:** `_buildVisualizerPreview()` reads `albumColorModeProvider` and passes album color when mode is not `off`.',
        ],
      ),
      ChangelogSection(
        title: 'Navigation Bar Auto-Collapse',
        bullets: [
          'FlickNavBar auto-collapse with animated transitions after idle timer.',
          'Configurable auto-collapse behavior and timer duration via preferences.',
          'Collapsed state with smooth animated reveal on interaction.',
        ],
      ),
      ChangelogSection(
        title: 'Milestone Card Redesign & Collection',
        bullets: [
          'Redesigned milestone celebration card with per-tier accent color (bronze / silver / gold / sapphire / amethyst), large hero icon, tinted border + glow, and a subtle "next milestone — N to go" hint line',
          'New achievement-style collection view (Settings → Milestones) listing all five tiers in a grid; unlocked tiles re-open the celebration card with the achieved date, locked tiles show a progress bottom sheet',
          'Settings → About → Milestones tile shows a live "X / 5 unlocked" counter',
          'Five new `AppColors` milestone tint constants and per-tier `tierIcon` / `tierColor` / `shortLabel` / `threshold` / `isTopTier` getters on `MilestoneTypeX`',
          'New `MilestoneService.getNextMilestone()` helper for "next unshown tier + remaining units" (used by the popup and the locked-tile sheet)',
          '`MilestoneService` constructor now accepts an optional `playCountOverride` for unit testing without Isar',
          'New test suite: `test/services/milestone_service_test.dart`',
        ],
      ),
      ChangelogSection(
        title: 'What\'s New System',
        bullets: [
          'What\'s New bottom sheet shown on first launch after update.',
          'Structured changelog data model with versioned entries and sections.',
          'Changelog-aware provider with `lastSeenChangelogVersion` preference.',
          'Version constants (`kAppVersion`, `kAppBuild`, `kAppVersionLabel`) in `app_constants.dart`.',
        ],
      ),
      ChangelogSection(
        title: 'Ambient Background Removed',
        bullets: [
          'Ambient background decoration removed from songs, albums, artists, playlists, favorites, and folders screens.',
          'Ambient background toggle removed from settings and playback display.',
          'Menu screen hero refactored to use `ColorExtractionService` instead of ambient background.',
        ],
      ),
      ChangelogSection(
        title: 'Folder Browser Enhancements',
        bullets: [
          'Pagination with configurable page size slider.',
          'Pinch-to-zoom gesture support with animated grid transitions.',
          'File type filter and sort options in folder browser.',
        ],
      ),
      ChangelogSection(
        title: 'Build & Compatibility',
        bullets: [
          '**minSdk stays at 26** (Android 8.0+). Core library desugaring enabled for Java 17 target.',
          '**Impeller rendering configurable** via bool resource, disabled on API 24/25, enabled on API 26+.',
          '**Isar bumped to 3.3.2** with MDBX_INCOMPATIBLE recovery: corrupt database files are deleted and the library database is recreated automatically.',
          '**V1 and V2 APK signing** enabled in release config.',
          'Notification channel creation guarded behind API 26 check.',
        ],
      ),
      ChangelogSection(
        title: 'Updates & Distribution',
        bullets: [
          'GitHub release update checks for non-Play Store builds with customized update messages.',
        ],
      ),
      ChangelogSection(
        title: 'UI Polish & Fixes',
        bullets: [
          'Play all and shuffle buttons styled as accent-colored pills with fixed width.',
          'Scroll-aware animated app bar actions on artist, playlist, and album detail screens.',
          'Song auto-added to player queue when added to a playlist.',
          'Audio info bottom sheet expanded to `ConsumerStatefulWidget` with swipeable page view.',
          'Library auto-sync refactored to event-driven with full rescan support.',
          'Equalizer initialized on app start and reapplied after audio session changes.',
          'Star animation overflow clamped; disc scale clamped to prevent zero/negative values.',
          'Ring buffer write logic fixed to handle full buffer gracefully; bluetooth devices handled more gracefully.',
          'Center logo Svg in app info settings screen.',
          'SmartMixDetailScreen back button moved to overlay position.',
        ],
      ),
    ],
  ),
  ChangelogEntry(
    version: '0.17.0-beta.1',
    date: '2026-05-31',
    sections: [
      ChangelogSection(
        title: 'Post-Release Additions',
        subsections: [
          ChangelogSubsection(
            title: 'DSD Bit Order & Native USB Direct',
            bullets: [
              '**DsdBitOrder enum** (LSB/MSB) with per-source detection across all DSD format decoders (DSF, DFF, WavPack). Bit order normalization in the DSD output router.',
              '**Global DSD bit reverse override:** `set_dsd_bit_reverse_override()` FFI function exposing manual byte-order control to Flutter.',
              '**USB native DSD output:** `AndroidDirectUsbPlaybackFormat` now carries `dsd_bit_rate`. Multi-byte interleaved USB payload packing with configurable endianness.',
              '**DSD quirks table:** `KNOWN_DSD_QUIRKS` with per-device entries (vendor/product IDs, endianness, bit reversal, preferred subslot size). Includes MOONDROP Dawn Pro quirk.',
              '**DoP word building refactored** into reusable `build_dop_word()` method with I32 packing for integer streams.',
              '**Default DSD bit rate initialization** for newly configured USB playback formats.',
            ],
          ),
          ChangelogSubsection(
            title: 'DSD Hardware Transport',
            bullets: [
              '**UAC2 feature enabled by default:** Multi-byte DSD slots now active without opt-in.',
              '**Pipeline mode based on output strategy:** `PipelineMode::Dop` set for USB DSD Native and DSD DoP strategies (bit-perfect passthrough). `Passthrough` for PCM bit-perfect. `Dsp` for standard processing.',
              '**DAP flag in native DSD detection:** DSD Native mode now considered available on DAP devices even without explicit DSD encoding support.',
              '**Transport labels made descriptive:** Debug transport labels updated from short codes to `usb-native-dsd-u{subslot}x{bits}-bit`, `usb-dop-{bits}-bit`, `usb-pcm`.',
              '**`DsdBitOrder` passed through DSD decoder thread** to `DsdOutputRouter` for per-track byte normalization.',
            ],
          ),
          ChangelogSubsection(
            title: 'Integer (I32) Stream Support',
            bullets: [
              '**`AndroidManagedStreamKind` enum:** Replaces hardcoded f32 stream with `F32` and `I32` variants.',
              '**`AndroidOutputCallbackI32`:** Reads f32 from pipeline, extracts raw bit patterns via `f32::to_bits()`, writes i32 to AAudio — preserving DoP markers and DSD data intact.',
              '**`open_android_output_stream()`** gains `use_integer_format` parameter; opens i32 stream with format conversion disabled for DoP/native DSD on DAP.',
              '**Fallback stream logic** adapted to work with both f32 and i32 streams.',
            ],
          ),
          ChangelogSubsection(
            title: 'Artist & Playlist Theming',
            bullets: [
              '**ArtistEntity** (Isar collection): `id`, `name` (unique, case-insensitive), `artPath` (nullable). Auto-generated Isar bindings.',
              '**ArtistRepository:** `getByName()`, `setArt()`, `clearArt()` for persistent artist art path caching.',
              '**ArtistDetailScreen:** Migrated from `StatefulWidget` to `ConsumerStatefulWidget` (Riverpod). Dynamic color theming via `ColorExtractionService` from resolved album art. Full-bleed artist image background with animated tinted app bar. Removed old circular avatar + stat chips layout.',
              '**PlaylistDetailScreen:** Dynamic playlist color from most-played song\'s album art via `getMostPlayedSongAmong()`. `TweenAnimationBuilder` tinted background. Info chips (track count, total duration, created/updated dates). "Other Playlists" horizontal section. Back button repositioned to overlay. Removed 4-tile cover grid.',
              '**`getMostPlayedSongAmong()`** in `RecentlyPlayedRepository`: Returns most-played song from a given list for playlist color extraction.',
            ],
          ),
          ChangelogSubsection(
            title: 'Visualizer & Player',
            bullets: [
              '**Vinyl disc morph animation:** Tap album art to morph into a spinning vinyl record. `_VinylDiscPainter` draws radial-gradient disc with grooves and highlight. `_morphController` (700ms) controls transition; `_spinController` (16s rotation) spins the disc. Album art shrinks to center label size. Song change resets to art mode. Haptic feedback on toggle.',
              '**Album color in visualizer preview:** `_buildVisualizerPreview()` reads `albumColorModeProvider` and passes album color when mode is not `off`.',
              '**SmartMixDetailScreen:** Back button moved from `SliverAppBar` leading to overlay position.',
              '**Playlist metadata helpers:** Total duration calculation and date formatting utilities.',
            ],
          ),
        ],
      ),
      ChangelogSection(
        title: 'Milestone Card Redesign & Collection',
        bullets: [
          'Redesigned milestone celebration card with per-tier accent color (bronze / silver / gold / sapphire / amethyst), large hero icon, tinted border + glow, and a subtle "next milestone — N to go" hint line',
          'New achievement-style collection view (Settings → Milestones) listing all five tiers in a grid; unlocked tiles re-open the celebration card with the achieved date, locked tiles show a progress bottom sheet',
          'Settings → About → Milestones tile shows a live "X / 5 unlocked" counter',
          'Five new `AppColors` milestone tint constants and per-tier `tierIcon` / `tierColor` / `shortLabel` / `threshold` / `isTopTier` getters on `MilestoneTypeX`',
          'New `MilestoneService.getNextMilestone()` helper for "next unshown tier + remaining units" (used by the popup and the locked-tile sheet)',
          '`MilestoneService` constructor now accepts an optional `playCountOverride` for unit testing without Isar',
          'New test suite: `test/services/milestone_service_test.dart`',
        ],
      ),
      ChangelogSection(
        title: 'BitPerfect Capsule / Indicator',
        bullets: [
          'BitPerfect status capsule displayed in the player UI showing active bit-perfect mode',
          'Visual indicator for bit-perfect audio path engagement',
        ],
      ),
      ChangelogSection(
        title: 'Player Layout Settings',
        bullets: [
          'Configurable player layout options',
          'Settings screen for customizing the player layout',
        ],
      ),
      ChangelogSection(
        title: 'Equalizer Paged Layout',
        bullets: [
          'Equalizer redesigned with a paged layout for better navigation across 31 bands',
          'Improved band browsing and adjustment workflow',
        ],
      ),
      ChangelogSection(
        title: 'Folder Filter / Sort Controls',
        bullets: [
          'Folder filtering controls for narrowing down folder listings',
          'Enhanced folder sort options with dedicated controls',
        ],
      ),
    ],
  ),
];

/// Returns the changelog entry whose version matches [version], or `null` if
/// no entry is recorded for it.
ChangelogEntry? findChangelogEntry(String version) {
  for (final entry in kChangelogEntries) {
    if (entry.version == version) return entry;
  }
  return null;
}
