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

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/model/device.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/processing_graph/parameter_config.dart';
import 'package:anthem/model/processing_graph/processors/vst3_processor.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/basic/controls/knob.dart';
import 'package:anthem/widgets/editors/device_rack/devices/vst3_device.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('shows a placeholder in the recent parameter slot', (
    tester,
  ) async {
    await _pumpDevice(tester);

    final placeholderKnob = tester.widget<Knob>(find.byType(Knob).first);

    expect(placeholderKnob.value, 0);
    expect(placeholderKnob.onValueChanged, isNull);
    expect(find.text('Filter cutoff'), findsOneWidget);

    _firstInteractiveKnob(tester).onValueChanged!(0.25);
    await tester.pump();

    expect(find.text('Filter cutoff'), findsNWidgets(2));
  });

  testWidgets('shows engine stopped state instead of parameter controls', (
    tester,
  ) async {
    await _pumpDevice(
      tester,
      engineState: EngineState.stopped,
      lastChangedControlPortId: 100,
    );

    final knobs = tester.widgetList<Knob>(find.byType(Knob)).toList();

    expect(find.text('Engine is not running'), findsOneWidget);
    expect(find.text('Filter cutoff'), findsNothing);
    expect(knobs, hasLength(1));
    expect(knobs.single.value, 0);
    expect(knobs.single.onValueChanged, isNull);
  });

  testWidgets('ignores parameter knob changes after the engine stops', (
    tester,
  ) async {
    final result = await _pumpDevice(tester);
    final cutoffPort = result.node.controlInputPorts.first;
    final initialValue = cutoffPort.parameterValue;
    final cutoffKnob = _firstInteractiveKnob(tester);

    result.project.engineState = EngineState.stopped;
    cutoffKnob.onValueChanged!(0.25);
    await tester.pump();

    expect(cutoffPort.parameterValue, initialValue);
    expect(result.node.lastChangedControlPortId, isNull);
    expect(find.text('Engine is not running'), findsOneWidget);
  });

  testWidgets('filters parameter rows while typing', (tester) async {
    await _pumpDevice(tester);

    expect(find.text('Filter cutoff'), findsOneWidget);
    expect(find.text('Oscillator shape'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'shape');
    await tester.pump();

    expect(find.text('Filter cutoff'), findsNothing);
    expect(find.text('Oscillator shape'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump();

    expect(find.text('Oscillator shape'), findsNothing);
    expect(find.text('No matching parameters'), findsOneWidget);
  });

  testWidgets('shows the most recently changed parameter row', (tester) async {
    await _pumpDevice(tester);

    expect(find.text('Filter cutoff'), findsOneWidget);
    expect(find.text('25.0%'), findsNothing);

    final cutoffKnob = _firstInteractiveKnob(tester);
    cutoffKnob.onValueChanged!(0.25);
    await tester.pump();

    expect(find.text('Filter cutoff'), findsNWidgets(2));
    expect(find.text('25.0%'), findsNWidgets(2));
  });

  testWidgets('shows plugin-provided parameter text with units', (
    tester,
  ) async {
    await _pumpDevice(
      tester,
      firstParameterDisplayMode: ParameterDisplayMode.pluginText,
      firstParameterUnitLabel: 'Hz',
      firstParameterDisplayText: '440',
    );

    expect(find.text('440 Hz'), findsOneWidget);
    expect(find.text('76.0%'), findsNothing);
  });

  testWidgets('adds value hints to parameter knobs', (tester) async {
    await _pumpDevice(tester);

    final cutoffKnob = _firstInteractiveKnob(tester);

    expect(cutoffKnob.hoverHintOverride?.call(0), 'Filter cutoff: 76.0%');
    expect(cutoffKnob.hint?.call(0.25), 'Filter cutoff: 25.0%');
  });
}

Knob _firstInteractiveKnob(WidgetTester tester) {
  return tester
      .widgetList<Knob>(find.byType(Knob))
      .firstWhere((knob) => knob.onValueChanged != null);
}

class _PumpedDevice {
  final ProjectModel project;
  final NodeModel node;

  const _PumpedDevice({required this.project, required this.node});
}

Future<_PumpedDevice> _pumpDevice(
  WidgetTester tester, {
  EngineState engineState = EngineState.running,
  int? lastChangedControlPortId,
  ParameterDisplayMode? firstParameterDisplayMode,
  String? firstParameterUnitLabel,
  String? firstParameterDisplayText,
}) async {
  final project = ProjectModel.create();
  addTearDown(project.dispose);
  project.engineState = engineState;

  final processor = VST3ProcessorModel.create(
    idAllocator: project.idAllocator,
    vst3Path: r'C:\Program Files\Common Files\VST3\Test Plugin.vst3',
  );
  final node = processor.createNode();

  node.controlInputPorts.addAll([
    _createParameterPort(
      nodeId: node.id,
      id: 100,
      name: 'Filter cutoff',
      defaultValue: 0.76,
      displayMode: firstParameterDisplayMode,
      unitLabel: firstParameterUnitLabel,
      displayText: firstParameterDisplayText,
    ),
    _createParameterPort(
      nodeId: node.id,
      id: 101,
      name: 'Filter resonance',
      defaultValue: 0.38,
    ),
    _createParameterPort(
      nodeId: node.id,
      id: 102,
      name: 'Oscillator shape',
      defaultValue: 0.50,
    ),
  ]);
  node.lastChangedControlPortId = lastChangedControlPortId;

  project.processingGraph.addNode(node);
  final device = DeviceModel(
    idAllocator: project.idAllocator,
    name: 'Test Plugin',
    type: DeviceType.vst3Plugin,
    nodeIds: AnthemObservableList.of([node.id]),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Provider<ProjectModel>.value(
        value: project,
        child: Material(
          child: SizedBox(height: 240, child: Vst3Device(device: device)),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 1));

  return _PumpedDevice(project: project, node: node);
}

NodePortModel _createParameterPort({
  required int nodeId,
  required int id,
  required String name,
  required double defaultValue,
  ParameterDisplayMode? displayMode,
  String? unitLabel,
  String? displayText,
}) {
  return NodePortModel(
    nodeId: nodeId,
    id: id,
    config: NodePortConfigModel(
      dataType: NodePortDataType.control,
      name: name,
      parameterConfig: ParameterConfigModel(
        id: id,
        defaultValue: defaultValue,
        displayMode: displayMode,
        unitLabel: unitLabel,
      ),
    ),
    parameterDisplayText: displayText,
  );
}
