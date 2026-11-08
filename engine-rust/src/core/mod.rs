// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

pub mod runtime;
pub mod services;

use runtime::{MessageThread, MessageThreadHandle};
use services::ServiceRegistry;
use std::process::ExitCode;

/// Starts the engine's message thread and installs its services.
pub fn run() -> ExitCode {
    // Exercise message-thread startup until IPC supplies work.
    let (runtime, handle) = MessageThread::new();
    let _message_thread = handle
        .install()
        .expect("Message thread was already installed");
    let mut registry = ServiceRegistry::default();
    registry.register(handle);
    let _services = registry.install();

    runtime::post(|| services::with::<MessageThreadHandle, _>(MessageThreadHandle::shutdown))
        .unwrap();

    runtime.run();

    #[cfg(not(target_os = "emscripten"))]
    {
        eprintln!("The Rust engine runtime started. Engine IPC is not implemented yet.");
        ExitCode::FAILURE
    }

    #[cfg(target_os = "emscripten")]
    ExitCode::SUCCESS
}
