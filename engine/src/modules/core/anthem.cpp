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
  graphProcessor = std::make_unique<AnthemGraphProcessor>();
}

void Anthem::shutdown() {
  if (isAudioCallbackRunning) {
    deviceManager.removeAudioCallback(audioCallback.get());
  }
}

void Anthem::startAudioCallback() {
  if (isAudioCallbackRunning) {
    std::cout << "Tried to start audio callback when it was already running. This probably doesn't break anything, but it's definitely a bug." << std::endl;
    return;
  }

  audioCallback = std::make_unique<AnthemAudioCallback>(this);

  // Initialize the audio device manager with 2 input and 2 output channels
  this->deviceManager.initialiseWithDefaultDevices(2, 2);

  // Set up the audio callback
  this->deviceManager.addAudioCallback(this->audioCallback.get());

  isAudioCallbackRunning = true;
}

void Anthem::compileProcessingGraph() {
  auto result = AnthemGraphCompiler::compile();

  std::cout << "Processing steps: " << result->processContexts.size() << std::endl;

  for (auto& group : result->actionGroups) {
    juce::Logger::writeToLog("ACTION GROUP");
    for (auto& action : *group) {
      action->debugPrint();
    }
  }

  graphProcessor->setProcessingStepsFromMainThread(result);
}
