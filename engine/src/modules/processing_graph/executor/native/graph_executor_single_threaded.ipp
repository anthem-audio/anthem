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

namespace anthem {

class GraphExecutor::RuntimeState::Impl final {
public:
  Impl(size_t readyNodeQueueCount, size_t readyNodeQueueCapacity) {
    juce::ignoreUnused(readyNodeQueueCount, readyNodeQueueCapacity);
  }
};

namespace {

void rt_processSingleThreaded(GraphExecutorState& state, int numSamples) {
  auto& runtimeGraph = state.runtimeGraph;

  jassert(runtimeGraph.availableTasks.empty());

  for (auto* inputNode : runtimeGraph.inputNodes) {
    runtimeGraph.availableTasks.push(inputNode);
  }

  while (!runtimeGraph.availableTasks.empty()) {
    auto* runtimeNode = runtimeGraph.availableTasks.top();
    runtimeGraph.availableTasks.pop();

    rt_processNode(state, *runtimeNode, numSamples);

    for (auto* downstreamNode : runtimeNode->outgoingConnections) {
      if (rt_decrementRemainingUpstreamNodes(*downstreamNode)) {
        runtimeGraph.availableTasks.push(downstreamNode);
      }
    }
  }
}

} // namespace

class GraphExecutor::Impl final {
public:
  Impl() = default;

  void prepare(const GraphExecutor::ThreadConfig& threadConfig) {
    juce::ignoreUnused(threadConfig);
  }

  size_t getReadyNodeQueueCount() const {
    return 1;
  }

  void rt_processBlock(RuntimeGraph& runtimeGraph, RuntimeState& runtimeState, int numSamples) {
    juce::ignoreUnused(runtimeState);

    GraphExecutorState state(runtimeGraph);
    rt_prepareGraphForBlock(state);
    rt_processSingleThreaded(state, numSamples);
  }
};

} // namespace anthem
