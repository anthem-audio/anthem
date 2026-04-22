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

#pragma once

#include "modules/processing_graph/compiler/graph_compiler_edge.h"
#include "modules/processing_graph/model/node.h"

#include <juce_core/juce_core.h>
#include <map>
#include <memory>
#include <vector>

namespace anthem {

class GraphNode;
class NodeProcessContext;

// Represents a node in the compiler. Used internally by the compiler to keep
// track of details about nodes being processed.
class GraphCompilerNode {
public:
  using NodeMap = ModelUnorderedMap<int64_t, std::shared_ptr<Node>>;
  using ConnectionMap = ModelUnorderedMap<int64_t, std::shared_ptr<NodeConnection>>;

  // The node that this compiled node represents
  std::shared_ptr<Node> node;

  std::vector<std::shared_ptr<GraphCompilerEdge>> inputEdges;
  std::vector<std::shared_ptr<GraphCompilerEdge>> outputEdges;

  // The runtime context for this node
  NodeProcessContext* context;

  // Whether this node is ready to process
  bool readyToProcess = false;

  GraphCompilerNode(std::shared_ptr<Node> node, NodeProcessContext* context)
    : node(node), context(context) {}

  // Populate the input and output edges for this node
  void assignEdges(const NodeMap& nodes,
      const ConnectionMap& connections,
      std::map<Node*, std::shared_ptr<GraphCompilerNode>>& nodeToCompilerNode,
      std::map<NodeConnection*, std::shared_ptr<GraphCompilerEdge>>& connectionToCompilerEdge);
private:
  void assignEdge(const NodeMap& nodes,
      std::map<Node*, std::shared_ptr<GraphCompilerNode>>& nodeToCompilerNode,
      std::map<NodeConnection*, std::shared_ptr<GraphCompilerEdge>>& connectionToCompilerEdge,
      std::vector<std::shared_ptr<GraphCompilerEdge>>& edgeContainer,
      const std::shared_ptr<NodeConnection>& connection);

  JUCE_LEAK_DETECTOR(GraphCompilerNode)
};

} // namespace anthem
