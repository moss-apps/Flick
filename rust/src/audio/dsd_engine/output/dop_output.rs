use super::super::dsd::dop::DopPacker;
use super::super::dsd::DsdRate;

pub struct DopOutput {
    packer: DopPacker,
}

impl DopOutput {
    pub fn new(dsd_rate: DsdRate, channels: usize) -> Self {
        Self {
            packer: DopPacker::new(dsd_rate, channels),
        }
    }

    pub fn pack(
        &mut self,
        dsd_bytes: &[u8],
        channel_offsets: &[usize],
        output: &mut Vec<f32>,
    ) {
        self.packer.pack_to_f32(dsd_bytes, channel_offsets, output);
    }

    pub fn carrier_rate(&self) -> u32 {
        self.packer.carrier_rate()
    }

    pub fn reset(&mut self) {
        self.packer.reset();
    }
}
