use crate::audio::backend::BackendType;
use serde::Serialize;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub enum OutputStrategy {
    DapNative,
    MixerBitPerfect,
    MixerMatched,
    UsbDirect,
    ResampledFallback,
    DsdNative,
    DsdDoP,
}

impl From<OutputStrategy> for BackendType {
    fn from(strategy: OutputStrategy) -> Self {
        match strategy {
            OutputStrategy::DapNative => BackendType::DapNative,
            OutputStrategy::MixerBitPerfect => BackendType::MixerBitPerfect,
            OutputStrategy::MixerMatched => BackendType::MixerMatched,
            OutputStrategy::UsbDirect => BackendType::UsbDirect,
            OutputStrategy::ResampledFallback => BackendType::ResampledFallback,
            OutputStrategy::DsdNative => BackendType::DsdNative,
            OutputStrategy::DsdDoP => BackendType::DsdDoP,
        }
    }
}

impl From<BackendType> for OutputStrategy {
    fn from(bt: BackendType) -> Self {
        match bt {
            BackendType::DapNative => OutputStrategy::DapNative,
            BackendType::MixerBitPerfect => OutputStrategy::MixerBitPerfect,
            BackendType::MixerMatched => OutputStrategy::MixerMatched,
            BackendType::UsbDirect => OutputStrategy::UsbDirect,
            BackendType::ResampledFallback => OutputStrategy::ResampledFallback,
            BackendType::DsdNative => OutputStrategy::DsdNative,
            BackendType::DsdDoP => OutputStrategy::DsdDoP,
        }
    }
}

impl OutputStrategy {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::DapNative => "dap_native",
            Self::MixerBitPerfect => "mixer_bit_perfect",
            Self::MixerMatched => "mixer_matched",
            Self::UsbDirect => "usb_direct",
            Self::ResampledFallback => "resampled_fallback",
            Self::DsdNative => "dsd_native",
            Self::DsdDoP => "dsd_dop",
        }
    }

    pub fn requests_passthrough(self) -> bool {
        matches!(
            self,
            Self::DapNative | Self::MixerBitPerfect | Self::UsbDirect | Self::DsdDoP
        )
    }

    pub fn is_dsd(self) -> bool {
        matches!(self, Self::DsdNative | Self::DsdDoP)
    }
}

#[derive(Debug, Clone, Copy)]
pub struct TrackInfo {
    pub sample_rate: u32,
    pub channels: usize,
    pub is_dsd: bool,
    pub dsd_rate: Option<u32>,
}

impl TrackInfo {
    pub fn pcm(sample_rate: u32, channels: usize) -> Self {
        Self {
            sample_rate,
            channels,
            is_dsd: false,
            dsd_rate: None,
        }
    }

    pub fn dsd(dsd_rate: u32, channels: usize) -> Self {
        Self {
            sample_rate: dsd_rate,
            channels,
            is_dsd: true,
            dsd_rate: Some(dsd_rate),
        }
    }
}

#[derive(Debug, Clone)]
pub struct DeviceCaps {
    pub api_level: Option<u32>,
    pub confirmed_dap_native: bool,
    pub supports_mixer_bit_perfect: bool,
    pub supports_requested_rate: bool,
    pub direct_usb_available: bool,
    pub direct_usb_verified: bool,
    pub supports_native_dsd: bool,
    pub supports_dop: bool,
    pub max_dsd_carrier_rate: u32,
}

impl Default for DeviceCaps {
    fn default() -> Self {
        Self {
            api_level: None,
            confirmed_dap_native: false,
            supports_mixer_bit_perfect: false,
            supports_requested_rate: false,
            direct_usb_available: false,
            direct_usb_verified: false,
            supports_native_dsd: false,
            supports_dop: false,
            max_dsd_carrier_rate: 0,
        }
    }
}

pub struct BackendCandidate {
    pub backend_type: BackendType,
    pub scorer: fn(&DeviceCaps, &TrackInfo) -> Option<u8>,
}

