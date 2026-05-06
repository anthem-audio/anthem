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
#include "modules/core/constants.h"
#include "modules/processing_graph/model/node.h"
#include "modules/processing_graph/model/node_connection.h"
#include "modules/processing_graph/model/node_port.h"
#include "modules/processing_graph/runtime/node_process_context.h"

#include <stdexcept>
#include <string>
#include <unordered_set>
#include <utility>

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
using BufferBindingsByNodeId =
    std::unordered_map<RuntimeNode::Id, NodeProcessContext::BufferBindings>;

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

size_t getBufferIndex(const NodeProcessContext::BufferBindings& bindings,
    NodePortDataType dataType,
    NodeProcessContext::BufferDirection direction,
    int64_t id) {
  switch (dataType) {
    case NodePortDataType::audio:
      return direction == NodeProcessContext::BufferDirection::input
                 ? bindings.inputAudioBuffers.at(id)
                 : bindings.outputAudioBuffers.at(id);
    case NodePortDataType::control:
      return direction == NodeProcessContext::BufferDirection::input
                 ? bindings.inputControlBuffers.at(id)
                 : bindings.outputControlBuffers.at(id);
    case NodePortDataType::event:
      return direction == NodeProcessContext::BufferDirection::input
                 ? bindings.inputEventBuffers.at(id)
                 : bindings.outputEventBuffers.at(id);
  }

  throw std::runtime_error("Processing graph received an unsupported port data type.");
}

anthem::NodeConnection& getGraphConnection(
    GraphConnectionMap& graphConnections, int64_t connectionId) {
  auto connectionIter = graphConnections.find(connectionId);
  if (connectionIter == graphConnections.end()) {
    throw std::runtime_error(
        "Processing graph connection ID not found: " + std::to_string(connectionId));
  }

  return *connectionIter->second;
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

    runtimeGraph.nodes.at(nodeId).connectionTransferActions.reserve(incomingConnectionCount);
  }

  runtimeGraph.graphProcessContext->reserve(
      graphNodes.size(), totalAudioBufferCount, totalControlBufferCount, totalEventBufferCount);
}

