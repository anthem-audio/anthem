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

#include <algorithm>
#include <limits>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

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
// Maps source node ID -> source audio output port ID -> number of outgoing
// audio connections from that port.
using AudioOutputConnectionCountMap =
    std::unordered_map<RuntimeNode::Id, std::unordered_map<int64_t, size_t>>;
using AudioOutputConnectionMap = std::unordered_map<RuntimeNode::Id,
    std::unordered_map<int64_t, std::vector<anthem::NodeConnection*>>>;
using AudioOutputWidthMap = std::unordered_map<RuntimeNode::Id, std::unordered_map<int64_t, int>>;

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
                 ? bindings.inputAudioBuffers.at(id).bufferIndex
                 : bindings.outputAudioBuffers.at(id).bufferIndex;
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

AudioBufferSlice getAudioBufferSlice(const NodeProcessContext::BufferBindings& bindings,
    NodeProcessContext::BufferDirection direction,
    int64_t id) {
  return direction == NodeProcessContext::BufferDirection::input
             ? bindings.inputAudioBuffers.at(id)
             : bindings.outputAudioBuffers.at(id);
}

NodePort& getAudioInputPortById(anthem::Node& graphNode, int64_t portId) {
  for (auto& port : *graphNode.audioInputPorts()) {
    if (port->id() == portId) {
      return *port;
    }
  }

  throw std::runtime_error(
      "Processing graph audio input port ID not found: " + std::to_string(portId));
}

NodePort& getAudioOutputPortById(anthem::Node& graphNode, int64_t portId) {
  for (auto& port : *graphNode.audioOutputPorts()) {
    if (port->id() == portId) {
      return *port;
    }
  }

  throw std::runtime_error(
      "Processing graph audio output port ID not found: " + std::to_string(portId));
}

int getAudioPortChannelCount(RuntimeGraph& runtimeGraph, NodePort& port) {
  jassert(runtimeGraph.graphProcessContext != nullptr);

  const auto configuredChannelCount = port.config()->channelCount();
  const auto channelCount = configuredChannelCount.value_or(
      static_cast<int64_t>(runtimeGraph.graphProcessContext->getDefaultAudioChannelCount()));

  if (channelCount <= 0 || channelCount > std::numeric_limits<int>::max()) {
    throw std::runtime_error(
        "Processing graph audio port has invalid channel count: " + std::to_string(port.id()));
  }

  return static_cast<int>(channelCount);
}

int getNodeAudioProcessChannelCount(RuntimeGraph& runtimeGraph, anthem::Node& graphNode) {
  int result = 0;

  for (auto& port : *graphNode.audioInputPorts()) {
    result = std::max(result, getAudioPortChannelCount(runtimeGraph, *port));
  }

  for (auto& port : *graphNode.audioOutputPorts()) {
    result = std::max(result, getAudioPortChannelCount(runtimeGraph, *port));
  }

  return result;
}

