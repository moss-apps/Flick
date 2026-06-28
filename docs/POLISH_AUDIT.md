# Flick — Polish Audit

> Cleanup checklist, prioritized by effort vs. payoff. Conducted **2026-06-26** via `flutter analyze` (124 issues) and source inspection.
>
> `flutter analyze` noise was dominated by (a) vendored build tooling and (b) ~50 auto-fixable import lints.

Convention: `[x]` = done, `[ ]` = open, `[~]` = in progress / blocked.

---

## ⬆️ Upgrade log (2026-06-27)

- [x] **Flutter 3.41.9 → 3.44.4.** `flutter upgrade` succeeded (~7.5m). `flutter doctor` green modulo irrelevant missing `ninja` (Linux desktop only — this is an Android app). Permissive SDK constraint (`sdk: ^3.10.4`) accommodates 3.44's Dart.
- [x] **`lucide_icons_flutter` 3.1.12 → 3.1.14+2.** 3.44 made `IconData` a `final class`; 3.1.12's `LucideIconData extends IconData` broke compilation. 3.1.14+2 dropped the subclass. Drop-in bump (`flutter pub upgrade lucide_icons_flutter`).
- [x] **Two of six 3.44 deprecation lints fixed** (see 🟡 J for deferred four): `cacheExtent` → `scrollCacheExtent` (`full_player_screen.dart:6239`, needed `import 'package:flutter/rendering.dart'`); `SizeTransition.axisAlignment` → `alignment: const Alignment(-1.0, -1.0)` (`online_lyrics_search_sheet.dart:1252`).

**Post-upgrade:** `flutter analyze lib` reports only the 4 deferred `onReorder` infos. `flutter test`: **74 pass / 1 fail** — pre-existing `widget_test.dart` smoke test (`"Your Library"` assertion), unrelated to the upgrade.

---

## 🟢 Level 1 — Quick wins (minutes, mostly mechanical)

- [x] **A. Exclude vendored build tooling from analysis.** ~60 errors in `rust_builder/cargokit/build_tool/`. Added `rust_builder/**` to `analyzer.exclude` in `analysis_options.yaml`. Also excluded generated `**/*.g.dart`, `**/*.freezed.dart`, `lib/src/**`.
- [x] **B. Delete stray root files.** `test_file_picker.dart` (broken scratch), `flutter_01.log`/`flutter_02.log` (gitignored junk).
- [x] **C. `dart fix --apply` on `lib/`.** 24 fixes across 19 files (unused `foundation.dart` imports).
- [x] **D. Remove dead code in `player_service.dart`.** Removed `_syncCurrentSongFromIndex`, `_updateAutoSyncGuardFromProgress`, then cascade-removed their only consumers (`_shouldIgnoreAutoSyncedSong`, `DateTime? _autoSyncGuardUntil` field). Remaining guard state (`_autoSyncGuardSongId`, `_armAutoSyncGuard`, `_clearAutoSyncGuard`) still live at ~line 2202.
- [x] **E. Add `test` to `dev_dependencies`.** `test: ^1.25.0` (resolved to 1.30.0); fixes `depend_on_referenced_packages`.

**Acceptance:** `flutter analyze lib` = **0 issues**. Full-project `flutter analyze` = **No issues found!**

> ⚠️ Pre-existing test failure (not caused by this slice): `test/widget_test.dart:11` ("Your Library" smoke test) fails — verified by `git stash` + re-run on clean tree. 74/75 pass. Separate bug for 🟡 backlog.

---

## 🟡 Level 2 — Medium (real upgrades)

- [~] **F. Migrate deprecated `just_audio` API — DEFERRED (not a rename).** `ConcatenatingAudioSource` is `@Deprecated('Use AudioPlayer.setAudioSources instead')` with 6 suppressions. **Deferred because:** the code uses it as a **detached mutable handle** — `player_service` builds it, hands it to `android_audio_engine`, then incrementally mutates it via `.insert()`/`.removeAt()`/`.children.length`. The new `setAudioSources` model has no such handle (edits route through async `player.insert`/`removeAudioSourceAt`). Requires field-type change at ~12 read sites + sync→async conversion + on-device queue-mutation verification. The deprecated API still works (`@Deprecated`, not removed). Re-do when refactoring for other reasons or the API is removed.
- [~] **G. Shed dependency overrides — SPLIT.** `pubspec.yaml` pins `analyzer: 8.1.1`, `dart_style: 3.1.2`, `rive_native: 0.1.4`.
  - **`analyzer` + `dart_style` → BLOCKED (load-bearing).** Upstream conflict: `riverpod_generator 4.0.4` requires `analyzer: ^12.0.0`, `isar_community_generator 3.3.2` caps `analyzer: <11.0.0`. Non-overlapping → 8.x is the only resolvable intersection. `riverpod_analyzer_utils` still on `1.0.0-dev.*` prerelease. Do **not** attempt removal.
  - **`rive_native: 0.1.4` → DONE.** Override shed; `rive: 0.14.5` requires `rive_native: ^0.1.5` (override was older). Resolved forward to 0.1.5. `flutter analyze lib` / `flutter test` unchanged.
- [x] **H. Resolve TODO — DONE (re-scoped to Share).** `song_actions_bottom_sheet.dart` "Show in Files" button was a no-op SnackBar stub. Re-scoped: no reliable "reveal in folder" intent on Android (scoped storage blocks `file://`; `ACTION_VIEW` opens a music handler, not a file manager). Now **Shares** via `share_plus` (`Share.shareXFiles([XFile(song.filePath!)])`), guarded by `song.filePath != null && !song.isExternal`. Uses installed dep, works on Android.
- [ ] **J. Migrate four `onReorder` → `onReorderItem` sites (deferred from 3.44 upgrade).** Info-level lints; semantic migration, not mechanical. `onReorderItem` pre-adjusts `newIndex` for the removed item, so each handler's manual adjustment logic must change. Touches data-integrity reorder paths.
  - `queue_screen.dart:176` (up next) and `:263` (queue): handler pre-adjusts (`newIndex > oldIndex ? newIndex - 1 : newIndex`), passes ADJUSTED index.
  - `playlist_detail_screen.dart:495`: passes RAW `newIndex`.
  - `bottom_bar_settings_screen.dart:116`: passes RAW `newIndex`.
  - `moveQueueItem` expects ADJUSTED; `moveUpNextItem` does its own internal adjust, expects RAW — `moveUpNextItem`'s caller ALSO pre-adjusts (possible latent off-by-one). Requires per-site changes + on-device verification.

---

## 🔴 Level 3 — Large (optional, high effort)

- [ ] **I. Decompose god-files.** Major maintainability debt — only pursue if actively maintained. `player_service.dart` (5118 lines / 172 KB), `full_player_screen.dart` (260 KB), `equalizer_screen.dart` (139 KB), `menu_screen.dart` (125 KB), `songs_screen.dart` (113 KB). Candidates for extraction: queue management, notification logic, audio-source building, per-section widgets.
