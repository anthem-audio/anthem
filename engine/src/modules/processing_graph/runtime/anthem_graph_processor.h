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

#pragma once

#include <memory>

#include <juce_events/juce_events.h>

#include "anthem_graph_compilation_result.h"
#include "thread_safe_queue.h"

// This class is used to handle the audio thread concerns of the processing
// graph. It owns a read-only instance of AnthemGraphTopology as well as a
// compiled set of processing instructions, and it is responsible for executing
// those instructions in a real-time context.
//
// This class should only be accessed from the audio thread, except for the
// setProcessingStepsFromMainThread function, which is intended to be called
// from the main thread.
class AnthemGraphProcessor {
private:
  std::shared_ptr<AnthemGraphCompilationResult> processingSteps;
  std::unique_ptr<ThreadSafeQueue<std::shared_ptr<AnthemGraphCompilationResult>>> processingStepsQueue;
  std::unique_ptr<ThreadSafeQueue<std::shared_ptr<AnthemGraphCompilationResult>>> processingStepsDeletionQueue;
  std::unique_ptr<juce::TimedCallback> clearDeletionQueueTimedCallback;
public:
  // Processes a single block of audio in the graph. This will also process and
  // propagate MIDI and control data.
  //
  // The output can be read from a node, such as a MasterOutputNode.
  void process(int numSamples);

  // This function adds a new set of processing steps to the queue. This is
  // intended to be called from the main thread, and the processing steps will
  // be picked up by the audio thread.
  void setProcessingStepsFromMainThread(std::shared_ptr<AnthemGraphCompilationResult> compilationResult);

  // This function clears the deletion queue. This is intended to be called from
  // the main thread. The audio thread should not deallocate memory, so old compilation
  // results are added to a deletion queue and then cleared from the main thread.
  void clearDeletionQueueFromMainThread();

  AnthemGraphProcessor();
};
