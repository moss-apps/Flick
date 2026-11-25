use crate::uac2::iso_packet_validation::{
    account_timed_out_transfer, validate_iso_packet_descriptors, PacketAcceptance,
};
use crate::uac2::iso_transport_loss::{
    lost_frame_budget, ring_bytes_per_frame, LossLimit, LossLimits, LossLogGate, LossTracker,
    UrbLoss,
};
use libusb1_sys::{
    constants::{LIBUSB_TRANSFER_COMPLETED, LIBUSB_TRANSFER_ERROR},
    libusb_iso_packet_descriptor,
};

// 44.1 kHz stereo 16-bit on a 125 us interval: 4-byte frames, 5/6-frame packets.
const BYTES_PER_FRAME: usize = 4;
const SCHEDULE: [usize; 8] = [20, 24, 20, 24, 20, 24, 20, 24];
const SCHEDULE_FRAMES: u64 = 44;

fn acceptance() -> PacketAcceptance {
    PacketAcceptance::new(44_100, 125, BYTES_PER_FRAME)
}

fn lenient_limits() -> LossLimits {
    LossLimits {
        max_consecutive_lossy_urbs: 3,
        max_lost_frames: 1_000_000,
    }
}

fn descriptors(packet_sizes: &[usize], actual: &[usize]) -> Vec<libusb_iso_packet_descriptor> {
    packet_sizes
        .iter()
        .zip(actual)
        .map(|(length, actual)| libusb_iso_packet_descriptor {
            length: *length as u32,
            actual_length: *actual as u32,
            status: LIBUSB_TRANSFER_COMPLETED,
        })
        .collect()
}

/// Account for a URB libusb reported as COMPLETED, the way the output loop does.
fn completed_loss(packet_sizes: &[usize], actual: &[usize]) -> UrbLoss {
    let stats = validate_iso_packet_descriptors(
        packet_sizes,
        &descriptors(packet_sizes, actual),
        acceptance(),
    )
    .expect("completion must be accepted");
    UrbLoss::from_completion(&stats, false, BYTES_PER_FRAME)
}

/// Account for a URB libusb reported as TIMED_OUT, the way the output loop does.
fn timed_out_loss(packet_sizes: &[usize], descriptors: &[libusb_iso_packet_descriptor]) -> UrbLoss {
    let stats = account_timed_out_transfer(packet_sizes, descriptors, acceptance());
    UrbLoss::from_completion(&stats, true, BYTES_PER_FRAME)
}

fn lossless() -> UrbLoss {
    completed_loss(&SCHEDULE, &SCHEDULE)
}

fn lossy_by(lost_frames: u64) -> UrbLoss {
    UrbLoss {
        lost_frames,
        ..UrbLoss::default()
    }
}

#[test]
fn timed_out_urb_credits_only_packets_that_completed_in_full() {
    // Packets 0-2 went out whole. Packet 3 was cancelled mid-flight, which
    // libusb reports as COMPLETED with zero bytes. Packet 4 completed short
    // (16 of 20 bytes). Packets 5-7 never ran.
    let descriptors = descriptors(&SCHEDULE, &[20, 24, 20, 0, 16, 0, 0, 0]);

    let loss = timed_out_loss(&SCHEDULE, &descriptors);
    // Delivered: 20 + 24 + 20 = 64 bytes = 16 frames; the other 112 bytes are lost.
    assert_eq!(loss.lost_frames, 28);
    assert!(loss.timed_out);

    let mut tracker = LossTracker::new(lenient_limits());
    let verdict = tracker.record(SCHEDULE_FRAMES, loss);
    assert_eq!(verdict.consumed_frames, 16);
    assert!(verdict.lossy);
    assert!(verdict.newly_latched);
    assert_eq!(tracker.lost_frames(), 28);
    assert_eq!(tracker.data_urb_timeouts(), 1);
}

