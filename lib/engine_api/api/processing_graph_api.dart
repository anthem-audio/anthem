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

  Future<List<ProcessorDescription>> getAvailableProcessors() async {
    final id = _engine._getRequestId();

    final request = RequestObjectBuilder(
      id: id,
      commandType: CommandTypeId.GetProcessors,
      command: GetProcessorsObjectBuilder(),
    );

    final response = (await _engine._request(id, request)).returnValue
        as GetProcessorsResponse;

    return response.processors!;
  }

  Future<int> getMasterOutputNodeId() async {
    final id = _engine._getRequestId();

    final request = RequestObjectBuilder(
      id: id,
      commandType: CommandTypeId.GetMasterOutputNodeId,
      command: GetMasterOutputNodeIdObjectBuilder(),
    );

    final response = (await _engine._request(id, request)).returnValue
        as GetMasterOutputNodeIdResponse;

    return response.nodeId;
  }

  /// Adds the processor with the given ID to the engine's processing graph.
  Future<int> addProcessor(String processorId) async {
    final id = _engine._getRequestId();

    final request = RequestObjectBuilder(
      id: id,
      commandType: CommandTypeId.AddProcessor,
      command: AddProcessorObjectBuilder(
        id: processorId,
      ),
    );

    final response = (await _engine._request(id, request)).returnValue
        as AddProcessorResponse;

    if (response.success) {
      return response.processorId;
    } else {
      throw Exception(
          'addProcessor(): engine returned an error: ${response.error}');
    }
  }

  /// Removes the processor with the given ID from the engine's processing
  /// graph.
  Future<void> removeProcessor(int processorId) async {
    final id = _engine._getRequestId();

    final request = RequestObjectBuilder(
      id: id,
      commandType: CommandTypeId.RemoveProcessor,
      command: RemoveProcessorObjectBuilder(
        id: processorId,
      ),
    );

    final response = (await _engine._request(id, request)).returnValue
        as RemoveProcessorResponse;

    if (response.success) {
      return;
    } else {
      throw Exception(
          'removeProcessor(): engine returned an error: ${response.error}');
    }
  }

  /// Connects two processors in the engine's processing graph.
  Future<void> connectProcessors({
    required int sourceId,
    required int sourcePortIndex,
    required int destinationId,
    required int destinationPortIndex,
    required ProcessorConnectionType connectionType,
  }) async {
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

    final response = (await _engine._request(id, request)).returnValue
        as ConnectProcessorsResponse;

    if (response.success) {
      return;
    } else {
      throw Exception(
          'connectProcessors(): engine returned an error: ${response.error}');
    }
  }

  /// Disconnects two processors in the engine's processing graph.
  Future<void> disconnectProcessors({
    required int sourceId,
    required int sourcePortIndex,
    required int destinationId,
    required int destinationPortIndex,
    required ProcessorConnectionType connectionType,
  }) async {
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

    final response = (await _engine._request(id, request)).returnValue
        as DisconnectProcessorsResponse;

    if (response.success) {
      return;
    } else {
      throw Exception(
          'disconnectProcessors(): engine returned an error: ${response.error}');
    }
  }

  /// Compiles the processing graph, and pushes the result to the audio thread.
  ///
  /// Updates to the topology of the processing graph, e.g. adding or removing
  /// nodes or modifying connections, are done first on the main thread in the
  /// engine. When ready, this method can be called to compile an updated set of
  /// processing instructions and push them to the audio thread.
  Future<void> compile() async {
    final id = _engine._getRequestId();

    final request = RequestObjectBuilder(
      id: id,
      commandType: CommandTypeId.CompileProcessingGraph,
      command: CompileProcessingGraphObjectBuilder(),
    );

    final response = (await _engine._request(id, request)).returnValue
        as CompileProcessingGraphResponse;

    if (response.success) {
      return;
    } else {
      throw Exception('compile(): engine returned an error: ${response.error}');
    }
  }

  /// Sets the static value of a parameter.
  Future<void> setParameter({
    required int nodeId,
    required int parameterId,
    required double value,
  }) async {
    final id = _engine._getRequestId();

    final request = RequestObjectBuilder(
      id: id,
      commandType: CommandTypeId.SetParameter,
      command: SetParameterObjectBuilder(
        nodeId: nodeId,
        parameterId: parameterId,
        value: value,
      ),
    );

    final response = (await _engine._request(id, request)).returnValue
        as SetParameterResponse;

    if (response.success) {
      return;
    } else {
      throw Exception('compile(): engine returned an error');
    }
  }

  /// Gets port info for a given processor in the graph.
  Future<GetProcessorPortInfoResponse> getProcessorPortInfo(
      {required int processorId}) async {
    final id = _engine._getRequestId();

    final request = RequestObjectBuilder(
      id: id,
      commandType: CommandTypeId.GetProcessorPorts,
      command: GetProcessorPortsObjectBuilder(
        id: processorId,
      ),
    );

    final response = (await _engine._request(id, request)).returnValue
        as GetProcessorPortsResponse;

    if (!response.success) {
      throw Exception(
          'getProcessorPortInfo(): error getting processor port info: ${response.error}');
    }

    final audioInputPorts =
        response.inputAudioPorts!.map((port) => (id: port.id)).toList();
    final controlInputPorts =
        response.inputControlPorts!.map((port) => (id: port.id)).toList();
    final midiInputPorts =
        response.inputMidiPorts!.map((port) => (id: port.id)).toList();
    final audioOutputPorts =
        response.outputAudioPorts!.map((port) => (id: port.id)).toList();
    final controlOutputPorts =
        response.outputControlPorts!.map((port) => (id: port.id)).toList();
    final midiOutputPorts =
        response.outputMidiPorts!.map((port) => (id: port.id)).toList();
    final parameters = response.parameters!
        .map((parameter) => (
              id: parameter.id,
              defaultValue: parameter.defaultValue,
              minValue: parameter.minValue,
              maxValue: parameter.maxValue,
            ))
        .toList();

    return (
      audioInputPorts: audioInputPorts,
      controlInputPorts: controlInputPorts,
      midiInputPorts: midiInputPorts,
      audioOutputPorts: audioOutputPorts,
      controlOutputPorts: controlOutputPorts,
      midiOutputPorts: midiOutputPorts,
      parameters: parameters,
    );
  }
}

typedef PortInfo = ({int id});

typedef ParameterInfo = ({
  int id,
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
