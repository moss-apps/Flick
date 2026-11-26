# USB reconnect investigation — 2026-11-25

## Evidence and diagnosis

Input: `flick_logs_2026-11-25T12-51-04.txt` from the Desktop.

- At 12:49:55.030, native playback reports verified 16-bit/44.1 kHz USB
  output. At 12:49:55.942, the next toggle still sees `isPlaying=false` and
  executes resume. The playback indicator was inconsistent with the engine.
- At 12:50:05.262, feedback resubmission fails with libusb error `-4`.
  The data submission fails immediately afterward. This establishes loss of
  the USB device through that handle; it does not establish who caused it.
- At 12:50:05.281, Flick sees one enumerated DAC and labels the failure a
  transient suspension. That enumeration can use the native device cache.
  At 12:50:05.284, enumeration returns zero devices; it stays empty through
  12:50:06.142. The earlier result does not prove the DAC stayed attached.
- Fallback explicitly starts Android playback at 12:50:05.659, despite a
  pause request at 12:50:05.293. The early classification overrode the
  pause-on-disconnect preference.
- At 12:50:17.391 the DAC appears again. At 12:50:18.146 foreground recovery
  requests resume, followed by another resume at 12:50:18.231. Attach recovery
  and foreground recovery were allowed to overlap.

The selected engine can already be USB while the initialized engine is still
Android. The previous handoff condition inspected selection and therefore
skipped moving a playing Android stream to USB.

`LIBUSB_ERROR_NO_DEVICE` must not be treated as a harmless feedback-only loss.
Keeping the Java connection object open does not establish that its device
handle can survive a disconnect. See the [libusb device handling reference](https://libusb.sourceforge.io/api-1.0/group__libusb__dev.html).
This evidence does not justify requiring an Android USB routing setting.

## Implementation

- Update the play indicator from active/paused/stopped native states. Do not
  treat a transient native idle notification alone as a user pause.
- Queue the entire attach handoff with play, pause, foreground recovery, and
  USB runtime recovery. Coalesce duplicate attach/permission notifications.
  Avoid waiting inside the playback queue for work that needs that same queue.
- Compare the initialized engine when deciding whether playback needs moving.
  Resume the current track once, preserving position and the DAC volume guard.
- Retain resume intent across a detach that follows the transport error.
  Cancel it on a manual pause. Apply pause-on-connect before activation.
- Invalidate obsolete attach work when detach occurs, including while awaiting
  permission. Recheck queued foreground work before resuming.
- Force a fresh device enumeration during recovery. Close the previous native
  connection, then reopen/reclaim and rebuild once if the DAC is still present.
  If it is absent or recovery fails, retain the existing fallback path and honor
  pause-on-disconnect. Do not retry data through the disconnected descriptor.
- Require native registration for a claimed-DAC status. Accept that claim when
  Android's shared audio route no longer advertises USB after exclusive claim.

## Local validation

The USB handoff checks pass, including current-position resume, native play
indicator updates, fresh-connection recovery, absence without a reopen attempt,
manual-pause cancellation, pause-on-connect, duplicate attach, and detach during
permission. Existing volume safety checks also pass. The older volume-widget
checks now invoke PlayerService activation, matching the existing ownership
decision; the prompt no longer activates USB.

The complete Flutter suite was run. The affected USB file passes on recheck.
The unrelated `AnimatedArtworkService.refreshAlbumArtwork drops a negative entry
so a later lookup re-queries` test still fails. The full run also failed
`resolveArtist reads a cached artist from disk on a fresh cache`; that metadata
test passed on recheck. These failures are not reported as a green full suite.

`flutter analyze` reports 28 informational notices outside the changed code,
with no errors or warnings. `git diff --check` passes.

Rust library tests passed except four scanner tests whose expected `/var` paths
did not match canonical `/private/var` paths. All four passed when rerun with
`TMPDIR=/private/tmp`; no Rust source was changed. The failed tests were:

- `library_scan::tests::two_phase_scan_async_applies_batch_updates`
- `library_scan::tests::two_phase_scan_classifies_all_file_states`
- `library_scan::tests::two_phase_scan_skips_nomedia_subtrees`
- `library_scan::tests::hybrid_scanner_bootstraps_and_reacts_to_live_changes`

The graph was updated with `graphify update .` (AST only).

## Phone build and installation

Built the `full` flavor in release mode for ARM64. WavPack bindgen needed the
installed Android NDK sysroot passed explicitly. The checkout had no release
keystore configuration; the phone's existing installation was signed by the
local Android debug certificate. The release-mode APK uses that same certificate
for the data-preserving update. The temporary ignored signing configuration was
removed after the build.

Artifact: `build/usb-recovery-20261125/flick-usb-reconnect-arm64.apk`.
SHA-256: `ed83004feb7f4a0a565979c721c0367a313c9bc20f35b04d341fe3f1b4fe79c8`.
`adb install -r` returned `Success` on the CPH2747. Installation and hardware
acceptance are separate results.

## Hardware acceptance procedure

1. Play a track through the supported DAC and confirm the button shows pause.
2. Unplug while playing. With pause-on-disconnect enabled, playback must pause
   without continuing through the phone. With it disabled, Android fallback is
   allowed.
3. Reconnect and grant permission if asked. With pause-on-connect disabled,
   playback must return to direct USB at the retained position without a press.
4. Pause once, then play once. Confirm that one press performs each action.
5. Pause manually while disconnected, then reconnect. Playback must stay paused.

If any step fails, export the new Flick log and identify the failed step. The
remaining transport cause can then be checked against fresh enumeration and
the explicit connection-recovery message.

## CPH2747 and DC04U follow-up

In `flick_logs_2026-11-25T13-11-40.txt`, the release build saw zero DACs
after `-4` at 13:10:54 and entered paused fallback. After replug, the app
requested automatic resume at 13:11:07.735 and negotiated 24-bit/44.1 kHz.
At 13:11:08.029, the volume safety state changed during initialization and
the handoff stopped before loading playable audio. The first manual Play
then verified USB PCM before the flow became silent. The log records no new
`-4` at that point. The second manual Play restored verified audio.

The volume restore now takes its safety snapshot after refreshing the route.
This lets it join a safety pause raised by newly discovered DAC controls.
If the safety state changes again during startup, initialization can verify
volume once more on the same connection after the transport pauses. It still
refuses playback on failed pause, stop, or volume verification. Deferred
volume callbacks read the current tier after waiting for the output guard.
The regression test publishes hardware volume during the route refresh and
checks that the same request pauses and verifies hardware volume.

On the next phone run, the replug at 13:17:03 reached `Playback play()`.
The volume guard then reported loss of DAC authority and the USB payload
went silent. One manual press restored sustained direct output. The route
status now retains the device identity reported by USB registration rather
than adopting AudioManager's description of its shared output. The volume
guard accepts display name changes only when the USB device path, vendor,
product and serial agree. A different device or missing hardware controls
still holds playback.

The user confirmed the fix on the CPH2747 with the DC04U. The final build's
installed APK matched SHA-256
`3a20685ccd7dc00876933035cfc77e5518a8386e62da9c8d6f0404d7ea50e9d2`.
On unplug at 13:20:12, libusb reported `-4` and Flick entered paused fallback.
Replug activated the DAC at 13:20:23.985. Flick requested resume seven
milliseconds later and started the track after verifying hardware volume.
The log recorded verified 24-bit/44.1 kHz direct output, no Play toggle, and
continued direct playback through 13:20:48.498. The captured records are
`phone-dac-identity-acceptance.log` and `phone-dac-identity-sustain.log` in
`build/usb-recovery-20261125/`.
