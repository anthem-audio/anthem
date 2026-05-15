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

#include <exception>
#include <memory>
#include <optional>
#include <string>
#include <utility>
#include <vector>

namespace anthem {

namespace {
std::shared_ptr<ProcessingGraphNodeInitializationResult> makeNodeInitializationResult(
    int64_t nodeId,
    bool success,
    std::optional<std::string> error = std::nullopt,
    std::optional<std::shared_ptr<ProcessingGraphNodePortConfiguration>> portConfiguration =
        std::nullopt) {
  return std::make_shared<ProcessingGraphNodeInitializationResult>(
      ProcessingGraphNodeInitializationResult{
          .nodeId = nodeId,
          .success = success,
          .error = std::move(error),
          .portConfiguration = std::move(portConfiguration),
      });
}

std::shared_ptr<ProcessingGraphPortConfiguration> makePortConfiguration(
    const ProcessorPortConfiguration& portConfiguration) {
  return std::make_shared<ProcessingGraphPortConfiguration>(ProcessingGraphPortConfiguration{
      .id = portConfiguration.id,
      .name = portConfiguration.name,
      .channelCount = portConfiguration.channelCount,
      .parameterDefaultValue = portConfiguration.parameterDefaultValue,
  });
}

std::shared_ptr<std::vector<std::shared_ptr<ProcessingGraphPortConfiguration>>>
makePortConfigurationList(const std::vector<ProcessorPortConfiguration>& portConfigurations) {
  auto result = std::make_shared<std::vector<std::shared_ptr<ProcessingGraphPortConfiguration>>>();
  result->reserve(portConfigurations.size());

  for (const auto& portConfiguration : portConfigurations) {
    result->push_back(makePortConfiguration(portConfiguration));
  }

  return result;
}

std::shared_ptr<ProcessingGraphNodePortConfiguration> makeNodePortConfiguration(
    const ProcessorNodePortConfiguration& portConfiguration) {
  return std::make_shared<ProcessingGraphNodePortConfiguration>(
      ProcessingGraphNodePortConfiguration{
          .audioInputPorts = makePortConfigurationList(portConfiguration.audioInputPorts),
          .audioOutputPorts = makePortConfigurationList(portConfiguration.audioOutputPorts),
          .eventInputPorts = makePortConfigurationList(portConfiguration.eventInputPorts),
          .eventOutputPorts = makePortConfigurationList(portConfiguration.eventOutputPorts),
          .controlInputPorts = makePortConfigurationList(portConfiguration.controlInputPorts),
          .controlOutputPorts = makePortConfigurationList(portConfiguration.controlOutputPorts),
      });
}

std::shared_ptr<ProcessingGraphNodeInitializationResult> makeNodeInitializationResult(
    int64_t nodeId, const ProcessorPrepareResult& prepareResult) {
  std::optional<std::shared_ptr<ProcessingGraphNodePortConfiguration>> portConfiguration =
      std::nullopt;

  if (prepareResult.portConfiguration.has_value()) {
    portConfiguration = makeNodePortConfiguration(*prepareResult.portConfiguration);
  }

  return makeNodeInitializationResult(
      nodeId, prepareResult.success, prepareResult.error, std::move(portConfiguration));
}
} // namespace

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
        auto processor = initializedNode->getProcessor();
        if (processor.has_value()) {
          processor.value()->isPrepared = false;
        }
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

void ProcessingGraphNodeInitializationSession::initializeNodeWithoutProcessor(
    const NodeInitializationWorkItem& workItem) {
  // A graph node without a processor has no process preparation step, but it
  // still participates in delta tracking so it won't be reported as new on
  // every initialization request.
  markNodeInitialized(workItem.nodeId, workItem.graphNode);
  addResult(makeNodeInitializationResult(workItem.nodeId, true));
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

  if (!prepareResult.has_value()) {
    processor->isPrepared = true;
    markNodeInitialized(nodeId, graphNode);
    addResult(makeNodeInitializationResult(nodeId, true));
  } else if (prepareResult->success) {
    processor->isPrepared = true;
    markNodeInitialized(nodeId, graphNode);
    addResult(makeNodeInitializationResult(nodeId, *prepareResult));
  } else {
    processor->isPrepared = false;
    addResult(makeNodeInitializationResult(nodeId, *prepareResult));
  }

  finishPendingNode();
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
  auto processor = workItem.graphNode->getProcessor();
  if (!processor.has_value()) {
    initializeNodeWithoutProcessor(workItem);
    return;
  }

  initializeProcessorNode(workItem, processor.value());
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
