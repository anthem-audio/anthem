/*
  Copyright (C) 2026 Joshua Wade

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

import 'package:mobx/mobx.dart';

import 'node.dart';
import 'node_connection.dart';

part 'processing_graph.g.dart';

// ignore: library_private_types_in_public_api
class ProcessingGraphModel = _ProcessingGraphModel with _$ProcessingGraphModel;

abstract class _ProcessingGraphModel with Store {
  @observable
  ObservableMap<int, NodeModel> nodes;

  @observable
  ObservableMap<int, NodeConnectionModel> connections;

  @observable
  int nextId = 1;

  _ProcessingGraphModel({
    ObservableMap<int, NodeModel>? nodes,
    ObservableMap<int, NodeConnectionModel>? connections,
  }) : nodes = nodes ?? ObservableMap<int, NodeModel>(),
       connections = connections ?? ObservableMap<int, NodeConnectionModel>();

  @action
  int allocateId() {
    return nextId++;
  }

  @action
  void addNode(NodeModel node) {
    nodes[node.id] = node;
  }

  @action
  void clear() {
    nodes.clear();
    connections.clear();
    nextId = 1;
  }

  @action
  void addConnection(NodeConnectionModel connection) {
    connections[connection.id] = connection;

    nodes[connection.sourceNodeId]!
        .getPortById(connection.sourcePortId)
        .connections
        .add(connection.id);
    nodes[connection.destinationNodeId]!
        .getPortById(connection.destinationPortId)
        .connections
        .add(connection.id);
  }

  @action
  void removeConnection(int connectionId) {
    final connection = connections.remove(connectionId);

    if (connection == null) {
      return;
    }

    nodes[connection.sourceNodeId]
        ?.getPortById(connection.sourcePortId)
        .connections
        .remove(connection.id);
    nodes[connection.destinationNodeId]
        ?.getPortById(connection.destinationPortId)
        .connections
        .remove(connection.id);
  }
}
