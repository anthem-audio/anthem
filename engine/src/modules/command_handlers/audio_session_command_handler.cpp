/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

#include "audio_session_command_handler.h"

#include "modules/core/audio_processing_config.h"
#include "modules/core/engine.h"

#include <memory>

namespace anthem {

namespace {
std::optional<std::shared_ptr<AudioProcessingConfigDto>> toDtoOptional(
    const std::optional<AudioProcessingConfig>& audioProcessingConfig) {
  if (!audioProcessingConfig.has_value()) {
    return std::nullopt;
  }

  return audioProcessingConfig->toDto();
}
} // namespace

std::optional<Response> handleAudioSessionCommand(Request& request) {
  auto& engine = Engine::getInstance();

  if (rfl::holds_alternative<StartAudioRequest>(request.variant())) {
    auto& requestAsStartAudio = rfl::get<StartAudioRequest>(request.variant());

    juce::Logger::writeToLog("Starting audio callback after model init...");
    auto audioProcessingConfig = engine.audioSessionController->startRealtimeAudio();
    juce::Logger::writeToLog("startRealtimeAudio() returned.");

    auto startAudioReply = StartAudioResponse{.success = audioProcessingConfig.has_value(),
        .error = audioProcessingConfig.has_value()
                     ? std::nullopt
                     : std::optional<std::string>("Failed to initialize audio device."),
        .audioConfig = toDtoOptional(audioProcessingConfig),
        .responseBase = ResponseBase{.id = requestAsStartAudio.requestBase.get().id}};

    return std::optional(std::move(startAudioReply));
  }

  if (rfl::holds_alternative<StartRenderAudioSessionRequest>(request.variant())) {
    auto& requestAsStartRenderAudioSession =
        rfl::get<StartRenderAudioSessionRequest>(request.variant());

    juce::Logger::writeToLog("Starting render audio session...");
    auto audioProcessingConfig = engine.audioSessionController->startRenderAudioSession(
        requestAsStartRenderAudioSession.sampleRate,
        requestAsStartRenderAudioSession.blockSize,
        requestAsStartRenderAudioSession.outputChannelCount);
    juce::Logger::writeToLog("startRenderAudioSession() returned.");

    auto startRenderAudioSessionReply = StartRenderAudioSessionResponse{
        .success = audioProcessingConfig.has_value(),
        .error = audioProcessingConfig.has_value()
                     ? std::nullopt
                     : std::optional<std::string>("Failed to start render audio session."),
        .audioConfig = toDtoOptional(audioProcessingConfig),
        .responseBase = ResponseBase{.id = requestAsStartRenderAudioSession.requestBase.get().id}};

    return std::optional(std::move(startRenderAudioSessionReply));
  }

  if (rfl::holds_alternative<StopAudioRequest>(request.variant())) {
    auto& requestAsStopAudio = rfl::get<StopAudioRequest>(request.variant());

    juce::Logger::writeToLog("Stopping audio callback...");
    engine.audioSessionController->stopAudio();
    juce::Logger::writeToLog("stopAudio() returned.");

    auto stopAudioReply = StopAudioResponse{.success = true,
        .error = std::nullopt,
        .responseBase = ResponseBase{.id = requestAsStopAudio.requestBase.get().id}};

    return std::optional(std::move(stopAudioReply));
  }

  if (rfl::holds_alternative<RenderAudioRequest>(request.variant())) {
    auto& requestAsRenderAudio = rfl::get<RenderAudioRequest>(request.variant());

    juce::Logger::writeToLog("Starting render...");
    auto renderResult = engine.renderController->startRender(RenderStartOptions{
        .renderId = requestAsRenderAudio.renderId,
        .outputPath = requestAsRenderAudio.outputPath,
        .format = requestAsRenderAudio.format,
        .startTick = requestAsRenderAudio.startTick,
        .endTick = requestAsRenderAudio.endTick,
        .includeTail = requestAsRenderAudio.includeTail,
        .bitDepth = requestAsRenderAudio.bitDepth,
        .qualityOptionIndex = requestAsRenderAudio.qualityOptionIndex,
        .sampleFormat = requestAsRenderAudio.sampleFormat,
    });
    juce::Logger::writeToLog("startRender() returned.");

    auto renderAudioReply = RenderAudioResponse{.success = renderResult.success,
        .error = renderResult.error,
        .renderId = requestAsRenderAudio.renderId,
        .responseBase = ResponseBase{.id = requestAsRenderAudio.requestBase.get().id}};

    return std::optional(std::move(renderAudioReply));
  }

  return std::nullopt;
}

} // namespace anthem
