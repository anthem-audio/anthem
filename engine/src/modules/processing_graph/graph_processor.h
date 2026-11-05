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
#include "modules/processing_graph/runtime/node_processing_state.h"
#include "modules/util/ring_buffer.h"

#include <cstdint>
#include <functional>
#include <juce_events/juce_events.h>
#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace anthem {

class GraphExecutor;
class EngineRuntimeServices;
class Project;
class Node;

enum class GraphWorkerSchedulingMode {
  realtime,
  normal,
};

class GraphProcessor {
public:
  using PauseNodeCallback =
      std::function<void(std::shared_ptr<NodeProcessingPause>, std::optional<std::string>)>;
private:
  struct RuntimeGraphHandoff;
  struct NodePauseRequest {
    int64_t nodeId;
    std::weak_ptr<Node> node;
    std::weak_ptr<NodeProcessingPause> pause;
    std::shared_ptr<NodeProcessingPause> pending;
    PauseNodeCallback complete;
  };

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
  const std::shared_ptr<Project>& project;
  std::vector<NodePauseRequest> nodePauseRequests;
  juce::TimedCallback nodePauseTimer;
  bool isShutdown = false;

  std::shared_ptr<Node> findNode(int64_t nodeId) const;
  void pollNodePauses();
public:
  GraphProcessor(
      EngineRuntimeServices& engineRuntimeServices, const std::shared_ptr<Project>& project);
  ~GraphProcessor();

  // Starts graph workers and periodic cleanup of retired graphs.
  void initialize();

  // Final message-thread shutdown cancels pause requests and stops maintenance.
  // Audio-session stop/start uses clearRuntimeGraph() and retains pause claims.
  void shutdown();

  // Supplies a pause claim once processing is quiescent. The master output
  // cannot be paused. Requests and callback delivery belong on the message thread.
  void pauseNode(int64_t nodeId, PauseNodeCallback complete);

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
