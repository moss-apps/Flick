//! FFI API for ALAC/M4A to WAV/PCM conversion
//!
//! This module exposes the ALAC converter to Flutter via flutter_rust_bridge.

use crate::audio::alac_converter::{AudioMetadata, ConversionSession};
use anyhow::Result;
use flutter_rust_bridge::frb;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};

/// Thread-safe session manager
static SESSION_MANAGER: once_cell::sync::Lazy<Arc<Mutex<SessionManager>>> =
    once_cell::sync::Lazy::new(|| Arc::new(Mutex::new(SessionManager::new())));

struct SessionManager {
    sessions: HashMap<u64, ConversionSession>,
    next_id: u64,
}

impl SessionManager {
    fn new() -> Self {
        Self {
            sessions: HashMap::new(),
            next_id: 1,
        }
    }

    fn create_session(&mut self, session: ConversionSession) -> u64 {
        let id = self.next_id;
        self.next_id += 1;
        self.sessions.insert(id, session);
        id
    }

    fn get_session(&mut self, id: u64) -> Option<&mut ConversionSession> {
        self.sessions.get_mut(&id)
    }

    fn remove_session(&mut self, id: u64) -> Option<ConversionSession> {
        self.sessions.remove(&id)
    }
}

/// Audio metadata exposed to Flutter
#[frb(dart_metadata=("freezed"))]
#[derive(Debug, Clone)]
pub struct AlacAudioMetadata {
    pub sample_rate: u32,
    pub channels: u16,
    pub bit_depth: u16,
    pub duration_samples: u64,
    pub duration_seconds: f64,
}

impl From<&AudioMetadata> for AlacAudioMetadata {
    fn from(meta: &AudioMetadata) -> Self {
        Self {
            sample_rate: meta.sample_rate,
            channels: meta.channels,
            bit_depth: meta.bit_depth,
            duration_samples: meta.duration_samples,
            duration_seconds: meta.duration_seconds,
        }
    }
}

/// Probe ALAC/M4A file and return metadata without creating a session
#[frb(sync)]
pub fn alac_probe_metadata(file_bytes: Vec<u8>) -> Result<AlacAudioMetadata> {
    let session = ConversionSession::new(file_bytes)?;
    Ok(AlacAudioMetadata::from(session.metadata()))
}

/// Create a new conversion session and return session ID
#[frb(sync)]
pub fn alac_create_session(file_bytes: Vec<u8>) -> Result<u64> {
    let session = ConversionSession::new(file_bytes)?;
    let mut manager = SESSION_MANAGER.lock().unwrap();
    Ok(manager.create_session(session))
}

/// Get metadata for an active session
#[frb(sync)]
pub fn alac_get_metadata(session_id: u64) -> Result<AlacAudioMetadata> {
    let mut manager = SESSION_MANAGER.lock().unwrap();
    let session = manager
        .get_session(session_id)
        .ok_or_else(|| anyhow::anyhow!("Invalid session ID"))?;
    Ok(AlacAudioMetadata::from(session.metadata()))
}

/// Get WAV header for the session
#[frb(sync)]
pub fn alac_get_wav_header(session_id: u64) -> Result<Vec<u8>> {
    let mut manager = SESSION_MANAGER.lock().unwrap();
    let session = manager
        .get_session(session_id)
        .ok_or_else(|| anyhow::anyhow!("Invalid session ID"))?;
    Ok(session.wav_header())
}

/// Decode the next chunk of PCM data
///
/// Returns None when end of stream is reached
#[frb(sync)]
pub fn alac_decode_next_chunk(session_id: u64) -> Result<Option<Vec<u8>>> {
    let mut manager = SESSION_MANAGER.lock().unwrap();
    let session = manager
        .get_session(session_id)
        .ok_or_else(|| anyhow::anyhow!("Invalid session ID"))?;
    session.decode_next_chunk()
}

/// Seek to a specific time position in seconds
#[frb(sync)]
pub fn alac_seek(session_id: u64, time_seconds: f64) -> Result<()> {
    let mut manager = SESSION_MANAGER.lock().unwrap();
    let session = manager
        .get_session(session_id)
        .ok_or_else(|| anyhow::anyhow!("Invalid session ID"))?;
    session.seek(time_seconds)
}

/// Close and cleanup a conversion session
#[frb(sync)]
pub fn alac_close_session(session_id: u64) -> Result<()> {
    let mut manager = SESSION_MANAGER.lock().unwrap();
    manager
        .remove_session(session_id)
        .ok_or_else(|| anyhow::anyhow!("Invalid session ID"))?;
    Ok(())
}

/// Convert entire ALAC/M4A file to WAV in memory (one-shot conversion)
///
/// For large files, prefer streaming with create_session + decode_next_chunk
#[frb(sync)]
pub fn alac_convert_to_wav(file_bytes: Vec<u8>) -> Result<Vec<u8>> {
    let mut session = ConversionSession::new(file_bytes)?;
    session.convert_to_wav()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_session_manager() {
        let manager = SessionManager::new();
        assert_eq!(manager.sessions.len(), 0);
    }
}
