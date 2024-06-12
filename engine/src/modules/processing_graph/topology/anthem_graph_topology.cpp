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

void AnthemGraphTopology::removeNode(std::shared_ptr<AnthemGraphNode> processor) {
  // For each input port, remove all connections
  for (auto port : processor->audioInputs) {
    for (auto connection : port->connections) {
      removeConnection(connection->source.lock(), connection->destination.lock());
    }
  }

  // For each output port, remove all connections
  for (auto port : processor->audioOutputs) {
    for (auto connection : port->connections) {
      removeConnection(connection->source.lock(), connection->destination.lock());
    }
  }

  // Remove the processor from the list of nodes
  nodes.erase(
    std::remove_if(
      nodes.begin(),
      nodes.end(),
      [processor](std::shared_ptr<AnthemGraphNode> node) {
        return node == processor;
      }
    ),
    nodes.end()
  );
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

void AnthemGraphTopology::removeConnection(
  std::shared_ptr<AnthemGraphNodePort> source,
  std::shared_ptr<AnthemGraphNodePort> destination
) {
  // Check that source and destination have the same node type
  if (source->config->portType != destination->config->portType) {
    throw std::runtime_error(
      "AnthemGraphTopology::removeConnection(): Source and destination nodes must have the same type"
    );
  }

  auto type = source->config->portType;

  switch(type) {
    case AnthemGraphDataType::Audio:
      audioPortConnections.erase(
        std::remove_if(
          audioPortConnections.begin(),
          audioPortConnections.end(),
          [source, destination](std::shared_ptr<AnthemGraphNodeConnection> connection) {
            return connection->source.lock() == source && connection->destination.lock() == destination;
          }
        ),
        audioPortConnections.end()
      );
      break;
    case AnthemGraphDataType::Midi:
      throw std::runtime_error("AnthemGraphTopology::removeConnection(): MIDI connections are not yet supported");
      // midiPortConnections.erase(
      //   std::remove_if(
      //     midiPortConnections.begin(),
      //     midiPortConnections.end(),
      //     [source, destination](std::shared_ptr<AnthemGraphNodeConnection> connection) {
      //       return connection->source == source && connection->destination == destination;
      //     }
      //   ),
      //   midiPortConnections.end()
      // );
      break;
    case AnthemGraphDataType::Control:
      throw std::runtime_error("AnthemGraphTopology::removeConnection(): Control connections are not yet supported");
      // controlPortConnections.erase(
      //   std::remove_if(
      //     controlPortConnections.begin(),
      //     controlPortConnections.end(),
      //     [source, destination](std::shared_ptr<AnthemGraphNodeConnection> connection) {
      //       return connection->source == source && connection->destination == destination;
      //     }
      //   ),
      //   controlPortConnections.end()
      // );
      break;
  }

  source->connections.erase(
    std::remove_if(
      source->connections.begin(),
      source->connections.end(),
      [source, destination](std::shared_ptr<AnthemGraphNodeConnection> connection) {
        return connection->source.lock() == source && connection->destination.lock() == destination;
      }
    ),
    source->connections.end()
  );

  destination->connections.erase(
    std::remove_if(
      destination->connections.begin(),
      destination->connections.end(),
      [source, destination](std::shared_ptr<AnthemGraphNodeConnection> connection) {
        return connection->source.lock() == source && connection->destination.lock() == destination;
      }
    ),
    destination->connections.end()
  );
}

std::vector<std::shared_ptr<AnthemGraphNode>>& AnthemGraphTopology::getNodes() {
  return nodes;
}

std::vector<std::shared_ptr<AnthemGraphNodeConnection>>& AnthemGraphTopology::getConnections() {
  return audioPortConnections;
}
