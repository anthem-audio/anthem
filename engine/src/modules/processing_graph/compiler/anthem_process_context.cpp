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

#include "anthem_process_context.h"

#include "modules/core/constants.h"

AnthemProcessContext::AnthemProcessContext(Node& graphNode, ArenaBufferAllocator<AnthemProcessorEvent>* eventAllocator) : graphNode(graphNode) {
  for (auto& port : graphNode.audioInputPorts()) {
    inputAudioBuffers[port->id()] = juce::AudioSampleBuffer(2, MAX_AUDIO_BUFFER_SIZE);
  }

  for (auto& port : graphNode.audioOutputPorts()) {
    outputAudioBuffers[port->id()] = juce::AudioSampleBuffer(2, MAX_AUDIO_BUFFER_SIZE);
  }

  for (auto& port : graphNode.controlInputPorts()) {
    inputControlBuffers[port->id()] = juce::AudioSampleBuffer(1, MAX_AUDIO_BUFFER_SIZE);
  }

  for (auto& port : graphNode.controlOutputPorts()) {
    outputControlBuffers[port->id()] = juce::AudioSampleBuffer(1, MAX_AUDIO_BUFFER_SIZE);
  }

  for (auto& port : graphNode.midiInputPorts()) {
    inputNoteEventBuffers[port->id()] = AnthemEventBuffer(eventAllocator, 1024);
  }

  for (auto& port : graphNode.midiOutputPorts()) {
    outputNoteEventBuffers[port->id()] = AnthemEventBuffer(eventAllocator, 1024);
  }

  for (auto& port : graphNode.controlInputPorts()) {
    parameterValues[port->id()] = std::atomic<float>(port->parameterValue().value_or(0.0f));
  }

  for (auto& port : graphNode.controlInputPorts()) {
    auto parameterValue = port->parameterValue().value_or(0.0f);
    auto& parameterConfig = port->config()->parameterConfig();

    auto smoother = std::make_unique<LinearParameterSmoother>(parameterValue, parameterConfig.smoothingDurationSeconds());
    parameterSmoothers[port->id()] = std::move(smoother);
  }
}

// TODO: We should set parameters automatically when the model is changed
void AnthemProcessContext::setParameterValue(int32_t id, float value) {
  // Throw if not on the JUCE message thread
  if (!juce::MessageManager::getInstance()->isThisTheMessageThread()) {
    throw std::runtime_error("AnthemProcessContext::setParameterValue() must be called on the JUCE message thread.");
  }

  parameterValues[id].store(value);
}

float AnthemProcessContext::getParameterValue(int32_t id) {
  return parameterValues[id].load();
}

void AnthemProcessContext::setAllInputAudioBuffers(const std::unordered_map<int32_t, juce::AudioSampleBuffer>& buffers) {
  inputAudioBuffers = buffers;
}

void AnthemProcessContext::setAllOutputAudioBuffers(const std::unordered_map<int32_t, juce::AudioSampleBuffer>& buffers) {
  outputAudioBuffers = buffers;
}

juce::AudioSampleBuffer& AnthemProcessContext::getInputAudioBuffer(int32_t id) {
  return inputAudioBuffers[id];
}

juce::AudioSampleBuffer& AnthemProcessContext::getOutputAudioBuffer(int32_t id) {
  return outputAudioBuffers[id];
}

size_t AnthemProcessContext::getNumInputAudioBuffers() {
  return inputAudioBuffers.size();
}

size_t AnthemProcessContext::getNumOutputAudioBuffers() {
  return outputAudioBuffers.size();
}

void AnthemProcessContext::setAllInputControlBuffers(const std::unordered_map<int32_t, juce::AudioSampleBuffer>& buffers) {
  inputControlBuffers = buffers;
}

void AnthemProcessContext::setAllOutputControlBuffers(const std::unordered_map<int32_t, juce::AudioSampleBuffer>& buffers) {
  outputControlBuffers = buffers;
}

juce::AudioSampleBuffer& AnthemProcessContext::getInputControlBuffer(int32_t id) {
  return inputControlBuffers[id];
}

juce::AudioSampleBuffer& AnthemProcessContext::getOutputControlBuffer(int32_t id) {
  return outputControlBuffers[id];
}

size_t AnthemProcessContext::getNumInputControlBuffers() {
  return inputControlBuffers.size();
}

size_t AnthemProcessContext::getNumOutputControlBuffers() {
  return outputControlBuffers.size();
}

void AnthemProcessContext::setAllInputNoteEventBuffers(const std::unordered_map<int32_t, AnthemEventBuffer>& buffers) {
  inputNoteEventBuffers = buffers;
}

void AnthemProcessContext::setAllOutputNoteEventBuffers(const std::unordered_map<int32_t, AnthemEventBuffer>& buffers) {
  outputNoteEventBuffers = buffers;
}

AnthemEventBuffer& AnthemProcessContext::getInputNoteEventBuffer(int32_t id) {
  return inputNoteEventBuffers[id];
}

AnthemEventBuffer& AnthemProcessContext::getOutputNoteEventBuffer(int32_t id) {
  return outputNoteEventBuffers[id];
}

size_t AnthemProcessContext::getNumInputNoteEventBuffers() {
  return inputNoteEventBuffers.size();
}

size_t AnthemProcessContext::getNumOutputNoteEventBuffers() {
  return outputNoteEventBuffers.size();
}
