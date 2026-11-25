use crate::uac2::iso_packet_scheduler::IsoPacketScheduler;
use crate::uac2::iso_packet_validation::{
    account_timed_out_transfer, validate_iso_packet_descriptors, CompletionStats, PacketAcceptance,
};
use libusb1_sys::{
    constants::{
        LIBUSB_TRANSFER_CANCELLED, LIBUSB_TRANSFER_COMPLETED, LIBUSB_TRANSFER_ERROR,
        LIBUSB_TRANSFER_NO_DEVICE, LIBUSB_TRANSFER_OVERFLOW, LIBUSB_TRANSFER_STALL,
        LIBUSB_TRANSFER_TIMED_OUT,
    },
    libusb_iso_packet_descriptor,
};

fn completed_packets(packet_sizes: &[usize]) -> Vec<libusb_iso_packet_descriptor> {
    packet_sizes
        .iter()
        .map(|length| libusb_iso_packet_descriptor {
            length: *length as u32,
            actual_length: *length as u32,
            status: LIBUSB_TRANSFER_COMPLETED,
        })
        .collect()
}

#[test]
fn test_variable_44100_hz_packets_match_the_submitted_schedule() {
    let mut scheduler = IsoPacketScheduler::new(44_100, 4, 125);
    let packet_sizes = scheduler.next_transfer_packet_bytes();
    assert_eq!(&packet_sizes[..8], &[20, 24, 20, 24, 20, 24, 20, 24]);

    let acceptance = PacketAcceptance::new(44_100, 125, 4);
    assert_eq!(
        validate_iso_packet_descriptors(
            &packet_sizes,
            &completed_packets(&packet_sizes),
            acceptance,
        ),
        Ok(Default::default())
    );
}

#[test]
fn test_issue_354_alternating_packet_phase_is_accepted() {
    let mut scheduler = IsoPacketScheduler::new(44_100, 4, 125);
    // The issue's capture is a 32-packet window; join whole transfers to get one.
    let mut packet_sizes = Vec::new();
    for _ in 0..(32 / scheduler.packets_per_transfer()) {
        packet_sizes.extend(scheduler.next_transfer_packet_bytes());
    }
    let mut descriptors = completed_packets(&packet_sizes);

    // Reconstruct the issue's 23 actual/expected mismatches: the host
    // controller repacketised the URB, so some 24-byte requests completed with
    // 20 bytes and some 20-byte requests with 24.
    for index in (1..16).chain(24..32) {
        descriptors[index].actual_length = 44 - descriptors[index].length;
    }
    assert_eq!(descriptors[0].actual_length, 20);
    assert_eq!(descriptors[0].length, 20);
    assert_eq!(descriptors[1].actual_length, 20);
    assert_eq!(descriptors[1].length, 24);

    let acceptance = PacketAcceptance::new(44_100, 125, 4);
    let stats = validate_iso_packet_descriptors(&packet_sizes, &descriptors, acceptance).unwrap();
    assert_eq!(stats.short_packets, 23);
    assert_eq!(stats.shortfall_frames, 1);
    assert_eq!(stats.lost_bytes, 4);
    assert_eq!(stats.zero_packets, 0);
    assert_eq!(stats.descriptor_rewrites, 0);
}

#[test]
fn test_swapped_legal_sizes_are_accepted() {
    let packet_sizes = [20, 24];
    let mut descriptors = completed_packets(&packet_sizes);
    descriptors[0].actual_length = 24;
    descriptors[1].actual_length = 20;

    let acceptance = PacketAcceptance::new(44_100, 125, 4);
    let stats = validate_iso_packet_descriptors(&packet_sizes, &descriptors, acceptance).unwrap();
    assert_eq!(stats.short_packets, 2);
    assert_eq!(stats.shortfall_frames, 0);
    assert_eq!(stats.lost_bytes, 0);
}

