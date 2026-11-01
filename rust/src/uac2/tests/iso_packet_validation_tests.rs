use crate::uac2::iso_packet_scheduler::IsoPacketScheduler;
use crate::uac2::iso_packet_validation::validate_iso_packet_descriptors;
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

    assert_eq!(
        validate_iso_packet_descriptors(&packet_sizes, &completed_packets(&packet_sizes)),
        Ok(())
    );
}

#[test]
fn test_issue_354_mismatches_report_a_frame_deficit_not_harmless_alternation() {
    let mut scheduler = IsoPacketScheduler::new(44_100, 4, 125);
    scheduler.next_transfer_packet_bytes();
    scheduler.next_transfer_packet_bytes();
    let packet_sizes = scheduler.next_transfer_packet_bytes();
    let mut descriptors = completed_packets(&packet_sizes);

    // Reconstruct the issue's 23 actual/expected mismatches. Here descriptor
    // lengths match the saved schedule; the new diagnostics distinguish those
    // two sources of "expected", which the original log could not do.
    for index in (0..15).chain(24..32) {
        descriptors[index].actual_length = 44 - descriptors[index].length;
    }
    assert_eq!(descriptors[0].actual_length, 20);
    assert_eq!(descriptors[0].length, 24);
    assert_eq!(descriptors[1].actual_length, 24);
    assert_eq!(descriptors[1].length, 20);
    assert_eq!(descriptors[24].actual_length, 24);
    assert_eq!(descriptors[24].length, 20);

    let error = validate_iso_packet_descriptors(&packet_sizes, &descriptors).unwrap_err();
    assert!(error.starts_with("isochronous transfer completed with packet errors:"));
    assert!(error.contains("requested_total=708 descriptor_total=708 actual_total=704"));
    assert!(error.contains("actual_minus_requested=-4"));
    assert!(error.contains("status_errors=0 descriptor_changes=0 length_mismatches=23"));
    assert!(error.contains("#0:requested=24/descriptor=24/actual=20/status=completed(0)"));
    assert!(error.contains("#1:requested=20/descriptor=20/actual=24/status=completed(0)"));
}

#[test]
fn test_equal_byte_totals_do_not_hide_swapped_packet_lengths() {
    let packet_sizes = [20, 24];
    let mut descriptors = completed_packets(&packet_sizes);
    descriptors[0].actual_length = 24;
    descriptors[1].actual_length = 20;

    let error = validate_iso_packet_descriptors(&packet_sizes, &descriptors).unwrap_err();
    assert!(error.contains("requested_total=44 descriptor_total=44 actual_total=44"));
    assert!(error.contains("actual_minus_requested=0"));
    assert!(error.contains("length_mismatches=2"));
}

#[test]
fn test_changed_descriptor_does_not_replace_the_saved_request() {
    let mut descriptors = completed_packets(&[20]);
    descriptors[0].length = 24;
    descriptors[0].actual_length = 24;

    let error = validate_iso_packet_descriptors(&[20], &descriptors).unwrap_err();
    assert!(error.contains("descriptor_changes=1 length_mismatches=1"));
    assert!(error.contains("requested=20/descriptor=24/actual=24"));
}

#[test]
fn test_changed_descriptor_is_rejected_even_when_actual_matches_the_request() {
    let mut descriptors = completed_packets(&[20]);
    descriptors[0].length = 24;

    let error = validate_iso_packet_descriptors(&[20], &descriptors).unwrap_err();
    assert!(error.contains("requested=20/descriptor=24/actual=20"));
}

#[test]
fn test_empty_short_unaligned_and_oversized_completions_are_rejected() {
    for actual_length in [0, 19, 20, 21, 28] {
        let mut descriptors = completed_packets(&[24]);
        descriptors[0].actual_length = actual_length;
        assert!(validate_iso_packet_descriptors(&[24], &descriptors).is_err());
    }
}

#[test]
fn test_zero_length_packets_are_only_accepted_when_requested() {
    assert_eq!(
        validate_iso_packet_descriptors(&[0, 4], &completed_packets(&[0, 4])),
        Ok(())
    );
}

#[test]
fn test_per_packet_errors_are_rejected_even_when_lengths_match() {
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
        let error = validate_iso_packet_descriptors(&[24], &descriptors).unwrap_err();
        assert!(error.contains("status_errors=1"));
        assert!(error.contains(&format!("status={}({})", label, status)));
    }
}

#[test]
fn test_packet_count_mismatches_are_rejected_and_identified() {
    let error = validate_iso_packet_descriptors(&[20, 24], &completed_packets(&[20])).unwrap_err();
    assert!(error.contains("packet_counts=requested:2,descriptors:1"));
    assert!(error.contains("#1:requested=24/descriptor=missing"));

    let error = validate_iso_packet_descriptors(&[20], &completed_packets(&[20, 24])).unwrap_err();
    assert!(error.contains("packet_counts=requested:1,descriptors:2"));
    assert!(error.contains("#1:requested=missing/descriptor=24/actual=24"));
}

#[test]
fn test_matching_schedules_across_rates_formats_and_service_intervals() {
    for sample_rate in [
        44_100, 48_000, 88_200, 96_000, 176_400, 192_000, 352_800, 384_000,
    ] {
        for channels in [1, 2] {
            for subslot_bytes in [1, 2, 3, 4] {
                for service_interval_us in [125, 250, 1_000] {
                    let mut scheduler = IsoPacketScheduler::new(
                        sample_rate,
                        channels * subslot_bytes,
                        service_interval_us,
                    );
                    for _ in 0..8 {
                        let packet_sizes = scheduler.next_transfer_packet_bytes();
                        assert_eq!(
                            validate_iso_packet_descriptors(
                                &packet_sizes,
                                &completed_packets(&packet_sizes),
                            ),
                            Ok(())
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
        let nominal = f64::from(sample_rate) * 125.0 / 1_000_000.0;
        assert!(scheduler.update_feedback_frames_per_packet(nominal * 0.9998));
        for _ in 0..64 {
            let packet_sizes = scheduler.next_transfer_packet_bytes();
            assert_eq!(
                validate_iso_packet_descriptors(&packet_sizes, &completed_packets(&packet_sizes)),
                Ok(())
            );
        }
    }
}

#[test]
fn test_reused_slot_cannot_validate_against_an_old_schedule() {
    let mut scheduler = IsoPacketScheduler::new(44_100, 4, 125);
    let old_packet_sizes = scheduler.next_transfer_packet_bytes();
    scheduler.next_transfer_packet_bytes();
    let current_packet_sizes = scheduler.next_transfer_packet_bytes();
    let descriptors = completed_packets(&current_packet_sizes);

    assert!(validate_iso_packet_descriptors(&old_packet_sizes, &descriptors).is_err());
    assert_eq!(
        validate_iso_packet_descriptors(&current_packet_sizes, &descriptors),
        Ok(())
    );
}

#[test]
fn test_failure_packet_dump_is_bounded_but_totals_cover_all_packets() {
    let packet_sizes = vec![24; 40];
    let mut descriptors = completed_packets(&packet_sizes);
    for packet in &mut descriptors {
        packet.actual_length = 20;
    }

    let error = validate_iso_packet_descriptors(&packet_sizes, &descriptors).unwrap_err();
    assert_eq!(error.matches('#').count(), 32);
    assert!(error.contains("#31:requested=24/descriptor=24/actual=20"));
    assert!(!error.contains("#32:"));
    assert!(error.contains("omitted_packets=8"));
    assert!(error.contains("requested_total=960 descriptor_total=960 actual_total=800"));
    assert!(error.contains("length_mismatches=40"));
}
