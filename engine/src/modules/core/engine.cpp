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
#include "modules/processing_graph_threaded/model/runtime_graph.h"
#include "modules/processors/db_meter.h"

namespace anthem {

namespace {
std::shared_ptr<EngineAudioConfig> buildAudioConfig(juce::AudioIODevice* device) {
  if (device == nullptr) {
    return nullptr;
  }

  auto audioConfig = std::make_shared<EngineAudioConfig>();
  audioConfig->sampleRate = device->getCurrentSampleRate();
  audioConfig->blockSize = device->getCurrentBufferSizeSamples();
  audioConfig->inputChannelCount = device->getActiveInputChannels().countNumberOfSetBits();
  audioConfig->outputChannelCount = device->getActiveOutputChannels().countNumberOfSetBits();
  return audioConfig;
}
} // namespace

std::unique_ptr<Engine> Engine::instance = nullptr;

Engine::Engine() {
  isAudioCallbackRunning = false;
}

void Engine::initialize() {
  this->threadedGraphProcessor = std::make_unique<threaded_graph::GraphProcessor>();
  this->sequenceStore = std::make_unique<RuntimeSequenceStore>();
  transport = std::make_unique<Transport>(
      createTransportProjectView(*this), createTransportClock(audioDeviceManager));
  globalVisualizationSources = std::make_unique<GlobalVisualizationSources>();

#ifndef __EMSCRIPTEN__
  juce::addDefaultFormatsToManager(audioPluginFormatManager);
  juce::Logger::writeToLog(
      "Initialized audio plugin format manager with UI-capable plugin formats.");
#endif // #ifndef __EMSCRIPTEN__

  comms.init();

// On desktop, we use a heartbeat to make sure that we have an active
// connection to the UI. While it shouldn't be possible due to how we start
// the engine from the Dart side, this is a last resort to make sure that we
// don't have a dangling engine process if something goes wrong.
//
// On web, we don't need this for two reasons: First, the web version is
// self-contained within the browser tab; if something is wrong, the tab can
// just be closed. Second, the connection between the UI and engine is much
// more direct on web, since the UI gets an object to puppeteer the engine
// directly, and the risk of losing track of the engine is much lower.
//
// The other reason this is removed on web is that when the browser loses
// focus, it may throttle or pause background tasks, which causes the UI to
// stop sending heartbeats. We could fix this, but since it's not needed on
// web anyway, it's simpler to just disable it.
#ifndef __EMSCRIPTEN__
  commandHandler.startHeartbeatThread();
#endif // #ifndef __EMSCRIPTEN__
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

  auto audioConfig = buildAudioConfig(device);
  if (audioConfig == nullptr) {
    juce::Logger::writeToLog("Failed to build audio config for current device.");
    return nullptr;
  }

  juce::Logger::writeToLog("Selected audio device: " + device->getName());
  juce::Logger::writeToLog("Sample rate: " + juce::String(device->getCurrentSampleRate()));
  juce::Logger::writeToLog("Buffer size: " + juce::String(device->getCurrentBufferSizeSamples()));
  juce::Logger::writeToLog("Active output channels: " +
                           juce::String(device->getActiveOutputChannels().countNumberOfSetBits()));

  transport->prepareToProcess();
  threadedGraphProcessor->resetRtServices();
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
}

std::shared_ptr<EngineAudioConfig> Engine::getCurrentAudioConfig() const {
  return buildAudioConfig(audioDeviceManager.getCurrentAudioDevice());
}

void Engine::compileProcessingGraph() {
  auto* currentDevice = audioDeviceManager.getCurrentAudioDevice();
  jassert(currentDevice != nullptr);
  if (currentDevice == nullptr) {
    return;
  }

  auto& processingGraph = *project->processingGraph();

  auto threadedRuntimeGraph = threaded_graph::RuntimeGraph::fromProcessingGraph(processingGraph,
      threadedGraphProcessor->getRtServices(),
      GraphBufferLayout{
          .numAudioChannels = currentDevice->getActiveOutputChannels().countNumberOfSetBits(),
          .blockSize = currentDevice->getCurrentBufferSizeSamples(),
      },
      currentDevice->getCurrentSampleRate());

  // Make sure all nodes have been prepared for processing
  for (auto& pair : *processingGraph.nodes()) {
    auto& node = *pair.second;

    auto& procVariant = node.processor();
    if (!procVariant.has_value()) {
      continue;
    }

    rfl::visit(
        [&](const auto& field) {
          // 'field' is the rfl::Field<Name, Type> wrapper.
          // We get the actual std::shared_ptr with .value().
          const auto& sharedPtr = field.value();
          Processor* baseProcessor = sharedPtr.get();

          if (!baseProcessor->isPrepared) {
            baseProcessor->prepareToProcess();
            baseProcessor->isPrepared = true;
          }
        },
        procVariant.value());
  }

  threadedGraphProcessor->setRuntimeGraphFromMainThread(threadedRuntimeGraph.release());
}

} // namespace anthem
