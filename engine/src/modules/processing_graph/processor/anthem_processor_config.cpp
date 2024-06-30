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

const std::optional<unsigned int> AnthemProcessorConfig::getIndexOfAudioInput(unsigned long id) const {
  std::optional<unsigned int> result = std::nullopt;

  for (unsigned int i = 0; i < this->getNumAudioInputs(); i++) {
    if (this->getAudioInputByIndex(i)->id == id) {
      result = std::optional{i};
      break;
    }
  }

  return result;
}

const std::shared_ptr<AnthemProcessorPortConfig> AnthemProcessorConfig::getAudioInputByIndex(int index) const {
  return audioInputs[index];
}

int AnthemProcessorConfig::getNumAudioInputs() const {
  return audioInputs.size();
}

void AnthemProcessorConfig::addAudioInput(const std::shared_ptr<AnthemProcessorPortConfig> port) {
  audioInputs.push_back(port);
}

const std::optional<unsigned int> AnthemProcessorConfig::getIndexOfAudioOutput(unsigned long id) const {
  std::optional<unsigned int> result = std::nullopt;

  for (unsigned int i = 0; i < this->getNumAudioOutputs(); i++) {
    if (this->getAudioOutputByIndex(i)->id == id) {
      result = std::optional{i};
      break;
    }
  }

  return result;
}

const std::shared_ptr<AnthemProcessorPortConfig> AnthemProcessorConfig::getAudioOutputByIndex(int index) const {
  return audioOutputs[index];
}

int AnthemProcessorConfig::getNumAudioOutputs() const {
  return audioOutputs.size();
}

void AnthemProcessorConfig::addAudioOutput(const std::shared_ptr<AnthemProcessorPortConfig> port) {
  audioOutputs.push_back(port);
}

const std::optional<unsigned int> AnthemProcessorConfig::getIndexOfMidiInput(unsigned long id) const {
  std::optional<unsigned int> result = std::nullopt;

  for (unsigned int i = 0; i < this->getNumMidiInputs(); i++) {
    if (this->getMidiInputByIndex(i)->id == id) {
      result = std::optional{i};
      break;
    }
  }

  return result;
}

const std::shared_ptr<AnthemProcessorPortConfig> AnthemProcessorConfig::getMidiInputByIndex(int index) const {
  return midiInputs[index];
}

int AnthemProcessorConfig::getNumMidiInputs() const {
  return midiInputs.size();
}

void AnthemProcessorConfig::addMidiInput(const std::shared_ptr<AnthemProcessorPortConfig> port) {
  midiInputs.push_back(port);
}

const std::optional<unsigned int> AnthemProcessorConfig::getIndexOfMidiOutput(unsigned long id) const {
  std::optional<unsigned int> result = std::nullopt;

  for (unsigned int i = 0; i < this->getNumMidiOutputs(); i++) {
    if (this->getMidiOutputByIndex(i)->id == id) {
      result = std::optional{i};
      break;
    }
  }

  return result;
}

const std::shared_ptr<AnthemProcessorPortConfig> AnthemProcessorConfig::getMidiOutputByIndex(int index) const {
  return midiOutputs[index];
}

int AnthemProcessorConfig::getNumMidiOutputs() const {
  return midiOutputs.size();
}

void AnthemProcessorConfig::addMidiOutput(const std::shared_ptr<AnthemProcessorPortConfig> port) {
  midiOutputs.push_back(port);
}

const std::optional<unsigned int> AnthemProcessorConfig::getIndexOfControlInput(unsigned long id) const {
  std::optional<unsigned int> result = std::nullopt;

  for (unsigned int i = 0; i < this->getNumControlInputs(); i++) {
    if (this->getControlInputByIndex(i)->id == id) {
      result = std::optional{i};
      break;
    }
  }

  return result;
}

const std::shared_ptr<AnthemProcessorPortConfig> AnthemProcessorConfig::getControlInputByIndex(int index) const {
  return controlInputs[index];
}

int AnthemProcessorConfig::getNumControlInputs() const {
  return controlInputs.size();
}

void AnthemProcessorConfig::addControlInput(const std::shared_ptr<AnthemProcessorPortConfig> port, const std::shared_ptr<AnthemProcessorParameterConfig> parameter) {
  controlInputs.push_back(port);
  parameters.push_back(parameter);
}

const std::optional<unsigned int> AnthemProcessorConfig::getIndexOfControlOutput(unsigned long id) const {
  std::optional<unsigned int> result = std::nullopt;

  for (unsigned int i = 0; i < this->getNumControlOutputs(); i++) {
    if (this->getControlOutputByIndex(i)->id == id) {
      result = std::optional{i};
      break;
    }
  }

  return result;
}

const std::shared_ptr<AnthemProcessorPortConfig> AnthemProcessorConfig::getControlOutputByIndex(int index) const {
  return controlOutputs[index];
}

int AnthemProcessorConfig::getNumControlOutputs() const {
  return controlOutputs.size();
}

const std::optional<unsigned int> AnthemProcessorConfig::getIndexOfParameter(unsigned long id) const {
  return this->getIndexOfControlInput(id);
}

const std::shared_ptr<AnthemProcessorParameterConfig> AnthemProcessorConfig::getParameterByIndex(int index) const {
  return parameters[index];
}

void AnthemProcessorConfig::addControlOutput(const std::shared_ptr<AnthemProcessorPortConfig> port) {
  controlOutputs.push_back(port);
}
