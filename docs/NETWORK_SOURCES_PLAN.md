# Network Sources (Self-Hosted Local & Cloud) — Phased Plan

Play from self-hosted music servers — on-LAN NAS boxes and remote/cloud-hosted
instances — through the **existing Rust audio engine**, so bit-perfect PCM,
native DSD, the full DSP chain, gapless and crossfade all keep working. One
playback path. No second engine for "network songs."

Scope: a new `source` abstraction over the audio path, protocol adapters
(Subsonic, WebDAV, Jellyfin, later SMB/UPnP), a bounded on-device cache, and a
remote-library browser that reuses the existing songs/albums UI.

**Ponytail policy**: no new deps for v1. Subsonic and WebDAV are plain HTTP and
ride the existing `http` package. SMB and UPnP each need a crate/package and
are deferred until v1 proves the abstraction. Bytes go through the Rust engine
as a seekable `MediaSource` — same decoders, same DSP, same DSD pipeline. No
server-side transcode requests; if a server transcodes by default we pass the
raw-format params to opt out. We do not ship a parallel `just_audio` HTTP path.

**Status**: Phase 1 done. P1.1–P1.3 (`NetworkServerEntity` + registration in
`database.dart`, `SongEntity` source fields, `PlaybackSource.network`,
`NetworkCacheService` with LRU eviction; `path` promoted to a direct dep),
P1.4–P1.8 (SubsonicService, RemoteSourceService, Network Sources settings UI,
next-track prefetch, network cover art), and P7.1 + P7.2 (cache + Subsonic
auth unit tests) all shipped. Tests: `test/services/subsonic_service_test.dart`
(spec known-answer vector for auth, URL params, field mapping, pagination,
double-tolerant numeric fields).

Small deviations from the text below, all benign:
- Subsonic token order is the spec-correct `t = md5(password + salt)` — P1.4's
  parenthetical had the operands reversed; pinned by the P7.2 test.