#[test]
fn fully_timed_out_urb_counts_every_frame_lost() {
    let cancelled = descriptors(&SCHEDULE, &[0; 8]);
    let loss = timed_out_loss(&SCHEDULE, &cancelled);
    assert_eq!(loss.lost_frames, SCHEDULE_FRAMES);

    let mut tracker = LossTracker::new(lenient_limits());
    let verdict = tracker.record(SCHEDULE_FRAMES, loss);
    assert_eq!(verdict.consumed_frames, 0);
    assert!(tracker.is_latched());
}

#[test]
fn timed_out_packet_with_an_error_status_is_lost_even_at_full_length() {
    let mut packets = descriptors(&SCHEDULE, &SCHEDULE);
    packets[3].status = LIBUSB_TRANSFER_ERROR;
    let loss = timed_out_loss(&SCHEDULE, &packets);
    assert_eq!(loss.lost_frames, 6);
}

#[test]
fn timed_out_urb_with_untrusted_descriptors_counts_the_whole_urb_lost() {
    let truncated = descriptors(&SCHEDULE[..4], &SCHEDULE[..4]);
    let loss = timed_out_loss(&SCHEDULE, &truncated);
    assert_eq!(loss.lost_frames, SCHEDULE_FRAMES);
}

#[test]
fn timed_out_urb_that_delivered_everything_is_lossy_but_not_a_loss() {
    let delivered = descriptors(&SCHEDULE, &SCHEDULE);
    let loss = timed_out_loss(&SCHEDULE, &delivered);
    assert_eq!(loss.lost_frames, 0);

    let mut tracker = LossTracker::new(lenient_limits());
    let verdict = tracker.record(SCHEDULE_FRAMES, loss);
    // Nothing was lost, so nothing latches, but a timeout still counts toward
    // the consecutive bound and never as a successful transfer.
    assert!(verdict.lossy);
    assert!(!verdict.counts_as_successful_transfer());
    assert!(!verdict.newly_latched);
    assert!(!tracker.is_latched());
    assert_eq!(verdict.consumed_frames, SCHEDULE_FRAMES);
    assert_eq!(tracker.consecutive_lossy_urbs(), 1);
}

#[test]
fn short_packet_shortfall_is_lost_not_consumed_and_latches() {
    // The 24-byte packet at index 1 carried only 20 bytes: one frame is gone.
    let loss = completed_loss(&SCHEDULE, &[20, 20, 20, 24, 20, 24, 20, 24]);
    assert_eq!(loss.lost_frames, 1);
    assert_eq!(loss.short_packets, 1);
    assert!(!loss.timed_out);

    let mut tracker = LossTracker::new(lenient_limits());
    let verdict = tracker.record(SCHEDULE_FRAMES, loss);
    assert_eq!(verdict.consumed_frames, SCHEDULE_FRAMES - 1);
    assert!(verdict.lossy);
    assert!(!verdict.counts_as_successful_transfer());
    assert!(verdict.newly_latched);
    assert!(tracker.is_latched());
    assert_eq!(tracker.lost_frames(), 1);
    assert_eq!(tracker.short_packets(), 1);
}

#[test]
fn swapped_legal_sizes_with_an_equal_total_are_not_loss() {
    // Every packet swapped to the other legal size: 20<->24 in pairs.
    let loss = completed_loss(&SCHEDULE, &[24, 20, 24, 20, 24, 20, 24, 20]);
    assert_eq!(loss.lost_frames, 0);
    assert_eq!(loss.short_packets, 8);

    let mut tracker = LossTracker::new(lenient_limits());
    // Give the consecutive counter something to reset, to prove a swap counts
    // as a clean URB rather than a lossy one.
    assert!(tracker.record(SCHEDULE_FRAMES, lossy_by(1)).lossy);
    assert_eq!(tracker.consecutive_lossy_urbs(), 1);

    let latched_before = tracker.is_latched();
    let verdict = tracker.record(SCHEDULE_FRAMES, loss);
    assert!(!verdict.lossy);
    assert!(verdict.counts_as_successful_transfer());
    assert!(!verdict.newly_latched);
    assert!(verdict.fatal.is_none());
    assert_eq!(verdict.consumed_frames, SCHEDULE_FRAMES);
    assert_eq!(tracker.is_latched(), latched_before);
    assert_eq!(tracker.consecutive_lossy_urbs(), 0);
    assert_eq!(
        tracker.lost_frames(),
        1,
        "the swap added nothing to the loss"
    );
    assert_eq!(
        tracker.short_packets(),
        8,
        "short packets are still counted"
    );
}