fn score_dap_native(device: &DeviceCaps, track: &TrackInfo) -> Option<u8> {
    if device.confirmed_dap_native && track.sample_rate > 0 && track.channels > 0 {
        Some(100)
    } else {
        None
    }
}

fn score_mixer_bit_perfect(device: &DeviceCaps, _track: &TrackInfo) -> Option<u8> {
    if device.api_level.unwrap_or_default() >= 34 && device.supports_mixer_bit_perfect {
        Some(80)
    } else {
        None
    }
}

fn score_mixer_matched(device: &DeviceCaps, track: &TrackInfo) -> Option<u8> {
    if device.supports_requested_rate && track.sample_rate > 0 && track.channels > 0 {
        Some(60)
    } else {
        None
    }
}

fn score_usb_direct(device: &DeviceCaps, _track: &TrackInfo) -> Option<u8> {
    if device.direct_usb_available && device.direct_usb_verified {
        Some(70)
    } else {
        None
    }
}

fn score_resampled_fallback(_device: &DeviceCaps, _track: &TrackInfo) -> Option<u8> {
    Some(10)
}

fn score_dsd_native(device: &DeviceCaps, track: &TrackInfo) -> Option<u8> {
    if track.is_dsd && device.supports_native_dsd {
        log::debug!(
            "[STRATEGY] score_dsd_native = 110 (dsd_rate={}, native_dsd={})",
            track.dsd_rate.unwrap_or(0),
            device.supports_native_dsd,
        );
        Some(110)
    } else {
        log::debug!(
            "[STRATEGY] score_dsd_native = None (is_dsd={}, native_dsd={})",
            track.is_dsd,
            device.supports_native_dsd,
        );
        None
    }
}

fn score_dsd_dop(device: &DeviceCaps, track: &TrackInfo) -> Option<u8> {
    if !track.is_dsd || !device.supports_dop {
        return None;
    }
    let usb_available = device.direct_usb_available && device.direct_usb_verified;
    let dap_available = device.confirmed_dap_native || device.supports_native_dsd;
    if !usb_available && !dap_available {
        return None;
    }
    if let Some(dsd_rate) = track.dsd_rate {
        let carrier = crate::audio::dsd_engine::dsd::DsdRate::from_sample_rate(dsd_rate)
            .map(|r| r.dop_carrier_rate())
            .unwrap_or(0);
        if carrier > 0 && device.max_dsd_carrier_rate >= carrier {
            return Some(90);
        }
    }
    None
}

pub static DEFAULT_CANDIDATES: &[BackendCandidate] = &[
    BackendCandidate { backend_type: BackendType::DsdNative, scorer: score_dsd_native },
    BackendCandidate { backend_type: BackendType::DapNative, scorer: score_dap_native },
    BackendCandidate { backend_type: BackendType::MixerBitPerfect, scorer: score_mixer_bit_perfect },
    BackendCandidate { backend_type: BackendType::DsdDoP, scorer: score_dsd_dop },
    BackendCandidate { backend_type: BackendType::UsbDirect, scorer: score_usb_direct },
    BackendCandidate { backend_type: BackendType::MixerMatched, scorer: score_mixer_matched },
    BackendCandidate { backend_type: BackendType::ResampledFallback, scorer: score_resampled_fallback },
];

pub fn select_strategy(track: TrackInfo, device: &DeviceCaps) -> OutputStrategy {
    select_strategy_excluded(&track, device, &[])
}

pub fn select_strategy_excluded(
    track: &TrackInfo,
    device: &DeviceCaps,
    excluded: &[OutputStrategy],
) -> OutputStrategy {
    select_strategy_with_candidates_filtered(&track, device, DEFAULT_CANDIDATES, excluded)
}

pub fn select_strategy_with_candidates(
    track: &TrackInfo,
    device: &DeviceCaps,
    candidates: &[BackendCandidate],
) -> OutputStrategy {
    select_strategy_with_candidates_filtered(track, device, candidates, &[])
}