#[test]
fn test_descriptor_rewrite_is_diagnostic_only() {
    let mut descriptors = completed_packets(&[20]);
    descriptors[0].length = 24;
    descriptors[0].actual_length = 20;

    let acceptance = PacketAcceptance::new(44_100, 125, 4);
    let stats = validate_iso_packet_descriptors(&[20], &descriptors, acceptance).unwrap();
    assert_eq!(stats.descriptor_rewrites, 1);
    assert_eq!(stats.short_packets, 0);
}

#[test]
fn test_unaligned_oversized_and_over_request_are_rejected() {
    let acceptance = PacketAcceptance::new(44_100, 125, 4);
    for actual_length in [19, 21, 28] {
        let mut descriptors = completed_packets(&[24]);
        descriptors[0].actual_length = actual_length;
        let error = validate_iso_packet_descriptors(&[24], &descriptors, acceptance).unwrap_err();
        assert!(error.contains("isochronous transfer completed with packet errors:"));
        assert!(error.contains("legal=20/24 frame=4"));
    }
}

#[test]
fn test_zero_length_packets_are_counted_not_rejected() {
    let acceptance = PacketAcceptance::new(44_100, 125, 4);
    let mut descriptors = completed_packets(&[24]);
    descriptors[0].actual_length = 0;
    let stats = validate_iso_packet_descriptors(&[24], &descriptors, acceptance).unwrap();
    assert_eq!(stats.zero_packets, 1);
    assert_eq!(stats.shortfall_frames, 6);
    assert_eq!(stats.lost_bytes, 24);

    // A packet nobody asked anything of is not a dropped packet.
    let empty_request =
        validate_iso_packet_descriptors(&[0, 4], &completed_packets(&[0, 4]), acceptance).unwrap();
    assert_eq!(empty_request.zero_packets, 0);
    assert_eq!(empty_request.lost_bytes, 0);
}

#[test]
fn test_per_packet_errors_are_rejected_even_when_lengths_match() {
    let acceptance = PacketAcceptance::new(44_100, 125, 4);
    for (status, label) in [
        (LIBUSB_TRANSFER_TIMED_OUT, "timed_out"),
        (LIBUSB_TRANSFER_STALL, "stall"),
        (LIBUSB_TRANSFER_NO_DEVICE, "no_device"),
        (LIBUSB_TRANSFER_OVERFLOW, "overflow"),
        (LIBUSB_TRANSFER_CANCELLED, "cancelled"),
        (LIBUSB_TRANSFER_ERROR, "error"),
        (99, "unknown"),
    ] {
        let mut descriptors = completed_packets(&[24]);
        descriptors[0].status = status;
        let error = validate_iso_packet_descriptors(&[24], &descriptors, acceptance).unwrap_err();
        assert!(error.contains("status_errors=1"));
        assert!(error.contains(&format!("status={}({})", label, status)));
    }
}

#[test]
fn test_packet_count_mismatches_are_rejected_and_identified() {
    let acceptance = PacketAcceptance::new(44_100, 125, 4);
    let error = validate_iso_packet_descriptors(&[20, 24], &completed_packets(&[20]), acceptance)
        .unwrap_err();
    assert!(error.contains("packet_counts=requested:2,descriptors:1"));
    assert!(error.contains("packet count changed"));

    let error = validate_iso_packet_descriptors(&[20], &completed_packets(&[20, 24]), acceptance)
        .unwrap_err();
    assert!(error.contains("packet_counts=requested:1,descriptors:2"));
}

#[test]
fn test_matching_schedules_across_rates_formats_and_service_intervals() {
    for sample_rate in [
        44_100, 48_000, 88_200, 96_000, 176_400, 192_000, 352_800, 384_000,
    ] {
        for channels in [1, 2] {
            for subslot_bytes in [1, 2, 3, 4] {
                for service_interval_us in [125, 250, 1_000] {
                    let bytes_per_frame = channels * subslot_bytes;
                    let mut scheduler =
                        IsoPacketScheduler::new(sample_rate, bytes_per_frame, service_interval_us);
                    let acceptance =
                        PacketAcceptance::new(sample_rate, service_interval_us, bytes_per_frame);
                    for _ in 0..8 {
                        let packet_sizes = scheduler.next_transfer_packet_bytes();
                        assert_eq!(
                            validate_iso_packet_descriptors(
                                &packet_sizes,
                                &completed_packets(&packet_sizes),
                                acceptance,
                            ),
                            Ok(Default::default())
                        );
                    }
                }
            }
        }
    }
}

