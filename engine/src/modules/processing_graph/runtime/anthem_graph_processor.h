/*
  Copyright (C) 2024 - 2025 Joshua Wade

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

#include <juce_core/juce_core.h>
#include <juce_events/juce_events.h>

#include "modules/processing_graph/compiler/anthem_graph_compilation_result.h"
#include "modules/util/ring_buffer.h"

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
  JUCE_LEAK_DETECTOR(AnthemGraphProcessor)

  AnthemGraphCompilationResult* processingSteps;
  RingBuffer<AnthemGraphCompilationResult*, 512> processingStepsQueue;
  RingBuffer<AnthemGraphCompilationResult*, 512> processingStepsDeletionQueue;
  juce::TimedCallback clearDeletionQueueTimedCallback;
public:
  // Processes a single block of audio in the graph. This will also process and
  // propagate event and control data.
  void process(int numSamples);

  // This function adds a new set of processing steps to the queue. This is
  // intended to be called from the main thread, and the processing steps will
  // be picked up by the audio thread.
  void setProcessingStepsFromMainThread(AnthemGraphCompilationResult* compilationResult);

  // This function clears the deletion queue. This is intended to be called from
  // the main thread. The audio thread should not deallocate memory, so old compilation
  // results are added to a deletion queue and then cleared from the main thread.
  void clearDeletionQueueFromMainThread();

  AnthemGraphProcessor();
};
