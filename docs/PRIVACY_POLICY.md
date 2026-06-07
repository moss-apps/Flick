# Privacy Policy

**Last updated:** May 4, 2026

**Flick Player** ("the App") is developed by **Ultra Electronica** ("we", "us", or "our"). This Privacy Policy explains how the App handles data and user privacy.

By using the App, you agree to the terms described in this Privacy Policy.

---

## 1. Data Collection

**Flick Player does not collect, store, or transmit any personal data.**

The App is designed with privacy as a core principle. Specifically:

- **No personal information** is collected (no name, email, phone number, location, device identifiers, etc.)
- **No usage analytics** are gathered
- **No crash reports** are sent to external servers
- **No advertising identifiers** are accessed or transmitted
- **No data is shared** with third parties because no data is collected

---

## 2. Local Data

All data generated or used by the App is stored **locally on your device** only:

- **Music library metadata** (ID3 tags, Vorbis comments) extracted from your local music files
- **Play history** (recently played tracks, play counts)
- **User-created playlists**
- **Equalizer presets and settings**
- **App preferences** (theme, playback settings)
- **Last.fm scrobbling credentials** (stored securely on-device via Flutter Secure Storage)

This data never leaves your device unless you explicitly use an integration described below.

---

## 3. Camera and Photos

The App requests access to your **camera** and **photo library** solely for the **Flick Replay** feature, which generates listening recap posters.

- **Camera access** is used only when you choose to take a photo to use as a custom poster background
- **Photo library access** is used only when you choose to select an existing photo as a poster background or when saving generated recap images to your gallery
- **No photos or camera images** are uploaded, transmitted, or stored outside your device
- Photos are used **only at your explicit request** and remain entirely local

You can deny camera/photo permissions at any time through your device settings. The core functionality of the App (music playback, library management, equalizer) will continue to work without these permissions.

---

## 4. Storage Permissions

The App requires access to your device's **storage** to:

- Scan and read music files from your local storage
- Read audio metadata (tags, album art, lyrics)
- Import/export equalizer presets
- Save recap images to your gallery

No files are uploaded or transmitted externally. All processing happens on-device.

---

## 5. USB Device Access

The App accesses **USB Audio Class 2.0 (UAC 2.0)** devices (external DACs/AMPs) for bit-perfect audio playback.

- USB device enumeration is performed locally
- No USB device information is transmitted externally
- The App only communicates with the USB audio device for audio streaming purposes

---

## 6. Third-Party Integrations

### 6.1 Last.fm Scrobbling

If you choose to connect your Last.fm account:

- Your Last.fm **username and password** are stored securely on-device
- Play data (artist, track, album, timestamp) is sent **only to Last.fm** for scrobbling purposes
- We do not receive, store, or process this data

### 6.2 Album Art Import

When you use the album art import feature:

- The App queries public APIs (**MusicBrainz/Cover Art Archive, iTunes, Deezer**) to find matching album art
- Search queries are based on local music metadata (artist, album name)
- Downloaded images are cached locally on your device
- No personal data is sent to these services

### 6.3 Moss Ecosystem (Latch Integration)

Flick Player is part of the **Moss ecosystem**. It can receive playback handoffs from **Latch** (another Moss app):

- Playback intents contain only song file paths/metadata needed for playback
- No personal data is exchanged between apps
- The integration is entirely local on your device

### 6.4 In-App Updates

- **Play Store updates**: The App uses Google Play In-App Update API, which is governed by Google's privacy policies
- **Patch notes**: Release notes are fetched from **GitHub Releases API** — no personal data is sent

---

## 7. Internet Access

The App requires internet access for:

- Fetching album art from online sources (MusicBrainz, iTunes, Deezer)
- Last.fm scrobbling (if enabled by you)
- Checking for app updates and fetching patch notes from GitHub

No personal data is transmitted during these operations beyond what is necessary for the specific feature (e.g., album/artist name for art lookup, scrobble data for Last.fm).

---

## 8. Children's Privacy

The App does not knowingly collect any information from anyone. The App is designed to not collect data from any user, regardless of age.

---

## 9. Changes to This Privacy Policy

We may update this Privacy Policy from time to time. Changes will be reflected in the "Last updated" date at the top of this document. We encourage you to review this Privacy Policy periodically.

---

## 10. Contact

If you have any questions or concerns about this Privacy Policy, please contact us:

- **GitHub**: https://github.com/anomalyco/opencode/issues
- **Email**: [Your contact email]

---

*Flick Player is open-source software licensed under the MIT License. You can review the source code to verify the claims made in this Privacy Policy.*
