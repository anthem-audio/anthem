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

#include "graph_processor.h"

#include "modules/util/intentionally_leak.h"

namespace anthem::threaded_graph {

namespace {
void deleteRuntimeGraph(RuntimeGraph* runtimeGraph) {
  delete runtimeGraph;
}
} // namespace

GraphProcessor::GraphProcessor()
  : clearDeletionQueueTimedCallback(
        juce::TimedCallback([this]() { this->clearDeletionQueueFromMainThread(); })) {
  clearDeletionQueueTimedCallback.startTimer(2000);
}

GraphProcessor::~GraphProcessor() {
  clearDeletionQueueTimedCallback.stopTimer();

  while (auto nextRuntimeGraph = pendingRuntimeGraphsQueue.read()) {
    deleteRuntimeGraph(nextRuntimeGraph.value());
  }

  clearDeletionQueueFromMainThread();

  deleteRuntimeGraph(rt_activeRuntimeGraph);
  rt_activeRuntimeGraph = nullptr;
}

void GraphProcessor::setRuntimeGraphFromMainThread(RuntimeGraph* runtimeGraph) {
  if (!pendingRuntimeGraphsQueue.add(runtimeGraph)) {
    jassertfalse;
    deleteRuntimeGraph(runtimeGraph);
  }
}

void GraphProcessor::rt_processGraphUpdates() {
  auto nextRuntimeGraph = pendingRuntimeGraphsQueue.read();

  while (nextRuntimeGraph) {
    if (rt_activeRuntimeGraph != nullptr) {
      if (!retiredRuntimeGraphsQueue.add(rt_activeRuntimeGraph)) {
        // If the handoff queue overflows, preserve real-time safety and leak
        // the retired graph instead of deleting it on the audio thread.
        intentionallyLeak(rt_activeRuntimeGraph);
      }
    }

    rt_activeRuntimeGraph = nextRuntimeGraph.value();
    nextRuntimeGraph = pendingRuntimeGraphsQueue.read();
  }
}

void GraphProcessor::clearDeletionQueueFromMainThread() {
  auto nextRuntimeGraph = retiredRuntimeGraphsQueue.read();

  while (nextRuntimeGraph) {
    deleteRuntimeGraph(nextRuntimeGraph.value());
    nextRuntimeGraph = retiredRuntimeGraphsQueue.read();
  }
}

} // namespace anthem::threaded_graph
