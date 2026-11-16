# Front-End Battery Optimizations

**Status:** Source audit complete. Items 1, 2, 3, 4, 5, and 6 are implemented.
Local analysis and tests pass; device verification is still pending. The
remaining items are not implemented or measured on a device yet.

Scope: Flutter/Dart timers, polling, notifications, and on-screen animation.
No audio decoding, DSP, or USB changes.

## Current timer and polling costs

| Cost | Where | Rate |
|---|---|---|
| Rust event polling | `lib/services/rust_audio_service.dart` | 50ms while playing, buffering, or crossfading; 500ms paused/idle/stopped |
| Progress polling | `lib/services/rust_audio_service.dart` (`_updateProgress`) | 50ms playing, 250ms paused; 1 FFI call per tick; state comes from events with a 2s fallback |
| Position checkpoint | `lib/services/player_service.dart:7530` | 5s while playing; one save on pause; stopped while paused |
| Playlist serialization | `lib/services/last_played_service.dart:30` | Only when queue IDs change; index integer on track changes |
| Full-player position throttle | `lib/features/player/screens/full_player_screen.dart:121` | 250ms duplicate timer |
| Notification rebuild | `lib/services/player_service.dart:3868` | Every 2s while playing |
| Motion Art | `lib/features/player/widgets/motion_art_widget.dart:296` | Streams/loops video while visible; default on |
| Visualizer | `lib/services/visualizer_source.dart:74` | 33ms data poll plus 60fps paint while visible |
| Ken Burns artwork | `lib/widgets/common/animated_album_art.dart:49` | 60fps transform/gradient rebuild while visible |

## Implemented

| # | Optimization | Status | Risk | Expected impact | Guardrail |
|---|---|---|---|---|---|
| 1 | Stop the position-save timer while paused. Save once immediately, restart on resume. | Implemented | Low | Medium | Keep 5s checkpoints while playing; final save on lifecycle |
| 2 | Serialize playlist IDs only when the queue or index changes. | Implemented | Low | Low–Medium | Preserve existing keys, crash restoration, and final save |
| 3 | Slow event polling to ~500ms when paused/idle/stopped. | Implemented | Low | Medium–High | Keep 50ms while playing, buffering, or crossfading; refresh state immediately on actions |
| 4 | Remove the per-progress-tick `audioGetState()` read; refresh state from `stateChanged` events with a slow fallback. | Implemented | Low | Low–Medium | Keep immediate refresh after play/pause/resume/stop and a 2s fallback for missed events |
| 5 | Change the full-player position throttle from 50ms to 250ms. | Implemented | Low | Low | Keep waveform and lyrics responsive; labels remain second-resolution |
| 6 | Start `FrameTimingsMonitor` only in developer mode. | Implemented | Low | Low | Clear pending timings when disabled; no release telemetry |

`PlayerService` now runs the 5s position checkpoint only while playback is
active. Pausing stops the timer and writes the current position once; resuming
restarts it. Playback-state changes also stop the timer and save once when the
engine pauses without going through the normal pause path. Stop-after-current
and queue-end rewinds explicitly persist `Duration.zero`, and network prefetch
still runs when checkpoints start. Covered by
`test/services/player_service_position_checkpoint_test.dart` (5 checkpoint
tests). Local focused tests pass and `flutter analyze` reports only pre-existing
`info` diagnostics. The full `flutter test` run is currently blocked by an
unrelated Isar core version mismatch in
`test/services/webdav_sync_integration_test.dart`; device verification is still
pending.

`LastPlayedService` now caches the last persisted playlist IDs and index.
Position checkpoints continue to write the song ID, position, and playing state,
but skip `jsonEncode` and the SharedPreferences string write when the queue is
unchanged. A changed queue rewrites the playlist JSON; a track change writes only
the index integer. Empty or null playlists still remove both keys, and
`clearLastPlayed()` resets the cache. Covered by
`test/services/last_played_service_test.dart` (7 tests) plus a queue-context case
in `test/services/player_service_position_checkpoint_test.dart` (6 tests total).
Local focused tests pass; device verification of queue restoration after a
force-stop is still pending.

`FrameTimingsMonitor` now follows `Uac2PreferencesService.developerModeNotifier`.
It installs the `SchedulerBinding` timing callback and 5s report timer only while
Developer Mode is enabled, and removes the callback, cancels the timer, and
clears pending timings when it is disabled. Covered by
`test/core/utils/frame_timings_monitor_test.dart`; device verification is still
pending.

