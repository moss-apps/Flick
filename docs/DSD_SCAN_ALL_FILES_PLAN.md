# DSD Scan + All-Files Access Plan

Goal: DSD/DSF/DFF/WV always scan on every OEM. Primary strategy: All Files Access
(`MANAGE_EXTERNAL_STORAGE`) so all normal scans use the Rust filesystem walker (UAPP-style,
MediaStore bypassed). Scoped-storage path stays fully functional as fallback with DSD fixes.

| Phase | Scope | Status |
|-------|-------|--------|
| W1 | Permission layer: `MANAGE_EXTERNAL_STORAGE` + `requestLegacyExternalStorage` in manifest; `allFilesAccess` flag in `resolveStorageInfo` (Kotlin); channel methods `hasAllFilesAccess`/`requestAllFilesAccess`; dismissible notice card + Settings → Library → Scan Settings "Full Library Access" row (status re-checked on app resume) | done |
| W2 | Scan routing: `chooseAndroidScanEngine` (pure, unit-tested) → all-files mode routes `_scanFolderRust(fsPath)` for primary AND removable; SAF fallback kept; scoped-mode routing unchanged | done |
| W3 | Scoped-mode DSD fixes in `queryMediaStoreAudio`: (a) `DsdReconciliation.findUnindexedDsdFiles` stat-only walk merged+deduped every scan (synthesized `file://` rows, `.nomedia`/dotfile aware), (b) `MediaScannerConnection.scanFile()` fire-and-forget heal, (c) ContentObserver on `MediaStore.Files` (descendants) — Kotlin JVM tests in `android/app/src/test/` | done |
| W4 | Live updates under all-files: Audio + Files observers already nudge rescans; Rust `EventDrivenScanner` inotify wiring deferred (needs FRB stream + watcher lifecycle — not cheap, next-scan latency acceptable) | done (deferred wiring) |
| W5 | Out of scope (follow-up): raw-path DSD playback on removable volumes (bypass SAF staging) | deferred |
| W6 | Tests + docs: routing tests (8), `DsdReconciliation` JVM tests (5), architecture doc + CHANGELOG updated; `flutter analyze` clean (pre-existing infos only), `flutter test`, `gradlew :app:assembleDebug` | done |
| W7 | Follow-up fix: cross-engine deletion wipe — engines only delete rows in their own URI space; SAF rows superseded via `rawPathFromSafUri` mapping (unit-tested); deletion refresh checks (`_checkDeletedPathsRust`/`Saf`) scoped the same way | done |

Notes:
- Walk is stat-only and deduped against MediaStore rows; incremental via existing fingerprint cache in `_scanFolderRust`.
- Play review risk for `MANAGE_EXTERNAL_STORAGE` accepted; off-Play fallback if rejected.
- Extension allowlists (Rust scanner, two_phase, Dart, SAF) already include dsf/dff/wv — no changes needed there.
