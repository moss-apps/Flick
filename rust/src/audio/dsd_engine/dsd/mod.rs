pub mod coefficients;
pub mod dop;

use std::sync::OnceLock;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DsdOutputMode {
    PcmDecimation,
    Dop,
    Native,
    Auto,
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

    pub fn byte_rate(&self) -> u32 {
        self.sample_rate() / 8
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

    pub fn pcm_decimation_targets(&self) -> &'static [u32] {
        static DSD64: &[u32] = &[176_400, 88_200, 44_100];
        static DSD128: &[u32] = &[352_800, 176_400, 88_200, 44_100];
        static DSD256: &[u32] = &[705_600, 352_800, 176_400, 88_200];
        static DSD512: &[u32] = &[705_600, 352_800, 176_400, 88_200];
        match self {
            Self::Dsd64 => DSD64,
            Self::Dsd128 => DSD128,
            Self::Dsd256 => DSD256,
            Self::Dsd512 => DSD512,
        }
    }

    pub fn best_pcm_target(&self, engine_rate: u32) -> u32 {
        let targets = self.pcm_decimation_targets();

        // If an engine already exists, prefer a target that matches its rate
        // to avoid expensive engine recreation.
        if engine_rate != 0 {
            for &target in targets.iter() {
                if target == engine_rate {
                    return target;
                }
            }
        }

        // Prefer the DoP carrier rate if it appears in the target list.
        // Many DAPs support the DoP carrier rate via their wired output
        // even though they don't expose it as a standard PCM rate.
        let carrier = self.dop_carrier_rate();
        for &target in targets.iter() {
            if target == carrier {
                return target;
            }
        }

        // For new engines, cap at 176.4 kHz — the highest rate that works
        // reliably across all Android DAP/internal paths. Higher rates
        // (352.8 kHz / 705.6 kHz) often trigger driver bugs or CPU overload.
        for &target in targets.iter() {
            if target <= 176_400 {
                return target;
            }
        }

        targets[0]
    }
}

pub fn resolve_dsd_pcm_sample_rate(dsd_rate: DsdRate, engine_rate: u32) -> u32 {
    dsd_rate.best_pcm_target(engine_rate)
}

pub struct DsdDecimationPipeline {
    dsd_rate: DsdRate,
    target_pcm_rate: u32,
    channels: usize,
    cic_decimation: usize,
    cic_int_c: Vec<i64>,
    cic_int_f: Vec<f64>,
    cic_comb_c: Vec<i64>,
    cic_comb_f: Vec<f64>,
    fir_state: Vec<Vec<f64>>,
    stage2_coeffs: OnceLock<Vec<f64>>,
}

impl DsdDecimationPipeline {
    const CIC_ORDER: usize = 3;
    const FIXED_FIR_TAPS: usize = 512;
    const MAX_CIC_DECIMATION: usize = 4;
    const AUDIO_BAND_HZ: u32 = 18_000;

    pub fn new(dsd_rate: DsdRate, target_pcm_rate: u32, channels: usize) -> Self {
        let total_decimation = dsd_rate.sample_rate() / target_pcm_rate.max(1);
        let cic_decimation = Self::compute_cic_decimation(total_decimation);

        Self {
            dsd_rate,
            target_pcm_rate,
            channels,
            cic_decimation,
            cic_int_c: vec![0; channels * Self::CIC_ORDER],
            cic_int_f: vec![0.0; channels * Self::CIC_ORDER],
            cic_comb_c: vec![0; channels * Self::CIC_ORDER],
            cic_comb_f: vec![0.0; channels * Self::CIC_ORDER],
            fir_state: vec![vec![0.0; Self::FIXED_FIR_TAPS]; channels],
            stage2_coeffs: OnceLock::new(),
        }
    }

    fn compute_cic_decimation(total_decimation: u32) -> usize {
        if total_decimation == 0 {
            return 1;
        }
        let mut best = 1usize;
        for factor in (1..=Self::MAX_CIC_DECIMATION).rev() {
            if total_decimation as usize % factor == 0 {
                best = factor;
                break;
            }
        }
        if best < 2 {
            // fallback: accept any factor, round FIR decimation
            best = 1;
        }
        best
    }

    pub fn target_pcm_rate(&self) -> u32 {
        self.target_pcm_rate
    }

    pub fn dsd_rate(&self) -> DsdRate {
        self.dsd_rate
    }

    pub fn stage2_decimation(&self) -> usize {
        let total = self.dsd_rate.sample_rate() / self.target_pcm_rate.max(1);
        total as usize / self.cic_decimation.max(1)
    }

    fn cic_normalization(&self) -> f64 {
        1.0 / (self.cic_decimation as f64).powi(Self::CIC_ORDER as i32)
    }

