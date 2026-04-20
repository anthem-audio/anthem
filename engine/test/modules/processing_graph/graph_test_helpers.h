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
#include "modules/processing_graph/model/node.h"
#include "modules/processing_graph/model/node_connection.h"
#include "modules/processing_graph/model/node_port.h"
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
    std::optional<std::shared_ptr<ParameterConfigModel>> parameterConfig = std::nullopt) {
  return std::make_shared<NodePort>(NodePortModelImpl{
      .id = id,
      .nodeId = nodeId,
      .config = std::make_shared<NodePortConfigModel>(NodePortConfigModelImpl{
          .dataType = dataType,
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

} // namespace graph_test_helpers

} // namespace anthem
