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

AnthemGraphProcessor::AnthemGraphProcessor() {
  this->processingStepsQueue = std::make_unique<ThreadSafeQueue<std::shared_ptr<AnthemGraphCompilationResult>>>(512);
  this->processingStepsDeletionQueue = std::make_unique<ThreadSafeQueue<std::shared_ptr<AnthemGraphCompilationResult>>>(512);

  // Set up a JUCE timer to clear the deletion queue every 1s
  this->clearDeletionQueueTimedCallback = std::make_unique<juce::TimedCallback>([this]() {
    this->clearDeletionQueueFromMainThread();
  });
  this->clearDeletionQueueTimedCallback->startTimer(1000);
}

void AnthemGraphProcessor::setProcessingStepsFromMainThread(std::shared_ptr<AnthemGraphCompilationResult> compilationResult) {
  this->processingStepsQueue->add(compilationResult);
}

void AnthemGraphProcessor::clearDeletionQueueFromMainThread() {
  auto nextCompilationResult = this->processingStepsDeletionQueue->read();

  while (nextCompilationResult) {
    nextCompilationResult = this->processingStepsDeletionQueue->read();
  }
}

void AnthemGraphProcessor::process(int numSamples) {
  auto nextCompilationResult = this->processingStepsQueue->read();

  while (nextCompilationResult) {
    this->processingStepsDeletionQueue->add(this->processingSteps);
    this->processingSteps = nextCompilationResult.value();
    nextCompilationResult = this->processingStepsQueue->read();
  }

  auto actionGroups = this->processingSteps->actionGroups;

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
