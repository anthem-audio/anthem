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

#include "anthem_graph_node.h"
#include "anthem_process_context.h"
#include "constants.h"

AnthemProcessContext::AnthemProcessContext(std::shared_ptr<AnthemGraphNode> graphNode) : graphNode(graphNode) {
  for (int i = 0; i < graphNode->audioInputs.size(); i++) {
    inputAudioBuffers.push_back(juce::AudioSampleBuffer(2, MAX_AUDIO_BUFFER_SIZE));
  }

  for (int i = 0; i < graphNode->audioOutputs.size(); i++) {
    outputAudioBuffers.push_back(juce::AudioSampleBuffer(2, MAX_AUDIO_BUFFER_SIZE));
  }
}

void AnthemProcessContext::setAllInputAudioBuffers(const std::vector<juce::AudioSampleBuffer>& buffers) {
  inputAudioBuffers = buffers;
}

void AnthemProcessContext::setAllOutputAudioBuffers(const std::vector<juce::AudioSampleBuffer>& buffers) {
  outputAudioBuffers = buffers;
}

juce::AudioSampleBuffer& AnthemProcessContext::getInputAudioBuffer(int index) {
  return inputAudioBuffers[index];
}

juce::AudioSampleBuffer& AnthemProcessContext::getOutputAudioBuffer(int index) {
  return outputAudioBuffers[index];
}

int AnthemProcessContext::getNumInputAudioBuffers() {
  return inputAudioBuffers.size();
}

int AnthemProcessContext::getNumOutputAudioBuffers() {
  return outputAudioBuffers.size();
}