void createNodeProcessContexts(
    RuntimeGraph& runtimeGraph, BufferBindingsByNodeId& bufferBindingsByNodeId) {
  jassert(runtimeGraph.graphProcessContext != nullptr);

  for (auto& [_, runtimeNode] : runtimeGraph.nodes) {
    if (runtimeNode.sourceNode == nullptr) {
      throw std::runtime_error("Processing graph cannot create a context for a null graph node.");
    }

    auto bufferBindingsIter = bufferBindingsByNodeId.find(runtimeNode.id);
    if (bufferBindingsIter == bufferBindingsByNodeId.end()) {
      throw std::runtime_error(
          "Processing graph cannot create a context without buffer bindings for node: " +
          std::to_string(runtimeNode.id));
    }

    auto& nodeProcessContext = runtimeGraph.graphProcessContext->createNodeProcessContext(
        runtimeNode.sourceNode, std::move(bufferBindingsIter->second));
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

RuntimeNode& addConnectionToRuntimeGraph(RuntimeGraph& runtimeGraph,
    UniqueDestinationMap& uniqueDestinationIdsBySource,
    RuntimeNode::Id inputPortNodeId,
    anthem::NodeConnection& connection) {
  auto sourceNodeId = connection.sourceNodeId();
  auto destinationNodeId = connection.destinationNodeId();

  if (destinationNodeId != inputPortNodeId) {
    throw std::runtime_error("Processing graph connection destination does not match input port "
                             "owner node: " +
                             std::to_string(connection.id()));
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

  auto uniqueDestinationIdsIter = uniqueDestinationIdsBySource.find(sourceNodeId);
  if (uniqueDestinationIdsIter == uniqueDestinationIdsBySource.end()) {
    auto [insertedIter, _] =
        uniqueDestinationIdsBySource.emplace(sourceNodeId, std::unordered_set<RuntimeNode::Id>{});
    uniqueDestinationIdsIter = insertedIter;
  }

  auto& uniqueDestinationIds = uniqueDestinationIdsIter->second;
  auto [_, wasInserted] = uniqueDestinationIds.insert(destinationNodeId);

  if (!wasInserted) {
    return destinationNode;
  }

  sourceNode.outgoingConnections.push_back(&destinationNode);
  destinationNode.upstreamNodeCount++;

  return destinationNode;
}

void addConnectionSourceToTransferAction(RuntimeConnectionTransferAction& action,
    RuntimeNode*& destinationRuntimeNode,
    RuntimeGraph& runtimeGraph,
    UniqueDestinationMap& uniqueDestinationIdsBySource,
    anthem::NodeConnection& connection,
    NodePortDataType dataType,
    RuntimeNode::Id inputPortNodeId,
    BufferBindingsByNodeId& bufferBindingsByNodeId) {
  auto& destinationNode = addConnectionToRuntimeGraph(
      runtimeGraph, uniqueDestinationIdsBySource, inputPortNodeId, connection);
  destinationRuntimeNode = &destinationNode;

  auto sourceBufferIndex = getBufferIndex(bufferBindingsByNodeId.at(connection.sourceNodeId()),
      dataType,
      NodeProcessContext::BufferDirection::output,
      connection.sourcePortId());
  action.sourceBufferIndices.push_back(sourceBufferIndex);
}

void reserveBufferBindingStorage(
    NodeProcessContext::BufferBindings& bindings, anthem::Node& graphNode) {
  bindings.inputAudioBuffers.reserve(graphNode.audioInputPorts()->size());
  bindings.outputAudioBuffers.reserve(graphNode.audioOutputPorts()->size());
  bindings.inputControlBuffers.reserve(graphNode.controlInputPorts()->size());
  bindings.outputControlBuffers.reserve(graphNode.controlOutputPorts()->size());
  bindings.inputEventBuffers.reserve(graphNode.eventInputPorts()->size());
  bindings.outputEventBuffers.reserve(graphNode.eventOutputPorts()->size());
  bindings.rt_eventBuffersToClear.reserve(
      graphNode.eventInputPorts()->size() + graphNode.eventOutputPorts()->size());
  bindings.rt_parameterInputPortsToWrite.reserve(graphNode.controlInputPorts()->size());
}

void bindOutputPortBuffers(RuntimeGraph& runtimeGraph,
    anthem::Node& graphNode,
    NodeProcessContext::BufferBindings& bindings) {
  jassert(runtimeGraph.graphProcessContext != nullptr);

  for (auto& port : *graphNode.audioOutputPorts()) {
    bindings.outputAudioBuffers.emplace(
        port->id(), runtimeGraph.graphProcessContext->allocateAudioBuffer());
  }

  for (auto& port : *graphNode.controlOutputPorts()) {
    bindings.outputControlBuffers.emplace(
        port->id(), runtimeGraph.graphProcessContext->allocateControlBuffer());
  }

  for (auto& port : *graphNode.eventOutputPorts()) {
    // TODO: Seed initial capacities from persisted per-port runtime hints once
    // graph recompilation can preserve processing state across compiles.
    auto bufferIndex =
        runtimeGraph.graphProcessContext->allocateEventBuffer(DEFAULT_EVENT_BUFFER_SIZE);
    bindings.outputEventBuffers.emplace(port->id(), bufferIndex);
    bindings.rt_eventBuffersToClear.push_back(bufferIndex);
  }
}

void bindAudioInputPort(RuntimeGraph& runtimeGraph,
    GraphConnectionMap& graphConnections,
    UniqueDestinationMap& uniqueDestinationIdsBySource,
    BufferBindingsByNodeId& bufferBindingsByNodeId,
    RuntimeNode::Id inputPortNodeId,
    NodePort& inputPort,
    NodeProcessContext::BufferBindings& bindings) {
  jassert(runtimeGraph.graphProcessContext != nullptr);

  auto connectionCount = inputPort.connections()->size();

  // If there are no inputs, we will only read silence. There is a shared
  // silence buffer for this, which should hopefully be more cache-friendly.
  if (connectionCount == 0) {
    bindings.inputAudioBuffers.emplace(
        inputPort.id(), runtimeGraph.graphProcessContext->getSharedSilentAudioBufferIndex());
    return;
  }

  // For input ports with only one incoming connection, which is probably most
  // ports, we can skip the copy step and just direct the node/processor to read
  // directly from the output port's buffer.
  if (connectionCount == 1) {
    auto& connection = getGraphConnection(graphConnections, inputPort.connections()->at(0));
    addConnectionToRuntimeGraph(
        runtimeGraph, uniqueDestinationIdsBySource, inputPortNodeId, connection);

    auto sourceBufferIndex = getBufferIndex(bufferBindingsByNodeId.at(connection.sourceNodeId()),
        NodePortDataType::audio,
        NodeProcessContext::BufferDirection::output,
        connection.sourcePortId());
    bindings.inputAudioBuffers.emplace(inputPort.id(), sourceBufferIndex);
    return;
  }

  // Finally, the only case where we need a dedicated input buffer is when the
  // input port has multiple incoming connections. In this case, we sum all the
  // connected output buffers into the input buffer.

  auto destinationBufferIndex = runtimeGraph.graphProcessContext->allocateAudioBuffer();
  bindings.inputAudioBuffers.emplace(inputPort.id(), destinationBufferIndex);

  RuntimeConnectionTransferAction action;
  action.dataType = RuntimeConnectionDataType::audio;
  action.destinationBufferIndex = destinationBufferIndex;
  action.sourceBufferIndices.reserve(connectionCount);
  RuntimeNode* destinationRuntimeNode = nullptr;

  for (auto connectionId : *inputPort.connections()) {
    auto& connection = getGraphConnection(graphConnections, connectionId);
    addConnectionSourceToTransferAction(action,
        destinationRuntimeNode,
        runtimeGraph,
        uniqueDestinationIdsBySource,
        connection,
        NodePortDataType::audio,
        inputPortNodeId,
        bufferBindingsByNodeId);
  }

  jassert(destinationRuntimeNode != nullptr);
  if (destinationRuntimeNode != nullptr) {
    destinationRuntimeNode->connectionTransferActions.push_back(std::move(action));
  }
}

void bindControlInputPort(RuntimeGraph& runtimeGraph,
    GraphConnectionMap& graphConnections,
    UniqueDestinationMap& uniqueDestinationIdsBySource,
    BufferBindingsByNodeId& bufferBindingsByNodeId,
    RuntimeNode::Id inputPortNodeId,
    NodePort& inputPort,
    NodeProcessContext::BufferBindings& bindings) {
  // The logic here for zero-, one- and multi-input ports is similar to audio
  // ports, which is documented above.

  jassert(runtimeGraph.graphProcessContext != nullptr);

  auto connectionCount = inputPort.connections()->size();

  if (connectionCount == 0) {
    auto bufferIndex = runtimeGraph.graphProcessContext->allocateControlBuffer();
    runtimeGraph.graphProcessContext->getControlBuffer(bufferIndex).clear();
    bindings.inputControlBuffers.emplace(inputPort.id(), bufferIndex);

    if (inputPort.config()->parameterConfig().has_value()) {
      bindings.rt_parameterInputPortsToWrite.insert(inputPort.id());
    }

    return;
  }

  if (connectionCount == 1) {
    auto& connection = getGraphConnection(graphConnections, inputPort.connections()->at(0));
    addConnectionToRuntimeGraph(
        runtimeGraph, uniqueDestinationIdsBySource, inputPortNodeId, connection);

    // A single-source input can read directly from the source output. Fan-in
    // inputs below get a dedicated destination buffer and transfer action.
    auto sourceBufferIndex = getBufferIndex(bufferBindingsByNodeId.at(connection.sourceNodeId()),
        NodePortDataType::control,
        NodeProcessContext::BufferDirection::output,
        connection.sourcePortId());
    bindings.inputControlBuffers.emplace(inputPort.id(), sourceBufferIndex);
    return;
  }

  auto destinationBufferIndex = runtimeGraph.graphProcessContext->allocateControlBuffer();
  bindings.inputControlBuffers.emplace(inputPort.id(), destinationBufferIndex);

  RuntimeConnectionTransferAction action;
  action.dataType = RuntimeConnectionDataType::control;
  action.destinationBufferIndex = destinationBufferIndex;
  action.sourceBufferIndices.reserve(connectionCount);
  RuntimeNode* destinationRuntimeNode = nullptr;

  for (auto connectionId : *inputPort.connections()) {
    auto& connection = getGraphConnection(graphConnections, connectionId);
    addConnectionSourceToTransferAction(action,
        destinationRuntimeNode,
        runtimeGraph,
        uniqueDestinationIdsBySource,
        connection,
        NodePortDataType::control,
        inputPortNodeId,
        bufferBindingsByNodeId);
  }

  jassert(destinationRuntimeNode != nullptr);
  if (destinationRuntimeNode != nullptr) {
    destinationRuntimeNode->connectionTransferActions.push_back(std::move(action));
  }
}

void bindEventInputPort(RuntimeGraph& runtimeGraph,
    GraphConnectionMap& graphConnections,
    UniqueDestinationMap& uniqueDestinationIdsBySource,
    BufferBindingsByNodeId& bufferBindingsByNodeId,
    RuntimeNode::Id inputPortNodeId,
    NodePort& inputPort,
    NodeProcessContext::BufferBindings& bindings) {
  // The logic here for zero-, one- and multi-input ports is similar to audio
  // ports, which is documented above.

  jassert(runtimeGraph.graphProcessContext != nullptr);

  auto connectionCount = inputPort.connections()->size();

  if (connectionCount == 0) {
    bindings.inputEventBuffers.emplace(
        inputPort.id(), runtimeGraph.graphProcessContext->getSharedEmptyEventBufferIndex());
    return;
  }

  if (connectionCount == 1) {
    auto& connection = getGraphConnection(graphConnections, inputPort.connections()->at(0));
    addConnectionToRuntimeGraph(
        runtimeGraph, uniqueDestinationIdsBySource, inputPortNodeId, connection);

    // A single-source input can read directly from the source output. Fan-in
    // inputs below get a dedicated destination buffer and transfer action.
    auto sourceBufferIndex = getBufferIndex(bufferBindingsByNodeId.at(connection.sourceNodeId()),
        NodePortDataType::event,
        NodeProcessContext::BufferDirection::output,
        connection.sourcePortId());
    bindings.inputEventBuffers.emplace(inputPort.id(), sourceBufferIndex);
    return;
  }

  // TODO: Seed initial capacities from persisted per-port runtime hints once
  // graph recompilation can preserve processing state across compiles.
  auto destinationBufferIndex =
      runtimeGraph.graphProcessContext->allocateEventBuffer(DEFAULT_EVENT_BUFFER_SIZE);
  bindings.inputEventBuffers.emplace(inputPort.id(), destinationBufferIndex);
  bindings.rt_eventBuffersToClear.push_back(destinationBufferIndex);

  RuntimeConnectionTransferAction action;
  action.dataType = RuntimeConnectionDataType::event;
  action.destinationBufferIndex = destinationBufferIndex;
  action.sourceBufferIndices.reserve(connectionCount);
  RuntimeNode* destinationRuntimeNode = nullptr;

  for (auto connectionId : *inputPort.connections()) {
    auto& connection = getGraphConnection(graphConnections, connectionId);
    addConnectionSourceToTransferAction(action,
        destinationRuntimeNode,
        runtimeGraph,
        uniqueDestinationIdsBySource,
        connection,
        NodePortDataType::event,
        inputPortNodeId,
        bufferBindingsByNodeId);
  }

  jassert(destinationRuntimeNode != nullptr);
  if (destinationRuntimeNode != nullptr) {
    destinationRuntimeNode->connectionTransferActions.push_back(std::move(action));
  }
}

void bindInputPortBuffers(RuntimeGraph& runtimeGraph,
    GraphConnectionMap& graphConnections,
    UniqueDestinationMap& uniqueDestinationIdsBySource,
    BufferBindingsByNodeId& bufferBindingsByNodeId,
    anthem::Node& graphNode,
    NodeProcessContext::BufferBindings& bindings) {
  for (auto& inputPort : *graphNode.audioInputPorts()) {
    bindAudioInputPort(runtimeGraph,
        graphConnections,
        uniqueDestinationIdsBySource,
        bufferBindingsByNodeId,
        graphNode.id(),
        *inputPort,
        bindings);
  }

  for (auto& inputPort : *graphNode.controlInputPorts()) {
    bindControlInputPort(runtimeGraph,
        graphConnections,
        uniqueDestinationIdsBySource,
        bufferBindingsByNodeId,
        graphNode.id(),
        *inputPort,
        bindings);
  }

  for (auto& inputPort : *graphNode.eventInputPorts()) {
    bindEventInputPort(runtimeGraph,
        graphConnections,
        uniqueDestinationIdsBySource,
        bufferBindingsByNodeId,
        graphNode.id(),
        *inputPort,
        bindings);
  }
}

BufferBindingsByNodeId createBufferBindingsAndConnections(RuntimeGraph& runtimeGraph,
    ModelUnorderedMap<int64_t, std::shared_ptr<anthem::Node>>& graphNodes,
    GraphConnectionMap& graphConnections) {
  BufferBindingsByNodeId bufferBindingsByNodeId;
  bufferBindingsByNodeId.reserve(runtimeGraph.nodes.size());

  for (auto& [nodeId, graphNode] : graphNodes) {
    auto [bindingsIter, _] =
        bufferBindingsByNodeId.emplace(nodeId, NodeProcessContext::BufferBindings{});
    auto& bindings = bindingsIter->second;

    reserveBufferBindingStorage(bindings, *graphNode);
    bindOutputPortBuffers(runtimeGraph, *graphNode, bindings);
  }

  UniqueDestinationMap uniqueDestinationIdsBySource;
  uniqueDestinationIdsBySource.reserve(graphNodes.size());

  for (auto& [nodeId, graphNode] : graphNodes) {
    auto bindingsIter = bufferBindingsByNodeId.find(nodeId);
    if (bindingsIter == bufferBindingsByNodeId.end()) {
      throw std::runtime_error(
          "Processing graph buffer bindings missing for node: " + std::to_string(nodeId));
    }

    bindInputPortBuffers(runtimeGraph,
        graphConnections,
        uniqueDestinationIdsBySource,
        bufferBindingsByNodeId,
        *graphNode,
        bindingsIter->second);
  }

  return bufferBindingsByNodeId;
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
  auto bufferBindingsByNodeId =
      createBufferBindingsAndConnections(runtimeGraph, graphNodes, graphConnections);
  createNodeProcessContexts(runtimeGraph, bufferBindingsByNodeId);

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
