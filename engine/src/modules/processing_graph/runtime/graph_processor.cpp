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

#include "graph_processor.h"

#include "modules/processing_graph/runtime/graph_action_executor.h"
#include "modules/processing_graph/runtime/graph_runtime_services.h"
#include "modules/util/intentionally_leak.h"

namespace anthem {

namespace {
void deleteCompilationResult(GraphCompilationResult* result) {
  if (result == nullptr) {
    return;
  }

  result->cleanup();
  delete result;
}
} // namespace

GraphProcessor::GraphProcessor()
  : rt_services(std::make_unique<GraphRuntimeServices>()),
    clearDeletionQueueTimedCallback(
        juce::TimedCallback([this]() { this->clearDeletionQueueFromMainThread(); })) {
  // Periodically retire replaced compilation results on the main thread.
  this->clearDeletionQueueTimedCallback.startTimer(2000);
  this->rt_activeCompilationResult = nullptr;
}

GraphProcessor::~GraphProcessor() {
  this->clearDeletionQueueTimedCallback.stopTimer();

  while (auto nextCompilationResult = this->pendingCompilationResultsQueue.read()) {
    deleteCompilationResult(nextCompilationResult.value());
  }

  this->clearDeletionQueueFromMainThread();

  deleteCompilationResult(this->rt_activeCompilationResult);
  this->rt_activeCompilationResult = nullptr;
}

void GraphProcessor::setProcessingStepsFromMainThread(GraphCompilationResult* compilationResult) {
  if (!this->pendingCompilationResultsQueue.add(compilationResult)) {
    jassertfalse;
    compilationResult->cleanup();
    delete compilationResult;
  }
}

void GraphProcessor::clearDeletionQueueFromMainThread() {
  auto nextCompilationResult = this->retiredCompilationResultsQueue.read();

  while (nextCompilationResult) {
    deleteCompilationResult(nextCompilationResult.value());

    nextCompilationResult = this->retiredCompilationResultsQueue.read();
  }
}

void GraphProcessor::process(int numSamples) {
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

  executeGraphActions(*this->rt_activeCompilationResult, numSamples);
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

} // namespace anthem
