//! Hardware control transfers routed to the isochronous streaming thread.
//!
//! libusb's usbfs backend reaps completed URBs per file descriptor without
//! checking which context submitted them. A second `Context` wrapped around a
//! streaming fd therefore steals the stream's isochronous completions while it
//! runs its own control transfer, and the stream can reap the control URB in
//! return. While a stream is active, Feature Unit volume/mute/health requests
//! are queued to the streaming thread instead. It runs them on its own handle
//! between isochronous resubmissions and answers over a reply channel.

use rusb::{DeviceHandle, Error as UsbError, UsbContext};
use std::fmt;
use std::sync::atomic::{AtomicU8, Ordering};
use std::sync::mpsc::{sync_channel, Receiver, RecvTimeoutError, SyncSender, TrySendError};
use std::sync::Arc;
use std::time::{Duration, Instant};

/// Requests that may wait for the streaming thread at once. Callers are
/// serialised by the hardware volume mutex, so one live request is the norm;
/// the spare slots hold requests a caller abandoned but the stream has not
/// popped yet. A wedged stream therefore fails new callers instead of letting
/// them pile up.
pub(crate) const STREAM_CONTROL_QUEUE_CAPACITY: usize = 4;

/// Longest one control transfer may run inline on the streaming thread.
///
/// Resubmission pauses for the duration. The smallest audio cushion is 8
/// queued transfers x 32 packets x 125 us = 32 ms (high-speed, 125 us service
/// interval; full-speed has 128 ms). A DAC normally ACKs a Feature Unit
/// request in 1-3 ms, so 20 ms leaves ~10x headroom for slow firmware while
/// staying under that cushion. The 1 s timeouts used on the idle path could
/// underrun the stream by themselves.
pub(crate) const STREAM_CONTROL_TRANSFER_TIMEOUT: Duration = Duration::from_millis(20);

/// How long a caller waits for the streaming thread to run its request. The
/// stream services one request per completed isochronous transfer (4-16 ms
/// apart, 50 ms worst case when idle), so this covers the queue wait plus one
/// inline transfer while still bounding a JNI/UI caller if the stream wedges.
pub(crate) const STREAM_CONTROL_REPLY_DEADLINE: Duration = Duration::from_millis(250);

/// Extra wait for a request the stream already started when the caller's
/// deadline passes; its own transfer timeout bounds it.
const STREAM_CONTROL_RUNNING_GRACE: Duration = Duration::from_millis(100);

const STATE_PENDING: u8 = 0;
const STATE_RUNNING: u8 = 1;
const STATE_ABANDONED: u8 = 2;

const USB_DIR_IN: u8 = 0x80;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum ControlError {
    /// libusb rejected or failed the transfer.
    Usb(UsbError),
    /// The stream's request queue is full.
    QueueFull,
    /// The streaming thread did not run the request before its deadline.
    Expired,
    /// The stream stopped before the request completed.
    StreamEnded,
    /// The handle the request was routed to was released mid-operation.
    HandleReleased,
}

impl fmt::Display for ControlError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Usb(error) => write!(f, "{error}"),
            Self::QueueFull => f.write_str("USB stream control queue is full"),
            Self::Expired => f.write_str("USB stream did not service the control request in time"),
            Self::StreamEnded => {
                f.write_str("USB stream ended before the control request completed")
            }
            Self::HandleReleased => f.write_str("USB control handle was released"),
        }
    }
}

impl std::error::Error for ControlError {}

/// The two class-request primitives the Feature Unit helpers need. Implemented
/// by a raw libusb handle (idle, transient) and by the stream's request queue.
pub(crate) trait UsbControl {
    fn control_in(
        &self,
        request_type: u8,
        request: u8,
        value: u16,
        index: u16,
        buf: &mut [u8],
        timeout: Duration,
    ) -> Result<usize, ControlError>;

    fn control_out(
        &self,
        request_type: u8,
        request: u8,
        value: u16,
        index: u16,
        buf: &[u8],
        timeout: Duration,
    ) -> Result<usize, ControlError>;
}

impl<T: UsbContext> UsbControl for DeviceHandle<T> {
    fn control_in(
        &self,
        request_type: u8,
        request: u8,
        value: u16,
        index: u16,
        buf: &mut [u8],
        timeout: Duration,
    ) -> Result<usize, ControlError> {
        self.read_control(request_type, request, value, index, buf, timeout)
            .map_err(ControlError::Usb)
    }

