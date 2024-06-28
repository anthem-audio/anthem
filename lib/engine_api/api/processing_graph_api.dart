/*
  Copyright (C) 2024 Joshua Wade

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

/// This class is an API for the processing graph in the Anthem Engine. It can
/// be used to add and remove nodes, and to connect and disconnect existing
/// nodes.
class ProcessingGraphApi {
  final Engine _engine;

  ProcessingGraphApi(this._engine);

  Future<List<ProcessorDescription>> getAvailableProcessors() {
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

  /// Removes the processor with the given ID from the engine's processing
  /// graph.
  Future<void> removeProcessor(int processorId) {
    final completer = Completer<void>();

    final id = _engine._getRequestId();

    final request = RequestObjectBuilder(
      id: id,
      commandType: CommandTypeId.RemoveProcessor,
      command: RemoveProcessorObjectBuilder(
        id: processorId,
      ),
    );

    _engine._request(id, request, onResponse: (response) {
      if ((response.returnValue as RemoveProcessorResponse).success) {
        completer.complete();
      } else {
        completer.completeError(
            (response.returnValue as RemoveProcessorResponse).error ??
                'Unknown error');
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
        completer.completeError(
            (response.returnValue as ConnectProcessorsResponse).error ??
                'Unknown error');
      }
    });

    return completer.future;
  }

  /// Disconnects two processors in the engine's processing graph.
  Future<void> disconnectProcessors({
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
      commandType: CommandTypeId.DisconnectProcessors,
      command: DisconnectProcessorsObjectBuilder(
        sourceId: sourceId,
        sourcePortIndex: sourcePortIndex,
        destinationId: destinationId,
        destinationPortIndex: destinationPortIndex,
        connectionType: connectionType,
      ),
    );

    _engine._request(id, request, onResponse: (response) {
      if ((response.returnValue as DisconnectProcessorsResponse).success) {
        completer.complete();
      } else {
        completer.completeError(
            (response.returnValue as DisconnectProcessorsResponse).error ??
                'Unknown error');
      }
    });

    return completer.future;
  }

  /// Compiles the processing graph, and pushes the result to the audio thread.
  ///
  /// Updates to the topology of the processing graph, e.g. adding or removing
  /// nodes or modifying connections, are done first on the main thread in the
  /// engine. When ready, this method can be called to compile an updated set of
  /// processing instructions and push them to the audio thread.
  Future<void> compile() {
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

  /// Sets the static value of a parameter.
  Future<void> setParameter({
    required int processorId,
    required int parameterIndex,
    required double value,
  }) {
    final completer = Completer<void>();

    final id = _engine._getRequestId();

    final request = RequestObjectBuilder(
      id: id,
      commandType: CommandTypeId.SetParameter,
      command: SetParameterObjectBuilder(
        processorId: processorId,
        parameterIndex: parameterIndex,
        value: value,
      ),
    );

    _engine._request(id, request, onResponse: (response) {
      if ((response.returnValue as SetParameterResponse).success) {
        completer.complete();
      } else {
        completer.completeError('error setting parameter');
      }
    });

    return completer.future;
  }

  /// Gets port info for a given processor in the graph.
  Future<GetProcessorPortInfoResponse> getProcessorPortInfo(
      {required int processorId}) {
    final completer = Completer<GetProcessorPortInfoResponse>();

    final id = _engine._getRequestId();

    final request = RequestObjectBuilder(
      id: id,
      commandType: CommandTypeId.GetProcessorPorts,
      command: GetProcessorPortsObjectBuilder(
        id: processorId,
      ),
    );

    _engine._request(id, request, onResponse: (response) {
      final inner = response.returnValue as GetProcessorPortsResponse;

      if (!inner.success) {
        completer
            .completeError('Error getting processor port info: ${inner.error}');
        return;
      }

      final audioInputPorts =
          inner.inputAudioPorts!.map((port) => (name: port.name!)).toList();
      final controlInputPorts =
          inner.inputControlPorts!.map((port) => (name: port.name!)).toList();
      final midiInputPorts =
          inner.inputMidiPorts!.map((port) => (name: port.name!)).toList();
      final audioOutputPorts =
          inner.outputAudioPorts!.map((port) => (name: port.name!)).toList();
      final controlOutputPorts =
          inner.outputControlPorts!.map((port) => (name: port.name!)).toList();
      final midiOutputPorts =
          inner.outputMidiPorts!.map((port) => (name: port.name!)).toList();
      final parameters = inner.parameters!
          .map((parameter) => (
                name: parameter.name!,
                defaultValue: parameter.defaultValue,
                minValue: parameter.minValue,
                maxValue: parameter.maxValue,
              ))
          .toList();

      completer.complete((
        audioInputPorts: audioInputPorts,
        controlInputPorts: controlInputPorts,
        midiInputPorts: midiInputPorts,
        audioOutputPorts: audioOutputPorts,
        controlOutputPorts: controlOutputPorts,
        midiOutputPorts: midiOutputPorts,
        parameters: parameters,
      ));
    });

    return completer.future;
  }
}

typedef PortInfo = ({String name});

typedef ParameterInfo = ({
  String name,
  double defaultValue,
  double minValue,
  double maxValue,
});

typedef GetProcessorPortInfoResponse = ({
  List<PortInfo> audioInputPorts,
  List<PortInfo> controlInputPorts,
  List<PortInfo> midiInputPorts,
  List<PortInfo> audioOutputPorts,
  List<PortInfo> controlOutputPorts,
  List<PortInfo> midiOutputPorts,
  List<ParameterInfo> parameters,
});
