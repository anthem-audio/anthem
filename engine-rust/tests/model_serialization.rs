// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

use anthem_engine::model;
use serde_json::Value;

#[path = "../src/generated/test/fixtures/rust_model_fixture.rs"]
mod fixture;

#[test]
fn round_trips_dart_engine_snapshots() {
    let snapshots: Vec<Value> =
        serde_json::from_str(include_str!("fixtures/serialization.json")).unwrap();
    for snapshot in snapshots {
        let model: fixture::RustModelFixture = serde_json::from_value(snapshot.clone()).unwrap();
        assert_eq!(serde_json::to_value(&model).unwrap(), snapshot);
        assert_eq!(model.integer_value(), i64::MAX);
        assert_eq!(model.color().a, 128);
        assert_eq!(model.children()[&42].r#type(), 3);
        assert_eq!(model.bool_map()[&true], 1);
        assert_eq!(model.nested_list()[0][1], None);
    }
    assert_eq!(
        fixture::RustModelFixture::QUOTED_LABEL,
        "A \"quoted\" label\\with\nlines"
    );
    assert_eq!(fixture::RustModelFixture::ESCAPE_LABEL, r"\back\form\u1234");
    assert_eq!(fixture::RustModelFixture::CONTROL_LABEL, "\u{8}\u{c}\0\t🎵");
}

#[test]
fn mixes_owned_records_and_shared_models_in_one_module() {
    let snapshots: Vec<Value> =
        serde_json::from_str(include_str!("fixtures/serialization.json")).unwrap();
    let mut model: fixture::RustModelFixture =
        serde_json::from_value(snapshots.last().unwrap().clone()).unwrap();
    let shared = model.shared_child().as_ref().unwrap();
    let cloned = shared.clone();
    shared.with(|original| {
        assert_eq!(original.value(), 7);
        cloned.with(|alias| assert!(std::ptr::eq(original, alias)));
    });
    model.children.insert(
        43,
        fixture::FixtureChild {
            r#type: 4,
            name: "owned".into(),
        },
    );
    assert_eq!(model.children()[&43].r#type(), 4);
    assert_eq!(model.children()[&43].name(), "owned");
}

#[test]
fn rejects_invalid_typed_data() {
    let snapshots: Vec<Value> =
        serde_json::from_str(include_str!("fixtures/serialization.json")).unwrap();
    for (field, bad_value) in [
        ("integerValue", serde_json::json!(1.5)),
        ("integerValue", serde_json::json!(u64::MAX)),
        (
            "color",
            serde_json::json!({"a": 256, "r": 0, "g": 0, "b": 0}),
        ),
        ("mode", serde_json::json!("unknown")),
        ("selection", serde_json::json!({"UnknownModel": {}})),
        (
            "children",
            serde_json::json!({"bad-key": {"type": 3, "name": "nested"}}),
        ),
    ] {
        let mut snapshot = snapshots[0].clone();
        snapshot[field] = bad_value;
        assert!(serde_json::from_value::<fixture::RustModelFixture>(snapshot).is_err());
    }
    let mut snapshot = snapshots[0].clone();
    snapshot.as_object_mut().unwrap().remove("integerValue");
    assert!(serde_json::from_value::<fixture::RustModelFixture>(snapshot).is_err());
}
