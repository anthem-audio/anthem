// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

// cspell:ignore oneshot

use std::cell::{Cell, RefCell};
use std::future::Future;
use std::rc::Rc;
use std::time::Duration;
use tokio::sync::oneshot;

use crate::audio::{Config, Stream};
use crate::messages::IpcEvent;

use super::{Application, ipc::Ipc, runtime, services};

#[derive(Default)]
enum State {
    #[default]
    Stopped,
    Starting {
        // Dropping this sender cancels startup on StopAudio or shutdown.
        _cancel: oneshot::Sender<()>,
    },
    Running {
        id: u64,
        stream: Stream,
        config: Config,
    },
}

enum Start {
    AlreadyRunning(Config),
    Open {
        id: u64,
        cancelled: oneshot::Receiver<()>,
    },
}

/// Owns the device stream on the application's message thread.
#[derive(Default)]
pub(crate) struct AudioSession {
    state: RefCell<State>,
    next_id: Cell<u64>,
}

impl AudioSession {
    fn reserve_start(&self) -> Result<Start, &'static str> {
        let mut state = self.state.borrow_mut();
        match &*state {
            State::Running { config, .. } => Ok(Start::AlreadyRunning(*config)),
            State::Starting { .. } => Err("Audio startup is already in progress."),
            State::Stopped => {
                let id = self.next_id.get();
                self.next_id.set(id.wrapping_add(1));
                let (cancel, cancelled) = oneshot::channel();
                *state = State::Starting { _cancel: cancel };
                Ok(Start::Open { id, cancelled })
            }
        }
    }

    pub(crate) fn start(self: Rc<Self>) -> impl Future<Output = Result<Config, String>> {
        // Reserve the session before spawning the task so a following stop
        // request can cancel it even before the task has started.
        let start = self.reserve_start();
        async move {
            let (id, mut cancelled) = match start? {
                Start::AlreadyRunning(config) => return Ok(config),
                Start::Open { id, cancelled } => (id, cancelled),
            };
            let opened = tokio::select! {
                biased;
                _ = &mut cancelled => return Err("Audio startup was cancelled.".into()),
                opened = Stream::open() => opened,
            };
            let mut state = self.state.borrow_mut();
            *state = State::Stopped;
            let (mut stream, config) = opened?;
            stream.start()?;
            *state = State::Running { id, stream, config };
            drop(state);
            runtime::spawn_local(self.watch_stream(id));
            Ok(config)
        }
    }

    pub(crate) fn stop(&self) {
        let old = self.state.take();
        drop(old);
    }

    async fn watch_stream(self: Rc<Self>, id: u64) {
        loop {
            tokio::time::sleep(Duration::from_millis(250)).await;
            let failed = match &*self.state.borrow() {
                State::Running {
                    id: active_id,
                    stream,
                    ..
                } if *active_id == id => stream.has_failed(),
                _ => return,
            };
            if failed {
                self.stop();
                let result = services::with::<Ipc, _>(|ipc| {
                    ipc.send(IpcEvent::AudioSessionInvalidatedEvent {
                        reason: Some("The audio output stream stopped working.".into()),
                    })
                });
                if let Err(error) = result {
                    services::with::<Application, _>(|app| app.report_fatal_error(error));
                }
                return;
            }
        }
    }
}
