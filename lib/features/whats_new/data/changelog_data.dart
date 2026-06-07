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
