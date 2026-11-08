// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

use std::sync::{
    Arc,
    atomic::{AtomicBool, Ordering},
    mpsc,
};
use std::thread;
use std::time::Duration;

use anthem_engine::core::{
    Application, EngineRuntime,
    model_sync::{handle_request, with_project},
    services,
};
use anthem_engine::messages::{FieldAccess, FieldType, FieldUpdateKind, Request, Response};
use anthem_engine::model::{
    self,
    sync::{ModelUpdate, ModelValue},
};
use serde_json::{Value, json};

#[path = "../src/generated/test/fixtures/rust_model_fixture.rs"]
mod fixture;

fn cases() -> Value {
    serde_json::from_str(include_str!("fixtures/model_updates.json")).unwrap()
}

#[test]
fn applies_dart_requests_through_the_runtime_and_stops_on_fatal_errors() {
    let case = &cases()["project"];
    let (engine, handle) = EngineRuntime::new();
    let (send, responses) = mpsc::channel();
    let mut requests =
        vec![serde_json::from_value::<Request>(case["initializeRequest"].clone()).unwrap()];
    for step in case["steps"].as_array().unwrap() {
        requests.push(serde_json::from_value(step["request"].clone()).unwrap());
    }
    requests.push(Request::GetSerializedModelFromEngineRequest { id: 1000 });
    let message_thread = thread::current().id();
    thread::spawn(move || {
        for request in requests {
            let send = send.clone();
            handle
                .post(move || {
                    let response = handle_request(request).unwrap();
                    // Query through the installed project service after every update.
                    // This also verifies that mutation has released its model borrows.
                    let tempo = with_project(|project| {
                        project.sequence().with(|s| s.beats_per_minute_raw())
                    })
                    .unwrap();
                    send.send((response, tempo, thread::current().id()))
                        .unwrap();
                })
                .unwrap();
        }
        handle.shutdown();
    })
    .join()
    .unwrap();
    engine.run().unwrap();
    let responses: Vec<_> = responses.into_iter().collect();
    assert!(responses.iter().all(|(_, _, id)| *id == message_thread));
    assert!(matches!(
        responses[0].0,
        Some(Response::ModelInitResponse { success: true, .. })
    ));
    assert_eq!(responses.last().unwrap().1, 13550);
    let Some(Response::GetSerializedModelFromEngineResponse {
        id,
        serialized_model,
    }) = &responses.last().unwrap().0
    else {
        panic!("missing model query response")
    };
    assert_eq!(*id, 1000);
    assert_eq!(
        serde_json::from_str::<Value>(serialized_model).unwrap(),
        case["final"]
    );

    // A fatal update must stop the runtime before a later queued job can run.
    // Run fresh sessions for failures before initialization, during initialization,
    // and after the model has been installed.
    for initial in [
        None,
        Some("not JSON".to_owned()),
        Some(serde_json::to_string(&case["initial"]).unwrap()),
    ] {
        let (engine, handle) = EngineRuntime::new();
        let (send, errors) = mpsc::channel();
        if let Some(serialized_model) = initial {
            let send = send.clone();
            handle
                .post(move || {
                    if let Err(error) = handle_request(Request::ModelInitRequest {
                        id: 1,
                        serialized_model,
                    }) {
                        send.send(error.to_string()).unwrap();
                    }
                })
                .unwrap();
        }
        handle
            .post(move || {
                let error = handle_request(Request::ModelUpdateRequest {
                    id: 2,
                    update_kind: FieldUpdateKind::Set,
                    field_accesses: vec![FieldAccess {
                        field_type: FieldType::Raw,
                        field_name: Some("missing".into()),
                        list_index: None,
                        serialized_map_key: None,
                    }],
                    serialized_value: Some("1".into()),
                })
                .unwrap_err();
                send.send(error.to_string()).unwrap();
            })
            .unwrap();
        let ran = Arc::new(AtomicBool::new(false));
        let later = Arc::clone(&ran);
        handle
            .post(move || later.store(true, Ordering::Relaxed))
            .unwrap();
        handle.shutdown();
        assert!(engine.run().is_err());
        assert!(
            !errors
                .recv_timeout(Duration::from_secs(5))
                .unwrap()
                .is_empty()
        );
        assert!(!ran.load(Ordering::Relaxed));
        assert!(handle.post(|| {}).is_err());
    }

    // Other subsystems use the same failure signal. Preserve the first cause,
    // reject further requests in this job, and skip all later queued jobs.
    let (engine, handle) = EngineRuntime::new();
    let serialized_model = serde_json::to_string(&case["initial"]).unwrap();
    handle
        .post(move || {
            let first = services::with::<Application, _>(|application| {
                application.report_fatal_error(std::io::Error::other("IPC connection failed"))
            });
            let second = services::with::<Application, _>(|application| {
                application.report_fatal_error("secondary cleanup failure")
            });
            assert_eq!(second.to_string(), first.to_string());
            let error = handle_request(Request::ModelInitRequest {
                id: 10,
                serialized_model,
            })
            .unwrap_err();
            assert_eq!(error.to_string(), first.to_string());
            assert!(with_project(|_| ()).is_err());
        })
        .unwrap();
    let ran = Arc::new(AtomicBool::new(false));
    let later = Arc::clone(&ran);
    handle
        .post(move || later.store(true, Ordering::Relaxed))
        .unwrap();
    handle.shutdown();
    assert_eq!(
        engine.run().unwrap_err().to_string(),
        "IPC connection failed"
    );
    assert!(!ran.load(Ordering::Relaxed));
    assert!(handle.post(|| {}).is_err());

    // Failure belongs to one runtime session. Ordinary shutdown of a fresh
    // session still succeeds after an earlier session has failed.
    let (engine, handle) = EngineRuntime::new();
    handle
        .post(|| services::with::<Application, _>(Application::shutdown))
        .unwrap();
    engine.run().unwrap();
}

