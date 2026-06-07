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

import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/logic/commands/track_commands.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/processing_graph/parameter_config.dart';
import 'package:anthem/model/processing_graph/processors/control_value_visualization.dart';
import 'package:anthem/model/processing_graph/processors/utility.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/basic/controls/parameter_control_binding.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ParameterUiBinding commits parameter changes to undo stack', () {
    final (:project, :node, :port) = _createParameterProject(defaultValue: 0.5);
    addTearDown(() => _disposeProject(project));

    final binding = ParameterUiBinding(node: node, port: port);

    binding.beginChange();
    binding.updateChange(0.75);
    binding.commitChange();

    expect(port.parameterValue, 0.75);

    project.undo();
    expect(port.parameterValue, 0.5);

    project.redo();
    expect(port.parameterValue, 0.75);
  });

  test('ParameterUiBinding maps between UI and parameter values', () {
    final (:project, :node, :port) = _createParameterProject(defaultValue: 0.5);
    addTearDown(() => _disposeProject(project));

    final binding = ParameterUiBinding(
      node: node,
      port: port,
      parameterToUiValue: (double value) => value * 2 - 1,
      uiToParameterValue: (double value) => (value + 1) * 0.5,
    );

    expect(binding.uiValue, 0);
    expect(binding.uiValueForNormalizedParameterValue(0.75), 0.5);

    binding.beginChange();
    binding.updateChange(1);
    binding.commitChange();

    expect(port.parameterValue, 1);
    expect(binding.uiValue, 1);
  });

  test('ParameterUiBinding resets mapped parameters to default', () {
    final (:project, :node, :port) = _createParameterProject(
      defaultValue: 0.25,
    );
    addTearDown(() => _disposeProject(project));

    final binding = ParameterUiBinding(
      node: node,
      port: port,
      parameterToUiValue: (double value) => value * 2 - 1,
      uiToParameterValue: (double value) => (value + 1) * 0.5,
    );

    binding.beginChange();
    binding.updateChange(1);
    binding.commitChange();
    expect(port.parameterValue, 1);

    binding.resetToDefault();

    expect(port.parameterValue, 0.25);
    expect(binding.uiValue, -0.5);

    project.undo();
    expect(port.parameterValue, 1);

    project.redo();
    expect(port.parameterValue, 0.25);
  });

  test('ParameterUiBinding resolves automation visualization from lane', () {
    final project = ProjectModel.create();
    ServiceRegistry.initializeProject(project);
    addTearDown(() => _disposeProject(project));

    final track = project.tracks[project.trackOrder.single]!;
    final utilityNode = track.requireProcessing.utilityNode!;
    final port = utilityNode.getPortById(UtilityProcessorModel.gainPortId);
    final binding = ParameterUiBinding(node: utilityNode, port: port);

    expect(binding.automationVisualizationId, isNull);

    final command = AutomationLaneAddRemoveCommand.add(
      project: project,
      parentTrackId: track.id,
      nodeId: utilityNode.id,
      portId: port.id,
      name: 'Volume',
    );
    command.execute(project);

    final expectedVisualizationId =
        ControlValueVisualizationProcessorModel.buildVisualizationId(
          nodeId: utilityNode.id,
          portId: port.id,
        );

    expect(binding.automationVisualizationId, equals(expectedVisualizationId));

    command.rollback(project);

    expect(binding.automationVisualizationId, isNull);

    command.execute(project);

    expect(binding.automationVisualizationId, equals(expectedVisualizationId));
  });
}

({ProjectModel project, NodeModel node, NodePortModel port})
_createParameterProject({required double defaultValue}) {
  final project = ProjectModel.create();
  ServiceRegistry.initializeProject(project);

  final nodeId = project.allocateId();
  final port = NodePortModel(
    nodeId: nodeId,
    id: 100,
    config: NodePortConfigModel(
      dataType: NodePortDataType.control,
      parameterConfig: ParameterConfigModel(
        id: 100,
        defaultValue: defaultValue,
      ),
    ),
  );
  final node = NodeModel(
    id: nodeId,
    controlInputPorts: AnthemObservableList.of([port]),
  );

  project.processingGraph.addNode(node);

  return (project: project, node: node, port: port);
}

void _disposeProject(ProjectModel project) {
  ServiceRegistry.removeProject(project.id);
  project.dispose();
}
