// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

fn main() {
    println!("cargo:rerun-if-changed=src/audio/web_bridge.c");
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("emscripten") {
        cc::Build::new()
            .file("src/audio/web_bridge.c")
            .flag("-pthread")
            .flag("-sWASM_WORKERS=1")
            .compile("anthem_web_audio");
    }
}
