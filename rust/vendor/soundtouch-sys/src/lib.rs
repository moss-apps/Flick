//! Raw FFI bindings to the bundled SoundTouch library (SoundTouchDLL C API),
//! compiled with SOUNDTOUCH_FLOAT_SAMPLES so samples are interleaved f32.

use core::ffi::{c_char, c_void};

pub type SoundTouchHandle = *mut c_void;

// Setting ids for soundtouch_setSetting (see SoundTouch.h).
pub const SETTING_USE_AA_FILTER: i32 = 0;
pub const SETTING_AA_FILTER_LENGTH: i32 = 1;
pub const SETTING_USE_QUICKSEEK: i32 = 2;
pub const SETTING_SEQUENCE_MS: i32 = 3;
pub const SETTING_SEEKWINDOW_MS: i32 = 4;
pub const SETTING_OVERLAP_MS: i32 = 5;

extern "C" {
    pub fn soundtouch_createInstance() -> SoundTouchHandle;
    pub fn soundtouch_destroyInstance(h: SoundTouchHandle);
    pub fn soundtouch_getVersionString() -> *const c_char;

    pub fn soundtouch_setPitchSemiTones(h: SoundTouchHandle, new_pitch: f32);
    pub fn soundtouch_setChannels(h: SoundTouchHandle, num_channels: u32) -> i32;
    pub fn soundtouch_setSampleRate(h: SoundTouchHandle, srate: u32) -> i32;

    /// Returns number of samples (per channel) accepted, or -1 on error.
    pub fn soundtouch_putSamples(
        h: SoundTouchHandle,
        samples: *const f32,
        num_samples: u32,
    ) -> i32;
    /// Returns number of samples (per channel) written to `out`.
    pub fn soundtouch_receiveSamples(
        h: SoundTouchHandle,
        out: *mut f32,
        max_samples: u32,
    ) -> u32;
    pub fn soundtouch_numSamples(h: SoundTouchHandle) -> u32;
    pub fn soundtouch_clear(h: SoundTouchHandle);
    pub fn soundtouch_flush(h: SoundTouchHandle) -> i32;
    pub fn soundtouch_setSetting(h: SoundTouchHandle, setting_id: i32, value: i32) -> i32;
}
