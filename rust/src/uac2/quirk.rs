use once_cell::sync::Lazy;
use parking_lot::RwLock;
use rusb::SyncType;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UsbAudioQuirk {
    IgnoreBrokenClockSource,
    ForceAsyncFeedback,
    DisableNativeDsd,
    IgnoreInvalidSampleRate,
    Force48kHzOnly,
    RequireVerifiedRate,
    SettleDelayMs(u64),
    PreferPadded24BitTransport,
    DsdSubslotSize(u8),
    DsdBigEndian,
    DsdBitReverse,
    ForceIsochronousSyncType(SyncType),
    SkipFeedbackValidation,
    AssumeSynchEndpointZero,
    IgnoreMuteControl,
    IgnoreVolumeControl,
    PreferInterfaceAlt(u8),
    SkipClockValidation,
    RequireInterfaceClaim(u8),
}

#[derive(Debug, Clone)]
pub struct QuirkEntry {
    pub vendor_id: u16,
    pub product_id: u16,
    pub product_name_contains: &'static str,
    pub quirks: &'static [UsbAudioQuirk],
}

pub struct QuirkDatabase {
    entries: RwLock<Vec<QuirkEntry>>,
}

impl QuirkDatabase {
    pub fn new() -> Self {
        Self {
            entries: RwLock::new(Vec::new()),
        }
    }

    pub fn add(&self, vendor_id: u16, product_id: u16, product_name_contains: &'static str, quirks: &'static [UsbAudioQuirk]) {
        self.entries.write().push(QuirkEntry {
            vendor_id,
            product_id,
            product_name_contains,
            quirks,
        });
    }

    pub fn lookup(&self, vendor_id: u16, product_id: u16, product_name: &str) -> Vec<UsbAudioQuirk> {
        let mut result = Vec::new();
        for entry in self.entries.read().iter() {
            if entry.vendor_id == vendor_id
                && entry.product_id == product_id
                && (entry.product_name_contains.is_empty() || product_name.contains(entry.product_name_contains))
            {
                result.extend_from_slice(entry.quirks);
            }
        }
        result
    }

    pub fn has_quirk(&self, vendor_id: u16, product_id: u16, product_name: &str, quirk: UsbAudioQuirk) -> bool {
        self.lookup(vendor_id, product_id, product_name)
            .iter()
            .any(|q| *q == quirk)
    }

    pub fn find_quirk_by_type(&self, vendor_id: u16, product_id: u16, product_name: &str, quirk: UsbAudioQuirk) -> bool {
        self.has_quirk(vendor_id, product_id, product_name, quirk)
    }
}

pub static QUIRK_DATABASE: Lazy<QuirkDatabase> = Lazy::new(|| {
    let db = QuirkDatabase::new();

    // MOONDROP Dawn Pro: dual CS43131, XMOS-style bridge, DSD_U32_BE
    db.add(
        12230, // vendor_id 0x2FC6
        61546, // product_id 0xF09A
        "MOONDROP Dawn Pro",
        &[
            UsbAudioQuirk::RequireVerifiedRate,
            UsbAudioQuirk::SettleDelayMs(50),
            UsbAudioQuirk::PreferPadded24BitTransport,
            UsbAudioQuirk::DsdSubslotSize(4),
            UsbAudioQuirk::DsdBigEndian,
        ],
    );

    db
});

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dawn_pro_quirks_found_by_vid_pid() {
        let quirks = QUIRK_DATABASE.lookup(12230, 61546, "MOONDROP Dawn Pro");
        assert!(quirks.contains(&UsbAudioQuirk::RequireVerifiedRate));
        assert!(quirks.contains(&UsbAudioQuirk::PreferPadded24BitTransport));
        assert!(quirks.contains(&UsbAudioQuirk::DsdBigEndian));
    }

    #[test]
    fn unknown_device_returns_empty() {
        let quirks = QUIRK_DATABASE.lookup(0x0000, 0x0000, "Unknown");
        assert!(quirks.is_empty());
    }

    #[test]
    fn has_quirk_check() {
        assert!(QUIRK_DATABASE.has_quirk(12230, 61546, "MOONDROP Dawn Pro", UsbAudioQuirk::RequireVerifiedRate));
        assert!(!QUIRK_DATABASE.has_quirk(12230, 61546, "MOONDROP Dawn Pro", UsbAudioQuirk::Force48kHzOnly));
    }
}
