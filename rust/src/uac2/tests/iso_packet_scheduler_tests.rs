use crate::uac2::iso_packet_scheduler::{IsoPacketScheduler, IsoQueueGeometry};

#[test]
fn queue_changes_only_for_125_us_pcm() {
    let pcm = IsoQueueGeometry::for_stream(125, false);
    assert_eq!(pcm.packets_per_transfer, 16);
    assert_eq!(pcm.transfer_slots, 8);
    assert_eq!(pcm.stable_transfers, 128);
    assert_eq!(pcm.packets_per_transfer * pcm.transfer_slots * 125, 16_000);
    assert_eq!(
        pcm.packets_per_transfer * pcm.stable_transfers * 125,
        256_000
    );

    let dsd = IsoQueueGeometry::for_stream(125, true);
    assert_eq!(dsd.packets_per_transfer, 32);
    assert_eq!(dsd.transfer_slots, 8);
    assert_eq!(dsd.stable_transfers, 64);
    for interval in [250, 500, 1_000, 2_000] {
        let pcm = IsoQueueGeometry::for_stream(interval, false);
        assert_eq!(pcm, IsoQueueGeometry::for_stream(interval, true));
        assert_eq!(pcm.packets_per_transfer, 16);
        assert_eq!(pcm.transfer_slots, 8);
        assert_eq!(pcm.stable_transfers, 64);
    }
}

#[test]
fn regrouping_the_125_us_pcm_queue_preserves_packet_sizes_in_order() {
    let current = IsoQueueGeometry::for_stream(125, false);
    let previous = IsoQueueGeometry {
        packets_per_transfer: 8,
        transfer_slots: 16,
        stable_transfers: 256,
    };
    for rate in [44_100, 96_000, 384_000] {
        let schedule = |geometry: IsoQueueGeometry| {
            let mut scheduler = IsoPacketScheduler::with_geometry(rate, 6, 125, geometry);
            (0..(8_000 / geometry.packets_per_transfer))
                .flat_map(|_| scheduler.next_transfer_packet_bytes())
                .collect::<Vec<_>>()
        };
        assert_eq!(schedule(current), schedule(previous));
    }
}

fn transfer_frames(packet_bytes: &[usize], bytes_per_frame: usize) -> Vec<usize> {
    packet_bytes
        .iter()
        .map(|packet| packet / bytes_per_frame)
        .collect()
}

#[test]
fn test_scheduler_44100_hz_microframes_alternate_five_and_six_frames() {
    let bytes_per_frame = 4usize;
    let mut scheduler = IsoPacketScheduler::new(44_100, bytes_per_frame, 125);
    let frames = transfer_frames(&scheduler.next_transfer_packet_bytes(), bytes_per_frame);

    assert_eq!(frames.len(), scheduler.packets_per_transfer());
    assert_eq!(&frames[..8], &[5, 6, 5, 6, 5, 6, 5, 6]);
}

#[test]
fn test_scheduler_44100_hz_microframes_accumulate_exact_second() {
    let bytes_per_frame = 4usize;
    let mut scheduler = IsoPacketScheduler::new(44_100, bytes_per_frame, 125);
    let total_frames: usize = (0..(8_000 / scheduler.packets_per_transfer()))
        .flat_map(|_| scheduler.next_transfer_packet_bytes())
        .map(|packet| packet / bytes_per_frame)
        .sum();

    assert_eq!(total_frames, 44_100);
}

#[test]
fn test_scheduler_48000_hz_microframes_accumulate_exact_second() {
    let bytes_per_frame = 4usize;
    let mut scheduler = IsoPacketScheduler::new(48_000, bytes_per_frame, 125);
    let total_frames: usize = (0..(8_000 / scheduler.packets_per_transfer()))
        .flat_map(|_| scheduler.next_transfer_packet_bytes())
        .map(|packet| packet / bytes_per_frame)
        .sum();

    assert_eq!(total_frames, 48_000);
}

#[test]
fn test_scheduler_96000_hz_microframes_accumulate_exact_second() {
    let bytes_per_frame = 6usize;
    let mut scheduler = IsoPacketScheduler::new(96_000, bytes_per_frame, 125);
    let total_frames: usize = (0..(8_000 / scheduler.packets_per_transfer()))
        .flat_map(|_| scheduler.next_transfer_packet_bytes())
        .map(|packet| packet / bytes_per_frame)
        .sum();

    assert_eq!(total_frames, 96_000);
}

#[test]
fn test_scheduler_96000_hz_microframes_use_twelve_frames_per_packet() {
    let bytes_per_frame = 6usize;
    let mut scheduler = IsoPacketScheduler::new(96_000, bytes_per_frame, 125);
    let frames = transfer_frames(&scheduler.next_transfer_packet_bytes(), bytes_per_frame);

    assert_eq!(frames.len(), scheduler.packets_per_transfer());
    assert!(frames.iter().all(|frames| *frames == 12));
}

