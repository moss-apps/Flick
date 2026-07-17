# Contributing to Flick

Contributions are welcome. Bug fixes, hardware compatibility improvements, DSP work, and docs all count.

## Before you write code

1. **Always `git pull` on `main` before starting** — catches merge conflicts early instead of at PR time.
2. Check open issues and PRs first. If your thing isn't listed, open an issue describing the change so we can talk it through before you sink time into it. This is especially true for anything that touches the audio path or DAC output formats — those are opinionated by design.

## What this project cares about

- **Bit-perfect and native format output are the goal.** Routing everything through a single container format for convenience is a no. If a fix makes output sound the same but is simpler, that's fine; if it silently resamples or truncates, it isn't.
- **Android-only, minSdk 26.** Don't add desktop/iOS paths.
- **No new dependencies without a reason.** Symphonia, rusb, cpal/Oboe, lofty, Riverpod, just_audio, Isar are already in. If stdlib or an existing dep can do it, use that.
- **No ads, no tracking, no premium tier.** Don't add anything that phones home or gates features.
- **MIT.** Your contribution lands under the same license.

## Code

- Frontend is Flutter (Riverpod). Backend is Rust, bridged via `flutter_rust_bridge`.
- Match the style of the files you're touching. Don't reformat unrelated code in the same diff.
- Build before opening a PR:
  ```bash
  flutter pub get
  cd rust && cargo fetch && cd ..
  flutter run
  ```
  Or `flutter build apk --release` if you want to confirm a release build still passes.
- If you touch the Rust audio engine, test on real hardware if you can. A USB DAC behaves differently from the emulator's virtual device.

## PRs

- One change per PR. Mixed refactors + features get bounced.
- Write the PR description like a changelog entry: what changed, why, how you tested it. Screenshots if UI.
- Keep diffs small. If a change needs 1000 lines, split it.

## Hardware notes

If you're working on DAC output, note that some DACs only do `S24_3LE`, not `S24_LE`, and cpal maps `i24` to `S24_LE`. That's a known constraint — handle it deliberately, don't paper over it with a 32-bit container unless the project's audio path already decided to.

## Branch policy

Work off `main`. Fork, push to your fork, open a PR against `main`. Rebase before you open if `main` has moved.