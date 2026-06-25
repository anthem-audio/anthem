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

Engine::Engine() {
  isAudioCallbackRunning = false;
}

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
  if (isAudioCallbackRunning) {
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

  auto audioProcessingConfig = buildAudioProcessingConfig(device);
  if (!audioProcessingConfig.has_value()) {
    juce::Logger::writeToLog("Failed to build processing config for current device.");
    return nullptr;
  }

  setCurrentAudioProcessingConfig(audioProcessingConfig.value());
  auto audioConfig = buildAudioConfig(*currentAudioProcessingConfig);

  juce::Logger::writeToLog("Selected audio device: " + device->getName());
  juce::Logger::writeToLog("Sample rate: " + juce::String(audioProcessingConfig->sampleRate));
  juce::Logger::writeToLog("Buffer size: " + juce::String(audioProcessingConfig->blockSize));
  juce::Logger::writeToLog(
      "Active output channels: " + juce::String(audioProcessingConfig->outputChannelCount));

  graphProcessor->prepareForAudioProcessingConfig(*currentAudioProcessingConfig);
  transport->prepareToProcess();
  juce::Logger::writeToLog("Transport prepared before audio callback registration.");

  // Set up the audio callback
  this->audioDeviceManager.addAudioCallback(this->audioCallback.get());
  juce::Logger::writeToLog("Audio callback registered with device manager.");

  isAudioCallbackRunning = true;

  return audioConfig;
}

void Engine::stopAudioCallback() {
  if (isAudioCallbackRunning) {
    audioDeviceManager.removeAudioCallback(audioCallback.get());
    audioDeviceManager.closeAudioDevice();
    isAudioCallbackRunning = false;
  }

  audioCallback.reset();
  clearCurrentAudioProcessingConfig();
}

void Engine::setCurrentAudioProcessingConfig(AudioProcessingConfig audioProcessingConfig) {
  jassert(audioProcessingConfig.isValid());
  if (!audioProcessingConfig.isValid()) {
    currentAudioProcessingConfig = std::nullopt;
    return;
  }

  currentAudioProcessingConfig = audioProcessingConfig;
}

void Engine::clearCurrentAudioProcessingConfig() {
  currentAudioProcessingConfig = std::nullopt;
}

std::optional<AudioProcessingConfig> Engine::getCurrentAudioProcessingConfig() const {
  return currentAudioProcessingConfig;
}

std::shared_ptr<EngineAudioConfig> Engine::getCurrentAudioConfig() const {
  if (!currentAudioProcessingConfig.has_value()) {
    return nullptr;
  }

  return buildAudioConfig(currentAudioProcessingConfig.value());
}

void Engine::initializeProcessingGraphNodes(InitializeProcessingGraphNodesCallback complete) {
  auto session =
      std::make_shared<ProcessingGraphNodeInitializationSession>(*this, std::move(complete));
  session->run();
}

void Engine::publishProcessingGraph() {
  auto audioProcessingConfig = getCurrentAudioProcessingConfig();
  jassert(audioProcessingConfig.has_value());
  if (!audioProcessingConfig.has_value()) {
    return;
  }

  auto& processingGraph = *project->processingGraph();

  auto runtimeGraph = RuntimeGraph::fromProcessingGraph(processingGraph,
      graphProcessor->getEngineRuntimeServices(),
      GraphBufferLayout{
          .numAudioChannels = audioProcessingConfig->outputChannelCount,
          .blockSize = audioProcessingConfig->blockSize,
      });

  graphProcessor->setRuntimeGraphFromMainThread(runtimeGraph.release());
}

} // namespace anthem