    fn control_out(
        &self,
        request_type: u8,
        request: u8,
        value: u16,
        index: u16,
        buf: &[u8],
        timeout: Duration,
    ) -> Result<usize, ControlError> {
        self.write_control(request_type, request, value, index, buf, timeout)
            .map_err(ControlError::Usb)
    }
}

/// Where a hardware control transfer should run.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum ControlRoute {
    /// A stream owns the fd: queue to its thread.
    Stream,
    /// No stream, but the idle lock holds a handle for this device.
    IdleLock,
    /// Nothing else touches the fd: a throwaway context is safe.
    Transient,
}

pub(crate) fn route_hardware_control(
    stream_registered: bool,
    idle_lock_held: bool,
) -> ControlRoute {
    if stream_registered {
        ControlRoute::Stream
    } else if idle_lock_held {
        ControlRoute::IdleLock
    } else {
        ControlRoute::Transient
    }
}

#[derive(Debug)]
pub(crate) struct ControlTransfer {
    pub(crate) request_type: u8,
    pub(crate) request: u8,
    pub(crate) value: u16,
    pub(crate) index: u16,
    /// IN: zeroed buffer to fill. OUT: payload.
    pub(crate) data: Vec<u8>,
    pub(crate) timeout: Duration,
}

impl ControlTransfer {
    fn is_in(&self) -> bool {
        self.request_type & USB_DIR_IN != 0
    }

    /// Runs the transfer synchronously on `handle`.
    pub(crate) fn run_on<T: UsbContext>(
        &mut self,
        handle: &DeviceHandle<T>,
        timeout: Duration,
    ) -> Result<usize, UsbError> {
        if self.is_in() {
            handle.read_control(
                self.request_type,
                self.request,
                self.value,
                self.index,
                &mut self.data,
                timeout,
            )
        } else {
            handle.write_control(
                self.request_type,
                self.request,
                self.value,
                self.index,
                &self.data,
                timeout,
            )
        }
    }
}

#[derive(Debug)]
pub(crate) struct ControlReply {
    pub(crate) transferred: usize,
    /// IN: the filled buffer (`transferred` valid bytes).
    pub(crate) data: Vec<u8>,
}

type ControlResult = Result<ControlReply, ControlError>;

struct QueuedRequest {
    transfer: ControlTransfer,
    deadline: Instant,
    /// PENDING -> RUNNING (stream took it) or ABANDONED (caller gave up, or
    /// the deadline passed before the stream reached it). Whoever wins the
    /// swap decides, so a request is never executed after its caller reported
    /// failure.
    state: Arc<AtomicU8>,
    reply: SyncSender<ControlResult>,
}

/// Caller side of the queue; cheap to clone.
#[derive(Clone)]
pub(crate) struct StreamControlHandle {
    tx: SyncSender<QueuedRequest>,
}

/// Streaming-thread side of the queue.
pub(crate) struct StreamControlService {
    rx: Receiver<QueuedRequest>,
}

pub(crate) fn stream_control_channel() -> (StreamControlHandle, StreamControlService) {
    let (tx, rx) = sync_channel(STREAM_CONTROL_QUEUE_CAPACITY);
    (StreamControlHandle { tx }, StreamControlService { rx })
}

/// A queued request the caller has not yet waited on.
pub(crate) struct PendingControl {
    reply: Receiver<ControlResult>,
    state: Arc<AtomicU8>,
    deadline: Instant,
}

impl StreamControlHandle {
    pub(crate) fn enqueue(
        &self,
        transfer: ControlTransfer,
        deadline: Instant,
    ) -> Result<PendingControl, ControlError> {
        let (reply_tx, reply_rx) = sync_channel(1);
        let state = Arc::new(AtomicU8::new(STATE_PENDING));
        self.tx
            .try_send(QueuedRequest {
                transfer,
                deadline,
                state: Arc::clone(&state),
                reply: reply_tx,
            })
            .map_err(|error| match error {
                TrySendError::Full(_) => ControlError::QueueFull,
                TrySendError::Disconnected(_) => ControlError::StreamEnded,
            })?;
        Ok(PendingControl {
            reply: reply_rx,
            state,
            deadline,
        })
    }

