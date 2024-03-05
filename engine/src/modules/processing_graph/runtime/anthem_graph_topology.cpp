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

#include <stdexcept>

#include "anthem_graph_topology.h"

AnthemGraphTopology::AnthemGraphTopology() {
  nodes = std::vector<std::shared_ptr<AnthemGraphNode>>();
}

void AnthemGraphTopology::addNode(std::shared_ptr<AnthemGraphNode> processor) {
  nodes.push_back(processor);
}

void AnthemGraphTopology::addConnection(
  std::shared_ptr<AnthemGraphNodePort> source,
  std::shared_ptr<AnthemGraphNodePort> destination
) {
  // Check that source and destination have the same node type
  if (source->config->portType != destination->config->portType) {
    throw std::runtime_error(
      "AnthemGraphTopology::addConnection(): Source and destination nodes must have the same type"
    );
  }

  auto connection = std::make_shared<AnthemGraphNodeConnection>(
    source,
    destination
  );

  auto type = source->config->portType;

  switch(type) {
    case AnthemGraphDataType::Audio:
      audioPortConnections.push_back(connection);
      break;
    case AnthemGraphDataType::Midi:
      throw std::runtime_error("AnthemGraphTopology::addConnection(): MIDI connections are not yet supported");
      // midiPortConnections.push_back(connection);
      break;
    case AnthemGraphDataType::Control:
      throw std::runtime_error("AnthemGraphTopology::addConnection(): Control connections are not yet supported");
      // controlPortConnections.push_back(connection);
      break;
  }

  source->connections.push_back(connection);
  destination->connections.push_back(connection);
}

std::unique_ptr<AnthemGraphTopology> AnthemGraphTopology::clone() {
  auto newTopology = std::make_unique<AnthemGraphTopology>();
  for (auto node : nodes) {
    newTopology->addNode(node);
  }
  return newTopology;
}

std::vector<std::shared_ptr<AnthemGraphNode>>& AnthemGraphTopology::getNodes() {
  return nodes;
}

std::vector<std::shared_ptr<AnthemGraphNodeConnection>>& AnthemGraphTopology::getConnections() {
  return audioPortConnections;
}
