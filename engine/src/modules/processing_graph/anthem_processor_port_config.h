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

#pragma once

#include <string>
#include <optional>

enum AnthemGraphNodePortType {
  Audio,
  Midi,
  Control
};

// This class defines info about a port on an AnthemProcessor. This info is used
class AnthemProcessorPortConfig {
public:
  // The type of the port.
  AnthemGraphNodePortType portType;

  // The name of the port.
  std::optional<std::string> name;

  // Constructor
  AnthemProcessorPortConfig(
    AnthemGraphNodePortType portType,
    std::optional<std::string> name = std::nullopt
  ) : portType(portType), name(name) {}
};
