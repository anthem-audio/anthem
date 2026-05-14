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

#pragma once

#include "generated/lib/model/model.h"
#include "modules/core/constants.h"
#include "modules/processing_graph/model/node.h"
#include "modules/processing_graph/model/node_connection.h"
#include "modules/processing_graph/model/node_port.h"
#include "modules/processing_graph/runtime/graph_process_context.h"
#include "modules/processors/gain.h"
#include "modules/processors/master_output.h"

#include <type_traits>
#include <utility>

namespace anthem {

namespace graph_test_helpers {

using NodeProcessorVariant =
    typename std::remove_cvref_t<decltype(std::declval<NodeModelImpl>().processor)>::value_type;

inline std::shared_ptr<ParameterConfigModel> makeParameterConfig(
    int64_t id, double defaultValue, double smoothingDurationSeconds = 0.0) {
  return std::make_shared<ParameterConfigModel>(ParameterConfigModelImpl{
      .id = id,
      .defaultValue = defaultValue,
      .smoothingDurationSeconds = smoothingDurationSeconds,
  });
}

inline std::shared_ptr<NodePort> makePort(int64_t id,
    int64_t nodeId,
    NodePortDataType dataType,
    std::optional<double> parameterValue = std::nullopt,
    std::optional<std::shared_ptr<ParameterConfigModel>> parameterConfig = std::nullopt,
    std::optional<int64_t> channelCount = std::nullopt) {
  return std::make_shared<NodePort>(NodePortModelImpl{
      .id = id,
      .nodeId = nodeId,
      .config = std::make_shared<NodePortConfigModel>(NodePortConfigModelImpl{
          .dataType = dataType,
          .channelCount = channelCount,
          .parameterConfig = parameterConfig,
      }),
      .connections = std::make_shared<ModelVector<int64_t>>(),
      .parameterValue = parameterValue,
  });
}

inline std::shared_ptr<Node> makeGainNode(int64_t nodeId) {
  auto gainProcessor = std::make_shared<GainProcessor>(GainProcessorModelImpl{.nodeId = nodeId});

  return std::make_shared<Node>(NodeModelImpl{
      .id = nodeId,
      .audioInputPorts = std::make_shared<ModelVector<std::shared_ptr<NodePort>>>(),
      .eventInputPorts = std::make_shared<ModelVector<std::shared_ptr<NodePort>>>(),
      .controlInputPorts = std::make_shared<ModelVector<std::shared_ptr<NodePort>>>(),
      .audioOutputPorts = std::make_shared<ModelVector<std::shared_ptr<NodePort>>>(),
      .eventOutputPorts = std::make_shared<ModelVector<std::shared_ptr<NodePort>>>(),
      .controlOutputPorts = std::make_shared<ModelVector<std::shared_ptr<NodePort>>>(),
      .isThirdPartyPlugin = false,
      .processor = NodeProcessorVariant(rfl::make_field<"GainProcessorModel">(gainProcessor)),
  });
}

inline std::shared_ptr<Node> makeNode(int64_t nodeId) {
  return std::make_shared<Node>(NodeModelImpl{
      .id = nodeId,
      .audioInputPorts = std::make_shared<ModelVector<std::shared_ptr<NodePort>>>(),
      .eventInputPorts = std::make_shared<ModelVector<std::shared_ptr<NodePort>>>(),
      .controlInputPorts = std::make_shared<ModelVector<std::shared_ptr<NodePort>>>(),
      .audioOutputPorts = std::make_shared<ModelVector<std::shared_ptr<NodePort>>>(),
      .eventOutputPorts = std::make_shared<ModelVector<std::shared_ptr<NodePort>>>(),
      .controlOutputPorts = std::make_shared<ModelVector<std::shared_ptr<NodePort>>>(),
      .isThirdPartyPlugin = false,
      .processor = std::nullopt,
  });
}

inline std::shared_ptr<Node> makeMasterOutputNode(int64_t nodeId) {
  auto processor =
      std::make_shared<MasterOutputProcessor>(MasterOutputProcessorModelImpl{.nodeId = nodeId});

  return std::make_shared<Node>(NodeModelImpl{
      .id = nodeId,
      .audioInputPorts = std::make_shared<ModelVector<std::shared_ptr<NodePort>>>(),
      .eventInputPorts = std::make_shared<ModelVector<std::shared_ptr<NodePort>>>(),
      .controlInputPorts = std::make_shared<ModelVector<std::shared_ptr<NodePort>>>(),
      .audioOutputPorts = std::make_shared<ModelVector<std::shared_ptr<NodePort>>>(),
      .eventOutputPorts = std::make_shared<ModelVector<std::shared_ptr<NodePort>>>(),
      .controlOutputPorts = std::make_shared<ModelVector<std::shared_ptr<NodePort>>>(),
      .isThirdPartyPlugin = false,
      .processor = NodeProcessorVariant(rfl::make_field<"MasterOutputProcessorModel">(processor)),
  });
}

inline std::shared_ptr<NodeConnection> makeConnection(int64_t id,
    int64_t sourceNodeId,
    int64_t sourcePortId,
    int64_t destinationNodeId,
    int64_t destinationPortId) {
  return std::make_shared<NodeConnection>(NodeConnectionModelImpl{
      .id = id,
      .sourceNodeId = sourceNodeId,
      .sourcePortId = sourcePortId,
      .destinationNodeId = destinationNodeId,
      .destinationPortId = destinationPortId,
  });
}

inline std::shared_ptr<ProcessingGraphModel> makeProcessingGraph() {
  return std::make_shared<ProcessingGraphModel>(ProcessingGraphModelImpl{
      .nodes = std::make_shared<ModelUnorderedMap<int64_t, std::shared_ptr<Node>>>(),
      .connections =
          std::make_shared<ModelUnorderedMap<int64_t, std::shared_ptr<NodeConnection>>>(),
      .masterOutputNodeId = 0,
  });
}

inline NodeProcessContext::BufferBindings createStandaloneBufferBindings(
    std::shared_ptr<Node>& graphNode, GraphProcessContext& graphProcessContext) {
  NodeProcessContext::BufferBindings bindings;

  bindings.inputAudioBuffers.reserve(graphNode->audioInputPorts()->size());
  bindings.outputAudioBuffers.reserve(graphNode->audioOutputPorts()->size());
  bindings.inputControlBuffers.reserve(graphNode->controlInputPorts()->size());
  bindings.outputControlBuffers.reserve(graphNode->controlOutputPorts()->size());
  bindings.inputEventBuffers.reserve(graphNode->eventInputPorts()->size());
  bindings.outputEventBuffers.reserve(graphNode->eventOutputPorts()->size());
  bindings.rt_audioBuffersToClear.reserve(
      graphNode->audioInputPorts()->size() + graphNode->audioOutputPorts()->size());
  bindings.rt_eventBuffersToClear.reserve(
      graphNode->eventInputPorts()->size() + graphNode->eventOutputPorts()->size());
  bindings.rt_parameterInputPortsToWrite.reserve(graphNode->controlInputPorts()->size());

  for (auto& port : *graphNode->audioInputPorts()) {
    auto bufferIndex = graphProcessContext.allocateAudioBuffer();
    bindings.inputAudioBuffers.emplace(port->id(),
        AudioBufferSlice{
            .bufferIndex = bufferIndex,
            .channelCount = graphProcessContext.getAudioBuffer(bufferIndex).getNumChannels(),
        });
  }

  for (auto& port : *graphNode->audioOutputPorts()) {
    auto bufferIndex = graphProcessContext.allocateAudioBuffer();
    bindings.outputAudioBuffers.emplace(port->id(),
        AudioBufferSlice{
            .bufferIndex = bufferIndex,
            .channelCount = graphProcessContext.getAudioBuffer(bufferIndex).getNumChannels(),
        });
  }

  if (!graphNode->audioOutputPorts()->empty()) {
    bindings.audioProcessBuffer =
        bindings.outputAudioBuffers.at(graphNode->audioOutputPorts()->at(0)->id());
  } else if (!graphNode->audioInputPorts()->empty()) {
    bindings.audioProcessBuffer =
        bindings.inputAudioBuffers.at(graphNode->audioInputPorts()->at(0)->id());
  }

  for (auto& port : *graphNode->controlInputPorts()) {
    bindings.inputControlBuffers.emplace(port->id(), graphProcessContext.allocateControlBuffer());

    if (port->config()->parameterConfig().has_value()) {
      bindings.rt_parameterInputPortsToWrite.insert(port->id());
    }
  }

  for (auto& port : *graphNode->controlOutputPorts()) {
    bindings.outputControlBuffers.emplace(port->id(), graphProcessContext.allocateControlBuffer());
  }

  for (auto& port : *graphNode->eventInputPorts()) {
    auto bufferIndex = graphProcessContext.allocateEventBuffer(DEFAULT_EVENT_BUFFER_SIZE);
    bindings.inputEventBuffers.emplace(port->id(), bufferIndex);
    bindings.rt_eventBuffersToClear.push_back(bufferIndex);
  }

  for (auto& port : *graphNode->eventOutputPorts()) {
    auto bufferIndex = graphProcessContext.allocateEventBuffer(DEFAULT_EVENT_BUFFER_SIZE);
    bindings.outputEventBuffers.emplace(port->id(), bufferIndex);
    bindings.rt_eventBuffersToClear.push_back(bufferIndex);
  }

  return bindings;
}

inline NodeProcessContext& createStandaloneNodeProcessContext(
    GraphProcessContext& graphProcessContext, std::shared_ptr<Node>& graphNode) {
  return graphProcessContext.createNodeProcessContext(
      graphNode, createStandaloneBufferBindings(graphNode, graphProcessContext));
}

} // namespace graph_test_helpers

} // namespace anthem
