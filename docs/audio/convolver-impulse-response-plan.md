# Convolver / Impulse Response — Phased Plan

Goal: let a user load an **impulse response (IR)** file and convolve
playback with it — room/hall reverb, headphone crossfeed/speaker
simulation, cabinet sims, and Oratory1990-style correction IRs. Scope:
the realtime DSP chain in `rust/src/audio/` plus the FFI surface in
`rust/src/api/audio_api.rs` and the Flutter EQ/provider layer.

The convolver slots into the existing FX chain as a sibling of
`SpatialFx` (`fx.rs`), `Equalizer` (`equalizer.rs`), and `DynamicsChain`
(`dynamics.rs`). It reuses the same lock-free `try_lock`-in-callback
pattern and the same command/FFI/persistence shape — no new runtime
dependencies for v1.

Status tracked below. **Ponytail policy**: ship direct (time-domain)
convolution with a tap cap in v1 — covers cabinet/crossfeed/correction
and short-reverb IRs with zero new crates; add partitioned FFT
convolution only if users load long hall tails and CPU shows it.

---

## A. What the user means by "convolver / impulse response"

An IR is the recorded acoustic signature of a space or device. Convolution
with it makes playback sound as if it was played through that space/device.
Common IR classes this must support:

| Class | Typical IR length | Channels | Why |
|-------|-------------------|----------|-----|
| Room / hall reverb | 0.3–4 s (14k–192k taps @48k) | stereo | The headline ask — "make it sound like a concert hall". |
| Headphone crossfeed / speaker sim | <50 ms (<2.4k taps) | stereo | Crossfeed correction, speaker-in-room emulation. |
| Cabinet / amp sim | 0.5–20 ms (24–1k taps) | mono | Guitar/bass cabinet emulation. |
| EQ / correction (Oratory1990, AutoEq IR) | <10 ms (<480 taps) | mono/stereo | Frequency-response correction turned into an FIR. |

A v1 that handles **mono and stereo IRs up to a tap cap** covers all but the
longest hall reverbs; the cap is the ponytail ceiling we name explicitly.

---

## B. Algorithm decision (the one real fork)

| Option | Cost per output sample | Max IR length @ 48 kHz, 1% CPU on a mid ARM core | New deps | When to use |
|--------|------------------------|---------------------------------------------------|----------|-------------|
| **Direct (time-domain) convolution** | O(M) MACs (M = IR taps) | ~8k–16k taps (~170–340 ms tail) | none | **v1.** Covers crossfeed, cabinet, correction, short reverb. Zero algorithmic latency. |
| **Partitioned FFT (overlap-save)** | O(log M) amortised | seconds-long tails | `rustfft` (+ `realfft` for real-input optimisation) | Only if users load long hall/cathedral IRs and direct convolution xruns. |

Direct convolution is a textbook FIR: `y[n] = Σ h[k]·x[n−k]`. The engine
already runs biquad chains, dynamics, and a multi-tap delay network per
sample with `try_lock` Mutexes; a capped direct convolver is the same
complexity class. **Decision: direct convolution, cap = 16 384 taps**
(≈341 ms at 48 kHz). The cap is enforced at IR load (truncate + warn),
with a `// ponytail:` comment naming the FFT upgrade path.

---

## C. DSP chain placement

Current DSP order (`engine.rs:2347-2355` and `2485-2493`, the two callback
branches — straight path and crossfade/speed path):

```
sources → crossfader/speed → EQ → FX → dynamics → volume
```

Convolver inserts **between FX and dynamics**:

```
sources → crossfader/speed → EQ → FX → CONVOLVER → dynamics → volume
```

Rationale: a convolver is a time/spatial effect (sits with FX family), and
it must run **before dynamics** so the existing limiter catches reverb-tail
peaks and prevents clipping. It runs **after EQ** so tonal shaping happens
pre-reverb (the natural order; mirrors Web Audio `ConvolverNode` placement).

Both callback branches (`audio_callback`) get the new `try_lock` call
mirrored in lock-step, exactly like the existing EQ/FX/dynamics triple.

---

## D. IR loading pipeline (must never touch the realtime callback)

IR decode is expensive and **must not allocate in the callback**. It runs on
the command thread (`command_processing_loop`), mirroring how
`SetEqualizer`/`SetFx` push into the callback via `Mutex`:

1. **Pick + copy** — Dart copies the chosen IR into the app documents
   directory (same pattern as `album_art_import_service.dart:616`), stores a
   stable path. Keeps the IR alive independent of the source URI/permission.
2. **Decode** — new helper `load_ir_to_pcm(path, target_rate, channels)`
   decodes with **Symphonia** (already a dependency, decodes WAV/FLAC/AIFF/
   MP3/etc.) to interleaved f32 PCM at its native rate.
3. **Resample** — **rubato** (already a dependency, used by the resampler
   stage) to the engine's current sample rate. An IR recorded at 44.1 kHz
   must match the 48 kHz engine or the convolved spectrum is pitch-shifted.
