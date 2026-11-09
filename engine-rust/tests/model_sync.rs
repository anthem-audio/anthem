// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

use anthem_engine::messages::Request;
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
