/*
  Copyright (C) 2025 - 2026 Joshua Wade

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
import 'dart:convert';
import 'dart:io';

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/engine_api/engine_connector_base.dart';
import 'package:anthem/engine_api/engine_connector_desktop.dart';
import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/logic/processing_graph_controller.dart';
import 'package:anthem/logic/commands/parameter_commands.dart';
import 'package:anthem/logic/commands/processor_state_commands.dart';
import 'package:anthem/logic/commands/command.dart';
import 'package:anthem/helpers/gain_parameter_mapping.dart';
import 'package:anthem/model/processing_graph/processors/utility.dart';
import 'package:anthem/logic/storage/project_storage.dart';
import 'package:anthem/logic/storage/file_fingerprint.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

class _NoopCommand extends Command {
  @override
  void execute(ProjectModel project) {}
  @override
  void rollback(ProjectModel project) {}
}

class _StorageConnector extends EngineConnector {
  bool dropNextWriteReply = false;
  final sentMessages = <IpcMessage>[];
  Completer<void>? shutdownGate;
  final shutdownEntered = Completer<void>();
  final droppedWriteReply = Completer<BeginFileWriteResponse>();

  _StorageConnector(
    super.id, {
    required super.kDebugMode,
    super.noHeartbeat,
    super.enginePathOverride,
    super.onMessage,
    super.onExit,
    super.onConnectionClosed,
  });

  @override
  Future<void> shutdown({Duration timeout = const Duration(seconds: 5)}) async {
    if (!shutdownEntered.isCompleted) shutdownEntered.complete();
    await shutdownGate?.future;
    await super.shutdown(timeout: timeout);
  }

  @override
  void sendMessage(IpcMessage message) {
    sentMessages.add(message);
    if (dropNextWriteReply && message is BeginFileWriteResponse) {
      dropNextWriteReply = false;
      droppedWriteReply.complete(message);
      return;
    }
    super.sendMessage(message);
  }
}

class _StorageFixture {
  final ProjectModel project;
  final ProjectStorage storage;
  final messages = StreamController<IpcMessage>.broadcast();
  final readyHeld = Completer<EngineReadyCheckResponse>();
  bool holdStartup;
  bool holdSnapshotReply = false;
  final snapshotReplyHeld = Completer<LoadProcessorSnapshotResponse>();
  late _StorageConnector connector;
  void Function(IpcMessage)? _deliver;

  Engine get engine => project.engine;
  ProcessingGraphController get graph =>
      ServiceRegistry.forProject(project.id).processingGraphController;
  _StorageFixture._(this.project, this.holdStartup)
    : storage = ProjectStorage.temporary(project: project);

  static Future<_StorageFixture> create({bool holdStartup = false}) async {
    final suffix = Platform.isWindows ? '.exe' : '';
    final candidates = [
      'engine/build/AnthemEngine_artefacts/Debug/AnthemEngine$suffix',
      'engine/build_release/AnthemEngine_artefacts/Release/AnthemEngine$suffix',
    ];
    final executable = candidates
        .map(File.new)
        .where((f) => f.existsSync())
        .first
        .absolute
        .path;
    final project = ProjectModel.create(executable);
    await project.engine.dispose();
    final fixture = _StorageFixture._(project, holdStartup);
    project.engine = Engine(
      project.engineID,
      project,
      enginePathOverride: executable,
      engineConnectorFactory: fixture._createConnector,
    );
    ServiceRegistry.initializeProject(
      project,
      overrides: ProjectServiceFactoryOverrides([
        overrideService(projectStorageService, (_, _) => fixture.storage),
      ]),
    );
    addTearDown(fixture.dispose);
    return fixture;
  }

  EngineConnectorBase _createConnector(
    int id, {
    required bool kDebugMode,
    void Function(IpcMessage)? onMessage,
    void Function()? onExit,
    void Function()? onConnectionClosed,
    bool noHeartbeat = false,
    String? enginePathOverride,
  }) {
    _deliver = onMessage;
    return connector = _StorageConnector(
      id,
      kDebugMode: kDebugMode,
      noHeartbeat: true,
      enginePathOverride: enginePathOverride,
      onExit: onExit,
      onConnectionClosed: onConnectionClosed,
      onMessage: (message) {
        messages.add(message);
        if (holdSnapshotReply && message is LoadProcessorSnapshotResponse) {
          snapshotReplyHeld.complete(message);
          return;
        }
        if (holdStartup && message is EngineReadyCheckResponse) {
          readyHeld.complete(message);
          return;
        }
        onMessage?.call(message);
      },
    );
  }

  Future<void> releaseStartup() async {
    holdStartup = false;
    _deliver!(await readyHeld.future);
  }

  Future<TestFileStorageResponse> send(
    TestFileStorageOperation operation, {
    String category = 'plugin states',
    String? baseName,
    String? extension,
    String data = '',
    String token = '',
    String relativePath = '',
    FileFingerprint? fingerprint,
    bool includeFingerprint = false,
  }) async {
    final id = connector.getRequestId();
    final response = messages.stream.firstWhere(
      (message) => message is TestFileStorageResponse && message.id == id,
    );
    connector.sendMessage(
      TestFileStorageRequest(
        id: id,
        operation: operation,
        category: category,
        baseName: baseName,
        extension: extension,
        data: data,
        token: token,
        relativePath: relativePath,
        fingerprint: fingerprint,
        includeFingerprint: includeFingerprint,
      ),
    );
    return await response.timeout(const Duration(seconds: 10))
        as TestFileStorageResponse;
  }

  Future<void> dispose() async {
    await project.dispose();
    await storage.discard();
    ServiceRegistry.removeProject(project.id);
    await messages.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> initializeSnapshots(_StorageFixture fixture) async {
    await fixture.engine.start(initializeAudio: false);
    await fixture.engine.renderApi.startRenderAudioSession(
      sampleRate: 48000,
      blockSize: 128,
      outputChannelCount: 2,
    );
    await ServiceRegistry.forProject(fixture.project.id)
        .processingGraphController
        .publish();
  }

  test('retained snapshots support repeated live loads and survive engine sessions', () async {
    final fixture = await _StorageFixture.create();
    await initializeSnapshots(fixture);
    final services = ServiceRegistry.forProject(fixture.project.id);
    final track = fixture.project.tracks[fixture.project.trackOrder.first]!;
    final node = track.requireProcessing.utilityNode!;
    final port = node.getPortById(UtilityProcessorModel.gainPortId);
    final api = fixture.graph;
    Future<void> set(double value) => services.parameterController.setValue(
      node: node,
      port: port,
      value: value,
    );
    await set(0.3);
    await node.updateStateFromEngine();
    final savedReference = node.processorStateRetentionId;
    final snapshot = await api.saveSnapshot(node.id);
    addTearDown(snapshot.dispose);
    expect(snapshot.isDisposed, isFalse);
    expect(node.processorStateRetentionId, savedReference);
    final resetTarget = port.parameterResetTarget;
    for (var i = 0; i < 2; ++i) {
      await set(0.7);
      await api.loadSnapshot(node.id, snapshot);
      expect(port.parameterValue, closeTo(0.3, 0.0001));
      expect(port.parameterResetTarget, resetTarget);
      expect(node.initializationState, NodeInitializationState.ready);
      expect(
        fixture.storage.resolveRetention(node.processorStateRetentionId!),
        snapshot.relativePath,
      );
      expect(snapshot.isDisposed, isFalse);
    }
    await fixture.engine.stop();
    await initializeSnapshots(fixture);
    await set(0.6);
    await api.loadSnapshot(node.id, snapshot);
    expect(port.parameterValue, closeTo(0.3, 0.0001));
    snapshot.dispose();
    snapshot.dispose();
    expect(snapshot.isDisposed, isTrue);
    expect(() => api.loadSnapshot(node.id, snapshot), throwsStateError);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test(
    'snapshot commands support undo and redo across engine restarts',
    () async {
      final fixture = await _StorageFixture.create();
      await initializeSnapshots(fixture);
      final project = fixture.project;
      final parameter = ServiceRegistry.forProject(project.id)
          .parameterController;
      final node = project
          .tracks[project.trackOrder.first]!
          .requireProcessing
          .utilityNode!;
      final port = node.getPortById(UtilityProcessorModel.gainPortId);
      await parameter.setValue(node: node, port: port, value: 0.3);
      final target = await fixture.graph.saveSnapshot(node.id);
      final targetPath = target.relativePath;
      final load = LoadProcessorSnapshotCommand(
        nodeId: node.id,
        snapshot: target,
      );
      target.dispose();
      await parameter.setValue(node: node, port: port, value: 0.7);
      final reset = port.parameterResetTarget;
      final captures = fixture.connector.sentMessages
          .whereType<SaveProcessorSnapshotRequest>()
          .length;
      await project.execute(load);
      expect(
        fixture.connector.sentMessages
            .whereType<SaveProcessorSnapshotRequest>()
            .length,
        captures + 1,
        reason: 'Undo uses the recovery capture rather than capturing twice.',
      );
      for (var i = 0; i < 2; i++) {
        expect(port.parameterValue, closeTo(0.3, 0.0001));
        expect(
          fixture.storage.resolveRetention(node.processorStateRetentionId!),
          targetPath,
        );
        await project.undo();
        expect(port.parameterValue, closeTo(0.7, 0.0001));
        await project.redo();
      }
      await fixture.engine.stop();
      await initializeSnapshots(fixture);
      await project.undo();
      expect(port.parameterValue, closeTo(0.7, 0.0001));
      await project.redo();
      expect(port.parameterValue, closeTo(0.3, 0.0001));
      expect(port.parameterResetTarget, reset);
    },
  );

  test('discarding snapshot redo history releases its file and preserves the project state', () async {
    final fixture = await _StorageFixture.create();
    await initializeSnapshots(fixture);
    final project = fixture.project;
    final parameter = ServiceRegistry.forProject(project.id)
        .parameterController;
    final node = project
        .tracks[project.trackOrder.first]!
        .requireProcessing
        .utilityNode!;
    final port = node.getPortById(UtilityProcessorModel.gainPortId);
    await parameter.setValue(node: node, port: port, value: 0.3);
    final target = await fixture.graph.saveSnapshot(node.id);
    final targetPath = target.relativePath;
    final load = LoadProcessorSnapshotCommand(
      nodeId: node.id,
      snapshot: target,
    );
    target.dispose();
    await parameter.setValue(node: node, port: port, value: 0.7);
    await project.execute(load);
    await project.undo();
    final beforePath = fixture.storage.resolveRetention(
      node.processorStateRetentionId!,
    );
    expect(beforePath, isNot(targetPath));
    await fixture.engine.stop();
    final store = await fixture.storage.assetStore;
    final scope = store.openScope();
    addTearDown(() => store.closeScope(scope));
    expect(() => store.delete(scope, targetPath), throwsStateError);
    await project.execute(_NoopCommand());
    await store.delete(scope, targetPath);
    expect(() => store.delete(scope, beforePath), throwsStateError);
  });

  test('failed snapshot commands preserve live state and the previous history entry', () async {
    final fixture = await _StorageFixture.create();
    await initializeSnapshots(fixture);
    final project = fixture.project;
    final parameter = ServiceRegistry.forProject(project.id)
        .parameterController;
    final node = project
        .tracks[project.trackOrder.first]!
        .requireProcessing
        .utilityNode!;
    final port = node.getPortById(UtilityProcessorModel.gainPortId);
    await parameter.setValue(node: node, port: port, value: 0.3);
    final target = await fixture.graph.saveSnapshot(node.id);
    final targetPath = target.relativePath;
    final load = LoadProcessorSnapshotCommand(
      nodeId: node.id,
      snapshot: target,
    );
    target.dispose();
    await parameter.setValue(node: node, port: port, value: 0.6);
    await project.execute(
      SetParameterValueCommand(
        nodeId: node.id,
        controlPortId: port.id,
        oldValue: 0.6,
        newValue: 0.7,
      ),
    );
    final store = await fixture.storage.assetStore;
    final scope = store.openScope();
    addTearDown(() => store.closeScope(scope));
    final read = store.acquireRead(scope, targetPath);
    await File(read.absolutePath).writeAsString('invalid');
    store.releaseRead(scope, read.token);
    await expectLater(project.execute(load), throwsStateError);
    expect(port.parameterValue, closeTo(0.7, 0.0001));
    expect(node.canEditParameters, isTrue);
    await project.undo();
    expect(port.parameterValue, closeTo(0.6, 0.0001));
    await fixture.engine.stop();
    await store.delete(scope, targetPath);
  });

  test('snapshot replacement excludes publication and other-node captures through completion', () async {
    final fixture = await _StorageFixture.create();
    await initializeSnapshots(fixture);
    final services = ServiceRegistry.forProject(fixture.project.id);
    final processing = fixture
        .project
        .tracks[fixture.project.trackOrder.first]!
        .requireProcessing;
    final node = processing.utilityNode!;
    final port = node.getPortById(UtilityProcessorModel.gainPortId);
    await services.parameterController.setValue(
      node: node,
      port: port,
      value: 0.3,
    );
    final snapshot = await fixture.graph.saveSnapshot(node.id);
    addTearDown(snapshot.dispose);
    await services.parameterController.setValue(
      node: node,
      port: port,
      value: 0.7,
    );
    fixture.holdSnapshotReply = true;
    final loading = fixture.graph.loadSnapshot(node.id, snapshot);
    final paused = await fixture.snapshotReplyHeld.future;
    expect(node.canHandleProcessorEvents, isFalse);
    final firstQueuedRequest = fixture.connector.sentMessages.length;
    final capture = fixture.graph.captureProcessorState(
      processing.dbMeterNode!.id,
    );
    final publishing = services.processingGraphController.publish();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      fixture.connector.sentMessages
          .skip(firstQueuedRequest)
          .whereType<Request>(),
      isEmpty,
    );
    fixture.holdSnapshotReply = false;
    fixture._deliver!(paused);
    await loading;
    await capture;
    await publishing;
    final operations = fixture.connector.sentMessages
        .skip(firstQueuedRequest)
        .where(
          (message) =>
              message is FinishProcessorSnapshotLoadRequest ||
              message is CaptureProcessorStateRequest ||
              message is InitializeProcessingGraphNodesRequest ||
              message is PublishProcessingGraphRequest,
        )
        .map((message) => message.runtimeType)
        .toList();
    expect(operations, [
      FinishProcessorSnapshotLoadRequest,
      CaptureProcessorStateRequest,
      InitializeProcessingGraphNodesRequest,
      PublishProcessingGraphRequest,
    ]);
    expect(port.parameterValue, closeTo(0.3, 0.0001));
    expect(node.canEditParameters, isTrue);
  });

  test(
    'engine loss during a load restores its fresh recovery file on restart',
    () async {
      final fixture = await _StorageFixture.create();
      await initializeSnapshots(fixture);
      final services = ServiceRegistry.forProject(fixture.project.id);
      final node = fixture
          .project
          .tracks[fixture.project.trackOrder.first]!
          .requireProcessing
          .utilityNode!;
      final port = node.getPortById(UtilityProcessorModel.gainPortId);
      await services.parameterController.setValue(
        node: node,
        port: port,
        value: 0.3,
      );
      final snapshot = await fixture.graph.saveSnapshot(node.id);
      addTearDown(snapshot.dispose);
      await services.parameterController.setValue(
        node: node,
        port: port,
        value: 0.7,
      );
      fixture.holdSnapshotReply = true;
      final loading = fixture.graph.loadSnapshot(node.id, snapshot);
      final failed = expectLater(loading, throwsStateError);
      final response = await fixture.snapshotReplyHeld.future;
      expect(response.result!.success, isTrue);
      final recovery = node.processorStateRetentionId;
      expect(recovery, isNotNull);
      await fixture.engine.stop();
      await failed;
      fixture.holdSnapshotReply = false;
      await initializeSnapshots(fixture);
      expect(node.processorStateRetentionId, recovery);
      expect(port.parameterValue, closeTo(0.7, 0.0001));
      await fixture.graph.loadSnapshot(node.id, snapshot);
      expect(port.parameterValue, closeTo(0.3, 0.0001));
    },
  );

  test(
    'snapshot operations reject a render hold without leaving a busy node',
    () async {
      final fixture = await _StorageFixture.create();
      await initializeSnapshots(fixture);
      final node = fixture
          .project
          .tracks[fixture.project.trackOrder.first]!
          .requireProcessing
          .utilityNode!;
      final api = fixture.graph;
      final snapshot = await api.saveSnapshot(node.id);
      addTearDown(snapshot.dispose);
      fixture.engine.holdRequestsForRender();
      try {
        await expectLater(api.saveSnapshot(node.id), throwsStateError);
        await expectLater(
          api.loadSnapshot(node.id, snapshot),
          throwsStateError,
        );
        expect(node.isProcessorStateOperationPending, isFalse);
      } finally {
        fixture.engine.releaseRequestsHeldForRender();
      }
    },
  );

  test('stateless processors still yield reusable snapshot handles', () async {
    final fixture = await _StorageFixture.create();
    await initializeSnapshots(fixture);
    final node = fixture
        .project
        .tracks[fixture.project.trackOrder.first]!
        .requireProcessing
        .dbMeterNode!;
    expect(node.controlInputPorts, isEmpty);
    final api = fixture.graph;
    final snapshot = await api.saveSnapshot(node.id);
    addTearDown(snapshot.dispose);
    await api.loadSnapshot(node.id, snapshot);
    expect(node.initializationState, NodeInitializationState.ready);
    expect(snapshot.isDisposed, isFalse);
  });

  test('caller ownership protects a snapshot independently of engine and project state', () async {
    final fixture = await _StorageFixture.create();
    await initializeSnapshots(fixture);
    final services = ServiceRegistry.forProject(fixture.project.id);
    final node = fixture
        .project
        .tracks[fixture.project.trackOrder.first]!
        .requireProcessing
        .utilityNode!;
    final port = node.getPortById(UtilityProcessorModel.gainPortId);
    await services.parameterController.setValue(
      node: node,
      port: port,
      value: 0.3,
    );
    final snapshot = await fixture.graph.saveSnapshot(node.id);
    addTearDown(snapshot.dispose);
    await services.parameterController.setValue(
      node: node,
      port: port,
      value: 0.7,
    );
    await node.updateStateFromEngine();
    await fixture.engine.stop();
    final store = await fixture.storage.assetStore;
    final scope = store.openScope();
    addTearDown(() => store.closeScope(scope));
    expect(() => store.delete(scope, snapshot.relativePath), throwsStateError);
    snapshot.dispose();
    await store.delete(scope, snapshot.relativePath);
  });

  test(
    'loading borrows its own claim before the caller disposes the handle',
    () async {
      final fixture = await _StorageFixture.create();
      await initializeSnapshots(fixture);
      final services = ServiceRegistry.forProject(fixture.project.id);
      final node = fixture
          .project
          .tracks[fixture.project.trackOrder.first]!
          .requireProcessing
          .utilityNode!;
      final port = node.getPortById(UtilityProcessorModel.gainPortId);
      await services.parameterController.setValue(
        node: node,
        port: port,
        value: 0.3,
      );
      final snapshot = await fixture.graph.saveSnapshot(node.id);
      addTearDown(snapshot.dispose);
      await services.parameterController.setValue(
        node: node,
        port: port,
        value: 0.7,
      );
      fixture.connector.dropNextWriteReply = true;
      final loading = fixture.graph.loadSnapshot(node.id, snapshot);
      final write = await fixture.connector.droppedWriteReply.future;
      snapshot.dispose();
      fixture.connector.sendMessage(write);
      await loading;
      expect(port.parameterValue, closeTo(0.3, 0.0001));
      expect(node.initializationState, NodeInitializationState.ready);
    },
  );

  test('invalid snapshot files preserve current values and a retained recovery reference', () async {
    final fixture = await _StorageFixture.create();
    await initializeSnapshots(fixture);
    final services = ServiceRegistry.forProject(fixture.project.id);
    final node = fixture
        .project
        .tracks[fixture.project.trackOrder.first]!
        .requireProcessing
        .utilityNode!;
    final port = node.getPortById(UtilityProcessorModel.gainPortId);
    await services.parameterController.setValue(
      node: node,
      port: port,
      value: 0.3,
    );
    final snapshot = await fixture.graph.saveSnapshot(node.id);
    addTearDown(snapshot.dispose);
    await services.parameterController.setValue(
      node: node,
      port: port,
      value: 0.7,
    );
    final store = await fixture.storage.assetStore;
    final scope = store.openScope();
    final read = store.acquireRead(scope, snapshot.relativePath);
    await File(read.absolutePath).writeAsString('invalid');
    store.releaseRead(scope, read.token);
    await store.closeScope(scope);
    await expectLater(
      fixture.graph.loadSnapshot(node.id, snapshot),
      throwsStateError,
    );
    expect(port.parameterValue, closeTo(0.7, 0.0001));
    expect(node.initializationState, NodeInitializationState.ready);
    expect(node.canEditParameters, isTrue);
    expect(node.canHandleProcessorEvents, isTrue);
    expect(port.isAvailable, isTrue);
    expect(node.processorStateRetentionId, isNotNull);
    await fixture.engine.stop();
    await initializeSnapshots(fixture);
    expect(port.parameterValue, closeTo(0.7, 0.0001));
  });

  test('native parameters survive graph publication and engine restart through snapshots', () async {
    final fixture = await _StorageFixture.create();
    final project = fixture.project;
    final services = ServiceRegistry.forProject(project.id);
    Future<void> initialize() async {
      await fixture.engine.start(initializeAudio: false);
      await fixture.engine.renderApi.startRenderAudioSession(
        sampleRate: 48000,
        blockSize: 128,
        outputChannelCount: 2,
      );
      await services.processingGraphController.publish();
    }

    await initialize();
    final track = project.tracks[project.trackOrder.first]!;
    final node =
        project.processingGraph.nodes[track.requireProcessing.utilityNodeId]!;
    final port = node.getPortById(UtilityProcessorModel.gainPortId);
    expect(port.parameterValue, closeTo(gainDbToParameterValue(-10), 0.0001));
    expect(
      port.config.parameterConfig!.factoryDefaultValue,
      closeTo(gainParameterZeroDbNormalized, 0.0001),
    );
    expect(port.parameterResetTarget, gainDbToParameterValue(-10));
    expect(
      node
          .getPortById(UtilityProcessorModel.balancePortId)
          .config
          .parameterConfig!
          .normalizedVisualBaseline,
      0.5,
    );
    final master = project
        .tracks[project.sendTrackOrder.single]!
        .requireProcessing
        .utilityNode!;
    expect(master.initialParameterValues, isEmpty);
    expect(
      master.getPortById(UtilityProcessorModel.gainPortId).parameterValue,
      closeTo(gainParameterZeroDbNormalized, 0.0001),
    );

    // Creation overrides survive loss of the engine before the first capture.
    expect(node.processorStateRetentionId, isNull);
    await fixture.engine.stop();
    expect(port.parameterValue, closeTo(gainDbToParameterValue(-10), 0.0001));
    expect(port.config.parameterConfig!.displayMode, isNotNull);
    expect(node.initialParameterValues[port.id], gainDbToParameterValue(-10));
    await initialize();
    expect(port.parameterValue, closeTo(gainDbToParameterValue(-10), 0.0001));
    await project.execute(
      SetParameterValueCommand(
        nodeId: node.id,
        controlPortId: port.id,
        oldValue: port.parameterValue!,
        newValue: 0.37,
      ),
    );
    expect(port.parameterValue, closeTo(0.37, 0.0001));
    await node.updateStateFromEngine();
    final retention = node.processorStateRetentionId;
    expect(retention, isNotNull);
    expect(node.initialParameterValues, isEmpty);

    // A stale UI preview cannot overwrite the live setting on graph rebuild.
    port.parameterValue = 0.99;
    await services.processingGraphController.publish();
    await node.updateStateFromEngine();
    expect(node.processorStateRetentionId, retention);

    await fixture.engine.stopAudio();
    await fixture.engine.renderApi.startRenderAudioSession(
      sampleRate: 96000,
      blockSize: 256,
      outputChannelCount: 2,
    );
    await services.processingGraphController.publish();
    expect(port.parameterValue, closeTo(0.37, 0.0001));

    // A retained snapshot takes precedence over any remaining creation input.
    node.initialParameterValues[port.id] = 0.8;
    await fixture.engine.stop();
    await initialize();
    expect(port.parameterValue, closeTo(0.37, 0.0001));
    await node.updateStateFromEngine();
    expect(node.processorStateRetentionId, retention);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test(
    'project retention IDs resolve over IPC after an engine restart',
    () async {
      final fixture = await _StorageFixture.create();
      await fixture.engine.start(initializeAudio: false);
      final store = await fixture.storage.assetStore;
      final writer = store.openScope();
      final write = await store.beginWrite(writer, 'plugin states');
      await File(write.absolutePath).writeAsString('project-owned state');
      final path = await store.commitWrite(writer, write.token);
      final retentionId = fixture.storage.retainAssetForProject(path);
      await store.closeScope(writer);
      for (var start = 0; start < 2; start++) {
        final resolved = await fixture.send(
          TestFileStorageOperation.resolveRetention,
          token: retentionId,
        );
        expect(resolved.error, isNull);
        expect(resolved.relativePath, path);
        if (start == 0) {
          await fixture.engine.stop();
          expect(fixture.storage.resolveRetention(retentionId), path);
          await fixture.engine.start(initializeAudio: false);
        }
      }
      fixture.storage.releaseAssetFromProject(retentionId);
      expect(
        (await fixture.send(
          TestFileStorageOperation.resolveRetention,
          token: retentionId,
        )).error,
        contains('Unknown file retention'),
      );
    },
  );

  test('engine writer fingerprints are returned through read metadata without changing the file', () async {
    final fixture = await _StorageFixture.create();
    await fixture.engine.start(initializeAudio: false);
    const contents = 'state with Unicode Ω';
    final fingerprint = FileFingerprint.fromBytes(utf8.encode(contents));
    final write = await fixture.send(
      TestFileStorageOperation.beginWrite,
      data: contents,
    );
    final committed = await fixture.send(
      TestFileStorageOperation.commitWrite,
      token: write.token!,
      fingerprint: fingerprint,
    );
    expect(committed.error, isNull);
    final read = await fixture.send(
      TestFileStorageOperation.acquireRead,
      relativePath: committed.relativePath!,
      includeFingerprint: true,
    );
    expect(read.error, isNull);
    expect(read.fingerprint!.byteLength, fingerprint.byteLength);
    expect(read.fingerprint!.sha256, fingerprint.sha256);
    expect(read.data, contents);
    await fixture.send(
      TestFileStorageOperation.releaseRead,
      token: read.token!,
    );
    final ordinaryRead = await fixture.send(
      TestFileStorageOperation.acquireRead,
      relativePath: committed.relativePath!,
    );
    expect(ordinaryRead.fingerprint, isNull);
    await fixture.send(
      TestFileStorageOperation.releaseRead,
      token: ordinaryRead.token!,
    );
  });

  test(
    'a missing file fails metadata access without leaving a read token behind',
    () async {
      final fixture = await _StorageFixture.create();
      await fixture.engine.start(initializeAudio: false);
      final bytes = utf8.encode('cached contents');
      final store = await fixture.storage.assetStore;
      final scope = store.openScope();
      addTearDown(() => store.closeScope(scope));
      final write = await store.beginWrite(scope, 'plugin states');
      await File(write.absolutePath).writeAsBytes(bytes);
      final relativePath = await store.commitWrite(scope, write.token);
      final access = store.acquireRead(scope, relativePath);
      await store.getFingerprint(scope, access.token);
      store.releaseRead(scope, access.token);
      final file = File(access.absolutePath);
      await file.delete();

      final failed = await fixture.send(
        TestFileStorageOperation.acquireRead,
        relativePath: relativePath,
        includeFingerprint: true,
      );
      expect(failed.error, isNotNull);
      expect(failed.token, isNull);
      await file.writeAsBytes(bytes, flush: true);
      await store.delete(scope, relativePath);
    },
  );

  test('the engine writes and reads through production storage requests during startup and render holds', () async {
    final fixture = await _StorageFixture.create(holdStartup: true);
    final startup = fixture.engine.start(initializeAudio: false);
    await fixture.readyHeld.future;
    expect(fixture.engine.engineState, EngineState.starting);
    final write = await fixture.send(
      TestFileStorageOperation.beginWrite,
      baseName: 'Preset Ω',
      extension: 'bin',
      data: 'opaque state Ω\u0000tail',
    );
    expect(write.error, isNull);
    final store = await fixture.storage.assetStore;
    final uiScope = store.openScope();
    addTearDown(() => store.closeScope(uiScope));
    expect(store.relativePaths, isEmpty);
    final committed = await fixture.send(
      TestFileStorageOperation.commitWrite,
      token: write.token!,
    );
    expect(committed.error, isNull);
    expect(committed.relativePath, 'plugin states/Preset Ω 01.bin');
    await fixture.releaseStartup();
    await startup;
    fixture.engine.holdRequestsForRender();
    final read = await fixture.send(
      TestFileStorageOperation.acquireRead,
      relativePath: committed.relativePath!,
      includeFingerprint: true,
    );
    expect(read.error, isNull);
    expect(read.data, 'opaque state Ω\u0000tail');
    final expected = FileFingerprint.fromBytes(
      utf8.encode('opaque state Ω\u0000tail'),
    );
    expect(read.fingerprint!.byteLength, expected.byteLength);
    expect(read.fingerprint!.sha256, expected.sha256);
    expect(
      (await fixture.send(
        TestFileStorageOperation.deleteFile,
        relativePath: committed.relativePath!,
      )).error,
      contains('still in use'),
    );
    expect(
      (await fixture.send(
        TestFileStorageOperation.releaseRead,
        token: read.token!,
      )).error,
      isNull,
    );
    final retained = store.retain(uiScope, committed.relativePath!);
    expect(
      (await fixture.send(
        TestFileStorageOperation.deleteFile,
        relativePath: committed.relativePath!,
      )).error,
      contains('still in use'),
    );
    store.releaseRetention(uiScope, retained);
    final engineRetention = await fixture.send(
      TestFileStorageOperation.retainFile,
      relativePath: committed.relativePath!,
    );
    expect(engineRetention.error, isNull);
    expect(
      () => store.delete(uiScope, committed.relativePath!),
      throwsStateError,
    );
    expect(
      (await fixture.send(
        TestFileStorageOperation.releaseRetention,
        token: engineRetention.token!,
      )).error,
      isNull,
    );
    expect(
      (await fixture.send(
        TestFileStorageOperation.deleteFile,
        relativePath: committed.relativePath!,
      )).error,
      isNull,
    );
    expect(await File(read.absolutePath!).exists(), isFalse);
    final aborted = await fixture.send(
      TestFileStorageOperation.beginWrite,
      baseName: 'Discard',
    );
    expect(
      (await fixture.send(
        TestFileStorageOperation.abortWrite,
        token: aborted.token!,
      )).error,
      isNull,
    );
    expect(await File(aborted.absolutePath!).exists(), isFalse);
    expect(
      (await fixture.send(
        TestFileStorageOperation.commitWrite,
        token: aborted.token!,
      )).error,
      contains('Unknown file write token'),
    );
    expect(
      (await fixture.send(
        TestFileStorageOperation.beginWrite,
        category: '../outside',
      )).error,
      contains('Unknown file category'),
    );
    expect(
      (await fixture.send(
        TestFileStorageOperation.acquireRead,
        relativePath: '../outside',
      )).error,
      contains('Expected a category/filename path'),
    );
    fixture.engine.releaseRequestsHeldForRender();
  }, timeout: const Timeout(Duration(seconds: 45)));

  test(
    'UI writes are available to the engine after the UI file scope closes',
    () async {
      final fixture = await _StorageFixture.create();
      await fixture.engine.start(initializeAudio: false);
      final store = await fixture.storage.assetStore;
      final uiScope = store.openScope();
      addTearDown(() => store.closeScope(uiScope));
      final write = await store.beginWrite(
        uiScope,
        'plugin states',
        baseName: 'Created by UI',
      );
      await File(write.absolutePath).writeAsString('shared state', flush: true);
      expect(
        (await fixture.send(
          TestFileStorageOperation.commitWrite,
          token: write.token,
        )).error,
        contains('Unknown file write token'),
      );
      final relativePath = await store.commitWrite(uiScope, write.token);
      final read = await fixture.send(
        TestFileStorageOperation.acquireRead,
        relativePath: relativePath,
      );
      expect(read.error, isNull);
      expect(read.data, 'shared state');
      store.retain(uiScope, relativePath);
      final pending = await store.beginWrite(uiScope, 'plugin states');

      await store.closeScope(uiScope);
      expect(await File(pending.absolutePath).exists(), isFalse);
      expect(await File(read.absolutePath!).readAsString(), 'shared state');
      // The engine's read token still prevents deletion after UI cleanup.
      expect(
        (await fixture.send(
          TestFileStorageOperation.deleteFile,
          relativePath: relativePath,
        )).error,
        contains('still in use'),
      );
      expect(
        (await fixture.send(
          TestFileStorageOperation.releaseRead,
          token: read.token!,
        )).error,
        isNull,
      );
      expect(
        (await fixture.send(
          TestFileStorageOperation.deleteFile,
          relativePath: relativePath,
        )).error,
        isNull,
      );
      expect(await File(read.absolutePath!).exists(), isFalse);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test('process exit releases reads and unfinished writes while restart keeps committed state', () async {
    final fixture = await _StorageFixture.create();
    await fixture.engine.start(initializeAudio: false);
    final write = await fixture.send(
      TestFileStorageOperation.beginWrite,
      data: 'saved state',
    );
    final committed = await fixture.send(
      TestFileStorageOperation.commitWrite,
      token: write.token!,
    );
    final relativePath = committed.relativePath!;
    final store = await fixture.storage.assetStore;
    final uiScope = store.openScope();
    addTearDown(() => store.closeScope(uiScope));
    final retained = store.retain(uiScope, relativePath);
    final engineRetention = await fixture.send(
      TestFileStorageOperation.retainFile,
      relativePath: relativePath,
    );
    expect(engineRetention.error, isNull);
    final read = await fixture.send(
      TestFileStorageOperation.acquireRead,
      relativePath: relativePath,
    );
    final unfinished = await fixture.send(
      TestFileStorageOperation.beginWrite,
      data: 'unfinished',
    );
    final stopped = fixture.engine.engineStateStream.firstWhere(
      (state) => state == EngineState.stopped,
    );
    expect(
      Process.killPid(fixture.connector.processId!, ProcessSignal.sigkill),
      isTrue,
    );
    await stopped.timeout(const Duration(seconds: 15));
    expect(await File(unfinished.absolutePath!).exists(), isFalse);
    expect(await File(read.absolutePath!).readAsString(), 'saved state');
    expect(
      () => store.delete(uiScope, relativePath),
      throwsStateError,
    ); // Project retention survives.
    await fixture.engine.start(initializeAudio: false);
    expect(
      (await fixture.send(
        TestFileStorageOperation.commitWrite,
        token: unfinished.token!,
      )).error,
      contains('Unknown file write token'),
    );
    expect(
      (await fixture.send(
        TestFileStorageOperation.releaseRead,
        token: read.token!,
      )).error,
      contains('Unknown file read token'),
    );
    expect(
      (await fixture.send(
        TestFileStorageOperation.releaseRetention,
        token: engineRetention.token!,
      )).error,
      contains('Unknown file retention token'),
    );
    final reread = await fixture.send(
      TestFileStorageOperation.acquireRead,
      relativePath: relativePath,
    );
    expect(reread.data, 'saved state');
    await fixture.send(
      TestFileStorageOperation.releaseRead,
      token: reread.token!,
    );
    store.releaseRetention(uiScope, retained);
    expect(
      (await fixture.send(
        TestFileStorageOperation.deleteFile,
        relativePath: relativePath,
      )).error,
      isNull,
    );
    final pending = await fixture.send(TestFileStorageOperation.beginWrite);
    await fixture.engine.stop();
    expect(await File(pending.absolutePath!).exists(), isFalse);
    expect(
      await Directory(path.join(store.rootDirectory, '.pending'))
          .list()
          .toList(),
      isEmpty,
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  test(
    'entering stopping preserves access until connector shutdown completes',
    () async {
      final fixture = await _StorageFixture.create();
      await fixture.engine.start(initializeAudio: false);
      final write = await fixture.send(TestFileStorageOperation.beginWrite);
      final committed = await fixture.send(
        TestFileStorageOperation.commitWrite,
        token: write.token!,
      );
      await fixture.send(
        TestFileStorageOperation.acquireRead,
        relativePath: committed.relativePath!,
      );
      final pending = await fixture.send(TestFileStorageOperation.beginWrite);
      final store = await fixture.storage.assetStore;
      final uiScope = store.openScope();
      addTearDown(() => store.closeScope(uiScope));
      final gate = fixture.connector.shutdownGate = Completer<void>();
      final stopping = fixture.engine.stop();
      try {
        await fixture.engine.sessionEnded;
        await fixture.connector.shutdownEntered.future;
        expect(fixture.engine.engineState, EngineState.stopping);
        expect(await File(pending.absolutePath!).exists(), isTrue);
        expect(
          () => store.delete(uiScope, committed.relativePath!),
          throwsStateError,
        );
      } finally {
        gate.complete();
        await stopping;
      }
      expect(await File(pending.absolutePath!).exists(), isFalse);
      await store.delete(uiScope, committed.relativePath!);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test('failed file cleanup can be retried when closing the engine', () async {
    final fixture = await _StorageFixture.create();
    await fixture.engine.start(initializeAudio: false);
    final pending = await fixture.send(TestFileStorageOperation.beginWrite);
    await File(pending.absolutePath!).delete();
    await Directory(pending.absolutePath!).create();
    await expectLater(
      fixture.engine.dispose(),
      throwsA(isA<FileSystemException>()),
    );
    expect(await Directory(pending.absolutePath!).exists(), isTrue);
    await expectLater(
      fixture.engine.start(initializeAudio: false),
      throwsStateError,
    );
    await Directory(pending.absolutePath!).delete();
    await File(pending.absolutePath!).writeAsString('retry cleanup');
    await fixture.engine.dispose();
    expect(await File(pending.absolutePath!).exists(), isFalse);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('a lost write-access reply is cleaned up after the engine times out and stops', () async {
    final fixture = await _StorageFixture.create();
    await fixture.engine.start(initializeAudio: false);
    fixture.connector.dropNextWriteReply = true;
    final pending = fixture.send(TestFileStorageOperation.beginWrite);
    final lost = await fixture.connector.droppedWriteReply.future;
    expect((await pending).error, 'IPC request timed out.');
    expect(await File(lost.absolutePath).exists(), isTrue);
    await fixture.engine.stop();
    expect(await File(lost.absolutePath).exists(), isFalse);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
