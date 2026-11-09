// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

mod blocks;
#[cfg(not(target_os = "emscripten"))]
mod native;
#[cfg(target_os = "emscripten")]
pub(crate) mod web;

#[cfg(not(target_os = "emscripten"))]
pub(crate) use native::Stream;
#[cfg(target_os = "emscripten")]
pub(crate) use web::Stream;

pub(crate) const BLOCK_FRAMES: usize = 128;

#[derive(Clone, Copy)]
pub(crate) struct Config {
    pub sample_rate: u32,
    pub output_channels: u16,
}

fn render_block(output: &mut [f32]) {
    output.fill(0.0);
}
