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

import 'package:anthem/logic/commands/parameter_commands.dart';
import 'package:anthem/logic/parameter_controller.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/processing_graph/parameter_config.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProjectModel project;
  late NodeModel node;
  late NodePortModel port;

  setUp(() {
    project = ProjectModel.create();
    final nodeId = project.allocateId();
    node = NodeModel(
      id: nodeId,
      controlInputPorts: AnthemObservableList.of([
        NodePortModel(
          nodeId: nodeId,
          id: 100,
          config: NodePortConfigModel(
            dataType: NodePortDataType.control,
            parameterConfig: ParameterConfigModel(id: 100, defaultValue: 0.25),
          ),
        ),
      ]),
    );
    port = node.controlInputPorts.single;
    project.processingGraph.addNode(node);
  });

  tearDown(() {
    project.dispose();
  });

  test('SetParameterValueCommand executes and rolls back', () {
    final command = SetParameterValueCommand(
      nodeId: node.id,
      controlPortId: port.id,
      oldValue: 0.25,
      newValue: 0.75,
    );

    command.execute(project);
    expect(port.parameterValue, equals(0.75));

    command.rollback(project);
    expect(port.parameterValue, equals(0.25));
  });

  test('ParameterController commits a gesture as one undo step', () {
    final controller = ParameterController(project);

    controller.beginChange(node: node, port: port);
    controller.updateChange(node: node, port: port, value: 0.5);
    controller.updateChange(node: node, port: port, value: 0.75);
    controller.commitChange(node: node, port: port);

    expect(port.parameterValue, equals(0.75));

    project.undo();
    expect(port.parameterValue, equals(0.25));

    project.redo();
    expect(port.parameterValue, equals(0.75));
  });

  test('ParameterController skips unchanged gestures', () {
    final controller = ParameterController(project);

    controller.beginChange(node: node, port: port);
    controller.commitChange(node: node, port: port);

    expect(node.lastChangedControlPortId, equals(port.id));

    project.undo();
    expect(port.parameterValue, equals(0.25));
  });

  test(
    'ParameterController marks a gesture as touched before value changes',
    () {
      final controller = ParameterController(project);
      project.isDirty = false;

      controller.beginChange(node: node, port: port);

      expect(node.lastChangedControlPortId, equals(port.id));
      expect(project.isDirty, isFalse);

      controller.commitChange(node: node, port: port);
    },
  );

  test('ParameterController resets to default as one undo step', () {
    final controller = ParameterController(project);

    controller.updateChange(node: node, port: port, value: 0.75);
    controller.resetToDefault(node: node, port: port);

    expect(port.parameterValue, equals(0.25));

    project.undo();
    expect(port.parameterValue, equals(0.75));

    project.redo();
    expect(port.parameterValue, equals(0.25));
  });

  test('ParameterController skips unchanged reset', () {
    final controller = ParameterController(project);
    project.isDirty = false;

    controller.resetToDefault(node: node, port: port);

    expect(node.lastChangedControlPortId, equals(port.id));
    expect(port.parameterValue, equals(0.25));
    expect(project.isDirty, isFalse);
  });
}
