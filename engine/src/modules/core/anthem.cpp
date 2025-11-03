/*
  Copyright (C) 2023 - 2025 Joshua Wade

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

#include "modules/core/anthem.h"

#include "modules/processing_graph/compiler/anthem_graph_compiler.h"

std::unique_ptr<Anthem> Anthem::instance = nullptr;

Anthem::Anthem() {
  isAudioCallbackRunning = false;
}

void Anthem::initialize() {
  this->graphProcessor = std::make_unique<AnthemGraphProcessor>();
  this->sequenceStore = std::make_unique<AnthemRuntimeSequenceStore>();
  transport = std::make_unique<Transport>();
  globalVisualizationSources = std::make_unique<GlobalVisualizationSources>();

  #ifndef __EMSCRIPTEN__
  audioPluginFormatManager.addDefaultFormats();
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

void Anthem::shutdown() {
  if (isAudioCallbackRunning) {
    audioDeviceManager.removeAudioCallback(audioCallback.get());
    audioDeviceManager.closeAudioDevice();
  }
}

void Anthem::startAudioCallback() {
  if (isAudioCallbackRunning) {
    std::cout << "Tried to start audio callback when it was already running. This probably doesn't break anything, but it's definitely a bug." << std::endl;
    return;
  }

  audioCallback = std::make_unique<AnthemAudioCallback>(this);

  // Initialize the audio device manager with 2 input and 2 output channels
  this->audioDeviceManager.initialiseWithDefaultDevices(2, 2);

  // Set up the audio callback
  this->audioDeviceManager.addAudioCallback(this->audioCallback.get());

  isAudioCallbackRunning = true;
}

void Anthem::compileProcessingGraph() {
  auto result = AnthemGraphCompiler::compile();

  // std::cout << "Processing steps: " << result->processContexts.size() << std::endl;

  // for (auto& group : result->actionGroups) {
  //   juce::Logger::writeToLog("ACTION GROUP");
  //   for (auto& action : *group) {
  //     action->debugPrint();
  //   }
  // }

  // Make sure all nodes have been prepared for processing
  for (auto& pair : *project->processingGraph()->nodes()) {
    auto& node = *pair.second;

    auto& procVariant = node.processor();
    if (!procVariant.has_value()) {
      continue;
    }

    rfl::visit([&](const auto& field) {
      // 'field' is the rfl::Field<Name, Type> wrapper.
      // We get the actual std::shared_ptr with .value().
      const auto& sharedPtr = field.value();

      // sharedPtr is a std::shared_ptr<DerivedProcessor>.
      // .get() returns a DerivedProcessor*.
      // C++ polymorphism allows us to assign a Derived* to a Base*.
      AnthemProcessor* baseProcessor = sharedPtr.get();

      if (!baseProcessor->isPrepared) {
        baseProcessor->prepareToProcess();
        baseProcessor->isPrepared = true;
      }
    }, procVariant.value());
  }

  graphProcessor->setProcessingStepsFromMainThread(result);
}
