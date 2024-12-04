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
#include "modules/processors/tone_generator.h"
#include "modules/processors/gain_node.h"

std::optional<Response>
handleProcessingGraphCommand(Request& request) {
  auto& anthem = Anthem::getInstance();

  if (rfl::holds_alternative<GetProcessorsRequest>(request.variant())) {
    // TODO: remove this request
    return std::nullopt;
  }

  else if (rfl::holds_alternative<GetProcessorPortsRequest>(request.variant())) {
    // TODO: remove this request
    return std::nullopt;
  }

  else if (rfl::holds_alternative<GetMasterOutputNodeIdRequest>(request.variant())) {
    // TODO: remove this request
    return std::nullopt;
  }

  else if (rfl::holds_alternative<AddProcessorRequest>(request.variant())) {
    // TODO: remove this request
    return std::nullopt;
  } else if (rfl::holds_alternative<RemoveProcessorRequest>(request.variant())) {
    // TODO: remove this request
    return std::nullopt;
  }

  else if (rfl::holds_alternative<ConnectProcessorsRequest>(request.variant())) {
    // TODO: remove this request
    return std::nullopt;
  }

  else if (rfl::holds_alternative<DisconnectProcessorsRequest>(request.variant())) {
    // TODO: remove this request
    return std::nullopt;
  }

  else if (rfl::holds_alternative<CompileProcessingGraphRequest>(request.variant())) {
    auto& compileProcessingGraphRequest = rfl::get<CompileProcessingGraphRequest>(request.variant());

    std::cout << "Compiling from UI request..." << std::endl;

    anthem.compileProcessingGraph();

    std::cout << "Finished compiling." << std::endl;

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
