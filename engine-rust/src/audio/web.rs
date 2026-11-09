// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

use std::ffi::c_void;
use std::ptr::NonNull;
use std::sync::atomic::{AtomicU32, Ordering};
use std::time::{Duration, Instant};

use super::{Config, blocks::FixedBlocks, render_block};

const CHANNELS: u16 = 2;
static RENDERED_BLOCKS: AtomicU32 = AtomicU32::new(0);

unsafe extern "C" {
    fn anthem_web_audio_prepare();
    fn anthem_web_audio_sample_rate() -> i32;
    fn anthem_web_audio_attach(state: *mut c_void);
    fn anthem_web_audio_detach();
    fn anthem_web_audio_in_callback() -> i32;
    fn anthem_web_audio_close();
    fn anthem_web_audio_close_result() -> i32;
}

pub(crate) struct Stream {
    renderer: NonNull<FixedBlocks>,
    attached: bool,
}

impl Stream {
    pub(crate) async fn open() -> Result<(Self, Config), String> {
        unsafe { anthem_web_audio_prepare() };
        let sample_rate = tokio::time::timeout(Duration::from_secs(5), async {
            loop {
                match unsafe { anthem_web_audio_sample_rate() } {
                    0 => tokio::time::sleep(Duration::from_millis(5)).await,
                    rate if rate > 0 => return Ok(rate as u32),
                    _ => return Err("Could not initialize the browser AudioWorklet."),
                }
            }
        })
        .await
        .map_err(|_| "Browser audio initialization timed out.")??;
        Ok((
            Self {
                renderer: NonNull::from(Box::leak(Box::new(FixedBlocks::new(usize::from(
                    CHANNELS,
                ))))),
                attached: false,
            },
            Config {
                sample_rate,
                output_channels: CHANNELS,
            },
        ))
    }

    pub(crate) fn start(&mut self) -> Result<(), String> {
        unsafe { anthem_web_audio_attach(self.renderer.as_ptr().cast()) };
        self.attached = true;
        Ok(())
    }

    pub(crate) fn has_failed(&self) -> bool {
        unsafe { anthem_web_audio_sample_rate() < 0 }
    }
}

impl Drop for Stream {
    fn drop(&mut self) {
        if self.attached {
            unsafe { anthem_web_audio_detach() };
            // Keep the allocation alive until the worklet has finished using
            // it. New callbacks see the detached state and render silence.
            while unsafe { anthem_web_audio_in_callback() } != 0 {
                std::thread::sleep(Duration::from_millis(1));
            }
        }
        unsafe { drop(Box::from_raw(self.renderer.as_ptr())) };
    }
}

pub(crate) fn request_shutdown() {
    unsafe { anthem_web_audio_close() };
}

pub(crate) fn shutdown() -> Result<(), &'static str> {
    request_shutdown();
    let deadline = Instant::now() + Duration::from_secs(3);
    loop {
        match unsafe { anthem_web_audio_close_result() } {
            1 => return Ok(()),
            -1 => return Err("Could not close the browser audio context."),
            _ if Instant::now() >= deadline => return Err("Browser audio shutdown timed out."),
            _ => std::thread::sleep(Duration::from_millis(5)),
        }
    }
}

#[unsafe(no_mangle)]
unsafe extern "C" fn anthem_render_audio(state: *mut c_void, output: *mut f32, frames: u32) {
    let frames = frames as usize;
    let channels = usize::from(CHANNELS);
    // The bridge supplies a live renderer and one planar output buffer with
    // exactly CHANNELS channels. The worklet has exclusive access to both.
    let renderer = unsafe { &mut *state.cast::<FixedBlocks>() };
    let output = unsafe { std::slice::from_raw_parts_mut(output, frames * channels) };
    renderer.write(
        frames,
        |block| {
            render_block(block);
            RENDERED_BLOCKS.fetch_add(1, Ordering::Relaxed);
        },
        |frame, samples| {
            for (index, sample) in samples.iter().enumerate() {
                output[index % channels * frames + frame + index / channels] = *sample;
            }
        },
    );
}

#[unsafe(no_mangle)]
extern "C" fn getAudioRenderedBlocks() -> u32 {
    RENDERED_BLOCKS.load(Ordering::Relaxed)
}
