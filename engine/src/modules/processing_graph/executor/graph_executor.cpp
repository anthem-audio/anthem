/*
  Copyright (C) 2026 Joshua Wade

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

#include "graph_executor.h"

#include "graph_executor_shared.h"
#include "modules/processing_graph/model/runtime_graph.h"

#include <juce_core/juce_core.h>

#if JUCE_WINDOWS
#include "native/graph_executor_windows.ipp"
#else
#include "native/graph_executor_generic.ipp"
#endif

namespace anthem {

GraphExecutor::GraphExecutor() : impl(std::make_unique<Impl>()) {}

GraphExecutor::~GraphExecutor() = default;

void GraphExecutor::prepare() {
  impl->prepare();
}

void GraphExecutor::rt_processBlock(RuntimeGraph& runtimeGraph, int numSamples) {
  impl->rt_processBlock(runtimeGraph, numSamples);
}

} // namespace anthem
