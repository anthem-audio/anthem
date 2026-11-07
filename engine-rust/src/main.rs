/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

mod runtime;
mod services;

use runtime::{MessageThread, MessageThreadHandle};
use services::ServiceRegistry;
use std::process::ExitCode;

fn main() -> ExitCode {
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