bool hasSingleAudioInputAndOutput(anthem::Node& graphNode) {
  return graphNode.audioInputPorts()->size() == 1 && graphNode.audioOutputPorts()->size() == 1;
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

void addInputPortConnectionsToRuntimeTopology(RuntimeGraph& runtimeGraph,
    UniqueDestinationMap& uniqueDestinationIdsBySource,
    GraphConnectionMap& graphConnections,
    RuntimeNode::Id inputPortNodeId,
    ModelVector<int64_t>& inputPortConnections) {
  for (auto connectionId : inputPortConnections) {
    auto& connection = getGraphConnection(graphConnections, connectionId);
    addConnectionToRuntimeGraph(
        runtimeGraph, uniqueDestinationIdsBySource, inputPortNodeId, connection);
  }
}

void buildRuntimeTopology(RuntimeGraph& runtimeGraph,
    ModelUnorderedMap<int64_t, std::shared_ptr<anthem::Node>>& graphNodes,
    GraphConnectionMap& graphConnections) {
  UniqueDestinationMap uniqueDestinationIdsBySource;
  uniqueDestinationIdsBySource.reserve(graphNodes.size());

  for (auto& [_, graphNode] : graphNodes) {
    for (auto& inputPort : *graphNode->audioInputPorts()) {
      addInputPortConnectionsToRuntimeTopology(runtimeGraph,
          uniqueDestinationIdsBySource,
          graphConnections,
          graphNode->id(),
          *inputPort->connections());
    }

    for (auto& inputPort : *graphNode->controlInputPorts()) {
      addInputPortConnectionsToRuntimeTopology(runtimeGraph,
          uniqueDestinationIdsBySource,
          graphConnections,
          graphNode->id(),
          *inputPort->connections());
    }

    for (auto& inputPort : *graphNode->eventInputPorts()) {
      addInputPortConnectionsToRuntimeTopology(runtimeGraph,
          uniqueDestinationIdsBySource,
          graphConnections,
          graphNode->id(),
          *inputPort->connections());
    }
  }
}

void addConnectionSourceToTransferAction(RuntimeConnectionTransferAction& action,
    anthem::NodeConnection& connection,
    NodePortDataType dataType,
    BufferBindingsByNodeId& bufferBindingsByNodeId) {
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
  bindings.rt_audioBuffersToClear.reserve(
      graphNode.audioInputPorts()->size() + graphNode.audioOutputPorts()->size());
  bindings.rt_eventBuffersToClear.reserve(
      graphNode.eventInputPorts()->size() + graphNode.eventOutputPorts()->size());
  bindings.rt_parameterInputPortsToWrite.reserve(graphNode.controlInputPorts()->size());
}

void bindNonAudioOutputPortBuffers(RuntimeGraph& runtimeGraph,
    anthem::Node& graphNode,
    NodeProcessContext::BufferBindings& bindings) {
  jassert(runtimeGraph.graphProcessContext != nullptr);

  for (auto& port : *graphNode.controlOutputPorts()) {
    bindings.outputControlBuffers.emplace(
        port->id(), runtimeGraph.graphProcessContext->allocateControlBuffer());
  }

  for (auto& port : *graphNode.eventOutputPorts()) {
    // TODO: Seed initial capacities from persisted per-port runtime hints once
    // graph publishing can preserve processing state across publishes.
    auto bufferIndex =
        runtimeGraph.graphProcessContext->allocateEventBuffer(DEFAULT_EVENT_BUFFER_SIZE);
    bindings.outputEventBuffers.emplace(port->id(), bufferIndex);
    bindings.rt_eventBuffersToClear.push_back(bufferIndex);
  }
}

AudioOutputConnectionCountMap buildAudioOutputConnectionCountMap(
    ModelUnorderedMap<int64_t, std::shared_ptr<anthem::Node>>& graphNodes,
    GraphConnectionMap& graphConnections) {
  AudioOutputConnectionCountMap result;

  for (auto& [_, graphNode] : graphNodes) {
    for (auto& inputPort : *graphNode->audioInputPorts()) {
      for (auto connectionId : *inputPort->connections()) {
        auto& connection = getGraphConnection(graphConnections, connectionId);
        result[connection.sourceNodeId()][connection.sourcePortId()]++;
      }
    }
  }

  return result;
}

AudioOutputConnectionMap buildAudioOutputConnectionMap(
    ModelUnorderedMap<int64_t, std::shared_ptr<anthem::Node>>& graphNodes,
    GraphConnectionMap& graphConnections) {
  AudioOutputConnectionMap result;

  for (auto& [_, graphNode] : graphNodes) {
    for (auto& inputPort : *graphNode->audioInputPorts()) {
      for (auto connectionId : *inputPort->connections()) {
        auto& connection = getGraphConnection(graphConnections, connectionId);
        result[connection.sourceNodeId()][connection.sourcePortId()].push_back(&connection);
      }
    }
  }

  return result;
}

const std::vector<anthem::NodeConnection*>& getAudioOutputConnections(
    const AudioOutputConnectionMap& connectionMap, RuntimeNode::Id nodeId, int64_t portId) {
  static const std::vector<anthem::NodeConnection*> emptyConnections;

  auto nodeIter = connectionMap.find(nodeId);
  if (nodeIter == connectionMap.end()) {
    return emptyConnections;
  }

  auto portIter = nodeIter->second.find(portId);
  if (portIter == nodeIter->second.end()) {
    return emptyConnections;
  }

  return portIter->second;
}

size_t getAudioOutputConnectionCount(const AudioOutputConnectionCountMap& connectionCounts,
    RuntimeNode::Id sourceNodeId,
    int64_t sourcePortId) {
  auto nodeIter = connectionCounts.find(sourceNodeId);
  if (nodeIter == connectionCounts.end()) {
    return 0;
  }

  auto portIter = nodeIter->second.find(sourcePortId);
  if (portIter == nodeIter->second.end()) {
    return 0;
  }

  return portIter->second;
}

int getRequiredAudioOutputBufferChannelCount(RuntimeGraph& runtimeGraph,
    ModelUnorderedMap<int64_t, std::shared_ptr<anthem::Node>>& graphNodes,
    const AudioOutputConnectionMap& audioOutputConnections,
    AudioOutputWidthMap& outputWidthMemo,
    RuntimeNode::Id nodeId,
    int64_t outputPortId);

int getRequiredAudioInputBufferChannelCount(RuntimeGraph& runtimeGraph,
    ModelUnorderedMap<int64_t, std::shared_ptr<anthem::Node>>& graphNodes,
    const AudioOutputConnectionMap& audioOutputConnections,
    AudioOutputWidthMap& outputWidthMemo,
    RuntimeNode::Id nodeId,
    int64_t inputPortId) {
  auto& graphNode = *graphNodes.at(nodeId);
  auto& inputPort = getAudioInputPortById(graphNode, inputPortId);
  auto result = getAudioPortChannelCount(runtimeGraph, inputPort);

  if (!hasSingleAudioInputAndOutput(graphNode) ||
      graphNode.audioInputPorts()->at(0)->id() != inputPortId) {
    return result;
  }

  auto& outputPort = *graphNode.audioOutputPorts()->at(0);

  result = std::max(result, getNodeAudioProcessChannelCount(runtimeGraph, graphNode));
  result = std::max(result,
      getRequiredAudioOutputBufferChannelCount(runtimeGraph,
          graphNodes,
          audioOutputConnections,
          outputWidthMemo,
          nodeId,
          outputPort.id()));

  return result;
}

int getRequiredAudioOutputBufferChannelCount(RuntimeGraph& runtimeGraph,
    ModelUnorderedMap<int64_t, std::shared_ptr<anthem::Node>>& graphNodes,
    const AudioOutputConnectionMap& audioOutputConnections,
    AudioOutputWidthMap& outputWidthMemo,
    RuntimeNode::Id nodeId,
    int64_t outputPortId) {
  auto nodeMemoIter = outputWidthMemo.find(nodeId);
  if (nodeMemoIter != outputWidthMemo.end()) {
    auto portMemoIter = nodeMemoIter->second.find(outputPortId);
    if (portMemoIter != nodeMemoIter->second.end()) {
      return portMemoIter->second;
    }
  }

  auto& graphNode = *graphNodes.at(nodeId);
  auto& outputPort = getAudioOutputPortById(graphNode, outputPortId);
  auto result = getAudioPortChannelCount(runtimeGraph, outputPort);

  if (hasSingleAudioInputAndOutput(graphNode) &&
      graphNode.audioOutputPorts()->at(0)->id() == outputPortId) {
    result = std::max(result, getNodeAudioProcessChannelCount(runtimeGraph, graphNode));
  }

  const auto& outputConnections =
      getAudioOutputConnections(audioOutputConnections, nodeId, outputPortId);

  if (outputConnections.size() == 1) {
    auto& connection = *outputConnections[0];
    auto& destinationNode = *graphNodes.at(connection.destinationNodeId());
    auto& destinationInputPort =
        getAudioInputPortById(destinationNode, connection.destinationPortId());

    if (destinationInputPort.connections()->size() == 1) {
      result = std::max(result,
          getRequiredAudioInputBufferChannelCount(runtimeGraph,
              graphNodes,
              audioOutputConnections,
              outputWidthMemo,
              connection.destinationNodeId(),
              connection.destinationPortId()));
    }
  }

  outputWidthMemo[nodeId][outputPortId] = result;
  return result;
}

void validateAudioConnectionChannelCounts(RuntimeGraph& runtimeGraph,
    ModelUnorderedMap<int64_t, std::shared_ptr<anthem::Node>>& graphNodes,
    GraphConnectionMap& graphConnections) {
  for (auto& [_, graphNode] : graphNodes) {
    for (auto& inputPort : *graphNode->audioInputPorts()) {
      const auto inputChannelCount = getAudioPortChannelCount(runtimeGraph, *inputPort);

      for (auto connectionId : *inputPort->connections()) {
        auto& connection = getGraphConnection(graphConnections, connectionId);
        auto& sourceNode = *graphNodes.at(connection.sourceNodeId());
        auto& sourceOutputPort = getAudioOutputPortById(sourceNode, connection.sourcePortId());
        const auto sourceChannelCount = getAudioPortChannelCount(runtimeGraph, sourceOutputPort);

        if (sourceChannelCount != inputChannelCount) {
          throw std::runtime_error("Processing graph audio connection has mismatched channel "
                                   "counts: " +
                                   std::to_string(connection.id()));
        }
      }
    }
  }
}

void bindAudioPortBuffersForNode(RuntimeGraph& runtimeGraph,
    ModelUnorderedMap<int64_t, std::shared_ptr<anthem::Node>>& graphNodes,
    GraphConnectionMap& graphConnections,
    BufferBindingsByNodeId& bufferBindingsByNodeId,
    const AudioOutputConnectionCountMap& audioOutputConnectionCounts,
    const AudioOutputConnectionMap& audioOutputConnections,
    AudioOutputWidthMap& outputWidthMemo,
    std::unordered_set<RuntimeNode::Id>& audioBoundNodeIds,
    RuntimeNode::Id nodeId);

AudioBufferSlice getAudioOutputBufferSlice(RuntimeGraph& runtimeGraph,
    ModelUnorderedMap<int64_t, std::shared_ptr<anthem::Node>>& graphNodes,
    GraphConnectionMap& graphConnections,
    BufferBindingsByNodeId& bufferBindingsByNodeId,
    const AudioOutputConnectionCountMap& audioOutputConnectionCounts,
    const AudioOutputConnectionMap& audioOutputConnections,
    AudioOutputWidthMap& outputWidthMemo,
    std::unordered_set<RuntimeNode::Id>& audioBoundNodeIds,
    anthem::NodeConnection& connection) {
  // Recursion point: before an input can bind to an upstream audio output, the
  // source node's audio ports must already be bound.
  bindAudioPortBuffersForNode(runtimeGraph,
      graphNodes,
      graphConnections,
      bufferBindingsByNodeId,
      audioOutputConnectionCounts,
      audioOutputConnections,
      outputWidthMemo,
      audioBoundNodeIds,
      connection.sourceNodeId());

  return getAudioBufferSlice(bufferBindingsByNodeId.at(connection.sourceNodeId()),
      NodeProcessContext::BufferDirection::output,
      connection.sourcePortId());
}

void bindAudioInputPort(RuntimeGraph& runtimeGraph,
    ModelUnorderedMap<int64_t, std::shared_ptr<anthem::Node>>& graphNodes,
    GraphConnectionMap& graphConnections,
    BufferBindingsByNodeId& bufferBindingsByNodeId,
    const AudioOutputConnectionCountMap& audioOutputConnectionCounts,
    const AudioOutputConnectionMap& audioOutputConnections,
    AudioOutputWidthMap& outputWidthMemo,
    std::unordered_set<RuntimeNode::Id>& audioBoundNodeIds,
    RuntimeNode::Id inputPortNodeId,
    NodePort& inputPort,
    NodeProcessContext::BufferBindings& bindings) {
  jassert(runtimeGraph.graphProcessContext != nullptr);

  auto connectionCount = inputPort.connections()->size();

  // Rule: disconnected audio inputs get their own writable buffer, which is
  // cleared before the node runs.
  if (connectionCount == 0) {
    auto bufferIndex = runtimeGraph.graphProcessContext->allocateAudioBuffer(
        getRequiredAudioInputBufferChannelCount(runtimeGraph,
            graphNodes,
            audioOutputConnections,
            outputWidthMemo,
            inputPortNodeId,
            inputPort.id()));
    AudioBufferSlice slice{
        .bufferIndex = bufferIndex,
        .channelCount = getAudioPortChannelCount(runtimeGraph, inputPort),
    };
    bindings.inputAudioBuffers.emplace(inputPort.id(), slice);
    bindings.rt_audioBuffersToClear.push_back(slice);
    return;
  }

  if (connectionCount == 1) {
    auto& connection = getGraphConnection(graphConnections, inputPort.connections()->at(0));
    auto& destinationRuntimeNode = runtimeGraph.nodes.at(inputPortNodeId);
    auto sourceSlice = getAudioOutputBufferSlice(runtimeGraph,
        graphNodes,
        graphConnections,
        bufferBindingsByNodeId,
        audioOutputConnectionCounts,
        audioOutputConnections,
        outputWidthMemo,
        audioBoundNodeIds,
        connection);

    const auto sourceConnectionCount = getAudioOutputConnectionCount(
        audioOutputConnectionCounts, connection.sourceNodeId(), connection.sourcePortId());

    // Rule: a single-source audio input with no source fan-out can read the
    // source output buffer directly.
    if (sourceConnectionCount <= 1) {
      bindings.inputAudioBuffers.emplace(inputPort.id(),
          AudioBufferSlice{
              .bufferIndex = sourceSlice.bufferIndex,
              .channelCount = getAudioPortChannelCount(runtimeGraph, inputPort),
          });
      return;
    }

    // Rule: if the source output fans out, copy it into this node's private
    // input buffer so this node can process in place without mutating sibling
    // branches.
    auto destinationBufferIndex = runtimeGraph.graphProcessContext->allocateAudioBuffer(
        getRequiredAudioInputBufferChannelCount(runtimeGraph,
            graphNodes,
            audioOutputConnections,
            outputWidthMemo,
            inputPortNodeId,
            inputPort.id()));
    AudioBufferSlice destinationSlice{
        .bufferIndex = destinationBufferIndex,
        .channelCount = getAudioPortChannelCount(runtimeGraph, inputPort),
    };
    bindings.inputAudioBuffers.emplace(inputPort.id(), destinationSlice);

    RuntimeConnectionTransferAction action;
    action.dataType = RuntimeConnectionDataType::audio;
    action.destinationBufferIndex = destinationBufferIndex;
    action.sourceBufferIndices.push_back(sourceSlice.bufferIndex);
    action.destinationAudioSlice = destinationSlice;
    action.sourceAudioSlices.push_back(sourceSlice);
    destinationRuntimeNode.connectionTransferActions.push_back(std::move(action));
    return;
  }

  // Rule: fan-in audio inputs get a private input buffer and a transfer action
  // that sums all connected source output buffers into it.
  auto destinationBufferIndex = runtimeGraph.graphProcessContext->allocateAudioBuffer(
      getRequiredAudioInputBufferChannelCount(runtimeGraph,
          graphNodes,
          audioOutputConnections,
          outputWidthMemo,
          inputPortNodeId,
          inputPort.id()));
  AudioBufferSlice destinationSlice{
      .bufferIndex = destinationBufferIndex,
      .channelCount = getAudioPortChannelCount(runtimeGraph, inputPort),
  };
  bindings.inputAudioBuffers.emplace(inputPort.id(), destinationSlice);

  RuntimeConnectionTransferAction action;
  action.dataType = RuntimeConnectionDataType::audio;
  action.destinationBufferIndex = destinationBufferIndex;
  action.sourceBufferIndices.reserve(connectionCount);
  action.destinationAudioSlice = destinationSlice;
  action.sourceAudioSlices.reserve(connectionCount);
  auto& destinationRuntimeNode = runtimeGraph.nodes.at(inputPortNodeId);

  for (auto connectionId : *inputPort.connections()) {
    auto& connection = getGraphConnection(graphConnections, connectionId);

    auto sourceSlice = getAudioOutputBufferSlice(runtimeGraph,
        graphNodes,
        graphConnections,
        bufferBindingsByNodeId,
        audioOutputConnectionCounts,
        audioOutputConnections,
        outputWidthMemo,
        audioBoundNodeIds,
        connection);
    action.sourceBufferIndices.push_back(sourceSlice.bufferIndex);
    action.sourceAudioSlices.push_back(sourceSlice);
  }

  destinationRuntimeNode.connectionTransferActions.push_back(std::move(action));
}

void bindAudioOutputPortBuffers(RuntimeGraph& runtimeGraph,
    anthem::Node& graphNode,
    ModelUnorderedMap<int64_t, std::shared_ptr<anthem::Node>>& graphNodes,
    const AudioOutputConnectionMap& audioOutputConnections,
    AudioOutputWidthMap& outputWidthMemo,
    NodeProcessContext::BufferBindings& bindings) {
  jassert(runtimeGraph.graphProcessContext != nullptr);

  auto& audioInputPorts = *graphNode.audioInputPorts();
  auto& audioOutputPorts = *graphNode.audioOutputPorts();

  // Rule: single-audio-input/single-audio-output nodes process in place, so the
  // output port aliases the input port's buffer.
  if (audioInputPorts.size() == 1 && audioOutputPorts.size() == 1) {
    const auto inputBufferIter = bindings.inputAudioBuffers.find(audioInputPorts[0]->id());

    if (inputBufferIter != bindings.inputAudioBuffers.end()) {
      bindings.outputAudioBuffers.emplace(audioOutputPorts[0]->id(),
          AudioBufferSlice{
              .bufferIndex = inputBufferIter->second.bufferIndex,
              .channelCount = getAudioPortChannelCount(runtimeGraph, *audioOutputPorts[0]),
          });
      return;
    }
  }

  // Rule: nodes that cannot use the single-input/single-output in-place shape
  // get dedicated audio output buffers.
  for (auto& port : audioOutputPorts) {
    if (bindings.outputAudioBuffers.find(port->id()) != bindings.outputAudioBuffers.end()) {
      continue;
    }

    auto bufferIndex = runtimeGraph.graphProcessContext->allocateAudioBuffer(
        getRequiredAudioOutputBufferChannelCount(runtimeGraph,
            graphNodes,
            audioOutputConnections,
            outputWidthMemo,
            graphNode.id(),
            port->id()));
    bindings.outputAudioBuffers.emplace(port->id(),
        AudioBufferSlice{
            .bufferIndex = bufferIndex,
            .channelCount = getAudioPortChannelCount(runtimeGraph, *port),
        });
  }
}

void bindAudioProcessBufferForNode(RuntimeGraph& runtimeGraph,
    anthem::Node& graphNode,
    NodeProcessContext::BufferBindings& bindings) {
  const auto processChannelCount = getNodeAudioProcessChannelCount(runtimeGraph, graphNode);
  const auto audioInputPortCount = graphNode.audioInputPorts()->size();
  const auto audioOutputPortCount = graphNode.audioOutputPorts()->size();

  if (processChannelCount == 0 || bindings.audioProcessBuffer.has_value()) {
    return;
  }

  if ((audioInputPortCount + audioOutputPortCount) > 2) {
    return;
  }

  if (audioOutputPortCount == 1) {
    const auto outputPortId = graphNode.audioOutputPorts()->at(0)->id();
    const auto outputSlice = bindings.outputAudioBuffers.at(outputPortId);
    bindings.audioProcessBuffer = AudioBufferSlice{
        .bufferIndex = outputSlice.bufferIndex,
        .channelCount = processChannelCount,
    };
    return;
  }

  if (audioInputPortCount == 1) {
    const auto inputPortId = graphNode.audioInputPorts()->at(0)->id();
    const auto inputSlice = bindings.inputAudioBuffers.at(inputPortId);
    bindings.audioProcessBuffer = AudioBufferSlice{
        .bufferIndex = inputSlice.bufferIndex,
        .channelCount = processChannelCount,
    };
  }
}

void bindAudioPortBuffersForNode(RuntimeGraph& runtimeGraph,
    ModelUnorderedMap<int64_t, std::shared_ptr<anthem::Node>>& graphNodes,
    GraphConnectionMap& graphConnections,
    BufferBindingsByNodeId& bufferBindingsByNodeId,
    const AudioOutputConnectionCountMap& audioOutputConnectionCounts,
    const AudioOutputConnectionMap& audioOutputConnections,
    AudioOutputWidthMap& outputWidthMemo,
    std::unordered_set<RuntimeNode::Id>& audioBoundNodeIds,
    RuntimeNode::Id nodeId) {
  if (audioBoundNodeIds.find(nodeId) != audioBoundNodeIds.end()) {
    return;
  }

  auto graphNodeIter = graphNodes.find(nodeId);
  if (graphNodeIter == graphNodes.end() || graphNodeIter->second == nullptr) {
    throw std::runtime_error(
        "Processing graph cannot bind audio buffers for missing node: " + std::to_string(nodeId));
  }

  auto bindingsIter = bufferBindingsByNodeId.find(nodeId);
  if (bindingsIter == bufferBindingsByNodeId.end()) {
    throw std::runtime_error(
        "Processing graph buffer bindings missing for node: " + std::to_string(nodeId));
  }

  auto& graphNode = *graphNodeIter->second;
  auto& bindings = bindingsIter->second;

  // Audio inputs are bound before audio outputs so a one-input/one-output node
  // can alias its output to the selected input process buffer.
  for (auto& inputPort : *graphNode.audioInputPorts()) {
    bindAudioInputPort(runtimeGraph,
        graphNodes,
        graphConnections,
        bufferBindingsByNodeId,
        audioOutputConnectionCounts,
        audioOutputConnections,
        outputWidthMemo,
        audioBoundNodeIds,
        graphNode.id(),
        *inputPort,
        bindings);
  }

  bindAudioOutputPortBuffers(
      runtimeGraph, graphNode, graphNodes, audioOutputConnections, outputWidthMemo, bindings);
  bindAudioProcessBufferForNode(runtimeGraph, graphNode, bindings);

  audioBoundNodeIds.insert(nodeId);
}

void bindControlInputPort(RuntimeGraph& runtimeGraph,
    GraphConnectionMap& graphConnections,
    BufferBindingsByNodeId& bufferBindingsByNodeId,
    RuntimeNode::Id inputPortNodeId,
    NodePort& inputPort,
    NodeProcessContext::BufferBindings& bindings) {
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

  for (auto connectionId : *inputPort.connections()) {
    auto& connection = getGraphConnection(graphConnections, connectionId);
    addConnectionSourceToTransferAction(
        action, connection, NodePortDataType::control, bufferBindingsByNodeId);
  }

  runtimeGraph.nodes.at(inputPortNodeId).connectionTransferActions.push_back(std::move(action));
}

void bindEventInputPort(RuntimeGraph& runtimeGraph,
    GraphConnectionMap& graphConnections,
    BufferBindingsByNodeId& bufferBindingsByNodeId,
    RuntimeNode::Id inputPortNodeId,
    NodePort& inputPort,
    NodeProcessContext::BufferBindings& bindings) {
  jassert(runtimeGraph.graphProcessContext != nullptr);

  auto connectionCount = inputPort.connections()->size();

  if (connectionCount == 0) {
    bindings.inputEventBuffers.emplace(
        inputPort.id(), runtimeGraph.graphProcessContext->getSharedEmptyEventBufferIndex());
    return;
  }

  if (connectionCount == 1) {
    auto& connection = getGraphConnection(graphConnections, inputPort.connections()->at(0));

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
  // graph publishing can preserve processing state across publishes.
  auto destinationBufferIndex =
      runtimeGraph.graphProcessContext->allocateEventBuffer(DEFAULT_EVENT_BUFFER_SIZE);
  bindings.inputEventBuffers.emplace(inputPort.id(), destinationBufferIndex);
  bindings.rt_eventBuffersToClear.push_back(destinationBufferIndex);

  RuntimeConnectionTransferAction action;
  action.dataType = RuntimeConnectionDataType::event;
  action.destinationBufferIndex = destinationBufferIndex;
  action.sourceBufferIndices.reserve(connectionCount);

  for (auto connectionId : *inputPort.connections()) {
    auto& connection = getGraphConnection(graphConnections, connectionId);
    addConnectionSourceToTransferAction(
        action, connection, NodePortDataType::event, bufferBindingsByNodeId);
  }

  runtimeGraph.nodes.at(inputPortNodeId).connectionTransferActions.push_back(std::move(action));
}

void bindInputPortBuffers(RuntimeGraph& runtimeGraph,
    GraphConnectionMap& graphConnections,
    BufferBindingsByNodeId& bufferBindingsByNodeId,
    anthem::Node& graphNode,
    NodeProcessContext::BufferBindings& bindings) {
  for (auto& inputPort : *graphNode.controlInputPorts()) {
    bindControlInputPort(runtimeGraph,
        graphConnections,
        bufferBindingsByNodeId,
        graphNode.id(),
        *inputPort,
        bindings);
  }

  for (auto& inputPort : *graphNode.eventInputPorts()) {
    bindEventInputPort(runtimeGraph,
        graphConnections,
        bufferBindingsByNodeId,
        graphNode.id(),
        *inputPort,
        bindings);
  }
}

BufferBindingsByNodeId createBufferBindings(RuntimeGraph& runtimeGraph,
    ModelUnorderedMap<int64_t, std::shared_ptr<anthem::Node>>& graphNodes,
    GraphConnectionMap& graphConnections) {
  BufferBindingsByNodeId bufferBindingsByNodeId;
  bufferBindingsByNodeId.reserve(runtimeGraph.nodes.size());

  for (auto& [nodeId, graphNode] : graphNodes) {
    auto [bindingsIter, _] =
        bufferBindingsByNodeId.emplace(nodeId, NodeProcessContext::BufferBindings{});
    auto& bindings = bindingsIter->second;

    reserveBufferBindingStorage(bindings, *graphNode);
    bindNonAudioOutputPortBuffers(runtimeGraph, *graphNode, bindings);
  }

  auto audioOutputConnectionCounts =
      buildAudioOutputConnectionCountMap(graphNodes, graphConnections);
  auto audioOutputConnections = buildAudioOutputConnectionMap(graphNodes, graphConnections);
  AudioOutputWidthMap outputWidthMemo;
  validateAudioConnectionChannelCounts(runtimeGraph, graphNodes, graphConnections);

  std::unordered_set<RuntimeNode::Id> audioBoundNodeIds;
  audioBoundNodeIds.reserve(graphNodes.size());

  for (auto& [nodeId, _] : graphNodes) {
    bindAudioPortBuffersForNode(runtimeGraph,
        graphNodes,
        graphConnections,
        bufferBindingsByNodeId,
        audioOutputConnectionCounts,
        audioOutputConnections,
        outputWidthMemo,
        audioBoundNodeIds,
        nodeId);
  }

  for (auto& [nodeId, graphNode] : graphNodes) {
    auto bindingsIter = bufferBindingsByNodeId.find(nodeId);
    if (bindingsIter == bufferBindingsByNodeId.end()) {
      throw std::runtime_error(
          "Processing graph buffer bindings missing for node: " + std::to_string(nodeId));
    }

    bindInputPortBuffers(
        runtimeGraph, graphConnections, bufferBindingsByNodeId, *graphNode, bindingsIter->second);
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
    const GraphBufferLayout& bufferLayout) {
  auto& graphNodes = *processingGraph.nodes();
  auto& graphConnections = *processingGraph.connections();

  auto runtimeGraphStorage = std::make_unique<RuntimeGraph>(graphNodes.size());
  auto& runtimeGraph = *runtimeGraphStorage;

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

  // Build and validate graph topology before allocating buffers. Audio buffer
  // binding can recurse upstream to find in-place process buffers, so cycles
  // must be rejected before that phase starts.
  buildRuntimeTopology(runtimeGraph, graphNodes, graphConnections);

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

  reserveRuntimeGraphStorage(runtimeGraph, graphNodes);
  auto bufferBindingsByNodeId = createBufferBindings(runtimeGraph, graphNodes, graphConnections);
  createNodeProcessContexts(runtimeGraph, bufferBindingsByNodeId);

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
