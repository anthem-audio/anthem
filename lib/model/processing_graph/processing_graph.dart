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

import 'package:anthem/model/processing_graph/processors/master_output.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project_model_getter_mixin.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

import 'node.dart';
import 'node_connection.dart';

part 'processing_graph.g.dart';

/// Captures the result of removing one or more processing graph nodes.
///
/// This is primarily used by undo/redo commands (for example track add/remove)
/// so the exact removed nodes and any connections touching those nodes can be
/// restored on redo/undo without recomputing graph state. This also allows us
/// to keep the objects around in case they have transient plugin state (e.g.
/// third-party plugin state) that would be destroyed if the objects were
/// recreated.
class RemovedNodesSnapshot {
  final List<NodeModel> nodes;
  final List<NodeConnectionModel> connections;

  const RemovedNodesSnapshot({required this.nodes, required this.connections});

  const RemovedNodesSnapshot.empty() : nodes = const [], connections = const [];

  bool get isEmpty => nodes.isEmpty && connections.isEmpty;
}

@AnthemModel.syncedModel()
class ProcessingGraphModel extends _ProcessingGraphModel
    with _$ProcessingGraphModel, _$ProcessingGraphModelAnthemModelMixin {
  ProcessingGraphModel() {
    _init();
  }

  ProcessingGraphModel.uninitialized();

  ProcessingGraphModel.create({required Id masterOutputNodeId}) {
    // Set up the master output node
    final masterOutputNode = MasterOutputProcessorModel(
      nodeId: masterOutputNodeId,
    ).createNode();
    addNode(masterOutputNode);
    this.masterOutputNodeId = masterOutputNode.id;

    _init();
  }

  void _init() {
    // Send a message to compile the processing graph after the model has been
    // sent to the engine
    onModelFirstAttached(() async {
      // Forward engine state changes to all nodes
      //
      // I don't want to add this listener in the node itself because that would
      // require me to add model lifecycle methods to the entire model, or
      // otherwise always remember to clean up the node's listeners when
      // removing a node, neither of which I want to do.
      project.engine.engineStateStream.listen((state) {
        for (final node in nodes.values) {
          node.handleEngineStateChange(state);
        }
      });
    });
  }

  factory ProcessingGraphModel.fromJson(Map<String, dynamic> json) {
    final graph = _$ProcessingGraphModelAnthemModelMixin.fromJson(json);
    graph._init();
    return graph;
  }

  void addNode(NodeModel node) {
    nodes[node.id] = node;
  }

  /// Removes the given nodes from the graph while capturing all removed nodes
  /// and connections so they can be restored later.
  RemovedNodesSnapshot removeNodesAndCapture(Iterable<Id> nodeIds) {
    final idsToRemove = <Id>{};
    for (final nodeId in nodeIds) {
      if (nodes[nodeId] != null) {
        idsToRemove.add(nodeId);
      }
    }

    if (idsToRemove.isEmpty) {
      return const RemovedNodesSnapshot.empty();
    }

    final removedConnections = <NodeConnectionModel>[];
    for (final connection in connections.values) {
      final isTouchingRemovedNode =
          idsToRemove.contains(connection.sourceNodeId) ||
          idsToRemove.contains(connection.destinationNodeId);

      if (isTouchingRemovedNode) {
        removedConnections.add(connection);
      }
    }

    final removedNodes = <NodeModel>[];
    for (final nodeId in idsToRemove) {
      final node = nodes[nodeId];
      if (node != null) {
        removedNodes.add(node);
      }
    }

    for (final connection in removedConnections) {
      removeConnection(connection.id);
    }

    for (final node in removedNodes) {
      nodes.remove(node.id);
    }

    return RemovedNodesSnapshot(
      nodes: removedNodes,
      connections: removedConnections,
    );
  }

  /// Restores a snapshot that was captured by [removeNodesAndCapture].
  void restoreRemovedNodesSnapshot(RemovedNodesSnapshot snapshot) {
    for (final node in snapshot.nodes) {
      if (nodes[node.id] != null) {
        continue;
      }

      addNode(node);
    }

    for (final connection in snapshot.connections) {
      if (connections[connection.id] != null) {
        continue;
      }

      if (nodes[connection.sourceNodeId] == null) {
        throw StateError(
          'Could not restore connection ${connection.id}: source node '
          '${connection.sourceNodeId} not found.',
        );
      }

      if (nodes[connection.destinationNodeId] == null) {
        throw StateError(
          'Could not restore connection ${connection.id}: destination node '
          '${connection.destinationNodeId} not found.',
        );
      }

      addConnection(connection);
    }
  }

  /// Removes a node from the graph, and removes all connections to and from the
  /// node.
  void removeNode(Id nodeId) {
    final node = nodes[nodeId];

    if (node == null) return;

    for (final port in node.getAllPorts()) {
      // We copy the list of connections here so we can modify the original
      // without a concurrent modification error
      for (final connectionId in [...port.connections]) {
        removeConnection(connectionId);
      }
    }

    nodes.remove(nodeId);
  }

  void addConnection(NodeConnectionModel connection) {
    connections[connection.id] = connection;

    final sourceNode = nodes[connection.sourceNodeId]!;
    final sourceNodePort = sourceNode.getPortById(connection.sourcePortId);
    sourceNodePort.connections.add(connection.id);

    final destinationNode = nodes[connection.destinationNodeId];
    final destinationNodePort = destinationNode!.getPortById(
      connection.destinationPortId,
    );
    destinationNodePort.connections.add(connection.id);
  }

  void removeConnection(Id connectionId) {
    final connection = connections[connectionId]!;
    final sourceNode = nodes[connection.sourceNodeId]!;
    final sourceNodePort = sourceNode.getPortById(connection.sourcePortId);
    sourceNodePort.connections.removeWhere((e) => e == connectionId);

    final destinationNode = nodes[connection.destinationNodeId]!;
    final destinationNodePort = destinationNode.getPortById(
      connection.destinationPortId,
    );
    destinationNodePort.connections.removeWhere((e) => e == connectionId);

    connections.remove(connectionId);
  }

  NodeModel getMasterOutputNode() {
    return nodes[masterOutputNodeId]!;
  }
}

abstract class _ProcessingGraphModel
    with Store, AnthemModelBase, ProjectModelGetterMixin {
  /// A map of nodes in the graph.
  ///
  /// The key is the node ID.
  ///
  /// This should not be modified directly. Use [addNode] and [removeNode].
  @anthemObservable
  AnthemObservableMap<Id, NodeModel> nodes = AnthemObservableMap();

  /// A map of connections between nodes in the graph.
  ///
  /// The key is the connection ID.
  ///
  /// This should not be modified directly. Use [addConnection] and
  /// [removeConnection].
  @anthemObservable
  AnthemObservableMap<Id, NodeConnectionModel> connections =
      AnthemObservableMap();

  @anthemObservable
  late Id masterOutputNodeId;
}
