// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

use std::future::Future;

use crate::audio::BLOCK_FRAMES;
use crate::core::{audio_session::AudioSession, services};
use crate::messages::{AudioProcessingConfigDto, Response};

pub(super) fn start(id: i64) -> impl Future<Output = Response> {
    let start = services::get::<AudioSession>().start();
    async move {
        let (audio_config, error) = match start.await {
            Ok(config) => (
                Some(AudioProcessingConfigDto {
                    sample_rate: f64::from(config.sample_rate),
                    block_size: BLOCK_FRAMES as i64,
                    input_channel_count: 0,
                    output_channel_count: i64::from(config.output_channels),
                }),
                None,
            ),
            Err(error) => (None, Some(error)),
        };
        Response::StartAudioResponse {
            id,
            success: audio_config.is_some(),
            error,
            audio_config,
        }
    }
}

pub(super) fn stop(id: i64) -> Response {
    services::with::<AudioSession, _>(AudioSession::stop);
    Response::StopAudioResponse {
        id,
        success: true,
        error: None,
    }
}
