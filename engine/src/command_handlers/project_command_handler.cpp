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

std::optional<flatbuffers::Offset<Response>> handleProjectCommand(
  const Request* request,
  flatbuffers::FlatBufferBuilder& builder,
  Anthem* /*anthem*/
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
      std::cout << "Edit pointer: " << std::hex << command->edit_pointer() << std::dec << std::endl;

      return std::nullopt;
    }
    case Command_AddProcessor: {
      // TODO: Handle correctly
      std::cout << "Received unhandled AddProcessor command" << std::endl;

      bool success = false;

      // Error response
      if (!success) {
        auto errorResponse = CreateAddProcessorResponse(builder, false);
        auto errorResponseOffset = errorResponse.Union();
        auto errorResponseMessage = CreateResponse(builder, request->id(), ReturnValue_AddProcessorResponse, errorResponseOffset);

        return std::optional(errorResponseMessage);
      } else {
        auto response = CreateAddProcessorResponse(builder, true);
        auto responseOffset = response.Union();

        auto message = CreateResponse(builder, request->id(), ReturnValue_AddProcessorResponse, responseOffset);

        return std::optional(message);
      }
    }
    case Command_GetProcessors: {
      std::vector<flatbuffers::Offset<ProcessorDescription>> fbProcessorList;

      // TODO: This should probably be stored somewhere for real, so we don't
      // have to manage it here
      std::vector<std::tuple<std::string, std::string, ProcessorCategory>> processors = {
        {"SimpleVolumeLfo", "Simple Volume LFO", ProcessorCategory::ProcessorCategory_Effect},
        {"ToneGenerator", "Sine Tone Generator", ProcessorCategory::ProcessorCategory_Instrument},
        // {"3", "Processor3", ProcessorCategory::ProcessorCategory_Unknown}
      };

      for (const auto& processor : processors) {
        auto id = builder.CreateString(std::get<0>(processor));
        auto name = builder.CreateString(std::get<1>(processor));
        auto category = std::get<2>(processor);

        auto processorDescription = CreateProcessorDescription(builder, id, name, category);
        fbProcessorList.push_back(processorDescription);
      }

      auto processorListOffset = builder.CreateVector(fbProcessorList);

      auto response = CreateGetProcessorsResponse(builder, processorListOffset);
      auto responseOffset = response.Union();

      auto message = CreateResponse(builder, request->id(), ReturnValue_GetProcessorsResponse, responseOffset);

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
