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

#include "audio_session_controller.h"

#include "modules/audio/audio_block_processor.h"
#include "modules/core/audio_callback.h"
#include "modules/core/comms.h"
#include "modules/core/engine.h"
#include "modules/core/project.h"
#include "modules/processing_graph/graph_processor.h"
#include "modules/sequencer/runtime/transport.h"

#include <exception>
#include <rfl/json.hpp>
#include <utility>

namespace anthem {

AudioSessionController::AudioSessionController(std::shared_ptr<Project>& project,
    GraphProcessor& graphProcessor,
    Transport& transport,
    Comms& comms,
    AudioBlockProcessor& audioBlockProcessor,
    std::function<void()> resetInitializedProcessingGraphNodes)
  : project(project), graphProcessor(graphProcessor), transport(transport), comms(comms),
    audioBlockProcessor(audioBlockProcessor),
    resetInitializedProcessingGraphNodes(std::move(resetInitializedProcessingGraphNodes)) {}

AudioSessionController::~AudioSessionController() {
  stopAudio();
}

std::optional<AudioProcessingConfig> AudioSessionController::startRealtimeAudio() {
  if (isRenderAudioSessionRunning()) {
    juce::Logger::writeToLog("Cannot start the realtime audio callback while render audio session "
                             "is active.");
    return std::nullopt;
  }

  if (isRealtimeAudioRunning()) {
    juce::Logger::writeToLog("Tried to start audio callback when it was already running. This "
                             "probably doesn't break anything, but it's definitely a bug.");
    return getCurrentAudioProcessingConfig();
  }

  if (project == nullptr) {
    juce::Logger::writeToLog("Cannot start audio callback because project model is null.");
    return std::nullopt;
  }

  juce::Logger::writeToLog("Creating audio callback...");

  try {
    audioCallback = std::make_unique<AudioCallback>(*project, audioBlockProcessor, *this);
  } catch (const std::exception& e) {
    juce::Logger::writeToLog("Failed to create audio callback: " + juce::String(e.what()));
    return std::nullopt;
  }

  juce::Logger::writeToLog("Initializing audio device manager...");
  juce::Logger::writeToLog("Listing available audio devices...");
  auto& deviceTypes = audioDeviceManager.getAvailableDeviceTypes();
  juce::Logger::writeToLog(
      "Found " + juce::String(static_cast<int>(deviceTypes.size())) + " device types:");
  for (int i = 0; i < deviceTypes.size(); i++) {
    auto* deviceType = deviceTypes[i];
    juce::Logger::writeToLog(" - " + deviceType->getTypeName());
  }

  // Initialize the audio device manager with 2 input and 2 output channels
  auto initError = audioDeviceManager.initialiseWithDefaultDevices(2, 2);
  if (initError.isNotEmpty()) {
    juce::Logger::writeToLog("initialiseWithDefaultDevices(2, 2) failed: " + initError);
    juce::Logger::writeToLog("Retrying with 0 input channels and 2 output channels...");

    initError = audioDeviceManager.initialiseWithDefaultDevices(0, 2);
  }

  if (initError.isNotEmpty()) {
    juce::Logger::writeToLog("initialiseWithDefaultDevices() failed again: " + initError);
    return std::nullopt;
  }

  auto* device = audioDeviceManager.getCurrentAudioDevice();
  if (device == nullptr) {
    juce::Logger::writeToLog(
        "Audio device manager initialized, but no current audio device is available.");
    return std::nullopt;
  }

  auto audioProcessingConfig = refreshAudioProcessingConfigForDevice(*device);
  if (!audioProcessingConfig.has_value()) {
    juce::Logger::writeToLog("Failed to refresh processing config for current device.");
    return std::nullopt;
  }

  juce::Logger::writeToLog("Selected audio device: " + device->getName());
  juce::Logger::writeToLog("Sample rate: " + juce::String(audioProcessingConfig->sampleRate));
  juce::Logger::writeToLog("Buffer size: " + juce::String(audioProcessingConfig->blockSize));
  juce::Logger::writeToLog(
      "Active output channels: " + juce::String(audioProcessingConfig->outputChannelCount));

  audioDeviceManager.addAudioCallback(audioCallback.get());
  juce::Logger::writeToLog("Audio callback registered with device manager.");

  isRealtimeAudioRunningFlag.store(true, std::memory_order_release);

  return audioProcessingConfig;
}

std::optional<AudioProcessingConfig> AudioSessionController::startRenderAudioSession(
    double sampleRate, int64_t blockSize, int64_t outputChannelCount) {
  if (isRealtimeAudioRunning()) {
    juce::Logger::writeToLog(
        "Cannot start render audio session while realtime audio callback is running.");
    return std::nullopt;
  }

  if (isRenderAudioSessionRunning()) {
    juce::Logger::writeToLog("Render audio session is already active.");
    return getCurrentAudioProcessingConfig();
  }

  auto audioProcessingConfig = AudioProcessingConfig{
      .sampleRate = sampleRate,
      .blockSize = static_cast<int>(blockSize),
      .inputChannelCount = 0,
      .outputChannelCount = static_cast<int>(outputChannelCount),
  };

  if (!audioProcessingConfig.isValid()) {
    juce::Logger::writeToLog("Cannot start render audio session with invalid audio config.");
    return std::nullopt;
  }

  setCurrentAudioProcessingConfig(audioProcessingConfig);
  prepareForAudioProcessingConfig(audioProcessingConfig, GraphWorkerSchedulingMode::normal);
  isRenderAudioSessionActive = true;

  juce::Logger::writeToLog("Started render audio session.");
  return audioProcessingConfig;
}

void AudioSessionController::stopAudio() {
  if (isRealtimeAudioRunningFlag.exchange(false, std::memory_order_acq_rel)) {
    audioDeviceManager.removeAudioCallback(audioCallback.get());
    audioDeviceManager.closeAudioDevice();
  }

  isRenderAudioSessionActive = false;
  audioCallback.reset();
  graphProcessor.clearRuntimeGraph();
  resetInitializedProcessingGraphNodes();
  clearCurrentAudioProcessingConfig();
}

uint64_t AudioSessionController::setCurrentAudioProcessingConfig(
    AudioProcessingConfig audioProcessingConfig) {
  jassert(audioProcessingConfig.isValid());
  if (!audioProcessingConfig.isValid()) {
    clearCurrentAudioProcessingConfig();
    return getAudioProcessingConfigGeneration();
  }

  std::scoped_lock lock(audioProcessingConfigMutex);

  currentAudioProcessingConfig = audioProcessingConfig;
  return audioProcessingConfigGeneration.fetch_add(1, std::memory_order_acq_rel) + 1;
}

void AudioSessionController::clearCurrentAudioProcessingConfig() {
  std::scoped_lock lock(audioProcessingConfigMutex);
  currentAudioProcessingConfig = std::nullopt;
  audioProcessingConfigGeneration.fetch_add(1, std::memory_order_acq_rel);
}

void AudioSessionController::prepareForAudioProcessingConfig(
    const AudioProcessingConfig& audioProcessingConfig,
    GraphWorkerSchedulingMode workerSchedulingMode) {
  graphProcessor.prepareForAudioProcessingConfig(audioProcessingConfig, workerSchedulingMode);
  transport.prepareToProcess();
  juce::Logger::writeToLog("Prepared engine for audio processing config.");
}

void AudioSessionController::sendAudioSessionInvalidatedEvent(std::optional<std::string> reason) {
  Response response = AudioSessionInvalidatedEvent{
      .reason = std::move(reason),
      .responseBase = ResponseBase{.id = -1},
  };

  auto responseText = rfl::json::write(response);
  comms.send(responseText);
  juce::Logger::writeToLog("AudioSessionInvalidatedEvent sent to UI.");
}

void AudioSessionController::notifyAudioSessionInvalidatedOnMessageThread(
    std::optional<std::string> reason, uint64_t invalidatedGeneration) {
  jassert(juce::MessageManager::getInstance()->isThisTheMessageThread());

  if (!isRealtimeAudioRunning()) {
    return;
  }

  if (getAudioProcessingConfigGeneration() != invalidatedGeneration) {
    return;
  }

  sendAudioSessionInvalidatedEvent(std::move(reason));
}

void AudioSessionController::requestAudioSessionInvalidation(std::optional<std::string> reason) {
  if (!isRealtimeAudioRunning()) {
    return;
  }

  clearCurrentAudioProcessingConfig();
  const auto invalidatedGeneration = getAudioProcessingConfigGeneration();

  if (juce::MessageManager::getInstance()->isThisTheMessageThread()) {
    notifyAudioSessionInvalidatedOnMessageThread(std::move(reason), invalidatedGeneration);
    return;
  }

  juce::MessageManager::callAsync([reason = std::move(reason), invalidatedGeneration]() mutable {
    if (!Engine::hasInstance()) {
      return;
    }

    auto& engine = Engine::getInstance();
    if (engine.audioSessionController == nullptr) {
      return;
    }

    engine.audioSessionController->notifyAudioSessionInvalidatedOnMessageThread(
        std::move(reason), invalidatedGeneration);
  });
}

std::optional<AudioProcessingConfig> AudioSessionController::refreshAudioProcessingConfigForDevice(
    juce::AudioIODevice& device) {
  auto audioProcessingConfig = AudioProcessingConfig{
      .sampleRate = device.getCurrentSampleRate(),
      .blockSize = device.getCurrentBufferSizeSamples(),
      .inputChannelCount = device.getActiveInputChannels().countNumberOfSetBits(),
      .outputChannelCount = device.getActiveOutputChannels().countNumberOfSetBits(),
  };

#if JUCE_MAC
  audioProcessingConfig.macAudioWorkgroup = device.getWorkgroup();
#endif

  if (!audioProcessingConfig.isValid()) {
    juce::Logger::writeToLog("Failed to build processing config for audio device.");
    clearCurrentAudioProcessingConfig();
    return std::nullopt;
  }

  setCurrentAudioProcessingConfig(audioProcessingConfig);
  prepareForAudioProcessingConfig(audioProcessingConfig, GraphWorkerSchedulingMode::realtime);
  return audioProcessingConfig;
}

std::optional<AudioProcessingConfig>
AudioSessionController::getCurrentAudioProcessingConfig() const {
  std::scoped_lock lock(audioProcessingConfigMutex);
  return currentAudioProcessingConfig;
}

std::optional<AudioProcessingConfigSnapshot>
AudioSessionController::getCurrentAudioProcessingConfigSnapshot() const {
  std::scoped_lock lock(audioProcessingConfigMutex);
  if (!currentAudioProcessingConfig.has_value()) {
    return std::nullopt;
  }

  return AudioProcessingConfigSnapshot{
      .config = currentAudioProcessingConfig.value(),
      .generation = audioProcessingConfigGeneration.load(std::memory_order_acquire),
  };
}

uint64_t AudioSessionController::getAudioProcessingConfigGeneration() const {
  return audioProcessingConfigGeneration.load(std::memory_order_acquire);
}

} // namespace anthem
