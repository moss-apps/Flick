# Bit-Perfect DSD / DoP / Native USB — Phased Plan

Goal: make DSF / DFF / WavPack-DSD play **bit-perfectly** through the
isochronous USB engine (the `USB_DAC_EXPERIMENTAL` path — the only route that
bypasses the Android mixer). Scope: `rust/src/uac2/android_direct.rs` and the
DSD engine in `rust/src/audio/dsd_engine/`.

Status of each phase is tracked below. **Conservative quirk policy**: ship the
XMOS-standard `DSD_U32_BE` default + runtime overrides; no hardcoded
unverified device entries (a wrong quirk must never break a working DAC).

---

## A. Already verified correct (no action)

| Area | Where | Why it's right |
|------|-------|----------------|
| DoP word build | `dsd/dop.rs:90` `build_dop_word` | Left-justifies marker into MSByte; `bits_per_frame` = 24 (DSD64/128/256) or 32 (DSD512). |
| DoP wire emit | `android_direct.rs:6366` `encode_dop_slots` | Emits top `ss` bytes LE → marker reassembles into bits 31:24 (ss=4) / 23:16 (ss=3). Standard DoP. |
| DoP marker toggle | `dsd/dop.rs:106` `advance_marker` | 0x05/0xFA alternation; `PipelineMode::Dop` (engine.rs:291) blocks DSP/gain corruption. |
| Native byte chain | `output/mod.rs:130` → render `to_bits()` (4080) → encode `& 0xFF` (6273/6284) | DSD byte value preserved end-to-end. |
| Native ss>1 repack | `encode_usb_pcm_slots:6275` | Deinterleaves `[b0_c0,b0_c1,...]`, groups `ss` bytes per channel, byte order by `big_endian`. |
| WavPack-DSD extract | `wavpack_decoder.rs:111` | `OPEN_DSD_NATIVE`, `as u8` truncation is safe (one byte per i32). |
| DSD thread output_mode | `engine.rs:2803` | Matches USB transport (DoP/Native). |

## B. Confirmed gaps

| # | Gap | Severity | Location |
|---|-----|----------|----------|
| G1 | Native DSD bookkeeping in wire-rate (88.2k) not byte-rate (352.8k); priming/telemetry 4× off. Robustness, not integrity. | Med | 1201, 830, 4032, 875 |
| G2 | DoP bit-depth hardcoded `24` → DSD512 (needs 32) drops 1 data byte. | High | engine.rs:1414 |
| G3 | `bit_reverse` + `preferred_subslot` quirk knobs never read. | High | 124, 130, 6285 |
| G4 | Unified `QUIRK_DATABASE` DSD variants not wired into encode (dead branch 167). | High | 154-174, quirk.rs |
| G5 | Isochronous feedback not polled; async iso-only DACs run open-loop. | Med | 4525-4533, 6598 |
| G6 | `direct_path_is_bit_perfect` ignores DSD payload (rate/depth/ch/clock only). | Med | 2120 |
| G7 | Only one quirk entry (Dawn Pro). | High | 142-152 |

---

## C. Phases

### Phase 1 — Bit-integrity correctness  ✅ complete

| Task | Gap | Change |
|------|-----|--------|
| P1.1 | G2 | engine.rs:1414 — `24` → `rate.dop_bits_per_frame()`. Existing alt-setting validation handles unsupported 32-bit-PCM@705.6 kHz (falls back, no manual DSD512→DSD256 hack — that would decimate). |
| P1.2a | G3 | `encode_usb_pcm_slots` — add `bit_reverse: bool`, reverse the DSD byte after `& 0xFF` when set (distinct from source-layer MSB/LSB normalization). |
| P1.2b | G3 | Wire `preferred_subslot` into `select_stream_candidate` + `build_android_usb_capability_model` via `resolve_dsd_quirk_for_device` (post-parse override, DSD format only). |
| P1.3 | G4 | Replace `lookup_dsd_quirk` with `resolve_dsd_quirk` (owned) that merges `KNOWN_DSD_QUIRKS` + unified `QUIRK_DATABASE` (`DsdSubslotSize`/`DsdBigEndian`/`DsdBitReverse`). |

**Verify P1:** golden-vector `#[cfg(test)]` checks — `encode_usb_pcm_slots`
native ss=4 (BE + LE + bit_reverse), `encode_dop_slots` ss=3 & ss=4, plus
`build_dop_word` for all four rates.

### Phase 2 — Tunable overrides (conservative)  ✅ complete

- `DSD_BIG_ENDIAN_OVERRIDE` + `DSD_SUBSLOT_OVERRIDE` atomics (next to
  `DSD_BIT_REVERSE_OVERRIDE` in `output/mod.rs`) for per-device field tuning.
- Surface in `uac2_preferences_service.dart`.

### Phase 3 — Robustness  ✅ P3.1 complete · P3.2 (G5) deferred

- P3.1 (G1) ✅: Native path uses `effective_ring_rate(&playback_format)`
  (`= dsd_bit_rate/8`, byte domain) for `RuntimeStats::new` and render
  `chunk_frames`; the symmetric `samples_to_millis` divisor self-corrects
  telemetry. Priming now targets the real ~100 ms of byte-rate i32 samples.
