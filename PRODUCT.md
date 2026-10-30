# Flick

<!-- impeccable:product-schema 1 -->

## Platform

android

## Product Purpose

An Android music player for a listener's local library, with a Rust audio engine,
USB DAC output, DSP, and listening recaps called Flick Replay.

## Capabilities and Constraints

- Android only, minSdk 26; Flutter/Riverpod frontend and Rust audio backend.
- Preserve native formats and bit-perfect output; never silently resample.
- No ads, tracking, premium tier, or gated features.
- Existing English, Simplified Chinese, and Taglish localization must survive UI changes.
- First-run screens must not assume an existing library or listening history.

## Brand Commitments

- Preserve Flick's recognizable dotted logo and bundled Google Sans Flex family.
- The onboarding redesign takes its visual language from Flick Replay and the
  user's utilitarian, motorsport-inspired poster references, not generic cyberpunk.
- This request changes onboarding, not the music player's wider interface or audio paths.

## Evidence on Hand

- Product capabilities and development constraints: `README.md`, `AGENTS.md`.
- Replay identity: `lib/features/recap/widgets/replay_style.dart` and
  `assets/recap/`.
- Official dotted mark: `assets/icons/flicklogo_svg.svg`.
- Existing onboarding content and translations: `lib/l10n/app_{en,zh,tl}.arb`.

## Product Principles

- A listener's music and control come first.
- Distinctive graphics must not obscure familiar navigation.
- Keep first-run guidance optional and preserve the existing tutorial handoff.
