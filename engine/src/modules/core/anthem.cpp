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

  audioPluginFormatManager.addDefaultFormats();

  comms.init();
  commandHandler.startHeartbeatThread();
}

void Anthem::shutdown() {
  if (isAudioCallbackRunning) {
    audioDeviceManager.removeAudioCallback(audioCallback.get());
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
