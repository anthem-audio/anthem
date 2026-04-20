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

#pragma once

#include "modules/processing_graph/compiler/anthem_graph_compilation_result.h"
#include "modules/util/ring_buffer.h"

#include <juce_core/juce_core.h>
#include <juce_events/juce_events.h>
#include <memory>

namespace anthem {

class GraphRuntimeServices;

// This class is used to handle the audio thread concerns of the processing
// graph. It owns a read-only instance of AnthemGraphTopology as well as a
// compiled set of processing instructions, and it is responsible for executing
// those instructions in a real-time context.
//
// This class should only be accessed from the audio thread, except for the
// setProcessingStepsFromMainThread and clearDeletionQueueFromMainThread
// functions, which are intended to be called from the main thread.
class GraphProcessor {
private:
  JUCE_LEAK_DETECTOR(GraphProcessor)

  // Owned by the audio thread until a newer compilation result is swapped in.
  GraphCompilationResult* rt_activeCompilationResult;
  std::unique_ptr<GraphRuntimeServices> rt_services;

  // Ownership is transferred from the main thread into this queue, then picked
  // up by the audio thread at the start of process().
  RingBuffer<GraphCompilationResult*, 512> pendingCompilationResultsQueue;

  // Replaced active results are transferred back to the main thread through
  // this queue so cleanup and deletion happen off the audio thread.
  RingBuffer<GraphCompilationResult*, 512> retiredCompilationResultsQueue;

  juce::TimedCallback clearDeletionQueueTimedCallback;
public:
  ~GraphProcessor();

  // Processes a single block of audio in the graph. This will also process and
  // propagate event and control data.
  void process(int numSamples);

  // Transfers ownership of a newly compiled result from the main thread to the
  // audio thread. The result will become active at the start of a later
  // process() call.
  void setProcessingStepsFromMainThread(GraphCompilationResult* compilationResult);

  // Destroys retired compilation results on the main thread. The audio thread
  // never deletes compilation results directly.
  void clearDeletionQueueFromMainThread();

  GraphRuntimeServices& getRtServices();
  void resetRtServices();

  GraphProcessor();
};

} // namespace anthem
