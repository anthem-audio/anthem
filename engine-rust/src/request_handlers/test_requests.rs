// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

use std::time::Duration;

use crate::core::{ipc::Ipc, services};
use crate::messages::{Request, Response};

pub(super) async fn echo_round_trip(id: i64, value: String, timeout_milliseconds: i64) -> Response {
    let ipc = services::get::<Ipc>();
    let timeout = Duration::from_millis(timeout_milliseconds.clamp(1, 60_000) as u64);
    let result = ipc
        .request(|id| Request::TestUiEchoRequest { id, value }, timeout)
        .await;
    let (value, error) = match result {
        Ok(Response::TestUiEchoResponse { value, .. }) => (Some(value), None),
        Ok(_) => (None, Some("Unexpected UI response type.".into())),
        Err(error) => (None, Some(error)),
    };
    Response::TestUiEchoRoundTripResponse { id, value, error }
}
