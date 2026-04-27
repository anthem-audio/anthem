/*
  Copyright (C) 2026 Joshua Wade

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

#include "runtime_graph.h"

#include "generated/lib/model/processing_graph/processing_graph.h"
#include "modules/processing_graph/model/node.h"
#include "modules/processing_graph/model/node_connection.h"
#include "modules/processing_graph/model/node_port.h"

#include <stdexcept>
#include <string>
#include <unordered_set>

namespace anthem::threaded_graph {

namespace {

enum class DfsState : uint8_t {
  unvisited,
  visiting,
  visited,
};

using UniqueDestinationMap = std::unordered_map<Node::Id, std::unordered_set<Node::Id>>;
using GraphConnectionMap = ModelUnorderedMap<int64_t, std::shared_ptr<anthem::NodeConnection>>;

void addConnectionToRuntimeGraph(RuntimeGraph& runtimeGraph,
    GraphConnectionMap& graphConnections,
    UniqueDestinationMap& uniqueDestinationIdsBySource,
    Node::Id inputPortNodeId,
    int64_t connectionId) {
  auto connectionIter = graphConnections.find(connectionId);
  if (connectionIter == graphConnections.end()) {
    throw std::invalid_argument(
        "Threaded graph connection ID not found: " + std::to_string(connectionId));
  }

  auto& connection = *connectionIter->second;
  auto sourceNodeId = connection.sourceNodeId();
  auto destinationNodeId = connection.destinationNodeId();

  if (destinationNodeId != inputPortNodeId) {
    throw std::invalid_argument("Threaded graph connection destination does not match input port "
                                "owner node: " +
                                std::to_string(connectionId));
  }

  auto sourceNodeIter = runtimeGraph.nodes.find(sourceNodeId);
  if (sourceNodeIter == runtimeGraph.nodes.end()) {
    throw std::invalid_argument(
        "Threaded graph source node ID not found: " + std::to_string(sourceNodeId));
  }

  auto destinationNodeIter = runtimeGraph.nodes.find(destinationNodeId);
  if (destinationNodeIter == runtimeGraph.nodes.end()) {
    throw std::invalid_argument(
        "Threaded graph destination node ID not found: " + std::to_string(destinationNodeId));
  }

  auto& uniqueDestinationIds = uniqueDestinationIdsBySource[sourceNodeId];
  auto [_, wasInserted] = uniqueDestinationIds.insert(destinationNodeId);

  if (!wasInserted) {
    return;
  }

  auto& sourceNode = sourceNodeIter->second;
  auto& destinationNode = destinationNodeIter->second;

  sourceNode.outgoingConnections.push_back(&destinationNode);
  destinationNode.upstreamNodeCount++;
}

void addInputPortConnectionsToRuntimeGraph(RuntimeGraph& runtimeGraph,
    GraphConnectionMap& graphConnections,
    UniqueDestinationMap& uniqueDestinationIdsBySource,
    anthem::Node& graphNode,
    ModelVector<std::shared_ptr<NodePort>>& inputPorts) {
  for (auto& inputPort : inputPorts) {
    for (auto connectionId : *inputPort->connections()) {
      addConnectionToRuntimeGraph(runtimeGraph,
          graphConnections,
          uniqueDestinationIdsBySource,
          graphNode.id(),
          connectionId);
    }
  }
}

void assertAcyclicFromNode(Node& node, std::unordered_map<Node::Id, DfsState>& dfsStates) {
  auto& state = dfsStates[node.id];

  if (state == DfsState::visiting) {
    throw std::runtime_error(
        "Cycle detected in threaded graph at node: " + std::to_string(node.id));
  }

  if (state == DfsState::visited) {
    return;
  }

  state = DfsState::visiting;

  for (auto* downstreamNode : node.outgoingConnections) {
    assertAcyclicFromNode(*downstreamNode, dfsStates);
  }

  state = DfsState::visited;
}

} // namespace

RuntimeGraph RuntimeGraph::fromProcessingGraph(ProcessingGraphModel& processingGraph) {
  RuntimeGraph runtimeGraph;

  auto& graphNodes = *processingGraph.nodes();
  auto& graphConnections = *processingGraph.connections();

  runtimeGraph.nodes.reserve(graphNodes.size());

  for (auto& [nodeId, graphNode] : graphNodes) {
    if (graphNode == nullptr) {
      throw std::invalid_argument("Threaded graph cannot build from a null graph node.");
    }

    if (nodeId != graphNode->id()) {
      throw std::invalid_argument(
          "Threaded graph node map key does not match node ID: " + std::to_string(nodeId));
    }

    runtimeGraph.nodes.emplace(nodeId, Node{.id = nodeId});
  }

  UniqueDestinationMap uniqueDestinationIdsBySource;
  uniqueDestinationIdsBySource.reserve(graphNodes.size());

  for (auto& [_, graphNode] : graphNodes) {
    addInputPortConnectionsToRuntimeGraph(runtimeGraph,
        graphConnections,
        uniqueDestinationIdsBySource,
        *graphNode,
        *graphNode->audioInputPorts());
    addInputPortConnectionsToRuntimeGraph(runtimeGraph,
        graphConnections,
        uniqueDestinationIdsBySource,
        *graphNode,
        *graphNode->controlInputPorts());
    addInputPortConnectionsToRuntimeGraph(runtimeGraph,
        graphConnections,
        uniqueDestinationIdsBySource,
        *graphNode,
        *graphNode->eventInputPorts());
  }

  runtimeGraph.inputNodes.reserve(runtimeGraph.nodes.size());

  for (auto& [_, runtimeNode] : runtimeGraph.nodes) {
    if (runtimeNode.upstreamNodeCount == 0) {
      runtimeGraph.inputNodes.push_back(&runtimeNode);
    }
  }

  std::unordered_map<Node::Id, DfsState> dfsStates;
  dfsStates.reserve(runtimeGraph.nodes.size());

  // We do input nodes first, because in all correctly-formed graphs, this will
  // cover all nodes
  for (auto* inputNode : runtimeGraph.inputNodes) {
    assertAcyclicFromNode(*inputNode, dfsStates);
  }

  // A graph that is entirely cyclic has no input nodes, so input-rooted DFS is
  // not sufficient on its own.
  for (auto& [_, runtimeNode] : runtimeGraph.nodes) {
    assertAcyclicFromNode(runtimeNode, dfsStates);
  }

  return runtimeGraph;
}

} // namespace anthem::threaded_graph
