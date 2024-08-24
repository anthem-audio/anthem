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

// ignore_for_file: non_constant_identifier_names

part of 'messages.dart';

class GetMasterOutputNodeIdRequest extends Request {}

class GetMasterOutputNodeIdResponse extends Response {
  late int nodeId;
}

// Adds a processor to the processing graph
class AddProcessorRequest extends Request {
  late String processorId;
}

class AddProcessorResponse extends Response {
  // Whether the command succeeded
  late bool success;

  // If the command succeeded, this will contain an ID to look up the processor
  late int processorId;

  // If the command failed, this will contain an error message
  late String error;
}

// Removes a processor from the processing graph
class RemoveProcessorRequest extends Request {
  late int nodeId;
}

class RemoveProcessorResponse extends Response {
  late bool success;
  late String error;
}

enum ProcessorConnectionType { audio, noteEvent, control }

// Connects two processors in the node graph (e.g. an instrument audio output to
// an effect audio input).
class ConnectProcessorsRequest extends Request {
  late int sourceId;
  late int destinationId;

  late ProcessorConnectionType connectionType;

  late int sourcePortIndex;
  late int destinationPortIndex;
}

class ConnectProcessorsResponse extends Response {
  late bool success;
  late String error;
}

// Disconnects two processors in the node graph.
class DisconnectProcessorsRequest extends Request {
  late int sourceId;
  late int destinationId;

  late ProcessorConnectionType connectionType;

  late int sourcePortIndex;
  late int destinationPortIndex;
}

class DisconnectProcessorsResponse extends Response {
  late bool success;
  late String error;
}

// Processor category enum
enum ProcessorCategory { effect, generator, utility }

@AnthemModel(serializable: true)
class ProcessorDescription extends _ProcessorDescription
    with _$ProcessorDescriptionAnthemModelMixin {
  ProcessorDescription();

  factory ProcessorDescription.fromJson_ANTHEM(Map<String, dynamic> json) =>
      _$ProcessorDescriptionAnthemModelMixin.fromJson_ANTHEM(json);

  ProcessorDescription.create({
    required String processorId,
    required ProcessorCategory category,
  }) {
    this.processorId = processorId;
    this.category = category;
  }
}

class _ProcessorDescription {
  late String processorId;
  late ProcessorCategory category;
}

class GetProcessorsRequest extends Request {}

class GetProcessorsResponse extends Response {
  late List<ProcessorDescription> processors;
}

@AnthemModel(serializable: true)
class ProcessorPortDescription extends _ProcessorPortDescription
    with _$ProcessorPortDescriptionAnthemModelMixin {
  ProcessorPortDescription();

  factory ProcessorPortDescription.fromJson_ANTHEM(Map<String, dynamic> json) =>
      _$ProcessorPortDescriptionAnthemModelMixin.fromJson_ANTHEM(json);

  ProcessorPortDescription.create({required int id}) {
    this.id = id;
  }
}

class _ProcessorPortDescription {
  late int id;
}

@AnthemModel(serializable: true)
class ProcessorParameterDescription extends _ProcessorParameterDescription
    with _$ProcessorParameterDescriptionAnthemModelMixin {
  ProcessorParameterDescription();

  factory ProcessorParameterDescription.fromJson_ANTHEM(
          Map<String, dynamic> json) =>
      _$ProcessorParameterDescriptionAnthemModelMixin.fromJson_ANTHEM(json);

  ProcessorParameterDescription.create({
    required int id,
    required double defaultValue,
    required double minValue,
    required double maxValue,
  }) {
    this.id = id;
    this.defaultValue = defaultValue;
    this.minValue = minValue;
    this.maxValue = maxValue;
  }
}

class _ProcessorParameterDescription {
  late int id;
  late double defaultValue;
  late double minValue;
  late double maxValue;
}

// Gets the ports of a node instance with the given ID
class GetProcessorPortsRequest extends Request {
  late int nodeId;
}

class GetProcessorPortsResponse extends Response {
  // Whether the command succeeded
  late bool success;

  // If the command failed, this will contain an error message
  late String error;

  late List<ProcessorPortDescription> inputAudioPorts;
  late List<ProcessorPortDescription> inputControlPorts;
  late List<ProcessorPortDescription> inputNoteEventPorts;

  late List<ProcessorPortDescription> outputAudioPorts;
  late List<ProcessorPortDescription> outputControlPorts;
  late List<ProcessorPortDescription> outputNoteEventPorts;

  late ProcessorParameterDescription parameters;
}

// Compiles the processing graph and sends the result to the audio thread. This
// must be called after any graph changes.
class CompileProcessingGraphRequest extends Request {}

class CompileProcessingGraphResponse extends Response {
  late bool success;
  late String error;
}
