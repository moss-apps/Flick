# AGENTS.md

Flick is an Android music player with a Rust audio engine: bit-perfect PCM and native DSD to USB DACs (UAC 2.0), DAP hi-res via Oboe/AAudio exclusive mode, and a full DSP chain (31-band PEQ, dynamics, convolution reverb, crossfade, gapless). Flutter/Riverpod + Isar frontend; Rust backend (Symphonia, rusb, cpal/Oboe, lofty) bridged with `flutter_rust_bridge`. Android-only, minSdk 26.

## Docs

| Doc | Contents |
|---|---|
| `docs/RELEASING.md` | Build flavors, signing, release process |
| `docs/UAC2_IMPLEMENTATION_CHECKLIST.md` | USB audio work and constraints |
| `docs/DSD_ARCHITECTURE.md` | DSD paths (DSF/DFF/WavPack, DoP) |
| `docs/LIBRARY_SCAN_ARCHITECTURE.md` | MediaStore/SAF scanner design |
| `CONTRIBUTING.md` | Scope, invariants, PR rules |

## Commands

```
flutter analyze
flutter test
cargo test --lib --manifest-path rust/Cargo.toml
flutter run --flavor full
```

## Installation and hardware tests

- The user handles app installation and hardware testing. Do not install, launch, restart, or drive tests on a connected device unless explicitly requested.
- Run local automated checks yourself. Tell the user when a rebuild is needed with `flutter run --release --flavor full`, and distinguish local verification from user-confirmed hardware results.

## Invariants (do not violate)

- **Bit-perfect / native format output is the goal.** Never silently resample or truncate; do not route everything through one container for convenience.
- **Android only, minSdk 26.** No desktop or iOS paths.
- **No ads, tracking, or premium tier.** Nothing phones home or gates features.
- **No new dependencies without a reason** — stdlib or an existing dep first.
- Match the style of files you touch; no unrelated reformatting in the same diff.
- Test audio-path changes on real hardware when possible; say so if not.
- Never commit signing material, secrets, or machine-local files (`key.properties`, keystores, `graphify-out/`).

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

When the user types `/graphify`, invoke the `skill` tool with `skill: "graphify"` before doing anything else.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
