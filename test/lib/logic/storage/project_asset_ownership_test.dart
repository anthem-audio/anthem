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

@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/logic/commands/track_commands.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/logic/commands/device_commands.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/logic/devices/device_factory.dart';
import 'package:anthem/model/device.dart';
import 'package:anthem/logic/storage/project_asset_store.dart';
import 'package:anthem/logic/storage/project_storage.dart';
import 'package:anthem/model/project.dart';
import 'package:flutter_test/flutter_test.dart';

class _OfflineGraphApi extends Fake implements ProcessingGraphApi {
  Future<String?> Function()? capture;

  @override
  Future<String?> captureProcessorState(int nodeId) => capture!();

  @override
  Future<void> waitForPendingParameterEdits(int nodeId) async {}

  @override
  Future<ProcessingGraphNodeInitialization> initializeNodes() async =>
      ProcessingGraphNodeInitialization(didInitialize: false, results: []);
}

class _RunningEngine extends Fake implements Engine {
  @override
  final ProcessingGraphApi processingGraphApi;

  _RunningEngine(this.processingGraphApi);

  @override
  bool get isRunning => true;

  @override
  final Future<void> sessionEnded = Future.value();

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProjectModel project;
  late ProjectStorage storage;
  late ProjectAssetStore store;
  late AssetScope scope;

  setUp(() async {
    project = ProjectModel.create();
    project.engine.processingGraphApi = _OfflineGraphApi();
    storage = ProjectStorage.temporary();
    ServiceRegistry.initializeProject(
      project,
      overrides: ProjectServiceFactoryOverrides([
        overrideService(projectStorageService, (_, _) => storage),
      ]),
    );
    store = await storage.assetStore;
    scope = store.openScope();
  });

  tearDown(() async {
    await scope.close();
    await project.dispose();
    await storage.discard();
    ServiceRegistry.removeProject(project.id);
  });

  Future<String> state() async {
    final write = await scope.beginWrite('plugin states', extension: 'bin');
    await File(write.absolutePath).writeAsBytes([1, 2, 3]);
    return scope.commitWrite(write.token);
  }

  void useState(NodeModel node, String? relativePath) {
    final previous = node.processorStateRetentionId;
    node.processorStateRetentionId = relativePath == null
        ? null
        : storage.projectFiles.retain(relativePath);
    if (previous != null) storage.projectFiles.releaseRetention(previous);
  }

  String? statePath(NodeModel node) => node.processorStateRetentionId == null
      ? null
      : storage.resolveRetention(node.processorStateRetentionId!);

  NodeModel addPlugin() {
    final track = project.tracks[project.trackOrder.first]!;
    project.execute(
      DeviceAddRemoveCommand.add(
        project: project,
        trackId: track.id,
        device: DeviceDescriptorForCommand(
          type: DeviceType.vst3Plugin,
          vst3Path: '/test.vst3',
        ),
      ),
    );
    final device = track.requireProcessing.devices.last;
    return project.processingGraph.nodes[device.nodeIds.single]!;
  }

  _OfflineGraphApi startEngine(NodeModel node) {
    final previousEngine = project.engine;
    addTearDown(previousEngine.dispose);
    final api = _OfflineGraphApi();
    project.engine = _RunningEngine(api);
    node.markInitialized();
    return api;
  }

