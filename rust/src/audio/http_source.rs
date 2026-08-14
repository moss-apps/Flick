//! Seekable HTTP [`MediaSource`] for remote audio streaming.
//!
//! Issues block-granularity ranged GETs (~1 MiB). `seek` drops the buffer and
//! records the target offset; the next `read` issues `Range: bytes=N-` and
//! refills. Total length is resolved from `Content-Range` on the first ranged
//! response. All fields are `Sync` (no persistent reader handle), so the struct
//! is `Send + Sync` without a `Mutex`.

use std::collections::HashMap;
use std::io::{self, Read, Seek, SeekFrom};
use std::time::Duration;
use symphonia::core::io::MediaSource;

const BLOCK_SIZE: usize = 1024 * 1024; // 1 MiB

// ponytail: global timeouts so a stalled network can't pin the command thread.
fn http_agent() -> &'static ureq::Agent {
    static AGENT: std::sync::OnceLock<ureq::Agent> = std::sync::OnceLock::new();
    AGENT.get_or_init(|| {
        ureq::AgentBuilder::new()
            .timeout_connect(Duration::from_secs(10))
            .timeout_read(Duration::from_secs(30))
            .build()
    })
}

pub struct HttpMediaSource {
    url: String,
    headers: HashMap<String, String>,
    pos: u64,
    len: Option<u64>,
    buf: Vec<u8>,
    buf_start: u64,
}

impl HttpMediaSource {
    pub fn new(url: String, headers: HashMap<String, String>) -> Self {
        Self {
            url,
            headers,
            pos: 0,
            len: None,
            buf: Vec::new(),
            buf_start: 0,
        }
    }

    fn ensure_buffered(&mut self) -> io::Result<()> {
        if !self.buf.is_empty()
            && self.pos >= self.buf_start
            && self.pos < self.buf_start + self.buf.len() as u64
        {
            return Ok(());
        }

        let end = self.pos + BLOCK_SIZE as u64 - 1;
        let mut req = http_agent().get(&self.url);
        for (k, v) in &self.headers {
            req = req.set(k, v);
        }
        req = req.set("Range", &format!("bytes={}-{}", self.pos, end));

        let resp = req
            .call()
            .map_err(|e| io::Error::other(format!("HTTP GET failed: {}", e)))?;

        let status = resp.status();
        let content_range = resp.header("Content-Range").map(|s| s.to_string());
        let content_length = resp.header("Content-Length").map(|s| s.to_string());

        self.buf_start = self.pos;
        self.buf.clear();
        resp.into_reader().read_to_end(&mut self.buf)?;

        if status == 206 {
            if let Some(cr) = content_range {
                // "bytes 0-1023/2048"
                if let Some(total) = cr.split('/').nth(1).and_then(|s| s.parse::<u64>().ok()) {
                    self.len = Some(total);
                }
            }
        } else {
            // ponytail: server ignored Range (200 OK full body). Only valid at pos 0.
            self.buf_start = 0;
            if self.pos != 0 {
                return Err(io::Error::new(
                    io::ErrorKind::UnexpectedEof,
                    "server does not support Range requests; cannot serve seeked offset",
                ));
            }
            if let Some(cl) = content_length.and_then(|s| s.parse::<u64>().ok()) {
                self.len = Some(cl);
            }
        }

        Ok(())
    }
}

impl Read for HttpMediaSource {
    fn read(&mut self, dst: &mut [u8]) -> io::Result<usize> {
        if dst.is_empty() {
            return Ok(0);
        }
        if let Some(len) = self.len {
            if self.pos >= len {
                return Ok(0);
            }
        }
        self.ensure_buffered()?;
        if self.buf.is_empty() {
            return Ok(0);
        }
        let offset_in_buf = (self.pos - self.buf_start) as usize;
        let available = &self.buf[offset_in_buf..];
        let n = available.len().min(dst.len());
        dst[..n].copy_from_slice(&available[..n]);
        self.pos += n as u64;
        Ok(n)
    }
}

