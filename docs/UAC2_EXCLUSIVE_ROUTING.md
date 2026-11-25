# UAC2 exclusive routing (follow-up to #400)

Status: implementation in progress on `feat/uac2-exclusive-routing`.

## Problem

#400 makes direct USB playback work on the iBasso DC4U, but only after this
device setting is applied manually:

```sh
adb shell settings put secure usb_audio_automatic_routing_disabled 1
```

Without it, Android's platform USB-audio path keeps `snd-usb-audio` bound to
the DAC's AudioControl and AudioStreaming interfaces. Flick's libusb claim on
the AudioControl interface fails with `Resource busy`, every clock request
(`GET_RANGE`, `GET_CUR`, `SET_CUR`) returns `Input/Output Error`, and the
engine refuses to stream because the rate cannot be verified.

UAPP works on the same phone without that setting, so the app must be able to
take the interfaces itself.

## Approach

1. **Force-claim only the AudioControl interface through Android's API.** In
   `activateDirectUsb`, after `UsbManager.openDevice`, claim interface 1 with
   `UsbDeviceConnection.claimInterface(usbInterface, force = true)`. This is
   the `USBDEVFS_DISCONNECT_CLAIM` path: it detaches the kernel driver and
   claims the interface in one step.

   The AudioStreaming interface is deliberately left to libusb. Claiming it
   through Java makes libusb's `set_alt_setting` fail with
   `Entity not found (ENOENT)` and the engine never starts. This was measured
   on the DC4U: Java claim of interfaces {1,2} produced
   `Failed to reset USB interface 2 to alt 0 before negotiation: Entity not
   found`; Java claim of {1} plus libusb claim of {2} streamed immediately.
2. **Tell Rust the interfaces are already claimed.** usbfs tracks claims per
   device, not per file descriptor, so a second `libusb_claim_interface` on the
   same fd returns `EBUSY`. Pass `preClaimed` at device registration and have
   `ensure_interface_claimed` record the interface without issuing the ioctl.
3. **Fallback, not silence.** If the force-claim is refused, log the exact
   interface and error and return a clear activation failure. The UI prompt
   ("Disable USB audio routing" with a shortcut to Developer options) is the
   remaining fallback for devices where Android refuses the claim.
4. **Release stays correct.** Teardown keeps setting alt 0; Java releases the
   claims when `UsbDeviceConnection.close()` runs. Rust must not rely on its
   own release for pre-claimed interfaces.

## Test plan

1. Set `usb_audio_automatic_routing_disabled` back to `0`.
2. Unplug/replug the DC4U.
3. Confirm `snd-usb-audio` is bound to `1-1:1.1` and `1-1:1.2` before launch.
4. Play the 24-bit/44.1 kHz track.
5. Expect in `RustUSB`:

```text
[USB] SET_CUR verified: 44100 Hz on clock 1 interface 1
[USB] Streaming started ... strategy=usb_direct
[USB] USB stream stabilized after 64 transfers
[USB] ... timeouts=0 errors=0
```

6. Audio Signal Path must read `Strategy: USB direct`, `Passthrough: Allowed`,
   `USB: Interface claimed · Stream stable`, with `Bit-perfect verified`.
7. Repeat on 48 kHz and 24/96 to confirm the clock is reprogrammed per track.

If step 3 cannot be reproduced (driver already unbound), disable routing,
replug, and re-enable routing before launching to force the conflict.
