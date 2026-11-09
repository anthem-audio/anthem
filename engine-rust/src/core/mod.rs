// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

mod application;
pub(crate) mod audio_session;
pub mod ipc;
pub mod model_sync;
pub mod runtime;
pub mod services;

pub use application::{Application, EngineFailure};
use runtime::{MessageThread, MessageThreadHandle};
use services::ServiceRegistry;
use std::process::ExitCode;

/// Owns the message-thread runtime. Services are created on the thread that runs it.
pub struct EngineRuntime {
    message_thread: MessageThread,
    handle: MessageThreadHandle,
}

impl EngineRuntime {
    pub fn new() -> (Self, MessageThreadHandle) {
        let (message_thread, handle) = MessageThread::new();
        (
            Self {
                message_thread,
                handle: handle.clone(),
            },
            handle,
        )
    }

    pub fn run(self) -> Result<(), EngineFailure> {
        let _message_thread = self
            .handle
            .install()
            .map_err(|_| EngineFailure::new("Message thread was already installed"))?;
        let mut registry = ServiceRegistry::default();
        registry.register(Application::new(self.handle));
        registry.register(model_sync::ProjectSlot::default());
        registry.register(ipc::Ipc::default());
        registry.register(audio_session::AudioSession::default());
        let _services = registry.install();

        self.message_thread
            .run_until(|| services::with::<Application, _>(Application::has_failed));
        services::with::<audio_session::AudioSession, _>(audio_session::AudioSession::stop);
        services::with::<Application, _>(Application::fatal_error).map_or(Ok(()), Err)
    }
}

/// Starts the engine's message thread and installs its services.
pub fn run() -> ExitCode {
    let (runtime, handle) = EngineRuntime::new();
    // Queue startup before the handle is installed. The job runs once the
    // services and local task scheduler are ready.
    handle
        .post(ipc::start)
        .expect("Could not queue IPC startup");
    let result = runtime.run();
    #[cfg(target_os = "emscripten")]
    let result = {
        let audio_shutdown = crate::audio::web::shutdown().map_err(EngineFailure::new);
        let result = result.and(audio_shutdown);
        ipc::transport::finished(result.is_err());
        result
    };
    if let Err(error) = result {
        eprintln!("Engine stopped: {error}");
        return ExitCode::FAILURE;
    }

    ExitCode::SUCCESS
}
