# Releasing Flick

Two distribution channels, two flavors. Both use the same `applicationId`
(`com.mossapps.flick`), so they are install-compatible; only the manifest
differs.

## Google Play

```bash
flutter build appbundle --flavor play --release
```

- Output: `build/app/outputs/bundle/playRelease/app-play-release.aab`
- Upload the bundle and bump the version code (current: `0.23.0-beta.2+31`).
- The `play` flavor does **not** declare `MANAGE_EXTERNAL_STORAGE`. The
  All Files Access declaration no longer applies to this build — **do not
  resubmit it**. It was rejected twice (see
  [`DSD_SCAN_ALL_FILES_PLAN.md`](DSD_SCAN_ALL_FILES_PLAN.md)); retrying
  risks escalating enforcement.
- Play builds silently use the scoped MediaStore/SAF scan path. The Full
  Library Access row is hidden at runtime by `isAllFilesAccessSupported()`.

## GitHub Releases

```bash
flutter build apk --flavor full --release
```

- Output: `build/app/outputs/apk/full/release/app-full-release.apk`
- The `full` flavor declares `MANAGE_EXTERNAL_STORAGE` and keeps the Rust
  direct-walk scanner for complete DSD/WavPack coverage
  (`android/app/src/full/AndroidManifest.xml`).
- Attach the APK to the GitHub release.

## Checks before publishing

```bash
flutter analyze
flutter test
```

Both flavors ship from CI/one machine with `ANDROID_NDK_HOME` set — see
[`ANDROID_NDK_SETUP.md`](ANDROID_NDK_SETUP.md).
