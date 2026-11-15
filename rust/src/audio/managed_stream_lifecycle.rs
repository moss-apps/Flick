//! Control-thread lifecycle for Android-managed output. Paused shared PCM must
//! not remain an active silent media stream (Bluetooth multipoint, issue #378).
//! Kept platform-independent so the real lifecycle can be tested without a DAC.

pub(super) trait ManagedOutputStream {
    fn start(&mut self) -> Result<(), String>;
    fn pause(&mut self) -> Result<(), String>;
    fn stop(&mut self);
}

pub(super) struct ManagedStreamLifecycle<S: ManagedOutputStream> {
    stream: Option<S>,
    running: bool,
    keep_alive: bool,
}

impl<S: ManagedOutputStream> ManagedStreamLifecycle<S> {
    pub fn new(stream: S, keep_alive: bool) -> Self {
        Self {
            stream: Some(stream),
            running: false,
            keep_alive,
        }
    }

    pub fn stream_mut(&mut self) -> Option<&mut S> {
        self.stream.as_mut()
    }

    pub fn should_run(&self, playback_active: bool) -> bool {
        self.keep_alive || playback_active
    }

    pub fn reconcile(
        &mut self,
        playback_active: bool,
        disconnected: bool,
        reopen: impl FnOnce() -> Result<S, String>,
    ) -> Result<(), String> {
        if disconnected {
            self.close();
        }

        if !self.should_run(playback_active) {
            if self.running {
                self.running = false;
                if let Some(stream) = self.stream.as_mut() {
                    if let Err(error) = stream.pause() {
                        // A failed pause must not leave silent output active.
                        // Drop only the output, not the source/decoder/queue.
                        self.close();
                        return Err(format!("Failed to pause managed output: {error}"));
                    }
                }
            }
            return Ok(());
        }

        if self.stream.is_none() {
            self.stream = Some(reopen()?);
        }
        if !self.running {
            if let Err(error) = self.stream.as_mut().unwrap().start() {
                self.close();
                return Err(format!("Failed to start managed output: {error}"));
            }
            self.running = true;
        }
        Ok(())
    }

    pub fn close(&mut self) {
        self.running = false;
        if let Some(mut stream) = self.stream.take() {
            stream.stop();
        }
    }
}

impl<S: ManagedOutputStream> Drop for ManagedStreamLifecycle<S> {
    fn drop(&mut self) {
        self.close();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::{Arc, Mutex};

    struct Stream {
        calls: Arc<Mutex<Vec<&'static str>>>,
        fail_start: bool,
        fail_pause: bool,
    }

    impl ManagedOutputStream for Stream {
        fn start(&mut self) -> Result<(), String> {
            self.calls.lock().unwrap().push("start");
            if self.fail_start {
                Err("disconnected".into())
            } else {
                Ok(())
            }
        }

        fn pause(&mut self) -> Result<(), String> {
            self.calls.lock().unwrap().push("pause");
            if self.fail_pause {
                Err("disconnected".into())
            } else {
                Ok(())
            }
        }

        fn stop(&mut self) {
            self.calls.lock().unwrap().push("stop");
        }
    }

    fn stream(calls: &Arc<Mutex<Vec<&'static str>>>) -> Stream {
        Stream {
            calls: calls.clone(),
            fail_start: false,
            fail_pause: false,
        }
    }

    fn unexpected_reopen() -> Result<Stream, String> {
        panic!("the existing output should be reused")
    }

    #[test]
    fn shared_pcm_stays_inactive_until_play_and_reuses_output_after_pause() {
        let calls = Arc::new(Mutex::new(Vec::new()));
        let mut output = ManagedStreamLifecycle::new(stream(&calls), false);
        output.reconcile(false, false, unexpected_reopen).unwrap();
        assert!(output.stream_mut().is_some());
        assert!(calls.lock().unwrap().is_empty());
        for _ in 0..3 {
            output.reconcile(true, false, unexpected_reopen).unwrap();
            output.reconcile(true, false, unexpected_reopen).unwrap();
            output.reconcile(false, false, unexpected_reopen).unwrap();
            output.reconcile(false, false, unexpected_reopen).unwrap();
        }
        assert_eq!(
            *calls.lock().unwrap(),
            ["start", "pause", "start", "pause", "start", "pause"]
        );
    }

    #[test]
    fn disconnect_while_paused_does_not_reopen_until_explicit_playback() {
        let calls = Arc::new(Mutex::new(Vec::new()));
        let mut output = ManagedStreamLifecycle::new(stream(&calls), false);
        output.reconcile(true, false, unexpected_reopen).unwrap();
        output.reconcile(false, false, unexpected_reopen).unwrap();
        output.reconcile(false, true, unexpected_reopen).unwrap();
        output.reconcile(false, false, unexpected_reopen).unwrap();
        assert_eq!(*calls.lock().unwrap(), ["start", "pause", "stop"]);
        output
            .reconcile(true, false, || Ok(stream(&calls)))
            .unwrap();
        assert_eq!(*calls.lock().unwrap(), ["start", "pause", "stop", "start"]);
    }

    #[test]
    fn failed_pause_closes_output_instead_of_leaving_silence_running() {
        let calls = Arc::new(Mutex::new(Vec::new()));
        let mut initial = stream(&calls);
        initial.fail_pause = true;
        let mut output = ManagedStreamLifecycle::new(initial, false);
        output.reconcile(true, false, unexpected_reopen).unwrap();
        assert!(output.reconcile(false, false, unexpected_reopen).is_err());
        output.reconcile(false, false, unexpected_reopen).unwrap();
        assert_eq!(*calls.lock().unwrap(), ["start", "pause", "stop"]);
        output
            .reconcile(true, false, || Ok(stream(&calls)))
            .unwrap();
        assert_eq!(*calls.lock().unwrap(), ["start", "pause", "stop", "start"]);
    }

    #[test]
    fn failed_start_is_retryable_but_not_while_paused() {
        let calls = Arc::new(Mutex::new(Vec::new()));
        let mut initial = stream(&calls);
        initial.fail_start = true;
        let mut output = ManagedStreamLifecycle::new(initial, false);
        assert!(output.reconcile(true, false, unexpected_reopen).is_err());
        output.reconcile(false, false, unexpected_reopen).unwrap();
        output
            .reconcile(true, false, || Ok(stream(&calls)))
            .unwrap();
        assert_eq!(*calls.lock().unwrap(), ["start", "stop", "start"]);
    }

    #[test]
    fn active_disconnect_reopens_and_starts_replacement() {
        let calls = Arc::new(Mutex::new(Vec::new()));
        let mut output = ManagedStreamLifecycle::new(stream(&calls), false);
        output.reconcile(true, false, unexpected_reopen).unwrap();
        output.reconcile(true, true, || Ok(stream(&calls))).unwrap();
        assert_eq!(*calls.lock().unwrap(), ["start", "stop", "start"]);
    }

    #[test]
    fn exclusive_and_raw_transports_keep_existing_keepalive_behavior() {
        let calls = Arc::new(Mutex::new(Vec::new()));
        let mut output = ManagedStreamLifecycle::new(stream(&calls), true);
        output.reconcile(false, false, unexpected_reopen).unwrap();
        output.reconcile(true, false, unexpected_reopen).unwrap();
        output.reconcile(false, false, unexpected_reopen).unwrap();
        assert_eq!(*calls.lock().unwrap(), ["start"]);
    }
}
