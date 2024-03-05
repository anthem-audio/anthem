/*
  Copyright (C) 2024 Joshua Wade

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

#include "master_output_node.h"

#include <iostream>

#include "anthem_process_context.h"

MasterOutputNode::MasterOutputNode(int numChannels, int bufferSize) : AnthemProcessor("MasterOutputNode") {
  buffer = juce::AudioSampleBuffer(numChannels, bufferSize);

  config.addAudioInput(
    AnthemProcessorPortConfig(AnthemGraphDataType::Audio, "input")
  );
}

MasterOutputNode::~MasterOutputNode() {}

// std::shared_ptr<AnthemGraphNodePort> getInput();

std::shared_ptr<AnthemGraphNodePort> MasterOutputNode::getInput() {
  return config.getAudioInput(0);
}

void MasterOutputNode::process(AnthemProcessContext& context, int numSamples) {
  auto& inputBuffer = context.getInputAudioBuffer(0);

  for (int channel = 0; channel < buffer.getNumChannels(); channel++) {
    this->buffer.copyFrom(channel, 0, inputBuffer, channel, 0, numSamples);
  }
}