4. **Deinterleave + cap** — split to per-channel IR vectors; truncate each to
   `IR_TAP_CAP` (16 384); normalise peak to ±1.0 to avoid a hot IR.
5. **Swap in** — build a fresh `Convolver` (allocates the input-history ring
   buffer sized to the IR) and replace it under `data.convolver` Mutex. The
   callback's next `try_lock` picks it up; a mid-buffer collision simply
   skips the convolver for one block (identical to EQ/FX today).

Stereo handling: a **mono IR** is applied to both channels (L=IR, R=IR); a
**stereo IR** applies L IR → L out, R IR → R out. True-stereo (4 IRs:
LL/LR/RL/RR) is out of scope for v1 (`// ponytail:`).

---

## E. Confirmed gaps (what does not exist yet)

| # | Gap | Severity | Location |
|---|-----|----------|----------|
| G1 | No `Convolver` DSP struct / `process()` in the realtime callback. | High | new file `rust/src/audio/convolver.rs` |
| G2 | No `convolver` field on `AudioCallbackData`; not constructed in `new()`/`reconfigure_sample_rate()`. | High | engine.rs:119-189, 299-312 |
| G3 | Convolver not applied in either callback branch (straight + crossfade/speed). | High | engine.rs:2347-2355, 2485-2493 |
| G4 | No `AudioCommand` for convolver enable/mix or IR load. | High | commands.rs:11-85 |
| G5 | No `set_convolver`/`load_ir` on `AudioEngineHandle`. | High | engine.rs:349-607 |
| G6 | No FFI functions `audio_set_convolver` / `audio_load_ir`. | High | audio_api.rs (after `audio_set_fx:1173`) |
| G7 | No IR decode/resample helper. | High | new file `rust/src/audio/ir_loader.rs` |
| G8 | No Flutter `ConvolverSettings` model / state field / persistence. | High | equalizer_provider.dart:78-543 |
| G9 | No convolver UI card. | High | equalizer_screen.dart:3509+ |
| G10 | Convolver bypassed in Passthrough/DoP modes (correct) but not documented/asserted. | Low | engine.rs:2278-2319 |

Like EQ/FX/dynamics, the convolver **only runs in `PipelineMode::Dsp`** — the
passthrough (bit-perfect) and DoP branches return early before any DSP
(`engine.rs:2278-2319`). This is the desired behaviour (IR processing breaks
bit-perfect) and needs no new gate, just a comment.

---

## F. Phases

### Phase 1 — Rust DSP core + IR loader (no UI)

| Task | Gap | Change |
|------|-----|--------|
| P1.1 | G1 | New `rust/src/audio/convolver.rs`: `Convolver { ir_l, ir_r, hist_l, hist_r, write_pos, mix, enabled }`. `process(&mut [f32], channels)` does direct convolution per channel with a ring input-history buffer (no per-call alloc). `// ponytail: O(M) direct conv, partitioned FFT if IR > cap xruns`. |
| P1.2 | G1 | Add `reconfigure_sample_rate()` + `reset_state()` mirroring `SpatialFx`. On rate change the history buffer is zeroed (IR stays; length is rate-independent in *taps*, but a new IR load is encouraged). |
| P1.3 | G7 | New `rust/src/audio/ir_loader.rs`: `load_ir(path, target_rate, out_channels) -> IrData { taps, channels, samples }` using Symphonia decode + rubato resample. Cap = 16 384 taps, peak-normalise. |
| P1.4 | G2 | engine.rs: add `convolver: Mutex<Convolver>` to `AudioCallbackData`; init in `new()` (`Convolver::new(sample_rate)`); reset in `reconfigure_sample_rate()` (line 310). |

**Verify P1:** `#[cfg(test)]` golden-vector checks — convolving a unit
impulse IR reproduces the input; a known 2-tap IR `[a,b]` yields
`y[n]=a·x[n]+b·x[n−1]`; disabled convolver leaves buffer byte-identical;
mono vs stereo IR routing correct.

### Phase 2 — Wire into callback + command/FFI

| Task | Gap | Change |
|------|-----|--------|
| P2.1 | G3 | engine.rs `audio_callback`: after `fx.process`, add `if let Some(mut c) = data.convolver.try_lock() { c.process(output, channels); }` in **both** branches (2347-2355 and 2485-2493). |
| P2.2 | G4 | commands.rs: add `SetConvolver { enabled, mix }` and `LoadIr { path: PathBuf }` to `AudioCommand`. |
| P2.3 | G5 | engine.rs `AudioEngineHandle`: `set_convolver(enabled, mix)` + `load_ir(path)` sending the new commands. |
| P2.4 | | command_processing_loop (engine.rs:2711 `SetFx` arm): handle `SetConvolver` (push to `convolver.lock().set(...)`) and `LoadIr` (decode via P1.3 on this thread, then swap `convolver.lock().load_ir(...)`; emit `AudioEvent::Error` on decode failure). |
| P2.5 | G6 | audio_api.rs: `audio_set_convolver(enabled, mix)` and `audio_load_ir(path: String) -> Result<(), String>` (after `audio_set_fx:1173`). Mark `#[flutter_rust_bridge::frb(sync)]` on `audio_set_convolver`; `audio_load_ir` is async (returns when IR swapped). |
| P2.6 | | Regenerate bindings: `flutter_rust_bridge_codegen generate`. |

