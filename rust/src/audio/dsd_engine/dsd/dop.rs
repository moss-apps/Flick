use super::DsdRate;

pub struct DopPacker {
    dsd_rate: DsdRate,
    channels: usize,
    marker_state: u8,
    dsd_bytes_per_ch: usize,
}

impl DopPacker {
    pub fn new(dsd_rate: DsdRate, channels: usize) -> Self {
        let dsd_bytes_per_ch = dsd_rate.dsd_bytes_per_channel_per_dop_frame();
        Self {
            dsd_rate,
            channels,
            marker_state: 0x05,
            dsd_bytes_per_ch,
        }
    }

    pub fn carrier_rate(&self) -> u32 {
        self.dsd_rate.dop_carrier_rate()
    }

    pub fn bits_per_frame(&self) -> u8 {
        self.dsd_rate.dop_bits_per_frame()
    }

    pub fn dsd_bytes_per_ch_per_frame(&self) -> usize {
        self.dsd_bytes_per_ch
    }

    pub fn pack_to_f32(
        &mut self,
        dsd_bytes: &[u8],
        channel_offsets: &[usize],
        output: &mut Vec<f32>,
    ) {
        output.clear();

        let bits = self.bits_per_frame() as usize;
        let dsd_data_bits = bits - 8;
        let bytes_per_channel = dsd_bytes.len() / self.channels.max(1);
        let num_frames = bytes_per_channel / self.dsd_bytes_per_ch.max(1);

        for frame_index in 0..num_frames {
            for ch in 0..self.channels {
                let ch_base = channel_offsets
                    .get(ch)
                    .copied()
                    .unwrap_or(ch * bytes_per_channel);
                let frame_byte_offset = ch_base + frame_index * self.dsd_bytes_per_ch;

                let mut sample: u32 = (self.marker_state as u32) << dsd_data_bits;

                for byte_idx in 0..self.dsd_bytes_per_ch {
                    let read_pos = frame_byte_offset + byte_idx;
                    if read_pos < dsd_bytes.len() {
                        let shift = dsd_data_bits - 8 * (byte_idx + 1);
                        sample |= (dsd_bytes[read_pos] as u32) << shift;
                    }
                }

                output.push(f32::from_bits(sample));
            }
            self.advance_marker();
        }
    }

    fn advance_marker(&mut self) {
        self.marker_state = if self.marker_state == 0x05 {
            0xFA
        } else {
            0x05
        };
    }

    pub fn dop_frame_size(&self) -> usize {
        1 + self.dsd_bytes_per_ch * self.channels
    }

    pub fn reset(&mut self) {
        self.marker_state = 0x05;
    }
}
