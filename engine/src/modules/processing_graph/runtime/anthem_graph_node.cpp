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

AnthemGraphNode::AnthemGraphNode(const AnthemGraphNode& other) {
  processor = other.processor;

  audioInputs = std::vector<std::shared_ptr<AnthemGraphNodeAudioPort>>();

  for (auto& input : other.audioInputs) {
    audioInputs.push_back(input);
  }

  audioOutputs = std::vector<std::shared_ptr<AnthemGraphNodeAudioPort>>();

  for (auto& output : other.audioOutputs) {
    audioOutputs.push_back(output);
  }
}

void AnthemGraphNode::addAudioInput(std::shared_ptr<AnthemGraphNodeAudioPort> input) {
  audioInputs.push_back(std::move(input));
}

void AnthemGraphNode::addAudioOutput(std::shared_ptr<AnthemGraphNodeAudioPort> output) {
  audioOutputs.push_back(std::move(output));
}
