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

/// A reusable fragment of processing graph state.
///
/// This is used by undo/redo commands and by logic that needs to prepare a set
/// of nodes and connections before adding them to the graph. Keeping the
/// original model objects around also preserves transient state such as
/// third-party plugin state.
class ProcessingGraphFragment {
  final List<NodeModel> nodes;
  final List<NodeConnectionModel> connections;

  const ProcessingGraphFragment({
    required this.nodes,
    required this.connections,
  });

  const ProcessingGraphFragment.empty()
    : nodes = const [],
      connections = const [];

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

  /// Captures the given nodes and any touching connections without mutating the
  /// graph.
  ///
  /// This is for save/restore. For example, tracks only contain references to
  /// node IDs - they do not hold the actual node objects. When a track is
  /// removed and we are creating the undo/redo step, we need to capture the
  /// actual node and processor objects that are removed in that step so we can
  /// restore them later.
  ProcessingGraphFragment captureNodes(Iterable<Id> nodeIds) {
    final capturedNodeIds = <Id>{};
    for (final nodeId in nodeIds) {
      if (nodes[nodeId] != null) {
        capturedNodeIds.add(nodeId);
      }
    }

    if (capturedNodeIds.isEmpty) {
      return const ProcessingGraphFragment.empty();
    }

    final capturedConnections = <NodeConnectionModel>[];
    for (final connection in connections.values) {
      final isTouchingCapturedNode =
          capturedNodeIds.contains(connection.sourceNodeId) ||
          capturedNodeIds.contains(connection.destinationNodeId);

      if (isTouchingCapturedNode) {
        capturedConnections.add(connection);
      }
    }

    final capturedNodes = <NodeModel>[];
    for (final nodeId in capturedNodeIds) {
      final node = nodes[nodeId];
      if (node != null) {
        capturedNodes.add(node);
      }
    }

    return ProcessingGraphFragment(
      nodes: capturedNodes,
      connections: capturedConnections,
    );
  }

  /// Removes the given nodes from the graph while capturing all removed nodes
  /// and connections so they can be restored later.
  ProcessingGraphFragment removeNodesAndCapture(Iterable<Id> nodeIds) {
    final fragment = captureNodes(nodeIds);
    if (fragment.isEmpty) {
      return const ProcessingGraphFragment.empty();
    }

    for (final connection in fragment.connections) {
      removeConnection(connection.id);
    }

    for (final node in fragment.nodes) {
      nodes.remove(node.id);
    }

    return fragment;
  }

  /// Restores a fragment into the graph.
  void restoreGraphFragment(ProcessingGraphFragment fragment) {
    for (final node in fragment.nodes) {
      if (nodes[node.id] != null) {
        continue;
      }

      addNode(node);
    }

    for (final connection in fragment.connections) {
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
