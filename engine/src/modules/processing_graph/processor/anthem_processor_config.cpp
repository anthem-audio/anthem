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

const std::optional<size_t> AnthemProcessorConfig::getIndexOfAudioInput(uint64_t portId) const {
  std::optional<size_t> result = std::nullopt;

  for (size_t i = 0; i < this->getNumAudioInputs(); i++) {
    if (this->getAudioInputByIndex(i)->id == portId) {
      result = std::optional{i};
      break;
    }
  }

  return result;
}

const std::shared_ptr<AnthemProcessorPortConfig> AnthemProcessorConfig::getAudioInputByIndex(size_t index) const {
  return audioInputs[index];
}

size_t AnthemProcessorConfig::getNumAudioInputs() const {
  return audioInputs.size();
}

void AnthemProcessorConfig::addAudioInput(const std::shared_ptr<AnthemProcessorPortConfig> port) {
  audioInputs.push_back(port);
}

const std::optional<size_t> AnthemProcessorConfig::getIndexOfAudioOutput(uint64_t portId) const {
  std::optional<size_t> result = std::nullopt;

  for (size_t i = 0; i < this->getNumAudioOutputs(); i++) {
    if (this->getAudioOutputByIndex(i)->id == portId) {
      result = std::optional{i};
      break;
    }
  }

  return result;
}

const std::shared_ptr<AnthemProcessorPortConfig> AnthemProcessorConfig::getAudioOutputByIndex(size_t index) const {
  return audioOutputs[index];
}

size_t AnthemProcessorConfig::getNumAudioOutputs() const {
  return audioOutputs.size();
}

void AnthemProcessorConfig::addAudioOutput(const std::shared_ptr<AnthemProcessorPortConfig> port) {
  audioOutputs.push_back(port);
}

const std::optional<size_t> AnthemProcessorConfig::getIndexOfMidiInput(uint64_t portId) const {
  std::optional<size_t> result = std::nullopt;

  for (size_t i = 0; i < this->getNumMidiInputs(); i++) {
    if (this->getMidiInputByIndex(i)->id == portId) {
      result = std::optional{i};
      break;
    }
  }

  return result;
}

const std::shared_ptr<AnthemProcessorPortConfig> AnthemProcessorConfig::getMidiInputByIndex(size_t index) const {
  return midiInputs[index];
}

size_t AnthemProcessorConfig::getNumMidiInputs() const {
  return midiInputs.size();
}

void AnthemProcessorConfig::addMidiInput(const std::shared_ptr<AnthemProcessorPortConfig> port) {
  midiInputs.push_back(port);
}

const std::optional<size_t> AnthemProcessorConfig::getIndexOfMidiOutput(uint64_t portId) const {
  std::optional<size_t> result = std::nullopt;

  for (size_t i = 0; i < this->getNumMidiOutputs(); i++) {
    if (this->getMidiOutputByIndex(i)->id == portId) {
      result = std::optional{i};
      break;
    }
  }

  return result;
}

const std::shared_ptr<AnthemProcessorPortConfig> AnthemProcessorConfig::getMidiOutputByIndex(size_t index) const {
  return midiOutputs[index];
}

size_t AnthemProcessorConfig::getNumMidiOutputs() const {
  return midiOutputs.size();
}

void AnthemProcessorConfig::addMidiOutput(const std::shared_ptr<AnthemProcessorPortConfig> port) {
  midiOutputs.push_back(port);
}

const std::optional<size_t> AnthemProcessorConfig::getIndexOfControlInput(uint64_t portId) const {
  std::optional<size_t> result = std::nullopt;

  for (size_t i = 0; i < this->getNumControlInputs(); i++) {
    if (this->getControlInputByIndex(i)->id == portId) {
      result = std::optional{i};
      break;
    }
  }

  return result;
}

const std::shared_ptr<AnthemProcessorPortConfig> AnthemProcessorConfig::getControlInputByIndex(size_t index) const {
  return controlInputs[index];
}

size_t AnthemProcessorConfig::getNumControlInputs() const {
  return controlInputs.size();
}

void AnthemProcessorConfig::addControlInput(const std::shared_ptr<AnthemProcessorPortConfig> port, const std::shared_ptr<AnthemProcessorParameterConfig> parameter) {
  controlInputs.push_back(port);
  parameters.push_back(parameter);
}

const std::optional<size_t> AnthemProcessorConfig::getIndexOfControlOutput(uint64_t portId) const {
  std::optional<size_t> result = std::nullopt;

  for (size_t i = 0; i < this->getNumControlOutputs(); i++) {
    if (this->getControlOutputByIndex(i)->id == portId) {
      result = std::optional{i};
      break;
    }
  }

  return result;
}

const std::shared_ptr<AnthemProcessorPortConfig> AnthemProcessorConfig::getControlOutputByIndex(size_t index) const {
  return controlOutputs[index];
}

size_t AnthemProcessorConfig::getNumControlOutputs() const {
  return controlOutputs.size();
}

const std::optional<size_t> AnthemProcessorConfig::getIndexOfParameter(uint64_t portId) const {
  return this->getIndexOfControlInput(portId);
}

const std::shared_ptr<AnthemProcessorParameterConfig> AnthemProcessorConfig::getParameterByIndex(size_t index) const {
  return parameters[index];
}

void AnthemProcessorConfig::addControlOutput(const std::shared_ptr<AnthemProcessorPortConfig> port) {
  controlOutputs.push_back(port);
}
