/*
  Copyright (C) 2023 - 2024 Joshua Wade

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

#include "anthem.h"
#include "tone_generator_node.h"

Anthem::Anthem() {
  processingGraph = AnthemGraph();

  init();
}

void Anthem::init() {
  auto masterOutputProcessor = std::make_unique<MasterOutputNode>(2, 512);
  auto masterOutputNode = processingGraph.addNode(std::move(masterOutputProcessor));

  auto toneGeneratorProcessor = std::make_unique<ToneGeneratorNode>();
  auto toneGeneratorNode = processingGraph.addNode(std::move(toneGeneratorProcessor));

  processingGraph.connectNodes(
    std::dynamic_pointer_cast<ToneGeneratorNode>(toneGeneratorNode->processor)->getOutput(),
    std::dynamic_pointer_cast<MasterOutputNode>(masterOutputNode->processor)->getInput()
  );

  // Initialize the audio device manager with 2 input and 2 output channels
  this->deviceManager.initialiseWithDefaultDevices(2, 2);

  // Set up the audio callback
  this->deviceManager.addAudioCallback(&this->audioCallback);
}
