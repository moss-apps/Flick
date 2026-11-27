//! Protocol and arithmetic shared by USB volume discovery and host-side tests.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum AudioControlProtocol {
    Uac1,
    Uac2,
}

impl AudioControlProtocol {
    pub(crate) fn current_request(self) -> u8 {
        match self {
            Self::Uac1 => 0x81,
            Self::Uac2 => 0x01,
        }
    }

    pub(crate) fn writable(self, controls: u32, selector: u8) -> bool {
        match self {
            Self::Uac1 => controls & (1 << (selector - 1)) != 0,
            // 00 absent, 01 read-only, 10 reserved, 11 read/write.
            Self::Uac2 => (controls >> (2 * (selector - 1))) & 3 == 3,
        }
    }

    pub(crate) fn volume_channels(self, controls: &[u32], channels: u16) -> Option<Vec<u16>> {
        if self.writable(*controls.first()?, 2) {
            return Some(vec![0]);
        }
        if channels == 0 || controls.len() <= channels as usize {
            return None;
        }
        (1..=channels).all(|channel| self.writable(controls[channel as usize], 2))
            .then(|| (1..=channels).collect())
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) struct VolumeRange {
    pub(crate) min: i16,
    pub(crate) max: i16,
    pub(crate) resolution: i16,
}

impl VolumeRange {
    pub(crate) fn validate(self) -> Result<Self, String> {
        if self.min > self.max || self.resolution < 0 {
            return Err("invalid signed USB volume range".to_string());
        }
        Ok(self)
    }

    fn nearest(self, target: f64) -> i16 {
        self.nearest_at_or_above(target, self.min).unwrap_or(self.min)
    }