#[test]
fn test_scheduler_88200_hz_microframes_accumulate_exact_second() {
    let bytes_per_frame = 6usize;
    let mut scheduler = IsoPacketScheduler::new(88_200, bytes_per_frame, 125);
    let total_frames: usize = (0..(8_000 / scheduler.packets_per_transfer()))
        .flat_map(|_| scheduler.next_transfer_packet_bytes())
        .map(|packet| packet / bytes_per_frame)
        .sum();

    assert_eq!(total_frames, 88_200);
}

#[test]
fn test_scheduler_176400_hz_microframes_accumulate_exact_second() {
    let bytes_per_frame = 6usize;
    let mut scheduler = IsoPacketScheduler::new(176_400, bytes_per_frame, 125);
    let total_frames: usize = (0..(8_000 / scheduler.packets_per_transfer()))
        .flat_map(|_| scheduler.next_transfer_packet_bytes())
        .map(|packet| packet / bytes_per_frame)
        .sum();

    assert_eq!(total_frames, 176_400);
}

#[test]
fn test_scheduler_192000_hz_microframes_accumulate_exact_second() {
    let bytes_per_frame = 6usize;
    let mut scheduler = IsoPacketScheduler::new(192_000, bytes_per_frame, 125);
    let total_frames: usize = (0..(8_000 / scheduler.packets_per_transfer()))
        .flat_map(|_| scheduler.next_transfer_packet_bytes())
        .map(|packet| packet / bytes_per_frame)
        .sum();

    assert_eq!(total_frames, 192_000);
}

#[test]
fn test_scheduler_96000_hz_full_speed_frames_accumulate_exact_second() {
    let bytes_per_frame = 6usize;
    let mut scheduler = IsoPacketScheduler::new(96_000, bytes_per_frame, 1_000);
    let mut total_frames = 0usize;
    let mut packet_count = 0usize;
    while packet_count < 1_000 {
        for packet in scheduler.next_transfer_packet_bytes() {
            total_frames += packet / bytes_per_frame;
            packet_count += 1;
            if packet_count == 1_000 {
                break;
            }
        }
    }

    assert_eq!(total_frames, 96_000);
}

#[test]
fn test_scheduler_rejects_implausible_feedback() {
    let bytes_per_frame = 6usize;
    let mut scheduler = IsoPacketScheduler::new(96_000, bytes_per_frame, 125);
    assert!(!scheduler.update_feedback_frames_per_packet(10_000.0));

    let frames = transfer_frames(&scheduler.next_transfer_packet_bytes(), bytes_per_frame);
    assert!(frames.iter().all(|frames| *frames == 12));
}

#[test]
fn test_scheduler_352800_hz_dop_carrier_accumulates_exact_second() {
    let bytes_per_frame = 6usize;
    let mut scheduler = IsoPacketScheduler::with_geometry(
        352_800,
        bytes_per_frame,
        125,
        IsoQueueGeometry::for_stream(125, true),
    );
    let mut frames = Vec::new();
    for _ in 0..(8_000 / scheduler.packets_per_transfer()) {
        frames.extend(transfer_frames(
            &scheduler.next_transfer_packet_bytes(),
            bytes_per_frame,
        ));
    }

    assert_eq!(frames.len(), 8_000);
    assert_eq!(frames.iter().sum::<usize>(), 352_800);
    assert!(frames.iter().all(|frames| *frames == 44 || *frames == 45));
    assert_eq!(frames.iter().filter(|frames| **frames == 45).count(), 800);
}

#[test]
fn test_scheduler_feedback_tracks_small_dac_clock_skew() {
    let bytes_per_frame = 6usize;
    let mut scheduler = IsoPacketScheduler::new(352_800, bytes_per_frame, 125);
    let nominal = 352_800.0 * 125.0 / 1_000_000.0;
    let skewed = nominal * 1.000_2;
    assert!(scheduler.update_feedback_frames_per_packet(skewed));

    let total_frames: usize = (0..8_000)
        .map(|_| {
            scheduler
                .next_transfer_packet_bytes()
                .first()
                .copied()
                .unwrap()
                / bytes_per_frame
        })
        .sum();
    let expected = (skewed * 8_000.0) as usize;
    assert!(total_frames.abs_diff(expected) <= 2);
    assert!(total_frames > 352_800);
}

#[test]
fn test_scheduler_feedback_rejects_and_recovers_from_outlier() {
    let bytes_per_frame = 6usize;
    let mut scheduler = IsoPacketScheduler::new(352_800, bytes_per_frame, 125);
    assert!(!scheduler.update_feedback_frames_per_packet(0.0));
    assert!(!scheduler.update_feedback_frames_per_packet(f64::NAN));
    assert!(!scheduler.update_feedback_frames_per_packet(44.1 * 1.5));
    assert!(scheduler.update_feedback_frames_per_packet(44.1 * 1.000_1));

    let total_frames: usize = (0..8_000)
        .map(|_| {
            scheduler
                .next_transfer_packet_bytes()
                .first()
                .copied()
                .unwrap()
                / bytes_per_frame
        })
        .sum();
    assert!(total_frames > 352_800);
}
