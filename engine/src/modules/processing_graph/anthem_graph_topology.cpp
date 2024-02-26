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

#include "anthem_graph_topology.h"

AnthemGraphTopology::AnthemGraphTopology() {
  nodes = std::vector<std::shared_ptr<AnthemGraphNode>>();
}

void AnthemGraphTopology::addNode(std::shared_ptr<AnthemGraphNode> processor) {
  nodes.push_back(processor);
}

std::unique_ptr<AnthemGraphTopology> AnthemGraphTopology::clone() {
  auto newTopology = std::make_unique<AnthemGraphTopology>();
  for (auto node : nodes) {
    newTopology->addNode(node);
  }
  return newTopology;
}