#[test]
fn swapped_legal_sizes_alone_never_latch() {
    let mut tracker = LossTracker::new(lenient_limits());
    for _ in 0..100 {
        let loss = completed_loss(&SCHEDULE, &[24, 20, 24, 20, 24, 20, 24, 20]);
        let verdict = tracker.record(SCHEDULE_FRAMES, loss);
        assert!(!verdict.lossy);
        assert!(verdict.fatal.is_none());
    }
    assert!(!tracker.is_latched());
    assert_eq!(tracker.lost_frames(), 0);
}

#[test]
fn all_zero_length_urb_is_lossy_and_does_not_reset_the_counter() {
    let loss = completed_loss(&SCHEDULE, &[0; 8]);
    assert_eq!(loss.zero_packets, 8);
    assert_eq!(loss.lost_frames, SCHEDULE_FRAMES);
    assert!(!loss.timed_out, "libusb reported COMPLETED for this one");

    let mut tracker = LossTracker::new(lenient_limits());
    tracker.record(SCHEDULE_FRAMES, lossy_by(1));
    tracker.record(SCHEDULE_FRAMES, lossy_by(1));
    assert_eq!(tracker.consecutive_lossy_urbs(), 2);

    let verdict = tracker.record(SCHEDULE_FRAMES, loss);
    assert!(verdict.lossy);
    assert!(
        !verdict.counts_as_successful_transfer(),
        "must not advance the stream-stable threshold"
    );
    assert_eq!(verdict.consumed_frames, 0);
    assert_eq!(
        tracker.consecutive_lossy_urbs(),
        3,
        "counter must not reset"
    );
    assert_eq!(tracker.zero_packets(), 8);
}

#[test]
fn consecutive_lossy_urbs_trip_the_bound_at_the_right_count() {
    let mut tracker = LossTracker::new(LossLimits {
        max_consecutive_lossy_urbs: 3,
        max_lost_frames: u64::MAX,
    });
    for _ in 0..3 {
        assert_eq!(tracker.record(SCHEDULE_FRAMES, lossy_by(1)).fatal, None);
    }
    // More than three in a row is fatal.
    let verdict = tracker.record(SCHEDULE_FRAMES, lossy_by(1));
    assert_eq!(
        verdict.fatal,
        Some(LossLimit::ConsecutiveLossyUrbs { count: 4, limit: 3 })
    );
}

#[test]
fn timeouts_and_losses_share_one_consecutive_counter() {
    let mut tracker = LossTracker::new(LossLimits {
        max_consecutive_lossy_urbs: 3,
        max_lost_frames: u64::MAX,
    });
    let timeout = UrbLoss {
        timed_out: true,
        ..UrbLoss::default()
    };
    assert_eq!(tracker.record(SCHEDULE_FRAMES, timeout).fatal, None);
    assert_eq!(tracker.record(SCHEDULE_FRAMES, lossy_by(2)).fatal, None);
    assert_eq!(tracker.record(SCHEDULE_FRAMES, timeout).fatal, None);
    assert!(tracker.record(SCHEDULE_FRAMES, lossy_by(2)).fatal.is_some());
}

