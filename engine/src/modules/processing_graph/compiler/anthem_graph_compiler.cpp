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

std::shared_ptr<AnthemGraphCompilationResult> AnthemGraphCompiler::compile(AnthemGraphTopology& topology) {
  std::shared_ptr<AnthemGraphCompilationResult> result = std::make_shared<AnthemGraphCompilationResult>();

  // We store these in a vector so that when it goes out of scope, the nodes
  // are destroyed. We will store the actual pointers in a set, which improves
  // performance for large graphs.
  std::vector<std::shared_ptr<AnthemGraphCompilerNode>> vectorOfNodesToProcess;

  std::set<AnthemGraphCompilerNode*> nodesToProcess;

  std::map<AnthemGraphNode*, std::shared_ptr<AnthemGraphCompilerNode>> nodeToCompilerNode;

  for (auto& node : topology.getNodes()) {
    auto context = std::make_shared<AnthemProcessContext>(node);

    auto compilerNode = std::make_shared<AnthemGraphCompilerNode>(node, context);

    vectorOfNodesToProcess.push_back(compilerNode);
    nodeToCompilerNode[node.get()] = compilerNode;
    nodesToProcess.insert(compilerNode.get());
  }

  for (auto& node : vectorOfNodesToProcess) {
    node->assignEdges(nodeToCompilerNode);
  }

  std::shared_ptr<std::vector<std::shared_ptr<AnthemGraphCompilerAction>>> actions;

  // Step 1: Zero input buffers
  for (auto& node : nodesToProcess) {
    actions->push_back(std::make_shared<ZeroInputBuffersAction>(node->context));
  }

  result->actionGroups.push_back(actions);

  actions = std::make_shared<std::vector<std::shared_ptr<AnthemGraphCompilerAction>>>();

  // Step 2: Find nodes with no inputs and mark them as ready to process

  for (auto& node : nodesToProcess) {
    if (node->inputEdges.size() == 0) {
      node->readyToProcess = true;
    }
  }

  auto lastSize = SIZE_MAX;

  while (!nodesToProcess.empty()) {
    // This will make it easier to track down infinite loops
    jassert(lastSize > nodesToProcess.size());
    lastSize = nodesToProcess.size();

    std::vector<AnthemGraphCompilerNode*> nodesToRemoveFromProcessing;

    // Step 3: Process nodes that are ready to process
    for (auto& node : nodesToProcess) {
      if (node->readyToProcess) {
        actions->push_back(std::make_shared<ProcessNodeAction>(node->context, node->node));
        nodesToRemoveFromProcessing.push_back(node);
      }
    }

    result->actionGroups.push_back(actions);

    actions = std::make_shared<std::vector<std::shared_ptr<AnthemGraphCompilerAction>>>();

    // Remove processed nodes from the list of nodes to process
    for (auto& node : nodesToProcess) {
      if (node->readyToProcess) {
        nodesToProcess.erase(node);
      }
    }

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
      }
    }

    result->actionGroups.push_back(actions);

    actions = std::make_shared<std::vector<std::shared_ptr<AnthemGraphCompilerAction>>>();

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

  return std::make_shared<AnthemGraphCompilationResult>();
}
