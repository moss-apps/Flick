# Flick

<p align="center">
  <img src="docs/app_screenshots/flick_banner.png" alt="Flick Banner" width="100%">
</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.mossapps.flick">
    <img src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" alt="Get it on Google Play" height="80">
  </a>
  <a href="https://trendshift.io/repositories/64676?utm_source=trendshift-badge&amp;utm_medium=badge&amp;utm_campaign=badge-trendshift-64676" target="_blank" rel="noopener noreferrer">
    <img src="https://trendshift.io/api/badge/trendshift/repositories/64676/daily?language=Dart" alt="moss-apps%2FFlick | Trendshift" width="250" height="55">
  </a>
</p>

---

An Android music player with a Rust audio engine. Bit-perfect PCM and native DSD to USB DACs, hi-res on DAPs, plus a full DSP chain.

Builds at [GitHub Releases](https://github.com/moss-apps/flick) or the [Play Store](https://play.google.com/store/apps/details?id=com.mossapps.flick).

## What it does

- **Rust audio engine** — bit-perfect USB DAC output (UAC 2.0), native DSD (DSF/DFF/WavPack), DoP, and DAP hi-res via Oboe/AAudio exclusive mode. Falls back to Android's standard pipeline when needed.
- **31-band parametric EQ** with dynamics (compressor/limiter), convolution reverb from IR files, crossfade, and gapless playback.
- **Library** — MediaStore scanner with differential sync, removable storage (SD/USB) via SAF, metadata editing that writes back to files, album art from MusicBrainz/iTunes/Deezer. CUE sheet support, EAC rip logs, duplicate detection.
- **Lyrics** — search via LRCLib.net, synced LRC editor, plain text fallback.
- **Widgets** — mini player, compact, and full-size widgets that work when the app is killed.
- **Flick Replay** — daily/weekly/monthly/yearly listening recaps you can save as PNG.
- **Last.fm scrobbling**, adaptive theming from album art, star ratings, sleep timer, waveform seek bar, FFT visualizer, vinyl disc animation.
- Receives playback handoffs from [Latch](https://github.com/moss-apps/Latch).

## Tech

Flutter (Riverpod, just_audio, Isar) on the frontend. Rust (Symphonia, rusb, cpal/Oboe, lofty) on the backend, bridged with flutter_rust_bridge. Android-only, minSdk 26.

## Build

```bash
flutter pub get
cd rust && cargo fetch && cd ..
flutter run
```

Or `flutter build apk --release`.

## Docs

- [`docs/DSD_ARCHITECTURE.md`](docs/DSD_ARCHITECTURE.md)
- [`docs/LIBRARY_SCAN_ARCHITECTURE.md`](docs/LIBRARY_SCAN_ARCHITECTURE.md)
- [`docs/hardware_volume_control.md`](docs/hardware_volume_control.md)
- [`docs/uac2/`](docs/uac2/)

## License

MIT. No ads, no premium features, no tracking.

## Contributors

- [@Harleythetech](https://github.com/Harleythetech)
- [@MagosVox](https://github.com/MagosVox)

---

I build this with [OpenCode](https://opencode.ai). It writes some of the comments and docs, and it's bailed me out of more than a few nasty-ass bugs. The code, the design calls, and the fuck-ups are all mine.
