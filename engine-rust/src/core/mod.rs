// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

mod application;
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
        let _services = registry.install();

        self.message_thread
            .run_until(|| services::with::<Application, _>(Application::has_failed));
        services::with::<Application, _>(Application::fatal_error).map_or(Ok(()), Err)
    }
}

/// Starts the engine's message thread and installs its services.
pub fn run() -> ExitCode {
    // Exercise message-thread startup until IPC supplies work.
    let (runtime, handle) = EngineRuntime::new();
    handle
        .post(|| services::with::<Application, _>(Application::shutdown))
        .unwrap();
    if let Err(error) = runtime.run() {
        eprintln!("Engine stopped: {error}");
        return ExitCode::FAILURE;
    }

    #[cfg(not(target_os = "emscripten"))]
    {
        eprintln!("The Rust engine runtime started. Engine IPC is not implemented yet.");
        ExitCode::FAILURE
    }

    #[cfg(target_os = "emscripten")]
    ExitCode::SUCCESS
}
