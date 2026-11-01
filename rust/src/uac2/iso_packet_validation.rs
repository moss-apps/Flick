use libusb1_sys::{
    constants::{
        LIBUSB_TRANSFER_CANCELLED, LIBUSB_TRANSFER_COMPLETED, LIBUSB_TRANSFER_ERROR,
        LIBUSB_TRANSFER_NO_DEVICE, LIBUSB_TRANSFER_OVERFLOW, LIBUSB_TRANSFER_STALL,
        LIBUSB_TRANSFER_TIMED_OUT,
    },
    libusb_iso_packet_descriptor,
};

const MAX_DIAGNOSTIC_PACKETS: usize = 32;

/// Validate ISO OUT completions against the exact submitted schedule, including
/// variable-size and feedback-paced packets. A nominal floor/ceiling size or an
/// equal byte total cannot establish that each submitted packet was transferred.
pub(crate) fn validate_iso_packet_descriptors(
    packet_sizes: &[usize],
    descriptors: &[libusb_iso_packet_descriptor],
) -> Result<(), String> {
    if packet_sizes.len() == descriptors.len()
        && packet_sizes
            .iter()
            .zip(descriptors)
            .all(|(requested, packet)| {
                packet.status == LIBUSB_TRANSFER_COMPLETED
                    && packet.actual_length == packet.length
                    && packet.actual_length as usize == *requested
            })
    {
        return Ok(());
    }

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

    Err(format!(
        "isochronous transfer completed with packet errors: \
         packet_counts=requested:{},descriptors:{} requested_total={} descriptor_total={} \
         actual_total={} actual_minus_requested={} status_errors={} descriptor_changes={} \
         length_mismatches={}; packet_results=[{}] omitted_packets={}",
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
    ))
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
