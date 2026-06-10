#![allow(non_upper_case_globals)]
#![allow(non_camel_case_types)]
#![allow(non_snake_case)]

mod ffi {
    include!(concat!(env!("OUT_DIR"), "/bindings.rs"));
}

use std::ffi::c_int;
use std::ptr;

pub enum Channels {
    Mono,
    Stereo,
}

impl Channels {
    fn to_c_int(&self) -> c_int {
        match self {
            Channels::Mono => 1,
            Channels::Stereo => 2,
        }
    }

    pub fn count(&self) -> usize {
        match self {
            Channels::Mono => 1,
            Channels::Stereo => 2,
        }
    }
}

pub struct Decoder {
    ptr: *mut ffi::OpusDecoder,
    channels: Channels,
}

unsafe impl Send for Decoder {}

impl Decoder {
    pub fn new(sample_rate: u32, channels: Channels) -> Result<Decoder, i32> {
        let mut err: c_int = 0;
        let ptr = unsafe {
            ffi::opus_decoder_create(
                sample_rate as i32,
                channels.to_c_int(),
                &mut err,
            )
        };
        if err != 0 || ptr.is_null() {
            Err(err)
        } else {
            Ok(Decoder { ptr, channels })
        }
    }

    pub fn decode_float(
        &mut self,
        input: &[u8],
        output: &mut [f32],
        fec: bool,
    ) -> Result<usize, i32> {
        let frame_size = output.len() / self.channels.count();
        let result = unsafe {
            ffi::opus_decode_float(
                self.ptr,
                input.as_ptr(),
                input.len() as i32,
                output.as_mut_ptr(),
                frame_size as i32,
                if fec { 1 } else { 0 },
            )
        };
        if result < 0 {
            Err(result)
        } else {
            Ok(result as usize * self.channels.count())
        }
    }

    pub fn get_nb_samples(&mut self, packet: &[u8]) -> Result<usize, i32> {
        let result = unsafe {
            ffi::opus_decoder_get_nb_samples(
                self.ptr,
                packet.as_ptr(),
                packet.len() as i32,
            )
        };
        if result < 0 {
            Err(result)
        } else {
            Ok(result as usize)
        }
    }

    pub fn reset_state(&mut self) -> Result<(), i32> {
        let result = unsafe { ffi::opus_decoder_ctl(self.ptr, ffi::OPUS_RESET_STATE as i32) };
        if result != 0 {
            Err(result)
        } else {
            Ok(())
        }
    }
}

impl Drop for Decoder {
    fn drop(&mut self) {
        if !self.ptr.is_null() {
            unsafe {
                ffi::opus_decoder_destroy(self.ptr);
            }
            self.ptr = ptr::null_mut();
        }
    }
}
