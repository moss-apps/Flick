# USB isochronous completion diagnostics (#354)

This is the diagnostic stage of [issue #354](https://github.com/moss-apps/Flick/issues/354),
not a compatibility workaround. Packet acceptance and fallback remain strict:
each ISO OUT packet must complete successfully with its exact submitted length.
No resampling, format conversion, startup-packet skipping, or new DAC quirks are
introduced.

## Collecting a reproduction

1. Use a test build signed compatibly with the installed app. A locally built
   debug APK may have a different signing key; do not uninstall an existing app
   and lose its data just to collect diagnostics.
2. Connect the affected Redmi 12C / KT-Micro KT-384/32 DAC combination and select
   direct USB / bit-perfect playback.
3. Start a local 44.1 kHz, 16-bit stereo track and export Flick's logs immediately
   after playback falls back. Include the app version and source audio format.
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

## Validation before changing acceptance

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

Use reporter hardware results to determine whether to fix submission/lifecycle
bookkeeping or investigate a narrowly scoped USB-stack reporting quirk. Do not
replace exact packet checks with a nominal floor/ceiling whitelist or skip empty
completions. Recheck both sample-rate families, supported bit depths, DSD/DoP,
seeking, pause/resume, foregrounding and unplugging before shipping a behavioral
fix. Real DAC verification is still required.
