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

#pragma once

namespace anthem {

class RuntimeGraph;
struct RuntimeNode;

struct GraphExecutorState {
  explicit GraphExecutorState(RuntimeGraph& runtimeGraph);

  RuntimeGraph& runtimeGraph;
};

// Resets per-block runtime counters before scheduling starts.
void rt_prepareGraphForBlock(GraphExecutorState& state);

// Allocates arena-backed audio slots needed by this node. The threaded
// executor must call this from its scheduler-gated section.
void rt_prepareNodeForProcessing(GraphExecutorState& state, RuntimeNode& node);

// Merges/copies this node's incoming connection data, then invokes the node's
// processor if it has one.
void rt_processNode(GraphExecutorState& state, RuntimeNode& node, int numSamples);

// Releases this node's uses of arena-backed audio slots, freeing only slots
// whose last remaining use is released. The threaded executor must call this
// from its scheduler-gated section.
void rt_finishNodeProcessing(GraphExecutorState& state, RuntimeNode& node);

// Marks one upstream node as processed and returns true if this node is now
// ready to run.
bool rt_decrementRemainingUpstreamNodes(RuntimeNode& node);

} // namespace anthem
