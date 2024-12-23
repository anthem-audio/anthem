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

#include "node.h"

std::optional<std::shared_ptr<NodePort>> Node::getPortById(int32_t id) {
  for (auto& port : *this->audioInputPorts()) {
    if (port->id() == id) {
      return port;
    }
  }

  for (auto& port : *this->audioOutputPorts()) {
    if (port->id() == id) {
      return port;
    }
  }

  for (auto& port : *this->controlInputPorts()) {
    if (port->id() == id) {
      return port;
    }
  }

  for (auto& port : *this->controlOutputPorts()) {
    if (port->id() == id) {
      return port;
    }
  }

  for (auto& port : *this->midiInputPorts()) {
    if (port->id() == id) {
      return port;
    }
  }

  for (auto& port : *this->midiOutputPorts()) {
    if (port->id() == id) {
      return port;
    }
  }

  return std::nullopt;
}
