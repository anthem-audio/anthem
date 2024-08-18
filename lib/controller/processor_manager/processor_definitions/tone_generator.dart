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

import 'package:anthem/model/processing_graph/processor_definition.dart';

const toneGeneratorDefinition = ProcessorDefinition(
  id: 'ToneGenerator',
  name: 'Tone Generator',
  type: ProcessorType.generator,
  inputAudioPorts: [],
  inputControlPorts: [
    ProcessorPort(id: 0, name: 'Frequency'),
    ProcessorPort(id: 1, name: 'Amplitude'),
  ],
  inputMIDIPorts: [
    ProcessorPort(id: 0, name: 'MIDI Input'),
  ],
  outputAudioPorts: [
    ProcessorPort(id: 0, name: 'Output'),
  ],
  outputControlPorts: [],
  outputMIDIPorts: [],
  parameters: [
    // Frequency
    ProcessorParameter(
      id: 0,
      defaultValue: 440.0,
      minValue: 0.0,
      maxValue: 20000.0,
    ),
    // Amplitude
    ProcessorParameter(
      id: 1,
      defaultValue: 0.125,
      minValue: 0.0,
      maxValue: 1.0,
    ),
  ],
);
