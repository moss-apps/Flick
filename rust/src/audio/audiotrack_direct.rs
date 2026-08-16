//! Native android::AudioTrack with AUDIO_OUTPUT_FLAG_DIRECT — the UAPP
//! method for native-rate mixer bypass on HiBy-style DAPs. Symbols reached
//! via dlopen(libmedia/libOpenSLES) → dlsym dependency chain.
#![cfg(target_os = "android")]

use crate::audio::commands::AudioEvent;
use crate::audio::engine::{audio_callback, AudioCallbackData};
use crossbeam_channel::Sender;
use std::ffi::{c_void, CStr, CString};
use std::os::raw::{c_char, c_int};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread::JoinHandle;

const RTLD_LAZY: c_int = 1;
const RTLD_LOCAL: c_int = 0;

const AUDIO_STREAM_MUSIC: i32 = 3;
const AUDIO_FORMAT_PCM_32_BIT: u32 = 3;
const AUDIO_CHANNEL_OUT_STEREO: u32 = 0x3;
const AUDIO_OUTPUT_FLAG_DIRECT: u32 = 0x1;
const AUDIO_SESSION_ALLOCATE: i32 = 0;
// transfer_type: SYNC=3, blocking write(), no callback.
const TRANSFER_SYNC: i32 = 3;
const USAGE_MEDIA: u32 = 1;
const CONTENT_TYPE_MUSIC: u32 = 2;

// ponytail: over-allocate — exact sizes not observable from Rust.
const AUDIOTRACK_ALLOC_SIZE: usize = 8192;
const ATTRS_ALLOC_SIZE: usize = 256;

type CtorFn = unsafe extern "C" fn(*mut c_void);
type DtorFn = unsafe extern "C" fn(*mut c_void);
type StartFn = unsafe extern "C" fn(*mut c_void) -> i32;
type WriteFn = unsafe extern "C" fn(*mut c_void, *const c_void, usize, bool) -> i64;
type GetSampleRateFn = unsafe extern "C" fn(*mut c_void) -> i32;
type SetFn = unsafe extern "C" fn(
    *mut c_void,        // this
    i32,                // streamType
    u32,                // rate
    u32,                // format
    u32,                // channelMask
    usize,              // frameCount
    u32,                // flags
    *mut c_void,        // callback_t cbf
    *mut c_void,        // void* user
    i32,                // notificationFrames
    *const c_void,      // const sp<IMemory>* sharedBuffer
    bool,               // threadCanCallJava
    i32,                // sessionId
    i32,                // transferType
    *const c_void,      // const audio_offload_info_t*
    u32,                // uid
    i32,                // pid
    *const c_void,      // const audio_attributes_t*
    bool,               // doNotReconnect
    f32,                // maxRequiredSpeed
    i32,                // selectedDeviceId
) -> i32;

#[repr(C)]
struct AudioTrackApi {
    ctor: CtorFn,
    dtor: DtorFn,
    set: SetFn,
    start: StartFn,
    stop: StartFn,
    write: WriteFn,
    get_sample_rate: GetSampleRateFn,
}

