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

    /// Nearest supported value to `target` that lies above `floor`, if this
    /// range has one. A `floor` at or below the range minimum does not restrict it.
    fn nearest_above(self, target: f64, floor: i16) -> Option<i16> {
        let target = target.clamp(self.min as f64, self.max as f64);
        let step = i32::from(self.resolution).max(1);
        // Round inside the supported lattice; MAX need not be step-aligned.
        let last_step = (i32::from(self.max) - i32::from(self.min)) / step;
        let first_step = if floor > self.min {
            (i32::from(floor) - i32::from(self.min)) / step + 1
        } else {
            0
        };
        if first_step > last_step {
            return None;
        }
        let index = (((target - self.min as f64) / step as f64).round() as i32)
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

/// Quietest level the 0..1 slider range reaches above silence: -80 dB in
/// UAC's 1/256 dB units. Many DACs report a minimum near -127 dB, so mapping the
/// slider over their whole range leaves much of its travel inaudible.
pub(crate) const VOLUME_FLOOR_RAW: i16 = -80 * 256;

/// Lower end of the slider's 0..1 span. Fraction 0 is still the device minimum
/// (silence); anything above it spans `volume_floor(..)` to the device maximum,
/// so a device whose minimum is above the floor (or that never rises above it)
/// keeps its linear full-range mapping.
fn volume_floor(min: i16, max: i16) -> i16 {
    if max > VOLUME_FLOOR_RAW { min.max(VOLUME_FLOOR_RAW) } else { min }
}

pub(crate) fn normalize_volume(raw: i16, ranges: &[VolumeRange]) -> f64 {
    let (min, max) = volume_bounds(ranges);
    let floor = volume_floor(min, max);
    let span = i32::from(max) - i32::from(floor);
    if span == 0 {
        return 0.0;
    }
    ((i32::from(raw) - i32::from(floor)) as f64 / span as f64).clamp(0.0, 1.0)
}

pub(crate) fn quantize_volume(volume: f64, ranges: &[VolumeRange]) -> i16 {
    let (min, max) = volume_bounds(ranges);
    let volume = volume.clamp(0.0, 1.0);
    if volume == 0.0 {
        return min;
    }
    let floor = volume_floor(min, max);
    let target = floor as f64 + volume * (i32::from(max) - i32::from(floor)) as f64;
    // In a gap, use the nearest supported value (quieter on a tie). A nonzero
    // fraction stays above the floor so normalize_volume() maps it back to
    // itself; only a range with nothing above it falls back to its minimum.
    let nearest = |above| ranges.iter().filter_map(|range| range.nearest_above(target, above))
        .min_by(|a, b| {
            ((*a as f64 - target).abs()).total_cmp(&(*b as f64 - target).abs()).then(a.cmp(b))
        });
    nearest(floor).or_else(|| nearest(min)).unwrap_or(min)
}

#[derive(Debug, PartialEq)]
pub(crate) struct HardwareVolumeSnapshot {
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

    /// Every raw value the ranges support.
    fn lattice(ranges: &[VolumeRange]) -> Vec<i16> {
        ranges.iter().flat_map(|range| {
            let step = i32::from(range.resolution).max(1) as usize;
            (i32::from(range.min)..=i32::from(range.max)).step_by(step).map(|raw| raw as i16)
        }).collect()
    }

    fn assert_floored_curve_is_consistent(ranges: &[VolumeRange]) {
        let (min, max) = volume_bounds(ranges);
        let floor = volume_floor(min, max);
        let span = (i32::from(max) - i32::from(floor)) as f64;
        let supported = lattice(ranges);
        assert_eq!(quantize_volume(0.0, ranges), min);
        assert_eq!(normalize_volume(min, ranges), 0.0);
        // Supported steps above the floor survive normalize -> quantize exactly.
        for &raw in supported.iter().filter(|&&raw| raw > floor) {
            let fraction = normalize_volume(raw, ranges);
            assert!(fraction > 0.0 && fraction <= 1.0, "{raw} -> {fraction}");
            assert_eq!(quantize_volume(fraction, ranges), raw, "fraction {fraction}");
        }
        // Whatever the slider requests, the write is supported, never below the
        // floor, and reads back (1e-6, as the write verification does) unchanged.
        let mut previous = min;
        for step in 0..=1000 {
            let volume = f64::from(step) / 1000.0;
            let raw = quantize_volume(volume, ranges);
            assert!(supported.contains(&raw), "{volume} -> {raw}");
            assert!(raw >= previous, "not monotonic at {volume}");
            previous = raw;
            if volume > 0.0 {
                assert!(raw > floor || floor == min, "{volume} -> {raw} is at or below the floor");
            }
            let fraction = normalize_volume(raw, ranges);
            assert!((normalize_volume(quantize_volume(fraction, ranges), ranges) - fraction).abs() < 1e-6);
            // Within one lattice step of the request (a step, not half of one,
            // because the floor itself is excluded for a nonzero fraction).
            let widest = ranges.iter().map(|r| i32::from(r.resolution).max(1)).max().unwrap();
            if volume > 0.0 && ranges.len() == 1 && max > floor {
                let target = f64::from(floor) + volume * span;
                assert!((f64::from(raw) - target).abs() <= f64::from(widest), "{volume} -> {raw}");
            }
        }
        assert_eq!(quantize_volume(1.0, ranges), *supported.iter().max().unwrap());
    }

    #[test]
    fn wide_device_spends_the_slider_above_minus_80_db() {
        // -127..0 dB in 1 dB steps; the old mapping put 50 % at -63.5 dB.
        let ranges = [VolumeRange { min: -127 * 256, max: 0, resolution: 256 }];
        assert_eq!(VOLUME_FLOOR_RAW, -20480);
        assert_eq!(quantize_volume(0.0, &ranges), -127 * 256);
        assert_eq!(quantize_volume(0.5, &ranges), -40 * 256);
        assert_eq!(quantize_volume(1.0, &ranges), 0);
        assert_eq!(normalize_volume(-40 * 256, &ranges), 0.5);
        // Anything audible-by-slider is above the floor; the floor step itself
        // and everything below it read back as the bottom of the slider.
        assert_eq!(quantize_volume(0.01, &ranges), -79 * 256);
        assert_eq!(normalize_volume(-80 * 256, &ranges), 0.0);
        assert_eq!(normalize_volume(-127 * 256, &ranges), 0.0);
        assert_eq!(normalize_volume(-100 * 256, &ranges), 0.0);
        assert_floored_curve_is_consistent(&ranges);
    }

    #[test]
    fn floored_curve_round_trips_unaligned_and_fine_lattices() {
        for ranges in [
            // 1/256 dB resolution, minimum -128 dB.
            [VolumeRange { min: i16::MIN, max: 0, resolution: 1 }],
            // Coarse steps that do not land on the floor, maximum above 0 dB.
            [VolumeRange { min: -32000, max: 3000, resolution: 384 }],
            // Maximum not aligned to the step.
            [VolumeRange { min: -25600, max: -500, resolution: 256 }],
        ] {
            assert_floored_curve_is_consistent(&ranges);
        }
    }

    #[test]
    fn device_minimum_above_the_floor_keeps_the_linear_curve() {
        let ranges = [VolumeRange { min: -60 * 256, max: 0, resolution: 256 }];
        for step in 0..=100 {
            let volume = f64::from(step) / 100.0;
            let linear = (-60.0 + volume * 60.0).round() as i16 * 256;
            assert_eq!(quantize_volume(volume, &ranges), linear, "volume {volume}");
        }
        assert_eq!(normalize_volume(-30 * 256, &ranges), 0.5);
        assert_floored_curve_is_consistent(&ranges);
    }

    #[test]
    fn device_that_never_rises_above_the_floor_keeps_its_full_range() {
        let ranges = [VolumeRange { min: -120 * 256, max: -90 * 256, resolution: 256 }];
        assert_eq!(quantize_volume(0.0, &ranges), -120 * 256);
        assert_eq!(quantize_volume(0.5, &ranges), -105 * 256);
        assert_eq!(quantize_volume(1.0, &ranges), -90 * 256);
        assert_eq!(normalize_volume(-105 * 256, &ranges), 0.5);
        assert_floored_curve_is_consistent(&ranges);
    }

    #[test]
    fn multi_range_floor_in_a_gap_or_inside_a_range() {
        // The floor (-80 dB) falls in the gap: only the upper range is above it.
        let gap = [
            VolumeRange { min: -127 * 256, max: -100 * 256, resolution: 256 },
            VolumeRange { min: -50 * 256, max: 0, resolution: 256 },
        ];
        assert_eq!(quantize_volume(0.0, &gap), -127 * 256);
        assert_eq!(quantize_volume(0.001, &gap), -50 * 256);
        assert_eq!(quantize_volume(1.0, &gap), 0);
        assert_floored_curve_is_consistent(&gap);

        // The floor falls inside the lower range, which the slider may use above it.
        let inside = [
            VolumeRange { min: -127 * 256, max: -64 * 256, resolution: 256 },
            VolumeRange { min: -32 * 256, max: 0, resolution: 512 },
        ];
        assert_eq!(quantize_volume(0.01, &inside), -79 * 256);
        assert!(inside.iter().any(|r| {
            let raw = quantize_volume(0.5, &inside);
            raw >= r.min && raw <= r.max
        }));
        assert_floored_curve_is_consistent(&inside);
    }

    #[test]
    fn device_with_nothing_supported_above_the_floor_falls_back_to_its_values() {
        // Maximum -20000 is above the floor, but the 20000-wide steps only
        // support -30000: the slider must still produce a supported value.
        let ranges = [VolumeRange { min: -30000, max: -20000, resolution: 20000 }];
        assert_eq!(quantize_volume(0.0, &ranges), -30000);
        assert_eq!(quantize_volume(0.5, &ranges), -30000);
        assert_eq!(quantize_volume(1.0, &ranges), -30000);
    }

    #[test]
    fn floored_curve_is_never_quieter_than_the_old_one_for_the_same_fraction() {
        // A fraction saved under the old full-range mapping now lands at the same
        // or a louder level on a device whose minimum is below -80 dB (50 % moved
        // from -63.5 dB to -40 dB), so persisted values must not be replayed as is.
        let ranges = [VolumeRange { min: -127 * 256, max: 0, resolution: 256 }];
        for step in 1..100 {
            let volume = f64::from(step) / 100.0;
            let old = (-127.0 + volume * 127.0).round() as i32 * 256;
            assert!(i32::from(quantize_volume(volume, &ranges)) >= old, "volume {volume}");
        }
    }

    #[test]
    fn legacy_fraction_keeps_its_attenuation_on_the_floored_curve() {
        // lib/core/utils/volume_curve.dart mirrors this to carry a level saved
        // under the old full-range mapping over: -63.5 dB is 20.625 % now.
        let ranges = [VolumeRange { min: -127 * 256, max: 0, resolution: 256 }];
        let old_raw = |fraction: f64| (-127.0 * 256.0 * (1.0 - fraction)) as i16;
        assert!((normalize_volume(old_raw(0.5), &ranges) - 0.20625).abs() < 1e-12);
        // 60 % is -50.8 dB, truncated to a whole raw unit here.
        assert!((normalize_volume(old_raw(0.6), &ranges) - 0.365).abs() < 1e-4);
        // Quieter than the floor: the bottom of the slider.
        assert_eq!(normalize_volume(old_raw(0.2), &ranges), 0.0);
    }

    const TEST_RANGES: [VolumeRange; 1] = [VolumeRange {
        min: -25600, max: 0, resolution: 256,
    }];

    #[test]
    fn optional_mute_failure_does_not_disable_master_volume() {
        let snapshot = read_hardware_volume_snapshot(
            &[0], &TEST_RANGES,
            |channel| { assert_eq!(channel, 0); Ok(-12800) },
            || Err("mute GET_CUR stalled".to_string()),
        ).unwrap();
        // -50 dB of a -80..0 dB slider span.
        assert_eq!(snapshot.volume, 0.375);
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
        assert_eq!(snapshot.volume, 0.6875);
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
