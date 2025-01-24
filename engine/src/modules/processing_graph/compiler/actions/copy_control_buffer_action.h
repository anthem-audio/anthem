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

#include <memory>

#include "modules/processing_graph/compiler/anthem_process_context.h"
#include "modules/processing_graph/compiler/actions/clear_buffers_action.h"

// This action copies the data from a given control output to a given control
// input.
//
// The output value is expected to be normalized from 0 to 1. When copying, the
// value is scaled to the range defined by the associated parameter value.
class CopyControlBufferAction : public AnthemGraphCompilerAction {
public:
  AnthemProcessContext* source;
  int32_t sourcePortId;

  AnthemProcessContext* destination;
  int32_t destinationPortId;

  float minParameterValue;
  float maxParameterValue;

  CopyControlBufferAction(
    AnthemProcessContext* source,
    int32_t sourcePortId,
    AnthemProcessContext* destination,
    int32_t destinationPortId,
    float minParameterValue,
    float maxParameterValue
  ) : source(source),
      sourcePortId(sourcePortId),
      destination(destination),
      destinationPortId(destinationPortId),
      minParameterValue(minParameterValue),
      maxParameterValue(maxParameterValue) {}

  void execute(int numSamples) override;

  void debugPrint() override;
};