unsafe fn load_api() -> Result<AudioTrackApi, String> {
    // dlopen libmedia (UAPP's path) or libOpenSLES; dlsym follows the
    // dependency chain into libaudioclient either way.
    let mut handle: *mut c_void = std::ptr::null_mut();
    let mut used = "";
    for candidate in ["/system/lib64/libmedia.so", "libOpenSLES.so"] {
        let lib = CString::new(candidate).unwrap();
        handle = libc::dlopen(lib.as_ptr(), RTLD_LAZY | RTLD_LOCAL);
        if !handle.is_null() {
            used = candidate;
            break;
        }
    }
    if handle.is_null() {
        let err = libc::dlerror();
        let msg = if err.is_null() {
            "unknown dlopen error".to_string()
        } else {
            CStr::from_ptr(err).to_string_lossy().into_owned()
        };
        return Err(format!("libmedia/libOpenSLES unavailable: {}", msg));
    }
    let _ = used;

    macro_rules! sym {
        ($name:expr) => {{
            let cname = CString::new($name).unwrap();
            let p = libc::dlsym(handle, cname.as_ptr());
            if p.is_null() {
                return Err(format!("missing symbol {}", $name));
            }
            p
        }};
    }

    Ok(AudioTrackApi {
        ctor: std::mem::transmute::<*mut c_void, CtorFn>(sym!(
            "_ZN7android10AudioTrackC1Ev"
        )),
        dtor: std::mem::transmute::<*mut c_void, DtorFn>(sym!(
            "_ZN7android10AudioTrackD1Ev"
        )),
        set: std::mem::transmute::<*mut c_void, SetFn>(sym!(
            "_ZN7android10AudioTrack3setE19audio_stream_type_tj14audio_format_tjm20audio_output_flags_tPFviPvS4_ES4_iRKNS_2spINS_7IMemoryEEEb15audio_session_tNS0_13transfer_typeEPK20audio_offload_info_tjiPK18audio_attributes_tbfi"
        )),
        start: std::mem::transmute::<*mut c_void, StartFn>(sym!(
            "_ZN7android10AudioTrack5startEv"
        )),
        stop: std::mem::transmute::<*mut c_void, StartFn>(sym!(
            "_ZN7android10AudioTrack4stopEv"
        )),
        write: std::mem::transmute::<*mut c_void, WriteFn>(sym!(
            "_ZN7android10AudioTrack5writeEPKvmb"
        )),
        get_sample_rate: std::mem::transmute::<*mut c_void, GetSampleRateFn>(sym!(
            "_ZNK7android10AudioTrack13getSampleRateEv"
        )),
    })
}

/// Owns one android::AudioTrack constructed in place inside `storage`.
/// `this` is nulled after teardown so Drop stays idempotent.
struct RawAudioTrack {
    api: &'static AudioTrackApi,
    #[allow(dead_code)]
    storage: Vec<u8>,
    this: *mut c_void,
    started: bool,
}

unsafe impl Send for RawAudioTrack {}

impl RawAudioTrack {
    unsafe fn open_direct(api: &'static AudioTrackApi, rate: u32) -> Result<Self, String> {
        let mut storage = vec![0u8; AUDIOTRACK_ALLOC_SIZE];
        let this = storage.as_mut_ptr() as *mut c_void;
        (api.ctor)(this);

        // ~400 ms buffer like UAPP.
        let frame_count = ((rate as u64 * 400) / 1000).max(256) as usize;
        let mut attrs = vec![0u8; ATTRS_ALLOC_SIZE];
        attrs[0..4].copy_from_slice(&CONTENT_TYPE_MUSIC.to_le_bytes());
        attrs[4..8].copy_from_slice(&USAGE_MEDIA.to_le_bytes());

        // Empty sp<IMemory> — a null reference here is UB and returns -22.
        static EMPTY_SP: [u64; 1] = [0];

        let status = (api.set)(
            this,
            AUDIO_STREAM_MUSIC,
            rate,
            AUDIO_FORMAT_PCM_32_BIT,
            AUDIO_CHANNEL_OUT_STEREO,
            frame_count,
            AUDIO_OUTPUT_FLAG_DIRECT,
            std::ptr::null_mut(),
            std::ptr::null_mut(),
            0,
            EMPTY_SP.as_ptr() as *const c_void,
            false,
            AUDIO_SESSION_ALLOCATE,
            TRANSFER_SYNC,
            std::ptr::null(),
            u32::MAX,
            -1,
            attrs.as_ptr() as *const c_void,
            false,
            1.0,
            0,
        );
        if status != 0 {
            (api.dtor)(this);
            return Err(format!("AudioTrack DIRECT open failed (status {})", status));
        }
        let opened_rate = (api.get_sample_rate)(this);
        if opened_rate != rate as i32 {
            (api.dtor)(this);
            return Err(format!(
                "opened at {} Hz instead of requested {} Hz — policy adapted the request (no native direct profile)",
                opened_rate, rate
            ));
        }
        let status = (api.start)(this);
        if status != 0 {
            (api.dtor)(this);
            return Err(format!("AudioTrack start failed (status {})", status));
        }

        Ok(Self {
            api,
            storage,
            this,
            started: true,
        })
    }