  test('removing a device retains its state for undo and redo, but excludes it from saves', () async {
    final file = await state();
    final track = project.tracks[project.trackOrder.first]!;
    project.execute(
      DeviceAddRemoveCommand.add(
        project: project,
        trackId: track.id,
        device: DeviceDescriptorForCommand(
          type: DeviceType.vst3Plugin,
          vst3Path: '/test.vst3',
        ),
      ),
    );
    final device = track.requireProcessing.devices.first;
    final node = project.processingGraph.nodes[device.nodeIds.first]!;
    useState(node, file);
    final originalRetentionId = node.processorStateRetentionId;
    project.execute(
      DeviceAddRemoveCommand.remove(
        project: project,
        trackId: track.id,
        deviceId: device.id,
      ),
    );
    final removed = storage.projectFiles.snapshot();
    expect(removed.reads, isEmpty);
    expect(node.processorStateRetentionId, isNull);
    expect(
      () => storage.resolveRetention(originalRetentionId!),
      throwsStateError,
    );
    await removed.close();
    expect(() => scope.delete(file), throwsStateError);
    project.undo();
    expect(statePath(project.processingGraph.nodes[node.id]!), file);
    expect(node.processorStateRetentionId, isNot(originalRetentionId));
    project.redo();
    expect(project.processingGraph.nodes, isNot(contains(node.id)));
    expect(() => scope.delete(file), throwsStateError);
    project.undo();
    project.undo();
    project.execute(
      DeviceAddRemoveCommand.add(
        project: project,
        trackId: track.id,
        device: DeviceDescriptorForCommand(type: DeviceType.utility),
      ),
    );
    await scope.delete(file);
  });

  test(
    'discarding a removal command preserves a restored node claim',
    () async {
      final file = await state();
      final node = addPlugin();
      useState(node, file);
      final track = project.tracks[project.trackOrder.first]!;
      final device = track.requireProcessing.devices.last;
      await project.execute(
        DeviceAddRemoveCommand.remove(
          project: project,
          trackId: track.id,
          deviceId: device.id,
        ),
      );
      await project.undo();
      final restoredId = node.processorStateRetentionId;
      await project.execute(
        DeviceAddRemoveCommand.add(
          project: project,
          trackId: track.id,
          device: DeviceDescriptorForCommand(type: DeviceType.utility),
        ),
      );
      expect(node.processorStateRetentionId, restoredId);
      expect(storage.resolveRetention(restoredId!), file);
      expect(() => scope.delete(file), throwsStateError);
    },
  );

  test('nodes sharing a file keep independent claims across removal', () async {
    final file = await state();
    final first = addPlugin();
    final second = addPlugin();
    useState(first, file);
    useState(second, file);
    final firstId = first.processorStateRetentionId;
    final secondId = second.processorStateRetentionId;
    expect(secondId, isNot(firstId));
    final track = project.tracks[project.trackOrder.first]!;
    await project.execute(
      DeviceAddRemoveCommand.remove(
        project: project,
        trackId: track.id,
        deviceId: track.requireProcessing.devices.last.id,
      ),
    );
    expect(storage.resolveRetention(firstId!), file);
    expect(second.processorStateRetentionId, isNull);
    expect(() => scope.delete(file), throwsStateError);
    await project.undo();
    expect(statePath(second), file);
    expect(second.processorStateRetentionId, isNot(secondId));
    expect(first.processorStateRetentionId, firstId);
    expect(storage.resolveRetention(second.processorStateRetentionId!), file);
  });

  test('undoing addition captures before removal and releases obsolete claims after redo', () async {
    final original = await state();
    final latest = await state();
    final subsequent = await state();
    final node = addPlugin();
    useState(node, original);
    final api = startEngine(node);
    final capture = Completer<String?>();
    api.capture = () => capture.future;
    final undo = project.undo();
    expect(project.processingGraph.nodes, contains(node.id));
    capture.complete(latest);
    await undo;
    expect(project.processingGraph.nodes, isNot(contains(node.id)));
    expect(node.processorStateRetentionId, isNull);
    expect(node.initializationState, NodeInitializationState.uninitialized);
    await scope.delete(original);
    expect(() => scope.delete(latest), throwsStateError);
    await project.redo();
    useState(node, subsequent);
    // A live device's changing files are not owned by its addition command.
    await scope.delete(latest);
    expect(() => scope.delete(subsequent), throwsStateError);
  });

