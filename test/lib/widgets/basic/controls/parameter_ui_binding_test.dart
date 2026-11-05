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
import 'package:anthem/model/processing_graph/processors/gain.dart';
import 'package:anthem/model/processing_graph/processors/utility.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/basic/controls/parameter_ui_binding.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/parameter_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ParameterUiBinding commits parameter changes to undo stack', () async {
    final (:project, :node, :port) = _createParameterProject(defaultValue: 0.5);
    addTearDown(() => _disposeProject(project));

    installParameterTestEngine(project);
    final binding = ParameterUiBinding(node: node, port: port);

    binding.beginChange();
    binding.updateChange(0.75);
    await binding.commitChange();

    expect(port.parameterValue, 0.75);

    await project.undo();
    expect(port.parameterValue, 0.5);

    await project.redo();
    expect(port.parameterValue, 0.75);
  });

  test('ParameterUiBinding maps between UI and parameter values', () async {
    final (:project, :node, :port) = _createParameterProject(defaultValue: 0.5);
    addTearDown(() => _disposeProject(project));

    installParameterTestEngine(project);
    final binding = ParameterUiBinding(
      node: node,
      port: port,
      parameterToUiValue: (double value) => value * 2 - 1,
      uiToParameterValue: (double value) => (value + 1) * 0.5,
    );

    expect(binding.displayValue(), 0);
    expect(binding.displayValue(automatedNormalizedValue: 0.75), 0.5);

    binding.beginChange();
    binding.updateChange(1);
    await binding.commitChange();

    expect(port.parameterValue, 1);
    expect(binding.displayValue(), 1);
  });

  test(
    'display values preserve unknown, pending, cached and automated states',
    () {
      final (:project, :node, :port) = _createParameterProject(
        defaultValue: 0.25,
      );
      addTearDown(() => _disposeProject(project));
      final binding = ParameterUiBinding(node: node, port: port);

      port.parameterResetValue = 0.8;
      port.parameterValue = null;
      expect(binding.displayValue(), isNull);
      expect(binding.displayValue(automatedNormalizedValue: 0.9), isNull);
      expect(binding.missingValueMessage, 'Waiting for engine...');

      port.pendingParameterValue = 0.6;
      expect(binding.displayValue(), 0.6);
      expect(binding.missingValueMessage, isNull);

      port.parameterValue = 0.25;
      port.pendingParameterValue = null;
      expect(binding.displayValue(), 0.25);

      port.pendingParameterValue = 0.7;
      expect(binding.displayValue(), 0.7);
      expect(binding.displayValue(automatedNormalizedValue: 0.9), 0.9);
      expect(port.parameterValue, 0.25);
      expect(port.pendingParameterValue, 0.7);
    },
  );

  test(
    'display values clamp normalized inputs before mapping to the UI range',
    () {
      final (:project, :node, :port) = _createParameterProject(
        defaultValue: 0.25,
      );
      addTearDown(() => _disposeProject(project));
      final binding = ParameterUiBinding(
        node: node,
        port: port,
        parameterToUiValue: (value) => value * 2 - 1,
      );

      port.parameterValue = 1.2;
      expect(binding.displayValue(), 1);
      port.pendingParameterValue = -0.2;
      expect(binding.displayValue(), -1);
      expect(binding.displayValue(automatedNormalizedValue: 1.2), 1);
      expect(binding.displayValue(automatedNormalizedValue: -0.2), -1);
    },
  );

  test('ParameterUiBinding resets mapped parameters to default', () async {
    final (:project, :node, :port) = _createParameterProject(
      defaultValue: 0.25,
    );
    addTearDown(() => _disposeProject(project));

    installParameterTestEngine(project);
    final binding = ParameterUiBinding(
      node: node,
      port: port,
      parameterToUiValue: (double value) => value * 2 - 1,
      uiToParameterValue: (double value) => (value + 1) * 0.5,
    );

    binding.beginChange();
    binding.updateChange(1);
    await binding.commitChange();
    expect(port.parameterValue, 1);

    await binding.resetToDefault();

    expect(port.parameterValue, 0.25);
    expect(binding.displayValue(), -0.5);

    await project.undo();
    expect(port.parameterValue, 1);

    await project.redo();
    expect(port.parameterValue, 0.25);
  });

  test('ParameterUiBinding maps a pan visual baseline into the UI domain', () {
    final (:project, :node, :port) = _createParameterProject(
      defaultValue: 0.25,
      displayMode: ParameterDisplayMode.pan,
      normalizedVisualBaseline: 0.5,
    );
    addTearDown(() => _disposeProject(project));
    expect(ParameterUiBinding(node: node, port: port).uiVisualBaseline, 0.5);

    final mappedBinding = ParameterUiBinding(
      node: node,
      port: port,
      parameterToUiValue: (value) => value * 2 - 1,
      uiToParameterValue: (value) => (value + 1) * 0.5,
    );
    expect(mappedBinding.displayValue(), -0.5);
    expect(mappedBinding.uiVisualBaseline, 0);
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
_createParameterProject({
  required double defaultValue,
  ParameterDisplayMode? displayMode,
  double normalizedVisualBaseline = 0.0,
}) {
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
        factoryDefaultValue: defaultValue,
        displayMode: displayMode,
        normalizedVisualBaseline: normalizedVisualBaseline,
      ),
    ),
  );
  final node = NodeModel(
    id: nodeId,
    processor: GainProcessorModel(nodeId: nodeId),
    controlInputPorts: AnthemObservableList.of([port]),
  );

  project.processingGraph.addNode(node);

  return (project: project, node: node, port: port);
}

Future<void> _disposeProject(ProjectModel project) async {
  await project.dispose();
  ServiceRegistry.removeProject(project.id);
}