#[test]
fn test_feedback_paced_packets_use_the_actual_submitted_schedule() {
    for sample_rate in [44_100, 48_000, 352_800] {
        let mut scheduler = IsoPacketScheduler::new(sample_rate, 6, 125);
        let acceptance = PacketAcceptance::new(sample_rate, 125, 6);
        let nominal = f64::from(sample_rate) * 125.0 / 1_000_000.0;
        assert!(scheduler.update_feedback_frames_per_packet(nominal * 0.9998));
        for _ in 0..64 {
            let packet_sizes = scheduler.next_transfer_packet_bytes();
            assert_eq!(
                validate_iso_packet_descriptors(
                    &packet_sizes,
                    &completed_packets(&packet_sizes),
                    acceptance,
                ),
                Ok(Default::default())
            );
        }
    }
}

#[test]
fn test_stale_schedule_with_a_different_packet_count_is_rejected() {
    let mut scheduler = IsoPacketScheduler::new(44_100, 4, 125);
    let mut old_packet_sizes = Vec::new();
    for _ in 0..2 {
        old_packet_sizes.extend(scheduler.next_transfer_packet_bytes());
    }
    let current_packet_sizes = scheduler.next_transfer_packet_bytes();
    let descriptors = completed_packets(&current_packet_sizes);

    let acceptance = PacketAcceptance::new(44_100, 125, 4);
    assert!(validate_iso_packet_descriptors(&old_packet_sizes, &descriptors, acceptance).is_err());
    assert_eq!(
        validate_iso_packet_descriptors(&current_packet_sizes, &descriptors, acceptance),
        Ok(Default::default())
    );
}

#[test]
fn test_failure_packet_dump_is_bounded_but_totals_cover_all_packets() {
    let packet_sizes = vec![24; 40];
    let mut descriptors = completed_packets(&packet_sizes);
    for packet in &mut descriptors {
        // 22 bytes is neither 20 nor 24 and is not frame-aligned.
        packet.actual_length = 22;
    }

    let acceptance = PacketAcceptance::new(44_100, 125, 4);
    let error =
        validate_iso_packet_descriptors(&packet_sizes, &descriptors, acceptance).unwrap_err();
    assert!(!error.contains("#32:"));
    assert!(error.contains("omitted_packets=8"));
    assert!(error.contains("requested_total=960 descriptor_total=960 actual_total=880"));
    assert!(error.contains("length_mismatches=40"));
}

#[test]
fn test_exact_mode_still_rejects_any_shortfall() {
    let mut descriptors = completed_packets(&[24]);
    descriptors[0].actual_length = 20;
    assert!(
        validate_iso_packet_descriptors(&[24], &descriptors, PacketAcceptance::exact()).is_err()
    );
    assert_eq!(
        validate_iso_packet_descriptors(
            &[24],
            &completed_packets(&[24]),
            PacketAcceptance::exact()
        ),
        Ok(Default::default())
    );
}

#[test]
fn test_exact_mode_rejects_a_zero_length_completion_of_a_non_empty_packet() {
    let mut descriptors = completed_packets(&[24]);
    descriptors[0].actual_length = 0;
    let error = validate_iso_packet_descriptors(&[24], &descriptors, PacketAcceptance::exact())
        .unwrap_err();
    assert!(error.contains("zero-length completion of a non-empty packet"));
    assert!(error.contains("actual_total=0"));

    // One dead packet among healthy ones is still an error in exact mode.
    let mut descriptors = completed_packets(&[24, 24, 24]);
    descriptors[1].actual_length = 0;
    assert!(validate_iso_packet_descriptors(
        &[24, 24, 24],
        &descriptors,
        PacketAcceptance::exact()
    )
    .is_err());
}

#[test]
fn test_exact_mode_accepts_an_empty_request_that_completes_empty() {
    assert_eq!(
        validate_iso_packet_descriptors(
            &[0, 24],
            &completed_packets(&[0, 24]),
            PacketAcceptance::exact()
        ),
        Ok(Default::default())
    );
}

