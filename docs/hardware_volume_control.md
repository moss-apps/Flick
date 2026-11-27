# Hardware Volume Control — Implementation Status

## Summary

Three-tier volume control for the Rust UAC2 isochronous USB DAC path:

| Tier | Mechanism | When |
|------|-----------|------|
| 1 (primary) | UAC2 Feature Unit SET_CUR + GET_CUR verify | `VolumeTier.hardware` — verified DAC volume; engine master gain normally 1.0 |
| 2 (software) | Rust engine software gain | `VolumeTier.software` — eligible PCM DSP without hardware authority, not recovery from an uncertain hardware write |
| 3 (system) | Android AudioManager / just_audio | `VolumeTier.system` — non-direct-USB (shared mode) path, or when no Rust backend |

Direct USB with a trusted UAC2 Feature Unit always uses Tier 1, even when the
PCM bit-perfect toggle is off. In that mode the USB engine still runs its DSP
path, but `_reconcileVolumeForTier` keeps the engine master gain at unity so
software slider gain is never stacked on top of the DAC's own attenuation.
Temporary notification ducking is a separate, explicitly applied attenuation.
`VolumeTier.unavailable` protects passthrough/DSD without hardware control and
DAC-volume safety blocks whose hardware control is no longer available.

## VolumeTier State Machine

- `_determineCurrentTier()` evaluates the route, native volume mode, transport,
  bit-perfect policy and safety state. `volumeTierNotifier` publishes the result.
- `_reconcileVolumeForTier()` applies authority changes and retains active
  ducking across status, diagnostics and physical-knob updates.
- Hardware discovery alone does not release existing engine attenuation. A
  verified pre-playback restore or explicit slider write must establish readiness.

### Tier transition triggers

| Trigger | Effect |
|---------|--------|
| `setVolume()` | Dispatches by tier; hardware writes require verified readback |
| Direct-USB write/readback failure | Pauses transport, retains known preferences and blocks automatic gain changes; no software fallback |
| Verified hardware restore or slider write | Clears the safety block and establishes hardware readiness; a slider write alone never auto-resumes |
| Hardware discovered after software use | Pauses rather than silently removing software attenuation |
| Hardware authority lost or device changed | Pauses rather than reinterpreting the hardware percentage as software volume |
| Disconnect | Resets connection readiness and the once-per-connection restore coordinator |
| Bit-perfect/preparation/resume | Awaits the pre-playback volume barrier before audio can start |

## How It Works

### Tier 1: DAC has verified hardware volume

```
UI slider → route-bound gesture → latest-value writer
  → tier = _determineCurrentTier() == VolumeTier.hardware
  → uac2_service.setVolume()            (platform channel)
  → Kotlin setRouteVolume()
  → nativeSetRustDirectUsbHardwareVolume()
  → android_direct_set_hardware_volume()     (Rust)
  → quantize_slider_volume()                  (slider position → supported i16 dB step)
  → synchronous USBDEVFS_CONTROL              (SET_CUR → DAC, on the volume worker)
  → GET_CUR readback must match the exact raw step
  → if OK: mirror actual DAC level, persist hardware slot, establish readiness
  → if mismatch/STALL: pause transport and block automatic volume changes
```

Key details:
- Native discovery establishes writable Feature Unit capability; the Dart write
  validates route identity and mirrors actual readback, not an optimistic target.
- The bounded Kotlin volume worker uses the existing direct USB connection.
  Synchronous controls do not reap isochronous completions or run on the
  submission thread. Native rejects stale hardware-control generations.
- A live slider gesture binds to its route before the first tick. One write is
  in flight and the latest value replaces any waiting write. Changing the DAC
  or volume authority discards pending values. The thumb holds the final
  requested position until verified readback, then shows the actual step.
- A hardware volume gesture never changes mute. Software, system and cast
  sliders still apply their values on release.

#### Phone volume keys

When direct USB has a verified hardware level, the activity sends volume up and
down to that DAC. Foreground presses show the confirmed level in the app.
Outside the app, Android can route volume events through Flick's active media
session, including while the screen is off. Cast volume takes priority in the
media session, and without a verified DAC the keys keep their usual behavior.

A press and its repeats stay tied to the claim that received the initial key
down. Replacing or unplugging the DAC discards stale requests, including those
already waiting in the same writer used by the slider. The keys adjust the
full-range DAC level, independently of mute. DAC level updates reuse the
running media session and never start the notification service.

### Tier 2: eligible PCM DSP without hardware authority

```
UI slider → player_service.setVolume()
  → tier = _determineCurrentTier() == VolumeTier.software
  → _rustAudioService.setVolume(clampedVolume)
  → FFI → AudioCommand::SetVolume
  → callback_data.set_volume()            (AtomicU32, lock-free)
  → audio_callback() applies volume_to_gain(volume)
```

The slider coordinate is not linear gain: 0 is silence, 0–100% uses a −40 dB
span, and values above 100% are linear boost (when enabled). At 50% the gain is
−20 dB. USB software labels use the shared Dart curve matching Rust.
Raw native DSD, DoP and passthrough are never software-scaled.

### Tier 3: Android system volume (shared mode)

```
UI slider → player_service.setVolume()
  → tier = _determineCurrentTier() == VolumeTier.system
  → just_audio player.setVolume(clampedVolume)
  → OR _rustAudioService.setVolume(clampedVolume) if Rust backend available
```

