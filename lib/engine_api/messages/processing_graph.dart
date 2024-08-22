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

part of 'messages.dart';

class GetMasterOutputNodeIdRequest extends Request {}
class GetMasterOutputNodeIdResponse extends Response {
  late int nodeId;
}

// Adds a processor to the processing graph
class AddProcessorRequest extends Request{
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

enum ProcessorConnectionType {
  audio,
  noteEvent,
  control
}

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
enum ProcessorCategory {
  effect,
  generator,
  utility
}

class ProcessorDescription {
  late String processorId;
  late ProcessorCategory category;
}

class GetProcessorsRequest extends Request {}
class GetProcessorsResponse extends Response {
  late List<ProcessorDescription> processors;
}

class ProcessorPortDescription {
  late int id;
}

class ProcessorParameterDescription {
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
