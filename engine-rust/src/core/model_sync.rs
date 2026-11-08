// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

use std::cell::RefCell;

use crate::messages::{Request, Response};
use crate::model::{
    ModelRef, ProjectModel,
    sync::{ModelUpdate, ModelValue, SyncError},
};

use super::{Application, EngineFailure, services};

// The slot remains installed for the session. Initialization can replace the
// root without changing how callers find the current project through services.
pub(crate) type ProjectSlot = RefCell<Option<ModelRef<ProjectModel>>>;

fn project() -> Result<ModelRef<ProjectModel>, SyncError> {
    services::with::<ProjectSlot, _>(|slot| slot.borrow().clone())
        .ok_or_else(|| SyncError::new("Project has not been initialized"))
}

/// Queries the current project on the message thread, without exposing mutation.
pub fn with_project<R>(read: impl FnOnce(&ProjectModel) -> R) -> Result<R, SyncError> {
    Ok(project()?.with(read))
}

/// Handles model requests on the message thread. A sync error ends the session;
/// the runtime checks that condition before executing another queued job.
pub fn handle_request(request: Request) -> Result<Option<Response>, EngineFailure> {
    services::with::<Application, _>(|application| {
        if let Some(error) = application.fatal_error() {
            return Err(error);
        }
        let id = request.id();
        apply_request(request)
            .map_err(|error| application.report_fatal_error(error.at(format_args!("request {id}"))))
    })
}

fn apply_request(request: Request) -> Result<Option<Response>, SyncError> {
    match request {
        Request::ModelInitRequest {
            id,
            serialized_model,
        } => {
            // 1. Decode the complete tree before installing it as the project.
            let model = ModelRef::new(serde_json::from_str::<ProjectModel>(&serialized_model)?);
            // 2. Install the new root. Future initialization hooks must be able
            // to find this tree through services before any of them are called.
            let old = services::with::<ProjectSlot, _>(|slot| slot.replace(Some(model)));
            // 3. The slot borrow is released. Cleanup of the previous tree is
            // safe here; behavior initialization and observers will follow it.
            drop(old);
            Ok(Some(Response::ModelInitResponse {
                id,
                success: true,
                error: None,
            }))
        }
        Request::ModelUpdateRequest {
            update_kind,
            field_accesses,
            serialized_value,
            ..
        } => {
            if field_accesses.is_empty() {
                return Err(SyncError::new("Model update path is empty"));
            }
            let mut project = project()?;
            // 1–2. Generated code routes the update; the leaf decodes its value
            // and mutates only the field or collection that owns the operation.
            let change = project.apply_update(ModelUpdate {
                path: &field_accesses,
                kind: update_kind,
                json: serialized_value.as_deref(),
            })?;
            // 3. All model borrows have ended. Finish removal before adding
            // initialization hooks and field observers at this same boundary.
            // 4–6. Deferred removal now; initialization and notification follow
            // in the behavior checkpoint. Do not post them behind another update.
            change.finish();
            Ok(None)
        }
        Request::GetSerializedModelFromEngineRequest { id } => {
            let serialized_model = with_project(serde_json::to_string)??;
            Ok(Some(Response::GetSerializedModelFromEngineResponse {
                id,
                serialized_model,
            }))
        }
        _ => Ok(None),
    }
}