impl Seek for HttpMediaSource {
    fn seek(&mut self, pos: SeekFrom) -> io::Result<u64> {
        let new_pos = match pos {
            SeekFrom::Start(n) => n as i64,
            SeekFrom::End(n) => self
                .len
                .map(|l| l as i64 + n)
                .ok_or_else(|| io::Error::new(io::ErrorKind::Unsupported, "length unknown"))?,
            SeekFrom::Current(n) => self.pos as i64 + n,
        };
        if new_pos < 0 {
            return Err(io::Error::new(io::ErrorKind::InvalidInput, "negative seek"));
        }
        self.pos = new_pos as u64;
        self.buf.clear();
        Ok(self.pos)
    }
}

impl MediaSource for HttpMediaSource {
    fn is_seekable(&self) -> bool {
        true
    }
    fn byte_len(&self) -> Option<u64> {
        self.len
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use std::net::{TcpListener, TcpStream};
    use std::thread;

    // ponytail: in-process HTTP/1.1 server honoring Range; no ureq mock needed.
    fn spawn_server(data: &'static [u8]) -> String {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let addr = listener.local_addr().unwrap();
        let url = format!("http://{}/track", addr);
        thread::spawn(move || {
            for stream in listener.incoming() {
                let mut stream = stream.unwrap();
                serve_one(&mut stream, data);
            }
        });
        url
    }

    fn serve_one(stream: &mut TcpStream, data: &[u8]) {
        let mut buf = [0u8; 1024];
        let n = stream.read(&mut buf).unwrap_or(0);
        let req = String::from_utf8_lossy(&buf[..n]);
        let range = req
            .lines()
            .find(|l| l.to_ascii_lowercase().starts_with("range:"))
            .and_then(|l| l.split(':').nth(1))
            .map(|s| s.trim().to_string());

        let (status, headers, body_range) = match range.as_deref() {
            Some(r) if r.starts_with("bytes=") => {
                let spec = &r[6..];
                let (lo_s, hi_s) = spec.split_once('-').unwrap_or((spec, ""));
                let lo: usize = lo_s.parse().unwrap_or(0);
                let hi: usize = if hi_s.is_empty() {
                    data.len().saturating_sub(1)
                } else {
                    hi_s.parse().unwrap_or(data.len() - 1)
                };
                let hi = hi.min(data.len() - 1);
                (
                    "206 Partial Content",
                    format!(
                        "Content-Range: bytes {}-{}/{}\r\nContent-Length: {}\r\n",
                        lo,
                        hi,
                        data.len(),
                        hi - lo + 1
                    ),
                    lo..=hi,
                )
            }
            _ => (
                "200 OK",
                format!("Content-Length: {}\r\n", data.len()),
                0..=data.len() - 1,
            ),
        };
        let resp = format!(
            "HTTP/1.1 {}\r\n{}Accept-Ranges: bytes\r\nConnection: close\r\n\r\n",
            status, headers
        );
        stream.write_all(resp.as_bytes()).unwrap();
        stream.write_all(&data[body_range]).unwrap();
        stream.flush().unwrap();
    }

    #[test]
    fn sequential_read_and_len() {
        let data: Vec<u8> = (0..200_000u32).map(|i| (i % 251) as u8).collect();
        let data_box: &'static [u8] = Box::leak(data.into_boxed_slice());
        let url = spawn_server(data_box);
        let mut src = HttpMediaSource::new(url, HashMap::new());

        let mut got = [0u8; 4096];
        let mut total = 0usize;
        loop {
            let n = src.read(&mut got).unwrap();
            if n == 0 {
                break;
            }
            assert_eq!(&got[..n], &data_box[total..total + n]);
            total += n;
        }
        assert_eq!(total, data_box.len());
        assert_eq!(src.byte_len(), Some(data_box.len() as u64));
        assert!(src.is_seekable());
    }

    #[test]
    fn seek_then_read() {
        let data: Vec<u8> = (0..150_000u32).map(|i| (i % 251) as u8).collect();
        let data_box: &'static [u8] = Box::leak(data.into_boxed_slice());
        let url = spawn_server(data_box);
        let mut src = HttpMediaSource::new(url, HashMap::new());

        src.seek(SeekFrom::Start(70_000)).unwrap();
        let mut got = [0u8; 1024];
        let n = src.read(&mut got).unwrap();
        assert_eq!(n, 1024);
        assert_eq!(&got[..n], &data_box[70_000..71_024]);

        // Seek back to start.
        src.seek(SeekFrom::Start(0)).unwrap();
        let n = src.read(&mut got).unwrap();
        assert_eq!(&got[..n], &data_box[0..1024]);
    }
}
