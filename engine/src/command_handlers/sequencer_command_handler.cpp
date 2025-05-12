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

#include "sequencer_command_handler.h"

#include "modules/core/anthem.h"

std::optional<Response> handleSequencerCommand(Request& request) {
  if (rfl::holds_alternative<PlayRequest>(request.variant())) {
    // auto& playRequest = rfl::get<PlayRequest>(request.variant());
    Anthem::getInstance().transport->play();
  }
  else if (rfl::holds_alternative<StopRequest>(request.variant())) {
    // auto& stopRequest = rfl::get<StopRequest>(request.variant());
    Anthem::getInstance().transport->stop();
  }

  return std::nullopt;
}
