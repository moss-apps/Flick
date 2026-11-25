#[derive(Debug, Clone)]
pub(crate) struct IsoPacketScheduler {
    sample_rate: u32,
    service_interval_us: u32,
    nominal_remainder: u64,
    bytes_per_frame: usize,
    packets_per_transfer: usize,
    feedback_frames_per_packet: Option<f64>,
    feedback_remainder: f64,
}

impl IsoPacketScheduler {
    pub(crate) fn new(sample_rate: u32, bytes_per_frame: usize, service_interval_us: u32) -> Self {
        // 16 packets per URB at 125 us = 2 ms per transfer, 8 queued = 16 ms
        // in flight (see ANDROID_USB_TRANSFER_QUEUE_DEPTH for the limit this
        // respects). The output thread's CPU cost follows packets per URB:
        // 16 measured about 30% below 8 on a OnePlus 15, with the same audio
        // in flight. BitChord issue 1485 reports a stall on another Snapdragon
        // phone at a different in-flight count, so the limit is
        // device-specific.
        let packets_per_transfer = 16usize;

        Self {
            sample_rate,
            service_interval_us,
            nominal_remainder: 0,
            bytes_per_frame,
            packets_per_transfer,
            feedback_frames_per_packet: None,
            feedback_remainder: 0.0,
        }
    }

    pub(crate) fn packets_per_transfer(&self) -> usize {
        self.packets_per_transfer
    }

    pub(crate) fn next_transfer_packet_bytes(&mut self) -> Vec<usize> {
        (0..self.packets_per_transfer)
            .map(|_| self.next_packet_bytes())
            .collect()
    }

    /// Update packet timing from a device feedback report.
    ///
    /// Returns false when the report is non-finite, non-positive, or too far
    /// from nominal to be a real DAC clock. A 2% band comfortably covers USB
    /// clock tolerance (typically hundreds of ppm) while rejecting decode
    /// errors and malformed feedback values that would otherwise cause a large
    /// audio discontinuity.
    pub(crate) fn update_feedback_frames_per_packet(&mut self, frames_per_packet: f64) -> bool {
        if !frames_per_packet.is_finite() || frames_per_packet <= 0.0 {
            return false;
        }

        let nominal = self.nominal_frames_per_packet().max(0.001);
        if frames_per_packet < nominal * 0.98 || frames_per_packet > nominal * 1.02 {
            return false;
        }

        self.feedback_frames_per_packet = Some(match self.feedback_frames_per_packet {
            Some(previous) => previous * 0.8 + frames_per_packet * 0.2,
            None => frames_per_packet,
        });
        true
    }

    pub(crate) fn lock_to_nominal_packet_timing(&mut self) {
        self.feedback_frames_per_packet = None;
        self.feedback_remainder = 0.0;
    }

    fn nominal_frames_per_packet(&self) -> f64 {
        self.sample_rate as f64 * self.service_interval_us as f64 / 1_000_000.0
    }

    fn next_packet_bytes(&mut self) -> usize {
        let frames = if let Some(feedback_frames_per_packet) = self.feedback_frames_per_packet {
            self.feedback_remainder += feedback_frames_per_packet;
            let frames = self.feedback_remainder.floor() as usize;
            self.feedback_remainder -= frames as f64;
            frames
        } else {
            let total = self.nominal_remainder
                + (self.sample_rate as u64 * self.service_interval_us as u64);
            let frames = (total / 1_000_000) as usize;
            self.nominal_remainder = total % 1_000_000;
            frames
        };
        frames.saturating_mul(self.bytes_per_frame)
    }
}
