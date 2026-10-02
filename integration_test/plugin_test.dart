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

import 'dart:io';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/commands/parameter_commands.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/device.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/processors/vst3_processor.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/widgets/editors/device_rack/devices/vst3_device.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/app_test_session.dart';
import 'support/test_plugins.dart';
import 'support/waits.dart';

Future<void> _prepareRack(AppTestSession session, Id trackId) async {
  // Prerequisite setup: isolate the plugins from the default built-in device.
  for (final device
      in session.project.tracks[trackId]!.requireProcessing.devices.toList()) {
    session.services.deviceController.removeDevice(
      trackId: trackId,
      deviceId: device.id,
    );
  }
  _showRack(session, trackId);
  await startOfflinePluginProcessing(session);
}

void _showRack(AppTestSession session, Id trackId) {
  session.services.trackController.setActiveTrack(trackId);
  session.services.arrangerViewModel.selectedTracks.add(trackId);
  session.services.projectViewModel.selectedEditor = EditorKind.deviceRack;
  session.services.projectViewModel.activePanel = PanelKind.deviceRack;
}

NodePortModel _parameter(NodeModel node, String name) =>
    node.controlInputPorts.singleWhere((port) => port.config.name == name);

Future<String> _liveState(AppTestSession session, NodeModel node) async {
  final state = await waitForFuture(
    session.tester,
    session.project.engine.processingGraphApi.getPluginState(node.id),
    conditionDescription: 'live serialized state of plugin ${node.id}',
    collectTimeoutDiagnostics: () => session.sessionDiagnostics,
    checkHealth: session.checkEngine,
  );
  expect(state, isNotEmpty, reason: 'A real VST3 instance must provide state.');
  return state;
}

void _setParameter(
  AppTestSession session,
  NodeModel node,
  String name,
  double value,
) {
  final port = _parameter(node, name);
  session.project.execute(
    SetParameterValueCommand(
      nodeId: node.id,
      controlPortId: port.id,
      oldValue: SetParameterValueCommand.effectiveParameterValue(port),
      newValue: value,
    ),
  );
}

Future<void> _verifyPlugin(
  AppTestSession session,
  NodeModel node, {
  required bool instrument,
}) async {
  await waitForFuture(
    session.tester,
    node.pluginLoadedCompleter.future,
    conditionDescription: 'real VST3 instance ${node.id} loaded',
    collectTimeoutDiagnostics: () => session.sessionDiagnostics,
  );
  await waitForFuture(
    session.tester,
    node.stateIsSentToEngineCompleter.future,
    conditionDescription: 'plugin ${node.id} restored its opaque state',
    collectTimeoutDiagnostics: () => session.sessionDiagnostics,
  );
  expect(node.processor, isA<VST3ProcessorModel>());
  expect(node.audioInputPorts, hasLength(instrument ? 0 : 1));
  expect(node.audioOutputPorts, hasLength(1));
  expect(node.audioOutputPorts.single.config.channelCount, 2);
  expect(node.eventInputPorts, hasLength(instrument ? 1 : 0));
  expect(node.eventOutputPorts, isEmpty);
  expect(
    node.controlInputPorts.map((port) => port.config.name),
    unorderedEquals(['Gain', 'Invert', 'Bypass']),
  );
  expect(node.controlInputPorts.map((port) => port.id).toSet(), hasLength(3));
  await session.waitForEngineModel(
    conditionDescription: 'engine discovered plugin ${node.id} ports',
    matches: (model) {
      final engineNode =
          ((model['processingGraph'] as Map)['nodes'] as Map)[node.id
                  .toString()]
              as Map?;
      return engineNode != null &&
          (engineNode['audioInputPorts'] as List).length ==
              (instrument ? 0 : 1) &&
          (engineNode['audioOutputPorts'] as List).length == 1 &&
          (engineNode['eventInputPorts'] as List).length ==
              (instrument ? 1 : 0) &&
          (engineNode['controlInputPorts'] as List).length == 3;
    },
  );
}

