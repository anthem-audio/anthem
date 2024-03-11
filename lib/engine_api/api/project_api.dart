/*
  Copyright (C) 2023 - 2024 Joshua Wade

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

class ProjectApi {
  final Engine _engine;

  ProjectApi(this._engine);

  /// Creates a new arrangement, which maps to an `Edit` in Tracktion Engine.
  /// Returns a pointer to the Tracktion edit object within the engine process.
  ///
  /// The UI is responsible for cleaning up this memory.
  Future<int> addArrangement() {
    final completer = Completer<int>();

    final id = _engine._getRequestId();

    final request = RequestObjectBuilder(
      id: id,
      commandType: CommandTypeId.AddArrangement,
      command: AddArrangementObjectBuilder(),
    );

    _engine._request(id, request, onResponse: (response) {
      final inner = response.returnValue as AddArrangementResponse;
      completer.complete(inner.editId);
    });

    return completer.future;
  }

  /// Removes an arrangement with the given `Edit` pointer.
  ///
  /// See [addArrangement].
  void deleteArrangement(int editId) {
    final id = _engine._getRequestId();

    final request = RequestObjectBuilder(
      id: id,
      commandType: CommandTypeId.DeleteArrangement,
      command: DeleteArrangementObjectBuilder(editId: editId),
    );

    _engine._request(id, request);
  }

  Future<List<ProcessorDescription>> getProcessors() {
    final completer = Completer<List<ProcessorDescription>>();

    final id = _engine._getRequestId();

    final request = RequestObjectBuilder(
      id: id,
      commandType: CommandTypeId.GetProcessors,
      command: GetProcessorsObjectBuilder(),
    );

    _engine._request(id, request, onResponse: (response) {
      final inner = response.returnValue as GetProcessorsResponse;
      completer.complete(inner.processors!);
    });

    return completer.future;
  }

  Future<int> getMasterOutputNodeId() {
    final completer = Completer<int>();

    final id = _engine._getRequestId();

    final request = RequestObjectBuilder(
      id: id,
      commandType: CommandTypeId.GetMasterOutputNodeId,
      command: GetMasterOutputNodeIdObjectBuilder(),
    );

    _engine._request(id, request, onResponse: (response) {
      final inner = response.returnValue as GetMasterOutputNodeIdResponse;
      completer.complete(inner.nodeId);
    });

    return completer.future;
  }

  /// Adds the processor with the given ID to the engine's processing graph.
  Future<int> addProcessor(String processorId) {
    final id = _engine._getRequestId();

    final request = RequestObjectBuilder(
      id: id,
      commandType: CommandTypeId.AddProcessor,
      command: AddProcessorObjectBuilder(
        id: processorId,
      ),
    );

    final completer = Completer<int>();

    _engine._request(id, request, onResponse: (response) {
      final inner = response.returnValue as AddProcessorResponse;
      if (inner.success) {
        completer.complete(inner.processorId);
      } else {
        completer.completeError(false);
      }
    });

    return completer.future;
  }

  /// Connects two processors in the engine's processing graph.
  Future<void> connectProcessors({
    required int sourceId,
    required int sourcePortIndex,
    required int destinationId,
    required int destinationPortIndex,
    required ProcessorConnectionType connectionType,
  }) {
    final completer = Completer<void>();

    final id = _engine._getRequestId();

    final request = RequestObjectBuilder(
      id: id,
      commandType: CommandTypeId.ConnectProcessors,
      command: ConnectProcessorsObjectBuilder(
        sourceId: sourceId,
        sourcePortIndex: sourcePortIndex,
        destinationId: destinationId,
        destinationPortIndex: destinationPortIndex,
        connectionType: connectionType,
      ),
    );

    _engine._request(id, request, onResponse: (response) {
      if ((response.returnValue as ConnectProcessorsResponse).success) {
        completer.complete();
      } else {
        completer.completeError(false);
      }
    });

    return completer.future;
  }

  Future<void> compileProcessingGraph() {
    final completer = Completer<void>();

    final id = _engine._getRequestId();

    final request = RequestObjectBuilder(
      id: id,
      commandType: CommandTypeId.CompileProcessingGraph,
      command: CompileProcessingGraphObjectBuilder(),
    );

    _engine._request(id, request, onResponse: (response) {
      if ((response.returnValue as CompileProcessingGraphResponse).success) {
        completer.complete();
      } else {
        completer.completeError(
            (response.returnValue as CompileProcessingGraphResponse).error ??
                'Unknown error');
      }
    });

    return completer.future;
  }

  void noteOn({
    int channel = 1,
    required int note,
    double velocity = 0.5,
    required int editId,
  }) {
    final id = _engine._getRequestId();

    final request = RequestObjectBuilder(
      id: id,
      commandType: CommandTypeId.LiveNoteOn,
      command: LiveNoteOnObjectBuilder(
        editId: editId,
        channel: channel,
        note: note,
        velocity: velocity,
      ),
    );

    _engine._request(id, request);
  }

  void noteOff({
    int channel = 1,
    required int note,
    required int editId,
  }) {
    final id = _engine._getRequestId();

    final request = RequestObjectBuilder(
      id: id,
      commandType: CommandTypeId.LiveNoteOff,
      command: LiveNoteOffObjectBuilder(
        editId: editId,
        channel: channel,
        note: note,
      ),
    );

    _engine._request(id, request);
  }
}
