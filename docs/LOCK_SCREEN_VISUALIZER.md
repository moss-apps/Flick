# Lock-screen visualizer

## Use

Both modes are opt-in, off by default, and use the same renderer. The phone
stays locked; neither mode exposes the library, settings, or player navigation.

### Explicit screen

1. Use Standard playback or High Quality with a PCM track.
2. Open **Settings → Visualizer → Lock-screen visualizer** and enable it.
   This opt-in is independent of the in-app visualizer.
3. Tap **Open visualizer screen** while Flick is unlocked. Standard playback
   needs the existing microphone permission for Android's Visualizer effect;
   permission must be resolved before the viewer opens.
4. Lock the phone, then wake it. The dedicated Flick screen appears over the
   keyguard without unlocking it. Tap anywhere or use Back to close and reveal
   the real lock screen when locked. TalkBack exposes the current state and a
   Close action without visible chrome.

This is **AOD-style, not Android's low-power system AOD**. A normal third-party
Activity cannot run this live animation inside the system's dozing AOD. It does
not replace the OEM lock screen, open automatically, wake the display, prevent
screen timeout, or animate while the display is off/dozing.

### Simulated AOD (experimental)

This mode is for showcase use and deliberately approximates the moment when an
always-on display would appear. It does **not** use the device's AOD setting and
cannot replace the OEM AOD.

1. Enable **Lock-screen visualizer**, then enable **Simulated AOD
   (experimental)** and allow **Display over other apps** when prompted.
2. Start playback, then lock or let the display time out. While the feature is
   armed, Flick wakes the display and shows the same full-screen visualizer at
   low brightness over the keyguard.
3. Tap anywhere or use Back to close. The normal explicit flow above remains
   available and unchanged.

Important differences from system AOD:

- The display is fully awake, not in the panel's low-power dozing state. Expect
  much higher battery use and possible OLED burn-in during long sessions.
- It stops after 30 minutes or on low battery, and closes when playback pauses
  or stops, the route becomes unsupported, animations are turned off, or the
  feature is disabled.
- It launches only while a supported song is playing, the visualizer source is
  available without prompting, Flick/Android animations are enabled, and overlay
  permission is granted. It never prompts for permission while locked.
- It does not launch over an already-open viewer, and waits about three seconds
  after a manual close before it can launch again on the next screen-off.
- Background Activity starts are restricted by Android and can be blocked or
  delayed by an OEM. The overlay permission is the supported exemption used
  here; there is no overlay-only or fake-wake fallback.
- Turn the toggle off to stop it. Long-pressing power or actually powering the
  device off cannot be overridden by an app.

## Rendering

The native renderer follows `AudioVisualizer` in the immersive player: all six
styles (including its fine square block grid), album-art/rainbow/monochrome
colors, frequency masks, movement preferences and quiet top/bottom fade. The
background stays pure black rather than using album tint. Real capture remains at
its existing rate; `Choreographer` interpolates on display vsync with the player's
70/100/130 ms movement durations and cubic easing, plus elapsed-time block trails.
There is a short fade from black when real frames arrive. On pause, capture stops
immediately and the last spectrum eases/fades back to black, then rendering stops.
No synthetic audio is generated. Hidden or reduced-motion states clear immediately.

## Audio and lifetime

- The native Activity does not create a Flutter engine or audio player.
- `LockScreenVisualizerService` holds one reference to the shared
  `VisualizerSource` only while a viewer is visible, the screen is interactive,
  playback is running, and both Flick and Android allow motion. The simulated
  arming state itself holds no source reference or wake lock.
- Closing, hiding, pausing, or disabling the feature releases that reference. A
  brief native settle animation on pause does not hold a source reference.
- `FlickVisualizerPlugin` owns Android FFT capture at engine scope rather than
  retaining `MainActivity`. Existing in-app and lock-screen consumers share it.
- No PCM tap, resampling, conversion, or alternative routing is added. Direct
  USB, native DAP, and native/DoP DSD paths remain unavailable. Switching to one
  while the viewer is open clears the spectrum to black. The restriction remains
  available to TalkBack and in Visualizer settings, not as visible screen text.
- A missing engine after process death fails closed. Reopen explicitly from
  unlocked Flick; simulated mode also cannot arm without the app process and its
  playback service.

## Local verification

```bash
flutter analyze
flutter test
cd android
./gradlew :app:compileFullDebugKotlin :app:testFullDebugUnitTest \
  -x :app:compileFlutterBuildFullDebug -x :app:copyNdkLibs
```

The Gradle command checks native compilation and JVM tests without rebuilding
the Flutter/Rust artifact or installing anything. It is not a full release
build or proof of device lock-screen behavior.

## Device acceptance checklist (user-run)

Rebuild with `flutter run --release --flavor full`. Check API 26's legacy
show-when-locked flag and API 27+ behavior where devices are available; include
the intended OEM device because keyguard/task behavior varies.

- Start from the default-off setting. Enabling alone must not open a screen.
- Open with High Quality PCM, lock, and wake. Only the visualizer should appear
  on true black, with no text or controls. Compare all six styles, colors,
  frequency masks and movement to immersive full-view, especially the block grid.
  Check smoothness at the device's supported refresh rates; capture must not
  make movement jump at 30 Hz. Repeat with Standard, including first grant and denial of
  microphone permission. Denial must not leave a loading spinner or open UI.
- Verify secure keyguard remains engaged. Tap-to-close, Back, Home, notification shade,
  and a normal Flick notification tap must not expose library/settings while
  locked. Unlocking must still use the system credential/biometric flow.
- Pause/resume from the notification and headset. Verify a smooth fade to/from
  black, no visible controls, no duplicate playback, clicks, route changes, or
  altered DAC format. Tapping the view must close it, not toggle playback.
- Turn off Flick animations and Android animator duration scale. Bars must
  clear immediately without a fade; tap/Back and TalkBack Close must still work.
- For simulated AOD, first deny **Display over other apps** and confirm the
  toggle does not stay enabled. Grant it, play a supported PCM track, lock the
  screen, and confirm the display wakes at low brightness with the visualizer
  over the secure keyguard. Repeat after closing manually, pausing/stopping
  playback, changing to an unsupported route, disabling animations, and letting
  the 30-minute cap or low-battery stop run. Confirm it does not launch without
  overlay permission, over an open viewer, or after process death. Check that
  normal screen timeout/keep-awake behavior returns after close; simulated mode
  intentionally disables timeout only while its viewer is visible.
- Let the screen time out in explicit mode; lock/wake repeatedly and leave/reopen
  the viewer. Capture must stop while hidden/off and resume only when eligible.
  Explicit mode must not wake the display, hold it on, animate in system AOD, or
  relaunch in the background.
- Switch to Direct USB, native DAP, and DSD where supported. Verify the
  black screen, accessible unavailable explanation, and unchanged native audio output.
- Exercise rotation, display sizes, TalkBack, tablet/landscape, calls, process
  recreation, and feature disable/reopen. The spectrum should fill the view
  without tablet-width caps; a lost engine must return to the keyguard safely.

Device/hardware acceptance is pending until these checks are performed. Local
unit/widget tests cannot confirm OEM keyguard behavior, simulated-AOD launch
policy, burn-in, battery use, or DAC output integrity.
