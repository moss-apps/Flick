//! Direct ALSA DSD output via raw kernel ioctls on /dev/snd/pcmC*D*p.
//! No tinyalsa, no dlopen, no AudioTrack. Talks straight to the kernel ALSA
//! driver using the SNDRV_PCM ioctl interface from <sound/asound.h>.
//!
//! This bypasses AudioFlinger entirely — the approach used by pro players
//! (UAPP, Neutron) on DAPs whose HAL doesn't expose ENCODING_DSD.

#[cfg(target_os = "android")]
mod internal {
    use std::ffi::CString;
    use std::sync::atomic::{AtomicBool, AtomicI32, Ordering};

    // ── ALSA UAPI ioctl numbers (arm64) ───────────────────────────────────
    // Computed via _IOC(dir, type, nr, size).  See <asm-generic/ioctl.h>,
    // <sound/asound.h>.
    //
    // _IOC(dir, type, nr, size) = (dir << 30) | (size << 16) | (type << 8) | nr
    //   dir: NONE=0, WRITE=1, READ=2, RW=3
    //   type: 'A' = 0x41

    const IOC_HW_REFINE: i32 = 0xC158_4110_u32 as i32; // _IOWR('A',0x10, hw_params=344B)
    const IOC_HW_PARAMS: i32 = 0xC158_4111_u32 as i32; // _IOWR('A',0x11, hw_params)
    const IOC_HW_FREE: i32 = 0x0000_4112; // _IO('A',0x12)
    const IOC_PREPARE: i32 = 0x0000_4140; // _IO('A',0x40)

    // ── ALSA parameter constants ──────────────────────────────────────────
    // Format IDs from enum snd_pcm_format_t (<uapi/sound/asound.h>).
    const FMT_DSD_U8: usize = 56;
    const FMT_DSD_U16_LE: usize = 57;
    const FMT_DSD_U32_LE: usize = 58;

    // Access modes
    const ACCESS_RW_INTERLEAVED: usize = 3;

    // Subformat
    const SUBFORMAT_STD: usize = 0;

    // ── ALSA UAPI structs ─────────────────────────────────────────────────

    #[repr(C)]
    #[derive(Clone, Copy)]
    struct SndMask {
        bits: [u32; 8], // 256 bits
    }

    #[repr(C)]
    #[derive(Clone, Copy)]
    struct SndInterval {
        min: u32,
        max: u32,
        flags: u32, // openmin:1, openmax:1, integer:1, reserved:29
    }

    // Layout matches kernel struct snd_pcm_hw_params exactly on arm64.
    // 4 + 96 + 144 + 24 + 4(pad) + 8 + 64 = 344 bytes.
    #[repr(C)]
    struct SndPcmHwParams {
        flags: u32,
        masks: [SndMask; 3], // ACCESS, FORMAT, SUBFORMAT
        intervals: [SndInterval; 12],
        rmask: u32,
        cmask: u32,
        info: u32,
        msbits: u32,
        rate_num: u32,
        rate_den: u32,
        fifo_size: u64, // 4 bytes auto-padding before this on arm64
        reserved: [u8; 64],
    }

    // Interval indices into hw_params.intervals[]
    const INTERVAL_SAMPLE_BITS: usize = 0;
    const INTERVAL_FRAME_BITS: usize = 1;
    const INTERVAL_CHANNELS: usize = 2;
    const INTERVAL_RATE: usize = 3;
    const INTERVAL_PERIOD_SIZE: usize = 5;
    const INTERVAL_PERIODS: usize = 7;

    const _: () = assert!(std::mem::size_of::<SndPcmHwParams>() == 344);

    // ── Mask / interval helpers ───────────────────────────────────────────

    fn mask_reset(m: &mut SndMask) {
        m.bits.fill(0);
    }
    fn mask_all(m: &mut SndMask) {
        m.bits.fill(u32::MAX);
    }
    fn mask_set(m: &mut SndMask, bit: usize) {
        m.bits[bit / 32] |= 1 << (bit % 32);
    }
    fn mask_test(m: &SndMask, bit: usize) -> bool {
        m.bits[bit / 32] & (1 << (bit % 32)) != 0
    }
    fn mask_empty(m: &SndMask) -> bool {
        m.bits.iter().all(|&w| w == 0)
    }

