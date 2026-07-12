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

#include "modules/core/engine_runtime_services.h"
#include "modules/processing_graph/executor/graph_executor.h"
#include "modules/util/intentionally_leak.h"

namespace anthem {

struct GraphProcessor::RuntimeGraphHandoff {
  RuntimeGraphHandoff(RuntimeGraph* runtimeGraph,
      std::unique_ptr<GraphExecutor::RuntimeState> executorState,
      uint64_t audioProcessingConfigGeneration)
    : runtimeGraph(runtimeGraph), executorState(std::move(executorState)),
      audioProcessingConfigGeneration(audioProcessingConfigGeneration) {}

  std::unique_ptr<RuntimeGraph> runtimeGraph;
  std::unique_ptr<GraphExecutor::RuntimeState> executorState;
  uint64_t audioProcessingConfigGeneration;
};

GraphProcessor::GraphProcessor(EngineRuntimeServices& engineRuntimeServices)
  : executor(std::make_unique<GraphExecutor>()), engineRuntimeServices(&engineRuntimeServices),
    clearDeletionQueueTimedCallback(
        juce::TimedCallback([this]() { this->clearRetiredRuntimeGraphs(); })) {
  executor->prepare();
  clearDeletionQueueTimedCallback.startTimer(2000);
}

GraphProcessor::~GraphProcessor() {
  clearDeletionQueueTimedCallback.stopTimer();

  while (auto nextHandoff = pendingRuntimeGraphHandoffsQueue.read()) {
    delete nextHandoff.value();
  }

  clearRetiredRuntimeGraphs();

  delete rt_activeRuntimeGraphHandoff;
  rt_activeRuntimeGraphHandoff = nullptr;
}

void GraphProcessor::prepareForAudioProcessingConfig(
    const AudioProcessingConfig& audioProcessingConfig,
    GraphWorkerSchedulingMode workerSchedulingMode) {
  GraphExecutor::ThreadConfig threadConfig;

  if (audioProcessingConfig.isValid()) {
    threadConfig.audioBlockSize = audioProcessingConfig.blockSize;
    threadConfig.sampleRate = audioProcessingConfig.sampleRate;
    threadConfig.useRealtimeWorkerScheduling =
        workerSchedulingMode == GraphWorkerSchedulingMode::realtime;

#if JUCE_MAC
    threadConfig.macAudioWorkgroup = audioProcessingConfig.macAudioWorkgroup;

    if (threadConfig.macAudioWorkgroup) {
      threadConfig.maxActiveWorkerThreadCount =
          threadConfig.macAudioWorkgroup.getMaxParallelThreadCount();
    }
#endif
  }

  executor->prepare(threadConfig);
  resetRtServices();
}

void GraphProcessor::publishRuntimeGraph(
    RuntimeGraph* runtimeGraph, uint64_t audioProcessingConfigGeneration) {
  if (runtimeGraph == nullptr) {
    return;
  }

  auto executorState = executor->createRuntimeStateForGraph(*runtimeGraph);
  auto* handoff = new RuntimeGraphHandoff(
      runtimeGraph, std::move(executorState), audioProcessingConfigGeneration);

  if (!pendingRuntimeGraphHandoffsQueue.add(handoff)) {
    jassertfalse;
    delete handoff;
    return;
  }
}

void GraphProcessor::clearRuntimeGraph() {
  while (auto nextHandoff = pendingRuntimeGraphHandoffsQueue.read()) {
    delete nextHandoff.value();
  }

  delete rt_activeRuntimeGraphHandoff;
  rt_activeRuntimeGraphHandoff = nullptr;

  clearRetiredRuntimeGraphs();
  resetRtServices();
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

bool GraphProcessor::rt_process(int numSamples, uint64_t currentAudioProcessingConfigGeneration) {
  rt_processGraphUpdates();

  // The audio thread can run before the first runtime graph has been published
  // and handed over.
  if (rt_activeRuntimeGraphHandoff == nullptr) {
    return false;
  }

  auto& handoff = *rt_activeRuntimeGraphHandoff;

  jassert(handoff.runtimeGraph != nullptr);
  jassert(handoff.executorState != nullptr);

  if (handoff.runtimeGraph == nullptr || handoff.executorState == nullptr) {
    return false;
  }

  // The processing graph that we use must have been generated using the same
  // audio config that we have. If it wasn't, then we can't process.
  if (handoff.audioProcessingConfigGeneration != currentAudioProcessingConfigGeneration) {
    return false;
  }

  executor->rt_processBlock(*handoff.runtimeGraph, *handoff.executorState, numSamples);
  return true;
}

EngineRuntimeServices& GraphProcessor::getEngineRuntimeServices() {
  jassert(engineRuntimeServices != nullptr);
  return *engineRuntimeServices;
}

void GraphProcessor::resetRtServices() {
  jassert(engineRuntimeServices != nullptr);
  if (engineRuntimeServices != nullptr) {
    engineRuntimeServices->rt_reset();
  }
}

void GraphProcessor::clearRetiredRuntimeGraphs() {
  auto nextHandoff = retiredRuntimeGraphHandoffsQueue.read();

  while (nextHandoff) {
    delete nextHandoff.value();
    nextHandoff = retiredRuntimeGraphHandoffsQueue.read();
  }
}

} // namespace anthem
