#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) struct IsoQueueGeometry {
    pub(crate) packets_per_transfer: usize,
    pub(crate) transfer_slots: usize,
    pub(crate) stable_transfers: usize,
}

impl IsoQueueGeometry {
    pub(crate) fn for_stream(service_interval_us: u32, dsd_on_wire: bool) -> Self {
        // On a OnePlus 15 + DC04U, 125-us PCM stalled with 256 packets in
        // flight. Both 8 x 16 and 16 x 8 (packets x slots) worked with 128
        // packets queued, but 16 x 8 completed half as many URBs per second
        // and used less CPU. This is a device result, not a controller limit.
        // Keep the original geometry for other intervals and native DSD/DoP.
        if service_interval_us == 125 && !dsd_on_wire {
            return Self {
                packets_per_transfer: 16,
                transfer_slots: 8,
                // Keep the old 256 ms observation window (64 x 32 x 125 us).
                stable_transfers: 128,
            };
        }
        Self {
            packets_per_transfer: (4_000 / service_interval_us.max(1)).clamp(16, 32) as usize,
            transfer_slots: 8,
            stable_transfers: 64,
        }
    }
}

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
    #[cfg(test)]
    pub(crate) fn new(sample_rate: u32, bytes_per_frame: usize, service_interval_us: u32) -> Self {
        Self::with_geometry(
            sample_rate,
            bytes_per_frame,
            service_interval_us,
            IsoQueueGeometry::for_stream(service_interval_us, false),
        )
    }

    pub(crate) fn with_geometry(
        sample_rate: u32,
        bytes_per_frame: usize,
        service_interval_us: u32,
        geometry: IsoQueueGeometry,
    ) -> Self {
        Self {
            sample_rate,
            service_interval_us,
            nominal_remainder: 0,
            bytes_per_frame,
            packets_per_transfer: geometry.packets_per_transfer,
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
