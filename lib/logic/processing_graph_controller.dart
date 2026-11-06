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

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/devices/device_port_defaults.dart';
import 'package:anthem/logic/parameter_controller.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/logic/storage/project_asset_references.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/project.dart';

/// A reusable snapshot owned by its caller, independently of the engine session
/// and the node's current saved state. Dispose it when it is no longer needed.
/// This low-level reference belongs to one processor in one open project.
class ProcessorSnapshot {
  final ProjectModel _project;
  final Object _processor;
  final String relativePath;
  final ProjectAssetRetention _retention;

  ProcessorSnapshot._(
    this._project,
    this._processor,
    this.relativePath,
    this._retention,
  );

  bool get isDisposed => _retention.isDisposed;
  void dispose() => _retention.dispose();
}

/// Coordinates engine graph publication and processor state operations.
///
/// One FIFO queue covers each complete workflow: processor initialization,
/// model reconciliation and publication, or snapshot capture/replacement through
/// reconciliation and resume. Serializing individual IPC requests would leave
/// gaps in which compilation could observe a partly reconfigured processor.
///
/// Graph model edits remain immediate and synchronize normally. Callers request
/// publication after editing. Adjacent queued publications coalesce; a state
/// operation between them preserves their ordering. Nested steps use the engine
/// API directly rather than queueing another operation and waiting on themselves.
///
/// The queue never blocks engine shutdown or engine-to-UI file-service replies.
/// Queued work belongs to the engine session in which it was submitted and fails
/// if that session changes. A failed operation does not prevent later work.
class ProcessingGraphController implements DisposableService {
  final ProjectModel project;

  ProcessingGraphController(this.project);

  Engine get _engine => project.engine;
  Future<void> _operationTail = Future.value();
  bool _disposed = false;
  ({Future<void> session, Future<void> completion})? _pendingPublication;

