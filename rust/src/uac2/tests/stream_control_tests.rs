use crate::uac2::stream_control::{
    route_hardware_control, stream_control_channel, ControlError, ControlRoute, ControlTransfer,
    StreamControlService, UsbControl, STREAM_CONTROL_QUEUE_CAPACITY,
    STREAM_CONTROL_TRANSFER_TIMEOUT,
};
use rusb::Error as UsbError;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::channel;
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};

const IN: u8 = 0xa1;
const OUT: u8 = 0x21;

fn transfer(request_type: u8, request: u8, data: Vec<u8>) -> ControlTransfer {
    ControlTransfer {
        request_type,
        request,
        value: 0,
        index: 0,
        data,
        timeout: Duration::from_secs(1),
    }
}

fn live_deadline() -> Instant {
    Instant::now() + Duration::from_secs(30)
}

#[test]
fn route_prefers_stream_then_idle_lock_then_transient() {
    assert_eq!(route_hardware_control(true, true), ControlRoute::Stream);
    assert_eq!(route_hardware_control(true, false), ControlRoute::Stream);
    assert_eq!(route_hardware_control(false, true), ControlRoute::IdleLock);
    assert_eq!(
        route_hardware_control(false, false),
        ControlRoute::Transient
    );
}

#[test]
fn queue_rejects_requests_beyond_capacity_until_one_is_serviced() {
    let (handle, service) = stream_control_channel();
    let mut pending = Vec::new();
    for _ in 0..STREAM_CONTROL_QUEUE_CAPACITY {
        pending.push(
            handle
                .enqueue(transfer(IN, 1, vec![0; 2]), live_deadline())
                .unwrap(),
        );
    }
    assert_eq!(
        handle
            .enqueue(transfer(IN, 1, vec![0; 2]), live_deadline())
            .err(),
        Some(ControlError::QueueFull)
    );

    assert!(service.service_next(Instant::now(), |_, _| Ok(2)));
    assert!(handle
        .enqueue(transfer(IN, 1, vec![0; 2]), live_deadline())
        .is_ok());
}

#[test]
fn stream_runs_one_live_request_per_call() {
    let (handle, service) = stream_control_channel();
    let pending: Vec<_> = (0..3u8)
        .map(|request| {
            handle
                .enqueue(transfer(IN, request, vec![0; 2]), live_deadline())
                .unwrap()
        })
        .collect();

    let mut executed = Vec::new();
    assert!(service.service_next(Instant::now(), |transfer, _| {
        executed.push(transfer.request);
        Ok(2)
    }));
    assert_eq!(executed, [0]);
    assert!(service.service_next(Instant::now(), |transfer, _| {
        executed.push(transfer.request);
        Ok(2)
    }));
    assert_eq!(executed, [0, 1]);
    drop(pending);
}

#[test]
fn request_past_its_deadline_is_failed_without_touching_the_bus() {
    let (handle, service) = stream_control_channel();
    let deadline = Instant::now() + Duration::from_millis(10);
    let expired = handle
        .enqueue(transfer(OUT, 9, vec![1, 2]), deadline)
        .unwrap();
    let live = handle
        .enqueue(transfer(OUT, 7, vec![3, 4]), live_deadline())
        .unwrap();

    let mut executed = Vec::new();
    // The stream reaches the queue after the first deadline: only the live
    // request may run, and it still counts as this call's single transfer.
    assert!(
        service.service_next(deadline + Duration::from_secs(1), |transfer, _| {
            executed.push(transfer.request);
            Ok(transfer.data.len())
        })
    );
    assert_eq!(executed, [7]);
    assert_eq!(expired.wait().err(), Some(ControlError::Expired));
    assert_eq!(live.wait().unwrap().transferred, 2);
}

#[test]
fn caller_that_times_out_withdraws_the_request_before_it_runs() {
    let (handle, service) = stream_control_channel();
    let pending = handle
        .enqueue(transfer(OUT, 5, vec![1]), Instant::now())
        .unwrap();
    // Nobody serviced it before the deadline: the caller reports failure...
    assert_eq!(pending.wait().err(), Some(ControlError::Expired));

    // ...so a late stream iteration must not execute the write.
    let mut executed = 0;
    assert!(!service.service_next(Instant::now(), |_, _| {
        executed += 1;
        Ok(1)
    }));
    assert_eq!(executed, 0);
}

#[test]
fn request_already_running_at_the_deadline_still_returns_its_result() {
    let (handle, service) = stream_control_channel();
    let pending = handle
        .enqueue(
            transfer(OUT, 5, vec![1]),
            Instant::now() + Duration::from_millis(100),
        )
        .unwrap();

    let (started_tx, started_rx) = channel();
    let (release_tx, release_rx) = channel::<()>();
    let stream = thread::spawn(move || {
        service.service_next(Instant::now(), |transfer, _| {
            started_tx.send(()).unwrap();
            release_rx.recv().unwrap();
            Ok(transfer.data.len())
        })
    });
    started_rx.recv().unwrap();
    thread::sleep(Duration::from_millis(130));
    let release = thread::spawn(move || {
        thread::sleep(Duration::from_millis(20));
        release_tx.send(()).unwrap();
    });

    assert_eq!(pending.wait().unwrap().transferred, 1);
    release.join().unwrap();
    assert!(stream.join().unwrap());
}

