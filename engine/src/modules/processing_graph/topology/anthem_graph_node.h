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

#include "modules/processing_graph/processor/anthem_processor.h"
#include "modules/processing_graph/topology/anthem_graph_node_port.h"

// Represents a node in the processing graph.
class AnthemGraphNode : public std::enable_shared_from_this<AnthemGraphNode> {
public:
  // The processor associated with this node. Note that this is accessed from
  // the audio thread, and so must not be a shared_ptr.
  std::unique_ptr<AnthemProcessor> processor;

  std::vector<std::shared_ptr<AnthemGraphNodePort>> audioInputs;
  std::vector<std::shared_ptr<AnthemGraphNodePort>> audioOutputs;

  std::vector<std::shared_ptr<AnthemGraphNodePort>> controlInputs;
  std::vector<std::shared_ptr<AnthemGraphNodePort>> controlOutputs;

  std::vector<std::shared_ptr<AnthemGraphNodePort>> noteEventInputs;
  std::vector<std::shared_ptr<AnthemGraphNodePort>> noteEventOutputs;

  std::vector<float> parameters;

  std::optional<AnthemProcessContext*> runtimeContext;

  static std::shared_ptr<AnthemGraphNode> create(std::unique_ptr<AnthemProcessor> processor);

  // Delete the copy constructor
  AnthemGraphNode(const AnthemGraphNode&) = delete;

  // Delete the copy assignment operator
  AnthemGraphNode& operator=(const AnthemGraphNode&) = delete;

  AnthemGraphNode(std::unique_ptr<AnthemProcessor> processor);

  void initializePorts();

  void setParameter(uint64_t index, float value);
};