  void _checkSession(Engine engine, Future<void> session) {
    if (_disposed ||
        !engine.isRunning ||
        !identical(engine, _engine) ||
        !identical(session, engine.sessionEnded)) {
      throw StateError('The engine session ended during the graph operation.');
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final engine = _engine;
    final session = engine.sessionEnded;
    _pendingPublication = null;
    final completion = _operationTail.then<T>((_) {
      _checkSession(engine, session);
      return operation();
    });
    _operationTail = completion.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return completion;
  }

  /// Initializes processors, reconciles descriptions/routing, then publishes.
  /// Completion confirms submission; ordinary publication does not await audio
  /// thread activation. Snapshot-load completion does await activation.
  Future<void> publish() {
    final engine = _engine;
    // Offline edits are picked up by the next engine startup publication.
    if (!engine.isRunning) return Future.value();
    final session = engine.sessionEnded;
    final pending = _pendingPublication;
    if (pending != null && identical(pending.session, session)) {
      return pending.completion;
    }
    late final Future<void> completion;
    completion = _enqueue(() async {
      if (identical(_pendingPublication?.completion, completion)) {
        _pendingPublication = null;
      }
      await _initializeAndPublish(engine, session, forRender: false);
    });
    _pendingPublication = (session: session, completion: completion);
    return completion;
  }

  Future<void> _initializeAndPublish(
    Engine engine,
    Future<void> session, {
    required bool forRender,
  }) async {
    _checkSession(engine, session);
    final initialization = forRender
        ? await engine.processingGraphApi.initializeNodesForRender()
        : await engine.processingGraphApi.initializeNodes();
    _checkSession(engine, session);
    if (!initialization.didInitialize) return;
    _applyNodePortConfigurations(initialization.results);
    if (forRender) {
      await engine.processingGraphApi.publishForRender();
    } else {
      await engine.processingGraphApi.publish();
    }
    _checkSession(engine, session);
  }

  /// Keeps render setup, processing, and audio-session restoration together.
  /// The supplied publication function runs within this queue turn, including
  /// initialization/reconciliation, so render code never queues behind itself.
  Future<T> runRender<T>(
    Future<T> Function(Future<void> Function() publishGraph) render,
  ) {
    final engine = _engine;
    final session = engine.sessionEnded;
    return _enqueue(
      () =>
          render(() => _initializeAndPublish(engine, session, forRender: true)),
    );
  }

  /// Captures project state in the same queue as publication and live loading.
  Future<String?> captureProcessorState(Id nodeId) {
    final engine = _engine;
    final session = engine.sessionEnded;
    return _enqueue(() async {
      await engine.processingGraphApi.waitForPendingParameterEdits(nodeId);
      _checkSession(engine, session);
      final path = await engine.processingGraphApi.captureProcessorState(
        nodeId,
      );
      _checkSession(engine, session);
      return path;
    });
  }

  void _checkSnapshotRequest(NodeModel node, Future<void> session) {
    if (_disposed ||
        !_engine.isRunning ||
        !identical(session, _engine.sessionEnded)) {
      throw StateError(
        'The engine session ended during the snapshot operation.',
      );
    }
    if (!identical(_engine.project.processingGraph.nodes[node.id], node)) {
      throw StateError('The processor node was removed.');
    }
    if (_engine.areRequestsHeldForRender) {
      throw StateError('Processor snapshots are unavailable during rendering.');
    }
  }

  /// Captures state into a file and transfers an independent retention to the
  /// caller. Saving does not change the node's saved project reference.
  Future<ProcessorSnapshot> saveSnapshot(Id nodeId) {
    final node = _engine.project.processingGraph.nodes[nodeId];
    if (node == null) {
      return Future.error(StateError('The processor node was removed.'));
    }
    if (_engine.areRequestsHeldForRender) {
      return Future.error(
        StateError('Processor snapshots are unavailable during rendering.'),
      );
    }
    final session = _engine.sessionEnded;
    return _enqueue(() async {
      _checkSnapshotRequest(node, session);
      node.beginProcessorStateOperation();
      try {
        await _engine.processingGraphApi.waitForPendingParameterEdits(nodeId);
        _checkSnapshotRequest(node, session);
        return await _saveSnapshot(nodeId);
      } finally {
        node.finishProcessorStateOperation();
      }
    });
  }

  Future<ProcessorSnapshot> _saveSnapshot(Id nodeId) async {
    final node = _engine.project.processingGraph.nodes[nodeId];
    if (node == null) throw StateError('The processor node was removed.');
    final session = _engine.sessionEnded;
    _checkSnapshotRequest(node, session);
    final retentionId = await _engine.processingGraphApi.saveSnapshot(nodeId);
    _checkSnapshotRequest(node, session);
    final owned = await _engine.adoptReturnedFileRetention(retentionId);
    try {
      _checkSnapshotRequest(node, session);
      return ProcessorSnapshot._(
        _engine.project,
        node.processor,
        owned.relativePath,
        owned.retention,
      );
    } catch (_) {
      owned.retention.dispose();
      rethrow;
    }
  }

  /// Borrows [snapshot]; it remains reusable after this call. A fresh recovery
  /// snapshot becomes the node's saved state before replacement starts. Failed
  /// loads recover that state; unrecoverable failures leave the node unavailable
  /// until the engine is restarted. No undo command is created here.
  Future<void> loadSnapshot(Id nodeId, ProcessorSnapshot snapshot) {
    final node = _engine.project.processingGraph.nodes[nodeId];
    if (node == null ||
        !identical(snapshot._project, project) ||
        !identical(snapshot._processor, node.processor) ||
        snapshot.isDisposed) {
      throw StateError('The snapshot is not available for this processor.');
    }
    if (_engine.areRequestsHeldForRender) {
      return Future.error(
        StateError('Processor snapshots are unavailable during rendering.'),
      );
    }
    // Borrow before waiting, so disposing the caller's handle is harmless.
    final storage = ServiceRegistry.forProject(_engine.project.id)
        .projectStorage;
    final borrowed = storage.retainAssets([snapshot.relativePath]);
    final session = _engine.sessionEnded;
    return _enqueue(() async {
      _checkSnapshotRequest(node, session);
      node.beginProcessorStateOperation();
      try {
        await _engine.processingGraphApi.waitForPendingParameterEdits(nodeId);
        return await _loadSnapshot(node, snapshot, borrowed, session);
      } finally {
        node.finishProcessorStateOperation();
      }
    }).whenComplete(borrowed.dispose);
  }

  Future<void> _loadSnapshot(
    NodeModel node,
    ProcessorSnapshot snapshot,
    ProjectAssetRetention borrowed,
    Future<void> session,
  ) async {
    final nodeId = node.id;
    final services = ServiceRegistry.forProject(_engine.project.id);
    if (services.parameterController.hasActiveChanges(nodeId)) {
      throw StateError(
        'Finish the parameter gesture before loading a snapshot.',
      );
    }
    _checkSnapshotRequest(node, session);
    final recovery = await _saveSnapshot(nodeId);
    var stateAvailable = true;
    try {
      _checkSnapshotRequest(node, session);
      node.adoptProcessorState(recovery.relativePath);
      node.beginProcessorStateRestoration();
      stateAvailable = false;
      _engine.discardProcessorGestures(nodeId);
      final response = await _engine.processingGraphApi.loadSnapshot(
        nodeId,
        retentionId: borrowed.retentionIds.single,
        recoveryRetentionId: recovery._retention.retentionIds.single,
      );
      _checkSnapshotRequest(node, session);
      if (response.operationId == null || response.result?.success != true) {
        if (response.operationId == null) {
          node.markInitialized();
          stateAvailable = true;
        } else {
          node.markInitializationFailed();
        }
        throw StateError(response.error ?? 'Snapshot loading failed.');
      }
      final operationId = response.operationId!;
      Future<LoadProcessorSnapshotResponse> finish({
        bool rollback = false,
      }) async {
        _checkSnapshotRequest(node, session);
        if (rollback) {
          node.beginProcessorStateRestoration();
          _engine.discardProcessorGestures(nodeId);
        } else {
          node.finishProcessorStateRestoration();
        }
        return await _engine.processingGraphApi.finishSnapshotLoad(
          operationId,
          rollback: rollback,
        );
      }

      try {
        _applyNodePortConfigurations([response.result!]);
        final finished = await finish();
        _checkSnapshotRequest(node, session);
        if (finished.error != null) throw StateError(finished.error!);
        services.parameterController.applyEngineValues(
          nodeId,
          finished.result!.parameterValues,
        );
        stateAvailable = true;
      } catch (error, stack) {
        // Reconcile the recovery configuration before resuming it as well.
        try {
          final recovered = await finish(rollback: true);
          _checkSnapshotRequest(node, session);
          if (recovered.error != null || recovered.result?.success != true) {
            throw StateError(recovered.error ?? 'Snapshot recovery failed.');
          }
          _applyNodePortConfigurations([recovered.result!]);
          final finished = await finish();
          _checkSnapshotRequest(node, session);
          if (finished.error != null) throw StateError(finished.error!);
          services.parameterController.applyEngineValues(
            nodeId,
            finished.result!.parameterValues,
          );
          stateAvailable = true;
        } catch (_) {
          node.markInitializationFailed();
          // A lost completion reply can make the resume outcome ambiguous.
          // Stop this session before exposing a failed load to its caller.
          if (_engine.isRunning && identical(session, _engine.sessionEnded)) {
            await _engine.stop();
          }
          rethrow;
        }
        Error.throwWithStackTrace(error, stack);
      }
      if (response.error != null) throw StateError(response.error!);
      node.adoptProcessorState(snapshot.relativePath);
    } catch (error) {
      if (!stateAvailable &&
          error is TimeoutException &&
          _engine.isRunning &&
          identical(session, _engine.sessionEnded)) {
        await _engine.stop();
      }
      if (!stateAvailable &&
          _engine.isRunning &&
          identical(session, _engine.sessionEnded) &&
          identical(_engine.project.processingGraph.nodes[nodeId], node)) {
        node.markInitializationFailed();
      }
      rethrow;
    } finally {
      recovery.dispose();
    }
  }

  void _applyNodePortConfigurations(
    List<ProcessingGraphNodeInitializationResult> results,
  ) {
    final affectedTrackIds = <Id>{};

    for (final result in results) {
      final node = project.processingGraph.nodes[result.nodeId];
      if (node == null) continue;
      if (!result.success) {
        node.markInitializationFailed();
        continue;
      }

      final portConfiguration = result.portConfiguration;

      if (portConfiguration != null) {
        final routingChanged = node.applyPortConfiguration(portConfiguration);
        if (routingChanged) {
          affectedTrackIds.addAll(_updateDeviceDefaultsForNode(result.nodeId));
        }
      }

      applyReportedParameterValues(node, result.parameterValues);
      node.markInitialized();
    }

    if (affectedTrackIds.isEmpty) {
      return;
    }

    final serviceRegistry = ServiceRegistry.forProject(project.id);
    for (final trackId in affectedTrackIds) {
      serviceRegistry.deviceController.rebuildTrackDeviceRouting(trackId);
    }
  }

  Iterable<Id> _updateDeviceDefaultsForNode(Id nodeId) sync* {
    final devicePortDefaults = DevicePortDefaults(project.processingGraph);

    for (final track in project.tracks.values) {
      if (!track.hasProcessing) {
        continue;
      }
      final processing = track.requireProcessing;

      for (final device in processing.devices) {
        if (!device.nodeIds.contains(nodeId)) {
          continue;
        }

        devicePortDefaults.refreshDeviceDefaultPorts(device);
        yield track.id;
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pendingPublication = null;
  }
}
