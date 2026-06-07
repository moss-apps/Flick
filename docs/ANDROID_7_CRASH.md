# Android 7/7.1 (API 24/25) Compatibility

## Symptom

App crashes immediately on Android 7.0 (API 24) and 7.1 (API 25) devices.

## Root Causes

The app's Gradle build targets Java 17 (`sourceCompatibility` /
`targetCompatibility = VERSION_17`). Android 7.x lacks native support for some
Java 8+ library APIs (`java.time`, `java.util.stream`, `java.util.function`,
etc.), so core library desugaring must remain enabled while `minSdk` includes
API 24/25.

Isar can also fail at startup with:

```text
IsarError: Cannot open Environment: MdbxError (-30784): MDBX_INCOMPATIBLE
```

This can happen when an existing `libmdbx` environment was created by an
incompatible native library/flag combination. Isar stores the database as
`<documents>/flick_player.isar` with a lock file at
`<documents>/flick_player.isar.lock`.

Additionally, Impeller is controlled through
`io.flutter.embedding.android.EnableImpeller`. Older Android 7 GPU drivers can
have compatibility issues with Impeller's rendering pipeline, so the base
resource disables it and `values-v26` enables it again for Android 8+.

## Fix

Keep Android 7 installable with `minSdk = 24`, but apply these compatibility
guards:

- Enable core library desugaring in `android/app/build.gradle.kts`.
- Use `isar_community`, `isar_community_flutter_libs`, and
  `isar_community_generator` `3.3.2`.
- On `MDBX_INCOMPATIBLE`, delete both `flick_player.isar` and
  `flick_player.isar.lock`, then reopen Isar so the app can recreate the local
  library database.
- Keep Impeller disabled for API 24/25 through `values/bools.xml` and enabled
  for API 26+ through `values-v26/bools.xml`.

### Key Changes

`android/app/build.gradle.kts`:

```kotlin
compileOptions {
    isCoreLibraryDesugaringEnabled = true
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

defaultConfig {
    minSdk = 24
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
```

`lib/data/database.dart`:

```dart
// On MDBX_INCOMPATIBLE, remove:
// <documents>/flick_player.isar
// <documents>/flick_player.isar.lock
// Then reopen Isar with the same schema.
```

## Impact

- Android 7.0/7.1 devices remain installable.
- If an incompatible Isar environment exists, the local library database is
  recreated. Users may need to rescan their music folders.
- Android 8.0+ devices keep Impeller enabled.
