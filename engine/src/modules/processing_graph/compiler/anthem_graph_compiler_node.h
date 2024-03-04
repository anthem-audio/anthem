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
#include <map>
#include <vector>

#include "anthem_graph_compiler_edge.h"
#include "anthem_graph_node.h"

class AnthemGraphNode;
class AnthemProcessContext;

// Represents a node in the compiler. Used internally by the compiler to keep
// track of details about nodes being processed.
class AnthemGraphCompilerNode {
public:
  // The node that this compiled node represents
  std::shared_ptr<AnthemGraphNode> node;

  std::vector<std::shared_ptr<AnthemGraphCompilerEdge>> inputEdges;
  std::vector<std::shared_ptr<AnthemGraphCompilerEdge>> outputEdges;

  // The runtime context for this node
  std::shared_ptr<AnthemProcessContext> context;

  // Whether this node is ready to process
  bool readyToProcess = false;

  AnthemGraphCompilerNode(std::shared_ptr<AnthemGraphNode> node, std::shared_ptr<AnthemProcessContext> context) : node(node), context(context) {}

  // Populate the input and output edges for this node
  void assignEdges(std::map<AnthemGraphNode*, std::shared_ptr<AnthemGraphCompilerNode>>& nodeToCompilerNode) {
    for (auto& port : node->audioInputs) {
      for (auto connection : port->connections) {
        auto edge = std::make_shared<AnthemGraphCompilerEdge>(
          connection,
          nodeToCompilerNode[connection->source.lock()->node.lock().get()]->context,
          nodeToCompilerNode[connection->destination.lock()->node.lock().get()]->context,
          connection->source.lock()->config.portType
        );
        inputEdges.push_back(edge);
      }
    }

    // TODO: other port types

    for (auto& port : node->audioOutputs) {
      for (auto connection : port->connections) {
        auto edge = std::make_shared<AnthemGraphCompilerEdge>(
          connection,
          nodeToCompilerNode[connection->source.lock()->node.lock().get()]->context,
          nodeToCompilerNode[connection->destination.lock()->node.lock().get()]->context,
          connection->source.lock()->config.portType
        );
        outputEdges.push_back(edge);
      }
    }
  }
};