#[test]
fn nested_collections_and_unions_match_dart_after_each_update() {
    let case = &cases()["nested"];
    let mut model: fixture::RustSyncFixture =
        serde_json::from_value(case["initial"].clone()).unwrap();
    let mut retained = None;
    for (index, step) in case["steps"].as_array().unwrap().iter().enumerate() {
        let Request::ModelUpdateRequest {
            update_kind,
            field_accesses,
            serialized_value,
            ..
        } = serde_json::from_value(step["request"].clone()).unwrap()
        else {
            panic!("expected update")
        };
        model
            .apply_update(ModelUpdate {
                path: &field_accesses,
                kind: update_kind,
                json: serialized_value.as_deref(),
            })
            .unwrap()
            .finish();
        assert_eq!(
            serde_json::to_value(&model).unwrap(),
            step["expected"],
            "request: {}",
            step["request"]
        );
        if index == 1 {
            retained = Some(model.nested()[0].values().next().unwrap()[0].clone());
        }
        if index == 2 || index == 4 {
            // A deep edit updates the existing instance. Replacing the entry
            // creates a new instance while a retained old handle stays readable.
            retained
                .as_ref()
                .unwrap()
                .with(|child| assert_eq!(child.value(), 11));
        }
    }
}

#[test]
fn rejects_invalid_accesses_operations_and_values() {
    let initial = cases()["nested"]["initial"].clone();
    let raw = |name| json!({"fieldType":"raw", "fieldName":name});
    for (kind, path, value) in [
        ("set", vec![raw("unknown")], Some("1")),
        ("set", vec![raw("uiOnly")], Some("\"hidden\"")),
        ("set", vec![raw("text"), raw("deeper")], Some("\"x\"")),
        ("set", vec![raw("optional"), raw("deeper")], Some("1")),
        ("set", vec![raw("text")], None),
        ("set", vec![raw("text")], Some("123")),
        ("set", vec![raw("mode")], Some("\"invalid\"")),
        ("remove", vec![raw("text")], None),
        (
            "add",
            vec![raw("nested"), json!({"fieldType":"list", "listIndex":-1})],
            Some("{}"),
        ),
        (
            "add",
            vec![raw("nested"), json!({"fieldType":"list", "listIndex":1})],
            Some("{}"),
        ),
        (
            "set",
            vec![
                raw("nested"),
                json!({"fieldType":"map", "serializedMapKey":"\"x\""}),
            ],
            Some("{}"),
        ),
    ] {
        let request: Request = serde_json::from_value(json!({"__type":"ModelUpdateRequest", "id":1, "updateKind":kind, "fieldAccesses":path, "serializedValue":value})).unwrap();
        let Request::ModelUpdateRequest {
            update_kind,
            field_accesses,
            serialized_value,
            ..
        } = request
        else {
            unreachable!()
        };
        let mut model: fixture::RustSyncFixture = serde_json::from_value(initial.clone()).unwrap();
        assert!(
            model
                .apply_update(ModelUpdate {
                    path: &field_accesses,
                    kind: update_kind,
                    json: serialized_value.as_deref()
                })
                .is_err()
        );
    }
}
