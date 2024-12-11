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

std::optional<Response> handleProcessorCommand(Request& request) {
  auto& anthem = Anthem::getInstance();

  if (rfl::holds_alternative<SetParameterRequest>(request.variant())) {
    // TODO: Validate that parameter changes are picked up and forwarded to the audio thread
    // they probably aren't right now

    // TODO: Remove this request

    /*auto& setParameterRequest = rfl::get<SetParameterRequest>(request.variant());

    auto nodeId = setParameterRequest.nodeId;
    auto parameterId = setParameterRequest.parameterId;
    auto value = setParameterRequest.value;

    anthem.getNode(nodeId)->setParameter(parameterId, value);

    return std::optional(SetParameterResponse {
      .success = true,
      .responseBase = ResponseBase {
        .id = setParameterRequest.requestBase.get().id
      }
    });*/

    return std::nullopt;
  }

  return std::nullopt;
}
