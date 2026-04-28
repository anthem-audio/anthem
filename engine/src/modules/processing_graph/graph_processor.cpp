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

#include "modules/processing_graph/executor/graph_executor.h"
#include "modules/processing_graph/runtime/graph_runtime_services.h"
#include "modules/util/intentionally_leak.h"

namespace anthem {

GraphProcessor::GraphProcessor()
  : executor(std::make_unique<GraphExecutor>()),
    rt_services(std::make_unique<GraphRuntimeServices>()),
    clearDeletionQueueTimedCallback(
        juce::TimedCallback([this]() { this->clearDeletionQueueFromMainThread(); })) {
  clearDeletionQueueTimedCallback.startTimer(2000);
}

GraphProcessor::~GraphProcessor() {
  clearDeletionQueueTimedCallback.stopTimer();

  while (auto nextRuntimeGraph = pendingRuntimeGraphsQueue.read()) {
    delete nextRuntimeGraph.value();
  }

  clearDeletionQueueFromMainThread();

  delete rt_activeRuntimeGraph;
  rt_activeRuntimeGraph = nullptr;
}

void GraphProcessor::setRuntimeGraphFromMainThread(RuntimeGraph* runtimeGraph) {
  if (!pendingRuntimeGraphsQueue.add(runtimeGraph)) {
    jassertfalse;
    delete runtimeGraph;
    return;
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

void GraphProcessor::rt_process(int numSamples) {
  rt_processGraphUpdates();

  // The audio thread can run before the first runtime graph has been compiled
  // and handed over.
  if (rt_activeRuntimeGraph == nullptr) {
    return;
  }

  executor->rt_processBlock(*rt_activeRuntimeGraph, numSamples);
}

GraphRuntimeServices& GraphProcessor::getRtServices() {
  jassert(rt_services != nullptr);
  return *rt_services;
}

void GraphProcessor::resetRtServices() {
  jassert(rt_services != nullptr);
  if (rt_services != nullptr) {
    rt_services->rt_reset();
  }
}

void GraphProcessor::clearDeletionQueueFromMainThread() {
  auto nextRuntimeGraph = retiredRuntimeGraphsQueue.read();

  while (nextRuntimeGraph) {
    delete nextRuntimeGraph.value();
    nextRuntimeGraph = retiredRuntimeGraphsQueue.read();
  }
}

} // namespace anthem
