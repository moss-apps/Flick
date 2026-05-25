use super::super::dsd::{DsdDecimationPipeline, DsdRate};

pub struct PcmOutput {
    pipeline: DsdDecimationPipeline,
}

impl PcmOutput {
    pub fn new(dsd_rate: DsdRate, target_rate: u32, channels: usize) -> Self {
        Self {
            pipeline: DsdDecimationPipeline::new(dsd_rate, target_rate, channels),
        }
    }

    pub fn process(
        &mut self,
        dsd_bytes: &[u8],
        channel_offsets: &[usize],
        output: &mut Vec<f32>,
    ) {
        self.pipeline.process_bytes(dsd_bytes, channel_offsets, output);
    }

    pub fn output_rate(&self) -> u32 {
        self.pipeline.target_pcm_rate()
    }

    pub fn reset(&mut self) {
        self.pipeline.reset();
    }
}
