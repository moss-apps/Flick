use libusb1_sys::{
    constants::{
        LIBUSB_TRANSFER_CANCELLED, LIBUSB_TRANSFER_COMPLETED, LIBUSB_TRANSFER_ERROR,
        LIBUSB_TRANSFER_NO_DEVICE, LIBUSB_TRANSFER_OVERFLOW, LIBUSB_TRANSFER_STALL,
        LIBUSB_TRANSFER_TIMED_OUT,
    },
    libusb_iso_packet_descriptor,
};

const MAX_DIAGNOSTIC_PACKETS: usize = 32;

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub(crate) struct CompletionStats {
    pub short_packets: u64,
    pub zero_packets: u64,
    /// Submitted PCM frames that could not be credited as delivered.
    pub lost_frames: u64,
}

/// Exact validation for DSD, DoP and diagnostic probes. Totals cannot
/// establish that each packet retained its submitted length and boundaries.
pub(crate) fn validate_iso_packet_descriptors(
    packet_sizes: &[usize],
    descriptors: &[libusb_iso_packet_descriptor],
) -> Result<(), String> {
    if packet_sizes.len() == descriptors.len()
        && packet_sizes
            .iter()
            .zip(descriptors)
            .all(|(&requested, packet)| {
                packet.status == LIBUSB_TRANSFER_COMPLETED
                    && packet.length as usize == requested
                    && packet.actual_length == packet.length
            })
    {
        Ok(())
    } else {
        Err(format_diagnostics(
            packet_sizes,
            descriptors,
            "expected exact packet completions",
        ))
    }
}

/// Account for a completed or timed-out PCM OUT transfer. Packet buffers have
/// fixed offsets: a short packet cannot be made up by a larger neighbor. Only a
/// whole-frame shortfall within the original descriptor is recoverable.
///
/// linux_usbfs copies each retired URB's results before issuing the timeout
/// callback. usbfs maps packet cancellations to COMPLETED with zero bytes.
/// On timeout only full, completed packets are credited. A generic packet
/// error is distinct from cancellation and remains fatal.
pub(crate) fn account_pcm_completion(
    packet_sizes: &[usize],
    descriptors: &[libusb_iso_packet_descriptor],
    bytes_per_frame: usize,
    timed_out: bool,
) -> Result<CompletionStats, String> {
    let invalid = |reason| format_diagnostics(packet_sizes, descriptors, reason);
    if packet_sizes.len() != descriptors.len() {
        return Err(invalid("packet count changed"));
    }
    if bytes_per_frame == 0 {
        return Err(invalid("invalid PCM frame size"));
    }

    let mut stats = CompletionStats::default();
    for (&requested, packet) in packet_sizes.iter().zip(descriptors) {
        let actual = packet.actual_length as usize;
        if packet.length as usize != requested {
            return Err(invalid("descriptor length changed"));
        }
        if packet.status == LIBUSB_TRANSFER_NO_DEVICE {
            return Err(invalid("USB DAC disconnected"));
        }
        let cancelled_by_timeout = timed_out
            && actual == 0
            && matches!(
                packet.status,
                LIBUSB_TRANSFER_CANCELLED | LIBUSB_TRANSFER_TIMED_OUT
            );
        if packet.status != LIBUSB_TRANSFER_COMPLETED && !cancelled_by_timeout {
            return Err(invalid(
                "packet status is not completed or cancelled by timeout",
            ));
        }
        if actual > requested {
            return Err(invalid("packet exceeds its submitted length"));
        }
        if requested % bytes_per_frame != 0 || actual % bytes_per_frame != 0 {
            return Err(invalid("packet is not frame-aligned"));
        }
        if actual == requested {
            continue;
        }

        if actual == 0 {
            stats.zero_packets += 1;
        } else {
            stats.short_packets += 1;
        }
        let missing = if timed_out {
            requested
        } else {
            requested - actual
        };
        stats.lost_frames += (missing / bytes_per_frame) as u64;
    }

    Ok(stats)
}

fn format_diagnostics(
    packet_sizes: &[usize],
    descriptors: &[libusb_iso_packet_descriptor],
    reason: &str,
) -> String {
    // Only allocate/format diagnostics on failure. These are sums of individual
    // packet lengths: libusb_transfer.actual_length is not meaningful for ISO.
    let requested_total: u64 = packet_sizes.iter().map(|length| *length as u64).sum();
    let descriptor_total: u64 = descriptors
        .iter()
        .map(|packet| u64::from(packet.length))
        .sum();
    let actual_total: u64 = descriptors
        .iter()
        .map(|packet| u64::from(packet.actual_length))
        .sum();
    let status_errors = descriptors
        .iter()
        .filter(|packet| packet.status != LIBUSB_TRANSFER_COMPLETED)
        .count();
    let descriptor_changes = packet_sizes
        .iter()
        .zip(descriptors)
        .filter(|(requested, packet)| **requested != packet.length as usize)
        .count();
    let length_mismatches = packet_sizes
        .iter()
        .zip(descriptors)
        .filter(|(requested, packet)| {
            packet.actual_length != packet.length || packet.actual_length as usize != **requested
        })
        .count();
    let packet_count = packet_sizes.len().max(descriptors.len());
    let packet_results = (0..packet_count.min(MAX_DIAGNOSTIC_PACKETS))
        .map(|index| {
            let requested = packet_sizes
                .get(index)
                .map(|length| length.to_string())
                .unwrap_or_else(|| "missing".to_string());
            match descriptors.get(index) {
                Some(packet) => format!(
                    "#{}:requested={}/descriptor={}/actual={}/status={}({})",
                    index,
                    requested,
                    packet.length,
                    packet.actual_length,
                    iso_transfer_status_label(packet.status),
                    packet.status,
                ),
                None => format!("#{}:requested={}/descriptor=missing", index, requested),
            }
        })
        .collect::<Vec<_>>();

    format!(
        "isochronous transfer completed with packet errors: {}; \
         packet_counts=requested:{},descriptors:{} \
         requested_total={} descriptor_total={} actual_total={} actual_minus_requested={} \
         status_errors={} descriptor_changes={} length_mismatches={}; \
         packet_results=[{}] omitted_packets={}",
        reason,
        packet_sizes.len(),
        descriptors.len(),
        requested_total,
        descriptor_total,
        actual_total,
        i128::from(actual_total) - i128::from(requested_total),
        status_errors,
        descriptor_changes,
        length_mismatches,
        packet_results.join(","),
        packet_count.saturating_sub(MAX_DIAGNOSTIC_PACKETS),
    )
}

pub(crate) fn iso_transfer_status_label(status: i32) -> &'static str {
    match status {
        LIBUSB_TRANSFER_COMPLETED => "completed",
        LIBUSB_TRANSFER_TIMED_OUT => "timed_out",
        LIBUSB_TRANSFER_STALL => "stall",
        LIBUSB_TRANSFER_NO_DEVICE => "no_device",
        LIBUSB_TRANSFER_OVERFLOW => "overflow",
        LIBUSB_TRANSFER_CANCELLED => "cancelled",
        LIBUSB_TRANSFER_ERROR => "error",
        _ => "unknown",
    }
}