#[test]
fn a_clean_urb_resets_the_consecutive_counter() {
    let mut tracker = LossTracker::new(LossLimits {
        max_consecutive_lossy_urbs: 3,
        max_lost_frames: u64::MAX,
    });
    for _ in 0..3 {
        assert_eq!(tracker.record(SCHEDULE_FRAMES, lossy_by(1)).fatal, None);
    }
    let clean = tracker.record(SCHEDULE_FRAMES, lossless());
    assert!(!clean.lossy);
    assert_eq!(tracker.consecutive_lossy_urbs(), 0);
    for _ in 0..3 {
        assert_eq!(tracker.record(SCHEDULE_FRAMES, lossy_by(1)).fatal, None);
    }
    assert!(
        tracker.is_latched(),
        "a clean URB never un-latches the stream"
    );
}

#[test]
fn cumulative_loss_trips_the_bound_even_when_never_consecutive() {
    let mut tracker = LossTracker::new(LossLimits {
        max_consecutive_lossy_urbs: 3,
        max_lost_frames: 10,
    });
    let mut fatal = None;
    for _ in 0..3 {
        fatal = tracker.record(SCHEDULE_FRAMES, lossy_by(4)).fatal;
        if fatal.is_some() {
            break;
        }
        // A clean URB in between keeps the consecutive counter at one.
        assert_eq!(tracker.record(SCHEDULE_FRAMES, lossless()).fatal, None);
    }
    assert_eq!(
        fatal,
        Some(LossLimit::CumulativeLostFrames {
            lost: 12,
            limit: 10
        })
    );
    assert_eq!(tracker.consecutive_lossy_urbs(), 1);
}

#[test]
fn cumulative_loss_equal_to_the_limit_is_not_fatal() {
    let mut tracker = LossTracker::new(LossLimits {
        max_consecutive_lossy_urbs: 10,
        max_lost_frames: 10,
    });
    assert_eq!(tracker.record(SCHEDULE_FRAMES, lossy_by(10)).fatal, None);
    assert_eq!(
        tracker.record(SCHEDULE_FRAMES, lossy_by(1)).fatal,
        Some(LossLimit::CumulativeLostFrames {
            lost: 11,
            limit: 10
        })
    );
}

#[test]
fn fatal_messages_name_the_numbers() {
    let consecutive = LossLimit::ConsecutiveLossyUrbs { count: 4, limit: 3 }.to_string();
    assert!(consecutive.contains('4') && consecutive.contains("limit 3"));
    let cumulative = LossLimit::CumulativeLostFrames {
        lost: 4411,
        limit: 4410,
    }
    .to_string();
    assert!(cumulative.contains("4411") && cumulative.contains("4410"));
}

#[test]
fn counters_accumulate_across_urbs() {
    let mut tracker = LossTracker::new(lenient_limits());
    tracker.record(
        SCHEDULE_FRAMES,
        UrbLoss {
            short_packets: 2,
            zero_packets: 1,
            lost_frames: 3,
            timed_out: false,
        },
    );
    tracker.record(
        SCHEDULE_FRAMES,
        UrbLoss {
            short_packets: 1,
            zero_packets: 0,
            lost_frames: 0,
            timed_out: true,
        },
    );
    assert_eq!(tracker.short_packets(), 3);
    assert_eq!(tracker.zero_packets(), 1);
    assert_eq!(tracker.lost_frames(), 3);
    assert_eq!(tracker.data_urb_timeouts(), 1);
}