    fn write_blocking(&mut self, bytes: &[u8]) -> Result<(), String> {
        let written =
            unsafe { ((self.api).write)(self.this, bytes.as_ptr() as *const c_void, bytes.len(), true) };
        if written < 0 {
            Err(format!("AudioTrack write failed ({})", written))
        } else {
            Ok(())
        }
    }

    fn close(&mut self) {
        if self.this.is_null() {
            return;
        }
        unsafe {
            if self.started {
                ((self.api).stop)(self.this);
            }
            ((self.api).dtor)(self.this);
        }
        self.started = false;
        self.this = std::ptr::null_mut();
    }
}

impl Drop for RawAudioTrack {
    fn drop(&mut self) {
        self.close();
    }
}

/// Render-thread PCM backend into the native DIRECT AudioTrack.
pub struct AudioTrackDirectBackend {
    stop: Arc<AtomicBool>,
    render_thread: Option<JoinHandle<()>>,
}

impl AudioTrackDirectBackend {
    pub fn start(
        callback_data: Arc<AudioCallbackData>,
        event_tx: Sender<AudioEvent>,
        sample_rate: u32,
        channels: usize,
    ) -> Result<Self, String> {
        let api: &'static AudioTrackApi = Box::leak(Box::new(unsafe { load_api()? }));
        // Fail fast before spawning anything.
        let track = unsafe { RawAudioTrack::open_direct(api, sample_rate)? };
        let stop = Arc::new(AtomicBool::new(false));
        let stop_clone = Arc::clone(&stop);
        let handle = std::thread::Builder::new()
            .name("at-direct-render".to_string())
            .spawn(move || {
                audiotrack_render_loop(track, callback_data, event_tx, sample_rate, channels, stop_clone);
            })
            .map_err(|e| format!("Failed to spawn AudioTrack render thread: {}", e))?;
        Ok(Self {
            stop,
            render_thread: Some(handle),
        })
    }

    pub fn stop(&mut self) {
        self.stop.store(true, Ordering::Release);
        if let Some(handle) = self.render_thread.take() {
            let _ = handle.join();
        }
    }
}

const AT_DIRECT_CHUNK_MS: u64 = 10;

fn audiotrack_render_loop(
    mut track: RawAudioTrack,
    callback_data: Arc<AudioCallbackData>,
    event_tx: Sender<AudioEvent>,
    sample_rate: u32,
    channels: usize,
    stop: Arc<AtomicBool>,
) {
    let chunk_frames = (((sample_rate as u64) * AT_DIRECT_CHUNK_MS) / 1000).max(1) as usize;
    let chunk_samples = chunk_frames * channels;
    let mut render_buffer = vec![0.0f32; chunk_samples];
    let mut pcm_bytes = vec![0u8; chunk_samples * 4];

    while !stop.load(Ordering::Acquire) {
        audio_callback(&mut render_buffer, &callback_data, &event_tx);

        for (i, sample) in render_buffer.iter().enumerate() {
            let clamped = sample.clamp(-1.0, 1.0);
            let value = (clamped * 2_147_483_648.0f32) as i32; // `as` saturates; int24 sources roundtrip exactly
            pcm_bytes[i * 4..i * 4 + 4].copy_from_slice(&value.to_le_bytes());
        }

        if let Err(e) = track.write_blocking(&pcm_bytes) {
            log::error!("[AT-DIRECT] {}", e);
            break;
        }
    }
    track.close();
}
