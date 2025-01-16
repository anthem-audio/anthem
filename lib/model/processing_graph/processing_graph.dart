/*
  Copyright (C) 2024 - 2025 Joshua Wade

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

import 'package:anthem/model/anthem_model_base_mixin.dart';
import 'package:anthem/model/collections.dart';
import 'package:anthem/model/processing_graph/processors/master_output.dart';
import 'package:anthem_codegen/include/annotations.dart';
import 'package:mobx/mobx.dart';

import 'node.dart';
import 'node_connection.dart';

part 'processing_graph.g.dart';

@AnthemModel.syncedModel()
class ProcessingGraphModel extends _ProcessingGraphModel
    with _$ProcessingGraphModel, _$ProcessingGraphModelAnthemModelMixin {
  ProcessingGraphModel.uninitialized();

  ProcessingGraphModel() {
    // Set up the master output node
    final masterOutputNode =
        MasterOutputProcessorModel.createNode('masterOutput');
    addNode(masterOutputNode);
    masterOutput = MasterOutputProcessorModel(nodeId: masterOutputNode.id);

    // Send a message to compile the processing graph after the model has been
    // sent to the engine
    onModelAttached(() async {
      await project.waitForFirstSync();
      await project.engine.processingGraphApi.compile();
    });
  }

  factory ProcessingGraphModel.fromJson(Map<String, dynamic> json) =>
      _$ProcessingGraphModelAnthemModelMixin.fromJson(json);

  void addNode(NodeModel node) {
    nodes[node.id] = node;
  }

  void removeNode(String nodeId) {
    nodes.remove(nodeId);
  }

  void addConnection(NodeConnectionModel connection) {
    connections[connection.id] = connection;

    final sourceNode = nodes[connection.sourceNodeId]!;
    final sourceNodePort = sourceNode.getPortById(connection.sourcePortId);
    sourceNodePort.connections.add(connection.id);

    final destinationNode = nodes[connection.destinationNodeId];
    final destinationNodePort =
        destinationNode!.getPortById(connection.destinationPortId);
    destinationNodePort.connections.add(connection.id);
  }

  void removeConnection(String connectionId) {
    final connection = connections[connectionId]!;
    final sourceNode = nodes[connection.sourceNodeId]!;
    final sourceNodePort = sourceNode.getPortById(connection.sourcePortId);
    sourceNodePort.connections.removeWhere((e) => e == connectionId);

    final destinationNode = nodes[connection.destinationNodeId]!;
    final destinationNodePort =
        destinationNode.getPortById(connection.destinationPortId);
    destinationNodePort.connections.removeWhere((e) => e == connectionId);

    connections.remove(connectionId);
  }
}

abstract class _ProcessingGraphModel with Store, AnthemModelBase {
  /// A map of nodes in the graph.
  ///
  /// The key is the node ID.
  ///
  /// This should not be modified directly. Use [addNode] and [removeNode].
  @anthemObservable
  AnthemObservableMap<String, NodeModel> nodes = AnthemObservableMap();

  /// A map of connections between nodes in the graph.
  ///
  /// The key is the connection ID.
  ///
  /// This should not be modified directly. Use [addConnection] and
  /// [removeConnection].
  @anthemObservable
  AnthemObservableMap<String, NodeConnectionModel> connections =
      AnthemObservableMap();

  @anthemObservable
  late MasterOutputProcessorModel masterOutput;
}
