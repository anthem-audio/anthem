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
#include "modules/processing_graph/runtime/node_process_context.h"

#include <stdexcept>
#include <string>
#include <unordered_set>

namespace anthem {

bool RuntimeNodePriorityComparator::operator()(
    const RuntimeNode* left, const RuntimeNode* right) const {
  if (left->priority == right->priority) {
    return left->id > right->id;
  }

  return left->priority < right->priority;
}

namespace {

enum class DfsState : uint8_t {
  unvisited = 0,
  visiting,
  visited,
};

using UniqueDestinationMap =
    std::unordered_map<RuntimeNode::Id, std::unordered_set<RuntimeNode::Id>>;
using GraphConnectionMap = ModelUnorderedMap<int64_t, std::shared_ptr<anthem::NodeConnection>>;

RuntimeConnectionDataType toRuntimeConnectionDataType(NodePortDataType dataType) {
  switch (dataType) {
    case NodePortDataType::audio:
      return RuntimeConnectionDataType::audio;
    case NodePortDataType::control:
      return RuntimeConnectionDataType::control;
    case NodePortDataType::event:
      return RuntimeConnectionDataType::event;
  }

  throw std::runtime_error("Processing graph received an unsupported port data type.");
}

void reserveRuntimeGraphStorage(RuntimeGraph& runtimeGraph,
    ModelUnorderedMap<int64_t, std::shared_ptr<anthem::Node>>& graphNodes) {
  size_t totalAudioBufferCount = 0;
  size_t totalControlBufferCount = 0;
  size_t totalEventBufferCount = 0;

  for (auto& [nodeId, graphNode] : graphNodes) {
    totalAudioBufferCount +=
        graphNode->audioInputPorts()->size() + graphNode->audioOutputPorts()->size();
    totalControlBufferCount +=
        graphNode->controlInputPorts()->size() + graphNode->controlOutputPorts()->size();
    totalEventBufferCount +=
        graphNode->eventInputPorts()->size() + graphNode->eventOutputPorts()->size();

    size_t incomingConnectionCount = 0;

    for (auto& port : *graphNode->audioInputPorts()) {
      incomingConnectionCount += port->connections()->size();
    }

    for (auto& port : *graphNode->controlInputPorts()) {
      incomingConnectionCount += port->connections()->size();
    }

    for (auto& port : *graphNode->eventInputPorts()) {
      incomingConnectionCount += port->connections()->size();
    }

    runtimeGraph.nodes.at(nodeId).incomingConnectionCopies.reserve(incomingConnectionCount);
  }

  runtimeGraph.inputNodes.reserve(graphNodes.size());
  runtimeGraph.graphProcessContext->reserve(
      graphNodes.size(), totalAudioBufferCount, totalControlBufferCount, totalEventBufferCount);
}

void createNodeProcessContexts(RuntimeGraph& runtimeGraph) {
  jassert(runtimeGraph.graphProcessContext != nullptr);

  for (auto& [_, runtimeNode] : runtimeGraph.nodes) {
    if (runtimeNode.sourceNode == nullptr) {
      throw std::runtime_error("Processing graph cannot create a context for a null graph node.");
    }

    auto& nodeProcessContext =
        runtimeGraph.graphProcessContext->createNodeProcessContext(runtimeNode.sourceNode);
    runtimeNode.nodeProcessContext = &nodeProcessContext;

    auto processor = runtimeNode.sourceNode->getProcessor();
    if (processor.has_value()) {
      runtimeNode.processor = processor.value().get();
    }
  }
}

void publishRuntimeContexts(RuntimeGraph& runtimeGraph) {
  for (auto& [_, runtimeNode] : runtimeGraph.nodes) {
    runtimeNode.sourceNode->runtimeContext = runtimeNode.nodeProcessContext;
  }
}

void addIncomingConnectionCopyToRuntimeNode(RuntimeNode& sourceNode,
    RuntimeNode& destinationNode,
    anthem::NodeConnection& connection,
    NodePortDataType dataType) {
  if (sourceNode.nodeProcessContext == nullptr || destinationNode.nodeProcessContext == nullptr) {
    throw std::runtime_error("Processing graph connection encountered a node without a context.");
  }

  auto sourceBufferIndex = sourceNode.nodeProcessContext->getBufferIndex(
      dataType, NodeProcessContext::BufferDirection::output, connection.sourcePortId());
  auto destinationBufferIndex = destinationNode.nodeProcessContext->getBufferIndex(
      dataType, NodeProcessContext::BufferDirection::input, connection.destinationPortId());

  destinationNode.incomingConnectionCopies.push_back(RuntimeConnectionCopy{
      .dataType = toRuntimeConnectionDataType(dataType),
      .sourceBufferIndex = sourceBufferIndex,
      .destinationBufferIndex = destinationBufferIndex,
  });
}

void addConnectionToRuntimeGraph(RuntimeGraph& runtimeGraph,
    GraphConnectionMap& graphConnections,
    UniqueDestinationMap& uniqueDestinationIdsBySource,
    RuntimeNode::Id inputPortNodeId,
    NodePortDataType dataType,
    int64_t connectionId) {
  auto connectionIter = graphConnections.find(connectionId);
  if (connectionIter == graphConnections.end()) {
    throw std::runtime_error(
        "Processing graph connection ID not found: " + std::to_string(connectionId));
  }

  auto& connection = *connectionIter->second;
  auto sourceNodeId = connection.sourceNodeId();
  auto destinationNodeId = connection.destinationNodeId();

  if (destinationNodeId != inputPortNodeId) {
    throw std::runtime_error("Processing graph connection destination does not match input port "
                             "owner node: " +
                             std::to_string(connectionId));
  }

  auto sourceNodeIter = runtimeGraph.nodes.find(sourceNodeId);
  if (sourceNodeIter == runtimeGraph.nodes.end()) {
    throw std::runtime_error(
        "Processing graph source node ID not found: " + std::to_string(sourceNodeId));
  }

  auto destinationNodeIter = runtimeGraph.nodes.find(destinationNodeId);
  if (destinationNodeIter == runtimeGraph.nodes.end()) {
    throw std::runtime_error(
        "Processing graph destination node ID not found: " + std::to_string(destinationNodeId));
  }

  auto& sourceNode = sourceNodeIter->second;
  auto& destinationNode = destinationNodeIter->second;

  addIncomingConnectionCopyToRuntimeNode(sourceNode, destinationNode, connection, dataType);

  auto uniqueDestinationIdsIter = uniqueDestinationIdsBySource.find(sourceNodeId);
  if (uniqueDestinationIdsIter == uniqueDestinationIdsBySource.end()) {
    auto [insertedIter, _] =
        uniqueDestinationIdsBySource.emplace(sourceNodeId, std::unordered_set<RuntimeNode::Id>{});
    uniqueDestinationIdsIter = insertedIter;
  }

  auto& uniqueDestinationIds = uniqueDestinationIdsIter->second;
  auto [_, wasInserted] = uniqueDestinationIds.insert(destinationNodeId);

  if (!wasInserted) {
    return;
  }

  sourceNode.outgoingConnections.push_back(&destinationNode);
  destinationNode.upstreamNodeCount++;
}

void addInputPortConnectionsToRuntimeGraph(RuntimeGraph& runtimeGraph,
    GraphConnectionMap& graphConnections,
    UniqueDestinationMap& uniqueDestinationIdsBySource,
    anthem::Node& graphNode,
    ModelVector<std::shared_ptr<NodePort>>& inputPorts,
    NodePortDataType dataType) {
  for (auto& inputPort : inputPorts) {
    for (auto connectionId : *inputPort->connections()) {
      addConnectionToRuntimeGraph(runtimeGraph,
          graphConnections,
          uniqueDestinationIdsBySource,
          graphNode.id(),
          dataType,
          connectionId);
    }
  }
}

void assertAcyclicFromNode(
    RuntimeNode& node, std::unordered_map<RuntimeNode::Id, DfsState>& dfsStates) {
  auto dfsStateIter = dfsStates.find(node.id);
  if (dfsStateIter == dfsStates.end()) {
    auto [insertedIter, _] = dfsStates.emplace(node.id, DfsState::unvisited);
    dfsStateIter = insertedIter;
  }

  auto& state = dfsStateIter->second;

  if (state == DfsState::visiting) {
    throw std::runtime_error(
        "Cycle detected in processing graph at node: " + std::to_string(node.id));
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

size_t getAndSetPriority(RuntimeNode& node) {
  if (node.priority != 0) {
    return node.priority;
  }

  size_t priority = 1;

  for (auto* downstreamNode : node.outgoingConnections) {
    priority += getAndSetPriority(*downstreamNode);
  }

  node.priority = priority;
  return priority;
}

} // namespace

std::unique_ptr<RuntimeGraph> RuntimeGraph::fromProcessingGraph(
    ProcessingGraphModel& processingGraph,
    GraphRuntimeServices& rtServices,
    const GraphBufferLayout& bufferLayout,
    double sampleRate) {
  auto& graphNodes = *processingGraph.nodes();
  auto& graphConnections = *processingGraph.connections();

  auto runtimeGraphStorage = std::make_unique<RuntimeGraph>(graphNodes.size());
  auto& runtimeGraph = *runtimeGraphStorage;

  runtimeGraph.sampleRate = static_cast<float>(sampleRate);
  runtimeGraph.graphProcessContext =
      std::make_unique<GraphProcessContext>(rtServices, bufferLayout);
  runtimeGraph.nodes.reserve(graphNodes.size());

  for (auto& [nodeId, graphNode] : graphNodes) {
    if (graphNode == nullptr) {
      throw std::runtime_error("Processing graph cannot build from a null graph node.");
    }

    if (nodeId != graphNode->id()) {
      throw std::runtime_error(
          "Processing graph node map key does not match node ID: " + std::to_string(nodeId));
    }

    runtimeGraph.nodes.emplace(nodeId, RuntimeNode(nodeId, graphNode));
  }

  reserveRuntimeGraphStorage(runtimeGraph, graphNodes);
  createNodeProcessContexts(runtimeGraph);

  UniqueDestinationMap uniqueDestinationIdsBySource;
  uniqueDestinationIdsBySource.reserve(graphNodes.size());

  for (auto& [_, graphNode] : graphNodes) {
    addInputPortConnectionsToRuntimeGraph(runtimeGraph,
        graphConnections,
        uniqueDestinationIdsBySource,
        *graphNode,
        *graphNode->audioInputPorts(),
        NodePortDataType::audio);
    addInputPortConnectionsToRuntimeGraph(runtimeGraph,
        graphConnections,
        uniqueDestinationIdsBySource,
        *graphNode,
        *graphNode->controlInputPorts(),
        NodePortDataType::control);
    addInputPortConnectionsToRuntimeGraph(runtimeGraph,
        graphConnections,
        uniqueDestinationIdsBySource,
        *graphNode,
        *graphNode->eventInputPorts(),
        NodePortDataType::event);
  }

  for (auto& [_, runtimeNode] : runtimeGraph.nodes) {
    if (runtimeNode.upstreamNodeCount == 0) {
      runtimeGraph.inputNodes.push_back(&runtimeNode);
    }
  }

  std::unordered_map<RuntimeNode::Id, DfsState> dfsStates;
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

  for (auto* inputNode : runtimeGraph.inputNodes) {
    getAndSetPriority(*inputNode);
  }

  for (auto& [_, runtimeNode] : runtimeGraph.nodes) {
    getAndSetPriority(runtimeNode);
  }

  publishRuntimeContexts(runtimeGraph);

  return runtimeGraphStorage;
}

RuntimeGraph::RuntimeGraph() : RuntimeGraph(0) {}

RuntimeGraph::RuntimeGraph(size_t nodeCapacity)
  : availableTasks(createAvailableTaskQueue(nodeCapacity)) {}

RuntimeGraph::~RuntimeGraph() {
  cleanup();
}

void RuntimeGraph::cleanup() {
  if (hasCleanedUp) {
    return;
  }

  for (auto& [_, runtimeNode] : nodes) {
    if (runtimeNode.sourceNode == nullptr || !runtimeNode.sourceNode->runtimeContext.has_value()) {
      continue;
    }

    if (runtimeNode.sourceNode->runtimeContext.value() == runtimeNode.nodeProcessContext) {
      runtimeNode.sourceNode->runtimeContext.reset();
    }
  }

  if (graphProcessContext != nullptr) {
    graphProcessContext->cleanup();
  }

  hasCleanedUp = true;
}

RuntimeGraph::AvailableTaskQueue RuntimeGraph::createAvailableTaskQueue(size_t nodeCapacity) {
  std::vector<RuntimeNode*> taskStorage;
  taskStorage.reserve(nodeCapacity);

  return AvailableTaskQueue(RuntimeNodePriorityComparator(), std::move(taskStorage));
}

} // namespace anthem
