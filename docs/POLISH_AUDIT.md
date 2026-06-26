# Flick — Polish Audit

> A living checklist of cleanup and improvement opportunities, prioritized by effort vs. payoff.
> Conducted **2026-06-26** via `flutter analyze` (124 issues total) and targeted source inspection.
>
> **Headline:** App code is close to clean. The `flutter analyze` noise is dominated by (a) vendored
> build tooling being analyzed and (b) ~50 auto-fixable import lints. A clean analyze is ~15 min away.

Convention: `[x]` = done, `[ ]` = open, `[~]` = in progress / blocked.

---

## ⬆️ Upgrade log (2026-06-27)

- [x] **Flutter 3.41.9 → 3.44.4.** `flutter upgrade` succeeded (~7.5m). `flutter doctor` green modulo an
  irrelevant missing `ninja` for the Linux desktop toolchain (this is an Android/mobile app). The
  permissive SDK constraint (`sdk: ^3.10.4`) accommodates 3.44's Dart.
- [x] **`lucide_icons_flutter` 3.1.12 → 3.1.14+2 (forced by the upgrade).** 3.44 made `IconData` a
  `final class`; 3.1.12's `LucideIconData extends IconData` then failed to compile (broke 6 tests AND
  would break the app build). 3.1.14+2 dropped the subclass and uses plain `IconData`. App uses
  `LucideIcons.*` camelCase names + `package:lucide_icons_flutter/lucide_icons.dart` — both unchanged,
  so the bump was drop-in (`flutter pub upgrade lucide_icons_flutter`; no `pubspec.yaml` constraint
  edit needed since `^3.1.8` already admitted it — the lockfile just pinned the old one).
- [x] **Two of six 3.44 deprecation lints fixed** (see new 🟡 item J for the deferred four):
  - `cacheExtent` → `scrollCacheExtent` in `full_player_screen.dart:6239`. Auto-fix referenced the
    sealed `ScrollCacheExtent` type that `widgets.dart` doesn't re-export → added
    `import 'package:flutter/rendering.dart';`.
  - `SizeTransition.axisAlignment` → `alignment: const Alignment(-1.0, -1.0)` in
    `online_lyrics_search_sheet.dart:1252` (SDK-documented exact mapping for `Axis.vertical`).

**Post-upgrade verification:** `flutter analyze lib` reports only the 4 deferred `onReorder` infos.
`flutter test`: **74 pass / 1 fail** — the 1 fail is the pre-existing `widget_test.dart` smoke test
(`"Your Library"` assertion), unrelated to the upgrade.

---

## 🟢 Level 1 — Quick wins (minutes, mostly mechanical)

- [x] **A. Exclude vendored build tooling from analysis.** ~60 errors lived in
  `rust_builder/cargokit/build_tool/` (cargokit, build-time tooling shipped by `flutter_rust_bridge`,
  not app code). Added `rust_builder/**` to `analyzer.exclude` in `analysis_options.yaml`.
  Also excluded generated `**/*.g.dart`, `**/*.freezed.dart`, `lib/src/**` (isar/freezed/FRB code
  emits `experimental_member_use` lints — 36 of them).
- [x] **B. Delete stray root files.**
  - `test_file_picker.dart` — removed (was a broken scratch; `FilePicker.platform undefined_getter`).
  - `flutter_01.log`, `flutter_02.log` — removed (already gitignored `*.log`; local junk).
- [x] **C. `dart fix --apply` on `lib/`.** **24 fixes across 19 files** (unused/unnecessary
  `foundation.dart` imports). All mechanical and analyzer-verified.
