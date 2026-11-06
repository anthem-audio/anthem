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

#include "modules/core/processing_graph_node_initialization_session.h"

#include "processor_description.h"

#include <exception>
#include <memory>
#include <optional>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace anthem {

ProcessingGraphNodeInitializationSession::ProcessingGraphNodeInitializationSession(
    Engine& engine, InitializeProcessingGraphNodesCallback complete)
  : engine(engine), complete(std::move(complete)) {}

bool ProcessingGraphNodeInitializationSession::hasProcessingGraph() const {
  return engine.project != nullptr && engine.project->processingGraph() != nullptr;
}

void ProcessingGraphNodeInitializationSession::pruneInitializedNodeTracker() {
  auto& graphNodes = *engine.project->processingGraph()->nodes();

  for (auto iter = engine.initializedProcessingGraphNodes.begin();
      iter != engine.initializedProcessingGraphNodes.end();) {
    auto graphNodeIter = graphNodes.find(iter->first);
    auto initializedNode = iter->second.lock();

    if (graphNodeIter == graphNodes.end() || initializedNode == nullptr ||
        initializedNode != graphNodeIter->second) {
      if (initializedNode != nullptr) {
        initializedNode->getProcessor()->isPrepared = false;
      }

      iter = engine.initializedProcessingGraphNodes.erase(iter);
      continue;
    }

    ++iter;
  }
}

ProcessingGraphNodeInitializationSession::ProcessingGraphInitializationDiff
ProcessingGraphNodeInitializationSession::collectInitializationDiff() {
  auto& graphNodes = *engine.project->processingGraph()->nodes();
  ProcessingGraphInitializationDiff diff;
  diff.nodesToInitialize.reserve(graphNodes.size());

  // Then initialize the delta: every current node that is not already tracked
  // as this exact Node instance. Existing tracked nodes have already completed
  // preparation, so they are intentionally skipped.
  for (auto& [nodeId, graphNode] : graphNodes) {
    if (graphNode == nullptr) {
      diff.immediateResults.push_back(makeNodeInitializationResult(
          nodeId, false, "Processing graph cannot initialize a null node."));
      continue;
    }

    // A live snapshot load owns preparation until its graph is reconciled.
    if (engine.processorStateStorage.isBusy(nodeId))
      continue;

    auto initializedNodeIter = engine.initializedProcessingGraphNodes.find(nodeId);
    if (initializedNodeIter != engine.initializedProcessingGraphNodes.end() &&
        initializedNodeIter->second.lock() == graphNode) {
      continue;
    }

    diff.nodesToInitialize.push_back(NodeInitializationWorkItem{
        .nodeId = nodeId,
        .graphNode = graphNode,
    });
  }

  return diff;
}

bool ProcessingGraphNodeInitializationSession::isStillCurrentGraphNode(
    int64_t nodeId, const std::shared_ptr<Node>& graphNode) const {
  if (graphNode == nullptr || !hasProcessingGraph()) {
    return false;
  }

  auto& graphNodes = *engine.project->processingGraph()->nodes();
  auto graphNodeIter = graphNodes.find(nodeId);

  return graphNodeIter != graphNodes.end() && graphNodeIter->second == graphNode;
}

void ProcessingGraphNodeInitializationSession::addResult(
    std::shared_ptr<ProcessingGraphNodeInitializationResult> result) {
  results.push_back(std::move(result));
}

void ProcessingGraphNodeInitializationSession::markNodeInitialized(
    int64_t nodeId, const std::shared_ptr<Node>& graphNode) {
  engine.initializedProcessingGraphNodes[nodeId] = graphNode;
}

void ProcessingGraphNodeInitializationSession::completeProcessorNode(int64_t nodeId,
    const std::weak_ptr<Node>& weakGraphNode,
    const std::weak_ptr<Processor>& weakProcessor,
    std::optional<ProcessorPrepareResult> prepareResult) {
  auto graphNode = weakGraphNode.lock();
  auto processor = weakProcessor.lock();

  // Async plugin creation can complete after the UI has deleted or replaced
  // the node. Only the current shared-model node instance may update the
  // initialization tracker or report port config that the UI could apply back
  // to the graph.
  if (!isStillCurrentGraphNode(nodeId, graphNode) || processor == nullptr) {
    if (processor != nullptr) {
      processor->isPrepared = false;
    }

    addResult(makeNodeInitializationResult(
        nodeId, false, "Processing graph node changed before initialization completed."));
    finishPendingNode();
    return;
  }

  if (prepareResult.has_value() && !prepareResult->success) {
    processor->isPrepared = false;
    addResult(makeNodeInitializationResult(nodeId, *prepareResult));
    finishPendingNode();
    return;
  }

  try {
    if (!prepareResult || !prepareResult->portConfiguration)
      throw std::runtime_error("Processor preparation did not supply a port configuration.");
    processor->reconcileParameters(*prepareResult);
    if (!processor->hasRestoredProjectState) {
      if (graphNode->processorStateRetentionId().has_value()) {
        engine.processorStateStorage.restore(graphNode,
            processor,
            [self = shared_from_this(), nodeId, weakGraphNode, weakProcessor](
                std::optional<std::string> error) {
              self->completeStateRestoration(
                  nodeId, weakGraphNode, weakProcessor, std::move(error));
            });
        return;
      }
      std::map<int64_t, double> initialValues;
      for (const auto& [id, value] : *graphNode->initialParameterValues())
        initialValues.emplace(id, value);
      processor->restoreParameterValues(initialValues);
      processor->hasRestoredProjectState = true;
    }
    prepareResult->parameterValues = processor->getParameterValues();
    processor->isPrepared = true;
    markNodeInitialized(nodeId, graphNode);
    addResult(makeNodeInitializationResult(nodeId, *prepareResult));
  } catch (const std::exception& error) {
    processor->isPrepared = false;
    addResult(makeNodeInitializationResult(nodeId, false, error.what()));
  }

  finishPendingNode();
}

