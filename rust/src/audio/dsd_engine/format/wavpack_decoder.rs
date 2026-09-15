use super::{DsdBitOrder, DsdChannelLayout, DsdFormatDecoder};
use crate::audio::dsd_engine::dsd::DsdRate;
use anyhow::{anyhow, Result};
use std::ffi::CString;
use std::fs::File;
use std::os::raw::c_char;
use std::path::Path;
use wavpack_sys::*;

pub struct WavpackDsdDecoder {
    context: *mut WavpackContext,
    sample_rate: u32,
    channels: u16,
    // libwavpack counts native DSD "samples" as bytes per channel; the trait
    // contract (see DsfDecoder) wants bits.
    total_byte_samples: u64,
    total_samples: u64,
    is_dsd: bool,
    dsd_rate: Option<DsdRate>,
    _file: File,
}

impl WavpackDsdDecoder {
    pub fn open(path: &Path) -> Result<Self> {
        let path_str = path
            .to_str()
            .ok_or_else(|| anyhow!("Invalid path encoding"))?;
        let c_path = CString::new(path_str).map_err(|_| anyhow!("Path contains null byte"))?;

        let _file = File::open(path)?;

        let mut error_buf = [0u8; 256];
        let context = unsafe {
            WavpackOpenFileInput(
                c_path.as_ptr(),
                error_buf.as_mut_ptr() as *mut c_char,
                OPEN_DSD_NATIVE as i32,
                0,
            )
        };

        if context.is_null() {
            let error_msg = unsafe {
                std::ffi::CStr::from_ptr(error_buf.as_ptr() as *const c_char)
                    .to_string_lossy()
                    .into_owned()
            };
            return Err(anyhow!("WavPack open failed: {}", error_msg));
        }

        let qmode = unsafe { WavpackGetQualifyMode(context) } as u32;
        let is_dsd = (qmode & QMODE_DSD_AUDIO) != 0;

        if !is_dsd {
            unsafe { WavpackCloseFile(context) };
            return Err(anyhow!("WavPack file is not DSD"));
        }

        let sample_rate = unsafe { WavpackGetNativeSampleRate(context) };
        let channels = unsafe { WavpackGetNumChannels(context) } as u16;
        let total_byte_samples = unsafe { WavpackGetNumSamples64(context) } as u64;

        let dsd_rate = DsdRate::from_sample_rate(sample_rate);

        Ok(Self {
            context,
            sample_rate,
            channels,
            total_byte_samples,
            total_samples: total_byte_samples * 8,
            is_dsd,
            dsd_rate,
            _file,
        })
    }

    pub fn is_dsd(&self) -> bool {
        self.is_dsd
    }

    pub fn dsd_rate(&self) -> Option<DsdRate> {
        self.dsd_rate
    }
}

impl DsdFormatDecoder for WavpackDsdDecoder {
    fn sample_rate(&self) -> u32 {
        self.sample_rate
    }

    fn channels(&self) -> u16 {
        self.channels
    }

    fn total_samples(&self) -> u64 {
        self.total_samples
    }

    fn duration_secs(&self) -> f64 {
        if self.sample_rate == 0 {
            return 0.0;
        }
        self.total_samples as f64 / self.sample_rate as f64
    }

    fn seek(&mut self, sample: u64) -> Result<()> {
        // sample is DSD bits per channel; libwavpack wants bytes
        let result = unsafe { WavpackSeekSample64(self.context, (sample / 8) as i64) };
        if result == 0 {
            return Err(anyhow!("WavPack seek failed"));
        }
        Ok(())
    }

    fn read_dsd_bytes(&mut self, buf: &mut [u8]) -> Result<usize> {
        if !self.is_dsd {
            return Err(anyhow!("WavPackDsdDecoder used for non-DSD WavPack file"));
        }

        let channels = self.channels as usize;
        if channels == 0 || buf.len() < channels {
            return Ok(0);
        }

        // One libwavpack "sample" spans all channels; DSD bytes land interleaved
        // in the low 8 bits of each 32-bit word.
        let samples_to_read = (buf.len() / channels) as u32;
        let mut int_buf = vec![0i32; samples_to_read as usize * channels];
        let unpacked =
            unsafe { WavpackUnpackSamples(self.context, int_buf.as_mut_ptr(), samples_to_read) };

        if unpacked == 0 {
            return Ok(0);
        }

        let bytes_read = unpacked as usize * channels;
        for (dst, src) in buf.iter_mut().take(bytes_read).zip(int_buf.iter()) {
            *dst = *src as u8;
        }

        Ok(bytes_read)
    }

    fn is_finished(&self) -> bool {
        if self.context.is_null() {
            return true;
        }
        let index = unsafe { WavpackGetSampleIndex64(self.context) };
        index >= self.total_byte_samples as i64
    }

    fn channel_layout(&self) -> DsdChannelLayout {
        DsdChannelLayout::Interleaved
    }

    fn bit_order(&self) -> DsdBitOrder {
        DsdBitOrder::MsbFirst
    }
}

impl Drop for WavpackDsdDecoder {
    fn drop(&mut self) {
        if !self.context.is_null() {
            unsafe {
                WavpackCloseFile(self.context);
            }
        }
    }
}

unsafe impl Send for WavpackDsdDecoder {}
