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

enum ProcessorType {
  generator,
  effect,
  utility,
}

/// Defines a processor, including ports and parameters. This is used to inform
/// the UI about what ports exist (and therefore can be connected to things like
/// automation), what parameters exist and can be set, and so on.
class ProcessorDefinition {
  final String id;
  final String name;
  final ProcessorType type;

  final List<ProcessorPort> inputAudioPorts;
  final List<ProcessorPort> inputControlPorts;
  final List<ProcessorPort> inputMIDIPorts;

  final List<ProcessorPort> outputAudioPorts;
  final List<ProcessorPort> outputControlPorts;
  final List<ProcessorPort> outputMIDIPorts;

  final List<ProcessorParameter> parameters;

  const ProcessorDefinition({
    required this.id,
    required this.name,
    required this.type,
    required this.inputAudioPorts,
    required this.inputControlPorts,
    required this.inputMIDIPorts,
    required this.outputAudioPorts,
    required this.outputControlPorts,
    required this.outputMIDIPorts,
    required this.parameters,
  });
}

/// Descries a processor port.
class ProcessorPort {
  /// The ID of this port. This mirrors parameter ID as described by VST3, and
  /// is treated similarly. It allows plugins to modify ports between versions
  /// without breaking connections in existing project files.
  final int id;

  /// The human-readable name of this port.
  final String name;

  const ProcessorPort({required this.id, required this.name});
}

/// Describes details about a processor parameter, such as min/max values. Every
/// processor must have the same number of parameters as it has control inputs.
class ProcessorParameter {
  /// The ID of the control input port associated with this parameter.
  final int id;

  /// The default value for this parameter.
  final double defaultValue;

  /// The max value for this parameter.
  final double minValue;

  /// The min value for this parameter.
  final double maxValue;

  const ProcessorParameter({
    required this.id,
    required this.defaultValue,
    required this.minValue,
    required this.maxValue,
  });
}
