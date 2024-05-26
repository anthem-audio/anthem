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

#pragma once

#include <vector>
#include <memory>

#include "anthem_graph_node.h"
#include "anthem_graph_node_connection.h"

// This is a container for the processing graph. It holds nodes and their
// connections, and it can be cloned to create a new graph with the same
// structure.
//
// The graph lives on the main thread, and can be mutated at any time. Updates
// can be pushed to the audio thread via the graph compiler, which reads in this
// topology and produces an AnthemGraphCompilationResult. This compilation
// result contains the set of steps needed to actually process the graph, and is
// used on the audio thread by AnthemGraphProcessor.
class AnthemGraphTopology {
private:
  std::vector<std::shared_ptr<AnthemGraphNode>> nodes;
  std::vector<std::shared_ptr<AnthemGraphNodeConnection>> audioPortConnections;
public:
  AnthemGraphTopology();

  void addNode(std::shared_ptr<AnthemGraphNode> node);

  void removeNode(std::shared_ptr<AnthemGraphNode> node);

  void addConnection(
    std::shared_ptr<AnthemGraphNodePort> source,
    std::shared_ptr<AnthemGraphNodePort> destination
  );

  void removeConnection(
    std::shared_ptr<AnthemGraphNodePort> source,
    std::shared_ptr<AnthemGraphNodePort> destination
  );

  std::vector<std::shared_ptr<AnthemGraphNode>>& getNodes();
  std::vector<std::shared_ptr<AnthemGraphNodeConnection>>& getConnections();
};
