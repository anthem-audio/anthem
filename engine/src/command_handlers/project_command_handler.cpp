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
