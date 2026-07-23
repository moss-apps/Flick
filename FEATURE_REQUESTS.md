# Flick Player — Feature Requests

> User-submitted suggestions. Not prioritized or committed.

---

## Album list view — additional columns

The album list view (`_AlbumListTile` in
`lib/features/songs/screens/songs_screen.dart`) currently shows artwork, album
name, track count, artist, and (newly added) **Year**.

- **Genre** column — derivable from `Song.genre` (first non-null across the
  album's songs, same scan pattern used for Year).
- **Total duration** column — sum of `Song.duration` across the album's songs.
- ~~**Track count as its own column**~~ — already shown inline. Don't add a column for a single integer.

---

## ~~Audio Analysis~~ — too far. This is an audio analyzer/lab, not a music player.

### Measurement

- ~~TT Dynamic Range (DR) measurement~~
- ~~LUFS loudness analysis~~
- ~~True Peak (dBTP)~~
- ~~Loudness Range (LRA)~~
- ~~Clipping detection~~
- ~~Effective bit-depth estimation~~
- ~~Spectral bandwidth analysis~~
- ~~Fake-lossless detection~~
- ~~Overall fidelity scoring~~
- ~~Mastering quality grading~~
- ~~Cached analysis~~
- ~~Batch album analysis~~
- ~~Exportable analysis reports~~

### Spectrogram

- ~~Calibrated FFT spectrogram~~
- ~~True re-analysis while zooming~~
- ~~Higher FFT resolution on deeper zoom~~
- ~~Stereo / Left / Right / Mid / Side view~~
- ~~Linear & Log frequency scales~~
- ~~Tap-to-inspect (Hz, dB, Time)~~
- ~~Full Nyquist display~~
- ~~Exportable spectrogram images~~

---

## Casting & Streaming

- [ ] **DLNA casting** — stream to DLNA-compatible receivers
- [ ] **Chromecast casting** — stream to Chromecast devices
- [ ] **UPnP casting** — stream to UPnP devices
- [ ] **Chromecast Output selection** — per-output-device routing (Wired Headset/AUX, Speaker, Bluetooth, USB DAC, Other)

---

## UI & Themes

- ~~**Liquid Glass UI Theme**~~ — almost identical to the original theme, will be replaced by light/dark theme selection instead.
- [X] **Audio Quality Badges** — show badges under the time bar (e.g. Lossless, AAC, Hi-Res)
- [X] **Apple Music Animated Album Art** — animated album art on player screen
- [X] **Immersive Animated Album Player Art** — full-bleed animated player background
- [ ] **Library screen grid 3×X** — configurable grid column count

---

## Audio Formats & Processing

- ~~**Dolby Atmos support**~~ — too far. Licensed decoder, massive effort.
- ~~**HRTF support**~~ — too far. Complex spatial DSP, different product.
  - ~~HRTF preset library~~
  - ~~Optional HRTF scan upload~~
- ~~**MQA (Master Quality Authenticated)**~~ — too far. Licensed, instant bankrupt for me.
- [ ] **Pitch shifter** — adjust audio pitch independently of tempo

---

## Audio Output Engines

- [x] **OpenSL ES Output** — exposed as a selectable option in the "Android Audio API" settings dialog.
- [ ] **AudioTrack Output** — partially covered; the `normalAndroid` path already drives `AudioTrack` under the hood, and `DsdNativeBackend` uses it for ENCODING_DSD.
- [x] **Hi-Res Output** — covered by existing hi-res machinery (Bit-perfect, Hi-Res Direct Bluetooth).
- [x] **AAudio Output** — exposed as a selectable option in the "Android Audio API" settings dialog.

---

## Bluetooth

- [ ] **Shizuku integration** — true in-app A2DP codec switching (LDAC/aptX) without root. Requires Shizuku + ADB setup.

---

## Integrations

- [ ] **Tidal integration** — Tidal streaming service support
- [ ] **Local Media Server** — stream music from NAS / network shares

---
