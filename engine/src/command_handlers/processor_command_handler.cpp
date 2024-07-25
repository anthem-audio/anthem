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

#include "processor_command_handler.h"

std::optional<flatbuffers::Offset<Response>>
handleProcessorCommand(const Request *request,
                       flatbuffers::FlatBufferBuilder &builder,
                        Anthem *anthem) {
  auto commandType = request->command_type();

  switch (commandType) {
    case Command_SetParameter: {
      auto command = request->command_as_SetParameter();
      auto nodeId = command->node_id();
      auto parameterId = command->parameter_id();
      auto value = command->value();

      anthem->getNode(nodeId)->setParameter(parameterId, value);

      auto response = CreateSetParameterResponse(builder, true);
      auto responseOffset = response.Union();

      auto message = CreateResponse(builder, request->id(), ReturnValue_SetParameterResponse, responseOffset);

      return std::optional(message);
    }
    default:
      return std::nullopt;
  }
}
