/*
  Copyright (C) 2023 - 2024 Joshua Wade

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

#include "project_command_handler.h"

#include <string>

#include "tone_generator_node.h"
#include "simple_volume_lfo_node.h"

std::optional<flatbuffers::Offset<Response>> handleProjectCommand(
  const Request* request,
  flatbuffers::FlatBufferBuilder& builder,
  Anthem* anthem
) {
  auto commandType = request->command_type();

  switch (commandType) {
    // TODO: Delete arrangement

    case Command_AddArrangement: {
      // TODO: Handle correctly
      std::cout << "Received unhandled AddArrangement command" << std::endl;

      uint64_t editPtrAsUint = 0;

      auto response = CreateAddArrangementResponse(builder, editPtrAsUint);
      auto responseOffset = response.Union();

      auto message = CreateResponse(builder, request->id(), ReturnValue_AddArrangementResponse, responseOffset);

      return std::optional(message);
    }
    case Command_DeleteArrangement: {
      // TODO: Handle correctly
      std::cout << "Received unhandled DeleteArrangement command" << std::endl;

      auto command = request->command_as_DeleteArrangement();
      
      std::cout << "Received unhandled DeleteArrangement command" << std::endl;
      std::cout << "Edit id: " << std::hex << command->edit_id() << std::dec << std::endl;

      return std::nullopt;
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
        processor = std::make_shared<ToneGeneratorNode>(440);
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
    case Command_CompileProcessingGraph: {
      anthem->getProcessingGraph()->compile();

      anthem->getProcessingGraph()->debugPrint();

      auto response = CreateCompileProcessingGraphResponse(builder, true);
      auto responseOffset = response.Union();

      auto message = CreateResponse(builder, request->id(), ReturnValue_CompileProcessingGraphResponse, responseOffset);

      return std::optional(message);
    }
    case Command_LiveNoteOn: {
      auto command = request->command_as_LiveNoteOn();

      // auto edit_ptr = static_cast<uintptr_t>(command->edit_pointer());

      auto midiChannel = command->channel();
      auto midiNoteNumber = command->note();
      auto velocity = command->velocity();

      juce::MidiMessage message = juce::MidiMessage::noteOn(midiChannel, midiNoteNumber, velocity);

      // TODO: Handle correctly
      std::cout << "Received unhandled LiveNoteOn command" << std::endl;

      return std::nullopt;
    }
    case Command_LiveNoteOff: {
      auto command = request->command_as_LiveNoteOff();

      // auto edit_ptr = static_cast<uintptr_t>(command->edit_pointer());

      auto midiChannel = command->channel();
      auto midiNoteNumber = command->note();

      juce::MidiMessage message = juce::MidiMessage::noteOff(midiChannel, midiNoteNumber);

      // TODO: Handle correctly
      std::cout << "Received unhandled LiveNoteOff command" << std::endl;

      return std::nullopt;
    }
    default: {
      std::cerr << "Unknown command received by handleProjectCommand()" << std::endl;
      return std::nullopt;
    }
  }
}
