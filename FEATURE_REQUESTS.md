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

## ~~Audio Analysis~~ — too far for now.

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

- [x] **DLNA casting** — stream to DLNA-compatible receivers
- [x] **Chromecast casting** — stream to Chromecast devices
- [x] **UPnP casting** — stream to UPnP devices
- [x] **Chromecast Output selection** — per-output-device routing (Wired Headset/AUX, Speaker, Bluetooth, USB DAC, Other)

---

## UI & Themes

- ~~**Liquid Glass UI Theme**~~ — almost identical to the original theme, will be replaced by light/dark theme selection instead.
- [X] **Audio Quality Badges** — show badges under the time bar (e.g. Lossless, AAC, Hi-Res)
- [X] **Apple Music Animated Album Art** — animated album art on player screen
- [X] **Immersive Animated Album Player Art** — full-bleed animated player background
- [X] **Visualizer color modes & fading blocks** — follow album-cover colors, rainbow spectrum, or monochrome; new Fading Blocks style with softly decaying trails.
- [ ] **Offline animated album covers** ([#282](https://github.com/moss-apps/Flick/issues/282)) — manually select a local animated cover and apply it across an album; discover named motion files beside music (for example `motion.mp4` or `cover.mp4`). Resolve manual overrides before folder artwork, online motion art, and static fallback. Preserve imported animations, use durable app storage, and support granted SAF/removable-storage folders. Keep video muted and respect reduced-motion and exclusive-output suppression. The reported inconsistent online artwork across album tracks still needs an affected album's tags/logs to reproduce.
- [ ] **Library screen grid 3×X** — configurable grid column count
- [ ] **Landscape mode** — proper landscape layouts for library and player screens (e.g. side-by-side player with artwork/queue, wider list/grid columns)

---

## Source-quality estimation — deferred

- [ ] **Lossless-origin check** ([#282](https://github.com/moss-apps/Flick/issues/282)) — request to identify MP3-to-FLAC conversions, upsampling, or padded bit depth. Recorded for future scope review; overlaps the declined audio-analysis features above. Audio alone cannot prove a recording's origin. Any future implementation should be an opt-in, offline estimate with supporting evidence and an inconclusive/unsupported result, rather than a binary “true/fake lossless” badge. Validate false positives on genuine bandwidth-limited recordings before shipping; keep analysis separate from playback, preload, and ReplayGain.

---

## Audio Formats & Processing

- ~~**Dolby Atmos support**~~ — too far. Licensed decoder, massive effort.
- ~~**HRTF support**~~ — too far. Complex spatial DSP, different product.
  - ~~HRTF preset library~~
  - ~~Optional HRTF scan upload~~
- ~~**MQA (Master Quality Authenticated)**~~ — too far. Licensed, instant bankrupt for me.
- [X] **Pitch shifter** — adjust audio pitch independently of tempo
- [X] **Replay Gain (track & album)** — apply per-track or per-album loudness gain on playback; album mode keeps relative levels, track mode normalizes every track. Clipping prevention (peak limiting when gain pushes past 0 dBFS) included.
- [X] **Replay Gain scanner** — batch-scan library (or per-track) using ReplayGain 2.0-style loudness analysis (EBU R128/LUFS), store values as tags or in a local DB.
- [X] **Crossfeed (BS2B)** — 3-stage Bauer stereophonic-to-binaural crossfeed DSP to reduce ear fatigue on headphones; selectable crossfeed level (Off/Default/Crossfeed/Crossfeed easy) built into the Rust DSP pipeline. Shipped as `_CrossfeedSection` in Audio settings; bypassed in bit-perfect passthrough and under 432 Hz tuning.

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

- [x] **Tidal integration** — Tidal streaming service support (reverse-engineered web/OAuth2 path: user signs in with their own account; HiFi lossless FLAC/ALAC through the bit-perfect engine; HiRes/MQA/Atmos gated by Tidal and surfaced as an error).
- [X] **Local Media Server** — stream music from NAS / network shares. Shipped as Network Sources (`docs/NETWORK_SOURCES_PLAN.md`): Subsonic (Navidrome/Airsonic/gonic/etc.), WebDAV (Nextcloud/ownCloud/Synology/generic), Jellyfin, and UPnP/DLNA media-server browse/play, all through the existing Rust engine (bit-perfect/DSD/gapless preserved). SMB is a loud-failing placeholder recommending the WebDAV workaround.
- [ ] **Discord Rich Presence** — show “Listening to Flick” with the current track, artist/album, playback timer, and Flick logo on Discord, including the mobile app. Feasible through Discord Social SDK 1.10+ unauthenticated Android presence when the Discord app is installed and signed in; no OAuth or account linking required. Needs Discord Developer Portal approval for a music app, the proprietary native `discord_partner_sdk.aar` (not committable to the repo), a thin Flutter/JNI bridge, and opt-in privacy handling. Local album art cannot be used; use a static Flick asset. **Status: still thinking about it.**

---
