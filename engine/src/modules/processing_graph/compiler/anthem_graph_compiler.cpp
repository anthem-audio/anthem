/*
  Copyright (C) 2024 Joshua Wade

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

#include <iostream>

std::shared_ptr<AnthemGraphCompilationResult> AnthemGraphCompiler::compile(AnthemGraphTopology& topology) {
  std::shared_ptr<AnthemGraphCompilationResult> result = std::make_shared<AnthemGraphCompilationResult>();

  // We store these in a vector so that when it goes out of scope, the nodes
  // are destroyed. We will store the actual pointers in a set, which improves
  // performance for large graphs.
  std::vector<std::shared_ptr<AnthemGraphCompilerNode>> vectorOfNodesToProcess;

  std::set<AnthemGraphCompilerNode*> nodesToProcess;

  std::map<AnthemGraphNode*, std::shared_ptr<AnthemGraphCompilerNode>> nodeToCompilerNode;
  std::map<AnthemGraphNodeConnection*, std::shared_ptr<AnthemGraphCompilerEdge>> connectionToCompilerEdge;

  std::cout
    << "\033[32m"
    << "AnthemGraphCompiler::compile(): Compiling graph with "
    << topology.getNodes().size()
    << (topology.getNodes().size() > 1 ? " nodes" : " node")
    << " and "
    << topology.getConnections().size()
    << (topology.getConnections().size() > 1 ? " connections" : " connection")
    << "\033[0m"
    << std::endl;

  for (auto& node : topology.getNodes()) {
    auto context = std::make_shared<AnthemProcessContext>(node);

    auto compilerNode = std::make_shared<AnthemGraphCompilerNode>(node, context);

    vectorOfNodesToProcess.push_back(compilerNode);
    nodeToCompilerNode[node.get()] = compilerNode;
    nodesToProcess.insert(compilerNode.get());
  }

  std::cout << vectorOfNodesToProcess.size() << " nodes to process" << std::endl;
  std::cout << std::endl;

  for (auto& node : vectorOfNodesToProcess) {
    node->assignEdges(nodeToCompilerNode, connectionToCompilerEdge);
  }

  std::shared_ptr<std::vector<std::shared_ptr<AnthemGraphCompilerAction>>> actions = std::make_shared<std::vector<std::shared_ptr<AnthemGraphCompilerAction>>>();

  std::cout << "Step 1: Zero input buffers" << std::endl;

  // Step 1: Zero input buffers
  for (auto& node : nodesToProcess) {
    actions->push_back(std::make_shared<ZeroInputBuffersAction>(node->context));
  }

  result->actionGroups.push_back(actions);

  std::cout << result->actionGroups.size() << " action groups" << std::endl;
  std::cout << std::endl;

  actions = std::make_shared<std::vector<std::shared_ptr<AnthemGraphCompilerAction>>>();

  // Step 2: Find nodes with no inputs and mark them as ready to process

  int i = 0;

  for (auto& node : nodesToProcess) {
    if (node->inputEdges.size() == 0) {
      i++;
      node->readyToProcess = true;
    }
  }

  std::cout << "Step 2: Found " << i << " nodes with no inputs" << std::endl;
  std::cout << std::endl;

  auto lastSize = SIZE_MAX;

  int j = 0;

  while (!nodesToProcess.empty()) {
    j++;
    std::cout << "\033[32mLoop iteration " << j << "\033[0m" << std::endl;
    std::cout << "Nodes still left to process: " << nodesToProcess.size() << std::endl;
    std::cout << "Last size: " << lastSize << std::endl;

    // This will make it easier to track down infinite loops
    jassert(lastSize != nodesToProcess.size());
    lastSize = nodesToProcess.size();

    std::vector<AnthemGraphCompilerNode*> nodesToRemoveFromProcessing;

    i = 0;

    // Step 3: Process nodes that are ready to process
    for (auto& node : nodesToProcess) {
      if (node->readyToProcess) {
        std::cout << "Processing node " << node->node->processor->config.getId() << std::endl;
        actions->push_back(std::make_shared<ProcessNodeAction>(node->context, node->node));
        nodesToRemoveFromProcessing.push_back(node);
        i++;
      }
    }

    std::cout << "Step 3: Added process actions for " << i << " nodes" << std::endl;

    result->actionGroups.push_back(actions);

    actions = std::make_shared<std::vector<std::shared_ptr<AnthemGraphCompilerAction>>>();

    std::cout << result->actionGroups.size() << " action groups" << std::endl;

    i = 0;

    // Remove processed nodes from the list of nodes to process
    for (auto& node : nodesToRemoveFromProcessing) {
      i++;
      nodesToProcess.erase(node);
    }

    std::cout << "Step 3: Removed " << i << " nodes from processing" << std::endl;
    std::cout << std::endl;

    i = 0;

    // Step 4: Process connections
    for (auto& node : nodesToRemoveFromProcessing) {
      for (auto& edge : node->outputEdges) {
        auto sourcePort = edge->edgeSource->source;
        auto destinationPort = edge->edgeSource->destination;

        switch (edge->type) {
          case AnthemGraphDataType::Audio:
            actions->push_back(
              std::make_shared<CopyAudioBufferAction>(
                edge->sourceNodeContext,
                sourcePort.lock()->index,
                edge->destinationNodeContext,
                destinationPort.lock()->index
              )
            );
            break;
          case AnthemGraphDataType::Midi:
            throw std::runtime_error("AnthemGraphCompiler::compile(): MIDI connections are not yet supported");
            break;
          case AnthemGraphDataType::Control:
            throw std::runtime_error("AnthemGraphCompiler::compile(): Control connections are not yet supported");
            break;
        }

        edge->processed = true;
        std::cout << "Marked edge with pointer " << std::hex << edge.get() << std::dec << " as processed" << std::endl;
        std::cout << "This compiler edge represents a real edge with pointer " << std::hex << edge->edgeSource.get() << std::dec << std::endl;
        i++;
      }
    }

    std::cout << "Step 4: Added " << i << " connection actions" << std::endl;
    std::cout << std::endl;

    result->actionGroups.push_back(actions);

    actions = std::make_shared<std::vector<std::shared_ptr<AnthemGraphCompilerAction>>>();

    // Step 5: Mark nodes with no unprocessed input connections as ready to process

    i = 0;

    for (auto& node : nodesToProcess) {
      bool allInputsProcessed = true;

      std::cout << "Checking node " << node->node->processor->config.getId() << std::endl;

      for (auto& edge : node->inputEdges) {
        std::cout << "This is an edge..." << std::endl;
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

    std::cout << "Step 5: Found " << i << " nodes with no unprocessed input connections" << std::endl;

    std::cout << "Restarting loop..." << std::endl;
    std::cout << std::endl;
  }

  return result;
}
