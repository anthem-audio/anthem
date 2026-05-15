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

// ignore_for_file: non_constant_identifier_names

part of 'messages.dart';

class InitializeProcessingGraphNodesRequest extends Request {
  InitializeProcessingGraphNodesRequest.uninitialized();

  InitializeProcessingGraphNodesRequest({required int id}) {
    super.id = id;
  }
}

class InitializeProcessingGraphNodesResponse extends Response {
  late bool didInitialize;
  late List<ProcessingGraphNodeInitializationResult> results;

  InitializeProcessingGraphNodesResponse.uninitialized()
    : didInitialize = false,
      results = [];

  InitializeProcessingGraphNodesResponse({
    required int id,
    required this.didInitialize,
    required this.results,
  }) {
    super.id = id;
  }
}

@AnthemModel(serializable: true, generateCpp: true)
class ProcessingGraphNodeInitializationResult
    extends _ProcessingGraphNodeInitializationResult
    with _$ProcessingGraphNodeInitializationResultAnthemModelMixin {
  ProcessingGraphNodeInitializationResult.uninitialized()
    : super(nodeId: -1, success: false);

  ProcessingGraphNodeInitializationResult({
    required super.nodeId,
    required super.success,
    super.error,
    super.portConfiguration,
  });

  factory ProcessingGraphNodeInitializationResult.fromJson(
    Map<String, dynamic> json,
  ) => _$ProcessingGraphNodeInitializationResultAnthemModelMixin.fromJson(json);
}

abstract class _ProcessingGraphNodeInitializationResult {
  Id nodeId;
  bool success;
  String? error;
  ProcessingGraphNodePortConfiguration? portConfiguration;

  _ProcessingGraphNodeInitializationResult({
    required this.nodeId,
    required this.success,
    this.error,
    this.portConfiguration,
  });
}

@AnthemModel(serializable: true, generateCpp: true)
class ProcessingGraphNodePortConfiguration
    extends _ProcessingGraphNodePortConfiguration
    with _$ProcessingGraphNodePortConfigurationAnthemModelMixin {
  ProcessingGraphNodePortConfiguration.uninitialized()
    : super(
        audioInputPorts: [],
        audioOutputPorts: [],
        eventInputPorts: [],
        eventOutputPorts: [],
        controlInputPorts: [],
        controlOutputPorts: [],
      );

  ProcessingGraphNodePortConfiguration({
    required super.audioInputPorts,
    required super.audioOutputPorts,
    required super.eventInputPorts,
    required super.eventOutputPorts,
    required super.controlInputPorts,
    required super.controlOutputPorts,
  });

  factory ProcessingGraphNodePortConfiguration.fromJson(
    Map<String, dynamic> json,
  ) => _$ProcessingGraphNodePortConfigurationAnthemModelMixin.fromJson(json);
}

abstract class _ProcessingGraphNodePortConfiguration {
  List<ProcessingGraphPortConfiguration> audioInputPorts;
  List<ProcessingGraphPortConfiguration> audioOutputPorts;
  List<ProcessingGraphPortConfiguration> eventInputPorts;
  List<ProcessingGraphPortConfiguration> eventOutputPorts;
  List<ProcessingGraphPortConfiguration> controlInputPorts;
  List<ProcessingGraphPortConfiguration> controlOutputPorts;

  _ProcessingGraphNodePortConfiguration({
    required this.audioInputPorts,
    required this.audioOutputPorts,
    required this.eventInputPorts,
    required this.eventOutputPorts,
    required this.controlInputPorts,
    required this.controlOutputPorts,
  });
}

@AnthemModel(serializable: true, generateCpp: true)
class ProcessingGraphPortConfiguration extends _ProcessingGraphPortConfiguration
    with _$ProcessingGraphPortConfigurationAnthemModelMixin {
  ProcessingGraphPortConfiguration.uninitialized() : super(id: -1);

  ProcessingGraphPortConfiguration({
    required super.id,
    super.name,
    super.channelCount,
    super.parameterDefaultValue,
  });

  factory ProcessingGraphPortConfiguration.fromJson(
    Map<String, dynamic> json,
  ) => _$ProcessingGraphPortConfigurationAnthemModelMixin.fromJson(json);
}

abstract class _ProcessingGraphPortConfiguration {
  int id;
  String? name;
  int? channelCount;
  double? parameterDefaultValue;

  _ProcessingGraphPortConfiguration({
    required this.id,
    this.name,
    this.channelCount,
    this.parameterDefaultValue,
  });
}

class PublishProcessingGraphRequest extends Request {
  PublishProcessingGraphRequest.uninitialized();

  PublishProcessingGraphRequest({required int id}) {
    super.id = id;
  }
}

