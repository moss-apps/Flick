use std::time::{Duration, Instant};

/// Time-based latch that absorbs transient payload-audit failures.
///
/// The PCM/DSD wire audits run on every isochronous transfer, so a single
/// silent, constant or fully-underrun buffer (fade, digital silence,
/// zero-padded underrun) would otherwise flip the bit-perfect claim off and
/// back on. Once verified, the latch only clears after the audit failed
/// continuously for the grace window.
#[derive(Debug, Clone)]
pub(crate) struct PayloadAuditLatch {
    verified: bool,
    constant_since: Option<Instant>,
    grace: Duration,
}

impl PayloadAuditLatch {
    pub(crate) const fn new(grace: Duration) -> Self {
        Self {
            verified: false,
            constant_since: None,
            grace,
        }
    }

    /// Records one audit result. Returns `Some(verified)` only when the
    /// latched state flips.
    pub(crate) fn observe(&mut self, ok: bool, now: Instant) -> Option<bool> {
        if ok {
            self.constant_since = None;
            if !self.verified {
                self.verified = true;
                return Some(true);
            }
            return None;
        }

        match self.constant_since {
            None => {
                self.constant_since = Some(now);
                None
            }
            Some(since) => {
                if self.verified && now.duration_since(since) >= self.grace {
                    self.verified = false;
                    self.constant_since = Some(now);
                    return Some(false);
                }
                None
            }
        }
    }

    pub(crate) fn is_verified(&self) -> bool {
        self.verified
    }

    pub(crate) fn constant_for(&self, now: Instant) -> Option<Duration> {
        self.constant_since.map(|since| now.duration_since(since))
    }

    pub(crate) fn reset(&mut self) {
        self.verified = false;
        self.constant_since = None;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn latch() -> PayloadAuditLatch {
        PayloadAuditLatch::new(Duration::from_millis(1500))
    }

    #[test]
    fn first_success_verifies() {
        let mut latch = latch();
        let now = Instant::now();

        assert_eq!(latch.observe(true, now), Some(true));
        assert!(latch.is_verified());
    }

    #[test]
    fn single_failure_keeps_verification() {
        let mut latch = latch();
        let start = Instant::now();
        latch.observe(true, start);

        assert_eq!(latch.observe(false, start + Duration::from_millis(50)), None);
        assert_eq!(latch.observe(false, start + Duration::from_millis(400)), None);
        assert!(latch.is_verified());
    }

    #[test]
    fn sustained_failure_clears_after_grace() {
        let mut latch = latch();
        let start = Instant::now();
        latch.observe(true, start);
        latch.observe(false, start + Duration::from_millis(100));

        assert_eq!(
            latch.observe(false, start + Duration::from_millis(1500)),
            None
        );
        assert_eq!(
            latch.observe(false, start + Duration::from_millis(1700)),
            Some(false)
        );
        assert!(!latch.is_verified());
    }

    #[test]
    fn recovery_reverifies() {
        let mut latch = latch();
        let start = Instant::now();
        latch.observe(true, start);
        latch.observe(false, start + Duration::from_millis(100));
        latch.observe(false, start + Duration::from_millis(2000));

        assert_eq!(latch.observe(true, start + Duration::from_millis(2100)), Some(true));
        assert!(latch.is_verified());
    }

    #[test]
    fn recovery_before_grace_cancels_clearing() {
        let mut latch = latch();
        let start = Instant::now();
        latch.observe(true, start);
        latch.observe(false, start + Duration::from_millis(100));
        latch.observe(true, start + Duration::from_millis(500));
        latch.observe(false, start + Duration::from_millis(600));

        assert_eq!(latch.observe(false, start + Duration::from_millis(1500)), None);
        assert!(latch.is_verified());
    }

    #[test]
    fn failure_before_first_success_never_flips() {
        let mut latch = latch();
        let start = Instant::now();

        assert_eq!(latch.observe(false, start), None);
        assert_eq!(latch.observe(false, start + Duration::from_secs(5)), None);
        assert!(!latch.is_verified());
    }

    #[test]
    fn reset_clears_state() {
        let mut latch = latch();
        let now = Instant::now();
        latch.observe(true, now);
        latch.reset();

        assert!(!latch.is_verified());
        assert_eq!(latch.constant_for(now), None);
        assert_eq!(latch.observe(true, now), Some(true));
    }
}
