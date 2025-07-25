/*
  Copyright (C) 2025 Joshua Wade

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

#include "visualization_command_handler.h"

#include "modules/core/visualization/visualization_broker.h"

std::optional<Response> handleVisualizationCommand(Request& request) {
  if (rfl::holds_alternative<SetVisualizationSubscriptionsRequest>(request.variant())) {
    auto& setVisualizationSubscriptionsRequest = rfl::get<SetVisualizationSubscriptionsRequest>(request.variant());

    // subscriptions is a list of strings
    // debug print:
    std::cout << "SetVisualizationSubscriptionsRequest: ";
    for (const auto& subscription : *setVisualizationSubscriptionsRequest.subscriptions) {
      std::cout << subscription << ", ";
    }
    std::cout << std::endl;

    VisualizationBroker::getInstance().setSubscriptions(
      *setVisualizationSubscriptionsRequest.subscriptions
    );
  } else if (rfl::holds_alternative<SetVisualizationUpdateIntervalRequest>(request.variant())) {
    auto& setVisualizationUpdateIntervalRequest = rfl::get<SetVisualizationUpdateIntervalRequest>(request.variant());

    // intervalMilliseconds is a double
    std::cout << "SetVisualizationUpdateIntervalRequest: " << setVisualizationUpdateIntervalRequest.intervalMilliseconds << std::endl;

    VisualizationBroker::getInstance().setUpdateInterval(
      setVisualizationUpdateIntervalRequest.intervalMilliseconds
    );
  }

  return std::nullopt;
}
