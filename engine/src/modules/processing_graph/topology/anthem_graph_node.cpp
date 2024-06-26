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
#include "anthem_process_context.h"

AnthemGraphNode::AnthemGraphNode(std::shared_ptr<AnthemProcessor> processor) : processor(processor) {
  audioInputs = std::vector<std::shared_ptr<AnthemGraphNodePort>>();
  audioOutputs = std::vector<std::shared_ptr<AnthemGraphNodePort>>();

  controlInputs = std::vector<std::shared_ptr<AnthemGraphNodePort>>();
  controlOutputs = std::vector<std::shared_ptr<AnthemGraphNodePort>>();

  parameters = std::vector<float>(processor->config.getNumControlInputs(), 0.0f);

  for (int i = 0; i < processor->config.getNumControlInputs(); i++) {
    parameters[i] = processor->config.getParameter(i)->defaultValue;
  }

  runtimeContext = std::nullopt;
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
    audioInputs.push_back(
      std::make_shared<AnthemGraphNodePort>(self, processor->config.getAudioInput(i), i)
    );
  }

  for (int i = 0; i < processor->config.getNumAudioOutputs(); i++) {
    audioOutputs.push_back(
      std::make_shared<AnthemGraphNodePort>(self, processor->config.getAudioOutput(i), i)
    );
  }
  
  for (int i = 0; i < processor->config.getNumControlInputs(); i++) {
    controlInputs.push_back(
      std::make_shared<AnthemGraphNodePort>(self, processor->config.getControlInput(i), i)
    );
  }

  for (int i = 0; i < processor->config.getNumControlOutputs(); i++) {
    controlOutputs.push_back(
      std::make_shared<AnthemGraphNodePort>(self, processor->config.getControlOutput(i), i)
    );
  }
}

void AnthemGraphNode::setParameter(int index, float value) {
  parameters[index] = value;

  if (runtimeContext.has_value()) {
    runtimeContext.value()->setParameterValue(index, value);
  }
}