    fn interval_wildcard(i: &mut SndInterval) {
        i.min = 0;
        i.max = u32::MAX;
        i.flags = 0;
    }
    fn interval_exact(i: &mut SndInterval, val: u32) {
        i.min = val;
        i.max = val;
        i.flags = 1; // integer
    }

    // ── State ─────────────────────────────────────────────────────────────

    static FD: AtomicI32 = AtomicI32::new(-1);
    static PROBED: AtomicBool = AtomicBool::new(false);
    static PROBE_OK: AtomicBool = AtomicBool::new(false);

    // ── Device discovery ──────────────────────────────────────────────────

    fn parse_pcm_device(name: &str) -> Option<(u32, u32)> {
        let inner = name.strip_prefix("pcmC")?;
        let p = inner.strip_suffix('p')?;
        let mut parts = p.split('D');
        let card = parts.next()?.parse().ok()?;
        let dev = parts.next()?.parse().ok()?;
        Some((card, dev))
    }

    fn discover_playback_devices() -> Vec<(String, u32, u32)> {
        let mut out = Vec::new();
        if let Ok(entries) = std::fs::read_dir("/dev/snd") {
            for entry in entries.flatten() {
                let name = entry.file_name();
                let name = name.to_string_lossy();
                if name.starts_with("pcmC") && name.ends_with('p') {
                    if let Some((card, dev)) = parse_pcm_device(&name) {
                        out.push((format!("/dev/snd/{}", name), card, dev));
                    }
                }
            }
        }
        if out.is_empty() {
            out.push(("/dev/snd/pcmC0D0p".into(), 0, 0));
        }
        out
    }

    // ── Probe ─────────────────────────────────────────────────────────────

    pub fn probe() -> bool {
        if PROBED.load(Ordering::Acquire) {
            return PROBE_OK.load(Ordering::Acquire);
        }
        let ok = compute_probe();
        PROBE_OK.store(ok, Ordering::Release);
        PROBED.store(true, Ordering::Release);
        ok
    }

    fn compute_probe() -> bool {
        let devices = discover_playback_devices();
        for (path, card, dev) in &devices {
            let cpath = CString::new(path.as_str()).unwrap_or_default();
            unsafe {
                if libc::access(cpath.as_ptr(), libc::R_OK | libc::W_OK) == 0 {
                    log::info!(
                        "[DSD-ALSA] Accessible playback device: {} (card {} dev {})",
                        path,
                        card,
                        dev
                    );
                    return true;
                } else {
                    let err = std::io::Error::last_os_error().raw_os_error().unwrap_or(0);
                    log::info!(
                        "[DSD-ALSA] {} not accessible (errno={}, will try at playback time)",
                        path,
                        err
                    );
                }
            }
        }
        log::info!("[DSD-ALSA] No /dev/snd playback devices found");
        false
    }

    // ── Open + configure ──────────────────────────────────────────────────

    pub fn open(byte_rate: u32, channels: usize) -> bool {
        if FD.load(Ordering::Acquire) >= 0 {
            return true;
        }

        let devices = discover_playback_devices();
        for (path, _card, _dev) in &devices {
            match try_open_device(path, byte_rate, channels) {
                Ok(fd) => {
                    FD.store(fd, Ordering::Release);
                    log::info!(
                        "[DSD-ALSA] DSD output opened: {} rate={} ch={}",
                        path,
                        byte_rate,
                        channels
                    );
                    return true;
                }
                Err(e) => {
                    log::info!("[DSD-ALSA] {} failed: {}", path, e);
                }
            }
        }
        log::warn!(
            "[DSD-ALSA] No device accepted DSD at byte_rate={} ch={}",
            byte_rate,
            channels
        );
        false
    }

