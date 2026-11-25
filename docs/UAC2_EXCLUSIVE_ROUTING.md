# Android exclusive USB routing

Flick can request the DAC for direct USB playback without asking the user to
disable Android's automatic USB audio routing system-wide. Enumeration and
saved preferences alone do not take ownership of the DAC.

## Ownership and fallback

- After the user grants USB permission, Android's `UsbDeviceConnection` claims
  the AudioControl and isochronous playback interfaces in the active
  configuration with `force = true`. Capture-only and MIDI streaming
  interfaces are not claimed. A failed claim or registration rolls back the
  interfaces already acquired.
- Rust verifies the exact interface IDs and uses a duplicate of that connection
  for clock controls and transfers. It sets streaming alternates with the
  usbfs `USBDEVFS_SETINTERFACE` ioctl: libusb's alternate-setting helper would
  reject an interface claimed by Android rather than by that libusb handle.
  Hardware volume and mute use synchronous usbfs controls so they do not
  consume completions from the streaming context.
- On exit from direct USB, Rust stops and drains the transfers before Android
  resets the streaming alternate and explicitly releases the interfaces.
  `releaseInterface` lets Android try to rebind its driver; simply closing a
  descriptor is not a substitute. If a device refuses the initial claim, retry
  after reconnecting, or test with **Disable USB audio routing** enabled in
  Developer options as a fallback.
- The strict isochronous completion checks, timeout handling and queue depth
  are unchanged. See [USB completion diagnostics](USB_ISO_COMPLETION_DIAGNOSTICS.md).

## Hardware test

1. In Android Developer options, leave **Disable USB audio routing** **off**.
   Unplug and reconnect the DAC. With Flick set to Standard and USB auto-engage
   disabled, confirm Android can use the DAC and that launching Flick does not
   take it away.
2. Select **Isochronous USB**, enable **Bit-perfect (USB DAC)**, and grant USB
   permission. Start with a local 24-bit/44.1 kHz FLAC on the iBasso DC4U. In
   Audio Signal Path, confirm **USB direct**, a stable stream, the expected
   source and output format, and **Bit-perfect verified**. Check that output
   is audible and the DAC reports the expected rate. Note any clock refusal,
   unexpected fallback, packet-length mismatch, or timeout.
3. Play 48 and 96 kHz PCM and a 16-bit track; pause, resume, and seek. If the
   DAC supports hardware volume, change it at a safe level during playback
   and listen for interruptions. On a compatible DAC, repeat with native DSD
   and DoP. Unplug/replug and play again. An attach must not restart a track
   you paused.
4. Pause and select Standard, then play again and verify Android can route to
   the DAC. Also test selecting direct USB during Android-managed playback:
   ownership should transfer on the next playback request, not interrupt the
   ongoing track as soon as the preference changes.
5. Export Flick's logs if anything fails. Include the Android device/version,
   DAC, source format, and whether automatic USB audio routing was enabled.

Build from the project root with `flutter run --release --flavor full`.
