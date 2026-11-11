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
#include "modules/core/project.h"
#include "modules/processing_graph/executor/graph_executor.h"
#include "modules/util/intentionally_leak.h"

#include <utility>

namespace anthem {

struct GraphProcessor::RuntimeGraphHandoff {
  RuntimeGraphHandoff(RuntimeGraph* runtimeGraph,
      std::unique_ptr<GraphExecutor::RuntimeState> executorState,
      uint64_t audioProcessingConfigGeneration,
      uint64_t publicationId)
    : runtimeGraph(runtimeGraph), executorState(std::move(executorState)),
      audioProcessingConfigGeneration(audioProcessingConfigGeneration),
      publicationId(publicationId) {}

  std::unique_ptr<RuntimeGraph> runtimeGraph;
  std::unique_ptr<GraphExecutor::RuntimeState> executorState;
  uint64_t audioProcessingConfigGeneration;
  uint64_t publicationId;
};

GraphProcessor::GraphProcessor(
    EngineRuntimeServices& engineRuntimeServices, const std::shared_ptr<Project>& project)
  : executor(std::make_unique<GraphExecutor>()), engineRuntimeServices(&engineRuntimeServices),
    clearDeletionQueueTimedCallback(
        juce::TimedCallback([this]() { this->clearRetiredRuntimeGraphs(); })),
    project(project), nodePauseTimer([this]() { pollNodePauses(); }) {}

void GraphProcessor::initialize() {
  executor->prepare();
  clearDeletionQueueTimedCallback.startTimer(2000);
}

GraphProcessor::~GraphProcessor() {
  shutdown();

  while (auto nextHandoff = pendingRuntimeGraphHandoffsQueue.read()) {
    delete nextHandoff.value();
  }

  clearRetiredRuntimeGraphs();

  delete rt_activeRuntimeGraphHandoff;
  rt_activeRuntimeGraphHandoff = nullptr;
}

void GraphProcessor::shutdown() {
  if (isShutdown)
    return;
  isShutdown = true;
  nodePauseTimer.stopTimer();
  clearDeletionQueueTimedCallback.stopTimer();
  auto cancelled = std::exchange(nodePauseRequests, {});
  for (auto& request : cancelled) {
    if (auto pause = request.pause.lock())
      pause->cancel();
    if (request.complete)
      request.complete(nullptr, "Graph processor has shut down.");
  }
}

std::shared_ptr<Node> GraphProcessor::findNode(int64_t nodeId) const {
  if (!project || !project->processingGraph())
    return nullptr;
  const auto& nodes = *project->processingGraph()->nodes();
  const auto node = nodes.find(nodeId);
  return node == nodes.end() ? nullptr : node->second;
}

void GraphProcessor::pauseNode(int64_t nodeId, PauseNodeCallback complete) {
  if (isShutdown) {
    complete(nullptr, "Graph processor has shut down.");
    return;
  }
  const auto node = findNode(nodeId);
  const auto processor = node ? node->getProcessor() : nullptr;
  if (!node) {
    complete(nullptr, "Processing graph node not found.");
    return;
  }
  if (dynamic_cast<MasterOutputProcessor*>(processor.get()) != nullptr) {
    complete(nullptr, "The master output node cannot be paused.");
    return;
  }
  auto pause = processor->pauseProcessing();
  nodePauseRequests.push_back({.nodeId = nodeId,
      .node = node,
      .pause = pause,
      .pending = std::move(pause),
      .complete = std::move(complete)});
  nodePauseTimer.startTimer(5);
  pollNodePauses();
}

void GraphProcessor::pollNodePauses() {
  if (isShutdown)
    return;
  struct Completed {
    PauseNodeCallback complete;
    std::shared_ptr<NodeProcessingPause> pause;
    std::optional<std::string> error;
    int64_t nodeId = 0;
    std::weak_ptr<Node> node;
  };
  std::vector<Completed> completed;
  for (auto it = nodePauseRequests.begin(); it != nodePauseRequests.end();) {
    auto pause = it->pause.lock();
    if (!pause || !pause->isValid()) {
      if (it->complete)
        completed.push_back({std::move(it->complete), nullptr, "Node pause was cancelled."});
      it = nodePauseRequests.erase(it);
      continue;
    }
    const auto node = findNode(it->nodeId);
    if (!node || node != it->node.lock()) {
      pause->cancel();
      if (it->complete)
        completed.push_back({std::move(it->complete), nullptr, "Processing graph node changed."});
      it = nodePauseRequests.erase(it);
      continue;
    }
    if (it->complete && pause->isPaused())
      completed.push_back({.complete = std::exchange(it->complete, {}),
          .pause = std::move(it->pending),
          .nodeId = it->nodeId,
          .node = it->node});
    ++it;
  }
  if (nodePauseRequests.empty())
    nodePauseTimer.stopTimer();
  // Callers can release claims, request more pauses, or shut down graph processing.
  for (auto& result : completed) {
    const auto node = isShutdown ? nullptr : findNode(result.nodeId);
    if (result.pause && (!node || node != result.node.lock()))
      result.pause->cancel();
    if (isShutdown || (result.pause && !result.pause->isValid()))
      result.complete(nullptr, "Node pause was cancelled.");
    else
      result.complete(std::move(result.pause), std::move(result.error));
  }
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

uint64_t GraphProcessor::publishRuntimeGraph(
    RuntimeGraph* runtimeGraph, uint64_t audioProcessingConfigGeneration) {
  if (runtimeGraph == nullptr) {
    return 0;
  }

  auto executorState = executor->createRuntimeStateForGraph(*runtimeGraph);
  auto* handoff = new RuntimeGraphHandoff(
      runtimeGraph, std::move(executorState), audioProcessingConfigGeneration, ++nextPublicationId);

  if (!pendingRuntimeGraphHandoffsQueue.add(handoff)) {
    jassertfalse;
    delete handoff;
    return 0;
  }
  return handoff->publicationId;
}

void GraphProcessor::clearRuntimeGraph() {
  activePublicationId.store(0, std::memory_order_release);
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
    activePublicationId.store(
        rt_activeRuntimeGraphHandoff->publicationId, std::memory_order_release);
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
