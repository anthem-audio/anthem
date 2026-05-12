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

#include <juce_audio_devices/juce_audio_devices.h>

namespace anthem {

struct GraphProcessor::RuntimeGraphHandoff {
  RuntimeGraphHandoff(
      RuntimeGraph* runtimeGraph, std::unique_ptr<GraphExecutor::RuntimeState> executorState)
    : runtimeGraph(runtimeGraph), executorState(std::move(executorState)) {}

  std::unique_ptr<RuntimeGraph> runtimeGraph;
  std::unique_ptr<GraphExecutor::RuntimeState> executorState;
};

GraphProcessor::GraphProcessor()
  : executor(std::make_unique<GraphExecutor>()),
    rt_services(std::make_unique<GraphRuntimeServices>()),
    clearDeletionQueueTimedCallback(
        juce::TimedCallback([this]() { this->clearDeletionQueueFromMainThread(); })) {
  executor->prepare();
  clearDeletionQueueTimedCallback.startTimer(2000);
}

GraphProcessor::~GraphProcessor() {
  clearDeletionQueueTimedCallback.stopTimer();

  while (auto nextHandoff = pendingRuntimeGraphHandoffsQueue.read()) {
    delete nextHandoff.value();
  }

  clearDeletionQueueFromMainThread();

  delete rt_activeRuntimeGraphHandoff;
  rt_activeRuntimeGraphHandoff = nullptr;
}

void GraphProcessor::prepareForAudioDevice(juce::AudioIODevice* device) {
  GraphExecutor::ThreadConfig threadConfig;

  if (device != nullptr) {
    threadConfig.audioBlockSize = device->getCurrentBufferSizeSamples();
    threadConfig.sampleRate = device->getCurrentSampleRate();

#if JUCE_MAC
    threadConfig.macAudioWorkgroup = device->getWorkgroup();

    if (threadConfig.macAudioWorkgroup) {
      threadConfig.maxActiveWorkerThreadCount =
          threadConfig.macAudioWorkgroup.getMaxParallelThreadCount();
    }
#endif
  }

  executor->prepare(threadConfig);
  resetRtServices();
}

void GraphProcessor::setRuntimeGraphFromMainThread(RuntimeGraph* runtimeGraph) {
  if (runtimeGraph == nullptr) {
    return;
  }

  auto executorState = executor->createRuntimeStateForGraph(*runtimeGraph);
  auto* handoff = new RuntimeGraphHandoff(runtimeGraph, std::move(executorState));

  if (!pendingRuntimeGraphHandoffsQueue.add(handoff)) {
    jassertfalse;
    delete handoff;
    return;
  }
}

void GraphProcessor::rt_processGraphUpdates() {
  auto nextHandoff = pendingRuntimeGraphHandoffsQueue.read();

  while (nextHandoff) {
    if (rt_activeRuntimeGraphHandoff != nullptr) {
      if (!retiredRuntimeGraphHandoffsQueue.add(rt_activeRuntimeGraphHandoff)) {
        // If the handoff queue overflows, preserve real-time safety and leak
        // the retired graph instead of deleting it on the audio thread.
        intentionallyLeak(rt_activeRuntimeGraphHandoff);
      }
    }

    rt_activeRuntimeGraphHandoff = nextHandoff.value();
    nextHandoff = pendingRuntimeGraphHandoffsQueue.read();
  }
}

void GraphProcessor::rt_process(int numSamples) {
  rt_processGraphUpdates();

  // The audio thread can run before the first runtime graph has been published
  // and handed over.
  if (rt_activeRuntimeGraphHandoff == nullptr) {
    return;
  }

  auto& handoff = *rt_activeRuntimeGraphHandoff;

  jassert(handoff.runtimeGraph != nullptr);
  jassert(handoff.executorState != nullptr);

  if (handoff.runtimeGraph == nullptr || handoff.executorState == nullptr) {
    return;
  }

  executor->rt_processBlock(*handoff.runtimeGraph, *handoff.executorState, numSamples);
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
  auto nextHandoff = retiredRuntimeGraphHandoffsQueue.read();

  while (nextHandoff) {
    delete nextHandoff.value();
    nextHandoff = retiredRuntimeGraphHandoffsQueue.read();
  }
}

} // namespace anthem
