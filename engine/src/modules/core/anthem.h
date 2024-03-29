/*
  Copyright (C) 2023 - 2024 Joshua Wade

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

#include <memory>
#include <iostream>

#include <juce_audio_devices/juce_audio_devices.h>

#include "anthem_audio_callback.h"
#include "anthem_graph.h"
#include "master_output_node.h"

class Anthem {
private:
  juce::AudioDeviceManager deviceManager;
  std::unique_ptr<AnthemAudioCallback> audioCallback;

  // Initializes the engine
  void init();
public:
  std::shared_ptr<AnthemGraph> processingGraph;
  std::shared_ptr<AnthemGraphNode> masterOutputNode;

  Anthem();
};
