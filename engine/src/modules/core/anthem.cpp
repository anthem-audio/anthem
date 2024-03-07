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
#include "simple_volume_lfo_node.h"

Anthem::Anthem() {
  processingGraph = std::make_shared<AnthemGraph>();

  init();
}

void Anthem::init() {
  auto masterOutputProcessor = std::make_shared<MasterOutputNode>(2, MAX_AUDIO_BUFFER_SIZE);
  this->masterOutputNode = processingGraph->addNode(masterOutputProcessor);
  audioCallback = std::make_unique<AnthemAudioCallback>(processingGraph, this->masterOutputNode);

  auto toneGeneratorProcessor = std::make_shared<ToneGeneratorNode>();
  auto toneGeneratorNode = processingGraph->addNode(toneGeneratorProcessor);

  auto simpleVolumeLfoProcessor = std::make_shared<SimpleVolumeLfoNode>();
  auto simpleVolumeLfoNode = processingGraph->addNode(simpleVolumeLfoProcessor);

  processingGraph->connectNodes(
    toneGeneratorNode->audioOutputs[toneGeneratorProcessor->getOutputPortIndex()],
    simpleVolumeLfoNode->audioInputs[simpleVolumeLfoProcessor->getInputPortIndex()]
  );

  processingGraph->connectNodes(
    simpleVolumeLfoNode->audioOutputs[simpleVolumeLfoProcessor->getOutputPortIndex()],
    masterOutputNode->audioInputs[masterOutputProcessor->getInputPortIndex()]
  );

  processingGraph->compile();

  processingGraph->debugPrint();

  // Initialize the audio device manager with 2 input and 2 output channels
  this->deviceManager.initialiseWithDefaultDevices(2, 2);

  // Set up the audio callback
  this->deviceManager.addAudioCallback(this->audioCallback.get());
}
