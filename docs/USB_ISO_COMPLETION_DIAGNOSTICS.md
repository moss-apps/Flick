# USB isochronous completion diagnostics (#354)

These diagnostics were introduced for [issue #354](https://github.com/moss-apps/Flick/issues/354).
Direct USB PCM can continue through bounded, reported shortfalls. The report
still compares every packet with its original submission. Native DSD, DoP,
and diagnostic probes require exact, successful completions.

## PCM completion policy

- A completed packet may be shorter than submitted if the descriptor is
  unchanged and both lengths are whole PCM frames. The missing frames are
  counted as loss rather than consumed. On timeout, only successful packets
  that reported the full original length are credited. A partly reported
  packet from a timed-out transfer is counted in full as uncredited.
- Any reported shortfall or timeout clears stream stability and bit-perfect
  verification until a new stream starts. A timeout with full-length packets
  still clears verification without adding invented lost frames.
- An oversized packet, descriptor rewrite, malformed completion, or other
  packet error stops playback on this transport. Matching total lengths
  cannot make two mismatched packets valid. Recovery stops after a fourth
  consecutive interrupted completion in callback order or when uncredited
  frames exceed 100 ms of PCM since stream start.
- New submissions carry new audio. Later audio is already queued, so dropped
  packets are never replayed or filled by resampling. Audible gaps may remain.

The first recoverable interruption is recorded in the shareable log.
`[USB-TIMING]` reports `lostFrames`, `shortPackets`, `zeroPackets`,
`dataUrbTimeouts`, and `transportUnverified` for the current stream. These
are completion-based counts, not measurements of the bytes received by the DAC.

## Collecting a reproduction

1. Use a test build signed compatibly with the installed app. A locally built
   debug APK may have a different signing key; do not uninstall an existing app
   and lose its data just to collect diagnostics.
2. Connect the affected Redmi 12C / KT-Micro KT-384/32 DAC combination and select
   direct USB / bit-perfect playback.
3. Start a local 44.1 kHz, 16-bit stereo track and export Flick's logs immediately
   after an interruption or fallback. Include the app version and source format
   and whether the bit-perfect indicator changed.
4. If possible, repeat with a 48 kHz track, then with the same DAC on another
   Android device. Keep each reproduction's logs separate.

No healthy per-packet logging is added. On the first rejected completion, the
existing fatal-error path includes a snapshot of up to 32 packets (the current
maximum OUT transfer size), before the slot is reused or drained. No audio
payload or additional device identifiers are included in this snapshot.

## Reading the snapshot

- `slot` and `generation`: slot index and successful submission count for that
  slot within this stream. A fresh stream starts a new set of slots.
- `submitted_endpoint` / `completed_endpoint`, `submitted_bytes` /
  `transfer_length`: saved submission metadata versus the completed header.
- `sample_rate`, `channels`, `subslot_bytes`, `bit_resolution`,
  `service_interval_us`, interface, alternate setting, endpoint, speed and sync
  type: the selected wire format and endpoint timing.
- `requested`: the saved scheduler request for that packet.
- `descriptor`: the descriptor's requested length at completion.
- `actual`: the descriptor's reported completed length.
- `status`: per-packet completion status, with its numeric value.
- `descriptor_changes`: descriptor lengths that differ from the saved requests.
- `length_mismatches`: packets whose actual length differs from either request.
- `requested_total`, `descriptor_total`, `actual_total`,
  `actual_minus_requested`: sums over all per-packet lengths, **not** the ISO
  transfer header's meaningless `actual_length` field. Totals are diagnostic
  only; equal totals do not make mismatched packets safe to accept.
- `packet_counts` and `omitted_packets`: structural mismatch / truncation
  information. An unexpected header packet count is rejected before reading
  the descriptor array.

The original log's `20/24` notation did not distinguish descriptor lengths from
saved requests. Reconstructing its 23 reported mismatches against a matching
44.1 kHz schedule gives 708 requested versus 704 reported bytes: a one-frame
deficit for 16-bit stereo. This may be bad completion metadata or actual loss;
the diagnostic snapshot must not be interpreted as proof of either on its own.

## Validation

Run the Rust library tests and cross-compile the Android audio path. The pure
validation tests run on the host without USB hardware:

```sh
cargo test --lib --manifest-path rust/Cargo.toml
```

With the [Android NDK configured](ANDROID_NDK_SETUP.md), check the Android-only
path from the `rust/` directory:

```sh
cargo ndk --target arm64-v8a --platform 26 check --locked --lib
```

To produce a full-flavor diagnostic APK, run from the project root:

```sh
flutter build apk --flavor full --debug
```

The APK is written to `build/app/outputs/flutter-apk/app-full-debug.apk`. The
signing-key warning above applies; successful compilation is not DAC validation.

Recheck both sample-rate families, supported bit depths, DSD/DoP, seeking,
pause/resume, foregrounding and unplugging. The earlier #354 capture included
packets larger than submitted. PCM shortfall recovery does not accept those
completions. Retest the affected hardware to establish what it reports with this
build.