`RustAudioService` now polls engine events at 50ms only while playing, buffering,
or crossfading, and backs off to 500ms when paused, idle, or stopped. Play,
resume, pause, and stop refresh state immediately, and every state transition
resynchronizes the cadence. Position updates still come from the separate
progress timer, so slowing event polling does not affect the progress bar.
Covered by `test/services/rust_audio_service_event_polling_test.dart`; device
verification is still pending.

`RustAudioService._updateProgress` now reads only `audioGetProgress()`. Playback
state changes come from `stateChanged` events drained by the event poll, with a
2s fallback that repairs a missed transition. Play, pause, resume, and stop
still refresh state immediately after the command, and event-driven refreshes
stop the progress timer when the engine reports stopped or idle. The fallback
reuses the existing event-poll wakeups, so no extra timer is added. Covered by
the fallback-cadence cases in
`test/services/rust_audio_service_event_polling_test.dart`; device verification
is still pending.

`FullPlayerScreen` now throttles its derived playback clock at 250ms instead of
50ms. The engine position notifier and progress polling cadence are unchanged;
only the full-player waveform, lyrics sync checks, and time-label rebuilds use
the slower clock. `PlayerControls` and `LyricsModeWaveformStrip` accept an
optional position notifier so their labels no longer rebuild at the raw 50ms
rate. Label text stays at second resolution, and seek-drag feedback still updates
the throttled notifier directly. The change is front-end only and does not touch
the audio path. Device verification is pending for waveform motion, lyrics
transitions, and scrubbing.

## Ready to implement

Risk means chance of a visible or audio regression, not battery benefit.

| # | Optimization | Status | Risk | Expected impact | Guardrail |
|---|---|---|---|---|---|
| 7 | Move notification refresh from 2s to 5s. | Proposed (optional) | Low–Medium | Low–Medium | Keep controls and artwork; verify notification progress staleness |

Implementation order: **7** (#1, #2, #3, #4, #5, and #6 complete). One focused
commit/PR each.

## Needs measurement or a product decision

| # | Item | Status | Risk | Why it is deferred |
|---|---|---|---|---|
| 8 | Motion Art default and battery-saver behavior | Needs measurement | Medium | Video decoder plus network streaming; user-visible feature |
| 9 | Visualizer refresh rate and mini-player defaults | Needs measurement | Medium | 33ms polling plus continuous repaint; already stops when hidden |
| 10 | Ken Burns animation cost | Needs measurement | Low–Medium | Visual-only; possible static-glow or lower-frame-rate option |
| 11 | 50ms event polling during active playback | Keep as-is | High if changed | Needed for track-end and gapless UI latency |
| 12 | Global progress polling rate | Keep as-is | Medium if changed | Lyrics and karaoke may depend on the current rate |

Do not change Motion Art, visualizer, or Ken Burns defaults without a profile and
a deliberate product decision.

## Risk scale

- **Low:** front-end only, no audio path, no expected visible change.
- **Medium:** visible behavior or playback restoration; needs targeted tests and
  possibly a user decision.
- **High:** audio path or core playback behavior; separate plan and hardware
  verification required.

## Measurement

Battery percentages are not known yet. Compare 30-minute sessions on a test
device:

1. Paused, screen off.
2. Local FLAC playing, screen off.
3. Full player open with Motion Art.
4. Visualizer on versus off.

Use Android Studio's Energy Profiler, or:

```bash
adb shell dumpsys batterystats --reset
# run one scenario for 30 minutes
adb shell dumpsys batterystats --charged com.mossapps.flick
```

Record battery use, wakeups, wakelocks, CPU time, and network traffic. Use a
release build for battery comparisons and a profile build for CPU traces.

## Acceptance criteria

- No changes to decoding, DSP, sample rate, bit depth, or DAC output.
- Track end, crossfade, media controls, queue restoration, and paused
  restoration behave as before.
- Add focused tests for pause/resume checkpoints, queue-change serialization,
  state transitions, restoration, and frame-timing enable/disable.
- Run `flutter analyze` and `flutter test`.
- Confirm playback behavior on hardware; distinguish that from local automated
  checks.

Related: [Quality-preserving optimizations](QUALITY_PRESERVING_OPTIMIZATIONS.md).
