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

#include <string>

#include "anthem_graph.h"

// This class is used to generate a Graphviz file from an AnthemGraph. It can be
// used to visualize the graph for debugging purposes.
//
// Example usage:
//
//   std::cout << GenerateGraphVisFromGraph::generate(*processingGraph) << std::endl;
//
// This will print a Graphviz file to the console. This graph can be loaded into
// a Graphviz viewer like GraphvizOnline to visualize the graph.
//
// https://dreampuf.github.io/GraphvizOnline/
class GenerateGraphVisFromGraph {
public:
  static std::string generate(AnthemGraph& graph);
private:
  static std::string getIdFromNode(std::shared_ptr<AnthemGraphNode> node);
  static std::string getIdFromEdge(std::shared_ptr<AnthemGraphNodeConnection> connection);
};
