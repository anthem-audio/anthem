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
  String? error;

  InitializeProcessingGraphNodesResponse.uninitialized()
    : didInitialize = false,
      results = [];

  InitializeProcessingGraphNodesResponse({
    required int id,
    required this.didInitialize,
    required this.results,
    this.error,
  }) {
    super.id = id;
  }
}

@AnthemModel(serializable: true, generateCpp: true)
class ProcessingGraphNodeInitializationResult
    extends _ProcessingGraphNodeInitializationResult
    with _$ProcessingGraphNodeInitializationResultAnthemModelMixin {
  ProcessingGraphNodeInitializationResult.uninitialized()
    : super(nodeId: -1, success: false, parameterValues: []);

  ProcessingGraphNodeInitializationResult({
    required super.nodeId,
    required super.success,
    List<ProcessingGraphParameterValue>? parameterValues,
    super.error,
    super.portConfiguration,
  }) : super(parameterValues: parameterValues ?? []);

  factory ProcessingGraphNodeInitializationResult.fromJson(
    Map<String, dynamic> json,
  ) => _$ProcessingGraphNodeInitializationResultAnthemModelMixin.fromJson(json);
}

abstract class _ProcessingGraphNodeInitializationResult {
  Id nodeId;
  bool success;
  String? error;
  ProcessingGraphNodePortConfiguration? portConfiguration;
  List<ProcessingGraphParameterValue> parameterValues;

  _ProcessingGraphNodeInitializationResult({
    required this.nodeId,
    required this.success,
    required this.parameterValues,
    this.error,
    this.portConfiguration,
  });
}

@AnthemModel(serializable: true, generateCpp: true)
class ProcessingGraphParameterValue extends _ProcessingGraphParameterValue
    with _$ProcessingGraphParameterValueAnthemModelMixin {
  ProcessingGraphParameterValue.uninitialized()
    : super(controlPortId: -1, value: 0.0);

  ProcessingGraphParameterValue({
    required super.controlPortId,
    required super.value,
    super.displayText,
  });

  factory ProcessingGraphParameterValue.fromJson(Map<String, dynamic> json) =>
      _$ProcessingGraphParameterValueAnthemModelMixin.fromJson(json);
}

abstract class _ProcessingGraphParameterValue {
  int controlPortId;
  double value;
  String? displayText;