#[test]
fn native_dsd_loss_is_counted_in_ring_frames_not_transport_frames() {
    // DSD64 stereo over DSD_U32: 2.8224 MHz / 32 bits = 88.2 kHz transport
    // frames of 8 bytes. The ring queues one sample per DSD byte, so a ring
    // frame is 2 bytes (one per channel) and a transport frame is 4 of them.
    let transport_bytes_per_frame = 8;
    let channels = 2;
    let dsd = PacketAcceptance::new(88_200, 125, transport_bytes_per_frame);
    let packet_sizes = [88, 96, 88, 96, 88, 96, 88, 96];
    let queued_bytes: usize = packet_sizes.iter().sum();
    // `prepare_iso_transfer_payload` queues `total_bytes / channels` for native DSD.
    let queued_ring_frames = (queued_bytes / channels) as u64;
    assert_eq!(queued_ring_frames, 368);

    // One 96-byte packet came back with 88: one transport frame (8 bytes) lost.
    let mut actual = packet_sizes;
    actual[1] = 88;
    let stats =
        validate_iso_packet_descriptors(&packet_sizes, &descriptors(&packet_sizes, &actual), dsd)
            .unwrap();
    assert_eq!(stats.lost_bytes, 8);
    assert_eq!(stats.shortfall_frames, 1, "transport frames");

    let native_ring_bytes = ring_bytes_per_frame(true, channels, transport_bytes_per_frame);
    assert_eq!(native_ring_bytes, 2);
    let loss = UrbLoss::from_completion(&stats, false, native_ring_bytes);
    assert_eq!(
        loss.lost_frames, 4,
        "one transport frame is four DSD bytes per channel"
    );

    let mut tracker = LossTracker::new(lenient_limits());
    let verdict = tracker.record(queued_ring_frames, loss);
    assert_eq!(verdict.consumed_frames, 364);

    // Dividing by the transport frame instead would have under-counted by the
    // subslot size and credited three lost ring frames as consumed.
    let wrong = UrbLoss::from_completion(&stats, false, transport_bytes_per_frame);
    assert_eq!(wrong.lost_frames, 1);
}

#[test]
fn pcm_and_dop_ring_frames_match_transport_frames() {
    assert_eq!(ring_bytes_per_frame(false, 2, 8), 8);
    assert_eq!(ring_bytes_per_frame(false, 2, 6), 6);
    assert_eq!(ring_bytes_per_frame(true, 2, 8), 2);
    assert_eq!(ring_bytes_per_frame(true, 2, 2), 2, "1-byte subslot DSD");
    assert_eq!(ring_bytes_per_frame(true, 0, 0), 1, "never divide by zero");
}

#[test]
fn lost_frame_budget_scales_with_the_ring_rate() {
    assert_eq!(lost_frame_budget(44_100, 100), 4_410);
    assert_eq!(lost_frame_budget(192_000, 100), 19_200);
    // Native DSD64 stereo rings at the DSD byte rate per channel.
    assert_eq!(lost_frame_budget(2_822_400 / 8, 100), 35_280);
    assert_eq!(lost_frame_budget(0, 100), 0);
    assert_eq!(lost_frame_budget(u32::MAX, u64::MAX), u64::MAX / 1_000);
}

#[test]
fn log_gate_admits_a_burst_then_at_most_one_per_interval() {
    let mut gate = LossLogGate::new(4, 1_000);
    for now_ms in [0, 1, 2, 3] {
        assert!(gate.admit(now_ms), "burst event at {now_ms} ms");
    }
    assert!(!gate.admit(4));
    assert!(!gate.admit(500));
    assert!(
        !gate.admit(1_002),
        "interval is measured from the last admitted event"
    );
    assert!(gate.admit(1_003));
    assert!(!gate.admit(1_004));
    assert!(gate.admit(2_500));
    assert!(!gate.admit(2_501));
}

#[test]
fn log_gate_bounds_the_rate_of_a_steady_loss_stream_without_going_quiet() {
    // One loss event per millisecond for ten seconds. The old condition tested
    // a cumulative packet count for `% 256 == 0`; that count moves in URB-sized
    // steps from an arbitrary offset and can skip every multiple. The gate keys
    // on elapsed time instead: the burst, then one line per interval.
    let mut gate = LossLogGate::new(4, 1_000);
    let admitted: Vec<u64> = (0..10_000u64)
        .filter(|now_ms| gate.admit(*now_ms))
        .collect();
    assert_eq!(
        admitted,
        [0, 1, 2, 3, 1_003, 2_003, 3_003, 4_003, 5_003, 6_003, 7_003, 8_003, 9_003]
    );
}

#[test]
fn log_gate_survives_a_non_monotonic_clock() {
    let mut gate = LossLogGate::new(0, 1_000);
    assert!(gate.admit(5_000));
    assert!(!gate.admit(4_000));
    assert!(gate.admit(6_000));
}