pub fn select_strategy_with_candidates_filtered(
    track: &TrackInfo,
    device: &DeviceCaps,
    candidates: &[BackendCandidate],
    excluded: &[OutputStrategy],
) -> OutputStrategy {
    candidates
        .iter()
        .filter(|candidate| {
            let strategy: OutputStrategy = candidate.backend_type.into();
            !excluded.contains(&strategy)
        })
        .filter_map(|candidate| {
            (candidate.scorer)(device, track).map(|score| (candidate.backend_type, score))
        })
        .max_by_key(|(_, score)| *score)
        .map(|(backend_type, _)| backend_type.into())
        .unwrap_or(OutputStrategy::ResampledFallback)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn test_caps() -> DeviceCaps {
        DeviceCaps::default()
    }

    #[test]
    fn picks_mixer_bit_perfect_when_platform_supports_it() {
        let strategy = select_strategy(
            TrackInfo::pcm(44_100, 2),
            &DeviceCaps {
                api_level: Some(34),
                supports_mixer_bit_perfect: true,
                supports_requested_rate: true,
                direct_usb_available: true,
                direct_usb_verified: true,
                ..test_caps()
            },
        );

        assert_eq!(strategy, OutputStrategy::MixerBitPerfect);
    }

    #[test]
    fn picks_usb_direct_when_direct_path_is_only_verified_option() {
        let strategy = select_strategy(
            TrackInfo::pcm(192_000, 2),
            &DeviceCaps {
                api_level: Some(33),
                direct_usb_available: true,
                direct_usb_verified: true,
                ..test_caps()
            },
        );

        assert_eq!(strategy, OutputStrategy::UsbDirect);
    }

    #[test]
    fn falls_back_to_resampler_when_no_exact_path_exists() {
        let strategy = select_strategy(
            TrackInfo::pcm(44_100, 2),
            &DeviceCaps {
                api_level: Some(33),
                ..test_caps()
            },
        );

        assert_eq!(strategy, OutputStrategy::ResampledFallback);
    }

    #[test]
    fn picks_dap_native_for_confirmed_dap_routes() {
        let strategy = select_strategy(
            TrackInfo::pcm(192_000, 2),
            &DeviceCaps {
                api_level: Some(31),
                confirmed_dap_native: true,
                ..test_caps()
            },
        );

        assert_eq!(strategy, OutputStrategy::DapNative);
    }

    #[test]
    fn custom_candidates_override_defaults() {
        fn always_mixer(_device: &DeviceCaps, _track: &TrackInfo) -> Option<u8> {
            Some(200)
        }

        let custom = vec![
            BackendCandidate { backend_type: crate::audio::backend::BackendType::MixerMatched, scorer: always_mixer },
        ];

        let strategy = select_strategy_with_candidates(
            &TrackInfo::pcm(44_100, 2),
            &DeviceCaps {
                api_level: Some(34),
                confirmed_dap_native: true,
                supports_mixer_bit_perfect: true,
                supports_requested_rate: true,
                direct_usb_available: true,
                direct_usb_verified: true,
                ..test_caps()
            },
            &custom,
        );

        assert_eq!(strategy, OutputStrategy::MixerMatched);
    }

    #[test]
    fn dap_native_beats_usb_direct_on_score() {
        let strategy = select_strategy(
            TrackInfo::pcm(192_000, 2),
            &DeviceCaps {
                api_level: Some(33),
                confirmed_dap_native: true,
                direct_usb_available: true,
                direct_usb_verified: true,
                ..test_caps()
            },
        );

        assert_eq!(strategy, OutputStrategy::DapNative);
    }

    #[test]
    fn usb_direct_beats_mixer_matched_on_score() {
        let strategy = select_strategy(
            TrackInfo::pcm(96_000, 2),
            &DeviceCaps {
                api_level: Some(33),
                supports_requested_rate: true,
                direct_usb_available: true,
                direct_usb_verified: true,
                ..test_caps()
            },
        );

        assert_eq!(strategy, OutputStrategy::UsbDirect);
    }

    #[test]
    fn dsd_native_wins_over_dap_native() {
        let strategy = select_strategy(
            TrackInfo::dsd(2_822_400, 2),
            &DeviceCaps {
                confirmed_dap_native: true,
                supports_native_dsd: true,
                direct_usb_available: true,
                direct_usb_verified: true,
                supports_dop: true,
                max_dsd_carrier_rate: 176_400,
                ..test_caps()
            },
        );

        assert_eq!(strategy, OutputStrategy::DsdNative);
    }

    #[test]
    fn dsd_dop_wins_over_usb_direct_for_dsd_tracks() {
        let strategy = select_strategy(
            TrackInfo::dsd(2_822_400, 2),
            &DeviceCaps {
                direct_usb_available: true,
                direct_usb_verified: true,
                supports_dop: true,
                max_dsd_carrier_rate: 176_400,
                ..test_caps()
            },
        );

        assert_eq!(strategy, OutputStrategy::DsdDoP);
    }

    #[test]
    fn dsd_dop_not_chosen_when_carrier_rate_exceeded() {
        let strategy = select_strategy(
            TrackInfo::dsd(5_644_800, 2),
            &DeviceCaps {
                direct_usb_available: true,
                direct_usb_verified: true,
                supports_dop: true,
                max_dsd_carrier_rate: 176_400,
                ..test_caps()
            },
        );

        assert_eq!(strategy, OutputStrategy::UsbDirect);
    }

    #[test]
    fn dsd_native_not_chosen_for_pcm_tracks() {
        let strategy = select_strategy(
            TrackInfo::pcm(96_000, 2),
            &DeviceCaps {
                confirmed_dap_native: true,
                supports_native_dsd: true,
                ..test_caps()
            },
        );

        assert_eq!(strategy, OutputStrategy::DapNative);
    }

    #[test]
    fn dsd_falls_back_to_resampled_when_no_dsd_path() {
        let strategy = select_strategy(
            TrackInfo::dsd(2_822_400, 2),
            &DeviceCaps {
                ..test_caps()
            },
        );

        assert_eq!(strategy, OutputStrategy::ResampledFallback);
    }

    #[test]
    fn excluded_strategies_skips_dsd_native() {
        let strategy = select_strategy_excluded(
            &TrackInfo::dsd(2_822_400, 2),
            &DeviceCaps {
                confirmed_dap_native: false,
                supports_native_dsd: false,
                supports_dop: true,
                max_dsd_carrier_rate: 176_400,
                direct_usb_available: true,
                direct_usb_verified: true,
                ..test_caps()
            },
            &[OutputStrategy::DsdNative],
        );
        assert_eq!(strategy, OutputStrategy::DsdDoP);
    }

    #[test]
    fn excluded_strategies_skips_all_dsd_falls_to_dap_native() {
        let strategy = select_strategy_excluded(
            &TrackInfo::dsd(2_822_400, 2),
            &DeviceCaps {
                confirmed_dap_native: true,
                supports_native_dsd: true,
                supports_dop: true,
                max_dsd_carrier_rate: 176_400,
                ..test_caps()
            },
            &[OutputStrategy::DsdNative, OutputStrategy::DsdDoP],
        );
        assert_eq!(strategy, OutputStrategy::DapNative);
    }

    #[test]
    fn excluded_strategies_with_empty_list_behaves_as_default() {
        let strategy = select_strategy_excluded(
            &TrackInfo::dsd(2_822_400, 2),
            &DeviceCaps {
                confirmed_dap_native: true,
                supports_native_dsd: true,
                supports_dop: true,
                max_dsd_carrier_rate: 176_400,
                ..test_caps()
            },
            &[],
        );
        assert_eq!(strategy, OutputStrategy::DsdNative);
    }
}
