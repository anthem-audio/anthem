// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

use anthem_engine::messages::{
    AudioProcessingConfigDto, IpcEvent, IpcMessage, Request, Response, VisualizationItem,
};
use serde_json::{Value, json};

#[path = "../src/generated/test/fixtures/rust_message_fixture.rs"]
mod fixture;

#[test]
fn round_trips_dart_messages_and_their_roles() {
    let snapshots: Vec<Value> =
        serde_json::from_str(include_str!("fixtures/messages.json")).unwrap();
    for snapshot in snapshots {
        let message: IpcMessage = serde_json::from_value(snapshot.clone()).unwrap();
        assert_eq!(serde_json::to_value(message).unwrap(), snapshot);
        let matching_roles = [
            serde_json::from_value::<Request>(snapshot.clone()).and_then(serde_json::to_value),
            serde_json::from_value::<Response>(snapshot.clone()).and_then(serde_json::to_value),
            serde_json::from_value::<IpcEvent>(snapshot.clone()).and_then(serde_json::to_value),
        ];
        let successes: Vec<_> = matching_roles.into_iter().filter_map(Result::ok).collect();
        assert_eq!(successes, [snapshot]);
    }
}

#[test]
fn constructs_typed_requests_and_responses_without_json() {
    let request = Request::Heartbeat { id: 42 };
    assert_eq!(request.id(), 42);
    let message: IpcMessage = request.into();
    assert_eq!(
        serde_json::to_value(message).unwrap(),
        json!({"__type": "Heartbeat", "id": 42})
    );
    let response = Response::StartAudioResponse {
        id: 3,
        success: true,
        error: None,
        audio_config: Some(AudioProcessingConfigDto {
            sample_rate: 48000.0,
            block_size: 256,
            input_channel_count: 0,
            output_channel_count: 2,
        }),
    };
    assert_eq!(response.id(), 3);
    let encoded = serde_json::to_value(response).unwrap();
    assert_eq!(encoded["audioConfig"]["blockSize"], 256);
    assert!(encoded.get("error").is_none());
    fn assert_send<T: Send>() {}
    assert_send::<IpcMessage>();
    assert_send::<Request>();
    assert_send::<Response>();
}

#[test]
fn nested_sealed_hierarchies_keep_inherited_fields() {
    let snapshots: Vec<Value> =
        serde_json::from_str(include_str!("fixtures/sealed_messages.json")).unwrap();
    for snapshot in snapshots {
        let message: fixture::FixtureMessage = serde_json::from_value(snapshot.clone()).unwrap();
        assert!(message.version() > 0);
        assert_eq!(serde_json::to_value(message).unwrap(), snapshot);
        if snapshot["__type"] != "FixtureEvent" {
            let request: fixture::FixtureRequest =
                serde_json::from_value(snapshot.clone()).unwrap();
            assert!(request.id() >= 10);
            let _ = request.routing();
            let parent: fixture::FixtureMessage = request.into();
            assert_eq!(serde_json::to_value(parent).unwrap(), snapshot);
        }
    }
}

#[test]
fn rejects_unknown_discriminators_missing_fields_and_wrong_roles() {
    for value in [
        json!({"__type":"Unknown", "id":1}),
        json!({"id":1}),
        json!({"__type":"Heartbeat"}),
        json!({"__type":"Heartbeat", "id":"wrong"}),
    ] {
        assert!(serde_json::from_value::<IpcMessage>(value).is_err());
    }
    assert!(serde_json::from_value::<Response>(json!({"__type":"Heartbeat", "id":1})).is_err());
    assert!(serde_json::from_value::<IpcEvent>(json!({"__type":"Heartbeat", "id":1})).is_err());
}

#[test]
fn round_trips_standalone_payload_records_and_collection_unions() {
    let snapshots: Vec<Value> =
        serde_json::from_str(include_str!("fixtures/message_payloads.json")).unwrap();
    for snapshot in snapshots {
        let payload: VisualizationItem = serde_json::from_value(snapshot.clone()).unwrap();
        assert_eq!(serde_json::to_value(payload).unwrap(), snapshot);
    }
}
