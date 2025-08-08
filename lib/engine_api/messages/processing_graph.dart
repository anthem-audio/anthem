/*
  Copyright (C) 2024 - 2025 Joshua Wade

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

class CompileProcessingGraphRequest extends Request {
  CompileProcessingGraphRequest.uninitialized();

  CompileProcessingGraphRequest({required int id}) {
    super.id = id;
  }
}

class CompileProcessingGraphResponse extends Response {
  late bool success;
  String? error;

  CompileProcessingGraphResponse.uninitialized();

  CompileProcessingGraphResponse({
    required int id,
    required this.success,
    this.error,
  }) {
    super.id = id;
  }
}

class PluginChangedEvent extends Response {
  late String nodeId;

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
  late String nodeId;
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
  late String nodeId;

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
  late String nodeId;
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
  late String nodeId;

  PluginLoadedEvent.uninitialized();

  PluginLoadedEvent({required int id, required this.nodeId}) {
    super.id = id;
  }
}

@AnthemModel(serializable: true, generateCpp: true)
class LiveEventRequestNoteOnEvent extends _LiveEventRequestNoteOnEvent
    with _$LiveEventRequestNoteOnEventAnthemModelMixin {
  LiveEventRequestNoteOnEvent.uninitialized()
    : super(pitch: 0, velocity: 0.0, pan: 0.0);

  LiveEventRequestNoteOnEvent({
    required super.pitch,
    required super.velocity,
    required super.pan,
  });

  factory LiveEventRequestNoteOnEvent.fromJson(Map<String, dynamic> json) =>
      _$LiveEventRequestNoteOnEventAnthemModelMixin.fromJson(json);
}

abstract class _LiveEventRequestNoteOnEvent {
  int pitch;
  double velocity;
  double pan;

  _LiveEventRequestNoteOnEvent({
    required this.pitch,
    required this.velocity,
    required this.pan,
  });
}

@AnthemModel(serializable: true, generateCpp: true)
class LiveEventRequestNoteOffEvent extends _LiveEventRequestNoteOffEvent
    with _$LiveEventRequestNoteOffEventAnthemModelMixin {
  LiveEventRequestNoteOffEvent.uninitialized() : super(pitch: 0);

  LiveEventRequestNoteOffEvent({required super.pitch});

  factory LiveEventRequestNoteOffEvent.fromJson(Map<String, dynamic> json) =>
      _$LiveEventRequestNoteOffEventAnthemModelMixin.fromJson(json);
}

abstract class _LiveEventRequestNoteOffEvent {
  int pitch;

  _LiveEventRequestNoteOffEvent({required this.pitch});
}

/// Sends a live event to the engine, which will be picked up by the given
/// LiveEventProviderProcessor node.
class SendLiveEventRequest extends Request {
  late String liveEventProviderNodeId;

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
