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

#include "modules/processors/tone_generator_node.h"
#include "modules/processors/simple_volume_lfo_node.h"

std::optional<Response> handleProjectCommand(
  Request& request,
  [[maybe_unused]] Anthem* anthem
) {
  if (rfl::holds_alternative<AddArrangementRequest>(request.variant())) {
    // TODO: Handle correctly
    std::cout << "Received unhandled AddArrangement command" << std::endl;

    auto& addArrangementRequest = rfl::get<AddArrangementRequest>(request.variant());

    int64_t editPtrAsUint = 0;

    auto response = AddArrangementResponse {
      .editId = editPtrAsUint,
      .responseBase = ResponseBase {
        .id = addArrangementRequest.requestBase.get().id
      }
    };

    return std::optional(std::move(response));
  }

  else if (rfl::holds_alternative<DeleteArrangementRequest>(request.variant())) {
    // TODO: Handle correctly
    std::cout << "Received unhandled DeleteArrangement command" << std::endl;

    auto& deleteArrangementRequest = rfl::get<DeleteArrangementRequest>(request.variant());
    
    std::cout << "Received unhandled DeleteArrangement command" << std::endl;
    std::cout << "Edit id: " << std::hex << deleteArrangementRequest.editId << std::dec << std::endl;

    return std::nullopt;
  }

  else if (rfl::holds_alternative<LiveNoteOnRequest>(request.variant())) {
    auto& liveNoteOnRequest = rfl::get<LiveNoteOnRequest>(request.variant());

    // auto edit_ptr = static_cast<uintptr_t>(command->edit_pointer());

    auto midiChannel = static_cast<int>(liveNoteOnRequest.channel);
    auto midiNoteNumber = static_cast<int>(liveNoteOnRequest.note);
    auto velocity = static_cast<float>(liveNoteOnRequest.velocity);

    juce::MidiMessage message = juce::MidiMessage::noteOn(midiChannel, midiNoteNumber, velocity);

    // TODO: Handle correctly
    std::cout << "Received unhandled LiveNoteOn command" << std::endl;

    return std::nullopt;
  }

  else if (rfl::holds_alternative<LiveNoteOffRequest>(request.variant())) {
    auto& liveNoteOffRequest = rfl::get<LiveNoteOffRequest>(request.variant());

    // auto edit_ptr = static_cast<uintptr_t>(command->edit_pointer());

    auto midiChannel = liveNoteOffRequest.channel;
    auto midiNoteNumber = liveNoteOffRequest.note;

    juce::MidiMessage message = juce::MidiMessage::noteOff(midiChannel, midiNoteNumber);

    // TODO: Handle correctly
    std::cout << "Received unhandled LiveNoteOff command" << std::endl;

    return std::nullopt;
  }

  return std::nullopt;
}
