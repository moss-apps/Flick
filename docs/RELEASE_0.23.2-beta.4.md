# Flick 0.23.2-beta.4

Landscape layouts, route-aware tutorials, Latin American Spanish, orbit card backgrounds, and live audio diagnostics — plus safer physical-output volume and SAF metadata editing.

## Localization

- **Español (Latinoamérica)** — Latin American Spanish joins the language picker as a draft pending native-speaker review. System Spanish locales (including `es_MX` and `es_419`) resolve to the same `es` copy, search keywords are translated, and the choice persists across restarts; the Taglish Baybayin switch does not apply to Spanish.
- **Taglish UI Customization** — Track Thumbnails, Progress Bar, and Album Colors stay in English under Taglish, matching the rest of the English-role catalog.
- **Day-count streak greeting** — the Taglish streak popup now rotates five fixed greetings plus a line that fills in the current streak length.

## Interactive Tutorial

- **Route-aware guides with a picker** — the single spotlight tour is now five guides: Core, Library, Player, Appearance, and Audio. Each keeps its own completed or dismissed state, can be started from the tutorial picker or Settings → App info → Interactive Tutorial, and deep-links into the relevant manual section.
- **Real actions advance steps** — highlights follow actual navigation and playback, ignore zero-size or off-route widgets, and let library, search, sort, queue, and lyrics actions complete the current step. Back skips the guide, modals and permission pickers suspend it, and What's New waits until the tutorial closes.

## Landscape & Adaptive Layout

- **Landscape unlocked** — Flick no longer forces portrait. Layouts key off window size: wide windows get a scrollable side navigation rail and side mini player, the full player splits into stage and controls, and bottom sheets use the full window and scroll under large text and the keyboard.
- **Animated mini player dock** — in short landscape windows the mini player glides between the bottom bar and the compact orbit strip, keeping both layouts mounted, muting and ignoring input on the inactive side, and snapping under reduced motion.
- **Landscape orbit** — orbit geometry, card count, size, depth, spacing, and focal position are persisted independently from portrait, with a profile selector and per-profile reset in Orbit settings.
- **Edge-to-edge orbit** — the ribbon and cards paint behind the library header, search bar, mini player, and navigation bar while staying clipped to the Songs screen; card faces are cached so motion keeps decoded artwork.

## Orbit & Customization

- **Card background styles** — Orbit settings gains a Card Background selector for Blur gradient, Black gradient, and Album-color gradient. Blurred covers are rasterized once, cached, and preloaded for a moving lookahead window instead of live-filtered while scrolling.
- **Live orbit preview** — a browse-only preview stays pinned at the top of Orbit settings, tracks every layout change, expands, and opens full screen without touching playback or the queue.
- **Progress bar size** — UI Customization now exposes Waveform height and Line thickness sliders with a live preview and per-style reset; painted bars scale while keeping a 48 dp touch target.
- **Immersive background style** — Player Layout adds a Blur gradient option that renders un-scrimmed blurred artwork fading into the foreground, mirrored in the immersive and full-screen previews.
- **Song card polish** — cards use a padded glass border, keep artwork above a scrollable one-line footer, and use a smaller accent-aware selection indicator; detail headers keep lossless and long translated labels from overflowing.

## Metadata & Library

- **SAF metadata write-back** — on content:// libraries, the metadata editor stages a private copy for the Rust tagger and streams edits back over the original document. Providers that reject `"wt"` truncation fall back to `"w"`, stale edit copies are pruned after 24 hours, and missing files or lost permission surface localized errors.
- **Online artist and album information toggle** — Settings → Integrations → Metadata can hide Apple Music biographies, similar artists, top songs, album notes, and new artist-portrait downloads. The preference is independent of post-scan album identification, defaults to on, and late provider results cannot restore hidden content.
- Apple Music provider hashes were regenerated for the current provider schema.

## Audio & Diagnostics

- **Physical output volume guard** — wired and analog outputs, with an attached UAC2 DAC as fallback, get a safety volume ceiling once per connection on the standard engine. The shared gain path keeps the ceiling through crossfade ramps and player swaps, blocks manual changes until the guard settles, restores DAC volume on attach, and retries failed safety writes.
- **Live DSP and output telemetry** — Diagnostics now reports PCM and managed-output callback counts and durations, overruns and xruns, lock misses, starved samples, skipped DSP stages, peak/clipping, and non-finite samples. Callback-safe atomics, a seqlock for playback progress, lock-free stage mirrors, and a coalesced EQ mailbox keep the audio thread from locking or logging.
- **SMB account formats and interrupted syncs** — `DOMAIN\user` and `user@domain` usernames now reach NTLM split into the account and domain a Windows client would send. If a library walk is interrupted, already-listed tracks are imported, stale rows are not purged, and the failure still surfaces so the next sync can finish the job.
- **SMB sync resilience** — an unreadable or vanished child folder no longer aborts the whole library scan; directory loops are depth-capped and duplicate paths are skipped. Folder art larger than the server's single-READ limit now loads through the pipelined reader.
- **SMB playback robustness** — a failing progress callback can no longer cancel a shared transfer or start a duplicate download, cache accounting failures no longer discard a completed file, a disappearing cache entry is treated as a miss, a changed remote file invalidates its cached bytes on resync, and a failed next-track download reports cleanly instead of throwing in the background.

## Builds & Flavors

- **This GitHub download uses the `full` flavor** — it declares **All Files Access** (`MANAGE_EXTERNAL_STORAGE`) for the raw Rust filesystem scanner and complete DSD/WavPack coverage. Build: `flutter build apk --flavor full --release`.
- **Google Play uses the `play` flavor** — no All Files Access (Play policy for media apps); it scans via MediaStore/SAF plus the DSD/DSF/WavPack reconciliation path. Build: `flutter build appbundle --flavor play --release`.
- Both flavors share `applicationId` `com.mossapps.flick`, so either installs over the other.

## Getting Started

1. Spanish: Settings → Interface → Language → **Español (Latinoamérica)** (draft; native-speaker review pending)
2. Interactive tutorial: Settings → App info → Interactive Tutorial, or finish onboarding and pick a guide
3. Landscape: rotate the device or resize the window; the side rail and split player appear on wide windows
4. Orbit card backgrounds: Settings → Playback & Display → Songs View → Orbital → Customize Orbital → Card Background
5. Orbit preview: Settings → Playback & Display → Songs View → Orbital → Customize Orbital (preview pinned at the top; tap to expand)
6. Progress bar size: Settings → UI Customization → Progress Bar
7. Immersive background: open the player layout sheet → Immersive → Background → **Blur gradient**
8. Physical output volume: connect wired headphones or a USB DAC and press Play; the safety ceiling is applied once per connection
9. SAF metadata edits: edit a song's tags from a content:// library; the write-back path handles staging and permissions
10. Audio diagnostics: Settings → Audio → USB Audio (UAC2) → UAC2 Preferences → **Show verbose audio diagnostics and engine/session trace logs**
