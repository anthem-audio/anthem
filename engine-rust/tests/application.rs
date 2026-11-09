// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

use anthem_engine::core::{Application, EngineRuntime, services};
use std::sync::{
    Arc,
    atomic::{AtomicBool, Ordering},
};

#[test]
fn fatal_errors_preserve_the_first_cause_and_stop_later_jobs() {
    let (runtime, handle) = EngineRuntime::new();
    handle
        .post(|| {
            services::with::<Application, _>(|app| {
                let first = app.report_fatal_error(std::io::Error::other("Connection failed"));
                let second = app.report_fatal_error("Cleanup failed");
                assert_eq!(first.to_string(), second.to_string());
            })
        })
        .unwrap();
    let ran = Arc::new(AtomicBool::new(false));
    let later = ran.clone();
    handle
        .post(move || later.store(true, Ordering::Relaxed))
        .unwrap();
    assert_eq!(runtime.run().unwrap_err().to_string(), "Connection failed");
    assert!(!ran.load(Ordering::Relaxed));
    assert!(handle.post(|| {}).is_err());

    let (runtime, handle) = EngineRuntime::new();
    handle
        .post(|| services::with::<Application, _>(Application::shutdown))
        .unwrap();
    runtime.run().unwrap();
}
