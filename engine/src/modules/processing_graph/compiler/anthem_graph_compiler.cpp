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

#include "anthem_graph_compiler.h"

#include "modules/core/anthem.h"

#include "generated/lib/model/model.h"

#include <iostream>

// See the header file for an overview of the graph processing algorithm. Each
// step in the algorithm is annotated here.

AnthemGraphCompilationResult* AnthemGraphCompiler::compile() {
  auto* currentDevice = Anthem::getInstance().audioDeviceManager.getCurrentAudioDevice();
  jassert(currentDevice != nullptr);

  auto sampleRate = currentDevice->getCurrentSampleRate();

  auto& processingGraphModel = Anthem::getInstance().project->processingGraph();

  AnthemGraphCompilationResult* result = new AnthemGraphCompilationResult();

  // We store these in a vector so that when it goes out of scope, the nodes
  // are destroyed. We will store the actual pointers in a set, which improves
  // performance for large graphs.
  std::vector<std::shared_ptr<AnthemGraphCompilerNode>> vectorOfNodesToProcess;

  std::set<AnthemGraphCompilerNode*> nodesToProcess;

  std::map<Node*, std::shared_ptr<AnthemGraphCompilerNode>> nodeToCompilerNode;
  std::map<NodeConnection*, std::shared_ptr<AnthemGraphCompilerEdge>> connectionToCompilerEdge;

  std::cout
    << "\033[32m"
    << "AnthemGraphCompiler::compile(): Compiling graph with "
    << processingGraphModel->nodes()->size()
    << (processingGraphModel->nodes()->size() > 1 ? " nodes" : " node")
    << " and "
    << processingGraphModel->connections()->size()
    << (processingGraphModel->connections()->size() > 1 ? " connections" : " connection")
    << "\033[0m"
    << std::endl;

  size_t totalEventPorts = 0;

  // Get the total number of event ports in the graph.
  for (auto& nodePair : *processingGraphModel->nodes()) {
    auto& node = nodePair.second;
    totalEventPorts += node->eventInputPorts()->size();
    totalEventPorts += node->eventOutputPorts()->size();
  }

  // Create a buffer allocator for events, and allocate double the size of the
  // buffer for each port. This is because if any port buffer overflows, it will
  // reallocate, so we need some free space.
  //
  // This is probably way too much free space, but I won't try to tweak it
  // unless it becomes a problem.
  result->eventAllocator = 
    std::make_unique<ArenaBufferAllocator<AnthemLiveEvent>>(
      totalEventPorts * DEFAULT_EVENT_BUFFER_SIZE * sizeof(AnthemLiveEvent) * 2
    );

  // Create contexts for each node
  for (auto& pair : *processingGraphModel->nodes()) {
    auto& node = pair.second;

    auto context = new AnthemProcessContext(node, result->eventAllocator.get());
    result->processContexts.push_back(std::unique_ptr<AnthemProcessContext>(context));

    result->graphNodes.push_back(node);

    auto compilerNode = std::make_shared<AnthemGraphCompilerNode>(node, context);

    node->runtimeContext = std::make_optional(context);

    vectorOfNodesToProcess.push_back(compilerNode);
    nodeToCompilerNode[node.get()] = compilerNode;
    nodesToProcess.insert(compilerNode.get());
  }

  std::cout << vectorOfNodesToProcess.size() << " nodes to process" << std::endl;
  std::cout << std::endl;

  for (auto& node : vectorOfNodesToProcess) {
    node->assignEdges(nodeToCompilerNode, connectionToCompilerEdge);
  }

  std::unique_ptr<std::vector<std::unique_ptr<AnthemGraphCompilerAction>>> actions =
        std::make_unique<std::vector<std::unique_ptr<AnthemGraphCompilerAction>>>();

  juce::Logger::writeToLog("Step 1: Zero input buffers");

  // Step 1 (part 1): Clear buffers
  //
  // Before starting, we add an action that writes zeros to all audio input
  // buffers. If no inputs are present at an audio input port, then the input
  // for that port should be silence (e.g. all zeros), as opposed to either
  // garbage data or the data from the last block.
  //
  // This will also clear all event buffers, which are used for MIDI and other
  // event data. This is important because if an event buffer is not cleared,
  // then the event data from the last block will be processed again, which
  // could cause duplicate notes to be played, or other odd behavior.
  //
  // Note that this does not do anything to contorl input buffers. In Anthem,
  // control values are audio-rate sampled data, but unlike audio input ports,
  // each control input port has a corresponding parameter definition that has a
  // current value, and the control value is initialized with that current value
  // instead. See below for more.

  for (auto& node : nodesToProcess) {
    actions->push_back(
      std::move(std::make_unique<ClearBuffersAction>(node->context))
    );
  }

  result->actionGroups.push_back(std::move(actions));

  actions = std::make_unique<std::vector<std::unique_ptr<AnthemGraphCompilerAction>>>();

  // Step 1 (part 2): Initialize control input buffers with corresponding
  // parameter values.
  //
  // Unlike audio inputs, control inputs always have a corresponding parameter
  // definition, which provides a default value, and a parameter instance, which
  // provides the current value. This action writes the current value from each
  // parameter to the input buffer for each control input. If there is a
  // connection to a given contorl input, then the value from that connection
  // will overwrite the parameter value in a future step.
  //
  // We don't skip this step for control input ports that have attached inputs,
  // though we probably could. It's not necessarily trivial to skip though,
  // because the control value is smoothed in this step, and not processing the
  // smoother could produce odd behavior when connections are made or destroyed.

  for (auto& node : nodesToProcess) {
    actions->push_back(
      std::make_unique<WriteParametersToControlInputsAction>(node->context, sampleRate)
    );
  }

  result->actionGroups.push_back(std::move(actions));

  actions = std::make_unique<std::vector<std::unique_ptr<AnthemGraphCompilerAction>>>();

  std::cout << result->actionGroups.size() << " action groups" << std::endl;
  std::cout << std::endl;

  // Step 2: Find nodes with no inputs and mark them as ready to process

  int i = 0;

  for (auto& node : nodesToProcess) {
    if (node->inputEdges.size() == 0) {
      i++;
      node->readyToProcess = true;
    }
  }

  juce::Logger::writeToLog("Step 2: Found " + std::to_string(i) + " nodes with no inputs");
  std::cout << std::endl;

  auto lastSize = SIZE_MAX;

  int j = 0;

  while (!nodesToProcess.empty()) {
    j++;
    juce::Logger::writeToLog("\033[32mLoop iteration " + std::to_string(j) + "\033[0m");
    std::cout << "Nodes still left to process: " << std::to_string(nodesToProcess.size()) << std::endl;
    std::cout << "Last size: " << std::to_string(lastSize) << std::endl;

    // If there's an infinite loop, throw an error. This should never happen,
    // and a bug that causes an infinite loop here would prevent the engine from
    // being shut down. This is a safety check to prevent that.
    if (lastSize == nodesToProcess.size()) {
      throw std::runtime_error("Infinite loop detected in graph compiler");
    }

    lastSize = nodesToProcess.size();

    std::vector<AnthemGraphCompilerNode*> nodesToRemoveFromProcessing;

    i = 0;

    // Step 3: Process nodes that are ready to process
    for (auto& node : nodesToProcess) {
      if (node->readyToProcess) {
        std::cout << "Processing node " << node->node->id() << std::endl;

        nodesToRemoveFromProcessing.push_back(node);
        i++;

        auto processor = node->node->getProcessor();
        if (!processor.has_value()) {
          std::cout << "Error: Node " << node->node->id() << " has no processor." << std::endl;
          continue;
        }

        actions->push_back(std::make_unique<ProcessNodeAction>(node->context, processor.value().get()));
      }
    }

    juce::Logger::writeToLog("Step 3: Added process actions for " + std::to_string(i) + " nodes");

    result->actionGroups.push_back(std::move(actions));

    actions = std::make_unique<std::vector<std::unique_ptr<AnthemGraphCompilerAction>>>();

    std::cout << result->actionGroups.size() << " action groups" << std::endl;

    i = 0;

    // Remove processed nodes from the list of nodes to process
    for (auto& node : nodesToRemoveFromProcessing) {
      i++;
      nodesToProcess.erase(node);
    }

    juce::Logger::writeToLog("Step 3: Removed " + std::to_string(i) + " nodes from processing");
    std::cout << std::endl;

    i = 0;

    // Step 4: Process connections
    for (auto& node : nodesToRemoveFromProcessing) {
      for (auto& edge : node->outputEdges) {
        auto& sourceNodeId = edge->edgeSource->sourceNodeId();
        auto& destinationNodeId = edge->edgeSource->destinationNodeId();
        auto& sourcePortId = edge->edgeSource->sourcePortId();
        auto& destinationPortId = edge->edgeSource->destinationPortId();

        auto& sourceNode = processingGraphModel->nodes()->at(sourceNodeId);
        auto& destinationNode = processingGraphModel->nodes()->at(destinationNodeId);

        auto sourcePortResult = sourceNode->getPortById(sourcePortId);
        auto destinationPortResult = destinationNode->getPortById(destinationPortId);

        if (!sourcePortResult.has_value() || !destinationPortResult.has_value()) {
          std::cout << "Error: Could not find source or destination port" << std::endl;
          continue;
        }

        auto& sourcePort = sourcePortResult.value();
        auto& destinationPort = destinationPortResult.value();

        switch (edge->type) {
          case NodePortDataType::audio:
            actions->push_back(
              std::make_unique<CopyAudioBufferAction>(
                edge->sourceNodeContext,
                sourcePort->id(),
                edge->destinationNodeContext,
                destinationPort->id()
              )
            );
            break;
          case NodePortDataType::event:
            actions->push_back(
              std::make_unique<CopyEventsAction>(
                edge->sourceNodeContext,
                sourcePort->id(),
                edge->destinationNodeContext,
                destinationPort->id()
              )
            );
            break;
          case NodePortDataType::control:
            auto& portParameterConfig = sourcePort->config()->parameterConfig().value();
            auto minParameterValue = (float) portParameterConfig->minimumValue();
            auto maxParameterValue = (float) portParameterConfig->maximumValue();

            actions->push_back(
              std::make_unique<CopyControlBufferAction>(
                edge->sourceNodeContext,
                sourcePort->id(),
                edge->destinationNodeContext,
                destinationPort->id(),
                minParameterValue,
                maxParameterValue
              )
            );
            break;
        }

        edge->processed = true;
        i++;
      }
    }

    juce::Logger::writeToLog("Step 4: Added " + std::to_string(i) + " connection actions");
    std::cout << std::endl;

    result->actionGroups.push_back(std::move(actions));

    actions = std::make_unique<std::vector<std::unique_ptr<AnthemGraphCompilerAction>>>();

    // Step 5: Mark nodes with no unprocessed input connections as ready to process

    i = 0;

    for (auto& node : nodesToProcess) {
      bool allInputsProcessed = true;

      std::cout << "Checking node " << node->node->id() << std::endl;

      for (auto& edge : node->inputEdges) {
        if (!edge->processed) {
          std::cout << "\033[34m";
          std::cout << "Found unprocessed edge with pointer " << std::hex << edge.get() << std::dec << std::endl;
          std::cout << "This compiler edge represents a real edge with pointer " << std::hex << edge->edgeSource.get() << std::dec << std::endl;
          std::cout << "\033[0m";
          allInputsProcessed = false;
          break;
        }
      }

      if (allInputsProcessed) {
        i++;
        node->readyToProcess = true;
      }
    }

    juce::Logger::writeToLog("Step 5: Found " + std::to_string(i) + " nodes with no unprocessed input connections");

    juce::Logger::writeToLog("Restarting loop...");
    std::cout << std::endl;
  }

  return result;
}
