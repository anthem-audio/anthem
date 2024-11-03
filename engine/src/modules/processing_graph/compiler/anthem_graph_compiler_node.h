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

#include "modules/processing_graph/compiler/anthem_graph_compiler_edge.h"
#include "modules/processing_graph/topology/anthem_graph_node.h"

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
  AnthemProcessContext* context;

  // Whether this node is ready to process
  bool readyToProcess = false;

  AnthemGraphCompilerNode(std::shared_ptr<AnthemGraphNode> node, AnthemProcessContext* context) : node(node), context(context) {}

  // Populate the input and output edges for this node
  void assignEdges(
    std::map<AnthemGraphNode*, std::shared_ptr<AnthemGraphCompilerNode>>& nodeToCompilerNode,
    std::map<AnthemGraphNodeConnection*, std::shared_ptr<AnthemGraphCompilerEdge>>& connectionToCompilerEdge
  ) {
    for (auto& port : node->audioInputs) {
      for (auto connection : port->connections) {
        assignEdge(nodeToCompilerNode, connectionToCompilerEdge, inputEdges, connection);
      }
    }

    for (auto& port : node->controlInputs) {
      for (auto connection : port->connections) {
        assignEdge(nodeToCompilerNode, connectionToCompilerEdge, inputEdges, connection);
      }
    }

    for (auto& port : node->noteEventInputs) {
      for (auto connection : port->connections) {
        assignEdge(nodeToCompilerNode, connectionToCompilerEdge, inputEdges, connection);
      }
    }

    for (auto& port : node->audioOutputs) {
      for (auto connection : port->connections) {
        assignEdge(nodeToCompilerNode, connectionToCompilerEdge, outputEdges, connection);
      }
    }

    for (auto& port : node->controlOutputs) {
      for (auto connection : port->connections) {
        assignEdge(nodeToCompilerNode, connectionToCompilerEdge, outputEdges, connection);
      }
    }

    for (auto& port : node->noteEventOutputs) {
      for (auto connection : port->connections) {
        assignEdge(nodeToCompilerNode, connectionToCompilerEdge, outputEdges, connection);
      }
    }
  }
private:
  void assignEdge(
    std::map<AnthemGraphNode*, std::shared_ptr<AnthemGraphCompilerNode>>& nodeToCompilerNode,
    std::map<AnthemGraphNodeConnection*, std::shared_ptr<AnthemGraphCompilerEdge>>& connectionToCompilerEdge,
    std::vector<std::shared_ptr<AnthemGraphCompilerEdge>>& edgeContainer,
    std::shared_ptr<AnthemGraphNodeConnection> connection
  ) {
    auto sourceNodeContext = nodeToCompilerNode[connection->source.lock()->node.lock().get()]->context;
    auto destinationNodeContext = nodeToCompilerNode[connection->destination.lock()->node.lock().get()]->context;
    auto portType = connection->source.lock()->config->portType;

    // If we've already created a compiler edge for this connection, use it
    if (connectionToCompilerEdge.find(connection.get()) != connectionToCompilerEdge.end()) {
      edgeContainer.push_back(connectionToCompilerEdge[connection.get()]);
    } else {
      auto edge = std::make_shared<AnthemGraphCompilerEdge>(
        connection,
        sourceNodeContext,
        destinationNodeContext,
        portType
      );

      connectionToCompilerEdge[connection.get()] = edge;

      edgeContainer.push_back(edge);
    }
  }
};
