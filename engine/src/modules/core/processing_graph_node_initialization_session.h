/*
  Copyright (C) 2023 - 2026 Joshua Wade

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

#include "modules/core/engine.h"
#include "modules/processing_graph/model/node.h"
#include "modules/processing_graph/processor/processor.h"

#include <cstddef>
#include <cstdint>
#include <memory>
#include <optional>
#include <vector>

namespace anthem {

// Class used to track asynchronous node initialization.
//
// "Publishing" the live processing graph has two steps. First, we initialize
// all new nodes. Then, we send a condensed version of the graph to the audio
// node. This class takes care of the first step.
//
// The reason a separate class is necessary is that node initialization
// sometimes happens asynchronously, and so we need to store state to track the
// operation. The UI will send a graph initialization request, at which point we
// do the following:
//
// 1. Detect which nodes are not already initialized.
// 2. For each of those nodes, start the initialization process, and pass in a
//    callback. This callback is called once the initialization process has been
//    completed by the node, which may happen asynchronously. The node may
//    request an updated port layout by supplying it to this callback.
// 3. The results for each initialization are collected by the callbacks. Once
//    all nodes have been initialized, a top-level callback is called that sends
//    the result back to the command handler - see
//    processing_graph_command_handler.h/cpp.
class ProcessingGraphNodeInitializationSession
  : public std::enable_shared_from_this<ProcessingGraphNodeInitializationSession> {
private:
  struct NodeInitializationWorkItem {
    int64_t nodeId;
    std::shared_ptr<Node> graphNode;
  };

  struct ProcessingGraphInitializationDiff {
    std::vector<NodeInitializationWorkItem> nodesToInitialize;
    std::vector<std::shared_ptr<ProcessingGraphNodeInitializationResult>> immediateResults;
  };

  Engine& engine;
  InitializeProcessingGraphNodesCallback complete;
  std::vector<std::shared_ptr<ProcessingGraphNodeInitializationResult>> results;
  std::size_t pendingCount = 0;
  bool didFinishScheduling = false;
  bool didComplete = false;

  bool hasProcessingGraph() const;
  void pruneInitializedNodeTracker();
  ProcessingGraphInitializationDiff collectInitializationDiff();
  bool isStillCurrentGraphNode(int64_t nodeId, const std::shared_ptr<Node>& graphNode) const;
  void addResult(std::shared_ptr<ProcessingGraphNodeInitializationResult> result);
  void markNodeInitialized(int64_t nodeId, const std::shared_ptr<Node>& graphNode);
  void initializeNodeWithoutProcessor(const NodeInitializationWorkItem& workItem);
  void completeProcessorNode(int64_t nodeId,
      const std::weak_ptr<Node>& weakGraphNode,
      const std::weak_ptr<Processor>& weakProcessor,
      std::optional<ProcessorPrepareResult> prepareResult);
  void initializeProcessorNode(
      const NodeInitializationWorkItem& workItem, const std::shared_ptr<Processor>& processor);
  void initializeNode(const NodeInitializationWorkItem& workItem);
  void initializeDiff(ProcessingGraphInitializationDiff diff);
  void finishPendingNode();
  void maybeComplete();
public:
  ProcessingGraphNodeInitializationSession(
      Engine& engine, InitializeProcessingGraphNodesCallback complete);

  void run();
};

} // namespace anthem
