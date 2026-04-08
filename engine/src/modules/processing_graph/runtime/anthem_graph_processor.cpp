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

#include "anthem_graph_processor.h"

#include "modules/processing_graph/runtime/graph_runtime_services.h"
#include "modules/util/intentionally_leak.h"

AnthemGraphProcessor::AnthemGraphProcessor()
  : rt_services(std::make_unique<GraphRuntimeServices>()),
    clearDeletionQueueTimedCallback(
        juce::TimedCallback([this]() { this->clearDeletionQueueFromMainThread(); })) {
  // Periodically retire replaced compilation results on the main thread.
  this->clearDeletionQueueTimedCallback.startTimer(2000);
  this->rt_activeCompilationResult = nullptr;
}

AnthemGraphProcessor::~AnthemGraphProcessor() = default;

void AnthemGraphProcessor::setProcessingStepsFromMainThread(
    AnthemGraphCompilationResult* compilationResult) {
  if (!this->pendingCompilationResultsQueue.add(compilationResult)) {
    jassertfalse;
    compilationResult->cleanup();
    delete compilationResult;
  }
}

void AnthemGraphProcessor::clearDeletionQueueFromMainThread() {
  auto nextCompilationResult = this->retiredCompilationResultsQueue.read();

  while (nextCompilationResult) {
    auto* ptr = nextCompilationResult.value();
    ptr->cleanup();
    delete ptr;

    nextCompilationResult = this->retiredCompilationResultsQueue.read();
  }
}

void AnthemGraphProcessor::process(int numSamples) {
  auto nextCompilationResult = this->pendingCompilationResultsQueue.read();

  while (nextCompilationResult) {
    juce::Logger::writeToLog("Audio thread: New compilation result found, replacing old one");
    if (this->rt_activeCompilationResult != nullptr) {
      if (!this->retiredCompilationResultsQueue.add(this->rt_activeCompilationResult)) {
        // If the handoff queue overflows, preserve real-time safety and leak the
        // retired result instead of deleting it on the audio thread.
        intentionallyLeak(this->rt_activeCompilationResult);
      }
    }

    this->rt_activeCompilationResult = nextCompilationResult.value();
    nextCompilationResult = this->pendingCompilationResultsQueue.read();
  }

  // The audio thread can't do anything until it receives the first graph
  // compilation result.
  if (this->rt_activeCompilationResult == nullptr) {
    return;
  }

  auto& actionGroups = this->rt_activeCompilationResult->actionGroups;

  for (auto& group : actionGroups) {
    // Actions within groups can be executed in parallel, but we're not doing
    // that yet because the grouping is naive and we haven't profiled the
    // performance characteristics of everything yet. Some actions may be too
    // small to benefit from parallel execution, and the way we're grouping
    // at the moment may be suboptimal for some graphs.
    //
    // ALso, the action groups that write output buffers to input buffers
    // cannot be safely executed in parallel because they may have two actions
    // that target the same buffer.
    for (auto& action : *group) {
      action->execute(numSamples);
    }
  }
}

GraphRuntimeServices& AnthemGraphProcessor::getRtServices() {
  jassert(rt_services != nullptr);
  return *rt_services;
}

void AnthemGraphProcessor::resetRtServices() {
  jassert(rt_services != nullptr);
  if (rt_services != nullptr) {
    rt_services->rt_reset();
  }
}
