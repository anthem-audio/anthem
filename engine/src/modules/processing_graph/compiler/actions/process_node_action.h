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

#include "modules/processing_graph/compiler/actions/graph_compiler_action.h"
#include "modules/processing_graph/compiler/node_process_context.h"
#include "modules/processing_graph/processor/processor.h"

#include <juce_core/juce_core.h>
#include <memory>

namespace anthem {

class ProcessNodeAction : public GraphCompilerAction {
private:
  JUCE_LEAK_DETECTOR(ProcessNodeAction)
public:
  NodeProcessContext* context;
  Processor* processor;

  void execute(int numSamples) override;

  ProcessNodeAction(NodeProcessContext* context, Processor* processor)
    : context(context), processor(processor) {}

  void debugPrint() override;
};

} // namespace anthem