    fn get_stage2_coeffs(&self) -> &Vec<f64> {
        self.stage2_coeffs.get_or_init(|| {
            let intermediate_rate = self.dsd_rate.sample_rate() / self.cic_decimation as u32;
            let fir_taps = self.fir_state[0].len();
            let cutoff = Self::AUDIO_BAND_HZ.min(intermediate_rate / 2);
            coefficients::generate_sinc_filter(
                fir_taps,
                cutoff as f64 / intermediate_rate as f64,
                coefficients::WindowFunction::Kaiser { beta: 10.0 },
            )
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

        let bits_per_channel = bytes_per_channel_block * 8;
        let cic_out_count = bits_per_channel / self.cic_decimation;
        let mut cic_buffer = vec![0.0f64; cic_out_count];
        output.clear();

        let coeffs = self.get_stage2_coeffs().clone();
        let norm = self.cic_normalization();

        let mut per_channel: Vec<Vec<f32>> = Vec::with_capacity(self.channels);

        for ch in 0..self.channels {
            let ch_offset = channel_data_offsets
                .get(ch)
                .copied()
                .unwrap_or(ch * bytes_per_channel_block);
            let ch_bytes = &dsd_bytes[ch_offset..ch_offset + bytes_per_channel_block];

            self.run_cic_stage(ch, ch_bytes, &mut cic_buffer);

            let stage2_count = cic_buffer.len() / stage2_decimation;
            let fir_state = &mut self.fir_state[ch];

            let mut ch_output = Vec::with_capacity(stage2_count);
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

                ch_output.push((sample * norm) as f32);
            }
            per_channel.push(ch_output);
        }

        let frames = per_channel.first().map_or(0, |c| c.len());
        for i in 0..frames {
            for ch in 0..self.channels {
                output.push(per_channel[ch][i]);
            }
        }

        if log::log_enabled!(log::Level::Debug) && !output.is_empty() {
            let peak = output.iter().map(|s| s.abs()).fold(0.0f32, f32::max);
            log::debug!(
                "[DSD-PCM] dsd={:?} target={} cic_dec={} s2_dec={} norm={:.6} peak={:.4} frames={}",
                self.dsd_rate,
                self.target_pcm_rate,
                self.cic_decimation,
                stage2_decimation,
                norm,
                peak,
                frames,
            );
        }
    }

    #[inline]
    fn add_f64(c: &mut i64, f: &mut f64, rhs: f64) {
        let full = *f + rhs;
        let carry = full.trunc();
        *c += carry as i64;
        *f = full - carry;
    }

    #[inline]
    fn add_pair(c: &mut i64, f: &mut f64, rhs_c: i64, rhs_f: f64) {
        *c += rhs_c;
        let full = *f + rhs_f;
        let carry = full.trunc();
        *c += carry as i64;
        *f = full - carry;
    }

    #[inline]
    fn sub_pair(c: &mut i64, f: &mut f64, rhs_c: i64, rhs_f: f64) {
        *c -= rhs_c;
        let full = *f - rhs_f;
        let carry = full.trunc();
        *c += carry as i64;
        *f = full - carry;
    }

    fn run_cic_stage(&mut self, channel: usize, bytes: &[u8], output: &mut [f64]) {
        let order = Self::CIC_ORDER;
        let integ_base = channel * order;
        let comb_base = channel * order;
        let dec = self.cic_decimation;
        let mut bit_idx = 0usize;

        for &byte in bytes.iter() {
            for shift in (0..8).rev() {
                let bit_val = if (byte >> shift) & 1 == 1 {
                    1.0f64
                } else {
                    -1.0f64
                };

                Self::add_f64(
                    &mut self.cic_int_c[integ_base],
                    &mut self.cic_int_f[integ_base],
                    bit_val,
                );

                for stage in 1..order {
                    let prev_c = self.cic_int_c[integ_base + stage - 1];
                    let prev_f = self.cic_int_f[integ_base + stage - 1];
                    Self::add_pair(
                        &mut self.cic_int_c[integ_base + stage],
                        &mut self.cic_int_f[integ_base + stage],
                        prev_c,
                        prev_f,
                    );
                }

                bit_idx += 1;
                if bit_idx % dec == 0 {
                    let out_idx = bit_idx / dec - 1;
                    if out_idx < output.len() {
                        let mut val_c = self.cic_int_c[integ_base + order - 1];
                        let mut val_f = self.cic_int_f[integ_base + order - 1];

                        for stage in 0..order {
                            let idx = comb_base + stage;
                            let old_c = self.cic_comb_c[idx];
                            let old_f = self.cic_comb_f[idx];

                            self.cic_comb_c[idx] = val_c;
                            self.cic_comb_f[idx] = val_f;

                            Self::sub_pair(&mut val_c, &mut val_f, old_c, old_f);
                        }

                        output[out_idx] = val_c as f64 + val_f;
                    }
                }
            }
        }
    }

    pub fn reset(&mut self) {
        self.cic_int_c.fill(0);
        self.cic_int_f.fill(0.0);
        self.cic_comb_c.fill(0);
        self.cic_comb_f.fill(0.0);
        for state in &mut self.fir_state {
            state.fill(0.0);
        }
    }
}
