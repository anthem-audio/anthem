/*
  Copyright (C) 2023 - 2025 Joshua Wade

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

#include "model_sync_command_handler.h"

// I have absolutely no idea why this import is required, but reflect-cpp won't
// compile the deserialization call without it.
#include "modules/processors/tone_generator.h"

#include <string>

std::optional<Response> handleModelSyncCommand(Request& request) {
  auto& anthem = Anthem::getInstance();

  if (rfl::holds_alternative<ModelInitRequest>(request.variant())) {
    juce::Logger::writeToLog("Loading project model...");

    auto& modelInitRequest = rfl::get<ModelInitRequest>(request.variant());

    // std::cout << modelInitRequest.serializedModel << std::endl;

    auto result = rfl::json::read<std::shared_ptr<Project>>(
      modelInitRequest.serializedModel
    );

    // auto result = Project::fromJson(modelInitRequest.serializedModel);

    auto err = result.error();

    if (err.has_value()) {
      juce::Logger::writeToLog("Error during deserialize:");
      std::cout << err.value().what() << std::endl;
      jassertfalse;
      // This shouldn't be possible if the UI loaded the project successfully,
      // but if it does happen, we should probably handle it better.
    }
    else {
      anthem.project = std::move(
        result.value()
      );

      anthem.project->initialize(
        anthem.project,
        nullptr
      );

      juce::Logger::writeToLog("Loaded project model");
      std::cout << "id: " << anthem.project->id() << std::endl;

      // We could probably move this action to a command, but for now we always
      // want to start as soon as we have a valid project anyway, so this is
      // probably fine.
      anthem.startAudioCallback();
    }
  }
  else if (rfl::holds_alternative<ModelUpdateRequest>(request.variant())) {
    auto& modelUpdateRequest = rfl::get<ModelUpdateRequest>(request.variant());

    anthem.project->handleModelUpdate(
      modelUpdateRequest,
      0
    );
  }
  else if (rfl::holds_alternative<GetSerializedModelFromEngineRequest>(request.variant())) {
    auto& getSerializedModelFromEngineRequest = rfl::get<GetSerializedModelFromEngineRequest>(request.variant());

    return std::optional(GetSerializedModelFromEngineResponse {
      .serializedModel = rfl::json::write(
        anthem.project.get()
      ),
      .responseBase = ResponseBase {
        .id = getSerializedModelFromEngineRequest.requestBase.get().id
      }
    });
  }

  return std::nullopt;
}