- P3.2 (G5): **Deferred.** `read_iso_feedback_packet` is blocking (nests its own
  `context.handle_events`); a correct fix weaves a persistent iso IN feedback
  transfer into the OUT slot loop — a risky rearchitecture. Most async DACs
  (incl. Dawn Pro) use INTERRUPT feedback (already handled); iso-only-feedback
  devices fall back to `lock_to_nominal_packet_timing()` (open-loop). See §E.3.

### Phase 4 — Verification & proof  ✅ P4.1/P4.2 complete

- P4.1 (G6) ✅: Post-encode `audit_dsd_payload` — DoP: every word's last byte
  must be 0x05/0xFA and channel-0 markers must alternate; Native: ≥1 non-zero
  byte. Result stored in `USB_DSD_PAYLOAD_VERIFIED` and ANDed into
  `direct_path_is_bit_perfect`; reported live via `android_direct_debug_state`.
- P4.2 ✅: Golden-vector + audit `#[cfg(test)]` checks committed in the
  `dsd_bitperfect_tests` module (native BE/LE/bit_reverse/U8, DoP ss3/ss4,
  quirk resolution, DoP marker alternation, effective_ring_rate).
- P4.3: capture procedure + DAC DSD-lock checklist — §E below.

---

## D. Execution order

Phase 1 (P1.1 → P1.3 → P1.2a → P1.2b) → commit golden tests (P4.2 subset) →
Phase 2 → Phase 3 → Phase 4.

> All four phases implemented. Host `cargo check` ✓, Android
> `cargo check --target aarch64-linux-android` ✓, test module compiles+links ✓
> (on-device run = §E.3). Dart `flutter analyze` ✓. Not yet committed.

---

## E. Verification procedures (P4.3)

### E.1 In-app runtime gate (always on)

`audit_dsd_payload` runs on every prepared transfer; `direct_path_is_bit_perfect`
now requires DoP markers to alternate (0x05↔0xFA) and Native bytes to be
non-zero. `android_direct_debug_state().bit_perfect_verified` reflects this live
— if it reads `true` while playing DSD, the wire payload is structurally intact.
This is the first-line check; it does NOT prove the DAC agrees on byte order
(use §E.2 / E.3).

### E.2 DAC-side DSD-lock confirmation (primary real-world proof)

The DAC's own display is the authoritative bit-perfect signal — it confirms the
device accepted the negotiated format and locked to it:

1. Play a known DSD file (DSF/DFF/WavPack-DSD) via the `USB_DAC_EXPERIMENTAL`
   path.
2. DAC panel must show **DSD** lock (not PCM) at the expected rate
   (DSD64/128/256/512). If it shows PCM, DoP/native negotiation failed or fell
   back to decimation.
3. No dropouts/clicks over ≥60 s → clock feedback (interrupt) or nominal-timing
   fallback is holding.
4. A/B against a known-bit-perfect player (USB Audio Player PRO / foobar2000
   DSD) on the same DAC + same file: identical reported format/rate and
   indistinguishable silence-floor/noise spectrum ⇒ transport-correct.

### E.3 Host-side byte capture (usbmon / Wireshark) — definitive diff

Do this on a **Linux host** with the DAC plugged into the PC (not Android), to
compare wire bytes against a reference player. (On Android it needs root +
`usbmon`, rarely available.)

1. `sudo modprobe usbmon`
2. `lsusb` → note the DAC's bus/device, then
   `sudo wireshark -k -i usbmonX` (X = bus number).
3. Capture while playing the test file. Filter UAC2 OUT audio:
   `usb.transfer_type == 0x1 && usb.dst.startswith("2.")` (isochronous OUT).
4. Inspect the first few packets: the MSByte of each DoP word must alternate
   0x05/0xFA; for native DSD the 4-byte groups carry packed DSD bytes.
5. Diff against a reference capture (foobar2000/hqplayer, same file, same DAC):
   identical packet byte content (modulo feedback-driven size variation) ⇒
   bit-perfect confirmed.

### E.4 On-device test run (golden + audit tests)

The `dsd_bitperfect_tests` module is android-gated (the encoder lives behind
`#[cfg(target_os="android")]`). To actually execute them:

- Build the test binary for the device:
  `cargo test --target aarch64-linux-android --features uac2 --lib --no-run`
  (already passes — compile+link only on the host).
- Push + run on-device:
  `cargo test --target aarch64-linux-android --features uac2` (requires a
  connected device or emulator with the NDK linker wired; run from the device).

### E.3′ G5 (iso feedback) deferral — when to revisit

Re-open P3.2 only if a target DAC exposes **iso-only** feedback (no interrupt
feedback endpoint) AND exhibits drift/underruns at high DSD bitrates (DSD128+).
Fix shape: add a persistent iso IN feedback transfer to the OUT slot queue,
drain its completion in the same `context.handle_events` loop, route to
`decode_feedback_report` → `scheduler.update_feedback_frames_per_packet`. Until
then, iso-only devices run open-loop via `lock_to_nominal_packet_timing()`,
which is correct for sync/adaptive DACs and most async DACs that also expose
interrupt feedback.