    fn nearest_at_or_above(self, target: f64, floor: i16) -> Option<i16> {
        let target = target.clamp(self.min as f64, self.max as f64);
        let step = i32::from(self.resolution).max(1);
        let offset = (i32::from(floor) - i32::from(self.min)).max(0);
        let first_step = (offset + step - 1) / step;
        // Round inside the supported lattice; MAX need not be step-aligned.
        let last_step = (i32::from(self.max) - i32::from(self.min)) / step;
        if first_step > last_step {
            return None;
        }
        let index = (((target - self.min as f64) / f64::from(step)).round() as i32)
            .clamp(first_step, last_step);
        Some((i32::from(self.min) + index * step) as i16)
    }
}

pub(crate) fn parse_uac2_volume_ranges(data: &[u8]) -> Result<Vec<VolumeRange>, String> {
    if data.len() < 2 {
        return Err("USB volume RANGE has no subrange count".to_string());
    }
    let count = u16::from_le_bytes([data[0], data[1]]) as usize;
    if count == 0 || count > 64 || data.len() != 2 + count * 6 {
        return Err(format!("invalid USB volume RANGE length/count: {}/{count}", data.len()));
    }
    data[2..].chunks_exact(6).map(|bytes| VolumeRange {
        min: i16::from_le_bytes([bytes[0], bytes[1]]),
        max: i16::from_le_bytes([bytes[2], bytes[3]]),
        resolution: i16::from_le_bytes([bytes[4], bytes[5]]),
    }.validate()).collect()
}

pub(crate) fn volume_bounds(ranges: &[VolumeRange]) -> (i16, i16) {
    (ranges.iter().map(|r| r.min).min().unwrap_or(0),
     ranges.iter().map(|r| r.max).max().unwrap_or(0))
}

pub(crate) fn normalize_volume(raw: i16, ranges: &[VolumeRange]) -> f64 {
    let (min, max) = volume_bounds(ranges);
    let span = i32::from(max) - i32::from(min);
    if span == 0 {
        return 0.0;
    }
    ((i32::from(raw) - i32::from(min)) as f64 / span as f64).clamp(0.0, 1.0)
}

pub(crate) fn quantize_volume(volume: f64, ranges: &[VolumeRange]) -> i16 {
    let (min, max) = volume_bounds(ranges);
    let target = min as f64 + volume.clamp(0.0, 1.0) * (i32::from(max) - i32::from(min)) as f64;
    // In a gap, use the nearest supported value (quieter on a tie).
    ranges.iter().map(|range| range.nearest(target)).min_by(|a, b| {
        ((*a as f64 - target).abs()).total_cmp(&(*b as f64 - target).abs()).then(a.cmp(b))
    }).unwrap_or(min)
}

/// The floor applies to explicit slider gestures only. Readback, saved
/// levels and automatic restoration still use the whole device range.
const SLIDER_FLOOR_RAW: i16 = -80 * 256;

fn slider_floor_raw(ranges: &[VolumeRange]) -> i16 {
    let (min, max) = volume_bounds(ranges);
    if min < SLIDER_FLOOR_RAW && max > SLIDER_FLOOR_RAW
        && ranges.iter().any(|range| {
            range.nearest_at_or_above(f64::from(max), SLIDER_FLOOR_RAW + 1).is_some()
        })
    {
        SLIDER_FLOOR_RAW
    } else {
        min
    }
}

pub(crate) fn volume_slider_floor(ranges: &[VolumeRange]) -> f64 {
    normalize_volume(slider_floor_raw(ranges), ranges)
}

pub(crate) fn quantize_slider_volume(volume: f64, ranges: &[VolumeRange]) -> i16 {
    let (min, max) = volume_bounds(ranges);
    let floor = slider_floor_raw(ranges);
    let volume = volume.clamp(0.0, 1.0);
    if volume == 0.0 {
        return min;
    }
    let target = f64::from(floor) + volume * (f64::from(max) - f64::from(floor));
    let lowest_step = if floor > min { floor + 1 } else { min };
    ranges.iter().filter_map(|range| range.nearest_at_or_above(target, lowest_step))
        .min_by(|a, b| {
            (f64::from(*a) - target).abs().total_cmp(&(f64::from(*b) - target).abs())
                .then(a.cmp(b))
        })
        .unwrap_or(min)
}

#[derive(Debug, PartialEq)]
pub(crate) struct HardwareVolumeSnapshot {
    pub(crate) raw: i16,
    pub(crate) volume: f64,
    pub(crate) muted: Option<bool>,
    pub(crate) mute_error: Option<String>,
}

/// Volume readback is mandatory; an optional mute control has independent health.
pub(crate) fn read_hardware_volume_snapshot(
    channels: &[u16],
    ranges: &[VolumeRange],
    mut read_volume: impl FnMut(u16) -> Result<i16, String>,
    read_mute: impl FnOnce() -> Result<Option<bool>, String>,
) -> Result<HardwareVolumeSnapshot, String> {
    let (&first, remaining) = channels.split_first()
        .ok_or_else(|| "USB volume has no playback channels".to_string())?;
    let raw = read_volume(first)?;
    for &channel in remaining {
        if read_volume(channel)? != raw {
            return Err("USB volume readback channels disagree".to_string());
        }
    }
    if !ranges.iter().any(|range| raw >= range.min && raw <= range.max) {
        return Err("USB volume readback is out of range".to_string());
    }
    let (muted, mute_error) = match read_mute() {
        Ok(muted) => (muted, None),
        Err(error) => (None, Some(error)),
    };
    Ok(HardwareVolumeSnapshot {
        raw,
        volume: normalize_volume(raw, ranges),
        muted,
        mute_error,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn uac2_current_is_not_a_uac1_get_request() {
        assert_eq!(AudioControlProtocol::Uac1.current_request(), 0x81);
        assert_eq!(AudioControlProtocol::Uac2.current_request(), 1);
    }

    #[test]
    fn uac2_volume_requires_read_write_and_all_channels() {
        let protocol = AudioControlProtocol::Uac2;
        assert_eq!(protocol.volume_channels(&[0x0c, 0, 0], 2), Some(vec![0]));
        assert_eq!(protocol.volume_channels(&[0x04, 0x0c, 0x0c], 2), Some(vec![1, 2]));
        assert_eq!(protocol.volume_channels(&[0x08, 0x0c, 0], 2), None);
        assert_eq!(AudioControlProtocol::Uac1.volume_channels(&[2], 2), Some(vec![0]));
    }

    #[test]
    fn range_decode_is_signed_bounded_and_multi_range() {
        let data = [2, 0, 0, 0x80, 0, 0xc0, 0, 1, 0, 0xe0, 0, 0, 0, 1];
        let ranges = parse_uac2_volume_ranges(&data).unwrap();
        assert_eq!(ranges[0].min, i16::MIN);
        assert_eq!(ranges[1].max, 0);
        assert!(parse_uac2_volume_ranges(&data[..13]).is_err());
        assert!(parse_uac2_volume_ranges(&[0, 0]).is_err());
        let raw = quantize_volume(0.5, &ranges);
        assert!(ranges.iter().any(|range| raw >= range.min && raw <= range.max));
    }

    #[test]
    fn full_signed_span_does_not_overflow() {
        let ranges = [VolumeRange { min: i16::MIN, max: i16::MAX, resolution: 1 }];
        assert_eq!(normalize_volume(i16::MIN, &ranges), 0.0);
        assert_eq!(normalize_volume(i16::MAX, &ranges), 1.0);
        assert_eq!(quantize_volume(1.0, &ranges), i16::MAX);
    }

    #[test]
    fn quantization_never_emits_an_unaligned_maximum() {
        let ranges = [VolumeRange { min: -1000, max: 0, resolution: 256 }];
        assert_eq!(quantize_volume(1.0, &ranges), -232);
    }

    const TEST_RANGES: [VolumeRange; 1] = [VolumeRange {
        min: -25600, max: 0, resolution: 256,
    }];

    #[test]
    fn slider_floor_does_not_change_startup_or_saved_levels() {
        let ranges = [VolumeRange { min: -127 * 256, max: 0, resolution: 256 }];
        assert_eq!(quantize_volume(0.4, &ranges), -76 * 256);
        assert_eq!(quantize_slider_volume(0.4, &ranges), -48 * 256);
        assert_eq!(quantize_slider_volume(0.0, &ranges), -127 * 256);
        assert_eq!(quantize_slider_volume(0.001, &ranges), -79 * 256);
        assert_eq!(quantize_slider_volume(1.0, &ranges), 0);
        assert_eq!(volume_slider_floor(&ranges), 47.0 / 127.0);
        for raw in [-100 * 256, -80 * 256, -76 * 256] {
            assert_eq!(quantize_volume(normalize_volume(raw, &ranges), &ranges), raw);
        }
    }

    #[test]
    fn slider_selects_supported_steps_across_disjoint_or_coarse_ranges() {
        let mut ranges = [
            VolumeRange { min: -127 * 256, max: -90 * 256, resolution: 256 },
            VolumeRange { min: -60 * 256, max: -100, resolution: 256 },
        ];
        assert_eq!(quantize_slider_volume(0.01, &ranges), -60 * 256);
        assert_eq!(quantize_slider_volume(1.0, &ranges), -256);
        // The advertised maximum is above the floor, but there are no steps there.
        ranges[0].max = -20000;
        ranges[0].resolution = 20000;
        assert_eq!(quantize_slider_volume(0.5, &ranges[..1]), -127 * 256);
        assert_eq!(volume_slider_floor(&ranges[..1]), 0.0);
    }

    #[test]
    fn slider_preserves_the_range_when_it_is_entirely_above_or_below_the_floor() {
        for (min, max) in [(-60 * 256, 0), (-120 * 256, -90 * 256)] {
            let ranges = [VolumeRange { min, max, resolution: 256 }];
            assert_eq!(volume_slider_floor(&ranges), 0.0);
            assert_eq!(quantize_slider_volume(0.6, &ranges), quantize_volume(0.6, &ranges));
        }
    }

    #[test]
    fn optional_mute_failure_does_not_disable_master_volume() {
        let snapshot = read_hardware_volume_snapshot(
            &[0], &TEST_RANGES,
            |channel| { assert_eq!(channel, 0); Ok(-12800) },
            || Err("mute GET_CUR stalled".to_string()),
        ).unwrap();
        assert_eq!(snapshot.volume, 0.5);
        assert_eq!(snapshot.muted, None);
        assert_eq!(snapshot.mute_error.as_deref(), Some("mute GET_CUR stalled"));
    }

    #[test]
    fn stereo_volume_readback_preserves_optional_mute_state() {
        let mut read_channels = Vec::new();
        let snapshot = read_hardware_volume_snapshot(
            &[1, 2], &TEST_RANGES,
            |channel| { read_channels.push(channel); Ok(-6400) },
            || Ok(Some(true)),
        ).unwrap();
        assert_eq!(read_channels, vec![1, 2]);
        assert_eq!(snapshot.volume, 0.75);
        assert_eq!(snapshot.muted, Some(true));
        assert_eq!(snapshot.mute_error, None);
    }

    #[test]
    fn volume_without_mute_remains_usable_and_mute_can_recover() {
        for muted in [None, Some(false), Some(true)] {
            let snapshot = read_hardware_volume_snapshot(
                &[0], &TEST_RANGES, |_| Ok(-25600), || Ok(muted),
            ).unwrap();
            assert_eq!(snapshot.volume, 0.0);
            assert_eq!(snapshot.muted, muted);
            assert_eq!(snapshot.mute_error, None);
        }
    }

    #[test]
    fn failed_or_inconsistent_volume_never_probes_mute() {
        for (channels, values) in [
            (vec![], vec![]),
            (vec![0], vec![Err("volume GET_CUR stalled".to_string())]),
            (vec![0], vec![Ok(1)]),
            (vec![1, 2], vec![Ok(-12800), Ok(-6400)]),
            (vec![1, 2], vec![Ok(-12800), Err("right channel stalled".to_string())]),
        ] {
            let mut values = values.into_iter();
            let result = read_hardware_volume_snapshot(
                &channels, &TEST_RANGES, |_| values.next().unwrap(),
                || panic!("mute must not mask a volume failure"),
            );
            assert!(result.is_err());
        }
    }

    #[test]
    fn readback_in_a_gap_between_volume_ranges_is_rejected() {
        let ranges = [
            VolumeRange { min: -25600, max: -12800, resolution: 256 },
            VolumeRange { min: -6400, max: 0, resolution: 256 },
        ];
        assert!(read_hardware_volume_snapshot(
            &[0], &ranges, |_| Ok(-9600), || panic!("invalid volume"),
        ).is_err());
    }
}