    fn try_open_device(path: &str, byte_rate: u32, channels: usize) -> Result<i32, String> {
        let cpath = CString::new(path).map_err(|e| format!("path: {}", e))?;
        let fd = unsafe { libc::open(cpath.as_ptr(), libc::O_RDWR | libc::O_CLOEXEC) };
        if fd < 0 {
            let err = std::io::Error::last_os_error();
            return Err(format!("open failed: {} (errno={})", err, err.raw_os_error().unwrap_or(0)));
        }

        // HW_REFINE: query what hardware supports, then narrow to DSD.
        let mut params = SndPcmHwParams {
            flags: 0,
            masks: [SndMask { bits: [0; 8] }; 3],
            intervals: [SndInterval { min: 0, max: 0, flags: 0 }; 12],
            rmask: u32::MAX,
            cmask: 0,
            info: 0,
            msbits: 0,
            rate_num: 0,
            rate_den: 0,
            fifo_size: 0,
            reserved: [0; 64],
        };
        // Wildcard everything
        for m in &mut params.masks {
            mask_all(m);
        }
        for i in &mut params.intervals {
            interval_wildcard(i);
        }

        let rc = unsafe { libc::ioctl(fd, IOC_HW_REFINE as _, &mut params as *mut _ as *mut libc::c_void) };
        if rc < 0 {
            let err = std::io::Error::last_os_error();
            unsafe { libc::close(fd) };
            return Err(format!(
                "HW_REFINE failed: {} (errno={})",
                err,
                err.raw_os_error().unwrap_or(0)
            ));
        }

        // Check if DSD_U8 survived refine
        let dsd_formats = [FMT_DSD_U8, FMT_DSD_U16_LE, FMT_DSD_U32_LE];
        let mut chosen_fmt = None;
        for &fmt in &dsd_formats {
            if mask_test(&params.masks[1], fmt) {
                chosen_fmt = Some(fmt);
                break;
            }
        }

        let fmt = match chosen_fmt {
            Some(f) => {
                log::info!("[DSD-ALSA] Driver supports DSD format bit {}", f);
                f
            }
            None => {
                unsafe { libc::close(fd) };
                return Err("Driver does not support any DSD format".into());
            }
        };

        // Narrow params to exact DSD configuration
        mask_reset(&mut params.masks[0]); // ACCESS
        mask_set(&mut params.masks[0], ACCESS_RW_INTERLEAVED);
        mask_reset(&mut params.masks[1]); // FORMAT
        mask_set(&mut params.masks[1], fmt);
        mask_reset(&mut params.masks[2]); // SUBFORMAT
        mask_set(&mut params.masks[2], SUBFORMAT_STD);

        interval_exact(&mut params.intervals[INTERVAL_CHANNELS], channels as u32);
        interval_exact(&mut params.intervals[INTERVAL_RATE], byte_rate);

        let sample_bits = match fmt {
            FMT_DSD_U8 => 8,
            FMT_DSD_U16_LE => 16,
            FMT_DSD_U32_LE => 32,
            _ => 8,
        };
        interval_exact(&mut params.intervals[INTERVAL_SAMPLE_BITS], sample_bits);
        interval_exact(
            &mut params.intervals[INTERVAL_FRAME_BITS],
            sample_bits * channels as u32,
        );

        let period = (byte_rate / 8).max(1024);
        interval_exact(&mut params.intervals[INTERVAL_PERIOD_SIZE], period);
        interval_exact(&mut params.intervals[INTERVAL_PERIODS], 4);

        params.rmask = 0;
        params.cmask = 0;

        // HW_PARAMS: apply
        let rc = unsafe { libc::ioctl(fd, IOC_HW_PARAMS as _, &mut params as *mut _ as *mut libc::c_void) };
        if rc < 0 {
            let err = std::io::Error::last_os_error();
            unsafe {
                libc::ioctl(fd, IOC_HW_FREE as _, std::ptr::null_mut::<libc::c_void>());
                libc::close(fd);
            }
            return Err(format!(
                "HW_PARAMS failed: {} (errno={})",
                err,
                err.raw_os_error().unwrap_or(0)
            ));
        }

        // PREPARE: transition to PREPARED state
        let rc = unsafe { libc::ioctl(fd, IOC_PREPARE as _, std::ptr::null_mut::<libc::c_void>()) };
        if rc < 0 {
            let err = std::io::Error::last_os_error();
            unsafe {
                libc::ioctl(fd, IOC_HW_FREE as _, std::ptr::null_mut::<libc::c_void>());
                libc::close(fd);
            }
            return Err(format!(
                "PREPARE failed: {} (errno={})",
                err,
                err.raw_os_error().unwrap_or(0)
            ));
        }

        Ok(fd)
    }

