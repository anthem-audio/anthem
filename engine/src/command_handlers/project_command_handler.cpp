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
    case Command_AddPlugin: {
      // TODO: Handle correctly
      std::cout << "Received unhandled AddPlugin command" << std::endl;

      bool success = false;

      // Error response
      if (!success) {
        auto errorResponse = CreateAddPluginResponse(builder, false);
        auto errorResponseOffset = errorResponse.Union();
        auto errorResponseMessage = CreateResponse(builder, request->id(), ReturnValue_AddPluginResponse, errorResponseOffset);

        return std::optional(errorResponseMessage);
      } else {
        auto response = CreateAddPluginResponse(builder, true);
        auto responseOffset = response.Union();

        auto message = CreateResponse(builder, request->id(), ReturnValue_AddPluginResponse, responseOffset);

        return std::optional(message);
      }
    }
    case Command_GetPlugins: {
      // TODO: Handle correctly
      std::cout << "Received unhandled GetPlugins command" << std::endl;

      // auto& pluginManager = anthem->engine->getPluginManager();

      // auto plugins = pluginManager.knownPluginList.getTypes();

      std::vector<flatbuffers::Offset<flatbuffers::String>> fbPluginList;

      // if (plugins.size() == 0) {
      //   fbPluginList.push_back(builder.CreateString("(:"));
      // } else {
      //   for (auto plugin : plugins) {
      //     fbPluginList.push_back(
      //       builder.CreateString(
      //         plugin.name.toStdString() + " - " + plugin.descriptiveName.toStdString()
      //       )
      //     );
      //   }
      // }

      auto pluginListOffset = builder.CreateVector(fbPluginList);

      auto response = CreateGetPluginsResponse(builder, pluginListOffset);
      auto responseOffset = response.Union();

      auto message = CreateResponse(builder, request->id(), ReturnValue_GetPluginsResponse, responseOffset);

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
