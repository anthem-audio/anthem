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

#include "processing_graph_command_handler.h"

#include "modules/processors/simple_volume_lfo_node.h"
#include "modules/processors/simple_midi_generator_node.h"
#include "modules/processors/tone_generator_node.h"
#include "modules/processors/gain_node.h"

std::optional<Response>
handleProcessingGraphCommand(Request& request, Anthem* anthem) {
  if (rfl::holds_alternative<GetProcessorsRequest>(request.variant())) {
    auto& getProcessorsRequest = rfl::get<GetProcessorsRequest>(request.variant());

    std::shared_ptr<std::vector<std::shared_ptr<ProcessorDescription>>> processorList;

    // TODO: This should probably be stored somewhere for real, so we don't
    // have to manage it here
    std::vector<std::tuple<std::string, ProcessorCategory>> processors = {
      {"SimpleVolumeLfo", ProcessorCategory::effect},
      {"ToneGenerator", ProcessorCategory::generator},
      // {"3", "Processor3", ProcessorCategory::ProcessorCategory_Utility}
    };

    for (const auto& processor : processors) {
      auto id = std::get<0>(processor);
      auto category = std::get<1>(processor);

      auto processorDescription = std::make_shared<ProcessorDescription>(
        ProcessorDescription{
          .processorId = id,
          .category = category
        }
      );

      processorList->push_back(std::move(processorDescription));
    }

    auto response = GetProcessorsResponse {
      .processors = std::move(processorList),
      .responseBase = ResponseBase {
        .id = getProcessorsRequest.requestBase.get().id
      }
    };

    return std::optional(std::move(response));
  }

  else if (rfl::holds_alternative<GetProcessorPortsRequest>(request.variant())) {
    auto& getProcessorPortsRequest = rfl::get<GetProcessorPortsRequest>(request.variant());

    int64_t nodeId = getProcessorPortsRequest.nodeId;

    if (!anthem->hasNode(nodeId)) {
      std::string error = "Node not found";
      auto errorResponse = GetProcessorPortsResponse {
        .success = false,
        .error = error,
        .responseBase = ResponseBase {
          .id = getProcessorPortsRequest.requestBase.get().id
        }
      };

      return std::optional(errorResponse);
    }

    auto node = anthem->getNode(nodeId);

    std::shared_ptr<std::vector<std::shared_ptr<ProcessorPortDescription>>> audioInputPorts;

    for (const auto& port : node->audioInputs) {
      auto id = port->config->id;

      auto portDescription = std::make_shared<ProcessorPortDescription>(
        ProcessorPortDescription {
          .id = static_cast<int64_t>(id)
        }
      );

      audioInputPorts->push_back(std::move(portDescription));
    }

    std::shared_ptr<std::vector<std::shared_ptr<ProcessorPortDescription>>> controlInputPorts;

    for (const auto& port : node->controlInputs) {
      auto id = port->config->id;

      auto portDescription = std::make_shared<ProcessorPortDescription>(
          ProcessorPortDescription {
          .id = static_cast<int64_t>(id)
        }
      );

      controlInputPorts->push_back(std::move(portDescription));
    }

    std::shared_ptr<std::vector<std::shared_ptr<ProcessorPortDescription>>> noteEventInputPorts;

    for (const auto& port : node->noteEventInputs) {
      auto id = port->config->id;

      auto portDescription = std::make_shared<ProcessorPortDescription>(
          ProcessorPortDescription {
          .id = static_cast<int64_t>(id)
        }
      );

      noteEventInputPorts->push_back(std::move(portDescription));
    }

    std::shared_ptr<std::vector<std::shared_ptr<ProcessorPortDescription>>> audioOutputPorts;

    for (const auto& port : node->audioOutputs) {
      auto id = port->config->id;

      auto portDescription = std::make_shared<ProcessorPortDescription>(
          ProcessorPortDescription {
          .id = static_cast<int64_t>(id)
        }
      );

      audioOutputPorts->push_back(std::move(portDescription));
    }

    std::shared_ptr<std::vector<std::shared_ptr<ProcessorPortDescription>>> controlOutputPorts;

    for (const auto& port : node->controlOutputs) {
      auto id = port->config->id;

      auto portDescription = std::make_shared<ProcessorPortDescription>(
          ProcessorPortDescription {
          .id = static_cast<int64_t>(id)
        }
      );

      controlOutputPorts->push_back(std::move(portDescription));
    }

    std::shared_ptr<std::vector<std::shared_ptr<ProcessorPortDescription>>> noteEventOutputPorts;

    for (const auto& port : node->noteEventOutputs) {
      auto id = port->config->id;
    
      auto portDescription = std::make_shared<ProcessorPortDescription>(
          ProcessorPortDescription {
          .id = static_cast<int64_t>(id)
        }
      );

      noteEventOutputPorts->push_back(std::move(portDescription));
    }

    std::shared_ptr<std::vector<std::shared_ptr<ProcessorParameterDescription>>> parameters;

    for (int i = 0; i < node->controlInputs.size(); i++) {
      auto& port = node->controlInputs[i];
      auto parameter = node->processor->config.getParameterByIndex(i);

      auto id = port->config->id;
      auto defaultValue = parameter->defaultValue;
      auto min = parameter->minValue;
      auto max = parameter->maxValue;

      auto parameterDescription = std::make_shared<ProcessorParameterDescription>(
        ProcessorParameterDescription {
          .id = static_cast<int64_t>(id),
          .defaultValue = defaultValue,
          .minValue = min,
          .maxValue = max
        }
      );

      parameters->push_back(std::move(parameterDescription));
    }

    auto response = GetProcessorPortsResponse {
      .success = true,
      .error = std::nullopt,
      .inputAudioPorts = std::move(audioInputPorts),
      .inputControlPorts = std::move(controlInputPorts),
      .inputNoteEventPorts = std::move(noteEventInputPorts),
      .outputAudioPorts = std::move(audioOutputPorts),
      .outputControlPorts = std::move(controlOutputPorts),
      .outputNoteEventPorts = std::move(noteEventOutputPorts),
      .parameters = std::move(parameters),
      .responseBase = ResponseBase {
        .id = getProcessorPortsRequest.requestBase.get().id
      }
    };

    return std::optional(std::move(response));
  }

  else if (rfl::holds_alternative<GetMasterOutputNodeIdRequest>(request.variant())) {
    auto& getMasterOutputNodeIdRequest = rfl::get<GetMasterOutputNodeIdRequest>(request.variant());

    return std::optional(GetMasterOutputNodeIdResponse {
      .nodeId = static_cast<int64_t>(anthem->getMasterOutputNodeId()),
      .responseBase = ResponseBase {
        .id = getMasterOutputNodeIdRequest.requestBase.get().id
      }
    });
  }

  else if (rfl::holds_alternative<AddProcessorRequest>(request.variant())) {
    bool success = false;
    std::string error;

    auto& addProcessorRequest = rfl::get<AddProcessorRequest>(request.variant());
    auto processorId = addProcessorRequest.processorId;

    std::unique_ptr<AnthemProcessor> processor;

    if (processorId == "SimpleVolumeLfo") {
      processor = std::make_unique<SimpleVolumeLfoNode>();
      success = true;
    } else if (processorId == "ToneGenerator") {
      processor = std::make_unique<ToneGeneratorNode>();
      success = true;
    } else if (processorId == "SimpleMidiGenerator") {
      processor = std::make_unique<SimpleMidiGeneratorNode>();
      success = true;
    } else if (processorId == "Gain") {
      processor = std::make_unique<GainNode>();
      success = true;
    } else {
      success = false;
      error = "Unknown processor id: " + processorId;
    }

    // Error response
    if (!success) {
      error = "AddProcessor command failed";

      return std::optional(
        AddProcessorResponse {
          .success = false,
          .processorId = 0,
          .error = std::optional(error),
          .responseBase = ResponseBase {
            .id = addProcessorRequest.requestBase.get().id
          }
        }
      );
    }

    uint64_t nodeId;
    if (success) {
      nodeId = anthem->addNode(std::move(processor));
    } else {
      return std::nullopt;
    }

    return std::optional(AddProcessorResponse {
      .success = true,
      .processorId = static_cast<int64_t>(nodeId),
      .error = std::nullopt,
      .responseBase = ResponseBase {
        .id = addProcessorRequest.requestBase.get().id
      }
    });
  } else if (rfl::holds_alternative<RemoveProcessorRequest>(request.variant())) {
    auto& removeProcessorRequest = rfl::get<RemoveProcessorRequest>(request.variant());
    auto nodeId = removeProcessorRequest.nodeId;

    bool success = anthem->removeNode(nodeId);

    return std::optional(RemoveProcessorResponse {
      .success = success,
      .error = success ? std::nullopt : std::optional("Node not found"),
      .responseBase = ResponseBase {
        .id = removeProcessorRequest.requestBase.get().id
      }
    });
  }

  else if (rfl::holds_alternative<ConnectProcessorsRequest>(request.variant())) {
    auto& connectProcessorsRequest = rfl::get<ConnectProcessorsRequest>(request.variant());

    auto sourceId = connectProcessorsRequest.sourceId;
    auto destinationId = connectProcessorsRequest.destinationId;
    auto& connectionType = connectProcessorsRequest.connectionType;
    auto sourcePortIndex = connectProcessorsRequest.sourcePortIndex;
    auto destinationPortIndex = connectProcessorsRequest.destinationPortIndex;

    // std::cout << "Connecting processors: source_id=" << sourceId << ", destination_id=" << destinationId << ", connection_type=" << connectionType << ", source_channel=" << sourceChannel << ", destination_channel=" << destinationChannel << std::endl;

    bool success = true;
    std::string error = "";

    if (!anthem->hasNode(sourceId)) {
      success = false;
      error = "Source node not found";
    }

    if (!anthem->hasNode(destinationId)) {
      success = false;
      error = "Destination node not found";
    }

    if (success) {
      auto sourceNode = anthem->getNode(sourceId);
      auto destinationNode = anthem->getNode(destinationId);

      if (connectionType == ProcessorConnectionType::audio) {
        if (sourceNode->audioOutputs.size() <= sourcePortIndex) {
          success = false;
          error = "Source port index out of range";
        }

        if (destinationNode->audioInputs.size() <= destinationPortIndex) {
          success = false;
          error = "Destination port index out of range";
        }

        if (success) {
          anthem->getProcessingGraph()->connectNodes(
            sourceNode->audioOutputs[sourcePortIndex],
            destinationNode->audioInputs[destinationPortIndex]
          );
        }
      } else if (connectionType == ProcessorConnectionType::control) {
        if (sourceNode->controlOutputs.size() <= sourcePortIndex) {
          success = false;
          error = "Source port index out of range";
        }

        if (destinationNode->controlInputs.size() <= destinationPortIndex) {
          success = false;
          error = "Destination port index out of range";
        }

        if (success) {
          anthem->getProcessingGraph()->connectNodes(
            sourceNode->controlOutputs[sourcePortIndex],
            destinationNode->controlInputs[destinationPortIndex]
          );
        }
      } else if (connectionType == ProcessorConnectionType::noteEvent) {
        if (sourceNode->noteEventOutputs.size() <= sourcePortIndex) {
          success = false;
          error = "Source port index out of range";
        }

        if (destinationNode->noteEventInputs.size() <= destinationPortIndex) {
          success = false;
          error = "Destination port index out of range";
        }

        if (success) {
          anthem->getProcessingGraph()->connectNodes(
            sourceNode->noteEventOutputs[sourcePortIndex],
            destinationNode->noteEventInputs[destinationPortIndex]
          );
        }
      }
    }

    return std::optional(ConnectProcessorsResponse {
      .success = success,
      .error = error,
      .responseBase = ResponseBase {
        .id = connectProcessorsRequest.requestBase.get().id
      }
    });
  }

  else if (rfl::holds_alternative<DisconnectProcessorsRequest>(request.variant())) {
    auto& disconnectProcessorsRequest = rfl::get<DisconnectProcessorsRequest>(request.variant());

    auto sourceId = disconnectProcessorsRequest.sourceId;
    auto destinationId = disconnectProcessorsRequest.destinationId;
    auto sourcePortIndex = disconnectProcessorsRequest.sourcePortIndex;
    auto destinationPortIndex = disconnectProcessorsRequest.destinationPortIndex;

    bool success = true;
    std::string error = "";

    if (!anthem->hasNode(sourceId)) {
      success = false;
      error = "Source node not found";
    }

    if (!anthem->hasNode(destinationId)) {
      success = false;
      error = "Destination node not found";
    }

    if (success) {
      auto sourceNode = anthem->getNode(sourceId);
      auto destinationNode = anthem->getNode(destinationId);

      if (sourceNode->audioOutputs.size() <= sourcePortIndex) {
        success = false;
        error = "Source port index out of range";
      }

      if (destinationNode->audioInputs.size() <= destinationPortIndex) {
        success = false;
        error = "Destination port index out of range";
      }

      if (success) {
        anthem->getProcessingGraph()->disconnectNodes(
          sourceNode->audioOutputs[sourcePortIndex],
          destinationNode->audioInputs[destinationPortIndex]
        );
      }
    }

    return std::optional(DisconnectProcessorsResponse {
      .success = success,
      .error = error,
      .responseBase = ResponseBase {
        .id = disconnectProcessorsRequest.requestBase.get().id
      }
    });
  }

  else if (rfl::holds_alternative<CompileProcessingGraphRequest>(request.variant())) {
    auto& compileProcessingGraphRequest = rfl::get<CompileProcessingGraphRequest>(request.variant());

    anthem->getProcessingGraph()->compile();

    anthem->getProcessingGraph()->debugPrint();

    return std::optional(CompileProcessingGraphResponse {
      .success = true,
      .error = std::nullopt,
      .responseBase = ResponseBase {
        .id = compileProcessingGraphRequest.requestBase.get().id
      }
    });
  }

  return std::nullopt;
}