  test(
    'capture failure leaves the device in place and undo can be retried',
    () async {
      final file = await state();
      final node = addPlugin();
      useState(node, file);
      final api = startEngine(node);
      api.capture = () => Future.error(StateError('capture failed'));
      await expectLater(project.undo(), throwsStateError);
      expect(project.processingGraph.nodes, contains(node.id));
      expect(statePath(node), file);
      expect(() => scope.delete(file), throwsStateError);
      api.capture = () async => file;
      await project.undo();
      expect(project.processingGraph.nodes, isNot(contains(node.id)));
      expect(() => scope.delete(file), throwsStateError);
    },
  );

  test(
    'explicit removal also captures the current state before detaching',
    () async {
      final file = await state();
      final node = addPlugin();
      final api = startEngine(node);
      api.capture = () async => file;
      final track = project.tracks[project.trackOrder.first]!;
      final device = track.requireProcessing.devices.last;
      await project.execute(
        DeviceAddRemoveCommand.remove(
          project: project,
          trackId: track.id,
          deviceId: device.id,
        ),
      );
      expect(project.processingGraph.nodes, isNot(contains(node.id)));
      expect(node.processorStateRetentionId, isNull);
      expect(() => scope.delete(file), throwsStateError);
      await project.undo();
      expect(statePath(project.processingGraph.nodes[node.id]!), file);
    },
  );

  test('an open undo group owns removed track files until discarded', () async {
    final file = await state();
    useState(addPlugin(), file);
    project.startUndoGroup();
    await project.execute(
      TrackAddRemoveCommand.remove(
        project: project,
        ids: [project.trackOrder.first],
      ),
    );
    expect(() => scope.delete(file), throwsStateError);
    project.commitUndoGroup();
    expect(() => scope.delete(file), throwsStateError);
    await project.dispose();
    await scope.delete(file);
  });

  test(
    'a failed background capture does not pass its error across async zones',
    () async {
      final file = await state();
      final node = addPlugin();
      final api = startEngine(node);
      var captures = 0;
      api.capture = () {
        captures++;
        return captures == 1
            ? Future.error(StateError('background capture failed'))
            : Future.value(file);
      };
      final backgroundErrors = <Object>[];
      runZonedGuarded(
        node.scheduleThrottledStateUpdate,
        (error, _) => backgroundErrors.add(error),
      );
      await node.updateStateFromEngine().timeout(const Duration(seconds: 2));
      expect(backgroundErrors, isEmpty);
      expect(captures, 2);
      expect(statePath(node), file);
    },
  );

  test('capture preserves saved state until initialization succeeds, including retries', () async {
    final original = await state();
    final latest = await state();
    final node = addPlugin();
    useState(node, original);
    final api = startEngine(node);
    var captures = 0;
    api.capture = () async {
      captures++;
      return latest;
    };

    node.resetEngineInitialization();
    await node.updateStateFromEngine();
    expect(captures, 0);
    expect(statePath(node), original);

    node.markInitializationFailed();
    await node.updateStateFromEngine();
    expect(captures, 0);
    expect(statePath(node), original);

    node.markInitialized();
    await node.updateStateFromEngine();
    expect(captures, 1);
    expect(statePath(node), latest);
  });

  for (final removed in [false, true]) {
    test(
      'a late capture is ignored after ${removed ? 'removal and restoration' : 'failed initialization and retry'}, even when ready again',
      () async {
        final original = await state();
        final stale = await state();
        final latest = await state();
        final node = addPlugin();
        useState(node, original);
        final api = startEngine(node);
        final capture = Completer<String?>();
        api.capture = () => capture.future;
        final pending = node.updateStateFromEngine();

        if (removed) {
          final fragment = project.processingGraph.removeNodesAndCapture([
            node.id,
          ]);
          project.processingGraph.restoreGraphFragment(fragment);
        } else {
          node.markInitializationFailed();
        }
        node.markInitialized();
        project.isDirty = false;
        capture.complete(stale);
        await pending;
        expect(node.initializationState, NodeInitializationState.ready);
        expect(statePath(node), original);
        expect(project.isDirty, isFalse);

        api.capture = () async => latest;
        await node.updateStateFromEngine();
        expect(statePath(node), latest);
        expect(project.isDirty, isTrue);
      },
    );
  }
}