- [x] **D. Remove dead code in `player_service.dart`.**
  - `_syncCurrentSongFromIndex` — removed.
  - `_updateAutoSyncGuardFromProgress` — removed.
  - **Cascade discovered during execution:** both methods were the only consumers of the
    auto-sync-guard, so the analyzer then flagged two more now-dead symbols, which were also removed:
    `_shouldIgnoreAutoSyncedSong` (the guard's only decision-reader) and the `DateTime? _autoSyncGuardUntil`
    field (write-only once the reader was gone; its setter/clearer lines trimmed). The remaining
    guard state (`_autoSyncGuardSongId`, `_armAutoSyncGuard`, `_clearAutoSyncGuard`) is still live —
    consumed at `player_service.dart` ~line 2202.
- [x] **E. Add `test` to `dev_dependencies`.** Added `test: ^1.25.0` (resolved to 1.30.0); fixes
  `depend_on_referenced_packages` in `music_folder_service_test.dart` and `replay_play_tracker_test.dart`.

**Acceptance:** `flutter analyze lib` reports **0 issues**. ✅ Achieved. (Full-project `flutter analyze`
also reports **No issues found!**)

> ⚠️ **Pre-existing test failure (not caused by this slice):** `test/widget_test.dart:11`
> ("Flick Player app smoke test") fails — expects text `"Your Library"` but finds 0 widgets.
> Verified by `git stash` + re-run on the clean tree: **fails identically before any changes.**
> 74/75 tests pass. This is a separate bug for the 🟡 backlog.

---

## 🟡 Level 2 — Medium (real upgrades)

- [~] **F. Migrate deprecated `just_audio` API — DEFERRED (re-appraised: not a rename).**
  `ConcatenatingAudioSource` is `@Deprecated('Use AudioPlayer.setAudioSources instead')`. 6
  `// ignore: deprecated_member_use` suppressions (player_service.dart field `_audioSourceSequence`
  + build/mutate sites; android_audio_engine.dart:411).
  - **Why deferred:** investigation showed the code relies on `ConcatenatingAudioSource` as a
    **detached mutable handle** — `player_service` builds it, hands it to `android_audio_engine`, then
    incrementally mutates it on every queue add/remove (`_insertIntoAudioSequence`,
    `_removeFromAudioSequence`, both callers live) via `.insert()`/`.removeAt()`/`.children.length`.
    The new `setAudioSources` model has no such handle — incremental edits must route through the
    **player** (`player.insert`/`removeAudioSourceAt`, both async), which means a field-type change at
    ~12 read sites, one sync method becoming async (2 callers), and an emptiness-guard change. A real
    refactor across a data-integrity (queue mutation) path.
  - **Payoff vs cost:** removes 6 lint comments, but the deprecated API still **fully works**
    (`@Deprecated`, not removed). Not worth queue-mutation risk without on-device verification.
  - just_audio 0.10.5 = latest; `setAudioSources`/`player.insert`/`removeAudioSourceAt` are available
    when this is revisited. Re-do when the code is refactored for other reasons, or the API is removed.
- [~] **G. Shed dependency overrides — SPLIT after research.** `pubspec.yaml` pins `analyzer: 8.1.1`,
  `dart_style: 3.1.2`, `rive_native: 0.1.4`, each annotated "remove once upstream fixed."
  - **`analyzer: 8.1.1` + `dart_style: 3.1.2` → BLOCKED (load-bearing).** Not stale. Root cause is an
    upstream conflict between the two code generators: `riverpod_generator 4.0.4` requires
    `analyzer: ^12.0.0`, while `isar_community_generator 3.3.2` (latest) caps `analyzer: <11.0.0`.
    The ranges don't overlap, so 8.x is the only resolvable intersection → the override is forced.
    `riverpod_analyzer_utils` (the upstream that would unblock this) is still on a `1.0.0-dev.*`
    prerelease line — no stable release. Defer until one side bumps. Do **not** attempt removal.
  - **`rive_native: 0.1.4` → DONE (override shed).** Removed the override; `flutter pub get` resolved
    `rive_native` cleanly (now `transitive`, not `direct overridden`). Reason it worked: `rive: 0.14.5`
    itself requires `rive_native: ^0.1.5`, so the override to exact `0.1.4` was actually *older* than
    what `rive` wanted — shedding lets it resolve forward to 0.1.5. `flutter analyze lib` unchanged
    (still the 4 deferred `onReorder` infos, no new issues); `flutter test` 74/75 (the 1 fail is the
    pre-existing `widget_test.dart` smoke test). Override line + its comment removed from `pubspec.yaml`.
- [x] **H. Resolve outstanding TODO — DONE (re-scoped to Share).**
  `lib/features/songs/widgets/song_actions_bottom_sheet.dart` had a `// TODO: Implement show in files
  functionality` behind a "Show in Files" button whose handler was a no-op SnackBar showing the path.
  - **Why re-scoped:** this is an **Android-only** app, and on Android there is no reliable
    cross-file-manager "reveal file in folder" intent. Scoped storage blocks `file://` via
    `url_launcher`; `ACTION_VIEW` opens the file's default handler (a music app), not a file manager.
    Making a genuine "Show in Files" would require native Kotlin (FileProvider + DocumentsContract)
    with inconsistent results across Android file managers, unverifiable on the target DAPs. The TODO
    is the tell that the original author hit this wall.
  - **Resolution:** the button now **Shares** the file via the already-installed `share_plus`
    (`Share.shareXFiles([XFile(song.filePath!)])`), guarded by `song.filePath != null && !song.isExternal`,
    label "Share", icon `LucideIcons.share2`. Lazy, functional, uses an installed dep, works on Android
    (FileProvider handled by the plugin). Honest trade: it's "Share", not "reveal in folder" — but it
    does something useful instead of being a no-op stub.
- [ ] **J. Migrate four `onReorder` → `onReorderItem` sites (deferred from the 3.44 upgrade).**
  Info-level lints; app runs, but the migration is **semantic, not mechanical**: `onReorderItem`
  pre-adjusts `newIndex` for the removed item, so each handler's manual adjustment logic must change.
  Touches data-integrity reorder paths, so faking lint-cleanliness without per-site reconciliation
  risks corrupting playlist/queue order. Sites + current behavior:
  - `lib/features/queue/screens/queue_screen.dart:176` (up next) and `:263` (queue): handler
    pre-adjusts (`newIndex > oldIndex ? newIndex - 1 : newIndex`), passes ADJUSTED index.
  - `lib/features/playlists/screens/playlist_detail_screen.dart:495`: passes RAW `newIndex` to
    `reorderSongs`; local-adjusts only the `_songs` mutation.
  - `lib/features/settings/screens/bottom_bar_settings_screen.dart:116`: passes RAW `newIndex`.
  - Provider semantics differ: `player_service.moveQueueItem` (uses index directly, expects ADJUSTED)
    vs. `moveUpNextItem` (does its own internal adjust, expects RAW) — `moveUpNextItem`'s caller ALSO
    pre-adjusts, a subtle interaction that may already be a latent off-by-one. Requires per-site
    changes + manual on-device reorder verification.

---

## 🔴 Level 3 — Large (optional, high effort)

- [ ] **I. Decompose god-files.** Major maintainability debt, but a real time investment — only
  pursue if actively maintained.
  - `lib/services/player_service.dart` — **5118 lines** (~172 KB).
  - `lib/features/player/screens/full_player_screen.dart` — **260 KB**.
  - `lib/features/settings/screens/equalizer_screen.dart` — **139 KB**.
  - `lib/features/menu/screens/menu_screen.dart` — **125 KB**.
  - `lib/features/songs/screens/songs_screen.dart` — **113 KB**.
  - Candidates for extraction: queue management, notification logic, audio-source building, and
    per-section widgets out of the screens.
