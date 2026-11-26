use std::time::Instant;

use libusb1_sys::constants::LIBUSB_TRANSFER_COMPLETED;

#[derive(Debug, Clone, Copy)]
pub(crate) struct IsoCompletionDiagnostic {
    pub status: i32,
    pub completed_at: Instant,
    pub packets_valid: bool,
}

#[derive(Debug)]
pub(crate) struct IsoSlotDiagnostic {
    pub slot_index: usize,
    pub generation: u64,
    pub pending_at_poll: bool,
    pub submitted_age_us: Option<u64>,
    pub queued_frames: u64,
    pub submitted_bytes: usize,
    pub completion: Option<IsoCompletionDiagnostic>,
}

pub(crate) struct IsoBatchSummary {
    pub completion_count: usize,
    pub packet_validated_count: usize,
    pub latest_packet_validated_at: Option<Instant>,
}

/// Summarize every callback already delivered by libusb before the event-loop
/// stops processing the batch. The top-level COMPLETED status alone is not
/// enough: each packet must have completed with its exact submitted length.
pub(crate) fn summarize_iso_batch(
    slots: &[IsoSlotDiagnostic],
    prior_packet_validated_at: Option<Instant>,
) -> IsoBatchSummary {
    let mut completion_count = 0;
    let mut packet_validated_count = 0;
    let mut latest_packet_validated_at = prior_packet_validated_at;

    for slot in slots {
        let Some(completion) = slot.completion else {
            continue;
        };
        completion_count += 1;
        if completion.status != LIBUSB_TRANSFER_COMPLETED || !completion.packets_valid {
            continue;
        }
        packet_validated_count += 1;
        latest_packet_validated_at = latest_packet_validated_at.max(Some(completion.completed_at));
    }

    IsoBatchSummary {
        completion_count,
        packet_validated_count,
        latest_packet_validated_at,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use libusb1_sys::constants::LIBUSB_TRANSFER_TIMED_OUT;
    use std::time::Duration;

    fn slot(slot_index: usize, completion: Option<IsoCompletionDiagnostic>) -> IsoSlotDiagnostic {
        IsoSlotDiagnostic {
            slot_index,
            generation: 1,
            pending_at_poll: completion.is_none(),
            submitted_age_us: Some(4_000),
            queued_frames: 384,
            submitted_bytes: 1_152,
            completion,
        }
    }

    fn completion(
        status: i32,
        completed_at: Instant,
        packets_valid: bool,
    ) -> IsoCompletionDiagnostic {
        IsoCompletionDiagnostic {
            status,
            completed_at,
            packets_valid,
        }
    }

    #[test]
    fn mixed_batch_counts_only_packet_validated_completions_and_keeps_latest() {
        let base = Instant::now();
        let slots = [
            slot(0, Some(completion(LIBUSB_TRANSFER_TIMED_OUT, base, false))),
            slot(
                1,
                Some(completion(
                    LIBUSB_TRANSFER_COMPLETED,
                    base + Duration::from_millis(2),
                    true,
                )),
            ),
            slot(2, Some(completion(LIBUSB_TRANSFER_COMPLETED, base, true))),
            slot(
                3,
                Some(completion(
                    LIBUSB_TRANSFER_COMPLETED,
                    base + Duration::from_millis(3),
                    false,
                )),
            ),
            slot(4, None),
        ];

        let summary = summarize_iso_batch(&slots, None);

        assert_eq!(summary.completion_count, 4);
        assert_eq!(summary.packet_validated_count, 2);
        assert_eq!(
            summary.latest_packet_validated_at,
            Some(base + Duration::from_millis(2))
        );
    }

    #[test]
    fn older_valid_completion_does_not_replace_prior_timestamp() {
        let base = Instant::now();
        let prior = base + Duration::from_millis(10);
        let slots = [slot(
            0,
            Some(completion(LIBUSB_TRANSFER_COMPLETED, base, true)),
        )];

        let summary = summarize_iso_batch(&slots, Some(prior));

        assert_eq!(summary.completion_count, 1);
        assert_eq!(summary.packet_validated_count, 1);
        assert_eq!(summary.latest_packet_validated_at, Some(prior));
    }
}
