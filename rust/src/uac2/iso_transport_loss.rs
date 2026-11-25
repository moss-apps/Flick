//! Honest, bounded accounting for isochronous OUT audio that never reached the DAC.
//!
//! Many URBs are in flight at once, so the audio behind a failed URB is already
//! queued and cannot be re-sent without playing out of order. Loss is therefore
//! a discontinuity: it is counted exactly, latched so the stream can no longer
//! claim bit-perfect output, and bounded so a broken transport stops the stream
//! instead of playing glitched audio forever.
//!
//! Everything here is plain data so the decisions can be unit-tested without
//! libusb. `android_direct::run_usb_output_loop` only feeds it URB outcomes and
//! acts on the verdicts.

use crate::uac2::iso_packet_validation::CompletionStats;
use std::fmt;

/// Frame unit used by the PCM ring buffer and `consumer_frames`.
///
/// PCM and DoP queue one ring frame per transport frame (`slot * channels`
/// bytes). Native DSD queues one ring sample per DSD byte, so a ring frame is
/// one byte per channel while a transport frame is `subslot_size` bytes per
/// channel. Dividing lost bytes by the transport frame size would under-count
/// native DSD loss by `subslot_size`.
pub(crate) fn ring_bytes_per_frame(
    native_dsd: bool,
    channels: usize,
    transport_bytes_per_frame: usize,
) -> usize {
    if native_dsd {
        channels.max(1)
    } else {
        transport_bytes_per_frame.max(1)
    }
}

/// Ring frames of audio that `budget_ms` represents at the ring rate.
pub(crate) fn lost_frame_budget(ring_rate_hz: u32, budget_ms: u64) -> u64 {
    u64::from(ring_rate_hz).saturating_mul(budget_ms) / 1_000
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) struct LossLimits {
    /// More than this many lossy URBs in a row is fatal.
    pub max_consecutive_lossy_urbs: u32,
    /// More than this many lost ring frames since stream start is fatal.
    pub max_lost_frames: u64,
}

/// What one completed data URB cost, in ring frames.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub(crate) struct UrbLoss {
    pub timed_out: bool,
    pub lost_frames: u64,
    pub short_packets: u64,
    pub zero_packets: u64,
}

impl UrbLoss {
    /// Map a completed or timed-out URB's descriptor accounting into ring
    /// frames.
    pub(crate) fn from_completion(
        stats: &CompletionStats,
        timed_out: bool,
        ring_bytes_per_frame: usize,
    ) -> Self {
        Self {
            timed_out,
            lost_frames: stats.lost_ring_frames(ring_bytes_per_frame),
            short_packets: stats.short_packets as u64,
            zero_packets: stats.zero_packets as u64,
        }
    }

