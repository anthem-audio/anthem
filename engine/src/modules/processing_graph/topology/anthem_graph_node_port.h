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

#include "modules/processing_graph/processor/anthem_processor_port_config.h"
#include "modules/processing_graph/topology/anthem_graph_node_connection.h"

class AnthemGraphNode;

// This class represents a port on a node in the processing graph.
class AnthemGraphNodePort {
public:
  // The node that this port is on.
  std::weak_ptr<AnthemGraphNode> node;

  // The index of this port on the node.
  int index;

  // The connections to or from this port.
  std::vector<std::shared_ptr<AnthemGraphNodeConnection>> connections;

  // The configuration of this port.
  std::shared_ptr<AnthemProcessorPortConfig> config;

  AnthemGraphNodePort(std::shared_ptr<AnthemGraphNode> node, std::shared_ptr<AnthemProcessorPortConfig> config, int index) : config(config), index(index) {
    this->node = std::weak_ptr<AnthemGraphNode>(node);
  }

  // Delete the copy constructor
  AnthemGraphNodePort(const AnthemGraphNodePort&) = delete;

  // Delete the copy assignment operator
  AnthemGraphNodePort& operator=(const AnthemGraphNodePort&) = delete;
};