- Download progress surfaces on `RemoteSourceService.downloadProgressNotifier`
  (a per-song download shouldn't pop the library-scan overlay); sync progress
  reuses the `ScanProgress` class over the same stream shape.
- Network songs get synthetic `subsonic://<serverId>/<remoteId>` file paths
  (unique, satisfies the composite index) and keep a `subsonic-cover://<id>`
  marker in `SongEntity.albumArtPath` so cover art re-resolves after eviction.
- Save does not auto-trigger a sync; sync is manual per server (refresh icon),
  matching F.2's "no background polling".
- Playback errors log via `LogSource.dart` (`LogSource.source` doesn't exist
  yet).

---

## A. What "self-hosted local & cloud server playing" means here

| Server class | Where it runs | Examples | Protocol |
|--------------|---------------|----------|----------|
| Subsonic-compatible | LAN or cloud | Navidrome, Airsonic/Advanced Airsonic, gonic, Bonob, Supysonic, Funkwhale, Ampache (Subsonic shim), Music Assistant (Subsonic endpoint) | Subsonic REST API (HTTP + XML/JSON) |
| WebDAV | LAN or cloud | Nextcloud Music, ownCloud, Synology WebDAV, generic | HTTP verbs (GET/PROPFIND) |
| Jellyfin | LAN or cloud | Jellyfin, *arr-compatible forks | Jellyfin REST API (HTTP + JSON) |
| SMB/CIFS share | LAN only | NAS boxes, Samba | SMB2/3 (new dep — deferred) |
| UPnP/DLNA media server | LAN only | ReadyMedia/minidlna, Gerbera, vendor NAS | UPnP MediaServer + ContentDirectory (new dep — deferred) |

**Out of scope:** commercial cloud streaming (Tidal/Spotify/Qobuz/Apple Music).
DRM and licensing are a different product. Tidal already has its own
`FEATURE_REQUESTS.md` line; it stays there until someone wants to pay for the
SDK. Self-hosted = you control the server, you own the files.

---

## B. The one real design fork: how bytes reach the engine

The Rust engine is path-based (`audio_api.rs`) and decodes from a
`MediaSource` (Read + Seek) trait. Two ways to feed it a network song:

1. **Cache-then-play.** Download the full file to a temp path, hand the path to
   the engine. Simplest. Loses instant-start. Wasteful for "skip after 5 s".
2. **Seekable HTTP `MediaSource`.** A Rust `HttpMediaSource` implementing
   `MediaSource` via HTTP `Range` requests: `read` pulls the next bytes, `seek`
   opens a new range. Engine streams over the network, bit-perfect, full DSP.
   Instant-start. Seek = one round-trip.

**Decision: v1 = cache-then-play. v2 = `HttpMediaSource`.** One playback path
either way — the difference is latency and storage, not architecture. v1 reuses
the exact `playFile(path)` call the engine already has; the only new piece is a
download job per song. v2 swaps the source object behind the same engine
entrypoint. No double engine, ever.

**Bit-perfect contract.** Adapters MUST request raw containers:
- Subsonic `stream`: no `maxBitRate`, no `format`/`convertedFormat` → raw file.
- Jellyfin `/Audio/<id>/stream`: no `container`/`audioCodec`/`bitrate`
  query → raw file. Reject `transcodingReason` in the response when possible.
- WebDAV `GET`: raw file by definition.

If a server forces transcode (rare for self-hosted), we surface a
"transcoded" badge in the UI and keep playing — no silent quality loss
disguised as bit-perfect.

---

## C. Where it plugs in

| Point | File | Change |
|-------|------|--------|
| `PlaybackSource` enum | `lib/models/playback_context.dart:1` | add `network` (and keep `folder` etc.). UI labels switch on it. |
| Song model | `lib/data/entities/song_entity.dart` | a `sourceType` (`local` \| `subsonic` \| `webdav` \| `jellyfin`) and `remoteId` (the server's song id) + `remoteServerId`. Local songs: both null. |
| Repository | `lib/data/repositories/song_repository.dart` | queries already filter by folder/source; add `byRemoteServer` filter for the browser. |
| Audio playback entrypoint | `lib/services/audio_player_service.dart` (or wherever `playFile(path)` lives) | branch: local → existing path; network → `NetworkSourceService.play(remoteSong)` → cache file → existing path. |
| Rust engine | `rust/src/api/audio_api.rs` | **unchanged in v1.** v2 adds `playFromHttp(url, headers)` and a `HttpMediaSource`. |
| Scanner | `lib/services/library_scanner_service.dart` | network "scan" is a metadata fetch, not a file walk. New `network_scanner_service.dart` per protocol. |
| Settings | `lib/features/settings/` | new "Network Sources" screen: list configured servers, add/edit/remove, test connection. |
| Cache | new `lib/services/network_cache_service.dart` | bounded LRU dir under `getApplicationCacheDirectory()/network_cache/`. Default 2 GB, configurable. Eviction on write past cap. |

**One `MediaSource`-shaped seam.** A `RemoteSource` Rust struct (v2) or a
`cachedFilePath` (v1) is the only thing the engine knows about. Protocol
adapters live entirely on the Dart side and produce either a cached file path
(v1) or an `(url, headers)` pair (v2). Rust never sees Subsonic or Jellyfin.

---

## D. Confirmed gaps (what does not exist yet)

| # | Gap | Severity | Location |
|---|-----|----------|----------|
| N1 | ~~No `remoteId` / `sourceType` / `remoteServerId` on `SongEntity`.~~ **Done (P1.2)** | High | `lib/data/entities/song_entity.dart` |
| N2 | ~~No `network` value on `PlaybackSource`; UI label plumbing assumes local.~~ **Done (P1.2)** | Medium | `lib/models/playback_context.dart:1` |
| N3 | ~~No `NetworkServer` config entity (id, label, protocol, baseUrl, user, token, lastSyncedAt).~~ **Done (P1.1)** | High | `lib/data/entities/network_server_entity.dart` |
| N4 | ~~No `NetworkCacheService` (bounded LRU download cache).~~ **Done (P1.3)** | High | `lib/services/network_cache_service.dart` |
| N5 | ~~No `RemoteSource` abstraction over the audio path (v1: path; v2: `MediaSource`).~~ **Done (P1.5, v1 path)** | High | `lib/services/remote_source_service.dart` (v1), `rust/src/audio/http_source.rs` (v2) |
| N6 | ~~No Subsonic adapter (auth salt+md5, `ping`/`getArtists`/`getAlbum`/`stream`).~~ **Done (P1.4)** | High | `lib/services/sources/subsonic_service.dart` |
| N7 | No WebDAV adapter (PROPFIND album list, GET file). | Medium | new `lib/services/sources/webdav_service.dart` |
| N8 | No Jellyfin adapter (`/Users/.../Items` browse, `/Audio/<id>/stream`). | Medium | new `lib/services/sources/jellyfin_service.dart` |
| N9 | ~~No "Network Sources" settings screen; no add/edit/test flow.~~ **Done (P1.6)** | High | `lib/features/settings/screens/network_sources_screen.dart` |
| N10 | Audio engine has no HTTP `MediaSource` (v2). | Medium (v2) | `rust/src/audio/source.rs`, `rust/src/api/audio_api.rs` |
| N11 | ~~Gapless/crossfade assumes next file is local & instant. Network next-track needs prefetch.~~ **Done (P1.7)** | Medium | `lib/services/player_service.dart` (`_maybePrefetchNextNetworkSong`) |
| N12 | No SMB adapter. | Low (deferred) | needs `smb_connect` or Rust `pavao`/`puffer` crate |
| N13 | No UPnP/DLNA media-server adapter. | Low (deferred) | needs `upnp-client` crate; `FEATURE_REQUESTS.md` already lists DLNA casting (separate direction) |
| N14 | ~~Album-art, lyrics, and Replay hand off network songs through paths that assume local files.~~ **Done (P1.8)** | Medium | `album_art_service.dart`, `lyrics_service.dart`, `recap` — resolve network art to cache bytes, lyrics to LRCLib as today |

---

## E. Phases

### Phase 1 — Subsonic-compatible (covers ~80% of self-hosted servers)

| Task | Gap | Change |
|------|-----|--------|
| P1.1 **(done)** | N3 | `NetworkServerEntity` (id, label, protocol, baseUrl, username, token (salted-hash, not plaintext — store the Subsonic `sHex` salt+md5 form), lastSyncedAt). Register in `database.dart`. |
| P1.2 **(done)** | N1, N2 | Add `sourceType`, `remoteId`, `remoteServerId` to `SongEntity`; `network` to `PlaybackSource` with label "Network"; UI label plumbing. Local songs: the three new fields null. |
| P1.3 **(done)** | N4 | `NetworkCacheService`: LRU dir with size cap (default 2 GB), `getPath(remoteServerId, remoteId)` → cached `<hash>.<ext>` or null, `stash(bytes, ...)` evicting oldest past cap. One class, stdlib + `path` + `crypto` (already deps). |
| P1.4 **(done)** | N6 | `SubsonicService`: salt+md5 auth (`t=md5(password+salt)&s=<salt>` — spec order, password first), `ping`, `getAlbumList2` (paginated) / `getAlbum` (build `SongEntity`s with `sourceType=subsonic`, synthetic `subsonic://<serverId>/<remoteId>` paths), `getCoverArt` → album-art cache via `album_art_service.dart`, `stream(id)` → `http.get(stream)` with no transcode params, body → `NetworkCacheService.stash`. Sync = metadata fetch + upsert + stale purge + `lastSyncedAt` stamp. |
| P1.5 **(done)** | N5, v1 | `RemoteSourceService.ensureLocal(remoteSong)`: cached → existing local path; miss → download (progress on `downloadProgressNotifier`), then play. `player_service.dart` branches at the top of `_resolvePreparedPlaybackPath`, so both engines (just_audio + Rust) reuse it. |
| P1.6 **(done)** | N9 | "Network Sources" settings screen: list (label, protocol chip, URL, synced-at, edit/delete/sync), add (URL + user + password + "Test" button), edit, delete. Test calls `ping`. Protocol picker: Subsonic enabled; WebDAV/Jellyfin/SMB/UPnP greyed with "needs a new dependency". Password salted+hashed at save, plaintext never persisted. |
| P1.7 **(done)** | N11 | Prefetch: 5 s position timer checks position ≥ duration − 10 s and next song is `sourceType=subsonic`, starts `stream(id)` download into cache (marker prevents repeats) so gapless/crossfade reads a local path at handoff. |
| P1.8 **(done)** | N14 | Cover art for network songs resolves via `getCoverArt` bytes (marker `subsonic-cover://<id>` in `albumArtPath`) → existing `albumArtPath` cache flow; lyrics fall back to LRCLib as today (network songs have no local tags to mine). |

### Phase 2 — WebDAV (Nextcloud, ownCloud, generic)

| Task | Gap | Change |
|------|-----|--------|
| P2.1 | N7 | `WebDavService`: `PROPFIND` on the music root with Depth:1 to list folders-as-albums, recursive `PROPFIND` for tracks, basic-auth or bearer token. Build `SongEntity` with `sourceType=webdav`, `remoteId` = file URL. Cover art: `Thumbs`/`Cover.jpg` conventions or skip (fall back to `getCoverArt`-style “first image in folder”). |
| P2.2 | — | Register WebDAV in `NetworkServerEntity.protocol`. Settings add/edit flow branches on protocol. |
| P2.3 | — | `RemoteSourceService` extension: WebDAV `GET` → cache, same `playFile` path. |

### Phase 3 — Jellyfin

| Task | Gap | Change |
|------|-----|--------|
| P3.1 | N8 | `JellyfinService`: `/Users/AuthenticateByName` for token, `/Users/<id>/Items?IncludeItemTypes=MusicAlbum`, `/Items?ParentId=...` for tracks, `/Audio/<id>/stream` for bytes (no transcode params). `remoteId` = Jellyfin `Item.Id`. |
| P3.2 | — | Register branch. Cover art via `/Items/<id>/Images/Primary` → cache. |

### Phase 4 — Seekable HTTP `MediaSource` (v2, latency win)

| Task | Gap | Change |
|------|-----|--------|
| P4.1 | N10 | New `rust/src/audio/http_source.rs`: `HttpMediaSource { url, headers, pos, range_buf }` implementing `Symphonia` `MediaSource` (`read`/`seek`/...). `seek` = drop buffer, save target offset; next `read` issues `Range: bytes=N-`. Headers carry Subsonic/Jellyfin/WebDAV auth. |
| P4.2 | N10 | `rust/src/api/audio_api.rs`: `play_from_http(url, headers)` mirror of the existing path-based entrypoint, swaps only the `MediaSource` construction. Everything downstream (DSP, DSD, gapless) is reused. |
| P4.3 | N5 | `RemoteSourceService.play` v2 path: prefer `play_from_http` when range supported (Subsonic `stream` ✓, WebDAV GET ✓, Jellyfin stream ✓ — all return `Accept-Ranges: bytes`). Fall back to cache-then-play if server says no ranges or on transport error. |
| P4.4 | — | Cache becomes a prefetch/seek-ahead buffer, not a full-file requirement. Keep `NetworkCacheService` for offline and replay; size cap stays. |

### Phase 5 — SMB (LAN only; needs a new dep)

| Task | Gap | Change |
|------|-----|--------|
| P5.1 | N12 | Evaluate `pavao`/`puffer` (Rust SMB2/3) vs Dart `smb_connect`. Decision driven by: does it go through the Rust engine (preferred — keeps DSP) or only through `just_audio`'s URI handler (rejected — loses engine). If no Rust crate is acceptable, **defer or skip SMB.** SMB isn't worth a second playback path. |
| P5.2 | — | If a Rust path: `SmbSource` implementing `MediaSource` like the HTTP one, mounted lazily. Auth via NTLMv2. Read-only — we never write back metadata edits to SMB shares in v1. |

### Phase 6 — UPnP/DLNA media-server browsing (LAN only; needs a new dep)

| Task | Gap | Change |
|------|-----|--------|
| P6.1 | N13 | Evaluate `upnp-client` Rust crate for ContentDirectory browsing + `http-get` resource URLs. The DLNA *casting* item in `FEATURE_REQUESTS.md` is a different direction (Flick as renderer); this phase is Flick as **control point / player pulling from a media server**. Don't conflate them. |
| P6.2 | — | If adopted: same `MediaSource` seam as HTTP/SMB; resources are plain HTTP `res` URLs, so they may ride the Phase 4 `HttpMediaSource` directly with no new Rust code. |

### Phase 7 — Self-checks (ponytail: one runnable check per non-trivial unit)

| Task | Change |
|------|--------|
| P7.1 **(done)** | Dart unit test for `NetworkCacheService`: cap is enforced; LRU evicts oldest on overflow; `stash` then `getPath` returns the same file. |
| P7.2 **(done)** | Dart unit test for `SubsonicService` auth: known salt+password (`sesame`/`c19b2d` → `t=26719a1196d2a940705a59634eb18eab`), asserts `t=`/`s=` query params against the spec form `md5(password+salt)`; mock `http.Client` for `ping`/`getAlbum`/`getAlbumList2`. |
| P7.3 | Dart integration test: configure a server pointing at a fixture (or a recorded HTTP cassette), "scan" returns `SongEntity`s with `sourceType=subsonic` and `remoteId` set. |
| P7.4 | (v2) Rust `#[test]` for `HttpMediaSource`: a `Cursor`-backed fake server, `read` returns contiguous bytes, `seek` followed by `read` returns the right slice, `stream_len` matches. |
| P7.5 | Manual: real Navidrome + real Jellyfin + a Nextcloud over WebDAV, on both LAN and a cloud VPS, through a USB DAC. Confirm bit-perfect badge, native DSD passthrough on a DSF served by Navidrome, gapless between two network songs, crossfade between a local and a network song. |

---

## F. Procedures (operational)

### F.1 Adding a server (user flow)

1. Settings → Network Sources → Add.
2. Pick protocol: Subsonic / WebDAV / Jellyfin. (SMB/UPnP listed but
   greyed-out until Phase 5/6 land, with a one-line "needs a new dependency"
   note.)
3. Enter label, base URL, username, password (Subsonic) / bearer token
   (WebDAV) / username+password (Jellyfin, exchanged for a token on first
   connect). Stored on `NetworkServerEntity`. Passwords never logged; the
   Subsonic salt+md5 is computed at save time and stored as the
   `salt:md5hex` token — plaintext is not retained.
4. "Test connection" → adapter `ping`/`PROPFIND`/`AuthenticateByName`. Show
   pass/fail with the server-reported version string.
5. Save, then sync manually per server (refresh icon) — F.2's "no background
   polling" applies.

### F.2 Library sync (not a file walk)

- Network "scan" = fetch the server's album/track index via the adapter's
  browse call, upsert `SongEntity` rows with `sourceType` + `remoteId` +
  `remoteServerId`. Same Isar DB, same UI query paths.
- Differential: store `lastSyncedAt` on `NetworkServerEntity`; adapters expose a
  "changed since" query where the protocol supports it (Subsonic
  `getAlbumList2?type=newest&size=...` + `ifModifiedSince`; Jellyfin
  `/Items?MinDateCreated=...`). WebDAV falls back to full `PROPFIND` with
  `getlastmodified` comparison.
- Manual re-sync per server. No background polling by default (ponytail: don't

  burn battery for a feature that's only useful when the user opens the app).

### F.3 Playback

- Tap a network song → `RemoteSourceService.ensureLocal`:
  - **v1:** `NetworkCacheService.getPath(...)` → hit → cached path. Miss
    → download `stream`/`GET`/`/Audio/.../stream` with raw-format params →
    `stash` → cached path. Progress on `downloadProgressNotifier`.
  - **v2:** `play_from_http(url, headers)` if range-supported, else v1 path.
- Gapless/crossfade: prefetch next network song into cache when current
  position ≤ duration − 10 s (Phase 1.7). The crossfader already reads file
  paths; it doesn't care they came from HTTP.
- Error handling: transport failure mid-stream → log via `app_log.dart`
  (`LogSource.dart`; `LogSource.source` doesn't exist yet), surface a toast,
  advance or halt per user setting. Partial cache file deleted.

### F.4 Cache & storage

- Location: `getApplicationCacheDirectory()/network_cache/<serverId>/<hash>.<ext>`.
- Cap: 2 GB default, configurable in Settings. Eviction is LRU by
  last-accessed mtime; eviction runs after each `stash`.
- Offline: a network song whose cache file exists is playable with the server
  offline. We do not pre-emptively cache whole libraries — ponytail: storage
  cost would dwarf the feature.
- Metadata edits: write-back is local-only (`metadata_editor.rs`). Editing a
  network song is a no-op with a toast, not silently written to cache.

### F.5 DSP & DSD

- Network songs run through the same 31-band EQ, convolution reverb, dynamics,
  crossfade, waveform seek bar, FFT visualizer. No branching in the DSP path.
- Native DSD served by a Subsonic server (Navidrome can serve DSF): the
  `dsd_native_backend` reads from the cached path (v1) or the
  `HttpMediaSource` (v2) identically to local DSD. Confirm with the P7.5
  manual check. DoP/USB DAC path unchanged.

### F.6 Security

- Plaintext passwords never persisted. Subsonic stores salt+md5 form only;
  Jellyfin stores the server-returned token; WebDAV stores a bearer token or a
  username:base64(password) for basic auth. All in Isar, not in shared prefs.
- HTTP (not HTTPS) base URLs are allowed but warn on save (self-hosted LAN is
  fine; cloud should be HTTPS). No cert pinning in v1.

---

## G. Risks & open questions

- **Bit-perfect contract vs server transcode.** Most self-hosted servers
  serve raw by default, but a misconfigured Navidrome/Jellyfin profile can
  transcode. Mitigation: adapters pass the explicit "no transcode" params;
  UI surfaces a "transcoded" badge if the response `Content-Type`/length
  disagrees with the known file size. We never *claim* bit-perfect on a
  network song that came back smaller than expected.
- **Seek latency (v2).** Each seek = one HTTP round-trip. On a high-latency
  cloud server this is perceptible. Mitigation: read-ahead buffer (a few MB
  past the current position) so small seeks stay in buffer. Cache-then-play
  (v1) has no seek penalty, which is why it's v1.
- **Range support.** Subsonic `stream`, WebDAV `GET`, and Jellyfin `stream`
  all advertise `Accept-Ranges: bytes` in practice. If a server doesn't, v2
  falls back to v1 (download-then-play) automatically. No user-visible
  difference except seek lag.
- **Large libraries over the wire.** A 50k-track Navidrome sync is a lot of
  `getAlbum` calls. Differential sync + a per-server "full re-sync" button
  (under the ellipsis menu, beside the existing ones in
  `library_settings_screen.dart:1140`) keep it bounded. Phase 1 caps initial
  sync to recent N; streaming the rest on browse.
- ** smb / UPnP new-dep gate.** Both need a crate/package the project doesn't
  have. CONTRIBUTING.md says no new deps without a reason. The reason is
  "users asked for NAS shares / DLNA media servers." Only after v1 (Subsonic
  + WebDAV + Jellyfin) is in, real users bump into the gap, and the chosen
  crate is audited. Don't pre-add.
- **DLNA casting confusion.** This plan is Flick *pulling from* a DLNA media
  server (Phase 6). The `FEATURE_REQUESTS.md` DLNA/Chromecast/UPnP items are
  Flick *pushing to* a renderer. Different directions, different code, don't
  merge them in one PR.
- **Tidal / commercial cloud.** Explicitly out. DRM, licensing, dev keys,
  NDAs. Separate effort, separate plan if ever.
- **just_audio's HTTP capability.** The project already has `just_audio`,
  which can stream HTTP URLs out of the box. Using it would be the "one line"
  rung of the ladder — but it bypasses the Rust engine and loses bit-perfect,
  DSD, EQ, reverb, gapless, the lot. That's not Flick. The one-line option is

  rejected here because it violates the product's core contract; cache-then-
  play through the existing path is the lazy solution that *keeps the product
  the product*.