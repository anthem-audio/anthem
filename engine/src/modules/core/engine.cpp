/*
  Copyright (C) 2023 - 2026 Joshua Wade

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

#include "modules/core/engine.h"

#include "modules/core/adapters/transport_adapters.h"
#include "modules/core/processing_graph_node_initialization_session.h"
#include "modules/processing_graph/model/runtime_graph.h"
#include "modules/processors/db_meter.h"

#include <exception>
#include <memory>
#include <optional>
#include <rfl/json.hpp>
#include <string>
#include <utility>

namespace anthem {

namespace {
std::optional<AudioProcessingConfig> buildAudioProcessingConfig(juce::AudioIODevice* device) {
  if (device == nullptr) {
    return std::nullopt;
  }

  auto audioProcessingConfig = AudioProcessingConfig{
      .sampleRate = device->getCurrentSampleRate(),
      .blockSize = device->getCurrentBufferSizeSamples(),
      .inputChannelCount = device->getActiveInputChannels().countNumberOfSetBits(),
      .outputChannelCount = device->getActiveOutputChannels().countNumberOfSetBits(),
  };

#if JUCE_MAC
  audioProcessingConfig.macAudioWorkgroup = device->getWorkgroup();
#endif

  if (!audioProcessingConfig.isValid()) {
    return std::nullopt;
  }

  return audioProcessingConfig;
}

std::shared_ptr<EngineAudioConfig> buildAudioConfig(
    const AudioProcessingConfig& audioProcessingConfig) {
  auto audioConfig = std::make_shared<EngineAudioConfig>();
  audioConfig->sampleRate = audioProcessingConfig.sampleRate;
  audioConfig->blockSize = audioProcessingConfig.blockSize;
  audioConfig->inputChannelCount = audioProcessingConfig.inputChannelCount;
  audioConfig->outputChannelCount = audioProcessingConfig.outputChannelCount;
  return audioConfig;
}

} // namespace

std::unique_ptr<Engine> Engine::instance = nullptr;

Engine::Engine() = default;

void Engine::initialize() {
  this->sequenceStore = std::make_unique<RuntimeSequenceStore>();
  this->automationSequenceStore = std::make_unique<RuntimeAutomationSequenceStore>();
  transport =
      std::make_unique<Transport>(createTransportProjectView(*this), createTransportClock(*this));
  this->engineRuntimeServices =
      std::make_unique<EngineRuntimeServices>(*transport, *sequenceStore, *automationSequenceStore);
  this->graphProcessor = std::make_unique<GraphProcessor>(*engineRuntimeServices);
  globalVisualizationSources = std::make_unique<GlobalVisualizationSources>();

#ifndef __EMSCRIPTEN__
  juce::addDefaultFormatsToManager(audioPluginFormatManager);
  juce::Logger::writeToLog(
      "Initialized audio plugin format manager with UI-capable plugin formats.");
#endif // #ifndef __EMSCRIPTEN__

  comms.init();
}

void Engine::shutdown() {
  stopAudioCallback();
}

std::shared_ptr<EngineAudioConfig> Engine::startAudioCallback() {
  if (isAudioThreadRunning()) {
    juce::Logger::writeToLog("Tried to start audio callback when it was already running. This "
                             "probably doesn't break anything, but it's definitely a bug.");
    return getCurrentAudioConfig();
  }

  juce::Logger::writeToLog("Creating audio callback...");

  try {
    audioCallback = std::make_unique<AudioCallback>(this);
  } catch (const std::exception& e) {
    juce::Logger::writeToLog("Failed to create audio callback: " + juce::String(e.what()));
    return nullptr;
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
  auto initError = this->audioDeviceManager.initialiseWithDefaultDevices(2, 2);
  if (initError.isNotEmpty()) {
    juce::Logger::writeToLog("initialiseWithDefaultDevices(2, 2) failed: " + initError);
    juce::Logger::writeToLog("Retrying with 0 input channels and 2 output channels...");

    initError = this->audioDeviceManager.initialiseWithDefaultDevices(0, 2);
  }

  if (initError.isNotEmpty()) {
    juce::Logger::writeToLog("initialiseWithDefaultDevices() failed again: " + initError);
    return nullptr;
  }

  auto* device = this->audioDeviceManager.getCurrentAudioDevice();
  if (device == nullptr) {
    juce::Logger::writeToLog(
        "Audio device manager initialized, but no current audio device is available.");
    return nullptr;
  }

  auto audioConfig = refreshAudioProcessingConfigForDevice(*device);
  if (audioConfig == nullptr) {
    juce::Logger::writeToLog("Failed to refresh processing config for current device.");
    return nullptr;
  }

  juce::Logger::writeToLog("Selected audio device: " + device->getName());
  juce::Logger::writeToLog("Sample rate: " + juce::String(audioConfig->sampleRate));
  juce::Logger::writeToLog("Buffer size: " + juce::String(audioConfig->blockSize));
  juce::Logger::writeToLog(
      "Active output channels: " + juce::String(audioConfig->outputChannelCount));

  // Set up the audio callback
  this->audioDeviceManager.addAudioCallback(this->audioCallback.get());
  juce::Logger::writeToLog("Audio callback registered with device manager.");

  isAudioCallbackRunning.store(true, std::memory_order_release);

  return audioConfig;
}

void Engine::stopAudioCallback() {
  if (isAudioCallbackRunning.exchange(false, std::memory_order_acq_rel)) {
    audioDeviceManager.removeAudioCallback(audioCallback.get());
    audioDeviceManager.closeAudioDevice();
  }

  audioCallback.reset();
  graphProcessor->clearRuntimeGraph();
  resetInitializedProcessingGraphNodes();
  clearCurrentAudioProcessingConfig();
}

uint64_t Engine::setCurrentAudioProcessingConfig(AudioProcessingConfig audioProcessingConfig) {
  jassert(audioProcessingConfig.isValid());
  if (!audioProcessingConfig.isValid()) {
    clearCurrentAudioProcessingConfig();
    return getAudioProcessingConfigGeneration();
  }

  std::scoped_lock lock(audioProcessingConfigMutex);

  currentAudioProcessingConfig = audioProcessingConfig;
  return audioProcessingConfigGeneration.fetch_add(1, std::memory_order_acq_rel) + 1;
}

void Engine::clearCurrentAudioProcessingConfig() {
  std::scoped_lock lock(audioProcessingConfigMutex);
  currentAudioProcessingConfig = std::nullopt;
  audioProcessingConfigGeneration.fetch_add(1, std::memory_order_acq_rel);
}

void Engine::prepareForAudioProcessingConfig(const AudioProcessingConfig& audioProcessingConfig) {
  graphProcessor->prepareForAudioProcessingConfig(audioProcessingConfig);
  transport->prepareToProcess();
  juce::Logger::writeToLog("Prepared engine for audio processing config.");
}

void Engine::sendAudioSessionInvalidatedEvent(std::optional<std::string> reason) {
  Response response = AudioSessionInvalidatedEvent{
      .reason = std::move(reason),
      .responseBase = ResponseBase{.id = -1},
  };

  auto responseText = rfl::json::write(response);
  comms.send(responseText);
  juce::Logger::writeToLog("AudioSessionInvalidatedEvent sent to UI.");
}

void Engine::notifyAudioSessionInvalidatedOnMessageThread(
    std::optional<std::string> reason, uint64_t invalidatedGeneration) {
  jassert(juce::MessageManager::getInstance()->isThisTheMessageThread());

  if (!isAudioThreadRunning()) {
    return;
  }

  if (getAudioProcessingConfigGeneration() != invalidatedGeneration) {
    return;
  }

  sendAudioSessionInvalidatedEvent(std::move(reason));
}

void Engine::requestAudioSessionInvalidation(std::optional<std::string> reason) {
  if (!isAudioThreadRunning()) {
    return;
  }

  clearCurrentAudioProcessingConfig();
  const auto invalidatedGeneration = getAudioProcessingConfigGeneration();

  if (juce::MessageManager::getInstance()->isThisTheMessageThread()) {
    notifyAudioSessionInvalidatedOnMessageThread(std::move(reason), invalidatedGeneration);
    return;
  }

  juce::MessageManager::callAsync([reason = std::move(reason), invalidatedGeneration]() mutable {
    auto& engine = Engine::getInstance();
    engine.notifyAudioSessionInvalidatedOnMessageThread(std::move(reason), invalidatedGeneration);
  });
}

std::shared_ptr<EngineAudioConfig> Engine::refreshAudioProcessingConfigForDevice(
    juce::AudioIODevice& device) {
  auto audioProcessingConfig = buildAudioProcessingConfig(&device);
  if (!audioProcessingConfig.has_value()) {
    juce::Logger::writeToLog("Failed to build processing config for audio device.");
    clearCurrentAudioProcessingConfig();
    return nullptr;
  }

  setCurrentAudioProcessingConfig(audioProcessingConfig.value());
  auto audioConfig = buildAudioConfig(audioProcessingConfig.value());

  prepareForAudioProcessingConfig(audioProcessingConfig.value());
  return audioConfig;
}

std::optional<AudioProcessingConfig> Engine::getCurrentAudioProcessingConfig() const {
  std::scoped_lock lock(audioProcessingConfigMutex);
  return currentAudioProcessingConfig;
}

std::optional<AudioProcessingConfigSnapshot>
Engine::getCurrentAudioProcessingConfigSnapshot() const {
  std::scoped_lock lock(audioProcessingConfigMutex);
  if (!currentAudioProcessingConfig.has_value()) {
    return std::nullopt;
  }

  return AudioProcessingConfigSnapshot{
      .config = currentAudioProcessingConfig.value(),
      .generation = audioProcessingConfigGeneration.load(std::memory_order_acquire),
  };
}

std::shared_ptr<EngineAudioConfig> Engine::getCurrentAudioConfig() const {
  auto audioProcessingConfig = getCurrentAudioProcessingConfig();
  if (!audioProcessingConfig.has_value()) {
    return nullptr;
  }

  return buildAudioConfig(audioProcessingConfig.value());
}

uint64_t Engine::getAudioProcessingConfigGeneration() const {
  return audioProcessingConfigGeneration.load(std::memory_order_acquire);
}

void Engine::resetInitializedProcessingGraphNodes() {
  for (auto& [_, initializedNodeWeakPtr] : initializedProcessingGraphNodes) {
    auto initializedNode = initializedNodeWeakPtr.lock();
    if (initializedNode == nullptr) {
      continue;
    }

    auto processor = initializedNode->getProcessor();
    if (processor.has_value()) {
      processor.value()->isPrepared = false;
    }
  }

  initializedProcessingGraphNodes.clear();
}

void Engine::initializeProcessingGraphNodes(InitializeProcessingGraphNodesCallback complete) {
  auto session =
      std::make_shared<ProcessingGraphNodeInitializationSession>(*this, std::move(complete));
  session->run();
}

void Engine::publishProcessingGraph() {
  auto audioProcessingConfigSnapshot = getCurrentAudioProcessingConfigSnapshot();
  jassert(audioProcessingConfigSnapshot.has_value());
  if (!audioProcessingConfigSnapshot.has_value()) {
    return;
  }

  const auto& audioProcessingConfig = audioProcessingConfigSnapshot->config;

  auto& processingGraph = *project->processingGraph();

  auto runtimeGraph = RuntimeGraph::fromProcessingGraph(processingGraph,
      graphProcessor->getEngineRuntimeServices(),
      GraphBufferLayout{
          .numAudioChannels = audioProcessingConfig.outputChannelCount,
          .blockSize = audioProcessingConfig.blockSize,
      });

  graphProcessor->publishRuntimeGraph(
      runtimeGraph.release(), audioProcessingConfigSnapshot->generation);
}

} // namespace anthem
