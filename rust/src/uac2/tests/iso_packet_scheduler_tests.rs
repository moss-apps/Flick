use crate::uac2::iso_packet_scheduler::IsoPacketScheduler;

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

    assert_eq!(frames.len(), 32);
    assert_eq!(&frames[..8], &[5, 6, 5, 6, 5, 6, 5, 6]);
}

#[test]
fn test_scheduler_44100_hz_microframes_accumulate_exact_second() {
    let bytes_per_frame = 4usize;
    let mut scheduler = IsoPacketScheduler::new(44_100, bytes_per_frame, 125);
    let total_frames: usize = (0..250)
        .flat_map(|_| scheduler.next_transfer_packet_bytes())
        .map(|packet| packet / bytes_per_frame)
        .sum();

    assert_eq!(total_frames, 44_100);
}

#[test]
fn test_scheduler_48000_hz_microframes_accumulate_exact_second() {
    let bytes_per_frame = 4usize;
    let mut scheduler = IsoPacketScheduler::new(48_000, bytes_per_frame, 125);
    let total_frames: usize = (0..250)
        .flat_map(|_| scheduler.next_transfer_packet_bytes())
        .map(|packet| packet / bytes_per_frame)
        .sum();

    assert_eq!(total_frames, 48_000);
}

#[test]
fn test_scheduler_96000_hz_microframes_accumulate_exact_second() {
    let bytes_per_frame = 6usize;
    let mut scheduler = IsoPacketScheduler::new(96_000, bytes_per_frame, 125);
    let total_frames: usize = (0..250)
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

    assert_eq!(frames.len(), 32);
    assert!(frames.iter().all(|frames| *frames == 12));
}

#[test]
fn test_scheduler_88200_hz_microframes_accumulate_exact_second() {
    let bytes_per_frame = 6usize;
    let mut scheduler = IsoPacketScheduler::new(88_200, bytes_per_frame, 125);
    let total_frames: usize = (0..250)
        .flat_map(|_| scheduler.next_transfer_packet_bytes())
        .map(|packet| packet / bytes_per_frame)
        .sum();

    assert_eq!(total_frames, 88_200);
}

#[test]
fn test_scheduler_176400_hz_microframes_accumulate_exact_second() {
    let bytes_per_frame = 6usize;
    let mut scheduler = IsoPacketScheduler::new(176_400, bytes_per_frame, 125);
    let total_frames: usize = (0..250)
        .flat_map(|_| scheduler.next_transfer_packet_bytes())
        .map(|packet| packet / bytes_per_frame)
        .sum();

    assert_eq!(total_frames, 176_400);
}

#[test]
fn test_scheduler_192000_hz_microframes_accumulate_exact_second() {
    let bytes_per_frame = 6usize;
    let mut scheduler = IsoPacketScheduler::new(192_000, bytes_per_frame, 125);
    let total_frames: usize = (0..250)
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
fn test_scheduler_feedback_clamps_to_nominal_band() {
    let bytes_per_frame = 6usize;
    let mut scheduler = IsoPacketScheduler::new(96_000, bytes_per_frame, 125);
    scheduler.update_feedback_frames_per_packet(10_000.0);

    let frames = transfer_frames(&scheduler.next_transfer_packet_bytes(), bytes_per_frame);
    let nominal = 96_000.0f64 * 125.0 / 1_000_000.0;
    let max_allowed = (nominal * 1.5).ceil() as usize + 1;
    assert!(frames.iter().all(|frames| *frames <= max_allowed));
}
