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
import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/helpers/gain_parameter_mapping.dart';
import 'package:anthem/model/processing_graph/parameter_config.dart';
import 'package:anthem/model/processing_graph/processors/utility.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests the parameter UI against the engine API without starting a process.
class ParameterTestEngine extends Fake implements Engine {
  @override
  final ProjectModel project;
  ParameterTestEngine(this.project, {ParameterTestApi? processingGraphApi})
    : processingGraphApi = processingGraphApi ?? ParameterTestApi();
  @override
  final Future<void> sessionEnded = Future.value();
  bool running = true;
  @override
  bool get isRunning => running;
  @override
  final ParameterTestApi processingGraphApi;
  @override
  final SequencerApi sequencerApi = _ParameterTestSequencerApi();
  @override
  Stream<EngineState> get engineStateStream => const Stream.empty();
  @override
  Future<void> dispose() async {
    running = false;
    for (final node in project.processingGraph.nodes.values) {
      node.resetEngineInitialization();
    }
  }
}

class ParameterTestApi extends Fake implements ProcessingGraphApi {
  Future<ProcessingGraphParameterValue> Function(int, int, double)? onEdit;
  @override
  Future<ProcessingGraphParameterValue> setParameterValue(
    int nodeId,
    int portId,
    double value,
  ) =>
      onEdit?.call(nodeId, portId, value) ??
      Future.value(
        ProcessingGraphParameterValue(controlPortId: portId, value: value),
      );
  @override
  Future<String?> captureProcessorState(int nodeId) async => null;

  @override
  Future<void> waitForPendingParameterEdits(int nodeId) async {}
}

ParameterTestEngine installParameterTestEngine(ProjectModel project) {
  final original = project.engine;
  addTearDown(original.dispose);
  final engine = ParameterTestEngine(project);
  project.engine = engine;
  for (final node in project.processingGraph.nodes.values) {
    node.markInitialized();
    if (node.processor is UtilityProcessorModel) {
      for (final port in node.controlInputPorts) {
        final pan = port.id == UtilityProcessorModel.balancePortId;
        final value = pan ? 0.5 : gainParameterZeroDbNormalized;
        port.config.parameterConfig = ParameterConfigModel(
          id: port.id,
          factoryDefaultValue: value,
          displayMode: pan
              ? ParameterDisplayMode.pan
              : ParameterDisplayMode.gainDb,
          normalizedVisualBaseline: pan ? 0.5 : 0.0,
        );
        port.parameterValue ??= node.initialParameterValues[port.id] ?? value;
      }
    }
    for (final port in node.getAllPorts()) {
      port.isAvailable = true;
    }
  }
  return engine;
}

class _ParameterTestSequencerApi extends Fake implements SequencerApi {
  @override
  void cleanUpTrack(int trackId) {}

  @override
  void compileArrangement({
    List<int>? tracksToRebuild,
    List<InvalidationRange>? invalidationRanges,
  }) {}
}

/// Engine reports used by parameter-focused UI tests without a native process.
ProcessingGraphNodeInitializationResult testUtilityInitialization(
  NodeModel node,
) {
  final controls = [
    ProcessingGraphPortConfiguration(
      id: UtilityProcessorModel.gainPortId,
      parameterDefaultValue: gainParameterZeroDbNormalized,
      parameterDisplayMode: 'gainDb',
      parameterUnitLabel: 'dB',
    ),
    ProcessingGraphPortConfiguration(
      id: UtilityProcessorModel.balancePortId,
      parameterDefaultValue: 0.5,
      parameterDisplayMode: 'pan',
      parameterNormalizedVisualBaseline: 0.5,
    ),
  ];
  return ProcessingGraphNodeInitializationResult(
    nodeId: node.id,
    success: true,
    portConfiguration: ProcessingGraphNodePortConfiguration(
      audioInputPorts: [
        ProcessingGraphPortConfiguration(
          id: UtilityProcessorModel.audioInputPortId,
          channelCount: 2,
        ),
      ],
      audioOutputPorts: [
        ProcessingGraphPortConfiguration(
          id: UtilityProcessorModel.audioOutputPortId,
          channelCount: 2,
        ),
      ],
      eventInputPorts: [],
      eventOutputPorts: [],
      controlOutputPorts: [],
      controlInputPorts: controls,
    ),
    parameterValues: [
      for (final descriptor in controls)
        ProcessingGraphParameterValue(
          controlPortId: descriptor.id,
          value:
              node.getPortById(descriptor.id).parameterValue ??
              node.initialParameterValues[descriptor.id] ??
              descriptor.parameterDefaultValue!,
        ),
    ],
  );
}
