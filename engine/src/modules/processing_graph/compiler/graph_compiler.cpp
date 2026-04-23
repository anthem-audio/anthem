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

#include "graph_compiler.h"

#include "modules/processing_graph/compiler/node_process_context.h"
#include "modules/processing_graph/runtime/graph_runtime_services.h"

/*
  Steps to compile a processing graph:

  1. Append initialization actions for every node. This clears the relevant
     buffers and writes parameter values to control inputs.
  2. Find all nodes that have no incoming connections. These are the "root"
     nodes of the graph. Mark these as ready to process.
  3. Append process actions for all nodes that are ready to process.
  4. Append copy actions for the outgoing connections of the nodes that were
     just processed.
     Note: this phase is serialized today. If it is ever parallelized, fan-in
     needs special care because multiple connections may target the same
     destination buffer, and audio copies sum into that destination.
  5. Find all remaining nodes whose incoming connections are now all processed.
     Mark these as ready to process.
  6. Repeat steps 3-5 until all nodes are marked as processed.

  All steps are commented below.
*/

namespace anthem {

GraphCompilationResult* GraphCompiler::compile(const GraphCompileRequest& request) {
  auto result = std::make_unique<GraphCompilationResult>();
  result->sampleRate = static_cast<float>(request.sampleRate);
  result->graphProcessContext =
      std::make_unique<GraphProcessContext>(request.rtServices, request.bufferLayout);

  size_t totalAudioBufferCount = 0;
  size_t totalControlBufferCount = 0;
  size_t totalEventBufferCount = 0;
  for (auto& pair : request.nodes) {
    auto& node = pair.second;
    totalAudioBufferCount += node->audioInputPorts()->size() + node->audioOutputPorts()->size();
    totalControlBufferCount +=
        node->controlInputPorts()->size() + node->controlOutputPorts()->size();
    totalEventBufferCount += node->eventInputPorts()->size() + node->eventOutputPorts()->size();
  }
  result->graphProcessContext->reserve(
      request.nodes.size(), totalAudioBufferCount, totalControlBufferCount, totalEventBufferCount);
  result->actions.reserve(request.nodes.size() * 3 + request.connections.size());

  // We store these in a vector so that when it goes out of scope, the nodes
  // are destroyed. We will store the actual pointers in a set, which improves
  // performance for large graphs.
  std::vector<std::shared_ptr<GraphCompilerNode>> vectorOfNodesToProcess;

  std::set<GraphCompilerNode*> nodesToProcess;

  std::map<Node*, std::shared_ptr<GraphCompilerNode>> nodeToCompilerNode;
  std::map<NodeConnection*, std::shared_ptr<GraphCompilerEdge>> connectionToCompilerEdge;

  // Create contexts for each node
  for (auto& pair : request.nodes) {
    auto& node = pair.second;

    auto& context = result->graphProcessContext->createNodeProcessContext(node);

    result->graphNodes.push_back(node);

    auto compilerNode = std::make_shared<GraphCompilerNode>(node, &context);

    node->runtimeContext = std::make_optional(&context);

    vectorOfNodesToProcess.push_back(compilerNode);
    nodeToCompilerNode[node.get()] = compilerNode;
    nodesToProcess.insert(compilerNode.get());
  }

  for (auto& node : vectorOfNodesToProcess) {
    node->assignEdges(
        request.nodes, request.connections, nodeToCompilerNode, connectionToCompilerEdge);
  }

  auto addClearBuffersAction = [&](NodeProcessContext* context) {
    result->actions.push_back(GraphAction::makeClearBuffers(context));
  };

  auto addWriteParametersToControlInputsAction = [&](NodeProcessContext* context) {
    result->actions.push_back(GraphAction::makeWriteParametersToControlInputs(context));
  };

  auto addProcessNodeAction = [&](NodeProcessContext* context, Processor* processor) {
    result->actions.push_back(GraphAction::makeProcessNode(context, processor));
  };

  auto addCopyAudioBufferAction = [&](NodeProcessContext* sourceContext,
                                      int64_t sourcePortId,
                                      NodeProcessContext* destinationContext,
                                      int64_t destinationPortId) {
    result->actions.push_back(GraphAction::makeCopyAudioBuffer(
        sourceContext->getBufferIndex(
            NodePortDataType::audio, NodeProcessContext::BufferDirection::output, sourcePortId),
        destinationContext->getBufferIndex(NodePortDataType::audio,
            NodeProcessContext::BufferDirection::input,
            destinationPortId)));
  };

  auto addCopyEventsAction = [&](NodeProcessContext* sourceContext,
                                 int64_t sourcePortId,
                                 NodeProcessContext* destinationContext,
                                 int64_t destinationPortId) {
    result->actions.push_back(GraphAction::makeCopyEvents(
        sourceContext->getBufferIndex(
            NodePortDataType::event, NodeProcessContext::BufferDirection::output, sourcePortId),
        destinationContext->getBufferIndex(NodePortDataType::event,
            NodeProcessContext::BufferDirection::input,
            destinationPortId)));
  };

  auto addCopyControlBufferAction = [&](NodeProcessContext* sourceContext,
                                        int64_t sourcePortId,
                                        NodeProcessContext* destinationContext,
                                        int64_t destinationPortId) {
    result->actions.push_back(GraphAction::makeCopyControlBuffer(
        sourceContext->getBufferIndex(
            NodePortDataType::control, NodeProcessContext::BufferDirection::output, sourcePortId),
        destinationContext->getBufferIndex(NodePortDataType::control,
            NodeProcessContext::BufferDirection::input,
            destinationPortId)));
  };

  // Step 1 (part 1): Clear buffers
  //
  // Before starting, we append an action that writes zeros to all audio input
  // buffers. If no inputs are present at an audio input port, then the input
  // for that port should be silence (e.g. all zeros), as opposed to either
  // garbage data or the data from the last block.
  //
  // This will also clear all event buffers, which are used for MIDI and other
  // event data. This is important because if an event buffer is not cleared,
  // then the event data from the last block will be processed again, which
  // could cause duplicate notes to be played, or other odd behavior.
  //
  // Note that this does not do anything to control input buffers. In Anthem,
  // control values are audio-rate sampled data, but unlike audio input ports,
  // each control input port has a corresponding parameter definition that has a
  // current value, and the control value is initialized with that current value
  // instead. See below for more.

  for (auto& node : nodesToProcess) {
    addClearBuffersAction(node->context);
  }

  // Step 1 (part 2): Initialize control input buffers with corresponding
  // parameter values.
  //
  // Unlike audio inputs, control inputs always have a corresponding parameter
  // definition, which provides a default value, and a parameter instance, which
  // provides the current value. This action writes the current value from each
  // parameter to the input buffer for each control input. If there is a
  // connection to a given control input, then the value from that connection
  // will overwrite the parameter value in a future step.
  //
  // We don't skip this step for control input ports that have attached inputs,
  // though we probably could. It's not necessarily trivial to skip though,
  // because the control value is smoothed in this step, and not processing the
  // smoother could produce odd behavior when connections are made or destroyed.

  for (auto& node : nodesToProcess) {
    addWriteParametersToControlInputsAction(node->context);
  }

  // Step 2: Find nodes with no inputs and mark them as ready to process

  for (auto& node : nodesToProcess) {
    if (node->inputEdges.size() == 0) {
      node->readyToProcess = true;
    }
  }

  auto lastSize = SIZE_MAX;

  while (!nodesToProcess.empty()) {
    // If there's an infinite loop, throw an error. This should never happen,
    // and a bug that causes an infinite loop here would prevent the engine from
    // being shut down. This is a safety check to prevent that.
    if (lastSize == nodesToProcess.size()) {
      throw std::runtime_error("Infinite loop detected in graph compiler");
    }

    lastSize = nodesToProcess.size();

    std::vector<GraphCompilerNode*> nodesToRemoveFromProcessing;

    // Step 3: Append process actions for nodes that are ready to process
    for (auto& node : nodesToProcess) {
      if (node->readyToProcess) {
        nodesToRemoveFromProcessing.push_back(node);

        auto processor = node->node->getProcessor();
        if (!processor.has_value()) {
          continue;
        }

        addProcessNodeAction(node->context, processor.value().get());
      }
    }

    // Remove processed nodes from the list of nodes to process
    for (auto& node : nodesToRemoveFromProcessing) {
      nodesToProcess.erase(node);
    }

    // Step 4: Append connection-copy actions
    for (auto& node : nodesToRemoveFromProcessing) {
      for (auto& edge : node->outputEdges) {
        auto& sourceNodeId = edge->edgeSource->sourceNodeId();
        auto& destinationNodeId = edge->edgeSource->destinationNodeId();
        auto& sourcePortId = edge->edgeSource->sourcePortId();
        auto& destinationPortId = edge->edgeSource->destinationPortId();

        auto& sourceNode = request.nodes.at(sourceNodeId);
        auto& destinationNode = request.nodes.at(destinationNodeId);

        auto sourcePortResult = sourceNode->getPortById(sourcePortId);
        auto destinationPortResult = destinationNode->getPortById(destinationPortId);

        if (!sourcePortResult.has_value() || !destinationPortResult.has_value()) {
          continue;
        }

        auto& sourcePort = sourcePortResult.value();
        auto& destinationPort = destinationPortResult.value();

        switch (edge->type) {
          case NodePortDataType::audio:
            addCopyAudioBufferAction(edge->sourceNodeContext,
                sourcePort->id(),
                edge->destinationNodeContext,
                destinationPort->id());
            break;
          case NodePortDataType::event:
            addCopyEventsAction(edge->sourceNodeContext,
                sourcePort->id(),
                edge->destinationNodeContext,
                destinationPort->id());
            break;
          case NodePortDataType::control:
            addCopyControlBufferAction(edge->sourceNodeContext,
                sourcePort->id(),
                edge->destinationNodeContext,
                destinationPort->id());
            break;
        }

        edge->processed = true;
      }
    }

    // Step 5: Mark nodes with no unprocessed input connections as ready to process

    for (auto& node : nodesToProcess) {
      bool allInputsProcessed = true;

      for (auto& edge : node->inputEdges) {
        if (!edge->processed) {
          allInputsProcessed = false;
          break;
        }
      }

      if (allInputsProcessed) {
        node->readyToProcess = true;
      }
    }
  }

  return result.release();
}

} // namespace anthem