#[test]
fn pending_requests_fail_when_the_stream_ends() {
    let (handle, service) = stream_control_channel();
    let first = handle
        .enqueue(transfer(IN, 1, vec![0; 2]), live_deadline())
        .unwrap();
    let second = handle
        .enqueue(transfer(OUT, 2, vec![1]), live_deadline())
        .unwrap();

    service.close();

    assert_eq!(first.wait().err(), Some(ControlError::StreamEnded));
    assert_eq!(second.wait().err(), Some(ControlError::StreamEnded));
    assert_eq!(
        handle
            .enqueue(transfer(IN, 3, vec![0; 2]), live_deadline())
            .err(),
        Some(ControlError::StreamEnded)
    );
}

#[test]
fn dropping_the_service_wakes_callers_instead_of_leaving_them_to_the_deadline() {
    let (handle, service) = stream_control_channel();
    let pending = handle
        .enqueue(transfer(IN, 1, vec![0; 2]), live_deadline())
        .unwrap();

    drop(service);

    let started = Instant::now();
    assert_eq!(pending.wait().err(), Some(ControlError::StreamEnded));
    assert!(started.elapsed() < Duration::from_secs(5));
}

#[test]
fn stream_never_waits_for_a_slow_or_absent_caller() {
    let (handle, service) = stream_control_channel();
    let abandoned = handle
        .enqueue(transfer(IN, 1, vec![0; 2]), live_deadline())
        .unwrap();
    drop(abandoned);
    let unread = handle
        .enqueue(transfer(IN, 2, vec![0; 2]), live_deadline())
        .unwrap();

    // The first caller is gone and the second has not read its reply yet;
    // neither may hold up the stream thread.
    assert!(service.service_next(Instant::now(), |_, _| Ok(2)));
    assert!(service.service_next(Instant::now(), |_, _| Ok(2)));
    assert!(!service.service_next(Instant::now(), |_, _| Ok(2)));
    assert_eq!(unread.wait().unwrap().transferred, 2);
}

#[test]
fn inline_timeout_is_capped_for_the_streaming_thread() {
    let (handle, service) = stream_control_channel();
    let mut seen = Vec::new();
    for requested in [
        Duration::from_secs(1),
        Duration::from_millis(5),
        Duration::ZERO,
    ] {
        let mut request = transfer(IN, 1, vec![0; 2]);
        request.timeout = requested;
        let pending = handle.enqueue(request, live_deadline()).unwrap();
        service.service_next(Instant::now(), |_, timeout| {
            seen.push(timeout);
            Ok(2)
        });
        pending.wait().unwrap();
    }
    assert_eq!(
        seen,
        [
            STREAM_CONTROL_TRANSFER_TIMEOUT,
            Duration::from_millis(5),
            Duration::from_millis(1)
        ]
    );
}

fn spawn_stream(
    service: StreamControlService,
    mut execute: impl FnMut(&mut ControlTransfer, Duration) -> Result<usize, UsbError> + Send + 'static,
) -> (Arc<AtomicBool>, thread::JoinHandle<()>) {
    let stop = Arc::new(AtomicBool::new(false));
    let stream_stop = Arc::clone(&stop);
    let thread = thread::spawn(move || {
        while !stream_stop.load(Ordering::Acquire) {
            if !service.service_next(Instant::now(), &mut execute) {
                thread::sleep(Duration::from_millis(1));
            }
        }
        service.close();
    });
    (stop, thread)
}

#[test]
fn control_requests_round_trip_through_the_stream_thread() {
    let (handle, service) = stream_control_channel();
    let (stop, stream) = spawn_stream(service, |transfer, _| {
        if transfer.request_type == IN {
            transfer.data[0] = 0x34;
            transfer.data[1] = 0x12;
            Ok(2)
        } else {
            Ok(transfer.data.len())
        }
    });

    let mut read = [0u8; 2];
    assert_eq!(
        handle.control_in(IN, 0x81, 0x0201, 0x0200, &mut read, Duration::from_secs(1)),
        Ok(2)
    );
    assert_eq!(read, [0x34, 0x12]);
    assert_eq!(
        handle.control_out(
            OUT,
            0x01,
            0x0201,
            0x0200,
            &[0xcd, 0xab],
            Duration::from_secs(1)
        ),
        Ok(2)
    );

    stop.store(true, Ordering::Release);
    stream.join().unwrap();
    assert_eq!(
        handle.control_out(OUT, 0x01, 0, 0, &[1], Duration::from_secs(1)),
        Err(ControlError::StreamEnded)
    );
}

#[test]
fn usb_errors_keep_their_original_text_for_the_caller() {
    let (handle, service) = stream_control_channel();
    let (stop, stream) = spawn_stream(service, |_, _| Err(UsbError::Pipe));

    let mut read = [0u8; 2];
    let error = handle
        .control_in(IN, 0x81, 0, 0, &mut read, Duration::from_secs(1))
        .unwrap_err();
    assert_eq!(error, ControlError::Usb(UsbError::Pipe));
    assert_eq!(error.to_string(), UsbError::Pipe.to_string());

    stop.store(true, Ordering::Release);
    stream.join().unwrap();
}
