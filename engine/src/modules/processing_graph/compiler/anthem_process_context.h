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

#include <memory>
#include <vector>

#include <juce_audio_basics/juce_audio_basics.h>

class AnthemGraphNode;

// This class acts as a context for node graph processors. It is passed to the
// `process()` method of each `AnthemProcessor`, and provides a way to query
// the inputs and outputs of the node associated with that processor.
class AnthemProcessContext {
private:
  std::vector<juce::AudioSampleBuffer> inputAudioBuffers;
  std::vector<juce::AudioSampleBuffer> outputAudioBuffers;

  std::shared_ptr<AnthemGraphNode> graphNode;
public:
  AnthemProcessContext(std::shared_ptr<AnthemGraphNode> graphNode) : graphNode(graphNode) {}

  void setAllInputAudioBuffers(const std::vector<juce::AudioSampleBuffer>& buffers) {
    inputAudioBuffers = buffers;
  }

  void setAllOutputAudioBuffers(const std::vector<juce::AudioSampleBuffer>& buffers) {
    outputAudioBuffers = buffers;
  }

  juce::AudioSampleBuffer& getInputAudioBuffer(int index) {
    return inputAudioBuffers[index];
  }

  juce::AudioSampleBuffer& getOutputAudioBuffer(int index) {
    return outputAudioBuffers[index];
  }

  int getNumInputAudioBuffers() {
    return inputAudioBuffers.size();
  }

  int getNumOutputAudioBuffers() {
    return outputAudioBuffers.size();
  }
};