    // ── Write ─────────────────────────────────────────────────────────────

    pub fn write(data: &[u8]) -> i32 {
        let fd = FD.load(Ordering::Acquire);
        if fd < 0 {
            return -1;
        }
        let mut offset = 0usize;
        while offset < data.len() {
            let remaining = &data[offset..];
            let written = unsafe {
                libc::write(fd, remaining.as_ptr() as *const libc::c_void, remaining.len())
            };
            if written < 0 {
                let err = std::io::Error::last_os_error();
                let errno = err.raw_os_error().unwrap_or(0);
                if errno == libc::EAGAIN {
                    // Buffer full, brief spin
                    std::thread::yield_now();
                    continue;
                }
                if errno == libc::EPIPE {
                    // Underrun: prepare and retry
                    log::warn!("[DSD-ALSA] Underrun (EPIPE), re-preparing");
                    unsafe {
                        libc::ioctl(fd, IOC_PREPARE as _, std::ptr::null_mut::<libc::c_void>());
                    }
                    continue;
                }
                log::error!("[DSD-ALSA] write failed: {} (errno={})", err, errno);
                return -1;
            }
            offset += written as usize;
        }
        data.len() as i32
    }

    // ── Close ─────────────────────────────────────────────────────────────

    pub fn close() {
        let fd = FD.swap(-1, Ordering::AcqRel);
        if fd >= 0 {
            unsafe {
                libc::ioctl(fd, IOC_HW_FREE as _, std::ptr::null_mut::<libc::c_void>());
                libc::close(fd);
            }
            log::info!("[DSD-ALSA] Device closed");
        }
    }

    pub fn is_open() -> bool {
        FD.load(Ordering::Acquire) >= 0
    }
}

// ── Public API ────────────────────────────────────────────────────────────

#[cfg(target_os = "android")]
pub use internal::{close as dsd_alsa_close, is_open as dsd_alsa_is_open, open as dsd_alsa_open};

#[cfg(target_os = "android")]
pub fn dsd_alsa_probe() -> bool {
    internal::probe()
}

#[cfg(target_os = "android")]
pub fn dsd_alsa_write(data: &[u8]) -> i32 {
    internal::write(data)
}

#[cfg(not(target_os = "android"))]
pub fn dsd_alsa_open(_rate: u32, _channels: usize) -> bool {
    false
}

#[cfg(not(target_os = "android"))]
pub fn dsd_alsa_write(_data: &[u8]) -> i32 {
    -1
}

#[cfg(not(target_os = "android"))]
pub fn dsd_alsa_close() {}

#[cfg(not(target_os = "android"))]
pub fn dsd_alsa_is_open() -> bool {
    false
}

#[cfg(not(target_os = "android"))]
pub fn dsd_alsa_probe() -> bool {
    false
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_pcm_device_names() {
        #[cfg(target_os = "android")]
        {
            assert_eq!(internal::parse_pcm_device("pcmC0D0p"), Some((0, 0)));
            assert_eq!(internal::parse_pcm_device("pcmC1D3p"), Some((1, 3)));
            assert_eq!(internal::parse_pcm_device("pcmC0D0c"), None);
            assert_eq!(internal::parse_pcm_device("control"), None);
        }
    }

    #[test]
    fn non_android_stubs() {
        #[cfg(not(target_os = "android"))]
        {
            assert!(!dsd_alsa_open(352_800, 2));
            assert_eq!(dsd_alsa_write(&[0; 4]), -1);
            assert!(!dsd_alsa_is_open());
            dsd_alsa_close();
            assert!(!dsd_alsa_probe());
        }
    }
}
