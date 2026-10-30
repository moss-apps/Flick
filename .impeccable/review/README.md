# Onboarding render evidence

These are **Flutter widget-render captures, not Android emulator screenshots**.
The Medium_Phone API 36 emulator failed to become ADB-ready after normal and
software-rendered cold boots. No preview was installed on the connected phone.
Android system chrome, actual device font scaling, TalkBack, and live gesture
behavior still need an emulator or device check.

The captures render the actual onboarding widgets with `AppTheme.darkTheme`,
bundled GoogleSansFlex/Noto fonts, 24dp top/bottom safe insets, reduced motion,
and 2x capture resolution. There is no screenshot-only replacement artwork.

| File | Logical window | State |
| --- | --- | --- |
| `phone.png` | 390 × 844 | Welcome, English |
| `phone-library.png` | 390 × 844 | Library, English |
| `phone-browse.png` | 390 × 844 | Browse, English |
| `phone-playback.png` | 390 × 844 | Playback, English |
| `phone-ready.png` | 390 × 844 | Ready, English |
| `phone-zh.png` | 390 × 844 | Welcome, Chinese |
| `phone-tl.png` | 390 × 844 | Welcome, Taglish |
| `tablet.png` | 800 × 1280 | Welcome, English |
| `landscape.png` | 800 × 360 | Playback, English |
| `phone-large-text.png` | 320 × 568 | Welcome, English, 2x text, top |
| `phone-large-text-body.png` | 320 × 568 | Same window, scrolled to body |

The normal full-flavor debug APK also builds successfully from `lib/main.dart`:
`flutter build apk --debug --flavor full --target-platform android-arm64 --no-pub`.
It has not been installed on a device. The earlier isolated preview used a
temporary onboarding-only entry point; it is not the final APK entry point.

Independent review supported the poster direction and requested a whole-word
fix for enlarged headings. That fix is included in these captures and covered
by bundled-font regression tests. All 27 onboarding tests pass and the targeted
analyzer is clean. Native visual/accessibility approval remains **pending**, not
implied by widget-render review or a successful APK build.

The playback capture also includes the follow-up vinyl clipping fix. The full
record now stays inside the artboard throughout its entrance; two graphics
regressions check four artwork sizes with standard and reduced motion.

The full Flutter suite reports 1,078 passing tests and one unrelated load
failure in `test/services/webdav_sync_integration_test.dart`: the host Isar Core
binary is 3.4.1 while the dependency requires 3.3.2. Dependencies were not changed.

Capture harness: `/tmp/opencode/flick_onboarding_capture_test.dart`.
These review PNGs are not app assets.
