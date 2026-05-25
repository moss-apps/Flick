use super::dsd::dop::DopPacker;
use super::dsd::DsdDecimationPipeline;
use super::dsd::{DsdOutputMode, DsdRate};
use anyhow::Result;

pub struct DsdOutputRouter {
    mode: DsdOutputMode,
    pcm_pipeline: Option<DsdDecimationPipeline>,
    dop_packer: Option<DopPacker>,
}

impl DsdOutputRouter {
    pub fn new(
        mode: DsdOutputMode,
        dsd_rate: DsdRate,
        target_rate: u32,
        channels: usize,
    ) -> Self {
        let pcm_pipeline = match mode {
            DsdOutputMode::PcmDecimation | DsdOutputMode::Auto => {
                Some(DsdDecimationPipeline::new(dsd_rate, target_rate, channels))
            }
            DsdOutputMode::Dop | DsdOutputMode::Native => None,
        };

        let dop_packer = match mode {
            DsdOutputMode::Dop => Some(DopPacker::new(dsd_rate, channels)),
            DsdOutputMode::PcmDecimation | DsdOutputMode::Native | DsdOutputMode::Auto => None,
        };

        Self {
            mode,
            pcm_pipeline,
            dop_packer,
        }
    }

    pub fn output_sample_rate(&self, dsd_rate: DsdRate) -> u32 {
        match self.mode {
            DsdOutputMode::PcmDecimation | DsdOutputMode::Auto => self
                .pcm_pipeline
                .as_ref()
                .map(|p| p.target_pcm_rate())
                .unwrap_or(dsd_rate.dop_carrier_rate()),
            DsdOutputMode::Dop => dsd_rate.dop_carrier_rate(),
            DsdOutputMode::Native => dsd_rate.byte_rate(),
        }
    }

    pub fn mode(&self) -> DsdOutputMode {
        self.mode
    }

    pub fn process_dsd_bytes(
        &mut self,
        dsd_bytes: &[u8],
        channel_offsets: &[usize],
        output: &mut Vec<f32>,
    ) -> Result<()> {
        match self.mode {
            DsdOutputMode::PcmDecimation | DsdOutputMode::Auto => {
                if let Some(ref mut pipeline) = self.pcm_pipeline {
                    pipeline.process_bytes(dsd_bytes, channel_offsets, output);
                }
            }
            DsdOutputMode::Dop => {
                if let Some(ref mut packer) = self.dop_packer {
                    packer.pack_to_f32(dsd_bytes, channel_offsets, output);
                }
            }
            DsdOutputMode::Native => {
                pack_native_dsd_f32(dsd_bytes, channel_offsets, output);
            }
        }
        Ok(())
    }

    pub fn reset(&mut self) {
        if let Some(ref mut pipeline) = self.pcm_pipeline {
            pipeline.reset();
        }
        if let Some(ref mut packer) = self.dop_packer {
            packer.reset();
        }
    }
}

fn pack_native_dsd_f32(
    dsd_bytes: &[u8],
    channel_offsets: &[usize],
    output: &mut Vec<f32>,
) {
    let channels = channel_offsets.len().max(1);
    let bytes_per_ch = dsd_bytes.len() / channels;
    output.clear();

    if channels == 1 {
        output.reserve(dsd_bytes.len());
        for &b in dsd_bytes {
            output.push(f32::from_bits(b as u32));
        }
        return;
    }

    let frames = bytes_per_ch;
    output.reserve(frames * channels);
    for i in 0..frames {
        for ch in 0..channels {
            let ch_offset = channel_offsets.get(ch).copied().unwrap_or(ch * bytes_per_ch);
            let b = dsd_bytes[ch_offset + i];
            output.push(f32::from_bits(b as u32));
        }
    }
}
