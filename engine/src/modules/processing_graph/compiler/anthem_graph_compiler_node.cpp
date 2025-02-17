/*
  Copyright (C) 2024 - 2025 Joshua Wade

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

#include "anthem_graph_compiler_node.h"
#include "modules/core/anthem.h"

void AnthemGraphCompilerNode::assignEdges(
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

  for (auto& port : *node->eventInputPorts()) {
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

  for (auto& port : *node->eventOutputPorts()) {
    for (auto& connectionId : *port->connections()) {
      auto& connection = Anthem::getInstance().project->processingGraph()->connections()->at(connectionId);
      assignEdge(nodeToCompilerNode, connectionToCompilerEdge, outputEdges, connection);
    }
  }
}

void AnthemGraphCompilerNode::assignEdge(
  std::map<Node*, std::shared_ptr<AnthemGraphCompilerNode>>& nodeToCompilerNode,
  std::map<NodeConnection*, std::shared_ptr<AnthemGraphCompilerEdge>>& connectionToCompilerEdge,
  std::vector<std::shared_ptr<AnthemGraphCompilerEdge>>& edgeContainer,
  std::shared_ptr<NodeConnection>& connection
) {
  auto& sourceNode = Anthem::getInstance().project->processingGraph()->nodes()->at(connection->sourceNodeId());
  auto& destinationNode = Anthem::getInstance().project->processingGraph()->nodes()->at(connection->destinationNodeId());

  auto sourceNodePort = sourceNode->getPortById(connection->sourcePortId());
  auto destinationNodePort = destinationNode->getPortById(connection->destinationPortId());

  auto& sourceCompilerNode = nodeToCompilerNode[sourceNode.get()];
  auto& destinationCompilerNode = nodeToCompilerNode[destinationNode.get()];

  auto sourceNodeContext = sourceCompilerNode->context;
  auto destinationNodeContext = destinationCompilerNode->context;

  auto portType = sourceNodePort.value()->config()->dataType();

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
