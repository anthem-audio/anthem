/*
  Copyright (C) 2024 Joshua Wade

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

AnthemGraphProcessor::AnthemGraphProcessor() : clearDeletionQueueTimedCallback(juce::TimedCallback([this]() {
        this->clearDeletionQueueFromMainThread();
      })),
      processingStepsQueue(ThreadSafeQueue<AnthemGraphCompilationResult*>(512)),
      processingStepsDeletionQueue(ThreadSafeQueue<AnthemGraphCompilationResult*>(512)) {
  // Set up a JUCE timer to clear the deletion queue every 1s
  // this->clearDeletionQueueTimedCallback = std::move();
  this->clearDeletionQueueTimedCallback.startTimer(2000);
  this->processingSteps = nullptr;
}

void AnthemGraphProcessor::setProcessingStepsFromMainThread(AnthemGraphCompilationResult* compilationResult) {
  this->processingStepsQueue.add(compilationResult);
}

void AnthemGraphProcessor::clearDeletionQueueFromMainThread() {
  auto nextCompilationResult = this->processingStepsDeletionQueue.read();

  while (nextCompilationResult) {
    auto* ptr = nextCompilationResult.value();
    delete ptr;
    nextCompilationResult = this->processingStepsDeletionQueue.read();
  }
}

void AnthemGraphProcessor::process(int numSamples) {
  auto nextCompilationResult = std::move(this->processingStepsQueue.read());

  while (nextCompilationResult) {
    if (this->processingSteps != nullptr) {
      this->processingStepsDeletionQueue.add(this->processingSteps);
    }

    this->processingSteps = nextCompilationResult.value();
    nextCompilationResult = this->processingStepsQueue.read();
  }

  // The audio thread can't do anything until it receives the first graph
  // compilation result.
	if (this->processingSteps == nullptr) {
		return;
	}

  auto& actionGroups = this->processingSteps->actionGroups;

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