Future<({DeviceModel device, NodeModel node})> _addPlugin(
  AppTestSession session,
  TestPluginFileSelector files,
  Id trackId,
  String pluginPath, {
  required bool instrument,
}) async {
  files.selectedPluginPath = pluginPath;
  final previousIds = session.project.tracks[trackId]!.requireProcessing.devices
      .map((device) => device.id)
      .toSet();
  await waitForFuture(
    session.tester,
    session.services.deviceController.addDevice(
      trackId: trackId,
      type: DeviceType.vst3Plugin,
    ),
    conditionDescription: 'application Add VST3 workflow',
    collectTimeoutDiagnostics: () => session.sessionDiagnostics,
  );
  await publishPluginGraph(session);
  final device = session.project.tracks[trackId]!.requireProcessing.devices
      .singleWhere((device) => !previousIds.contains(device.id));
  final node = session.project.processingGraph.nodes[device.nodeIds.single]!;
  expect((node.processor as VST3ProcessorModel).vst3Path, pluginPath);
  await _verifyPlugin(session, node, instrument: instrument);
  return (device: device, node: node);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testAppScenario('load, remove, and reload real VST3 instrument and effect', (
    tester,
  ) async {
    final fixtures = loadTestPlugins();
    final files = await TestPluginFileSelector.install(
      'plugin-loading',
      fixtures,
    );
    final session = AppTestSession(tester, name: 'plugin-loading');
    await session.start();
    final trackId = session.project.trackOrder.first;
    await _prepareRack(session, trackId);
    final retiredNodeIds = <Id>{};
    for (var attempt = 0; attempt < 2; attempt++) {
      for (final fixture in [
        (path: fixtures.instrument, instrument: true),
        (path: fixtures.effect, instrument: false),
      ]) {
        final added = await _addPlugin(
          session,
          files,
          trackId,
          fixture.path,
          instrument: fixture.instrument,
        );
        expect(retiredNodeIds, isNot(contains(added.node.id)));
        expect(_parameter(added.node, 'Gain').parameterValue, 0.25);
        expect(_parameter(added.node, 'Invert').parameterValue, 0);
        await _liveState(session, added.node);
        await tester.pump();
        expect(find.byType(Vst3Device), findsOneWidget);
        await session.writeSessionDiagnostics(
          'loaded-$attempt-${fixture.instrument ? 'instrument' : 'effect'}',
          additionalDiagnostics: {
            'deviceId': added.device.id,
            'nodeId': added.node.id,
            'pluginPath': fixture.path,
            'pluginState': await _liveState(session, added.node),
          },
        );
        session.services.deviceController.removeDevice(
          trackId: trackId,
          deviceId: added.device.id,
        );
        await publishPluginGraph(session);
        expect(
          session.project.processingGraph.nodes.containsKey(added.node.id),
          isFalse,
        );
        expect(
          session.project.tracks[trackId]!.requireProcessing.devices,
          isEmpty,
        );
        await session.waitForEngineModel(
          conditionDescription:
              'removed plugin ${added.node.id} absent from engine',
          matches: (model) =>
              !((model['processingGraph'] as Map)['nodes'] as Map).containsKey(
                added.node.id.toString(),
              ),
        );
        await tester.pump();
        expect(find.byType(Vst3Device), findsNothing);
        retiredNodeIds.add(added.node.id);
      }
    }
    expect(files.pluginSelectionCount, 4);
    await session.dispose();
  });

  testAppScenario('save and reopen actual VST3 parameters and opaque state', (
    tester,
  ) async {
    final fixtures = loadTestPlugins();
    final files = await TestPluginFileSelector.install(
      'plugin-persistence',
      fixtures,
    );
    final session = AppTestSession(tester, name: 'plugin-persistence');
    await session.start();
    final original = session.project;
    final trackId = original.trackOrder.first;
    await _prepareRack(session, trackId);
    final instrument = await _addPlugin(
      session,
      files,
      trackId,
      fixtures.instrument,
      instrument: true,
    );
    final effect = await _addPlugin(
      session,
      files,
      trackId,
      fixtures.effect,
      instrument: false,
    );
    final expectedStates = <Id, String>{};
    for (final fixture in [
      (node: instrument.node, gain: 0.625),
      (node: effect.node, gain: 0.75),
    ]) {
      final baseline = await _liveState(session, fixture.node);
      _setParameter(session, fixture.node, 'Gain', 0.5);
      await _liveState(
        session,
        fixture.node,
      ); // Flush through the real VST3 host.
      _setParameter(session, fixture.node, 'Gain', 0.25);
      final cycled = await _liveState(session, fixture.node);
      expect(_parameter(fixture.node, 'Gain').parameterValue, 0.25);
      expect(
        cycled,
        isNot(baseline),
        reason:
            'Gain is back at default, but the opaque revision counter changed.',
      );
      _setParameter(session, fixture.node, 'Gain', fixture.gain);
      _setParameter(session, fixture.node, 'Invert', 1);
      expectedStates[fixture.node.id] = await _liveState(session, fixture.node);
    }
    expect(original.isDirty, isTrue);
    files.projectFiles.selectedSavePath = files.projectFiles.pathFor(
      'plugin-state',
    );
    expect(
      await waitForFuture(
        tester,
        ServiceRegistry.mainWindowController.saveProject(
          original.id,
          true,
          dialogController: ServiceRegistry.dialogController,
        ),
        conditionDescription:
            'Save As collects current plugin states and writes project',
        collectTimeoutDiagnostics: () => session.sessionDiagnostics,
      ),
      isTrue,
    );
    final savedPath = files.projectFiles.pathFor('plugin-state.anthem');
    expect(original.isDirty, isFalse);
    for (final entry in expectedStates.entries) {
      expect(
        original.processingGraph.nodes[entry.key]!.processorState,
        entry.value,
      );
    }
    await File(savedPath)
        .copy('${session.artifacts.path}/saved-plugin-project.anthem');
    await session.writeSessionDiagnostics(
      'saved',
      additionalDiagnostics: {
        'pluginStates': expectedStates.map(
          (id, state) => MapEntry(id.toString(), state),
        ),
      },
    );
    final previousPid = original.engine.processId;
    expect(
      await waitForFuture(
        tester,
        session.services.projectController.close(),
        conditionDescription: 'close plugin project',
        collectTimeoutDiagnostics: () => session.sessionDiagnostics,
      ),
      isTrue,
    );
    await waitForFuture(
      tester,
      original.engine.dispose(),
      conditionDescription: 'old plugin engine exited',
      collectTimeoutDiagnostics: () => session.sessionDiagnostics,
    );
    expect(original.engine.processExitCode, isNotNull);
    expect(AnthemStore.instance.projects, isEmpty);

    files.projectFiles.selectedOpenPath = savedPath;
    final reopened = await session.openProjectFromFile();
    expect(reopened, isNotNull);
    expect(reopened, isNot(same(original)));
    expect(reopened!.engine.processId, isNot(previousPid));
    expect(reopened.isDirty, isFalse);
    _showRack(session, trackId);
    await startOfflinePluginProcessing(session);
    for (final fixture in [
      (id: instrument.node.id, instrument: true, gain: 0.625),
      (id: effect.node.id, instrument: false, gain: 0.75),
    ]) {
      final restored = reopened.processingGraph.nodes[fixture.id]!;
      await _verifyPlugin(session, restored, instrument: fixture.instrument);
      expect(restored, isNot(same(original.processingGraph.nodes[fixture.id])));
      expect(
        await _liveState(session, restored),
        expectedStates[fixture.id],
        reason: 'A fresh native instance must restore both parameters and opaque revision state.',
      );
      await waitUntil(
        tester,
        conditionDescription:
            'restored plugin parameter snapshot returned to Flutter',
        isReady: () =>
            _parameter(restored, 'Gain').parameterValue == fixture.gain &&
            _parameter(restored, 'Invert').parameterValue == 1,
        collectTimeoutDiagnostics: () => restored.toJson(),
        checkHealth: session.checkEngine,
      );
    }
    expect(
      reopened.tracks[trackId]!.requireProcessing.devices.map(
        (device) => device.id,
      ),
      [instrument.device.id, effect.device.id],
    );
    expect(reopened.isDirty, isFalse);
    await tester.pump();
    expect(find.byType(Vst3Device), findsNWidgets(2));
    expect(
      files.pluginSelectionCount,
      2,
      reason:
          'Reopen restores plugin paths without asking for selection again.',
    );
    await session.writeSessionDiagnostics(
      'reopened',
      additionalDiagnostics: {
        'previousEnginePid': previousPid,
        'previousEngineExitCode': original.engine.processExitCode,
      },
    );
    await session.dispose();
  });
}
