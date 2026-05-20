pub mod coefficients;
pub mod dop;

use std::sync::OnceLock;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FilterQuality {
    Fast,
    Normal,
    High,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DsdOutputMode {
    PcmDecimation,
    Dop,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DsdRate {
    Dsd64,
    Dsd128,
    Dsd256,
    Dsd512,
}

impl DsdRate {
    pub fn sample_rate(&self) -> u32 {
        match self {
            Self::Dsd64 => 2_822_400,
            Self::Dsd128 => 5_644_800,
            Self::Dsd256 => 11_289_600,
            Self::Dsd512 => 22_579_200,
        }
    }

    pub fn from_sample_rate(rate: u32) -> Option<Self> {
        match rate {
            2_822_400 => Some(Self::Dsd64),
            5_644_800 => Some(Self::Dsd128),
            11_289_600 => Some(Self::Dsd256),
            22_579_200 => Some(Self::Dsd512),
            _ => None,
        }
    }

    pub fn dop_carrier_rate(&self) -> u32 {
        match self {
            Self::Dsd64 => 176_400,
            Self::Dsd128 => 352_800,
            Self::Dsd256 => 705_600,
            Self::Dsd512 => 705_600,
        }
    }

    pub fn dop_bits_per_frame(&self) -> u8 {
        match self {
            Self::Dsd64 | Self::Dsd128 | Self::Dsd256 => 24,
            Self::Dsd512 => 32,
        }
    }

    pub fn dsd_bytes_per_channel_per_dop_frame(&self) -> usize {
        ((self.dop_bits_per_frame() - 8) / 8) as usize
    }
}

pub struct DsdDecimationPipeline {
    dsd_rate: DsdRate,
    target_pcm_rate: u32,
    quality: FilterQuality,
    channels: usize,
    cic_integrators: Vec<f64>,
    cic_previous: Vec<f64>,
    fir_state: Vec<Vec<f64>>,
    stage2_coeffs: OnceLock<Vec<f64>>,
}

impl DsdDecimationPipeline {
    const CIC_DECIMATION: usize = 8;
    const CIC_ORDER: usize = 3;

    pub fn new(
        dsd_rate: DsdRate,
        target_pcm_rate: u32,
        quality: FilterQuality,
        channels: usize,
    ) -> Self {
        let total_decimation = dsd_rate.sample_rate() / target_pcm_rate;
        assert!(
            total_decimation % Self::CIC_DECIMATION as u32 == 0,
            "Target PCM rate must be a power-of-8 fraction of DSD rate"
        );

        let fir_taps = match quality {
            FilterQuality::Fast => 32,
            FilterQuality::Normal => 64,
            FilterQuality::High => 128,
        };

        Self {
            dsd_rate,
            target_pcm_rate,
            quality,
            channels,
            cic_integrators: vec![0.0; channels * Self::CIC_ORDER],
            cic_previous: vec![0.0; channels],
            fir_state: vec![vec![0.0; fir_taps]; channels],
            stage2_coeffs: OnceLock::new(),
        }
    }

    pub fn target_pcm_rate(&self) -> u32 {
        self.target_pcm_rate
    }

    pub fn dsd_rate(&self) -> DsdRate {
        self.dsd_rate
    }

    pub fn stage2_decimation(&self) -> usize {
        (self.dsd_rate.sample_rate() / self.target_pcm_rate) as usize / Self::CIC_DECIMATION
    }

    fn get_stage2_coeffs(&self) -> &Vec<f64> {
        self.stage2_coeffs.get_or_init(|| {
            let intermediate_rate = self.dsd_rate.sample_rate() / Self::CIC_DECIMATION as u32;
            let fir_taps = self.fir_state[0].len();
            coefficients::generate_lowpass_fir(fir_taps, intermediate_rate, self.target_pcm_rate)
        })
    }

    pub fn process_bytes(
        &mut self,
        dsd_bytes: &[u8],
        channel_data_offsets: &[usize],
        output: &mut Vec<f32>,
    ) {
        let stage2_decimation = self.stage2_decimation();
        let bytes_per_channel_block = dsd_bytes.len() / self.channels.max(1);

        let mut cic_buffer = vec![0.0f64; bytes_per_channel_block / Self::CIC_DECIMATION];
        output.clear();

        let coeffs = self.get_stage2_coeffs().clone();

        for ch in 0..self.channels {
            let ch_offset = channel_data_offsets
                .get(ch)
                .copied()
                .unwrap_or(ch * bytes_per_channel_block);
            let ch_bytes = &dsd_bytes[ch_offset..ch_offset + bytes_per_channel_block];

            self.run_cic_stage(ch, ch_bytes, &mut cic_buffer);

            let stage2_count = cic_buffer.len() / stage2_decimation;
            let fir_state = &mut self.fir_state[ch];

            for i in 0..stage2_count {
                let base = i * stage2_decimation;
                for j in 0..stage2_decimation {
                    fir_state.rotate_right(1);
                    fir_state[0] = cic_buffer[base + j];
                }

                let sample: f64 = fir_state
                    .iter()
                    .zip(coeffs.iter())
                    .map(|(s, c)| s * c)
                    .sum();

                output.push(sample as f32);
            }
        }
    }

    fn run_cic_stage(&mut self, channel: usize, bytes: &[u8], output: &mut [f64]) {
        let order = Self::CIC_ORDER;
        let integrator_base = channel * order;

        for (byte_idx, &byte) in bytes.iter().enumerate() {
            let bit_sum = (byte.count_ones() as f64 * 2.0) - 8.0;

            self.cic_integrators[integrator_base] += bit_sum;
            for stage in 1..order {
                self.cic_integrators[integrator_base + stage] +=
                    self.cic_integrators[integrator_base + stage - 1];
            }

            if (byte_idx + 1) % Self::CIC_DECIMATION == 0 {
                let out_idx = (byte_idx + 1) / Self::CIC_DECIMATION - 1;
                if out_idx < output.len() {
                    let raw = self.cic_integrators[integrator_base + order - 1];
                    let diff = raw - self.cic_previous[channel];
                    self.cic_previous[channel] = raw;
                    output[out_idx] = diff;
                }
            }
        }
    }

    pub fn reset(&mut self) {
        self.cic_integrators.fill(0.0);
        self.cic_previous.fill(0.0);
        for state in &mut self.fir_state {
            state.fill(0.0);
        }
    }
}
