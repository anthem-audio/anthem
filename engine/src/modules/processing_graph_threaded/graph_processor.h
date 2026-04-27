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

#pragma once

#include "modules/processing_graph_threaded/model/runtime_graph.h"
#include "modules/util/ring_buffer.h"

#include <juce_events/juce_events.h>

namespace anthem::threaded_graph {

class GraphProcessor {
private:
  // Owned by the audio thread until a newer runtime graph is swapped in.
  RuntimeGraph* rt_activeRuntimeGraph = nullptr;

  // Ownership is transferred from the main thread into this queue, then picked
  // up by the audio thread.
  RingBuffer<RuntimeGraph*, 512> pendingRuntimeGraphsQueue;

  // Replaced runtime graphs are transferred back to the main thread so their
  // shared_ptr references are released off the audio thread.
  RingBuffer<RuntimeGraph*, 512> retiredRuntimeGraphsQueue;

  juce::TimedCallback clearDeletionQueueTimedCallback;
public:
  GraphProcessor();
  ~GraphProcessor();

  // Transfers ownership of a newly built runtime graph from the main thread to
  // the audio thread.
  void setRuntimeGraphFromMainThread(RuntimeGraph* runtimeGraph);

  // Picks up graph updates on the audio thread. This does not process audio
  // yet; it only keeps the threaded graph mirror in sync.
  void rt_processGraphUpdates();

  // Destroys retired runtime graphs on the main thread.
  void clearDeletionQueueFromMainThread();
};

} // namespace anthem::threaded_graph
