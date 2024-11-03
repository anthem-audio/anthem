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

#include "modules/processing_graph/compiler/actions/clear_buffers_action.h"
#include "modules/processing_graph/compiler/anthem_process_context.h"

// This action writes parameter values to control inputs ports for a given
// processor (given by that processor's processContext). This initializes the
// control input buffers for the current block, which may then be overwritten by
// incoming connections to the port. If there are no incoming connections, then
// the data written to each buffer by this step will be the data in that buffer
// when the node is processed.
class WriteParametersToControlInputsAction : public AnthemGraphCompilerAction {
private:
  AnthemProcessContext* processContext;
  float sampleRate;
public:
  WriteParametersToControlInputsAction(AnthemProcessContext* processContext, float sampleRate)
    : processContext(processContext), sampleRate(sampleRate) {}

  void execute(int numSamples) override;

  void debugPrint() override;
};
