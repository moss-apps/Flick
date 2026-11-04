# Flick 0.23.1-beta.3

A new onboarding poster system, a narrower bottom bar, safer USB DAC volume, and atomic SMB playback.

## Onboarding

- **Onboarding is now a Flick Replay poster system** — five full-bleed pages share Replay's acid, signal, ink, and paper palette but change composition, artwork, and button treatment per page. Authored vector scenes replace generic placeholders, including the official dotted Flick mark, stacked sleeves, a turntable, and a dotted path.
- **Type that fits** — headline sizes are measured against the real locale and text scaler (up to 96), with enlarged text dropping to a readable 30–44 range and whole-word fitting instead of clipping or ellipsis. Wide windows use a two-column poster; short windows scroll the copy while the footer action stays pinned.
- **Calmer motion and chrome** — the staggered entrance skips to the final frame under reduced motion, decorative art is excluded from the accessibility tree, and route-scoped system-bar styling keeps icon contrast correct after light screens are popped.

## Settings & Navigation

- **Bottom Bar Width** — a new 70–100% slider in Settings → Interface → Bottom Bar scales the navigation bar inward from its usual margins and centers it, while keeping each item at least 44 dp; reset returns to full width.
- **Mini player as its own card** — the mini player now always sits above the frosted navigation bar instead of merging into it, aligns to the standard bar width, and keeps its gradient, border, and shadow in separated and collapsed layouts.

## Interface & Polish

- **Android-native scrolling** — removed the remaining iOS-style bounce overrides from shared bottom sheets, the Menu refresh list, lyrics sync tools, album filters, and the EQ graphs and lists. Android's own glow and stretch behavior is back, with a regression test that keeps iOS bounce physics out.
- **Taglish playlist header** — playlist song count, duration, created/updated dates, and the Lossless label stay English in Taglish; the playlist name and song metadata keep the active locale.

## USB & DSD Audio

- **Hardware volume authority on direct USB** — a verified DAC now owns volume even for PCM playback with bit-perfect off. Hardware and software levels are stored separately, so switching modes cannot reuse a software percentage as a hardware restore target.
- **Pause instead of guessing** — if hardware volume control or readback fails, direct USB playback pauses rather than falling back to software gain. The volume sheet explains the safety pause and keeps the hardware slider available for an explicit retry; Play retries at a low, verified level.
- **Guarded restore and handoff** — volume restores are ignored after route changes, coalesced across concurrent handoffs, and keep safe attenuation until hardware control is verified, including when resuming a prepared engine.
- **Consistent volume curves** — software-volume dB display and ducking now match the Rust engine's gain curve.
- **ISO completion diagnostics** — strict per-packet validation now records a bounded snapshot of packet lengths, transfer slots, and the selected wire format on the first mismatch, without accepting packets more loosely. This is diagnostic groundwork for #354, not a compatibility workaround.

## Network & SMB

- **Atomic SMB downloads** — playback, next-track prefetch, and gapless preparation for the same file share one transfer. Downloads publish only after the native completion event, a consistent byte count, and a matching on-disk length; short, cancelled, and incomplete transfers delete their staging file and stay retryable.
- **Cache safety** — SMB entries move to a new `smb-v2:` key so files left by older builds are bypassed without clearing app data, and staging and `.part` files are excluded from lookup, eviction, and the cache cap.
- **Privacy-safe failures** — SMB errors resolve to allowlisted stage/code pairs and localized copy; hostnames, account names, shares, and paths are never echoed into logs or banners. URL parsing decodes escapes once and rejects embedded credentials, unsupported schemes, query/fragment data, and out-of-range ports; Test Connection probes the configured root.
- **Metadata backfill** — after a download, missing duration, sample rate, and bit depth are read from the cached original through the Rust scanner, with the format probe as fallback. Existing values and local edits are preserved, and failed probes are not retried on every play.

## Builds & Flavors

- **This GitHub download uses the `full` flavor** — it declares **All Files Access** (`MANAGE_EXTERNAL_STORAGE`) for the raw Rust filesystem scanner and complete DSD/WavPack coverage. Build: `flutter build apk --flavor full --release`.
- **Google Play uses the `play` flavor** — no All Files Access (Play policy for media apps); it scans via MediaStore/SAF plus the DSD/DSF/WavPack reconciliation path. Build: `flutter build appbundle --flavor play --release`.
- Both flavors share `applicationId` `com.mossapps.flick`, so either installs over the other.

## Getting Started

1. Onboarding: install fresh, or open Settings → App Info → View Onboarding
2. Bottom bar width: Settings → Interface → Bottom Bar, or long-press the navigation bar
3. Mini player: Settings → Interface → Bottom Bar → Mini Player Layout (the card now sits above the bar)
4. USB volume safety: connect a USB DAC; if volume cannot be confirmed, press Play to retry at a low verified level
5. SMB playback: stream from an existing SMB source; interrupted downloads now retry safely without clearing app data
