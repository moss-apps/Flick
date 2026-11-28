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
- PCM can continue after a bounded shortfall or timeout, but the first one
  clears stream stability and bit-perfect verification until a new stream.
  Native DSD and DoP still require exact completions and stop on a timeout.
  See [USB completion diagnostics](USB_ISO_COMPLETION_DIAGNOSTICS.md).
- PCM at a 125 µs service interval uses 16 packets per transfer and eight
  slots (16 ms queued) instead of 32 packets and
  eight slots (32 ms). It requires 128 successful transfers, preserving
  the original 256 ms nominal window before marking the stream stable.
  Other intervals, native DSD and DoP keep their original geometry.
  The shorter queue addressed stalls on a OnePlus 15 with an iBasso DC04U.
  On that setup, the author also measured lower CPU use with 16 × 8 than
  with 8 × 16 at 44.1 kHz. This does not establish a host-controller limit.

## Playback controls

For short pauses, Flick keeps the USB stream and DAC clock running with
format-correct silence.
Already submitted USB transfers finish, but Flick holds the rest of the buffer
for resume. Buffered PCM uses the current software volume when sent to the DAC,
including a volume change made while paused. Seek discards audio from the old
position and sends silence until the new decoder can supply audio. Intentional
silence does not count as an underrun, and transport errors still count.

After 30 seconds of continuous pause, Flick drains the transfers and stops the
stream while keeping the DAC claimed. The DAC can lose its clock lock during
this time. The song and position are retained, and seeking while paused only
updates the position. DAC volume controls are unavailable while the stream is
closed. On Play, Flick reopens the same DAC and checks the previous output
format and hardware level before starting the decoder at the saved position.
This check does not write gain or mute to the DAC. If the route or volume
cannot be verified, playback stays paused.

## Hardware volume

Live volume, mute and periodic level reads run on a separate worker using the
claimed USB connection. The synchronous usbfs control transfers do not reap
libusb streaming completions or run on the audio submission thread. The worker
checks the DAC and active Feature Unit generation before starting a request.
Release waits for an in-flight control operation before returning the interfaces
to Android.

Flick checks the DAC's readback before accepting a new level or mute setting.
If verification fails, it attempts to restore the previous setting on that
connection and reports the error. A failed direct USB write does not turn into
an Android volume change. Before a new stream starts, any remembered hardware
level is still restored and verified before the first audio is sent.

## Reconnect

Automatic resume requires the same track, enabled USB auto-engage and
bit-perfect playback, and the same DAC identified by vendor, product and a
real USB serial number. A changed USB address is allowed. If Android has
not exposed the serial yet, permission can be requested for a single plausible
device, but playback stays paused unless its serial matches. DACs without a
verifiable serial require a manual Play after reconnecting.

The app verifies the DAC's volume and direct route before starting audio.
If the DAC or its claim changes during startup, or direct playback fails,
the reconnect attempt does not start Android output. A manual pause and
**Pause on USB DAC connect** both cancel the pending resume. On a confirmed
unplug, Android continuation remains possible only when **Pause on USB DAC
disconnect** is disabled and no DAC is present.

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
3. Play 48 and 96 kHz PCM, a 16-bit track, and a higher rate such as 192 or
   384 kHz if the DAC supports it. Check quick and long pauses, then seek while
   playing and while paused. Listen for old audio after the seek and confirm
   the DAC stays locked during a short pause. Leave a track paused for over
   30 seconds, check that the stream is closed, then seek without waking it.
   Play and listen for the first audio at the new position at the same level.
   With PCM software volume, lower it during a short pause and
   check the first audio after resume. If the DAC supports hardware volume,
   adjust it at a safe level during playback. Check the displayed readback,
   try hardware mute if supported, and listen for interruptions. Repeat after
   pausing and after reconnecting the DAC.
   On a compatible DAC, repeat pause and seek with native DSD and DoP.
   With pause-on-connect off, unplug during playback and reconnect
   the same DAC. Check that playback continues once at the retained position
   after the safe level is restored. Repeat after a manual pause, with
   pause-on-connect on, and using a different DAC. None should resume.
4. Pause and select Standard, then play again and verify Android can route to
   the DAC. Also test selecting direct USB during Android-managed playback:
   ownership should transfer on the next playback request, not interrupt the
   ongoing track as soon as the preference changes.
5. Export Flick's logs if anything fails. Include the Android device/version,
   DAC, source format, and whether automatic USB audio routing was enabled.
   For 125 µs PCM, the `Isochronous queue` line should show
   `packetsPerTransfer=16 slots=8 stableTransfers=128`.
   After a recoverable PCM interruption, playback can continue on the DAC.
   Confirm the interruption was logged and the verified badge stays off
   until a new stream starts. Check that disconnect and reconnect still follow
   the configured preferences.

Build from the project root with `flutter run --release --flavor full`.
