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

#include <vector>

#include "anthem_processor_port_config.h"

// This class defines properties for an AnthemProcessor. These properties are
// used by the graph to define things like inputs and outputs.
class AnthemProcessorConfig {
public:
  std::vector<AnthemProcessorPortConfig> audioInputs;
  std::vector<AnthemProcessorPortConfig> audioOutputs;

  std::vector<AnthemProcessorPortConfig> midiInputs;
  std::vector<AnthemProcessorPortConfig> midiOutputs;

  std::vector<AnthemProcessorPortConfig> controlInputs;
  std::vector<AnthemProcessorPortConfig> controlOutputs;
};
