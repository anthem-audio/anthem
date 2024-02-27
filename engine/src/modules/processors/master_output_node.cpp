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

MasterOutputNode::MasterOutputNode(AnthemGraphNode& graphNode, int numChannels, int bufferSize) {
  buffer = juce::AudioSampleBuffer(numChannels, bufferSize);

  graphNode.addAudioInput(std::make_unique<AnthemGraphNodeAudioPort>());
}

MasterOutputNode::~MasterOutputNode() {}

void MasterOutputNode::process(AnthemProcessContext& context) {
  auto& buffer = context.graphNode->audioInputs[0]->buffer;
}
