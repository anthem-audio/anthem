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

#include "generated/lib/model/model.h"

class AnthemGraphNode;
class AnthemProcessContext;

// Represents a node in the compiler. Used internally by the compiler to keep
// track of details about nodes being processed.
class AnthemGraphCompilerNode {
public:
  // The node that this compiled node represents
  std::shared_ptr<Node> node;

  std::vector<std::shared_ptr<AnthemGraphCompilerEdge>> inputEdges;
  std::vector<std::shared_ptr<AnthemGraphCompilerEdge>> outputEdges;

  // The runtime context for this node
  AnthemProcessContext* context;

  // Whether this node is ready to process
  bool readyToProcess = false;

  AnthemGraphCompilerNode(std::shared_ptr<Node> node, AnthemProcessContext* context) : node(node), context(context) {}

  // Populate the input and output edges for this node
  void assignEdges(
    std::map<Node*, std::shared_ptr<AnthemGraphCompilerNode>>& nodeToCompilerNode,
    std::map<NodeConnection*, std::shared_ptr<AnthemGraphCompilerEdge>>& connectionToCompilerEdge
  ) {
    for (auto& port : *node->audioInputPorts()) {
      for (auto& connectionId : *port->connections()) {
        auto& connection = Anthem::getInstance().project->processingGraph()->connections()->at(connectionId);
        assignEdge(nodeToCompilerNode, connectionToCompilerEdge, inputEdges, connection);
      }
    }

    for (auto& port : *node->controlInputPorts()) {
      for (auto& connectionId : *port->connections()) {
        auto& connection = Anthem::getInstance().project->processingGraph()->connections()->at(connectionId);
        assignEdge(nodeToCompilerNode, connectionToCompilerEdge, inputEdges, connection);
      }
    }

    for (auto& port : *node->midiInputPorts()) {
      for (auto& connectionId : *port->connections()) {
        auto& connection = Anthem::getInstance().project->processingGraph()->connections()->at(connectionId);
        assignEdge(nodeToCompilerNode, connectionToCompilerEdge, inputEdges, connection);
      }
    }

    for (auto& port : *node->audioOutputPorts()) {
      for (auto& connectionId : *port->connections()) {
        auto& connection = Anthem::getInstance().project->processingGraph()->connections()->at(connectionId);
        assignEdge(nodeToCompilerNode, connectionToCompilerEdge, outputEdges, connection);
      }
    }

    for (auto& port : *node->controlOutputPorts()) {
      for (auto& connectionId : *port->connections()) {
        auto& connection = Anthem::getInstance().project->processingGraph()->connections()->at(connectionId);
        assignEdge(nodeToCompilerNode, connectionToCompilerEdge, outputEdges, connection);
      }
    }

    for (auto& port : *node->midiOutputPorts()) {
      for (auto& connectionId : *port->connections()) {
        auto& connection = Anthem::getInstance().project->processingGraph()->connections()->at(connectionId);
        assignEdge(nodeToCompilerNode, connectionToCompilerEdge, outputEdges, connection);
      }
    }
  }
private:
  void assignEdge(
    std::map<Node*, std::shared_ptr<AnthemGraphCompilerNode>>& nodeToCompilerNode,
    std::map<NodeConnection*, std::shared_ptr<AnthemGraphCompilerEdge>>& connectionToCompilerEdge,
    std::vector<std::shared_ptr<AnthemGraphCompilerEdge>>& edgeContainer,
    std::shared_ptr<NodeConnection>& connection
  ) {
		auto& sourceNode = Anthem::getInstance().project->processingGraph()->nodes()->at(connection->sourceNodeId());
		auto& destinationNode = Anthem::getInstance().project->processingGraph()->nodes()->at(connection->destinationNodeId());

		auto& sourceNodePort = sourceNode->audioOutputPorts()->at(connection->sourcePortId());
		auto& destinationNodePort = destinationNode->audioInputPorts()->at(connection->destinationPortId());

		auto& sourceCompilerNode = nodeToCompilerNode[sourceNode.get()];
		auto& destinationCompilerNode = nodeToCompilerNode[destinationNode.get()];

    auto sourceNodeContext = sourceCompilerNode->context;
		auto destinationNodeContext = destinationCompilerNode->context;

    auto portType = sourceNodePort->config()->dataType();

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