## Safe Restoration and Authority Changes

Readback, saved settings and automatic hardware restore use the same
full-range fractions as before (`normalize_volume` and `quantize_volume`).
Only explicit slider gestures use the compressed scale. When the DAC exposes
steps on both sides of −80 dB, positive slider values choose supported steps
above −80 dB. Zero selects the absolute device minimum, which is not
necessarily silence. A DAC already set at or below the slider floor is still
read and restored at its actual level, even though the thumb displays zero.

Hardware and software levels are stored in separate per-device slots
(`uac2_usb_device_volume_authorities`). No saved hardware values are migrated.
Legacy untyped values cannot authorize a hardware restore.

A new DAC or ambiguous legacy record uses the existing 40% full-range first-use default,
without requiring a slider gesture. A lower current DAC readback is retained,
including silence. Hardware discovery after software use pauses before removing
software attenuation, then a playback request restores a verified low level.
Recovery is capped at the lower of the default, the saved hardware level and the
current valid DAC readback; healthy playback is not otherwise capped at 40%.

A real hardware write/readback failure stays paused with no software fallback.
Pressing Play retries the low restore, even if an earlier startup restore was
cached as successful. A verified retry clears the hold so the same Play request
can continue. Only continued control, route or transport failures refuse playback;
there is no mandatory confirmation gesture. Verified restored levels are saved
to the hardware slot without changing the software slot.

The native queued restore skips ambiguous levels and live playback. Dart awaits
the verified restore before playback and resume, with connection-generation and
device checks. A recovery write waits for the safety pause to finish; failed
pause falls back to stopping transport. No alternate audio output is auto-started.

## Notification Ducking

`attenuateSoftwareVolume` multiplies the effective gain by 0.2 (approximately
−14 dB), then inverts the Rust slider curve. Passing 0.2 directly to Rust would
instead produce −32 dB. Reconciliation and slider updates retain ducking until
the interruption ends. If the requested attenuation is below the software
curve's floor, it uses silence rather than rounding the level upward.

Hardware authority uses unity as the unducked engine base. Passthrough and raw
DSD/DoP remain at unity and are not ducked with software gain.

## Logging

Search logs for `[VolFlow]` for authority dispatch, native raw range/quantization,
write/readback errors and held processing preferences. Safety-pause/stop failures
are also logged with that prefix.

## Key Files

| File | Role |
|------|------|
| `lib/services/player_service.dart` | Authority, readiness, safety pause, restore barrier and duck reconciliation |
| `lib/services/uac2_preferences_service.dart` | Per-device authority-specific levels and conservative legacy handling |
| `lib/services/uac2_service.dart` | Route-checked native writes/readback and queued restore |
| `lib/services/usb_dac_volume_restore.dart` | Coalesced, generation-checked restore coordination |
| `lib/core/utils/volume_curve.dart` | Rust-compatible dB labels and inverse-curve duck attenuation |
| `rust/src/uac2/android_direct.rs` | Feature Unit discovery, verified SET_CUR/GET_CUR and startup restore |
| `rust/src/uac2/volume_control.rs` | Raw dB range normalization and supported-step quantization |
| `rust/src/audio/engine.rs` | Software volume-to-gain curve and raw/passthrough guards |

## Design History

- **Transient handle claim/release removed** (`2781fc2`): both handles share the same Android USB FD; release could tear down the AudioControl interface claim from under the streaming handle. Control transfers on endpoint 0 don't require claims on Android.
- **GET_CUR post-write verification** (`2781fc2`): after SET_CUR, GET_CUR readback compares normalized volume to the quantized expected value. A direct-USB failure now pauses instead of falling back to Tier 2.
- **`Uac2VolumeMode.software`** (`9a8b053`): distinguishes DAC hardware volume from Rust engine software fallback in route status. Direct USB DAC without hardware volume controls → parser overrides to `software` with `hasVolumeControl=true`/`volumeControlWritable=true`.
- **Historical optimistic Tier 1 cache**: superseded by native writable Feature Unit discovery and verified, connection-scoped hardware readiness.
- **VolumeTier state machine**: replaced implicit tier routing (scattered `_hasBitPerfectUsbHardwareVolumeControl()` checks + `_currentVolume` drift) with explicit `VolumeTier` tracking + `_reconcileVolumeForTier()` single point.
- **Single hardware authority on direct USB** (#352): a trusted Feature Unit is Tier 1 regardless of the PCM bit-perfect toggle, removing stacked hardware + engine attenuation. The software-tier dB label now mirrors the engine's −40 dB curve (50 % = −20 dB) instead of the stale −60 dB approximation.
- **Safe authority handoffs** (#352 review): split hardware/software preferences, automatically restore a low verified level for ambiguous legacy records, retry on Play after hardware-control failure, and preserve linear-gain ducking through reconciliation.
- **Separated control worker** (#415): use synchronous native Feature Unit transfers on the owned USB connection and roll back failed or unverifiable writes.
- **Route-bound slider** (#416): coalesce live hardware gestures, keep the audible slider scale separate from saved levels, and verify raw readback.

## Hardware check

With a DAC in direct USB mode, compare the level after reopening playback with
its saved level before touching the slider. Move the slider in both directions
while playing, and check that volume settles on the last position without
dropouts. With hardware mute on, move the slider and check that mute stays on.
If another DAC is available, release the slider after disconnecting the first
DAC and confirm the replacement's level does not change.
