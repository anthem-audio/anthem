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

#include "modules/processing_graph/compiler/actions/clear_buffers_action.h"
#include "modules/processing_graph/compiler/node_process_context.h"

#include <cstdint>
#include <juce_core/juce_core.h>
#include <memory>

// Copies data from an output port to an input port
namespace anthem {

class CopyAudioBufferAction : public GraphCompilerAction {
private:
  JUCE_LEAK_DETECTOR(CopyAudioBufferAction)
public:
  NodeProcessContext* source;
  int64_t sourcePortId;

  NodeProcessContext* destination;
  int64_t destinationPortId;

  CopyAudioBufferAction(NodeProcessContext* source,
      int64_t sourcePortId,
      NodeProcessContext* destination,
      int64_t destinationPortId)
    : source(source), sourcePortId(sourcePortId), destination(destination),
      destinationPortId(destinationPortId) {}

  void execute(int numSamples) override;

  void debugPrint() override;
};

} // namespace anthem
