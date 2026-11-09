// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

// cspell:ignore oneshot

use std::cell::{Cell, RefCell};
use std::collections::HashMap;
use std::time::Duration;

use serde::Deserialize;
use tokio::sync::{mpsc, oneshot};

use super::{Application, runtime, services};
use crate::{
    messages::{Request, Response},
    request_handlers,
};

#[cfg(not(target_os = "emscripten"))]
#[path = "ipc/native.rs"]
mod transport;
#[cfg(target_os = "emscripten")]
#[path = "ipc/web.rs"]
pub(crate) mod transport;

pub(crate) struct Outgoing {
    bytes: Vec<u8>,
    flushed: Option<oneshot::Sender<()>>,
}

/// The IPC connection and outstanding engine-to-UI requests for this session.
pub struct Ipc {
    outgoing: mpsc::UnboundedSender<Outgoing>,
    receiver: RefCell<Option<mpsc::UnboundedReceiver<Outgoing>>>,
    next_id: Cell<i64>,
    pending: RefCell<HashMap<i64, oneshot::Sender<Response>>>,
    closing: Cell<bool>,
}

impl Default for Ipc {
    fn default() -> Self {
        let (outgoing, receiver) = mpsc::unbounded_channel();
        Self {
            outgoing,
            receiver: RefCell::new(Some(receiver)),
            next_id: Cell::new(0),
            pending: RefCell::new(HashMap::new()),
            closing: Cell::new(false),
        }
    }
}

impl Ipc {
    pub fn send(&self, message: impl serde::Serialize) -> Result<(), String> {
        self.enqueue(message, None)
    }

    /// Stops accepting new requests while allowing queued replies to drain.
    pub(crate) fn begin_close(&self) {
        self.closing.set(true);
    }

    /// Waits for the transport to write this message.
    pub(crate) async fn send_and_flush(
        &self,
        message: impl serde::Serialize,
    ) -> Result<(), String> {
        let (send, flushed) = oneshot::channel();
        self.enqueue(message, Some(send))?;
        flushed.await.map_err(|_| "IPC connection closed.".into())
    }

    fn enqueue(
        &self,
        message: impl serde::Serialize,
        flushed: Option<oneshot::Sender<()>>,
    ) -> Result<(), String> {
        let body = serde_json::to_vec(&message).map_err(|error| error.to_string())?;
        let mut bytes = Vec::with_capacity(8 + body.len());
        bytes.extend_from_slice(&(body.len() as u64).to_ne_bytes());
        bytes.extend_from_slice(&body);
        self.outgoing
            .send(Outgoing { bytes, flushed })
            .map_err(|_| "IPC connection closed.".into())
    }

    /// Waits for a UI response without holding a model or registry borrow.
    pub async fn request(
        &self,
        make_request: impl FnOnce(i64) -> Request,
        timeout: Duration,
    ) -> Result<Response, String> {
        if self.closing.get() {
            return Err("IPC connection closed.".into());
        }
        let id = self.next_id.get();
        self.next_id
            .set(id.checked_add(1).ok_or("IPC request IDs exhausted.")?);
        let (send, receive) = oneshot::channel();
        self.pending.borrow_mut().insert(id, send);
        // Remove this entry on success, timeout, or cancellation of the task.
        let _pending = PendingRequest { client: self, id };
        self.send(make_request(id))?;
        match tokio::time::timeout(timeout, receive).await {
            Err(_) => Err("IPC request timed out.".into()),
            Ok(Err(_)) => Err("IPC connection closed.".into()),
            Ok(Ok(Response::RequestErrorResponse { message, .. })) => Err(message),
            Ok(Ok(response)) => Ok(response),
        }
    }
}

struct PendingRequest<'a> {
    client: &'a Ipc,
    id: i64,
}
impl Drop for PendingRequest<'_> {
    fn drop(&mut self) {
        self.client.pending.borrow_mut().remove(&self.id);
    }
}

#[derive(Deserialize)]
#[serde(untagged)]
enum Incoming {
    Request(Request),
    Response(Response),
}

pub(crate) fn start() {
    #[cfg(target_os = "emscripten")]
    if transport::shutdown_requested() {
        services::with::<Application, _>(Application::shutdown);
        return;
    }
    let receiver = services::get::<Ipc>().receiver.borrow_mut().take().unwrap();
    runtime::spawn_local(async move {
        if let Err(error) = transport::run(receiver).await {
            services::with::<Application, _>(|app| {
                app.report_fatal_error(error);
            });
        }
    });
}

/// Called by the platform implementation (either native or web) when data is
/// received from the UI.
pub(crate) fn receive(bytes: &[u8]) {
    if services::with::<Application, _>(Application::has_failed) {
        return;
    }
    let client = services::get::<Ipc>();
    let result = (|| -> Result<(), String> {
        match serde_json::from_slice::<Incoming>(bytes)
            .map_err(|error| format!("Invalid IPC message: {error}"))?
        {
            Incoming::Response(response) => {
                let pending = client.pending.borrow_mut().remove(&response.id());
                if let Some(pending) = pending {
                    let _ = pending.send(response);
                }
            }
            Incoming::Request(_) if client.closing.get() => {}
            Incoming::Request(request) => request_handlers::dispatch(request)?,
        }
        Ok(())
    })();
    if let Err(error) = result {
        services::with::<Application, _>(|app| {
            app.report_fatal_error(error);
        });
    }
}

pub(crate) const MAX_MESSAGE_LENGTH: usize = 256 * 1024 * 1024;

pub(crate) fn message_length(header: [u8; 8]) -> std::io::Result<usize> {
    let length = u64::from_ne_bytes(header);
    if length == 0 || length > MAX_MESSAGE_LENGTH as u64 {
        return Err(std::io::Error::new(
            std::io::ErrorKind::InvalidData,
            "Invalid IPC message length",
        ));
    }
    Ok(length as usize)
}
