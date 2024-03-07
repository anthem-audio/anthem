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

#include "anthem_graph_node.h"

AnthemGraphNode::AnthemGraphNode(std::shared_ptr<AnthemProcessor> processor) : processor(processor) {
  audioInputs = std::vector<std::shared_ptr<AnthemGraphNodePort>>();
  audioOutputs = std::vector<std::shared_ptr<AnthemGraphNodePort>>();
}

AnthemGraphNode::AnthemGraphNode(const AnthemGraphNode& other) {
  processor = other.processor;

  audioInputs = std::vector<std::shared_ptr<AnthemGraphNodePort>>();

  for (auto& input : other.audioInputs) {
    audioInputs.push_back(input);
  }

  audioOutputs = std::vector<std::shared_ptr<AnthemGraphNodePort>>();

  for (auto& output : other.audioOutputs) {
    audioOutputs.push_back(output);
  }
}

std::shared_ptr<AnthemGraphNode> AnthemGraphNode::create(std::shared_ptr<AnthemProcessor> processor) {
  auto node = std::make_shared<AnthemGraphNode>(processor);
  node->initializePorts();
  return node;
}

void AnthemGraphNode::initializePorts() {
  std::shared_ptr<AnthemGraphNode> self = shared_from_this();

  // Add input and output ports
  for (int i = 0; i < processor->config.getNumAudioInputs(); i++) {
    audioInputs.push_back(std::make_shared<AnthemGraphNodePort>(self, processor->config.getAudioInput(i), i));
  }

  for (int i = 0; i < processor->config.getNumAudioOutputs(); i++) {
    audioOutputs.push_back(std::make_shared<AnthemGraphNodePort>(self, processor->config.getAudioOutput(i), i));
  }
}
