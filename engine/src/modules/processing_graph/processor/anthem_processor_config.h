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
#include <memory>
#include <string>

#include "anthem_processor_port_config.h"

// This class defines properties for an AnthemProcessor. These properties are
// used by the graph to define things like inputs and outputs.
class AnthemProcessorConfig {
private:
  std::vector<std::shared_ptr<AnthemProcessorPortConfig>> audioInputs;
  std::vector<std::shared_ptr<AnthemProcessorPortConfig>> audioOutputs;

  std::vector<std::shared_ptr<AnthemProcessorPortConfig>> midiInputs;
  std::vector<std::shared_ptr<AnthemProcessorPortConfig>> midiOutputs;

  std::vector<std::shared_ptr<AnthemProcessorPortConfig>> controlInputs;
  std::vector<std::shared_ptr<AnthemProcessorPortConfig>> controlOutputs;

  std::string id;
public:
  AnthemProcessorConfig(const std::string& id) : id(id) {}

  // Get an audio input port by index.
  const std::shared_ptr<AnthemProcessorPortConfig> getAudioInput(int index) const;

  // Get the number of audio inputs.
  int getNumAudioInputs() const;

  // Add an audio input port.
  void addAudioInput(const std::shared_ptr<AnthemProcessorPortConfig> port);

  // Get an audio output port by index.
  const std::shared_ptr<AnthemProcessorPortConfig> getAudioOutput(int index) const;

  // Get the number of audio outputs.
  int getNumAudioOutputs() const;

  // Add an audio output port.
  void addAudioOutput(const std::shared_ptr<AnthemProcessorPortConfig> port);

  // Get a MIDI input port by index.
  const std::shared_ptr<AnthemProcessorPortConfig> getMidiInput(int index) const;

  // Get the number of MIDI inputs.
  int getNumMidiInputs() const;

  // Add a MIDI input port.
  void addMidiInput(const std::shared_ptr<AnthemProcessorPortConfig> port);

  // Get a MIDI output port by index.
  const std::shared_ptr<AnthemProcessorPortConfig> getMidiOutput(int index) const;

  // Get the number of MIDI outputs.
  int getNumMidiOutputs() const;

  // Add a MIDI output port.
  void addMidiOutput(const std::shared_ptr<AnthemProcessorPortConfig> port);

  // Get a control input port by index.
  const std::shared_ptr<AnthemProcessorPortConfig> getControlInput(int index) const;

  // Get the number of control inputs.
  int getNumControlInputs() const;

  // Add a control input port.
  void addControlInput(const std::shared_ptr<AnthemProcessorPortConfig> port);

  // Get a control output port by index.
  const std::shared_ptr<AnthemProcessorPortConfig> getControlOutput(int index) const;

  // Get the number of control outputs.
  int getNumControlOutputs() const;

  // Add a control output port.
  void addControlOutput(const std::shared_ptr<AnthemProcessorPortConfig> port);

  std::string getId() {
    return id;
  }
};
