/*
  Copyright (C) 2024 - 2025 Joshua Wade

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

  if (rfl::holds_alternative<CompileProcessingGraphRequest>(request.variant())) {
    auto& compileProcessingGraphRequest = rfl::get<CompileProcessingGraphRequest>(request.variant());

    juce::Logger::writeToLog("Compiling from UI request...");

    anthem.compileProcessingGraph();

    juce::Logger::writeToLog("Finished compiling.");

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