  _ProcessingGraphParameterValue({
    required this.controlPortId,
    required this.value,
    this.displayText,
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
    super.parameterDisplayMode,
    super.parameterUnitLabel,
    super.parameterNormalizedVisualBaseline,
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
  String? parameterDisplayMode;
  String? parameterUnitLabel;
  double? parameterNormalizedVisualBaseline;

  _ProcessingGraphPortConfiguration({
    required this.id,
    this.name,
    this.channelCount,
    this.parameterDefaultValue,
    this.parameterDisplayMode,
    this.parameterUnitLabel,
    this.parameterNormalizedVisualBaseline,
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

/// An unsolicited event about a processing graph node's processor.
sealed class ProcessorEvent extends IpcEvent {
  late Id nodeId;

  ProcessorEvent.uninitialized();

  ProcessorEvent({required this.nodeId});
}

class PluginChangedEvent extends ProcessorEvent {
  late bool latencyChanged;
  late bool parameterInfoChanged;
  late bool programChanged;
  late bool nonParameterStateChanged;

  PluginChangedEvent.uninitialized() : super.uninitialized();

  PluginChangedEvent({
    required super.nodeId,
    required this.latencyChanged,
    required this.parameterInfoChanged,
    required this.programChanged,
    required this.nonParameterStateChanged,
  });
}

class ProcessorParameterChangedEvent extends ProcessorEvent {
  late int controlPortId;
  late double value;
  String? displayText;

  ProcessorParameterChangedEvent.uninitialized() : super.uninitialized();

  ProcessorParameterChangedEvent({
    required super.nodeId,
    required this.controlPortId,
    required this.value,
    this.displayText,
  });
}

class ProcessorParameterGestureEvent extends ProcessorEvent {
  late int controlPortId;
  late bool isStarting;
  late double value;
  String? displayText;

  ProcessorParameterGestureEvent.uninitialized() : super.uninitialized();

  ProcessorParameterGestureEvent({
    required super.nodeId,
    required this.controlPortId,
    required this.isStarting,
    required this.value,
    this.displayText,
  });
}

class ProcessorParameterSnapshotEvent extends ProcessorEvent {
  late List<ProcessingGraphParameterValue> parameterValues;

  ProcessorParameterSnapshotEvent.uninitialized()
    : parameterValues = [],
      super.uninitialized();

  ProcessorParameterSnapshotEvent({
    required super.nodeId,
    required this.parameterValues,
  });
}

/// Restores the UI cache after callback notifications could not be retained.
/// Any unfinished parameter gestures for this node must be discarded.
class ProcessorParameterResyncEvent extends ProcessorEvent {
  late List<ProcessingGraphParameterValue> parameterValues;

  ProcessorParameterResyncEvent.uninitialized()
    : parameterValues = [],
      super.uninitialized();

  ProcessorParameterResyncEvent({
    required super.nodeId,
    required this.parameterValues,
  });
}

class CaptureProcessorStateRequest extends Request {
  late Id nodeId;

  CaptureProcessorStateRequest.uninitialized();

  CaptureProcessorStateRequest({required int id, required this.nodeId}) {
    super.id = id;
  }
}

/// Returns a processor snapshot asset path without transferring its contents.
class CaptureProcessorStateResponse extends Response {
  String? relativePath;
  String? error;

  CaptureProcessorStateResponse.uninitialized();

  CaptureProcessorStateResponse({
    required int id,
    required this.relativePath,
    required this.error,
  }) {
    super.id = id;
  }
}

class SetProcessorParameterValueRequest extends Request {
  late Id nodeId;
  late int controlPortId;
  late double value;

  SetProcessorParameterValueRequest.uninitialized();

  SetProcessorParameterValueRequest({
    required int id,
    required this.nodeId,
    required this.controlPortId,
    required this.value,
  }) {
    super.id = id;
  }
}

class SetProcessorParameterValueResponse extends Response {
  ProcessingGraphParameterValue? parameterValue;
  String? error;

  SetProcessorParameterValueResponse.uninitialized();

  SetProcessorParameterValueResponse({
    required int id,
    this.parameterValue,
    this.error,
  }) {
    super.id = id;
  }
}

class OpenPluginWindowRequest extends Request {
  late Id nodeId;

  OpenPluginWindowRequest.uninitialized();

  OpenPluginWindowRequest({required int id, required this.nodeId}) {
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

/// Saves an independently retained snapshot, including for stateless processors.
class SaveProcessorSnapshotRequest extends Request {
  late Id nodeId;
  SaveProcessorSnapshotRequest.uninitialized();
  SaveProcessorSnapshotRequest({required int id, required this.nodeId}) {
    super.id = id;
  }
}

class SaveProcessorSnapshotResponse extends Response {
  /// Handed to the UI on success; the engine will not use or release this token.
  /// The session scope retains it until the UI adopts it or the session closes.
  String? retentionId;
  String? error;
  SaveProcessorSnapshotResponse.uninitialized();
  SaveProcessorSnapshotResponse({
    required int id,
    this.retentionId,
    this.error,
  }) {
    super.id = id;
  }
}

/// Begins a paused state replacement. The recovery file is retained by the UI.
class LoadProcessorSnapshotRequest extends Request {
  late Id nodeId;
  late String retentionId;
  late String recoveryRetentionId;
  LoadProcessorSnapshotRequest.uninitialized();
  LoadProcessorSnapshotRequest({
    required int id,
    required this.nodeId,
    required this.retentionId,
    required this.recoveryRetentionId,
  }) {
    super.id = id;
  }
}

class LoadProcessorSnapshotResponse extends Response {
  int? operationId;
  ProcessingGraphNodeInitializationResult? result;
  String? error;
  LoadProcessorSnapshotResponse.uninitialized();
  LoadProcessorSnapshotResponse({
    required int id,
    this.operationId,
    this.result,
    this.error,
  }) {
    super.id = id;
  }
}

/// Reconciled model updates precede this request. Rollback restores the recovery
/// state and returns its description; otherwise publish and await activation.
class FinishProcessorSnapshotLoadRequest extends Request {
  late int operationId;
  late bool rollback;
  FinishProcessorSnapshotLoadRequest.uninitialized();
  FinishProcessorSnapshotLoadRequest({
    required int id,
    required this.operationId,
    this.rollback = false,
  }) {
    super.id = id;
  }
}
