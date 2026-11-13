# AutoEq catalog maintenance

Flick already bundles 466 offline parametric presets. This correctness milestone
does not replace that legacy catalog: its exact upstream revision and targets
were not recorded and must not be invented retroactively.

## Reproducible import

The generator follows AutoEq's **recommended results**, not an arbitrary recursive
GitHub tree or Flick-maintained preference ranking. `tool/autoeq_catalog.lock.json`
pins a full commit and SHA-256 checksums for the recommended index, manufacturer
table and MIT license. Nothing contacts upstream during ordinary offline use.
The online button is an explicit request. It reads the index, manufacturer table
and preset from the same pinned raw GitHub revision without using the GitHub API
quota, and it does not guess a similar headphone variant. The runtime revision
constant must be updated together with the generator lock.

Stage a full candidate import (no new packages needed):

```sh
dart run tool/gen_autoeq_catalog.dart --output=/tmp/opencode/autoeq-staged --baseline=assets/autoeq/autoeq_catalog.json
```

For a small smoke test, use a separate directory and `--limit=10`. Reports mark
partial catalogs. Successful downloads are cached in `.dart_tool/autoeq_cache`,
keyed by commit and path; `--cache=<directory>` changes that location. Remove
that specific cache directory if a download is corrupted. The three locked
inputs are checksum-verified, and every imported preset records its input hash.
Network errors abort rather than masquerade as missing headphones. A missing
parametric file (HTTP 404) is a reported upstream omission, not a reason to pick
another measurement. Unsupported profiles are also reported; no catalog is
written unless all selected profiles are supported or an operator explicitly
uses `--allow-exclusions` after review. An empty catalog is never written.

At the pinned revision, 6,032 of 6,033 recommendations validate across 659 brands.
The remaining link, Samsung Galaxy Buds2 Pro (passive mode), points to a missing
directory. A full import therefore stops with a report by default. These are
candidate presets, not an expanded shipping bundle or a redistribution clearance.

Repeat with the same options and `--check` to verify byte-identical output.
There are no timestamps, random IDs or rounded filter values in generated data.
To update upstream, deliberately change the commit **and** locked checksums,
then review the generated report. Do not set a moving branch in the lock.

Outputs:

- `autoeq_catalog.json`, `autoeq_brands.json`: compact runtime data.
- `autoeq_manifest.json`: revision, input checksums, output checksums and sizes.
- `autoeq_report.json`: counts, sources, exclusions and optional baseline changes.
- `AUTOEQ-LICENSE.txt`, `NOTICE.txt`: upstream license and attribution.

Each preset preserves its exact upstream name/variant, source, rig (if supplied),
path, revision, input hash, preamp and filter settings. IDs are hashes of the exact
upstream path, so punctuation and source variants do not collide. A target is
**unknown** (`tg: null`) unless explicitly verified; category alone does not prove
a target curve version. The catalog reader still accepts legacy entries without
these optional provenance fields.

## Review before bundling

The root AutoEq repository is MIT licensed. That does **not** establish blanket
redistribution rights for all third-party measurement databases or targets.
Review source-specific terms and retain attribution before promoting staged
presets. This generator exports numeric PEQ settings only: no raw measurements,
plots, target datasets, Python runtime or impulse responses. Generation is not
legal clearance. The staging-only CLI deliberately refuses `assets/autoeq` as
its output directory.

After review, promote the catalog and brands together, include the manifest and
notices in `pubspec.yaml` and the app's license information, and rerun catalog
tests. Inspect baseline changes rather than silently relabeling existing models.
Saved EQ state and custom presets contain full settings, not live catalog links;
updating the bundle must not rewrite them.

## Fidelity and verification

Catalog/online imports are strict: required preamp, supported PK/LS/HS filters,
finite values, 20–20,000 Hz, ±20 dB gain, Q 0.1–20, ±24 dB preamp, at most 31 bands.
Unknown filter types and unsupported values are rejected, never substituted or
clamped. Manual TXT/JSON imports report supported-range adjustments and reject
unsupported types/counts. The graph, editor/imports and Rust use the same Q floor;
valid AutoEq Q 0.18/0.19 filters no longer become Q 0.2.

Correction is DSP, **not bit-perfect**. Existing processing locks remain in place;
this work does not change audio routing, resample audio, or convert native DSD or
DoP to PCM to enable EQ. Android fixed-band mapping remains approximate. UI work
to distinguish selected/processing/bypassed correction and expose that fallback
is a later milestone, alongside the expanded reviewed catalog.

Run `flutter analyze`, `flutter test` and
`cargo test --lib --manifest-path rust/Cargo.toml` locally. Automated response tests
are not DAC/listening verification. The user handles rebuilding, installation and
hardware checks with `flutter run --release --flavor full`.
