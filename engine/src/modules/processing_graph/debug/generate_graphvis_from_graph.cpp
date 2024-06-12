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

#include "generate_graphvis_from_graph.h"

std::string GenerateGraphVisFromGraph::generate(AnthemGraph& graph) {
  std::string result = "";

  // Start graph
  result += "digraph G {\n";

  result += "  rankdir=LR;\n";
  result += "  node [style=filled];\n";
  result += "\n";
  
  result += "  # Graph nodes\n";
  result += "\n";

  auto topology = graph.getTopology();

  // For each node in the graph, write a node to the file
  for (auto node : topology.getNodes()) {
    auto id = GenerateGraphVisFromGraph::getIdFromNode(node);
    result += "  " + id + " [label=\"" + node->processor->config.getId() + "\"];\n";
  }

  result += "\n";
  result += "  # Graph edges\n";
  result += "\n";

  // For each edge in the graph, write an edge to the file
  for (auto connection : topology.getConnections()) {
    auto id = GenerateGraphVisFromGraph::getIdFromEdge(connection);
    auto sourceId = GenerateGraphVisFromGraph::getIdFromNode(connection->source.lock()->node.lock());
    auto destinationId = GenerateGraphVisFromGraph::getIdFromNode(connection->destination.lock()->node.lock());
    result += "  " + sourceId + " -> " + destinationId + ";\n";
  }

  // End graph
  result += "}\n";

  return result;
}

std::string GenerateGraphVisFromGraph::getIdFromNode(std::shared_ptr<AnthemGraphNode> node) {
  auto ptr = node.get();
  return std::to_string(reinterpret_cast<intptr_t>(ptr));
}

std::string GenerateGraphVisFromGraph::getIdFromEdge(std::shared_ptr<AnthemGraphNodeConnection> connection) {
  auto ptr = connection.get();
  return std::to_string(reinterpret_cast<intptr_t>(ptr));
}