void ProcessingGraphNodeInitializationSession::completeStateRestoration(int64_t nodeId,
    const std::weak_ptr<Node>& weakGraphNode,
    const std::weak_ptr<Processor>& weakProcessor,
    std::optional<std::string> error) {
  auto node = weakGraphNode.lock();
  auto processor = weakProcessor.lock();
  if (!isStillCurrentGraphNode(nodeId, node) || processor == nullptr) {
    completeProcessorNode(nodeId, weakGraphNode, weakProcessor, std::nullopt);
    return;
  }
  if (error) {
    processor->isPrepared = false;
    addResult(makeNodeInitializationResult(nodeId, false, *error));
    finishPendingNode();
    return;
  }

  processor->hasRestoredProjectState = true;
  // Restored state can change the bus layout. Report ports and values only
  // after the plugin has been prepared again with its saved state applied.
  try {
    processor->prepareToProcess([self = shared_from_this(), nodeId, weakGraphNode, weakProcessor](
                                    std::optional<ProcessorPrepareResult> result) {
      self->completeProcessorNode(nodeId, weakGraphNode, weakProcessor, std::move(result));
    });
  } catch (const std::exception& exception) {
    processor->isPrepared = false;
    addResult(makeNodeInitializationResult(nodeId, false, exception.what()));
    finishPendingNode();
  }
}

void ProcessingGraphNodeInitializationSession::initializeProcessorNode(
    const NodeInitializationWorkItem& workItem, const std::shared_ptr<Processor>& processor) {
  // Processor preparation is the initialization boundary. Successful nodes are
  // added to the tracker; failed nodes are left untracked so a later initialize
  // request can retry after the model or environment changes.
  try {
    auto weakGraphNode = std::weak_ptr<Node>(workItem.graphNode);
    auto weakProcessor = std::weak_ptr<Processor>(processor);

    pendingCount++;

    processor->prepareToProcess(
        [self = shared_from_this(), nodeId = workItem.nodeId, weakGraphNode, weakProcessor](
            std::optional<ProcessorPrepareResult> prepareResult) {
          self->completeProcessorNode(
              nodeId, weakGraphNode, weakProcessor, std::move(prepareResult));
        });
  } catch (const std::exception& e) {
    processor->isPrepared = false;
    addResult(makeNodeInitializationResult(workItem.nodeId, false, std::string(e.what())));
    pendingCount--;
  } catch (...) {
    processor->isPrepared = false;
    addResult(makeNodeInitializationResult(
        workItem.nodeId, false, "Unknown error while initializing processing graph node."));
    pendingCount--;
  }
}

void ProcessingGraphNodeInitializationSession::initializeNode(
    const NodeInitializationWorkItem& workItem) {
  initializeProcessorNode(workItem, workItem.graphNode->getProcessor());
}

void ProcessingGraphNodeInitializationSession::initializeDiff(
    ProcessingGraphInitializationDiff diff) {
  results.reserve(diff.immediateResults.size() + diff.nodesToInitialize.size());

  for (auto& result : diff.immediateResults) {
    addResult(std::move(result));
  }

  for (const auto& workItem : diff.nodesToInitialize) {
    initializeNode(workItem);
  }

  didFinishScheduling = true;
  maybeComplete();
}

void ProcessingGraphNodeInitializationSession::finishPendingNode() {
  pendingCount--;
  maybeComplete();
}

void ProcessingGraphNodeInitializationSession::maybeComplete() {
  if (!didFinishScheduling || pendingCount != 0 || didComplete) {
    return;
  }

  didComplete = true;
  complete(std::move(results));
}

void ProcessingGraphNodeInitializationSession::run() {
  if (!hasProcessingGraph()) {
    complete({});
    return;
  }

  pruneInitializedNodeTracker();
  initializeDiff(collectInitializationDiff());
}

} // namespace anthem