#[test]
fn test_envelope_mode_still_tolerates_zero_length_completions() {
    // Envelope-based streams count the shortfall as loss instead of failing;
    // only exact mode treats a zero-length completion as an error.
    let acceptance = PacketAcceptance::new(44_100, 125, 4);
    let mut descriptors = completed_packets(&[24, 20]);
    descriptors[0].actual_length = 0;
    let stats = validate_iso_packet_descriptors(&[24, 20], &descriptors, acceptance).unwrap();
    assert_eq!(stats.zero_packets, 1);
    assert_eq!(stats.lost_bytes, 24);
}

#[test]
fn test_lost_bytes_is_the_submitted_total_minus_the_delivered_total() {
    let acceptance = PacketAcceptance::new(44_100, 125, 4);

    // A swap of the two legal sizes with an equal URB total delivers everything.
    let mut swapped = completed_packets(&[20, 24]);
    swapped[0].actual_length = 24;
    swapped[1].actual_length = 20;
    let stats = validate_iso_packet_descriptors(&[20, 24], &swapped, acceptance).unwrap();
    assert_eq!((stats.short_packets, stats.lost_bytes), (2, 0));

    // An all-zero URB loses all of it.
    let mut zeroed = completed_packets(&[20, 24, 20, 24]);
    for packet in &mut zeroed {
        packet.actual_length = 0;
    }
    let stats = validate_iso_packet_descriptors(&[20, 24, 20, 24], &zeroed, acceptance).unwrap();
    assert_eq!((stats.zero_packets, stats.lost_bytes), (4, 88));
    assert_eq!(stats.lost_ring_frames(4), 22);
}

#[test]
fn test_lost_ring_frames_rounds_up_and_never_divides_by_zero() {
    let stats = CompletionStats {
        lost_bytes: 5,
        ..CompletionStats::default()
    };
    assert_eq!(stats.lost_ring_frames(4), 2);
    assert_eq!(stats.lost_ring_frames(0), 5);
    assert_eq!(CompletionStats::default().lost_ring_frames(4), 0);
}

#[test]
fn test_timed_out_transfer_credits_only_packets_that_completed_in_full() {
    let acceptance = PacketAcceptance::new(44_100, 125, 4);
    let packet_sizes = [20, 24, 20, 24];

    // libusb reports a packet the timeout cancelled as COMPLETED with 0 bytes.
    let mut descriptors = completed_packets(&packet_sizes);
    descriptors[2].actual_length = 0;
    descriptors[3].actual_length = 20; // short fragment: not credited
    let stats = account_timed_out_transfer(&packet_sizes, &descriptors, acceptance);
    assert_eq!(stats.lost_bytes, 44);
    assert_eq!(stats.shortfall_frames, 11);
    assert_eq!((stats.short_packets, stats.zero_packets), (0, 0));

    // A packet with an error status is lost even though it reports full length.
    let mut descriptors = completed_packets(&packet_sizes);
    descriptors[0].status = LIBUSB_TRANSFER_ERROR;
    assert_eq!(
        account_timed_out_transfer(&packet_sizes, &descriptors, acceptance).lost_bytes,
        20
    );

    // Every packet whole means nothing was lost.
    assert_eq!(
        account_timed_out_transfer(&packet_sizes, &completed_packets(&packet_sizes), acceptance)
            .lost_bytes,
        0
    );
}

#[test]
fn test_timed_out_transfer_with_mismatched_descriptors_loses_the_whole_urb() {
    let acceptance = PacketAcceptance::new(44_100, 125, 4);
    let packet_sizes = [20, 24, 20, 24];
    let stats =
        account_timed_out_transfer(&packet_sizes, &completed_packets(&[20, 24]), acceptance);
    assert_eq!(stats.lost_bytes, 88);
    assert_eq!(stats.shortfall_frames, 22);
    let stats = account_timed_out_transfer(&packet_sizes, &[], acceptance);
    assert_eq!(stats.lost_bytes, 88);
}
