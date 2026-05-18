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

import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_connection.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/processing_graph/parameter_config.dart';
import 'package:anthem/model/processing_graph/processing_graph.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter_test/flutter_test.dart';

NodePortModel _port({
  required int nodeId,
  required int id,
  required NodePortDataType dataType,
  ParameterConfigModel? parameterConfig,
}) {
  return NodePortModel(
    nodeId: nodeId,
    id: id,
    config: NodePortConfigModel(
      dataType: dataType,
      parameterConfig: parameterConfig,
    ),
  );
}

ProjectEntityIdAllocator _idAllocatorFor(int id) {
  return ProjectEntityIdAllocator.test(() => id);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProcessingGraphModel.addConnection()', () {
    test('adds a valid typed connection when port IDs overlap', () {
      final graph = ProcessingGraphModel();
      final sourceAudioPort = _port(
        nodeId: 1,
        id: 0,
        dataType: NodePortDataType.audio,
      );
      final sourceControlPort = _port(
        nodeId: 1,
        id: 0,
        dataType: NodePortDataType.control,
      );
      final destinationAudioPort = _port(
        nodeId: 2,
        id: 0,
        dataType: NodePortDataType.audio,
      );
      final destinationControlPort = _port(
        nodeId: 2,
        id: 0,
        dataType: NodePortDataType.control,
      );

      graph.addNode(
        NodeModel(
          id: 1,
          audioOutputPorts: AnthemObservableList.of([sourceAudioPort]),
          controlOutputPorts: AnthemObservableList.of([sourceControlPort]),
        ),
      );
      graph.addNode(
        NodeModel(
          id: 2,
          audioInputPorts: AnthemObservableList.of([destinationAudioPort]),
          controlInputPorts: AnthemObservableList.of([destinationControlPort]),
        ),
      );

      final connection = NodeConnectionModel(
        idAllocator: _idAllocatorFor(10),
        sourceNodeId: 1,
        sourcePortId: 0,
        destinationNodeId: 2,
        destinationPortId: 0,
        dataType: NodePortDataType.audio,
      );

      graph.addConnection(connection);

      expect(graph.connections[10], same(connection));
      expect(sourceAudioPort.connections, equals([10]));
      expect(destinationAudioPort.connections, equals([10]));
      expect(sourceControlPort.connections, isEmpty);
      expect(destinationControlPort.connections, isEmpty);
    });

    test('rejects a mistyped connection without mutating the graph', () {
      final graph = ProcessingGraphModel();
      final sourceControlPort = _port(
        nodeId: 1,
        id: 0,
        dataType: NodePortDataType.control,
      );
      final destinationAudioPort = _port(
        nodeId: 2,
        id: 0,
        dataType: NodePortDataType.audio,
      );

      graph.addNode(
        NodeModel(
          id: 1,
          controlOutputPorts: AnthemObservableList.of([sourceControlPort]),
        ),
      );
      graph.addNode(
        NodeModel(
          id: 2,
          audioInputPorts: AnthemObservableList.of([destinationAudioPort]),
        ),
      );

      final connection = NodeConnectionModel(
        idAllocator: _idAllocatorFor(11),
        sourceNodeId: 1,
        sourcePortId: 0,
        destinationNodeId: 2,
        destinationPortId: 0,
        dataType: NodePortDataType.control,
      );

      expect(() => graph.addConnection(connection), throwsException);
      expect(graph.connections, isEmpty);
      expect(sourceControlPort.connections, isEmpty);
      expect(destinationAudioPort.connections, isEmpty);
    });
  });

  group('NodeModel parameter touch tracking', () {
    test('tracks the last changed control input parameter', () {
      final project = ProjectModel.create();
      addTearDown(project.dispose);
      final nodeId = project.allocateId();
      final parameterPort = _port(
        nodeId: nodeId,
        id: 100,
        dataType: NodePortDataType.control,
        parameterConfig: ParameterConfigModel(id: 100, defaultValue: 0.5),
      );
      final nonParameterPort = _port(
        nodeId: nodeId,
        id: 101,
        dataType: NodePortDataType.control,
      );
      final node = NodeModel(
        id: nodeId,
        controlInputPorts: AnthemObservableList.of([
          parameterPort,
          nonParameterPort,
        ]),
      );

      project.processingGraph.addNode(node);

      parameterPort.parameterValue = 0.75;

      expect(node.lastChangedControlPortId, equals(100));

      nonParameterPort.parameterValue = 0.25;

      expect(node.lastChangedControlPortId, equals(100));
    });

    test('can suppress parameter touch tracking for state sync', () {
      final project = ProjectModel.create();
      addTearDown(project.dispose);
      final nodeId = project.allocateId();
      final parameterPort = _port(
        nodeId: nodeId,
        id: 100,
        dataType: NodePortDataType.control,
        parameterConfig: ParameterConfigModel(id: 100, defaultValue: 0.5),
      );
      final node = NodeModel(
        id: nodeId,
        controlInputPorts: AnthemObservableList.of([parameterPort]),
      );

      project.processingGraph.addNode(node);

      node.withoutParameterTouchTracking(() {
        parameterPort.parameterValue = 0.25;
      });

      expect(node.lastChangedControlPortId, isNull);

      parameterPort.parameterValue = 0.75;

      expect(node.lastChangedControlPortId, equals(100));
    });
  });
}
