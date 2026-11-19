# Flick 0.23.3-beta.5

An equalizer tab, live and lock-screen spectrum visualizers, multi-FILE CUE support, file-only metadata, focus-aware playback, and stable/beta update channels — plus a quieter idle app.

## Equalizer

- **Equalizer as a navigation tab** — the full effects UI can now be pinned as a bottom-bar tab. The shipped default is menu, equalizer, songs, settings, and search with labels hidden; saved layouts are never rewritten, and the default is persisted only when no button list exists.
- **Embedded paging** — when the equalizer is embedded in the main pager, horizontal content swipes pass through to the parent and section changes use the tab bar; standalone behavior is unchanged.
- **Strict preset import** — manual TXT/JSON imports now validate before applying: unsupported filter types, duplicate or oversized bands, missing preamps, and malformed lines are rejected, while in-range adjustments surface localized warnings. Gain, Q, preamp, and band limits now come from one shared `EqLimits` model.
- **AutoEq Q floor and provenance** — the biquad Q floor drops to 0.1 so valid upstream AutoEq 0.18/0.19 filters survive import instead of becoming Q 0.2. Catalog entries retain upstream name, rig, revision, and target metadata, and strict parsing rejects rather than substitutes unsupported values.
- **AutoEQ online search feedback** — snackbar toasts are replaced by an inline banner for searching, found, and failed states, with a cloud search button, an empty-state fallback, keyboard-aware placement, and stale lookups invalidated when the query or brand changes.
- **Reproducible AutoEq catalog** — the generator now fetches from a pinned AutoEq commit with SHA-256-checked inputs, stages output outside `assets/`, writes reports and manifests, reports upstream omissions instead of guessing, and supports `--check` for byte-identical reruns.
- **Processing stays DSP** — EQ correction is not bit-perfect; existing processing locks, native DSD/DoP handling, and audio routing are unchanged.

## Visualizer

- **Live PCM spectrum from the engine** — a read-only tap on the audio callback computes FFT bars for the High Quality engine, while Standard playback uses Android's Visualizer after microphone permission. Direct USB, DAP native, and native/DoP DSD report unavailable instead of being converted or rerouted.
- **Stable spectrum mapping** — a 60 dB relative window with log-spaced bands, asymmetric attack/release smoothing, and a corrected capture rate (milliHertz, capped at 30 fps and the device maximum) keep the bars responsive without wild jumps.
- **Lock-screen visualizer** — an opt-in, off-by-default native Kotlin viewer renders the same six styles, colors, frequency masks, movement preferences, and block trails over the secure keyguard on pure black. It never exposes library, settings, or player navigation, requests no keyguard dismissal, and captures only while visible, awake, and playing.
- **Simulated AOD (experimental)** — an optional mode wakes the dimmed display over the keyguard while a supported song plays and Display over other apps is granted. It stops after 30 minutes, on low battery, pause or stop, an unsupported route, disabled animations, or when the feature is turned off; it is not system AOD and does not use the panel's low-power state.
- **Shared source and status** — one reference-counted visualizer source is shared by player surfaces and the lock screen. Offscreen stages stop through `TickerMode`, rebuilds no longer restart capture, and settings show the active source plus reduced-motion and unavailable notices.

## Library & Metadata

- **Multi-FILE CUE sheets** — each `FILE` block parses into its own sheet and resolves to an audio file in its own directory, so one-track-per-file rips no longer collapse onto the last file or collide on the song unique index. Stale references fall back to a unique same-stem sibling, directories are stripped from names, relative paths resolve against the CUE directory, and duplicate `INDEX` offsets are skipped.
- **Scan-time folder paths** — MediaStore, SAF quick scans, and directory scans record `relativeFolderPath` from the actual scan root and backfill legacy rows before the unchanged-file skip. Folder grouping repairs in place for libraries imported with opaque SAF document ids, without changing ids or local edits.
- **File-only metadata** — song actions and metadata sheets now read comment, full recording date, copyright, and label/organization from the file itself. Multiple comments are joined as paragraphs, year-only dates and blank values are hidden, and CUE, external, network, and pathless songs are skipped.

## Playback & Performance

- **Audio focus ownership** — the Rust engine requests focus before play, releases it on manual pause and stop, and serializes interruption pause/resume through the playback queue. An interruption generation prevents a stale end event from resuming after a manual pause or newer interruption, and ducking gain is restored when an interruption ends in stop.
- **Managed output lifecycle** — shared PCM output relinquishes Android's active media stream on pause and reclaims it on resume, while exclusive and DSD transports keep their stream alive. Play, pause, resume, and stop wait for native completion, the engine manager lock is released while waiting, and state events read native state instead of a queued payload.
- **Idle and foreground battery work** — engine event polling backs off from 50 ms to 500 ms when paused, idle, or stopped; position checkpoints stop while paused and skip unchanged playlist serialization; progress ticks no longer re-read engine state; full-player position updates throttle at 250 ms; frame timing collection runs only in Developer Mode.

## Updates

- **Stable and pre-release channels** — Settings → App Info → Update Channel now offers Stable (default), Pre-releases, or both for GitHub builds. Release tags are ordered by semver, pre-releases are detected from the tag suffix or the GitHub flag, drafts and releases without an APK are ignored, and the full APK is preferred.
- **Separate update notices** — Home shows distinct stable and beta banners with channel-appropriate copy, and the settings update check reports the selected channel. Play Store builds keep their existing In-App Update behavior.

## Localization

- EQ graph titles, guidance, status chips, and band-family labels, plus file-tag rows, visualizer source and status copy, lock-screen visualizer settings, and update-channel copy, are localized across English, Spanish, Taglish, and Chinese. Taglish keeps interactive EQ labels in English through the existing shim.

## Under the hood

- Removed the unused `rive` dependency and its transitive native packages, pinned `pubspec.lock` resolution for Flutter 3.50 stable, marked Replay Gain as implemented in the feature list, and documented AutoEq maintenance, lock-screen visualizer behavior, CUE and folder-path scanning, and front-end battery work.

## Builds & Flavors

- **This GitHub download uses the `full` flavor** — it declares **All Files Access** (`MANAGE_EXTERNAL_STORAGE`) for the raw Rust filesystem scanner and complete DSD/WavPack coverage. Build: `flutter build apk --flavor full --release`.
- **Google Play uses the `play` flavor** — no All Files Access (Play policy for media apps); it scans via MediaStore/SAF plus the DSD/DSF/WavPack reconciliation path. Build: `flutter build appbundle --flavor play --release`.
- Both flavors share `applicationId` `com.mossapps.flick`, so either installs over the other.

## Getting Started

1. Equalizer tab: Settings → Interface → Bottom Bar, or tap the equalizer icon in the default bottom bar.
2. AutoEQ: open the equalizer → Presets → **AutoEQ headphones**; use the cloud button to search upstream for a model that is not bundled.
3. Visualizer: Settings → Interface → Visualizer → enable **Visualizer**. High Quality playback uses the engine FFT; Standard playback uses Android's Visualizer and asks for microphone permission.
4. Lock-screen visualizer: Settings → Interface → Visualizer → **Lock-screen visualizer** → **Open visualizer screen**, then lock and wake the phone. Simulated AOD is the experimental toggle below it.
5. Update channel: Settings → App Info → **Update Channel** → Stable, Pre-releases, or both.
6. Library repair: run Settings → Library → **Rescan Library** once to split multi-FILE CUE sheets and backfill folder paths on existing rows.
7. File-only tags: open a song's actions or metadata sheet; comment, full date, copyright, and label appear when the file contains them.
