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

#include "modules/core/audio_processing_config.h"
#include "modules/processing_graph/model/runtime_graph.h"
#include "modules/util/ring_buffer.h"

#include <cstdint>
#include <juce_events/juce_events.h>
#include <memory>

namespace anthem {

class GraphExecutor;
class EngineRuntimeServices;

enum class GraphWorkerSchedulingMode {
  realtime,
  normal,
};

class GraphProcessor {
private:
  struct RuntimeGraphHandoff;

  // Owned by the audio thread until a newer runtime graph is swapped in.
  RuntimeGraphHandoff* rt_activeRuntimeGraphHandoff = nullptr;

  // Graph ownership and executor-prepared state are transferred from the main
  // thread into this queue, then picked up by the audio thread.
  RingBuffer<RuntimeGraphHandoff*, 512> pendingRuntimeGraphHandoffsQueue;

  // Replaced runtime graphs are transferred back to the main thread so their
  // shared_ptr references and executor state are released off the audio thread.
  RingBuffer<RuntimeGraphHandoff*, 512> retiredRuntimeGraphHandoffsQueue;

  std::unique_ptr<GraphExecutor> executor;
  EngineRuntimeServices* engineRuntimeServices = nullptr;
  juce::TimedCallback clearDeletionQueueTimedCallback;
public:
  explicit GraphProcessor(EngineRuntimeServices& engineRuntimeServices);
  ~GraphProcessor();

  void prepareForAudioProcessingConfig(const AudioProcessingConfig& audioProcessingConfig,
      GraphWorkerSchedulingMode workerSchedulingMode = GraphWorkerSchedulingMode::realtime);

  // Transfers ownership of a newly built runtime graph from the main thread to
  // the audio thread.
  void publishRuntimeGraph(RuntimeGraph* runtimeGraph, uint64_t audioProcessingConfigGeneration);

  // Clears all runtime graph state. This must only be called while the audio
  // thread is stopped.
  void clearRuntimeGraph();

  // Picks up graph updates on the audio thread. This does not process audio
  // yet; it only keeps the runtime graph in sync.
  void rt_processGraphUpdates();

  // Processes the active runtime graph on the audio thread.
  bool rt_process(int numSamples, uint64_t currentAudioProcessingConfigGeneration);

  EngineRuntimeServices& getEngineRuntimeServices();
  void resetRtServices();

  // Destroys retired runtime graphs on the main thread.
  void clearRetiredRuntimeGraphs();
};

} // namespace anthem