**Verify P2:** load a 1 kHz sine test tone + a short reverb IR; capture the
engine output (debug hook or a `dev_eprintln` energy dump) and confirm wet
content with reverb tail. Confirm passthrough/DoP modes are untouched
(no DSP runs). Confirm no allocations in callback (`cargo` + a quick
heap-scan or xrun counter stays flat).

### Phase 3 — Flutter model + persistence + UI

| Task | Gap | Change |
|------|-----|--------|
| P3.1 | G8 | equalizer_provider.dart: new immutable `ConvolverSettings { enabled, mix, irPath, irDisplayName }` with `toJson`/`fromJson` mirroring `FxSettings:178`. Defaults: `enabled=false, mix=1.0, irPath=null`. |
| P3.2 | G8 | Add `convolver` to `EqualizerState` (around line 391), default `const ConvolverSettings()`. Wire `fromJson` (538) and `toJson`. |
| P3.3 | G8 | Notifier setters: `setConvolverEnabled`, `setConvolverMix`, `setConvolverIr(path, displayName)`, `clearConvolverIr`. Each calls `audio_set_convolver` / `audio_load_ir` (catch errors, surface via existing error UX). |
| P3.4 | | IR persistence service (new small helper or extend an existing one): on `setConvolverIr`, copy the picked file into `getApplicationDocumentsDirectory()` under e.g. `irs/<hash>.wav`; store that path in settings. Mirror `album_art_import_service.dart:616`. |
| P3.5 | G9 | equalizer_screen.dart: new `_DynamicsCard`-style card "Convolver / Impulse Response" placed **after** the Spatial & Time card (line ~3508) and **before** any dynamics card, matching chain order. Contents: enable toggle, IR picker button (`FilePicker.pickFiles`, type filter `wav/flac/aiff`, like `equalizer_screen.dart:533`), current IR name + clear button, Mix knob (0–100 %). |
| P3.6 | | Apply IR on engine init: when the engine is (re)created (rate/strategy change recreates it — see PENDING_VOLUME pattern, audio_api.rs:27), restore the convolver settings + reload the persisted IR. Add a `PENDING_CONVOLVER` mirror or push in the same engine-ready hook. |

**Verify P3:** pick an IR, hear reverb; toggle off → dry returns; rotate
device / change output → IR persists and reloads; load a corrupt/unsupported
file → graceful error, playback continues dry.

### Phase 4 — Hardening (optional, post-ship)

| Task | Change |
|------|--------|
| P4.1 | Partitioned FFT convolution behind a feature flag if users report long-hall IR xruns (`rustfft` + `realfft`). Keep direct path as default. |
| P4.2 | True-stereo IR (LL/LR/RL/RR) for headphone crossfeed purists. |
| P4.3 | Per-IR `predelay` and `output_gain` controls. |
| P4.4 | Ship 2–3 bundled IRs in `assets/audio/irs/` (room + crossfeed) so the feature is usable with zero setup. |

---

## G. Risks & open questions

1. **CPU on long IRs** — a 16k-tap stereo direct conv = ~32k MACs/sample ×
   48k/s ≈ 1.5 GMAC/s. Fine on big cores; watch background/low-power. The
   tap cap + the named FFT upgrade path mitigate. **Mitigation already in
   plan: P4.1.**
2. **Bit-perfect contract** — convolver deliberately breaks bit-perfect. It
   must be auto-disabled (no-op) in Passthrough/DoP, which the existing
   early-return gives us for free. Confirm in P2 verify.
3. **IR rate mismatch** — an IR at the wrong rate pitch-shifts. P1.3
   resamples to engine rate; re-resample on engine rate change is the cost
   (acceptable, off-callback). Decision: re-resample lazily only if the IR
   was loaded at a different rate than the current engine rate.
4. **Engine recreation wipes the convolver** — like volume/crossfade, the IR
   must be re-pushed after recreation (P3.6). This is the same fragility
   already solved for volume/crossfade via PENDING_* atomics.
5. **File access / SAF** — Android scoped storage: copying into app docs dir
   (P3.4) avoids re-prompting for permission per play.
6. **Library-scan interaction** — IRs should NOT be imported into the music
   library. They live under app docs, not scanned folders. No scanner change.

---

## H. Test plan

- **Unit (Rust):** convolver identity (impulse IR), linearity, 2-tap FIR,
  mono/stereo routing, tap-cap truncation, disabled = passthrough, IR loader
  resample correctness (44.1k IR @ 48k engine). Golden-vector style like the
  existing `fx.rs:212` tests.
- **Integration:** load IR during playback → no xrun (XRUN_COUNT flat),
  no drop in the progress stream; toggle off → seamless dry resume.
- **Manual:** room reverb IR (audible tail), cabinet sim (tone change),
  crossfeed IR (narrowing on headphones); passthrough mode unaffected.
