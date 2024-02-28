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

#pragma once

#include <vector>

#include "anthem_processor_port_config.h"
#include "anthem_graph_node_port.h"

// This class defines properties for an AnthemProcessor. These properties are
// used by the graph to define things like inputs and outputs.
class AnthemProcessorConfig {
private:
  std::vector<AnthemGraphNodePort> audioInputs;
  std::vector<AnthemGraphNodePort> audioOutputs;

  std::vector<AnthemGraphNodePort> midiInputs;
  std::vector<AnthemGraphNodePort> midiOutputs;

  std::vector<AnthemGraphNodePort> controlInputs;
  std::vector<AnthemGraphNodePort> controlOutputs;
public:
  // Get an audio input port by index.
  const AnthemGraphNodePort& getAudioInput(int index) const;

  // Get the number of audio inputs.
  int getNumAudioInputs() const;

  // Add an audio input port.
  void addAudioInput(const AnthemProcessorPortConfig& port);

  // Get an audio output port by index.
  const AnthemGraphNodePort& getAudioOutput(int index) const;

  // Get the number of audio outputs.
  int getNumAudioOutputs() const;

  // Add an audio output port.
  void addAudioOutput(const AnthemProcessorPortConfig& port);

  // Get a MIDI input port by index.
  const AnthemGraphNodePort& getMidiInput(int index) const;

  // Get the number of MIDI inputs.
  int getNumMidiInputs() const;

  // Add a MIDI input port.
  void addMidiInput(const AnthemProcessorPortConfig& port);

  // Get a MIDI output port by index.
  const AnthemGraphNodePort& getMidiOutput(int index) const;

  // Get the number of MIDI outputs.
  int getNumMidiOutputs() const;

  // Add a MIDI output port.
  void addMidiOutput(const AnthemProcessorPortConfig& port);

  // Get a control input port by index.
  const AnthemGraphNodePort& getControlInput(int index) const;

  // Get the number of control inputs.
  int getNumControlInputs() const;

  // Add a control input port.
  void addControlInput(const AnthemProcessorPortConfig& port);

  // Get a control output port by index.
  const AnthemGraphNodePort& getControlOutput(int index) const;

  // Get the number of control outputs.
  int getNumControlOutputs() const;

  // Add a control output port.
  void addControlOutput(const AnthemProcessorPortConfig& port);
};
