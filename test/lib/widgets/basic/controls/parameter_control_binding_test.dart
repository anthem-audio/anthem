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
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/processing_graph/parameter_config.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/basic/controls/knob.dart';
import 'package:anthem/widgets/basic/controls/slider.dart' as anthem;
import 'package:anthem_codegen/include.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Knob commits bound parameter changes to undo stack', (
    tester,
  ) async {
    final (:project, :node, :port) = _createParameterProject(defaultValue: 0.5);
    addTearDown(() => _disposeProject(project));
    await tester.pump(const Duration(milliseconds: 1));

    await tester.pumpWidget(
      Knob(
        parameter: ParameterControlBinding(node: node, port: port),
      ),
    );

    final knob = tester.widget<Knob>(find.byType(Knob));
    knob.onValueChangeStart!();
    knob.onValueChanged!(0.75);
    knob.onValueChangeEnd!(0.75);
    await tester.pump();

    expect(port.parameterValue, 0.75);

    project.undo();
    await tester.pump();
    expect(port.parameterValue, 0.5);

    project.redo();
    await tester.pump();
    expect(port.parameterValue, 0.75);
  });

  testWidgets('Slider maps between control and parameter values', (
    tester,
  ) async {
    final (:project, :node, :port) = _createParameterProject(defaultValue: 0.5);
    addTearDown(() => _disposeProject(project));
    await tester.pump(const Duration(milliseconds: 1));

    await tester.pumpWidget(
      anthem.Slider(
        parameter: ParameterControlBinding(
          node: node,
          port: port,
          parameterToControlValue: (double value) => value * 2 - 1,
          controlToParameterValue: (double value) => (value + 1) * 0.5,
        ),
        min: -1,
        max: 1,
      ),
    );

    var slider = tester.widget<anthem.Slider>(find.byType(anthem.Slider));
    expect(slider.value, 0);

    slider.onValueChangeStart!();
    slider.onValueChanged!(1);
    slider.onValueChangeEnd!(1);
    await tester.pump();

    expect(port.parameterValue, 1);

    slider = tester.widget<anthem.Slider>(find.byType(anthem.Slider));
    expect(slider.value, 1);
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
