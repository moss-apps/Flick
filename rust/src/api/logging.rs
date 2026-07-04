use crate::frb_generated::StreamSink;
use std::sync::{Mutex, OnceLock};

static LOG_SINK: OnceLock<Mutex<Option<StreamSink<String>>>> = OnceLock::new();

pub fn register_log_sink(sink: StreamSink<String>) {
    let cell = LOG_SINK.get_or_init(|| Mutex::new(None));
    if let Ok(mut guard) = cell.lock() {
        *guard = Some(sink);
    }
}

pub(crate) fn forward_to_sink(msg: String) {
    let Some(cell) = LOG_SINK.get() else {
        return;
    };
    let Ok(guard) = cell.try_lock() else {
        return;
    };
    if let Some(sink) = guard.as_ref() {
        let _ = sink.add(msg);
    }
}