class PublishProcessingGraphResponse extends Response {
  late bool success;
  String? error;

  PublishProcessingGraphResponse.uninitialized();

  PublishProcessingGraphResponse({
    required int id,
    required this.success,
    this.error,
  }) {
    super.id = id;
  }
}

class PluginChangedEvent extends Response {
  late Id nodeId;

  late bool latencyChanged;
  late bool parameterInfoChanged;
  late bool programChanged;
  late bool nonParameterStateChanged;

  PluginChangedEvent.uninitialized();

  PluginChangedEvent({
    required int id,
    required this.nodeId,
    required this.latencyChanged,
    required this.parameterInfoChanged,
    required this.programChanged,
    required this.nonParameterStateChanged,
  }) {
    super.id = id;
  }
}

class PluginParameterChangedEvent extends Response {
  late Id nodeId;
  late int parameterIndex;
  late double newValue;

  PluginParameterChangedEvent.uninitialized();

  PluginParameterChangedEvent({
    required int id,
    required this.nodeId,
    required this.parameterIndex,
    required this.newValue,
  }) {
    super.id = id;
  }
}

class GetPluginStateRequest extends Request {
  late Id nodeId;

  GetPluginStateRequest.uninitialized();

  GetPluginStateRequest({required int id, required this.nodeId}) {
    super.id = id;
  }
}

class GetPluginStateResponse extends Response {
  late String state;
  late bool isValid;

  GetPluginStateResponse.uninitialized();

  GetPluginStateResponse({
    required int id,
    required this.state,
    required this.isValid,
  }) {
    super.id = id;
  }
}

class SetPluginStateRequest extends Request {
  late Id nodeId;
  late String state;

  SetPluginStateRequest.uninitialized();

  SetPluginStateRequest({
    required int id,
    required this.nodeId,
    required this.state,
  }) {
    super.id = id;
  }
}

/// An event that is fired when a third-party plugin is loaded for the given
/// node.
///
/// This will only fire for nodes that load third-party plugins.
class PluginLoadedEvent extends Response {
  late Id nodeId;

  PluginLoadedEvent.uninitialized();

  PluginLoadedEvent({required int id, required this.nodeId}) {
    super.id = id;
  }
}

@AnthemModel(serializable: true, generateCpp: true)
class LiveEventRequestNoteOnEvent extends _LiveEventRequestNoteOnEvent
    with _$LiveEventRequestNoteOnEventAnthemModelMixin {
  LiveEventRequestNoteOnEvent.uninitialized()
    : super(noteId: 0, pitch: 0, channel: 0, velocity: 0.0, pan: 0.0);

  LiveEventRequestNoteOnEvent({
    required super.noteId,
    required super.pitch,
    required super.channel,
    required super.velocity,
    required super.pan,
  });

  factory LiveEventRequestNoteOnEvent.fromJson(Map<String, dynamic> json) =>
      _$LiveEventRequestNoteOnEventAnthemModelMixin.fromJson(json);
}

abstract class _LiveEventRequestNoteOnEvent {
  int noteId;
  int pitch;
  int channel;
  double velocity;
  double pan;

  _LiveEventRequestNoteOnEvent({
    required this.noteId,
    required this.pitch,
    required this.channel,
    required this.velocity,
    required this.pan,
  });
}

@AnthemModel(serializable: true, generateCpp: true)
class LiveEventRequestNoteOffEvent extends _LiveEventRequestNoteOffEvent
    with _$LiveEventRequestNoteOffEventAnthemModelMixin {
  LiveEventRequestNoteOffEvent.uninitialized()
    : super(noteId: 0, pitch: 0, channel: 0);

  LiveEventRequestNoteOffEvent({
    required super.noteId,
    required super.pitch,
    required super.channel,
  });

  factory LiveEventRequestNoteOffEvent.fromJson(Map<String, dynamic> json) =>
      _$LiveEventRequestNoteOffEventAnthemModelMixin.fromJson(json);
}

abstract class _LiveEventRequestNoteOffEvent {
  int noteId;
  int pitch;
  int channel;

  _LiveEventRequestNoteOffEvent({
    required this.noteId,
    required this.pitch,
    required this.channel,
  });
}

/// Sends a live event to the engine, which will be picked up by the given
/// LiveEventProviderProcessor node.
class SendLiveEventRequest extends Request {
  late Id liveEventProviderNodeId;

  @Union([LiveEventRequestNoteOnEvent, LiveEventRequestNoteOffEvent])
  late Object event;

  SendLiveEventRequest.uninitialized();

  SendLiveEventRequest({
    required int id,
    required this.liveEventProviderNodeId,
    required this.event,
  }) {
    super.id = id;
  }
}
