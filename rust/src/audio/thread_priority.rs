//! Best-effort realtime scheduling for audio-driving threads.
//!
//! The render loops (USB direct, DSD offload) block on the HAL/ioctl most of
//! the time, so a FIFO slot is safe and keeps their write cadence honest.
//! Producer threads that do blocking file I/O only get a nice bump: a
//! CPU-bound decoder must never hold a FIFO slot against the render loop.

/// Raise the current thread to render priority: `SCHED_FIFO` (prio 2) with a
/// nice -16 fallback when the scheduler policy is denied. No-op off Android.
/// Returns the `sched_setscheduler` error (the nice fallback still applied).
#[cfg(target_os = "android")]
pub fn raise_audio_render_priority() -> Result<(), std::io::Error> {
    let param = libc::sched_param { sched_priority: 2 };
    unsafe {
        let result = libc::sched_setscheduler(0, libc::SCHED_FIFO, &param);
        if result != 0 {
            let err = std::io::Error::last_os_error();
            crate::dev_eprintln!(
                "[AudioSched] SCHED_FIFO failed (errno={}): {}",
                err.raw_os_error().unwrap_or(-1),
                err
            );
            libc::setpriority(libc::PRIO_PROCESS, 0, -16);
            crate::dev_eprintln!("[AudioSched] set nice=-16");
            return Err(err);
        }
    }
    crate::dev_eprintln!("[AudioSched] SCHED_FIFO priority=2 acquired");
    Ok(())
}

/// Producer-side priority: nice -16 only. No-op off Android.
#[cfg(target_os = "android")]
pub fn raise_audio_decode_priority() {
    unsafe {
        libc::setpriority(libc::PRIO_PROCESS, 0, -16);
    }
}

#[cfg(not(target_os = "android"))]
pub fn raise_audio_render_priority() -> Result<(), std::io::Error> {
    Ok(())
}

#[cfg(not(target_os = "android"))]
pub fn raise_audio_decode_priority() {}
