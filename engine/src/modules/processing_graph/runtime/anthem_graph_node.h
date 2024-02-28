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

#pragma once

#include <memory>
#include <vector>

#include "anthem_processor.h"
#include "anthem_process_context.h"
#include "anthem_graph_node_port.h"

// Represents a node in the processing graph.
class AnthemGraphNode {
public:
  std::shared_ptr<AnthemProcessor> processor;

  std::vector<std::shared_ptr<AnthemGraphNodePort>> audioInputs;
  std::vector<std::shared_ptr<AnthemGraphNodePort>> audioOutputs;

  std::unique_ptr<AnthemProcessContext> processContext;

  AnthemGraphNode(std::shared_ptr<AnthemProcessor> processor) : processor(processor) {
    auto graph_node = std::make_shared<AnthemGraphNode>(*this);
    processContext = std::make_unique<AnthemProcessContext>(graph_node);
  }
  
  // Shallow copy constructor
  AnthemGraphNode(const AnthemGraphNode& other);

  void addAudioInput(std::shared_ptr<AnthemGraphNodePort> input);

  void addAudioOutput(std::shared_ptr<AnthemGraphNodePort> output);
};