    /// A URB is lossy if it timed out or failed to deliver any of its frames.
    /// Short packets alone are not loss: a swap of the two legal packet sizes
    /// inside one URB delivers every byte.
    pub(crate) fn is_lossy(&self) -> bool {
        self.timed_out || self.lost_frames > 0
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum LossLimit {
    ConsecutiveLossyUrbs { count: u32, limit: u32 },
    CumulativeLostFrames { lost: u64, limit: u64 },
}

impl fmt::Display for LossLimit {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::ConsecutiveLossyUrbs { count, limit } => write!(
                f,
                "{} consecutive isochronous transfers lost audio or timed out (limit {})",
                count, limit
            ),
            Self::CumulativeLostFrames { lost, limit } => write!(
                f,
                "{} audio frames lost since stream start exceeds the limit of {}",
                lost, limit
            ),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) struct UrbVerdict {
    pub lossy: bool,
    /// Ring frames the DAC actually took from this URB. Lost frames are never
    /// included.
    pub consumed_frames: u64,
    /// This URB is the first to lose frames on the stream.
    pub newly_latched: bool,
    pub fatal: Option<LossLimit>,
}

impl UrbVerdict {
    /// Only a lossless URB counts toward the "stream is stable" threshold. A
    /// COMPLETED status is not enough: an all-zero-length completion reports
    /// COMPLETED too.
    pub(crate) fn counts_as_successful_transfer(&self) -> bool {
        !self.lossy
    }
}

#[derive(Debug)]
pub(crate) struct LossTracker {
    limits: LossLimits,
    consecutive_lossy_urbs: u32,
    lost_frames: u64,
    short_packets: u64,
    zero_packets: u64,
    data_urb_timeouts: u64,
    latched: bool,
}

impl LossTracker {
    pub(crate) fn new(limits: LossLimits) -> Self {
        Self {
            limits,
            consecutive_lossy_urbs: 0,
            lost_frames: 0,
            short_packets: 0,
            zero_packets: 0,
            data_urb_timeouts: 0,
            latched: false,
        }
    }

    /// Fold one completed data URB into the stream totals.
    ///
    /// A lossy URB never resets the consecutive counter, whatever else it did:
    /// an all-zero-length completion still reports COMPLETED, and must not
    /// look like a healthy transfer.
    pub(crate) fn record(&mut self, queued_frames: u64, urb: UrbLoss) -> UrbVerdict {
        self.short_packets = self.short_packets.saturating_add(urb.short_packets);
        self.zero_packets = self.zero_packets.saturating_add(urb.zero_packets);
        if urb.timed_out {
            self.data_urb_timeouts = self.data_urb_timeouts.saturating_add(1);
        }

        let mut newly_latched = false;
        if urb.lost_frames > 0 {
            newly_latched = !self.latched;
            self.latched = true;
            self.lost_frames = self.lost_frames.saturating_add(urb.lost_frames);
        }

        let lossy = urb.is_lossy();
        self.consecutive_lossy_urbs = if lossy {
            self.consecutive_lossy_urbs.saturating_add(1)
        } else {
            0
        };

        let fatal = if self.consecutive_lossy_urbs > self.limits.max_consecutive_lossy_urbs {
            Some(LossLimit::ConsecutiveLossyUrbs {
                count: self.consecutive_lossy_urbs,
                limit: self.limits.max_consecutive_lossy_urbs,
            })
        } else if self.lost_frames > self.limits.max_lost_frames {
            Some(LossLimit::CumulativeLostFrames {
                lost: self.lost_frames,
                limit: self.limits.max_lost_frames,
            })
        } else {
            None
        };

        UrbVerdict {
            lossy,
            consumed_frames: queued_frames.saturating_sub(urb.lost_frames),
            newly_latched,
            fatal,
        }
    }

    /// True once any frame has been lost on this stream. Never cleared; a new
    /// stream gets a new tracker.
    pub(crate) fn is_latched(&self) -> bool {
        self.latched
    }

    pub(crate) fn consecutive_lossy_urbs(&self) -> u32 {
        self.consecutive_lossy_urbs
    }

    pub(crate) fn lost_frames(&self) -> u64 {
        self.lost_frames
    }

    pub(crate) fn short_packets(&self) -> u64 {
        self.short_packets
    }

    pub(crate) fn zero_packets(&self) -> u64 {
        self.zero_packets
    }

    pub(crate) fn data_urb_timeouts(&self) -> u64 {
        self.data_urb_timeouts
    }
}

/// Rate limiter for loss log lines: the first `burst` events are admitted
/// immediately, after that at most one per `min_interval_ms`. It keys on
/// elapsed time rather than a cumulative count, so a count that jumps past a
/// multiple (several packets per URB) cannot silence it.
#[derive(Debug)]
pub(crate) struct LossLogGate {
    burst: u32,
    min_interval_ms: u64,
    admitted: u32,
    last_admitted_ms: u64,
}

impl LossLogGate {
    pub(crate) const fn new(burst: u32, min_interval_ms: u64) -> Self {
        Self {
            burst,
            min_interval_ms,
            admitted: 0,
            last_admitted_ms: 0,
        }
    }

    pub(crate) fn admit(&mut self, now_ms: u64) -> bool {
        let due = self.admitted < self.burst
            || now_ms.saturating_sub(self.last_admitted_ms) >= self.min_interval_ms;
        if due {
            self.admitted = self.admitted.saturating_add(1);
            self.last_admitted_ms = now_ms;
        }
        due
    }
}
