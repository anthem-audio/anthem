// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

mod test_requests;

use std::future::Future;

use crate::core::{Application, ipc::Ipc, model_sync, runtime, services};
use crate::messages::{Request, RequestErrorCode, Response};

/// Routes UI requests on the message thread. Inline handlers finish before the
/// next request is dispatched. Handlers that await a UI reply run as local tasks.
pub(crate) fn dispatch(request: Request) -> Result<(), String> {
    match request {
        Request::Exit { id } => {
            let ipc = services::get::<Ipc>();
            // Reject further requests as soon as Exit is dispatched. The transport
            // stays alive until the final reply is written or the connection closes.
            ipc.begin_close();
            runtime::spawn_local(async move {
                let _ = ipc.send_and_flush(Response::ExitReply { id }).await;
                services::with::<Application, _>(Application::shutdown);
            });
            Ok(())
        }
        Request::Heartbeat { id } => reply(Response::HeartbeatReply { id }),
        Request::EngineReadyCheckRequest { id } => reply(Response::EngineReadyCheckResponse {
            id,
            success: true,
            error: None,
        }),
        request @ (Request::ModelInitRequest { .. }
        | Request::ModelUpdateRequest { .. }
        | Request::GetSerializedModelFromEngineRequest { .. }) => {
            if let Some(response) =
                model_sync::handle_request(request).map_err(|error| error.to_string())?
            {
                reply(response)?;
            }
            Ok(())
        }
        Request::TestUiEchoRoundTripRequest {
            id,
            value,
            timeout_milliseconds,
        } => {
            reply_async(test_requests::echo_round_trip(
                id,
                value,
                timeout_milliseconds,
            ));
            Ok(())
        }
        request => reply(Response::RequestErrorResponse {
            id: request.id(),
            code: RequestErrorCode::Unsupported,
            message: "Request is not implemented.".into(),
        }),
    }
}

fn reply(response: Response) -> Result<(), String> {
    services::with::<Ipc, _>(|ipc| ipc.send(response))
}

fn reply_async(response: impl Future<Output = Response> + 'static) {
    runtime::spawn_local(async move {
        if let Err(error) = reply(response.await) {
            services::with::<Application, _>(|app| {
                app.report_fatal_error(error);
            });
        }
    });
}
