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

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/model/processing_graph/node_connection.dart';
import 'package:anthem/model/processing_graph/processors/sequence_automation_provider.dart';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/project_file/codec.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:anthem/logic/commands/parameter_commands.dart';
import 'package:anthem/logic/commands/processor_state_commands.dart';
import 'package:anthem/logic/commands/track_commands.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/device.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/parameter_config.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
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
    await session.services.deviceController.removeDevice(
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

NodePortModel _parameter(NodeModel node, String name) => node.controlInputPorts
    .singleWhere((port) => port.isAvailable && port.config.name == name);

/// Captures state and hashes the file's bytes for equality assertions.
Future<String> _captureStateHash(AppTestSession session, NodeModel node) async {
  await waitForFuture(
    session.tester,
    node.updateStateFromEngine(),
    conditionDescription: 'capture state file of plugin ${node.id}',
    collectTimeoutDiagnostics: () => session.sessionDiagnostics,
    checkHealth: session.checkEngine,
  );
  expect(
    node.processorStateRetentionId,
    isNotNull,
    reason: 'A real VST3 instance must provide state.',
  );
  final store = await session.services.projectStorage.assetStore;
  final scope = store.openScope();
  try {
    final read = scope.acquireRead(
      store.resolveRetention(node.processorStateRetentionId!),
    );
    return sha256
        .convert(await File(read.absolutePath).readAsBytes())
        .toString();
  } finally {
    await scope.close();
  }
}

Future<void> _setParameter(
  AppTestSession session,
  NodeModel node,
  String name,
  double value,
) {
  final port = _parameter(node, name);
  return session.project.execute(
    SetParameterValueCommand(
      nodeId: node.id,
      controlPortId: port.id,
      oldValue: port.parameterValueOrResetTarget,
      newValue: value,
    ),
  );
}

Future<void> _verifyPlugin(
  AppTestSession session,
  NodeModel node, {
  required bool instrument,
}) async {
  await waitUntil(
    session.tester,
    conditionDescription: 'plugin ${node.id} initialization completed',
    isReady: () =>
        node.initializationState != NodeInitializationState.uninitialized,
    collectTimeoutDiagnostics: () => session.sessionDiagnostics,
    checkHealth: session.checkEngine,
  );
  expect(node.initializationState, NodeInitializationState.ready);
  expect(node.processor, isA<VST3ProcessorModel>());
  expect(
    node.audioInputPorts.where((port) => port.isAvailable),
    hasLength(instrument ? 0 : 1),
  );
  expect(node.audioOutputPorts.where((port) => port.isAvailable), hasLength(1));
  expect(node.audioOutputPorts.single.config.channelCount, 2);
  expect(
    node.eventInputPorts.where((port) => port.isAvailable),
    hasLength(instrument ? 1 : 0),
  );
  expect(node.eventOutputPorts.where((port) => port.isAvailable), isEmpty);
  expect(
    node.controlInputPorts
        .where((port) => port.isAvailable)
        .map((port) => port.config.name),
    unorderedEquals(['Gain', 'Invert', 'State size', 'Bypass']),
  );
  expect(
    node.controlInputPorts
        .where((port) => port.isAvailable)
        .map((port) => port.id)
        .toSet(),
    hasLength(4),
  );
  await session.waitForEngineModel(
    conditionDescription: 'engine discovered plugin ${node.id} ports',
    matches: (model) {
      final engineNode =
          ((model['processingGraph'] as Map)['nodes'] as Map)[node.id
                  .toString()]
              as Map?;
      return engineNode != null &&
          (engineNode['audioInputPorts'] as List)
                  .where((port) => port['isAvailable'] == true)
                  .length ==
              (instrument ? 0 : 1) &&
          (engineNode['audioOutputPorts'] as List)
                  .where((port) => port['isAvailable'] == true)
                  .length ==
              1 &&
          (engineNode['eventInputPorts'] as List)
                  .where((port) => port['isAvailable'] == true)
                  .length ==
              (instrument ? 1 : 0) &&
          (engineNode['controlInputPorts'] as List)
                  .where((port) => port['isAvailable'] == true)
                  .length ==
              4;
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

/// Renders a tone through the track chain and measures its output.
Future<double> _renderRms(
  AppTestSession session,
  TestPluginFileSelector files,
  int renderId,
) async {
  final outputPath = files.projectFiles.pathFor('render-$renderId.wav');
  final result = await waitForFuture(
    session.tester,
    session.services.processingGraphController.runRender((_) async {
      final completion = Completer<IpcEvent>();
      final subscription = session.project.engine.renderApi.events.listen((
        event,
      ) {
        if (event is RenderCompletedEvent && event.renderId == renderId ||
            event is RenderFailedEvent && event.renderId == renderId) {
          completion.complete(event);
        }
      });
      try {
        await session.project.engine.renderApi.renderAudio(
          renderId: renderId,
          outputPath: outputPath,
          format: RenderAudioFormat.wav,
          startTick: 0,
          endTick: 96,
          includeTail: false,
          bitDepth: 32,
          qualityOptionIndex: 0,
          sampleFormat: RenderAudioSampleFormat.floatingPoint,
        );
        return await completion.future;
      } finally {
        await subscription.cancel();
      }
    }),
    conditionDescription: 'render parameter-state audio',
    collectTimeoutDiagnostics: () => session.sessionDiagnostics,
    checkHealth: session.checkEngine,
  );
  expect(result, isA<RenderCompletedEvent>());
  final bytes = await File(outputPath).readAsBytes();
  final data = ByteData.sublistView(bytes);
  expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF');
  expect(ascii.decode(bytes.sublist(8, 12)), 'WAVE');
  for (var offset = 12; offset + 8 <= bytes.length;) {
    final length = data.getUint32(offset + 4, Endian.little);
    if (ascii.decode(bytes.sublist(offset, offset + 4)) == 'data') {
      expect(length, greaterThan(0));
      var squares = 0.0;
      final end = offset + 8 + length;
      for (var sample = offset + 8; sample < end; sample += 4) {
        final value = data.getFloat32(sample, Endian.little);
        squares += value * value;
      }
      return math.sqrt(squares / (length ~/ 4));
    }
    offset += 8 + length + (length % 2);
  }
  throw StateError('Rendered WAV has no audio data.');
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
        await _captureStateHash(session, added.node);
        await tester.pump();
        expect(find.byType(Vst3Device), findsOneWidget);
        await session.writeSessionDiagnostics(
          'loaded-$attempt-${fixture.instrument ? 'instrument' : 'effect'}',
          additionalDiagnostics: {
            'deviceId': added.device.id,
            'nodeId': added.node.id,
            'pluginPath': fixture.path,
            'pluginState': await _captureStateHash(session, added.node),
          },
        );
        await waitForFuture(
          tester,
          session.services.deviceController.removeDevice(
            trackId: trackId,
            deviceId: added.device.id,
          ),
          conditionDescription: 'capture and remove plugin ${added.node.id}',
          collectTimeoutDiagnostics: () => session.sessionDiagnostics,
          checkHealth: session.checkEngine,
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

  testAppScenario('undo and deletion capture plugin state before removing it', (
    tester,
  ) async {
    final fixtures = loadTestPlugins();
    final files = await TestPluginFileSelector.install(
      'plugin-removal',
      fixtures,
    );
    final session = AppTestSession(tester, name: 'plugin-removal');
    await session.start();
    final trackId = session.project.trackOrder.first;
    await _prepareRack(session, trackId);
    final added = await _addPlugin(
      session,
      files,
      trackId,
      fixtures.instrument,
      instrument: true,
    );
    await _captureStateHash(session, added.node);
    final initialRetentionId = added.node.processorStateRetentionId;

    // Change the plugin without adding a parameter command to host history.
    // Undo therefore reaches device addition while this state is still live.
    await ServiceRegistry.forProject(session.project.id).parameterController
        .setValue(
          node: added.node,
          port: _parameter(added.node, 'Gain'),
          value: 0.73,
        );
    await waitUntil(
      tester,
      conditionDescription: 'plugin gain changed without a host undo command',
      isReady: () =>
          (_parameter(added.node, 'Gain').parameterValue! - 0.73).abs() <
          0.0001,
      collectTimeoutDiagnostics: () => session.sessionDiagnostics,
      checkHealth: session.checkEngine,
    );
    await waitForFuture(
      tester,
      session.project.undo(),
      conditionDescription: 'undo addition after capturing live plugin state',
      collectTimeoutDiagnostics: () => session.sessionDiagnostics,
      checkHealth: session.checkEngine,
    );
    expect(
      session.project.processingGraph.nodes,
      isNot(contains(added.node.id)),
    );
    expect(added.node.processorStateRetentionId, isNull);
    await publishPluginGraph(session);
    await session.project.redo();
    await publishPluginGraph(session);
    await _verifyPlugin(session, added.node, instrument: true);
    expect(
      _parameter(added.node, 'Gain').parameterValue,
      closeTo(0.73, 0.0001),
    );
    await _captureStateHash(session, added.node);
    expect(added.node.processorStateRetentionId, isNot(initialRetentionId));

    await ServiceRegistry.forProject(session.project.id).parameterController
        .setValue(
          node: added.node,
          port: _parameter(added.node, 'Gain'),
          value: 0.41,
        );
    await waitUntil(
      tester,
      conditionDescription: 'plugin gain changed before explicit deletion',
      isReady: () =>
          (_parameter(added.node, 'Gain').parameterValue! - 0.41).abs() <
          0.0001,
      collectTimeoutDiagnostics: () => session.sessionDiagnostics,
      checkHealth: session.checkEngine,
    );
    await waitForFuture(
      tester,
      session.services.deviceController.removeDevice(
        trackId: trackId,
        deviceId: added.device.id,
      ),
      conditionDescription: 'capture plugin state before explicit deletion',
      collectTimeoutDiagnostics: () => session.sessionDiagnostics,
      checkHealth: session.checkEngine,
    );
    expect(added.node.processorStateRetentionId, isNull);
    await publishPluginGraph(session);
    await session.project.undo();
    await publishPluginGraph(session);
    await _verifyPlugin(session, added.node, instrument: true);
    expect(
      _parameter(added.node, 'Gain').parameterValue,
      closeTo(0.41, 0.0001),
    );
    await session.dispose();
  });

  testAppScenario(
    'unavailable plugin parameter preserves its automation through discovery and restart',
    (tester) async {
      final fixtures = loadTestPlugins();
      final files = await TestPluginFileSelector.install(
        'unavailable-plugin-parameter',
        fixtures,
      );
      final session = AppTestSession(
        tester,
        name: 'unavailable-plugin-parameter',
      );
      await session.start();
      final project = session.project;
      final trackId = project.trackOrder.first;
      await _prepareRack(session, trackId);
      final added = await _addPlugin(
        session,
        files,
        trackId,
        fixtures.instrument,
        instrument: true,
      );
      const missingId = 987654321;
      final cached = NodePortModel(
        id: missingId,
        nodeId: added.node.id,
        config: NodePortConfigModel(
          dataType: NodePortDataType.control,
          name: 'Unavailable parameter',
          parameterConfig: ParameterConfigModel(
            id: missingId,
            factoryDefaultValue: 0.5,
            normalizedVisualBaseline: 0.25,
          ),
        ),
        initialParameterValue: 0.456,
        parameterResetValue: 0.3,
      );
      added.node.controlInputPorts.add(cached);
      final command = AutomationLaneAddRemoveCommand.add(
        project: project,
        parentTrackId: trackId,
        nodeId: added.node.id,
        portId: missingId,
        name: 'Retained automation',
      );
      project.execute(command);
      await publishPluginGraph(session);
      final connectionIds = cached.connections.toSet();
      expect(connectionIds, isNotEmpty);
      await _captureStateHash(session, added.node);
      await waitForFuture(
        tester,
        session.services.projectEngineController.stop(),
        conditionDescription: 'stop engine while retaining project routing',
        collectTimeoutDiagnostics: () => session.sessionDiagnostics,
      );
      await waitForFuture(
        tester,
        session.services.projectEngineController.start(startAudio: false),
        conditionDescription:
            'restart engine with cached unavailable parameter',
        collectTimeoutDiagnostics: () => session.sessionDiagnostics,
      );
      await startOfflinePluginProcessing(session);
      expect(
        added.node.getInputPortById(NodePortDataType.control, missingId),
        same(cached),
      );
      expect(cached.isAvailable, isFalse);
      expect(cached.connections.toSet(), connectionIds);
      expect(cached.parameterValue, 0.456);
      expect(cached.parameterResetTarget, 0.3);
      expect(cached.config.parameterConfig!.normalizedVisualBaseline, 0.25);
      expect(
        project.tracks[command.lane.id]!.automationTarget!.portId,
        missingId,
      );
      for (final id in connectionIds) {
        expect(project.processingGraph.connections, contains(id));
        expect(
          project.processingGraph.isConnectionResolved(
            project.processingGraph.connections[id]!,
          ),
          isFalse,
        );
      }
      await session.waitForEngineModel(
        conditionDescription: 'engine retained suspended routing',
        matches: (model) {
          final graph = model['processingGraph'] as Map;
          final node = (graph['nodes'] as Map)[added.node.id.toString()] as Map;
          final port = (node['controlInputPorts'] as List).singleWhere(
            (port) => port['id'] == missingId,
          ) as Map;
          return port['isAvailable'] == false &&
              (port['connections'] as List).toSet().containsAll(
                connectionIds,
              ) &&
              connectionIds.every(
                (id) =>
                    (graph['connections'] as Map).containsKey(id.toString()),
              );
        },
      );
      await session.writeSessionDiagnostics(
        'unavailable-parameter',
        additionalDiagnostics: {
          'port': cached.toJson(),
          'automationLane': command.lane.toJson(),
        },
      );
    },
  );

  testAppScenario(
    'VST automation preserves the base value across capture and restart',
    (tester) async {
      final fixtures = loadTestPlugins();
      final files = await TestPluginFileSelector.install(
        'plugin-base-value',
        fixtures,
      );
      final session = AppTestSession(tester, name: 'plugin-base-value');
      await session.start();
      final project = session.project;
      final trackId = project.trackOrder.first;
      await startOfflinePluginProcessing(session);
      await waitForFuture(
        tester,
        session.services.deviceController.addDevice(
          trackId: trackId,
          type: DeviceType.toneGenerator,
        ),
        conditionDescription: 'add tone source for the effect',
        collectTimeoutDiagnostics: () => session.sessionDiagnostics,
        checkHealth: session.checkEngine,
      );
      await publishPluginGraph(session);
      final effect = await _addPlugin(
        session,
        files,
        trackId,
        fixtures.effect,
        instrument: false,
      );
      final gain = _parameter(effect.node, 'Gain');
      expect(gain.parameterValue, 0.25);
      final baseRms = await _renderRms(session, files, 1);
      expect(baseRms, greaterThan(0.001));

      final provider = SequenceAutomationProviderProcessorModel.create(
        idAllocator: project.idAllocator,
        trackId: trackId,
        emptyValue: 0.8,
      ).createNode();
      project.processingGraph.addNode(provider);
      final connection = NodeConnectionModel(
        idAllocator: project.idAllocator,
        sourceNodeId: provider.id,
        sourcePortId:
            SequenceAutomationProviderProcessorModel.controlOutputPortId,
        destinationNodeId: effect.node.id,
        destinationPortId: gain.id,
        dataType: NodePortDataType.control,
      );
      project.processingGraph.addConnection(connection);
      await publishPluginGraph(session);
      final controlledRms = await _renderRms(session, files, 2);
      expect(controlledRms / baseRms, closeTo(3.2, 0.02));
      expect(gain.parameterValue, 0.25);
      await _captureStateHash(session, effect.node);
      final savedRetention = effect.node.processorStateRetentionId;

      project.processingGraph.removeConnection(connection.id);
      await publishPluginGraph(session);
      final disconnectedRms = await _renderRms(session, files, 3);
      expect(disconnectedRms / baseRms, closeTo(1, 0.01));
      expect(effect.node.processorStateRetentionId, savedRetention);
      await waitForFuture(
        tester,
        session.services.projectEngineController.stop(),
        conditionDescription: 'stop engine after capturing automated plugin',
        collectTimeoutDiagnostics: () => session.sessionDiagnostics,
      );
      await waitForFuture(
        tester,
        session.services.projectEngineController.start(startAudio: false),
        conditionDescription: 'restore snapshot captured during automation',
        collectTimeoutDiagnostics: () => session.sessionDiagnostics,
      );
      await startOfflinePluginProcessing(session);
      expect(gain.parameterValue, 0.25);
      final restoredRms = await _renderRms(session, files, 4);
      expect(restoredRms / baseRms, closeTo(1, 0.01));
    },
  );

  for (final undoable in [false, true]) {
    final scenarioName = undoable
        ? 'plugin-snapshot-undo'
        : 'plugin-snapshot-load';
    testAppScenario(
      undoable
          ? 'undoable VST snapshots restore live parameters and private state'
          : 'retained VST snapshots restore live parameters and private state',
      (tester) async {
        final fixtures = loadTestPlugins();
        final files = await TestPluginFileSelector.install(
          scenarioName,
          fixtures,
        );
        final session = AppTestSession(tester, name: scenarioName);
        await session.start();
        final project = session.project;
        final trackId = project.trackOrder.first;
        await startOfflinePluginProcessing(session);
        await waitForFuture(
          tester,
          session.services.deviceController.addDevice(
            trackId: trackId,
            type: DeviceType.toneGenerator,
          ),
          conditionDescription: 'add tone source for snapshot test',
          collectTimeoutDiagnostics: () => session.sessionDiagnostics,
          checkHealth: session.checkEngine,
        );
        await publishPluginGraph(session);
        final effect = await _addPlugin(
          session,
          files,
          trackId,
          fixtures.effect,
          instrument: false,
        );
        final api = session.services.processingGraphController;
        final baseline = await _captureStateHash(session, effect.node);
        final baseRms = await _renderRms(session, files, 1);
        expect(baseRms, greaterThan(0.001));
        final snapshot = await waitForFuture(
          tester,
          api.saveSnapshot(effect.node.id),
          conditionDescription: 'save independently retained VST state',
          collectTimeoutDiagnostics: () => session.sessionDiagnostics,
          checkHealth: session.checkEngine,
        );
        addTearDown(snapshot.dispose);
        for (var iteration = 0; iteration < 2; ++iteration) {
          await _setParameter(session, effect.node, 'Gain', 0.75);
          final changed = await _captureStateHash(session, effect.node);
          expect(changed, isNot(baseline));
          expect(
            await _renderRms(session, files, 2 + iteration * 2) / baseRms,
            closeTo(3, 0.02),
          );
          await waitForFuture(
            tester,
            undoable
                ? project.execute(
                    LoadProcessorSnapshotCommand(
                      nodeId: effect.node.id,
                      snapshot: snapshot,
                    ),
                  )
                : api.loadSnapshot(effect.node.id, snapshot),
            conditionDescription:
                'replace live VST state and reconcile its graph',
            collectTimeoutDiagnostics: () => session.sessionDiagnostics,
            checkHealth: session.checkEngine,
          );
          expect(_parameter(effect.node, 'Gain').parameterValue, 0.25);
          expect(
            await _captureStateHash(session, effect.node),
            baseline,
            reason: 'Loading must restore the private revision counter as well as values.',
          );
          expect(
            await _renderRms(session, files, 3 + iteration * 2) / baseRms,
            closeTo(1, 0.01),
          );
          if (undoable) {
            await waitForFuture(
              tester,
              project.undo(),
              conditionDescription: 'undo the VST snapshot load',
              collectTimeoutDiagnostics: () => session.sessionDiagnostics,
              checkHealth: session.checkEngine,
            );
            expect(_parameter(effect.node, 'Gain').parameterValue, 0.75);
            expect(await _captureStateHash(session, effect.node), changed);
            expect(
              await _renderRms(session, files, 10 + iteration * 2) / baseRms,
              closeTo(3, 0.02),
            );
            await waitForFuture(
              tester,
              project.redo(),
              conditionDescription: 'redo the VST snapshot load',
              collectTimeoutDiagnostics: () => session.sessionDiagnostics,
              checkHealth: session.checkEngine,
            );
            expect(_parameter(effect.node, 'Gain').parameterValue, 0.25);
            expect(await _captureStateHash(session, effect.node), baseline);
            expect(
              await _renderRms(session, files, 11 + iteration * 2) / baseRms,
              closeTo(1, 0.01),
            );
          }
          expect(snapshot.isDisposed, isFalse);
        }
      },
    );
  }

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
    await _setParameter(session, instrument.node, 'State size', 1);
    final expectedStates = <Id, String>{};
    for (final fixture in [
      (node: instrument.node, gain: 0.625),
      (node: effect.node, gain: 0.75),
    ]) {
      final baseline = await _captureStateHash(session, fixture.node);
      await _setParameter(session, fixture.node, 'Gain', 0.5);
      await _captureStateHash(
        session,
        fixture.node,
      ); // Flush through the real VST3 host.
      await _setParameter(session, fixture.node, 'Gain', 0.25);
      final cycled = await _captureStateHash(session, fixture.node);
      expect(_parameter(fixture.node, 'Gain').parameterValue, 0.25);
      expect(
        cycled,
        isNot(baseline),
        reason:
            'Gain is back at default, but the opaque revision counter changed.',
      );
      await _setParameter(session, fixture.node, 'Gain', fixture.gain);
      await _setParameter(session, fixture.node, 'Invert', 1);
      expectedStates[fixture.node.id] = await _captureStateHash(
        session,
        fixture.node,
      );
    }
    final firstRetentionId = instrument.node.processorStateRetentionId;
    original.isDirty = false;
    expect(
      await _captureStateHash(session, instrument.node),
      expectedStates[instrument.node.id],
    );
    expect(instrument.node.processorStateRetentionId, firstRetentionId);
    expect(
      original.isDirty,
      isFalse,
      reason: 'Unchanged capture must reuse the state file.',
    );
    final workingStore = await session.services.projectStorage.assetStore;
    expect(
      await File(
        path.join(
          workingStore.rootDirectory,
          workingStore.resolveRetention(firstRetentionId!),
        ),
      ).length(),
      greaterThan(1024 * 1024),
    );
    final previousEffectRetentionId = effect.node.processorStateRetentionId;
    final pending = Directory(
      path.join(workingStore.rootDirectory, '.pending'),
    );
    final parkedPending = await pending.rename('${pending.path}-parked');
    final blockedPending = File(pending.path);
    await blockedPending.writeAsString('block new state writes');
    try {
      await _setParameter(session, effect.node, 'Gain', 0.875);
      Object? captureError;
      try {
        await waitForFuture(
          tester,
          effect.node.updateStateFromEngine(),
          conditionDescription: 'failed state write returns an error',
          collectTimeoutDiagnostics: () => session.sessionDiagnostics,
          checkHealth: session.checkEngine,
        );
      } catch (error) {
        captureError = error;
      }
      expect(captureError, isA<StateError>());
      expect(effect.node.processorStateRetentionId, previousEffectRetentionId);
    } finally {
      await blockedPending.delete();
      await parkedPending.rename(pending.path);
    }
    await _setParameter(session, effect.node, 'Gain', 0.75);
    expectedStates[effect.node.id] = await _captureStateHash(
      session,
      effect.node,
    );
    await files.projectFiles.useTemporaryProjectsDirectory();
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
    final savedPath = files.projectFiles.pathFor(
      'plugin-state/plugin-state.anthem',
    );
    expect(original.isDirty, isFalse);
    final savedJson = await readProjectFile(savedPath);
    for (final fixture in [instrument.node, effect.node]) {
      final savedNode =
          savedJson['processingGraph']['nodes'][fixture.id.toString()] as Map;
      expect(savedNode, isNot(contains('processorState')));
      expect(
        savedNode['processorStateRetentionId'],
        fixture.processorStateRetentionId,
      );
      expect(
        await File(
          path.join(
            path.dirname(savedPath),
            jsonDecode(
                  savedJson['fileRetentions'],
                )[fixture.processorStateRetentionId]
                as String,
          ),
        ).exists(),
        isTrue,
      );
    }
    expect(
      await File(savedPath).length(),
      lessThan(64 * 1024),
      reason: 'The document must not embed plugin state.',
    );
    for (final entry in expectedStates.entries) {
      expect(
        await _captureStateHash(
          session,
          original.processingGraph.nodes[entry.key]!,
        ),
        entry.value,
      );
    }
    final savedArtifact = Directory(
      path.join(session.artifacts.path, 'saved-plugin-project'),
    );
    await savedArtifact.create();
    await File(savedPath)
        .copy(path.join(savedArtifact.path, 'plugin-state.anthem'));
    for (final node in [instrument.node, effect.node]) {
      final relativePath =
          jsonDecode(
                savedJson['fileRetentions'],
              )[node.processorStateRetentionId]
              as String;
      final destination = File(path.join(savedArtifact.path, relativePath));
      await destination.parent.create(recursive: true);
      await File(path.join(path.dirname(savedPath), relativePath))
          .copy(destination.path);
    }
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
    expect(original.engine.processExitCode, 0);
    expect(AnthemStore.instance.projects, isEmpty);

    files.projectFiles.selectedOpenPath = savedPath;
    final reopened = await session.openProjectFromFile();
    expect(reopened, isNotNull);
    expect(reopened, isNot(same(original)));
    expect(reopened!.engine.processId, isNot(previousPid));
    expect(reopened.isDirty, isFalse);
    _showRack(session, trackId);
    await startOfflinePluginProcessing(session);
    final reopenedStore = await session.services.projectStorage.assetStore;
    final storedFileCount = reopenedStore.relativePaths.length;
    for (final fixture in [
      (id: instrument.node.id, instrument: true, gain: 0.625),
      (id: effect.node.id, instrument: false, gain: 0.75),
    ]) {
      final restored = reopened.processingGraph.nodes[fixture.id]!;
      await _verifyPlugin(session, restored, instrument: fixture.instrument);
      final previousStateRetentionId = restored.processorStateRetentionId;
      await waitForFuture(
        tester,
        restored.updateStateFromEngine(),
        conditionDescription: 'unchanged plugin state reuses its saved file',
        collectTimeoutDiagnostics: () => session.sessionDiagnostics,
      );
      expect(restored.processorStateRetentionId, previousStateRetentionId);
      expect(restored, isNot(same(original.processingGraph.nodes[fixture.id])));
      expect(
        await _captureStateHash(session, restored),
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
    expect(reopenedStore.relativePaths.length, storedFileCount);
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
