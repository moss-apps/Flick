use libusb1_sys::{
    constants::{
        LIBUSB_TRANSFER_CANCELLED, LIBUSB_TRANSFER_COMPLETED, LIBUSB_TRANSFER_ERROR,
        LIBUSB_TRANSFER_NO_DEVICE, LIBUSB_TRANSFER_OVERFLOW, LIBUSB_TRANSFER_STALL,
        LIBUSB_TRANSFER_TIMED_OUT,
    },
    libusb_iso_packet_descriptor,
};

const MAX_DIAGNOSTIC_PACKETS: usize = 32;

/// Legal packet-size envelope for one isochronous service interval.
///
/// At 44.1 kHz on a 125 µs microframe the average packet is 5.5125 frames, so
/// the host must alternate 5-frame and 6-frame packets. A completion may carry
/// either size (or exactly what this transfer requested, when feedback pacing
/// moved the schedule). Demanding the exact submitted length turns normal
/// repacketisation and FIFO backpressure into a fatal stream error.
#[derive(Debug, Clone, Copy)]
pub(crate) struct PacketAcceptance {
    legal_sizes: [usize; 2],
    bytes_per_frame: usize,
}

impl PacketAcceptance {
    pub(crate) fn new(sample_rate: u32, service_interval_us: u32, bytes_per_frame: usize) -> Self {
        let bytes_per_frame = bytes_per_frame.max(1);
        let interval = service_interval_us.max(1) as u64;
        let scaled = u64::from(sample_rate) * interval;
        let lo_frames = scaled / 1_000_000;
        let hi_frames = scaled.div_ceil(1_000_000);
        let legal_sizes = [
            lo_frames as usize * bytes_per_frame,
            hi_frames as usize * bytes_per_frame,
        ];
        Self {
            legal_sizes,
            bytes_per_frame,
        }
    }

    /// Accept only the exact submitted length. Used by diagnostic probes that
    /// have no stream rate to derive an envelope from.
    pub(crate) fn exact() -> Self {
        Self {
            legal_sizes: [0, 0],
            bytes_per_frame: 1,
        }
    }

    pub(crate) fn legal_sizes(&self) -> [usize; 2] {
        self.legal_sizes
    }

    pub(crate) fn bytes_per_frame(&self) -> usize {
        self.bytes_per_frame
    }

    fn is_legal_size(&self, actual_length: usize, requested: usize) -> bool {
        if actual_length == requested {
            return true;
        }
        self.legal_sizes[0] != 0
            && (actual_length == self.legal_sizes[0] || actual_length == self.legal_sizes[1])
    }

    fn is_frame_aligned(&self, actual_length: usize) -> bool {
        actual_length % self.bytes_per_frame == 0
    }
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub(crate) struct CompletionStats {
    pub short_packets: usize,
    pub zero_packets: usize,
    pub descriptor_rewrites: usize,
    pub shortfall_frames: u64,
}

/// Validate ISO OUT completions against the legal packet envelope for the
/// stream's service interval.
///
/// A completed packet shorter (or, after repacketisation, longer) than the
/// submitted length is timing data, not a transport failure: only a non-zero
/// status, a length above the endpoint packet, a non-frame-aligned length, or
/// a total that exceeds what was submitted is an error. Shortfall is returned
/// so the caller can account for it without stopping playback.
pub(crate) fn validate_iso_packet_descriptors(
    packet_sizes: &[usize],
    descriptors: &[libusb_iso_packet_descriptor],
    acceptance: PacketAcceptance,
) -> Result<CompletionStats, String> {
    if packet_sizes.len() != descriptors.len() {
        return Err(format_diagnostics(
            packet_sizes,
            descriptors,
            acceptance,
            "packet count changed",
        ));
    }

    let mut stats = CompletionStats::default();
    for (requested, packet) in packet_sizes.iter().zip(descriptors) {
        if packet.status != LIBUSB_TRANSFER_COMPLETED {
            return Err(format_diagnostics(
                packet_sizes,
                descriptors,
                acceptance,
                "packet status is not completed",
            ));
        }

        let requested = *requested;
        let actual = packet.actual_length as usize;

        if packet.length as usize != requested {
            stats.descriptor_rewrites = stats.descriptor_rewrites.saturating_add(1);
        }

        if actual == 0 {
            stats.zero_packets = stats.zero_packets.saturating_add(1);
            continue;
        }

        if !acceptance.is_frame_aligned(actual) {
            return Err(format_diagnostics(
                packet_sizes,
                descriptors,
                acceptance,
                "packet is not frame-aligned",
            ));
        }

        // A repacketising host controller may move a packet's bytes into a
        // neighbouring microframe of the same URB, so `actual` can be the other
        // legal size instead of exactly `requested`. The transfer total is
        // checked below and can never exceed what was submitted.
        if !acceptance.is_legal_size(actual, requested) {
            return Err(format_diagnostics(
                packet_sizes,
                descriptors,
                acceptance,
                "packet length is outside the legal envelope",
            ));
        }

        if actual != requested {
            stats.short_packets = stats.short_packets.saturating_add(1);
        }
    }

    // Repacketisation may shuffle bytes between packets of one URB, but the
    // whole transfer can never deliver more than it submitted.
    let requested_total: usize = packet_sizes.iter().copied().sum();
    let actual_total: usize = descriptors
        .iter()
        .map(|packet| packet.actual_length as usize)
        .sum();
    if actual_total > requested_total {
        return Err(format_diagnostics(
            packet_sizes,
            descriptors,
            acceptance,
            "transfer exceeds the submitted byte total",
        ));
    }

    stats.shortfall_frames =
        ((requested_total - actual_total) / acceptance.bytes_per_frame.max(1)) as u64;

    Ok(stats)
}

fn format_diagnostics(
    packet_sizes: &[usize],
    descriptors: &[libusb_iso_packet_descriptor],
    acceptance: PacketAcceptance,
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
        .filter(|(requested, packet)| packet.actual_length as usize != **requested)
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
         packet_counts=requested:{},descriptors:{} legal={}/{} frame={} \
         requested_total={} descriptor_total={} actual_total={} actual_minus_requested={} \
         status_errors={} descriptor_changes={} length_mismatches={}; \
         packet_results=[{}] omitted_packets={}",
        reason,
        packet_sizes.len(),
        descriptors.len(),
        acceptance.legal_sizes[0],
        acceptance.legal_sizes[1],
        acceptance.bytes_per_frame,
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
