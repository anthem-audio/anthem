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

#include "anthem_processor_config.h"

const std::shared_ptr<AnthemGraphNodePort> AnthemProcessorConfig::getAudioInput(int index) const {
  return audioInputs[index];
}

int AnthemProcessorConfig::getNumAudioInputs() const {
  return audioInputs.size();
}

void AnthemProcessorConfig::addAudioInput(const AnthemProcessorPortConfig& port) {
  audioInputs.push_back(std::make_shared<AnthemGraphNodePort>(port, audioInputs.size()));
}

const std::shared_ptr<AnthemGraphNodePort> AnthemProcessorConfig::getAudioOutput(int index) const {
  return audioOutputs[index];
}

int AnthemProcessorConfig::getNumAudioOutputs() const {
  return audioOutputs.size();
}

void AnthemProcessorConfig::addAudioOutput(const AnthemProcessorPortConfig& port) {
  audioOutputs.push_back(std::make_shared<AnthemGraphNodePort>(port, audioOutputs.size()));
}

const std::shared_ptr<AnthemGraphNodePort> AnthemProcessorConfig::getMidiInput(int index) const {
  return midiInputs[index];
}

int AnthemProcessorConfig::getNumMidiInputs() const {
  return midiInputs.size();
}

void AnthemProcessorConfig::addMidiInput(const AnthemProcessorPortConfig& port) {
  midiInputs.push_back(std::make_shared<AnthemGraphNodePort>(port, midiInputs.size()));
}

const std::shared_ptr<AnthemGraphNodePort> AnthemProcessorConfig::getMidiOutput(int index) const {
  return midiOutputs[index];
}

int AnthemProcessorConfig::getNumMidiOutputs() const {
  return midiOutputs.size();
}

void AnthemProcessorConfig::addMidiOutput(const AnthemProcessorPortConfig& port) {
  midiOutputs.push_back(std::make_shared<AnthemGraphNodePort>(port, midiOutputs.size()));
}

const std::shared_ptr<AnthemGraphNodePort> AnthemProcessorConfig::getControlInput(int index) const {
  return controlInputs[index];
}

int AnthemProcessorConfig::getNumControlInputs() const {
  return controlInputs.size();
}

void AnthemProcessorConfig::addControlInput(const AnthemProcessorPortConfig& port) {
  controlInputs.push_back(std::make_shared<AnthemGraphNodePort>(port, controlInputs.size()));
}

const std::shared_ptr<AnthemGraphNodePort> AnthemProcessorConfig::getControlOutput(int index) const {
  return controlOutputs[index];
}

int AnthemProcessorConfig::getNumControlOutputs() const {
  return controlOutputs.size();
}

void AnthemProcessorConfig::addControlOutput(const AnthemProcessorPortConfig& port) {
  controlOutputs.push_back(std::make_shared<AnthemGraphNodePort>(port, controlOutputs.size()));
}
