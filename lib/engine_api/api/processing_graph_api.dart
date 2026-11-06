/*
  Copyright (C) 2024 - 2026 Joshua Wade

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

part of 'package:anthem/engine_api/engine.dart';

class ProcessingGraphNodeInitialization {
  final bool didInitialize;
  final List<ProcessingGraphNodeInitializationResult> results;

  ProcessingGraphNodeInitialization({
    required this.didInitialize,
    required this.results,
  });
}

/// Individual processing-graph requests to the engine. Application workflows
/// are coordinated by ProcessingGraphController.
class ProcessingGraphApi {
  final Engine _engine;

  ProcessingGraphApi(this._engine);

  final _pendingEdits = <Id, Set<Future<ProcessingGraphParameterValue>>>{};

  /// Waits for already submitted edits before capturing/replacing state.
  Future<void> waitForPendingParameterEdits(Id nodeId) =>
      Future.wait(_pendingEdits[nodeId]?.toList() ?? []).then((_) {});

  /// Captures a snapshot and hands its retention token to the UI.
  /// The engine will not use or release the token after returning it. Adopt it
  /// with Engine.adoptReturnedFileRetention to retain it beyond this session.
  /// Application callers should use ProcessingGraphController.saveSnapshot.
  Future<String> saveSnapshot(Id nodeId) async {
    final response = await _engine._request(
      SaveProcessorSnapshotRequest(id: _engine._getRequestId(), nodeId: nodeId),
      timeout: const Duration(seconds: 30),
    ) as SaveProcessorSnapshotResponse;
    if (response.error != null || response.retentionId == null) {
      throw StateError(response.error ?? 'No snapshot retention was returned.');
    }
    return response.retentionId!;
  }

  /// Begins replacement and returns descriptions while the node stays paused.
  /// The caller must reconcile the model, then finish or recover the operation.
  Future<LoadProcessorSnapshotResponse> loadSnapshot(
    Id nodeId, {
    required String retentionId,
    required String recoveryRetentionId,
  }) async => await _engine._request(
    LoadProcessorSnapshotRequest(
      id: _engine._getRequestId(),
      nodeId: nodeId,
      retentionId: retentionId,
      recoveryRetentionId: recoveryRetentionId,
    ),
    timeout: const Duration(seconds: 30),
  ) as LoadProcessorSnapshotResponse;

  /// Publishes the reconciled graph and resumes, or restores recovery state.
  Future<LoadProcessorSnapshotResponse> finishSnapshotLoad(
    int operationId, {
    bool rollback = false,
  }) async => await _engine._request(
    FinishProcessorSnapshotLoadRequest(
      id: _engine._getRequestId(),
      operationId: operationId,
      rollback: rollback,
    ),
    timeout: const Duration(seconds: 30),
  ) as LoadProcessorSnapshotResponse;

  /// Initializes any processing graph nodes that have not been initialized by
  /// the engine yet.
  Future<ProcessingGraphNodeInitialization> initializeNodes() {
    return _initializeNodes(bypassRenderRequestHold: false);
  }

  Future<ProcessingGraphNodeInitialization> initializeNodesForRender() {
    return _initializeNodes(bypassRenderRequestHold: true);
  }

  Future<ProcessingGraphNodeInitialization> _initializeNodes({
    required bool bypassRenderRequestHold,
  }) async {
    final id = _engine._getRequestId();

    final request = InitializeProcessingGraphNodesRequest(id: id);

    final response = (await _engine._request(
      request,
      bypassRenderRequestHold: bypassRenderRequestHold,
      timeout: Duration(seconds: 30),
    )) as InitializeProcessingGraphNodesResponse;

    if (response.error != null) {
      throw Exception(
        'initializeNodes(): engine returned an error: ${response.error}',
      );
    }

    return ProcessingGraphNodeInitialization(
      didInitialize: response.didInitialize,
      results: response.results,
    );
  }

  /// Publishes the processing graph to the audio thread.
  ///
  /// Any updates to the topology of the processing graph, e.g. adding or
  /// removing nodes or modifying connections, are done first by modifying the
  /// model. When ready, this method can be called to publish an updated set of
  /// processing instructions to the audio thread.
  Future<void> publish() {
    return _publish(bypassRenderRequestHold: false);
  }

  Future<void> publishForRender() {
    return _publish(bypassRenderRequestHold: true);
  }

  Future<void> _publish({required bool bypassRenderRequestHold}) async {
    final id = _engine._getRequestId();

    final request = PublishProcessingGraphRequest(id: id);

    final response = (await _engine._request(
      request,
      bypassRenderRequestHold: bypassRenderRequestHold,
    )) as PublishProcessingGraphResponse;

    if (response.success) {
      return;
    } else {
      throw Exception('publish(): engine returned an error: ${response.error}');
    }
  }

  /// Updates an engine-owned base value and returns the accepted setting.
  Future<ProcessingGraphParameterValue> setParameterValue(
    Id nodeId,
    int controlPortId,
    double value,
  ) {
    final node = _engine.project.processingGraph.nodes[nodeId];
    if (node == null || !node.canEditParameters) {
      return Future.error(
        StateError('The processor is not ready for parameter edits.'),
      );
    }
    final pending = _setParameterValue(nodeId, controlPortId, value);
    final edits = _pendingEdits.putIfAbsent(nodeId, () => {});
    edits.add(pending);
    void remove() {
      edits.remove(pending);
      if (edits.isEmpty) _pendingEdits.remove(nodeId);
    }

    pending.then<void>(
      (_) => remove(),
      onError: (Object _, StackTrace _) => remove(),
    );
    return pending;
  }

  Future<ProcessingGraphParameterValue> _setParameterValue(
    Id nodeId,
    int controlPortId,
    double value,
  ) async {
    if (!_engine.isRunning) throw StateError('The engine is not running.');
    final response = await _engine._request(
      SetProcessorParameterValueRequest(
        id: _engine._getRequestId(),
        nodeId: nodeId,
        controlPortId: controlPortId,
        value: value,
      ),
    ) as SetProcessorParameterValueResponse;
    if (response.error != null || response.parameterValue == null) {
      throw StateError(
        response.error ?? 'The engine returned no accepted parameter value.',
      );
    }
    return response.parameterValue!;
  }

  /// Captures base parameters and private state into the project's asset store.
  ///
  /// Returns its relative path, or null if the processor has no stored state.
  /// Unchanged contents reuse the previous file. Capture failures throw without
  /// replacing the model's existing reference.
  Future<String?> captureProcessorState(Id nodeId) async {
    final request = CaptureProcessorStateRequest(
      id: _engine._getRequestId(),
      nodeId: nodeId,
    );
    final response = await _engine._request(
      request,
      timeout: const Duration(seconds: 30),
    ) as CaptureProcessorStateResponse;
    if (response.error != null) throw StateError(response.error!);
    return response.relativePath;
  }

  /// Opens the native plugin editor window for the given third-party plugin
  /// node.
  void openPluginWindow(Id nodeId) {
    final id = _engine._getRequestId();

    final request = OpenPluginWindowRequest(id: id, nodeId: nodeId);

    _engine._requestNoReply(
      request,
      startupBehavior: StartupSendBehavior.dropDuringStartup,
    );
  }

  /// Sends a live event to the given LiveEventProviderProcessor node in the
  /// engine.
  ///
  /// The [event] parameter takes an object that is serialized as part of the
  /// message, and is defined inline with the message definition. See
  /// lib/engine_api/messages/processing_graph.dart for valid event types.
  void sendLiveEvent(Id liveEventProviderNodeId, Object event) async {
    assert(
      event is LiveEventRequestNoteOnEvent ||
          event is LiveEventRequestNoteOffEvent,
      'sendLiveEvent() requires a valid live event type.',
    );

    if (!_engine.isRunning) {
      return;
    }

    final id = _engine._getRequestId();

    final request = SendLiveEventRequest(
      id: id,
      liveEventProviderNodeId: liveEventProviderNodeId,
      event: event,
    );

    _engine._requestNoReply(request);
  }
}