    pub(crate) fn submit(&self, transfer: ControlTransfer) -> ControlResult {
        self.enqueue(transfer, Instant::now() + STREAM_CONTROL_REPLY_DEADLINE)?
            .wait()
    }
}

impl PendingControl {
    /// Blocks until the stream answers, the stream ends, or the deadline passes.
    pub(crate) fn wait(self) -> ControlResult {
        let remaining = self.deadline.saturating_duration_since(Instant::now());
        match self.reply.recv_timeout(remaining) {
            Ok(result) => result,
            Err(RecvTimeoutError::Disconnected) => Err(ControlError::StreamEnded),
            Err(RecvTimeoutError::Timeout) => {
                if self
                    .state
                    .compare_exchange(
                        STATE_PENDING,
                        STATE_ABANDONED,
                        Ordering::AcqRel,
                        Ordering::Acquire,
                    )
                    .is_ok()
                {
                    return Err(ControlError::Expired);
                }
                // The stream already took it (or answered just now): its
                // transfer timeout bounds how long the reply can take.
                match self
                    .reply
                    .recv_timeout(STREAM_CONTROL_TRANSFER_TIMEOUT + STREAM_CONTROL_RUNNING_GRACE)
                {
                    Ok(result) => result,
                    Err(RecvTimeoutError::Disconnected) => Err(ControlError::StreamEnded),
                    Err(RecvTimeoutError::Timeout) => Err(ControlError::Expired),
                }
            }
        }
    }
}

impl UsbControl for StreamControlHandle {
    fn control_in(
        &self,
        request_type: u8,
        request: u8,
        value: u16,
        index: u16,
        buf: &mut [u8],
        timeout: Duration,
    ) -> Result<usize, ControlError> {
        let reply = self.submit(ControlTransfer {
            request_type,
            request,
            value,
            index,
            data: vec![0; buf.len()],
            timeout,
        })?;
        let copied = reply.transferred.min(buf.len());
        buf[..copied].copy_from_slice(&reply.data[..copied]);
        Ok(reply.transferred)
    }

    fn control_out(
        &self,
        request_type: u8,
        request: u8,
        value: u16,
        index: u16,
        buf: &[u8],
        timeout: Duration,
    ) -> Result<usize, ControlError> {
        self.submit(ControlTransfer {
            request_type,
            request,
            value,
            index,
            data: buf.to_vec(),
            timeout,
        })
        .map(|reply| reply.transferred)
    }
}

impl StreamControlService {
    /// Runs at most one live request, so the stream is paused for a single
    /// transfer per call. Requests whose caller gave up, or whose deadline has
    /// passed, are answered/skipped without touching the bus. Never waits for
    /// the caller: the reply channel has room for the one answer.
    ///
    /// Returns whether a transfer was executed.
    pub(crate) fn service_next<F>(&self, now: Instant, mut execute: F) -> bool
    where
        F: FnMut(&mut ControlTransfer, Duration) -> Result<usize, UsbError>,
    {
        while let Ok(mut request) = self.rx.try_recv() {
            let expired = now >= request.deadline;
            let claimed = if expired {
                STATE_ABANDONED
            } else {
                STATE_RUNNING
            };
            if request
                .state
                .compare_exchange(STATE_PENDING, claimed, Ordering::AcqRel, Ordering::Acquire)
                .is_err()
            {
                continue;
            }
            if expired {
                let _ = request.reply.try_send(Err(ControlError::Expired));
                continue;
            }

            let timeout = request
                .transfer
                .timeout
                .clamp(Duration::from_millis(1), STREAM_CONTROL_TRANSFER_TIMEOUT);
            let result = execute(&mut request.transfer, timeout)
                .map(|transferred| ControlReply {
                    transferred,
                    data: std::mem::take(&mut request.transfer.data),
                })
                .map_err(ControlError::Usb);
            let _ = request.reply.try_send(result);
            return true;
        }
        false
    }

    /// Fails every queued request and closes the queue; later `enqueue` calls
    /// fail at once with `StreamEnded`. Dropping the service has the same
    /// effect (queued requests are dropped, which wakes their callers).
    pub(crate) fn close(self) {
        while let Ok(request) = self.rx.try_recv() {
            let _ = request.reply.try_send(Err(ControlError::StreamEnded));
        }
    }
}
