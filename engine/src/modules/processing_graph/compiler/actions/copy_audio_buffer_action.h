/*
  Copyright (C) 2024 - 2026 Joshua Wade

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
#include <cstdint>

#include <juce_core/juce_core.h>

#include "modules/processing_graph/compiler/anthem_node_process_context.h"
#include "modules/processing_graph/compiler/actions/clear_buffers_action.h"

// Copies data from an output port to an input port
class CopyAudioBufferAction : public AnthemGraphCompilerAction {
private:
  JUCE_LEAK_DETECTOR(CopyAudioBufferAction)
public:
  AnthemNodeProcessContext* source;
  int64_t sourcePortId;

  AnthemNodeProcessContext* destination;
  int64_t destinationPortId;

  CopyAudioBufferAction(
    AnthemNodeProcessContext* source,
    int64_t sourcePortId,
    AnthemNodeProcessContext* destination,
    int64_t destinationPortId
  ) : source(source), sourcePortId(sourcePortId), destination(destination), destinationPortId(destinationPortId) {}

  void execute(int numSamples) override;

  void debugPrint() override;
};
