# Flick Player — Feature Requests

> User-submitted suggestions. Not prioritized or committed.

---

## Casting & Streaming

- [ ] **DLNA casting** — stream to DLNA-compatible receivers
- [ ] **Chromecast casting** — stream to Chromecast devices
- [ ] **UPnP casting** — stream to UPnP devices
- [ ] **Chromecast Output selection** — per-output-device routing (Wired Headset/AUX, Speaker, Bluetooth, USB DAC, Other)

---

## UI & Themes

- [ ] **Liquid Glass UI Theme** — glassmorphism-style theme variant
- [ ] **Audio Quality Badges** — show badges under the time bar (e.g. Dolby Atmos, Lossless, AAC)
- [ ] **Apple Music Animated Album Art** — animated album art on player screen
- [ ] **Immersive Animated Album Player Art** — full-bleed animated player background
- [ ] **Library screen grid 3×X** — configurable grid column count

---

## Audio Formats & Processing

- [ ] **Dolby Atmos support** — decode and play Dolby Atmos content
- [ ] **HRTF support** — head-related transfer function for spatial audio
  - [ ] HRTF preset library
  - [ ] Optional HRTF scan upload
- [ ] **MQA (Master Quality Authenticated)** — decode and play MQA content

---

## Audio Output Engines

- [ ] **OpenSL ES Output** — OpenSL ES audio backend
- [ ] **AudioTrack Output** — Android AudioTrack backend
- [ ] **Hi-Res Output** — high-resolution audio output path
- [ ] **AAudio Output** — AAudio backend (Android 8.1+)

---

## Bluetooth

- [ ] **Shizuku integration** — true in-app A2DP codec switching (LDAC/aptX/sample-rate) without root. Routes the hidden `BluetoothA2dp.setCodecConfigPreference` through Shizuku's privileged context. One-time setup: user installs Shizuku and starts it via ADB. Fallback for devices where the non-SDK API blocklist exemption (`setHiddenApiExemptions`) is patched out by the OEM/Android version.

---

## Integrations

- [ ] **Tidal integration** — Tidal streaming service support
- [ ] **Local Media Server** — stream music from NAS / network shares

---
