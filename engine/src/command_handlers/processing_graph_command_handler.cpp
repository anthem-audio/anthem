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

#include "simple_volume_lfo_node.h"
#include "tone_generator_node.h"
#include "gain_node.h"

std::optional<flatbuffers::Offset<Response>>
handleProcessingGraphCommand(const Request *request,
                     flatbuffers::FlatBufferBuilder &builder, Anthem *anthem) {
  auto commandType = request->command_type();

  switch (commandType) {
    case Command_GetProcessors: {
      std::vector<flatbuffers::Offset<ProcessorDescription>> fbProcessorList;

      // TODO: This should probably be stored somewhere for real, so we don't
      // have to manage it here
      std::vector<std::tuple<std::string, ProcessorCategory>> processors = {
        {"SimpleVolumeLfo", ProcessorCategory::ProcessorCategory_Effect},
        {"ToneGenerator", ProcessorCategory::ProcessorCategory_Generator},
        // {"3", "Processor3", ProcessorCategory::ProcessorCategory_Utility}
      };

      for (const auto& processor : processors) {
        auto id = builder.CreateString(std::get<0>(processor));
        auto category = std::get<1>(processor);

        auto processorDescription = CreateProcessorDescription(builder, id, category);
        fbProcessorList.push_back(processorDescription);
      }

      auto processorListOffset = builder.CreateVector(fbProcessorList);

      auto response = CreateGetProcessorsResponse(builder, processorListOffset);
      auto responseOffset = response.Union();

      auto message = CreateResponse(builder, request->id(), ReturnValue_GetProcessorsResponse, responseOffset);

      return std::optional(message);
    }
    case Command_GetProcessorPorts: {
      auto command = request->command_as_GetProcessorPorts();
      uint64_t nodeId = command->id();

      if (!anthem->hasNode(nodeId)) {
        std::string error = "Node not found";
        auto errorResponse = CreateGetProcessorPortsResponse(builder, false, builder.CreateString(error));
        auto errorResponseOffset = errorResponse.Union();
        auto errorResponseMessage = CreateResponse(builder, request->id(), ReturnValue_GetProcessorPortsResponse, errorResponseOffset);

        return std::optional(errorResponseMessage);
      }

      auto node = anthem->getNode(nodeId);

      std::vector<flatbuffers::Offset<ProcessorPortDescription>> fbAudioInputPorts;

      for (const auto& port : node->audioInputs) {
        auto id = port->config->id;

        auto portDescription = CreateProcessorPortDescription(builder, id);
        fbAudioInputPorts.push_back(portDescription);
      }

      std::vector<flatbuffers::Offset<ProcessorPortDescription>> fbControlInputPorts;

      for (const auto& port : node->controlInputs) {
        auto id = port->config->id;

        auto portDescription = CreateProcessorPortDescription(builder, id);
        fbControlInputPorts.push_back(portDescription);
      }

      std::vector<flatbuffers::Offset<ProcessorPortDescription>> fbMidiInputPorts;

      // for (const auto& port : node->midiInputs) {
      //   auto id = port->config->name;

      //   auto portDescription = CreateProcessorPortDescription(builder, id);
      //   fbMidiInputPorts.push_back(portDescription);
      // }

      std::vector<flatbuffers::Offset<ProcessorPortDescription>> fbAudioOutputPorts;

      for (const auto& port : node->audioOutputs) {
        auto id = port->config->id;

        auto portDescription = CreateProcessorPortDescription(builder, id);
        fbAudioOutputPorts.push_back(portDescription);
      }

      std::vector<flatbuffers::Offset<ProcessorPortDescription>> fbControlOutputPorts;

      for (const auto& port : node->controlOutputs) {
        auto id = port->config->id;

        auto portDescription = CreateProcessorPortDescription(builder, id);
        fbControlOutputPorts.push_back(portDescription);
      }

      std::vector<flatbuffers::Offset<ProcessorPortDescription>> fbMidiOutputPorts;

      // for (const auto& port : node->midiOutputs) {
      //   auto id = port->config->id;
      
      //   auto portDescription = CreateProcessorPortDescription(builder, id);
      //   fbMidiOutputPorts.push_back(portDescription);
      // }

      std::vector<flatbuffers::Offset<ProcessorParameterDescription>> fbParameters;

      for (int i = 0; i < node->controlInputs.size(); i++) {
        auto& port = node->controlInputs[i];
        auto parameter = node->processor->config.getParameterByIndex(i);

        auto id = port->config->id;
        auto defaultValue = parameter->defaultValue;
        auto min = parameter->minValue;
        auto max = parameter->maxValue;

        auto parameterDescription = CreateProcessorParameterDescription(builder, id, defaultValue, min, max);
        fbParameters.push_back(parameterDescription);
      }

      auto audioInputPortsOffset = builder.CreateVector(fbAudioInputPorts);
      auto controlInputPortsOffset = builder.CreateVector(fbControlInputPorts);
      auto midiInputPortsOffset = builder.CreateVector(fbMidiInputPorts);

      auto audioOutputPortsOffset = builder.CreateVector(fbAudioOutputPorts);
      auto controlOutputPortsOffset = builder.CreateVector(fbControlOutputPorts);
      auto midiOutputPortsOffset = builder.CreateVector(fbMidiOutputPorts);

      auto parametersOffset = builder.CreateVector(fbParameters);

      auto response = CreateGetProcessorPortsResponse(
        builder,
        true,
        0,
        audioInputPortsOffset,
        controlInputPortsOffset,
        midiInputPortsOffset,
        audioOutputPortsOffset,
        controlOutputPortsOffset,
        midiOutputPortsOffset,
        parametersOffset
      );

      auto responseOffset = response.Union();

      auto message = CreateResponse(builder, request->id(), ReturnValue_GetProcessorPortsResponse, responseOffset);

      return std::optional(message);
    }
    case Command_GetMasterOutputNodeId: {
      auto response = CreateGetMasterOutputNodeIdResponse(builder, anthem->getMasterOutputNodeId());
      auto responseOffset = response.Union();

      auto message = CreateResponse(builder, request->id(), ReturnValue_GetMasterOutputNodeIdResponse, responseOffset);

      return std::optional(message);
    }
    case Command_AddProcessor: {
      bool success = false;
      std::string error;

      auto command = request->command_as_AddProcessor();
      auto processorId = command->id()->str();

      std::shared_ptr<AnthemProcessor> processor;

      if (processorId == "SimpleVolumeLfo") {
        processor = std::make_shared<SimpleVolumeLfoNode>();
        success = true;
      } else if (processorId == "ToneGenerator") {
        processor = std::make_shared<ToneGeneratorNode>();
        success = true;
      } else if (processorId == "Gain") {
        processor = std::make_shared<GainNode>();
        success = true;
      } else {
        success = false;
        error = "Unknown processor id: " + processorId;
      }

      // Error response
      if (!success) {
        error = "AddProcessor command failed";
        auto errorResponse = CreateAddProcessorResponse(builder, false, 0, builder.CreateString(error));
        auto errorResponseOffset = errorResponse.Union();
        auto errorResponseMessage = CreateResponse(builder, request->id(), ReturnValue_AddProcessorResponse, errorResponseOffset);

        return std::optional(errorResponseMessage);
      }

      uint64_t nodeId;
      if (success) {
        nodeId = anthem->addNode(processor);
      }

      auto response = CreateAddProcessorResponse(builder, true, nodeId, 0);
      auto responseOffset = response.Union();

      auto message = CreateResponse(builder, request->id(), ReturnValue_AddProcessorResponse, responseOffset);

      return std::optional(message);
    }
    case Command_RemoveProcessor: {
      auto command = request->command_as_RemoveProcessor();
      uint64_t nodeId = command->id();

      bool success = anthem->removeNode(nodeId);

      // Error response
      if (!success) {
        std::string error = "Node not found";
        auto errorResponse = CreateRemoveProcessorResponse(builder, false, builder.CreateString(error));
        auto errorResponseOffset = errorResponse.Union();
        auto errorResponseMessage = CreateResponse(builder, request->id(), ReturnValue_RemoveProcessorResponse, errorResponseOffset);

        return std::optional(errorResponseMessage);
      }

      auto response = CreateRemoveProcessorResponse(builder, success);
      auto responseOffset = response.Union();

      auto message = CreateResponse(builder, request->id(), ReturnValue_RemoveProcessorResponse, responseOffset);

      return std::optional(message);
    }
    case Command_ConnectProcessors: {
      auto command = request->command_as_ConnectProcessors();

      uint64_t sourceId = command->source_id();
      uint64_t destinationId = command->destination_id();
      ProcessorConnectionType connectionType = command->connection_type();
      uint32_t sourcePortIndex = command->source_port_index();
      uint32_t destinationPortIndex = command->destination_port_index();

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
      }

      auto response = CreateConnectProcessorsResponse(builder, success, builder.CreateString(error));
      auto responseOffset = response.Union();

      auto message = CreateResponse(builder, request->id(), ReturnValue_ConnectProcessorsResponse, responseOffset);

      return std::optional(message);
    }
    case Command_DisconnectProcessors: {
      auto command = request->command_as_DisconnectProcessors();

      uint64_t sourceId = command->source_id();
      uint64_t destinationId = command->destination_id();
      uint32_t sourcePortIndex = command->source_port_index();
      uint32_t destinationPortIndex = command->destination_port_index();

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

      auto response = CreateDisconnectProcessorsResponse(builder, success, builder.CreateString(error));
      auto responseOffset = response.Union();

      auto message = CreateResponse(builder, request->id(), ReturnValue_DisconnectProcessorsResponse, responseOffset);

      return std::optional(message);
    }
    case Command_CompileProcessingGraph: {
      anthem->getProcessingGraph()->compile();

      anthem->getProcessingGraph()->debugPrint();

      auto response = CreateCompileProcessingGraphResponse(builder, true);
      auto responseOffset = response.Union();

      auto message = CreateResponse(builder, request->id(), ReturnValue_CompileProcessingGraphResponse, responseOffset);

      return std::optional(message);
    }
    default: {
      std::cerr << "Unknown command received by handleProcessingGraphCommand()" << std::endl;
      return std::nullopt;
    }
  }
}
