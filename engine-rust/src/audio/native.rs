// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

// cspell:ignore xrun

use std::sync::{
    Arc,
    atomic::{AtomicBool, Ordering},
};
use std::time::Duration;

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{ErrorKind, FromSample, SampleFormat, SizedSample, StreamConfig};

use super::{Config, blocks::FixedBlocks, render_block};

pub(crate) struct Stream {
    stream: cpal::Stream,
    failed: Arc<AtomicBool>,
}

impl Stream {
    pub(crate) async fn open() -> Result<(Self, Config), String> {
        let device = cpal::default_host()
            .default_output_device()
            .ok_or("No default audio output device is available.")?;
        let supported = device
            .default_output_config()
            .map_err(|error| error.to_string())?;
        let config = supported.config();
        let failed = Arc::new(AtomicBool::new(false));
        let stream = match supported.sample_format() {
            SampleFormat::I8 => build::<i8>(&device, config, failed.clone()),
            SampleFormat::I16 => build::<i16>(&device, config, failed.clone()),
            SampleFormat::I24 => build::<cpal::I24>(&device, config, failed.clone()),
            SampleFormat::I32 => build::<i32>(&device, config, failed.clone()),
            SampleFormat::I64 => build::<i64>(&device, config, failed.clone()),
            SampleFormat::U8 => build::<u8>(&device, config, failed.clone()),
            SampleFormat::U16 => build::<u16>(&device, config, failed.clone()),
            SampleFormat::U24 => build::<cpal::U24>(&device, config, failed.clone()),
            SampleFormat::U32 => build::<u32>(&device, config, failed.clone()),
            SampleFormat::U64 => build::<u64>(&device, config, failed.clone()),
            SampleFormat::F32 => build::<f32>(&device, config, failed.clone()),
            SampleFormat::F64 => build::<f64>(&device, config, failed.clone()),
            format => {
                return Err(format!(
                    "Unsupported audio output sample format: {format:?}."
                ));
            }
        }
        .map_err(|error| error.to_string())?;
        Ok((
            Self { stream, failed },
            Config {
                sample_rate: config.sample_rate,
                output_channels: config.channels,
            },
        ))
    }

    pub(crate) fn start(&mut self) -> Result<(), String> {
        self.stream.play().map_err(|error| error.to_string())
    }

    pub(crate) fn has_failed(&self) -> bool {
        self.failed.load(Ordering::Acquire)
    }
}

fn build<T: SizedSample + FromSample<f32> + Send + 'static>(
    device: &cpal::Device,
    config: StreamConfig,
    failed: Arc<AtomicBool>,
) -> Result<cpal::Stream, cpal::Error> {
    let channels = usize::from(config.channels);
    let mut blocks = FixedBlocks::new(channels);
    device.build_output_stream(
        config,
        move |output: &mut [T], _| {
            let frames = output.len() / channels;
            output[frames * channels..].fill(T::EQUILIBRIUM);
            blocks.write(frames, render_block, |frame, samples| {
                let start = frame * channels;
                let destination = &mut output[start..start + samples.len()];
                for (destination, &sample) in destination.iter_mut().zip(samples) {
                    *destination = T::from_sample(sample);
                }
            });
        },
        move |error| match error.kind() {
            ErrorKind::Xrun | ErrorKind::DeviceChanged | ErrorKind::RealtimeDenied => {}
            _ => failed.store(true, Ordering::Release),
        },
        Some(Duration::from_secs(3)),
    )
}
