// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

use std::cell::RefCell;
use std::fmt;

use super::runtime::MessageThreadHandle;

#[derive(Clone, Debug)]
pub struct EngineFailure(String);

impl EngineFailure {
    pub(crate) fn new(reason: impl fmt::Display) -> Self {
        Self(reason.to_string())
    }
}

impl fmt::Display for EngineFailure {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.0.fmt(formatter)
    }
}

impl std::error::Error for EngineFailure {}

/// Application lifecycle operations, available as a service on the message thread.
pub struct Application {
    message_thread: MessageThreadHandle,
    fatal_error: RefCell<Option<EngineFailure>>,
}

impl Application {
    pub(crate) fn new(message_thread: MessageThreadHandle) -> Self {
        Self {
            message_thread,
            fatal_error: RefCell::new(None),
        }
    }

    /// Requests ordinary shutdown through the message-thread queue.
    pub fn shutdown(&self) {
        self.message_thread.shutdown();
    }

    /// Reports a fatal error and stops the runtime before another job is dispatched.
    /// The first failure is preserved if cleanup reports additional errors.
    pub fn report_fatal_error(&self, reason: impl fmt::Display) -> EngineFailure {
        // Format and log outside the borrow, so error reporting can query services.
        let failure = EngineFailure::new(reason);
        let (first, failure) = {
            let mut slot = self.fatal_error.borrow_mut();
            let first = slot.is_none();
            (first, slot.get_or_insert(failure).clone())
        };
        if first {
            eprintln!("Fatal engine error: {failure}");
            self.message_thread.wake();
        }
        failure
    }

    pub fn fatal_error(&self) -> Option<EngineFailure> {
        self.fatal_error.borrow().clone()
    }

    pub(crate) fn has_failed(&self) -> bool {
        self.fatal_error.borrow().is_some()
    }
}
