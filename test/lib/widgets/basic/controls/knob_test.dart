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

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/model/processing_graph/processors/utility.dart';
import 'package:anthem/model/processing_graph/parameter_config.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/basic/controls/knob.dart';
import 'package:anthem/widgets/basic/hint/hint_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'new controls wait for a reported value and retain cached displays',
    (tester) async {
      final project = ProjectModel.create();
      addTearDown(project.dispose);
      final node = project
          .tracks[project.trackOrder.single]!
          .requireProcessing
          .utilityNode!;
      final port = node.getPortById(UtilityProcessorModel.balancePortId);
      final emptyOutline = await _paintKnob(tester, const Knob(value: 0));
      final knob = Knob(
        parameterBinding: ParameterUiBinding(node: node, port: port),
      );
      final unknown = await _paintKnob(tester, knob);
      expect(unknown, orderedEquals(emptyOutline));
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byType(Knob)));
      await tester.pump();
      expect(
        HintStore.instance.getActiveHint()!.single.text,
        'Waiting for engine...',
      );
      project.engineState = EngineState.running;
      await tester.pump();
      expect(
        HintStore.instance.getActiveHint()!.single.text,
        'Initializing...',
      );
      port.config.parameterConfig = ParameterConfigModel(
        id: port.id,
        normalizedVisualBaseline: 0.5,
      );
      port.parameterValue = 0.75;
      await tester.pump(Duration.zero);
      expect(HintStore.instance.getActiveHint(), isNull);
      expect(find.byType(CustomPaint), findsOneWidget);
      final confirmed = await _paintKnob(tester, knob);
      expect(confirmed, isNot(orderedEquals(emptyOutline)));
      node.resetEngineInitialization();
      await tester.pump(Duration.zero);
      final cached = await _paintKnob(tester, knob);
      expect(cached, orderedEquals(confirmed));
    },
  );

  testWidgets('bound pan knobs use the same centered arc in both UI domains', (
    tester,
  ) async {
    final project = ProjectModel.create();
    addTearDown(project.dispose);
    final track = project.tracks[project.trackOrder.single]!;
    final node = track.requireProcessing.utilityNode!;
    final port = node.getPortById(UtilityProcessorModel.balancePortId);
    port.config.parameterConfig = ParameterConfigModel(
      id: port.id,
      displayMode: ParameterDisplayMode.pan,
      normalizedVisualBaseline: 0.5,
    );
    port.parameterValue = 0.25;

    final normalized = await _paintKnob(
      tester,
      Knob(
        parameterBinding: ParameterUiBinding(node: node, port: port),
      ),
    );
    final mapped = await _paintKnob(
      tester,
      Knob(
        type: KnobType.pan,
        parameterBinding: ParameterUiBinding(
          node: node,
          port: port,
          parameterToUiValue: (value) => value * 2 - 1,
          uiToParameterValue: (value) => (value + 1) * 0.5,
        ),
      ),
    );
    final standalone = await _paintKnob(
      tester,
      const Knob(type: KnobType.pan, value: -0.5),
    );
    expect(normalized, orderedEquals(mapped));
    expect(normalized, orderedEquals(standalone));
  });

  testWidgets(
    'gain arc starts at the minimum independently of its reset value',
    (tester) async {
      final project = ProjectModel.create();
      addTearDown(project.dispose);
      final track = project.tracks[project.trackOrder.single]!;
      final node = track.requireProcessing.utilityNode!;
      final port = node.getPortById(UtilityProcessorModel.gainPortId);
      port.parameterValue = 0.25;

      final bound = await _paintKnob(
        tester,
        Knob(
          parameterBinding: ParameterUiBinding(node: node, port: port),
        ),
      );
      final standalone = await _paintKnob(tester, const Knob(value: 0.25));
      expect(bound, orderedEquals(standalone));
    },
  );

  testWidgets(
    'bipolar percentages and plugin text use their supplied baselines',
    (tester) async {
      final project = ProjectModel.create();
      addTearDown(project.dispose);
      final track = project.tracks[project.trackOrder.single]!;
      final node = track.requireProcessing.utilityNode!;
      final port = node.getPortById(UtilityProcessorModel.gainPortId);
      port.parameterValue = 0.75;
      final config = port.config.parameterConfig = ParameterConfigModel(
        id: port.id,
      );
      for (final displayMode in [
        ParameterDisplayMode.percent,
        ParameterDisplayMode.pluginText,
      ]) {
        config.displayMode = displayMode;
        for (final baseline in [0.25, 0.5]) {
          port.config.parameterConfig!.normalizedVisualBaseline = baseline;
          final bound = await _paintKnob(
            tester,
            Knob(
              parameterBinding: ParameterUiBinding(node: node, port: port),
            ),
          );
          final standalone = await _paintKnob(
            tester,
            Knob(value: 0.75, normalizedVisualBaseline: baseline),
          );
          expect(bound, orderedEquals(standalone));
        }
      }
    },
  );

  testWidgets(
    'explicit off-center baseline updates the arc without changing its value',
    (tester) async {
      final initial = await _paintKnob(tester, const Knob(value: 0.5));
      final shifted = await _paintKnob(
        tester,
        const Knob(value: 0.5, normalizedVisualBaseline: 0.25),
      );
      expect(shifted, isNot(orderedEquals(initial)));
    },
  );
}

Future<Uint8List> _paintKnob(WidgetTester tester, Knob knob) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: SizedBox(width: 80, height: 80, child: knob)),
    ),
  );
  await tester.pump(Duration.zero);
  final customPaint = tester.widget<CustomPaint>(
    find.descendant(of: find.byType(Knob), matching: find.byType(CustomPaint)),
  );
  return (await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    customPaint.painter!.paint(ui.Canvas(recorder), const ui.Size(80, 80));
    final image = await recorder.endRecording().toImage(80, 80);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
        .buffer
        .asUint8List();
    image.dispose();
    return bytes;
  }))!;
}
